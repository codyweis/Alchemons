import 'package:alchemons/services/campaign_journal_service.dart';
import 'package:alchemons/audio/audio.dart';
import 'dart:convert';
import 'package:alchemons/widgets/animations/hatch_reveal_stage.dart';
import 'package:alchemons/models/potential_genetics.dart';
import 'dart:math';
import 'dart:ui';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/constants/egg.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/screens/breed/utils/breed_utils.dart';
import 'package:alchemons/screens/breeding_milestones_screen.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/constellation_service.dart';
import 'package:alchemons/services/new_discovery_reveal_controller.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/services/creature_instance_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/screens/alchemical_encyclopedia_screen.dart';
import 'package:alchemons/services/alchemical_encyclopedia_service.dart';
import 'package:alchemons/services/cinematic_quality_service.dart';
import 'package:alchemons/services/cold_storage_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/utils/instance_purity_util.dart';
import 'package:alchemons/utils/nature_utils.dart';
import 'package:alchemons/widgets/animations/breed_result_animation.dart';
import 'package:alchemons/widgets/animations/database_typing_animation.dart';
import 'package:alchemons/widgets/animations/hatching_cinematic.dart';
import 'package:alchemons/widgets/nursery/hatch_curtain.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/creature_detail/creature_dialog.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:alchemons/widgets/delay_type_widget.dart';
import 'package:alchemons/widgets/pure_breeding_intro_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/models/egg/egg_payload.dart';
import 'package:alchemons/widgets/app_icons.dart';

/// Both natures on one line. Two separate BEHAVIOR rows would read as a
/// duplicate rather than as a pair.
String? _natureLabel(Creature creature) {
  final parts = <String>[
    if (creature.nature != null) creature.nature!.id,
    if (creature.nature2 != null) creature.nature2!.id,
  ];
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}

/// Result of a hatching operation
/// The largest scale the size gene applies to a sprite (`giant`, from
/// alchemons_genetics.json). Anything fitting a sprite into a fixed box has to
/// leave room for it, or large specimens overflow that box.
const double _maxSizeGeneScale = 1.3;

class HatchingResult {
  final bool success;
  final String? message;
  final IconData? icon;
  final Color? color;

  const HatchingResult({
    required this.success,
    this.message,
    this.icon,
    this.color,
  });

  factory HatchingResult.success() => const HatchingResult(success: true);

  factory HatchingResult.failure(
    String message, {
    IconData? icon,
    Color? color,
  }) {
    return HatchingResult(
      success: false,
      message: message,
      icon: icon,
      color: color,
    );
  }
}

/// Service class for handling egg hatching and extraction
class EggHatching {
  EggHatching._();
  static OverlayEntry? _activeDiscoveryOverlay;
  static int _overlayVersion = 0;

  // ============================================================================
  // PUBLIC API
  // ============================================================================

  /// Check if a creature is undiscovered (not yet in player's collection)
  static Future<bool> isUndiscovered(
    BuildContext context,
    String creatureId,
  ) async {
    final db = context.read<AlchemonsDatabase>();
    final row = await db.creatureDao.getCreature(creatureId);
    return row == null || row.discovered == false;
  }

  /// Main hatching orchestration

  /// Main hatching orchestration (starters = exact write, others = finalize path)
  static Future<HatchingResult> performHatching({
    required BuildContext context,
    required IncubatorSlot slot,
    required Map<String, bool> undiscoveredCache,
  }) async {
    final repo = context.read<CreatureCatalog>();
    final gameData = context.read<GameDataService>();
    final db = context.read<AlchemonsDatabase>();
    final fc = FC.of(context);

    if (slot.resultCreatureId == null) {
      return HatchingResult.failure('Could not load specimen data');
    }

    final offspring = repo.getCreatureById(slot.resultCreatureId!);
    if (offspring == null) {
      return HatchingResult.failure('Could not load specimen data');
    }

    // Check discovery before marking
    final isNewDiscovery = await isUndiscovered(context, offspring.id);
    await gameData.markDiscovered(offspring.id);

    // Parse payload ONCE
    final hp = _parsePayload(slot.payloadJson, offspring);
    final derivedStats = _deriveLevelOneStats(offspring, hp);

    // Starter branch: exact DB write, no rerolls
    if (hp.source == 'starter' || hp.source == 'bloodborn') {
      final fb = _fallbackLineageFor(offspring);

      final createdId = await db.creatureDao.insertInstanceFromHatchPayload(
        baseId: hp.baseId,
        payload: {...hp.toJson(), 'stats': derivedStats},
        fallbackGenerationDepth: fb.generationDepth,
        fallbackFactionLineage: fb.factionLineage,
        fallbackElementLineage: fb.elementLineage,
        fallbackFamilyLineage: fb.familyLineage,
        fallbackVariantFaction: fb.variantFaction,
        fallbackIsPure: fb.isPure,
      );

      if (createdId == null) {
        return HatchingResult.failure(
          'Specimen containment full. Clear space to complete extraction.',
          icon: AppIcons.warning_amber_rounded,
          color: Colors.orange.shade600,
        );
      }

      if (hp.source == 'bloodborn') {
        await db.creatureDao.updateAlchemyEffect(
          instanceId: createdId,
          effect: 'blood_aura',
        );
      }

      if (!context.mounted) return HatchingResult.success();
      await _afterHatchCommon(
        context: context,
        slot: slot,
        instanceId: createdId,
        offspring: offspring,
        isNewDiscovery: isNewDiscovery,
        undiscoveredCache: undiscoveredCache,
        isPrismatic: hp.isPrismaticSkin,
        variantFaction: hp.lineage.variantFaction,
      );
      return HatchingResult.success();
    }

    // Non-starter branch: existing finalize path
    final svc = CreatureInstanceService(db);
    final fb = _fallbackLineageFor(offspring);

    final result = await svc.finalizeInstance(
      baseId: hp.baseId,
      rarity: hp.rarity,
      natureId: hp.natureId,
      natureId2: hp.natureId2,
      genetics: hp.genetics,
      parentage: hp.parentage?.toJson(),
      isPrismaticSkin: hp.isPrismaticSkin,
      likelihoodAnalysisJson: hp.likelihoodAnalysisJson,
      source: hp.source,
      statBeauty: derivedStats['beauty'],
      statSpeed: derivedStats['speed'],
      statIntelligence: derivedStats['intelligence'],
      statStrength: derivedStats['strength'],
      generationDepth: hp.lineage.generationDepth,
      factionLineage: hp.lineage.factionLineage.isEmpty
          ? fb.factionLineage
          : hp.lineage.factionLineage,
      variantFaction: hp.lineage.variantFaction ?? fb.variantFaction,
      isPure: hp.lineage.isPure,
      elementLineage: hp.lineage.elementLineage.isEmpty
          ? fb.elementLineage
          : hp.lineage.elementLineage,
      familyLineage: hp.lineage.familyLineage.isEmpty
          ? fb.familyLineage
          : hp.lineage.familyLineage,
      statBeautyPotential: hp.potentials.beauty,
      statSpeedPotential: hp.potentials.speed,
      statIntelligencePotential: hp.potentials.intelligence,
      statStrengthPotential: hp.potentials.strength,
    );

    if (result.status == InstanceFinalizeStatus.speciesFull) {
      return HatchingResult.failure(
        'Specimen containment full. Clear space to complete extraction.',
        icon: AppIcons.warning_amber_rounded,
        color: FC.orange,
      );
    }

    final instanceId = result.instanceId;
    if (instanceId == null || instanceId.isEmpty) {
      return HatchingResult.failure(
        'Extraction failed: system error',
        color: fc.danger,
      );
    }

    if (!context.mounted) return HatchingResult.success();
    await _afterHatchCommon(
      context: context,
      slot: slot,
      instanceId: instanceId,
      offspring: offspring,
      isNewDiscovery: isNewDiscovery,
      undiscoveredCache: undiscoveredCache,
      isPrismatic: hp.isPrismaticSkin,
      variantFaction: hp.lineage.variantFaction,
    );
    return HatchingResult.success();
  }

