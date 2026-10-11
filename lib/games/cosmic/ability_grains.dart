import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'cosmic_data.dart' show kElementColors;
import 'vfx_shapes.dart';

/// The ability particle pool as lit grains: every spark, ember, mote and wisp
/// an ability throws goes out in ONE `drawRawAtlas` of a soft grain sprite,
/// each grain tinted through `BlendMode.modulate` with its own colour.
///
/// Shared by survival's own pool (`_VfxParticle`) and [AbilityVfxPool] (open
/// space, dungeons): both hand their particles to [AbilityGrainBatch] through
/// [AbilityGrainBatch.addParticle], so the three modes draw the same grain
/// for the same particle.
///
/// A grain's colour starts from the element's material (vfx_shapes.dart) and
/// is tinted toward the colour the emitter asked for — so a hit spark in raw
/// Material orange becomes a grain of Fire's lit ember, cooling from its
/// glint toward its light as it dies.
///
/// The sprite is built once, off the frame, with `await toImage()` (an atlas
/// built lazily with `toImageSync` mid-frame is a suspect in an open device
/// bug). Until it is ready the batch draws plain circles.

/// Per-second rate at which an ability particle's velocity eases away:
/// v(t) = v0·e^(−k·t). Frame-rate independent. It was 0.92 per 60 Hz frame
/// (k ≈ 5/s), which stopped a burst after ≈ v/5 px, so a release authored as
/// "speed × life" reached a fifth of its area.
const double kAbilityParticleDrag = 1.2;

/// Most particles an ability pool holds at once (survival's long-standing
/// cap; open space and dungeons had none).
const int kAbilityParticleCap = 150;

double _dragDt = -1;
double _dragFactor = 1;

/// The velocity multiplier for one step of [dt] seconds. One `exp` per frame,
/// shared: every particle in a frame steps by the same dt.
double abilityParticleDragFactor(double dt) {
  if (dt != _dragDt) {
    _dragDt = dt;
    _dragFactor = exp(-kAbilityParticleDrag * dt);
  }
  return _dragFactor;
}

/// The two colours a grain moves between: [lit] at birth, [body] as it dies
/// (0xRRGGBB, no alpha).
class AbilityGrainTone {
  const AbilityGrainTone(this.body, this.lit);
  final int body, lit;
}

final Map<int, AbilityGrainTone> _tones = {};

/// The grain tone for an emitter's [color]. Cached per colour, so particles
/// take it at spawn for the cost of a map lookup. The colour's own alpha is
/// ignored, as the old circle render ignored it.
AbilityGrainTone abilityGrainTone(ui.Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return _tones[rgb] ??= _makeTone(rgb);
}

// The glowing elements (vfx_shapes.dart) take more of their own hue.
const Set<String> _glowing = kVfxGlowingElements;

final Map<int, String?> _elementOfRgb = {};

/// The element whose colour [color] is (alpha ignored), or null.
String? abilityElementOfColor(ui.Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return _elementOfRgb.putIfAbsent(rgb, () {
    for (final e in kElementColors.entries) {
      if ((e.value.toARGB32() & 0xFFFFFF) == rgb) return e.key;
    }
    return null;
  });
}

final Map<int, int> _materialTints = {};

/// An element colour as ability art should paint it: the element's material
/// light, tinted toward the raw colour — 30% for the glowing elements (Air,
/// Steam, Light, Spirit, Lightning) so they don't go to pale wires, 22% for
/// the rest.
/// Any colour that is not one of the element colours comes back unchanged.
/// The input's alpha is kept.
ui.Color abilityMaterialTint(ui.Color color) {
  final argb = color.toARGB32();
  final rgb = argb & 0xFFFFFF;
  final tinted = _materialTints[rgb] ??= () {
    for (final e in kElementColors.entries) {
      if ((e.value.toARGB32() & 0xFFFFFF) != rgb) continue;
      return _lerpRgb(
        vfxMaterial(e.key).light.toARGB32() & 0xFFFFFF,
        rgb,
        _glowing.contains(e.key) ? 0.30 : 0.22,
      );
    }
    return rgb;
  }();
  return ui.Color((argb & 0xFF000000) | tinted);
}

/// Element colours saturated enough to stand for a hue.
final List<(String, double)> _hueElements = [
  for (final e in kElementColors.entries)
    if (_hsv(e.value.toARGB32() & 0xFFFFFF).$2 >= 0.45)
      (e.key, _hsv(e.value.toARGB32() & 0xFFFFFF).$1),
];

