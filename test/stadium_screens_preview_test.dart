@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/dungeon_debug_party.dart';
import 'package:alchemons/games/stadium/race_bodies.dart';
import 'package:alchemons/games/stadium/race_cups.dart';
import 'package:alchemons/games/stadium/trials_records.dart';
import 'package:alchemons/screens/stadium/race_screen.dart';
import 'package:alchemons/screens/stadium/stadium_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The stadium's screens with real fonts and sprites: the ladder, a race
// mid-run with its HUD, and the results.
//
//   STADIUM_OUT=/tmp/stadium flutter test \
//     test/stadium_screens_preview_test.dart --tags preview
//   STADIUM_SIZE=475x751 for the folded Fold (the Trials upright; the race
//   the same screen turned); STADIUM_PROGRESS (below).
void main() {
  final out = Platform.environment['STADIUM_OUT'];
  final sizeArg = Platform.environment['STADIUM_SIZE'] ?? '390x844';
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
    await loadFont(
      'monospace',
      '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
    );
  });

  testWidgets('stadium screens', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    // STADIUM_PROGRESS='{"copper":3,"silver":1}' for a ladder part climbed.
    final progress = Platform.environment['STADIUM_PROGRESS'];
    SharedPreferences.setMockInitialValues({
      if (progress != null) 'stadium_race_progress_v1': progress,
    });
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final catalog = CreatureCatalog();
    await tester.runAsync(catalog.load);
    final images = Images();

    CosmicPartyMember member(String element, String family, double stat) {
      final c = catalog
          .byType(element)
          .firstWhere(
            (c) =>
                c.spriteData != null &&
                (c.mutationFamily ?? '').toLowerCase() == family,
          );
      final m = debugMemberFromCreature(c, statTier: 3);
      return CosmicPartyMember(
        instanceId: m.instanceId,
        baseId: m.baseId,
        displayName: m.displayName,
        element: m.element,
        family: m.family,
        level: 1,
        statSpeed: stat,
        statIntelligence: stat - 0.3,
        statStrength: stat - 0.4,
        statBeauty: stat - 0.2,
        slotIndex: 0,
        staminaBars: 3,
        staminaMax: family == 'wing' ? 4 : 3,
        spriteSheet: m.spriteSheet,
      );
    }

    final party = [
      member('Fire', 'mane', 2.9),
      member('Lightning', 'wing', 3.2),
      member('Water', 'pip', 2.7),
    ];
    final key = GlobalKey();

    Future<void> shoot(String name) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await boundary.toImage(pixelRatio: 2);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    }

    Future<void> settle(int frames) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    // The ladder.
    await tester.pumpWidget(
      Provider<CreatureCatalog>.value(
        value: catalog,
        child: MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: StadiumScreen(party: party),
          ),
        ),
      ),
    );
    await settle(30);
    await shoot('01_ladder');

    // A race, the phone turned.
    tester.view.physicalSize = size.flipped * 2;
    final cup = kRaceCups[0];
    final me = party[0];
    final racers = raceField(cup, 0, racerFromMember(me, null));
    final bodies = <RaceBody>[];
    var r = 0;
    for (final racer in racers) {
      bodies.add(
        RaceBody(racer.isPlayer ? me : rivalMember(catalog, cup.rivals[r++])!),
      );
    }
    await tester.runAsync(() async {
      for (final b in bodies) {
        await b.load(images);
      }
    });
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: RaceScreen(
            cup: cup,
            race: 0,
            racers: racers,
            bodies: bodies,
            onFinished: (finish) async =>
                TrialsPayout(gold: finish.place == 1 ? 1 : 0),
          ),
        ),
      ),
    );
    Future<void> run(double seconds) async {
      for (var f = 0; f < seconds * 10; f++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await run(1.3);
    await shoot('02_lineup');
    await run(5.2);
    await tester.tap(find.text('BOOST'));
    await run(1.0);
    await shoot('03_running');
    await run(14);
    await shoot('04_midrace');
    await run(70);
    await settle(4);
    await shoot('05_results');
  });
}
