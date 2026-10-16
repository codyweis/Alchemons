// lib/games/cosmic_survival/arena_art.dart
//
// The arena Survival is fought in, in the same material as the core at its
// centre: the core's light pooled faintly on the disc it holds, a belt of
// dust at the rim where the hordes come through, and sky in two depths
// behind it. The rim used to be a pulsing cyan hoop with tick marks; it is
// now the outermost and densest of the core's dust lanes (see
// paintOrbField), so the edge of the arena reads as matter, not a UI line.
//
// The enemies' heavier fire lives here too — the siege beam and the
// colossus's shockwave — drawn as filled, lit shapes in the element's
// material rather than stroked lines. Their shots are shared with open
// space, in cosmic/hostile_shot_vfx.dart.
//
// Budget: no blur, no offscreen layers. Stars and grains go through
// drawRawPoints in a few buckets; the floor is one gradient fill; the
// nebula behind the stars is four gradient fills and three point batches.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart' show elementColor;
import 'package:alchemons/games/cosmic/vfx_shapes.dart';
import 'package:alchemons/games/cosmic_survival/orb_art.dart';
import 'package:alchemons/models/survival_upgrades.dart';
import 'package:flutter/painting.dart';

// ── point batches ───────────────────────────────────────────────────────────

/// Points in buckets, each bucket drawn once as round dots.
class _Points {
  _Points(int buckets)
    : _pts = List.generate(buckets, (_) => Float32List(256)),
      _n = List.filled(buckets, 0);

  final List<Float32List> _pts;
  final List<int> _n;

  static final Paint _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  void clear() => _n.fillRange(0, _n.length, 0);

  void add(int b, double x, double y) {
    var buf = _pts[b];
    final i = _n[b] * 2;
    if (i + 2 > buf.length) {
      _pts[b] = buf = Float32List(buf.length * 2)..setAll(0, buf);
    }
    buf[i] = x;
    buf[i + 1] = y;
    _n[b]++;
  }

  void draw(Canvas c, int b, double diameter, Color color) {
    final n = _n[b];
    if (n == 0 || diameter <= 0 || color.a <= 0) return;
    _paint
      ..strokeWidth = diameter
      ..color = color;
    c.drawRawPoints(
      ui.PointMode.points,
      Float32List.sublistView(_pts[b], 0, n * 2),
      _paint,
    );
  }
}

// ── sky ─────────────────────────────────────────────────────────────────────

/// The sky behind the arena: near stars fixed in the world and a far layer
/// that drifts at a quarter of the camera's speed, so the field has depth
/// as the ship swings round the core. Each layer is batched by size and
/// brightness — the old field drew every star as its own circle.
class ArenaSky {
  ArenaSky() {
    final r = Random(91);
    for (var i = 0; i < _farCount; i++) {
      _far[i * 4] = r.nextDouble() * _farTile;
      _far[i * 4 + 1] = r.nextDouble() * _farTile;
      _far[i * 4 + 2] = 0.12 + r.nextDouble() * 0.28;
      _far[i * 4 + 3] = r.nextDouble() * 2 * pi;
    }
  }

  static const _farCount = 90;
  static const _farTile = 1400.0;
  static const _farFactor = 0.25;
  final Float32List _far = Float32List(_farCount * 4);

  /// Near stars as (x, y, size, twinkle rate, brightness), in world units.
  final List<double> _near = [];

  static const _sizes = 3, _levels = 6;
  final _Points _pts = _Points(_sizes * _levels + _levels);

  void addStar(
    double x,
    double y,
    double size,
    double twinkle,
    double brightness,
  ) => _near.addAll([x, y, size, twinkle, brightness]);

