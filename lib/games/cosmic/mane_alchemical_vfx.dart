import 'dart:math';
import 'dart:ui' as ui;

import 'cosmic_data.dart';
import 'vfx_shapes.dart';

// Material vocabulary for Mane specials. Every shader and path is built once.
// Animation uses transforms and bounded analytic details: no spawned particles,
// blur, saveLayer, or geometry proportional to the number of enemies hit.
class _Material {
  final ui.Color ink;
  final ui.Color light;
  late final ui.Shader glow = ui.Gradient.radial(
    ui.Offset.zero,
    1,
    [light, ink.withValues(alpha: 0.6), ink.withValues(alpha: 0)],
    const [0, 0.30, 1],
  );
  late final ui.Shader glass = ui.Gradient.linear(
    const ui.Offset(-15, 12),
    const ui.Offset(12, -15),
    [ui.Color.lerp(ink, const ui.Color(0xFF070B14), 0.75)!, ink, light],
    const [0, 0.7, 1],
  );
  _Material(int ink, int light) : ink = ui.Color(ink), light = ui.Color(light);
}

final _materials = <String, _Material>{
  'Water': _Material(0xFF245F7E, 0xFFA9E0DB),
  'Earth': _Material(0xFF685447, 0xFFC4AB7C),
  'Air': _Material(0xFF526B73, 0xFFD2E8DB),
  'Steam': _Material(0xFF69777A, 0xFFDFD6BB),
  'Mud': _Material(0xFF66533C, 0xFFAFA080),
  'Lightning': _Material(0xFF6D687B, 0xFFEDE0B9),
  'Crystal': _Material(0xFF376A66, 0xFFC6E5CD),
  'Plant': _Material(0xFF465D3C, 0xFFB4CF7E),
  'Poison': _Material(0xFF65517D, 0xFFC1ACCA),
  'Spirit': _Material(0xFF586B8D, 0xFFD3E7E0),
  'Blood': _Material(0xFF732F3F, 0xFFE4A990),
  'Dust': _Material(0xFF796750, 0xFFD8C5A0),
  'Light': _Material(0xFFAC8750, 0xFFFFF1CB),
  'Fire': _Material(0xFFBC4A25, 0xFFFFDEAB),
  'Lava': _Material(0xFF9A4029, 0xFFFFCE91),
};
final _ribbon = ui.Path()
  ..moveTo(17, 0)
  ..cubicTo(4, -15, -12, -9, -36, 4)
  ..cubicTo(-12, -2, -1, 9, 17, 0)
  ..close();
final _wave = ui.Path()
  ..moveTo(-12, -29)
  ..cubicTo(14, -26, 23, 18, -9, 30)
  ..cubicTo(6, 12, 1, -8, -12, -29)
  ..close();
final _crest = ui.Path()
  ..moveTo(-10, -27)
  ..cubicTo(13, -19, 16, 15, -8, 28);
final _stone = ui.Path()
  ..moveTo(18, -4)
  ..lineTo(10, -16)
  ..lineTo(-6, -13)
  ..lineTo(-18, -3)
  ..lineTo(-12, 12)
  ..lineTo(3, 16)
  ..lineTo(16, 8)
  ..close();
final _fracture = ui.Path()
  ..moveTo(-13, -2)
  ..lineTo(-5, 1)
  ..lineTo(0, -4)
  ..lineTo(5, -2)
  ..lineTo(10, -12)
  ..moveTo(0, -4)
  ..lineTo(2, 6)
  ..lineTo(-3, 13)
  ..moveTo(2, 6)
  ..lineTo(13, 8);
final _shard = ui.Path()
  ..moveTo(23, 0)
  ..lineTo(2, -11)
  ..lineTo(-16, -5)
  ..lineTo(-12, 8)
  ..lineTo(3, 10)
  ..close();
final _facet = ui.Path()
  ..moveTo(23, 0)
  ..lineTo(0, -3)
  ..lineTo(-16, -5)
  ..lineTo(3, 10)
  ..close();
final _drop = ui.Path()
  ..moveTo(17, 0)
  ..cubicTo(17, -12, 2, -16, -20, 0)
  ..cubicTo(2, 14, 17, 10, 17, 0)
  ..close();
