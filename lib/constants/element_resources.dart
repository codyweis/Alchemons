import 'package:flutter/material.dart';

class ElementRes {
  final String elementId; // canonical id: 'fire'
  final String elementLabel; // display:     'Fire'
  final String resId; // canonical:   'embers'
  final String resLabel; // display:     'Embers'
  final String settingsKey; // KV key:      'res_embers'
  final IconData icon;
  final Color color;

  const ElementRes({
    required this.elementId,
    required this.elementLabel,
    required this.resId,
    required this.resLabel,
    required this.settingsKey,
    required this.icon,
    required this.color,
  });
}

// Helper to make 'res_embers' etc.
String _key(String resId) => 'res_${resId.toLowerCase()}';

class ElementResources {
  // Keep the order stable (useful for UI grids)
  static const List<ElementRes> all = [
    ElementRes(
      elementId: 'fire',
      elementLabel: 'Fire',
      resId: 'embers',
      resLabel: 'Embers',
      settingsKey: 'res_embers',
      icon: Icons.local_fire_department_rounded,
      color: Color(0xFFFF7A3C),
    ),
    ElementRes(
      elementId: 'water',
      elementLabel: 'Water',
      resId: 'droplets',
      resLabel: 'Droplets',
      settingsKey: 'res_droplets',
      icon: Icons.water_drop_rounded,
      color: Color(0xFF59B9FF),
    ),
    ElementRes(
      elementId: 'earth',
      elementLabel: 'Earth',
      resId: 'pebbles',
      resLabel: 'Pebbles',
      settingsKey: 'res_pebbles',
      icon: Icons.terrain_rounded,
      color: Color(0xFFC8A86B),
    ),
    ElementRes(
      elementId: 'air',
      elementLabel: 'Air',
      resId: 'wisps',
      resLabel: 'Wisps',
      settingsKey: 'res_wisps',
      icon: Icons.air_rounded,
      color: Color(0xFFB6CFE0),
    ),
    ElementRes(
      elementId: 'steam',
      elementLabel: 'Steam',
      resId: 'vapor',
      resLabel: 'Vapor',
      settingsKey: 'res_vapor',
      icon: Icons.cloud_rounded,
      color: Color(0xFFA9C4D6),
    ),
    ElementRes(
      elementId: 'lava',
      elementLabel: 'Lava',
      resId: 'molten',
      resLabel: 'Molten',
      settingsKey: 'res_molten',
      icon: Icons.local_fire_department_outlined,
      color: Color(0xFFFF5333),
    ),
    ElementRes(
      elementId: 'lightning',
      elementLabel: 'Lightning',
      resId: 'sparks',
      resLabel: 'Sparks',
      settingsKey: 'res_sparks',
      icon: Icons.bolt_rounded,
      color: Color(0xFFFFD54F),
    ),
    ElementRes(
      elementId: 'mud',
      elementLabel: 'Mud',
      resId: 'silt',
      resLabel: 'Silt',
      settingsKey: 'res_silt',
      icon: Icons.deblur_rounded,
      color: Color(0xFFA07C5A),
    ),
    ElementRes(
      elementId: 'ice',
      elementLabel: 'Ice',
      resId: 'shards',
      resLabel: 'Shards',
      settingsKey: 'res_shards',
      icon: Icons.ac_unit_rounded,
      color: Color(0xFF84D1FF),
    ),
    ElementRes(
      elementId: 'dust',
      elementLabel: 'Dust',
      resId: 'grit',
      resLabel: 'Grit',
      settingsKey: 'res_grit',
      icon: Icons.blur_on_rounded,
      color: Color(0xFFD3BFA2),
    ),
    ElementRes(
      elementId: 'crystal',
      elementLabel: 'Crystal',
      resId: 'prisms',
      resLabel: 'Prisms',
      settingsKey: 'res_prisms',
      icon: Icons.all_inclusive_rounded,
      color: Color(0xFFB58CFF),
    ),
    ElementRes(
      elementId: 'plant',
      elementLabel: 'Plant',
      resId: 'seeds',
      resLabel: 'Seeds',
      settingsKey: 'res_seeds',
      icon: Icons.eco_rounded,
      color: Color(0xFF6BCB77),
    ),
    ElementRes(
      elementId: 'poison',
      elementLabel: 'Poison',
      resId: 'venom',
      resLabel: 'Venom',
      settingsKey: 'res_venom',
      icon: Icons.biotech_rounded,
      color: Color(0xFF9B6ACB),
    ),
    ElementRes(
      elementId: 'spirit',
      elementLabel: 'Spirit',
      resId: 'essence',
      resLabel: 'Essence',
      settingsKey: 'res_essence',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFF61E1D1),
    ),
    ElementRes(
      elementId: 'dark',
      elementLabel: 'Dark',
      resId: 'shadowbits',
      resLabel: 'Shadowbits',
      settingsKey: 'res_shadowbits',
      icon: Icons.nightlight_round_rounded,
      color: Color(0xFF6C5A7C),
    ),
    ElementRes(
      elementId: 'light',
      elementLabel: 'Light',
      resId: 'lumens',
      resLabel: 'Lumens',
      settingsKey: 'res_lumens',
      icon: Icons.wb_sunny_rounded,
      color: Color(0xFFFFF176),
    ),
    ElementRes(
      elementId: 'blood',
      elementLabel: 'Blood',
      resId: 'vitae',
      resLabel: 'Vitae',
      settingsKey: 'res_vitae',
      icon: Icons.bloodtype_rounded,
      color: Color(0xFFE53935),
    ),
  ];

  static final Map<String, ElementRes> byElementId = {
    for (final e in all) e.elementId: e,
  };
  static final Map<String, ElementRes> byKey = {
    for (final e in all) e.settingsKey: e,
  };
  static List<String> get settingsKeys =>
      all.map((e) => e.settingsKey).toList(growable: false);

  /// 'fire' -> 'res_embers'
  static String keyForElement(String elementId) =>
      byElementId[elementId.toLowerCase()]?.settingsKey ?? 'res_misc';

  /// Convenience to build cost maps: {'Fire':60,'Water':30} -> {'res_embers':60,'res_droplets':30}
  static Map<String, int> costByElements(Map<String, int> elementAmounts) {
    final out = <String, int>{};
    elementAmounts.forEach((elem, amt) {
      out[keyForElement(elem)] = amt;
    });
    return out;
  }
}
