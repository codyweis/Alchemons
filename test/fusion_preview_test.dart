@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fusion_harness.dart';

// The fusion tab on a phone: empty with a pair to repeat, one in, a pair
// ready, a pair it refuses (two families; one resting), chambers full, a big
// wing, the light theme, and the merge on the live chamber.
//
//   FUSION_OUT=/tmp/fusion flutter test \
//     test/fusion_preview_test.dart --tags preview
/// The Galaxy Fold opened, as the app lays out on it.
const _fold = Size(476, 680);

void main() {
  final out = Platform.environment['FUSION_OUT'];

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

  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      final boundary =
          FusionHarness.shotKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  final cases = <(String, Future<FusionHarness> Function(WidgetTester))>[
    ('0_empty', (t) => FusionHarness.pump(t, lastPair: ('fh', 'wh'))),
    ('1_one', (t) => FusionHarness.pump(t, p1: 'fh')),
    ('2_pair', (t) => FusionHarness.pump(t, p1: 'fh', p2: 'wh')),
    ('3_two_families', (t) => FusionHarness.pump(t, p1: 'fh', p2: 'wl')),
    ('4_resting', (t) => FusionHarness.pump(t, p1: 'tired', p2: 'wh')),
    ('5_full', (t) => FusionHarness.pump(t, p1: 'fh', p2: 'wh', busy: 4)),
    (
      '6_all_full',
      (t) =>
          FusionHarness.pump(t, p1: 'fh', p2: 'wh', busy: 4, storageFull: true),
    ),
    (
      '7_wing',
      (t) => FusionHarness.pump(t, p1: 'ww', p2: 'wl', crossSpecies: true),
    ),
    (
      '7b_let_horn',
      (t) => FusionHarness.pump(t, p1: 'wl', p2: 'fh', crossSpecies: true),
    ),
    (
      '7c_mystic',
      (t) => FusionHarness.pump(t, p1: 'my', p2: 'ww', crossSpecies: true),
    ),
    (
      '8_light',
      (t) => FusionHarness.pump(
        t,
        p1: 'fh',
        p2: 'wh',
        brightness: Brightness.light,
      ),
    ),
    // The Fold, open: wider and squatter.
    (
      'f1_fold_pair',
      (t) => FusionHarness.pump(t, p1: 'fh', p2: 'wh', view: _fold),
    ),
    (
      'f2_fold_let_horn',
      (t) => FusionHarness.pump(
        t,
        p1: 'wl',
        p2: 'fh',
        crossSpecies: true,
        view: _fold,
      ),
    ),
    (
      'f3_fold_mystic',
      (t) => FusionHarness.pump(
        t,
        p1: 'my',
        p2: 'ww',
        crossSpecies: true,
        view: _fold,
      ),
    ),
    (
      '8b_light_empty',
      (t) => FusionHarness.pump(t, brightness: Brightness.light),
    ),
  ];

  // One test for all of them: the knot's portraits are cached across the
  // run, and a decode finished under one test's fake clock never wakes the
  // next test that waits on it.
  testWidgets('fusion preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    for (final (name, pump) in cases) {
      final h = await pump(tester);
      // The knot's portraits decode off the fake clock.
      await h.settle(30);
      await shoot(tester, name);
      await h.dispose();
    }

    // The merge, on the live chamber.
    final h = await FusionHarness.pump(tester, p1: 'fh', p2: 'wh');
    await h.settle(30);
    await tester.tap(find.text('FUSE'));
    // Reading the pair into grains, then the merge's own frames.
    var shot = 0;
    for (var i = 0; i < 80 && shot < 4; i++) {
      await h.settle(1);
      if (i >= 14 && i % 14 == 0) await shoot(tester, '9_merge_${shot++}');
    }
    await h.dispose();
  });
}
