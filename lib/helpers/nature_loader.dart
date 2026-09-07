import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:alchemons/models/nature.dart';

class NatureCatalog {
  static final List<NatureDef> _all = [];
  static const Map<String, String> _legacyAliases = {'Placidal': 'Placid'};

  static List<NatureDef> get all => List.unmodifiable(_all);
  static List<NatureDef> get rollable =>
      List.unmodifiable(_all.where((nature) => nature.wildWeight > 0));

  static NatureDef random(Random rng) {
    final pool = rollable;
    return pool[rng.nextInt(pool.length)];
  }

  static NatureDef? byId(String id) {
    final canonicalId = _legacyAliases[id] ?? id;
    for (final n in _all) {
      if (n.id == canonicalId) return n;
    }
    return null;
  }

  static void _setAll(List<NatureDef> list) {
    _all
      ..clear()
      ..addAll(list);
  }
}

/// Call this once at startup
Future<void> loadNatures({
  String path = 'assets/data/alchemons_natures.json',
}) async {
  final raw = await rootBundle.loadString(path);
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final list = (data['natures'] as List? ?? const []);

  final parsed = <NatureDef>[];
  for (var i = 0; i < list.length; i++) {
    final item = list[i] as Map<String, dynamic>;
    try {
      parsed.add(NatureDef.fromJson(item));
    } catch (e) {
      // Logs which specific entry failed
      throw FormatException('Failed parsing nature at index $i: $e\n$item');
    }
  }
  NatureCatalog._setAll(parsed);
}

// --- Weighted utilities ---
NatureDef _weightedPick(List<NatureDef> pool, Random rng) {
  if (pool.isEmpty) {
    throw StateError('No natures loaded');
  }
  final eligible = pool.where((n) => n.wildWeight > 0).toList();
  if (eligible.isEmpty) throw StateError('No rollable natures loaded');
  final weights = eligible.map((n) => n.wildWeight).toList();
  final total = weights.fold<int>(0, (a, b) => a + b);
  var roll = rng.nextInt(total);
  for (var i = 0; i < eligible.length; i++) {
    roll -= weights[i];
    if (roll < 0) return eligible[i];
  }
  return eligible.last;
}

extension NatureCatalogWeighted on NatureCatalog {
  /// Old uniform picker (kept for compatibility, if you still want it)
  static NatureDef uniformRandom(Random rng) =>
      NatureCatalog.rollable[rng.nextInt(NatureCatalog.rollable.length)];

  /// New: dominance-weighted random from the whole catalog
  static NatureDef weightedRandom(Random rng, {Set<String>? excludeIds}) {
    final src = excludeIds == null || excludeIds.isEmpty
        ? NatureCatalog.rollable
        : NatureCatalog.rollable
              .where((n) => !excludeIds.contains(n.id))
              .toList();
    return _weightedPick(src, rng);
  }

  /// New: dominance-weighted pick from a specific pool (e.g., parents)
  static NatureDef weightedFromPool(List<NatureDef> pool, Random rng) {
    if (pool.isEmpty) throw StateError('No parent natures available');
    final total = pool.fold<int>(0, (sum, n) => sum + max(1, n.dominance));
    var roll = rng.nextInt(total);
    for (final nature in pool) {
      roll -= max(1, nature.dominance);
      if (roll < 0) return nature;
    }
    return pool.last;
  }

  /// Regular wild Alchemons have no Nature 15% of the time, one Nature 70%,
  /// and two distinct Natures 15%. The expected number of slots remains one.
  static List<NatureDef> rollWildSlots(Random rng, {bool elite = false}) {
    final roll = rng.nextDouble();
    final count = elite
        ? (roll < .30 ? 2 : 1)
        : (roll < .15
              ? 0
              : roll < .85
              ? 1
              : 2);
    final result = <NatureDef>[];
    while (result.length < count) {
      final next = weightedRandom(
        rng,
        excludeIds: result.map((n) => n.id).toSet(),
      );
      if (!_isCompatible(result, next)) continue;
      result.add(next);
    }
    return result;
  }

  static bool _isCompatible(List<NatureDef> existing, NatureDef candidate) {
    const conflicts = [
      {'Homotypic', 'Heterotypic'},
      {'Sympatric', 'Conspecific'},
    ];
    return conflicts.every(
      (pair) =>
          !pair.contains(candidate.id) ||
          existing.every((n) => !pair.contains(n.id)),
    );
  }
}
