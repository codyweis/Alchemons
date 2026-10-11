// lib/screens/athanor/athanor_field.dart
//
// The Athanor's screen field, as plain Dart: the furnace, how it burns
// from moment to moment, and the two streams a pour is made of — tincture
// (or gold) pouring down into the flue at the furnace's crown, and later
// rising out of it toward the piece it becomes. Stepped by the screen's one
// ticker; painted under the page.
//
// Every change eases: the furnace settles lower for a pour and back, the
// fire swells to a roar and banks, the stone warms through and cools, the
// crown takes the poured color and gives it back. Streams are grains with
// short trails, so a path reads as a current. No blur.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/screens/athanor/athanor_furnace.dart';
import 'package:alchemons/screens/athanor/athanor_tone.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart' show GrainBatch;
import 'package:alchemons/widgets/fx/grain_glass.dart';
import 'package:flutter/material.dart';

double _clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);
double _smooth(double x) {
  final t = _clamp01(x);
  return t * t * (3 - 2 * t);
}

double _easeInOut(double x) {
  final t = _clamp01(x);
  return t < 0.5 ? 2 * t * t : 1 - math.pow(-2 * t + 2, 2) / 2;
}

/// A value that glides from where it is to where it is sent, over a time
/// of its own, eased at both ends.
class _Glide {
  _Glide(this.value) : _from = value, _to = value;

  double value;
  double _from, _to;
  double _t = 1, _len = 1;

  double get target => _to;

  void to(double v, double seconds) {
    if (v == _to && _t >= 1) return;
    _from = value;
    _to = v;
    _t = 0;
    _len = math.max(0.01, seconds);
  }

  void step(double dt) {
    if (_t >= 1) return;
    _t = math.min(1, _t + dt / _len);
    value = _from + (_to - _from) * _smooth(_t);
  }
}

/// One stream of grains, from a point to a point, each grain on its own
/// bowed path, born over a while.
class _Stream {
  _Stream({
    required this.born,
    required this.color,
    required this.count,
    required this.over,
    required this.flight,
    required this.from,
    required this.to,
    required this.salt,
    this.rising = false,
    this.spread = 0,
    this.source = 10,
  });

  final double born;
  final Color color;
  final int count;

  /// Seconds over which its grains set out, and each one's flight.
  final double over, flight;

  /// Where it leaves from and lands, asked as it is drawn (the furnace
  /// moves under it).
  final Offset Function() from, to;
  final int salt;

  /// Out of the flue, spreading into a cloud [spread] across at its end.
  final bool rising;
  final double spread;

  /// How wide the band a pour leaves from is.
  final double source;

  double get end => born + over + flight * 1.3;
}

class AthanorField {
  AthanorField({this.time = 0, bool lit = false})
    : _fire = _Glide(lit ? 1 : 0.3);

  /// Seconds; started from the shared glyph clock so the furnace stands
  /// exactly as the passage that grew it left it.
  double time;

  /// Time runs this much faster while a pour is being skipped through.
  double speed = 1;

  final _Glide _focus = _Glide(0);
  final _Glide _fire;
  final _Glide _heat = _Glide(0);

  /// How much of the crown's light is the poured color, and whether that
  /// is gold.
  final _Glide _tint = _Glide(0);
  final _Glide _gold = _Glide(0);

  final List<_Stream> _streams = [];

  /// The fire it banks to when nothing is being poured: lit while a free
  /// pour waits.
  void restFire(bool lit, {double seconds = 1.2}) =>
      _fire.to(lit ? 1 : 0.3, seconds);

  /// How far the furnace has settled into its working place, 0..1.
  double get focus => _focus.value;

  void focusTo(double v, {double seconds = 0.9}) => _focus.to(v, seconds);
  void fireTo(double v, {double seconds = 0.8}) => _fire.to(v, seconds);
  void heatTo(double v, {double seconds = 0.8}) => _heat.to(v, seconds);

  /// The crown taking on the poured color (1) or giving it back (0);
  /// [gold] for a gold pour's.
  void tintTo(double v, {bool? gold, double seconds = 1.2}) {
    _tint.to(v, seconds);
    if (gold != null) _gold.to(gold ? 1 : 0, 0.01);
  }

  bool get busy => _streams.isNotEmpty;

  /// Pours [count] grains of [color] from [from] into the flue.
  void pour(
    AthanorLayout layout, {
    required Offset from,
    required Color color,
    int count = 140,
    double over = 1.0,
    double width = 14,
  }) {
    _streams.add(
      _Stream(
        born: time,
        color: color,
        count: count,
        over: over,
        flight: 0.85,
        from: () => from,
        to: () => geo(layout).ventTop,
        salt: _streams.length + 3,
        source: width,
      ),
    );
  }

  /// Lifts [count] grains of [color] out of the flue to a cloud round [to].
  void rise(
    AthanorLayout layout, {
    required Offset to,
    required double spread,
    required Color color,
    int count = 150,
    double over = 0.9,
  }) {
    _streams.add(
      _Stream(
        born: time,
        color: color,
        count: count,
        over: over,
        flight: 1.0,
        from: () => geo(layout).ventTop,
        to: () => to,
        salt: _streams.length + 11,
        rising: true,
        spread: spread,
      ),
    );
  }