  /// Paints both layers over [view] (world units), at [zoom] screen pixels
  /// per world unit.
  void paint(Canvas c, Rect view, double time, double zoom) {
    _pts.clear();
    // Far layer: one tile repeated, shifted so it scrolls at _farFactor.
    final shiftX = view.left * (1 - _farFactor);
    final shiftY = view.top * (1 - _farFactor);
    final ox = view.left * _farFactor, oy = view.top * _farFactor;
    final c0 = (ox / _farTile).floor(),
        c1 = ((ox + view.width) / _farTile).floor();
    final r0 = (oy / _farTile).floor(),
        r1 = ((oy + view.height) / _farTile).floor();
    final farBase = _sizes * _levels;
    for (var col = c0; col <= c1; col++) {
      for (var row = r0; row <= r1; row++) {
        final tx = col * _farTile + shiftX, ty = row * _farTile + shiftY;
        for (var i = 0; i < _farCount; i++) {
          final a =
              _far[i * 4 + 2] * (0.7 + 0.3 * sin(time * 0.6 + _far[i * 4 + 3]));
          _pts.add(
            farBase + (a / 0.4 * _levels).floor().clamp(0, _levels - 1),
            tx + _far[i * 4],
            ty + _far[i * 4 + 1],
          );
        }
      }
    }
    // Near layer.
    const m = 48.0;
    for (var i = 0; i < _near.length; i += 5) {
      final x = _near[i], y = _near[i + 1];
      if (x < view.left - m ||
          x > view.right + m ||
          y < view.top - m ||
          y > view.bottom + m) {
        continue;
      }
      final a =
          _near[i + 4] * (0.5 + 0.5 * sin(time * _near[i + 3] + x * 0.01));
      if (a < 0.03) continue;
      final s = ((_near[i + 2] - 0.5) / 2.0 * _sizes).floor().clamp(
        0,
        _sizes - 1,
      );
      final l = (a * _levels).floor().clamp(0, _levels - 1);
      _pts.add(s * _levels + l, x, y);
    }

    // A star never shrinks below a pixel and a half as the camera pulls out.
    final px = 1 / zoom;
    for (var l = 0; l < _levels; l++) {
      _pts.draw(
        c,
        farBase + l,
        max(1.0, 1.2 * px),
        const Color(0xFFCFD6F2).withValues(alpha: (l + 0.5) / _levels * 0.4),
      );
    }
    for (var s = 0; s < _sizes; s++) {
      for (var l = 0; l < _levels; l++) {
        _pts.draw(
          c,
          s * _levels + l,
          max(1.2 + s * 1.1, 1.5 * px),
          const Color(0xFFF4F1EA).withValues(alpha: (l + 0.5) / _levels),
        );
      }
    }
  }
}

// ── the nebula ──────────────────────────────────────────────────────────────

/// One cloud of the nebula, centred [x], [y] from the core, [rx] by [ry],
/// wandering [drift] units on a [period]-second loop.
class _Cloud {
  const _Cloud(
    this.x,
    this.y,
    this.rx,
    this.ry,
    this.color,
    this.weight,
    this.drift,
    this.period,
  );
  final double x, y, rx, ry, weight, drift, period;
  final Color color;
}

/// Deep midnight clouds, with one faint warm one near the core.
const _kClouds = [
  _Cloud(-700, -900, 1100, 700, Color(0xFF3B2F86), 0.9, 120, 70),
  _Cloud(800, -200, 800, 1000, Color(0xFF1F4A6E), 0.8, 100, 55),
  _Cloud(-400, 900, 1000, 650, Color(0xFF5A2E66), 0.75, 110, 63),
  _Cloud(250, -150, 600, 500, Color(0xFF6A5232), 0.3, 70, 47),
];

/// Faint clouds and a haze of fine grains behind the stars, so the fight
/// has a sky with depth rather than a black page. It slides at a fifth of
/// the camera's speed; the clouds wander and breathe on loops of about a
/// minute, and their grains turn slowly round them, glimmering in and out.
/// Kept dim: it is the back of the sky, never something to look at.
///
/// Budget: four gradient fills (shaders built once) and three point batches
/// of at most [_grainCount] grains, culled to the view. No blur.
class ArenaNebula {
  ArenaNebula() {
    final r = Random(17);
    var k = 0;
    for (var ci = 0; ci < _kClouds.length; ci++) {
      final cl = _kClouds[ci];
      final n = (_grainCount * cl.weight / _totalWeight).round();
      for (var i = 0; i < n && k < _grainCount; i++, k++) {
        // Denser toward the middle, in an ellipse the cloud's own shape.
        final d = pow(r.nextDouble(), 0.75).toDouble();
        _cloud[k] = ci;
        _angle[k] = r.nextDouble() * 2 * pi;
        _reach[k] = d;
        // Inner grains turn a little faster, like the dust lanes.
        _turn[k] = (0.006 + 0.014 * (1 - d)) * (ci.isEven ? 1 : -1);
        _bucket[k] = r.nextInt(_buckets);
      }
    }
    _count = k;
  }

  static const _factor = 0.2;
  static const _grainCount = 2600;
  static const _buckets = 3;
  static final double _totalWeight = _kClouds.fold(
    0.0,
    (sum, c) => sum + c.weight,
  );

