// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'altar_dao.dart';

// ignore_for_file: type=lint
mixin _$AltarDaoMixin on DatabaseAccessor<AlchemonsDatabase> {
  $AltarPlacementsTable get altarPlacements => attachedDatabase.altarPlacements;
  AltarDaoManager get managers => AltarDaoManager(this);
}

class AltarDaoManager {
  final _$AltarDaoMixin _db;
  AltarDaoManager(this._db);
  $$AltarPlacementsTableTableManager get altarPlacements =>
      $$AltarPlacementsTableTableManager(
        _db.attachedDatabase,
        _db.altarPlacements,
      );
}
