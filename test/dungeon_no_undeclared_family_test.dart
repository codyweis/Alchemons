// You never need a creature the riddle did not ask for.
//
// A family requirement can be written in two places: declared on the layout as
// a DungeonFamilyGate — which the descent panel shows, the door enforces and
// the entrance verse names — or buried in a module as a bare
// DungeonInteractionRequirement literal, which announces itself to nobody.
//
// The second kind is invisible. Ice's Star-Walker maxim demanded an Ice MANE
// that no gate declared and no line of verse mentioned, so a player could
// arrive with the exact team the planet asked for and be refused at the lens
// with no way to have known. That is the failure this test exists to prevent.
//
// It reads the SOURCE, because a requirement written as a `const` inside a
// method is not reachable any other way — the same trick the shader-coverage
// test uses. Crude, and it catches the thing that matters.

import 'dart:io';

import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// DungeonAbility → the family name a gate declares.
const Map<String, String> _abilityToFamily = {
  'smallAccess': 'Pip',
  'terrainTrail': 'Mane',
  'heavyForce': 'Horn',
  'insight': 'Mask',
  'aerialTraversal': 'Wing',
  'ancientStabilize': 'Kin',
};

void main() {
  final requirement = RegExp(r'requiredFamily:\s*DungeonAbility\.(\w+)');

  /// Every family demanded anywhere in [element]'s own source.
  Set<String> familiesDemandedInSource(String element) {
    final out = <String>{};
    for (final kind in ['game', 'layout']) {
      final f = File(
        'lib/games/planet_dungeon/planet_dungeon_${kind}_'
        '${element.toLowerCase()}.dart',
      );
      if (!f.existsSync()) continue;
      for (final m in requirement.allMatches(f.readAsStringSync())) {
        final family = _abilityToFamily[m.group(1)];
        if (family != null) out.add(family);
      }
    }
    return out;
  }

  group('no dungeon demands an undeclared family', () {
    test('every family required in code is a declared gate', () {
      kPlanetDungeonLayouts.forEach((element, layout) {
        final declared = layout.familyGates
            .map((g) => g.family)
            .toSet();
        for (final family in familiesDemandedInSource(element)) {
          expect(
            declared,
            contains(family),
            reason:
                '$element requires a $family somewhere in its code but '
                'declares no gate for it — the descent panel will not show '
                'it, the door will not enforce it, and the riddle will not '
                'ask for it, so the player finds out by being refused',
          );
        }
      });
    });

    test('every declared gate is named in the entrance verse', () {
      // The other direction. A gate the door enforces but the verse omits is
      // a party the player is turned away for not bringing, with no notice.
      kPlanetDungeonLayouts.forEach((element, layout) {
        final verse = layout.riddle.join(' ').toLowerCase();
        for (final gate in layout.familyGates) {
          expect(
            verse,
            contains(gate.family.toLowerCase()),
            reason:
                '$element gates on a ${gate.family} that its riddle never '
                'mentions',
          );
        }
      });
    });

    test('a gate the verse names is a gate that exists', () {
      // And the reverse of the reverse: the verse must not send the player
      // breeding for a key nothing checks.
      const families = ['wing', 'horn', 'mane', 'mask', 'pip', 'kin'];
      kPlanetDungeonLayouts.forEach((element, layout) {
        final declared = layout.familyGates
            .map((g) => g.family.toLowerCase())
            .toSet();
        final verse = layout.riddle.join(' ');
        for (final family in families) {
          final named = RegExp(
            '\\b$family\\b',
            caseSensitive: false,
          ).hasMatch(verse);
          if (!named) continue;
          expect(
            declared,
            contains(family),
            reason:
                '$element\'s riddle asks for a $family that no gate demands',
          );
        }
      });
    });
  });
}
