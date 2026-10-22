import 'package:alchemons/widgets/fx/celebration_particles.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A cosmetic layer independent of the creature's genetics and aura.
/// [base] is the head attachment point; hosts own frame-specific placement.
///
/// A solid cone sitting on the head, not a glass one: anything the head
/// carries (flames, a crest, horns) stays behind it, so it reads as worn.
///
/// A cone of night sky (user 2026-10-22: "more alchemical"): through its
/// velvet, a nebula in the hat's own color drifts and two depths of stars
/// pass slowly, as the sky turns, the way the Starlit mutation holds a
/// night sky in a body. Its gold spiral stays put while grains of gold
/// run up it, and at the tip they go up as a thin wisp of stardust that
/// thins and goes out.
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

  /// The sky's grains, in the cone's space, laid once: (x, y, depth,
  /// size, twinkle phase). Depth 0 is far and slow, 1 near and quicker.
  static final List<(double, double, double, double, double)> _stars = [
    for (var i = 0; i < 120; i++)
      (
        (_hash(i, 1) * 2 - 1) * _half * 1.1,
        -_tall * _hash(i, 2),
        _hash(i, 3) < 0.65 ? 0.0 : 1.0,
        _hash(i, 4) < 0.9 ? 0.5 + 0.35 * _hash(i, 5) : 1.15,
        _hash(i, 6) * math.pi * 2,
      ),
  ];

  static double _hash(int i, int salt) {
    final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  /// Where on the gold spiral [h] of the way up (0 the brim, 1 the tip)
  /// is, for [band] of three, and whether that is on the near side.
  static (Offset, bool) _spiral(int band, double h) {
    final a = h * math.pi * 6 + band * math.pi * 2 / 3;
    return (
      Offset(
        math.cos(a) * (_half + 1) * (1 - h),
        -_tall * h + math.sin(a) * 7 * (1 - h * 0.6),
      ),
      math.sin(a) >= 0,
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
    const star = Color(0xFFFFF8EC);
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

    // Through the velvet, the night sky: a nebula in the hat's own color
    // and two depths of stars, all drifting slowly across as the sky
    // turns, wrapping round, so the cone is a window and not a print.
    canvas.save();
    canvas.clipPath(_cone);
    _particles.clear();
    final glow = Color.lerp(velvet, const Color(0xFFFFFFFF), 0.4)!;
    const span = _half * 2.2;
    double wrap(double x) => (x + span / 2) % span - span / 2;
    for (var i = 0; i < 4; i++) {
      mote(
        Offset(
          wrap(_hash(i, 21) * span + time * 1.6),
          -_tall * (0.15 + 0.6 * _hash(i, 22)) +
              4 * math.sin(time * 0.3 + i * 1.9),
        ),
        12 + 8 * _hash(i, 23),
        i == 3 ? const Color(0xFF3FA6C8) : (i.isEven ? glow : violet),
        i == 3 ? 0.07 : 0.12,
      );
    }
    for (final (x, y, depth, size, phase) in _stars) {
      final twinkle = 0.55 + 0.45 * math.sin(time * (1.1 + depth) + phase);
      mote(
        Offset(wrap(x + time * (1.2 + 2.6 * depth)), y),
        size * (0.85 + 0.15 * twinkle),
        size > 1 ? star : (phase < 0.6 ? cyan : violet),
        (0.45 + 0.45 * depth) * twinkle,
      );
    }
    _particles.draw(canvas);
    canvas.restore();

    // Everything on the near side, over it.
    _particles.clear();
    // Grains along the flanks keep the shape readable at small sizes.
    for (var i = 0; i < 42; i++) {
      final h = i / 41;
      for (final side in [-1.0, 1.0]) {
        mote(
          Offset(side * _half * (1 - h), -_tall * h),
          0.8,
          violet,
          0.22 + 0.18 * math.sin(i + time * math.pi).abs(),
        );
      }
    }
    for (var i = 0; i < 50; i++) {
      final a = i / 100 * math.pi * 2;
      mote(Offset(math.cos(a) * _half, math.sin(a) * 10), 1.1, gold, 0.9);
    }
    // The gold spiral, held still, faint; the far turns go behind.
    for (var band = 0; band < 3; band++) {
      for (var i = 0; i < 32; i++) {
        final (at, near) = _spiral(band, (i + 0.5) / 32);
        if (near) mote(at, 1.1, gold, 0.75);
      }
      // Grains of gold running up it, each with a short fading trail,
      // quickening toward the tip; round the back they go behind.
      for (var k = 0; k < 4; k++) {
        final s = (time / 5.5 + k / 4 + band / 12) % 1;
        for (var j = 2; j >= 0; j--) {
          final h = math.pow(s - j * 0.014, 1.2).toDouble();
          if (s - j * 0.014 <= 0) continue;
          final (at, near) = _spiral(band, h);
          if (!near) continue;
          mote(
            at,
            1.9 - j * 0.4,
            j == 0 ? const Color(0xFFFFF2CE) : gold,
            (j == 0 ? 1.0 : 0.55 - j * 0.12) * math.min(1.0, s * 8),
          );
        }
      }
    }
    // Off the tip, a thin wisp of stardust: each grain rises, slowing,
    // wavering, cooling from gold into the hat's own light, and goes out.
    for (var i = 0; i < 12; i++) {
      final u = (time / (2.6 + 1.0 * _hash(i, 31)) + _hash(i, 32)) % 1;
      final rise = 1 - (1 - u) * (1 - u);
      mote(
        Offset(
          math.sin(u * 4 + i * 2.1) * 3 * u + (_hash(i, 33) - 0.5) * 8 * u,
          -_tall - 4 - rise * (20 + 12 * _hash(i, 34)),
        ),
        1.6 - 0.8 * u,
        Color.lerp(gold, glow, u)!,
        math.sin(math.pi * math.min(1.0, u * 1.1)) * 0.95,
      );
    }
    // The point of light at the tip, where the gold leaves it.
    final pulse = 0.85 + 0.15 * math.sin(time * 2.2);
    mote(const Offset(0, -_tall - 4), 5.5 * pulse, gold, 0.3);
    mote(const Offset(0, -_tall - 4), 2.6, const Color(0xFFFFF2CE), 1);
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
