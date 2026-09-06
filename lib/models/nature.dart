import 'dart:collection';

class NatureEffect {
  final Map<String, num> _modifiers;
  NatureEffect(Map<String, num> modifiers)
    : _modifiers = UnmodifiableMapView(modifiers);

  /// Read a raw modifier (e.g. "xp_gain_mult") or null if absent.
  num? operator [](String key) => _modifiers[key];

  /// Convenience helpers
  num getNum(String key, {num fallback = 1.0}) => _modifiers[key] ?? fallback;
  double getDouble(String key, {double fallback = 1.0}) =>
      (_modifiers[key] ?? fallback).toDouble();

  Map<String, num> get modifiers => _modifiers;
}

class NatureDef {
  final String id;
  final int dominance;
  final int wildWeight;
  final String tier;
  final String? description;
  final NatureEffect effect;

  const NatureDef({
    required this.id,
    required this.dominance,
    this.wildWeight = 1,
    this.tier = 'Utility',
    this.description,
    required this.effect,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'dominance': dominance,
    'wildWeight': wildWeight,
    'tier': tier,
    if (description != null) 'description': description,
    'effect': effect.modifiers,
  };

  factory NatureDef.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null || id.isEmpty) {
      throw FormatException('Nature is missing a non-empty "id": $json');
    }
    final dom = (json['dominance'] as num?)?.toInt() ?? 0;
    final wildWeight = (json['wildWeight'] as num?)?.toInt() ?? dom;
    final tier = json['tier'] as String? ?? 'Utility';

    final raw = json['effect'];
    final effectMap = raw is Map
        ? raw.map((k, v) => MapEntry(k.toString(), (v as num)))
        : <String, num>{};

    return NatureDef(
      id: id,
      dominance: dom,
      wildWeight: wildWeight,
      tier: tier,
      description: json['description'] as String?,
      effect: NatureEffect(effectMap),
    );
  }
}
