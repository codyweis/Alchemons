import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:alchemons/models/nature.dart';

class NatureCatalog {
  static final List<NatureDef> _all = [];

  static List<NatureDef> get all => List.unmodifiable(_all);

  static NatureDef random(Random rng) => _all[rng.nextInt(_all.length)];

  static NatureDef? byId(String id) {
    for (final n in _all) {
      if (n.id == id) return n;
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
  // Treat dominance <= 0 as 1 to avoid zero-weight issues
  final weights = pool.map((n) => n.dominance <= 0 ? 1 : n.dominance).toList();
  final total = weights.fold<int>(0, (a, b) => a + b);
  var roll = rng.nextInt(total);
  for (var i = 0; i < pool.length; i++) {
    roll -= weights[i];
    if (roll < 0) return pool[i];
  }
  return pool.last; // fallback
}

extension NatureCatalogWeighted on NatureCatalog {
  /// Old uniform picker (kept for compatibility, if you still want it)
  static NatureDef uniformRandom(Random rng) =>
      NatureCatalog.all[rng.nextInt(NatureCatalog.all.length)];

  /// New: dominance-weighted random from the whole catalog
  static NatureDef weightedRandom(Random rng, {Set<String>? excludeIds}) {
    final src = excludeIds == null || excludeIds.isEmpty
        ? NatureCatalog.all
        : NatureCatalog.all.where((n) => !excludeIds.contains(n.id)).toList();
    return _weightedPick(src, rng);
  }

  /// New: dominance-weighted pick from a specific pool (e.g., parents)
  static NatureDef weightedFromPool(List<NatureDef> pool, Random rng) {
    return _weightedPick(pool, rng);
  }
}
