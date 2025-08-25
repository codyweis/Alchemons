import 'dart:convert';

import 'package:alchemons/models/genetics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class GeneticsCatalog {
  static final Map<String, GeneTrack> _tracks = {};
  static Map<String, dynamic> breedingEffects = const {};

  static GeneTrack track(String key) => _tracks[key]!;
  static Iterable<GeneTrack> get all => _tracks.values;

  static Future<void> load({
    String path = 'assets/data/alchemons_genetics.json',
  }) async {
    final raw = await rootBundle.loadString(path);
    final data = jsonDecode(raw);

    if (data is! Map || data['genetics'] is! Map) {
      throw FormatException('genetics file malformed: missing "genetics" map');
    }

    final genetics = Map<String, dynamic>.from(data['genetics'] as Map);

    _tracks.clear();

    for (final entry in genetics.entries) {
      final key = entry.key.toString();
      final val = entry.value;

      if (key.isEmpty) {
        throw FormatException('genetics has an entry with empty key');
      }
      if (val is! Map) {
        // <-- THIS is the case that causes "Null is not a subtype of String"
        // because Map<String,dynamic>.from(val) would blow up.
        throw FormatException('gene "$key" is not a JSON object: $val');
      }

      try {
        final trackJson = Map<String, dynamic>.from(val);
        _tracks[key] = GeneTrack.fromJson(key, trackJson);
      } catch (e, st) {
        // choose one: either throw (strict) or log-and-skip (lenient)
        // throw FormatException('Failed to parse gene "$key": $e');
        debugPrint('⚠️ Failed to parse gene "$key": $e\n$st');
      }
    }

    breedingEffects = data['breeding_effects'] is Map
        ? Map<String, dynamic>.from(data['breeding_effects'] as Map)
        : <String, dynamic>{};
  }
}
