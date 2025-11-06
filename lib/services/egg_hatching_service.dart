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
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/providers/app_providers.dart';
import 'package:alchemons/screens/breed/utils/breed_utils.dart';
import 'package:alchemons/screens/creatures_screen.dart';
import 'package:alchemons/services/breeding_engine.dart';
import 'package:alchemons/services/creature_instance_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/animations/breed_result_animation.dart';
import 'package:alchemons/widgets/animations/database_typing_animation.dart';
import 'package:alchemons/widgets/animations/hatching_cinematic.dart';
import 'package:alchemons/widgets/creature_dialog.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/delay_type_widget.dart';
import 'package:flame/extensions.dart';
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
    if ((hp.source ?? '') == 'starter') {
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

      await _afterHatchCommon(
        context: context,
        slot: slot,
        instanceId: createdId,
        offspring: offspring,
        isNewDiscovery: isNewDiscovery,
        undiscoveredCache: undiscoveredCache,
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
        color: Colors.orange.shade600,
      );
    }

    final instanceId = result.instanceId;
    if (instanceId == null || instanceId.isEmpty) {
      return HatchingResult.failure(
        'Extraction failed: system error',
        color: Colors.red.shade600,
      );
    }

    await _afterHatchCommon(
      context: context,
      slot: slot,
      instanceId: instanceId,
      offspring: offspring,
      isNewDiscovery: isNewDiscovery,
      undiscoveredCache: undiscoveredCache,
    );
    return HatchingResult.success();
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
    final payload = payloadFactory.createVialPayload(offspring);
    final payloadJson = payload.toJsonString();

    final eggId = db.creatureDao.makeInstanceId('EGG');
    final adjustedHatchDelay = _calculateHatchTime(rarity);

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
        message: 'Incubator full — embryo transferred to storage',
        icon: Icons.inventory_2_rounded,
        color: Colors.orange,
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
        message: 'Embryo placed in incubation chamber ${free.id + 1}',
        icon: Icons.science_rounded,
        color: const Color.fromARGB(255, 239, 255, 92),
      );
    }
  }

  // Helper for hatch time calculation
  static Duration _calculateHatchTime(String rarity) {
    return switch (rarity.toLowerCase()) {
      'common' => Duration(hours: 1),
      'uncommon' => Duration(hours: 2),
      'rare' => Duration(hours: 4),
      'legendary' => Duration(hours: 6),
      'mythic' => Duration(hours: 8),
      _ => Duration(hours: 2),
    };
  }
  // ============================================================================
  // PRIVATE HELPERS
  // ============================================================================

  /// Pick a random creature from the elemental group
  static Creature? _pickRandomCreatureFromGroup(
    CreatureCatalog repo,
    ElementalGroup group,
    String? fixedRarity,
  ) {
    final allCreatures = repo.creatures;

    // Filter by group
    final inGroup = allCreatures.where((c) {
      return c.types.any((type) => elementalGroupOf(c) == group);
    }).toList();

    if (inGroup.isEmpty) return null;

    // Filter by rarity if specified
    final candidates = fixedRarity != null
        ? inGroup
              .where((c) => c.rarity.toLowerCase() == fixedRarity.toLowerCase())
              .toList()
        : inGroup;

    if (candidates.isEmpty) return null;

    // Pick random
    final rng = Random();
    return candidates[rng.nextInt(candidates.length)];
  }

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

  static Future<void> _afterHatchCommon({
    required BuildContext context,
    required IncubatorSlot slot,
    required String instanceId,
    required Creature offspring,
    required bool isNewDiscovery,
    required Map<String, bool> undiscoveredCache,
  }) async {
    final db = context.read<AlchemonsDatabase>();

    // Clear egg & cache
    await db.incubatorDao.clearEgg(slot.id);
    if (slot.resultCreatureId != null) {
      undiscoveredCache.remove(slot.resultCreatureId!);
    }

    final instance = await db.creatureDao.getInstance(instanceId);

    // Particle-driven cinematic (shared)
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
    if (p1Types != null && p1Types.isNotEmpty)
      types.add(p1Types.first.toString());
    if (p2Types != null && p2Types.isNotEmpty)
      types.add(p2Types.first.toString());

    final Color primaryHue = BreedConstants.getRarityColor(offspring.rarity);
    ImageProvider? silhouette = const AssetImage(
      'assets/images/creatures/legendary/WNG04_airwing.png',
    );

    try {
      await playHatchingCinematicAlchemy(
        context: context,
        parentATypeId: types.isNotEmpty ? types[0] : offspring.types.first,
        parentBTypeId: types.length > 1 ? types[1] : offspring.types.last,
        paletteMain: primaryHue,
        creatureSilhouette: silhouette,
        totalDuration: const Duration(milliseconds: 8000),
      );
    } catch (e) {
      final factionSvc = context.read<FactionService>();
      final faction = factionSvc.current;
      await playHatchCinematic(
        context,
        'assets/animations/egg_hatch.json',
        palette,
        faction,
      );
    }

    await _showExtractionResult(context, instanceId, isNewDiscovery);
  }

  /// Extract and normalize lineage data from payload
  static ({
    int generationDepth,
    Map<String, int> factionLineage,
    Map<String, int> elementLineage,
    Map<String, int> familyLineage,
    String? variantFaction,
    bool isPure,
  })
  _extractLineage(Map<String, dynamic>? payload, Creature offspring) {
    // Support both nested payload['lineage'] and flat form
    Map<String, dynamic>? lineageBlock;
    final rawLineage = payload?['lineage'];
    if (rawLineage is Map) {
      lineageBlock = rawLineage.cast<String, dynamic>();
    } else {
      lineageBlock = payload;
    }

    // Helper to convert values to int
    int? _asInt(dynamic v) => (v is num) ? v.toInt() : null;

    // Helper to normalize lineage maps
    Map<String, int>? _normalizeLineageMap(dynamic raw) {
      if (raw is! Map) return null;
      final m = <String, int>{};
      raw.forEach((k, v) {
        var key = k.toString();

        // Legacy enum-style keys like "CreatureFamily.let" -> "Let"
        if (key.startsWith('CreatureFamily.')) {
          final tail = key.split('.').last;
          key = tail.isEmpty
              ? 'Unknown'
              : (tail[0].toUpperCase() + tail.substring(1));
        }

        final vv = (v is num)
            ? v.toInt()
            : (v is String ? int.tryParse(v) ?? 0 : 0);

        if (vv > 0) m[key] = vv;
      });
      return m;
    }

    final payloadDepth = _asInt(lineageBlock?['generationDepth']);
    final payloadVariantFaction = (lineageBlock?['variantFaction'] as String?);
    final payloadIsPure = (lineageBlock?['isPure'] as bool?);

    final payloadFactionLineage = _normalizeLineageMap(
      lineageBlock?['factionLineage'],
    );
    final payloadElementLineage = _normalizeLineageMap(
      lineageBlock?['elementLineage'],
    );
    final payloadFamilyLineage = _normalizeLineageMap(
      lineageBlock?['familyLineage'],
    );

    // Choose lineage: trust payload when present; otherwise synthesize fallback
    if (payloadDepth != null && (payloadFactionLineage?.isNotEmpty ?? false)) {
      // TRUST PAYLOAD
      return (
        generationDepth: payloadDepth,
        factionLineage: payloadFactionLineage!,
        variantFaction: payloadVariantFaction,
        isPure: payloadIsPure ?? false,
        elementLineage: payloadElementLineage?.isNotEmpty ?? false
            ? payloadElementLineage!
            : _fallbackLineageFor(offspring).elementLineage,
        familyLineage: payloadFamilyLineage?.isNotEmpty ?? false
            ? payloadFamilyLineage!
            : _fallbackLineageFor(offspring).familyLineage,
      );
    } else {
      // FALLBACK (wild/legacy eggs)
      final fb = _fallbackLineageFor(offspring);
      return (
        generationDepth: fb.generationDepth,
        factionLineage: fb.factionLineage,
        variantFaction: fb.variantFaction,
        isPure: fb.isPure,
        elementLineage: fb.elementLineage,
        familyLineage: fb.familyLineage,
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
        if (f == null) return null;
        return f.toString();
      } catch (_) {
        return null;
      }
    }

    final native = nativeGroupName();
    final elem = primaryElement();
    final fam = familyId();

    // Wild founder
    const depth = 1;

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
    bool isNewDiscovery,
  ) async {
    final offspring = await _effectiveFromInstance(context, instanceId);

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

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.95,
                  height: MediaQuery.of(context).size.height * 0.82,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: primaryColor.withOpacity(.45),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(.18),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildExtractionHeader(offspring, primaryColor),

                      // Sprite dock
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.03),
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withOpacity(.08),
                            ),
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
                                    color: Colors.white.withOpacity(.02),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(.12),
                                    ),
                                  ),
                                  child: CreatureScanAnimation(
                                    key: scanAnimationKey,
                                    isNewDiscovery: isNewDiscovery,
                                    scanDuration: const Duration(
                                      milliseconds: 3000,
                                    ),
                                    onReadyChanged: (ready) {
                                      if (ready) {
                                        safeSetDialogState(
                                          setDialogState,
                                          () => scanComplete = true,
                                        );
                                      }
                                    },
                                    child: InstanceSprite(
                                      creature: offspring,
                                      instance: instance!,
                                      size: 72,
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
                                        Colors.tealAccent,
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
                                        Colors.purpleAccent,
                                      ),
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
                                    milliseconds: 800,
                                  ),
                                  onComplete: () {
                                    safeSetDialogState(setDialogState, () {
                                      ctaVisible = true;
                                      ctaTouchable = false;
                                    });
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
                                        ),
                                        _buildTypingAnalysisRow(
                                          'TYPE CATEGORIES',
                                          offspring.types.join(', '),
                                          scanComplete,
                                          primaryColor,
                                          delay: const Duration(
                                            milliseconds: 300,
                                          ),
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
                                          ),
                                      ],
                                    ),
                                    _buildAnalysisSection(
                                      'GENETIC PROFILE',
                                      primaryColor,
                                      [
                                        _buildTypingAnalysisRow(
                                          'SIZE VARIANT',
                                          _getSizeName(offspring),
                                          scanComplete,
                                          primaryColor,
                                        ),
                                        _buildTypingAnalysisRow(
                                          'PIGMENTATION',
                                          _getTintName(offspring),
                                          scanComplete,
                                          primaryColor,
                                          delay: const Duration(
                                            milliseconds: 300,
                                          ),
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
                                          ),
                                        if (offspring.isPrismaticSkin == true)
                                          _buildTypingAnalysisRow(
                                            'SPECIAL TRAIT',
                                            'PRISMATIC PHENOTYPE',
                                            scanComplete,
                                            primaryColor,
                                            delay: const Duration(
                                              milliseconds: 900,
                                            ),
                                          ),
                                        _buildVariantTypingRow(
                                          context,
                                          instanceId,
                                          scanComplete,
                                          primaryColor,
                                        ),
                                      ],
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
                          color: Colors.black.withOpacity(.2),
                          border: Border(
                            top: BorderSide(
                              color: Colors.white.withOpacity(.08),
                            ),
                          ),
                        ),
                        child: AnimatedOpacity(
                          opacity: ctaVisible ? 1 : 0,
                          duration: const Duration(milliseconds: 450),
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

                                      // Update state to stop all tickers/animations
                                      setDialogState(() {
                                        closing = true;
                                        ctaTouchable = false;
                                      });

                                      // Pop on next frame after state updates
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
                                            primaryColor.withOpacity(.95),
                                            primaryColor.withOpacity(.8),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(.18),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: primaryColor.withOpacity(
                                              .25,
                                            ),
                                            blurRadius: 12,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
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
                                      color: Colors.white.withOpacity(.08),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(.25),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.pets_rounded,
                                      color: Colors.white.withOpacity(.9),
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

  static Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(.45)),
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

  static Widget _buildExtractionHeader(Creature offspring, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.03),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(.08)),
        ),
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
            style: const TextStyle(
              color: Color(0xFFE8EAED),
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
              style: const TextStyle(
                color: Color(0xFFE8EAED),
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
            color: Colors.black.withOpacity(.25),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(.12)),
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
                color: Colors.white.withOpacity(.6),
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
                    style: const TextStyle(
                      color: Color(0xFFE8EAED),
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
    BuildContext context,
    String instanceId,
    bool startTyping,
    Color primaryColor,
  ) {
    return FutureBuilder<CreatureInstance?>(
      future: context.read<AlchemonsDatabase>().creatureDao.getInstance(
        instanceId,
      ),
      builder: (context, snap) {
        if (!snap.hasData || snap.data == null) {
          return const SizedBox.shrink();
        }

        final inst = snap.data!;
        final isVariant =
            inst.variantFaction != null && inst.variantFaction!.isNotEmpty;
        if (!isVariant) return const SizedBox.shrink();

        final variantType = inst.variantFaction!;

        return _buildTypingAnalysisRow(
          'VARIANT FACTION',
          variantType,
          startTyping,
          primaryColor,
          delay: const Duration(milliseconds: 900),
        );
      },
    );
  }

  static String _getSizeName(Creature c) =>
      sizeLabels[c.genetics?.get('size') ?? 'normal'] ?? 'Standard';

  static String _getTintName(Creature c) =>
      tintLabels[c.genetics?.get('tinting') ?? 'normal'] ?? 'Standard';
}