final _pool = ui.Path()
  ..moveTo(21, 0)
  ..cubicTo(24, 8, 11, 10, 5, 13)
  ..cubicTo(-5, 16, -8, 9, -17, 9)
  ..cubicTo(-25, 6, -22, -3, -15, -5)
  ..cubicTo(-14, -15, -4, -10, 2, -13)
  ..cubicTo(12, -14, 11, -5, 21, 0)
  ..close();
// A flat molten surface with a cooling rim, not the projectile's glass shader.
final _lavaPoolHeat = ui.Gradient.radial(
  const ui.Offset(1, -1),
  24,
  const [
    ui.Color(0xFFAA704A),
    ui.Color(0xFF783E30),
    ui.Color(0xFF571E17),
    ui.Color(0xFF20151A),
  ],
  const [0, 0.4, 0.78, 1],
);
final _lavaRaft = ui.Path()
  ..moveTo(-7, -2)
  ..cubicTo(-5, -5, -1, -3, 2, -4)
  ..cubicTo(7, -4, 8, 1, 4, 3)
  ..cubicTo(1, 2, -4, 5, -7, -2)
  ..close();
final _root = ui.Path()
  ..moveTo(-27, 5)
  ..cubicTo(-15, -4, -9, 9, 1, -2)
  ..cubicTo(8, -12, 17, -5, 21, 0)
  ..moveTo(-7, 3)
  ..quadraticBezierTo(-12, -12, -18, -10)
  ..moveTo(4, -5)
  ..quadraticBezierTo(6, 9, 15, 13);
final _thorn = ui.Path()
  ..moveTo(0, 0)
  ..lineTo(-4, -5)
  ..quadraticBezierTo(2, -4, 4, 0)
  ..close();
// An arc writhing through the old zig-zag's corners (curved through their
// midpoints) with one branch, so the ribbon reads as a discharge, not a
// zig-zag wire.
final _bolt = ui.Path()
  ..moveTo(-19, 4)
  ..quadraticBezierTo(-10, -2, -8, 0.5)
  ..quadraticBezierTo(-6, 3, -3, -1)
  ..quadraticBezierTo(0, -5, 2, -3)
  ..quadraticBezierTo(4, -1, 16, -7)
  ..moveTo(-5.75, 1.4)
  ..quadraticBezierTo(-2, 10, 4, 12);

// One paint for every Mane painter: a painter is built per effect per frame,
// and every draw below sets the fields it uses.
final ui.Paint _manePaint = ui.Paint();

/// The scorch under a Mane Lightning field (Lightning's dark material).
const ui.Color _scorch = ui.Color(0xFF14162A);

/// The broken ground under a Mane Earth quake (Earth's dark material).
const ui.Color _earthDark = ui.Color(0xFF1E1610);

class _Painter {
  final ui.Canvas c;
  final _Material m;
  final double t;
  final double fade;
  final ui.Paint p = _manePaint;
  _Painter(this.c, this.m, this.t, this.fade);
  void glow(double x, double y, double rx, double ry, double alpha) {
    c.save();
    c.translate(x, y);
    c.scale(rx, ry);
    c.drawCircle(
      ui.Offset.zero,
      1,
      p
        ..style = ui.PaintingStyle.fill
        ..shader = m.glow
        ..color = ui.Color.fromRGBO(255, 255, 255, alpha * fade),
    );
    c.restore();
  }

  void fill(ui.Path path, double alpha, {bool glass = true}) {
    c.drawPath(
      path,
      p
        ..style = ui.PaintingStyle.fill
        ..shader = glass ? m.glass : null
        ..color = (glass ? const ui.Color(0xFFFFFFFF) : m.ink).withValues(
          alpha: alpha * fade,
        ),
    );
  }

