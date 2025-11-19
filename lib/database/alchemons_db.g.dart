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
  static const VerificationMeta _natureIdMeta = const VerificationMeta(
    'natureId',
  );
  @override
  late final GeneratedColumn<String> natureId = GeneratedColumn<String>(
    'nature_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, discovered, natureId];
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
    if (data.containsKey('nature_id')) {
      context.handle(
        _natureIdMeta,
        natureId.isAcceptableOrUnknown(data['nature_id']!, _natureIdMeta),
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
      natureId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nature_id'],
      ),
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
  final String? natureId;
  const PlayerCreature({
    required this.id,
    required this.discovered,
    this.natureId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['discovered'] = Variable<bool>(discovered);
    if (!nullToAbsent || natureId != null) {
      map['nature_id'] = Variable<String>(natureId);
    }
    return map;
  }

  PlayerCreaturesCompanion toCompanion(bool nullToAbsent) {
    return PlayerCreaturesCompanion(
      id: Value(id),
      discovered: Value(discovered),
      natureId: natureId == null && nullToAbsent
          ? const Value.absent()
          : Value(natureId),
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
      natureId: serializer.fromJson<String?>(json['natureId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'discovered': serializer.toJson<bool>(discovered),
      'natureId': serializer.toJson<String?>(natureId),
    };
  }

  PlayerCreature copyWith({
    String? id,
    bool? discovered,
    Value<String?> natureId = const Value.absent(),
  }) => PlayerCreature(
    id: id ?? this.id,
    discovered: discovered ?? this.discovered,
    natureId: natureId.present ? natureId.value : this.natureId,
  );
  PlayerCreature copyWithCompanion(PlayerCreaturesCompanion data) {
    return PlayerCreature(
      id: data.id.present ? data.id.value : this.id,
      discovered: data.discovered.present
          ? data.discovered.value
          : this.discovered,
      natureId: data.natureId.present ? data.natureId.value : this.natureId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayerCreature(')
          ..write('id: $id, ')
          ..write('discovered: $discovered, ')
          ..write('natureId: $natureId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, discovered, natureId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayerCreature &&
          other.id == this.id &&
          other.discovered == this.discovered &&
          other.natureId == this.natureId);
}

class PlayerCreaturesCompanion extends UpdateCompanion<PlayerCreature> {
  final Value<String> id;
  final Value<bool> discovered;
  final Value<String?> natureId;
  final Value<int> rowid;
  const PlayerCreaturesCompanion({
    this.id = const Value.absent(),
    this.discovered = const Value.absent(),
    this.natureId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlayerCreaturesCompanion.insert({
    required String id,
    this.discovered = const Value.absent(),
    this.natureId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<PlayerCreature> custom({
    Expression<String>? id,
    Expression<bool>? discovered,
    Expression<String>? natureId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (discovered != null) 'discovered': discovered,
      if (natureId != null) 'nature_id': natureId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlayerCreaturesCompanion copyWith({
    Value<String>? id,
    Value<bool>? discovered,
    Value<String?>? natureId,
    Value<int>? rowid,
  }) {
    return PlayerCreaturesCompanion(
      id: id ?? this.id,
      discovered: discovered ?? this.discovered,
      natureId: natureId ?? this.natureId,
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
    if (natureId.present) {
      map['nature_id'] = Variable<String>(natureId.value);
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
          ..write('natureId: $natureId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IncubatorSlotsTable extends IncubatorSlots
    with TableInfo<$IncubatorSlotsTable, IncubatorSlot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IncubatorSlotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unlockedMeta = const VerificationMeta(
    'unlocked',
  );
  @override
  late final GeneratedColumn<bool> unlocked = GeneratedColumn<bool>(
    'unlocked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("unlocked" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _eggIdMeta = const VerificationMeta('eggId');
  @override
  late final GeneratedColumn<String> eggId = GeneratedColumn<String>(
    'egg_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resultCreatureIdMeta = const VerificationMeta(
    'resultCreatureId',
  );
  @override
  late final GeneratedColumn<String> resultCreatureId = GeneratedColumn<String>(
    'result_creature_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bonusVariantIdMeta = const VerificationMeta(
    'bonusVariantId',
  );
  @override
  late final GeneratedColumn<String> bonusVariantId = GeneratedColumn<String>(
    'bonus_variant_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rarityMeta = const VerificationMeta('rarity');
  @override
  late final GeneratedColumn<String> rarity = GeneratedColumn<String>(
    'rarity',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hatchAtUtcMsMeta = const VerificationMeta(
    'hatchAtUtcMs',
  );
  @override
  late final GeneratedColumn<int> hatchAtUtcMs = GeneratedColumn<int>(
    'hatch_at_utc_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    unlocked,
    eggId,
    resultCreatureId,
    bonusVariantId,
    rarity,
    hatchAtUtcMs,
    payloadJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'incubator_slots';
  @override
  VerificationContext validateIntegrity(
    Insertable<IncubatorSlot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('unlocked')) {
      context.handle(
        _unlockedMeta,
        unlocked.isAcceptableOrUnknown(data['unlocked']!, _unlockedMeta),
      );
    }
    if (data.containsKey('egg_id')) {
      context.handle(
        _eggIdMeta,
        eggId.isAcceptableOrUnknown(data['egg_id']!, _eggIdMeta),
      );
    }
    if (data.containsKey('result_creature_id')) {
      context.handle(
        _resultCreatureIdMeta,
        resultCreatureId.isAcceptableOrUnknown(
          data['result_creature_id']!,
          _resultCreatureIdMeta,
        ),
      );
    }
    if (data.containsKey('bonus_variant_id')) {
      context.handle(
        _bonusVariantIdMeta,
        bonusVariantId.isAcceptableOrUnknown(
          data['bonus_variant_id']!,
          _bonusVariantIdMeta,
        ),
      );
    }
    if (data.containsKey('rarity')) {
      context.handle(
        _rarityMeta,
        rarity.isAcceptableOrUnknown(data['rarity']!, _rarityMeta),
      );
    }
    if (data.containsKey('hatch_at_utc_ms')) {
      context.handle(
        _hatchAtUtcMsMeta,
        hatchAtUtcMs.isAcceptableOrUnknown(
          data['hatch_at_utc_ms']!,
          _hatchAtUtcMsMeta,
        ),
      );
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  IncubatorSlot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IncubatorSlot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      unlocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}unlocked'],
      )!,
      eggId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}egg_id'],
      ),
      resultCreatureId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_creature_id'],
      ),
      bonusVariantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bonus_variant_id'],
      ),
      rarity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rarity'],
      ),
      hatchAtUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hatch_at_utc_ms'],
      ),
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      ),
    );
  }

  @override
  $IncubatorSlotsTable createAlias(String alias) {
    return $IncubatorSlotsTable(attachedDatabase, alias);
  }
}

class IncubatorSlot extends DataClass implements Insertable<IncubatorSlot> {
  final int id;
  final bool unlocked;
  final String? eggId;
  final String? resultCreatureId;
  final String? bonusVariantId;
  final String? rarity;
  final int? hatchAtUtcMs;
  final String? payloadJson;
  const IncubatorSlot({
    required this.id,
    required this.unlocked,
    this.eggId,
    this.resultCreatureId,
    this.bonusVariantId,
    this.rarity,
    this.hatchAtUtcMs,
    this.payloadJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['unlocked'] = Variable<bool>(unlocked);
    if (!nullToAbsent || eggId != null) {
      map['egg_id'] = Variable<String>(eggId);
    }
    if (!nullToAbsent || resultCreatureId != null) {
      map['result_creature_id'] = Variable<String>(resultCreatureId);
    }
    if (!nullToAbsent || bonusVariantId != null) {
      map['bonus_variant_id'] = Variable<String>(bonusVariantId);
    }
    if (!nullToAbsent || rarity != null) {
      map['rarity'] = Variable<String>(rarity);
    }
    if (!nullToAbsent || hatchAtUtcMs != null) {
      map['hatch_at_utc_ms'] = Variable<int>(hatchAtUtcMs);
    }
    if (!nullToAbsent || payloadJson != null) {
      map['payload_json'] = Variable<String>(payloadJson);
    }
    return map;
  }

  IncubatorSlotsCompanion toCompanion(bool nullToAbsent) {
    return IncubatorSlotsCompanion(
      id: Value(id),
      unlocked: Value(unlocked),
      eggId: eggId == null && nullToAbsent
          ? const Value.absent()
          : Value(eggId),
      resultCreatureId: resultCreatureId == null && nullToAbsent
          ? const Value.absent()
          : Value(resultCreatureId),
      bonusVariantId: bonusVariantId == null && nullToAbsent
          ? const Value.absent()
          : Value(bonusVariantId),
      rarity: rarity == null && nullToAbsent
          ? const Value.absent()
          : Value(rarity),
      hatchAtUtcMs: hatchAtUtcMs == null && nullToAbsent
          ? const Value.absent()
          : Value(hatchAtUtcMs),
      payloadJson: payloadJson == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadJson),
    );
  }

  factory IncubatorSlot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IncubatorSlot(
      id: serializer.fromJson<int>(json['id']),
      unlocked: serializer.fromJson<bool>(json['unlocked']),
      eggId: serializer.fromJson<String?>(json['eggId']),
      resultCreatureId: serializer.fromJson<String?>(json['resultCreatureId']),
      bonusVariantId: serializer.fromJson<String?>(json['bonusVariantId']),
      rarity: serializer.fromJson<String?>(json['rarity']),
      hatchAtUtcMs: serializer.fromJson<int?>(json['hatchAtUtcMs']),
      payloadJson: serializer.fromJson<String?>(json['payloadJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'unlocked': serializer.toJson<bool>(unlocked),
      'eggId': serializer.toJson<String?>(eggId),
      'resultCreatureId': serializer.toJson<String?>(resultCreatureId),
      'bonusVariantId': serializer.toJson<String?>(bonusVariantId),
      'rarity': serializer.toJson<String?>(rarity),
      'hatchAtUtcMs': serializer.toJson<int?>(hatchAtUtcMs),
      'payloadJson': serializer.toJson<String?>(payloadJson),
    };
  }

  IncubatorSlot copyWith({
    int? id,
    bool? unlocked,
    Value<String?> eggId = const Value.absent(),
    Value<String?> resultCreatureId = const Value.absent(),
    Value<String?> bonusVariantId = const Value.absent(),
    Value<String?> rarity = const Value.absent(),
    Value<int?> hatchAtUtcMs = const Value.absent(),
    Value<String?> payloadJson = const Value.absent(),
  }) => IncubatorSlot(
    id: id ?? this.id,
    unlocked: unlocked ?? this.unlocked,
    eggId: eggId.present ? eggId.value : this.eggId,
    resultCreatureId: resultCreatureId.present
        ? resultCreatureId.value
        : this.resultCreatureId,
    bonusVariantId: bonusVariantId.present
        ? bonusVariantId.value
        : this.bonusVariantId,
    rarity: rarity.present ? rarity.value : this.rarity,
    hatchAtUtcMs: hatchAtUtcMs.present ? hatchAtUtcMs.value : this.hatchAtUtcMs,
    payloadJson: payloadJson.present ? payloadJson.value : this.payloadJson,
  );
  IncubatorSlot copyWithCompanion(IncubatorSlotsCompanion data) {
    return IncubatorSlot(
      id: data.id.present ? data.id.value : this.id,
      unlocked: data.unlocked.present ? data.unlocked.value : this.unlocked,
      eggId: data.eggId.present ? data.eggId.value : this.eggId,
      resultCreatureId: data.resultCreatureId.present
          ? data.resultCreatureId.value
          : this.resultCreatureId,
      bonusVariantId: data.bonusVariantId.present
          ? data.bonusVariantId.value
          : this.bonusVariantId,
      rarity: data.rarity.present ? data.rarity.value : this.rarity,
      hatchAtUtcMs: data.hatchAtUtcMs.present
          ? data.hatchAtUtcMs.value
          : this.hatchAtUtcMs,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IncubatorSlot(')
          ..write('id: $id, ')
          ..write('unlocked: $unlocked, ')
          ..write('eggId: $eggId, ')
          ..write('resultCreatureId: $resultCreatureId, ')
          ..write('bonusVariantId: $bonusVariantId, ')
          ..write('rarity: $rarity, ')
          ..write('hatchAtUtcMs: $hatchAtUtcMs, ')
          ..write('payloadJson: $payloadJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    unlocked,
    eggId,
    resultCreatureId,
    bonusVariantId,
    rarity,
    hatchAtUtcMs,
    payloadJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IncubatorSlot &&
          other.id == this.id &&
          other.unlocked == this.unlocked &&
          other.eggId == this.eggId &&
          other.resultCreatureId == this.resultCreatureId &&
          other.bonusVariantId == this.bonusVariantId &&
          other.rarity == this.rarity &&
          other.hatchAtUtcMs == this.hatchAtUtcMs &&
          other.payloadJson == this.payloadJson);
}

class IncubatorSlotsCompanion extends UpdateCompanion<IncubatorSlot> {
  final Value<int> id;
  final Value<bool> unlocked;
  final Value<String?> eggId;
  final Value<String?> resultCreatureId;
  final Value<String?> bonusVariantId;
  final Value<String?> rarity;
  final Value<int?> hatchAtUtcMs;
  final Value<String?> payloadJson;
  const IncubatorSlotsCompanion({
    this.id = const Value.absent(),
    this.unlocked = const Value.absent(),
    this.eggId = const Value.absent(),
    this.resultCreatureId = const Value.absent(),
    this.bonusVariantId = const Value.absent(),
    this.rarity = const Value.absent(),
    this.hatchAtUtcMs = const Value.absent(),
    this.payloadJson = const Value.absent(),
  });
  IncubatorSlotsCompanion.insert({
    this.id = const Value.absent(),
    this.unlocked = const Value.absent(),
    this.eggId = const Value.absent(),
    this.resultCreatureId = const Value.absent(),
    this.bonusVariantId = const Value.absent(),
    this.rarity = const Value.absent(),
    this.hatchAtUtcMs = const Value.absent(),
    this.payloadJson = const Value.absent(),
  });
  static Insertable<IncubatorSlot> custom({
    Expression<int>? id,
    Expression<bool>? unlocked,
    Expression<String>? eggId,
    Expression<String>? resultCreatureId,
    Expression<String>? bonusVariantId,
    Expression<String>? rarity,
    Expression<int>? hatchAtUtcMs,
    Expression<String>? payloadJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (unlocked != null) 'unlocked': unlocked,
      if (eggId != null) 'egg_id': eggId,
      if (resultCreatureId != null) 'result_creature_id': resultCreatureId,
      if (bonusVariantId != null) 'bonus_variant_id': bonusVariantId,
      if (rarity != null) 'rarity': rarity,
      if (hatchAtUtcMs != null) 'hatch_at_utc_ms': hatchAtUtcMs,
      if (payloadJson != null) 'payload_json': payloadJson,
    });
  }

  IncubatorSlotsCompanion copyWith({
    Value<int>? id,
    Value<bool>? unlocked,
    Value<String?>? eggId,
    Value<String?>? resultCreatureId,
    Value<String?>? bonusVariantId,
    Value<String?>? rarity,
    Value<int?>? hatchAtUtcMs,
    Value<String?>? payloadJson,
  }) {
    return IncubatorSlotsCompanion(
      id: id ?? this.id,
      unlocked: unlocked ?? this.unlocked,
      eggId: eggId ?? this.eggId,
      resultCreatureId: resultCreatureId ?? this.resultCreatureId,
      bonusVariantId: bonusVariantId ?? this.bonusVariantId,
      rarity: rarity ?? this.rarity,
      hatchAtUtcMs: hatchAtUtcMs ?? this.hatchAtUtcMs,
      payloadJson: payloadJson ?? this.payloadJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (unlocked.present) {
      map['unlocked'] = Variable<bool>(unlocked.value);
    }
    if (eggId.present) {
      map['egg_id'] = Variable<String>(eggId.value);
    }
    if (resultCreatureId.present) {
      map['result_creature_id'] = Variable<String>(resultCreatureId.value);
    }
    if (bonusVariantId.present) {
      map['bonus_variant_id'] = Variable<String>(bonusVariantId.value);
    }
    if (rarity.present) {
      map['rarity'] = Variable<String>(rarity.value);
    }
    if (hatchAtUtcMs.present) {
      map['hatch_at_utc_ms'] = Variable<int>(hatchAtUtcMs.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IncubatorSlotsCompanion(')
          ..write('id: $id, ')
          ..write('unlocked: $unlocked, ')
          ..write('eggId: $eggId, ')
          ..write('resultCreatureId: $resultCreatureId, ')
          ..write('bonusVariantId: $bonusVariantId, ')
          ..write('rarity: $rarity, ')
          ..write('hatchAtUtcMs: $hatchAtUtcMs, ')
          ..write('payloadJson: $payloadJson')
          ..write(')'))
        .toString();
  }
}

class $EggsTable extends Eggs with TableInfo<$EggsTable, Egg> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EggsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eggIdMeta = const VerificationMeta('eggId');
  @override
  late final GeneratedColumn<String> eggId = GeneratedColumn<String>(
    'egg_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resultCreatureIdMeta = const VerificationMeta(
    'resultCreatureId',
  );
  @override
  late final GeneratedColumn<String> resultCreatureId = GeneratedColumn<String>(
    'result_creature_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rarityMeta = const VerificationMeta('rarity');
  @override
  late final GeneratedColumn<String> rarity = GeneratedColumn<String>(
    'rarity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bonusVariantIdMeta = const VerificationMeta(
    'bonusVariantId',
  );
  @override
  late final GeneratedColumn<String> bonusVariantId = GeneratedColumn<String>(
    'bonus_variant_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remainingMsMeta = const VerificationMeta(
    'remainingMs',
  );
  @override
  late final GeneratedColumn<int> remainingMs = GeneratedColumn<int>(
    'remaining_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    eggId,
    resultCreatureId,
    rarity,
    bonusVariantId,
    remainingMs,
    payloadJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'eggs';
  @override
  VerificationContext validateIntegrity(
    Insertable<Egg> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('egg_id')) {
      context.handle(
        _eggIdMeta,
        eggId.isAcceptableOrUnknown(data['egg_id']!, _eggIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eggIdMeta);
    }
    if (data.containsKey('result_creature_id')) {
      context.handle(
        _resultCreatureIdMeta,
        resultCreatureId.isAcceptableOrUnknown(
          data['result_creature_id']!,
          _resultCreatureIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_resultCreatureIdMeta);
    }
    if (data.containsKey('rarity')) {
      context.handle(
        _rarityMeta,
        rarity.isAcceptableOrUnknown(data['rarity']!, _rarityMeta),
      );
    } else if (isInserting) {
      context.missing(_rarityMeta);
    }
    if (data.containsKey('bonus_variant_id')) {
      context.handle(
        _bonusVariantIdMeta,
        bonusVariantId.isAcceptableOrUnknown(
          data['bonus_variant_id']!,
          _bonusVariantIdMeta,
        ),
      );
    }
    if (data.containsKey('remaining_ms')) {
      context.handle(
        _remainingMsMeta,
        remainingMs.isAcceptableOrUnknown(
          data['remaining_ms']!,
          _remainingMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remainingMsMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {eggId};
  @override
  Egg map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Egg(
      eggId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}egg_id'],
      )!,
      resultCreatureId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_creature_id'],
      )!,
      rarity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rarity'],
      )!,
      bonusVariantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bonus_variant_id'],
      ),
      remainingMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remaining_ms'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      ),
    );
  }

  @override
  $EggsTable createAlias(String alias) {
    return $EggsTable(attachedDatabase, alias);
  }
}

class Egg extends DataClass implements Insertable<Egg> {
  final String eggId;
  final String resultCreatureId;
  final String rarity;
  final String? bonusVariantId;
  final int remainingMs;
  final String? payloadJson;
  const Egg({
    required this.eggId,
    required this.resultCreatureId,
    required this.rarity,
    this.bonusVariantId,
    required this.remainingMs,
    this.payloadJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['egg_id'] = Variable<String>(eggId);
    map['result_creature_id'] = Variable<String>(resultCreatureId);
    map['rarity'] = Variable<String>(rarity);
    if (!nullToAbsent || bonusVariantId != null) {
      map['bonus_variant_id'] = Variable<String>(bonusVariantId);
    }
    map['remaining_ms'] = Variable<int>(remainingMs);
    if (!nullToAbsent || payloadJson != null) {
      map['payload_json'] = Variable<String>(payloadJson);
    }
    return map;
  }

  EggsCompanion toCompanion(bool nullToAbsent) {
    return EggsCompanion(
      eggId: Value(eggId),
      resultCreatureId: Value(resultCreatureId),
      rarity: Value(rarity),
      bonusVariantId: bonusVariantId == null && nullToAbsent
          ? const Value.absent()
          : Value(bonusVariantId),
      remainingMs: Value(remainingMs),
      payloadJson: payloadJson == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadJson),
    );
  }

  factory Egg.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Egg(
      eggId: serializer.fromJson<String>(json['eggId']),
      resultCreatureId: serializer.fromJson<String>(json['resultCreatureId']),
      rarity: serializer.fromJson<String>(json['rarity']),
      bonusVariantId: serializer.fromJson<String?>(json['bonusVariantId']),
      remainingMs: serializer.fromJson<int>(json['remainingMs']),
      payloadJson: serializer.fromJson<String?>(json['payloadJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'eggId': serializer.toJson<String>(eggId),
      'resultCreatureId': serializer.toJson<String>(resultCreatureId),
      'rarity': serializer.toJson<String>(rarity),
      'bonusVariantId': serializer.toJson<String?>(bonusVariantId),
      'remainingMs': serializer.toJson<int>(remainingMs),
      'payloadJson': serializer.toJson<String?>(payloadJson),
    };
  }

  Egg copyWith({
    String? eggId,
    String? resultCreatureId,
    String? rarity,
    Value<String?> bonusVariantId = const Value.absent(),
    int? remainingMs,
    Value<String?> payloadJson = const Value.absent(),
  }) => Egg(
    eggId: eggId ?? this.eggId,
    resultCreatureId: resultCreatureId ?? this.resultCreatureId,
    rarity: rarity ?? this.rarity,
    bonusVariantId: bonusVariantId.present
        ? bonusVariantId.value
        : this.bonusVariantId,
    remainingMs: remainingMs ?? this.remainingMs,
    payloadJson: payloadJson.present ? payloadJson.value : this.payloadJson,
  );
  Egg copyWithCompanion(EggsCompanion data) {
    return Egg(
      eggId: data.eggId.present ? data.eggId.value : this.eggId,
      resultCreatureId: data.resultCreatureId.present
          ? data.resultCreatureId.value
          : this.resultCreatureId,
      rarity: data.rarity.present ? data.rarity.value : this.rarity,
      bonusVariantId: data.bonusVariantId.present
          ? data.bonusVariantId.value
          : this.bonusVariantId,
      remainingMs: data.remainingMs.present
          ? data.remainingMs.value
          : this.remainingMs,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Egg(')
          ..write('eggId: $eggId, ')
          ..write('resultCreatureId: $resultCreatureId, ')
          ..write('rarity: $rarity, ')
          ..write('bonusVariantId: $bonusVariantId, ')
          ..write('remainingMs: $remainingMs, ')
          ..write('payloadJson: $payloadJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    eggId,
    resultCreatureId,
    rarity,
    bonusVariantId,
    remainingMs,
    payloadJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Egg &&
          other.eggId == this.eggId &&
          other.resultCreatureId == this.resultCreatureId &&
          other.rarity == this.rarity &&
          other.bonusVariantId == this.bonusVariantId &&
          other.remainingMs == this.remainingMs &&
          other.payloadJson == this.payloadJson);
}

class EggsCompanion extends UpdateCompanion<Egg> {
  final Value<String> eggId;
  final Value<String> resultCreatureId;
  final Value<String> rarity;
  final Value<String?> bonusVariantId;
  final Value<int> remainingMs;
  final Value<String?> payloadJson;
  final Value<int> rowid;
  const EggsCompanion({
    this.eggId = const Value.absent(),
    this.resultCreatureId = const Value.absent(),
    this.rarity = const Value.absent(),
    this.bonusVariantId = const Value.absent(),
    this.remainingMs = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EggsCompanion.insert({
    required String eggId,
    required String resultCreatureId,
    required String rarity,
    this.bonusVariantId = const Value.absent(),
    required int remainingMs,
    this.payloadJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : eggId = Value(eggId),
       resultCreatureId = Value(resultCreatureId),
       rarity = Value(rarity),
       remainingMs = Value(remainingMs);
  static Insertable<Egg> custom({
    Expression<String>? eggId,
    Expression<String>? resultCreatureId,
    Expression<String>? rarity,
    Expression<String>? bonusVariantId,
    Expression<int>? remainingMs,
    Expression<String>? payloadJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (eggId != null) 'egg_id': eggId,
      if (resultCreatureId != null) 'result_creature_id': resultCreatureId,
      if (rarity != null) 'rarity': rarity,
      if (bonusVariantId != null) 'bonus_variant_id': bonusVariantId,
      if (remainingMs != null) 'remaining_ms': remainingMs,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EggsCompanion copyWith({
    Value<String>? eggId,
    Value<String>? resultCreatureId,
    Value<String>? rarity,
    Value<String?>? bonusVariantId,
    Value<int>? remainingMs,
    Value<String?>? payloadJson,
    Value<int>? rowid,
  }) {
    return EggsCompanion(
      eggId: eggId ?? this.eggId,
      resultCreatureId: resultCreatureId ?? this.resultCreatureId,
      rarity: rarity ?? this.rarity,
      bonusVariantId: bonusVariantId ?? this.bonusVariantId,
      remainingMs: remainingMs ?? this.remainingMs,
      payloadJson: payloadJson ?? this.payloadJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eggId.present) {
      map['egg_id'] = Variable<String>(eggId.value);
    }
    if (resultCreatureId.present) {
      map['result_creature_id'] = Variable<String>(resultCreatureId.value);
    }
    if (rarity.present) {
      map['rarity'] = Variable<String>(rarity.value);
    }
    if (bonusVariantId.present) {
      map['bonus_variant_id'] = Variable<String>(bonusVariantId.value);
    }
    if (remainingMs.present) {
      map['remaining_ms'] = Variable<int>(remainingMs.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EggsCompanion(')
          ..write('eggId: $eggId, ')
          ..write('resultCreatureId: $resultCreatureId, ')
          ..write('rarity: $rarity, ')
          ..write('bonusVariantId: $bonusVariantId, ')
          ..write('remainingMs: $remainingMs, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CreatureInstancesTable extends CreatureInstances
    with TableInfo<$CreatureInstancesTable, CreatureInstance> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CreatureInstancesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _instanceIdMeta = const VerificationMeta(
    'instanceId',
  );
  @override
  late final GeneratedColumn<String> instanceId = GeneratedColumn<String>(
    'instance_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseIdMeta = const VerificationMeta('baseId');
  @override
  late final GeneratedColumn<String> baseId = GeneratedColumn<String>(
    'base_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _xpMeta = const VerificationMeta('xp');
  @override
  late final GeneratedColumn<int> xp = GeneratedColumn<int>(
    'xp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lockedMeta = const VerificationMeta('locked');
  @override
  late final GeneratedColumn<bool> locked = GeneratedColumn<bool>(
    'locked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("locked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _nicknameMeta = const VerificationMeta(
    'nickname',
  );
  @override
  late final GeneratedColumn<String> nickname = GeneratedColumn<String>(
    'nickname',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPrismaticSkinMeta = const VerificationMeta(
    'isPrismaticSkin',
  );
  @override
  late final GeneratedColumn<bool> isPrismaticSkin = GeneratedColumn<bool>(
    'is_prismatic_skin',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_prismatic_skin" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _natureIdMeta = const VerificationMeta(
    'natureId',
  );
  @override
  late final GeneratedColumn<String> natureId = GeneratedColumn<String>(
    'nature_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('discovery'),
  );
  static const VerificationMeta _parentageJsonMeta = const VerificationMeta(
    'parentageJson',
  );
  @override
  late final GeneratedColumn<String> parentageJson = GeneratedColumn<String>(
    'parentage_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _geneticsJsonMeta = const VerificationMeta(
    'geneticsJson',
  );
  @override
  late final GeneratedColumn<String> geneticsJson = GeneratedColumn<String>(
    'genetics_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _likelihoodAnalysisJsonMeta =
      const VerificationMeta('likelihoodAnalysisJson');
  @override
  late final GeneratedColumn<String> likelihoodAnalysisJson =
      GeneratedColumn<String>(
        'likelihood_analysis_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _staminaMaxMeta = const VerificationMeta(
    'staminaMax',
  );
  @override
  late final GeneratedColumn<int> staminaMax = GeneratedColumn<int>(
    'stamina_max',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(3),
  );
  static const VerificationMeta _staminaBarsMeta = const VerificationMeta(
    'staminaBars',
  );
  @override
  late final GeneratedColumn<int> staminaBars = GeneratedColumn<int>(
    'stamina_bars',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(3),
  );
  static const VerificationMeta _staminaLastUtcMsMeta = const VerificationMeta(
    'staminaLastUtcMs',
  );
  @override
  late final GeneratedColumn<int> staminaLastUtcMs = GeneratedColumn<int>(
    'stamina_last_utc_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtUtcMsMeta = const VerificationMeta(
    'createdAtUtcMs',
  );
  @override
  late final GeneratedColumn<int> createdAtUtcMs = GeneratedColumn<int>(
    'created_at_utc_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _alchemyEffectMeta = const VerificationMeta(
    'alchemyEffect',
  );
  @override
  late final GeneratedColumn<String> alchemyEffect = GeneratedColumn<String>(
    'alchemy_effect',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statSpeedMeta = const VerificationMeta(
    'statSpeed',
  );
  @override
  late final GeneratedColumn<double> statSpeed = GeneratedColumn<double>(
    'stat_speed',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(3.0),
  );
  static const VerificationMeta _statIntelligenceMeta = const VerificationMeta(
    'statIntelligence',
  );
  @override
  late final GeneratedColumn<double> statIntelligence = GeneratedColumn<double>(
    'stat_intelligence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(3.0),
  );
  static const VerificationMeta _statStrengthMeta = const VerificationMeta(
    'statStrength',
  );
  @override
  late final GeneratedColumn<double> statStrength = GeneratedColumn<double>(
    'stat_strength',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(3.0),
  );
  static const VerificationMeta _statBeautyMeta = const VerificationMeta(
    'statBeauty',
  );
  @override
  late final GeneratedColumn<double> statBeauty = GeneratedColumn<double>(
    'stat_beauty',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(3.0),
  );
  static const VerificationMeta _statSpeedPotentialMeta =
      const VerificationMeta('statSpeedPotential');
  @override
  late final GeneratedColumn<double> statSpeedPotential =
      GeneratedColumn<double>(
        'stat_speed_potential',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(4.0),
      );
  static const VerificationMeta _statIntelligencePotentialMeta =
      const VerificationMeta('statIntelligencePotential');
  @override
  late final GeneratedColumn<double> statIntelligencePotential =
      GeneratedColumn<double>(
        'stat_intelligence_potential',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(4.0),
      );
  static const VerificationMeta _statStrengthPotentialMeta =
      const VerificationMeta('statStrengthPotential');
  @override
  late final GeneratedColumn<double> statStrengthPotential =
      GeneratedColumn<double>(
        'stat_strength_potential',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(4.0),
      );
  static const VerificationMeta _statBeautyPotentialMeta =
      const VerificationMeta('statBeautyPotential');
  @override
  late final GeneratedColumn<double> statBeautyPotential =
      GeneratedColumn<double>(
        'stat_beauty_potential',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(4.0),
      );
  static const VerificationMeta _generationDepthMeta = const VerificationMeta(
    'generationDepth',
  );
  @override
  late final GeneratedColumn<int> generationDepth = GeneratedColumn<int>(
    'generation_depth',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _factionLineageJsonMeta =
      const VerificationMeta('factionLineageJson');
  @override
  late final GeneratedColumn<String> factionLineageJson =
      GeneratedColumn<String>(
        'faction_lineage_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _variantFactionMeta = const VerificationMeta(
    'variantFaction',
  );
  @override
  late final GeneratedColumn<String> variantFaction = GeneratedColumn<String>(
    'variant_faction',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPureMeta = const VerificationMeta('isPure');
  @override
  late final GeneratedColumn<bool> isPure = GeneratedColumn<bool>(
    'is_pure',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pure" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _elementLineageJsonMeta =
      const VerificationMeta('elementLineageJson');
  @override
  late final GeneratedColumn<String> elementLineageJson =
      GeneratedColumn<String>(
        'element_lineage_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _familyLineageJsonMeta = const VerificationMeta(
    'familyLineageJson',
  );
  @override
  late final GeneratedColumn<String> familyLineageJson =
      GeneratedColumn<String>(
        'family_lineage_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    instanceId,
    baseId,
    level,
    xp,
    locked,
    nickname,
    isPrismaticSkin,
    natureId,
    source,
    parentageJson,
    geneticsJson,
    likelihoodAnalysisJson,
    staminaMax,
    staminaBars,
    staminaLastUtcMs,
    createdAtUtcMs,
    alchemyEffect,
    statSpeed,
    statIntelligence,
    statStrength,
    statBeauty,
    statSpeedPotential,
    statIntelligencePotential,
    statStrengthPotential,
    statBeautyPotential,
    generationDepth,
    factionLineageJson,
    variantFaction,
    isPure,
    elementLineageJson,
    familyLineageJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'creature_instances';
  @override
  VerificationContext validateIntegrity(
    Insertable<CreatureInstance> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('instance_id')) {
      context.handle(
        _instanceIdMeta,
        instanceId.isAcceptableOrUnknown(data['instance_id']!, _instanceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_instanceIdMeta);
    }
    if (data.containsKey('base_id')) {
      context.handle(
        _baseIdMeta,
        baseId.isAcceptableOrUnknown(data['base_id']!, _baseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_baseIdMeta);
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    }
    if (data.containsKey('xp')) {
      context.handle(_xpMeta, xp.isAcceptableOrUnknown(data['xp']!, _xpMeta));
    }
    if (data.containsKey('locked')) {
      context.handle(
        _lockedMeta,
        locked.isAcceptableOrUnknown(data['locked']!, _lockedMeta),
      );
    }
    if (data.containsKey('nickname')) {
      context.handle(
        _nicknameMeta,
        nickname.isAcceptableOrUnknown(data['nickname']!, _nicknameMeta),
      );
    }
    if (data.containsKey('is_prismatic_skin')) {
      context.handle(
        _isPrismaticSkinMeta,
        isPrismaticSkin.isAcceptableOrUnknown(
          data['is_prismatic_skin']!,
          _isPrismaticSkinMeta,
        ),
      );
    }
    if (data.containsKey('nature_id')) {
      context.handle(
        _natureIdMeta,
        natureId.isAcceptableOrUnknown(data['nature_id']!, _natureIdMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('parentage_json')) {
      context.handle(
        _parentageJsonMeta,
        parentageJson.isAcceptableOrUnknown(
          data['parentage_json']!,
          _parentageJsonMeta,
        ),
      );
    }
    if (data.containsKey('genetics_json')) {
      context.handle(
        _geneticsJsonMeta,
        geneticsJson.isAcceptableOrUnknown(
          data['genetics_json']!,
          _geneticsJsonMeta,
        ),
      );
    }
    if (data.containsKey('likelihood_analysis_json')) {
      context.handle(
        _likelihoodAnalysisJsonMeta,
        likelihoodAnalysisJson.isAcceptableOrUnknown(
          data['likelihood_analysis_json']!,
          _likelihoodAnalysisJsonMeta,
        ),
      );
    }
    if (data.containsKey('stamina_max')) {
      context.handle(
        _staminaMaxMeta,
        staminaMax.isAcceptableOrUnknown(data['stamina_max']!, _staminaMaxMeta),
      );
    }
    if (data.containsKey('stamina_bars')) {
      context.handle(
        _staminaBarsMeta,
        staminaBars.isAcceptableOrUnknown(
          data['stamina_bars']!,
          _staminaBarsMeta,
        ),
      );
    }
    if (data.containsKey('stamina_last_utc_ms')) {
      context.handle(
        _staminaLastUtcMsMeta,
        staminaLastUtcMs.isAcceptableOrUnknown(
          data['stamina_last_utc_ms']!,
          _staminaLastUtcMsMeta,
        ),
      );
    }
    if (data.containsKey('created_at_utc_ms')) {
      context.handle(
        _createdAtUtcMsMeta,
        createdAtUtcMs.isAcceptableOrUnknown(
          data['created_at_utc_ms']!,
          _createdAtUtcMsMeta,
        ),
      );
    }
    if (data.containsKey('alchemy_effect')) {
      context.handle(
        _alchemyEffectMeta,
        alchemyEffect.isAcceptableOrUnknown(
          data['alchemy_effect']!,
          _alchemyEffectMeta,
        ),
      );
    }
    if (data.containsKey('stat_speed')) {
      context.handle(
        _statSpeedMeta,
        statSpeed.isAcceptableOrUnknown(data['stat_speed']!, _statSpeedMeta),
      );
    }
    if (data.containsKey('stat_intelligence')) {
      context.handle(
        _statIntelligenceMeta,
        statIntelligence.isAcceptableOrUnknown(
          data['stat_intelligence']!,
          _statIntelligenceMeta,
        ),
      );
    }
    if (data.containsKey('stat_strength')) {
      context.handle(
        _statStrengthMeta,
        statStrength.isAcceptableOrUnknown(
          data['stat_strength']!,
          _statStrengthMeta,
        ),
      );
    }
    if (data.containsKey('stat_beauty')) {
      context.handle(
        _statBeautyMeta,
        statBeauty.isAcceptableOrUnknown(data['stat_beauty']!, _statBeautyMeta),
      );
    }
    if (data.containsKey('stat_speed_potential')) {
      context.handle(
        _statSpeedPotentialMeta,
        statSpeedPotential.isAcceptableOrUnknown(
          data['stat_speed_potential']!,
          _statSpeedPotentialMeta,
        ),
      );
    }
    if (data.containsKey('stat_intelligence_potential')) {
      context.handle(
        _statIntelligencePotentialMeta,
        statIntelligencePotential.isAcceptableOrUnknown(
          data['stat_intelligence_potential']!,
          _statIntelligencePotentialMeta,
        ),
      );
    }
    if (data.containsKey('stat_strength_potential')) {
      context.handle(
        _statStrengthPotentialMeta,
        statStrengthPotential.isAcceptableOrUnknown(
          data['stat_strength_potential']!,
          _statStrengthPotentialMeta,
        ),
      );
    }
    if (data.containsKey('stat_beauty_potential')) {
      context.handle(
        _statBeautyPotentialMeta,
        statBeautyPotential.isAcceptableOrUnknown(
          data['stat_beauty_potential']!,
          _statBeautyPotentialMeta,
        ),
      );
    }
    if (data.containsKey('generation_depth')) {
      context.handle(
        _generationDepthMeta,
        generationDepth.isAcceptableOrUnknown(
          data['generation_depth']!,
          _generationDepthMeta,
        ),
      );
    }
    if (data.containsKey('faction_lineage_json')) {
      context.handle(
        _factionLineageJsonMeta,
        factionLineageJson.isAcceptableOrUnknown(
          data['faction_lineage_json']!,
          _factionLineageJsonMeta,
        ),
      );
    }
    if (data.containsKey('variant_faction')) {
      context.handle(
        _variantFactionMeta,
        variantFaction.isAcceptableOrUnknown(
          data['variant_faction']!,
          _variantFactionMeta,
        ),
      );
    }
    if (data.containsKey('is_pure')) {
      context.handle(
        _isPureMeta,
        isPure.isAcceptableOrUnknown(data['is_pure']!, _isPureMeta),
      );
    }
    if (data.containsKey('element_lineage_json')) {
      context.handle(
        _elementLineageJsonMeta,
        elementLineageJson.isAcceptableOrUnknown(
          data['element_lineage_json']!,
          _elementLineageJsonMeta,
        ),
      );
    }
    if (data.containsKey('family_lineage_json')) {
      context.handle(
        _familyLineageJsonMeta,
        familyLineageJson.isAcceptableOrUnknown(
          data['family_lineage_json']!,
          _familyLineageJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {instanceId};
  @override
  CreatureInstance map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CreatureInstance(
      instanceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instance_id'],
      )!,
      baseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_id'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}level'],
      )!,
      xp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}xp'],
      )!,
      locked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}locked'],
      )!,
      nickname: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nickname'],
      ),
      isPrismaticSkin: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_prismatic_skin'],
      )!,
      natureId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nature_id'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      parentageJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parentage_json'],
      ),
      geneticsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genetics_json'],
      ),
      likelihoodAnalysisJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}likelihood_analysis_json'],
      ),
      staminaMax: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stamina_max'],
      )!,
      staminaBars: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stamina_bars'],
      )!,
      staminaLastUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stamina_last_utc_ms'],
      )!,
      createdAtUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc_ms'],
      )!,
      alchemyEffect: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alchemy_effect'],
      ),
      statSpeed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stat_speed'],
      )!,
      statIntelligence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stat_intelligence'],
      )!,
      statStrength: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stat_strength'],
      )!,
      statBeauty: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stat_beauty'],
      )!,
      statSpeedPotential: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stat_speed_potential'],
      )!,
      statIntelligencePotential: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stat_intelligence_potential'],
      )!,
      statStrengthPotential: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stat_strength_potential'],
      )!,
      statBeautyPotential: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stat_beauty_potential'],
      )!,
      generationDepth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}generation_depth'],
      )!,
      factionLineageJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}faction_lineage_json'],
      ),
      variantFaction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variant_faction'],
      ),
      isPure: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pure'],
      )!,
      elementLineageJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}element_lineage_json'],
      ),
      familyLineageJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_lineage_json'],
      ),
    );
  }

  @override
  $CreatureInstancesTable createAlias(String alias) {
    return $CreatureInstancesTable(attachedDatabase, alias);
  }
}

class CreatureInstance extends DataClass
    implements Insertable<CreatureInstance> {
  final String instanceId;
  final String baseId;
  final int level;
  final int xp;
  final bool locked;
  final String? nickname;
  final bool isPrismaticSkin;
  final String? natureId;
  final String source;
  final String? parentageJson;
  final String? geneticsJson;
  final String? likelihoodAnalysisJson;
  final int staminaMax;
  final int staminaBars;
  final int staminaLastUtcMs;
  final int createdAtUtcMs;
  final String? alchemyEffect;
  final double statSpeed;
  final double statIntelligence;
  final double statStrength;
  final double statBeauty;
  final double statSpeedPotential;
  final double statIntelligencePotential;
  final double statStrengthPotential;
  final double statBeautyPotential;
  final int generationDepth;
  final String? factionLineageJson;
  final String? variantFaction;
  final bool isPure;
  final String? elementLineageJson;
  final String? familyLineageJson;
  const CreatureInstance({
    required this.instanceId,
    required this.baseId,
    required this.level,
    required this.xp,
    required this.locked,
    this.nickname,
    required this.isPrismaticSkin,
    this.natureId,
    required this.source,
    this.parentageJson,
    this.geneticsJson,
    this.likelihoodAnalysisJson,
    required this.staminaMax,
    required this.staminaBars,
    required this.staminaLastUtcMs,
    required this.createdAtUtcMs,
    this.alchemyEffect,
    required this.statSpeed,
    required this.statIntelligence,
    required this.statStrength,
    required this.statBeauty,
    required this.statSpeedPotential,
    required this.statIntelligencePotential,
    required this.statStrengthPotential,
    required this.statBeautyPotential,
    required this.generationDepth,
    this.factionLineageJson,
    this.variantFaction,
    required this.isPure,
    this.elementLineageJson,
    this.familyLineageJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['instance_id'] = Variable<String>(instanceId);
    map['base_id'] = Variable<String>(baseId);
    map['level'] = Variable<int>(level);
    map['xp'] = Variable<int>(xp);
    map['locked'] = Variable<bool>(locked);
    if (!nullToAbsent || nickname != null) {
      map['nickname'] = Variable<String>(nickname);
    }
    map['is_prismatic_skin'] = Variable<bool>(isPrismaticSkin);
    if (!nullToAbsent || natureId != null) {
      map['nature_id'] = Variable<String>(natureId);
    }
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || parentageJson != null) {
      map['parentage_json'] = Variable<String>(parentageJson);
    }
    if (!nullToAbsent || geneticsJson != null) {
      map['genetics_json'] = Variable<String>(geneticsJson);
    }
    if (!nullToAbsent || likelihoodAnalysisJson != null) {
      map['likelihood_analysis_json'] = Variable<String>(
        likelihoodAnalysisJson,
      );
    }
    map['stamina_max'] = Variable<int>(staminaMax);
    map['stamina_bars'] = Variable<int>(staminaBars);
    map['stamina_last_utc_ms'] = Variable<int>(staminaLastUtcMs);
    map['created_at_utc_ms'] = Variable<int>(createdAtUtcMs);
    if (!nullToAbsent || alchemyEffect != null) {
      map['alchemy_effect'] = Variable<String>(alchemyEffect);
    }
    map['stat_speed'] = Variable<double>(statSpeed);
    map['stat_intelligence'] = Variable<double>(statIntelligence);
    map['stat_strength'] = Variable<double>(statStrength);
    map['stat_beauty'] = Variable<double>(statBeauty);
    map['stat_speed_potential'] = Variable<double>(statSpeedPotential);
    map['stat_intelligence_potential'] = Variable<double>(
      statIntelligencePotential,
    );
    map['stat_strength_potential'] = Variable<double>(statStrengthPotential);
    map['stat_beauty_potential'] = Variable<double>(statBeautyPotential);
    map['generation_depth'] = Variable<int>(generationDepth);
    if (!nullToAbsent || factionLineageJson != null) {
      map['faction_lineage_json'] = Variable<String>(factionLineageJson);
    }
    if (!nullToAbsent || variantFaction != null) {
      map['variant_faction'] = Variable<String>(variantFaction);
    }
    map['is_pure'] = Variable<bool>(isPure);
    if (!nullToAbsent || elementLineageJson != null) {
      map['element_lineage_json'] = Variable<String>(elementLineageJson);
    }
    if (!nullToAbsent || familyLineageJson != null) {
      map['family_lineage_json'] = Variable<String>(familyLineageJson);
    }
    return map;
  }

  CreatureInstancesCompanion toCompanion(bool nullToAbsent) {
    return CreatureInstancesCompanion(
      instanceId: Value(instanceId),
      baseId: Value(baseId),
      level: Value(level),
      xp: Value(xp),
      locked: Value(locked),
      nickname: nickname == null && nullToAbsent
          ? const Value.absent()
          : Value(nickname),
      isPrismaticSkin: Value(isPrismaticSkin),
      natureId: natureId == null && nullToAbsent
          ? const Value.absent()
          : Value(natureId),
      source: Value(source),
      parentageJson: parentageJson == null && nullToAbsent
          ? const Value.absent()
          : Value(parentageJson),
      geneticsJson: geneticsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(geneticsJson),
      likelihoodAnalysisJson: likelihoodAnalysisJson == null && nullToAbsent
          ? const Value.absent()
          : Value(likelihoodAnalysisJson),
      staminaMax: Value(staminaMax),
      staminaBars: Value(staminaBars),
      staminaLastUtcMs: Value(staminaLastUtcMs),
      createdAtUtcMs: Value(createdAtUtcMs),
      alchemyEffect: alchemyEffect == null && nullToAbsent
          ? const Value.absent()
          : Value(alchemyEffect),
      statSpeed: Value(statSpeed),
      statIntelligence: Value(statIntelligence),
      statStrength: Value(statStrength),
      statBeauty: Value(statBeauty),
      statSpeedPotential: Value(statSpeedPotential),
      statIntelligencePotential: Value(statIntelligencePotential),
      statStrengthPotential: Value(statStrengthPotential),
      statBeautyPotential: Value(statBeautyPotential),
      generationDepth: Value(generationDepth),
      factionLineageJson: factionLineageJson == null && nullToAbsent
          ? const Value.absent()
          : Value(factionLineageJson),
      variantFaction: variantFaction == null && nullToAbsent
          ? const Value.absent()
          : Value(variantFaction),
      isPure: Value(isPure),
      elementLineageJson: elementLineageJson == null && nullToAbsent
          ? const Value.absent()
          : Value(elementLineageJson),
      familyLineageJson: familyLineageJson == null && nullToAbsent
          ? const Value.absent()
          : Value(familyLineageJson),
    );
  }

  factory CreatureInstance.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CreatureInstance(
      instanceId: serializer.fromJson<String>(json['instanceId']),
      baseId: serializer.fromJson<String>(json['baseId']),
      level: serializer.fromJson<int>(json['level']),
      xp: serializer.fromJson<int>(json['xp']),
      locked: serializer.fromJson<bool>(json['locked']),
      nickname: serializer.fromJson<String?>(json['nickname']),
      isPrismaticSkin: serializer.fromJson<bool>(json['isPrismaticSkin']),
      natureId: serializer.fromJson<String?>(json['natureId']),
      source: serializer.fromJson<String>(json['source']),
      parentageJson: serializer.fromJson<String?>(json['parentageJson']),
      geneticsJson: serializer.fromJson<String?>(json['geneticsJson']),
      likelihoodAnalysisJson: serializer.fromJson<String?>(
        json['likelihoodAnalysisJson'],
      ),
      staminaMax: serializer.fromJson<int>(json['staminaMax']),
      staminaBars: serializer.fromJson<int>(json['staminaBars']),
      staminaLastUtcMs: serializer.fromJson<int>(json['staminaLastUtcMs']),
      createdAtUtcMs: serializer.fromJson<int>(json['createdAtUtcMs']),
      alchemyEffect: serializer.fromJson<String?>(json['alchemyEffect']),
      statSpeed: serializer.fromJson<double>(json['statSpeed']),
      statIntelligence: serializer.fromJson<double>(json['statIntelligence']),
      statStrength: serializer.fromJson<double>(json['statStrength']),
      statBeauty: serializer.fromJson<double>(json['statBeauty']),
      statSpeedPotential: serializer.fromJson<double>(
        json['statSpeedPotential'],
      ),
      statIntelligencePotential: serializer.fromJson<double>(
        json['statIntelligencePotential'],
      ),
      statStrengthPotential: serializer.fromJson<double>(
        json['statStrengthPotential'],
      ),
      statBeautyPotential: serializer.fromJson<double>(
        json['statBeautyPotential'],
      ),
      generationDepth: serializer.fromJson<int>(json['generationDepth']),
      factionLineageJson: serializer.fromJson<String?>(
        json['factionLineageJson'],
      ),
      variantFaction: serializer.fromJson<String?>(json['variantFaction']),
      isPure: serializer.fromJson<bool>(json['isPure']),
      elementLineageJson: serializer.fromJson<String?>(
        json['elementLineageJson'],
      ),
      familyLineageJson: serializer.fromJson<String?>(
        json['familyLineageJson'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'instanceId': serializer.toJson<String>(instanceId),
      'baseId': serializer.toJson<String>(baseId),
      'level': serializer.toJson<int>(level),
      'xp': serializer.toJson<int>(xp),
      'locked': serializer.toJson<bool>(locked),
      'nickname': serializer.toJson<String?>(nickname),
      'isPrismaticSkin': serializer.toJson<bool>(isPrismaticSkin),
      'natureId': serializer.toJson<String?>(natureId),
      'source': serializer.toJson<String>(source),
      'parentageJson': serializer.toJson<String?>(parentageJson),
      'geneticsJson': serializer.toJson<String?>(geneticsJson),
      'likelihoodAnalysisJson': serializer.toJson<String?>(
        likelihoodAnalysisJson,
      ),
      'staminaMax': serializer.toJson<int>(staminaMax),
      'staminaBars': serializer.toJson<int>(staminaBars),
      'staminaLastUtcMs': serializer.toJson<int>(staminaLastUtcMs),
      'createdAtUtcMs': serializer.toJson<int>(createdAtUtcMs),
      'alchemyEffect': serializer.toJson<String?>(alchemyEffect),
      'statSpeed': serializer.toJson<double>(statSpeed),
      'statIntelligence': serializer.toJson<double>(statIntelligence),
      'statStrength': serializer.toJson<double>(statStrength),
      'statBeauty': serializer.toJson<double>(statBeauty),
      'statSpeedPotential': serializer.toJson<double>(statSpeedPotential),
      'statIntelligencePotential': serializer.toJson<double>(
        statIntelligencePotential,
      ),
      'statStrengthPotential': serializer.toJson<double>(statStrengthPotential),
      'statBeautyPotential': serializer.toJson<double>(statBeautyPotential),
      'generationDepth': serializer.toJson<int>(generationDepth),
      'factionLineageJson': serializer.toJson<String?>(factionLineageJson),
      'variantFaction': serializer.toJson<String?>(variantFaction),
      'isPure': serializer.toJson<bool>(isPure),
      'elementLineageJson': serializer.toJson<String?>(elementLineageJson),
      'familyLineageJson': serializer.toJson<String?>(familyLineageJson),
    };
  }

  CreatureInstance copyWith({
    String? instanceId,
    String? baseId,
    int? level,
    int? xp,
    bool? locked,
    Value<String?> nickname = const Value.absent(),
    bool? isPrismaticSkin,
    Value<String?> natureId = const Value.absent(),
    String? source,
    Value<String?> parentageJson = const Value.absent(),
    Value<String?> geneticsJson = const Value.absent(),
    Value<String?> likelihoodAnalysisJson = const Value.absent(),
    int? staminaMax,
    int? staminaBars,
    int? staminaLastUtcMs,
    int? createdAtUtcMs,
    Value<String?> alchemyEffect = const Value.absent(),
    double? statSpeed,
    double? statIntelligence,
    double? statStrength,
    double? statBeauty,
    double? statSpeedPotential,
    double? statIntelligencePotential,
    double? statStrengthPotential,
    double? statBeautyPotential,
    int? generationDepth,
    Value<String?> factionLineageJson = const Value.absent(),
    Value<String?> variantFaction = const Value.absent(),
    bool? isPure,
    Value<String?> elementLineageJson = const Value.absent(),
    Value<String?> familyLineageJson = const Value.absent(),
  }) => CreatureInstance(
    instanceId: instanceId ?? this.instanceId,
    baseId: baseId ?? this.baseId,
    level: level ?? this.level,
    xp: xp ?? this.xp,
    locked: locked ?? this.locked,
    nickname: nickname.present ? nickname.value : this.nickname,
    isPrismaticSkin: isPrismaticSkin ?? this.isPrismaticSkin,
    natureId: natureId.present ? natureId.value : this.natureId,
    source: source ?? this.source,
    parentageJson: parentageJson.present
        ? parentageJson.value
        : this.parentageJson,
    geneticsJson: geneticsJson.present ? geneticsJson.value : this.geneticsJson,
    likelihoodAnalysisJson: likelihoodAnalysisJson.present
        ? likelihoodAnalysisJson.value
        : this.likelihoodAnalysisJson,
    staminaMax: staminaMax ?? this.staminaMax,
    staminaBars: staminaBars ?? this.staminaBars,
    staminaLastUtcMs: staminaLastUtcMs ?? this.staminaLastUtcMs,
    createdAtUtcMs: createdAtUtcMs ?? this.createdAtUtcMs,
    alchemyEffect: alchemyEffect.present
        ? alchemyEffect.value
        : this.alchemyEffect,
    statSpeed: statSpeed ?? this.statSpeed,
    statIntelligence: statIntelligence ?? this.statIntelligence,
    statStrength: statStrength ?? this.statStrength,
    statBeauty: statBeauty ?? this.statBeauty,
    statSpeedPotential: statSpeedPotential ?? this.statSpeedPotential,
    statIntelligencePotential:
        statIntelligencePotential ?? this.statIntelligencePotential,
    statStrengthPotential: statStrengthPotential ?? this.statStrengthPotential,
    statBeautyPotential: statBeautyPotential ?? this.statBeautyPotential,
    generationDepth: generationDepth ?? this.generationDepth,
    factionLineageJson: factionLineageJson.present
        ? factionLineageJson.value
        : this.factionLineageJson,
    variantFaction: variantFaction.present
        ? variantFaction.value
        : this.variantFaction,
    isPure: isPure ?? this.isPure,
    elementLineageJson: elementLineageJson.present
        ? elementLineageJson.value
        : this.elementLineageJson,
    familyLineageJson: familyLineageJson.present
        ? familyLineageJson.value
        : this.familyLineageJson,
  );
  CreatureInstance copyWithCompanion(CreatureInstancesCompanion data) {
    return CreatureInstance(
      instanceId: data.instanceId.present
          ? data.instanceId.value
          : this.instanceId,
      baseId: data.baseId.present ? data.baseId.value : this.baseId,
      level: data.level.present ? data.level.value : this.level,
      xp: data.xp.present ? data.xp.value : this.xp,
      locked: data.locked.present ? data.locked.value : this.locked,
      nickname: data.nickname.present ? data.nickname.value : this.nickname,
      isPrismaticSkin: data.isPrismaticSkin.present
          ? data.isPrismaticSkin.value
          : this.isPrismaticSkin,
      natureId: data.natureId.present ? data.natureId.value : this.natureId,
      source: data.source.present ? data.source.value : this.source,
      parentageJson: data.parentageJson.present
          ? data.parentageJson.value
          : this.parentageJson,
      geneticsJson: data.geneticsJson.present
          ? data.geneticsJson.value
          : this.geneticsJson,
      likelihoodAnalysisJson: data.likelihoodAnalysisJson.present
          ? data.likelihoodAnalysisJson.value
          : this.likelihoodAnalysisJson,
      staminaMax: data.staminaMax.present
          ? data.staminaMax.value
          : this.staminaMax,
      staminaBars: data.staminaBars.present
          ? data.staminaBars.value
          : this.staminaBars,
      staminaLastUtcMs: data.staminaLastUtcMs.present
          ? data.staminaLastUtcMs.value
          : this.staminaLastUtcMs,
      createdAtUtcMs: data.createdAtUtcMs.present
          ? data.createdAtUtcMs.value
          : this.createdAtUtcMs,
      alchemyEffect: data.alchemyEffect.present
          ? data.alchemyEffect.value
          : this.alchemyEffect,
      statSpeed: data.statSpeed.present ? data.statSpeed.value : this.statSpeed,
      statIntelligence: data.statIntelligence.present
          ? data.statIntelligence.value
          : this.statIntelligence,
      statStrength: data.statStrength.present
          ? data.statStrength.value
          : this.statStrength,
      statBeauty: data.statBeauty.present
          ? data.statBeauty.value
          : this.statBeauty,
      statSpeedPotential: data.statSpeedPotential.present
          ? data.statSpeedPotential.value
          : this.statSpeedPotential,
      statIntelligencePotential: data.statIntelligencePotential.present
          ? data.statIntelligencePotential.value
          : this.statIntelligencePotential,
      statStrengthPotential: data.statStrengthPotential.present
          ? data.statStrengthPotential.value
          : this.statStrengthPotential,
      statBeautyPotential: data.statBeautyPotential.present
          ? data.statBeautyPotential.value
          : this.statBeautyPotential,
      generationDepth: data.generationDepth.present
          ? data.generationDepth.value
          : this.generationDepth,
      factionLineageJson: data.factionLineageJson.present
          ? data.factionLineageJson.value
          : this.factionLineageJson,
      variantFaction: data.variantFaction.present
          ? data.variantFaction.value
          : this.variantFaction,
      isPure: data.isPure.present ? data.isPure.value : this.isPure,
      elementLineageJson: data.elementLineageJson.present
          ? data.elementLineageJson.value
          : this.elementLineageJson,
      familyLineageJson: data.familyLineageJson.present
          ? data.familyLineageJson.value
          : this.familyLineageJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CreatureInstance(')
          ..write('instanceId: $instanceId, ')
          ..write('baseId: $baseId, ')
          ..write('level: $level, ')
          ..write('xp: $xp, ')
          ..write('locked: $locked, ')
          ..write('nickname: $nickname, ')
          ..write('isPrismaticSkin: $isPrismaticSkin, ')
          ..write('natureId: $natureId, ')
          ..write('source: $source, ')
          ..write('parentageJson: $parentageJson, ')
          ..write('geneticsJson: $geneticsJson, ')
          ..write('likelihoodAnalysisJson: $likelihoodAnalysisJson, ')
          ..write('staminaMax: $staminaMax, ')
          ..write('staminaBars: $staminaBars, ')
          ..write('staminaLastUtcMs: $staminaLastUtcMs, ')
          ..write('createdAtUtcMs: $createdAtUtcMs, ')
          ..write('alchemyEffect: $alchemyEffect, ')
          ..write('statSpeed: $statSpeed, ')
          ..write('statIntelligence: $statIntelligence, ')
          ..write('statStrength: $statStrength, ')
          ..write('statBeauty: $statBeauty, ')
          ..write('statSpeedPotential: $statSpeedPotential, ')
          ..write('statIntelligencePotential: $statIntelligencePotential, ')
          ..write('statStrengthPotential: $statStrengthPotential, ')
          ..write('statBeautyPotential: $statBeautyPotential, ')
          ..write('generationDepth: $generationDepth, ')
          ..write('factionLineageJson: $factionLineageJson, ')
          ..write('variantFaction: $variantFaction, ')
          ..write('isPure: $isPure, ')
          ..write('elementLineageJson: $elementLineageJson, ')
          ..write('familyLineageJson: $familyLineageJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    instanceId,
    baseId,
    level,
    xp,
    locked,
    nickname,
    isPrismaticSkin,
    natureId,
    source,
    parentageJson,
    geneticsJson,
    likelihoodAnalysisJson,
    staminaMax,
    staminaBars,
    staminaLastUtcMs,
    createdAtUtcMs,
    alchemyEffect,
    statSpeed,
    statIntelligence,
    statStrength,
    statBeauty,
    statSpeedPotential,
    statIntelligencePotential,
    statStrengthPotential,
    statBeautyPotential,
    generationDepth,
    factionLineageJson,
    variantFaction,
    isPure,
    elementLineageJson,
    familyLineageJson,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CreatureInstance &&
          other.instanceId == this.instanceId &&
          other.baseId == this.baseId &&
          other.level == this.level &&
          other.xp == this.xp &&
          other.locked == this.locked &&
          other.nickname == this.nickname &&
          other.isPrismaticSkin == this.isPrismaticSkin &&
          other.natureId == this.natureId &&
          other.source == this.source &&
          other.parentageJson == this.parentageJson &&
          other.geneticsJson == this.geneticsJson &&
          other.likelihoodAnalysisJson == this.likelihoodAnalysisJson &&
          other.staminaMax == this.staminaMax &&
          other.staminaBars == this.staminaBars &&
          other.staminaLastUtcMs == this.staminaLastUtcMs &&
          other.createdAtUtcMs == this.createdAtUtcMs &&
          other.alchemyEffect == this.alchemyEffect &&
          other.statSpeed == this.statSpeed &&
          other.statIntelligence == this.statIntelligence &&
          other.statStrength == this.statStrength &&
          other.statBeauty == this.statBeauty &&
          other.statSpeedPotential == this.statSpeedPotential &&
          other.statIntelligencePotential == this.statIntelligencePotential &&
          other.statStrengthPotential == this.statStrengthPotential &&
          other.statBeautyPotential == this.statBeautyPotential &&
          other.generationDepth == this.generationDepth &&
          other.factionLineageJson == this.factionLineageJson &&
          other.variantFaction == this.variantFaction &&
          other.isPure == this.isPure &&
          other.elementLineageJson == this.elementLineageJson &&
          other.familyLineageJson == this.familyLineageJson);
}

class CreatureInstancesCompanion extends UpdateCompanion<CreatureInstance> {
  final Value<String> instanceId;
  final Value<String> baseId;
  final Value<int> level;
  final Value<int> xp;
  final Value<bool> locked;
  final Value<String?> nickname;
  final Value<bool> isPrismaticSkin;
  final Value<String?> natureId;
  final Value<String> source;
  final Value<String?> parentageJson;
  final Value<String?> geneticsJson;
  final Value<String?> likelihoodAnalysisJson;
  final Value<int> staminaMax;
  final Value<int> staminaBars;
  final Value<int> staminaLastUtcMs;
  final Value<int> createdAtUtcMs;
  final Value<String?> alchemyEffect;
  final Value<double> statSpeed;
  final Value<double> statIntelligence;
  final Value<double> statStrength;
  final Value<double> statBeauty;
  final Value<double> statSpeedPotential;
  final Value<double> statIntelligencePotential;
  final Value<double> statStrengthPotential;
  final Value<double> statBeautyPotential;
  final Value<int> generationDepth;
  final Value<String?> factionLineageJson;
  final Value<String?> variantFaction;
  final Value<bool> isPure;
  final Value<String?> elementLineageJson;
  final Value<String?> familyLineageJson;
  final Value<int> rowid;
  const CreatureInstancesCompanion({
    this.instanceId = const Value.absent(),
    this.baseId = const Value.absent(),
    this.level = const Value.absent(),
    this.xp = const Value.absent(),
    this.locked = const Value.absent(),
    this.nickname = const Value.absent(),
    this.isPrismaticSkin = const Value.absent(),
    this.natureId = const Value.absent(),
    this.source = const Value.absent(),
    this.parentageJson = const Value.absent(),
    this.geneticsJson = const Value.absent(),
    this.likelihoodAnalysisJson = const Value.absent(),
    this.staminaMax = const Value.absent(),
    this.staminaBars = const Value.absent(),
    this.staminaLastUtcMs = const Value.absent(),
    this.createdAtUtcMs = const Value.absent(),
    this.alchemyEffect = const Value.absent(),
    this.statSpeed = const Value.absent(),
    this.statIntelligence = const Value.absent(),
    this.statStrength = const Value.absent(),
    this.statBeauty = const Value.absent(),
    this.statSpeedPotential = const Value.absent(),
    this.statIntelligencePotential = const Value.absent(),
    this.statStrengthPotential = const Value.absent(),
    this.statBeautyPotential = const Value.absent(),
    this.generationDepth = const Value.absent(),
    this.factionLineageJson = const Value.absent(),
    this.variantFaction = const Value.absent(),
    this.isPure = const Value.absent(),
    this.elementLineageJson = const Value.absent(),
    this.familyLineageJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CreatureInstancesCompanion.insert({
    required String instanceId,
    required String baseId,
    this.level = const Value.absent(),
    this.xp = const Value.absent(),
    this.locked = const Value.absent(),
    this.nickname = const Value.absent(),
    this.isPrismaticSkin = const Value.absent(),
    this.natureId = const Value.absent(),
    this.source = const Value.absent(),
    this.parentageJson = const Value.absent(),
    this.geneticsJson = const Value.absent(),
    this.likelihoodAnalysisJson = const Value.absent(),
    this.staminaMax = const Value.absent(),
    this.staminaBars = const Value.absent(),
    this.staminaLastUtcMs = const Value.absent(),
    this.createdAtUtcMs = const Value.absent(),
    this.alchemyEffect = const Value.absent(),
    this.statSpeed = const Value.absent(),
    this.statIntelligence = const Value.absent(),
    this.statStrength = const Value.absent(),
    this.statBeauty = const Value.absent(),
    this.statSpeedPotential = const Value.absent(),
    this.statIntelligencePotential = const Value.absent(),
    this.statStrengthPotential = const Value.absent(),
    this.statBeautyPotential = const Value.absent(),
    this.generationDepth = const Value.absent(),
    this.factionLineageJson = const Value.absent(),
    this.variantFaction = const Value.absent(),
    this.isPure = const Value.absent(),
    this.elementLineageJson = const Value.absent(),
    this.familyLineageJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : instanceId = Value(instanceId),
       baseId = Value(baseId);
  static Insertable<CreatureInstance> custom({
    Expression<String>? instanceId,
    Expression<String>? baseId,
    Expression<int>? level,
    Expression<int>? xp,
    Expression<bool>? locked,
    Expression<String>? nickname,
    Expression<bool>? isPrismaticSkin,
    Expression<String>? natureId,
    Expression<String>? source,
    Expression<String>? parentageJson,
    Expression<String>? geneticsJson,
    Expression<String>? likelihoodAnalysisJson,
    Expression<int>? staminaMax,
    Expression<int>? staminaBars,
    Expression<int>? staminaLastUtcMs,
    Expression<int>? createdAtUtcMs,
    Expression<String>? alchemyEffect,
    Expression<double>? statSpeed,
    Expression<double>? statIntelligence,
    Expression<double>? statStrength,
    Expression<double>? statBeauty,
    Expression<double>? statSpeedPotential,
    Expression<double>? statIntelligencePotential,
    Expression<double>? statStrengthPotential,
    Expression<double>? statBeautyPotential,
    Expression<int>? generationDepth,
    Expression<String>? factionLineageJson,
    Expression<String>? variantFaction,
    Expression<bool>? isPure,
    Expression<String>? elementLineageJson,
    Expression<String>? familyLineageJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (instanceId != null) 'instance_id': instanceId,
      if (baseId != null) 'base_id': baseId,
      if (level != null) 'level': level,
      if (xp != null) 'xp': xp,
      if (locked != null) 'locked': locked,
      if (nickname != null) 'nickname': nickname,
      if (isPrismaticSkin != null) 'is_prismatic_skin': isPrismaticSkin,
      if (natureId != null) 'nature_id': natureId,
      if (source != null) 'source': source,
      if (parentageJson != null) 'parentage_json': parentageJson,
      if (geneticsJson != null) 'genetics_json': geneticsJson,
      if (likelihoodAnalysisJson != null)
        'likelihood_analysis_json': likelihoodAnalysisJson,
      if (staminaMax != null) 'stamina_max': staminaMax,
      if (staminaBars != null) 'stamina_bars': staminaBars,
      if (staminaLastUtcMs != null) 'stamina_last_utc_ms': staminaLastUtcMs,
      if (createdAtUtcMs != null) 'created_at_utc_ms': createdAtUtcMs,
      if (alchemyEffect != null) 'alchemy_effect': alchemyEffect,
      if (statSpeed != null) 'stat_speed': statSpeed,
      if (statIntelligence != null) 'stat_intelligence': statIntelligence,
      if (statStrength != null) 'stat_strength': statStrength,
      if (statBeauty != null) 'stat_beauty': statBeauty,
      if (statSpeedPotential != null)
        'stat_speed_potential': statSpeedPotential,
      if (statIntelligencePotential != null)
        'stat_intelligence_potential': statIntelligencePotential,
      if (statStrengthPotential != null)
        'stat_strength_potential': statStrengthPotential,
      if (statBeautyPotential != null)
        'stat_beauty_potential': statBeautyPotential,
      if (generationDepth != null) 'generation_depth': generationDepth,
      if (factionLineageJson != null)
        'faction_lineage_json': factionLineageJson,
      if (variantFaction != null) 'variant_faction': variantFaction,
      if (isPure != null) 'is_pure': isPure,
      if (elementLineageJson != null)
        'element_lineage_json': elementLineageJson,
      if (familyLineageJson != null) 'family_lineage_json': familyLineageJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CreatureInstancesCompanion copyWith({
    Value<String>? instanceId,
    Value<String>? baseId,
    Value<int>? level,
    Value<int>? xp,
    Value<bool>? locked,
    Value<String?>? nickname,
    Value<bool>? isPrismaticSkin,
    Value<String?>? natureId,
    Value<String>? source,
    Value<String?>? parentageJson,
    Value<String?>? geneticsJson,
    Value<String?>? likelihoodAnalysisJson,
    Value<int>? staminaMax,
    Value<int>? staminaBars,
    Value<int>? staminaLastUtcMs,
    Value<int>? createdAtUtcMs,
    Value<String?>? alchemyEffect,
    Value<double>? statSpeed,
    Value<double>? statIntelligence,
    Value<double>? statStrength,
    Value<double>? statBeauty,
    Value<double>? statSpeedPotential,
    Value<double>? statIntelligencePotential,
    Value<double>? statStrengthPotential,
    Value<double>? statBeautyPotential,
    Value<int>? generationDepth,
    Value<String?>? factionLineageJson,
    Value<String?>? variantFaction,
    Value<bool>? isPure,
    Value<String?>? elementLineageJson,
    Value<String?>? familyLineageJson,
    Value<int>? rowid,
  }) {
    return CreatureInstancesCompanion(
      instanceId: instanceId ?? this.instanceId,
      baseId: baseId ?? this.baseId,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      locked: locked ?? this.locked,
      nickname: nickname ?? this.nickname,
      isPrismaticSkin: isPrismaticSkin ?? this.isPrismaticSkin,
      natureId: natureId ?? this.natureId,
      source: source ?? this.source,
      parentageJson: parentageJson ?? this.parentageJson,
      geneticsJson: geneticsJson ?? this.geneticsJson,
      likelihoodAnalysisJson:
          likelihoodAnalysisJson ?? this.likelihoodAnalysisJson,
      staminaMax: staminaMax ?? this.staminaMax,
      staminaBars: staminaBars ?? this.staminaBars,
      staminaLastUtcMs: staminaLastUtcMs ?? this.staminaLastUtcMs,
      createdAtUtcMs: createdAtUtcMs ?? this.createdAtUtcMs,
      alchemyEffect: alchemyEffect ?? this.alchemyEffect,
      statSpeed: statSpeed ?? this.statSpeed,
      statIntelligence: statIntelligence ?? this.statIntelligence,
      statStrength: statStrength ?? this.statStrength,
      statBeauty: statBeauty ?? this.statBeauty,
      statSpeedPotential: statSpeedPotential ?? this.statSpeedPotential,
      statIntelligencePotential:
          statIntelligencePotential ?? this.statIntelligencePotential,
      statStrengthPotential:
          statStrengthPotential ?? this.statStrengthPotential,
      statBeautyPotential: statBeautyPotential ?? this.statBeautyPotential,
      generationDepth: generationDepth ?? this.generationDepth,
      factionLineageJson: factionLineageJson ?? this.factionLineageJson,
      variantFaction: variantFaction ?? this.variantFaction,
      isPure: isPure ?? this.isPure,
      elementLineageJson: elementLineageJson ?? this.elementLineageJson,
      familyLineageJson: familyLineageJson ?? this.familyLineageJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (instanceId.present) {
      map['instance_id'] = Variable<String>(instanceId.value);
    }
    if (baseId.present) {
      map['base_id'] = Variable<String>(baseId.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    if (xp.present) {
      map['xp'] = Variable<int>(xp.value);
    }
    if (locked.present) {
      map['locked'] = Variable<bool>(locked.value);
    }
    if (nickname.present) {
      map['nickname'] = Variable<String>(nickname.value);
    }
    if (isPrismaticSkin.present) {
      map['is_prismatic_skin'] = Variable<bool>(isPrismaticSkin.value);
    }
    if (natureId.present) {
      map['nature_id'] = Variable<String>(natureId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (parentageJson.present) {
      map['parentage_json'] = Variable<String>(parentageJson.value);
    }
    if (geneticsJson.present) {
      map['genetics_json'] = Variable<String>(geneticsJson.value);
    }
    if (likelihoodAnalysisJson.present) {
      map['likelihood_analysis_json'] = Variable<String>(
        likelihoodAnalysisJson.value,
      );
    }
    if (staminaMax.present) {
      map['stamina_max'] = Variable<int>(staminaMax.value);
    }
    if (staminaBars.present) {
      map['stamina_bars'] = Variable<int>(staminaBars.value);
    }
    if (staminaLastUtcMs.present) {
      map['stamina_last_utc_ms'] = Variable<int>(staminaLastUtcMs.value);
    }
    if (createdAtUtcMs.present) {
      map['created_at_utc_ms'] = Variable<int>(createdAtUtcMs.value);
    }
    if (alchemyEffect.present) {
      map['alchemy_effect'] = Variable<String>(alchemyEffect.value);
    }
    if (statSpeed.present) {
      map['stat_speed'] = Variable<double>(statSpeed.value);
    }
    if (statIntelligence.present) {
      map['stat_intelligence'] = Variable<double>(statIntelligence.value);
    }
    if (statStrength.present) {
      map['stat_strength'] = Variable<double>(statStrength.value);
    }
    if (statBeauty.present) {
      map['stat_beauty'] = Variable<double>(statBeauty.value);
    }
    if (statSpeedPotential.present) {
      map['stat_speed_potential'] = Variable<double>(statSpeedPotential.value);
    }
    if (statIntelligencePotential.present) {
      map['stat_intelligence_potential'] = Variable<double>(
        statIntelligencePotential.value,
      );
    }
    if (statStrengthPotential.present) {
      map['stat_strength_potential'] = Variable<double>(
        statStrengthPotential.value,
      );
    }
    if (statBeautyPotential.present) {
      map['stat_beauty_potential'] = Variable<double>(
        statBeautyPotential.value,
      );
    }
    if (generationDepth.present) {
      map['generation_depth'] = Variable<int>(generationDepth.value);
    }
    if (factionLineageJson.present) {
      map['faction_lineage_json'] = Variable<String>(factionLineageJson.value);
    }
    if (variantFaction.present) {
      map['variant_faction'] = Variable<String>(variantFaction.value);
    }
    if (isPure.present) {
      map['is_pure'] = Variable<bool>(isPure.value);
    }
    if (elementLineageJson.present) {
      map['element_lineage_json'] = Variable<String>(elementLineageJson.value);
    }
    if (familyLineageJson.present) {
      map['family_lineage_json'] = Variable<String>(familyLineageJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CreatureInstancesCompanion(')
          ..write('instanceId: $instanceId, ')
          ..write('baseId: $baseId, ')
          ..write('level: $level, ')
          ..write('xp: $xp, ')
          ..write('locked: $locked, ')
          ..write('nickname: $nickname, ')
          ..write('isPrismaticSkin: $isPrismaticSkin, ')
          ..write('natureId: $natureId, ')
          ..write('source: $source, ')
          ..write('parentageJson: $parentageJson, ')
          ..write('geneticsJson: $geneticsJson, ')
          ..write('likelihoodAnalysisJson: $likelihoodAnalysisJson, ')
          ..write('staminaMax: $staminaMax, ')
          ..write('staminaBars: $staminaBars, ')
          ..write('staminaLastUtcMs: $staminaLastUtcMs, ')
          ..write('createdAtUtcMs: $createdAtUtcMs, ')
          ..write('alchemyEffect: $alchemyEffect, ')
          ..write('statSpeed: $statSpeed, ')
          ..write('statIntelligence: $statIntelligence, ')
          ..write('statStrength: $statStrength, ')
          ..write('statBeauty: $statBeauty, ')
          ..write('statSpeedPotential: $statSpeedPotential, ')
          ..write('statIntelligencePotential: $statIntelligencePotential, ')
          ..write('statStrengthPotential: $statStrengthPotential, ')
          ..write('statBeautyPotential: $statBeautyPotential, ')
          ..write('generationDepth: $generationDepth, ')
          ..write('factionLineageJson: $factionLineageJson, ')
          ..write('variantFaction: $variantFaction, ')
          ..write('isPure: $isPure, ')
          ..write('elementLineageJson: $elementLineageJson, ')
          ..write('familyLineageJson: $familyLineageJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FeedEventsTable extends FeedEvents
    with TableInfo<$FeedEventsTable, FeedEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FeedEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetInstanceIdMeta = const VerificationMeta(
    'targetInstanceId',
  );
  @override
  late final GeneratedColumn<String> targetInstanceId = GeneratedColumn<String>(
    'target_instance_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fodderInstanceIdMeta = const VerificationMeta(
    'fodderInstanceId',
  );
  @override
  late final GeneratedColumn<String> fodderInstanceId = GeneratedColumn<String>(
    'fodder_instance_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _xpGainedMeta = const VerificationMeta(
    'xpGained',
  );
  @override
  late final GeneratedColumn<int> xpGained = GeneratedColumn<int>(
    'xp_gained',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtUtcMsMeta = const VerificationMeta(
    'createdAtUtcMs',
  );
  @override
  late final GeneratedColumn<int> createdAtUtcMs = GeneratedColumn<int>(
    'created_at_utc_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    eventId,
    targetInstanceId,
    fodderInstanceId,
    xpGained,
    createdAtUtcMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'feed_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<FeedEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('target_instance_id')) {
      context.handle(
        _targetInstanceIdMeta,
        targetInstanceId.isAcceptableOrUnknown(
          data['target_instance_id']!,
          _targetInstanceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetInstanceIdMeta);
    }
    if (data.containsKey('fodder_instance_id')) {
      context.handle(
        _fodderInstanceIdMeta,
        fodderInstanceId.isAcceptableOrUnknown(
          data['fodder_instance_id']!,
          _fodderInstanceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fodderInstanceIdMeta);
    }
    if (data.containsKey('xp_gained')) {
      context.handle(
        _xpGainedMeta,
        xpGained.isAcceptableOrUnknown(data['xp_gained']!, _xpGainedMeta),
      );
    } else if (isInserting) {
      context.missing(_xpGainedMeta);
    }
    if (data.containsKey('created_at_utc_ms')) {
      context.handle(
        _createdAtUtcMsMeta,
        createdAtUtcMs.isAcceptableOrUnknown(
          data['created_at_utc_ms']!,
          _createdAtUtcMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {eventId};
  @override
  FeedEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FeedEvent(
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      targetInstanceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_instance_id'],
      )!,
      fodderInstanceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fodder_instance_id'],
      )!,
      xpGained: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}xp_gained'],
      )!,
      createdAtUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc_ms'],
      )!,
    );
  }

  @override
  $FeedEventsTable createAlias(String alias) {
    return $FeedEventsTable(attachedDatabase, alias);
  }
}

class FeedEvent extends DataClass implements Insertable<FeedEvent> {
  final String eventId;
  final String targetInstanceId;
  final String fodderInstanceId;
  final int xpGained;
  final int createdAtUtcMs;
  const FeedEvent({
    required this.eventId,
    required this.targetInstanceId,
    required this.fodderInstanceId,
    required this.xpGained,
    required this.createdAtUtcMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['event_id'] = Variable<String>(eventId);
    map['target_instance_id'] = Variable<String>(targetInstanceId);
    map['fodder_instance_id'] = Variable<String>(fodderInstanceId);
    map['xp_gained'] = Variable<int>(xpGained);
    map['created_at_utc_ms'] = Variable<int>(createdAtUtcMs);
    return map;
  }

  FeedEventsCompanion toCompanion(bool nullToAbsent) {
    return FeedEventsCompanion(
      eventId: Value(eventId),
      targetInstanceId: Value(targetInstanceId),
      fodderInstanceId: Value(fodderInstanceId),
      xpGained: Value(xpGained),
      createdAtUtcMs: Value(createdAtUtcMs),
    );
  }

  factory FeedEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FeedEvent(
      eventId: serializer.fromJson<String>(json['eventId']),
      targetInstanceId: serializer.fromJson<String>(json['targetInstanceId']),
      fodderInstanceId: serializer.fromJson<String>(json['fodderInstanceId']),
      xpGained: serializer.fromJson<int>(json['xpGained']),
      createdAtUtcMs: serializer.fromJson<int>(json['createdAtUtcMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'eventId': serializer.toJson<String>(eventId),
      'targetInstanceId': serializer.toJson<String>(targetInstanceId),
      'fodderInstanceId': serializer.toJson<String>(fodderInstanceId),
      'xpGained': serializer.toJson<int>(xpGained),
      'createdAtUtcMs': serializer.toJson<int>(createdAtUtcMs),
    };
  }

  FeedEvent copyWith({
    String? eventId,
    String? targetInstanceId,
    String? fodderInstanceId,
    int? xpGained,
    int? createdAtUtcMs,
  }) => FeedEvent(
    eventId: eventId ?? this.eventId,
    targetInstanceId: targetInstanceId ?? this.targetInstanceId,
    fodderInstanceId: fodderInstanceId ?? this.fodderInstanceId,
    xpGained: xpGained ?? this.xpGained,
    createdAtUtcMs: createdAtUtcMs ?? this.createdAtUtcMs,
  );
  FeedEvent copyWithCompanion(FeedEventsCompanion data) {
    return FeedEvent(
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      targetInstanceId: data.targetInstanceId.present
          ? data.targetInstanceId.value
          : this.targetInstanceId,
      fodderInstanceId: data.fodderInstanceId.present
          ? data.fodderInstanceId.value
          : this.fodderInstanceId,
      xpGained: data.xpGained.present ? data.xpGained.value : this.xpGained,
      createdAtUtcMs: data.createdAtUtcMs.present
          ? data.createdAtUtcMs.value
          : this.createdAtUtcMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FeedEvent(')
          ..write('eventId: $eventId, ')
          ..write('targetInstanceId: $targetInstanceId, ')
          ..write('fodderInstanceId: $fodderInstanceId, ')
          ..write('xpGained: $xpGained, ')
          ..write('createdAtUtcMs: $createdAtUtcMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    eventId,
    targetInstanceId,
    fodderInstanceId,
    xpGained,
    createdAtUtcMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FeedEvent &&
          other.eventId == this.eventId &&
          other.targetInstanceId == this.targetInstanceId &&
          other.fodderInstanceId == this.fodderInstanceId &&
          other.xpGained == this.xpGained &&
          other.createdAtUtcMs == this.createdAtUtcMs);
}

class FeedEventsCompanion extends UpdateCompanion<FeedEvent> {
  final Value<String> eventId;
  final Value<String> targetInstanceId;
  final Value<String> fodderInstanceId;
  final Value<int> xpGained;
  final Value<int> createdAtUtcMs;
  final Value<int> rowid;
  const FeedEventsCompanion({
    this.eventId = const Value.absent(),
    this.targetInstanceId = const Value.absent(),
    this.fodderInstanceId = const Value.absent(),
    this.xpGained = const Value.absent(),
    this.createdAtUtcMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FeedEventsCompanion.insert({
    required String eventId,
    required String targetInstanceId,
    required String fodderInstanceId,
    required int xpGained,
    required int createdAtUtcMs,
    this.rowid = const Value.absent(),
  }) : eventId = Value(eventId),
       targetInstanceId = Value(targetInstanceId),
       fodderInstanceId = Value(fodderInstanceId),
       xpGained = Value(xpGained),
       createdAtUtcMs = Value(createdAtUtcMs);
  static Insertable<FeedEvent> custom({
    Expression<String>? eventId,
    Expression<String>? targetInstanceId,
    Expression<String>? fodderInstanceId,
    Expression<int>? xpGained,
    Expression<int>? createdAtUtcMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (eventId != null) 'event_id': eventId,
      if (targetInstanceId != null) 'target_instance_id': targetInstanceId,
      if (fodderInstanceId != null) 'fodder_instance_id': fodderInstanceId,
      if (xpGained != null) 'xp_gained': xpGained,
      if (createdAtUtcMs != null) 'created_at_utc_ms': createdAtUtcMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FeedEventsCompanion copyWith({
    Value<String>? eventId,
    Value<String>? targetInstanceId,
    Value<String>? fodderInstanceId,
    Value<int>? xpGained,
    Value<int>? createdAtUtcMs,
    Value<int>? rowid,
  }) {
    return FeedEventsCompanion(
      eventId: eventId ?? this.eventId,
      targetInstanceId: targetInstanceId ?? this.targetInstanceId,
      fodderInstanceId: fodderInstanceId ?? this.fodderInstanceId,
      xpGained: xpGained ?? this.xpGained,
      createdAtUtcMs: createdAtUtcMs ?? this.createdAtUtcMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (targetInstanceId.present) {
      map['target_instance_id'] = Variable<String>(targetInstanceId.value);
    }
    if (fodderInstanceId.present) {
      map['fodder_instance_id'] = Variable<String>(fodderInstanceId.value);
    }
    if (xpGained.present) {
      map['xp_gained'] = Variable<int>(xpGained.value);
    }
    if (createdAtUtcMs.present) {
      map['created_at_utc_ms'] = Variable<int>(createdAtUtcMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FeedEventsCompanion(')
          ..write('eventId: $eventId, ')
          ..write('targetInstanceId: $targetInstanceId, ')
          ..write('fodderInstanceId: $fodderInstanceId, ')
          ..write('xpGained: $xpGained, ')
          ..write('createdAtUtcMs: $createdAtUtcMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BiomeFarmsTable extends BiomeFarms
    with TableInfo<$BiomeFarmsTable, BiomeFarm> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BiomeFarmsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _biomeIdMeta = const VerificationMeta(
    'biomeId',
  );
  @override
  late final GeneratedColumn<String> biomeId = GeneratedColumn<String>(
    'biome_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unlockedMeta = const VerificationMeta(
    'unlocked',
  );
  @override
  late final GeneratedColumn<bool> unlocked = GeneratedColumn<bool>(
    'unlocked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("unlocked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _activeElementIdMeta = const VerificationMeta(
    'activeElementId',
  );
  @override
  late final GeneratedColumn<String> activeElementId = GeneratedColumn<String>(
    'active_element_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    biomeId,
    unlocked,
    level,
    activeElementId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'biome_farms';
  @override
  VerificationContext validateIntegrity(
    Insertable<BiomeFarm> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('biome_id')) {
      context.handle(
        _biomeIdMeta,
        biomeId.isAcceptableOrUnknown(data['biome_id']!, _biomeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_biomeIdMeta);
    }
    if (data.containsKey('unlocked')) {
      context.handle(
        _unlockedMeta,
        unlocked.isAcceptableOrUnknown(data['unlocked']!, _unlockedMeta),
      );
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    }
    if (data.containsKey('active_element_id')) {
      context.handle(
        _activeElementIdMeta,
        activeElementId.isAcceptableOrUnknown(
          data['active_element_id']!,
          _activeElementIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BiomeFarm map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BiomeFarm(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      biomeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}biome_id'],
      )!,
      unlocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}unlocked'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}level'],
      )!,
      activeElementId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}active_element_id'],
      ),
    );
  }

  @override
  $BiomeFarmsTable createAlias(String alias) {
    return $BiomeFarmsTable(attachedDatabase, alias);
  }
}

class BiomeFarm extends DataClass implements Insertable<BiomeFarm> {
  final int id;
  final String biomeId;
  final bool unlocked;
  final int level;
  final String? activeElementId;
  const BiomeFarm({
    required this.id,
    required this.biomeId,
    required this.unlocked,
    required this.level,
    this.activeElementId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['biome_id'] = Variable<String>(biomeId);
    map['unlocked'] = Variable<bool>(unlocked);
    map['level'] = Variable<int>(level);
    if (!nullToAbsent || activeElementId != null) {
      map['active_element_id'] = Variable<String>(activeElementId);
    }
    return map;
  }

  BiomeFarmsCompanion toCompanion(bool nullToAbsent) {
    return BiomeFarmsCompanion(
      id: Value(id),
      biomeId: Value(biomeId),
      unlocked: Value(unlocked),
      level: Value(level),
      activeElementId: activeElementId == null && nullToAbsent
          ? const Value.absent()
          : Value(activeElementId),
    );
  }

  factory BiomeFarm.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BiomeFarm(
      id: serializer.fromJson<int>(json['id']),
      biomeId: serializer.fromJson<String>(json['biomeId']),
      unlocked: serializer.fromJson<bool>(json['unlocked']),
      level: serializer.fromJson<int>(json['level']),
      activeElementId: serializer.fromJson<String?>(json['activeElementId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'biomeId': serializer.toJson<String>(biomeId),
      'unlocked': serializer.toJson<bool>(unlocked),
      'level': serializer.toJson<int>(level),
      'activeElementId': serializer.toJson<String?>(activeElementId),
    };
  }

  BiomeFarm copyWith({
    int? id,
    String? biomeId,
    bool? unlocked,
    int? level,
    Value<String?> activeElementId = const Value.absent(),
  }) => BiomeFarm(
    id: id ?? this.id,
    biomeId: biomeId ?? this.biomeId,
    unlocked: unlocked ?? this.unlocked,
    level: level ?? this.level,
    activeElementId: activeElementId.present
        ? activeElementId.value
        : this.activeElementId,
  );
  BiomeFarm copyWithCompanion(BiomeFarmsCompanion data) {
    return BiomeFarm(
      id: data.id.present ? data.id.value : this.id,
      biomeId: data.biomeId.present ? data.biomeId.value : this.biomeId,
      unlocked: data.unlocked.present ? data.unlocked.value : this.unlocked,
      level: data.level.present ? data.level.value : this.level,
      activeElementId: data.activeElementId.present
          ? data.activeElementId.value
          : this.activeElementId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BiomeFarm(')
          ..write('id: $id, ')
          ..write('biomeId: $biomeId, ')
          ..write('unlocked: $unlocked, ')
          ..write('level: $level, ')
          ..write('activeElementId: $activeElementId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, biomeId, unlocked, level, activeElementId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BiomeFarm &&
          other.id == this.id &&
          other.biomeId == this.biomeId &&
          other.unlocked == this.unlocked &&
          other.level == this.level &&
          other.activeElementId == this.activeElementId);
}

class BiomeFarmsCompanion extends UpdateCompanion<BiomeFarm> {
  final Value<int> id;
  final Value<String> biomeId;
  final Value<bool> unlocked;
  final Value<int> level;
  final Value<String?> activeElementId;
  const BiomeFarmsCompanion({
    this.id = const Value.absent(),
    this.biomeId = const Value.absent(),
    this.unlocked = const Value.absent(),
    this.level = const Value.absent(),
    this.activeElementId = const Value.absent(),
  });
  BiomeFarmsCompanion.insert({
    this.id = const Value.absent(),
    required String biomeId,
    this.unlocked = const Value.absent(),
    this.level = const Value.absent(),
    this.activeElementId = const Value.absent(),
  }) : biomeId = Value(biomeId);
  static Insertable<BiomeFarm> custom({
    Expression<int>? id,
    Expression<String>? biomeId,
    Expression<bool>? unlocked,
    Expression<int>? level,
    Expression<String>? activeElementId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (biomeId != null) 'biome_id': biomeId,
      if (unlocked != null) 'unlocked': unlocked,
      if (level != null) 'level': level,
      if (activeElementId != null) 'active_element_id': activeElementId,
    });
  }

  BiomeFarmsCompanion copyWith({
    Value<int>? id,
    Value<String>? biomeId,
    Value<bool>? unlocked,
    Value<int>? level,
    Value<String?>? activeElementId,
  }) {
    return BiomeFarmsCompanion(
      id: id ?? this.id,
      biomeId: biomeId ?? this.biomeId,
      unlocked: unlocked ?? this.unlocked,
      level: level ?? this.level,
      activeElementId: activeElementId ?? this.activeElementId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (biomeId.present) {
      map['biome_id'] = Variable<String>(biomeId.value);
    }
    if (unlocked.present) {
      map['unlocked'] = Variable<bool>(unlocked.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    if (activeElementId.present) {
      map['active_element_id'] = Variable<String>(activeElementId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BiomeFarmsCompanion(')
          ..write('id: $id, ')
          ..write('biomeId: $biomeId, ')
          ..write('unlocked: $unlocked, ')
          ..write('level: $level, ')
          ..write('activeElementId: $activeElementId')
          ..write(')'))
        .toString();
  }
}

class $BiomeJobsTable extends BiomeJobs
    with TableInfo<$BiomeJobsTable, BiomeJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BiomeJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _jobIdMeta = const VerificationMeta('jobId');
  @override
  late final GeneratedColumn<String> jobId = GeneratedColumn<String>(
    'job_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _biomeIdMeta = const VerificationMeta(
    'biomeId',
  );
  @override
  late final GeneratedColumn<int> biomeId = GeneratedColumn<int>(
    'biome_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creatureInstanceIdMeta =
      const VerificationMeta('creatureInstanceId');
  @override
  late final GeneratedColumn<String> creatureInstanceId =
      GeneratedColumn<String>(
        'creature_instance_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _startUtcMsMeta = const VerificationMeta(
    'startUtcMs',
  );
  @override
  late final GeneratedColumn<int> startUtcMs = GeneratedColumn<int>(
    'start_utc_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ratePerMinuteMeta = const VerificationMeta(
    'ratePerMinute',
  );
  @override
  late final GeneratedColumn<int> ratePerMinute = GeneratedColumn<int>(
    'rate_per_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    jobId,
    biomeId,
    creatureInstanceId,
    startUtcMs,
    durationMs,
    ratePerMinute,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'biome_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<BiomeJob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('job_id')) {
      context.handle(
        _jobIdMeta,
        jobId.isAcceptableOrUnknown(data['job_id']!, _jobIdMeta),
      );
    } else if (isInserting) {
      context.missing(_jobIdMeta);
    }
    if (data.containsKey('biome_id')) {
      context.handle(
        _biomeIdMeta,
        biomeId.isAcceptableOrUnknown(data['biome_id']!, _biomeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_biomeIdMeta);
    }
    if (data.containsKey('creature_instance_id')) {
      context.handle(
        _creatureInstanceIdMeta,
        creatureInstanceId.isAcceptableOrUnknown(
          data['creature_instance_id']!,
          _creatureInstanceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_creatureInstanceIdMeta);
    }
    if (data.containsKey('start_utc_ms')) {
      context.handle(
        _startUtcMsMeta,
        startUtcMs.isAcceptableOrUnknown(
          data['start_utc_ms']!,
          _startUtcMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startUtcMsMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('rate_per_minute')) {
      context.handle(
        _ratePerMinuteMeta,
        ratePerMinute.isAcceptableOrUnknown(
          data['rate_per_minute']!,
          _ratePerMinuteMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ratePerMinuteMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {jobId};
  @override
  BiomeJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BiomeJob(
      jobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}job_id'],
      )!,
      biomeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}biome_id'],
      )!,
      creatureInstanceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}creature_instance_id'],
      )!,
      startUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_utc_ms'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      ratePerMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rate_per_minute'],
      )!,
    );
  }

  @override
  $BiomeJobsTable createAlias(String alias) {
    return $BiomeJobsTable(attachedDatabase, alias);
  }
}

class BiomeJob extends DataClass implements Insertable<BiomeJob> {
  final String jobId;
  final int biomeId;
  final String creatureInstanceId;
  final int startUtcMs;
  final int durationMs;
  final int ratePerMinute;
  const BiomeJob({
    required this.jobId,
    required this.biomeId,
    required this.creatureInstanceId,
    required this.startUtcMs,
    required this.durationMs,
    required this.ratePerMinute,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['job_id'] = Variable<String>(jobId);
    map['biome_id'] = Variable<int>(biomeId);
    map['creature_instance_id'] = Variable<String>(creatureInstanceId);
    map['start_utc_ms'] = Variable<int>(startUtcMs);
    map['duration_ms'] = Variable<int>(durationMs);
    map['rate_per_minute'] = Variable<int>(ratePerMinute);
    return map;
  }

  BiomeJobsCompanion toCompanion(bool nullToAbsent) {
    return BiomeJobsCompanion(
      jobId: Value(jobId),
      biomeId: Value(biomeId),
      creatureInstanceId: Value(creatureInstanceId),
      startUtcMs: Value(startUtcMs),
      durationMs: Value(durationMs),
      ratePerMinute: Value(ratePerMinute),
    );
  }

  factory BiomeJob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BiomeJob(
      jobId: serializer.fromJson<String>(json['jobId']),
      biomeId: serializer.fromJson<int>(json['biomeId']),
      creatureInstanceId: serializer.fromJson<String>(
        json['creatureInstanceId'],
      ),
      startUtcMs: serializer.fromJson<int>(json['startUtcMs']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      ratePerMinute: serializer.fromJson<int>(json['ratePerMinute']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'jobId': serializer.toJson<String>(jobId),
      'biomeId': serializer.toJson<int>(biomeId),
      'creatureInstanceId': serializer.toJson<String>(creatureInstanceId),
      'startUtcMs': serializer.toJson<int>(startUtcMs),
      'durationMs': serializer.toJson<int>(durationMs),
      'ratePerMinute': serializer.toJson<int>(ratePerMinute),
    };
  }

  BiomeJob copyWith({
    String? jobId,
    int? biomeId,
    String? creatureInstanceId,
    int? startUtcMs,
    int? durationMs,
    int? ratePerMinute,
  }) => BiomeJob(
    jobId: jobId ?? this.jobId,
    biomeId: biomeId ?? this.biomeId,
    creatureInstanceId: creatureInstanceId ?? this.creatureInstanceId,
    startUtcMs: startUtcMs ?? this.startUtcMs,
    durationMs: durationMs ?? this.durationMs,
    ratePerMinute: ratePerMinute ?? this.ratePerMinute,
  );
  BiomeJob copyWithCompanion(BiomeJobsCompanion data) {
    return BiomeJob(
      jobId: data.jobId.present ? data.jobId.value : this.jobId,
      biomeId: data.biomeId.present ? data.biomeId.value : this.biomeId,
      creatureInstanceId: data.creatureInstanceId.present
          ? data.creatureInstanceId.value
          : this.creatureInstanceId,
      startUtcMs: data.startUtcMs.present
          ? data.startUtcMs.value
          : this.startUtcMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      ratePerMinute: data.ratePerMinute.present
          ? data.ratePerMinute.value
          : this.ratePerMinute,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BiomeJob(')
          ..write('jobId: $jobId, ')
          ..write('biomeId: $biomeId, ')
          ..write('creatureInstanceId: $creatureInstanceId, ')
          ..write('startUtcMs: $startUtcMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('ratePerMinute: $ratePerMinute')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    jobId,
    biomeId,
    creatureInstanceId,
    startUtcMs,
    durationMs,
    ratePerMinute,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BiomeJob &&
          other.jobId == this.jobId &&
          other.biomeId == this.biomeId &&
          other.creatureInstanceId == this.creatureInstanceId &&
          other.startUtcMs == this.startUtcMs &&
          other.durationMs == this.durationMs &&
          other.ratePerMinute == this.ratePerMinute);
}

class BiomeJobsCompanion extends UpdateCompanion<BiomeJob> {
  final Value<String> jobId;
  final Value<int> biomeId;
  final Value<String> creatureInstanceId;
  final Value<int> startUtcMs;
  final Value<int> durationMs;
  final Value<int> ratePerMinute;
  final Value<int> rowid;
  const BiomeJobsCompanion({
    this.jobId = const Value.absent(),
    this.biomeId = const Value.absent(),
    this.creatureInstanceId = const Value.absent(),
    this.startUtcMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.ratePerMinute = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BiomeJobsCompanion.insert({
    required String jobId,
    required int biomeId,
    required String creatureInstanceId,
    required int startUtcMs,
    required int durationMs,
    required int ratePerMinute,
    this.rowid = const Value.absent(),
  }) : jobId = Value(jobId),
       biomeId = Value(biomeId),
       creatureInstanceId = Value(creatureInstanceId),
       startUtcMs = Value(startUtcMs),
       durationMs = Value(durationMs),
       ratePerMinute = Value(ratePerMinute);
  static Insertable<BiomeJob> custom({
    Expression<String>? jobId,
    Expression<int>? biomeId,
    Expression<String>? creatureInstanceId,
    Expression<int>? startUtcMs,
    Expression<int>? durationMs,
    Expression<int>? ratePerMinute,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (jobId != null) 'job_id': jobId,
      if (biomeId != null) 'biome_id': biomeId,
      if (creatureInstanceId != null)
        'creature_instance_id': creatureInstanceId,
      if (startUtcMs != null) 'start_utc_ms': startUtcMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (ratePerMinute != null) 'rate_per_minute': ratePerMinute,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BiomeJobsCompanion copyWith({
    Value<String>? jobId,
    Value<int>? biomeId,
    Value<String>? creatureInstanceId,
    Value<int>? startUtcMs,
    Value<int>? durationMs,
    Value<int>? ratePerMinute,
    Value<int>? rowid,
  }) {
    return BiomeJobsCompanion(
      jobId: jobId ?? this.jobId,
      biomeId: biomeId ?? this.biomeId,
      creatureInstanceId: creatureInstanceId ?? this.creatureInstanceId,
      startUtcMs: startUtcMs ?? this.startUtcMs,
      durationMs: durationMs ?? this.durationMs,
      ratePerMinute: ratePerMinute ?? this.ratePerMinute,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (jobId.present) {
      map['job_id'] = Variable<String>(jobId.value);
    }
    if (biomeId.present) {
      map['biome_id'] = Variable<int>(biomeId.value);
    }
    if (creatureInstanceId.present) {
      map['creature_instance_id'] = Variable<String>(creatureInstanceId.value);
    }
    if (startUtcMs.present) {
      map['start_utc_ms'] = Variable<int>(startUtcMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (ratePerMinute.present) {
      map['rate_per_minute'] = Variable<int>(ratePerMinute.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BiomeJobsCompanion(')
          ..write('jobId: $jobId, ')
          ..write('biomeId: $biomeId, ')
          ..write('creatureInstanceId: $creatureInstanceId, ')
          ..write('startUtcMs: $startUtcMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('ratePerMinute: $ratePerMinute, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CompetitionProgressTable extends CompetitionProgress
    with TableInfo<$CompetitionProgressTable, CompetitionProgressData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CompetitionProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _biomeMeta = const VerificationMeta('biome');
  @override
  late final GeneratedColumn<String> biome = GeneratedColumn<String>(
    'biome',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _highestLevelCompletedMeta =
      const VerificationMeta('highestLevelCompleted');
  @override
  late final GeneratedColumn<int> highestLevelCompleted = GeneratedColumn<int>(
    'highest_level_completed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalWinsMeta = const VerificationMeta(
    'totalWins',
  );
  @override
  late final GeneratedColumn<int> totalWins = GeneratedColumn<int>(
    'total_wins',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalLossesMeta = const VerificationMeta(
    'totalLosses',
  );
  @override
  late final GeneratedColumn<int> totalLosses = GeneratedColumn<int>(
    'total_losses',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastCompletedAtMeta = const VerificationMeta(
    'lastCompletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastCompletedAt =
      GeneratedColumn<DateTime>(
        'last_completed_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    biome,
    highestLevelCompleted,
    totalWins,
    totalLosses,
    lastCompletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'competition_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<CompetitionProgressData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('biome')) {
      context.handle(
        _biomeMeta,
        biome.isAcceptableOrUnknown(data['biome']!, _biomeMeta),
      );
    } else if (isInserting) {
      context.missing(_biomeMeta);
    }
    if (data.containsKey('highest_level_completed')) {
      context.handle(
        _highestLevelCompletedMeta,
        highestLevelCompleted.isAcceptableOrUnknown(
          data['highest_level_completed']!,
          _highestLevelCompletedMeta,
        ),
      );
    }
    if (data.containsKey('total_wins')) {
      context.handle(
        _totalWinsMeta,
        totalWins.isAcceptableOrUnknown(data['total_wins']!, _totalWinsMeta),
      );
    }
    if (data.containsKey('total_losses')) {
      context.handle(
        _totalLossesMeta,
        totalLosses.isAcceptableOrUnknown(
          data['total_losses']!,
          _totalLossesMeta,
        ),
      );
    }
    if (data.containsKey('last_completed_at')) {
      context.handle(
        _lastCompletedAtMeta,
        lastCompletedAt.isAcceptableOrUnknown(
          data['last_completed_at']!,
          _lastCompletedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {biome};
  @override
  CompetitionProgressData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CompetitionProgressData(
      biome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}biome'],
      )!,
      highestLevelCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}highest_level_completed'],
      )!,
      totalWins: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_wins'],
      )!,
      totalLosses: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_losses'],
      )!,
      lastCompletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_completed_at'],
      ),
    );
  }

  @override
  $CompetitionProgressTable createAlias(String alias) {
    return $CompetitionProgressTable(attachedDatabase, alias);
  }
}

class CompetitionProgressData extends DataClass
    implements Insertable<CompetitionProgressData> {
  final String biome;
  final int highestLevelCompleted;
  final int totalWins;
  final int totalLosses;
  final DateTime? lastCompletedAt;
  const CompetitionProgressData({
    required this.biome,
    required this.highestLevelCompleted,
    required this.totalWins,
    required this.totalLosses,
    this.lastCompletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['biome'] = Variable<String>(biome);
    map['highest_level_completed'] = Variable<int>(highestLevelCompleted);
    map['total_wins'] = Variable<int>(totalWins);
    map['total_losses'] = Variable<int>(totalLosses);
    if (!nullToAbsent || lastCompletedAt != null) {
      map['last_completed_at'] = Variable<DateTime>(lastCompletedAt);
    }
    return map;
  }

  CompetitionProgressCompanion toCompanion(bool nullToAbsent) {
    return CompetitionProgressCompanion(
      biome: Value(biome),
      highestLevelCompleted: Value(highestLevelCompleted),
      totalWins: Value(totalWins),
      totalLosses: Value(totalLosses),
      lastCompletedAt: lastCompletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCompletedAt),
    );
  }

  factory CompetitionProgressData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CompetitionProgressData(
      biome: serializer.fromJson<String>(json['biome']),
      highestLevelCompleted: serializer.fromJson<int>(
        json['highestLevelCompleted'],
      ),
      totalWins: serializer.fromJson<int>(json['totalWins']),
      totalLosses: serializer.fromJson<int>(json['totalLosses']),
      lastCompletedAt: serializer.fromJson<DateTime?>(json['lastCompletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'biome': serializer.toJson<String>(biome),
      'highestLevelCompleted': serializer.toJson<int>(highestLevelCompleted),
      'totalWins': serializer.toJson<int>(totalWins),
      'totalLosses': serializer.toJson<int>(totalLosses),
      'lastCompletedAt': serializer.toJson<DateTime?>(lastCompletedAt),
    };
  }

  CompetitionProgressData copyWith({
    String? biome,
    int? highestLevelCompleted,
    int? totalWins,
    int? totalLosses,
    Value<DateTime?> lastCompletedAt = const Value.absent(),
  }) => CompetitionProgressData(
    biome: biome ?? this.biome,
    highestLevelCompleted: highestLevelCompleted ?? this.highestLevelCompleted,
    totalWins: totalWins ?? this.totalWins,
    totalLosses: totalLosses ?? this.totalLosses,
    lastCompletedAt: lastCompletedAt.present
        ? lastCompletedAt.value
        : this.lastCompletedAt,
  );
  CompetitionProgressData copyWithCompanion(CompetitionProgressCompanion data) {
    return CompetitionProgressData(
      biome: data.biome.present ? data.biome.value : this.biome,
      highestLevelCompleted: data.highestLevelCompleted.present
          ? data.highestLevelCompleted.value
          : this.highestLevelCompleted,
      totalWins: data.totalWins.present ? data.totalWins.value : this.totalWins,
      totalLosses: data.totalLosses.present
          ? data.totalLosses.value
          : this.totalLosses,
      lastCompletedAt: data.lastCompletedAt.present
          ? data.lastCompletedAt.value
          : this.lastCompletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CompetitionProgressData(')
          ..write('biome: $biome, ')
          ..write('highestLevelCompleted: $highestLevelCompleted, ')
          ..write('totalWins: $totalWins, ')
          ..write('totalLosses: $totalLosses, ')
          ..write('lastCompletedAt: $lastCompletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    biome,
    highestLevelCompleted,
    totalWins,
    totalLosses,
    lastCompletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CompetitionProgressData &&
          other.biome == this.biome &&
          other.highestLevelCompleted == this.highestLevelCompleted &&
          other.totalWins == this.totalWins &&
          other.totalLosses == this.totalLosses &&
          other.lastCompletedAt == this.lastCompletedAt);
}

class CompetitionProgressCompanion
    extends UpdateCompanion<CompetitionProgressData> {
  final Value<String> biome;
  final Value<int> highestLevelCompleted;
  final Value<int> totalWins;
  final Value<int> totalLosses;
  final Value<DateTime?> lastCompletedAt;
  final Value<int> rowid;
  const CompetitionProgressCompanion({
    this.biome = const Value.absent(),
    this.highestLevelCompleted = const Value.absent(),
    this.totalWins = const Value.absent(),
    this.totalLosses = const Value.absent(),
    this.lastCompletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CompetitionProgressCompanion.insert({
    required String biome,
    this.highestLevelCompleted = const Value.absent(),
    this.totalWins = const Value.absent(),
    this.totalLosses = const Value.absent(),
    this.lastCompletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : biome = Value(biome);
  static Insertable<CompetitionProgressData> custom({
    Expression<String>? biome,
    Expression<int>? highestLevelCompleted,
    Expression<int>? totalWins,
    Expression<int>? totalLosses,
    Expression<DateTime>? lastCompletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (biome != null) 'biome': biome,
      if (highestLevelCompleted != null)
        'highest_level_completed': highestLevelCompleted,
      if (totalWins != null) 'total_wins': totalWins,
      if (totalLosses != null) 'total_losses': totalLosses,
      if (lastCompletedAt != null) 'last_completed_at': lastCompletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CompetitionProgressCompanion copyWith({
    Value<String>? biome,
    Value<int>? highestLevelCompleted,
    Value<int>? totalWins,
    Value<int>? totalLosses,
    Value<DateTime?>? lastCompletedAt,
    Value<int>? rowid,
  }) {
    return CompetitionProgressCompanion(
      biome: biome ?? this.biome,
      highestLevelCompleted:
          highestLevelCompleted ?? this.highestLevelCompleted,
      totalWins: totalWins ?? this.totalWins,
      totalLosses: totalLosses ?? this.totalLosses,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (biome.present) {
      map['biome'] = Variable<String>(biome.value);
    }
    if (highestLevelCompleted.present) {
      map['highest_level_completed'] = Variable<int>(
        highestLevelCompleted.value,
      );
    }
    if (totalWins.present) {
      map['total_wins'] = Variable<int>(totalWins.value);
    }
    if (totalLosses.present) {
      map['total_losses'] = Variable<int>(totalLosses.value);
    }
    if (lastCompletedAt.present) {
      map['last_completed_at'] = Variable<DateTime>(lastCompletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CompetitionProgressCompanion(')
          ..write('biome: $biome, ')
          ..write('highestLevelCompleted: $highestLevelCompleted, ')
          ..write('totalWins: $totalWins, ')
          ..write('totalLosses: $totalLosses, ')
          ..write('lastCompletedAt: $lastCompletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ShopPurchasesTable extends ShopPurchases
    with TableInfo<$ShopPurchasesTable, ShopPurchase> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShopPurchasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _offerIdMeta = const VerificationMeta(
    'offerId',
  );
  @override
  late final GeneratedColumn<String> offerId = GeneratedColumn<String>(
    'offer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _purchaseCountMeta = const VerificationMeta(
    'purchaseCount',
  );
  @override
  late final GeneratedColumn<int> purchaseCount = GeneratedColumn<int>(
    'purchase_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastPurchaseUtcMsMeta = const VerificationMeta(
    'lastPurchaseUtcMs',
  );
  @override
  late final GeneratedColumn<int> lastPurchaseUtcMs = GeneratedColumn<int>(
    'last_purchase_utc_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    offerId,
    purchaseCount,
    lastPurchaseUtcMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shop_purchases';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShopPurchase> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('offer_id')) {
      context.handle(
        _offerIdMeta,
        offerId.isAcceptableOrUnknown(data['offer_id']!, _offerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_offerIdMeta);
    }
    if (data.containsKey('purchase_count')) {
      context.handle(
        _purchaseCountMeta,
        purchaseCount.isAcceptableOrUnknown(
          data['purchase_count']!,
          _purchaseCountMeta,
        ),
      );
    }
    if (data.containsKey('last_purchase_utc_ms')) {
      context.handle(
        _lastPurchaseUtcMsMeta,
        lastPurchaseUtcMs.isAcceptableOrUnknown(
          data['last_purchase_utc_ms']!,
          _lastPurchaseUtcMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {offerId};
  @override
  ShopPurchase map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShopPurchase(
      offerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}offer_id'],
      )!,
      purchaseCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}purchase_count'],
      )!,
      lastPurchaseUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_purchase_utc_ms'],
      ),
    );
  }

  @override
  $ShopPurchasesTable createAlias(String alias) {
    return $ShopPurchasesTable(attachedDatabase, alias);
  }
}

class ShopPurchase extends DataClass implements Insertable<ShopPurchase> {
  final String offerId;
  final int purchaseCount;
  final int? lastPurchaseUtcMs;
  const ShopPurchase({
    required this.offerId,
    required this.purchaseCount,
    this.lastPurchaseUtcMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['offer_id'] = Variable<String>(offerId);
    map['purchase_count'] = Variable<int>(purchaseCount);
    if (!nullToAbsent || lastPurchaseUtcMs != null) {
      map['last_purchase_utc_ms'] = Variable<int>(lastPurchaseUtcMs);
    }
    return map;
  }

  ShopPurchasesCompanion toCompanion(bool nullToAbsent) {
    return ShopPurchasesCompanion(
      offerId: Value(offerId),
      purchaseCount: Value(purchaseCount),
      lastPurchaseUtcMs: lastPurchaseUtcMs == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPurchaseUtcMs),
    );
  }

  factory ShopPurchase.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShopPurchase(
      offerId: serializer.fromJson<String>(json['offerId']),
      purchaseCount: serializer.fromJson<int>(json['purchaseCount']),
      lastPurchaseUtcMs: serializer.fromJson<int?>(json['lastPurchaseUtcMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'offerId': serializer.toJson<String>(offerId),
      'purchaseCount': serializer.toJson<int>(purchaseCount),
      'lastPurchaseUtcMs': serializer.toJson<int?>(lastPurchaseUtcMs),
    };
  }

  ShopPurchase copyWith({
    String? offerId,
    int? purchaseCount,
    Value<int?> lastPurchaseUtcMs = const Value.absent(),
  }) => ShopPurchase(
    offerId: offerId ?? this.offerId,
    purchaseCount: purchaseCount ?? this.purchaseCount,
    lastPurchaseUtcMs: lastPurchaseUtcMs.present
        ? lastPurchaseUtcMs.value
        : this.lastPurchaseUtcMs,
  );
  ShopPurchase copyWithCompanion(ShopPurchasesCompanion data) {
    return ShopPurchase(
      offerId: data.offerId.present ? data.offerId.value : this.offerId,
      purchaseCount: data.purchaseCount.present
          ? data.purchaseCount.value
          : this.purchaseCount,
      lastPurchaseUtcMs: data.lastPurchaseUtcMs.present
          ? data.lastPurchaseUtcMs.value
          : this.lastPurchaseUtcMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShopPurchase(')
          ..write('offerId: $offerId, ')
          ..write('purchaseCount: $purchaseCount, ')
          ..write('lastPurchaseUtcMs: $lastPurchaseUtcMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(offerId, purchaseCount, lastPurchaseUtcMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShopPurchase &&
          other.offerId == this.offerId &&
          other.purchaseCount == this.purchaseCount &&
          other.lastPurchaseUtcMs == this.lastPurchaseUtcMs);
}

class ShopPurchasesCompanion extends UpdateCompanion<ShopPurchase> {
  final Value<String> offerId;
  final Value<int> purchaseCount;
  final Value<int?> lastPurchaseUtcMs;
  final Value<int> rowid;
  const ShopPurchasesCompanion({
    this.offerId = const Value.absent(),
    this.purchaseCount = const Value.absent(),
    this.lastPurchaseUtcMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShopPurchasesCompanion.insert({
    required String offerId,
    this.purchaseCount = const Value.absent(),
    this.lastPurchaseUtcMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : offerId = Value(offerId);
  static Insertable<ShopPurchase> custom({
    Expression<String>? offerId,
    Expression<int>? purchaseCount,
    Expression<int>? lastPurchaseUtcMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (offerId != null) 'offer_id': offerId,
      if (purchaseCount != null) 'purchase_count': purchaseCount,
      if (lastPurchaseUtcMs != null) 'last_purchase_utc_ms': lastPurchaseUtcMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShopPurchasesCompanion copyWith({
    Value<String>? offerId,
    Value<int>? purchaseCount,
    Value<int?>? lastPurchaseUtcMs,
    Value<int>? rowid,
  }) {
    return ShopPurchasesCompanion(
      offerId: offerId ?? this.offerId,
      purchaseCount: purchaseCount ?? this.purchaseCount,
      lastPurchaseUtcMs: lastPurchaseUtcMs ?? this.lastPurchaseUtcMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (offerId.present) {
      map['offer_id'] = Variable<String>(offerId.value);
    }
    if (purchaseCount.present) {
      map['purchase_count'] = Variable<int>(purchaseCount.value);
    }
    if (lastPurchaseUtcMs.present) {
      map['last_purchase_utc_ms'] = Variable<int>(lastPurchaseUtcMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShopPurchasesCompanion(')
          ..write('offerId: $offerId, ')
          ..write('purchaseCount: $purchaseCount, ')
          ..write('lastPurchaseUtcMs: $lastPurchaseUtcMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InventoryItemsTable extends InventoryItems
    with TableInfo<$InventoryItemsTable, InventoryItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InventoryItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qtyMeta = const VerificationMeta('qty');
  @override
  late final GeneratedColumn<int> qty = GeneratedColumn<int>(
    'qty',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [key, qty];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inventory_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<InventoryItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('qty')) {
      context.handle(
        _qtyMeta,
        qty.isAcceptableOrUnknown(data['qty']!, _qtyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  InventoryItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InventoryItem(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      qty: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}qty'],
      )!,
    );
  }

  @override
  $InventoryItemsTable createAlias(String alias) {
    return $InventoryItemsTable(attachedDatabase, alias);
  }
}

class InventoryItem extends DataClass implements Insertable<InventoryItem> {
  final String key;
  final int qty;
  const InventoryItem({required this.key, required this.qty});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['qty'] = Variable<int>(qty);
    return map;
  }

  InventoryItemsCompanion toCompanion(bool nullToAbsent) {
    return InventoryItemsCompanion(key: Value(key), qty: Value(qty));
  }

  factory InventoryItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InventoryItem(
      key: serializer.fromJson<String>(json['key']),
      qty: serializer.fromJson<int>(json['qty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'qty': serializer.toJson<int>(qty),
    };
  }

  InventoryItem copyWith({String? key, int? qty}) =>
      InventoryItem(key: key ?? this.key, qty: qty ?? this.qty);
  InventoryItem copyWithCompanion(InventoryItemsCompanion data) {
    return InventoryItem(
      key: data.key.present ? data.key.value : this.key,
      qty: data.qty.present ? data.qty.value : this.qty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InventoryItem(')
          ..write('key: $key, ')
          ..write('qty: $qty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, qty);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InventoryItem &&
          other.key == this.key &&
          other.qty == this.qty);
}

class InventoryItemsCompanion extends UpdateCompanion<InventoryItem> {
  final Value<String> key;
  final Value<int> qty;
  final Value<int> rowid;
  const InventoryItemsCompanion({
    this.key = const Value.absent(),
    this.qty = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InventoryItemsCompanion.insert({
    required String key,
    this.qty = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<InventoryItem> custom({
    Expression<String>? key,
    Expression<int>? qty,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (qty != null) 'qty': qty,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InventoryItemsCompanion copyWith({
    Value<String>? key,
    Value<int>? qty,
    Value<int>? rowid,
  }) {
    return InventoryItemsCompanion(
      key: key ?? this.key,
      qty: qty ?? this.qty,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (qty.present) {
      map['qty'] = Variable<int>(qty.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InventoryItemsCompanion(')
          ..write('key: $key, ')
          ..write('qty: $qty, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ActiveSpawnsTable extends ActiveSpawns
    with TableInfo<$ActiveSpawnsTable, ActiveSpawn> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActiveSpawnsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sceneIdMeta = const VerificationMeta(
    'sceneId',
  );
  @override
  late final GeneratedColumn<String> sceneId = GeneratedColumn<String>(
    'scene_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spawnPointIdMeta = const VerificationMeta(
    'spawnPointId',
  );
  @override
  late final GeneratedColumn<String> spawnPointId = GeneratedColumn<String>(
    'spawn_point_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _speciesIdMeta = const VerificationMeta(
    'speciesId',
  );
  @override
  late final GeneratedColumn<String> speciesId = GeneratedColumn<String>(
    'species_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rarityMeta = const VerificationMeta('rarity');
  @override
  late final GeneratedColumn<String> rarity = GeneratedColumn<String>(
    'rarity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spawnedAtUtcMsMeta = const VerificationMeta(
    'spawnedAtUtcMs',
  );
  @override
  late final GeneratedColumn<int> spawnedAtUtcMs = GeneratedColumn<int>(
    'spawned_at_utc_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sceneId,
    spawnPointId,
    speciesId,
    rarity,
    spawnedAtUtcMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'active_spawns';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActiveSpawn> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('scene_id')) {
      context.handle(
        _sceneIdMeta,
        sceneId.isAcceptableOrUnknown(data['scene_id']!, _sceneIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sceneIdMeta);
    }
    if (data.containsKey('spawn_point_id')) {
      context.handle(
        _spawnPointIdMeta,
        spawnPointId.isAcceptableOrUnknown(
          data['spawn_point_id']!,
          _spawnPointIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_spawnPointIdMeta);
    }
    if (data.containsKey('species_id')) {
      context.handle(
        _speciesIdMeta,
        speciesId.isAcceptableOrUnknown(data['species_id']!, _speciesIdMeta),
      );
    } else if (isInserting) {
      context.missing(_speciesIdMeta);
    }
    if (data.containsKey('rarity')) {
      context.handle(
        _rarityMeta,
        rarity.isAcceptableOrUnknown(data['rarity']!, _rarityMeta),
      );
    } else if (isInserting) {
      context.missing(_rarityMeta);
    }
    if (data.containsKey('spawned_at_utc_ms')) {
      context.handle(
        _spawnedAtUtcMsMeta,
        spawnedAtUtcMs.isAcceptableOrUnknown(
          data['spawned_at_utc_ms']!,
          _spawnedAtUtcMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_spawnedAtUtcMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActiveSpawn map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActiveSpawn(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sceneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scene_id'],
      )!,
      spawnPointId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}spawn_point_id'],
      )!,
      speciesId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}species_id'],
      )!,
      rarity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rarity'],
      )!,
      spawnedAtUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}spawned_at_utc_ms'],
      )!,
    );
  }

  @override
  $ActiveSpawnsTable createAlias(String alias) {
    return $ActiveSpawnsTable(attachedDatabase, alias);
  }
}

class ActiveSpawn extends DataClass implements Insertable<ActiveSpawn> {
  /// Composite primary key: "sceneId_spawnPointId"
  /// Example: "valley_spawn_1", "volcano_spawn_3"
  final String id;

  /// The scene/biome where this spawn exists
  /// Example: "valley", "volcano", "sky", "swamp"
  final String sceneId;

  /// The specific spawn point ID within the scene
  /// Example: "spawn_1", "spawn_2", etc.
  final String spawnPointId;

  /// The species ID of the spawned creature
  /// Example: "aetherwing", "emberfox"
  final String speciesId;

  /// The rarity of this encounter
  /// Values: "common", "uncommon", "rare", "epic", "legendary", "mythic"
  final String rarity;

  /// When this spawn was created (UTC milliseconds)
  /// Used for potential future features like spawn expiry
  final int spawnedAtUtcMs;
  const ActiveSpawn({
    required this.id,
    required this.sceneId,
    required this.spawnPointId,
    required this.speciesId,
    required this.rarity,
    required this.spawnedAtUtcMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['scene_id'] = Variable<String>(sceneId);
    map['spawn_point_id'] = Variable<String>(spawnPointId);
    map['species_id'] = Variable<String>(speciesId);
    map['rarity'] = Variable<String>(rarity);
    map['spawned_at_utc_ms'] = Variable<int>(spawnedAtUtcMs);
    return map;
  }

  ActiveSpawnsCompanion toCompanion(bool nullToAbsent) {
    return ActiveSpawnsCompanion(
      id: Value(id),
      sceneId: Value(sceneId),
      spawnPointId: Value(spawnPointId),
      speciesId: Value(speciesId),
      rarity: Value(rarity),
      spawnedAtUtcMs: Value(spawnedAtUtcMs),
    );
  }

  factory ActiveSpawn.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActiveSpawn(
      id: serializer.fromJson<String>(json['id']),
      sceneId: serializer.fromJson<String>(json['sceneId']),
      spawnPointId: serializer.fromJson<String>(json['spawnPointId']),
      speciesId: serializer.fromJson<String>(json['speciesId']),
      rarity: serializer.fromJson<String>(json['rarity']),
      spawnedAtUtcMs: serializer.fromJson<int>(json['spawnedAtUtcMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sceneId': serializer.toJson<String>(sceneId),
      'spawnPointId': serializer.toJson<String>(spawnPointId),
      'speciesId': serializer.toJson<String>(speciesId),
      'rarity': serializer.toJson<String>(rarity),
      'spawnedAtUtcMs': serializer.toJson<int>(spawnedAtUtcMs),
    };
  }

  ActiveSpawn copyWith({
    String? id,
    String? sceneId,
    String? spawnPointId,
    String? speciesId,
    String? rarity,
    int? spawnedAtUtcMs,
  }) => ActiveSpawn(
    id: id ?? this.id,
    sceneId: sceneId ?? this.sceneId,
    spawnPointId: spawnPointId ?? this.spawnPointId,
    speciesId: speciesId ?? this.speciesId,
    rarity: rarity ?? this.rarity,
    spawnedAtUtcMs: spawnedAtUtcMs ?? this.spawnedAtUtcMs,
  );
  ActiveSpawn copyWithCompanion(ActiveSpawnsCompanion data) {
    return ActiveSpawn(
      id: data.id.present ? data.id.value : this.id,
      sceneId: data.sceneId.present ? data.sceneId.value : this.sceneId,
      spawnPointId: data.spawnPointId.present
          ? data.spawnPointId.value
          : this.spawnPointId,
      speciesId: data.speciesId.present ? data.speciesId.value : this.speciesId,
      rarity: data.rarity.present ? data.rarity.value : this.rarity,
      spawnedAtUtcMs: data.spawnedAtUtcMs.present
          ? data.spawnedAtUtcMs.value
          : this.spawnedAtUtcMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActiveSpawn(')
          ..write('id: $id, ')
          ..write('sceneId: $sceneId, ')
          ..write('spawnPointId: $spawnPointId, ')
          ..write('speciesId: $speciesId, ')
          ..write('rarity: $rarity, ')
          ..write('spawnedAtUtcMs: $spawnedAtUtcMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sceneId, spawnPointId, speciesId, rarity, spawnedAtUtcMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActiveSpawn &&
          other.id == this.id &&
          other.sceneId == this.sceneId &&
          other.spawnPointId == this.spawnPointId &&
          other.speciesId == this.speciesId &&
          other.rarity == this.rarity &&
          other.spawnedAtUtcMs == this.spawnedAtUtcMs);
}

class ActiveSpawnsCompanion extends UpdateCompanion<ActiveSpawn> {
  final Value<String> id;
  final Value<String> sceneId;
  final Value<String> spawnPointId;
  final Value<String> speciesId;
  final Value<String> rarity;
  final Value<int> spawnedAtUtcMs;
  final Value<int> rowid;
  const ActiveSpawnsCompanion({
    this.id = const Value.absent(),
    this.sceneId = const Value.absent(),
    this.spawnPointId = const Value.absent(),
    this.speciesId = const Value.absent(),
    this.rarity = const Value.absent(),
    this.spawnedAtUtcMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ActiveSpawnsCompanion.insert({
    required String id,
    required String sceneId,
    required String spawnPointId,
    required String speciesId,
    required String rarity,
    required int spawnedAtUtcMs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sceneId = Value(sceneId),
       spawnPointId = Value(spawnPointId),
       speciesId = Value(speciesId),
       rarity = Value(rarity),
       spawnedAtUtcMs = Value(spawnedAtUtcMs);
  static Insertable<ActiveSpawn> custom({
    Expression<String>? id,
    Expression<String>? sceneId,
    Expression<String>? spawnPointId,
    Expression<String>? speciesId,
    Expression<String>? rarity,
    Expression<int>? spawnedAtUtcMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sceneId != null) 'scene_id': sceneId,
      if (spawnPointId != null) 'spawn_point_id': spawnPointId,
      if (speciesId != null) 'species_id': speciesId,
      if (rarity != null) 'rarity': rarity,
      if (spawnedAtUtcMs != null) 'spawned_at_utc_ms': spawnedAtUtcMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ActiveSpawnsCompanion copyWith({
    Value<String>? id,
    Value<String>? sceneId,
    Value<String>? spawnPointId,
    Value<String>? speciesId,
    Value<String>? rarity,
    Value<int>? spawnedAtUtcMs,
    Value<int>? rowid,
  }) {
    return ActiveSpawnsCompanion(
      id: id ?? this.id,
      sceneId: sceneId ?? this.sceneId,
      spawnPointId: spawnPointId ?? this.spawnPointId,
      speciesId: speciesId ?? this.speciesId,
      rarity: rarity ?? this.rarity,
      spawnedAtUtcMs: spawnedAtUtcMs ?? this.spawnedAtUtcMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sceneId.present) {
      map['scene_id'] = Variable<String>(sceneId.value);
    }
    if (spawnPointId.present) {
      map['spawn_point_id'] = Variable<String>(spawnPointId.value);
    }
    if (speciesId.present) {
      map['species_id'] = Variable<String>(speciesId.value);
    }
    if (rarity.present) {
      map['rarity'] = Variable<String>(rarity.value);
    }
    if (spawnedAtUtcMs.present) {
      map['spawned_at_utc_ms'] = Variable<int>(spawnedAtUtcMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActiveSpawnsCompanion(')
          ..write('id: $id, ')
          ..write('sceneId: $sceneId, ')
          ..write('spawnPointId: $spawnPointId, ')
          ..write('speciesId: $speciesId, ')
          ..write('rarity: $rarity, ')
          ..write('spawnedAtUtcMs: $spawnedAtUtcMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ActiveSceneEntryTable extends ActiveSceneEntry
    with TableInfo<$ActiveSceneEntryTable, ActiveSceneEntryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActiveSceneEntryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sceneIdMeta = const VerificationMeta(
    'sceneId',
  );
  @override
  late final GeneratedColumn<String> sceneId = GeneratedColumn<String>(
    'scene_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enteredAtUtcMsMeta = const VerificationMeta(
    'enteredAtUtcMs',
  );
  @override
  late final GeneratedColumn<int> enteredAtUtcMs = GeneratedColumn<int>(
    'entered_at_utc_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [sceneId, enteredAtUtcMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'active_scene_entry';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActiveSceneEntryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scene_id')) {
      context.handle(
        _sceneIdMeta,
        sceneId.isAcceptableOrUnknown(data['scene_id']!, _sceneIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sceneIdMeta);
    }
    if (data.containsKey('entered_at_utc_ms')) {
      context.handle(
        _enteredAtUtcMsMeta,
        enteredAtUtcMs.isAcceptableOrUnknown(
          data['entered_at_utc_ms']!,
          _enteredAtUtcMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_enteredAtUtcMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sceneId};
  @override
  ActiveSceneEntryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActiveSceneEntryData(
      sceneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scene_id'],
      )!,
      enteredAtUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}entered_at_utc_ms'],
      )!,
    );
  }

  @override
  $ActiveSceneEntryTable createAlias(String alias) {
    return $ActiveSceneEntryTable(attachedDatabase, alias);
  }
}

class ActiveSceneEntryData extends DataClass
    implements Insertable<ActiveSceneEntryData> {
  /// The scene ID the user is currently in
  /// Example: "valley", "volcano", "sky", "swamp"
  final String sceneId;

  /// When the user entered this scene (UTC milliseconds)
  final int enteredAtUtcMs;
  const ActiveSceneEntryData({
    required this.sceneId,
    required this.enteredAtUtcMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scene_id'] = Variable<String>(sceneId);
    map['entered_at_utc_ms'] = Variable<int>(enteredAtUtcMs);
    return map;
  }

  ActiveSceneEntryCompanion toCompanion(bool nullToAbsent) {
    return ActiveSceneEntryCompanion(
      sceneId: Value(sceneId),
      enteredAtUtcMs: Value(enteredAtUtcMs),
    );
  }

  factory ActiveSceneEntryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActiveSceneEntryData(
      sceneId: serializer.fromJson<String>(json['sceneId']),
      enteredAtUtcMs: serializer.fromJson<int>(json['enteredAtUtcMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sceneId': serializer.toJson<String>(sceneId),
      'enteredAtUtcMs': serializer.toJson<int>(enteredAtUtcMs),
    };
  }

  ActiveSceneEntryData copyWith({String? sceneId, int? enteredAtUtcMs}) =>
      ActiveSceneEntryData(
        sceneId: sceneId ?? this.sceneId,
        enteredAtUtcMs: enteredAtUtcMs ?? this.enteredAtUtcMs,
      );
  ActiveSceneEntryData copyWithCompanion(ActiveSceneEntryCompanion data) {
    return ActiveSceneEntryData(
      sceneId: data.sceneId.present ? data.sceneId.value : this.sceneId,
      enteredAtUtcMs: data.enteredAtUtcMs.present
          ? data.enteredAtUtcMs.value
          : this.enteredAtUtcMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActiveSceneEntryData(')
          ..write('sceneId: $sceneId, ')
          ..write('enteredAtUtcMs: $enteredAtUtcMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sceneId, enteredAtUtcMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActiveSceneEntryData &&
          other.sceneId == this.sceneId &&
          other.enteredAtUtcMs == this.enteredAtUtcMs);
}

class ActiveSceneEntryCompanion extends UpdateCompanion<ActiveSceneEntryData> {
  final Value<String> sceneId;
  final Value<int> enteredAtUtcMs;
  final Value<int> rowid;
  const ActiveSceneEntryCompanion({
    this.sceneId = const Value.absent(),
    this.enteredAtUtcMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ActiveSceneEntryCompanion.insert({
    required String sceneId,
    required int enteredAtUtcMs,
    this.rowid = const Value.absent(),
  }) : sceneId = Value(sceneId),
       enteredAtUtcMs = Value(enteredAtUtcMs);
  static Insertable<ActiveSceneEntryData> custom({
    Expression<String>? sceneId,
    Expression<int>? enteredAtUtcMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sceneId != null) 'scene_id': sceneId,
      if (enteredAtUtcMs != null) 'entered_at_utc_ms': enteredAtUtcMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ActiveSceneEntryCompanion copyWith({
    Value<String>? sceneId,
    Value<int>? enteredAtUtcMs,
    Value<int>? rowid,
  }) {
    return ActiveSceneEntryCompanion(
      sceneId: sceneId ?? this.sceneId,
      enteredAtUtcMs: enteredAtUtcMs ?? this.enteredAtUtcMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sceneId.present) {
      map['scene_id'] = Variable<String>(sceneId.value);
    }
    if (enteredAtUtcMs.present) {
      map['entered_at_utc_ms'] = Variable<int>(enteredAtUtcMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActiveSceneEntryCompanion(')
          ..write('sceneId: $sceneId, ')
          ..write('enteredAtUtcMs: $enteredAtUtcMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SpawnScheduleTable extends SpawnSchedule
    with TableInfo<$SpawnScheduleTable, SpawnScheduleData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpawnScheduleTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sceneIdMeta = const VerificationMeta(
    'sceneId',
  );
  @override
  late final GeneratedColumn<String> sceneId = GeneratedColumn<String>(
    'scene_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueAtUtcMsMeta = const VerificationMeta(
    'dueAtUtcMs',
  );
  @override
  late final GeneratedColumn<int> dueAtUtcMs = GeneratedColumn<int>(
    'due_at_utc_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [sceneId, dueAtUtcMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'spawn_schedule';
  @override
  VerificationContext validateIntegrity(
    Insertable<SpawnScheduleData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scene_id')) {
      context.handle(
        _sceneIdMeta,
        sceneId.isAcceptableOrUnknown(data['scene_id']!, _sceneIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sceneIdMeta);
    }
    if (data.containsKey('due_at_utc_ms')) {
      context.handle(
        _dueAtUtcMsMeta,
        dueAtUtcMs.isAcceptableOrUnknown(
          data['due_at_utc_ms']!,
          _dueAtUtcMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dueAtUtcMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sceneId};
  @override
  SpawnScheduleData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SpawnScheduleData(
      sceneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scene_id'],
      )!,
      dueAtUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_at_utc_ms'],
      )!,
    );
  }

  @override
  $SpawnScheduleTable createAlias(String alias) {
    return $SpawnScheduleTable(attachedDatabase, alias);
  }
}

class SpawnScheduleData extends DataClass
    implements Insertable<SpawnScheduleData> {
  final String sceneId;
  final int dueAtUtcMs;
  const SpawnScheduleData({required this.sceneId, required this.dueAtUtcMs});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scene_id'] = Variable<String>(sceneId);
    map['due_at_utc_ms'] = Variable<int>(dueAtUtcMs);
    return map;
  }

  SpawnScheduleCompanion toCompanion(bool nullToAbsent) {
    return SpawnScheduleCompanion(
      sceneId: Value(sceneId),
      dueAtUtcMs: Value(dueAtUtcMs),
    );
  }

  factory SpawnScheduleData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SpawnScheduleData(
      sceneId: serializer.fromJson<String>(json['sceneId']),
      dueAtUtcMs: serializer.fromJson<int>(json['dueAtUtcMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sceneId': serializer.toJson<String>(sceneId),
      'dueAtUtcMs': serializer.toJson<int>(dueAtUtcMs),
    };
  }

  SpawnScheduleData copyWith({String? sceneId, int? dueAtUtcMs}) =>
      SpawnScheduleData(
        sceneId: sceneId ?? this.sceneId,
        dueAtUtcMs: dueAtUtcMs ?? this.dueAtUtcMs,
      );
  SpawnScheduleData copyWithCompanion(SpawnScheduleCompanion data) {
    return SpawnScheduleData(
      sceneId: data.sceneId.present ? data.sceneId.value : this.sceneId,
      dueAtUtcMs: data.dueAtUtcMs.present
          ? data.dueAtUtcMs.value
          : this.dueAtUtcMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SpawnScheduleData(')
          ..write('sceneId: $sceneId, ')
          ..write('dueAtUtcMs: $dueAtUtcMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sceneId, dueAtUtcMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpawnScheduleData &&
          other.sceneId == this.sceneId &&
          other.dueAtUtcMs == this.dueAtUtcMs);
}

class SpawnScheduleCompanion extends UpdateCompanion<SpawnScheduleData> {
  final Value<String> sceneId;
  final Value<int> dueAtUtcMs;
  final Value<int> rowid;
  const SpawnScheduleCompanion({
    this.sceneId = const Value.absent(),
    this.dueAtUtcMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SpawnScheduleCompanion.insert({
    required String sceneId,
    required int dueAtUtcMs,
    this.rowid = const Value.absent(),
  }) : sceneId = Value(sceneId),
       dueAtUtcMs = Value(dueAtUtcMs);
  static Insertable<SpawnScheduleData> custom({
    Expression<String>? sceneId,
    Expression<int>? dueAtUtcMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sceneId != null) 'scene_id': sceneId,
      if (dueAtUtcMs != null) 'due_at_utc_ms': dueAtUtcMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SpawnScheduleCompanion copyWith({
    Value<String>? sceneId,
    Value<int>? dueAtUtcMs,
    Value<int>? rowid,
  }) {
    return SpawnScheduleCompanion(
      sceneId: sceneId ?? this.sceneId,
      dueAtUtcMs: dueAtUtcMs ?? this.dueAtUtcMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sceneId.present) {
      map['scene_id'] = Variable<String>(sceneId.value);
    }
    if (dueAtUtcMs.present) {
      map['due_at_utc_ms'] = Variable<int>(dueAtUtcMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpawnScheduleCompanion(')
          ..write('sceneId: $sceneId, ')
          ..write('dueAtUtcMs: $dueAtUtcMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotificationDismissalsTable extends NotificationDismissals
    with TableInfo<$NotificationDismissalsTable, NotificationDismissal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationDismissalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _notificationTypeMeta = const VerificationMeta(
    'notificationType',
  );
  @override
  late final GeneratedColumn<String> notificationType = GeneratedColumn<String>(
    'notification_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dismissedAtUtcMsMeta = const VerificationMeta(
    'dismissedAtUtcMs',
  );
  @override
  late final GeneratedColumn<int> dismissedAtUtcMs = GeneratedColumn<int>(
    'dismissed_at_utc_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [notificationType, dismissedAtUtcMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notification_dismissals';
  @override
  VerificationContext validateIntegrity(
    Insertable<NotificationDismissal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('notification_type')) {
      context.handle(
        _notificationTypeMeta,
        notificationType.isAcceptableOrUnknown(
          data['notification_type']!,
          _notificationTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_notificationTypeMeta);
    }
    if (data.containsKey('dismissed_at_utc_ms')) {
      context.handle(
        _dismissedAtUtcMsMeta,
        dismissedAtUtcMs.isAcceptableOrUnknown(
          data['dismissed_at_utc_ms']!,
          _dismissedAtUtcMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dismissedAtUtcMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {notificationType};
  @override
  NotificationDismissal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotificationDismissal(
      notificationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notification_type'],
      )!,
      dismissedAtUtcMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dismissed_at_utc_ms'],
      )!,
    );
  }

  @override
  $NotificationDismissalsTable createAlias(String alias) {
    return $NotificationDismissalsTable(attachedDatabase, alias);
  }
}

class NotificationDismissal extends DataClass
    implements Insertable<NotificationDismissal> {
  final String notificationType;
  final int dismissedAtUtcMs;
  const NotificationDismissal({
    required this.notificationType,
    required this.dismissedAtUtcMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['notification_type'] = Variable<String>(notificationType);
    map['dismissed_at_utc_ms'] = Variable<int>(dismissedAtUtcMs);
    return map;
  }

  NotificationDismissalsCompanion toCompanion(bool nullToAbsent) {
    return NotificationDismissalsCompanion(
      notificationType: Value(notificationType),
      dismissedAtUtcMs: Value(dismissedAtUtcMs),
    );
  }

  factory NotificationDismissal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotificationDismissal(
      notificationType: serializer.fromJson<String>(json['notificationType']),
      dismissedAtUtcMs: serializer.fromJson<int>(json['dismissedAtUtcMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'notificationType': serializer.toJson<String>(notificationType),
      'dismissedAtUtcMs': serializer.toJson<int>(dismissedAtUtcMs),
    };
  }

  NotificationDismissal copyWith({
    String? notificationType,
    int? dismissedAtUtcMs,
  }) => NotificationDismissal(
    notificationType: notificationType ?? this.notificationType,
    dismissedAtUtcMs: dismissedAtUtcMs ?? this.dismissedAtUtcMs,
  );
  NotificationDismissal copyWithCompanion(
    NotificationDismissalsCompanion data,
  ) {
    return NotificationDismissal(
      notificationType: data.notificationType.present
          ? data.notificationType.value
          : this.notificationType,
      dismissedAtUtcMs: data.dismissedAtUtcMs.present
          ? data.dismissedAtUtcMs.value
          : this.dismissedAtUtcMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationDismissal(')
          ..write('notificationType: $notificationType, ')
          ..write('dismissedAtUtcMs: $dismissedAtUtcMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(notificationType, dismissedAtUtcMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationDismissal &&
          other.notificationType == this.notificationType &&
          other.dismissedAtUtcMs == this.dismissedAtUtcMs);
}

class NotificationDismissalsCompanion
    extends UpdateCompanion<NotificationDismissal> {
  final Value<String> notificationType;
  final Value<int> dismissedAtUtcMs;
  final Value<int> rowid;
  const NotificationDismissalsCompanion({
    this.notificationType = const Value.absent(),
    this.dismissedAtUtcMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotificationDismissalsCompanion.insert({
    required String notificationType,
    required int dismissedAtUtcMs,
    this.rowid = const Value.absent(),
  }) : notificationType = Value(notificationType),
       dismissedAtUtcMs = Value(dismissedAtUtcMs);
  static Insertable<NotificationDismissal> custom({
    Expression<String>? notificationType,
    Expression<int>? dismissedAtUtcMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (notificationType != null) 'notification_type': notificationType,
      if (dismissedAtUtcMs != null) 'dismissed_at_utc_ms': dismissedAtUtcMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotificationDismissalsCompanion copyWith({
    Value<String>? notificationType,
    Value<int>? dismissedAtUtcMs,
    Value<int>? rowid,
  }) {
    return NotificationDismissalsCompanion(
      notificationType: notificationType ?? this.notificationType,
      dismissedAtUtcMs: dismissedAtUtcMs ?? this.dismissedAtUtcMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (notificationType.present) {
      map['notification_type'] = Variable<String>(notificationType.value);
    }
    if (dismissedAtUtcMs.present) {
      map['dismissed_at_utc_ms'] = Variable<int>(dismissedAtUtcMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationDismissalsCompanion(')
          ..write('notificationType: $notificationType, ')
          ..write('dismissedAtUtcMs: $dismissedAtUtcMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConstellationPointsTable extends ConstellationPoints
    with TableInfo<$ConstellationPointsTable, ConstellationPoint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConstellationPointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _currentBalanceMeta = const VerificationMeta(
    'currentBalance',
  );
  @override
  late final GeneratedColumn<int> currentBalance = GeneratedColumn<int>(
    'current_balance',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalEarnedMeta = const VerificationMeta(
    'totalEarned',
  );
  @override
  late final GeneratedColumn<int> totalEarned = GeneratedColumn<int>(
    'total_earned',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalSpentMeta = const VerificationMeta(
    'totalSpent',
  );
  @override
  late final GeneratedColumn<int> totalSpent = GeneratedColumn<int>(
    'total_spent',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _hasSeenFinaleMeta = const VerificationMeta(
    'hasSeenFinale',
  );
  @override
  late final GeneratedColumn<bool> hasSeenFinale = GeneratedColumn<bool>(
    'has_seen_finale',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_seen_finale" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastUpdatedUtcMeta = const VerificationMeta(
    'lastUpdatedUtc',
  );
  @override
  late final GeneratedColumn<DateTime> lastUpdatedUtc =
      GeneratedColumn<DateTime>(
        'last_updated_utc',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    currentBalance,
    totalEarned,
    totalSpent,
    hasSeenFinale,
    lastUpdatedUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'constellation_points';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConstellationPoint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('current_balance')) {
      context.handle(
        _currentBalanceMeta,
        currentBalance.isAcceptableOrUnknown(
          data['current_balance']!,
          _currentBalanceMeta,
        ),
      );
    }
    if (data.containsKey('total_earned')) {
      context.handle(
        _totalEarnedMeta,
        totalEarned.isAcceptableOrUnknown(
          data['total_earned']!,
          _totalEarnedMeta,
        ),
      );
    }
    if (data.containsKey('total_spent')) {
      context.handle(
        _totalSpentMeta,
        totalSpent.isAcceptableOrUnknown(data['total_spent']!, _totalSpentMeta),
      );
    }
    if (data.containsKey('has_seen_finale')) {
      context.handle(
        _hasSeenFinaleMeta,
        hasSeenFinale.isAcceptableOrUnknown(
          data['has_seen_finale']!,
          _hasSeenFinaleMeta,
        ),
      );
    }
    if (data.containsKey('last_updated_utc')) {
      context.handle(
        _lastUpdatedUtcMeta,
        lastUpdatedUtc.isAcceptableOrUnknown(
          data['last_updated_utc']!,
          _lastUpdatedUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastUpdatedUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConstellationPoint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConstellationPoint(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      currentBalance: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_balance'],
      )!,
      totalEarned: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_earned'],
      )!,
      totalSpent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_spent'],
      )!,
      hasSeenFinale: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_seen_finale'],
      )!,
      lastUpdatedUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_updated_utc'],
      )!,
    );
  }

  @override
  $ConstellationPointsTable createAlias(String alias) {
    return $ConstellationPointsTable(attachedDatabase, alias);
  }
}

class ConstellationPoint extends DataClass
    implements Insertable<ConstellationPoint> {
  final int id;
  final int currentBalance;
  final int totalEarned;
  final int totalSpent;
  final bool hasSeenFinale;
  final DateTime lastUpdatedUtc;
  const ConstellationPoint({
    required this.id,
    required this.currentBalance,
    required this.totalEarned,
    required this.totalSpent,
    required this.hasSeenFinale,
    required this.lastUpdatedUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['current_balance'] = Variable<int>(currentBalance);
    map['total_earned'] = Variable<int>(totalEarned);
    map['total_spent'] = Variable<int>(totalSpent);
    map['has_seen_finale'] = Variable<bool>(hasSeenFinale);
    map['last_updated_utc'] = Variable<DateTime>(lastUpdatedUtc);
    return map;
  }

  ConstellationPointsCompanion toCompanion(bool nullToAbsent) {
    return ConstellationPointsCompanion(
      id: Value(id),
      currentBalance: Value(currentBalance),
      totalEarned: Value(totalEarned),
      totalSpent: Value(totalSpent),
      hasSeenFinale: Value(hasSeenFinale),
      lastUpdatedUtc: Value(lastUpdatedUtc),
    );
  }

  factory ConstellationPoint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConstellationPoint(
      id: serializer.fromJson<int>(json['id']),
      currentBalance: serializer.fromJson<int>(json['currentBalance']),
      totalEarned: serializer.fromJson<int>(json['totalEarned']),
      totalSpent: serializer.fromJson<int>(json['totalSpent']),
      hasSeenFinale: serializer.fromJson<bool>(json['hasSeenFinale']),
      lastUpdatedUtc: serializer.fromJson<DateTime>(json['lastUpdatedUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'currentBalance': serializer.toJson<int>(currentBalance),
      'totalEarned': serializer.toJson<int>(totalEarned),
      'totalSpent': serializer.toJson<int>(totalSpent),
      'hasSeenFinale': serializer.toJson<bool>(hasSeenFinale),
      'lastUpdatedUtc': serializer.toJson<DateTime>(lastUpdatedUtc),
    };
  }

  ConstellationPoint copyWith({
    int? id,
    int? currentBalance,
    int? totalEarned,
    int? totalSpent,
    bool? hasSeenFinale,
    DateTime? lastUpdatedUtc,
  }) => ConstellationPoint(
    id: id ?? this.id,
    currentBalance: currentBalance ?? this.currentBalance,
    totalEarned: totalEarned ?? this.totalEarned,
    totalSpent: totalSpent ?? this.totalSpent,
    hasSeenFinale: hasSeenFinale ?? this.hasSeenFinale,
    lastUpdatedUtc: lastUpdatedUtc ?? this.lastUpdatedUtc,
  );
  ConstellationPoint copyWithCompanion(ConstellationPointsCompanion data) {
    return ConstellationPoint(
      id: data.id.present ? data.id.value : this.id,
      currentBalance: data.currentBalance.present
          ? data.currentBalance.value
          : this.currentBalance,
      totalEarned: data.totalEarned.present
          ? data.totalEarned.value
          : this.totalEarned,
      totalSpent: data.totalSpent.present
          ? data.totalSpent.value
          : this.totalSpent,
      hasSeenFinale: data.hasSeenFinale.present
          ? data.hasSeenFinale.value
          : this.hasSeenFinale,
      lastUpdatedUtc: data.lastUpdatedUtc.present
          ? data.lastUpdatedUtc.value
          : this.lastUpdatedUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConstellationPoint(')
          ..write('id: $id, ')
          ..write('currentBalance: $currentBalance, ')
          ..write('totalEarned: $totalEarned, ')
          ..write('totalSpent: $totalSpent, ')
          ..write('hasSeenFinale: $hasSeenFinale, ')
          ..write('lastUpdatedUtc: $lastUpdatedUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    currentBalance,
    totalEarned,
    totalSpent,
    hasSeenFinale,
    lastUpdatedUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConstellationPoint &&
          other.id == this.id &&
          other.currentBalance == this.currentBalance &&
          other.totalEarned == this.totalEarned &&
          other.totalSpent == this.totalSpent &&
          other.hasSeenFinale == this.hasSeenFinale &&
          other.lastUpdatedUtc == this.lastUpdatedUtc);
}

class ConstellationPointsCompanion extends UpdateCompanion<ConstellationPoint> {
  final Value<int> id;
  final Value<int> currentBalance;
  final Value<int> totalEarned;
  final Value<int> totalSpent;
  final Value<bool> hasSeenFinale;
  final Value<DateTime> lastUpdatedUtc;
  const ConstellationPointsCompanion({
    this.id = const Value.absent(),
    this.currentBalance = const Value.absent(),
    this.totalEarned = const Value.absent(),
    this.totalSpent = const Value.absent(),
    this.hasSeenFinale = const Value.absent(),
    this.lastUpdatedUtc = const Value.absent(),
  });
  ConstellationPointsCompanion.insert({
    this.id = const Value.absent(),
    this.currentBalance = const Value.absent(),
    this.totalEarned = const Value.absent(),
    this.totalSpent = const Value.absent(),
    this.hasSeenFinale = const Value.absent(),
    required DateTime lastUpdatedUtc,
  }) : lastUpdatedUtc = Value(lastUpdatedUtc);
  static Insertable<ConstellationPoint> custom({
    Expression<int>? id,
    Expression<int>? currentBalance,
    Expression<int>? totalEarned,
    Expression<int>? totalSpent,
    Expression<bool>? hasSeenFinale,
    Expression<DateTime>? lastUpdatedUtc,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (currentBalance != null) 'current_balance': currentBalance,
      if (totalEarned != null) 'total_earned': totalEarned,
      if (totalSpent != null) 'total_spent': totalSpent,
      if (hasSeenFinale != null) 'has_seen_finale': hasSeenFinale,
      if (lastUpdatedUtc != null) 'last_updated_utc': lastUpdatedUtc,
    });
  }

  ConstellationPointsCompanion copyWith({
    Value<int>? id,
    Value<int>? currentBalance,
    Value<int>? totalEarned,
    Value<int>? totalSpent,
    Value<bool>? hasSeenFinale,
    Value<DateTime>? lastUpdatedUtc,
  }) {
    return ConstellationPointsCompanion(
      id: id ?? this.id,
      currentBalance: currentBalance ?? this.currentBalance,
      totalEarned: totalEarned ?? this.totalEarned,
      totalSpent: totalSpent ?? this.totalSpent,
      hasSeenFinale: hasSeenFinale ?? this.hasSeenFinale,
      lastUpdatedUtc: lastUpdatedUtc ?? this.lastUpdatedUtc,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (currentBalance.present) {
      map['current_balance'] = Variable<int>(currentBalance.value);
    }
    if (totalEarned.present) {
      map['total_earned'] = Variable<int>(totalEarned.value);
    }
    if (totalSpent.present) {
      map['total_spent'] = Variable<int>(totalSpent.value);
    }
    if (hasSeenFinale.present) {
      map['has_seen_finale'] = Variable<bool>(hasSeenFinale.value);
    }
    if (lastUpdatedUtc.present) {
      map['last_updated_utc'] = Variable<DateTime>(lastUpdatedUtc.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConstellationPointsCompanion(')
          ..write('id: $id, ')
          ..write('currentBalance: $currentBalance, ')
          ..write('totalEarned: $totalEarned, ')
          ..write('totalSpent: $totalSpent, ')
          ..write('hasSeenFinale: $hasSeenFinale, ')
          ..write('lastUpdatedUtc: $lastUpdatedUtc')
          ..write(')'))
        .toString();
  }
}

class $ConstellationTransactionsTable extends ConstellationTransactions
    with TableInfo<$ConstellationTransactionsTable, ConstellationTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConstellationTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _transactionTypeMeta = const VerificationMeta(
    'transactionType',
  );
  @override
  late final GeneratedColumn<String> transactionType = GeneratedColumn<String>(
    'transaction_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> createdAtUtc = GeneratedColumn<DateTime>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    transactionType,
    amount,
    sourceId,
    description,
    createdAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'constellation_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConstellationTransaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('transaction_type')) {
      context.handle(
        _transactionTypeMeta,
        transactionType.isAcceptableOrUnknown(
          data['transaction_type']!,
          _transactionTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionTypeMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConstellationTransaction map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConstellationTransaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      transactionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_type'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at_utc'],
      )!,
    );
  }

  @override
  $ConstellationTransactionsTable createAlias(String alias) {
    return $ConstellationTransactionsTable(attachedDatabase, alias);
  }
}

class ConstellationTransaction extends DataClass
    implements Insertable<ConstellationTransaction> {
  final int id;
  final String transactionType;
  final int amount;
  final String? sourceId;
  final String description;
  final DateTime createdAtUtc;
  const ConstellationTransaction({
    required this.id,
    required this.transactionType,
    required this.amount,
    this.sourceId,
    required this.description,
    required this.createdAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['transaction_type'] = Variable<String>(transactionType);
    map['amount'] = Variable<int>(amount);
    if (!nullToAbsent || sourceId != null) {
      map['source_id'] = Variable<String>(sourceId);
    }
    map['description'] = Variable<String>(description);
    map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    return map;
  }

  ConstellationTransactionsCompanion toCompanion(bool nullToAbsent) {
    return ConstellationTransactionsCompanion(
      id: Value(id),
      transactionType: Value(transactionType),
      amount: Value(amount),
      sourceId: sourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceId),
      description: Value(description),
      createdAtUtc: Value(createdAtUtc),
    );
  }

  factory ConstellationTransaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConstellationTransaction(
      id: serializer.fromJson<int>(json['id']),
      transactionType: serializer.fromJson<String>(json['transactionType']),
      amount: serializer.fromJson<int>(json['amount']),
      sourceId: serializer.fromJson<String?>(json['sourceId']),
      description: serializer.fromJson<String>(json['description']),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'transactionType': serializer.toJson<String>(transactionType),
      'amount': serializer.toJson<int>(amount),
      'sourceId': serializer.toJson<String?>(sourceId),
      'description': serializer.toJson<String>(description),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
    };
  }

  ConstellationTransaction copyWith({
    int? id,
    String? transactionType,
    int? amount,
    Value<String?> sourceId = const Value.absent(),
    String? description,
    DateTime? createdAtUtc,
  }) => ConstellationTransaction(
    id: id ?? this.id,
    transactionType: transactionType ?? this.transactionType,
    amount: amount ?? this.amount,
    sourceId: sourceId.present ? sourceId.value : this.sourceId,
    description: description ?? this.description,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
  );
  ConstellationTransaction copyWithCompanion(
    ConstellationTransactionsCompanion data,
  ) {
    return ConstellationTransaction(
      id: data.id.present ? data.id.value : this.id,
      transactionType: data.transactionType.present
          ? data.transactionType.value
          : this.transactionType,
      amount: data.amount.present ? data.amount.value : this.amount,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      description: data.description.present
          ? data.description.value
          : this.description,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConstellationTransaction(')
          ..write('id: $id, ')
          ..write('transactionType: $transactionType, ')
          ..write('amount: $amount, ')
          ..write('sourceId: $sourceId, ')
          ..write('description: $description, ')
          ..write('createdAtUtc: $createdAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    transactionType,
    amount,
    sourceId,
    description,
    createdAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConstellationTransaction &&
          other.id == this.id &&
          other.transactionType == this.transactionType &&
          other.amount == this.amount &&
          other.sourceId == this.sourceId &&
          other.description == this.description &&
          other.createdAtUtc == this.createdAtUtc);
}

class ConstellationTransactionsCompanion
    extends UpdateCompanion<ConstellationTransaction> {
  final Value<int> id;
  final Value<String> transactionType;
  final Value<int> amount;
  final Value<String?> sourceId;
  final Value<String> description;
  final Value<DateTime> createdAtUtc;
  const ConstellationTransactionsCompanion({
    this.id = const Value.absent(),
    this.transactionType = const Value.absent(),
    this.amount = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.description = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
  });
  ConstellationTransactionsCompanion.insert({
    this.id = const Value.absent(),
    required String transactionType,
    required int amount,
    this.sourceId = const Value.absent(),
    required String description,
    required DateTime createdAtUtc,
  }) : transactionType = Value(transactionType),
       amount = Value(amount),
       description = Value(description),
       createdAtUtc = Value(createdAtUtc);
  static Insertable<ConstellationTransaction> custom({
    Expression<int>? id,
    Expression<String>? transactionType,
    Expression<int>? amount,
    Expression<String>? sourceId,
    Expression<String>? description,
    Expression<DateTime>? createdAtUtc,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (transactionType != null) 'transaction_type': transactionType,
      if (amount != null) 'amount': amount,
      if (sourceId != null) 'source_id': sourceId,
      if (description != null) 'description': description,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
    });
  }

  ConstellationTransactionsCompanion copyWith({
    Value<int>? id,
    Value<String>? transactionType,
    Value<int>? amount,
    Value<String?>? sourceId,
    Value<String>? description,
    Value<DateTime>? createdAtUtc,
  }) {
    return ConstellationTransactionsCompanion(
      id: id ?? this.id,
      transactionType: transactionType ?? this.transactionType,
      amount: amount ?? this.amount,
      sourceId: sourceId ?? this.sourceId,
      description: description ?? this.description,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (transactionType.present) {
      map['transaction_type'] = Variable<String>(transactionType.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<DateTime>(createdAtUtc.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConstellationTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('transactionType: $transactionType, ')
          ..write('amount: $amount, ')
          ..write('sourceId: $sourceId, ')
          ..write('description: $description, ')
          ..write('createdAtUtc: $createdAtUtc')
          ..write(')'))
        .toString();
  }
}

class $ConstellationUnlocksTable extends ConstellationUnlocks
    with TableInfo<$ConstellationUnlocksTable, ConstellationUnlock> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConstellationUnlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _skillIdMeta = const VerificationMeta(
    'skillId',
  );
  @override
  late final GeneratedColumn<String> skillId = GeneratedColumn<String>(
    'skill_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unlockedAtUtcMeta = const VerificationMeta(
    'unlockedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> unlockedAtUtc =
      GeneratedColumn<DateTime>(
        'unlocked_at_utc',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _pointsCostMeta = const VerificationMeta(
    'pointsCost',
  );
  @override
  late final GeneratedColumn<int> pointsCost = GeneratedColumn<int>(
    'points_cost',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [skillId, unlockedAtUtc, pointsCost];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'constellation_unlocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConstellationUnlock> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('skill_id')) {
      context.handle(
        _skillIdMeta,
        skillId.isAcceptableOrUnknown(data['skill_id']!, _skillIdMeta),
      );
    } else if (isInserting) {
      context.missing(_skillIdMeta);
    }
    if (data.containsKey('unlocked_at_utc')) {
      context.handle(
        _unlockedAtUtcMeta,
        unlockedAtUtc.isAcceptableOrUnknown(
          data['unlocked_at_utc']!,
          _unlockedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_unlockedAtUtcMeta);
    }
    if (data.containsKey('points_cost')) {
      context.handle(
        _pointsCostMeta,
        pointsCost.isAcceptableOrUnknown(data['points_cost']!, _pointsCostMeta),
      );
    } else if (isInserting) {
      context.missing(_pointsCostMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {skillId};
  @override
  ConstellationUnlock map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConstellationUnlock(
      skillId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}skill_id'],
      )!,
      unlockedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}unlocked_at_utc'],
      )!,
      pointsCost: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}points_cost'],
      )!,
    );
  }

  @override
  $ConstellationUnlocksTable createAlias(String alias) {
    return $ConstellationUnlocksTable(attachedDatabase, alias);
  }
}

class ConstellationUnlock extends DataClass
    implements Insertable<ConstellationUnlock> {
  final String skillId;
  final DateTime unlockedAtUtc;
  final int pointsCost;
  const ConstellationUnlock({
    required this.skillId,
    required this.unlockedAtUtc,
    required this.pointsCost,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['skill_id'] = Variable<String>(skillId);
    map['unlocked_at_utc'] = Variable<DateTime>(unlockedAtUtc);
    map['points_cost'] = Variable<int>(pointsCost);
    return map;
  }

  ConstellationUnlocksCompanion toCompanion(bool nullToAbsent) {
    return ConstellationUnlocksCompanion(
      skillId: Value(skillId),
      unlockedAtUtc: Value(unlockedAtUtc),
      pointsCost: Value(pointsCost),
    );
  }

  factory ConstellationUnlock.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConstellationUnlock(
      skillId: serializer.fromJson<String>(json['skillId']),
      unlockedAtUtc: serializer.fromJson<DateTime>(json['unlockedAtUtc']),
      pointsCost: serializer.fromJson<int>(json['pointsCost']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'skillId': serializer.toJson<String>(skillId),
      'unlockedAtUtc': serializer.toJson<DateTime>(unlockedAtUtc),
      'pointsCost': serializer.toJson<int>(pointsCost),
    };
  }

  ConstellationUnlock copyWith({
    String? skillId,
    DateTime? unlockedAtUtc,
    int? pointsCost,
  }) => ConstellationUnlock(
    skillId: skillId ?? this.skillId,
    unlockedAtUtc: unlockedAtUtc ?? this.unlockedAtUtc,
    pointsCost: pointsCost ?? this.pointsCost,
  );
  ConstellationUnlock copyWithCompanion(ConstellationUnlocksCompanion data) {
    return ConstellationUnlock(
      skillId: data.skillId.present ? data.skillId.value : this.skillId,
      unlockedAtUtc: data.unlockedAtUtc.present
          ? data.unlockedAtUtc.value
          : this.unlockedAtUtc,
      pointsCost: data.pointsCost.present
          ? data.pointsCost.value
          : this.pointsCost,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConstellationUnlock(')
          ..write('skillId: $skillId, ')
          ..write('unlockedAtUtc: $unlockedAtUtc, ')
          ..write('pointsCost: $pointsCost')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(skillId, unlockedAtUtc, pointsCost);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConstellationUnlock &&
          other.skillId == this.skillId &&
          other.unlockedAtUtc == this.unlockedAtUtc &&
          other.pointsCost == this.pointsCost);
}

class ConstellationUnlocksCompanion
    extends UpdateCompanion<ConstellationUnlock> {
  final Value<String> skillId;
  final Value<DateTime> unlockedAtUtc;
  final Value<int> pointsCost;
  final Value<int> rowid;
  const ConstellationUnlocksCompanion({
    this.skillId = const Value.absent(),
    this.unlockedAtUtc = const Value.absent(),
    this.pointsCost = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConstellationUnlocksCompanion.insert({
    required String skillId,
    required DateTime unlockedAtUtc,
    required int pointsCost,
    this.rowid = const Value.absent(),
  }) : skillId = Value(skillId),
       unlockedAtUtc = Value(unlockedAtUtc),
       pointsCost = Value(pointsCost);
  static Insertable<ConstellationUnlock> custom({
    Expression<String>? skillId,
    Expression<DateTime>? unlockedAtUtc,
    Expression<int>? pointsCost,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (skillId != null) 'skill_id': skillId,
      if (unlockedAtUtc != null) 'unlocked_at_utc': unlockedAtUtc,
      if (pointsCost != null) 'points_cost': pointsCost,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConstellationUnlocksCompanion copyWith({
    Value<String>? skillId,
    Value<DateTime>? unlockedAtUtc,
    Value<int>? pointsCost,
    Value<int>? rowid,
  }) {
    return ConstellationUnlocksCompanion(
      skillId: skillId ?? this.skillId,
      unlockedAtUtc: unlockedAtUtc ?? this.unlockedAtUtc,
      pointsCost: pointsCost ?? this.pointsCost,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (skillId.present) {
      map['skill_id'] = Variable<String>(skillId.value);
    }
    if (unlockedAtUtc.present) {
      map['unlocked_at_utc'] = Variable<DateTime>(unlockedAtUtc.value);
    }
    if (pointsCost.present) {
      map['points_cost'] = Variable<int>(pointsCost.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConstellationUnlocksCompanion(')
          ..write('skillId: $skillId, ')
          ..write('unlockedAtUtc: $unlockedAtUtc, ')
          ..write('pointsCost: $pointsCost, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BreedingStatisticsTable extends BreedingStatistics
    with TableInfo<$BreedingStatisticsTable, BreedingStatistic> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BreedingStatisticsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _speciesIdMeta = const VerificationMeta(
    'speciesId',
  );
  @override
  late final GeneratedColumn<String> speciesId = GeneratedColumn<String>(
    'species_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalBredMeta = const VerificationMeta(
    'totalBred',
  );
  @override
  late final GeneratedColumn<int> totalBred = GeneratedColumn<int>(
    'total_bred',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastMilestoneAwardedMeta =
      const VerificationMeta('lastMilestoneAwarded');
  @override
  late final GeneratedColumn<int> lastMilestoneAwarded = GeneratedColumn<int>(
    'last_milestone_awarded',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastBredAtUtcMeta = const VerificationMeta(
    'lastBredAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> lastBredAtUtc =
      GeneratedColumn<DateTime>(
        'last_bred_at_utc',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    speciesId,
    totalBred,
    lastMilestoneAwarded,
    lastBredAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'breeding_statistics';
  @override
  VerificationContext validateIntegrity(
    Insertable<BreedingStatistic> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('species_id')) {
      context.handle(
        _speciesIdMeta,
        speciesId.isAcceptableOrUnknown(data['species_id']!, _speciesIdMeta),
      );
    } else if (isInserting) {
      context.missing(_speciesIdMeta);
    }
    if (data.containsKey('total_bred')) {
      context.handle(
        _totalBredMeta,
        totalBred.isAcceptableOrUnknown(data['total_bred']!, _totalBredMeta),
      );
    }
    if (data.containsKey('last_milestone_awarded')) {
      context.handle(
        _lastMilestoneAwardedMeta,
        lastMilestoneAwarded.isAcceptableOrUnknown(
          data['last_milestone_awarded']!,
          _lastMilestoneAwardedMeta,
        ),
      );
    }
    if (data.containsKey('last_bred_at_utc')) {
      context.handle(
        _lastBredAtUtcMeta,
        lastBredAtUtc.isAcceptableOrUnknown(
          data['last_bred_at_utc']!,
          _lastBredAtUtcMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {speciesId};
  @override
  BreedingStatistic map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BreedingStatistic(
      speciesId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}species_id'],
      )!,
      totalBred: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_bred'],
      )!,
      lastMilestoneAwarded: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_milestone_awarded'],
      )!,
      lastBredAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_bred_at_utc'],
      ),
    );
  }

  @override
  $BreedingStatisticsTable createAlias(String alias) {
    return $BreedingStatisticsTable(attachedDatabase, alias);
  }
}

class BreedingStatistic extends DataClass
    implements Insertable<BreedingStatistic> {
  final String speciesId;
  final int totalBred;
  final int lastMilestoneAwarded;
  final DateTime? lastBredAtUtc;
  const BreedingStatistic({
    required this.speciesId,
    required this.totalBred,
    required this.lastMilestoneAwarded,
    this.lastBredAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['species_id'] = Variable<String>(speciesId);
    map['total_bred'] = Variable<int>(totalBred);
    map['last_milestone_awarded'] = Variable<int>(lastMilestoneAwarded);
    if (!nullToAbsent || lastBredAtUtc != null) {
      map['last_bred_at_utc'] = Variable<DateTime>(lastBredAtUtc);
    }
    return map;
  }

  BreedingStatisticsCompanion toCompanion(bool nullToAbsent) {
    return BreedingStatisticsCompanion(
      speciesId: Value(speciesId),
      totalBred: Value(totalBred),
      lastMilestoneAwarded: Value(lastMilestoneAwarded),
      lastBredAtUtc: lastBredAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(lastBredAtUtc),
    );
  }

  factory BreedingStatistic.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BreedingStatistic(
      speciesId: serializer.fromJson<String>(json['speciesId']),
      totalBred: serializer.fromJson<int>(json['totalBred']),
      lastMilestoneAwarded: serializer.fromJson<int>(
        json['lastMilestoneAwarded'],
      ),
      lastBredAtUtc: serializer.fromJson<DateTime?>(json['lastBredAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'speciesId': serializer.toJson<String>(speciesId),
      'totalBred': serializer.toJson<int>(totalBred),
      'lastMilestoneAwarded': serializer.toJson<int>(lastMilestoneAwarded),
      'lastBredAtUtc': serializer.toJson<DateTime?>(lastBredAtUtc),
    };
  }

  BreedingStatistic copyWith({
    String? speciesId,
    int? totalBred,
    int? lastMilestoneAwarded,
    Value<DateTime?> lastBredAtUtc = const Value.absent(),
  }) => BreedingStatistic(
    speciesId: speciesId ?? this.speciesId,
    totalBred: totalBred ?? this.totalBred,
    lastMilestoneAwarded: lastMilestoneAwarded ?? this.lastMilestoneAwarded,
    lastBredAtUtc: lastBredAtUtc.present
        ? lastBredAtUtc.value
        : this.lastBredAtUtc,
  );
  BreedingStatistic copyWithCompanion(BreedingStatisticsCompanion data) {
    return BreedingStatistic(
      speciesId: data.speciesId.present ? data.speciesId.value : this.speciesId,
      totalBred: data.totalBred.present ? data.totalBred.value : this.totalBred,
      lastMilestoneAwarded: data.lastMilestoneAwarded.present
          ? data.lastMilestoneAwarded.value
          : this.lastMilestoneAwarded,
      lastBredAtUtc: data.lastBredAtUtc.present
          ? data.lastBredAtUtc.value
          : this.lastBredAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BreedingStatistic(')
          ..write('speciesId: $speciesId, ')
          ..write('totalBred: $totalBred, ')
          ..write('lastMilestoneAwarded: $lastMilestoneAwarded, ')
          ..write('lastBredAtUtc: $lastBredAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(speciesId, totalBred, lastMilestoneAwarded, lastBredAtUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BreedingStatistic &&
          other.speciesId == this.speciesId &&
          other.totalBred == this.totalBred &&
          other.lastMilestoneAwarded == this.lastMilestoneAwarded &&
          other.lastBredAtUtc == this.lastBredAtUtc);
}

class BreedingStatisticsCompanion extends UpdateCompanion<BreedingStatistic> {
  final Value<String> speciesId;
  final Value<int> totalBred;
  final Value<int> lastMilestoneAwarded;
  final Value<DateTime?> lastBredAtUtc;
  final Value<int> rowid;
  const BreedingStatisticsCompanion({
    this.speciesId = const Value.absent(),
    this.totalBred = const Value.absent(),
    this.lastMilestoneAwarded = const Value.absent(),
    this.lastBredAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BreedingStatisticsCompanion.insert({
    required String speciesId,
    this.totalBred = const Value.absent(),
    this.lastMilestoneAwarded = const Value.absent(),
    this.lastBredAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : speciesId = Value(speciesId);
  static Insertable<BreedingStatistic> custom({
    Expression<String>? speciesId,
    Expression<int>? totalBred,
    Expression<int>? lastMilestoneAwarded,
    Expression<DateTime>? lastBredAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (speciesId != null) 'species_id': speciesId,
      if (totalBred != null) 'total_bred': totalBred,
      if (lastMilestoneAwarded != null)
        'last_milestone_awarded': lastMilestoneAwarded,
      if (lastBredAtUtc != null) 'last_bred_at_utc': lastBredAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BreedingStatisticsCompanion copyWith({
    Value<String>? speciesId,
    Value<int>? totalBred,
    Value<int>? lastMilestoneAwarded,
    Value<DateTime?>? lastBredAtUtc,
    Value<int>? rowid,
  }) {
    return BreedingStatisticsCompanion(
      speciesId: speciesId ?? this.speciesId,
      totalBred: totalBred ?? this.totalBred,
      lastMilestoneAwarded: lastMilestoneAwarded ?? this.lastMilestoneAwarded,
      lastBredAtUtc: lastBredAtUtc ?? this.lastBredAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (speciesId.present) {
      map['species_id'] = Variable<String>(speciesId.value);
    }
    if (totalBred.present) {
      map['total_bred'] = Variable<int>(totalBred.value);
    }
    if (lastMilestoneAwarded.present) {
      map['last_milestone_awarded'] = Variable<int>(lastMilestoneAwarded.value);
    }
    if (lastBredAtUtc.present) {
      map['last_bred_at_utc'] = Variable<DateTime>(lastBredAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BreedingStatisticsCompanion(')
          ..write('speciesId: $speciesId, ')
          ..write('totalBred: $totalBred, ')
          ..write('lastMilestoneAwarded: $lastMilestoneAwarded, ')
          ..write('lastBredAtUtc: $lastBredAtUtc, ')
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
  late final $IncubatorSlotsTable incubatorSlots = $IncubatorSlotsTable(this);
  late final $EggsTable eggs = $EggsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $CreatureInstancesTable creatureInstances =
      $CreatureInstancesTable(this);
  late final $FeedEventsTable feedEvents = $FeedEventsTable(this);
  late final $BiomeFarmsTable biomeFarms = $BiomeFarmsTable(this);
  late final $BiomeJobsTable biomeJobs = $BiomeJobsTable(this);
  late final $CompetitionProgressTable competitionProgress =
      $CompetitionProgressTable(this);
  late final $ShopPurchasesTable shopPurchases = $ShopPurchasesTable(this);
  late final $InventoryItemsTable inventoryItems = $InventoryItemsTable(this);
  late final $ActiveSpawnsTable activeSpawns = $ActiveSpawnsTable(this);
  late final $ActiveSceneEntryTable activeSceneEntry = $ActiveSceneEntryTable(
    this,
  );
  late final $SpawnScheduleTable spawnSchedule = $SpawnScheduleTable(this);
  late final $NotificationDismissalsTable notificationDismissals =
      $NotificationDismissalsTable(this);
  late final $ConstellationPointsTable constellationPoints =
      $ConstellationPointsTable(this);
  late final $ConstellationTransactionsTable constellationTransactions =
      $ConstellationTransactionsTable(this);
  late final $ConstellationUnlocksTable constellationUnlocks =
      $ConstellationUnlocksTable(this);
  late final $BreedingStatisticsTable breedingStatistics =
      $BreedingStatisticsTable(this);
  late final SettingsDao settingsDao = SettingsDao(this as AlchemonsDatabase);
  late final CurrencyDao currencyDao = CurrencyDao(this as AlchemonsDatabase);
  late final CreatureDao creatureDao = CreatureDao(this as AlchemonsDatabase);
  late final IncubatorDao incubatorDao = IncubatorDao(
    this as AlchemonsDatabase,
  );
  late final InventoryDao inventoryDao = InventoryDao(
    this as AlchemonsDatabase,
  );
  late final BiomeDao biomeDao = BiomeDao(this as AlchemonsDatabase);
  late final ShopDao shopDao = ShopDao(this as AlchemonsDatabase);
  late final ConstellationDao constellationDao = ConstellationDao(
    this as AlchemonsDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    playerCreatures,
    incubatorSlots,
    eggs,
    settings,
    creatureInstances,
    feedEvents,
    biomeFarms,
    biomeJobs,
    competitionProgress,
    shopPurchases,
    inventoryItems,
    activeSpawns,
    activeSceneEntry,
    spawnSchedule,
    notificationDismissals,
    constellationPoints,
    constellationTransactions,
    constellationUnlocks,
    breedingStatistics,
  ];
}

typedef $$PlayerCreaturesTableCreateCompanionBuilder =
    PlayerCreaturesCompanion Function({
      required String id,
      Value<bool> discovered,
      Value<String?> natureId,
      Value<int> rowid,
    });
typedef $$PlayerCreaturesTableUpdateCompanionBuilder =
    PlayerCreaturesCompanion Function({
      Value<String> id,
      Value<bool> discovered,
      Value<String?> natureId,
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

  ColumnFilters<String> get natureId => $composableBuilder(
    column: $table.natureId,
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

  ColumnOrderings<String> get natureId => $composableBuilder(
    column: $table.natureId,
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

  GeneratedColumn<String> get natureId =>
      $composableBuilder(column: $table.natureId, builder: (column) => column);
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
                Value<String?> natureId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlayerCreaturesCompanion(
                id: id,
                discovered: discovered,
                natureId: natureId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<bool> discovered = const Value.absent(),
                Value<String?> natureId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlayerCreaturesCompanion.insert(
                id: id,
                discovered: discovered,
                natureId: natureId,
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
typedef $$IncubatorSlotsTableCreateCompanionBuilder =
    IncubatorSlotsCompanion Function({
      Value<int> id,
      Value<bool> unlocked,
      Value<String?> eggId,
      Value<String?> resultCreatureId,
      Value<String?> bonusVariantId,
      Value<String?> rarity,
      Value<int?> hatchAtUtcMs,
      Value<String?> payloadJson,
    });
typedef $$IncubatorSlotsTableUpdateCompanionBuilder =
    IncubatorSlotsCompanion Function({
      Value<int> id,
      Value<bool> unlocked,
      Value<String?> eggId,
      Value<String?> resultCreatureId,
      Value<String?> bonusVariantId,
      Value<String?> rarity,
      Value<int?> hatchAtUtcMs,
      Value<String?> payloadJson,
    });

class $$IncubatorSlotsTableFilterComposer
    extends Composer<_$AlchemonsDatabase, $IncubatorSlotsTable> {
  $$IncubatorSlotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get unlocked => $composableBuilder(
    column: $table.unlocked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eggId => $composableBuilder(
    column: $table.eggId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultCreatureId => $composableBuilder(
    column: $table.resultCreatureId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bonusVariantId => $composableBuilder(
    column: $table.bonusVariantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rarity => $composableBuilder(
    column: $table.rarity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hatchAtUtcMs => $composableBuilder(
    column: $table.hatchAtUtcMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IncubatorSlotsTableOrderingComposer
    extends Composer<_$AlchemonsDatabase, $IncubatorSlotsTable> {
  $$IncubatorSlotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get unlocked => $composableBuilder(
    column: $table.unlocked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eggId => $composableBuilder(
    column: $table.eggId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultCreatureId => $composableBuilder(
    column: $table.resultCreatureId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bonusVariantId => $composableBuilder(
    column: $table.bonusVariantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rarity => $composableBuilder(
    column: $table.rarity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hatchAtUtcMs => $composableBuilder(
    column: $table.hatchAtUtcMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IncubatorSlotsTableAnnotationComposer
    extends Composer<_$AlchemonsDatabase, $IncubatorSlotsTable> {
  $$IncubatorSlotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get unlocked =>
      $composableBuilder(column: $table.unlocked, builder: (column) => column);

  GeneratedColumn<String> get eggId =>
      $composableBuilder(column: $table.eggId, builder: (column) => column);

  GeneratedColumn<String> get resultCreatureId => $composableBuilder(
    column: $table.resultCreatureId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bonusVariantId => $composableBuilder(
    column: $table.bonusVariantId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rarity =>
      $composableBuilder(column: $table.rarity, builder: (column) => column);

  GeneratedColumn<int> get hatchAtUtcMs => $composableBuilder(
    column: $table.hatchAtUtcMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );
}

class $$IncubatorSlotsTableTableManager
    extends
        RootTableManager<
          _$AlchemonsDatabase,
          $IncubatorSlotsTable,
          IncubatorSlot,
          $$IncubatorSlotsTableFilterComposer,
          $$IncubatorSlotsTableOrderingComposer,
          $$IncubatorSlotsTableAnnotationComposer,
          $$IncubatorSlotsTableCreateCompanionBuilder,
          $$IncubatorSlotsTableUpdateCompanionBuilder,
          (
            IncubatorSlot,
            BaseReferences<
              _$AlchemonsDatabase,
              $IncubatorSlotsTable,
              IncubatorSlot
            >,
          ),
          IncubatorSlot,
          PrefetchHooks Function()
        > {
  $$IncubatorSlotsTableTableManager(
    _$AlchemonsDatabase db,
    $IncubatorSlotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IncubatorSlotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IncubatorSlotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IncubatorSlotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> unlocked = const Value.absent(),
                Value<String?> eggId = const Value.absent(),
                Value<String?> resultCreatureId = const Value.absent(),
                Value<String?> bonusVariantId = const Value.absent(),
                Value<String?> rarity = const Value.absent(),
                Value<int?> hatchAtUtcMs = const Value.absent(),
                Value<String?> payloadJson = const Value.absent(),
              }) => IncubatorSlotsCompanion(
                id: id,
                unlocked: unlocked,
                eggId: eggId,
                resultCreatureId: resultCreatureId,
                bonusVariantId: bonusVariantId,
                rarity: rarity,
                hatchAtUtcMs: hatchAtUtcMs,
                payloadJson: payloadJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> unlocked = const Value.absent(),
                Value<String?> eggId = const Value.absent(),
                Value<String?> resultCreatureId = const Value.absent(),
                Value<String?> bonusVariantId = const Value.absent(),
                Value<String?> rarity = const Value.absent(),
                Value<int?> hatchAtUtcMs = const Value.absent(),
                Value<String?> payloadJson = const Value.absent(),
              }) => IncubatorSlotsCompanion.insert(
                id: id,
                unlocked: unlocked,
                eggId: eggId,
                resultCreatureId: resultCreatureId,
                bonusVariantId: bonusVariantId,
                rarity: rarity,
                hatchAtUtcMs: hatchAtUtcMs,
                payloadJson: payloadJson,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IncubatorSlotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AlchemonsDatabase,
      $IncubatorSlotsTable,
      IncubatorSlot,
      $$IncubatorSlotsTableFilterComposer,
      $$IncubatorSlotsTableOrderingComposer,
      $$IncubatorSlotsTableAnnotationComposer,
      $$IncubatorSlotsTableCreateCompanionBuilder,
      $$IncubatorSlotsTableUpdateCompanionBuilder,
      (
        IncubatorSlot,
        BaseReferences<
          _$AlchemonsDatabase,
          $IncubatorSlotsTable,
          IncubatorSlot
        >,
      ),
      IncubatorSlot,
      PrefetchHooks Function()
    >;
typedef $$EggsTableCreateCompanionBuilder =
    EggsCompanion Function({
      required String eggId,
      required String resultCreatureId,
      required String rarity,
      Value<String?> bonusVariantId,
      required int remainingMs,
      Value<String?> payloadJson,
      Value<int> rowid,
    });
typedef $$EggsTableUpdateCompanionBuilder =
    EggsCompanion Function({
      Value<String> eggId,
      Value<String> resultCreatureId,
      Value<String> rarity,
      Value<String?> bonusVariantId,
      Value<int> remainingMs,
      Value<String?> payloadJson,
      Value<int> rowid,
    });

class $$EggsTableFilterComposer
    extends Composer<_$AlchemonsDatabase, $EggsTable> {
  $$EggsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get eggId => $composableBuilder(
    column: $table.eggId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultCreatureId => $composableBuilder(
    column: $table.resultCreatureId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rarity => $composableBuilder(
    column: $table.rarity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bonusVariantId => $composableBuilder(
    column: $table.bonusVariantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remainingMs => $composableBuilder(
    column: $table.remainingMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EggsTableOrderingComposer
    extends Composer<_$AlchemonsDatabase, $EggsTable> {
  $$EggsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get eggId => $composableBuilder(
    column: $table.eggId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultCreatureId => $composableBuilder(
    column: $table.resultCreatureId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rarity => $composableBuilder(
    column: $table.rarity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bonusVariantId => $composableBuilder(
    column: $table.bonusVariantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remainingMs => $composableBuilder(
    column: $table.remainingMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EggsTableAnnotationComposer
    extends Composer<_$AlchemonsDatabase, $EggsTable> {
  $$EggsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get eggId =>
      $composableBuilder(column: $table.eggId, builder: (column) => column);

  GeneratedColumn<String> get resultCreatureId => $composableBuilder(
    column: $table.resultCreatureId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rarity =>
      $composableBuilder(column: $table.rarity, builder: (column) => column);

  GeneratedColumn<String> get bonusVariantId => $composableBuilder(
    column: $table.bonusVariantId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remainingMs => $composableBuilder(
    column: $table.remainingMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );
}

class $$EggsTableTableManager
    extends
        RootTableManager<
          _$AlchemonsDatabase,
          $EggsTable,
          Egg,
          $$EggsTableFilterComposer,
          $$EggsTableOrderingComposer,
          $$EggsTableAnnotationComposer,
          $$EggsTableCreateCompanionBuilder,
          $$EggsTableUpdateCompanionBuilder,
          (Egg, BaseReferences<_$AlchemonsDatabase, $EggsTable, Egg>),
          Egg,
          PrefetchHooks Function()
        > {
  $$EggsTableTableManager(_$AlchemonsDatabase db, $EggsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EggsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EggsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EggsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> eggId = const Value.absent(),
                Value<String> resultCreatureId = const Value.absent(),
                Value<String> rarity = const Value.absent(),
                Value<String?> bonusVariantId = const Value.absent(),
                Value<int> remainingMs = const Value.absent(),
                Value<String?> payloadJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EggsCompanion(
                eggId: eggId,
                resultCreatureId: resultCreatureId,
                rarity: rarity,
                bonusVariantId: bonusVariantId,
                remainingMs: remainingMs,
                payloadJson: payloadJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String eggId,
                required String resultCreatureId,
                required String rarity,
                Value<String?> bonusVariantId = const Value.absent(),
                required int remainingMs,
                Value<String?> payloadJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EggsCompanion.insert(
                eggId: eggId,
                resultCreatureId: resultCreatureId,
                rarity: rarity,
                bonusVariantId: bonusVariantId,
                remainingMs: remainingMs,
                payloadJson: payloadJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EggsTableProcessedTableManager =
    ProcessedTableManager<
      _$AlchemonsDatabase,
      $EggsTable,
      Egg,
      $$EggsTableFilterComposer,
      $$EggsTableOrderingComposer,
      $$EggsTableAnnotationComposer,
      $$EggsTableCreateCompanionBuilder,
      $$EggsTableUpdateCompanionBuilder,
      (Egg, BaseReferences<_$AlchemonsDatabase, $EggsTable, Egg>),
      Egg,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AlchemonsDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AlchemonsDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AlchemonsDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AlchemonsDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            Setting,
            BaseReferences<_$AlchemonsDatabase, $SettingsTable, Setting>,
          ),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AlchemonsDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AlchemonsDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AlchemonsDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$CreatureInstancesTableCreateCompanionBuilder =
    CreatureInstancesCompanion Function({
      required String instanceId,
      required String baseId,
      Value<int> level,
      Value<int> xp,
      Value<bool> locked,
      Value<String?> nickname,
      Value<bool> isPrismaticSkin,
      Value<String?> natureId,
      Value<String> source,
      Value<String?> parentageJson,
      Value<String?> geneticsJson,
      Value<String?> likelihoodAnalysisJson,
      Value<int> staminaMax,
      Value<int> staminaBars,
      Value<int> staminaLastUtcMs,
      Value<int> createdAtUtcMs,
      Value<String?> alchemyEffect,
      Value<double> statSpeed,
      Value<double> statIntelligence,
      Value<double> statStrength,
      Value<double> statBeauty,
      Value<double> statSpeedPotential,
      Value<double> statIntelligencePotential,
      Value<double> statStrengthPotential,
      Value<double> statBeautyPotential,
      Value<int> generationDepth,
      Value<String?> factionLineageJson,
      Value<String?> variantFaction,
      Value<bool> isPure,
      Value<String?> elementLineageJson,
      Value<String?> familyLineageJson,
      Value<int> rowid,
    });
typedef $$CreatureInstancesTableUpdateCompanionBuilder =
    CreatureInstancesCompanion Function({
      Value<String> instanceId,
      Value<String> baseId,
      Value<int> level,
      Value<int> xp,
      Value<bool> locked,
      Value<String?> nickname,
      Value<bool> isPrismaticSkin,
      Value<String?> natureId,
      Value<String> source,
      Value<String?> parentageJson,
      Value<String?> geneticsJson,
      Value<String?> likelihoodAnalysisJson,
      Value<int> staminaMax,
      Value<int> staminaBars,
      Value<int> staminaLastUtcMs,
      Value<int> createdAtUtcMs,
      Value<String?> alchemyEffect,
      Value<double> statSpeed,
      Value<double> statIntelligence,
      Value<double> statStrength,
      Value<double> statBeauty,
      Value<double> statSpeedPotential,
      Value<double> statIntelligencePotential,
      Value<double> statStrengthPotential,
      Value<double> statBeautyPotential,
      Value<int> generationDepth,
      Value<String?> factionLineageJson,
      Value<String?> variantFaction,
      Value<bool> isPure,
      Value<String?> elementLineageJson,
      Value<String?> familyLineageJson,
      Value<int> rowid,
    });

class $$CreatureInstancesTableFilterComposer
    extends Composer<_$AlchemonsDatabase, $CreatureInstancesTable> {
  $$CreatureInstancesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get instanceId => $composableBuilder(
    column: $table.instanceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseId => $composableBuilder(
    column: $table.baseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get xp => $composableBuilder(
    column: $table.xp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get locked => $composableBuilder(
    column: $table.locked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPrismaticSkin => $composableBuilder(
    column: $table.isPrismaticSkin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get natureId => $composableBuilder(
    column: $table.natureId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentageJson => $composableBuilder(
    column: $table.parentageJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get geneticsJson => $composableBuilder(
    column: $table.geneticsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get likelihoodAnalysisJson => $composableBuilder(
    column: $table.likelihoodAnalysisJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get staminaMax => $composableBuilder(
    column: $table.staminaMax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get staminaBars => $composableBuilder(
    column: $table.staminaBars,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get staminaLastUtcMs => $composableBuilder(
    column: $table.staminaLastUtcMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtcMs => $composableBuilder(
    column: $table.createdAtUtcMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alchemyEffect => $composableBuilder(
    column: $table.alchemyEffect,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get statSpeed => $composableBuilder(
    column: $table.statSpeed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get statIntelligence => $composableBuilder(
    column: $table.statIntelligence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get statStrength => $composableBuilder(
    column: $table.statStrength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get statBeauty => $composableBuilder(
    column: $table.statBeauty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get statSpeedPotential => $composableBuilder(
    column: $table.statSpeedPotential,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get statIntelligencePotential => $composableBuilder(
    column: $table.statIntelligencePotential,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get statStrengthPotential => $composableBuilder(
    column: $table.statStrengthPotential,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get statBeautyPotential => $composableBuilder(
    column: $table.statBeautyPotential,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get generationDepth => $composableBuilder(
    column: $table.generationDepth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get factionLineageJson => $composableBuilder(
    column: $table.factionLineageJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get variantFaction => $composableBuilder(
    column: $table.variantFaction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPure => $composableBuilder(
    column: $table.isPure,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get elementLineageJson => $composableBuilder(
    column: $table.elementLineageJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get familyLineageJson => $composableBuilder(
    column: $table.familyLineageJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CreatureInstancesTableOrderingComposer
    extends Composer<_$AlchemonsDatabase, $CreatureInstancesTable> {
  $$CreatureInstancesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get instanceId => $composableBuilder(
    column: $table.instanceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseId => $composableBuilder(
    column: $table.baseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get xp => $composableBuilder(
    column: $table.xp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get locked => $composableBuilder(
    column: $table.locked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPrismaticSkin => $composableBuilder(
    column: $table.isPrismaticSkin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get natureId => $composableBuilder(
    column: $table.natureId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentageJson => $composableBuilder(
    column: $table.parentageJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get geneticsJson => $composableBuilder(
    column: $table.geneticsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get likelihoodAnalysisJson => $composableBuilder(
    column: $table.likelihoodAnalysisJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get staminaMax => $composableBuilder(
    column: $table.staminaMax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get staminaBars => $composableBuilder(
    column: $table.staminaBars,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get staminaLastUtcMs => $composableBuilder(
    column: $table.staminaLastUtcMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtcMs => $composableBuilder(
    column: $table.createdAtUtcMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alchemyEffect => $composableBuilder(
    column: $table.alchemyEffect,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get statSpeed => $composableBuilder(
    column: $table.statSpeed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get statIntelligence => $composableBuilder(
    column: $table.statIntelligence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get statStrength => $composableBuilder(
    column: $table.statStrength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get statBeauty => $composableBuilder(
    column: $table.statBeauty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get statSpeedPotential => $composableBuilder(
    column: $table.statSpeedPotential,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get statIntelligencePotential => $composableBuilder(
    column: $table.statIntelligencePotential,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get statStrengthPotential => $composableBuilder(
    column: $table.statStrengthPotential,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get statBeautyPotential => $composableBuilder(
    column: $table.statBeautyPotential,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get generationDepth => $composableBuilder(
    column: $table.generationDepth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get factionLineageJson => $composableBuilder(
    column: $table.factionLineageJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get variantFaction => $composableBuilder(
    column: $table.variantFaction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPure => $composableBuilder(
    column: $table.isPure,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get elementLineageJson => $composableBuilder(
    column: $table.elementLineageJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get familyLineageJson => $composableBuilder(
    column: $table.familyLineageJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CreatureInstancesTableAnnotationComposer
    extends Composer<_$AlchemonsDatabase, $CreatureInstancesTable> {
  $$CreatureInstancesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get instanceId => $composableBuilder(
    column: $table.instanceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get baseId =>
      $composableBuilder(column: $table.baseId, builder: (column) => column);

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<int> get xp =>
      $composableBuilder(column: $table.xp, builder: (column) => column);

  GeneratedColumn<bool> get locked =>
      $composableBuilder(column: $table.locked, builder: (column) => column);

  GeneratedColumn<String> get nickname =>
      $composableBuilder(column: $table.nickname, builder: (column) => column);

  GeneratedColumn<bool> get isPrismaticSkin => $composableBuilder(
    column: $table.isPrismaticSkin,
    builder: (column) => column,
  );

  GeneratedColumn<String> get natureId =>
      $composableBuilder(column: $table.natureId, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get parentageJson => $composableBuilder(
    column: $table.parentageJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get geneticsJson => $composableBuilder(
    column: $table.geneticsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get likelihoodAnalysisJson => $composableBuilder(
    column: $table.likelihoodAnalysisJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get staminaMax => $composableBuilder(
    column: $table.staminaMax,
    builder: (column) => column,
  );

  GeneratedColumn<int> get staminaBars => $composableBuilder(
    column: $table.staminaBars,
    builder: (column) => column,
  );

  GeneratedColumn<int> get staminaLastUtcMs => $composableBuilder(
    column: $table.staminaLastUtcMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUtcMs => $composableBuilder(
    column: $table.createdAtUtcMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get alchemyEffect => $composableBuilder(
    column: $table.alchemyEffect,
    builder: (column) => column,
  );

  GeneratedColumn<double> get statSpeed =>
      $composableBuilder(column: $table.statSpeed, builder: (column) => column);

  GeneratedColumn<double> get statIntelligence => $composableBuilder(
    column: $table.statIntelligence,
    builder: (column) => column,
  );

  GeneratedColumn<double> get statStrength => $composableBuilder(
    column: $table.statStrength,
    builder: (column) => column,
  );

  GeneratedColumn<double> get statBeauty => $composableBuilder(
    column: $table.statBeauty,
    builder: (column) => column,
  );

  GeneratedColumn<double> get statSpeedPotential => $composableBuilder(
    column: $table.statSpeedPotential,
    builder: (column) => column,
  );

  GeneratedColumn<double> get statIntelligencePotential => $composableBuilder(
    column: $table.statIntelligencePotential,
    builder: (column) => column,
  );

  GeneratedColumn<double> get statStrengthPotential => $composableBuilder(
    column: $table.statStrengthPotential,
    builder: (column) => column,
  );

  GeneratedColumn<double> get statBeautyPotential => $composableBuilder(
    column: $table.statBeautyPotential,
    builder: (column) => column,
  );

  GeneratedColumn<int> get generationDepth => $composableBuilder(
    column: $table.generationDepth,
    builder: (column) => column,
  );

  GeneratedColumn<String> get factionLineageJson => $composableBuilder(
    column: $table.factionLineageJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get variantFaction => $composableBuilder(
    column: $table.variantFaction,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPure =>
      $composableBuilder(column: $table.isPure, builder: (column) => column);

  GeneratedColumn<String> get elementLineageJson => $composableBuilder(
    column: $table.elementLineageJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get familyLineageJson => $composableBuilder(
    column: $table.familyLineageJson,
    builder: (column) => column,
  );
}

class $$CreatureInstancesTableTableManager
    extends
        RootTableManager<
          _$AlchemonsDatabase,
          $CreatureInstancesTable,
          CreatureInstance,
          $$CreatureInstancesTableFilterComposer,
          $$CreatureInstancesTableOrderingComposer,
          $$CreatureInstancesTableAnnotationComposer,
          $$CreatureInstancesTableCreateCompanionBuilder,
          $$CreatureInstancesTableUpdateCompanionBuilder,
          (
            CreatureInstance,
            BaseReferences<
              _$AlchemonsDatabase,
              $CreatureInstancesTable,
              CreatureInstance
            >,
          ),
          CreatureInstance,
          PrefetchHooks Function()
        > {
  $$CreatureInstancesTableTableManager(
    _$AlchemonsDatabase db,
    $CreatureInstancesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CreatureInstancesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CreatureInstancesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CreatureInstancesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> instanceId = const Value.absent(),
                Value<String> baseId = const Value.absent(),
                Value<int> level = const Value.absent(),
                Value<int> xp = const Value.absent(),
                Value<bool> locked = const Value.absent(),
                Value<String?> nickname = const Value.absent(),
                Value<bool> isPrismaticSkin = const Value.absent(),
                Value<String?> natureId = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> parentageJson = const Value.absent(),
                Value<String?> geneticsJson = const Value.absent(),
                Value<String?> likelihoodAnalysisJson = const Value.absent(),
                Value<int> staminaMax = const Value.absent(),
                Value<int> staminaBars = const Value.absent(),
                Value<int> staminaLastUtcMs = const Value.absent(),
                Value<int> createdAtUtcMs = const Value.absent(),
                Value<String?> alchemyEffect = const Value.absent(),
                Value<double> statSpeed = const Value.absent(),
                Value<double> statIntelligence = const Value.absent(),
                Value<double> statStrength = const Value.absent(),
                Value<double> statBeauty = const Value.absent(),
                Value<double> statSpeedPotential = const Value.absent(),
                Value<double> statIntelligencePotential = const Value.absent(),
                Value<double> statStrengthPotential = const Value.absent(),
                Value<double> statBeautyPotential = const Value.absent(),
                Value<int> generationDepth = const Value.absent(),
                Value<String?> factionLineageJson = const Value.absent(),
                Value<String?> variantFaction = const Value.absent(),
                Value<bool> isPure = const Value.absent(),
                Value<String?> elementLineageJson = const Value.absent(),
                Value<String?> familyLineageJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CreatureInstancesCompanion(
                instanceId: instanceId,
                baseId: baseId,
                level: level,
                xp: xp,
                locked: locked,
                nickname: nickname,
                isPrismaticSkin: isPrismaticSkin,
                natureId: natureId,
                source: source,
                parentageJson: parentageJson,
                geneticsJson: geneticsJson,
                likelihoodAnalysisJson: likelihoodAnalysisJson,
                staminaMax: staminaMax,
                staminaBars: staminaBars,
                staminaLastUtcMs: staminaLastUtcMs,
                createdAtUtcMs: createdAtUtcMs,
                alchemyEffect: alchemyEffect,
                statSpeed: statSpeed,
                statIntelligence: statIntelligence,
                statStrength: statStrength,
                statBeauty: statBeauty,
                statSpeedPotential: statSpeedPotential,
                statIntelligencePotential: statIntelligencePotential,
                statStrengthPotential: statStrengthPotential,
                statBeautyPotential: statBeautyPotential,
                generationDepth: generationDepth,
                factionLineageJson: factionLineageJson,
                variantFaction: variantFaction,
                isPure: isPure,
                elementLineageJson: elementLineageJson,
                familyLineageJson: familyLineageJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String instanceId,
                required String baseId,
                Value<int> level = const Value.absent(),
                Value<int> xp = const Value.absent(),
                Value<bool> locked = const Value.absent(),
                Value<String?> nickname = const Value.absent(),
                Value<bool> isPrismaticSkin = const Value.absent(),
                Value<String?> natureId = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> parentageJson = const Value.absent(),
                Value<String?> geneticsJson = const Value.absent(),
                Value<String?> likelihoodAnalysisJson = const Value.absent(),
                Value<int> staminaMax = const Value.absent(),
                Value<int> staminaBars = const Value.absent(),
                Value<int> staminaLastUtcMs = const Value.absent(),
                Value<int> createdAtUtcMs = const Value.absent(),
                Value<String?> alchemyEffect = const Value.absent(),
                Value<double> statSpeed = const Value.absent(),
                Value<double> statIntelligence = const Value.absent(),
                Value<double> statStrength = const Value.absent(),
                Value<double> statBeauty = const Value.absent(),
                Value<double> statSpeedPotential = const Value.absent(),
                Value<double> statIntelligencePotential = const Value.absent(),
                Value<double> statStrengthPotential = const Value.absent(),
                Value<double> statBeautyPotential = const Value.absent(),
                Value<int> generationDepth = const Value.absent(),
                Value<String?> factionLineageJson = const Value.absent(),
                Value<String?> variantFaction = const Value.absent(),
                Value<bool> isPure = const Value.absent(),
                Value<String?> elementLineageJson = const Value.absent(),
                Value<String?> familyLineageJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CreatureInstancesCompanion.insert(
                instanceId: instanceId,
                baseId: baseId,
                level: level,
                xp: xp,
                locked: locked,
                nickname: nickname,
                isPrismaticSkin: isPrismaticSkin,
                natureId: natureId,
                source: source,
                parentageJson: parentageJson,
                geneticsJson: geneticsJson,
                likelihoodAnalysisJson: likelihoodAnalysisJson,
                staminaMax: staminaMax,
                staminaBars: staminaBars,
                staminaLastUtcMs: staminaLastUtcMs,
                createdAtUtcMs: createdAtUtcMs,
                alchemyEffect: alchemyEffect,
                statSpeed: statSpeed,
                statIntelligence: statIntelligence,
                statStrength: statStrength,
                statBeauty: statBeauty,
                statSpeedPotential: statSpeedPotential,
                statIntelligencePotential: statIntelligencePotential,
                statStrengthPotential: statStrengthPotential,
                statBeautyPotential: statBeautyPotential,
                generationDepth: generationDepth,
                factionLineageJson: factionLineageJson,
                variantFaction: variantFaction,
                isPure: isPure,
                elementLineageJson: elementLineageJson,
                familyLineageJson: familyLineageJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CreatureInstancesTableProcessedTableManager =
    ProcessedTableManager<
      _$AlchemonsDatabase,
      $CreatureInstancesTable,
      CreatureInstance,
      $$CreatureInstancesTableFilterComposer,
      $$CreatureInstancesTableOrderingComposer,
      $$CreatureInstancesTableAnnotationComposer,
      $$CreatureInstancesTableCreateCompanionBuilder,
      $$CreatureInstancesTableUpdateCompanionBuilder,
      (
        CreatureInstance,
        BaseReferences<
          _$AlchemonsDatabase,
          $CreatureInstancesTable,
          CreatureInstance
        >,
      ),
      CreatureInstance,
      PrefetchHooks Function()
    >;
typedef $$FeedEventsTableCreateCompanionBuilder =
    FeedEventsCompanion Function({
      required String eventId,
      required String targetInstanceId,
      required String fodderInstanceId,
      required int xpGained,
      required int createdAtUtcMs,
      Value<int> rowid,
    });
typedef $$FeedEventsTableUpdateCompanionBuilder =
    FeedEventsCompanion Function({
      Value<String> eventId,
      Value<String> targetInstanceId,
      Value<String> fodderInstanceId,
      Value<int> xpGained,
      Value<int> createdAtUtcMs,
      Value<int> rowid,
    });

class $$FeedEventsTableFilterComposer
    extends Composer<_$AlchemonsDatabase, $FeedEventsTable> {
  $$FeedEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetInstanceId => $composableBuilder(
    column: $table.targetInstanceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fodderInstanceId => $composableBuilder(
    column: $table.fodderInstanceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get xpGained => $composableBuilder(
    column: $table.xpGained,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtcMs => $composableBuilder(
    column: $table.createdAtUtcMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FeedEventsTableOrderingComposer
    extends Composer<_$AlchemonsDatabase, $FeedEventsTable> {
  $$FeedEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetInstanceId => $composableBuilder(
    column: $table.targetInstanceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fodderInstanceId => $composableBuilder(
    column: $table.fodderInstanceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get xpGained => $composableBuilder(
    column: $table.xpGained,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtcMs => $composableBuilder(
    column: $table.createdAtUtcMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FeedEventsTableAnnotationComposer
    extends Composer<_$AlchemonsDatabase, $FeedEventsTable> {
  $$FeedEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get targetInstanceId => $composableBuilder(
    column: $table.targetInstanceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fodderInstanceId => $composableBuilder(
    column: $table.fodderInstanceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get xpGained =>
      $composableBuilder(column: $table.xpGained, builder: (column) => column);

  GeneratedColumn<int> get createdAtUtcMs => $composableBuilder(
    column: $table.createdAtUtcMs,
    builder: (column) => column,
  );
}

class $$FeedEventsTableTableManager
    extends
        RootTableManager<
          _$AlchemonsDatabase,
          $FeedEventsTable,
          FeedEvent,
          $$FeedEventsTableFilterComposer,
          $$FeedEventsTableOrderingComposer,
          $$FeedEventsTableAnnotationComposer,
          $$FeedEventsTableCreateCompanionBuilder,
          $$FeedEventsTableUpdateCompanionBuilder,
          (
            FeedEvent,
            BaseReferences<_$AlchemonsDatabase, $FeedEventsTable, FeedEvent>,
          ),
          FeedEvent,
          PrefetchHooks Function()
        > {
  $$FeedEventsTableTableManager(_$AlchemonsDatabase db, $FeedEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FeedEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FeedEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FeedEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> eventId = const Value.absent(),
                Value<String> targetInstanceId = const Value.absent(),
                Value<String> fodderInstanceId = const Value.absent(),
                Value<int> xpGained = const Value.absent(),
                Value<int> createdAtUtcMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FeedEventsCompanion(
                eventId: eventId,
                targetInstanceId: targetInstanceId,
                fodderInstanceId: fodderInstanceId,
                xpGained: xpGained,
                createdAtUtcMs: createdAtUtcMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String eventId,
                required String targetInstanceId,
                required String fodderInstanceId,
                required int xpGained,
                required int createdAtUtcMs,
                Value<int> rowid = const Value.absent(),
              }) => FeedEventsCompanion.insert(
                eventId: eventId,
                targetInstanceId: targetInstanceId,
                fodderInstanceId: fodderInstanceId,
                xpGained: xpGained,
                createdAtUtcMs: createdAtUtcMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FeedEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AlchemonsDatabase,
      $FeedEventsTable,
      FeedEvent,
      $$FeedEventsTableFilterComposer,
      $$FeedEventsTableOrderingComposer,
      $$FeedEventsTableAnnotationComposer,
      $$FeedEventsTableCreateCompanionBuilder,
      $$FeedEventsTableUpdateCompanionBuilder,
      (
        FeedEvent,
        BaseReferences<_$AlchemonsDatabase, $FeedEventsTable, FeedEvent>,
      ),
      FeedEvent,
      PrefetchHooks Function()
    >;
typedef $$BiomeFarmsTableCreateCompanionBuilder =
    BiomeFarmsCompanion Function({
      Value<int> id,
      required String biomeId,
      Value<bool> unlocked,
      Value<int> level,
      Value<String?> activeElementId,
    });
typedef $$BiomeFarmsTableUpdateCompanionBuilder =
    BiomeFarmsCompanion Function({
      Value<int> id,
      Value<String> biomeId,
      Value<bool> unlocked,
      Value<int> level,
      Value<String?> activeElementId,
    });

class $$BiomeFarmsTableFilterComposer
    extends Composer<_$AlchemonsDatabase, $BiomeFarmsTable> {
  $$BiomeFarmsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get biomeId => $composableBuilder(
    column: $table.biomeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get unlocked => $composableBuilder(
    column: $table.unlocked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activeElementId => $composableBuilder(
    column: $table.activeElementId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BiomeFarmsTableOrderingComposer
    extends Composer<_$AlchemonsDatabase, $BiomeFarmsTable> {
  $$BiomeFarmsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get biomeId => $composableBuilder(
    column: $table.biomeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get unlocked => $composableBuilder(
    column: $table.unlocked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activeElementId => $composableBuilder(
    column: $table.activeElementId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BiomeFarmsTableAnnotationComposer
    extends Composer<_$AlchemonsDatabase, $BiomeFarmsTable> {
  $$BiomeFarmsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get biomeId =>
      $composableBuilder(column: $table.biomeId, builder: (column) => column);

  GeneratedColumn<bool> get unlocked =>
      $composableBuilder(column: $table.unlocked, builder: (column) => column);

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get activeElementId => $composableBuilder(
    column: $table.activeElementId,
    builder: (column) => column,
  );
}

class $$BiomeFarmsTableTableManager
    extends
        RootTableManager<
          _$AlchemonsDatabase,
          $BiomeFarmsTable,
          BiomeFarm,
          $$BiomeFarmsTableFilterComposer,
          $$BiomeFarmsTableOrderingComposer,
          $$BiomeFarmsTableAnnotationComposer,
          $$BiomeFarmsTableCreateCompanionBuilder,
          $$BiomeFarmsTableUpdateCompanionBuilder,
          (
            BiomeFarm,
            BaseReferences<_$AlchemonsDatabase, $BiomeFarmsTable, BiomeFarm>,
          ),
          BiomeFarm,
          PrefetchHooks Function()
        > {
  $$BiomeFarmsTableTableManager(_$AlchemonsDatabase db, $BiomeFarmsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BiomeFarmsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BiomeFarmsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BiomeFarmsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> biomeId = const Value.absent(),
                Value<bool> unlocked = const Value.absent(),
                Value<int> level = const Value.absent(),
                Value<String?> activeElementId = const Value.absent(),
              }) => BiomeFarmsCompanion(
                id: id,
                biomeId: biomeId,
                unlocked: unlocked,
                level: level,
                activeElementId: activeElementId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String biomeId,
                Value<bool> unlocked = const Value.absent(),
                Value<int> level = const Value.absent(),
                Value<String?> activeElementId = const Value.absent(),
              }) => BiomeFarmsCompanion.insert(
                id: id,
                biomeId: biomeId,
                unlocked: unlocked,
                level: level,
                activeElementId: activeElementId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BiomeFarmsTableProcessedTableManager =
    ProcessedTableManager<
      _$AlchemonsDatabase,
      $BiomeFarmsTable,
      BiomeFarm,
      $$BiomeFarmsTableFilterComposer,
      $$BiomeFarmsTableOrderingComposer,
      $$BiomeFarmsTableAnnotationComposer,
      $$BiomeFarmsTableCreateCompanionBuilder,
      $$BiomeFarmsTableUpdateCompanionBuilder,
      (
        BiomeFarm,
        BaseReferences<_$AlchemonsDatabase, $BiomeFarmsTable, BiomeFarm>,
      ),
      BiomeFarm,
      PrefetchHooks Function()
    >;
typedef $$BiomeJobsTableCreateCompanionBuilder =
    BiomeJobsCompanion Function({
      required String jobId,
      required int biomeId,
      required String creatureInstanceId,
      required int startUtcMs,
      required int durationMs,
      required int ratePerMinute,
      Value<int> rowid,
    });
typedef $$BiomeJobsTableUpdateCompanionBuilder =
    BiomeJobsCompanion Function({
      Value<String> jobId,
      Value<int> biomeId,
      Value<String> creatureInstanceId,
      Value<int> startUtcMs,
      Value<int> durationMs,
      Value<int> ratePerMinute,
      Value<int> rowid,
    });

class $$BiomeJobsTableFilterComposer
    extends Composer<_$AlchemonsDatabase, $BiomeJobsTable> {
  $$BiomeJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get jobId => $composableBuilder(
    column: $table.jobId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get biomeId => $composableBuilder(
    column: $table.biomeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creatureInstanceId => $composableBuilder(
    column: $table.creatureInstanceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startUtcMs => $composableBuilder(
    column: $table.startUtcMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ratePerMinute => $composableBuilder(
    column: $table.ratePerMinute,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BiomeJobsTableOrderingComposer
    extends Composer<_$AlchemonsDatabase, $BiomeJobsTable> {
  $$BiomeJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get jobId => $composableBuilder(
    column: $table.jobId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get biomeId => $composableBuilder(
    column: $table.biomeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creatureInstanceId => $composableBuilder(
    column: $table.creatureInstanceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startUtcMs => $composableBuilder(
    column: $table.startUtcMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ratePerMinute => $composableBuilder(
    column: $table.ratePerMinute,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BiomeJobsTableAnnotationComposer
    extends Composer<_$AlchemonsDatabase, $BiomeJobsTable> {
  $$BiomeJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get jobId =>
      $composableBuilder(column: $table.jobId, builder: (column) => column);

  GeneratedColumn<int> get biomeId =>
      $composableBuilder(column: $table.biomeId, builder: (column) => column);

  GeneratedColumn<String> get creatureInstanceId => $composableBuilder(
    column: $table.creatureInstanceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startUtcMs => $composableBuilder(
    column: $table.startUtcMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get ratePerMinute => $composableBuilder(
    column: $table.ratePerMinute,
    builder: (column) => column,
  );
}

class $$BiomeJobsTableTableManager
    extends
        RootTableManager<
          _$AlchemonsDatabase,
          $BiomeJobsTable,
          BiomeJob,
          $$BiomeJobsTableFilterComposer,
          $$BiomeJobsTableOrderingComposer,
          $$BiomeJobsTableAnnotationComposer,
          $$BiomeJobsTableCreateCompanionBuilder,
          $$BiomeJobsTableUpdateCompanionBuilder,
          (
            BiomeJob,
            BaseReferences<_$AlchemonsDatabase, $BiomeJobsTable, BiomeJob>,
          ),
          BiomeJob,
          PrefetchHooks Function()
        > {
  $$BiomeJobsTableTableManager(_$AlchemonsDatabase db, $BiomeJobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BiomeJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BiomeJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BiomeJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> jobId = const Value.absent(),
                Value<int> biomeId = const Value.absent(),
                Value<String> creatureInstanceId = const Value.absent(),
                Value<int> startUtcMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> ratePerMinute = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BiomeJobsCompanion(
                jobId: jobId,
                biomeId: biomeId,
                creatureInstanceId: creatureInstanceId,
                startUtcMs: startUtcMs,
                durationMs: durationMs,
                ratePerMinute: ratePerMinute,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String jobId,
                required int biomeId,
                required String creatureInstanceId,
                required int startUtcMs,
                required int durationMs,
                required int ratePerMinute,
                Value<int> rowid = const Value.absent(),
              }) => BiomeJobsCompanion.insert(
                jobId: jobId,
                biomeId: biomeId,
                creatureInstanceId: creatureInstanceId,
                startUtcMs: startUtcMs,
                durationMs: durationMs,
                ratePerMinute: ratePerMinute,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BiomeJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AlchemonsDatabase,
      $BiomeJobsTable,
      BiomeJob,
      $$BiomeJobsTableFilterComposer,
      $$BiomeJobsTableOrderingComposer,
      $$BiomeJobsTableAnnotationComposer,
      $$BiomeJobsTableCreateCompanionBuilder,
      $$BiomeJobsTableUpdateCompanionBuilder,
      (
        BiomeJob,
        BaseReferences<_$AlchemonsDatabase, $BiomeJobsTable, BiomeJob>,
      ),
      BiomeJob,
      PrefetchHooks Function()
    >;
typedef $$CompetitionProgressTableCreateCompanionBuilder =
    CompetitionProgressCompanion Function({
      required String biome,
      Value<int> highestLevelCompleted,
      Value<int> totalWins,
      Value<int> totalLosses,
      Value<DateTime?> lastCompletedAt,
      Value<int> rowid,
    });
typedef $$CompetitionProgressTableUpdateCompanionBuilder =
    CompetitionProgressCompanion Function({
      Value<String> biome,
      Value<int> highestLevelCompleted,
      Value<int> totalWins,
      Value<int> totalLosses,
      Value<DateTime?> lastCompletedAt,
      Value<int> rowid,
    });

class $$CompetitionProgressTableFilterComposer
    extends Composer<_$AlchemonsDatabase, $CompetitionProgressTable> {
  $$CompetitionProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get biome => $composableBuilder(
    column: $table.biome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get highestLevelCompleted => $composableBuilder(
    column: $table.highestLevelCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalWins => $composableBuilder(
    column: $table.totalWins,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalLosses => $composableBuilder(
    column: $table.totalLosses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastCompletedAt => $composableBuilder(
    column: $table.lastCompletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CompetitionProgressTableOrderingComposer
    extends Composer<_$AlchemonsDatabase, $CompetitionProgressTable> {
  $$CompetitionProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get biome => $composableBuilder(
    column: $table.biome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get highestLevelCompleted => $composableBuilder(
    column: $table.highestLevelCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalWins => $composableBuilder(
    column: $table.totalWins,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalLosses => $composableBuilder(
    column: $table.totalLosses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastCompletedAt => $composableBuilder(
    column: $table.lastCompletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CompetitionProgressTableAnnotationComposer
    extends Composer<_$AlchemonsDatabase, $CompetitionProgressTable> {
  $$CompetitionProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get biome =>
      $composableBuilder(column: $table.biome, builder: (column) => column);

  GeneratedColumn<int> get highestLevelCompleted => $composableBuilder(
    column: $table.highestLevelCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalWins =>
      $composableBuilder(column: $table.totalWins, builder: (column) => column);

  GeneratedColumn<int> get totalLosses => $composableBuilder(
    column: $table.totalLosses,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastCompletedAt => $composableBuilder(
    column: $table.lastCompletedAt,
    builder: (column) => column,
  );
}

class $$CompetitionProgressTableTableManager
    extends
        RootTableManager<
          _$AlchemonsDatabase,
          $CompetitionProgressTable,
          CompetitionProgressData,
          $$CompetitionProgressTableFilterComposer,
          $$CompetitionProgressTableOrderingComposer,
          $$CompetitionProgressTableAnnotationComposer,
          $$CompetitionProgressTableCreateCompanionBuilder,
          $$CompetitionProgressTableUpdateCompanionBuilder,
          (
            CompetitionProgressData,
            BaseReferences<
              _$AlchemonsDatabase,
              $CompetitionProgressTable,
              CompetitionProgressData
            >,
          ),
          CompetitionProgressData,
          PrefetchHooks Function()
        > {
  $$CompetitionProgressTableTableManager(
    _$AlchemonsDatabase db,
    $CompetitionProgressTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CompetitionProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CompetitionProgressTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CompetitionProgressTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> biome = const Value.absent(),
                Value<int> highestLevelCompleted = const Value.absent(),
                Value<int> totalWins = const Value.absent(),
                Value<int> totalLosses = const Value.absent(),
                Value<DateTime?> lastCompletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CompetitionProgressCompanion(
                biome: biome,
                highestLevelCompleted: highestLevelCompleted,
                totalWins: totalWins,
                totalLosses: totalLosses,
                lastCompletedAt: lastCompletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String biome,
                Value<int> highestLevelCompleted = const Value.absent(),
                Value<int> totalWins = const Value.absent(),
                Value<int> totalLosses = const Value.absent(),
                Value<DateTime?> lastCompletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CompetitionProgressCompanion.insert(
                biome: biome,
                highestLevelCompleted: highestLevelCompleted,
                totalWins: totalWins,
                totalLosses: totalLosses,
                lastCompletedAt: lastCompletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CompetitionProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AlchemonsDatabase,
      $CompetitionProgressTable,
      CompetitionProgressData,
      $$CompetitionProgressTableFilterComposer,
      $$CompetitionProgressTableOrderingComposer,
      $$CompetitionProgressTableAnnotationComposer,
      $$CompetitionProgressTableCreateCompanionBuilder,
      $$CompetitionProgressTableUpdateCompanionBuilder,
      (
        CompetitionProgressData,
        BaseReferences<
          _$AlchemonsDatabase,
          $CompetitionProgressTable,
          CompetitionProgressData
        >,
      ),
      CompetitionProgressData,
      PrefetchHooks Function()
    >;
typedef $$ShopPurchasesTableCreateCompanionBuilder =
    ShopPurchasesCompanion Function({
      required String offerId,
      Value<int> purchaseCount,
      Value<int?> lastPurchaseUtcMs,
      Value<int> rowid,
    });
typedef $$ShopPurchasesTableUpdateCompanionBuilder =
    ShopPurchasesCompanion Function({
      Value<String> offerId,
      Value<int> purchaseCount,
      Value<int?> lastPurchaseUtcMs,
      Value<int> rowid,
    });

class $$ShopPurchasesTableFilterComposer
    extends Composer<_$AlchemonsDatabase, $ShopPurchasesTable> {
  $$ShopPurchasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get offerId => $composableBuilder(
    column: $table.offerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get purchaseCount => $composableBuilder(
    column: $table.purchaseCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPurchaseUtcMs => $composableBuilder(
    column: $table.lastPurchaseUtcMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ShopPurchasesTableOrderingComposer
    extends Composer<_$AlchemonsDatabase, $ShopPurchasesTable> {
  $$ShopPurchasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get offerId => $composableBuilder(
    column: $table.offerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get purchaseCount => $composableBuilder(
    column: $table.purchaseCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPurchaseUtcMs => $composableBuilder(
    column: $table.lastPurchaseUtcMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ShopPurchasesTableAnnotationComposer
    extends Composer<_$AlchemonsDatabase, $ShopPurchasesTable> {
  $$ShopPurchasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get offerId =>
      $composableBuilder(column: $table.offerId, builder: (column) => column);

  GeneratedColumn<int> get purchaseCount => $composableBuilder(
    column: $table.purchaseCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastPurchaseUtcMs => $composableBuilder(
    column: $table.lastPurchaseUtcMs,
    builder: (column) => column,
  );
}

class $$ShopPurchasesTableTableManager
    extends
        RootTableManager<
          _$AlchemonsDatabase,
          $ShopPurchasesTable,
          ShopPurchase,
          $$ShopPurchasesTableFilterComposer,
          $$ShopPurchasesTableOrderingComposer,
          $$ShopPurchasesTableAnnotationComposer,
          $$ShopPurchasesTableCreateCompanionBuilder,
          $$ShopPurchasesTableUpdateCompanionBuilder,
          (
            ShopPurchase,
            BaseReferences<
              _$AlchemonsDatabase,
              $ShopPurchasesTable,
              ShopPurchase
            >,
          ),
          ShopPurchase,
          PrefetchHooks Function()
        > {
  $$ShopPurchasesTableTableManager(
    _$AlchemonsDatabase db,
    $ShopPurchasesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShopPurchasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShopPurchasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShopPurchasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> offerId = const Value.absent(),
                Value<int> purchaseCount = const Value.absent(),
                Value<int?> lastPurchaseUtcMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShopPurchasesCompanion(
                offerId: offerId,
                purchaseCount: purchaseCount,
                lastPurchaseUtcMs: lastPurchaseUtcMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String offerId,
                Value<int> purchaseCount = const Value.absent(),
                Value<int?> lastPurchaseUtcMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShopPurchasesCompanion.insert(
                offerId: offerId,
                purchaseCount: purchaseCount,
                lastPurchaseUtcMs: lastPurchaseUtcMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ShopPurchasesTableProcessedTableManager =
    ProcessedTableManager<
      _$AlchemonsDatabase,
      $ShopPurchasesTable,
      ShopPurchase,
      $$ShopPurchasesTableFilterComposer,
      $$ShopPurchasesTableOrderingComposer,
      $$ShopPurchasesTableAnnotationComposer,
      $$ShopPurchasesTableCreateCompanionBuilder,
      $$ShopPurchasesTableUpdateCompanionBuilder,
      (
        ShopPurchase,
        BaseReferences<_$AlchemonsDatabase, $ShopPurchasesTable, ShopPurchase>,
      ),
      ShopPurchase,
      PrefetchHooks Function()
    >;
typedef $$InventoryItemsTableCreateCompanionBuilder =
    InventoryItemsCompanion Function({
      required String key,
      Value<int> qty,
      Value<int> rowid,
    });
typedef $$InventoryItemsTableUpdateCompanionBuilder =
    InventoryItemsCompanion Function({
      Value<String> key,
      Value<int> qty,
      Value<int> rowid,
    });

class $$InventoryItemsTableFilterComposer
    extends Composer<_$AlchemonsDatabase, $InventoryItemsTable> {
  $$InventoryItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InventoryItemsTableOrderingComposer
    extends Composer<_$AlchemonsDatabase, $InventoryItemsTable> {
  $$InventoryItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InventoryItemsTableAnnotationComposer
    extends Composer<_$AlchemonsDatabase, $InventoryItemsTable> {
  $$InventoryItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<int> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => column);
}

class $$InventoryItemsTableTableManager
    extends
        RootTableManager<
          _$AlchemonsDatabase,
          $InventoryItemsTable,
          InventoryItem,
          $$InventoryItemsTableFilterComposer,
          $$InventoryItemsTableOrderingComposer,
          $$InventoryItemsTableAnnotationComposer,
          $$InventoryItemsTableCreateCompanionBuilder,
          $$InventoryItemsTableUpdateCompanionBuilder,
          (
            InventoryItem,
            BaseReferences<
              _$AlchemonsDatabase,
              $InventoryItemsTable,
              InventoryItem
            >,
          ),
          InventoryItem,
          PrefetchHooks Function()
        > {
  $$InventoryItemsTableTableManager(
    _$AlchemonsDatabase db,
    $InventoryItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InventoryItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InventoryItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InventoryItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<int> qty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InventoryItemsCompanion(key: key, qty: qty, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                Value<int> qty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InventoryItemsCompanion.insert(
                key: key,
                qty: qty,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InventoryItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AlchemonsDatabase,
      $InventoryItemsTable,
      InventoryItem,
      $$InventoryItemsTableFilterComposer,
      $$InventoryItemsTableOrderingComposer,
      $$InventoryItemsTableAnnotationComposer,
      $$InventoryItemsTableCreateCompanionBuilder,
      $$InventoryItemsTableUpdateCompanionBuilder,
      (
        InventoryItem,
        BaseReferences<
          _$AlchemonsDatabase,
          $InventoryItemsTable,
          InventoryItem
        >,
      ),
      InventoryItem,
      PrefetchHooks Function()
    >;
typedef $$ActiveSpawnsTableCreateCompanionBuilder =
    ActiveSpawnsCompanion Function({
      required String id,
      required String sceneId,
      required String spawnPointId,
      required String speciesId,
      required String rarity,
      required int spawnedAtUtcMs,
      Value<int> rowid,
    });
typedef $$ActiveSpawnsTableUpdateCompanionBuilder =
    ActiveSpawnsCompanion Function({
      Value<String> id,
      Value<String> sceneId,
      Value<String> spawnPointId,
      Value<String> speciesId,
      Value<String> rarity,
      Value<int> spawnedAtUtcMs,
      Value<int> rowid,
    });

class $$ActiveSpawnsTableFilterComposer
    extends Composer<_$AlchemonsDatabase, $ActiveSpawnsTable> {
  $$ActiveSpawnsTableFilterComposer({
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

  ColumnFilters<String> get sceneId => $composableBuilder(
    column: $table.sceneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spawnPointId => $composableBuilder(
    column: $table.spawnPointId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get speciesId => $composableBuilder(
    column: $table.speciesId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rarity => $composableBuilder(
    column: $table.rarity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get spawnedAtUtcMs => $composableBuilder(
    column: $table.spawnedAtUtcMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ActiveSpawnsTableOrderingComposer
    extends Composer<_$AlchemonsDatabase, $ActiveSpawnsTable> {
  $$ActiveSpawnsTableOrderingComposer({
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

  ColumnOrderings<String> get sceneId => $composableBuilder(
    column: $table.sceneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spawnPointId => $composableBuilder(
    column: $table.spawnPointId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get speciesId => $composableBuilder(
    column: $table.speciesId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rarity => $composableBuilder(
    column: $table.rarity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get spawnedAtUtcMs => $composableBuilder(
    column: $table.spawnedAtUtcMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActiveSpawnsTableAnnotationComposer
    extends Composer<_$AlchemonsDatabase, $ActiveSpawnsTable> {
  $$ActiveSpawnsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sceneId =>
      $composableBuilder(column: $table.sceneId, builder: (column) => column);

  GeneratedColumn<String> get spawnPointId => $composableBuilder(
    column: $table.spawnPointId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get speciesId =>
      $composableBuilder(column: $table.speciesId, builder: (column) => column);

  GeneratedColumn<String> get rarity =>
      $composableBuilder(column: $table.rarity, builder: (column) => column);

  GeneratedColumn<int> get spawnedAtUtcMs => $composableBuilder(
    column: $table.spawnedAtUtcMs,
    builder: (column) => column,
  );
}

class $$ActiveSpawnsTableTableManager
    extends
        RootTableManager<
          _$AlchemonsDatabase,
          $ActiveSpawnsTable,
          ActiveSpawn,
          $$ActiveSpawnsTableFilterComposer,
          $$ActiveSpawnsTableOrderingComposer,
          $$ActiveSpawnsTableAnnotationComposer,
          $$ActiveSpawnsTableCreateCompanionBuilder,
          $$ActiveSpawnsTableUpdateCompanionBuilder,
          (
            ActiveSpawn,
            BaseReferences<
              _$AlchemonsDatabase,
              $ActiveSpawnsTable,
              ActiveSpawn
            >,
          ),
          ActiveSpawn,
          PrefetchHooks Function()
        > {
  $$ActiveSpawnsTableTableManager(
    _$AlchemonsDatabase db,
    $ActiveSpawnsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActiveSpawnsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActiveSpawnsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActiveSpawnsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sceneId = const Value.absent(),
                Value<String> spawnPointId = const Value.absent(),
                Value<String> speciesId = const Value.absent(),
                Value<String> rarity = const Value.absent(),
                Value<int> spawnedAtUtcMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActiveSpawnsCompanion(
                id: id,
                sceneId: sceneId,
                spawnPointId: spawnPointId,
                speciesId: speciesId,
                rarity: rarity,
                spawnedAtUtcMs: spawnedAtUtcMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sceneId,
                required String spawnPointId,
                required String speciesId,
                required String rarity,
                required int spawnedAtUtcMs,
                Value<int> rowid = const Value.absent(),
              }) => ActiveSpawnsCompanion.insert(
                id: id,
                sceneId: sceneId,
                spawnPointId: spawnPointId,
                speciesId: speciesId,
                rarity: rarity,
                spawnedAtUtcMs: spawnedAtUtcMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActiveSpawnsTableProcessedTableManager =
    ProcessedTableManager<
      _$AlchemonsDatabase,
      $ActiveSpawnsTable,
      ActiveSpawn,
      $$ActiveSpawnsTableFilterComposer,
      $$ActiveSpawnsTableOrderingComposer,
      $$ActiveSpawnsTableAnnotationComposer,
      $$ActiveSpawnsTableCreateCompanionBuilder,
      $$ActiveSpawnsTableUpdateCompanionBuilder,
      (
        ActiveSpawn,
        BaseReferences<_$AlchemonsDatabase, $ActiveSpawnsTable, ActiveSpawn>,
      ),
      ActiveSpawn,
      PrefetchHooks Function()
    >;
typedef $$ActiveSceneEntryTableCreateCompanionBuilder =
    ActiveSceneEntryCompanion Function({
      required String sceneId,
      required int enteredAtUtcMs,
      Value<int> rowid,
    });
typedef $$ActiveSceneEntryTableUpdateCompanionBuilder =
    ActiveSceneEntryCompanion Function({
      Value<String> sceneId,
      Value<int> enteredAtUtcMs,
      Value<int> rowid,
    });

class $$ActiveSceneEntryTableFilterComposer
    extends Composer<_$AlchemonsDatabase, $ActiveSceneEntryTable> {
  $$ActiveSceneEntryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sceneId => $composableBuilder(
    column: $table.sceneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get enteredAtUtcMs => $composableBuilder(
    column: $table.enteredAtUtcMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ActiveSceneEntryTableOrderingComposer
    extends Composer<_$AlchemonsDatabase, $ActiveSceneEntryTable> {
  $$ActiveSceneEntryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sceneId => $composableBuilder(
    column: $table.sceneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get enteredAtUtcMs => $composableBuilder(
    column: $table.enteredAtUtcMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActiveSceneEntryTableAnnotationComposer
    extends Composer<_$AlchemonsDatabase, $ActiveSceneEntryTable> {
  $$ActiveSceneEntryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sceneId =>
      $composableBuilder(column: $table.sceneId, builder: (column) => column);

  GeneratedColumn<int> get enteredAtUtcMs => $composableBuilder(
    column: $table.enteredAtUtcMs,
    builder: (column) => column,
  );
}

class $$ActiveSceneEntryTableTableManager
    extends
        RootTableManager<
          _$AlchemonsDatabase,
          $ActiveSceneEntryTable,
          ActiveSceneEntryData,
          $$ActiveSceneEntryTableFilterComposer,
          $$ActiveSceneEntryTableOrderingComposer,
          $$ActiveSceneEntryTableAnnotationComposer,
          $$ActiveSceneEntryTableCreateCompanionBuilder,
          $$ActiveSceneEntryTableUpdateCompanionBuilder,
          (
            ActiveSceneEntryData,
            BaseReferences<
              _$AlchemonsDatabase,
              $ActiveSceneEntryTable,
              ActiveSceneEntryData
            >,
          ),
          ActiveSceneEntryData,
          PrefetchHooks Function()
        > {
  $$ActiveSceneEntryTableTableManager(
    _$AlchemonsDatabase db,
    $ActiveSceneEntryTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActiveSceneEntryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActiveSceneEntryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActiveSceneEntryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sceneId = const Value.absent(),
                Value<int> enteredAtUtcMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActiveSceneEntryCompanion(
                sceneId: sceneId,
                enteredAtUtcMs: enteredAtUtcMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sceneId,
                required int enteredAtUtcMs,
                Value<int> rowid = const Value.absent(),
              }) => ActiveSceneEntryCompanion.insert(
                sceneId: sceneId,
                enteredAtUtcMs: enteredAtUtcMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActiveSceneEntryTableProcessedTableManager =
    ProcessedTableManager<
      _$AlchemonsDatabase,
      $ActiveSceneEntryTable,
      ActiveSceneEntryData,
      $$ActiveSceneEntryTableFilterComposer,
      $$ActiveSceneEntryTableOrderingComposer,
      $$ActiveSceneEntryTableAnnotationComposer,
      $$ActiveSceneEntryTableCreateCompanionBuilder,
      $$ActiveSceneEntryTableUpdateCompanionBuilder,
      (
        ActiveSceneEntryData,
        BaseReferences<
          _$AlchemonsDatabase,
          $ActiveSceneEntryTable,
          ActiveSceneEntryData
        >,
      ),
      ActiveSceneEntryData,
      PrefetchHooks Function()
    >;
typedef $$SpawnScheduleTableCreateCompanionBuilder =
    SpawnScheduleCompanion Function({
      required String sceneId,
      required int dueAtUtcMs,
      Value<int> rowid,
    });
typedef $$SpawnScheduleTableUpdateCompanionBuilder =
    SpawnScheduleCompanion Function({
      Value<String> sceneId,
      Value<int> dueAtUtcMs,
      Value<int> rowid,
    });

class $$SpawnScheduleTableFilterComposer
    extends Composer<_$AlchemonsDatabase, $SpawnScheduleTable> {
  $$SpawnScheduleTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sceneId => $composableBuilder(
    column: $table.sceneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueAtUtcMs => $composableBuilder(
    column: $table.dueAtUtcMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SpawnScheduleTableOrderingComposer
    extends Composer<_$AlchemonsDatabase, $SpawnScheduleTable> {
  $$SpawnScheduleTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sceneId => $composableBuilder(
    column: $table.sceneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueAtUtcMs => $composableBuilder(
    column: $table.dueAtUtcMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SpawnScheduleTableAnnotationComposer
    extends Composer<_$AlchemonsDatabase, $SpawnScheduleTable> {
  $$SpawnScheduleTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sceneId =>
      $composableBuilder(column: $table.sceneId, builder: (column) => column);

  GeneratedColumn<int> get dueAtUtcMs => $composableBuilder(
    column: $table.dueAtUtcMs,
    builder: (column) => column,
  );
}

class $$SpawnScheduleTableTableManager
    extends
        RootTableManager<
          _$AlchemonsDatabase,
          $SpawnScheduleTable,
          SpawnScheduleData,
          $$SpawnScheduleTableFilterComposer,
          $$SpawnScheduleTableOrderingComposer,
          $$SpawnScheduleTableAnnotationComposer,
          $$SpawnScheduleTableCreateCompanionBuilder,
          $$SpawnScheduleTableUpdateCompanionBuilder,
          (
            SpawnScheduleData,
            BaseReferences<
              _$AlchemonsDatabase,
              $SpawnScheduleTable,
              SpawnScheduleData
            >,
          ),
          SpawnScheduleData,
          PrefetchHooks Function()
        > {
  $$SpawnScheduleTableTableManager(
    _$AlchemonsDatabase db,
    $SpawnScheduleTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpawnScheduleTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpawnScheduleTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpawnScheduleTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sceneId = const Value.absent(),
                Value<int> dueAtUtcMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SpawnScheduleCompanion(
                sceneId: sceneId,
                dueAtUtcMs: dueAtUtcMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sceneId,
                required int dueAtUtcMs,
                Value<int> rowid = const Value.absent(),
              }) => SpawnScheduleCompanion.insert(
                sceneId: sceneId,
                dueAtUtcMs: dueAtUtcMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SpawnScheduleTableProcessedTableManager =
    ProcessedTableManager<
      _$AlchemonsDatabase,
      $SpawnScheduleTable,
      SpawnScheduleData,
      $$SpawnScheduleTableFilterComposer,
      $$SpawnScheduleTableOrderingComposer,
      $$SpawnScheduleTableAnnotationComposer,
      $$SpawnScheduleTableCreateCompanionBuilder,
      $$SpawnScheduleTableUpdateCompanionBuilder,
      (
        SpawnScheduleData,
        BaseReferences<
          _$AlchemonsDatabase,
          $SpawnScheduleTable,
          SpawnScheduleData
        >,
      ),
      SpawnScheduleData,
      PrefetchHooks Function()
    >;
typedef $$NotificationDismissalsTableCreateCompanionBuilder =
    NotificationDismissalsCompanion Function({
      required String notificationType,
      required int dismissedAtUtcMs,
      Value<int> rowid,
    });
typedef $$NotificationDismissalsTableUpdateCompanionBuilder =
    NotificationDismissalsCompanion Function({
      Value<String> notificationType,
      Value<int> dismissedAtUtcMs,
      Value<int> rowid,
    });

class $$NotificationDismissalsTableFilterComposer
    extends Composer<_$AlchemonsDatabase, $NotificationDismissalsTable> {
  $$NotificationDismissalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get notificationType => $composableBuilder(
    column: $table.notificationType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dismissedAtUtcMs => $composableBuilder(
    column: $table.dismissedAtUtcMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotificationDismissalsTableOrderingComposer
    extends Composer<_$AlchemonsDatabase, $NotificationDismissalsTable> {
  $$NotificationDismissalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get notificationType => $composableBuilder(
    column: $table.notificationType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dismissedAtUtcMs => $composableBuilder(
    column: $table.dismissedAtUtcMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotificationDismissalsTableAnnotationComposer
    extends Composer<_$AlchemonsDatabase, $NotificationDismissalsTable> {
  $$NotificationDismissalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get notificationType => $composableBuilder(
    column: $table.notificationType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dismissedAtUtcMs => $composableBuilder(
    column: $table.dismissedAtUtcMs,
    builder: (column) => column,
  );
}

class $$NotificationDismissalsTableTableManager
    extends
        RootTableManager<
          _$AlchemonsDatabase,
          $NotificationDismissalsTable,
          NotificationDismissal,
          $$NotificationDismissalsTableFilterComposer,
          $$NotificationDismissalsTableOrderingComposer,
          $$NotificationDismissalsTableAnnotationComposer,
          $$NotificationDismissalsTableCreateCompanionBuilder,
          $$NotificationDismissalsTableUpdateCompanionBuilder,
          (
            NotificationDismissal,
            BaseReferences<
              _$AlchemonsDatabase,
              $NotificationDismissalsTable,
              NotificationDismissal
            >,
          ),
          NotificationDismissal,
          PrefetchHooks Function()
        > {
  $$NotificationDismissalsTableTableManager(
    _$AlchemonsDatabase db,
    $NotificationDismissalsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationDismissalsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$NotificationDismissalsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$NotificationDismissalsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> notificationType = const Value.absent(),
                Value<int> dismissedAtUtcMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotificationDismissalsCompanion(
                notificationType: notificationType,
                dismissedAtUtcMs: dismissedAtUtcMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String notificationType,
                required int dismissedAtUtcMs,
                Value<int> rowid = const Value.absent(),
              }) => NotificationDismissalsCompanion.insert(
                notificationType: notificationType,
                dismissedAtUtcMs: dismissedAtUtcMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotificationDismissalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AlchemonsDatabase,
      $NotificationDismissalsTable,
      NotificationDismissal,
      $$NotificationDismissalsTableFilterComposer,
      $$NotificationDismissalsTableOrderingComposer,
      $$NotificationDismissalsTableAnnotationComposer,
      $$NotificationDismissalsTableCreateCompanionBuilder,
      $$NotificationDismissalsTableUpdateCompanionBuilder,
      (
        NotificationDismissal,
        BaseReferences<
          _$AlchemonsDatabase,
          $NotificationDismissalsTable,
          NotificationDismissal
        >,
      ),
      NotificationDismissal,
      PrefetchHooks Function()
    >;
typedef $$ConstellationPointsTableCreateCompanionBuilder =
    ConstellationPointsCompanion Function({
      Value<int> id,
      Value<int> currentBalance,
      Value<int> totalEarned,
      Value<int> totalSpent,
      Value<bool> hasSeenFinale,
      required DateTime lastUpdatedUtc,
    });
typedef $$ConstellationPointsTableUpdateCompanionBuilder =
    ConstellationPointsCompanion Function({
      Value<int> id,
      Value<int> currentBalance,
      Value<int> totalEarned,
      Value<int> totalSpent,
      Value<bool> hasSeenFinale,
      Value<DateTime> lastUpdatedUtc,
    });

class $$ConstellationPointsTableFilterComposer
    extends Composer<_$AlchemonsDatabase, $ConstellationPointsTable> {
  $$ConstellationPointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentBalance => $composableBuilder(
    column: $table.currentBalance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalEarned => $composableBuilder(
    column: $table.totalEarned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalSpent => $composableBuilder(
    column: $table.totalSpent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasSeenFinale => $composableBuilder(
    column: $table.hasSeenFinale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUpdatedUtc => $composableBuilder(
    column: $table.lastUpdatedUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConstellationPointsTableOrderingComposer
    extends Composer<_$AlchemonsDatabase, $ConstellationPointsTable> {
  $$ConstellationPointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentBalance => $composableBuilder(
    column: $table.currentBalance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalEarned => $composableBuilder(
    column: $table.totalEarned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalSpent => $composableBuilder(
    column: $table.totalSpent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasSeenFinale => $composableBuilder(
    column: $table.hasSeenFinale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUpdatedUtc => $composableBuilder(
    column: $table.lastUpdatedUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConstellationPointsTableAnnotationComposer
    extends Composer<_$AlchemonsDatabase, $ConstellationPointsTable> {
  $$ConstellationPointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get currentBalance => $composableBuilder(
    column: $table.currentBalance,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalEarned => $composableBuilder(
    column: $table.totalEarned,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalSpent => $composableBuilder(
    column: $table.totalSpent,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasSeenFinale => $composableBuilder(
    column: $table.hasSeenFinale,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastUpdatedUtc => $composableBuilder(
    column: $table.lastUpdatedUtc,
    builder: (column) => column,
  );
}

class $$ConstellationPointsTableTableManager
    extends
        RootTableManager<
          _$AlchemonsDatabase,
          $ConstellationPointsTable,
          ConstellationPoint,
          $$ConstellationPointsTableFilterComposer,
          $$ConstellationPointsTableOrderingComposer,
          $$ConstellationPointsTableAnnotationComposer,
          $$ConstellationPointsTableCreateCompanionBuilder,
          $$ConstellationPointsTableUpdateCompanionBuilder,
          (
            ConstellationPoint,
            BaseReferences<
              _$AlchemonsDatabase,
              $ConstellationPointsTable,
              ConstellationPoint
            >,
          ),
          ConstellationPoint,
          PrefetchHooks Function()
        > {
  $$ConstellationPointsTableTableManager(
    _$AlchemonsDatabase db,
    $ConstellationPointsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConstellationPointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConstellationPointsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ConstellationPointsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> currentBalance = const Value.absent(),
                Value<int> totalEarned = const Value.absent(),
                Value<int> totalSpent = const Value.absent(),
                Value<bool> hasSeenFinale = const Value.absent(),
                Value<DateTime> lastUpdatedUtc = const Value.absent(),
              }) => ConstellationPointsCompanion(
                id: id,
                currentBalance: currentBalance,
                totalEarned: totalEarned,
                totalSpent: totalSpent,
                hasSeenFinale: hasSeenFinale,
                lastUpdatedUtc: lastUpdatedUtc,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> currentBalance = const Value.absent(),
                Value<int> totalEarned = const Value.absent(),
                Value<int> totalSpent = const Value.absent(),
                Value<bool> hasSeenFinale = const Value.absent(),
                required DateTime lastUpdatedUtc,
              }) => ConstellationPointsCompanion.insert(
                id: id,
                currentBalance: currentBalance,
                totalEarned: totalEarned,
                totalSpent: totalSpent,
                hasSeenFinale: hasSeenFinale,
                lastUpdatedUtc: lastUpdatedUtc,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConstellationPointsTableProcessedTableManager =
    ProcessedTableManager<
      _$AlchemonsDatabase,
      $ConstellationPointsTable,
      ConstellationPoint,
      $$ConstellationPointsTableFilterComposer,
      $$ConstellationPointsTableOrderingComposer,
      $$ConstellationPointsTableAnnotationComposer,
      $$ConstellationPointsTableCreateCompanionBuilder,
      $$ConstellationPointsTableUpdateCompanionBuilder,
      (
        ConstellationPoint,
        BaseReferences<
          _$AlchemonsDatabase,
          $ConstellationPointsTable,
          ConstellationPoint
        >,
      ),
      ConstellationPoint,
      PrefetchHooks Function()
    >;
typedef $$ConstellationTransactionsTableCreateCompanionBuilder =
    ConstellationTransactionsCompanion Function({
      Value<int> id,
      required String transactionType,
      required int amount,
      Value<String?> sourceId,
      required String description,
      required DateTime createdAtUtc,
    });
typedef $$ConstellationTransactionsTableUpdateCompanionBuilder =
    ConstellationTransactionsCompanion Function({
      Value<int> id,
      Value<String> transactionType,
      Value<int> amount,
      Value<String?> sourceId,
      Value<String> description,
      Value<DateTime> createdAtUtc,
    });

class $$ConstellationTransactionsTableFilterComposer
    extends Composer<_$AlchemonsDatabase, $ConstellationTransactionsTable> {
  $$ConstellationTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transactionType => $composableBuilder(
    column: $table.transactionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConstellationTransactionsTableOrderingComposer
    extends Composer<_$AlchemonsDatabase, $ConstellationTransactionsTable> {
  $$ConstellationTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transactionType => $composableBuilder(
    column: $table.transactionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConstellationTransactionsTableAnnotationComposer
    extends Composer<_$AlchemonsDatabase, $ConstellationTransactionsTable> {
  $$ConstellationTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get transactionType => $composableBuilder(
    column: $table.transactionType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );
}

class $$ConstellationTransactionsTableTableManager
    extends
        RootTableManager<
          _$AlchemonsDatabase,
          $ConstellationTransactionsTable,
          ConstellationTransaction,
          $$ConstellationTransactionsTableFilterComposer,
          $$ConstellationTransactionsTableOrderingComposer,
          $$ConstellationTransactionsTableAnnotationComposer,
          $$ConstellationTransactionsTableCreateCompanionBuilder,
          $$ConstellationTransactionsTableUpdateCompanionBuilder,
          (
            ConstellationTransaction,
            BaseReferences<
              _$AlchemonsDatabase,
              $ConstellationTransactionsTable,
              ConstellationTransaction
            >,
          ),
          ConstellationTransaction,
          PrefetchHooks Function()
        > {
  $$ConstellationTransactionsTableTableManager(
    _$AlchemonsDatabase db,
    $ConstellationTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConstellationTransactionsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ConstellationTransactionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ConstellationTransactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> transactionType = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<DateTime> createdAtUtc = const Value.absent(),
              }) => ConstellationTransactionsCompanion(
                id: id,
                transactionType: transactionType,
                amount: amount,
                sourceId: sourceId,
                description: description,
                createdAtUtc: createdAtUtc,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String transactionType,
                required int amount,
                Value<String?> sourceId = const Value.absent(),
                required String description,
                required DateTime createdAtUtc,
              }) => ConstellationTransactionsCompanion.insert(
                id: id,
                transactionType: transactionType,
                amount: amount,
                sourceId: sourceId,
                description: description,
                createdAtUtc: createdAtUtc,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConstellationTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AlchemonsDatabase,
      $ConstellationTransactionsTable,
      ConstellationTransaction,
      $$ConstellationTransactionsTableFilterComposer,
      $$ConstellationTransactionsTableOrderingComposer,
      $$ConstellationTransactionsTableAnnotationComposer,
      $$ConstellationTransactionsTableCreateCompanionBuilder,
      $$ConstellationTransactionsTableUpdateCompanionBuilder,
      (
        ConstellationTransaction,
        BaseReferences<
          _$AlchemonsDatabase,
          $ConstellationTransactionsTable,
          ConstellationTransaction
        >,
      ),
      ConstellationTransaction,
      PrefetchHooks Function()
    >;
typedef $$ConstellationUnlocksTableCreateCompanionBuilder =
    ConstellationUnlocksCompanion Function({
      required String skillId,
      required DateTime unlockedAtUtc,
      required int pointsCost,
      Value<int> rowid,
    });
typedef $$ConstellationUnlocksTableUpdateCompanionBuilder =
    ConstellationUnlocksCompanion Function({
      Value<String> skillId,
      Value<DateTime> unlockedAtUtc,
      Value<int> pointsCost,
      Value<int> rowid,
    });

class $$ConstellationUnlocksTableFilterComposer
    extends Composer<_$AlchemonsDatabase, $ConstellationUnlocksTable> {
  $$ConstellationUnlocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get skillId => $composableBuilder(
    column: $table.skillId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get unlockedAtUtc => $composableBuilder(
    column: $table.unlockedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pointsCost => $composableBuilder(
    column: $table.pointsCost,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConstellationUnlocksTableOrderingComposer
    extends Composer<_$AlchemonsDatabase, $ConstellationUnlocksTable> {
  $$ConstellationUnlocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get skillId => $composableBuilder(
    column: $table.skillId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get unlockedAtUtc => $composableBuilder(
    column: $table.unlockedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pointsCost => $composableBuilder(
    column: $table.pointsCost,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConstellationUnlocksTableAnnotationComposer
    extends Composer<_$AlchemonsDatabase, $ConstellationUnlocksTable> {
  $$ConstellationUnlocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get skillId =>
      $composableBuilder(column: $table.skillId, builder: (column) => column);

  GeneratedColumn<DateTime> get unlockedAtUtc => $composableBuilder(
    column: $table.unlockedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pointsCost => $composableBuilder(
    column: $table.pointsCost,
    builder: (column) => column,
  );
}

class $$ConstellationUnlocksTableTableManager
    extends
        RootTableManager<
          _$AlchemonsDatabase,
          $ConstellationUnlocksTable,
          ConstellationUnlock,
          $$ConstellationUnlocksTableFilterComposer,
          $$ConstellationUnlocksTableOrderingComposer,
          $$ConstellationUnlocksTableAnnotationComposer,
          $$ConstellationUnlocksTableCreateCompanionBuilder,
          $$ConstellationUnlocksTableUpdateCompanionBuilder,
          (
            ConstellationUnlock,
            BaseReferences<
              _$AlchemonsDatabase,
              $ConstellationUnlocksTable,
              ConstellationUnlock
            >,
          ),
          ConstellationUnlock,
          PrefetchHooks Function()
        > {
  $$ConstellationUnlocksTableTableManager(
    _$AlchemonsDatabase db,
    $ConstellationUnlocksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConstellationUnlocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConstellationUnlocksTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ConstellationUnlocksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> skillId = const Value.absent(),
                Value<DateTime> unlockedAtUtc = const Value.absent(),
                Value<int> pointsCost = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConstellationUnlocksCompanion(
                skillId: skillId,
                unlockedAtUtc: unlockedAtUtc,
                pointsCost: pointsCost,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String skillId,
                required DateTime unlockedAtUtc,
                required int pointsCost,
                Value<int> rowid = const Value.absent(),
              }) => ConstellationUnlocksCompanion.insert(
                skillId: skillId,
                unlockedAtUtc: unlockedAtUtc,
                pointsCost: pointsCost,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConstellationUnlocksTableProcessedTableManager =
    ProcessedTableManager<
      _$AlchemonsDatabase,
      $ConstellationUnlocksTable,
      ConstellationUnlock,
      $$ConstellationUnlocksTableFilterComposer,
      $$ConstellationUnlocksTableOrderingComposer,
      $$ConstellationUnlocksTableAnnotationComposer,
      $$ConstellationUnlocksTableCreateCompanionBuilder,
      $$ConstellationUnlocksTableUpdateCompanionBuilder,
      (
        ConstellationUnlock,
        BaseReferences<
          _$AlchemonsDatabase,
          $ConstellationUnlocksTable,
          ConstellationUnlock
        >,
      ),
      ConstellationUnlock,
      PrefetchHooks Function()
    >;
typedef $$BreedingStatisticsTableCreateCompanionBuilder =
    BreedingStatisticsCompanion Function({
      required String speciesId,
      Value<int> totalBred,
      Value<int> lastMilestoneAwarded,
      Value<DateTime?> lastBredAtUtc,
      Value<int> rowid,
    });
typedef $$BreedingStatisticsTableUpdateCompanionBuilder =
    BreedingStatisticsCompanion Function({
      Value<String> speciesId,
      Value<int> totalBred,
      Value<int> lastMilestoneAwarded,
      Value<DateTime?> lastBredAtUtc,
      Value<int> rowid,
    });

class $$BreedingStatisticsTableFilterComposer
    extends Composer<_$AlchemonsDatabase, $BreedingStatisticsTable> {
  $$BreedingStatisticsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get speciesId => $composableBuilder(
    column: $table.speciesId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalBred => $composableBuilder(
    column: $table.totalBred,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastMilestoneAwarded => $composableBuilder(
    column: $table.lastMilestoneAwarded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastBredAtUtc => $composableBuilder(
    column: $table.lastBredAtUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BreedingStatisticsTableOrderingComposer
    extends Composer<_$AlchemonsDatabase, $BreedingStatisticsTable> {
  $$BreedingStatisticsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get speciesId => $composableBuilder(
    column: $table.speciesId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalBred => $composableBuilder(
    column: $table.totalBred,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastMilestoneAwarded => $composableBuilder(
    column: $table.lastMilestoneAwarded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastBredAtUtc => $composableBuilder(
    column: $table.lastBredAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BreedingStatisticsTableAnnotationComposer
    extends Composer<_$AlchemonsDatabase, $BreedingStatisticsTable> {
  $$BreedingStatisticsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get speciesId =>
      $composableBuilder(column: $table.speciesId, builder: (column) => column);

  GeneratedColumn<int> get totalBred =>
      $composableBuilder(column: $table.totalBred, builder: (column) => column);

  GeneratedColumn<int> get lastMilestoneAwarded => $composableBuilder(
    column: $table.lastMilestoneAwarded,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastBredAtUtc => $composableBuilder(
    column: $table.lastBredAtUtc,
    builder: (column) => column,
  );
}

class $$BreedingStatisticsTableTableManager
    extends
        RootTableManager<
          _$AlchemonsDatabase,
          $BreedingStatisticsTable,
          BreedingStatistic,
          $$BreedingStatisticsTableFilterComposer,
          $$BreedingStatisticsTableOrderingComposer,
          $$BreedingStatisticsTableAnnotationComposer,
          $$BreedingStatisticsTableCreateCompanionBuilder,
          $$BreedingStatisticsTableUpdateCompanionBuilder,
          (
            BreedingStatistic,
            BaseReferences<
              _$AlchemonsDatabase,
              $BreedingStatisticsTable,
              BreedingStatistic
            >,
          ),
          BreedingStatistic,
          PrefetchHooks Function()
        > {
  $$BreedingStatisticsTableTableManager(
    _$AlchemonsDatabase db,
    $BreedingStatisticsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BreedingStatisticsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BreedingStatisticsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BreedingStatisticsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> speciesId = const Value.absent(),
                Value<int> totalBred = const Value.absent(),
                Value<int> lastMilestoneAwarded = const Value.absent(),
                Value<DateTime?> lastBredAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BreedingStatisticsCompanion(
                speciesId: speciesId,
                totalBred: totalBred,
                lastMilestoneAwarded: lastMilestoneAwarded,
                lastBredAtUtc: lastBredAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String speciesId,
                Value<int> totalBred = const Value.absent(),
                Value<int> lastMilestoneAwarded = const Value.absent(),
                Value<DateTime?> lastBredAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BreedingStatisticsCompanion.insert(
                speciesId: speciesId,
                totalBred: totalBred,
                lastMilestoneAwarded: lastMilestoneAwarded,
                lastBredAtUtc: lastBredAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BreedingStatisticsTableProcessedTableManager =
    ProcessedTableManager<
      _$AlchemonsDatabase,
      $BreedingStatisticsTable,
      BreedingStatistic,
      $$BreedingStatisticsTableFilterComposer,
      $$BreedingStatisticsTableOrderingComposer,
      $$BreedingStatisticsTableAnnotationComposer,
      $$BreedingStatisticsTableCreateCompanionBuilder,
      $$BreedingStatisticsTableUpdateCompanionBuilder,
      (
        BreedingStatistic,
        BaseReferences<
          _$AlchemonsDatabase,
          $BreedingStatisticsTable,
          BreedingStatistic
        >,
      ),
      BreedingStatistic,
      PrefetchHooks Function()
    >;

class $AlchemonsDatabaseManager {
  final _$AlchemonsDatabase _db;
  $AlchemonsDatabaseManager(this._db);
  $$PlayerCreaturesTableTableManager get playerCreatures =>
      $$PlayerCreaturesTableTableManager(_db, _db.playerCreatures);
  $$IncubatorSlotsTableTableManager get incubatorSlots =>
      $$IncubatorSlotsTableTableManager(_db, _db.incubatorSlots);
  $$EggsTableTableManager get eggs => $$EggsTableTableManager(_db, _db.eggs);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$CreatureInstancesTableTableManager get creatureInstances =>
      $$CreatureInstancesTableTableManager(_db, _db.creatureInstances);
  $$FeedEventsTableTableManager get feedEvents =>
      $$FeedEventsTableTableManager(_db, _db.feedEvents);
  $$BiomeFarmsTableTableManager get biomeFarms =>
      $$BiomeFarmsTableTableManager(_db, _db.biomeFarms);
  $$BiomeJobsTableTableManager get biomeJobs =>
      $$BiomeJobsTableTableManager(_db, _db.biomeJobs);
  $$CompetitionProgressTableTableManager get competitionProgress =>
      $$CompetitionProgressTableTableManager(_db, _db.competitionProgress);
  $$ShopPurchasesTableTableManager get shopPurchases =>
      $$ShopPurchasesTableTableManager(_db, _db.shopPurchases);
  $$InventoryItemsTableTableManager get inventoryItems =>
      $$InventoryItemsTableTableManager(_db, _db.inventoryItems);
  $$ActiveSpawnsTableTableManager get activeSpawns =>
      $$ActiveSpawnsTableTableManager(_db, _db.activeSpawns);
  $$ActiveSceneEntryTableTableManager get activeSceneEntry =>
      $$ActiveSceneEntryTableTableManager(_db, _db.activeSceneEntry);
  $$SpawnScheduleTableTableManager get spawnSchedule =>
      $$SpawnScheduleTableTableManager(_db, _db.spawnSchedule);
  $$NotificationDismissalsTableTableManager get notificationDismissals =>
      $$NotificationDismissalsTableTableManager(
        _db,
        _db.notificationDismissals,
      );
  $$ConstellationPointsTableTableManager get constellationPoints =>
      $$ConstellationPointsTableTableManager(_db, _db.constellationPoints);
  $$ConstellationTransactionsTableTableManager get constellationTransactions =>
      $$ConstellationTransactionsTableTableManager(
        _db,
        _db.constellationTransactions,
      );
  $$ConstellationUnlocksTableTableManager get constellationUnlocks =>
      $$ConstellationUnlocksTableTableManager(_db, _db.constellationUnlocks);
  $$BreedingStatisticsTableTableManager get breedingStatistics =>
      $$BreedingStatisticsTableTableManager(_db, _db.breedingStatistics);
}
