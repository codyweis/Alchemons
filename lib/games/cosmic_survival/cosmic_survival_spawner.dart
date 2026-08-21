// lib/games/cosmic_survival/cosmic_survival_spawner.dart
//
// COSMIC SURVIVAL WAVE SPAWNER
// Endless waves of cosmic enemy types that scale in count, HP, speed, and tier.
// Boss encounters at milestone waves (every 5 waves).

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'dart:ui';

import 'package:alchemons/games/shared/enemy_movement.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_balance.dart';
import 'package:alchemons/games/shared/enemy_flight_steering.dart';

enum CosmicEnemyRole { striker, orbiter, shooter, hunter }

enum CosmicEnemyTarget { orb, ship, companion }

enum SurvivalEnemyVariant {
  standard,
  orbBreaker,
  siegeShooter,
  crusher,
  pouncer,
  // Periodically summons a small swarm of wisps while alive.
  summoner,
  // On death, bursts into multiple fast pouncer drones.
  splitter,
}

enum SurvivalBossDiscipline {
  standard,
  artillery,
  trickster,
  duelist,
  conductor,
  siegebreaker,
  riftcaller,
}

/// How a boss prefers to move relative to the orb / player.
/// - [chase]: closes the gap, brawler. Old default.
/// - [orbit]: holds a medium-far ring and strafes around it.
/// - [sniper]: hangs back near the arena edge and fires from range.
enum SurvivalBossMovementStyle { chase, orbit, sniper }

enum SurvivalWavePattern {
  mixed,
  wispHorde,
  hunterPack,
  siegePush,
  shooterScreen,
  swarmRush,
}



enum SurvivalWaveMutator {
  orbSiege,
  hunterSwarm,
  arcStorm,
  fortified,
  shatteredSpace,
  manaFlux,
}

// ──────────────────────────────────────────────────────────────────────────────
// SURVIVAL ENEMY (uses same EnemyTier as cosmic game)
// ──────────────────────────────────────────────────────────────────────────────

class CosmicSurvivalEnemy {
  Offset position;
  Offset knockbackVelocity;
  double angle;
  double hp;
  final double maxHp;
  final double speed;
  final double damage;
  final double radius;
  final EnemyTier tier;
  final String element;
  final CosmicEnemyRole role;
  final SurvivalEnemyVariant variant;

  /// Converged taxonomy (docs/enemy_taxonomy.md). Derived from role+variant
  /// during migration; once the spawner picks these directly, role and variant
  /// go away.
  final EnemyConduct conduct;
  final EnemyTrait? trait;
  CosmicEnemyTarget target;
  bool isDead;
  double hitFlash;
  double slowTimer;
  double slowMultiplier;
  double attackCooldown;
  double retargetTimer;
  final bool isElite;
  final EliteAffix? eliteAffix;
  // Mane+Plant pierce sets this to the source slot index. If the
  // enemy dies while still flagged, the resolver triggers an AOE
  // explosion at the kill site.
  int? maneRootSlot;
  double maneRootTimer;
  // Pip+Mud hit sets this to true so the enemy permanently leaves
  // mud trail puffs that slow other enemies behind it.
  bool pipMudTrail;
  double pipMudTrailTimer;
  // Wing+Dust disorient: while > 0, shooter-role enemies target
  // other enemies instead of the orb/ship.
  double disorientTimer;
  // Horn+Plant per-enemy root: while > 0, the enemy is rooted in
  // place and wears a green vine-wrap visual. Set by Plant horn's
  // charge-sweep hits.
  double hornPlantRootTimer;
  // Mane+Poison stacking damage: every pierce by the mane Poison
  // catapult increments this; persistent poison DoT scales with
  // the stack count so chained pierces hit harder.
  int manePoisonStacks;
  // Wing+Ice frost buildup: a sustained ice beam ramps this from 0→1;
  // at 1 the enemy snaps into a hard freeze and it resets.
  double frostBuildup;
  // Summoner-variant cooldown. >0 means "ready to summon in X seconds".
  double summonCooldown;
  // Mask+Blood permanent drain: enemies that pass through the blood
  // blob are tagged here with the source slot. Per-frame drain pulls
  // HP from them and splits it as healing across all allies until the
  // enemy dies. Cleared on death.
  int? maskBloodDrainSlot;
  // Shared hover/dive steering state (lazily created by whichever mode is
  // driving this enemy). See games/shared/enemy_flight_steering.dart.
  FlightSteeringState? flightSteering;

  CosmicSurvivalEnemy({
    required this.position,
    this.knockbackVelocity = Offset.zero,
    this.angle = 0,
    required this.hp,
    required this.maxHp,
    required this.speed,
    required this.damage,
    required this.radius,
    required this.tier,
    required this.element,
    required CosmicEnemyRole role,
    SurvivalEnemyVariant variant = SurvivalEnemyVariant.standard,
    EnemyConduct? conduct,
    EnemyTrait? trait,
    required this.target,
    this.isDead = false,
    this.hitFlash = 0,
    this.slowTimer = 0,
    this.slowMultiplier = 0.5,
    this.attackCooldown = 0,
    this.retargetTimer = 0,
    this.isElite = false,
    this.eliteAffix,
    this.maneRootSlot,
    this.maneRootTimer = 0,
    this.pipMudTrail = false,
    this.pipMudTrailTimer = 0,
    this.disorientTimer = 0,
    this.hornPlantRootTimer = 0,
    this.manePoisonStacks = 0,
    this.frostBuildup = 0,
    this.summonCooldown = 0,
    this.maskBloodDrainSlot,
  }) : // Not initializing formals: role and variant must be in scope here so
       // conduct and trait can be derived from them below.
       // ignore: prefer_initializing_formals
       role = role,
       // ignore: prefer_initializing_formals
       variant = variant,
       // Derived, not stored twice: one place decides what the old pair means
       // under the new taxonomy.
       // The spawner may pick these directly; otherwise they are derived from
       // the legacy pair while the migration finishes.
       conduct = conduct ?? conductFromRoleVariant(role, variant),
       trait = trait ?? traitFromVariant(variant);

  double get hpFraction => maxHp > 0 ? (hp / maxHp).clamp(0, 1) : 0;
  /// True for bodies heavy enough to earn the charge speed bonus that the old
  /// `crusher` variant used to smuggle into its movement vector.
  bool get hasHeavyBody =>
      tier == EnemyTier.brute || tier == EnemyTier.colossus;

  double get effectiveSpeed {
    if (maneRootTimer > 0 ||
        hornPlantRootTimer > 0 ||
        slowMultiplier <= 0) {
      return 0;
    }
    // The crusher's old `* 1.08` lived in the direction vector, which made a
    // stat look like a steering rule. It is an explicit speed term now.
    final conductBonus = conductSpeedMultiplier(
      conduct,
      heavyBody: hasHeavyBody,
    );
    if (slowTimer <= 0) return speed * conductBonus;
    return speed *
        conductBonus *
        (isRelentless ? max(0.78, slowMultiplier) : slowMultiplier);
  }

  bool get isShooter => role == CosmicEnemyRole.shooter;
  bool get hasBulwark => eliteAffix == EliteAffix.bulwarked;
  bool get isVolatile => eliteAffix == EliteAffix.volatile;
  bool get isVampiric => eliteAffix == EliteAffix.vampiric;
  bool get isOverclocked => eliteAffix == EliteAffix.overclocked;
  bool get isRelentless => eliteAffix == EliteAffix.relentless;
}

