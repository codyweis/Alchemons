@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/animations/hatching_cinematic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// The extraction ceremony, frame by frame: the grain shell forming, held,
// unravelling, and the newborn gathering out of it in grains.
//
//   CEREMONY_OUT=/tmp/ceremony.png flutter test \
//     test/hatch_ceremony_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['CEREMONY_OUT'];

  testWidgets('hatch ceremony preview', (tester) async {
    if (out == null) return;
    tester.view.physicalSize = const Size(1248, 1972);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: HatchingCeremonyView(
            parentATypeId: 'fire',
            parentBTypeId: 'water',
            resultTypeId: 'Fire',
            paletteMain: const Color(0xFFFF8C42),
            creatureSilhouette: const AssetImage(
              'assets/images/creatures/rare/HOR01_firehorn.png',
            ),
            mutationFamily: 'horn',
            playSound: false,
            showSkip: false,
            onComplete: () {},
          ),
        ),
      ),
    );
    // Let the silhouette decode and be read.
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump(const Duration(milliseconds: 1));
    }
    final frames = <ui.Image>[];
    var elapsed = 0;
    for (final at in [
      400,
      1400,
      2600,
      4200,
      5000,
      5250,
      5450,
      5650,
      5800,
      5950,
    ]) {
      await tester.pump(Duration(milliseconds: at - elapsed));
      elapsed = at;
      final b =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      frames.add((await tester.runAsync(() => b.toImage(pixelRatio: 0.6)))!);
    }
    await tester.runAsync(() async {
      final w = frames.first.width.toDouble(),
          h = frames.first.height.toDouble();
      const cols = 5;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      for (var i = 0; i < frames.length; i++) {
        c.drawImage(
          frames[i],
          Offset((i % cols) * (w + 4), (i ~/ cols) * (h + 4)),
          Paint(),
        );
      }
      final img = rec.endRecording().toImageSync(
        (cols * (w + 4)).round(),
        ((frames.length / cols).ceil() * (h + 4)).round(),
      );
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    await tester.pump(const Duration(seconds: 2));
  });
}
