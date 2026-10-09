// lib/games/cosmic_survival/components/survival_hud.dart
//
// The run's HUD, in the ship console's language: plain dark glass, lit from
// below when it is the live thing, readings in spaced monospace, and gauges
// as glass tubes with matter settled in them (the space HUD's meter tube)
// rather than flat bars. The orb's gauge is lit in the core's own light, the
// same color as the ring of cells round the core in the arena.

import 'dart:math';
import 'dart:ui' show PointMode;

import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';

/// Ink and glass for the HUD.
class HudInk {
  static const glass = Color(0xFF0B0B10);
  static const line = Color(0xFF3A3A48);
  static const ink = Color(0xFFF4EEDF);
  static const muted = Color(0xFF9A93A6);
  static const amber = Color(0xFFE4B356);
  static const danger = Color(0xFFFF6B5E);

  /// The ship's own color: the pale steel of its hull's lit edge.
  static const ship = Color(0xFF8FC9D6);
}

TextStyle hudMono(
  double size,
  Color color, {
  FontWeight weight = FontWeight.w800,
  double spacing = 1.2,
}) => TextStyle(
  fontFamily: 'monospace',
  color: color,
  fontSize: size,
  fontWeight: weight,
  letterSpacing: spacing,
  height: 1.1,
);

/// A pane of the HUD's dark glass, lit from below in [accent] when that is
/// a color of its own (the plain [HudInk.line] draws nothing).
class HudGlass extends StatelessWidget {
  const HudGlass({
    super.key,
    required this.child,
    this.accent = HudInk.line,
    this.padding = EdgeInsets.zero,
    this.bracket = 7,
    this.alpha = 0.86,
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final double bracket;
  final double alpha;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: BracketFramePainter(
      color: accent,
      bracketSize: bracket,
      strokeWidth: 1.1,
    ),
    child: Container(
      padding: padding,
      color: HudInk.glass.withValues(alpha: alpha),
      child: child,
    ),
  );
}

/// A square key on the console. [lit] when what it toggles is on.
class HudKey extends StatelessWidget {
  const HudKey({
    super.key,
    required this.icon,
    required this.onTap,
    this.lit = false,
    this.size = 44,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool lit;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final key = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: HudGlass(
        accent: lit
            ? HudInk.amber.withValues(alpha: 0.9)
            : HudInk.line.withValues(alpha: 0.9),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: size * 0.42,
            color: lit ? HudInk.amber : HudInk.muted,
          ),
        ),
      ),
    );
    return tooltip == null ? key : Tooltip(message: tooltip!, child: key);
  }
}

/// A gauge: what it measures, a glass tube filled as far as [fraction],
/// and the figure.
class HudGauge extends StatelessWidget {
  const HudGauge({
    super.key,
    required this.label,
    required this.fraction,
    required this.color,
    this.figure,
  });

  final String label;
  final double fraction;
  final Color color;

  /// Written after the tube; the percentage when left out.
  final String? figure;

  @override
  Widget build(BuildContext context) {
    final f = fraction.clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 34,
          child: Text(label, style: hudMono(9, HudInk.muted)),
        ),
        Expanded(
          child: SizedBox(
            height: 8,
            child: CustomPaint(painter: HudTubePainter(f, color)),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 30,
          child: Text(
            figure ?? '${(f * 100).round()}',
            textAlign: TextAlign.right,
            style: hudMono(
              10,
              f < 0.25 ? HudInk.danger : HudInk.ink,
              spacing: 0.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// A glass tube with [color]'s matter in it as far as [fraction]: lit at the
/// top, deep at the bottom, grains settled through it, and the glass's own
/// highlight over all of it.
class HudTubePainter extends CustomPainter {
  HudTubePainter(this.fraction, this.color);

  final double fraction;
  final Color color;

  static final Paint _p = Paint();
  static final Paint _grain = Paint()
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    _p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Color(0xFF1A1B26), Color(0xFF08090E), Color(0xFF12131C)],
      stops: const [0.0, 0.6, 1.0],
    ).createShader(rect);
    canvas.drawRect(rect, _p);

    final w = size.width * fraction;
    if (w > 0.5) {
      final band = Rect.fromLTWH(0, 0, w, size.height);
      final hsl = HSLColor.fromColor(
        Color.lerp(color, const Color(0xFF16141E), 0.15)!,
      );
      final mid = hsl.toColor();
      final lit = hsl
          .withLightness((hsl.lightness + 0.2).clamp(0.0, 0.88))
          .toColor();
      final deep = hsl
          .withLightness((hsl.lightness * 0.42).clamp(0.0, 1.0))
          .toColor();
      _p.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [lit, mid, deep],
        stops: const [0.0, 0.42, 1.0],
      ).createShader(band);
      canvas.drawRect(band, _p);
      // Grains settled in it — fixed places, so a still gauge is still.
      _grain
        ..strokeWidth = 1.3
        ..color = lit.withValues(alpha: 0.8);
      final pts = <Offset>[];
      for (var i = 0; i * 3.4 < w - 1; i++) {
        final h = ((i * 7919) % 97) / 97;
        pts.add(Offset(i * 3.4 + h * 2.4, size.height * (0.2 + 0.7 * h)));
      }
      canvas.drawPoints(PointMode.points, pts, _grain);
      // The meniscus: the matter's leading edge catches the light.
      _p
        ..shader = null
        ..color = lit.withValues(alpha: 0.9);
      canvas.drawRect(Rect.fromLTWH(w - 1.2, 0, 1.2, size.height), _p);
    }

    _p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x26FFFFFF), Color(0x00FFFFFF)],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.4));
    canvas.drawRect(Rect.fromLTWH(0, 0.5, size.width, size.height * 0.4), _p);
    _p.shader = null;
  }

  @override
  bool shouldRepaint(HudTubePainter old) =>
      old.fraction != fraction || old.color != color;
}

