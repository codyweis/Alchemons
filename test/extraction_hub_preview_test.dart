@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'extraction_hub_harness.dart';

// The harvest screen on a phone: the tutorial, a full chamber, one filling
// and just tapped, an empty one, a locked one, and a collect pouring out.
//
//   HUB_OUT=/tmp/hub flutter test \
//     test/extraction_hub_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['HUB_OUT'];

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
  });
  setUp(muteNotifications);

  testWidgets('extraction hub preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final h = await HubHarness.pump(tester, tutorialSeen: false);

    Future<void> shoot(String name) async {
      await tester.runAsync(() async {
        final boundary =
            h.shotKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await shoot('0_tutorial');
    await tester.tap(find.text('GOT IT'));
    await h.settle(40);
    // Full chambers come first.
    await shoot('1_ready');

    await h.select(0);
    await h.settle(30);
    await shoot('2_running');
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('bay-volcanic'))),
    );
    await h.settle(6);
    await shoot('3_tap');
    await h.select(1);
    await shoot('4_empty');
    await h.select(4);
    await shoot('5_locked');

    // The full one, collected: it pours up out of the neck.
    await h.select(3);
    await tester.tap(find.text('COLLECT').first);
    for (final (i, frames) in [(0, 6), (1, 6), (2, 8)]) {
      await h.settle(frames);
      await shoot('6_pour_$i');
    }
    await h.settle(40);
    await shoot('7_collected');

    await h.dispose();
    unmuteNotifications();
  });
}
