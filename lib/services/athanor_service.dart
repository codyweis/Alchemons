// lib/services/athanor_service.dart
//
// The Athanor's state and its pours (docs/athanor_design.md; the batches,
// odds and draw are models/athanor.dart).
//
// A pour is one database transaction: the payment is checked again and
// spent, the piece drawn on exactly the odds [AthanorService.nextPourOdds]
// shows, granted through its kind's own system, and recorded. A pour that
// is not allowed changes nothing. The free daily pour replaces the home
// chest and still pays what the chest paid.
//
// Gold pours are a paid random draw, so they are off where the storefront
// country is Belgium. Tincture pours stay on there.

import 'dart:async';
import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart' show PlanetStarState;
import 'package:alchemons/models/athanor.dart';
import 'package:alchemons/models/dock_sets.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/models/home_decor.dart';
import 'package:alchemons/models/home_keepsakes.dart' show kPlanetStarsPrefsKey;
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/owned_cosmetics.dart';
import 'package:alchemons/models/profile_titles.dart';
import 'package:alchemons/services/campaign_journal_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AthanorPayment { daily, tincture, gold }

/// What the daily pour pays beside its piece: the old home chest's rewards.
class AthanorDailyExtras {
  const AthanorDailyExtras({
    required this.silver,
    required this.gold,
    this.vialGroupName,
  });

  final int silver;

  /// 0 or 1.
  final int gold;

  /// The common vial's group, as its [ElementalGroup.name]; null when no
  /// vial came.
  final String? vialGroupName;

  /// The vial's group, resolved from [vialGroupName].
  ElementalGroup? get vialGroup {
    final name = vialGroupName;
    if (name == null) return null;
    for (final g in ElementalGroup.values) {
      if (g.name == name) return g;
    }
    return null;
  }
}

class AthanorPourResult {
  const AthanorPourResult({
    required this.batch,
    required this.piece,
    this.capstone,
    this.daily,
    this.items = const {},
  });

  final AthanorBatch batch;
  final AthanorPiece piece;

  /// What [piece] gave as items, by inventory key: an Enhance Orbs piece's
  /// orbs and soul. Empty for every other piece.
  final Map<String, int> items;

  /// Given with this pour: the batch is done.
  final AthanorPiece? capstone;

  /// The daily pour's chest rewards; null for a paid pour.
  final AthanorDailyExtras? daily;
}

/// Whether [country] (alpha-2 or alpha-3, any case) is Belgium.
bool athanorIsBelgium(String? country) {
  final c = country?.trim().toUpperCase();
  return c == 'BE' || c == 'BEL';
}

/// The storefront country, for the gold-pour switch: the store's own on iOS
/// (alpha-3, 'BEL') and Android (alpha-2, 'BE'), else the platform locale's.
/// Null when neither is known.
Future<String?> athanorDefaultStorefrontCountry() async {
  final mobile =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
  if (mobile) {
    try {
      final code = (await InAppPurchase.instance.countryCode().timeout(
        const Duration(seconds: 4),
      )).trim();
      if (code.isNotEmpty) return code;
    } catch (_) {
      // No store answer (no account, no connection): the locale below.
    }
  }
  final locale = PlatformDispatcher.instance.locale.countryCode;
  return locale == null || locale.isEmpty ? null : locale;
}

/// Grants [piece] through its kind's system. Runs inside the caller's
/// transaction. Returns what an Enhance Orbs piece gave (rolled on
/// [random]), by inventory key; empty for every other piece.
Future<Map<String, int>> grantAthanorPiece(
  AlchemonsDatabase db,
  AthanorPiece piece, {
  Random? random,
}) async {
  switch (piece.kind) {
    case AthanorPieceKind.alchemyEffect:
      await db.inventoryDao.addItemQty(piece.grantRef, 1);
    case AthanorPieceKind.homeDecor:
      // Owning more lets more of it stand in each realm (HomeDecor.max). A
      // Curio comes three at a time, so a draw places a few round a realm.
      final decor = HomeDecor.byId(piece.grantRef);
      final key = decor?.inventoryKey ?? athanorInventoryKeyFor(piece)!;
      await db.inventoryDao.addItemQty(
        key,
        decor?.tier == DecorTier.curio ? kAthanorCurioCopies : 1,
      );
    case AthanorPieceKind.title:
      await ProfileTitles.grant(db, piece.grantRef);
    case AthanorPieceKind.costume:
      await db.inventoryDao.addItemQty(piece.grantRef, 1);
    case AthanorPieceKind.dockSet:
      final set = kDockSets.where((s) => s.id == piece.grantRef).firstOrNull;
      await db.settingsDao.setSetting(
        set?.settingKey ?? 'dock_set_owned_${piece.grantRef}',
        '1',
      );
    case AthanorPieceKind.caseStyle:
    case AthanorPieceKind.trail:
    case AthanorPieceKind.fusionStyle:
    case AthanorPieceKind.ambience:
      await OwnedCosmetics.grant(db, piece.kind, piece.grantRef);
    case AthanorPieceKind.enhanceOrbs:
      final items = athanorRollEnhanceOrbs(random ?? Random());
      for (final e in items.entries) {
        await db.inventoryDao.addItemQty(e.key, e.value);
      }
      return items;
  }
  return const {};
}

