import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'mane_alchemical_vfx.dart';
import 'horn_vfx.dart';
import 'mystic_world_vfx.dart';
import 'kin_vfx.dart';
import 'pip_vfx.dart';
import 'wing_vfx.dart';
import 'mask_trap_vfx.dart';
import 'let_vfx.dart';
import 'basic_vfx.dart';
import 'ability_grains.dart';
import 'vfx_shapes.dart';
export 'ability_grains.dart';
export 'horn_vfx.dart';
export 'let_vfx.dart';
export 'mystic_world_vfx.dart';
export 'kin_vfx.dart';
export 'pip_vfx.dart';
export 'wing_vfx.dart';
export 'mask_trap_vfx.dart';

/// Kin signature pieces — the Spirit wisp, escorts, wall, cloud, updraft,
/// dust banks, mud tracks. Every game calls this first for companion
/// projectiles; the art lives in kin_vfx.dart.
bool drawKinSpiritWispVisual({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required ui.Color color,
  required double time,
}) => drawKinPieceVisual(
  canvas: canvas,
  projectile: projectile,
  position: position,
  time: time,
);

/// The shared moving Mystic cast. Mystic's large world fixtures remain a
/// survival-only system; the projectile itself still follows the global
/// ability visual contract.
bool drawMysticOrbitalProjectileVisual({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required ui.Color color,
  required double time,
}) {
  if (projectile.visualStyle != ProjectileVisualStyle.mysticOrbital ||
      projectile.stationary) {
    return false;
  }
  _paintMysticComet(canvas, projectile, position, color, time);
  return true;
}

/// A parked Mystic fixture (fog node, mire pool, dark well, turret, pillar).
/// Fixtures are terrain, so the ground-zone painters get the first say; one
/// no painter claims keeps the cast's comet silhouette. [reduceAmbient] drops
/// the halo and tail, as Survival's performance mode does.
bool drawMysticOrbitalFixtureVisual({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required ui.Color color,
  required double time,
  bool reduceAmbient = false,
}) {
  if (projectile.visualStyle != ProjectileVisualStyle.mysticOrbital ||
      !projectile.stationary) {
    return false;
  }
  if (drawMaskElementalProjectileVisual(
    canvas: canvas,
    projectile: projectile,
    position: position,
    color: color,
    time: time,
  )) {
    return true;
  }
  _paintMysticComet(
    canvas,
    projectile,
    position,
    color,
    time,
    reduceAmbient: reduceAmbient,
  );
  return true;
}

/// A Mystic cast in flight (or a parked one no ground painter claims), so it
/// reads as an ultimate rather than a regular dart: a comet of its element's
/// material — light pooled round it, a tapered tail of that light lit across
/// its width, a body and a lit head of the material. No white pip and no
/// trail of flat discs (each a new Paint). Four fills, cached light; shared
/// by survival, open space and dungeons.
void drawMysticComet({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required ui.Color color,
  required double time,
  bool reduceAmbient = false,
}) {
  final m = vfxMaterial(projectile.element);
  final radius = (1.65 * projectile.visualScale).clamp(1.4, 6.1).toDouble();
  final pulse = 0.78 + 0.22 * sin(time * 4.0 + projectile.life);
  final a = projectile.angle;
  if (!reduceAmbient) {
    vfxSpill(canvas, position, radius * 3.0, m.light, 0.26 * pulse);
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(a + pi);
    final h = radius * 1.8;
    vfxCrossLit(
      canvas,
      vfxLens(radius * 7.5, h, radius * 0.6, radius * 4.5),
      h / 2,
      m.light,
      m.light,
      0.42,
      plateau: 0.2,
    );
    canvas.restore();
  }
  vfxFillPath(canvas, vfxDrop(position, radius, a), m.mid, 0.92 * pulse);
  vfxFillPath(
    canvas,
    vfxDrop(position + vfxPolar(a, radius * 0.2), radius * 0.55, a),
    m.glint,
    0.9 * pulse,
  );
  drawProjectileRoleOverlay(
    canvas: canvas,
    projectile: projectile,
    position: position,
    color: color,
    time: time,
  );
}

void _paintMysticComet(
  ui.Canvas canvas,
  Projectile projectile,
  ui.Offset position,
  ui.Color color,
  double time, {
  bool reduceAmbient = false,
}) => drawMysticComet(
  canvas: canvas,
  projectile: projectile,
  position: position,
  color: color,
  time: time,
  reduceAmbient: reduceAmbient,
);

/// A beam in the game's beam list: Wing's elemental beams (wing_vfx.dart),
/// and the element-less pieces other abilities route through the list — a
/// healing beam's core, a charge's swell and micro-arcs, Horn's arcs and
/// chords, the orb turret and reflect.
///
/// The element-less beam is light, not a rod: a lens that tapers to points at
/// both ends, lit across its width and fading to nothing at its edge, with a
/// thinner lit core inside it. Two fills. (It was three stacked round-capped
/// strokes with a near-white core and five loose dots: the hairline-laser
/// look the material pass replaced everywhere else.)
void drawAdvancedAbilityBeam({
  required ui.Canvas canvas,
  required ui.Offset start,
  required ui.Offset end,
  required ui.Color color,
  required double width,
  required double alpha,
  double time = 0,
  String? wingElement,
}) {
  // Wing beams have their own art (wing_vfx.dart), always with their
  // material: the material is what tells the elements apart.
  if (wingElement != null) {
    drawWingBeam(
      canvas: canvas,
      start: start,
      end: end,
      element: wingElement,
      width: width,
      alpha: alpha,
      time: time,
    );
    return;
  }
  final a = alpha.clamp(0.0, 1.0);
  if (a <= 0.004) return;
  final w = max(1.0, width);
  // The core is the colour's own lit tint, not white.
  final core = ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.35)!;
  final d = end - start;
  final len = d.distance;
  if (len < 1.0) {
    // A point — a charge swelling where the wing stands: a soft bead.
    vfxSpill(canvas, start, w * 1.6, color, 0.5 * a);
    vfxSpill(canvas, start, w * 0.6, core, 0.55 * a);
    return;
  }
  canvas.save();
  canvas.translate(start.dx, start.dy);
  canvas.rotate(atan2(d.dy, d.dx));
  final glowH = w * 2.6;
  vfxCrossLit(
    canvas,
    vfxLens(len, glowH, w * 1.6, w * 1.6),
    glowH / 2,
    color,
    color,
    0.42 * a,
    plateau: 0.1,
  );
  vfxFillPath(canvas, vfxLens(len, max(1.0, w * 0.42), w, w), core, 0.8 * a);
  canvas.restore();
}

/// Wing's elemental beam, shared by every game mode (art in wing_vfx.dart).
void drawWingElementBeam({
  required ui.Canvas canvas,
  required ui.Offset start,
  required ui.Offset end,
  required String element,
  required double width,
  required double alpha,
  required double time,
}) => drawWingBeam(
  canvas: canvas,
  start: start,
  end: end,
  element: element,
  width: width,
  alpha: alpha,
  time: time,
);

/// Canonical Wing beam charge telegraph (art in wing_vfx.dart).
void drawAdvancedWingBeamCharge({
  required ui.Canvas canvas,
  required ui.Offset origin,
  required ui.Color color,
  required double progress,
  required double time,
}) => drawWingBeamCharge(
  canvas: canvas,
  origin: origin,
  color: color,
  progress: progress,
  time: time,
);

/// Canonical perimeter for Fire/Poison Wing fields (art in wing_vfx.dart).
void drawAdvancedWingBeamRing({
  required ui.Canvas canvas,
  required ui.Offset center,
  required double radius,
  required double width,
  required ui.Color color,
  required String element,
  required double alpha,
  required double time,
  bool details = true,
}) => drawWingRing(
  canvas: canvas,
  center: center,
  radius: radius,
  width: width,
  element: element,
  alpha: alpha,
  time: time,
  details: details,
);

/// Shared creature shield (art in kin_vfx.dart).
void drawAdvancedCompanionShield({
  required ui.Canvas canvas,
  required double time,
  double scale = 1,
}) => drawShieldWard(canvas: canvas, time: time, scale: scale);

/// Shared Horn dash trail. All modes pass local creature coordinates.
/// The art lives in horn_vfx.dart.
void drawAdvancedChargeTrail({
  required ui.Canvas canvas,
  required ui.Color color,
  required double angle,
  required double sweepRadius,
  required double overshootDistance,
  String? element,
  double time = 0,
  double scale = 1,
}) {
  drawHornChargeWake(
    canvas: canvas,
    color: color,
    angle: angle,
    sweepRadius: sweepRadius,
    overshootDistance: overshootDistance,
    element: element,
    time: time,
    scale: scale,
  );
}

/// Shared Kin laser charge (art in kin_vfx.dart).
void drawAdvancedKinCharge({
  required ui.Canvas canvas,
  required ui.Color color,
  required double progress,
  required double time,
  ui.Offset? aimDirection,
}) => drawKinCharge(
  canvas: canvas,
  color: color,
  progress: progress,
  time: time,
  aimDirection: aimDirection,
);

/// Shared blessing (art in kin_vfx.dart).
void drawAdvancedBlessingAura({
  required ui.Canvas canvas,
  required double time,
  double scale = 1,
  double opacity = 1,
}) => drawBlessing(canvas: canvas, time: time, scale: scale, opacity: opacity);

/// What shows on a kin while its support runs (art in kin_vfx.dart).
void drawAdvancedKinSupportAura({
  required ui.Canvas canvas,
  required String element,
  required ui.Color color,
  required double time,
  double iceChargeProgress = 0,
  bool lightningActive = false,
  bool fireOrbitalActive = false,

  /// What the reborn flame actually burns. The orbit is drawn in proportion to
  /// it so a Beauty-heavy Fire kin looks as wide as it hits.
  double fireOrbitalRadius = 70,
  bool lavaPlateActive = false,
  bool darkCloakActive = false,

  /// Steam boiler stacks as a fraction of the cap (0 when not boiling).
  double steamPressure = 0,
}) => drawKinSupportEffects(
  canvas: canvas,
  element: element,
  time: time,
  iceChargeProgress: iceChargeProgress,
  lightningActive: lightningActive,
  fireOrbitalActive: fireOrbitalActive,
  fireOrbitalRadius: fireOrbitalRadius,
  lavaPlateActive: lavaPlateActive,
  darkCloakActive: darkCloakActive,
  steamPressure: steamPressure,
);

bool drawPipElementalProjectileVisual({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required ui.Color color,
  required double time,
}) {
  final element = projectile.element;
  if (element == null || projectile.visualStyle != ProjectileVisualStyle.dart) {
    return false;
  }
  // A Pip's own auto-attack is a Pip dart too. It carries none of the tempo
  // signals below, so without its family tag it fell to the generic dot.
  final hasPipTempoSignals =
      projectile.basicFamily == 'pip' ||
      projectile.homing ||
      projectile.bounceCount > 0 ||
      projectile.snareRadius > 0 ||
      projectile.interceptCharges > 0;
  if (!hasPipTempoSignals) return false;

  // The art lives in pip_vfx.dart.
  drawPipDart(
    canvas: canvas,
    projectile: projectile,
    position: position,
    time: time,
    special: projectile.abilityFamily == 'pip',
  );
  return true;
}

// Cached, travel-facing geometry. Broad irregular facets stay readable at the
// gameplay camera scale. Paths and material shaders are cached; no blur passes
// or spawned particles.
final _maneIceHull = ui.Path()
  ..moveTo(20, -3)
  ..lineTo(13, -14)
  ..lineTo(3, -19)
  ..lineTo(-6, -15)
  ..lineTo(-17, -18)
  ..lineTo(-14, -7)
  ..lineTo(-23, -2)
  ..lineTo(-16, 5)
  ..lineTo(-18, 15)
  ..lineTo(-7, 12)
  ..lineTo(0, 18)
  ..lineTo(12, 12)
  ..lineTo(16, 4)
  ..close();
final _maneIceUpperFacet = ui.Path()
  ..moveTo(-17, -18)
  ..lineTo(-6, -15)
  ..lineTo(3, -19)
  ..lineTo(13, -14)
  ..lineTo(20, -3)
  ..lineTo(3, -5)
  ..lineTo(-14, -7)
  ..close();
final _maneIceFrontFacet = ui.Path()
  ..moveTo(3, -5)
  ..lineTo(20, -3)
  ..lineTo(16, 4)
  ..lineTo(12, 12)
  ..lineTo(0, 18)
  ..lineTo(1, 4)
  ..close();
final _maneIceInnerFacet = ui.Path()
  ..moveTo(-14, -7)
  ..lineTo(3, -5)
  ..lineTo(1, 4)
  ..lineTo(-7, 12)
  ..lineTo(-16, 5)
  ..lineTo(-9, 1)
  ..close();
final _maneIceEdge = ui.Path()
  ..moveTo(-6, -15)
  ..lineTo(3, -19)
  ..lineTo(13, -14)
  ..lineTo(20, -3)
  ..lineTo(16, 4)
  ..moveTo(13, -14)
  ..lineTo(3, -5)
  ..lineTo(1, 4);
final _maneIceChip = ui.Path()
  ..moveTo(3, 0)
  ..lineTo(-1, -1.7)
  ..lineTo(-3, 0.4)
  ..lineTo(0, 2)
  ..close();
final _maneIceMist = ui.Path()
  ..moveTo(-10, -9)
  ..cubicTo(-24, -15, -37, -10, -54, -3)
  ..cubicTo(-38, -4, -31, 9, -12, 10)
  ..quadraticBezierTo(-19, 0, -10, -9)
  ..close();

// Cool mineral glass with an enclosed silver light, rather than opaque panels.
final _maneIceGlass = ui.Gradient.linear(
  const ui.Offset(-19, 14),
  const ui.Offset(14, -15),
  const [
    ui.Color(0xFF112A39),
    ui.Color(0xFF365B69),
    ui.Color(0xFF739698),
    ui.Color(0xFFB1C8BD),
  ],
  const [0.0, 0.46, 0.82, 1.0],
);
final _maneIceRefraction = ui.Gradient.linear(
  const ui.Offset(-9, -17),
  const ui.Offset(8, 13),
  const [
    ui.Color(0xFFCEDCD0),
    ui.Color(0xFF668B90),
    ui.Color(0xFF193949),
    ui.Color(0xFF8CBBB9),
  ],
  const [0.0, 0.30, 0.65, 1.0],
);
final _maneIceInnerLight = ui.Gradient.radial(
  const ui.Offset(1, -2),
  17,
  const [ui.Color(0x807DDACB), ui.Color(0x20418389), ui.Color(0x00173949)],
  const [0.0, 0.48, 1.0],
);
final _maneIceVeins = ui.Path()
  ..moveTo(-18, -2)
  ..lineTo(-12, -4)
  ..lineTo(-8, -2)
  ..lineTo(-4, -5)
  ..lineTo(1, -6)
  ..lineTo(5, -12)
  ..moveTo(-8, -2)
  ..lineTo(-9, 4)
  ..lineTo(-13, 8)
  ..moveTo(-9, 4)
  ..lineTo(-4, 7)
  ..lineTo(-2, 13)
  ..moveTo(5, -12)
  ..lineTo(9, -13)
  ..moveTo(7, 11)
  ..lineTo(6, 6)
  ..lineTo(10, 2)
  ..lineTo(9, -2)
  ..moveTo(10, 2)
  ..lineTo(14, 3);