/// The run's top line: the wave and the clock, the console's keys, and the
/// ship's and the orb's gauges.
class SurvivalTopHud extends StatelessWidget {
  const SurvivalTopHud({
    super.key,
    required this.wave,
    required this.time,
    required this.keys,
    required this.shipFraction,
    required this.shipGhost,
    required this.orbFraction,
    required this.orbColor,
  });

  final int wave;
  final String time;
  final List<Widget> keys;
  final double shipFraction;
  final bool shipGhost;
  final double orbFraction;
  final Color orbColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        HudGlass(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('WAVE ', style: hudMono(8.5, HudInk.muted)),
                  Text(
                    '$wave',
                    style: hudMono(17, HudInk.amber, weight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(time, style: hudMono(10, HudInk.ink, spacing: 1.0)),
            ],
          ),
        ),
        const SizedBox(width: 6),
        for (final k in keys) ...[k, const SizedBox(width: 6)],
        const SizedBox(width: 2),
        Expanded(
          child: HudGlass(
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HudGauge(
                  label: shipGhost ? 'GHOST' : 'SHIP',
                  fraction: shipGhost ? 1 : shipFraction,
                  color: HudInk.ship,
                  figure: shipGhost ? '—' : null,
                ),
                const SizedBox(height: 7),
                HudGauge(label: 'ORB', fraction: orbFraction, color: orbColor),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The detonation key: a sphere of dark glass that fills with molten matter
/// as the charge builds, its surface catching the light. Full, it burns —
/// a pool of its light behind it and the glass's limb lit — instead of a
/// progress ring and a blurred glow.
class DetonationVesselPainter extends CustomPainter {
  DetonationVesselPainter({required this.charge, required this.ready});

  final double charge;
  final bool ready;

  static const _deep = Color(0xFF3A1206);
  static const _melt = Color(0xFFD9602E);
  static const _hot = Color(0xFFFFC27A);
  static final Paint _p = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 4;
    final f = charge.clamp(0.0, 1.0);

    if (ready) {
      _p.shader = RadialGradient(
        colors: [
          _melt.withValues(alpha: 0.45),
          _melt.withValues(alpha: 0.12),
          _melt.withValues(alpha: 0),
        ],
        stops: const [0.4, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r + 4));
      canvas.drawCircle(c, r + 4, _p);
    }

    // The empty glass.
    _p.shader = RadialGradient(
      center: const Alignment(-0.3, -0.4),
      colors: const [Color(0xFF1C1A22), Color(0xFF0A090D), Color(0xFF050407)],
      stops: const [0.0, 0.7, 1.0],
    ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, _p);

    // The melt, up to its level.
    if (f > 0.01) {
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
      final top = c.dy + r - 2 * r * f;
      final body = Rect.fromLTRB(c.dx - r, top, c.dx + r, c.dy + r);
      _p.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [ready ? _hot : _melt, _melt, _deep],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(body);
      canvas.drawRect(body, _p);
      // Its surface, seen a little from above.
      _p
        ..shader = null
        ..color = _hot.withValues(alpha: ready ? 0.9 : 0.6);
      final half = sqrt(max(0.0, r * r - (top - c.dy) * (top - c.dy)));
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(c.dx, top),
          width: half * 2,
          height: max(1.5, half * 0.18),
        ),
        _p,
      );
      canvas.restore();
    }

    // The glass's limb and its glint.
    _p.shader = RadialGradient(
      colors: [
        const Color(0x00FFFFFF),
        const Color(0x00FFFFFF),
        (ready ? _hot : const Color(0xFF9A93A6)).withValues(
          alpha: ready ? 0.55 : 0.28,
        ),
        const Color(0x00FFFFFF),
      ],
      stops: const [0.0, 0.84, 0.96, 1.0],
    ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, _p);
    _p
      ..shader = null
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.16);
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(-r * 0.32, -r * 0.5),
        width: r * 0.62,
        height: r * 0.26,
      ),
      _p,
    );
    _p.shader = null;
  }

  @override
  bool shouldRepaint(DetonationVesselPainter old) =>
      old.charge != charge || old.ready != ready;
}
