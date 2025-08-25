class GeneVariant {
  final String id; // "tiny", "warm", "bright"
  final String name;
  final int dominance; // higher tends to win (except special rules)
  final Map<String, dynamic> effect; // free-form per track
  final String description;

  GeneVariant({
    required this.id,
    required this.name,
    required this.dominance,
    required this.effect,
    required this.description,
  });

  factory GeneVariant.fromJson(Map<String, dynamic> j) => GeneVariant(
    id: j['id'],
    name: j['name'],
    dominance: j['dominance'] ?? 0,
    effect: Map<String, dynamic>.from(j['effect'] ?? const {}),
    description: j['description'] ?? '',
  );
}

class GeneTrack {
  final String key; // "size" | "tinting"
  final String category; // cosmetic grouping
  final String
  inheritance; // "average_with_variance" | "blend_with_mutation" | "rare_dominant"
  final double mutationChance; // 0..1
  final List<GeneVariant> variants;

  GeneTrack({
    required this.key,
    required this.category,
    required this.inheritance,
    required this.mutationChance,
    required this.variants,
  });

  factory GeneTrack.fromJson(String key, Map<String, dynamic> j) => GeneTrack(
    key: key,
    category: j['category'],
    inheritance: j['inheritance'],
    mutationChance: (j['mutation_chance'] ?? 0).toDouble(),
    variants: (j['variants'] as List)
        .map((v) => GeneVariant.fromJson(Map<String, dynamic>.from(v)))
        .toList(),
  );

  GeneVariant byId(String id) => variants.firstWhere((v) => v.id == id);
}
