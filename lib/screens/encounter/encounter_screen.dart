import 'dart:convert';
import 'dart:ui';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart' as db;
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/genetics.dart';
import 'package:alchemons/models/wilderness.dart' show PartyMember;
import 'package:alchemons/services/breeding_engine.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/creature_filter_util.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/utils/likelihood_analyzer.dart';
import 'package:alchemons/utils/nature_utils.dart';
import 'package:alchemons/widgets/wilderness/creature_sprite_component.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum EncounterResult { ran, bred, completed }

class EncounterPage extends StatefulWidget {
  final String speciesId;
  final Creature? hydrated;
  final List<PartyMember> party;

  const EncounterPage({
    super.key,
    required this.speciesId,
    required this.party,
    this.hydrated,
  });

  @override
  State<EncounterPage> createState() => _EncounterPageState();
}

class _EncounterPageState extends State<EncounterPage>
    with TickerProviderStateMixin {
  PartyMember? _selected;
  bool _isBreeding = false;
  late AnimationController _glowController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final factionSvc = context.read<FactionService>();
    final currentFaction = factionSvc.current;
    final (primaryColor, _, accentColor) = getFactionColors(currentFaction);
    final repo = context.read<CreatureRepository>();
    final base = repo.getCreatureById(widget.speciesId);
    final visual = widget.hydrated ?? base;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, EncounterResult.ran);
        return false;
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0B0F14).withOpacity(0.96),
                const Color(0xFF0B0F14).withOpacity(0.92),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(accentColor),
                _buildWildCreatureDisplay(visual, accentColor),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildEncounterInfo(visual, accentColor),
                        if (_selected != null)
                          _buildCompatibilityPanel(
                            visual,
                            _selected!,
                            accentColor,
                          ),
                        _buildPartySection(accentColor),
                      ],
                    ),
                  ),
                ),
                _buildActionButtons(accentColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color accentColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: _GlassContainer(
        accentColor: accentColor,
        glowController: _glowController,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _IconButton(
                icon: Icons.arrow_back_rounded,
                accentColor: accentColor,
                onTap: () => Navigator.pop(context, EncounterResult.ran),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FIELD ENCOUNTER', style: _TextStyles.headerTitle),
                    const SizedBox(height: 2),
                    Text(
                      'Wild specimen breeding opportunity',
                      style: _TextStyles.headerSubtitle,
                    ),
                  ],
                ),
              ),
              _GlowingIcon(
                icon: Icons.explore_rounded,
                color: accentColor,
                controller: _glowController,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWildCreatureDisplay(Creature? visual, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: _GlassContainer(
        accentColor: Colors.purple.shade400,
        glowController: _glowController,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Wild Specimen',
                style: TextStyle(
                  color: _TextStyles.mutedText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.05),
                    child: child,
                  );
                },
                child: _WildPreviewBox(creature: visual),
              ),
              const SizedBox(height: 12),
              Text(
                visual?.name ?? 'Unknown Species',
                style: _TextStyles.wildCreatureName,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              if (visual?.types.isNotEmpty == true)
                _TypeBadges(types: visual!.types),
              const SizedBox(height: 6),
              _RarityBadge(rarity: visual?.rarity ?? 'Unknown'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEncounterInfo(Creature? visual, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: _GlassContainer(
        accentColor: accentColor,
        glowController: _glowController,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.science_outlined, color: accentColor, size: 16),
                  const SizedBox(width: 8),
                  Text('Breeding Opportunity', style: _TextStyles.sectionTitle),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Subject ${visual?.name ?? 'specimen'} is displaying breeding readiness. Cross-breeding with your team may yield valuable offspring for research.',
                style: _TextStyles.description,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompatibilityPanel(
    Creature? wild,
    PartyMember partner,
    Color accentColor,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: _GlassContainer(
        accentColor: Colors.green.shade400,
        glowController: _glowController,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.biotech_outlined,
                    color: Colors.green.shade400,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Compatibility Analysis',
                    style: _TextStyles.sectionTitle,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FutureBuilder<db.CreatureInstance?>(
                future: context.read<AlchemonsDatabase>().getInstance(
                  partner.instanceId,
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final instance = snapshot.data!;
                  final repo = context.read<CreatureRepository>();
                  final partnerCreature = repo.getCreatureById(instance.baseId);

                  return Row(
                    children: [
                      Expanded(
                        child: _CompatibilityCard(
                          title: 'Wild',
                          creature: wild,
                          color: Colors.purple.shade400,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              Colors.green.shade400.withOpacity(0.3),
                              Colors.transparent,
                            ],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.green.shade400.withOpacity(0.5),
                          ),
                        ),
                        child: Icon(
                          Icons.science,
                          color: Colors.green.shade400,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _CompatibilityCard(
                          title: 'Team',
                          creature: partnerCreature,
                          color: Colors.blue.shade400,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartySection(Color accentColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: _GlassContainer(
        accentColor: accentColor,
        glowController: _glowController,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.groups_outlined, color: accentColor, size: 16),
                  const SizedBox(width: 8),
                  Text('Select Partner', style: _TextStyles.sectionTitle),
                  const Spacer(),
                  if (_selected != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade400.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.green.shade400.withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        'Selected',
                        style: TextStyle(
                          color: Colors.green.shade400,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 160,
                child: _PartyGrid(
                  party: widget.party,
                  selected: _selected,
                  onPick: (p) => setState(() => _selected = p),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(Color accentColor) {
    final canBreed = _selected != null && !_isBreeding;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.18),
            border: Border(
              top: BorderSide(color: accentColor.withOpacity(0.35)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: canBreed
                      ? () => _handleBreed(context, _selected!)
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: canBreed
                          ? Colors.green.shade600
                          : Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: canBreed
                          ? [
                              BoxShadow(
                                color: Colors.green.shade400.withOpacity(0.4),
                                blurRadius: 12,
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isBreeding) ...[
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ] else ...[
                          const Icon(
                            Icons.science_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          _isBreeding ? 'Processing...' : 'Initiate Breeding',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, EncounterResult.ran),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.close_outlined,
                          color: _TextStyles.softText,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Abort',
                          style: TextStyle(
                            color: _TextStyles.softText,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
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
    );
  }

  Future<void> _handleBreed(BuildContext context, PartyMember partner) async {
    setState(() => _isBreeding = true);

    final factions = context.read<FactionService>();
    final firePerk2 = await factions.perk2Active();
    final dbApi = context.read<db.AlchemonsDatabase>();
    final engine = context.read<BreedingEngine>();
    final repo = context.read<CreatureRepository>();
    final stamina = context.read<StaminaService>();

    bool spinnerOpen = false;
    Future<void> openSpinner() async {
      spinnerOpen = true;
      await showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    void closeSpinnerIfOpen() {
      if (spinnerOpen) {
        spinnerOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    try {
      final inst = await dbApi.getInstance(partner.instanceId);
      if (inst == null) {
        _snack('Could not load partner.');
        return;
      }
      final creatureOfInst = repo.getCreatureById(inst.baseId);
      if (creatureOfInst == null) {
        _snack('Could not load partner creature.');
        return;
      }

      final can = await stamina.canBreed(inst.instanceId);
      if (!can) {
        _snack('This partner is resting.');
        return;
      }

      final wild = widget.hydrated ?? repo.getCreatureById(widget.speciesId);
      if (wild == null) {
        _snack('Wild specimen unavailable.');
        return;
      }

      openSpinner();

      final hasFireParent =
          repo.getCreatureById(inst.baseId)?.types.contains('Fire') == true ||
          wild.types.contains('Fire');

      final fireMult = factions.fireHatchTimeMultiplier(
        hasFireParent: hasFireParent,
        perk2: firePerk2,
      );

      final analyzer = BreedingLikelihoodAnalyzer(
        repository: repo,
        elementRecipes: engine.elementRecipes,
        familyRecipes: engine.familyRecipes,
        specialRules: engine.specialRules,
        tuning: engine.tuning,
      );

      final result = engine.breedInstanceWithCreature(inst, wild);
      if (!result.success || result.creature == null) {
        closeSpinnerIfOpen();
        _snack('No offspring this time.');
        return;
      }

      final baby = result.creature!;
      final justification = analyzer.justifyBreedingResult(
        creatureOfInst,
        wild,
        baby,
      );

      final rarityKey = baby.rarity.toLowerCase();
      final baseHatch =
          BreedConstants.rarityHatchTimes[rarityKey] ??
          const Duration(minutes: 10);
      final hatchMult = hatchMultForNature(baby.nature?.id);
      final adjusted = Duration(
        milliseconds: (baseHatch.inMilliseconds * hatchMult * fireMult).round(),
      );

      final payload = {
        'baseId': baby.id,
        'rarity': baby.rarity,
        'natureId': baby.nature?.id,
        'genetics': baby.genetics?.variants ?? <String, String>{},
        'parentage': baby.parentage?.toJson(),
        'isPrismaticSkin': baby.isPrismaticSkin,
        'likelihoodAnalysis': jsonEncode(justification.toJson()),
      };
      final payloadJson = jsonEncode(payload);
      final eggId = 'egg_${DateTime.now().millisecondsSinceEpoch}';

      final free = await dbApi.firstFreeSlot();
      int? placedIndex;
      bool enqueued = false;

      if (free == null) {
        await dbApi.enqueueEgg(
          eggId: eggId,
          resultCreatureId: baby.id,
          bonusVariantId: result.variantUnlocked?.id,
          rarity: baby.rarity,
          remaining: adjusted,
          payloadJson: payloadJson,
        );
        enqueued = true;
      } else {
        final hatchAtUtc = DateTime.now().toUtc().add(adjusted);
        await dbApi.placeEgg(
          slotId: free.id,
          eggId: eggId,
          resultCreatureId: baby.id,
          bonusVariantId: result.variantUnlocked?.id,
          rarity: baby.rarity,
          hatchAtUtc: hatchAtUtc,
          payloadJson: payloadJson,
        );
        placedIndex = free.id;
      }

      final waterPerk1 = factions.perk1Active && factions.isWater();
      final partnerIsWater =
          (repo.getCreatureById(inst.baseId)?.types.contains('Water') ?? false);
      final wildIsWater = wild.types.contains('Water');

      final skipStamina = factions.waterSkipBreedStamina(
        bothWater: partnerIsWater && wildIsWater,
        perk1: waterPerk1,
      );

      if (!skipStamina) {
        await stamina.spendForBreeding(inst.instanceId);
      }

      closeSpinnerIfOpen();

      if (!mounted) return;
      await _showResultDialog(
        context,
        baby,
        incubatorSlotIndex: placedIndex,
        hatchIn: adjusted,
        enqueuedInstead: enqueued,
      );

      if (!mounted) return;
      Navigator.of(context).pop(EncounterResult.bred);
    } catch (e) {
      closeSpinnerIfOpen();
      _snack('Breeding failed: $e');
    } finally {
      if (mounted) setState(() => _isBreeding = false);
    }
  }

  Future<void> _showResultDialog(
    BuildContext context,
    Creature baby, {
    int? incubatorSlotIndex,
    Duration? hatchIn,
    bool enqueuedInstead = false,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ResultDialog(
        baby: baby,
        slotIndex: incubatorSlotIndex,
        hatchIn: hatchIn,
        enqueued: enqueuedInstead,
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// ==================== REUSABLE COMPONENTS ====================

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final Color accentColor;
  final AnimationController glowController;

  const _GlassContainer({
    required this.child,
    required this.accentColor,
    required this.glowController,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedBuilder(
          animation: glowController,
          builder: (context, _) {
            final glow = 0.35 + glowController.value * 0.4;
            return Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentColor.withOpacity(glow * 0.85)),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(glow * 0.5),
                    blurRadius: 20 + glowController.value * 14,
                  ),
                ],
              ),
              child: child,
            );
          },
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _IconButton({
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accentColor.withOpacity(.35)),
        ),
        child: Icon(icon, color: _TextStyles.softText, size: 18),
      ),
    );
  }
}

class _GlowingIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final AnimationController controller;

  const _GlowingIcon({
    required this.icon,
    required this.color,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final glow = 0.35 + controller.value * 0.4;
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withOpacity(.3), Colors.transparent],
            ),
            border: Border.all(color: color.withOpacity(glow)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(glow * .4),
                blurRadius: 20 + controller.value * 14,
              ),
            ],
          ),
          child: Icon(icon, size: 18, color: color),
        );
      },
    );
  }
}

class _WildPreviewBox extends StatelessWidget {
  final Creature? creature;

  const _WildPreviewBox({required this.creature});

  @override
  Widget build(BuildContext context) {
    if (creature?.spriteData == null) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Icon(Icons.help_outline, color: _TextStyles.mutedText, size: 32),
      );
    }

    final sd = creature!.spriteData!;
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.purple.shade400.withOpacity(0.5),
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: GameWidget(
        game: _OneSpriteGame(
          spritePath: sd.spriteSheetPath,
          frames: sd.totalFrames,
          rows: sd.rows,
          frameSize: Vector2(
            sd.frameWidth.toDouble(),
            sd.frameHeight.toDouble(),
          ),
          stepTime: sd.frameDurationMs / 1000.0,
          genetics: creature!.genetics,
          prismatic: creature!.isPrismaticSkin == true,
        ),
      ),
    );
  }
}

class _TypeBadges extends StatelessWidget {
  final List<String> types;

  const _TypeBadges({required this.types});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: types.map((type) {
        final color = CreatureFilterUtils.getTypeColor(type);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Text(
            type,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RarityBadge extends StatelessWidget {
  final String rarity;

  const _RarityBadge({required this.rarity});

  @override
  Widget build(BuildContext context) {
    final color = _getRarityColor(rarity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_border_outlined, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            rarity,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return Colors.grey.shade500;
      case 'uncommon':
        return Colors.green.shade400;
      case 'rare':
        return Colors.blue.shade400;
      case 'epic':
      case 'mythic':
        return Colors.purple.shade400;
      case 'legendary':
        return Colors.orange.shade400;
      default:
        return Colors.grey.shade500;
    }
  }
}

class _CompatibilityCard extends StatelessWidget {
  final String title;
  final Creature? creature;
  final Color color;

  const _CompatibilityCard({
    required this.title,
    required this.creature,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: _TextStyles.mutedText,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            creature?.name ?? 'Unknown',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _PartyGrid extends StatelessWidget {
  final List<PartyMember> party;
  final PartyMember? selected;
  final ValueChanged<PartyMember> onPick;

  const _PartyGrid({
    required this.party,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    if (party.isEmpty) {
      return Center(
        child: Text(
          'No team members available',
          style: _TextStyles.hint,
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      itemCount: party.length,
      itemBuilder: (context, i) {
        final p = party[i];
        final isSel = selected?.instanceId == p.instanceId;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _PartyCard(member: p, selected: isSel, onTap: () => onPick(p)),
        );
      },
    );
  }
}

class _PartyCard extends StatelessWidget {
  final PartyMember member;
  final bool selected;
  final VoidCallback onTap;

  const _PartyCard({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dbInstance = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureRepository>();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 120,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? Colors.green.shade400.withOpacity(0.15)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Colors.green.shade400
                : Colors.white.withOpacity(0.25),
            width: selected ? 2 : 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.green.shade400.withOpacity(0.3),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: FutureBuilder<db.CreatureInstance?>(
          future: dbInstance.getInstance(member.instanceId),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final inst = snap.data!;
            final base = repo.getCreatureById(inst.baseId);
            final displayName = base?.name ?? inst.baseId;
            final stamina = inst.staminaBars;
            final maxStamina = inst.staminaMax;

            return Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: base != null
                            ? CreatureFilterUtils.getTypeColor(base.types.first)
                            : Colors.grey.shade600,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: base?.image != null
                          ? Image.asset(
                              'assets/images/${base!.image}',
                              fit: BoxFit.cover,
                            )
                          : Icon(
                              Icons.pets,
                              color: _TextStyles.mutedText,
                              size: 32,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  displayName,
                  style: selected
                      ? _TextStyles.cardTitle
                      : _TextStyles.cardSmallTitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                _StaminaBar(current: stamina, max: maxStamina),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StaminaBar extends StatelessWidget {
  final int current;
  final int max;

  const _StaminaBar({required this.current, required this.max});

  @override
  Widget build(BuildContext context) {
    final pct = (max <= 0) ? 0.0 : (current / max).clamp(0.0, 1.0);
    final color = pct > 0.5
        ? Colors.green.shade400
        : pct > 0.2
        ? Colors.orange.shade400
        : Colors.red.shade400;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 6,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1)),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: pct,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.7), color],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultDialog extends StatelessWidget {
  final Creature baby;
  final int? slotIndex;
  final Duration? hatchIn;
  final bool enqueued;

  const _ResultDialog({
    required this.baby,
    this.slotIndex,
    this.hatchIn,
    required this.enqueued,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2E).withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade400.withOpacity(0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.science_outlined,
                  color: Colors.green.shade400,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  'Breeding Success!',
                  style: TextStyle(
                    color: _TextStyles.softText,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  enqueued
                      ? 'Embryo secured in research queue for incubation.'
                      : 'Embryo placed in laboratory incubator for development.',
                  style: _TextStyles.description,
                  textAlign: TextAlign.center,
                ),
                if (hatchIn != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Estimated development: ${_formatDuration(hatchIn!)}',
                    style: TextStyle(
                      color: _TextStyles.mutedText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
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
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

class _OneSpriteGame extends FlameGame {
  final String spritePath;
  final int frames;
  final int rows;
  final Vector2 frameSize;
  final double stepTime;
  final Genetics? genetics;
  final bool prismatic;

  _OneSpriteGame({
    required this.spritePath,
    required this.frames,
    required this.rows,
    required this.frameSize,
    required this.stepTime,
    required this.genetics,
    required this.prismatic,
  });

  @override
  Future<void> onLoad() async {
    final box = Vector2(size.x, size.y);
    final scale = scaleFromGenes(genetics);

    add(
      CreatureSpriteComponent(
          spritePath: spritePath,
          totalFrames: frames,
          rows: rows,
          frameSize: frameSize,
          stepTime: stepTime,
          scaleFactor: scale,
          saturation: satFromGenes(genetics),
          brightness: briFromGenes(genetics),
          baseHueShift: hueFromGenes(genetics),
          isPrismatic: prismatic,
          desiredSize: box,
        )
        ..anchor = Anchor.center
        ..position = box / 2,
    );
  }
}

// ==================== TEXT STYLES ====================

class _TextStyles {
  static const softText = Color(0xFFE8EAED);
  static const mutedText = Color(0xFFB6C0CC);

  static const headerTitle = TextStyle(
    color: softText,
    fontSize: 15,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.8,
  );

  static const headerSubtitle = TextStyle(
    color: mutedText,
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  static const sectionTitle = TextStyle(
    color: softText,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  static const wildCreatureName = TextStyle(
    color: softText,
    fontSize: 22,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.5,
  );

  static const description = TextStyle(
    color: mutedText,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const hint = TextStyle(
    color: mutedText,
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  static const cardTitle = TextStyle(
    color: softText,
    fontSize: 12,
    fontWeight: FontWeight.w800,
  );

  static const cardSmallTitle = TextStyle(
    color: softText,
    fontSize: 11,
    fontWeight: FontWeight.w700,
  );
}
