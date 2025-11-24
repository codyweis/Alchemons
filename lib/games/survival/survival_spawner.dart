import 'dart:math';

import 'package:alchemons/games/survival/survival_combat.dart';
import 'package:flame/components.dart';
import 'package:alchemons/games/survival/survival_game.dart';
import 'package:alchemons/games/survival/survival_enemies.dart';

enum WaveStyle {
  normal,
  swarm, // tons of low-HP mobs → AoE check
  eliteWall, // few very tanky → single-target / %HP / debuff check
  attrition, // sustained chip damage → healer / sustain check
}

class SurvivalSpawner extends Component with HasGameRef<SurvivalHoardGame> {
  double _timer = 0;
  final Random _rng = Random();

  static const double _minSpawnDist = 1250.0;
  static const double _maxSpawnDist = 1450.0;

  // Track which waves already got a special formation
  final Set<int> _didPatternForWave = {};

  @override
  void update(double dt) {
    if (gameRef.isGameOver || gameRef.isInAlchemyPause) return;

    final wave = gameRef.currentWave;

    final waveFactor = (1.0 - (wave - 1) * 0.04).clamp(0.5, 1.0);
    final timeFactor = (1.0 - gameRef.timeElapsed / 1200.0).clamp(0.9, 1.0);
    final currentSpawnRate = 3.2 * waveFactor * timeFactor;

    _timer += dt;

    if (_timer >= currentSpawnRate) {
      _timer = 0;
      _spawnTick(wave);
    }
  }

  void _spawnTick(int wave) {
    // Boss?
    if (_shouldSpawnBoss(wave)) {
      _spawnBoss(wave);
      return;
    }

    // Try scripted pattern first
    if (!_didPatternForWave.contains(wave)) {
      if (_trySpawnSpecialPattern(wave)) {
        _didPatternForWave.add(wave);
        return;
      }
    }

    // --- fallback: normal spawn ---
    int tier = _pickTierForWave(wave);
    int count = 1;
    final style = _waveStyleFor(wave);

    switch (style) {
      case WaveStyle.swarm:
        tier = 1;
        count = 5 + _rng.nextInt(3);
        break;

      case WaveStyle.eliteWall:
        tier = (tier + 1).clamp(1, 5);
        count = 1;
        break;

      case WaveStyle.attrition:
        count = 1 + _rng.nextInt(2);
        break;

      case WaveStyle.normal:
        count = 1 + _rng.nextInt(2);
        break;
    }

    final angle = _rng.nextDouble() * pi * 2;

    final dist =
        _minSpawnDist + _rng.nextDouble() * (_maxSpawnDist - _minSpawnDist);
    final centerPos = Vector2(cos(angle), sin(angle)) * dist;

    for (int i = 0; i < count; i++) {
      final offset = Vector2(
        _rng.nextDouble() * 80 - 40,
        _rng.nextDouble() * 80 - 40,
      );

      _spawnSingleEnemy(
        tier: tier,
        wave: wave,
        position: centerPos + offset,
        isBoss: false,
      );
    }
  }

  WaveStyle _waveStyleFor(int wave) {
    if (wave % 10 == 0) return WaveStyle.eliteWall;
    if (wave % 7 == 0) return WaveStyle.attrition;
    if (wave % 3 == 0) return WaveStyle.swarm;
    return WaveStyle.normal;
  }

  // ---------------------------------------------------------------------------
  // Special pattern waves (visual spice)
  // ---------------------------------------------------------------------------

  bool _trySpawnSpecialPattern(int wave) {
    // Example schedule:
    // Wave 6,11,16,... => closing ring
    // Wave 8,13,18,... => rotating arc
    // Wave 10,15,20,... => cross barrage

    if (wave >= 6 && (wave - 6) % 5 == 0) {
      _spawnClosingRing(wave);
      return true;
    }

    if (wave >= 8 && (wave - 8) % 5 == 0) {
      _spawnRotatingArc(wave);
      return true;
    }

    if (wave >= 10 && (wave - 10) % 5 == 0) {
      _spawnCrossBarrage(wave);
      return true;
    }

    return false;
  }

