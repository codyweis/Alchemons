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
      // Ink of its own color: deep and saturated, running to violet-black
      // in the darkest, and a lit edge where it catches the light.
      final inkS = math.max(0.6, s);
      return [
        _hsl(h + (265 - h) * 0.4, 0.45, 0.05),
        _hsl(h + (265 - h) * 0.25, inkS, 0.09),
        _hsl(h, inkS, 0.14),
        _hsl(h, inkS, 0.2),
        _hsl(h, inkS * 0.95, 0.29),
        _hsl(h, inkS * 0.8, 0.55),
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
      // Gold leaf, old to bright, warmed toward its own color.
      const gold = [
        Color(0xFF6E4A16),
        Color(0xFF9A6E28),
        Color(0xFFC99A44),
        Color(0xFFE8C468),
        Color(0xFFF8E2A0),
        Color(0xFFFFF6DA),
      ];
      // Enough of its own color that the two strands of the helix can be
      // told apart.
      final tint = _hsl(h, math.max(0.5, s), 0.55);
      return [for (final g in gold) Color.lerp(g, tint, 0.2)!];
    case FusionStyle.ember:
      // Heat, cold to white.
      return const [
        Color(0xFF4A0A08),
        Color(0xFF8E1A0C),
        Color(0xFFD2441A),
        Color(0xFFF4822C),
        Color(0xFFFFC060),
        Color(0xFFFFF0C8),
      ];
    case FusionStyle.distillation:
      // Vapour (the three palest) and glassy drops of its own color.
      return [
        Color.lerp(_hsl(h, 0.2, 0.5), const Color(0xFF8FA6B8), 0.6)!,
        Color.lerp(_hsl(h, 0.2, 0.7), const Color(0xFFC8D8E4), 0.6)!,
        const Color(0xFFE6EEF4),
        _hsl(h, math.max(0.45, s), 0.42),
        _hsl(h, math.max(0.4, s), 0.62),
        Color.lerp(_hsl(h, 0.4, 0.85), const Color(0xFFFFFFFF), 0.5)!,
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
