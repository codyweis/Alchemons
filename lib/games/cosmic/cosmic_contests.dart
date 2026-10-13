// lib/games/cosmic/cosmic_contests.dart
//
// The four traits a creature is judged on (contest_judging.dart). The
// contest arenas that once stood in open space are retired — the Trials
// replaced them — but what they left behind is kept:
//
//   CosmicContestProgress   the levels each player won, under
//                           'cosmic_trait_contests_v1'; home keepsakes and
//                           the campaign journal still read it
//   kCosmicContestHintLore  the notes once found drifting in space, which
//                           the profile still shows to whoever found them

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

/// A rival as judgeRival (contest_judging.dart) sees it: what it is, and
/// the score it brings before its element and family are counted.
class CosmicContestOpponent {
  final String name;
  final String element;
  final String family;
  final double targetScore;

  const CosmicContestOpponent({
    required this.name,
    required this.element,
    required this.family,
    required this.targetScore,
  });
}

class CosmicContestProgress {
  /// Where it is kept: saves from before the contests were retired still
  /// have it, and what it says they earned stays earned.
  static const String prefsKey = 'cosmic_trait_contests_v1';

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

/// The notes that once drifted in space, each a true rule of the judging
/// (contest_judging.dart). They can no longer be found, but a save remembers
/// the ids of those that were ('cosmic_trait_hint_notes_v1'), and the
/// profile still shows them, so the ids and their order stay put.
const List<CosmicContestHintLore> kCosmicContestHintLore = [
  CosmicContestHintLore(
    id: 'fast_elements_1',
    text:
        'A track steward\'s note: "Lightning runs fastest, then water and ice. Mud is slowest of all."',
  ),
  CosmicContestHintLore(
    id: 'fast_family_wing',
    text: 'A racer\'s chalk mark: "Wings are built for speed. Horns are not."',
  ),
  CosmicContestHintLore(
    id: 'fast_family_let',
    text:
        'A pit-lane scrap: "Small frames are nimble on the track. Big ones are heavy."',
  ),
  CosmicContestHintLore(
    id: 'fast_nature_swift',
    text:
        'A telemetry card: "Swift and Hyperbolic natures raise speed itself."',
  ),
  CosmicContestHintLore(
    id: 'fast_pure_lightning',
    text:
        'A storm etching: "A line bred pure to a fast element keeps its pace."',
  ),
  CosmicContestHintLore(
    id: 'beauty_elements_1',
    text:
        'A polished shard: "Crystal and light catch the judges\' eye. Poison and blood do not."',
  ),
  CosmicContestHintLore(
    id: 'beauty_prismatic',
    text:
        'An engraved plate: "A prismatic coat counts for a great deal wherever looks are judged."',
  ),
  CosmicContestHintLore(
    id: 'beauty_variant',
    text:
        'A stage memo: "Rare variants, unusual tints and a glow about them all sway the judges."',
  ),
  CosmicContestHintLore(
    id: 'beauty_pure_element',
    text:
        'A velvet ribbon: "At a show of purebreds, pure lines are judged above all."',
  ),
  CosmicContestHintLore(
    id: 'beauty_species_pure',
    text:
        'A critic\'s ledger: "A creature bred true to its own kind is judged more kindly."',
  ),
  CosmicContestHintLore(
    id: 'beauty_nature',
    text:
        'A perfume card: "Elegant and Resplendent natures raise beauty itself."',
  ),
  CosmicContestHintLore(
    id: 'strength_elements_1',
    text:
        'A basalt tablet: "Earth is strongest, then lava and fire. Air is weakest."',
  ),
  CosmicContestHintLore(
    id: 'strength_size',
    text:
        'A field memo: "Big frames carry mass. On a tall wall, size counts most."',
  ),
  CosmicContestHintLore(
    id: 'speed_family',
    text:
        'A smudged journal: "On the turns, kin, pips and lets take the corners. Wings overshoot them."',
  ),
  CosmicContestHintLore(
    id: 'intelligence_lineage',
    text:
        'A cipher strip: "Many kinds of blood in a line make a sharper mind."',
  ),
  CosmicContestHintLore(
    id: 'intelligence_elements_1',
    text:
        'A library scrap: "Spirit, light, dark and crystal are sharpest. Lava and mud are muddled."',
  ),
  CosmicContestHintLore(
    id: 'beauty_bad_elements',
    text:
        'A critic\'s card: "On a night with no moon, what shines by its own light shows best: light, fire and lightning."',
  ),
  CosmicContestHintLore(
    id: 'speed_bad_elements',
    text:
        'A track warning: "When it rains, water and ice glide. Fire and earth bog down."',
  ),
  CosmicContestHintLore(
    id: 'strength_family',
    text: 'A coach\'s note: "Horns and manes are the strongest lines."',
  ),
  CosmicContestHintLore(
    id: 'strength_nature',
    text:
        'A cracked plate: "Mighty and Titanic natures raise strength itself."',
  ),
  CosmicContestHintLore(
    id: 'strength_pure_line',
    text:
        'A quarry note: "A hot wall suits fire and lava. Ice and plants wilt in the heat."',
  ),
  CosmicContestHintLore(
    id: 'intelligence_family',
    text: 'A margin note: "Masks and kin are the sharpest lines."',
  ),
  CosmicContestHintLore(
    id: 'intelligence_nature_clever',
    text:
        'A librarian\'s tag: "Clever and Noetic natures raise intelligence itself."',
  ),
  CosmicContestHintLore(
    id: 'intelligence_nature_neuroadaptive',
    text:
        'A neural sketch: "In the harder tests of wits, crystal and masks see the pattern first."',
  ),
  CosmicContestHintLore(
    id: 'intelligence_species_pure',
    text:
        'A sealed thesis: "On a sheer wall, technique beats bulk. Kin, masks and pips find the holds."',
  ),
  CosmicContestHintLore(
    id: 'cross_trait_purity',
    text:
        'A folded card: "Under moonlight, silver, blue and shadow are lovely. Fire and light look harsh."',
  ),
  CosmicContestHintLore(
    id: 'speed_storm',
    text:
        'A singed flag: "In a storm, lightning and air ride the weather, and wings with them."',
  ),
  CosmicContestHintLore(
    id: 'intelligence_insight',
    text:
        'A torn page: "In the hardest tests of wits, what a creature is made of counts nearly double."',
  ),
  CosmicContestHintLore(
    id: 'contest_finals',
    text:
        'A gilt programme: "On the grandest courses, everything that counts counts for more."',
  ),
  CosmicContestHintLore(
    id: 'contest_no_luck',
    text:
        'A judge\'s rule card: "There is no luck in the Trials. Lose, and try another of your Alchemons."',
  ),
];

/// A note adrift in open space: one of [kCosmicContestHintLore], where it
/// lies, and whether the ship has taken it. Flown through, it is kept (its
/// words shown, and listed on the profile's COSMIC NOTES).
class CosmicLoreNote {
  CosmicLoreNote({
    required this.id,
    required this.text,
    required this.position,
    this.collected = false,
  });

