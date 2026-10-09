// lib/games/cosmic/contest_judging.dart
//
// How a trait contest is judged. Pure rules, no chance: the same Alchemon
// against the same level always scores the same, so a player can learn what
// works by trying — lightning is quick, horns are strong, crystal catches the
// eye, spirit is sharp — and the scorecard shows exactly what counted.
//
// A score is the creature's trait stat (rated 1–5) plus what it brings to the
// trait: its element, its family, its frame, its looks or its lineage. Each
// level adds a condition that tilts those — a wet lane favours water, a
// leverage bout favours technique over bulk — so a different creature can be
// the right one for a different level. The rival is judged by the same rules
// on its element and family, at half weight, over its own fixed strength.

import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/models/elemental_group.dart';

/// What the judges can see of an entrant.
class ContestEntrant {
  const ContestEntrant({
    required this.name,
    required this.element,
    required this.family,
    required this.statRating,
    this.scale = 1,
    this.prismatic = false,
    this.effect,
    this.variant = false,
    this.tinted = false,
    this.pureElement,
    this.pureFamily,
    this.speciesPure = false,
    this.elementKinds = 0,
    this.factionKinds = 0,
    this.familyKinds = 0,
    this.generations = 0,
  });

  final String name;

  /// 'Fire', 'Water', … and 'wing', 'horn', … (case is normalised here).
  final String element, family;

  /// The trait's stat on the 1–5 gameplay rating.
  final double statRating;

  /// Its size: 1 is ordinary, under 1 small, over 1 large.
  final double scale;

  /// Looks.
  final bool prismatic, variant, tinted;

  /// Its alchemy effect id, if it wears one ('prismatic_cascade', …).
  final String? effect;

  /// The one element / family in its whole line, if it has only one.
  final String? pureElement, pureFamily;

  /// Bred only from its own species.
  final bool speciesPure;

  /// How many kinds of element, faction and family run in its line, and how
  /// many generations deep it goes.
  final int elementKinds, factionKinds, familyKinds, generations;
}

/// One thing the judges counted, and by how much (positive helps).
class ContestFactor {
  const ContestFactor(this.text, this.delta);
  final String text;
  final double delta;
}

class ContestVerdict {
  const ContestVerdict(this.score, this.factors);
  final double score;

  /// What moved the score, biggest first. The stat is not among them.
  final List<ContestFactor> factors;
}

/// A level's condition: how it tilts the judging.
class ContestCondition {
  const ContestCondition({
    required this.title,
    required this.line,
    this.elementAdd = const {},
    this.familyAdd = const {},
    this.good = '',
    this.bad = '',
    this.elementMul = 1,
    this.familyMul = 1,
    this.sizeMul = 1,
    this.lookMul = 1,
    this.purityMul = 1,
    this.lineageMul = 1,
    this.contrast = false,
    this.allMul = 1,
  });

  /// What the arena calls it, and one line of what it is.
  final String title, line;

  /// Extra for (or against) elements and families under this condition,
  /// and how a line about it reads ("glides in the wet" / "bogs down").
  final Map<String, double> elementAdd, familyAdd;
  final String good, bad;

  /// How much each of the trait's usual factors counts here.
  final double elementMul, familyMul, sizeMul, lookMul, purityMul, lineageMul;

  /// Beauty: the judges reward a look that stands apart from the rival's.
  final bool contrast;

  /// The finals: everything counts this much more.
  final double allMul;
}

/// The condition at [trait]'s [level] (1–5).
ContestCondition contestCondition(CosmicContestTrait trait, int level) {
  final list = _conditions[trait]!;
  return list[(level - 1).clamp(0, list.length - 1)];
}

