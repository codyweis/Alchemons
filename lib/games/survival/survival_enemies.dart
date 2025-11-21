import 'dart:math';
import 'dart:ui';
import 'package:alchemons/games/survival/components/alchemy_orb.dart';
import 'package:alchemons/games/survival/survival_game.dart';
import 'package:alchemons/services/gameengines/boss_battle_engine_service.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 5 Enemy Tiers with scaling stats
enum EnemyTier {
  swarm(1, 'Swarm', 0.6, 0.5), // Weakest, most numerous
  grunt(2, 'Grunt', 0.8, 0.7),
  elite(3, 'Elite', 1.0, 0.9),
  champion(4, 'Champion', 1.3, 1.2),
  titan(5, 'Titan', 1.8, 1.6); // Strongest, rarest

  final int tier;
  final String name;
  final double statMultiplier;
  final double hpMultiplier;

  const EnemyTier(this.tier, this.name, this.statMultiplier, this.hpMultiplier);
}

/// 17 Elemental Types
const List<String> allElements = [
  'Fire',
  'Water',
  'Earth',
  'Air',
  'Ice',
  'Lightning',
  'Plant',
  'Poison',
  'Steam',
  'Lava',
  'Mud',
  'Dust',
  'Crystal',
  'Spirit',
  'Dark',
  'Light',
  'Blood',
];

/// Enemy template combining tier + element
class SurvivalEnemyTemplate {
  final EnemyTier tier;
  final String element;
  final String family; // For move compatibility

  const SurvivalEnemyTemplate({
    required this.tier,
    required this.element,
    required this.family,
  });

  String get name => '${tier.name} ${element}ling';
  String get id => '${element.toLowerCase()}_${tier.name.toLowerCase()}';
}

/// Enemy catalog with all combinations
class SurvivalEnemyCatalog {
  static final Random _rng = Random();

  // Pre-generate all 85 combinations (5 tiers × 17 elements)
  static final List<SurvivalEnemyTemplate> _allTemplates =
      _generateAllTemplates();

  static List<SurvivalEnemyTemplate> _generateAllTemplates() {
    final templates = <SurvivalEnemyTemplate>[];

    for (final tier in EnemyTier.values) {
      for (final element in allElements) {
        templates.add(
          SurvivalEnemyTemplate(
            tier: tier,
            element: element,
            family: _getElementFamily(element),
          ),
        );
      }
    }

    return templates;
  }

  /// Get random template for a specific tier
  static SurvivalEnemyTemplate getRandomTemplateForTier(int tierNum) {
    final tier = EnemyTier.values.firstWhere((t) => t.tier == tierNum);
    final tieredTemplates = _allTemplates.where((t) => t.tier == tier).toList();
    return tieredTemplates[_rng.nextInt(tieredTemplates.length)];
  }

  /// Build actual enemy combatant
  static BattleCombatant buildEnemy({
    required SurvivalEnemyTemplate template,
    required int tier,
    required int wave,
  }) {
    // Level scaling: VERY gentle
    final baseLevel = _getBaseLevelForTier(tier, wave);
    final level = baseLevel; // consider dropping the + wave~/3 for now

    final baseStats = _getBaseStats(tier);

    final enemy = BattleCombatant(
      id: '${template.id}_w${wave}_${DateTime.now().microsecondsSinceEpoch}_${_rng.nextInt(9999)}',
      name: template.name,
      types: [template.element],
      family: template.family,
      statSpeed: baseStats['speed']!, // in *0–5* range!
      statIntelligence: baseStats['intelligence']!,
      statStrength: baseStats['strength']!,
      statBeauty: baseStats['beauty']!,
      level: level,
    );

    // --- SURVIVAL-SPECIFIC TUNING ---
    // Early waves: enemies hit softer.
    // Later waves: they ramp up towards or slightly above "normal" strength.
    final atkScale = (0.7 + wave * 0.02).clamp(0.7, 1.1);
    final hpScale = (0.9 + wave * 0.015).clamp(0.9, 1.25);

    return enemy.scaledCopy(
      newId: enemy.id, // keep same id
      hpScale: hpScale,
      atkScale: atkScale,
      defScale: 1.0,
      spdScale: 1.0,
    );
  }

  static int _getBaseLevelForTier(int tier, int wave) {
    switch (tier) {
      case 1:
        return max(1, wave ~/ 2); // Tier 1: Very low level
      case 2:
        return max(2, 2 + wave ~/ 2);
      case 3:
        return max(5, 5 + wave ~/ 2);
      case 4:
        return max(10, 10 + wave ~/ 2);
      case 5:
        return max(15, 15 + wave ~/ 2);
      default:
        return 1;
    }
  }

