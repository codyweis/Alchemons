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
import 'package:alchemons/screens/stadium/route_planner.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The space course, frame by frame, with real sprites: the three come up,
// the count, the forks parting them onto their own ways and bringing them
// back, wells slung round, gates fused through, boosts, the gate. And the
// route planner before it, with real fonts.
//
//   FLIGHT_OUT=/tmp/flight [FLIGHT_COURSE=asteroids|gravity|gates] \
//     [FLIGHT_SIZE=475x751] [FLIGHT_EVERY=1.2] \
//     flutter test test/flight_preview_test.dart --tags preview
//
// FLIGHT_PLANNER=1 shoots only the planner. FLIGHT_COST=1 prints the
// painter's cost per frame.
void main() {
  final env = Platform.environment;
  final out = env['FLIGHT_OUT'];
  final place = env['FLIGHT_COURSE'] ?? 'asteroids';
  final sizeArg = env['FLIGHT_SIZE'] ?? '475x751';
  final size = Size(
    double.parse(sizeArg.split('x')[0]),
    double.parse(sizeArg.split('x')[1]),
  );

  // Each course flown by three that show what it does.
  final lineups = <String, List<(String, String, double)>>{
    'asteroids': [
      ('Water', 'pip', 4.6),
      ('Air', 'wing', 4.5),
      ('Earth', 'horn', 4.4),
    ],
    'gravity': [
      ('Spirit', 'mask', 4.6),
      ('Air', 'wing', 4.5),
      ('Earth', 'horn', 4.4),
    ],
    'gates': [
      ('Fire', 'pip', 4.6),
      ('Poison', 'let', 4.5),
      ('Light', 'wing', 4.5),
    ],
  };

  Future<void> loadFont(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer))))
        .load();
  }

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

    final course = kFlightCourses[place]!;
    final three = [
      for (final (e, f, v) in lineups[place] ?? lineups['asteroids']!)
        one(
          e,
          f,
          v,
          player: e == (lineups[place] ?? lineups['asteroids']!).first.$1,
        ),
    ];

    if (env['FLIGHT_PLANNER'] != null) {
      await tester.runAsync(() async {
        await loadFont(
          'Roboto',
          '/System/Library/Fonts/Supplemental/Arial.ttf',
        );
      });
      final key = GlobalKey();
      final nav = GlobalKey<NavigatorState>();
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) => RepaintBoundary(key: key, child: child!),
          home: const Scaffold(backgroundColor: Color(0xFF09090B)),
        ),
      );
      planFlightRoute(
        nav.currentContext!,
        title: place == 'gates'
            ? 'Element Gates'
            : (place == 'gravity' ? 'Gravity Chain' : 'Asteroid Run'),
        subtitle: 'EMERALD CUP · PLAN YOUR ROUTE',
        course: course,
        racer: three.first.$1,
      );
      for (var q = 0; q < 30; q++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/planner.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      nav.currentState!.pop();
      await tester.pump(const Duration(milliseconds: 400));
      return;
    }

    final choices = [for (final (r, _) in three) bestFlightRoute(r, course)];
    final fighters = [for (final (r, _) in three) r];
    final bodies = [for (final (_, b) in three) b];
    final forms = flightForms(catalog, fighters, bodies, course, choices);
    await tester.runAsync(() async {
      for (final m in forms) {
        for (final b in m.values) {
          if (b.ticker == null) await b.load(images);
        }
      }
    });
    final stage = FlightStage(
      course: course,
      choices: choices,
      fighters: fighters,
      bodies: bodies,
      forms: forms,
      player: 0,
    );
    // ignore: avoid_print
    print(
      'routes $choices elements ${[for (final l in stage.sim.legs) l.elements]}',
    );

    // One painter for the whole flight (it keeps its fusions' essences).
    final painter = FlightPainter(stage);
    final timed = <int>[];
    var frame = 0;
    Future<void> shoot(String name) async {
      await tester.runAsync(() async {
        final rec = ui.PictureRecorder();
        painter.paint(Canvas(rec)..scale(2), size);
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
    final every = env['FLIGHT_EVERY'];
    final step = every == null ? 1.2 : double.parse(every);
    for (var t = 0.0; t < 90 && !stage.done; t += dt) {
      stage.advance(dt);
      for (final m in forms) {
        for (final b in m.values) {
          b.ticker?.update(dt);
        }
      }
      // The player dashes three times, a few seconds apart.
      if (stage.flying &&
          taps < 3 &&
          stage.flyClock > 3 + taps * 8 &&
          stage.act()) {
        taps++;
      }
      if (env['FLIGHT_COST'] != null && stage.flying) {
        final rec = ui.PictureRecorder();
        final watch = Stopwatch()..start();
        painter.paint(Canvas(rec), size);
        timed.add(watch.elapsedMicroseconds);
        rec.endRecording().dispose();
      }
      if ((t / step).floor() != ((t - dt) / step).floor()) {
        await shoot(stage.flying ? 'fly' : 'other');
      }
    }
    await shoot('end');
    // ignore: avoid_print
    print(
      'standings ${stage.standings} times ${[for (final st in stage.sim.states) st.finishTime]}',
    );
    if (timed.isNotEmpty) {
      timed.sort();
      // ignore: avoid_print
      print(
        'paint µs: median ${timed[timed.length ~/ 2]} '
        'p90 ${timed[timed.length * 9 ~/ 10]} max ${timed.last}',
      );
    }
  });
}
