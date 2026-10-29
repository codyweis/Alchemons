import 'package:alchemons/services/blood_rebirth_service.dart';
import 'package:alchemons/services/campaign_journal_service.dart';
import 'package:alchemons/audio/audio.dart';
import 'dart:convert';
import 'dart:math';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/services/timed_boost_service.dart';
import 'package:alchemons/utils/cultivation_time.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/egg/egg_payload_helpers.dart';
import 'package:alchemons/models/home_keepsakes.dart' show kEffigyBredCount;
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/models/vial_infusion.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/screens/progress_overview_screen.dart';
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
import 'package:alchemons/utils/instance_purity_util.dart';
import 'package:alchemons/widgets/animations/bloodborn_extraction.dart';
import 'package:alchemons/widgets/animations/hatching_cinematic.dart';
import 'package:alchemons/widgets/nursery/extraction_result_card.dart';
import 'package:alchemons/widgets/nursery/hatch_curtain.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:alchemons/widgets/mutation_intro_dialog.dart';
import 'package:alchemons/widgets/pure_breeding_intro_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/models/egg/egg_payload.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/models/wild_fusion.dart';

/// Result of a hatching operation
class HatchingResult {
  final bool success;
  final String? message;
  final IconData? icon;
  final Color? color;
  final String? instanceId;
  final String? creatureId;
  final bool isNewDiscovery;

  const HatchingResult({
    required this.success,
    this.message,
    this.icon,
    this.color,
    this.instanceId,
    this.creatureId,
    this.isNewDiscovery = false,
  });

  factory HatchingResult.success({
    String? instanceId,
    String? creatureId,
    bool isNewDiscovery = false,
  }) => HatchingResult(
    success: true,
    instanceId: instanceId,
    creatureId: creatureId,
    isNewDiscovery: isNewDiscovery,
  );

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

/// Everything the ceremony needs to draw one egg, derived in ONE place.
///
/// The batch grid runs several ceremonies at once and must dress each of them
/// exactly as the single-extraction ceremony would. Re-deriving hint type,
/// purity and parent elements at the call site is how the two drift apart, so
/// both paths read these from [EggHatching.ceremonyParamsFor].
class HatchCeremonyParams {
  const HatchCeremonyParams({
    required this.parentATypeId,
    required this.parentBTypeId,
    required this.resultTypeId,
    required this.paletteMain,
    required this.silhouette,
    required this.hintType,
    required this.variantColor,
    required this.pureElementTypeId,
    required this.mutationFamily,
    this.mutation,
  });

  final String parentATypeId;
  final String? parentBTypeId;
  final String? resultTypeId;
  final Color paletteMain;
  final ImageProvider? silhouette;
  final HatchHintType hintType;
  final Color? variantColor;
  final String? pureElementTypeId;
  final String? mutationFamily;
  final AlchemonMutation? mutation;
}

class EggHatching {
  EggHatching._();

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

  /// Ceremony dressing for a finished specimen. See [HatchCeremonyParams].
  static HatchCeremonyParams ceremonyParamsFor({
    required CreatureInstance instance,
    required Creature offspring,
  }) {
    // Parent elements come from the stored parentage when there is any; a
    // wild or legacy specimen falls back to its own elements, which is what
    // the single ceremony does too.
    final types = <String>[];
    final raw = instance.parentageJson;
    if (raw != null && raw.isNotEmpty) {
      try {
        final payload = jsonDecode(raw) as Map<String, dynamic>;
        for (final key in const ['parentA', 'parentB']) {
          final p = payload[key] as Map<String, dynamic>?;
          final t = p?['types'] as List<dynamic>?;
          if (t != null && t.isNotEmpty) types.add(t.first.toString());
        }
      } catch (_) {}
    }

    HatchHintType hintType = HatchHintType.normal;
    Color? variantColor;
    final variantFaction = instance.variantFaction;
    if (instance.isPrismaticSkin == true) {
      hintType = HatchHintType.prismatic;
    } else if (variantFaction != null && variantFaction.isNotEmpty) {
      hintType = HatchHintType.variant;
      variantColor = _getVariantColor(variantFaction);
    }

    String? pureElementTypeId;
    final purity = classifyInstancePurity(instance, species: offspring);
    if (purity.isElementallyPure && purity.elementLineage.isNotEmpty) {
      pureElementTypeId = purity.elementLineage.keys.first;
    }

    return HatchCeremonyParams(
      parentATypeId: types.isNotEmpty ? types[0] : offspring.types.first,
      parentBTypeId: types.length > 1 ? types[1] : offspring.types.last,
      resultTypeId: offspring.types.isNotEmpty ? offspring.types.first : null,
      paletteMain: BreedConstants.getRarityColor(offspring.rarity),
      silhouette: AssetImage('assets/images/${offspring.image}'),
      hintType: hintType,
      variantColor: variantColor,
      pureElementTypeId: pureElementTypeId,
      mutationFamily: offspring.mutationFamily,
      mutation: AlchemonMutation.byId(instance.mutation),
    );
  }

