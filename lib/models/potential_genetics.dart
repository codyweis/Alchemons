import 'dart:math';

import 'package:alchemons/models/stat_system.dart';

/// The four heritable stat axes as one addressable type. The stat columns
/// predate this and are still spelled out individually everywhere; this lets
/// genetics talk about "a stat" without repeating itself four times.
enum StatKind {
  speed('speed', 'Speed'),
  intelligence('intelligence', 'Intelligence'),
  strength('strength', 'Strength'),
  beauty('beauty', 'Beauty');

  const StatKind(this.id, this.label);

  final String id;
  final String label;

  static StatKind? byId(String? id) {
    if (id == null) return null;
    final key = id.trim().toLowerCase();
    for (final kind in StatKind.values) {
      if (kind.id == key) return kind;
    }
    return null;
  }
}

/// The two stats an Alchemon passes down most reliably.
///
/// Every Alchemon has exactly two, fixed at birth. A Dominant stat leans
/// harder on its parent and rolls a stranger less often; it never changes the
/// value that gets copied. Two of four means no creature, however good, is a
/// clean source for everything it has.
class DominantStats {
  final StatKind first;
  final StatKind second;

  const DominantStats._(this.first, this.second);

  factory DominantStats(StatKind a, StatKind b) {
    if (a == b) {
      // A pair must name two different stats; take the next axis rather than
      // silently collapsing to a single Dominant.
      final other = StatKind.values.firstWhere((k) => k != a);
      return DominantStats._(a, other);
    }
    return a.index <= b.index ? DominantStats._(a, b) : DominantStats._(b, a);
  }

  bool contains(StatKind stat) => stat == first || stat == second;

  List<StatKind> get all => [first, second];

  /// Stable storage form: "speed,strength".
  String encode() => '${first.id},${second.id}';

  static DominantStats? decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parts = raw
        .split(',')
        .map(StatKind.byId)
        .whereType<StatKind>()
        .toList(growable: false);
    if (parts.length < 2) return null;
    return DominantStats(parts[0], parts[1]);
  }

  /// The fallback for wild spawns, vial hatches and pre-Dominants saves: an
  /// Alchemon is Dominant in whatever it is already best at. Deterministic, so
  /// the same creature never resolves two different ways.
  factory DominantStats.fromPotentials({
    required num speed,
    required num intelligence,
    required num strength,
    required num beauty,
  }) {
    final ranked = <MapEntry<StatKind, num>>[
      MapEntry(StatKind.speed, speed),
      MapEntry(StatKind.intelligence, intelligence),
      MapEntry(StatKind.strength, strength),
      MapEntry(StatKind.beauty, beauty),
    ]..sort((a, b) {
      final byValue = b.value.compareTo(a.value);
      // Ties resolve by declaration order so the result is stable.
      return byValue != 0 ? byValue : a.key.index.compareTo(b.key.index);
    });
    return DominantStats(ranked[0].key, ranked[1].key);
  }

  @override
  bool operator ==(Object other) =>
      other is DominantStats && other.first == first && other.second == second;

  @override
  int get hashCode => Object.hash(first, second);

  @override
  String toString() => 'DominantStats(${first.id}, ${second.id})';
}

/// Every number the Potential and Nature inheritance model uses, in one place,
/// so balancing never means editing logic.
abstract final class GeneticsTuning {
  // Recipe hit: the pairing produced a family from an authored recipe that
  // neither parent belonged to. This is the only way a bloodline climbs.
  static const double hitParentShare = 0.35;
  static const double hitDominantBonus = 0.15;
  static const double hitBothDominantBonus = 0.07;

  /// A recipe hit rolls its stranger from this fraction of the better parent
  /// up to 100, which is what lets a line exceed its own stock.
  static const double hitStrangerFloor = 0.60;

  // Miss: same family, or no authored recipe for the pairing. Shuffles what
  // you already have and cannot improve on it.
  static const double missParentShare = 0.20;
  static const double missDominantBonus = 0.12;
  static const double missBothDominantBonus = 0.06;

  /// A miss caps its stranger roll at the better parent, so hatching in volume
  /// off mediocre stock stops being a way to fish for high Potential.
  static const bool missStrangerCappedAtParents = true;

  // Nature. Hits pass parent Natures harder; misses keep today's odds.
  static const double hitNatureParentShare = 0.45;
  static const double missNatureParentShare = 0.35;

  /// Odds one of the child's two Dominant slots lands on a stat neither parent
  /// was Dominant in. Keeps lines from ossifying.
  static const double dominantDriftChance = 0.12;
}

