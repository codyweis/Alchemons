// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alchemons_db.dart';

// ignore_for_file: type=lint
class $PlayerCreaturesTable extends PlayerCreatures
    with TableInfo<$PlayerCreaturesTable, PlayerCreature> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayerCreaturesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _discoveredMeta = const VerificationMeta(
    'discovered',
  );
  @override
  late final GeneratedColumn<bool> discovered = GeneratedColumn<bool>(
    'discovered',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("discovered" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, discovered];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'player_creatures';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlayerCreature> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('discovered')) {
      context.handle(
        _discoveredMeta,
        discovered.isAcceptableOrUnknown(data['discovered']!, _discoveredMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlayerCreature map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayerCreature(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      discovered: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}discovered'],
      )!,
    );
  }

  @override
  $PlayerCreaturesTable createAlias(String alias) {
    return $PlayerCreaturesTable(attachedDatabase, alias);
  }
}

class PlayerCreature extends DataClass implements Insertable<PlayerCreature> {
  final String id;
  final bool discovered;
  const PlayerCreature({required this.id, required this.discovered});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['discovered'] = Variable<bool>(discovered);
    return map;
  }

  PlayerCreaturesCompanion toCompanion(bool nullToAbsent) {
    return PlayerCreaturesCompanion(
      id: Value(id),
      discovered: Value(discovered),
    );
  }

  factory PlayerCreature.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayerCreature(
      id: serializer.fromJson<String>(json['id']),
      discovered: serializer.fromJson<bool>(json['discovered']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'discovered': serializer.toJson<bool>(discovered),
    };
  }

  PlayerCreature copyWith({String? id, bool? discovered}) => PlayerCreature(
    id: id ?? this.id,
    discovered: discovered ?? this.discovered,
  );
  PlayerCreature copyWithCompanion(PlayerCreaturesCompanion data) {
    return PlayerCreature(
      id: data.id.present ? data.id.value : this.id,
      discovered: data.discovered.present
          ? data.discovered.value
          : this.discovered,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayerCreature(')
          ..write('id: $id, ')
          ..write('discovered: $discovered')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, discovered);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayerCreature &&
          other.id == this.id &&
          other.discovered == this.discovered);
}

class PlayerCreaturesCompanion extends UpdateCompanion<PlayerCreature> {
  final Value<String> id;
  final Value<bool> discovered;
  final Value<int> rowid;
  const PlayerCreaturesCompanion({
    this.id = const Value.absent(),
    this.discovered = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlayerCreaturesCompanion.insert({
    required String id,
    this.discovered = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<PlayerCreature> custom({
    Expression<String>? id,
    Expression<bool>? discovered,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (discovered != null) 'discovered': discovered,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlayerCreaturesCompanion copyWith({
    Value<String>? id,
    Value<bool>? discovered,
    Value<int>? rowid,
  }) {
    return PlayerCreaturesCompanion(
      id: id ?? this.id,
      discovered: discovered ?? this.discovered,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (discovered.present) {
      map['discovered'] = Variable<bool>(discovered.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayerCreaturesCompanion(')
          ..write('id: $id, ')
          ..write('discovered: $discovered, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AlchemonsDatabase extends GeneratedDatabase {
  _$AlchemonsDatabase(QueryExecutor e) : super(e);
  $AlchemonsDatabaseManager get managers => $AlchemonsDatabaseManager(this);
  late final $PlayerCreaturesTable playerCreatures = $PlayerCreaturesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [playerCreatures];
}

typedef $$PlayerCreaturesTableCreateCompanionBuilder =
    PlayerCreaturesCompanion Function({
      required String id,
      Value<bool> discovered,
      Value<int> rowid,
    });
typedef $$PlayerCreaturesTableUpdateCompanionBuilder =
    PlayerCreaturesCompanion Function({
      Value<String> id,
      Value<bool> discovered,
      Value<int> rowid,
    });

class $$PlayerCreaturesTableFilterComposer
    extends Composer<_$AlchemonsDatabase, $PlayerCreaturesTable> {
  $$PlayerCreaturesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get discovered => $composableBuilder(
    column: $table.discovered,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlayerCreaturesTableOrderingComposer
    extends Composer<_$AlchemonsDatabase, $PlayerCreaturesTable> {
  $$PlayerCreaturesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get discovered => $composableBuilder(
    column: $table.discovered,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlayerCreaturesTableAnnotationComposer
    extends Composer<_$AlchemonsDatabase, $PlayerCreaturesTable> {
  $$PlayerCreaturesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get discovered => $composableBuilder(
    column: $table.discovered,
    builder: (column) => column,
  );
}

class $$PlayerCreaturesTableTableManager
    extends
        RootTableManager<
          _$AlchemonsDatabase,
          $PlayerCreaturesTable,
          PlayerCreature,
          $$PlayerCreaturesTableFilterComposer,
          $$PlayerCreaturesTableOrderingComposer,
          $$PlayerCreaturesTableAnnotationComposer,
          $$PlayerCreaturesTableCreateCompanionBuilder,
          $$PlayerCreaturesTableUpdateCompanionBuilder,
          (
            PlayerCreature,
            BaseReferences<
              _$AlchemonsDatabase,
              $PlayerCreaturesTable,
              PlayerCreature
            >,
          ),
          PlayerCreature,
          PrefetchHooks Function()
        > {
  $$PlayerCreaturesTableTableManager(
    _$AlchemonsDatabase db,
    $PlayerCreaturesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayerCreaturesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayerCreaturesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayerCreaturesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<bool> discovered = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlayerCreaturesCompanion(
                id: id,
                discovered: discovered,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<bool> discovered = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlayerCreaturesCompanion.insert(
                id: id,
                discovered: discovered,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlayerCreaturesTableProcessedTableManager =
    ProcessedTableManager<
      _$AlchemonsDatabase,
      $PlayerCreaturesTable,
      PlayerCreature,
      $$PlayerCreaturesTableFilterComposer,
      $$PlayerCreaturesTableOrderingComposer,
      $$PlayerCreaturesTableAnnotationComposer,
      $$PlayerCreaturesTableCreateCompanionBuilder,
      $$PlayerCreaturesTableUpdateCompanionBuilder,
      (
        PlayerCreature,
        BaseReferences<
          _$AlchemonsDatabase,
          $PlayerCreaturesTable,
          PlayerCreature
        >,
      ),
      PlayerCreature,
      PrefetchHooks Function()
    >;

class $AlchemonsDatabaseManager {
  final _$AlchemonsDatabase _db;
  $AlchemonsDatabaseManager(this._db);
  $$PlayerCreaturesTableTableManager get playerCreatures =>
      $$PlayerCreaturesTableTableManager(_db, _db.playerCreatures);
}
