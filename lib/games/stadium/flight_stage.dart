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
// the screen through the stars and a far haze of nebulae; at a fork it
// parts in two, each way told only by what fills it — dark rocks lit at
// their rims (asteroids), grains spiralling into a black heart (gravity),
// comets falling past with their tails (comet tails), clouds of coloured
// light (nebula), a veil of an element's grains hung across the way (an
// element gate) — and comes together again; a band of green light across
// the top is the gate. Each flyer leaves a wake along its own way.
//
// A well is slung round: the flyer swings once about its heart and is
// flung out of the top, and on the Gravity Chain the run-out after it is
// flown faster the cleaner the chain — a streak of its light behind it.
// A gate's veil parts round whoever flies through it; through a gate with
// a recipe the flyer comes apart into what it makes (EssenceField, as at
// the race's fusion stations) and gathers again as that form.
//
// With friends ([BoutLive]) every phone flies the same flight, kept to the
// shared gun, the others' boosts merged in as they come.

import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/obsidian_kit.dart';
import 'package:alchemons/games/stadium/bout_stage.dart';
import 'package:alchemons/games/stadium/flight_rules.dart';
import 'package:alchemons/games/stadium/race_bodies.dart';
import 'package:alchemons/games/stadium/race_painter.dart';
import 'package:alchemons/games/stadium/race_rules.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/material.dart';

enum _Phase { intro, countdown, fly, done }

/// Every form each flyer takes on [course] by its route ([choices], one
/// list per flyer), by element (lower case): its own, then what each gate
/// makes it. Load them with the bodies and hand them to [FlightStage].
List<Map<String, RaceBody>> flightForms(
  CreatureCatalog catalog,
  List<Racer> fighters,
  List<RaceBody> bodies,
  FlightCourse course,
  List<List<int>> choices,
) => [
  for (var i = 0; i < fighters.length; i++)
    () {
      final own = fighters[i].entrant.element.toLowerCase();
      final out = <String, RaceBody>{own: bodies[i]};
      if (!course.gates) return out;
      final legs = FlightLegs.of(fighters[i], course, choices[i]);
      for (final e in legs.elements) {
        final key = e.toLowerCase();
        if (out.containsKey(key)) continue;
        final m = raceFormMember(catalog, bodies[i].member, e);
        if (m != null) out[key] = RaceBody(m);
      }
      return out;
    }(),
];