void _drawManeIceMass(
  ui.Canvas canvas,
  Projectile projectile,
  ui.Offset position,
  double time,
) {
  final scale = maneArtScale(projectile, floor: 0.75);
  final phase = time + projectile.angle;
  final opacity = (projectile.life / 0.22).clamp(0.0, 1.0);
  final breakup = (1 - opacity) * (1 - opacity);
  final paint = ui.Paint();
  canvas.save();
  canvas.translate(position.dx, position.dy);
  canvas.rotate(projectile.angle);
  canvas.scale(scale);

  // Two quiet ribbons of cold air, tucked behind the solid leading face.
  canvas.drawPath(
    _maneIceMist,
    paint
      ..color = const ui.Color(0xFF79CAED).withValues(alpha: 0.045 * opacity),
  );
  canvas.save();
  canvas.translate(-6, sin(phase * 3) * 2);
  canvas.scale(0.87, 0.67);
  canvas.drawPath(
    _maneIceMist,
    paint
      ..color = const ui.Color(0xFFB5EFFF).withValues(alpha: 0.055 * opacity),
  );
  canvas.restore();

  // Six analytic chips: fixed draw cost, independent of refresh rate and the
  // shared ambient pool. They peel off, tumble, and dissolve in the wake.
  for (var i = 0; i < 6; i++) {
    final t = (phase * 1.25 + i / 6) % 1.0;
    final side = i.isEven ? -1.0 : 1.0;
    canvas.save();
    canvas.translate(-14 - t * 39, side * (7 + t * (5 + i) + breakup * 12));
    canvas.rotate(side * (t * 3 + i));
    canvas.scale(0.35 + (i % 3) * 0.12);
    canvas.drawPath(
      _maneIceChip,
      paint
        ..color = const ui.Color(
          0xFFBDEEFF,
        ).withValues(alpha: sin(t * pi) * 0.40 * opacity),
    );
    canvas.restore();
  }

  // Faces separate during the final 220ms, using the same cached geometry.
  void facet(
    ui.Path path,
    ui.Shader shader,
    double alpha,
    double dx,
    double dy,
  ) {
    canvas.save();
    canvas.translate(dx * breakup, dy * breakup);
    canvas.drawPath(
      path,
      paint
        ..shader = shader
        ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: alpha * opacity),
    );
    canvas.restore();
  }

  facet(_maneIceHull, _maneIceGlass, 0.84, -3, 4);
  facet(_maneIceInnerFacet, _maneIceRefraction, 0.38, -9, 2);
  facet(_maneIceUpperFacet, _maneIceRefraction, 0.56, -3, -10);
  facet(_maneIceFrontFacet, _maneIceRefraction, 0.44, 10, 3);
  facet(_maneIceHull, _maneIceInnerLight, 0.8, 0, 0);
  // Veins and the lit edge as filled slivers in the glass (cached ribbons
  // along the static paths), not hairline strokes; the engraved seal that
  // sat inside it is gone — a glyph, not ice.
  paint.shader = null;
  vfxFillPath(
    canvas,
    vfxRibbonAlongStaticPath(_maneIceVeins, 0.6, taper: 0.4),
    const ui.Color(0xFFB2D6C9),
    0.32 * opacity * (1 - breakup),
  );
  vfxFillPath(
    canvas,
    vfxRibbonAlongStaticPath(_maneIceEdge, 0.9, taper: 0.4),
    const ui.Color(0xFFE0FAFF),
    0.40 * opacity * (1 - breakup),
  );
  // A single moving glint along the leading facet: a small lit sliver.
  final glint = 0.28 + 0.18 * sin(time * 4 + projectile.angle);
  vfxFillPath(canvas, _maneIceGlint, const ui.Color(0xFFE9EDDB), glint * opacity);
  canvas.restore();
}

final _maneIceGlint = vfxLensRibbon(
  vfxPolylineSpine(const [ui.Offset(16, -8), ui.Offset(19, -3)]),
  1.3,
);

// Obsidian suspended over molten material. All paths and shaders are reused.
final _maneLavaBody = ui.Path()
  ..moveTo(22, -1)
  ..cubicTo(23, -10, 10, -17, 1, -14)
  ..cubicTo(-8, -16, -10, -8, -19, -9)
  ..lineTo(-14, -3)
  ..lineTo(-24, 2)
  ..cubicTo(-12, 1, -14, 12, -4, 12)
  ..cubicTo(6, 17, 21, 10, 22, -1)
  ..close();
final _maneLavaSeams = ui.Path()
  ..moveTo(-17, -7)
  ..lineTo(-8, -5)
  ..lineTo(-3, -8)
  ..lineTo(4, -5)
  ..lineTo(9, -10)
  ..lineTo(13, -11)
  ..moveTo(4, -5)
  ..lineTo(6, 1)
  ..lineTo(2, 5)
  ..lineTo(5, 12)
  ..moveTo(6, 1)
  ..lineTo(14, 2)
  ..lineTo(20, -2)
  ..moveTo(2, 5)
  ..lineTo(-6, 4)
  ..lineTo(-12, 7);
final _maneLavaCrust = ui.Gradient.linear(
  const ui.Offset(-12, 10),
  const ui.Offset(12, -12),
  const [
    ui.Color(0xFF100F16),
    ui.Color(0xFF35292C),
    ui.Color(0xFF5D4540),
    ui.Color(0xFF8C6450),
  ],
  const [0.0, 0.50, 0.85, 1.0],
);
final _maneLavaHeat = ui.Gradient.radial(
  const ui.Offset(8, -1),
  25,
  const [
    ui.Color(0xFFFFD393),
    ui.Color(0xFFE9833C),
    ui.Color(0xFF902D18),
    ui.Color(0xFF321A21),
  ],
  const [0.0, 0.3, 0.7, 1.0],
);
// Soft falloff is baked into a reusable shader, avoiding an offscreen blur.
final _maneLavaGlow = ui.Gradient.radial(
  ui.Offset.zero,
  1,
  const [
    ui.Color(0xFFFFD599),
    ui.Color(0xDDFE872D),
    ui.Color(0x558F2513),
    ui.Color(0x008F2513),
  ],
  const [0.0, 0.22, 0.55, 1.0],
);

final _maneLavaWake = ui.Path()
  ..moveTo(-10, -6)
  ..cubicTo(-24, -8, -25, 0, -48, 3)
  ..cubicTo(-28, 7, -21, 2, -11, 7)
  ..close();
final _maneLavaDrop = ui.Path()
  ..moveTo(3, 0)
  ..cubicTo(3, -3, -1, -3, -5, 0)
  ..cubicTo(-1, 2, 3, 3, 3, 0)
  ..close();

void _drawManeLavaMass(
  ui.Canvas canvas,
  Projectile projectile,
  ui.Offset position,
  double time,
) {
  final scale = maneArtScale(projectile, floor: 0.75);
  final opacity = (projectile.life / 0.25).clamp(0.0, 1.0);
  final phase = time + projectile.angle;
  final heat = 0.68 + 0.20 * sin(phase * 2.1);
  final paint = ui.Paint();
  canvas.save();
  canvas.translate(position.dx, position.dy);
  canvas.rotate(projectile.angle);
  canvas.scale(scale);
  void glow(double x, double y, double rx, double ry, double alpha) {
    canvas.save();
    canvas.translate(x, y);
    canvas.scale(rx, ry);
    canvas.drawCircle(
      ui.Offset.zero,
      1,
      paint
        ..style = ui.PaintingStyle.fill
        ..shader = _maneLavaGlow
        ..color = ui.Color.fromRGBO(255, 255, 255, alpha * opacity),
    );
    canvas.restore();
  }

  // Close surface radiance, asymmetric and gently changing with the heat.
  glow(4, 0, 32 + 2 * sin(phase * 2.1), 24, 0.30);
  canvas.save();
  canvas.scale(1.0 + sin(phase * 2.6) * 0.06, 1.0 + sin(phase * 3.2) * 0.16);
  canvas.drawPath(
    _maneLavaWake,
    paint
      ..shader = _maneLavaHeat
      ..color = ui.Color.fromRGBO(255, 255, 255, 0.25 * opacity),
  );
  canvas.restore();
  // Four drawn droplets, with no additions to either game's particle pool.
  for (var i = 0; i < 4; i++) {
    final t = (phase * 0.8 + i * 0.25) % 1.0;
    canvas.save();
    canvas.translate(-15 - t * 28, sin(i * 2.4) * (3 + t * 9));
    canvas.rotate(sin(i * 2.4) * t * 0.3);
    canvas.scale((0.7 - t * 0.4) * (1 + sin(t * pi) * 1.3), 0.72 - t * 0.5);
    canvas.drawPath(
      _maneLavaDrop,
      paint
        ..shader = null
        ..color = ui.Color.lerp(
          const ui.Color(0xFFFFB663),
          const ui.Color(0xFF72352A),
          t,
        )!.withValues(alpha: sin(t * pi) * opacity * 0.8),
    );
    canvas.restore();
  }
  canvas.drawPath(
    _maneLavaBody,
    paint
      ..shader = _maneLavaCrust
      ..color = ui.Color.fromRGBO(255, 255, 255, opacity),
  );
  // Moving subsurface hot spots cross under the dark crust independently.
  // Clipping is local geometry; no saveLayer or framebuffer blur is needed.
  canvas.save();
  canvas.clipPath(_maneLavaBody);
  for (var i = 0; i < 3; i++) {
    final flow = phase * (1.0 + i * 0.19) + i * 2.1;
    glow(
      3 + sin(flow) * 11,
      sin(flow * 1.37 + i) * 7,
      13 + sin(flow * 1.6) * 3,
      9,
      0.48 + sin(flow * 1.8) * 0.14,
    );
  }
  canvas.restore();
  // Wide, faint heat under a narrow molten seam: filled ribbons along the
  // seams (cached), not strokes; no blur or offscreen layer.
  paint
    ..shader = _maneLavaHeat
    ..style = ui.PaintingStyle.fill;
  canvas.drawPath(
    vfxRibbonAlongStaticPath(_maneLavaSeams, 3.2, taper: 0.35),
    paint..color = ui.Color.fromRGBO(255, 255, 255, 0.12 * heat * opacity),
  );
  canvas.drawPath(
    vfxRibbonAlongStaticPath(_maneLavaSeams, 0.8, taper: 0.4),
    paint..color = ui.Color.fromRGBO(255, 255, 255, 0.55 * heat * opacity),
  );
  canvas.save();
  canvas.clipPath(_maneLavaBody);
  final run = (phase * 0.55) % 1.0;
  glow(18 - run * 33, 2 + sin(run * pi * 2) * 4, 7, 4, sin(run * pi) * 0.65);
  canvas.restore();
  paint
    ..style = ui.PaintingStyle.fill
    ..shader = _maneLavaHeat;
  // A small hot meniscus along the leading face sells the liquid beneath:
  // a filled crescent, not a stroked arc.
  canvas.drawPath(
    _maneLavaMeniscus,
    paint..color = ui.Color.fromRGBO(255, 255, 255, 0.55 * heat * opacity),
  );
  canvas.restore();
}

final _maneLavaMeniscus = vfxEllipseCrescent(
  const ui.Offset(14, -0.5),
  6,
  8.5,
  1.1,
  -0.9 + 1.55 / 2,
  1.55,
);

// A consuming void: smoky silver-violet material spirals inward, disappearing
// behind an opaque centre. Cached geometry/shaders, no blur or particle pool.
final _maneDarkHalo = ui.Gradient.radial(
  ui.Offset.zero,
  1,
  const [
    ui.Color(0x003E294F),
    ui.Color(0x004A315D),
    ui.Color(0x88594A70),
    ui.Color(0x00372A49),
  ],
  const [0.0, 0.24, 0.43, 1.0],
);
final _maneDarkWisp = ui.Path()
  ..moveTo(29, -13)
  ..cubicTo(13, -19, -8, -15, -10, -2)
  ..cubicTo(-10, 7, 0, 10, 7, 4)
  ..cubicTo(-3, 6, -7, 1, -3, -5)
  ..cubicTo(2, -13, 17, -15, 29, -13)
  ..close();
final _maneDarkSmoke = ui.Gradient.linear(
  const ui.Offset(27, -14),
  const ui.Offset(-8, 2),
  const [
    ui.Color(0x003F344C),
    ui.Color(0x705D526E),
    ui.Color(0xBBA599AE),
    ui.Color(0x00413551),
  ],
  const [0.0, 0.38, 0.78, 1.0],
);
final _maneDarkCore = ui.Gradient.radial(
  const ui.Offset(-2, 0),
  13,
  const [ui.Color(0xFF020207), ui.Color(0xFF05050C), ui.Color(0x002B213B)],
  const [0.0, 0.70, 1.0],
);

