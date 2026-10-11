import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Filled, tapered shapes for ability art — the material language the Mask
/// traps and Horn share. Nothing here strokes a hairline or draws a closed
/// hoop; those read as UI chrome, not stone, water or fire.

/// Cheap stable noise so shapes are irregular without a Random per frame.
double vfxHash(double x) {
  final s = sin(x * 12.9898) * 43758.5453;
  return s - s.floorToDouble();
}

ui.Offset vfxPolar(double a, double r) => ui.Offset(cos(a) * r, sin(a) * r);

/// Irregular closed blob, smoothed through midpoints so it never reads as a
/// polygon.
ui.Path vfxBlob(
  ui.Offset c,
  double r,
  double seed, {
  int n = 12,
  double wobble = 0.16,
  double squash = 1,
}) {
  final pts = <ui.Offset>[];
  for (var i = 0; i < n; i++) {
    final a = i * pi * 2 / n;
    final rr = r * (1 - wobble + 2 * wobble * vfxHash(seed + i * 1.37));
    pts.add(c + ui.Offset(cos(a) * rr, sin(a) * rr * squash));
  }
  final path = ui.Path();
  final first = (pts.last + pts.first) / 2;
  path.moveTo(first.dx, first.dy);
  for (var i = 0; i < n; i++) {
    final p = pts[i];
    final next = pts[(i + 1) % n];
    final mid = (p + next) / 2;
    path.quadraticBezierTo(p.dx, p.dy, mid.dx, mid.dy);
  }
  return path..close();
}