  void _spawnClosingRing(int wave) {
    final int tier = 1; // keep swarmy
    final int count = 32;
    final double radius = (_minSpawnDist + _maxSpawnDist) * 0.5;

    for (int i = 0; i < count; i++) {
      final angle = (i / count) * 2 * pi;
      final pos = Vector2(cos(angle), sin(angle)) * radius;

      _spawnSingleEnemy(tier: tier, wave: wave, position: pos, isBoss: false);
    }
  }

  void _spawnRotatingArc(int wave) {
    final int tier = _pickTierForWave(wave).clamp(1, 3);
    final int count = 18;

    final double baseAngle = _rng.nextDouble() * 2 * pi;
    final double arcWidth = pi / 2;
    final double radius = _minSpawnDist + (_maxSpawnDist - _minSpawnDist) * 0.3;

    for (int i = 0; i < count; i++) {
      final double t = count == 1 ? 0.5 : i / (count - 1);
      final angle = baseAngle - arcWidth / 2 + arcWidth * t;
      final pos = Vector2(cos(angle), sin(angle)) * radius;

      _spawnSingleEnemy(tier: tier, wave: wave, position: pos, isBoss: false);
    }
  }

  void _spawnCrossBarrage(int wave) {
    final int tier = _pickTierForWave(wave).clamp(1, 2);
    final int perLane = 6;

    final double inner = _minSpawnDist;
    final double outer = _maxSpawnDist;

    final List<Vector2> dirs = [
      Vector2(0, -1),
      Vector2(1, 0),
      Vector2(0, 1),
      Vector2(-1, 0),
    ];

    for (final dir in dirs) {
      for (int i = 0; i < perLane; i++) {
        final double t = perLane == 1 ? 0.5 : i / (perLane - 1);
        final double dist = inner + (outer - inner) * t;
        final pos = dir * dist;

        _spawnSingleEnemy(tier: tier, wave: wave, position: pos, isBoss: false);
      }
    }
  }

  // ---------------------------------------------------------------------------

  void _spawnSingleEnemy({
    required int tier,
    required int wave,
    required Vector2 position,
    required bool isBoss,
    BossArchetype? bossArchetype,
    bool isMegaBoss = false,
  }) {
    final template = SurvivalEnemyCatalog.getRandomTemplateForTier(tier);

    final enemyUnit = SurvivalEnemyCatalog.buildEnemy(
      template: template,
      tier: tier,
      wave: wave,
    );

    if (isBoss) {
      _applyBossStats(enemyUnit, wave);
    }

    final role = _determineRole(template, wave);

    // Decide boss speed scaling here (no gameRef inside HoardEnemy constructor)
    double speedMult = 1.0;
    if (isBoss) {
      if (wave <= 10) {
        speedMult = 0.5;
      } else if (wave <= 20) {
        speedMult = 0.75;
      } else {
        speedMult = 0.9;
      }
    }

    final enemy = HoardEnemy(
      position: position,
      targetOrb: gameRef.orb,
      unit: enemyUnit,
      template: template,
      role: role,
      sizeScale: isBoss ? (isMegaBoss ? 2.3 : 1.8) : 1.0,
      bossArchetype: isBoss ? bossArchetype : null,
      isMegaBoss: isMegaBoss,
      speedMultiplier: speedMult,
    );

    enemy.isBoss = isBoss;
    gameRef.addHoardEnemy(enemy);
  }

  bool _shouldSpawnBoss(int wave) {
    if (wave <= 0) return false;
    final isBossWave = wave % 5 == 0;
    if (!isBossWave) return false;
    if (gameRef.bossAlive) return false;

    return _rng.nextDouble() < 0.9;
  }

