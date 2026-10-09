// lib/games/cosmic/kin_support_runtime.dart
//
// The rules of the Kin family's support paths, shared by Cosmic Survival and
// open space. Survival is the source of truth: every number and every piece
// here is lifted out of it verbatim, and both games call these instead of
// keeping their own copy. Pure Dart — the host passes positions, stats and
// the sinks it wants things poured into.

import 'dart:math';
import 'dart:ui';

import 'package:alchemons/models/stat_system.dart';

import 'cosmic_data.dart';
import 'horn_runtime.dart' show hornStatScale;

/// A Kin's special waits this much longer than its table cooldown. Every Kin
/// is a build-defining support and the cast is what sets it running.
const double kKinSpecialCooldownStretch = 1.6;

/// Where a Kin emitter pours its particles: position, velocity, size, life
/// and color — the same shape both games' particle pools take.
typedef KinVfxEmit =
    void Function(
      double x,
      double y,
      double vx,
      double vy,
      double size,
      double life,
      Color color,
    );

/// The fixed numbers and pieces of the Kin support paths.
abstract final class KinSupport {
  // ── how long a cast runs (Intelligence stretches it) ─────────────────────

  static double lavaPlateDuration(double intelligence) =>
      9.0 * hornStatScale(intelligence, perPoint: 0.10, min: 0.85, max: 1.40);

  static double iceChargeDuration(double intelligence) =>
      4.0 * hornStatScale(intelligence, perPoint: -0.06, min: 0.70, max: 1.15);

  static double steamBoilerDuration(double intelligence) =>
      10.0 * hornStatScale(intelligence, perPoint: 0.12, min: 0.80, max: 1.60);

  static double lightningChargeDuration(double intelligence) =>
      10.0 * hornStatScale(intelligence, perPoint: 0.10, min: 0.85, max: 1.40);

  static double mudEnchantDuration(double intelligence) =>
      5.0 * hornStatScale(intelligence, perPoint: 0.10, min: 0.85, max: 1.40);

  static double darkVeilDuration(double intelligence) =>
      7.0 * hornStatScale(intelligence, perPoint: 0.10, min: 0.85, max: 1.50);

  static double bloodPactDuration(double intelligence) =>
      9.0 * hornStatScale(intelligence, perPoint: 0.10, min: 0.85, max: 1.50);

  /// Starts the timed support a cast of [element] sets running on [k]. Dust,
  /// Spirit and Earth lay a piece instead (the host builds it from the
  /// builders below), and Fire never casts.
  static void activateTimers(
    KinSupportFields k,
    String element, {
    required double intelligence,
  }) {
    switch (element) {
      case 'Lava':
        k.kinLavaPlateTimer = lavaPlateDuration(intelligence);
      case 'Ice':
        final chargeTime = iceChargeDuration(intelligence);
        k.kinIceChargeTimer = chargeTime;
        k.kinIceChargeTotal = chargeTime;
      case 'Steam':
        k.kinSteamBoilerTimer = steamBoilerDuration(intelligence);
        k.kinSteamBoilerStacks = 0;
        k.kinSteamStackCarry = 0;
        k.kinSteamStackDecayTimer = steamDecayInterval;
      case 'Lightning':
        k.kinLightningChargeTimer = lightningChargeDuration(intelligence);
      case 'Mud':
        k.kinMudShipEnchantTimer = mudEnchantDuration(intelligence);
      case 'Dark':
        k.kinDarkCloakTimer = darkVeilDuration(intelligence);
      case 'Blood':
        k.kinBloodPactTimer = bloodPactDuration(intelligence);
    }
  }

  // ── Fire: the phoenix and its rebirth ────────────────────────────────────

  /// What the objective is restored to when the phoenix saves it.
  static const double phoenixRestoreFraction = 0.25;
  static const Color phoenixEmber = Color(0xFFFFB060);
  static const Color phoenixFlash = Color(0xFFFFE7B0);

