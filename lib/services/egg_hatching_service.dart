import 'dart:convert';
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
import 'package:alchemons/screens/breed/utils/breed_utils.dart';
import 'package:alchemons/screens/breeding_milestones_screen.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/constellation_service.dart';
import 'package:alchemons/services/creature_instance_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/screens/alchemical_encyclopedia_screen.dart';
import 'package:alchemons/services/alchemical_encyclopedia_service.dart';
import 'package:alchemons/services/cinematic_quality_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/utils/nature_utils.dart';
import 'package:alchemons/widgets/animations/breed_result_animation.dart';
import 'package:alchemons/widgets/animations/database_typing_animation.dart';
import 'package:alchemons/widgets/animations/hatching_cinematic.dart';
import 'package:alchemons/widgets/creature_detail/creature_dialog.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:alchemons/widgets/delay_type_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/models/egg/egg_payload.dart';

/// Result of a hatching operation
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

    // Starter branch: exact DB write, no rerolls
    if (hp.source == 'starter') {
      final fb = _fallbackLineageFor(offspring);

      final createdId = await db.creatureDao.insertInstanceFromHatchPayload(
        baseId: hp.baseId,
        payload: hp.toJson(),
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
          icon: Icons.warning_amber_rounded,
          color: Colors.orange.shade600,
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
      genetics: hp.genetics,
      parentage: hp.parentage?.toJson(),
      isPrismaticSkin: hp.isPrismaticSkin,
      likelihoodAnalysisJson: hp.likelihoodAnalysisJson,
      source: hp.source,
      statBeauty: hp.stats.beauty,
      statSpeed: hp.stats.speed,
      statIntelligence: hp.stats.intelligence,
      statStrength: hp.stats.strength,
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
        icon: Icons.warning_amber_rounded,
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

    // Consume the vial first
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
        icon: Icons.error_rounded,
        color: Colors.red,
      );
    }

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
        icon: Icons.error_rounded,
        color: Colors.red,
      );
    }

    // Pick a random creature
    final offspring =
        eligibleCreatures[Random().nextInt(eligibleCreatures.length)];

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
    // Try to place in incubator
    final free = await db.incubatorDao.firstFreeSlot();

    if (free == null) {
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
        icon: Icons.inventory_2_rounded,
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
        icon: Icons.science_rounded,
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
    final natureMult = hatchMultForNature(offspring.nature?.id);

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
        totalDuration: const Duration(milliseconds: 4200), // Faster!
        hintType: hintType,
        variantColor: variantColor,
        quality: cinematicQuality,
      );
    } catch (e) {
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

    bool scanComplete = false;
    bool ctaVisible = false;
    bool ctaTouchable = false;
    bool closing = false;

    // GlobalKey to control the animation
    final scanAnimationKey = GlobalKey<CreatureScanAnimationState>();

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

    if (!context.mounted) return;
    final media = MediaQuery.of(context);
    final shortestSide = media.size.shortestSide;
    final lowFxDevice = media.disableAnimations || shortestSide < 430;
    final dialogBlurSigma = switch (cinematicQuality) {
      CinematicQuality.high => lowFxDevice ? 0.0 : 14.0,
      CinematicQuality.balanced => lowFxDevice ? 0.0 : 8.0,
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: dialogShell(
                Container(
                  width: MediaQuery.of(context).size.width * 0.95,
                  height: MediaQuery.of(context).size.height * 0.82,
                  decoration: BoxDecoration(
                    color: fc.bg0.withValues(alpha: .7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: .45),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildExtractionHeader(offspring, primaryColor, fc),

                      // Sprite dock
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: fc.bg2,
                          border: Border(
                            bottom: BorderSide(color: fc.borderDim),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              children: [
                                Container(
                                  height: 200,
                                  width: 200,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: fc.bg1,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: fc.borderDim),
                                  ),
                                  child: CreatureScanAnimation(
                                    key: scanAnimationKey,
                                    isNewDiscovery: isNewDiscovery,
                                    scanDuration: switch (cinematicQuality) {
                                      CinematicQuality.high => const Duration(
                                        milliseconds: 1400,
                                      ),
                                      CinematicQuality.balanced =>
                                        const Duration(milliseconds: 1800),
                                    },
                                    onReadyChanged: (ready) {
                                      if (ready) {
                                        safeSetDialogState(setDialogState, () {
                                          scanComplete = true;
                                          ctaVisible =
                                              true; // Show button right away
                                        });
                                      }
                                    },
                                    child: InstanceSprite(
                                      creature: offspring,
                                      instance: instance!,
                                      size: 150,
                                    ),
                                  ),
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
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Content
                      Expanded(
                        child: TickerMode(
                          enabled: !closing,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              children: [
                                DatabaseTypingAnimation(
                                  startAnimation: scanComplete,
                                  delayBetweenItems: const Duration(
                                    milliseconds: 100,
                                  ),
                                  onComplete: () {
                                    // Typing done - button already visible
                                  },
                                  children: [
                                    _buildAnalysisSection(
                                      'SPECIMEN ANALYSIS',
                                      primaryColor,
                                      [
                                        _buildTypingAnalysisRow(
                                          'CLASSIFICATION',
                                          offspring.rarity,
                                          scanComplete,
                                          primaryColor,
                                          fc: fc,
                                        ),
                                        _buildTypingAnalysisRow(
                                          'TYPE CATEGORIES',
                                          offspring.types.join(', '),
                                          scanComplete,
                                          primaryColor,
                                          delay: const Duration(
                                            milliseconds: 300,
                                          ),
                                          fc: fc,
                                        ),
                                        if (offspring.description.isNotEmpty)
                                          _buildTypingAnalysisRow(
                                            'NOTES',
                                            offspring.description,
                                            scanComplete,
                                            primaryColor,
                                            delay: const Duration(
                                              milliseconds: 600,
                                            ),
                                            fc: fc,
                                          ),
                                      ],
                                      fc,
                                    ),
                                    const SizedBox(height: 15),
                                    _buildAnalysisSection(
                                      'GENETIC PROFILE',
                                      primaryColor,
                                      [
                                        _buildTypingAnalysisRow(
                                          'SIZE VARIANT',
                                          _getSizeName(offspring),
                                          scanComplete,
                                          primaryColor,
                                          fc: fc,
                                        ),
                                        _buildTypingAnalysisRow(
                                          'PIGMENTATION',
                                          _getTintName(offspring),
                                          scanComplete,
                                          primaryColor,
                                          delay: const Duration(
                                            milliseconds: 300,
                                          ),
                                          fc: fc,
                                        ),
                                        if (offspring.nature != null)
                                          _buildTypingAnalysisRow(
                                            'BEHAVIOR',
                                            offspring.nature!.id,
                                            scanComplete,
                                            primaryColor,
                                            delay: const Duration(
                                              milliseconds: 600,
                                            ),
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
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Docked CTA
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: fc.bg2,
                          border: Border(top: BorderSide(color: fc.borderDim)),
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
                                    onTap: () {
                                      if (closing) return;

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

                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            if (Navigator.of(
                                              context,
                                            ).canPop()) {
                                              Navigator.of(context).pop();
                                            }
                                          });
                                    },

                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 22,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            primaryColor.withValues(alpha: .95),
                                            primaryColor.withValues(alpha: .8),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: fc.borderDim),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.check_rounded,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'EXTRACTION CONFIRMED',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13,
                                              letterSpacing: .6,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () {
                                    if (closing) return;

                                    CreatureDetailsDialog.show(
                                      context,
                                      offspring,
                                      true,
                                      instanceId: instanceId,
                                    );
                                  },
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: fc.bg2,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: fc.borderDim,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.info_outline_rounded,
                                      color: fc.textSecondary,
                                      size: 22,
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
              ),
            ),
          );
        },
      ),
    );
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
              onTap: openEncyclopedia,
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
                        Icons.menu_book_rounded,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .45)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 7,
          fontWeight: FontWeight.w900,
          letterSpacing: .5,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: prismaticColors.map((c) => c.withValues(alpha: .15)).toList(),
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: .4)),
      ),
      child: ShaderMask(
        shaderCallback: (bounds) =>
            LinearGradient(colors: prismaticColors).createShader(bounds),
        child: const Text(
          'PRISMATIC',
          style: TextStyle(
            color: Colors.white,
            fontSize: 7,
            fontWeight: FontWeight.w900,
            letterSpacing: .5,
          ),
        ),
      ),
    );
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
              onTap: openProgress,
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
                        Icons.auto_awesome_rounded,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fc.bg2,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: Border(bottom: BorderSide(color: fc.borderDim)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.science_rounded, color: primaryColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'EXTRACTION COMPLETE',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: .6,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            offspring.name,
            style: TextStyle(
              color: fc.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: .3,
            ),
            textAlign: TextAlign.center,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.dataset_outlined, color: primaryColor, size: 16),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: fc.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: .6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: fc.bg1,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: fc.borderDim),
          ),
          child: Column(children: children),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: fc.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: .4,
              ),
            ),
          ),
          Expanded(
            child: startTyping
                ? DelayedTypingText(
                    text: value,
                    delay: delay,
                    style: TextStyle(
                      color: fc.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
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
      variantType,
      startTyping,
      primaryColor,
      delay: const Duration(milliseconds: 900),
      fc: fc,
    );
  }

  static String _getSizeName(Creature c) =>
      sizeLabels[c.genetics?.get('size') ?? 'normal'] ?? 'Standard';

  static String _getTintName(Creature c) =>
      tintLabels[c.genetics?.get('tinting') ?? 'normal'] ?? 'Standard';
}
