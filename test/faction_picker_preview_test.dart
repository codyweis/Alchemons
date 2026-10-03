@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/screens/faction_picker.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The faction picker on each page.
//
//   FACTION_OUT=/tmp/faction flutter test \
//     test/faction_picker_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['FACTION_OUT'];

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

  Future<void> shoot(WidgetTester tester, GlobalKey key, String name) async {
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1248 / 412 / 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> settle(WidgetTester tester, int frames) async {
    for (var i = 0; i < frames; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 33));
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets('faction picker preview (${brightness.name})', (tester) async {
      if (out == null) return;
      final tag = brightness == Brightness.light ? 'light_' : '';
      Directory(out).createSync(recursive: true);
      // The headings are Google Fonts, fetched at run time as in the app; the
      // test binding's stand-in network refuses them.
      HttpOverrides.global = null;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => Directory.systemTemp.createTempSync('fonts').path,
      );
      // The background listens to the accelerometer; there is none here.
      final messenger = tester.binding.defaultBinaryMessenger;
      for (final channel in const [
        'dev.fluttercommunity.plus/sensors/method',
        'dev.fluttercommunity.plus/sensors/accelerometer',
      ]) {
        messenger.setMockMethodCallHandler(MethodChannel(channel), (_) async {
          return null;
        });
      }
      tester.view.physicalSize = const Size(1248, 2600);
      tester.view.devicePixelRatio = 1248 / 412;

      late AlchemonsDatabase db;
      await tester.runAsync(() async {
        db = AlchemonsDatabase(NativeDatabase.memory());
      });

      Widget host(GlobalKey key, Widget home) => MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          Provider<FactionTheme>.value(
            value: factionThemeFor(null, brightness: brightness),
          ),
          ChangeNotifierProvider<FactionService>(
            create: (_) => FactionService(db),
          ),
          ChangeNotifierProvider<ThemeNotifier>(
            create: (_) => ThemeNotifier(db),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: brightness == Brightness.light
              ? ThemeData.light()
              : ThemeData.dark(),
          builder: (context, child) => RepaintBoundary(key: key, child: child),
          home: home,
        ),
      );

      // Picker, page by page.
      final key = GlobalKey();
      await tester.pumpWidget(host(key, const FactionPickerDialog()));
      // Long enough for the headings' font to arrive.
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 33));
      }
      for (var i = 0; i < 4; i++) {
        await shoot(tester, key, '${tag}picker_$i');
        await tester.drag(find.byType(PageView), const Offset(-400, 0));
        // Half way through the grains' flight, then landed.
        await settle(tester, 22);
        if (i < 3) {
          await shoot(tester, key, '${tag}picker_${i}_to_${i + 1}');
        }
        await settle(tester, 60);
      }

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
      await tester.runAsync(db.close);
    });
  }
}
