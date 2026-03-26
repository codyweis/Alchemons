import 'dart:convert';
import 'dart:math';

import 'package:alchemons/helpers/genetics_loader.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/breeding_config.dart';
import 'package:alchemons/services/breeding_engine.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/likelihood_analyzer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CreatureCatalog repository;
  late ElementRecipeConfig elementRecipes;
  late FamilyRecipeConfig familyRecipes;
  late Creature waterlet;

  setUpAll(() async {
    await loadNatures();
    await GeneticsCatalog.load();

    final creaturesRaw = await rootBundle.loadString(
      'assets/data/alchemons_creatures.json',
    );
    final creaturesJson = jsonDecode(creaturesRaw) as Map<String, dynamic>;
    repository = CreatureCatalog.fromList(
      (creaturesJson['creatures'] as List<dynamic>)
          .map((json) => Creature.fromJson(json as Map<String, dynamic>))
          .toList(growable: false),
    );

    final elementRaw = await rootBundle.loadString(
      'assets/data/alchemons_element_recipes.json',
    );
    final elementJson = jsonDecode(elementRaw) as Map<String, dynamic>;
    final elementSrc = elementJson['recipes'] as Map<String, dynamic>;
    final elementOut = <String, Map<String, int>>{};
    for (final entry in elementSrc.entries) {
      final rawKey = entry.key.trim();
      final rawVal = entry.value as Map<String, dynamic>;
      final inner = <String, int>{};
      for (final recipeEntry in rawVal.entries) {
        inner[ElementRecipeConfig.norm(recipeEntry.key)] =
            (recipeEntry.value as num).toInt();
      }
      if (rawKey.contains('+')) {
        final parts = rawKey.split('+').map((s) => s.trim()).toList();
        elementOut[ElementRecipeConfig.keyOf(parts[0], parts[1])] = inner;
      } else {
        elementOut[ElementRecipeConfig.norm(rawKey)] = inner;
      }
    }
    elementRecipes = ElementRecipeConfig(recipes: elementOut);

    final familyRaw = await rootBundle.loadString(
      'assets/data/alchemons_family_recipes.json',
    );
    final familyJson = jsonDecode(familyRaw) as Map<String, dynamic>;
    final familySrc = familyJson['recipes'] as Map<String, dynamic>;
    familyRecipes = FamilyRecipeConfig.fromRaw(
      familySrc.map(
        (key, value) => MapEntry(
          key,
          (value as Map<String, dynamic>).map(
            (family, weight) => MapEntry(
              FamilyRecipeConfig.norm(family),
              (weight as num).toInt(),
            ),
          ),
        ),
      ),
    );

    waterlet = repository.getCreatureById('LET02')!;
  });

  group('Breeding engine', () {
    test('same-species lets follow the normal recipe path', () {
      final outcomes = <String>{};

      for (var seed = 0; seed < 200; seed++) {
        final engine = BreedingEngine(
          repository,
          elementRecipes: elementRecipes,
          familyRecipes: familyRecipes,
          tuning: const BreedingTuning(globalMutationChance: 0),
          random: Random(seed),
        );

        final result = engine.breed('LET02', 'LET02');
        expect(result.success, isTrue);
        outcomes.add(result.creature!.id);
      }

      expect(outcomes.contains('LET02'), isTrue);
      expect(outcomes.any((id) => id == 'MAN02' || id == 'PIP02'), isTrue);
    });

    test(
      'same-species let analyzer uses recipe odds instead of clone odds',
      () {
        final engine = BreedingEngine(
          repository,
          elementRecipes: elementRecipes,
          familyRecipes: familyRecipes,
          tuning: const BreedingTuning(globalMutationChance: 0),
          random: Random(0),
        );
        final analyzer = BreedingLikelihoodAnalyzer(
          repository: repository,
          elementRecipes: elementRecipes,
          familyRecipes: familyRecipes,
          engine: engine,
          tuning: const BreedingTuning(globalMutationChance: 0),
        );

        final watermane = repository.getCreatureById('MAN02')!;
        final report = analyzer.analyzeBreedingResult(
          waterlet,
          waterlet,
          watermane,
        );

        final familyMechanic = report.inheritanceMechanics.firstWhere(
          (m) => m.category == 'Family Lineage',
        );
        final speciesMechanic = report.inheritanceMechanics.firstWhere(
          (m) => m.category == 'Species',
        );

        expect(report.breedingType, BreedingType.sameSpecies);
        expect(familyMechanic.result, 'Mane');
        expect(familyMechanic.percentage, greaterThan(0));
        expect(speciesMechanic.percentage, lessThan(100));
      },
    );
  });
}
