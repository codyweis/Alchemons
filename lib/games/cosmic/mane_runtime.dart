// lib/games/cosmic/mane_runtime.dart
//
// The rules of the Mane specials that live outside the shared ability table,
// shared by Cosmic Survival and open space: what a cast becomes (Light's
// ward, Spirit's stream, Lightning's scatter), what the catapult sheds as it
// travels, and what each element does to the bodies it pierces. Survival is
// the source of truth and every number here is lifted out of it verbatim.
// Pure Dart — the host passes positions, the random source and a clamp.

import 'dart:math';
import 'dart:ui';

import 'cosmic_data.dart';

abstract final class ManeRuntime {
  // ── what a cast becomes ──────────────────────────────────────────────────

  /// Spirit: each cast adds another shot to a tight machine-gun stream up to
  /// ten, then resets. [stacks] is the caster's cast counter; returns the
  /// stream and the counter's next value.
  static (List<Projectile>, int) spiritStream(
    Projectile base,
    double angle,
    int stacks,
    int? slot,
  ) {
    final shotCount = 1 + stacks.clamp(0, 9);
    final dir = Offset(cos(angle), sin(angle));
    final perp = Offset(-dir.dy, dir.dx);
    final soulSlashes = <Projectile>[];
    for (var i = 0; i < shotCount; i++) {
      final laneOffset = ((i % 3) - 1) * 2.5;
      soulSlashes.add(
        Projectile(
          position: base.position - dir * (i * 9.0) + perp * laneOffset,
          angle: angle + (i.isEven ? -0.018 : 0.018),
          element: base.element,
          damage: base.damage,
          life: base.life + i * 0.025,
          speedMultiplier: min(base.speedMultiplier + i * 0.012, 0.74),
          radiusMultiplier: max(base.radiusMultiplier * 0.88, 0.72),
          visualScale: max(base.visualScale * 0.86, 0.72),
          piercing: base.piercing,
          homing: base.homing,
          homingStrength: base.homingStrength,
          visualStyle: base.visualStyle,
          sourceSlotIndex: slot,
          abilityFamily: base.abilityFamily,
          hitEffect: base.hitEffect,
          killEffect: base.killEffect,
          pierceEffect: base.pierceEffect,
          effectPower: base.effectPower,
          effectRadius: base.effectRadius,
          effectDuration: base.effectDuration,
          // The Mane per-body ceiling rides along. A fresh Projectile starts
          // at 0 (no limit), so every slash of the stream billed a standing
          // body once a frame — twice the damage at 120 fps as at 60
          // (measured 2026-10-07), in every mode that builds the stream.
        )..maxHitsPerEnemy = base.maxHitsPerEnemy,
      );
    }
    return (soulSlashes, stacks >= 9 ? 0 : stacks + 1);
  }

  /// How far past the scatter centre the nearest Lightning orb lands.
  static const double lightningOrbBaseDistance = 170.0;

  /// Lightning: 5–10 small orbs thrown toward scattered points round
  /// [scatterCenter]; each blooms into a shock field where it lands.
  /// [clamp] keeps a landing point inside the host's play space.
  /// How many orbs a cast places: the cast's own lane count, which the
  /// special sets from Beauty (5 weak, 7 average, 12 perfect), held to the
  /// board's 5-10. It used to be a roll of 5-10 whatever the caster, so the
  /// field never grew with stats, and once the stacking rule stopped its
  /// fields piling up (ability pass M7) it lost a third of its damage at
  /// perfect and read as an early-game special.
  static int lightningOrbCount(int castLanes) => castLanes.clamp(5, 10);

  static List<Projectile> lightningOrbs(
    Projectile base, {
    required Offset casterPos,
    required double angle,
    required Offset scatterCenter,
    required double scatterRadius,
    required Random rng,
    required Offset Function(Offset) clamp,
    required int count,
    int? slot,
  }) {
    final orbCount = lightningOrbCount(count);
    final orbs = <Projectile>[];
    for (var i = 0; i < orbCount; i++) {
      final a = angle + i * 2.399963 + (rng.nextDouble() - 0.5) * 0.42;
      final dist = lightningOrbBaseDistance + rng.nextDouble() * scatterRadius;
      final target = clamp(scatterCenter + Offset(cos(a), sin(a)) * dist);
      final launchAngle = atan2(
        target.dy - casterPos.dy,
        target.dx - casterPos.dx,
      );
      final orb = Projectile(
        position: Offset(
          casterPos.dx + cos(launchAngle) * 24,
          casterPos.dy + sin(launchAngle) * 24,
        ),
        angle: launchAngle,
        element: 'Lightning',
        damage: 0,
        life: 2.9,
        speedMultiplier: 0.82 + (i % 3) * 0.05,
        piercing: true,
        radiusMultiplier: 0.58,
        visualScale: 0.62,
        visualStyle: ProjectileVisualStyle.sigil,
        sourceSlotIndex: slot,
        abilityFamily: 'mane',
        effectPower: base.damage * 0.30,
        effectRadius: 44,
        effectDuration: 1.0,
        effectStacks: 1,
      );
      orb.cachedHomingTarget = target;
      orbs.add(orb);
    }
    return orbs;
  }

