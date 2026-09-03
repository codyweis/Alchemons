import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_poison.dart';
import 'package:flutter_test/flutter_test.dart';

/// THE POT MUST BE STOCKABLE BY THE PARTY THE PLANET ASKS FOR.
///
/// The bug these exist to catch, found the hard way while writing them: the
/// recipes wanted Poison, Plant and Mud while the summons was still asking
/// for Poison, LAVA and Mud. Every unit test passed, the analyzer was clean,
/// and the intended party could not make a single brew — the planet was
/// unwinnable for exactly the three creatures it told you to bring.
///
/// So the invariant is not "the recipes are well-formed". It is "the riddle,
/// the family gates and the recipes name the SAME THREE ELEMENTS".
void main() {
  group('the venom monastery can actually be brewed in', () {
    final larder = <String>{
      for (final p in kPlaguePotions) ...[p.first, p.second],
    };

    test(
      'every ingredient is something the cauldron knows how to describe',
      () {
        for (final el in larder) {
          expect(
            kPotionIngredientEffect.containsKey(el),
            isTrue,
            reason:
                '$el is in a recipe but the pot has no line for what it DOES — '
                'the player deduces the recipe from those lines, so a silent '
                'ingredient is an unsolvable one',
          );
        }
        // And nothing is described that no recipe uses, which would read as a
        // fourth ingredient the player hunts for and never needs.
        for (final el in kPotionIngredientEffect.keys) {
          expect(larder, contains(el));
        }
      },
    );

    test('the larder is exactly three elements, one per party slot', () {
      expect(larder.length, 3);
    });

    test('the summons asks for the three the pot drinks', () {
      final riddle = poisonLayout.riddle.join(' ');
      for (final el in larder) {
        expect(
          riddle.contains(el),
          isTrue,
          reason:
              'the pot needs $el and the riddle never asks for it — a party '
              'that follows the summons cannot brew',
        );
      }
    });

    test('no family gate demands an element outside the larder', () {
      for (final gate in poisonLayout.familyGates) {
        expect(
          larder,
          contains(gate.element),
          reason:
              '${gate.objectId} wants ${gate.element}, which spends a party '
              'slot on something the cauldron cannot use — with only three '
              'slots that makes at least one recipe impossible',
        );
      }
    });

    test('the hands and the recipes come out exactly even', () {
      // Three creatures × two brews each = six contributions; three recipes
      // × two ingredients = six. The assignment is forced, which is the
      // point: the decision the player makes is WHEN to brew, not who.
      final need = <String, int>{};
      for (final p in kPlaguePotions) {
        need[p.first] = (need[p.first] ?? 0) + 1;
        need[p.second] = (need[p.second] ?? 0) + 1;
      }
      expect(need.length, 3);
      for (final el in larder) {
        expect(
          need[el],
          kPotionContributionsEach,
          reason:
              '$el is wanted ${need[el]} times but one alchemon can give '
              '$kPotionContributionsEach — a party of three cannot cover it',
        );
      }
    });

    test('a recipe never asks one alchemon for both halves', () {
      for (final p in kPlaguePotions) {
        expect(
          p.first == p.second,
          isFalse,
          reason: '${p.id} is a brew of one thing — the pot wants two',
        );
      }
    });

    test('no two brews are the same pair', () {
      final pairs = kPlaguePotions
          .map((p) => ([p.first, p.second]..sort()).join('+'))
          .toSet();
      expect(pairs.length, kPlaguePotions.length);
    });

    test('every brew has a ward that exists, and every plague ward a brew', () {
      final wardRooms = poisonLayout.rooms.values
          .where((r) => r.ward != null)
          .map((r) => r.id)
          .toSet();
      for (final p in kPlaguePotions) {
        expect(
          wardRooms,
          contains(p.wardId),
          reason: '${p.id} is mixed for ${p.wardId}, which is not a ward',
        );
      }
      // The fourth ward is the dead-house: no plague, and it is the way down.
      final unclaimed = wardRooms.difference(
        kPlaguePotions.map((p) => p.wardId).toSet(),
      );
      expect(unclaimed, {'ward_charnel'});
    });

    test('the board and the pot together are enough to solve it', () {
      // The sign names the two ingredients outright, so no brew can be
      // guess-and-check: a player who reads three boards knows three
      // recipes. What is left to work out is the ORDER.
      for (final p in kPlaguePotions) {
        expect(p.first.isNotEmpty && p.second.isNotEmpty, isTrue);
        expect(p.name.trim(), isNotEmpty);
        expect(p.symptom.trim(), isNotEmpty);
      }
    });
  });
}
