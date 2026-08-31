// Every element has its own glyph, and only its own.
//
// The icon used to live as a switch on AltarEntry, and it routed through the
// Material→Phosphor aliases, where several names collapse onto one glyph:
// `water_drop`, `water_damage` and `bloodtype` are all `drop`. Harmless as a
// rename, useless as an identity — Water, Mud and Blood came out identical.
//
// Now there is one table. These pin that it stays complete and stays distinct,
// because a duplicate reads to the player as the wrong element rather than as
// a missing icon.

import 'package:alchemons/data/mystic_altar_data.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every element has a glyph', () {
    for (final element in kElementColors.keys) {
      expect(
        elementIconFor(element),
        isNot(AppIcons.help_outline),
        reason: '$element falls through to the question mark',
      );
    }
  });

  test('no two elements share one', () {
    final seen = <IconData, String>{};
    for (final element in kElementColors.keys) {
      final icon = elementIconFor(element);
      expect(
        seen[icon],
        isNull,
        reason: '$element and ${seen[icon]} draw the same glyph',
      );
      seen[icon] = element;
    }
    expect(seen.length, kElementColors.length);
  });

  test('it does not care how the element is spelled', () {
    expect(elementIconFor('fire'), elementIconFor('Fire'));
    expect(elementIconFor('BLOOD'), elementIconFor('Blood'));
  });

  test('the altar reads the same table', () {
    // It kept its own switch for a while; a second copy is how the two
    // screens drifted apart in the first place.
    for (final entry in kAltarEntries) {
      expect(entry.elementIcon, elementIconFor(entry.element));
    }
  });
}
