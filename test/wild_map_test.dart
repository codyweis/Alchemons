// The wild map: a field of grains a finger stirs. Taps find the realm they
// land on, a swipe moves the grains and they settle back where they were,
// a realm is dust until something waits in it and then gathers into its
// shape, each realm shows its state (lightning in a storm, the Volcano's
// mood, the rainbow rain leaves), and a frame stays a few blur-free draws.

import 'dart:math' as math;

import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/widgets/wilderness/wild_map.dart';
import 'package:alchemons/widgets/wilderness/wild_map_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what a frame asks the GPU to do.
class _CensusCanvas implements Canvas {
  final Map<String, int> counts = {};
  int blurredDraws = 0;

  @override
  dynamic noSuchMethod(Invocation i) {
    final n = i.memberName.toString();
    final key = n.substring(8, n.length - 2);
    counts[key] = (counts[key] ?? 0) + 1;
    for (final a in i.positionalArguments) {
      if (a is Paint && a.maskFilter != null) blurredDraws++;
    }
    if (key == 'getSaveCount') return 1;
    return null;
  }

  int get draws => counts.entries
      .where((e) => e.key.startsWith('draw'))
      .fold(0, (s, e) => s + e.value);
}

const _size = Size(390, 620);

WildMapField _field({
  Map<String, WeatherKind> weather = const {},
  Set<String> ready = const {},
  bool arcane = false,
  WildVolcano volcano = WildVolcano.still,
  bool rainbow = false,
}) => WildMapField()
  ..weather = weather
  ..ready = ready
  ..arcane = arcane
  ..volcano = volcano
  ..rainbow = rainbow
  ..layout(_size)
  ..settle();

Offset _centreOf(WildRealm r) => Offset(_size.width * r.x, _size.height * r.y);

