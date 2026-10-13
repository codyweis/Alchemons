// lib/games/stadium/flight_stage.dart
//
// The space course as it is watched (the Emerald Cup's bouts,
// flight_rules.dart): the flight stepped under a real-time clock, the three
// eased between steps, the camera climbing with the player, and the
// theatre round it — the count, a boost gathering and surging, the forks
// parting the three onto their own ways and bringing them back together,
// the gate.
//
// FlightPainter draws it in grains on black, upright: the course climbs
// the screen through the stars; at a fork it parts in two, each way told
// only by what fills it — dark rocks lit at their rims (asteroids), grains
// spiralling into a black heart (gravity), comets falling past with their
// tails (comet tails), clouds of coloured light (nebula) — and comes
// together again; a band of green light across the top is the gate. Each
// flyer leaves a wake along its own way.

import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/obsidian_kit.dart';
import 'package:alchemons/games/stadium/bout_stage.dart';
import 'package:alchemons/games/stadium/flight_rules.dart';
import 'package:alchemons/games/stadium/gem_cups.dart';
import 'package:alchemons/games/stadium/race_bodies.dart';
import 'package:alchemons/games/stadium/race_painter.dart';
import 'package:alchemons/games/stadium/race_rules.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/material.dart';

/// The course for an Emerald Cup bout.
FlightCourse flightCourseOf(GemBout bout) =>
    kFlightCourses[bout.place] ?? kFlightCourses.values.first;

enum _Phase { intro, countdown, fly, done }

class FlightStage extends ChangeNotifier implements BoutStage {
  FlightStage({
    required this.course,
    required this.fighters,
    required this.bodies,
    required this.player,
    required List<List<int>> choices,
  }) : sim = FlightSim(course, fighters, choices) {
    final n = fighters.length;
    pd = List.filled(n, 0);
    d = List.filled(n, 0);
    _seenBoosts = List.filled(n, 0);
    boostAtClock = List.filled(n, null);
  }

  final FlightCourse course;
  final List<Racer> fighters;
  final List<RaceBody> bodies;
  @override
  final int player;
  final FlightSim sim;

  static const double introSeconds = 2.0, countdownSeconds = 3.0;

  _Phase _phase = _Phase.intro;
  @override
  double clock = 0;
  double flyClock = 0;
  double _acc = 0;
  double? _overAt;
  int _countSaid = 4;
  late final List<double> pd, d;
  late final List<int> _seenBoosts;
  late final List<double?> boostAtClock;

  @override
  final List<BoutSound> sounds = [];

  bool get flying => _phase == _Phase.fly;
  double get countdownLeft => _phase == _Phase.countdown
      ? max(0, introSeconds + countdownSeconds - clock)
      : 0;

  /// How far through its own route each is, eased (0..1 per stretch, and
  /// which stretch) — now, or at [at] along it.
  (int, double) where(int i, [double? at]) {
    final r = sim.routes[i];
    final starts = sim.starts[i];
    final dist = at ?? d[i];
    for (var j = r.length - 1; j >= 0; j--) {
      if (dist >= starts[j]) {
        return (j, ((dist - starts[j]) / r[j].length).clamp(0.0, 1.0));
      }
    }
    return (0, 0);
  }

  // ── what the bout screen reads ──

  @override
  bool get done => _phase == _Phase.done;
  @override
  List<int> get standings => sim.standings;
  @override
  bool get hasAction => true;
  @override
  String? get caption => null;
  @override
  bool get canAct => flying && sim.canBoost(player);
  @override
  int get actsLeft => sim.states[player].boostsLeft;
  @override
  bool act() {
    if (!canAct) return false;
    sim.tap(player);
    sounds.add(BoutSound.act);
    return true;
  }

  @override
  double? get actPour {
    final me = sim.states[player];
    if (me.phase != RacerPhase.windup) return null;
    return (sim.tick - me.phaseFrom) / kRaceBoostWindupTicks;
  }

