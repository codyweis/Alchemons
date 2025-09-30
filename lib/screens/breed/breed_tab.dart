import 'dart:convert';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/screens/feeding_screen.dart';
import 'package:alchemons/services/creature_instance_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/likelihood_analyzer.dart';
import 'package:alchemons/utils/nature_utils.dart';
import 'package:alchemons/widgets/creature_instances_sheet.dart';
import 'package:alchemons/widgets/creature_selection_sheet.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/alchemons_db.dart';
import '../../models/creature.dart';
import '../../providers/app_providers.dart';
import '../../services/breeding_engine.dart';
import '../../services/creature_repository.dart';
import '../../services/game_data_service.dart';

class BreedingTab extends StatefulWidget {
  final List<Map<String, dynamic>> discoveredCreatures;
  final VoidCallback onBreedingComplete;

  const BreedingTab({
    super.key,
    required this.discoveredCreatures,
    required this.onBreedingComplete,
  });

  @override
  State<BreedingTab> createState() => _BreedingTabState();
}

class _BreedingTabState extends State<BreedingTab> {
  CreatureInstance? selectedParent1;
  CreatureInstance? selectedParent2;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildBreedingSlots(),
          const SizedBox(height: 16),
          _buildBreedButton(),
        ],
      ),
    );
  }

  Widget _buildBreedingSlots() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.merge_type_rounded,
                color: Colors.indigo.shade600,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Genetic Combination Protocol',
                style: TextStyle(
                  color: Colors.indigo.shade700,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildBreedingSlot(
                selectedParent1,
                'Specimen A',
                () => _showCreatureSelection(1),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: Colors.blue.shade600,
                  size: 16,
                ),
              ),
              _buildBreedingSlot(
                selectedParent2,
                'Specimen B',
                () => _showCreatureSelection(2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreedingSlot(
    CreatureInstance? inst,
    String placeholder,
    VoidCallback onTap,
  ) {
    final repo = context.read<CreatureRepository>();
    Creature? base = inst != null ? repo.getCreatureById(inst.baseId) : null;

    final genetics = decodeGenetics(inst?.geneticsJson);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: base != null
              ? BreedConstants.getTypeColor(base.types.first).withOpacity(0.1)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: base != null
                ? BreedConstants.getTypeColor(base.types.first)
                : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: base != null
                  ? BreedConstants.getTypeColor(
                      base.types.first,
                    ).withOpacity(0.2)
                  : Colors.grey.shade200,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: base != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    // CreatureSprite(
                    //           spritePath: effectiveCreature!
                    //               .spriteData!
                    //               .spriteSheetPath,
                    //           totalFrames:
                    //               effectiveCreature.spriteData!.totalFrames,
                    //           rows: effectiveCreature.spriteData!.rows,
                    //           scale: scaleFromGenes(effectiveCreature.genetics),
                    //           saturation: satFromGenes(
                    //             effectiveCreature.genetics,
                    //           ),
                    //           brightness: briFromGenes(
                    //             effectiveCreature.genetics,
                    //           ),
                    //           hueShift: hueFromGenes(
                    //             effectiveCreature.genetics,
                    //           ),
                    //           isPrismatic: effectiveCreature.isPrismaticSkin,
                    //           frameSize: Vector2(
                    //             effectiveCreature.spriteData!.frameWidth * 1.0,
                    //             effectiveCreature.spriteData!.frameHeight * 1.0,
                    //           ),
                    //           stepTime:
                    //               (effectiveCreature
                    //                   .spriteData!
                    //                   .frameDurationMs /
                    //               1000.0),
                    //         )
                    child: base.spriteData != null && inst != null
                        ? CreatureSprite(
                            spritePath: base.spriteData!.spriteSheetPath,
                            totalFrames: base.spriteData!.totalFrames,
                            rows: base.spriteData!.rows,
                            frameSize: Vector2(
                              base.spriteData!.frameWidth * 1.0,
                              base.spriteData!.frameHeight * 1.0,
                            ),
                            stepTime:
                                (base.spriteData!.frameDurationMs / 1000.0),
                            scale: scaleFromGenes(genetics),
                            saturation: satFromGenes(genetics),
                            brightness: briFromGenes(genetics),
                            hueShift: hueFromGenes(genetics),
                            isPrismatic: inst.isPrismaticSkin,
                          )
                        : Icon(
                            Icons.image_not_supported_rounded,
                            color: Colors.grey.shade400,
                            size: 24,
                          ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    base.name,
                    style: TextStyle(
                      color: Colors.indigo.shade700,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_circle_outline_rounded,
                    color: Colors.grey.shade400,
                    size: 24,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    placeholder,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBreedButton() {
    final canBreed = selectedParent1 != null && selectedParent2 != null;

    return GestureDetector(
      onTap: canBreed ? _performBreeding : null,
      child: Container(
        width: double.infinity,
        height: 45,
        decoration: BoxDecoration(
          color: canBreed ? Colors.indigo.shade600 : Colors.grey.shade400,
          borderRadius: BorderRadius.circular(8),
          boxShadow: canBreed
              ? [
                  BoxShadow(
                    color: Colors.indigo.shade200,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.merge_type_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                'INITIATE GENETIC FUSION',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _performBreeding() async {
    if (selectedParent1 == null || selectedParent2 == null) return;

    // 1) Pre-check stamina BEFORE opening the dialog
    final stamina = context.read<StaminaService>();
    final id1 = selectedParent1!.instanceId;
    final id2 = selectedParent2!.instanceId;
    final ok1 = await stamina.canBreed(id1);
    final ok2 = await stamina.canBreed(id2);
    if (!ok1 || !ok2) {
      _showToast(
        !ok1 && !ok2
            ? 'Both specimens are resting'
            : (!ok1 ? 'Specimen A is resting' : 'Specimen B is resting'),
        icon: Icons.hourglass_bottom_rounded,
        color: Colors.orange.shade600,
      );
      return;
    }

    // 2) Proceed with breeding
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Container(
          color: Colors.indigo.shade50.withOpacity(0.3),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.indigo.shade200,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.indigo.shade600,
                    ),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Processing Genetic Fusion...',
                    style: TextStyle(
                      color: Colors.indigo.shade700,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final breedingEngine = context.read<BreedingEngine>();
      final db = context.read<AlchemonsDatabase>();
      final repo = context.read<CreatureRepository>();
      final factions = context.read<FactionService>();
      final firePerk2 = await factions.perk2Active();

      final breedingResult = breedingEngine.breedInstances(
        selectedParent1!,
        selectedParent2!,
      );

      if (!breedingResult.success || breedingResult.creature == null) {
        _showToast(
          'Genetic incompatibility detected',
          icon: Icons.warning_rounded,
          color: Colors.orange.shade600,
        );
        return;
      }

      final resultWithJustification = breedingEngine
          .breedInstancesWithJustification(selectedParent1!, selectedParent2!);

      if (!resultWithJustification.success ||
          resultWithJustification.result.creature == null) {
        _showToast(
          'Genetic incompatibility detected',
          icon: Icons.warning_rounded,
          color: Colors.orange.shade600,
        );
        return;
      }

      // Store justification data
      String? analysisJson;
      if (resultWithJustification.justification != null) {
        analysisJson = jsonEncode(
          resultWithJustification.justification!.toJson(),
        );
      }

      final offspring = resultWithJustification.result.creature!;

      final hasFireParent =
          repo
                  .getCreatureById(selectedParent1!.baseId)
                  ?.types
                  .contains('Fire') ==
              true ||
          repo
                  .getCreatureById(selectedParent2!.baseId)
                  ?.types
                  .contains('Fire') ==
              true;

      final fireMult = factions.fireHatchTimeMultiplier(
        hasFireParent: hasFireParent,
        perk2: firePerk2,
      );

      final rarityKey = offspring.rarity.toLowerCase();
      final baseHatchDelay =
          BreedConstants.rarityHatchTimes[rarityKey] ??
          const Duration(minutes: 10);

      final hatchMult = hatchMultForNature(offspring.nature?.id);
      final adjustedHatchDelay = Duration(
        milliseconds: (baseHatchDelay.inMilliseconds * hatchMult * fireMult)
            .round(),
      );

      final payload = {
        'baseId': offspring.id,
        'rarity': offspring.rarity,
        'natureId': offspring.nature?.id,
        'genetics': offspring.genetics?.variants ?? <String, String>{},
        'parentage': offspring.parentage?.toJson(),
        'isPrismaticSkin': offspring.isPrismaticSkin,
        'likelihoodAnalysis': analysisJson,
      };
      final payloadJson = jsonEncode(payload);

      final free = await db.firstFreeSlot();
      final eggId = 'egg_${DateTime.now().millisecondsSinceEpoch}';

      if (free == null) {
        await db.enqueueEgg(
          eggId: eggId,
          resultCreatureId: offspring.id,
          bonusVariantId: breedingResult.variantUnlocked?.id,
          rarity: offspring.rarity,
          remaining: adjustedHatchDelay,
          payloadJson: payloadJson,
        );
        _showToast(
          'Incubator full — specimen transferred to storage',
          icon: Icons.inventory_2_rounded,
          color: Colors.orange.shade600,
        );
      } else {
        final hatchAtUtc = DateTime.now().toUtc().add(adjustedHatchDelay);
        await db.placeEgg(
          slotId: free.id,
          eggId: eggId,
          resultCreatureId: offspring.id,
          bonusVariantId: breedingResult.variantUnlocked?.id,
          rarity: offspring.rarity,
          hatchAtUtc: hatchAtUtc,
          payloadJson: payloadJson,
        );
        _showToast(
          'Embryo placed in incubation chamber ${free.id + 1}',
          icon: Icons.science_rounded,
          color: Colors.green.shade600,
        );
      }

      final waterPerk1 = factions.perk1Active && factions.isWater();
      final bothParentsWater =
          repo
                  .getCreatureById(selectedParent1!.baseId)
                  ?.types
                  .contains('Water') ==
              true &&
          repo
                  .getCreatureById(selectedParent2!.baseId)
                  ?.types
                  .contains('Water') ==
              true;

      final skipStamina = factions.waterSkipBreedStamina(
        bothWater: bothParentsWater,
        perk1: waterPerk1,
      );

      if (!skipStamina) {
        // 3) Deduct stamina AFTER success
        await stamina.spendForBreeding(id1);
        await stamina.spendForBreeding(id2);
      }

      if (!mounted) return;
      setState(() {
        selectedParent1 = null;
        selectedParent2 = null;
      });
      widget.onBreedingComplete();
    } catch (e) {
      _showToast(
        'Fusion protocol error: $e',
        color: Colors.red.shade600,
        icon: Icons.error_rounded,
      );
    } finally {
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop(); // always close spinner
      }
    }
  }

  void _showCreatureSelection(int slotNumber) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return CreatureSelectionSheet(
              scrollController: scrollController,
              discoveredCreatures: widget.discoveredCreatures,
              onSelectCreature: (creatureId) async {
                Navigator.pop(context);
                final repo = context.read<CreatureRepository>();
                final species = repo.getCreatureById(creatureId);
                if (species == null) return;
                _showInstancePicker(slotNumber, species);
              },
            );
          },
        );
      },
    );
  }

  // In your BreedingTab class, update this method:
  void _showInstancePicker(int slotNumber, Creature species) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return InstancesSheet(
          species: species,
          selectedInstanceId1: selectedParent1?.instanceId,
          selectedInstanceId2: selectedParent2?.instanceId,
          onTap: (CreatureInstance inst) async {
            // Capture the service before the async gap
            final stamina = context.read<StaminaService>();

            // Refresh & check (so UI is always up-to-date)
            final refreshed = await stamina.refreshAndGet(inst.instanceId);
            final canUse = (refreshed?.staminaBars ?? 0) >= 1;

            if (!canUse) {
              // Optional: compute ETA to next bar (quick + friendly)
              final perBar = stamina.regenPerBar;
              final now = DateTime.now().toUtc().millisecondsSinceEpoch;
              final last = refreshed?.staminaLastUtcMs ?? now;
              final elapsed = now - last;
              final remMs =
                  perBar.inMilliseconds - (elapsed % perBar.inMilliseconds);
              final mins = (remMs / 60000).ceil();

              if (!mounted) return;
              _showToast(
                'Specimen is resting — next stamina in ~${mins}m',
                icon: Icons.hourglass_bottom_rounded,
                color: Colors.orange.shade600,
                fromTop: true,
              );
              return; // do NOT select
            }

            if (!mounted) return;
            Navigator.of(context).pop();
            _selectInstance(inst, slotNumber);
          },
        );
      },
    );
  }

  void _selectInstance(CreatureInstance inst, int slotNumber) {
    setState(() {
      if (slotNumber == 1) {
        if (selectedParent2?.instanceId != inst.instanceId) {
          selectedParent1 = inst;
        }
      } else {
        if (selectedParent1?.instanceId != inst.instanceId) {
          selectedParent2 = inst;
        }
      }
    });
  }

  void _showToast(
    String message, {
    IconData icon = Icons.info_rounded,
    Color? color,
    bool fromTop = false, // <-- new param
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        elevation: 100,
        backgroundColor: color ?? Colors.indigo.shade600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: fromTop
            ? const EdgeInsets.only(top: 24, left: 16, right: 16)
            : null,
      ),
    );
  }
}
