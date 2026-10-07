// lib/games/cosmic/raid_state.dart
//
// Pure-Dart model + scheduler for timed planet raids.
//
// A raid "takes over" one conquered planet (guardian beaten) for a real-time
// window. While active, descending enters the raid arena instead of the
// normal dungeon. Raids spawn on an automatic rotation, or on demand via a
// Raid Beacon. Each victory advances a three-level ladder. The first Level-3
// victory schedules one delayed echo; the planet returns to normal when that
// echo falls or the event window closes.
//
// No Flutter/DB imports here — persistence lives in RaidService, and the
// tests exercise this file headlessly.

import 'dart:math';

/// How long a raid stays attackable once it spawns.
const Duration kRaidWindow = Duration(hours: 24);

/// How long you get to fell the guardian once the fight begins.
///
/// A hard fail state, so a raid cannot be outlasted forever. Since the
/// 2026-10-07 tuning a mid squad (stats 3) fells the L3 guardian in about
/// three and a half minutes and a strong one (4.5) in about one and a half,
/// and the squad hit wears down a squad that is not ready long before ten:
/// the limit is a backstop, not the wall.
const Duration kRaidFightLimit = Duration(minutes: 10);

/// A defeated Level-3 guardian reforms once per raid event. The cooldown
/// prevents the final tier's Soul, Gold, cache, and orb payout becoming an
/// immediate infinite loop.
const Duration kRaidLevel3RespawnCooldown = Duration(hours: 12);

/// Once the first Level-3 clear lands, guarantee enough event time for the
/// respawn cooldown plus a twelve-hour claim window.
const Duration kRaidLevel3RespawnWindow = Duration(hours: 24);

/// How often the rotation tries to spawn a raid (measured from the end of
/// the previous raid, or from first launch).
const Duration kRaidRotationPeriod = Duration(hours: 48);

enum RaidSource { rotation, summon }

class RaidState {
  final String element;
  final DateTime startUtc;
  final Duration duration;
  final RaidSource source;
  final bool cleared;
  final int level;
  final int level3Clears;
  final DateTime? readyUtc;

  const RaidState({
    required this.element,
    required this.startUtc,
    this.duration = kRaidWindow,
    this.source = RaidSource.rotation,
    this.cleared = false,
    this.level = 1,
    this.level3Clears = 0,
    this.readyUtc,
  });

  DateTime get endUtc => startUtc.add(duration);

  bool isActive(DateTime nowUtc) => !cleared && nowUtc.isBefore(endUtc);

  bool canEnter(DateTime nowUtc) =>
      isActive(nowUtc) && (readyUtc == null || !nowUtc.isBefore(readyUtc!));

  bool isCoolingDown(DateTime nowUtc) =>
      isActive(nowUtc) && readyUtc != null && nowUtc.isBefore(readyUtc!);

  Duration respawnRemaining(DateTime nowUtc) {
    final ready = readyUtc;
    if (ready == null) return Duration.zero;
    final left = ready.difference(nowUtc);
    return left.isNegative ? Duration.zero : left;
  }

  Duration remaining(DateTime nowUtc) {
    final left = endUtc.difference(nowUtc);
    return left.isNegative ? Duration.zero : left;
  }

  RaidState withCleared() => RaidState(
    element: element,
    startUtc: startUtc,
    duration: duration,
    source: source,
    cleared: true,
    level: level,
    level3Clears: level3Clears,
    readyUtc: readyUtc,
  );

  /// Advances a cleared tier. The first Level-3 clear schedules one respawn;
  /// defeating that echo closes the raid.
  RaidState advanceLevel({required DateTime nowUtc}) {
    if (level < RaidConfig.maxLevel) {
      return RaidState(
        element: element,
        startUtc: startUtc,
        duration: duration,
        source: source,
        cleared: false,
        level: level + 1,
        level3Clears: level3Clears,
      );
    }

    if (level3Clears == 0) {
      final ready = nowUtc.add(kRaidLevel3RespawnCooldown);
      final guaranteedEnd = nowUtc.add(kRaidLevel3RespawnWindow);
      final extendedDuration = guaranteedEnd.isAfter(endUtc)
          ? guaranteedEnd.difference(startUtc)
          : duration;
      return RaidState(
        element: element,
        startUtc: startUtc,
        duration: extendedDuration,
        source: source,
        cleared: false,
        level: RaidConfig.maxLevel,
        level3Clears: 1,
        readyUtc: ready,
      );
    }

    return RaidState(
      element: element,
      startUtc: startUtc,
      duration: duration,
      source: source,
      cleared: true,
      level: RaidConfig.maxLevel,
      level3Clears: 2,
      readyUtc: null,
    );
  }

