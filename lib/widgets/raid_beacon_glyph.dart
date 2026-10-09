import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/fusion_particles.dart' show GrainBatch;
import 'package:alchemons/widgets/fx/grain_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The Raid Beacon: an obsidian spire planted in its own light, lit from
/// inside, sending a column of grains up off its tip — and, late in each
/// call, a few grains drawn back in to it from the dark. The call and the
/// answer.
///
/// Near-black stone whose color comes only from the light in and round it,
/// and grains for the signal — the same material as the stations and the
/// power orbs. The old beacon was a pink outlined shard inside stroked
/// rings.
class RaidBeaconGlyph extends StatelessWidget {
  const RaidBeaconGlyph({super.key, required this.size, this.animate = true});

  final double size;

  /// Off for a still frame; a shop card scrolling past does not need to run.
  final bool animate;

  // On the shop glyphs' shared clock, let go of while TickerMode is off.
  @override
  Widget build(BuildContext context) => GrainGlyph(
    size: size,
    animate: animate,
    painter: (clock) => _RaidBeaconPainter(clock: clock),
  );
}

class _RaidBeaconPainter extends CustomPainter {
  _RaidBeaconPainter({required this.clock}) : super(repaint: clock);

  final ValueListenable<double>? clock;

  @override
  void paint(Canvas canvas, Size size) => _BeaconPaint.paint(
    canvas,
    size.center(Offset.zero),
    size.shortestSide,
    // A still beacon is caught mid-call, with its column up and a pulse
    // on the way; a running one starts from that same frame.
    (clock?.value ?? 0) + _BeaconPaint.stillTime,
  );

  @override
  bool shouldRepaint(covariant _RaidBeaconPainter old) => old.clock != clock;
}

/// Paints the beacon in a unit box (1 = the glyph's size, origin at its
/// centre) through one scale, so its stone, shaders and grain layout are
/// built once for every size. No strokes, no blur, no layers.
abstract final class _BeaconPaint {
  static const double stillTime = 0.78;

  /// One call: a pulse running up the column, then the answer coming in.
  static const double _period = 2.6;

  static const Color _ink = Color(0xFF070408);
  static const Color _signal = Color(0xFFFF3D71);
  static const Color _hot = Color(0xFFFFD9E4);
  static final Color _lit = Color.lerp(_signal, Colors.white, 0.35)!;

  // ── the stone ──
  // The spire, leaning a little right, and two smaller stones at its foot —
  // a planted cluster, lopsided, not a badge.
  static const Offset _tip = Offset(0.03, -0.13);
  static const Offset _foot = Offset(0.01, 0.4);
  static const double _ground = 0.39;

  static Path _poly(List<Offset> pts) {
    final p = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (final q in pts.skip(1)) {
      p.lineTo(q.dx, q.dy);
    }
    return p..close();
  }

  static final Path _spireLeft = _poly(const [
    _tip,
    Offset(-0.125, 0.05),
    Offset(-0.105, 0.345),
    _foot,
  ]);
  static final Path _spireRight = _poly(const [
    _tip,
    Offset(0.14, 0.03),
    Offset(0.115, 0.34),
    _foot,
  ]);
  static final Path _spire = _poly(const [
    _tip,
    Offset(0.14, 0.03),
    Offset(0.115, 0.34),
    _foot,
    Offset(-0.105, 0.345),
    Offset(-0.125, 0.05),
  ]);

  // The key light catching its upper-left edge near the tip: a glint that
  // fades down the face, not an outline.
  static final Path _glintL = _poly(const [
    _tip,
    Offset(-0.125, 0.05),
    Offset(-0.1, 0.07),
  ]);
  static final Shader _glintShader = ui.Gradient.linear(
    _tip,
    const Offset(-0.115, 0.06),
    [_a(_hot, 0.6), _a(_lit, 0.2), _a(_lit, 0)],
    const [0.0, 0.5, 1.0],
  );

  // The stone behind it, on the left.
  static const Offset _tip2 = Offset(-0.215, 0.1);
  static final Path _back = _poly(const [
    _tip2,
    Offset(-0.14, 0.22),
    Offset(-0.13, 0.385),
    Offset(-0.21, 0.38),
    Offset(-0.265, 0.22),
  ]);
  static final Path _backLit = _poly(const [
    _tip2,
    Offset(-0.265, 0.22),
    Offset(-0.21, 0.38),
    Offset(-0.185, 0.382),
    Offset(-0.198, 0.23),
  ]);

