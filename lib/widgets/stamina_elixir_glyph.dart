import 'dart:math' as math;

import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The Stamina Elixir, drawn doing the one thing it does.
///
/// A flask charges — the fluid climbs, the bubbles quicken, the bolt suspended
/// in it winds up — and then discharges out of the neck and settles back to
/// resting. Charge, spend, recover is the item's whole loop, which a painting
/// of a bottle could only imply.
class StaminaElixirGlyph extends StatefulWidget {
  const StaminaElixirGlyph({
    super.key,
    required this.size,
    this.animate = true,
  });

  final double size;

  /// Off for a still frame; a list row scrolling past does not need to run.
  final bool animate;

  @override
  State<StaminaElixirGlyph> createState() => _StaminaElixirGlyphState();
}

class _StaminaElixirGlyphState extends State<StaminaElixirGlyph>
    with GlyphClockLease {
  @override
  bool get wantsClock => widget.animate;

  @override
  void initState() {
    super.initState();
    syncGlyphClock();
  }

  @override
  void didUpdateWidget(covariant StaminaElixirGlyph oldWidget) {
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
        painter: _StaminaElixirPainter(clock: glyphClock),
      ),
    );
  }
}

class _StaminaElixirPainter extends CustomPainter {
  _StaminaElixirPainter({required this.clock}) : super(repaint: clock);

  final ValueListenable<double>? clock;

  /// Reused across every frame and every glyph on screen.
  static final Paint _p = Paint();

  /// Charge, discharge, rest.
  static const double _period = 3.4;

  /// Where the loop starts.
  ///
  /// A still glyph sits at t = 0 — the shop grid bakes exactly that frame —
  /// and the loop's natural start is the spent, near-empty flask, which is the
  /// worst possible portrait of the item. Starting it charged means the baked
  /// frame is a full flask with the bolt lit.
  static const double _stillPhase = 0.36;

  static const _fluidTop = Color(0xFFC7F958);
  static const _fluidMid = Color(0xFF49D97E);
  static const _fluidDeep = Color(0xFF0E6B45);
  static const _glass = Color(0xFFCFE9F5);
  static const _spark = Color(0xFFF2FFC9);

  /// The flask, at one size. Rebuilding the outline every frame for an icon
  /// that never changes shape is the kind of allocation these glyphs draw
  /// dozens of, so it is cut once per size and kept.
  static final Map<int, Path> _flasks = <int, Path>{};

  double get _t => clock?.value ?? 0;

  static double _seed(int i, int salt) => ((i * 47 + salt * 13) % 100) / 100.0;

  static Path _flask(double s) => _flasks.putIfAbsent(s.round(), () {
    final body = Rect.fromCircle(
      center: Offset(s * 0.5, s * 0.635),
      radius: s * 0.275,
    );
    final neck = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.418, s * 0.185, s * 0.582, s * 0.50),
      Radius.circular(s * 0.03),
    );
    return Path.combine(
      PathOperation.union,
      Path()..addOval(body),
      Path()..addRRect(neck),
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;

    final beat = ((_t / _period) + _stillPhase) % 1.0;
    final flask = _flask(s);

    // Charge to full, hold at the top while the bolt winds up, empty out of
    // the neck, then sit low until the next cycle.
    final double level;
    if (beat < 0.50) {
      level = 0.20 + 0.68 * Curves.easeOutCubic.transform(beat / 0.50);
    } else if (beat < 0.66) {
      level = 0.88;
    } else if (beat < 0.82) {
      level = 0.88 - 0.68 * Curves.easeInCubic.transform((beat - 0.66) / 0.16);
    } else {
      level = 0.20;
    }

    // Peaks across the hold, which is when the bolt is brightest.
    final charge = beat < 0.50
        ? Curves.easeInQuad.transform(beat / 0.50)
        : beat < 0.72
        ? 1.0
        : (1 - (beat - 0.72) / 0.16).clamp(0.0, 1.0);

    canvas.save();
    canvas.clipPath(flask);
    _fluid(canvas, s, level, charge);
    _bubbles(canvas, s, level, beat);
    canvas.restore();

    _bolt(canvas, s, charge);
    _glassware(canvas, s, flask);
    if (beat >= 0.62 && beat < 0.86) {
      _discharge(canvas, s, (beat - 0.62) / 0.24);
    }
  }

