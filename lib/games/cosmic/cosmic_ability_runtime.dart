import 'dart:math';
import 'dart:ui' show Offset;

import 'cosmic_data.dart';

enum CosmicAbilityMode { openSpace, survival }

/// One kind of ground a Let leaves behind: what it does, how wide, how long.
///
/// Survival's numbers, held in one place. Open space used to carry its own
/// copies and they drifted — Steam's vent ran 8s instead of 12, Plant rooted
/// instead of cutting — so all three games now spawn from this.
class LetZoneSpec {
  const LetZoneSpec({
    required this.tick,
    required this.radius,
    required this.duration,
    this.damageShare = 0,
    this.effectShare = 0,
    this.visualScale = 1.35,
  });

  final AbilityEffectKind tick;
  final double radius;
  final double duration;

  /// Tick power as a share of the meteor's damage...
  final double damageShare;

  /// ...or, when [damageShare] is 0, of its effect power.
  final double effectShare;
  final double visualScale;

  double power(Projectile meteor) => damageShare > 0
      ? meteor.damage * damageShare
      : meteor.effectPower * effectShare;
}

class CosmicAbilityRuntime {
  /// The ground a Let leaves where it COLLIDES — the board's "if collides"
  /// half. Null for elements whose contact effect leaves nothing behind.
  static LetZoneSpec? letContactZone(String? element) => switch (element) {
    'Dust' => const LetZoneSpec(
      tick: AbilityEffectKind.slow,
      radius: 130,
      duration: 4.5,
      effectShare: 0.25,
    ),
    'Lava' => const LetZoneSpec(
      tick: AbilityEffectKind.burn,
      radius: 145,
      duration: 4.2,
      damageShare: 0.13,
    ),
    'Poison' => const LetZoneSpec(
      tick: AbilityEffectKind.poison,
      radius: 116,
      duration: 3.8,
      damageShare: 0.08,
      visualScale: 1.9,
    ),
    'Earth' => const LetZoneSpec(
      tick: AbilityEffectKind.stun,
      radius: 128,
      duration: 3.2,
      damageShare: 0.10,
      visualScale: 1.55,
    ),
    _ => null,
  };

  /// The ground a Let leaves where it KILLS — the board's "if kills" half.
  /// Plant is not here: its vines are traps, not a zone (see [letVineSpots]).
  static LetZoneSpec? letKillZone(String? element) => switch (element) {
    'Light' => const LetZoneSpec(
      tick: AbilityEffectKind.zoneHeal,
      radius: 130,
      duration: 5.5,
      damageShare: 0.16,
      visualScale: 1.7,
    ),
    'Steam' => const LetZoneSpec(
      tick: AbilityEffectKind.geyser,
      radius: 115,
      duration: 12.0,
      damageShare: 0.12,
      visualScale: 1.6,
    ),
    'Mud' => const LetZoneSpec(
      tick: AbilityEffectKind.stun,
      radius: 130,
      duration: 4.8,
      damageShare: 0.08,
      visualScale: 1.5,
    ),
    _ => null,
  };

  /// Plant's kill: vines grow round the kill and wait. Per the board they
  /// "remain until an enemy collides with them" and "do damage" — each one is
  /// a trap that strikes the first body to come within [kLetVineReach] and is
  /// spent doing it.
  ///
  /// This replaced four overlapping 30-second damage fields. They sat almost
  /// on top of one another, so a body in the middle took four ticks every
  /// 0.35s and the kill left what was really one very strong damage zone.
  static const int kLetVineCount = 5;
  static const double kLetVineReach = 34.0;

  /// "Until an enemy collides" needs some ceiling so an unvisited corner of
  /// the arena does not collect vines forever.
  static const double kLetVineLife = 30.0;

  /// What one vine strikes for, as a share of the meteor's damage.
  static const double kLetVineDamageShare = 0.45;

  /// Where the vines grow: a ring round the kill, far enough apart that no
  /// two reaches overlap, turned by the cast so repeat kills do not stamp the
  /// same pattern.
  static List<Offset> letVineSpots(Offset centre, double angle) => [
    for (var i = 0; i < kLetVineCount; i++)
      centre +
          Offset(
                cos(angle + i * pi * 2 / kLetVineCount),
                sin(angle + i * pi * 2 / kLetVineCount),
              ) *
              (82.0 + (i.isEven ? 10.0 : 0.0)),
  ];

  static bool isLetVine(Projectile p) =>
      p.abilityFamily == 'let' &&
      p.stationary &&
      p.element == 'Plant' &&
      p.visualStyle == ProjectileVisualStyle.letShard;

