import 'dart:math' as math;

import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A cold storage upgrade, drawn as the cells it buys you.
///
/// The offer was borrowing the breeding icon, which says nothing about
/// capacity. A honeycomb of stasis cells does: the occupied ones hold a
/// specimen and are lit, the spare ones are empty sockets, and the loop keeps
/// filling the spares in — which is the purchase.
class ColdStorageGlyph extends StatefulWidget {
  const ColdStorageGlyph({
    super.key,
    required this.size,
    this.animate = true,
  });

  final double size;

  /// Off for a still frame; a shop card scrolling past does not need to run.
  final bool animate;

  @override
  State<ColdStorageGlyph> createState() => _ColdStorageGlyphState();
}

class _ColdStorageGlyphState extends State<ColdStorageGlyph>
    with GlyphClockLease {
  @override
  bool get wantsClock => widget.animate;

  @override
  void initState() {
    super.initState();
    syncGlyphClock();
  }

  @override
  void didUpdateWidget(covariant ColdStorageGlyph oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncGlyphClock();
  }

  @override
  void dispose() {
    releaseGlyphClock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        willChange: widget.animate,
        isComplex: false,
        painter: _ColdStoragePainter(clock: glyphClock),
      ),
    );
  }
}

class _ColdStoragePainter extends CustomPainter {
  _ColdStoragePainter({required this.clock}) : super(repaint: clock);

  final ValueListenable<double>? clock;

  /// Reused across every frame and every glyph on screen.
  static final Paint _p = Paint();

  /// One fill-up and reset.
  static const double _period = 5.4;

  /// The cells that are already yours. The rest are what the upgrade adds,
  /// and they are the ones that light.
  static const int _occupied = 4;
  static const int _cells = 7;

  static const _frost = Color(0xFFDFF6FF);
  static const _ice = Color(0xFF5CC4F2);
  static const _iceDeep = Color(0xFF1E5B85);
  static const _socket = Color(0xFF3D566B);

  double get _t => clock?.value ?? 0;

  static double _seed(int i, int salt) => ((i * 43 + salt * 19) % 100) / 100.0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final c = Offset(size.width / 2, size.height / 2);

    // Circumradius, and the centre-to-centre step that makes them share edges.
    final r = s * 0.152;
    final step = r * math.sqrt(3);
    final beat = (_t % _period) / _period;

    final centres = <Offset>[c];
    for (var i = 0; i < 6; i++) {
      // Neighbours sit toward the edge midpoints, not the vertices.
      final a = math.pi / 6 + i * math.pi / 3;
      centres.add(c + Offset(math.cos(a) * step, math.sin(a) * step));
    }

    // The spares fill one after another, hold, then release together.
    final spares = _cells - _occupied;
    for (var i = 0; i < _cells; i++) {
      double lit;
      if (i < _occupied) {
        lit = 1;
      } else {
        final slot = i - _occupied;
        // Each spare gets its own slice of the first 55% of the loop.
        final start = 0.10 + slot * (0.45 / spares);
        final end = start + 0.45 / spares;
        if (beat < start) {
          lit = 0;
        } else if (beat < end) {
          lit = Curves.easeOutCubic.transform((beat - start) / (end - start));
        } else if (beat < 0.84) {
          lit = 1;
        } else {
          lit = 1 - Curves.easeInCubic.transform((beat - 0.84) / 0.16);
        }
      }
      _cell(canvas, centres[i], r * 0.90, s, lit);
    }

    _frostMotes(canvas, c, s);
  }

  void _cell(Canvas canvas, Offset centre, double r, double s, double lit) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      final p = centre + Offset(math.cos(a) * r, math.sin(a) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();

    final bounds = Rect.fromCircle(center: centre, radius: r);

    if (lit > 0.01) {
      canvas.drawPath(
        path,
        _p
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(_socket, _frost, lit)!,
              Color.lerp(_socket, _ice, lit)!,
              Color.lerp(const Color(0xFF16202B), _iceDeep, lit)!,
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(bounds),
      );
      _p.shader = null;
    } else {
      canvas.drawPath(path, _p..color = const Color(0xFF16202B));
    }

    canvas.drawPath(
      path,
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.016
        ..strokeJoin = StrokeJoin.round
        ..color = Color.lerp(
          _socket.withValues(alpha: 0.85),
          _frost,
          lit,
        )!,
    );
    _p.style = PaintingStyle.fill;

    // The specimen the cell is holding.
    if (lit > 0.15) {
      canvas.drawCircle(
        centre,
        r * 0.24 * lit,
        _p..color = Colors.white.withValues(alpha: 0.85 * lit),
      );
    }
  }

  /// A little cold coming off it. Five motes is enough to say "frost" and
  /// cheap enough to draw in a scrolling grid.
  void _frostMotes(Canvas canvas, Offset c, double s) {
    for (var i = 0; i < 5; i++) {
      final phase = (_t * 0.16 + _seed(i, 3)) % 1.0;
      final x = c.dx + (_seed(i, 5) - 0.5) * s * 0.86;
      final y = c.dy + s * (0.46 - 0.92 * phase);
      final fade =
          (phase < 0.2 ? phase / 0.2 : 1.0) *
          (phase > 0.75 ? (1 - phase) / 0.25 : 1.0);
      if (fade <= 0.02) continue;
      canvas.drawCircle(
        Offset(x, y),
        s * 0.014,
        _p..color = _frost.withValues(alpha: 0.5 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ColdStoragePainter old) => old.clock != clock;
}