  /// A seam, crest, cord or arc along [path]: one filled ribbon that swells
  /// to ~1.5x [width] in the middle and tapers to points, so it reads as
  /// material rather than a stroked wire. Every caller passes a static path,
  /// so the ribbon is flattened once and reused.
  void line(ui.Path path, double width, double alpha, {bool dark = false}) {
    c.drawPath(
      vfxRibbonAlongStaticPath(path, width * 1.5, taper: 0.4),
      p
        ..style = ui.PaintingStyle.fill
        ..shader = dark ? m.glass : null
        ..color = (dark ? const ui.Color(0xFFFFFFFF) : m.light).withValues(
          alpha: alpha * fade,
        ),
    );
  }

  void dot(double x, double y, double r, double alpha) {
    c.drawCircle(
      ui.Offset(x, y),
      r,
      p
        ..shader = null
        ..style = ui.PaintingStyle.fill
        ..color = m.light.withValues(alpha: alpha * fade),
    );
  }

  void ribbon(double phase, double alpha, double width) {
    c.save();
    c.translate(-phase * 9, sin(t * 2 + phase) * 3);
    c.scale(1 + phase * 0.15, width);
    fill(_ribbon, alpha);
    c.restore();
  }

  void flecks(int count, {double speed = 1, bool inward = false}) {
    for (var i = 0; i < count; i++) {
      final f = (t * speed + i / count) % 1.0;
      final x = inward ? -38 + f * 34 : -12 - f * 27;
      dot(
        x,
        sin(i * 2.4 + f) * (3 + f * 7),
        0.35 + (1 - f) * 0.6,
        sin(f * pi) * 0.65,
      );
    }
  }

  void hotSurface(ui.Path body, {double intensity = 0.3}) {
    c.save();
    c.clipPath(body);
    for (var i = 0; i < 2; i++) {
      glow(
        sin(t * (1 + i * 0.2) + i * 3) * 10,
        cos(t * 1.3 + i * 2) * 6,
        12,
        9,
        intensity,
      );
    }
    c.restore();
  }

  void water() {
    glow(0, 0, 24, 35, 0.16);
    for (var i = 0; i < 3; i++) {
      final f = (t * 0.75 + i / 3) % 1.0;
      c.save();
      c.translate(-f * 15, 0);
      c.scale(1, 0.88 + f * 0.2);
      fill(_wave, sin(f * pi) * 0.6);
      // A broad band of foam on the crest, not a bright hairline (three of
      // them stacked read as ruled lines across the wave).
      line(_crest, 0.95, sin(f * pi) * 0.34);
      c.restore();
    }
    for (var i = 0; i < 5; i++) {
      final f = (t * 0.6 + i / 5) % 1.0;
      dot(8 - 15 * f * f, -25 + f * 50, 0.6, sin(f * pi) * 0.7);
    }
  }

  void air() {
    glow(8, 0, 25, 8, 0.18);
    for (var i = 0; i < 3; i++) {
      c.save();
      c.translate(-i * 5.0, sin(t * 5 + i) * 4);
      c.scale(1.4, 0.23 + i * 0.13);
      fill(_ribbon, 0.26);
      c.restore();
    }
    flecks(6, speed: 2.4);
  }

  void earth() {
    glow(0, 0, 24, 20, 0.14);
    // Independently grinding plates; their seams open as pressure builds.
    for (var i = 0; i < 3; i++) {
      c.save();
      c.translate(-i * 7.0, sin(t * 2 + i * 2) * 2);
      c.rotate(sin(t * 0.8 + i) * 0.07);
      c.scale(1 - i * 0.16);
      fill(_stone, 0.96);
      hotSurface(_stone, intensity: 0.22);
      line(_fracture, 0.4, 0.22 + 0.18 * sin(t * 2 + i));
      c.restore();
    }
    for (var i = 0; i < 4; i++) {
      final f = (t * 0.65 + i / 4) % 1.0;
      c.save();
      c.translate(-16 - f * 22, sin(i * 2.4) * (9 + f * 10));
      c.rotate(f * 3 + i);
      c.scale(0.12 * (1 - f));
      fill(_stone, sin(f * pi));
      c.restore();
    }
  }