const Map<CosmicContestTrait, List<ContestCondition>> _conditions = {
  CosmicContestTrait.beauty: [
    ContestCondition(title: 'DEBUT', line: 'The judges want to see you.'),
    ContestCondition(
      title: 'CONTRAST',
      line: 'Stand apart from the rival and be seen.',
      contrast: true,
    ),
    ContestCondition(
      title: 'MOONLIGHT',
      line: 'Only cool light tonight: silver, blue and shadow.',
      elementAdd: {
        'Ice': 0.4,
        'Water': 0.35,
        'Spirit': 0.35,
        'Dark': 0.45,
        'Crystal': 0.1,
        'Fire': -0.35,
        'Lava': -0.35,
        'Light': -0.3,
        'Lightning': -0.15,
      },
      good: 'lovely in the moonlight',
      bad: 'too harsh by moonlight',
    ),
    ContestCondition(
      title: 'PURE LINES',
      line: 'The judges prize a clean bloodline.',
      purityMul: 2.5,
    ),
    ContestCondition(
      title: 'GRAND GALA',
      line: 'The finest show. Everything counts for more.',
      contrast: true,
      allMul: 1.5,
    ),
  ],
  CosmicContestTrait.speed: [
    ContestCondition(title: 'OPEN SPRINT', line: 'A clear track. Pure pace.'),
    ContestCondition(
      title: 'WET LANE',
      line: 'Rain on the track tonight.',
      elementAdd: {
        'Water': 0.42,
        'Ice': 0.42,
        'Steam': 0.28,
        'Fire': -0.35,
        'Lava': -0.35,
        'Earth': -0.28,
        'Mud': -0.21,
        'Dust': -0.28,
      },
      good: 'glides in the wet',
      bad: 'bogs down in the wet',
      sizeMul: 1.5,
    ),
    ContestCondition(
      title: 'STORM LANE',
      line: 'Lightning walks the track.',
      elementAdd: {'Lightning': 0.49, 'Air': 0.42, 'Earth': -0.14},
      familyAdd: {'wing': 0.21},
      good: 'rides the storm',
      bad: 'grounded by the storm',
    ),
    ContestCondition(
      title: 'SWITCHBACK',
      line: 'Tight turns all the way round.',
      familyAdd: {'kin': 0.35, 'pip': 0.35, 'let': 0.28, 'wing': -0.21},
      good: 'takes the turns',
      bad: 'overshoots the turns',
      sizeMul: 2,
    ),
    ContestCondition(
      title: 'GRAND CIRCUIT',
      line: 'The long race. Everything counts for more.',
      allMul: 1.5,
    ),
  ],
  CosmicContestTrait.strength: [
    ContestCondition(title: 'THE SHOVE', line: 'Drive the bead to the rival.'),
    ContestCondition(
      title: 'MOLTEN RING',
      line: 'The anvil burns hot today.',
      elementAdd: {
        'Fire': 0.42,
        'Lava': 0.42,
        'Ice': -0.42,
        'Water': -0.28,
        'Plant': -0.35,
        'Air': -0.21,
      },
      good: 'at home in the heat',
      bad: 'wilts in the heat',
    ),
    ContestCondition(
      title: 'HEAVYWEIGHT',
      line: 'No weight classes tonight.',
      sizeMul: 2.5,
    ),
    ContestCondition(
      title: 'LEVERAGE',
      line: 'Technique over bulk.',
      familyAdd: {'kin': 0.42, 'mask': 0.35, 'pip': 0.28},
      good: 'finds the angle',
      bad: '',
      familyMul: 0.4,
      sizeMul: 0.3,
    ),
    ContestCondition(
      title: 'TITAN BOUT',
      line: 'The heaviest bout. Everything counts for more.',
      allMul: 1.5,
    ),
  ],
  CosmicContestTrait.intelligence: [
    ContestCondition(title: 'RIDDLES', line: 'Simple riddles to start.'),
    ContestCondition(
      title: 'MEMORY',
      line: 'Long sequences to hold in mind.',
      familyAdd: {'kin': 0.35, 'pip': 0.35},
      good: 'holds the sequence',
      bad: '',
      lineageMul: 2,
    ),
    ContestCondition(
      title: 'PATTERNS',
      line: 'Shapes that repeat, then break.',
      elementAdd: {'Crystal': 0.42, 'Ice': 0.21, 'Lightning': 0.14},
      familyAdd: {'mask': 0.35},
      good: 'sees the pattern',
      bad: '',
    ),
    ContestCondition(
      title: 'INSIGHT',
      line: 'Questions with no clear answer.',
      elementMul: 1.8,
    ),
    ContestCondition(
      title: 'GRAND COLLOQUIUM',
      line: 'The last debate. Everything counts for more.',
      allMul: 1.5,
    ),
  ],
};

// ── the trait's usual factors ───────────────────────────────────────────────

