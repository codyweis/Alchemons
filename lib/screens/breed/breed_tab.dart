import 'dart:math' as math;
import 'dart:math';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/breeding_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/creature_instance_uti.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/bottom_sheet_shell.dart';
import 'package:alchemons/widgets/creature_instances_sheet.dart';
import 'package:alchemons/widgets/creature_selection_sheet.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/breed_cinematic_fx.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/alchemons_db.dart';
import '../../models/creature.dart';
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
  bool _isBreeding = false;

  // Remember last breeding pair for quick repeat
  String? _lastParent1InstanceId;
  String? _lastParent2InstanceId;

  late AnimationController _slot1Controller;
  late AnimationController _slot2Controller;
  late AnimationController _compatibilityController;
  late AnimationController _breedButtonController;

  late AnimationController _emptyFuseController;

  // fade controllers for pre-cinematic dissolve
  late AnimationController _preCinematicFadeController;
  late Animation<double> _spriteFadeAnim;

  late Animation<double> _orbScaleAnim;
  late Animation<double> _orbSpinSpeedAnim;

  String _familyKeyForCreature(Creature c) {
    if (c.mutationFamily != null && c.mutationFamily!.isNotEmpty) {
      return c.mutationFamily!.toUpperCase();
    }
    final match = RegExp(r'^[A-Za-z]+').firstMatch(c.id);
    final letters = match?.group(0) ?? c.id;
    return letters.toUpperCase();
  }

  Future<void> _showCrossSpeciesLockedDialog(
    BuildContext context,
    String familyA,
    String familyB,
  ) async {
    final theme = context.read<FactionTheme>();
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            'Further Research Required',
            style: TextStyle(color: theme.text),
          ),
          content: Text(
            'Your current alchemical research only supports fusion within the '
            'same lineage family.\n\n'
            'To attempt breeding between $familyA and $familyB specimens, '
            'you must first unlock the Cross-Species Lineage node in the '
            'Breeder constellation.',
            style: TextStyle(color: theme.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Mystics may only fuse with the exact same Mystic species.
  Future<void> _showMysticBreedingLockedDialog(
    BuildContext context,
    String nameA,
    String nameB,
  ) async {
    final theme = context.read<FactionTheme>();
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            'Mystic Incompatibility',
            style: TextStyle(color: theme.text),
          ),
          content: Text(
            'Mystic entities are bound to their own essence.\n\n'
            '$nameA and $nameB cannot be fused — Mystics may only '
            'breed with another of the exact same Mystic species.',
            style: TextStyle(color: theme.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

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

    // fade-out before cinematic
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

    // spin the orb if we have at least one parent
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
          // Quick-select both button when neither slot is filled
          if (selectedParent1 == null && selectedParent2 == null) ...[
            const SizedBox(height: 8),
            _buildQuickSelectButton(theme),
          ],
          // Repeat breed button when both slots empty but we have a last pair
          if (selectedParent1 == null &&
              selectedParent2 == null &&
              _lastParent1InstanceId != null &&
              _lastParent2InstanceId != null) ...[
            const SizedBox(height: 10),
            _buildRepeatBreedButton(theme),
          ],
        ],
      ),
    );
  }

  // ================== MAIN FUSION CARD ==================
  Widget _buildBreedingCard(FactionTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceAlt.withValues(alpha: .4),
        boxShadow: [
          BoxShadow(
            color: theme.surface.withValues(alpha: .2),
            blurRadius: 32,
            offset: const Offset(0, 0),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.surface.withValues(alpha: .6),
            theme.surfaceAlt.withValues(alpha: .15),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Vertical accent bar with glow
        Container(
          width: 3,
          height: 44,
          decoration: BoxDecoration(
            color: theme.accent,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: theme.accent.withValues(alpha: .5),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        // Title + subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FUSION CHAMBER',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Select two specimens to synthesize new life',
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  letterSpacing: .3,
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

        // floating fusion orb, centered between slots visually
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
      animation: Listenable.merge([controller, _preCinematicFadeController]),
      builder: (context, child) {
        final scale = isEmpty ? 1.0 : 1.0 + (controller.value * 0.03);

        // fade to 0 opacity during pre-cinematic dissolve
        final spriteOpacity = 1.0 - _spriteFadeAnim.value;

        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: () => _showBreedingPicker(targetSlot: slotIndex),
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
                                  base,
                                  inst!,
                                  genetics,
                                ),
                              ),
                      ),

                      const SizedBox(height: 18),

                      // NAME + TYPE
                      if (!isEmpty) ...[
                        Text(
                          base.name.toUpperCase(),
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
                            color: theme.textMuted.withValues(alpha: .6),
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
                            color: Colors.black.withValues(alpha: .7),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.red.withValues(alpha: .6),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: .4),
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
              border: Border.all(
                color: theme.border.withValues(alpha: .4),
                width: 2,
              ),
              gradient: RadialGradient(
                colors: [
                  theme.surfaceAlt.withValues(alpha: .2),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: .2),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.help_center_rounded,
              color: theme.textMuted.withValues(alpha: .3),
              size: 32,
            ),
          ),

          // spinning fuse ring
          AnimatedBuilder(
            animation: _emptyFuseController,
            builder: (context, _) {
              final angle = _emptyFuseController.value * 2 * math.pi;

              return Transform.rotate(
                angle: angle,
                child: CustomPaint(
                  size: const Size(96, 96),
                  painter: _FuseArcPainter(
                    color: primary,
                    thickness: 3,
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
        color: Colors.black.withValues(alpha: .3),
        border: Border.all(
          color: Colors.white.withValues(alpha: .08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .6),
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
              color: Colors.white.withValues(alpha: .4),
              size: 32,
            ),
    );
  }

  Widget _buildTypeChip(String type, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: .5), width: 1),
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
      return Stack(
        children: [
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
        ],
      );
    }

    // Case: no parents selected
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
        final spinMultiplier = _orbSpinSpeedAnim.value;
        final bothParents = hasParents;
        final speedBase = bothParents ? 2.0 : 1;

        final rotation = baseRotation * speedBase * spinMultiplier;

        final idlePulseScale = hasParents
            ? 1.0 +
                  (math.sin(_compatibilityController.value * 2 * math.pi) * 0.1)
            : 1.0;

        final chargedScale = idlePulseScale * _orbScaleAnim.value;

        Color ringColor;
        if (leftColor != null && rightColor != null) {
          ringColor = Color.lerp(
            leftColor,
            rightColor,
            0.5,
          )!.withValues(alpha: .8);
        } else if (leftColor != null) {
          ringColor = leftColor.withValues(alpha: .8);
        } else if (rightColor != null) {
          ringColor = rightColor.withValues(alpha: .8);
        } else {
          ringColor = theme.border.withValues(alpha: .4);
        }

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
                      : theme.border.withValues(alpha: .3),
                  width: 1.5,
                ),
                boxShadow: (leftColor != null || rightColor != null)
                    ? [
                        BoxShadow(
                          color: ringColor.withValues(alpha: .3),
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
    final canBreed =
        selectedParent1 != null && selectedParent2 != null && !_isBreeding;

    return AnimatedBuilder(
      animation: _breedButtonController,
      builder: (context, child) {
        final t = _breedButtonController.value;
        final pulseValue = canBreed
            ? 1.0 + (math.sin(t * 2 * math.pi) * 0.04)
            : 1.0;
        final glowAlpha = canBreed
            ? 0.4 + math.sin(t * 2 * math.pi) * 0.2
            : 0.0;

        return Transform.scale(
          scale: pulseValue,
          child: GestureDetector(
            onTap: canBreed ? _onBreedTap : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: canBreed
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [theme.accent, theme.accentSoft, theme.accent],
                        stops: const [0.0, 0.5, 1.0],
                      )
                    : null,
                color: canBreed ? null : theme.surfaceAlt.withValues(alpha: .4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: canBreed
                      ? theme.accent.withValues(alpha: .9)
                      : theme.border.withValues(alpha: .4),
                  width: canBreed ? 1.5 : 1,
                ),
                boxShadow: canBreed
                    ? [
                        BoxShadow(
                          color: theme.accent.withValues(alpha: glowAlpha),
                          blurRadius: 28,
                          spreadRadius: 6,
                        ),
                        BoxShadow(
                          color: theme.accent.withValues(alpha: glowAlpha * .4),
                          blurRadius: 52,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (canBreed) ...[
                    Icon(
                      Icons.merge_type_rounded,
                      color: Colors.black,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    canBreed ? 'INITIATE FUSION' : 'SELECT TWO SPECIMENS',
                    style: TextStyle(
                      color: canBreed
                          ? Colors.black
                          : theme.textMuted.withValues(alpha: .5),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
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

  // ================== REPEAT BREED BUTTON ==================
  Widget _buildRepeatBreedButton(FactionTheme theme) {
    return GestureDetector(
      onTap: _onRepeatBreed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: theme.surfaceAlt.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.accent.withValues(alpha: .5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.replay_rounded, color: theme.accent, size: 18),
            const SizedBox(width: 8),
            Text(
              'BREED AGAIN',
              style: TextStyle(
                color: theme.accent,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onRepeatBreed() async {
    if (_lastParent1InstanceId == null || _lastParent2InstanceId == null) {
      return;
    }
    final db = context.read<AlchemonsDatabase>();
    final inst1 = await db.creatureDao.getInstance(_lastParent1InstanceId!);
    final inst2 = await db.creatureDao.getInstance(_lastParent2InstanceId!);

    if (inst1 == null || inst2 == null) {
      _showToast(
        'Previous specimens no longer available',
        icon: Icons.warning_rounded,
        color: Colors.orange,
      );
      setState(() {
        _lastParent1InstanceId = null;
        _lastParent2InstanceId = null;
      });
      return;
    }

    setState(() {
      selectedParent1 = inst1;
      selectedParent2 = inst2;
      _updateAnimations();
    });
  }

  // ================== QUICK SELECT BOTH BUTTON ==================
  Widget _buildQuickSelectButton(FactionTheme theme) {
    return GestureDetector(
      onTap: () => _showBreedingPicker(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: theme.surfaceAlt.withValues(alpha: .3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.border.withValues(alpha: .4),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            'SELECT ALCHEMONS',
            style: TextStyle(
              color: theme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }

  // instead of calling _performBreeding() directly,
  // we first run the dissolve fade, then call _performBreeding()
  Future<void> _onBreedTap() async {
    if (selectedParent1 == null || selectedParent2 == null) return;
    if (_isBreeding) return;

    setState(() => _isBreeding = true);
    try {
      // --- Cross-species check runs BEFORE any cinematic / fade ---
      final repo = context.read<CreatureCatalog>();
      final speciesA = repo.getCreatureById(selectedParent1!.baseId);
      final speciesB = repo.getCreatureById(selectedParent2!.baseId);

      if (speciesA == null || speciesB == null) {
        _showToast('Error loading species data', color: Colors.red);
        return;
      }

      final famA = _familyKeyForCreature(speciesA);
      final famB = _familyKeyForCreature(speciesB);
      final sameFamily = famA == famB;

      // Mystic-only rule: Mystics can only breed with the EXACT same species.
      final isMysticA = speciesA.mutationFamily == 'Mystic';
      final isMysticB = speciesB.mutationFamily == 'Mystic';
      if (isMysticA || isMysticB) {
        final sameMysticSpecies =
            isMysticA && isMysticB && speciesA.id == speciesB.id;
        if (!sameMysticSpecies) {
          await _showMysticBreedingLockedDialog(
            context,
            speciesA.name,
            speciesB.name,
          );
          return;
        }
      }

      final db = context.read<AlchemonsDatabase>();
      final skills = await db.constellationDao.getUnlockedSkillIds();
      final hasCrossSpecies = skills.contains('breeder_cross_species');

      if (!sameFamily && !hasCrossSpecies) {
        if (!mounted) return;
        await _showCrossSpeciesLockedDialog(context, famA, famB);
        // Do NOT start fade / cinematic; we just bail out cleanly.
        return;
      }
      // -------------------------------------------------------------

      // play fade from 1 -> 0, orb ramps up
      await _preCinematicFadeController.forward();

      // let that max-charged orb hang briefly
      await Future.delayed(const Duration(milliseconds: 400));

      // now jump to cinematic + actual breeding
      if (!mounted) return;
      await _performBreeding();
    } finally {
      if (mounted) {
        _preCinematicFadeController.reset();
        setState(() => _isBreeding = false);
      }
    }
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
      if (!mounted) return;
      final repo = context.read<CreatureCatalog>();
      final breedingService = context.read<BreedingServiceV2>();

      final speciesA = repo.getCreatureById(selectedParent1!.baseId);
      final speciesB = repo.getCreatureById(selectedParent2!.baseId);

      if (speciesA == null || speciesB == null) {
        _showToast('Error loading species data', color: Colors.red);
        return;
      }

      final colorA = BreedConstants.getTypeColor(speciesA.types.first);
      final colorB = BreedConstants.getTypeColor(speciesB.types.first);

      Widget spriteFor(CreatureInstance inst, Creature? base) {
        if (base?.spriteData == null) {
          return Icon(
            Icons.pets,
            color: Colors.white.withValues(alpha: .8),
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

      if (!mounted) return;
      await showAlchemyFusionCinematic<void>(
        context: context,
        leftSprite: leftSprite,
        rightSprite: rightSprite,
        leftColor: colorA,
        rightColor: colorB,
        minDuration: const Duration(milliseconds: 1800),
        task: () async {
          // Service now handles breeding + analysis in one go.
          final result = await breedingService.breedInstances(
            selectedParent1!,
            selectedParent2!,
          );

          if (!result.success) {
            _showToast(
              'Genetic incompatibility detected',
              icon: Icons.warning_rounded,
              color: Colors.orange,
            );
            throw Exception('Incompatible');
          }

          if (result.placement == EggPlacement.storage) {
            _showToast(
              'Incubator full — specimen transferred to storage',
              icon: Icons.inventory_2_rounded,
              color: Colors.orange,
            );
          } else if (result.placement == EggPlacement.incubator) {
            _showToast(
              'Specimen placed in incubation chamber ${(result.slotId ?? 0) + 1}',
              icon: Icons.science_rounded,
              color: const Color.fromARGB(255, 239, 255, 92),
            );
          }

          // Handle stamina cost with faction perks
          await _handleStaminaCost(
            selectedParent1!,
            selectedParent2!,
            speciesA,
            speciesB,
          );
        },
      );

      if (!mounted) return;

      setState(() {
        // Save last pair for repeat breeding
        _lastParent1InstanceId = selectedParent1?.instanceId;
        _lastParent2InstanceId = selectedParent2?.instanceId;
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

  /// Handle stamina costs with faction-specific perks
  Future<void> _handleStaminaCost(
    CreatureInstance parent1,
    CreatureInstance parent2,
    Creature speciesA,
    Creature speciesB,
  ) async {
    final stamina = context.read<StaminaService>();
    final factions = context.read<FactionService>();

    // Check for Water faction perk (skip stamina cost)
    final bothWater =
        speciesA.types.contains('Water') && speciesB.types.contains('Water');

    final skipStamina = factions.waterSkipBreedStamina(
      bothWater: bothWater,
      perk1: factions.perk1Active && factions.isWater(),
    );

    // 50% chance to skip if perk is active
    if (skipStamina && Random().nextBool()) {
      return; // Lucky! No stamina cost
    }

    // Spend stamina normally WITH creature data for nature modifiers
    await stamina.spendForBreeding(
      parent1.instanceId,
      instanceOverlayForNature: speciesA,
    );
    await stamina.spendForBreeding(
      parent2.instanceId,
      instanceOverlayForNature: speciesB,
    );
  }

  void _applyBreedingPicks(
    CreatureInstance? parent1,
    CreatureInstance? parent2,
  ) {
    if (!mounted) return;
    setState(() {
      selectedParent1 = parent1;
      selectedParent2 = parent2;
      _updateAnimations();
    });
  }

  // ================== PERSISTENT BREEDING PICKER ==================
  // targetSlot == null => pick both (quick-select flow)
  // targetSlot != null => pick only that slot and close.
  void _showBreedingPicker({int? targetSlot}) async {
    final pickBoth = targetSlot == null;
    final db = context.read<AlchemonsDatabase>();
    final available = await db.creatureDao.getSpeciesWithInstances();

    final filteredDiscovered = filterByAvailableInstances(
      widget.discoveredCreatures,
      available,
    );

    if (!mounted) return;

    // Seed from current selections so tapping a filled slot continues naturally
    CreatureInstance? tempPick1 = selectedParent1;
    CreatureInstance? tempPick2 = selectedParent2;

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (_, setSheetState) {
            String sheetTitle() {
              if (!pickBoth) {
                return targetSlot == 1
                    ? 'Select Specimen A'
                    : 'Select Specimen B';
              }
              final needsA = tempPick1 == null;
              final needsB = tempPick1 != null && tempPick2 == null;
              if (needsA) return 'Select Specimen A';
              if (needsB) return 'Specimen A Selected • Select Specimen B';
              return 'Both Selected';
            }

            List<String> blockedIds() {
              if (pickBoth) {
                return [
                  if (tempPick1 != null) tempPick1!.instanceId,
                  if (tempPick2 != null) tempPick2!.instanceId,
                ];
              }
              if (targetSlot == 1) {
                return [if (tempPick2 != null) tempPick2!.instanceId];
              }
              return [if (tempPick1 != null) tempPick1!.instanceId];
            }

            bool applyPickedInstance(CreatureInstance instance) {
              if (!pickBoth) {
                if (targetSlot == 1) {
                  tempPick1 = instance;
                } else {
                  tempPick2 = instance;
                }
                _applyBreedingPicks(tempPick1, tempPick2);
                if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                return true;
              }

              if (tempPick1 == null) {
                tempPick1 = instance;
                setSheetState(() {});
                return false;
              } else {
                tempPick2 ??= instance;
              }

              if (tempPick1 != null && tempPick2 != null) {
                _applyBreedingPicks(tempPick1, tempPick2);
                if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                return true;
              }

              setSheetState(() {});
              return false;
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollController) {
                return CreatureSelectionSheet(
                  scrollController: scrollController,
                  discoveredCreatures: filteredDiscovered,
                  showOnlyAvailableTypes: true,
                  title: sheetTitle(),
                  selectedInstanceIds: [
                    if (tempPick1 != null) tempPick1!.instanceId,
                    if (tempPick2 != null) tempPick2!.instanceId,
                  ],
                  onSelectInstance: (instance) async {
                    // --- Toggle off if already selected (dual-pick only) ---
                    if (pickBoth) {
                      if (tempPick1?.instanceId == instance.instanceId) {
                        tempPick1 = null;
                        setSheetState(() {});
                        return;
                      }
                      if (tempPick2?.instanceId == instance.instanceId) {
                        tempPick2 = null;
                        setSheetState(() {});
                        return;
                      }
                    }

                    // --- Stamina check ---
                    final stamina = context.read<StaminaService>();
                    final refreshed = await stamina.refreshAndGet(
                      instance.instanceId,
                    );
                    if ((refreshed?.staminaBars ?? 0) < 1) {
                      final perBar = stamina.regenPerBar;
                      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
                      final last = refreshed?.staminaLastUtcMs ?? now;
                      final elapsed = now - last;
                      final remMs =
                          perBar.inMilliseconds -
                          (elapsed % perBar.inMilliseconds);
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

                    final blocked = blockedIds();
                    if (blocked.contains(instance.instanceId)) {
                      return;
                    }

                    applyPickedInstance(instance);
                  },
                  onSelectCreature: (creatureId) async {
                    // Species-grid tap → open instance picker ON TOP (stacked)
                    final repo = context.read<CreatureCatalog>();
                    final species = repo.getCreatureById(creatureId);
                    if (species == null) return;

                    _showInstancePickerStacked(
                      species: species,
                      blockedIds: blockedIds(),
                      selectedIds: [
                        if (tempPick1 != null) tempPick1!.instanceId,
                        if (tempPick2 != null) tempPick2!.instanceId,
                      ],
                      onPicked: (inst) {
                        return applyPickedInstance(inst);
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  /// Opens an instance picker that stacks ON TOP of the main breeding sheet.
  /// When the user picks one, it pops itself and calls [onPicked].
  void _showInstancePickerStacked({
    required Creature species,
    required List<String> blockedIds,
    required List<String> selectedIds,
    required bool Function(CreatureInstance inst) onPicked,
  }) {
    final theme = context.read<FactionTheme>();
    var liveSelectedIds = List<String>.from(selectedIds);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (pickerCtx) {
        return StatefulBuilder(
          builder: (context, setPickerState) {
            return BottomSheetShell(
              theme: theme,
              title: '${species.name} Specimens',
              child: InstancesSheet(
                species: species,
                theme: theme,
                selectedInstanceIds: liveSelectedIds,
                onTap: (CreatureInstance inst) async {
                  // --- Already-selected guard ---
                  if (blockedIds.contains(inst.instanceId)) {
                    return;
                  }
                  if (liveSelectedIds.contains(inst.instanceId)) {
                    return;
                  }

                  // --- Stamina check ---
                  final stamina = context.read<StaminaService>();
                  final refreshed = await stamina.refreshAndGet(
                    inst.instanceId,
                  );
                  if ((refreshed?.staminaBars ?? 0) < 1) {
                    final perBar = stamina.regenPerBar;
                    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
                    final last = refreshed?.staminaLastUtcMs ?? now;
                    final elapsed = now - last;
                    final remMs =
                        perBar.inMilliseconds -
                        (elapsed % perBar.inMilliseconds);
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
                  final shouldClose = onPicked(inst);
                  if (shouldClose) {
                    if (pickerCtx.mounted) {
                      Navigator.of(pickerCtx).pop();
                    }
                    return;
                  }

                  if (!liveSelectedIds.contains(inst.instanceId)) {
                    setPickerState(() {
                      liveSelectedIds = [...liveSelectedIds, inst.instanceId];
                    });
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showToast(
    String message, {
    IconData icon = Icons.info_rounded,
    Color? color,
    bool fromTop = false,
  }) {
    if (!mounted) return;
    final theme = context.read<FactionTheme>();
    final accent = color ?? theme.accent;
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.surface.withValues(alpha: .98),
                theme.surfaceAlt.withValues(alpha: .96),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withValues(alpha: .8), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: .2),
                blurRadius: 14,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: theme.text,
                  ),
                ),
              ),
            ],
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        padding: EdgeInsets.zero,
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
      ..color = color.withValues(alpha: .3)
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
      ..color = color.withValues(alpha: .2)
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
      path.addArc(
        Rect.fromLTWH(0, 0, size.width, size.height),
        math.pi / 2,
        math.pi,
      );
    } else {
      path.addArc(
        Rect.fromLTWH(0, 0, size.width, size.height),
        -math.pi / 2,
        math.pi,
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
  final double sweepRadians;

  _FuseArcPainter({
    required this.color,
    required this.thickness,
    this.sweepRadians = math.pi / 3,
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