void _drawManeDarkVoid(
  ui.Canvas canvas,
  Projectile projectile,
  ui.Offset position,
  double time,
) {
  final scale = maneArtScale(projectile, floor: 0.75);
  final fade = (projectile.life / 0.3).clamp(0.0, 1.0);
  final phase = time + projectile.angle;
  final paint = ui.Paint();
  // The reach it drags from (its snare), faintly bent light out to the real
  // edge: the halo below is the body, this is the pull, and the flecks are
  // drawn in from its rim. (The art stopped at ~0.45 of the pull at low.)
  final pull = max(projectile.snareRadius, projectile.effectRadius);
  final pullLocal = max(30.0, pull / scale);
  if (pull > 0) {
    vfxSpill(canvas, position, pull, vfxMaterial('Dark').light, 0.1 * fade);
  }
  canvas.save();
  canvas.translate(position.dx, position.dy);
  canvas.rotate(projectile.angle);
  canvas.scale(scale);
  canvas.save();
  canvas.scale(34 + sin(phase * 1.8) * 2, 29);
  canvas.drawCircle(
    ui.Offset.zero,
    1,
    paint
      ..shader = _maneDarkHalo
      ..color = ui.Color.fromRGBO(255, 255, 255, fade),
  );
  canvas.restore();
  // Unequal streams tighten and turn into the centre instead of shedding out.
  for (var i = 0; i < 3; i++) {
    final t = (phase * 0.38 + i / 3) % 1.0;
    canvas.save();
    canvas.rotate(i * 2.4 + t * 2.2);
    canvas.scale(1.4 - t * 0.75, (1.4 - t * 0.75) * 0.82);
    canvas.drawPath(
      _maneDarkWisp,
      paint
        ..shader = _maneDarkSmoke
        ..color = ui.Color.fromRGBO(255, 255, 255, sin(t * pi) * fade),
    );
    canvas.restore();
  }
  // Six dim flecks visibly accelerate inward, then vanish under the core.
  paint.shader = null;
  for (var i = 0; i < 6; i++) {
    final t = (phase * 0.48 + i / 6) % 1.0;
    final radius = pullLocal - (pullLocal - 6) * t * t;
    final a = i * 2.399 + t * 2.5;
    final at = ui.Offset(cos(a), sin(a) * 0.85) * radius;
    canvas.drawCircle(
      at,
      0.35 + 0.3 * (1 - t),
      paint
        ..color = const ui.Color(
          0xFFC2ADC7,
        ).withValues(alpha: sin(t * pi) * 0.55 * fade),
    );
  }
  canvas.save();
  canvas.scale(1.0 + sin(phase * 2.3) * 0.04, 0.90);
  canvas.drawCircle(
    ui.Offset.zero,
    13,
    paint
      ..shader = _maneDarkCore
      ..color = ui.Color.fromRGBO(255, 255, 255, fade),
  );
  canvas.restore();
  canvas.restore();
}

bool drawManeElementalProjectileVisual({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required ui.Color color,
  required double time,
}) {
  if (drawAlchemicalManeVisual(
    canvas: canvas,
    projectile: projectile,
    position: position,
    time: time,
  )) {
    return true;
  }

  final element = projectile.element;
  if (element == null ||
      projectile.visualStyle != ProjectileVisualStyle.slash) {
    return false;
  }

  if (drawAlchemicalManeBasicVisual(
    canvas: canvas,
    projectile: projectile,
    position: position,
    time: time,
  )) {
    return true;
  }

  // A parked Mane piece the alchemical painter does not claim (Ice and Dark
  // have no zone of their own there) lies on its element's ground, sized to
  // the area it affects — the shared material painter, not the old flat
  // concentric discs and legacy zone art.
  if (projectile.stationary && projectile.abilityFamily == 'mane') {
    final radius = max(
      24.0,
      max(projectile.effectRadius, projectile.snareRadius * 0.95),
    ).clamp(24.0, 220.0).toDouble();
    drawVfxElementGround(
      canvas: canvas,
      element: element,
      center: position,
      radius: radius,
      time: time,
      seed: (identityHashCode(projectile) % 97) * 0.37,
    );
    return true;
  }

  if (element == 'Dark' &&
      projectile.abilityFamily == 'mane' &&
      !projectile.stationary) {
    _drawManeDarkVoid(canvas, projectile, position, time);
    return true;
  }

  if (element == 'Lava' &&
      projectile.abilityFamily == 'mane' &&
      !projectile.stationary) {
    _drawManeLavaMass(canvas, projectile, position, time);
    return true;
  }

  // The special is a thrown ice mass; basic attacks keep their small blades.
  if (element == 'Ice' &&
      projectile.abilityFamily == 'mane' &&
      !projectile.stationary) {
    _drawManeIceMass(canvas, projectile, position, time);
    return true;
  }

  // Every Mane slash is claimed above — the alchemical specials, the basics,
  // the Ice / Lava / Dark masses and the parked fixtures. Anything else
  // falls to the generic painter. (The legacy slash renderer that sat here,
  // with its trail wisps and stroked edges, could no longer be reached.)
  return false;
}

bool drawHornElementalProjectileVisual({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required ui.Color color,
  required double time,
}) {
  if (projectile.element == null ||
      projectile.visualStyle != ProjectileVisualStyle.hornImpact) {
    return false;
  }
  // The art lives in horn_vfx.dart.
  if (!drawHornZoneVisual(
    canvas: canvas,
    projectile: projectile,
    position: position,
    time: time,
  )) {
    drawHornMote(
      canvas: canvas,
      projectile: projectile,
      position: position,
      time: time,
    );
  }
  return true;
}

/// Paints a ground-zone style visual sized to the projectile's gameplay
/// radius (snare > effect > taunt): a horn's trail patch, else its element's
/// ground ([drawVfxElementGround]) — Kin's healing garden is a growth bed
/// with buds. A trap that just fired ([Projectile.abilityGrowthTimer]) swells
/// in its own material's light; the white flash discs are gone.
void _drawMaskGroundZone({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required double time,
}) {
  final element = projectile.element ?? '';
  final zoneR = max(
    20.0,
    max(
      projectile.snareRadius,
      max(projectile.effectRadius, projectile.tauntRadius * 0.45),
    ),
  ).clamp(20.0, 260.0).toDouble();
  final zoneSize = zoneR * (1.0 + 0.04 * sin(time * 1.2 + projectile.life));
  if (projectile.abilityFamily == 'horn' &&
      (element == 'Poison' || element == 'Mud' || element == 'Fire')) {
    drawHornTrailPatch(
      canvas: canvas,
      element: element,
      position: position,
      radius: zoneSize,
      time: time,
      fade: (projectile.life / 0.5).clamp(0.0, 1.0),
    );
    return;
  }
  drawVfxElementGround(
    canvas: canvas,
    element: element,
    center: position,
    radius: zoneSize,
    time: time,
    seed: (identityHashCode(projectile) % 97) * 0.37,
    flash: projectile.abilityGrowthTimer.clamp(0.0, 1.0).toDouble(),
    garden: projectile.abilityFamily == 'kin' && element == 'Plant',
  );
}

bool drawMaskElementalProjectileVisual({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required ui.Color color,
  required double time,
  bool reduceAmbient = false,
}) {
  if (drawAlchemicalManeVisual(
    canvas: canvas,
    projectile: projectile,
    position: position,
    time: time,
  )) {
    return true;
  }

  if (projectile.visualStyle != ProjectileVisualStyle.sigil) {
    return false;
  }

  final element = projectile.element;
  if (element == null) return false;

  // Pip's kill pools, clouds, beacon, black hole, vein and mud (pip_vfx.dart).
  if (drawPipGroundVisual(
    canvas: canvas,
    projectile: projectile,
    position: position,
    time: time,
  )) {
    return true;
  }

  if (drawMaskTrapFixture(
    canvas: canvas,
    projectile: projectile,
    position: position,
    time: time,
    reduced: reduceAmbient,
  )) {
    return true;
  }

  // Stationary placements with a tick effect (Pip Fire pools, Pip
  // Dust clouds, Mud trail puffs, Pip Poison line segments, Plant
  // vine zones, etc.) deserve the rich ground-zone art too — without
  // this, they fall back to a generic colored circle.
  final hasGroundZoneSignal =
      projectile.stationary && projectile.tickEffect != AbilityEffectKind.none;
  final hasMaskSignals =
      hasGroundZoneSignal ||
      projectile.decoy ||
      projectile.tauntRadius > 0 ||
      projectile.snareRadius > 0 ||
      projectile.deathExplosionCount > 0;
  if (!hasMaskSignals) return false;

  // Its element's ground, sized to the gameplay radius.
  _drawMaskGroundZone(
    canvas: canvas,
    projectile: projectile,
    position: position,
    time: time,
  );

  return true;
}

/// [reduceAmbient] mirrors the performance visual mode gate: it trims the
/// secondary glow passes and the widest soft plumes, and never the authored
/// element silhouette (see docs/cosmic_ability_contract.md).
bool drawLetElementalProjectileVisual({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required ui.Color color,
  required double time,
  bool reduceAmbient = false,
}) {
  final element = projectile.element;
  if (element == null) return false;

  // The stationary catch-all below claims "any parked thing with a snare, a
  // taunt or a trail", which was written when Let was the only family placing
  // such things. It is not. Mystic parks orbitals carrying snare radii, and
  // Horn parks its impact zones with taunts and snares; both were drawn as
  // Let fallout craters, in survival, open space and dungeons alike — Horn's
  // Fire, Water, Steam, Dust and Dark zones wore flat legacy discs while the
  // burning ground, whirlpool, geyser, cyclone and void horn_vfx.dart paints
  // for them never drew.
  //
  // So the catch-all is Let's own: only a projectile carrying the Let family
  // is claimed by those signals. Every other family's parked pieces go on
  // down the claim order to their own painter (test/horn_zone_claim_test.dart
  // drives the real render path of all three games to hold this).
  final isLetProjectile =
      projectile.visualStyle == ProjectileVisualStyle.meteor ||
      projectile.visualStyle == ProjectileVisualStyle.letShard ||
      (projectile.abilityFamily == 'let' &&
          projectile.stationary &&
          !projectile.decoy &&
          (projectile.trailInterval > 0 ||
              projectile.snareRadius > 0 ||
              projectile.tauntRadius > 0));
  if (!isLetProjectile) return false;

  // Let's own ground — what a meteor leaves in its crater — has its own art.
  if (drawLetGroundZone(
    canvas: canvas,
    projectile: projectile,
    position: position,
    time: time,
    reduceAmbient: reduceAmbient,
  )) {
    return true;
  }

  if (projectile.stationary && !projectile.decoy) {
    _drawLetFallout(
      canvas,
      projectile,
      position,
      color,
      element,
      time,
      reduceAmbient: reduceAmbient,
    );
    return true;
  }

  if (projectile.visualStyle == ProjectileVisualStyle.meteor) {
    _drawSkyfallMeteor(
      canvas,
      projectile,
      position,
      color,
      time,
      reduceAmbient: reduceAmbient,
    );
    return true;
  }

  // A Let piece that is neither ground nor a falling meteor has no art of
  // its own (none is made: Let's shards are its parked vines and zones).
  return false;
}

/// A falling Let meteor. The art lives in let_vfx.dart ([drawLetMeteor]):
/// a material stone sized from the projectile's contact radius, a plume of
/// its light and a grain wake. [color] is unused — the material comes from
/// the element.
void _drawSkyfallMeteor(
  ui.Canvas canvas,
  Projectile projectile,
  ui.Offset position,
  ui.Color color,
  double time, {
  bool reduceAmbient = false,
}) {
  drawLetMeteor(
    canvas: canvas,
    projectile: projectile,
    position: position,
    time: time,
    reduceAmbient: reduceAmbient,
  );
}

void drawProjectileRoleOverlay({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required ui.Color color,
  required double time,
}) {
  final element = projectile.element;
  if (element == null) return;
  // A parked horn piece is drawn whole by horn_vfx.dart — the burning ground,
  // whirlpool, geyser, cyclone or void is the taunt and the snare. Rotating
  // spokes and guard arcs laid over it are the line art the zone replaced.
  if (projectile.stationary &&
      projectile.visualStyle == ProjectileVisualStyle.hornImpact) {
    return;
  }

  // The role reads as light, not as a diagram. A taunting piece pools a
  // faint glow of its own material under itself — the beacon enemies turn
  // toward. The rest was line art laid over the real art and is gone: snare
  // spokes (the frost asterisk), the intercept guard arcs, the turret square
  // and the heal cross. Each piece's own painter shows its cold, its shards
  // and its orbit.
  if (projectile.tauntRadius <= 0) return;
  final vs = projectile.visualScale.clamp(0.75, 2.8).toDouble();
  final tauntR = (projectile.tauntRadius * 0.14).clamp(16.0, 84.0) * vs;
  final pulse = 0.82 + 0.18 * sin(time * 1.6 + projectile.life * 1.3);
  final m = vfxMaterial(element);
  final glowing = kVfxGlowingElements.contains(element);
  vfxSpill(
    canvas,
    position,
    tauntR,
    ui.Color.lerp(m.light, color, glowing ? 0.3 : 0.15)!,
    0.09 * pulse,
  );
}

void _drawLetFallout(
  ui.Canvas canvas,
  Projectile projectile,
  ui.Offset position,
  ui.Color color,
  String element,
  double time, {
  bool reduceAmbient = false,
}) {
  final vs = projectile.visualScale.clamp(0.7, 3.2).toDouble();
  // The gameplay zone radius (effect/snare/taunt), so it covers the area
  // the piece actually affects: its element's ground, in material.
  final radius = max(
    18.0 * vs,
    [
      projectile.effectRadius,
      projectile.snareRadius * 0.95,
      projectile.tauntRadius * 0.55,
    ].fold<double>(0, (a, b) => max(a, b)),
  ).clamp(18.0, 220.0).toDouble();
  drawVfxElementGround(
    canvas: canvas,
    element: element,
    center: position,
    radius: radius,
    time: time,
    seed: (identityHashCode(projectile) % 97) * 0.37,
  );
}

/// Sink for a single ambient zone-VFX particle. Each game adapts this to its
/// own particle pool (survival `_VfxParticle`, cosmic `VfxParticle`, dungeon
/// `_AlchemyParticle`). `arc` requests a lightning-zap render where the pool
/// supports it (otherwise the particle just renders as a normal wisp).
typedef ZoneVfxEmit =
    void Function(
      double x,
      double y,
      double vx,
      double vy,
      double size,
      double life,
      ui.Color color, {
      bool arc,
    });

