/// What an unbroken bloodline is worth in combat.
///
/// Purity used to be ancestry and nothing else: the pure-breeding tutorial
/// promised stat bonuses, the stat formula had none, and the discrepancy was
/// settled by rewriting the tutorial. This is the bonus that was meant to be
/// there, on the terms the design actually wants — not a flat lift to
/// everything, but a single stat rolled once and kept.
///
/// * **Fully pure** (one element line *and* one species line): +15% to one of
///   the four stats.
/// * **Elementally pure only**: +10% to Beauty or Intelligence — the pair an
///   elemental line reads as.
/// * **Species pure only**: +10% to Speed or Strength — the physical pair a
///   species line reads as.
///
/// The roll is derived from the instance id rather than stored, because stats
/// are recomputed and written back on every load: a roll taken from a plain
/// random source would hand the creature a different bonus every time the app
/// started. It is stable for the life of the creature and reproducible
/// anywhere, which is also what lets an analysis screen show what it rolled
/// without a column to read.
library;

enum PurityStatBonusKind {
  none,

  /// One element line, mixed species.
  elemental,

  /// One species line, mixed elements.
  species,

  /// Both lines unbroken.
  full,
}

/// The four stat keys, spelled the way [natureMultiplier] and the stat
/// derivation spell them.
const String kStatSpeed = 'speed';
const String kStatIntelligence = 'intelligence';
const String kStatStrength = 'strength';
const String kStatBeauty = 'beauty';

/// A fully pure creature may roll any of the four.
const List<String> kFullPurityStatPool = [
  kStatSpeed,
  kStatIntelligence,
  kStatStrength,
  kStatBeauty,
];

/// An elemental line expresses itself in the mind-and-presence pair.
const List<String> kElementalPurityStatPool = [kStatBeauty, kStatIntelligence];

/// A species line expresses itself in the body pair.
const List<String> kSpeciesPurityStatPool = [kStatSpeed, kStatStrength];

const double kFullPurityBonus = 0.15;
const double kPartialPurityBonus = 0.10;

/// One creature's purity bonus: which stat it rolled and what it is worth.
class PurityStatBonus {
  const PurityStatBonus({
    required this.kind,
    required this.statKey,
    required this.bonus,
  });

  static const none = PurityStatBonus(
    kind: PurityStatBonusKind.none,
    statKey: null,
    bonus: 0,
  );

  final PurityStatBonusKind kind;

  /// The stat this creature rolled, or null when its lineage is mixed.
  final String? statKey;

  /// The fraction added, e.g. 0.15 for a fully pure roll.
  final double bonus;

  bool get isNone => kind == PurityStatBonusKind.none;

  /// The multiplier to apply to [key] — 1.0 for every stat but the rolled one.
  double multiplierFor(String key) => statKey == key ? 1.0 + bonus : 1.0;

  /// Player-facing name of the lineage that earned this.
  String get lineageLabel => switch (kind) {
    PurityStatBonusKind.none => 'Mixed Lineage',
    PurityStatBonusKind.elemental => 'Elementally Pure',
    PurityStatBonusKind.species => 'Species Pure',
    PurityStatBonusKind.full => 'Pure',
  };

  /// What an analysis readout shows, e.g. "Pure · +15% Strength".
  String get readout {
    if (isNone || statKey == null) return lineageLabel;
    final stat = statKey![0].toUpperCase() + statKey!.substring(1);
    final percent = (bonus * 100).round();
    return '$lineageLabel · +$percent% $stat';
  }

  @override
  String toString() => 'PurityStatBonus($readout)';
}

/// The bonus for a creature whose lineage is already classified.
///
/// [instanceId] seeds the roll; the same id always rolls the same stat.
PurityStatBonus resolvePurityStatBonus({
  required String instanceId,
  required bool isElementallyPure,
  required bool isSpeciesPure,
}) {
  if (instanceId.isEmpty) return PurityStatBonus.none;

  final (List<String> pool, double bonus, PurityStatBonusKind kind) = switch ((
    isElementallyPure,
    isSpeciesPure,
  )) {
    (true, true) => (
      kFullPurityStatPool,
      kFullPurityBonus,
      PurityStatBonusKind.full,
    ),
    (true, false) => (
      kElementalPurityStatPool,
      kPartialPurityBonus,
      PurityStatBonusKind.elemental,
    ),
    (false, true) => (
      kSpeciesPurityStatPool,
      kPartialPurityBonus,
      PurityStatBonusKind.species,
    ),
    _ => (const <String>[], 0.0, PurityStatBonusKind.none),
  };
  if (pool.isEmpty) return PurityStatBonus.none;

  // Salted per pool so a creature that would roll Beauty as an elemental line
  // does not automatically roll Beauty again if it later reads as fully pure.
  final index = _stableHash('$instanceId:${kind.name}') % pool.length;
  return PurityStatBonus(kind: kind, statKey: pool[index], bonus: bonus);
}

/// FNV-1a, 32-bit.
///
/// Deliberately not `String.hashCode`: that is only promised to be stable
/// within a single run, so a Dart upgrade could silently re-roll every pure
/// creature in every save. This produces the same number forever.
int _stableHash(String value) {
  var hash = 0x811c9dc5;
  for (var i = 0; i < value.length; i++) {
    hash ^= value.codeUnitAt(i);
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}
