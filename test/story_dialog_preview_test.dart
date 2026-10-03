import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/screens/story/story_intro_screen.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/story_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

// The opening's story intro and the shared story dialog, on a phone (and the
// dialog once in landscape), with real fonts:
//
//   STORY_OUT=/tmp/story flutter test test/story_dialog_preview_test.dart
//
// Crimson Text stands in as Georgia Italic. google_fonts still reports the
// real font missing from the assets once the test is over, so a preview run
// ends "failed" after every PNG has been written. Without STORY_OUT the test
// returns at once and passes.
void main() {
  testWidgets('story intro + dialog preview', (tester) async {
    final out = Platform.environment['STORY_OUT'];
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    GoogleFonts.config.allowRuntimeFetching = false;

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
      for (final f in ['CrimsonText_italic', 'CrimsonText_regular']) {
        await loadFont(
          f,
          '/System/Library/Fonts/Supplemental/Georgia Italic.ttf',
        );
      }
    });

    final key = GlobalKey();
    Future<void> shoot(String name) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> settle([int frames = 8]) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Widget app(Widget home) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      builder: (context, child) => RepaintBoundary(key: key, child: child!),
      home: home,
    );

    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // The intro: first page, then a few pages in after a stir.
    await tester.pumpWidget(app(const StoryIntroScreen()));
    await settle(12);
    await shoot('intro_page1');
    await tester.drag(find.byType(StoryIntroScreen), const Offset(160, -60));
    for (var i = 0; i < 3; i++) {
      await tester.tapAt(const Offset(195, 600));
      await settle(8);
    }
    await shoot('intro_page4');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));

    final dialogs = <(String, Future<void> Function(BuildContext))>[
      (
        'dialog_field_tutorial',
        (c) => showStoryDialog(
          c,
          icon: AppIcons.auto_awesome,
          primaryLabel: 'BEGIN',
          beats: const [
            StoryBeat(
              title: 'Ancient Portal',
              message: '',
              voice:
                  'This portal was created eons ago. Is this false '
                  'perception? Beauty obstructs reality.',
            ),
            StoryBeat(
              title: 'Alchemy is Power',
              message:
                  'Tap the wild Alchemon, then choose one of yours to fuse '
                  'with it.',
            ),
          ],
        ),
      ),
      (
        'dialog_vial_secured',
        (c) => showStoryDialog(
          c,
          kind: StoryDialogKind.success,
          primaryLabel: 'OPEN THE CHAMBER',
          beats: const [
            StoryBeat(
              title: 'Vial secured',
              message: 'Your starter vial is waiting in the Extraction Chamber.',
            ),
          ],
        ),
      ),
      (
        'dialog_memory_line',
        (c) => showStoryDialog(
          c,
          beats: const [
            StoryBeat(title: '', message: '', voice: 'Is this a memory?'),
          ],
        ),
      ),
      (
        'dialog_confirm',
        (c) => showStoryDialog(
          c,
          primaryLabel: 'I HAVE AN ACCOUNT',
          secondaryLabel: "I'M NEW",
          beats: const [
            StoryBeat(
              title: 'Welcome',
              message:
                  'Already have an Alchemons account? Sign in to bring your '
                  'cloud backup to this device, or start fresh.',
            ),
          ],
        ),
      ),
    ];

    for (final landscape in [false, true]) {
      tester.view.physicalSize = landscape
          ? const Size(844 * 3, 390 * 3)
          : const Size(390 * 3, 844 * 3);
      for (final (name, open) in dialogs) {
        if (landscape && name != 'dialog_field_tutorial') continue;
        await tester.pumpWidget(
          app(
            Builder(
              builder: (context) => Scaffold(
                backgroundColor: const Color(0xFF203040),
                body: Center(
                  child: TextButton(
                    onPressed: () => open(context),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await settle(6);
        await shoot(landscape ? '${name}_landscape' : name);
        if (name == 'dialog_field_tutorial' && !landscape) {
          await tester.tap(find.text('NEXT'));
          await settle(6);
          await shoot('${name}_page2');
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      }
    }
  });
}
