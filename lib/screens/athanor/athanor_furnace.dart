// lib/screens/athanor/athanor_furnace.dart
//
// THE ATHANOR in grains: a tower of dark bronze grains that rounds into a
// dome, a short flue at its crown, and the fire in its mouth. A pour goes
// in at the flue and what it makes rises out of it, so the crown is where
// the furnace breathes: its opening glows as the fire works, the stone
// round it warms, and sparks lift off it. One painter for every size it is
// shown at — home's emblem, the passage that grows it over the screen, and
// the screen's own field — so the way in ends as the screen's first thing,
// in its place.
//
// Lit grains in batches and radial gradients. No strokes, no blur.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/screens/athanor/athanor_tone.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart' show GrainBatch;
import 'package:alchemons/widgets/fx/grain_glass.dart';
import 'package:flutter/material.dart';

double _clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);
double _smooth(double e0, double e1, double x) {
  final t = _clamp01((x - e0) / (e1 - e0));
  return t * t * (3 - 2 * t);
}

// The furnace's shape, in units of its width at the foot, measured up from
// its floor.
const double _towerTop = 0.44; // straight walls give way to the dome
const double _domeTop = 0.77; // the dome's crown
const double _flueHalf = 0.085; // the flue's half width
const double _flueFoot = 0.7; // where the flue rises out of the dome
const double _ventUp = 0.88; // the flue's opening
const double _mouthHalf = 0.13, _mouthSpring = 0.14;

/// Where the furnace stands: the middle of its floor and its size (its
/// width at the foot). Everything else is measured from these.
class AthanorFurnaceGeo {
  const AthanorFurnaceGeo(this.base, this.s);

  /// The furnace fitted into [box] (the home emblem's), standing on its
  /// floor.
  factory AthanorFurnaceGeo.inBox(Rect box) {
    final s = math.min(box.width / 1.16, box.height / 1.12);
    return AthanorFurnaceGeo(Offset(box.center.dx, box.bottom - s * 0.07), s);
  }

  final Offset base;
  final double s;

  /// The flue's opening, where a pour goes in and what it makes comes out.
  double get ventTopY => base.dy - s * _ventUp;
  Offset get ventTop => Offset(base.dx, ventTopY);
  double get ventHalf => s * _flueHalf * 0.8;

  double get mouthHalf => s * _mouthHalf;
  Offset get mouthCentre => Offset(base.dx, base.dy - s * 0.11);

  /// Everything it draws, its light and the heat over its crown included.
  Rect get bounds => Rect.fromLTRB(
    base.dx - s * 0.62,
    ventTopY - s * 0.3,
    base.dx + s * 0.62,
    base.dy + s * 0.08,
  );

  static AthanorFurnaceGeo lerp(
    AthanorFurnaceGeo a,
    AthanorFurnaceGeo b,
    double t,
  ) => AthanorFurnaceGeo(
    Offset.lerp(a.base, b.base, t)!,
    ui.lerpDouble(a.s, b.s, t)!,
  );

  @override
  bool operator ==(Object other) =>
      other is AthanorFurnaceGeo && other.base == base && other.s == s;

  @override
  int get hashCode => Object.hash(base, s);
}

/// How the furnace is burning, for one frame.
class AthanorBurn {
  const AthanorBurn({
    this.fire = 0.3,
    this.heat = 0,
    this.alpha = 1,
    this.glow = AthanorTone.ember,
  });

  /// The fire in the mouth: 0.3 banked low, 1 lit (a free pour waiting),
  /// up to 1.6 roaring while a pour is worked.
  final double fire;

  /// The furnace worked hot, 0..1: the stone warms from inside, the crown
  /// glows and breathes sparks, the embers in the mouth stir.
  final double heat;

  /// The whole furnace's fade.
  final double alpha;

  /// The light the crown takes: the fire's, or what was poured into it.
  final Color glow;
}

/// Half the furnace's width at [up] (from its floor, in its units).
double _halfWidth(double up) {
  var w = up <= _towerTop
      ? 0.47 - 0.07 * (up / _towerTop)
      : 0.40 *
            math.sqrt(
              math.max(
                0.0,
                1 - math.pow((up - _towerTop) / (_domeTop - _towerTop), 2),
              ),
            );
  if (up < 0.045) w += 0.035 * (1 - up / 0.045);
  // The flue stands on the crown.
  if (up >= _flueFoot && up <= _ventUp) w = math.max(w, _flueHalf);
  return w;
}