  /// A quake zone: the ground broken over the whole patch — a dark stain
  /// with lit fault lines running across it and small stones jolting up
  /// out of it on a slow beat, dust hanging over it. It was two expanding
  /// hairline cracks.
  void quake() {
    final beat = (t * 0.9) % 1.0;
    final jolt = pow(1 - beat, 3).toDouble();
    vfxFillPath(
      c,
      vfxBlob(ui.Offset.zero, 23, 2.7, n: 14, wobble: 0.18),
      _earthDark,
      0.5 * fade,
    );
    glow(0, 0, 26, 24, 0.08 + 0.12 * jolt);
    for (var i = 0; i < 2; i++) {
      c.save();
      c.rotate(i * 1.9 + 0.3);
      c.scale(1.5);
      line(_fracture, 0.45, 0.3 + 0.35 * jolt);
      c.restore();
    }
    for (var i = 0; i < 5; i++) {
      final a = i * 2.399963 + 0.6;
      final d = 20 * sqrt((i + 0.5) / 5);
      final lift = jolt * (1.5 + (i % 3)) * 1.6;
      c.save();
      c.translate(cos(a) * d, sin(a) * d * 0.9 - lift);
      c.rotate(a + jolt * 0.4);
      c.scale(0.17 + 0.05 * (i % 3));
      fill(_stone, 0.9);
      c.restore();
    }
    flecks(4, speed: 0.5);
  }

  void vapor({bool dust = false, bool poison = false, bool field = false}) {
    // Billows expand into the wake. Dust drifts laterally; steam rises.
    final count = dust ? 5 : 4;
    for (var i = 0; i < count; i++) {
      final f = (t * (poison ? 0.45 : 0.7) + i / count) % 1.0;
      glow(
        field ? sin(i * 2.4 + t * 0.3) * 11 : 8 - f * 37,
        field
            ? cos(i * 2.4) * 7 - (dust ? 0 : f * 9)
            : sin(i * 2.4 + t) * 4 - (dust ? 0 : f * 8),
        9 + f * 13,
        7 + f * 12,
        sin(f * pi) * (poison ? 0.5 : 0.36),
      );
    }
    if (dust) {
      flecks(7, speed: 0.6);
    } else if (poison && !field) {
      c.save();
      c.scale(0.8, 0.85);
      fill(_drop, 0.65);
      hotSurface(_drop, intensity: 0.42);
      c.restore();
      for (var i = 0; i < 3; i++) {
        final f = (t * 0.5 + i / 3) % 1.0;
        dot(-9 + i * 5, -f * 13, 0.5 + f, sin(f * pi) * 0.4);
      }
    } else {
      if (!field) ribbon(0, 0.25, 0.3);
      glow(7, 0, 12, 7, 0.55);
    }
  }

  void mud() {
    c.save();
    c.scale(1 + sin(t * 2.5) * 0.06, 1 + cos(t * 2.5) * 0.07);
    fill(_drop, 0.95);
    hotSurface(_drop, intensity: 0.16);
    line(_fracture, 0.5, 0.28, dark: true);
    c.restore();
    for (var i = 0; i < 4; i++) {
      final f = (t * 0.7 + i / 4) % 1.0;
      c.save();
      c.translate(-17 - f * 20, sin(i * 2.4) * (7 + f * 6));
      c.rotate(f + i);
      c.scale(0.12 * (1 - f), 0.1);
      fill(_drop, sin(f * pi));
      c.restore();
    }
  }

  /// A shock field on the ground: a scorch in the stone, charge pooled
  /// over it and three arcs crawling across it, each easing from one hashed
  /// pose to the next. Two fills for the arcs.
  void lightningField() {
    final flash = 0.65 + 0.25 * (vfxGlide(0.7, t, 2.5) * 2 - 1);
    vfxFillPath(
      c,
      vfxBlob(ui.Offset.zero, 15, 4.1, wobble: 0.26),
      _scorch,
      0.6 * fade,
    );
    glow(0, 0, 25, 25, 0.3 * flash);
    final glowPath = ui.Path();
    final core = ui.Path();
    // Two discharges crawling across the field from edge to edge, each its
    // own way (three chords through the middle read as an asterisk).
    for (var i = 0; i < 2; i++) {
      final a0 = i * 2.7 + (vfxGlide(i * 3.1, t, 1.2) - 0.5) * 1.4;
      final a1 = a0 + 1.7 + 0.6 * vfxGlide(i * 5.7 + 0.4, t, 1.5);
      vfxArcInto(
        glowPath,
        core,
        vfxPolar(a0, 20 + 4 * vfxGlide(i * 2.2, t, 1.9)),
        vfxPolar(a1, 18),
        i * 9.0 + 2.0,
        t,
        width: 1.3,
        amp: 0.24,
      );
    }
    c.drawPath(
      glowPath,
      p
        ..style = ui.PaintingStyle.fill
        ..shader = null
        ..color = m.light.withValues(alpha: 0.24 * flash * fade),
    );
    c.drawPath(
      core,
      p..color = m.light.withValues(alpha: 0.85 * flash * fade),
    );
  }