  /// The rise-from-the-ashes buff, rolled once from the kin's own stats:
  /// Beauty the reach of the flame, Speed the rate it ticks and the kin's own
  /// attack rate.
  static ({double radius, double interval, double haste, double damageAmp})
  fireRebirth({required double beauty, required double speed}) => (
    radius:
        70 *
        scaledAbilityValue(
          beauty,
          atLow: 0.80,
          atAverage: 1.0,
          atPerfect: 1.48,
        ),
    interval:
        0.5 /
        scaledAbilityValue(speed, atLow: 0.82, atAverage: 1.0, atPerfect: 1.70),
    haste:
        (1.0 /
                scaledAbilityValue(
                  speed,
                  atLow: 1.08,
                  atAverage: 1.20,
                  atPerfect: 1.55,
                ))
            .clamp(0.45, 1.0)
            .toDouble(),
    damageAmp: scaledAbilityValue(
      beauty,
      atLow: 1.15,
      atAverage: 1.30,
      atPerfect: 1.75,
    ).clamp(1.0, 4.0).toDouble(),
  );

  /// The reborn flame's burn per tick.
  static double fireFlameDamage(num abilityAtk) => max(abilityAtk * 0.6, 4.0);

  // ── Lava: the reactive plate ─────────────────────────────────────────────

  static const double lavaSplashRadius = 90.0;

  /// How far from the ship the plate looks for what struck.
  static const double lavaSearchShip = 280.0;

  /// How far from the orb the plate looks, when it was the orb that was hit.
  static const double lavaSearchOrb = 200.0;
  static const Color lavaSplashColor = Color(0xFFFF7A20);

  /// The splash for [teamDamage] taken this frame, capped so a crowd breaking
  /// on the objective pays a steady price, not one frame of everything.
  static double lavaSplashDamage(double teamDamage, num abilityAtk) =>
      max(teamDamage * 1.4, abilityAtk * 0.8).clamp(0.0, abilityAtk * 3.0);

  // ── Ice: the charge and its release ──────────────────────────────────────

  static double iceReleaseRadius(double beauty) =>
      220.0 * hornStatScale(beauty, perPoint: 0.40, min: 0.85, max: 6.0);

  static double iceSlowDuration(double intelligence) =>
      4.0 * hornStatScale(intelligence, perPoint: 0.18, min: 0.90, max: 2.0);

  /// The 90% slow the design asks for.
  static const double iceSlowMultiplier = 0.10;
  static const Color frost = Color(0xFFEFFFFF);

  // ── Steam: the boiler ────────────────────────────────────────────────────

  static const int steamMaxStacks = 10;

  /// Seconds a stack lasts without fresh damage.
  static const double steamDecayInterval = 2.0;

  /// One stack per 8% of the ship's health taken by the bodies it protects.
  static double steamBodyUnit(double shipMaxHp) => max(2.0, shipMaxHp * 0.08);

  /// One stack per 1.5% of the orb's health, for hits on the orb.
  static double steamObjectiveUnit(double orbMaxHp) =>
      max(4.0, orbMaxHp * 0.015);

  /// Beauty scales each stack's potency (5% base).
  static double steamPerStack(double beauty) =>
      0.05 * hornStatScale(beauty, perPoint: 0.10, min: 0.85, max: 1.40);

  /// The attack-cooldown multiplier every companion gets at [stacks].
  static double steamHasteMultiplier(int stacks, double beauty) =>
      (1.0 - (stacks * steamPerStack(beauty))).clamp(0.50, 1.0).toDouble();

