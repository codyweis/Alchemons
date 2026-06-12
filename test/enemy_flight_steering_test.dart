// Unit tests for the shared hover/dive enemy steering used by planet
// dungeons, cosmic survival, and open cosmic space.

import 'dart:math';

import 'package:alchemons/games/shared/enemy_flight_steering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Step a stationary-target scenario: the enemy starts [startOffset] away
/// from a fixed target; returns the trace of relative offsets (target -
/// enemy) plus how many impacts landed.
({List<Offset> trace, int impacts, int telegraphFrames}) _simulate({
  required FlightSteeringProfile profile,
  required Offset startOffset,
  double speed = 90,
  double contactRange = 26,
  double seconds = 12,
  int seed = 7,
}) {
  final rng = Random(seed);
  final state = FlightSteeringState(rng);
  var enemyPos = Offset.zero;
  const targetPos = Offset(0, 0);
  var toTarget = targetPos - (enemyPos = -startOffset);
  final trace = <Offset>[];
  var impacts = 0;
  var telegraphFrames = 0;
  const dt = 1 / 60;
  for (var t = 0.0; t < seconds; t += dt) {
    toTarget = targetPos - enemyPos;
    final tick = tickFlightSteering(
      state: state,
      profile: profile,
      toTarget: toTarget,
      speed: speed,
      contactRange: contactRange,
      dt: dt,
      rng: rng,
    );
    enemyPos += tick.velocity * dt;
    if (tick.impact) impacts++;
    if (state.telegraphing) telegraphFrames++;
    trace.add(targetPos - enemyPos);
  }
  return (trace: trace, impacts: impacts, telegraphFrames: telegraphFrames);
}

void main() {
  group('flight steering', () {
    for (final (name, profile) in [
      ('dungeonWisp', FlightSteeringProfile.dungeonWisp),
      ('survivalMelee', FlightSteeringProfile.survivalMelee),
      ('spaceMelee', FlightSteeringProfile.spaceMelee),
    ]) {
      test('$name: approaches, hovers, telegraphs, and lands dives', () {
        final run = _simulate(
          profile: profile,
          startOffset: Offset(profile.hoverRadius * 4, 40),
        );
        expect(run.impacts, greaterThan(0), reason: 'dives must land');
        expect(
          run.telegraphFrames,
          greaterThan(0),
          reason: 'every dive is telegraphed',
        );
        // The enemy must NOT grind on the target: most of its time is spent
        // off-contact (hovering / retreating / approaching).
        final touching = run.trace
            .where((d) => d.distance < 30)
            .length;
        expect(
          touching / run.trace.length,
          lessThan(0.4),
          reason: 'hover/dive spends most time off-contact',
        );
        // And it engages: it must spend real time near the hover ring.
        final nearRing = run.trace
            .where((d) => (d.distance - profile.hoverRadius).abs() <
                profile.hoverRadius)
            .length;
        expect(nearRing / run.trace.length, greaterThan(0.4));
      });
    }

    test('impact begins a retreat (velocity points away from target)', () {
      final rng = Random(3);
      final state = FlightSteeringState(rng)
        ..diving = true
        ..diveTimer = 1.0;
      const toTarget = Offset(10, 0); // already within contact range
      final tick = tickFlightSteering(
        state: state,
        profile: FlightSteeringProfile.dungeonWisp,
        toTarget: toTarget,
        speed: 80,
        contactRange: 26,
        dt: 1 / 60,
        rng: rng,
      );
      expect(tick.impact, isTrue);
      expect(state.diving, isFalse);
      // Retreat velocity points away from the target.
      expect(state.velocity.dx, lessThan(0));
    });

    test('a dive that misses times out and returns to hovering', () {
      final rng = Random(5);
      final state = FlightSteeringState(rng)
        ..diving = true
        ..diveTimer = 0.05;
      var fired = 0;
      for (var i = 0; i < 30; i++) {
        final tick = tickFlightSteering(
          state: state,
          profile: FlightSteeringProfile.spaceMelee,
          toTarget: const Offset(900, 0), // target far away — dive whiffs
          speed: 80,
          contactRange: 22,
          dt: 1 / 60,
          rng: rng,
        );
        if (tick.impact) fired++;
      }
      expect(fired, 0);
      expect(state.diving, isFalse, reason: 'dive timed out');
    });

    test('telegraph ring shows on the first windup only', () {
      final rng = Random(9);
      final state = FlightSteeringState(rng);
      var enemyPos = const Offset(-120, 0);
      const dt = 1 / 60;
      var firstWindupRings = 0;
      var laterWindupRings = 0;
      var divesSeen = 0;
      for (var t = 0.0; t < 20; t += dt) {
        final wasDiving = state.diving;
        final tick = tickFlightSteering(
          state: state,
          profile: FlightSteeringProfile.survivalMelee,
          toTarget: -enemyPos,
          speed: 90,
          contactRange: 26,
          dt: dt,
          rng: rng,
        );
        enemyPos += tick.velocity * dt;
        if (!wasDiving && state.diving) divesSeen++;
        if (state.telegraphing) {
          if (divesSeen == 0) {
            if (state.showTelegraphRing) firstWindupRings++;
          } else {
            if (state.showTelegraphRing) laterWindupRings++;
          }
        }
      }
      expect(divesSeen, greaterThan(1), reason: 'multiple dives sampled');
      expect(firstWindupRings, greaterThan(0), reason: 'first windup rings');
      expect(
        laterWindupRings,
        0,
        reason: 'the ring is a one-time teaching cue per enemy',
      );
    });

    test('degenerate input (zero delta, zero dt) stays finite', () {
      final rng = Random(11);
      final state = FlightSteeringState(rng);
      for (var i = 0; i < 120; i++) {
        final tick = tickFlightSteering(
          state: state,
          profile: FlightSteeringProfile.survivalPouncer,
          toTarget: Offset.zero,
          speed: 0,
          contactRange: 10,
          dt: i.isEven ? 0 : 1 / 60,
          rng: rng,
        );
        expect(tick.velocity.dx.isFinite, isTrue);
        expect(tick.velocity.dy.isFinite, isTrue);
      }
    });
  });
}