  // A chip in front of it, on the right.
  static const Offset _tip3 = Offset(0.215, 0.215);
  static final Path _chip = _poly(const [
    _tip3,
    Offset(0.245, 0.31),
    Offset(0.21, 0.4),
    Offset(0.155, 0.395),
    Offset(0.16, 0.31),
  ]);
  static final Path _chipLit = _poly(const [
    _tip3,
    Offset(0.16, 0.31),
    Offset(0.155, 0.395),
    Offset(0.185, 0.398),
    Offset(0.19, 0.3),
  ]);

  static Color _a(Color c, double a) => c.withValues(alpha: a);
  static Color _mix(double k) => Color.lerp(_ink, _signal, k)!;

  // Each face lit by the tip's light from above and the pool's from below;
  // the left one, turned to the key light, more.
  static final Shader _faceL = ui.Gradient.linear(
    _tip,
    const Offset(-0.06, 0.39),
    [_mix(0.66), _mix(0.24), _mix(0.05), _mix(0.48)],
    const [0.0, 0.28, 0.7, 1.0],
  );
  static final Shader _faceR = ui.Gradient.linear(
    _tip,
    const Offset(0.08, 0.39),
    [_mix(0.36), _mix(0.07), _ink, _mix(0.54)],
    const [0.0, 0.3, 0.7, 1.0],
  );
  static final Shader _faceBack = ui.Gradient.linear(
    _tip2,
    const Offset(-0.19, 0.385),
    [_mix(0.26), _ink, _mix(0.48)],
    const [0.0, 0.55, 1.0],
  );
  static final Shader _faceChip = ui.Gradient.linear(
    _tip3,
    const Offset(0.19, 0.4),
    [_mix(0.32), _ink, _mix(0.6)],
    const [0.0, 0.5, 1.0],
  );

  // The light inside the spire, leaking down from the tip.
  static final Shader _leak = ui.Gradient.radial(
    _tip,
    0.42,
    [_a(_hot, 0.5), _a(_signal, 0.26), _a(_signal, 0.06), _a(_signal, 0)],
    const [0.0, 0.28, 0.65, 1.0],
  );

  // Unit-radius lights, stretched where they are drawn: the column off its
  // tip, and its white-hot tip.
  static final Shader _beam = ui.Gradient.radial(
    Offset.zero,
    1,
    [_a(_lit, 0.42), _a(_signal, 0.16), _a(_signal, 0)],
    const [0.0, 0.4, 1.0],
  );
  static final Shader _heart = ui.Gradient.radial(
    Offset.zero,
    1,
    [Colors.white, _hot, _a(_signal, 0.7), _a(_signal, 0)],
    const [0.0, 0.22, 0.5, 1.0],
  );
  static double _h(int i, int salt) => GrainGlass.h(i, salt);

  // Buckets: the column hot / lit / fading, the light inside the spire,
  // the answer, the embers in the pool.
  static const int _colB = 0, _veinB = 3, _ansB = 4, _emberB = 5;
  static final GrainBatch _b = GrainBatch(6);
  static final Paint _p = Paint();

