import 'dart:convert';
import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/breeding_config.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:flutter/services.dart' show rootBundle;

enum EncyclopediaRecipeKind { family, element }

class EncyclopediaRecipeEntry {
  final EncyclopediaRecipeKind kind;
  final String pairKey;
  final String parentA;
  final String parentB;
  final String result;
  final int topWeight;

  const EncyclopediaRecipeEntry({
    required this.kind,
    required this.pairKey,
    required this.parentA,
    required this.parentB,
    required this.result,
    required this.topWeight,
  });
}

class AlchemicalEncyclopediaSnapshot {
  final List<EncyclopediaRecipeEntry> familyRecipes;
  final List<EncyclopediaRecipeEntry> elementRecipes;
  final Set<String> discoveredFamilyKeys;
  final Set<String> discoveredElementKeys;

  const AlchemicalEncyclopediaSnapshot({
    required this.familyRecipes,
    required this.elementRecipes,
    required this.discoveredFamilyKeys,
    required this.discoveredElementKeys,
  });

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
  static const String _familyDiscoveredKey = 'enc.family.discovered.v1';
  static const String _elementDiscoveredKey = 'enc.element.discovered.v1';

  static Future<_RecipeCatalog>? _catalogFuture;

  static Future<AlchemicalEncyclopediaSnapshot> loadSnapshot({
    required AlchemonsDatabase db,
  }) async {
    final catalog = await _loadCatalog();
    final discoveredFamily = await _readDiscoveredSet(db, _familyDiscoveredKey);
    final discoveredElement = await _readDiscoveredSet(
      db,
      _elementDiscoveredKey,
    );

    return AlchemicalEncyclopediaSnapshot(
      familyRecipes: catalog.familyRecipes,
      elementRecipes: catalog.elementRecipes,
      discoveredFamilyKeys: discoveredFamily,
      discoveredElementKeys: discoveredElement,
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
    final discoveredFamily = await _readDiscoveredSet(db, _familyDiscoveredKey);
    final discoveredElement = await _readDiscoveredSet(
      db,
      _elementDiscoveredKey,
    );

    final unlocked = <EncyclopediaRecipeEntry>[];
    var familyChanged = false;
    var elementChanged = false;

    if (parentAElement != null &&
        parentBElement != null &&
        childElement != null) {
      final pairKey = ElementRecipeConfig.keyOf(parentAElement, parentBElement);
      final candidate = catalog.elementByPair[pairKey];
      if (candidate != null &&
          candidate.result == childElement &&
          !discoveredElement.contains(pairKey)) {
        discoveredElement.add(pairKey);
        unlocked.add(candidate);
        elementChanged = true;
      }
    }

    if (parentAFamily != null && parentBFamily != null && childFamily != null) {
      final pairKey = FamilyRecipeConfig.keyOf(parentAFamily, parentBFamily);
      final candidate = catalog.familyByPair[pairKey];
      if (candidate != null &&
          candidate.result == childFamily &&
          !discoveredFamily.contains(pairKey)) {
        discoveredFamily.add(pairKey);
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

  static Future<_RecipeCatalog> _loadCatalog() {
    return _catalogFuture ??= _buildCatalog();
  }

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

      final top = _strictTopNewResult(
        dist,
        parentA: parentA,
        parentB: parentB,
        norm: norm,
      );
      if (top == null) continue;

      final pairKey = keyOf(parentA, parentB);
      final pairParts = pairKey.split('+');
      byPair[pairKey] = EncyclopediaRecipeEntry(
        kind: kind,
        pairKey: pairKey,
        parentA: pairParts[0],
        parentB: pairParts[1],
        result: top.result,
        topWeight: top.weight,
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

  static ({String result, int weight})? _strictTopNewResult(
    Map<String, dynamic> distribution, {
    required String parentA,
    required String parentB,
    required String Function(String) norm,
  }) {
    if (distribution.isEmpty) return null;

    final normalized = <String, int>{};
    for (final entry in distribution.entries) {
      final weight = (entry.value as num?)?.toInt() ?? 0;
      if (weight <= 0) continue;
      final key = norm(entry.key);
      normalized[key] = (normalized[key] ?? 0) + weight;
    }
    if (normalized.isEmpty) return null;

    final maxWeight = normalized.values.reduce(max);
    final top = normalized.entries.where((e) => e.value == maxWeight).toList();
    if (top.length != 1) return null;

    final topResult = top.first.key;
    if (topResult == parentA || topResult == parentB) return null;

    return (result: topResult, weight: maxWeight);
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

  static Future<void> _writeDiscoveredSet(
    AlchemonsDatabase db,
    String key,
    Set<String> values,
  ) async {
    final list = values.toList()..sort();
    await db.settingsDao.setSetting(key, jsonEncode(list));
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