  /// One frame of the boiler: [gain] is this frame's stack progress (the
  /// damage taken, in stack units; 0 for none). Carried across frames so
  /// chaff chipping at the objective still counts.
  static ({int stacks, double carry, double decayTimer}) steamStep({
    required int stacks,
    required double carry,
    required double decayTimer,
    required double gain,
    required double dt,
  }) {
    if (gain > 0) {
      carry += gain;
      final gained = carry.floor();
      if (gained > 0) {
        carry -= gained;
        stacks = min(steamMaxStacks, stacks + gained);
        decayTimer = steamDecayInterval;
      }
    }
    // Decay 1 stack per 2s when no recent damage.
    if (stacks > 0) {
      decayTimer -= dt;
      if (decayTimer <= 0) {
        stacks = max(0, stacks - 1);
        decayTimer = steamDecayInterval;
      }
    }
    return (stacks: stacks, carry: carry, decayTimer: decayTimer);
  }

  // ── Lightning: the tesla channel ─────────────────────────────────────────

  /// Chain hops every companion basic carries while a tesla channel holds.
  static const int teslaChainCharges = 3;

  // ── Blood: the pact ──────────────────────────────────────────────────────

  /// The share of what the alchemons took that the pact heals back, split
  /// evenly over the living ones — ship included.
  static const double bloodHealShare = 0.60;
  static const Color bloodThread = Color(0xFFC8254A);

  // ── Crystal: the refractors ──────────────────────────────────────────────

  static const double crystalRefractRange = 360.0;
  static const Color refractColor = Color(0xFFFFF3C8);
  static double crystalRefractDamage(Projectile shard) =>
      max(12.0, shard.damage * 2.0);

  // ── Earth: the wall ──────────────────────────────────────────────────────

  /// A curved arc of indestructible stone round [center] (the orb in
  /// survival, the ship in open space), facing [facing]. The arc spans ~120°
  /// so it covers the front without enclosing the centre. Segments shove on
  /// contact and reflect hostile shots, and never take damage — they time
  /// out.
  static List<Projectile> earthWallArc({
    required Offset center,
    required double facing,
    required double beauty,
    int? slot,
  }) {
    final segCount =
        7 + (AlchemonStatSystem.combatProgress(beauty) * 4).round();
    const arcSpanRad = 2.094; // ~120° front arc
    const arcRadius = 110.0;
    final lifeSeconds =
        12.0 * hornStatScale(beauty, perPoint: 0.10, min: 0.85, max: 1.40);
    return [
      for (var i = 0; i < segCount; i++)
        () {
          final t = segCount == 1 ? 0.5 : i / (segCount - 1).toDouble();
          final a = facing - arcSpanRad / 2 + arcSpanRad * t;
          return Projectile(
            position: Offset(
              center.dx + cos(a) * arcRadius,
              center.dy + sin(a) * arcRadius,
            ),
            angle: 0,
            element: 'Earth',
            damage: 0,
            life: lifeSeconds,
            speedMultiplier: 0,
            stationary: true,
            piercing: true,
            radiusMultiplier: 1.6,
            visualScale: 1.7,
            visualStyle: ProjectileVisualStyle.sigil,
            sourceSlotIndex: slot,
            abilityFamily: 'kin',
            hitEffect: AbilityEffectKind.knockback,
            effectPower: 320,
            effectRadius: 60,
            effectDuration: 0.3,
            reflectsProjectiles: true,
          );
        }(),
    ];
  }

  /// How close a hostile shot must come to a reflecting fixture.
  static double reflectorRadius(Projectile fixture) =>
      fixture.element == 'Light'
      ? max(60.0, fixture.radiusMultiplier * 20.0 + 70.0)
      : fixture.radiusMultiplier * 12.0 + 18.0;

  /// A reflected shot re-aims at the nearest foe within this reach.
  static const double reflectRetargetRange = 480.0;

  // ── Dust: the clouds ─────────────────────────────────────────────────────

  static const int dustCloudCap = 10;

  /// Hostile shots inside a cloud are lost at this chance per frame.
  static const double dustShotMissChance = 0.80;

  static bool isDustCloud(Projectile p) =>
      p.abilityFamily == 'kin' &&
      p.element == 'Dust' &&
      p.stationary &&
      p.effectRadius > 0;

