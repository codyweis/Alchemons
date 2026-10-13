// lib/services/trade_vault.dart
//
// The save's side of trading (lib/models/trade.dart): what may go on a
// table, the card an Alchemon travels as, and moving it — into the table
// while it waits, back out if it is taken back, and away for good when the
// trade is done, the friend's arriving in its place. Each move is one
// database transaction, and each done trade is collected once (its receipt
// is kept in the same transaction), so a game stopped at any point loses
// nothing and makes no copy.
//
// Settings rows:
//   trade_escrow_v1    {"<table id>": <row JSON>}  confirmed, waiting
//   trade_receipts_v1  {"<trade key>": {"gave", "got", "at"}}  collected (a
//                      fusion's "got" is its cultivation's id)

import 'dart:convert';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic_survival/survival_suspended_run.dart'
    show kSuspendedRunKey;
import 'package:alchemons/models/cosmetic_wear.dart';
import 'package:alchemons/models/owned_cosmetics.dart';
import 'package:alchemons/models/trade.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class TradeVault {
  TradeVault(this.db, {required this.catalog});

  final AlchemonsDatabase db;
  final CreatureCatalog catalog;

  static const String escrowKey = 'trade_escrow_v1';
  static const String receiptsKey = 'trade_receipts_v1';

  /// How many of one species a save holds (CreatureDao.defaultSpeciesCap).
  static const int speciesCap = 100;

  bool knownSpecies(String baseId) => catalog.getCreatureById(baseId) != null;

  // ── What may go up ──────────────────────────────────────────────────────

  /// Why [instance] can't go on a table, or null when it can. [elsewhere]:
  /// the Alchemons already up on other tables.
  Future<String?> whyNot(
    CreatureInstance instance, {
    Set<String> elsewhere = const {},
  }) async {
    final id = instance.instanceId;
    if (instance.locked || instance.isFavorite) {
      return "Favorites can't be traded.";
    }
    if (elsewhere.contains(id)) return 'It is on another trade table.';
    final jobs = await (db.select(
      db.biomeJobs,
    )..where((t) => t.creatureInstanceId.equals(id))).get();
    if (jobs.isNotEmpty) return 'It is harvesting.';
    final s = db.settingsDao;
    if ((await s.getCosmicPartySlots()).contains(id)) {
      return "It is in your ship's party.";
    }
    if ((await s.getCosmicGarrisonSlots()).contains(id)) {
      return 'It is guarding your home base.';
    }
    if ((await s.getSetting(kSuspendedRunKey))?.contains(id) ?? false) {
      return 'It is in a paused survival run.';
    }
    return null;
  }

  /// Why the friend's [card] can't come to this save, or null when it can.
  Future<String?> whyNotReceive(TradedCreature card) async {
    final species = catalog.getCreatureById(card.instance.baseId);
    if (species == null) return 'This game does not know that Alchemon.';
    final n = await db.creatureDao.countBySpecies(card.instance.baseId);
    if (n >= speciesCap) return 'You have $speciesCap ${species.name} already.';
    return null;
  }

  // ── Cards ───────────────────────────────────────────────────────────────

  /// [instanceId] as it would travel now: its row and the case and trail it
  /// wears. Null when it is not in the collection.
  Future<TradedCreature?> card(String instanceId) async {
    final row = await db.creatureDao.getInstance(instanceId);
    if (row == null) return null;
    final (caseStyle, trail) = await _wornBy(instanceId);
    return TradedCreature(instance: row, caseStyle: caseStyle, trail: trail);
  }

  /// The case and trail [instanceId] wears, as the game shows them.
  Future<(CaseStyle?, TrailStyle?)> _wornBy(String instanceId) async {
    final s = db.settingsDao;
    final worn =
        CosmeticWear.decode(
          cases: await s.getSetting(CosmeticWear.caseKey),
          trails: await s.getSetting(CosmeticWear.trailKey),
        ).owned(
          OwnedCosmetics.decode(await s.getSetting(OwnedCosmetics.key)),
          carried: CarriedWear.decode(await s.getSetting(CarriedWear.key)),
        );
    return (worn.cases[instanceId], worn.trails[instanceId]);
  }

  /// [raw] read as a friend's card, cleaned; null when it can't be one.
  TradedCreature? read(String? raw) =>
      TradedCreature.decode(raw, knownSpecies: knownSpecies);

  // ── Waiting on a table ──────────────────────────────────────────────────

  /// What waits on each table, by table id.
  Future<Map<String, CreatureInstance>> escrowed() async {
    final raw = await db.settingsDao.getSetting(escrowKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return {};
      final out = <String, CreatureInstance>{};
      for (final e in json.entries) {
        if (e.key is! String || e.value is! Map) continue;
        try {
          out[e.key as String] = CreatureInstance.fromJson(
            Map<String, dynamic>.from(e.value as Map),
          );
        } catch (_) {}
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveEscrow(Map<String, CreatureInstance> e) =>
      db.settingsDao.setSetting(
        escrowKey,
        jsonEncode({for (final x in e.entries) x.key: x.value.toJson()}),
      );

  /// Moves [instanceId] out of the collection onto [tableId]. False when it
  /// is not in the collection (or something else already waits there).
  Future<bool> escrow(String tableId, String instanceId) =>
      db.transaction(() async {
        final waiting = await escrowed();
        if (waiting[tableId]?.instanceId == instanceId) return true;
        if (waiting.containsKey(tableId)) return false;
        final row = await db.creatureDao.getInstance(instanceId);
        if (row == null) return false;
        await db.creatureDao.deleteInstances([instanceId]);
        await _saveEscrow({...waiting, tableId: row});
        return true;
      });

  /// Brings what waits on [tableId] back into the collection, unless it was
  /// traded away since this save was made ([gone]). Returns it, if it came
  /// back.
  Future<CreatureInstance?> release(
    String tableId, {
    Map<String, int> gone = const {},
  }) => db.transaction(() async {
    final waiting = await escrowed();
    final row = waiting.remove(tableId);
    if (row == null) return null;
    await _saveEscrow(waiting);
    final id = row.instanceId;
    if (await _wasTradedAway(id, gone)) return null;
    if (await db.creatureDao.getInstance(id) != null) return null;
    await db.into(db.creatureInstances).insert(row);
    return row;
  });

  // ── Collecting a done trade ─────────────────────────────────────────────

  /// What has been collected, by trade key.
  Future<Map<String, TradeReceipt>> receipts() async {
    final raw = await db.settingsDao.getSetting(receiptsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return {};
      return {
        for (final e in json.entries)
          if (e.key is String)
            if (TradeReceipt.fromJson(e.value) case final r?)
              e.key as String: r,
      };
    } catch (_) {
      return {};
    }
  }

  /// The trade [key] has been collected into this save.
  Future<bool> collected(String key) async =>
      (await receipts()).containsKey(key);

  /// Collects the done trade [key] on [tableId]: [giveId] leaves (from the
  /// table or the collection), [got] arrives with [step] in its history, its
  /// stats worked out again, wearing what it came in. Once only: null when
  /// it already was. Returns the Alchemon as it arrived.
  Future<CreatureInstance?> collect({
    required String key,
    required String tableId,
    required String giveId,
    required TradedCreature got,
    required TradeStep step,
  }) => db.transaction(() async {
    final all = await receipts();
    if (all.containsKey(key)) return null;

    // What leaves.
    final waiting = await escrowed();
    if (waiting[tableId]?.instanceId == giveId) {
      waiting.remove(tableId);
      await _saveEscrow(waiting);
    }
    await _forget(giveId);

    // What arrives.
    var row = got.instance;
    if (await db.creatureDao.getInstance(row.instanceId) != null) {
      row = row.copyWith(instanceId: const Uuid().v4());
    }
    row = row.copyWith(
      provenance: Value(
        (got.provenance ?? const TradeProvenance([])).plus(step).encode(),
      ),
    );
    await db.into(db.creatureInstances).insert(row);
    await GameDataService(
      db: db,
      catalog: catalog,
    ).refreshInstanceStats(row.instanceId);
    await db.creatureDao.addOrUpdateCreature(
      PlayerCreaturesCompanion(
        id: Value(row.baseId),
        discovered: const Value(true),
        natureId: Value(row.natureId),
        natureId2: Value(row.natureId2),
      ),
    );
    await _carry(row.instanceId, got.caseStyle, got.trail);

    all[key] = TradeReceipt(gave: giveId, got: row.instanceId, atMs: step.atMs);
    await _saveReceipts(all);
    return row;
  });

  /// Keeps [receipt] for [key], from inside the transaction that collected
  /// it: a fusion's, whose cultivation [TradeReceipt.got] is.
  Future<void> keepReceipt(String key, TradeReceipt receipt) async =>
      _saveReceipts({...await receipts(), key: receipt});

  Future<void> _saveReceipts(Map<String, TradeReceipt> all) =>
      db.settingsDao.setSetting(
        receiptsKey,
        jsonEncode({for (final e in all.entries) e.key: e.value.toJson()}),
      );

  /// Takes out of the collection any Alchemon traded away ([gone]: id →
  /// when) that a restored save brought back. Returns how many.
  Future<int> enforceGone(Map<String, int> gone) async {
    if (gone.isEmpty) return 0;
    return db.transaction(() async {
      var n = 0;
      for (final id in gone.keys) {
        if (!await _wasTradedAway(id, gone)) continue;
        if (await db.creatureDao.getInstance(id) == null) continue;
        await _forget(id);
        n++;
      }
      return n;
    });
  }

  /// [id] left in a trade later than any trade brought it here.
  Future<bool> _wasTradedAway(String id, Map<String, int> gone) async {
    final at = gone[id];
    if (at == null) return false;
    var arrived = -1;
    for (final r in (await receipts()).values) {
      if (r.got == id && r.atMs > arrived) arrived = r.atMs;
    }
    return at > arrived;
  }

  /// [id] out of the collection, and out of everything that pointed at it
  /// where it would be missed: what it wore, its backdrop, the home's
  /// featured spot, the bubble party, the ship's party and garrison.
  Future<void> _forget(String id) async {
    await db.creatureDao.deleteInstances([id]);
    final s = db.settingsDao;
    for (final key in [CosmeticWear.caseKey, CosmeticWear.trailKey]) {
      final raw = await s.getSetting(key);
      if (raw == null || !raw.contains(id)) continue;
      try {
        final map = Map<String, dynamic>.from(jsonDecode(raw) as Map)
          ..remove(id);
        final keys = map.keys.toList()..sort();
        await s.setSetting(key, jsonEncode({for (final k in keys) k: map[k]}));
      } catch (_) {}
    }
    final carried = CarriedWear.decode(await s.getSetting(CarriedWear.key));
    if (carried.byInstance.containsKey(id)) {
      await s.setSetting(
        CarriedWear.key,
        carried.withInstance(id, null, null).encode(),
      );
    }
    await s.deleteSetting('creature_bg:instance:$id');
    if (await s.getFeaturedInstanceId() == id) {
      await s.setFeaturedInstanceId(null);
    }
    final blobs = await s.getBlobInstanceSlots();
    for (var i = 0; i < blobs.length; i++) {
      if (blobs[i] == id) await s.setBlobSlotInstance(i, null);
    }
    final party = await s.getCosmicPartySlots();
    for (var i = 0; i < party.length; i++) {
      if (party[i] == id) await s.setCosmicPartySlotInstance(i, null);
    }
    final garrison = await s.getCosmicGarrisonSlots();
    for (var i = 0; i < garrison.length; i++) {
      if (garrison[i] == id) await s.setCosmicGarrisonSlotInstance(i, null);
    }
    await (db.delete(
      db.biomeJobs,
    )..where((t) => t.creatureInstanceId.equals(id))).go();
  }

  /// [id] wears [caseStyle] and [trail], owned or not.
  Future<void> _carry(
    String id,
    CaseStyle? caseStyle,
    TrailStyle? trail,
  ) async {
    if (caseStyle == null && trail == null) return;
    final s = db.settingsDao;
    final carried = CarriedWear.decode(await s.getSetting(CarriedWear.key));
    await s.setSetting(
      CarriedWear.key,
      carried.withInstance(id, caseStyle, trail).encode(),
    );
    final worn = CosmeticWear.decode(
      cases: await s.getSetting(CosmeticWear.caseKey),
      trails: await s.getSetting(CosmeticWear.trailKey),
    );
    if (caseStyle != null) {
      await s.setSetting(
        CosmeticWear.caseKey,
        CosmeticWear.encodeMap({...worn.cases, id: caseStyle}, (c) => c.id),
      );
    }
    if (trail != null) {
      await s.setSetting(
        CosmeticWear.trailKey,
        CosmeticWear.encodeMap({...worn.trails, id: trail}, (t) => t.id),
      );
    }
  }
}

/// A done trade, collected: what left, what arrived, and when it was done.
/// For a fusion, the parent (which stayed) and the cultivation.
class TradeReceipt {
  const TradeReceipt({
    required this.gave,
    required this.got,
    required this.atMs,
  });

  final String gave, got;
  final int atMs;

  Map<String, dynamic> toJson() => {'gave': gave, 'got': got, 'at': atMs};

  static TradeReceipt? fromJson(Object? j) {
    if (j is! Map) return null;
    final gave = j['gave'], got = j['got'], at = j['at'];
    if (gave is! String || got is! String || at is! num) return null;
    return TradeReceipt(gave: gave, got: got, atMs: at.toInt());
  }
}
