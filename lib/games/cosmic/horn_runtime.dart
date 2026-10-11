// ─────────────────────────────────────────────────────────────────────────────
//  HORN RUNTIME: the rules of the Horn specials, once, for every game
//
//  Cosmic Survival is where the Horn specials were built and tuned, and it is
//  the source of truth. What it decides about a cast that is pure arithmetic —
//  how a stat scales an aura, where a dash ends and how long it takes, what a
//  trail segment or a kill-site geyser is, how much a Blood horn gives up —
//  lives here so survival and open space run the very same numbers and cannot
//  drift apart again. Each game keeps only what touches its own world: which
//  bodies are near, how a hit lands, where a projectile is appended.
//
//  The particles and telegraphs these casts throw live beside the painters in
//  horn_vfx.dart.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'dart:ui';

import 'package:alchemons/models/stat_system.dart';

import 'cosmic_data.dart';

/// Survival's Horn stat curve: 1.0 at a stat of 3, [perPoint] a point either
/// side, clamped to [min]..[max]. Stats past the legacy five-point ceiling are
/// read through the gameplay rating first. Survival's other families use the
/// same curve for their own hooks.
double hornStatScale(
  double stat, {
  double perPoint = 0.12,
  double min = 0.82,
  double max = 1.22,
}) {
  final clamped = stat > AlchemonStatSystem.legacyCombatCeiling
      ? AlchemonStatSystem.legacyGameplayRating(stat)
      : stat.clamp(0.5, AlchemonStatSystem.legacyCombatCeiling);
  return (1.0 + (clamped - 3.0) * perPoint).clamp(min, max).toDouble();
}

/// [hornStatScale] for an ability's own strengths — a heal share, a hold, a
/// support's duration — that should keep growing with the creature. At or
/// below an average stat it is exactly [hornStatScale]; past it, where the
/// legacy curve has read stats through the compressed rating and clamped, it
/// keeps climbing on the anchored curve ([abilityHookValue]). A negative
/// [perPoint] (a charge time) keeps shrinking instead.
double abilityHookScale(
  double stat, {
  double perPoint = 0.12,
  double min = 0.82,
  double max = 1.22,
}) => abilityHookValue(
  stat,
  legacy: hornStatScale(stat, perPoint: perPoint, min: min, max: max),
  atAverage: hornStatScale(
    kAbilityStatAverage,
    perPoint: perPoint,
    min: min,
    max: max,
  ),
  rising: perPoint >= 0,
);

/// The fixed numbers of the Horn specials.
abstract final class HornRules {
  /// How fast a horn rams, before the cast's speed multiplier.
  static const double chargeSpeed = 400.0;

  /// A ram steps only while it is further than this from its end point.
  static const double arriveEps = 5.0;

  /// The time a ram gets on top of its travel, and the bounds on it.
  static const double travelBuffer = 0.15;
  static const double chargeTimerMin = 0.3;
  static const double chargeTimerMax = 3.0;

  /// Lightning's storm, brewed where the ram landed before it discharges.
  static const double postDashBrew = 3.0;

  /// Kills credited to the cast for this long, plus any wind-up, after it.
  static const double activeWindowBase = 5.0;

  /// A ram's deferred burst, right-sized so each impact reads cleanly.
  static const double burstSnareMax = 100.0;
  static const double burstTauntMax = 180.0;
  static const double burstEffectMax = 110.0;
  static const double burstStationaryLifeMin = 2.5;

  /// Ice: the sideways dash that paints the wall.
  static const double iceWallLength = 240.0;
  static const double iceWallSegmentInterval = 0.05;
  static const double iceTravelBuffer = 0.10;

  /// Fire: a burning patch laid behind the ram this often.
  static const double fireTrailInterval = 0.12;

  /// Water: one lap of the circle, and the bounds on its radius.
  static const double waterCircleDuration = 1.0;
  static const double waterRadiusMin = 90.0;
  static const double waterRadiusMax = 200.0;

