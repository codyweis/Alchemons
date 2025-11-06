// lib/items/extraction_vials.dart
import 'package:alchemons/models/elemental_group.dart';

const List<String> kRarityOrder = [
  'Common',
  'Uncommon',
  'Rare',
  'Legendary',
  'Mythic',
];

enum VialRarity { common, uncommon, rare, legendary, mythic }

extension VialRarityX on VialRarity {
  String get label => kRarityOrder[index];
}

/// single key format for inventory table
String vialKey(ElementalGroup group, VialRarity rarity) =>
    'vial.${groupIdFrom(group)}.${rarity.name}';