  int _count = 0;
  final Int8List _cloud = Int8List(_grainCount);
  final Float32List _angle = Float32List(_grainCount);
  final Float32List _reach = Float32List(_grainCount);
  final Float32List _turn = Float32List(_grainCount);
  final Int8List _bucket = Int8List(_grainCount);
  final List<Float32List> _pts = List.generate(
    _buckets,
    (_) => Float32List(_grainCount * 2),
  );
  final List<int> _n = List.filled(_buckets, 0);

  static final List<ui.Shader> _shaders = [
    for (final cl in _kClouds)
      ui.Gradient.radial(
        Offset.zero,
        1,
        [
          cl.color.withValues(alpha: 0.26 * cl.weight),
          cl.color.withValues(alpha: 0.10 * cl.weight),
          cl.color.withValues(alpha: 0),
        ],
        const [0.0, 0.55, 1.0],
      ),
  ];
  final Paint _fill = Paint();
  final Paint _dots = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 1.4;
  final List<Offset> _centre = List.filled(_kClouds.length, Offset.zero);
  final List<double> _breath = List.filled(_kClouds.length, 1);

  /// Paints the nebula round [orb] for a camera looking at [view], [time]
  /// seconds into the run.
  void paint(Canvas c, Rect view, Offset orb, double time) {
    final at = orb + (view.center - orb) * (1 - _factor);
    for (var ci = 0; ci < _kClouds.length; ci++) {
      final cl = _kClouds[ci];
      final w = 2 * pi * time / cl.period;
      _centre[ci] =
          at + Offset(cl.x + cos(w) * cl.drift, cl.y + sin(w * 0.7) * cl.drift);
      _breath[ci] = 1 + 0.05 * sin(w * 1.3 + ci);
      final rx = cl.rx * _breath[ci], ry = cl.ry * _breath[ci];
      final p = _centre[ci];
      if (p.dx + rx < view.left ||
          p.dx - rx > view.right ||
          p.dy + ry < view.top ||
          p.dy - ry > view.bottom) {
        continue;
      }
      c.save();
      c.translate(p.dx, p.dy);
      c.scale(rx, ry);
      c.drawCircle(Offset.zero, 1, _fill..shader = _shaders[ci]);
      c.restore();
    }
    _fill.shader = null;

    for (var b = 0; b < _buckets; b++) {
      _n[b] = 0;
    }
    final l = view.left - 4, t = view.top - 4;
    final rgt = view.right + 4, btm = view.bottom + 4;
    for (var k = 0; k < _count; k++) {
      final ci = _cloud[k];
      final cl = _kClouds[ci];
      final a = _angle[k] + _turn[k] * time;
      final d = _reach[k] * _breath[ci];
      final x = _centre[ci].dx + cos(a) * cl.rx * d;
      final y = _centre[ci].dy + sin(a) * cl.ry * d;
      if (x < l || x > rgt || y < t || y > btm) continue;
      final b = _bucket[k];
      final i = _n[b];
      _pts[b][i] = x;
      _pts[b][i + 1] = y;
      _n[b] = i + 2;
    }
    for (var b = 0; b < _buckets; b++) {
      if (_n[b] == 0) continue;
      // Each third glimmers on its own slow beat.
      final glow = 0.5 + 0.5 * sin(time * 0.35 + b * 2.1);
      _dots.color = const Color(0xFFB8BEE0).withValues(
        alpha: 0.08 + 0.12 * glow,
      );
      c.drawRawPoints(
        ui.PointMode.points,
        Float32List.sublistView(_pts[b], 0, _n[b]),
        _dots,
      );
    }
  }
}

// ── the rim ─────────────────────────────────────────────────────────────────

/// The arena's floor and edge: the core's light pooled faintly on the disc
/// it holds, and a belt of dust at the rim — hundreds of grains on slow
/// orbits over a soft lane, the planets' particle-ring recipe laid flat.
/// The belt is the core's outermost dust lane, so it takes the core's
/// color: a different core lights a different arena.
class ArenaRim {
  ArenaRim() {
    final r = Random(1140);
    double gauss() {
      final u = max(1e-9, r.nextDouble());
      return sqrt(-2 * log(u)) * cos(2 * pi * r.nextDouble());
    }

    void grain(double rad, double a) {
      _grains.addAll([
        rad,
        a,
        0.4 + r.nextDouble() * 0.6, // size
        r.nextDouble() * 2 * pi, // twinkle phase
        0.6 + r.nextDouble() * 1.4, // twinkle rate
      ]);
    }

    // The belt proper, densest just inside the edge.
    for (var i = 0; i < 900; i++) {
      grain(1.0 - 0.006 + gauss() * 0.011, r.nextDouble() * 2 * pi);
    }
    // Clumps in it, where the dust has gathered.
    for (var k = 0; k < 26; k++) {
      final a = r.nextDouble() * 2 * pi;
      final rad = 1.0 + gauss() * 0.006;
      for (var i = 0; i < 16; i++) {
        grain(rad + gauss() * 0.004, a + gauss() * 0.012);
      }
    }
    // A thin inner lane, and a few grains strayed out past the edge.
    for (var i = 0; i < 260; i++) {
      grain(0.962 + gauss() * 0.004, r.nextDouble() * 2 * pi);
    }
    for (var i = 0; i < 140; i++) {
      grain(1.02 + r.nextDouble().abs() * 0.05, r.nextDouble() * 2 * pi);
    }
  }

