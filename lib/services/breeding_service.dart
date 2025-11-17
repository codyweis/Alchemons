// lib/services/breeding_service_v2.dart

import 'dart:convert';
import 'dart:math';

import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/egg/egg_payload.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/breeding_engine.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/services/wild_breed_randomizer.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/utils/likelihood_analyzer.dart';
import 'package:alchemons/utils/nature_utils.dart';

class BreedingServiceV2 {
  final GameDataService gameData;
  final AlchemonsDatabase db;
  final BreedingEngine engine;
  final EggPayloadFactory payloadFactory;
  final WildCreatureRandomizer wildRandomizer;

  // Access catalog via engine so we don’t need another injected param
  CreatureCatalog get repository => engine.repository;

  BreedingServiceV2({
    required this.gameData,
    required this.db,
    required this.engine,
    required this.payloadFactory,
    required this.wildRandomizer,
  });

  /// Regular breeding between two owned instances
  ///
  /// We:
  ///   1) Call the engine exactly once.
  ///   2) Use that *same* offspring for the likelihood analyzer.
  ///   3) Store the analysis JSON inside the EggPayload.
  Future<EggCreationResult> breedInstances(
    CreatureInstance parent1,
    CreatureInstance parent2, {
    // kept for backward compat; ignored now
    String? likelihoodAnalysisJson,
  }) async {
    final result = engine.breedInstances(parent1, parent2);

    if (!result.success || result.creature == null) {
      return EggCreationResult.failure('Genetic incompatibility');
    }

    final offspring = result.creature!;

    // Compute analysis based on *this* offspring
    final analysisJson = _buildInstanceBreedingAnalysis(
      parent1,
      parent2,
      offspring,
    );

    final payload = payloadFactory.fromBreedingResult(
      offspring,
      likelihoodAnalysisJson: analysisJson,
    );

    return _createEgg(offspring, payload);
  }

  /// Wild breeding - breed instance with wild catalog creature
  ///
  /// Same pattern: only one breeding pass, then analysis on that result.
  Future<EggCreationResult> breedWithWild(
    CreatureInstance ownedParent,
    Creature wildCreature, {
    int? wildSeed,
    // kept for compat; ignored
    String? likelihoodAnalysisJson,
  }) async {
    // Randomize wild creature's attributes ONCE
    final randomizedWild = wildRandomizer.randomizeWildCreature(
      wildCreature,
      seed: wildSeed,
    );

    // Breed using the randomized wild
    final result = engine.breedInstanceWithCreature(
      ownedParent,
      randomizedWild,
    );

    if (!result.success || result.creature == null) {
      return EggCreationResult.failure('Genetic incompatibility');
    }

    final offspring = result.creature!;

    // Compute analysis based on the actual offspring + randomized wild
    final analysisJson = _buildWildBreedingAnalysis(
      ownedParent,
      randomizedWild,
      offspring,
    );

    final payload = payloadFactory.fromWildBreeding(
      offspring,
      ownedParent, // Parent A (owned)
      randomizedWild, // Parent B (wild used for breeding)
      likelihoodAnalysisJson: analysisJson,
    );

    return _createEgg(offspring, payload);
  }

  /// Create starter egg (starters have no RNG/analysis)
  Future<EggCreationResult> grantStarterEgg(
    FactionId faction, {
    Duration? customHatchDuration,
  }) async {
    final baseId = _pickStarterForFaction(faction);
    final payload = payloadFactory.createStarterPayload(baseId, faction);

    final base = repository.getCreatureById(baseId);
    if (base == null) {
      return EggCreationResult.failure('Invalid starter');
    }

    return _createEgg(base, payload, customHatchDuration: customHatchDuration);
  }

  // ---------------------------------------------------------------------------
  // PRIVATE: Analysis helpers
  // ---------------------------------------------------------------------------

  String? _buildInstanceBreedingAnalysis(
    CreatureInstance parent1,
    CreatureInstance parent2,
    Creature offspring,
  ) {
    try {
      final baseA = repository.getCreatureById(parent1.baseId);
      final baseB = repository.getCreatureById(parent2.baseId);

      if (baseA == null || baseB == null) return null;

      // Hydrate instances with genetics + nature
      final geneticsA = decodeGenetics(parent1.geneticsJson);
      final geneticsB = decodeGenetics(parent2.geneticsJson);

      final parentA = baseA.copyWith(
        genetics: geneticsA,
        nature: parent1.natureId != null
            ? NatureCatalog.byId(parent1.natureId!)
            : baseA.nature,
        isPrismaticSkin: parent1.isPrismaticSkin,
      );

      final parentB = baseB.copyWith(
        genetics: geneticsB,
        nature: parent2.natureId != null
            ? NatureCatalog.byId(parent2.natureId!)
            : baseB.nature,
        isPrismaticSkin: parent2.isPrismaticSkin,
      );

      final analyzer = BreedingLikelihoodAnalyzer(
        repository: repository,
        elementRecipes: engine.elementRecipes,
        familyRecipes: engine.familyRecipes,
        tuning: engine.tuning,
        engine: engine,
      );

      final report = analyzer.analyzeBreedingResult(
        parentA,
        parentB,
        offspring,
      );

      return jsonEncode(report.toJson());
    } catch (e, st) {
      // Don't break breeding if analyzer dies – just log & skip analysis.
      // ignore: avoid_print
      print('⚠️ BreedingServiceV2: instance analysis failed: $e\n$st');
      return null;
    }
  }

  String? _buildWildBreedingAnalysis(
    CreatureInstance ownedParent,
    Creature randomizedWild,
    Creature offspring,
  ) {
    try {
      final ownedBase = repository.getCreatureById(ownedParent.baseId);
      if (ownedBase == null) return null;

      final geneticsOwned = decodeGenetics(ownedParent.geneticsJson);
      final hydratedOwned = ownedBase.copyWith(
        genetics: geneticsOwned,
        nature: ownedParent.natureId != null
            ? NatureCatalog.byId(ownedParent.natureId!)
            : ownedBase.nature,
        isPrismaticSkin: ownedParent.isPrismaticSkin,
      );

      final analyzer = BreedingLikelihoodAnalyzer(
        repository: repository,
        elementRecipes: engine.elementRecipes,
        familyRecipes: engine.familyRecipes,
        tuning: engine.tuning,
        engine: engine,
      );

      final report = analyzer.analyzeBreedingResult(
        hydratedOwned,
        randomizedWild,
        offspring,
      );

      return jsonEncode(report.toJson());
    } catch (e, st) {
      // ignore: avoid_print
      print('⚠️ BreedingServiceV2: wild analysis failed: $e\n$st');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // PRIVATE: Egg creation
  // ---------------------------------------------------------------------------

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

    // Apply nature modifier
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
    final natureMult = hatchMultForNature(creature.nature?.id);
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