  final String id;
  final String text;
  final Offset position;
  bool collected;

  /// How near the ship takes it.
  static const double interactRadius = 90.0;
}

/// Scatters the notes through open space, clear of [obstacles] and of each
/// other — each where it always lay for a given world (the same seed mix,
/// margins and spacing as before the contests were retired).
List<CosmicLoreNote> generateCosmicLoreNotes({
  required int seed,
  required Size worldSize,
  required List<Offset> obstacles,
}) {
  final rng = Random(seed ^ 0xCC7712);
  const margin = 1800.0;
  const minObstacleDist = 1500.0;
  const minNoteDist = 1200.0;
  final out = <CosmicLoreNote>[];
  for (final lore in kCosmicContestHintLore) {
    Offset pos;
    var tries = 0;
    do {
      pos = Offset(
        margin + rng.nextDouble() * (worldSize.width - margin * 2),
        margin + rng.nextDouble() * (worldSize.height - margin * 2),
      );
      tries++;
    } while (tries < 500 &&
        (obstacles.any((o) => (o - pos).distance < minObstacleDist) ||
            out.any((h) => (h.position - pos).distance < minNoteDist)));
    out.add(CosmicLoreNote(id: lore.id, text: lore.text, position: pos));
  }
  return out;
}

/// The note ids a save remembers, in their comma-separated form.
String serialiseContestHintIds(Set<String> ids) =>
    (ids.toList()..sort()).join(',');

/// The note ids a save remembers, from their comma-separated form.
Set<String> deserialiseContestHintIds(String raw) {
  if (raw.isEmpty) return {};
  return raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
}
