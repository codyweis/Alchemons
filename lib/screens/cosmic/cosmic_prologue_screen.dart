import 'package:alchemons/audio/audio.dart';
// lib/screens/cosmic/cosmic_prologue_screen.dart
//
// THE FIRST CROSSING — played once, the first time the player ever falls into
// cosmic space, before the exploration tutorial picks up.
//
// Flow:
//   1. Space blooms open: colour-shifting stars flare in and wink out, warp
//      streaks pull past, nebulae turn over slowly.
//   2. A Stabilized Harvester hangs in the middle. Tap it to retrieve it.
//   3. Four elemental stars unfurl — Fire, Water, Earth, Air.
//   4. Choosing one calls a prismatic Let of that element out of the dark, and
//      the player catches it with the harvester they just found.
//   5. Pops back to the cosmic screen, which runs the normal tutorial.

import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/wilderness/encounter_sheet.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/creature_stats.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/wilderness.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/wildlife_generator.dart';
import 'package:alchemons/services/wilderness_service.dart';
import 'package:alchemons/screens/cosmic/widgets/trippy_cosmos_painter.dart';
import 'package:alchemons/utils/app_font_family.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/fx/portal_harvest.dart';
import 'package:alchemons/widgets/fx/rift_vortex.dart';
import 'package:alchemons/widgets/harvester_glyph.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────
// RESULT
// ─────────────────────────────────────────────────────────

class CosmicPrologueResult {
  const CosmicPrologueResult({this.caught = false, this.chosenElement});

  /// True if the prismatic Let was actually captured.
  final bool caught;

  /// Which of the four elemental stars the player steered toward.
  final String? chosenElement;
}

enum _ProloguePhase { drifting, warping, choosing, entering, encounter }

/// The four elemental stars offered at the crossing.
const List<String> kPrologueElements = ['Fire', 'Water', 'Earth', 'Air'];

/// Particle palette for the crossing — the shop's alchemical drift, pulled
/// toward the cold end so it sits inside a star field instead of over black.
const List<Color> _cosmosParticleColors = [
  Color(0xFF7FE3FF),
  Color(0xFFB388FF),
  Color(0xFF6BE6C1),
  Color(0xFF4FA8FF),
  Color(0xFFC77DFF),
  Color(0xFFFFD08A),
  Color(0xFFFF8AB0),
];

// ─────────────────────────────────────────────────────────
// THE AUTHORED LET
// ─────────────────────────────────────────────────────────

/// Fixed stats for the Let waiting behind the gate.
const CreatureStats kCrossingLetStats = CreatureStats(
  speed: 2.5,
  intelligence: 2.5,
  strength: 2.5,
  beauty: 2.5,
  speedPotential: 76,
  intelligencePotential: 76,
  strengthPotential: 76,
  beautyPotential: 76,
);

/// Stamp the crossing's authored identity onto a freshly generated creature.
///
/// Two things are deliberately not left to the wild generator:
///   • **Pigment.** Fresh genetics can land on pale, vibrant or albino tinting.
///     The Let's prismatic sheen should read against true colours, not on top
///     of a washed-out or hue-shifted body, so the `tinting` track is forced
///     back to `normal`. Everything else about the genetics (size and so on)
///     is left alone.
///   • **Stats.** Fixed at 2.5 across the board with 76 Potential. The egg
///     payload honours these verbatim (`hasFixedStats`), so what hatches is
///     what is set here.
Creature shapeCrossingLet(Creature hydrated) {
  final pigment = Map<String, String>.from(hydrated.genetics?.variants ?? {})
    ..['tinting'] = 'normal';

  return hydrated.copyWith(
    genetics: Genetics(Map.unmodifiable(pigment)),
    stats: kCrossingLetStats,
    isPrismaticSkin: true,
  );
}

// ─────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────

class CosmicPrologueScreen extends StatefulWidget {
  const CosmicPrologueScreen({super.key});

  @override
  State<CosmicPrologueScreen> createState() => _CosmicPrologueScreenState();
}