  String serialise() => [
    element,
    startUtc.millisecondsSinceEpoch,
    duration.inSeconds,
    source.name,
    cleared ? 1 : 0,
    level.clamp(1, RaidConfig.maxLevel),
    level3Clears.clamp(0, 2),
    readyUtc?.millisecondsSinceEpoch ?? '',
  ].join('|');

  static RaidState? deserialise(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('|');
    // Five fields is the pre-tier format; migrate those raids to Level 1.
    if (parts.length != 5 && parts.length != 6 && parts.length != 8) {
      return null;
    }
    final startMs = int.tryParse(parts[1]);
    final durSec = int.tryParse(parts[2]);
    if (startMs == null || durSec == null) return null;
    final storedLevel = parts.length >= 6 ? int.tryParse(parts[5]) : null;
    final storedLevel3Clears = parts.length == 8
        ? int.tryParse(parts[6])
        : null;
    final readyMs = parts.length == 8 && parts[7].isNotEmpty
        ? int.tryParse(parts[7])
        : null;
    return RaidState(
      element: parts[0],
      startUtc: DateTime.fromMillisecondsSinceEpoch(startMs, isUtc: true),
      duration: Duration(seconds: durSec),
      source: parts[3] == RaidSource.summon.name
          ? RaidSource.summon
          : RaidSource.rotation,
      cleared: parts[4] == '1',
      level: (storedLevel ?? 1).clamp(1, RaidConfig.maxLevel),
      level3Clears: (storedLevel3Clears ?? 0).clamp(0, 2),
      readyUtc: readyMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(readyMs, isUtc: true),
    );
  }
}

class RaidScheduleResult {
  final RaidState? state;
  final DateTime? nextRotationUtc;
  const RaidScheduleResult(this.state, this.nextRotationUtc);
}

/// Pure rotation logic: given the persisted state and "now", decide whether a
/// raid should spawn, keep running, or be cleaned up.
class RaidSchedule {
  static RaidScheduleResult evaluate({
    required RaidState? current,
    required DateTime? nextRotationUtc,
    required DateTime nowUtc,
    required List<String> eligibleElements,
    required Random rng,
  }) {
    var state = current;
    var nextRotation = nextRotationUtc;

    // An active raid keeps running untouched.
    if (state != null && state.isActive(nowUtc)) {
      return RaidScheduleResult(
        state,
        nextRotation ?? nowUtc.add(kRaidRotationPeriod),
      );
    }

    // Expired or cleared raid: clean up. A rotation that came due while the
    // old raid wound down is left due, so the next spawn happens right away
    // ("you return to find another planet under attack"). Completing level 3
    // pushes the rotation out after the final victory.
    if (state != null) {
      state = null;
      nextRotation ??= nowUtc.add(kRaidRotationPeriod);
    }

    // First launch: queue the first rotation, don't spawn instantly.
    if (nextRotation == null) {
      return RaidScheduleResult(null, nowUtc.add(kRaidRotationPeriod));
    }

    // Rotation due → spawn on a random conquered planet.
    if (!nowUtc.isBefore(nextRotation) && eligibleElements.isNotEmpty) {
      final element = eligibleElements[rng.nextInt(eligibleElements.length)];
      return RaidScheduleResult(
        RaidState(element: element, startUtc: nowUtc),
        nowUtc.add(kRaidRotationPeriod),
      );
    }

    return RaidScheduleResult(null, nextRotation);
  }

