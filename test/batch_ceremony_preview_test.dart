@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/services/cinematic_quality_service.dart';
import 'package:alchemons/services/egg_hatching_service.dart';
import 'package:alchemons/widgets/animations/hatching_cinematic.dart';
import 'package:alchemons/widgets/nursery/batch_extraction_ceremony.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// Extract-all next to a single extraction, at the same moments: the single
// ceremony full screen on top, the real BatchCeremonyGrid underneath.
//
//   BATCH_OUT=/tmp/batch.png BATCH_CELLS=6 BATCH_QUALITY=performance \
//     flutter test test/batch_ceremony_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['BATCH_OUT'];
  final cells = int.tryParse(Platform.environment['BATCH_CELLS'] ?? '') ?? 6;
  final quality = Platform.environment['BATCH_QUALITY'] == 'cinematic'
      ? CinematicQuality.cinematic
      : CinematicQuality.performance;
  final frameTimes =
      Platform.environment['BATCH_AT']?.split(',').map(int.parse).toList() ??
      [1400, 3400, 4600, 5600];

  const pairs = [
    ('fire', 'water', 'Fire', Color(0xFFFF8C42), 'horn'),
    ('earth', 'plant', 'Plant', Color(0xFF7FB069), 'wing'),
    ('air', 'lightning', 'Lightning', Color(0xFFFFE066), 'let'),
    ('ice', 'water', 'Ice', Color(0xFF9AD8F0), 'pip'),
    ('dark', 'spirit', 'Spirit', Color(0xFF9B7FD4), 'mane'),
    ('lava', 'mud', 'Lava', Color(0xFFE2582E), 'mask'),
    ('crystal', 'light', 'Crystal', Color(0xFF8FE3E0), 'kin'),
    ('blood', 'poison', 'Blood', Color(0xFFB0303A), 'horn'),
  ];

  Widget view(int i, CinematicQuality q) {
    final p = pairs[i % pairs.length];
    return HatchingCeremonyView(
      key: ValueKey(i),
      parentATypeId: p.$1,
      parentBTypeId: p.$2,
      resultTypeId: p.$3,
      paletteMain: p.$4,
      creatureSilhouette: const AssetImage(
        'assets/images/creatures/rare/HOR01_firehorn.png',
      ),
      mutationFamily: p.$5,
      quality: q,
      playSound: false,
      showSkip: false,
      onComplete: () {},
    );
  }

  // The real grid, with roughly the header and SKIP row it sits between.
  Widget grid(int n) => Column(
    children: [
      const SizedBox(height: 40),
      Expanded(
        child: BatchCeremonyGrid(
          ceremonies: [
            for (var i = 0; i < n; i++)
              HatchCeremonyParams(
                parentATypeId: pairs[i % pairs.length].$1,
                parentBTypeId: pairs[i % pairs.length].$2,
                resultTypeId: pairs[i % pairs.length].$3,
                paletteMain: pairs[i % pairs.length].$4,
                silhouette: const AssetImage(
                  'assets/images/creatures/rare/HOR01_firehorn.png',
                ),
                hintType: HatchHintType.normal,
                variantColor: null,
                pureElementTypeId: null,
                mutationFamily: pairs[i % pairs.length].$5,
              ),
          ],
          quality: quality,
          onCellFinished: (_) {},
        ),
      ),
      const SizedBox(height: 56),
    ],
  );

  Future<List<ui.Image>> capture(WidgetTester tester, Widget body) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Material(color: Colors.black, child: body),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump(const Duration(milliseconds: 1));
    }
    final frames = <ui.Image>[];
    var elapsed = 0;
    for (final at in frameTimes) {
      await tester.pump(Duration(milliseconds: at - elapsed));
      elapsed = at;
      final b =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      frames.add((await tester.runAsync(() => b.toImage(pixelRatio: double.tryParse(Platform.environment["BATCH_RATIO"] ?? "") ?? 0.7)))!);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 8));
    return frames;
  }

  testWidgets('batch vs single ceremony', (tester) async {
    if (out == null) return;
    tester.view.physicalSize = const Size(1248, 1972);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    final single = await capture(tester, view(0, CinematicQuality.cinematic));
    final batch = await capture(tester, grid(cells));

    await tester.runAsync(() async {
      final w = single.first.width.toDouble(),
          h = single.first.height.toDouble();
      final cols = frameTimes.length;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      for (var i = 0; i < cols; i++) {
        c.drawImage(single[i], Offset(i * (w + 6), 0), Paint());
        c.drawImage(batch[i], Offset(i * (w + 6), h + 6), Paint());
      }
      final img = rec.endRecording().toImageSync(
        (cols * (w + 6)).round(),
        (2 * (h + 6)).round(),
      );
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
