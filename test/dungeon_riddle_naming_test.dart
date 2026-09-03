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
  /// What slot [i] of [element] actually demands: a strict element+family
  /// gate, a verb-only gate (any creature of that family), or nothing beyond
  /// the element itself.
  String demandFor(String element, int i) {
    final layout = kPlanetDungeonLayouts[element]!;
    final els = kCosmicPlanetEntry[element]!;
    final fams = kDungeonIdealFamilies[element]!;
    final strict = layout.familyGates.any(
      (g) =>
          g.needsElement &&
          g.element == els[i] &&
          g.family.toLowerCase() == fams[i].toLowerCase(),
    );
    if (strict) return 'strict';
    final verbOnly = layout.familyGates.any(
      (g) => !g.needsElement && g.family.toLowerCase() == fams[i].toLowerCase(),
    );
    return verbOnly ? 'any' : 'element';
  }

  const families = ['wing', 'horn', 'mane', 'mask', 'pip', 'kin'];

  /// Whole-word match, so "kin" does not fire on "kind" and "pip" does not
  /// fire on "piping".
  bool names(String line, String family) =>
      RegExp('\\b$family\\b', caseSensitive: false).hasMatch(line);

  group('a line asks for exactly what its slot demands', () {
    test('one line per entry slot', () {
      kPlanetDungeonLayouts.forEach((element, layout) {
        expect(
          layout.riddle.length,
          kCosmicPlanetEntry[element]!.length,
          reason: '$element: one verse line per element the descent needs',
        );
      });
    });

    test('every line names its slot\'s ELEMENT', () {
      // The three elements are always required, gate or no gate.
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

    test('a family is named ONLY where one is actually demanded', () {
      // The point of the pass. An ungated slot that names a family is asking
      // for something the door does not check, which sends the player
      // breeding for a key that was never needed.
      kPlanetDungeonLayouts.forEach((element, layout) {
        final fams = kDungeonIdealFamilies[element]!;
        for (var i = 0; i < layout.riddle.length; i++) {
          final line = layout.riddle[i];
          final named = families.where((f) => names(line, f)).toList();
          switch (demandFor(element, i)) {
            case 'element':
              expect(
                named,
                isEmpty,
                reason:
                    '$element line ${i + 1} is element-only but names '
                    '${named.join(", ")}',
              );
            case 'strict':
            case 'any':
              expect(
                named,
                [fams[i].toLowerCase()],
                reason:
                    '$element line ${i + 1} should name exactly '
                    '${fams[i].toLowerCase()}',
              );
          }
        }
      });
    });

    test('a verb-only gate says ANY; a strict one does not', () {
      // "an Air WING" and "an Air, and any WING at all" are different
      // promises, and the second is the one a player can satisfy from stock.
      kPlanetDungeonLayouts.forEach((element, layout) {
        for (var i = 0; i < layout.riddle.length; i++) {
          final line = layout.riddle[i].toLowerCase();
          switch (demandFor(element, i)) {
            case 'any':
              expect(
                line,
                contains('any'),
                reason:
                    '$element line ${i + 1} gates on the family alone, '
                    'so it must not read as an element+family lock',
              );
            case 'strict':
              expect(
                line,
                isNot(contains('any')),
                reason: '$element line ${i + 1} is a strict lock',
              );
            case 'element':
              break;
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
            RegExp(r'[:,;]').hasMatch(line),
            isTrue,
            reason: '$element line ${i + 1} has no second clause',
          );
        }
      });
    });

    test('the article is always "a", never "an"', () {
      // An authored voice, not English class: "a Ice Mane" is the house style
      // and reads consistently down the placard where "an" kept snagging.
      // Only before a NAME — ordinary prose ("in an age") is untouched.
      kPlanetDungeonLayouts.forEach((element, layout) {
        for (var i = 0; i < layout.riddle.length; i++) {
          expect(
            RegExp(r'\ban (?=[A-Z])').hasMatch(layout.riddle[i]),
            isFalse,
            reason: '$element line ${i + 1} uses "an"',
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
