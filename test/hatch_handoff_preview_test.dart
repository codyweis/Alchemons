@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/animations/hatching_cinematic.dart';
import 'package:alchemons/widgets/fx/cultivation_sphere.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// The extraction's opening as it really runs: a cultivation sphere handed
// from the dialog into the ceremony, drawn to the middle, and unwound into
// the two parents' clusters as the shell's first motes come up out of them.
//
//   HANDOFF_OUT=/tmp/handoff.png flutter test \
//     test/hatch_handoff_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['HANDOFF_OUT'];

  testWidgets('hatch handoff preview', (tester) async {
    if (out == null) return;
    tester.view.physicalSize = const Size(1248, 1972);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    Map<String, dynamic> parent(String id, String image, String type) => {
      'baseId': id,
      'name': id,
      'types': [type],
      'rarity': 'Rare',
      'image': image,
    };
    final sphereKey = GlobalKey();
    final shot = GlobalKey();
    late BuildContext host;
    await tester.pumpWidget(
      RepaintBoundary(
        key: shot,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Builder(
            builder: (context) {
              host = context;
              return Scaffold(
                backgroundColor: const Color(0xFF0B0E13),
                body: Center(
                  child: SizedBox.square(
                    dimension: 245,
                    child: CultivationSphere(
                      key: sphereKey,
                      payload: {
                        'parentage': {
                          'parentA': parent(
                            'HOR01',
                            'creatures/rare/HOR01_firehorn.png',
                            'Fire',
                          ),
                          'parentB': parent(
                            'LET02',
                            'creatures/common/LET02_waterlet.png',
                            'Water',
                          ),
                        },
                      },
                      types: const ['Fire', 'Water'],
                      isReady: true,
                      grains: 1100,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }
    CultivationHandoff.stage(CultivationSphere.handoffFrom(sphereKey));
    playHatchingCinematicAlchemy(
      context: host,
      parentATypeId: 'fire',
      parentBTypeId: 'water',
      resultTypeId: 'Fire',
      paletteMain: const Color(0xFFFF8C42),
      creatureSilhouette: const AssetImage(
        'assets/images/creatures/rare/HOR01_firehorn.png',
      ),
      mutationFamily: 'horn',
    );
    final frames = <ui.Image>[];
    var elapsed = 0;
    for (final at in [300, 900, 1200, 1400, 1600, 1800, 2000, 2300, 2700, 3200]) {
      await tester.pump(Duration(milliseconds: at - elapsed));
      elapsed = at;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      final b =
          shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
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
    await tester.pump(const Duration(seconds: 8));
  });
}