AbilityGrainTone _makeTone(int rgb) {
  final c = ui.Color(0xFF000000 | rgb);
  String? element;
  for (final e in kElementColors.entries) {
    if ((e.value.toARGB32() & 0xFFFFFF) == rgb) {
      element = e.key;
      break;
    }
  }
  final (h, s, v) = _hsv(rgb);
  final luma = _luma(rgb);
  // A raw accent (Material orange, cyanAccent) or a tinted white is an
  // element colour by another name: the element of the nearest hue.
  if (element == null &&
      ((s >= 0.55 && v >= 0.55) || (luma > 0.78 && s >= 0.06))) {
    var best = double.infinity;
    for (final (name, hue) in _hueElements) {
      var d = (hue - h).abs();
      if (d > 180) d = 360 - d;
      if (d < best) {
        best = d;
        element = name;
      }
    }
  }
  if (element == null && luma > 0.85) {
    // Plain white: no element to borrow from, so a soft pale glint rather
    // than a white pip — a grain catching light, not a flash.
    return AbilityGrainTone(
      _lerpRgb(rgb, 0x8C93A0, 0.5),
      _lerpRgb(rgb, 0xD6DAE2, 0.5),
    );
  }
  if (element == null) {
    // Authored on purpose (a dark speck, a neutral mote): keep it, and let
    // it cool a step deeper as it dies.
    return AbilityGrainTone(_lerpRgb(rgb, 0x000000, 0.2), rgb);
  }
  final m = vfxMaterial(element);
  final t = _glowing.contains(element) ? 0.30 : 0.16;
  final target = c.toARGB32() & 0xFFFFFF;
  final glint = m.glint.toARGB32() & 0xFFFFFF;
  final light = m.light.toARGB32() & 0xFFFFFF;
  final mid = m.mid.toARGB32() & 0xFFFFFF;
  if (luma > 0.78) {
    // A pale spark stays pale: the material's glint, cooling to its light.
    return AbilityGrainTone(
      _lerpRgb(_lerpRgb(glint, light, 0.45), target, t),
      _lerpRgb(glint, target, t),
    );
  }
  if (luma < 0.2) {
    // A dark one is the material's body, lit at most to its light.
    return AbilityGrainTone(
      _lerpRgb(mid, target, t),
      _lerpRgb(light, target, t),
    );
  }
  return AbilityGrainTone(
    _lerpRgb(light, target, t),
    _lerpRgb(_lerpRgb(light, glint, 0.6), target, t),
  );
}

double _luma(int rgb) =>
    (0.2126 * ((rgb >> 16) & 0xFF) +
        0.7152 * ((rgb >> 8) & 0xFF) +
        0.0722 * (rgb & 0xFF)) /
    255;

(double, double, double) _hsv(int rgb) {
  final r = ((rgb >> 16) & 0xFF) / 255;
  final g = ((rgb >> 8) & 0xFF) / 255;
  final b = (rgb & 0xFF) / 255;
  final mx = max(r, max(g, b));
  final mn = min(r, min(g, b));
  final d = mx - mn;
  var h = 0.0;
  if (d > 1e-6) {
    if (mx == r) {
      h = 60 * (((g - b) / d) % 6);
    } else if (mx == g) {
      h = 60 * ((b - r) / d + 2);
    } else {
      h = 60 * ((r - g) / d + 4);
    }
  }
  if (h < 0) h += 360;
  return (h, mx <= 0 ? 0.0 : d / mx, mx);
}