  /// One frame of a Lightning orb flying to its landing point. Null when [p]
  /// is not a travelling orb; otherwise whether it landed this frame (it is
  /// then spent, and the host lays a [lightningShockField] where it landed).
  static ({Offset? landedAt})? lightningOrbStep(Projectile p, double dt) {
    if (p.abilityFamily != 'mane' ||
        p.element != 'Lightning' ||
        p.effectStacks != 1) {
      return null;
    }
    final target = p.cachedHomingTarget;
    if (target == null) return null;
    final toTarget = target - p.position;
    final dist = toTarget.distance;
    final step = Projectile.speed * max(0.25, p.speedMultiplier) * dt;
    if (dist <= step || dist < 8) {
      p.life = 0;
      return (landedAt: target);
    }
    final dir = toTarget / dist;
    p.angle = atan2(dir.dy, dir.dx);
    p.position += dir * step;
    return (landedAt: null);
  }

  /// The shock field a Lightning orb blooms into.
  static Projectile lightningShockField(Projectile source, Offset at) =>
      Projectile(
        position: at,
        angle: 0,
        element: 'Lightning',
        damage: 0,
        life: 4.0,
        speedMultiplier: 0,
        stationary: true,
        piercing: true,
        radiusMultiplier: 0.95,
        visualScale: 1.05,
        visualStyle: ProjectileVisualStyle.sigil,
        sourceSlotIndex: source.sourceSlotIndex,
        abilityFamily: 'mane',
        tickEffect: AbilityEffectKind.zoneDamage,
        effectPower: source.effectPower,
        effectRadius: source.effectRadius.clamp(36.0, 48.0).toDouble(),
        effectDuration: source.effectDuration,
        effectStacks: 2,
      );

  // ── what the catapult sheds in flight ────────────────────────────────────

  /// Earth: a quake burst the fault slab leaves as it breaks.
  static Projectile earthQuakePulse(Projectile source, Random rng) {
    final dir = Offset(cos(source.angle), sin(source.angle));
    final perp = Offset(-dir.dy, dir.dx);
    final offset = perp * ((rng.nextDouble() - 0.5) * 56.0) - dir * 18.0;
    return Projectile(
      position: source.position + offset,
      angle: source.angle,
      element: 'Earth',
      damage: 0,
      life: 1.05,
      speedMultiplier: 0,
      stationary: true,
      piercing: true,
      radiusMultiplier: 0.92,
      visualScale: 0.92,
      visualStyle: ProjectileVisualStyle.sigil,
      sourceSlotIndex: source.sourceSlotIndex,
      abilityFamily: 'mane',
      tickEffect: AbilityEffectKind.zoneDamage,
      effectPower: max(source.turretDamage * 0.62, source.damage * 0.16),
      effectRadius: max(54.0, source.effectRadius * 0.42),
      effectDuration: 0.85,
      snareRadius: max(48.0, source.snareRadius * 0.40),
      snareMoveMultiplier: min(source.snareMoveMultiplier, 0.52),
    );
  }

  /// Earth: the slab wears down as it sheds.
  static void earthShrink(Projectile p, double dt) {
    p.radiusMultiplier = max(p.radiusMultiplier - dt * 0.36, 2.15);
    p.visualScale = max(p.visualScale - dt * 0.30, 1.85);
  }

  /// Steam: a geyser puff dropped under the projectile.
  static Projectile steamPuff(Projectile p) => Projectile(
    position: p.position,
    angle: 0,
    element: 'Steam',
    damage: 0,
    life: 1.6,
    speedMultiplier: 0,
    stationary: true,
    piercing: true,
    radiusMultiplier: 1.5,
    visualScale: 1.4,
    visualStyle: ProjectileVisualStyle.sigil,
    sourceSlotIndex: p.sourceSlotIndex,
    abilityFamily: 'mane',
    tickEffect: AbilityEffectKind.geyser,
    effectPower: p.turretDamage,
    effectRadius: 70,
    effectDuration: 1.2,
  );

