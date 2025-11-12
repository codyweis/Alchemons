import 'dart:convert';
import 'dart:math' as math;
import 'dart:math';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/creature_instance_uti.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/utils/likelihood_analyzer.dart';
import 'package:alchemons/utils/nature_utils.dart';
import 'package:alchemons/widgets/bottom_sheet_shell.dart';
import 'package:alchemons/widgets/creature_instances_sheet.dart';
import 'package:alchemons/widgets/creature_selection_sheet.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/breed_cinematic_fx.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/alchemons_db.dart';
import '../../models/creature.dart';
import '../../providers/app_providers.dart';
import '../../services/breeding_engine.dart';
import '../../services/creature_repository.dart';

class BreedingTab extends StatefulWidget {
  final List<CreatureEntry> discoveredCreatures;
  final VoidCallback onBreedingComplete;

  const BreedingTab({
    super.key,
    required this.discoveredCreatures,
    required this.onBreedingComplete,
  });

  @override
  State<BreedingTab> createState() => _BreedingTabState();
}

class _BreedingTabState extends State<BreedingTab>
    with TickerProviderStateMixin {
  CreatureInstance? selectedParent1;
  CreatureInstance? selectedParent2;

  late AnimationController _slot1Controller;
  late AnimationController _slot2Controller;
  late AnimationController _compatibilityController;
  late AnimationController _breedButtonController;

  late AnimationController _emptyFuseController;

  // CHANGE: fade controllers for pre-cinematic dissolve
  late AnimationController _preCinematicFadeController;
  late Animation<double> _spriteFadeAnim;

  late Animation<double> _orbScaleAnim;
  late Animation<double> _orbSpinSpeedAnim;

  @override
  void initState() {
    super.initState();
    _slot1Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _emptyFuseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _slot2Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _compatibilityController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _breedButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // CHANGE: fade-out before cinematic
    _preCinematicFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _spriteFadeAnim = CurvedAnimation(
      parent: _preCinematicFadeController,
      curve: Curves.easeOut,
    );

    _orbScaleAnim = Tween<double>(begin: 1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _preCinematicFadeController,
        curve: Curves.easeOutCubic,
      ),
    );

    _orbSpinSpeedAnim = Tween<double>(begin: 1.0, end: 4.0).animate(
      CurvedAnimation(
        parent: _preCinematicFadeController,
        curve: Curves.easeInCubic,
      ),
    );
  }

  @override
  void dispose() {
    _slot1Controller.dispose();
    _slot2Controller.dispose();
    _compatibilityController.dispose();
    _breedButtonController.dispose();
    _preCinematicFadeController.dispose();
    _emptyFuseController.dispose();
    super.dispose();
  }

  void _updateAnimations() {
    final hasParent1 = selectedParent1 != null;
    final hasParent2 = selectedParent2 != null;
    final hasEither = hasParent1 || hasParent2;
    final hasBoth = hasParent1 && hasParent2;

    final slot1Empty = selectedParent1 == null;
    final slot2Empty = selectedParent2 == null;

    // if BOTH are empty we animate fuse,
    // else we could slow/stop. You can pick your rule.
    if (slot1Empty || slot2Empty) {
      if (!_emptyFuseController.isAnimating) {
        _emptyFuseController.repeat();
      }
    } else {
      _emptyFuseController.stop();
    }

    // slot anims stay as-is
    if (hasParent1) {
      _slot1Controller.forward();
    } else {
      _slot1Controller.reverse();
    }

    if (hasParent2) {
      _slot2Controller.forward();
    } else {
      _slot2Controller.reverse();
    }

    // NEW: spin the orb if we have at least one parent
    if (hasEither) {
      if (!_compatibilityController.isAnimating) {
        _compatibilityController.repeat();
      }
    } else {
      _compatibilityController.reset();
    }

    // breed button should only pulse (and show DNA/particles/etc) when both
    if (hasBoth) {
      if (!_breedButtonController.isAnimating) {
        _breedButtonController.repeat();
      }
    } else {
      _breedButtonController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildBreedingCard(theme),
          const SizedBox(height: 16),
          if (selectedParent1 != null && selectedParent2 != null)
            _buildBreedButton(theme),
        ],
      ),
    );
  }

  // ================== MAIN FUSION CARD ==================
  Widget _buildBreedingCard(FactionTheme theme) {
    return Container(
      // CHANGE: give the whole chamber a pro card shell
      decoration: BoxDecoration(
        color: theme.surfaceAlt.withOpacity(.4),

        boxShadow: [
          BoxShadow(
            color: theme.surface.withOpacity(.2),
            blurRadius: 32,
            offset: const Offset(0, 0),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.surface.withOpacity(.6),
            theme.surfaceAlt.withOpacity(.15),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Animated background particles when both selected
          if (selectedParent1 != null && selectedParent2 != null)
            _buildBackgroundParticles(theme),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildHeader(theme),
                const SizedBox(height: 24),
                _buildParentSlots(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(FactionTheme theme) {
    return Row(
      children: [
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FUSION CHAMBER',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Select two specimens to synthesize new life',
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildParentSlots(FactionTheme theme) {
    final hasParents = selectedParent1 != null && selectedParent2 != null;

    // grab base species + their colors up front so we can feed them to orb
    final repo = context.read<CreatureCatalog>();
    final baseA = selectedParent1 != null
        ? repo.getCreatureById(selectedParent1!.baseId)
        : null;
    final baseB = selectedParent2 != null
        ? repo.getCreatureById(selectedParent2!.baseId)
        : null;

    final Color? colorA = baseA != null
        ? BreedConstants.getTypeColor(baseA.types.first)
        : null;

    final Color? colorB = baseB != null
        ? BreedConstants.getTypeColor(baseB.types.first)
        : null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // animated DNA line
        if (hasParents) _buildDNAConnection(theme),

        // the two slots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildEnhancedSlot(
                inst: selectedParent1,
                label: 'SPECIMEN A',
                slotIndex: 1,
                theme: theme,
                controller: _slot1Controller,
              ),
            ),
            const SizedBox(width: 16),
            // (no orb here anymore)
            const SizedBox(width: 16),
            Expanded(
              child: _buildEnhancedSlot(
                inst: selectedParent2,
                label: 'SPECIMEN B',
                slotIndex: 2,
                theme: theme,
                controller: _slot2Controller,
              ),
            ),
          ],
        ),

        // new: floating fusion orb, centered between slots visually
        if (true) // we always build it so layout doesn't jump,
          // but inside we dim it if !hasParents
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: _buildFusionIndicator(
                  theme: theme,
                  hasParents: hasParents,
                  leftColor: colorA,
                  rightColor: colorB,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ================== ENHANCED SLOT ==================
  //
  // Major visual overhaul:
  // - each slot is its own card with border + glow when active
  // - close button moved to top-right corner overlay, not in column flow
  // - consistent header row with label + status badge
  // - cleaned avatar area so they won't overlap or feel floaty
  //
  Widget _buildEnhancedSlot({
    required CreatureInstance? inst,
    required String label,
    required int slotIndex,
    required FactionTheme theme,
    required AnimationController controller,
  }) {
    final repo = context.read<CreatureCatalog>();
    final base = inst != null ? repo.getCreatureById(inst.baseId) : null;
    final genetics = decodeGenetics(inst?.geneticsJson);

    final typeColor = base != null
        ? BreedConstants.getTypeColor(base.types.first)
        : theme.accent;

    final isEmpty = base == null;

    return AnimatedBuilder(
      animation: Listenable.merge([
        controller,
        _preCinematicFadeController, // CHANGE: to animate fade
      ]),
      builder: (context, child) {
        // subtle breathing scale when occupied
        final scale = isEmpty ? 1.0 : 1.0 + (controller.value * 0.03);

        // fade to 0 opacity during pre-cinematic dissolve
        final spriteOpacity =
            1.0 - _spriteFadeAnim.value; // 1 -> 0 as we animate

        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: () => _showCreatureSelection(slotIndex),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              height: 220,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // CONTENT COLUMN
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // SPRITE ZONE
                      Center(
                        child: isEmpty
                            ? _buildEmptyAvatar(theme)
                            : Opacity(
                                opacity: spriteOpacity.clamp(0, 1),
                                child: _buildCreatureAvatar(
                                  base!,
                                  inst!,
                                  genetics,
                                ),
                              ),
                      ),

                      const SizedBox(height: 18),

                      // NAME + TYPE
                      if (!isEmpty) ...[
                        Text(
                          base!.name.toUpperCase(),
                          style: TextStyle(
                            color: theme.text,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        _buildTypeChip(base.types.first, typeColor),
                      ] else ...[
                        Text(
                          'Tap to select',
                          style: TextStyle(
                            color: theme.textMuted.withOpacity(.6),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),

                  // CLOSE BUTTON (ONLY WHEN FILLED)
                  if (!isEmpty)
                    Positioned(
                      right: 0,
                      top: -10,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            if (slotIndex == 1) {
                              selectedParent1 = null;
                            } else {
                              selectedParent2 = null;
                            }
                            _updateAnimations();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(.7),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.red.withOpacity(.6),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.red,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // empty avatar ring (inactive state)
  Widget _buildEmptyAvatar(FactionTheme theme) {
    final primary = Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // base circle / placeholder
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: theme.border.withOpacity(.4), width: 2),
              gradient: RadialGradient(
                colors: [theme.surfaceAlt.withOpacity(.2), Colors.transparent],
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(.2),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.help_center_rounded,
              color: theme.textMuted.withOpacity(.3),
              size: 32,
            ),
          ),

          // spinning fuse ring
          AnimatedBuilder(
            animation: _emptyFuseController,
            builder: (context, _) {
              // spin 0 -> 2π
              final angle = _emptyFuseController.value * 2 * math.pi;

              return Transform.rotate(
                angle: angle,
                child: CustomPaint(
                  // take full 96x96 so arc hugs the same circle
                  size: const Size(96, 96),
                  painter: _FuseArcPainter(
                    color: primary,
                    thickness: 3,
                    // you can make this shorter or longer;
                    // math.pi/3 == 60°, math.pi/2 == 90°
                    sweepRadians: math.pi / 2,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // live animated sprite, slightly enlarged but nicely framed
  Widget _buildCreatureAvatar(
    Creature base,
    CreatureInstance inst,
    Genetics? genetics,
  ) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withOpacity(.3),
        border: Border.all(color: Colors.white.withOpacity(.08), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.6),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: base.spriteData != null
          ? Transform.scale(
              scale: 1.4,
              child: InstanceSprite(creature: base, instance: inst, size: 72),
            )
          : Icon(
              Icons.image_not_supported_rounded,
              color: Colors.white.withOpacity(.4),
              size: 32,
            ),
    );
  }

  Widget _buildTypeChip(String type, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(.25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(.5), width: 1),
      ),
      child: Text(
        type.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildOrbFill({
    required bool hasParents,
    required Color? leftColor,
    required Color? rightColor,
    required Color fallbackColor,
  }) {
    // Case: both parents selected (full fusion)
    if (leftColor != null && rightColor != null) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [leftColor, rightColor],
          ),
        ),
      );
    }

    // Case: exactly one parent selected
    final singleColor = leftColor ?? rightColor;
    if (singleColor != null) {
      // We'll build two half-circles:
      // - left half (or top/bottom, doesn't matter visually once it's spinning)
      // - transparent other half

      return Stack(
        children: [
          // filled half
          Align(
            alignment: Alignment.centerLeft,
            child: ClipPath(
              clipper: _HalfCircleClipper(side: HalfSide.left),
              child: Container(
                decoration: BoxDecoration(
                  color: singleColor,
                  shape: BoxShape.rectangle,
                ),
              ),
            ),
          ),
          // transparent half (nothing)
        ],
      );
    }

    // Case: no parents selected (idle gray-ish orb or empty)
    return Container(
      decoration: BoxDecoration(color: fallbackColor, shape: BoxShape.circle),
    );
  }

  // ================== FUSION INDICATOR ==================
  Widget _buildFusionIndicator({
    required FactionTheme theme,
    required bool hasParents,
    Color? leftColor,
    Color? rightColor,
  }) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _compatibilityController,
        _preCinematicFadeController,
      ]),
      builder: (context, child) {
        final baseRotation = _compatibilityController.value * 2 * math.pi;
        final spinMultiplier =
            _orbSpinSpeedAnim.value; // (1.0 -> 4.0 during charge)
        final bothParents = hasParents; // you already pass this in
        final speedBase = bothParents ? 2.0 : 1; // tweak to taste

        final rotation = baseRotation * speedBase * spinMultiplier;

        // gentle idle pulse
        final idlePulseScale = hasParents
            ? 1.0 +
                  (math.sin(_compatibilityController.value * 2 * math.pi) * 0.1)
            : 1.0;

        // dramatic charge-up scale (1.0 -> 2.0)
        final chargedScale = idlePulseScale * _orbScaleAnim.value;

        // Pick colors for border/glow
        Color ringColor;
        if (leftColor != null && rightColor != null) {
          ringColor = Color.lerp(leftColor, rightColor, 0.5)!.withOpacity(.8);
        } else if (leftColor != null) {
          ringColor = leftColor.withOpacity(.8);
        } else if (rightColor != null) {
          ringColor = rightColor.withOpacity(.8);
        } else {
          ringColor = theme.border.withOpacity(.4);
        }

        // Orb fill widget (full blend, half-fill, or fallback)
        final innerOrb = _buildOrbFill(
          hasParents: hasParents,
          leftColor: leftColor,
          rightColor: rightColor,
          fallbackColor: theme.surfaceAlt,
        );

        return Transform.scale(
          scale: chargedScale,
          child: Transform.rotate(
            angle: rotation,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: (leftColor != null || rightColor != null)
                      ? ringColor
                      : theme.border.withOpacity(.3),
                  width: 1.5,
                ),
                boxShadow: (leftColor != null || rightColor != null)
                    ? [
                        BoxShadow(
                          color: ringColor.withOpacity(.3),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ]
                    : [],
              ),
              child: ClipOval(child: innerOrb),
            ),
          ),
        );
      },
    );
  }

  // ================== DNA CONNECTION LINE ==================
  Widget _buildDNAConnection(FactionTheme theme) {
    return AnimatedBuilder(
      animation: _compatibilityController,
      builder: (context, child) {
        return IgnorePointer(
          child: CustomPaint(
            size: const Size(double.infinity, 200),
            painter: _DNAConnectionPainter(
              progress: _compatibilityController.value,
              color: theme.accent,
            ),
          ),
        );
      },
    );
  }

  // ================== BACKGROUND PARTICLES ==================
  Widget _buildBackgroundParticles(FactionTheme theme) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _compatibilityController,
        builder: (context, child) {
          return IgnorePointer(
            child: CustomPaint(
              painter: _ParticlePainter(
                progress: _compatibilityController.value,
                color: theme.accent,
              ),
            ),
          );
        },
      ),
    );
  }

  // ================== BREED BUTTON ==================
  Widget _buildBreedButton(FactionTheme theme) {
    final canBreed = selectedParent1 != null && selectedParent2 != null;

    return AnimatedBuilder(
      animation: _breedButtonController,
      builder: (context, child) {
        final pulseValue = canBreed
            ? 1.0 +
                  (math.sin(_breedButtonController.value * 2 * math.pi) * 0.05)
            : 1.0;

        return Transform.scale(
          scale: pulseValue,
          child: GestureDetector(
            onTap: canBreed ? _onBreedTap : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: canBreed
                    ? LinearGradient(colors: [theme.accent, theme.accentSoft])
                    : null,
                color: canBreed ? null : theme.surfaceAlt.withOpacity(.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: canBreed
                      ? theme.accent.withOpacity(.8)
                      : theme.border.withOpacity(.4),
                  width: 2,
                ),
                boxShadow: canBreed
                    ? [
                        BoxShadow(
                          color: theme.accent.withOpacity(.5),
                          blurRadius: 28,
                          spreadRadius: 4,
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 12),
                  Text(
                    canBreed ? 'INITIATE FUSION' : 'SELECT TWO SPECIMENS',
                    style: TextStyle(
                      color: canBreed
                          ? Colors.black
                          : theme.textMuted.withOpacity(.5),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // CHANGE: instead of calling _performBreeding() directly,
  // we first run the dissolve fade, then call _performBreeding()
  Future<void> _onBreedTap() async {
    // play fade from 1 -> 0, orb ramps up
    await _preCinematicFadeController.forward();

    // NEW: let that max-charged orb hang on screen briefly
    await Future.delayed(const Duration(milliseconds: 400));

    // now jump to cinematic
    await _performBreeding();

    // reset fade for next time
    _preCinematicFadeController.reset();
  }

  // ================== BREED HANDLER ==================
  Future<void> _performBreeding() async {
    if (selectedParent1 == null || selectedParent2 == null) return;

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
      final repo = context.read<CreatureCatalog>();
      final speciesA = repo.getCreatureById(selectedParent1!.baseId);
      final speciesB = repo.getCreatureById(selectedParent2!.baseId);

      final colorA = speciesA != null
          ? BreedConstants.getTypeColor(speciesA.types.first)
          : Theme.of(context).colorScheme.primary;
      final colorB = speciesB != null
          ? BreedConstants.getTypeColor(speciesB.types.first)
          : Theme.of(context).colorScheme.secondary;

      Widget spriteFor(CreatureInstance inst, Creature? base) {
        if (base?.spriteData == null) {
          return Icon(
            Icons.pets,
            color: Colors.white.withOpacity(.8),
            size: 64,
          );
        }
        return SizedBox(
          width: 120,
          height: 120,
          child: InstanceSprite(creature: base!, instance: inst, size: 72),
        );
      }

      final leftSprite = spriteFor(selectedParent1!, speciesA);
      final rightSprite = spriteFor(selectedParent2!, speciesB);

      // cinematic runs same as before
      await showAlchemyFusionCinematic<void>(
        context: context,
        leftSprite: leftSprite,
        rightSprite: rightSprite,
        leftColor: colorA,
        rightColor: colorB,
        minDuration: const Duration(milliseconds: 1800),
        task: () async {
          final breedingEngine = context.read<BreedingEngine>();
          final db = context.read<AlchemonsDatabase>();
          final factions = context.read<FactionService>();

          final firePerk2 = await factions.perk2Active();

          // Breed
          final breedResult = breedingEngine.breedInstances(
            selectedParent1!,
            selectedParent2!,
          );

          if (!breedResult.success || breedResult.creature == null) {
            _showToast(
              'Genetic incompatibility detected',
              icon: Icons.warning_rounded,
              color: Colors.orange,
            );
            throw Exception('Incompatible');
          }

          final offspring = breedResult.creature!;

          String? analysisJson;
          try {
            final baseA = repo.getCreatureById(selectedParent1!.baseId);
            final baseB = repo.getCreatureById(selectedParent2!.baseId);

            if (baseA != null && baseB != null) {
              // Hydrate parents with genetics and nature
              final geneticsA = decodeGenetics(selectedParent1!.geneticsJson);
              final geneticsB = decodeGenetics(selectedParent2!.geneticsJson);

              final parentA = baseA.copyWith(
                genetics: geneticsA,
                nature: selectedParent1!.natureId != null
                    ? NatureCatalog.byId(selectedParent1!.natureId!)
                    : baseA.nature,
                isPrismaticSkin: selectedParent1!.isPrismaticSkin,
              );

              final parentB = baseB.copyWith(
                genetics: geneticsB,
                nature: selectedParent2!.natureId != null
                    ? NatureCatalog.byId(selectedParent2!.natureId!)
                    : baseB.nature,
                isPrismaticSkin: selectedParent2!.isPrismaticSkin,
              );

              // Create analyzer
              final analyzer = BreedingLikelihoodAnalyzer(
                repository: repo,
                elementRecipes: breedingEngine.elementRecipes,
                familyRecipes: breedingEngine.familyRecipes,
                specialRules: breedingEngine.specialRules,
                tuning: breedingEngine.tuning,
                engine: breedingEngine,
              );

              // Analyze
              final analysisReport = analyzer.analyzeBreedingResult(
                parentA,
                parentB,
                offspring,
              );

              analysisJson = jsonEncode(analysisReport.toJson());
            }
          } catch (e) {
            print('⚠️ Analyzer failed: $e');
          }

          final hasFireParent =
              speciesA?.types.contains('Fire') == true ||
              speciesB?.types.contains('Fire') == true;
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
          final lineage = offspring.lineageData;

          final payload = {
            'baseId': offspring.id,
            'rarity': offspring.rarity,
            'natureId': offspring.nature?.id,
            'genetics': offspring.genetics?.variants ?? <String, String>{},
            'parentage': offspring.parentage?.toJson(),
            'isPrismaticSkin': offspring.isPrismaticSkin,
            'likelihoodAnalysis': analysisJson,
            'stats': offspring.stats?.toJson(),
            'lineage': {
              'generationDepth': lineage?.generationDepth,
              'nativeFaction': lineage?.nativeFaction,
              'variantFaction': lineage?.variantFaction,
              'factionLineage': lineage?.factionLineage,
              'elementLineage': lineage?.elementLineage,
              'familyLineage': lineage?.familyLineage,
              'isPure': offspring.isPure,
            },
            'statPotentials': {
              'speed': offspring.stats?.speedPotential ?? 3.0,
              'intelligence': offspring.stats?.intelligencePotential ?? 3.0,
              'strength': offspring.stats?.strengthPotential ?? 3.0,
              'beauty': offspring.stats?.beautyPotential ?? 3.0,
            },
          };
          final payloadJson = jsonEncode(payload);

          final free = await db.incubatorDao.firstFreeSlot();
          final eggId = 'egg_${DateTime.now().millisecondsSinceEpoch}';

          if (free == null) {
            await db.incubatorDao.enqueueEgg(
              eggId: eggId,
              resultCreatureId: offspring.id,
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
            await db.incubatorDao.placeEgg(
              slotId: free.id,
              eggId: eggId,
              resultCreatureId: offspring.id,
              rarity: offspring.rarity,
              hatchAtUtc: hatchAtUtc,
              payloadJson: payloadJson,
            );
            _showToast(
              'Embryo placed in incubation chamber ${free.id + 1}',
              icon: Icons.science_rounded,
              color: const Color.fromARGB(255, 239, 255, 92),
            );
          }

          final bothWater =
              speciesA?.types.contains('Water') == true &&
              speciesB?.types.contains('Water') == true;
          final skipStamina = factions.waterSkipBreedStamina(
            bothWater: bothWater,
            perk1: factions.perk1Active && factions.isWater(),
          );

          // 50% chance to skip stamina cost if perk active

          if (!skipStamina) {
            await stamina.spendForBreeding(selectedParent1!.instanceId);
            await stamina.spendForBreeding(selectedParent2!.instanceId);
          } else {
            if (Random().nextBool()) {
              await stamina.spendForBreeding(selectedParent1!.instanceId);
              await stamina.spendForBreeding(selectedParent2!.instanceId);
            }
          }
        },
      );

      if (!mounted) return;

      setState(() {
        selectedParent1 = null;
        selectedParent2 = null;
        _updateAnimations();
      });
      widget.onBreedingComplete();
    } catch (e) {
      if (e.toString().contains('Incompatible')) return;
      _showToast(
        'Fusion protocol error: $e',
        color: Colors.red,
        icon: Icons.error_rounded,
      );
    }
  }

  // ================== CREATURE SELECTION (unchanged logic) ==================
  void _showCreatureSelection(int slotNumber) async {
    final db = context.read<AlchemonsDatabase>();
    final available = await db.creatureDao
        .getSpeciesWithInstances(); // Set<String> baseIds

    final filteredDiscovered = filterByAvailableInstances(
      widget.discoveredCreatures,
      available,
    );

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
              discoveredCreatures: filteredDiscovered,
              showOnlyAvailableTypes: true,
              onSelectCreature: (creatureId) async {
                Navigator.pop(context);
                final repo = context.read<CreatureCatalog>();
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
    final theme = context.read<FactionTheme>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return BottomSheetShell(
          theme: theme,
          title: '${species.name} Specimens',
          child: InstancesSheet(
            species: species,
            theme: theme,
            selectedInstanceIds: [
              if (selectedParent1?.instanceId != null)
                selectedParent1!.instanceId,
              if (selectedParent2?.instanceId != null)
                selectedParent2!.instanceId,
            ],
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
          ),
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
      _updateAnimations();
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

// ================== CUSTOM PAINTERS ==================

class _DNAConnectionPainter extends CustomPainter {
  final double progress;
  final Color color;

  _DNAConnectionPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final width = size.width;
    final height = size.height;
    final centerY = height / 2;

    final path = Path();
    for (double x = 0; x < width; x++) {
      final y =
          centerY +
          math.sin((x / width) * 4 * math.pi + progress * 2 * math.pi) * 8;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_DNAConnectionPainter oldDelegate) => true;
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  final Color color;

  _ParticlePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(.2)
      ..style = PaintingStyle.fill;

    final random = math.Random(42); // Fixed seed for consistency

    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final y = baseY + math.sin(progress * 2 * math.pi + i) * 20;
      final radius = 1.0 + random.nextDouble() * 2;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => true;
}

enum HalfSide { left, right }

class _HalfCircleClipper extends CustomClipper<Path> {
  final HalfSide side;
  _HalfCircleClipper({required this.side});

  @override
  Path getClip(Size size) {
    final path = Path();
    if (side == HalfSide.left) {
      // left semicircle
      path.addArc(
        Rect.fromLTWH(0, 0, size.width, size.height),
        math.pi / 2, // 90°
        math.pi, // sweep 180°
      );
    } else {
      // right semicircle
      path.addArc(
        Rect.fromLTWH(0, 0, size.width, size.height),
        -math.pi / 2, // -90°
        math.pi, // 180°
      );
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _HalfCircleClipper oldClipper) {
    return oldClipper.side != side;
  }
}

class _FuseArcPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final double sweepRadians; // how long the "lit fuse" is

  _FuseArcPainter({
    required this.color,
    required this.thickness,
    this.sweepRadians = math.pi / 3, // ~60° arc
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(
      thickness / 2,
      thickness / 2,
      size.width - thickness,
      size.height - thickness,
    );

    // we'll always draw starting at angle 0; rotation is handled by Transform.rotate
    const double startAngle = 0;
    canvas.drawArc(rect, startAngle, sweepRadians, false, strokePaint);
  }

  @override
  bool shouldRepaint(_FuseArcPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.thickness != thickness ||
        oldDelegate.sweepRadians != sweepRadians;
  }
}
