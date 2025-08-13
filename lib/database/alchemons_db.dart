import 'package:drift/drift.dart';

part 'alchemons_db.g.dart';

class PlayerCreatures extends Table {
  TextColumn get id => text()(); // e.g. CR001

  BoolColumn get discovered =>
      boolean().withDefault(const Constant(false))(); // Have we found it?

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [PlayerCreatures])
class AlchemonsDatabase extends _$AlchemonsDatabase {
  AlchemonsDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;

  Future<void> addOrUpdateCreature(PlayerCreaturesCompanion entry) =>
      into(playerCreatures).insertOnConflictUpdate(entry);

  Future<PlayerCreature?> getCreature(String id) => (select(
    playerCreatures,
  )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<List<PlayerCreature>> getAllCreatures() =>
      select(playerCreatures).get();
}
