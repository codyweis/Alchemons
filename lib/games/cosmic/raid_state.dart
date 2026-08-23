// lib/games/cosmic/raid_state.dart
//
// Pure-Dart model + scheduler for timed planet raids.
//
// A raid "takes over" one conquered planet (guardian beaten) for a real-time
// window. While active, descending enters the raid arena instead of the
// normal dungeon. Raids spawn on an automatic rotation, or on demand via a
// Raid Beacon. Clearing the raid banks loot; the planet returns to normal
// when the window closes or the raid is cleared.
//
// No Flutter/DB imports here — persistence lives in RaidService, and the
// tests exercise this file headlessly.

import 'dart:math';

/// How long a raid stays attackable once it spawns.
const Duration kRaidWindow = Duration(hours: 24);

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

  const RaidState({
    required this.element,
    required this.startUtc,
    this.duration = kRaidWindow,
    this.source = RaidSource.rotation,
    this.cleared = false,
  });

  DateTime get endUtc => startUtc.add(duration);

  bool isActive(DateTime nowUtc) => !cleared && nowUtc.isBefore(endUtc);

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
  );

  String serialise() => [
    element,
    startUtc.millisecondsSinceEpoch,
    duration.inSeconds,
    source.name,
    cleared ? 1 : 0,
  ].join('|');

  static RaidState? deserialise(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('|');
    if (parts.length != 5) return null;
    final startMs = int.tryParse(parts[1]);
    final durSec = int.tryParse(parts[2]);
    if (startMs == null || durSec == null) return null;
    return RaidState(
      element: parts[0],
      startUtc: DateTime.fromMillisecondsSinceEpoch(startMs, isUtc: true),
      duration: Duration(seconds: durSec),
      source: parts[3] == RaidSource.summon.name
          ? RaidSource.summon
          : RaidSource.rotation,
      cleared: parts[4] == '1',
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
    // ("you return to find another planet under attack"). markCleared()
    // already pushes the rotation out after a victory.
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
  final double hpMul;
  final double dmgMul;

  /// Guardian HP fractions at which a wave of adds joins the fight.
  final List<double> addPhaseThresholds;

  const RaidConfig({
    // A raid squad is five Alchemons to a dungeon's three — roughly +67% DPS
    // and +67% bodies to lose. HP rises with it (3.0 -> 5.0) so the fight
    // still takes about as long as it used to, and damage rises further
    // (1.5 -> 2.2) so the bigger roster does not just mean more slack.
    this.hpMul = 5.0,
    this.dmgMul = 2.2,
    this.addPhaseThresholds = const [0.7, 0.35],
  });

  /// How many Alchemons a raid squad may field, against three in a dungeon.
  static const int squadSize = 5;
}