  static Map<String, double> _deriveLevelOneStats(
    Creature creature,
    EggPayload payload,
  ) {
    final base =
        creature.baseStats ??
        const SpeciesBaseStats(
          speed: 60,
          intelligence: 60,
          strength: 60,
          beauty: 60,
        );
    return {
      'speed': AlchemonStatSystem.effectiveInternal(
        speciesBase: base.speed,
        level: 1,
        potential: payload.potentials.speed,
        additionalMultiplier: AlchemonStatSystem.natureMultiplier(
          payload.natureId,
          'speed',
          payload.natureId2,
        ),
      ),
      'intelligence': AlchemonStatSystem.effectiveInternal(
        speciesBase: base.intelligence,
        level: 1,
        potential: payload.potentials.intelligence,
        additionalMultiplier: AlchemonStatSystem.natureMultiplier(
          payload.natureId,
          'intelligence',
          payload.natureId2,
        ),
      ),
      'strength': AlchemonStatSystem.effectiveInternal(
        speciesBase: base.strength,
        level: 1,
        potential: payload.potentials.strength,
        additionalMultiplier: AlchemonStatSystem.natureMultiplier(
          payload.natureId,
          'strength',
          payload.natureId2,
        ),
      ),
      'beauty': AlchemonStatSystem.effectiveInternal(
        speciesBase: base.beauty,
        level: 1,
        potential: payload.potentials.beauty,
        additionalMultiplier: AlchemonStatSystem.natureMultiplier(
          payload.natureId,
          'beauty',
          payload.natureId2,
        ),
      ),
    };
  }

  static Future<HatchingResult> performStorageHatching({
    required BuildContext context,
    required Egg egg,
    Map<String, bool> undiscoveredCache = const {},
  }) async {
    final db = context.read<AlchemonsDatabase>();
    final tempSlot = IncubatorSlot(
      id: -1,
      unlocked: true,
      eggId: egg.eggId,
      resultCreatureId: egg.resultCreatureId,
      bonusVariantId: egg.bonusVariantId,
      rarity: egg.rarity,
      hatchAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      payloadJson: egg.payloadJson,
    );

    final result = await performHatching(
      context: context,
      slot: tempSlot,
      undiscoveredCache: Map<String, bool>.from(undiscoveredCache),
    );

    if (result.success) {
      await db.incubatorDao.removeFromInventory(egg.eggId);
    }

    return result;
  }

  /// Extract a creature directly from a vial (shop purchase)
  static Future<HatchingResult> extractViaVial({
    required BuildContext context,
    required ElementalGroup group,
    required String rarity,
    required String name,
  }) async {
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();
    final payloadFactory = context.read<EggPayloadFactory>();

    // Get eligible creatures for this group and rarity
    final eligibleCreatures = repo.creatures.where((c) {
      final types = group.elementTypes;
      final matchesGroup = c.types.any(types.contains);
      final matchesRarity = c.rarity.toLowerCase() == rarity.toLowerCase();
      return matchesGroup && matchesRarity;
    }).toList();

    if (eligibleCreatures.isEmpty) {
      return HatchingResult(
        success: false,
        message: 'No creatures available for this vial type',
        icon: AppIcons.error_rounded,
        color: Colors.red,
      );
    }

    // Pick a random creature
    final offspring =
        eligibleCreatures[Random().nextInt(eligibleCreatures.length)];

    // Consume the vial only once we know it can produce a valid specimen.
    final vialRarity = switch (rarity) {
      'Common' => VialRarity.common,
      'Uncommon' => VialRarity.uncommon,
      'Rare' => VialRarity.rare,
      'Legendary' => VialRarity.legendary,
      'Mythic' => VialRarity.mythic,
      _ => VialRarity.common,
    };

    final consumed = await db.inventoryDao.consumeVial(name, group, vialRarity);
    if (!consumed) {
      return HatchingResult(
        success: false,
        message: 'Vial not found in inventory',
        icon: AppIcons.error_rounded,
        color: Colors.red,
      );
    }

    // Create standardized payload using factory
    final payload = payloadFactory.createVialPayload(offspring, vialName: name);
    final payloadJson = payload.toJsonString();

    final eggId = db.creatureDao.makeInstanceId('EGG');
    if (!context.mounted) {
      return HatchingResult(success: false, message: 'Screen was closed');
    }
    final adjustedHatchDelay = _calculateHatchTime(
      context,
      offspring,
      bothParentsFire: false,
    );
    final free = await db.incubatorDao.firstFreeSlot();

    if (free == null) {
      if (!await ColdStorageService.hasCapacity(db)) {
        await db.inventoryDao.addVial(name, group, vialRarity);
        return HatchingResult(
          success: false,
          message: await ColdStorageService.buildFullMessage(db),
          icon: AppIcons.inventory_2_rounded,
          color: Colors.orange,
        );
      }

      // Queue it
      await db.incubatorDao.enqueueEgg(
        eggId: eggId,
        resultCreatureId: offspring.id,
        rarity: offspring.rarity,
        remaining: adjustedHatchDelay,
        payloadJson: payloadJson,
      );

      return HatchingResult(
        success: true,
        message: 'Incubator full — specimen transferred to cold storage',
        icon: AppIcons.inventory_2_rounded,
        color: FC.orange,
      );
    } else {
      // Place directly
      final hatchAtUtc = DateTime.now().toUtc().add(adjustedHatchDelay);
      await db.incubatorDao.placeEgg(
        slotId: free.id,
        eggId: eggId,
        resultCreatureId: offspring.id,
        rarity: offspring.rarity,
        hatchAtUtc: hatchAtUtc,
        payloadJson: payloadJson,
      );

      return HatchingResult(
        success: true,
        message: 'Specimen placed in incubation chamber ${free.id + 1}',
        icon: AppIcons.science_rounded,
        color: const Color.fromARGB(255, 239, 255, 92),
      );
    }
  }

  // Helper for hatch time calculation

