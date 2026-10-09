import 'dart:convert';
import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/nature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/breeding_config.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:flutter/services.dart' show rootBundle;

enum EncyclopediaRecipeKind { family, element }

class EncyclopediaOutcomeEntry {
  final String result;
  final int weight;

  const EncyclopediaOutcomeEntry({required this.result, required this.weight});
}

class EncyclopediaRecipeEntry {
  final EncyclopediaRecipeKind kind;
  final String pairKey;
  final String parentA;
  final String parentB;
  final List<EncyclopediaOutcomeEntry> outcomes;

  const EncyclopediaRecipeEntry({
    required this.kind,
    required this.pairKey,
    required this.parentA,
    required this.parentB,
    required this.outcomes,
  });

  String get result => outcomes.first.result;

  int get topWeight => outcomes.first.weight;

  String outcomePathKey(String result) => '$pairKey::$result';

  bool definesOutcome(String value) {
    final normalized = value.trim().toLowerCase();
    return outcomes.any(
      (entry) => entry.result.trim().toLowerCase() == normalized,
    );
  }
}

class EncyclopediaNatureEntry {
  final NatureDef nature;
  final int observedCount;
  final bool discovered;

  const EncyclopediaNatureEntry({
    required this.nature,
    required this.observedCount,
    required this.discovered,
  });
}

class AlchemicalEncyclopediaSnapshot {
  final List<EncyclopediaRecipeEntry> familyRecipes;
  final List<EncyclopediaRecipeEntry> elementRecipes;
  final List<EncyclopediaNatureEntry> natureEntries;
  final Set<String> discoveredFamilyKeys;
  final Set<String> discoveredElementKeys;
  final Set<String> discoveredFamilyOutcomeKeys;
  final Set<String> discoveredElementOutcomeKeys;

  /// Elements the player has come across ('Fire'…): in a species they have
  /// found or a specimen they keep, or in a formula they have made — its
  /// makers as well as what it made.
  final Set<String> knownElements;

  /// Species families the same way ('Let'…).
  final Set<String> knownFamilies;

  /// A creature to show each family by: the first the player has found, or
  /// the first in the catalog for a family not yet known.
  final Map<String, Creature> familyFaces;

  const AlchemicalEncyclopediaSnapshot({
    required this.familyRecipes,
    required this.elementRecipes,
    required this.natureEntries,
    required this.discoveredFamilyKeys,
    required this.discoveredElementKeys,
    required this.discoveredFamilyOutcomeKeys,
    required this.discoveredElementOutcomeKeys,
    this.knownElements = const {},
    this.knownFamilies = const {},
    this.familyFaces = const {},
  });

  /// The element formulas that make [element], and those it is a maker in.
  List<EncyclopediaRecipeEntry> elementMadeFrom(String element) =>
      _madeFrom(elementRecipes, element);
  List<EncyclopediaRecipeEntry> elementFusesInto(String element) =>
      _fusesInto(elementRecipes, element);

  /// The same for a species family.
  List<EncyclopediaRecipeEntry> familyMadeFrom(String family) =>
      _madeFrom(familyRecipes, family);
  List<EncyclopediaRecipeEntry> familyFusesInto(String family) =>
      _fusesInto(familyRecipes, family);

  static List<EncyclopediaRecipeEntry> _madeFrom(
    List<EncyclopediaRecipeEntry> recipes,
    String name,
  ) => [
    for (final r in recipes)
      if (r.definesOutcome(name)) r,
  ];

  static List<EncyclopediaRecipeEntry> _fusesInto(
    List<EncyclopediaRecipeEntry> recipes,
    String name,
  ) => [
    for (final r in recipes)
      if (r.parentA == name || r.parentB == name) r,
  ];

  /// Whether the outcome [result] of [recipe] has been made.
  bool outcomeFound(EncyclopediaRecipeEntry recipe, String result) =>
      switch (recipe.kind) {
        EncyclopediaRecipeKind.family => discoveredFamilyOutcomeKeys,
        EncyclopediaRecipeKind.element => discoveredElementOutcomeKeys,
      }.contains(recipe.outcomePathKey(result));

  bool isDiscovered(EncyclopediaRecipeEntry entry) {
    return switch (entry.kind) {
      EncyclopediaRecipeKind.family => discoveredFamilyKeys.contains(
        entry.pairKey,
      ),
      EncyclopediaRecipeKind.element => discoveredElementKeys.contains(
        entry.pairKey,
      ),
    };
  }
}

class EncyclopediaDiscoveryResult {
  final List<EncyclopediaRecipeEntry> unlocked;

  const EncyclopediaDiscoveryResult({this.unlocked = const []});

