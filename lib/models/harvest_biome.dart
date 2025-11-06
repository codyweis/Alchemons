// lib/models/biome.dart
import 'package:flutter/material.dart';

/// Biome system for resource gathering and creature habitats
///
/// Design Decision: Biomes are game mechanics/UI concepts, not creature data.
/// They define WHERE players gather resources, not WHAT creatures exist.
/// The JSON defines creature types; this defines the resource economy.
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
    volcanic => 'Intense heat and raw energy',
    oceanic => 'Fluid essences and frozen power',
    earthen => 'Solid matter and crystalline structures',
    verdant => 'Living forces and atmospheric currents',
    arcane => 'Mystical and primal energies',
  };

  /// Elements grouped by biome for resource gathering
  /// Note: These match the type names from alchemons_creatures.json
  List<String> get elementTypes => switch (this) {
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

  // ═══════════════════════════════════════════════════════════════════════════
  // UNIFIED RESOURCE SYSTEM
  // ═══════════════════════════════════════════════════════════════════════════
  // One resource pool per biome (simplified from 17 element-specific resources)

  /// Database key for storing this biome's resource amount
  String get resourceKey => 'res_$name';

  /// Display name for the resource
  String get resourceLabel => label;

  /// Icon for resource display
  IconData get resourceIcon => icon;

  /// Color for resource display
  Color get resourceColor => primaryColor;

  // ═══════════════════════════════════════════════════════════════════════════
  // ELEMENT TYPE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Check if an element type belongs to this biome
  bool containsElement(String elementType) {
    return elementTypes.contains(elementType);
  }

  /// Get the biome for a given element type
  static Biome? forElementType(String elementType) {
    for (final biome in Biome.values) {
      if (biome.containsElement(elementType)) {
        return biome;
      }
    }
    return null;
  }

  /// Get resource key for any element type (routes to biome pool)
  static String resourceKeyForElementType(String elementType) {
    final biome = forElementType(elementType);
    return biome?.resourceKey ?? 'res_arcane'; // fallback to arcane
  }
}

/// Helper extension to get biome info from element type strings
extension ElementTypeBiome on String {
  /// Get the biome this element type belongs to
  Biome? get biome => Biome.forElementType(this);

  /// Get the resource key for this element type
  String get resourceKey => Biome.resourceKeyForElementType(this);
}
