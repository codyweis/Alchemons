// lib/games/survival/survival_spawner_v3.dart
//
// IMPROVED SPAWNER - Dramatic wave surges, not trickle spawns
//
import 'dart:math' show max, min, cos, sin, pi, Random;

import 'package:alchemons/constants/breed_constants.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/games/survival/survival_game.dart';
import 'package:alchemons/games/survival/enemies/survival_enemies.dart';

// ════════════════════════════════════════════════════════════════════════════
// WAVE TELEGRAPH - Visual warning before surge arrives
// ════════════════════════════════════════════════════════════════════════════

class WaveTelegraph extends PositionComponent {
  final Vector2 direction;
  final Color color;
  final double duration;

  double _time = 0;

  WaveTelegraph({
    required Vector2 position,
    required this.direction,
    required this.color,
    this.duration = 1.5,
  }) : super(position: position, anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (_time >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final progress = (_time / duration).clamp(0.0, 1.0);
    final alpha = sin(progress * pi);
    final pulse = 1.0 + sin(_time * 8) * 0.1;

    canvas.save();
    canvas.rotate(direction.angleTo(Vector2(1, 0)) + pi);
    canvas.scale(pulse);

    // Arrow shape
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(-120, -45)
      ..lineTo(-85, 0)
      ..lineTo(-120, 45)
      ..close();

    canvas.drawPath(path, Paint()..color = color.withOpacity(alpha * 0.6));
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withOpacity(alpha * 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Warning rings
    for (int i = 0; i < 3; i++) {
      final ringProgress = (progress + i * 0.2) % 1.0;
      canvas.drawCircle(
        const Offset(-70, 0),
        20 + ringProgress * 40,
        Paint()
          ..color = color.withOpacity((1.0 - ringProgress) * alpha * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    canvas.restore();
  }
}

// ════════════════════════════════════════════════════════════════════════════
// RIFT SPAWNER - Dramatic tear enemies pour through
// ════════════════════════════════════════════════════════════════════════════

class RiftSpawner extends PositionComponent {
  final Color color;
  final double width;
  final double height;
  final int enemyCount;
  final double spawnDuration;
  final void Function(Vector2 position) onSpawnEnemy;

  double _time = 0;
  int _phase = 0; // 0=forming, 1=active, 2=closing
  int _spawned = 0;
  double _spawnTimer = 0;
  double _riftOpenness = 0;

  final Random _rng = Random();
  final List<_RiftParticle> _particles = [];

  static const double formDuration = 0.8;
  static const double closeDuration = 0.5;

  RiftSpawner({
    required Vector2 position,
    required this.color,
    required this.onSpawnEnemy,
    this.width = 200,
    this.height = 80,
    this.enemyCount = 10,
    this.spawnDuration = 2.0,
  }) : super(
         position: position,
         size: Vector2(width * 1.5, height * 2),
         anchor: Anchor.center,
       );

  double get _spawnInterval => spawnDuration / enemyCount;

  @override
  Future<void> onLoad() async {
    for (int i = 0; i < 20; i++) _addParticle();
  }

  void _addParticle() {
    _particles.add(
      _RiftParticle(
        position: Vector2(
          (_rng.nextDouble() - 0.5) * width * 0.5,
          (_rng.nextDouble() - 0.5) * height * 0.3,
        ),
        velocity: Vector2(
          (_rng.nextDouble() - 0.5) * 100,
          -50 - _rng.nextDouble() * 100,
        ),
        size: 3 + _rng.nextDouble() * 5,
        life: 0.5 + _rng.nextDouble() * 0.5,
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;

    if (_phase == 0) {
      _riftOpenness = (_time / formDuration).clamp(0.0, 1.0);
      if (_time >= formDuration) {
        _phase = 1;
        _time = 0;
      }
    } else if (_phase == 1) {
      _riftOpenness = 1.0;
      _spawnTimer += dt;
      if (_spawnTimer >= _spawnInterval && _spawned < enemyCount) {
        _spawnTimer = 0;
        _spawned++;
        onSpawnEnemy(
          position +
              Vector2(
                (_rng.nextDouble() - 0.5) * width * 0.6,
                (_rng.nextDouble() - 0.5) * height * 0.3,
              ),
        );
        for (int i = 0; i < 5; i++) _addParticle();
      }
      if (_spawned >= enemyCount) {
        _phase = 2;
        _time = 0;
      }
    } else {
      _riftOpenness = 1.0 - (_time / closeDuration).clamp(0.0, 1.0);
      if (_time >= closeDuration) {
        removeFromParent();
        return;
      }
    }

    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.life -= dt;
      p.position += p.velocity * dt;
      if (p.life <= 0) _particles.removeAt(i);
    }

    if (_phase == 1 && _particles.length < 30) _addParticle();
  }

  @override
  void render(Canvas canvas) {
    final center = (size / 2).toOffset();
    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Glow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: width * 1.3 * _riftOpenness,
        height: height * 1.5 * _riftOpenness,
      ),
      Paint()..color = color.withOpacity(0.3 * _riftOpenness),
    );

    // Rift shape
    final path = _buildRiftPath();
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withOpacity(0.9 * _riftOpenness),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.8 * _riftOpenness)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    // Particles
    for (final p in _particles) {
      final alpha = (p.life * 2).clamp(0.0, 1.0) * _riftOpenness;
      canvas.drawCircle(
        p.position.toOffset(),
        p.size * alpha,
        Paint()..color = color.withOpacity(alpha * 0.8),
      );
    }

    canvas.restore();
  }

  Path _buildRiftPath() {
    final path = Path();
    final w = width * _riftOpenness;
    final h = height * _riftOpenness;

    path.moveTo(-w / 2, 0);
    for (int i = 1; i < 6; i++) {
      final t = i / 6;
      path.lineTo(-w / 2 + w * t, -h / 2 + sin(_time * 5 + i * 2) * h * 0.15);
    }
    path.lineTo(w / 2, 0);
    for (int i = 5; i > 0; i--) {
      final t = i / 6;
      path.lineTo(
        -w / 2 + w * t,
        h / 2 + sin(_time * 5 + i * 2 + pi) * h * 0.15,
      );
    }
    path.close();
    return path;
  }
}

class _RiftParticle {
  Vector2 position;
  Vector2 velocity;
  double size;
  double life;
  _RiftParticle({
    required this.position,
    required this.velocity,
    required this.size,
    required this.life,
  });
}

// ════════════════════════════════════════════════════════════════════════════
// SURGE TYPES
// ════════════════════════════════════════════════════════════════════════════

enum WaveSurgeType {
  flood,
  pincer,
  encircle,
  artillery,
  swarm,
  elite,
  boss,
  ring,
}

class WaveSurgeConfig {
  final WaveSurgeType type;
  final int enemyCount;
  final double spawnDuration;
  final double predelay;

  const WaveSurgeConfig({
    required this.type,
    required this.enemyCount,
    this.spawnDuration = 3.0,
    this.predelay = 1.5,
  });
}

// ════════════════════════════════════════════════════════════════════════════
// MAIN SPAWNER
// ════════════════════════════════════════════════════════════════════════════

class ImprovedSurvivalSpawner extends Component
    with HasGameRef<SurvivalHoardGame> {
  static const bool debugSpawns = false;
  static const double _spawnDistance = 2000.0;

  final Random _rng = Random();

  int _lastWave = 0;
  int _spawnedThisWave = 0;
  int _waveSpawnBudget = 0;

  bool _surgeActive = false;
  WaveSurgeConfig? _currentSurge;
  double _surgeTimer = 0;
  int _surgeSpawnCounter = 0;
  List<Vector2> _surgeDirections = [];

  double _timeSinceLastSurge = 0;
  double _nextSurgeDelay = 0;

  final Set<int> _didMiniBossForWave = {};
  final Set<int> _didMegaBossForWave = {};
  final Set<int> _didElitePackForWave = {};

  @override
  void update(double dt) {
    if (gameRef.isGameOver || gameRef.isInAlchemyPause) return;

    final wave = gameRef.currentWave;

    if (wave != _lastWave) _onWaveChange(wave);

    _timeSinceLastSurge += dt;

    if (_surgeActive) {
      _updateSurge(dt, wave);
    } else if (_spawnedThisWave < _waveSpawnBudget &&
        _timeSinceLastSurge >= _nextSurgeDelay) {
      _startNewSurge(wave);
    }
  }

  void _onWaveChange(int wave) {
    if (debugSpawns) print('==== WAVE $wave ====');

    _lastWave = wave;
    _spawnedThisWave = 0;
    _surgeActive = false;
    _timeSinceLastSurge = 0;
    // Longer opening pause on early waves so players can breathe
    _nextSurgeDelay = wave <= 5 ? 3.0 : (wave <= 10 ? 2.0 : 0.5);
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
      Future.delayed(
        const Duration(milliseconds: 3000),
        () => _spawnElitePack(wave),
      );
      _didElitePackForWave.add(wave);
    }
  }

  int _getBudgetForWave(int wave) {
    const maxBudget = 200;
    // Waves 1-5: gentle introduction — small rings to establish the pattern
    if (wave <= 5) {
      final base = 28 + (wave - 1) * 8; // 28, 36, 44, 52, 60
      final mult = wave % 5 == 0 ? 0.45 : 1.0; // wave 5 is mini-boss wave
      return (base * mult).round().clamp(15, 80);
    }
    // Waves 6-10: ramp up, but still measured
    if (wave <= 10) {
      final base = 45 + (wave - 6) * 8; // 45, 53, 61, 69, 77
      final mult = wave % 5 == 0 ? 0.35 : 1.0;
      return (base * mult).round().clamp(20, maxBudget);
    }
    final bool earlyPressure = wave <= 20;
    final int base = earlyPressure ? 58 : 40;
    final int perWave = earlyPressure ? 5 : 3;

    double mult = wave % 5 == 0 ? 0.3 : 1.0;
    if (earlyPressure && wave % 5 == 0) mult = 0.45;

    return ((base + (wave - 1) * perWave) * mult).round().clamp(
      earlyPressure ? 28 : 15,
      maxBudget,
    );
  }

  void _startNewSurge(int wave) {
    if (_spawnedThisWave >= _waveSpawnBudget) return;

    final remaining = _waveSpawnBudget - _spawnedThisWave;
    final surgeType = _pickSurgeType(wave);
    final surgeSize = _calculateSurgeSize(wave, surgeType, remaining);

    _currentSurge = WaveSurgeConfig(
      type: surgeType,
      enemyCount: surgeSize,
      spawnDuration: _getSurgeDuration(surgeType, surgeSize),
      predelay: _getSurgePredelay(surgeType),
    );

    _surgeActive = true;
    _surgeTimer = 0;
    _surgeSpawnCounter = 0;
    _surgeDirections = _getSurgeDirections(surgeType);

    if (debugSpawns) print('  >> SURGE: ${surgeType.name} x$surgeSize');

    _showTelegraphs(wave);
  }

  WaveSurgeType _pickSurgeType(int wave) {
    if (wave % 5 == 0) return WaveSurgeType.boss;

    final weights = <WaveSurgeType, double>{
      // Waves 1-7:  ring is the dominant surge type — surrounded feel
      // Waves 8-12: ring fades out as variety takes over
      // Waves 15-25: ring returns occasionally as a scary callback
      // Waves 26-35: rare ring for dramatic late-game moments
      WaveSurgeType.ring: wave <= 7
          ? 60
          : wave <= 12
          ? 18
          : wave <= 25
          ? 12
          : wave <= 35
          ? 6
          : 0,
      WaveSurgeType.flood: wave <= 7 ? 12 : 30,
      WaveSurgeType.swarm: wave <= 7 ? 18 : (wave < 10 ? 40 : 25),
      WaveSurgeType.pincer: wave >= 5 ? 20 : 5,
      WaveSurgeType.encircle: wave >= 8 ? 15 : 0,
      WaveSurgeType.artillery: wave >= 10 ? 10 : 0,
    };

    var roll = _rng.nextDouble() * weights.values.reduce((a, b) => a + b);
    for (final e in weights.entries) {
      roll -= e.value;
      if (roll <= 0) return e.key;
    }
    return WaveSurgeType.flood;
  }

  int _calculateSurgeSize(int wave, WaveSurgeType type, int maxBudget) {
    int base = switch (type) {
      // Ring scales gently early, then bigger as a rare late-game threat
      WaveSurgeType.ring => wave <= 10 ? 14 + wave * 2 : 20 + wave * 2,
      WaveSurgeType.swarm => 20 + wave,
      WaveSurgeType.flood => 15 + wave ~/ 2,
      WaveSurgeType.pincer => 12 + wave ~/ 2,
      WaveSurgeType.encircle => 16 + wave ~/ 2,
      WaveSurgeType.artillery => 10 + wave ~/ 3,
      WaveSurgeType.elite => 3 + wave ~/ 10,
      WaveSurgeType.boss => 8,
    };
    double pressureMult = 1.0;
    if (wave <= 20) {
      pressureMult = 1.2;
      if (type == WaveSurgeType.swarm ||
          type == WaveSurgeType.flood ||
          type == WaveSurgeType.pincer) {
        pressureMult += 0.1;
      }
    }

    return ((base * pressureMult * (0.8 + _rng.nextDouble() * 0.4)).round())
        .clamp(5, maxBudget);
  }

  double _getSurgeDuration(WaveSurgeType type, int count) => switch (type) {
    WaveSurgeType.ring => 2.5 + count * 0.06,
    WaveSurgeType.swarm => 1.5 + count * 0.05,
    WaveSurgeType.flood => 2.0 + count * 0.08,
    WaveSurgeType.pincer => 2.5 + count * 0.1,
    WaveSurgeType.encircle => 3.0 + count * 0.1,
    WaveSurgeType.artillery => 2.0 + count * 0.12,
    WaveSurgeType.elite => 2.0,
    WaveSurgeType.boss => 4.0,
  };

  double _getSurgePredelay(WaveSurgeType type) => switch (type) {
    WaveSurgeType.ring => 1.0,
    WaveSurgeType.swarm => 0.8,
    WaveSurgeType.flood => 1.2,
    WaveSurgeType.pincer => 1.5,
    WaveSurgeType.encircle => 2.0,
    WaveSurgeType.artillery => 1.5,
    WaveSurgeType.elite => 2.5,
    WaveSurgeType.boss => 0,
  };

  List<Vector2> _getSurgeDirections(WaveSurgeType type) {
    final angle = _rng.nextDouble() * 2 * pi;
    return switch (type) {
      WaveSurgeType.flood ||
      WaveSurgeType.swarm ||
      WaveSurgeType.artillery => [Vector2(cos(angle), sin(angle))],
      WaveSurgeType.pincer => [
        Vector2(cos(angle), sin(angle)),
        Vector2(cos(angle + pi), sin(angle + pi)),
      ],
      WaveSurgeType.encircle => List.generate(
        6,
        (i) => Vector2(cos(i / 6 * 2 * pi), sin(i / 6 * 2 * pi)),
      ),
      // Full 360° ring — 12 evenly-spaced spawn points
      WaveSurgeType.ring => List.generate(
        12,
        (i) =>
            Vector2(cos(angle + i / 12 * 2 * pi), sin(angle + i / 12 * 2 * pi)),
      ),
      _ => [],
    };
  }

  void _showTelegraphs(int wave) {
    for (final dir in _surgeDirections) {
      final element = allElements[_rng.nextInt(allElements.length)];
      gameRef.world.add(
        WaveTelegraph(
          position: dir * (_spawnDistance - 300),
          direction: dir,
          color: BreedConstants.getTypeColor(element),
          duration: _currentSurge?.predelay ?? 1.5,
        ),
      );
    }
  }

  void _updateSurge(double dt, int wave) {
    if (_currentSurge == null) {
      _surgeActive = false;
      return;
    }

    _surgeTimer += dt;
    if (_surgeTimer < _currentSurge!.predelay) return;

    final activeTime = _surgeTimer - _currentSurge!.predelay;
    final targetSpawned =
        (_currentSurge!.enemyCount *
                (activeTime / _currentSurge!.spawnDuration))
            .round();
    final toSpawn = targetSpawned - _surgeSpawnCounter;

    if (toSpawn > 0) _executeSurgeSpawn(wave, toSpawn);

    if (activeTime >= _currentSurge!.spawnDuration) _completeSurge();
  }

  void _executeSurgeSpawn(int wave, int count) {
    final type = _currentSurge?.type ?? WaveSurgeType.flood;
    final tier = _pickTierForWave(wave);

    switch (type) {
      case WaveSurgeType.flood:
      case WaveSurgeType.swarm:
        _spawnFlood(wave, tier, count);
      case WaveSurgeType.pincer:
        _spawnPincer(wave, tier, count);
      case WaveSurgeType.encircle:
        _spawnEncircle(wave, tier, count);
      case WaveSurgeType.artillery:
        _spawnArtillery(wave, tier, count);
      case WaveSurgeType.ring:
        _spawnRing(wave, tier, count);
      default:
        _spawnFlood(wave, tier, count);
    }

    _surgeSpawnCounter += count;
  }

  void _spawnFlood(int wave, int tier, int count) {
    if (_surgeDirections.isEmpty) return;
    final dir = _surgeDirections.first;
    final basePos = dir * _spawnDistance;

    if (_surgeSpawnCounter == 0 && count >= 5) {
      final element = allElements[_rng.nextInt(allElements.length)];
      gameRef.world.add(
        RiftSpawner(
          position: basePos,
          color: BreedConstants.getTypeColor(element),
          enemyCount: count,
          width: 250 + count * 5.0,
          spawnDuration: count * 0.15,
          onSpawnEnemy: (pos) =>
              _spawnEnemy(tier: tier, wave: wave, position: pos),
        ),
      );
    } else {
      for (int i = 0; i < count; i++) {
        final perpAngle = dir.angleTo(Vector2(1, 0)) + pi / 2;
        final offset =
            Vector2(cos(perpAngle), sin(perpAngle)) * ((i - count / 2) * 40);
        final jitter = Vector2(
          (_rng.nextDouble() - 0.5) * 60,
          (_rng.nextDouble() - 0.5) * 60,
        );
        _spawnEnemy(
          tier: tier,
          wave: wave,
          position: basePos + offset + jitter,
        );
      }
    }
  }

  void _spawnPincer(int wave, int tier, int count) {
    final perSide = count ~/ 2;
    for (int side = 0; side < min(2, _surgeDirections.length); side++) {
      final basePos = _surgeDirections[side] * _spawnDistance;
      for (int i = 0; i < perSide; i++) {
        _spawnEnemy(
          tier: tier,
          wave: wave,
          position:
              basePos +
              Vector2(
                (_rng.nextDouble() - 0.5) * 150,
                (_rng.nextDouble() - 0.5) * 150,
              ),
        );
      }
    }
  }

  void _spawnEncircle(int wave, int tier, int count) {
    final perDir = max(1, count ~/ _surgeDirections.length);
    for (final dir in _surgeDirections) {
      final basePos = dir * _spawnDistance;
      for (int i = 0; i < perDir; i++) {
        _spawnEnemy(
          tier: tier,
          wave: wave,
          position:
              basePos +
              Vector2(
                (_rng.nextDouble() - 0.5) * 100,
                (_rng.nextDouble() - 0.5) * 100,
              ),
        );
      }
    }
  }

  void _spawnArtillery(int wave, int tier, int count) {
    if (_surgeDirections.isEmpty) return;
    final dir = _surgeDirections.first;
    final basePos = dir * _spawnDistance;

    final chargers = (count * 0.6).round();
    for (int i = 0; i < chargers; i++) {
      _spawnEnemy(
        tier: tier,
        wave: wave,
        position:
            basePos +
            Vector2(
              (_rng.nextDouble() - 0.5) * 200,
              (_rng.nextDouble() - 0.5) * 100,
            ),
        forceRole: EnemyRole.charger,
      );
    }

    final backPos = basePos + dir * 200;
    for (int i = 0; i < count - chargers; i++) {
      _spawnEnemy(
        tier: tier,
        wave: wave,
        position:
            backPos +
            Vector2(
              (_rng.nextDouble() - 0.5) * 200,
              (_rng.nextDouble() - 0.5) * 80,
            ),
        forceRole: EnemyRole.shooter,
      );
    }
  }

  /// Spawns enemies evenly distributed around a full 360° ring, producing
  /// the classic "surrounded from all sides" early-wave feel.
  void _spawnRing(int wave, int tier, int count) {
    if (_surgeDirections.isEmpty) return;
    final perDir = max(1, count ~/ _surgeDirections.length);
    // Use a slightly larger radius so the ring feels wide and dramatic
    final ringRadius = _spawnDistance * 1.1;
    for (final dir in _surgeDirections) {
      final basePos = dir * ringRadius;
      for (int i = 0; i < perDir; i++) {
        final jitter = Vector2(
          (_rng.nextDouble() - 0.5) * 180,
          (_rng.nextDouble() - 0.5) * 180,
        );
        _spawnEnemy(tier: tier, wave: wave, position: basePos + jitter);
      }
    }
  }

  void _completeSurge() {
    _surgeActive = false;
    _currentSurge = null;
    _surgeSpawnCounter = 0;
    _timeSinceLastSurge = 0;
    final wave = gameRef.currentWave;
    if (wave <= 5) {
      // Very early: long gap so waves feel like distinct events
      _nextSurgeDelay = 4.0 + _rng.nextDouble() * 2.0;
    } else if (wave <= 10) {
      // Still measured, 3-5s breathing room
      _nextSurgeDelay = 3.0 + _rng.nextDouble() * 2.0;
    } else if (wave <= 20) {
      _nextSurgeDelay = 1.5 + _rng.nextDouble() * 1.5;
    } else {
      _nextSurgeDelay = 2.0 + _rng.nextDouble() * 2.0;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ENEMY SPAWNING
  // ══════════════════════════════════════════════════════════════════════════

  void _spawnEnemy({
    required int tier,
    required int wave,
    required Vector2 position,
    double sizeScale = 1.0,
    EnemyRole? forceRole,
  }) {
    if (_spawnedThisWave >= _waveSpawnBudget) return;

    final template = SurvivalEnemyCatalog.getRandomTemplateForTier(tier);
    final role = forceRole ?? _determineRole(template, wave);

    final unit = SurvivalEnemyCatalog.buildEnemy(
      template: template,
      tier: tier,
      wave: wave,
      isShooter: role == EnemyRole.shooter,
    );

    gameRef.addHoardEnemy(
      HoardEnemy(
        position: position,
        targetOrb: gameRef.orb,
        unit: unit,
        template: template,
        role: role,
        sizeScale: sizeScale,
      ),
    );

    _spawnedThisWave++;
  }

  int _pickTierForWave(int wave) {
    // Tier 2 enemies appear much earlier for variety
    if (wave < 5) return 1;
    if (wave < 10) return _rng.nextDouble() < 0.85 ? 1 : 2;
    if (wave < 18) return _rng.nextDouble() < 0.6 ? 1 : 2;
    if (wave < 25) return _rng.nextDouble() < 0.4 ? 1 : 2;
    // Late game: mix of tier 1-3
    final roll = _rng.nextDouble();
    if (roll < 0.15) return 1;
    if (roll < 0.70) return 2;
    return 3;
  }

  EnemyRole _determineRole(SurvivalEnemyTemplate template, int wave) {
    // Roles appear earlier & scale more aggressively for strategic variety
    // Wave 1-2: chargers only (tutorial feel)
    // Wave 3+: shooters trickle in
    // Wave 5+: bombers appear
    // Wave 8+: leechers join
    double shooter = wave >= 3 ? 0.10 + (wave * 0.005).clamp(0, 0.12) : 0.0;
    double bomber = wave >= 5 ? 0.06 + (wave * 0.003).clamp(0, 0.08) : 0.0;
    double leecher = wave >= 8 ? 0.04 + (wave * 0.002).clamp(0, 0.06) : 0.0;

    // Element affinity bonuses (additive)
    switch (template.element) {
      case 'Air':
      case 'Lightning':
      case 'Spirit':
        shooter += 0.06;
      case 'Fire':
      case 'Lava':
        bomber += 0.05;
      case 'Blood':
      case 'Dark':
      case 'Poison':
        leecher += 0.05;
      case 'Ice':
      case 'Crystal':
        // Tanky element: more chargers (reduce others slightly)
        shooter *= 0.7;
        bomber *= 0.7;
      case 'Water':
      case 'Steam':
        // Flexible: slight boost to all special roles
        shooter += 0.02;
        leecher += 0.02;
    }

    final roll = _rng.nextDouble();
    if (roll < bomber) return EnemyRole.bomber;
    if (roll < bomber + leecher) return EnemyRole.leecher;
    if (roll < bomber + leecher + shooter) return EnemyRole.shooter;
    return EnemyRole.charger;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BOSS/ELITE SPAWNING
  // ══════════════════════════════════════════════════════════════════════════

  void _spawnElitePack(int wave) {
    final count = wave >= 25 ? 3 : 2;
    final angle = _rng.nextDouble() * 2 * pi;
    final pos = Vector2(cos(angle), sin(angle)) * _spawnDistance;

    for (int i = 0; i < count; i++) {
      _spawnEnemy(
        tier: 3,
        wave: wave,
        position:
            pos +
            Vector2(
              (_rng.nextDouble() - 0.5) * 100,
              (_rng.nextDouble() - 0.5) * 100,
            ),
      );
    }
  }

  void _spawnMiniBoss(int wave) {
    final tier = wave < 10 ? 2 : (wave < 20 ? 3 : (wave < 35 ? 4 : 5));
    final template = SurvivalEnemyCatalog.getRandomTemplateForTier(tier);
    final unit = SurvivalEnemyCatalog.buildMiniBoss(
      template: template,
      wave: wave,
    );

    final angle = _rng.nextDouble() * 2 * pi;
    final pos = Vector2(cos(angle), sin(angle)) * (_spawnDistance + 250);

    final enemy = HoardEnemy(
      position: pos,
      targetOrb: gameRef.orb,
      unit: unit,
      template: template,
      role: EnemyRole.charger,
      sizeScale: (2.8 + wave * 0.04).clamp(2.8, 4.2),
      speedMultiplier: 0.6,
    );
    enemy.isMiniBoss = true;
    gameRef.addHoardEnemy(enemy);

    // Escort wave
    Future.delayed(const Duration(milliseconds: 2200), () {
      for (int i = 0; i < 4 + wave ~/ 12; i++) {
        final escortAngle = (i / (4 + wave ~/ 12)) * 2 * pi;
        _spawnEnemy(
          tier: max(1, tier - 1),
          wave: wave,
          position: pos + Vector2(cos(escortAngle), sin(escortAngle)) * 220,
        );
      }
    });
  }

  void _spawnMegaBoss(int wave) {
    final tier = wave < 15 ? 3 : (wave < 25 ? 4 : 5);
    final template = SurvivalEnemyCatalog.getRandomTemplateForTier(tier);

    final bossNum = wave ~/ 10;
    final archetype = bossNum > 0 && bossNum % 4 == 0
        ? BossArchetype.hydra
        : [
            BossArchetype.juggernaut,
            BossArchetype.summoner,
            BossArchetype.artillery,
          ][(bossNum - 1) % 3];

    final angle = _rng.nextDouble() * 2 * pi;
    final pos = Vector2(cos(angle), sin(angle)) * (_spawnDistance + 450);

    if (archetype == BossArchetype.hydra) {
      final unit = SurvivalEnemyCatalog.buildHydraBoss(
        template: template,
        wave: wave,
        generation: 0,
      );
      final enemy = HoardEnemy(
        position: pos,
        targetOrb: gameRef.orb,
        unit: unit,
        template: template,
        role: EnemyRole.charger,
        sizeScale: (3.0 + wave * 0.03).clamp(3.0, 4.5),
        bossArchetype: BossArchetype.hydra,
        isMegaBoss: true,
        speedMultiplier: 0.35,
        hydraGeneration: 0,
      );
      enemy.isBoss = true;
      gameRef.addHoardEnemy(enemy);
    } else {
      final unit = SurvivalEnemyCatalog.buildMegaBoss(
        template: template,
        wave: wave,
      );
      final enemy = HoardEnemy(
        position: pos,
        targetOrb: gameRef.orb,
        unit: unit,
        template: template,
        role: archetype == BossArchetype.artillery
            ? EnemyRole.shooter
            : EnemyRole.charger,
        sizeScale: (4.0 + wave * 0.05).clamp(4.0, 6.0),
        bossArchetype: archetype,
        isMegaBoss: true,
        speedMultiplier: 0.4,
      );
      enemy.isBoss = true;
      gameRef.addHoardEnemy(enemy);

      _spawnBossMinionWaves(pos, wave, tier);
    }
  }

  void _spawnBossMinionWaves(Vector2 bossPos, int wave, int tier) {
    Future.delayed(const Duration(milliseconds: 3200), () {
      for (int i = 0; i < 5 + wave ~/ 10; i++) {
        final angle = (i / (5 + wave ~/ 10)) * 2 * pi;
        _spawnEnemy(
          tier: max(1, min(3, tier - 2)),
          wave: wave,
          position: bossPos + Vector2(cos(angle), sin(angle)) * 320,
        );
      }
    });

    Future.delayed(const Duration(milliseconds: 6200), () {
      for (int i = 0; i < 6 + wave ~/ 10; i++) {
        final angle = (i / (6 + wave ~/ 10)) * 2 * pi + pi / (6 + wave ~/ 10);
        _spawnEnemy(
          tier: max(1, min(3, tier - 1)),
          wave: wave,
          position: bossPos + Vector2(cos(angle), sin(angle)) * 420,
        );
      }
    });
  }
}
