@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/models/wild_fusion.dart';
import 'package:alchemons/widgets/animations/hatching_cinematic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// The extraction ceremony standing in its sand, frame by frame, with a finger
// drawn through it partway and the shell's burst rolling out at the end.
//
//   SAND_OUT=/tmp/sand.png flutter test \
//     test/hatch_sand_preview_test.dart --tags preview
//
// SAND_LOOK=prismatic|variant|transmuted|alchemized dresses the hatch;
// SAND_A / SAND_B pick the parents (default fire / water); SAND_AT=ms,ms
// picks the frames; SAND_RATIO scales them (default 0.8).
void main() {
  final out = Platform.environment['SAND_OUT'];
  final look = Platform.environment['SAND_LOOK'] ?? 'elements';
  final a = Platform.environment['SAND_A'] ?? 'fire';
  final b = Platform.environment['SAND_B'] ?? 'water';
  final frameTimes =
      Platform.environment['SAND_AT']?.split(',').map(int.parse).toList() ??
      [250, 900, 2400, 3300, 3700, 4600, 5300, 5500, 5800];
  final ratio =
      double.tryParse(Platform.environment['SAND_RATIO'] ?? '') ?? 0.8;

  testWidgets('hatch sand preview', (tester) async {
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
            parentATypeId: a,
            parentBTypeId: b,
            resultTypeId: a,
            paletteMain: const Color(0xFFFF8C42),
            creatureSilhouette: const AssetImage(
              'assets/images/creatures/rare/HOR01_firehorn.png',
            ),
            mutationFamily: 'horn',
            mutation: AlchemonMutation.byId(look),
            hintType: switch (look) {
              'prismatic' => HatchHintType.prismatic,
              'variant' => HatchHintType.variant,
              _ => HatchHintType.normal,
            },
            variantColor: look == 'variant' ? const Color(0xFF7CF5C8) : null,
            playSound: false,
            showSkip: false,
            sand: true,
            onComplete: () {},
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump(const Duration(milliseconds: 1));
    }

    // A finger drawn through the sand from 2.6 s, low across the screen and
    // up the left.
    const stirFrom = 2600, stirFor = 600;
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    TestGesture? finger;

    final frames = <ui.Image>[];
    var now = 0;
    for (final at in frameTimes) {
      while (now < at) {
        if (now >= stirFrom && now < stirFrom + stirFor) {
          final u = (now - stirFrom) / stirFor;
          final p = Offset(
            size.width * (0.12 + 0.7 * u),
            size.height * (0.82 - 0.25 * u * u),
          );
          if (finger == null) {
            finger = await tester.startGesture(p);
          } else {
            await finger.moveTo(p);
          }
        } else if (finger != null && now >= stirFrom + stirFor) {
          await finger.up();
          finger = null;
        }
        await tester.pump(const Duration(milliseconds: 16));
        now += 16;
      }
      final rb =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      frames.add((await tester.runAsync(() => rb.toImage(pixelRatio: ratio)))!);
    }
    await tester.runAsync(() async {
      final w = frames.first.width.toDouble(),
          h = frames.first.height.toDouble();
      final cols = frames.length < 3 ? frames.length : 3;
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