  @override
  String get actLabel => 'BOOST';
  @override
  String? tagOf(int i) => switch (sim.states[i].finishTime) {
    final t? => '${t.toStringAsFixed(2)}s',
    null => null,
  };
  @override
  bool dimmed(int i) => false;
  @override
  String headline(int place) =>
      place == 1 ? 'FIRST THROUGH THE GATE' : 'BEATEN TO THE GATE';
  @override
  String? resultOf(int i) => tagOf(i);

  /// The player's time through the gate.
  @override
  double? get mark => sim.states[player].finishTime;

  /// How long the player took over each way it picked: what it has to go
  /// on next time (nothing says what a way asks).
  @override
  String? get note {
    final st = sim.states[player];
    final parts = <String>[];
    for (final j in course.forks) {
      if (j >= st.legEnteredAt.length) break;
      final from = st.legEnteredAt[j];
      final to = j + 1 < st.legEnteredAt.length
          ? st.legEnteredAt[j + 1] / kRaceTickRate
          : st.finishTime;
      if (to == null) break;
      final secs = to - from / kRaceTickRate;
      parts.add(
        '${sim.routes[player][j].kind.title} ${secs.toStringAsFixed(1)}s',
      );
    }
    return parts.isEmpty ? null : parts.join('  ·  ');
  }

  @override
  late final CustomPainter painter = FlightPainter(this);

  double? get overAt => _overAt;

  @override
  void advance(double dt) {
    dt = min(dt, 0.1);
    clock += dt;
    switch (_phase) {
      case _Phase.intro:
        if (clock >= introSeconds) _phase = _Phase.countdown;
      case _Phase.countdown:
        final n = countdownLeft.ceil();
        if (n < _countSaid && n > 0) {
          _countSaid = n;
          sounds.add(BoutSound.countTick);
        }
        if (clock >= introSeconds + countdownSeconds) {
          _phase = _Phase.fly;
          sounds.add(BoutSound.gun);
        }
      case _Phase.fly:
        flyClock += dt;
        _run(dt);
        if (sim.over) {
          _overAt ??= clock;
          if (clock - _overAt! >= 1.8) {
            _phase = _Phase.done;
            sounds.add(BoutSound.win);
          }
        }
      case _Phase.done:
        _run(dt);
    }
    notifyListeners();
  }

  final List<bool> _finishedSaid = [false, false, false];

  void _run(double dt) {
    const step = 1 / kRaceTickRate;
    if (!sim.over) {
      _acc += dt;
      while (_acc >= step && !sim.over) {
        for (var i = 0; i < d.length; i++) {
          pd[i] = sim.states[i].distance;
        }
        sim.step();
        _acc -= step;
        for (var i = 0; i < d.length; i++) {
          final s = sim.states[i];
          if (s.boostsAt.length != _seenBoosts[i]) {
            _seenBoosts[i] = s.boostsAt.length;
            boostAtClock[i] = clock;
          }
          if (s.finishTime != null && i < 3 && !_finishedSaid[i]) {
            _finishedSaid[i] = true;
            sounds.add(BoutSound.out);
          }
        }
      }
      final a = _acc / step;
      for (var i = 0; i < d.length; i++) {
        d[i] = pd[i] + (sim.states[i].distance - pd[i]) * a;
      }
    } else {
      // Past the gate, each drifts on a little.
      for (var i = 0; i < d.length; i++) {
        d[i] = min(d[i] + 40 * dt, sim.lengths[i] + 140);
      }
    }
  }
}

// ── the painter ─────────────────────────────────────────────────────────────