  static Duration _calculateHatchTime(
    BuildContext context,
    Creature offspring, {
    bool bothParentsFire = false,
  }) {
    final key = offspring.rarity.toLowerCase();
    final base =
        BreedConstants.rarityHatchTimes[key] ?? const Duration(minutes: 10);

    // Nature speed-up / slow-down
    final natureMult = hatchMultForNatures(
      offspring.nature?.id,
      offspring.nature2?.id,
    );

    // Constellation gestation reduction (0–0.15)
    final constellation = context.read<ConstellationEffectsService>();
    final gestationReduction = constellation.getGestationReduction();

    // 🔥 Volcanic Fire Breeder perk
    final factions = context.read<FactionService>();
    final fireMult = factions.fireBreederTimeMultiplier(
      bothParentsFire: bothParentsFire,
    );

    // Combine all multipliers
    final totalMult = natureMult * (1.0 - gestationReduction) * fireMult;

    return Duration(milliseconds: (base.inMilliseconds * totalMult).round());
  }
  // ============================================================================
  // PRIVATE HELPERS
  // ============================================================================

  /// Pick a random creature from the elemental group

  /// Parse payload from JSON
  static EggPayload _parsePayload(String? payloadJson, Creature offspring) {
    if (payloadJson == null || payloadJson.isEmpty) {
      // No payload, create minimal fallback
      return EggPayload(
        baseId: offspring.id,
        rarity: offspring.rarity,
        source: 'unknown',
        genetics: {},
        stats: CreatureStats(speed: 0, intelligence: 0, strength: 0, beauty: 0),
        potentials: CreatureStatPotentials(
          speed: 3,
          intelligence: 3,
          strength: 3,
          beauty: 3,
        ),
        lineage: LineageData(
          generationDepth: 0,
          factionLineage: {},
          elementLineage: {},
          familyLineage: {},
        ),
      );
    }

    final json = jsonDecode(payloadJson) as Map<String, dynamic>;
    return EggPayload.fromJson(json);
  }

  /// Get the color for a variant faction
  static Color? _getVariantColor(String? variantFaction) {
    if (variantFaction == null || variantFaction.isEmpty) return null;

    // Map faction names to their signature colors
    final factionColors = <String, Color>{
      'Volcanic': const Color(0xFFFF5722), // Orange-red / Fire
      'Oceanic': const Color(0xFF2196F3), // Blue / Water
      'Earthen': const Color(0xFF795548), // Brown / Earth
      'Verdant': const Color(0xFF4CAF50), // Green / Nature
      'Arcane': const Color(0xFF9C27B0), // Purple / Magic
      'Bloodborn': const Color(0xFFFF5252), // Crimson / Bloodborn
      'bloodborn': const Color(0xFFFF5252),
    };

    return factionColors[variantFaction];
  }

  static Future<void> _afterHatchCommon({
    required BuildContext context,
    required IncubatorSlot slot,
    required String instanceId,
    required Creature offspring,
    required bool isNewDiscovery,
    required Map<String, bool> undiscoveredCache,
    bool isPrismatic = false,
    String? variantFaction,
  }) async {
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();

    // Track breeding for constellation points
    // (starters and vials don't count toward breeding milestones)
    PendingMilestoneShowcase? milestoneShowcase;
    try {
      final constellationSvc = context.read<ConstellationService>();
      milestoneShowcase = await constellationSvc.incrementBreedCount(
        offspring.id,
        rarity: offspring.rarity,
      );
    } catch (e) {
      // Don't break hatching if constellation tracking fails
      debugPrint('⚠️ Failed to track breeding for constellation: $e');
    }

    // Auto-unlock the Elemental Essence Creator once the player has bred
    // enough Alchemons. Safe no-op once already unlocked.
    try {
      if (context.mounted) {
        await context.read<ShopService>().maybeAutoUnlockElementalCreator();
      }
    } catch (e) {
      debugPrint('⚠️ Failed to check Elemental Creator auto-unlock: $e');
    }

    // 👇 Capture a stable, root-level context up front
    if (!context.mounted) return;
    final NavigatorState nav = Navigator.of(context, rootNavigator: true);
    final BuildContext safeContext = nav.context;

    // Clear egg & cache
    await db.incubatorDao.clearEgg(slot.id);
    if (slot.resultCreatureId != null) {
      undiscoveredCache.remove(slot.resultCreatureId!);
    }

    final instance = await db.creatureDao.getInstance(instanceId);
    final creature = repo.getCreatureById(instance?.baseId ?? '');

    final elementName = offspring.types.first;
    final palette = paletteForElement(elementName);

    Map<String, dynamic>? parentPayload;
    final parentageJson = instance?.parentageJson;
    if (parentageJson != null && parentageJson.isNotEmpty) {
      try {
        parentPayload = jsonDecode(parentageJson) as Map<String, dynamic>;
      } catch (_) {}
    }

    final parent1 = parentPayload?['parentA'] as Map<String, dynamic>?;
    final parent2 = parentPayload?['parentB'] as Map<String, dynamic>?;
    final p1Types = parent1?['types'] as List<dynamic>?;
    final p2Types = parent2?['types'] as List<dynamic>?;

    final types = <String>[];
    if (p1Types != null && p1Types.isNotEmpty) {
      types.add(p1Types.first.toString());
    }
    if (p2Types != null && p2Types.isNotEmpty) {
      types.add(p2Types.first.toString());
    }

    final instancePath = creature!.image;
    final Color primaryHue = BreedConstants.getRarityColor(offspring.rarity);
    ImageProvider? silhouette = AssetImage('assets/images/$instancePath');

    // Determine hint type for special hatches
    // Check instance data as fallback (in case payload didn't have it)
    final actualIsPrismatic =
        isPrismatic || (instance?.isPrismaticSkin == true);
    final actualVariantFaction = variantFaction ?? instance?.variantFaction;

    HatchHintType hintType = HatchHintType.normal;
    Color? variantColor;

    if (actualIsPrismatic) {
      hintType = HatchHintType.prismatic;
    } else if (actualVariantFaction != null &&
        actualVariantFaction.isNotEmpty) {
      hintType = HatchHintType.variant;
      variantColor = _getVariantColor(actualVariantFaction);
    }

    // Elementally pure lineage gets its own cinematic treatment (purity seal
    // ring, element-colored burst, lineage caption).
    String? pureElementTypeId;
    if (instance != null) {
      final purity = classifyInstancePurity(instance, species: offspring);
      if (purity.isElementallyPure && purity.elementLineage.isNotEmpty) {
        pureElementTypeId = purity.elementLineage.keys.first;
      }
    }

    // ── Achievement counters ────────────────────────────────────────────────
    // Counted here because this is the one place that knows the finished
    // specimen, its family, its purity and whether it was a first discovery.
    final family = offspring.mutationFamily?.toLowerCase();
    if (family != null && kFusionFamilies.contains(family)) {
      await CampaignJournalService.bump(db.settingsDao, fusionMetric(family));
    }
    // "Breeds true": a first sighting whose lineage is a single element, out
    // of two parents that were not the same species. Two of a kind producing
    // their own kind is not the trick.
    if (isNewDiscovery &&
        pureElementTypeId != null &&
        parent1 != null &&
        parent2 != null &&
        parent1['baseId'] != null &&
        parent1['baseId'] != parent2['baseId']) {
      await CampaignJournalService.mark(db.settingsDao, 'purebredNew');
    }

    final recipeDiscoveryFuture =
        AlchemicalEncyclopediaService.registerBreedingDiscovery(
          db: db,
          repo: repo,
          offspring: offspring,
          parentageJson: instance?.parentageJson,
        );
    final cinematicQuality = await CinematicQualityService().getQuality();

    try {
      // ✅ still use the original context for the cinematic if you want
      if (!context.mounted) return;
      await playHatchingCinematicAlchemy(
        context: context,
        parentATypeId: types.isNotEmpty ? types[0] : offspring.types.first,
        parentBTypeId: types.length > 1 ? types[1] : offspring.types.last,
        paletteMain: primaryHue,
        creatureSilhouette: silhouette,
        // 6400, down from 7200: the ceremony was carrying a long still tail
        // after the silhouette landed, and the trim comes out of that.
        totalDuration: const Duration(milliseconds: 6400),
        hintType: hintType,
        variantColor: variantColor,
        pureElementTypeId: pureElementTypeId,
        quality: cinematicQuality,
      );
    } catch (e) {
      // The alchemy cinematic never got far enough to drop the curtain, and
      // the Lottie fallback must not play behind it.
      HatchCurtain.lower();
      if (!context.mounted) return;
      final factionSvc = context.read<FactionService>();
      final faction = factionSvc.current;
      await playHatchCinematic(
        context,
        'assets/animations/egg_hatch.json',
        palette,
        faction,
      );
    }

    if (!nav.mounted) return;

    if (!safeContext.mounted) return;
    await _showExtractionResult(
      safeContext,
      instanceId,
      isNewDiscovery,
      cinematicQuality: cinematicQuality,
    );
    if (!safeContext.mounted) return;
    if (instance != null) {
      await maybeShowFirstPureExtractionDialog(
        safeContext,
        instance: instance,
        species: offspring,
      );
    }

    final recipeDiscovery = await recipeDiscoveryFuture.catchError(
      (_) => EncyclopediaDiscoveryResult.none,
    );
    if (!safeContext.mounted) return;
    if (recipeDiscovery.hasAny) {
      _showScorchedDiscoveryOverlay(
        safeContext,
        unlocked: recipeDiscovery.unlocked,
      );
    }
    if (milestoneShowcase != null && safeContext.mounted) {
      showConstellationMilestoneOverlay(
        safeContext,
        speciesId: offspring.id,
        speciesName: offspring.name,
        showcase: milestoneShowcase,
      );
    }
  }

