import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/audio/sound_cue.dart';
import 'package:alchemons/games/wilderness/keepsake_component.dart';
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/athanor.dart' show kAthanorCurioCopies;
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/home_biome.dart';
import 'package:alchemons/models/home_decor.dart';
import 'package:alchemons/models/home_keepsakes.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/widgets/fx/keepsake_art.dart';
import 'package:alchemons/widgets/wilderness/creature_sprite_component.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// The home decor drawn at the Athanor (HomeDecor.athanor): never sold, each
// with its art, and the ones the residents use, used — sat in, slept in,
// bowed at, hopped beside, held court on, and gone through as grains.
void main() {
  const ids = {
    'moth_lantern', 'inkcap_cluster', 'ash_brazier', 'nightbloom_bed', //
    'moonstone_cairn', 'salt_pillar', 'moon_font', 'snow_globe', //
    'sundial', 'honey_lamp', 'storm_coil', 'gilded_throne', //
    'glass_rose', 'ember_bowl', 'ember_nest', 'pomegranate_tree', //
    'herb_rack', 'retort_shelf', 'alembic', 'bell_jar', 'music_box', //
    'great_alembic',
  };

  group('the catalog', () {
    test('every Athanor piece is in the decor, and only drawn', () {
      expect(HomeDecor.athanor.map((d) => d.id).toSet(), ids);
      expect(HomeDecor.athanor, hasLength(ids.length), reason: 'no repeats');
      final all = HomeDecor.all.map((d) => d.id).toList();
      expect(all.toSet(), hasLength(all.length), reason: 'ids are unique');
      final keepsakes = {for (final k in Keepsake.all) k.id};
      for (final d in HomeDecor.athanor) {
        expect(HomeDecor.byId(d.id), same(d));
        expect(d.athanorOnly, isTrue, reason: d.id);
        expect(d.cost, isEmpty, reason: d.id);
        expect(keepsakes.contains(d.id), isFalse, reason: d.id);
        expect(d.line, isNotEmpty);
        switch (d.tier) {
          case DecorTier.curio:
            expect(
              d.max,
              kAthanorCurioCopies,
              reason: '${d.id}: a draw gives 3',
            );
          case DecorTier.living || DecorTier.wonder:
            expect(d.max, 1, reason: d.id);
        }
      }
      expect(
        HomeDecor.athanor.where((d) => d.tier == DecorTier.curio),
        hasLength(10),
      );
      expect(
        HomeDecor.athanor.where((d) => d.tier == DecorTier.living),
        hasLength(9),
      );
      expect(
        HomeDecor.athanor
            .where((d) => d.tier == DecorTier.wonder)
            .map((d) => d.id),
        unorderedEquals(['snow_globe', 'gilded_throne', 'great_alembic']),
      );
    });

    test('the shop never offers one', () {
      final offered = ShopService.offersForDecor(
        HomeDecor.all,
      ).map((o) => o.id);
      final offers = ShopService.allOffers.map((o) => o.id).toSet();
      for (final d in HomeDecor.athanor) {
        expect(offered, isNot(contains(d.offerId)), reason: d.id);
        expect(offers, isNot(contains(d.offerId)), reason: d.id);
      }
      // The bought decor still is.
      for (final d in HomeDecor.all.where((d) => !d.athanorOnly)) {
        expect(offered, contains(d.offerId), reason: d.id);
      }
    });

    test('each has its art, its box and its sound, and draws', () {
      for (final d in HomeDecor.athanor) {
        final art = KeepsakeArt.of(d.id);
        expect(art, isNotNull, reason: d.id);
        final box = art!.box;
        expect(box.isEmpty, isFalse, reason: d.id);
        expect(
          box.contains(const Offset(0, -1)),
          isTrue,
          reason: '${d.id}: round its feet',
        );
        expect(box.bottom, greaterThanOrEqualTo(0), reason: d.id);
        expect(SoundCue.forHomeThing(d.id), isNotNull, reason: d.id);
        for (final (night, stir) in const [
          (0.0, 0.0),
          (1.0, 0.0),
          (0.5, 1.0),
        ]) {
          final rec = ui.PictureRecorder();
          final c = Canvas(rec);
          final k = KeepsakeTime(
            t: 3,
            night: night,
            daylight: 1 - night,
            stir: stir,
            hour: 9,
          );
          art.paint(c, k);
          if (art.hasFront) art.front(c, k);
          rec.endRecording().dispose();
        }
        art.dispose();
      }
    });

    test('the pieces sat in have their seats', () {
      List<Offset> seats(String id) =>
          KeepsakeArt.of(id)!.seats(KeepsakeTime());
      for (final id in [
        'nightbloom_bed',
        'snow_globe',
        'ember_nest',
        'bell_jar',
      ]) {
        expect(seats(id), hasLength(1), reason: id);
        expect(
          seats(id).first.dy,
          greaterThan(0),
          reason: '$id: up off the ground',
        );
      }
      expect(seats('pomegranate_tree'), hasLength(2));
      // The throne: its seat, and a place either side to bow from.
      final throne = seats('gilded_throne');
      expect(throne, hasLength(3));
      expect(throne[1].dx, lessThan(0));
      expect(throne[2].dx, greaterThan(0));
      // The Great Alembic: in at one end, out at the other.
      final still = seats('great_alembic');
      expect(still, hasLength(2));
      expect(still[0].dx, lessThan(0));
      expect(still[1].dx, greaterThan(0));
      for (final id in [
        'snow_globe',
        'gilded_throne',
        'nightbloom_bed',
        'ember_nest',
        'bell_jar',
        'great_alembic',
      ]) {
        expect(
          KeepsakeArt.of(id)!.hasFront,
          isTrue,
          reason: '$id: drawn over who is in it',
        );
      }
    });
  });

  // ── Life ──────────────────────────────────────────────────────────────────

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
  final period = HomeRealm.valley.period(HomeRealm.valley.near.layer);

  /// The share of the row [d] layer units along from 0.12.
  double from12(double d) => 0.12 + d / period;

  Future<SceneGame> mount(
    WidgetTester tester,
    HomeBiomeLayout layout, {
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
      await game.showResident(r.spawnId, species('HOR01'));
    }
    for (final p in layout.placed.where((p) => p.isKeepsake)) {
      final art = KeepsakeArt.of(p.kind)!;
      game.showThing(
        p.spawnId,
        KeepsakeComponent(kind: p.kind, art: art, rowSize: 100),
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

  /// [seconds] of the field, letting real work (reading a sprite into
  /// grains) finish now and then.
  Future<void> run(
    WidgetTester tester,
    double seconds, [
    void Function()? each,
  ]) async {
    for (var i = 0; i < seconds * 30; i++) {
      if (i % 10 == 0) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 4)),
        );
      }
      await tester.pump(const Duration(milliseconds: 33));
      each?.call();
    }
  }

  HomeBiomeLayout one(String kind, double d) => HomeBiomeLayout(
    realm: HomeRealm.valley,
    pieces: {
      'valley': [HomePiece(id: '$kind#0', kind: kind, x: from12(d))],
    },
    residents: const [HomeResident(instanceId: 'a', x: 0.12)],
  );

  bool animating(SceneGame game, String id) => game.debugResidents[id]!.children
      .whereType<CreatureSpriteComponent>()
      .first
      .animating;

  for (final (kind, high) in const [
    ('bell_jar', 15.0),
    ('pomegranate_tree', 60.0),
    ('snow_globe', 25.0),
  ]) {
    testWidgets('it climbs into the $kind, sits, and comes down', (
      tester,
    ) async {
      final game = await mount(tester, one(kind, 100));
      expect(game.debugVisit('HOME_a', 'PIECE_$kind#0'), isTrue);
      var highest = 0.0;
      var cameDown = false;
      await run(tester, 16, () {
        final o = game.debugLifeOffset('HOME_a');
        if (o != null && -o.dy > highest) highest = -o.dy;
        if (highest > high && !game.debugVisiting('HOME_a')) {
          cameDown = cameDown || (o?.dy ?? 0).abs() < 12;
        }
      });
      expect(highest, greaterThan(high), reason: 'up in it');
      expect(cameDown, isTrue, reason: 'and down again');
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final (kind, up) in const [
    ('nightbloom_bed', 1.0),
    ('ember_nest', 10.0),
    ('snow_globe', 25.0),
  ]) {
    testWidgets('at night it sleeps in the $kind', (tester) async {
      final game = await mount(tester, one(kind, 70), hour: 23);
      await run(tester, 14);
      final o = game.debugLifeOffset('HOME_a');
      expect(o, isNotNull, reason: 'it went to it');
      expect(o!.dy, lessThan(-up), reason: 'up in it');
      expect((o.dx - 70).abs(), lessThan(40), reason: 'in it, not beside it');
      expect(game.debugVisiting('HOME_a'), isTrue, reason: 'there the night');
      expect(animating(game, 'HOME_a'), isFalse, reason: 'asleep');
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('at night it sleeps by the ash brazier', (tester) async {
    final game = await mount(tester, one('ash_brazier', 100), hour: 23);
    await run(tester, 14);
    final o = game.debugLifeOffset('HOME_a');
    expect(o, isNotNull, reason: 'it went to it');
    expect((o!.dx - 100).abs(), lessThan(90));
    expect((o.dx - 100).abs(), greaterThan(40), reason: 'beside it, not in it');
    expect(animating(game, 'HOME_a'), isFalse, reason: 'asleep there');
    await tester.pumpWidget(const SizedBox());
  });

  for (final kind in const ['storm_coil', 'music_box']) {
    testWidgets('it hops beside the $kind', (tester) async {
      final game = await mount(tester, one(kind, 100));
      expect(game.debugVisit('HOME_a', 'PIECE_$kind#0'), isTrue);
      var hops = 0;
      var up = false;
      await run(tester, 8, () {
        final o = game.debugLifeOffset('HOME_a');
        final lifted = o != null && o.dy < -5;
        if (lifted && !up) hops++;
        up = lifted;
      });
      expect(hops, greaterThanOrEqualTo(4));
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final kind in const ['moon_font', 'alembic']) {
    testWidgets('it bows at the $kind', (tester) async {
      final game = await mount(tester, one(kind, 100));
      expect(game.debugVisit('HOME_a', 'PIECE_$kind#0'), isTrue);
      var bowed = 0.0;
      await run(tester, 6, () {
        final a = game.debugResidents['HOME_a']!.angle.abs();
        if (a > bowed) bowed = a;
      });
      expect(bowed, greaterThan(0.1));
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('one holds court on the throne; another bows to it', (
    tester,
  ) async {
    final layout = HomeBiomeLayout(
      realm: HomeRealm.valley,
      pieces: {
        'valley': [
          HomePiece(
            id: 'gilded_throne#0',
            kind: 'gilded_throne',
            x: from12(100),
          ),
        ],
      },
      residents: [
        const HomeResident(instanceId: 'a', x: 0.12),
        HomeResident(instanceId: 'b', x: from12(300)),
      ],
    );
    final game = await mount(tester, layout);
    expect(game.debugVisit('HOME_a', 'PIECE_gilded_throne#0'), isTrue);
    expect(game.debugVisit('HOME_b', 'PIECE_gilded_throne#0'), isTrue);
    var bowed = false;
    void bows() {
      if (game.debugResidents['HOME_b']!.angle.abs() > 0.1) bowed = true;
    }

    await run(tester, 3, bows);
    // Up on it, it holds court sitting still — not hopping as on a stage.
    var low = double.infinity, high = -double.infinity;
    await run(tester, 4, () {
      bows();
      final a = game.debugLifeOffset('HOME_a');
      if (a == null) return;
      if (a.dy < low) low = a.dy;
      if (a.dy > high) high = a.dy;
    });
    expect(high, lessThan(-40), reason: 'the first sits on it');
    expect(high - low, lessThan(2), reason: 'and sits still');
    expect(bowed, isTrue, reason: 'the second bows');
    expect(
      (game.debugLifeOffset('HOME_b')?.dy ?? 0).abs(),
      lessThan(14),
      reason: 'on the ground',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'it goes through the Great Alembic as grains and out the far end',
    (tester) async {
      final game = await mount(tester, one('great_alembic', 130));
      expect(game.debugVisit('HOME_a', 'PIECE_great_alembic#0'), isTrue);
      final still =
          game.debugThings['PIECE_great_alembic#0']! as KeepsakeComponent;
      var gone = false, carried = false;
      Offset? out;
      await run(tester, 18, () {
        if (game.debugLifeFade('HOME_a') < 0.05) gone = true;
        if (still.art.passenger != null) carried = true;
        final o = game.debugLifeOffset('HOME_a');
        if (gone &&
            game.debugLifeFade('HOME_a') == 1 &&
            o != null &&
            out == null) {
          out = o;
        }
      });
      expect(carried, isTrue, reason: 'carried through as its grains');
      expect(gone, isTrue, reason: 'it came apart');
      expect(out, isNotNull, reason: 'and gathered again');
      expect(out!.dx, greaterThan(130), reason: 'at the far end');
      expect(game.debugLifeFade('HOME_a'), 1);
      // Its grains are let go of once it is through.
      await run(tester, 1);
      expect(still.art.passenger, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('arranging mid-way through brings it back whole', (tester) async {
    final game = await mount(tester, one('great_alembic', 130));
    expect(game.debugVisit('HOME_a', 'PIECE_great_alembic#0'), isTrue);
    var gone = false;
    await run(tester, 12, () {
      if (!gone && game.debugLifeFade('HOME_a') < 0.05) {
        gone = true;
        game.arranging = true;
      }
    });
    expect(gone, isTrue);
    expect(game.debugLifeFade('HOME_a'), 1);
    expect(game.debugLifeOffset('HOME_a'), isNull, reason: 'back at its spot');
    await tester.pumpWidget(const SizedBox());
  });
}
