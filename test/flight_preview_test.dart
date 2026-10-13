@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/contest_judging.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/planet_dungeon/dungeon_debug_party.dart';
import 'package:alchemons/games/stadium/flight_rules.dart';
import 'package:alchemons/games/stadium/flight_stage.dart';
import 'package:alchemons/games/stadium/race_bodies.dart';
import 'package:alchemons/games/stadium/race_rules.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The space course, frame by frame, with real sprites: the three come up,
// the count, the forks parting them onto their own ways and bringing them
// back, boosts, the gate.
//
//   FLIGHT_OUT=/tmp/flight [FLIGHT_COURSE=asteroids|nebula|stars] \
//     [FLIGHT_SIZE=475x751] flutter test test/flight_preview_test.dart \
//     --tags preview
void main() {
  final out = Platform.environment['FLIGHT_OUT'];
  final place = Platform.environment['FLIGHT_COURSE'] ?? 'asteroids';
  final sizeArg = Platform.environment['FLIGHT_SIZE'] ?? '475x751';
  final size = Size(
    double.parse(sizeArg.split('x')[0]),
    double.parse(sizeArg.split('x')[1]),
  );

  testWidgets('flight preview', (tester) async {
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
        autoBoostLegs: player ? const [] : const [0],
      );
      return (racer, RaceBody(m));
    }

    final three = [
      one('Water', 'pip', 4.6, player: true),
      one('Air', 'wing', 4.5),
      one('Earth', 'horn', 4.4),
    ];
    await tester.runAsync(() async {
      for (final (_, b) in three) {
        await b.load(images);
      }
    });
    final course = kFlightCourses[place]!;
    final stage = FlightStage(
      course: course,
      choices: [for (final (r, _) in three) bestFlightRoute(r, course)],
      fighters: [for (final (r, _) in three) r],
      bodies: [for (final (_, b) in three) b],
      player: 0,
    );

    var frame = 0;
    Future<void> shoot(String name) async {
      await tester.runAsync(() async {
        final rec = ui.PictureRecorder();
        FlightPainter(stage).paint(Canvas(rec)..scale(2), size);
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
    var taps = 0;
    for (var t = 0.0; t < 70 && !stage.done; t += dt) {
      stage.advance(dt);
      for (final b in stage.bodies) {
        b.ticker?.update(dt);
      }
      // The player dashes three times, a few seconds apart.
      if (stage.flying &&
          taps < 3 &&
          stage.flyClock > 3 + taps * 8 &&
          stage.act()) {
        taps++;
      }
      final every = Platform.environment['FLIGHT_EVERY'];
      final step = every == null ? 1.2 : double.parse(every);
      if ((t / step).floor() != ((t - dt) / step).floor()) {
        await shoot(stage.flying ? 'fly' : 'other');
      }
    }
    await shoot('end');
    // ignore: avoid_print
    print(
      'standings ${stage.standings} times ${[for (final st in stage.sim.states) st.finishTime]}',
    );
  });
}
