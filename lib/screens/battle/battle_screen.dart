import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/battle_arena_art.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/games/cosmic_survival/components/survival_hud.dart' show HudGlass, HudInk, HudTubePainter, hudMono;
import 'package:alchemons/screens/battle/battle_hub_screen.dart';
import 'package:alchemons/widgets/instance_widgets/specimen_case.dart' show CaseLightPainter, elementLight;
import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/screens/stadium/racer_gate.dart' show stadiumSprite;
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:alchemons/widgets/battle/battle_arena_preview.dart'
    show battleArenaPreviewSideways, battleArenaPreviewZoom;
import 'package:alchemons/widgets/fx/fusion_particles.dart' show SpecimenGrains;
import 'package:alchemons/widgets/fx/grain_assembly.dart';
import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  THE BATTLE SCREEN: you against the computer, two at a time from four
//
//  The floor is the game (cosmic_game_battle.dart), framed between the
//  other side's strip at the top and your hand at the bottom: your two on
//  the field (their health and specials, which fire on their own), your
//  bench (tap one, then the field card it replaces: one of your two swaps)
//  and your swaps left. Tap an enemy, on the floor or in the strip, to
//  make it your side's focus.
// ─────────────────────────────────────────────────────────────────────────────

const Color _ink = Color(0xFFE6E2DA);
const Color _muted = Color(0xFF8E8C88);
const Color _bg = Color(0xFF09090B);
const Color _bg1 = Color(0xFF131316);

/// Where the battle keeps the team last brought, by instance id.
const String kBattleTeamKey = 'battle_team_v1';

/// The HUD's bands, which the floor is framed between.
const double _kTopBand = 72;
const double _kBottomBand = 186;

/// A computer side for [team]: [team.length] catalog species of different
/// families (no Mystics), each at the team's average stats and level, so the
/// two sides are even and the fight is about who brings what.
List<CosmicPartyMember> battleRivalFor(
  CreatureCatalog catalog,
  List<CosmicPartyMember> team, {
  int? seed,
}) {
  final rng = Random(seed);
  final pool =
      catalog.creatures
          .where(
            (c) =>
                c.spriteData != null &&
                c.types.isNotEmpty &&
                (c.mutationFamily ?? '').toLowerCase() != 'mystic' &&
                (c.mutationFamily ?? '').isNotEmpty,
          )
          .toList()
        ..shuffle(rng);
  final picked = <Creature>[];
  final families = <String>{};
  for (final c in pool) {
    if (picked.length == team.length) break;
    if (families.add(c.mutationFamily!.toLowerCase())) picked.add(c);
  }
  for (final c in pool) {
    if (picked.length == team.length) break;
    if (!picked.contains(c)) picked.add(c);
  }
  double avg(double Function(CosmicPartyMember m) f) =>
      team.fold(0.0, (sum, m) => sum + f(m)) / team.length;
  final level = avg((m) => m.level.toDouble()).round();
  return [
    for (var i = 0; i < picked.length; i++)
      CosmicPartyMember(
        instanceId: 'rival:$i:${picked[i].id}',
        baseId: picked[i].id,
        displayName: picked[i].name,
        element: picked[i].types.first,
        family: picked[i].mutationFamily!,
        level: level,
        statSpeed: avg((m) => m.statSpeed),
        statIntelligence: avg((m) => m.statIntelligence),
        statStrength: avg((m) => m.statStrength),
        statBeauty: avg((m) => m.statBeauty),
        slotIndex: i,
        staminaBars: 3,
        staminaMax: 3,
        spriteSheet: sheetFromCreature(picked[i]),
        spriteVisuals: visualsFromInstance(picked[i], null),
      ),
  ];
}

/// The battle hub: the arena, the four you bring, the computer's four, then
/// the battle.
Future<void> openBattleAgainstComputer(BuildContext context) =>
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const BattleHubScreen()),
    );

class BattleScreen extends StatefulWidget {
  const BattleScreen({
    super.key,
    required this.team,
    required this.rival,
    this.rivalName = 'THE COMPUTER',
    this.arena = 'obsidian',
    this.leaveLabel = 'BACK TO THE HUB',
    this.onFinished,
    this.fromRect,
  });

  final List<CosmicPartyMember> team;
  final List<CosmicPartyMember> rival;
  final String rivalName;

  /// The result card's way out (the hub's, or the Trials').
  final String leaveLabel;

  /// The arena it is fought in (models/battle_arenas.dart): the host's.
  final String arena;

  /// Told each fight's winner once it is decided — 0 you, 1 them, null a
  /// draw — and when, in seconds (the hub keeps the record, the Trials the
  /// ladder).
  final Future<void> Function(int? winner, double at)? onFinished;

