// Creatures in a field must make sense where they are: only those that can
// fly or float are ever put in the open air, and anything standing has
// something under its feet. These pin that for each field drawn in code —
// the Valley, the Sky, the Swamp, the Volcano and the Arcane — and the rule
// every redesigned field follows.

import 'dart:ui';

import 'package:alchemons/games/wilderness/field/grain_field.dart';
import 'package:alchemons/games/wilderness/field/field_art.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/encounters/pools/arcane_pool.dart';
import 'package:alchemons/models/encounters/pools/dunes_pool.dart';
import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/models/encounters/pools/sky_pool.dart';
import 'package:alchemons/models/encounters/pools/swamp_pool.dart';
import 'package:alchemons/models/encounters/pools/valley_pool.dart';
import 'package:alchemons/models/encounters/pools/volcano_pool.dart';
import 'package:alchemons/models/scenes/arcane/arcane_scene.dart';
import 'package:alchemons/models/scenes/dunes/dunes_scene.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:alchemons/models/scenes/sky/sky_scene.dart';
import 'package:alchemons/models/scenes/swamp/swamp_scene.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:alchemons/models/scenes/volcano/volcano_scene.dart';
import 'package:alchemons/services/encounter_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only wings, Air, Steam and Lightning may float', () {
    for (final id in [
      'WNG01',
      'WNG03',
      'WNG12',
      'LET04',
      'KIN04',
      'LET05',
      'PIP07',
      'LET07',
    ]) {
      expect(speciesCanFloat(id), isTrue, reason: id);
    }
    for (final id in ['HOR03', 'LET03', 'MAN12', 'KIN01', 'LET16', 'MYS15']) {
      expect(speciesCanFloat(id), isFalse, reason: id);
    }
  });

  void onlyFloatersAloft(
    String name,
    SceneDefinition scene,
    ({EncounterPool sceneWide, Map<String, EncounterPool> perSpawn}) Function(
      SceneDefinition,
    )
    pools,
  ) {
    test('every $name open-air point can only roll creatures that float', () {
      final tables = pools(scene);
      final sky = scene.spawnPoints.where((p) => p.aloft);
      expect(sky, isNotEmpty);
      for (final p in sky) {
        final pool = poolForSpawn(
          spawnId: p.id,
          sceneWide: tables.sceneWide,
          perSpawn: tables.perSpawn,
        ).where((e) => speciesCanFloat(e.speciesId));
        expect(pool.isEmpty, isFalse, reason: '${p.id} has nothing to roll');

        final service = EncounterService(
          scene: scene,
          party: const [],
          tableBuilder: pools,
          seed: 7,
        );
        for (var i = 0; i < 200; i++) {
          final roll = service.roll(spawnId: p.id);
          expect(speciesCanFloat(roll.speciesId), isTrue, reason: p.id);
        }
      }
    });
  }

  onlyFloatersAloft('Valley', valleySceneCorrected, valleyEncounterPools);
  onlyFloatersAloft('Sky', skyScene, skyEncounterPools);
  onlyFloatersAloft('Swamp', swampScene, swampEncounterPools);
  onlyFloatersAloft('Volcano', volcanoScene, volcanoEncounterPools);
  onlyFloatersAloft('Dunes', dunesScene, dunesEncounterPools);

  test('the sandstorm brings only what the Dunes\' air points can take '
      'there, and stands the rest on the sand', () {
    for (final e in dunesSandstorm.pool.entries) {
      // Air and Lightning: every one of them floats.
      expect(speciesCanFloat(e.speciesId), isTrue, reason: e.speciesId);
    }
  });

  // ── The Dunes: sand underfoot, dunes rising, a rock under the high point ──

  double dunesPeriod(SceneLayer layer) =>
      dunesScene.worldWidth *
      (1 + dunesScene.layers.firstWhere((l) => l.id == layer).parallaxFactor);

  DunesField builtDunes(double h) {
    final field = DunesField()
      ..layout(
        dunesScene.spawnPoints,
        dunesScene.worldWidth,
        loop: dunesScene.loop,
      );
    final screen = Size(h * 1.6, h);
    for (final layer in [
      SceneLayer.layer2,
      SceneLayer.layer3,
      SceneLayer.layer4,
      SceneLayer.layer5,
    ]) {
      field.build(layer, Size(dunesPeriod(layer), h), screen);
    }
    return field;
  }

  for (final h in const [412.0, 475.0, 700.0]) {
    test('every Dunes standing point has sand or rock under it at $h', () {
      final field = builtDunes(h);
      for (final p in dunesScene.spawnPoints.where((p) => !p.aloft)) {
        final x = p.normalizedPos.dx * dunesPeriod(p.anchor);
        final feet = p.normalizedPos.dy * h + p.size.y * 0.42;
        final ground = field.groundAt(p.anchor, x);
        expect(ground, isNotNull, reason: '${p.id} has no ground');
        final perch = field.perchFor(p.id);
        if (perch != null) {
          // On its rock: the rock's top is where its feet are.
          expect(perch, closeTo(feet, 1e-6), reason: p.id);
          expect(ground!.rest, closeTo(feet, 2 * h / 475), reason: p.id);
        } else {
          // In the sand, or on a dune risen to meet it: never over the air.
          expect(feet, greaterThan(ground!.top), reason: p.id);
        }
      }
    });

    test('every Dunes encounter partner has ground at $h', () {
      final field = builtDunes(h);
      for (final p in dunesScene.spawnPoints) {
        final x =
            p.normalizedPos.dx * dunesPeriod(p.anchor) +
            p.partnerSide * kFieldPairGap;
        expect(field.groundAt(p.anchor, x), isNotNull, reason: p.id);
      }
    });
  }

  test('the Dunes high point is the only one with a rock under it', () {
    final field = builtDunes(475);
    final perched = [
      for (final p in dunesScene.spawnPoints)
        if (field.perchFor(p.id) != null) p.id,
    ];
    expect(perched, ['SP_dunes_05']);
  });

  test('sky points sit on a layer with ground, for a partner who cannot '
      'float', () {
    for (final p in valleySceneCorrected.spawnPoints.where((p) => p.aloft)) {
      expect(
        p.anchor,
        anyOf(SceneLayer.layer3, SceneLayer.layer4),
        reason: p.id,
      );
    }
  });

  // The Valley loops: each layer is built one loop wide, worldWidth × (1 +
  // its parallax factor), and a spawn's x is a share of that.
  double period(SceneLayer layer) =>
      valleySceneCorrected.worldWidth *
      (1 +
          valleySceneCorrected.layers
              .firstWhere((l) => l.id == layer)
              .parallaxFactor);

  ValleyField builtValley(double h) {
    final field = ValleyField()
      ..layout(
        valleySceneCorrected.spawnPoints,
        valleySceneCorrected.worldWidth,
        loop: valleySceneCorrected.loop,
      );
    final screen = Size(h * 1.6, h);
    for (final layer in [SceneLayer.layer3, SceneLayer.layer4]) {
      field.build(layer, Size(period(layer), h), screen);
    }
    return field;
  }

  for (final h in const [412.0, 475.0, 700.0]) {
    test('every Valley ground point has something under its feet at $h', () {
      final field = builtValley(h);
      for (final p in valleySceneCorrected.spawnPoints.where((p) => !p.aloft)) {
        final x = p.normalizedPos.dx * period(p.anchor);
        final feet = p.normalizedPos.dy * h + p.size.y * 0.42;
        final perch = field.perchFor(p.id);
        if (perch != null) {
          expect(perch, closeTo(feet, 1), reason: '${p.id} perch');
          continue;
        }
        final ground = field.groundAt(p.anchor, x);
        expect(ground, isNotNull, reason: '${p.id} has no ground');
        expect(
          ground!.top,
          lessThanOrEqualTo(feet),
          reason: '${p.id}: feet at $feet, ground starts at ${ground.top}',
        );
      }
    });
  }

  test('the Valley joins round its loop without a seam', () {
    final field = builtValley(475);
    for (final layer in [SceneLayer.layer3, SceneLayer.layer4]) {
      final p = period(layer);
      for (var x = 0.0; x < p; x += p / 37) {
        expect(
          field.groundAt(layer, x + p)!.top,
          closeTo(field.groundAt(layer, x)!.top, 1e-6),
          reason: '$layer at $x',
        );
      }
    }
  });

  // ── The Sky: isles in the open air ───────────────────────────────────────

  double skyPeriod(SceneLayer layer) =>
      skyScene.worldWidth *
      (1 + skyScene.layers.firstWhere((l) => l.id == layer).parallaxFactor);

  SkyField builtSky(double h) {
    final field = SkyField()
      ..layout(skyScene.spawnPoints, skyScene.worldWidth, loop: skyScene.loop);
    final screen = Size(h * 1.6, h);
    for (final layer in [SceneLayer.layer3, SceneLayer.layer4]) {
      field.build(layer, Size(skyPeriod(layer), h), screen);
    }
    return field;
  }

  test('every Sky point is on the near or far isles\' layer', () {
    for (final p in skyScene.spawnPoints) {
      expect(
        p.anchor,
        anyOf(SceneLayer.layer3, SceneLayer.layer4),
        reason: p.id,
      );
    }
  });

  for (final h in const [412.0, 475.0, 700.0]) {
    test('every Sky standing point stands on its own isle at $h', () {
      final field = builtSky(h);
      for (final p in skyScene.spawnPoints.where((p) => !p.aloft)) {
        final x = p.normalizedPos.dx * skyPeriod(p.anchor);
        final feet = p.normalizedPos.dy * h + p.size.y * 0.42;
        expect(field.perchFor(p.id), closeTo(feet, 1e-6), reason: p.id);
        final ground = field.groundAt(p.anchor, x);
        expect(ground, isNotNull, reason: '${p.id} has no isle');
        expect(ground!.rest, closeTo(feet, 2 * h / 475), reason: p.id);
      }
    });

    test('every Sky encounter partner has an isle to stand on at $h', () {
      final field = builtSky(h);
      for (final p in skyScene.spawnPoints) {
        final x =
            p.normalizedPos.dx * skyPeriod(p.anchor) +
            p.partnerSide * kFieldPairGap;
        final ground = field.groundAt(p.anchor, x);
        expect(ground, isNotNull, reason: '${p.id} partner has no isle');
        // A partner that cannot float is stood on it, whatever its height;
        // one that can hangs at its battle position, just over it.
        expect(ground!.top, double.infinity, reason: p.id);
        final hang = p.getBattlePos().dy * h + p.size.y * 0.42;
        expect(ground.rest, greaterThan(hang), reason: '${p.id} hangs in it');
        expect(
          ground.rest - hang,
          lessThan(p.size.y * 0.2),
          reason: '${p.id} hangs too high over it',
        );
      }
    });

    test('no Sky isle overlaps another or an open-air point at $h', () {
      final field = builtSky(h);
      for (final layer in [SceneLayer.layer3, SceneLayer.layer4]) {
        final period = skyPeriod(layer);
        final isles = field.debugIsles(layer);
        double gap(Rect a, Rect b) {
          var d = (a.center.dx - b.center.dx) % period;
          if (d > period / 2) d -= period;
          return d.abs() - (a.width + b.width) / 2;
        }

        for (var i = 0; i < isles.length; i++) {
          for (var j = i + 1; j < isles.length; j++) {
            expect(
              gap(isles[i], isles[j]),
              greaterThan(8),
              reason: '$layer isles $i and $j',
            );
          }
        }
        for (final p in skyScene.spawnPoints.where(
          (p) => p.aloft && p.anchor == layer,
        )) {
          final body = Rect.fromCenter(
            center: Offset(p.normalizedPos.dx * period, p.normalizedPos.dy * h),
            width: p.size.x,
            height: p.size.y,
          );
          for (final isle in isles) {
            final overlapsX = gap(body, isle) < 0;
            expect(
              overlapsX && body.bottom > isle.top && body.top < isle.bottom,
              isFalse,
              reason: '${p.id} hangs inside an isle',
            );
          }
        }
      }
    });
  }

  test('the Sky joins round its loop without a seam', () {
    final field = builtSky(475);
    for (final layer in [SceneLayer.layer3, SceneLayer.layer4]) {
      final p = skyPeriod(layer);
      var isles = 0;
      for (var x = 0.0; x < p; x += p / 211) {
        final here = field.groundAt(layer, x);
        final round = field.groundAt(layer, x + p);
        expect(round?.rest, here == null ? isNull : closeTo(here.rest, 1e-6));
        if (here != null) isles++;
      }
      expect(isles, greaterThan(0), reason: '$layer has no isles');
    }
  });

  // ── The Swamp: banks and stones standing in the water ────────────────────

  double swampPeriod(SceneLayer layer) =>
      swampScene.worldWidth *
      (1 + swampScene.layers.firstWhere((l) => l.id == layer).parallaxFactor);

  SwampField builtSwamp(double h, {bool dry = false}) {
    final field = SwampField()
      ..weatherKind = dry ? WeatherKind.dry : null
      ..weather = dry ? 1 : 0
      ..layout(
        swampScene.spawnPoints,
        swampScene.worldWidth,
        loop: swampScene.loop,
      );
    final screen = Size(h * 1.6, h);
    for (final layer in [SceneLayer.layer3, SceneLayer.layer4]) {
      field.build(layer, Size(swampPeriod(layer), h), screen);
    }
    return field;
  }

  test('every Swamp point is on the near or back banks\' layer', () {
    for (final p in swampScene.spawnPoints) {
      expect(
        p.anchor,
        anyOf(SceneLayer.layer3, SceneLayer.layer4),
        reason: p.id,
      );
    }
  });

  for (final h in const [412.0, 475.0, 700.0]) {
    test('every Swamp standing point stands on its own bank at $h', () {
      final field = builtSwamp(h);
      for (final p in swampScene.spawnPoints.where(
        (p) => p.perch == SpawnPerch.ground,
      )) {
        final x = p.normalizedPos.dx * swampPeriod(p.anchor);
        final feet = p.normalizedPos.dy * h + p.size.y * 0.42;
        expect(field.perchFor(p.id), closeTo(feet, 1e-6), reason: p.id);
        final ground = field.groundAt(p.anchor, x);
        expect(ground, isNotNull, reason: '${p.id} has no bank');
        expect(ground!.rest, closeTo(feet, 2 * h / 475), reason: p.id);
      }
    });

    test('every Swamp encounter partner has a bank to stand on at $h', () {
      final field = builtSwamp(h);
      for (final p in swampScene.spawnPoints.where(
        (p) => p.perch != SpawnPerch.wade,
      )) {
        final x =
            p.normalizedPos.dx * swampPeriod(p.anchor) +
            p.partnerSide * kFieldPairGap;
        final ground = field.groundAt(p.anchor, x);
        expect(ground, isNotNull, reason: '${p.id} partner has no bank');
        // A partner that cannot float is stood on it, whatever its height;
        // one that can hangs at its battle position, just over it.
        expect(ground!.top, double.infinity, reason: p.id);
        final hang = p.getBattlePos().dy * h + p.size.y * 0.42;
        expect(ground.rest, greaterThan(hang), reason: '${p.id} hangs in it');
        expect(
          ground.rest - hang,
          lessThan(p.size.y * 0.2),
          reason: '${p.id} hangs too high over it',
        );
      }
    });

    test('the Swamp\'s water is not ground at $h', () {
      final field = builtSwamp(h);
      for (final layer in [SceneLayer.layer3, SceneLayer.layer4]) {
        final banks = field.debugBanks(layer);
        final period = swampPeriod(layer);
        var water = 0;
        for (var x = 0.0; x < period; x += period / 401) {
          final onBank = banks.any((b) {
            var d = (x - b.center.dx) % period;
            if (d > period / 2) d -= period;
            return d.abs() < b.width / 2;
          });
          if (onBank) continue;
          expect(field.groundAt(layer, x), isNull, reason: '$layer at $x');
          water++;
        }
        expect(water, greaterThan(100), reason: '$layer is all bank');
      }
    });

    test('no Swamp bank overlaps another or an open-air point at $h', () {
      final field = builtSwamp(h);
      for (final layer in [SceneLayer.layer3, SceneLayer.layer4]) {
        final period = swampPeriod(layer);
        final banks = field.debugBanks(layer);
        double gap(Rect a, Rect b) {
          var d = (a.center.dx - b.center.dx) % period;
          if (d > period / 2) d -= period;
          return d.abs() - (a.width + b.width) / 2;
        }

        for (var i = 0; i < banks.length; i++) {
          for (var j = i + 1; j < banks.length; j++) {
            expect(
              gap(banks[i], banks[j]),
              greaterThan(8),
              reason: '$layer banks $i and $j',
            );
          }
        }
        for (final p in swampScene.spawnPoints.where(
          (p) => p.aloft && p.anchor == layer,
        )) {
          final body = Rect.fromCenter(
            center: Offset(p.normalizedPos.dx * period, p.normalizedPos.dy * h),
            width: p.size.x,
            height: p.size.y,
          );
          for (final bank in banks) {
            final overlapsX = gap(body, bank) < 0;
            expect(
              overlapsX && body.bottom > bank.top && body.top < bank.bottom,
              isFalse,
              reason: '${p.id} hangs inside a bank',
            );
          }
        }
      }
    });
  }

  for (final h in const [412.0, 475.0, 700.0]) {
    test('gone dry, each pool point wades in its own pool and its partner '
        'stands on the dry floor at $h', () {
      final field = builtSwamp(h, dry: true);
      final wade = swampScene.spawnPoints.where(
        (p) => p.perch == SpawnPerch.wade,
      );
      expect(wade, isNotEmpty);
      for (final p in wade) {
        // There only when dry, and only for what wades.
        expect(p.onlyIn, WeatherKind.dry, reason: p.id);
        expect(p.takes('LET02'), isTrue);
        expect(p.takes('LET10'), isFalse);
        final period = swampPeriod(p.anchor);
        final x = p.normalizedPos.dx * period;
        final feet = p.normalizedPos.dy * h + p.size.y * 0.42;
        expect(field.perchFor(p.id), closeTo(feet, 1e-6), reason: p.id);
        final pool = field
            .debugPools(p.anchor)
            .firstWhere(
              (r) => (r.center.dx - x).abs() < 1,
              orElse: () => fail('${p.id} has no pool'),
            );
        expect(feet, inInclusiveRange(pool.top, pool.bottom), reason: p.id);
        // Nothing stands on a pool, and no pool runs into a bank.
        expect(field.groundAt(p.anchor, x), isNull, reason: p.id);
        for (final b in field.debugBanks(p.anchor)) {
          var d = (pool.center.dx - b.center.dx) % period;
          if (d > period / 2) d -= period;
          expect(
            d.abs() - (pool.width + b.width) / 2,
            greaterThan(4),
            reason: '${p.id} pool and a bank',
          );
        }
        // Its partner, a pace off, on the floor (or a bank).
        final px = x + p.partnerSide * kFieldPairGap;
        final ground = field.groundAt(p.anchor, px);
        expect(ground, isNotNull, reason: '${p.id} partner has no ground');
        final partnerFeet = p.getBattlePos().dy * h + p.size.y * 0.42;
        expect(
          ground!.top,
          lessThanOrEqualTo(partnerFeet),
          reason: '${p.id} partner in the air',
        );
      }
    });
  }

  test('the Swamp\'s floor is only ground when it has gone dry', () {
    final wet = builtSwamp(475), dry = builtSwamp(475, dry: true);
    final period = swampPeriod(SceneLayer.layer4);
    var floor = 0;
    for (var x = 0.0; x < period; x += period / 211) {
      if (wet.groundAt(SceneLayer.layer4, x) != null) continue;
      if (dry.groundAt(SceneLayer.layer4, x) != null) floor++;
    }
    expect(floor, greaterThan(50));
  });

  test('the Swamp joins round its loop without a seam', () {
    final field = builtSwamp(475);
    for (final layer in [SceneLayer.layer3, SceneLayer.layer4]) {
      final p = swampPeriod(layer);
      var banks = 0;
      for (var x = 0.0; x < p; x += p / 211) {
        final here = field.groundAt(layer, x);
        final round = field.groundAt(layer, x + p);
        expect(round?.rest, here == null ? isNull : closeTo(here.rest, 1e-6));
        if (here != null) banks++;
      }
      expect(banks, greaterThan(0), reason: '$layer has no banks');
    }
  });

  // ── The Volcano: shelves of rock standing in the lava ───────────────────

  double volcanoPeriod(SceneLayer layer) =>
      volcanoScene.worldWidth *
      (1 + volcanoScene.layers.firstWhere((l) => l.id == layer).parallaxFactor);

  VolcanoField builtVolcano(double h) {
    final field = VolcanoField()
      ..layout(
        volcanoScene.spawnPoints,
        volcanoScene.worldWidth,
        loop: volcanoScene.loop,
      );
    final screen = Size(h * 1.6, h);
    for (final layer in [SceneLayer.layer3, SceneLayer.layer4]) {
      field.build(layer, Size(volcanoPeriod(layer), h), screen);
    }
    return field;
  }

  test('every Volcano point is on the near or back shelves\' layer, and '
      'sits where the spawn service keeps its camera safe', () {
    final ids = volcanoScene.spawnPoints.map((p) => p.id).toSet();
    // The old points keep their ids; the tutorial's is among them.
    for (final id in ['01', '02', '03', '04', '05']) {
      expect(ids, contains('SP_volcano_$id'));
    }
    for (final p in volcanoScene.spawnPoints) {
      expect(
        p.anchor,
        anyOf(SceneLayer.layer3, SceneLayer.layer4),
        reason: p.id,
      );
      expect(p.normalizedPos.dx, inInclusiveRange(0.10, 0.90), reason: p.id);
    }
  });

  for (final h in const [412.0, 475.0, 700.0]) {
    test('every Volcano standing point stands on its own shelf at $h', () {
      final field = builtVolcano(h);
      for (final p in volcanoScene.spawnPoints.where((p) => !p.aloft)) {
        final x = p.normalizedPos.dx * volcanoPeriod(p.anchor);
        final feet = p.normalizedPos.dy * h + p.size.y * 0.42;
        expect(field.perchFor(p.id), closeTo(feet, 1e-6), reason: p.id);
        final ground = field.groundAt(p.anchor, x);
        expect(ground, isNotNull, reason: '${p.id} has no shelf');
        expect(ground!.rest, closeTo(feet, 2 * h / 475), reason: p.id);
      }
    });

    test('every Volcano encounter partner has a shelf to stand on at $h', () {
      final field = builtVolcano(h);
      for (final p in volcanoScene.spawnPoints) {
        final x =
            p.normalizedPos.dx * volcanoPeriod(p.anchor) +
            p.partnerSide * kFieldPairGap;
        final ground = field.groundAt(p.anchor, x);
        expect(ground, isNotNull, reason: '${p.id} partner has no shelf');
        // A partner that cannot float is stood on it, whatever its height;
        // one that can hangs at its battle position, just over it.
        expect(ground!.top, double.infinity, reason: p.id);
        final hang = p.getBattlePos().dy * h + p.size.y * 0.42;
        expect(ground.rest, greaterThan(hang), reason: '${p.id} hangs in it');
        expect(
          ground.rest - hang,
          lessThan(p.size.y * 0.2),
          reason: '${p.id} hangs too high over it',
        );
      }
    });

    test('the Volcano\'s lava is not ground at $h', () {
      final field = builtVolcano(h);
      for (final layer in [SceneLayer.layer3, SceneLayer.layer4]) {
        final shelves = field.debugShelves(layer);
        final period = volcanoPeriod(layer);
        var lava = 0;
        for (var x = 0.0; x < period; x += period / 401) {
          final onShelf = shelves.any((b) {
            var d = (x - b.center.dx) % period;
            if (d > period / 2) d -= period;
            return d.abs() < b.width / 2;
          });
          if (onShelf) continue;
          expect(field.groundAt(layer, x), isNull, reason: '$layer at $x');
          lava++;
        }
        expect(lava, greaterThan(100), reason: '$layer is all rock');
      }
    });

    test('no Volcano shelf overlaps another or an open-air point at $h', () {
      final field = builtVolcano(h);
      for (final layer in [SceneLayer.layer3, SceneLayer.layer4]) {
        final period = volcanoPeriod(layer);
        final shelves = field.debugShelves(layer);
        double gap(Rect a, Rect b) {
          var d = (a.center.dx - b.center.dx) % period;
          if (d > period / 2) d -= period;
          return d.abs() - (a.width + b.width) / 2;
        }

        for (var i = 0; i < shelves.length; i++) {
          for (var j = i + 1; j < shelves.length; j++) {
            expect(
              gap(shelves[i], shelves[j]),
              greaterThan(8),
              reason: '$layer shelves $i and $j',
            );
          }
        }
        for (final p in volcanoScene.spawnPoints.where(
          (p) => p.aloft && p.anchor == layer,
        )) {
          final body = Rect.fromCenter(
            center: Offset(p.normalizedPos.dx * period, p.normalizedPos.dy * h),
            width: p.size.x,
            height: p.size.y,
          );
          for (final shelf in shelves) {
            final overlapsX = gap(body, shelf) < 0;
            expect(
              overlapsX && body.bottom > shelf.top && body.top < shelf.bottom,
              isFalse,
              reason: '${p.id} hangs inside a shelf',
            );
          }
        }
      }
    });
  }

  test('the Volcano joins round its loop without a seam', () {
    final field = builtVolcano(475);
    for (final layer in [SceneLayer.layer3, SceneLayer.layer4]) {
      final p = volcanoPeriod(layer);
      var shelves = 0;
      for (var x = 0.0; x < p; x += p / 211) {
        final here = field.groundAt(layer, x);
        final round = field.groundAt(layer, x + p);
        expect(round?.rest, here == null ? isNull : closeTo(here.rest, 1e-6));
        if (here != null) shelves++;
      }
      expect(shelves, greaterThan(0), reason: '$layer has no shelves');
    }
  });

  // ── The Arcane: a mirror out to the dust band ────────────────────────────

  double arcanePeriod(SceneLayer layer) =>
      arcaneScene.worldWidth *
      (1 + arcaneScene.layers.firstWhere((l) => l.id == layer).parallaxFactor);

  ArcaneField builtArcane(double h) {
    final field = ArcaneField()
      ..layout(
        arcaneScene.spawnPoints,
        arcaneScene.worldWidth,
        loop: arcaneScene.loop,
      );
    final screen = Size(h * 1.6, h);
    for (final layer in [
      SceneLayer.layer2,
      SceneLayer.layer3,
      SceneLayer.layer4,
    ]) {
      field.build(layer, Size(arcanePeriod(layer), h), screen);
    }
    return field;
  }

  test('no Arcane point is in the open air: the only floaters it rolls are '
      'its legendary wings', () {
    final ids = arcaneScene.spawnPoints.map((p) => p.id).toSet();
    expect(ids, {'SP_arcane_01', 'SP_arcane_02', 'SP_arcane_03'});
    for (final p in arcaneScene.spawnPoints) {
      expect(p.aloft, isFalse, reason: p.id);
      expect(
        p.anchor,
        anyOf(SceneLayer.layer3, SceneLayer.layer4),
        reason: p.id,
      );
    }
    final pool = arcaneEncounterPools(arcaneScene).sceneWide.entries;
    final floaters = pool.where((e) => speciesCanFloat(e.speciesId));
    for (final e in floaters) {
      expect(e.speciesId, startsWith('WNG'), reason: e.speciesId);
      expect(e.rarity, EncounterRarity.legendary, reason: e.speciesId);
    }
  });

  for (final h in const [412.0, 475.0, 700.0]) {
    test('every Arcane creature and partner stands on the glass at $h', () {
      final field = builtArcane(h);
      final glass = field.debugGlassLine;
      for (final p in arcaneScene.spawnPoints) {
        final x = p.normalizedPos.dx * arcanePeriod(p.anchor);
        final feet = p.normalizedPos.dy * h + p.size.y * 0.42;
        expect(field.perchFor(p.id), closeTo(feet, 1e-6), reason: p.id);
        expect(feet, greaterThan(glass + 4), reason: '${p.id} over the band');
        final ground = field.groundAt(p.anchor, x);
        expect(ground, isNotNull, reason: '${p.id} has no ground');
        expect(ground!.top, lessThanOrEqualTo(feet), reason: p.id);
        // Its partner, a pace off, on the glass too.
        final px = x + p.partnerSide * kFieldPairGap;
        final partnerFeet = p.getBattlePos().dy * h + p.size.y * 0.42;
        final under = field.groundAt(p.anchor, px);
        expect(under, isNotNull, reason: '${p.id} partner has no ground');
        expect(
          under!.top,
          lessThanOrEqualTo(partnerFeet),
          reason: '${p.id} partner in the air',
        );
      }
    });

    test('the Arcane glass is ground everywhere nearer than the band, and '
        'gives back what stands on it, at $h', () {
      final field = builtArcane(h);
      for (final layer in [SceneLayer.layer3, SceneLayer.layer4]) {
        final period = arcanePeriod(layer);
        for (var x = 0.0; x < period * 2; x += period / 97) {
          final g = field.groundAt(layer, x);
          expect(g, isNotNull, reason: '$layer at $x');
          expect(g!.top, closeTo(field.debugGlassLine, 1e-6));
        }
        expect(field.reflectionAt(layer), greaterThan(0));
      }
      expect(field.groundAt(SceneLayer.layer2, 100), isNull);
      expect(field.reflectionAt(SceneLayer.layer2), 0);
    });

    test('no Arcane standing stone stands where a creature or its partner '
        'does at $h', () {
      final field = builtArcane(h);
      for (final layer in [SceneLayer.layer3, SceneLayer.layer4]) {
        final period = arcanePeriod(layer);
        double gap(double a, double aw, double b, double bw) {
          var d = (a - b) % period;
          if (d > period / 2) d -= period;
          return d.abs() - (aw + bw) / 2;
        }

        for (final p in arcaneScene.spawnPoints.where(
          (p) => p.anchor == layer,
        )) {
          final x = p.normalizedPos.dx * period;
          for (final spot in [x, x + p.partnerSide * kFieldPairGap]) {
            for (final stone in field.debugStones(layer)) {
              expect(
                gap(stone.center.dx, stone.width, spot, p.size.x),
                greaterThan(8),
                reason: '${p.id}: a stone at ${stone.center.dx}',
              );
            }
          }
        }
      }
    });
  }
}
