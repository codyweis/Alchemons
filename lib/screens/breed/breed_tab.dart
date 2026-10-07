// lib/screens/breed/breed_tab.dart
//
// FUSION — two Alchemons on one lit floor. What they will make is kept a
// surprise.
//
//   Each stands at its family's size on a pool of its element's light, the
//   first turned to face the second. Once both are in, a small knot of their
//   grains turns between them: the cultivation to be, in the same material
//   the chambers hold. Under each, its name, element, level and stamina; above
//   the button, one plain line for anything that would stop the fusion, so
//   nothing refuses after the tap. One button always does the next thing:
//   choose two, choose one more, fuse.
//
//   FUSE runs the merge here, on the live chamber: each is read into grains
//   where it stands and poured into the knot (fusion_particles.dart), and the
//   cinematic opens over it, anchored to the same places.
//
// This replaced a card of hexagram circles, a wave line and a flat orb, with
// refusals (resting, cross-family, Mystics, no room) that only came as
// dialogs after INITIATE FUSION was pressed.

import 'dart:async' show Timer;
import 'dart:math' as math;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart'
    show kCompanionSpeciesScale;
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/breeding_service.dart';
import 'package:alchemons/services/cold_storage_service.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/nav_bar.dart';
import 'package:alchemons/widgets/all_specimens_page.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/breed_cinematic_fx.dart';
import 'package:alchemons/widgets/fx/cultivation_sphere.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:provider/provider.dart';

import '../../database/alchemons_db.dart';
import '../../models/creature.dart';
import '../../services/creature_repository.dart';
import 'package:alchemons/widgets/app_icons.dart';

part 'fusion_stage.dart';

/// The fusion gold: pale on the dark palette, deep on the parchment, where
/// the pale one washes out.
Color fusionGold(BracketPalette palette) =>
    palette.isDark ? const Color(0xFFE4C16A) : const Color(0xFF9A6B00);

const _kDanger = Color(0xFFE5735C);

class BreedingTab extends StatefulWidget {
  final List<CreatureEntry> discoveredCreatures;
  final VoidCallback onBreedingComplete;

  const BreedingTab({
    super.key,
    required this.discoveredCreatures,
    required this.onBreedingComplete,
    this.debugParent1,
    this.debugParent2,
    this.debugLastPair,
  });

  /// Specimens already in the chambers when the tab opens, with no reveal:
  /// for measuring the chamber at rest.
  @visibleForTesting
  final CreatureInstance? debugParent1, debugParent2;

  /// A pair fused before, so SAME PAIR is offered.
  @visibleForTesting
  final (String, String)? debugLastPair;

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

  /// Runs the merge in the chamber, before the cinematic opens.
  late AnimationController _preCinematicFadeController;

  /// The merge, in particles: both specimens read into grains at the tap,
  /// then poured into the knot. Null when no merge is running.
  FusionParticleField? _fusionField;

  /// Seconds into the merge.
  double get _mergeTime =>
      _preCinematicFadeController.value * FusionParticleField.duration;

  /// The knot, fed a little as the grains start to arrive and gone by the
  /// time they have: the cloud of the two of them is the fusion.
  late Animation<double> _knotScaleAnim;
  late Animation<double> _knotFadeAnim;

  // Keys to capture on-screen chamber positions so the fusion cinematic can
  // anchor itself to the live screen.
  final GlobalKey _slot1AvatarKey = GlobalKey();
  final GlobalKey _slot2AvatarKey = GlobalKey();
  final GlobalKey _orbKey = GlobalKey();

  /// A specimen put into a chamber gathers there out of its element. Each
  /// pick gets its own ticket, so the chambers coming back into view later
  /// just show what is in them.
  EssenceReveal? _slot1Reveal, _slot2Reveal;

  // What each specimen is read into grains from, and the stack the grains
  // are painted in.
  final GlobalKey _slot1CaptureKey = GlobalKey();
  final GlobalKey _slot2CaptureKey = GlobalKey();
  final GlobalKey _slotsStackKey = GlobalKey();

