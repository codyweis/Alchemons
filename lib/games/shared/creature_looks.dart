// CREATURE LOOKS — how an Alchemon is drawn in a game's own canvas, shared by
// the modes that paint their creatures themselves (survival, the planet
// dungeons and raids): its genetics colours, and what it wears — its alchemy
// effect (an aura round it) and its costumes. Space draws the same from its
// own copies (cosmic_game_helpers.dart, the genetics filter in its home
// visuals); the widgets and the home field from theirs. One look everywhere.

import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/fx/albino_look.dart';
import 'package:alchemons/widgets/fx/alchemy_effects/alchemy_effect_paint.dart';
import 'package:alchemons/widgets/fx/costume_paint.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// The colour filter [v]'s genetics put on its sprite at [time] seconds (a
/// prismatic creature's hue turns with it): saturation, brightness, hue and
/// lineage tint. An albino's look is in its sheet ([sheetForVisuals]), so it
/// gets none — but a mutated one, whose sheet carries the mutation.
ui.ColorFilter? creatureGeneticsFilter(SpriteVisuals v, double time) =>
    isAlbinoLook(v) ? albinoFilter(v) : _genetics(v, time);

/// The radius an aura is drawn at round a sprite shown [displaySize] across:
/// half of it, held between 10 and 38 as open space holds its own.
double wornAuraRadius(double displaySize) =>
    (displaySize * 0.5).clamp(10.0, 38.0).toDouble();

/// [v]'s worn alchemy effect about the origin at [radius]: the layer behind
/// its sprite, or with [front] the near side over it (only effects that have
/// one). Nothing when it wears none.
void paintWornAura(
  Canvas canvas,
  SpriteVisuals? v,
  double radius,
  double time, {
  bool front = false,
  double opacity = 1,
}) {
  final effect = v?.alchemyEffect;
  if (effect == null) return;
  if (front && !AlchemyEffectPaint.hasFront(effect)) return;
  AlchemyEffectPaint.paint(
    canvas,
    effect,
    Offset.zero,
    radius,
    time,
    element: v!.auraElement,
    opacity: opacity,
    front: front,
  );
}

/// [v]'s worn costumes over [sprite], drawn centred on the origin in the
/// sprite's own transform (its turn and scale), at frame [frame]'s fit.
void paintWornCostumes(
  Canvas canvas,
  SpriteVisuals? v,
  Sprite sprite,
  int frame,
  double time, {
  double opacity = 1,
}) {
  final costumes = v?.costumes;
  if (costumes == null || costumes.isEmpty) return;
  CostumePaint.paintWorn(
    canvas,
    costumes,
    Rect.fromCenter(
      center: Offset.zero,
      width: sprite.srcSize.x,
      height: sprite.srcSize.y,
    ),
    frame,
    time,
    opacity: opacity,
  );
}

// ── the genetics matrices (survival's, as they were) ─────────────────────

ui.ColorFilter _genetics(SpriteVisuals v, double time) {
  var m = _identityMatrix();
  if (v.saturation != 1.0 || v.brightness != 1.0) {
    m = _mulMatrix(_bsSatMatrix(v.brightness, v.saturation), m);
  }
  final rawHue = v.isPrismatic
      ? (v.hueShiftDeg + (time * 45.0) % 360)
      : v.hueShiftDeg;
  final normHue = ((rawHue % 360) + 360) % 360;
  if (normHue != 0) m = _mulMatrix(_hueMatrix(normHue), m);
  if (v.tint != null && !(v.brightness == 1.45 && !v.isPrismatic)) {
    final tr = v.tint!.r, tg = v.tint!.g, tb = v.tint!.b;
    m = _mulMatrix(<double>[
      tr,
      0,
      0,
      0,
      0,
      0,
      tg,
      0,
      0,
      0,
      0,
      0,
      tb,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ], m);
  }
  return ui.ColorFilter.matrix(m);
}

List<double> _identityMatrix() => <double>[
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

List<double> _bsSatMatrix(double brightness, double saturation) {
  final s = saturation;
  return <double>[
    s * brightness,
    0,
    0,
    0,
    0,
    0,
    s * brightness,
    0,
    0,
    0,
    0,
    0,
    s * brightness,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}

List<double> _hueMatrix(double degrees) {
  final rad = degrees * (pi / 180.0);
  final c = cos(rad), s = sin(rad);
  return <double>[
    0.213 + c * 0.787 - s * 0.213,
    0.715 - c * 0.715 - s * 0.715,
    0.072 - c * 0.072 + s * 0.928,
    0,
    0,
    0.213 - c * 0.213 + s * 0.143,
    0.715 + c * 0.285 + s * 0.140,
    0.072 - c * 0.072 - s * 0.283,
    0,
    0,
    0.213 - c * 0.213 - s * 0.787,
    0.715 - c * 0.715 + s * 0.715,
    0.072 + c * 0.928 + s * 0.072,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}

List<double> _mulMatrix(List<double> a, List<double> b) {
  final out = List<double>.filled(20, 0.0);
  for (int row = 0; row < 4; row++) {
    for (int col = 0; col < 4; col++) {
      double sum = 0.0;
      for (int k = 0; k < 4; k++) {
        sum += a[row * 5 + k] * b[k * 5 + col];
      }
      out[row * 5 + col] = sum;
    }
    double tx = a[row * 5 + 4];
    for (int k = 0; k < 4; k++) {
      tx += a[row * 5 + k] * b[k * 5 + 4];
    }
    out[row * 5 + 4] = tx;
  }
  return out;
}
