import 'dart:convert';
import 'dart:math';
import 'dart:ui';

enum CosmicContestTrait { beauty, speed, strength, intelligence }

extension CosmicContestTraitX on CosmicContestTrait {
  String get label => switch (this) {
    CosmicContestTrait.beauty => 'Beauty',
    CosmicContestTrait.speed => 'Speed',
    CosmicContestTrait.strength => 'Strength',
    CosmicContestTrait.intelligence => 'Intelligence',
  };

  String get arenaLabel => '$label Contest';

  Color get color => switch (this) {
    CosmicContestTrait.beauty => const Color(0xFFF8BBD0),
    CosmicContestTrait.speed => const Color(0xFF81D4FA),
    CosmicContestTrait.strength => const Color(0xFFFF8A65),
    CosmicContestTrait.intelligence => const Color(0xFFB39DDB),
  };
}

enum CosmicContestVisualTheme {
  standard,
  radiant,
  thermal,
  cryogenic,
  prismatic,
}

extension CosmicContestVisualThemeX on CosmicContestVisualTheme {
  String get label => switch (this) {
    CosmicContestVisualTheme.standard => 'Standard',
    CosmicContestVisualTheme.radiant => 'Radiant',
    CosmicContestVisualTheme.thermal => 'Thermal',
    CosmicContestVisualTheme.cryogenic => 'Cryogenic',
    CosmicContestVisualTheme.prismatic => 'Prismatic',
  };
}

class CosmicContestArena {
  Offset position;
  final CosmicContestTrait trait;
  bool discovered;

  CosmicContestArena({
    required this.position,
    required this.trait,
    this.discovered = false,
  });

  static const double visualRadius = 260.0;
  static const double interactRadius = 360.0;
  static const double exitRadius = 450.0;
}

class CosmicContestOpponent {
  final String name;
  final String element;
  final String family;
  final double targetScore;
  final CosmicContestVisualTheme visualTheme;

  const CosmicContestOpponent({
    required this.name,
    required this.element,
    required this.family,
    required this.targetScore,
    this.visualTheme = CosmicContestVisualTheme.standard,
  });
}

class CosmicContestLevel {
  final int level; // 1..5
  final CosmicContestOpponent opponent;
  final int rewardShards;

  const CosmicContestLevel({
    required this.level,
    required this.opponent,
    required this.rewardShards,
  });
}

