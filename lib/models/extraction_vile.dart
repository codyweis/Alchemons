// lib/items/extraction_vials.dart
import 'package:alchemons/models/elemental_group.dart';

const List<String> kRarityOrder = [
  'Worn Vial',
  'Runed Vial',
  'Sigiled Vial',
  'Eclipse Vial',
  'Ascendant Vial',
];

enum VialRarity { common, uncommon, rare, legendary, mythic }

extension VialRarityX on VialRarity {
  String get label => kRarityOrder[index];

  String get badgeLabel => label.replaceFirst(RegExp(r'\s+Vial$'), '');

  String get grade => switch (this) {
    VialRarity.common => 'worn',
    VialRarity.uncommon => 'runed',
    VialRarity.rare => 'sigiled',
    VialRarity.legendary => 'eclipse',
    VialRarity.mythic => 'ascendant',
  };
}

/// single key format for inventory table
String vialKey(ElementalGroup group, VialRarity rarity) =>
    'vial.${groupIdFrom(group)}.${rarity.name}';
