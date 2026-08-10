// lib/games/planet_dungeon/planet_dungeon_fx.dart
//
// Performant atmospheric FX for the planet dungeon. Soft sprites (glow / mote /
// cloud puff) are baked ONCE into ui.Images, then blitted cheaply — no
// per-frame MaskFilter blur. Particles are a bounded pool drawn in a single
// drawAtlas call. Keeps the per-frame cost low (see feedback_performance).

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// One-time baked soft sprites reused across the whole scene.
class DungeonFxAssets {
  ui.Image? glow; // radial white falloff
  ui.Image? mote; // tiny radial dot
  ui.Image? puff; // soft cloud blob

  bool get ready => glow != null && mote != null && puff != null;

  Future<void> load() async {
    glow = await _bakeRadial(96);
    mote = await _bakeRadial(24);
    puff = await _bakePuff(128, 84);
  }

  static Future<ui.Image> _bakeRadial(int size) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final r = size / 2.0;
    c.drawCircle(
      Offset(r, r),
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(r, r),
          r,
          const [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
          const [0.0, 1.0],
        ),
    );
    return rec.endRecording().toImage(size, size);
  }

  static Future<ui.Image> _bakePuff(int w, int h) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    void blob(double cx, double cy, double r) {
      c.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..shader = ui.Gradient.radial(Offset(cx, cy), r, const [
            Color(0xFFFFFFFF),
            Color(0x00FFFFFF),
          ]),
      );
    }

    blob(w * 0.34, h * 0.62, h * 0.40);
    blob(w * 0.50, h * 0.42, h * 0.46);
    blob(w * 0.66, h * 0.58, h * 0.42);
    blob(w * 0.80, h * 0.66, h * 0.30);
    blob(w * 0.22, h * 0.66, h * 0.28);
    return rec.endRecording().toImage(w, h);
  }
}

/// Blit a baked glow, tinted and additively blended. [radius] is half-size.
void drawGlow(
  Canvas canvas,
  ui.Image img,
  Offset center,
  double radius,
  Color color,
) {
  final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
  final dst = Rect.fromCenter(
    center: center,
    width: radius * 2,
    height: radius * 2,
  );
  canvas.drawImageRect(
    img,
    src,
    dst,
    Paint()
      ..colorFilter = ColorFilter.mode(color, BlendMode.modulate)
      ..blendMode = BlendMode.plus
      ..filterQuality = FilterQuality.low,
  );
}

/// Blit a baked cloud puff, tinted, normal alpha blend.
void drawPuff(
  Canvas canvas,
  ui.Image img,
  Offset center,
  double width,
  Color color,
) {
  final ratio = img.height / img.width;
  final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
  final dst = Rect.fromCenter(
    center: center,
    width: width,
    height: width * ratio,
  );
  canvas.drawImageRect(
    img,
    src,
    dst,
    Paint()
      ..colorFilter = ColorFilter.mode(color, BlendMode.modulate)
      ..filterQuality = FilterQuality.low,
  );
}

class _Mote {
  double x = 0, y = 0, vx = 0, vy = 0, size = 2, alpha = 0.3, hue = 0;
}

/// A bounded pool of drifting wind motes, rendered in one drawAtlas call.
/// The default palette is the Air planet's; pass [palette] to retint (e.g.
/// ember tones for the Cinder Cathedral).
class AmbientWind {
  AmbientWind({int? seed, List<Color>? palette})
    : _rng = Random(seed ?? 0x10E),
      _palette = palette ?? _windPalette;

  final Random _rng;
  final List<_Mote> _motes = [];
  final List<Color> _palette;
  Size _area = Size.zero;

  static const List<Color> _windPalette = [
    Color(0xFFE4C16A), // amber
    Color(0xFF5BC8E8), // teal
    Color(0xFFB9C7D6), // pale wind
  ];

  void ensure(Size area, {int count = 72}) {
    final resized =
        (area.width - _area.width).abs() > 1 ||
        (area.height - _area.height).abs() > 1;
    _area = area;
    if (_motes.length == count && !resized) return;
    _motes
      ..clear()
      ..addAll(List.generate(count, (_) => _spawn(randomY: true)));
  }

  _Mote _spawn({bool randomY = false}) {
    final m = _Mote();
    final layer = _rng.nextDouble(); // 0 far .. 1 near
    m.x = _rng.nextDouble() * _area.width;
    m.y = randomY ? _rng.nextDouble() * _area.height : -8.0;
    m.vx = 14 + layer * 46 + _rng.nextDouble() * 12; // drift right (wind)
    m.vy = -6 - layer * 10; // gentle rise
    m.size = 1.5 + layer * 4.5;
    m.alpha = 0.10 + layer * 0.28;
    m.hue = _rng.nextDouble();
    return m;
  }

