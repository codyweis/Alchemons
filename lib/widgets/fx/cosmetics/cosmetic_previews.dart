// lib/widgets/fx/cosmetics/cosmetic_previews.dart
//
// A case style, a trail, a fusion style or a home ambience on its own, as
// a tile: the Athanor's pieces, the creature details' pickers and the
// profile's fusion chooser all draw them from here, so a piece looks the
// same wherever it is chosen. Each is a handful of fills and one or two
// atlas draws (a fusion, a few hundred grains); the case is drawn once and
// replayed.

import 'dart:math' as math;

import 'package:alchemons/models/athanor.dart';
import 'package:alchemons/models/cosmetic_wear.dart';
import 'package:alchemons/widgets/fx/cosmetics/case_style_art.dart';
import 'package:alchemons/widgets/fx/cosmetics/cosmetic_atlas.dart';
import 'package:alchemons/widgets/fx/cosmetics/home_ambience_art.dart';
import 'package:alchemons/widgets/fx/cosmetics/trail_art.dart';
import 'package:alchemons/widgets/fx/fusion_burst.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/rendering.dart';

/// The light a case shows with no specimen in it.
const Color kCasePreviewLight = Color(0xFFE6DCFF);

/// Paints the piece of [kind] known as [grantRef] into [rect] at [t]
/// seconds. False for a kind or id this does not draw.
bool paintCosmeticPreview(
  Canvas c,
  AthanorPieceKind kind,
  String grantRef,
  Rect rect,
  double t,
) {
  switch (kind) {
    case AthanorPieceKind.caseStyle:
      final style = CaseStyle.byId(grantRef);
      if (style == null) return false;
      paintCasePreview(c, style, rect);
    case AthanorPieceKind.trail:
      final style = TrailStyle.byId(grantRef);
      if (style == null) return false;
      paintTrailPreview(c, style, rect, t);
    case AthanorPieceKind.fusionStyle:
      final f = FusionStyle.byId(grantRef);
      if (f == null) return false;
      paintFusionStylePreview(c, f, rect, t);
    case AthanorPieceKind.ambience:
      final a = HomeAmbience.byId(grantRef);
      if (a == null) return false;
      paintAmbiencePreview(c, a, rect, t);
    default:
      return false;
  }
  return true;
}

/// A case standing in [rect] at the Creatures tab's proportions, empty, lit
/// in [light].
void paintCasePreview(
  Canvas c,
  CaseStyle style,
  Rect rect, {
  Color light = kCasePreviewLight,
}) {
  const aspect = 104 / 132;
  final h = math.min(rect.height, rect.width / aspect) * 0.94;
  final w = h * aspect;
  final box = Rect.fromCenter(center: rect.center, width: w, height: h);
  c
    ..save()
    ..clipRect(box)
    ..translate(box.left, box.top);
  paintCaseStyle(c, style, box.size, light);
  c.restore();
}

final CosmeticAtlas _ground = CosmeticAtlas(8 * TrailPrints.entriesPerPrint);
final CosmeticAtlas _light = CosmeticAtlas(8 * TrailPrints.entriesPerPrint);
final Map<TrailStyle, TrailPrints> _prints = {};

/// A few prints of [style] on a strip of dark ground, coming and going in
/// a loop at [t].
void paintTrailPreview(Canvas c, TrailStyle style, Rect rect, double t) {
  final w = rect.width, h = rect.height;
  final groundY = rect.top + h * 0.66;
  // The ground: a dark band, a little lighter at its lip.
  softPool(
    c,
    rect.center.dx,
    groundY + h * 0.08,
    w * 0.62,
    h * 0.2,
    const Color(0xFF2A2F2A),
    0.9,
  );
  final prints = _prints[style] ??= TrailPrints(style, capacity: 8);
  final life = prints.life;
  // Four prints walked right to left, each born a beat after the last,
  // the walk starting over every [loop] seconds.
  final loop = life + 1.2;
  final now = t % loop;
  prints.clear();
  for (var k = 0; k < 4; k++) {
    final born = k * 0.55;
    if (born > now) break;
    final near = k.isEven;
    prints.step(
      rect.left + w * (0.8 - k * 0.2),
      groundY + (near ? 1 : -1) * h * 0.04,
      born,
      size: math.min(w, h) * 0.12,
    );
  }
  prints.paint(_ground, _light, now);
  _ground.draw(c);
  _light.draw(c, blend: BlendMode.plus);
}

final CosmeticAtlas _ambOver = CosmeticAtlas(320);
final CosmeticAtlas _ambLight = CosmeticAtlas(420);

