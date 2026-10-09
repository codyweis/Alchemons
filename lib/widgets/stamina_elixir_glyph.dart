import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/fusion_particles.dart' show GrainBatch;
import 'package:alchemons/widgets/fx/grain_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The Stamina Elixir: a small dark-glass flask, half full of a draught of
/// green-gold grains turning slowly in it, with a wisp of them rising out of
/// its neck.
///
/// The same material as the shop's glass spheres ([GrainGlass], the power
/// orbs) — dark tinted glass with the light inside it, a lit edge and a
/// catchlight, at the same strengths — so it sits in a row of them as the
/// same kind of thing. Its body is drawn here rather than by
/// [GrainGlass.sphere] because a draught needs a level, with empty glass
/// above it, and that sphere fills every grain. The old flask was a flat
/// cartoon: a green fill, a white outline, a cork and a lightning bolt.
class StaminaElixirGlyph extends StatelessWidget {
  const StaminaElixirGlyph({
    super.key,
    required this.size,
    this.animate = true,
  });

  final double size;

  /// Off for a still frame; a list row scrolling past does not need to run.
  final bool animate;

  // On the shop glyphs' shared clock, let go of while TickerMode is off.
  @override
  Widget build(BuildContext context) => GrainGlyph(
    size: size,
    animate: animate,
    painter: (clock) => _StaminaElixirPainter(clock: clock),
  );
}

class _StaminaElixirPainter extends CustomPainter {
  _StaminaElixirPainter({required this.clock}) : super(repaint: clock);

  final ValueListenable<double>? clock;

  @override
  void paint(Canvas canvas, Size size) => _ElixirPaint.paint(
    canvas,
    size.center(Offset.zero),
    size.shortestSide,
    // A still flask is caught with its wisp already up; a running one
    // starts from that same frame.
    (clock?.value ?? 0) + _ElixirPaint.stillTime,
  );

  @override
  bool shouldRepaint(covariant _StaminaElixirPainter old) => old.clock != clock;
}

/// Paints the flask. Everything is laid out in a unit box (1 = the glyph's
/// size, origin at its centre) and drawn through one scale, so every shader
/// and grain layout is built once for every size. No blur, no layers.
abstract final class _ElixirPaint {
  static const double stillTime = 1.7;

  // ── the draught's colors, deep to white ──
  static const Color _ink = Color(0xFF05080A);
  static const Color _essence = Color(0xFF6FD873);
  static const List<Color> _tones = [
    Color(0xFF16452C),
    Color(0xFF2A8550),
    Color(0xFF55C96C),
    Color(0xFFA3E363),
    Color(0xFFE0EE8C),
    Color(0xFFFBFFE0),
  ];
  static final Color _rim = Color.lerp(_essence, Colors.white, 0.4)!;

  // ── the flask ──
  static const Offset _bc = Offset(0, 0.15); // the body's centre
  static const double _rb = 0.275; // its radius
  static const double _lean = -0.1; // leaning a little to the left
  static const double _neckW = 0.058; // half the neck's width
  static const double _neckTop = -0.255;

  /// The level, in body radii from its centre (y down): a little over half.
  static const double _surf = -0.16;

  /// Seen from a little above, so the surface is an ellipse, not an edge.
  static const double _tip = 0.4;
  static final double _ct = math.cos(_tip), _st = math.sin(_tip);

  static double _h(int i, int salt) => GrainGlass.h(i, salt);

  // The draught, laid out once: grains in the unit ball under the level,
  // each with its distance from the axis, its height and its starting turn.
  // Shuffled, so a small flask can draw just the first few and still fill.
  static final List<(double, double, double)> _liquid = () {
    final out = <(double, double, double)>[];
    for (var i = 0; out.length < 230 && i < 2000; i++) {
      final lat = math.asin(2 * _h(i, 1) - 1);
      final rad = math.pow(_h(i, 3), 0.45).toDouble() * 0.95;
      final py = rad * math.sin(lat);
      if (py < _surf + 0.04) continue;
      out.add((rad * math.cos(lat), py, _h(i, 2) * math.pi * 2));
    }
    return out;
  }();

