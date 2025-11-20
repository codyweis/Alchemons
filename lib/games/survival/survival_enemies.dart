// lib/services/gameengines/survival_enemies.dart
import 'package:alchemons/services/gameengines/boss_battle_engine_service.dart';
// ^ or whatever path your BattleCombatant etc live at

/// Template for an enemy type used in Survival mode.
class SurvivalEnemyTemplate {
  final String id;
  final String name;
  final List<String> types; // element(s), e.g. ['Fire']
  final String family; // Let/Pip/... so moves work
  final double baseSpeed;
  final double baseIntelligence;
  final double baseStrength;
  final double baseBeauty;

  const SurvivalEnemyTemplate({
    required this.id,
    required this.name,
    required this.types,
    required this.family,
    required this.baseSpeed,
    required this.baseIntelligence,
    required this.baseStrength,
    required this.baseBeauty,
  });
}

/// Static catalog of survival enemies.
/// You can tweak/add more later.
class SurvivalEnemyCatalog {
  static const List<SurvivalEnemyTemplate> templates = [
    SurvivalEnemyTemplate(
      id: 'ember_sprout',
      name: 'Ember Sprout',
      types: ['Fire', 'Plant'],
      family: 'Let',
      baseSpeed: 28,
      baseIntelligence: 20,
      baseStrength: 22,
      baseBeauty: 15,
    ),
    SurvivalEnemyTemplate(
      id: 'gloom_slime',
      name: 'Gloom Slime',
      types: ['Poison', 'Dark'],
      family: 'Pip',
      baseSpeed: 16,
      baseIntelligence: 22,
      baseStrength: 25,
      baseBeauty: 10,
    ),
    SurvivalEnemyTemplate(
      id: 'crystal_wisp',
      name: 'Crystal Wisp',
      types: ['Crystal', 'Light'],
      family: 'Mystic',
      baseSpeed: 30,
      baseIntelligence: 30,
      baseStrength: 18,
      baseBeauty: 28,
    ),
    SurvivalEnemyTemplate(
      id: 'mud_gnarl',
      name: 'Mud Gnarl',
      types: ['Mud', 'Earth'],
      family: 'Horn',
      baseSpeed: 14,
      baseIntelligence: 12,
      baseStrength: 30,
      baseBeauty: 8,
    ),
    SurvivalEnemyTemplate(
      id: 'stormling',
      name: 'Stormling',
      types: ['Lightning', 'Air'],
      family: 'Wing',
      baseSpeed: 35,
      baseIntelligence: 24,
      baseStrength: 20,
      baseBeauty: 18,
    ),
  ];

  /// Simple helper to get a template, e.g. based on wave.
  static SurvivalEnemyTemplate pickTemplateForWave(int wave) {
    // You can make certain templates only appear after certain waves.
    final index = wave ~/ 5; // every 5 waves unlocks the next template
    return templates[index.clamp(0, templates.length - 1)];
  }

  /// Builds a BattleCombatant from a template & wave-based "level".
  static BattleCombatant buildEnemyForWave({
    required SurvivalEnemyTemplate template,
    required int wave,
  }) {
    // Rough level curve: wave 1 => lvl 3, then +1 level per 2 waves.
    final level = 3 + (wave ~/ 2);

    return BattleCombatant(
      id: '${template.id}_w${wave}_${DateTime.now().microsecondsSinceEpoch}',
      name: template.name,
      types: template.types,
      family: template.family,
      statSpeed: template.baseSpeed,
      statIntelligence: template.baseIntelligence,
      statStrength: template.baseStrength,
      statBeauty: template.baseBeauty,
      level: level,
    );
  }
}