  void step(double dt) {
    final d = dt * speed;
    time += d;
    for (final g in [_focus, _fire, _heat, _tint, _gold]) {
      g.step(d);
    }
    _streams.removeWhere((s) => time > s.end);
  }

  AthanorFurnaceGeo geo(AthanorLayout l) =>
      AthanorFurnaceGeo.lerp(l.rest, l.working, _focus.value);

  AthanorBurn get burn => AthanorBurn(
    fire: _fire.value,
    heat: _heat.value,
    glow: Color.lerp(
      AthanorTone.ember,
      Color.lerp(AthanorTone.tincture, AthanorTone.gold, _gold.value),
      _tint.value,
    )!,
  );

  // Buckets per stream color: glow, trail, head — two colors at most.
  final GrainBatch _b = GrainBatch(6);

  void paint(Canvas canvas, AthanorLayout layout) {
    final g = geo(layout);
    final burn = this.burn;
    paintAthanorFurnace(canvas, g, time, burn, front: false);
    // The pour goes into the flue, under its opening.
    _paintStreams(canvas, g, rising: false);
    paintAthanorFurnace(canvas, g, time, burn, back: false);
    _paintStreams(canvas, g, rising: true);
  }

  void _paintStreams(
    Canvas canvas,
    AthanorFurnaceGeo g, {
    required bool rising,
  }) {
    final b = _b..clear();
    final colors = <Color>[];
    for (final s in _streams) {
      if (s.rising != rising) continue;
      var ci = colors.indexOf(s.color);
      if (ci < 0) {
        if (colors.length >= 2) continue;
        colors.add(s.color);
        ci = colors.length - 1;
      }
      final from = s.from(), to = s.to();
      final span = to - from;
      final len = math.max(1.0, span.distance);
      final perp = Offset(-span.dy, span.dx) / len;
      for (var i = 0; i < s.count; i++) {
        final h0 = GrainGlass.h(i, s.salt);
        final h1 = GrainGlass.h(i, s.salt + 40);
        final h2 = GrainGlass.h(i, s.salt + 80);
        final start = s.born + s.over * h0;
        final flight = s.flight * (0.8 + 0.4 * h1);
        final u = (time - start) / flight;
        if (u <= 0 || u >= 1.04) continue;
        // Leaving from a little round the source; a rising grain lands in
        // a filled cloud, not on one radius.
        final jitter = rising
            ? Offset((h1 - 0.5) * g.ventHalf * 1.6, 0)
            : Offset((h1 - 0.5) * s.source, (h2 - 0.5) * 8);
        final a = h2 * math.pi * 2;
        final land = rising
            ? Offset(math.cos(a), math.sin(a) * 0.8) *
                  s.spread *
                  math.sqrt(GrainGlass.h(i, s.salt + 120))
            : Offset((h2 - 0.5) * g.ventHalf * 1.2, 0);
        final p0 = from + jitter, p2 = to + land;
        // Bowed to one side, each its own way; a pour arcs up first.
        final bow = (h1 - 0.5) * len * (rising ? 0.22 : 0.1);
        final lift = rising ? 0.0 : -len * 0.22;
        final ctrl = (p0 + p2) / 2 + perp * bow + Offset(0, lift);
        for (var k = 0; k < 3; k++) {
          final e = rising
              ? 1 - math.pow(1 - _clamp01(u - k * 0.05), 2.2).toDouble()
              : _easeInOut(u - k * 0.05);
          if (k > 0 && e <= 0) break;
          final m = 1 - e;
          final x = m * m * p0.dx + 2 * m * e * ctrl.dx + e * e * p2.dx;
          final y = m * m * p0.dy + 2 * m * e * ctrl.dy + e * e * p2.dy;
          // A rising grain thins out as it reaches the cloud the piece
          // gathers from; a poured one is gone into the flue.
          if (rising &&
              u > 0.8 &&
              k == 0 &&
              GrainGlass.h(i, s.salt + 7) < (u - 0.8) * 4) {
            break;
          }
          if (!rising && u > 1) break;
          b.add(ci * 3 + (k == 0 ? 2 : 1), x, y);
          if (k == 0) b.add(ci * 3, x, y);
        }
      }
    }
    final d = (g.s * 0.011).clamp(1.5, 2.4);
    for (var c = 0; c < colors.length; c++) {
      final col = colors[c];
      final hot = Color.lerp(col, Colors.white, 0.45)!;
      b.draw(canvas, c * 3, d * 4.2, col.withValues(alpha: 0.09));
      b.draw(canvas, c * 3 + 1, d * 1.05, col.withValues(alpha: 0.5));
      b.draw(canvas, c * 3 + 2, d * 1.3, hot);
    }
  }
}

/// Paints an [AthanorField] at its clock.
class AthanorFieldPainter extends CustomPainter {
  AthanorFieldPainter(this.field, this.layout, {required super.repaint});

  final AthanorField field;
  final AthanorLayout layout;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          const [AthanorTone.void1, AthanorTone.void0],
        ),
    );
    field.paint(canvas, layout);
  }

  @override
  bool shouldRepaint(AthanorFieldPainter old) =>
      old.field != field ||
      old.layout.size != layout.size ||
      old.layout.pad != layout.pad;
}