// ──────────────────────────────────────────────────────────────────────────────
// SURVIVAL BOSS
// ──────────────────────────────────────────────────────────────────────────────

class SurvivalBoss {
  final BossTemplate template;
  final BossType type;
  final SurvivalBossDiscipline discipline;
  final int level;
  Offset position;
  double angle;
  double hp;
  final double maxHp;
  double speed;
  final double baseSpeed;
  final double radius;
  final Color color;
  bool isDead;
  double hitFlash;
  double phaseTimer;

  // Charger state
  bool charging;
  double chargeTimer;
  double chargeAngle;
  double chargeDashTimer;

  // Gunner state
  double shootTimer;
  bool shieldUp;
  double shieldHealth;
  double shieldTimer;

  // Carrier state
  double escortTimer;

  // Warden state
  double spreadTimer;
  double summonTimer;
  bool enraged;
  double spawnIntroTimer;
  double spawnIntroDuration;
  Offset? spawnFromPosition;
  Offset? spawnTargetPosition;

  // Titanic trait state
  double colossalTraitTimer;
  double colossalTraitAuxTimer;

  // Movement profile chosen at spawn — drives whether the boss chases,
  // strafes a ring, or sits back firing.
  final SurvivalBossMovementStyle movementStyle;
  /// Preferred distance the boss tries to hold from its anchor target.
  /// Each AI uses this as the radial setpoint instead of a hardcoded value.
  final double engagementRange;
  /// 0..1 — how aggressively the boss tangentially strafes its ring.
  /// Snipers ≈ 0.15 (mostly still), orbiters ≈ 0.7, chasers ≈ 1.0.
  final double strafeWeight;

  // Constants
  static const double chargeCooldown = 3.0;
  static const double chargeDashDuration = 0.6;
  static const double chargeSpeedMultiplier = 3.0;
  static const double shootCooldown = 1.5;
  static const double shieldCooldown = 8.0;
  static const double shieldDuration = 4.0;
  static const double shieldMaxHealth = 50.0;
  static const double escortCooldown = 10.0;
  static const double spreadCooldown = 2.5;
  static const double summonCooldown = 12.0;
  static const double enrageThreshold = 0.3;

  SurvivalBoss({
    required this.template,
    required this.type,
    this.discipline = SurvivalBossDiscipline.standard,
    required this.level,
    required this.position,
    this.angle = 0,
    required this.hp,
    required this.maxHp,
    required this.speed,
    required this.baseSpeed,
    required this.radius,
    required this.color,
    this.isDead = false,
    this.hitFlash = 0,
    this.phaseTimer = 0,
    this.charging = false,
    this.chargeTimer = 1.0, // first charge comes quickly
    this.chargeAngle = 0,
    this.chargeDashTimer = 0,
    this.shootTimer = 0.5, // fire soon after spawn
    this.shieldUp = false,
    this.shieldHealth = 0,
    this.shieldTimer = shieldCooldown,
    this.escortTimer = escortCooldown,
    this.spreadTimer = 1.0, // spread soon after spawn
    this.summonTimer = summonCooldown,
    this.enraged = false,
    this.spawnIntroTimer = 0,
    this.spawnIntroDuration = 1.2,
    this.spawnFromPosition,
    this.spawnTargetPosition,
    this.colossalTraitTimer = 0,
    this.colossalTraitAuxTimer = 0,
    this.movementStyle = SurvivalBossMovementStyle.chase,
    this.engagementRange = 220.0,
    this.strafeWeight = 0.8,
  });

  double get hpFraction => maxHp > 0 ? (hp / maxHp).clamp(0, 1) : 0;
  bool get isSpawning => spawnIntroTimer > 0;
}

// ──────────────────────────────────────────────────────────────────────────────
// BOSS PROJECTILE
// ──────────────────────────────────────────────────────────────────────────────

class SurvivalBossProjectile {
  Offset position;
  final double angle;
  final String element;
  final double damage;
  final double speed;
  double life;
  final double radius;

  SurvivalBossProjectile({
    required this.position,
    required this.angle,
    required this.element,
    required this.damage,
    this.speed = 250,
    this.life = 4.0,
    this.radius = 5.0,
  });
}

class SurvivalEnemyProjectile {
  Offset position;
  // Non-final so Horn+Ice walls and Horn+Light barriers can reflect
  // the projectile (mutates angle to point back at the firer side).
  double angle;
  final String element;
  final double damage;
  final double speed;
  double life;
  final double radius;
  final CosmicEnemyTarget target;
  // Wing+Dust disorient: when true, this enemy projectile damages
  // other enemies on collision instead of the orb/ship/companions.
  // Also flipped to true by Horn+Ice / Horn+Light reflects.
  bool friendlyFire;

  SurvivalEnemyProjectile({
    required this.position,
    required this.angle,
    required this.element,
    required this.damage,
    required this.target,
    this.speed = 220,
    this.life = 4.0,
    this.radius = 4.0,
    this.friendlyFire = false,
  });
}

// ──────────────────────────────────────────────────────────────────────────────
// TIER STAT HELPERS
// ──────────────────────────────────────────────────────────────────────────────

double tierBaseHp(EnemyTier tier) => switch (tier) {
  EnemyTier.wisp => 8,
  EnemyTier.drone => 20,
  EnemyTier.sentinel => 50,
  EnemyTier.phantom => 85,
  EnemyTier.brute => 180,
  EnemyTier.colossus => 400,
};

double tierRadius(EnemyTier tier) => switch (tier) {
  EnemyTier.wisp => 6,
  EnemyTier.drone => 10,
  EnemyTier.sentinel => 14,
  EnemyTier.phantom => 12,
  EnemyTier.brute => 20,
  EnemyTier.colossus => 28,
};

double tierBaseSpeed(EnemyTier tier) => switch (tier) {
  EnemyTier.wisp => 90,
  EnemyTier.drone => 70,
  EnemyTier.sentinel => 45,
  EnemyTier.phantom => 65,
  EnemyTier.brute => 30,
  EnemyTier.colossus => 20,
};

double tierBaseDamage(EnemyTier tier) => switch (tier) {
  EnemyTier.wisp => 2,
  EnemyTier.drone => 4,
  EnemyTier.sentinel => 7,
  EnemyTier.phantom => 10,
  EnemyTier.brute => 18,
  EnemyTier.colossus => 30,
};

int tierShardReward(EnemyTier tier) => switch (tier) {
  EnemyTier.wisp => 1,
  EnemyTier.drone => 3,
  EnemyTier.sentinel => 6,
  EnemyTier.phantom => 10,
  EnemyTier.brute => 20,
  EnemyTier.colossus => 40,
};

// ──────────────────────────────────────────────────────────────────────────────
// ELEMENTS (for random assignment)
// ──────────────────────────────────────────────────────────────────────────────

const _kElements = [
  'Fire',
  'Lava',
  'Lightning',
  'Water',
  'Ice',
  'Steam',
  'Earth',
  'Mud',
  'Dust',
  'Crystal',
  'Air',
  'Plant',
  'Poison',
  'Spirit',
  'Dark',
  'Light',
  'Blood',
];

// ──────────────────────────────────────────────────────────────────────────────
// WAVE SPAWNER
// ──────────────────────────────────────────────────────────────────────────────

class CosmicSurvivalSpawner {
  static const double earlyAdvanceKillThreshold = 0.90;

  final Random _rng = Random();
  final List<String> _recentBossNames = <String>[];
  final List<String> _recentBossElements = <String>[];

