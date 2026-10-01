import 'dart:math' as math;
import 'dart:math';
import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart'
    show kCompanionSpeciesScale;
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/breeding_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/all_specimens_page.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/breed_cinematic_fx.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:provider/provider.dart';

import '../../database/alchemons_db.dart';
import '../../models/creature.dart';
import '../../services/creature_repository.dart';
import 'package:alchemons/widgets/app_icons.dart';

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

  // Outcome banner captured during the fusion cinematic, surfaced once after.
  _PendingToast? _pendingFusionToast;

  // Remember last breeding pair for quick repeat
  String? _lastParent1InstanceId;
  String? _lastParent2InstanceId;

  late AnimationController _slot1Controller;
  late AnimationController _slot2Controller;
  late AnimationController _compatibilityController;
  late AnimationController _breedButtonController;

  late AnimationController _emptyFuseController;

  /// Runs the merge in the chamber, before the cinematic opens.
  late AnimationController _preCinematicFadeController;

  /// The merge, in particles: both specimens read into grains at the tap,
  /// then poured into the orb. Null when no merge is running.
  FusionParticleField? _fusionField;

  /// Seconds into the merge.
  double get _mergeTime =>
      _preCinematicFadeController.value * FusionParticleField.duration;

  late Animation<double> _orbScaleAnim;

  /// The orb and the line through it, going as the grains pour in.
  late Animation<double> _orbFadeAnim;
  late Animation<double> _orbSpinSpeedAnim;

  // Keys to capture on-screen chamber positions so the fusion cinematic can
  // anchor itself to the live screen.
  final GlobalKey _slot1AvatarKey = GlobalKey();
  final GlobalKey _slot2AvatarKey = GlobalKey();
  final GlobalKey _orbKey = GlobalKey();

  // What each specimen is read into grains from, and the stack the grains
  // are painted in.
  /// A specimen put into a chamber gathers there out of its element. Each
  /// pick gets its own ticket, so the chambers coming back into view later
  /// just show what is in them.
  EssenceReveal? _slot1Reveal, _slot2Reveal;

  final GlobalKey _slot1CaptureKey = GlobalKey();
  final GlobalKey _slot2CaptureKey = GlobalKey();
  final GlobalKey _slotsStackKey = GlobalKey();

  /// How tall the specimen's part of a chamber is, filled or empty, so
  /// choosing a specimen never moves its name.
  static const double _avatarZone = 170;

  /// A sprite frame this wide per unit of family scale: a let (1.1) stands
  /// 115 across, a wing (2.0) 209, a mystic (2.4) 251.
  static const double _framePerFamilyScale = 104.5;

  /// How big a specimen stands in its chamber, as its sprite frame before
  /// its size gene: the size its family is drawn at in cosmic space and
  /// survival ([kCompanionSpeciesScale]), so a wing is as much bigger than a
  /// let here as it is out there.
  static double _chamberFrame(Creature c) {
    final family = (c.mutationFamily ?? '').toLowerCase();
    return _framePerFamilyScale *
        (_chamberFamilyScale[family] ?? kCompanionSpeciesScale[family] ?? 1.0);
  }

  /// Where the chamber departs from that table: a mask at its full 1.5 stood
  /// too big beside its partner here.
  static const Map<String, double> _chamberFamilyScale = {'mask': 1.3};

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
            'Alchemy constellation.',
            style: TextStyle(color: theme.text),
          ),
          actions: [
            TextButton(
              onPressed: context.soundAction(() => Navigator.of(ctx).pop()),
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
            '$nameA and $nameB cannot be fused, Mystics may only '
            'breed with another of the exact same Mystic species.',
            style: TextStyle(color: theme.text),
          ),
          actions: [
            TextButton(
              onPressed: context.soundAction(() => Navigator.of(ctx).pop()),
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

    // THE MERGE, performed in the chamber itself, so the route that follows
    // never has to draw a copy of anything.
    //
    // Each specimen is read into grains where it stands and swapped for
    // them under a line of sparkle — the same shape, the same markings, made
    // of particles — and the grains are poured into the orb, the two
    // winding through each other, until it takes them in. The timeline is
    // the field's; this controller just runs it.
    _preCinematicFadeController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: (FusionParticleField.duration * 1000).round(),
      ),
    );

    // The orb is fed a little as the grains start to arrive, and is gone by
    // the time they have: the cloud of the two of them is the fusion, as it
    // is in the wild where there is no orb at all. Left standing, it sat at
    // double size under the cloud with the grains falling into a gradient.
    _orbScaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 34),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.2,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(tween: ConstantTween(1.2), weight: 36),
    ]).animate(_preCinematicFadeController);
    _orbFadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _preCinematicFadeController,
        curve: const Interval(0.42, 0.72, curve: Curves.easeIn),
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
                  fontSize: 12,
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

    final field = _fusionField;
    return Stack(
      key: _slotsStackKey,
      clipBehavior: Clip.none,
      children: [
        // animated DNA line
        if (hasParents)
          FadeTransition(
            opacity: _orbFadeAnim,
            child: _buildDNAConnection(theme),
          ),

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
                avatarKey: _slot1AvatarKey,
                captureKey: _slot1CaptureKey,
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
                avatarKey: _slot2AvatarKey,
                captureKey: _slot2CaptureKey,
              ),
            ),
          ],
        ),

        // The merge's grains on the far side of the orb, under it. Always
        // in the tree (painting nothing between merges) so adding it never
        // shuffles the orb's place in this stack.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: field == null
                  ? null
                  : FusionParticlePainter(
                      field,
                      () => _mergeTime,
                      back: true,
                      repaint: _preCinematicFadeController,
                    ),
            ),
          ),
        ),

        // floating fusion orb, centered between slots visually
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: KeyedSubtree(
                key: _orbKey,
                child: _buildFusionIndicator(
                  theme: theme,
                  hasParents: hasParents,
                  leftColor: colorA,
                  rightColor: colorB,
                ),
              ),
            ),
          ),
        ),

        // ...and everything else of it, over the orb and the chambers.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: field == null
                  ? null
                  : FusionParticlePainter(
                      field,
                      () => _mergeTime,
                      back: false,
                      repaint: _preCinematicFadeController,
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
    GlobalKey? avatarKey,
    GlobalKey? captureKey,
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
        // THE MERGE happens to this widget's own sprite: it is cut away
        // behind the crest as its grains take its place, and the chamber
        // empties as they are poured into the orb.
        final field = _fusionField;
        final side = slotIndex - 1;
        final t = _mergeTime;
        final cutY = field?.cutY(side, t);
        // With no field (the chamber could not be measured) the sprite just
        // fades, as it used to.
        final emptied =
            field?.chamberEmpty(side, t) ??
            Curves.easeIn.transform(_preCinematicFadeController.value);

        // The CARD only breathes; the merge belongs to the sprite alone.
        final scale = isEmpty ? 1.0 : 1.0 + (controller.value * 0.03);

        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            // Mid-merge the specimen is already grains; swapping it out
            // from under them would leave the merge pouring a creature that
            // is no longer there.
            onTap: context.soundAction(
              _isBreeding
                  ? null
                  : () => _showBreedingPicker(targetSlot: slotIndex),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              height: 270,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
              ),
              child: LayoutBuilder(
                builder: (context, box) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // CONTENT COLUMN
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // SPRITE ZONE
                        //
                        // The merge belongs to the sprite and nothing else:
                        // the name and element chip stay with the chamber.
                        Center(
                          key: avatarKey,
                          child: isEmpty
                              ? _buildEmptyAvatar(theme)
                              : _buildCreatureAvatar(
                                  base,
                                  inst!,
                                  genetics,
                                  captureKey: captureKey,
                                  // Never so big it spills out of its chamber
                                  // (a giant mystic on a narrow phone): the
                                  // body is about 60% of its frame.
                                  maxFrame: box.maxWidth * 1.5,
                                  cutY: cutY,
                                  emptied: emptied,
                                  spriteOpacity: field == null
                                      ? 1.0 - emptied
                                      : 1.0,
                                  reveal: slotIndex == 1
                                      ? _slot1Reveal
                                      : _slot2Reveal,
                                ),
                        ),

                        const SizedBox(height: 18),

                        // NAME + TYPE — they belong to the chamber, not to the
                        // specimen, so they stay put and dim as it is drawn out.
                        if (!isEmpty) ...[
                          Opacity(
                            opacity: (1.0 - emptied).clamp(0.0, 1.0),
                            child: Column(
                              children: [
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
                              ],
                            ),
                          ),
                        ] else ...[
                          Text(
                            'Tap to select',
                            style: TextStyle(
                              color: theme.textMuted.withValues(alpha: .6),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),

                    // CLOSE BUTTON (ONLY WHEN FILLED)
                    if (!isEmpty)
                      Positioned(
                        right: -8,
                        top: -18,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: context.soundAction(
                            _isBreeding
                                ? null
                                : () {
                                    setState(() {
                                      if (slotIndex == 1) {
                                        selectedParent1 = null;
                                      } else {
                                        selectedParent2 = null;
                                      }
                                      _updateAnimations();
                                    });
                                  },
                          ),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: .78),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.red.withValues(alpha: .68),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withValues(alpha: .38),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  AppIcons.close,
                                  color: Colors.red,
                                  size: 14,
                                ),
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
    );
  }

  // empty avatar — alchemical summoning circle
  Widget _buildEmptyAvatar(FactionTheme theme) {
    final primary = Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: _avatarZone,
      child: Center(
        child: SizedBox(
          width: 104,
          height: 104,
          child: AnimatedBuilder(
            animation: _emptyFuseController,
            builder: (context, _) {
              return CustomPaint(
                painter: _SummoningCirclePainter(
                  color: theme.border.withValues(alpha: .45),
                  accentColor: primary,
                  glowColor: primary.withValues(alpha: .06),
                  progress: _emptyFuseController.value,
                  showOrbit: true,
                ),
                child: Center(
                  child: Icon(
                    AppIcons.help_center_rounded,
                    color: theme.textMuted.withValues(alpha: .25),
                    size: 28,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // live animated sprite inside summoning circle frame
  /// The specimen and the circle it stands in.
  ///
  /// It stands at its family's size ([_chamberFrame]) times its size gene,
  /// up to [maxFrame], and the circle under it grows with it.
  ///
  /// They part during a merge: the SUMMONING CIRCLE belongs to the chamber
  /// and stays, dimming as the chamber empties ([emptied]), while the sprite
  /// is cut away from the top down ([cutY], from the capture box's centre)
  /// as its grains take its place.
  ///
  /// The sprite sits in a repaint boundary ([captureKey]) a little bigger
  /// than it, so it can be read into grains exactly as it is showing. The
  /// tree here is the same whether or not a merge is running, so starting
  /// one never rebuilds the sprite underneath it.
  Widget _buildCreatureAvatar(
    Creature base,
    CreatureInstance inst,
    Genetics? genetics, {
    GlobalKey? captureKey,
    double maxFrame = double.infinity,
    double? cutY,
    double emptied = 0,
    double spriteOpacity = 1,
    EssenceReveal? reveal,
  }) {
    final typeColor = BreedConstants.getTypeColor(base.types.first);
    // The sprite's own widget draws its frame 69 across and then applies the
    // size gene, so the family size goes on as a scale around it.
    final gene = scaleFromGenes(genetics);
    final frame = math.min(_chamberFrame(base) * gene, maxFrame);
    final sprite = base.spriteData != null
        ? Transform.scale(
            scale: frame / gene / 69,
            child: InstanceSprite(creature: base, instance: inst, size: 64),
          )
        : Icon(
            AppIcons.image_not_supported_rounded,
            color: Colors.white.withValues(alpha: .4),
            size: 32,
          );
    final captureBox = (frame * 1.12).ceilToDouble();
    final circle = (frame * 0.62).clamp(104.0, 150.0);
    final cut = cutY ?? double.negativeInfinity;
    // Gone once the crest has passed; nothing left to draw.
    final opacity = cut == double.infinity ? 0.0 : spriteOpacity;

    return SizedBox(
      width: 104,
      height: _avatarZone,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: (1.0 - emptied * 0.9).clamp(0.0, 1.0),
            child: OverflowBox(
              maxWidth: circle,
              maxHeight: circle,
              child: SizedBox.square(
                dimension: circle,
                child: CustomPaint(
                  painter: _SummoningCirclePainter(
                    color: typeColor.withValues(alpha: .5),
                    accentColor: typeColor,
                    glowColor: typeColor.withValues(alpha: .08),
                    progress: 0,
                    showOrbit: false,
                  ),
                ),
              ),
            ),
          ),
          OverflowBox(
            maxWidth: captureBox,
            maxHeight: captureBox,
            child: ClipRect(
              clipper: SpriteCrestClipper(cut),
              clipBehavior: cut == double.negativeInfinity
                  ? Clip.none
                  : Clip.hardEdge,
              child: RepaintBoundary(
                key: captureKey,
                child: SizedBox.square(
                  dimension: captureBox,
                  child: Center(
                    child: Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: SizedBox(
                        width: 68,
                        height: 68,
                        child: base.spriteData == null
                            ? sprite
                            : ElementalEssence(
                                key: ValueKey(inst.instanceId),
                                element: base.types.first,
                                dark: context.read<FactionTheme>().isDark,
                                reveal: reveal,
                                // A tap on the chamber picks its specimen.
                                tappable: false,
                                // The sprite is scaled up past this box to
                                // its family size; read all of it.
                                captureScale: captureBox / 68,
                                child: sprite,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
          fontSize: 12,
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

        return Opacity(
          opacity: _orbFadeAnim.value,
          child: Transform.scale(
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
            onTap: context.soundAction(canBreed ? _onBreedTap : null),
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
                      AppIcons.merge_type_rounded,
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
      onTap: context.soundAction(_onRepeatBreed),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: theme.surfaceAlt.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: theme.accent.withValues(alpha: .5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.replay_rounded, color: theme.accent, size: 18),
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
        icon: AppIcons.warning_rounded,
        color: Colors.orange,
      );
      setState(() {
        _lastParent1InstanceId = null;
        _lastParent2InstanceId = null;
      });
      return;
    }

    setState(() {
      _revealNewPicks(inst1, inst2);
      selectedParent1 = inst1;
      selectedParent2 = inst2;
      _updateAnimations();
    });
  }

  // ================== QUICK SELECT BOTH BUTTON ==================
  Widget _buildQuickSelectButton(FactionTheme theme) {
    return GestureDetector(
      onTap: context.soundAction(() => _showBreedingPicker()),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: theme.surfaceAlt.withValues(alpha: .3),
          borderRadius: BorderRadius.circular(4),
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
    // Read the specimens into grains now, while the refusals below are
    // checked, so the merge does not wait on it. Thrown away if one says no.
    final grains = _captureSpecimens();
    try {
      // --- Cross-species check runs BEFORE any cinematic / fade ---
      final repo = context.read<CreatureCatalog>();
      final breedingService = context.read<BreedingServiceV2>();
      final speciesA = repo.getCreatureById(selectedParent1!.baseId);
      final speciesB = repo.getCreatureById(selectedParent2!.baseId);

      if (speciesA == null || speciesB == null) {
        _showToast('Error loading species data', color: Colors.red);
        return;
      }

      // Stamina belongs up here with the other refusals. It was checked
      // inside _performBreeding, which runs after the dissolve fade — so a
      // resting specimen played the whole wind-up and then said no.
      final stamina = context.read<StaminaService>();
      final restedA = await stamina.canBreed(selectedParent1!.instanceId);
      final restedB = await stamina.canBreed(selectedParent2!.instanceId);
      if (!restedA || !restedB) {
        _showToast(
          !restedA && !restedB
              ? 'Both specimens are resting'
              : (!restedA ? 'Specimen A is resting' : 'Specimen B is resting'),
          icon: AppIcons.hourglass_bottom_rounded,
          color: Colors.orange,
        );
        return;
      }
      if (!mounted) return;

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

      final placementFailure = await breedingService
          .getEggPlacementFailureMessage();
      if (placementFailure != null) {
        _showToast(
          placementFailure,
          icon: AppIcons.inventory_2_rounded,
          color: Colors.orange,
        );
        return;
      }
      // -------------------------------------------------------------

      // The specimens turn to grains and are poured into the orb, on the
      // real chamber. Measured from the layout as it is right now: it is
      // responsive, so none of this can be a constant.
      final read = await grains;
      if (!mounted) return;
      setState(
        () => _fusionField = _buildFusionField(read, speciesA, speciesB),
      );
      context.sound(SoundCue.breedingStart, owner: this);
      await _preCinematicFadeController.forward();

      // let that max-charged orb hang briefly
      await Future.delayed(const Duration(milliseconds: 140));

      // now jump to cinematic + actual breeding
      if (!mounted) return;
      await _performBreeding();
    } finally {
      if (mounted) {
        _preCinematicFadeController.reset();
        setState(() {
          _isBreeding = false;
          _fusionField = null;
        });
      }
    }
  }

  /// Reads both chamber sprites into grains, exactly as they are showing.
  /// A specimen that cannot be read comes back null.
  Future<List<SpecimenGrains?>> _captureSpecimens() async {
    final ratio = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);
    // Between frames, so nothing in the box is waiting to be repainted.
    await WidgetsBinding.instance.endOfFrame;
    Future<SpecimenGrains?> read(GlobalKey key) async {
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderRepaintBoundary || !box.attached) return null;
      try {
        return await SpecimenGrains.capture(box, pixelRatio: ratio);
      } catch (e) {
        debugPrint('fusion: could not read a specimen into grains: $e');
        return null;
      }
    }

    return Future.wait([read(_slot1CaptureKey), read(_slot2CaptureKey)]);
  }

  /// The merge, laid out on the chamber as it is right now. Null if the
  /// chamber is not laid out, in which case the sprites simply fade.
  FusionParticleField? _buildFusionField(
    List<SpecimenGrains?> grains,
    Creature speciesA,
    Creature speciesB,
  ) {
    RenderBox? boxOf(GlobalKey key) {
      final box = key.currentContext?.findRenderObject();
      return box is RenderBox && box.attached && box.hasSize ? box : null;
    }

    final stack = boxOf(_slotsStackKey);
    final orb = boxOf(_orbKey);
    if (stack == null || orb == null) return null;
    final centres = <Offset>[];
    final scales = <double>[];
    for (final key in [_slot1CaptureKey, _slot2CaptureKey]) {
      final box = boxOf(key);
      if (box == null) return null;
      // Through any transform above it (the slot breathes at 1.03).
      final tl = box.localToGlobal(Offset.zero);
      final br = box.localToGlobal(box.size.bottomRight(Offset.zero));
      centres.add(stack.globalToLocal((tl + br) / 2));
      scales.add((br.dx - tl.dx) / box.size.width);
    }
    final colorA = BreedConstants.getTypeColor(speciesA.types.first);
    final colorB = BreedConstants.getTypeColor(speciesB.types.first);
    return FusionParticleField(
      specimens: [
        grains[0] ?? SpecimenGrains.disc(colorA),
        grains[1] ?? SpecimenGrains.disc(colorB),
      ],
      centres: centres,
      scales: scales,
      core: stack.globalToLocal(
        orb.localToGlobal(orb.size.center(Offset.zero)),
      ),
      // A cloud a little wider than the orb, so it shows through the gaps.
      coreRadius: orb.size.width / 2 * 1.7,
      colors: [colorA, colorB],
      darkBackdrop: context.read<FactionTheme>().isDark,
    );
  }

  // Resolve a keyed widget's bounds in global screen coordinates, so the
  // fusion cinematic can anchor itself to the live chamber slots / orb.
  Rect? _globalRectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  // Map a breeding outcome to the cinematic's reveal flourish: standard
  // fusion, a pure new element, a pure lineage, or both.
  FusionRevealData _buildRevealData(
    Creature? offspring,
    PureBreedingInfo? pure,
    Color colorA,
    Color colorB,
  ) {
    final mix = Color.lerp(colorA, colorB, .5)!;
    if (pure == null) {
      return FusionRevealData(kind: FusionRevealKind.standard, accent: mix);
    }

    const gold = Color(0xFFFFC34D);
    final isElement = pure.elementName != null;
    final isSpecies = pure.familyName != null;
    final element = offspring != null && offspring.types.isNotEmpty
        ? offspring.types.first
        : pure.elementName;
    final elementColor = element != null
        ? BreedConstants.getTypeColor(element)
        : mix;
    final elementUpper = (element ?? 'PURE').toUpperCase();

    if (isElement && isSpecies) {
      return FusionRevealData(
        kind: FusionRevealKind.pureBoth,
        accent: Color.lerp(gold, elementColor, .35)!,
        element: element?.toLowerCase(),
        foundedNewLine: pure.foundedNewLine,
        caption: pure.foundedNewLine
            ? 'PURE LINE ESTABLISHED'
            : 'PURE SYNTHESIS',
      );
    }
    if (isElement) {
      return FusionRevealData(
        kind: FusionRevealKind.pureElement,
        accent: elementColor,
        element: element?.toLowerCase(),
        foundedNewLine: pure.foundedNewElementLine,
        caption: pure.foundedNewElementLine
            ? 'NEW $elementUpper LINEAGE'
            : 'PURE $elementUpper',
      );
    }
    return FusionRevealData(
      kind: FusionRevealKind.pureSpecies,
      accent: gold,
      foundedNewLine: pure.foundedNewFamilyLine,
      caption: pure.foundedNewFamilyLine
          ? 'NEW LINEAGE FOUNDED'
          : 'PURE LINEAGE',
    );
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
        icon: AppIcons.hourglass_bottom_rounded,
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
            AppIcons.pets,
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
      // Resolved mid-cinematic so the climax matches what was actually bred.
      final outcomeNotifier = ValueNotifier<FusionRevealData?>(null);
      final didBreed = await showAlchemyFusionCinematic<bool>(
        context: context,
        leftSprite: leftSprite,
        rightSprite: rightSprite,
        // The chamber already merged the live ones; a second pair drawn here
        // would be the duplicate.
        drawSpecimens: false,
        leftColor: colorA,
        rightColor: colorB,
        leftSlotRect: _globalRectOf(_slot1AvatarKey),
        rightSlotRect: _globalRectOf(_slot2AvatarKey),
        coreRect: _globalRectOf(_orbKey),
        outcome: outcomeNotifier,
        // The eruption is made of what the pair were just poured as.
        grains: _fusionField?.specimens,
        // Shorter than the old 4350: the intake, the charge and the haul
        // together now happen for real in the chamber before this opens, so
        // the route only has the eruption and the reveal left to play.
        minDuration: const Duration(milliseconds: 2800),
        task: () async {
          // Service now handles breeding + analysis in one go.
          final result = await breedingService.breedInstances(
            selectedParent1!,
            selectedParent2!,
          );

          if (!result.success) {
            _pendingFusionToast = _PendingToast(
              result.message ?? 'Breeding failed',
              icon: AppIcons.warning_rounded,
              color: Colors.orange,
            );
            return false;
          }

          // Tell the cinematic what was created so it can play the right reveal.
          outcomeNotifier.value = _buildRevealData(
            repo.getCreatureById(result.creatureId ?? ''),
            result.pureBreedingInfo,
            colorA,
            colorB,
          );

          if (result.placement == EggPlacement.storage) {
            _pendingFusionToast = _PendingToast(
              'Incubator full. Specimen transferred to cold storage',
              icon: AppIcons.inventory_2_rounded,
              color: Colors.orange,
            );
          } else if (result.placement == EggPlacement.incubator) {
            _pendingFusionToast = _PendingToast(
              'Specimen placed in incubation chamber ${(result.slotId ?? 0) + 1}',
              icon: AppIcons.science_rounded,
            );
          }

          // Handle stamina cost with faction perks
          await _handleStaminaCost(
            selectedParent1!,
            selectedParent2!,
            speciesA,
            speciesB,
          );

          return true;
        },
      );

      outcomeNotifier.dispose();

      // Surface the outcome once, after the cinematic, so it is actually
      // visible (not hidden behind the overlay) and can't double-fire.
      final pending = _pendingFusionToast;
      _pendingFusionToast = null;
      if (pending != null) {
        _showToast(pending.message, icon: pending.icon, color: pending.color);
      }

      if (didBreed != true) return;
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
      _showToast(
        'Fusion protocol error: $e',
        color: Colors.red,
        icon: AppIcons.error_rounded,
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

  /// New tickets for whichever chambers are getting a different specimen.
  void _revealNewPicks(CreatureInstance? parent1, CreatureInstance? parent2) {
    if (parent1 != null && parent1.instanceId != selectedParent1?.instanceId) {
      _slot1Reveal = EssenceReveal.once();
    }
    if (parent2 != null && parent2.instanceId != selectedParent2?.instanceId) {
      _slot2Reveal = EssenceReveal.once();
    }
  }

  void _applyBreedingPicks(
    CreatureInstance? parent1,
    CreatureInstance? parent2,
  ) {
    if (!mounted) return;
    setState(() {
      _revealNewPicks(parent1, parent2);
      selectedParent1 = parent1;
      selectedParent2 = parent2;
      _updateAnimations();
    });
  }

  // ================== PERSISTENT BREEDING PICKER ==================
  // targetSlot == null => pick both (quick-select flow)
  // targetSlot != null => pick only that slot and close.
  void _showBreedingPicker({int? targetSlot}) async {
    var nextParent1 = selectedParent1;
    var nextParent2 = selectedParent2;

    if (targetSlot != null) {
      final picked = await _pickBreedingInstance(
        searchHint: targetSlot == 1 ? 'SELECT SPECIMEN A' : 'SELECT SPECIMEN B',
        selectedIds: [
          if (nextParent1 != null) nextParent1.instanceId,
          if (nextParent2 != null) nextParent2.instanceId,
        ],
        blockedIds: [
          if (targetSlot == 1 && nextParent2 != null) nextParent2.instanceId,
          if (targetSlot == 2 && nextParent1 != null) nextParent1.instanceId,
        ],
      );
      if (picked == null) return;

      if (targetSlot == 1) {
        nextParent1 = picked;
      } else {
        nextParent2 = picked;
      }
      _applyBreedingPicks(nextParent1, nextParent2);
      return;
    }

    if (nextParent1 == null) {
      final picked = await _pickBreedingInstance(
        searchHint: 'SELECT SPECIMEN A',
        selectedIds: [if (nextParent2 != null) nextParent2.instanceId],
        blockedIds: [if (nextParent2 != null) nextParent2.instanceId],
      );
      if (picked == null) return;
      nextParent1 = picked;
      _applyBreedingPicks(nextParent1, nextParent2);
    }

    if (nextParent2 == null) {
      final picked = await _pickBreedingInstance(
        searchHint: 'SELECT SPECIMEN B',
        selectedIds: [nextParent1.instanceId],
        blockedIds: [nextParent1.instanceId],
      );
      if (picked == null) {
        _applyBreedingPicks(nextParent1, nextParent2);
        return;
      }
      nextParent2 = picked;
    }

    _applyBreedingPicks(nextParent1, nextParent2);
  }

  Future<CreatureInstance?> _pickBreedingInstance({
    required String searchHint,
    required List<String> selectedIds,
    required List<String> blockedIds,
  }) {
    final theme = context.read<FactionTheme>();
    return Navigator.of(context).push<CreatureInstance>(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) =>
            AllSpecimensPage(
              theme: theme,
              instancePrefsScopeKey: 'breed_specimens',
              popOnSelect: true,
              searchHint: searchHint,
              selectedInstanceIds: selectedIds,
              onWillSelectInstance: (inst) =>
                  _validateBreedingSelection(inst, blockedIds: blockedIds),
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final tween = Tween(
            begin: const Offset(0.0, 1.0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  Future<bool> _validateBreedingSelection(
    CreatureInstance instance, {
    required List<String> blockedIds,
  }) async {
    if (blockedIds.contains(instance.instanceId)) {
      _showToast(
        'That specimen is already selected',
        icon: AppIcons.block_rounded,
        color: Colors.orange,
        fromTop: true,
      );
      return false;
    }

    final stamina = context.read<StaminaService>();
    final refreshed = await stamina.refreshAndGet(instance.instanceId);
    if ((refreshed?.staminaBars ?? 0) >= 1) {
      return true;
    }

    final perBar = stamina.regenPerBar;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final last = refreshed?.staminaLastUtcMs ?? now;
    final elapsed = now - last;
    final remMs = perBar.inMilliseconds - (elapsed % perBar.inMilliseconds);
    final mins = (remMs / 60000).ceil();
    _showToast(
      'Specimen is resting, next stamina in ~${mins}m',
      icon: AppIcons.hourglass_bottom_rounded,
      color: Colors.orange,
      fromTop: true,
    );
    return false;
  }

  // Guard against the same banner firing twice in quick succession (e.g. a
  // toast queued during the fusion cinematic plus a follow-up call).
  String? _lastToastMessage;
  DateTime? _lastToastAt;

  void _showToast(
    String message, {
    IconData icon = AppIcons.info_rounded,
    Color? color,
    bool fromTop = false,
  }) {
    if (!mounted) return;
    // The one thing worth keeping from this screen's own toast: breeding can
    // fire the same complaint several times in a second, and repeating it is
    // just noise.
    final now = DateTime.now();
    if (_lastToastMessage == message &&
        _lastToastAt != null &&
        now.difference(_lastToastAt!) < const Duration(milliseconds: 1500)) {
      return;
    }
    _lastToastMessage = message;
    _lastToastAt = now;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    showGameSnack(
      context,
      message,
      icon: icon,
      accent: color,
      duration: const Duration(seconds: 2),
    );
  }
}

// ================== CUSTOM PAINTERS ==================

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

class _SummoningCirclePainter extends CustomPainter {
  final Color color;
  final Color accentColor;
  final Color glowColor;
  final double progress;
  final bool showOrbit;

  _SummoningCirclePainter({
    required this.color,
    required this.accentColor,
    required this.glowColor,
    required this.progress,
    this.showOrbit = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);
    final outerR = cx - 4;
    final innerR = outerR * 0.78;

    // --- Subtle radial glow ---
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [glowColor, glowColor.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: innerR));
    canvas.drawCircle(center, innerR, glowPaint);

    // --- Outer circle ---
    canvas.drawCircle(
      center,
      outerR,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // --- Inner circle ---
    canvas.drawCircle(
      center,
      innerR,
      Paint()
        ..color = color.withValues(alpha: color.a * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // --- Inscribed hexagon on outer circle ---
    final hexPaint = Paint()
      ..color = color.withValues(alpha: color.a * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final hexPath = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i / 6) * 2 * math.pi - math.pi / 2;
      final x = cx + outerR * math.cos(angle);
      final y = cy + outerR * math.sin(angle);
      if (i == 0) {
        hexPath.moveTo(x, y);
      } else {
        hexPath.lineTo(x, y);
      }
    }
    hexPath.close();
    canvas.drawPath(hexPath, hexPaint);

    // --- Two overlapping triangles (Star of David / transmutation seal) ---
    final triPaint = Paint()
      ..color = accentColor.withValues(alpha: accentColor.a * 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    // Triangle pointing up
    final triUpPath = Path();
    for (int i = 0; i < 3; i++) {
      final angle = (i / 3) * 2 * math.pi - math.pi / 2;
      final x = cx + innerR * math.cos(angle);
      final y = cy + innerR * math.sin(angle);
      if (i == 0) {
        triUpPath.moveTo(x, y);
      } else {
        triUpPath.lineTo(x, y);
      }
    }
    triUpPath.close();
    canvas.drawPath(triUpPath, triPaint);

    // Triangle pointing down
    final triDownPath = Path();
    for (int i = 0; i < 3; i++) {
      final angle = (i / 3) * 2 * math.pi + math.pi / 2;
      final x = cx + innerR * math.cos(angle);
      final y = cy + innerR * math.sin(angle);
      if (i == 0) {
        triDownPath.moveTo(x, y);
      } else {
        triDownPath.lineTo(x, y);
      }
    }
    triDownPath.close();
    canvas.drawPath(triDownPath, triPaint);

    // --- Small tick marks at 12 positions on outer ring ---
    final tickPaint = Paint()
      ..color = color.withValues(alpha: color.a * 0.5)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 12; i++) {
      final angle = (i / 12) * 2 * math.pi - math.pi / 2;
      final isCardinal = i % 3 == 0;
      final len = isCardinal ? 4.0 : 2.0;
      final from = Offset(
        cx + outerR * math.cos(angle),
        cy + outerR * math.sin(angle),
      );
      final to = Offset(
        cx + (outerR + len) * math.cos(angle),
        cy + (outerR + len) * math.sin(angle),
      );
      canvas.drawLine(from, to, tickPaint);
    }

    // --- Small diamond runes at 4 cardinal points (outside ring) ---
    final runePaint = Paint()
      ..color = accentColor.withValues(alpha: accentColor.a * 0.4)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 4; i++) {
      final angle = (i / 4) * 2 * math.pi - math.pi / 2;
      final dx = cx + (outerR + 7) * math.cos(angle);
      final dy = cy + (outerR + 7) * math.sin(angle);
      final d = Path()
        ..moveTo(dx, dy - 2.2)
        ..lineTo(dx + 1.3, dy)
        ..lineTo(dx, dy + 2.2)
        ..lineTo(dx - 1.3, dy)
        ..close();
      canvas.drawPath(d, runePaint);
    }

    // --- Orbiting particle with trail (empty state) ---
    if (showOrbit) {
      final angle = progress * 2 * math.pi;
      final orbitR = (outerR + innerR) / 2;

      // Main dot with glow
      final orbX = cx + orbitR * math.cos(angle);
      final orbY = cy + orbitR * math.sin(angle);
      canvas.drawCircle(
        Offset(orbX, orbY),
        2.5,
        Paint()
          ..color = accentColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );

      // Fading trail
      for (int t = 1; t <= 6; t++) {
        final ta = angle - t * 0.15;
        final tx = cx + orbitR * math.cos(ta);
        final ty = cy + orbitR * math.sin(ta);
        canvas.drawCircle(
          Offset(tx, ty),
          2.0 - t * 0.25,
          Paint()
            ..color = accentColor.withValues(
              alpha: accentColor.a * (1.0 - t / 7),
            ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SummoningCirclePainter old) =>
      old.progress != progress ||
      old.showOrbit != showOrbit ||
      old.color != color ||
      old.accentColor != accentColor;
}

/// A toast captured during the fusion cinematic, shown once after it closes.
class _PendingToast {
  const _PendingToast(this.message, {required this.icon, this.color});
  final String message;
  final IconData icon;
  final Color? color;
}
