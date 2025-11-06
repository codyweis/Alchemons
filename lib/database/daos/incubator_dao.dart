// lib/database/daos/incubator_dao.dart
import 'package:drift/drift.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/database/schema_tables.dart';

part 'incubator_dao.g.dart';

@DriftAccessor(tables: [IncubatorSlots, Eggs])
class IncubatorDao extends DatabaseAccessor<AlchemonsDatabase>
    with _$IncubatorDaoMixin {
  IncubatorDao(super.db);

  // =================== INCUBATOR ===================

  Stream<List<IncubatorSlot>> watchSlots() => (select(
    incubatorSlots,
  )..orderBy([(t) => OrderingTerm.asc(t.id)])).watch();

  Future<IncubatorSlot?> firstFreeSlot() {
    final q = (select(incubatorSlots)
      ..where((t) => t.unlocked.equals(true) & t.eggId.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.id)])
      ..limit(1));
    return q.getSingleOrNull();
  }

  Future<void> placeEgg({
    required int slotId,
    required String eggId,
    required String resultCreatureId,
    String? bonusVariantId,
    required String rarity,
    required DateTime hatchAtUtc,
    String? payloadJson,
  }) async {
    await (update(incubatorSlots)..where((t) => t.id.equals(slotId))).write(
      IncubatorSlotsCompanion(
        eggId: Value(eggId),
        resultCreatureId: Value(resultCreatureId),
        bonusVariantId: Value(bonusVariantId),
        rarity: Value(rarity),
        hatchAtUtcMs: Value(hatchAtUtc.toUtc().millisecondsSinceEpoch),
        payloadJson: Value(payloadJson),
      ),
    );
  }

  Future<void> clearEgg(int slotId) async {
    await (update(incubatorSlots)..where((t) => t.id.equals(slotId))).write(
      const IncubatorSlotsCompanion(
        eggId: Value(null),
        resultCreatureId: Value(null),
        bonusVariantId: Value(null),
        rarity: Value(null),
        hatchAtUtcMs: Value(null),
      ),
    );
  }

  Future<void> unlockSlot(int slotId) async {
    await (update(incubatorSlots)..where((t) => t.id.equals(slotId))).write(
      const IncubatorSlotsCompanion(unlocked: Value(true)),
    );
  }

  Future<DateTime?> speedUpSlot({
    required int slotId,
    required Duration delta,
    required DateTime safeNowUtc,
  }) async {
    final row = await (select(
      incubatorSlots,
    )..where((t) => t.id.equals(slotId))).getSingle();
    if (row.eggId == null || row.hatchAtUtcMs == null) return null;

    final current = DateTime.fromMillisecondsSinceEpoch(
      row.hatchAtUtcMs!,
      isUtc: true,
    );
    final target = current.subtract(delta).isBefore(safeNowUtc)
        ? safeNowUtc
        : current.subtract(delta);

    await (update(incubatorSlots)..where((t) => t.id.equals(slotId))).write(
      IncubatorSlotsCompanion(
        hatchAtUtcMs: Value(target.millisecondsSinceEpoch),
      ),
    );
    return target;
  }

  // =================== EGG INVENTORY ===================

  Stream<List<Egg>> watchInventory() =>
      (select(eggs)..orderBy([(t) => OrderingTerm.asc(t.rarity)])).watch();

  /// place in storage
  Future<void> enqueueEgg({
    required String eggId,
    required String resultCreatureId,
    String? bonusVariantId,
    required String rarity,
    required Duration remaining,
    String? payloadJson,
  }) async {
    await into(eggs).insertOnConflictUpdate(
      EggsCompanion(
        eggId: Value(eggId),
        resultCreatureId: Value(resultCreatureId),
        bonusVariantId: Value(bonusVariantId),
        rarity: Value(rarity),
        remainingMs: Value(remaining.inMilliseconds),
        payloadJson: Value(payloadJson),
      ),
    );
  }

  Future<void> removeFromInventory(String eggId) async {
    await (delete(eggs)..where((t) => t.eggId.equals(eggId))).go();
  }
}
