import 'package:alchemons/widgets/fx/celebration_particles.dart';
import 'dart:math' as math;
import 'dart:ui';

/// Which way the face wearing them is turned, as each family is drawn.
enum GlassesView {
  /// Three-quarters on from the left (Horns, Pips): both eyes, the far
  /// lens narrower, the near arm back to the ear.
  threeQuarter,

  /// Side on, facing left (Wings): the one eye that shows, the bridge over
  /// the snout, the arm back to the ear.
  profile,

  /// Face on (Lets): two lenses alike, the arms going back out of sight.
  front;

  /// How [species] is drawn: by family, but for the few drawn otherwise.
  static GlassesView of(String species) =>
      _species[species] ??
      switch (species.substring(0, 3)) {
        'WNG' => profile,
        'LET' => front,
        _ => threeQuarter,
      };

  static const _species = {
    // Earthwing looks out from under its brow, both eyes showing.
    'WNG03': front,
    // Darkwing's head turns toward us.
    'WNG15': threeQuarter,
  };
}

/// Sunglasses, seen as the face wearing them is turned ([GlassesView]).
///
/// Smoked glass in a dark obsidian frame with gold hinge pins. The lenses
/// take the picked [tint]: darker at the brow, clearer toward the cheek, in
/// the same steps for every colour. A soft sheen glides across the lenses
/// as one reflection now and then, and a few gold grains twinkle on the
/// brow bar.
abstract final class AlchemicalSunglasses {
  static final _particles = CelebrationParticles();
  static const double _rim = 0.075;

  // Each view in the glasses' own space, 1 across from eye to eye: for
  // three-quarters the far eye at (-0.5, 0) and the near at (0.5, 0); face
  // on, the same; side on, the eye at the origin.
  static final _shapes = {
    GlassesView.threeQuarter: _Shape(
      lenses: [
        RRect.fromRectAndCorners(
          Rect.fromCenter(
            center: const Offset(0.52, 0.02),
            width: 0.86,
            height: 0.62,
          ),
          topLeft: const Radius.circular(0.10),
          topRight: const Radius.circular(0.14),
          bottomLeft: const Radius.circular(0.30),
          bottomRight: const Radius.circular(0.34),
        ),
        RRect.fromRectAndCorners(
          Rect.fromCenter(
            center: const Offset(-0.45, 0.02),
            width: 0.60,
            height: 0.58,
          ),
          topLeft: const Radius.circular(0.12),
          topRight: const Radius.circular(0.09),
          bottomLeft: const Radius.circular(0.27),
          bottomRight: const Radius.circular(0.23),
        ),
      ],
      bars: [
        Path()
          ..moveTo(-0.18, -0.20)
          ..quadraticBezierTo(0.02, -0.30, 0.12, -0.20)
          ..lineTo(0.12, -0.10)
          ..quadraticBezierTo(0.02, -0.18, -0.18, -0.10)
          ..close(),
        Path()
          ..moveTo(0.93, -0.25)
          ..lineTo(1.30, -0.33)
          ..quadraticBezierTo(1.36, -0.33, 1.35, -0.27)
          ..lineTo(0.95, -0.12)
          ..close(),
      ],
      pins: const [Offset(0.94, -0.19), Offset(-0.78, -0.19)],
      left: -0.86,
      right: 1.0,
    ),
    GlassesView.profile: _Shape(
      lenses: [
        RRect.fromRectAndCorners(
          Rect.fromCenter(
            center: const Offset(0, 0.02),
            width: 0.86,
            height: 0.62,
          ),
          topLeft: const Radius.circular(0.10),
          topRight: const Radius.circular(0.14),
          bottomLeft: const Radius.circular(0.30),
          bottomRight: const Radius.circular(0.34),
        ),
      ],
      bars: [
        // The bridge, over the snout toward the far eye.
        Path()
          ..moveTo(-0.46, -0.21)
          ..quadraticBezierTo(-0.62, -0.27, -0.74, -0.22)
          ..lineTo(-0.72, -0.12)
          ..quadraticBezierTo(-0.62, -0.17, -0.46, -0.11)
          ..close(),
        Path()
          ..moveTo(0.41, -0.25)
          ..lineTo(0.90, -0.34)
          ..quadraticBezierTo(0.96, -0.34, 0.95, -0.28)
          ..lineTo(0.43, -0.12)
          ..close(),
      ],
      pins: const [Offset(0.42, -0.19)],
      left: -0.42,
      right: 0.42,
    ),
    GlassesView.front: _Shape(
      lenses: [
        for (final side in const [-1.0, 1.0])
          RRect.fromRectAndCorners(
            Rect.fromCenter(
              center: Offset(0.5 * side, 0.02),
              width: 0.78,
              height: 0.60,
            ),
            topLeft: Radius.circular(side < 0 ? 0.14 : 0.10),
            topRight: Radius.circular(side < 0 ? 0.10 : 0.14),
            bottomLeft: Radius.circular(side < 0 ? 0.32 : 0.27),
            bottomRight: Radius.circular(side < 0 ? 0.27 : 0.32),
          ),
      ],
      bars: [
        Path()
          ..moveTo(-0.15, -0.20)
          ..quadraticBezierTo(0, -0.29, 0.15, -0.20)
          ..lineTo(0.15, -0.10)
          ..quadraticBezierTo(0, -0.17, -0.15, -0.10)
          ..close(),
        for (final side in const [-1.0, 1.0])
          Path()
            ..moveTo(0.88 * side, -0.25)
            ..lineTo(1.04 * side, -0.27)
            ..lineTo(1.04 * side, -0.15)
            ..lineTo(0.88 * side, -0.12)
            ..close(),
      ],
      pins: const [Offset(-0.9, -0.19), Offset(0.9, -0.19)],
      left: -0.86,
      right: 0.86,
    ),
  };