  /// Dust leaves a puff this often, painting a trailing dust line.
  static const double dustPuffInterval = 0.35;

  static bool shedsDustPuffs(Projectile p) =>
      p.abilityFamily == 'mane' && p.element == 'Dust';

  /// Most Dust puffs on the field at once. A well-bred Mane keeps a dozen
  /// Dust shots in flight, and their trails held about 106 of the 220
  /// shared projectile slots at every stat level; the same budget Pip's mud
  /// trail uses ([kPipMudTrailBudget]) keeps the line without the crowd.
  static const int dustTrailBudget = 48;

  /// Whether another Dust puff fits under [dustTrailBudget].
  static bool dustTrailHasRoom(Iterable<Projectile> projectiles) {
    var puffs = 0;
    for (final p in projectiles) {
      if (p.stationary && p.element == 'Dust' && p.abilityFamily == 'mane') {
        if (++puffs >= dustTrailBudget) return false;
      }
    }
    return true;
  }

  /// Dust: one slow-cloud puff under the projectile.
  static Projectile dustTrailPuff(Projectile p) => Projectile(
    position: p.position,
    angle: 0,
    element: 'Dust',
    damage: 0,
    life: 2.4,
    speedMultiplier: 0,
    stationary: true,
    piercing: true,
    radiusMultiplier: 1.3,
    visualScale: 1.3,
    visualStyle: ProjectileVisualStyle.sigil,
    sourceSlotIndex: p.sourceSlotIndex,
    abilityFamily: 'mane',
    tickEffect: AbilityEffectKind.suppressShooting,
    effectPower: p.damage * 0.10,
    effectRadius: 60,
    effectDuration: 1.6,
  );

  /// Dark: the slow void bolt drags every body within its snare toward
  /// itself every frame, harder close in. The step for a body at [enemy],
  /// or null when it is out of reach (or on top of the bolt).
  static Offset? darkPullStep(
    Offset bolt,
    Offset enemy,
    double radius,
    double dt,
  ) {
    final dx = bolt.dx - enemy.dx;
    final dy = bolt.dy - enemy.dy;
    final distSq = dx * dx + dy * dy;
    if (distSq < 4.0 || distSq > radius * radius) return null;
    final dist = sqrt(distSq);
    final norm = Offset(dx / dist, dy / dist);
    final t = 1.0 - (dist / radius);
    final speed = 60.0 + 220.0 * t;
    return Offset(norm.dx * speed * dt, norm.dy * speed * dt);
  }

  static bool pullsInFlight(Projectile p) =>
      p.abilityFamily == 'mane' &&
      p.element == 'Dark' &&
      !p.stationary &&
      p.snareRadius > 0;

  // ── what it does to what it touches ──────────────────────────────────────

  /// Mud: the first body struck splits the projectile into ten fragments.
  static bool shattersOnHit(Projectile p) =>
      p.abilityFamily == 'mane' &&
      p.element == 'Mud' &&
      !p.clustered &&
      p.effectStacks == 0;

  static List<Projectile> mudShards(Projectile p, Offset at) => [
    for (var fi = 0; fi < 10; fi++)
      Projectile(
        position: at,
        angle: fi * (pi * 2 / 10),
        element: 'Mud',
        damage: p.damage * 0.45,
        life: 1.0,
        speedMultiplier: 1.4,
        radiusMultiplier: max(p.radiusMultiplier * 0.55, 0.7),
        visualScale: max(p.visualScale * 0.55, 0.7),
        piercing: false,
        visualStyle: ProjectileVisualStyle.slash,
        sourceSlotIndex: p.sourceSlotIndex,
        abilityFamily: 'mane',
        hitEffect: AbilityEffectKind.slow,
        effectPower: p.effectPower * 0.6,
        effectRadius: 40,
        effectDuration: 1.5,
        effectStacks: 1,
      ),
  ];

  /// Most blobs one Lava shot drops: the first bodies it pierces.
  static const int lavaBlobsPerShot = 4;

