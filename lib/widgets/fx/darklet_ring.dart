// lib/widgets/fx/darklet_ring.dart
//
// DARKLET'S GALAXY RING: dust orbiting its head, behind and in front of it.
//
//   Drawn by the sprite renderers like a worn costume — in the frame's own
//   space, at that frame's fit — so it follows the head through the four eye
//   frames and whatever the renderer does to the sprite. The sheet itself is
//   the ringless Darklet; this is the ring.

import 'dart:math' as math;

import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

abstract final class DarkletRing {
  /// Darklet's sheet is the only one cut at this frame size.
  static const Size frameSize = Size(543, 724);

  static bool matches(double frameWidth, double frameHeight) =>
      frameWidth == 543 && frameHeight == 724;

  // Head centre per eye frame, in frame pixels: the sheet bobs the body
  // up and down a few pixels (up, mid, down, mid).
  static const double _headX = 271;
  static const List<double> _headY = [315, 319, 323, 319];

  // The ring was designed at 0.88 of the frame; radii below are in those units.
  static const double _unit = 1 / 0.88;
  static const double _tilt = 0.47;
  static const double _squash = 0.31;
  static const List<Color> _colors = [
    Color(0xFF7474EC),
    Color(0xFF8B91FF),
    Color(0xFF9ACAFF),
    Color(0xFFC7ECFF),
  ];

  static final List<_Grain> _grains = _makeGrains();

  static List<_Grain> _makeGrains() {
    var seed = 2309;
    double random() {
      seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF;
      return seed / 4294967296;
    }

    return List.generate(260, (_) {
      final lane = random();
      final radius = lane < .58
          ? 179 + (random() + random() - 1) * 13
          : lane < .9
          ? 200 + (random() + random() - 1) * 9
          : 220 + (random() - .5) * 11;
      return _Grain(
        radius,
        random() * math.pi * 2,
        random() * math.pi * 2,
        .35 + random() * .8,
        random() > .9,
        (random() * _colors.length).floor(),
      );
    });
  }

  static double _speed(double r) => .76 / math.pow(r / 180, 1.5);

  /// Paints one side of the ring into [frame] — the far side before the
  /// sprite, the near side after — for eye frame [index] at [t] seconds.
  static void paint(
    Canvas canvas,
    Rect frame,
    int index,
    double t, {
    required bool front,
    double opacity = 1,
  }) {
    if (opacity <= 0) return;
    final s = frame.width / frameSize.width;
    final k = s * _unit;
    final cx = frame.left + _headX * s;
    final cy = frame.top + _headY[index.clamp(0, 3)] * s;
    final cosT = math.cos(_tilt), sinT = math.sin(_tilt);
    final depth = (front ? 1.0 : .62) * opacity;

    Offset at(double r, double a) {
      final x = math.cos(a) * r, y = math.sin(a) * r * _squash;
      return Offset(
        cx + (x * cosT - y * sinT) * k,
        cy + (x * sinT + y * cosT) * k,
      );
    }

    Path arc(double r, double a, double b) {
      final p = Path();
      for (var i = 0; i <= 28; i++) {
        final o = at(r, a + (b - a) * i / 28);
        i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
      }
      return p;
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.plus;
    void line(Path p, double width, Color c, double alpha) {
      stroke
        ..strokeWidth = width * k
        ..color = c.withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawPath(p, stroke);
    }

    final start = front ? 0.0 : math.pi, end = front ? math.pi : math.pi * 2;
    for (final r in const [176.0, 184.0, 200.0]) {
      final p = arc(r, start, end);
      line(p, 11, _colors[0], .032 * depth);
      line(p, 5, _colors[1], .055 * depth);
      line(p, 1.1, _colors[2], .12 * depth);
    }

    // Stretched, rotating clumps give the disc its swirl direction.
    for (var band = 0; band < 4; band++) {
      final r = 174.0 + band * 11;
      final speed = _speed(r);
      for (var j = 0; j < 2; j++) {
        final angle = t * speed + band * 1.7 + j * math.pi;
        // Near the horizon the clump is half on each side; drawn whole on
        // whichever side its head is.
        if ((math.sin(angle) > 0) != front) continue;
        final tail = arc(r, angle - .55, angle);
        line(tail, 2.4, _colors[1], .10 * depth);
        line(tail, .8, _colors[3], .34 * depth);
      }
    }

    final dot = Paint()..blendMode = BlendMode.plus;
    for (final g in _grains) {
      final a = g.angle + t * _speed(g.radius);
      if ((math.sin(a) > 0) != front) continue;
      final o = at(g.radius, a);
      final twinkle = .55 + .45 * math.pow(math.sin(t * 1.6 + g.phase), 2);
      final c = _colors[g.color];
      dot.color = c.withValues(
        alpha: ((g.bright ? .95 : .6) * twinkle * depth).clamp(0.0, 1.0),
      );
      canvas.drawCircle(o, g.size * k, dot);
      if (g.bright) {
        dot.color = c.withValues(alpha: .075 * twinkle * depth);
        canvas.drawCircle(o, g.size * 3 * k, dot);
      }
    }
  }
}

class _Grain {
  const _Grain(
    this.radius,
    this.angle,
    this.phase,
    this.size,
    this.bright,
    this.color,
  );
  final double radius, angle, phase, size;
  final bool bright;
  final int color;
}

/// Darklet's ring about [child] in a widget: far side behind the sprite,
/// near side over it, on the shared glyph clock.
class DarkletRingView extends StatefulWidget {
  const DarkletRingView({
    super.key,
    required this.frameIndex,
    required this.child,
  });

  final int Function() frameIndex;
  final Widget child;

  @override
  State<DarkletRingView> createState() => _DarkletRingViewState();
}

class _DarkletRingViewState extends State<DarkletRingView>
    with GlyphClockLease {
  bool _visible = true;

  @override
  bool get wantsClock => _visible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    syncGlyphClock();
  }

  @override
  void dispose() {
    releaseGlyphClock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _RingPainter(false, widget.frameIndex, glyphClock),
    foregroundPainter: _RingPainter(true, widget.frameIndex, glyphClock),
    child: widget.child,
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.front, this.frameIndex, this.clock) : super(repaint: clock);

  final bool front;
  final int Function() frameIndex;
  final ValueListenable<double>? clock;

  @override
  void paint(Canvas canvas, Size size) {
    const fs = DarkletRing.frameSize;
    final fit = math.min(size.width / fs.width, size.height / fs.height);
    DarkletRing.paint(
      canvas,
      Offset.zero & (fs * fit),
      frameIndex(),
      clock?.value ?? 2.6,
      front: front,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.front != front || old.clock != clock;
}