  static const none = EncyclopediaDiscoveryResult();

  bool get hasAny => unlocked.isNotEmpty;

  bool get familyUnlocked =>
      unlocked.any((e) => e.kind == EncyclopediaRecipeKind.family);

  bool get elementUnlocked =>
      unlocked.any((e) => e.kind == EncyclopediaRecipeKind.element);
}

class AlchemicalEncyclopediaService {
  static const String _legacyFamilyDiscoveredKey = 'enc.family.discovered.v1';
  static const String _legacyElementDiscoveredKey = 'enc.element.discovered.v1';
  static const String _familyDiscoveredKey = 'enc.family.outcomes.v2';
  static const String _elementDiscoveredKey = 'enc.element.outcomes.v2';
  static const String _natureDiscoveredKey = 'enc.nature.discovered.v1';

  // The recipe books, once read. Kept as the value, not the future: a
  // future completed in one zone hands its result back through that zone,
  // which a test's fake clock may have stopped running.
  static _RecipeCatalog? _catalog;

  /// Everything the Codex shows. Without a [catalog] only formulas make an
  /// element or family known, and families have no faces.
  static Future<AlchemicalEncyclopediaSnapshot> loadSnapshot({
    required AlchemonsDatabase db,
    CreatureCatalog? catalog,
  }) async {
    final recipes = await _loadCatalog();
    final discoveredFamilyOutcomeKeys = await _readDiscoveredOutcomeSet(
      db,
      currentKey: _familyDiscoveredKey,
      legacyPairKey: _legacyFamilyDiscoveredKey,
      recipesByPair: recipes.familyByPair,
    );
    final discoveredElementOutcomeKeys = await _readDiscoveredOutcomeSet(
      db,
      currentKey: _elementDiscoveredKey,
      legacyPairKey: _legacyElementDiscoveredKey,
      recipesByPair: recipes.elementByPair,
    );
    final discoveredFamily = _pairKeysFromOutcomeKeys(
      recipes.familyRecipes,
      discoveredFamilyOutcomeKeys,
    );
    final discoveredElement = _pairKeysFromOutcomeKeys(
      recipes.elementRecipes,
      discoveredElementOutcomeKeys,
    );
    final instances = await db.creatureDao.listAllInstances();
    final natureEntries = await _loadNatureEntries(db, instances);

    // What the player has come across.
    final knownElements = <String>{};
    final knownFamilies = <String>{};
    final familyFaces = <String, Creature>{};
    if (catalog != null && catalog.isLoaded) {
      final found = {
        for (final p in await db.creatureDao.getAllCreatures())
          if (p.discovered) p.id,
      };
      for (final inst in instances) {
        final c = catalog.getCreatureById(inst.baseId);
        if (c != null) found.add(c.id);
      }
      for (final c in catalog.creatures) {
        final fam = _familyFromCreature(c);
        final isFound = found.contains(c.id);
        if (isFound) {
          final el = _primaryElement(c.types);
          if (el != null) knownElements.add(el);
          if (fam != null) knownFamilies.add(fam);
        }
        if (fam != null &&
            (!familyFaces.containsKey(fam) ||
                (isFound && !found.contains(familyFaces[fam]!.id)))) {
          familyFaces[fam] = c;
        }
      }
    }
    void fromFormulas(
      List<EncyclopediaRecipeEntry> list,
      Set<String> outcomeKeys,
      Set<String> into,
    ) {
      for (final r in list) {
        for (final o in r.outcomes) {
          if (!outcomeKeys.contains(r.outcomePathKey(o.result))) continue;
          into
            ..add(r.parentA)
            ..add(r.parentB)
            ..add(o.result);
        }
      }
    }

    fromFormulas(
      recipes.elementRecipes,
      discoveredElementOutcomeKeys,
      knownElements,
    );
    fromFormulas(
      recipes.familyRecipes,
      discoveredFamilyOutcomeKeys,
      knownFamilies,
    );

    return AlchemicalEncyclopediaSnapshot(
      familyRecipes: recipes.familyRecipes,
      elementRecipes: recipes.elementRecipes,
      natureEntries: natureEntries,
      discoveredFamilyKeys: discoveredFamily,
      discoveredElementKeys: discoveredElement,
      discoveredFamilyOutcomeKeys: discoveredFamilyOutcomeKeys,
      discoveredElementOutcomeKeys: discoveredElementOutcomeKeys,
      knownElements: knownElements,
      knownFamilies: knownFamilies,
      familyFaces: familyFaces,
    );
  }

