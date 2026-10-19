@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/contest_judging.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/planet_dungeon/dungeon_debug_party.dart';
import 'package:alchemons/games/stadium/race_bodies.dart';
import 'package:alchemons/games/stadium/race_rules.dart';
import 'package:alchemons/games/stadium/sky_rules.dart';
import 'package:alchemons/games/stadium/sky_stage.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The night sky, frame by frame, with real sprites: the three come up on
// the ridge, their figures drawn in faint, the casts round by round, the
// stars they light, the fullest figure burning brighter at the end. Also
// times the painter over every frame (recording only).
//
//   SKY_OUT=/tmp/sky [SKY_NIGHT=clear|mirror|fusion] [SKY_SIZE=475x751] \
//     [SKY_THREE=Water:pip,Fire:mane,Earth:horn] [SKY_EVERY=1.2] \
//     flutter test test/sky_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['SKY_OUT'];
  final night = SkyNight.values.byName(
    Platform.environment['SKY_NIGHT'] ?? 'clear',
  );
  final sizeArg = Platform.environment['SKY_SIZE'] ?? '475x751';
  final size = Size(
    double.parse(sizeArg.split('x')[0]),
    double.parse(sizeArg.split('x')[1]),
  );
  final threeArg =
      Platform.environment['SKY_THREE'] ?? 'Water:pip,Fire:mane,Earth:horn';

  testWidgets('sky preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final catalog = CreatureCatalog();
    await tester.runAsync(catalog.load);
    final images = Images();

    (Racer, RaceBody) one(
      String element,
      String family,
      double v, {
      bool player = false,
    }) {
      final c = catalog
          .byType(element)
          .firstWhere(
            (c) =>
                c.spriteData != null &&
                (c.mutationFamily ?? '').toLowerCase() == family,
          );
      final m = debugMemberFromCreature(c, statTier: 3);
      final racer = Racer(
        id: '$element$family',
        isPlayer: player,
        entrant: ContestEntrant(
          name: c.name,
          element: element,
          family: family,
          statRating: 0,
          scale: m.spriteVisuals?.scale ?? 1,
        ),
        ratings: {for (final t in CosmicContestTrait.values) t: v},
        boosts: 3,
      );
      return (racer, RaceBody(m));
    }

    final picks = threeArg.split(',');
    final three = [
      for (var i = 0; i < picks.length; i++)
        one(
          picks[i].split(':')[0],
          picks[i].split(':')[1],
          [4.6, 4.3, 4.0][i % 3],
          player: i == 0,
        ),
    ];
    late final List<SkyFigure> figures;
    await tester.runAsync(() async {
      for (final (_, b) in three) {
        await b.load(images);
      }
      figures = await loadSkyFigures([for (final (_, b) in three) b]);
    });
    final stage = SkyStage(
      figures: figures,
      bout: SkyBout(night, 2),
      fighters: [for (final (r, _) in three) r],
      bodies: [for (final (_, b) in three) b],
      player: 0,
    );

    var frame = 0;
    Future<void> shoot(String name) async {
      await tester.runAsync(() async {
        final rec = ui.PictureRecorder();
        SkyPainter(stage).paint(Canvas(rec)..scale(2), size);
        final img = rec.endRecording().toImageSync(
          (size.width * 2).round(),
          (size.height * 2).round(),
        );
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$out/${(frame++).toString().padLeft(3, '0')}_$name.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
        img.dispose();
      });
    }

    const dt = 1 / 30;
    final every = Platform.environment['SKY_EVERY'];
    final step = every == null ? 1.2 : double.parse(every);
    final watch = Stopwatch();
    var painted = 0, worst = 0;
    for (var t = 0.0; t < 60 && !stage.done; t += dt) {
      stage.advance(dt);
      for (final b in stage.bodies) {
        b.ticker?.update(dt);
      }
      // What a frame costs to record.
      final rec = ui.PictureRecorder();
      final before = watch.elapsedMicroseconds;
      watch.start();
      SkyPainter(stage).paint(Canvas(rec), size);
      watch.stop();
      rec.endRecording().dispose();
      if (painted++ < 30) {
        watch.reset();
      } else {
        worst = max(worst, watch.elapsedMicroseconds - before);
      }
      if ((t / step).floor() != ((t - dt) / step).floor()) {
        await shoot(stage.phase.name);
      }
    }
    await shoot('end');
    // ignore: avoid_print
    print(
      'standings ${stage.standings} stars '
      '${[for (var i = 0; i < 3; i++) stage.contest.starsOf(i)]} '
      'over at ${stage.clock.toStringAsFixed(1)} s · paint '
      '${(watch.elapsedMicroseconds / max(1, painted - 30) / 1000).toStringAsFixed(3)}'
      ' ms a frame (worst ${(worst / 1000).toStringAsFixed(2)} ms)',
    );
  });
}