  void update(double dt) {
    if (_area == Size.zero) return;
    const margin = 24.0;
    for (final m in _motes) {
      m.x += m.vx * dt;
      m.y += m.vy * dt;
      if (m.x > _area.width + margin) m.x = -margin;
      if (m.y < -margin) m.y = _area.height + margin;
      if (m.y > _area.height + margin) m.y = -margin;
    }
  }

  void render(Canvas canvas, ui.Image moteImg, double time) {
    if (_motes.isEmpty) return;
    final transforms = <ui.RSTransform>[];
    final rects = <Rect>[];
    final colors = <Color>[];
    final src = Rect.fromLTWH(
      0,
      0,
      moteImg.width.toDouble(),
      moteImg.height.toDouble(),
    );
    for (var i = 0; i < _motes.length; i++) {
      final m = _motes[i];
      final twinkle = 0.6 + 0.4 * sin(time * 2 + i * 0.7);
      final scale = m.size / moteImg.width;
      transforms.add(
        ui.RSTransform.fromComponents(
          rotation: 0,
          scale: scale,
          anchorX: moteImg.width / 2,
          anchorY: moteImg.height / 2,
          translateX: m.x,
          translateY: m.y,
        ),
      );
      rects.add(src);
      final base =
          _palette[(m.hue * _palette.length).floor() % _palette.length];
      colors.add(base.withValues(alpha: (m.alpha * twinkle).clamp(0.0, 1.0)));
    }
    canvas.drawAtlas(
      moteImg,
      transforms,
      rects,
      colors,
      BlendMode.modulate,
      null,
      Paint()
        ..blendMode = BlendMode.plus
        ..filterQuality = FilterQuality.low,
    );
  }
}

/// Airy twilight sky for the air planet — cool blues, lighter toward the
/// horizon so it reads as open sky, not a brown cave.
void drawSky(Canvas canvas, Size size) {
  final rect = Offset.zero & size;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        const [
          Color(0xFF16223A), // deep blue zenith
          Color(0xFF223759), // night sky blue
          Color(0xFF35577E), // luminous horizon
        ],
        const [0.0, 0.55, 1.0],
      ),
  );
}

double _seedRand(int seed, double offset) {
  final v = sin(seed * 12.9898 + offset * 78.233) * 43758.5453;
  return v - v.floorToDouble();
}

/// Soft drifting clouds in the style of the faction backgrounds: blurred ovals
/// that drift across, bob on a sine wave, and fade in/out at the edges.
/// Screen-space; [t] is seconds. Bounded count keeps the per-frame cost low.
void drawDriftingClouds(
  Canvas canvas,
  Size size,
  double t, {
  Color primary = const Color(0xFF8FB3D6),
  Color secondary = const Color(0xFFB9C7D6),
  int count = 8,
  double maxAlpha = 0.16,
}) {
  for (var i = 0; i < count; i++) {
    final randomY = _seedRand(i, 0) * size.height * 0.72 + size.height * 0.1;
    final speed = 0.045 + _seedRand(i, 1) * 0.075;
    final wave = _seedRand(i, 2) * 50 - 25;
    final stagger = _seedRand(i, 4);

    final phase = t * speed + stagger;
    final u = phase - phase.floorToDouble();

    final fadeZone = size.width * 0.2;
    final totalRange = size.width + fadeZone * 2;
    final x = -fadeZone + u * totalRange;
    final y = randomY + sin(phase * 2 * pi) * wave;

    double fade = 1.0;
    if (x < fadeZone && x >= 0) {
      fade = x / fadeZone;
    } else if (x > size.width - fadeZone && x <= size.width) {
      fade = (size.width - x) / fadeZone;
    } else if (x < 0 || x > size.width) {
      fade = 0.0;
    }
    if (fade <= 0) continue;

    for (var j = 0; j < 2; j++) {
      final w = 150 + sin(phase * 3 * pi + j) * 26 + i * 10;
      final h = 66 + j * 8;
      final op = ((maxAlpha - j * 0.03) * fade).clamp(0.0, 1.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x + j * 22, y + j * 7),
          width: w,
          height: h.toDouble(),
        ),
        Paint()
          ..color = (j.isEven ? primary : secondary).withValues(alpha: op)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
  }
}

/// Gentle cool vignette — frames the scene without crushing it to mud.
void drawVignette(Canvas canvas, Size size) {
  final rect = Offset.zero & size;
  final r = size.longestSide * 0.8;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.radial(
        rect.center,
        r,
        const [Color(0x00000000), Color(0x55070C16)],
        const [0.62, 1.0],
      ),
  );
}
