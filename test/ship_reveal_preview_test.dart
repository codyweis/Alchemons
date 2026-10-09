@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/ship_reveal_fx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// The ship's reveal on home, frame by frame, over a stand-in for home with
// the emblem where home puts it (right edge, under the header).
//
//   SHIP_REVEAL_OUT=/tmp/ship_reveal flutter test \
//     test/ship_reveal_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['SHIP_REVEAL_OUT'];

  testWidgets('ship reveal preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final progress = AnimationController(
      vsync: const TestVSync(),
      duration: ShipReveal.duration,
    );
    addTearDown(progress.dispose);
    const centre = Offset(338, 190);
    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF2A3B5C), Color(0xFF6B4E3D)],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: centre.dx - 40,
                top: centre.dy - 40,
                child: AnimatedBuilder(
                  animation: progress,
                  builder: (context, _) => Transform.scale(
                    scale: ShipReveal.emblemScale(progress.value),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF1B1F2A),
                      ),
                      child: const Icon(
                        Icons.rocket_launch,
                        color: Color(0xFF9FD8FF),
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: ShipRevealOverlay(
                  progress: progress,
                  centre: () => centre,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    for (final t in const [0.08, 0.2, 0.29, 0.33, 0.4, 0.5, 0.62, 0.8, 0.95]) {
      progress.value = t;
      await tester.pump();
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$out/reveal_${(t * 100).round().toString().padLeft(3, '0')}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
  });
}