  /// Where the hub showed the arena, on screen: the floor flies from there
  /// into the fight, turning upright as it grows, and back there after.
  /// Null fades in from dark.
  final Rect? fromRect;

  /// The way in from the hub: the hub stays under it while the floor flies.
  static Route<void> route(BattleScreen screen) => PageRouteBuilder<void>(
    opaque: false,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (_, _, _) => screen,
  );

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen>
    with TickerProviderStateMixin {
  CosmicGame? _game;
  CosmicBattle? _battle;
  bool _loaded = false;
  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier(0);
  final ValueNotifier<double> _time = ValueNotifier(0);

  /// The bench Alchemon picked to swap in, waiting for which one goes out.
  int? _swapIn;

  /// The floor's flight: 0 on the hub's stage, 1 framed as the fight.
  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 820),
    value: widget.fromRect == null ? 1 : 0,
  );

  /// The flying floor over the game (1), or the game itself (0).
  late final AnimationController _cover = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: widget.fromRect == null ? 0 : 1,
  );

  /// The HUD slid in (1) or out (0).
  late final AnimationController _hud = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  /// Dark over everything: the way in without a stage, and AGAIN.
  late final AnimationController _dark = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
    value: widget.fromRect == null ? 1 : 0,
  );

  /// The result card coming up, 0..1, its parts in turn.
  late final AnimationController _card = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  late final BattleFloor _flightFloor = battleFloorFor(
    widget.arena,
    rx: kBattleFloorHalfWidth,
    ry: kBattleFloorHalfHeight,
  );

  bool _reported = false;
  Timer? _cardTimer;
  bool _leaving = false;
  bool _gameHidden = false;

  /// The result card shows who did what (DETAILS) in place of the two
  /// fours.
  bool _details = false;

  /// The result's word, read into grains to gather.
  GrainAssembly? _word;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _frame.value++;
      _time.value = elapsed.inMicroseconds / 1e6;
      final b = _battle;
      if (b != null && b.over && !_reported) {
        _reported = true;
        unawaited(widget.onFinished?.call(b.result!.winner, b.result!.at));
        unawaited(_readWord(b.result!.winner));
        // The last fall, slowed, and the light rising off the winners'
        // half first; then the card.
        _cardTimer = Timer(const Duration(milliseconds: 1700), () {
          if (mounted) unawaited(_card.forward(from: 0));
        });
      }
    })..start();
    _flight.addStatusListener((s) {
      if (s == AnimationStatus.completed) _maybeBegin();
    });
    unawaited(_start());
    unawaited(context.read<AudioController>().playBossBattleMusic());
    if (widget.fromRect != null) unawaited(_flight.forward());
  }

  Future<void> _start() async {
    final game = CosmicGame(
      world_: CosmicWorld.generate(seed: 5),
      onMeterChanged: () {},
      onSound: _sound,
    );
    setState(() => _game = game);
    await game.loaded;
    if (!mounted) return;
    _loaded = true;
    _maybeBegin();
  }

  /// The fight starts once the floor has landed and the game is ready.
  void _maybeBegin() {
    if (!_loaded || _battle != null || _flight.value < 1 || _leaving) return;
    _begin();
  }

  void _begin() {
    final game = _game!;
    _cardTimer?.cancel();
    _card.value = 0;
    _reported = false;
    _word = null;
    final b = game.startBattle(
      home: widget.team,
      away: widget.rival,
      center: game.ship.pos,
      arena: widget.arena,
    );
    setState(() {
      _battle = b;
      _swapIn = null;
      _details = false;
    });
    // The game takes over from the flying floor, the HUD slides in, and
    // the two sides gather out of grains on their places.
    unawaited(_cover.reverse());
    unawaited(_hud.forward(from: 0));
    if (_dark.value > 0) unawaited(_dark.reverse());
  }

  /// The card goes quickly, by the way it came.
  Future<void> _clearCard() => _card.animateBack(
    0,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeIn,
  );

  Future<void> _again() async {
    HapticFeedback.mediumImpact();
    unawaited(_clearCard());
    await _dark.forward();
    if (!mounted) return;
    _hud.value = 0;
    _begin();
  }

  /// Back to the hub: the HUD slides away and the floor flies back into the
  /// hub's stage (or the screen goes dark), then the page goes.
  Future<void> _back() async {
    if (_leaving) return;
    _leaving = true;
    _cardTimer?.cancel();
    unawaited(_hud.reverse());
    await _clearCard();
    if (!mounted) return;
    if (widget.fromRect != null) {
      await _cover.forward();
      // The flying floor covers it now: the game goes, so what the floor
      // uncovers as it shrinks is the hub.
      if (!mounted) return;
      setState(() => _gameHidden = true);
      await _flight.reverse();
    } else {
      await _dark.forward();
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _sound(SoundCue cue) {
    if (!mounted) return;
    unawaited(context.read<AudioController>().playSound(cue));
  }

  /// The result's word in grains, for the card to gather.
  Future<void> _readWord(int? winner) async {
    final word = switch (winner) {
      0 => 'VICTORY',
      1 => 'DEFEAT',
      _ => 'DRAW',
    };
    final color = switch (winner) {
      0 => kBattleBrass,
      1 => kBattleSilver,
      _ => _ink,
    };
    final style = bracketText(
      context,
      26,
      Colors.white,
      weight: FontWeight.w800,
      letterSpacing: 5,
    );
    final grains = await readWordGrains(word, style);
    if (!mounted || grains == null) return;
    setState(() => _word = GrainAssembly(grains, accent: color));
  }

  @override
  void dispose() {
    _ticker.dispose();
    _cardTimer?.cancel();
    _frame.dispose();
    _time.dispose();
    for (final c in [_flight, _cover, _hud, _dark, _card]) {
      c.dispose();
    }
    _flightFloor.dispose();
    _game?.endBattle();
    super.dispose();
  }

  Future<void> _leave() async {
    final b = _battle;
    if (b != null && !b.over) {
      final ok = await showBracketConfirm(
        context,
        palette: BracketPalette.dark,
        accent: kLeaveQuietAccent,
        title: 'LEAVE THE BATTLE?',
        message: 'The fight ends here. Nothing is lost.',
        confirmLabel: 'LEAVE',
        cancelLabel: 'STAY',
      );
      if (!ok || !mounted) return;
    }
    await _back();
  }

  // ── your hand ─────────────────────────────────────────────────────────────

  void _tapField(int spot) {
    final game = _game;
    final b = _battle;
    if (game == null || b == null || b.over) return;
    final side = b.sides[0];
    final swapIn = _swapIn;
    if (swapIn != null) {
      setState(() => _swapIn = null);
      if (game.battleSummon(0, swapIn, spot: spot)) {
        HapticFeedback.mediumImpact();
      } else if (side.at(spot) != null) {
        showGameSnack(context, 'It has only just arrived.');
      }
      return;
    }
    if (side.at(spot) == null) return;
    // A field card on its own does nothing: swaps start from the bench.
    showGameSnack(context, 'Tap one on the bench to swap it in here.');
  }

  /// A tap on the floor: one of theirs becomes your focus (again: let go).
  void _tapFloor(Offset at) {
    final game = _game;
    if (game == null || _battle == null) return;
    final hit = game.battleCreatureAt(at);
    if (hit == null || hit.$1 != 1) return;
    _focus(hit.$2);
  }

  void _focus(int creature) {
    final game = _game;
    if (game == null) return;
    if (game.focusBattleTarget(0, creature)) HapticFeedback.selectionClick();
  }

  void _tapBench(int creature) {
    final game = _game;
    final b = _battle;
    if (game == null || b == null || b.over) return;
    final side = b.sides[0];
    final c = side.creatures[creature];
    if (c.fallen || c.onField) return;
    if (side.spots.contains(null)) {
      if (game.battleSummon(0, creature)) HapticFeedback.mediumImpact();
      return;
    }
    if (side.swapsLeft <= 0) {
      showGameSnack(context, 'No swaps left.');
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _swapIn = _swapIn == creature ? null : creature);
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final size = MediaQuery.sizeOf(context);
    final insets = EdgeInsets.only(
      top: pad.top + _kTopBand,
      bottom: pad.bottom + _kBottomBand,
    );
    final band = Rect.fromLTRB(0, insets.top, size.width, size.height - insets.bottom);
    final b = _battle;
    if (b != null) b.viewInsets = insets;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // The game draws the open world until the battle begins: kept
            // out of sight, but mounted, so it loads.
            if (_game != null)
              Positioned.fill(
                child: Opacity(
                  opacity: b == null || _gameHidden ? 0 : 1,
                  child: GameWidget(game: _game!),
                ),
              ),
            // Taps on the floor are the battle's, never the ship's.
            if (b != null)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _tapFloor(d.localPosition),
                ),
              ),
            // The floor flying in from the hub's stage, and out again.
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_flight, _cover, _time]),
                  builder: (context, _) => _cover.value <= 0
                      ? const SizedBox.shrink()
                      : Opacity(
                          opacity: _cover.value,
                          child: CustomPaint(
                            painter: _FlightPainter(
                              floor: _flightFloor,
                              t: Curves.easeInOutCubic.transform(_flight.value),
                              from: widget.fromRect,
                              band: band,
                              time: _time.value,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                ),
              ),
            ),
            if (b != null && !_gameHidden)
              ValueListenableBuilder<int>(
                valueListenable: _frame,
                builder: (context, _, _) {
                  final h = Curves.easeOutCubic.transform(_hud.value);
                  // Under the result card, the HUD steps back.
                  final dim = 1 - 0.6 * Curves.easeOut.transform(
                    (_card.value * 3).clamp(0.0, 1.0),
                  );
                  return Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        child: Transform.translate(
                          offset: Offset(0, -(1 - h) * 90),
                          child: Opacity(
                            opacity: h * dim,
                            child: _TopBand(
                              battle: b,
                              rivalName: widget.rivalName,
                              padTop: pad.top,
                              onLeave: _leave,
                              onFocus: _focus,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Transform.translate(
                          offset: Offset(0, (1 - h) * 150),
                          child: Opacity(
                            opacity: h * dim,
                            child: _Hand(
                              battle: b,
                              swapIn: _swapIn,
                              padBottom: pad.bottom,
                              onField: _tapField,
                              onBench: _tapBench,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            if (b != null && b.result != null)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _card,
                  builder: (context, _) => _card.value <= 0
                      ? const SizedBox.shrink()
                      : _ResultCard(
                          battle: b,
                          t: _card.value,
                          word: _word,
                          onAgain: _again,
                          onLeave: _back,
                          leaveLabel: widget.leaveLabel,
                          details: _details,
                          onDetails: () {
                            HapticFeedback.selectionClick();
                            setState(() => _details = !_details);
                          },
                        ),
                ),
              ),
            // Dark over all of it, for the way in without a stage and for
            // AGAIN.
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _dark,
                  builder: (context, _) => _dark.value <= 0
                      ? const SizedBox.shrink()
                      : ColoredBox(
                          color: _bg.withValues(
                            alpha: Curves.easeInOut.transform(_dark.value),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The floor in flight: from the hub's stage (on its side, at the stage's
/// zoom, clipped to it) to the fight's opening frame (upright, the whole
/// floor in the band), the hub going dark behind it. Both ends match what
/// is drawn there, so the hand-overs are seamless.
class _FlightPainter extends CustomPainter {
  _FlightPainter({
    required this.floor,
    required this.t,
    required this.from,
    required this.band,
    required this.time,
  });

  final BattleFloor floor;
  final double t;
  final Rect? from;
  final Rect band;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Offset.zero & size;
    final start = from ?? band;
    canvas.drawRect(screen, Paint()..color = _bg.withValues(alpha: t));
    final aspect = band.width / band.height;
    final widest = max(
      kBattleFloorHalfHeight * 2 + 80,
      (kBattleFloorHalfWidth * 2 + 80) / aspect,
    );
    final z1 = band.height / widest;
    final z0 = from == null ? z1 : battleArenaPreviewZoom(start.size);
    final sideways = from != null && battleArenaPreviewSideways(start.size);
    final zoom = z0 * pow(z1 / z0, t);
    final at = Offset.lerp(start.center, band.center, t)!;
    final clip = Rect.lerp(start, screen, t)!;
    canvas.save();
    canvas.clipRect(clip);
    canvas.translate(at.dx, at.dy);
    canvas.scale(zoom);
    if (sideways) canvas.rotate(-pi / 2 * (1 - t));
    floor.paint(
      canvas,
      Offset.zero,
      time,
      Rect.fromCenter(center: Offset.zero, width: 2e4, height: 2e4),
    );
    canvas.restore();
    // The stage's own vignette, let go of as it grows.
    if (t < 1 && from != null) {
      canvas.save();
      canvas.clipRect(clip);
      canvas.drawRect(
        clip,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.45 * (1 - t)),
            ],
            stops: const [0.6, 1.0],
          ).createShader(clip),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FlightPainter old) =>
      old.t != t || old.time != time || old.from != from || old.band != band;
}

// ── pieces ──────────────────────────────────────────────────────────────────

/// A creature's sprite: lit, dimmed on the bench, ash when fallen.
Widget _portrait(CosmicPartyMember m, double size, {double opacity = 1}) {
  Widget sprite = SizedBox(
    width: size,
    height: size,
    child: stadiumSprite(m, size),
  );
  if (opacity < 0.3) {
    sprite = ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        0.33, 0.33, 0.33, 0, 0, //
        0.33, 0.33, 0.33, 0, 0, //
        0.33, 0.33, 0.33, 0, 0, //
        0, 0, 0, 1, 0, //
      ]),
      child: sprite,
    );
  }
  return Opacity(opacity: opacity, child: sprite);
}

/// A creature in a small lit case, the specimen case's light in its
/// element's colour; dim on the bench, dark and ash once fallen.
class _Case extends StatelessWidget {
  const _Case({
    required this.creature,
    required this.width,
    required this.height,
    this.strength = 1,
    this.lit,
  });

  final BattleCreature creature;
  final double width;
  final double height;
  final double strength;

  /// Lit from below in this colour (a focus, a pick), or plain.
  final Color? lit;

  @override
  Widget build(BuildContext context) {
    final m = creature.member;
    final fallen = creature.fallen;
    return CustomPaint(
      foregroundPainter: BracketFramePainter(
        color: lit?.withValues(alpha: 0.9) ?? Colors.white.withValues(alpha: 0.06),
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: CaseLightPainter(
            color: elementLight(m.element),
            strength: fallen ? 0 : strength,
          ),
          child: Center(
            child: _portrait(
              m,
              min(width, height) * 0.8,
              opacity: fallen ? 0.22 : (creature.onField ? 1 : 0.8),
            ),
          ),
        ),
      ),
    );
  }
}

/// A glass tube, the survival HUD's, filled as far as [share].
class _Tube extends StatelessWidget {
  const _Tube({required this.share, required this.color, this.height = 6});

  final double share;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: CustomPaint(
      painter: HudTubePainter(share.clamp(0.0, 1.0), color),
      child: const SizedBox.expand(),
    ),
  );
}

/// Swaps left, as beads.
class _SwapPips extends StatelessWidget {
  const _SwapPips({required this.left, required this.color});

  final int left;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < kBattleSwaps; i++)
        Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: i < left
                ? RadialGradient(
                    center: const Alignment(-0.3, -0.4),
                    colors: [Color.lerp(color, Colors.white, 0.4)!, color],
                  )
                : null,
            color: i < left ? null : Colors.white.withValues(alpha: 0.08),
          ),
        ),
    ],
  );
}