const Map<CosmicContestTrait, Map<String, double>> kContestElementWeights = {
  CosmicContestTrait.beauty: {
    'Crystal': 0.32,
    'Light': 0.26,
    'Spirit': 0.18,
    'Ice': 0.17,
    'Fire': 0.15,
    'Air': 0.12,
    'Steam': 0.10,
    'Plant': 0.08,
    'Mud': -0.14,
    'Blood': -0.24,
    'Poison': -0.30,
  },
  CosmicContestTrait.speed: {
    'Lightning': 0.34,
    'Water': 0.26,
    'Ice': 0.23,
    'Air': 0.18,
    'Steam': 0.14,
    'Lava': -0.13,
    'Earth': -0.16,
    'Mud': -0.28,
  },
  CosmicContestTrait.strength: {
    'Earth': 0.34,
    'Lava': 0.29,
    'Fire': 0.23,
    'Mud': 0.16,
    'Crystal': 0.12,
    'Blood': 0.10,
    'Water': -0.11,
    'Air': -0.19,
  },
  CosmicContestTrait.intelligence: {
    'Spirit': 0.30,
    'Light': 0.25,
    'Dark': 0.22,
    'Crystal': 0.19,
    'Air': 0.11,
    'Water': 0.08,
    'Blood': -0.09,
    'Mud': -0.13,
    'Lava': -0.16,
  },
};

const Map<CosmicContestTrait, Map<String, double>> kContestFamilyWeights = {
  CosmicContestTrait.beauty: {'mask': 0.12, 'wing': 0.07, 'kin': 0.05},
  CosmicContestTrait.speed: {
    'wing': 0.18,
    'let': 0.07,
    'kin': 0.06,
    'horn': -0.08,
  },
  CosmicContestTrait.strength: {
    'horn': 0.16,
    'mane': 0.14,
    'kin': 0.06,
    'let': -0.06,
  },
  CosmicContestTrait.intelligence: {'mask': 0.14, 'kin': 0.12, 'pip': 0.06},
};

/// How an element or family line reads for each trait.
const Map<CosmicContestTrait, (String, String)> _traitWords = {
  CosmicContestTrait.beauty: ('catches the eye', 'dulls the eye'),
  CosmicContestTrait.speed: ('quick', 'slow'),
  CosmicContestTrait.strength: ('powerful', 'light in the shove'),
  CosmicContestTrait.intelligence: ('sharp', 'muddled'),
};

const Map<String, String> _effectNames = {
  'beauty_radiance': 'BEAUTY RADIANCE',
  'speed_flux': 'SPEED FLUX',
  'strength_forge': 'STRENGTH FORGE',
  'intelligence_halo': 'INTELLIGENCE HALO',
};

const Map<CosmicContestTrait, String> _traitEffect = {
  CosmicContestTrait.beauty: 'beauty_radiance',
  CosmicContestTrait.speed: 'speed_flux',
  CosmicContestTrait.strength: 'strength_forge',
  CosmicContestTrait.intelligence: 'intelligence_halo',
};