/// Single source of truth for the per-element ambient wisps that make a
/// stationary zone/aura/trap projectile feel alive — embers off a Fire pool,
/// bubbles off a Poison cloud, rain inside a kin Water cloud, updraft
/// streamers for kin Air, etc. Lifted verbatim from Cosmic Survival (the
/// canonical look) so survival, cosmic space, and dungeons all emit identical
/// particles; each caller supplies [emit] to route into its own pool and is
/// responsible for the per-frame spawn cadence + pool cap.
void emitZoneParticles(Projectile p, Random rng, ZoneVfxEmit emit) {
  // These Mane fields draw their own bounded ambient motion. Emitting the
  // legacy wisps as well doubles the effect and crowds the shared pool.
  if (usesAlchemicalManeVisual(p)) return;
  final element = p.element ?? '';
  final ec = elementColor(element);
  final r = p.effectRadius;
  if (r <= 0) return;

  // Kin-specific directional overrides — ship-attached auras get dedicated
  // visuals so they read as a rain cloud or updraft column instead of a
  // generic puddle.
  if (p.abilityFamily == 'kin' && p.attachedToSlot != -2) {
    if (element == 'Water') {
      // Rain drops: spawn near the top of the cloud and fall down.
      if (rng.nextDouble() > 0.85) return;
      final dx = (rng.nextDouble() - 0.5) * r * 1.4;
      emit(
        p.position.dx + dx,
        p.position.dy - r * 0.6,
        dx * 0.05,
        100 + rng.nextDouble() * 80,
        1.1 + rng.nextDouble() * 0.8,
        0.45 + rng.nextDouble() * 0.25,
        ui.Color.lerp(ec, const ui.Color(0xFFFFFFFF), 0.55)!,
      );
      return;
    }
    if (element == 'Air') {
      // Updraft streamers: spawn at the bottom and shoot up.
      if (rng.nextDouble() > 0.7) return;
      final a = rng.nextDouble() * 2 * pi;
      final rr = r * (0.30 + rng.nextDouble() * 0.60);
      emit(
        p.position.dx + cos(a) * rr,
        p.position.dy + sin(a) * rr * 0.35,
        cos(a) * (6 + rng.nextDouble() * 8),
        -110 - rng.nextDouble() * 70,
        1.0 + rng.nextDouble() * 1.0,
        0.45 + rng.nextDouble() * 0.30,
        ui.Color.lerp(ec, const ui.Color(0xFFFFFFFF), 0.55)!,
      );
      return;
    }
  }

  // Skip-rate per element: most zones spawn a wisp every ~2-3 frames (gentle
  // ambient shimmer). Fire/Lava/Lightning/Steam spawn more often.
  const activeElements = {'Lava', 'Fire', 'Lightning', 'Steam'};
  final spawnChance = activeElements.contains(element) ? 0.55 : 0.30;
  if (rng.nextDouble() > spawnChance) return;

  switch (element) {
    case 'Lava':
    case 'Fire':
      // Ember pop drifting upward + slightly outward.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.20 + rng.nextDouble() * 0.60);
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        cos(a) * (8 + rng.nextDouble() * 12),
        -25 - rng.nextDouble() * 30,
        1.4 + rng.nextDouble() * 1.4,
        0.45 + rng.nextDouble() * 0.35,
        rng.nextBool()
            ? const ui.Color(0xFFFFB060)
            : const ui.Color(0xFFFFD080),
      );
      break;
    case 'Poison':
      // Bubble pops drifting upward, tinted poison.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.20 + rng.nextDouble() * 0.60);
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        cos(a) * (4 + rng.nextDouble() * 8),
        -18 - rng.nextDouble() * 18,
        1.3 + rng.nextDouble() * 1.2,
        0.55 + rng.nextDouble() * 0.35,
        ec,
      );
      break;
    case 'Mud':
      // Sloppy splat dot — drops a bit, settles. Subtle.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.15 + rng.nextDouble() * 0.55);
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        cos(a) * (2 + rng.nextDouble() * 6),
        4 + rng.nextDouble() * 8,
        1.4 + rng.nextDouble() * 1.0,
        0.4 + rng.nextDouble() * 0.3,
        ui.Color.lerp(ec, const ui.Color(0xFF221008), 0.45)!,
      );
      break;
    case 'Water':
      // Droplet flicker — small, drifts outward gently.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.40 + rng.nextDouble() * 0.55);
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        cos(a) * (12 + rng.nextDouble() * 14),
        sin(a) * (12 + rng.nextDouble() * 14),
        1.1 + rng.nextDouble() * 0.9,
        0.35 + rng.nextDouble() * 0.3,
        ui.Color.lerp(ec, const ui.Color(0xFFFFFFFF), 0.45)!,
      );
      break;
    case 'Plant':
      // Spore particle drifting upward + slightly random.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.20 + rng.nextDouble() * 0.55);
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        cos(a) * 6,
        -10 - rng.nextDouble() * 16,
        1.2 + rng.nextDouble() * 1.0,
        0.5 + rng.nextDouble() * 0.4,
        const ui.Color(0xFFB0FFB0),
      );
      break;
    case 'Crystal':
      // Sparkle mote orbiting outward briefly.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.20 + rng.nextDouble() * 0.65);
      final tang = ui.Offset(-sin(a), cos(a));
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        tang.dx * 18 + cos(a) * 6,
        tang.dy * 18 + sin(a) * 6,
        1.1 + rng.nextDouble() * 0.9,
        0.35 + rng.nextDouble() * 0.3,
        const ui.Color(0xFFFFFFFF),
      );
      break;
    case 'Ice':
      // Frost mote drifting outward + falling.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.25 + rng.nextDouble() * 0.55);
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        cos(a) * (6 + rng.nextDouble() * 10),
        sin(a) * (6 + rng.nextDouble() * 10) + 6,
        1.0 + rng.nextDouble() * 1.0,
        0.5 + rng.nextDouble() * 0.35,
        const ui.Color(0xFFFFFFFF),
      );
      break;
    case 'Lightning':
      // Arc flicker — bright zap that pops at a random position.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.15 + rng.nextDouble() * 0.80);
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        cos(a) * (15 + rng.nextDouble() * 25),
        sin(a) * (15 + rng.nextDouble() * 25),
        1.4 + rng.nextDouble() * 1.4,
        0.25 + rng.nextDouble() * 0.25,
        rng.nextBool() ? const ui.Color(0xFFFFFFFF) : ec,
        arc: true,
      );
      break;
    case 'Steam':
      // Steam puff rising upward + slight outward drift.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.15 + rng.nextDouble() * 0.50);
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        cos(a) * (8 + rng.nextDouble() * 8),
        -22 - rng.nextDouble() * 28,
        1.8 + rng.nextDouble() * 1.5,
        0.6 + rng.nextDouble() * 0.35,
        ui.Color.lerp(ec, const ui.Color(0xFFFFFFFF), 0.55)!,
      );
      break;
    case 'Earth':
      // Dust kick — small earthy speck pops up from the ground.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.30 + rng.nextDouble() * 0.50);
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        cos(a) * (4 + rng.nextDouble() * 8),
        -8 - rng.nextDouble() * 12,
        1.2 + rng.nextDouble() * 0.8,
        0.4 + rng.nextDouble() * 0.3,
        ui.Color.lerp(ec, const ui.Color(0xFF4A362B), 0.40)!,
      );
      break;
    case 'Dark':
      // Inward suck fleck — flies INTO the zone from the rim.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.85 + rng.nextDouble() * 0.20);
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        -cos(a) * (35 + rng.nextDouble() * 50),
        -sin(a) * (35 + rng.nextDouble() * 50),
        1.3 + rng.nextDouble() * 1.2,
        0.4 + rng.nextDouble() * 0.3,
        rng.nextBool()
            ? const ui.Color(0xFFB89AFF)
            : const ui.Color(0xFF1A0A2A),
      );
      break;
    case 'Light':
      // Outward shine sparkle from the dome rim.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.55 + rng.nextDouble() * 0.40);
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        cos(a) * (10 + rng.nextDouble() * 14),
        sin(a) * (10 + rng.nextDouble() * 14),
        1.2 + rng.nextDouble() * 0.9,
        0.4 + rng.nextDouble() * 0.3,
        const ui.Color(0xFFFFFFFF),
      );
      break;
    case 'Air':
      // Leaf-wind drift — particle swirls tangentially.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.30 + rng.nextDouble() * 0.60);
      final tang = ui.Offset(-sin(a), cos(a));
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        tang.dx * 25 + cos(a) * 8,
        tang.dy * 25 + sin(a) * 8,
        1.1 + rng.nextDouble() * 0.9,
        0.45 + rng.nextDouble() * 0.30,
        ui.Color.lerp(ec, const ui.Color(0xFFFFFFFF), 0.45)!,
      );
      break;
    case 'Dust':
      // Speck swirl — tangential drift like Air but tinted dust.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.20 + rng.nextDouble() * 0.65);
      final tang = ui.Offset(-sin(a), cos(a));
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        tang.dx * 20 + cos(a) * 6,
        tang.dy * 20 + sin(a) * 6,
        1.0 + rng.nextDouble() * 0.8,
        0.4 + rng.nextDouble() * 0.3,
        ec,
      );
      break;
    case 'Spirit':
      // Ghost wisp drifting upward + sideways.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.20 + rng.nextDouble() * 0.55);
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        cos(a) * 8 + (rng.nextDouble() - 0.5) * 14,
        -10 - rng.nextDouble() * 18,
        1.4 + rng.nextDouble() * 1.2,
        0.55 + rng.nextDouble() * 0.35,
        const ui.Color(0xFFE6E9FF),
      );
      break;
    case 'Blood':
      // Drip pulse — small dark-red drip falls.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.25 + rng.nextDouble() * 0.50);
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        cos(a) * 4,
        4 + rng.nextDouble() * 10,
        1.3 + rng.nextDouble() * 1.0,
        0.45 + rng.nextDouble() * 0.30,
        ec,
      );
      break;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// SHARED LIGHTNING BOLT
//
// Lifted from the Voltara planet dungeon (`_drawJaggedBolt` in
// planet_dungeon_game_lightning.dart), which is the look the storm should
// have everywhere. The dungeon now calls straight into this, so survival,
// cosmic space and the dungeons all draw the identical bolt instead of each
// game growing its own zigzag.
//
// Cost: one Path with at most `_kBoltMaxSteps` lineTo's, stroked up to three
// times with module-cached Paints (glow → halo → white-hot core). No
// MaskFilter, no saveLayer, no per-frame allocation beyond the Path itself.
// ─────────────────────────────────────────────────────────────────────────

/// Voltara's white-blue bolt core.
const ui.Color kLightningBoltCore = ui.Color(0xFFEAF6FF);

/// Voltara's cool halo tone, the color that makes the bolt read as electric.
const ui.Color kLightningBoltGlow = ui.Color(0xFF6BA8FF);

const int _kBoltMaxSteps = 18;

final ui.Paint _boltPaint = ui.Paint()
  ..style = ui.PaintingStyle.stroke
  ..strokeCap = ui.StrokeCap.round
  ..strokeJoin = ui.StrokeJoin.round;

/// Deterministic, allocation-free hash in [-1, 1]. Same trick the dungeon's
/// bolt used (a sin-scramble seeded off position + index) so a bolt between
/// two fixed points animates rather than strobes randomly.
double _boltNoise(double a, double b) {
  final v = sin(a * 12.9898 + b * 78.233) * 43758.5453;
  return (v - v.floorToDouble()) * 2.0 - 1.0;
}

/// Builds the jagged path between [a] and [b]: the straight run displaced
/// along its own normal by a time-driven wobble, exactly as Voltara does it.
ui.Path _boltPath(
  ui.Offset a,
  ui.Offset b,
  double time,
  double jitter,
  double segmentLength,
  double seed,
) {
  final delta = b - a;
  final len = delta.distance;
  final path = ui.Path()..moveTo(a.dx, a.dy);
  if (len < 1) {
    path.lineTo(b.dx, b.dy);
    return path;
  }
  final nrm = ui.Offset(-delta.dy / len, delta.dx / len);
  final steps = (len / segmentLength).clamp(2, _kBoltMaxSteps).floor();
  for (var i = 1; i < steps; i++) {
    final t = i / steps;
    // Taper the wobble toward both anchors so the bolt still connects
    // cleanly to whatever it is arcing between.
    final taper = 1.0 - (t * 2.0 - 1.0).abs() * 0.55;
    final j =
        sin(time * 22 + i * 1.7 + seed) * jitter * taper +
        _boltNoise(seed + i * 3.1, (time * 9).floorToDouble()) *
            jitter *
            0.45 *
            taper;
    final base = a + delta * t;
    path.lineTo(base.dx + nrm.dx * j, base.dy + nrm.dy * j);
  }
  path.lineTo(b.dx, b.dy);
  return path;
}

/// Strokes a bolt path as glow → halo → white-hot core. [glowPasses] is the
/// performance dial: 0 draws the core only (performance visual mode), 1 adds
/// the halo, 2 is the full Voltara stack.
void _strokeBolt(
  ui.Canvas canvas,
  ui.Path path,
  double width,
  ui.Color core,
  ui.Color glow,
  double alpha,
  int glowPasses,
) {
  if (glowPasses >= 2) {
    _boltPaint
      ..strokeWidth = width * 3.0
      ..color = glow.withValues(alpha: 0.14 * alpha);
    canvas.drawPath(path, _boltPaint);
  }
  if (glowPasses >= 1) {
    _boltPaint
      ..strokeWidth = width * 1.75
      ..color = glow.withValues(alpha: 0.34 * alpha);
    canvas.drawPath(path, _boltPaint);
  }
  _boltPaint
    ..strokeWidth = width
    ..color = core.withValues(alpha: 0.95 * alpha);
  canvas.drawPath(path, _boltPaint);
}

/// A crackling lightning segment between [a] and [b] — the single canonical
/// bolt for every game. A jittering zigzag with a layered core+glow ramp and
/// optional forks, so a bolt reads as a real discharge instead of a line.
///
/// [glowPasses]: 2 = full stack, 1 = halo + core, 0 = core only (performance
/// visual mode). The core is never dropped, so lightning identity survives.
void drawLightningBolt(
  ui.Canvas canvas,
  ui.Offset a,
  ui.Offset b, {
  required double time,
  double width = 3.4,
  double jitter = 6.0,
  double segmentLength = 26.0,
  ui.Color core = kLightningBoltCore,
  ui.Color glow = kLightningBoltGlow,
  double alpha = 1.0,
  int branches = 0,
  int glowPasses = 2,
  double seed = 0,
}) {
  final s = seed + a.dx * 0.05;
  final path = _boltPath(a, b, time, jitter, segmentLength, s);
  _strokeBolt(canvas, path, width, core, glow, alpha, glowPasses);
  if (branches <= 0) return;

  // Forks: short, thinner offshoots that leave the trunk part-way along and
  // veer off. Bounded by `branches` so the cost stays fixed.
  final delta = b - a;
  final len = delta.distance;
  if (len < 12) return;
  final dir = delta / len;
  final nrm = ui.Offset(-dir.dy, dir.dx);
  final fork = ui.Path();
  for (var i = 0; i < branches; i++) {
    final t = 0.28 + 0.44 * ((i + 0.5) / branches);
    final root = a + delta * t;
    // Flicker each fork on its own beat so they do not pop in unison.
    final beat = sin(time * 7.0 + i * 2.3 + s);
    if (beat < -0.15) continue;
    final side = i.isEven ? 1.0 : -1.0;
    final reach = len * (0.16 + 0.12 * _boltNoise(s + i, 4.0).abs());
    final tip =
        root +
        dir * reach * 0.55 +
        nrm * side * reach * (0.55 + 0.3 * _boltNoise(s + i, 9.0).abs());
    final mid = ui.Offset(
      (root.dx + tip.dx) * 0.5 + nrm.dx * side * reach * 0.18,
      (root.dy + tip.dy) * 0.5 + nrm.dy * side * reach * 0.18,
    );
    fork
      ..moveTo(root.dx, root.dy)
      ..lineTo(mid.dx, mid.dy)
      ..lineTo(tip.dx, tip.dy);
  }
  _strokeBolt(
    canvas,
    fork,
    width * 0.52,
    core,
    glow,
    alpha * 0.72,
    glowPasses > 0 ? 1 : 0,
  );
}