  /// A thrown orb in flight: a small ball of charge with its light round it
  /// and one arc writhing on its skin — the size of its contact, a few
  /// times over in glow, where it was the generic dot with a white core.
  void lightningOrb() {
    final flash = 0.7 + 0.3 * (vfxGlide(1.3, t, 3.0) * 2 - 1);
    glow(0, 0, 22, 22, 0.42 * flash);
    glow(0, 0, 7, 7, 0.8);
    final glowPath = ui.Path();
    final core = ui.Path();
    final a0 = (vfxGlide(2.1, t, 2.2) - 0.5) * 4;
    vfxArcInto(
      glowPath,
      core,
      vfxPolar(a0, 7),
      vfxPolar(a0 + 2.4, 8),
      3.3,
      t,
      width: 1.3,
      amp: 0.5,
    );
    c.drawPath(
      glowPath,
      p
        ..style = ui.PaintingStyle.fill
        ..shader = null
        ..color = m.light.withValues(alpha: 0.3 * flash * fade),
    );
    c.drawPath(
      core,
      p..color = m.light.withValues(alpha: 0.9 * flash * fade),
    );
    flecks(2, speed: 1.4);
  }

  void lightning() {
    // The arcs re-aim a couple of times a second, easing from one hashed pose
    // to the next, instead of snapping to a new one nine times a second.
    final flash = 0.6 + 0.3 * (vfxGlide(0.7, t, 2.5) * 2 - 1);
    glow(0, 0, 23, 17, 0.33);
    glow(0, 0, 6, 5, 0.6);
    // Both arcs run along the slash, one a little behind and to the side of
    // the other, so the piece reads as a charged streak travelling, not a
    // crossed glyph (they used to swing up to 2.6 rad apart: an X).
    for (var i = 0; i < 2; i++) {
      c.save();
      c.translate(i == 0 ? 0 : -4, i == 0 ? -1.5 : 2.5);
      c.rotate((i == 0 ? 0 : 0.22) + (vfxGlide(i * 3.7 + 1.1, t, 2.2) - 0.5) * 0.4);
      // Never mirrored: a flipped copy of the bolt crosses the first one.
      c.scale(
        0.85 + 0.2 * (vfxGlide(i * 5.3 + 2.9, t, 2.2) * 2 - 1),
        i == 0 ? 1 : 0.75,
      );
      // A broad faint band of charge under a lit core that swells along
      // each arc: plasma in a crack, not a white wire.
      line(_bolt, 2.8, flash * 0.18);
      line(_bolt, 0.85, flash * 0.85);
      c.restore();
    }
  }

  void crystal() {
    glow(0, 0, 26, 18, 0.22);
    fill(_shard, 0.85);
    hotSurface(_shard, intensity: 0.42);
    c.save();
    c.scale(1, 0.65 + sin(t * 1.5) * 0.13);
    fill(_facet, 0.45);
    c.restore();
    line(_facet, 0.25, 0.2);
    final f = (t * 0.5) % 1.0;
    glow(-12 + f * 30, 0, 4, 8, sin(f * pi) * 0.5);
    flecks(3, speed: 0.5);
  }