const Map<CosmicContestTrait, List<CosmicContestLevel>> kCosmicContestLevels = {
  CosmicContestTrait.beauty: [
    CosmicContestLevel(
      level: 1,
      rewardShards: 20,
      opponent: CosmicContestOpponent(
        name: 'Glimmerlet',
        element: 'Light',
        family: 'let',
        targetScore: 3.15,
      ),
    ),
    CosmicContestLevel(
      level: 2,
      rewardShards: 35,
      opponent: CosmicContestOpponent(
        name: 'Quartzmane',
        element: 'Crystal',
        family: 'mane',
        targetScore: 3.55,
      ),
    ),
    CosmicContestLevel(
      level: 3,
      rewardShards: 50,
      opponent: CosmicContestOpponent(
        name: 'Aurawing',
        element: 'Spirit',
        family: 'wing',
        targetScore: 3.95,
      ),
    ),
    CosmicContestLevel(
      level: 4,
      rewardShards: 70,
      opponent: CosmicContestOpponent(
        name: 'Prismask',
        element: 'Light',
        family: 'mask',
        targetScore: 4.35,
      ),
    ),
    CosmicContestLevel(
      level: 5,
      rewardShards: 95,
      opponent: CosmicContestOpponent(
        name: 'Solacrown',
        element: 'Crystal',
        family: 'horn',
        targetScore: 4.75,
      ),
    ),
  ],
  CosmicContestTrait.speed: [
    CosmicContestLevel(
      level: 1,
      rewardShards: 20,
      opponent: CosmicContestOpponent(
        name: 'Sparklet',
        element: 'Lightning',
        family: 'let',
        targetScore: 3.2,
      ),
    ),
    CosmicContestLevel(
      level: 2,
      rewardShards: 35,
      opponent: CosmicContestOpponent(
        name: 'Riptidepip',
        element: 'Water',
        family: 'pip',
        targetScore: 3.6,
      ),
    ),
    CosmicContestLevel(
      level: 3,
      rewardShards: 50,
      opponent: CosmicContestOpponent(
        name: 'Frostwing',
        element: 'Ice',
        family: 'wing',
        targetScore: 4.0,
      ),
    ),
    CosmicContestLevel(
      level: 4,
      rewardShards: 70,
      opponent: CosmicContestOpponent(
        name: 'Skykin',
        element: 'Air',
        family: 'kin',
        targetScore: 4.4,
      ),
    ),
    CosmicContestLevel(
      level: 5,
      rewardShards: 95,
      opponent: CosmicContestOpponent(
        name: 'Voltacrown',
        element: 'Lightning',
        family: 'horn',
        targetScore: 4.85,
      ),
    ),
  ],
  CosmicContestTrait.strength: [
    CosmicContestLevel(
      level: 1,
      rewardShards: 20,
      opponent: CosmicContestOpponent(
        name: 'Basaltlet',
        element: 'Earth',
        family: 'let',
        targetScore: 3.25,
      ),
    ),
    CosmicContestLevel(
      level: 2,
      rewardShards: 35,
      opponent: CosmicContestOpponent(
        name: 'Magmamane',
        element: 'Lava',
        family: 'mane',
        targetScore: 3.7,
      ),
    ),
    CosmicContestLevel(
      level: 3,
      rewardShards: 50,
      opponent: CosmicContestOpponent(
        name: 'Ironhorn',
        element: 'Earth',
        family: 'horn',
        targetScore: 4.1,
      ),
    ),
    CosmicContestLevel(
      level: 4,
      rewardShards: 70,
      opponent: CosmicContestOpponent(
        name: 'Siegekin',
        element: 'Blood',
        family: 'kin',
        targetScore: 4.5,
      ),
    ),
    CosmicContestLevel(
      level: 5,
      rewardShards: 95,
      opponent: CosmicContestOpponent(
        name: 'Titanforge',
        element: 'Lava',
        family: 'mask',
        targetScore: 4.95,
      ),
    ),
  ],
  CosmicContestTrait.intelligence: [
    CosmicContestLevel(
      level: 1,
      rewardShards: 20,
      opponent: CosmicContestOpponent(
        name: 'Glyphlet',
        element: 'Spirit',
        family: 'let',
        targetScore: 3.1,
      ),
    ),
    CosmicContestLevel(
      level: 2,
      rewardShards: 35,
      opponent: CosmicContestOpponent(
        name: 'Cipherpip',
        element: 'Crystal',
        family: 'pip',
        targetScore: 3.55,
      ),
    ),
    CosmicContestLevel(
      level: 3,
      rewardShards: 50,
      opponent: CosmicContestOpponent(
        name: 'Aethermask',
        element: 'Spirit',
        family: 'mask',
        targetScore: 4.0,
      ),
    ),
    CosmicContestLevel(
      level: 4,
      rewardShards: 70,
      opponent: CosmicContestOpponent(
        name: 'Lumenkin',
        element: 'Light',
        family: 'kin',
        targetScore: 4.45,
      ),
    ),
    CosmicContestLevel(
      level: 5,
      rewardShards: 95,
      opponent: CosmicContestOpponent(
        name: 'Mindcrown',
        element: 'Dark',
        family: 'wing',
        targetScore: 4.9,
      ),
    ),
  ],
};