  static int countDustClouds(Iterable<Projectile> projectiles, int? slot) {
    var active = 0;
    for (final p in projectiles) {
      if (p.sourceSlotIndex == slot &&
          p.abilityFamily == 'kin' &&
          p.element == 'Dust' &&
          p.stationary) {
        active++;
      }
    }
    return active;
  }

  static bool insideDustCloud(Iterable<Projectile> projectiles, Offset pos) {
    for (final p in projectiles) {
      if (!isDustCloud(p)) continue;
      final d = p.position - pos;
      if (d.dx * d.dx + d.dy * d.dy < p.effectRadius * p.effectRadius) {
        return true;
      }
    }
    return false;
  }

  /// A field cloud: 160px at baseline Beauty so it reads as a real
  /// defensive zone, slowing and snaring what walks through it.
  static Projectile dustCloud(
    Offset at, {
    required double beauty,
    required double intelligence,
    int? slot,
  }) {
    final radius =
        160.0 * hornStatScale(beauty, perPoint: 0.12, min: 0.85, max: 1.55);
    return Projectile(
      position: at,
      angle: 0,
      element: 'Dust',
      damage: 0,
      life:
          30.0 *
          hornStatScale(intelligence, perPoint: 0.10, min: 0.85, max: 1.50),
      speedMultiplier: 0,
      piercing: true,
      stationary: true,
      radiusMultiplier: max(1.6, radius / 28.0),
      visualScale: 2.4,
      visualStyle: ProjectileVisualStyle.sigil,
      sourceSlotIndex: slot,
      abilityFamily: 'kin',
      tickEffect: AbilityEffectKind.slow,
      effectPower: 1.0,
      effectRadius: radius,
      effectDuration: 1.4,
      snareRadius: radius,
      snareMoveMultiplier: 0.55,
    );
  }

  // ── Mud: the ship enchant ────────────────────────────────────────────────

  static const double mudPatchInterval = 0.35;

  /// One patch of the slowing trail the enchanted ship leaves.
  static Projectile mudPatch(Offset at, int? slot) => Projectile(
    position: at,
    angle: 0,
    element: 'Mud',
    damage: 0,
    life: 5.0,
    speedMultiplier: 0,
    stationary: true,
    piercing: true,
    radiusMultiplier: 1.4,
    visualScale: 1.4,
    visualStyle: ProjectileVisualStyle.sigil,
    sourceSlotIndex: slot,
    abilityFamily: 'kin',
    tickEffect: AbilityEffectKind.slow,
    effectPower: 1.0,
    effectRadius: 48,
    effectDuration: 1.6,
  );

  // ── Spirit: the wisp ─────────────────────────────────────────────────────

  static const double spiritWispLife = 60.0;

  static bool isSpiritWisp(Projectile p, int? slot) =>
      p.sourceSlotIndex == slot &&
      p.abilityFamily == 'kin' &&
      p.element == 'Spirit' &&
      p.followSourceCompanion;

  /// The wisp tied to [slot]'s Spirit kin, if one is out.
  static Projectile? findSpiritWisp(
    Iterable<Projectile> projectiles,
    int? slot,
  ) {
    for (final p in projectiles) {
      if (isSpiritWisp(p, slot)) return p;
    }
    return null;
  }

  /// A new wisp orbiting the Spirit kin at [casterPos]. Tier 1 at spawn;
  /// it tiers up on the kin's kills.
  static Projectile spiritWisp(Offset casterPos, int? slot) {
    const orbitR = 56.0;
    return Projectile(
      position: Offset(casterPos.dx + orbitR, casterPos.dy),
      angle: 0,
      element: 'Spirit',
      damage: 0,
      life: spiritWispLife,
      orbitCenter: casterPos,
      orbitAngle: 0,
      orbitRadius: orbitR,
      orbitSpeed: 1.8,
      orbitTime: 999.0,
      holdOrbit: true,
      followSourceCompanion: true,
      radiusMultiplier: 1.4,
      visualScale: 1.2,
      visualStyle: ProjectileVisualStyle.sigil,
      sourceSlotIndex: slot,
      abilityFamily: 'kin',
      // effectStacks = kill count, effectCount = current tier (1..4)
      effectStacks: 0,
      effectCount: 1,
    );
  }

