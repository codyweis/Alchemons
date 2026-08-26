// Rifts used to live only in the Flame game instance, so leaving a scene
// destroyed them. Since entering one needs a faction portal key you may not
// hold, the correct response — go buy the key — was the thing that lost you
// the rift, and the next 5% roll would likely be a different faction.
//
// A rift now survives for kRiftWindow, and only one is open at a time.

import 'package:alchemons/models/rift_state.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 8, 22, 12);

PendingRift _rift({String scene = 'valley', Duration age = Duration.zero}) =>
    PendingRift(
      factionName: 'earthen',
      sceneId: scene,
      spawnedUtc: _now.subtract(age),
    );

void main() {
  group('the window', () {
    test('is eight hours from spawn, not a clock cutoff', () {
      // A midnight cutoff would give a rift that appeared at 11:50pm ten
      // usable minutes — the same dead end this replaces.
      expect(kRiftWindow, const Duration(hours: 8));
      expect(_rift().expiresUtc, _now.add(const Duration(hours: 8)));
    });

    test('is open right up to the boundary and shut after it', () {
      final r = _rift();
      expect(r.isOpen(_now), isTrue);
      expect(r.isOpen(_now.add(const Duration(hours: 7, minutes: 59))), isTrue);
      expect(r.isOpen(r.expiresUtc), isFalse);
      expect(r.isOpen(r.expiresUtc.add(const Duration(seconds: 1))), isFalse);
    });

    test('remaining never goes negative', () {
      final r = _rift(age: const Duration(hours: 20));
      expect(r.remaining(_now), Duration.zero);
      expect(r.remainingLabel(_now), 'expired');
    });

    test('the countdown label is readable at each scale', () {
      expect(_rift().remainingLabel(_now), '8h 0m');
      expect(
        _rift(age: const Duration(hours: 4, minutes: 40)).remainingLabel(_now),
        '3h 20m',
      );
      expect(
        _rift(age: const Duration(hours: 7, minutes: 48)).remainingLabel(_now),
        '12m',
      );
      expect(
        _rift(
          age: const Duration(hours: 7, minutes: 59, seconds: 30),
        ).remainingLabel(_now),
        '<1m',
      );
    });
  });

  group('entering a scene', () {
    test('rolls when nothing is pending', () {
      expect(
        riftActionForScene(pending: null, sceneId: 'valley', nowUtc: _now),
        RiftSceneAction.roll,
      );
    });

    test('restores the rift waiting in this scene', () {
      expect(
        riftActionForScene(
          pending: _rift(scene: 'valley'),
          sceneId: 'valley',
          nowUtc: _now,
        ),
        RiftSceneAction.restore,
      );
    });

    test('does nothing while a rift waits in another scene', () {
      // One at a time: entering the swamp must not roll a second rift while
      // one is still open in the valley.
      expect(
        riftActionForScene(
          pending: _rift(scene: 'valley'),
          sceneId: 'swamp',
          nowUtc: _now,
        ),
        RiftSceneAction.none,
      );
    });

    test('an expired rift frees the slot, even in another scene', () {
      final stale = _rift(scene: 'valley', age: const Duration(hours: 9));
      for (final scene in ['valley', 'swamp']) {
        expect(
          riftActionForScene(pending: stale, sceneId: scene, nowUtc: _now),
          RiftSceneAction.roll,
          reason: scene,
        );
      }
    });

    test('an expired rift in this scene is not restored', () {
      expect(
        riftActionForScene(
          pending: _rift(scene: 'valley', age: const Duration(hours: 8)),
          sceneId: 'valley',
          nowUtc: _now,
        ),
        isNot(RiftSceneAction.restore),
      );
    });
  });

  group('round-tripping through storage', () {
    test('survives serialise and back', () {
      final r = _rift(scene: 'volcano');
      final back = PendingRift.deserialise(r.serialise())!;
      expect(back.factionName, r.factionName);
      expect(back.sceneId, r.sceneId);
      expect(back.spawnedUtc, r.spawnedUtc);
      expect(back.window, r.window);
      expect(back.expiresUtc, r.expiresUtc);
    });

    test('garbage and empties read as no rift, never a crash', () {
      for (final bad in [
        null,
        '',
        'nonsense',
        'a|b',
        'earthen|valley|notanumber|3600',
        'earthen|valley|123|notanumber',
        '|valley|123|3600',
        'earthen||123|3600',
      ]) {
        expect(PendingRift.deserialise(bad), isNull, reason: '$bad');
      }
    });

    test('a stored rift still expires on schedule after a restart', () {
      // The window is anchored to spawn time, so closing the app does not
      // pause it.
      final r = _rift(age: const Duration(hours: 7));
      final reloaded = PendingRift.deserialise(r.serialise())!;
      expect(reloaded.isOpen(_now), isTrue);
      expect(reloaded.isOpen(_now.add(const Duration(hours: 2))), isFalse);
    });
  });

  test('the spawn chance is unchanged — this is not a rift buff', () {
    // Persistence makes an existing rift reachable; it must not make rifts
    // more common.
    expect(kRiftSpawnChance, 0.05);
  });
}
