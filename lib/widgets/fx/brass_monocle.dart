// lib/widgets/fx/brass_monocle.dart
//
// The Brass Monocle (the Athanor, the Still-Room): a round lens in a brass
// rim over the eye the face shows nearest, a chain of brass beads hanging
// from it. It is worn on the sunglasses' fits (FamilyCostume.monocle): the
// eyes' midpoint and eye-to-eye, and GlassesView.of(species) for which eye
// shows. The glass is faintly tinted (its picked color, warm and clear by
// default), a sheen gliding over it now and then; the chain sways a little.
//
// The rim is one filled band, not a stroke; the paths are made once; the
// chain is one grain pass. No blur.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/obsidian_kit.dart'
    show kGlint, paintDisc;
import 'package:alchemons/games/cosmic/vfx_shapes.dart' show vfxCrescent;
import 'package:alchemons/widgets/fx/alchemical_sunglasses.dart'
    show GlassesView;
import 'package:alchemons/widgets/fx/celebration_particles.dart';
import 'package:flutter/painting.dart';

abstract final class BrassMonocle {
  /// Clear glass with a little of the brass's warmth.
  static const Color defaultTint = Color(0xFFCDB07A);

  static final Paint _paint = Paint()..isAntiAlias = true;
  static final CelebrationParticles _chain = CelebrationParticles();

  // In eye-to-eye units, round the lens's centre.
  static const double _lensR = 0.32, _rimW = 0.1;

  static final ui.Shader _rim = ui.Gradient.linear(
    const Offset(-0.45, -0.45),
    const Offset(0.45, 0.45),
    const [
      Color(0xFFF2DDA6),
      Color(0xFFCDB07A),
      Color(0xFF6B5A36),
      Color(0xFF3A3020),
      Color(0xFF8A7448),
    ],
    const [0.0, 0.25, 0.6, 0.85, 1.0],
  );

  static final Path _rimBand = Path()
    ..fillType = PathFillType.evenOdd
    ..addOval(Rect.fromCircle(center: Offset.zero, radius: _lensR + _rimW))
    ..addOval(Rect.fromCircle(center: Offset.zero, radius: _lensR));
  static final Path _lensClip = Path()
    ..addOval(Rect.fromCircle(center: Offset.zero, radius: _lensR));

  /// The glass's catch-light, and the rim's lit shoulder.
  static final Path _catch = vfxCrescent(
    Offset.zero,
    _lensR * 0.86,
    0.07,
    -2.3,
    1.2,
  );
  static final Path _shoulder = vfxCrescent(
    Offset.zero,
    _lensR + _rimW * 0.92,
    _rimW * 0.5,
    -2.4,
    1.5,
  );

  /// The glass in each tint: nearly clear at its middle, the tint
  /// gathering toward its edge. Bounded, like the hat's velvets.
  static final Map<int, ui.Shader> _lenses = {};

  static ui.Shader _lens(Color tint) {
    final key = tint.toARGB32();
    final kept = _lenses[key];
    if (kept != null) return kept;
    if (_lenses.length >= 32) _lenses.clear();
    const white = Color(0xFFFFFFFF);
    return _lenses[key] = ui.Gradient.radial(
      const Offset(-0.08, -0.1),
      0.4,
      [
        Color.lerp(tint, white, 0.8)!.withValues(alpha: 0.07),
        Color.lerp(tint, white, 0.55)!.withValues(alpha: 0.12),
        tint.withValues(alpha: 0.4),
      ],
      const [0.0, 0.7, 1.0],
    );
  }

  /// Paints the monocle over the eyes at [eyes], [eyeToEye] apart, tilted
  /// with the head by [tilt], as the face is seen ([view]). [time] in
  /// seconds.
  static void paint(
    Canvas canvas,
    Offset eyes,
    double eyeToEye,
    double time, {
    double opacity = 1,
    double tilt = 0,
    GlassesView view = GlassesView.threeQuarter,
    Color tint = defaultTint,
  }) {
    if (eyeToEye <= 0 || opacity <= 0) return;
    final o = opacity.clamp(0.0, 1.0);
    canvas.save();
    canvas.translate(eyes.dx, eyes.dy);
    canvas.scale(eyeToEye);
    canvas.rotate(tilt);
    // Over the near eye: the right one as drawn, or the one eye side on.
    canvas.translate(view == GlassesView.profile ? 0 : 0.5, 0.02);

    // The chain first, so the rim covers where it hangs from: a hanging
    // curve of beads, sagging lowest a little past halfway.
    _chain.clear();
    const links = 16;
    final sway = math.sin(time * 1.3) * 0.06;
    final from = Offset(
      math.cos(0.75) * (_lensR + _rimW * 0.6),
      math.sin(0.75) * (_lensR + _rimW * 0.6),
    );
    final to = Offset(0.75 + sway, 1.55);
    for (var i = 0; i <= links; i++) {
      final f = i / links;
      final p =
          Offset.lerp(from, to, f)! +
          Offset(-0.18 * math.sin(math.pi * f), 0.3 * math.sin(math.pi * f));
      _chain.add(p, 0.028, const Color(0xFF2A2216), 0.9 * o);
      _chain.add(p, 0.018, const Color(0xFFB8975A), o);
      _chain.add(p + const Offset(-0.018, -0.02), 0.01, const Color(0xFFF6E2B0), o);
    }
    _chain.draw(canvas);

    // The glass, a sheen gliding over it every few seconds, its
    // catch-light; then the rim round it.
    _paint
      ..shader = _lens(tint)
      ..color = Color.fromRGBO(0, 0, 0, o);
    canvas.drawCircle(Offset.zero, _lensR, _paint);
    final g = time / 5.5 - (time / 5.5).floorToDouble();
    if (g < 0.35) {
      canvas.save();
      canvas.clipPath(_lensClip);
      canvas.translate(-0.5 + g / 0.35, 0);
      canvas.rotate(0.5);
      _paint
        ..shader = null
        ..color = Color.fromRGBO(
          255,
          250,
          235,
          0.3 * math.sin(math.pi * g / 0.35) * o,
        );
      canvas.drawRect(const Rect.fromLTRB(-0.05, -0.5, 0.05, 0.5), _paint);
      canvas.restore();
    }
    _paint
      ..shader = null
      ..color = Color.fromRGBO(255, 250, 235, 0.45 * o);
    canvas.drawPath(_catch, _paint);
    _paint
      ..shader = _rim
      ..color = Color.fromRGBO(0, 0, 0, o);
    canvas.drawPath(_rimBand, _paint);
    _paint
      ..shader = null
      ..color = Color.fromRGBO(255, 240, 200, 0.6 * o);
    canvas.drawPath(_shoulder, _paint);
    paintDisc(canvas, kGlint, const Offset(-0.3, -0.3), 0.06, 0.9 * o);
    canvas.restore();
  }

  /// On its own, for a card: centred on [center] in a box of half-side
  /// [r], its chain hanging down to the right.
  static void paintPreview(
    Canvas canvas,
    Offset center,
    double r,
    double t, {
    double opacity = 1,
    Color tint = defaultTint,
  }) => paint(
    canvas,
    // The lens up and left of the middle, the chain's end low and right.
    center + Offset(-r * 0.775, -r * 0.467),
    r * 0.85,
    t,
    opacity: opacity,
    tint: tint,
  );
}
