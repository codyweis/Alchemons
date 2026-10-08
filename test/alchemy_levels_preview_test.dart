@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/screens/heart_puzzle/altar_levels_screen.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ALCHEMY's level select partway through (LEVELS_SOLVED levels won, mixed
// stars): as it opens, after it has glided down to the next level, and at
// the foot of the page.
//
//   LEVELS_OUT=/tmp/levels flutter test \
//     test/alchemy_levels_preview_test.dart --tags preview
//
// LEVELS_SIZE=412x900 picks the screen (logical px).
void main() {
  final out = Platform.environment['LEVELS_OUT'];

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

  testWidgets('alchemy levels preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final size = (Platform.environment['LEVELS_SIZE'] ?? '412x900')
        .split('x')
        .map(double.parse)
        .toList();
    tester.view.physicalSize = Size(size[0] * 3, size[1] * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final solved = int.parse(Platform.environment['LEVELS_SOLVED'] ?? '24');
    const pattern = [3, 3, 2, 3, 1, 2, 3, 3, 2, 3, 1, 3, 2];
    SharedPreferences.setMockInitialValues({
      'altars.stars.v1': jsonEncode({
        for (var n = 1; n <= solved; n++) '$n': pattern[(n - 1) % pattern.length],
      }),
    });
    final db = AlchemonsDatabase(NativeDatabase.memory());
    final key = GlobalKey();
    Future<void> shoot(String name) async {
      await tester.runAsync(() async {
        final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await b.toImage(pixelRatio: 2);
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
    await run(.5);
    await shoot('p1_open');
    await run(2.2);
    await shoot('p2_next');
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await run(.8);
    await shoot('p3_foot');

    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.runAsync(() => db.close());
  });
}
