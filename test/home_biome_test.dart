// The home biome: the player's own field under the home planet. These pin
// what it keeps (its layout survives a save, and a bad one never breaks
// it), how residents are spaced, that each realm offers only its own
// weather, and that every resident who stands has ground under its feet in
// every realm — with nothing built for encounter partners, which the home
// biome has none of.

import 'package:alchemons/games/wilderness/field/field_art.dart';
import 'package:alchemons/games/wilderness/field/grain_field.dart';
import 'package:alchemons/games/wilderness/field_essence.dart';
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/home_biome.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:alchemons/services/wilderness_spawn_service.dart';
import 'package:alchemons/widgets/wilderness/creature_sprite_component.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const near = SceneLayer.layer4, far = SceneLayer.layer3;

  // A mixed household: some on each row, a flyer up in the air.
  const household = HomeBiomeLayout(
    residents: [
      HomeResident(instanceId: 'a', x: 0.05),
      HomeResident(instanceId: 'b', x: 0.20, flip: true),
      HomeResident(instanceId: 'c', x: 0.42),
      HomeResident(instanceId: 'd', x: 0.12, back: true),
      HomeResident(instanceId: 'e', x: 0.55, back: true),
      HomeResident(instanceId: 'wing', x: 0.30, lift: 0.34),
    ],
  );
  bool floats(String id) => id == 'wing';

  test('a layout survives the save', () {
    final layout = household
        .copyWith(realm: HomeRealm.swamp, hour: () => 18.8)
        .withMood('dry');
    final back = HomeBiomeLayout.fromJson(layout.toJson());
    expect(back.realm, HomeRealm.swamp);
    expect(back.mood.id, 'dry');
    expect(back.hour, 18.8);
    expect(back.residents.length, household.residents.length);
    for (var i = 0; i < back.residents.length; i++) {
      final a = household.residents[i], b = back.residents[i];
      expect(b.instanceId, a.instanceId);
      expect(b.back, a.back);
      expect(b.x, closeTo(a.x, 1e-4));
      expect(b.lift, a.lift == null ? isNull : closeTo(a.lift!, 1e-4));
      expect(b.flip, a.flip);
    }
  });

  test('each realm remembers its own weather', () {
    final layout = const HomeBiomeLayout()
        .withMood('rain')
        .copyWith(realm: HomeRealm.arcane)
        .withMood('aurora');
    expect(layout.mood.id, 'aurora');
    expect(layout.copyWith(realm: HomeRealm.valley).mood.id, 'rain');
    expect(layout.copyWith(realm: HomeRealm.sky).mood.id, 'clear');
  });

  test('the Arcane is not a home until it is unlocked in the wild', () {
    final locked = HomeRealm.open(arcane: false);
    expect(locked, isNot(contains(HomeRealm.arcane)));
    expect(locked.length, HomeRealm.values.length - 1);
    expect(HomeRealm.open(arcane: true), HomeRealm.values);
    // A home made in the Arcane comes back in the Valley while it is locked,
    // residents and all, and as it was once it opens.
    final arcaneHome = household.copyWith(realm: HomeRealm.arcane);
    expect(arcaneHome.within(locked).realm, HomeRealm.valley);
    expect(
      arcaneHome.within(locked).residents.length,
      household.residents.length,
    );
    expect(
      arcaneHome.within(HomeRealm.open(arcane: true)).realm,
      HomeRealm.arcane,
    );
  });

  test('a broken or strange save is read as far as it makes sense', () {
    expect(HomeBiomeLayout.fromJson(null).residents, isEmpty);
    expect(HomeBiomeLayout.fromJson('nonsense').realm, HomeRealm.valley);
    final odd = HomeBiomeLayout.fromJson({
      'realm': 'atlantis',
      'moods': {'valley': 'hail', 'sky': 3},
      'hour': 30,
      'residents': [
        {'id': 'x', 'x': 1.25},
        {'id': 'x', 'x': 0.5},
        {'x': 0.2},
        'nobody',
        for (var i = 0; i < 20; i++) {'id': 'n$i', 'x': i / 20},
      ],
    });
    expect(odd.realm, HomeRealm.valley);
    // An unknown mood falls back to the realm's first.
    expect(odd.mood.id, 'clear');
    expect(odd.hour, 6);
    expect(odd.residents.first.instanceId, 'x');
    expect(odd.residents.first.x, closeTo(0.25, 1e-9));
    expect(odd.residents.where((r) => r.instanceId == 'x').length, 1);
    expect(odd.residents.length, kHomeBiomeMaxResidents);
  });

  test('every realm offers only weather its wild field has', () {
    for (final realm in HomeRealm.values) {
      final wild = {
        for (final w in WildernessSpawnService.weathers[realm.sceneId] ?? [])
          w.kind,
      };
      for (final m in realm.moods) {
        if (m.weather == null) continue;
        expect(wild, contains(m.weather), reason: '${realm.name} ${m.id}');
      }
      expect(realm.moods.map((m) => m.id).toSet().length, realm.moods.length);
    }
    // The Volcano has no weather of its own: its moods are its cycle.
    expect(
      HomeRealm.volcano.moods.map((m) => m.stage),
      orderedEquals(realm(HomeRealm.volcano).stages.toSet()),
    );
  });

  test('only what can float is held in the air', () {
    final layout = household;
    final wing = layout.spawnPointFor(layout.residents.last, floats: true);
    expect(wing.perch, SpawnPerch.air);
    expect(wing.normalizedPos.dy, 0.34);
    // The same lift on something that cannot float: it stands.
    final grounded = layout.spawnPointFor(layout.residents.last, floats: false);
    expect(grounded.perch, SpawnPerch.ground);
    expect(grounded.normalizedPos.dy, HomeRealm.valley.near.height);
    final back = layout.spawnPointFor(layout.residents[3], floats: false);
    expect(back.anchor, far);
    expect(back.size.x, HomeRealm.valley.far.size);
  });

  test('residents keep clear of each other on a row', () {
    for (final realm in HomeRealm.values) {
      var layout = HomeBiomeLayout(realm: realm);
      // Fill the near row, each one asking for the same spot.
      var placed = 0;
      while (true) {
        final r = HomeResident(instanceId: 'r$placed');
        final x = layout.freeSpotNear(r, 0.5);
        if (x == null) break;
        layout = layout.copyWith(
          residents: [
            ...layout.residents,
            r.copyWith(x: x),
          ],
        );
        placed++;
        expect(placed, lessThan(100));
      }
      expect(placed, greaterThanOrEqualTo(6), reason: realm.name);
      final g = layout.gap(back: false);
      final xs = [for (final r in layout.residents) r.x];
      for (var i = 0; i < xs.length; i++) {
        for (var j = i + 1; j < xs.length; j++) {
          final d = (xs[i] - xs[j]).abs() % 1.0;
          expect(
            d > 0.5 ? 1 - d : d,
            greaterThanOrEqualTo(g - 1e-9),
            reason: '${realm.name} $i $j',
          );
        }
      }
      // The far row is still free, and a flyer can hover over anyone.
      expect(
        layout.freeSpotNear(
          const HomeResident(instanceId: 'f', back: true),
          0.5,
        ),
        0.5,
      );
      expect(
        layout.freeSpotNear(
          HomeResident(instanceId: 'w', lift: 0.3, x: xs.first),
          xs.first,
        ),
        xs.first,
      );
    }
  });

  // ── The ground under them, realm by realm ───────────────────────────────

  FieldArt fieldOf(HomeRealm realm) => switch (realm) {
    HomeRealm.valley => ValleyField(),
    HomeRealm.sky => SkyField(),
    HomeRealm.swamp => SwampField(),
    HomeRealm.volcano => VolcanoField(),
    HomeRealm.arcane => ArcaneField(),
  };

  for (final realm in HomeRealm.values) {
    test('every resident in the ${realm.name} that stands has ground', () {
      final layout = household.copyWith(realm: realm);
      final scene = layout.scene(floats);
      const h = 412.0;
      final field = fieldOf(realm)
        ..layout(
          scene.spawnPoints,
          scene.worldWidth,
          loop: scene.loop,
          partners: false,
          placed: true,
        );
      final screen = const Size(h * 2.2, h);
      for (final l in scene.layers) {
        field.build(l.id, Size(realm.period(l.id), h), screen);
      }
      for (final p in scene.spawnPoints) {
        // Scenery is its own ground; only what stands needs some.
        if (p.aloft || p.piece != null) continue;
        final x = p.normalizedPos.dx * realm.period(p.anchor);
        final ground = field.groundAt(p.anchor, x);
        expect(ground, isNotNull, reason: '${realm.name} ${p.id}');
        // Its feet are on that ground (where the field seats it), not
        // hanging over it.
        final feet = field.perchFor(p.id) ?? (p.normalizedPos.dy * h);
        expect(feet, lessThan(ground!.rest + p.size.y), reason: p.id);
      }
    });
  }

  test('the Sky builds an isle under each standing resident, and no more', () {
    final layout = household.copyWith(realm: HomeRealm.sky);
    final scene = layout.scene(floats);
    const h = 412.0;
    SkyField built({required bool partners}) {
      final field = SkyField()
        ..layout(
          scene.spawnPoints,
          scene.worldWidth,
          loop: true,
          partners: partners,
          placed: !partners,
        );
      for (final l in scene.layers) {
        field.build(
          l.id,
          Size(HomeRealm.sky.period(l.id), h),
          const Size(900, h),
        );
      }
      return field;
    }

    final home = built(partners: false), wild = built(partners: true);
    for (final layer in [near, far]) {
      final points = scene.spawnPoints.where(
        (p) => p.anchor == layer && p.piece == null,
      );
      final standing = points.where((p) => !p.aloft).length;
      // A wild field adds one for each point's partner too.
      expect(
        wild.debugIsles(layer).length - home.debugIsles(layer).length,
        points.length,
        reason: '$layer',
      );
      expect(home.debugIsles(layer).length, greaterThanOrEqualTo(standing));
    }
  });

  testWidgets('moving a resident in the Sky moves its isle', (tester) async {
    tester.view.physicalSize = const Size(915, 412) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    var layout = household.copyWith(realm: HomeRealm.sky);
    final game = SceneGame(scene: layout.scene(floats), showcase: true);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: GameWidget(game: game),
      ),
    );
    for (var i = 0; i < 40 && !game.isLoaded; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    final sky = game.debugField! as SkyField;
    final period = HomeRealm.sky.period(near);
    bool isleAt(double share) => sky
        .debugIsles(near)
        .any((r) => r.left < share * period && r.right > share * period);
    final farBefore = sky.debugIsles(far);
    expect(isleAt(0.05), isTrue);
    expect(isleAt(0.80), isFalse);

    layout = layout.replace(layout.residents.first.copyWith(x: 0.80));
    game.relayout(layout.spawnPoints(floats));
    expect(isleAt(0.80), isTrue);
    expect(isleAt(0.05), isFalse);
    // The far row was not rebuilt.
    expect(sky.debugIsles(far), farBefore);

    // Sent away: its isle goes too.
    layout = layout.copyWith(residents: layout.residents.skip(1).toList());
    game.relayout(layout.spawnPoints(floats));
    expect(isleAt(0.80), isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('arranging, a resident is carried by a finger', (tester) async {
    tester.view.physicalSize = const Size(915, 412) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final json =
        jsonDecode(
              File('assets/data/alchemons_creatures.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final horn = Creature.fromJson(
      (json['creatures'] as List).cast<Map<String, dynamic>>().firstWhere(
        (c) => c['id'] == 'HOR01',
      ),
    );
    const layout = HomeBiomeLayout(
      residents: [HomeResident(instanceId: 'h', x: 0.12)],
    );
    final game = SceneGame(scene: layout.scene((_) => false), showcase: true);
    (String, double, double)? dropped;
    String? picked;
    game
      ..arranging = true
      ..onResidentPicked = ((id) => picked = id)
      ..onResidentDropped = ((id, share, height) =>
          dropped = (id, share, height));
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: GameWidget(game: game),
      ),
    );
    for (var i = 0; i < 40 && !game.isLoaded; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await game.showResident('HOME_h', horn);
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    final resident = game.debugResidents['HOME_h']!;
    final x = game.screenXOf('HOME_h')!;
    final y = (resident.parent! as dynamic).position.y as double;

    // A quick drag that starts on the resident pans the field past it: it
    // is not taken hold of until a finger has rested on it a moment.
    final camera0 = game.cameraX;
    await tester.timedDragFrom(
      Offset(x, y),
      const Offset(-240, 0),
      const Duration(milliseconds: 300),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(picked, isNull);
    expect(dropped, isNull);
    expect(game.cameraX, greaterThan(camera0 + 20));
    final x1 = game.screenXOf('HOME_h')!;

    // Held a moment first, it is carried, and the field does not move
    // under it.
    final camera = game.cameraX;
    final finger = await tester.startGesture(Offset(x1, y));
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(picked, 'HOME_h');
    for (var i = 1; i <= 25; i++) {
      await finger.moveBy(const Offset(240 / 25, -80 / 25));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await finger.up();
    await tester.pump(const Duration(milliseconds: 16));
    expect(dropped, isNotNull);
    expect(dropped!.$1, 'HOME_h');
    final period = HomeRealm.valley.period(SceneLayer.layer4);
    // Carried right by about the finger's way, in layer units.
    final from = game.shareAtScreen(SceneLayer.layer4, x1);
    expect(dropped!.$2, closeTo(from + 240 / period, 30 / period));
    expect(game.cameraX, closeTo(camera, 1));

    // Not arranging: the same drag pans the field instead.
    dropped = null;
    game.arranging = false;
    await tester.timedDragFrom(
      Offset(game.screenXOf('HOME_h')!, y),
      const Offset(-240, 0),
      const Duration(milliseconds: 500),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(dropped, isNull);
    expect(game.cameraX, greaterThan(camera + 20));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('looking, a tap plays its essence; a drag past it does not', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(915, 412) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final json =
        jsonDecode(
              File('assets/data/alchemons_creatures.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final horn = Creature.fromJson(
      (json['creatures'] as List).cast<Map<String, dynamic>>().firstWhere(
        (c) => c['id'] == 'HOR01',
      ),
    );
    const layout = HomeBiomeLayout(
      residents: [HomeResident(instanceId: 'h', x: 0.12)],
    );
    final game = SceneGame(scene: layout.scene((_) => false), showcase: true);
    game.onResidentTap = game.playEssence;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: GameWidget(game: game),
      ),
    );
    Future<void> settle(int frames) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 33));
      }
    }

    for (var i = 0; i < 40 && !game.isLoaded; i++) {
      await settle(1);
    }
    await game.showResident('HOME_h', horn);
    await settle(20);
    final resident = game.debugResidents['HOME_h']!;
    final anchor = resident.parent! as PositionComponent;
    bool playing() => anchor.children.any((c) => c is FieldEssence);
    final at = Offset(game.screenXOf('HOME_h')!, anchor.position.y);

    // Panning the field from on top of it is not a tap.
    await tester.timedDragFrom(
      at,
      const Offset(-200, 0),
      const Duration(milliseconds: 400),
    );
    await settle(2);
    expect(playing(), isFalse);

    final now = Offset(game.screenXOf('HOME_h')!, anchor.position.y);
    await tester.tapAt(now);
    await settle(2);
    expect(playing(), isTrue);
    // A second tap while it plays does not start another.
    await tester.tapAt(now);
    await settle(2);
    expect(anchor.children.whereType<FieldEssence>().length, 1);

    final sprite = resident.children.whereType<CreatureSpriteComponent>().first;
    await settle(30);
    expect(sprite.spriteOpacity, lessThan(0.5), reason: 'it is grains now');
    await settle(70);
    expect(playing(), isFalse);
    expect(sprite.spriteOpacity, 1);
    await tester.pumpWidget(const SizedBox());
  });

  test('put down beside a keepsake, it shares the keepsake\'s isle', () {
    final realmSky = HomeRealm.sky;
    var layout = HomeBiomeLayout(
      realm: realmSky,
      pieces: const {
        'sky': [HomePiece(id: 'ember_torch#0', kind: 'ember_torch', x: 0.30)],
      },
      residents: const [HomeResident(instanceId: 'h', x: 0.10)],
    );
    final period = realmSky.period(realmSky.near.layer);
    // Let go just right of the torch: beside it, on its ground.
    final nest = layout.nestBeside('HOME_h', 0.30 + 40 / period, back: false);
    expect(nest, isNotNull);
    expect(nest!.$1, 'PIECE_ember_torch#0');
    expect(nest.$2, greaterThan(0.30));
    layout = layout.replace(
      layout.residents.first.copyWith(x: nest.$2, beside: () => nest.$1),
    );
    final scene = layout.scene((_) => false);
    final point = scene.spawnPoints.firstWhere((p) => p.id == 'HOME_h');
    expect(point.beside, 'PIECE_ember_torch#0');

    // One isle for the two of them, wide enough for both.
    const h = 412.0;
    final field = SkyField()
      ..layout(
        scene.spawnPoints,
        scene.worldWidth,
        loop: true,
        partners: false,
        placed: true,
      );
    for (final l in scene.layers) {
      field.build(l.id, Size(realmSky.period(l.id), h), const Size(900, h));
    }
    final torchX = 0.30 * period, hx = nest.$2 * period;
    final under = [
      for (final r in field.debugIsles(realmSky.near.layer))
        if (r.left < torchX && r.right > torchX) r,
    ];
    expect(under.length, 1, reason: 'the torch stands on one isle');
    expect(under.first.left < hx && under.first.right > hx, isTrue,
        reason: 'and the resident on the same one');
    expect(field.perchFor('HOME_h'), isNotNull);

    // Spaced as one: nothing else can stand where the pair stands.
    final other = const HomeResident(instanceId: 'o', x: 0);
    final spot = layout.copyWith(
      residents: [...layout.residents, other],
    ).freeSpotNear(other, nest.$2);
    final gapToPair = (spot! - 0.30).abs();
    expect(gapToPair, greaterThan(1.5 * layout.gap(back: false) / 2));

    // The torch moved, the resident goes with it.
    final moved = layout
        .replacePiece(layout.placed.first.copyWith(x: 0.5))
        .carryBeside('PIECE_ember_torch#0', 0.2);
    expect(moved.residents.first.x, closeTo(nest.$2 + 0.2, 1e-9));
    // Taken away, the resident stands on its own again.
    final freed = moved.freeBeside('PIECE_ember_torch#0');
    expect(freed.residents.first.beside, isNull);
  });
}

SceneDefinition realm(HomeRealm r) => r.wildScene;
