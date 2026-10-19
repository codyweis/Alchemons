@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/contest_judging.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/planet_dungeon/dungeon_debug_party.dart';
import 'package:alchemons/games/stadium/gem_cups.dart';
import 'package:alchemons/games/stadium/island_stage.dart';
import 'package:alchemons/games/stadium/race_bodies.dart';
import 'package:alchemons/games/stadium/race_rules.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The island, frame by frame, with real sprites: the three set down, the
// count, charges, blows, the edge crumbling (the lava widening, the stones
// drifting apart), falls, the last one standing. A Ruby Cup bout, against
// its own two rivals.
//
//   ISLAND_OUT=/tmp/island [ISLAND_KIND=sand|molten|stones] \
//     [ISLAND_PLAYER=Fire:mane] [ISLAND_V=4.6] [ISLAND_ME=0] \
//     [ISLAND_SIZE=475x751] [ISLAND_EVERY=1.2] [ISLAND_ADRIFT=1] \
//     flutter test test/island_preview_test.dart --tags preview
//
// ISLAND_PLAYER is the player's element and family (by default one made
// for the bout: a Water pip on sand, a Fire mane by the lava, an Air wing
// on the stones), ISLAND_V its ratings, ISLAND_ME its place in the three;
// ISLAND_ADRIFT=1 adds a frame whenever one goes into the lava or out over
// a gap.
void main() {
  final env = Platform.environment;
  final out = env['ISLAND_OUT'];
  final place = env['ISLAND_KIND'] ?? 'sand';
  final sizeArg = env['ISLAND_SIZE'] ?? '475x751';
  final size = Size(
    double.parse(sizeArg.split('x')[0]),
    double.parse(sizeArg.split('x')[1]),
  );

  testWidgets('island preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final catalog = CreatureCatalog();
    await tester.runAsync(catalog.load);
    final images = Images();

    final cup = kGemCups[0];
    final b = cup.bouts.indexWhere((x) => x.place == place);
    expect(b, isNot(-1), reason: 'no Ruby bout on "$place"');

    RaceBody bodyOf(String element, String family) {
      final c = catalog
          .byType(element)
          .firstWhere(
            (c) =>
                c.spriteData != null &&
                (c.mutationFamily ?? '').toLowerCase() == family,
          );
      return RaceBody(debugMemberFromCreature(c, statTier: 3));
    }

    final (el, fam) = switch (env['ISLAND_PLAYER']?.split(':')) {
      [final e, final f] => (e, f),
      _ => switch (place) {
        'molten' => ('Fire', 'mane'),
        'stones' => ('Air', 'wing'),
        _ => ('Water', 'pip'),
      },
    };
    final v = double.parse(env['ISLAND_V'] ?? '4.6');
    final meBody = bodyOf(el, fam);
    final me = Racer(
      id: '$el$fam',
      isPlayer: true,
      entrant: ContestEntrant(
        name: '$el$fam',
        element: el,
        family: fam,
        statRating: 0,
        scale: meBody.member.spriteVisuals?.scale ?? 1,
      ),
      ratings: {for (final t in CosmicContestTrait.values) t: v},
      boosts: 3,
    );
    final rivals = [
      for (final r in cup.rivalsOf(b))
        (gemRivalRacer(r, cup.rivalForm[b]), bodyOf(r.element, r.family)),
    ];
    final at = int.parse(env['ISLAND_ME'] ?? '0').clamp(0, 2);
    final three = [...rivals]..insert(at, (me, meBody));
    await tester.runAsync(() async {
      for (final (_, body) in three) {
        await body.load(images);
      }
    });
    final stage = IslandStage(
      bout: islandBoutOf(cup.bouts[b]),
      fighters: [for (final (r, _) in three) r],
      bodies: [for (final (_, body) in three) body],
      player: at,
    );

    var frame = 0;
    Future<void> shoot(String name) async {
      await tester.runAsync(() async {
        final rec = ui.PictureRecorder();
        IslandPainter(stage).paint(Canvas(rec)..scale(2), size);
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

    // How long the painter takes a frame (recorded, not rasterised).
    var paintUs = 0, paints = 0;
    const dt = 1 / 30;
    var taps = 0;
    final adrift = [false, false, false];
    var shotIn = 0;
    final every = env['ISLAND_EVERY'];
    final step = every == null ? 1.2 : double.parse(every);
    for (
      var t = 0.0;
      t < 100 && stage.phase != IslandStagePhase.done;
      t += dt
    ) {
      stage.advance(dt);
      for (final body in stage.bodies) {
        body.ticker?.update(dt);
      }
      // The player charges three times, a few seconds apart.
      if (stage.fighting &&
          taps < 3 &&
          stage.fightClock > 3 + taps * 6 &&
          stage.tapCharge()) {
        taps++;
      }
      if (stage.fighting) {
        final watch = Stopwatch()..start();
        final rec = ui.PictureRecorder();
        IslandPainter(stage).paint(Canvas(rec), size);
        rec.endRecording().dispose();
        paintUs += watch.elapsedMicroseconds;
        paints++;
      }
      // A moment after one goes into the lava or out over a gap, a frame
      // of it there (ISLAND_ADRIFT=1).
      if (env['ISLAND_ADRIFT'] != null && stage.fighting) {
        for (var i = 0; i < 3; i++) {
          final now = stage.sim.adrift(i);
          if (now && !adrift[i]) shotIn = 5;
          adrift[i] = now;
        }
        if (shotIn > 0 && --shotIn == 0) await shoot('adrift');
      }
      if ((t / step).floor() != ((t - dt) / step).floor()) {
        await shoot(stage.phase.name);
      }
    }
    await shoot('end');
    final how = [
      for (final st in stage.sim.states)
        st.fellAt == null
            ? 'stood'
            : '${st.sank ? 'lava' : 'fell'} '
                  '${(st.fellAt! / 60).toStringAsFixed(1)} s',
    ];
    // ignore: avoid_print
    print(
      'standings ${stage.standings} after '
      '${stage.fightClock.toStringAsFixed(1)} s ($how) · paint '
      '${(paintUs / paints / 1000).toStringAsFixed(2)} ms a frame',
    );
  });
}
