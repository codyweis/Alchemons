part of 'alchemy_effect_paint.dart';

/// THE SPOTLIGHTS (the Trials: one for each cup won — Copper, Silver and
/// Gold; Ruby, Sapphire and Emerald) —
/// the creature stands in the light the Trials' shelf gives its chosen cup:
/// a soft beam from a lamp high over its head, light pooled where it
/// stands, and motes of the cup's metal drifting up through the beam, a few
/// passing in front of it and flaring white now and then. The higher the
/// cup on its ladder, the brighter the beam and the more it carries; the
/// last of each (Gold, Emerald) has a glint sliding down it every few
/// seconds, as the cups' glints run over them.
///
/// The beam is one cone on a unit frame, stretched (one shader per metal);
/// the motes are atlas grains.
/// The spotlights' beam, white, made once: out of the dark at its lamp
/// (the top) and strongest where it lands (the bottom), fading to nothing at
/// its edges. Tint it with a modulate colour filter and stretch it over the
/// lit one (the Ruby Cup's island lights its last one standing with it).
ui.Image trialsBeamImage() => _Spotlight._image ??= _Spotlight._beamImage();

abstract final class _Spotlight {
  /// Each cup's metal: the beam's light (the metal itself, so copper reads
  /// as copper), the light in its bowl, and its glint.
  static const List<(Color, Color, Color)> _metals = [
    (Color(0xFFE8935A), Color(0xFFFFC48E), Color(0xFFFFE0BF)),
    (Color(0xFFB9C8E0), Color(0xFFE4ECFA), Color(0xFFFFFFFF)),
    (Color(0xFFE8C66E), Color(0xFFF2E3BC), Color(0xFFFBF1D4)),
    (Color(0xFFE0506A), Color(0xFFFF8FA0), Color(0xFFFFD3DA)),
    (Color(0xFF5A82E8), Color(0xFF9EC2FF), Color(0xFFDCE8FF)),
    (Color(0xFF3FBF86), Color(0xFF9AF0C4), Color(0xFFD6FFE9)),
  ];

  /// How far the beam reaches either side at its lamp and where it lands,
  /// as shares of its width.
  static const double _lamp = 0.08, _foot = 0.62;

  /// The beam as one white image, made once: out of the dark at the lamp
  /// and strongest where it lands, fading to nothing at its edges — so it
  /// has no edge — tinted and stretched to each creature.
  static ui.Image? _image;
  static const double _imgW = 96, _imgH = 160;

