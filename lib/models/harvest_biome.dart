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

  /// Elements that thematically live under this biome.
  /// (For UI chips, flavor text, etc. This can stay.)
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

  // =========================================================
  // NEW CORE: unified biome resource identity
  // =========================================================

  /// This is the settings key / db key to store this biome's currency.
  /// You will only have 5 of these in Settings now.
  String get resourceKey => switch (this) {
    volcanic => 'res_volcanic',
    oceanic => 'res_oceanic',
    earthen => 'res_earthen',
    verdant => 'res_verdant',
    arcane => 'res_arcane',
  };

  /// Player-facing display name of that resource
  String get resourceLabel => switch (this) {
    volcanic => 'Volcanic',
    oceanic => 'Oceanic',
    earthen => 'Earthen',
    verdant => 'Verdant',
    arcane => 'Arcane',
  };

  /// Icon representing that biome's resource in UI (for payouts/unlock/etc)
  IconData get resourceIcon => icon;

  /// Accent color for that resource (can just reuse primaryColor)
  Color get resourceColor => primaryColor;

  // =========================================================
  // LEGACY COMPAT SHIMS (OPTIONAL, for screens still expecting elementId)
  // =========================================================
  //
  // Before: a specific elementId like 'T001' mapped to a unique resource key,
  // e.g. 'res_fire', 'res_water', etc.
  //
  // Now: ANY elementId under this biome maps to this biome's single resource pool.

  String resourceKeyForElement(String elementId) {
    // ignore which element exactly, just route to biome pool:
    return resourceKey;
  }

  String resourceNameForElement(String elementId) {
    // same idea — always show the biome resource name
    return resourceLabel;
  }

  // You *can* keep color/icon variations per element for flavor in the UI,
  // but they should NOT imply different currencies anymore.
  Color colorForElement(String elementId) {
    // Option A: still do per-element flair like before.
    // Option B (simpler): always biome color.
    return primaryColor;
  }

  IconData iconForElement(String elementId) {
    // Same: either keep per-element icons, or simplify.
    // I'll keep the cool per-element icons for chips/active extraction pill.
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
      _ => icon,
    };
  }
}
