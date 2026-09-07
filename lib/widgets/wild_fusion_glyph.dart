import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Code-native artwork for the Wild Fusion catalyst.
///
/// Draws the alchemical conjunction: two element bodies circling a graduated
/// vessel, drawn together until they overlap into a single flare, then thrown
/// apart to begin again. The cycle is the item's whole purpose — one attempt
/// binds a party Alchemon to a wild one — rather than a generic glow.
class WildFusionGlyph extends StatefulWidget {
  const WildFusionGlyph({super.key, this.size = 48, this.animate = true});

  final double size;

  /// Grids render many of these at once; leave it off there and the glyph
  /// settles on a legible resting frame instead of running a ticker per cell.
  final bool animate;

  @override
  State<WildFusionGlyph> createState() => _WildFusionGlyphState();
}

class _WildFusionGlyphState extends State<WildFusionGlyph>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  @override
  void initState() {
    super.initState();
    if (widget.animate) _start();
  }

  @override
  void didUpdateWidget(WildFusionGlyph old) {
    super.didUpdateWidget(old);
    if (widget.animate && _ctrl == null) {
      _start();
    } else if (!widget.animate && _ctrl != null) {
      _ctrl!.dispose();
      _ctrl = null;
    }
  }

  void _start() {
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;
    // 0.42 sits mid-approach: both bodies visible and clearly converging,
    // which reads better as a still than the merged flash does.
    if (ctrl == null) {
      return SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(painter: const _WildFusionPainter(progress: 0.42)),
      );
    }
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: ctrl,
        builder: (context, _) =>
            CustomPaint(painter: _WildFusionPainter(progress: ctrl.value)),
      ),
    );
  }
}

class _WildFusionPainter extends CustomPainter {
  const _WildFusionPainter({required this.progress});

  final double progress;

  static const Color _wild = Color(0xFF4FD1C5); // the wild body
  static const Color _party = Color(0xFFFFA94D); // the party body
  static const Color _bond = Color(0xFFFFE9A8);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height / 2);

    // Approach for the first 74% of the cycle, then flare and reset.
    const mergeAt = 0.74;
    final approaching = progress < mergeAt;
    final approach = approaching
        ? Curves.easeInCubic.transform(progress / mergeAt)
        : 1.0;
    final flare = approaching
        ? 0.0
        : Curves.easeOutCubic.transform((progress - mergeAt) / (1 - mergeAt));
    final spin = progress * 2 * math.pi;

    // ── Vessel ──────────────────────────────────────────────────────────────
    final ringR = s * 0.42;
    canvas.drawCircle(
      c,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.016
        ..color = _bond.withValues(alpha: 0.42),
    );
    final tick = Paint()
      ..strokeWidth = s * 0.015
      ..strokeCap = StrokeCap.round
      ..color = _bond.withValues(alpha: 0.34);
    for (var i = 0; i < 8; i++) {
      final a = spin * 0.25 + i * math.pi / 4;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * ringR, c + dir * (ringR + s * 0.05), tick);
    }

    // ── The two bodies, drawn together ─────────────────────────────────────
    final sep = (1 - approach) * s * 0.30;
    final bodyR = s * 0.155 * (1 + approach * 0.25);
    final axis = spin;
    final offset = Offset(math.cos(axis), math.sin(axis)) * sep;

    void body(Offset at, Color colour) {
      canvas.drawCircle(
        at,
        bodyR * 1.5,
        Paint()
          ..color = colour.withValues(alpha: 0.30 * (1 - flare))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.06),
      );
      canvas.drawCircle(
        at,
        bodyR,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.95 * (1 - flare)),
              colour.withValues(alpha: 0.92 * (1 - flare)),
              colour.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(Rect.fromCircle(center: at, radius: bodyR)),
      );
    }

    body(c + offset, _wild);
    body(c - offset, _party);

    // The bond that pulls them in, brightest just before they meet.
    if (sep > 0.5) {
      canvas.drawLine(
        c + offset,
        c - offset,
        Paint()
          ..strokeWidth = s * 0.02
          ..strokeCap = StrokeCap.round
          ..color = _bond.withValues(alpha: 0.18 + 0.55 * approach),
      );
    }

    // ── Conjunction flare ──────────────────────────────────────────────────
    if (flare > 0) {
      canvas.drawCircle(
        c,
        s * (0.16 + 0.34 * flare),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.03 * (1 - flare)
          ..color = _bond.withValues(alpha: 0.9 * (1 - flare)),
      );
      canvas.drawCircle(
        c,
        s * 0.20 * (1 - flare * 0.4),
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.95 * (1 - flare)),
              _bond.withValues(alpha: 0.55 * (1 - flare)),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: c, radius: s * 0.20)),
      );
    }

    // ── Core, always present so the glyph never reads as empty ─────────────
    canvas.drawCircle(
      c,
      s * 0.055,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white, _bond.withValues(alpha: 0.85)],
        ).createShader(Rect.fromCircle(center: c, radius: s * 0.055)),
    );
  }

  @override
  bool shouldRepaint(_WildFusionPainter old) => old.progress != progress;
}
