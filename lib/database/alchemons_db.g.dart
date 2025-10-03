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
    parentageJson,
    geneticsJson,
    likelihoodAnalysisJson,
    staminaMax,
    staminaBars,
    staminaLastUtcMs,
    createdAtUtcMs,
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
  final String? parentageJson;
  final String? geneticsJson;
  final String? likelihoodAnalysisJson;
  final int staminaMax;
  final int staminaBars;
  final int staminaLastUtcMs;
  final int createdAtUtcMs;
  const CreatureInstance({
    required this.instanceId,
    required this.baseId,
    required this.level,
    required this.xp,
    required this.locked,
    this.nickname,
    required this.isPrismaticSkin,
    this.natureId,
    this.parentageJson,
    this.geneticsJson,
    this.likelihoodAnalysisJson,
    required this.staminaMax,
    required this.staminaBars,
    required this.staminaLastUtcMs,
    required this.createdAtUtcMs,
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
      parentageJson: serializer.fromJson<String?>(json['parentageJson']),
      geneticsJson: serializer.fromJson<String?>(json['geneticsJson']),
      likelihoodAnalysisJson: serializer.fromJson<String?>(
        json['likelihoodAnalysisJson'],
      ),
      staminaMax: serializer.fromJson<int>(json['staminaMax']),
      staminaBars: serializer.fromJson<int>(json['staminaBars']),
      staminaLastUtcMs: serializer.fromJson<int>(json['staminaLastUtcMs']),
      createdAtUtcMs: serializer.fromJson<int>(json['createdAtUtcMs']),
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
      'parentageJson': serializer.toJson<String?>(parentageJson),
      'geneticsJson': serializer.toJson<String?>(geneticsJson),
      'likelihoodAnalysisJson': serializer.toJson<String?>(
        likelihoodAnalysisJson,
      ),
      'staminaMax': serializer.toJson<int>(staminaMax),
      'staminaBars': serializer.toJson<int>(staminaBars),
      'staminaLastUtcMs': serializer.toJson<int>(staminaLastUtcMs),
      'createdAtUtcMs': serializer.toJson<int>(createdAtUtcMs),
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
    Value<String?> parentageJson = const Value.absent(),
    Value<String?> geneticsJson = const Value.absent(),
    Value<String?> likelihoodAnalysisJson = const Value.absent(),
    int? staminaMax,
    int? staminaBars,
    int? staminaLastUtcMs,
    int? createdAtUtcMs,
  }) => CreatureInstance(
    instanceId: instanceId ?? this.instanceId,
    baseId: baseId ?? this.baseId,
    level: level ?? this.level,
    xp: xp ?? this.xp,
    locked: locked ?? this.locked,
    nickname: nickname.present ? nickname.value : this.nickname,
    isPrismaticSkin: isPrismaticSkin ?? this.isPrismaticSkin,
    natureId: natureId.present ? natureId.value : this.natureId,
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
          ..write('parentageJson: $parentageJson, ')
          ..write('geneticsJson: $geneticsJson, ')
          ..write('likelihoodAnalysisJson: $likelihoodAnalysisJson, ')
          ..write('staminaMax: $staminaMax, ')
          ..write('staminaBars: $staminaBars, ')
          ..write('staminaLastUtcMs: $staminaLastUtcMs, ')
          ..write('createdAtUtcMs: $createdAtUtcMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    instanceId,
    baseId,
    level,
    xp,
    locked,
    nickname,
    isPrismaticSkin,
    natureId,
    parentageJson,
    geneticsJson,
    likelihoodAnalysisJson,
    staminaMax,
    staminaBars,
    staminaLastUtcMs,
    createdAtUtcMs,
  );
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
          other.parentageJson == this.parentageJson &&
          other.geneticsJson == this.geneticsJson &&
          other.likelihoodAnalysisJson == this.likelihoodAnalysisJson &&
          other.staminaMax == this.staminaMax &&
          other.staminaBars == this.staminaBars &&
          other.staminaLastUtcMs == this.staminaLastUtcMs &&
          other.createdAtUtcMs == this.createdAtUtcMs);
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
  final Value<String?> parentageJson;
  final Value<String?> geneticsJson;
  final Value<String?> likelihoodAnalysisJson;
  final Value<int> staminaMax;
  final Value<int> staminaBars;
  final Value<int> staminaLastUtcMs;
  final Value<int> createdAtUtcMs;
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
    this.parentageJson = const Value.absent(),
    this.geneticsJson = const Value.absent(),
    this.likelihoodAnalysisJson = const Value.absent(),
    this.staminaMax = const Value.absent(),
    this.staminaBars = const Value.absent(),
    this.staminaLastUtcMs = const Value.absent(),
    this.createdAtUtcMs = const Value.absent(),
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
    this.parentageJson = const Value.absent(),
    this.geneticsJson = const Value.absent(),
    this.likelihoodAnalysisJson = const Value.absent(),
    this.staminaMax = const Value.absent(),
    this.staminaBars = const Value.absent(),
    this.staminaLastUtcMs = const Value.absent(),
    this.createdAtUtcMs = const Value.absent(),
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
    Expression<String>? parentageJson,
    Expression<String>? geneticsJson,
    Expression<String>? likelihoodAnalysisJson,
    Expression<int>? staminaMax,
    Expression<int>? staminaBars,
    Expression<int>? staminaLastUtcMs,
    Expression<int>? createdAtUtcMs,
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
      if (parentageJson != null) 'parentage_json': parentageJson,
      if (geneticsJson != null) 'genetics_json': geneticsJson,
      if (likelihoodAnalysisJson != null)
        'likelihood_analysis_json': likelihoodAnalysisJson,
      if (staminaMax != null) 'stamina_max': staminaMax,
      if (staminaBars != null) 'stamina_bars': staminaBars,
      if (staminaLastUtcMs != null) 'stamina_last_utc_ms': staminaLastUtcMs,
      if (createdAtUtcMs != null) 'created_at_utc_ms': createdAtUtcMs,
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
    Value<String?>? parentageJson,
    Value<String?>? geneticsJson,
    Value<String?>? likelihoodAnalysisJson,
    Value<int>? staminaMax,
    Value<int>? staminaBars,
    Value<int>? staminaLastUtcMs,
    Value<int>? createdAtUtcMs,
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
      parentageJson: parentageJson ?? this.parentageJson,
      geneticsJson: geneticsJson ?? this.geneticsJson,
      likelihoodAnalysisJson:
          likelihoodAnalysisJson ?? this.likelihoodAnalysisJson,
      staminaMax: staminaMax ?? this.staminaMax,
      staminaBars: staminaBars ?? this.staminaBars,
      staminaLastUtcMs: staminaLastUtcMs ?? this.staminaLastUtcMs,
      createdAtUtcMs: createdAtUtcMs ?? this.createdAtUtcMs,
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
          ..write('parentageJson: $parentageJson, ')
          ..write('geneticsJson: $geneticsJson, ')
          ..write('likelihoodAnalysisJson: $likelihoodAnalysisJson, ')
          ..write('staminaMax: $staminaMax, ')
          ..write('staminaBars: $staminaBars, ')
          ..write('staminaLastUtcMs: $staminaLastUtcMs, ')
          ..write('createdAtUtcMs: $createdAtUtcMs, ')
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

