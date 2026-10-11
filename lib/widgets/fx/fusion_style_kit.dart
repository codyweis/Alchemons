// lib/widgets/fx/fusion_style_kit.dart
//
// What the fusion styles (the Athanor's) are made of: the material each
// turns the pair into, and its light. The fields that play a fusion —
// FusionParticleField (the merge) and FusionBurstField (the cinematic) —
// read this; their motion lives beside them (fusion_style_merge.dart,
// fusion_style_burst.dart).
//
// Every style is grains: lit grains in motion, eased, never a burst. A
// grain is drawn in its own color, or in one of six tones of the style's
// material (darkest first), so a body turns to ink, frost, gold, embers or
// vapour grain by grain.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:alchemons/models/cosmetic_wear.dart';
import 'package:flutter/painting.dart';

/// Tones of material per specimen.
const int kFusionStyleTones = 6;

/// A stable 0–1 for grain [i].
double fsHash(int i, int salt) {
  final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

double fsSmooth(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double fsClamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);

double fsEaseInOut(double x) =>
    x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3) / 2;

/// A specimen's middle color: its palette's middle tone.
Color _middle(List<Color> palette) =>
    palette.isEmpty ? const Color(0xFF9A8F80) : palette[palette.length ~/ 2];

Color _hsl(double h, double s, double l) => HSLColor.fromAHSL(
  1,
  h % 360,
  s.clamp(0.0, 1.0),
  l.clamp(0.0, 1.0),
).toColor();

/// The six tones of [style]'s material for a specimen of [palette].
List<Color> fusionStyleTones(FusionStyle style, List<Color> palette) {
  final mid = HSLColor.fromColor(_middle(palette));
  final h = mid.hue, s = mid.saturation;
  switch (style) {
    case FusionStyle.ink:
      // Ink: near black where it is thick, its own color only where it
      // thins, and light at the edges that catch it.
      final inkS = math.max(0.6, s);
      return [
        _hsl(h + (265 - h) * 0.4, 0.35, 0.03),
        _hsl(h + (265 - h) * 0.2, inkS * 0.8, 0.06),
        _hsl(h, inkS, 0.1),
        _hsl(h, inkS, 0.16),
        _hsl(h, inkS * 0.9, 0.27),
        _hsl(h, inkS * 0.5, 0.48),
      ];
    case FusionStyle.frost:
      // Ice with a breath of its own color in it, shadow to lit: the facet
      // in shadow a deep cold blue, the cap white.
      return [
        _hsl(212, 0.45, 0.3),
        Color.lerp(_hsl(h, 0.35, 0.45), _hsl(208, 0.5, 0.48), 0.6)!,
        _hsl(205, 0.45, 0.64),
        Color.lerp(_hsl(h, 0.25, 0.8), const Color(0xFFCFE6FA), 0.6)!,
        const Color(0xFFE6F3FF),
        const Color(0xFFFFFFFF),
      ];
    case FusionStyle.gilt:
      // Gold leaf: its back an old warm gold, its face bright metal, a
      // breath of its own color in it so the two can be told apart.
      const gold = [
        Color(0xFF6A4410),
        Color(0xFF94621C),
        Color(0xFFB98530),
        Color(0xFFE2B04C),
        Color(0xFFF6D57E),
        Color(0xFFFFF0C0),
      ];
      final tint = _hsl(h, math.max(0.5, s), 0.55);
      return [for (final g in gold) Color.lerp(g, tint, 0.1)!];
    case FusionStyle.ember:
      // Heat, cold to white.
      return const [
        Color(0xFF221814),
        Color(0xFF7A160A),
        Color(0xFFC63A18),
        Color(0xFFF27A28),
        Color(0xFFFFC462),
        Color(0xFFFFF3D4),
      ];
    case FusionStyle.distillation:
      // Vapour (the three palest), and water: clear, with a breath of its
      // own color, a darker rim, and the light it catches.
      final water = Color.lerp(
        _hsl(h, 0.35, 0.55),
        const Color(0xFF9FC4DA),
        0.7,
      )!;
      return [
        Color.lerp(_hsl(h, 0.2, 0.5), const Color(0xFF8FA6B8), 0.6)!,
        Color.lerp(_hsl(h, 0.2, 0.7), const Color(0xFFC8D8E4), 0.6)!,
        const Color(0xFFE6EEF4),
        Color.lerp(water, const Color(0xFF0E1A26), 0.55)!,
        water,
        const Color(0xFFF4FAFF),
      ];
  }
}

/// The light [style] gives off: its glows, the merge's last bloom, the
/// cinematic's heat.
Color fusionStyleLight(FusionStyle style) => switch (style) {
  FusionStyle.ink => const Color(0xFF7A5CC8),
  FusionStyle.frost => const Color(0xFFBFE4FF),
  FusionStyle.gilt => const Color(0xFFFFD27A),
  FusionStyle.ember => const Color(0xFFFF8A3A),
  FusionStyle.distillation => const Color(0xFFBFD8E8),
};