  static Map<String, double> _getBaseStats(int tier) {
    // Base in 0.0–5.0 range
    double baseSpeed, baseInt, baseStr, baseBeauty;

    switch (tier) {
      case 1: // Swarm – weak
        baseSpeed = 2.8 + _rng.nextDouble() * 0.7;
        baseInt = 1.0 + _rng.nextDouble() * 0.6;
        baseStr = 1.2 + _rng.nextDouble() * 0.8;
        baseBeauty = 0.8 + _rng.nextDouble() * 0.5;
        break;
      case 2: // Grunt – moderate
        baseSpeed = 2.4 + _rng.nextDouble() * 0.8;
        baseInt = 1.8 + _rng.nextDouble() * 0.8;
        baseStr = 2.2 + _rng.nextDouble() * 0.8;
        baseBeauty = 1.4 + _rng.nextDouble() * 0.7;
        break;
      case 3: // Elite
        baseSpeed = 3.0 + _rng.nextDouble() * 0.8;
        baseInt = 2.6 + _rng.nextDouble() * 0.9;
        baseStr = 3.2 + _rng.nextDouble() * 0.9;
        baseBeauty = 2.0 + _rng.nextDouble() * 0.8;
        break;
      case 4: // Champion
        baseSpeed = 3.4 + _rng.nextDouble() * 0.9;
        baseInt = 3.4 + _rng.nextDouble() * 0.9;
        baseStr = 4.0 + _rng.nextDouble() * 0.9;
        baseBeauty = 2.8 + _rng.nextDouble() * 0.9;
        break;
      case 5: // Titan
        baseSpeed = 3.8 + _rng.nextDouble() * 1.0;
        baseInt = 4.0 + _rng.nextDouble() * 1.0;
        baseStr = 4.5 + _rng.nextDouble() * 1.0;
        baseBeauty = 3.4 + _rng.nextDouble() * 0.9;
        break;
      default:
        baseSpeed = baseInt = baseStr = 2.0;
        baseBeauty = 1.5;
        break;
    }

    return {
      'speed': baseSpeed,
      'intelligence': baseInt,
      'strength': baseStr,
      'beauty': baseBeauty,
    };
  }

  /// Assign family based on element for move compatibility
  static String _getElementFamily(String element) {
    switch (element) {
      case 'Fire':
      case 'Lava':
      case 'Blood':
        return 'Let'; // Aggressive

      case 'Water':
      case 'Ice':
      case 'Steam':
        return 'Pip'; // Quick

      case 'Earth':
      case 'Mud':
      case 'Crystal':
        return 'Horn'; // Defensive

      case 'Air':
      case 'Dust':
      case 'Lightning':
        return 'Wing'; // Fast

      case 'Plant':
      case 'Poison':
        return 'Mane'; // Tricky

      case 'Spirit':
      case 'Light':
      case 'Dark':
        return 'Mystic'; // Magical

      default:
        return 'Let';
    }
  }

  /// Get all templates for a specific tier (for testing/debugging)
  static List<SurvivalEnemyTemplate> getTemplatesForTier(int tierNum) {
    final tier = EnemyTier.values.firstWhere((t) => t.tier == tierNum);
    return _allTemplates.where((t) => t.tier == tier).toList();
  }

  /// Get template by exact element and tier
  static SurvivalEnemyTemplate? getTemplate(String element, int tierNum) {
    try {
      final tier = EnemyTier.values.firstWhere((t) => t.tier == tierNum);
      return _allTemplates.firstWhere(
        (t) => t.element == element && t.tier == tier,
      );
    } catch (e) {
      return null;
    }
  }
}

class HoardEnemy extends PositionComponent with HasGameRef<SurvivalHoardGame> {
  final int level;
  final AlchemyOrb targetOrb;

  late int hp;
  late int maxHp;
  bool isDead = false;

  HoardEnemy({
    required Vector2 position,
    required this.level,
    required this.targetOrb,
  }) : super(position: position, size: Vector2.all(60), anchor: Anchor.center) {
    maxHp = 50 + (level * 20);
    hp = maxHp;
  }

  @override
  Future<void> onLoad() async {
    // Simple visual
    add(CircleComponent(radius: 25, paint: Paint()..color = Colors.red));
  }

  @override
  void update(double dt) {
    if (isDead) return;

    // Move towards Orb
    final dir = (targetOrb.position - position).normalized();
    position += dir * (80.0 * dt); // Speed 80

    // Simple collision with Orb (Range 50)
    if (position.distanceTo(targetOrb.position) < 80) {
      targetOrb.takeDamage(5 + level);
      isDead = true; // Suicide bomber style or stop and attack?
      // Let's make them explode on impact for "Hoard" feel
      removeFromParent();
      gameRef.removeEnemy(this);
    }
  }

  void takeDamage(int amount) {
    hp -= amount;
    if (hp <= 0) {
      isDead = true;
      removeFromParent();
      gameRef.removeEnemy(this);
    }
  }
}

class SimpleProjectile extends PositionComponent {
  final Vector2 start;
  final Vector2 end;
  final Color color;
  final VoidCallback onHit;
  double t = 0;

  SimpleProjectile({
    required this.start,
    required this.end,
    required this.color,
    required this.onHit,
  }) : super(position: start, size: Vector2.all(10));

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset.zero, 8, Paint()..color = color);
  }

  @override
  void update(double dt) {
    t += dt * 3.0; // Speed factor
    if (t >= 1.0) {
      onHit();
      removeFromParent();
    } else {
      position = start + (end - start) * t;
    }
  }
}
