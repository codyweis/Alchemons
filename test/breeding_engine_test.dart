import 'dart:convert';
import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart' as db;
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

  group('Potential inheritance through the engine', () {
    db.CreatureInstance instance(String id, String baseId, double potential) =>
        db.CreatureInstance(
          instanceId: id,
          baseId: baseId,
          level: 1,
          xp: 0,
          locked: false,
          isPrismaticSkin: false,
          source: 'test',
          staminaMax: 3,
          staminaBars: 3,
          staminaLastUtcMs: 0,
          createdAtUtcMs: 0,
          statSpeed: 3,
          statIntelligence: 3,
          statStrength: 3,
          statBeauty: 3,
          statSpeedPotential: potential,
          statIntelligencePotential: potential,
          statStrengthPotential: potential,
          statBeautyPotential: potential,
          statSpeedEnhancement: 0,
          statIntelligenceEnhancement: 0,
          statStrengthEnhancement: 0,
          statBeautyEnhancement: 0,
          generationDepth: 0,
          isPure: true,
          isFavorite: false,
        );

    test('a miss cannot exceed the parents, a recipe hit can', () {
      const parentPotential = 40.0;
      final a = instance('a', 'LET02', parentPotential);
      final b = instance('b', 'LET02', parentPotential);

      var missBest = 0.0;
      var hitExceeded = false;
      var misses = 0;
      var hits = 0;

      for (var seed = 0; seed < 600; seed++) {
        final engine = BreedingEngine(
          repository,
          elementRecipes: elementRecipes,
          familyRecipes: familyRecipes,
          tuning: const BreedingTuning(globalMutationChance: 0),
          random: Random(seed),
        );
        final result = engine.breedInstances(a, b);
        if (!result.success) continue;
        final child = result.creature!;
        final stats = child.stats;
        if (stats == null) continue;

        final best = [
          stats.speedPotential,
          stats.intelligencePotential,
          stats.strengthPotential,
          stats.beautyPotential,
        ].reduce((x, y) => x > y ? x : y);

        // Both parents are Lets. A child that stayed a Let is a miss; one that
        // came out Mane or Pip took the recipe, and pays out.
        final childFamily = child.mutationFamily;
        if (childFamily == 'Let') {
          misses++;
          if (best > missBest) missBest = best;
        } else {
          hits++;
          if (best > parentPotential) hitExceeded = true;
        }
      }

      expect(misses, greaterThan(0), reason: 'let+let should stay Let often');
      expect(hits, greaterThan(0), reason: 'let+let should also pop family');
      expect(
        missBest,
        lessThanOrEqualTo(parentPotential),
        reason: 'a miss must never hand back more than the better parent',
      );
      expect(
        hitExceeded,
        isTrue,
        reason: 'a recipe hit is the only way a line climbs',
      );
    });

    test('every bred child carries exactly two Dominants', () {
      final a = instance('a', 'LET02', 60);
      final b = instance('b', 'LET02', 60);

      for (var seed = 0; seed < 100; seed++) {
        final engine = BreedingEngine(
          repository,
          elementRecipes: elementRecipes,
          familyRecipes: familyRecipes,
          tuning: const BreedingTuning(globalMutationChance: 0),
          random: Random(seed),
        );
        final result = engine.breedInstances(a, b);
        if (!result.success) continue;
        final dominants = result.creature!.stats?.dominants;
        expect(dominants, isNotNull);
        expect(dominants!.first, isNot(dominants.second));
      }
    });
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

    test('Hereditary parents guarantee both protected second Natures', () {
      final hereditary = NatureCatalog.byId('Hereditary')!;
      final titanic = NatureCatalog.byId('Titanic')!;
      final noetic = NatureCatalog.byId('Noetic')!;
      final parentA = repository
          .getCreatureById('LET02')!
          .copyWith(nature: hereditary, nature2: titanic);
      final parentB = repository
          .getCreatureById('PIP02')!
          .copyWith(nature: hereditary, nature2: noetic);
      final hereditaryRepository = CreatureCatalog.fromList([
        for (final creature in repository.creatures)
          if (creature.id == parentA.id)
            parentA
          else if (creature.id == parentB.id)
            parentB
          else
            creature,
      ]);

      for (var seed = 0; seed < 100; seed++) {
        final engine = BreedingEngine(
          hereditaryRepository,
          elementRecipes: elementRecipes,
          familyRecipes: familyRecipes,
          tuning: const BreedingTuning(globalMutationChance: 0),
          random: Random(seed),
        );
        final child = engine.breed(parentA.id, parentB.id).creature!;
        expect({
          child.nature?.id,
          child.nature2?.id,
        }, containsAll(<String>{'Titanic', 'Noetic'}));
        expect(
          engine.natureAppearanceChancePct(parentA, parentB, 'Titanic'),
          100,
        );
        expect(
          engine.natureAppearanceChancePct(parentA, parentB, 'Noetic'),
          100,
        );
      }
    });
  });
}