/// A crescent that tapers to points at both ends, centred on [angle].
ui.Path vfxCrescent(
  ui.Offset c,
  double r,
  double thickness,
  double angle,
  double sweep,
) {
  const n = 14;
  final path = ui.Path();
  for (var k = 0; k <= n; k++) {
    final th = angle - sweep / 2 + sweep * k / n;
    final p = c + vfxPolar(th, r);
    k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  for (var k = n; k >= 0; k--) {
    final th = angle - sweep / 2 + sweep * k / n;
    final w = thickness * sin(pi * k / n);
    final p = c + vfxPolar(th, r - w);
    path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

/// A ribbon along [spine], tapering from [w0] to [w1].
ui.Path vfxRibbon(
  List<ui.Offset> spine,
  double w0,
  double w1, {
  bool taperIn = false,
}) {
  final left = <ui.Offset>[];
  final right = <ui.Offset>[];
  for (var i = 0; i < spine.length; i++) {
    final prev = spine[max(0, i - 1)];
    final next = spine[min(spine.length - 1, i + 1)];
    var t = next - prev;
    final len = t.distance;
    t = len < 1e-4 ? const ui.Offset(1, 0) : t / len;
    final n = ui.Offset(-t.dy, t.dx);
    final f = spine.length == 1 ? 0.0 : i / (spine.length - 1);
    final h = taperIn
        ? w1 * sin(pi * pow(f, 0.6)) / 2 + w0 * (1 - f) * 0.1
        : (w0 + (w1 - w0) * f) / 2;
    left.add(spine[i] + n * h);
    right.add(spine[i] - n * h);
  }
  final path = ui.Path()..moveTo(left.first.dx, left.first.dy);
  for (final p in left.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  for (final p in right.reversed) {
    path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

/// A spiral arm winding in from radius [r] toward the centre.
ui.Path vfxSpiralArm(
  ui.Offset c,
  double r,
  double start,
  double turn,
  double width, {
  double reach = 0.82,
}) {
  final spine = <ui.Offset>[];
  const n = 20;
  for (var k = 0; k <= n; k++) {
    final t = k / n;
    spine.add(c + vfxPolar(start + turn * t, r * (1 - reach * t)));
  }
  return vfxRibbon(spine, width * 0.25, width, taperIn: true);
}

/// A pointed shard lying along [a].
ui.Path vfxShard(ui.Offset c, double len, double width, double a) {
  final d = vfxPolar(a, 1);
  final n = ui.Offset(-d.dy, d.dx);
  return ui.Path()
    ..moveTo(c.dx + d.dx * len, c.dy + d.dy * len)
    ..lineTo(c.dx + n.dx * width, c.dy + n.dy * width)
    ..lineTo(c.dx - d.dx * len * 0.35, c.dy - d.dy * len * 0.35)
    ..lineTo(c.dx - n.dx * width, c.dy - n.dy * width)
    ..close();
}

/// A droplet travelling along [a]: round head, tail behind.
ui.Path vfxDrop(ui.Offset c, double r, double a) {
  final d = vfxPolar(a, 1);
  final n = ui.Offset(-d.dy, d.dx);
  final tail = c - d * r * 2.4;
  return ui.Path()
    ..moveTo(tail.dx, tail.dy)
    ..quadraticBezierTo(
      c.dx + n.dx * r * 1.1 - d.dx * r * 0.4,
      c.dy + n.dy * r * 1.1 - d.dy * r * 0.4,
      c.dx + d.dx * r,
      c.dy + d.dy * r,
    )
    ..quadraticBezierTo(
      c.dx - n.dx * r * 1.1 - d.dx * r * 0.4,
      c.dy - n.dy * r * 1.1 - d.dy * r * 0.4,
      tail.dx,
      tail.dy,
    )
    ..close();
}

/// A leaf lying along [a].
ui.Path vfxLeaf(ui.Offset c, double len, double a) {
  final d = vfxPolar(a, 1);
  final n = ui.Offset(-d.dy, d.dx);
  final tip = c + d * len;
  final mid = c + d * len * 0.5;
  return ui.Path()
    ..moveTo(c.dx, c.dy)
    ..quadraticBezierTo(
      mid.dx + n.dx * len * 0.38,
      mid.dy + n.dy * len * 0.38,
      tip.dx,
      tip.dy,
    )
    ..quadraticBezierTo(
      mid.dx - n.dx * len * 0.38,
      mid.dy - n.dy * len * 0.38,
      c.dx,
      c.dy,
    )
    ..close();
}

/// What an element is made of. [ink] is the dark body, [mid] the lit face,
/// [glint] the rare catch of light, [light] what it spills on the ground.
class VfxMaterial {
  const VfxMaterial(this.ink, this.mid, this.glint, this.light);
  final ui.Color ink, mid, glint, light;
}

VfxMaterial vfxMaterial(String? element) => switch (element) {
  'Fire' => const VfxMaterial(
    ui.Color(0xFF2A0F08),
    ui.Color(0xFFA04A22),
    ui.Color(0xFFFFC27A),
    ui.Color(0xFFE0703A),
  ),
  'Lava' => const VfxMaterial(
    ui.Color(0xFF1E0B06),
    ui.Color(0xFF7E3014),
    ui.Color(0xFFFFA24A),
    ui.Color(0xFFD9602E),
  ),
  'Lightning' => const VfxMaterial(
    ui.Color(0xFF14162A),
    ui.Color(0xFF55609A),
    ui.Color(0xFFE6EBFF),
    ui.Color(0xFFB2B9E3),
  ),
  'Water' => const VfxMaterial(
    ui.Color(0xFF030A10),
    ui.Color(0xFF2E5566),
    ui.Color(0xFFBFD8DE),
    ui.Color(0xFF619BAE),
  ),
  'Ice' => const VfxMaterial(
    ui.Color(0xFF0E1C24),
    ui.Color(0xFF5F8C9A),
    ui.Color(0xFFE4F4F8),
    ui.Color(0xFF92BFC9),
  ),
  'Steam' => const VfxMaterial(
    ui.Color(0xFF1A1E22),
    ui.Color(0xFF7D8A92),
    ui.Color(0xFFE8EEF0),
    ui.Color(0xFFA6BBC5),
  ),
  'Earth' => const VfxMaterial(
    ui.Color(0xFF1E1610),
    ui.Color(0xFF6A543C),
    ui.Color(0xFFD2B892),
    ui.Color(0xFFAC916D),
  ),
  'Mud' => const VfxMaterial(
    ui.Color(0xFF17110B),
    ui.Color(0xFF4E3B28),
    ui.Color(0xFFA08A66),
    ui.Color(0xFF7A6448),
  ),
  'Dust' => const VfxMaterial(
    ui.Color(0xFF231C14),
    ui.Color(0xFF8A7458),
    ui.Color(0xFFE0CCA8),
    ui.Color(0xFFAC916D),
  ),
  'Crystal' => const VfxMaterial(
    ui.Color(0xFF192B2A),
    ui.Color(0xFF405851),
    ui.Color(0xFFA6C7AD),
    ui.Color(0xFF7BBC9C),
  ),
  'Air' => const VfxMaterial(
    ui.Color(0xFF1A2226),
    ui.Color(0xFF6E8A94),
    ui.Color(0xFFE0EEF2),
    ui.Color(0xFFA6BBC5),
  ),
  'Plant' => const VfxMaterial(
    ui.Color(0xFF121C0C),
    ui.Color(0xFF45622E),
    ui.Color(0xFFA8C888),
    ui.Color(0xFF8BAB6B),
  ),
  'Poison' => const VfxMaterial(
    ui.Color(0xFF14170A),
    ui.Color(0xFF5B6A30),
    ui.Color(0xFFC8D890),
    ui.Color(0xFF91A85C),
  ),
  'Spirit' => const VfxMaterial(
    ui.Color(0xFF141A24),
    ui.Color(0xFF6A7C98),
    ui.Color(0xFFDCE6F4),
    ui.Color(0xFFA8B8D8),
  ),
  'Dark' => const VfxMaterial(
    ui.Color(0xFF020207),
    ui.Color(0xFF3A2A48),
    ui.Color(0xFFA48CC8),
    ui.Color(0xFF9768B6),
  ),
  'Light' => const VfxMaterial(
    ui.Color(0xFF2A2618),
    ui.Color(0xFFA89C74),
    ui.Color(0xFFF4EED8),
    ui.Color(0xFFE4D6AB),
  ),
  'Blood' => const VfxMaterial(
    ui.Color(0xFF1C0508),
    ui.Color(0xFF7A1A28),
    ui.Color(0xFFE07088),
    ui.Color(0xFFAA3658),
  ),
  _ => const VfxMaterial(
    ui.Color(0xFF1A1A1E),
    ui.Color(0xFF6A6A72),
    ui.Color(0xFFE0E0E6),
    ui.Color(0xFFA0A0AA),
  ),
};

final ui.Paint _vfxFill = ui.Paint();
final ui.Paint _vfxStroke = ui.Paint()
  ..style = ui.PaintingStyle.stroke
  ..strokeCap = ui.StrokeCap.round
  ..strokeJoin = ui.StrokeJoin.round;

void vfxFillPath(ui.Canvas canvas, ui.Path path, ui.Color color, double alpha) {
  if (alpha <= 0.004) return;
  _vfxFill
    ..shader = null
    ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0));
  canvas.drawPath(path, _vfxFill);
}

// Gradients for the light fills below, cached: a frame of spills, rings and
// beams used to build a new shader object per call. Each is built once per
// colour and shape at unit size (spills and rings are drawn scaled), and the
// strength rides on the paint's alpha, which scales a shader's output — the
// same pixels as baking the strength into the stops.
final Map<int, ui.Shader> _spillShaders = {};
final Map<int, ui.Shader> _ringShaders = {};
final Map<(int, int, int, int), ui.Shader> _crossShaders = {};

ui.Shader _cachedShader<K>(
  Map<K, ui.Shader> cache,
  K key,
  ui.Shader Function() build,
) {
  final hit = cache[key];
  if (hit != null) return hit;
  // Bounded: a charge that swells through many widths churns, never grows.
  if (cache.length >= 192) cache.clear();
  return cache[key] = build();
}

int _rgb(ui.Color c) => c.toARGB32() & 0xFFFFFF;

/// Light pooled on the ground: soft centre, no edge.
void vfxSpill(
  ui.Canvas canvas,
  ui.Offset c,
  double r,
  ui.Color color,
  double strength,
) {
  if (strength <= 0.004 || r <= 0.5) return;
  final rgb = _rgb(color);
  _vfxFill
    ..color = ui.Color.fromRGBO(255, 255, 255, strength.clamp(0.0, 1.0))
    ..shader = _cachedShader(_spillShaders, rgb, () {
      final k = ui.Color(0xFF000000 | rgb);
      return ui.Gradient.radial(
        ui.Offset.zero,
        1,
        [k, k.withValues(alpha: 0.4), k.withValues(alpha: 0)],
        const [0.0, 0.45, 1.0],
      );
    });
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.scale(r);
  canvas.drawCircle(ui.Offset.zero, 1, _vfxFill);
  canvas.restore();
  _vfxFill.shader = null;
}

/// A soft band of light at radius [r] — a shock front or a rim without an
/// outline.
void vfxSoftRing(
  ui.Canvas canvas,
  ui.Offset c,
  double r,
  double band,
  ui.Color color,
  double strength,
) {
  if (strength <= 0.004 || r <= 1) return;
  final outer = r + band;
  // The band's edges in 64ths of the outer radius: a cached gradient per
  // step, finer than a pixel at any size a ring is drawn.
  final inner = (((r - band) / outer).clamp(0.0, 1.0) * 64).round();
  final peak = max(inner, ((r / outer) * 64).round());
  final rgb = _rgb(color);
  _vfxFill
    ..color = ui.Color.fromRGBO(255, 255, 255, strength.clamp(0.0, 1.0))
    ..shader = _cachedShader(
      _ringShaders,
      (rgb << 14) | (inner << 7) | peak,
      () {
        final k = ui.Color(0xFF000000 | rgb);
        final clear = k.withValues(alpha: 0);
        return ui.Gradient.radial(
          ui.Offset.zero,
          1,
          [clear, clear, k, clear],
          [0.0, inner / 64, peak / 64, 1.0],
        );
      },
    );
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.scale(outer);
  canvas.drawCircle(ui.Offset.zero, 1, _vfxFill);
  canvas.restore();
  _vfxFill.shader = null;
}

/// A lens along the x axis from 0 to [len], [h] tall at its widest, tapering
/// to points over [taperIn] at the start and [taperOut] at the end.
ui.Path vfxLens(double len, double h, double taperIn, double taperOut) {
  final a = min(taperIn, len * 0.4);
  final b = min(taperOut, len * 0.4);
  final half = h / 2;
  return ui.Path()
    ..moveTo(0, 0)
    ..quadraticBezierTo(a * 0.35, -half, a, -half)
    ..lineTo(len - b, -half)
    ..quadraticBezierTo(len - b * 0.3, -half, len, 0)
    ..quadraticBezierTo(len - b * 0.3, half, len - b, half)
    ..lineTo(a, half)
    ..quadraticBezierTo(a * 0.35, half, 0, 0)
    ..close();
}

/// Fills [path] with light that is strongest on the beam's axis and falls
/// off to nothing at +-[half].
void vfxCrossLit(
  ui.Canvas canvas,
  ui.Path path,
  double half,
  ui.Color edge,
  ui.Color centre,
  double alpha, {
  double plateau = 0.0,
}) {
  if (alpha <= 0.004 || half <= 0) return;
  // Keyed on both colours, the plateau in 32nds and the half-height in
  // quarter pixels: a beam's widths are its gameplay widths, so a live beam
  // reuses the same two or three gradients every frame.
  final pq = (plateau.clamp(0.0, 1.0) * 32).round();
  final hq = max(1, (half * 4).round());
  final edgeRgb = _rgb(edge), centreRgb = _rgb(centre);
  _vfxFill
    ..color = ui.Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0))
    ..shader = _cachedShader(_crossShaders, (edgeRgb, centreRgb, pq, hq), () {
      final h = hq / 4;
      final p = pq / 32;
      final e = ui.Color(edgeRgb);
      final k = ui.Color(0xFF000000 | centreRgb);
      return ui.Gradient.linear(
        ui.Offset(0, -h),
        ui.Offset(0, h),
        [e.withValues(alpha: 0), k, k, e.withValues(alpha: 0)],
        [0.0, 0.5 - p / 2, 0.5 + p / 2, 1.0],
      );
    });
  canvas.drawPath(path, _vfxFill);
  _vfxFill.shader = null;
}

/// A faceted stone or ice chunk: dark body, one lit face, one glint.
void vfxChunk(
  ui.Canvas canvas,
  ui.Offset c,
  double r,
  double seed,
  VfxMaterial m, {
  double alpha = 1,
  double rot = 0,
  int sides = 6,
  double faceAlpha = 0.7,
}) {
  final pts = <ui.Offset>[];
  for (var k = 0; k < sides; k++) {
    final a = rot + k * pi * 2 / sides + (vfxHash(seed + k) - 0.5) * 0.5;
    pts.add(c + vfxPolar(a, r * (0.72 + 0.4 * vfxHash(seed + k * 2.3))));
  }
  final body = ui.Path()..addPolygon(pts, true);
  vfxFillPath(canvas, body, m.ink, 0.92 * alpha);
  final face = ui.Path()
    ..addPolygon([c + (pts[0] - c) * 0.2, pts[0], pts[1], pts[2]], true);
  vfxFillPath(canvas, face, m.mid, faceAlpha * alpha);
  final glint = ui.Path()
    ..addPolygon([pts[0], pts[1], c + (pts[1] - c) * 0.55], true);
  vfxFillPath(canvas, glint, m.glint, 0.30 * alpha);
}

/// A lightning bolt as a lit core over a faint glow — the one place a line is
/// the right material.
void vfxBolt(
  ui.Canvas canvas,
  ui.Offset from,
  ui.Offset to,
  double seed,
  VfxMaterial m,
  double alpha, {
  double jag = 0.22,
  int segs = 5,
}) {
  final d = to - from;
  final len = d.distance;
  if (len < 1) return;
  final n = ui.Offset(-d.dy, d.dx) / len;
  final path = ui.Path()..moveTo(from.dx, from.dy);
  for (var k = 1; k <= segs; k++) {
    final f = k / segs;
    final off = k == segs ? 0.0 : (vfxHash(seed + k * 3.1) - 0.5) * len * jag;
    final p = from + d * f + n * off;
    path.lineTo(p.dx, p.dy);
  }
  _vfxStroke
    ..color = m.mid.withValues(alpha: 0.22 * alpha)
    ..strokeWidth = 4.2;
  canvas.drawPath(path, _vfxStroke);
  _vfxStroke
    ..color = m.glint.withValues(alpha: 0.9 * alpha)
    ..strokeWidth = 1.3;
  canvas.drawPath(path, _vfxStroke);
}

// ── Grains ──────────────────────────────────────────────────────────────
//
// The game's alchemy is lit sand, so the sparkle and grit in ability art are
// grains — round points painted as one batch, the same `drawRawPoints` idiom
// the sand tray and the star fields use — never drawn star glints. A grain
// that "flares" is one painted in a second, whiter batch.
//
// A painter collects positions with [vfxGrain] and paints them with
// [vfxGrainsFlush]: one draw call per batch, no allocation per frame.

const int _kGrainCap = 160;
final Float32List _grainXY = Float32List(_kGrainCap * 2);
int _grainCount = 0;
final ui.Paint _grainPaint = ui.Paint()..strokeCap = ui.StrokeCap.round;

/// Adds one grain to the pending batch (dropped past the cap).
void vfxGrain(double x, double y) {
  if (_grainCount >= _kGrainCap) return;
  _grainXY[_grainCount * 2] = x;
  _grainXY[_grainCount * 2 + 1] = y;
  _grainCount++;
}

/// Forgets any grains collected but not painted.
void vfxGrainsDiscard() => _grainCount = 0;

/// Paints the pending grains as round points [size] across, then empties the
/// batch.
void vfxGrainsFlush(
  ui.Canvas canvas,
  double size,
  ui.Color color,
  double alpha,
) {
  final n = _grainCount;
  _grainCount = 0;
  if (n == 0 || alpha <= 0.004 || size <= 0.05) return;
  _grainPaint
    ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0))
    ..strokeWidth = size;
  canvas.drawRawPoints(
    ui.PointMode.points,
    Float32List.sublistView(_grainXY, 0, n * 2),
    _grainPaint,
  );
}

