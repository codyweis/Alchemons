import 'dart:convert';
import 'dart:io';

import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/home_biome.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// A Horn on the same ground as a Let now and then charges it (home life):
// the Let runs, leaps back over the Horn, three passes, and both go home.
// Never across a gap (the Sky's isles), never at night, never two Horns.
void main() {
  final json =
      jsonDecode(
            File('assets/data/alchemons_creatures.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  Creature species(String id) => Creature.fromJson(
    (json['creatures'] as List).cast<Map<String, dynamic>>().firstWhere(
      (c) => c['id'] == id,
    ),
  );

  Future<SceneGame> mount(
    WidgetTester tester,
    HomeBiomeLayout layout,
    Map<String, String> who, {
    double hour = 12,
  }) async {
    tester.view.physicalSize = const Size(915, 412) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final game = SceneGame(scene: layout.scene((_) => false), showcase: true)
      ..fieldHourOverride = hour
      ..lively = true;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: GameWidget(game: game),
      ),
    );
    for (var i = 0; i < 40 && !game.isLoaded; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 33));
    }
    for (final r in layout.residents) {
      await game.showResident(r.spawnId, species(who[r.instanceId]!));
    }
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 33));
    }
    return game;
  }

  Future<void> run(
    WidgetTester tester,
    double seconds, [
    void Function()? each,
  ]) async {
    for (var i = 0; i < seconds * 30; i++) {
      await tester.pump(const Duration(milliseconds: 33));
      each?.call();
    }
  }

  HomeBiomeLayout pair(HomeRealm realm) => HomeBiomeLayout(
    realm: realm,
    pieces: {realm.name: const []},
    residents: const [
      HomeResident(instanceId: 'h', x: 0.10),
      HomeResident(instanceId: 'l', x: 0.15),
    ],
  );

  testWidgets('the Horn charges, the Let runs and leaps, and both go home', (
    tester,
  ) async {
    final game = await mount(tester, pair(HomeRealm.valley), {
      'h': 'HOR01',
      'l': 'LET01',
    });
    expect(game.debugChase('HOME_h'), isTrue);
    var most = 0;
    var leapt = false;
    var highest = 0.0;
    await run(tester, 14, () {
      final c = game.debugChaseOf('HOME_h');
      if (c != null) {
        most = c.passes > most ? c.passes : most;
        if (c.stage == 2) leapt = true;
      }
      final l = game.debugLifeOffset('HOME_l');
      if (l != null && -l.dy > highest) highest = -l.dy;
      for (final id in const ['HOME_h', 'HOME_l']) {
        final o = game.debugLifeOffset(id);
        if (o == null) continue;
        expect(o.dx.abs(), lessThan(460), reason: "$id on its ground");
      }
    });
    expect(leapt, isTrue, reason: 'the Let leapt over the Horn');
    expect(highest, greaterThan(30), reason: 'up over its head');
    expect(most, 3);
    expect(game.debugChaseOf('HOME_h'), isNull, reason: 'it gave up');
    expect(game.debugChaseOf('HOME_l'), isNull);
    // And straight after, not again: it rests between chases.
    expect(game.debugChase('HOME_h'), isTrue, reason: 'forced is allowed');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('no chase between two Horns, nor at night', (tester) async {
    final horns = await mount(tester, pair(HomeRealm.valley), {
      'h': 'HOR01',
      'l': 'HOR02',
    });
    expect(horns.debugChase('HOME_h'), isFalse);
    await tester.pumpWidget(const SizedBox());

    final night = await mount(tester, pair(HomeRealm.valley), {
      'h': 'HOR01',
      'l': 'LET01',
    }, hour: 23);
    await run(tester, 3);
    // Asleep, the Let is not to be chased.
    expect(night.debugChase('HOME_h'), isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('not across the gap between two isles', (tester) async {
    final game = await mount(
      tester,
      HomeBiomeLayout(
        realm: HomeRealm.sky,
        pieces: const {'sky': []},
        residents: const [
          HomeResident(instanceId: 'h', x: 0.10),
          HomeResident(instanceId: 'l', x: 0.18),
        ],
      ),
      {'h': 'HOR01', 'l': 'LET01'},
    );
    expect(game.debugChase('HOME_h'), isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
