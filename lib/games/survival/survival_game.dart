import 'dart:math' as math;
import 'package:alchemons/games/survival/components/alchemy_orb.dart';
import 'package:alchemons/games/survival/survival_creature_sprite.dart';
import 'package:alchemons/games/survival/survival_enemies.dart';
import 'package:alchemons/games/survival/survival_engine.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';

class SurvivalHoardGame extends FlameGame with HasCollisionDetection {
  final List<PartyMember> party;

  late World world;
  late CameraComponent cameraComponent;
  late AlchemyOrb orb;

  final List<HoardGuardian> _guardians = [];
  final List<HoardEnemy> _enemies = [];

  // Game State
  int score = 0;
  double timeElapsed = 0;
  bool isGameOver = false;

  // Spawning
  double _spawnTimer = 0;
  double _currentSpawnRate = 2.0; // Seconds between spawns

  SurvivalHoardGame({required this.party});

  @override
  Future<void> onLoad() async {
    world = World();
    cameraComponent = CameraComponent(world: world)
      ..viewfinder.anchor = Anchor.center;

    add(world);
    add(cameraComponent);

    // 1. Place Orb at (0,0)
    orb = AlchemyOrb(maxHp: 5000);
    world.add(orb);

    // 2. Place Party Members based on Formation
    _setupFormation();
  }

  void _setupFormation() {
    for (var member in party) {
      // Calculate offset based on FormationPosition
      Vector2 offset;

      // Front Row = Outer Ring (Radius 200)
      // Back Row = Inner Ring (Radius 120)
      switch (member.position) {
        case FormationPosition.frontLeft:
          offset = Vector2(-200, -100);
          break;
        case FormationPosition.frontRight:
          offset = Vector2(200, -100);
          break;
        case FormationPosition.backLeft:
          offset = Vector2(-120, 100);
          break;
        case FormationPosition.backRight:
          offset = Vector2(120, 100);
          break;
      }

      final guardian = HoardGuardian(
        combatant: member.combatant,
        position: offset,
      );

      _guardians.add(guardian);
      world.add(guardian);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isGameOver) return;

    timeElapsed += dt;

    // Ramp up difficulty: Spawn faster every minute
    _currentSpawnRate = math.max(0.2, 2.0 - (timeElapsed / 60.0));

    // Spawning Logic
    _spawnTimer += dt;
    if (_spawnTimer >= _currentSpawnRate) {
      _spawnTimer = 0;
      _spawnEnemy();
    }

    // Win/Loss Check
    if (orb.isDestroyed) {
      isGameOver = true;
      // Show Game Over Overlay via your UI logic
    }
  }

  void _spawnEnemy() {
    // Spawn in a circle far away
    final angle = math.Random().nextDouble() * math.pi * 2;
    final spawnPos =
        Vector2(math.cos(angle), math.sin(angle)) * 900; // 900px out

    // Scale enemy stats with time
    int level = 1 + (timeElapsed / 30).floor();

    final enemy = HoardEnemy(position: spawnPos, level: level, targetOrb: orb);

    _enemies.add(enemy);
    world.add(enemy);
  }

  // --- Combat Helpers ---

  HoardEnemy? getNearestEnemy(Vector2 position, double range) {
    HoardEnemy? nearest;
    double minDstSq = range * range;

    for (final enemy in _enemies) {
      if (enemy.isDead) continue;
      final dstSq = position.distanceToSquared(enemy.position);
      if (dstSq < minDstSq) {
        minDstSq = dstSq;
        nearest = enemy;
      }
    }
    return nearest;
  }

  void spawnProjectile({
    required Vector2 start,
    required HoardEnemy target,
    required int damage,
    required Color color,
  }) {
    // Simple projectile visual that travels to target
    final projectile = SimpleProjectile(
      start: start,
      end: target.position,
      color: color,
      onHit: () {
        target.takeDamage(damage);
        // Show damage number logic here
      },
    );
    world.add(projectile);
  }

  void removeEnemy(HoardEnemy enemy) {
    _enemies.remove(enemy);
    score += 10 * enemy.level;
  }
}