const Map<int, List<CosmicContestOpponent>> kBeautyContestOpponentPools = {
  1: [
    CosmicContestOpponent(
      name: 'Glimmerlet',
      element: 'Light',
      family: 'let',
      targetScore: 3.13,
      visualTheme: CosmicContestVisualTheme.radiant,
    ),
    CosmicContestOpponent(
      name: 'Pearlpip',
      element: 'Crystal',
      family: 'pip',
      targetScore: 3.18,
      visualTheme: CosmicContestVisualTheme.standard,
    ),
    CosmicContestOpponent(
      name: 'Daypetal',
      element: 'Plant',
      family: 'kin',
      targetScore: 3.10,
      visualTheme: CosmicContestVisualTheme.radiant,
    ),
  ],
  2: [
    CosmicContestOpponent(
      name: 'Quartzmane',
      element: 'Crystal',
      family: 'mane',
      targetScore: 3.56,
      visualTheme: CosmicContestVisualTheme.standard,
    ),
    CosmicContestOpponent(
      name: 'Halolet',
      element: 'Light',
      family: 'let',
      targetScore: 3.52,
      visualTheme: CosmicContestVisualTheme.radiant,
    ),
    CosmicContestOpponent(
      name: 'Vitraskin',
      element: 'Crystal',
      family: 'mask',
      targetScore: 3.60,
      visualTheme: CosmicContestVisualTheme.standard,
    ),
  ],
  3: [
    CosmicContestOpponent(
      name: 'Cinderveil',
      element: 'Fire',
      family: 'wing',
      targetScore: 3.95,
      visualTheme: CosmicContestVisualTheme.thermal,
    ),
    CosmicContestOpponent(
      name: 'Hushfrost',
      element: 'Ice',
      family: 'mask',
      targetScore: 3.99,
      visualTheme: CosmicContestVisualTheme.cryogenic,
    ),
    CosmicContestOpponent(
      name: 'Aurawing',
      element: 'Spirit',
      family: 'wing',
      targetScore: 3.92,
      visualTheme: CosmicContestVisualTheme.radiant,
    ),
  ],
  4: [
    CosmicContestOpponent(
      name: 'Embermask',
      element: 'Fire',
      family: 'mask',
      targetScore: 4.36,
      visualTheme: CosmicContestVisualTheme.thermal,
    ),
    CosmicContestOpponent(
      name: 'Cryocrown',
      element: 'Ice',
      family: 'horn',
      targetScore: 4.33,
      visualTheme: CosmicContestVisualTheme.cryogenic,
    ),
    CosmicContestOpponent(
      name: 'Solsticekin',
      element: 'Light',
      family: 'kin',
      targetScore: 4.38,
      visualTheme: CosmicContestVisualTheme.radiant,
    ),
  ],
  5: [
    CosmicContestOpponent(
      name: 'Prismask Prime',
      element: 'Crystal',
      family: 'mask',
      targetScore: 4.92,
      visualTheme: CosmicContestVisualTheme.prismatic,
    ),
    CosmicContestOpponent(
      name: 'Iridescent Crown',
      element: 'Light',
      family: 'horn',
      targetScore: 4.88,
      visualTheme: CosmicContestVisualTheme.prismatic,
    ),
    CosmicContestOpponent(
      name: 'Spectrum Sovereign',
      element: 'Spirit',
      family: 'wing',
      targetScore: 4.95,
      visualTheme: CosmicContestVisualTheme.prismatic,
    ),
  ],
};

List<CosmicContestOpponent> beautyContestOpponentsForLevel(int level) {
  final pool = kBeautyContestOpponentPools[level];
  if (pool != null && pool.isNotEmpty) return pool;
  final fallback = kCosmicContestLevels[CosmicContestTrait.beauty];
  if (fallback == null || level < 1 || level > fallback.length) return const [];
  return [fallback[level - 1].opponent];
}

class CosmicContestProgress {
  final Map<CosmicContestTrait, int> completedByTrait; // 0..5

  CosmicContestProgress({required this.completedByTrait});

  factory CosmicContestProgress.fresh() {
    return CosmicContestProgress(
      completedByTrait: {
        for (final trait in CosmicContestTrait.values) trait: 0,
      },
    );
  }

  int completedLevels(CosmicContestTrait trait) =>
      (completedByTrait[trait] ?? 0).clamp(0, 5);

