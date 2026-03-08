import 'dart:convert';

import 'effect.dart';

typedef EffectFactory = Effect Function(Map<String, dynamic> json);

class EffectRegistry {
  static final Map<String, EffectFactory> _factories = {};

  static void register(String id, EffectFactory factory) {
    _factories[id] = factory;
  }

  static Effect create(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null) throw StateError('Effect JSON missing id');
    final factory = _factories[id];
    if (factory == null)
      throw StateError('No factory registered for effect $id');
    return factory(json);
  }

  /// Convenience: create many from a JSON string or decoded list
  static List<Effect> createAllFromJsonString(String s) {
    final decoded = json.decode(s);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>().map(create).toList();
    }
    return [];
  }
}
