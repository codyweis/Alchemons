// lib/games/stadium/island_stage.dart
//
// The island as it is watched (the Ruby Cup's bouts, island_rules.dart):
// the bout stepped under a real-time clock and the three eased between
// steps, and the theatre round it — the three set down on the island one
// after another, the count, a charge gathering and breaking, a blow
// throwing sand, the edge crumbling away into the dark, the fallen coming
// apart into their own grains, the last one standing in the light.
//
// IslandPainter draws it, in grains on black like everything else: a sand
// island floating among the stars, its rock hanging under it, the crowd's
// lights in a ring far below.

import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/obsidian_kit.dart';
import 'package:alchemons/games/stadium/bout_stage.dart';
import 'package:alchemons/games/stadium/gem_cups.dart';
import 'package:alchemons/games/stadium/island_rules.dart';
import 'package:alchemons/games/stadium/race_bodies.dart';
import 'package:alchemons/games/stadium/race_painter.dart';
import 'package:alchemons/games/stadium/race_rules.dart';
import 'package:alchemons/widgets/fx/alchemy_effects/alchemy_effect_paint.dart'
    show trialsBeamImage;
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum IslandStagePhase { intro, countdown, fight, done }

/// The island for a Ruby Cup bout.
IslandBout islandBoutOf(GemBout bout) => IslandBout(
  IslandKind.values.asNameMap()[bout.place] ?? IslandKind.sand,
  bout.level,
);

/// A blow landing, or one going over the edge: where and when, and whose.
class IslandBurst {
  IslandBurst(this.at, this.clock, this.lane, {this.fall = false});
  final Offset at;
  final double clock;
  final int lane;
  final bool fall;
}

class IslandStage extends ChangeNotifier implements BoutStage {
  IslandStage({
    required this.bout,
    required this.fighters,
    required this.bodies,
    required this.player,
  }) : sim = IslandSim(bout, fighters) {
    final n = fighters.length;
    px = [for (final s in sim.states) s.x];
    py = [for (final s in sim.states) s.y];
    x = [...px];
    y = [...py];
    _seenHits = List.filled(n, 0);
    _seenCharges = List.filled(n, 0);
    _seenFall = List.filled(n, false);
    fellAtClock = List.filled(n, null);
    chargeAtClock = List.filled(n, null);
  }

  final IslandBout bout;
  final List<Racer> fighters;
  final List<RaceBody> bodies;

  /// The player's place in [fighters].
  @override
  final int player;
  final IslandSim sim;

  /// The three set down, then the count.
  static const double introSeconds = 2.4, countdownSeconds = 3.0;

  /// Held on the last one standing before the results.
  static const double endHold = 2.2;

  IslandStagePhase phase = IslandStagePhase.intro;
  @override
  double clock = 0;
  double fightClock = 0, doneClock = 0;
  double _acc = 0;
  double? _overAt;
  int _countSaid = 4;

  /// When the last but one went over (stage clock); null till then.
  double? get overAt => _overAt;

  /// Each one's place on the island (island units), eased between steps,
  /// and where it was the step before.
  late final List<double> x, y, px, py;
  late final List<int> _seenHits, _seenCharges;
  late final List<bool> _seenFall;

  /// When each went over the edge, and last began a charge (stage clock).
  late final List<double?> fellAtClock, chargeAtClock;

  final List<IslandBurst> bursts = [];
  @override
  final List<BoutSound> sounds = [];

  /// How the crowd is taking it, 0..1, rising on every blow.
  double cheer = 0;

  bool get fighting => phase == IslandStagePhase.fight;

  double get countdownLeft => phase == IslandStagePhase.countdown
      ? max(0, introSeconds + countdownSeconds - clock)
      : 0;

  bool get canCharge => fighting && sim.canCharge(player);
  int get chargesLeft => sim.states[player].charges;

  /// The island's radius as watched, eased between steps.
  double get radius => sim.radiusAt(sim.tick) + 0.0;

  @override
  List<int> get standings => sim.standings;

  /// The player taps a charge.
  bool tapCharge() {
    if (!canCharge) return false;
    sim.tap(player);
    sounds.add(BoutSound.act);
    return true;
  }

  // ── what the bout screen reads ──

  @override
  bool get done => phase == IslandStagePhase.done;
  @override
  bool get hasAction => true;
  @override
  String? get caption => null;
  @override
  bool get canAct => canCharge;
  @override
  int get actsLeft => chargesLeft;
  @override
  bool act() => tapCharge();
  @override
  double? get actPour {
    final me = sim.states[player];
    if (me.phase != FighterPhase.windup || !me.boosted) return null;
    return (sim.tick - me.phaseFrom) / IslandSim.windupTicks;
  }

  @override
  String get actLabel => 'CHARGE';
  @override
  String? tagOf(int i) => fellAtClock[i] != null ? 'OUT' : null;
  @override
  bool dimmed(int i) => fellAtClock[i] != null;
  @override
  String headline(int place) =>
      place == 1 ? 'LAST ONE STANDING' : 'OVER THE EDGE';
  @override
  String? get note => null;