  static Future<EncyclopediaDiscoveryResult> registerBreedingDiscovery({
    required AlchemonsDatabase db,
    required CreatureCatalog repo,
    required Creature offspring,
    required String? parentageJson,
  }) async {
    if (parentageJson == null || parentageJson.isEmpty) {
      return EncyclopediaDiscoveryResult.none;
    }

    Parentage parentage;
    try {
      final decoded = jsonDecode(parentageJson) as Map<String, dynamic>;
      parentage = Parentage.fromJson(decoded);
    } catch (_) {
      return EncyclopediaDiscoveryResult.none;
    }

    final parentAElement = _primaryElement(parentage.parentA.types);
    final parentBElement = _primaryElement(parentage.parentB.types);
    final childElement = _primaryElement(offspring.types);

    final parentAFamily = _familyFromParent(parentage.parentA, repo);
    final parentBFamily = _familyFromParent(parentage.parentB, repo);
    final childFamily = _familyFromCreature(offspring);

    final catalog = await _loadCatalog();
    final discoveredFamily = await _readDiscoveredOutcomeSet(
      db,
      currentKey: _familyDiscoveredKey,
      legacyPairKey: _legacyFamilyDiscoveredKey,
      recipesByPair: catalog.familyByPair,
    );
    final discoveredElement = await _readDiscoveredOutcomeSet(
      db,
      currentKey: _elementDiscoveredKey,
      legacyPairKey: _legacyElementDiscoveredKey,
      recipesByPair: catalog.elementByPair,
    );

    final unlocked = <EncyclopediaRecipeEntry>[];
    var familyChanged = false;
    var elementChanged = false;

    if (parentAElement != null &&
        parentBElement != null &&
        childElement != null) {
      final pairKey = ElementRecipeConfig.keyOf(parentAElement, parentBElement);
      final candidate = catalog.elementByPair[pairKey];
      final outcomeKey = candidate?.outcomePathKey(childElement);
      if (candidate != null &&
          candidate.definesOutcome(childElement) &&
          outcomeKey != null &&
          !discoveredElement.contains(outcomeKey)) {
        discoveredElement.add(outcomeKey);
        unlocked.add(candidate);
        elementChanged = true;
      }
    }

    if (parentAFamily != null && parentBFamily != null && childFamily != null) {
      final pairKey = FamilyRecipeConfig.keyOf(parentAFamily, parentBFamily);
      final candidate = catalog.familyByPair[pairKey];
      final outcomeKey = candidate?.outcomePathKey(childFamily);
      if (candidate != null &&
          candidate.definesOutcome(childFamily) &&
          outcomeKey != null &&
          !discoveredFamily.contains(outcomeKey)) {
        discoveredFamily.add(outcomeKey);
        unlocked.add(candidate);
        familyChanged = true;
      }
    }

    if (familyChanged) {
      await _writeDiscoveredSet(db, _familyDiscoveredKey, discoveredFamily);
    }
    if (elementChanged) {
      await _writeDiscoveredSet(db, _elementDiscoveredKey, discoveredElement);
    }

    return unlocked.isEmpty
        ? EncyclopediaDiscoveryResult.none
        : EncyclopediaDiscoveryResult(unlocked: unlocked);
  }

  /// How many formulas are found, elements and families together, of all
  /// there are: the count ALCHEMY opens on (AlchemyUnlock), without the
  /// specimen scan [loadSnapshot] makes for the Codex.
  static Future<({int found, int total})> formulaCount(
    AlchemonsDatabase db,
  ) async {
    final recipes = await _loadCatalog();
    final family = _pairKeysFromOutcomeKeys(
      recipes.familyRecipes,
      await _readDiscoveredOutcomeSet(
        db,
        currentKey: _familyDiscoveredKey,
        legacyPairKey: _legacyFamilyDiscoveredKey,
        recipesByPair: recipes.familyByPair,
      ),
    );
    final element = _pairKeysFromOutcomeKeys(
      recipes.elementRecipes,
      await _readDiscoveredOutcomeSet(
        db,
        currentKey: _elementDiscoveredKey,
        legacyPairKey: _legacyElementDiscoveredKey,
        recipesByPair: recipes.elementByPair,
      ),
    );
    return (
      found: family.length + element.length,
      total: recipes.familyRecipes.length + recipes.elementRecipes.length,
    );
  }

  static Future<_RecipeCatalog> _loadCatalog() async =>
      _catalog ??= await _buildCatalog();

