import 'package:alchemons/widgets/fx/celebration_particles.dart';
import 'dart:math' as math;
import 'dart:ui';

/// A ruby particle nose. Hosts supply the species/frame-specific snout point.
///
/// Its glass takes the picked [color]: the lit cap, the deep edge, the
/// glow and the grains are all made from it, in the same steps for every
/// colour. The highlight and the gold and violet bubbles stay as they are.
abstract final class AlchemicalClownNose {
  static final _particles = CelebrationParticles();
  static void paint(
    Canvas canvas,
    Offset center,
    double radius,
    double time, {
    double opacity = 1,
    Color color = const Color(0xFFEE254B),
  }) {
    if (radius <= 0 || opacity <= 0) return;
    _particles.clear();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    final pulse = 1 + 0.035 * math.sin(time * math.pi);
    canvas.scale(radius * pulse);
    final p = Paint();
    const gold = Color(0xFFFFD58B);
    const white = Color(0xFFFFFFFF);
    final lit = Color.lerp(color, white, 0.45)!;
    final grain = Color.lerp(color, white, 0.55)!;
    // Darkened evenly, so the edge keeps the colour's hue.
    final deep = Color.from(
      alpha: 1,
      red: color.r * 0.55,
      green: color.g * 0.55,
      blue: color.b * 0.55,
    );
    p.shader = Gradient.radial(Offset.zero, 1.7, [
      color.withValues(alpha: 0.3 * opacity),
      color.withValues(alpha: 0),
    ]);
    canvas.drawCircle(Offset.zero, 1.7, p);
    p.shader = Gradient.radial(
      const Offset(-0.3, -0.35),
      1.5,
      [
        lit.withValues(alpha: opacity),
        color.withValues(alpha: opacity),
        deep.withValues(alpha: opacity),
      ],
      [0, 0.5, 1],
    );
    canvas.drawCircle(Offset.zero, 0.86, p);
    p.shader = null;
    // Dense little grains give the round red silhouette an alchemical edge.
    for (var i = 0; i < 130; i++) {
      final angle = i * 2.399963 + time * math.pi / 4;
      final r = math.sqrt((i * 0.61803398875) % 1);
      final a = 0.25 + 0.55 * (0.5 + 0.5 * math.sin(i + time * math.pi));
      _particles.add(
        Offset(math.cos(angle) * r, math.sin(angle) * r),
        0.025 + (i % 3) * 0.012,
        i % 13 == 0 ? gold : grain,
        a * opacity,
      );
    }
    _particles.draw(canvas);
    p.color = const Color(0xFFFFE5DF).withValues(alpha: 0.85 * opacity);
    canvas.drawOval(const Rect.fromLTWH(-0.48, -0.52, 0.36, 0.21), p);
    // Small bubbles peel off the nose and dissolve above the snout.
    for (var i = 0; i < 5; i++) {
      final life = (time / 4 + i / 5) % 1;
      final at = Offset(
        -0.85 - math.sin(life * 3 + i) * 0.6,
        -0.25 - life * 2.1,
      );
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.035
        ..color = (i.isEven ? gold : const Color(0xFFC49AFF)).withValues(
          alpha: math.sin(life * math.pi) * 0.7 * opacity,
        );
      canvas.drawCircle(at, 0.08 + life * 0.10, p);
    }
    canvas.restore();
  }
}