  /// (radius as a fraction of the arena's, start angle, size 0..1, twinkle
  /// phase, twinkle rate) per grain.
  final List<double> _grains = [];
  final _Points _pts = _Points(6);

  /// How far past the rim the floor gradient reaches.
  static const _reach = 1.07;
  final Map<OrbBaseSkin, ui.Shader> _floors = {};
  final Paint _fill = Paint();

  static const _ash = Color(0xFF9A8F7C);

  ui.Shader _floor(OrbBaseSkin skin) => _floors[skin] ??= () {
    final l = orbLook(skin);
    final tint = Color.lerp(l.rim, _ash, 0.45)!;
    // (radius / reach, alpha): a faint pool over the disc, a dip before the
    // inner lane, the belt's lane at the rim, nothing past it.
    const profile = <(double, double)>[
      (0.0, 0.055),
      (0.45, 0.035),
      (0.85, 0.018),
      (0.94, 0.018),
      (0.962, 0.04),
      (0.975, 0.02),
      (0.992, 0.07),
      (1.0, 0.09),
      (1.012, 0.05),
      (1.04, 0.012),
      (_reach, 0.0),
    ];
    return ui.Gradient.radial(
      Offset.zero,
      1,
      [for (final (_, a) in profile) tint.withValues(alpha: a)],
      [for (final (r, _) in profile) r / _reach],
    );
  }();

  /// Paints the floor and the belt for an arena of [radius] round [centre],
  /// culled to [view] (world units), at [zoom] screen pixels per unit.
  void paint(
    Canvas c,
    Offset centre,
    double radius,
    OrbBaseSkin skin,
    double time,
    Rect view,
    double zoom,
  ) {
    final l = orbLook(skin);

    c.save();
    c.translate(centre.dx, centre.dy);
    c.scale(radius * _reach);
    _fill.shader = _floor(skin);
    c.drawCircle(Offset.zero, 1, _fill);
    c.restore();

    // Grains — only the arc in view. Outer grains turn a little slower,
    // as dust on real orbits does.
    _pts.clear();
    final cull = view.inflate(8);
    for (var i = 0; i < _grains.length; i += 5) {
      final f = _grains[i];
      final rad = radius * f;
      final a = _grains[i + 1] + time * 0.011 / (f * sqrt(f));
      final x = centre.dx + cos(a) * rad;
      final y = centre.dy + sin(a) * rad;
      if (!cull.contains(Offset(x, y))) continue;
      final tw = sin(time * _grains[i + 4] + _grains[i + 3]);
      final big = _grains[i + 2] > 0.75 ? 3 : 0;
      final lit = tw > 0.82 ? 2 : (tw > -0.2 ? 1 : 0);
      _pts.add(big + lit, x, y);
    }
    final px = 1 / zoom;
    final dim = Color.lerp(l.rim, _ash, 0.5)!;
    final mid = Color.lerp(l.grainDim, l.essence, 0.25)!;
    final lit = l.grainLit;
    for (final (b, col, a) in [(0, dim, 0.32), (1, mid, 0.5), (2, lit, 0.85)]) {
      _pts.draw(c, b, max(2.2, 1.3 * px), col.withValues(alpha: a));
      _pts.draw(c, b + 3, max(3.4, 1.9 * px), col.withValues(alpha: a));
    }
  }
}

// ── enemy fire ──────────────────────────────────────────────────────────────