  /// How quickly the player won, in seconds of fighting; none if it lost.
  @override
  double? get mark => sim.over && sim.standings.first == player
      ? sim.tick / kIslandTickRate
      : null;
  @override
  String? resultOf(int i) => null;
  @override
  late final CustomPainter painter = IslandPainter(this);

  @override
  void advance(double dt) {
    dt = min(dt, 0.1);
    clock += dt;
    switch (phase) {
      case IslandStagePhase.intro:
        if (clock >= introSeconds) phase = IslandStagePhase.countdown;
      case IslandStagePhase.countdown:
        final n = countdownLeft.ceil();
        if (n < _countSaid && n > 0) {
          _countSaid = n;
          sounds.add(BoutSound.countTick);
        }
        if (clock >= introSeconds + countdownSeconds) {
          phase = IslandStagePhase.fight;
          sounds.add(BoutSound.gun);
        }
      case IslandStagePhase.fight:
        fightClock += dt;
        _run(dt);
        if (sim.over) {
          _overAt ??= clock;
          if (clock - _overAt! >= endHold) {
            phase = IslandStagePhase.done;
            sounds.add(BoutSound.win);
          }
        }
      case IslandStagePhase.done:
        doneClock += dt;
    }
    cheer = max(0, cheer - dt * 0.6);
    bursts.removeWhere((b) => clock - b.clock > 1.6);
    notifyListeners();
  }

  void _run(double dt) {
    const step = 1 / kIslandTickRate;
    if (!sim.over) {
      _acc += dt;
      while (_acc >= step && !sim.over) {
        for (var i = 0; i < x.length; i++) {
          px[i] = sim.states[i].x;
          py[i] = sim.states[i].y;
        }
        sim.step();
        _acc -= step;
        _events();
      }
    }
    final a = sim.over ? 1.0 : _acc / step;
    for (var i = 0; i < x.length; i++) {
      final s = sim.states[i];
      x[i] = px[i] + (s.x - px[i]) * a;
      y[i] = py[i] + (s.y - py[i]) * a;
    }
  }

  void _events() {
    for (var i = 0; i < x.length; i++) {
      final s = sim.states[i];
      if (s.chargesAt.length != _seenCharges[i]) {
        _seenCharges[i] = s.chargesAt.length;
        chargeAtClock[i] = clock;
      }
      while (_seenHits[i] < s.hitsAt.length) {
        _seenHits[i]++;
        // Where it landed: between it and the one it hit.
        final t = s.target;
        final o = t >= 0 ? sim.states[t] : s;
        bursts.add(
          IslandBurst(
            Offset((s.x + o.x) / 2, (s.y + o.y) / 2),
            clock,
            t >= 0 ? t : i,
          ),
        );
        cheer = min(1, cheer + 0.5);
        sounds.add(BoutSound.hit);
      }
      if (s.fellAt != null && !_seenFall[i]) {
        _seenFall[i] = true;
        fellAtClock[i] = clock;
        bursts.add(IslandBurst(Offset(s.x, s.y), clock, i, fall: true));
        cheer = 1;
        sounds.add(BoutSound.out);
      }
    }
  }
}

// ── the painter ─────────────────────────────────────────────────────────────

/// How each island looks: its sand from dark to lit, its lit rim, the rock
/// under it, and the colour of the sky behind.
class _IslandLook {
  const _IslandLook(this.sand, this.rim, this.rock, this.sky, {this.veins});

  final List<Color> sand;
  final Color rim;
  final List<Color> rock;
  final Color sky;

  /// Glowing cracks in the rock (the ember island).
  final Color? veins;
}

const Map<IslandKind, _IslandLook> _looks = {
  IslandKind.sand: _IslandLook(
    [
      Color(0xFF241F18),
      Color(0xFF433929),
      Color(0xFF6E5D40),
      Color(0xFFB39A6A),
    ],
    Color(0xFFE2C98F),
    [Color(0xFF16130F), Color(0xFF272219), Color(0xFF3B3326)],
    Color(0xFF4A3B6E),
  ),
  IslandKind.ice: _IslandLook(
    [
      Color(0xFF141C25),
      Color(0xFF2C4253),
      Color(0xFF5F86A0),
      Color(0xFFCBE4F2),
    ],
    Color(0xFFCFEFF8),
    [Color(0xFF0D141B), Color(0xFF1A2733), Color(0xFF2E4659)],
    Color(0xFF2E5A82),
  ),
  IslandKind.ember: _IslandLook(
    [
      Color(0xFF181010),
      Color(0xFF2C1C17),
      Color(0xFF4C2B1E),
      Color(0xFFA8552A),
    ],
    Color(0xFFF5A060),
    [Color(0xFF110A08), Color(0xFF21130E), Color(0xFF341D14)],
    Color(0xFF6E2A1E),
    veins: Color(0xFFFF8A3C),
  ),
};