/// Potential inheritance, per stat, independently.
///
/// Keeps the original three-way shape — parent A, parent B, or a stranger
/// roll — and changes only how the shares are weighted and how far the
/// stranger is allowed to reach.
abstract final class PotentialGenetics {
  /// Parent shares for one stat. Whatever is left over is the stranger roll.
  static ({double a, double b}) parentShares({
    required bool recipeHit,
    required bool aDominant,
    required bool bDominant,
  }) {
    final base = recipeHit
        ? GeneticsTuning.hitParentShare
        : GeneticsTuning.missParentShare;
    final solo = recipeHit
        ? GeneticsTuning.hitDominantBonus
        : GeneticsTuning.missDominantBonus;
    final both = recipeHit
        ? GeneticsTuning.hitBothDominantBonus
        : GeneticsTuning.missBothDominantBonus;

    var a = base;
    var b = base;
    if (aDominant && bDominant) {
      a += both;
      b += both;
    } else if (aDominant) {
      a += solo;
    } else if (bDominant) {
      b += solo;
    }
    return (a: a, b: b);
  }

  /// The inclusive range a stranger roll may land in.
  ///
  /// A hit reaches 100, so a recipe pairing can exceed both parents. A miss
  /// stops at the better parent, so a clutch bred off poor stock can never
  /// fish up something better than the stock itself.
  static ({int lo, int hi}) strangerRange({
    required bool recipeHit,
    required num parentA,
    required num parentB,
  }) {
    final best = max(
      AlchemonStatSystem.normalizePotential(parentA),
      AlchemonStatSystem.normalizePotential(parentB),
    );
    if (recipeHit) {
      final lo = (best * GeneticsTuning.hitStrangerFloor).round().clamp(
        1,
        AlchemonStatSystem.maxPotential,
      );
      return (lo: lo, hi: AlchemonStatSystem.maxPotential);
    }
    if (!GeneticsTuning.missStrangerCappedAtParents) {
      return (lo: 1, hi: AlchemonStatSystem.maxPotential);
    }
    return (lo: 1, hi: best);
  }

  static int inheritPotential(
    Random rng, {
    required num parentA,
    required num parentB,
    required StatKind stat,
    required bool recipeHit,
    DominantStats? dominantsA,
    DominantStats? dominantsB,
  }) {
    final shares = parentShares(
      recipeHit: recipeHit,
      aDominant: dominantsA?.contains(stat) ?? false,
      bDominant: dominantsB?.contains(stat) ?? false,
    );

    final roll = rng.nextDouble();
    if (roll < shares.a) return AlchemonStatSystem.normalizePotential(parentA);
    if (roll < shares.a + shares.b) {
      return AlchemonStatSystem.normalizePotential(parentB);
    }

    final range = strangerRange(
      recipeHit: recipeHit,
      parentA: parentA,
      parentB: parentB,
    );
    final span = range.hi - range.lo + 1;
    return AlchemonStatSystem.normalizePotential(
      range.lo + (span > 1 ? rng.nextInt(span) : 0),
    );
  }

  /// One Dominant drawn from each parent, so pairing two specialists can
  /// produce a child carrying both strengths and a matched line breeds true.
  /// A small drift chance keeps a stat neither parent had reachable.
  static DominantStats inheritDominants(
    Random rng,
    DominantStats? parentA,
    DominantStats? parentB,
  ) {
    if (parentA == null && parentB == null) return _randomPair(rng);
    final a = parentA ?? parentB!;
    final b = parentB ?? parentA!;

    var first = a.all[rng.nextInt(2)];
    var second = b.all[rng.nextInt(2)];

    if (first == second) {
      // Both parents offered the same stat. Exhaust what they carry between
      // them before reaching outside the pair.
      final pool = <StatKind>{...a.all, ...b.all}..remove(first);
      second = pool.isNotEmpty
          ? pool.elementAt(rng.nextInt(pool.length))
          : StatKind.values.firstWhere((k) => k != first);
    }

    if (rng.nextDouble() < GeneticsTuning.dominantDriftChance) {
      final outside = StatKind.values
          .where((k) => k != first && k != second)
          .toList(growable: false);
      if (outside.isNotEmpty) {
        final drifted = outside[rng.nextInt(outside.length)];
        if (rng.nextBool()) {
          first = drifted;
        } else {
          second = drifted;
        }
      }
    }

    return DominantStats(first, second);
  }

  static DominantStats _randomPair(Random rng) {
    final pool = List<StatKind>.from(StatKind.values)..shuffle(rng);
    return DominantStats(pool[0], pool[1]);
  }
}
