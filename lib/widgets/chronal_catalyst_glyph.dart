import 'dart:math' as math;

import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The Chronal Catalyst, drawn as what it does to a clock.
///
/// Not an hourglass: an hourglass says "time", and half the items in the shop
/// are about time. This says the specific thing — one hand sweeping at
/// ordinary speed and a second running at double, pulling ahead of it, with
/// the gap between them filled in. What you are buying is the gap.
class ChronalCatalystGlyph extends StatefulWidget {
  const ChronalCatalystGlyph({
    super.key,
    required this.size,
    this.animate = true,
    this.color = const Color(0xFF7BE1E8),
  });

  final double size;
  final bool animate;
  final Color color;

  @override
  State<ChronalCatalystGlyph> createState() => _ChronalCatalystGlyphState();
}

class _ChronalCatalystGlyphState extends State<ChronalCatalystGlyph>
    with GlyphClockLease {
  @override
  bool get wantsClock => widget.animate;

  @override
  void initState() {
    super.initState();
    syncGlyphClock();
  }

  @override
  void didUpdateWidget(covariant ChronalCatalystGlyph oldWidget) {
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
        painter: _CatalystPainter(color: widget.color, clock: glyphClock),
      ),
    );
  }
}

class _CatalystPainter extends CustomPainter {
  _CatalystPainter({required this.color, required this.clock})
    : super(repaint: clock);

  final Color color;
  final ValueListenable<double>? clock;

  /// Reused across every frame and every catalyst on screen. No MaskFilter
  /// anywhere: blur in a per-frame paint is this app's main source of jank.
  static final Paint _p = Paint();

  /// One full sweep of the slow hand.
  static const double _period = 3.0;

  /// Where the still frame is taken. At t = 0 both hands sit on top of each
  /// other and the glyph says nothing at all, so the baked frame is a
  /// third of the way round, where the gap is widest and obvious.
  static const double _stillPhase = 0.33;

  double get _t => (clock?.value ?? _stillPhase * _period);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final c = Offset(size.width / 2, size.height / 2);
    final phase = (_t % _period) / _period;
    final r = s * 0.36;

    const start = -math.pi / 2;
    final slow = start + phase * math.pi * 2;
    // Twice round in the time the other goes once. That is the whole item.
    final fast = start + phase * math.pi * 4;

    // The dial.
    canvas.drawCircle(
      c,
      r,
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.035
        ..color = color.withValues(alpha: 0.32),
    );

    // The time the catalyst is giving back, swept between the two hands.
    _p
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.16);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.92),
      slow,
      fast - slow,
      true,
      _p,
    );

    // Four ticks, so the dial reads as a dial at 22px.
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.030
      ..color = color.withValues(alpha: 0.45);
    for (var i = 0; i < 4; i++) {
      final a = start + i * math.pi / 2;
      final u = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + u * (r * 0.80), c + u * r, _p);
    }

    // The ordinary hand, and the one running ahead of it.
    _p
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * 0.042
      ..color = color.withValues(alpha: 0.55);
    canvas.drawLine(
      c,
      c + Offset(math.cos(slow), math.sin(slow)) * (r * 0.62),
      _p,
    );
    _p
      ..strokeWidth = s * 0.052
      ..color = Color.lerp(color, Colors.white, 0.35)!;
    canvas.drawLine(
      c,
      c + Offset(math.cos(fast), math.sin(fast)) * (r * 0.80),
      _p,
    );

    // The hub, holding both.
    _p
      ..style = PaintingStyle.fill
      ..color = Color.lerp(color, Colors.white, 0.5)!;
    canvas.drawCircle(c, s * 0.052, _p);
  }

  @override
  bool shouldRepaint(covariant _CatalystPainter old) =>
      old.color != color || old.clock != clock;
}