  /// Dark: the void's wind-up, its reach, and the dash that carries the catch.
  static const double darkWindUp = 5.0;
  static const double darkAuraRadius = 260.0;
  static const double darkCaptureRadius = 200.0;
  static const double darkPullStart = 90.0;
  static const double darkPullRamp = 220.0;
  static const double darkEdgeExtra = 200.0;
  static const double darkCaptureDamageMul = 1.2;
  static const double darkCaptureJitterMin = 20.0;
  static const double darkCaptureJitterSpan = 50.0;
  static const double darkDragSlowMul = 0.55;
  static const double darkDragSlowDur = 0.30;

  /// Crystal and Spirit's wind-ups, as the telegraphs count them.
  static const double crystalWindUp = 1.2;
  static const double spiritWindUp = 2.0;

  /// Lightning: absorbed damage into the discharge.
  static const double lightningAbsorbMul = 1.4;

  /// Blood: the share of current HP given up, and what it buys.
  static const double bloodSacFraction = 0.18;
  static const double bloodSacDamageMul = 0.25;
  static const double bloodHealFraction = 0.05;

  /// Plant: how long a ram's victims are held.
  static const double plantRootBase = 3.0;

  /// Poison: the ram's extra hit, and the passive aura.
  static const double poisonDashShare = 0.40;
  static const double poisonAuraRadius = 140.0;
  static const double poisonAuraInterval = 0.6;

  /// Spirit takes this share of damage while it winds up and rams.
  static const double spiritPhaseMul = 0.40;

  /// An ally inside a Light barrier takes this share of damage.
  static const double lightAllyMul = 0.30;

  /// A body inside a Light barrier is put on its rim and thrown this hard.
  static const double lightBounceKnock = 90.0;

  /// Air's wind wisps, this often.
  static const double airParticleInterval = 0.085;
}

/// Right-sizes a ram's deferred burst: snares, taunts and effect radii are
/// capped and short-lived stationary fixtures stretched, so each impact reads.
/// (Survival also caps the sweeps at this point, but those values are
/// overwritten by the cast straight after, so the sweeps are never clamped.)
///
/// The snare and effect caps are an average horn's; [reach] ([hornZoneReach]
/// of the caster's Beauty) grows them with the zones, or a capped zone could
/// never grow. The taunt cap stays put: a wider taunt hauls more of the wave
/// onto the impact beside the orb, and measured as less protection, not more.
void clampHornChargeBurst(List<Projectile> burst, {double reach = 1.0}) {
  final snareMax = HornRules.burstSnareMax * reach;
  const tauntMax = HornRules.burstTauntMax;
  final effectMax = HornRules.burstEffectMax * reach;
  for (final p in burst) {
    if (p.snareRadius > snareMax) {
      p.snareRadius = snareMax;
    }
    if (p.tauntRadius > tauntMax) {
      p.tauntRadius = tauntMax;
    }
    // A zone that taunts and drags keeps an average horn's cap
    // ([hornZoneHoldsReach]).
    final cap = hornZoneHoldsReach(p) ? HornRules.burstEffectMax : effectMax;
    if (p.effectRadius > cap) {
      p.effectRadius = cap;
    }
    if (p.stationary && p.life < HornRules.burstStationaryLifeMin) {
      p.life = HornRules.burstStationaryLifeMin;
    }
  }
}

double _travelTimer(double distance, double speedMul, double buffer) =>
    (distance / (HornRules.chargeSpeed * speedMul) + buffer).clamp(
      HornRules.chargeTimerMin,
      HornRules.chargeTimerMax,
    );

/// The standard ram: through [target] and [overshoot] past it. With the
/// target underfoot it rams in place for [requested] seconds.
({Offset target, double timer}) hornStandardDash(
  Offset from,
  Offset target,
  double overshoot,
  double speedMul,
  double requested,
) {
  final dir = target - from;
  final dist = dir.distance;
  if (dist > 1) {
    final end = target + (dir / dist) * overshoot;
    return (
      target: end,
      timer: _travelTimer(
        (end - from).distance,
        speedMul,
        HornRules.travelBuffer,
      ),
    );
  }
  return (
    target: target,
    timer: requested.clamp(HornRules.chargeTimerMin, HornRules.chargeTimerMax),
  );
}

