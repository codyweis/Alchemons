import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/database/schema_tables.dart';
import 'package:drift/drift.dart';

part 'family_mastery_dao.g.dart';

@DriftAccessor(tables: [SurvivalFamilyMasteries, SurvivalFamilyLoadouts])
class FamilyMasteryDao extends DatabaseAccessor<AlchemonsDatabase>
    with _$FamilyMasteryDaoMixin {
  FamilyMasteryDao(super.db);

  Future<SurvivalFamilyMastery?> getFamilyMastery(String familyId) {
    return (select(
      survivalFamilyMasteries,
    )..where((t) => t.familyId.equals(familyId))).getSingleOrNull();
  }

  Future<List<SurvivalFamilyMastery>> getAllFamilyMasteries() {
    return select(survivalFamilyMasteries).get();
  }

  Stream<List<SurvivalFamilyMastery>> watchAllFamilyMasteries() {
    return select(survivalFamilyMasteries).watch();
  }

  Future<void> saveFamilyMastery({
    required String familyId,
    required String purchasedNodeIdsJson,
    required String? selectedPathId,
    required int updatedAtUtcMs,
  }) {
    return into(survivalFamilyMasteries).insertOnConflictUpdate(
      SurvivalFamilyMasteriesCompanion(
        familyId: Value(familyId),
        purchasedNodeIdsJson: Value(purchasedNodeIdsJson),
        selectedPathId: Value(selectedPathId),
        updatedAtUtcMs: Value(updatedAtUtcMs),
      ),
    );
  }

  Future<SurvivalFamilyLoadout?> getLoadout(String instanceId) {
    return (select(
      survivalFamilyLoadouts,
    )..where((t) => t.instanceId.equals(instanceId))).getSingleOrNull();
  }

  Future<List<SurvivalFamilyLoadout>> getLoadouts(
    Iterable<String> instanceIds,
  ) {
    final ids = instanceIds.toSet();
    if (ids.isEmpty) return Future.value(const []);
    return (select(
      survivalFamilyLoadouts,
    )..where((t) => t.instanceId.isIn(ids))).get();
  }

  Stream<List<SurvivalFamilyLoadout>> watchAllLoadouts() {
    return select(survivalFamilyLoadouts).watch();
  }

  Future<List<SurvivalFamilyLoadout>> getAllLoadouts() {
    return select(survivalFamilyLoadouts).get();
  }

  Future<void> saveLoadout({
    required String instanceId,
    required String familyId,
    required String? selectedPathId,
    String? presetName,
    required int updatedAtUtcMs,
  }) {
    return into(survivalFamilyLoadouts).insertOnConflictUpdate(
      SurvivalFamilyLoadoutsCompanion(
        instanceId: Value(instanceId),
        familyId: Value(familyId),
        selectedPathId: Value(selectedPathId),
        presetName: Value(presetName),
        updatedAtUtcMs: Value(updatedAtUtcMs),
      ),
    );
  }

  Future<int> deleteLoadout(String instanceId) {
    return (delete(
      survivalFamilyLoadouts,
    )..where((t) => t.instanceId.equals(instanceId))).go();
  }
}