  /// Beacon summon: allowed only when no raid is live and the target planet
  /// is conquered. Returns null if the summon is not allowed.
  static RaidState? summon({
    required RaidState? current,
    required DateTime nowUtc,
    required String element,
    required List<String> eligibleElements,
  }) {
    if (current != null && current.isActive(nowUtc)) return null;
    if (!eligibleElements.contains(element)) return null;
    return RaidState(
      element: element,
      startUtc: nowUtc,
      source: RaidSource.summon,
    );
  }
}

/// Knobs for the raid-empowered guardian fight.
class RaidConfig {
  static const int maxLevel = 3;

  final int level;
  final int level3Clears;
  final double? _hpMulOverride;
  final double? _dmgMulOverride;

  /// Guardian HP fractions at which a wave of adds joins the fight.
  final List<double>? _addPhaseThresholdsOverride;

  const RaidConfig({
    this.level = 1,
    this.level3Clears = 0,
    double? hpMul,
    double? dmgMul,
    List<double>? addPhaseThresholds,
  }) : _hpMulOverride = hpMul,
       _dmgMulOverride = dmgMul,
       _addPhaseThresholdsOverride = addPhaseThresholds;

  int get safeLevel => level.clamp(1, maxLevel);

  /// Raid difficulty is fixed by tier and deliberately ignores campaign
  /// guardian count. This lets every conquered planet host the same L1–L3
  /// ladder without late planets silently multiplying it again.
  ///
  /// TUNED 2026-10-07 (docs/plans/raid_threat_plan.md, Phase 6) against the
  /// author's tier table: a mid squad with no healer loses about one at L1,
  /// most of itself at L2, and wipes at L3; with a Kin it loses none, 0–1,
  /// then 1–3. What makes a tier harder is how LONG it lasts and how many
  /// adds it brings. The hits stay the same size, because the squad hit
  /// lands evenly: over a longer fight it is the total that kills, and the
  /// old per-tier ramp on top of the HP ramp (×10 / ×18 HP and ×2.3 / ×3.2
  /// damage) wiped a mid squad at L2 and L3 whatever it brought.
  double get hpMul =>
      _hpMulOverride ??
      switch (safeLevel) {
        1 => 5.0,
        2 => 7.0,
        _ => 11.0,
      };

  double get dmgMul =>
      _dmgMulOverride ??
      switch (safeLevel) {
        1 => 1.6,
        2 => 1.9,
        _ => 2.4,
      };

  List<double> get addPhaseThresholds =>
      _addPhaseThresholdsOverride ??
      switch (safeLevel) {
        1 => const [0.50],
        2 => const [0.70, 0.35],
        _ => const [0.80, 0.55, 0.30],
      };

  /// A guardian dive's share of its victim's health (plus the guardian's
  /// damage, then trimmed by P-DEF). The same at every tier; see [hpMul].
  double get guardianHitFraction => 0.06;

  /// Seconds between the guardian's squad hits: one telegraphed hit on every
  /// living Alchemon, wherever it stands. Attrition you answer with healing
  /// and defence, never by dodging. The last tier's beat is a little
  /// quicker.
  double get squadHitInterval => safeLevel >= 3 ? 7.0 : 8.0;

  /// What a squad hit takes from each Alchemon, as a fraction of its health,
  /// before E-DEF trims it. The same at every tier; see [hpMul].
  double get squadHitFraction => 0.06;

  double get lullStrikeMultiplier => switch (safeLevel) {
    1 => 6.0,
    2 => 7.0,
    _ => 8.0,
  };

  /// How tough an add wave is. An add that outlives its welcome does the
  /// killing: at the old ×35 a mid squad could not clear the L3 waves, and
  /// with no adds at all the same squad and healer cleared L3 with one loss.
  double get addHpMul => safeLevel >= 3 ? 12.0 : 8.0;

  /// Adds hit like the dungeon's own wisps (about 9% of a body a contact).
  /// Their raid toughness is their health, not their bite: at the old
  /// ×1.5–×3 every contact took 12–20%, as much as the guardian's own dive.
  double get addDmgMul => 1.0;

  /// How many Alchemons a raid squad may field, against three in a dungeon.
  static const int squadSize = 5;
}
