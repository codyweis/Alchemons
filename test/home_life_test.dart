import 'dart:convert';
import 'dart:io';

import 'package:alchemons/games/wilderness/keepsake_component.dart';
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/models/home_biome.dart';
import 'package:alchemons/widgets/fx/keepsake_art.dart';
import 'package:alchemons/widgets/wilderness/creature_sprite_component.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// The residents' life in the home biome (home_life.dart): left alone they
// walk their own ground and come back to it, stand still to be arranged,
// sleep at night, and walk through a pair of portals and home again.
void main() {
  final json =
      jsonDecode(File('assets/data/alchemons_creatures.json').readAsStringSync())
          as Map<String, dynamic>;
  Creature species(String id) => Creature.fromJson(
    (json['creatures'] as List).cast<Map<String, dynamic>>().firstWhere(
      (c) => c['id'] == id,
    ),
  );

  Future<SceneGame> mount(
    WidgetTester tester,
    HomeBiomeLayout layout, {
    double hour = 12,
    bool ghosts = false,
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
      await game.showResident(r.spawnId, species('HOR01'));
    }
    for (final p in layout.placed.where((p) => p.isKeepsake)) {
      final copy = int.tryParse(p.id.split('#').last) ?? 0;
      final art = KeepsakeArt.of(p.kind, copy: copy)!;
      game.showThing(
        p.spawnId,
        KeepsakeComponent(
          kind: p.kind,
          art: art,
          rowSize: 100,
          ghost: ghosts && p.trial,
        ),
        art.box,
      );
    }
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 33));
    }
    return game;
  }

  Future<void> run(WidgetTester tester, double seconds,
      [void Function()? each]) async {
    for (var i = 0; i < seconds * 30; i++) {
      await tester.pump(const Duration(milliseconds: 33));
      each?.call();
    }
  }

  const two = HomeBiomeLayout(
    realm: HomeRealm.valley,
    pieces: {'valley': []},
    residents: [
      HomeResident(instanceId: 'a', x: 0.10),
      HomeResident(instanceId: 'b', x: 0.22),
    ],
  );

  testWidgets('left alone they walk their own ground and keep to it', (
    tester,
  ) async {
    final game = await mount(tester, two);
    var moved = false;
    await run(tester, 40, () {
      for (final id in const ['HOME_a', 'HOME_b']) {
        final o = game.debugLifeOffset(id);
        if (o == null) continue;
        if (o.dx.abs() > 4) moved = true;
        // Never further than its own stretch of ground.
        expect(o.dx.abs(), lessThan(170), reason: id);
        expect(o.dy.abs(), lessThan(30), reason: id);
      }
    });
    expect(moved, isTrue, reason: 'someone went for a stroll');

    // Arranging, everyone is back at their spot at once.
    game.arranging = true;
    await run(tester, 0.1);
    expect(game.debugLifeOffset('HOME_a'), isNull);
    expect(game.debugLifeOffset('HOME_b'), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('at night what stands falls asleep', (tester) async {
    final game = await mount(tester, two, hour: 23.5);
    await run(tester, 2);
    for (final c in game.debugResidents.values) {
      final sprite = c.children.whereType<CreatureSpriteComponent>().first;
      expect(sprite.animating, isFalse);
    }
    game.fieldHourOverride = 12;
    await run(tester, 2);
    for (final c in game.debugResidents.values) {
      final sprite = c.children.whereType<CreatureSpriteComponent>().first;
      expect(sprite.animating, isTrue);
    }
    await tester.pumpWidget(const SizedBox());
  });

  HomeBiomeLayout withKeepsake(String kind, {double at = 0.16}) =>
      HomeBiomeLayout(
        realm: HomeRealm.valley,
        pieces: {
          'valley': [HomePiece(id: '$kind#0', kind: kind, x: at)],
        },
        residents: const [HomeResident(instanceId: 'a', x: 0.12)],
      );

  testWidgets('it climbs into the Giant\'s Palm, sits, and comes down', (
    tester,
  ) async {
    final game = await mount(tester, withKeepsake('giants_palm'));
    expect(game.debugVisit('HOME_a', 'PIECE_giants_palm#0'), isTrue);
    var highest = 0.0;
    var cameDown = false;
    await run(tester, 14, () {
      final o = game.debugLifeOffset('HOME_a');
      if (o != null) highest = highest < -o.dy ? -o.dy : highest;
      if (highest > 40 && !game.debugVisiting('HOME_a')) {
        // Finished: back on the ground beside it.
        cameDown = cameDown || (o?.dy ?? 0).abs() < 12;
      }
    });
    // Up into the palm: its seat is ~0.9 of a keepsake (×0.62) high.
    expect(highest, greaterThan(40));
    expect(cameDown, isTrue, reason: 'and came down again');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('it hops in time with the pipes', (tester) async {
    final game = await mount(tester, withKeepsake('harmony_pipes'));
    expect(game.debugVisit('HOME_a', 'PIECE_harmony_pipes#0'), isTrue);
    var hops = 0;
    var up = false;
    await run(tester, 10, () {
      final o = game.debugLifeOffset('HOME_a');
      final lifted = o != null && o.dy < -5;
      if (lifted && !up) hops++;
      up = lifted;
    });
    expect(hops, greaterThanOrEqualTo(4));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('at night it sleeps by a torch it can reach', (tester) async {
    final game = await mount(
      tester,
      withKeepsake('ember_torch', at: 0.17),
      hour: 23,
    );
    await run(tester, 14);
    final o = game.debugLifeOffset('HOME_a');
    expect(o, isNotNull, reason: 'it went to the torch');
    final period = HomeRealm.valley.period(HomeRealm.valley.near.layer);
    final torch = (0.17 - 0.12) * period;
    expect((o!.dx - torch).abs(), lessThan(80));
    final sprite = game.debugResidents['HOME_a']!
        .children
        .whereType<CreatureSpriteComponent>()
        .first;
    expect(sprite.animating, isFalse, reason: 'asleep there');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a tapped keepsake calls the nearest one that can reach it', (
    tester,
  ) async {
    final game = await mount(tester, withKeepsake('crown_mirror'));
    expect(game.callResidentTo('PIECE_crown_mirror#0'), isTrue);
    expect(game.debugVisiting('HOME_a'), isTrue);
    game.arranging = true;
    await run(tester, 0.1);
    expect(game.debugVisiting('HOME_a'), isFalse, reason: 'arranging stops it');
    expect(game.callResidentTo('PIECE_crown_mirror#0'), isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  // ── Decor ───────────────────────────────────────────────────────────────

  testWidgets('at night it sleeps in a rest nest it can reach', (tester) async {
    final game = await mount(tester, withKeepsake('rest_nest', at: 0.17), hour: 23);
    await run(tester, 12);
    final o = game.debugLifeOffset('HOME_a');
    expect(o, isNotNull, reason: 'it went to the nest');
    expect(o!.dy, lessThan(-4), reason: 'up in it');
    expect(game.debugVisiting('HOME_a'), isTrue, reason: 'and stays the night');
    final sprite = game.debugResidents['HOME_a']!
        .children
        .whereType<CreatureSpriteComponent>()
        .first;
    expect(sprite.animating, isFalse, reason: 'asleep');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('in the rain it shelters under the canopy', (tester) async {
    final game = await mount(tester, withKeepsake('canopy', at: 0.165));
    game.fieldWeather = WeatherKind.rain;
    await run(tester, 10);
    expect(game.debugVisiting('HOME_a'), isTrue, reason: 'under it');
    final period = HomeRealm.valley.period(HomeRealm.valley.near.layer);
    final canopy = (0.165 - 0.12) * period;
    expect((game.debugLifeOffset('HOME_a')!.dx - canopy).abs(), lessThan(70));
    // The rain clears: out it comes.
    game.fieldWeather = null;
    var left = false;
    await run(tester, 10, () {
      if (!game.debugVisiting('HOME_a')) left = true;
    });
    expect(left, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('it bathes in the hot spring, sunk into the water', (tester) async {
    final game = await mount(tester, withKeepsake('hot_spring', at: 0.19));
    expect(game.debugVisit('HOME_a', 'PIECE_hot_spring#0'), isTrue);
    var lowest = 0.0;
    await run(tester, 8, () {
      final o = game.debugLifeOffset('HOME_a');
      if (o != null && o.dy > lowest) lowest = o.dy;
    });
    expect(lowest, greaterThan(10), reason: 'down into the water');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('in the Arcane too it walks to the spring and bathes', (
    tester,
  ) async {
    const layout = HomeBiomeLayout(
      realm: HomeRealm.arcane,
      pieces: {
        'arcane': [HomePiece(id: 'hot_spring#0', kind: 'hot_spring', x: 0.19)],
      },
      residents: [HomeResident(instanceId: 'a', x: 0.12)],
    );
    final game = await mount(tester, layout);
    var strolled = false;
    await run(tester, 20, () {
      final o = game.debugLifeOffset('HOME_a');
      if (o != null && o.dx.abs() > 4) strolled = true;
    });
    expect(strolled, isTrue, reason: 'it walks the glass');
    final period = HomeRealm.arcane.period(HomeRealm.arcane.near.layer);
    expect((0.19 - 0.12) * period, lessThan(200));
    expect(game.debugVisit('HOME_a', 'PIECE_hot_spring#0'), isTrue);
    var lowest = 0.0;
    await run(tester, 8, () {
      final o = game.debugLifeOffset('HOME_a');
      if (o != null && o.dy > lowest) lowest = o.dy;
    });
    expect(lowest, greaterThan(10), reason: 'down into the water');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('one performs on the stage, another watches', (tester) async {
    const layout = HomeBiomeLayout(
      realm: HomeRealm.valley,
      pieces: {
        'valley': [HomePiece(id: 'stage#0', kind: 'stage', x: 0.17)],
      },
      residents: [
        HomeResident(instanceId: 'a', x: 0.12),
        HomeResident(instanceId: 'b', x: 0.235),
      ],
    );
    final game = await mount(tester, layout);
    expect(game.debugVisit('HOME_a', 'PIECE_stage#0'), isTrue);
    expect(game.debugVisit('HOME_b', 'PIECE_stage#0'), isTrue);
    var performerUp = false;
    await run(tester, 4, () {
      final o = game.debugLifeOffset('HOME_a');
      if (o != null && o.dy < -20) performerUp = true;
    });
    expect(performerUp, isTrue, reason: 'the first is up on the boards');
    final b = game.debugLifeOffset('HOME_b');
    expect((b?.dy ?? 0).abs(), lessThan(14), reason: 'the second on the ground');
    expect(game.debugVisiting('HOME_b'), isTrue, reason: 'watching');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a flyer lands on the flyer\'s perch', (tester) async {
    tester.view.physicalSize = const Size(915, 412) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    const layout = HomeBiomeLayout(
      realm: HomeRealm.valley,
      pieces: {
        'valley': [HomePiece(id: 'flyer_perch#0', kind: 'flyer_perch', x: 0.15)],
      },
      residents: [HomeResident(instanceId: 'w', x: 0.12, lift: 0.3)],
    );
    final game = SceneGame(scene: layout.scene((id) => true), showcase: true)
      ..fieldHourOverride = 12
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
    await game.showResident('HOME_w', species('WNG04'));
    final art = KeepsakeArt.of('flyer_perch')!;
    game.showThing(
      'PIECE_flyer_perch#0',
      KeepsakeComponent(kind: 'flyer_perch', art: art, rowSize: 100),
      art.box,
    );
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 33));
    }
    final period = HomeRealm.valley.period(HomeRealm.valley.near.layer);
    final perchX = (0.15 - 0.12) * period;
    var landed = false;
    await run(tester, 60, () {
      final o = game.debugLifeOffset('HOME_w');
      if (o != null && (o.dx - perchX).abs() < 6) landed = true;
    });
    expect(landed, isTrue, reason: 'it came to rest on the perch');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('trial decor is never visited', (tester) async {
    const layout = HomeBiomeLayout(
      realm: HomeRealm.valley,
      pieces: {
        'valley': [HomePiece(id: 'try:fountain#0', kind: 'fountain', x: 0.16)],
      },
      residents: [HomeResident(instanceId: 'a', x: 0.12)],
    );
    final game = await mount(tester, layout, ghosts: true);
    expect(game.callResidentTo('PIECE_try:fountain#0'), isFalse);
    expect(game.debugVisit('HOME_a', 'PIECE_try:fountain#0'), isFalse);
    expect(layout.toJson()['pieces'], {'valley': []}, reason: 'nor saved');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('through one portal, out of the other, and home', (
    tester,
  ) async {
    const layout = HomeBiomeLayout(
      realm: HomeRealm.valley,
      pieces: {
        'valley': [
          HomePiece(id: 'twin_portals#0', kind: 'twin_portals', x: 0.05),
          HomePiece(id: 'twin_portals#1', kind: 'twin_portals', x: 0.30),
        ],
      },
      residents: [HomeResident(instanceId: 'a', x: 0.12)],
    );
    final game = await mount(tester, layout);
    expect(game.debugTrip('HOME_a'), isTrue);
    final period = HomeRealm.valley.period(HomeRealm.valley.near.layer);
    final toB = (0.30 - 0.12) * period;
    var vanished = false, outOfB = false, home = false;
    await run(tester, 30, () {
      if (game.debugLifeFade('HOME_a') <= 0.01) vanished = true;
      final o = game.debugLifeOffset('HOME_a');
      if (o != null &&
          (o.dx - toB).abs() < 60 &&
          game.debugLifeFade('HOME_a') > 0.9) {
        outOfB = true;
      }
      // Back at its spot, whole, the trip over (it may set off again).
      if (outOfB && !game.debugOnTrip('HOME_a')) {
        home = home || game.debugLifeFade('HOME_a') == 1;
      }
    });
    expect(vanished, isTrue, reason: 'it went into a portal');
    expect(outOfB, isTrue, reason: 'it came out of the other');
    expect(home, isTrue, reason: 'and came home');
    await tester.pumpWidget(const SizedBox());
  });
}
