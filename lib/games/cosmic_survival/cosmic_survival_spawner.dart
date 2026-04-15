// lib/games/cosmic_survival/cosmic_survival_spawner.dart
//
// COSMIC SURVIVAL WAVE SPAWNER
// Endless waves of cosmic enemy types that scale in count, HP, speed, and tier.
// Boss encounters at milestone waves (every 5 waves).

import 'dart:math';
import 'dart:ui';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_balance.dart';

enum CosmicEnemyRole { striker, orbiter, shooter, hunter }

enum CosmicEnemyTarget { orb, ship, companion }

enum SurvivalBossDiscipline {
  standard,
  artillery,
  trickster,
  duelist,
  conductor,
}

enum SurvivalWavePattern {
  mixed,
  wispHorde,
  hunterPack,
  siegePush,
  shooterScreen,
}

enum SurvivalEliteAffix {
  bulwarked,
  volatile,
  vampiric,
  overclocked,
  relentless,
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
  double angle;
  double hp;
  final double maxHp;
  final double speed;
  final double damage;
  final double radius;
  final EnemyTier tier;
  final String element;
  final CosmicEnemyRole role;
  CosmicEnemyTarget target;
  bool isDead;
  double hitFlash;
  double slowTimer;
  double attackCooldown;
  double retargetTimer;
  final bool isElite;
  final SurvivalEliteAffix? eliteAffix;

  CosmicSurvivalEnemy({
    required this.position,
    this.angle = 0,
    required this.hp,
    required this.maxHp,
    required this.speed,
    required this.damage,
    required this.radius,
    required this.tier,
    required this.element,
    required this.role,
    required this.target,
    this.isDead = false,
    this.hitFlash = 0,
    this.slowTimer = 0,
    this.attackCooldown = 0,
    this.retargetTimer = 0,
    this.isElite = false,
    this.eliteAffix,
  });

  double get hpFraction => maxHp > 0 ? (hp / maxHp).clamp(0, 1) : 0;
  double get effectiveSpeed {
    if (slowTimer <= 0) return speed;
    return speed * (isRelentless ? 0.78 : 0.5);
  }

  bool get isShooter => role == CosmicEnemyRole.shooter;
  bool get hasBulwark => eliteAffix == SurvivalEliteAffix.bulwarked;
  bool get isVolatile => eliteAffix == SurvivalEliteAffix.volatile;
  bool get isVampiric => eliteAffix == SurvivalEliteAffix.vampiric;
  bool get isOverclocked => eliteAffix == SurvivalEliteAffix.overclocked;
  bool get isRelentless => eliteAffix == SurvivalEliteAffix.relentless;
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
  final double angle;
  final String element;
  final double damage;
  final double speed;
  double life;
  final double radius;
  final CosmicEnemyTarget target;