  // The surface: a disc of grains at the level.
  static final double _surfR = math.sqrt(1 - _surf * _surf) * 0.92;
  static final List<(double, double)> _surface = [
    for (var i = 0; i < 64; i++)
      (math.sqrt(_h(i, 21)) * _surfR, _h(i, 22) * math.pi * 2),
  ];

  // Buckets: liquid far side (3), near side by tone (6), the surface (2),
  // glints, the wisp low / mid / high.
  static const int _farB = 0, _nearB = 3, _surfB = 9, _glintB = 11;
  static const int _wispB = 12;
  static final GrainBatch _b = GrainBatch(15);
  static final Paint _p = Paint();

  static Color _a(Color c, double a) => c.withValues(alpha: a);

  static final Shader _glow = ui.Gradient.radial(
    const Offset(0, 0.06),
    0.5,
    [_a(_essence, 0.3), _a(_essence, 0.09), _a(_essence, 0)],
    const [0.0, 0.45, 1.0],
  );

  static final Shader _neck = ui.Gradient.linear(
    const Offset(-_neckW, 0),
    const Offset(_neckW, 0),
    [
      _a(Color.lerp(_ink, _rim, 0.55)!, 0.95),
      _a(Color.lerp(_ink, _essence, 0.2)!, 0.9),
      _a(_ink, 0.92),
      _a(Color.lerp(_ink, _essence, 0.32)!, 0.92),
    ],
    const [0.0, 0.3, 0.72, 1.0],
  );

  static final Shader _lip = ui.Gradient.linear(
    const Offset(0, _neckTop - 0.03),
    const Offset(0, _neckTop + 0.03),
    [
      _a(Color.lerp(_ink, _rim, 0.6)!, 0.95),
      _a(Color.lerp(_ink, _essence, 0.18)!, 0.94),
      _a(_ink, 0.95),
    ],
    const [0.0, 0.45, 1.0],
  );

  static final Shader _body = ui.Gradient.radial(
    _bc + const Offset(-_rb * 0.2, -_rb * 0.25),
    _rb * 1.25,
    [
      _a(Color.lerp(_essence, _ink, 0.5)!, 0.55),
      _a(Color.lerp(_essence, _ink, 0.74)!, 0.76),
      _a(Color.lerp(_essence, _ink, 0.88)!, 0.9),
    ],
    const [0.0, 0.6, 1.0],
  );

  // The light inside sits in the draught, under the level.
  static final Shader _heart = ui.Gradient.radial(
    _bc + const Offset(0, _rb * 0.32),
    _rb * 0.8,
    [
      _a(Color.lerp(_essence, Colors.white, 0.5)!, 0.62),
      _a(_essence, 0.28),
      _a(_essence, 0),
    ],
    const [0.0, 0.45, 1.0],
  );

  static final Shader _edge = ui.Gradient.radial(
    _bc + const Offset(_rb * 0.12, _rb * 0.14),
    _rb * 1.02,
    [_a(_essence, 0), _a(_essence, 0), _a(_rim, 0.5), _a(_essence, 0)],
    const [0.0, 0.8, 0.95, 1.0],
  );

  static final Shader _shine = ui.Gradient.radial(
    _bc + const Offset(-_rb * 0.36, -_rb * 0.42),
    _rb * 0.42,
    const [Color(0x8FFFFFFF), Color(0x00FFFFFF)],
  );

  static final Shader _lipShine = ui.Gradient.radial(
    const Offset(-_neckW * 0.6, _neckTop - 0.012),
    0.04,
    const [Color(0x99FFFFFF), Color(0x00FFFFFF)],
  );

