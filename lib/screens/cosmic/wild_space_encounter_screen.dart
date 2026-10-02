// lib/screens/cosmic/wild_space_encounter_screen.dart
//
// The portal the ship tears when it rams a wild Alchemon in space. Space is
// paused behind it; the encounter plays against the dark it was pulled from,
// with whatever planet the ship was beside — the home planet included —
// hanging in the frame on the side it really is.
//
// Failed attempts can be retried while the portal is open. A fusion that
// works consumes the specimen; leaving after a failure loses it — either way
// it is gone from space for good. Leaving without having tried sends the
// ship back with it still out there.

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart'
    show CosmicEncounterBackdrop, CosmicGame;
import 'package:alchemons/games/cosmic/portal_tear_paint.dart';
import 'package:alchemons/games/wilderness/disintegration.dart';
import 'package:alchemons/games/wilderness/encounter_sheet.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/wilderness.dart';
import 'package:alchemons/services/wilderness_service.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/harvest_cinematic.dart';
import 'package:alchemons/widgets/fx/harvester_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

enum WildSpaceEncounterResult {
  /// Left without an attempt. It is still out there.
  left,

  /// Harvested or fused. The specimen went into a chamber.
  taken,

  /// Left after a failed attempt. It is gone.
  lost,
}

class WildSpaceEncounterScreen extends StatefulWidget {
  const WildSpaceEncounterScreen({
    super.key,
    required this.creature,
    required this.rarity,
    required this.party,
    required this.backdrop,
    this.harvestBonus = 0,
    this.exhausted = false,
    this.partyLargestScale = 1,
  });

  /// The prepared specimen — the same Potentials shown over it in space.
  final Creature creature;
  final EncounterRarity rarity;
  final List<PartyMember> party;
  final CosmicEncounterBackdrop backdrop;
  final double harvestBonus;
  final bool exhausted;

  /// The biggest party member's size in space (family × size genetics), so
  /// the stage leaves room for whichever ally is picked.
  final double partyLargestScale;

  @override
  State<WildSpaceEncounterScreen> createState() =>
      _WildSpaceEncounterScreenState();
}