  static ui.Image _beamImage() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final paint = Paint();
    const white = Color(0xFFFFFFFF);
    for (var y = 0.0; y < _imgH; y += 2) {
      final v = (y + 1) / _imgH;
      final a = _smooth(0, 0.6, v) * (1 - 0.3 * _smooth(0.9, 1, v));
      // The cone's half width here, the image's full width at the foot.
      final half = (_lamp + (_foot - _lamp) * v) / _foot * _imgW / 2;
      const mid = _imgW / 2;
      paint.shader = ui.Gradient.linear(
        Offset(mid - half, 0),
        Offset(mid + half, 0),
        [
          white.withValues(alpha: 0),
          white.withValues(alpha: a * 0.4),
          white.withValues(alpha: a),
          white.withValues(alpha: a * 0.4),
          white.withValues(alpha: 0),
        ],
        const [0.0, 0.28, 0.5, 0.72, 1.0],
      );
      c.drawRect(Rect.fromLTWH(mid - half, y, half * 2, 2), paint);
    }
    final pic = rec.endRecording();
    final img = pic.toImageSync(_imgW.toInt(), _imgH.toInt());
    pic.dispose();
    return img;
  }

  static final Paint _beamPaint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.low;

  static void paint(
    Canvas c,
    Offset center,
    double r,
    double t,
    double o,
    bool dark,
    bool front,
    int tier,
  ) {
    final (beam, light, glint) = _metals[tier.clamp(0, _metals.length - 1)];
    // Each ladder's first cup the faintest, its last the brightest.
    final rung = tier % 3;
    final strength = const [0.7, 0.85, 1.0][rung];
    final feet = center.dy + 0.62 * r;
    final top = center.dy - 1.55 * r;
    final tall = feet + 0.04 * r - top;
    final wide = 1.75 * r;

    if (!front) {
      // The beam, breathing a little as a lamp's light does, and a hotter
      // core of the bowl's light down its middle.
      final breathe = 0.86 + 0.14 * math.sin(t * 1.3);
      final img = _image ??= _beamImage();
      final src = Rect.fromLTWH(0, 0, _imgW, _imgH);
      for (final (col, across, k) in [(beam, 1.0, 1.0), (light, 0.5, 0.55)]) {
        final a = (o * strength * breathe * k * (dark ? 0.95 : 0.6)).clamp(
          0.0,
          1.0,
        );
        if (a <= 0.004) continue;
        _beamPaint
          ..shader = null
          ..colorFilter = ColorFilter.mode(
            col.withValues(alpha: a),
            BlendMode.modulate,
          );
        c.drawImageRect(
          img,
          src,
          Rect.fromLTRB(
            center.dx - wide * _foot * across,
            top,
            center.dx + wide * _foot * across,
            top + tall,
          ),
          _beamPaint,
        );
      }
      // Gold's glint, sliding down the beam every few seconds: the beam's
      // own light, brighter in a soft band.
      if (rung == 2) {
        final g = (t / 3.4) % 1.0;
        if (g < 0.5) {
          final at = g / 0.5;
          final peak = o * 0.9 * math.sin(math.pi * at);
          for (var b = -3; b <= 3; b++) {
            final v0 = at + b * 0.022, v1 = v0 + 0.022;
            if (v1 <= 0 || v0 >= 1) continue;
            final a = peak * math.exp(-b * b / 4.5);
            if (a <= 0.004) continue;
            _beamPaint.colorFilter = ColorFilter.mode(
              glint.withValues(alpha: a.clamp(0.0, 1.0)),
              BlendMode.modulate,
            );
            final y0 = v0.clamp(0.0, 1.0), y1 = v1.clamp(0.0, 1.0);
            c.drawImageRect(
              img,
              Rect.fromLTRB(0, y0 * _imgH, _imgW, y1 * _imgH),
              Rect.fromLTRB(
                center.dx - wide * _foot,
                top + y0 * tall,
                center.dx + wide * _foot,
                top + y1 * tall,
              ),
              _beamPaint,
            );
          }
        }
      }
      _beamPaint.colorFilter = null;
      // Where it lands: a wide pool, and a brighter heart under the feet.
      _pool(
        c,
        center.dx,
        feet,
        1.05 * r,
        0.26 * r,
        beam,
        o * strength * (dark ? 0.6 : 0.35),
      );
      _pool(
        c,
        center.dx,
        feet,
        0.46 * r,
        0.11 * r,
        Color.lerp(light, const Color(0xFFFFFFFF), 0.5)!,
        o * strength * (dark ? 0.45 : 0.25),
      );
    }

    // Motes of the metal drifting up through the beam: every other one
    // behind the creature, the rest in front of it.
    final n = const [12, 16, 22][rung];
    final warm = _rgb(beam), bright = _rgb(light), white = 0xFFFFFF;
    _Atlas.clear();
    for (var i = 0; i < n; i++) {
      if (i.isOdd != front) continue;
      final life = _frac(t * (0.1 + 0.07 * _q(0, i)) + _q(1, i));
      final y = feet - life * 1.95 * r;
      // Within the beam's width where it is.
      final across = ((y - top) / tall).clamp(0.0, 1.0);
      final half = (0.09 + 0.51 * across) * wide;
      final x =
          center.dx +
          (_q(2, i) - 0.5) * 1.6 * half +
          math.sin(t * 0.8 + i * 1.7) * 0.05 * r;
      final fade = math.sin(math.pi * life);
      final flare = _frac(t * 0.3 + _q(3, i)) < 0.05;
      _Atlas.add(
        x,
        y,
        r * (0.15 + 0.08 * _q(4, i)) * (flare ? 1.35 : 1),
        flare ? white : (_q(5, i) < 0.45 ? bright : warm),
        o * fade * (flare ? 1 : 0.9) * (dark ? 1 : 0.85),
      );
    }
    _Atlas.draw(c, additive: dark);
  }
}