  int currentWave = 0;
  bool intermission = false;
  bool isBossWave = false;
  bool bossSpawned = false;
  SurvivalWavePattern currentPattern = SurvivalWavePattern.mixed;
  SurvivalWaveMutator? currentMutator;

  double _spawnTimer = 0;
  int _spawnedThisWave = 0;
  int _targetCountThisWave = 0;
  bool _waveActive = false;
  bool _waitingForClear = false;

  int get targetCountThisWave => _targetCountThisWave;
  int get spawnedThisWave => _spawnedThisWave;

  void startFirstWave() {
    currentWave = 0;
    _advanceWave();
  }

  /// Advances the wave without requiring the arena to be cleared. Test-only:
  /// spawn-policy tests need to reach the deep-wave trait gates.
  @visibleForTesting
  void forceNextWaveForTest() => _advanceWave();

  void _advanceWave() {
    currentWave++;
    intermission = false;
    isBossWave = isBossWaveNumber(currentWave);
    currentPattern = isBossWave
        ? SurvivalWavePattern.mixed
        : _patternForWave(currentWave);
    currentMutator = isBossWave ? null : previewMutatorForWave(currentWave);
    bossSpawned = false;
    _spawnedThisWave = 0;
    _targetCountThisWave = _enemyCountForWave(currentWave);
    _spawnTimer = 0;
    _waveActive = true;
    _waitingForClear = false;
  }

  static bool isBossWaveNumber(int wave) => wave > 0 && wave % 5 == 0;

  int _enemyCountForWave(int wave) {
    final base = (4 + wave * 1.55 + pow(wave, 1.05) * 0.40).round();
    final earlyPressureBonus = switch (wave) {
      <= 2 => 2,
      <= 4 => 3,
      <= 7 => 4,
      _ => 0,
    };
    final multiplier = switch (currentPattern) {
      SurvivalWavePattern.wispHorde => 1.35,
      SurvivalWavePattern.hunterPack => 1.10,
      SurvivalWavePattern.siegePush => 0.78,
      SurvivalWavePattern.shooterScreen => 0.92,
      SurvivalWavePattern.swarmRush => 1.24,
      SurvivalWavePattern.mixed => 1.0,
    };
    final mutatorMultiplier = switch (currentMutator) {
      SurvivalWaveMutator.orbSiege => 1.12,
      SurvivalWaveMutator.hunterSwarm => 1.08,
      SurvivalWaveMutator.arcStorm => 1.05,
      SurvivalWaveMutator.fortified => 0.94,
      SurvivalWaveMutator.shatteredSpace => 0.92,
      SurvivalWaveMutator.manaFlux => 1.0,
      null => 1.0,
    };
    return ((base + earlyPressureBonus) * multiplier * mutatorMultiplier)
        .round()
        .clamp(5, 96);
  }

  double _spawnInterval(int wave) {
    final base = (0.98 - wave * 0.017).clamp(0.20, 0.98);
    final patternInterval = switch (currentPattern) {
      SurvivalWavePattern.wispHorde => max(0.12, base * 0.45),
      SurvivalWavePattern.hunterPack => max(0.16, base * 0.72),
      SurvivalWavePattern.siegePush => min(0.88, base * 1.08),
      SurvivalWavePattern.shooterScreen => max(0.18, base * 0.76),
      SurvivalWavePattern.swarmRush => max(0.14, base * 0.58),
      SurvivalWavePattern.mixed => base,
    };
    final mutatorFactor = switch (currentMutator) {
      SurvivalWaveMutator.hunterSwarm => 0.90,
      SurvivalWaveMutator.arcStorm => 0.92,
      SurvivalWaveMutator.shatteredSpace => 0.82,
      SurvivalWaveMutator.manaFlux => 0.96,
      _ => 1.0,
    };
    return max(0.10, patternInterval * mutatorFactor);
  }

  static SurvivalWaveMutator? previewMutatorForWave(int wave) {
    if (wave < 7 || wave % 5 == 0) return null;
    if (wave >= 14 && wave % 9 == 4) return SurvivalWaveMutator.fortified;
    if (wave >= 18 && wave % 11 == 6) {
      return SurvivalWaveMutator.shatteredSpace;
    }
    if (wave >= 10 && wave % 8 == 3) return SurvivalWaveMutator.arcStorm;
    if (wave >= 8 && wave % 7 == 2) return SurvivalWaveMutator.hunterSwarm;
    if (wave >= 7 && wave % 6 == 1) return SurvivalWaveMutator.orbSiege;
    if (wave >= 14) return SurvivalWaveMutator.manaFlux;
    return null;
  }

  SurvivalWavePattern _patternForWave(int wave) {
    if (wave <= 2) return SurvivalWavePattern.mixed;
    if (wave % 9 == 0) return SurvivalWavePattern.siegePush;
    if (wave >= 8 && wave % 11 == 0) return SurvivalWavePattern.swarmRush;
    if (wave % 7 == 0) return SurvivalWavePattern.wispHorde;
    if (wave >= 10 && wave % 6 == 0) return SurvivalWavePattern.shooterScreen;
    if (wave >= 5 && wave.isOdd) {
      return _rng.nextDouble() < 0.34
          ? SurvivalWavePattern.hunterPack
          : SurvivalWavePattern.mixed;
    }
    final roll = _rng.nextDouble();
    if (roll < 0.18) return SurvivalWavePattern.wispHorde;
    if (roll < 0.32) return SurvivalWavePattern.hunterPack;
    if (wave >= 8 && roll < 0.44) return SurvivalWavePattern.swarmRush;
    if (wave >= 10 && roll < 0.58) return SurvivalWavePattern.shooterScreen;
    return SurvivalWavePattern.mixed;
  }