  static Future<HatchingResult> performHatching({
    required BuildContext context,
    required IncubatorSlot slot,
    required Map<String, bool> undiscoveredCache,
    bool showPresentation = true,
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
      // A Blood Ring vial carries the favorite that was offered: it comes
      // out as that companion made new, not as a level-one specimen.
      final raw = jsonDecode(slot.payloadJson ?? '{}');
      final rebirth =
          hp.source == 'bloodborn' &&
          raw is Map<String, dynamic> &&
          BloodRebirthService.carriesRecord(raw);

      final createdId = rebirth
          ? await BloodRebirthService(db).hatch(raw, offspring)
          : await db.creatureDao.insertInstanceFromHatchPayload(
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
        showPresentation: showPresentation,
      );
      return HatchingResult.success(
        instanceId: createdId,
        creatureId: offspring.id,
        isNewDiscovery: isNewDiscovery,
      );
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
      mutation: hp.mutation,
      likelihoodAnalysisJson: hp.likelihoodAnalysisJson,
      provenance: hp.provenance,
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
      // The Dominants breeding inherited. Dropped here, every bred child was
      // given its best two instead of what it was bred to carry.
      dominantStats: hp.potentials.dominants?.encode(),
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
      showPresentation: showPresentation,
    );
    return HatchingResult.success(
      instanceId: instanceId,
      creatureId: offspring.id,
      isNewDiscovery: isNewDiscovery,
    );
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

  /// Extract the vial on a chamber's stand with what it was infused with
  /// (models/vial_infusion.dart). The vial was taken from the inventory when
  /// it was set down. [pay] spends the extraction's essence; it is only
  /// asked once there is somewhere for the egg to go, and the infusion is
  /// left on the stand if there is not.
  static Future<HatchingResult> extractInfusedVial({
    required BuildContext context,
    required VialInfusion infusion,
    required Future<bool> Function() pay,
  }) async {
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();
    final payloadFactory = context.read<EggPayloadFactory>();
    final wanted = creatureRarityForVial(infusion.rarity).toLowerCase();
    final types = infusion.group.elementTypes;
    final eligible = repo.creatures
        .where(
          (c) =>
              c.rarity.toLowerCase() == wanted && c.types.any(types.contains),
        )
        .toList();
    if (eligible.isEmpty) {
      return HatchingResult(
        success: false,
        message: 'No creatures available for this vial type',
        icon: AppIcons.error_rounded,
        color: Colors.red,
      );
    }
    if (await db.incubatorDao.firstFreeSlot() == null &&
        !await ColdStorageService.hasCapacity(db)) {
      return HatchingResult(
        success: false,
        message: await ColdStorageService.buildFullMessage(db),
        icon: AppIcons.inventory_2_rounded,
        color: Colors.orange,
      );
    }
    if (!await pay()) {
      return HatchingResult(
        success: false,
        message: 'Not enough essence',
        icon: AppIcons.error_rounded,
        color: Colors.orange,
      );
    }
    final offspring = eligible[Random().nextInt(eligible.length)];
    final payload = payloadFactory.createVialPayload(
      offspring,
      vialName: infusion.name,
      natureId: infusion.natureId,
      tint: infusion.tint,
      size: infusion.size,
    );
    if (!context.mounted) {
      return HatchingResult(success: false, message: 'Screen was closed');
    }
    return _placeVialEgg(context, offspring, payload, onFull: () async {});
  }

  /// A vial's egg into the first free chamber, or cold storage. [onFull]
  /// gives back what was spent if neither has room.
  static Future<HatchingResult> _placeVialEgg(
    BuildContext context,
    Creature offspring,
    EggPayload payload, {
    required Future<void> Function() onFull,
  }) async {
    final db = context.read<AlchemonsDatabase>();
    final payloadJson = payload.toJsonString();

    final eggId = db.creatureDao.makeInstanceId('EGG');
    final adjustedHatchDelay = _calculateHatchTime(
      context,
      offspring,
      bothParentsFire: false,
    );
    final free = await db.incubatorDao.firstFreeSlot();

    if (free == null) {
      if (!await ColdStorageService.hasCapacity(db)) {
        await onFull();
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
        message: 'Chambers full — specimen moved to cold storage',
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
        message: 'Cultivating in chamber ${free.id + 1}',
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

    return cultivationDuration(
      base: base,
      natureId: offspring.nature?.id,
      nature2Id: offspring.nature2?.id,
      gestationReduction: context
          .read<ConstellationEffectsService>()
          .getGestationReduction(),
      fireMultiplier: context.read<FactionService>().fireBreederTimeMultiplier(
        bothParentsFire: bothParentsFire,
      ),
      halfCultivation: context.read<TimedBoostService>().halfCultivationActive,
    );
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
    bool showPresentation = true,
  }) async {
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();
    // Stats are written at hatch before the lineage has been classified, so a
    // pure specimen would not show its rolled bonus until the next launch
    // without this. Idempotent: it only writes when something differs.
    await context.read<GameDataService>().refreshInstanceStats(instanceId);
    if (!context.mounted) return;

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

    // Clear egg & cache. A cold-storage extraction comes through on
    // performStorageHatching's stand-in slot (id -1): its vial leaves the
    // rack here, before the ceremony, as a chamber's does — not after it,
    // which left it sitting in the rack until the reveal was dismissed.
    if (slot.id < 0 && slot.eggId != null) {
      await db.incubatorDao.removeFromInventory(slot.eggId!);
    } else {
      await db.incubatorDao.clearEgg(slot.id);
    }
    if (slot.resultCreatureId != null) {
      undiscoveredCache.remove(slot.resultCreatureId!);
    }

    final instance = await db.creatureDao.getInstance(instanceId);
    final creature = repo.getCreatureById(instance?.baseId ?? '');

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

    if (!showPresentation) {
      await recipeDiscoveryFuture.catchError(
        (_) => EncyclopediaDiscoveryResult.none,
      );
      return;
    }

    try {
      // ✅ still use the original context for the cinematic if you want
      if (!context.mounted) return;
      // The Blood Ring's vial has its own: the shell melts into blood and
      // the favorite rises out of it.
      final vial = jsonDecode(slot.payloadJson ?? '{}');
      if (vial is Map<String, dynamic> && isBloodbornPayload(vial)) {
        await playBloodbornExtraction(
          context: context,
          payload: vial,
          mutationFamily: family,
          quality: cinematicQuality,
        );
      } else {
        await playHatchingCinematicAlchemy(
          context: context,
          parentATypeId: types.isNotEmpty ? types[0] : offspring.types.first,
          parentBTypeId: types.length > 1 ? types[1] : offspring.types.last,
          // The element being hatched INTO -- the shell fuses both parent
          // palettes into this one at 82% of its arc.
          resultTypeId: offspring.types.isNotEmpty
              ? offspring.types.first
              : null,
          paletteMain: primaryHue,
          creatureSilhouette: silhouette,
          // The shell owns the first 80% of this and its arc is 6.6s, matching
          // the prototype; the remaining 20% is the whiteout and the silhouette
          // reveal. At 6400 the shell's arc was compressed to 5.1s.
          totalDuration: const Duration(milliseconds: kHatchCeremonyMs),
          hintType: hintType,
          variantColor: variantColor,
          pureElementTypeId: pureElementTypeId,
          // Drives which shell architecture the ceremony builds.
          mutationFamily: family,
          mutation: AlchemonMutation.byId(instance?.mutation),
          quality: cinematicQuality,
        );
      }
    } catch (e) {
      // The alchemy cinematic never got far enough to drop the curtain; lift
      // it and go straight to the result.
      HatchCurtain.lower();
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
    if (row.mutation != null) out = out.copyWith(wildMutation: row.mutation);
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

  /// The normal single-extraction result card.
  ///
  /// Public so the batch ceremony can present the SAME card per specimen
  /// instead of growing a second, lesser version of it that drifts. It awaits
  /// its own dialog, so calling it in a loop is what "one at a time" means --
  /// the card's own CTA is the Next button.
  static Future<void> showExtractionResult(
    BuildContext context,
    String instanceId,
    bool isNewDiscovery, {
    required CinematicQuality cinematicQuality,
    void Function(DiscoveryFlight flight)? onDeferDiscoveryFlight,
  }) => _showExtractionResult(
    context,
    instanceId,
    isNewDiscovery,
    cinematicQuality: cinematicQuality,
    onDeferDiscoveryFlight: onDeferDiscoveryFlight,
  );

  static Future<void> _showExtractionResult(
    BuildContext context,
    String instanceId,
    bool isNewDiscovery, {
    required CinematicQuality cinematicQuality,
    void Function(DiscoveryFlight flight)? onDeferDiscoveryFlight,
  }) async {
    final offspring = await _effectiveFromInstance(context, instanceId);
    if (!context.mounted) return;
    final instance = await context
        .read<AlchemonsDatabase>()
        .creatureDao
        .getInstance(instanceId);
    if (instance == null || !context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: kExtractionCardBarrier,
      builder: (_) => ExtractionResultCard(
        species: offspring,
        instance: instance,
        isNewDiscovery: isNewDiscovery,
        cinematicQuality: cinematicQuality,
        onDeferDiscoveryFlight: onDeferDiscoveryFlight,
      ),
    );
    // Here rather than after the single hatch, so the batch ceremony (which
    // shows this same card per specimen) explains it too.
    if (!context.mounted) return;
    await maybeShowFirstMutationExtractionDialog(context, instance: instance);
  }

  // ============================================================================
  // DIALOG UI COMPONENTS
  // ============================================================================

  /// The post-hatch notice that new recipes are in the encyclopedia: the
  /// game's one notice plate ([showGameSnack]), the whole bar opening it.
  static void _showScorchedDiscoveryOverlay(
    BuildContext context, {
    required List<EncyclopediaRecipeEntry> unlocked,
  }) {
    final rootNav = Navigator.of(context, rootNavigator: true);
    final unlockQueue = List<EncyclopediaRecipeEntry>.unmodifiable(unlocked);
    final count = unlockQueue.length;
    showGameSnack(
      context,
      count == 1 ? 'New discovery added' : '$count new discoveries added',
      // Amber, because that is what the encyclopedia it opens is dressed in.
      accent: FC.of(context).amberBright,
      action: SnackBarAction(
        label: 'Encyclopedia',
        onPressed: context.soundTap(
          () => rootNav.push(
            MaterialPageRoute(
              builder: (_) =>
                  AlchemicalEncyclopediaScreen(unlockShowcase: unlockQueue),
            ),
          ),
        ),
      ),
      duration: const Duration(seconds: 4),
      overlay: rootNav.overlay,
    );
  }

  /// The post-hatch notice that a species reached a breeding milestone, on
  /// the same plate, the whole bar opening its progress.
  static void showConstellationMilestoneOverlay(
    BuildContext context, {
    required String speciesId,
    required String speciesName,
    required PendingMilestoneShowcase showcase,
  }) {
    final rootNav = Navigator.of(context, rootNavigator: true);
    // A hundred bred is an effigy for the home biome.
    final effigy = showcase.milestoneCount >= kEffigyBredCount
        ? '. Its effigy waits at home'
        : '';
    showGameSnack(
      context,
      '$speciesName reached ${showcase.milestoneCount} fusions  •  '
      '+${showcase.pointsAwarded} constellation points$effigy',
      accent: FC.blue,
      action: SnackBarAction(
        label: 'Progress',
        onPressed: context.soundTap(
          () => rootNav.push(
            MaterialPageRoute(
              builder: (_) => ConstellationProgressOverviewScreen(
                highlightSpeciesId: speciesId,
              ),
            ),
          ),
        ),
      ),
      duration: const Duration(seconds: 4),
      overlay: rootNav.overlay,
    );
  }
}
