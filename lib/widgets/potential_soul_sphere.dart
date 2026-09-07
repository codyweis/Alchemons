import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared code-native artwork for Potential Souls in inventory, rewards and
/// Stat Infusion.
///
/// Drawn as an alchemical molecule rather than a plain marble: a bonded
/// nucleus inside three orbital shells, held in a graduated containment ring.
/// [tint] recolours the shells and aura so a soul can be shown against a
/// specific stat; null keeps the canonical violet.
///
/// [animate] spins the shells and is meant for the one hero instance on a
/// screen — inventory grids render many of these at once and leave it off.
class PotentialSoulSphere extends StatefulWidget {
  const PotentialSoulSphere({
    super.key,
    this.size = 48,
    this.tint,
    this.animate = false,
  });

  final double size;
  final Color? tint;
  final bool animate;

  @override
  State<PotentialSoulSphere> createState() => _PotentialSoulSphereState();
}

class _PotentialSoulSphereState extends State<PotentialSoulSphere>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  @override
  void initState() {
    super.initState();
    if (widget.animate) _startTicker();
  }

  @override
  void didUpdateWidget(PotentialSoulSphere oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && _ctrl == null) {
      _startTicker();
    } else if (!widget.animate && _ctrl != null) {
      _ctrl!.dispose();
      _ctrl = null;
    }
  }

  void _startTicker() {
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tint = widget.tint ?? const Color(0xFFB66CFF);
    final ctrl = _ctrl;
    if (ctrl == null) {
      return _buildSphere(tint, 0);
    }
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) => _buildSphere(tint, ctrl.value),
    );
  }

  Widget _buildSphere(Color tint, double progress) {
    final pulse = 0.5 + 0.5 * math.sin(progress * math.pi * 2);
    return SizedBox.square(
      dimension: widget.size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.22 + pulse * 0.08),
              tint.withValues(alpha: 0.20 + pulse * 0.08),
              tint.withValues(alpha: 0.04),
              Colors.transparent,
            ],
            stops: const [0.0, 0.38, 0.72, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: tint.withValues(alpha: 0.46 + pulse * 0.18),
              blurRadius: widget.size * (0.30 + pulse * 0.10),
              spreadRadius: widget.size * (0.045 + pulse * 0.035),
            ),
            BoxShadow(
              color: const Color(
                0xFFFFE9A8,
              ).withValues(alpha: 0.16 + pulse * 0.10),
              blurRadius: widget.size * 0.16,
              spreadRadius: widget.size * 0.015,
            ),
          ],
        ),
        child: CustomPaint(
          painter: _SoulMoleculePainter(progress: progress, tint: tint),
        ),
      ),
    );
  }
}

class _SoulMoleculePainter extends CustomPainter {
  const _SoulMoleculePainter({required this.progress, required this.tint});

  final double progress;
  final Color tint;

  static const Color _gold = Color(0xFFFFE9A8);
  static const Color _core = Color(0xFFFFF6D2);
  static const Color _deep = Color(0xFF2A0E4A);

  Offset _onShell(Offset c, double rx, double ry, double tilt, double angle) {
    final x = rx * math.cos(angle);
    final y = ry * math.sin(angle);
    return Offset(
      c.dx + x * math.cos(tilt) - y * math.sin(tilt),
      c.dy + x * math.sin(tilt) + y * math.cos(tilt),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height / 2);
    final spin = progress * 2 * math.pi;

    // ── Aura ────────────────────────────────────────────────────────────────
    canvas.drawCircle(
      c,
      s * 0.48,
      Paint()
        ..shader = RadialGradient(
          colors: [
            tint.withValues(alpha: 0.34),
            tint.withValues(alpha: 0.12),
            Colors.transparent,
          ],
          stops: const [0.0, 0.62, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: s * 0.48)),
    );

    // ── Vessel: containment ring plus graduation ticks ──────────────────────
    final ringR = s * 0.40;
    canvas.drawCircle(
      c,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.018
        ..color = _gold.withValues(alpha: 0.55),
    );
    final tick = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.016
      ..strokeCap = StrokeCap.round
      ..color = _gold.withValues(alpha: 0.42);
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * ringR, c + dir * (ringR + s * 0.045), tick);
    }

    // ── Orbital shells ──────────────────────────────────────────────────────
    final rx = s * 0.34;
    final ry = s * 0.13;
    for (var i = 0; i < 3; i++) {
      final tilt = spin * 0.5 + i * math.pi / 3;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(tilt);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.015
          ..color = tint.withValues(alpha: 0.34 + 0.16 * i),
      );
      canvas.restore();
    }

    // ── Bonded nucleus: hexagon with spokes ─────────────────────────────────
    final hexR = s * 0.155;
    final hex = Path();
    final verts = <Offset>[];
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + i * math.pi / 3 - spin * 0.35;
      final p = c + Offset(math.cos(a), math.sin(a)) * hexR;
      verts.add(p);
      if (i == 0) {
        hex.moveTo(p.dx, p.dy);
      } else {
        hex.lineTo(p.dx, p.dy);
      }
    }
    hex.close();
    canvas.drawPath(
      hex,
      Paint()
        ..style = PaintingStyle.fill
        ..color = _deep.withValues(alpha: 0.55),
    );
    canvas.drawPath(
      hex,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.016
        ..color = _gold.withValues(alpha: 0.72),
    );
    final bond = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.012
      ..color = _gold.withValues(alpha: 0.5);
    final node = Paint()..color = _gold;
    for (final v in verts) {
      canvas.drawLine(c, v, bond);
      canvas.drawCircle(v, s * 0.026, node);
    }

    // ── Electrons riding the shells ─────────────────────────────────────────
    for (var i = 0; i < 3; i++) {
      final tilt = spin * 0.5 + i * math.pi / 3;
      final p = _onShell(c, rx, ry, tilt, spin * 1.6 + i * 2 * math.pi / 3);
      canvas.drawCircle(
        p,
        s * 0.055,
        Paint()
          ..color = tint.withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.045),
      );
      canvas.drawCircle(p, s * 0.032, Paint()..color = _core);
    }

    // ── Core ────────────────────────────────────────────────────────────────
    canvas.drawCircle(
      c,
      s * 0.085,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white, _core, tint.withValues(alpha: 0.9)],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: s * 0.085)),
    );
    canvas.drawCircle(
      c,
      s * 0.13,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.01
        ..color = _core.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(_SoulMoleculePainter old) =>
      old.progress != progress || old.tint != tint;
}
