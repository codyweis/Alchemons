// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'family_mastery_dao.dart';

// ignore_for_file: type=lint
mixin _$FamilyMasteryDaoMixin on DatabaseAccessor<AlchemonsDatabase> {
  $SurvivalFamilyMasteriesTable get survivalFamilyMasteries =>
      attachedDatabase.survivalFamilyMasteries;
  $SurvivalFamilyLoadoutsTable get survivalFamilyLoadouts =>
      attachedDatabase.survivalFamilyLoadouts;
  FamilyMasteryDaoManager get managers => FamilyMasteryDaoManager(this);
}

class FamilyMasteryDaoManager {
  final _$FamilyMasteryDaoMixin _db;
  FamilyMasteryDaoManager(this._db);
  $$SurvivalFamilyMasteriesTableTableManager get survivalFamilyMasteries =>
      $$SurvivalFamilyMasteriesTableTableManager(
        _db.attachedDatabase,
        _db.survivalFamilyMasteries,
      );
  $$SurvivalFamilyLoadoutsTableTableManager get survivalFamilyLoadouts =>
      $$SurvivalFamilyLoadoutsTableTableManager(
        _db.attachedDatabase,
        _db.survivalFamilyLoadouts,
      );
}