String _clock(double seconds) {
  final s = seconds.ceil().clamp(0, 999);
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// The other side's four along the top (tap one to focus it), their swaps,
/// the clock on its glass, and the way out.
class _TopBand extends StatelessWidget {
  const _TopBand({
    required this.battle,
    required this.rivalName,
    required this.padTop,
    required this.onLeave,
    required this.onFocus,
  });

  final CosmicBattle battle;
  final String rivalName;
  final double padTop;
  final VoidCallback onLeave;
  final void Function(int creature) onFocus;

  @override
  Widget build(BuildContext context) {
    final side = battle.sides[1];
    final left = max(0.0, kBattleTimeLimit - battle.clock);
    final focus = battle.sides[0].focus;
    return Container(
      padding: EdgeInsets.fromLTRB(12, padTop + 8, 12, 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bg, _bg.withValues(alpha: 0.85), _bg.withValues(alpha: 0)],
          stops: const [0, 0.7, 1],
        ),
      ),
      child: SizedBox(
        height: _kTopBand - 14,
        child: Row(
          children: [
            BracketIconButton(
              icon: AppIcons.arrow_back,
              onTap: onLeave,
              palette: BracketPalette.dark,
              size: 34,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          rivalName,
                          overflow: TextOverflow.ellipsis,
                          style: bracketText(
                            context,
                            9.5,
                            kBattleSilver,
                            weight: FontWeight.w800,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ),
                      _SwapPips(left: side.swapsLeft, color: kBattleSilver),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      for (var i = 0; i < side.creatures.length; i++)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onFocus(i),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: SizedBox(
                              width: 32,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _Case(
                                    creature: side.creatures[i],
                                    width: 32,
                                    height: 30,
                                    strength: 0.7,
                                    lit: focus == i ? kBattleBrass : null,
                                  ),
                                  const SizedBox(height: 2),
                                  _Tube(
                                    share: side.creatures[i].healthShare,
                                    color: focus == i
                                        ? kBattleBrass
                                        : kBattleSilver,
                                    height: 3,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // In overtime the clock's glass lights, and says so.
            HudGlass(
              accent: left < 10
                  ? HudInk.danger
                  : battle.inOvertime
                  ? HudInk.amber
                  : HudInk.line,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _clock(left),
                    style: hudMono(
                      15,
                      left < 10
                          ? HudInk.danger
                          : battle.inOvertime
                          ? HudInk.amber
                          : _ink,
                    ),
                  ),
                  if (battle.inOvertime && !battle.over) ...[
                    const SizedBox(height: 2),
                    Text('OVERTIME', style: hudMono(7, HudInk.amber)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Your two on the field, your bench and your swaps.
class _Hand extends StatelessWidget {
  const _Hand({
    required this.battle,
    required this.swapIn,
    required this.padBottom,
    required this.onField,
    required this.onBench,
  });

  final CosmicBattle battle;
  final int? swapIn;
  final double padBottom;
  final void Function(int spot) onField;
  final void Function(int creature) onBench;

  @override
  Widget build(BuildContext context) {
    final side = battle.sides[0];
    final bench = [
      for (var i = 0; i < side.creatures.length; i++)
        if (!side.creatures[i].onField) i,
    ];
    return Container(
      padding: EdgeInsets.fromLTRB(12, 14, 12, padBottom + 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [_bg, _bg.withValues(alpha: 0.92), _bg.withValues(alpha: 0)],
          stops: const [0, 0.75, 1],
        ),
      ),
      child: SizedBox(
        height: _kBottomBand - 24,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  for (var spot = 0; spot < kBattleFieldSpots; spot++) ...[
                    if (spot > 0) const SizedBox(width: 10),
                    Expanded(
                      // A new one in the place (a fall, a swap, the bench
                      // filling it): the card crosses over, not snaps.
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        layoutBuilder: (current, previous) => Stack(
                          fit: StackFit.expand,
                          children: [...previous, ?current],
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(side.spots[spot] ?? -1),
                          child: _FieldCard(
                            side: side,
                            spot: spot,
                            swapping: swapIn != null,
                            theirFocus: battle.sides[1].focus,
                            now: battle.clock,
                            onTap: () => onField(spot),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  Text(
                    'BENCH',
                    style: bracketText(
                      context,
                      9.5,
                      _muted,
                      weight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(width: 10),
                  for (final i in bench)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onBench(i),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _Case(
                              creature: side.creatures[i],
                              width: 46,
                              height: 42,
                              strength: 0.8,
                              lit: swapIn == i ? kBattleBrass : null,
                            ),
                            const SizedBox(height: 3),
                            SizedBox(
                              width: 46,
                              child: _Tube(
                                share: side.creatures[i].healthShare,
                                color: kBattleBrass,
                                height: 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const Spacer(),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        swapIn != null ? 'TAP ONE TO SWAP OUT' : 'SWAPS',
                        style: bracketText(
                          context,
                          9,
                          swapIn != null ? kBattleBrass : _muted,
                          weight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 5),
                      _SwapPips(left: side.swapsLeft, color: kBattleBrass),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of your field places: who is there in its lit case, its health and
/// its special's charge in glass tubes (the special fires on its own), and
/// what it is doing. Empty, the bench fills it in a moment.
class _FieldCard extends StatelessWidget {
  const _FieldCard({
    required this.side,
    required this.spot,
    required this.swapping,
    required this.theirFocus,
    required this.now,
    required this.onTap,
  });

  final BattleSide side;
  final int spot;
  final bool swapping;

  /// The creature (by index) the other side is going for.
  final int? theirFocus;

  /// The battle clock.
  final double now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final creature = side.at(spot);
    final comp = creature?.body;
    if (creature == null || comp == null) {
      final coming = side.bench.isNotEmpty;
      return Container(
        color: _bg1,
        alignment: Alignment.center,
        child: Text(
          coming ? 'CALLING ONE IN' : 'EMPTY',
          style: bracketText(
            context,
            10,
            coming ? kBattleBrass : _muted,
            weight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
      );
    }
    final m = creature.member;
    final arriving = comp.life < kBattleArrival;
    final hasSpecial = battleHasSpecial(m);
    final wait = comp.specialCooldown;
    final full = max(0.1, comp.effectiveSpecialCooldown);
    final charge = hasSpecial ? (1 - wait / full).clamp(0.0, 1.0) : 0.0;
    final index = side.creatures.indexOf(creature);
    final ready = hasSpecial && !arriving && wait <= 0;
    // Its special just went off: the card lights for a moment.
    final cast =
        creature.lastSpecialAt >= 0 && now - creature.lastSpecialAt < 0.9;
    final targeted = theirFocus == index;
    final String status;
    final Color statusColor;
    if (swapping) {
      status = 'SWAP OUT';
      statusColor = kBattleBrass;
    } else if (arriving) {
      status = 'ARRIVING';
      statusColor = _muted;
    } else if (!hasSpecial) {
      status = 'SPECIAL ALWAYS ON';
      statusColor = _muted;
    } else if (ready) {
      status = 'SPECIAL READY';
      statusColor = kBattleBrass;
    } else {
      status = 'SPECIAL ${wait.toStringAsFixed(1)} s';
      statusColor = _muted;
    }
    final element = elementColor(m.element);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: swapping || cast
              ? kBattleBrass.withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.06),
        ),
        child: Container(
          color: _bg1,
          padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
          child: Row(
            children: [
              _Case(creature: creature, width: 62, height: 72),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            m.displayName.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: bracketText(
                              context,
                              10.5,
                              _ink,
                              weight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        if (targeted)
                          Text(
                            'TARGETED',
                            style: bracketText(
                              context,
                              8,
                              kBattleSilver,
                              weight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    _Tube(
                      share: comp.currentHp / comp.maxHp,
                      color: kBattleBrass,
                      height: 7,
                    ),
                    const SizedBox(height: 5),
                    _Tube(
                      share: hasSpecial ? charge : 1,
                      color: hasSpecial ? element : _muted,
                      height: 5,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: bracketText(
                        context,
                        9,
                        statusColor,
                        weight: FontWeight.w800,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [word] in [style] read into grains, for a title that gathers out of
/// them.
Future<SpecimenGrains?> readWordGrains(String word, TextStyle style) async {
  const ratio = 2.0;
  final tp = TextPainter(
    text: TextSpan(text: word, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final w = (tp.width * ratio).ceil() + 8;
  final h = (tp.height * ratio).ceil() + 8;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec)
    ..translate(4, 4)
    ..scale(ratio);
  tp.paint(c, Offset.zero);
  final image = await rec.endRecording().toImage(w, h);
  try {
    final data = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    if (data == null) return null;
    return SpecimenGrains.fromRgba(
      Uint8List.view(data.buffer),
      w,
      h,
      pixelRatio: ratio,
      maxGrains: 900,
      tones: 4,
    );
  } finally {
    image.dispose();
  }
}

double _span(double t, double a, double b) =>
    Curves.easeOutCubic.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

/// How it ended, coming up in turn over [t] 0..1: the card rises, the word
/// gathers out of grains, then both sides' four as they finished (yours,
/// then theirs), then again or back to the hub. No line under the word
/// (user 2026-10-20: the subtext read as cheesy). DETAILS puts who did what
/// in the fours' place: plain numbers, nothing said about them.
class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.battle,
    required this.t,
    required this.word,
    required this.onAgain,
    required this.onLeave,
    required this.leaveLabel,
    required this.details,
    required this.onDetails,
  });

  final CosmicBattle battle;
  final double t;
  final GrainAssembly? word;
  final VoidCallback onAgain;
  final VoidCallback onLeave;
  final String leaveLabel;
  final bool details;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final r = battle.result!;
    final (text, color) = switch (r.winner) {
      0 => ('VICTORY', kBattleBrass),
      1 => ('DEFEAT', kBattleSilver),
      _ => ('DRAW', _ink),
    };
    final rise = _span(t, 0, 0.3);
    final gather = ((t - 0.08) / 0.54).clamp(0.0, 1.0);
    Widget arriving(double k, Widget child) => Opacity(
      opacity: k,
      child: Transform.translate(offset: Offset(0, (1 - k) * 10), child: child),
    );
    Widget team(int i, String label, Color tone) => Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: bracketText(
              context,
              9,
              tone,
              weight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ),
        for (final c in battle.sides[i].creatures)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Case(creature: c, width: 44, height: 44, strength: 0.8),
                const SizedBox(height: 3),
                SizedBox(
                  width: 44,
                  child: _Tube(share: c.healthShare, color: tone, height: 3),
                ),
              ],
            ),
          ),
      ],
    );
    final title = bracketText(
      context,
      26,
      color,
      weight: FontWeight.w800,
      letterSpacing: 5,
    );
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.55 * rise),
      child: Center(
        child: Opacity(
          opacity: rise,
          child: Transform.translate(
            offset: Offset(0, (1 - rise) * 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: CustomPaint(
                painter: BracketFramePainter(
                  color: color.withValues(alpha: 0.85),
                ),
                child: Container(
                  color: _bg1,
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The word: grains gathering into it, then the word.
                      CustomPaint(
                        foregroundPainter: _WordGatherPainter(word, gather),
                        child: Opacity(
                          opacity: word == null
                              ? _span(t, 0.1, 0.5)
                              : GrainAssembly.spriteOpacityGathering(gather),
                          child: Text(text, style: title),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // The two fours as they finished, or (DETAILS) what
                      // each of them did: the card grows or shrinks to it.
                      Flexible(
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            layoutBuilder: (current, previous) => Stack(
                              alignment: Alignment.topCenter,
                              children: [...previous, ?current],
                            ),
                            child: details
                                ? SingleChildScrollView(
                                    key: const ValueKey('battle.details'),
                                    child: _Breakdown(battle: battle),
                                  )
                                : Column(
                                    key: const ValueKey('battle.fours'),
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      arriving(
                                        _span(t, 0.55, 0.78),
                                        team(0, 'YOU', kBattleBrass),
                                      ),
                                      const SizedBox(height: 8),
                                      arriving(
                                        _span(t, 0.65, 0.88),
                                        team(1, 'THEM', kBattleSilver),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      IgnorePointer(
                        ignoring: t < 0.85,
                        child: arriving(
                          _span(t, 0.72, 0.92),
                          GestureDetector(
                            key: const ValueKey('battle.detailsToggle'),
                            behavior: HitTestBehavior.opaque,
                            onTap: onDetails,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Text(
                                details ? 'HIDE DETAILS' : 'DETAILS',
                                style: bracketText(
                                  context,
                                  10,
                                  kBattleBrass,
                                  weight: FontWeight.w800,
                                  letterSpacing: 1.8,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      IgnorePointer(
                        ignoring: t < 0.85,
                        child: arriving(
                          _span(t, 0.8, 1.0),
                          Column(
                            children: [
                              BracketButton(
                                label: 'AGAIN',
                                onTap: onAgain,
                                palette: BracketPalette.dark,
                                accent: kBattleBrass,
                              ),
                              const SizedBox(height: 8),
                              BracketButton(
                                label: leaveLabel,
                                onTap: onLeave,
                                palette: BracketPalette.dark,
                                accent: kBattleBrass,
                                primary: false,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Who did what, both sides: each Alchemon in its case with the health it
/// finished on, then the health it took off the other side, the health it
/// lost, and the health it gave back to its own (in the creatures' own
/// points). Each side's most damage is lit in its colour; one kept on the
/// bench all fight says so.
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.battle});

  final CosmicBattle battle;

  static const double _column = 50;

  @override
  Widget build(BuildContext context) {
    Widget figure(String text, Color color, {double size = 10.5}) => SizedBox(
      width: _column,
      child: Text(
        text,
        textAlign: TextAlign.right,
        maxLines: 1,
        style: bracketText(
          context,
          size,
          color,
          weight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
    String amount(double v) => v < 0.5 ? '—' : v.round().toString();

    Widget head(String label, Color tone) => Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: bracketText(
              context,
              9,
              tone,
              weight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ),
        for (final word in const ['DEALT', 'TAKEN', 'HEALED'])
          figure(word, _muted, size: 8),
      ],
    );

    Widget line(BattleCreature c, Color tone, {required bool best}) {
      final m = c.member;
      return SizedBox(
        height: 30,
        child: Row(
          children: [
            _Case(creature: c, width: 28, height: 26, strength: 0.8),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.displayName.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: bracketText(
                      context,
                      9,
                      c.wasOnField ? _ink : _muted,
                      weight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FractionallySizedBox(
                    widthFactor: 0.7,
                    child: _Tube(share: c.healthShare, color: tone, height: 3),
                  ),
                ],
              ),
            ),
            if (!c.wasOnField)
              SizedBox(
                width: _column * 3,
                child: Text(
                  'BENCHED',
                  textAlign: TextAlign.right,
                  style: bracketText(
                    context,
                    9,
                    _muted,
                    weight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              )
            else ...[
              figure(amount(c.damageDealt), best ? tone : _ink),
              figure(amount(c.damageTaken), _ink),
              figure(amount(c.healing), _ink),
            ],
          ],
        ),
      );
    }

    final rows = <Widget>[];
    for (final (i, label, tone) in [
      (0, 'YOU', kBattleBrass),
      (1, 'THEM', kBattleSilver),
    ]) {
      final side = battle.sides[i];
      BattleCreature? best;
      for (final c in side.creatures) {
        if (c.damageDealt >= 0.5 &&
            (best == null || c.damageDealt > best.damageDealt)) {
          best = c;
        }
      }
      if (i > 0) rows.add(const SizedBox(height: 12));
      rows.add(head(label, tone));
      rows.add(const SizedBox(height: 4));
      for (final c in side.creatures) {
        rows.add(line(c, tone, best: identical(c, best)));
      }
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

/// The result's word gathering out of its grains, over the word.
class _WordGatherPainter extends CustomPainter {
  _WordGatherPainter(this.word, this.u);

  final GrainAssembly? word;
  final double u;

  @override
  void paint(Canvas canvas, Size size) {
    final w = word;
    if (w == null || u <= 0) return;
    w.paintGather(canvas, size.center(Offset.zero), u);
  }

  @override
  bool shouldRepaint(_WordGatherPainter old) =>
      old.u != u || !identical(old.word, word);
}
