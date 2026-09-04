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
      for (final p in kAllBrews) ...[p.first, p.second],
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
      // FOUR recipes now, and the sums still have to land exactly. Poison is
      // wanted four times — one each for Bloomvenom and Mirebane, and BOTH
      // halves of the Pure Vial — which is why the Poison alchemon carries
      // four gives and the other two carry two. One give more anywhere and
      // the order stops mattering; one fewer and the house cannot be
      // finished at all.
      final need = <String, int>{};
      for (final p in kAllBrews) {
        need[p.first] = (need[p.first] ?? 0) + 1;
        need[p.second] = (need[p.second] ?? 0) + 1;
      }
      expect(need.length, 3);
      for (final el in larder) {
        expect(
          need[el],
          contributionsAllowedFor(el),
          reason:
              '$el is wanted ${need[el]} times and one alchemon can give '
              '${contributionsAllowedFor(el)} — the party cannot cover it',
        );
      }
      expect(
        contributionsAllowedFor('Poison'),
        kPoisonContributions,
        reason: 'the double-Poison recipe is the reason for the extra two',
      );
    });

    test('exactly one recipe asks the same hand twice', () {
      final doubles = kAllBrews.where((p) => p.first == p.second).toList();
      expect(
        doubles.map((p) => p.id),
        [kPureVial.id],
        reason:
            'the pure vial is the only brew of one thing — if a second '
            'appears the four-give allowance stops adding up',
      );
    });

    test('no two brews are the same pair', () {
      final pairs = kAllBrews
          .map((p) => ([p.first, p.second]..sort()).join('+'))
          .toSet();
      expect(pairs.length, kAllBrews.length);
    });

    test('the vial wakes nothing, and every plague brew wakes something', () {
      expect(kPureVial.wardId, isNull);
      for (final p in kPlaguePotions) {
        expect(p.wardId, isNotNull, reason: '${p.id} wakes nothing');
      }
      expect(
        kAllBrews.where((p) => p.wardId == null).length,
        1,
        reason: 'one key, three answers',
      );
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

    test('no clue gives away an ingredient it does not share', () {
      // THE CLUE IS THE PUZZLE. A board that printed "POISON + PLANT" turned
      // the walk to the pot into a shopping trip.
      //
      // But the test cannot simply ban the ingredient words, because all
      // three clues call the brew "poison" — and a word that appears in
      // EVERY clue tells the player nothing about which brew is which. So
      // the real rule is about discrimination: an ingredient name may appear
      // in a clue only if it appears in all of them.
      final shared = <String>{
        for (final el in kPotionIngredientEffect.keys)
          if (kAllBrews.every(
            (p) => p.clue.toLowerCase().contains(el.toLowerCase()),
          ))
            el.toLowerCase(),
      };
      for (final p in kPlaguePotions) {
        final clue = p.clue.toLowerCase();
        for (final el in [p.first, p.second]) {
          if (shared.contains(el.toLowerCase())) continue;
          expect(
            clue.contains(el.toLowerCase()),
            isFalse,
            reason:
                '${p.id} names $el in its own clue, and the other clues do '
                'not — that is the answer printed on the question',
          );
        }
      }
    });

    test('a clue never says a verb its own brew cannot do', () {
      // The deduction is: the board says what the answer must DO, the shelf
      // says what each ingredient DOES, and the player crosses them.
      //
      // The first draft of this test demanded the reverse — that every
      // ingredient's verb appear in some clue that needs it — and Poison
      // failed it, correctly. Poison is not deduced from "sickens"; it is
      // the element every brew shares, and the third clue identifies its own
      // pair by NEGATING it ("pure poison, without its purity"). Demanding a
      // verb there would have forced a worse riddle to satisfy a test.
      //
      // What must hold is the other direction, and it is the one that can
      // actually rot: if a clue reaches for a shelf verb, the brew it is
      // written for has to contain that ingredient. Otherwise the house is
      // not being cryptic — it is lying.
      for (final p in kPlaguePotions) {
        final clue = p.clue.toLowerCase();
        for (final entry in kPotionIngredientEffect.entries) {
          final verb = entry.value.split(' ').first;
          final stem = verb.substring(0, verb.length - 1).toLowerCase();
          if (!clue.contains(stem)) continue;
          expect(
            p.takes(entry.key),
            isTrue,
            reason:
                '${p.id} tells the player to "$stem" and takes no '
                '${entry.key} — the shelf says that is what ${entry.key} '
                'does, so the board is pointing at the wrong jar',
          );
        }
      }
    });

    test('the clues discriminate: no two read the same way', () {
      // Three riddles that all crossed to the same pair would be one riddle
      // asked three times. Cheap proxy, but it bites on a copy-paste: the
      // set of shelf verbs each clue reaches for must not be identical
      // across two brews unless their ingredients differ some other way.
      String fingerprint(PlaguePotion p) {
        final clue = p.clue.toLowerCase();
        return [
          for (final e in kPotionIngredientEffect.entries)
            if (clue.contains(
              e.value
                  .split(' ')
                  .first
                  .substring(0, e.value.split(' ').first.length - 1),
            ))
              e.key,
        ].join('|');
      }

      final seen = <String, String>{};
      for (final p in kPlaguePotions) {
        final f = fingerprint(p);
        if (f.isEmpty) continue; // the negation clue reaches for no verb
        expect(
          seen.containsKey(f),
          isFalse,
          reason: '${p.id} and ${seen[f]} read identically off the shelf',
        );
        seen[f] = p.id;
      }
      expect(
        seen.length,
        greaterThanOrEqualTo(2),
        reason:
            'at least two clues have to touch the shelf, or there is nothing '
            'to cross-reference and the puzzle is three guesses',
      );
    });

    test('the three plagues do not arrive the same colour', () {
      // Everything in the lazaret is the same sick green until it is woken.
      // If all three wake green there is nothing to tell them apart in the
      // one room where telling them apart is the whole fight — and the
      // reaction each one uses in the pot is what the colour keys off, so a
      // repeat there is a repeat here.
      final reactions = kPlaguePotions.map((p) => p.pot).toSet();
      expect(
        reactions.length,
        kPlaguePotions.length,
        reason: 'two plagues sharing a reaction share a colour',
      );
    });

    test('every brew is fully identified', () {
      final ids = <String>{}, names = <String>{}, plagues = <String>{};
      final relics = <String>{}, reactions = <CauldronReaction>{};
      for (final p in kAllBrews) {
        expect(p.name.trim(), isNotEmpty);
        expect(p.plague.trim(), isNotEmpty);
        expect(p.clue.trim(), isNotEmpty);
        expect(p.relic.trim(), isNotEmpty);
        ids.add(p.id);
        names.add(p.name);
        plagues.add(p.plague);
        relics.add(p.relic);
        reactions.add(p.pot);
      }
      // Nothing shares a name, a plague, a relic or a REACTION — the pot
      // doing the same thing for two recipes would make the receipt useless.
      expect(ids.length, kAllBrews.length);
      expect(names.length, kAllBrews.length);
      expect(plagues.length, kAllBrews.length);
      expect(relics.length, kAllBrews.length);
      expect(
        reactions.length,
        kAllBrews.length,
        reason: 'two brews that look alike in the pot are one brew',
      );
    });
  });
}