/// One ambient ability particle (zone wisp, hit spark, burst fleck, …).
/// Mirrors Cosmic Survival's `_VfxParticle` exactly — same fields, same 0.92
/// drag, same `alpha` falloff — so it is the single canonical definition.
class AbilityVfxParticle {
  double x, y, vx, vy, size, life;
  final double maxLife;
  final ui.Color color;

  /// The grain colours this particle is drawn in (ability_grains.dart).
  final AbilityGrainTone tone;
  AbilityVfxParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.life,
    required this.color,
  }) : maxLife = life,
       tone = abilityGrainTone(color);
  double get alpha => (life / maxLife * 2).clamp(0.0, 1.0);
  bool get dead => life <= 0;

  /// Survival's step: drag per second, so a burst reaches the same distance
  /// at 60 and 120 Hz (ability_grains.dart).
  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    final drag = abilityParticleDragFactor(dt);
    vx *= drag;
    vy *= drag;
    life -= dt;
  }
}

/// Shared pool + canonical render for combat-ability particles, so survival,
/// cosmic space, and dungeons draw them identically. Each game owns one
/// instance, calls [update]/[render] in its loop, and routes its ability
/// emitters here (via [add]) instead of into its own flavor-VFX pool. The
/// render is survival's: every particle a lit grain, all of them in one
/// `drawRawAtlas` (ability_grains.dart), no glow/blur.
class AbilityVfxPool {
  final List<AbilityVfxParticle> particles = [];

  /// Drops every other spawn — the reduced-quality thinning, done where the
  /// particle is born rather than by skipping odd indices at draw time
  /// (which made particles blink as the list compacted).
  bool thinSpawns = false;
  int _spawned = 0;

  static final AbilityGrainBatch _batch = AbilityGrainBatch();

  int get length => particles.length;
  bool get isEmpty => particles.isEmpty;

  void add(
    double x,
    double y,
    double vx,
    double vy,
    double size,
    double life,
    ui.Color color,
  ) {
    if (particles.length >= kAbilityParticleCap) return;
    if (thinSpawns && (_spawned++).isOdd) return;
    particles.add(
      AbilityVfxParticle(
        x: x,
        y: y,
        vx: vx,
        vy: vy,
        size: size,
        life: life,
        color: color,
      ),
    );
  }

  void update(double dt) {
    for (final p in particles) {
      p.update(dt);
    }
    particles.removeWhere((p) => p.dead);
  }

  /// Survival's exact particle render: one grain batch, one draw.
  void render(ui.Canvas canvas) {
    final batch = _batch;
    for (final p in particles) {
      if (p.dead) continue;
      batch.addParticle(p.x, p.y, p.size, p.life, p.maxLife, p.tone);
    }
    batch.flush(canvas);
  }
}

/// Mask+Plant "wormy tendrils" overlay — the writhing vines a Plant trap grows
/// as it feeds, reaching toward nearby enemies to bite. Lifted verbatim from
/// Cosmic Survival (the source of truth) so cosmic space + dungeons grow the
/// exact same plant. The caller passes [time] and [targetsInReach]: enemy
/// positions within the vine's reach, nearest-first (empty = idle sway).
void drawMaskPlantWormyTendrils({
  required ui.Canvas canvas,
  required Projectile vine,
  required ui.Color color,
  required double time,
  required List<ui.Offset> targetsInReach,
}) {
  final feeds = vine.effectStacks.clamp(0, 100);
  final feedT = feeds / 100.0;
  // Always at least 1 tendril once the vine exists, +1 per 10 feeds.
  final tendrilCount = (1 + (feeds ~/ 10)).clamp(1, 10);

  final t = time;
  final reach = max(vine.snareRadius, vine.effectRadius);
  const dark = ui.Color(0xFF3D4731);
  const bright = ui.Color(0xFF9AA681);
  // Feed flash: abilityGrowthTimer is bumped to 1.0 on regular feeds and 2.0
  // on tendril-unlock feeds. Pump stroke width + brightness briefly so the
  // cast lands with weight.
  final rawFlash = vine.abilityGrowthTimer;
  final flash = rawFlash.clamp(0.0, 1.0);
  final flashBoost = 1.0 + 0.55 * flash;
  final strokeWidth = ((1.6 + 1.8 * feedT) * flashBoost)
      .clamp(1.4, 6.0)
      .toDouble();
  final amplitude = ((6.0 + 10.0 * feedT) * (1.0 + 0.30 * flash))
      .clamp(4.0, 24.0)
      .toDouble();
  // Idle tendril reach scales with the vine's visual radius so a bigger trunk
  // sprouts longer idle limbs.
  final idleReach = max(
    26.0,
    (vine.snareRadius > 0 ? vine.snareRadius * 0.55 : reach * 0.55),
  );
  const segs = 12;
  // Stable per-tendril seed so each one keeps its identity across frames
  // (idle direction, phase offset, target slot).
  final rootSeed =
      vine.position.dx.floor() * 7919 + vine.position.dy.floor() * 6113;

  // Feed flash: the root's light swelling and settling — a soft pool, larger
  // on a tendril-unlock feed (rawFlash > 1.0). (It was two hard flat discs.)
  if (flash > 0.01) {
    final isUnlock = rawFlash > 1.0;
    final pulseR =
        (vine.snareRadius > 0 ? vine.snareRadius * 0.35 : 28.0) *
        (isUnlock ? 1.6 : 1.0) *
        (1.0 + 0.8 * (1.0 - flash));
    vfxSpill(
      canvas,
      vine.position,
      pulseR,
      bright,
      (isUnlock ? 0.42 : 0.3) * flash,
    );
  }

  // Each tendril is a filled ribbon, thick at the root and tapering to its
  // tip, writhing along its length; all of them share three paths (a faint
  // wide body, the body, its lit spine) and the fangs one grain batch.
  // (They were three stroked polylines each: wires.)
  final halo = ui.Path(), body = ui.Path(), spine = ui.Path();
  var anyAttacking = false;
  final pts = <ui.Offset>[];
  vfxGrainsDiscard();
  for (var ti = 0; ti < tendrilCount; ti++) {
    // Tendril identity: a stable angle around the root for idle pose, a stable
    // phase offset for the wave.
    final h = (rootSeed + ti * 211) & 0xFFFF;
    final idleBaseAngle = (h % 360) * pi / 180;
    final phaseOffset = ti * 1.31 + ((h >> 8) % 100) / 100.0;

    // Pick this tendril's target by stable index — distributes tendrils across
    // multiple enemies when several are in range.
    ui.Offset endPoint;
    bool attacking;
    if (targetsInReach.isNotEmpty) {
      endPoint = targetsInReach[ti % targetsInReach.length];
      attacking = true;
    } else {
      // Idle: end point slowly drifts around the root.
      final sway =
          sin(t * 0.9 + phaseOffset * 2.7) * 0.45 +
          sin(t * 1.7 + phaseOffset) * 0.25;
      final pulse = 0.80 + 0.20 * sin(t * 1.3 + phaseOffset * 1.4);
      final a = idleBaseAngle + sway;
      endPoint = vine.position + ui.Offset(cos(a), sin(a)) * idleReach * pulse;
      attacking = false;
    }
    anyAttacking = anyAttacking || attacking;

    final delta = endPoint - vine.position;
    final dist = delta.distance;
    if (dist < 0.01) continue;
    final perp = ui.Offset(-delta.dy / dist, delta.dx / dist);

    // Wave amplitude: idle is gentler than attacking.
    final ampScale = attacking ? 1.0 : 0.60;

    pts.clear();
    for (var s = 0; s <= segs; s++) {
      final tFrac = s / segs;
      final base = vine.position + delta * tFrac;
      // Envelope: 0 at root + tip, peak in middle (so the root stays anchored
      // and the tip bites cleanly).
      final env = sin(tFrac * pi);
      final wave =
          sin(tFrac * pi * 3.2 + t * (attacking ? 6.5 : 3.2) + phaseOffset) *
              0.65 +
          sin(tFrac * pi * 5.6 + t * (attacking ? 4.2 : 2.0) + phaseOffset) *
              0.35;
      pts.add(base + perp * (wave * amplitude * env * ampScale));
    }
    final w = strokeWidth * (attacking ? 2.2 : 1.8);
    halo.addPath(vfxRibbon(pts, w * 2.2, w * 0.5), ui.Offset.zero);
    body.addPath(vfxRibbon(pts, w, w * 0.18), ui.Offset.zero);
    spine.addPath(vfxRibbon(pts, w * 0.36, w * 0.06), ui.Offset.zero);
    if (attacking) vfxGrain(endPoint.dx, endPoint.dy);
  }
  final outerAlpha = (anyAttacking ? 0.22 : 0.14) + 0.18 * flash;
  final mainAlpha = (anyAttacking ? 0.92 : 0.75) + 0.08 * flash;
  final highlightAlpha = (anyAttacking ? 0.55 : 0.4) + 0.35 * flash;
  vfxFillPath(canvas, halo, dark, outerAlpha);
  vfxFillPath(canvas, body, dark, mainAlpha);
  vfxFillPath(canvas, spine, bright, highlightAlpha);
  // The fangs where they bite, pulsing.
  final bite = 0.55 + 0.45 * sin(t * 9.0 + rootSeed % 7);
  vfxGrainsFlush(canvas, 2.6 + 2.0 * feedT, bright, 0.6 * bite);
}

// ─────────────────────────────────────────────────────────────────────────────
// Generic projectile fallback
//
// What a projectile looks like when no authored family renderer claims it.
// kin (kinOrbital), mystic (mysticOrbital) and wing (standard) projectiles have
// no dedicated renderer, so this IS their artwork rather than a degraded stand-
// in; the meteor/slash/dart/sigil/hornImpact/letShard cases below are reached
// only when the family renderer declined the projectile.
//
// Lifted out of cosmic_survival_game so survival, cosmic space and the preview
// harness share one silhouette instead of survival owning a copy nothing else
// can reach. Paints are module-level and mutated in place, exactly as the
// survival instance fields were — no per-frame Paint allocation added.
// ─────────────────────────────────────────────────────────────────────────────