/// Ice: a dash square to the target (turned +90°), painting the wall.
({Offset target, double timer}) hornIceWallDash(
  Offset from,
  Offset target,
  double fireAngle,
  double speedMul,
) {
  final toTarget = target - from;
  final tdist = toTarget.distance;
  final unit = tdist > 1
      ? Offset(toTarget.dx / tdist, toTarget.dy / tdist)
      : Offset(math.cos(fireAngle), math.sin(fireAngle));
  final perp = Offset(-unit.dy, unit.dx);
  final travelTime =
      HornRules.iceWallLength / (HornRules.chargeSpeed * speedMul);
  return (
    target: from + perp * HornRules.iceWallLength,
    timer: (travelTime + HornRules.iceTravelBuffer).clamp(
      HornRules.chargeTimerMin,
      HornRules.chargeTimerMax,
    ),
  );
}

/// Dark: after the void, a dash along the cast's aim that carries the catch.
({Offset target, double timer}) hornDarkEdgeDash(
  Offset from,
  double fireAngle,
  double overshoot,
  double speedMul,
) {
  final dir = Offset(math.cos(fireAngle), math.sin(fireAngle));
  final end = from + dir * (overshoot + HornRules.darkEdgeExtra);
  return (
    target: end,
    timer: _travelTimer(
      (end - from).distance,
      speedMul,
      HornRules.travelBuffer,
    ),
  );
}

/// Water: one lap round the cast point, starting square to the aim.
({double radius, double startAngle, double angularSpeed, double duration})
hornWaterCircle(double fireAngle, double overshoot) => (
  radius: overshoot
      .clamp(HornRules.waterRadiusMin, HornRules.waterRadiusMax)
      .toDouble(),
  startAngle: fireAngle - math.pi / 2,
  angularSpeed: 2 * math.pi / HornRules.waterCircleDuration,
  duration: HornRules.waterCircleDuration,
);

/// Where the Water horn is on its circle.
Offset hornCirclePoint(Offset center, double radius, double angle) => Offset(
  center.dx + math.cos(angle) * radius,
  center.dy + math.sin(angle) * radius,
);

/// The Dark void's gathering reach, by beauty.
double hornDarkAuraRadius(double beauty) =>
    HornRules.darkAuraRadius *
    hornStatScale(beauty, perPoint: 0.10, min: 0.85, max: 1.30);

/// What the Dark void holds when the wind-up ends, by beauty.
double hornDarkCaptureRadius(double beauty) =>
    HornRules.darkCaptureRadius *
    hornStatScale(beauty, perPoint: 0.10, min: 0.85, max: 1.30);

/// The void's pull, gentle at first and yanking by the end.
double hornDarkPullSpeed(double windUpRemaining) {
  final elapsed = (HornRules.darkWindUp - windUpRemaining).clamp(
    0.0,
    HornRules.darkWindUp,
  );
  final t = elapsed / HornRules.darkWindUp;
  return HornRules.darkPullStart + HornRules.darkPullRamp * t;
}

/// Lightning: how much of what it absorbed the discharge carries, by beauty.
double hornLightningAbsorbMultiplier(double beauty) =>
    HornRules.lightningAbsorbMul *
    hornStatScale(beauty, perPoint: 0.10, min: 0.85, max: 1.40);

/// Plant: how long a ram's victims are rooted, by intelligence.
double hornPlantRootDuration(double intelligence) =>
    HornRules.plantRootBase *
    abilityHookScale(intelligence, perPoint: 0.20, min: 0.80, max: 1.80);

/// Blood: the HP given up at the cast and the ram damage it buys, or null
/// when the horn has too little to give.
({int sacrifice, double bonus})? hornBloodSacrifice(int currentHp) {
  final sac = (currentHp * HornRules.bloodSacFraction).round();
  if (sac > 0 && currentHp - sac > 1) {
    return (sacrifice: sac, bonus: sac * HornRules.bloodSacDamageMul);
  }
  return null;
}

