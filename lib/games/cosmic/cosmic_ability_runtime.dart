import 'dart:math';
import 'dart:ui' show Offset;

import 'cosmic_data.dart';

enum CosmicAbilityMode { openSpace, survival }

class CosmicAbilityRuntime {
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
    p.position =
        p.skyfallImpact - Offset(cos(p.angle), sin(p.angle)) * height;
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