  void plant() {
    glow(0, 0, 24, 14, 0.17);
    // Lean cords: the vine's art grows with its rings as it feeds, so
    // its body stays slim enough not to swamp the field when it is large.
    for (var i = 0; i < 3; i++) {
      c.save();
      c.translate(-i * 3.0, sin(t * 2 + i) * 3);
      c.scale(1, i == 1 ? -0.85 : 0.8 + i * 0.1);
      line(_root, 1.0, 0.8, dark: true);
      line(_root, 0.2, 0.35);
      c.translate(5, -5);
      c.rotate(sin(t + i) * 0.15);
      fill(_thorn, 0.8);
      c.restore();
    }
    final sap = (t * 0.4) % 1.0;
    glow(-20 + sap * 38, sin(sap * pi * 2) * 4, 7, 5, sin(sap * pi) * 0.45);
  }

  void spirit() {
    glow(1, 0, 22, 16, 0.35);
    for (var i = 0; i < 3; i++) {
      c.save();
      c.translate(-i * 4.0, sin(t * 2 + i) * 4);
      c.scale(0.9 + sin(t + i) * 0.1, 0.5);
      fill(_ribbon, 0.3);
      c.restore();
    }
    glow(7 + sin(t * 1.8) * 2, 0, 7, 5, 0.65);
    flecks(3, speed: 0.35);
  }

  void blood() {
    glow(0, 0, 24, 15, 0.22);
    c.save();
    c.scale(1 + sin(t * 3) * 0.04, 0.8 + sin(t * 3) * 0.06);
    fill(_drop, 0.92);
    hotSurface(_drop, intensity: 0.3);
    c.restore();
    // The return current runs toward the caster, echoing healing on pierce.
    for (var i = 0; i < 2; i++) {
      ribbon(i * 0.7, 0.28, 0.3);
    }
    flecks(4, speed: 0.7);
  }

  void light() {
    // A held mote of light: a warm glow round a soft lit heart (no white
    // pip), two veils of it breathing where they lie and a few grains of
    // light drifting off behind. Nothing circles it — the ward's own orbit
    // is the only motion round the creature.
    glow(0, 0, 18, 15, 0.45);
    glow(0, 0, 8, 7, 0.62 + 0.1 * sin(t * 2.4));
    for (var i = 0; i < 2; i++) {
      c.save();
      c.rotate(i * pi + 0.5);
      c.scale(0.5 + 0.05 * sin(t * 1.3 + i), 0.3);
      fill(_ribbon, 0.2);
      c.restore();
    }
    flecks(3, speed: 0.4);
  }

  void fire() {
    // Fire is light and fast: folding flame, unlike Lava's heavy crust.
    glow(3, 0, 24, 17, 0.4);
    for (var i = 0; i < 3; i++) {
      c.save();
      c.translate(-i * 3.0, sin(t * 7 + i * 2) * 2);
      c.scale(1 + sin(t * 5 + i) * 0.15, 0.35 + i * 0.16);
      fill(_ribbon, 0.55);
      c.restore();
    }
    glow(8, 0, 8 + sin(t * 8), 6, 0.9);
    flecks(3, speed: 1.6);
  }