double _ease(double x) {
  final t = x.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

final GrainBatch _wayBatch = GrainBatch(6);

/// What fills a way of [kind] through [way] at [t] — rocks, a well, comets,
/// a cloud — drawn the same in the flight and on the route planner. [k] is
/// the scene's scale; [seed] keeps two ways of a kind apart.
void paintFlightWay(
  Canvas c,
  Rect way,
  FlightKind kind,
  double t,
  int seed, {
  double k = 1,
}) {
  switch (kind) {
    case FlightKind.asteroids:
      _rocks(c, way, t, seed, k);
    case FlightKind.gravity:
      _well(c, way, t, seed, k);
    case FlightKind.comets:
      _comets(c, way, t, seed, k);
    case FlightKind.nebula:
      _nebula(c, way, t, seed, k);
    case FlightKind.open:
      break;
  }
}

/// Rocks drifting through the way: dark masses that hide the stars, lit
/// along the edge that faces the light by a rim of grains, dust about them.
void _rocks(Canvas c, Rect way, double t, int seed, double k) {
  final n = max(2, (way.height / (62 * k)).floor());
  final b = _wayBatch..clear();
  final dark = Paint()..color = const Color(0xFF0D0B09);
  for (var r = 0; r < n; r++) {
    final h1 = hash01(r, 621 + seed), h2 = hash01(r, 622 + seed);
    final size = (14 + 22 * hash01(r, 623 + seed)) * k;
    final drift = sin(t * 0.3 + r * 1.7) * 4 * k;
    final cx = way.left + way.width * (0.12 + 0.76 * h1) + drift;
    final cy = way.top + way.height * (r + 0.2 + 0.6 * h2) / n;
    final spin = t * (0.15 + 0.3 * hash01(r, 624)) * (r.isEven ? 1 : -1);
    double rad(double a) =>
        size *
        (0.78 + 0.18 * sin(a * 2 + r * 1.3) + 0.12 * sin(a * 3 + r * 0.7 + 1));
    final path = Path();
    const m = 16;
    for (var q = 0; q <= m; q++) {
      final a = q / m * 2 * pi;
      final rr = rad(a - spin);
      final p = Offset(cx + cos(a) * rr, cy + sin(a) * rr * 0.86);
      q == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    c.drawPath(path, dark);
    // The lit rim, brightest where it faces up and to the left.
    final grains = (size * 2.6 / k).round();
    for (var g = 0; g < grains; g++) {
      final a = hash01(g, 625 + r) * 2 * pi;
      final face = cos(a - (-2.3));
      if (face < -0.1) continue;
      final inset = hash01(g, 626 + r) * (face > 0.6 ? 0.35 : 0.15);
      final rr = rad(a - spin) * (1 - inset);
      b.add(
        face > 0.65 ? 0 : (face > 0.25 ? 1 : 2),
        cx + cos(a) * rr,
        cy + sin(a) * rr * 0.86,
      );
    }
    // Its face, dim: grains scattered over the side the light reaches.
    final face = (size * size / (14 * k * k)).round();
    for (var g = 0; g < face; g++) {
      final a = hash01(g, 629 + r) * 2 * pi;
      final rr = rad(a - spin) * sqrt(hash01(g, 630 + r)) * 0.92;
      final lit = cos(a - (-2.3)) * rr / size;
      if (lit < -0.25) continue;
      b.add(lit > 0.35 ? 2 : 4, cx + cos(a) * rr, cy + sin(a) * rr * 0.86);
    }
    // A little dust in its wake.
    for (var g = 0; g < 7; g++) {
      final a = hash01(g, 627 + r) * 2 * pi;
      final rr = size * (1.15 + 0.6 * hash01(g, 628 + r));
      b.add(3, cx + cos(a + spin * 0.5) * rr, cy + sin(a + spin * 0.5) * rr);
    }
  }
  b.draw(c, 4, 1.3 * k, const Color(0xFF3A3128).withValues(alpha: 0.9));
  b.draw(c, 3, 1.2 * k, const Color(0xFF6E5E48).withValues(alpha: 0.45));
  b.draw(c, 2, 1.4 * k, const Color(0xFF5A4C3C));
  b.draw(c, 1, 1.6 * k, const Color(0xFF9C8460));
  b.draw(c, 0, 1.8 * k, const Color(0xFFE6CFA4));
}

/// A well: a black heart, and grains drawn round and in to it along two
/// uneven arms, quicker and brighter the nearer they come.
void _well(Canvas c, Rect way, double t, int seed, double k) {
  final centre = way.center;
  final r = min(way.width * 0.5, way.height * 0.4);
  c.drawCircle(
    centre,
    r * 1.15,
    Paint()
      ..shader = ui.Gradient.radial(
        centre,
        r * 1.15,
        [
          const Color(0xFF8E78F0).withValues(alpha: 0.2),
          const Color(0xFF4A32A8).withValues(alpha: 0.07),
          const Color(0x004A32A8),
        ],
        const [0.0, 0.5, 1.0],
      ),
  );
  final b = _wayBatch..clear();
  const n = 460;
  for (var g = 0; g < n; g++) {
    final arm = g % 5 < 3 ? 0 : 1;
    // Each grain falls in over and over, from the rim to the heart.
    final life =
        (hash01(g, 631 + seed) + t * (0.09 + 0.05 * hash01(g, 632))) % 1;
    final rho = r * (1 - 0.86 * pow(life, 0.8));
    final spread = (hash01(g, 633) - 0.5) * (0.5 + 0.6 * rho / r);
    final a = arm * pi + 0.7 * arm + 2.6 * log(r / rho) + spread + t * 0.25;
    final x = centre.dx + cos(a) * rho;
    final y = centre.dy + sin(a) * rho * 0.82;
    final near = 1 - rho / r;
    b.add(near > 0.7 ? 0 : (near > 0.4 ? 1 : 2), x, y);
  }
  b.draw(c, 2, 1.3 * k, const Color(0xFF8E78F0).withValues(alpha: 0.45));
  b.draw(c, 1, 1.6 * k, const Color(0xFFB9A8FF).withValues(alpha: 0.75));
  b.draw(c, 0, 1.9 * k, const Color(0xFFF0EBFF));
  c.drawCircle(
    centre,
    r * 0.2,
    Paint()
      ..shader = ui.Gradient.radial(
        centre,
        r * 0.2,
        [Colors.black, Colors.black, Colors.black.withValues(alpha: 0)],
        const [0.0, 0.6, 1.0],
      ),
  );
}

/// Comets falling down the way, each a bright knot with a tail that widens
/// and fades behind it.
void _comets(Canvas c, Rect way, double t, int seed, double k) {
  final b = _wayBatch..clear();
  final n = max(3, (way.height / (150 * k)).round());
  for (var q = 0; q < n; q++) {
    final speed = 0.16 + 0.12 * hash01(q, 641 + seed);
    final life = (t * speed + hash01(q, 642 + seed)) % 1.0;
    final slant = (hash01(q, 644 + seed) - 0.5) * 0.5;
    final x0 = way.left + way.width * (0.15 + 0.7 * hash01(q, 643 + seed));
    final travel = way.height + 160 * k;
    final y = way.top - 80 * k + travel * life;
    final x = x0 + slant * (y - way.top);
    final head = Offset(x, y);
    final len = (70 + 50 * hash01(q, 645)) * k;
    final tailEnd = head.translate(-slant * len, -len);
    final side = Offset(len, -slant * len) / len;
    final tail = Path()
      ..moveTo(head.dx + side.dx * 3.5 * k, head.dy + side.dy * 3.5 * k)
      ..lineTo(tailEnd.dx + side.dx * 9 * k, tailEnd.dy + side.dy * 9 * k)
      ..lineTo(tailEnd.dx - side.dx * 9 * k, tailEnd.dy - side.dy * 9 * k)
      ..lineTo(head.dx - side.dx * 3.5 * k, head.dy - side.dy * 3.5 * k)
      ..close();
    c.drawPath(
      tail,
      Paint()
        ..shader = ui.Gradient.linear(
          head,
          tailEnd,
          [
            const Color(0xFFBFE8FF).withValues(alpha: 0.32),
            const Color(0xFF7FC4F0).withValues(alpha: 0.08),
            const Color(0x007FC4F0),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );
    c.drawCircle(
      head,
      9 * k,
      Paint()
        ..shader = ui.Gradient.radial(head, 9 * k, [
          const Color(0xFFF2FCFF).withValues(alpha: 0.7),
          const Color(0x009FDCFF),
        ]),
    );
    for (var g = 0; g < 34; g++) {
      final u = pow(hash01(g, 646 + q), 1.4).toDouble();
      final w = (hash01(g, 647 + q) - 0.5) * (2 + 16 * u) * k;
      final p = head + (tailEnd - head) * u + side * w;
      b.add(u < 0.12 ? 0 : (u < 0.45 ? 1 : 2), p.dx, p.dy);
    }
  }
  b.draw(c, 2, 1.3 * k, const Color(0xFF7FC4F0).withValues(alpha: 0.35));
  b.draw(c, 1, 1.6 * k, const Color(0xFFBFE8FF).withValues(alpha: 0.7));
  b.draw(c, 0, 2.2 * k, const Color(0xFFF4FCFF));
}

/// Clouds of coloured light lying across the way, uneven, slowly moving,
/// fine dust glinting in them.
void _nebula(Canvas c, Rect way, double t, int seed, double k) {
  final clouds = max(3, (way.height / (110 * k)).floor() + 1);
  for (var q = 0; q < clouds; q++) {
    final at = Offset(
      way.left +
          way.width * (0.15 + 0.7 * hash01(q, 651 + seed)) +
          sin(t * 0.13 + q) * 8 * k,
      way.top + way.height * (q + 0.3 + 0.4 * hash01(q, 652 + seed)) / clouds,
    );
    final r = way.width * (0.38 + 0.3 * hash01(q, 653 + seed));
    final col = switch (q % 3) {
      0 => const Color(0xFFD86AB8),
      1 => const Color(0xFF6E86E8),
      _ => const Color(0xFF9A6EE0),
    };
    c.save();
    c.translate(at.dx, at.dy);
    c.scale(1, 0.7 + 0.4 * hash01(q, 654 + seed));
    c.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          r,
          [
            col.withValues(alpha: 0.22),
            col.withValues(alpha: 0.07),
            col.withValues(alpha: 0),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );
    c.restore();
  }
  final b = _wayBatch..clear();
  final n = (way.width * way.height / (900 * k * k)).round().clamp(40, 260);
  for (var g = 0; g < n; g++) {
    final x =
        way.left + way.width * hash01(g, 655 + seed) + sin(t * 0.2 + g) * 3 * k;
    final y = way.top + way.height * hash01(g, 656 + seed);
    final tw = sin(t * (0.8 + hash01(g, 657)) + g * 1.3);
    b.add(tw > 0.7 ? 0 : 1, x, y);
  }
  b.draw(c, 1, 1.2 * k, const Color(0xFFF0C8F0).withValues(alpha: 0.4));
  b.draw(c, 0, 1.9 * k, const Color(0xFFFFF4FC));
}

class FlightPainter extends CustomPainter {
  FlightPainter(this.stage) : super(repaint: stage);

  final FlightStage stage;
  static final GrainBatch _b = GrainBatch(10);

  /// How tall each stretch stands on the screen, for a screen [h] tall.
  static double _height(List<FlightRoute> s, double h) =>
      s.length > 1 ? h * 1.25 : h * 0.6;

  @override
  void paint(Canvas canvas, Size size) {
    final s = stage;
    final w = size.width, h = size.height;
    final k = w / 475;
    final t = s.clock;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), const [
          Color(0xFF04050A),
          Color(0xFF070912),
        ]),
    );

    // The course climbs: stretch j spans [starts[j], starts[j] + heights[j]]
    // up from the start line (world y, up is more).
    final stretches = s.course.stretches;
    final heights = [for (final st in stretches) _height(st, h)];
    final starts = <double>[];
    var acc = 0.0;
    for (final hh in heights) {
      starts.add(acc);
      acc += hh;
    }
    final top = acc;

    double worldY(int i, [double? at]) {
      final dist = at ?? s.d[i];
      if (dist >= s.sim.lengths[i]) {
        return top + (dist - s.sim.lengths[i]) * 0.6;
      }
      final (j, f) = s.where(i, dist);
      return starts[j] + f * heights[j];
    }

    // Each fork's ways: left and right of the middle, easing out of it and
    // back in.
    double laneX(int i, [double? at]) {
      final dist = at ?? s.d[i];
      final spread = (i - 1) * w * 0.12;
      if (dist >= s.sim.lengths[i]) return w / 2 + spread;
      final (j, f) = s.where(i, dist);
      final st = stretches[j];
      if (st.length == 1) return w / 2 + spread;
      final fi = s.course.forks.indexOf(j);
      final choice = s.sim.choices[i][fi];
      final side = choice == 0 ? -1.0 : 1.0;
      final out = _ease(f / 0.18) * _ease((1 - f) / 0.18);
      return w / 2 + side * w * 0.26 * out + spread * (1 - out * 0.7);
    }

    // The camera keeps the player a little below the middle.
    final camY = max(0.0, worldY(s.player) - h * 0.32);
    double screenY(double wy) => h - (wy - camY) - h * 0.12;

    _stars(canvas, size, camY, t);
    for (var j = 0; j < stretches.length; j++) {
      final y0 = screenY(starts[j]), y1 = screenY(starts[j] + heights[j]);
      if (y0 < -60 || y1 > h + 60) continue;
      _stretch(canvas, size, stretches[j], y0, y1, t, j, k);
    }
    _gate(canvas, screenY(top), w, t, k);

    // Wakes first, under everyone; then the three, the furthest back first.
    for (var i = 0; i < s.d.length; i++) {
      _wake(canvas, i, laneX, worldY, screenY, t, k);
    }
    final order = [for (var i = 0; i < s.d.length; i++) i]
      ..sort((a, b) => worldY(a).compareTo(worldY(b)));
    for (final i in order) {
      _flyer(canvas, i, Offset(laneX(i), screenY(worldY(i))), w, t);
    }
    paintGrainCount(
      canvas,
      raceNumeralGrains,
      s.countdownLeft,
      Offset(w / 2, h * 0.32),
      w / 475,
      s.clock,
    );
  }

  void _stars(Canvas c, Size size, double camY, double t) {
    final b = _b..clear();
    for (var i = 0; i < 320; i++) {
      // Nearer stars slide past faster as the camera climbs.
      final depth = 0.15 + 0.6 * hash01(i, 601);
      final y =
          (hash01(i, 602) * size.height * 3 + camY * depth) %
          (size.height * 1.2);
      final tw = 0.5 + 0.5 * sin(t * (0.5 + hash01(i, 603)) + i);
      b.add(
        depth > 0.55 || tw > 0.92 ? 1 : 0,
        hash01(i, 604) * size.width,
        y - size.height * 0.1,
      );
    }
    b.draw(c, 0, 1.0, const Color(0xFFE6E2DA).withValues(alpha: 0.35));
    b.draw(c, 1, 1.6, const Color(0xFFF2EEE6).withValues(alpha: 0.75));
  }

  /// One stretch, from [y0] (its start, lower on screen) to [y1]: open space
  /// is a faint current of dust up the middle; a fork, its two ways' own
  /// trouble either side.
  void _stretch(
    Canvas c,
    Size size,
    List<FlightRoute> st,
    double y0,
    double y1,
    double t,
    int j,
    double k,
  ) {
    final w = size.width;
    if (st.length == 1) {
      _current(c, Rect.fromLTRB(w * 0.32, y1, w * 0.68, y0), t, j, k);
      return;
    }
    for (var q = 0; q < st.length; q++) {
      final side = q == 0 ? -1.0 : 1.0;
      final cx = w / 2 + side * w * 0.26;
      // The way's trouble fills the middle of the stretch, where the flyers
      // have parted.
      final way = Rect.fromLTRB(
        cx - w * 0.2,
        y1 + (y0 - y1) * 0.1,
        cx + w * 0.2,
        y0 - (y0 - y1) * 0.12,
      );
      paintFlightWay(c, way, st[q].kind, t, j * 7 + q, k: k);
    }
  }

  /// Dust drifting up the course, faint: which way it goes.
  void _current(Canvas c, Rect band, double t, int seed, double k) {
    final b = _b..clear();
    final n = (band.height / (9 * k)).round();
    for (var g = 0; g < n; g++) {
      final u = (hash01(g, 611 + seed) + t * 0.05) % 1.0;
      final y = band.bottom - u * band.height;
      final x =
          band.left +
          band.width * hash01(g, 612 + seed) +
          sin(t * 0.4 + g) * 4 * k;
      final fade = sin(u * pi);
      b.add(fade > 0.6 ? 0 : 1, x, y);
    }
    b.draw(c, 1, 1.1 * k, const Color(0xFFCDB07A).withValues(alpha: 0.12));
    b.draw(c, 0, 1.3 * k, const Color(0xFFE2C98F).withValues(alpha: 0.26));
  }

  /// The gate: a curtain of green light hung across the top of the course,
  /// rays of fine grains rising from a bright foot, slowly swaying.
  void _gate(Canvas c, double y, double w, double t, double k) {
    if (y < -160 * k || y > 4000) return;
    const green = Color(0xFF5BE0A0), pale = Color(0xFFCFF7DF);
    const teal = Color(0xFF4FC6D8);
    final b = _b..clear();
    const rays = 80;
    for (var r = 0; r < rays; r++) {
      final x = (r + hash01(r, 671)) / rays * (w + 16) - 8;
      final foot =
          y +
          sin(x / w * 6.0 + t * 0.35) * 6 * k +
          sin(x / w * 17 - t * 0.5) * 2 * k;
      final reach = (30 + 70 * (0.5 + 0.5 * sin(x / w * 8.0 - t * 0.4))) * k;
      const n = 12;
      for (var g = 0; g < n; g++) {
        final f = pow((g + hash01(r * n + g, 672)) / n, 1.3);
        final jx = (hash01(r * n + g, 673) - 0.5) * 2 * k;
        b.add(
          f < 0.08 || f > 0.5 ? (f > 0.5 ? 2 : 1) : 0,
          x + jx,
          foot - f * reach,
        );
      }
    }
    b.draw(c, 2, 1.2 * k, teal.withValues(alpha: 0.18));
    b.draw(c, 1, 1.3 * k, green.withValues(alpha: 0.38));
    b.draw(c, 0, 1.6 * k, pale.withValues(alpha: 0.7));
  }

  /// A flyer's wake: grains along the way it has just come, loosening and
  /// going out behind it; longer and brighter on a surge.
  void _wake(
    Canvas c,
    int i,
    double Function(int, [double?]) laneX,
    double Function(int, [double?]) worldY,
    double Function(double) screenY,
    double t,
    double k,
  ) {
    final s = stage;
    final col = elementColor(s.bodies[i].member.element);
    // Eased in as a surge starts (after the wind-up), out once it is done.
    const windup = kRaceBoostWindupTicks / kRaceTickRate;
    const surge = kRaceBoostSurgeTicks / kRaceTickRate;
    final since = s.boostAtClock[i] == null ? 99.0 : t - s.boostAtClock[i]!;
    final heat =
        _ease((since - windup) / 0.3) *
        (1 - _ease((since - windup - surge) / 0.6));
    final intro = _ease((s.clock - FlightStage.introSeconds) / 0.6);
    if (intro <= 0) return;
    // Sampled back along its own way, each sample a loose handful that
    // spreads and dims with age: a mist, not a line.
    final gap = 3 + 3 * heat;
    final b = _b..clear();
    const n = 34;
    for (var q = 1; q <= n; q++) {
      final at = s.d[i] - q * gap;
      if (at < 0) break;
      final p = Offset(laneX(i, at), screenY(worldY(i, at)));
      final age = q / n;
      for (var g = 0; g < 4; g++) {
        final h1 = hash01(q * 4 + g, 681 + i), h2 = hash01(q * 4 + g, 682);
        final drift = (h1 - 0.5) * (8 + 30 * age) * k;
        final rise = (h2 - 0.3) * 10 * age * k;
        b.add(age < 0.25 ? 0 : (age < 0.6 ? 1 : 2), p.dx + drift, p.dy + rise);
      }
    }
    final hot = Color.lerp(col, Colors.white, 0.5)!;
    final a = intro * (0.45 + 0.55 * heat);
    b.draw(c, 2, 1.1 * k, col.withValues(alpha: 0.14 * a));
    b.draw(c, 1, 1.3 * k, col.withValues(alpha: 0.32 * a));
    b.draw(c, 0, 1.6 * k, hot.withValues(alpha: 0.55 * a));
    // On a surge, a streak of its light stretched out behind it.
    if (heat > 0.02) {
      final head = Offset(laneX(i), screenY(worldY(i)));
      final back = max(0.0, s.d[i] - 90);
      final tail = Offset(laneX(i, back), screenY(worldY(i, back)));
      paintLightStreak(c, head, tail, 8 * k, col, heat);
    }
  }

  void _flyer(Canvas c, int i, Offset at, double w, double t) {
    final s = stage;
    final body = s.bodies[i];
    final col = elementColor(body.member.element);
    final k = w / 475 * 1.9;
    final st = s.sim.states[i];
    // Coming in from below in the intro.
    var p = at;
    if (s.clock < FlightStage.introSeconds) {
      final e = _ease(s.clock / FlightStage.introSeconds);
      p = p.translate(0, (1 - e) * 240);
    }
    p = p.translate(0, sin(t * 2.2 + i) * 2.5);
    // Gathering itself for a boost: its own grains drawn in from behind it,
    // more from one side than the other, its light swelling.
    var swell = 0.0;
    if (st.phase == RacerPhase.windup) {
      final q = ((s.sim.tick - st.phaseFrom) / kRaceBoostWindupTicks).clamp(
        0.0,
        1.0,
      );
      swell = _ease(q);
      final b = _b..clear();
      for (var g = 0; g < 24; g++) {
        final h1 = hash01(g, 662 + i), h2 = hash01(g, 663 + i);
        final a = pi * 0.5 + (h1 - 0.35) * 2.2;
        final from = (18 + 26 * h2) * k;
        final r = from * (1 - _ease((q * 1.3 - h2 * 0.3)));
        if (r < 2) continue;
        final sw = (1 - q) * 0.8 * (h1 - 0.5);
        b.add(h2 < 0.4 ? 0 : 1, p.dx + cos(a + sw) * r, p.dy + sin(a + sw) * r);
      }
      b.draw(c, 1, 1.6 * w / 475, col.withValues(alpha: 0.6));
      b.draw(c, 0, 2.0 * w / 475, Color.lerp(col, Colors.white, 0.5)!);
    } else if (st.phase == RacerPhase.surge) {
      swell = 1 - _ease((s.sim.tick - st.phaseFrom) / kRaceBoostSurgeTicks);
    }
    final glowR = (18 + 10 * swell) * k;
    c.drawCircle(
      p,
      glowR,
      Paint()
        ..shader = ui.Gradient.radial(p, glowR, [
          (i == s.player ? const Color(0xFFE2C98F) : col).withValues(
            alpha: (i == s.player ? 0.16 : 0.06) + 0.22 * swell,
          ),
          col.withValues(alpha: 0),
        ]),
    );
    paintRaceBody(c, body, p, k, t, lean: -0.25, faceRight: true);
  }

  @override
  bool shouldRepaint(FlightPainter old) => old.stage != stage;
}
