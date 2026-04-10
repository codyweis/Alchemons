import 'dart:io';
import 'dart:math' as math;

// Mirrors PurebloodRiteService._generateWeeklyChallenge logic exactly.

const families = ['Let', 'Pip', 'Mane', 'Mask', 'Horn', 'Wing', 'Kin'];

const allElements = [
  'Fire',
  'Water',
  'Earth',
  'Air',
  'Steam',
  'Lava',
  'Lightning',
  'Mud',
  'Ice',
  'Dust',
  'Crystal',
  'Plant',
  'Poison',
  'Spirit',
  'Dark',
  'Light',
  'Blood',
];

// A simplified element pool per family (representative subset, not full catalog).
const familyElements = {
  'Let': [
    'Fire',
    'Water',
    'Air',
    'Lightning',
    'Mud',
    'Ice',
    'Dark',
    'Light',
    'Blood',
  ],
  'Pip': ['Lava', 'Fire', 'Blood', 'Poison', 'Earth', 'Steam'],
  'Mane': ['Steam', 'Ice', 'Fire', 'Air', 'Water', 'Crystal'],
  'Mask': ['Ice', 'Dark', 'Spirit', 'Dust', 'Poison'],
  'Horn': ['Lightning', 'Air', 'Fire', 'Poison', 'Light'],
  'Wing': ['Plant', 'Air', 'Crystal', 'Spirit', 'Light'],
  'Kin': ['Earth', 'Water', 'Fire', 'Dark', 'Air'],
};

const sizes = ['tiny', 'small', 'large', 'giant'];
const tints = ['warm', 'cool', 'vibrant', 'pale', 'albino'];
const natures = [
  'Metabolic',
  'Reproductive',
  'Ecophysiological',
  'Sympatric',
  'Conspecific',
  'Homotypic',
  'Heterotypic',
  'Precocial',
  'Neuroadaptive',
  'Swift',
  'Clever',
  'Mighty',
  'Elegant',
  'Homeostatic',
  'Placidal',
  'Dormant',
  'Apathetic',
  'Nullic',
];
const variantFactions = ['volcanic', 'oceanic', 'verdant', 'earthen', 'arcane'];

String labelize(String v) =>
    v.isEmpty ? '' : v[0].toUpperCase() + v.substring(1).toLowerCase();

String tintLabel(String v) {
  switch (v.toLowerCase()) {
    case 'warm':
      return 'Thermal';
    case 'cool':
      return 'Cryogenic';
    default:
      return labelize(v);
  }
}

int goldReward({
  required String? element,
  required bool speciesPurity,
  required String? size,
  required String? tint,
  required String? nature,
  required String? variantFaction,
}) {
  int d = 0;
  if (element != null) {
    d += 1;
  }
  d += 1; // elemental purity always required
  if (speciesPurity) {
    d += 1;
  }
  if (size == 'tiny' || size == 'giant') {
    d += 2;
  } else if (size != null) {
    d += 1;
  }
  if (tint == 'albino') {
    d += 2;
  } else if (tint != null) {
    d += 1;
  }
  if (nature != null) {
    d += 1;
  }
  if (variantFaction != null) {
    return 10;
  }
  return (d + 2).clamp(5, 9);
}

String buildTitle({
  required String family,
  required String? element,
  required bool speciesPurity,
  required String? size,
  required String? tint,
  required String? nature,
  required String? variantFaction,
}) {
  final parts = <String>[];
  if (speciesPurity) parts.add('Pure');
  if (size != null) parts.add(labelize(size));
  if (tint != null) parts.add(tintLabel(tint));
  if (nature != null) parts.add(labelize(nature));
  if (variantFaction != null) parts.add('${labelize(variantFaction)} Variant');
  if (element != null) {
    parts.add('$element$family');
  } else {
    parts.add(family);
  }
  return parts.join(' ');
}

void generate(int seed, String weekLabel) {
  final rng = math.Random(seed);

  final family = families[rng.nextInt(families.length)];
  final elementsList = List<String>.from(familyElements[family]!)..sort();
  final requiredElement = elementsList[rng.nextInt(elementsList.length)];

  final pool = ['speciesPurity', 'size', 'tint', 'nature', 'variant'];
  // Fisher-Yates shuffle
  for (var i = pool.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final tmp = pool[i];
    pool[i] = pool[j];
    pool[j] = tmp;
  }

  bool speciesPurity = false;
  String? size;
  String? tint;
  String? nature;
  String? variantFaction;

  const extraPickOdds = [1.0, 0.65, 0.40, 0.20, 0.0];
  int picked = 0;
  for (final option in pool) {
    if (picked >= extraPickOdds.length) break;
    final odds = extraPickOdds[picked];
    if (odds <= 0.0 || (picked > 0 && rng.nextDouble() >= odds)) continue;
    switch (option) {
      case 'speciesPurity':
        speciesPurity = true;
      case 'size':
        size = sizes[rng.nextInt(sizes.length)];
      case 'tint':
        tint = tints[rng.nextInt(tints.length)];
      case 'nature':
        nature = natures[rng.nextInt(natures.length)];
      case 'variant':
        variantFaction = variantFactions[rng.nextInt(variantFactions.length)];
    }
    picked++;
  }

  final gold = goldReward(
    element: requiredElement,
    speciesPurity: speciesPurity,
    size: size,
    tint: tint,
    nature: nature,
    variantFaction: variantFaction,
  );

  final title = buildTitle(
    family: family,
    element: requiredElement,
    speciesPurity: speciesPurity,
    size: size,
    tint: tint,
    nature: nature,
    variantFaction: variantFaction,
  );

  final reqs = <String>[];
  reqs.add('$requiredElement $family — elemental purity required');
  if (speciesPurity) reqs.add('Species purity required');
  if (size != null) reqs.add('Size: ${labelize(size)}');
  if (tint != null) reqs.add('Pigmentation: ${tintLabel(tint)}');
  if (nature != null) reqs.add('Nature: ${labelize(nature)}');
  if (variantFaction != null) reqs.add('Variant: ${labelize(variantFaction)}');

  stdout.writeln('Week $weekLabel  (seed $seed)');
  stdout.writeln('  Title  : $title');
  stdout.writeln('  Reward : +$gold gold');
  stdout.writeln('  Reqs   : ${reqs.join(' / ')}');
  stdout.writeln('');
}

void main() {
  // 5 consecutive weeks starting from Mon 2026-03-30
  generate(20260330, '2026-03-30');
  generate(20260406, '2026-04-06');
  generate(20260413, '2026-04-13');
  generate(20260420, '2026-04-20');
  generate(20260427, '2026-04-27');
}