  EnemyTier _tierForWave(int wave) {
    if (currentMutator == SurvivalWaveMutator.fortified) {
      final roll = _rng.nextDouble();
      if (wave >= 24 && roll < 0.12) return EnemyTier.colossus;
      if (wave >= 14 && roll < 0.38) return EnemyTier.brute;
      if (roll < 0.72) return EnemyTier.sentinel;
      return EnemyTier.drone;
    }
    switch (currentPattern) {
      case SurvivalWavePattern.wispHorde:
        final roll = _rng.nextDouble();
        if (wave >= 14 && roll < 0.06) return EnemyTier.sentinel;
        if (wave >= 8 && roll < 0.26) return EnemyTier.drone;
        return EnemyTier.wisp;
      case SurvivalWavePattern.hunterPack:
        final roll = _rng.nextDouble();
        if (wave >= 18 && roll < 0.12) return EnemyTier.brute;
        if (wave >= 10 && roll < 0.34) return EnemyTier.phantom;
        if (roll < 0.74) return EnemyTier.drone;
        return EnemyTier.wisp;
      case SurvivalWavePattern.siegePush:
        final roll = _rng.nextDouble();
        if (wave >= 22 && roll < 0.16) return EnemyTier.colossus;
        if (wave >= 12 && roll < 0.42) return EnemyTier.brute;
        if (roll < 0.78) return EnemyTier.sentinel;
        return EnemyTier.drone;
      case SurvivalWavePattern.shooterScreen:
        final roll = _rng.nextDouble();
        if (wave >= 18 && roll < 0.16) return EnemyTier.brute;
        if (wave >= 10 && roll < 0.46) return EnemyTier.phantom;
        if (roll < 0.82) return EnemyTier.sentinel;
        return EnemyTier.drone;
      case SurvivalWavePattern.swarmRush:
        final roll = _rng.nextDouble();
        if (wave >= 16 && roll < 0.08) return EnemyTier.brute;
        if (wave >= 10 && roll < 0.24) return EnemyTier.phantom;
        if (wave >= 12 && roll < 0.40) return EnemyTier.sentinel;
        if (roll < 0.78) return EnemyTier.drone;
        return EnemyTier.wisp;
      case SurvivalWavePattern.mixed:
        break;
    }

    // Progressively add harder tiers
    if (wave >= 30) {
      final roll = _rng.nextDouble();
      if (roll < 0.10) return EnemyTier.colossus;
      if (roll < 0.30) return EnemyTier.brute;
      if (roll < 0.55) return EnemyTier.phantom;
      if (roll < 0.80) return EnemyTier.sentinel;
      return EnemyTier.drone;
    } else if (wave >= 20) {
      final roll = _rng.nextDouble();
      if (roll < 0.05) return EnemyTier.colossus;
      if (roll < 0.20) return EnemyTier.brute;
      if (roll < 0.45) return EnemyTier.phantom;
      if (roll < 0.75) return EnemyTier.sentinel;
      return EnemyTier.drone;
    } else if (wave >= 12) {
      final roll = _rng.nextDouble();
      if (roll < 0.10) return EnemyTier.brute;
      if (roll < 0.30) return EnemyTier.phantom;
      if (roll < 0.60) return EnemyTier.sentinel;
      return EnemyTier.drone;
    } else if (wave >= 6) {
      final roll = _rng.nextDouble();
      if (roll < 0.05) return EnemyTier.phantom;
      if (roll < 0.25) return EnemyTier.sentinel;
      if (roll < 0.60) return EnemyTier.drone;
      return EnemyTier.wisp;
    } else if (wave >= 3) {
      final roll = _rng.nextDouble();
      if (roll < 0.15) return EnemyTier.sentinel;
      if (roll < 0.45) return EnemyTier.drone;
      return EnemyTier.wisp;
    } else {
      return _rng.nextDouble() < 0.3 ? EnemyTier.drone : EnemyTier.wisp;
    }
  }

  /// Called every frame. Returns new enemies to add.
  List<CosmicSurvivalEnemy> update(
    double dt,
    int aliveCount,
    double viewW,
    double viewH,
    Offset orbPos,
  ) {
    if (!_waveActive || _waitingForClear) return const [];

    _spawnTimer += dt;
    final interval = _spawnInterval(currentWave);
    if (_spawnTimer < interval) return const [];
    _spawnTimer = 0;

    if (_spawnedThisWave >= _targetCountThisWave) {
      _waitingForClear = true;
      return const [];
    }

    final batchLimit = switch (currentPattern) {
      SurvivalWavePattern.wispHorde => 8,
      SurvivalWavePattern.hunterPack => 5,
      SurvivalWavePattern.siegePush => 3,
      SurvivalWavePattern.shooterScreen => 4,
      SurvivalWavePattern.swarmRush => 6,
      SurvivalWavePattern.mixed => 4,
    };
    final batchSize = min(batchLimit, _targetCountThisWave - _spawnedThisWave);
    final spawned = <CosmicSurvivalEnemy>[];
    for (var i = 0; i < batchSize; i++) {
      spawned.add(_spawnEnemy(viewW, viewH, orbPos));
      _spawnedThisWave++;
    }
    return spawned;
  }

  /// Rolls an optional extra mechanic. Body-independent by design.
  EnemyTrait? _traitForWave(int wave) {
    if (wave >= 14 && _rng.nextDouble() < 0.10) return EnemyTrait.splitter;
    if (wave >= 12 && _rng.nextDouble() < 0.10) return EnemyTrait.summoner;
    if (wave >= 8 && _rng.nextDouble() < 0.12) return EnemyTrait.breaker;
    return null;
  }

  /// The legacy variant, reconstructed from the new axes. Read only by code
  /// that has not migrated yet; delete with the enum.
  SurvivalEnemyVariant _variantForDisplay(
    EnemyConduct conduct,
    EnemyTrait? trait,
    CosmicEnemyRole role,
  ) {
    if (trait == EnemyTrait.summoner) return SurvivalEnemyVariant.summoner;
    if (trait == EnemyTrait.splitter) return SurvivalEnemyVariant.splitter;
    if (trait == EnemyTrait.breaker) return SurvivalEnemyVariant.orbBreaker;
    if (conduct == EnemyConduct.stalk) return SurvivalEnemyVariant.pouncer;
    if (conduct == EnemyConduct.charge &&
        role != CosmicEnemyRole.striker &&
        role != CosmicEnemyRole.hunter) {
      return SurvivalEnemyVariant.crusher;
    }
    if (role == CosmicEnemyRole.shooter) {
      return SurvivalEnemyVariant.siegeShooter;
    }
    return SurvivalEnemyVariant.standard;
  }

