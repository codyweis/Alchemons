import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_verbs.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _member(String element, String family) => CosmicPartyMember(
      instanceId: 'i', baseId: 'b', displayName: 'd',
      element: element, family: family, level: 5,
      statSpeed: 3, statIntelligence: 3, statStrength: 3, statBeauty: 3,
      slotIndex: 0, staminaBars: 5, staminaMax: 5,
    );

void main() {
  group('abilityForFamily', () {
    test('maps each family to its dungeon ability', () {
      expect(abilityForFamily('Pip'), DungeonAbility.smallAccess);
      expect(abilityForFamily('Mane'), DungeonAbility.terrainTrail);
      expect(abilityForFamily('Horn'), DungeonAbility.heavyForce);
      expect(abilityForFamily('mask'), DungeonAbility.insight);
      expect(abilityForFamily('WING'), DungeonAbility.aerialTraversal);
      expect(abilityForFamily('Kin'), DungeonAbility.ancientStabilize);
      expect(abilityForFamily('Mystic'), DungeonAbility.guardianRelic);
      expect(abilityForFamily('???'), DungeonAbility.none);
    });
  });

  group('statForAbility', () {
    test('keys each ability off the intended stat', () {
      expect(statForAbility(DungeonAbility.aerialTraversal),
          CosmicContestTrait.speed);
      expect(statForAbility(DungeonAbility.insight),
          CosmicContestTrait.intelligence);
      expect(statForAbility(DungeonAbility.heavyForce),
          CosmicContestTrait.strength);
      expect(statForAbility(DungeonAbility.ancientStabilize),
          CosmicContestTrait.beauty);
      expect(statForAbility(DungeonAbility.guardianRelic), isNull);
    });
  });

  // v2: there is no quality ladder. A requirement is either ELEMENT-ONLY
  // (every family passes at full power) or a HARD GATE (right element AND
  // right family, else a clean refusal). Recipes buy an ELEMENT, never a
  // family. See docs/dungeons.md §5.
  group('evaluateInteraction — HARD GATE (requiredFamily set)', () {
    const gate = DungeonInteractionRequirement(
      element: 'Lightning',
      requiredFamily: DungeonAbility.heavyForce, // Horn
    );

    test('the named family of the named element passes', () {
      expect(evaluateInteraction(_member('Lightning', 'Horn'), gate),
          InteractionResult.passed);
    });

    test('right element, wrong family is blockedFamily — no middle tier', () {
      // Every non-Horn Lightning is refused identically: the gate has no
      // "works but weaker" rung for any of them.
      for (final family in const ['Pip', 'Mane', 'Mask', 'Wing', 'Kin']) {
        expect(
          evaluateInteraction(_member('Lightning', family), gate),
          InteractionResult.blockedFamily,
          reason: '$family must be refused outright at a hard gate',
        );
      }
    });

    test('wrong element is blockedElement, not blockedFamily', () {
      expect(evaluateInteraction(_member('Water', 'Horn'), gate),
          InteractionResult.blockedElement);
    });

    test('a recipe supplies the ELEMENT but never opens the family gate', () {
      const recipeGate = DungeonInteractionRequirement(
        element: 'Lightning',
        requiredFamily: DungeonAbility.heavyForce,
        allowRecipe: true,
      );
      // The braid stands in for Lightning — the Horn requirement still holds.
      expect(
        evaluateInteraction(_member('Water', 'Pip'), recipeGate,
            recipeAvailable: true),
        InteractionResult.blockedFamily,
      );
      expect(
        evaluateInteraction(_member('Water', 'Horn'), recipeGate,
            recipeAvailable: true),
        InteractionResult.passedViaRecipe,
      );
    });
  });

  group('evaluateInteraction — ELEMENT-ONLY (requiredFamily null)', () {
    const anyFam = DungeonInteractionRequirement(element: 'Air');

    test('every family of the element passes at full power', () {
      for (final family in const [
        'Pip', 'Mane', 'Horn', 'Mask', 'Wing', 'Kin', '???',
      ]) {
        expect(
          evaluateInteraction(_member('Air', family), anyFam),
          InteractionResult.passed,
          reason: '$family must act at full power on an element-only object',
        );
      }
    });

    test('blockedFamily is unreachable without a family gate', () {
      const withRecipe = DungeonInteractionRequirement(
        element: 'Ice',
        allowRecipe: true,
      );
      expect(evaluateInteraction(_member('Fire', 'Pip'), withRecipe),
          InteractionResult.blockedElement);
      expect(
        evaluateInteraction(_member('Spirit', 'Pip'), withRecipe,
            recipeAvailable: true),
        InteractionResult.passedViaRecipe,
      );
    });
  });

  group('stat gates', () {
    test('an unmet min* stat blocks after element/family clear', () {
      const needsSpeed = DungeonInteractionRequirement(
        element: 'Air',
        requiredFamily: DungeonAbility.aerialTraversal,
        minSpeed: 4,
      );
      final fast = CosmicPartyMember(
        instanceId: 'i', baseId: 'b', displayName: 'd',
        element: 'Air', family: 'Wing', level: 5,
        statSpeed: 5, statIntelligence: 3, statStrength: 3, statBeauty: 3,
        slotIndex: 0, staminaBars: 5, staminaMax: 5,
      );
      final slow = _member('Air', 'Wing'); // statSpeed 3
      expect(evaluateInteraction(fast, needsSpeed), InteractionResult.passed);
      expect(
        evaluateInteraction(slow, needsSpeed),
        InteractionResult.blockedStat,
        reason: 'a stat shortfall is its own refusal, distinct from family',
      );
      expect(needsSpeed.meetsStats(fast), isTrue);
      expect(needsSpeed.meetsStats(slow), isFalse);
      expect(needsSpeed.isHardGate, isTrue);
    });

    test('stats never gate an object that sets no min*', () {
      const free = DungeonInteractionRequirement(element: 'Air');
      expect(free.isHardGate, isFalse);
      expect(evaluateInteraction(_member('Air', 'Kin'), free),
          InteractionResult.passed);
    });
  });

  group('recipe table', () {
    test('order-independent lookups', () {
      expect(dungeonRecipeResult('Air', 'Fire'), 'Lightning');
      expect(dungeonRecipeResult('Fire', 'Air'), 'Lightning');
      expect(dungeonRecipeResult('Ice', 'Lava'), 'Steam');
      expect(dungeonRecipeResult('Crystal', 'Spirit'), 'Light');
      expect(dungeonRecipeResult('Water', 'Dark'), isNull);
    });
  });

  group('stat-scaled tunables', () {
    test('glideSeconds 3..8, rises with Speed', () {
      expect(glideSeconds(1.0), closeTo(3.0, 0.001));
      expect(glideSeconds(5.0), closeTo(8.0, 0.001));
      expect(glideSeconds(9.0), closeTo(8.0, 0.001));
    });
    test('revealHintTier steps 0→1→2', () {
      expect(revealHintTier(1.0), 0);
      expect(revealHintTier(3.0), 1);
      expect(revealHintTier(5.0), 2);
    });
    test('channelHoldSeconds 3..10', () {
      expect(channelHoldSeconds(1.0), closeTo(3.0, 0.001));
      expect(channelHoldSeconds(5.0), closeTo(10.0, 0.001));
    });
    test('charmOk needs high Beauty', () {
      expect(charmOk(5.0), isTrue);
      expect(charmOk(3.4), isTrue);
      expect(charmOk(3.0), isFalse);
    });
  });
}
