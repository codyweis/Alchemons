import 'dart:math';

import 'package:flame/components.dart';
import 'package:alchemons/games/survival/survival_game.dart';
import 'package:alchemons/games/survival/survival_enemies.dart';

enum WaveStyle { normal, tactical, reinforced, flanking, escort }

class ImprovedSurvivalSpawner extends Component
    with HasGameRef<SurvivalHoardGame> {
  static const bool debugSpawns = false;
  double _timer = 0;
  final Random _rng = Random();

  static const double _minSpawnDist = 1500.0;
  static const double _maxSpawnDist = 2500.0;

  final Set<int> _didPatternForWave = {};
  final Set<int> _didMiniBossForWave = {};
  final Set<int> _didMegaBossForWave = {};
  final Set<int> _didElitePackForWave = {};
  int _lastWave = 0;
  int _lastFormationIndex = -1;

  @override
  void update(double dt) {
    if (gameRef.isGameOver || gameRef.isInAlchemyPause) return;

    final wave = gameRef.currentWave;

    // Wave change
    if (wave != _lastWave) {
      if (debugSpawns) print('==== WAVE $wave ====');
      _lastWave = wave;

      final isBossWave = wave > 0 && wave % 10 == 0;
      final isMiniBossWave =
          wave > 0 && wave % 5 == 0 && wave % 10 != 0; // 5,15,25,...

      // Boss spawning at wave boundaries
      if (isBossWave && !_didMegaBossForWave.contains(wave)) {
        _spawnMegaBoss(wave);
        _didMegaBossForWave.add(wave);
      } else if (isMiniBossWave && !_didMiniBossForWave.contains(wave)) {
        _spawnMiniBoss(wave);
        _didMiniBossForWave.add(wave);
      }

      // Tiny elite pack every 5 waves (5, 15, 25...) – feels special, not spammy
      if (wave >= 5 && isMiniBossWave && !_didElitePackForWave.contains(wave)) {
        _spawnElitePack(wave);
        _didElitePackForWave.add(wave);
      }
    }

    // Boss / miniboss waves: slightly slower spawn rate so boss stands out
    final bool isAnyBossWave = wave % 5 == 0;
    final waveFactor = (1.0 - (wave - 1) * 0.012).clamp(0.4, 1.0);
    final baseSpawnRate = 1.8 * waveFactor;
    final currentSpawnRate = isAnyBossWave
        ? baseSpawnRate * 1.6
        : baseSpawnRate;

    _timer += dt;

    if (_timer >= currentSpawnRate) {
      _timer = 0;
      _spawnTick(wave);
    }
  }

  void _spawnTick(int wave) {
    // One "special" formation pattern per wave max
    if (!_didPatternForWave.contains(wave) && wave >= 2) {
      if (_trySpawnFormation(wave)) {
        _didPatternForWave.add(wave);
        return;
      }
    }

    _spawnTacticalGroup(wave);
  }

  void _spawnTacticalGroup(int wave) {
    final int tier = _pickTierForWave(wave); // swarm / brute only
    final style = _waveStyleFor(wave);
    final bool isBossWave = wave % 5 == 0;

    int baseCount;
    switch (style) {
      case WaveStyle.tactical:
        baseCount = 8 + _rng.nextInt(5);
        break;
      case WaveStyle.reinforced:
        baseCount = 10 + _rng.nextInt(5);
        break;
      case WaveStyle.flanking:
        _spawnFlankingGroup(wave, tier);
        return;
      case WaveStyle.escort:
        _spawnEscortGroup(wave, tier);
        return;
      case WaveStyle.normal:
      default:
        baseCount = 6 + _rng.nextInt(4);
    }

    // Boss waves: fewer trash mobs so arena stays readable
    final count = isBossWave ? max(3, (baseCount * 0.55).round()) : baseCount;

    final angle = _rng.nextDouble() * pi * 2;
    final dist =
        _minSpawnDist + _rng.nextDouble() * (_maxSpawnDist - _minSpawnDist);
    final centerPos = Vector2(cos(angle), sin(angle)) * dist;

    for (int i = 0; i < count; i++) {
      final offset = Vector2(
        _rng.nextDouble() * 120 - 60,
        _rng.nextDouble() * 120 - 60,
      );
      _spawnEnemy(tier: tier, wave: wave, position: centerPos + offset);
    }
  }

  void _spawnFlankingGroup(int wave, int tier) {
    final angle1 = _rng.nextDouble() * pi * 2;
    final angle2 = angle1 + pi + (_rng.nextDouble() - 0.5) * 0.5;
    final dist = _minSpawnDist;
    final countPerSide = 6 + _rng.nextInt(3);

    for (final angle in [angle1, angle2]) {
      final centerPos = Vector2(cos(angle), sin(angle)) * dist;
      for (int i = 0; i < countPerSide; i++) {
        final offset = Vector2(
          _rng.nextDouble() * 100 - 50,
          _rng.nextDouble() * 100 - 50,
        );
        _spawnEnemy(tier: tier, wave: wave, position: centerPos + offset);
      }
    }
  }

  void _spawnEscortGroup(int wave, int tier) {
    final angle = _rng.nextDouble() * pi * 2;
    final dist = _minSpawnDist;
    final centerPos = Vector2(cos(angle), sin(angle)) * dist;

    // Slightly bigger “captain” brute, not enormous
    _spawnEnemy(
      tier: min(2, tier + 1), // keep captain in swarm/brute band
      wave: wave,
      position: centerPos,
      sizeScale: 2.0,
    );

    final escortCount = 6 + _rng.nextInt(4);
    for (int i = 0; i < escortCount; i++) {
      final escortAngle = (i / escortCount) * pi * 2;
      final escortPos =
          centerPos + Vector2(cos(escortAngle), sin(escortAngle)) * 100;
      _spawnEnemy(tier: max(1, tier - 1), wave: wave, position: escortPos);
    }
  }

  WaveStyle _waveStyleFor(int wave) {
    // Boss / miniboss waves focus on the boss, use simpler patterns
    if (wave % 10 == 0 || wave % 5 == 0) return WaveStyle.normal;

    final styleIndex = wave % 8;
    switch (styleIndex) {
      case 1:
        return WaveStyle.tactical;
      case 2:
        return WaveStyle.normal;
      case 3:
        return WaveStyle.flanking;
      case 4:
        return WaveStyle.reinforced;
      case 5:
        return WaveStyle.tactical;
      case 6:
        return WaveStyle.escort;
      case 7:
        return WaveStyle.flanking;
      default:
        return WaveStyle.normal;
    }
  }

  bool _trySpawnFormation(int wave) {
    if (wave < 2) return false;

    final formations = [
      _spawnPincerFormation,
      _spawnArcFormation,
      _spawnDiamondFormation,
      _spawnWedgeFormation,
      _spawnLineFormation,
      _spawnCrescentFormation,
      _spawnTriangleFormation,
      _spawnDoubleLineFormation,
    ];

    int idx = (wave ~/ 2) % formations.length;
    if (idx == _lastFormationIndex) {
      idx = (idx + 1) % formations.length;
    }
    _lastFormationIndex = idx;

    // Don’t force a pattern every wave; keep them special
    if (_rng.nextDouble() < 0.5) {
      formations[idx](wave);
      return true;
    }
    return false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FORMATIONS (mostly unchanged, but only use swarm / brutes for trash)
  // ═══════════════════════════════════════════════════════════════════════════

  void _spawnPincerFormation(int wave) {
    final tier = _pickTierForWave(wave);
    final perArm = 6 + (wave ~/ 6);

    for (int arm = 0; arm < 2; arm++) {
      final baseAngle = arm * pi;
      final arcWidth = pi * 0.5;

      for (int i = 0; i < perArm; i++) {
        final t = perArm == 1 ? 0.5 : i / (perArm - 1);
        final angle = baseAngle - arcWidth / 2 + arcWidth * t;
        final dist = _minSpawnDist + _rng.nextDouble() * 100;
        final pos = Vector2(cos(angle), sin(angle)) * dist;
        _spawnEnemy(tier: tier, wave: wave, position: pos);
      }
    }
  }

  void _spawnArcFormation(int wave) {
    final tier = _pickTierForWave(wave);
    final count = 12 + (wave ~/ 5);
    final baseAngle = _rng.nextDouble() * pi * 2;
    final arcWidth = pi * 0.8;
    final dist = _minSpawnDist;

    for (int i = 0; i < count; i++) {
      final t = count == 1 ? 0.5 : i / (count - 1);
      final angle = baseAngle - arcWidth / 2 + arcWidth * t;
      final pos = Vector2(cos(angle), sin(angle)) * dist;
      _spawnEnemy(tier: tier, wave: wave, position: pos);
    }
  }

  void _spawnDiamondFormation(int wave) {
    final tier = _pickTierForWave(wave);
    final sideCount = 5 + (wave ~/ 8);
    final baseAngle = _rng.nextDouble() * pi * 2;
    final dist = _minSpawnDist;

    final corners = [
      Vector2(0, -1),
      Vector2(1, 0),
      Vector2(0, 1),
      Vector2(-1, 0),
    ];

    for (int side = 0; side < 4; side++) {
      final start = corners[side] * dist;
      final end = corners[(side + 1) % 4] * dist;

      for (int i = 0; i < sideCount; i++) {
        final t = i / (sideCount - 1);
        var pos = start + (end - start) * t;
        final rotated = Vector2(
          pos.x * cos(baseAngle) - pos.y * sin(baseAngle),
          pos.x * sin(baseAngle) + pos.y * cos(baseAngle),
        );
        _spawnEnemy(tier: tier, wave: wave, position: rotated);
      }
    }
  }

  void _spawnWedgeFormation(int wave) {
    final tier = _pickTierForWave(wave);
    final rows = 4 + (wave ~/ 10);
    final angle = _rng.nextDouble() * pi * 2;
    final baseDist = _minSpawnDist;

    for (int row = 0; row < rows; row++) {
      final enemiesInRow = row + 1;
      final rowDist = baseDist + row * 70;
      final spread = row * 60;

      for (int i = 0; i < enemiesInRow; i++) {
        final lateralOffset =
            (i - (enemiesInRow - 1) / 2) *
            (spread / max(1, enemiesInRow - 1) * 2);
        final perpAngle = angle + pi / 2;

        final pos =
            Vector2(cos(angle), sin(angle)) * rowDist +
            Vector2(cos(perpAngle), sin(perpAngle)) * lateralOffset;
        _spawnEnemy(tier: tier, wave: wave, position: pos);
      }
    }
  }

  void _spawnLineFormation(int wave) {
    final tier = _pickTierForWave(wave);
    final count = 10 + (wave ~/ 6);
    final angle = _rng.nextDouble() * pi * 2;
    final perpAngle = angle + pi / 2;
    final dist = _minSpawnDist;
    final lineWidth = count * 50.0;

    final centerPos = Vector2(cos(angle), sin(angle)) * dist;

    for (int i = 0; i < count; i++) {
      final offset = (i - (count - 1) / 2) * (lineWidth / (count - 1));
      final pos = centerPos + Vector2(cos(perpAngle), sin(perpAngle)) * offset;
      _spawnEnemy(tier: tier, wave: wave, position: pos);
    }
  }

  void _spawnCrescentFormation(int wave) {
    final tier = _pickTierForWave(wave);
    final count = 14 + (wave ~/ 6);
    final baseAngle = _rng.nextDouble() * pi * 2;
    final arcWidth = pi * 1.0;

    for (int i = 0; i < count; i++) {
      final t = count == 1 ? 0.5 : i / (count - 1);
      final angle = baseAngle - arcWidth / 2 + arcWidth * t;
      final distVariance = sin(t * pi) * 160;
      final dist = _minSpawnDist - distVariance;
      final pos = Vector2(cos(angle), sin(angle)) * dist;
      _spawnEnemy(tier: tier, wave: wave, position: pos);
    }
  }

  void _spawnTriangleFormation(int wave) {
    final tier = _pickTierForWave(wave);
    final perSide = 6 + (wave ~/ 8);
    final baseAngle = _rng.nextDouble() * pi * 2;
    final size = 320.0;

    final corners = <Vector2>[];
    for (int c = 0; c < 3; c++) {
      final cornerAngle = baseAngle + c * (pi * 2 / 3);
      corners.add(Vector2(cos(cornerAngle), sin(cornerAngle)) * size);
    }

    final offset = Vector2(cos(baseAngle), sin(baseAngle)) * _minSpawnDist;

    for (int side = 0; side < 3; side++) {
      final start = corners[side];
      final end = corners[(side + 1) % 3];

      for (int i = 0; i < perSide; i++) {
        final t = i / (perSide - 1);
        final pos = start + (end - start) * t + offset;
        _spawnEnemy(tier: tier, wave: wave, position: pos);
      }
    }
  }

  void _spawnDoubleLineFormation(int wave) {
    final tier = _pickTierForWave(wave);
    final perLine = 8 + (wave ~/ 7);
    final angle = _rng.nextDouble() * pi * 2;
    final perpAngle = angle + pi / 2;
    final lineWidth = perLine * 50.0;

    for (int line = 0; line < 2; line++) {
      final dist = _minSpawnDist + line * 140;
      final centerPos = Vector2(cos(angle), sin(angle)) * dist;

      for (int i = 0; i < perLine; i++) {
        final offset = (i - (perLine - 1) / 2) * (lineWidth / (perLine - 1));
        final pos =
            centerPos + Vector2(cos(perpAngle), sin(perpAngle)) * offset;
        _spawnEnemy(tier: tier, wave: wave, position: pos);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ELITE PACKS (Tier 3 - rare, small groups every 5 waves)
  // ═══════════════════════════════════════════════════════════════════════════

  void _spawnElitePack(int wave) {
    // Tiny, spicy elite group – 2 or 3 enemies.
    final count = wave >= 25 ? 3 : 2;
    final tier = 3; // Elite
    final angle = _rng.nextDouble() * pi * 2;
    final dist =
        _minSpawnDist + _rng.nextDouble() * (_maxSpawnDist - _minSpawnDist);
    final centerPos = Vector2(cos(angle), sin(angle)) * dist;

    if (debugSpawns) {
      print('  >> ELITE PACK (tier 3) at wave $wave, count=$count');
    }

    for (int i = 0; i < count; i++) {
      final offsetAngle = angle + (i - (count - 1) / 2) * 0.3;
      final pos =
          centerPos + Vector2(cos(offsetAngle), sin(offsetAngle)) * 80.0;
      _spawnEnemy(tier: tier, wave: wave, position: pos);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOSS SPAWNING - tuned to match simpler boss AI + sizes
  // ═══════════════════════════════════════════════════════════════════════════

  void _spawnMiniBoss(int wave) {
    if (debugSpawns) print('  >> MINI-BOSS at wave $wave');

    final tier = _getMiniBossTier(wave);
    final template = SurvivalEnemyCatalog.getRandomTemplateForTier(tier);
    final unit = SurvivalEnemyCatalog.buildMiniBoss(
      template: template,
      wave: wave,
    );

    // Spawn far away for dramatic entrance
    final angle = _rng.nextDouble() * pi * 2;
    final dist = _minSpawnDist + 250;
    final pos = Vector2(cos(angle), sin(angle)) * dist;

    // Reasonable size; scales slowly with wave
    final sizeScale = (2.8 + wave * 0.04).clamp(2.8, 4.2);

    final enemy = HoardEnemy(
      position: pos,
      targetOrb: gameRef.orb,
      unit: unit,
      template: template,
      role: EnemyRole.charger,
      sizeScale: sizeScale,
      speedMultiplier: 0.6,
    );

    enemy.isMiniBoss = true;
    gameRef.addHoardEnemy(enemy);

    // Light escort ring after entrance, not a full army
    Future.delayed(const Duration(milliseconds: 2200), () {
      final escortCount = 4 + (wave ~/ 12);
      for (int i = 0; i < escortCount; i++) {
        final escortAngle = (i / escortCount) * pi * 2;
        final escortPos =
            pos + Vector2(cos(escortAngle), sin(escortAngle)) * 220;
        _spawnEnemy(
          tier: max(1, min(2, tier - 1)), // escorts are swarm / brutes
          wave: wave,
          position: escortPos,
        );
      }
    });
  }

  void _spawnMegaBoss(int wave) {
    if (debugSpawns) print('  >> MEGA-BOSS at wave $wave');

    final tier = _getMegaBossTier(wave);
    final template = SurvivalEnemyCatalog.getRandomTemplateForTier(tier);
    final unit = SurvivalEnemyCatalog.buildMegaBoss(
      template: template,
      wave: wave,
    );

    // Select archetype based on wave (even if AI is simple now, we keep this for flavor/role)
    final archetype = _getBossArchetype(wave);

    // Spawn even further back for mega boss
    final angle = _rng.nextDouble() * pi * 2;
    final dist = _minSpawnDist + 450;
    final pos = Vector2(cos(angle), sin(angle)) * dist;

    // BIG, but not “break the game” big
    final sizeScale = (4.0 + wave * 0.05).clamp(4.0, 6.0);

    final enemy = HoardEnemy(
      position: pos,
      targetOrb: gameRef.orb,
      unit: unit,
      template: template,
      role: archetype == BossArchetype.artillery
          ? EnemyRole.shooter
          : EnemyRole.charger,
      sizeScale: sizeScale,
      bossArchetype: archetype,
      isMegaBoss: true,
      speedMultiplier: 0.4,
    );

    enemy.isBoss = true;
    gameRef.addHoardEnemy(enemy);

    _spawnBossMinionWaves(pos, wave, tier);
  }

  void _spawnBossMinionWaves(Vector2 bossPos, int wave, int tier) {
    // Wave 1: modest immediate minions
    Future.delayed(const Duration(milliseconds: 3200), () {
      final count = 5 + (wave ~/ 10);
      for (int i = 0; i < count; i++) {
        final angle = (i / count) * pi * 2;
        final pos = bossPos + Vector2(cos(angle), sin(angle)) * 320;
        _spawnEnemy(
          tier: max(1, min(3, tier - 2)), // mostly swarm/brutes, maybe elite
          wave: wave,
          position: pos,
        );
      }
    });

    // Wave 2: outer ring, slightly stronger
    Future.delayed(const Duration(milliseconds: 6200), () {
      final count = 6 + (wave ~/ 10);
      for (int i = 0; i < count; i++) {
        final angle = (i / count) * pi * 2 + pi / count;
        final pos = bossPos + Vector2(cos(angle), sin(angle)) * 420;
        _spawnEnemy(
          tier: max(
            1,
            min(3, tier - 1),
          ), // can dip into elites here later waves
          wave: wave,
          position: pos,
        );
      }
    });
  }

  int _getMiniBossTier(int wave) {
    if (wave < 10) return 2; // early mini-boss = tough brute
    if (wave < 20) return 3; // midgame = elite blob
    if (wave < 35) return 4; // late midgame
    return 5; // deep run mini-bosses scale up
  }

  int _getMegaBossTier(int wave) {
    if (wave < 15) return 3;
    if (wave < 25) return 4;
    return 5;
  }

  /// Cycle through archetypes so players face different challenges
  BossArchetype _getBossArchetype(int wave) {
    // Wave 10: Juggernaut (learn to dodge charges)
    // Wave 20: Summoner (learn to clear adds)
    // Wave 30: Artillery (learn to reposition)
    // Then cycle
    final bossNumber = wave ~/ 10;
    final archetypeIndex = (bossNumber - 1) % 3;
    return BossArchetype.values[archetypeIndex];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  void _spawnEnemy({
    required int tier,
    required int wave,
    required Vector2 position,
    double sizeScale = 1.0,
    bool forceShooter = false,
  }) {
    final template = SurvivalEnemyCatalog.getRandomTemplateForTier(tier);
    final role = forceShooter
        ? EnemyRole.shooter
        : _determineRole(template, wave);

    final unit = SurvivalEnemyCatalog.buildEnemy(
      template: template,
      tier: tier,
      wave: wave,
      isShooter: role == EnemyRole.shooter,
    );

    final enemy = HoardEnemy(
      position: position,
      targetOrb: gameRef.orb,
      unit: unit,
      template: template,
      role: role,
      sizeScale: sizeScale,
    );

    gameRef.addHoardEnemy(enemy);
  }

  /// Normal trash: only Swarm (tier 1) and Brute (tier 2).
  /// Elites are spawned explicitly via _spawnElitePack so they feel special.
  int _pickTierForWave(int wave) {
    // Waves 1–9: pure swarm
    if (wave < 10) {
      return 1;
    }

    // Waves 10–24: mostly swarm, some brutes
    if (wave < 25) {
      return _rng.nextDouble() < 0.7 ? 1 : 2;
    }

    // Waves 25+: mostly brutes, some swarm
    return _rng.nextDouble() < 0.3 ? 1 : 2;
  }

  EnemyRole _determineRole(SurvivalEnemyTemplate template, int wave) {
    double shooterBias = 0.06;

    switch (template.element) {
      case 'Air':
      case 'Lightning':
      case 'Spirit':
        shooterBias += 0.05;
        break;
      case 'Earth':
      case 'Plant':
      case 'Mud':
        shooterBias -= 0.02;
        break;
    }

    shooterBias = shooterBias.clamp(0.04, 0.14);
    return _rng.nextDouble() < shooterBias
        ? EnemyRole.shooter
        : EnemyRole.charger;
  }
}