  SurvivalEnemyProjectile({
    required this.position,
    required this.angle,
    required this.element,
    required this.damage,
    required this.target,
    this.speed = 220,
    this.life = 4.0,
    this.radius = 4.0,
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
    final base = (4 + wave * 1.9 + pow(wave, 1.08) * 0.38).round();
    final multiplier = switch (currentPattern) {
      SurvivalWavePattern.wispHorde => 1.45,
      SurvivalWavePattern.hunterPack => 1.10,
      SurvivalWavePattern.siegePush => 0.78,
      SurvivalWavePattern.shooterScreen => 0.92,
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
    return (base * multiplier * mutatorMultiplier).round().clamp(5, 108);
  }

  double _spawnInterval(int wave) {
    final base = (0.98 - wave * 0.017).clamp(0.20, 0.98);
    final patternInterval = switch (currentPattern) {
      SurvivalWavePattern.wispHorde => max(0.12, base * 0.45),
      SurvivalWavePattern.hunterPack => max(0.16, base * 0.72),
      SurvivalWavePattern.siegePush => min(0.88, base * 1.08),
      SurvivalWavePattern.shooterScreen => max(0.18, base * 0.76),
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
    if (wave >= 10 && roll < 0.44) return SurvivalWavePattern.shooterScreen;
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

  CosmicSurvivalEnemy _spawnEnemy(double viewW, double viewH, Offset orbPos) {
    final tier = _tierForWave(currentWave);
    final element = _kElements[_rng.nextInt(_kElements.length)];
    final role = _roleForWave(currentWave, tier);

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
        (eliteAffix == SurvivalEliteAffix.relentless ? 1.05 : 1.0) *
        (eliteAffix == SurvivalEliteAffix.overclocked ? 1.18 : 1.0);
    final baseDamage =
        tierBaseDamage(tier) *
        CosmicSurvivalBalance.enemyWaveDamageScale(currentWave) *
        (isElite ? 1.5 : 1.0) *
        (currentMutator == SurvivalWaveMutator.orbSiege ? 1.08 : 1.0) *
        (currentMutator == SurvivalWaveMutator.shatteredSpace ? 1.10 : 1.0) *
        (eliteAffix == SurvivalEliteAffix.vampiric ? 1.10 : 1.0);

    return CosmicSurvivalEnemy(
      position: pos,
      angle: angle + pi,
      hp: baseHp,
      maxHp: baseHp,
      speed: baseSpeed,
      damage: baseDamage,
      radius: tierRadius(tier) * (isElite ? 1.3 : 1.0),
      tier: tier,
      element: element,
      role: role,
      target: _initialTargetForRole(role),
      isElite: isElite,
      eliteAffix: eliteAffix,
    );
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
        return _rng.nextDouble() < 0.72
            ? CosmicEnemyRole.hunter
            : CosmicEnemyRole.striker;
      case SurvivalWavePattern.siegePush:
        if (tier.index >= EnemyTier.sentinel.index &&
            _rng.nextDouble() < 0.42) {
          return CosmicEnemyRole.orbiter;
        }
        return CosmicEnemyRole.striker;
      case SurvivalWavePattern.shooterScreen:
        if (_rng.nextDouble() < 0.58) return CosmicEnemyRole.shooter;
        return _rng.nextDouble() < 0.5
            ? CosmicEnemyRole.orbiter
            : CosmicEnemyRole.hunter;
      case SurvivalWavePattern.mixed:
        break;
    }

    final roll = _rng.nextDouble();
    if (wave >= 12 && tier.index >= EnemyTier.drone.index && roll < 0.18) {
      return CosmicEnemyRole.shooter;
    }
    if (wave >= 8 && roll < 0.35) return CosmicEnemyRole.hunter;
    if (roll < 0.58) return CosmicEnemyRole.orbiter;
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

  /// Create a boss for a boss wave.
  SurvivalBoss? createBossForWave(int wave, Offset spawnPos) {
    if (kBossTemplates.isEmpty) return null;
    final template = kBossTemplates[_rng.nextInt(kBossTemplates.length)];
    final bossLevel = (wave ~/ 5).clamp(1, 20);
    final hpScale = 1.0 + (bossLevel - 1) * 0.38;
    final speedScale = 1.0 + (bossLevel - 1) * 0.04;
    final hp = template.health * 16 * hpScale;
    final speed = (template.speed * speedScale).clamp(60.0, double.infinity);
    final type = template.preferredType ?? bossTypeForLevel(bossLevel);
    final discipline = switch (wave) {
      >= 25 when wave % 25 == 0 => SurvivalBossDiscipline.conductor,
      >= 20 when wave % 20 == 0 => SurvivalBossDiscipline.duelist,
      >= 15 when wave % 15 == 0 => SurvivalBossDiscipline.trickster,
      >= 10 when wave % 10 == 0 => SurvivalBossDiscipline.artillery,
      _ => SurvivalBossDiscipline.standard,
    };

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
      radius: template.radius,
      color: elementColor(template.element),
    );
  }

  /// Spawn escort adds for carrier/warden bosses.
  List<CosmicSurvivalEnemy> spawnBossAdds(
    SurvivalBoss boss,
    Offset orbPos,
    double viewW,
    double viewH,
  ) {
    final adds = <CosmicSurvivalEnemy>[];
    final count = 3 + (boss.level ~/ 2).clamp(0, 5);
    for (var i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final offset = Offset(
        cos(angle) * boss.radius * 2,
        sin(angle) * boss.radius * 2,
      );
      final pos = boss.position + offset;
      final tier = boss.level >= 10 ? EnemyTier.sentinel : EnemyTier.drone;
      final hp =
          tierBaseHp(tier) *
          CosmicSurvivalBalance.enemyWaveHpScale(currentWave);
      adds.add(
        CosmicSurvivalEnemy(
          position: pos,
          hp: hp,
          maxHp: hp,
          speed: tierBaseSpeed(tier),
          damage: tierBaseDamage(tier),
          radius: tierRadius(tier),
          tier: tier,
          element: boss.template.element,
          role: CosmicEnemyRole.striker,
          target: CosmicEnemyTarget.orb,
        ),
      );
    }
    return adds;
  }

  static double _eliteChance(int wave) {
    if (wave < 20) return 0;
    return ((wave - 20) * 0.010 + 0.05).clamp(0.0, 0.22);
  }

  static List<SurvivalEliteAffix> eliteAffixPoolForWave(int wave) {
    if (wave < 14) return const [];
    if (wave < 22) {
      return const [
        SurvivalEliteAffix.bulwarked,
        SurvivalEliteAffix.overclocked,
      ];
    }
    if (wave < 30) {
      return const [
        SurvivalEliteAffix.bulwarked,
        SurvivalEliteAffix.volatile,
        SurvivalEliteAffix.overclocked,
      ];
    }
    if (wave < 38) {
      return const [
        SurvivalEliteAffix.bulwarked,
        SurvivalEliteAffix.volatile,
        SurvivalEliteAffix.vampiric,
        SurvivalEliteAffix.overclocked,
      ];
    }
    return List<SurvivalEliteAffix>.of(SurvivalEliteAffix.values);
  }

  static SurvivalEliteAffix? rollEliteAffixForWave(int wave, Random rng) {
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
