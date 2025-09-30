import 'dart:convert';
import 'dart:ui';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/screens/feeding_screen.dart';
import 'package:alchemons/services/creature_instance_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
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
    final factionSvc = context.read<FactionService>();
    final currentFaction = factionSvc.current;
    final factionColors = getFactionColors(currentFaction);
    final primaryColor = factionColors.$1;
    final secondaryColor = factionColors.$2;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildBreedingSlots(primaryColor, secondaryColor),
          const SizedBox(height: 16),
          _buildBreedButton(primaryColor, secondaryColor),
        ],
      ),
    );
  }

  Widget _buildBreedingSlots(Color primaryColor, Color secondaryColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryColor.withOpacity(.35)),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(.18),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.merge_type_rounded, color: primaryColor, size: 18),
                  const SizedBox(width: 10),
                  const Text(
                    'GENETIC COMBINATION PROTOCOL',
                    style: TextStyle(
                      color: Color(0xFFE8EAED),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildBreedingSlot(
                    selectedParent1,
                    'SPECIMEN A',
                    () => _showCreatureSelection(1),
                    primaryColor,
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primaryColor.withOpacity(.2),
                          secondaryColor.withOpacity(.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: primaryColor.withOpacity(.4)),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      color: primaryColor,
                      size: 18,
                    ),
                  ),
                  _buildBreedingSlot(
                    selectedParent2,
                    'SPECIMEN B',
                    () => _showCreatureSelection(2),
                    primaryColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreedingSlot(
    CreatureInstance? inst,
    String placeholder,
    VoidCallback onTap,
    Color primaryColor,
  ) {
    final repo = context.read<CreatureRepository>();
    Creature? base = inst != null ? repo.getCreatureById(inst.baseId) : null;
    final genetics = decodeGenetics(inst?.geneticsJson);

    final borderColor = base != null
        ? BreedConstants.getTypeColor(base.types.first).withOpacity(.5)
        : Colors.white.withOpacity(.2);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: base != null
              ? BreedConstants.getTypeColor(base.types.first).withOpacity(0.08)
              : Colors.white.withOpacity(.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: base != null
              ? [
                  BoxShadow(
                    color: BreedConstants.getTypeColor(
                      base.types.first,
                    ).withOpacity(0.2),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: base != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
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
                              color: Colors.white.withOpacity(.3),
                              size: 28,
                            ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                    child: Text(
                      base.name.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFE8EAED),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_circle_outline_rounded,
                    color: Colors.white.withOpacity(.3),
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    placeholder,
                    style: TextStyle(
                      color: const Color(0xFFB6C0CC),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBreedButton(Color primaryColor, Color secondaryColor) {
    final canBreed = selectedParent1 != null && selectedParent2 != null;

    return GestureDetector(
      onTap: canBreed ? _performBreeding : null,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: canBreed
              ? LinearGradient(
                  colors: [
                    primaryColor.withOpacity(.9),
                    secondaryColor.withOpacity(.9),
                  ],
                )
              : null,
          color: canBreed ? null : Colors.white.withOpacity(.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: canBreed
                ? primaryColor.withOpacity(.5)
                : Colors.white.withOpacity(.2),
            width: 2,
          ),
          boxShadow: canBreed
              ? [BoxShadow(color: primaryColor.withOpacity(.3), blurRadius: 12)]
              : null,
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.merge_type_rounded,
                color: canBreed
                    ? Colors.white
                    : const Color(0xFFB6C0CC).withOpacity(.5),
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'INITIATE GENETIC FUSION',
                style: TextStyle(
                  color: canBreed
                      ? Colors.white
                      : const Color(0xFFB6C0CC).withOpacity(.5),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
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

    final factionSvc = context.read<FactionService>();
    final currentFaction = factionSvc.current;
    final factionColors = getFactionColors(currentFaction);
    final primaryColor = factionColors.$1;

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
        color: Colors.orange,
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.7),
        builder: (context) => Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: primaryColor.withOpacity(.4),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(.3),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'PROCESSING GENETIC FUSION',
                      style: TextStyle(
                        color: Color(0xFFE8EAED),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
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
          color: Colors.orange,
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
          color: Colors.orange,
        );
        return;
      }

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
          color: Colors.orange,
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
          color: Colors.green,
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
        color: Colors.red,
        icon: Icons.error_rounded,
      );
    } finally {
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
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
            final stamina = context.read<StaminaService>();

            final refreshed = await stamina.refreshAndGet(inst.instanceId);
            final canUse = (refreshed?.staminaBars ?? 0) >= 1;

            if (!canUse) {
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
                color: Colors.orange,
                fromTop: true,
              );
              return;
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
    bool fromTop = false,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        elevation: 100,
        backgroundColor: color ?? Colors.grey.shade700,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: fromTop
            ? const EdgeInsets.only(top: 24, left: 16, right: 16)
            : const EdgeInsets.all(16),
      ),
    );
  }
}