  static Future<_RecipeCatalog> _buildCatalog() async {
    final elementRaw = await rootBundle.loadString(
      'assets/data/alchemons_element_recipes.json',
    );
    final familyRaw = await rootBundle.loadString(
      'assets/data/alchemons_family_recipes.json',
    );

    final elementJson = jsonDecode(elementRaw) as Map<String, dynamic>;
    final familyJson = jsonDecode(familyRaw) as Map<String, dynamic>;

    final elementRecipes = _parseRecipes(
      kind: EncyclopediaRecipeKind.element,
      rawRecipes: (elementJson['recipes'] as Map<String, dynamic>),
      norm: ElementRecipeConfig.norm,
      keyOf: ElementRecipeConfig.keyOf,
    );
    final familyRecipes = _parseRecipes(
      kind: EncyclopediaRecipeKind.family,
      rawRecipes: (familyJson['recipes'] as Map<String, dynamic>),
      norm: FamilyRecipeConfig.norm,
      keyOf: FamilyRecipeConfig.keyOf,
    );

    final elementByPair = {
      for (final entry in elementRecipes) entry.pairKey: entry,
    };
    final familyByPair = {
      for (final entry in familyRecipes) entry.pairKey: entry,
    };

    return _RecipeCatalog(
      familyRecipes: familyRecipes,
      elementRecipes: elementRecipes,
      familyByPair: familyByPair,
      elementByPair: elementByPair,
    );
  }

  static List<EncyclopediaRecipeEntry> _parseRecipes({
    required EncyclopediaRecipeKind kind,
    required Map<String, dynamic> rawRecipes,
    required String Function(String) norm,
    required String Function(String, String) keyOf,
  }) {
    final byPair = <String, EncyclopediaRecipeEntry>{};

    for (final recipe in rawRecipes.entries) {
      final rawKey = recipe.key.trim();
      if (!rawKey.contains('+')) continue;

      final parts = rawKey.split('+').map((s) => s.trim()).toList();
      if (parts.length != 2) continue;

      final parentA = norm(parts[0]);
      final parentB = norm(parts[1]);
      final dist = recipe.value;
      if (dist is! Map<String, dynamic>) continue;

      final outcomes = _definedOutcomes(
        dist,
        norm: norm,
        excludedResults:
            kind == EncyclopediaRecipeKind.family ||
                kind == EncyclopediaRecipeKind.element
            ? {parentA, parentB}
            : const <String>{},
      );
      if (outcomes.isEmpty) continue;

      final pairKey = keyOf(parentA, parentB);
      final pairParts = pairKey.split('+');
      byPair[pairKey] = EncyclopediaRecipeEntry(
        kind: kind,
        pairKey: pairKey,
        parentA: pairParts[0],
        parentB: pairParts[1],
        outcomes: outcomes,
      );
    }

    final out = byPair.values.toList(growable: false);
    out.sort((a, b) {
      final p = a.parentA.compareTo(b.parentA);
      if (p != 0) return p;
      final s = a.parentB.compareTo(b.parentB);
      if (s != 0) return s;
      return a.result.compareTo(b.result);
    });
    return out;
  }

  static List<EncyclopediaOutcomeEntry> _definedOutcomes(
    Map<String, dynamic> distribution, {
    required String Function(String) norm,
    Set<String> excludedResults = const <String>{},
  }) {
    if (distribution.isEmpty) return const [];

    final excluded = excludedResults.map((e) => e.trim().toLowerCase()).toSet();
    final normalized = <String, int>{};
    for (final entry in distribution.entries) {
      final weight = (entry.value as num?)?.toInt() ?? 0;
      if (weight <= 0) continue;
      final key = norm(entry.key);
      if (excluded.contains(key.trim().toLowerCase())) continue;
      normalized[key] = (normalized[key] ?? 0) + weight;
    }
    if (normalized.isEmpty) return const [];

    final outcomes = normalized.entries
        .map(
          (entry) =>
              EncyclopediaOutcomeEntry(result: entry.key, weight: entry.value),
        )
        .toList(growable: false);
    outcomes.sort((a, b) {
      final byWeight = b.weight.compareTo(a.weight);
      if (byWeight != 0) return byWeight;
      return a.result.compareTo(b.result);
    });
    return List.unmodifiable(outcomes);
  }

  static String? _primaryElement(List<String> types) {
    if (types.isEmpty) return null;
    return ElementRecipeConfig.norm(types.first);
  }

  static String? _familyFromCreature(Creature creature) {
    final fam = familyOf(creature).trim();
    if (fam.isEmpty || fam.toLowerCase() == 'unknown') return null;
    return FamilyRecipeConfig.norm(fam);
  }

