// Pure-Dart tests for the timed planet raid model + rotation scheduler.

import 'dart:math';

import 'package:alchemons/games/cosmic/raid_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime.utc(2026, 6, 11, 12);

  group('RaidState', () {
    test('serialise/deserialise round-trip', () {
      final state = RaidState(
        element: 'Air',
        startUtc: t0,
        duration: const Duration(hours: 24),
        source: RaidSource.summon,
        cleared: false,
      );
      final back = RaidState.deserialise(state.serialise())!;
      expect(back.element, 'Air');
      expect(back.startUtc, t0);
      expect(back.duration, const Duration(hours: 24));
      expect(back.source, RaidSource.summon);
      expect(back.cleared, isFalse);
    });

    test('deserialise rejects garbage', () {
      expect(RaidState.deserialise(null), isNull);
      expect(RaidState.deserialise(''), isNull);
      expect(RaidState.deserialise('Air|nope'), isNull);
      expect(RaidState.deserialise('Air|x|y|rotation|0'), isNull);
    });

    test('active window and remaining time', () {
      final state = RaidState(element: 'Air', startUtc: t0);
      expect(state.isActive(t0), isTrue);
      expect(state.isActive(t0.add(const Duration(hours: 23))), isTrue);
      expect(state.isActive(t0.add(const Duration(hours: 25))), isFalse);
      expect(
        state.remaining(t0.add(const Duration(hours: 23))),
        const Duration(hours: 1),
      );
      expect(state.remaining(t0.add(const Duration(hours: 30))), Duration.zero);
      expect(state.withCleared().isActive(t0), isFalse);
    });
  });

  group('RaidSchedule.evaluate', () {
    test('first launch queues a rotation without spawning', () {
      final r = RaidSchedule.evaluate(
        current: null,
        nextRotationUtc: null,
        nowUtc: t0,
        eligibleElements: const ['Air'],
        rng: Random(1),
      );
      expect(r.state, isNull);
      expect(r.nextRotationUtc, t0.add(kRaidRotationPeriod));
    });

    test('rotation due spawns on an eligible planet and reschedules', () {
      final r = RaidSchedule.evaluate(
        current: null,
        nextRotationUtc: t0.subtract(const Duration(minutes: 1)),
        nowUtc: t0,
        eligibleElements: const ['Air'],
        rng: Random(1),
      );
      expect(r.state, isNotNull);
      expect(r.state!.element, 'Air');
      expect(r.state!.source, RaidSource.rotation);
      expect(r.state!.isActive(t0), isTrue);
      expect(r.nextRotationUtc, t0.add(kRaidRotationPeriod));
    });

    test('rotation due with no eligible planets spawns nothing', () {
      final r = RaidSchedule.evaluate(
        current: null,
        nextRotationUtc: t0.subtract(const Duration(minutes: 1)),
        nowUtc: t0,
        eligibleElements: const [],
        rng: Random(1),
      );
      expect(r.state, isNull);
    });

    test('an active raid is untouched', () {
      final live = RaidState(element: 'Air', startUtc: t0);
      final r = RaidSchedule.evaluate(
        current: live,
        nextRotationUtc: t0.subtract(const Duration(hours: 1)),
        nowUtc: t0.add(const Duration(hours: 2)),
        eligibleElements: const ['Air'],
        rng: Random(1),
      );
      expect(r.state, same(live));
    });

    test('an expired raid is cleaned up and the rotation re-queued', () {
      final stale = RaidState(element: 'Air', startUtc: t0);
      final later = t0.add(const Duration(hours: 30));
      final r = RaidSchedule.evaluate(
        current: stale,
        nextRotationUtc: t0.add(const Duration(hours: 48)),
        nowUtc: later,
        eligibleElements: const ['Air'],
        rng: Random(1),
      );
      expect(r.state, isNull);
      expect(r.nextRotationUtc, t0.add(const Duration(hours: 48)));
    });

    test('a cleared raid does not block the next rotation spawn', () {
      final cleared = RaidState(element: 'Air', startUtc: t0).withCleared();
      final later = t0.add(const Duration(hours: 49));
      final r = RaidSchedule.evaluate(
        current: cleared,
        nextRotationUtc: t0.add(const Duration(hours: 48)),
        nowUtc: later,
        eligibleElements: const ['Air'],
        rng: Random(1),
      );
      expect(r.state, isNotNull);
      expect(r.state!.isActive(later), isTrue);
    });

    test('element pick is deterministic under a seeded rng', () {
      const eligible = ['Air', 'Fire', 'Water'];
      final a = RaidSchedule.evaluate(
        current: null,
        nextRotationUtc: t0,
        nowUtc: t0,
        eligibleElements: eligible,
        rng: Random(7),
      );
      final b = RaidSchedule.evaluate(
        current: null,
        nextRotationUtc: t0,
        nowUtc: t0,
        eligibleElements: eligible,
        rng: Random(7),
      );
      expect(a.state!.element, b.state!.element);
      expect(eligible, contains(a.state!.element));
    });
  });

  group('RaidSchedule.summon', () {
    test('summon works when idle and the planet is conquered', () {
      final s = RaidSchedule.summon(
        current: null,
        nowUtc: t0,
        element: 'Air',
        eligibleElements: const ['Air'],
      );
      expect(s, isNotNull);
      expect(s!.source, RaidSource.summon);
      expect(s.isActive(t0), isTrue);
    });

    test('summon rejected while a raid is live', () {
      final live = RaidState(element: 'Air', startUtc: t0);
      final s = RaidSchedule.summon(
        current: live,
        nowUtc: t0.add(const Duration(hours: 1)),
        element: 'Air',
        eligibleElements: const ['Air'],
      );
      expect(s, isNull);
    });

    test('summon rejected on an unconquered planet', () {
      final s = RaidSchedule.summon(
        current: null,
        nowUtc: t0,
        element: 'Fire',
        eligibleElements: const ['Air'],
      );
      expect(s, isNull);
    });
  });
}