/// How much light [style] throws at its climax, against the plain fusion's
/// white eruption (1). Ink barely glows; embers flare.
double fusionStyleFlare(FusionStyle style) => switch (style) {
  FusionStyle.ink => 0.3,
  FusionStyle.frost => 0.7,
  FusionStyle.gilt => 0.8,
  FusionStyle.ember => 1.0,
  FusionStyle.distillation => 0.5,
};

/// How large [style]'s grains are against a plain grain: gold leaf is a
/// flake, vapour finer.
double fusionStyleGrain(FusionStyle style) => switch (style) {
  FusionStyle.ink => 1.05,
  FusionStyle.frost => 1.0,
  FusionStyle.gilt => 1.35,
  FusionStyle.ember => 1.1,
  FusionStyle.distillation => 0.95,
};

/// A triangular lattice of [pitch]: the nearest point to (x, y). Frost
/// locks grains to it, so a body turns faceted.
Offset fsLattice(double x, double y, double pitch) {
  const r3 = 0.8660254; // √3 / 2
  final row = (y / (pitch * r3)).roundToDouble();
  final shift = (row % 2 == 0) ? 0.0 : pitch / 2;
  final col = ((x - shift) / pitch).roundToDouble();
  return Offset(col * pitch + shift, row * pitch * r3);
}

/// A frost grain's place in the two crystals a frost fusion grows (unit
/// radius, from the middle), and the facet it lies on (0 shadow – 5 lit).
/// Each specimen ([side]) grows its own: an upright prism seen from the
/// side, pointed at both ends, leaning in toward the other.
(double, double, int) fsCrystalSlot(int i, int side) {
  final sgn = side == 0 ? -1.0 : 1.0;
  final scale = side == 0 ? 1.0 : 0.86;
  const hw = 0.38, hh = 1.0;
  var u = 0.0, v = 0.0;
  for (var k = 0; k < 8; k++) {
    u = (fsHash(i, 110 + k) * 2 - 1) * hw;
    v = (fsHash(i, 130 + k) * 2 - 1) * hh;
    if (v.abs() <= hh - 1.2 * u.abs()) break;
  }
  // Lit from the upper left: the cap brightest, then the left face, the
  // front, and the right face in deep shadow.
  final cap = v < -(hh - 1.2 * u.abs()) + 0.24;
  final facet = cap
      ? 5
      : u < -hw / 3
      ? 4
      : (u > hw / 3 ? 0 : 2);
  final lean = -sgn * 0.36;
  final cl = math.cos(lean), sl = math.sin(lean);
  return (
    sgn * 0.3 + (u * cl - v * sl) * scale,
    0.04 + (u * sl + v * cl) * scale,
    facet,
  );
}

/// The water ink moves in: the curl of a few octaves of slow travelling
/// waves, so it is divergence-free (grains crowd and thin along curling
/// filaments, never bunching to a point) and smooth in space and time —
/// a grain's place is a smooth function of the clock, with nothing random
/// from frame to frame. Laid on a lattice once a frame ([prepare]) and
/// sampled bilinearly ([sample]), in coordinates local to its middle.
class InkFlow {
  InkFlow({
    required this.halfWidth,
    required this.halfHeight,
    required this.scale,
    this.nx = 32,
    this.ny = 22,
  }) : _vx = Float32List((nx + 1) * (ny + 1)),
       _vy = Float32List((nx + 1) * (ny + 1)),
       _ca = Float32List((nx + 1) * _waves.length),
       _sa = Float32List((nx + 1) * _waves.length),
       _cb = Float32List((ny + 1) * _waves.length),
       _sb = Float32List((ny + 1) * _waves.length);

  /// How far the lattice reaches either side of its middle.
  final double halfWidth, halfHeight;

  /// The flow's largest curl, in the host's units.
  final double scale;
  final int nx, ny;

  final Float32List _vx, _vy, _ca, _sa, _cb, _sb;
  double _at = double.nan;

  /// The velocity [sample] found: about 1 across the flow's middle.
  double vx = 0, vy = 0;

  // kx, ky (per [scale]), angular speed, phase, amplitude: three octaves,
  // two directions each, the finer ones weaker and quicker.
  static const List<(double, double, double, double, double)> _waves = [
    (0.92, 0.6, 0.31, 0.4, 0.88),
    (-0.52, 1.0, -0.24, 2.1, 0.86),
    (2.05, -0.9, 0.47, 1.3, 0.25),
    (0.74, 2.16, -0.41, 4.4, 0.24),
    (-3.8, 2.3, 0.73, 0.9, 0.07),
    (2.5, 3.9, -0.66, 3.2, 0.065),
  ];

