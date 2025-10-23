import 'package:flutter/material.dart';

enum CompetitionType {
  speed('Speed', 'statSpeed', Icons.speed_rounded),
  strength('Strength', 'statStrength', Icons.fitness_center_rounded),
  intelligence('Intelligence', 'statIntelligence', Icons.psychology_rounded),
  beauty('Beauty', 'statBeauty', Icons.auto_awesome_rounded),
  ultimate('Ultimate', 'all', Icons.emoji_events_rounded);

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
    Icons.waves_rounded,
    'Test your speed in the churning tides',
  ),
  volcanic(
    'Volcanic Colosseum',
    CompetitionType.strength,
    ['Fire', 'Lava', 'Lightning'],
    Color(0xFFFF5757),
    Color(0xFFFF9B9B),
    Icons.local_fire_department_rounded,
    'Prove your strength in the molten arena',
  ),
  earthen(
    'Earthen Academy',
    CompetitionType.intelligence,
    ['Earth', 'Mud', 'Dust', 'Crystal'],
    Color(0xFFA67C52),
    Color(0xFFD4A574),
    Icons.terrain_rounded,
    'Challenge your intellect in ancient halls',
  ),
  verdant(
    'Verdant Gardens',
    CompetitionType.beauty,
    ['Air', 'Plant', 'Posion'],
    Color(0xFF2ED49A),
    Color(0xFF96F2C7),
    Icons.park_rounded,
    'Showcase your elegance among nature',
  ),
  celestial(
    'Celestial Nexus',
    CompetitionType.ultimate,
    ['Spirit', 'Light', 'Dark', 'Blood'],
    Color(0xFFB565FF),
    Color(0xFFD4A5FF),
    Icons.auto_awesome_rounded,
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
