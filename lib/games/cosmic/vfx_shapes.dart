import 'dart:math';
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

void vfxFillPath(ui.Canvas canvas, ui.Path path, ui.Color color, double alpha) {
  if (alpha <= 0.004) return;
  _vfxFill
    ..shader = null
    ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0));
  canvas.drawPath(path, _vfxFill);
}

/// Light pooled on the ground: soft centre, no edge.
void vfxSpill(
  ui.Canvas canvas,
  ui.Offset c,
  double r,
  ui.Color color,
  double strength,
) {
  if (strength <= 0.004 || r <= 0.5) return;
  _vfxFill
    ..color = const ui.Color(0xFFFFFFFF)
    ..shader = ui.Gradient.radial(
      c,
      r,
      [
        color.withValues(alpha: strength.clamp(0.0, 1.0)),
        color.withValues(alpha: (strength * 0.4).clamp(0.0, 1.0)),
        color.withValues(alpha: 0),
      ],
      const [0.0, 0.45, 1.0],
    );
  canvas.drawCircle(c, r, _vfxFill);
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
  final inner = ((r - band) / outer).clamp(0.0, 1.0);
  _vfxFill
    ..color = const ui.Color(0xFFFFFFFF)
    ..shader = ui.Gradient.radial(
      c,
      outer,
      [
        color.withValues(alpha: 0),
        color.withValues(alpha: 0),
        color.withValues(alpha: strength.clamp(0.0, 1.0)),
        color.withValues(alpha: 0),
      ],
      [0.0, inner, r / outer, 1.0],
    );
  canvas.drawCircle(c, outer, _vfxFill);
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
  _vfxFill
    ..color = const ui.Color(0xFFFFFFFF)
    ..shader = ui.Gradient.linear(
      ui.Offset(0, -half),
      ui.Offset(0, half),
      [
        edge.withValues(alpha: 0),
        centre.withValues(alpha: alpha.clamp(0.0, 1.0)),
        centre.withValues(alpha: alpha.clamp(0.0, 1.0)),
        edge.withValues(alpha: 0),
      ],
      [0.0, 0.5 - plateau / 2, 0.5 + plateau / 2, 1.0],
    );
  canvas.drawPath(path, _vfxFill);
  _vfxFill.shader = null;
}