/// The furnace's grains, laid out once in units of its size, from the
/// middle of its floor (y up is negative).
final class _Body {
  _Body() {
    final rng = math.Random(71);
    var k = 0;
    while (k < n) {
      final x = (rng.nextDouble() * 2 - 1) * 0.52;
      final up = rng.nextDouble() * _ventUp;
      final w = _halfWidth(up);
      if (x.abs() > w) continue;
      if (_inMouth(x, up)) continue;
      // Thin a little toward the edge, so the silhouette is soft.
      final edge = 1 - x.abs() / w;
      if (edge < 0.05 && rng.nextDouble() < 0.5) continue;
      final flue = up >= _flueFoot && x.abs() <= _flueHalf;
      this.x[k] = x;
      y[k] = -up;
      final nx = (x / w).clamp(-1.0, 1.0);
      final nz = math.sqrt(math.max(0.0, 1 - nx * nx));
      // The dome's face turns up toward the light as it rounds over.
      final dome = _smooth(_towerTop, _domeTop, up);
      final lam = -0.66 * nx + 0.68 * nz + 0.18 * dome;
      var b = 0.36 + 0.64 * lam;
      // Shade at the foot; the flue a shade darker than the dome it
      // stands on, so it reads as its own short stack.
      b *= 0.7 + 0.3 * _smooth(0, 0.2, up);
      if (flue) b *= 0.82;
      b += (rng.nextDouble() - 0.5) * 0.2;
      final lit = _clamp01(b);
      // Now and then a grain on the lit side catches it: brass, not sand.
      // The flue's lip catches it most.
      final lip = flue && up > _ventUp - 0.025;
      final glint =
          (lit > 0.7 && rng.nextDouble() < 0.05) ||
          (lip && rng.nextDouble() < 0.45);
      tone[k] = glint ? 8 : (math.pow(lit, 1.45) * 7.99).floor();
      // The fire's light on the stone round its mouth: strongest at the
      // jambs and the foot, thinning up the face, never a band.
      final dy = up - _mouthSpring;
      final d = dy > 0
          ? math.sqrt(x * x + dy * dy) - _mouthHalf
          : math.max(0.0, x.abs() - _mouthHalf);
      final near = _clamp01(1 - d / (0.3 - 0.12 * _smooth(0.1, 0.5, up)));
      warm[k] =
          near * near * (0.5 + 0.5 * nz) * (0.55 + 0.9 * rng.nextDouble());
      // Worked hot, the stone warms from inside: most on its face and low
      // down near the fire, unevenly, grain by grain.
      final r = rng.nextDouble();
      core[k] =
          math.pow(nz, 1.5) * (1 - 0.5 * up / _ventUp) * (0.2 + 0.8 * r * r);
      // The crown's light on the dome round the flue.
      final cx = x, cy = up - _ventUp;
      crown[k] = math
          .pow(_clamp01(1 - math.sqrt(cx * cx + cy * cy * 1.6) / 0.32), 1.4)
          .toDouble();
      ph[k] = rng.nextDouble();
      k++;
    }
  }

  static const int n = 4600;

  static bool _inMouth(double x, double up) {
    if (x.abs() >= _mouthHalf || up < 0.012) return false;
    if (up <= _mouthSpring) return true;
    final dy = up - _mouthSpring;
    return x * x + dy * dy < _mouthHalf * _mouthHalf;
  }

  final x = Float32List(n), y = Float32List(n);
  final tone = Uint8List(n);
  final warm = Float32List(n),
      core = Float32List(n),
      crown = Float32List(n),
      ph = Float32List(n);
}

final _Body _body = _Body();

/// The mouth's opening, in the furnace's units (shared by every size).
final Path _mouthUnit = () {
  const h = _mouthHalf;
  return Path()
    ..moveTo(-h, -0.012)
    ..lineTo(-h, -_mouthSpring)
    ..arcToPoint(
      const Offset(h, -_mouthSpring),
      radius: const Radius.circular(h),
      clockwise: true,
    )
    ..lineTo(h, -0.012)
    ..close();
}();

// Buckets: stone 8 + glint, firelit 4, crown-lit 2, coals 3, embers 2,
// sparks 2.
const int _stoneB = 0;
const int _warmB = 9, _crownB = 13, _coalB = 15, _emberB = 18, _sparkB = 20;
final GrainBatch _batch = GrainBatch(22);
final Paint _p = Paint();

const List<Color> _stone = [
  Color(0xFF09080A),
  Color(0xFF100E0D),
  Color(0xFF181512),
  Color(0xFF221D18),
  Color(0xFF2E261F),
  Color(0xFF3D3227),
  Color(0xFF524230),
  Color(0xFF6E583A),
  Color(0xFFB8975C),
];

