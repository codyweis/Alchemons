// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'creature_dao.dart';

// ignore_for_file: type=lint
mixin _$CreatureDaoMixin on DatabaseAccessor<AlchemonsDatabase> {
  $PlayerCreaturesTable get playerCreatures => attachedDatabase.playerCreatures;
  $CreatureInstancesTable get creatureInstances =>
      attachedDatabase.creatureInstances;
  $FeedEventsTable get feedEvents => attachedDatabase.feedEvents;
  CreatureDaoManager get managers => CreatureDaoManager(this);
}

class CreatureDaoManager {
  final _$CreatureDaoMixin _db;
  CreatureDaoManager(this._db);
  $$PlayerCreaturesTableTableManager get playerCreatures =>
      $$PlayerCreaturesTableTableManager(
        _db.attachedDatabase,
        _db.playerCreatures,
      );
  $$CreatureInstancesTableTableManager get creatureInstances =>
      $$CreatureInstancesTableTableManager(
        _db.attachedDatabase,
        _db.creatureInstances,
      );
  $$FeedEventsTableTableManager get feedEvents =>
      $$FeedEventsTableTableManager(_db.attachedDatabase, _db.feedEvents);
}
