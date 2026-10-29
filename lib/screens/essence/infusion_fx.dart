// lib/screens/essence/infusion_fx.dart
//
// The vial stand's alchemy, in grains (the game's one language for alchemy:
// lit grains in motion, flowing, never lines, hoops or bursts). Plain Dart,
// scrubbed by the shared clock's seconds, drawn blur-free in batches:
//
//   PourFx      essence leaves the store (the count in the header) in three
//               lopsided currents, bowing and curling, and winds into the
//               vial, each grain fading as the sphere takes it
//   WordFormFx  what came up: grains leave the vial and settle into the
//               letters of each pick, letter by letter, shimmer, and give way
//               to the card's own text where they settled
//   WordFlowFx  a pick taken: its letters loosen and run into the ladder's
//               slot; a pick passed over drifts back into the vial

import 'dart:math' as math;
import 'dart:ui';

import 'package:alchemons/games/planet_dungeon/blood_heart_fx.dart'
    show HeartWord;
import 'package:alchemons/widgets/fx/fusion_particles.dart' show GrainBatch;

double _h(int i, int salt) {
  final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

double _sm(double e0, double e1, double x) {
  final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double _easeInOut(double x) =>
    x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3) / 2;

/// A slow, smooth sideways wander, so paths read as currents.
Offset _curl(double x, double y, double t, double s) => Offset(
  math.sin(y * 0.031 + t * 1.3 + s),
  math.cos(x * 0.027 - t * 1.1 + s * 1.7),
);

Offset _bezier(Offset a, Offset c, Offset b, double t) {
  final u = 1 - t;
  return a * (u * u) + c * (2 * u * t) + b * (t * t);
}

/// Grains by shade and by how faded they are, drawn as point batches.
///
/// [shades] are eight colours: two elements' ramps (shadow, body, lit,
/// glint). A grain's alpha is quantised into four levels, so a whole
/// infusion is at most 32 draws however many grains are in flight.
class InfusionBatch {
  InfusionBatch(this.shades) : assert(shades.length == 8);

  final List<Color> shades;
  static const List<double> _levels = [1.0, 0.62, 0.36, 0.16];
  static const List<double> _sizes = [2.3, 2.1, 1.9, 1.7];
  final GrainBatch _b = GrainBatch(32);

  void clear() => _b.clear();

  /// A grain of shade [s] (0..7) at alpha [a].
  void add(int s, double a, Offset p) {
    if (a <= 0.08) return;
    final level = a > 0.8
        ? 0
        : a > 0.5
        ? 1
        : a > 0.26
        ? 2
        : 3;
    _b.add(s * 4 + level, p.dx, p.dy);
  }

  void paint(Canvas canvas) {
    for (var s = 0; s < 8; s++) {
      final c = shades[s];
      for (var l = 0; l < 4; l++) {
        _b.draw(
          canvas,
          s * 4 + l,
          _sizes[s % 4],
          c.withValues(alpha: c.a * _levels[l]),
        );
      }
    }
  }
}

/// A shade for grain [i]: mostly body and lit, from either ramp, the odd
/// one a glint.
int _shade(int i, int salt) {
  final ramp = _h(i, salt) < 0.5 ? 0 : 4;
  final r = _h(i, salt + 1);
  return ramp + (r > 0.94 ? 3 : (r > 0.55 ? 2 : (r > 0.18 ? 1 : 0)));
}

// ── the pour ────────────────────────────────────────────────────────────────

class PourFx {
  PourFx({
    required this.from,
    required this.to,
    required this.radius,
    required this.start,
    this.count = 360,
    this.span = 1.2,
  });

  /// Where the essence leaves (the store), and the vial's centre and size.
  final Offset from, to;
  final double radius;
  final double start;
  final int count;

  /// Over how long grains leave the store.
  final double span;

  static const double travel = 0.7;

  double get end => start + span + travel * 1.2;
  bool done(double now) => now >= end;

  /// How much of the pour the vial has taken (0..1), for its swell and light.
  double taken(double now) =>
      _sm(start + travel * 0.7, start + span + travel * 1.1, now);

  /// Three currents, each bowing its own way, so the pour is lopsided.
  static const List<double> _bows = [0.42, -0.18, 0.7];

  Offset _at(int i, double u, double now) {
    final cur = i % 3;
    final h1 = _h(i, 1), h2 = _h(i, 2), h3 = _h(i, 3);
    final s = from + Offset((h1 - 0.5) * 14, (h2 - 0.5) * 10);
    // Each lands somewhere in the vial, a little off its middle.
    final a = h3 * math.pi * 2;
    final end = to + Offset(math.cos(a), math.sin(a)) * radius * 0.55 * h2;
    final mid = Offset.lerp(s, end, 0.5)!;
    final d = end - s;
    final n = Offset(-d.dy, d.dx);
    final ctrl = mid + n * (_bows[cur] + (h1 - 0.5) * 0.18);
    final e = _easeInOut(u.clamp(0.0, 1.0));
    final p = _bezier(s, ctrl, end, e);
    // A wander along the way, none at either end.
    final w = _curl(p.dx, p.dy, now, h1 * 6) * (7 * math.sin(math.pi * e));
    // The last stretch winds round the vial's middle as it is taken.
    if (e > 0.72) {
      final k = (e - 0.72) / 0.28;
      final ang = k * 1.6 * (cur == 1 ? -1 : 1);
      final rel = p - to;
      final cs = math.cos(ang), sn = math.sin(ang);
      return to +
          Offset(rel.dx * cs - rel.dy * sn, rel.dx * sn + rel.dy * cs) +
          w * (1 - k);
    }
    return p + w;
  }

  void paint(InfusionBatch b, double now) {
    if (now < start || now > end) return;
    for (var i = 0; i < count; i++) {
      final birth = start + span * math.pow(i / count, 0.85) + 0.05 * _h(i, 4);
      final tr = travel * (0.85 + 0.3 * _h(i, 5));
      final u = (now - birth) / tr;
      if (u < 0 || u > 1.1) continue;
      final a =
          _sm(0, 0.12, u) * (1 - _sm(0.82, 1.1, u)) * (0.75 + 0.25 * _h(i, 6));
      final s = _shade(i, 7);
      b.add(s, a, _at(i, u, now));
      // A short trail, so the path reads as a current.
      b.add(s, a * 0.5, _at(i, u - 0.04, now - 0.03));
      b.add(s, a * 0.24, _at(i, u - 0.08, now - 0.06));
    }
  }
}

// ── a pick, forming ─────────────────────────────────────────────────────────

class WordFormFx {
  WordFormFx({
    required this.word,
    required this.sphere,
    required this.radius,
    required this.at,
    required this.start,
    this.salt = 0,
  });

  final HeartWord word;
  final Offset sphere;
  final double radius;

  /// Where the word's text begins (its left edge, at its middle height).
  final Offset at;
  final double start;
  final int salt;

  static const double leave = 0.5, gather = 0.85;

  /// When the card's own text comes in where the grains settled.
  double get textIn => start + leave + gather + 0.15;
  double get end => textIn + 0.6;
  bool done(double now) => now >= end;

  /// How far the card's text is in (0..1).
  double textShown(double now) => _sm(textIn, textIn + 0.4, now);

  Offset _home(int i) => at + Offset(word.width / 2 + word.x[i], word.y[i]);

  void paint(InfusionBatch b, double now) {
    if (now < start || now > end) return;
    final n = word.letters;
    final out = 1 - _sm(textIn + 0.05, textIn + 0.5, now);
    for (var i = 0; i < word.length; i++) {
      final l = word.letter[i];
      final h = _h(i + salt * 977, 11);
      final go = start + leave * l / n + 0.12 * h;
      final u = (now - go) / gather;
      if (u < 0) continue;
      final home = _home(i);
      Offset p;
      if (u < 1) {
        final e = 1 - math.pow(1 - u, 3).toDouble();
        final a = _h(i + salt * 977, 12) * math.pi * 2;
        final s =
            sphere +
            Offset(math.cos(a), math.sin(a)) *
                radius *
                0.7 *
                math.sqrt(_h(i + salt * 977, 13));
        final base = Offset.lerp(s, home, e)!;
        // Bowed to one side (each pick its own way), wandering a little.
        final bow =
            Offset((salt.isEven ? -1 : 1) * 26, -10) * math.sin(math.pi * e);
        final w =
            _curl(base.dx, base.dy, now, h * 6) * (6 * math.sin(math.pi * e));
        p = base + bow + w;
      } else {
        // Settled, breathing a little.
        p = home + Offset(0, math.sin(now * 2.2 + i * 0.7) * 0.5);
      }
      final a = _sm(0, 0.15, u) * out;
      final s = _shade(i + salt * 977, 14);
      b.add(s, a, p);
      if (u < 1) b.add(s, a * 0.4, p - (home - p) * 0.04);
    }
  }
}

// ── a pick, flowing on ──────────────────────────────────────────────────────

class WordFlowFx {
  WordFlowFx({
    required this.word,
    required this.at,
    required this.to,
    required this.spread,
    required this.start,
    this.bowSide = 1,
    this.salt = 0,
  });

  final HeartWord word;

  /// Where the word's text began (left edge, middle height).
  final Offset at;

  /// Where it runs to, and how wide it gathers there.
  final Offset to;
  final double spread;
  final double start;
  final double bowSide;
  final int salt;

  static const double loosen = 0.3, travel = 0.65;
  double get end => start + loosen + travel + 0.15;
  bool done(double now) => now >= end;

  /// How much has arrived (0..1), for what it lands in to light.
  double arrived(double now) => _sm(start + loosen + travel * 0.5, end, now);

  void paint(InfusionBatch b, double now) {
    if (now < start || now > end) return;
    final n = word.letters;
    for (var i = 0; i < word.length; i++) {
      final l = word.letter[i];
      final h = _h(i + salt * 613, 21);
      final go = start + loosen * l / n + 0.08 * h;
      final u = ((now - go) / travel).clamp(0.0, 1.0);
      final home = at + Offset(word.width / 2 + word.x[i], word.y[i]);
      final a2 = _h(i + salt * 613, 22) * math.pi * 2;
      final end =
          to +
          Offset(math.cos(a2), math.sin(a2)) *
              spread *
              math.sqrt(_h(i + salt * 613, 23));
      final e = _easeInOut(u);
      final d = end - home;
      final bow =
          Offset(-d.dy, d.dx) * (0.22 * bowSide) * math.sin(math.pi * e);
      final base = Offset.lerp(home, end, e)!;
      final w =
          _curl(base.dx, base.dy, now, h * 5) * (5 * math.sin(math.pi * e));
      final p = base + bow + w;
      final a = 1 - _sm(0.72, 1.0, u);
      final s = _shade(i + salt * 613, 24);
      b.add(s, a, p);
      if (u > 0 && u < 1) {
        b.add(s, a * 0.45, p - d * 0.035);
      }
    }
  }
}