  bool isMastered(CosmicContestTrait trait) => completedLevels(trait) >= 5;

  CosmicContestProgress withCompleted(CosmicContestTrait trait, int completed) {
    final next = Map<CosmicContestTrait, int>.from(completedByTrait);
    next[trait] = completed.clamp(0, 5);
    return CosmicContestProgress(completedByTrait: next);
  }

  String serialise() {
    final map = <String, int>{};
    for (final trait in CosmicContestTrait.values) {
      map[trait.name] = completedLevels(trait);
    }
    return jsonEncode(map);
  }

  factory CosmicContestProgress.deserialise(String raw) {
    final base = CosmicContestProgress.fresh().completedByTrait;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        for (final trait in CosmicContestTrait.values) {
          final v = decoded[trait.name];
          if (v is num) base[trait] = v.toInt().clamp(0, 5);
        }
      }
    } catch (_) {
      // fall through to defaults
    }
    return CosmicContestProgress(completedByTrait: base);
  }
}

class CosmicContestHintLore {
  final String id;
  final String text;

  const CosmicContestHintLore({required this.id, required this.text});
}

const List<CosmicContestHintLore> kCosmicContestHintLore = [
  CosmicContestHintLore(
    id: 'fast_elements_1',
    text:
        'A torn note: "Lightning, water, and ice are whispered to outrun all."',
  ),
  CosmicContestHintLore(
    id: 'fast_family_wing',
    text: 'A racer\'s chalk mark: "Wing bloodlines catch speed early."',
  ),
  CosmicContestHintLore(
    id: 'fast_family_let',
    text: 'A pit-lane scrap: "Let lines launch quick off the start."',
  ),
  CosmicContestHintLore(
    id: 'fast_nature_swift',
    text:
        'A bent telemetry card: "Swift by name, hyperbolic by legend - both love speed."',
  ),
  CosmicContestHintLore(
    id: 'fast_pure_lightning',
    text:
        'A storm etching: "Pure lightning lineages hold pace better than mixed drag."',
  ),
  CosmicContestHintLore(
    id: 'beauty_elements_1',
    text:
        'A polished shard reads: "Crystal and light hold beauty better than poison ever could."',
  ),
  CosmicContestHintLore(
    id: 'beauty_prismatic',
    text:
        'An engraved plate: "Prismatic coats draw every eye in beauty trials."',
  ),
  CosmicContestHintLore(
    id: 'beauty_variant',
    text:
        'A stage memo: "Rare variants and unusual tints tend to sway the judges."',
  ),
  CosmicContestHintLore(
    id: 'beauty_pure_element',
    text:
        'A velvet ribbon note: "Single-element blood sings cleaner on the beauty floor."',
  ),
  CosmicContestHintLore(
    id: 'beauty_species_pure',
    text:
        'A critic ledger: "Pure species lines read as deliberate elegance, not noise."',
  ),
  CosmicContestHintLore(
    id: 'beauty_nature',
    text: 'A perfume card: "Elegant natures bloom brighter under lights."',
  ),
  CosmicContestHintLore(
    id: 'strength_elements_1',
    text:
        'A basalt tablet: "Earth and lava bodies endure where soft forms fail."',
  ),
  CosmicContestHintLore(
    id: 'strength_size',
    text:
        'A field memo: "Large frames carry momentum; size matters in strength."',
  ),
  CosmicContestHintLore(
    id: 'speed_family',
    text:
        'A smudged journal: "Winged lines usually gain tempo before the horned."',
  ),
  CosmicContestHintLore(
    id: 'intelligence_lineage',
    text:
        'A cipher strip: "Deep mixed lineages think in more patterns than pure strains."',
  ),
  CosmicContestHintLore(
    id: 'intelligence_elements_1',
    text:
        'A library scrap: "Spirit, light, dark, and crystal are favored in mind duels."',
  ),
  CosmicContestHintLore(
    id: 'beauty_bad_elements',
    text:
        'A critic card: "Judges penalize corrosive palettes - poison and blood rarely place."',
  ),
  CosmicContestHintLore(
    id: 'speed_bad_elements',
    text: 'A track warning: "Mud and earth drag acceleration in speed lanes."',
  ),
  CosmicContestHintLore(
    id: 'strength_family',
    text: 'A coach note: "Horn and mane bloodlines often peak in raw force."',
  ),
  CosmicContestHintLore(
    id: 'strength_nature',
    text: 'A cracked plate: "Mighty natures convert stance into impact."',
  ),
  CosmicContestHintLore(
    id: 'strength_pure_line',
    text:
        'A quarry annotation: "Pure earth-heavy lines keep leverage through the shove."',
  ),
  CosmicContestHintLore(
    id: 'intelligence_family',
    text:
        'A margin note: "Mask and kin lines tend to solve puzzle rounds faster."',
  ),
  CosmicContestHintLore(
    id: 'intelligence_nature_clever',
    text: 'A librarian\'s tag: "Clever natures break cipher loops quickly."',
  ),
  CosmicContestHintLore(
    id: 'intelligence_nature_neuroadaptive',
    text:
        'A neural sketch: "Neuroadaptive minds learn between rounds, not after."',
  ),
  CosmicContestHintLore(
    id: 'intelligence_species_pure',
    text:
        'A sealed thesis: "Pure species lines retain cleaner memory structures."',
  ),
  CosmicContestHintLore(
    id: 'cross_trait_purity',
    text:
        'A folded field card: "Purity matters most when the bloodline matches the contest trait."',
  ),
];

