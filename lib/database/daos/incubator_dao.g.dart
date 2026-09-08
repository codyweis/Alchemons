// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'incubator_dao.dart';

// ignore_for_file: type=lint
mixin _$IncubatorDaoMixin on DatabaseAccessor<AlchemonsDatabase> {
  $IncubatorSlotsTable get incubatorSlots => attachedDatabase.incubatorSlots;
  $EggsTable get eggs => attachedDatabase.eggs;
  IncubatorDaoManager get managers => IncubatorDaoManager(this);
}

class IncubatorDaoManager {
  final _$IncubatorDaoMixin _db;
  IncubatorDaoManager(this._db);
  $$IncubatorSlotsTableTableManager get incubatorSlots =>
      $$IncubatorSlotsTableTableManager(
        _db.attachedDatabase,
        _db.incubatorSlots,
      );
  $$EggsTableTableManager get eggs =>
      $$EggsTableTableManager(_db.attachedDatabase, _db.eggs);
}
