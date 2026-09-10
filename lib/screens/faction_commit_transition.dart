import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/models/faction.dart';
import 'package:alchemons/widgets/animations/shaders/fire_animation.dart';
import 'package:flutter/material.dart';

/// The faction taking the screen, in its own voice.
///
/// This is the first animation in the game — it plays once, on the choice
/// that decides everything after it — so each faction gets the thing it
/// actually is rather than a tinted wipe. Fire burns up the screen, water
/// rains in and fills it, earth grows over it, air clouds it out.
///
/// Every one of them ends completely opaque. The dialog is popped underneath
/// while the screen is covered, so what the player sees is the new screen
/// arriving out of the element rather than the old one blinking away.
class FactionCommitTransition extends StatelessWidget {
  const FactionCommitTransition({
    super.key,
    required this.faction,
    required this.progress,
    required this.color,
    required this.accent,
  });

  final FactionId faction;

  /// 0 → 1 across the whole commit.
  final Animation<double> progress;
  final Color color;
  final Color accent;

  /// How long the whole thing runs. Long enough to read as an event, short
  /// enough that a player who already knows what they picked is not waiting
  /// on it.
  static const Duration duration = Duration(milliseconds: 1500);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) {
          final t = progress.value.clamp(0.0, 1.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              switch (faction) {
                FactionId.volcanic => _Burn(t: t, color: color, accent: accent),
                FactionId.oceanic => _Flood(t: t, color: color, accent: accent),
                FactionId.earthen => _Growth(
                  t: t,
                  color: color,
                  accent: accent,
                ),
                FactionId.verdant => _Clouds(
                  t: t,
                  color: color,
                  accent: accent,
                ),
              },
              // The last beat of every faction: settle to solid so the pop
              // underneath is invisible.
              if (t > 0.80)
                Opacity(
                  opacity: Curves.easeIn.transform(((t - 0.80) / 0.20)),
                  child: ColoredBox(color: color),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// VOLCANIC — the shader fire, climbing.
///
/// The flame itself is the game's own fire.frag, which already looks right;
/// what this adds is the climb. A wall of it rises from the floor, and the
/// screen scorches to black ahead of the flame front rather than after it,
/// the way paper darkens before it catches.
class _Burn extends StatelessWidget {
  const _Burn({required this.t, required this.color, required this.accent});

  final double t;
  final Color color;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    // The front runs ahead of the flame, so there is always char above fire.
    final front = Curves.easeInCubic.transform(t);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Char, laid down first and covering more than the flame reaches.
        Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: (front * 1.35).clamp(0.0, 1.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFF120703),
                    const Color(0xFF2A0F05).withValues(alpha: 0.92),
                    color.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ),
        // The flame wall.
        Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: (front * 1.05 + 0.06).clamp(0.0, 1.0),
            child: const ClipRect(
              child: FireFX(
                intensity: 1.25,
                turbulence: 1.5,
                rise: 0.9,
                speedFactor: 1.35,
              ),
            ),
          ),
        ),
        // A last flash as it takes the top of the screen.
        if (t > 0.55)
          Opacity(
            opacity:
                math.sin(((t - 0.55) / 0.45).clamp(0.0, 1.0) * math.pi) * 0.55,
            child: ColoredBox(color: accent),
          ),
      ],
    );
  }
}

/// OCEANIC — rain, then the water it leaves.
class _Flood extends StatelessWidget {
  const _Flood({required this.t, required this.color, required this.accent});

  final double t;
  final Color color;
  final Color accent;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _FloodPainter(t: t, color: color, accent: accent),
  );
}

class _FloodPainter extends CustomPainter {
  _FloodPainter({required this.t, required this.color, required this.accent});

  final double t;
  final Color color;
  final Color accent;

  static final Paint _p = Paint();
  static const int _drops = 90;

