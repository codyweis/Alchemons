import 'dart:math';
import 'dart:ui';

import 'package:alchemons/games/cosmic/cosmic_cache_data.dart';
import 'package:alchemons/games/cosmic/cosmic_cache_rewards.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _world = Size(38400, 38400);

List<CosmicPlanet> _planets() => [
  CosmicPlanet(element: 'Fire', position: const Offset(5000, 5000), radius: 70),
  CosmicPlanet(
    element: 'Water',
    position: const Offset(20000, 12000),
    radius: 70,
  ),
];

void main() {
  group('cache field layout', () {
    test('holds exactly one present cache per element', () {
      final field = ElementalCacheField.generate(
        seed: 7,
        worldSize: _world,
        planets: _planets(),
      );

      expect(field.caches.length, kElementColors.length);
      expect(
        field.caches.map((c) => c.element).toSet(),
        kElementColors.keys.toSet(),
      );
      expect(field.caches.every((c) => c.isPresent), isTrue);
      expect(field.caches.every((c) => !c.discovered), isTrue);
    });

    test('every element carries a hint the player can act on', () {
      for (final element in kElementColors.keys) {
        expect(kCacheHints[element], isNotNull, reason: element);
        expect(cacheHintFor(element), isNotEmpty);
      }
    });

    test('caches keep clear of planets and of each other', () {
      final planets = _planets();
      final field = ElementalCacheField.generate(
        seed: 99,
        worldSize: _world,
        planets: planets,
      );

      for (final cache in field.caches) {
        for (final planet in planets) {
          expect(
            (planet.position - cache.position).distance,
            greaterThanOrEqualTo(1600.0),
            reason: '${cache.element} sits on top of ${planet.element}',
          );
        }
      }
      for (var i = 0; i < field.caches.length; i++) {
        for (var j = i + 1; j < field.caches.length; j++) {
          expect(
            (field.caches[i].position - field.caches[j].position).distance,
            greaterThanOrEqualTo(2600.0),
          );
        }
      }
    });

    test('caches keep clear of other landmarks that share a HUD slot', () {
      const landmarks = [
        Offset(9000, 9000),
        Offset(21000, 4000),
        Offset(30000, 30000),
      ];
      final field = ElementalCacheField.generate(
        seed: 12,
        worldSize: _world,
        planets: _planets(),
        landmarks: landmarks,
      );

      for (final cache in field.caches) {
        for (final l in landmarks) {
          expect(
            (l - cache.position).distance,
            greaterThanOrEqualTo(2000.0),
            reason: '${cache.element} sits on a landmark',
          );
        }
      }
    });

    test('a relocated cache still avoids landmarks', () {
      const landmarks = [Offset(9000, 9000)];
      final planets = _planets();
      final field = ElementalCacheField.generate(
        seed: 12,
        worldSize: _world,
        planets: planets,
        landmarks: landmarks,
      );
      final cache = field.caches.first;
      for (var i = 0; i < 40; i++) {
        field.relocate(cache, Random(i), planets);
        expect(
          (landmarks.first - cache.position).distance,
          greaterThanOrEqualTo(2000.0),
        );
      }
    });

    test('relocating a claimed cache moves it and forgets the sighting', () {
      final planets = _planets();
      final field = ElementalCacheField.generate(
        seed: 3,
        worldSize: _world,
        planets: planets,
      );
      final cache = field.caches.first;
      cache.discovered = true;
      final before = cache.position;

      field.relocate(cache, Random(11), planets);

      expect(cache.position, isNot(before));
      expect(cache.discovered, isFalse);
      expect(cache.openTimer, -1);
    });
  });

  group('persistence', () {
    test('round-trips position, sighting and the daily open stamp', () {
      final planets = _planets();
      final saved = ElementalCacheField.generate(
        seed: 5,
        worldSize: _world,
        planets: planets,
      );
      saved.caches[0].discovered = true;
      saved.caches[0].position = const Offset(1234.5, 6789.5);
      final openedAt = DateTime.now().millisecondsSinceEpoch;
      saved.caches[1].openedAtMs = openedAt;

      final restored = ElementalCacheField.generate(
        seed: 5,
        worldSize: _world,
        planets: planets,
      );
      restored.restore(saved.serialise());

      expect(restored.caches[0].discovered, isTrue);
      expect(restored.caches[0].position.dx, closeTo(1234.5, 0.05));
      expect(restored.caches[0].position.dy, closeTo(6789.5, 0.05));
      expect(restored.caches[1].openedAtMs, openedAt);
      expect(restored.caches[1].isPresent, isFalse);
    });

    test('saves written before the daily reset restore as available', () {
      final field = ElementalCacheField.generate(
        seed: 5,
        worldSize: _world,
        planets: _planets(),
      );
      // Legacy row: five fields, no open stamp, mid-countdown.
      field.restore('Fire,10,20,1,420');
      final fire = field.caches.firstWhere((c) => c.element == 'Fire');
      expect(fire.openedAtMs, 0);
      expect(
        fire.isPresent,
        isTrue,
        reason:
            'nothing decrements the old countdown any more, so a legacy '
            'cache must not be stranded',
      );
    });
  });

  group('daily reset', () {
    ElementalCache cacheOpenedAt(DateTime when) => ElementalCache(
      element: 'Fire',
      position: Offset.zero,
      openedAtMs: when.millisecondsSinceEpoch,
    );

    test('a cache opened today is gone for the rest of the day', () {
      final now = DateTime(2026, 8, 21, 9);
      final cache = cacheOpenedAt(now);
      expect(cache.isPresentAt(now), isFalse);
      expect(cache.isPresentAt(DateTime(2026, 8, 21, 23, 59)), isFalse);
    });

    test('it returns when the calendar day rolls over', () {
      final cache = cacheOpenedAt(DateTime(2026, 8, 21, 23, 59));
      // Two minutes later in wall-clock terms, but a new day.
      expect(cache.isPresentAt(DateTime(2026, 8, 22, 0, 1)), isTrue);
    });

    test('an unopened cache is always present', () {
      expect(
        ElementalCache(element: 'Fire', position: Offset.zero).isPresent,
        isTrue,
      );
    });

    test('availableAt is midnight after the day it was opened', () {
      final cache = cacheOpenedAt(DateTime(2026, 8, 21, 14, 30));
      expect(cache.availableAt, DateTime(2026, 8, 22));
    });

    test('malformed or unknown entries are skipped, not fatal', () {
      final field = ElementalCacheField.generate(
        seed: 5,
        worldSize: _world,
        planets: _planets(),
      );
      expect(
        () => field.restore('garbage|Nonsense,1,2,3,4|Fire,10,20,1,0'),
        returnsNormally,
      );
      final fire = field.caches.firstWhere((c) => c.element == 'Fire');
      expect(fire.position, const Offset(10, 20));
      expect(fire.discovered, isTrue);
    });

    test('restore never leaves a cache mid-unseal', () {
      final field = ElementalCacheField.generate(
        seed: 5,
        worldSize: _world,
        planets: _planets(),
      );
      field.caches.first.openTimer = 1.4;
      field.restore(field.serialise());
      expect(field.caches.first.openTimer, -1);
    });
  });

  group('payout', () {
    test('always pays gold, powerups, elixirs and one harvester', () {
      for (var seed = 0; seed < 300; seed++) {
        final r = ElementalCacheReward.roll('Fire', Random(seed));
        expect(r.gold, inInclusiveRange(1, 5));
        expect(r.powerupTotal, inInclusiveRange(1, 5));
        expect(r.staminaElixirs, inInclusiveRange(1, 5));
        expect(r.stabilizedHarvesters, 1);
        expect(r.fusionExtractors, inInclusiveRange(0, 1));
        expect(
          r.powerups.keys.every(kCachePowerupKeys.contains),
          isTrue,
          reason: 'unexpected powerup key in ${r.powerups}',
        );
      }
    });

    test('the fusion extractor is a chance, not a guarantee', () {
      var withExtractor = 0;
      const trials = 2000;
      for (var seed = 0; seed < trials; seed++) {
        if (ElementalCacheReward.roll('Ice', Random(seed)).fusionExtractors >
            0) {
          withExtractor++;
        }
      }
      final rate = withExtractor / trials;
      expect(rate, greaterThan(0.12));
      expect(rate, lessThan(0.30));
    });

    test('item grants collapse into one inventory-ready map', () {
      final r = ElementalCacheReward(
        element: 'Dark',
        gold: 3,
        powerups: {InvKeys.powerupSpeed: 2, InvKeys.powerupBeauty: 1},
        staminaElixirs: 4,
        stabilizedHarvesters: 1,
        fusionExtractors: 1,
      );

      expect(r.itemGrants, {
        InvKeys.powerupSpeed: 2,
        InvKeys.powerupBeauty: 1,
        InvKeys.staminaPotion: 4,
        InvKeys.harvesterGuaranteed: 1,
        InvKeys.instantHatch: 1,
      });
      expect(r.powerupTotal, 3);
    });
  });
}
