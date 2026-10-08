@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/heart_puzzle/heart_puzzle_levels.dart';
import 'package:alchemons/screens/heart_puzzle/altar_realm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// ALCHEMY's level select stands each chapter on a still of its realm (the
// field the chapter is played in, at its hour). The stills are baked here,
// from the real fields, and shipped as images — so the page never builds a
// field to show one.
//
//   STILLS_OUT=/tmp/stills flutter test \
//     test/alchemy_realm_stills_bake_test.dart --tags preview
//   for f in /tmp/stills/*.png; do sips -s format jpeg -s formatOptions 82 \
//     "$f" --out "assets/images/ui/alchemy_realm_$(basename "${f%.png}").jpg"; done
//
// STILLS_SIZE=412x340 picks the field's size (logical px).
void main() {
  final out = Platform.environment['STILLS_OUT'];

  testWidgets('bake the chapter realm stills', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final size = (Platform.environment['STILLS_SIZE'] ?? '412x340')
        .split('x')
        .map(double.parse)
        .toList();
    tester.view.physicalSize = Size(size[0] * 2, size[1] * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    for (final c in kAltarChapters) {
      final r = altarRealmFor(c);
      final key = GlobalKey();
      var ready = false;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: key,
            // Raw: the page darkens it as it needs.
            child: AltarRealmView(
              key: ValueKey(c.name),
              realm: AltarRealm(r.scene, r.hour, dim: 0, drift: 0),
              onReady: () => ready = true,
            ),
          ),
        ),
      );
      for (var i = 0; i < 400 && !ready; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 33));
      }
      // Faded up and settled.
      for (var i = 0; i < 60; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 4)),
        );
        await tester.pump(const Duration(milliseconds: 33));
      }
      await tester.runAsync(() async {
        final b =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await b.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final name = c.name.toLowerCase().replaceAll(' ', '_');
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(ready, isTrue, reason: '${c.name} never drew');
    }
    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  });
}
