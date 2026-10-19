@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/wilderness/field/home_sky_art.dart';
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:alchemons/models/constellation/constellation_layout.dart';
import 'package:alchemons/models/home_biome.dart';
import 'package:alchemons/models/home_sky.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The home's sky — the planet's look from its ground, the constellations,
// the seasons — through the real SceneGame and field.
//
//   SKY_OUT=/tmp/sky flutter test test/home_sky_preview_test.dart \
//     --tags preview
//
// SKY_OUT is a directory: one PNG per frame and a sheet per set.
// SKY_ONLY picks frame-name prefixes (effects_, color_, stars_, season_),
// SKY_REALM the field (valley, sky, swamp, volcano, arcane, dunes, geode,
// tidal).
void main() {
  final out = Platform.environment['SKY_OUT'];

  testWidgets('home sky preview', (tester) async {
    if (out == null) return;
    const screen = Size(751, 475);
    const dpr = 2.625;
    tester.view.physicalSize = screen * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    Directory(out).createSync(recursive: true);
    final only = Platform.environment['SKY_ONLY']?.split(',');
    bool wanted(String name) =>
        only == null || only.any((p) => name.startsWith(p));
    final realm = Platform.environment['SKY_REALM'] ?? 'valley';
    // The home's own field: the realm's scenery as a home starts with it.
    final home = HomeBiomeLayout(realm: HomeRealm.byName(realm));
    final scene = home.scene((_) => false);

    final layouts = {
      for (final t in ConstellationTree.values) t: constellationTreeLayout(t),
    };
    final (allStars, allLinks) = skyStarsFor({
      for (final s in ConstellationCatalog.allSkills) s.id,
    }, layouts);
    final (someStars, someLinks) = skyStarsFor({
      for (final s in ConstellationCatalog.allSkills)
        if (s.tier <= 3) s.id,
    }, layouts);

    Future<ui.Image> shoot({
      required double hour,
      HomeSkyLook? look,
      HomeSeason? season,
      double t = 2.0,
      List<GroundMark> marks = const [],
      SceneDefinition? inScene,
      int stage = 0,
      BuriedCue? cue,
    }) async {
      final game = SceneGame(scene: inScene ?? scene, showcase: true)
        ..fieldHourOverride = hour
        ..homeSky = look
        ..fieldSeason = season
        ..fieldStage = stage
        ..fadingMarks = marks
        ..buried = cue;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: screen.width,
              height: screen.height,
              child: GameWidget(game: game),
            ),
          ),
        ),
      );
      for (var i = 0; i < 40 && !game.isLoaded; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      const dt = 1 / 30;
      for (var clock = 0.0; clock < t; clock += dt) {
        game.update(dt);
      }
      final rec = ui.PictureRecorder();
      game.render(Canvas(rec));
      final img = rec.endRecording().toImageSync(
        screen.width.round(),
        screen.height.round(),
      );
      await tester.pumpWidget(const SizedBox());
      return img;
    }

    final sets = <String, List<(String, ui.Image)>>{};
    Future<void> add(
      String set,
      String name,
      Future<ui.Image> Function() make,
    ) async {
      if (!wanted(name)) return;
      (sets[set] ??= []).add((name, await make()));
    }

    // Every visual effect a planet can wear, by day and by night, over a
    // grey planet so only the effect shows.
    final effects = [
      for (final r in kHomeRecipes)
        if (r.category == HomeRecipeCategory.visual) r.id,
    ];
    // What comes and goes, caught at its moment.
    const moments = {'lightning_rod': 7.08, 'phantom_phase': 4.0};
    for (final id in effects) {
      for (final h in const [13.0, 23.0]) {
        await add(
          'effects',
          'effects_${id}_${h.round()}',
          () => shoot(
            hour: h,
            look: HomeSkyLook(wearing: {id}),
            t: moments[id] ?? 2.0,
          ),
        );
      }
    }
    // The planet's own color.
    for (final c in const ['Fire', 'Water', 'Crystal', 'Void', 'Radiant']) {
      for (final h in const [13.0, 19.4, 23.0]) {
        await add(
          'color',
          'color_${c}_${h.toStringAsFixed(1)}',
          () => shoot(
            hour: h,
            look: HomeSkyLook(color: c, tint: homeColorSwatch(c)),
          ),
        );
      }
    }
    // Constellations: a few stones owned, and all of them.
    await add(
      'stars',
      'stars_some',
      () => shoot(
        hour: 23,
        look: HomeSkyLook(stars: someStars, links: someLinks),
      ),
    );
    await add(
      'stars',
      'stars_all',
      () => shoot(
        hour: 23,
        look: HomeSkyLook(stars: allStars, links: allLinks),
      ),
    );
    await add(
      'stars',
      'stars_all_dusk',
      () => shoot(
        hour: 20.6,
        look: HomeSkyLook(stars: allStars, links: allLinks),
      ),
    );
    // The seasons, by day and at golden hour.
    for (final s in HomeSeason.values) {
      for (final h in const [12.0, 18.6]) {
        await add(
          'season',
          'season_${s.name}_${h.round()}',
          () => shoot(hour: h, season: s),
        );
      }
    }

    // Every element's mark on the front row, at its strongest, across the
    // first screen of it.
    final row = home.realm.row(HomeDepth.front);
    final period = home.realm.period(row.layer);
    const elements = [
      'Fire', 'Lava', 'Lightning', 'Water', 'Ice', 'Steam', 'Earth', 'Mud',
      'Dust', 'Crystal', 'Air', 'Plant', 'Poison', 'Spirit', 'Dark', 'Light',
      'Blood',
    ];
    for (final (half, list) in [
      (0, elements.sublist(0, 9)),
      (1, elements.sublist(9)),
    ]) {
      final marks = [
        for (var i = 0; i < list.length; i++)
          GroundMark(
            layer: row.layer,
            x: screen.width * (0.08 + 0.84 * i / (list.length - 1)),
            period: period,
            feet: row.feet,
            size: row.size,
            element: list[i],
            strength: 1,
            seed: i * 7,
          ),
      ];
      for (final h in const [13.0, 23.0]) {
        await add(
          'marks',
          'marks_${half}_${h.round()}',
          () => shoot(hour: h, marks: marks),
        );
      }
    }

    // The Core: still and beating, under planets of three colors.
    final core = const HomeBiomeLayout(realm: HomeRealm.core).scene((_) => false);
    for (final c in const [null, 'Crystal', 'Fire', 'Void']) {
      for (final stage in const [0, 1]) {
        await add(
          'core',
          'core_${c ?? 'plain'}_$stage',
          () => shoot(
            hour: 23,
            inScene: core,
            stage: stage,
            t: 2.3,
            look: HomeSkyLook(
              color: c,
              tint: c == null ? null : homeColorSwatch(c),
            ),
          ),
        );
      }
    }
    // Where a shard lies, as the place shows it: by night and by day.
    for (final h in const [13.0, 23.0]) {
      await add(
        'cue',
        'cue_${h.round()}',
        () => shoot(
          hour: h,
          cue: BuriedCue(
            layer: row.layer,
            x: screen.width * 0.5,
            period: period,
            feet: row.feet,
            size: row.size,
            color: const Color(0xFF8EDB72),
          ),
        ),
      );
    }

    await tester.runAsync(() async {
      for (final e in sets.entries) {
        final frames = e.value;
        for (final (name, img) in frames) {
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        }
        // A sheet of the set, two across.
        final cw = screen.width / 2, ch = screen.height / 2;
        final cols = e.key == 'color' ? 3 : 2;
        final rows = (frames.length / cols).ceil();
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        for (var i = 0; i < frames.length; i++) {
          final img = frames[i].$2;
          c.drawImageRect(
            img,
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            Rect.fromLTWH((i % cols) * cw, (i ~/ cols) * ch, cw, ch),
            Paint()..filterQuality = FilterQuality.medium,
          );
        }
        final sheet = rec.endRecording().toImageSync(
          (cw * cols).round(),
          (ch * rows).round(),
        );
        final bytes = await sheet.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$out/sheet_${e.key}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
      }
    });
  });
}