class _CosmicPrologueScreenState extends State<CosmicPrologueScreen>
    with TickerProviderStateMixin {
  _ProloguePhase _phase = _ProloguePhase.drifting;
  String? _chosenElement;
  bool _harvesterClaimed = false;

  /// Whether the Stabilized Harvester actually landed in the inventory.
  /// The crossing has no exit, and the only way out is catching the Let —
  /// which needs a capture device. If the grant ever fails we must hand the
  /// exit back rather than trap the player in a cutscene.
  bool _harvesterGranted = false;

  /// Monotonic clock in "cosmos units" (~0.5 per second), driven by a Ticker.
  ///
  /// A repeating AnimationController was wrong here: its value snapped from 1
  /// back to 0 every cycle, and every rotation and phase derived from it jumped
  /// with it. Elapsed time never wraps, so nothing ever hitches.
  late final Ticker _clock;
  final ValueNotifier<double> _cosmos = ValueNotifier<double>(0);

  /// 0 → 1 as space fades up at the very start.
  late final AnimationController _fadeIn;

  /// 0 → 1 as the harvester bursts and the four stars unfurl.
  late final AnimationController _reveal;

  /// One-shot flare when the harvester is taken.
  late final AnimationController _claimFlash;

  /// The two-second hyperspace jump between finding the harvester and arriving
  /// at the gates.
  late final AnimationController _warp;

  /// The chosen portal swallowing the screen.
  late final AnimationController _enter;

  /// Where the chosen portal sat on screen, so the takeover grows from it.
  Offset? _portalOrigin;

  /// One per gate, so a tap can find where its portal is.
  final List<GlobalKey> _portalKeys = List.generate(
    kPrologueElements.length,
    (_) => GlobalKey(),
  );

  Creature? _encounterCreature;
  Creature? _partyCreature;

  /// Takes the Let that is standing there, as grains, rather than a copy.
  final PortalHarvest _harvest = PortalHarvest();

  /// The tapped gate's rift, carried on into the fall.
  RiftVortexField? _takeoverField;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _clock = createTicker((elapsed) {
      _cosmos.value = elapsed.inMicroseconds / 1e6 * 0.5;
    })..start();
    _fadeIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );
    _claimFlash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _warp = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    );
  }

  @override
  void dispose() {
    // Portrait, not "any". Re-allowing all four left the phone in whatever
    // it was physically held in — landscape, because the prologue just
    // demanded it — and cosmic space opened sideways. Every other landscape
    // screen in the app hands portrait back on the way out; see
    // VoidPortal.pushLandscape's returnOrientation.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _clock.dispose();
    _cosmos.dispose();
    _fadeIn.dispose();
    _reveal.dispose();
    _claimFlash.dispose();
    _warp.dispose();
    _enter.dispose();
    _harvest.dispose();
    super.dispose();
  }

  // ── harvester ────────────────────────────────────────

  Future<void> _claimHarvester() async {
    if (_harvesterClaimed) return;
    setState(() => _harvesterClaimed = true);
    HapticFeedback.heavyImpact();
    _claimFlash.forward(from: 0);

    // The grant must never be what strands the player in the cutscene — the
    // four gates unfurl either way, but a failure re-opens the exit.
    try {
      await context.read<AlchemonsDatabase>().inventoryDao.addItemQty(
        InvKeys.harvesterGuaranteed,
        1,
      );
      _harvesterGranted = true;
    } catch (_) {
      _harvesterGranted = false;
    }

    // Long enough to read "+1 added to inventory" before the jump.
    await Future.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;

    // Punch forward through two seconds of space to reach the gates.
    setState(() => _phase = _ProloguePhase.warping);
    HapticFeedback.mediumImpact();
    await _warp.forward(from: 0);
    if (!mounted) return;

    setState(() => _phase = _ProloguePhase.choosing);
    _reveal.forward(from: 0);
  }

  /// Hyperspace envelope: build speed, hold at the tunnel mouth, then drop out.
  double get _warpAmount {
    final p = _warp.value;
    if (p <= 0) return 0;
    if (p < 0.62) return Curves.easeInQuart.transform(p / 0.62);
    return 1 - Curves.easeOutCubic.transform((p - 0.62) / 0.38);
  }

  // ── elemental choice ─────────────────────────────────

  void _chooseElement(String element, int index) {
    if (_phase != _ProloguePhase.choosing) return;
    HapticFeedback.mediumImpact();

    // Grow the takeover from wherever that gate actually sits on screen.
    final box =
        _portalKeys[index].currentContext?.findRenderObject() as RenderBox?;
    final origin = box?.localToGlobal(box.size.center(Offset.zero));

    setState(() {
      _chosenElement = element;
      _portalOrigin = origin;
      _takeoverField = RiftVortexField(grains: 900, ringGrains: 140, motes: 40)
        ..open = 1;
      _phase = _ProloguePhase.entering;
    });

    // Build the creature while the portal is still swallowing the screen, so
    // it is ready the instant we arrive.
    _startEncounter(element);

    _enter.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      setState(() => _phase = _ProloguePhase.encounter);
    });
  }

  /// Call a prismatic Let of [element] out of the dark.
  void _startEncounter(String element) {
    final repo = context.read<CreatureCatalog>();

    var pool = repo.creatures
        .where(
          (c) =>
              c.mutationFamily?.toLowerCase() == 'let' &&
              c.types.any((t) => t == element),
        )
        .toList();

    if (pool.isEmpty) {
      // No Let for this element — fall back to anything of the element that is
      // not a Mystic, so the crossing always has something to offer.
      pool = repo.creatures
          .where(
            (c) =>
                c.rarity.toLowerCase() != 'mystic' &&
                c.types.any((t) => t == element),
          )
          .toList();
    }
    if (pool.isEmpty) {
      _finish(caught: false);
      return;
    }

    final picked = pool[Random().nextInt(pool.length)];
    final gen = WildlifeGenerator(
      repo,
      tuning: const WildlifeTuning(prismaticSkinChance: 1.0),
    );
    var hydrated = gen.generate(picked.id, rarity: 'legendary');
    if (hydrated == null) {
      _finish(caught: false);
      return;
    }

    if (!mounted) return;
    setState(() => _encounterCreature = shapeCrossingLet(hydrated));
  }

  void _finish({required bool caught}) {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pop(CosmicPrologueResult(caught: caught, chosenElement: _chosenElement));
  }

  // ── build ────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final accent = _chosenElement == null
        ? const Color(0xFF9C6BFF)
        : elementColor(_chosenElement!);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── deep field ──
            AnimatedBuilder(
              animation: Listenable.merge([_cosmos, _fadeIn, _reveal, _warp]),
              builder: (context, _) {
                return CustomPaint(
                  painter: TrippyCosmosPainter(
                    t: _cosmos.value,
                    fade: Curves.easeOut.transform(_fadeIn.value),
                    surge: Curves.easeOutCubic.transform(_reveal.value),
                    warp: _warpAmount,
                    accent: accent,
                  ),
                );
              },
            ),

            // ── mystical particle drift (same system as the shop) ──
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_fadeIn, _warp]),
                  // The fade goes to the motes' own alpha, not an Opacity
                  // widget: this rests at 0.85, and a partial Opacity over a
                  // layer that repaints every frame is an offscreen pass
                  // every frame for the whole crossing. The motes are points
                  // that barely overlap, so scaling each one's alpha looks
                  // the same.
                  builder: (context, _) => AlchemicalParticleBackground(
                    colors: _cosmosParticleColors,
                    densityMultiplier: 1.35,
                    // Particles wash out as the jump builds; they read as
                    // stationary grit against a moving star field otherwise.
                    opacity: 0.85 * _fadeIn.value * (1 - _warpAmount * 0.9),
                  ),
                ),
              ),
            ),

            if (_phase == _ProloguePhase.drifting) _driftingLayer(),
            if (_phase == _ProloguePhase.choosing) _choosingLayer(),
            if (_phase == _ProloguePhase.entering) _enteringLayer(),
            if (_phase == _ProloguePhase.encounter) ..._encounterLayer(),
          ],
        ),
      ),
    );
  }

  // ── phase 1: the harvester in the middle ─────────────

  Widget _driftingLayer() {
    return AnimatedBuilder(
      animation: Listenable.merge([_fadeIn, _cosmos, _claimFlash]),
      builder: (context, _) {
        final ready = _fadeIn.value;
        final t = _cosmos.value;
        final claim = _claimFlash.value;

        return Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Opacity(
                opacity: ((ready - 0.35) / 0.4).clamp(0.0, 1.0),
                child: GestureDetector(
                  onTap: context.soundAction(
                    _harvesterClaimed ? null : _claimHarvester,
                  ),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 190,
                        height: 190,
                        child: CustomPaint(
                          painter: _HarvesterRelicPainter(
                            t: t,
                            claim: claim,
                            taken: _harvesterClaimed,
                          ),
                          child: Center(
                            child: Transform.translate(
                              // Slow bob, as if it were adrift.
                              offset: Offset(0, sin(t * 0.9) * 6),
                              child: Transform.scale(
                                scale: 1 + claim * 0.55,
                                child: Opacity(
                                  opacity: (1 - claim).clamp(0.0, 1.0),
                                  child: const HarvesterGlyph(
                                    biomeId: universalHarvester,
                                    size: 82,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // The amber glow used to be a text Shadow with
                      // blurRadius 22: a gaussian pass on every glyph, every
                      // frame, since this whole layer repaints with the
                      // clock. A painted haze behind the line reads the same.
                      CustomPaint(
                        painter: const _LabelGlowPainter(Colors.amber),
                        child: Text(
                          _harvesterClaimed
                              ? 'STABILIZED HARVESTER SECURED'
                              : 'STABILIZED HARVESTER',
                          style: TextStyle(
                            fontFamily: appFontFamily(context),
                            color: Colors.amber.withValues(alpha: 0.95),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        _harvesterClaimed
                            ? '+1 added to inventory'
                            : 'TAP TO RETRIEVE',
                        style: TextStyle(
                          fontFamily: appFontFamily(context),
                          color: Colors.white.withValues(
                            alpha: 0.45 + 0.3 * sin(t * 2).abs(),
                          ),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _title(
              'FIRST CROSSING',
              'He defined hope as a "waking dream"',
              ((ready - 0.1) / 0.5).clamp(0.0, 1.0),
            ),
          ],
        );
      },
    );
  }

  // ── phase 2: four elemental stars ────────────────────

  Widget _choosingLayer() {
    return AnimatedBuilder(
      animation: Listenable.merge([_reveal, _cosmos]),
      builder: (context, _) {
        final r = _reveal.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 34),
                child: Wrap(
                  spacing: 26,
                  runSpacing: 18,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var i = 0; i < kPrologueElements.length; i++)
                      _ElementPortal(
                        key: _portalKeys[i],
                        element: kPrologueElements[i],
                        revealT: ((r - i * 0.13) / 0.5).clamp(0.0, 1.0),
                        clock: _cosmos,
                        onTap: context.soundTap(
                          () => _chooseElement(kPrologueElements[i], i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            _title('FOUR GATES', null, (r / 0.4).clamp(0.0, 1.0)),
          ],
        );
      },
    );
  }

  // ── phase 2.5: the gate swallows the screen ──────────

  Widget _enteringLayer() {
    final origin = _portalOrigin;
    final color = _portalColor(_chosenElement ?? 'Fire');
    return AnimatedBuilder(
      animation: Listenable.merge([_enter, _cosmos]),
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _PortalTakeoverPainter(
            origin: origin,
            field: _takeoverField!,
            color: color,
            t: _cosmos.value,
            progress: _enter.value,
          ),
        );
      },
    );
  }

  // ── phase 3: the prismatic Let ───────────────────────

  List<Widget> _encounterLayer() {
    final creature = _encounterCreature;
    if (creature == null) return const [];

    return [
      Center(
        child: _harvest.wrap(
          _PrologueSprite(
            creature: creature,
            size: 170,
            isPrismatic: true,
            flipHorizontal: false,
          ),
        ),
      ),
      if (_partyCreature != null)
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: MediaQuery.of(context).size.width * 0.32,
          child: Center(
            child: _PrologueSprite(
              creature: _partyCreature!,
              size: 140,
              isPrismatic: _partyCreature!.isPrismaticSkin == true,
              flipHorizontal: true,
            ),
          ),
        ),
      EncounterOverlay(
        encounter: WildEncounter(
          wildBaseId: creature.id,
          baseBreedChance: breedChanceForRarity(EncounterRarity.legendary),
          rarity: 'legendary',
          voidBred: true,
          source: 'cosmic_prologue',
        ),
        hydratedWildCreature: creature,
        party: const [],
        highlightPartyHUD: false,
        isTutorial: false,
        showFusionAction: false,
        // The crossing is not optional: hiding the Map action removes the only
        // exit from the encounter, and PopScope blocks system back. The one
        // exception is a harvester grant that failed — without a capture device
        // there is no way to finish, so the exit comes back.
        showMapAction: !_harvesterGranted,
        // The Let's rarity is an authored detail, not news.
        showRarityBadge: false,
        warnOnRun: true,
        onPreRollShake: () {},
        // The harvest is taken from the Let standing here — read into grains
        // and cut away behind the crest — not from a copy on a card.
        onHarvestInScene: (accent, task, profile) =>
            _harvest.run(context, accent, task, profile),
        onPartyCreatureSelected: (c) => setState(() => _partyCreature = c),
        onClosedWithResult: (success) => _finish(caught: success),
      ),
    ];
  }

  // ── shared chrome ────────────────────────────────────

  Widget _title(String kicker, String? line, double opacity) {
    if (opacity <= 0) return const SizedBox.shrink();
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 14, left: 60),
          child: Opacity(
            opacity: opacity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kicker,
                  style: TextStyle(
                    fontFamily: appFontFamily(context),
                    color: Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                  ),
                ),
                if (line != null)
                  Text(
                    line,
                    style: TextStyle(
                      fontFamily: appFontFamily(context),
                      color: Colors.white70,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// ELEMENT STAR CARD
// ─────────────────────────────────────────────────────────

class _ElementPortal extends StatefulWidget {
  const _ElementPortal({
    super.key,
    required this.element,
    required this.revealT,
    required this.clock,
    required this.onTap,
  });

  final String element;
  final double revealT;

  /// The crossing's monotonic clock (cosmos units, ~0.5 per second).
  final ValueListenable<double> clock;
  final VoidCallback onTap;

  @override
  State<_ElementPortal> createState() => _ElementPortalState();
}

class _ElementPortalState extends State<_ElementPortal> {
  // The same grain rift the wilderness and space use, small: a tipped disk
  // falling into a black core. Built once; the painter advances it.
  final RiftVortexField _field = RiftVortexField(
    grains: 520,
    ringGrains: 90,
    motes: 22,
    grainSize: 1.5,
  );

  @override
  Widget build(BuildContext context) {
    if (widget.revealT <= 0) return const SizedBox.shrink();

    return Opacity(
      opacity: widget.revealT.clamp(0.0, 1.0),
      child: GestureDetector(
        onTap: context.soundAction(widget.onTap),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 132,
          height: 132,
          child: CustomPaint(
            // No name, no icon — the colour is the whole label.
            painter: _VortexPortalPainter(
              field: _field,
              color: _portalColor(widget.element),
              clock: widget.clock,
              open: widget.revealT,
            ),
          ),
        ),
      ),
    );
  }
}

/// The element's colour lifted toward white so muddy ones still read against
/// near-black.
Color _portalColor(String element) =>
    Color.lerp(elementColor(element), Colors.white, 0.22)!;

/// Where on the crossing's clock each rift was last stepped, so a field that
/// starts mid-clock advances by real elapsed time rather than racing to catch
/// up.
final Expando<double> _steppedAt = Expando<double>('portal rift');

void _stepToClock(RiftVortexField field, double cosmos) {
  // Cosmos units run at ~0.5 per second; the field wants seconds.
  final now = cosmos * 2;
  final last = _steppedAt[field] ?? now;
  _steppedAt[field] = now;
  field.step((now - last).clamp(0.0, 0.1));
}

/// Steps [field] to the clock and draws it, the rift's own way.
class _VortexPortalPainter extends CustomPainter {
  _VortexPortalPainter({
    required this.field,
    required this.color,
    required this.clock,
    required this.open,
  }) : super(repaint: clock);

  final RiftVortexField field;
  final Color color;
  final ValueListenable<double> clock;
  final double open;

  static const double radius = 60;

  @override
  void paint(Canvas canvas, Size size) {
    _stepToClock(field, clock.value);
    field.open = Curves.easeOutCubic.transform(open.clamp(0.0, 1.0));
    field.paint(
      canvas,
      size,
      size.center(Offset.zero),
      radius,
      RiftPalette(color),
      backdrop: false,
    );
  }

  @override
  bool shouldRepaint(_VortexPortalPainter old) =>
      old.open != open || old.color != color || old.field != field;
}

/// The chosen gate rushing up to swallow the screen.
///
/// It is the same rift, carried on: spun up and falling in. The field's own
/// dive zooms the grains past and ends black, so the encounter cuts in from
/// the dark rather than from a wash of the element colour.
class _PortalTakeoverPainter extends CustomPainter {
  const _PortalTakeoverPainter({
    required this.origin,
    required this.field,
    required this.color,
    required this.t,
    required this.progress,
  });

  final Offset? origin;
  final RiftVortexField field;
  final Color color;
  final double t;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final from = origin ?? size.center(Offset.zero);
    final p = Curves.easeInCubic.transform(progress.clamp(0.0, 1.0));

    // Drift the rift to centre as it grows, so we fall straight into it.
    final centre = Offset.lerp(from, size.center(Offset.zero), p * 0.85)!;

    _stepToClock(field, t);
    field
      ..charge = p
      ..dive = p;
    field.paint(
      canvas,
      size,
      centre,
      _VortexPortalPainter.radius * (1 + p * 3),
      RiftPalette(color),
      backdrop: false,
    );
  }

  @override
  bool shouldRepaint(_PortalTakeoverPainter old) =>
      old.progress != progress || old.t != t || old.origin != origin;
}

// ─────────────────────────────────────────────────────────
// HARVESTER RELIC
// ─────────────────────────────────────────────────────────

class _HarvesterRelicPainter extends CustomPainter {
  const _HarvesterRelicPainter({
    required this.t,
    required this.claim,
    required this.taken,
  });

  final double t;
  final double claim;
  final bool taken;

  static const _gold = Color(0xFFFFC107);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final base = size.width * 0.26;
    final breathe = 0.9 + 0.1 * sin(t * 1.5);
    final fade = taken ? (1 - claim).clamp(0.0, 1.0) : 1.0;

    // Halo. Was a drawCircle under MaskFilter.blur with a sigma animated
    // every frame — a gaussian pass per frame for as long as the harvester
    // sits there. The same blurred disc as one radial gradient.
    _paintBlurredDisc(
      canvas,
      c,
      base * 2.4 * breathe * (1 + claim * 1.4),
      _gold.withValues(alpha: (0.16 + claim * 0.3) * (1 - claim * 0.5)),
      22 + claim * 40,
    );

    // Three nested alchemical rings, each turning its own way.
    for (var i = 0; i < 3; i++) {
      final rr = base * (0.9 + i * 0.42) * breathe;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(t * (i.isEven ? 0.3 : -0.42) + i);
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: rr),
        0,
        pi * 1.45,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = _gold.withValues(alpha: 0.55 * fade),
      );
      canvas.restore();
    }

    // Orbiting motes.
    for (var i = 0; i < 7; i++) {
      final a = t * 0.9 + i * (pi * 2 / 7);
      final rr = base * 1.75 * breathe * (1 + claim * 1.6);
      canvas.drawCircle(
        Offset(c.dx + cos(a) * rr, c.dy + sin(a) * rr * 0.55),
        2.4,
        Paint()..color = _gold.withValues(alpha: 0.8 * fade),
      );
    }

    // Retrieval flash.
    if (claim > 0) {
      canvas.drawCircle(
        c,
        base * 3.2 * Curves.easeOutCubic.transform(claim),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - claim)
          ..color = Colors.white.withValues(alpha: 0.8 * (1 - claim)),
      );
    }
  }

  @override
  bool shouldRepaint(_HarvesterRelicPainter old) =>
      old.t != t || old.claim != claim || old.taken != taken;
}

/// What `drawCircle(at, radius, Paint()..color = color
/// ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma))` drew, as one
/// radial gradient and no filter pass.
///
/// `paintSoftCircle` falls off linearly, which spreads a glow this big
/// (radius about 5 sigma) visibly wider and dimmer than the blur it replaces.
/// These stops follow the blurred disc's real edge instead: across the rim
/// a gaussian-blurred disc is the error function of the distance from it.
void _paintBlurredDisc(
  Canvas canvas,
  Offset at,
  double radius,
  Color color,
  double sigma,
) {
  if (color.a <= 0 || radius <= 0) return;
  final s = max(sigma, 0.01);
  // A blurred disc's half-brightness rim sits a little inside the disc:
  // the curved edge loses more light outward than it gains. sigma^2 / 2R is
  // that shift to first order, capped so a small disc keeps a core.
  final edge = radius - min(s * s / (2 * radius), radius * 0.5);
  final outer = edge + s * 3;
  final inner = max(0.0, edge - s * 3);
  const steps = 12;
  final stops = <double>[0];
  final colors = <Color>[];
  double level(double r) => 0.5 * (1 - _erf((r - edge) / (s * sqrt2)));
  colors.add(color.withValues(alpha: color.a * level(0)));
  for (var i = 0; i <= steps; i++) {
    final r = inner + (outer - inner) * i / steps;
    if (r <= 0) continue;
    stops.add(r / outer);
    colors.add(color.withValues(alpha: i == steps ? 0 : color.a * level(r)));
  }
  canvas.drawCircle(
    at,
    outer,
    Paint()..shader = ui.Gradient.radial(at, outer, colors, stops),
  );
}

/// Abramowitz and Stegun 7.1.26: within 1.5e-7, far below one alpha step.
double _erf(double x) {
  final sign = x < 0 ? -1.0 : 1.0;
  final a = x.abs();
  final t = 1 / (1 + 0.3275911 * a);
  final y =
      1 -
      (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t -
                      0.284496736) *
                  t +
              0.254829592) *
          t *
          exp(-a * a);
  return sign * y;
}

/// A soft glow behind a line of text, standing in for a blurred text Shadow.
///
/// A `Shadow(blurRadius: 22)` puts a sigma-13 haze around the glyphs; across
/// a single line that reads as a wide, low ellipse of the colour, which is
/// what this paints — a stretched radial gradient, no filter.
class _LabelGlowPainter extends CustomPainter {
  const _LabelGlowPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // About two sigma of spread past the glyphs, as the shadow had.
    final rx = size.width / 2 + 26;
    final ry = size.height / 2 + 22;
    final centre = size.center(Offset.zero);
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.scale(rx / ry, 1);
    canvas.drawCircle(
      Offset.zero,
      ry,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          ry,
          [
            color.withValues(alpha: 0.30),
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.06),
            color.withValues(alpha: 0),
          ],
          const [0, 0.45, 0.75, 1],
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LabelGlowPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────
// SPRITE
// ─────────────────────────────────────────────────────────

class _PrologueSprite extends StatelessWidget {
  const _PrologueSprite({
    required this.creature,
    required this.size,
    required this.isPrismatic,
    required this.flipHorizontal,
  });

  final Creature creature;
  final double size;
  final bool isPrismatic;
  final bool flipHorizontal;

  @override
  Widget build(BuildContext context) {
    final visuals = visualsFromInstance(creature, null);

    Widget sprite;
    if (creature.spriteData != null) {
      final sheet = sheetFromCreature(creature);
      sprite = SizedBox(
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
          isPrismatic: isPrismatic,
          tint: visuals.tint,
          alchemyEffect: visuals.alchemyEffect,
          costumes: visuals.costumes,
          variantFaction: visuals.variantFaction,
          elementType: visuals.elementType,
          effectSlotSize: size,
        ),
      );
    } else {
      sprite = SizedBox(
        width: size,
        height: size,
        child: Icon(AppIcons.pets, color: Colors.white24, size: size * 0.5),
      );
    }

    if (flipHorizontal) {
      return Transform.scale(scaleX: -1, child: sprite);
    }
    return sprite;
  }
}
