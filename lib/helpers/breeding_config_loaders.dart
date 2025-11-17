import 'dart:convert';
import 'package:alchemons/services/breeding_config.dart';
import 'package:flutter/services.dart' show rootBundle;

Future<ElementRecipeConfig> loadElementRecipes() async {
  final raw = await rootBundle.loadString(
    'assets/data/alchemons_element_recipes.json',
  );
  final map = json.decode(raw) as Map<String, dynamic>;

  final src = map['recipes'] as Map<String, dynamic>;
  final out = <String, Map<String, int>>{};

  for (final e in src.entries) {
    final rawKey = (e.key).trim();
    final rawVal = e.value as Map<String, dynamic>;

    // normalize inner map
    final inner = <String, int>{};
    for (final e2 in rawVal.entries) {
      inner[(e2.key).trim()] = (e2.value as num).toInt();
    }

    // canonicalize pair keys
    if (rawKey.contains('+')) {
      final parts = rawKey.split('+').map((s) => s.trim()).toList();
      final k = ElementRecipeConfig.keyOf(parts[0], parts[1]);
      out[k] = inner;
    } else {
      out[rawKey] = inner; // single-element dominance like "Fire": {"Fire":100}
    }
  }

  // quick sanity logs (remove in prod)
  print('[Recipes] has Fire? ${out.containsKey("Fire")}');
  print('[Recipes] has Fire+Water? ${out.containsKey("Fire+Water")}');

  return ElementRecipeConfig(recipes: out);
}

// family_recipes_loader.dart

Future<FamilyRecipeConfig> loadFamilyRecipes() async {
  final raw = await rootBundle.loadString(
    'assets/data/alchemons_family_recipes.json',
  );
  final map = json.decode(raw) as Map<String, dynamic>;
  final recipesRaw = (map['recipes'] as Map<String, dynamic>).map(
    (k, v) => MapEntry(
      k,
      (v as Map<String, dynamic>).map(
        (kk, vv) => MapEntry(kk, (vv as num).toInt()),
      ),
    ),
  );

  // normalize + build backlinks automatically
  return FamilyRecipeConfig.fromRaw(recipesRaw);
}
