import 'dart:math';

import 'cosmic_data.dart';

enum CosmicAbilityMode { openSpace, survival }

class CosmicAbilityRuntime {
  static bool isLetMeteorCore(Projectile projectile) =>
      projectile.visualStyle == ProjectileVisualStyle.meteor;

  static bool letMeteorCanSpawnPersistentZones(Projectile projectile) =>
      isLetMeteorCore(projectile);

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