class _WildSpaceEncounterScreenState extends State<WildSpaceEncounterScreen>
    with TickerProviderStateMixin {
  // The whole arrival on one timeline:
  //   0.00–0.17  dark — the phone turns to landscape behind it
  //   0.17–0.62  the tear opens, the same shape that swallowed space
  //   0.25–1.00  space settles, the planet rises in, the specimen steps out
  //   0.50       the encounter HUD arrives
  late final AnimationController _opening = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..forward();
  late final Animation<double> _entrance = CurvedAnimation(
    parent: _opening,
    curve: const Interval(0.25, 1.0),
  );
  bool _hudReady = false;

  /// The fusion, played on the two creatures standing here, in particles:
  /// each turns to grains of itself, they pour together into one cloud, and
  /// it falls in on itself. The timeline is [FusionParticleField]'s, the
  /// same as the breed chamber's; this runs it.
  late final AnimationController _merge = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: (FusionParticleField.duration * 1000).round(),
    ),
  );
  (Color, Color) _mergeColors = (Colors.white, Colors.white);

  /// The pair, read into grains as the catalyst is spent. Null outside a
  /// fusion, and again after one that failed, so a retry reads afresh.
  FusionParticleField? _fusionField;
  Future<FusionParticleField?>? _fieldReading;
  final GlobalKey _allyCaptureKey = GlobalKey();
  final GlobalKey _wildCaptureKey = GlobalKey();

  /// A fusion that failed: the pair recoil apart with a flash between them.
  late final AnimationController _reject = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );

  /// A harvest that failed: the specimen shakes loose and sheds light.
  late final AnimationController _breakFree = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  /// The ally picked for fusion steps out of a summon tear, as a companion
  /// does in space.
  late final AnimationController _allySummon = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// A harvest that held: the specimen is drawn in and gone.
  late final AnimationController _taken = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  Creature? _partyCreature;
  bool _failedOnce = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _opening.addListener(_revealHud);
    // The encounter HUD is laid out for landscape, as in the rift.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _opening.dispose();
    _merge.dispose();
    _reject.dispose();
    _breakFree.dispose();
    _taken.dispose();
    _allySummon.dispose();
    super.dispose();
  }

  void _revealHud() {
    if (_hudReady || _opening.value < 0.5) return;
    _opening.removeListener(_revealHud);
    setState(() => _hudReady = true);
  }

  WildSpaceStage _stage() => WildSpaceStage.forPair(
    MediaQuery.sizeOf(context),
    creature: widget.creature,
    ally: _partyCreature,
    partyLargest: widget.partyLargestScale,
  );

  /// Through the calibration wait both turn to grains where they stand and
  /// hold there, so the verdict lands on something already changing.
  void _fusionCalibrating() {
    final ally = _partyCreature;
    if (ally == null) return;
    setState(
      () => _mergeColors = (
        specimenAccent(ally),
        specimenAccent(widget.creature),
      ),
    );
    final reading = _readField();
    _fieldReading = reading;
    reading.then((field) {
      if (!mounted || field == null || _fieldReading != reading) return;
      setState(() => _fusionField = field);
      // The wait is 650ms; the reading takes a frame or two of it.
      _merge.animateTo(
        FusionParticleField.standTime / FusionParticleField.duration,
        duration: const Duration(milliseconds: 600),
      );
    });
  }

  /// Reads the ally and the specimen into grains as they are showing.
  Future<FusionParticleField?> _readField() async {
    final ally = _partyCreature;
    if (ally == null) return null;
    final stage = _stage();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // Between frames, so nothing in either box is waiting to be repainted.
    await WidgetsBinding.instance.endOfFrame;
    Future<SpecimenGrains?> read(GlobalKey key, double box) async {
      final boundary = key.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary || !boundary.attached) return null;
      try {
        // Never more than ~600 pixels across: grains are a pixel or two
        // apart, so a finer read buys nothing.
        return await SpecimenGrains.capture(
          boundary,
          pixelRatio: min(dpr, 600 / box),
        );
      } catch (e) {
        debugPrint('fusion: could not read a specimen into grains: $e');
        return null;
      }
    }

    final grains = await Future.wait([
      read(_allyCaptureKey, stage.allySize * 1.8),
      read(_wildCaptureKey, stage.wildSize * 1.8),
    ]);
    if (!mounted) return null;
    final party = specimenAccent(ally), wild = specimenAccent(widget.creature);
    return FusionParticleField(
      specimens: [
        grains[0] ?? SpecimenGrains.disc(party, radius: stage.allySize * 0.3),
        grains[1] ?? SpecimenGrains.disc(wild, radius: stage.wildSize * 0.3),
      ],
      // Each box is placed centred on its creature's spot, unscaled.
      centres: [stage.ally, stage.wild],
      scales: const [1, 1],
      core: stage.meeting,
      coreRadius: 0.32 * max(stage.allySize, stage.wildSize),
      colors: [party, wild],
    );
  }

  Future<FusionMergeHandoff?> _fuseInScene(Color party, Color wild) async {
    if (_partyCreature == null || !mounted) return null;
    final field = _fusionField ?? await (_fieldReading ?? _readField());
    if (field == null || !mounted) return null;
    setState(() {
      _fusionField = field;
      _mergeColors = (party, wild);
    });
    await _merge.forward();
    return FusionMergeHandoff(
      at: Rect.fromCenter(center: field.core, width: 1, height: 1),
      grains: field.specimens,
    );
  }

  /// The grains run back into the two of them as they are thrown apart.
  Future<void> _fusionFailed(Color party, Color wild) async {
    _fieldReading = null;
    await Future.wait([
      _reject.forward(from: 0),
      _merge.animateBack(
        0,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      ),
    ]);
    if (mounted) setState(() => _fusionField = null);
  }

  /// The harvest's crest on the specimen (see [HarvestTarget]), and whether
  /// it went all the way — the specimen then went as grains.
  double? _harvestCut;
  bool _harvestGone = false;

  Future<bool> _harvestInScene(
    Color accent,
    Future<bool> Function() task,
    HarvesterProfile profile,
  ) async {
    if (!mounted) return false;
    _harvestGone = false;
    final held = await showHarvestCinematic(
      context: context,
      targetSprite: null,
      targetColor: accent,
      deviceLabel: profile.biomeId.toUpperCase(),
      profile: profile,
      focus: _stage().wild,
      // The field closes to fit the specimen, not a fixed size.
      focusScale:
          (_stage().wildSize * WildSpaceStage.sizeGene(widget.creature) / 208)
              .clamp(0.45, 1.5),
      // The specimen standing here is what is taken: read into grains and
      // cut away behind the crest, on this screen.
      liveTarget: HarvestTarget(
        read: () async {
          final box = _wildCaptureKey.currentContext?.findRenderObject();
          if (box is! RenderRepaintBoundary || !box.attached) return null;
          final stage = _stage();
          final grains = await SpecimenGrains.capture(
            box,
            pixelRatio: min(
              MediaQuery.devicePixelRatioOf(context),
              600 / (stage.wildSize * 1.8),
            ),
          );
          return grains == null ? null : (grains, stage.wild, 1.0);
        },
        onCut: (cut) {
          if (!mounted) return;
          if (cut == double.infinity) _harvestGone = true;
          setState(() => _harvestCut = cut);
        },
      ),
      task: task,
    );
    if (!mounted) return held;
    if (held) {
      if (_harvestGone) {
        // Already gone, as grains.
        _taken.value = 1;
        setState(() => _harvestCut = null);
      } else {
        unawaited(_taken.forward(from: 0));
      }
    } else {
      await _breakFree.forward(from: 0);
    }
    return held;
  }

  void _close(WildSpaceEncounterResult result) {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final accent = specimenAccent(widget.creature);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _close(
            _failedOnce
                ? WildSpaceEncounterResult.lost
                : WildSpaceEncounterResult.left,
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF040509),
        body: Stack(
          fit: StackFit.expand,
          children: [
            WildSpaceBackdrop(
              creature: widget.creature,
              backdrop: widget.backdrop,
              exhausted: widget.exhausted,
              partyCreature: _partyCreature,
              entrance: _entrance,
              merge: _merge,
              reject: _reject,
              breakFree: _breakFree,
              taken: _taken,
              allySummon: _allySummon,
              partyLargestScale: widget.partyLargestScale,
              mergeColors: _mergeColors,
              fusionField: _fusionField,
              allyCaptureKey: _allyCaptureKey,
              wildCaptureKey: _wildCaptureKey,
              harvestCut: _harvestCut,
            ),

            if (_hudReady)
              EncounterOverlay(
                encounter: WildEncounter(
                  wildBaseId: widget.creature.id,
                  baseBreedChance: breedChanceForRarity(widget.rarity),
                  rarity: widget.rarity.label,
                  source: 'cosmic_wild',
                ),
                hydratedWildCreature: widget.creature,
                party: widget.party,
                showMapAction: false,
                showLeaveAction: true,
                dossierHud: true,
                // After a failure, leaving costs the specimen — say so.
                warnOnRun: _failedOnce,
                runWarningTitle: 'Leave it?',
                runWarningBody:
                    'After a failed attempt it will not stay. If you leave '
                    'now, it is gone.',
                harvestBonus: widget.harvestBonus,
                onPreRollShake: () {},
                // The field closes on the specimen where it stands.
                onHarvestInScene: _harvestInScene,
                // The pair merge here, as the two you were looking at —
                // the cinematic then only plays the burst where they met.
                onFusionInScene: _fuseInScene,
                onFusionCalibrating: _fusionCalibrating,
                onFusionFailedInScene: _fusionFailed,
                onPartyCreatureSelected: (c) {
                  if (_partyCreature?.id == c.id &&
                      _partyCreature?.genetics == c.genetics) {
                    return;
                  }
                  setState(() => _partyCreature = c);
                  _allySummon.forward(from: 0);
                },
                onAttemptFailed: () => setState(() => _failedOnce = true),
                onClosedWithResult: (success) {
                  if (!mounted) return;
                  _close(
                    success
                        ? WildSpaceEncounterResult.taken
                        : _failedOnce
                        ? WildSpaceEncounterResult.lost
                        : WildSpaceEncounterResult.left,
                  );
                },
              ),

            // ── the tear opening ──
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _opening,
                builder: (context, _) {
                  if (_opening.isCompleted) return const SizedBox.shrink();
                  return CustomPaint(
                    size: Size.infinite,
                    painter: _TearRevealPainter(
                      progress: _opening.value,
                      color: accent,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color specimenAccent(Creature creature) => creature.types.isEmpty
    ? const Color(0xFFE4C16A)
    : elementColor(creature.types.first);

/// Everything behind the encounter HUD: the dark, the planet, the specimen
/// and the ally picked to fuse with it.
class WildSpaceBackdrop extends StatefulWidget {
  const WildSpaceBackdrop({
    super.key,
    required this.creature,
    required this.backdrop,
    this.exhausted = false,
    this.partyCreature,
    this.entrance = kAlwaysCompleteAnimation,
    this.merge = kAlwaysDismissedAnimation,
    this.mergeColors = (Colors.white, Colors.white),
    this.reject = kAlwaysDismissedAnimation,
    this.breakFree = kAlwaysDismissedAnimation,
    this.taken = kAlwaysDismissedAnimation,
    this.allySummon = kAlwaysCompleteAnimation,
    this.partyLargestScale = 1,
    this.behindSpecimen,
    this.fusionField,
    this.allyCaptureKey,
    this.wildCaptureKey,
    this.harvestCut,
  });

  /// A harvest's crest on the specimen, while one is taking it.
  final double? harvestCut;

  final Creature creature;
  final CosmicEncounterBackdrop backdrop;

  /// The fusion in particles, while one is running (see [merge]).
  final FusionParticleField? fusionField;

  /// What the ally and the specimen are read into grains from.
  final GlobalKey? allyCaptureKey;
  final GlobalKey? wildCaptureKey;
  final bool exhausted;
  final Creature? partyCreature;

  /// 0→1 as the scene settles in behind the opening tear.
  final Animation<double> entrance;

  /// 0→1 as the ally and the specimen fuse (see [WildSpaceStage]).
  final Animation<double> merge;

  /// Ally's accent, specimen's accent.
  final (Color, Color) mergeColors;

  /// Failure and success beats played on the creatures themselves.
  final Animation<double> reject;
  final Animation<double> breakFree;
  final Animation<double> taken;

  /// 0→1 as the ally steps out of its summon tear.
  final Animation<double> allySummon;

  /// See [WildSpaceEncounterScreen.partyLargestScale].
  final double partyLargestScale;

  /// An extra layer between the planet and the specimen. Previews use it to
  /// stand this frame in for the space view the tear opens in.
  final void Function(Canvas canvas, Size size)? behindSpecimen;

  @override
  State<WildSpaceBackdrop> createState() => _WildSpaceBackdropState();
}

class _WildSpaceBackdropState extends State<WildSpaceBackdrop>
    with SingleTickerProviderStateMixin {
  // One slow clock for drift and bob. Everything it moves is a transform, so
  // a tick recomposites layers rather than repainting them.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  )..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = specimenAccent(widget.creature);
    final backdrop = widget.backdrop;
    final party = widget.partyCreature;
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── the dark, still settling from the fall through the tear ──
        AnimatedBuilder(
          animation: widget.entrance,
          builder: (context, child) {
            final e = Curves.easeOutCubic.transform(widget.entrance.value);
            return Transform.scale(scale: 1.22 - 0.22 * e, child: child);
          },
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size.infinite,
              painter: _SpaceFieldPainter(
                seed: widget.creature.id.hashCode,
                tint: backdrop.planetColor ?? accent,
                towards: backdrop.direction,
                hasPlanet: backdrop.image != null,
              ),
            ),
          ),
        ),

        // ── the planet it was pulled from beside ──
        if (backdrop.image != null)
          _PlanetLayer(
            backdrop: backdrop,
            clock: _clock,
            entrance: widget.entrance,
          ),

        if (widget.behindSpecimen != null)
          CustomPaint(
            size: Size.infinite,
            painter: _SlotPainter(widget.behindSpecimen!),
          ),

        // ── the stage: the specimen, and the ally picked to fuse ──
        LayoutBuilder(
          builder: (context, constraints) => _Stage(
            stage: WildSpaceStage.forPair(
              constraints.biggest,
              creature: widget.creature,
              ally: party,
              partyLargest: widget.partyLargestScale,
            ),
            creature: widget.creature,
            party: party,
            accent: accent,
            clock: _clock,
            exhausted: widget.exhausted,
            entrance: widget.entrance,
            merge: widget.merge,
            mergeColors: widget.mergeColors,
            reject: widget.reject,
            breakFree: widget.breakFree,
            taken: widget.taken,
            allySummon: widget.allySummon,
            field: widget.fusionField,
            allyCaptureKey: widget.allyCaptureKey,
            wildCaptureKey: widget.wildCaptureKey,
            harvestCut: widget.harvestCut,
          ),
        ),
      ],
    );
  }
}

/// Where the two creatures stand in the landscape encounter frame. The
/// identity panel owns the top-left and the actions the bottom edge, so
/// the pair share a line just below the middle: the specimen right of
/// centre facing left, the ally left of centre facing it.
///
/// Sizes are space's own: each creature's box is its family scale times one
/// shared unit, and its size genetics scale it inside that box — so a let
/// beside a wing is as small here as it is out there. The unit is set by
/// the biggest creature the encounter could have to fit (the specimen or any
/// party member), so nothing resizes when an ally steps in.
class WildSpaceStage {
  WildSpaceStage(
    Size size, {
    double wildFamilyScale = 1,
    double allyFamilyScale = 1,
    double largest = 1,
  }) : unit = min(size.height * 0.26, size.height * 0.5 / max(largest, 0.5)),
       wild = Offset(size.width * 0.63, size.height * 0.58),
       ally = Offset(size.width * 0.31, size.height * 0.58),
       _wildFamily = wildFamilyScale,
       _allyFamily = allyFamilyScale;

  /// For [creature], met beside an [ally] if one is picked, in a party whose
  /// biggest member draws at [partyLargest] (family × size genetics).
  factory WildSpaceStage.forPair(
    Size size, {
    required Creature creature,
    Creature? ally,
    double partyLargest = 1,
  }) {
    final wildFamily = spaceFamilyScale(creature);
    return WildSpaceStage(
      size,
      wildFamilyScale: wildFamily,
      allyFamilyScale: ally == null ? 1 : spaceFamilyScale(ally),
      largest: max(wildFamily * sizeGene(creature), partyLargest),
    );
  }

  /// The box a family-scale-1 Alchemon is drawn in.
  final double unit;
  final Offset wild;
  final Offset ally;
  final double _wildFamily;
  final double _allyFamily;

  double get wildSize => unit * _wildFamily;
  double get allySize => unit * _allyFamily;
  Offset get meeting => Offset.lerp(ally, wild, 0.5)!;

  static double spaceFamilyScale(Creature c) =>
      CosmicGame.spaceSpeciesScale(c.mutationFamily ?? 'kin');
  static double sizeGene(Creature c) => visualsFromInstance(c, null).scale;
}

class _Stage extends StatelessWidget {
  const _Stage({
    required this.stage,
    required this.creature,
    required this.party,
    required this.accent,
    required this.clock,
    required this.exhausted,
    required this.entrance,
    required this.merge,
    required this.mergeColors,
    required this.reject,
    required this.breakFree,
    required this.taken,
    required this.allySummon,
    this.field,
    this.allyCaptureKey,
    this.wildCaptureKey,
    this.harvestCut,
  });

  final double? harvestCut;
  final FusionParticleField? field;
  final GlobalKey? allyCaptureKey;
  final GlobalKey? wildCaptureKey;

  final Animation<double> reject;
  final Animation<double> breakFree;
  final Animation<double> taken;

  /// 0→1 as the ally steps out of its summon tear.
  final Animation<double> allySummon;
  final WildSpaceStage stage;
  final Creature creature;
  final Creature? party;
  final Color accent;
  final Animation<double> clock;
  final bool exhausted;
  final Animation<double> entrance;
  final Animation<double> merge;
  final (Color, Color) mergeColors;

  @override
  Widget build(BuildContext context) {
    final ally = party;
    final field = this.field;
    return AnimatedBuilder(
      animation: Listenable.merge([
        merge,
        reject,
        breakFree,
        taken,
        allySummon,
      ]),
      builder: (context, _) {
        // Seconds into the merge (see [FusionParticleField]).
        final t = merge.value * FusionParticleField.duration;
        // A failed fusion throws the pair apart; a failed harvest shakes the
        // specimen loose; a held one draws it in.
        final r = reject.value;
        final knock = r > 0 && r < 1 ? sin(pi * r) : 0.0;
        final b = breakFree.value;
        final loose = b > 0 && b < 1;
        final shake = loose ? sin(b * 70) * 16 * (1 - b) : 0.0;
        final pop = loose ? 1 + 0.22 * sin(pi * b) : 1.0;
        final k = Curves.easeIn.transform(taken.value);
        // The ally grows out of its tear, as a companion does in space.
        final st = allySummon.value;
        final summoning = st < 1;
        final allyEmerge = summoning
            ? Curves.easeOutBack.transform(((st - 0.18) / 0.55).clamp(0.0, 1.0))
            : 1.0;
        final allyIn = summoning ? ((st - 0.15) / 0.3).clamp(0.0, 1.0) : 1.0;

        final allyShift = Offset(-48 * knock, 0);
        final wildShift = Offset(48 * knock + shake, 0);
        final wildAt = stage.wild + wildShift;
        final allyAt = stage.ally + allyShift;
        // The grains still standing are knocked back with their bodies.
        if (field != null) {
          field.shift[0] = allyShift;
          field.shift[1] = wildShift;
        }
        final allyCut = field?.cutY(0, t) ?? double.negativeInfinity;
        final wildCut =
            harvestCut ?? field?.cutY(1, t) ?? double.negativeInfinity;

        Widget place(Offset at, double box, Widget child) => Positioned(
          left: at.dx - box / 2,
          top: at.dy - box / 2,
          width: box,
          height: box,
          child: child,
        );

        // Each is read into grains from here, as it stands.
        Widget readable(GlobalKey? key, Widget child) =>
            RepaintBoundary(key: key, child: child);
        final emptied = field == null ? 0.0 : field.chamberEmpty(0, t);

        Widget particles({required bool back}) => IgnorePointer(
          child: CustomPaint(
            size: Size.infinite,
            painter: field == null
                ? null
                : FusionParticlePainter(
                    field,
                    () => t,
                    back: back,
                    // Alive while it is held waiting on the verdict.
                    clock: () => clock.value * 60,
                    repaint: Listenable.merge([merge, clock]),
                  ),
          ),
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            // The far side of the cloud, behind everything.
            particles(back: true),

            // The flash between a pair that would not fuse, and the light a
            // specimen sheds as it breaks out of the field.
            if (knock > 0 || loose)
              CustomPaint(
                size: Size.infinite,
                painter: _BurstPainter(
                  reject: knock > 0 ? r : null,
                  rejectAt: stage.meeting,
                  rejectColor: Color.lerp(mergeColors.$1, mergeColors.$2, 0.5)!,
                  breakFree: loose ? b : null,
                  breakAt: wildAt,
                  breakColor: accent,
                  unit: max(24.0, stage.wildSize * 0.24),
                ),
              ),

            if (ally != null && summoning)
              CustomPaint(
                size: Size.infinite,
                painter: _SlotPainter(
                  (canvas, _) => paintSummonTear(
                    canvas,
                    centre: allyAt,
                    height: stage.allySize * 1.35,
                    t: st,
                    color: specimenAccent(ally),
                  ),
                ),
              ),

            if (ally != null && allyIn > 0)
              place(
                allyAt,
                stage.allySize * 1.8,
                readable(
                  allyCaptureKey,
                  _Fading(
                    opacity: allyIn,
                    child: Transform.scale(
                      scale: 0.25 + 0.75 * allyEmerge,
                      child: Transform.flip(
                        flipX: true,
                        child: _FloatingSpecimen(
                          creature: ally,
                          accent: mergeColors.$1 == Colors.white
                              ? specimenAccent(ally)
                              : mergeColors.$1,
                          clock: clock,
                          size: stage.allySize,
                          exhausted: false,
                          cutY: allyCut,
                          emptied: emptied,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            if (k < 1)
              place(
                wildAt,
                stage.wildSize * 1.8,
                readable(
                  wildCaptureKey,
                  // Steps out of the tear on arrival.
                  AnimatedBuilder(
                    animation: entrance,
                    builder: (context, child) {
                      final raw = ((entrance.value - 0.15) / 0.55).clamp(
                        0.0,
                        1.0,
                      );
                      final step = Curves.easeOutBack.transform(raw);
                      final arrive = 0.45 + 0.55 * step;
                      return _Fading(
                        opacity: Curves.easeOut.transform(raw) * (1 - k),
                        child: Transform.scale(
                          scale: arrive * pop * (1 - k),
                          child: child,
                        ),
                      );
                    },
                    child: _FloatingSpecimen(
                      creature: creature,
                      accent: accent,
                      clock: clock,
                      size: stage.wildSize,
                      exhausted: exhausted,
                      cutY: wildCut,
                      emptied: emptied,
                    ),
                  ),
                ),
              ),

            // Everything else of the cloud, over both of them.
            particles(back: false),
          ],
        );
      },
    );
  }
}

/// Opacity that costs nothing when it is fully on.
class _Fading extends StatelessWidget {
  const _Fading({required this.opacity, required this.child});

  final double opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      opacity >= 0.999 ? child : Opacity(opacity: opacity, child: child);
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.reject,
    required this.rejectAt,
    required this.rejectColor,
    required this.breakFree,
    required this.breakAt,
    required this.breakColor,
    required this.unit,
  });

  final double? reject;
  final Offset rejectAt;
  final Color rejectColor;
  final double? breakFree;
  final Offset breakAt;
  final Color breakColor;
  final double unit;

  static const _hot = Color(0xFFFFF4DC);

  void _bloom(Canvas canvas, Offset c, double radius, Color color, double a) {
    if (a <= 0 || radius <= 0) return;
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          radius,
          [
            _hot.withValues(alpha: 0.85 * a),
            color.withValues(alpha: 0.5 * a),
            color.withValues(alpha: 0),
          ],
          const [0.0, 0.35, 1.0],
        ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final r = reject;
    if (r != null) {
      // The seam flares and blows the two apart.
      _bloom(
        canvas,
        rejectAt,
        40 + 210 * Curves.easeOut.transform(r),
        rejectColor,
        1 - r,
      );
    }
    final b = breakFree;
    if (b != null) {
      _bloom(
        canvas,
        breakAt,
        40 + unit * 5 * Curves.easeOut.transform(b),
        breakColor,
        1 - b,
      );
      // It sheds its own light as it tears loose.
      Disintegration.paint(
        canvas,
        centre: breakAt,
        unit: unit,
        breakUp: sin(pi * b) * 0.7,
        color: breakColor,
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => true;
}

// ── background ────────────────────────────────────────────────────────────

class _SpaceFieldPainter extends CustomPainter {
  _SpaceFieldPainter({
    required this.seed,
    required this.tint,
    required this.towards,
    required this.hasPlanet,
  });

  final int seed;
  final Color tint;
  final Offset towards;
  final bool hasPlanet;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF040509));

    // Light spilling from the planet's side of the frame (or, in open
    // space, a far haze of the creature's own element).
    final glowCentre = Offset(
      size.width / 2 + towards.dx * size.width * 0.55,
      size.height / 2 + towards.dy * size.height * 0.55,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          glowCentre,
          size.longestSide * 0.9,
          [
            tint.withValues(alpha: hasPlanet ? 0.16 : 0.10),
            tint.withValues(alpha: 0.03),
            Colors.transparent,
          ],
          [0.0, 0.45, 1.0],
        ),
    );
    if (!hasPlanet) {
      final far = Offset(size.width * 0.22, size.height * 0.3);
      canvas.drawCircle(
        far,
        size.shortestSide * 0.6,
        Paint()
          ..shader = ui.Gradient.radial(far, size.shortestSide * 0.6, [
            tint.withValues(alpha: 0.07),
            Colors.transparent,
          ]),
      );
    }

    final rng = Random(seed);
    final star = Paint();
    for (var i = 0; i < 170; i++) {
      final p = Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height,
      );
      final bright = rng.nextDouble();
      final r = bright > 0.96 ? 1.5 : (bright > 0.8 ? 1.0 : 0.6);
      star.color = Color.lerp(
        const Color(0xFFE8DCC8),
        const Color(0xFFB9C6E8),
        rng.nextDouble(),
      )!.withValues(alpha: 0.18 + bright * 0.55);
      canvas.drawCircle(p, r, star);
    }

    // Keep the middle, where the creature is, the darkest part of the frame.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          size.center(Offset.zero),
          size.shortestSide * 0.55,
          [const Color(0x66040509), Colors.transparent],
        ),
    );
  }

  @override
  bool shouldRepaint(_SpaceFieldPainter old) =>
      old.seed != seed ||
      old.tint != tint ||
      old.towards != towards ||
      old.hasPlanet != hasPlanet;
}