double _smooth(double x) {
  final t = x.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

class IslandPainter extends CustomPainter {
  IslandPainter(this.stage) : super(repaint: stage) {
    _laySand();
  }

  final IslandStage stage;
  static final GrainBatch _b = GrainBatch(16);

  /// The island's sand: where each grain lies (radius, angle) and how lit
  /// it is; laid once.
  static Float32List? _sandRho, _sandTone;

  /// Each grain's way out from the middle, and the bite of the edge there
  /// (see [_edge]), worked out once.
  static Float32List? _sandCos, _sandSin, _sandBite;
  static const int _sandN = 6200;

  static void _laySand() {
    if (_sandRho != null) return;
    final rho = Float32List(_sandN), ang = Float32List(_sandN);
    final tone = Float32List(_sandN);
    for (var i = 0; i < _sandN; i++) {
      final u = hash01(i, 301), v = hash01(i, 302);
      rho[i] = kIslandRadius * 1.04 * sqrt(u);
      ang[i] = v * 2 * pi;
      // Lit from the upper left, a little rough, and in drifts: patches of
      // lighter and darker sand.
      final x = cos(ang[i]) * sqrt(u), y = sin(ang[i]) * sqrt(u);
      final drift = 0.5 + 0.5 * sin(x * 7.1 + y * 3.3) * sin(y * 5.7 - x * 2.1);
      tone[i] =
          (0.3 +
                  0.28 * -cos(ang[i] + 0.8) * sqrt(u) +
                  0.2 * drift +
                  0.25 * hash01(i, 303))
              .clamp(0.0, 1.0);
    }
    _sandRho = rho;
    _sandTone = tone;
    _sandCos = Float32List.fromList([for (final a in ang) cos(a)]);
    _sandSin = Float32List.fromList([for (final a in ang) sin(a)]);
    _sandBite = Float32List.fromList([for (final a in ang) _bite(a)]);
  }

  static double _bite(double a) =>
      2.2 * sin(a * 5 + 1.3) +
      1.4 * sin(a * 11 + 0.4) +
      0.9 * sin(a * 23 + 2.2);

  /// The island's edge isn't a circle: bitten in and out where it breaks.
  static double _edge(double a, double r) => r + _bite(a) * _biteScale(r);

  static double _biteScale(double r) => 0.6 + 0.4 * r / kIslandRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final s = stage;
    final look = _looks[s.bout.kind]!;
    final t = s.clock;
    final w = size.width, h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF060609),
    );
    _sky(canvas, size, look, t);

    // The island fills most of the width; the camera comes in a little as
    // it crumbles, so the fight stays big.
    final shrink = 1 - s.sim.radiusAt(s.sim.tick) / kIslandRadius;
    final zoom = 1 + 0.7 * shrink;
    final sx = w * 0.44 / kIslandRadius * zoom, sy = sx * 0.6;
    final cx = w / 2, cy = h * 0.42;
    Offset at(double ix, double iy) => Offset(cx + ix * sx, cy + iy * sy);

    _crowd(canvas, size, t);
    _debris(canvas, Offset(cx, cy), sx, look, t);
    final r = s.sim.radiusAt(s.sim.tick);
    _rock(canvas, at, r, sx, look, t);
    _top(canvas, at, r, sx, look, t);

    // The last one standing, in the light.
    if (s.sim.over) _winnerLight(canvas, at, sx, t, back: true);

    // The three, back to front.
    final order = [for (var i = 0; i < s.x.length; i++) i]
      ..sort((a, b) => s.y[a].compareTo(s.y[b]));
    for (final i in order) {
      _fighter(canvas, i, at, sx, t);
    }
    _bursts(canvas, at, sx, look);
    if (s.sim.over) _winnerLight(canvas, at, sx, t, back: false);
    paintGrainCount(
      canvas,
      raceNumeralGrains,
      s.countdownLeft,
      Offset(w / 2, h * 0.2),
      w / 475,
      s.clock,
    );
  }

  // ── the sky and what is below ──

  void _sky(Canvas c, Size size, _IslandLook look, double t) {
    final w = size.width, h = size.height;
    // A haze of the island's colour, low and uneven behind it.
    for (final (x, y, r, a) in [
      (0.32, 0.6, 0.75, 0.16),
      (0.72, 0.52, 0.6, 0.12),
      (0.55, 0.78, 0.9, 0.1),
    ]) {
      final o = Offset(w * x, h * y);
      c.drawCircle(
        o,
        w * r,
        Paint()
          ..shader = ui.Gradient.radial(
            o,
            w * r,
            [
              look.sky.withValues(alpha: a),
              look.sky.withValues(alpha: a * 0.35),
              look.sky.withValues(alpha: 0),
            ],
            const [0.0, 0.45, 1.0],
          ),
      );
    }
    final b = _b..clear();
    for (var i = 0; i < 260; i++) {
      final x = hash01(i, 401) * w;
      final y = hash01(i, 402) * h;
      final tw = 0.5 + 0.5 * sin(t * (0.6 + hash01(i, 403)) + i);
      b.add(tw > 0.85 ? 1 : 0, x, y);
    }
    b.draw(c, 0, 1.0, const Color(0xFFE6E2DA).withValues(alpha: 0.3));
    b.draw(c, 1, 1.6, const Color(0xFFF2EEE6).withValues(alpha: 0.75));
  }

  /// The crowd, far below: clusters of lights scattered across the bottom
  /// of the dark, nearer ones lower and larger, brightening and stirring as
  /// it cheers.
  void _crowd(Canvas c, Size size, double t) {
    final w = size.width, h = size.height;
    final cheer = stage.cheer;
    final b = _b..clear();
    for (var i = 0; i < 380; i++) {
      final cluster = (hash01(i, 411) * 30).floor();
      final depth = hash01(cluster, 412);
      final ccx = hash01(cluster, 413) * w * 1.1 - w * 0.05;
      final ccy = h * (0.84 + 0.13 * depth);
      final spread = (10 + 22 * depth) * w / 475;
      final x = ccx + (hash01(i, 414) - 0.5) * spread * 2;
      final y = ccy + (hash01(i, 415) - 0.5) * spread * 0.5;
      final bob = sin(t * (4 + 3 * hash01(i, 416)) + i) * cheer * 2;
      final lit = hash01(i, 417) < 0.12 + 0.3 * cheer;
      b.add(lit ? (depth > 0.5 ? 3 : 2) : (depth > 0.5 ? 1 : 0), x, y - bob);
    }
    b.draw(c, 0, 1.0, const Color(0xFFCDB07A).withValues(alpha: 0.16));
    b.draw(c, 1, 1.4, const Color(0xFFCDB07A).withValues(alpha: 0.22));
    final hot = const Color(0xFFE2C98F).withValues(alpha: 0.35 + 0.4 * cheer);
    b.draw(c, 2, 1.3, hot);
    b.draw(c, 3, 1.8, hot);
  }

  /// Bits of the island's rock adrift in the dark round it, slowly turning:
  /// dark masses lit at their edges.
  void _debris(Canvas c, Offset centre, double sx, _IslandLook look, double t) {
    final b = _b..clear();
    final dark = Paint()..color = look.rock[0];
    for (var d = 0; d < 6; d++) {
      final side = d.isEven ? -1.0 : 1.0;
      final o = centre.translate(
        side * kIslandRadius * sx * (0.95 + 0.25 * hash01(d, 491)),
        kIslandRadius * sx * (0.35 + 0.9 * hash01(d, 492)) +
            sin(t * 0.5 + d * 1.7) * 4,
      );
      final size = (3 + 6 * hash01(d, 493)) * sx;
      final spin = t * (0.2 + 0.2 * hash01(d, 494)) * side;
      final path = Path();
      for (var q = 0; q <= 10; q++) {
        final a = q / 10 * 2 * pi;
        final rr = size * (0.75 + 0.3 * sin(a * 3 + d + spin));
        final p = o + Offset(cos(a) * rr, sin(a) * rr * 0.8);
        q == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      c.drawPath(path, dark);
      for (var g = 0; g < 18; g++) {
        final a = hash01(g, 495 + d) * 2 * pi;
        final face = cos(a + 2.3);
        if (face < 0) continue;
        final rr = size * (0.75 + 0.3 * sin(a * 3 + d + spin)) * 0.95;
        b.add(face > 0.6 ? 1 : 0, o.dx + cos(a) * rr, o.dy + sin(a) * rr * 0.8);
      }
    }
    b.draw(c, 0, 1.3, look.rock[2]);
    b.draw(c, 1, 1.6, Color.lerp(look.rock[2], look.sand[3], 0.4)!);
  }

  // ── the island ──

  /// The rock hanging under the island: a dark mass that runs down into a
  /// main point and two lesser ones, told by its strata in grains — lit
  /// down its left flank, thinning to the points — and sand trickling off
  /// its lip. Glowing cracks on the ember island.
  void _rock(
    Canvas c,
    Offset Function(double, double) at,
    double r,
    double sx,
    _IslandLook look,
    double t,
  ) {
    final top = at(0, 0);
    final rx = r * sx;
    final ry = r * sx * 0.6;
    final lip = 7 * sx * (0.5 + 0.5 * r / kIslandRadius);
    final depth = r * sx * 1.0;
    // How far down the rock reaches at x (a share of rx, -1..1): three
    // hanging points, the middle the longest.
    double reach(double u) {
      final main = exp(-pow((u - 0.1) / 0.42, 2)) * 1.0;
      final left = exp(-pow((u + 0.55) / 0.26, 2)) * 0.5;
      final right = exp(-pow((u - 0.66) / 0.22, 2)) * 0.38;
      final base = sqrt(max(0.0, 1 - u * u)) * 0.3;
      return max(base, max(main, max(left, right))) *
          (0.94 + 0.08 * sin(u * 23 + 1));
    }

    final path = Path();
    const n = 48;
    for (var q = 0; q <= n; q++) {
      final u = -1 + 2 * q / n;
      final edge = _edge(pi - acos(u.clamp(-1.0, 1.0)), r) / r;
      final x = top.dx + u * rx * edge;
      final rim = top.dy + sqrt(max(0.0, 1 - u * u)) * ry;
      final y = rim + lip + reach(u) * depth;
      q == 0 ? path.moveTo(x, rim) : null;
      path.lineTo(x, y);
    }
    path.lineTo(top.dx + rx, top.dy);
    for (var q = n; q >= 0; q--) {
      final u = -1 + 2 * q / n;
      path.lineTo(top.dx + u * rx, top.dy + sqrt(max(0.0, 1 - u * u)) * ry);
    }
    path.close();
    c.drawPath(
      path,
      Paint()..color = Color.lerp(look.rock[0], Colors.black, 0.35)!,
    );

    // Strata: rows of grains across the rock, lit on the left, sparser and
    // dimmer the deeper they go.
    final b = _b..clear();
    const rows = 30;
    for (var row = 0; row < rows; row++) {
      final d = row / rows;
      final per = (80 * (1 - d * 0.6)).round();
      for (var g = 0; g < per; g++) {
        final u = -1 + 2 * hash01(row * 97 + g, 305);
        final down = reach(u);
        if (d > down) continue;
        final rim = top.dy + sqrt(max(0.0, 1 - u * u)) * ry;
        final y =
            rim +
            lip +
            d * depth +
            (hash01(row * 97 + g, 306) - 0.5) * depth / rows * 0.8 +
            sin(u * 9 + row) * 1.2;
        final x = top.dx + u * rx * (1 - 0.04 * d);
        // Thin out toward each point's end.
        if (hash01(row * 97 + g, 307) > 1.15 - d / max(down, 0.05)) continue;
        final lit = u < -0.45 ? 2 : (u < 0.15 ? 1 : 0);
        b.add(d > 0.6 ? min(lit, 1) : lit, x, y);
        if (look.veins != null && hash01(row * 97 + g, 308) < 0.07) {
          if (sin(t * 1.6 + row * 0.7 + g) > 0.2) b.add(3, x, y);
        }
      }
    }
    // The lip: the island's edge seen side on, a band of packed sand.
    for (var g = 0; g < 260; g++) {
      final u = -1 + 2 * hash01(g, 309);
      final rim = top.dy + sqrt(max(0.0, 1 - u * u)) * ry;
      final y = rim + hash01(g, 310) * lip;
      b.add(u < -0.3 ? 5 : 4, top.dx + u * rx, y);
    }
    // Sand trickling off it here and there.
    for (var f = 0; f < 7; f++) {
      final u = -0.85 + 1.7 * hash01(f, 311);
      final x0 = top.dx + u * rx;
      final y0 = top.dy + sqrt(max(0.0, 1 - u * u)) * ry + lip;
      for (var g = 0; g < 14; g++) {
        final life = (t * (0.5 + 0.3 * hash01(f, 312)) + g / 14) % 1.0;
        b.add(6, x0 + sin(life * 3 + g) * 1.5, y0 + life * life * depth * 0.9);
      }
    }
    final gs = 1.5 * sx / 2.2;
    b.draw(c, 0, gs, Color.lerp(look.rock[2], look.sand[0], 0.3)!);
    b.draw(c, 1, gs, Color.lerp(look.rock[2], look.sand[1], 0.6)!);
    b.draw(c, 2, gs + 0.2, Color.lerp(look.rock[2], look.sand[2], 0.75)!);
    b.draw(c, 4, gs, look.sand[1].withValues(alpha: 0.9));
    b.draw(c, 5, gs + 0.2, look.sand[2].withValues(alpha: 0.9));
    b.draw(c, 6, gs * 0.8, look.sand[2].withValues(alpha: 0.55));
    if (look.veins != null) {
      b.draw(c, 3, gs + 0.6, look.veins!.withValues(alpha: 0.85));
    }
  }

  /// The island's top: a dark ground told by its sand, in drifts, lit from
  /// the upper left; its edge bitten and catching a little more light at
  /// the back; and what has just broken off falling away into the dark.
  void _top(
    Canvas c,
    Offset Function(double, double) at,
    double r,
    double sx,
    _IslandLook look,
    double t,
  ) {
    final s = stage;
    final ground = Path();
    const n = 72;
    for (var q = 0; q <= n; q++) {
      final a = q / n * 2 * pi;
      final e = _edge(a, r);
      final p = at(cos(a) * e, sin(a) * e);
      q == 0 ? ground.moveTo(p.dx, p.dy) : ground.lineTo(p.dx, p.dy);
    }
    ground.close();
    // The ground under the sand: dark, a little lit toward the upper left.
    final mid = at(0, 0);
    c.drawPath(
      ground,
      Paint()
        ..shader = ui.Gradient.radial(
          mid.translate(-r * sx * 0.35, -r * sx * 0.2),
          r * sx * 1.35,
          [
            switch (s.bout.kind) {
              // Ice is glassy: its ground holds more of the light.
              IslandKind.ice => Color.lerp(look.sand[1], look.sand[2], 0.3)!,
              IslandKind.ember => Color.lerp(look.sand[1], look.sand[2], 0.15)!,
              IslandKind.sand => Color.lerp(look.sand[0], look.sand[1], 0.45)!,
            },
            Color.lerp(look.sand[0], look.sand[1], 0.3)!,
            Color.lerp(look.rock[0], Colors.black, 0.2)!,
          ],
          const [0.0, 0.55, 1.0],
        ),
    );

    final b = _b..clear();
    final rho = _sandRho!, tone = _sandTone!;
    final cs = _sandCos!, sn = _sandSin!, bite = _sandBite!;
    final crumble = s.bout.crumble;
    final since = s.fightClock;
    final scale = _biteScale(r);
    final o = at(0, 0);
    final syy = sx * 0.6;
    for (var i = 0; i < _sandN; i++) {
      final p = rho[i];
      final e = r + bite[i] * scale;
      final qx = o.dx + cs[i] * p * sx, qy = o.dy + sn[i] * p * syy;
      if (p <= e) {
        // Near the edge at the back, the sand catches the light.
        final rimLit = p > e - 5 && sn[i] < -0.2 ? 0.25 : 0.0;
        final lv = ((tone[i] + rimLit).clamp(0.0, 0.999) * 4).floor();
        b.add(lv, qx, qy);
        continue;
      }
      // Broken off: when the edge passed it, and how far it has fallen.
      final went = 5 + (kIslandRadius * 1.04 - p) / crumble;
      final age = since - went;
      if (age < 0 || age > 1.6) continue;
      final fall = 0.5 * 360 * age * age;
      b.add(age < 0.5 ? 5 : 6, qx + cs[i] * age * 10, qy + fall);
      if (age > 0.08) {
        final e2 = age - 0.06;
        b.add(7, qx + cs[i] * e2 * 10, qy + 0.5 * 360 * e2 * e2);
      }
    }
    final g = 1.45 * sx / 2.2;
    final ice = s.bout.kind == IslandKind.ice;
    // Ice shows fewer, softer grains (its glints come and go below).
    final shades = [
      look.sand[1],
      Color.lerp(look.sand[1], look.sand[2], 0.6)!,
      Color.lerp(look.sand[2], look.sand[3], ice ? 0.15 : 0.45)!,
      ice ? Color.lerp(look.sand[2], look.sand[3], 0.5)! : look.sand[3],
    ];
    for (var k = 0; k < 4; k++) {
      b.draw(c, k, g + 0.2, shades[k].withValues(alpha: ice ? 0.55 : 0.85));
    }
    b.draw(c, 5, g + 0.3, look.sand[3].withValues(alpha: 0.85));
    b.draw(c, 6, g, look.sand[2].withValues(alpha: 0.5));
    b.draw(c, 7, g, look.sand[2].withValues(alpha: 0.25));
    // Embers rising off the hot island; frost glinting on the ice.
    if (s.bout.kind != IslandKind.sand) {
      final e = _b..clear();
      for (var i = 0; i < 46; i++) {
        final a = hash01(i, 421) * 2 * pi;
        final p = sqrt(hash01(i, 422)) * r;
        final q = at(cos(a) * p, sin(a) * p);
        if (s.bout.kind == IslandKind.ember) {
          final life =
              (t * (0.3 + 0.2 * hash01(i, 423)) + hash01(i, 424)) % 1.0;
          e.add(
            life < 0.5 ? 0 : 2,
            q.dx + sin(life * 6 + i) * 3,
            q.dy - life * 40 * sx / 2.2,
          );
        } else if (sin(t * 1.7 + i * 2.3) > 0.9) {
          e.add(1, q.dx, q.dy);
        }
      }
      e.draw(c, 0, 1.6, const Color(0xFFFFA060).withValues(alpha: 0.8));
      e.draw(c, 2, 1.3, const Color(0xFFE0603A).withValues(alpha: 0.45));
      e.draw(c, 1, 2.2, const Color(0xFFF2FCFF));
    }
  }

  // ── the three ──

  /// A soft dark under one's feet.
  void _shadow(Canvas c, Offset feet, double k, {double alpha = 0.5}) {
    c.save();
    c.translate(feet.dx, feet.dy + 1);
    c.scale(1, 0.3);
    final r = 12 * k;
    c.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          r,
          [
            Colors.black.withValues(alpha: alpha),
            Colors.black.withValues(alpha: alpha * 0.5),
            Colors.black.withValues(alpha: 0),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );
    c.restore();
  }

  void _fighter(
    Canvas c,
    int i,
    Offset Function(double, double) at,
    double sx,
    double t,
  ) {
    final s = stage;
    final st = s.sim.states[i];
    final body = s.bodies[i];
    final col = elementColor(body.member.element);
    final hot = Color.lerp(col, Colors.white, 0.5)!;
    final k = sx * 0.95;
    final look = _looks[s.bout.kind]!;
    var feet = at(s.x[i], s.y[i]);

    // Set down one after another during the intro, dropping in from above.
    final arrive = (s.clock - 0.35 - i * 0.55) / 0.6;
    if (s.phase == IslandStagePhase.intro && arrive < 1) {
      if (arrive <= 0) return;
      final e = 1 - pow(1 - arrive, 3).toDouble();
      feet = feet.translate(0, -(1 - e) * 220);
    }

    // Gone over: it drops away out of the light, its grains streaming up
    // off it and going out.
    final fell = s.fellAtClock[i];
    if (fell != null) {
      _falling(c, i, feet, col, s.clock - fell, k, t);
      return;
    }

    // Its shadow, and the player's own light at its feet.
    if (i == s.player) {
      c.save();
      c.translate(feet.dx, feet.dy + 1);
      c.scale(1, 0.32);
      final r = 22 * k;
      c.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..shader = ui.Gradient.radial(Offset.zero, r, [
            const Color(0xFFE2C98F).withValues(alpha: 0.32),
            const Color(0xFFE2C98F).withValues(alpha: 0),
          ]),
      );
      c.restore();
    }
    _shadow(c, feet, k);

    final b = _b..clear();
    final dir = st.target >= 0
        ? Offset(s.x[st.target] - s.x[i], s.y[st.target] - s.y[i])
        : Offset(st.dx, st.dy);
    final len = dir.distance;
    final fx = len > 0 ? dir.dx / len : 1.0, fy = len > 0 ? dir.dy / len : 0.0;
    if (st.phase == FighterPhase.windup) {
      // Digging in: sand kicked up behind it, and — for a charge of its
      // stamina — its own grains drawn out of it, trailing back.
      final p = ((s.sim.tick - st.phaseFrom) / IslandSim.windupTicks).clamp(
        0.0,
        1.0,
      );
      for (var g = 0; g < 18; g++) {
        final h1 = hash01(g, 431 + i), h2 = hash01(g, 432 + i);
        final life = (p * 1.6 + h1) % 1.0;
        final back = (4 + 16 * life) * k;
        final side = (h2 - 0.5) * 12 * k;
        b.add(
          0,
          feet.dx - fx * back - fy * side * 0.6,
          feet.dy - fy * back * 0.6 + fx * side * 0.3 - sin(pi * life) * 8 * k,
        );
      }
      if (st.boosted) {
        for (var g = 0; g < 22; g++) {
          final h1 = hash01(g, 433 + i), h2 = hash01(g, 434 + i);
          final q = (p * 1.3 - h2 * 0.3).clamp(0.0, 1.0);
          final back = q * (10 + 22 * h1) * k;
          final lift = (14 + 10 * h2) * k;
          b.add(
            h2 < 0.4 ? 2 : 1,
            feet.dx - fx * back + (h1 - 0.5) * 8 * k,
            feet.dy - lift - fy * back * 0.6 + sin(q * 4 + g) * 2 * k,
          );
        }
      }
    } else if (st.phase == FighterPhase.dash) {
      // A plume of sand along the ground behind it, settling.
      for (var g = 0; g < 26; g++) {
        final h1 = hash01(g, 435), h2 = hash01(g, 436);
        final back = h1 * 34 * k;
        final side = (h2 - 0.5) * (4 + 14 * h1) * k;
        b.add(
          0,
          feet.dx - fx * back - fy * side,
          feet.dy - fy * back * 0.6 + fx * side * 0.4 - (1 - h1) * 5 * k,
        );
      }
      if (st.boosted) {
        // Its light stretched out behind it.
        final head = feet.translate(0, -body.height * k * 0.45);
        final tail = head.translate(-fx * 46 * k, -fy * 46 * k * 0.6);
        paintLightStreak(c, head, tail, 8 * k, col, 1);
      }
    }
    b.draw(c, 0, 1.6 * k / 2, look.sand[2].withValues(alpha: 0.7));
    b.draw(c, 1, 1.8 * k / 2, col.withValues(alpha: 0.75));
    b.draw(c, 2, 2.2 * k / 2, hot);

    // Reeling: a wobble; landing in the intro: a squash.
    var squash = 1.0;
    final reel = st.phase == FighterPhase.reel
        ? sin((s.sim.tick - st.phaseFrom) * 0.6) * 0.18
        : 0.0;
    if (s.phase == IslandStagePhase.intro && arrive >= 1 && arrive < 1.4) {
      squash = 1 - 0.18 * sin(pi * (arrive - 1) / 0.4);
    }
    final faceRight = switch (st.phase) {
      FighterPhase.dash ||
      FighterPhase.windup => st.target >= 0 ? s.x[st.target] >= s.x[i] : true,
      _ => s.x[i] < 0,
    };
    final centre = feet.translate(0, -body.height * k * 0.5 * squash);
    paintRaceBody(
      c,
      body,
      centre,
      k,
      t,
      squash: squash,
      lean: 0.03 + reel,
      faceRight: faceRight,
    );
  }

  /// One gone over the edge: it drops, tipping, fading into the dark, and
  /// its own grains stream up off it and go out behind it.
  void _falling(
    Canvas c,
    int i,
    Offset edge,
    Color col,
    double age,
    double k,
    double t,
  ) {
    final s = stage;
    final st = s.sim.states[i];
    final out = Offset(st.x, st.y);
    final ol = out.distance;
    final ox = ol > 0 ? out.dx / ol : 0.0;
    Offset where(double a) =>
        edge.translate(ox * a * 30 * k, 0.5 * 420 * a * a);
    final feet = where(age);
    final alpha = (1 - age / 0.9).clamp(0.0, 1.0);
    final body = s.bodies[i];
    if (alpha > 0) {
      paintRaceBody(
        c,
        body,
        feet.translate(0, -body.height * k * 0.5),
        k,
        t,
        alpha: alpha,
        lean: 0.03 + age * 1.6 * (ox >= 0 ? 1 : -1),
        faceRight: ox < 0,
      );
    }
    final b = _b..clear();
    final p = age / 1.6;
    if (p >= 1) return;
    for (var g = 0; g < 40; g++) {
      final h1 = hash01(g, 441 + i), h2 = hash01(g, 442 + i);
      // Each left the body at its own moment, and hangs where it left.
      final left = h1 * min(age, 1.0);
      final from = where(
        left,
      ).translate(0, -body.height * k * (0.2 + 0.6 * h2));
      final since = age - left;
      b.add(
        since < 0.3 ? 0 : 1,
        from.dx + (h2 - 0.5) * 16 * k * since,
        from.dy - since * 26 * k,
      );
    }
    final fade = 1 - _smooth(p);
    b.draw(c, 1, 1.6 * k / 2, col.withValues(alpha: 0.45 * fade));
    b.draw(
      c,
      0,
      2.0 * k / 2,
      Color.lerp(col, Colors.white, 0.45)!.withValues(alpha: 0.9 * fade),
    );
  }

  /// A blow landing: sand thrown on along the blow, arcing and falling,
  /// and a few grains of the one struck.
  void _bursts(
    Canvas c,
    Offset Function(double, double) at,
    double sx,
    _IslandLook look,
  ) {
    final s = stage;
    final k = sx * 0.95;
    for (final burst in s.bursts) {
      if (burst.fall) continue;
      final age = s.clock - burst.clock;
      if (age > 0.9) continue;
      final p = age / 0.9;
      final struck = burst.lane;
      final d = Offset(s.x[struck], s.y[struck]) - burst.at;
      final l = d.distance;
      final ux = l > 0 ? d.dx / l : 1.0, uy = l > 0 ? d.dy / l : 0.0;
      final o = at(burst.at.dx, burst.at.dy).translate(0, -4 * k);
      final b = _b..clear();
      for (var g = 0; g < 34; g++) {
        final h1 = hash01(g, 451 + burst.clock.floor());
        final h2 = hash01(g, 452);
        // Thrown within a cone about the blow's way, one side more.
        final a = atan2(uy, ux) + (h1 - 0.42) * 1.5;
        final v = (18 + 34 * h2) * k / 2;
        final x = o.dx + cos(a) * v * p * 1.6;
        final y =
            o.dy +
            sin(a) * v * p * 0.9 -
            (1 - p) * p * 30 * k / 2 +
            40 * k / 2 * p * p;
        b.add(g < 26 ? 0 : 1, x, y);
      }
      final col = elementColor(s.bodies[struck].member.element);
      final fade = 1 - _smooth(p);
      b.draw(c, 0, 1.6 * k / 2, look.sand[3].withValues(alpha: 0.9 * fade));
      b.draw(c, 1, 1.9 * k / 2, col.withValues(alpha: fade));
    }
  }

  /// The last one standing, in the Ruby Cup's light: a soft beam from far
  /// above (no edge to it), light pooled at its feet, motes rising (in
  /// front of it as well as behind).
  void _winnerLight(
    Canvas c,
    Offset Function(double, double) at,
    double sx,
    double t, {
    required bool back,
  }) {
    final s = stage;
    final win = s.standings.first;
    final feet = at(s.x[win], s.y[win]);
    final k = sx * 0.95;
    final up = _smooth((s.clock - (s.overAt ?? s.clock)) / 1.1);
    if (up <= 0) return;
    const ruby = Color(0xFFE0506A), rose = Color(0xFFFF8FA0);
    if (back) {
      final img = trialsBeamImage();
      final src = Rect.fromLTWH(
        0,
        0,
        img.width.toDouble(),
        img.height.toDouble(),
      );
      final tall = 300 * k / 2;
      for (final (col, wide, a) in [(ruby, 46.0, 0.5), (rose, 22.0, 0.32)]) {
        c.drawImageRect(
          img,
          src,
          Rect.fromLTRB(
            feet.dx - wide * k / 2,
            feet.dy - tall,
            feet.dx + wide * k / 2,
            feet.dy,
          ),
          Paint()
            ..filterQuality = FilterQuality.low
            ..colorFilter = ColorFilter.mode(
              col.withValues(alpha: a * up),
              BlendMode.modulate,
            ),
        );
      }
      c.save();
      c.translate(feet.dx, feet.dy + 1);
      c.scale(1, 0.3);
      final r = 44 * k / 2;
      c.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset.zero,
            r,
            [
              rose.withValues(alpha: 0.45 * up),
              ruby.withValues(alpha: 0.12 * up),
              ruby.withValues(alpha: 0),
            ],
            const [0.0, 0.5, 1.0],
          ),
      );
      c.restore();
    }
    final b = _b..clear();
    for (var i = 0; i < 30; i++) {
      if ((hash01(i, 485) < 0.3) == back) continue;
      final life = (t * (0.2 + 0.12 * hash01(i, 481)) + hash01(i, 482)) % 1.0;
      b.add(
        life < 0.4 ? 1 : 0,
        feet.dx + (hash01(i, 483) - 0.5) * 36 * k / 2 * (1 - life * 0.5),
        feet.dy - life * 220 * k / 2,
      );
    }
    b.draw(c, 0, 1.4, rose.withValues(alpha: 0.55 * up));
    b.draw(c, 1, 1.9, const Color(0xFFFFE6EA).withValues(alpha: 0.85 * up));
  }

  @override
  bool shouldRepaint(IslandPainter old) => old.stage != stage;
}
