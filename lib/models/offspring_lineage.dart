class OffspringLineageData {
  final int generationDepth;
  final Map<String, int> factionLineage;
  final String? variantFaction;
  final String nativeFaction;
  final Map<String, int> elementLineage; // e.g. {'Water': 3, 'Fire': 5}
  final Map<String, int> familyLineage; // e.g. {'pip': 4, 'wing': 2}

  const OffspringLineageData({
    required this.generationDepth,
    required this.factionLineage,
    required this.variantFaction,
    required this.nativeFaction,
    this.elementLineage = const {},
    this.familyLineage = const {},
  });

  Map<String, dynamic> toJson() => {
    'generationDepth': generationDepth,
    'factionLineage': factionLineage,
    'variantFaction': variantFaction,
    'nativeFaction': nativeFaction,
    'elementLineage': elementLineage,
    'familyLineage': familyLineage,
  };

  factory OffspringLineageData.fromJson(Map<String, dynamic> j) {
    final depth = (j['generationDepth'] as num?)?.toInt() ?? 0;
    final nf = (j['nativeFaction'] as String?) ?? 'Unknown';
    final vf = j['variantFaction'] as String?;

    final rawMap = j['factionLineage'];
    Map<String, int> m = {};
    if (rawMap is Map) {
      m = rawMap.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    }
    // NEW: element + family maps (safe defaults)
    Map<String, int> _coerceIntMap(dynamic raw) {
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      }
      return {};
    }

    final elemM = _coerceIntMap(j['elementLineage']);
    final famM = _coerceIntMap(j['familyLineage']);

    return OffspringLineageData(
      generationDepth: depth,
      factionLineage: m,
      variantFaction: vf,
      nativeFaction: nf,
      elementLineage: elemM,
      familyLineage: famM,
    );
  }
}