void drawGenericProjectileVisual({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required ui.Color color,
  required double time,

  /// Performance visual mode. Survival early-returns before reaching this
  /// renderer when it is on, so today it is always false here; the parameter
  /// keeps the original guard honest instead of baking in that assumption.
  bool reduceAmbient = false,
}) {
  switch (projectile.visualStyle) {
    case ProjectileVisualStyle.meteor:
      // An unclaimed meteor (no element) is still a falling stone.
      drawLetMeteor(
        canvas: canvas,
        projectile: projectile,
        position: position,
        time: time,
        reduceAmbient: reduceAmbient,
      );

    // The flat circle pairs that stood in for every unclaimed shot are gone:
    // basic_vfx.dart paints each in its family's material, sized from the
    // radius it hits with.
    case ProjectileVisualStyle.slash:
    case ProjectileVisualStyle.dart:
    case ProjectileVisualStyle.sigil:
    case ProjectileVisualStyle.hornImpact:
      drawMaterialProjectile(
        canvas: canvas,
        projectile: projectile,
        position: position,
        time: time,
      );

    // Kin escorts and Mystic casts are claimed by their own painters in
    // every mode before this; one that reaches here is a mote of its
    // family's material or the Mystic comet (no orbiting dots, no white
    // pip, no sigil glyph).
    case ProjectileVisualStyle.kinOrbital:
      drawMaterialProjectile(
        canvas: canvas,
        projectile: projectile,
        position: position,
        time: time,
      );

    case ProjectileVisualStyle.mysticOrbital:
      drawMysticComet(
        canvas: canvas,
        projectile: projectile,
        position: position,
        color: color,
        time: time,
        reduceAmbient: reduceAmbient,
      );

    case ProjectileVisualStyle.letShard:
      // A Let cluster fragment in flight: a small stone of the element,
      // sized from its own contact radius. (Parked letShards are Let's
      // ground zones and never reach here.)
      drawLetMeteor(
        canvas: canvas,
        projectile: projectile,
        position: position,
        time: time,
        reduceAmbient: true,
      );

    case ProjectileVisualStyle.standard:
      drawMaterialProjectile(
        canvas: canvas,
        projectile: projectile,
        position: position,
        time: time,
      );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Directional silhouette primitives
//
// Both the Let meteors and the Mane cleaves used to be built out of stacked
// translucent concentric circles — a cheap fake radial blur. It is cheap, but a
// stack of discs has no axis and no edge, so every element collapsed into the
// same round blob wearing a different hue, and the body's tumble could not read
// because a near-circle looks identical at every rotation.
//
// These replace the disc stack with forms that have a direction and a real
// outline: a genuinely irregular body that visibly spins, and a plume wake.
// Same cost class as what they replace — plain fills, no MaskFilter, no
// saveLayer, no per-frame Paint allocation.
// ─────────────────────────────────────────────────────────────────────────────

final ui.Paint _shapePaint = ui.Paint();

/// Irregular unit radii for a rock silhouette.
///
/// Two failure modes bracket this table. Too little variance (the old meteor
/// used 0.82..1.08) is a circle, and a circle cannot show its own rotation.
/// Variance that alternates high/low between neighbours makes a star — spiky,
/// symmetrical and far cheesier than the circle was. So: a wide range, but
/// neighbouring radii stay close, which gives lumps and one flattened face
/// instead of points.
const List<double> _kShardRadii = [
  1.00,
  1.10,
  1.06,
  0.86,
  0.72,
  0.76,
  0.92,
  1.08,
  1.02,
];

/// An irregular body that tumbles, stretched along [travelDir] so it reads as
/// travelling rather than hovering.
ui.Path buildTumblingShardPath({
  required ui.Offset centre,
  required double radius,
  required ui.Offset travelDir,
  required double spin,
  double elongation = 1.24,
  double flatten = 0.88,
}) {
  final perp = ui.Offset(-travelDir.dy, travelDir.dx);
  final path = ui.Path();
  final n = _kShardRadii.length;
  for (var i = 0; i < n; i++) {
    final a = spin + i * (pi * 2 / n);
    final r = radius * _kShardRadii[i];
    final along = cos(a) * r * elongation;
    final across = sin(a) * r * flatten;
    final p = centre + travelDir * along + perp * across;
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  path.close();
  return path;
}

/// A wake that flows.
///
/// The wedge this replaces was three nested triangles: straight sides, a blunt
/// cut across the head and a hard point at the tail. Whatever color went into
/// it, the eye read cut paper — and because every Let wore the same wedge at
/// the same angle, the family had one silhouette seventeen times over, and
/// that silhouette was a slipstream, which is Mane's.
///
/// This is a ribbon instead. Its centreline meanders, its width bulges and
/// pinches on the way down, and each layer carries its own phase so the
/// stacked edges never agree on where the boundary is. Nothing in it is
/// straight, which is the whole point: a falling mass drags a turbulent plume,
/// and turbulence is what tells the eye this is smoke and not a shape.
///
/// Cost is the same class as the wedge — three filled paths and three linear
/// gradients, no MaskFilter, no saveLayer, no Paint allocation. The samples
/// are recomputed rather than buffered so nothing allocates per frame either.
void drawPlumeWake({
  required ui.Canvas canvas,
  required ui.Offset head,
  required ui.Offset travelDir,
  required double length,
  required double headWidth,
  required ui.Color color,
  required double time,
  double alpha = 0.34,
  ui.Color? hotColor,
  int layers = 3,
  double seed = 0.0,
  double waveAmplitude = 1.0,
  double waveFrequency = 1.0,
}) {
  if (length <= 0.5 || headWidth <= 0.2) return;
  final perp = ui.Offset(-travelDir.dy, travelDir.dx);
  final hot =
      hotColor ?? ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.6)!;
  // Sampled coarsely and then smoothed: the points are joined through their
  // own midpoints with quadratic segments, so the outline is a continuous
  // curve rather than a polyline. Straight segments between samples were
  // visible as folds and corners on plumes this long, which put the hard
  // edges straight back after all the work of bending the centreline.
  const samples = 12;

  for (var l = 0; l < layers; l++) {
    final layerAlpha = 1.0 - l * 0.34;
    final w0 = headWidth * (1.0 - l * 0.30);
    final len = length * (1.0 - l * 0.14);
    // Each layer drifts on its own phase and swings a little wider than the
    // one inside it, so the composite edge is broken instead of a single
    // agreed-upon line. The time term makes the plume crawl.
    final phase = seed * 1.7 + l * 2.3 - time * (1.6 + l * 0.35);
    // Sway is a fraction of the plume's LENGTH, not its width. Scaling it off
    // headWidth was the bug in the first pass: these wakes run five times
    // longer than they are wide, so a width-derived wander was a couple of
    // pixels over several hundred and the ribbon stayed visually straight.
    // The per-layer spread is small on purpose. Widening it pushes the outer
    // layers clear of the inner one and the wake stops being one plume with a
    // broken edge and becomes two or three separate ribbons crossing.
    final amp = len * 0.085 * waveAmplitude * (1.0 + l * 0.14);
    final tail = head - travelDir * len;

    // Half-width and lateral offset at position [u] along the plume, where 0
    // is the head and 1 the far tail.
    double swayAt(double u) =>
        sin(u * pi * 1.6 * waveFrequency + phase) * amp * u;
    double halfWidthAt(double u) {
      // Narrow where it meets the rock, widest a little way behind it, then
      // falling away to nothing. Peaking at the head made an arrowhead — the
      // plume has to look like it is pouring out from under the body, not
      // like the body is the point of a dart.
      final swell = sin(pi * (u * 0.62 + 0.10).clamp(0.0, 1.0));
      final taper = swell * (1.0 - u * 0.55);
      // Two harmonics that do not divide into each other, so the plume bulges
      // and pinches at irregular intervals instead of scalloping evenly.
      final lump =
          1.0 +
          0.34 * sin(u * pi * 2.4 * waveFrequency + phase * 1.3) +
          0.18 * sin(u * pi * 5.3 * waveFrequency - phase * 0.7);
      return w0 * 0.62 * taper * lump;
    }

    ui.Offset edge(double u, double side) {
      final centre = head - travelDir * (len * u) + perp * swayAt(u);
      return centre + perp * (halfWidthAt(u) * side);
    }

    // Walks one side of the plume as a smooth curve: each sampled point
    // becomes the control handle for a quadratic that lands on the midpoint
    // to the next one, which is the cheap standard way to round a polyline
    // without fitting real splines.
    void traceSide(ui.Path path, double side, bool forward) {
      ui.Offset at(int i) => edge(i / samples, side);
      if (forward) {
        for (var i = 1; i < samples; i++) {
          final c = at(i);
          final n = at(i + 1);
          path.quadraticBezierTo(
            c.dx,
            c.dy,
            (c.dx + n.dx) * 0.5,
            (c.dy + n.dy) * 0.5,
          );
        }
        final last = at(samples);
        path.lineTo(last.dx, last.dy);
      } else {
        for (var i = samples - 1; i > 0; i--) {
          final c = at(i);
          final n = at(i - 1);
          path.quadraticBezierTo(
            c.dx,
            c.dy,
            (c.dx + n.dx) * 0.5,
            (c.dy + n.dy) * 0.5,
          );
        }
        final last = at(0);
        path.lineTo(last.dx, last.dy);
      }
    }

    final path = ui.Path();
    final first = edge(0, 1);
    path.moveTo(first.dx, first.dy);
    traceSide(path, 1, true);
    traceSide(path, -1, false);
    // The reverse trace ended on the far edge of the head; curve from there
    // back to where it started, bulging slightly forward, so the plume closes
    // under the body instead of butting into it with a straight cut.
    final domeCtl = head + travelDir * w0 * 0.12;
    path.quadraticBezierTo(domeCtl.dx, domeCtl.dy, first.dx, first.dy);
    path.close();

    // Alpha ramps to nothing at the tail so the wake ends by dissolving, and
    // the color cools from white-hot at the head to element at the far end.
    _shapePaint
      ..color = const ui.Color(0xFFFFFFFF)
      ..shader = ui.Gradient.linear(
        tail,
        head,
        [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: alpha * layerAlpha * 0.5),
          hot.withValues(alpha: alpha * layerAlpha),
        ],
        const [0.0, 0.6, 1.0],
      );
    canvas.drawPath(path, _shapePaint);
    _shapePaint.shader = null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LET SKYFALL — the telegraph and the landing
//
// A Let meteor arrives from off-screen, so for most of its descent there is
// nothing on screen to look at. The telegraph is what makes the cast readable:
// it marks the committed impact point from the instant of the cast, tightens
// as the rock closes, and is the only thing in any family that does this.
//
// Both painters are plain fills and strokes with at most one gradient each —
// no MaskFilter, no saveLayer, no per-frame Paint allocation. Cost sits in the
// same class as the meteor's own wake, and only one meteor is usually falling.
// ─────────────────────────────────────────────────────────────────────────────

/// How many ambient particles ONE Mane cast's trail may hold at a time.
///
/// The pool the trail draws from tops out around 150 and is shared with every
/// other effect in the game. A Mane cast fans up to sixteen projectiles, and
/// the trail used to emit two or three particles per projectile per frame —
/// so a single wide cast claimed the entire pool within a few frames and held
/// it for the projectiles' whole flight, leaving nothing for hit sparks, kill
/// bursts, zone wisps or meteor craters.
///
/// This is the cap for the cast as a whole, deliberately not per projectile:
/// what the trail costs must not depend on how wide the fan is.
const int kManeTrailParticleBudget = 48;

/// One Let meteor landing, alive just long enough to show the crater open.
///
/// Lives here rather than in any one game so all three hold the identical
/// struct and hand it to the identical painter — the same arrangement the
/// ability particle pool uses, and the reason the three modes stopped drifting
/// apart on ability art in the first place.
class LetSkyfallImpact {
  LetSkyfallImpact({
    required this.position,
    required this.color,
    required this.radius,
    this.element,
    this.minor = false,
    this.duration = kLetCraterDuration,
  }) : age = 0;

  final ui.Offset position;
  final ui.Color color;
  final double radius;

  /// Which element fell — what the crater throws and what it is made of.
  final String? element;

  /// A mastery auto-attack rock rather than the special: bowl, lip and stone
  /// only, so a Let firing every second does not bury the arena in debris.
  final bool minor;
  final double duration;
  double age;

  /// 0 at touchdown, 1 when the crater is gone.
  double get t => (age / duration).clamp(0.0, 1.0);
  bool get dead => age >= duration;
}

/// Advances a game's list of craters and drops the spent ones. Each game owns
/// the list; the stepping and the painting are shared.
void updateLetSkyfallImpacts(List<LetSkyfallImpact> impacts, double dt) {
  if (impacts.isEmpty) return;
  for (final impact in impacts) {
    impact.age += dt;
  }
  impacts.removeWhere((impact) => impact.dead);
}

/// Adds one crater, evicting the oldest if the (deliberately small) cap is hit.
void pushLetSkyfallImpact(
  List<LetSkyfallImpact> impacts,
  LetSkyfallImpact impact, {
  int cap = 6,
}) {
  if (impacts.length >= cap) impacts.removeAt(0);
  impacts.add(impact);
}

/// The ground under an incoming meteor. [progress] runs 0 at the cast to 1 at
/// the landing; [radius] is the blast the landing opens, read off the falling
/// projectile. The art lives in let_vfx.dart ([drawLetTelegraphShadow]): a
/// shadow pool of the element's dark that deepens as the stone closes — no
/// hoop, no ticks. [color] is the fallback when no [element] is passed.
void drawLetSkyfallTelegraph({
  required ui.Canvas canvas,
  required ui.Offset centre,
  required ui.Color color,
  required double radius,
  required double progress,
  required double time,
  String? element,
  bool reduceAmbient = false,
}) {
  drawLetTelegraphShadow(
    canvas: canvas,
    centre: centre,
    // A caller that only has the colour still gets the element's material.
    element:
        element ??
        kElementColors.entries
            .where((e) => e.value.toARGB32() == color.toARGB32())
            .firstOrNull
            ?.key,
    radius: radius,
    progress: progress,
    time: time,
    reduceAmbient: reduceAmbient,
  );
}

/// The landing. [age] runs 0 at touchdown to 1 when the crater is gone.
///
/// The painting lives in let_vfx.dart ([drawLetCrater]): each element throws
/// its own material out of the bowl. [color] is kept for callers that have no
/// element to hand; with neither, the crater is plain stone.
void drawLetSkyfallImpact({
  required ui.Canvas canvas,
  required ui.Offset centre,
  required ui.Color color,
  required double radius,
  required double age,
  String? element,
  bool minor = false,
  bool reduceAmbient = false,
}) {
  drawLetCrater(
    canvas: canvas,
    centre: centre,
    element: element,
    radius: radius,
    t: age,
    minor: minor,
    reduceAmbient: reduceAmbient,
  );
}

/// Builds a closed, smoothly curved ribbon that follows [spine] and tapers
/// from [baseWidth] at the first point to [tipWidth] at the last.
///
/// Strokes cannot taper, and a plant has no constant thickness anywhere on it,
/// so anything organic has to be a filled shape swept along a curve. Corners
/// are rounded by running quadratics through the midpoints of the offset
/// samples rather than joining them with straight segments — a polyline reads
/// as folded paper no matter how many points it has.
ui.Path _tapered(List<ui.Offset> spine, double baseWidth, double tipWidth) {
  final path = ui.Path();
  if (spine.length < 2) return path;

  final left = <ui.Offset>[];
  final right = <ui.Offset>[];
  for (var i = 0; i < spine.length; i++) {
    final prev = spine[i == 0 ? 0 : i - 1];
    final next = spine[i == spine.length - 1 ? i : i + 1];
    var tangent = next - prev;
    final len = tangent.distance;
    if (len < 0.0001) {
      tangent = const ui.Offset(0, -1);
    } else {
      tangent = tangent / len;
    }
    final normal = ui.Offset(-tangent.dy, tangent.dx);
    final f = i / (spine.length - 1);
    final half = (baseWidth + (tipWidth - baseWidth) * f) * 0.5;
    left.add(spine[i] + normal * half);
    right.add(spine[i] - normal * half);
  }

  void trace(List<ui.Offset> side) {
    for (var i = 1; i < side.length - 1; i++) {
      final mid = ui.Offset(
        (side[i].dx + side[i + 1].dx) * 0.5,
        (side[i].dy + side[i + 1].dy) * 0.5,
      );
      path.quadraticBezierTo(side[i].dx, side[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(side.last.dx, side.last.dy);
  }

  path.moveTo(left.first.dx, left.first.dy);
  trace(left);
  final reversed = right.reversed.toList();
  path.lineTo(reversed.first.dx, reversed.first.dy);
  trace(reversed);
  path.close();
  return path;
}

/// Dark Mystic's maw: the hole it tears in the arena.
///
/// A world feature, not a cast — it holds open for as long as its Mystic
/// stands, so it breathes slowly and keeps a constant boundary rather than
/// throwing expanding rings, which read as an effect going off over and over.
void drawMysticMaw({
  required ui.Canvas canvas,
  required ui.Offset centre,
  required double horizonRadius,
  required double open,
  required double spin,
  required double alpha,
  required double time,
}) {
  // Art lives in mystic_world_vfx.dart.
  paintMysticMaw(
    canvas: canvas,
    centre: centre,
    horizonRadius: horizonRadius,
    open: open,
    spin: spin,
    alpha: alpha,
    time: time,
  );
}

/// The curved spine of a grove vine, root first and head last.
///
/// Shared with the game rather than kept inside the painter, because the
/// spitter has to fire its thorns FROM its flower — and the flower is wherever
/// the swaying stem has carried it this frame. Spawning at the root instead
/// meant the shots appeared out of the ground under the plant.
List<ui.Offset> mysticGroveVineSpine({
  required ui.Offset root,
  required double growth,
  required double seed,
  required double time,
}) {
  // Both vines grow UPWARD. Which side of the caster a vine is rooted on is
  // about where it stands, not which way it points: mirroring the growth
  // direction hung the southern one downward with its flower at the bottom,
  // which just reads as a plant printed upside down.
  final height = 207.0 * growth;
  const samples = 16;
  return [
    for (var i = 0; i <= samples; i++)
      () {
        final f = i / samples;
        final wave =
            sin(f * 3.1 + time * 0.9 + seed) * 22.5 * f +
            sin(f * 6.4 + time * 0.55 + seed * 1.7) * 9.0 * f;
        return ui.Offset(root.dx + wave, root.dy - height * f);
      }(),
  ];
}

/// Where a grove vine's head — its whip root, or its flower — is right now.
ui.Offset mysticGroveVineHead({
  required ui.Offset root,
  required double growth,
  required double seed,
  required double time,
}) => mysticGroveVineSpine(
  root: root,
  growth: growth,
  seed: seed,
  time: time,
).last;

/// One of a Plant Mystic's two grove vines.
///
/// Built from tapered ribbons swept along curved spines rather than stroked
/// polylines with circles for leaves: a plant has no straight edges and no
/// constant thickness anywhere on it, and a constant-width stroke reads as
/// folded paper however many points it has.
void drawMysticGroveVine({
  required ui.Canvas canvas,
  required ui.Offset root,
  required bool lashes,
  required double growth,
  required double swing,
  required double aimAngle,
  required double reach,
  required double seed,
  required double alpha,
  required double time,
  required ui.Color plant,
}) {
  plant = ui.Color.lerp(plant, const ui.Color(0xFF384333), 0.78)!;
  final a = alpha;
  final grow = growth;
  final bright = ui.Color.lerp(plant, const ui.Color(0xFFCCDBA5), 0.60)!;

  final spine = mysticGroveVineSpine(
    root: root,
    growth: grow,
    seed: seed,
    time: time,
  );

  canvas.drawPath(
    _tapered(spine, 22.5 * grow, 3.6 * grow),
    ui.Paint()..color = plant.withValues(alpha: 0.32 * a),
  );
  canvas.drawPath(
    _tapered(spine, 14.2 * grow, 2.2 * grow),
    ui.Paint()..color = plant.withValues(alpha: 0.90 * a),
  );
  // A highlight running up one side so the stem reads as round.
  canvas.drawPath(
    _tapered(
      [for (final p in spine) p.translate(-3.0 * grow, 0)],
      5.1 * grow,
      1.2 * grow,
    ),
    ui.Paint()..color = bright.withValues(alpha: 0.30 * a),
  );

  // Root buttresses and broken bark grain keep the large vines organic.
  for (var i = 0; i < 5; i++) {
    final side = i.isEven ? 1.0 : -1.0;
    final rootlet = <ui.Offset>[
      root.translate(0, -14 * grow),
      root + ui.Offset(side * (16 + i * 3), -5) * grow,
      root + ui.Offset(side * (30 + i * 6), 5 + sin(i * 2.1) * 4) * grow,
    ];
    canvas.drawPath(
      _tapered(rootlet, 7 * grow, 0.3),
      ui.Paint()..color = plant.withValues(alpha: 0.85 * a),
    );
  }
  for (var i = 0; i < 3; i++) {
    final grain = <ui.Offset>[
      for (var k = 0; k < spine.length; k++)
        spine[k].translate(
          (i - 1) * 3 * grow + sin(k * 1.7 + seed + i) * grow,
          0,
        ),
    ];
    canvas.drawPath(
      _tapered(grain, 1.1 * grow, 0.1),
      ui.Paint()..color = const ui.Color(0xFF18251E).withValues(alpha: 0.8 * a),
    );
  }

  // Leaves peel off the stem, alternating sides and curling back toward the
  // tip — narrow blades rather than broad ones, to match the stem.
  final samples = spine.length - 1;
  for (var i = 2; i < samples - 1; i += 3) {
    final f = i / samples;
    final at = spine[i];
    final side = i % 6 == 2 ? 1.0 : -1.0;
    final droop = sin(time * 1.1 + i + seed) * 0.18;
    final len = (51.0 - f * 21.0) * grow;
    final leaf = <ui.Offset>[];
    for (var k = 0; k <= 5; k++) {
      final lf = k / 5;
      leaf.add(
        at +
            ui.Offset(
              side * len * lf * (1.0 - 0.25 * lf),
              -len * 0.42 * lf * lf + droop * len * lf,
            ),
      );
    }
    canvas.drawPath(
      _tapered(leaf, (10.5 - f * 3.6) * grow, 0.9),
      ui.Paint()..color = plant.withValues(alpha: 0.58 * a),
    );
  }

  final head = spine.last;

  if (lashes) {
    // The arm. At rest it curls back on itself; through a swing it
    // straightens along the aim and drags a tip across the arc.
    final extend = 0.34 + 0.66 * swing;
    final armLength = reach * 0.92 * extend * grow;
    final dir = ui.Offset(cos(aimAngle), sin(aimAngle));
    final perp = ui.Offset(-dir.dy, dir.dx);
    // Curl amount falls away as the whip lands, so the snap reads.
    final curl = armLength * 0.50 * (1.0 - swing);
    final whip = <ui.Offset>[];
    const ws = 14;
    for (var i = 0; i <= ws; i++) {
      final f = i / ws;
      whip.add(
        head +
            dir * (armLength * f) +
            perp * (curl * sin(f * pi) + sin(f * 4.0 + time * 3.0) * 6.0 * f),
      );
    }
    canvas.drawPath(
      _tapered(whip, 13.5 * grow, 1.5),
      ui.Paint()..color = plant.withValues(alpha: (0.48 + 0.42 * swing) * a),
    );
    canvas.drawPath(
      _tapered(whip, 5.4 * grow, 0.75),
      ui.Paint()..color = bright.withValues(alpha: (0.28 + 0.55 * swing) * a),
    );
    // The air it just swept, trailing the tip: a soft crescent that is
    // deepest where the tip is (it was a 2 px stroked arc).
    if (swing > 0.05) {
      vfxFillPath(
        canvas,
        vfxCrescent(head, armLength, 7.0 * grow, aimAngle, 2.3),
        bright,
        0.16 * swing * a,
      );
    }
  } else {
    // The spitter's flower: curved petals that peel open as it fires and fold
    // back after, around a throat that brightens with the shot.
    final fire = swing;
    const petals = 4;
    for (var i = 0; i < petals; i++) {
      final pa =
          aimAngle +
          (i - (petals - 1) / 2) * 0.40 +
          sin(time * 1.3 + i + seed) * 0.06;
      final len = (39.0 + 13.5 * fire) * grow;
      final bend = 0.55 - 0.40 * fire;
      final petal = <ui.Offset>[];
      for (var k = 0; k <= 5; k++) {
        final f = k / 5;
        final ang = pa + bend * f;
        petal.add(head + ui.Offset(cos(ang), sin(ang)) * (len * f));
      }
      canvas.drawPath(
        _tapered(petal, (12.0 + 3.0 * fire) * grow, 0.9),
        ui.Paint()..color = plant.withValues(alpha: 0.62 * a),
      );
    }
    final throat = (12.0 + 6.0 * fire) * grow;
    final pod = ui.Rect.fromCenter(
      center: head,
      width: throat * 1.25,
      height: throat * 2.2,
    );
    canvas.drawOval(
      pod,
      ui.Paint()..color = const ui.Color(0xFF17251E).withValues(alpha: a),
    );
    canvas.drawOval(
      pod,
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2 * grow
        ..color = plant.withValues(alpha: 0.9 * a),
    );
    canvas.drawOval(
      ui.Rect.fromCenter(
        center: head,
        width: (1.5 + 5 * fire) * grow,
        height: throat * 1.25,
      ),
      ui.Paint()..color = bright.withValues(alpha: (0.45 + 0.5 * fire) * a),
    );
  }
}

/// A Spirit Mystic's revenant: an enemy that died inside the world and came
/// back on our side. White and lit from within, deliberately not the purple of
/// Mask+Spirit's collectible wisps — those are picked up, these fight.
void drawMysticRevenant({
  required ui.Canvas canvas,
  required ui.Offset position,
  required ui.Offset velocity,
  required double radius,
  required double rise,
  required double life,
  required double alpha,
  required double time,
  required double seed,
}) {
  // Art lives in mystic_world_vfx.dart.
  paintMysticRevenant(
    canvas: canvas,
    position: position,
    velocity: velocity,
    radius: radius,
    rise: rise,
    life: life,
    alpha: alpha,
    time: time,
    seed: seed,
  );
}

/// One bolt from a Lightning Mystic's storm: a jagged fall out of the dark
/// onto a body, plus the flash it leaves on the ground.
///
/// Drawn from well above the strike and clipped by the viewport, so it reads
/// as coming out of the sky rather than as a beam between two points on the
/// floor.
void drawMysticLightningBolt({
  required ui.Canvas canvas,
  required ui.Offset strike,
  required double progress,
  required double seed,
  required bool onBoss,
}) {
  // Fast, bright, gone. A bolt that fades linearly reads as a flare.
  final t = (1.0 - progress).clamp(0.0, 1.0);
  final a = t * t;
  if (a <= 0.01) return;

  const fallHeight = 620.0;
  const segments = 11;
  final spine = <ui.Offset>[];
  for (var i = 0; i <= segments; i++) {
    final f = i / segments;
    // The jag narrows toward the ground, so the strike point stays precise
    // while the upper run wanders.
    final wobble =
        sin(f * 9.4 + seed * 5.1) * 34.0 * (1.0 - f) +
        sin(f * 21.0 + seed * 2.3) * 11.0 * (1.0 - f);
    spine.add(
      ui.Offset(strike.dx + wobble, strike.dy - fallHeight * (1.0 - f)),
    );
  }

  // Lightning's material in three filled ribbons through the bends (curved
  // through the corners, swelling and pinching toward the strike): a glow,
  // a lit body, a hot core. (It was three stroked polylines in raw blue
  // with a pure white wire down the middle.)
  final m = vfxMaterial('Lightning');
  final hue = elementColor('Lightning');
  final curve = vfxCurveSpine(spine, perSegment: 2);
  final scale = onBoss ? 1.5 : 1.0;
  vfxFillPath(
    canvas,
    vfxLensRibbon(curve, 13.0 * scale, taper: 0.04, taperEnd: 0.1),
    ui.Color.lerp(m.light, hue, 0.3)!,
    0.24 * a,
  );
  vfxFillPath(
    canvas,
    vfxLensRibbon(curve, 5.0 * scale, taper: 0.04, taperEnd: 0.14),
    ui.Color.lerp(m.light, m.glint, 0.5)!,
    0.75 * a,
  );
  vfxFillPath(
    canvas,
    vfxLensRibbon(curve, 2.2 * scale, taper: 0.04, taperEnd: 0.2),
    vfxFlare(m),
    0.9 * a,
  );

  // Ground flash, spreading as it dies.
  paintMysticBoltImpact(
    canvas: canvas,
    strike: strike,
    t: t,
    a: a,
    onBoss: onBoss,
  );
}

/// An Earth Mystic's quake, as a shock ring running out across the arena with
/// cracks opening behind it.
///
/// Expanding rings are wrong for a thing that stays (they read as an effect
/// re-firing), and exactly right for a thing that happens — this one lives
/// about a second and is gone.
void drawMysticQuake({
  required ui.Canvas canvas,
  required ui.Offset centre,
  required double radius,
  required double progress,
  required ui.Color earth,
}) {
  // Art lives in mystic_world_vfx.dart.
  paintMysticQuake(
    canvas: canvas,
    centre: centre,
    radius: radius,
    progress: progress,
    earth: earth,
  );
}

/// One patch of a Poison Mystic's trail.
///
/// Built from overlapping offset blobs rather than one circle: a spill has an
/// edge that wanders, and a ring of perfect circles down the ship's flight path
/// reads as a row of placed objects.
void drawMysticPoisonPatch({
  required ui.Canvas canvas,
  required ui.Offset centre,
  required double radius,
  required double alpha,
  required double seed,
  required double time,
  required ui.Color poison,
}) {
  // Art lives in mystic_world_vfx.dart.
  paintMysticPoisonPatch(
    canvas: canvas,
    centre: centre,
    radius: radius,
    alpha: alpha,
    seed: seed,
    time: time,
  );
}

/// Ground cover a Mystic world grows on the map — small, per-element, and
/// scaled by [bloom], which carries it up out of the floor and back down.
///
/// Deliberately a different SHAPE per element rather than one sprout in
/// seventeen colors: a world the player cannot identify from the ground at a
/// glance is not really changing the map, it is tinting it.
/// Element colors are tuned for creatures on a light card; several are so
/// dark they vanish as ground cover on a near-black floor. Lift lightness with
/// the hue intact — lerping toward white would wash out the vivid ones.
ui.Color _floraInk(ui.Color c) {
  // Scaled up by its own brightest channel rather than lerped toward white:
  // that keeps the hue and the saturation exactly where they were and only
  // raises the level, so Mud stays brown and Poison stays violet.
  final peak = [c.r, c.g, c.b].reduce((a, b) => a > b ? a : b);
  if (peak >= 0.62 || peak <= 0.001) return c;
  final gain = 0.62 / peak;
  return ui.Color.from(
    alpha: c.a,
    red: (c.r * gain).clamp(0.0, 1.0),
    green: (c.g * gain).clamp(0.0, 1.0),
    blue: (c.b * gain).clamp(0.0, 1.0),
  );
}

void drawMysticFlora({
  required ui.Canvas canvas,
  required ui.Offset at,
  required String element,
  required double size,
  required double bloom,
  required double seed,
  required double time,
  required ui.Color tint,
}) {
  // Fire, Poison, Ice and Spirit are drawn in mystic_world_vfx.dart; the
  // flora worlds are those plus Plant, Mud and Dust (survival's
  // _mysticFloraElements), so only those three reach the switch below.
  if (paintMysticFlora(
    canvas: canvas,
    at: at,
    element: element,
    size: size,
    bloom: bloom,
    seed: seed,
    time: time,
  )) {
    return;
  }
  if (bloom <= 0.02) return;
  final grow = bloom * size;
  // Every element's ground cover was built against Plant's sprout and came out
  // half its size, so on a dark floor only Plant read as anything. The rest are
  // scaled to match it.
  final lift = _floraInk(tint);
  final sway = sin(time * 1.4 + seed) * 0.16;
  final bright = ui.Color.lerp(tint, const ui.Color(0xFFFFFFFF), 0.45)!;

  switch (element) {
    case 'Plant':
      // Old roots, thorns and a sealed seed pod; light lives in the sap.
      const bark = ui.Color(0xFF52634F);
      const sap = ui.Color(0xFFB8CEA0);
      for (var i = 0; i < 4; i++) {
        final side = i.isEven ? 1.0 : -1.0;
        final roots = <ui.Offset>[
          for (var k = 0; k <= 7; k++)
            at +
                ui.Offset(
                      side * (10 + i * 4) * k / 7,
                      sin(k / 7 * 4 + seed + i) * 3 + k / 7 * 4,
                    ) *
                    grow,
        ];
        canvas.drawPath(
          _tapered(roots, 3.4 * grow, 0.2),
          ui.Paint()..color = bark.withValues(alpha: 0.8 * bloom),
        );
      }
      final spine = <ui.Offset>[
        for (var i = 0; i <= 8; i++)
          at + ui.Offset(sin(i * 0.7 + seed) * 3 + sway * i, -i * 3.9) * grow,
      ];
      canvas.drawPath(
        _tapered(spine, 5.0 * grow, 0.7),
        ui.Paint()..color = bark.withValues(alpha: 0.95 * bloom),
      );
      canvas.drawPath(
        _tapered(spine, 0.8 * grow, 0.15),
        ui.Paint()..color = sap.withValues(alpha: 0.48 * bloom),
      );
      for (var i = 2; i < 7; i += 2) {
        final side = i == 4 ? -1.0 : 1.0;
        final thorn = [
          spine[i],
          spine[i] + ui.Offset(side * 9, -3) * grow,
          spine[i] + ui.Offset(side * 13, -11) * grow,
        ];
        canvas.drawPath(
          _tapered(thorn, 2.7 * grow, 0.1),
          ui.Paint()..color = bark.withValues(alpha: bloom),
        );
      }
      final crown = spine.last;
      canvas.drawCircle(
        crown,
        9 * grow,
        ui.Paint()
          ..shader = ui.Gradient.radial(crown, 9 * grow, [
            sap.withValues(alpha: 0.22 * bloom),
            sap.withValues(alpha: 0),
          ]),
      );
      final pod = ui.Path()
        ..moveTo(crown.dx, crown.dy - 7 * grow)
        ..quadraticBezierTo(
          crown.dx + 6 * grow,
          crown.dy + 3 * grow,
          crown.dx,
          crown.dy + 6 * grow,
        )
        ..quadraticBezierTo(
          crown.dx - 6 * grow,
          crown.dy + 3 * grow,
          crown.dx,
          crown.dy - 7 * grow,
        );
      canvas.drawPath(
        pod,
        ui.Paint()..color = const ui.Color(0xFF27382E).withValues(alpha: bloom),
      );
      canvas.drawLine(
        crown + ui.Offset(0, -4 * grow),
        crown + ui.Offset(0, 3 * grow),
        ui.Paint()
          ..strokeWidth = max(0.6, grow)
          ..color = sap.withValues(alpha: 0.88 * bloom),
      );

    case 'Dust':
      // A dust devil: a low spiral of grit turning on the spot. Moving where
      // the other ground cover sits still, which is what a dry, windy floor
      // does and what tells it apart from Mud's wet pits at a glance.
      final turn = time * 1.8 + seed;
      for (var i = 0; i < 9; i++) {
        final f = i / 8.0;
        final ang = turn + f * 4.2;
        final r = (4.0 + 15.0 * f) * grow;
        canvas.drawCircle(
          at + ui.Offset(cos(ang) * r, sin(ang) * r * 0.5 - 7.0 * f * grow),
          (3.2 - 1.8 * f) * grow,
          ui.Paint()..color = lift.withValues(alpha: (0.46 - 0.24 * f) * bloom),
        );
      }

    case 'Mud':
      // A mire pit: a wet, uneven hole in the floor with a skin that bulges
      // and pops. Deliberately sunk INTO the ground where Earth's stone is
      // pushed out of it, so the two brown worlds are not one texture twice.
      final churn = 0.82 + 0.18 * sin(time * 1.6 + seed);
      // Mud's element color is the darkest in the palette and this was
      // darkening it further, so a mire pit on a near-black floor was almost
      // nothing at all. Lifted, and the rim catches light like wet ground.
      for (var i = 0; i < 4; i++) {
        final ang = seed + i * 1.57;
        final off = ui.Offset(cos(ang), sin(ang)) * (9.0 * grow);
        canvas.drawCircle(
          at + off,
          (16.0 - i * 1.6) * grow * churn,
          ui.Paint()..color = lift.withValues(alpha: 0.44 * bloom),
        );
      }
      canvas.drawCircle(
        at,
        11.0 * grow * churn,
        ui.Paint()
          ..color = ui.Color.lerp(
            lift,
            const ui.Color(0xFF2A1608),
            0.45,
          )!.withValues(alpha: 0.85 * bloom),
      );
      canvas.drawCircle(
        at + ui.Offset(-2.5 * grow, -3.0 * grow),
        4.5 * grow * churn,
        ui.Paint()..color = bright.withValues(alpha: 0.28 * bloom),
      );
      // A bubble surfacing and bursting.
      final burst = (time * 0.9 + seed) % 1.0;
      canvas.drawCircle(
        at + ui.Offset(sway * 5, -1.5 * grow),
        (1.2 + 3.4 * burst) * grow * (1.0 - burst),
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = bright.withValues(alpha: 0.50 * bloom * (1.0 - burst)),
      );

  }
}

/// The sky gathering over the spot a Lightning Mystic is about to strike.
///
/// Drawn on the ground rather than in the air: the player needs to read WHERE,
/// and a glow up in the sky tells them nothing they can act on. It tightens as
/// it charges, so the shrinking ring is the countdown.
void drawMysticStormCharge({
  required ui.Canvas canvas,
  required ui.Offset at,
  required double progress,
  required double seed,
  required double time,
}) {
  // Art lives in mystic_world_vfx.dart.
  paintMysticStormCharge(
    canvas: canvas,
    at: at,
    progress: progress,
    seed: seed,
    time: time,
  );
}

/// A Crystal world's shard, waiting to be collected.
void drawMysticCrystalShard({
  required ui.Canvas canvas,
  required ui.Offset at,
  required double alpha,
  required double seed,
  required double time,
  required ui.Color tint,
}) {
  // Art lives in mystic_world_vfx.dart.
  paintMysticCrystalShard(
    canvas: canvas,
    at: at,
    alpha: alpha,
    seed: seed,
    time: time,
  );
}

/// A Light world's star, hanging outside the arena and brightening toward dawn.
///
/// Drawn huge and far off, because the ability IS the wait: the player needs to
/// be able to glance at it from anywhere on the field and know how close it is.
void drawMysticDawnStar({
  required ui.Canvas canvas,
  required ui.Offset at,
  required double charge,
  required double flare,
  required double alpha,
  required double time,
}) {
  // Art lives in mystic_world_vfx.dart.
  paintMysticDawnStar(
    canvas: canvas,
    at: at,
    charge: charge,
    flare: flare,
    alpha: alpha,
    time: time,
  );
}

/// A Steam world venting: the arena exhaling, and the front of that exhale
/// running outward past everything it just threw.
///
/// Deliberately unlike Earth's quake ring, which is a hard crack with dust
/// trailing it. This is soft, billowing and pale — pressure, not fracture —
/// because the two are the only worlds that resolve as an arena-wide ring and
/// they have to be told apart at a glance.
void drawMysticVent({
  required ui.Canvas canvas,
  required ui.Offset centre,
  required double radius,
  required double progress,
  required double time,
}) {
  // Art lives in mystic_world_vfx.dart.
  paintMysticVent(
    canvas: canvas,
    centre: centre,
    radius: radius,
    progress: progress,
    time: time,
  );
}

/// A ribbon that opens from nothing, bellies out, and closes to nothing again.
///
/// `_tapered` runs wide-to-narrow, which is right for a stem and wrong for a
/// split in the ground: a crack has two ends and both of them are hairlines.
ui.Path _splitRibbon(List<ui.Offset> spine, double maxWidth) {
  final path = ui.Path();
  if (spine.length < 2) return path;
  final left = <ui.Offset>[];
  final right = <ui.Offset>[];
  for (var i = 0; i < spine.length; i++) {
    final prev = spine[i == 0 ? 0 : i - 1];
    final next = spine[i == spine.length - 1 ? i : i + 1];
    var tangent = next - prev;
    final len = tangent.distance;
    tangent = len < 0.0001 ? const ui.Offset(0, -1) : tangent / len;
    final normal = ui.Offset(-tangent.dy, tangent.dx);
    final f = i / (spine.length - 1);
    // Widest a little past the middle, so it does not read as symmetrical.
    final half = sin(pow(f, 0.82) * pi) * maxWidth * 0.5;
    left.add(spine[i] + normal * half);
    right.add(spine[i] - normal * half);
  }
  void trace(List<ui.Offset> side) {
    for (var i = 1; i < side.length - 1; i++) {
      final mid = ui.Offset(
        (side[i].dx + side[i + 1].dx) * 0.5,
        (side[i].dy + side[i + 1].dy) * 0.5,
      );
      path.quadraticBezierTo(side[i].dx, side[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(side.last.dx, side.last.dy);
  }

  path.moveTo(left.first.dx, left.first.dy);
  trace(left);
  final reversed = right.reversed.toList();
  path.lineTo(reversed.first.dx, reversed.first.dy);
  trace(reversed);
  path.close();
  return path;
}

/// A Lava world's fissure: a crack in the arena floor with molten light in it.
///
/// Drawn as a dark split with a glowing seam INSIDE it rather than a bright
/// line on top of the floor — a glowing line reads as a laser or a boundary
/// marker, where a crack has to read as depth the player is looking into.
void drawMysticFissure({
  required ui.Canvas canvas,
  required List<ui.Offset> points,
  required double alpha,
  required double flare,
  required double seed,
  required double time,
}) {
  if (alpha <= 0.01 || points.length < 2) return;
  final breath = 0.72 + 0.28 * sin(time * 1.3 + seed);
  // Banked at rest, bright when broken. Eight cracks all glowing at full heat
  // is a lava floor, which is not what this world is: it is a dark arena with
  // seams in it that flare when something heavy crosses one. The rest state is
  // roughly a third as hot as the flare.
  final heat = (0.40 * breath + flare * 1.8).clamp(0.0, 2.2);

  // A split that closes to a hairline at both ends, with the molten seam
  // narrower still inside it. The first version stroked one constant-width
  // line the whole length of the crack, which is why it read as a drawn mark
  // rather than as ground that has come apart.
  canvas.drawPath(
    _splitRibbon(points, 13.0),
    ui.Paint()
      ..color = const ui.Color(0xFF140602).withValues(alpha: 0.88 * alpha),
  );
  canvas.drawPath(
    _splitRibbon(points, 6.0 + 2.0 * flare),
    ui.Paint()
      ..color = const ui.Color(
        0xFFC2400C,
      ).withValues(alpha: (0.34 * heat).clamp(0.0, 0.85) * alpha),
  );
  canvas.drawPath(
    _splitRibbon(points, 2.4 + 1.4 * flare),
    ui.Paint()
      ..color = const ui.Color(
        0xFFFFA24A,
      ).withValues(alpha: (0.42 * heat).clamp(0.0, 0.92) * alpha),
  );

  // A couple of hairline branches off the middle, so it forks the way real
  // ground does instead of running as one clean line.
  final mid = points.length ~/ 2;
  for (var b = 0; b < 2; b++) {
    final at = points[(mid + (b == 0 ? -1 : 1)).clamp(0, points.length - 1)];
    final ang = seed * 3.0 + b * 2.4;
    final branch = <ui.Offset>[
      at,
      at + ui.Offset(cos(ang), sin(ang)) * 16.0,
      at + ui.Offset(cos(ang + 0.4), sin(ang + 0.4)) * 29.0,
    ];
    canvas.drawPath(
      _splitRibbon(branch, 4.6),
      ui.Paint()
        ..color = const ui.Color(0xFF140602).withValues(alpha: 0.70 * alpha),
    );
    canvas.drawPath(
      _splitRibbon(branch, 1.6),
      ui.Paint()
        ..color = const ui.Color(
          0xFFC2400C,
        ).withValues(alpha: (0.26 * heat).clamp(0.0, 0.6) * alpha),
    );
  }

  // Only a flaring crack throws light onto the floor around it. At rest it is
  // a dark seam with an ember in it, which is what lets eight of them sit on
  // the map without taking it over.
  if (flare > 0.02) {
    canvas.drawPath(
      _splitRibbon(points, 40.0),
      ui.Paint()
        ..color = const ui.Color(
          0xFFFF6A1E,
        ).withValues(alpha: 0.10 * flare * alpha),
    );
  }
}

/// A meteor a broken fissure threw up, on its way back down.
///
/// Falls into its impact point from off the top of the frame, with the shadow
/// on the ground tightening as it closes — that shadow is the only warning the
/// player gets, so it is drawn before the rock is anywhere near.
void drawMysticLavaMeteor({
  required ui.Canvas canvas,
  required ui.Offset impact,
  required double progress,
  required double seed,
}) {
  // Art lives in mystic_world_vfx.dart.
  paintMysticLavaMeteor(
    canvas: canvas,
    impact: impact,
    progress: progress,
    seed: seed,
  );
}

/// The mark a lava meteor leaves, cooling from molten to ash.
void drawMysticScorch({
  required ui.Canvas canvas,
  required ui.Offset at,
  required double age,
  required double maxAge,
  required double seed,
}) {
  // Art lives in mystic_world_vfx.dart.
  paintMysticScorch(
    canvas: canvas,
    at: at,
    age: age,
    maxAge: maxAge,
    seed: seed,
  );
}

/// A Water world's maelstrom: the whole surface turning around one eye.
///
/// Spiral arms rather than concentric rings. Rings would only say "a circular
/// thing is here" — arms say which WAY the water is going, which is the thing
/// the player reads the crowd's motion against, and it is what keeps this from
/// looking like Dark's accretion disc in blue.
void drawMysticMaelstrom({
  required ui.Canvas canvas,
  required ui.Offset centre,
  required double radius,
  required double phase,
  required double alpha,
  required double time,
}) {
  // Art lives in mystic_world_vfx.dart.
  paintMysticMaelstrom(
    canvas: canvas,
    centre: centre,
    radius: radius,
    phase: phase,
    alpha: alpha,
    time: time,
  );
}

/// An Air world's tornado, seen from above.
///
/// A funnel is a vertical thing and this arena is not, so it is drawn as a set
/// of OFFSET rings — each one further from the base than the last, leaning the
/// way the tornado is travelling. That lean is what sells height on a top-down
/// field, and it is also what keeps this from reading as another whirlpool:
/// the maelstrom is flat and concentric, this one is stacked and skewed.
void drawMysticTornado({
  required ui.Canvas canvas,
  required ui.Offset at,
  required double radius,
  required double phase,
  required double travelAngle,
  required double alpha,
  required double time,
}) {
  // Art lives in mystic_world_vfx.dart.
  paintMysticTornado(
    canvas: canvas,
    at: at,
    radius: radius,
    phase: phase,
    travelAngle: travelAngle,
    alpha: alpha,
    time: time,
  );
}