  CosmicSurvivalEnemy _spawnEnemy(double viewW, double viewH, Offset orbPos) {
    final tier = _tierForWave(currentWave);
    final element = _kElements[_rng.nextInt(_kElements.length)];
    final role = _roleForWave(currentWave, tier);

    // CONDUCT — how it moves. Rolled from the wave's shape, not from the body.
    // The old code derived a `variant` here and let it override the role's
    // movement; conduct is now the single authority (docs/enemy_taxonomy.md).
    var conduct = conductFromRoleVariant(role, SurvivalEnemyVariant.standard);
    if ((currentPattern == SurvivalWavePattern.siegePush ||
            currentMutator == SurvivalWaveMutator.fortified) &&
        _rng.nextDouble() < 0.34) {
      conduct = EnemyConduct.charge;
    } else if ((currentPattern == SurvivalWavePattern.hunterPack ||
            currentPattern == SurvivalWavePattern.swarmRush) &&
        _rng.nextDouble() < 0.32) {
      conduct = EnemyConduct.stalk;
    }

    // TRAIT — an extra mechanic, rolled INDEPENDENTLY of the body.
    //
    // This is the §2.4 fix. Traits used to be locked to the tier that implied
    // them: summoner only on sentinel/phantom, splitter only on
    // brute/colossus, breaker only on a heavy striker. So most of the nominal
    // combination space was unreachable by construction. Any body can now
    // carry any trait — a summoner wisp is a thing that can happen.
    final trait = _traitForWave(currentWave);

    // Legacy display/logic value, derived so the two cannot disagree while the
    // remaining consumers migrate.
    final variant = _variantForDisplay(conduct, trait, role);

    // Spawn outside view
    final margin = max(viewW, viewH) * 0.55;
    final angle = _rng.nextDouble() * 2 * pi;
    final pos = Offset(
      orbPos.dx + cos(angle) * margin,
      orbPos.dy + sin(angle) * margin,
    );

    // Elite champion chance past wave 20
    final isElite =
        currentWave >= 20 &&
        tier.index >= EnemyTier.sentinel.index &&
        _rng.nextDouble() < _eliteChance(currentWave);
    final eliteAffix = isElite
        ? rollEliteAffixForWave(currentWave, _rng)
        : null;
    final eliteMultiplier = isElite ? 2.2 : 1.0;

    final baseHp =
        tierBaseHp(tier) *
        CosmicSurvivalBalance.enemyWaveHpScale(currentWave) *
        eliteMultiplier *
        (currentMutator == SurvivalWaveMutator.fortified ? 1.12 : 1.0) *
        (currentMutator == SurvivalWaveMutator.shatteredSpace ? 0.88 : 1.0);
    final baseSpeed =
        tierBaseSpeed(tier) *
        CosmicSurvivalBalance.enemyWaveSpeedScale(currentWave) *
        (isElite ? 1.15 : 1.0) *
        (currentMutator == SurvivalWaveMutator.hunterSwarm ? 1.10 : 1.0) *
        (currentMutator == SurvivalWaveMutator.shatteredSpace ? 1.10 : 1.0) *
        (eliteAffix == EliteAffix.relentless ? 1.05 : 1.0) *
        (eliteAffix == EliteAffix.overclocked ? 1.18 : 1.0);
    final baseDamage =
        tierBaseDamage(tier) *
        CosmicSurvivalBalance.enemyWaveDamageScale(currentWave) *
        (isElite ? 1.5 : 1.0) *
        (currentMutator == SurvivalWaveMutator.orbSiege ? 1.08 : 1.0) *
        (currentMutator == SurvivalWaveMutator.shatteredSpace ? 1.10 : 1.0) *
        (eliteAffix == EliteAffix.vampiric ? 1.10 : 1.0);
    // (The old body-locked summoner/splitter roll lived here. It only ever
    // fired on sentinel/phantom and brute/colossus respectively, which is the
    // unreachable-combination problem; _traitForWave replaces it and is rolled
    // above, independent of tier.)

    final variantHpMult = switch (variant) {
      SurvivalEnemyVariant.orbBreaker => 1.22,
      SurvivalEnemyVariant.siegeShooter => 0.92,
      SurvivalEnemyVariant.crusher => 1.38,
      SurvivalEnemyVariant.pouncer => 0.88,
      SurvivalEnemyVariant.summoner => 1.15,
      SurvivalEnemyVariant.splitter => 1.05,
      SurvivalEnemyVariant.standard => 1.0,
    };
    final variantSpeedMult = switch (variant) {
      SurvivalEnemyVariant.orbBreaker => 0.84,
      SurvivalEnemyVariant.siegeShooter => 0.95,
      SurvivalEnemyVariant.crusher => 0.76,
      SurvivalEnemyVariant.pouncer => 1.22,
      SurvivalEnemyVariant.summoner => 0.78,
      SurvivalEnemyVariant.splitter => 0.82,
      SurvivalEnemyVariant.standard => 1.0,
    };
    final variantDamageMult = switch (variant) {
      SurvivalEnemyVariant.orbBreaker => 1.2,
      SurvivalEnemyVariant.siegeShooter => 1.16,
      SurvivalEnemyVariant.crusher => 1.26,
      SurvivalEnemyVariant.pouncer => 1.10,
      SurvivalEnemyVariant.summoner => 1.00,
      SurvivalEnemyVariant.splitter => 1.18,
      SurvivalEnemyVariant.standard => 1.0,
    };

    return CosmicSurvivalEnemy(
      position: pos,
      angle: angle + pi,
      hp: baseHp * variantHpMult,
      maxHp: baseHp * variantHpMult,
      speed: baseSpeed * variantSpeedMult,
      damage: baseDamage * variantDamageMult,
      radius: tierRadius(tier) * (isElite ? 1.3 : 1.0),
      tier: tier,
      element: element,
      role: role,
      variant: variant,
      // Picked directly, not derived — the whole point of the change.
      conduct: conduct,
      trait: trait,
      target: _initialTargetForRole(role),
      isElite: isElite,
      eliteAffix: eliteAffix,
      summonCooldown: variant == SurvivalEnemyVariant.summoner
          ? 5.0 + _rng.nextDouble() * 2.0
          : 0,
    );
  }

  /// Spawn the small swarm a summoner produces. Returned enemies should be
  /// appended to the game's main enemy list.
  List<CosmicSurvivalEnemy> spawnSummonerWisps(
    CosmicSurvivalEnemy parent, {
    int? count,
  }) {
    final out = <CosmicSurvivalEnemy>[];
    final addCount = count ?? (2 + _rng.nextInt(2));
    for (var i = 0; i < addCount; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final dist = parent.radius + 14.0;
      final pos = Offset(
        parent.position.dx + cos(angle) * dist,
        parent.position.dy + sin(angle) * dist,
      );
      const tier = EnemyTier.wisp;
      final hp =
          tierBaseHp(tier) *
          CosmicSurvivalBalance.enemyWaveHpScale(currentWave) *
          0.85;
      out.add(
        CosmicSurvivalEnemy(
          position: pos,
          angle: angle,
          hp: hp,
          maxHp: hp,
          speed:
              tierBaseSpeed(tier) *
              CosmicSurvivalBalance.enemyWaveSpeedScale(currentWave) *
              1.1,
          damage:
              tierBaseDamage(tier) *
              CosmicSurvivalBalance.enemyWaveDamageScale(currentWave),
          radius: tierRadius(tier),
          tier: tier,
          element: parent.element,
          role: CosmicEnemyRole.striker,
          variant: SurvivalEnemyVariant.standard,
          target: CosmicEnemyTarget.orb,
        ),
      );
    }
    return out;
  }

  /// Spawn the fast pouncer adds a splitter releases when it dies.
  List<CosmicSurvivalEnemy> spawnSplitterShards(CosmicSurvivalEnemy parent) {
    final out = <CosmicSurvivalEnemy>[];
    final shardCount = parent.tier == EnemyTier.colossus ? 4 : 3;
    final tier = parent.tier == EnemyTier.colossus
        ? EnemyTier.drone
        : EnemyTier.drone;
    for (var i = 0; i < shardCount; i++) {
      final angle = (i / shardCount) * 2 * pi + _rng.nextDouble() * 0.2;
      final dist = parent.radius + 6.0;
      final pos = Offset(
        parent.position.dx + cos(angle) * dist,
        parent.position.dy + sin(angle) * dist,
      );
      final hp =
          tierBaseHp(tier) *
          CosmicSurvivalBalance.enemyWaveHpScale(currentWave) *
          0.65;
      out.add(
        CosmicSurvivalEnemy(
          position: pos,
          angle: angle,
          hp: hp,
          maxHp: hp,
          speed:
              tierBaseSpeed(tier) *
              CosmicSurvivalBalance.enemyWaveSpeedScale(currentWave) *
              1.35,
          damage:
              tierBaseDamage(tier) *
              CosmicSurvivalBalance.enemyWaveDamageScale(currentWave) *
              1.10,
          radius: tierRadius(tier) * 0.95,
          tier: tier,
          element: parent.element,
          role: CosmicEnemyRole.striker,
          variant: SurvivalEnemyVariant.pouncer,
          target: CosmicEnemyTarget.orb,
        ),
      );
    }
    return out;
  }

