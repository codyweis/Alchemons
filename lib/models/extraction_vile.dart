// lib/items/extraction_vials.dart
import 'package:alchemons/models/creature.dart';
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

/// Whether a vial of this kind can ever produce a specimen.
///
/// A vial extracts a random creature matching its elemental group AND its
/// rarity, so a combination the catalog has no creature for is a dead item:
/// it sits in your inventory forever and answers "No creatures available for
/// this vial type" every time you try to use it.
///
/// As of writing the catalog has no Mythic creatures at all, and Arcane
/// starts at Uncommon — so six of the twenty-five combinations are dead.
/// This is derived from the catalog rather than hardcoded, so adding the
/// missing creatures is all it takes to bring those vials to life.
bool vialCanProduceSpecimen(
  Iterable<Creature> creatures,
  ElementalGroup group,
  VialRarity rarity,
) {
  final types = group.elementTypes;
  final wanted = _creatureRarityFor(rarity).toLowerCase();
  for (final c in creatures) {
    if (c.rarity.toLowerCase() != wanted) continue;
    if (c.types.any(types.contains)) return true;
  }
  return false;
}

/// The creature-rarity string a vial rarity extracts.
String _creatureRarityFor(VialRarity r) => switch (r) {
  VialRarity.common => 'Common',
  VialRarity.uncommon => 'Uncommon',
  VialRarity.rare => 'Rare',
  VialRarity.legendary => 'Legendary',
  VialRarity.mythic => 'Mythic',
};

/// Public alias — callers outside this file need the same mapping.
String creatureRarityForVial(VialRarity r) => _creatureRarityFor(r);

/// The groups that can yield a specimen at [rarity]. Empty if none can.
List<ElementalGroup> groupsWithSpecimensAt(
  Iterable<Creature> creatures,
  VialRarity rarity,
) => [
  for (final g in ElementalGroup.values)
    if (vialCanProduceSpecimen(creatures, g, rarity)) g,
];

/// The rarities that can yield a specimen for [group].
List<VialRarity> raritiesWithSpecimensFor(
  Iterable<Creature> creatures,
  ElementalGroup group,
) => [
  for (final r in VialRarity.values)
    if (vialCanProduceSpecimen(creatures, group, r)) r,
];