  /// Lays the flow at [t] seconds on the lattice; once per [t].
  void prepare(double t) {
    if (t == _at) return;
    _at = t;
    final w = _waves.length;
    // cos(a + b) from the columns' and the rows' parts.
    for (var c = 0; c <= nx; c++) {
      final x = (-halfWidth + 2 * halfWidth * c / nx) / scale;
      for (var k = 0; k < w; k++) {
        final a = _waves[k].$1 * x;
        _ca[c * w + k] = math.cos(a);
        _sa[c * w + k] = math.sin(a);
      }
    }
    for (var r = 0; r <= ny; r++) {
      final y = (-halfHeight + 2 * halfHeight * r / ny) / scale;
      for (var k = 0; k < w; k++) {
        final (_, ky, om, ph, _) = _waves[k];
        final b = ky * y + om * t + ph;
        _cb[r * w + k] = math.cos(b);
        _sb[r * w + k] = math.sin(b);
      }
    }
    for (var r = 0; r <= ny; r++) {
      for (var c = 0; c <= nx; c++) {
        var vx = 0.0, vy = 0.0;
        for (var k = 0; k < w; k++) {
          final (kx, ky, _, _, amp) = _waves[k];
          final cosArg =
              _ca[c * w + k] * _cb[r * w + k] - _sa[c * w + k] * _sb[r * w + k];
          // The curl of amp·sin(arg): (∂ψ/∂y, −∂ψ/∂x).
          vx += amp * ky * cosArg;
          vy -= amp * kx * cosArg;
        }
        _vx[r * (nx + 1) + c] = vx;
        _vy[r * (nx + 1) + c] = vy;
      }
    }
  }

  /// The velocity at ([x], [y]) from the middle into [vx], [vy]; still
  /// water outside the lattice.
  void sample(double x, double y) {
    final fx = (x + halfWidth) / (2 * halfWidth) * nx;
    final fy = (y + halfHeight) / (2 * halfHeight) * ny;
    if (fx < 0 || fy < 0 || fx >= nx || fy >= ny) {
      vx = 0;
      vy = 0;
      return;
    }
    final c = fx.floor(), r = fy.floor();
    final u = fx - c, v = fy - r;
    final i = r * (nx + 1) + c;
    final j = i + nx + 1;
    final a = (1 - u) * (1 - v), b = u * (1 - v), cc = (1 - u) * v, d = u * v;
    // Stilling toward the lattice's edge, so nothing jumps crossing it.
    final mx = math.min(fx, nx - fx), my = math.min(fy, ny - fy);
    final bx = nx * 0.14, by = ny * 0.14;
    final fade =
        (mx >= bx ? 1.0 : fsSmooth(0, bx, mx)) *
        (my >= by ? 1.0 : fsSmooth(0, by, my));
    vx = (_vx[i] * a + _vx[i + 1] * b + _vx[j] * cc + _vx[j + 1] * d) * fade;
    vy = (_vy[i] * a + _vy[i + 1] * b + _vy[j] * cc + _vy[j + 1] * d) * fade;
  }
}

/// How each style's tones are drawn: for tone [k] (0–5), the haze, the
/// body and the fine pass, each (size against a grain, alpha, how far
/// toward black); a zero alpha skips the pass.
List<(double, double, double)> fusionStyleLayers(
  FusionStyle st,
  int k,
) => switch (st) {
  FusionStyle.ink => const [],
  // Frost: cold light round fine bright crystal.
  FusionStyle.frost => const [(3.0, 0.05, 0), (1.5, 0.26, 0), (0.8, 0.95, 0)],
  // Gold leaf: dense metal, a little warm light off it.
  FusionStyle.gilt => const [(2.6, 0.05, 0), (1.25, 0.16, 0.1), (0.9, 0.95, 0)],
  // Fire: the hot tones glow wide; ash is fine dark soot.
  FusionStyle.ember =>
    k == 0
        ? const [(0, 0, 0), (1.2, 0.18, 0.4), (0.7, 0.45, 0.2)]
        : const [(4.6, 0.09, 0), (2.0, 0.28, 0), (0.9, 0.95, 0)],
  // Steam is soft and wide; water is a body with a bright skin.
  FusionStyle.distillation => switch (k) {
    <= 2 => const [(5.0, 0.05, 0), (2.4, 0.08, 0), (0.7, 0.35, 0)],
    3 => const [(2.0, 0.06, 0), (1.3, 0.3, 0.1), (0.8, 0.45, 0)],
    4 => const [(2.6, 0.06, 0), (1.6, 0.3, 0), (0.8, 0.18, 0)],
    _ => const [(2.4, 0.12, 0), (1.0, 0.5, 0), (0.8, 1.0, 0)],
  },
};

/// A water drop's grain at ([ox], [oy]) in its bead (unit disc): clear
/// glass (4), a darker rim where it bends the light (3), and the catch of
/// light up on the left and again, softer, low on the right (5).
int fsDropTone(double ox, double oy) {
  final lit = ox * -0.55 + oy * -0.835;
  final rr = ox * ox + oy * oy;
  if (lit > 0.62 && rr > 0.3 && rr < 0.8) return 5;
  if (lit < -0.7 && rr > 0.45 && rr < 0.7) return 5;
  return rr > 0.72 ? 3 : 4;
}