  // The draught as a body of light in the glass: the part of the sphere
  // under the level, its top edge the far side of the surface.
  static final double _surfY = _bc.dy + _surf * _rb * _ct;
  static final double _surfRx = _surfR * _rb, _surfRy = _surfR * _rb * _st;
  static final Path _draught = Path.combine(
    PathOperation.intersect,
    Path()..addOval(Rect.fromCircle(center: _bc, radius: _rb * 0.985)),
    Path.combine(
      PathOperation.union,
      Path()..addOval(
        Rect.fromCenter(
          center: Offset(_bc.dx, _surfY),
          width: _surfRx * 2,
          height: _surfRy * 2,
        ),
      ),
      Path()..addRect(Rect.fromLTRB(-1, _surfY, 1, 1)),
    ),
  );
  static final Shader _draughtLight = ui.Gradient.linear(
    Offset(0, _surfY - _surfRy),
    Offset(0, _bc.dy + _rb),
    [_a(_tones[4], 0.28), _a(_tones[2], 0.16), _a(_tones[0], 0.28)],
    const [0.0, 0.45, 1.0],
  );
  // The level catching the light: soft, brightest at its middle.
  static final Shader _levelLight = ui.Gradient.radial(
    Offset.zero,
    1,
    [_a(_tones[5], 0.55), _a(_tones[4], 0.3), _a(_tones[3], 0)],
    const [0.0, 0.5, 1.0],
  );

  static final RRect _neckRect = RRect.fromLTRBR(
    -_neckW,
    _neckTop,
    _neckW,
    _bc.dy - _rb * 0.8,
    const Radius.circular(0.02),
  );

  static final RRect _lipRect = RRect.fromLTRBR(
    -_neckW - 0.024,
    _neckTop - 0.032,
    _neckW + 0.024,
    _neckTop + 0.024,
    const Radius.circular(0.026),
  );

