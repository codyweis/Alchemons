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

  group('evaluateInteraction (quality)', () {
    const req = DungeonInteractionRequirement(
      element: 'Lightning',
      preferred: DungeonAbility.heavyForce, // Horn
    );

    test('Perfect = right element + right family', () {
      expect(evaluateInteraction(_member('Lightning', 'Horn'), req),
          InteractionQuality.perfect);
    });
    test('Valid = right element, wrong family', () {
      expect(evaluateInteraction(_member('Lightning', 'Pip'), req),
          InteractionQuality.valid);
    });
    test('Failed = wrong element, no recipe', () {
      expect(evaluateInteraction(_member('Water', 'Horn'), req),
          InteractionQuality.failed);
    });
    test('Weak = recipe available when wrong element', () {
      const recipeReq = DungeonInteractionRequirement(
        element: 'Lightning',
        preferred: DungeonAbility.heavyForce,
        allowRecipe: true,
      );
      expect(
        evaluateInteraction(_member('Water', 'Pip'), recipeReq,
            recipeAvailable: true),
        InteractionQuality.weak,
      );
    });
    test('no preferred → any family of the element is Perfect', () {
      const anyFam = DungeonInteractionRequirement(element: 'Air');
      expect(evaluateInteraction(_member('Air', 'Pip'), anyFam),
          InteractionQuality.perfect);
    });

    test('meetsStats is an orthogonal gate (stats range 1..5)', () {
      const needsSpeed = DungeonInteractionRequirement(
        element: 'Air',
        preferred: DungeonAbility.aerialTraversal,
        minSpeed: 4,
      );
      final fast = CosmicPartyMember(
        instanceId: 'i', baseId: 'b', displayName: 'd',
        element: 'Air', family: 'Wing', level: 5,
        statSpeed: 5, statIntelligence: 3, statStrength: 3, statBeauty: 3,
        slotIndex: 0, staminaBars: 5, staminaMax: 5,
      );
      final slow = _member('Air', 'Wing'); // statSpeed 3
      // Both are Perfect on element+family; only fast clears the speed gate.
      expect(evaluateInteraction(fast, needsSpeed), InteractionQuality.perfect);
      expect(evaluateInteraction(slow, needsSpeed), InteractionQuality.perfect);
      expect(needsSpeed.meetsStats(fast), isTrue);
      expect(needsSpeed.meetsStats(slow), isFalse);
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