  @override
  void paint(Canvas canvas, Size size) {
    // Rain arrives first and thins out as the water it made takes over.
    final fall = (t / 0.55).clamp(0.0, 1.0);
    final level = Curves.easeInOutCubic.transform(
      ((t - 0.18) / 0.62).clamp(0.0, 1.0),
    );
    final surfaceY = size.height * (1 - level);

    if (fall < 1.0 || level < 1.0) {
      _p
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < _drops; i++) {
        // Golden-ratio spread: a plain modulo hash clumps into visible bands.
        final x = ((i * 0.6180339887) % 1.0) * size.width;
        final speed = 0.7 + ((i * 0.3819660113) % 1.0) * 0.9;
        final phase = (t * speed * 2.4 + (i * 0.2360679775) % 1.0) % 1.0;
        final y = phase * (size.height + 120) - 60;
        // A drop stops at the waterline rather than falling through it.
        if (y > surfaceY) continue;
        final len = size.height * (0.045 + 0.035 * speed);
        final alpha = 0.55 * fall * (1 - level * 0.7);
        if (alpha <= 0.01) continue;
        _p
          ..strokeWidth = 1.4 + speed * 0.9
          ..color = accent.withValues(alpha: alpha);
        canvas.drawLine(Offset(x, y), Offset(x, y + len), _p);
      }
      _p.style = PaintingStyle.fill;
    }

    if (level <= 0) return;

    // The body of water, with a surface that is never a straight line.
    final path = Path()..moveTo(0, surfaceY);
    const steps = 24;
    final amp = size.height * 0.018 * (1 - level * 0.6);
    for (var i = 0; i <= steps; i++) {
      final x = size.width * i / steps;
      final y =
          surfaceY +
          math.sin(i * 0.7 + t * 9) * amp +
          math.sin(i * 0.31 - t * 6) * amp * 0.6;
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    _p.shader =
        ui.Gradient.linear(Offset(0, surfaceY), Offset(0, size.height), [
          Color.lerp(accent, color, 0.35)!.withValues(alpha: 0.92),
          color.withValues(alpha: 0.98),
        ]);
    canvas.drawPath(path, _p);
    _p.shader = null;

    // Foam along the surface, so the waterline reads as a surface.
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = Colors.white.withValues(alpha: 0.35 * (1 - level));
    canvas.drawPath(path, _p);
    _p.style = PaintingStyle.fill;
  }

  @override
  bool shouldRepaint(covariant _FloodPainter old) => old.t != t;
}

/// EARTHEN — vines out of the ground, over everything.
class _Growth extends StatelessWidget {
  const _Growth({required this.t, required this.color, required this.accent});

  final double t;
  final Color color;
  final Color accent;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _GrowthPainter(t: t, color: color, accent: accent),
  );
}

class _GrowthPainter extends CustomPainter {
  _GrowthPainter({required this.t, required this.color, required this.accent});

  final double t;
  final Color color;
  final Color accent;

  static final Paint _p = Paint();
  static const int _vines = 14;

  @override
  void paint(Canvas canvas, Size size) {
    // Soil rising behind the vines, so they are growing out of something.
    final soil = Curves.easeInCubic.transform(((t - 0.35) / 0.65).clamp(0, 1));
    if (soil > 0) {
      _p
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: 0.95);
      canvas.drawRect(
        Rect.fromLTWH(
          0,
          size.height * (1 - soil),
          size.width,
          size.height * soil,
        ),
        _p,
      );
    }

