// The wild map: a field of grains a finger stirs. Taps find the realm they
// land on, a swipe moves the grains and they settle back where they were,
// lightning comes with a storm, and a frame stays a few blur-free draws.

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
}) => WildMapField()
  ..weather = weather
  ..ready = ready
  ..arcane = arcane
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
    final f = _field();
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
    // The four realms' still grains, the cloud, the tree and Arcane; no
    // rims, with nothing waiting.
    expect(f.debugPictures, 7);
    final rest = f.debugGrains;
    expect(rest, lessThan(4000), reason: 'only the meadow, lava and movers');

    final v = _centreOf(WildRealm.valley);
    for (var i = 0; i < 6; i++) {
      f
        ..stir(v + Offset(i * 8.0, 0), const Offset(8, 0), 1 / 60)
        ..step(1 / 60);
    }
    f.paint(_CensusCanvas());
    // A finger in the Valley wakes its own grains and rim, and whatever
    // its wake spreads to, but not the whole map.
    expect(f.debugPictures, inInclusiveRange(4, 6));
    expect(f.debugGrains, greaterThan(rest * 2));

    for (var i = 0; i < 300; i++) {
      f.step(1 / 60);
    }
    f.paint(_CensusCanvas());
    expect(f.debugPictures, 7, reason: 'settled, it goes back to pictures');
  });

  test('a realm with something waiting has its rim drawn live, to pulse', () {
    final f = _field(ready: {'swamp'});
    f
      ..step(1 / 60)
      ..paint(_CensusCanvas());
    // The swamp's rim is live; the others are not drawn at all. The still
    // grains, the cloud and the tree are pictures (Arcane is closed).
    expect(f.debugPictures, 6);
    expect(f.debugGrains, greaterThan(500), reason: 'the swamp rim, live');
  });

  test('a storm over the Sky brings lightning; clear skies never do', () {
    final clear = _field();
    final storm = _field(weather: {'sky': WeatherKind.storm});
    var struck = false;
    for (var i = 0; i < 60 * 8; i++) {
      clear.step(1 / 60);
      storm.step(1 / 60);
      expect(clear.debugStriking, isFalse);
      if (storm.debugStriking) struck = true;
    }
    expect(struck, isTrue);
  });

  test('a frame is a handful of draws and never a blur', () {
    for (final (weather, ink) in [
      (const <String, WeatherKind>{}, false),
      ({'sky': WeatherKind.storm}, false),
      ({'valley': WeatherKind.rain}, false),
      ({'valley': WeatherKind.snow}, true),
      ({'swamp': WeatherKind.dry}, true),
    ]) {
      final f = _field(weather: weather, ready: {'valley'}, arcane: true)
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
