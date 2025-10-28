import 'package:flutter/material.dart';

class ElementRes {
  final String biomeId; // 'volcanic'
  final String biomeLabel; // 'Volcanic'
  final String settingsKey; // 'res_volcanic' (used in Settings table)
  final IconData icon; // biome icon
  final Color color; // biome primary color

  const ElementRes({
    required this.biomeId,
    required this.biomeLabel,
    required this.settingsKey,
    required this.icon,
    required this.color,
  });
}

class ElementResources {
  // The 5 currencies in the whole game now.
  static const List<ElementRes> all = [
    ElementRes(
      biomeId: 'volcanic',
      biomeLabel: 'Volcanic',
      settingsKey: 'res_volcanic',
      icon: Icons.local_fire_department_rounded,
      color: Color(0xFFFF6B35),
    ),
    ElementRes(
      biomeId: 'oceanic',
      biomeLabel: 'Oceanic',
      settingsKey: 'res_oceanic',
      icon: Icons.water_drop_rounded,
      color: Color(0xFF4ECDC4),
    ),
    ElementRes(
      biomeId: 'earthen',
      biomeLabel: 'Earthen',
      settingsKey: 'res_earthen',
      icon: Icons.landscape_rounded,
      color: Color(0xFF8B6F47),
    ),
    ElementRes(
      biomeId: 'verdant',
      biomeLabel: 'Verdant',
      settingsKey: 'res_verdant',
      icon: Icons.nature_rounded,
      color: Color(0xFF6BCF7F),
    ),
    ElementRes(
      biomeId: 'arcane',
      biomeLabel: 'Arcane',
      settingsKey: 'res_arcane',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFFB388FF),
    ),
  ];

  // lookups
  static final Map<String, ElementRes> byBiomeId = {
    for (final e in all) e.biomeId: e,
  };

  static final Map<String, ElementRes> byKey = {
    for (final e in all) e.settingsKey: e,
  };

  // this is what AlchemonsDatabase.watchResourceBalances() iterates
  static List<String> get settingsKeys =>
      all.map((e) => e.settingsKey).toList(growable: false);

  /// Helper: biomeId -> its resource key
  /// e.g. 'volcanic' -> 'res_volcanic'
  static String keyForBiome(String biomeId) =>
      byBiomeId[biomeId]?.settingsKey ?? 'res_unknown';

  /// Convenience to build cost maps for unlocks.
  /// Example:
  ///   { 'volcanic': 60, 'arcane': 30 }
  /// becomes
  ///   { 'res_volcanic': 60, 'res_arcane': 30 }
  static Map<String, int> costByBiome(Map<String, int> biomeAmounts) {
    final out = <String, int>{};
    biomeAmounts.forEach((biomeId, amt) {
      out[keyForBiome(biomeId)] = amt;
    });
    return out;
  }
}
