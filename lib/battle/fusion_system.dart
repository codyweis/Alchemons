// lib/battle/fusion_system.dart
// Handles ally bubble collisions and fusion logic

import 'dart:math' as math;
import 'dart:ui';
import 'package:alchemons/battle/battle_game_core.dart';
import 'package:alchemons/battle/battle_stats.dart';

/// Represents a fusion recipe from the chart
class FusionRecipe {
  final String elementA;
  final String elementB;
  final String result;

  const FusionRecipe(this.elementA, this.elementB, this.result);

  /// Check if these two elements can fuse
  bool matches(String elem1, String elem2) {
    return (elem1 == elementA && elem2 == elementB) ||
        (elem1 == elementB && elem2 == elementA);
  }
}

class FusionSystem {
  static final math.Random _rng = math.Random();

  // Fusion recipe chart (from your CSV)
  static const List<FusionRecipe> recipes = [
    FusionRecipe('Air', 'Earth', 'Dust'),
    FusionRecipe('Air', 'Fire', 'Lightning'),
    FusionRecipe('Air', 'Poison', 'Spirit'),
    FusionRecipe('Air', 'Spirit', 'Lightning'),
    FusionRecipe('Air', 'Water', 'Ice'),
    FusionRecipe('Crystal', 'Spirit', 'Light'),
    FusionRecipe('Dark', 'Light', 'Dark / Light'),
    FusionRecipe('Dark', 'Plant', 'Poison'),
    FusionRecipe('Earth', 'Fire', 'Lava'),
    FusionRecipe('Earth', 'Lightning', 'Crystal'),
    FusionRecipe('Earth', 'Spirit', 'Crystal'),
    FusionRecipe('Earth', 'Water', 'Mud'),
    FusionRecipe('Fire', 'Ice', 'Water'),
    FusionRecipe('Fire', 'Spirit', 'Steam'),
    FusionRecipe('Fire', 'Water', 'Steam'),
    FusionRecipe('Lava', 'Water', 'Poison'),
    FusionRecipe('Poison', 'Spirit', 'Dark'),
    FusionRecipe('Spirit', 'Water', 'Ice'),
  ];

  /// Find fusion result for two elements
  static String? getFusionResult(String element1, String element2) {
    for (final recipe in recipes) {
      if (recipe.matches(element1, element2)) {
        return recipe.result;
      }
    }
    return null;
  }

  /// Check if fusion is possible between two creatures
  /// Returns the fusion result element if possible, null otherwise
  static String? canFuse(
    BattleCreature parent1,
    BattleCreature parent2,
    BattleState state,
  ) {
    // 1. Must be same team
    if (parent1.team != parent2.team) return null;

    // 2. Check if elements can fuse
    final fusionResult = getFusionResult(parent1.element, parent2.element);
    if (fusionResult == null) return null;

    // 3. Check if we have unused fusion result in bench
    final bench = parent1.team == 0 ? state.playerBench : state.aiBench;
    final hasUnused = bench.any(
      (c) => c.element == fusionResult && c.summonable && !c.onField,
    );

    if (!hasUnused) {
      print(
        '   ⚠️ Fusion possible ($fusionResult) but not in bench or already used',
      );
      return null;
    }

    return fusionResult;
  }

  /// Attempt to fuse two creatures
  /// Returns the summoned fusion creature if successful, null if failed
  static BattleCreature? attemptFusion(
    BattleCreature parent1,
    BattleCreature parent2,
    BattleState state, {
    required Offset spawnPosition,
  }) {
    print('⚗️ Attempting fusion: ${parent1.element} + ${parent2.element}');

    // Check if fusion is possible
    final fusionResult = canFuse(parent1, parent2, state);
    if (fusionResult == null) {
      print('   ❌ Fusion not possible or result not available');
      return null;
    }

    // Roll for success based on Intelligence
    final success = BattleStats.rollFusion(parent1, parent2, _rng);
    final chance = BattleStats.fusionSuccessChance(parent1, parent2);

    print('   🎲 Fusion chance: ${(chance * 100).toStringAsFixed(1)}%');

    if (!success) {
      print('   ❌ Fusion failed!');
      return null;
    }

    print('   ✅ Fusion succeeded! Creating $fusionResult');

    // Find the fusion creature in bench
    final bench = parent1.team == 0 ? state.playerBench : state.aiBench;
    final fusionCreature = bench.firstWhere(
      (c) => c.element == fusionResult && c.summonable && !c.onField,
    );

    // Mark as summoned (can't summon again this battle)
    fusionCreature.summonable = false;
    fusionCreature.onField = true;

    // The actual bubble spawning will be handled by CombatResolver
    return fusionCreature;
  }

  /// Get all possible fusions for a given roster
  /// Useful for UI to show what fusions are available
  static List<String> getPossibleFusions(List<BattleCreature> roster) {
    final Set<String> possibleResults = {};

    for (int i = 0; i < roster.length; i++) {
      for (int j = i + 1; j < roster.length; j++) {
        final result = getFusionResult(roster[i].element, roster[j].element);
        if (result != null) {
          possibleResults.add(result);
        }
      }
    }

    return possibleResults.toList()..sort();
  }

  /// Check if a roster is "fusion-viable" (has fusion targets)
  static bool hasFusionPotential(List<BattleCreature> roster) {
    // Check if roster has any fusion results that can be created
    final elementsPresent = roster.map((c) => c.element).toSet();

    for (final recipe in recipes) {
      if (elementsPresent.contains(recipe.elementA) &&
          elementsPresent.contains(recipe.elementB) &&
          elementsPresent.contains(recipe.result)) {
        return true; // Can fuse A+B and result is in roster
      }
    }

    return false;
  }

  /// Validate a roster for fusion synergy
  /// Returns suggestions for improving fusion potential
  static List<String> analyzeFusionSynergy(List<BattleCreature> roster) {
    final suggestions = <String>[];
    final elementsPresent = roster.map((c) => c.element).toSet();

    // Find "missing links" - where you have A+B but not the result
    for (final recipe in recipes) {
      if (elementsPresent.contains(recipe.elementA) &&
          elementsPresent.contains(recipe.elementB) &&
          !elementsPresent.contains(recipe.result)) {
        suggestions.add(
          'Add ${recipe.result} to enable ${recipe.elementA}+${recipe.elementB} fusion',
        );
      }
    }

    // Find "dead ends" - fusion results with no parents
    for (final creature in roster) {
      final isResult = recipes.any((r) => r.result == creature.element);
      if (isResult) {
        final hasParents = recipes.any(
          (r) =>
              r.result == creature.element &&
              elementsPresent.contains(r.elementA) &&
              elementsPresent.contains(r.elementB),
        );

        if (!hasParents) {
          suggestions.add(
            '${creature.element} has no fusion parents in roster',
          );
        }
      }
    }

    return suggestions;
  }
}