  void _fluid(Canvas canvas, double s, double level, double charge) {
    // Level runs from the bottom of the body to the top of the neck.
    final topY = s * (0.91 - 0.66 * level);
    final rect = Rect.fromLTRB(0, topY, s, s);
    canvas.drawRect(
      rect,
      _p
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(_fluidTop, Colors.white, 0.35 * charge)!,
            _fluidMid,
            _fluidDeep,
          ],
          stops: const [0.0, 0.38, 1.0],
        ).createShader(rect),
    );
    _p.shader = null;

    // A bright meniscus, so the level reads as a surface rather than an edge.
    canvas.drawRect(
      Rect.fromLTRB(0, topY, s, topY + s * 0.022),
      _p..color = Color.lerp(_fluidTop, Colors.white, 0.55)!,
    );
  }

  void _bubbles(Canvas canvas, double s, double level, double beat) {
    final topY = s * (0.91 - 0.66 * level);
    for (var i = 0; i < 7; i++) {
      // Faster as the flask fills, so the charge is legible in the motion.
      final phase = (_t * (0.34 + 0.30 * level) + _seed(i, 2)) % 1.0;
      final y = s * 0.90 - (s * 0.90 - topY) * phase;
      if (y < topY) continue;
      final drift = math.sin(phase * math.pi * 3 + i) * s * 0.022;
      final x = s * (0.30 + 0.40 * _seed(i, 4)) + drift;
      final fade = phase > 0.82 ? (1 - phase) / 0.18 : 1.0;
      canvas.drawCircle(
        Offset(x, y),
        s * (0.014 + 0.010 * _seed(i, 6)),
        _p..color = Colors.white.withValues(alpha: 0.55 * fade),
      );
    }
  }

  /// The bolt the old icon carried, kept — but suspended in the fluid and
  /// winding up rather than stamped on the glass.
  void _bolt(Canvas canvas, double s, double charge) {
    final c = Offset(s * 0.5, s * 0.635);
    final h = s * 0.20 * (0.88 + 0.12 * charge);
    final w = s * 0.085;
    final path = Path()
      ..moveTo(c.dx + w * 0.35, c.dy - h)
      ..lineTo(c.dx - w, c.dy + h * 0.12)
      ..lineTo(c.dx - w * 0.10, c.dy + h * 0.12)
      ..lineTo(c.dx - w * 0.35, c.dy + h)
      ..lineTo(c.dx + w, c.dy - h * 0.14)
      ..lineTo(c.dx + w * 0.10, c.dy - h * 0.14)
      ..close();

    canvas.drawPath(
      path,
      _p..color = _spark.withValues(alpha: 0.35 + 0.60 * charge),
    );
    canvas.drawPath(
      path,
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.014
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withValues(alpha: 0.35 + 0.55 * charge),
    );
    _p.style = PaintingStyle.fill;
  }

  void _glassware(Canvas canvas, double s, Path flask) {
    canvas.drawPath(
      flask,
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.026
        ..color = _glass.withValues(alpha: 0.85),
    );
    _p.style = PaintingStyle.fill;

    // Cork band at the lip, so the neck ends in something.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(s * 0.392, s * 0.135, s * 0.608, s * 0.215),
        Radius.circular(s * 0.026),
      ),
      _p..color = const Color(0xFFC8A05A),
    );

    // One catchlight down the left of the body.
    canvas.save();
    canvas.translate(s * 0.375, s * 0.545);
    canvas.rotate(-0.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: s * 0.048,
        height: s * 0.16,
      ),
      _p..color = Colors.white.withValues(alpha: 0.35),
    );
    canvas.restore();
  }

  /// What comes out of the neck when it is spent.
  void _discharge(Canvas canvas, double s, double t) {
    final fade = 1 - Curves.easeInCubic.transform(t);
    if (fade <= 0.02) return;
    final origin = Offset(s * 0.5, s * 0.16);
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + (_seed(i, 8) - 0.5) * 1.5;
      final d = s * (0.06 + 0.16 * Curves.easeOutCubic.transform(t));
      final p = origin + Offset(math.cos(a) * d, math.sin(a) * d);
      canvas.drawCircle(
        p,
        s * 0.020 * fade,
        _p..color = _spark.withValues(alpha: 0.9 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StaminaElixirPainter old) => old.clock != clock;
}
