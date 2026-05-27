import 'package:flutter/material.dart';
import 'package:alchemons/widgets/app_icons.dart';

enum CompetitionType {
  speed('Speed', 'statSpeed', AppIcons.speed_rounded),
  strength('Strength', 'statStrength', AppIcons.fitness_center_rounded),
  intelligence('Intelligence', 'statIntelligence', AppIcons.psychology_rounded),
  beauty('Beauty', 'statBeauty', AppIcons.auto_awesome_rounded),
  ultimate('Ultimate', 'all', AppIcons.emoji_events_rounded);

  const CompetitionType(this.label, this.statKey, this.icon);
  final String label;
  final String statKey; // 'all' for ultimate
  final IconData icon;
}

enum CompetitionBiome {
  oceanic(
    'Oceanic Arena',
    CompetitionType.speed,
    ['Water', 'Ice', 'Steam'],
    Color(0xFF5B8CFF),
    Color(0xFF9BB7FF),
    AppIcons.waves_rounded,
    'Test your speed in the churning tides',
  ),
  volcanic(
    'Volcanic Colosseum',
    CompetitionType.strength,
    ['Fire', 'Lava', 'Lightning'],
    Color(0xFFFF5757),
    Color(0xFFFF9B9B),
    AppIcons.local_fire_department_rounded,
    'Prove your strength in the molten arena',
  ),
  earthen(
    'Earthen Academy',
    CompetitionType.intelligence,
    ['Earth', 'Mud', 'Dust', 'Crystal'],
    Color(0xFFA67C52),
    Color(0xFFD4A574),
    AppIcons.terrain_rounded,
    'Challenge your intellect in ancient halls',
  ),
  verdant(
    'Verdant Gardens',
    CompetitionType.beauty,
    ['Air', 'Plant', 'Posion'],
    Color(0xFF2ED49A),
    Color(0xFF96F2C7),
    AppIcons.park_rounded,
    'Showcase your elegance among nature',
  ),
  celestial(
    'Celestial Nexus',
    CompetitionType.ultimate,
    ['Spirit', 'Light', 'Dark', 'Blood'],
    Color(0xFFB565FF),
    Color(0xFFD4A5FF),
    AppIcons.auto_awesome_rounded,
    'The ultimate test of all attributes',
  );

  const CompetitionBiome(
    this.name,
    this.type,
    this.allowedTypes,
    this.primaryColor,
    this.accentColor,
    this.icon,
    this.description,
  );

  final String name;
  final CompetitionType type;
  final List<String> allowedTypes;
  final Color primaryColor;
  final Color accentColor;
  final IconData icon;
  final String description;

  bool canCompete(List<String> creatureTypes) {
    if (allowedTypes.isEmpty) return true; // Celestial allows all
    return creatureTypes.any((t) => allowedTypes.contains(t));
  }
}

class CompetitionLevel {
  final int level;
  final String name;
  final List<NPCCompetitor> npcs;
  final int rewardAmount;
  final String rewardResource;

  const CompetitionLevel({
    required this.level,
    required this.name,
    required this.npcs,
    required this.rewardAmount,
    required this.rewardResource,
  });

  // Stat requirement to have a chance
  double get minStatRecommended => 3.0 + (level * 1.5);
  double get maxStatRecommended => 5.0 + (level * 1.5);
}

class NPCCompetitor {
  final String name;
  final double statValue;
  final String? flavor;

  const NPCCompetitor({
    required this.name,
    required this.statValue,
    this.flavor,
  });
}
