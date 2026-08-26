import 'dart:convert';
import 'dart:io';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/dungeon_debug_party.dart';
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

  // The fabrication used to live as private methods on the cosmic screen's
  // state. The profile's dungeon menu enters the same dungeons with no cosmic
  // screen in the tree, so it moved to dungeon_debug_party.dart — these pin
  // the behaviour that move had to preserve.
  group('the shared fabricator', () {
    test('fields a full party for every built dungeon', () {
      for (final element in kPlanetDungeonLayouts.keys) {
        final party = debugIdealTrio(catalog, element);
        expect(
          party.length,
          kCosmicPlanetEntry[element]!.length,
          reason:
              '$element: one companion per entry slot, or the front door '
              'cannot be opened',
        );
      }
    });

    test('each companion answers its own entry slot, in order', () {
      // Index alignment is the whole contract: slot i is opened by the
      // creature at position i, so a shuffled party silently fails element
      // gates that the trio was built to satisfy.
      for (final element in kPlanetDungeonLayouts.keys) {
        final slots = kCosmicPlanetEntry[element]!;
        final party = debugIdealTrio(catalog, element);
        for (var i = 0; i < slots.length; i++) {
          expect(party[i].element, slots[i], reason: '$element slot $i');
        }
      }
    });

    test('every trio matches its ideal families exactly', () {
      // The fallback (any creature of the element) exists so a descent still
      // happens when no species fits, but it leaves hard family gates without
      // a key. Today nothing needs it, and the menu's warning row should stay
      // unreachable — if this fails, the menu will start warning.
      for (final element in kPlanetDungeonLayouts.keys) {
        expect(
          debugTrioIsExact(catalog, element),
          isTrue,
          reason: '$element cannot field its ideal families',
        );
        final families = kDungeonIdealFamilies[element]!;
        final party = debugIdealTrio(catalog, element);
        for (var i = 0; i < families.length; i++) {
          expect(
            party[i].family,
            families[i].toLowerCase(),
            reason: '$element slot $i',
          );
        }
      }
    });

    test('companions are animated, never Mystic, and fully statted', () {
      for (final element in kPlanetDungeonLayouts.keys) {
        for (final m in debugIdealTrio(catalog, element)) {
          // The dungeon renders sprite sheets; a sheetless companion is
          // invisible rather than merely ugly.
          expect(m.spriteSheet, isNotNull, reason: '$element ${m.displayName}');
          expect(m.family, isNot('mystic'), reason: element);
          expect(m.statStrength, kDebugPartyStatTier.toDouble());
          expect(m.statSpeed, kDebugPartyStatTier.toDouble());
        }
      }
    });

    test('an unbuilt or unknown element fabricates nothing', () {
      // The menu only lists built dungeons, but the helper is public now and
      // must refuse rather than hand back a half party.
      expect(debugIdealTrio(catalog, 'Nexus'), isEmpty);
      expect(debugIdealTrio(catalog, 'NotAnElement'), isEmpty);
      expect(debugTrioIsExact(catalog, 'NotAnElement'), isFalse);
    });

    test('the stat tier is honoured, so the sandbox dial still works', () {
      // The cosmic sandbox passes its own tier through this same function.
      final party = debugIdealTrio(catalog, 'Fire', statTier: 1);
      expect(party, isNotEmpty);
      for (final m in party) {
        expect(m.statBeauty, 1.0);
      }
    });
  });
}
