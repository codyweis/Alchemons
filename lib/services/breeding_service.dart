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
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
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
  final ConstellationEffectsService constellation; // 👈 NEW
  final FactionService factions;

  // Access catalog via engine so we don’t need another injected param
  CreatureCatalog get repository => engine.repository;

  BreedingServiceV2({
    required this.gameData,
    required this.db,
    required this.engine,
    required this.payloadFactory,
    required this.wildRandomizer,
    required this.constellation, // 👈 NEW
    required this.factions,
  });

  String _familyKeyForCreature(Creature c) {
    if (c.mutationFamily != null && c.mutationFamily!.isNotEmpty) {
      return c.mutationFamily!.toUpperCase();
    }
    final match = RegExp(r'^[A-Za-z]+').firstMatch(c.id);
    final letters = match?.group(0) ?? c.id;
    return letters.toUpperCase();
  }

  /// Returns true if cross-species breeding is allowed between these two base IDs,
  /// based on mutationFamily + constellation unlock state.
  Future<bool> _canCrossBreed(String baseIdA, String baseIdB) async {
    final baseA = repository.getCreatureById(baseIdA);
    final baseB = repository.getCreatureById(baseIdB);

    // If either base is missing, don't hard-block breeding.
    if (baseA == null || baseB == null) return true;

    final famA = _familyKeyForCreature(baseA);
    final famB = _familyKeyForCreature(baseB);

    // Same family is always allowed
    if (famA == famB) return true;

    // Different family → require Cross-Species Lineage skill
    final unlocked = await db.constellationDao.getUnlockedSkillIds();
    return unlocked.contains('breeder_cross_species');
  }

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
    // ---- Cross-species gate (owned vs owned) ----
    final allowed = await _canCrossBreed(parent1.baseId, parent2.baseId);
    if (!allowed) {
      return EggCreationResult.failure('Cross-species synthesis is locked.');
    }
    // ---------------------------------------------
    final result = engine.breedInstances(parent1, parent2);

    if (!result.success || result.creature == null) {
      return EggCreationResult.failure('Genetic incompatibility');
    }

    final offspring = result.creature!;

    // For fire perk: check if both parents are Fire-type
    final baseA = repository.getCreatureById(parent1.baseId);
    final baseB = repository.getCreatureById(parent2.baseId);

    final bothParentsFire =
        baseA != null &&
        baseB != null &&
        baseA.types.contains('Fire') &&
        baseB.types.contains('Fire');

    final analysisJson = _buildInstanceBreedingAnalysis(
      parent1,
      parent2,
      offspring,
    );

    final payload = payloadFactory.fromBreedingResult(
      offspring,
      likelihoodAnalysisJson: analysisJson,
    );

    return _createEgg(offspring, payload, bothParentsFire: bothParentsFire);
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
    // ---- Cross-species gate (owned vs wild) ----
    final allowed = await _canCrossBreed(ownedParent.baseId, wildCreature.id);
    if (!allowed) {
      return EggCreationResult.failure(
        'Cross-species synthesis with wild specimens is locked.',
      );
    }
    // --------------------------------------------

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
      ownedParent,
      randomizedWild,
      likelihoodAnalysisJson: analysisJson,
    );

    // Fire perk: owned parent + wild both Fire?
    final ownedBase = repository.getCreatureById(ownedParent.baseId);
    final bothParentsFire =
        ownedBase != null &&
        ownedBase.types.contains('Fire') &&
        randomizedWild.types.contains('Fire');

    return _createEgg(offspring, payload, bothParentsFire: bothParentsFire);
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
    bool bothParentsFire = false,
  }) async {
    final rarityKey = creature.rarity.toLowerCase();
    final baseHatchDelay =
        customHatchDuration ??
        BreedConstants.rarityHatchTimes[rarityKey] ??
        const Duration(minutes: 10);

    // Apply nature + constellation + (maybe) fire perk
    final adjustedDelay = _applyHatchModifiers(
      baseHatchDelay,
      creature,
      bothParentsFire: bothParentsFire,
    );

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

  Duration _applyHatchModifiers(
    Duration base,
    Creature creature, {
    bool bothParentsFire = false,
  }) {
    final natureMult = hatchMultForNature(creature.nature?.id);

    // Constellation gestation reduction (0–0.15)
    final gestationReduction = constellation.getGestationReduction();

    // 🔥 Volcanic Fire Breeder perk
    // FactionService internally checks:
    // - current faction == Volcanic
    // - perk1Active
    // - bothParentsFire
    // and does the 50% RNG. Returns 1.0 or 0.5.
    final fireMult = factions.fireBreederTimeMultiplier(
      bothParentsFire: bothParentsFire,
    );

    // Nature can make it slower/faster; constellation and fire perk reduce time
    final totalMult = natureMult * (1.0 - gestationReduction) * fireMult;

    return Duration(milliseconds: (base.inMilliseconds * totalMult).round());
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
      case FactionId.volcanic:
        return 'LET01';
      case FactionId.oceanic:
        return 'LET02';
      case FactionId.earthen:
        return 'LET03';
      case FactionId.verdant:
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
