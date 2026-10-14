import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/breeding_config.dart';
import 'package:alchemons/services/breeding_engine.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Creature of(String id, String type, String family, String rarity) => Creature(
    id: id,
    name: id,
    types: [type],
    rarity: rarity,
    description: '',
    image: '',
    mutationFamily: family,
  );
  final waterlet = of('LET02', 'Water', 'Let', 'Common');
  final poisonkin = of('KIN13', 'Poison', 'Kin', 'Legendary');
  final poisonlet = of('LET13', 'Poison', 'Let', 'Uncommon');
  final engine = BreedingEngine(
    CreatureCatalog.fromList([waterlet, poisonkin, poisonlet]),
    elementRecipes: ElementRecipeConfig(recipes: const {}),
    familyRecipes: const FamilyRecipeConfig(recipes: {}),
  );

  double poisonToWater(Creature a, Creature b, String? family) {
    final w = engine
        .getBiasedElementDistribution(a, b, childFamily: family)
        .weights;
    return w['Poison']! / w['Water']!;
  }

  test('a child leans to the element of the parent whose family it took', () {
    final neither = poisonToWater(waterlet, poisonkin, null);
    expect(
      poisonToWater(waterlet, poisonkin, 'Kin'),
      closeTo(neither * kFamilyParentElementWeight, 1e-9),
    );
    expect(
      poisonToWater(waterlet, poisonkin, 'Let'),
      closeTo(neither / kFamilyParentElementWeight, 1e-9),
    );
    // Either order of parents.
    expect(
      poisonToWater(poisonkin, waterlet, 'Kin'),
      closeTo(neither * kFamilyParentElementWeight, 1e-9),
    );
  });

  test('a same-family pair has no one parent to take after', () {
    expect(
      poisonToWater(waterlet, poisonlet, 'Let'),
      closeTo(poisonToWater(waterlet, poisonlet, null), 1e-9),
    );
  });
}