/// Blood: what each kill in the window heals, by beauty.
int hornBloodKillHeal(int maxHp, double beauty) => math.max(
  2,
  (maxHp *
          HornRules.bloodHealFraction *
          hornStatScale(beauty, perPoint: 0.10, min: 0.85, max: 1.40))
      .round(),
);

/// Air: the still middle, the rim, and the push, by intelligence.
({double inner, double outer, double push}) hornAirAura(double intelligence) {
  final scale = hornStatScale(
    intelligence,
    perPoint: 0.10,
    min: 0.85,
    max: 1.30,
  );
  return (inner: 90.0 * scale, outer: 230.0 * scale, push: 80.0 * scale);
}

/// Poison: the aura's scale, by intelligence. The aura reaches
/// [HornRules.poisonAuraRadius] times this.
double hornPoisonAuraScale(double intelligence) =>
    hornStatScale(intelligence, perPoint: 0.10, min: 0.85, max: 1.30);

/// Mud: how often the sludge drops, sparse at 3 and dense at 5, read off the
/// raw stat as survival does — and denser still past that as the creature
/// grows ([abilityHookValue]), where the old curve stopped at 5.
double hornMudInterval(double intelligence) {
  double legacy(double stat) {
    final t = ((stat - 3.0) / 2.0).clamp(0.0, 1.0);
    return 1.45 + (0.58 - 1.45) * t;
  }

  return abilityHookValue(
    intelligence,
    legacy: legacy(intelligence),
    atAverage: legacy(kAbilityStatAverage),
    rising: false,
  );
}

/// Lava: how far a kill's flames look for prey and how many there are.
({double radius, int maxFlames}) hornLavaSeek(double beauty) {
  final scale = hornStatScale(beauty, perPoint: 0.10, min: 0.85, max: 1.30);
  return (radius: 280.0 * scale, maxFlames: (4 * scale).round().clamp(3, 6));
}

/// Steam: a kill-site geyser's size (beauty) and duration (intelligence).
({double size, double dur}) hornSteamKillScales(
  double beauty,
  double intelligence,
) => (
  size: hornStatScale(beauty, perPoint: 0.10, min: 0.85, max: 1.25),
  dur: hornStatScale(intelligence, perPoint: 0.08, min: 0.88, max: 1.20),
);

// ── what the casts lay down ────────────────────────────────────────────────

/// Fire: a burning patch behind the ram.
Projectile hornFireTrailSegment({
  required Offset position,
  required num abilityAtk,
  required int? sourceSlot,
}) => Projectile(
  position: position,
  angle: 0,
  element: 'Fire',
  damage: 0,
  life: 3.2,
  speedMultiplier: 0,
  stationary: true,
  piercing: true,
  radiusMultiplier: 1.2,
  visualScale: 1.25,
  visualStyle: ProjectileVisualStyle.sigil,
  sourceSlotIndex: sourceSlot,
  abilityFamily: 'horn',
  tauntRadius: 80.0,
  tauntStrength: 1.0,
  tickEffect: AbilityEffectKind.burn,
  effectPower: math.max(1.0, abilityAtk * 0.18),
  effectRadius: 40.0,
  effectDuration: 3.0,
);

/// Ice: one block of the wall. It taunts, slows and turns shots.
Projectile hornIceWallSegment({
  required Offset position,
  required num maxHp,
  required num abilityAtk,
  required int? sourceSlot,
}) => Projectile(
  position: position,
  angle: 0,
  element: 'Ice',
  damage: 0,
  life: 4.5,
  speedMultiplier: 0,
  stationary: true,
  piercing: true,
  radiusMultiplier: 1.4,
  visualScale: 1.6,
  visualStyle: ProjectileVisualStyle.hornImpact,
  sourceSlotIndex: sourceSlot,
  abilityFamily: 'horn',
  tauntRadius: 90.0,
  tauntStrength: 1.4,
  decoy: true,
  decoyHp: maxHp * 0.10,
  tickEffect: AbilityEffectKind.slow,
  effectPower: math.max(1.0, abilityAtk * 0.12),
  effectRadius: 44.0,
  effectDuration: 2.5,
  reflectsProjectiles: true,
);