  /// Whether this pierce drops a lava blob. Only the shot does: a blob is
  /// itself a piercing Mane Lava projectile, so letting blobs drop blobs
  /// chained them until they filled 217 of the 220 shared projectile slots.
  /// And only for its first [lavaBlobsPerShot] bodies: a well-bred Mane
  /// fires often enough that one blob per body still filled the pool.
  /// Call it after the pierce is recorded in [Projectile.effectHitIds].
  static bool dropsLavaBlob(Projectile p) =>
      !p.stationary && p.effectHitIds.length <= lavaBlobsPerShot;

  /// Lava: a burning blob left at the pierce point.
  static Projectile lavaBlob(Projectile p, Offset at) => Projectile(
    position: at,
    angle: 0,
    element: 'Lava',
    damage: 0,
    life: 3.6,
    speedMultiplier: 0,
    stationary: true,
    piercing: true,
    radiusMultiplier: 1.4,
    visualScale: 1.3,
    visualStyle: ProjectileVisualStyle.sigil,
    sourceSlotIndex: p.sourceSlotIndex,
    abilityFamily: 'mane',
    tickEffect: AbilityEffectKind.burn,
    effectPower: p.damage * 0.18,
    effectRadius: 50,
    effectDuration: 3.6,
  );

  /// How many Lava pools lie on the field, for the painter's crowd switch.
  static int countLavaPools(Iterable<Projectile> projectiles) {
    var lavaPools = 0;
    for (final p in projectiles) {
      if (p.stationary && p.element == 'Lava' && p.abilityFamily == 'mane') {
        lavaPools++;
      }
    }
    return lavaPools;
  }

  /// Plant: how long a pierced body is rooted.
  static const double plantRootTime = 2.6;

  /// Plant: a rooted body's kill detonates the root on everything near it.
  /// 70 px: at 165 one kill blew up most of a lane and re-rooted it, so the
  /// chain carried the vine to about 5x the median special at every band;
  /// its hits already killed what they reached, so only reach, growth and
  /// rate moved it (ability pass, final balance, 2026-10-10). Every mode
  /// reads this.
  static const double plantRootExplodeRadius = 70.0;
  static const double plantRootExplodeShare = 2.1;
  static const double plantRootChainTime = 1.4;

  /// Plant: the vine thickens as it passes through things — growth by
  /// feeding, gentler per bite than a doubling and compounding over more.
  static void growPlantVine(Projectile p) {
    if (p.radiusMultiplier >= kManePlantMaxRadius) return;
    p.damage *= 1.55;
    p.radiusMultiplier = min(p.radiusMultiplier * 1.42, kManePlantMaxRadius);
    p.visualScale = min(p.visualScale * 1.42, kManePlantMaxVisual);
    p.effectRadius = min(p.effectRadius * 1.30, 320);
    // A thicker vine holds what it catches for longer.
    p.snareRadius = min(p.snareRadius * 1.18, 300);
  }

  /// Poison: each pierce stacks poison on the body (to 8), and the stacked
  /// hit lands harder per stack (1× at one, +20% each after). Returns the
  /// body's new stack count and the multiplier for this hit.
  static (int, double) poisonStackStep(int stacks) {
    final next = (stacks + 1).clamp(0, 8);
    return (next, 1.0 + (next - 1) * 0.20);
  }

  /// Blood: every pierce restores this much to what the cast protects.
  static int bloodPierceHeal(Projectile p) => max(2, (p.damage * 0.10).round());

  /// Dark: pierced bodies at or under this share of their health are eaten.
  static const double darkExecuteFraction = 0.18;

  /// Air: how far a pierced body is thrown along the shot, the shove it
  /// keeps, and the slow it is left with.
  static double airPushDistance(Projectile p) =>
      max(95.0, p.effectPower * 0.72).clamp(95.0, 180.0).toDouble();
  static const double airShoveSpeed = 170.0;
  static const double airSlow = 0.68;
  static double airSlowDuration(Projectile p) =>
      max(0.45, p.effectDuration * 0.35);

  /// Water (and any carry): how far a pierced body is dragged along the shot
  /// and the slow it is left with.
  static bool isWaterWall(Projectile p) =>
      p.abilityFamily == 'mane' && p.element == 'Water';
  static double waterWallDrag(Projectile p) =>
      max(120.0, p.effectPower * 0.85).clamp(120.0, 190.0).toDouble();
  static const double waterWallSlow = 0.38;
  static const double carrySlow = 0.55;
  static const double waterWallExtraSlowTime = 0.8;

  /// Crystal: the catapult shatters on a boss, stripping its shield, and the
  /// burst hits everything round it for this share of the shot.
  static const double crystalBossBlastRadius = 240.0;
  static const double crystalBossBlastShare = 3.0;
}