  CosmicEnemyRole _roleForWave(int wave, EnemyTier tier) {
    if (currentMutator == SurvivalWaveMutator.hunterSwarm) {
      return _rng.nextDouble() < 0.65
          ? CosmicEnemyRole.hunter
          : CosmicEnemyRole.striker;
    }
    if (currentMutator == SurvivalWaveMutator.arcStorm &&
        _rng.nextDouble() < 0.55) {
      return CosmicEnemyRole.shooter;
    }
    if (currentMutator == SurvivalWaveMutator.shatteredSpace &&
        _rng.nextDouble() < 0.34) {
      return _rng.nextBool() ? CosmicEnemyRole.hunter : CosmicEnemyRole.shooter;
    }
    switch (currentPattern) {
      case SurvivalWavePattern.wispHorde:
        return _rng.nextDouble() < 0.75
            ? CosmicEnemyRole.striker
            : CosmicEnemyRole.orbiter;
      case SurvivalWavePattern.hunterPack:
        final roll = _rng.nextDouble();
        if (roll < 0.56) return CosmicEnemyRole.hunter;
        if (roll < 0.84) return CosmicEnemyRole.striker;
        return CosmicEnemyRole.orbiter;
      case SurvivalWavePattern.siegePush:
        if (tier.index >= EnemyTier.sentinel.index &&
            _rng.nextDouble() < 0.42) {
          return CosmicEnemyRole.orbiter;
        }
        return CosmicEnemyRole.striker;
      case SurvivalWavePattern.shooterScreen:
        final roll = _rng.nextDouble();
        if (roll < 0.48) return CosmicEnemyRole.shooter;
        if (roll < 0.78) return CosmicEnemyRole.orbiter;
        return CosmicEnemyRole.striker;
      case SurvivalWavePattern.swarmRush:
        final roll = _rng.nextDouble();
        if (roll < 0.58) return CosmicEnemyRole.striker;
        if (roll < 0.92) return CosmicEnemyRole.orbiter;
        return CosmicEnemyRole.hunter;
      case SurvivalWavePattern.mixed:
        break;
    }

    final roll = _rng.nextDouble();
    if (wave >= 12 && tier.index >= EnemyTier.drone.index && roll < 0.14) {
      return CosmicEnemyRole.shooter;
    }
    if (wave >= 10 && roll < 0.28) return CosmicEnemyRole.hunter;
    if (roll < 0.62) return CosmicEnemyRole.orbiter;
    return CosmicEnemyRole.striker;
  }

  CosmicEnemyTarget _initialTargetForRole(CosmicEnemyRole role) {
    return switch (role) {
      CosmicEnemyRole.striker => CosmicEnemyTarget.orb,
      CosmicEnemyRole.orbiter => CosmicEnemyTarget.orb,
      CosmicEnemyRole.shooter => CosmicEnemyTarget.companion,
      CosmicEnemyRole.hunter => CosmicEnemyTarget.ship,
    };
  }

  /// Check if wave is complete.
  void checkWaveComplete(int aliveCount, {bool bossAlive = false}) {
    if (!_waveActive) return;
    if (!_waitingForClear) return;
    if (bossAlive) return;
    if (aliveCount <= 0) {
      _waveActive = false;
      intermission = true;
      return;
    }

    if (!isBossWave && _targetCountThisWave > 0) {
      final defeated = (_spawnedThisWave - aliveCount).clamp(
        0,
        _targetCountThisWave,
      );
      final requiredDefeats = max(
        1,
        (_targetCountThisWave * earlyAdvanceKillThreshold).round(),
      );
      final allowedAlive = max(
        3,
        (_targetCountThisWave * (1 - earlyAdvanceKillThreshold)).ceil(),
      );
      if (defeated >= requiredDefeats && aliveCount <= allowedAlive) {
        _waveActive = false;
        intermission = true;
      }
      return;
    }

    _waveActive = false;
    intermission = true;
  }

  void markBossSpawned() {
    bossSpawned = true;
  }

  void resumeAfterIntermission() {
    _advanceWave();
  }

  static String bossDisciplineLabel(SurvivalBossDiscipline discipline) {
    return switch (discipline) {
      SurvivalBossDiscipline.artillery => 'Artillery',
      SurvivalBossDiscipline.trickster => 'Trickster',
      SurvivalBossDiscipline.duelist => 'Duelist',
      SurvivalBossDiscipline.conductor => 'Conductor',
      SurvivalBossDiscipline.siegebreaker => 'Siegebreaker',
      SurvivalBossDiscipline.riftcaller => 'Riftcaller',
      SurvivalBossDiscipline.standard => 'Vanguard',
    };
  }

  static String bossDisciplineSummary(SurvivalBossDiscipline discipline) {
    return switch (discipline) {
      SurvivalBossDiscipline.artillery => 'Long-range salvos and lane denial.',
      SurvivalBossDiscipline.trickster => 'Blink dives with flanking pouncers.',
      SurvivalBossDiscipline.duelist =>
        'High-tempo hunter pressure on your backline.',
      SurvivalBossDiscipline.conductor => 'Orb siege with rotating escorts.',
      SurvivalBossDiscipline.siegebreaker =>
        'Heavy crushers forcing the orb line.',
      SurvivalBossDiscipline.riftcaller =>
        'Portal volleys and crossfire screens.',
      SurvivalBossDiscipline.standard =>
        'Classic boss patterns with light support.',
    };
  }

  List<BossType> _preferredBossTypesForDiscipline(
    SurvivalBossDiscipline discipline,
  ) {
    return switch (discipline) {
      SurvivalBossDiscipline.artillery => const [
        BossType.gunner,
        BossType.warden,
      ],
      SurvivalBossDiscipline.trickster => const [
        BossType.skirmisher,
        BossType.charger,
      ],
      SurvivalBossDiscipline.duelist => const [
        BossType.skirmisher,
        BossType.charger,
      ],
      SurvivalBossDiscipline.conductor => const [
        BossType.carrier,
        BossType.warden,
      ],
      SurvivalBossDiscipline.siegebreaker => const [
        BossType.bulwark,
        BossType.charger,
      ],
      SurvivalBossDiscipline.riftcaller => const [
        BossType.warden,
        BossType.gunner,
      ],
      SurvivalBossDiscipline.standard => const [
        BossType.charger,
        BossType.gunner,
        BossType.warden,
      ],
    };
  }

  void _rememberBossTemplate(BossTemplate template) {
    _recentBossNames.add(template.name);
    if (_recentBossNames.length > 3) {
      _recentBossNames.removeAt(0);
    }
    _recentBossElements.add(template.element);
    if (_recentBossElements.length > 2) {
      _recentBossElements.removeAt(0);
    }
  }

  BossTemplate _pickBossTemplateForWave(
    int wave,
    SurvivalBossDiscipline discipline,
  ) {
    final forceTitanic = wave % 25 == 0;
    var pool = kBossTemplates
        .where((t) => forceTitanic ? t.isTitanic : !t.isTitanic)
        .toList();
    if (pool.isEmpty) {
      pool = List<BossTemplate>.of(kBossTemplates);
    }

    final preferredTypes = _preferredBossTypesForDiscipline(discipline);
    var candidates = pool
        .where(
          (t) =>
              t.preferredType == null ||
              preferredTypes.contains(t.preferredType),
        )
        .toList();
    if (candidates.isEmpty) candidates = pool;

    final freshNames = candidates
        .where((t) => !_recentBossNames.contains(t.name))
        .toList();
    if (freshNames.isNotEmpty) {
      candidates = freshNames;
    }

    final freshElements = candidates
        .where((t) => !_recentBossElements.contains(t.element))
        .toList();
    if (freshElements.isNotEmpty) {
      candidates = freshElements;
    }

    final template = candidates[_rng.nextInt(candidates.length)];
    _rememberBossTemplate(template);
    return template;
  }

  double _survivalBossRadius(BossTemplate template) {
    if (template.isTitanic) {
      return (template.radius * 0.64).clamp(84.0, 104.0);
    }
    return (template.radius * 0.9).clamp(24.0, 46.0);
  }