/// The shadow side over a lit backdrop: dim, warm, never black.
const Color _shadeLifted = Color(0xFF3E2D21);

Color _a(Color c, double a) => c.withValues(alpha: _clamp01(c.a * a));

/// A flattened pool of light at [at].
void _pool(Canvas canvas, Offset at, double rx, double ry, List<Color> colors) {
  if (rx <= 0 || ry <= 0) return;
  _p.shader = ui.Gradient.radial(
    at,
    rx,
    colors,
    colors.length == 2 ? null : const [0.0, 0.45, 1.0],
  );
  canvas.save();
  canvas.translate(at.dx, at.dy);
  canvas.scale(1, ry / rx);
  canvas.translate(-at.dx, -at.dy);
  canvas.drawCircle(at, rx, _p);
  canvas.restore();
  _p.shader = null;
}

/// How many of the furnace's grains a furnace [s] across shows: about as
/// dense at every size.
int _grainsFor(double s) =>
    (_Body.n * math.pow(s / 240, 2)).round().clamp(1000, _Body.n);

/// Paints the furnace at [g] at [time] seconds.
///
/// [back] is the furnace itself (its light, shadow, stone, mouth and fire);
/// [front] is its crown's opening and the heat and sparks over it. A host
/// with something to draw between the two (a pour going into the flue)
/// paints them separately.
///
/// [shadow] is how deep the stone's shadow side goes, 0..1. On the screen's
/// dark it sinks to nothing; over home's lit realm (and the warm light the
/// emblem breathes while it teaches) grains darker than what is behind them
/// read as black specks, so there the shadow side is a dim warm brown.
void paintAthanorFurnace(
  Canvas canvas,
  AthanorFurnaceGeo g,
  double time,
  AthanorBurn burn, {
  bool back = true,
  bool front = true,
  double shadow = 1,
}) {
  final f = burn.alpha;
  if (f <= 0.01 || g.s <= 2) return;
  final s = g.s, bx = g.base.dx, by = g.base.dy;
  final fire = burn.fire;
  final fireK = _clamp01(fire);
  final heat = _clamp01(burn.heat);
  final t = time;
  final d = (s * 0.0088).clamp(1.45, 2.2);
  final b = _batch;
  final fc = AthanorTone.fire;
  final glow = burn.glow;

  if (back) {
    final body = _body;
    final count = _grainsFor(s);
    // ── its light on the dark round it, and its shadow ──
    _pool(canvas, Offset(bx, by - s * 0.42), s * 0.98, s * 0.98, [
      _a(
        Color.lerp(AthanorTone.brassDeep, fc[2], 0.4 * fireK + 0.3 * heat)!,
        (0.07 + 0.05 * fireK + 0.06 * heat) * f,
      ),
      Colors.transparent,
    ]);
    _pool(canvas, Offset(bx, by + s * 0.005), s * 0.56, s * 0.05, [
      Colors.black.withValues(alpha: 0.6 * f),
      Colors.transparent,
    ]);
    // The fire's light on the floor before the mouth.
    final roar = math.min(fire, 1.6);
    _pool(canvas, Offset(bx, by + s * 0.02), s * (0.62 + 0.1 * heat), s * 0.1, [
      _a(fc[3], 0.24 * roar * f),
      _a(fc[2], 0.08 * roar * f),
      Colors.transparent,
    ]);

    // ── the body ──
    b.clear();
    for (var i = 0; i < count; i++) {
      final x = bx + body.x[i] * s, y = by + body.y[i] * s;
      // Banked low, the fire barely reaches the stone; worked hot, the
      // stone warms through.
      final w = body.warm[i] * fire * fireK + body.core[i] * heat * 0.9;
      if (w > 0.12) {
        // Firelight flickers on the stone, grain by grain.
        final fl = w * (0.8 + 0.2 * math.sin(t * 6.3 + body.ph[i] * 31));
        if (fl > 0.12) {
          b.add(
            _warmB + (fl > 0.8 ? 3 : (fl > 0.5 ? 2 : (fl > 0.28 ? 1 : 0))),
            x,
            y,
          );
          continue;
        }
      }
      // The crown, lit from its own opening.
      final c = body.crown[i] * (0.32 * fireK + 0.9 * heat);
      if (c > 0.22) {
        b.add(_crownB + (c > 0.5 ? 1 : 0), x, y);
        continue;
      }
      b.add(_stoneB + body.tone[i], x, y);
    }
    final lift = 1 - _clamp01(shadow);
    for (var k = 0; k < 9; k++) {
      final c = k < 5 && lift > 0
          ? Color.lerp(_stone[k], _shadeLifted, lift * (1 - k / 6))!
          : _stone[k];
      b.draw(canvas, _stoneB + k, k == 8 ? d * 1.1 : d, _a(c, f));
    }
    b.draw(canvas, _warmB, d, _a(Color.lerp(_stone[5], fc[1], 0.45)!, f));
    b.draw(canvas, _warmB + 1, d, _a(Color.lerp(_stone[6], fc[1], 0.75)!, f));
    b.draw(canvas, _warmB + 2, d, _a(Color.lerp(fc[2], fc[1], 0.2)!, f));
    b.draw(canvas, _warmB + 3, d * 1.05, _a(Color.lerp(fc[3], fc[2], 0.3)!, f));
    b.draw(canvas, _crownB, d, _a(Color.lerp(_stone[6], glow, 0.5)!, f));
    b.draw(canvas, _crownB + 1, d, _a(Color.lerp(glow, _stone[8], 0.25)!, f));
    b.clear();

    // ── the mouth: the dark of the opening, and the fire in it ──
    canvas.save();
    canvas.translate(bx, by);
    canvas.scale(s);
    _p.color = _a(const Color(0xFF070302), f);
    canvas.drawPath(_mouthUnit, _p);
    final hot = math.min(fire, 1.6);
    // A pool of light on the coals, dark up under the arch: banked low it
    // is a red glow at the floor and nothing more; roaring, it fills it.
    final mid = Color.lerp(fc[1], fc[3], fireK)!;
    _p
      ..color = Colors.white
      ..shader = ui.Gradient.radial(
        const Offset(0, -0.005),
        0.25 + 0.05 * _clamp01(hot - 1),
        [
          _a(fc[5], 0.85 * _clamp01(hot - 0.5) * f),
          _a(fc[4], 0.85 * fireK * fireK * f),
          _a(mid, (0.14 + 0.66 * fireK * fireK) * f),
          _a(fc[1], (0.16 + 0.42 * fireK) * f),
          _a(fc[0], 0.0),
        ],
        const [0.0, 0.14, 0.36, 0.7, 1.0],
      );
    canvas.drawPath(_mouthUnit, _p);
    _p.shader = null;
    canvas.restore();

    // The coals on its floor, breathing; the embers lifting off them, and
    // stirring as the furnace is worked.
    final big = math.min(1.0, s / 120);
    final coalN = (26 * big).round().clamp(10, 26);
    for (var i = 0; i < coalN; i++) {
      final u = GrainGlass.h(i, 61) * 2 - 1;
      final mound = math.sqrt(math.max(0.0, 1 - u * u));
      final x = bx + u * s * 0.105;
      final y = by - s * (0.016 + 0.034 * mound * GrainGlass.h(i, 62));
      final breath =
          fire * (0.55 + 0.45 * math.sin(t * 2.1 + GrainGlass.h(i, 63) * 40));
      b.add(_coalB + (breath > 0.85 ? 2 : (breath > 0.45 ? 1 : 0)), x, y);
    }
    final emberN = ((18 * fireK + 30 * heat) * big).round();
    for (var i = 0; i < emberN; i++) {
      final period = (1.5 + 1.1 * GrainGlass.h(i, 64)) / (1 + 0.8 * heat);
      final p = ((t / period) + GrainGlass.h(i, 65)) % 1.0;
      if (p > 0.85) continue;
      // Rising off the coals; worked hot, carried round the mouth on the
      // draught, each its own way.
      final side = GrainGlass.h(i, 66) * 2 - 1;
      final x =
          bx +
          side * s * 0.08 +
          math.sin(t * (2.3 + 2.4 * heat) + i * 1.7 + p * 3) *
              s *
              (0.012 + 0.03 * heat);
      final y = by - s * (0.03 + (0.2 + 0.03 * heat) * p);
      b.add(_emberB + (p < 0.4 ? 1 : 0), x, y);
    }
    b.draw(canvas, _coalB, d * 1.1, _a(fc[2], f));
    b.draw(canvas, _coalB + 1, d * 1.15, _a(fc[3], f));
    b.draw(canvas, _coalB + 2, d * 1.2, _a(fc[4], f));
    b.draw(canvas, _emberB, d * 0.9, _a(fc[3], 0.7 * f));
    b.draw(canvas, _emberB + 1, d, _a(fc[5], 0.85 * f));
    b.clear();
  }

  if (front) {
    // ── the crown: the flue's opening, glowing as the fire works ──
    final v = g.ventTop;
    final vr = g.ventHalf;
    final breathe = 0.85 + 0.15 * math.sin(t * 1.9);
    final open = (0.3 * fireK + 0.85 * heat) * breathe;
    // The heat over it, a soft column of light lifting off the crown.
    _pool(canvas, v + Offset(0, -s * 0.06), s * (0.14 + 0.1 * heat), s * 0.16, [
      _a(glow, (0.05 + 0.16 * heat) * f),
      Colors.transparent,
    ]);
    // The opening, seen a little from above: a hollow, dark at rest and lit
    // from below as the fire works, its edge given by the flue's lip.
    canvas.save();
    canvas.translate(v.dx, v.dy);
    canvas.scale(1, 0.34);
    _p
      ..color = Colors.white
      ..shader = ui.Gradient.radial(
        Offset.zero,
        vr * 1.05,
        [
          _a(const Color(0xFF060302), 0.95 * f),
          _a(const Color(0xFF060302), 0.7 * f),
          _a(const Color(0xFF060302), 0),
        ],
        const [0.0, 0.6, 1.0],
      );
    canvas.drawCircle(Offset.zero, vr * 1.05, _p);
    if (open > 0.02) {
      final o = _clamp01(open);
      _p.shader = ui.Gradient.radial(
        Offset.zero,
        vr,
        [
          _a(Color.lerp(glow, Colors.white, 0.4)!, 0.7 * o * f),
          _a(glow, 0.45 * o * f),
          _a(glow, 0),
        ],
        const [0.0, 0.45, 1.0],
      );
      canvas.drawCircle(Offset.zero, vr, _p);
    }
    _p.shader = null;
    canvas.restore();

    // Sparks lifting off it: a few at rest, more and brighter worked hot.
    final sparkN =
        ((10 * (0.5 + 0.5 * fireK) + 24 * heat) * math.min(1.0, s / 140))
            .round();
    for (var i = 0; i < sparkN; i++) {
      final period = (3.2 + 2.2 * GrainGlass.h(i, 71)) / (1 + 1.2 * heat);
      final p = ((t / period) + GrainGlass.h(i, 72)) % 1.0;
      if (p < 0.04 || p > 0.88) continue;
      final side = GrainGlass.h(i, 74) - 0.5;
      final x =
          v.dx +
          side * vr * 1.4 +
          math.sin(t * 0.7 + GrainGlass.h(i, 73) * 9 + p * 3) * s * 0.07 * p +
          side * s * 0.12 * p;
      final y = v.dy - p * s * (0.34 + 0.12 * heat);
      b.add(_sparkB + (GrainGlass.h(i, 75) > 0.7 - 0.3 * heat ? 1 : 0), x, y);
    }
    b.draw(
      canvas,
      _sparkB,
      d * 0.85,
      _a(Color.lerp(glow, AthanorTone.brass, 0.5)!, (0.35 + 0.2 * heat) * f),
    );
    b.draw(
      canvas,
      _sparkB + 1,
      d,
      _a(Color.lerp(glow, Colors.white, 0.4)!, (0.45 + 0.3 * heat) * f),
    );
    b.clear();
  }
}

