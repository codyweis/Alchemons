import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/models/creature.dart';
import 'package:alchemons/screens/database_dialogs.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The database's tutorial and unknown-species dialogs on a phone, both
// themes, with real fonts:
//
//   DB_DIALOGS_OUT=/tmp/dbd flutter test test/database_dialogs_preview_test.dart
void main() {
  testWidgets('database dialogs preview', (tester) async {
    final out = Platform.environment['DB_DIALOGS_OUT'];
    if (out == null) return;
    Directory(out).createSync(recursive: true);

    Future<void> loadFont(String family, String path) async {
      final file = File(path);
      if (!file.existsSync()) return;
      await (FontLoader(family)..addFont(
            Future.value(ByteData.view(file.readAsBytesSync().buffer)),
          ))
          .load();
    }

    await tester.runAsync(() async {
      await loadFont(
        'monospace',
        '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
      );
      await loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial.ttf');
    });
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final species = Creature(
      id: 'MYS14',
      name: 'Wraithord',
      types: const ['Spirit'],
      rarity: 'Mystic',
      description: 'preview',
      image: 'test.png',
      mutationFamily: 'Mystic',
      spriteData: SpriteData(
        frameWidth: 512,
        frameHeight: 512,
        totalFrames: 4,
        frameDurationMs: 120,
        rows: 1,
        spriteSheetPath: 'creatures/mystic/MYS14_spiritmystic_spritesheet.png',
      ),
    );
    final light = FactionTheme(
      brightness: Brightness.light,
      primary: const Color(0xFF8A5A12),
      secondary: const Color(0xFF0E7490),
      accent: const Color(0xFFB7791F),
      accentSoft: const Color(0xFFD9B26A),
      surface: const Color(0xFFFFFBF4),
      surfaceAlt: const Color(0xFFF2EBDD),
      border: const Color(0xFF8A7961),
      text: const Color(0xFF201910),
      textMuted: const Color(0xFF665946),
      backgroundGradient: const [Color(0xFFF2EBDD), Color(0xFFFFFBF4)],
    );

    final key = GlobalKey();
    for (final (name, theme) in [
      ('dark', FactionTheme.scorchForge()),
      ('light', light),
    ]) {
      for (final (dialog, open) in <(String, Future<void> Function(BuildContext))>[
        ('tutorial', (c) => showDatabaseTutorial(c, theme)),
        ('unknown', (c) => showUnknownSpeciesDialog(c, theme, species)),
      ]) {
        await tester.pumpWidget(
          Provider<FactionTheme>.value(
            value: theme,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme.isDark ? ThemeData.dark() : ThemeData.light(),
              builder: (context, child) =>
                  RepaintBoundary(key: key, child: child!),
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => open(context),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        for (var i = 0; i < 6; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '$out/${name}_$dialog.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      }
    }
  });
}
