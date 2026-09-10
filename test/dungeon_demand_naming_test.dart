// The descent says what it wants, by name.
//
// The planet used to put its inner gates in verse, which meant the answer had
// to be known before you packed a party — so the puzzle was solved at the
// locked door or not at all. These pin the plain wording that replaced it.

import 'package:flutter_test/flutter_test.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';

void main() {
  test('a specific creature is named the way the roster names it', () {
    const demand = DungeonEntryDemand(
      family: 'Mane',
      element: 'Air',
      label: 'Air MANE',
    );
    expect(demand.speciesLabel, 'Airmane');
  });

  test('a verb-only gate names the family, not a creature', () {
    const demand = DungeonEntryDemand(family: 'Horn', label: 'any HORN');
    expect(demand.speciesLabel, 'Any Horn');
  });

  test('every authored demand reads as a name, never a verse', () {
    for (final element in kPlanetDungeonLayouts.keys) {
      for (final demand in dungeonEntryDemands(element)) {
        final label = demand.speciesLabel;
        expect(label.trim(), label, reason: '$element: "$label" is padded');
        expect(
          label.split(' ').length,
          lessThanOrEqualTo(2),
          reason: '$element: "$label" should be a name, not a phrase',
        );
        expect(
          label,
          isNot(contains(',')),
          reason: '$element: "$label" reads like prose',
        );
        // A named creature is one word; only the any-family form has two.
        if (demand.element != null) {
          expect(
            label.split(' ').length,
            1,
            reason: '$element: "$label" should be Elementfamily',
          );
          expect(label, startsWith(demand.element!));
          expect(label, endsWith(demand.family.toLowerCase()));
        } else {
          expect(label, 'Any ${demand.family}');
        }
      }
    }
  });
}