/// The white a grain flares to: its material's glint pushed most of the way
/// to white, so the flash still belongs to the element.
ui.Color vfxFlare(VfxMaterial m) =>
    ui.Color.lerp(m.glint, const ui.Color(0xFFFFFFFF), 0.6)!;

// ── Ribbons in place of strokes ─────────────────────────────────────────
//
// A stroked path reads as a wire. These build one filled ribbon along the
// same line, widest in the middle and tapering to points at both ends, so a
// seam, vein, crest or arc reads as material and costs one fill. Ribbons
// from [vfxLensRibbon] always wind the same way, so many of them can share
// one path (one draw) without cancelling where they overlap.

/// Adds to [into] (or a new path) a ribbon along [spine], [width] at its
/// widest. It tapers to a point over [taper] of its length at the start and
/// [taperEnd] (default [taper]) at the end; 0.5 and 0.5 make a full lens.
/// Normals come from the neighbouring points, so corners bend, not notch.
ui.Path vfxLensRibbon(
  List<ui.Offset> spine,
  double width, {
  double taper = 0.5,
  double? taperEnd,
  ui.Path? into,
}) {
  final path = into ?? ui.Path();
  final n = spine.length;
  if (n < 2 || width <= 0) return path;
  final a = taper.clamp(0.01, 1.0);
  final b = (taperEnd ?? taper).clamp(0.01, 1.0);
  final half = width / 2;
  double h(int i) {
    final f = i / (n - 1);
    final e = min(1.0, min(f / a, (1 - f) / b));
    return half * sin(e * pi / 2);
  }

  ui.Offset normal(int i) {
    final d = spine[min(n - 1, i + 1)] - spine[max(0, i - 1)];
    final len = d.distance;
    return len < 1e-6 ? const ui.Offset(0, 1) : ui.Offset(-d.dy, d.dx) / len;
  }

  for (var i = 0; i < n; i++) {
    final p = spine[i] + normal(i) * h(i);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  for (var i = n - 1; i >= 0; i--) {
    final p = spine[i] - normal(i) * h(i);
    path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

/// Points along a polyline, each segment split into [perSegment] steps, so a
/// lens ribbon through a few corners still swells and tapers smoothly.
List<ui.Offset> vfxPolylineSpine(
  List<ui.Offset> corners, {
  int perSegment = 3,
  List<ui.Offset>? into,
}) {
  final out = into ?? <ui.Offset>[];
  if (corners.isEmpty) return out;
  out.add(corners.first);
  for (var s = 1; s < corners.length; s++) {
    final p0 = corners[s - 1], p1 = corners[s];
    for (var k = 1; k <= perSegment; k++) {
      out.add(ui.Offset.lerp(p0, p1, k / perSegment)!);
    }
  }
  return out;
}

/// [n] + 1 points along the quadratic curve from [a] through control [c] to
/// [b] — the spine of what used to be a stroked `quadraticBezierTo`.
List<ui.Offset> vfxQuadSpine(
  ui.Offset a,
  ui.Offset c,
  ui.Offset b, {
  int n = 8,
  List<ui.Offset>? into,
}) {
  final out = into ?? <ui.Offset>[];
  for (var k = 0; k <= n; k++) {
    final t = k / n, u = 1 - t;
    out.add(
      ui.Offset(
        u * u * a.dx + 2 * u * t * c.dx + t * t * b.dx,
        u * u * a.dy + 2 * u * t * c.dy + t * t * b.dy,
      ),
    );
  }
  return out;
}

/// A lens ribbon along every contour of [path], sampled about every [step]
/// units (at most [maxSamples] per contour), all in one path. For a path that
/// is rebuilt each frame prefer building the spine directly; for one that
/// never changes use [vfxRibbonAlongStaticPath].
ui.Path vfxRibbonAlongPath(
  ui.Path path,
  double width, {
  double taper = 0.5,
  double step = 4,
  int maxSamples = 40,
  ui.Path? into,
}) {
  final out = into ?? ui.Path();
  final pts = <ui.Offset>[];
  for (final metric in path.computeMetrics()) {
    final len = metric.length;
    if (len < 1e-3) continue;
    final count = (len / step).ceil().clamp(2, maxSamples);
    pts.clear();
    for (var k = 0; k <= count; k++) {
      final tangent = metric.getTangentForOffset(len * k / count);
      if (tangent != null) pts.add(tangent.position);
    }
    vfxLensRibbon(pts, width, taper: taper, into: out);
  }
  return out;
}

final Expando<Map<int, ui.Path>> _vfxStaticRibbons = Expando('vfxRibbon');

/// [vfxRibbonAlongPath] for a path that never changes (a top-level `final`):
/// flattened once per width and taper, then reused every frame.
ui.Path vfxRibbonAlongStaticPath(
  ui.Path path,
  double width, {
  double taper = 0.5,
  double step = 1.5,
}) {
  final cache = _vfxStaticRibbons[path] ??= <int, ui.Path>{};
  final key = (width * 1000).round() * 128 + (taper * 100).round();
  return cache[key] ??= vfxRibbonAlongPath(
    path,
    width,
    taper: taper,
    step: step,
    maxSamples: 96,
  );
}

/// A crescent hugging an ellipse ([rx] x [ry]) round [c], centred on
/// [angle] and [sweep] long, [thickness] deep at its middle, tapering to
/// points — what an oval outline becomes: a lit rim, never a hoop.
ui.Path vfxEllipseCrescent(
  ui.Offset c,
  double rx,
  double ry,
  double thickness,
  double angle,
  double sweep, {
  ui.Path? into,
}) {
  const n = 12;
  final path = into ?? ui.Path();
  for (var k = 0; k <= n; k++) {
    final th = angle - sweep / 2 + sweep * k / n;
    final p = c + ui.Offset(cos(th) * rx, sin(th) * ry);
    k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  for (var k = n; k >= 0; k--) {
    final th = angle - sweep / 2 + sweep * k / n;
    final w = thickness * sin(pi * k / n);
    final p =
        c + ui.Offset(cos(th) * max(0.0, rx - w), sin(th) * max(0.0, ry - w));
    path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

/// A hashed value in 0..1 that glides, eased, from one random pose to the
/// next [rate] times a second. The smooth replacement for a value re-rolled
/// on every tick of `(time * 16).floor()`: same restlessness, no snapping.
double vfxGlide(double seed, double time, double rate) {
  final x = time * rate;
  final k = x.floorToDouble();
  final f = x - k;
  final e = f * f * (3 - 2 * f);
  final a = vfxHash(seed + k * 7.13);
  return a + (vfxHash(seed + (k + 1) * 7.13) - a) * e;
}

/// A smooth spine through the corners of a polyline: it starts and ends on
/// the first and last corner and bends past the ones between (a quadratic
/// B-spline through the segment midpoints), [perSegment] points per bend.
/// What a zig-zag becomes when it should read as a writhing arc, not a wire.
List<ui.Offset> vfxCurveSpine(
  List<ui.Offset> corners, {
  int perSegment = 4,
  List<ui.Offset>? into,
}) {
  final out = into ?? <ui.Offset>[];
  final n = corners.length;
  if (n < 3) return vfxPolylineSpine(corners, perSegment: perSegment, into: out);
  var from = corners.first;
  out.add(from);
  for (var i = 1; i < n - 1; i++) {
    final ctrl = corners[i];
    final to = i == n - 2 ? corners.last : (corners[i] + corners[i + 1]) / 2;
    for (var k = 1; k <= perSegment; k++) {
      final t = k / perSegment, u = 1 - t;
      out.add(
        ui.Offset(
          u * u * from.dx + 2 * u * t * ctrl.dx + t * t * to.dx,
          u * u * from.dy + 2 * u * t * ctrl.dy + t * t * to.dy,
        ),
      );
    }
    from = to;
  }
  return out;
}

/// Elements whose material is pale light, so their art takes more of their
/// own hue (30% instead of 22%) to keep from going to pale wires. Lightning
/// joined 2026-10-10: at 22% its beams read pale lavender, not electric.
const Set<String> kVfxGlowingElements = {
  'Air',
  'Steam',
  'Light',
  'Spirit',
  'Lightning',
};

/// A writhing arc from [from] to [to], added as two filled ribbons: a wide
/// faint one to [glow] (fill it with the material's light) and a thin lit one
/// to [core] (fill it with its glint). The kinks glide from one hashed pose
/// to the next [rate] times a second instead of re-rolling a zig-zag, so the
/// arc writhes rather than flickers, and it bows sideways by up to [amp] of
/// its length. Several arcs can share the two paths: two fills for all.
void vfxArcInto(
  ui.Path glow,
  ui.Path core,
  ui.Offset from,
  ui.Offset to,
  double seed,
  double time, {
  double width = 1.8,
  double amp = 0.16,
  int segs = 5,
  double rate = 2.4,
}) {
  final d = to - from;
  final len = d.distance;
  if (len < 2) return;
  final n = ui.Offset(-d.dy, d.dx) / len;
  final corners = <ui.Offset>[from];
  for (var i = 1; i < segs; i++) {
    final t = i / segs;
    final off = (vfxGlide(seed + i * 3.7, time, rate) - 0.5) * 2;
    corners.add(from + d * t + n * (off * amp * len * sin(t * pi)));
  }
  corners.add(to);
  final spine = vfxCurveSpine(corners, perSegment: 3);
  vfxLensRibbon(spine, width * 3.2, taper: 0.32, into: glow);
  vfxLensRibbon(spine, width, taper: 0.32, into: core);
}