void main() {
  test('a tap finds the realm it lands on, and the dark between is none', () {
    final f = _field(arcane: true);
    for (final r in WildRealm.values) {
      expect(f.sceneAt(_centreOf(r)), r.sceneId);
    }
    expect(f.sceneAt(f.riftRect.center), 'arcane');
    expect(f.sceneAt(const Offset(195, 4)), isNull);
    // Without Arcane open, its spot is empty.
    expect(_field().sceneAt(f.riftRect.center), isNull);
  });

  test('a swipe moves the grains, and they settle back', () {
    // The Valley in its shape: as dust it would drift on round.
    final f = _field(ready: {'valley'});
    final v = _centreOf(WildRealm.valley);
    f.step(1 / 60);
    final before = f.debugGrainNear(v);
    for (var i = 0; i < 12; i++) {
      f
        ..stir(v + Offset(-40 + i * 7.0, 0), const Offset(7, 0), 1 / 60)
        ..step(1 / 60);
    }
    expect(f.debugDisplacement, greaterThan(4));
    for (var i = 0; i < 240; i++) {
      f.step(1 / 60);
    }
    expect(f.debugDisplacement, lessThan(0.05));
    expect(
      (f.debugGrainNear(v) - before).distance,
      lessThan(4),
      reason: 'only its own sway away from where it began',
    );
  });

  test('at rest it draws from pictures; stirred, from live grains', () {
    final f = _field(arcane: true);
    for (var i = 0; i < 3; i++) {
      f.step(1 / 60);
      f.paint(_CensusCanvas());
    }
    // The sand; the dust of the realms' still grains, the cloud and the
    // tree, three layers each (the Sky has no still grains); and Arcane. No
    // rims, with nothing waiting.
    expect(f.debugPictures, 1 + 5 * 3 + 1);
    final rest = f.debugGrains;
    expect(rest, lessThan(4000), reason: 'only the meadow, lava and movers');

    final v = _centreOf(WildRealm.valley);
    for (var i = 0; i < 6; i++) {
      f
        ..stir(v + Offset(i * 8.0, 0), const Offset(8, 0), 1 / 60)
        ..step(1 / 60);
    }
    f.paint(_CensusCanvas());
    // A finger in the Valley wakes its own dust and the sand, and whatever
    // its wake spreads to, but not the whole map.
    expect(f.debugPictures, inInclusiveRange(10, 13));
    expect(f.debugGrains, greaterThan(rest * 2));

    for (var i = 0; i < 300; i++) {
      f.step(1 / 60);
    }
    f.paint(_CensusCanvas());
    expect(
      f.debugPictures,
      1 + 5 * 3 + 1,
      reason: 'settled, it goes back to pictures',
    );
  });

  test(
    'a short stroke redraws only the chunks it pushed, the same as whole',
    () {
      // A stroke across one corner of the Valley in its shape: the rest of
      // the realm's grains stay in their chunks' pictures.
      final f = _field(arcane: true, ready: {'valley'});
      final v = _centreOf(WildRealm.valley);
      f.step(1 / 60);
      for (var i = 0; i < 4; i++) {
        f
          ..stir(v + Offset(-60 + i * 6.0, -50), const Offset(6, 0), 1 / 60)
          ..step(1 / 60);
      }
      f.paint(_CensusCanvas());
      expect(f.debugChunkPictures, greaterThan(0));
      final pushed = f.debugGrains;

      // The same stroke on a twin field, then that field stirred everywhere:
      // a corner costs far less than the whole.
      final whole = _field(arcane: true, ready: {'valley'})..step(1 / 60);
      for (var i = 0; i < 40; i++) {
        whole
          ..stir(
            Offset(10 + i * 9.0, 40 + i * 13.0),
            const Offset(9, 13),
            1 / 60,
          )
          ..step(1 / 60);
      }
      whole.paint(_CensusCanvas());
      expect(pushed * 2, lessThan(whole.debugGrains));

      // Settled, every chunk is back in its picture and the group too.
      for (var i = 0; i < 300; i++) {
        f.step(1 / 60);
      }
      f.paint(_CensusCanvas());
      // The sand, the Valley whole, the others' dust in layers, Arcane.
      expect(f.debugPictures, 1 + 1 + 4 * 3 + 1);
      expect(f.debugChunkPictures, 0);
    },
  );

  test('a realm with something waiting has its rim drawn live, to pulse', () {
    final f = _field(ready: {'swamp'});
    f
      ..step(1 / 60)
      ..paint(_CensusCanvas());
    // The swamp's rim is live; the others are not drawn at all. The sand,
    // the swamp's still grains and its tree are one picture each; the
    // Valley, the Volcano and the cloud are dust, three layers each
    // (Arcane is closed).
    expect(f.debugPictures, 1 + 1 + 1 + 3 * 3);
    expect(f.debugGrains, greaterThan(500), reason: 'the swamp rim, live');
  });

  test('a storm over the Sky brings lightning; clear skies never do', () {
    final clear = _field(ready: {'sky'});
    final storm = _field(weather: {'sky': WeatherKind.storm}, ready: {'sky'});
    // A bolt drops out of the cloud's base: a Sky that is only dust has
    // none, though it flickers.
    final dust = _field(weather: {'sky': WeatherKind.storm});
    var struck = false, flickered = false;
    for (var i = 0; i < 60 * 8; i++) {
      clear.step(1 / 60);
      storm.step(1 / 60);
      dust.step(1 / 60);
      expect(clear.debugStriking, isFalse);
      expect(dust.debugStriking, isFalse);
      if (storm.debugStriking) struck = true;
      if (dust.debugFlickering) flickered = true;
    }
    expect(struck, isTrue);
    expect(flickered, isTrue);
  });

  test('a storm flickers inside its cloud between strikes, often', () {
    final clear = _field();
    final storm = _field(weather: {'sky': WeatherKind.storm});
    var flickers = 0, lit = false;
    for (var i = 0; i < 60 * 6; i++) {
      clear.step(1 / 60);
      storm.step(1 / 60);
      expect(clear.debugFlickering, isFalse);
      if (storm.debugFlickering && !lit) flickers++;
      lit = storm.debugFlickering;
    }
    // One every 0.35–1.45 s: a storm cloud is never long dark.
    expect(flickers, greaterThanOrEqualTo(4));
  });

  test("the Volcano shows its mood: still, smoking or erupting", () {
    ({int bombs, int smoke}) seen(WildVolcano v, {bool shaped = true}) {
      final f = _field(volcano: v, ready: shaped ? {'volcano'} : {});
      var bombs = 0, smoke = 0;
      for (var i = 0; i < 60 * 3; i++) {
        f
          ..step(1 / 60)
          ..paint(_CensusCanvas());
        bombs = math.max(bombs, f.debugBombs);
        smoke = math.max(smoke, f.debugSmoke);
      }
      return (bombs: bombs, smoke: smoke);
    }

    final still = seen(WildVolcano.still);
    expect(still.bombs, 0);
    expect(still.smoke, 0);
    final smoking = seen(WildVolcano.smoking);
    expect(smoking.bombs, 0, reason: 'smoke, but nothing thrown');
    expect(smoking.smoke, greaterThan(50));
    final erupting = seen(WildVolcano.erupting);
    expect(erupting.bombs, greaterThan(50));
    expect(erupting.smoke, greaterThan(50));
    // Thrown out of the crater: none while the Volcano is only dust.
    final dust = seen(WildVolcano.erupting, shaped: false);
    expect(dust.bombs + dust.smoke, 0);
  });

  test('Arcane takes a green rim when something waits in it', () {
    int pictures(WildMapField f) {
      f
        ..step(1 / 60)
        ..paint(_CensusCanvas());
      return f.debugPictures;
    }

    final waiting = _field(arcane: true, ready: {'arcane'});
    final quiet = _field(arcane: true);
    final closed = _field(ready: {'arcane'});
    // Its rim is the one group drawn live; quiet, there is none; closed,
    // nothing of Arcane at all.
    expect(pictures(quiet), 17);
    expect(pictures(waiting), 17);
    expect(waiting.debugGrains, greaterThan(quiet.debugGrains + 300));
    expect(pictures(closed), 16);
    expect(closed.debugGrains, quiet.debugGrains);
  });

  test(
    "Arcane's sky: meteors in a shower, curtains in the northern lights",
    () {
      ({int meteors, int sky}) seen(WildMapField f) {
        var meteors = 0, sky = 0;
        for (var i = 0; i < 60 * 3; i++) {
          f
            ..step(1 / 60)
            ..paint(_CensusCanvas());
          meteors = math.max(meteors, f.debugMeteors);
          sky = math.max(sky, f.debugArcaneSky);
        }
        return (meteors: meteors, sky: sky);
      }

      final clear = seen(_field(arcane: true));
      expect(clear.meteors, 0);
      expect(clear.sky, 0);
      final shower = seen(
        _field(arcane: true, weather: {'arcane': WeatherKind.meteors}),
      );
      expect(shower.meteors, greaterThanOrEqualTo(2), reason: 'a shower');
      final aurora = seen(
        _field(arcane: true, weather: {'arcane': WeatherKind.aurora}),
      );
      expect(aurora.meteors, 0);
      expect(aurora.sky, greaterThan(400));
      // Closed, its weather shows nowhere.
      final closed = seen(_field(weather: {'arcane': WeatherKind.meteors}));
      expect(closed.meteors + closed.sky, 0);
    },
  );

  test('the rainbow shows only while the Valley is clear', () {
    int bow(WildMapField f) {
      f
        ..step(1 / 60)
        ..paint(_CensusCanvas());
      return f.debugRainbow;
    }

    expect(bow(_field(ready: {'valley'})), 0);
    expect(bow(_field(rainbow: true, ready: {'valley'})), greaterThan(300));
    // Owed, but raining again: it waits for the rain to pass.
    expect(
      bow(
        _field(
          rainbow: true,
          weather: {'valley': WeatherKind.rain},
          ready: {'valley'},
        ),
      ),
      0,
    );
    // It stands before the mountains: none while they are only dust.
    expect(bow(_field(rainbow: true)), 0);
  });

  group('dust and shape', () {
    int turns(WildMapField f) {
      final c = _CensusCanvas();
      f
        ..step(1 / 60)
        ..paint(c);
      return c.counts['rotate'] ?? 0;
    }

    test('a realm is dust until something waits in it, then gathers', () {
      final f = _field();
      expect(f.debugFormOf(WildRealm.valley), 0);
      f.ready = {'valley'};
      for (var i = 0; i < 60; i++) {
        f.step(1 / 60);
      }
      // On its way: drawn grain by grain, no picture of the Valley.
      expect(f.debugFormOf(WildRealm.valley), inExclusiveRange(0, 1));
      f.paint(_CensusCanvas());
      expect(f.debugPictures, 1 + 4 * 3);
      for (var i = 0; i < 60; i++) {
        f.step(1 / 60);
      }
      expect(f.debugFormOf(WildRealm.valley), 1);
      expect(f.debugFormOf(WildRealm.sky), 0, reason: 'nothing in the Sky');
      f.paint(_CensusCanvas());
      expect(f.debugPictures, 1 + 1 + 4 * 3, reason: 'its shape, one picture');

      // Emptied, it comes apart again.
      f.ready = {};
      for (var i = 0; i < 120; i++) {
        f.step(1 / 60);
      }
      expect(f.debugFormOf(WildRealm.valley), 0);
      f.paint(_CensusCanvas());
      expect(f.debugPictures, 1 + 5 * 3);
    });

    test('an opened map gathers its waiting realms after a moment', () {
      final f = WildMapField()
        ..ready = {'swamp'}
        ..layout(_size)
        ..settle(gather: true);
      expect(f.debugFormOf(WildRealm.swamp), 0, reason: 'it opens as dust');
      for (var i = 0; i < 18; i++) {
        f.step(1 / 60);
      }
      expect(f.debugFormOf(WildRealm.swamp), 0, reason: 'a moment first');
      for (var i = 0; i < 130; i++) {
        f.step(1 / 60);
      }
      expect(f.debugFormOf(WildRealm.swamp), 1);
      expect(f.debugFormOf(WildRealm.volcano), 0);
    });

    test('dust drifts round in layers; a shape holds still', () {
      // Arcane's turn is the one other.
      final dust = _field(arcane: true);
      expect(turns(dust), 5 * 3 + 1);
      final shaped = _field(
        arcane: true,
        ready: {'valley', 'sky', 'volcano', 'swamp'},
      );
      expect(turns(shaped), 1);
    });

    test('a finger stirs the dust, and it settles back into its drift', () {
      final f = _field();
      final v = _centreOf(WildRealm.valley);
      f.step(1 / 60);
      for (var i = 0; i < 12; i++) {
        f
          ..stir(v + Offset(-40 + i * 7.0, 0), const Offset(7, 0), 1 / 60)
          ..step(1 / 60);
      }
      expect(f.debugDisplacement, greaterThan(4));
      for (var i = 0; i < 240; i++) {
        f.step(1 / 60);
      }
      expect(f.debugDisplacement, lessThan(0.05));
      f.paint(_CensusCanvas());
      expect(f.debugPictures, 1 + 5 * 3);
    });
  });

  test('a frame is a handful of draws and never a blur', () {
    for (final (weather, ink, volcano, rainbow) in [
      (const <String, WeatherKind>{}, false, WildVolcano.still, true),
      ({'sky': WeatherKind.storm}, false, WildVolcano.erupting, false),
      ({'arcane': WeatherKind.meteors}, false, WildVolcano.still, false),
      ({'arcane': WeatherKind.aurora}, true, WildVolcano.smoking, true),
      ({'valley': WeatherKind.rain}, false, WildVolcano.smoking, false),
      ({'valley': WeatherKind.snow}, true, WildVolcano.erupting, false),
      ({'swamp': WeatherKind.dry}, true, WildVolcano.still, true),
    ]) {
      final f =
          _field(
              weather: weather,
              ready: {'valley', 'arcane'},
              arcane: true,
              volcano: volcano,
              rainbow: rainbow,
            )
            ..ink = ink
            ..debugStrike();
      for (var i = 0; i < 10; i++) {
        f.step(1 / 60);
      }
      final c = _CensusCanvas();
      f.paint(c);
      expect(c.blurredDraws, 0, reason: '$weather');
      expect(c.draws, lessThan(40), reason: '$weather: ${c.counts}');
    }
  });

  group('on screen', () {
    Future<({List<String> entered, List<String> peeked})> pumpMap(
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = _size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final entered = <String>[], peeked = <String>[];
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.fromSize(
            size: _size,
            child: WildMapView(
              arcane: true,
              onEnter: entered.add,
              onPeek: peeked.add,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      return (entered: entered, peeked: peeked);
    }

    testWidgets('tapping a realm, or Arcane\'s circle, goes in', (
      tester,
    ) async {
      final m = await pumpMap(tester);
      await tester.tapAt(_centreOf(WildRealm.volcano));
      await tester.pump();
      // The edge of a circle still counts.
      await tester.tapAt(_centreOf(WildRealm.sky) + const Offset(0, 80));
      await tester.pump();
      await tester.tapAt(Offset(_size.width / 2, _size.height / 2));
      await tester.pump();
      expect(m.entered, ['volcano', 'sky', 'arcane']);
    });

    testWidgets('a swipe stirs it and goes in nowhere', (tester) async {
      final m = await pumpMap(tester);
      await tester.dragFrom(_centreOf(WildRealm.valley), const Offset(150, 30));
      await tester.pump(const Duration(milliseconds: 300));
      expect(m.entered, isEmpty);
    });

    testWidgets('a long press peeks', (tester) async {
      final m = await pumpMap(tester);
      await tester.longPressAt(_centreOf(WildRealm.swamp));
      await tester.pump();
      expect(m.peeked, ['swamp']);
      expect(m.entered, isEmpty);
    });
  });
}
