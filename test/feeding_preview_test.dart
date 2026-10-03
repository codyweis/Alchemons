@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'enhance_harness.dart';

// The Enhance screen on a phone: the picker, the stage, two kin chosen and
// poured in, the orb tray and the soul tray.
//
//   FEED_OUT=/tmp/feed flutter test test/feeding_preview_test.dart \
//     --tags preview
void main() {
  final out = Platform.environment['FEED_OUT'];

  Future<void> loadFont(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer))))
        .load();
  }

  setUpAll(() async {
    await loadFont(
      'monospace',
      '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
    );
    await loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial.ttf');
    await loadFont(
      'packages/phosphoricons_flutter/PhosphorBold',
      '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev/'
          'phosphoricons_flutter-1.0.0/lib/fonts/Phosphor-Bold.ttf',
    );
  });

  testWidgets('enhance preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final h = await EnhanceHarness.pump(tester);

    Future<void> shoot(String name) async {
      await tester.runAsync(() async {
        final boundary =
            EnhanceHarness.shotKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await shoot('0_picker');
    await tester.enterText(find.byType(TextField), 'plant');
    await h.settle(15);
    await shoot('0b_search');

    // Straight onto the leveled Firehorn.
    await h.reopen(open: 'fh0');
    await shoot('1_stage');

    // The stage sprite is the first; kin cards follow in the tray.
    Future<void> tapSprite(int i) async {
      await tester.tap(
        find.byType(InstanceSprite).hitTestable().at(i),
        warnIfMissed: false,
      );
      await h.settle(20);
    }

    await tapSprite(1);
    await tapSprite(2);
    await shoot('2_kin_chosen');

    await tester.tap(find.textContaining('SACRIFICE'), warnIfMissed: false);
    for (final (frames, name) in [
      (6, '3_pour_a'),
      (12, '3_pour_b'),
      (10, '3_pour_c'),
      (14, '4_flash'),
      (12, '4_count'),
      (40, '5_after'),
    ]) {
      await h.settle(frames);
      await shoot(name);
    }

    await h.settle(30);
    await tester.tap(find.textContaining('ORBS'), warnIfMissed: false);
    await h.settle(20);
    await shoot('6_orbs');

    await tester.tap(find.textContaining('SOULS'), warnIfMissed: false);
    await h.settle(20);
    await tester.tap(find.text('STR').last, warnIfMissed: false);
    await h.settle(20);
    await shoot('7_souls');

    await h.dispose();
  });
}
