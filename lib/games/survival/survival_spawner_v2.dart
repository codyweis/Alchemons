import 'dart:math' show pow, max, min, cos, sin, pi, Random, sqrt;

import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/games/survival/components/black_hole_spawner.dart';
import 'package:flame/components.dart';
import 'package:alchemons/games/survival/survival_game.dart';
import 'package:alchemons/games/survival/enemies/survival_enemies.dart';

enum WaveStyle { normal, tactical, reinforced, flanking, escort }

class ImprovedSurvivalSpawner extends Component
    with HasGameRef<SurvivalHoardGame> {
  static const bool debugSpawns = false;
  double _timer = 0;
  final Random _rng = Random();

  static const double _minSpawnDist = 2000.0;
  static const double _maxSpawnDist = 2000.0;

  final Set<int> _didPatternForWave = {};
  final Set<int> _didMiniBossForWave = {};
  final Set<int> _didMegaBossForWave = {};
  final Set<int> _didElitePackForWave = {};
  int _lastWave = 0;
  int _lastFormationIndex = -1;

  int _spawnedThisWave = 0;
  int _waveSpawnBudget = 0;

  @override
  void update(double dt) {
    if (gameRef.isGameOver || gameRef.isInAlchemyPause) return;

    final wave = gameRef.currentWave;

    // Wave change - reset budget
    if (wave != _lastWave) {
      if (debugSpawns) print('==== WAVE $wave ====');
      _lastWave = wave;
      _spawnedThisWave = 0;
      _waveSpawnBudget = _getBudgetForWave(wave);

      final isBossWave = wave > 0 && wave % 10 == 0;
      final isMiniBossWave = wave > 0 && wave % 5 == 0 && wave % 10 != 0;

      if (isBossWave && !_didMegaBossForWave.contains(wave)) {
        _spawnMegaBoss(wave);
        _didMegaBossForWave.add(wave);
      } else if (isMiniBossWave && !_didMiniBossForWave.contains(wave)) {
        _spawnMiniBoss(wave);
        _didMiniBossForWave.add(wave);
      }

      if (wave >= 5 && isMiniBossWave && !_didElitePackForWave.contains(wave)) {
        _spawnElitePack(wave);
        _didElitePackForWave.add(wave);
      }
    }

    // Stop spawning if budget exhausted
    if (_spawnedThisWave >= _waveSpawnBudget) return;

    // Rest of spawn timing logic stays the same...
    final bool isAnyBossWave = wave % 5 == 0;

    const double kBaseSpawnInterval = 0.5;
    const double kSpawnRampRate = 0.01;
    const double kMinSpawnInterval = 0.25;

    final waveFactor = (kBaseSpawnInterval - (wave - 1) * kSpawnRampRate).clamp(
      kMinSpawnInterval,
      kBaseSpawnInterval,
    );

    final spawnRateBase = isAnyBossWave ? waveFactor * 1.6 : waveFactor;
    final currentSpawnRate = spawnRateBase;

    _timer += dt;

    if (_timer >= currentSpawnRate) {
      _timer = 0;
      _spawnTick(wave);
    }
  }

  int _getBudgetForWave(int wave) {
    // Tune these numbers to taste
    const int baseEnemies = 50;
    const int perWaveIncrease = 1;
    const int maxBudget = 200;

    // Boss waves get fewer trash mobs
    final isBossWave = wave % 5 == 0;
    final multiplier = isBossWave ? 0.25 : 1.0;

    final budget = ((baseEnemies + (wave - 1) * perWaveIncrease) * multiplier)
        .round()
        .clamp(10, maxBudget);

    if (debugSpawns) print('  Wave $wave budget: $budget');
    return budget;
  }

  // Then in _spawnEnemy, track the count:
  void _spawnEnemy({
    required int tier,
    required int wave,
    required Vector2 position,
    double sizeScale = 1.0,
    EnemyRole? forceRole,
  }) {
    // Budget check (safety)
    if (_spawnedThisWave >= _waveSpawnBudget) return;

    final template = SurvivalEnemyCatalog.getRandomTemplateForTier(tier);
    final role = forceRole ?? _determineRole(template, wave);

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
    _spawnedThisWave++;
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

    final densityScale = _waveDensityScale(wave);

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
        if (_rng.nextBool()) {
          _spawnTacticalGroupFromBlackHole(wave);
        }
        return;
    }

    // NEW: multiply by density so waves 6+ bring more bodies
    int count = (baseCount * densityScale).round();

    // Boss waves: fewer trash mobs so arena stays readable
    count = isBossWave ? max(3, (count * 0.55).round()) : count;

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

    // Chance to spawn bomber squad (wave 8+)
    if (wave >= 8 && _rng.nextDouble() < _bomberChance(wave)) {
      _spawnBomberSquad(wave, centerPos);
    }

    // Chance to spawn leecher pack (wave 12+)
    if (wave >= 12 && _rng.nextDouble() < _leecherChance(wave)) {
      _spawnLeecherPack(wave, centerPos);
    }
  }

  double _bomberChance(int wave) {
    // Starts at 8% wave 8, scales to ~20% by wave 30
    return (0.08 + (wave - 8) * 0.004).clamp(0.0, 0.20);
  }

  double _leecherChance(int wave) {
    // Starts at 6% wave 12, scales to ~15% by wave 35
    return (0.06 + (wave - 12) * 0.004).clamp(0.0, 0.15);
  }

  void _spawnBomberSquad(int wave, Vector2 nearPos) {
    final count = 2 + (wave ~/ 15); // 2-4 bombers
    final tier = _pickTierForWave(wave);

    if (debugSpawns) print('  >> BOMBER SQUAD x$count');

    for (int i = 0; i < count; i++) {
      final offset = Vector2(
        _rng.nextDouble() * 80 - 40,
        _rng.nextDouble() * 80 - 40,
      );
      _spawnEnemy(
        tier: tier,
        wave: wave,
        position: nearPos + offset,
        forceRole: EnemyRole.bomber,
      );
    }
  }

  void _spawnLeecherPack(int wave, Vector2 nearPos) {
    final count = 1 + (wave ~/ 20); // 1-3 leechers
    final tier = _pickTierForWave(wave);

    if (debugSpawns) print('  >> LEECHER PACK x$count');

    for (int i = 0; i < count; i++) {
      final offset = Vector2(
        _rng.nextDouble() * 60 - 30,
        _rng.nextDouble() * 60 - 30,
      );
      _spawnEnemy(
        tier: tier,
        wave: wave,
        position: nearPos + offset,
        forceRole: EnemyRole.leecher,
      );
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

    // Flanking attacks sometimes include bombers for pressure
    if (wave >= 10 && _rng.nextDouble() < 0.3) {
      final bomberPos = Vector2(cos(angle1), sin(angle1)) * dist;
      _spawnBomberSquad(wave, bomberPos);
    }
  }

  void _spawnEscortGroup(int wave, int tier) {
    final angle = _rng.nextDouble() * pi * 2;
    final dist = _minSpawnDist;
    final centerPos = Vector2(cos(angle), sin(angle)) * dist;

    // Slightly bigger "captain" brute, not enormous
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

    // Escort groups sometimes have a leecher attached
    if (wave >= 15 && _rng.nextDouble() < 0.25) {
      _spawnEnemy(
        tier: tier,
        wave: wave,
        position: centerPos + Vector2(50, 50),
        forceRole: EnemyRole.leecher,
      );
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

    // Don't force a pattern every wave; keep them special
    if (_rng.nextDouble() < 0.5) {
      formations[idx](wave);
      return true;
    }
    return false;
  }

  //
  // FORMATIONS (mostly unchanged, but only use swarm / brutes for trash)
  //

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

    // Pincer can have bombers rushing through the middle
    if (wave >= 12 && _rng.nextDouble() < 0.4) {
      final midAngle = _rng.nextDouble() * pi * 2;
      final midPos = Vector2(cos(midAngle), sin(midAngle)) * _minSpawnDist;
      _spawnBomberSquad(wave, midPos);
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

    // Wedge tip can have a bomber leading the charge
    if (wave >= 10 && _rng.nextDouble() < 0.35) {
      final tipPos = Vector2(cos(angle), sin(angle)) * (baseDist - 50);
      _spawnEnemy(
        tier: tier,
        wave: wave,
        position: tipPos,
        forceRole: EnemyRole.bomber,
      );
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

    // Crescent center can have leechers lurking
    if (wave >= 15 && _rng.nextDouble() < 0.3) {
      final centerPos =
          Vector2(cos(baseAngle), sin(baseAngle)) * (_minSpawnDist - 160);
      _spawnLeecherPack(wave, centerPos);
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

  //
  // ELITE PACKS (Tier 3 - rare, small groups every 5 waves)
  //

  void _spawnElitePack(int wave) {
    // Tiny, spicy elite group â€“ 2 or 3 enemies.
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

  //
  // BOSS SPAWNING - tuned to match simpler boss AI + sizes
  //

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

      // Mini-boss escort can include a bomber or two
      if (wave >= 15 && _rng.nextDouble() < 0.4) {
        _spawnEnemy(
          tier: 1,
          wave: wave,
          position: pos + Vector2(180, 0),
          forceRole: EnemyRole.bomber,
        );
      }
    });
  }

  void _spawnTacticalGroupFromBlackHole(int wave) {
    final int tier = _pickTierForWave(wave);
    final style = _waveStyleFor(wave);
    final densityScale = _waveDensityScale(wave);

    int baseCount;
    switch (style) {
      case WaveStyle.tactical:
        baseCount = 8 + _rng.nextInt(5);
        break;
      case WaveStyle.reinforced:
        baseCount = 10 + _rng.nextInt(5);
        break;
      default:
        baseCount = 6 + _rng.nextInt(4);
    }

    int count = (baseCount * densityScale).round();
    final bool isBossWave = wave % 5 == 0;
    count = isBossWave ? max(3, (count * 0.55).round()) : count;

    final angle = _rng.nextDouble() * pi * 2;
    final dist = _minSpawnDist;
    final centerPos = Vector2(cos(angle), sin(angle)) * dist;

    // Determine black hole color based on dominant element this wave
    final element = allElements[_rng.nextInt(allElements.length)];
    final color = BreedConstants.getTypeColor(element);

    // Spawn the black hole
    final blackHole = BlackHoleSpawner(
      position: centerPos,
      accentColor: color,
      enemyCount: count,
      radius: 60.0 + (wave * 0.5).clamp(0, 40), // Grows slightly with wave
      spawnInterval: 0.25, // Enemies pour out quickly
      formDuration: 1.0,
      activeDuration: count * 0.3 + 1.0, // Duration scales with enemy count
      collapseDuration: 0.6,
      onSpawnEnemy: (pos) {
        // Add slight randomness to spawn position
        final offset = Vector2(
          _rng.nextDouble() * 60 - 30,
          _rng.nextDouble() * 60 - 30,
        );
        _spawnEnemy(tier: tier, wave: wave, position: pos + offset);
      },
    );

    gameRef.world.add(blackHole);
  }

  void _spawnMegaBoss(int wave) {
    if (debugSpawns) print('  >> MEGA-BOSS at wave $wave');

    final tier = _getMegaBossTier(wave);
    final template = SurvivalEnemyCatalog.getRandomTemplateForTier(tier);

    // Spawn even further back for mega boss
    final angle = _rng.nextDouble() * pi * 2;
    final dist = _minSpawnDist + 450;
    final pos = Vector2(cos(angle), sin(angle)) * dist;

    // Select archetype based on wave
    final archetype = _getBossArchetype(wave);

    // ─────────────────────────────────────────────────────────
    // HYDRA BOSS SPECIAL CASE
    // ─────────────────────────────────────────────────────────
    if (archetype == BossArchetype.hydra) {
      // Build the generation 0 Hydra boss (massive, tanky).
      final unit = SurvivalEnemyCatalog.buildHydraBoss(
        template: template,
        wave: wave,
        generation: 0,
      );

      // IMPORTANT: sizeScale here is moderate; the hydra radius helper
      // multiplies again (3x for gen 0), so don't double-dip too hard.
      final sizeScale = (3.0 + wave * 0.03).clamp(3.0, 4.5);

      final hydra = HoardEnemy(
        position: pos,
        targetOrb: gameRef.orb,
        unit: unit,
        template: template,
        role: EnemyRole.charger, // melee bruiser that slams + volleys
        sizeScale: sizeScale,
        bossArchetype: BossArchetype.hydra,
        isMegaBoss: true,
        speedMultiplier: 0.35,
        hydraGeneration: 0,
      );

      hydra.isBoss = true;
      gameRef.addHoardEnemy(hydra);

      // Performance: Hydra supplies its own "adds" via splitting.
      // We *skip* boss minion waves so the arena doesn't get insane.
      return;
    }

    // ─────────────────────────────────────────────────────────
    // NORMAL MEGA BOSS (juggernaut / summoner / artillery)
    // ─────────────────────────────────────────────────────────

    final unit = SurvivalEnemyCatalog.buildMegaBoss(
      template: template,
      wave: wave,
    );

    // BIG, but not "break the game" big
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

    // For non-Hydra bosses we still run minion support waves
    _spawnBossMinionWaves(pos, wave, tier);
  }

  /// PERFORMANCE-FRIENDLY DENSITY - caps at 2.0x, difficulty comes from bosses

  double _waveDensityScale(int wave) {
    return 0.9;
    // Before wave 10 → base value
    // if (wave < 5) return 0.5;
    // if (wave < 10) return 0.8;
    // if (wave < 15) return 1;

    // const startWave = 15;
    // const endValue = 1.1;
    // const startValue = 1.0;

    // // Choose the wave where you want to *reach* the cap.
    // // Example: reach cap by wave 50.
    // const capWave = 50;

    // // Linear progression from wave 10 to capWave
    // final t = ((wave - startWave) / (capWave - startWave)).clamp(0.0, 1.0);

    // final value = startValue + (endValue - startValue) * t;

    // return value;
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

      // Boss minion wave includes bombers for pressure
      if (wave >= 20) {
        for (int i = 0; i < 2; i++) {
          final bomberAngle = _rng.nextDouble() * pi * 2;
          final bomberPos =
              bossPos + Vector2(cos(bomberAngle), sin(bomberAngle)) * 350;
          _spawnEnemy(
            tier: 1,
            wave: wave,
            position: bomberPos,
            forceRole: EnemyRole.bomber,
          );
        }
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

      // Later waves add leechers to boss fights
      if (wave >= 30) {
        _spawnLeecherPack(wave, bossPos + Vector2(300, 0));
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
    // return BossArchetype.hydra;
    final bossNumber = wave ~/ 10; // 1 for wave 10, 2 for 20, etc.

    // Every 4th boss: special Hydra fight
    if (bossNumber > 0 && bossNumber % 4 == 0) {
      return BossArchetype.hydra;
    }

    // Otherwise cycle juggernaut -> summoner -> artillery
    const cycle = [
      BossArchetype.juggernaut,
      BossArchetype.summoner,
      BossArchetype.artillery,
    ];
    final index = (bossNumber - 1).clamp(0, cycle.length - 1) % cycle.length;
    return cycle[index];
  }

  //
  // HELPERS
  //

  /// Normal trash: only Swarm (tier 1) and Brute (tier 2).
  /// Elites are spawned explicitly via _spawnElitePack so they feel special.
  int _pickTierForWave(int wave) {
    // Waves 1â€“9: pure swarm
    if (wave < 10) {
      return 1;
    }

    // Waves 10â€“24: mostly swarm, some brutes
    if (wave < 25) {
      return _rng.nextDouble() < 0.7 ? 1 : 2;
    }

    // Waves 25+: mostly brutes, some swarm
    return _rng.nextDouble() < 0.3 ? 1 : 2;
  }

  EnemyRole _determineRole(SurvivalEnemyTemplate template, int wave) {
    // Base chances for special roles
    double shooterBias = 0.06;
    double bomberBias = wave >= 8 ? 0.04 : 0.0;
    double leecherBias = wave >= 12 ? 0.03 : 0.0;

    // Element influences
    switch (template.element) {
      case 'Air':
      case 'Lightning':
      case 'Spirit':
        shooterBias += 0.05;
        break;
      case 'Fire':
      case 'Lava':
        bomberBias += 0.03; // Fire types more likely to be bombers
        break;
      case 'Blood':
      case 'Dark':
      case 'Poison':
        leecherBias += 0.04; // Vampiric elements more likely to leech
        break;
      case 'Earth':
      case 'Plant':
      case 'Mud':
        shooterBias -= 0.02;
        break;
    }

    shooterBias = shooterBias.clamp(0.01, 0.15);
    bomberBias = bomberBias.clamp(0.0, 0.10);
    leecherBias = leecherBias.clamp(0.0, 0.08);

    final roll = _rng.nextDouble();

    if (roll < bomberBias) {
      return EnemyRole.bomber;
    } else if (roll < bomberBias + leecherBias) {
      return EnemyRole.leecher;
    } else if (roll < bomberBias + leecherBias + shooterBias) {
      return EnemyRole.shooter;
    }

    return EnemyRole.charger;
  }
}