String _cap(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

ElementalGroup? _groupOf(String element) {
  for (final g in ElementalGroup.values) {
    if (g.elementTypes.contains(element)) return g;
  }
  return null;
}

/// The most the bonuses can add or take away.
const double kContestBonusFloor = -1.2, kContestBonusCeiling = 1.4;

/// The highest a contest score can go.
const double kContestScoreMax = 6.85;

/// Judges [e] at [trait]'s [level]. [rivalElement] is the rival's, for the
/// contrast rounds.
ContestVerdict judgeEntrant(
  CosmicContestTrait trait,
  int level,
  ContestEntrant e, {
  String? rivalElement,
}) {
  final c = contestCondition(trait, level);
  final element = _cap(e.element);
  final family = e.family.toLowerCase().trim();
  final factors = <ContestFactor>[];
  void add(String text, double delta) {
    final d = delta * c.allMul;
    if (d.abs() >= 0.02) factors.add(ContestFactor(text, d));
  }

  final (good, bad) = _traitWords[trait]!;

  // Element: what the trait thinks of it, then the condition.
  final base = (kContestElementWeights[trait]![element] ?? 0) * c.elementMul;
  final extra = c.elementAdd[element] ?? 0;
  if (extra != 0) {
    add(
      '${element.toUpperCase()} · ${extra > 0 ? c.good : c.bad}',
      base + extra,
    );
  } else if (base != 0) {
    add('${element.toUpperCase()} · ${base > 0 ? good : bad}', base);
  }

  // Family.
  final fBase = (kContestFamilyWeights[trait]![family] ?? 0) * c.familyMul;
  final fExtra = c.familyAdd[family] ?? 0;
  final familyName = '${family.toUpperCase()} LINE';
  if (fExtra != 0 && (fExtra > 0 ? c.good : c.bad).isNotEmpty) {
    add('$familyName · ${fExtra > 0 ? c.good : c.bad}', fBase + fExtra);
  } else if (fBase + fExtra != 0) {
    add('$familyName · ${fBase + fExtra > 0 ? good : bad}', fBase + fExtra);
  }

  // Frame.
  final small = (1 - e.scale).clamp(0.0, 0.35);
  final large = (e.scale - 1).clamp(0.0, 0.55);
  switch (trait) {
    case CosmicContestTrait.speed:
      if (small > 0) add('SMALL FRAME · NIMBLE', small * 0.55 * c.sizeMul);
      if (large > 0) add('BIG FRAME · HEAVY', -large * 0.4 * c.sizeMul);
    case CosmicContestTrait.strength:
      if (large > 0) add('BIG FRAME · MASS', large * 0.7 * c.sizeMul);
      if (small > 0) add('SMALL FRAME · LIGHT', -small * 0.4 * c.sizeMul);
    case CosmicContestTrait.beauty:
    case CosmicContestTrait.intelligence:
      break;
  }

  // Looks.
  if (trait == CosmicContestTrait.beauty) {
    final m = c.lookMul;
    if (e.prismatic) add('PRISMATIC COAT', 0.24 * m);
    if (e.effect == 'prismatic_cascade') add('PRISMATIC CASCADE', 0.18 * m);
    if (e.effect == 'alchemy_glow' || e.effect == 'elemental_aura') {
      add('A GLOW ABOUT IT', 0.09 * m);
    }
    if (e.variant) add('RARE VARIANT', 0.12 * m);
    if (e.tinted) add('UNUSUAL TINT', 0.05 * m);
    if (c.contrast && rivalElement != null) {
      final rival = _cap(rivalElement);
      if (rival == element) {
        add('SAME COLORS AS THE RIVAL', -0.3);
      } else if (_groupOf(rival) != null &&
          _groupOf(rival) == _groupOf(element)) {
        add('MUCH LIKE THE RIVAL', -0.12);
      } else {
        add('STANDS APART FROM THE RIVAL', 0.35);
      }
    }
  }

  // The trait's own mastery effect.
  if (e.effect == _traitEffect[trait]) add(_effectNames[e.effect]!, 0.15);

  // Lineage: a mind is sharpened by many kinds of blood behind it.
  if (trait == CosmicContestTrait.intelligence) {
    final depth =
        e.elementKinds.clamp(0, 6) * 0.024 +
        e.factionKinds.clamp(0, 6) * 0.026 +
        e.familyKinds.clamp(0, 6) * 0.02 +
        e.generations.clamp(0, 12) * 0.011;
    if (depth > 0) add('MIXED LINEAGE · MANY PATTERNS', depth * c.lineageMul);
  }

  // Purity: a line kept true to an element or family the trait favours.
  final pureEl = e.pureElement == null ? null : _cap(e.pureElement!);
  if (pureEl != null) {
    final aligned = kContestElementWeights[trait]![pureEl] ?? 0;
    if (aligned > 0) {
      add(
        'PURE ${pureEl.toUpperCase()} LINE',
        (0.04 + aligned * 0.28) * c.purityMul,
      );
    } else if (trait == CosmicContestTrait.beauty) {
      add('PURE LINE', 0.08 * c.purityMul);
    }
  }
  final pureFam = e.pureFamily?.toLowerCase().trim();
  if (pureFam != null && pureFam.isNotEmpty) {
    final aligned = kContestFamilyWeights[trait]![pureFam] ?? 0;
    if (aligned > 0) {
      add(
        'PURE ${pureFam.toUpperCase()} LINE',
        (0.03 + aligned * 0.26) * c.purityMul,
      );
    }
  }
  if (trait == CosmicContestTrait.beauty && e.speciesPure) {
    add('TRUE TO ITS KIND', 0.08 * c.purityMul);
  }

  final bonus = factors
      .fold<double>(0, (s, f) => s + f.delta)
      .clamp(kContestBonusFloor, kContestBonusCeiling);
  factors.sort((a, b) => b.delta.abs().compareTo(a.delta.abs()));
  return ContestVerdict(
    (e.statRating + bonus).clamp(0.0, kContestScoreMax).toDouble(),
    factors,
  );
}

/// Judges the rival of [trait]'s [level]: its own strength, and its element
/// and family under the same rules at half weight.
ContestVerdict judgeRival(
  CosmicContestTrait trait,
  int level,
  CosmicContestOpponent rival,
) {
  final v = judgeEntrant(
    trait,
    level,
    ContestEntrant(
      name: rival.name,
      element: rival.element,
      family: rival.family,
      statRating: 0,
    ),
  );
  final factors = [
    for (final f in v.factors) ContestFactor(f.text, f.delta * 0.5),
  ];
  final bonus = factors.fold<double>(0, (s, f) => s + f.delta);
  return ContestVerdict(
    (rival.targetScore + bonus).clamp(0.0, kContestScoreMax).toDouble(),
    factors,
  );
}
