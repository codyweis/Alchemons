@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/dungeon_debug_party.dart';
import 'package:alchemons/games/stadium/race_bodies.dart';
import 'package:alchemons/games/stadium/race_cups.dart';
import 'package:alchemons/games/stadium/race_painter.dart';
import 'package:alchemons/games/stadium/race_rules.dart';
import 'package:alchemons/games/stadium/race_stage.dart';
import 'package:alchemons/games/stadium/stadium_space_art.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The race, frame by frame, with real sprites: the line-up, the count, a
// boost, the wall, a fusion, the show ring, a photo finish, the podium,
// rain and storm, and the stadium as it hangs in space.
//
//   RACE_OUT=/tmp/race flutter test test/race_preview_test.dart --tags preview
//   RACE_SIZE=916x265 for the folded Fold.
void main() {
  final out = Platform.environment['RACE_OUT'];
  final sizeArg = Platform.environment['RACE_SIZE'] ?? '844x390';
  final size = Size(
    double.parse(sizeArg.split('x')[0]),
    double.parse(sizeArg.split('x')[1]),
  );

  Future<void> loadFont(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer))))
        .load();
  }

  setUpAll(() async {
    await loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial.ttf');
  });

  testWidgets('race preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final catalog = CreatureCatalog();
    await tester.runAsync(catalog.load);
    const type = TextStyle(fontFamily: 'Roboto');
    await tester.runAsync(() => loadRaceNumerals(style: type));
    final images = Images();

    CosmicPartyMember member(String element, double speed) {
      final c = catalog
          .byType(element)
          .firstWhere(
            (c) =>
                c.spriteData != null &&
                (c.mutationFamily ?? '').toLowerCase() == 'mane',
          );
      final m = debugMemberFromCreature(c, statTier: 3);
      return CosmicPartyMember(
        instanceId: m.instanceId,
        baseId: m.baseId,
        displayName: m.displayName,
        element: m.element,
        family: m.family,
        level: 1,
        statSpeed: speed,
        statIntelligence: 3,
        statStrength: 3,
        statBeauty: 3,
        slotIndex: 0,
        staminaBars: 3,
        staminaMax: 3,
        spriteSheet: m.spriteSheet,
      );
    }

    Future<RaceStage> stageFor(
      int cup,
      int race,
      String element, {
      double speed = 3,
    }) async {
      final (racers, bodies) = raceSix(
        catalog,
        kRaceCups[cup],
        race,
        member(element, speed),
        null,
      );
      final forms = raceForms(
        catalog,
        racers,
        bodies,
        kRaceCups[cup].courses[race],
      );
      await tester.runAsync(() async {
        for (final f in forms) {
          for (final b in f.values) {
            await b.load(images);
          }
        }
      });
      return RaceStage(
        course: kRaceCups[cup].courses[race],
        racers: racers,
        bodies: bodies,
        player: racers.indexWhere((r) => r.isPlayer),
        numerals: raceNumeralGrains,
        forms: forms,
      )..viewport = size;
    }

    Future<void> shoot(RaceStage stage, String name) async {
      await tester.runAsync(() async {
        final rec = ui.PictureRecorder();
        RacePainter(stage, textStyle: type).paint(Canvas(rec)..scale(2), size);
        final img = rec.endRecording().toImageSync(
          (size.width * 2).round(),
          (size.height * 2).round(),
        );
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
        img.dispose();
      });
    }

    void tick(RaceStage s) {
      s.advance(1 / 60);
      for (final b in s.bodies) {
        b.ticker?.update(1 / 60);
      }
    }

    void runTo(RaceStage s, double clock) {
      while (s.clock < clock) {
        tick(s);
      }
    }

    void runUntil(RaceStage s, bool Function(RaceStage) when) {
      while (!when(s) && s.phase != RaceStagePhase.done) {
        tick(s);
      }
    }

    bool inLeg(RaceStage s, RaceLegKind k, double f) {
      final (leg, ff) = s.layout.legAt(s.distance[s.player]);
      return s.course.legs[leg].kind == k && ff >= f;
    }

    // Copper, Open Track (round the stadium): the line-up, the count, a
    // boost, the hill, the fusion, the crowd, the line, the podium.
    final intro = Platform.environment['RACE_ONLY'] == null;
    var s = await stageFor(0, 0, 'Fire');
    runTo(s, 1.2);
    if (intro) await shoot(s, '01_lineup');
    runTo(s, RaceStage.introSeconds + 1.55);
    if (intro) await shoot(s, '02_count');
    runTo(s, RaceStage.introSeconds + RaceStage.countdownSeconds + 1.9);
    s.tapBoost();
    runTo(s, s.clock + 0.9);
    if (intro) await shoot(s, '03_boost');
    runUntil(s, (s) => inLeg(s, RaceLegKind.hill, 0.35));
    if (intro) await shoot(s, '04_hill');
    runUntil(s, (s) => inLeg(s, RaceLegKind.fuse, 0.45));
    if (intro) await shoot(s, '05_fusion');
    runUntil(s, (s) => inLeg(s, RaceLegKind.crowd, 0.5));
    if (intro) await shoot(s, '06_crowd');
    runUntil(s, (s) => s.finishedAtClock.any((f) => f != null));
    runTo(s, s.clock + 0.35);
    if (intro) await shoot(s, '07_line');
    runUntil(s, (s) => s.phase == RaceStagePhase.podium);
    runTo(s, s.clock + 1.7);
    if (intro) await shoot(s, '08_podium');

    // What a frame costs to paint, mid-race (JIT, so a ceiling), out in
    // the country.
    {
      final probe = await stageFor(1, 1, 'Fire');
      runUntil(probe, (s) => inLeg(s, RaceLegKind.hill, 0.3));
      final painter = RacePainter(probe, textStyle: type);
      final watch = Stopwatch();
      for (var f = 0; f < 240; f++) {
        tick(probe);
        final rec = ui.PictureRecorder();
        watch.start();
        painter.paint(Canvas(rec), size);
        watch.stop();
        rec.endRecording().dispose();
      }
      // ignore: avoid_print
      print(
        'race paint: ${(watch.elapsedMicroseconds / 240).round()} µs/frame',
      );
    }

    // A photo finish: the player's speed tuned until two meet the line
    // together.
    RaceStage? photo;
    for (var v = 2.3; intro && v < 3.6 && photo == null; v += 0.02) {
      final probe = await stageFor(0, 0, 'Fire', speed: v);
      runUntil(
        probe,
        (s) => s.photoAt != null || s.finishedAtClock.any((f) => f != null),
      );
      if (probe.photoAt != null) photo = probe;
    }
    if (photo != null) {
      runTo(photo, photo.clock + 0.9);
      await shoot(photo, '09_photo');
    }

    // Every course, out in its own country: the middle of each stretch
    // that asks something, and the first sprint out of the stadium. A
    // Water racer, so a pond is swum, and a Wing racer on the gap courses.
    const elements = {
      (0, 1): 'Water',
      (1, 0): 'Air',
      (2, 0): 'Air',
      (2, 2): 'Air',
    };
    // RACE_ONLY=c01,c22 for some courses; RACE_TOUR=0 for none.
    final only = Platform.environment['RACE_ONLY']?.split(',');
    final tour = Platform.environment['RACE_TOUR'] != '0';
    for (var cup = 0; tour && cup < kRaceCups.length; cup++) {
      for (var race = 0; race < kRaceCups[cup].courses.length; race++) {
        if (only != null && !only.contains('c$cup$race')) continue;
        final course = kRaceCups[cup].courses[race];
        final st = await stageFor(cup, race, elements[(cup, race)] ?? 'Fire');
        final tag = 'c${cup}${race}_${course.id}';
        for (var j = 0; j < course.legs.length; j++) {
          final leg = course.legs[j];
          final first = j == 0;
          if (leg.kind == RaceLegKind.sprint && leg.level == 1 && !first) {
            continue;
          }
          final at = first ? 0.85 : 0.5;
          runUntil(st, (s) {
            final (l, f) = s.layout.legAt(s.distance[s.player]);
            return l > j || (l == j && f >= at);
          });
          await shoot(st, '${tag}_${j}_${leg.kind.name}${leg.level}');
        }
      }
    }

    // RACE_FUSE=1: a Fire racer through Open Track's Water station, frame
    // by frame, coming apart as itself and gathering back as Steam.
    if (Platform.environment['RACE_FUSE'] == '1') {
      final st = await stageFor(0, 0, 'Fire');
      runUntil(st, (s) => inLeg(s, RaceLegKind.fuse, 0.0));
      var n = 0;
      while (st.distance[st.player] < st.course.legStarts[4] + 60) {
        for (var k = 0; k < 8; k++) {
          tick(st);
        }
        await shoot(st, 'fuse_${(n++).toString().padLeft(2, '0')}');
      }
      // And on the podium, back to themselves.
      runUntil(st, (s) => s.phase == RaceStagePhase.podium);
      for (final at in [0.6, 1.6, 2.1, 2.6, 3.2, 4.4]) {
        runUntil(st, (s) => s.podiumClock >= at);
        await shoot(st, 'podium_${at.toStringAsFixed(1)}');
      }
    }

    // RACE_GIF=c20 (cup, race): a frame every RACE_GIF_EVERY seconds (0.2)
    // of a whole race, from the line-up to the podium, under gif/.
    final gif = Platform.environment['RACE_GIF'];
    if (gif != null) {
      final cup = int.parse(gif[1]), race = int.parse(gif[2]);
      final every =
          double.tryParse(Platform.environment['RACE_GIF_EVERY'] ?? '') ?? 0.2;
      final st = await stageFor(cup, race, 'Water', speed: 3.6);
      Directory('$out/gif').createSync(recursive: true);
      var n = 0;
      var next = 0.0;
      // A boost on each of the first three legs that ask something.
      final boostLegs = <int>{};
      while (st.phase != RaceStagePhase.done || st.resultsClock < 0.5) {
        tick(st);
        final (leg, _) = st.layout.legAt(st.distance[st.player]);
        if (st.course.legs[leg].kind != RaceLegKind.sprint &&
            boostLegs.length < 3 &&
            !boostLegs.contains(leg) &&
            st.tapBoost()) {
          boostLegs.add(leg);
        }
        if (st.clock >= next) {
          next += every;
          await shoot(st, 'gif/${(n++).toString().padLeft(4, '0')}');
        }
        if (st.clock > 120) break;
      }
    }

    // The stadium as it hangs in space: far, near, and as the story's
    // beacon.
    await tester.runAsync(() async {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawRect(
        const Rect.fromLTWH(0, 0, 3000, 1100),
        Paint()..color = const Color(0xFF050507),
      );
      paintStadium(c, at: const Offset(500, 380), t: 3.2);
      paintStadium(c, at: const Offset(1500, 380), t: 3.2, near: 1);
      paintStadium(c, at: const Offset(2500, 380), t: 3.2, beacon: true);
      final img = rec.endRecording().toImageSync(3000, 1100);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$out/13_space.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
