// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'constellation_dao.dart';

// ignore_for_file: type=lint
mixin _$ConstellationDaoMixin on DatabaseAccessor<AlchemonsDatabase> {
  $BreedingStatisticsTable get breedingStatistics =>
      attachedDatabase.breedingStatistics;
  $ConstellationUnlocksTable get constellationUnlocks =>
      attachedDatabase.constellationUnlocks;
  $ConstellationPointsTable get constellationPoints =>
      attachedDatabase.constellationPoints;
  $ConstellationTransactionsTable get constellationTransactions =>
      attachedDatabase.constellationTransactions;
  ConstellationDaoManager get managers => ConstellationDaoManager(this);
}

class ConstellationDaoManager {
  final _$ConstellationDaoMixin _db;
  ConstellationDaoManager(this._db);
  $$BreedingStatisticsTableTableManager get breedingStatistics =>
      $$BreedingStatisticsTableTableManager(
        _db.attachedDatabase,
        _db.breedingStatistics,
      );
  $$ConstellationUnlocksTableTableManager get constellationUnlocks =>
      $$ConstellationUnlocksTableTableManager(
        _db.attachedDatabase,
        _db.constellationUnlocks,
      );
  $$ConstellationPointsTableTableManager get constellationPoints =>
      $$ConstellationPointsTableTableManager(
        _db.attachedDatabase,
        _db.constellationPoints,
      );
  $$ConstellationTransactionsTableTableManager get constellationTransactions =>
      $$ConstellationTransactionsTableTableManager(
        _db.attachedDatabase,
        _db.constellationTransactions,
      );
}