  /// Generate fallback lineage for wild/legacy creatures
  static ({
    int generationDepth,
    Map<String, int> factionLineage,
    Map<String, int> elementLineage,
    Map<String, int> familyLineage,
    String nativeFaction,
    String? variantFaction,
    bool isPure,
  })
  _fallbackLineageFor(Creature offspring) {
    String nativeGroupName() {
      final g = elementalGroupOf(offspring);
      return g?.displayName ?? 'Unknown';
    }

    String? primaryElement() =>
        offspring.types.isNotEmpty ? offspring.types.first : null;

    String? familyId() {
      try {
        final f = familyOf(offspring);
        return f.toString();
      } catch (_) {
        return null;
      }
    }

    final native = nativeGroupName();
    final elem = primaryElement();
    final fam = familyId();

    // Founder specimens start at generation 0.
    const depth = 0;

    final factionLineage = <String, int>{if (native != 'Unknown') native: 1};
    final elementLineage = <String, int>{if (elem != null) elem: 1};
    final familyLineage = <String, int>{
      if (fam != null && fam.isNotEmpty)
        fam: 1
      else if (native != 'Unknown')
        'Unknown': 1,
    };

    return (
      generationDepth: depth,
      factionLineage: factionLineage,
      elementLineage: elementLineage,
      familyLineage: familyLineage,
      nativeFaction: native,
      variantFaction: null,
      isPure: true,
    );
  }

  /// Build effective creature from instance (with all traits applied)
  static Future<Creature> _effectiveFromInstance(
    BuildContext context,
    String instanceId,
  ) async {
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();

    final row = await db.creatureDao.getInstance(instanceId);
    if (row == null) throw Exception('Instance not found');

    final base =
        repo.getCreatureById(row.baseId) ??
        Creature(
          id: row.baseId,
          name: row.baseId,
          types: const ['Spirit'],
          rarity: 'Common',
          description: '',
          image: '',
        );

    var out = base;

    if (row.isPrismaticSkin == true) {
      out = out.copyWith(isPrismaticSkin: true);
    }
    if (row.natureId != null && row.natureId!.isNotEmpty) {
      final n = NatureCatalog.byId(row.natureId!);
      if (n != null) out = out.copyWith(nature: n);
    }
    if (row.natureId2 != null && row.natureId2!.isNotEmpty) {
      final n = NatureCatalog.byId(row.natureId2!);
      if (n != null) out = out.copyWith(nature2: n);
    }
    if ((row.geneticsJson ?? '').isNotEmpty) {
      try {
        final gMap = Map<String, dynamic>.from(jsonDecode(row.geneticsJson!));
        out = out.copyWith(
          genetics: Genetics(gMap.map((k, v) => MapEntry(k, v.toString()))),
        );
      } catch (_) {}
    }
    if ((row.parentageJson ?? '').isNotEmpty) {
      try {
        out = out.copyWith(
          parentage: Parentage.fromJson(
            jsonDecode(row.parentageJson!) as Map<String, dynamic>,
          ),
        );
      } catch (_) {}
    }
    return out;
  }

  // ============================================================================
  // EXTRACTION RESULT DIALOG
  // ============================================================================