class FlightStage extends ChangeNotifier implements BoutStage {
  FlightStage({
    required this.course,
    required this.fighters,
    required this.bodies,
    required this.player,
    required List<List<int>> choices,
    this.forms,
    this.live,
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
  FlightSim sim;

  /// Each flyer's forms by element (lower case), from [flightForms];
  /// without them a flyer keeps its own body whatever a gate makes it.
  final List<Map<String, RaceBody>>? forms;

  /// Flyer [i]'s body as [element].
  RaceBody bodyFor(int i, String element) =>
      forms?[i][element.toLowerCase()] ?? bodies[i];

  /// Set for a flight with friends.
  final BoutLive? live;

  static const double introSeconds = 2.0, countdownSeconds = 3.0;

  /// Where through a gate's stretch its fusion plays: it starts as the
  /// flyer reaches the veil and is done once it is out the other side.
  static const double fuseFrom = 0.3, fuseTo = 0.74;

  /// When a flyer that fuses into something new hands its old form over
  /// to the new one (essence seconds).
  static const double handOver = 1.15;

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

  /// The essence's time (seconds) of a gate's fusion [f] of the way
  /// through its stretch, or null outside it.
  static double? fusionTime(double f) {
    if (f <= fuseFrom || f >= fuseTo) return null;
    return (f - fuseFrom) / (fuseTo - fuseFrom) * EssenceField.duration;
  }

  /// What flyer [i] is at [dist] along its route: what it entered the
  /// stretch as, or — once a gate's fusion has handed over — what the gate
  /// made it.
  String elementAt(int i, double dist) {
    final legs = sim.legs[i];
    if (dist >= sim.lengths[i]) return legs.elements.last;
    final (j, f) = where(i, dist);
    if (legs.made[j] != null) {
      final et = fusionTime(f);
      if (f >= fuseTo || (et != null && et >= handOver + 0.15)) {
        return legs.elements[j + 1];
      }
    }
    return legs.elements[j];
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
  bool get canAct => flying && sim.canBoost(player) && !sim.hasPending(player);
  @override
  int get actsLeft => sim.states[player].boostsLeft;
  @override
  bool act() {
    if (!canAct) return false;
    sim.tap(player, live == null ? null : sim.tick + BoutLive.tapLead);
    sounds.add(BoutSound.act);
    return true;
  }

  @override
  List<int> get myTaps => [...?sim.taps[player]];

  @override
  void mergeTaps(int i, List<int> ticks) {
    if (i < 0 || i >= fighters.length || i == player) return;
    final have = sim.taps[i] ?? const <int>[];
    final fresh = [
      for (final t in ticks)
        if (!have.contains(t)) t,
    ];
    if (fresh.isEmpty) return;
    if (fresh.every((t) => t >= sim.tick)) {
      for (final t in fresh) {
        sim.tap(i, t);
      }
      return;
    }
    // The players' taps (a computer flyer taps again by itself).
    final all = <int, List<int>>{
      for (final e in sim.taps.entries)
        if (fighters[e.key].isPlayer) e.key: [...e.value],
    };
    (all[i] ??= []).addAll(fresh);
    sim = FlightSim.replay(course, fighters, sim.choices, all, sim.tick);
    for (var k = 0; k < fighters.length; k++) {
      pd[k] = sim.states[k].distance;
      _seenBoosts[k] = sim.states[k].boostsAt.length;
    }
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
      parts.add('${sim.routes[player][j].title} ${secs.toStringAsFixed(1)}s');
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
    final live = this.live;
    if (live != null && _phase.index <= _Phase.countdown.index) {
      // The count ends on the gun, whenever this phone came to it.
      clock = max(clock - dt, introSeconds + countdownSeconds - live.toGun);
      if (clock < 0) clock = 0;
    }
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
        if (live != null) {
          _runLive(live, dt);
        } else {
          _run(dt);
        }
        if (sim.over) {
          _overAt ??= clock;
          // With friends, a moment more for a last tap from far away.
          if (clock - _overAt! >= (live == null ? 1.8 : 2.4)) {
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
        _step();
        _acc -= step;
      }
      _between(_acc / step);
    } else {
      _drift(dt);
    }
  }

  /// With friends: stepped to where the wall clock says, so every phone is
  /// at the same tick at the same moment.
  void _runLive(BoutLive live, double dt) {
    if (sim.over) {
      _drift(dt);
      return;
    }
    final at = max(0.0, -live.toGun) * kRaceTickRate;
    final target = at.floor();
    while (sim.tick < target && !sim.over) {
      _step();
    }
    _between(sim.over ? 1.0 : (at - target).clamp(0.0, 1.0));
  }

  void _step() {
    for (var i = 0; i < d.length; i++) {
      pd[i] = sim.states[i].distance;
    }
    sim.step();
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

  /// Each one [a] of the way from its last step to this one.
  void _between(double a) {
    for (var i = 0; i < d.length; i++) {
      d[i] = pd[i] + (sim.states[i].distance - pd[i]) * a;
    }
  }

  /// Past the gate, each drifts on a little.
  void _drift(double dt) {
    for (var i = 0; i < d.length; i++) {
      d[i] = min(d[i] + 40 * dt, sim.lengths[i] + 140);
    }
  }
}

// ── what fills a way ────────────────────────────────────────────────────────

double _ease(double x) {
  final t = x.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

final GrainBatch _wayBatch = GrainBatch(6);

/// What fills a way of [kind] through [way] at [t] — rocks, a well, comets,
/// a cloud, a gate's veil of its [element] — drawn the same in the flight
/// and on the route planner. [k] is the scene's scale; [seed] keeps two
/// ways of a kind apart. A veil parts round each of [parts] (flyers going
/// through it), and is drawn whole, or ([layer] 0 / 1) only its far or near
/// grains, so a flyer can be drawn between them.
void paintFlightWay(
  Canvas c,
  Rect way,
  FlightKind kind,
  double t,
  int seed, {
  double k = 1,
  String? element,
  List<Offset> parts = const [],
  int? layer,
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
    case FlightKind.gate:
      _veil(c, way, element ?? 'Spirit', t, seed, k, parts, layer);
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
    _rock(c, b, dark, Offset(cx, cy), size, t, r, k);
  }
  _drawRocks(c, b, k);
}

/// One rock into [b]: its dark mass drawn now, its lit rim, face and dust
/// as grains.
void _rock(
  Canvas c,
  GrainBatch b,
  Paint dark,
  Offset at,
  double size,
  double t,
  int r,
  double k, {
  int dust = 7,
}) {
  final cx = at.dx, cy = at.dy;
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
  for (var g = 0; g < dust; g++) {
    final a = hash01(g, 627 + r) * 2 * pi;
    final rr = size * (1.15 + 0.6 * hash01(g, 628 + r));
    b.add(3, cx + cos(a + spin * 0.5) * rr, cy + sin(a + spin * 0.5) * rr);
  }
}

void _drawRocks(Canvas c, GrainBatch b, double k, [double alpha = 1]) {
  b.draw(c, 4, 1.3 * k, const Color(0xFF3A3128).withValues(alpha: 0.9 * alpha));
  b.draw(
    c,
    3,
    1.2 * k,
    const Color(0xFF6E5E48).withValues(alpha: 0.45 * alpha),
  );
  b.draw(c, 2, 1.4 * k, const Color(0xFF5A4C3C).withValues(alpha: alpha));
  b.draw(c, 1, 1.6 * k, const Color(0xFF9C8460).withValues(alpha: alpha));
  b.draw(c, 0, 1.8 * k, const Color(0xFFE6CFA4).withValues(alpha: alpha));
}

/// The well's heart and how wide its pull reaches, in [way].
(Offset, double) wellOf(Rect way) =>
    (way.center, min(way.width * 0.68, way.height * 0.42));

/// A well: a black heart, and grains drawn round and in to it along two
/// uneven arms, quicker and brighter the nearer they come.
void _well(Canvas c, Rect way, double t, int seed, double k) {
  final (centre, r) = wellOf(way);
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
  final n = (r * r / (14 * k * k)).round().clamp(260, 640);
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

/// How an element's grains move in its veil.
enum _Drift { rise, fall, across, still }

_Drift _driftOf(String element) => switch (element.toLowerCase()) {
  'fire' || 'lava' || 'steam' || 'spirit' || 'light' => _Drift.rise,
  'water' || 'ice' || 'mud' || 'poison' || 'dark' || 'blood' => _Drift.fall,
  'air' || 'dust' || 'lightning' => _Drift.across,
  _ => _Drift.still,
};

/// The middle of a gate's veil in [way], and how deep it hangs.
(double, double) veilOf(Rect way) => (
  way.center.dy,
  // (In a small picture, the route planner's, it fills more of it.)
  way.height < 160
      ? way.height * 0.62
      : min(way.height * 0.3, way.width * 0.62),
);

/// A gate: a veil hung across the way — a curtain of its element's grains
/// in fine hanging threads, as the finish is a curtain of green light —
/// swaying in folds, the grains moving along the threads as the element
/// does (flames rising, water and poison falling, air and dust blown
/// across, earth, crystal and leaves hanging still and glinting) over a
/// soft light of its colour. It parts round whoever flies through it.
void _veil(
  Canvas c,
  Rect way,
  String element,
  double t,
  int seed,
  double k,
  List<Offset> parts,
  int? layer,
) {
  final ee = EssenceElement.of(element);
  final ramp = essenceRamp(ee);
  final (mid0, band) = veilOf(way);
  final left = way.left - way.width * 0.04, span = way.width * 1.08;
  if (layer != 1) {
    // Its light, a soft pool lying along the veil.
    final pool = essencePool(ee);
    final r = span * 0.6;
    c.save();
    c.translate(way.center.dx, mid0);
    c.scale(1, band * 0.8 / r);
    c.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          r,
          [
            pool.withValues(alpha: 0.22),
            pool.withValues(alpha: 0.07),
            pool.withValues(alpha: 0),
          ],
          const [0.0, 0.55, 1.0],
        ),
    );
    c.restore();
  }
  final drift = _driftOf(element);
  final b = _wayBatch..clear();
  final threads = (span / (4.2 * k)).round().clamp(14, 60);
  final per = (band / (5.5 * k)).round().clamp(6, 22);
  final rho = 24 * k;
  for (var r = 0; r < threads; r++) {
    // The near threads in front of whoever flies through, the far behind.
    final front = hash01(r, 704 + seed) > 0.55;
    if (layer == 0 && front) continue;
    if (layer == 1 && !front) continue;
    final hr = hash01(r, 701 + seed);
    var u = (r + hr) / threads;
    if (drift == _Drift.across) u = (u + t * 0.02) % 1.0;
    final x0 = left + span * u;
    final fx = u * 6.3;
    // Its folds: the veil's middle sways, its depth swells along it.
    final mid = mid0 + sin(fx * 1.3 + t * 0.45 + seed) * band * 0.12;
    // Tapering to nothing at either end, ragged along its edge.
    final taper = sqrt(sin(pi * ((r + hr) / threads).clamp(0.0, 1.0)));
    final deep =
        band *
        taper *
        (0.45 +
            0.4 * (0.5 + 0.5 * sin(fx * 0.8 - t * 0.3 + seed)) +
            0.25 * hash01(r, 705 + seed));
    final lean =
        sin(fx * 0.9 + t * 0.5) * 0.18 + (drift == _Drift.across ? 0.35 : 0);
    final speed = 0.12 + 0.1 * hash01(r, 702 + seed);
    final m = max(3, (per * (0.3 + 0.7 * taper)).round());
    for (var g = 0; g < m; g++) {
      var v = (g + hash01(r * per + g, 703 + seed)) / m;
      switch (drift) {
        case _Drift.rise:
          v = (v - t * speed) % 1.0;
        case _Drift.fall:
          v = (v + t * speed) % 1.0;
        case _Drift.across:
          v = (v + t * speed * 0.5) % 1.0;
        case _Drift.still:
          break;
      }
      final dy = (v - 0.5) * deep;
      var x = x0 + dy * lean + sin(t * 1.3 + r + g * 0.4) * 0.8 * k;
      var y = mid + dy;
      // Parted round a flyer going through it.
      for (final p in parts) {
        final ddx = x - p.dx, ddy = (y - p.dy) * 1.3;
        final d2 = ddx * ddx + ddy * ddy;
        if (d2 < rho * rho && d2 > 0.01) {
          final dd = sqrt(d2);
          final push = (rho - dd) * 0.95;
          x += ddx / dd * push;
          y += ddy / dd * push / 1.3;
        }
      }
      // Brightest along its middle, thinning out above and below.
      final core = 1 - (2 * v - 1).abs();
      final tw = sin(t * (1.1 + hr * 1.7) + r * 2.3 + g * 1.9);
      b.add(tw > 0.94 ? 3 : (core > 0.6 ? 2 : (core > 0.25 ? 1 : 0)), x, y);
    }
  }
  b.draw(c, 0, 1.2 * k, ramp[1].withValues(alpha: 0.35));
  b.draw(c, 1, 1.35 * k, ramp[1].withValues(alpha: 0.8));
  b.draw(c, 2, 1.6 * k, ramp[2].withValues(alpha: 0.95));
  b.draw(c, 3, 2.2 * k, ramp[3]);
}

// ── the painter ─────────────────────────────────────────────────────────────

/// Where a flyer is drawn: its x on screen, its height up the course (world
/// y, up is more), and the height the camera follows for it (a sling's
/// loop left out).
typedef _At = ({double x, double y, double cam});

class FlightPainter extends CustomPainter {
  FlightPainter(this.stage) : super(repaint: stage);

  final FlightStage stage;
  static final GrainBatch _b = GrainBatch(10);
  final Map<int, EssenceField> _essence = {};

  /// How tall each stretch stands on the screen, for a screen [h] tall:
  /// the first short, so the first fork is in sight from the start.
  static double _height(List<FlightRoute> s, double h, int j) =>
      s.length > 1 ? h * 1.1 : (j == 0 ? h * 0.3 : h * 0.45);

  /// Where through a well's stretch the sling's loop begins and ends.
  static const double _loopIn = 0.3, _loopOut = 0.7;

  // Set at the top of each paint.
  double _w = 1;
  List<double> _heights = const [], _starts = const [];
  double _top = 0;

  /// A way's box in its stretch [y0]..[y1] (screen), on [side] (−1 left).
  Rect _wayRect(double side, double y0, double y1) {
    final cx = _w / 2 + side * _w * 0.26;
    return Rect.fromLTRB(
      cx - _w * 0.2,
      y1 + (y0 - y1) * 0.1,
      cx + _w * 0.2,
      y0 - (y0 - y1) * 0.12,
    );
  }

  /// Flyer [i]'s lane across the middle of the course, its spread.
  double _spread(int i) => (i - 1) * _w * 0.15;

  /// Where flyer [i] is drawn [dist] along its route.
  _At _at(int i, double dist) {
    final s = stage;
    final len = s.sim.lengths[i];
    final spread = _spread(i);
    if (dist >= len) {
      final y = _top + (dist - len) * 0.6;
      return (x: _w / 2 + spread, y: y, cam: y);
    }
    final (j, f) = s.where(i, dist);
    final st = s.course.stretches[j];
    final y0 = _starts[j], hh = _heights[j];
    if (st.length == 1) {
      final y = y0 + f * hh;
      return (x: _w / 2 + spread, y: y, cam: y);
    }
    final fi = s.course.forks.indexOf(j);
    final choice = s.sim.choices[i][fi];
    final side = choice == 0 ? -1.0 : 1.0;
    final out = _ease(f / 0.18) * _ease((1 - f) / 0.18);
    final lx = _w / 2 + side * _w * 0.26 * out + spread * (1 - out * 0.7);
    if (st[choice].kind != FlightKind.gravity) {
      final y = y0 + f * hh;
      return (x: lx, y: y, cam: y);
    }
    // A well: in up the side of it nearer the middle, once round its heart
    // (over the top, down the far side, back under), and flung out of the
    // top. Each of the three swings at its own distance.
    final cy = y0 + hh * 0.51;
    final well = min(_w * 0.4 * 0.68, hh * 0.78 * 0.42);
    final r = well * (0.4 + 0.14 * i);
    final inner = -side;
    if (f < _loopIn) {
      final y = y0 + (cy - y0) * f / _loopIn;
      return (x: lx + inner * r * _ease((f - 0.06) / 0.22), y: y, cam: y);
    }
    if (f > _loopOut) {
      final g = (f - _loopOut) / (1 - _loopOut);
      final y = cy + (y0 + hh - cy) * g;
      return (x: lx + inner * r * (1 - _ease(g / 0.7)), y: y, cam: y);
    }
    final u = (f - _loopIn) / (_loopOut - _loopIn);
    final a = pi - 2 * pi * u;
    return (x: lx - inner * r * cos(a), y: cy + r * sin(a), cam: cy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = stage;
    final w = size.width, h = size.height;
    _w = w;
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
    _heights = [
      for (var j = 0; j < stretches.length; j++) _height(stretches[j], h, j),
    ];
    final starts = <double>[];
    var acc = 0.0;
    for (final hh in _heights) {
      starts.add(acc);
      acc += hh;
    }
    _starts = starts;
    _top = acc;

    // The camera keeps the player low on the screen (so the way ahead
    // shows), following it eased along its own way.
    var follow = 0.0;
    const samples = 8;
    for (var q = 0; q < samples; q++) {
      follow += _at(s.player, max(0.0, s.d[s.player] - q * 24)).cam;
    }
    follow /= samples;
    final camY = max(0.0, follow - h * 0.22);
    double screenY(double wy) => h - (wy - camY) - h * 0.12;

    // Where each one is now, on screen.
    final now = [
      for (var i = 0; i < s.d.length; i++)
        () {
          final a = _at(i, s.d[i]);
          return Offset(a.x, screenY(a.y));
        }(),
    ];

    _haze(canvas, size, camY, t);
    _stars(canvas, size, camY, t);
    // Gates' near grains, drawn over the flyers.
    final veils = <(Rect, String, int, List<Offset>)>[];
    for (var j = 0; j < stretches.length; j++) {
      final y0 = screenY(_starts[j]), y1 = screenY(_starts[j] + _heights[j]);
      if (y0 < -60 || y1 > h + 60) continue;
      final st = stretches[j];
      if (st.length == 1) {
        _open(canvas, size, y0, y1, t, j, k);
        continue;
      }
      final fi = s.course.forks.indexOf(j);
      for (var q = 0; q < st.length; q++) {
        final way = _wayRect(q == 0 ? -1.0 : 1.0, y0, y1);
        final route = st[q];
        final gate = route.kind == FlightKind.gate;
        final parts = <Offset>[
          if (gate)
            for (var i = 0; i < s.d.length; i++)
              if (s.sim.choices[i][fi] == q &&
                  s.d[i] < s.sim.lengths[i] &&
                  s.where(i).$1 == j)
                now[i],
        ];
        paintFlightWay(
          canvas,
          way,
          route.kind,
          t,
          j * 7 + q,
          k: k,
          element: route.element,
          parts: parts,
          layer: gate ? 0 : null,
        );
        if (gate) veils.add((way, route.element!, j * 7 + q, parts));
      }
    }
    _gate(canvas, screenY(_top), w, t, k);

    // Wakes first, under everyone; then the three, the furthest back first.
    for (var i = 0; i < s.d.length; i++) {
      _wake(canvas, i, screenY, t, k);
    }
    final order = [for (var i = 0; i < s.d.length; i++) i]
      ..sort((a, b) => now[b].dy.compareTo(now[a].dy));
    for (final i in order) {
      _flyer(canvas, i, now[i], w, t);
    }
    for (final (way, element, seed, parts) in veils) {
      paintFlightWay(
        canvas,
        way,
        FlightKind.gate,
        t,
        seed,
        k: k,
        element: element,
        parts: parts,
        layer: 1,
      );
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

  /// Far off, a haze of nebulae that drifts by slower than the stars.
  void _haze(Canvas c, Size size, double camY, double t) {
    const cols = [Color(0xFF3A2A6E), Color(0xFF1E4A5E), Color(0xFF5A2A4E)];
    for (var q = 0; q < 4; q++) {
      final span = size.height * 2.4;
      final y =
          (hash01(q, 591) * span + camY * 0.12) % span - size.height * 0.6;
      final x =
          size.width * (q.isEven ? 0.1 : 0.9) +
          (hash01(q, 592) - 0.5) * size.width * 0.3 +
          sin(t * 0.05 + q) * 6;
      final r = size.width * (0.45 + 0.25 * hash01(q, 593));
      final col = cols[q % cols.length];
      c.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(x, y),
            r,
            [
              col.withValues(alpha: 0.24),
              col.withValues(alpha: 0.08),
              col.withValues(alpha: 0),
            ],
            const [0.0, 0.5, 1.0],
          ),
      );
    }
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

  /// Open space, from [y0] (its start, lower on screen) to [y1]: a faint
  /// current of dust up the middle, and rubble drifting by at either side.
  void _open(
    Canvas c,
    Size size,
    double y0,
    double y1,
    double t,
    int j,
    double k,
  ) {
    final w = size.width;
    _current(c, Rect.fromLTRB(w * 0.26, y1, w * 0.74, y0), t, j, k);
    final b = _b..clear();
    final dark = Paint()..color = const Color(0xFF0B0A08);
    for (var q = 0; q < 3; q++) {
      final left = (q + j).isEven;
      final hx = hash01(q, 711 + j);
      final x = left ? w * (0.03 + 0.14 * hx) : w * (0.83 + 0.14 * hx);
      final y = y1 + (y0 - y1) * (q + 0.25 + 0.5 * hash01(q, 712 + j)) / 3;
      final r = (5 + 9 * hash01(q, 713 + j)) * k;
      _rock(
        c,
        b,
        dark,
        Offset(x, y + sin(t * 0.2 + q) * 3 * k),
        r,
        t,
        q + j * 5,
        k,
        dust: 3,
      );
    }
    _drawRocks(c, b, k, 0.75);
  }

  /// Dust drifting up the course, faint: which way it goes.
  void _current(Canvas c, Rect band, double t, int seed, double k) {
    final b = _b..clear();
    final n = (band.height / (7 * k)).round();
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
    b.draw(c, 1, 1.1 * k, const Color(0xFFCDB07A).withValues(alpha: 0.14));
    b.draw(c, 0, 1.3 * k, const Color(0xFFE2C98F).withValues(alpha: 0.3));
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

  /// How hard flyer [i] is flung at [dist]: the run-out after a well on
  /// the Gravity Chain, its fling (0..1 of the most), fading as it goes.
  double _flung(int i, double dist) {
    final s = stage;
    if (!s.course.chain || dist >= s.sim.lengths[i]) return 0;
    final legs = s.sim.legs[i];
    final (j, f) = s.where(i, dist);
    final fling = legs.flings[j];
    if (fling <= 1 || legs.ways[j].kind == FlightKind.gravity) return 0;
    return ((fling - 1) / 0.32).clamp(0.0, 1.0) * (1 - _ease(f * 1.15));
  }

  /// A flyer's wake: grains along the way it has just come, loosening and
  /// going out behind it; longer and brighter on a surge, or flung out of a
  /// well.
  void _wake(
    Canvas c,
    int i,
    double Function(double) screenY,
    double t,
    double k,
  ) {
    final s = stage;
    final flung = _flung(i, s.d[i]);
    // Flung out of a well, its wake carries the well's light.
    final col = Color.lerp(
      elementColor(s.elementAt(i, s.d[i])),
      const Color(0xFFB9A8FF),
      flung * 0.7,
    )!;
    // Eased in as a surge starts (after the wind-up), out once it is done.
    const windup = kRaceBoostWindupTicks / kRaceTickRate;
    const surge = kRaceBoostSurgeTicks / kRaceTickRate;
    final since = s.boostAtClock[i] == null ? 99.0 : t - s.boostAtClock[i]!;
    final boost =
        _ease((since - windup) / 0.3) *
        (1 - _ease((since - windup - surge) / 0.6));
    final heat = max(boost, flung);
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
      final a = _at(i, at);
      final p = Offset(a.x, screenY(a.y));
      final age = q / n;
      for (var g = 0; g < 4; g++) {
        final h1 = hash01(q * 4 + g, 681 + i), h2 = hash01(q * 4 + g, 682);
        final drift = (h1 - 0.5) * (8 + 30 * age) * k;
        final rise = (h2 - 0.3) * 10 * age * k;
        b.add(age < 0.25 ? 0 : (age < 0.6 ? 1 : 2), p.dx + drift, p.dy + rise);
      }
    }
    // Flung: the well's grains thrown out after it, thick at first.
    if (flung > 0.02) {
      const m = 44;
      for (var q = 1; q <= m; q++) {
        final at = s.d[i] - q * 4;
        if (at < 0) break;
        final a = _at(i, at);
        final age = q / m;
        if (age > 0.3 + flung) break;
        for (var g = 0; g < 6; g++) {
          final h1 = hash01(q * 6 + g, 685 + i), h2 = hash01(q * 6 + g, 686);
          b.add(
            age < 0.25 ? 3 : 4,
            a.x + (h1 - 0.5) * (10 + 26 * age) * k,
            screenY(a.y) + (h2 - 0.5) * (4 + 14 * age) * k,
          );
        }
      }
    }
    final hot = Color.lerp(col, Colors.white, 0.5)!;
    final a = intro * (0.45 + 0.55 * heat);
    b.draw(c, 4, 1.4 * k, const Color(0xFF9A84FF).withValues(alpha: 0.6));
    b.draw(c, 3, 1.9 * k, const Color(0xFFEDE8FF).withValues(alpha: 0.9));
    b.draw(c, 2, 1.1 * k, col.withValues(alpha: 0.14 * a));
    b.draw(c, 1, 1.3 * k, col.withValues(alpha: 0.32 * a));
    b.draw(c, 0, 1.6 * k, hot.withValues(alpha: 0.55 * a));
    // On a surge or a fling, a streak of its light stretched out behind —
    // where the way behind it runs straight (not round a well).
    if (heat > 0.02) {
      final head = _at(i, s.d[i]);
      final back = _at(i, max(0.0, s.d[i] - 70));
      final mid = _at(i, max(0.0, s.d[i] - 35));
      final h0 = Offset(head.x, screenY(head.y));
      final b0 = Offset(back.x, screenY(back.y));
      final m0 = Offset(mid.x, screenY(mid.y));
      final bend = (m0 - (h0 + b0) / 2).distance;
      final len = (h0 - b0).distance;
      if (bend < 0.08 * len + 2) {
        paintLightStreak(
          c,
          h0,
          b0,
          8 * k,
          flung > boost ? const Color(0xFFB9A8FF) : col,
          heat * _ease((0.08 * len + 2 - bend) / (0.04 * len + 1)),
        );
      }
    }
  }

  void _flyer(Canvas c, int i, Offset at, double w, double t) {
    final s = stage;
    final dist = s.d[i];
    final element = s.elementAt(i, dist);
    final body = s.bodyFor(i, element);
    final col = elementColor(element);
    final k = w / 475 * 1.9;
    final st = s.sim.states[i];
    // Coming in from below in the intro.
    var p = at;
    if (s.clock < FlightStage.introSeconds) {
      final e = _ease(s.clock / FlightStage.introSeconds);
      p = p.translate(0, (1 - e) * 240);
    }
    p = p.translate(0, sin(t * 2.2 + i) * 2.5);
    // Leaning into its way, and turned to face it round a well.
    final here = _at(i, dist), back = _at(i, max(0.0, dist - 6));
    final vx = here.x - back.x, vy = here.y - back.y;
    var lean = -0.25;
    var faceRight = true;
    if (vx.abs() + vy.abs() > 0.5) {
      lean = (-0.25 + atan2(vx, vy.abs() + 0.001) * 0.25).clamp(-0.7, 0.4);
      if (vx < -1 && vx < -2 * vy.abs()) {
        faceRight = false;
        lean = -lean;
      }
    }
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
    final flung = _flung(i, dist);
    swell = max(swell, flung);
    final glowR = (18 + 10 * swell) * k;
    final glow = Color.lerp(
      i == s.player ? const Color(0xFFE2C98F) : col,
      const Color(0xFFB9A8FF),
      flung,
    )!;
    c.drawCircle(
      p,
      glowR,
      Paint()
        ..shader = ui.Gradient.radial(p, glowR, [
          glow.withValues(alpha: (i == s.player ? 0.16 : 0.06) + 0.22 * swell),
          glow.withValues(alpha: 0),
        ]),
    );

    // Through a gate with a recipe: it comes apart into what it makes and
    // gathers again — as that, once it has changed.
    var alpha = 1.0;
    final legs = s.sim.legs[i];
    if (dist < s.sim.lengths[i]) {
      final (j, f) = s.where(i, dist);
      final made = legs.made[j];
      final et = made == null ? null : FlightStage.fusionTime(f);
      if (made != null && et != null) {
        final before = s.bodyFor(i, legs.elements[j]);
        final after = s.bodyFor(i, legs.elements[j + 1]);
        final changes = !identical(before, after) && after.grains != null;
        final out = before.grains == null
            ? null
            : _essence.putIfAbsent(
                i * 64 + j,
                () =>
                    EssenceField(before.grains!, EssenceElement.of(made))
                      ..leaveAt = changes ? FlightStage.handOver : null,
              );
        final into = !changes
            ? null
            : _essence.putIfAbsent(
                i * 64 + j + 32,
                () =>
                    EssenceField(after.grains!, EssenceElement.of(made))
                      ..reveal = true,
              );
        if (out != null) alpha = EssenceField.spriteOpacity(et);
        c.save();
        c.translate(p.dx, p.dy);
        c.scale(k);
        out?.paint(c, Offset.zero, et);
        into?.paint(c, Offset.zero, et);
        c.restore();
      }
    }
    if (alpha > 0.01) {
      paintRaceBody(
        c,
        body,
        p,
        k,
        t,
        alpha: alpha,
        lean: lean,
        faceRight: faceRight,
      );
    }
  }

  @override
  bool shouldRepaint(FlightPainter old) => old.stage != stage;
}
