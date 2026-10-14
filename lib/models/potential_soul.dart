import 'dart:math';

/// Rules for the rare item that permanently improves one chosen Potential.
abstract final class PotentialSoulRules {
  static const int minGain = 1;
  static const int maxGain = 5;

  static int rollGain(Random rng) => minGain + rng.nextInt(maxGain);

  /// Potential Souls begin appearing only in serious Survival runs and stay
  /// much rarer than Power Orbs because they improve inheritable genetics.
  static bool rollsFromSurvival(int wave, Random rng) {
    final chance = wave >= 50
        ? 0.10
        : wave >= 40
        ? 0.06
        : wave >= 30
        ? 0.03
        : 0.0;
    return chance > 0 && rng.nextDouble() < chance;
  }

  /// Raids are time-gated and are the primary repeatable source of Souls.
  static bool rollsFromRaid(Random rng) => rng.nextDouble() < 0.50;

  /// The most Souls one Alchemon can hold.
  static const int maxPerAlchemon = 10;

  /// What taking one Soul back out costs, in Gold. The Silver paid to put it
  /// in is not returned.
  static const int refundGoldEach = 5;
}

/// The Souls put into one Alchemon: each stat and what it actually added
/// (less than the roll where it met 100). Saved as "speed:3,beauty:5".
class PotentialSoulLedger {
  const PotentialSoulLedger(this.entries);

  static const empty = PotentialSoulLedger([]);

  final List<({String stat, int gain})> entries;

  int get count => entries.length;

  bool get isFull => count >= PotentialSoulRules.maxPerAlchemon;

  /// What the Souls added to [stat], all told.
  int gainIn(String stat) =>
      entries.where((e) => e.stat == stat).fold(0, (sum, e) => sum + e.gain);

  PotentialSoulLedger plus(String stat, int gain) =>
      PotentialSoulLedger([...entries, (stat: stat, gain: gain)]);

  String? encode() => entries.isEmpty
      ? null
      : entries.map((e) => '${e.stat}:${e.gain}').join(',');

  static PotentialSoulLedger decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return empty;
    final out = <({String stat, int gain})>[];
    for (final part in raw.split(',')) {
      final pieces = part.split(':');
      if (pieces.length != 2) continue;
      final gain = int.tryParse(pieces[1].trim());
      if (gain == null) continue;
      out.add((stat: pieces[0].trim(), gain: gain));
    }
    return PotentialSoulLedger(out);
  }
}