  /// Obsidian, lit along its top edge: the same frame for every tint.
  static final Paint _framePaint = Paint()
    ..shader = Gradient.linear(
      const Offset(0, -0.42),
      const Offset(0, 0.42),
      const [
        Color(0xFF7A6E8E),
        Color(0xFF2A2433),
        Color(0xFF15121C),
        Color(0xFF0B090F),
      ],
      const [0.0, 0.16, 0.5, 1.0],
    );

  /// The reflection that glides across: a soft diagonal band, in its own
  /// space, moved by translating the canvas.
  static final Paint _sheenPaint = Paint()
    ..shader = Gradient.linear(
      const Offset(-0.22, 0),
      const Offset(0.22, 0),
      const [
        Color(0x00FFFFFF),
        Color(0x40FFFFFF),
        Color(0x66FFFFFF),
        Color(0x40FFFFFF),
        Color(0x00FFFFFF),
      ],
      const [0.0, 0.3, 0.5, 0.7, 1.0],
    );

  /// A gold pin, about the origin.
  static final Paint _pinPaint = Paint()
    ..shader = Gradient.radial(
      const Offset(-0.012, -0.012),
      0.05,
      const [Color(0xFFFFF0C8), Color(0xFFFFD58B), Color(0xFF8A6420)],
      const [0.0, 0.45, 1.0],
    );

  /// The sky caught in the top of the lenses: a glow fading down.
  static final Paint _skyPaint = Paint()
    ..shader = Gradient.linear(
      const Offset(0, -0.29),
      const Offset(0, -0.10),
      const [Color(0x40FFFFFF), Color(0x00FFFFFF)],
    );
  static final Paint _paint = Paint();

  /// One shader per tint, kept; a screenful of Horns in a handful of tints.
  static final Map<int, Shader> _glass = {};

