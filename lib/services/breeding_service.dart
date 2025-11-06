// lib/services/breeding_service_v2.dart

import 'dart:math';

import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/egg/egg_payload.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/services/breeding_engine.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/services/wild_breed_randomizer.dart';
import 'package:alchemons/utils/nature_utils.dart';

class BreedingServiceV2 {
  final GameDataService gameData;
  final AlchemonsDatabase db;
  final BreedingEngine engine;
  final EggPayloadFactory payloadFactory;
  final WildCreatureRandomizer wildRandomizer;

  BreedingServiceV2({
    required this.gameData,
    required this.db,
    required this.engine,
    required this.payloadFactory,
    required this.wildRandomizer,
  });

  /// Regular breeding between two owned instances
  Future<EggCreationResult> breedInstances(
    CreatureInstance parent1,
    CreatureInstance parent2, {
    String? likelihoodAnalysisJson,
  }) async {
    final result = engine.breedInstances(parent1, parent2);

    if (!result.success || result.creature == null) {
      return EggCreationResult.failure('Genetic incompatibility');
    }

    final offspring = result.creature!;
    final payload = payloadFactory.fromBreedingResult(
      offspring,
      likelihoodAnalysisJson: likelihoodAnalysisJson,
    );

    return _createEgg(offspring, payload);
  }

  /// Wild breeding - breed instance with wild catalog creature
  Future<EggCreationResult> breedWithWild(
    CreatureInstance ownedParent,
    Creature wildCreature, {
    int? wildSeed,
  }) async {
    // Randomize wild creature's attributes
    final randomizedWild = wildRandomizer.randomizeWildCreature(
      wildCreature,
      seed: wildSeed,
    );

    // Breed using the extension method
    final result = engine.breedInstanceWithCreature(
      ownedParent,
      randomizedWild,
    );

    if (!result.success || result.creature == null) {
      return EggCreationResult.failure('Genetic incompatibility');
    }

    final offspring = result.creature!;
    final payload = payloadFactory.fromWildBreeding(offspring, randomizedWild);

    return _createEgg(offspring, payload);
  }

  /// Create starter egg
  Future<EggCreationResult> grantStarterEgg(
    FactionId faction, {
    Duration? customHatchDuration,
  }) async {
    final baseId = _pickStarterForFaction(faction);
    final payload = payloadFactory.createStarterPayload(baseId, faction);

    final base = engine.repository.getCreatureById(baseId);
    if (base == null) {
      return EggCreationResult.failure('Invalid starter');
    }

    return _createEgg(base, payload, customHatchDuration: customHatchDuration);
  }

  // Private helper for egg creation
  Future<EggCreationResult> _createEgg(
    Creature creature,
    EggPayload payload, {
    Duration? customHatchDuration,
  }) async {
    final rarityKey = creature.rarity.toLowerCase();
    final baseHatchDelay =
        customHatchDuration ??
        BreedConstants.rarityHatchTimes[rarityKey] ??
        const Duration(minutes: 10);

    // Apply nature and faction multipliers if needed
    final adjustedDelay = _applyHatchModifiers(baseHatchDelay, creature);

    final eggId = _generateEggId(payload.source);
    final payloadJson = payload.toJsonString();

    final free = await db.incubatorDao.firstFreeSlot();

    if (free == null) {
      await db.incubatorDao.enqueueEgg(
        eggId: eggId,
        resultCreatureId: creature.id,
        rarity: creature.rarity,
        remaining: adjustedDelay,
        payloadJson: payloadJson,
      );

      return EggCreationResult.queued(eggId: eggId, creatureId: creature.id);
    } else {
      final hatchAtUtc = DateTime.now().toUtc().add(adjustedDelay);
      await db.incubatorDao.placeEgg(
        slotId: free.id,
        eggId: eggId,
        resultCreatureId: creature.id,
        rarity: creature.rarity,
        hatchAtUtc: hatchAtUtc,
        payloadJson: payloadJson,
      );

      return EggCreationResult.incubating(
        eggId: eggId,
        creatureId: creature.id,
        slotId: free.id,
      );
    }
  }

  Duration _applyHatchModifiers(Duration base, Creature creature) {
    // Apply nature modifier
    final natureMult = hatchMultForNature(creature.nature?.id);

    // Could apply faction modifiers here
    // final factionMult = ...

    return Duration(milliseconds: (base.inMilliseconds * natureMult).round());
  }

  String _generateEggId(String source) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = Random(
      now,
    ).nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '${source}_${now}_$random';
  }

  String _pickStarterForFaction(FactionId faction) {
    switch (faction) {
      case FactionId.fire:
        return 'LET01';
      case FactionId.water:
        return 'LET02';
      case FactionId.earth:
        return 'LET03';
      case FactionId.air:
        return 'LET04';
    }
  }
}

class EggCreationResult {
  final bool success;
  final String? eggId;
  final String? creatureId;
  final int? slotId;
  final String? message;
  final EggPlacement placement;

  EggCreationResult._({
    required this.success,
    this.eggId,
    this.creatureId,
    this.slotId,
    this.message,
    required this.placement,
  });

  factory EggCreationResult.incubating({
    required String eggId,
    required String creatureId,
    required int slotId,
  }) {
    return EggCreationResult._(
      success: true,
      eggId: eggId,
      creatureId: creatureId,
      slotId: slotId,
      placement: EggPlacement.incubator,
    );
  }

  factory EggCreationResult.queued({
    required String eggId,
    required String creatureId,
  }) {
    return EggCreationResult._(
      success: true,
      eggId: eggId,
      creatureId: creatureId,
      placement: EggPlacement.storage,
    );
  }

  factory EggCreationResult.failure(String message) {
    return EggCreationResult._(
      success: false,
      message: message,
      placement: EggPlacement.none,
    );
  }
}

enum EggPlacement { incubator, storage, none }
