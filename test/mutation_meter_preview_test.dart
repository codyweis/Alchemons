@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/wild_fusion.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/widgets/fx/mutation_moment.dart';
import 'package:alchemons/widgets/wilderness/mutation_meter.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The mutation meter on the wild scene, a notch pouring in, and a
// mutation's moment, as frames:
//
//   METER_OUT=/tmp/meter METER_BG=/path/to/scene.png flutter test \
//     test/mutation_meter_preview_test.dart --tags preview
//
// METER_BG is any landscape screenshot of a field (optional; black without).
void main() {
  final out = Platform.environment['METER_OUT'];
  final bg = Platform.environment['METER_BG'];

  testWidgets('mutation meter preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    tester.view.physicalSize = const Size(751, 475) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    late AlchemonsDatabase db;
    late ConstellationEffectsService effects;
    await tester.runAsync(() async {
      db = AlchemonsDatabase(NativeDatabase.memory());
      await db.constellationDao.unlockSkill(kMutationMeterSkillId, 0);
      await db.settingsDao.setMutationMeter(60);
      effects = ConstellationEffectsService(db);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    final key = GlobalKey();
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          ChangeNotifierProvider<ConstellationEffectsService>.value(
            value: effects,
          ),
        ],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            navigatorKey: nav,
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                children: [
                  if (bg != null)
                    Positioned.fill(
                      child: Image.file(File(bg), fit: BoxFit.cover),
                    ),
                  const Positioned.fill(child: MutationMeterHud()),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Future<void> wait(int ms) async {
      // The meter and the moment run on real time (a stopwatch).
      final end = DateTime.now().add(Duration(milliseconds: ms));
      while (DateTime.now().isBefore(end)) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 16)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    Future<void> shoot(String name) async {
      final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = (await tester.runAsync(() => b.toImage(pixelRatio: 1.5)))!;
      final bytes = (await tester.runAsync(
        () => img.toByteData(format: ui.ImageByteFormat.png),
      ))!;
      File('$out/$name.png').writeAsBytesSync(bytes.buffer.asUint8List());
    }

    await wait(1200);
    await shoot('a_meter_60');

    // A fusion that lands without mutating: one notch, from where it met.
    MutationMeterBus.instance.beginFusion();
    await tester.runAsync(() => db.settingsDao.setMutationMeter(61));
    await wait(200);
    MutationMeterBus.instance.fusionEnded(at: const Offset(380, 330));
    await wait(550);
    await shoot('b_notch_pouring');
    await wait(1400);
    await shoot('c_notch_in');

    // Full: the glass breathes.
    await tester.runAsync(
      () => db.settingsDao.setMutationMeter(kMutationMeterNotches),
    );
    await wait(1600);
    await shoot('d_full');

    // A mutation's moment.
    await tester.runAsync(() => db.settingsDao.setMutationMeter(70));
    await wait(1600);
    MutationMeterBus.instance.beginFusion();
    await tester.runAsync(() => db.settingsDao.setMutationMeter(0));
    final done = showMutationMoment(
      nav.currentContext!,
      at: const Offset(380, 330),
    );
    var last = 0;
    for (final at in [600, 1300, 2000, 2800, 3500, 4200, 5200]) {
      await wait(at - last);
      last = at;
      await shoot('e_moment_${at.toString().padLeft(4, '0')}');
    }
    // Tap past it.
    await tester.tapAt(const Offset(375, 240));
    await wait(1300);
    MutationMeterBus.instance.fusionEnded();
    await done;
    await wait(300);
    await shoot('f_after');

    await tester.runAsync(() async {
      effects.dispose();
      await db.close();
    });
    await tester.pumpWidget(const SizedBox());
  });
}