  late final Stream<List<IncubatorSlot>> _slots;
  late final Stream<List<Egg>> _stored;

  /// Cold storage's size: read once, and again after each fusion.
  int? _storageCapacity;

  /// Stamina as shown, per specimen, kept a while: a nature's extra bar is
  /// rolled each time it is worked out, and the cells should not flicker.
  final Map<String, (StaminaState, DateTime)> _staminaShown = {};

  /// Ticks the rest countdown while a resting specimen is in a chamber.
  Timer? _restTimer;

  /// The knot's makings, for the pair it was built for.
  Map<String, dynamic>? _knotPayload;
  String? _knotPair;

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

  /// The knot's box. The merge's cloud is sized from it (a little wider), and
  /// the cinematic's cover from that.
  static const double _knotBox = 56;

  String _familyKeyForCreature(Creature c) {
    if (c.mutationFamily != null && c.mutationFamily!.isNotEmpty) {
      return c.mutationFamily!.toUpperCase();
    }
    final match = RegExp(r'^[A-Za-z]+').firstMatch(c.id);
    final letters = match?.group(0) ?? c.id;
    return letters.toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    final db = context.read<AlchemonsDatabase>();
    _slots = db.incubatorDao.watchSlots();
    _stored = db.incubatorDao.watchInventory();
    _loadStorageCapacity();

    // THE MERGE, performed in the chamber itself, so the route that follows
    // never has to draw a copy of anything.
    //
    // Each specimen is read into grains where it stands and swapped for
    // them under a line of sparkle — the same shape, the same markings, made
    // of particles — and the grains are poured into the knot, the two
    // winding through each other, until it takes them in. The timeline is
    // the field's; this controller just runs it.
    _preCinematicFadeController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: (FusionParticleField.duration * 1000).round(),
      ),
    );

    _knotScaleAnim = TweenSequence<double>([
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
    _knotFadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _preCinematicFadeController,
        curve: const Interval(0.42, 0.72, curve: Curves.easeIn),
      ),
    );

    selectedParent1 = widget.debugParent1;
    selectedParent2 = widget.debugParent2;
    final last = widget.debugLastPair;
    if (last != null) {
      _lastParent1InstanceId = last.$1;
      _lastParent2InstanceId = last.$2;
    }
  }

  Future<void> _loadStorageCapacity() async {
    final capacity = await ColdStorageService.getCapacity(
      context.read<AlchemonsDatabase>(),
    );
    if (mounted && capacity != _storageCapacity) {
      setState(() => _storageCapacity = capacity);
    }
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _preCinematicFadeController.dispose();
    super.dispose();
  }

  // ───────────────────────────── reading the pair ─────────────────────────

  /// Its stamina now, as last worked out (within half a minute).
  StaminaState _staminaOf(CreatureInstance inst) {
    final now = DateTime.now();
    final key =
        '${inst.instanceId}|${inst.staminaBars}|${inst.staminaLastUtcMs}';
    final kept = _staminaShown[key];
    if (kept != null && now.difference(kept.$2).inSeconds < 30) return kept.$1;
    final state = context.read<StaminaService>().computeState(inst);
    _staminaShown
      ..removeWhere((k, _) => k.startsWith('${inst.instanceId}|'))
      ..[key] = (state, now);
    return state;
  }

  /// Keeps the rest countdown moving while a resting one is chosen, and
  /// nothing ticking otherwise.
  void _syncRestTimer(bool anyResting) {
    if (!anyResting) {
      _restTimer?.cancel();
      _restTimer = null;
      return;
    }
    _restTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  String _nameOf(CreatureInstance inst, Creature? base) {
    final nick = inst.nickname?.trim();
    if (nick != null && nick.isNotEmpty) return nick;
    return base?.name ?? 'Specimen';
  }

  /// Whatever stops this pair fusing right now, in plain words, or null.
  /// And, when it can go ahead, anything worth knowing first.
  ({String? block, String? note}) _readiness(
    Creature? a,
    Creature? b,
    _Room room,
  ) {
    final p1 = selectedParent1, p2 = selectedParent2;
    if (p1 == null || p2 == null || a == null || b == null) {
      return (block: null, note: null);
    }
    final mysticA = a.mutationFamily == 'Mystic';
    final mysticB = b.mutationFamily == 'Mystic';
    if ((mysticA || mysticB) && !(mysticA && mysticB && a.id == b.id)) {
      return (block: 'Mystics fuse only with their own species', note: null);
    }
    if (_familyKeyForCreature(a) != _familyKeyForCreature(b) &&
        !context
            .read<ConstellationEffectsService>()
            .hasCrossSpeciesBreeding()) {
      return (block: 'Two families · needs Cross-Species Lineage', note: null);
    }
    for (final (inst, base) in [(p1, a), (p2, b)]) {
      final s = _staminaOf(inst);
      if (s.bars < 1) {
        final wait = s.nextTickUtc?.difference(DateTime.now().toUtc());
        return (
          block: wait == null
              ? '${_nameOf(inst, base)} is resting'
              : '${_nameOf(inst, base)} is resting · ${_shortWait(wait)}',
          note: null,
        );
      }
    }
    if (room.known && room.free == 0) {
      if (room.storageFull) {
        return (block: 'Chambers and cold storage full', note: null);
      }
      return (
        block: null,
        note: 'Chambers full · this one goes to cold storage',
      );
    }
    return (block: null, note: null);
  }

  static String _shortWait(Duration d) {
    if (d.isNegative || d.inMinutes < 1) return 'any moment';
    final h = d.inHours, m = d.inMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  // ───────────────────────────── the chamber ──────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    // Cross-Species Lineage can be unlocked while this tab sits open.
    context.watch<ConstellationEffectsService>();
    final palette = BracketPalette.fromTheme(theme);
    return StreamBuilder<List<IncubatorSlot>>(
      stream: _slots,
      builder: (context, slotSnap) => StreamBuilder<List<Egg>>(
        stream: _stored,
        builder: (context, storedSnap) {
          final room = _Room.of(
            slotSnap.data,
            storedSnap.data?.length,
            _storageCapacity,
          );
          return _buildChamber(theme, palette, room);
        },
      ),
    );
  }

  Widget _buildChamber(FactionTheme theme, BracketPalette palette, _Room room) {
    final repo = context.read<CreatureCatalog>();
    final p1 = selectedParent1, p2 = selectedParent2;
    final a = p1 == null ? null : repo.getCreatureById(p1.baseId);
    final b = p2 == null ? null : repo.getCreatureById(p2.baseId);
    final ready = _readiness(a, b, room);
    _syncRestTimer(
      [
        if (p1 != null) p1,
        if (p2 != null) p2,
      ].any((i) => _staminaOf(i).bars < 1),
    );
    final gold = fusionGold(palette);

    return LayoutBuilder(
      builder: (context, box) {
        // A short window (a split screen) scrolls a stage of fixed height
        // rather than squeezing the specimens.
        final compact = box.maxHeight < 520;
        final stage = _buildStage(theme, palette, gold, a, b);
        final column = Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: _ChamberCells(room: room, palette: palette, gold: gold),
            ),
            if (compact)
              SizedBox(height: 400, child: stage)
            else
              Expanded(child: stage),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ReadinessLine(
                block: ready.block,
                note: ready.note,
                palette: palette,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildActions(palette, gold, ready.block == null),
            ),
            // Clear of the dock's raised FUSION icon, which otherwise sat on
            // the middle of the button.
            const SizedBox(height: kDockIconRise + 6),
          ],
        );
        return compact
            ? SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: column,
              )
            : column;
      },
    );
  }

  /// How far a side's specimen has been drawn out of its chamber by the
  /// merge, 0..1.
  double _emptied(int side) {
    if (!_isBreeding && _preCinematicFadeController.value == 0) return 0;
    return _fusionField?.chamberEmpty(side, _mergeTime) ??
        Curves.easeIn.transform(_preCinematicFadeController.value);
  }

  /// One button that does the next thing, and SAME PAIR beside it when
  /// there is a pair to repeat.
  Widget _buildActions(BracketPalette palette, Color gold, bool clear) {
    final p1 = selectedParent1, p2 = selectedParent2;
    if (p1 != null && p2 != null) {
      return BracketButton(
        label: 'FUSE',
        height: 48,
        palette: palette,
        accent: gold,
        enabled: clear && !_isBreeding,
        onTap: _onBreedTap,
      );
    }
    if (p1 != null || p2 != null) {
      return BracketButton(
        label: 'CHOOSE ONE MORE',
        height: 48,
        palette: palette,
        accent: gold,
        enabled: !_isBreeding,
        onTap: () => _showBreedingPicker(targetSlot: p1 == null ? 1 : 2),
      );
    }
    final repeat =
        _lastParent1InstanceId != null && _lastParent2InstanceId != null;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: BracketButton(
            label: 'CHOOSE TWO',
            height: 48,
            palette: palette,
            accent: gold,
            onTap: () => _showBreedingPicker(),
          ),
        ),
        if (repeat) ...[
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: BracketButton(
              label: 'SAME PAIR',
              primary: false,
              height: 48,
              palette: palette,
              accent: gold,
              onTap: _onRepeatBreed,
            ),
          ),
        ],
      ],
    );
  }

  // ───────────────────────────── the stage ────────────────────────────────

  /// How far a body reaches either side of its frame's centre, as a share
  /// of the frame: about a third, give or take a tail or a wing.
  static const double _bodyHalf = 0.36;

  /// From the floor down to the plate under a specimen.
  static const double _plateGap = 16;

  /// The floor, the pair standing on it with their plates under them, the
  /// knot between them, and the merge's grains over all of it.
  ///
  /// The pair and their plates are one group, centred in the stage. Each
  /// stands as far from the middle as its own body is wide (and at least a
  /// quarter of the way across), so a wing and a let are both clear of the
  /// knot rather than set at fixed places.
  Widget _buildStage(
    FactionTheme theme,
    BracketPalette palette,
    Color gold,
    Creature? a,
    Creature? b,
  ) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        // Room between each body and the knot. At 8 the pair crowded it.
        const clear = _knotBox / 2 + 24;
        // A tall stage stands the pair a little bigger, as far as the width
        // allows: never into the knot or off the screen's edge, never past
        // the stage's top.
        final zoom = ((h - _Plate.height - 60) / 300).clamp(1.0, 1.15);
        final widthCap = (w / 2 - clear - 6) / (2 * _bodyHalf);
        final heightCap = (h - _Plate.height - _plateGap - 24) / 0.98;
        double frameOf(Creature? c, CreatureInstance? inst) => c == null
            ? 0
            : math.min(
                math.min(
                  _chamberFrame(c) *
                      zoom *
                      scaleFromGenes(decodeGenetics(inst?.geneticsJson)),
                  widthCap,
                ),
                heightCap,
              );
        final frames = [
          frameOf(a, selectedParent1),
          frameOf(b, selectedParent2),
        ];
        final emptyW = math.min(w * 0.36, 150.0);
        final emptyH = emptyW * 1.25;
        final filled = frames.where((f) => f > 0);
        final tallest = filled.isEmpty ? emptyH : filled.reduce(math.max);
        final pairH = math.max(
          tallest * 0.95,
          frames.contains(0.0) ? emptyH : 0.0,
        );
        // The group a little above the middle: the eye sits there.
        final group = pairH + _plateGap + _Plate.height;
        final floorY = math.max(8.0, (h - group) * 0.45) + pairH;
        final xs = [
          for (var side = 0; side < 2; side++)
            () {
              final half = frames[side] > 0
                  ? frames[side] * _bodyHalf
                  : emptyW / 2;
              // Never nearer the middle than a quarter of the way across,
              // so a small pair on a wide screen does not huddle.
              final out = math.max(clear + half, w * 0.25);
              final x = w / 2 + (side == 0 ? -1 : 1) * out;
              return x.clamp(half + 6, w - half - 6);
            }(),
        ];
        // Level with the middle of the pair's bodies.
        final knotY = floorY - (tallest * 0.42).clamp(56.0, 130.0);
        final colors = [
          a == null ? null : BreedConstants.getTypeColor(a.types.first),
          b == null ? null : BreedConstants.getTypeColor(b.types.first),
        ];
        final plateW = w / 2 - 10;
        final field = _fusionField;

        return Stack(
          key: _slotsStackKey,
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _preCinematicFadeController,
                    builder: (context, _) => CustomPaint(
                      painter: _FusionFloorPainter(
                        floorY: floorY,
                        knotY: knotY,
                        xs: xs,
                        frames: frames,
                        colors: colors,
                        lit: [1 - _emptied(0) * 0.85, 1 - _emptied(1) * 0.85],
                        palette: palette,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            for (var side = 0; side < 2; side++)
              if (frames[side] == 0)
                _buildEmptySpot(palette, side, xs[side], floorY, emptyW, emptyH)
              else
                _buildSpecimen(
                  side: side,
                  base: side == 0 ? a! : b!,
                  inst: side == 0 ? selectedParent1! : selectedParent2!,
                  frame: frames[side],
                  x: xs[side],
                  floorY: floorY,
                  dark: theme.isDark,
                ),

            for (final (side, inst, base) in [
              (0, selectedParent1, a),
              (1, selectedParent2, b),
            ])
              if (inst != null)
                Positioned(
                  left: (xs[side] - plateW / 2).clamp(6.0, w - 6 - plateW),
                  top: floorY + _plateGap,
                  width: plateW,
                  child: AnimatedBuilder(
                    animation: _preCinematicFadeController,
                    builder: (context, child) => Opacity(
                      // They belong to the chamber, not to the specimen, so
                      // they stay put and dim as it is drawn out.
                      opacity: (1 - _emptied(side)).clamp(0.0, 1.0),
                      child: child,
                    ),
                    child: _Plate(
                      name: _nameOf(inst, base),
                      element: base?.types.first,
                      level: inst.level,
                      stamina: _staminaOf(inst),
                      palette: palette,
                      gold: gold,
                      onRemove: _isBreeding
                          ? null
                          : () => setState(() {
                              if (side == 0) {
                                selectedParent1 = null;
                              } else {
                                selectedParent2 = null;
                              }
                            }),
                    ),
                  ),
                ),

            // The merge's grains on the far side of the knot, under it.
            // Always in the tree (painting nothing between merges) so adding
            // it never shuffles the knot's place in this stack.
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

            Positioned(
              left: w / 2 - _knotBox / 2,
              top: knotY - _knotBox / 2,
              width: _knotBox,
              height: _knotBox,
              child: IgnorePointer(
                child: KeyedSubtree(
                  key: _orbKey,
                  child: _buildKnot(theme, a, b),
                ),
              ),
            ),

            // ...and everything else of it, over the knot and the pair.
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
      },
    );
  }

  /// A place to stand, waiting: a frame on the floor, open to a tap.
  Widget _buildEmptySpot(
    BracketPalette palette,
    int side,
    double x,
    double floorY,
    double width,
    double height,
  ) {
    return Positioned(
      left: x - width / 2,
      top: floorY - height,
      width: width,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: context.soundAction(
          _isBreeding ? null : () => _showBreedingPicker(targetSlot: side + 1),
        ),
        child: CustomPaint(
          painter: BracketFramePainter(
            color: palette.line.withValues(alpha: palette.isDark ? 0.55 : 0.6),
            bracketSize: 14,
          ),
          child: Center(
            child: Icon(
              AppIcons.add_rounded,
              size: 20,
              color: palette.muted.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }

  /// The specimen standing on the floor at its family's size.
  ///
  /// It sits in a repaint boundary ([captureKey]) a little bigger than its
  /// frame, so it can be read into grains exactly as it is showing; the merge
  /// cuts it away from the top down ([SpriteCrestClipper]) as its grains take
  /// its place. The first one is turned to face the second, inside the
  /// boundary, so what is read is what is seen. The tree is the same whether
  /// or not a merge is running, so starting one never rebuilds the sprite.
  Widget _buildSpecimen({
    required int side,
    required Creature base,
    required CreatureInstance inst,
    required double frame,
    required double x,
    required double floorY,
    required bool dark,
  }) {
    final gene = scaleFromGenes(decodeGenetics(inst.geneticsJson));
    final captureBox = (frame * 1.12).ceilToDouble();
    // The frame's foot on the floor: the sprites stand a little inside it.
    final centreY = floorY - frame / 2 + frame * 0.085;
    final sprite = base.spriteData != null
        ? Transform.scale(
            // The sprite's own widget draws its frame 69 across and then
            // applies the size gene, so the family size goes on around it.
            scale: frame / gene / 69,
            child: InstanceSprite(creature: base, instance: inst, size: 64),
          )
        : Icon(
            AppIcons.image_not_supported_rounded,
            color: Colors.white.withValues(alpha: .4),
            size: 32,
          );
    return Positioned(
      left: x - captureBox / 2,
      top: centreY - captureBox / 2,
      width: captureBox,
      height: captureBox,
      child: KeyedSubtree(
        key: side == 0 ? _slot1AvatarKey : _slot2AvatarKey,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          // Mid-merge the specimen is already grains; swapping it out from
          // under them would leave the merge pouring a creature that is no
          // longer there.
          onTap: context.soundAction(
            _isBreeding
                ? null
                : () => _showBreedingPicker(targetSlot: side + 1),
          ),
          child: AnimatedBuilder(
            animation: _preCinematicFadeController,
            builder: (context, child) {
              final field = _fusionField;
              final cut =
                  field?.cutY(side, _mergeTime) ?? double.negativeInfinity;
              // With no field (the chamber could not be measured) the sprite
              // just fades, as it used to.
              final opacity = cut == double.infinity
                  ? 0.0
                  : field == null
                  ? 1 - _emptied(side)
                  : 1.0;
              return ClipRect(
                clipper: SpriteCrestClipper(cut),
                clipBehavior: cut == double.negativeInfinity
                    ? Clip.none
                    : Clip.hardEdge,
                child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
              );
            },
            child: RepaintBoundary(
              key: side == 0 ? _slot1CaptureKey : _slot2CaptureKey,
              child: SizedBox.square(
                dimension: captureBox,
                child: Center(
                  child: Transform.flip(
                    flipX: side == 0,
                    child: SizedBox(
                      width: 68,
                      height: 68,
                      child: base.spriteData == null
                          ? sprite
                          : ElementalEssence(
                              key: ValueKey(inst.instanceId),
                              element: base.types.first,
                              dark: dark,
                              reveal: side == 0 ? _slot1Reveal : _slot2Reveal,
                              // A tap on the chamber picks its specimen.
                              tappable: false,
                              // The sprite is scaled up past this box to its
                              // family size; read all of it.
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
      ),
    );
  }

  /// The pair's grains, turning between them once both are in: the same
  /// sphere a cultivation is, made of the two portraits.
  Widget _buildKnot(FactionTheme theme, Creature? a, Creature? b) {
    final p1 = selectedParent1, p2 = selectedParent2;
    if (p1 == null || p2 == null || a == null || b == null) {
      return const SizedBox.expand();
    }
    final pair = '${p1.instanceId}|${p2.instanceId}';
    if (_knotPair != pair) {
      final repo = context.read<CreatureCatalog>();
      _knotPair = pair;
      _knotPayload = {
        'parentage': {
          'parentA': ParentSnapshot.fromDbInstance(p1, repo).toJson(),
          'parentB': ParentSnapshot.fromDbInstance(p2, repo).toJson(),
        },
      };
    }
    return FadeTransition(
      opacity: _knotFadeAnim,
      child: ScaleTransition(
        scale: _knotScaleAnim,
        child: TweenAnimationBuilder<double>(
          // Kindles when a pair is made, and again for a new pair.
          key: ValueKey(pair),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, v, child) => Opacity(
            opacity: v,
            child: Transform.scale(scale: 0.45 + 0.55 * v, child: child),
          ),
          child: CultivationSphere(
            payload: _knotPayload!,
            types: [a.types.first, b.types.first],
            progress: 0,
            grains: 260,
            radiusFactor: 0.44,
            interactive: false,
            darkBackdrop: theme.isDark,
            // Wound up as the pair pour in.
            spinScale: _isBreeding ? 7 : 1.4,
          ),
        ),
      ),
    );
  }

  // ───────────────────────────── fusing ───────────────────────────────────

  Future<void> _onRepeatBreed() async {
    if (_lastParent1InstanceId == null || _lastParent2InstanceId == null) {
      return;
    }
    final db = context.read<AlchemonsDatabase>();
    final inst1 = await db.creatureDao.getInstance(_lastParent1InstanceId!);
    final inst2 = await db.creatureDao.getInstance(_lastParent2InstanceId!);

    if (inst1 == null || inst2 == null) {
      _showToast(
        'That pair is no longer here',
        color: Colors.orange,
      );
      setState(() {
        _lastParent1InstanceId = null;
        _lastParent2InstanceId = null;
      });
      return;
    }

    _applyBreedingPicks(inst1, inst2);
  }

  // Read the specimens into grains first, then check, then run the merge in
  // the chamber, then the cinematic and the fusion itself.
  Future<void> _onBreedTap() async {
    if (selectedParent1 == null || selectedParent2 == null) return;
    if (_isBreeding) return;

    setState(() => _isBreeding = true);
    // Read the specimens into grains now, while the refusals below are
    // checked, so the merge does not wait on it. Thrown away if one says no.
    final grains = _captureSpecimens();
    try {
      final repo = context.read<CreatureCatalog>();
      final breedingService = context.read<BreedingServiceV2>();
      final speciesA = repo.getCreatureById(selectedParent1!.baseId);
      final speciesB = repo.getCreatureById(selectedParent2!.baseId);

      if (speciesA == null || speciesB == null) {
        _showToast('Error loading species data', color: Colors.red);
        return;
      }

      // The readiness line has already said all of these, and FUSE waits
      // on it; checked again against the database in case it moved since.
      final stamina = context.read<StaminaService>();
      final restedA = await stamina.canBreed(selectedParent1!.instanceId);
      final restedB = await stamina.canBreed(selectedParent2!.instanceId);
      if (!restedA || !restedB) {
        _showToast(
          !restedA && !restedB
              ? 'Both are resting'
              : '${_nameOf(!restedA ? selectedParent1! : selectedParent2!, !restedA ? speciesA : speciesB)} is resting',
          color: Colors.orange,
        );
        return;
      }
      if (!mounted) return;

      final isMysticA = speciesA.mutationFamily == 'Mystic';
      final isMysticB = speciesB.mutationFamily == 'Mystic';
      if ((isMysticA || isMysticB) &&
          !(isMysticA && isMysticB && speciesA.id == speciesB.id)) {
        _showToast(
          'Mystics fuse only with their own species',
          color: Colors.orange,
        );
        return;
      }

      final db = context.read<AlchemonsDatabase>();
      final skills = await db.constellationDao.getUnlockedSkillIds();
      if (_familyKeyForCreature(speciesA) != _familyKeyForCreature(speciesB) &&
          !skills.contains('breeder_cross_species')) {
        _showToast(
          'Two families · needs Cross-Species Lineage',
          color: Colors.orange,
        );
        return;
      }

      final placementFailure = await breedingService
          .getEggPlacementFailureMessage();
      if (placementFailure != null) {
        _showToast(
          placementFailure,
          color: Colors.orange,
        );
        return;
      }

      // The specimens turn to grains and are poured into the knot, on the
      // real chamber. Measured from the layout as it is right now: it is
      // responsive, so none of this can be a constant.
      final read = await grains;
      if (!mounted) return;
      setState(
        () => _fusionField = _buildFusionField(read, speciesA, speciesB),
      );
      context.sound(SoundCue.fusionMerge, owner: this);
      await _preCinematicFadeController.forward();

      // let that max-charged knot hang briefly
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
        _loadStorageCapacity();
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
      // A cloud a little wider than the knot, so it shows through the gaps.
      coreRadius: orb.size.width / 2 * 1.7,
      colors: [colorA, colorB],
      darkBackdrop: context.read<FactionTheme>().isDark,
    );
  }

  // Resolve a keyed widget's bounds in global screen coordinates, so the
  // fusion cinematic can anchor itself to the live chamber slots / knot.
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

  Future<void> _performBreeding() async {
    if (selectedParent1 == null || selectedParent2 == null) return;

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
        // The intake, the charge and the haul together happen for real in
        // the chamber before this opens, so the route only has the eruption
        // and the reveal left to play.
        minDuration: const Duration(milliseconds: 2800),
        task: () async {
          final result = await breedingService.breedInstances(
            selectedParent1!,
            selectedParent2!,
          );

          if (!result.success) {
            _pendingFusionToast = _PendingToast(
              result.message ?? 'Fusion failed',
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
              'Chambers full. The cultivation went to cold storage',
              color: Colors.orange,
            );
          } else if (result.placement == EggPlacement.incubator) {
            _pendingFusionToast = _PendingToast(
              'Cultivating in chamber ${(result.slotId ?? 0) + 1}',
            );
          }

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
        _showToast(pending.message, color: pending.color);
      }

      if (didBreed != true) return;
      if (!mounted) return;

      setState(() {
        // Saved for SAME PAIR.
        _lastParent1InstanceId = selectedParent1?.instanceId;
        _lastParent2InstanceId = selectedParent2?.instanceId;
        selectedParent1 = null;
        selectedParent2 = null;
      });

      widget.onBreedingComplete();
    } catch (e) {
      _showToast(
        'Fusion failed: $e',
        color: Colors.red,
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
    if (skipStamina && math.Random().nextBool()) {
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

  // ───────────────────────────── choosing ─────────────────────────────────

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
    });
  }

  /// The picker's title: who the pick will fuse with, once one is in.
  String _pickerTitle(CreatureInstance? partner) {
    if (partner == null) return 'CHOOSE TO FUSE';
    final base = context.read<CreatureCatalog>().getCreatureById(
      partner.baseId,
    );
    return 'FUSE WITH ${_nameOf(partner, base).toUpperCase()}';
  }

  // targetSlot == null => pick both (quick-select flow)
  // targetSlot != null => pick only that slot and close.
  void _showBreedingPicker({int? targetSlot}) async {
    var nextParent1 = selectedParent1;
    var nextParent2 = selectedParent2;

    if (targetSlot != null) {
      final partner = targetSlot == 1 ? nextParent2 : nextParent1;
      final picked = await _pickBreedingInstance(
        title: _pickerTitle(partner),
        selectedIds: [
          if (nextParent1 != null) nextParent1.instanceId,
          if (nextParent2 != null) nextParent2.instanceId,
        ],
        blockedIds: [if (partner != null) partner.instanceId],
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
        title: _pickerTitle(nextParent2),
        selectedIds: [if (nextParent2 != null) nextParent2.instanceId],
        blockedIds: [if (nextParent2 != null) nextParent2.instanceId],
      );
      if (picked == null) return;
      nextParent1 = picked;
      _applyBreedingPicks(nextParent1, nextParent2);
    }

    if (nextParent2 == null) {
      final picked = await _pickBreedingInstance(
        title: _pickerTitle(nextParent1),
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
    required String title,
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
              title: title,
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
        'That one is already in the other chamber',
        color: Colors.orange,
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
      'Resting, next stamina in ~${mins}m',
      color: Colors.orange,
    );
    return false;
  }

  // Guard against the same banner firing twice in quick succession (e.g. a
  // toast queued during the fusion cinematic plus a follow-up call).
  String? _lastToastMessage;
  DateTime? _lastToastAt;

  void _showToast(String message, {Color? color}) {
    if (!mounted) return;
    // Fusion can fire the same complaint several times in a second, and
    // repeating it is just noise.
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
      accent: color,
      duration: const Duration(seconds: 2),
    );
  }
}

/// A toast captured during the fusion cinematic, shown once after it closes.
class _PendingToast {
  const _PendingToast(this.message, {this.color});
  final String message;
  final Color? color;
}