    _p
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < _vines; i++) {
      // Staggered starts: they do not sprout in unison.
      final stagger = ((i * 0.6180339887) % 1.0) * 0.28;
      final grow = ((t - stagger) / (1 - stagger)).clamp(0.0, 1.0);
      if (grow <= 0) continue;
      final reach = Curves.easeOutCubic.transform(grow);

      final x0 = size.width * (i + 0.5) / _vines;
      // Each vine leans its own way and waves at its own rate.
      final lean = (((i * 0.3819660113) % 1.0) - 0.5) * size.width * 0.22;
      final wobble = 0.8 + ((i * 0.2360679775) % 1.0) * 1.6;

      final path = Path()..moveTo(x0, size.height);
      const steps = 18;
      for (var s = 1; s <= steps; s++) {
        final u = s / steps;
        final y = size.height * (1 - reach * u * 1.08);
        final x =
            x0 +
            lean * u * u +
            math.sin(u * math.pi * wobble + i) * size.width * 0.035 * u;
        path.lineTo(x, y);
      }

      _p
        ..strokeWidth = size.shortestSide * (0.020 + 0.014 * ((i % 3) / 2))
        ..color = Color.lerp(
          color,
          accent,
          (i % 3) / 3,
        )!.withValues(alpha: 0.95);
      canvas.drawPath(path, _p);

      // Leaves, appearing along the stem as it passes them.
      _p.style = PaintingStyle.fill;
      for (var l = 1; l <= 4; l++) {
        final at = l / 5;
        if (reach < at) break;
        final u = at;
        final y = size.height * (1 - reach * u * 1.08);
        final x =
            x0 +
            lean * u * u +
            math.sin(u * math.pi * wobble + i) * size.width * 0.035 * u;
        final open = ((reach - at) * 6).clamp(0.0, 1.0);
        final r = size.shortestSide * 0.030 * open;
        final side = l.isEven ? 1 : -1;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x + side * r * 1.1, y),
            width: r * 2.2,
            height: r * 1.1,
          ),
          _p..color = accent.withValues(alpha: 0.9 * open),
        );
      }
      _p.style = PaintingStyle.stroke;
    }
    _p.style = PaintingStyle.fill;
  }

  @override
  bool shouldRepaint(covariant _GrowthPainter old) => old.t != t;
}

/// VERDANT — cloud forming and turning over itself.
class _Clouds extends StatelessWidget {
  const _Clouds({required this.t, required this.color, required this.accent});

  final double t;
  final Color color;
  final Color accent;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _CloudPainter(t: t, color: color, accent: accent),
  );
}

class _CloudPainter extends CustomPainter {
  _CloudPainter({required this.t, required this.color, required this.accent});

  final double t;
  final Color color;
  final Color accent;

  static final Paint _p = Paint();
  static const int _puffs = 46;

  @override
  void paint(Canvas canvas, Size size) {
    final grow = Curves.easeOutCubic.transform(t);
    final centre = Offset(size.width / 2, size.height * 0.42);
    final spread = size.longestSide * 0.78 * grow;

    _p.style = PaintingStyle.fill;
    for (var i = 0; i < _puffs; i++) {
      // Each puff rides its own arm of the swirl and turns as the whole
      // thing turns — the rotation is what makes it read as weather rather
      // than a growing blob.
      final u = (i * 0.6180339887) % 1.0;
      final v = (i * 0.3819660113) % 1.0;
      final arm = u * math.pi * 6;
      final turn = t * math.pi * 1.6;
      final dist = spread * (0.15 + v * 0.95);
      final angle = arm + turn * (1.0 - v * 0.45);

      final pos =
          centre +
          Offset(math.cos(angle) * dist, math.sin(angle) * dist * 0.62);
      // Late puffs are still swelling when the early ones are full.
      final born = ((t - u * 0.35) / 0.4).clamp(0.0, 1.0);
      if (born <= 0) continue;
      final r = size.shortestSide * (0.09 + v * 0.13) * born;

      canvas.drawCircle(
        pos,
        r,
        _p
          ..color = Color.lerp(
            color,
            accent,
            v * 0.7,
          )!.withValues(alpha: 0.42 * born),
      );
      // A lighter crown on the upper edge, which is where light lands.
      canvas.drawCircle(
        pos.translate(0, -r * 0.22),
        r * 0.66,
        _p..color = Colors.white.withValues(alpha: 0.10 * born),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CloudPainter old) => old.t != t;
}