class AthanorService extends ChangeNotifier {
  AthanorService(
    this._db, {
    List<AthanorBatch> batches = kAthanorBatches,
    Random? random,
    Future<String?> Function()? storefrontCountry,
    CreatureCatalog? catalog,
    DateTime Function()? clock,
  }) : _batches = List.unmodifiable(batches),
       _random = random ?? Random(),
       _storefrontCountry =
           storefrontCountry ?? athanorDefaultStorefrontCountry,
       _catalog = catalog,
       _clock = clock ?? DateTime.now;

  final AlchemonsDatabase _db;
  final List<AthanorBatch> _batches;
  final Random _random;
  final Future<String?> Function() _storefrontCountry;

  /// For the daily pour's vial: only groups that can yield a common
  /// specimen give one. Without it no vial is given.
  final CreatureCatalog? _catalog;
  final DateTime Function() _clock;

  AthanorState _state = AthanorState.empty;
  int _tincture = 0;
  int _gold = 0;
  bool _loaded = false;

  /// Asked once; the answer is kept for the session.
  Future<String?>? _country;
  bool _countryKnown = false;
  bool _goldAllowed = true;

  /// Hydrates the state, the balances and the storefront country. Safe to
  /// call again (the screen does on opening, to pick up tincture earned
  /// elsewhere).
  Future<void> load() async {
    final country = _country ??= _askCountry();
    _state = AthanorState.decode(
      await _db.settingsDao.getSetting(AthanorState.key),
    );
    _introSeen = await _db.settingsDao.getSetting(kAthanorIntroSeenKey) == '1';
    await _readBalances();
    if (!_countryKnown) {
      _goldAllowed = !athanorIsBelgium(await country);
      _countryKnown = true;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<String?> _askCountry() async {
    try {
      return await _storefrontCountry().timeout(const Duration(seconds: 6));
    } catch (_) {
      return null;
    }
  }

  Future<void> _readBalances() async {
    _tincture = await _db.inventoryDao.getItemQty(InvKeys.athanorTincture);
    _gold = await _db.currencyDao.getGoldBalance();
  }

  bool get loaded => _loaded;

  /// Whether the player has opened the Athanor (its first fire is given on
  /// the first visit). Until then the home emblem pulses to be found.
  bool get opened => _state.firstFire;

  bool _introSeen = false;

  /// Whether the player has read how the Furnace works (shown once, on the
  /// first open; the sparks balance shows it again).
  bool get introSeen => _introSeen;

  Future<void> markIntroSeen() async {
    if (_introSeen) return;
    _introSeen = true;
    await _db.settingsDao.setSetting(kAthanorIntroSeenKey, '1');
  }

  List<AthanorBatch> get batches => _batches;

  AthanorBatch? batchById(String batchId) {
    for (final b in _batches) {
      if (b.id == batchId) return b;
    }
    return null;
  }

  Set<String> drawnIn(String batchId) =>
      Set.unmodifiable(_state.drawnIn(batchId));

  /// Every piece of the batch drawn. False for an unknown batch.
  bool isComplete(String batchId) {
    final batch = batchById(batchId);
    if (batch == null) return false;
    final drawn = _state.drawnIn(batchId);
    return batch.pieces.every((p) => drawn.contains(p.id));
  }

  /// Cached balances, refreshed by [load] and [pour].
  int get tincture => _tincture;
  int get gold => _gold;

  /// Today's (UTC) free pour not yet taken. Read live, so a screen kept
  /// open past midnight sees the new day.
  bool get dailyPourReady =>
      _loaded && _state.dailyKey != athanorDayKey(_clock());

  /// False where the storefront is Belgian, and until the country is known.
  bool get goldPoursAvailable => _countryKnown && _goldAllowed;

  bool canPour(String batchId, AthanorPayment payment) {
    if (!_loaded) return false;
    final batch = batchById(batchId);
    if (batch == null || isComplete(batchId)) return false;
    return switch (payment) {
      AthanorPayment.daily => dailyPourReady,
      AthanorPayment.tincture => _tincture >= kAthanorTincturePerPour,
      AthanorPayment.gold => goldPoursAvailable && _gold >= kAthanorGoldPerPour,
    };
  }

  /// Each piece left in the batch and its chance on the next pour: what
  /// [pour] rolls on. Empty for a finished or unknown batch.
  List<(AthanorPiece, double)> nextPourOdds(String batchId) {
    final batch = batchById(batchId);
    if (batch == null) return const [];
    return athanorNextPourOdds(batch, _state.drawnIn(batchId));
  }

  /// One pour into [batchId]. Null, with nothing changed, when it is not
  /// allowed: an unknown or finished batch, a daily already taken today,
  /// too little tincture or gold, or a gold pour where they are off.
  Future<AthanorPourResult?> pour(
    String batchId,
    AthanorPayment payment,
  ) async {
    if (!_loaded) await load();
    final batch = batchById(batchId);
    if (batch == null) return null;
    if (payment == AthanorPayment.gold && !goldPoursAvailable) return null;

    AthanorPourResult? result;
    AthanorState? committed;
    try {
      await _db.transaction(() async {
        // Everything is checked before anything is written: an early return
        // after a write would still commit it.
        final state = AthanorState.decode(
          await _db.settingsDao.getSetting(AthanorState.key),
        );
        final today = athanorDayKey(_clock());
        switch (payment) {
          case AthanorPayment.daily:
            if (state.dailyKey == today) return;
          case AthanorPayment.tincture:
            final have = await _db.inventoryDao.getItemQty(
              InvKeys.athanorTincture,
            );
            if (have < kAthanorTincturePerPour) return;
          case AthanorPayment.gold:
            if (await _db.currencyDao.getGoldBalance() < kAthanorGoldPerPour) {
              return;
            }
        }
        final drawn = state.drawnIn(batch.id);
        final piece = athanorDraw(batch, drawn, _random);
        if (piece == null) return;

        switch (payment) {
          case AthanorPayment.daily:
            break;
          case AthanorPayment.tincture:
            await _db.inventoryDao.addItemQty(
              InvKeys.athanorTincture,
              -kAthanorTincturePerPour,
            );
          case AthanorPayment.gold:
            await _db.currencyDao.addGold(-kAthanorGoldPerPour);
        }

        final items = await grantAthanorPiece(_db, piece, random: _random);
        var next = state.withDrawn(batch.id, piece.id);

        AthanorPiece? capstone;
        final done = batch.pieces.every(
          (p) => next.drawnIn(batch.id).contains(p.id),
        );
        if (done && !state.capstones.contains(batch.id)) {
          capstone = batch.capstone;
          await grantAthanorPiece(_db, capstone);
          next = next.copyWith(capstones: {...next.capstones, batch.id});
        }

        AthanorDailyExtras? extras;
        if (payment == AthanorPayment.daily) {
          extras = await _grantDailyExtras();
          next = next.copyWith(dailyKey: today);
        }

        await _db.settingsDao.setSetting(AthanorState.key, next.encode());
        committed = next;
        result = AthanorPourResult(
          batch: batch,
          piece: piece,
          capstone: capstone,
          daily: extras,
          items: items,
        );
      });
    } catch (e, st) {
      // Rolled back, so nothing changed: the same as a pour not allowed.
      debugPrint('Athanor pour failed: $e\n$st');
      return null;
    }

    if (committed == null) return null;
    _state = committed!;
    await _readBalances();
    notifyListeners();
    return result;
  }

  /// The home chest's rewards, rolled as it rolled them: 150–500 silver, a
  /// 15% chance of 1 gold and a 25% chance of a common vial.
  Future<AthanorDailyExtras> _grantDailyExtras() async {
    final silver = 150 + _random.nextInt(351);
    final gold = _random.nextDouble() < 0.15 ? 1 : 0;
    final givesVial = _random.nextDouble() < 0.25;

    await _db.currencyDao.addSilver(silver);
    if (gold > 0) await _db.currencyDao.addGold(gold);
    String? vialGroupName;
    final catalog = _catalog;
    if (givesVial && catalog != null) {
      // Only groups that can yield a common specimen: arcane starts at
      // uncommon, so an arcane worn vial would be a dead item.
      final groups = groupsWithSpecimensAt(
        catalog.creatures,
        VialRarity.common,
      );
      if (groups.isNotEmpty) {
        final group = groups[_random.nextInt(groups.length)];
        await _db.inventoryDao.addVial('Daily Vial', group, VialRarity.common);
        vialGroupName = group.name;
      }
    }
    return AthanorDailyExtras(
      silver: silver,
      gold: gold,
      vialGroupName: vialGroupName,
    );
  }

  /// The day's chest rewards without a draw, for when there is nothing
  /// left to pour into (every batch done, or none yet). It spends the same
  /// day as a daily pour: taking either takes the day. Null, with nothing
  /// changed, when today's daily is already taken.
  Future<AthanorDailyExtras?> takeDailyExtras() async {
    if (!_loaded) await load();
    AthanorDailyExtras? extras;
    AthanorState? committed;
    try {
      await _db.transaction(() async {
        final state = AthanorState.decode(
          await _db.settingsDao.getSetting(AthanorState.key),
        );
        final today = athanorDayKey(_clock());
        if (state.dailyKey == today) return;
        extras = await _grantDailyExtras();
        final next = state.copyWith(dailyKey: today);
        await _db.settingsDao.setSetting(AthanorState.key, next.encode());
        committed = next;
      });
    } catch (e, st) {
      debugPrint('Athanor daily extras failed: $e\n$st');
      return null;
    }
    if (committed == null) return null;
    _state = committed!;
    await _readBalances();
    notifyListeners();
    return extras;
  }

  /// Whether any batch still has a piece to draw. When none has, the daily
  /// is taken with [takeDailyExtras] instead of a pour.
  bool get anyPiecesLeft => _batches.any((b) => !isComplete(b.id));

  /// First fire, the first time the Athanor is opened:
  /// [kAthanorFirstFireTincture], plus 3 for every achievement and dungeon
  /// star claimed before the Athanor existed, up to
  /// [kAthanorFirstFireBackPayCap] ([athanorFirstFireTincture]). Returns
  /// what was given; 0 once it has been taken.
  Future<int> takeFirstFire() async {
    // Star claims are kept beside the stars, in preferences, not the
    // database; read them first.
    final prefs = await SharedPreferences.getInstance();
    final stars = PlanetStarState.deserialise(
      prefs.getString(kPlanetStarsPrefsKey) ?? '',
    );
    var claimedStars = 0;
    for (final mask in stars.claimedMasks.values) {
      for (var i = 0; i < 3; i++) {
        if (mask & (1 << i) != 0) claimedStars++;
      }
    }

    var given = 0;
    var state = AthanorState.empty;
    await _db.transaction(() async {
      state = AthanorState.decode(
        await _db.settingsDao.getSetting(AthanorState.key),
      );
      if (state.firstFire) return;
      Future<int> count(String key) async =>
          int.tryParse(await _db.settingsDao.getSetting(key) ?? '') ?? 0;
      final amount = athanorFirstFireTincture(
        unpaidAchievements:
            await CampaignJournalService.claimedCount(_db) -
            await count(kAthanorPaidAchievementsKey),
        unpaidStars: claimedStars - await count(kAthanorPaidStarsKey),
      );
      await _db.inventoryDao.addItemQty(InvKeys.athanorTincture, amount);
      state = state.copyWith(firstFire: true);
      await _db.settingsDao.setSetting(AthanorState.key, state.encode());
      given = amount;
    });
    _state = state;
    await _readBalances();
    notifyListeners();
    return given;
  }

  /// Whether a pour has given [pieceId], as a piece or a capstone.
  bool ownsPiece(String pieceId) {
    for (final batch in _batches) {
      if (_state.drawnIn(batch.id).contains(pieceId)) return true;
      if (batch.capstone.id == pieceId && _state.capstones.contains(batch.id)) {
        return true;
      }
    }
    return false;
  }
}
