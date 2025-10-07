// lib/models/biome.dart
import 'package:flutter/material.dart';

enum Biome {
  volcanic,
  oceanic,
  earthen,
  verdant,
  arcane;

  String get id => name;

  String get label => switch (this) {
    volcanic => 'Volcanic',
    oceanic => 'Oceanic',
    earthen => 'Earthen',
    verdant => 'Verdant',
    arcane => 'Arcane',
  };

  String get description => switch (this) {
    volcanic => 'Harness intense heat and raw energy',
    oceanic => 'Extract fluid essences and frozen power',
    earthen => 'Mine solid matter and crystalline structures',
    verdant => 'Cultivate living forces and atmospheric currents',
    arcane => 'Channel mystical and primal energies',
  };

  List<String> get elementIds => switch (this) {
    volcanic => ['T001', 'T006', 'T007'], // Fire, Lava, Lightning
    oceanic => ['T002', 'T009', 'T005'], // Water, Ice, Steam
    earthen => ['T003', 'T008', 'T010', 'T011'], // Earth, Mud, Dust, Crystal
    verdant => ['T004', 'T012', 'T013'], // Air, Plant, Poison
    arcane => ['T014', 'T016', 'T015', 'T017'], // Spirit, Light, Dark, Blood
  };

  List<String> get elementNames => switch (this) {
    volcanic => ['Fire', 'Lava', 'Lightning'],
    oceanic => ['Water', 'Ice', 'Steam'],
    earthen => ['Earth', 'Mud', 'Dust', 'Crystal'],
    verdant => ['Air', 'Plant', 'Poison'],
    arcane => ['Spirit', 'Light', 'Dark', 'Blood'],
  };

  IconData get icon => switch (this) {
    volcanic => Icons.local_fire_department_rounded,
    oceanic => Icons.water_drop_rounded,
    earthen => Icons.landscape_rounded,
    verdant => Icons.nature_rounded,
    arcane => Icons.auto_awesome_rounded,
  };

  Color get primaryColor => switch (this) {
    volcanic => const Color(0xFFFF6B35),
    oceanic => const Color(0xFF4ECDC4),
    earthen => const Color(0xFF8B6F47),
    verdant => const Color(0xFF6BCF7F),
    arcane => const Color(0xFFB388FF),
  };

  Color get secondaryColor => switch (this) {
    volcanic => const Color(0xFFFFA500),
    oceanic => const Color(0xFF00BCD4),
    earthen => const Color(0xFFA0826D),
    verdant => const Color(0xFF8FD99F),
    arcane => const Color(0xFFD4B3FF),
  };

  // Helper to get resource key for a specific element
  String resourceKeyForElement(String elementId) {
    return switch (elementId) {
      'T001' => 'res_fire',
      'T002' => 'res_water',
      'T003' => 'res_earth',
      'T004' => 'res_air',
      'T005' => 'res_steam',
      'T006' => 'res_lava',
      'T007' => 'res_lightning',
      'T008' => 'res_mud',
      'T009' => 'res_ice',
      'T010' => 'res_dust',
      'T011' => 'res_crystal',
      'T012' => 'res_plant',
      'T013' => 'res_poison',
      'T014' => 'res_spirit',
      'T015' => 'res_dark',
      'T016' => 'res_light',
      'T017' => 'res_blood',
      _ => 'res_unknown',
    };
  }

  // Helper to get display name for resource
  String resourceNameForElement(String elementId) {
    return switch (elementId) {
      'T001' => 'Embers',
      'T002' => 'Droplets',
      'T003' => 'Shards',
      'T004' => 'Breeze',
      'T005' => 'Steam',
      'T006' => 'Lava',
      'T007' => 'Lightning',
      'T008' => 'Mud',
      'T009' => 'Ice',
      'T010' => 'Dust',
      'T011' => 'Crystal',
      'T012' => 'Plant',
      'T013' => 'Poison',
      'T014' => 'Spirit',
      'T015' => 'Dark',
      'T016' => 'Light',
      'T017' => 'Blood',
      _ => 'Unknown',
    };
  }

  // Get element-specific color
  Color colorForElement(String elementId) {
    return switch (elementId) {
      'T001' => const Color(0xFFFF6B35), // Fire
      'T002' => const Color(0xFF4ECDC4), // Water
      'T003' => const Color(0xFF8B6F47), // Earth
      'T004' => const Color(0xFFB0E0E6), // Air
      'T005' => const Color(0xFFE6E6FA), // Steam
      'T006' => const Color(0xFFFF4500), // Lava
      'T007' => const Color(0xFFFFD700), // Lightning
      'T008' => const Color(0xFF8B7355), // Mud
      'T009' => const Color(0xFF87CEEB), // Ice
      'T010' => const Color(0xFFD2B48C), // Dust
      'T011' => const Color(0xFFE0B0FF), // Crystal
      'T012' => const Color(0xFF228B22), // Plant
      'T013' => const Color(0xFF9370DB), // Poison
      'T014' => const Color(0xFFE6E6FA), // Spirit
      'T015' => const Color(0xFF4B0082), // Dark
      'T016' => const Color(0xFFFFFACD), // Light
      'T017' => const Color(0xFF8B0000), // Blood
      _ => primaryColor,
    };
  }

  // Get icon for specific element
  IconData iconForElement(String elementId) {
    return switch (elementId) {
      'T001' => Icons.local_fire_department_rounded, // Fire
      'T002' => Icons.water_drop_rounded, // Water
      'T003' => Icons.landscape_rounded, // Earth
      'T004' => Icons.air_rounded, // Air
      'T005' => Icons.cloud_rounded, // Steam
      'T006' => Icons.volcano_rounded, // Lava
      'T007' => Icons.bolt_rounded, // Lightning
      'T008' => Icons.terrain_rounded, // Mud
      'T009' => Icons.ac_unit_rounded, // Ice
      'T010' => Icons.grain_rounded, // Dust
      'T011' => Icons.diamond_rounded, // Crystal
      'T012' => Icons.grass_rounded, // Plant
      'T013' => Icons.science_rounded, // Poison
      'T014' => Icons.wind_power_rounded, // Spirit
      'T015' => Icons.nightlight_rounded, // Dark
      'T016' => Icons.wb_sunny_rounded, // Light
      'T017' => Icons.bloodtype_rounded, // Blood
      _ => Icons.circle,
    };
  }
}