  static int spiritWispTier(int kills) => kills >= 30
      ? 4
      : kills >= 15
      ? 3
      : kills >= 5
      ? 2
      : 1;

  /// Sets the wisp's form for [kills]: T1 just orbits, T2 draws aggro.
  /// (T3's attack and T4's heal are on the design board only.)
  static void applySpiritWispTier(Projectile wisp, int kills) {
    final tier = spiritWispTier(kills);
    if (wisp.effectCount == tier) return; // no change
    wisp.effectCount = tier;
    wisp.visualScale = 1.0 + 0.4 * (tier - 1);
    wisp.radiusMultiplier = 1.2 + 0.3 * (tier - 1);
    wisp.tauntRadius = tier >= 2 ? 160.0 + 30.0 * (tier - 2) : 0;
    wisp.tauntStrength = tier >= 2 ? 3.0 : 0;
  }
}

/// The Kin basic attack: a charge, then a thin laser along the line.
abstract final class KinLaser {
  static const double chargeTime = 1.5;

  /// How far off the line a body may stand and still be struck (plus its
  /// own radius).
  static const double lateral = 14.0;

  /// The laser hits for physAtk × this. With the charge and the standard
  /// cooldown the cadence is ~2× slower than other families, so 4× per shot
  /// keeps single-target DPS roughly even.
  static const double damageScale = 4.0;

  /// The charge locks onto the nearest body within this of the target.
  static const double lockRadius = 80.0;

  /// Past attack range, how far the fire-time fallback looks.
  static const double fallbackExtra = 80.0;
  static const double beamLife = 0.28;
  static const double beamWidth = 2.6;
  static const int beamCap = 24;

  /// Enough to reach the target plus some overshoot, capped.
  static double length(double distanceToTarget) =>
      (distanceToTarget + 60.0).clamp(120.0, 720.0).toDouble();

  static double distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq <= 0.0001) return (p - a).distance;
    final ap = p - a;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lenSq).clamp(0.0, 1.0);
    final closest = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - closest).distance;
  }
}

/// One drawn laser, fading over [KinLaser.beamLife].
class KinLaserBeam {
  KinLaserBeam({required this.origin, required this.end, required this.color});

  final Offset origin;
  final Offset end;
  final Color color;
  double life = KinLaser.beamLife;
  bool get dead => life <= 0;

  /// 1 when fresh, 0 when gone.
  double get alpha => (life / KinLaser.beamLife).clamp(0.0, 1.0);
}

/// Adds [beam] to [beams], dropping the oldest past the cap.
void pushKinLaserBeam(List<KinLaserBeam> beams, KinLaserBeam beam) {
  if (beams.length >= KinLaser.beamCap) beams.removeAt(0);
  beams.add(beam);
}

/// Ages every beam and drops the spent ones.
void updateKinLaserBeams(List<KinLaserBeam> beams, double dt) {
  if (beams.isEmpty) return;
  for (final beam in beams) {
    beam.life -= dt;
  }
  beams.removeWhere((b) => b.dead);
}

// ── emitters ─────────────────────────────────────────────────────────────
//
// Each takes [hasRoom], asked before every particle (and before the random
// numbers it costs), so a full pool stops the emission exactly where
// survival's own loops broke off.

