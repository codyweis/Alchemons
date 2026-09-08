// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'biome_dao.dart';

// ignore_for_file: type=lint
mixin _$BiomeDaoMixin on DatabaseAccessor<AlchemonsDatabase> {
  $BiomeFarmsTable get biomeFarms => attachedDatabase.biomeFarms;
  $BiomeJobsTable get biomeJobs => attachedDatabase.biomeJobs;
  BiomeDaoManager get managers => BiomeDaoManager(this);
}

class BiomeDaoManager {
  final _$BiomeDaoMixin _db;
  BiomeDaoManager(this._db);
  $$BiomeFarmsTableTableManager get biomeFarms =>
      $$BiomeFarmsTableTableManager(_db.attachedDatabase, _db.biomeFarms);
  $$BiomeJobsTableTableManager get biomeJobs =>
      $$BiomeJobsTableTableManager(_db.attachedDatabase, _db.biomeJobs);
}