int _lerpRgb(int a, int b, double t) {
  int ch(int s) {
    final x = (a >> s) & 0xFF, y = (b >> s) & 0xFF;
    return (x + (y - x) * t).round().clamp(0, 255);
  }

  return (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

/// The soft grain every ability particle is drawn with: a lit heart, a soft
/// fall-off, no edge. White, so `modulate` gives each grain its own colour.
abstract final class AbilityGrainSprite {
  static const double cell = 32;
  static ui.Image? _image;
  static Future<void>? _loading;

  /// Null until [ensureLoaded] has finished.
  static ui.Image? get image => _image;

  /// Builds the sprite off the frame. Safe to call from every game's
  /// `onLoad` without awaiting it: the batch draws circles until it lands.
  static Future<void> ensureLoaded() => _loading ??= _build();

  static Future<void> _build() async {
    const c = cell;
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    const white = ui.Color(0xFFFFFFFF);
    canvas.drawCircle(
      const ui.Offset(c / 2, c / 2),
      c / 2,
      ui.Paint()
        ..shader = ui.Gradient.radial(
          const ui.Offset(c / 2, c / 2),
          c / 2,
          [
            white,
            white.withValues(alpha: 0.9),
            white.withValues(alpha: 0.38),
            white.withValues(alpha: 0.1),
            white.withValues(alpha: 0),
          ],
          const [0.0, 0.3, 0.55, 0.78, 1.0],
        ),
    );
    final pic = rec.endRecording();
    final image = await pic.toImage(c.toInt(), c.toInt());
    pic.dispose();
    _image = image;
  }
}

/// Collects a frame's grains and draws them in one call. Buffers are reused
/// frame to frame; nothing is allocated per grain.
class AbilityGrainBatch {
  AbilityGrainBatch([int capacity = kAbilityParticleCap])
    : _xf = Float32List(capacity * 4),
      _rects = Float32List(capacity * 4),
      _colors = Int32List(capacity),
      _cx = Float32List(capacity),
      _cy = Float32List(capacity),
      _cr = Float32List(capacity);

  Float32List _xf, _rects, _cx, _cy, _cr;
  Int32List _colors;
  int _n = 0;

  static final ui.Paint _atlasPaint = ui.Paint()
    ..filterQuality = ui.FilterQuality.low;
  static final ui.Paint _dotPaint = ui.Paint();

  int get length => _n;

  /// How much larger the soft sprite is drawn than the hard disc it replaces,
  /// so the lit heart covers about the same ground.
  static const double spriteScale = 1.6;

  /// One particle of an ability pool, the way every mode draws it: radius
  /// shrinking with its fade ([size] × alpha, alpha = 2 × life fraction,
  /// capped at 1), strength alpha × 0.85, colour cooling from the tone's lit
  /// shade to its body as the particle dies.
  void addParticle(
    double x,
    double y,
    double size,
    double life,
    double maxLife,
    AbilityGrainTone tone,
  ) {
    if (life <= 0 || maxLife <= 0) return;
    final f = (life / maxLife).clamp(0.0, 1.0);
    final alpha = min(1.0, f * 2);
    final r = size * alpha;
    if (r <= 0.05) return;
    add(x, y, r, _lerpRgb(tone.body, tone.lit, f * f), alpha * 0.85);
  }

  /// A grain centred on ([x], [y]) covering about a disc of [radius], in
  /// [rgb] at [alpha].
  void add(double x, double y, double radius, int rgb, double alpha) {
    if (alpha <= 0.01) return;
    if (_n >= _colors.length) _grow();
    final a = (alpha.clamp(0.0, 1.0) * 255).round();
    _colors[_n] = (a << 24) | rgb;
    _cx[_n] = x;
    _cy[_n] = y;
    _cr[_n] = radius;
    final half = radius * spriteScale;
    final scale = half * 2 / AbilityGrainSprite.cell;
    final i = _n * 4;
    _xf[i] = scale;
    _xf[i + 1] = 0;
    _xf[i + 2] = x - half;
    _xf[i + 3] = y - half;
    _rects[i] = 0;
    _rects[i + 1] = 0;
    _rects[i + 2] = AbilityGrainSprite.cell;
    _rects[i + 3] = AbilityGrainSprite.cell;
    _n++;
  }

  void _grow() {
    final cap = _colors.length * 2;
    _xf = Float32List(cap * 4)..setAll(0, _xf);
    _rects = Float32List(cap * 4)..setAll(0, _rects);
    _colors = Int32List(cap)..setAll(0, _colors);
    _cx = Float32List(cap)..setAll(0, _cx);
    _cy = Float32List(cap)..setAll(0, _cy);
    _cr = Float32List(cap)..setAll(0, _cr);
  }

  /// Draws what was added and empties the batch.
  void flush(ui.Canvas canvas) {
    if (_n == 0) return;
    final image = AbilityGrainSprite.image;
    if (image != null) {
      canvas.drawRawAtlas(
        image,
        Float32List.sublistView(_xf, 0, _n * 4),
        Float32List.sublistView(_rects, 0, _n * 4),
        Int32List.sublistView(_colors, 0, _n),
        ui.BlendMode.modulate,
        null,
        _atlasPaint,
      );
    } else {
      // The sprite is still being built: plain discs, one shared paint.
      for (var k = 0; k < _n; k++) {
        _dotPaint.color = ui.Color(_colors[k]);
        canvas.drawCircle(ui.Offset(_cx[k], _cy[k]), _cr[k], _dotPaint);
      }
    }
    _n = 0;
  }
}