class CosmicContestHintNote {
  final String id;
  final String text;
  Offset position;
  bool collected;

  CosmicContestHintNote({
    required this.id,
    required this.text,
    required this.position,
    this.collected = false,
  });

  static const double interactRadius = 90.0;
  static const double revealRadius = 260.0;
}

String serialiseContestHintIds(Set<String> ids) =>
    (ids.toList()..sort()).join(',');

Set<String> deserialiseContestHintIds(String raw) {
  if (raw.isEmpty) return {};
  return raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
}

List<CosmicContestArena> generateCosmicContestArenas({
  required int seed,
  required Size worldSize,
  required List<Offset> obstacles,
}) {
  final rng = Random(seed ^ 0xCC7711);
  const margin = 2200.0;
  const minObstacleDist = 2400.0;
  const minArenaDist = 4800.0;

  final out = <CosmicContestArena>[];
  for (final trait in CosmicContestTrait.values) {
    Offset pos;
    int tries = 0;
    do {
      pos = Offset(
        margin + rng.nextDouble() * (worldSize.width - margin * 2),
        margin + rng.nextDouble() * (worldSize.height - margin * 2),
      );
      tries++;
    } while (tries < 600 &&
        (obstacles.any((o) => (o - pos).distance < minObstacleDist) ||
            out.any((a) => (a.position - pos).distance < minArenaDist)));
    out.add(CosmicContestArena(position: pos, trait: trait));
  }
  return out;
}

List<CosmicContestHintNote> generateCosmicContestHintNotes({
  required int seed,
  required Size worldSize,
  required List<Offset> obstacles,
}) {
  final rng = Random(seed ^ 0xCC7712);
  const margin = 1800.0;
  const minObstacleDist = 1500.0;
  const minHintDist = 1200.0;

  final out = <CosmicContestHintNote>[];
  for (final lore in kCosmicContestHintLore) {
    Offset pos;
    int tries = 0;
    do {
      pos = Offset(
        margin + rng.nextDouble() * (worldSize.width - margin * 2),
        margin + rng.nextDouble() * (worldSize.height - margin * 2),
      );
      tries++;
    } while (tries < 500 &&
        (obstacles.any((o) => (o - pos).distance < minObstacleDist) ||
            out.any((h) => (h.position - pos).distance < minHintDist)));
    out.add(CosmicContestHintNote(id: lore.id, text: lore.text, position: pos));
  }
  return out;
}