/// [a] over a patch of dark field at its own hour, in [rect].
void paintAmbiencePreview(Canvas c, HomeAmbience a, Rect rect, double t) {
  final w = rect.width, h = rect.height;
  final sky = switch (a) {
    HomeAmbience.peatMist => const Color(0xFF120F1C),
    HomeAmbience.moonlitSnowfall => const Color(0xFF0E1420),
    HomeAmbience.sunMotes => const Color(0xFF1C170E),
    HomeAmbience.emberFall => const Color(0xFF1E0E0C),
  };
  c
    ..save()
    ..clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(w * 0.06)));
  softPool(c, rect.center.dx, rect.top + h * 0.35, w * 0.75, h * 0.6, sky, 1);
  final groundY = rect.top + h * 0.74;
  softPool(
    c,
    rect.center.dx,
    groundY + h * 0.14,
    w * 0.7,
    h * 0.22,
    const Color(0xFF262A24),
    0.9,
  );
  c.translate(rect.left, rect.top);
  final view = AmbienceView(
    left: 0,
    right: w,
    top: 0,
    bottom: h,
    height: h,
    time: 6 + t,
    ground: (x) => h * 0.74 + math.sin(x / w * 5.2) * h * 0.02,
    rowSize: h * 0.42,
  );
  paintHomeAmbience(
    a,
    view,
    1,
    _ambOver,
    _ambLight,
    tile: w,
    grain: 475 / h * 0.55,
  );
  _ambOver.draw(c);
  _ambLight.draw(c, blend: BlendMode.plus);
  c.restore();
}

/// A small fusion, kept per style and size: two balls of grains, one warm
/// and one cool, run through the merge and the cinematic.
final Map<(FusionStyle?, int), (FusionParticleField, FusionBurstField)>
_fusions = {};

const Color _warm = Color(0xFFFF7A3A), _cool = Color(0xFF3FA9F5);

/// Seconds of one loop of [paintFusionStylePreview]: the merge from the
/// stand into the orb, then the cinematic to rest, and a breath.
const double kFusionPreviewLoop = 1.83 + 2.6 + 0.7;

/// Two balls of grains fusing in [style] (null: the plain fusion) in
/// [rect], [t] seconds into a loop of [kFusionPreviewLoop].
void paintFusionStylePreview(
  Canvas c,
  FusionStyle? style,
  Rect rect,
  double t,
) {
  final side = rect.shortestSide;
  final key = (style, side.round());
  final (merge, burst) = _fusions.putIfAbsent(key, () {
    if (_fusions.length > 24) _fusions.remove(_fusions.keys.first);
    final ball = side * 0.13;
    return (
      FusionParticleField(
        specimens: [
          SpecimenGrains.disc(_warm, radius: ball),
          SpecimenGrains.disc(_cool, radius: ball),
        ],
        centres: [
          Offset(-side * 0.27, side * 0.06),
          Offset(side * 0.27, side * 0.06),
        ],
        scales: const [1, 1],
        core: Offset.zero,
        coreRadius: side * 0.17,
        colors: const [_warm, _cool],
        style: style,
        useWornStyle: false,
      ),
      FusionBurstField(
        grains: [
          SpecimenGrains.disc(_warm, radius: ball),
          SpecimenGrains.disc(_cool, radius: ball),
        ],
        radius: side * 0.24,
        maxGrains: 700,
        style: style,
        useWornStyle: false,
      ),
    );
  });
  final lt = t % kFusionPreviewLoop;
  c
    ..save()
    ..clipRect(rect)
    ..translate(rect.center.dx, rect.center.dy);
  if (lt < 1.83) {
    final mt = FusionParticleField.standTime + lt;
    merge.paint(c, mt, back: true, clock: t);
    merge.paint(c, mt, back: false, clock: t);
  } else {
    burst.paint(
      c,
      Offset.zero,
      lt - 1.83,
      colors: const [_warm, _cool],
      clock: t,
    );
  }
  c.restore();
}

/// The moment of [paintFusionStylePreview]'s loop that shows [style] best,
/// for a still: its form at the orb, or the plain fusion's sigil.
double fusionStyleShowcaseTime(FusionStyle? style) => switch (style) {
  null => 1.83 + 2.2,
  FusionStyle.ink => 1.83 + 0.6,
  FusionStyle.frost => 1.83 + 0.5,
  FusionStyle.gilt => 1.4,
  FusionStyle.ember => 1.83 + 0.3,
  FusionStyle.distillation => 1.83 + 0.4,
};
