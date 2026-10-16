@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/animations/bloodborn_extraction.dart';
import 'package:alchemons/widgets/fx/bloodborn_vial.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// THE BLOODBORN EXTRACTION, start to handover: the blood shell, its melt,
// the three beats and the rise, as frames and extraction.mp4 (ffmpeg).
//
//   BLOOD_EXTRACT_OUT=/tmp/bx flutter test \
//     test/bloodborn_extraction_preview_test.dart --tags preview
//
// BLOOD_EXTRACT_SIZE=412x880 (portrait; try 880x412), BLOOD_EXTRACT_SPECIES=HOR03.
void main() {
  testWidgets(
    'bloodborn extraction preview',
    timeout: const Timeout(Duration(minutes: 10)),
    (tester) async {
      final env = Platform.environment;
      final out = env['BLOOD_EXTRACT_OUT'];
      if (out == null) return;
      final dir = Directory(out)..createSync(recursive: true);
      for (final f in dir.listSync()) {
        if (f is File && f.path.endsWith('.png')) f.deleteSync();
      }
      final dims = (env['BLOOD_EXTRACT_SIZE'] ?? '412x880')
          .split('x')
          .map(double.parse)
          .toList();
      tester.view.physicalSize = Size(dims[0], dims[1]);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final id = env['BLOOD_EXTRACT_SPECIES'] ?? 'HOR03';
      final species =
          ((jsonDecode(
                        File(
                          'assets/data/alchemons_creatures.json',
                        ).readAsStringSync(),
                      )
                      as Map<String, dynamic>)['creatures']
                  as List)
              .cast<Map<String, dynamic>>()
              .firstWhere((c) => c['id'] == id);
      final body = await tester.runAsync(
        () => BloodbornVialGrains.read(
          species['image'] as String,
          height: 300,
          maxGrains: 1800,
        ),
      );
      var done = false;
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: BloodbornExtractionView(
              payload: {'baseId': id, 'source': 'bloodborn'},
              mutationFamily: species['mutationFamily'] as String?,
              body: body,
              showSkip: false,
              onComplete: () => done = true,
            ),
          ),
        ),
      );
      var frame = 0;
      for (var i = 0; i < 20 * 15 && !done; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (i.isOdd) continue;
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          File(
            '$out/f_${(frame++).toString().padLeft(4, '0')}.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }
      expect(done, isTrue);
      await tester.runAsync(() async {
        try {
          await Process.run('ffmpeg', [
            '-y',
            '-framerate',
            '10',
            '-i',
            '$out/f_%04d.png',
            '-pix_fmt',
            'yuv420p',
            '-vf',
            'scale=trunc(iw/2)*2:trunc(ih/2)*2',
            '$out/extraction.mp4',
          ]);
        } catch (_) {}
      });
    },
  );
}
