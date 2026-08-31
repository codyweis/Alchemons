// lib/data/mystic_altar_data.dart
//
// The Mystic Altar's slot catalogue. Each entry represents one element whose
// relic (earned by defeating that planet's dungeon guardian) can be placed at
// the altar to summon the element's mystic creature.
//
// The `id` values intentionally keep the legacy `boss_NNN` format so that
// existing persisted state (`altar_relic_placed_{id}`, `altar_summoned_{id}`,
// and AltarPlacements rows) keeps working without migration.
import 'package:flutter/material.dart';
import 'package:alchemons/widgets/app_icons.dart';

class AltarEntry {
  final String id; // legacy altar-slot id ('boss_001'..'boss_017')
  final String name; // fallback label; UI prefers the catalog mystic's name
  final String element;
  final int order; // 1-17, drives currency scaling + display order

  const AltarEntry({
    required this.id,
    required this.name,
    required this.element,
    required this.order,
  });

  Color get elementColor {
    switch (element.toLowerCase()) {
      case 'fire':
        return Colors.deepOrange;
      case 'water':
        return Colors.blue;
      case 'earth':
        return Colors.brown;
      case 'air':
        return Colors.cyan;
      case 'plant':
        return Colors.green;
      case 'ice':
        return Colors.lightBlue;
      case 'lightning':
        return Colors.yellow;
      case 'poison':
        return Colors.purple;
      case 'steam':
        return Colors.teal;
      case 'lava':
        return Colors.deepOrangeAccent;
      case 'mud':
        return Colors.brown.shade700;
      case 'dust':
        return Colors.orange.shade300;
      case 'crystal':
        return Colors.pink;
      case 'spirit':
        return Colors.indigo.shade200;
      case 'dark':
        return Colors.deepPurple.shade900;
      case 'light':
        return Colors.amber.shade100;
      case 'blood':
        return Colors.red.shade900;
      default:
        return Colors.grey;
    }
  }

  IconData get elementIcon => elementIconFor(element);

  /// Path to the relic image earned from this element's planet guardian.
  String get relicImagePath =>
      'assets/images/relics/${element.toLowerCase()}relic.png';
}

const List<AltarEntry> kAltarEntries = [
  AltarEntry(id: 'boss_001', name: 'Fire Lord', element: 'Fire', order: 1),
  AltarEntry(id: 'boss_002', name: 'Water Serpent', element: 'Water', order: 2),
  AltarEntry(id: 'boss_003', name: 'Earth Golem', element: 'Earth', order: 3),
  AltarEntry(id: 'boss_004', name: 'Air Elemental', element: 'Air', order: 4),
  AltarEntry(
    id: 'boss_005',
    name: 'Overgrown Treant',
    element: 'Plant',
    order: 5,
  ),
  AltarEntry(id: 'boss_006', name: 'Tundra Behemoth', element: 'Ice', order: 6),
  AltarEntry(
    id: 'boss_007',
    name: 'Thunder Wyvern',
    element: 'Lightning',
    order: 7,
  ),
  AltarEntry(
    id: 'boss_008',
    name: 'Plague Dragon',
    element: 'Poison',
    order: 8,
  ),
  AltarEntry(
    id: 'boss_009',
    name: 'Steam Centurion',
    element: 'Steam',
    order: 9,
  ),
  AltarEntry(id: 'boss_010', name: 'Magma Titan', element: 'Lava', order: 10),
  AltarEntry(id: 'boss_011', name: 'Swamp Horror', element: 'Mud', order: 11),
  AltarEntry(
    id: 'boss_012',
    name: 'Sandstorm Djinn',
    element: 'Dust',
    order: 12,
  ),
  AltarEntry(
    id: 'boss_013',
    name: 'Crystal Colossus',
    element: 'Crystal',
    order: 13,
  ),
  AltarEntry(
    id: 'boss_014',
    name: 'Ancient Phantom',
    element: 'Spirit',
    order: 14,
  ),
  AltarEntry(
    id: 'boss_015',
    name: 'Umbral Abomination',
    element: 'Dark',
    order: 15,
  ),
  AltarEntry(
    id: 'boss_016',
    name: 'Radiant Avatar',
    element: 'Light',
    order: 16,
  ),
  AltarEntry(id: 'boss_017', name: 'Crimson King', element: 'Blood', order: 17),
];

/// Legacy turn-based boss ids → element, used by the one-shot relic migration
/// for saves that defeated bosses before the gauntlet was removed.
const Map<String, String> kLegacyBossIdToElement = {
  'boss_001': 'Fire',
  'boss_002': 'Water',
  'boss_003': 'Earth',
  'boss_004': 'Air',
  'boss_005': 'Plant',
  'boss_006': 'Ice',
  'boss_007': 'Lightning',
  'boss_008': 'Poison',
  'boss_009': 'Steam',
  'boss_010': 'Lava',
  'boss_011': 'Mud',
  'boss_012': 'Dust',
  'boss_013': 'Crystal',
  'boss_014': 'Spirit',
  'boss_015': 'Dark',
  'boss_016': 'Light',
  'boss_017': 'Blood',
};

AltarEntry? altarEntryForElement(String element) {
  final lower = element.toLowerCase();
  for (final e in kAltarEntries) {
    if (e.element.toLowerCase() == lower) return e;
  }
  return null;
}