  void _spawnBoss(int wave) {
    int tierNum;
    if (wave <= 5) {
      tierNum = 3;
    } else if (wave <= 10) {
      tierNum = _rng.nextDouble() < 0.7 ? 3 : 4;
    } else if (wave <= 20) {
      tierNum = _rng.nextDouble() < 0.7 ? 4 : 5;
    } else {
      tierNum = _rng.nextDouble() < 0.4 ? 4 : 5;
    }

    // First mega boss at wave 25, then 45, 65, ...
    final bool isMegaBoss = wave >= 25 && ((wave - 25) % 20 == 0);

    // Choose archetype based on wave progression
    final BossArchetype archetype;
    if (!isMegaBoss) {
      final idx = ((wave ~/ 5) - 1) % 3;
      switch (idx) {
        case 0:
          archetype = BossArchetype.orbitingSummoner;
          break;
        case 1:
          archetype = BossArchetype.ringBreaker;
          break;
        default:
          archetype = BossArchetype.bulletHell;
          break;
      }
    } else {
      final megaIndex = ((wave - 25) ~/ 20) % 3;
      switch (megaIndex) {
        case 0:
          archetype = BossArchetype.orbitingSummoner;
          break;
        case 1:
          archetype = BossArchetype.bulletHell;
          break;
        default:
          archetype = BossArchetype.ringBreaker;
          break;
      }
    }

    final angle = _rng.nextDouble() * pi * 2;
    final dist = _minSpawnDist + _rng.nextDouble() * 100;
    final spawnPos = Vector2(cos(angle), sin(angle)) * dist;

    _spawnSingleEnemy(
      tier: tierNum,
      wave: wave,
      position: spawnPos,
      isBoss: true,
      bossArchetype: archetype,
      isMegaBoss: isMegaBoss,
    );
  }

  void _applyBossStats(SurvivalUnit unit, int wave) {
    final double t = (wave / 30.0).clamp(0.0, 1.0);

    double bossHpMult = 3.5 + (6.5 * t);
    double bossDmgMult = 1.3 + (1.8 - 1.3) * t;

    if (wave <= 5) {
      bossHpMult = 2.5;
      bossDmgMult = 1.15;
    }

    unit.maxHp = (unit.maxHp * bossHpMult).round();
    unit.currentHp = unit.maxHp;
    unit.physAtk = (unit.physAtk * bossDmgMult).round();
    unit.elemAtk = (unit.elemAtk * bossDmgMult).round();

    unit.calculateCombatStats();
  }

  int _pickTierForWave(int wave) {
    int maxTier;
    if (wave < 5) {
      maxTier = 1;
    } else if (wave < 10) {
      maxTier = 2;
    } else if (wave < 15) {
      maxTier = 3;
    } else if (wave < 25) {
      maxTier = 4;
    } else {
      maxTier = 5;
    }

    final roll = _rng.nextDouble();

    if (roll < 0.4) {
      return (maxTier - 1 - _rng.nextInt(2)).clamp(1, maxTier);
    } else if (roll < 0.8) {
      return maxTier;
    } else {
      return _rng.nextInt(maxTier) + 1;
    }
  }

  /// Shooters flat-ish, clamped at 10% max.
  EnemyRole _determineRole(SurvivalEnemyTemplate template, int wave) {
    final style = _waveStyleFor(wave);

    // very low baseline (2% shooters)
    double shooterBias = 0.02;

    // Elements that like being shooters
    switch (template.element) {
      case 'Air':
      case 'Lightning':
      case 'Spirit':
      case 'Ice':
      case 'Fire':
        shooterBias += 0.06; // up to ~8%
        break;

      // Elements that prefer melee
      case 'Earth':
      case 'Plant':
      case 'Mud':
      case 'Crystal':
        shooterBias -= 0.02;
        break;
    }

    // Wave styles influence, but lightly
    if (style == WaveStyle.attrition) shooterBias += 0.02;
    if (style == WaveStyle.swarm) shooterBias -= 0.01;
    if (style == WaveStyle.eliteWall) shooterBias -= 0.01;

    // Clamp at <= 10%
    shooterBias = shooterBias.clamp(0.02, 0.10);

    return _rng.nextDouble() < shooterBias
        ? EnemyRole.shooter
        : EnemyRole.charger;
  }
}