  static void paint(Canvas canvas, Offset c, double s, double t) {
    if (s <= 0) return;
    final b = _b..clear();

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(s);

    // ── its light on what is round it ──
    _p.shader = _glow;
    canvas.drawCircle(const Offset(0, 0.06), 0.5, _p);

    // The flask leans a little; the wisp curls back against it.
    canvas.translate(_bc.dx, _bc.dy);
    canvas.rotate(_lean);
    canvas.translate(-_bc.dx, -_bc.dy);

    // ── the neck and its lip, dark glass lit down the left ──
    _p.shader = _neck;
    canvas.drawRRect(_neckRect, _p);
    _p.shader = _lip;
    canvas.drawRRect(_lipRect, _p);
    _p.shader = _lipShine;
    canvas.drawCircle(const Offset(-_neckW * 0.6, _neckTop - 0.012), 0.04, _p);

    // ── the draught, turning ──
    // A small flask cannot resolve every grain.
    final px = _rb * s;
    final frac = (px / 24).clamp(0.4, 1.0);
    final count = (_liquid.length * frac).round();
    for (var i = 0; i < count; i++) {
      final (rho, py, lon0) = _liquid[i];
      // A vortex: the middle turns faster than the wall.
      final lon = lon0 + t * 0.55 / (0.35 + rho);
      final x = rho * math.cos(lon);
      final z = rho * math.sin(lon);
      final y = py * _ct + z * _st;
      final depth = z * _ct - py * _st;
      // Lit from the upper left and front, and from its own heart.
      var light = (-0.45 * x - 0.6 * y + 0.66 * depth) * 0.5 + 0.5;
      light = (light * light * (3 - 2 * light)).clamp(0.0, 1.0);
      // Brightest just under the level, deepest at the bottom.
      final rise = (1 - (py - _surf) / (1 - _surf)).clamp(0.0, 1.0);
      final tone = (0.55 * light + 0.45 * rise).clamp(0.0, 1.0);
      final sx = _bc.dx + x * _rb, sy = _bc.dy + y * _rb;
      if (depth < 0) {
        b.add(_farB + (tone * 2.99).floor(), sx, sy);
        continue;
      }
      if ((t * 0.3 + _h(i, 4) * 7.7) % 1.0 < 0.01 && tone > 0.45) {
        b.add(_glintB, sx, sy);
        continue;
      }
      b.add(_nearB + (tone * 5.99).floor(), sx, sy);
    }

    // The level: a disc of brighter grains, turning with the rest.
    final sCount = (_surface.length * frac).round();
    for (var i = 0; i < sCount; i++) {
      final (rho, lon0) = _surface[i];
      final lon = lon0 + t * 0.55 / (0.35 + rho);
      final x = rho * math.cos(lon);
      final z = rho * math.sin(lon);
      final y = _surf * _ct + z * _st;
      b.add(_surfB + (z > 0 ? 1 : 0), _bc.dx + x * _rb, _bc.dy + y * _rb);
    }

    // ── the wisp: grains lifting off the level, up the neck and out ──
    final surfY = _surfY;
    const top = -0.5;
    final neckFoot = _bc.dy - _rb * 0.8;
    final wisps = (56 * frac).round();
    for (var i = 0; i < wisps; i++) {
      final p = (t * (0.16 + 0.07 * _h(i, 31)) + _h(i, 32)) % 1.0;
      final side = _h(i, 33) * 2 - 1;
      final y = surfY + (top - surfY) * p;
      double x;
      if (y > neckFoot) {
        // Lifting off the whole level and drawn together into the neck.
        final k = ((surfY - y) / (surfY - neckFoot)).clamp(0.0, 1.0);
        final e = Curves.easeInQuad.transform(k);
        x = side * (_surfRx * 0.8 * (1 - e) + _neckW * 0.6 * e);
      } else if (y > _neckTop) {
        x = side * _neckW * 0.6;
      } else {
        // Out of the neck: spreading, and curling over to the right.
        final q = ((_neckTop - y) / (_neckTop - top)).clamp(0.0, 1.0);
        x =
            side * (_neckW * 0.6 + 0.07 * q) +
            0.15 * q * q +
            math.sin(t * 1.6 + p * 5 + _h(i, 34) * 6) * 0.018 * q;
      }
      // Faint while still in the glass, brightest as it leaves the neck.
      b.add(
        y > neckFoot
            ? _wispB + 2
            : y > _neckTop - 0.08
            ? _wispB
            : _wispB + 1,
        x,
        y,
      );
    }

    // ── draw, back to front ──
    final d = (px * 0.068).clamp(1.05, 2.3) / s;
    _p.shader = _body;
    canvas.drawCircle(_bc, _rb, _p);
    for (var k = 0; k < 3; k++) {
      b.draw(canvas, _farB + k, d * 0.8, _a(_tones[k + 1], 0.55));
    }
    _p.shader = _draughtLight;
    canvas.drawPath(_draught, _p);
    _p.shader = _heart;
    canvas.drawCircle(_bc + const Offset(0, _rb * 0.32), _rb * 0.8, _p);
    for (var k = 0; k < 6; k++) {
      b.draw(canvas, _nearB + k, d, _a(_tones[k], 0.9));
    }
    canvas.save();
    canvas.translate(_bc.dx, _surfY);
    canvas.scale(_surfRx * 0.9, _surfRy * 0.9);
    _p.shader = _levelLight;
    canvas.drawCircle(Offset.zero, 1, _p);
    canvas.restore();
    b.draw(canvas, _surfB, d * 0.95, _a(_tones[3], 0.75));
    b.draw(canvas, _surfB + 1, d * 1.05, _a(_tones[4], 0.95));
    _p.shader = _edge;
    canvas.drawCircle(_bc, _rb * 1.04, _p);
    _p.shader = _shine;
    canvas.drawCircle(
      _bc + const Offset(-_rb * 0.36, -_rb * 0.42),
      _rb * 0.42,
      _p,
    );
    _p.shader = null;
    b.draw(canvas, _glintB, d * 2.3, const Color(0x40FFFFFF));
    b.draw(canvas, _glintB, d * 1.25, Colors.white);
    b.draw(canvas, _wispB, d * 1.05, _a(_tones[5], 0.95));
    b.draw(canvas, _wispB + 1, d, _a(_tones[4], 0.85));
    b.draw(canvas, _wispB + 2, d * 0.9, _a(_tones[3], 0.6));
    canvas.restore();
  }
}
