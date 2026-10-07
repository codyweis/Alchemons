@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/harvest_cinematic.dart';
import 'package:alchemons/widgets/fx/harvester_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The harvest overlay as it plays, a take and a break, with the page drawing
// its own specimen.
//
//   HARVEST_CINE_OUT=/tmp/harvest_cine.png flutter test \
//     test/harvest_cinematic_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['HARVEST_CINE_OUT'];

  testWidgets('harvest cinematic preview', (tester) async {
    if (out == null) return;
    tester.view.physicalSize = const Size(1248, 1972);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    late ui.Image png;
    await tester.runAsync(() async {
      final data = await rootBundle.load(
        'assets/images/creatures/rare/HOR01_firehorn.png',
      );
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      png = (await codec.getNextFrame()).image;
    });

    final shotKey = GlobalKey();
    final frames = <(String, ui.Image)>[];
    for (final (label, held, device) in [
      ('take', true, 'arcane'),
      ('break', false, 'volcanic'),
    ]) {
      late BuildContext host;
      await tester.pumpWidget(
        RepaintBoundary(
          key: shotKey,
          child: MaterialApp(
            key: ValueKey(label),
            debugShowCheckedModeBanner: false,
            home: Builder(
              builder: (context) {
                host = context;
                return const Scaffold(backgroundColor: Color(0xFF0B0A12));
              },
            ),
          ),
        ),
      );
      final done = showHarvestCinematic(
        context: host,
        targetSprite: SizedBox(
          width: 180,
          height: 180,
          child: RawImage(image: png),
        ),
        targetColor: const Color(0xFFFF6B3D),
        profile: HarvesterProfile.forBiome(device),
        task: () async => held,
      );
      var finished = false;
      done.then((_) => finished = true);
      var elapsed = 0;
      for (final at in [
        300,
        700,
        1200,
        1700,
        1900,
        2150,
        2400,
        2700,
        3000,
        3300,
        3600,
        3900,
      ]) {
        await tester.pump(Duration(milliseconds: at - elapsed));
        elapsed = at;
        // Let the take's read land.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        final boundary =
            shotKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final img = await tester.runAsync(
          () => boundary.toImage(pixelRatio: 1),
        );
        frames.add(('$label +${at}ms', img!));
        // ignore: avoid_print
        print(
          '$label $at finished=$finished '
          'routes=${find.byType(CustomPaint).evaluate().length}',
        );
      }
      for (var i = 0; i < 60 && !finished; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
      }
      // ignore: avoid_print
      print('$label closed $finished');
    }

    await tester.runAsync(() async {
      final w = 1248 / 2.625, h = 1972 / 2.625 * 0.5;
      const cols = 5;
      final rows = (frames.length / cols).ceil();
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      for (var i = 0; i < frames.length; i++) {
        final (_, img) = frames[i];
        final at = Offset((i % cols) * (w + 6), (i ~/ cols) * (h + 6));
        c.drawImageRect(
          img,
          Rect.fromLTWH(0, h * 0.5, w, h),
          Rect.fromLTWH(at.dx, at.dy, w, h),
          Paint(),
        );
      }
      final img = rec.endRecording().toImageSync(
        (cols * (w + 6)).round(),
        (rows * (h + 6)).round(),
      );
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
