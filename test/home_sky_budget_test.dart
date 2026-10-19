// The home's sky, its seasons, its marks and its secrets cost a few draws
// a frame, whatever the planet wears: every effect at once, every
// constellation, marks, a harmony's thread and a buried shard's eddy, in
// every realm, by night and by day — no blur, no per-frame paths beyond
// the moon's, and within the fields' own ceilings with room to spare.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/wilderness/field/home_sky_art.dart';
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:alchemons/models/constellation/constellation_layout.dart';
import 'package:alchemons/models/home_biome.dart';
import 'package:alchemons/models/home_sky.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _CensusCanvas implements Canvas {
  final Map<String, int> counts = {};
  int blurredDraws = 0;
  int points = 0;

  @override
  dynamic noSuchMethod(Invocation i) {
    final n = i.memberName.toString();
    final key = n.substring(8, n.length - 2);
    counts[key] = (counts[key] ?? 0) + 1;
    for (final a in i.positionalArguments) {
      if (a is Paint && a.maskFilter != null) blurredDraws++;
      if (key == 'drawRawPoints' && a is Float32List) points += a.length ~/ 2;
    }
    if (key == 'getSaveCount') return 1;
    return null;
  }

  int get draws => counts.entries
      .where((e) => e.key.startsWith('draw'))
      .fold(0, (s, e) => s + e.value);
}

void main() {
  final layouts = {
    for (final t in ConstellationTree.values) t: constellationTreeLayout(t),
  };
  final (stars, links) = skyStarsFor({
    for (final s in ConstellationCatalog.allSkills) s.id,
  }, layouts);
  final everything = HomeSkyLook(
    color: 'Crystal',
    tint: homeColorSwatch('Crystal'),
    wearing: {
      for (final r in kHomeRecipes)
        if (r.category == HomeRecipeCategory.visual) r.id,
    },
    stars: stars,
    links: links,
  );

  for (final realm in HomeRealm.values) {
    for (final hour in const [13.0, 23.0]) {
      testWidgets('${realm.name} at ${hour.round()}:00 with all of it', (
        tester,
      ) async {
        const screen = Size(915, 412);
        tester.view.physicalSize = screen * 2.625;
        tester.view.devicePixelRatio = 2.625;
        addTearDown(tester.view.reset);
        final row = realm.row(HomeDepth.front);
        final period = realm.period(row.layer);
        final layout = HomeBiomeLayout(realm: realm);
        final game =
            SceneGame(scene: layout.scene((_) => false), showcase: true)
              ..fieldHourOverride = hour
              ..homeSky = everything
              ..fieldSeason = HomeSeason.autumn
              ..fadingMarks = [
                for (final (i, e) in const [
                  'Fire',
                  'Ice',
                  'Plant',
                  'Blood',
                ].indexed)
                  GroundMark(
                    layer: row.layer,
                    x: period * (0.1 + 0.1 * i),
                    period: period,
                    feet: row.feet,
                    size: row.size,
                    element: e,
                    strength: 1,
                  ),
              ]
              ..buried = BuriedCue(
                layer: row.layer,
                x: period * 0.2,
                period: period,
                feet: row.feet,
                size: row.size,
                color: const Color(0xFFA8DCFF),
              );
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
        var worst = _CensusCanvas();
        for (var f = 0; f < 45; f++) {
          game.update(1 / 30);
          final c = _CensusCanvas();
          game.render(c);
          if (c.draws > worst.draws) worst = c;
        }
        // ignore: avoid_print
        print(
          '${realm.name} ${hour.round()}h: ${worst.draws} draws, '
          '${worst.points} grains ${worst.counts}',
        );
        expect(worst.blurredDraws, 0);
        expect(worst.draws, lessThan(150));
        expect(worst.points, lessThan(20000));
        // A real frame renders without error.
        final rec = ui.PictureRecorder();
        game.render(Canvas(rec));
        rec.endRecording().dispose();
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