  void lavaPool() {
    c.save();
    c.scale(1.18, 0.86);
    if (maneLavaPoolCrowd > kManeLavaPoolLiteAbove) {
      // Crowded: overlapping pools hide the convection detail anyway, and the
      // clip plus nine layers per pool was ~17% of a device frame at ~200.
      c.drawPath(
        _pool,
        p
          ..style = ui.PaintingStyle.fill
          ..shader = _lavaPoolHeat
          ..color = ui.Color.fromRGBO(255, 255, 255, 0.58 * fade),
      );
      glow(sin(t * 0.65) * 8, cos(t * 0.85) * 5, 12, 8, 0.24);
      c.drawPath(
        _lavaRaft,
        p
          ..shader = null
          ..color = const ui.Color(0xFF21151A).withValues(alpha: 0.18 * fade),
      );
      c.restore();
      return;
    }
    glow(0, 0, 30, 23, 0.12);
    c.drawPath(
      _pool,
      p
        ..style = ui.PaintingStyle.fill
        ..shader = _lavaPoolHeat
        ..color = ui.Color.fromRGBO(255, 255, 255, 0.58 * fade),
    );
    c.save();
    c.clipPath(_pool);
    // Slow uneven convection, with faint warmth passing beneath cooling patches.
    for (var i = 0; i < 3; i++) {
      final phase = t * (0.65 + i * 0.12) + i * 2.2;
      glow(
        sin(phase) * 12,
        cos(phase * 1.3) * 7,
        11,
        7,
        0.22 + 0.06 * sin(phase * 1.7),
      );
    }
    for (var i = 0; i < 3; i++) {
      final a = i * 2.4;
      c.save();
      c.translate(
        cos(a) * (i == 0 ? 3 : 13) + sin(t * 0.5 + i),
        sin(a) * 7 + cos(t * 0.6 + i) * 0.8,
      );
      c.rotate(a + sin(t * 0.4 + i) * 0.12);
      c.scale(0.65 + i * 0.1, 0.7);
      c.drawPath(
        _lavaRaft,
        p
          ..shader = null
          ..color = const ui.Color(0xFF21151A).withValues(alpha: 0.18 * fade),
      );
      c.restore();
    }
    // Small surface vents briefly brighten and cool; no orbiting markings.
    for (var i = 0; i < 2; i++) {
      final f = (t * 0.45 + i * 0.5) % 1.0;
      glow(
        -9 + i * 17,
        3 - i * 7,
        2 + f * 2,
        1 + f,
        pow(sin(f * pi), 4).toDouble() * 0.16,
      );
    }
    c.restore();
    c.restore();
  }

  void zone(String element) {
    switch (element) {
      case 'Lightning':
        lightningField();
      case 'Steam':
        vapor(field: true);
      case 'Dust':
        vapor(dust: true, field: true);
      case 'Poison':
        vapor(poison: true, field: true);
      case 'Plant':
        plant();
      case 'Earth':
        quake();
      case 'Lava':
        lavaPool();
      case 'Mud':
        c.save();
        c.scale(1.2, 0.8);
        fill(_pool, 0.75);
        hotSurface(_pool, intensity: 0.15);
        c.restore();
      default:
        vapor(field: true);
    }
  }
}

/// How many Mane Lava pools are on the field this frame. A game sets it before
/// its projectile pass; above [kManeLavaPoolLiteAbove] pools draw a lighter
/// version. Modes that never set it keep full detail.
int maneLavaPoolCrowd = 0;
const kManeLavaPoolLiteAbove = 24;

/// How far each Mane piece's art reaches at scale 1, in local units: the
/// faint edge of its glow and wake, measured (phase-4 audit, drawn extent
/// over visualScale).
const Map<String, double> _maneArtReach = {
  'Water': 36,
  'Lava': 47,
  'Ice': 53,
  'Steam': 36,
  'Earth': 35,
  'Mud': 36,
  'Dust': 38,
  'Crystal': 31,
  'Air': 59,
  'Plant': 32,
  'Poison': 38,
  'Spirit': 39,
  'Dark': 33,
  'Blood': 46,
  'Fire': 44,
  'Light': 20,
  'Lightning': 17,
};

/// The scale a moving Mane piece is drawn at: its visualScale — Mane's scaler
/// grows visualScale and radiusMultiplier together (scaleManeProjectile), so
/// the art keeps step with the contact radius — but never so large that the
/// art reaches past the piece's own snare or effect ring (decision
/// 2026-10-10): the ring is what it does, and art drawn past it overstates
/// it. Uncapped, the masses reached ~10x their contact at perfect and the fed
/// Plant vine filled the screen. A Plant vine's rings grow as it feeds, so
/// its art grows with them.
double maneArtScale(Projectile projectile, {double floor = 0.65}) {
  final s = max(floor, projectile.visualScale);
  final ring = max(projectile.effectRadius, projectile.snareRadius);
  final reach = _maneArtReach[projectile.element];
  if (ring <= 0 || reach == null) return s;
  return max(0.3, min(s, ring / reach));
}

/// Whether this effect owns its ambient motion instead of using spawned wisps.
bool usesAlchemicalManeVisual(Projectile projectile) {
  if (projectile.abilityFamily != 'mane' ||
      !_materials.containsKey(projectile.element)) {
    return false;
  }
  if (!projectile.stationary && projectile.element == 'Lava') return false;
  return projectile.visualStyle == ProjectileVisualStyle.slash ||
      (projectile.visualStyle == ProjectileVisualStyle.sigil &&
          (projectile.stationary || projectile.element == 'Lightning'));
}

