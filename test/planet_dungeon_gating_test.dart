import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _member(String element, {String family = 'Wing'}) {
  return CosmicPartyMember(
    instanceId: 'i-$element-$family',
    baseId: 'b-$element-$family',
    displayName: '$element $family',
    element: element,
    family: family,
    level: 5,
    statSpeed: 3.0,
    statIntelligence: 3.0,
    statStrength: 3.0,
    statBeauty: 3.0,
    slotIndex: 0,
    staminaBars: 5,
    staminaMax: 5,
  );
}

void main() {
  group('cosmicPartySatisfiesEntry', () {
    test('passes when party covers the required elements', () {
      final party = [_member('Air'), _member('Lightning'), _member('Fire')];
      expect(
        cosmicPartySatisfiesEntry(party, ['Air', 'Lightning', 'Fire']),
        isTrue,
      );
    });

    test('fails when a required element is missing', () {
      final party = [_member('Air'), _member('Lightning'), _member('Water')];
      expect(
        cosmicPartySatisfiesEntry(party, ['Air', 'Lightning', 'Fire']),
        isFalse,
      );
    });

    test('extra creatures and nulls are ignored', () {
      final party = <CosmicPartyMember?>[
        _member('Air'),
        null,
        _member('Lightning'),
        _member('Fire'),
        _member('Dark'),
      ];
      expect(
        cosmicPartySatisfiesEntry(party, ['Air', 'Lightning', 'Fire']),
        isTrue,
      );
    });

    test('duplicate requirement needs distinct members of that element', () {
      expect(
        cosmicPartySatisfiesEntry([_member('Air')], ['Air', 'Air']),
        isFalse,
      );
      expect(
        cosmicPartySatisfiesEntry(
          [_member('Air'), _member('Air'), _member('Fire')],
          ['Air', 'Air', 'Fire'],
        ),
        isTrue,
      );
    });

    test('Air pilot requirement is wired in kCosmicPlanetEntry', () {
      expect(kCosmicPlanetEntry['Air'], ['Air', 'Lightning', 'Fire']);
    });
  });

  group('PlanetStarState', () {
    test('serialise -> deserialise round-trips earned stars', () {
      var state = PlanetStarState.fresh()
          .withStar('Air', 0)
          .withStar('Air', 2)
          .withStar('Fire', 1);

      final restored = PlanetStarState.deserialise(state.serialise());

      expect(restored.hasStar('Air', 0), isTrue);
      expect(restored.hasStar('Air', 1), isFalse);
      expect(restored.hasStar('Air', 2), isTrue);
      expect(restored.starsEarned('Air'), 2);
      expect(restored.hasStar('Fire', 1), isTrue);
      expect(restored.starsEarned('Fire'), 1);
      expect(restored.starsEarned('Water'), 0);
    });

    test('fresh state serialises to empty and round-trips', () {
      expect(PlanetStarState.fresh().serialise(), '');
      expect(PlanetStarState.deserialise('').starsEarned('Air'), 0);
    });

    test('claimed rewards: pending + round-trip', () {
      var state = PlanetStarState.fresh()
          .withStar('Air', 0)
          .withStar('Air', 1)
          .withStar('Air', 2)
          .withClaimed('Air', 0);

      // Star 0 claimed; 1 and 2 still pending.
      expect(state.pendingRewards('Air'), [1, 2]);
      expect(state.hasClaimed('Air', 0), isTrue);
      expect(state.hasClaimed('Air', 1), isFalse);

      final restored = PlanetStarState.deserialise(state.serialise());
      expect(restored.hasStar('Air', 2), isTrue);
      expect(restored.hasClaimed('Air', 0), isTrue);
      expect(restored.pendingRewards('Air'), [1, 2]);
    });

    test('earning a star does not auto-claim its reward', () {
      final state = PlanetStarState.fresh().withStar('Air', 0);
      expect(state.hasStar('Air', 0), isTrue);
      expect(state.hasClaimed('Air', 0), isFalse);
      expect(state.pendingRewards('Air'), [0]);
    });

    test('deserialises the old earned-only format (no claimed)', () {
      // Pre-rewards saves were "element=mask".
      final restored = PlanetStarState.deserialise('Air=7');
      expect(restored.starsEarned('Air'), 3);
      expect(restored.hasClaimed('Air', 0), isFalse);
      expect(restored.pendingRewards('Air'), [0, 1, 2]);
    });

    test('discovered cloud echoes persist with star state', () {
      final state = PlanetStarState.fresh()
          .withDiscoveredCloud('Air', 'c_ring')
          .withDiscoveredCloud('Air', 'c_spiral')
          .withStar('Air', 1);

      final restored = PlanetStarState.deserialise(state.serialise());

      expect(restored.hasStar('Air', 1), isTrue);
      expect(restored.discoveredCloudsFor('Air'), {'c_ring', 'c_spiral'});
      expect(restored.discoveredCloudsFor('Fire'), isEmpty);
    });
  });

  group('PlanetRecipe.fromEntryRequirement', () {
    test('trims the trio to two, home element kept and dominant', () {
      final recipe = PlanetRecipe.fromEntryRequirement(
        element: 'Air',
        slots: const ['Air', 'Lightning', 'Fire'],
        level: 1,
      );

      expect(recipe.planetElement, 'Air');
      // Two elements at most. A trio of three distinct elements is trimmed to
      // the two heaviest, and the rest falls inside the tolerance band —
      // three named elements read as a shopping list rather than a recipe.
      expect(recipe.components.length, 2);
      // The home element is nudged above the others, so it always survives
      // the cut on a planet that asks for itself.
      expect(recipe.components.containsKey('Air'), isTrue);
      // Fire and Lightning weigh the same here, so which one keeps its place
      // is settled by name rather than by sort order — the same seed has to
      // rebuild the same recipe.
      expect(recipe.components.containsKey('Fire'), isTrue);
      expect(recipe.components['Air']! > recipe.components['Fire']!, isTrue);
      final again = PlanetRecipe.fromEntryRequirement(
        element: 'Air',
        slots: const ['Air', 'Lightning', 'Fire'],
        level: 1,
      );
      expect(again.components, recipe.components);
      // Components + random tolerance sum to ~100%.
      final total =
          recipe.components.values.fold(0.0, (s, v) => s + v) +
          recipe.randomPct;
      expect(total, closeTo(100.0, 0.001));
    });
  });
}
