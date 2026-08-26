// The riddle says what to bring, in as many words.
//
// It used to encode the family by its dungeon VERB and never name it — "one
// the ground cannot keep" for a Wing, "where the grip is strongest" for a
// Horn. That made sense while the riddle was the ONLY thing telling a
// first-time visitor what to pack: the requirement chips appeared on the
// descent panel only after you had already walked into a gate and been
// refused, so the verse had to carry the puzzle.
//
// It does not carry it any more. The panel now declares every gate before you
// commit and the door refuses a party that cannot open them, so an encoded
// riddle is a puzzle whose answer is printed directly underneath it — and,
// as a review of all 51 lines found, five planets were encoding the WRONG
// family and actively misleading anyone who trusted them.
//
// So the rule is inverted: name the element and name the family, keep the
// planet's voice for everything else. This is the test that keeps it honest,
// because a riddle that lies is worse than no riddle at all.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('every riddle line names its own slot', () {
    test('one line per entry slot', () {
      kPlanetDungeonLayouts.forEach((element, layout) {
        expect(
          layout.riddle.length,
          kCosmicPlanetEntry[element]!.length,
          reason: '$element: one verse line per element the descent needs',
        );
      });
    });

    test('line i names slot i\'s ELEMENT', () {
      kPlanetDungeonLayouts.forEach((element, layout) {
        final els = kCosmicPlanetEntry[element]!;
        for (var i = 0; i < layout.riddle.length; i++) {
          expect(
            layout.riddle[i].toLowerCase(),
            contains(els[i].toLowerCase()),
            reason: '$element line ${i + 1} should name ${els[i]}',
          );
        }
      });
    });

    test('line i names slot i\'s FAMILY, in capitals', () {
      // Capitals because the family is the operative word — the line is a
      // shopping list in a planet's voice, and the eye should find it.
      kPlanetDungeonLayouts.forEach((element, layout) {
        final fams = kDungeonIdealFamilies[element]!;
        for (var i = 0; i < layout.riddle.length; i++) {
          expect(
            layout.riddle[i],
            contains(fams[i].toUpperCase()),
            reason:
                '$element line ${i + 1} should name ${fams[i].toUpperCase()}',
          );
        }
      });
    });

    test('a line never names a family that is not its own', () {
      // The exact failure the review turned up: Air line 2 carried the Mask
      // cue while its slot wanted a Horn. Naming plainly does not help if a
      // line names TWO families and only one of them is right.
      const families = ['WING', 'HORN', 'MANE', 'MASK', 'PIP', 'KIN'];
      kPlanetDungeonLayouts.forEach((element, layout) {
        final fams = kDungeonIdealFamilies[element]!;
        for (var i = 0; i < layout.riddle.length; i++) {
          final mine = fams[i].toUpperCase();
          for (final other in families) {
            if (other == mine) continue;
            expect(
              layout.riddle[i],
              isNot(contains(other)),
              reason:
                  '$element line ${i + 1} wants a $mine but also says $other',
            );
          }
        }
      });
    });
  });

  group('the verse is still a voice, not a table', () {
    test('every line says something beyond the requirement', () {
      // Guards the other direction: "Bring a Dust MASK." satisfies every
      // check above and is not worth showing. Each line keeps a clause of the
      // planet's own character.
      kPlanetDungeonLayouts.forEach((element, layout) {
        for (var i = 0; i < layout.riddle.length; i++) {
          final line = layout.riddle[i];
          expect(
            line.length,
            greaterThan(40),
            reason: '$element line ${i + 1} is a bare requirement, not verse',
          );
          expect(
            RegExp(r'[—,;]').hasMatch(line),
            isTrue,
            reason: '$element line ${i + 1} has no second clause',
          );
        }
      });
    });

    test('the verse reads as one sentence across its lines', () {
      // First line opens, last line closes. Anything else and the three read
      // as unrelated fragments stacked on the placard.
      kPlanetDungeonLayouts.forEach((element, layout) {
        expect(
          layout.riddle.first.startsWith('Send me'),
          isTrue,
          reason: '$element: the first line should open the verse',
        );
        expect(
          layout.riddle.last.endsWith('.'),
          isTrue,
          reason: '$element: the last line should close the verse',
        );
        for (final line in layout.riddle.take(layout.riddle.length - 1)) {
          expect(
            line.endsWith(';'),
            isTrue,
            reason: '$element: middle lines run on with a semicolon',
          );
        }
      });
    });
  });
}
