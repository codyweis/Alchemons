import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import 'default_effects.dart';
import 'effect_registry.dart';
import 'effect.dart';

/// Register default effect factories and load effect instances from a JSON asset.
Future<List<Effect>> loadEffectsFromAsset(String assetPath) async {
  registerDefaultEffects();
  final s = await rootBundle.loadString(assetPath);
  final decoded = json.decode(s);
  if (decoded is List) {
    return decoded
        .cast<Map<String, dynamic>>()
        .map(EffectRegistry.create)
        .toList();
  }
  return [];
}
