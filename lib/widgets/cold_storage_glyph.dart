import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/widgets/fx/grain_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A cold storage upgrade, drawn as the cells it buys you.
///
/// A small stasis rack — the nursery's — of glass cells set into frost, each
/// holding a cultivation's grains turning at a fifth of their speed. One more
/// cell at the rack's corner gathers itself out of the cold and lights: that
/// cell is the purchase.
class ColdStorageGlyph extends StatelessWidget {
  const ColdStorageGlyph({super.key, required this.size, this.animate = true});

  final double size;

  /// Off for a still frame; a shop card scrolling past does not need to run.
  final bool animate;

  @override
  Widget build(BuildContext context) => GrainGlyph(
    size: size,
    animate: animate,
    painter: (clock) => _ColdStoragePainter(clock),
  );
}

class _ColdStoragePainter extends CustomPainter {
  _ColdStoragePainter(this.clock) : super(repaint: clock);

  final ValueListenable<double>? clock;

  /// One new cell forming, held, and let go.
  static const double _period = 6.0;

  /// A still glyph (the shelf's bake) shows the new cell nearly formed, its
  /// last grains still swirling in.
  static const double _still = 0.36 * _period;

  static const _frost = Color(0xFFDDF3FF);
  static const _ice = Color(0xFF78B9DE);
  static const _iceDeep = Color(0xFF16324A);
  static const _socket = Color(0xFF233240);

  /// What the full cells hold, in the element colours the nursery uses.
  static final List<Color> _held = [
    for (final id in const ['oceanic', 'volcanic', 'verdant', 'arcane'])
      ElementResources.byBiomeId[id]!.color,
  ];

  static final Paint _p = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final t = (clock?.value ?? 0) + _still;
    final beat = (t % _period) / _period;

    // Flat-topped hexes, the rack's own. Four full ones in a diamond and the
    // new one at the top right, so the rack is not a badge.
    final r = s * 0.165;
    final hh = r * math.sqrt(3);
    final o = Offset(size.width / 2, size.height / 2 - hh * 0.25);
    final cells = [
      o + Offset(-1.5 * r, hh / 2),
      o,
      o + Offset(1.5 * r, hh / 2),
      o + Offset(0, hh),
    ];
    final fresh = o + Offset(1.5 * r, -hh / 2);

    // The new cell: gathers over the first half, holds, then lets go.
    final gather = GrainGlass.smooth(beat / 0.45);
    final release = GrainGlass.smooth((beat - 0.86) / 0.14);

    for (var i = 0; i < cells.length; i++) {
      _cell(canvas, cells[i], r, s, t, held: _held[i], lit: 1, salt: i);
    }
    _cell(
      canvas,
      fresh,
      r,
      s,
      t,
      held: _held[0],
      lit: gather * (1 - release),
      gather: gather,
      salt: 7,
    );
    _breath(canvas, o, s, t);
  }

  Path _hex(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  void _cell(
    Canvas canvas,
    Offset c,
    double r,
    double s,
    double t, {
    required Color held,
    required double lit,
    double gather = 1,
    required int salt,
  }) {
    final outer = r * 0.93, inner = r * 0.83;
    final box = Rect.fromCircle(center: c, radius: outer);

    // The frosted bevel: ice lit from the upper left, deep at the lower
    // right. A filled band, not a line. (Opaque first: a shader is drawn at
    // the paint colour's alpha, and the frost below leaves it faint.)
    _p.color = const Color(0xFF000000);
    _p.shader = ui.Gradient.linear(box.topLeft, box.bottomRight, [
      Color.lerp(_socket, _frost, 0.1 + 0.55 * lit)!,
      Color.lerp(_socket, _ice, 0.1 + 0.35 * lit)!,
      Color.lerp(const Color(0xFF0C141C), _iceDeep, 0.6 * lit)!,
      Color.lerp(const Color(0xFF0C141C), _iceDeep, lit)!,
    ], const [0.0, 0.3, 0.6, 1.0]);
    canvas.drawPath(_hex(c, outer), _p);

    // The glass well inside it.
    _p.shader = ui.Gradient.radial(
      c + Offset(-inner * 0.25, -inner * 0.3),
      inner * 1.3,
      [
        Color.lerp(const Color(0xFF101820), const Color(0xFF1A3346), lit)!,
        const Color(0xFF070B10),
      ],
    );
    canvas.drawPath(_hex(c, inner), _p);
    _p.shader = null;

    if (lit > 0.01) {
      GrainGlass.pool(canvas, c, inner * 0.95, held, alpha: 0.75 * lit);
      // Held in stasis: a fifth of a cultivation's turn.
      GrainGlass.sphere(
        canvas,
        c,
        inner * 0.62,
        t * 0.2,
        a: held,
        b: Color.lerp(held, Colors.white, 0.25),
        spin: 1.2,
        glass: 0,
        gather: gather,
        density: 0.75,
        glow: 0.6,
        fade: math.min(1, lit * 1.4),
        salt: salt,
      );
    }

    // Frost on the cold upper edge of the bevel: a few fine pale grains,
    // twinkling.
    final d = (s * 0.014).clamp(0.7, 1.8);
    for (var k = 0; k < 5; k++) {
      final a = (GrainGlass.h(k, 11 + salt) * 0.7 - 0.85) * math.pi;
      final rr = inner + (outer - inner) * (0.3 + 0.4 * GrainGlass.h(k, 12));
      final tw = 0.5 + 0.5 * math.sin(t * 1.3 + k * 2.1 + salt);
      _p.color = _frost.withValues(alpha: (0.15 + 0.4 * lit) * tw);
      canvas.drawCircle(
        c + Offset(math.cos(a) * rr, math.sin(a) * rr),
        d * 0.5,
        _p,
      );
    }
  }

  /// A little cold coming off the rack.
  void _breath(Canvas canvas, Offset o, double s, double t) {
    final d = (s * 0.016).clamp(0.8, 2.0);
    for (var i = 0; i < 6; i++) {
      final phase = (t * 0.12 + GrainGlass.h(i, 3)) % 1.0;
      final x = o.dx + (GrainGlass.h(i, 5) - 0.45) * s * 0.8;
      final y = o.dy + s * (0.42 - 0.62 * phase);
      final fade = math.sin(phase * math.pi);
      if (fade <= 0.02) continue;
      _p.color = _frost.withValues(alpha: 0.35 * fade);
      canvas.drawCircle(Offset(x, y), d * 0.5, _p);
    }
  }

  @override
  bool shouldRepaint(covariant _ColdStoragePainter old) => old.clock != clock;
}