/// The brute's siege beam from [origin] along [angle]: a lens of the
/// element's light, brightest on its axis and tapering at both ends, over a
/// wider faint band. [fade] runs 1 → 0 over the beam's life.
void paintSiegeBeam(
  Canvas c,
  Offset origin,
  double angle,
  double length,
  double width,
  String element,
  double fade,
) {
  if (fade <= 0) return;
  final m = vfxMaterial(element);
  final glow = Color.lerp(elementColor(element), m.light, 0.3)!;
  c.save();
  c.translate(origin.dx, origin.dy);
  c.rotate(angle);
  final outer = width * 2.2;
  vfxCrossLit(
    c,
    vfxLens(length, outer, outer * 1.5, length * 0.3),
    outer / 2,
    glow,
    glow,
    0.32 * fade,
    plateau: 0.2,
  );
  vfxCrossLit(
    c,
    vfxLens(length, width, width, length * 0.18),
    width / 2,
    glow,
    Color.lerp(glow, m.glint, 0.6)!,
    0.9 * fade,
    plateau: 0.35,
  );
  c.restore();
  // Where it leaves the brute, light pools.
  vfxSpill(c, origin, width * 2.6, glow, 0.35 * fade);
}

/// The colossus's shockwave at [radius] round [origin]: a wide faint band of
/// the element's light and a front of grains thrown outward, so the front —
/// the only part that hurts — is the part that reads. [fade] runs 1 → 0.
void paintShockFront(
  Canvas c,
  Offset origin,
  double radius,
  String element,
  double fade,
) {
  if (fade <= 0 || radius <= 1) return;
  final m = vfxMaterial(element);
  final glow = Color.lerp(elementColor(element), m.light, 0.3)!;
  final lit = Color.lerp(glow, m.glint, 0.5)!;
  vfxSoftRing(c, origin, radius - 14, 40, glow, 0.34 * fade);
  _front.clear();
  // The front: grains crowded at the wavefront, the brightest running just
  // ahead of it. Behind it, a thinner dust it has already thrown, so the
  // eye reads which way it is travelling.
  final n = (radius * 0.55).clamp(36, 200).toInt();
  for (var i = 0; i < n; i++) {
    final a = (i + vfxHash(i * 1.7)) / n * 2 * pi;
    final j = vfxHash(i * 3.1);
    final d = radius + (j - 0.55) * 22;
    _front.add(j > 0.7 ? 1 : 0, origin.dx + cos(a) * d, origin.dy + sin(a) * d);
    if (i.isEven) {
      final back = radius - 18 - vfxHash(i * 5.3) * 46;
      if (back > 0) {
        _front.add(2, origin.dx + cos(a) * back, origin.dy + sin(a) * back);
      }
    }
  }
  _front.draw(c, 2, 2.6, glow.withValues(alpha: 0.32 * fade));
  _front.draw(c, 0, 3.4, glow.withValues(alpha: 0.85 * fade));
  _front.draw(c, 1, 4.6, lit.withValues(alpha: 0.95 * fade));
}

final _Points _front = _Points(3);

/// The orb's own light going out from it, [t] (0 → 1) of the way through:
/// a front of grains racing out to [reach] and thinning as it goes, over a
/// faint pool. The shield pulse's push is pale; the nova's burn is [light]
/// at its hottest ([hot]). Wide, faint and gone in half a second — a front
/// of matter, never a ring.
///
/// Budget: one gradient fill and three point batches while it runs.
void paintOrbFront(
  Canvas c,
  Offset origin,
  double reach,
  Color light,
  double t, {
  bool hot = false,
}) {
  if (t <= 0 || t >= 1) return;
  final e = 1 - pow(1 - t, 3).toDouble();
  final radius = 30 + (reach - 30) * e;
  final fade = (1 - t) * (1 - t);
  vfxSpill(c, origin, radius * 1.05, light, (hot ? 0.26 : 0.16) * fade);
  _front.clear();
  final n = (radius * 0.5).clamp(30, 160).toInt();
  for (var i = 0; i < n; i++) {
    final a = (i + vfxHash(i * 2.3 + reach)) / n * 2 * pi;
    final j = vfxHash(i * 4.1 + reach);
    final d = radius + (j - 0.6) * 18;
    _front.add(j > 0.75 ? 1 : 0, origin.dx + cos(a) * d, origin.dy + sin(a) * d);
    if (i % 3 == 0) {
      final back = radius - 12 - vfxHash(i * 6.7) * 36;
      if (back > 0) {
        _front.add(2, origin.dx + cos(a) * back, origin.dy + sin(a) * back);
      }
    }
  }
  final lit = Color.lerp(light, const Color(0xFFFFFFFF), hot ? 0.45 : 0.25)!;
  _front.draw(c, 2, 3.0, light.withValues(alpha: 0.3 * fade));
  _front.draw(c, 0, 4.2, light.withValues(alpha: 0.85 * fade));
  _front.draw(c, 1, 5.6, lit.withValues(alpha: 0.95 * fade));
}
