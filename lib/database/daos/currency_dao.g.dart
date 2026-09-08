// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'currency_dao.dart';

// ignore_for_file: type=lint
mixin _$CurrencyDaoMixin on DatabaseAccessor<AlchemonsDatabase> {
  $SettingsTable get settings => attachedDatabase.settings;
  CurrencyDaoManager get managers => CurrencyDaoManager(this);
}

class CurrencyDaoManager {
  final _$CurrencyDaoMixin _db;
  CurrencyDaoManager(this._db);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db.attachedDatabase, _db.settings);
}