  static Future<void> _showExtractionResult(
    BuildContext context,
    String instanceId,
    bool isNewDiscovery, {
    required CinematicQuality cinematicQuality,
  }) async {
    final offspring = await _effectiveFromInstance(context, instanceId);

    if (!context.mounted) return;
    final factionSvc = context.read<FactionService>();
    final currentFaction = factionSvc.current;
    final factionColors = getFactionColors(currentFaction);
    final primaryColor = factionColors.$1;

    final soundOwner = Object();
    final audio = context.audio;
    bool scanComplete = false;
    // The specimen is revealed centre-card and only afterwards put away into
    // its dock; until it lands the dock holds an empty box of the same size so
    // nothing shifts when it arrives.
    bool revealLanded = false;
    bool ctaVisible = false;
    bool ctaTouchable = false;
    bool closing = false;
    double analysisDragDx = 0;

    // GlobalKey to control the animation
    final scanAnimationKey = GlobalKey<CreatureScanAnimationState>();
    // GlobalKey on the card's RepaintBoundary so we can snapshot it for the
    // "filing-away" animation on new discoveries.
    final cardBoundaryKey = GlobalKey(debugLabel: 'extraction-card-boundary');
    // Where the specimen flies to once the scan finishes.
    final dockSlotKey = GlobalKey(debugLabel: 'extraction-dock-slot');

    // Safe setState wrapper that only calls if dialog is still mounted
    void safeSetDialogState(StateSetter setDialogState, void Function() fn) {
      if (!closing) {
        setDialogState(fn);
      }
    }

    final instance = await context
        .read<AlchemonsDatabase>()
        .creatureDao
        .getInstance(instanceId);
    if (instance == null || !context.mounted) return;
    final purity = classifyInstancePurity(instance, species: offspring);
    final hasNotablePurity =
        purity.isPure || purity.isElementallyPure || purity.isSpeciesPure;

    final media = MediaQuery.of(context);
    final shortestSide = media.size.shortestSide;
    // Big enough to be the point of the screen, small enough to clear the
    // card's own edges on a short phone.
    final heroSize =
        min(media.size.width * 0.95, media.size.height * 0.82) * 0.62;
    final lowFxDevice = media.disableAnimations || shortestSide < 430;
    final dialogBlurSigma = switch (cinematicQuality) {
      CinematicQuality.cinematic => lowFxDevice ? 0.0 : 8.0,
      CinematicQuality.performance => 0.0,
    };

    Widget dialogShell(Widget child) {
      if (dialogBlurSigma <= 0) return child;
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: dialogBlurSigma,
          sigmaY: dialogBlurSigma,
        ),
        child: child,
      );
    }

    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final fc = FC.of(context);
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(12),
            child: RepaintBoundary(
              key: cardBoundaryKey,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: dialogShell(
                  Stack(
                    children: [
                      Container(
                        width: MediaQuery.of(context).size.width * 0.95,
                        height: MediaQuery.of(context).size.height * 0.82,
                        decoration: BoxDecoration(
                          color: fc.bg1,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: fc.borderAccent,
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildExtractionHeader(offspring, primaryColor, fc),

                            // Keep the specimen and its stats together in the top
                            // section. The longer analysis remains independently
                            // scrollable below it.
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final compact = constraints.maxWidth < 420;
                                  final spriteDockWidth = compact
                                      ? 158.0
                                      : 176.0;
                                  // 4 for the dock padding, 12 for the bracket
                                  // card's inset — derived so the sprite always
                                  // fits the dock instead of guessing at it.
                                  final spriteBox = spriteDockWidth - 4;
                                  // Same headroom the hero needs: the size
                                  // gene scales a sprite up to 1.3x, so
                                  // fitting it to the bracket card's inner box
                                  // alone overflowed for large specimens.
                                  final spriteSize =
                                      (spriteBox - 12) / _maxSizeGeneScale;
                                  final spriteDock = Container(
                                    width: spriteDockWidth,
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: fc.bg2,
                                      border: Border(
                                        right: BorderSide(color: fc.borderDim),
                                        bottom: BorderSide(color: fc.borderDim),
                                      ),
                                    ),
                                    child: Center(
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          SizedBox(
                                            key: dockSlotKey,
                                            height: spriteBox,
                                            width: spriteBox,
                                            // Empty while the specimen is centre
                                            // stage. The box still reserves its
                                            // space so the panel does not jump
                                            // when it arrives.
                                            child: revealLanded
                                                ? BracketCard(
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    bracketSize: 12,
                                                    strokeWidth: 1.4,
                                                    alpha: 0.85,
                                                    child: InstanceSprite(
                                                      creature: offspring,
                                                      instance: instance,
                                                      size: spriteSize,
                                                    ),
                                                  )
                                                : const SizedBox.shrink(),
                                          ),
                                          if (isNewDiscovery)
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: AnimatedOpacity(
                                                opacity: scanComplete ? 1 : 0,
                                                duration: const Duration(
                                                  milliseconds: 300,
                                                ),
                                                child: _buildBadge(
                                                  'NEW DISCOVERY',
                                                  fc.teal,
                                                ),
                                              ),
                                            ),
                                          if (instance.variantFaction != null)
                                            Positioned(
                                              top: 8,
                                              left: 8,
                                              child: AnimatedOpacity(
                                                opacity: scanComplete ? 1 : 0,
                                                duration: const Duration(
                                                  milliseconds: 300,
                                                ),
                                                child: _buildBadge(
                                                  'VARIANT DISCOVERY',
                                                  FC.purple,
                                                ),
                                              ),
                                            ),
                                          if (instance.isPrismaticSkin == true)
                                            Positioned(
                                              bottom: 8,
                                              left: 8,
                                              child: AnimatedOpacity(
                                                opacity: scanComplete ? 1 : 0,
                                                duration: const Duration(
                                                  milliseconds: 300,
                                                ),
                                                child: _buildPrismaticBadge(),
                                              ),
                                            ),
                                          if (hasNotablePurity)
                                            Positioned(
                                              bottom: 8,
                                              right: 8,
                                              child: AnimatedOpacity(
                                                opacity: scanComplete ? 1 : 0,
                                                duration: const Duration(
                                                  milliseconds: 300,
                                                ),
                                                child: _buildBadge(
                                                  purity.label.toUpperCase(),
                                                  _purityColor(purity),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );

                                  // The two stats this Alchemon passes down most
                                  // reliably; pre-Dominants creatures fall back to
                                  // whatever they are already best at.
                                  final effects = context
                                      .read<ConstellationEffectsService>();
                                  final showPotential = effects
                                      .hasPotentialAnalyzer();
                                  final showDominants = effects
                                      .hasDominantAnalyzer();
                                  final hatchDominants =
                                      DominantStats.decode(
                                        instance.dominantStats,
                                      ) ??
                                      DominantStats.fromPotentials(
                                        speed: instance.statSpeedPotential,
                                        intelligence:
                                            instance.statIntelligencePotential,
                                        strength:
                                            instance.statStrengthPotential,
                                        beauty: instance.statBeautyPotential,
                                      );

                                  final statPane = Container(
                                    decoration: BoxDecoration(
                                      color: fc.bg1,
                                      border: Border(
                                        bottom: BorderSide(color: fc.borderDim),
                                      ),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: compact ? 8 : 12,
                                      vertical: 3,
                                    ),
                                    child: DatabaseTypingAnimation(
                                      startAnimation: scanComplete,
                                      delayBetweenItems: const Duration(
                                        milliseconds: 100,
                                      ),
                                      onComplete: () {},
                                      children: [
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 3,
                                                  height: 10,
                                                  color: fc.amber,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'STAT PROFILE',
                                                  style: TextStyle(
                                                    fontFamily: 'monospace',
                                                    color: fc.amberBright,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 1.6,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Divider(
                                              height: 1,
                                              color: fc.borderDim,
                                            ),
                                            const SizedBox(height: 3),
                                          ],
                                        ),
                                        _buildCompactStatRow(
                                          'SPEED',
                                          instance.statSpeed,
                                          instance.statSpeedPotential,
                                          scanComplete,
                                          fc,
                                          const Color(0xFF0EA5E9),
                                          isDominant: showDominants && hatchDominants.contains(
                                            StatKind.speed,
                                          ),
                                          showPotential: showPotential,
                                        ),
                                        _buildCompactStatRow(
                                          'INTELLIGENCE',
                                          instance.statIntelligence,
                                          instance.statIntelligencePotential,
                                          scanComplete,
                                          fc,
                                          const Color(0xFFA855F7),
                                          isDominant: showDominants && hatchDominants.contains(
                                            StatKind.intelligence,
                                          ),
                                          showPotential: showPotential,
                                        ),
                                        _buildCompactStatRow(
                                          'STRENGTH',
                                          instance.statStrength,
                                          instance.statStrengthPotential,
                                          scanComplete,
                                          fc,
                                          const Color(0xFFC0392B),
                                          isDominant: showDominants && hatchDominants.contains(
                                            StatKind.strength,
                                          ),
                                          showPotential: showPotential,
                                        ),
                                        _buildCompactStatRow(
                                          'BEAUTY',
                                          instance.statBeauty,
                                          instance.statBeautyPotential,
                                          scanComplete,
                                          fc,
                                          const Color(0xFFF59E0B),
                                          isDominant: showDominants && hatchDominants.contains(
                                            StatKind.beauty,
                                          ),
                                          showPotential: showPotential,
                                        ),
                                      ],
                                    ),
                                  );

                                  final analysisPane = TickerMode(
                                    enabled: !closing,
                                    child: DefaultTabController(
                                      length: 2,
                                      child: Builder(
                                        builder: (tabContext) => Column(
                                          children: [
                                            // The tabs sat flush against the stat
                                            // pane's bottom edge. Both panels below
                                            // are already SingleChildScrollViews,
                                            // so the space costs no content.
                                            const SizedBox(height: 10),
                                            SizedBox(
                                              height: 32,
                                              child: TabBar(
                                                indicatorColor: fc.amberBright,
                                                indicatorWeight: 2,
                                                dividerColor:
                                                    Colors.transparent,
                                                labelColor: fc.amberBright,
                                                unselectedLabelColor:
                                                    fc.textMuted,
                                                labelPadding: EdgeInsets.zero,
                                                labelStyle: const TextStyle(
                                                  fontFamily: 'monospace',
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 1,
                                                ),
                                                tabs: const [
                                                  Tab(text: 'SPECIMEN'),
                                                  Tab(text: 'GENETICS'),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              child: Listener(
                                                behavior:
                                                    HitTestBehavior.translucent,
                                                onPointerDown: (_) {
                                                  analysisDragDx = 0;
                                                },
                                                onPointerMove: (event) {
                                                  analysisDragDx +=
                                                      event.delta.dx;
                                                },
                                                onPointerCancel: (_) {
                                                  analysisDragDx = 0;
                                                },
                                                onPointerUp: (_) {
                                                  if (analysisDragDx.abs() <
                                                      32) {
                                                    analysisDragDx = 0;
                                                    return;
                                                  }
                                                  final controller =
                                                      DefaultTabController.of(
                                                        tabContext,
                                                      );
                                                  final direction =
                                                      analysisDragDx < 0
                                                      ? 1
                                                      : -1;
                                                  final target =
                                                      (controller.index +
                                                              direction)
                                                          .clamp(
                                                            0,
                                                            controller.length -
                                                                1,
                                                          );
                                                  if (target !=
                                                      controller.index) {
                                                    controller.animateTo(
                                                      target,
                                                    );
                                                  }
                                                  analysisDragDx = 0;
                                                },
                                                child: TabBarView(
                                                  physics:
                                                      const NeverScrollableScrollPhysics(),
                                                  children: [
                                                    SingleChildScrollView(
                                                      padding:
                                                          const EdgeInsets.fromLTRB(
                                                            16,
                                                            14,
                                                            16,
                                                            8,
                                                          ),
                                                      child: DatabaseTypingAnimation(
                                                        startAnimation:
                                                            scanComplete,
                                                        delayBetweenItems:
                                                            const Duration(
                                                              milliseconds: 100,
                                                            ),
                                                        onComplete: () {},
                                                        children: [
                                                          _buildAnalysisSection(
                                                            'SPECIMEN ANALYSIS',
                                                            primaryColor,
                                                            [
                                                              _buildTypingAnalysisRow(
                                                                'CLASSIFICATION',
                                                                offspring
                                                                    .rarity,
                                                                scanComplete,
                                                                primaryColor,
                                                                fc: fc,
                                                              ),
                                                              _buildTypingAnalysisRow(
                                                                'TYPE',
                                                                offspring.types
                                                                    .join(', '),
                                                                scanComplete,
                                                                primaryColor,
                                                                fc: fc,
                                                              ),
                                                              if (hasNotablePurity)
                                                                _buildTypingAnalysisRow(
                                                                  'PURITY',
                                                                  purity.label,
                                                                  scanComplete,
                                                                  primaryColor,
                                                                  fc: fc,
                                                                ),
                                                              if (offspring
                                                                  .description
                                                                  .isNotEmpty)
                                                                _buildTypingAnalysisRow(
                                                                  'NOTES',
                                                                  offspring
                                                                      .description,
                                                                  scanComplete,
                                                                  primaryColor,
                                                                  fc: fc,
                                                                ),
                                                            ],
                                                            fc,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    SingleChildScrollView(
                                                      padding:
                                                          const EdgeInsets.fromLTRB(
                                                            16,
                                                            14,
                                                            16,
                                                            8,
                                                          ),
                                                      child: DatabaseTypingAnimation(
                                                        startAnimation:
                                                            scanComplete,
                                                        delayBetweenItems:
                                                            const Duration(
                                                              milliseconds: 100,
                                                            ),
                                                        onComplete: () {},
                                                        children: [
                                                          _buildAnalysisSection(
                                                            'GENETIC PROFILE',
                                                            primaryColor,
                                                            [
                                                              _buildTypingAnalysisRow(
                                                                'DOMINANT',
                                                                hatchDominants
                                                                    .all
                                                                    .map(
                                                                      (k) => k
                                                                          .label
                                                                          .toUpperCase(),
                                                                    )
                                                                    .join(
                                                                      ' · ',
                                                                    ),
                                                                scanComplete,
                                                                primaryColor,
                                                                fc: fc,
                                                              ),
                                                              _buildTypingAnalysisRow(
                                                                'SIZE VARIANT',
                                                                _getSizeName(
                                                                  offspring,
                                                                ),
                                                                scanComplete,
                                                                primaryColor,
                                                                fc: fc,
                                                              ),
                                                              _buildTypingAnalysisRow(
                                                                'PIGMENTATION',
                                                                _getTintName(
                                                                  offspring,
                                                                ),
                                                                scanComplete,
                                                                primaryColor,
                                                                fc: fc,
                                                              ),
                                                              // An Alchemon can
                                                              // carry two natures;
                                                              // this row only ever
                                                              // printed the first.
                                                              if (_natureLabel(
                                                                    offspring,
                                                                  ) !=
                                                                  null)
                                                                _buildTypingAnalysisRow(
                                                                  'BEHAVIOR',
                                                                  _natureLabel(
                                                                    offspring,
                                                                  )!,
                                                                  scanComplete,
                                                                  primaryColor,
                                                                  fc: fc,
                                                                ),
                                                              _buildVariantTypingRow(
                                                                instance,
                                                                scanComplete,
                                                                primaryColor,
                                                                fc,
                                                              ),
                                                            ],
                                                            fc,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      SizedBox(
                                        height: 158,
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            spriteDock,
                                            Expanded(child: statPane),
                                          ],
                                        ),
                                      ),
                                      Expanded(child: analysisPane),
                                    ],
                                  );
                                },
                              ),
                            ),

                            // Docked CTA
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: fc.bg2,
                                border: Border(
                                  top: BorderSide(color: fc.borderDim),
                                ),
                              ),
                              child: AnimatedOpacity(
                                opacity: ctaVisible ? 1 : 0,
                                duration: const Duration(milliseconds: 300),
                                onEnd: () {
                                  if (ctaVisible && !closing) {
                                    safeSetDialogState(
                                      setDialogState,
                                      () => ctaTouchable = true,
                                    );
                                  }
                                },
                                child: IgnorePointer(
                                  ignoring: !ctaTouchable || closing,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: context.soundAction(() async {
                                            if (closing) return;

                                            // Grabbed BEFORE the awaits.
                                            //
                                            // The dismissal used to look up
                                            // the navigator from this context
                                            // after the flight had finished,
                                            // inside a post-frame callback —
                                            // by which point the subtree had
                                            // rebuilt for `closing` and the
                                            // shell had switched tabs
                                            // underneath it. A defunct element
                                            // makes Navigator.of throw inside
                                            // the callback, so the card flew
                                            // and the result just sat there.
                                            // Holding the route means the
                                            // dismissal cannot depend on this
                                            // element still being alive.
                                            final resultNavigator =
                                                Navigator.of(context);
                                            final resultRoute = ModalRoute.of(
                                              context,
                                            );

                                            // Signal animation to stop any pending callbacks
                                            scanAnimationKey.currentState
                                                ?.takeAction();

                                            try {
                                              final db = context
                                                  .read<AlchemonsDatabase>();
                                              db.settingsDao.setSetting(
                                                'nav_locked_until_extraction_ack',
                                                '0',
                                              );
                                            } catch (_) {}

                                            // Update state to stop all tickers/animations
                                            setDialogState(() {
                                              closing = true;
                                              ctaTouchable = false;
                                            });

                                            if (isNewDiscovery) {
                                              await NewDiscoveryReveal.instance
                                                  .playFilingAway(
                                                    context: context,
                                                    cardBoundaryKey:
                                                        cardBoundaryKey,
                                                    creatureId: offspring.id,
                                                  );
                                            }

                                            if (resultRoute != null &&
                                                resultRoute.isActive) {
                                              resultNavigator.removeRoute(
                                                resultRoute,
                                              );
                                            } else if (resultNavigator
                                                .canPop()) {
                                              resultNavigator.pop();
                                            }
                                          }),

                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 22,
                                              vertical: 13,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                              border: Border.all(
                                                color: fc.amber,
                                                width: 1.2,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Container(
                                                  width: 3,
                                                  height: 14,
                                                  color: fc.amberBright,
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  'EXTRACTION CONFIRMED',
                                                  style: TextStyle(
                                                    fontFamily: 'monospace',
                                                    color: fc.amberBright,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 12,
                                                    letterSpacing: 2.0,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      GestureDetector(
                                        onTap: context.soundAction(() {
                                          if (closing) return;

                                          CreatureDetailsDialog.show(
                                            context,
                                            offspring,
                                            true,
                                            instanceId: instanceId,
                                          );
                                        }),
                                        child: Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: fc.bg3,
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                            border: Border.all(
                                              color: fc.borderDim,
                                              width: 1.2,
                                            ),
                                          ),
                                          child: Icon(
                                            AppIcons.info_outline_rounded,
                                            color: fc.textSecondary,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // THE REVEAL. The specimen is scanned large in the
                      // middle of the card, then carried into its dock — the
                      // scan used to play at thumbnail size in the corner,
                      // which is where it lives, not where it should be shown.
                      if (!revealLanded)
                        Positioned.fill(
                          child: HatchRevealStage(
                            dockKey: dockSlotKey,
                            heroSize: heroSize,
                            dockSize: heroSize,
                            scanComplete: scanComplete,
                            onLanded: () => safeSetDialogState(
                              setDialogState,
                              () => revealLanded = true,
                            ),
                            child: BracketCard(
                              padding: const EdgeInsets.all(6),
                              bracketSize: 12,
                              strokeWidth: 1.4,
                              alpha: 0.85,
                              child: CreatureScanAnimation(
                                key: scanAnimationKey,
                                onScanStarted: () {
                                  audio?.stopSoundOwner(soundOwner);
                                  final rare =
                                      isNewDiscovery ||
                                      offspring.isPrismaticSkin == true ||
                                      offspring.rarity.toLowerCase() ==
                                          'legendary' ||
                                      offspring.rarity.toLowerCase() ==
                                          'mystic';
                                  final scanMs =
                                      cinematicQuality ==
                                          CinematicQuality.cinematic
                                      ? 1800
                                      : 1000;
                                  // Match the identification tone to the scan chain's ready event.
                                  final readyMs =
                                      scanMs * .75 +
                                      (isNewDiscovery ? 1000 : 0);
                                  final lockMs = rare ? 1770 : 1080;
                                  context.sound(
                                    rare
                                        ? SoundCue.extractionRareReveal
                                        : SoundCue.extractionCreatureReveal,
                                    owner: soundOwner,
                                    speed: lockMs / readyMs,
                                  );
                                },
                                isNewDiscovery: isNewDiscovery,
                                scanDuration: switch (cinematicQuality) {
                                  CinematicQuality.cinematic => const Duration(
                                    milliseconds: 1800,
                                  ),
                                  CinematicQuality.performance =>
                                    const Duration(milliseconds: 1000),
                                },
                                onReadyChanged: (ready) {
                                  if (!ready) return;
                                  safeSetDialogState(setDialogState, () {
                                    scanComplete = true;
                                    ctaVisible = true;
                                  });
                                },
                                // InstanceSprite scales itself by the size
                                // gene, and `giant` is 1.3x — so a sprite
                                // sized to the box overflowed it for large
                                // specimens. Sized from that maximum rather
                                // than trimmed by eye.
                                child: InstanceSprite(
                                  creature: offspring,
                                  instance: instance,
                                  size: (heroSize - 12) / _maxSizeGeneScale,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    audio?.stopSoundOwner(soundOwner);
  }

  // ============================================================================
  // DIALOG UI COMPONENTS
  // ============================================================================

  static void _showScorchedDiscoveryOverlay(
    BuildContext context, {
    required List<EncyclopediaRecipeEntry> unlocked,
  }) {
    final rootNav = Navigator.of(context, rootNavigator: true);
    final overlay = rootNav.overlay;
    if (overlay == null) return;

    final unlockQueue = List<EncyclopediaRecipeEntry>.unmodifiable(unlocked);
    final count = unlockQueue.length;
    final title = count == 1
        ? 'New discovery added'
        : '$count new discoveries added';

    void dismissOverlay() {
      _activeDiscoveryOverlay?.remove();
      _activeDiscoveryOverlay = null;
    }

    void openEncyclopedia() {
      dismissOverlay();
      rootNav.push(
        MaterialPageRoute(
          builder: (_) =>
              AlchemicalEncyclopediaScreen(unlockShowcase: unlockQueue),
        ),
      );
    }

    dismissOverlay();
    final int version = ++_overlayVersion;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        final top = MediaQuery.of(overlayContext).padding.top + 10;
        return Positioned(
          top: top,
          left: 14,
          right: 14,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: context.soundAction(openEncyclopedia),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2B1711), Color(0xFF4B2317)],
                  ),
                  border: Border.all(
                    color: const Color(0xFFE26A3D).withValues(alpha: .7),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE26A3D).withValues(alpha: .2),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE26A3D).withValues(alpha: .2),
                        border: Border.all(
                          color: const Color(0xFFE26A3D).withValues(alpha: .6),
                        ),
                      ),
                      child: const Icon(
                        AppIcons.menu_book_rounded,
                        color: Color(0xFFFFB188),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$title • Tap to open encyclopedia',
                        style: const TextStyle(
                          color: Color(0xFFFFD4C1),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    _activeDiscoveryOverlay = entry;
    overlay.insert(entry);

    Future<void>.delayed(const Duration(seconds: 4), () {
      if (_overlayVersion == version) {
        dismissOverlay();
      }
    });
  }

  static Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 0.9),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: 'monospace',
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  static Widget _buildPrismaticBadge() {
    const prismaticColors = [
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.green,
      Colors.cyan,
      Colors.blue,
      Colors.purple,
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: prismaticColors
              .map((c) => c.withValues(alpha: 0.14))
              .toList(),
        ),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 0.9,
        ),
      ),
      child: ShaderMask(
        shaderCallback: (bounds) =>
            LinearGradient(colors: prismaticColors).createShader(bounds),
        child: const Text(
          'PRISMATIC',
          style: TextStyle(
            fontFamily: 'monospace',
            color: Colors.white,
            fontSize: 8.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
      ),
    );
  }

  static Color _purityColor(InstancePurityStatus purity) {
    if (purity.isPure) return Colors.greenAccent.shade400;
    if (purity.isElementallyPure) return Colors.cyanAccent.shade400;
    if (purity.isSpeciesPure) return Colors.amberAccent.shade400;
    return Colors.orangeAccent.shade200;
  }

  static void showConstellationMilestoneOverlay(
    BuildContext context, {
    required String speciesId,
    required String speciesName,
    required PendingMilestoneShowcase showcase,
  }) {
    final rootNav = Navigator.of(context, rootNavigator: true);
    final overlay = rootNav.overlay;
    if (overlay == null) return;

    void dismissOverlay() {
      _activeDiscoveryOverlay?.remove();
      _activeDiscoveryOverlay = null;
    }

    void openProgress() {
      dismissOverlay();
      rootNav.push(
        MaterialPageRoute(
          builder: (_) => BreedingMilestoneScreen(speciesId: speciesId),
        ),
      );
    }

    dismissOverlay();
    final int version = ++_overlayVersion;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        final top = MediaQuery.of(overlayContext).padding.top + 10;
        return Positioned(
          top: top,
          left: 14,
          right: 14,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: context.soundAction(openProgress),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF14192D), Color(0xFF223057)],
                  ),
                  border: Border.all(
                    color: const Color(0xFF7AA7FF).withValues(alpha: .72),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7AA7FF).withValues(alpha: .22),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF7AA7FF).withValues(alpha: .16),
                        border: Border.all(
                          color: const Color(0xFF7AA7FF).withValues(alpha: .55),
                        ),
                      ),
                      child: const Icon(
                        AppIcons.auto_awesome_rounded,
                        color: Color(0xFFDDE8FF),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$speciesName reached ${showcase.milestoneCount} bred  •  +${showcase.pointsAwarded} constellation points  •  Tap to open progress',
                        style: const TextStyle(
                          color: Color(0xFFE2ECFF),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    _activeDiscoveryOverlay = entry;
    overlay.insert(entry);

    Future<void>.delayed(const Duration(seconds: 4), () {
      if (_overlayVersion == version) {
        dismissOverlay();
      }
    });
  }

  static Widget _buildExtractionHeader(
    Creature offspring,
    Color primaryColor,
    FC fc,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: fc.bg3,
        border: Border(bottom: BorderSide(color: fc.borderDim)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 14, color: fc.amber),
              const SizedBox(width: 10),
              Icon(AppIcons.science_outlined, color: fc.amberBright, size: 15),
              const SizedBox(width: 8),
              Text(
                'EXTRACTION COMPLETE',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: fc.amberBright,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: fc.borderMid),
          const SizedBox(height: 10),
          Text(
            offspring.name,
            style: TextStyle(
              fontFamily: 'monospace',
              color: fc.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildAnalysisSection(
    String title,
    Color primaryColor,
    List<Widget> children,
    FC fc,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: fc.bg2,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: fc.borderDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: fc.bg3,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(2),
              ),
            ),
            child: Row(
              children: [
                Container(width: 3, height: 10, color: fc.amber),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: fc.amberBright,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: fc.borderDim),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildTypingAnalysisRow(
    String label,
    String value,
    bool startTyping,
    Color primaryColor, {
    Duration delay = Duration.zero,
    required FC fc,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 'CLASSIFICATION' at 11px with 1.4 letter-spacing fills 120 exactly,
          // so it touched its value with no gap at all.
          SizedBox(
            width: 128,
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'monospace',
                color: fc.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: startTyping
                ? DelayedTypingText(
                    text: value,
                    delay: delay,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: fc.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  static Widget _buildCompactStatRow(
    String label,
    double value,
    double potential,
    bool visible,
    FC fc,
    Color statColor, {
    bool isDominant = false,
    required bool showPotential,
  }) {
    final potentialRating = AlchemonStatSystem.normalizePotential(potential);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'monospace',
                color: isDominant ? fc.dominant : fc.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
          if (visible) ...[
            Text(
              AlchemonStatSystem.displayRating(value).toString(),
              style: TextStyle(
                fontFamily: 'monospace',
                color: statColor,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            // The extraction result was announcing the figure the rest of
            // the game hides — and it is the first place a new specimen's
            // Potential could ever be read, so it undid the gate entirely.
            if (showPotential) ...[
            const SizedBox(width: 7),
            Text.rich(
              TextSpan(
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: fc.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
                children: [
                  const TextSpan(text: 'P '),
                  TextSpan(
                    text: potentialRating.toString(),
                    style: TextStyle(
                      color: _potentialTierColor(potentialRating),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
            ),
            ],
          ],
        ],
      ),
    );
  }

  static Color _potentialTierColor(int potential) {
    if (potential <= 20) return const Color(0xFFC0392B);
    if (potential <= 40) return const Color(0xFFF97316);
    if (potential <= 60) return const Color(0xFFF59E0B);
    if (potential <= 80) return const Color(0xFF22C55E);
    return const Color(0xFFA855F7);
  }

  static Widget _buildVariantTypingRow(
    CreatureInstance? instance,
    bool startTyping,
    Color primaryColor,
    FC fc,
  ) {
    if (instance == null) return const SizedBox.shrink();
    final variantType = instance.variantFaction;
    if (variantType == null || variantType.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildTypingAnalysisRow(
      'VARIANT FACTION',
      _displayVariantFaction(variantType),
      startTyping,
      primaryColor,
      delay: const Duration(milliseconds: 900),
      fc: fc,
    );
  }

  static String _displayVariantFaction(String faction) {
    final trimmed = faction.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.toLowerCase() == 'bloodborn') return 'Bloodborn';
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  static String _getSizeName(Creature c) =>
      sizeLabels[c.genetics?.get('size') ?? 'normal'] ?? 'Standard';

  static String _getTintName(Creature c) =>
      tintLabels[c.genetics?.get('tinting') ?? 'normal'] ?? 'Standard';
}
