import 'package:alchemons/widgets/fx/celebration_particles.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A cosmetic layer independent of the creature's genetics and aura.
/// [base] is the head attachment point; hosts own frame-specific placement.
///
/// A solid cone sitting on the head, not a glass one: anything the head
/// carries (flames, a crest, horns) stays behind it, so it reads as worn.
/// The grains that fall on its far side are hidden by it, the ones on its
/// near side glitter over it.
abstract final class AlchemicalPartyHat {
  static final _particles = CelebrationParticles();

  // The hat's own space: 100 across the brim, the tip 115 above it.
  static const double _half = 49, _tall = 115;
  static final Path _cone = Path()
    ..moveTo(-_half, 0)
    ..lineTo(0, -_tall)
    ..lineTo(_half, 0)
    ..quadraticBezierTo(0, 15, -_half, 0)
    ..close();

  /// Dark velvet, shaded along the rays from the tip as a cone is: lit on
  /// its left flank, falling off to the right, so the grains are what
  /// shine on it. The ramp is the picked color (the lit flank) darkened in
  /// the same steps for every color; one shader per color, kept.
  static const _ramp = [0.18, 0.39, 0.68, 1.0, 0.51];
  static final Map<int, Shader> _bodies = {};
  static final Paint _bodyPaint = Paint();

  static Shader _body(Color velvet) {
    final key = velvet.toARGB32();
    final kept = _bodies[key];
    if (kept != null) return kept;
    // A screenful of hats in a handful of colors; a long session of
    // recoloring should not grow this without end.
    if (_bodies.length >= 32) _bodies.clear();
    return _bodies[key] = ui.Gradient.sweep(
      const Offset(0, -_tall),
      [
        for (final k in _ramp)
          Color.from(
            alpha: 1,
            red: velvet.r * k,
            green: velvet.g * k,
            blue: velvet.b * k,
          ),
      ],
      const [0.0, 0.35, 0.62, 0.8, 1.0],
      TileMode.clamp,
      math.atan2(_tall, _half),
      math.atan2(_tall, -_half),
    );
  }

  static void paint(
    Canvas canvas,
    Offset base,
    double width,
    double time, {
    double opacity = 1,
    double tilt = 0,
    Color velvet = const Color(0xFF4C3388),
  }) {
    if (width <= 0 || opacity <= 0) return;
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.scale(width / 100);
    canvas.rotate(-0.10 + tilt);
    const violet = Color(0xFFC4A2FF);
    const cyan = Color(0xFF94F5EB);
    const gold = Color(0xFFFFD58B);
    void mote(Offset at, double radius, Color color, double alpha) {
      _particles.add(at, radius, color, alpha * opacity);
    }

    // The far half of the brim, behind the body.
    _particles.clear();
    for (var i = 50; i < 100; i++) {
      final a = i / 100 * math.pi * 2;
      mote(Offset(math.cos(a) * _half, math.sin(a) * 10), 1.0, gold, 0.6);
    }
    _particles.draw(canvas);

    canvas.drawPath(
      _cone,
      _bodyPaint
        ..shader = _body(velvet)
        ..color = Color.fromRGBO(0, 0, 0, opacity.clamp(0.0, 1.0)),
    );

    // Everything on the near side, over it.
    _particles.clear();
    for (var i = 0; i < 280; i++) {
      // Spread evenly over the cone (an R2 sequence): a golden-angle turn
      // with a golden-ratio height ties every grain to one helix, which
      // the solid body cuts down to a single streak.
      final angle = (i * 0.7548776662 % 1) * math.pi * 2 + time * 0.5;
      // Only the near face shows.
      if (math.sin(angle) < 0) continue;
      final h = ((i * 0.5698402910 + time / 8) % 1);
      final spread = _half * (1 - h);
      final at = Offset(
        math.cos(angle) * spread * 0.92,
        -_tall * h + math.sin(angle) * spread * 0.15,
      );
      final sparkle = 0.5 + 0.5 * math.sin(time * math.pi + i * 1.7);
      // Hashed, not every ninth: that lines up into a streak.
      final tint = (math.sin(i * 12.9898) * 43758.5453) % 1;
      mote(
        at,
        0.55 + sparkle * 0.6,
        tint.abs() < 0.12 ? cyan : violet,
        0.25 + sparkle * 0.65,
      );
    }
    // Grains along the flanks keep the shape readable at small sizes.
    for (var i = 0; i < 42; i++) {
      final h = i / 41;
      for (final side in [-1.0, 1.0]) {
        mote(
          Offset(side * _half * (1 - h), -_tall * h),
          0.8,
          violet,
          0.3 + 0.25 * math.sin(i + time * math.pi).abs(),
        );
      }
    }
    for (var i = 0; i < 50; i++) {
      final a = i / 100 * math.pi * 2;
      mote(Offset(math.cos(a) * _half, math.sin(a) * 10), 1.1, gold, 0.9);
    }
    // Three spiral bands wind round it; the far turns go behind.
    for (var band = 0; band < 3; band++) {
      for (var i = 0; i < 32; i++) {
        final h = (band + i / 32) / 3;
        final a = h * math.pi * 6 + time * math.pi / 2;
        if (math.sin(a) < 0) continue;
        mote(
          Offset(
            math.cos(a) * (_half + 1) * (1 - h),
            -_tall * h + math.sin(a) * 7,
          ),
          1.15,
          gold,
          0.95,
        );
      }
    }
    // Tiny orbiting grains above the tip, instead of a solid pom-pom.
    for (var i = 0; i < 18; i++) {
      final a = i * 2.4 + time * math.pi / 2;
      final r = 3.0 + i % 5;
      mote(
        Offset(math.cos(a) * r, -_tall - 4 + math.sin(a) * r),
        1.2,
        gold,
        0.8,
      );
    }
    mote(const Offset(0, -_tall - 4), 2.2, const Color(0xFFFFF2CE), 1);
    _particles.draw(canvas);
    canvas.restore();
  }
}

/// Optional overlay for a sprite. Attachment coordinates are fractions of its
/// layout box, so the same hat can be fitted to different species.
class AlchemicalPartyHatView extends StatefulWidget {
  const AlchemicalPartyHatView({
    super.key,
    required this.child,
    this.attachment = const Offset(0.5, 0.22),
    this.widthFraction = 0.36,
  });
  final Widget child;
  final Offset attachment;
  final double widthFraction;
  @override
  State<AlchemicalPartyHatView> createState() => _HatState();
}

class _HatState extends State<AlchemicalPartyHatView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();
  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      foregroundPainter: _HatPainter(
        _clock,
        widget.attachment,
        widget.widthFraction,
      ),
      child: widget.child,
    ),
  );
}

class _HatPainter extends CustomPainter {
  _HatPainter(this.clock, this.attachment, this.width) : super(repaint: clock);
  final Animation<double> clock;
  final Offset attachment;
  final double width;
  @override
  void paint(Canvas canvas, Size size) => AlchemicalPartyHat.paint(
    canvas,
    Offset(size.width * attachment.dx, size.height * attachment.dy),
    size.width * width,
    clock.value * 8,
  );
  @override
  bool shouldRepaint(_HatPainter old) =>
      old.attachment != attachment || old.width != width || old.clock != clock;
}
