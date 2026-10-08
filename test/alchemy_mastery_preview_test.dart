@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/heart_puzzle/heart_puzzle_levels.dart';
import 'package:alchemons/screens/heart_puzzle/alchemy_mastery.dart';
import 'package:alchemons/screens/heart_puzzle/altar_levels_screen.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ALCHEMY mastered: the level picker opened with every star won — the orb
// comes down, gathers itself, comes apart into gold, settles into 500,
// COLLECT is tapped and the gold is paid; then the page scrolled, the orb
// docked in the top bar.
//
//   MASTERY_OUT=/tmp/mastery flutter test \
//     test/alchemy_mastery_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['MASTERY_OUT'];

  Future<void> loadFont(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer))))
        .load();
  }

  setUpAll(() async {
    await loadFont('monospace', '/System/Library/Fonts/Supplemental/Andale Mono.ttf');
    await loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial Bold.ttf');
  });

  testWidgets('alchemy mastery preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = const Size(412 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'altars.stars.v1': jsonEncode({
        for (var n = 1; n <= kAltarLevels.length; n++) '$n': 3,
      }),
    });
    final db = AlchemonsDatabase(NativeDatabase.memory());
    late int before;
    await tester.runAsync(() async => before = await db.currencyDao.getGoldBalance());

    final key = GlobalKey();
    Future<void> shoot(String name) async {
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> run(double seconds) async {
      for (var i = 0; i < (seconds / .033).round(); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 4)));
        await tester.pump(const Duration(milliseconds: 33));
      }
    }

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          Provider<FactionTheme>.value(value: FactionTheme.scorchForge()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) => RepaintBoundary(key: key, child: child!),
          home: const AltarLevelsScreen(),
        ),
      ),
    );
    await run(.3);
    var last = 0.0;
    for (final (name, at) in [
      ('m1_descend', .7),
      ('m2_gather_itself', 2.3),
      ('m3_burst', 3.25),
      ('m4_gold_out', 3.8),
      ('m5_gathering', 4.5),
      ('m6_settled', 5.6),
    ]) {
      await run(at - last);
      last = at;
      await shoot(name);
    }
    final m = tester.state<AlchemyMasteryState>(find.byType(AlchemyMastery));
    expect(m.debugCollectable, isTrue);
    await tester.tap(find.text('COLLECT'));
    await run(.5);
    await shoot('m7_paid');
    await run(1.6);
    await shoot('m8_back');
    expect(find.byType(AlchemyMastery), findsNothing);
    late int after;
    await tester.runAsync(() async => after = await db.currencyDao.getGoldBalance());
    expect(after - before, AlchemyMastery.gold);

    // Scrolled: the orb docks in the bar.
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await run(.4);
    await shoot('d1_docked');

    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.runAsync(() => db.close());
  });
}