/// Claims only authored Mane specials, leaving basic attacks and other families
/// with their own renderers. Ice/Lava/Dark moving bodies live in the main file.
bool drawAlchemicalManeVisual({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required double time,
}) {
  final element = projectile.element;
  if (!usesAlchemicalManeVisual(projectile)) return false;
  final material = _materials[element]!;
  final phase =
      time +
      projectile.angle +
      (position.dx + position.dy) * (projectile.stationary ? 0.005 : 0);
  final fade = (projectile.life / 0.25).clamp(0.0, 1.0);
  canvas.save();
  canvas.translate(position.dx, position.dy);
  if (projectile.stationary) {
    final radius = max(
      24.0,
      max(projectile.effectRadius, projectile.snareRadius),
    ).clamp(24.0, 220.0);
    // Zone geometry reaches about 28 local units: kept inside the ring.
    canvas.scale(radius / 28);
    _Painter(canvas, material, phase, fade).zone(element!);
  } else {
    canvas.rotate(projectile.angle);
    canvas.scale(maneArtScale(projectile));
    final p = _Painter(canvas, material, phase, fade);
    switch (element) {
      case 'Water':
        p.water();
      case 'Air':
        p.air();
      case 'Earth':
        p.earth();
      case 'Steam':
        p.vapor();
      case 'Dust':
        p.vapor(dust: true);
      case 'Poison':
        p.vapor(poison: true);
      case 'Mud':
        p.mud();
      case 'Lightning':
        // The scattered orbs fly as sigils; the special itself is a slash.
        projectile.visualStyle == ProjectileVisualStyle.sigil
            ? p.lightningOrb()
            : p.lightning();
      case 'Crystal':
        p.crystal();
      case 'Plant':
        p.plant();
      case 'Spirit':
        p.spirit();
      case 'Blood':
        p.blood();
      case 'Light':
        p.light();
      case 'Fire':
        p.fire();
    }
  }
  canvas.restore();
  return true;
}

final _basicIce = _Material(0xFF527B88, 0xFFD4E8DF);
final _basicDark = _Material(0xFF544465, 0xFFB5A5C0);
final _basicBlade = ui.Path()
  ..moveTo(18, 0)
  ..quadraticBezierTo(2, -8, -14, 2)
  ..quadraticBezierTo(0, 1, 18, 0)
  ..close();
final _basicEdge = ui.Path()
  ..moveTo(-7, 0)
  ..quadraticBezierTo(4, -2.2, 16, -0.2);
final _basicWake = ui.Path()
  ..moveTo(4, 0)
  ..quadraticBezierTo(-10, -3, -34, 2)
  ..quadraticBezierTo(-12, 1, 4, 0)
  ..close();

/// Untagged moving slashes are the family-basic twin blades. Special and
/// stationary effects retain their dedicated materials and gameplay markers.
bool drawAlchemicalManeBasicVisual({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required double time,
}) {
  if (projectile.visualStyle != ProjectileVisualStyle.slash ||
      projectile.abilityFamily.isNotEmpty ||
      projectile.stationary) {
    return false;
  }
  final material = switch (projectile.element) {
    'Ice' => _basicIce,
    'Dark' => _basicDark,
    _ => _materials[projectile.element],
  };
  if (material == null) return false;
  final fade = (projectile.life / 0.15).clamp(0.0, 1.0);
  final p = _Painter(canvas, material, time, fade);
  canvas.save();
  canvas.translate(position.dx, position.dy);
  canvas.rotate(projectile.angle);
  canvas.scale(projectile.visualScale.clamp(0.65, 3.4));
  // One short wake and a thin material edge. No motes, sigils or glow clouds
  // on a repeatedly fired basic attack; the pair itself supplies the motion.
  p.fill(_basicWake, 0.18);
  p.fill(_basicBlade, 0.95);
  p.line(_basicEdge, 0.65, 0.52 + 0.12 * sin(time * 4 + projectile.angle * 3));
  canvas.restore();
  return true;
}