  /// Create a boss for a boss wave.
  SurvivalBoss? createBossForWave(int wave, Offset spawnPos) {
    if (kBossTemplates.isEmpty) return null;
    final bossLevel = (wave ~/ 5).clamp(1, 20);
    final discipline = switch (wave) {
      >= 35 when wave % 35 == 0 => SurvivalBossDiscipline.riftcaller,
      >= 30 when wave % 30 == 0 => SurvivalBossDiscipline.siegebreaker,
      >= 25 when wave % 25 == 0 => SurvivalBossDiscipline.conductor,
      >= 20 when wave % 20 == 0 => SurvivalBossDiscipline.duelist,
      >= 15 when wave % 15 == 0 => SurvivalBossDiscipline.trickster,
      >= 10 when wave % 10 == 0 => SurvivalBossDiscipline.artillery,
      _ => SurvivalBossDiscipline.standard,
    };
    final template = _pickBossTemplateForWave(wave, discipline);
    // Boss HP is normalized off a fixed base rather than template.health
    // (which ranged 28–65 purely as element flavor), so same-wave bosses
    // are consistently tuned. It scales on the same wave curve as trash
    // enemies so a boss never falls behind the elites escorting it, and
    // because the curve is wave-based it keeps scaling past wave 100.
    final normalizedHealth = template.isTitanic ? 150.0 : 42.0;
    final bossHpMultiplier = template.isTitanic ? 3.0 : 1.55;
    // Wave 5 is the first boss the player meets; the old tuning made it a
    // pushover compared to wave 10+. Give it a meaningful bite without
    // disrupting later waves.
    final earlyBossBuff = wave == 5 ? 1.85 : 1.0;
    final hp =
        normalizedHealth *
        16 *
        CosmicSurvivalBalance.enemyWaveHpScale(wave) *
        bossHpMultiplier *
        earlyBossBuff;
    final speedScale =
        (1.0 + (bossLevel - 1) * 0.04) *
        (template.isTitanic ? 0.84 : 1.0) *
        (wave == 5 ? 1.15 : 1.0);
    final speed = (template.speed * speedScale).clamp(45.0, double.infinity);
    final type = template.preferredType ?? bossTypeForLevel(bossLevel);
    final movement = _pickBossMovementStyle(type, discipline);
    final engagement = _engagementRangeFor(movement);
    final strafe = _strafeWeightFor(movement);

    return SurvivalBoss(
      template: template,
      type: type,
      discipline: discipline,
      level: bossLevel,
      position: spawnPos,
      hp: hp,
      maxHp: hp,
      speed: speed,
      baseSpeed: speed,
      radius: _survivalBossRadius(template),
      color: elementColor(template.element),
      movementStyle: movement,
      engagementRange: engagement,
      strafeWeight: strafe,
    );
  }

  /// Pick how the boss prefers to move. Snipers/artillery sit back, brawlers
  /// chase, and a few archetypes patrol a mid-distance ring.
  SurvivalBossMovementStyle _pickBossMovementStyle(
    BossType type,
    SurvivalBossDiscipline discipline,
  ) {
    // Discipline overrides come first — they describe the wave-themed boss.
    switch (discipline) {
      case SurvivalBossDiscipline.artillery:
      case SurvivalBossDiscipline.riftcaller:
        return SurvivalBossMovementStyle.sniper;
      case SurvivalBossDiscipline.conductor:
      case SurvivalBossDiscipline.trickster:
        return SurvivalBossMovementStyle.orbit;
      case SurvivalBossDiscipline.duelist:
      case SurvivalBossDiscipline.siegebreaker:
        return SurvivalBossMovementStyle.chase;
      case SurvivalBossDiscipline.standard:
        // Fall through to per-type tuning.
        break;
    }
    switch (type) {
      case BossType.gunner:
        // 70% sniper, 30% orbit — keeps gunner fights feeling like artillery
        // bombardment from a distance rather than tight melee.
        return _rng.nextDouble() < 0.70
            ? SurvivalBossMovementStyle.sniper
            : SurvivalBossMovementStyle.orbit;
      case BossType.bulwark:
        return SurvivalBossMovementStyle.orbit;
      case BossType.warden:
        // Warden summons and shoots — keep it mid-far rather than in your face.
        return _rng.nextDouble() < 0.55
            ? SurvivalBossMovementStyle.orbit
            : SurvivalBossMovementStyle.sniper;
      case BossType.carrier:
        // Carrier escorts adds toward the orb but doesn't need to brawl.
        return SurvivalBossMovementStyle.orbit;
      case BossType.charger:
      case BossType.skirmisher:
        return SurvivalBossMovementStyle.chase;
    }
  }

  double _engagementRangeFor(SurvivalBossMovementStyle style) {
    // Snipers/orbiters get a randomized ring distance so two bosses on the
    // same wave don't stack on the exact same circle.
    switch (style) {
      case SurvivalBossMovementStyle.sniper:
        return 620.0 + _rng.nextDouble() * 140.0;
      case SurvivalBossMovementStyle.orbit:
        return 360.0 + _rng.nextDouble() * 90.0;
      case SurvivalBossMovementStyle.chase:
        return 180.0 + _rng.nextDouble() * 40.0;
    }
  }

  double _strafeWeightFor(SurvivalBossMovementStyle style) {
    switch (style) {
      case SurvivalBossMovementStyle.sniper:
        return 0.18;
      case SurvivalBossMovementStyle.orbit:
        return 0.70;
      case SurvivalBossMovementStyle.chase:
        return 1.0;
    }
  }