  static Shader _lens(Color tint) {
    final key = tint.toARGB32();
    final kept = _glass[key];
    if (kept != null) return kept;
    if (_glass.length >= 32) _glass.clear();
    Color shade(double k, double a) => Color.from(
      alpha: a,
      red: (tint.r * k).clamp(0.0, 1.0),
      green: (tint.g * k).clamp(0.0, 1.0),
      blue: (tint.b * k).clamp(0.0, 1.0),
    );
    return _glass[key] = Gradient.linear(
      const Offset(0, -0.32),
      const Offset(0, 0.34),
      [shade(0.32, 0.97), shade(0.7, 0.93), shade(1.25, 0.88)],
      const [0.0, 0.55, 1.0],
    );
  }

  static void paint(
    Canvas canvas,
    Offset center,
    double eyeSpacing,
    double time, {
    double opacity = 1,
    double tilt = 0,
    Color tint = const Color(0xFF2B2738),
    GlassesView view = GlassesView.threeQuarter,
  }) {
    if (eyeSpacing <= 0 || opacity <= 0) return;
    final shape = _shapes[view]!;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(eyeSpacing);
    canvas.rotate(tilt);
    final faded = opacity < 1;
    if (faded) {
      canvas.saveLayer(
        const Rect.fromLTRB(-1.3, -0.8, 1.6, 0.8),
        Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
      );
    }

    canvas.drawPath(shape.frames, _framePaint);
    _paint.shader = _lens(tint);
    canvas.drawPath(shape.lenses, _paint);
    _paint.shader = null;

    // The sky caught in the top of the lenses, still; and a slow sheen
    // across both as one: a glide over the first part of each cycle, eased
    // in and out, then still.
    const cycle = 7.0;
    final phase = (time % cycle) / (cycle * 0.4);
    canvas.save();
    canvas.clipPath(shape.lenses);
    canvas.drawRect(
      Rect.fromLTRB(shape.left, -0.32, shape.right, -0.1),
      _skyPaint,
    );
    if (phase < 1) {
      final eased = phase * phase * (3 - 2 * phase);
      final from = shape.left - 0.45, to = shape.right + 0.45;
      canvas.translate(from + eased * (to - from), 0);
      canvas.skew(-0.55, 0);
      canvas.drawRect(const Rect.fromLTRB(-0.22, -0.5, 0.22, 0.5), _sheenPaint);
    }
    canvas.restore();

    // Gold pins at the hinges.
    for (final pin in shape.pins) {
      canvas.save();
      canvas.translate(pin.dx, pin.dy);
      canvas.drawCircle(Offset.zero, 0.04, _pinPaint);
      canvas.restore();
    }

    // Stardust on the brow bar, each grain coming and going on its own.
    _particles.clear();
    const gold = Color(0xFFFFD58B);
    const pale = Color(0xFFFFF4DC);
    for (var i = 0; i < 9; i++) {
      final u = (i * 0.618034) % 1;
      final x = shape.left + u * (shape.right - shape.left);
      final twinkle = 0.5 + 0.5 * math.sin(time * 1.7 + i * 2.3);
      _particles.add(
        Offset(x, -0.33 + 0.02 * math.sin(i * 1.9)),
        0.018 + 0.012 * twinkle,
        i % 3 == 0 ? pale : gold,
        twinkle * twinkle * 0.9,
      );
    }
    _particles.draw(canvas);

    if (faded) canvas.restore();
    canvas.restore();
  }
}

/// One view of the glasses: its lenses, the bars round them (bridge, arms),
/// its hinge pins, and how far its lenses reach left and right.
class _Shape {
  _Shape({
    required List<RRect> lenses,
    required List<Path> bars,
    required this.pins,
    required this.left,
    required this.right,
  }) : lenses = Path(),
       frames = Path() {
    for (final lens in lenses) {
      this.lenses.addRRect(lens);
      frames.addRRect(lens.inflate(AlchemicalSunglasses._rim));
    }
    for (final bar in bars) {
      frames.addPath(bar, Offset.zero);
    }
  }

  final Path lenses, frames;
  final List<Offset> pins;
  final double left, right;
}