  static String? _familyFromParent(
    ParentSnapshot parent,
    CreatureCatalog repo,
  ) {
    final fromRepo = repo.getCreatureById(parent.baseId);
    if (fromRepo != null) {
      final fam = _familyFromCreature(fromRepo);
      if (fam != null) return fam;
    }

    if (parent.familyLineage.isNotEmpty) {
      final topFamily = _strictTopLineage(parent.familyLineage);
      if (topFamily != null && topFamily.toLowerCase() != 'unknown') {
        return FamilyRecipeConfig.norm(topFamily);
      }
    }

    const knownFamilies = [
      'Let',
      'Horn',
      'Kin',
      'Mane',
      'Mask',
      'Pip',
      'Wing',
      'Mystic',
    ];
    final n = parent.name.toLowerCase();
    for (final family in knownFamilies) {
      if (n.endsWith(family.toLowerCase())) return family;
    }
    return null;
  }

  static String? _strictTopLineage(Map<String, int> lineage) {
    if (lineage.isEmpty) return null;
    final topWeight = lineage.values.reduce(max);
    final top = lineage.entries.where((e) => e.value == topWeight).toList();
    if (top.length != 1) return null;
    return top.first.key;
  }

  static Future<Set<String>> _readDiscoveredSet(
    AlchemonsDatabase db,
    String key,
  ) async {
    final raw = await db.settingsDao.getSetting(key);
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toSet();
      }
    } catch (_) {}
    return <String>{};
  }

  static Future<Set<String>> _readDiscoveredOutcomeSet(
    AlchemonsDatabase db, {
    required String currentKey,
    required String legacyPairKey,
    required Map<String, EncyclopediaRecipeEntry> recipesByPair,
  }) async {
    final current = await _readDiscoveredSet(db, currentKey);
    final legacyPairs = await _readDiscoveredSet(db, legacyPairKey);
    if (legacyPairs.isEmpty) return current;

    final merged = {...current};
    for (final pairKey in legacyPairs) {
      final recipe = recipesByPair[pairKey];
      if (recipe == null) continue;
      merged.add(recipe.outcomePathKey(recipe.result));
    }
    if (merged.length != current.length || !merged.containsAll(current)) {
      await _writeDiscoveredSet(db, currentKey, merged);
    }
    return merged;
  }

  static Set<String> _pairKeysFromOutcomeKeys(
    List<EncyclopediaRecipeEntry> recipes,
    Set<String> discoveredOutcomeKeys,
  ) {
    final discoveredPairs = <String>{};
    for (final recipe in recipes) {
      final hasAny = recipe.outcomes.any(
        (outcome) => discoveredOutcomeKeys.contains(
          recipe.outcomePathKey(outcome.result),
        ),
      );
      if (hasAny) discoveredPairs.add(recipe.pairKey);
    }
    return discoveredPairs;
  }

  static Future<void> _writeDiscoveredSet(
    AlchemonsDatabase db,
    String key,
    Set<String> values,
  ) async {
    final list = values.toList()..sort();
    await db.settingsDao.setSetting(key, jsonEncode(list));
  }

  static Future<List<EncyclopediaNatureEntry>> _loadNatureEntries(
    AlchemonsDatabase db,
    List<CreatureInstance> instances,
  ) async {
    final stored = await _readDiscoveredSet(db, _natureDiscoveredKey);
    final observedCounts = <String, int>{};

    for (final instance in instances) {
      for (final natureId in [instance.natureId, instance.natureId2]) {
        final id = natureId?.trim();
        if (id == null || id.isEmpty) continue;
        observedCounts[id] = (observedCounts[id] ?? 0) + 1;
      }
    }

    final merged = {...stored, ...observedCounts.keys};
    if (merged.length != stored.length || !merged.containsAll(stored)) {
      await _writeDiscoveredSet(db, _natureDiscoveredKey, merged);
    }

    final entries = <EncyclopediaNatureEntry>[];
    for (final nature in NatureCatalog.all) {
      entries.add(
        EncyclopediaNatureEntry(
          nature: nature,
          observedCount: observedCounts[nature.id] ?? 0,
          discovered: merged.contains(nature.id),
        ),
      );
    }

    entries.sort((a, b) {
      if (a.discovered != b.discovered) return a.discovered ? -1 : 1;
      return a.nature.id.compareTo(b.nature.id);
    });
    return List.unmodifiable(entries);
  }
}

class _RecipeCatalog {
  final List<EncyclopediaRecipeEntry> familyRecipes;
  final List<EncyclopediaRecipeEntry> elementRecipes;
  final Map<String, EncyclopediaRecipeEntry> familyByPair;
  final Map<String, EncyclopediaRecipeEntry> elementByPair;

  const _RecipeCatalog({
    required this.familyRecipes,
    required this.elementRecipes,
    required this.familyByPair,
    required this.elementByPair,
  });
}