/// The Ice kin's release: frost shooting from the kin toward each slowed
/// body (so the player sees where the freeze went), a spark on each, then a
/// light radial sheen that reads even when nothing was in range.
void emitKinIceRelease({
  required Offset origin,
  required List<Offset> targets,
  required Random rng,
  required bool Function() hasRoom,
  required KinVfxEmit emit,
  required void Function(Offset at, Color color) spark,
  required Color iceColor,
}) {
  for (final target in targets) {
    if (!hasRoom()) break;
    final delta = target - origin;
    final dist = delta.distance;
    if (dist < 0.01) continue;
    final travelTime = 0.55 + rng.nextDouble() * 0.20;
    for (var k = 0; k < 3; k++) {
      if (!hasRoom()) break;
      final spread = (rng.nextDouble() - 0.5) * 0.35;
      final spd = dist / travelTime;
      emit(
        origin.dx,
        origin.dy,
        cos(delta.direction + spread) * spd,
        sin(delta.direction + spread) * spd,
        1.4 + rng.nextDouble() * 1.2,
        travelTime,
        k.isEven ? iceColor : KinSupport.frost,
      );
    }
    spark(target, KinSupport.frost);
  }
  for (var i = 0; i < 12; i++) {
    if (!hasRoom()) break;
    final a = i * (pi * 2 / 12);
    final spd = 200 + rng.nextDouble() * 140;
    emit(
      origin.dx,
      origin.dy,
      cos(a) * spd,
      sin(a) * spd,
      1.4 + rng.nextDouble() * 1.0,
      0.55 + rng.nextDouble() * 0.30,
      KinSupport.frost,
    );
  }
}

/// The Fire kin's phoenix save: 24 embers thrown from [at].
void emitKinPhoenixBurst({
  required Offset at,
  required Random rng,
  required bool Function() hasRoom,
  required KinVfxEmit emit,
}) {
  for (var i = 0; i < 24; i++) {
    if (!hasRoom()) break;
    final a = rng.nextDouble() * 2 * pi;
    final spd = 180 + rng.nextDouble() * 220;
    emit(
      at.dx,
      at.dy,
      cos(a) * spd,
      sin(a) * spd,
      1.6 + rng.nextDouble() * 1.6,
      0.55 + rng.nextDouble() * 0.40,
      i.isEven ? KinSupport.phoenixFlash : KinSupport.phoenixEmber,
    );
  }
}

/// A radial burst of [radius] (a Mane Light ring feeding, a detonation).
/// Checks for room once, as survival's does.
void emitDetonationBurst({
  required Offset center,
  required Color color,
  required double radius,
  required Random rng,
  required bool Function() hasRoom,
  required KinVfxEmit emit,
}) {
  if (!hasRoom()) return;
  final burstCount = max(10, (radius / 10).round()).clamp(10, 26);
  for (var i = 0; i < burstCount; i++) {
    final angle = (i / burstCount) * pi * 2;
    final speed = radius * (1.4 + rng.nextDouble() * 0.6);
    emit(
      center.dx,
      center.dy,
      cos(angle) * speed,
      sin(angle) * speed,
      3.0 + rng.nextDouble() * 3.2,
      0.24 + rng.nextDouble() * 0.22,
      color.withValues(alpha: 0.92),
    );
  }
}

// ── Plant: the healing garden's flowers ──────────────────────────────────

/// The garden drops a collectible flower this often.
const double kKinGardenFlowerInterval = 5.0;

/// The Plant kin's garden (the flower marker is `effectCount == 1`).
bool isKinGarden(Projectile p) =>
    p.abilityFamily == 'kin' &&
    p.element == 'Plant' &&
    p.stationary &&
    p.tickEffect == AbilityEffectKind.zoneHeal &&
    p.effectCount == 1;

/// Where in [garden] the next flower grows.
Offset kinGardenFlowerSpot(Projectile garden, Random rng) {
  final a = rng.nextDouble() * 2 * pi;
  final r =
      (garden.effectRadius * 0.4) +
      rng.nextDouble() * (garden.effectRadius * 0.4);
  return Offset(
    garden.position.dx + cos(a) * r,
    garden.position.dy + sin(a) * r,
  );
}

/// What a harvested flower heals every alchemon and the ship for.
double kinGardenFlowerHeal(Projectile garden) =>
    max(5.0, garden.effectPower * 1.2);
