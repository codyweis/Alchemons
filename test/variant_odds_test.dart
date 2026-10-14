import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/offspring_lineage.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/breeding_config.dart';
import 'package:alchemons/services/breeding_engine.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Creature species(String id, String type, String family) => Creature(
    id: id,
    name: id,
    types: [type],
    rarity: 'Common',
    description: '',
    image: '',
    mutationFamily: family,
  );
  final fire = species('LET01', 'Fire', 'Let');
  final water = species('LET02', 'Water', 'Let');

  test('a wild parent brings its faction, not its family, to the line', () {
    final wild = ParentSnapshot.fromCreature(fire);
    expect(wild.nativeFaction, 'Volcanic');
    expect(wild.factionLineage, {'Volcanic': 1});
    expect(wild.familyLineage, {'Let': 1});
    final withStats = ParentSnapshot.fromCreatureWithStats(water, null);
    expect(withStats.nativeFaction, 'Oceanic');
    expect(withStats.factionLineage, {'Oceanic': 1});
  });

  test('none until ten points of the faction, then 1% a point, to 15%', () {
    final engine = BreedingEngine(
      CreatureCatalog.fromList([fire, water]),
      elementRecipes: ElementRecipeConfig(recipes: const {}),
      familyRecipes: const FamilyRecipeConfig(recipes: {}),
    );
    // An Oceanic child, a Volcanic and an Oceanic parent: only the Volcanic
    // roll can land, at its points of Volcanic heritage.
    double? chanceAt(int points) => engine
        .computeVariantFactionOdds(
          child: water.copyWith(
            lineageData: OffspringLineageData(
              generationDepth: points,
              factionLineage: {'Volcanic': points, 'Oceanic': points},
              variantFaction: 'Volcanic',
              nativeFaction: 'Oceanic',
            ),
            parentage: Parentage(
              parentA: ParentSnapshot.fromCreature(fire),
              parentB: ParentSnapshot.fromCreature(water),
              bredAt: DateTime(2026),
            ),
          ),
        )
        ?.pickedFactionPct;

    expect(chanceAt(9), isNull);
    expect(chanceAt(10), closeTo(1, 1e-9));
    expect(chanceAt(11), closeTo(2, 1e-9));
    expect(chanceAt(24), closeTo(15, 1e-9));
    expect(chanceAt(40), closeTo(15, 1e-9));
  });
}