class $HarvestFarmsTable extends HarvestFarms
    with TableInfo<$HarvestFarmsTable, HarvestFarm> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HarvestFarmsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _elementMeta = const VerificationMeta(
    'element',
  );
  @override
  late final GeneratedColumn<String> element = GeneratedColumn<String>(
    'element',
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
  @override
  List<GeneratedColumn> get $columns => [id, element, unlocked, level];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'harvest_farms';
  @override
  VerificationContext validateIntegrity(
    Insertable<HarvestFarm> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('element')) {
      context.handle(
        _elementMeta,
        element.isAcceptableOrUnknown(data['element']!, _elementMeta),
      );
    } else if (isInserting) {
      context.missing(_elementMeta);
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HarvestFarm map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HarvestFarm(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      element: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}element'],
      )!,
      unlocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}unlocked'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}level'],
      )!,
    );
  }

  @override
  $HarvestFarmsTable createAlias(String alias) {
    return $HarvestFarmsTable(attachedDatabase, alias);
  }
}

class HarvestFarm extends DataClass implements Insertable<HarvestFarm> {
  final int id;
  final String element;
  final bool unlocked;
  final int level;
  const HarvestFarm({
    required this.id,
    required this.element,
    required this.unlocked,
    required this.level,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['element'] = Variable<String>(element);
    map['unlocked'] = Variable<bool>(unlocked);
    map['level'] = Variable<int>(level);
    return map;
  }

  HarvestFarmsCompanion toCompanion(bool nullToAbsent) {
    return HarvestFarmsCompanion(
      id: Value(id),
      element: Value(element),
      unlocked: Value(unlocked),
      level: Value(level),
    );
  }

  factory HarvestFarm.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HarvestFarm(
      id: serializer.fromJson<int>(json['id']),
      element: serializer.fromJson<String>(json['element']),
      unlocked: serializer.fromJson<bool>(json['unlocked']),
      level: serializer.fromJson<int>(json['level']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'element': serializer.toJson<String>(element),
      'unlocked': serializer.toJson<bool>(unlocked),
      'level': serializer.toJson<int>(level),
    };
  }

  HarvestFarm copyWith({
    int? id,
    String? element,
    bool? unlocked,
    int? level,
  }) => HarvestFarm(
    id: id ?? this.id,
    element: element ?? this.element,
    unlocked: unlocked ?? this.unlocked,
    level: level ?? this.level,
  );
  HarvestFarm copyWithCompanion(HarvestFarmsCompanion data) {
    return HarvestFarm(
      id: data.id.present ? data.id.value : this.id,
      element: data.element.present ? data.element.value : this.element,
      unlocked: data.unlocked.present ? data.unlocked.value : this.unlocked,
      level: data.level.present ? data.level.value : this.level,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HarvestFarm(')
          ..write('id: $id, ')
          ..write('element: $element, ')
          ..write('unlocked: $unlocked, ')
          ..write('level: $level')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, element, unlocked, level);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HarvestFarm &&
          other.id == this.id &&
          other.element == this.element &&
          other.unlocked == this.unlocked &&
          other.level == this.level);
}

class HarvestFarmsCompanion extends UpdateCompanion<HarvestFarm> {
  final Value<int> id;
  final Value<String> element;
  final Value<bool> unlocked;
  final Value<int> level;
  const HarvestFarmsCompanion({
    this.id = const Value.absent(),
    this.element = const Value.absent(),
    this.unlocked = const Value.absent(),
    this.level = const Value.absent(),
  });
  HarvestFarmsCompanion.insert({
    this.id = const Value.absent(),
    required String element,
    this.unlocked = const Value.absent(),
    this.level = const Value.absent(),
  }) : element = Value(element);
  static Insertable<HarvestFarm> custom({
    Expression<int>? id,
    Expression<String>? element,
    Expression<bool>? unlocked,
    Expression<int>? level,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (element != null) 'element': element,
      if (unlocked != null) 'unlocked': unlocked,
      if (level != null) 'level': level,
    });
  }

  HarvestFarmsCompanion copyWith({
    Value<int>? id,
    Value<String>? element,
    Value<bool>? unlocked,
    Value<int>? level,
  }) {
    return HarvestFarmsCompanion(
      id: id ?? this.id,
      element: element ?? this.element,
      unlocked: unlocked ?? this.unlocked,
      level: level ?? this.level,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (element.present) {
      map['element'] = Variable<String>(element.value);
    }
    if (unlocked.present) {
      map['unlocked'] = Variable<bool>(unlocked.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HarvestFarmsCompanion(')
          ..write('id: $id, ')
          ..write('element: $element, ')
          ..write('unlocked: $unlocked, ')
          ..write('level: $level')
          ..write(')'))
        .toString();
  }
}

class $HarvestJobsTable extends HarvestJobs
    with TableInfo<$HarvestJobsTable, HarvestJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HarvestJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _jobIdMeta = const VerificationMeta('jobId');
  @override
  late final GeneratedColumn<String> jobId = GeneratedColumn<String>(
    'job_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _farmIdMeta = const VerificationMeta('farmId');
  @override
  late final GeneratedColumn<int> farmId = GeneratedColumn<int>(
    'farm_id',
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
    farmId,
    creatureInstanceId,
    startUtcMs,
    durationMs,
    ratePerMinute,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'harvest_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<HarvestJob> instance, {
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
    if (data.containsKey('farm_id')) {
      context.handle(
        _farmIdMeta,
        farmId.isAcceptableOrUnknown(data['farm_id']!, _farmIdMeta),
      );
    } else if (isInserting) {
      context.missing(_farmIdMeta);
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
  HarvestJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HarvestJob(
      jobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}job_id'],
      )!,
      farmId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}farm_id'],
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
  $HarvestJobsTable createAlias(String alias) {
    return $HarvestJobsTable(attachedDatabase, alias);
  }
}

class HarvestJob extends DataClass implements Insertable<HarvestJob> {
  final String jobId;
  final int farmId;
  final String creatureInstanceId;
  final int startUtcMs;
  final int durationMs;
  final int ratePerMinute;
  const HarvestJob({
    required this.jobId,
    required this.farmId,
    required this.creatureInstanceId,
    required this.startUtcMs,
    required this.durationMs,
    required this.ratePerMinute,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['job_id'] = Variable<String>(jobId);
    map['farm_id'] = Variable<int>(farmId);
    map['creature_instance_id'] = Variable<String>(creatureInstanceId);
    map['start_utc_ms'] = Variable<int>(startUtcMs);
    map['duration_ms'] = Variable<int>(durationMs);
    map['rate_per_minute'] = Variable<int>(ratePerMinute);
    return map;
  }

  HarvestJobsCompanion toCompanion(bool nullToAbsent) {
    return HarvestJobsCompanion(
      jobId: Value(jobId),
      farmId: Value(farmId),
      creatureInstanceId: Value(creatureInstanceId),
      startUtcMs: Value(startUtcMs),
      durationMs: Value(durationMs),
      ratePerMinute: Value(ratePerMinute),
    );
  }

  factory HarvestJob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HarvestJob(
      jobId: serializer.fromJson<String>(json['jobId']),
      farmId: serializer.fromJson<int>(json['farmId']),
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
      'farmId': serializer.toJson<int>(farmId),
      'creatureInstanceId': serializer.toJson<String>(creatureInstanceId),
      'startUtcMs': serializer.toJson<int>(startUtcMs),
      'durationMs': serializer.toJson<int>(durationMs),
      'ratePerMinute': serializer.toJson<int>(ratePerMinute),
    };
  }

  HarvestJob copyWith({
    String? jobId,
    int? farmId,
    String? creatureInstanceId,
    int? startUtcMs,
    int? durationMs,
    int? ratePerMinute,
  }) => HarvestJob(
    jobId: jobId ?? this.jobId,
    farmId: farmId ?? this.farmId,
    creatureInstanceId: creatureInstanceId ?? this.creatureInstanceId,
    startUtcMs: startUtcMs ?? this.startUtcMs,
    durationMs: durationMs ?? this.durationMs,
    ratePerMinute: ratePerMinute ?? this.ratePerMinute,
  );
  HarvestJob copyWithCompanion(HarvestJobsCompanion data) {
    return HarvestJob(
      jobId: data.jobId.present ? data.jobId.value : this.jobId,
      farmId: data.farmId.present ? data.farmId.value : this.farmId,
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
    return (StringBuffer('HarvestJob(')
          ..write('jobId: $jobId, ')
          ..write('farmId: $farmId, ')
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
    farmId,
    creatureInstanceId,
    startUtcMs,
    durationMs,
    ratePerMinute,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HarvestJob &&
          other.jobId == this.jobId &&
          other.farmId == this.farmId &&
          other.creatureInstanceId == this.creatureInstanceId &&
          other.startUtcMs == this.startUtcMs &&
          other.durationMs == this.durationMs &&
          other.ratePerMinute == this.ratePerMinute);
}

class HarvestJobsCompanion extends UpdateCompanion<HarvestJob> {
  final Value<String> jobId;
  final Value<int> farmId;
  final Value<String> creatureInstanceId;
  final Value<int> startUtcMs;
  final Value<int> durationMs;
  final Value<int> ratePerMinute;
  final Value<int> rowid;
  const HarvestJobsCompanion({
    this.jobId = const Value.absent(),
    this.farmId = const Value.absent(),
    this.creatureInstanceId = const Value.absent(),
    this.startUtcMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.ratePerMinute = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HarvestJobsCompanion.insert({
    required String jobId,
    required int farmId,
    required String creatureInstanceId,
    required int startUtcMs,
    required int durationMs,
    required int ratePerMinute,
    this.rowid = const Value.absent(),
  }) : jobId = Value(jobId),
       farmId = Value(farmId),
       creatureInstanceId = Value(creatureInstanceId),
       startUtcMs = Value(startUtcMs),
       durationMs = Value(durationMs),
       ratePerMinute = Value(ratePerMinute);
  static Insertable<HarvestJob> custom({
    Expression<String>? jobId,
    Expression<int>? farmId,
    Expression<String>? creatureInstanceId,
    Expression<int>? startUtcMs,
    Expression<int>? durationMs,
    Expression<int>? ratePerMinute,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (jobId != null) 'job_id': jobId,
      if (farmId != null) 'farm_id': farmId,
      if (creatureInstanceId != null)
        'creature_instance_id': creatureInstanceId,
      if (startUtcMs != null) 'start_utc_ms': startUtcMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (ratePerMinute != null) 'rate_per_minute': ratePerMinute,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HarvestJobsCompanion copyWith({
    Value<String>? jobId,
    Value<int>? farmId,
    Value<String>? creatureInstanceId,
    Value<int>? startUtcMs,
    Value<int>? durationMs,
    Value<int>? ratePerMinute,
    Value<int>? rowid,
  }) {
    return HarvestJobsCompanion(
      jobId: jobId ?? this.jobId,
      farmId: farmId ?? this.farmId,
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
    if (farmId.present) {
      map['farm_id'] = Variable<int>(farmId.value);
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
    return (StringBuffer('HarvestJobsCompanion(')
          ..write('jobId: $jobId, ')
          ..write('farmId: $farmId, ')
          ..write('creatureInstanceId: $creatureInstanceId, ')
          ..write('startUtcMs: $startUtcMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('ratePerMinute: $ratePerMinute, ')
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
  late final $HarvestFarmsTable harvestFarms = $HarvestFarmsTable(this);
  late final $HarvestJobsTable harvestJobs = $HarvestJobsTable(this);
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
    harvestFarms,
    harvestJobs,
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
      Value<String?> parentageJson,
      Value<String?> geneticsJson,
      Value<String?> likelihoodAnalysisJson,
      Value<int> staminaMax,
      Value<int> staminaBars,
      Value<int> staminaLastUtcMs,
      Value<int> createdAtUtcMs,
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
      Value<String?> parentageJson,
      Value<String?> geneticsJson,
      Value<String?> likelihoodAnalysisJson,
      Value<int> staminaMax,
      Value<int> staminaBars,
      Value<int> staminaLastUtcMs,
      Value<int> createdAtUtcMs,
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
                Value<String?> parentageJson = const Value.absent(),
                Value<String?> geneticsJson = const Value.absent(),
                Value<String?> likelihoodAnalysisJson = const Value.absent(),
                Value<int> staminaMax = const Value.absent(),
                Value<int> staminaBars = const Value.absent(),
                Value<int> staminaLastUtcMs = const Value.absent(),
                Value<int> createdAtUtcMs = const Value.absent(),
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
                parentageJson: parentageJson,
                geneticsJson: geneticsJson,
                likelihoodAnalysisJson: likelihoodAnalysisJson,
                staminaMax: staminaMax,
                staminaBars: staminaBars,
                staminaLastUtcMs: staminaLastUtcMs,
                createdAtUtcMs: createdAtUtcMs,
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
                Value<String?> parentageJson = const Value.absent(),
                Value<String?> geneticsJson = const Value.absent(),
                Value<String?> likelihoodAnalysisJson = const Value.absent(),
                Value<int> staminaMax = const Value.absent(),
                Value<int> staminaBars = const Value.absent(),
                Value<int> staminaLastUtcMs = const Value.absent(),
                Value<int> createdAtUtcMs = const Value.absent(),
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
                parentageJson: parentageJson,
                geneticsJson: geneticsJson,
                likelihoodAnalysisJson: likelihoodAnalysisJson,
                staminaMax: staminaMax,
                staminaBars: staminaBars,
                staminaLastUtcMs: staminaLastUtcMs,
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
typedef $$HarvestFarmsTableCreateCompanionBuilder =
    HarvestFarmsCompanion Function({
      Value<int> id,
      required String element,
      Value<bool> unlocked,
      Value<int> level,
    });
typedef $$HarvestFarmsTableUpdateCompanionBuilder =
    HarvestFarmsCompanion Function({
      Value<int> id,
      Value<String> element,
      Value<bool> unlocked,
      Value<int> level,
    });

class $$HarvestFarmsTableFilterComposer
    extends Composer<_$AlchemonsDatabase, $HarvestFarmsTable> {
  $$HarvestFarmsTableFilterComposer({
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

  ColumnFilters<String> get element => $composableBuilder(
    column: $table.element,
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
}

class $$HarvestFarmsTableOrderingComposer
    extends Composer<_$AlchemonsDatabase, $HarvestFarmsTable> {
  $$HarvestFarmsTableOrderingComposer({
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

  ColumnOrderings<String> get element => $composableBuilder(
    column: $table.element,
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
}

class $$HarvestFarmsTableAnnotationComposer
    extends Composer<_$AlchemonsDatabase, $HarvestFarmsTable> {
  $$HarvestFarmsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get element =>
      $composableBuilder(column: $table.element, builder: (column) => column);

  GeneratedColumn<bool> get unlocked =>
      $composableBuilder(column: $table.unlocked, builder: (column) => column);

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);
}

class $$HarvestFarmsTableTableManager
    extends
        RootTableManager<
          _$AlchemonsDatabase,
          $HarvestFarmsTable,
          HarvestFarm,
          $$HarvestFarmsTableFilterComposer,
          $$HarvestFarmsTableOrderingComposer,
          $$HarvestFarmsTableAnnotationComposer,
          $$HarvestFarmsTableCreateCompanionBuilder,
          $$HarvestFarmsTableUpdateCompanionBuilder,
          (
            HarvestFarm,
            BaseReferences<
              _$AlchemonsDatabase,
              $HarvestFarmsTable,
              HarvestFarm
            >,
          ),
          HarvestFarm,
          PrefetchHooks Function()
        > {
  $$HarvestFarmsTableTableManager(
    _$AlchemonsDatabase db,
    $HarvestFarmsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HarvestFarmsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HarvestFarmsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HarvestFarmsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> element = const Value.absent(),
                Value<bool> unlocked = const Value.absent(),
                Value<int> level = const Value.absent(),
              }) => HarvestFarmsCompanion(
                id: id,
                element: element,
                unlocked: unlocked,
                level: level,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String element,
                Value<bool> unlocked = const Value.absent(),
                Value<int> level = const Value.absent(),
              }) => HarvestFarmsCompanion.insert(
                id: id,
                element: element,
                unlocked: unlocked,
                level: level,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HarvestFarmsTableProcessedTableManager =
    ProcessedTableManager<
      _$AlchemonsDatabase,
      $HarvestFarmsTable,
      HarvestFarm,
      $$HarvestFarmsTableFilterComposer,
      $$HarvestFarmsTableOrderingComposer,
      $$HarvestFarmsTableAnnotationComposer,
      $$HarvestFarmsTableCreateCompanionBuilder,
      $$HarvestFarmsTableUpdateCompanionBuilder,
      (
        HarvestFarm,
        BaseReferences<_$AlchemonsDatabase, $HarvestFarmsTable, HarvestFarm>,
      ),
      HarvestFarm,
      PrefetchHooks Function()
    >;
typedef $$HarvestJobsTableCreateCompanionBuilder =
    HarvestJobsCompanion Function({
      required String jobId,
      required int farmId,
      required String creatureInstanceId,
      required int startUtcMs,
      required int durationMs,
      required int ratePerMinute,
      Value<int> rowid,
    });
typedef $$HarvestJobsTableUpdateCompanionBuilder =
    HarvestJobsCompanion Function({
      Value<String> jobId,
      Value<int> farmId,
      Value<String> creatureInstanceId,
      Value<int> startUtcMs,
      Value<int> durationMs,
      Value<int> ratePerMinute,
      Value<int> rowid,
    });

class $$HarvestJobsTableFilterComposer
    extends Composer<_$AlchemonsDatabase, $HarvestJobsTable> {
  $$HarvestJobsTableFilterComposer({
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

  ColumnFilters<int> get farmId => $composableBuilder(
    column: $table.farmId,
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

class $$HarvestJobsTableOrderingComposer
    extends Composer<_$AlchemonsDatabase, $HarvestJobsTable> {
  $$HarvestJobsTableOrderingComposer({
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

  ColumnOrderings<int> get farmId => $composableBuilder(
    column: $table.farmId,
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

class $$HarvestJobsTableAnnotationComposer
    extends Composer<_$AlchemonsDatabase, $HarvestJobsTable> {
  $$HarvestJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get jobId =>
      $composableBuilder(column: $table.jobId, builder: (column) => column);

  GeneratedColumn<int> get farmId =>
      $composableBuilder(column: $table.farmId, builder: (column) => column);

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

class $$HarvestJobsTableTableManager
    extends
        RootTableManager<
          _$AlchemonsDatabase,
          $HarvestJobsTable,
          HarvestJob,
          $$HarvestJobsTableFilterComposer,
          $$HarvestJobsTableOrderingComposer,
          $$HarvestJobsTableAnnotationComposer,
          $$HarvestJobsTableCreateCompanionBuilder,
          $$HarvestJobsTableUpdateCompanionBuilder,
          (
            HarvestJob,
            BaseReferences<_$AlchemonsDatabase, $HarvestJobsTable, HarvestJob>,
          ),
          HarvestJob,
          PrefetchHooks Function()
        > {
  $$HarvestJobsTableTableManager(
    _$AlchemonsDatabase db,
    $HarvestJobsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HarvestJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HarvestJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HarvestJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> jobId = const Value.absent(),
                Value<int> farmId = const Value.absent(),
                Value<String> creatureInstanceId = const Value.absent(),
                Value<int> startUtcMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> ratePerMinute = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HarvestJobsCompanion(
                jobId: jobId,
                farmId: farmId,
                creatureInstanceId: creatureInstanceId,
                startUtcMs: startUtcMs,
                durationMs: durationMs,
                ratePerMinute: ratePerMinute,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String jobId,
                required int farmId,
                required String creatureInstanceId,
                required int startUtcMs,
                required int durationMs,
                required int ratePerMinute,
                Value<int> rowid = const Value.absent(),
              }) => HarvestJobsCompanion.insert(
                jobId: jobId,
                farmId: farmId,
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

typedef $$HarvestJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AlchemonsDatabase,
      $HarvestJobsTable,
      HarvestJob,
      $$HarvestJobsTableFilterComposer,
      $$HarvestJobsTableOrderingComposer,
      $$HarvestJobsTableAnnotationComposer,
      $$HarvestJobsTableCreateCompanionBuilder,
      $$HarvestJobsTableUpdateCompanionBuilder,
      (
        HarvestJob,
        BaseReferences<_$AlchemonsDatabase, $HarvestJobsTable, HarvestJob>,
      ),
      HarvestJob,
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
  $$HarvestFarmsTableTableManager get harvestFarms =>
      $$HarvestFarmsTableTableManager(_db, _db.harvestFarms);
  $$HarvestJobsTableTableManager get harvestJobs =>
      $$HarvestJobsTableTableManager(_db, _db.harvestJobs);
}