  /// A vine, ready to be placed at [at]. Its strike is carried in
  /// [Projectile.effectPower]; [Projectile.damage] stays 0 so the ordinary
  /// contact pass never bills a body for touching it.
  static Projectile letVine(Projectile meteor, Offset at) => Projectile(
    position: at,
    angle: 0,
    element: 'Plant',
    damage: 0,
    life: kLetVineLife,
    speedMultiplier: 0,
    stationary: true,
    piercing: true,
    // Let ground never collides, so the only thing still reading this is
    // survival's viewport cull — sized to the art so it does not pop out
    // at the screen edge.
    radiusMultiplier: 5.5,
    visualScale: 1.2,
    visualStyle: ProjectileVisualStyle.letShard,
    sourceSlotIndex: meteor.sourceSlotIndex,
    abilityFamily: 'let',
    effectPower: meteor.damage * kLetVineDamageShare,
    effectRadius: kLetVineReach,
    effectDuration: kLetVineLife,
  );

  /// A zone from [spec], ready to be placed at [at].
  static Projectile letZone(
    Projectile meteor,
    Offset at,
    String element,
    LetZoneSpec spec,
  ) => Projectile(
    position: at,
    angle: 0,
    element: element,
    damage: 0,
    life: spec.duration,
    speedMultiplier: 0,
    stationary: true,
    piercing: true,
    // Only survival's viewport cull reads this now (see [letVine]); sized so
    // a zone whose centre is just off screen is still drawn.
    radiusMultiplier: spec.radius / 7.0,
    visualScale: spec.visualScale,
    visualStyle: ProjectileVisualStyle.letShard,
    sourceSlotIndex: meteor.sourceSlotIndex,
    abilityFamily: 'let',
    tickEffect: spec.tick,
    effectPower: spec.power(meteor),
    effectRadius: spec.radius,
    effectDuration: spec.duration,
  );

  /// How far Air's knockback reaches, and Water's and Fire's second hits —
  /// the radii the aftermath beats are drawn to.
  static double letAirReach(Projectile p) => max(180.0, p.effectRadius);
  static double letWaterReach(Projectile p) => max(125.0, p.effectRadius);
  static double letFireReach(Projectile p) => max(555.0, p.effectRadius * 3.0);

  /// How long Ice's freeze and Crystal's slow hold the body they struck.
  static const double kLetIceHold = 3.2;
  static const double kLetCrystalHold = 3.5;

  static bool isLetMeteorCore(Projectile projectile) =>
      projectile.visualStyle == ProjectileVisualStyle.meteor;

  static bool letMeteorCanSpawnPersistentZones(Projectile projectile) =>
      isLetMeteorCore(projectile);

  /// Walks a descending Let meteor one frame down its drop line. Returns true
  /// on the single frame it touches down, which is the caller's cue to
  /// detonate it.
  ///
  /// The descent is parametric rather than simulated: the meteor's height
  /// above the impact point is a function of how much of [Projectile
  /// .skyfallDuration] is left, so it lands exactly on time at exactly
  /// [Projectile.skyfallImpact]. A velocity-driven fall can overshoot or
  /// arrive early, and a Let that lands somewhere other than where its
  /// telegraph promised is worse than one that never moved.
  ///
  /// [liveTarget] is the locked enemy's current position, or null once that
  /// enemy is gone. While it is supplied the impact point tracks it, tightly
  /// enough that an enemy cannot walk out from under the drop. That is
  /// deliberate: choosing where and when to drop a meteor is the decision,
  /// and making the player also lead a moving target would turn it into a
  /// reflex test.
  static bool advanceSkyfall(Projectile p, double dt, Offset? liveTarget) {
    if (p.skyfallDuration <= 0 || p.skyfallRemaining <= 0) return false;

    if (liveTarget != null) {
      // Tracking tightens as the meteor closes, so the trajectory reads as
      // committed early and unmissable late. A constant rate either looks
      // like the rock is steering itself, or lets a fast enemy escape.
      final closing = 1.0 - p.skyfallRemaining / p.skyfallDuration;
      final pull = ((0.18 + 0.82 * closing) * dt * 12.0).clamp(0.0, 1.0);
      p.skyfallImpact = Offset.lerp(p.skyfallImpact, liveTarget, pull)!;
    }

    p.skyfallRemaining = max(0.0, p.skyfallRemaining - dt);
    final remaining = p.skyfallRemaining / p.skyfallDuration;
    // Height is the square of time-remaining, so the meteor creeps at the top
    // of its arc and slams through the last stretch. Linear descent reads as
    // a lift, not a fall.
    final height = p.skyfallDistance * remaining * remaining;
    p.position = p.skyfallImpact - Offset(cos(p.angle), sin(p.angle)) * height;
    return p.skyfallRemaining <= 0;
  }

  static int darkLetFollowupCount(double casterIntelligence) {
    return (2 + ((casterIntelligence - 0.5) / 4.5) * 3)
        .round()
        .clamp(2, 5)
        .toInt();
  }

