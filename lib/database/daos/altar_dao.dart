// lib/database/daos/altar_dao.dart
import 'package:drift/drift.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/database/schema_tables.dart';

part 'altar_dao.g.dart';

@DriftAccessor(tables: [AltarPlacements])
class AltarDao extends DatabaseAccessor<AlchemonsDatabase>
    with _$AltarDaoMixin {
  AltarDao(super.db);

  /// Composite row key for a given boss + species pair.
  static String _key(String bossId, String speciesId) => '$bossId|$speciesId';

  /// Returns all placements for a given boss altar.
  Future<List<AltarPlacement>> getPlacementsForBoss(String bossId) =>
      (select(altarPlacements)..where((t) => t.bossId.equals(bossId))).get();

  /// Streams all placements for a given boss altar (reactive UI).
  Stream<List<AltarPlacement>> watchPlacementsForBoss(String bossId) =>
      (select(altarPlacements)..where((t) => t.bossId.equals(bossId))).watch();

  /// Place a creature instance into a slot.
  /// Call AFTER removing the instance from the regular creature storage.
  /// [snapshotJson] is a JSON-encoded map of the sacrificed creature's
  /// key stats at commit time (natureId, speed, intelligence, strength, beauty).
  Future<void> placeAlchemon({
    required String bossId,
    required String speciesId,
    required String instanceId,
    String? snapshotJson,
  }) async {
    await into(altarPlacements).insertOnConflictUpdate(
      AltarPlacementsCompanion(
        id: Value(_key(bossId, speciesId)),
        bossId: Value(bossId),
        speciesId: Value(speciesId),
        instanceId: Value(instanceId),
        placedAtUtcMs: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
        snapshotJson: Value(snapshotJson),
      ),
    );
  }

  /// Whether a specific (boss, species) slot is already filled.
  Future<bool> isSlotFilled(String bossId, String speciesId) async {
    final row = await (select(
      altarPlacements,
    )..where((t) => t.id.equals(_key(bossId, speciesId)))).getSingleOrNull();
    return row != null;
  }

  /// Clears ALL placements for a boss after a successful summoning.
  Future<void> clearPlacementsForBoss(String bossId) async {
    await (delete(altarPlacements)..where((t) => t.bossId.equals(bossId))).go();
  }

  /// Returns every placement across all altars (for debugging / admin view).
  Future<List<AltarPlacement>> getAllPlacements() =>
      select(altarPlacements).get();

  // ── Relic placement persistence ──────────────────────────────────────────
  // Stored in Settings table via the shared SettingsDao.
  // Key format: 'altar_relic_placed_<bossId>' = '1' / '0'

  static String _relicKey(String bossId) => 'altar_relic_placed_$bossId';

  /// Marks the relic as placed for [bossId].
  Future<void> setRelicPlaced(String bossId) =>
      attachedDatabase.settingsDao.setSetting(_relicKey(bossId), '1');

  /// Clears the relic-placed flag for [bossId] (call after summon).
  Future<void> clearRelicPlaced(String bossId) =>
      attachedDatabase.settingsDao.setSetting(_relicKey(bossId), '0');

  /// Returns the set of boss IDs from [bossIds] that have a relic placed.
  Future<Set<String>> getRelicPlacedIds(List<String> bossIds) async {
    final result = <String>{};
    for (final id in bossIds) {
      final v = await attachedDatabase.settingsDao.getSetting(_relicKey(id));
      if (v == '1') result.add(id);
    }
    return result;
  }
}
