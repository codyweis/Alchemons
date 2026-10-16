// lib/games/cosmic_survival/survival_damage_report.dart
//
// Who carried a survival run, for the results: each party member's damage,
// its share of everything the run dealt, its kills and healing, and how long
// it was out. Read off the run's own per-creature tally
// (CosmicSurvivalGame.companionRunStats, the one Family Mastery pays its
// performance share from), so the results and the mastery awards never
// disagree about who did what.

import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';

/// One party member's part in a run.
class SurvivalDamageLine {
  const SurvivalDamageLine({
    required this.slot,
    required this.name,
    required this.element,
    this.imagePath,
    required this.damage,
    required this.kills,
    required this.healing,
    required this.deployed,
    required this.fieldSeconds,
  });

  /// Its slot in the party.
  final int slot;
  final String name;
  final String element;
  final String? imagePath;
  final double damage;
  final int kills;
  final double healing;

  /// Out at some point: summoned, or with anything to its name. False is
  /// "benched" — kept in reserve the whole run.
  final bool deployed;

  /// Seconds out on the field, alive.
  final double fieldSeconds;
}

/// The run's damage, by who dealt it.
class SurvivalDamageReport {
  const SurvivalDamageReport({
    required this.lines,
    this.otherDamage = 0,
    this.otherKills = 0,
  });

  static const empty = SurvivalDamageReport(lines: []);

  /// The whole party, most damage first.
  final List<SurvivalDamageLine> lines;

  /// What no Alchemon dealt: the ship, the orb's own defenses, run perks.
  final double otherDamage;
  final int otherKills;

  bool get isEmpty => lines.isEmpty;

  /// Everything the run dealt.
  double get totalDamage =>
      lines.fold(otherDamage, (sum, line) => sum + line.damage);

  /// [damage]'s share of [totalDamage], 0..1.
  double shareOf(double damage) {
    final total = totalDamage;
    return total <= 0 ? 0 : (damage / total).clamp(0.0, 1.0);
  }

  /// The run's best: the top line, when anyone dealt anything.
  SurvivalDamageLine? get best =>
      lines.isNotEmpty && lines.first.damage > 0 ? lines.first : null;

  /// [game]'s run as it stands.
  factory SurvivalDamageReport.fromGame(CosmicSurvivalGame game) {
    final lines = <SurvivalDamageLine>[];
    var creatureKills = 0;
    for (final (slot, member) in game.party.indexed) {
      final s = game.companionRunStats[slot];
      creatureKills += s?.kills ?? 0;
      lines.add(
        SurvivalDamageLine(
          slot: slot,
          name: member.displayName.isEmpty ? 'Alchemon' : member.displayName,
          element: member.element,
          imagePath: member.imagePath,
          damage: s?.damageDealt ?? 0,
          kills: s?.kills ?? 0,
          healing: s?.healingDone ?? 0,
          // The same test the mastery award uses.
          deployed:
              game.deployedCompanionSlots.contains(slot) ||
              (s != null &&
                  (s.damageDealt > 0 ||
                      s.kills > 0 ||
                      s.healingDone > 0 ||
                      s.damageTaken > 0)),
          fieldSeconds: s?.fieldSeconds ?? 0,
        ),
      );
    }
    // Most damage first; among equals, those that went out before the
    // benched, then party order.
    lines.sort((a, b) {
      final byDamage = b.damage.compareTo(a.damage);
      if (byDamage != 0) return byDamage;
      if (a.deployed != b.deployed) return a.deployed ? -1 : 1;
      return a.slot.compareTo(b.slot);
    });
    return SurvivalDamageReport(
      lines: lines,
      otherDamage: game.stats.otherDamage,
      otherKills: (game.stats.kills - creatureKills).clamp(0, 1 << 30),
    );
  }
}

/// [value] short: 940, 9K, 12.4K, 124K, 3.1M.
String compactAmount(double value) {
  final v = value.isFinite ? value.abs() : 0.0;
  // Thresholds where the shorter form would round up to the next unit.
  if (v >= 999.5e3) return '${_oneDecimal(v / 1e6)}M';
  if (v >= 999.5) return '${_oneDecimal(v / 1e3)}K';
  return v.round().toString();
}

/// 12.4 under 100, whole above it (124K, not 124.3K), and no ".0" (9K).
String _oneDecimal(double v) {
  if (v >= 99.95) return v.round().toString();
  final fixed = v.toStringAsFixed(1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
}

/// [seconds] on the run's clock: 06:12, or 1:04:09 past an hour.
String fieldClock(double seconds) {
  final total = seconds.isFinite ? seconds.floor().clamp(0, 1 << 30) : 0;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}