  /// Spawn escort adds for carrier/warden bosses.
  List<CosmicSurvivalEnemy> spawnBossAdds(
    SurvivalBoss boss,
    Offset orbPos,
    double viewW,
    double viewH,
  ) {
    final adds = <CosmicSurvivalEnemy>[];
    final count = switch (boss.discipline) {
      SurvivalBossDiscipline.artillery => 2 + (boss.level >= 10 ? 1 : 0),
      SurvivalBossDiscipline.duelist => 2 + (boss.level >= 12 ? 1 : 0),
      SurvivalBossDiscipline.siegebreaker => 3 + (boss.level ~/ 5).clamp(0, 2),
      SurvivalBossDiscipline.trickster => 3 + (boss.level ~/ 4).clamp(0, 3),
      SurvivalBossDiscipline.conductor => 4 + (boss.level ~/ 4).clamp(0, 3),
      SurvivalBossDiscipline.riftcaller => 4 + (boss.level ~/ 4).clamp(0, 4),
      SurvivalBossDiscipline.standard => 3 + (boss.level ~/ 2).clamp(0, 5),
    };
    for (var i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final offset = Offset(
        cos(angle) * boss.radius * 2,
        sin(angle) * boss.radius * 2,
      );
      final pos = boss.position + offset;
      final tier = switch (boss.discipline) {
        SurvivalBossDiscipline.artillery =>
          (i == 0 && boss.level >= 10) ? EnemyTier.phantom : EnemyTier.sentinel,
        SurvivalBossDiscipline.duelist =>
          (i == 0 || boss.level >= 12) ? EnemyTier.phantom : EnemyTier.drone,
        SurvivalBossDiscipline.siegebreaker =>
          (i == 0 || boss.level >= 10) ? EnemyTier.brute : EnemyTier.sentinel,
        SurvivalBossDiscipline.trickster =>
          (i == 0 || boss.level >= 10) ? EnemyTier.phantom : EnemyTier.drone,
        SurvivalBossDiscipline.riftcaller =>
          i == 0 ? EnemyTier.phantom : EnemyTier.sentinel,
        SurvivalBossDiscipline.conductor =>
          (i % 3 == 0 && boss.level >= 10)
              ? EnemyTier.sentinel
              : EnemyTier.drone,
        _ => boss.level >= 10 ? EnemyTier.sentinel : EnemyTier.drone,
      };
      final role = switch (boss.discipline) {
        SurvivalBossDiscipline.artillery =>
          i == 0 ? CosmicEnemyRole.shooter : CosmicEnemyRole.orbiter,
        SurvivalBossDiscipline.duelist =>
          i.isEven ? CosmicEnemyRole.hunter : CosmicEnemyRole.striker,
        SurvivalBossDiscipline.siegebreaker =>
          i.isEven ? CosmicEnemyRole.striker : CosmicEnemyRole.orbiter,
        SurvivalBossDiscipline.trickster =>
          i.isEven ? CosmicEnemyRole.hunter : CosmicEnemyRole.shooter,
        SurvivalBossDiscipline.riftcaller =>
          i.isEven ? CosmicEnemyRole.shooter : CosmicEnemyRole.orbiter,
        SurvivalBossDiscipline.conductor =>
          i.isEven ? CosmicEnemyRole.orbiter : CosmicEnemyRole.striker,
        _ => CosmicEnemyRole.striker,
      };
      final variant = switch (boss.discipline) {
        SurvivalBossDiscipline.artillery when role == CosmicEnemyRole.shooter =>
          SurvivalEnemyVariant.siegeShooter,
        SurvivalBossDiscipline.artillery => SurvivalEnemyVariant.standard,
        SurvivalBossDiscipline.duelist => SurvivalEnemyVariant.pouncer,
        SurvivalBossDiscipline.siegebreaker
            when role == CosmicEnemyRole.striker =>
          SurvivalEnemyVariant.crusher,
        SurvivalBossDiscipline.siegebreaker => SurvivalEnemyVariant.orbBreaker,
        SurvivalBossDiscipline.trickster => SurvivalEnemyVariant.pouncer,
        SurvivalBossDiscipline.riftcaller
            when role == CosmicEnemyRole.shooter =>
          SurvivalEnemyVariant.siegeShooter,
        SurvivalBossDiscipline.conductor when role == CosmicEnemyRole.orbiter =>
          SurvivalEnemyVariant.orbBreaker,
        _ => SurvivalEnemyVariant.standard,
      };
      final hp =
          tierBaseHp(tier) *
          CosmicSurvivalBalance.enemyWaveHpScale(currentWave);
      final variantHpMult = switch (variant) {
        SurvivalEnemyVariant.orbBreaker => 1.22,
        SurvivalEnemyVariant.siegeShooter => 0.92,
        SurvivalEnemyVariant.crusher => 1.38,
        SurvivalEnemyVariant.pouncer => 0.88,
        SurvivalEnemyVariant.summoner => 1.15,
        SurvivalEnemyVariant.splitter => 1.05,
        SurvivalEnemyVariant.standard => 1.0,
      };
      final variantSpeedMult = switch (variant) {
        SurvivalEnemyVariant.orbBreaker => 0.84,
        SurvivalEnemyVariant.siegeShooter => 0.95,
        SurvivalEnemyVariant.crusher => 0.76,
        SurvivalEnemyVariant.pouncer => 1.22,
        SurvivalEnemyVariant.summoner => 0.78,
        SurvivalEnemyVariant.splitter => 0.82,
        SurvivalEnemyVariant.standard => 1.0,
      };
      final variantDamageMult = switch (variant) {
        SurvivalEnemyVariant.orbBreaker => 1.2,
        SurvivalEnemyVariant.siegeShooter => 1.16,
        SurvivalEnemyVariant.crusher => 1.26,
        SurvivalEnemyVariant.pouncer => 1.10,
        SurvivalEnemyVariant.summoner => 1.00,
        SurvivalEnemyVariant.splitter => 1.18,
        SurvivalEnemyVariant.standard => 1.0,
      };
      adds.add(
        CosmicSurvivalEnemy(
          position: pos,
          hp: hp * variantHpMult,
          maxHp: hp * variantHpMult,
          speed: tierBaseSpeed(tier) * variantSpeedMult,
          damage: tierBaseDamage(tier) * variantDamageMult,
          radius: tierRadius(tier),
          tier: tier,
          element: boss.template.element,
          role: role,
          variant: variant,
          target: switch (role) {
            CosmicEnemyRole.shooter
                when boss.discipline == SurvivalBossDiscipline.artillery =>
              CosmicEnemyTarget.orb,
            CosmicEnemyRole.hunter
                when boss.discipline == SurvivalBossDiscipline.duelist =>
              CosmicEnemyTarget.companion,
            CosmicEnemyRole.striker
                when boss.discipline == SurvivalBossDiscipline.siegebreaker =>
              CosmicEnemyTarget.orb,
            CosmicEnemyRole.shooter
                when boss.discipline == SurvivalBossDiscipline.riftcaller =>
              CosmicEnemyTarget.orb,
            CosmicEnemyRole.shooter => CosmicEnemyTarget.companion,
            CosmicEnemyRole.hunter => CosmicEnemyTarget.ship,
            _ => CosmicEnemyTarget.orb,
          },
        ),
      );
    }
    return adds;
  }

  static double _eliteChance(int wave) {
    if (wave < 20) return 0;
    return ((wave - 20) * 0.010 + 0.05).clamp(0.0, 0.22);
  }

  static List<EliteAffix> eliteAffixPoolForWave(int wave) {
    if (wave < 14) return const [];
    if (wave < 22) {
      return const [
        EliteAffix.bulwarked,
        EliteAffix.overclocked,
      ];
    }
    if (wave < 30) {
      return const [
        EliteAffix.bulwarked,
        EliteAffix.volatile,
        EliteAffix.overclocked,
      ];
    }
    if (wave < 38) {
      return const [
        EliteAffix.bulwarked,
        EliteAffix.volatile,
        EliteAffix.vampiric,
        EliteAffix.overclocked,
      ];
    }
    return List<EliteAffix>.of(EliteAffix.values);
  }

  static EliteAffix? rollEliteAffixForWave(int wave, Random rng) {
    final pool = eliteAffixPoolForWave(wave);
    if (pool.isEmpty) return null;
    return pool[rng.nextInt(pool.length)];
  }

  static String? mutatorLabel(SurvivalWaveMutator? mutator) {
    return switch (mutator) {
      SurvivalWaveMutator.orbSiege => 'ORB SIEGE',
      SurvivalWaveMutator.hunterSwarm => 'HUNTER SWARM',
      SurvivalWaveMutator.arcStorm => 'ARC STORM',
      SurvivalWaveMutator.fortified => 'FORTIFIED',
      SurvivalWaveMutator.shatteredSpace => 'SHATTERED SPACE',
      SurvivalWaveMutator.manaFlux => 'MANA FLUX',
      null => null,
    };
  }

  static String? mutatorDescription(SurvivalWaveMutator? mutator) {
    return switch (mutator) {
      SurvivalWaveMutator.orbSiege =>
        'Heavier orb pressure and sturdier assault lines.',
      SurvivalWaveMutator.hunterSwarm =>
        'Fast hunter packs collapse on ship and companions.',
      SurvivalWaveMutator.arcStorm =>
        'Shooter density rises and projectile pressure intensifies.',
      SurvivalWaveMutator.fortified =>
        'Heavier enemy tiers and stronger elite fronts.',
      SurvivalWaveMutator.shatteredSpace =>
        'Enemies break faster but surge in quicker, deadlier bursts.',
      SurvivalWaveMutator.manaFlux =>
        'Alchemical flow surges and build momentum accelerates.',
      null => null,
    };
  }
}