  static double projectileEffectPower(
    Projectile projectile, {
    double fallbackMultiplier = 0.35,
    double fallbackPower = 4.0,
  }) {
    if (projectile.effectPower > 0) return projectile.effectPower;
    final fromDamage = projectile.damage * fallbackMultiplier;
    return fromDamage > 0 ? fromDamage : fallbackPower;
  }

  static double projectileEffectRadius(
    Projectile projectile, {
    double fallbackRadius = 80.0,
  }) {
    return projectile.effectRadius > 0
        ? projectile.effectRadius
        : fallbackRadius;
  }

  static double projectileEffectDuration(
    Projectile projectile, {
    double fallbackDuration = 1.5,
  }) {
    return projectile.effectDuration > 0
        ? projectile.effectDuration
        : fallbackDuration;
  }

  static bool isCrowdControl(AbilityEffectKind effect) {
    return switch (effect) {
      AbilityEffectKind.slow ||
      AbilityEffectKind.root ||
      AbilityEffectKind.freeze ||
      AbilityEffectKind.stun ||
      AbilityEffectKind.suppressShooting => true,
      _ => false,
    };
  }

  /// Whether an effect still means something when its target is already dead.
  ///
  /// A KILL effect resolves against an enemy that has just died — that is what
  /// makes it a kill effect. The survival handler opened with a blanket
  /// `if (enemy.isDead) return`, so every kill effect routed through it was
  /// dropped on arrival: Pip+Blood and Pip+Light's heals, Plant's alchemy
  /// bonus, Water's splash, Crystal's taunt.
  ///
  /// Effects that change the enemy's own STATE — slowing it, freezing it,
  /// burning it — genuinely have nothing to do on a corpse and stay blocked.
  /// Effects that heal the caster, feed the orb, or act on the world around
  /// the kill do not care whether the body is still standing.
  static bool resolvesOnDeadTarget(AbilityEffectKind effect) {
    return switch (effect) {
      AbilityEffectKind.leech ||
      AbilityEffectKind.zoneHeal ||
      AbilityEffectKind.buff ||
      AbilityEffectKind.cooldownRefund ||
      AbilityEffectKind.alchemyBonus ||
      AbilityEffectKind.flower ||
      AbilityEffectKind.splash ||
      AbilityEffectKind.blackHole ||
      AbilityEffectKind.taunt => true,
      _ => false,
    };
  }

  static bool isDirectDamage(AbilityEffectKind effect) {
    return switch (effect) {
      AbilityEffectKind.burn ||
      AbilityEffectKind.poison ||
      AbilityEffectKind.zoneDamage ||
      AbilityEffectKind.geyser ||
      AbilityEffectKind.refraction ||
      AbilityEffectKind.chargeBlast ||
      AbilityEffectKind.execute => true,
      _ => false,
    };
  }

  static double directDamageForEffect(
    AbilityEffectKind effect, {
    required double power,
    required double targetHp,
    required double targetHpFraction,
  }) {
    if (effect == AbilityEffectKind.execute && targetHpFraction <= 0.20) {
      return targetHp + 1;
    }
    if (effect == AbilityEffectKind.execute) return power * 1.35;
    if (effect == AbilityEffectKind.chargeBlast) return power * 2.8;
    return power;
  }

  static double splashMultiplier(AbilityEffectKind effect) {
    return effect == AbilityEffectKind.chain ? 0.72 : 0.55;
  }

  static double openSpaceCrowdControlDuration(double duration) {
    if (duration >= 30) return duration.clamp(0.4, 60.0);
    return duration.clamp(0.4, 3.2);
  }

  static double openSpaceCrowdControlSpeedMultiplier(AbilityEffectKind effect) {
    return switch (effect) {
      AbilityEffectKind.freeze => 0.05,
      AbilityEffectKind.root => 0.18,
      AbilityEffectKind.stun => 0.12,
      AbilityEffectKind.suppressShooting => 0.72,
      _ => 0.72,
    };
  }

  static double survivalSlowMultiplier(AbilityEffectKind effect) {
    return switch (effect) {
      AbilityEffectKind.freeze => 0.05,
      AbilityEffectKind.root => 0.0,
      AbilityEffectKind.stun => 0.08,
      AbilityEffectKind.suppressShooting => 0.72,
      _ => 0.45,
    };
  }

  static double survivalCrowdControlDuration(
    AbilityEffectKind effect,
    double duration,
  ) {
    final base = duration > 0 ? duration : 1.5;
    return effect == AbilityEffectKind.stun ? base * 0.7 : base;
  }

  static double maneCarryDistance(double effectPower) {
    return max(28.0, effectPower * 0.15).clamp(28.0, 64.0).toDouble();
  }

  static bool isSurvivalOnlyEffect(AbilityEffectKind effect) {
    return switch (effect) {
      AbilityEffectKind.alchemyBonus || AbilityEffectKind.flower => true,
      _ => false,
    };
  }
}