/// Mud: a slowing sludge sigil left behind (the caller jitters [position]).
Projectile hornMudSludge({
  required Offset position,
  required num abilityAtk,
  required int? sourceSlot,
}) => Projectile(
  position: position,
  angle: 0,
  element: 'Mud',
  damage: 0,
  life: 4.5,
  speedMultiplier: 0,
  stationary: true,
  piercing: true,
  radiusMultiplier: 1.20,
  visualScale: 1.10,
  visualStyle: ProjectileVisualStyle.sigil,
  sourceSlotIndex: sourceSlot,
  abilityFamily: 'horn',
  tickEffect: AbilityEffectKind.slow,
  effectPower: math.max(1.0, abilityAtk * 0.08),
  effectRadius: 48.0,
  effectDuration: 1.4,
);

/// Poison: the faint puff that marks the aura. Authored at zero power, which
/// both games' resolvers read as their default tick.
Projectile hornPoisonAuraPuff({
  required Offset position,
  required double auraScale,
  required int? sourceSlot,
}) => Projectile(
  position: position,
  angle: 0,
  element: 'Poison',
  damage: 0,
  life: 1.4,
  speedMultiplier: 0,
  stationary: true,
  piercing: true,
  radiusMultiplier: 1.30 * auraScale,
  visualScale: 1.20 * auraScale,
  visualStyle: ProjectileVisualStyle.sigil,
  sourceSlotIndex: sourceSlot,
  abilityFamily: 'horn',
  tickEffect: AbilityEffectKind.poison,
  effectPower: 0,
  effectRadius: 60.0 * auraScale,
  effectDuration: 1.4,
);

/// Steam: the geyser a kill in the window leaves where the body fell.
Projectile hornSteamKillGeyser({
  required Offset position,
  required num abilityAtk,
  required double sizeScale,
  required double durScale,
  required int? sourceSlot,
}) => Projectile(
  position: position,
  angle: 0,
  element: 'Steam',
  damage: 0,
  life: 2.6 * durScale,
  speedMultiplier: 0,
  stationary: true,
  piercing: true,
  radiusMultiplier: 1.6 * sizeScale,
  visualScale: 1.6 * sizeScale,
  visualStyle: ProjectileVisualStyle.hornImpact,
  sourceSlotIndex: sourceSlot,
  abilityFamily: 'horn',
  tauntRadius: 100.0 * sizeScale,
  tauntStrength: 1.0,
  tickEffect: AbilityEffectKind.geyser,
  effectPower: math.max(1.0, abilityAtk * 0.5),
  effectRadius: 60.0 * sizeScale,
  effectDuration: 2.6 * durScale,
);

/// Lava: one homing flame thrown from a kill at the prey nearby.
Projectile hornLavaSeekerFlame({
  required Offset position,
  required double angle,
  required num abilityAtk,
  required int? sourceSlot,
}) => Projectile(
  position: position,
  angle: angle,
  element: 'Fire',
  damage: math.max(1.0, abilityAtk * 0.50),
  life: 1.4,
  speedMultiplier: 1.5,
  homing: true,
  homingStrength: 4.0,
  piercing: false,
  radiusMultiplier: 0.9,
  visualScale: 0.95,
  visualStyle: ProjectileVisualStyle.standard,
  sourceSlotIndex: sourceSlot,
  abilityFamily: 'horn',
);

// ── the Light barrier ──────────────────────────────────────────────────────

/// Whether [p] is a live Horn Light barrier.
bool isHornLightBarrier(Projectile p) =>
    p.abilityFamily == 'horn' &&
    p.element == 'Light' &&
    p.stationary &&
    p.reflectsProjectiles &&
    p.life > 0;

/// How far a barrier's cover reaches — the allies it protects and the rim
/// bodies are put back on. About its drawn size.
double hornLightProtectRadius(Projectile p) => 70.0 + p.radiusMultiplier * 20.0;