/// Mane+Light: the ward. Nothing is thrown — the cast hangs a ring round the
/// caster, then another, up to what its Beauty holds, and every cast after
/// that feeds one ring a rung up its size ladder, cycling outermost first,
/// for up to [kManeLightMaxGrowth] feedings.
abstract final class ManeLightWard {
  /// [slot]'s live rings, outermost first.
  static List<Projectile> rings(Iterable<Projectile> projectiles, int? slot) {
    final rings = projectiles
        .where(
          (p) =>
              p.abilityFamily == 'mane' &&
              p.element == 'Light' &&
              p.sourceSlotIndex == slot &&
              p.holdOrbit &&
              p.life > 0 &&
              // A ring that left to become a circuit (survival's Endless
              // Circuit) is no longer part of the ward, so the ward hangs a
              // replacement rather than counting it.
              !p.masteryNoLifetime,
        )
        .toList();
    rings.sort((a, b) => b.orbitRadius.compareTo(a.orbitRadius));
    return rings;
  }

  /// One cast. Returns the ring to hang (the host adds it and sparks the
  /// caster), or the ring it fed in place and the burst radius to play
  /// there, and the caster's growth count after the cast.
  static ({Projectile? hung, Projectile? fed, double burstRadius, int growth})
  cast({
    required List<Projectile> rings,
    required int ringCap,
    required int growth,
    required Offset casterPos,
    required double casterAngle,
    required Projectile template,
    int? slot,
  }) {
    // The ladder is an average Mane's; the caster's size scale (its cast's
    // radius over the authored one) widens every rung. Rings never moved with
    // any stat before.
    final reach = (template.effectRadius / kManeLightWardEffectRadius)
        .clamp(1.0, kAbilityReachCeiling)
        .toDouble();
    if (rings.length < ringCap) {
      // Every ring is born at level 0 however far along the ward is.
      final index = rings.length;
      return (
        hung: Projectile(
          position:
              casterPos +
              Offset(cos(casterAngle), sin(casterAngle)) *
                  kManeLightOrbitRadii[index],
          angle: casterAngle,
          element: 'Light',
          // Damage, effect power and the rest come from the authored cast,
          // so stat scaling still reaches the ward.
          damage: template.damage,
          life: template.life,
          speedMultiplier: 0,
          radiusMultiplier: kManeLightRadiusByLevel.first * reach,
          visualScale: kManeLightVisualByLevel.first * reach,
          piercing: true,
          visualStyle: ProjectileVisualStyle.slash,
          sourceSlotIndex: slot,
          abilityFamily: 'mane',
          orbitCenter: casterPos,
          orbitAngle: casterAngle,
          orbitRadius: kManeLightOrbitRadii[index],
          orbitSpeed: kManeLightOrbitSpeeds[index],
          holdOrbit: true,
          followSourceCompanion: true,
          pierceEffect: template.pierceEffect,
          effectPower: template.effectPower,
          effectRadius: template.effectRadius,
          effectDuration: template.effectDuration,
        ),
        fed: null,
        burstRadius: 0.0,
        growth: growth,
      );
    }
    if (growth >= kManeLightMaxGrowth || rings.isEmpty) {
      return (hung: null, fed: null, burstRadius: 0.0, growth: growth);
    }
    // Which ring eats this cast, cycling outward-in over the rings this ward
    // actually has.
    final turn = growth % rings.length;
    final ring = rings[turn];
    final level = (ring.effectStacks + 1).clamp(
      0,
      kManeLightVisualByLevel.length - 1,
    );
    // The ring keeps the reach it was hung with: its size over its rung.
    final ringReach =
        ring.radiusMultiplier /
        kManeLightRadiusByLevel[ring.effectStacks.clamp(
          0,
          kManeLightRadiusByLevel.length - 1,
        )];
    ring.effectStacks = level;
    ring.visualScale = kManeLightVisualByLevel[level] * ringReach;
    ring.radiusMultiplier = kManeLightRadiusByLevel[level] * ringReach;
    ring.damage *= 1.42;
    ring.effectRadius = min(ring.effectRadius * 1.24, 300);
    // Feeding renews the ward as well as growing it.
    ring.life = max(ring.life, 26.0);
    return (
      hung: null,
      fed: ring,
      burstRadius: 28.0 + level * 10.0,
      growth: growth + 1,
    );
  }
}