/// The screen's layout, shared with the passage that lands on it.
class AthanorLayout {
  AthanorLayout(this.size, this.pad);

  final Size size;
  final EdgeInsets pad;

  static const double headerH = 62;

  /// The panel under the field: the batch, its pieces and the buttons.
  static const double panelBody = 384;
  double get panelH => panelBody + pad.bottom;
  double get panelTop => size.height - panelH;
  double get fieldTop => pad.top + headerH;

  /// The furnace at rest, standing on the top of the panel, with room over
  /// its crown for the heat it breathes.
  AthanorFurnaceGeo get rest {
    final floor = panelTop - 4;
    final room = math.max(120.0, floor - fieldTop);
    final s = math.min(size.width * 0.62, room / 1.18);
    return AthanorFurnaceGeo(Offset(size.width / 2, floor), s);
  }

  /// The furnace while a pour is worked: lower, with the screen above it
  /// left for what the pour gives.
  AthanorFurnaceGeo get working {
    final r = rest;
    final s = r.s * 0.82;
    final floor = math.min(
      size.height - pad.bottom - 90,
      r.base.dy + panelH * 0.5,
    );
    return AthanorFurnaceGeo(Offset(size.width / 2, floor), s);
  }

  /// Where the drawn piece settles: well over the crown, with room under
  /// it for its name.
  Offset get pieceAt {
    final top = fieldTop + 8;
    final bottom = working.ventTopY - working.s * 0.3;
    return Offset(size.width / 2, top + (bottom - top) * 0.4);
  }

  double get pieceBox =>
      math.min(size.width * 0.44, (working.ventTopY - fieldTop) * 0.48);
}
