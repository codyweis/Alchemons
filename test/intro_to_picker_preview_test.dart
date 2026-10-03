import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/screens/faction_picker.dart';
import 'package:alchemons/screens/story/story_intro_screen.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// The opening's last page gathering into a knot, and the faction picker's
// realm bursting out of it:
//
//   INTRO_PICKER_OUT=/tmp/ip flutter test test/intro_to_picker_preview_test.dart
//
// (Like story_dialog_preview_test, a preview run ends "failed" on
// google_fonts' missing-asset report after the PNGs are written.)
void main() {
  testWidgets('opens the picker on the knot', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final out = Platform.environment['INTRO_PICKER_OUT'];
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    GoogleFonts.config.allowRuntimeFetching = false;

    await tester.runAsync(() async {
      final file = File('/System/Library/Fonts/Supplemental/Andale Mono.ttf');
      if (file.existsSync()) {
        await (FontLoader('monospace')..addFont(
              Future.value(ByteData.view(file.readAsBytesSync().buffer)),
            ))
            .load();
      }
    });

    final key = GlobalKey();
    await tester.pumpWidget(
      Provider<FactionTheme>.value(
        value: FactionTheme.scorchForge(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) => RepaintBoundary(key: key, child: child!),
          home: const StoryIntroScreen(),
        ),
      ),
    );

    Future<void> run(double seconds) async {
      for (var i = 0; i < (seconds / 0.05).round(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 3)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> shoot(String name) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await run(0.6);
    await tester.tap(find.text('SKIP'));
    await run(0.45);
    await shoot('1_gathering');
    await run(0.7);
    await shoot('2_knot');
    expect(find.byType(FactionPickerDialog), findsOneWidget);
    await run(0.35);
    await shoot('3_picker_bursting');
    await run(0.6);
    await shoot('4_realm_forming');
    await run(0.8);
    await shoot('5_chrome_in');
    await run(1.2);
    await shoot('6_settled');
  });
}
