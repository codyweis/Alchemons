// A vial extracts a random creature matching BOTH its elemental group and its
// rarity. When the catalog has no such creature the vial is a dead item: it
// sits in the inventory forever and answers "No creatures available for this
// vial type" every time. The daily chest granted them and the black market
// sold them.

import 'dart:convert';
import 'dart:io';

import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:flutter_test/flutter_test.dart';

late final List<Creature> catalog;

void main() {
  setUpAll(() {
    final raw = jsonDecode(
      File('assets/data/alchemons_creatures.json').readAsStringSync(),
    );
    catalog = (raw['creatures'] as List)
        .map((j) => Creature.fromJson(j))
        .toList();
  });

  test('the shipped catalog is what we think it is', () {
    expect(catalog, isNotEmpty);
  });

  group('the rule matches the shipped catalog', () {
    test('arcane has no common strain, so a worn arcane vial is dead', () {
      expect(
        vialCanProduceSpecimen(
          catalog,
          ElementalGroup.arcane,
          VialRarity.common,
        ),
        isFalse,
      );
    });

    test('arcane works from uncommon upward', () {
      for (final r in [
        VialRarity.uncommon,
        VialRarity.rare,
        VialRarity.legendary,
      ]) {
        expect(
          vialCanProduceSpecimen(catalog, ElementalGroup.arcane, r),
          isTrue,
          reason: 'arcane $r should be usable',
        );
      }
    });

    test('no group has a mythic strain, so every ascendant vial is dead', () {
      for (final g in ElementalGroup.values) {
        expect(
          vialCanProduceSpecimen(catalog, g, VialRarity.mythic),
          isFalse,
          reason: '$g mythic',
        );
      }
    });

    test('every other combination is live', () {
      for (final g in ElementalGroup.values) {
        for (final r in VialRarity.values) {
          if (r == VialRarity.mythic) continue;
          if (g == ElementalGroup.arcane && r == VialRarity.common) continue;
          expect(
            vialCanProduceSpecimen(catalog, g, r),
            isTrue,
            reason: '$g $r should be usable',
          );
        }
      }
    });
  });

  group('the roll helpers only offer live combinations', () {
    test('groupsWithSpecimensAt(common) excludes arcane', () {
      final groups = groupsWithSpecimensAt(catalog, VialRarity.common);
      expect(groups, isNotEmpty);
      expect(groups, isNot(contains(ElementalGroup.arcane)));
      // The daily chest rolls from this list, so it must stay non-empty.
      expect(groups.length, 4);
    });

    test('groupsWithSpecimensAt(mythic) is empty, not a broken default', () {
      expect(groupsWithSpecimensAt(catalog, VialRarity.mythic), isEmpty);
    });

    test('raritiesWithSpecimensFor(arcane) starts at uncommon', () {
      final rarities = raritiesWithSpecimensFor(catalog, ElementalGroup.arcane);
      expect(rarities.first, VialRarity.uncommon);
      expect(rarities, isNot(contains(VialRarity.common)));
      expect(rarities, isNot(contains(VialRarity.mythic)));
    });

    test('every group can deliver something, so none is wholly unstockable', () {
      for (final g in ElementalGroup.values) {
        expect(raritiesWithSpecimensFor(catalog, g), isNotEmpty, reason: '$g');
      }
    });
  });

  test('the vial rarity to creature rarity mapping is total', () {
    for (final r in VialRarity.values) {
      expect(creatureRarityForVial(r), isNotEmpty);
    }
    expect(creatureRarityForVial(VialRarity.common), 'Common');
    expect(creatureRarityForVial(VialRarity.mythic), 'Mythic');
  });

  test('an empty catalog makes everything dead rather than throwing', () {
    for (final g in ElementalGroup.values) {
      for (final r in VialRarity.values) {
        expect(vialCanProduceSpecimen(const [], g, r), isFalse);
      }
    }
    expect(groupsWithSpecimensAt(const [], VialRarity.common), isEmpty);
  });
}