/// The planet, far larger than the frame and mostly outside it, turning very
/// slowly. The image is rasterised once; only its transform animates. The
/// side facing away from the frame falls into shadow, so what shows is a lit
/// limb curving toward the creature.
class _PlanetLayer extends StatelessWidget {
  const _PlanetLayer({
    required this.backdrop,
    required this.clock,
    required this.entrance,
  });

  final CosmicEncounterBackdrop backdrop;
  final Animation<double> clock;

  /// The planet rises in from further off the frame, on the same side it
  /// left the frame in space.
  final Animation<double> entrance;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Planet radius on screen, and the whole image's side from it.
    final planetR = size.shortestSide * 0.78;
    final side = planetR / CosmicEncounterBackdrop.planetRadiusFraction;
    final dir = backdrop.direction;
    final len = dir.distance < 0.01 ? 1.0 : dir.distance;
    final unit = dir / len;
    // Centre far enough off the frame that only a limb and its glow show.
    final reach = size.longestSide * 0.5 + planetR * 0.42;
    final centre = size.center(Offset.zero) + unit * reach;

    return Positioned(
      left: centre.dx - side / 2,
      top: centre.dy - side / 2,
      width: side,
      height: side,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: Listenable.merge([clock, entrance]),
          builder: (context, child) {
            final t = clock.value * 2 * pi;
            final rise = 1 - Curves.easeOutCubic.transform(entrance.value);
            return Transform.translate(
              offset:
                  Offset(sin(t) * 6, cos(t * 0.5) * 4) +
                  unit * (planetR * 0.85 * rise),
              child: rise <= 0
                  ? child
                  : Transform.scale(scale: 1 + 0.12 * rise, child: child),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedBuilder(
                animation: clock,
                builder: (context, child) => Transform.rotate(
                  angle: clock.value * 2 * pi * 0.05,
                  child: child,
                ),
                child: RepaintBoundary(
                  child: RawImage(
                    image: backdrop.image,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
              RepaintBoundary(
                child: CustomPaint(
                  painter: _NightSidePainter(radius: planetR, away: unit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NightSidePainter extends CustomPainter {
  _NightSidePainter({required this.radius, required this.away});

  final double radius;
  final Offset away;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final lit = c - away * radius;
    final dark = c + away * radius * 0.35;
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: c, radius: radius * 1.01)),
    );
    canvas.drawCircle(
      c,
      radius * 1.01,
      Paint()
        ..shader = ui.Gradient.linear(
          lit,
          dark,
          [Colors.transparent, const Color(0xFF040509).withValues(alpha: 0.82)],
          [0.18, 1.0],
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NightSidePainter old) =>
      old.radius != radius || old.away != away;
}

class _FloatingSpecimen extends StatelessWidget {
  const _FloatingSpecimen({
    required this.creature,
    required this.accent,
    required this.clock,
    required this.exhausted,
    this.size = 170,
    this.cutY = double.negativeInfinity,
    this.emptied = 0,
  });

  final Creature creature;
  final Color accent;
  final Animation<double> clock;
  final bool exhausted;
  final double size;

  /// A fusion's crest, from the box's centre: above it the body is grains
  /// and the sprite is cut away. Only the body — its light fades instead
  /// ([emptied]), or the cut would leave a hard edge across the glow.
  final double cutY;
  final double emptied;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.8,
      height: size * 1.8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // A pool of its element's light, as it had in space.
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accent.withValues(
                    alpha: (exhausted ? 0.12 : 0.24) * (1 - emptied),
                  ),
                  accent.withValues(alpha: 0),
                ],
              ),
            ),
            child: const SizedBox.expand(),
          ),
          ClipRect(
            clipper: SpriteCrestClipper(cutY),
            clipBehavior: cutY == double.negativeInfinity
                ? Clip.none
                : Clip.hardEdge,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: clock,
                builder: (context, child) {
                  final t = clock.value * 2 * pi * 20;
                  return Transform.translate(
                    offset: Offset(0, sin(t * 0.4) * 5),
                    child: Transform.rotate(
                      angle: exhausted ? 0.4 + sin(t * 0.18) * 0.05 : 0,
                      child: child,
                    ),
                  );
                },
                child: Opacity(
                  opacity: exhausted ? 0.72 : 1.0,
                  child: _SpecimenSprite(creature: creature, size: size),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecimenSprite extends StatelessWidget {
  const _SpecimenSprite({required this.creature, required this.size});

  final Creature creature;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (creature.spriteData == null) {
      return SizedBox(width: size, height: size);
    }
    final sheet = sheetFromCreature(creature);
    final visuals = visualsFromInstance(creature, null);
    return SizedBox(
      width: size,
      height: size,
      child: CreatureSprite(
        spritePath: sheet.path,
        totalFrames: sheet.totalFrames,
        rows: sheet.rows,
        frameSize: sheet.frameSize,
        stepTime: sheet.stepTime,
        scale: visuals.scale,
        saturation: visuals.saturation,
        brightness: visuals.brightness,
        hueShift: visuals.hueShiftDeg,
        isPrismatic: visuals.isPrismatic,
        mutation: visuals.mutation,
        tint: visuals.tint,
        alchemyEffect: visuals.alchemyEffect,
        variantFaction: visuals.variantFaction,
        elementType: visuals.elementType,
      ),
    );
  }
}

/// The encounter arriving through the same tear that swallowed space: a
/// slit of light in the dark that widens until nothing of the dark is left.
/// Held black first while the phone turns to landscape.
class _TearRevealPainter extends CustomPainter {
  _TearRevealPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) =>
      paintTearReveal(canvas, size, progress: progress, color: color);

  @override
  bool shouldRepaint(_TearRevealPainter old) =>
      old.progress != progress || old.color != color;
}

class _SlotPainter extends CustomPainter {
  _SlotPainter(this.draw);

  final void Function(Canvas canvas, Size size) draw;

  @override
  void paint(Canvas canvas, Size size) => draw(canvas, size);

  @override
  bool shouldRepaint(_SlotPainter old) => !identical(old.draw, draw);
}
