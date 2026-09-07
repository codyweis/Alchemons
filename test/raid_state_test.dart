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
        level: 2,
        level3Clears: 1,
        readyUtc: t0.add(const Duration(hours: 12)),
      );
      final back = RaidState.deserialise(state.serialise())!;
      expect(back.element, 'Air');
      expect(back.startUtc, t0);
      expect(back.duration, const Duration(hours: 24));
      expect(back.source, RaidSource.summon);
      expect(back.cleared, isFalse);
      expect(back.level, 2);
      expect(back.level3Clears, 1);
      expect(back.readyUtc, t0.add(const Duration(hours: 12)));
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

    test('legacy raids migrate to Level 1', () {
      final legacy = RaidState.deserialise(
        'Air|${t0.millisecondsSinceEpoch}|86400|rotation|0',
      )!;
      expect(legacy.level, 1);
    });

    test('six-field tier saves keep their level and migrate echo state', () {
      final tierSave = RaidState.deserialise(
        'Air|${t0.millisecondsSinceEpoch}|86400|rotation|0|3',
      )!;
      expect(tierSave.level, 3);
      expect(tierSave.level3Clears, 0);
      expect(tierSave.readyUtc, isNull);
    });

    test('invalid stored echo time does not create an epoch cooldown', () {
      final state = RaidState.deserialise(
        'Air|${t0.millisecondsSinceEpoch}|86400|rotation|0|3|1|bad',
      )!;
      expect(state.readyUtc, isNull);
      expect(state.canEnter(t0), isTrue);
    });

    test('tier clears advance through Level 3 and one respawn', () {
      final level1 = RaidState(element: 'Air', startUtc: t0);
      final level2 = level1.advanceLevel(nowUtc: t0);
      final level3 = level2.advanceLevel(nowUtc: t0);
      final cooling = level3.advanceLevel(nowUtc: t0);
      final finished = cooling.advanceLevel(
        nowUtc: t0.add(kRaidLevel3RespawnCooldown),
      );

      expect(level2.level, 2);
      expect(level2.cleared, isFalse);
      expect(level3.level, 3);
      expect(level3.cleared, isFalse);
      expect(cooling.level, 3);
      expect(cooling.level3Clears, 1);
      expect(cooling.cleared, isFalse);
      expect(cooling.isCoolingDown(t0), isTrue);
      expect(cooling.canEnter(t0), isFalse);
      expect(cooling.readyUtc, t0.add(kRaidLevel3RespawnCooldown));
      expect(cooling.endUtc, t0.add(kRaidLevel3RespawnWindow));
      expect(cooling.canEnter(t0.add(kRaidLevel3RespawnCooldown)), isTrue);
      expect(finished.level, 3);
      expect(finished.level3Clears, 2);
      expect(finished.cleared, isTrue);
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
