import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/creature.dart';

/// Read-only catalog sourced from assets.
/// Load once at app start, then pass into services.
class CreatureCatalog {
  List<Creature>? _all;

  bool get isLoaded => _all?.isNotEmpty ?? false;
  List<Creature> get creatures => _all ?? const [];

  Future<void> load({
    String path = 'assets/data/alchemons_creatures.json',
  }) async {
    final raw = await rootBundle.loadString(path);
    final Map<String, dynamic> data = jsonDecode(raw);
    _all = (data['creatures'] as List)
        .map((json) => Creature.fromJson(json))
        .toList(growable: false);
  }

  Creature? getCreatureById(String id) =>
      _all!.firstWhereOrNull((c) => c.id == id);

  List<Creature> byType(String type) =>
      _all!.where((c) => c.types.contains(type)).toList(growable: false);

  List<String> allRarities() =>
      _all!.map((c) => c.rarity).toSet().toList()..sort();

  List<String> allFamilies() =>
      _all!.map((c) => c.mutationFamily).whereType<String>().toSet().toList()
        ..sort();

  List<String> allElements() =>
      _all!.expand((c) => c.types).toSet().toList()..sort();
}

/// Tiny helpers you may reuse project-wide.
extension FirstWhereOrNull<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