  /// A unit-radius [shader] stretched to [rx] by [ry] round [at].
  static void _light(
    Canvas canvas,
    Shader shader,
    Offset at,
    double rx,
    double ry, [
    double alpha = 1,
  ]) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(rx, ry);
    _p
      ..shader = shader
      ..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0));
    canvas.drawCircle(Offset.zero, 1, _p);
    canvas.restore();
    _p.color = const Color(0xFF000000);
  }

  static void _stone(Canvas canvas, Path path, Shader shader) {
    _p.shader = shader;
    canvas.drawPath(path, _p);
  }

  static void _face(Canvas canvas, Path path, double alpha) {
    _p
      ..shader = null
      ..color = _a(_lit, alpha);
    canvas.drawPath(path, _p);
    _p.color = const Color(0xFF000000);
  }

  static void paint(Canvas canvas, Offset c, double s, double t) {
    if (s <= 0) return;
    final b = _b..clear();
    final beat = (t % _period) / _period;
    final swell = 0.85 + 0.15 * math.sin(beat * math.pi * 2);
    // A small beacon cannot resolve every grain.
    final frac = (s / 64).clamp(0.45, 1.0);

    // ── the light round it: behind it, so the dark stone stands out of
    // the dark, and the pool it is planted in ──
    GrainGlass.pool(
      canvas,
      c + const Offset(0.02, -0.02) * s,
      0.5 * s,
      _signal,
      alpha: 0.6,
    );
    canvas.save();
    canvas.translate(c.dx, c.dy + _ground * s);
    canvas.scale(1, 0.085 / 0.36);
    GrainGlass.pool(canvas, Offset.zero, 0.36 * s, _signal, alpha: swell);
    canvas.restore();

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(s);
    // A shared Paint draws a shader at its color's alpha: start opaque.
    _p.color = const Color(0xFF000000);

    // ── the stone ──
    _stone(canvas, _back, _faceBack);
    _face(canvas, _backLit, 0.26);
    _stone(canvas, _spireLeft, _faceL);
    _stone(canvas, _spireRight, _faceR);
    _p.color = Color.fromRGBO(0, 0, 0, 0.8 + 0.2 * swell);
    _stone(canvas, _spire, _leak);
    _p.color = const Color(0xFF000000);
    _stone(canvas, _glintL, _glintShader);
    _stone(canvas, _chip, _faceChip);
    _face(canvas, _chipLit, 0.3);
    _p.shader = null;

    // ── the column of light off its tip ──
    _light(
      canvas,
      _beam,
      Offset(_tip.dx, _tip.dy - 0.2),
      0.075,
      0.34,
      0.75 + 0.25 * swell,
    );

    // ── grains ──
    // Light climbing the inside of the spire to its tip.
    final veins = (26 * frac).round();
    for (var i = 0; i < veins; i++) {
      final p = (t * (0.2 + 0.1 * _h(i, 1)) + _h(i, 2)) % 1.0;
      final at = Offset.lerp(_foot, _tip, 0.06 + 0.88 * p)!;
      final w = 0.09 * (1 - p) * (_h(i, 3) * 2 - 1);
      b.add(_veinB, at.dx + w, at.dy);
    }

    // The column, off the tip and up out of the box. A pulse climbs it
    // once a call.
    final pulse = beat / 0.6;
    final cols = (80 * frac).round();
    for (var i = 0; i < cols; i++) {
      final p = (t * (0.3 + 0.16 * _h(i, 11)) + _h(i, 12)) % 1.0;
      final side = _h(i, 13) * 2 - 1;
      final spread = 0.01 + 0.075 * math.pow(p, 0.8).toDouble();
      final x =
          _tip.dx +
          side * spread +
          math.sin(t * 1.3 + p * 3 + _h(i, 14) * 5) * 0.018 * p;
      final y = _tip.dy - 0.03 - p * (_tip.dy + 0.5);
      final inPulse = pulse < 1 && (p - pulse).abs() < 0.07;
      b.add(
        inPulse || p < 0.12
            ? _colB
            : p < 0.5
            ? _colB + 1
            : _colB + 2,
        x,
        y,
      );
    }

    // The answer: late in the call, a few grains drawn in from the dark.
    if (beat > 0.45) {
      final u = (beat - 0.45) / 0.55;
      for (var i = 0; i < 7; i++) {
        final ph = (u + _h(i, 21) * 0.5) % 1.0;
        final pull = Curves.easeInCubic.transform(ph);
        final d = 0.44 * (1 - pull);
        final a = -math.pi / 2 + (_h(i, 22) - 0.5) * 2.6 + ph * 0.9;
        b.add(
          _ansB,
          _tip.dx + math.cos(a) * d,
          _tip.dy + math.sin(a) * d * 0.75,
        );
      }
    }

    // A few embers lying in the pool, coming and going.
    for (var i = 0; i < 9; i++) {
      if (math.sin(t * (0.9 + _h(i, 33)) + i * 2.1) < -0.2) continue;
      b.add(
        _emberB,
        (_h(i, 31) * 2 - 1) * 0.3,
        _ground + (_h(i, 32) * 2 - 1) * 0.045,
      );
    }

    final d = (s * 0.026).clamp(1.0, 2.4) / s;
    b.draw(canvas, _emberB, d * 0.85, _a(_lit, 0.55));
    b.draw(canvas, _veinB, d * 0.85, _a(_lit, 0.55));

    // ── the tip, white-hot, breathing with the call ──
    _light(canvas, _heart, _tip, 0.075 * swell, 0.075 * swell);
    _p.shader = null;

    b.draw(canvas, _colB + 2, d * 0.8, _a(_signal, 0.55));
    b.draw(canvas, _colB + 1, d * 0.9, _a(_lit, 0.85));
    b.draw(canvas, _colB, d * 1.05, _a(_hot, 1));
    b.draw(canvas, _ansB, d, _a(_hot, 0.85));
    canvas.restore();
  }
}
