// lib/services/raid_service.dart
//
// SharedPreferences persistence for timed planet raids. All times UTC so the
// window survives restarts and timezone changes (same approach as breeding
// cooldowns in StaminaService).

import 'dart:math';

import 'package:alchemons/games/cosmic/raid_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RaidService {
  static const _stateKey = 'cosmic_raid_state';
  static const _rotationKey = 'cosmic_raid_next_rotation_utc';

  final Random _rng;
  RaidService({Random? rng}) : _rng = rng ?? Random();

  Future<RaidState?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return RaidState.deserialise(prefs.getString(_stateKey));
  }

  /// Runs the rotation scheduler against "now" and persists the outcome.
  /// Returns the raid that is currently live, if any.
  Future<RaidState?> evaluateAndPersist(List<String> eligibleElements) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc();
    final rotationMs = prefs.getInt(_rotationKey);
    final result = RaidSchedule.evaluate(
      current: RaidState.deserialise(prefs.getString(_stateKey)),
      nextRotationUtc: rotationMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(rotationMs, isUtc: true),
      nowUtc: now,
      eligibleElements: eligibleElements,
      rng: _rng,
    );
    await _persist(prefs, result.state, result.nextRotationUtc);
    final s = result.state;
    return (s != null && s.isActive(now)) ? s : null;
  }

  /// Beacon summon. Returns the new raid, or null if a raid is already live
  /// or the planet isn't conquered (caller shows the reason + refunds).
  Future<RaidState?> forceSummon(
    String element,
    List<String> eligibleElements,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc();
    final state = RaidSchedule.summon(
      current: RaidState.deserialise(prefs.getString(_stateKey)),
      nowUtc: now,
      element: element,
      eligibleElements: eligibleElements,
    );
    if (state == null) return null;
    await prefs.setString(_stateKey, state.serialise());
    return state;
  }

  /// Advance the active raid to its next tier. The first Level-3 clear starts
  /// its echo cooldown; clearing the echo closes the raid and queues the next
  /// rotation from now.
  Future<void> markLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    final state = RaidState.deserialise(prefs.getString(_stateKey));
    if (state == null) return;
    final now = DateTime.now().toUtc();
    final next = state.advanceLevel(nowUtc: now);
    final rotationMs = prefs.getInt(_rotationKey);
    final currentRotation = rotationMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(rotationMs, isUtc: true);
    final nextRotation = next.cleared
        ? now.add(kRaidRotationPeriod)
        : currentRotation ?? now.add(kRaidRotationPeriod);
    await _persist(prefs, next, nextRotation);
  }

  Future<void> _persist(
    SharedPreferences prefs,
    RaidState? state,
    DateTime? nextRotationUtc,
  ) async {
    if (state == null) {
      await prefs.remove(_stateKey);
    } else {
      await prefs.setString(_stateKey, state.serialise());
    }
    if (nextRotationUtc == null) {
      await prefs.remove(_rotationKey);
    } else {
      await prefs.setInt(_rotationKey, nextRotationUtc.millisecondsSinceEpoch);
    }
  }

  /// Debug helper: clears all raid state.
  Future<void> debugReset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_stateKey);
    await prefs.remove(_rotationKey);
  }

  /// Debug helper: makes the next rotation due immediately.
  Future<void> debugForceRotationDue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _rotationKey,
      DateTime.now().toUtc().millisecondsSinceEpoch - 1000,
    );
  }
}
