import 'dart:convert';
import 'dart:io';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// The debug descent fabricates a planet's §6 ideal team from
/// [kDungeonIdealFamilies]. If that table drifts out of step with
/// [kCosmicPlanetEntry] — or names a family/element pair no creature has — the
/// tool silently hands over the wrong trio and the hard gates can't be tested.
void main() {
  late CreatureCatalog catalog;

  setUpAll(() {
    final raw = File('assets/data/alchemons_creatures.json').readAsStringSync();
    final decoded = jsonDecode(raw);
    final list = (decoded is List ? decoded : decoded['creatures'] as List)
        .map((e) => Creature.fromJson(e as Map<String, dynamic>))
        .toList();
    catalog = CreatureCatalog.fromList(list);
  });

  group('debug ideal trio', () {
    test('every built dungeon declares one family per entry slot', () {
      for (final element in kPlanetDungeonLayouts.keys) {
        final slots = kCosmicPlanetEntry[element];
        expect(slots, isNotNull, reason: '$element has no entry requirement');
        final families = kDungeonIdealFamilies[element];
        expect(
          families,
          isNotNull,
          reason: '$element has a dungeon but no ideal-family list',
        );
        expect(
          families!.length,
          slots!.length,
          reason: '$element: ideal families must be index-aligned with slots',
        );
      }
    });

    test('every ideal element+family pair exists as a real species', () {
      kDungeonIdealFamilies.forEach((element, families) {
        final slots = kCosmicPlanetEntry[element]!;
        for (var i = 0; i < families.length; i++) {
          final want = families[i].toLowerCase();
          final match = catalog
              .byType(slots[i])
              .where((c) => c.spriteData != null)
              .where((c) => (c.mutationFamily ?? '').toLowerCase() == want);
          expect(
            match,
            isNotEmpty,
            reason:
                '$element slot $i wants a ${slots[i]} $want — no animated '
                'species matches, so the debug trio would silently fall back',
          );
        }
      });
    });

    test('a Mystic is never an ideal-team family', () {
      // Mystics are guardians, not party tools (§5) — the debug trio filters
      // them out, and the table must not ask for one either.
      for (final families in kDungeonIdealFamilies.values) {
        for (final f in families) {
          expect(f.toLowerCase(), isNot('mystic'));
        }
      }
    });
  });
}
