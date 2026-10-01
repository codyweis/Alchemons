@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/breed_cinematic_fx.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The fusion cinematic as the chamber hands over to it, frame by frame, for
// each kind of reveal.
//
//   CINEMATIC_OUT=/tmp/cinematic.png flutter test \
//     test/fusion_cinematic_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['CINEMATIC_OUT'];

  testWidgets('fusion cinematic preview', (tester) async {
    if (out == null) return;
    // The phone's cover screen.
    tester.view.physicalSize = const Size(1248, 1972);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    const screen = Size(1248 / 2.625, 1972 / 2.625);
    const core = Offset(237.7, 372);
    const fire = Color(0xFFFF6B3D), water = Color(0xFF3FA9F5);

    // The two specimens read the way the chamber reads them.
    late List<SpecimenGrains> grains;
    await tester.runAsync(() async {
      Future<SpecimenGrains> read(String path, double box) async {
        final data = await rootBundle.load(path);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final sheet = (await codec.getNextFrame()).image;
        final f = sheet.height.toDouble();
        final px = (box * 1.12 * 2.6).round();
        final rec = ui.PictureRecorder();
        Canvas(rec).drawImageRect(
          sheet,
          Rect.fromLTWH(0, 0, f, f),
          Rect.fromCenter(
            center: Offset(px / 2, px / 2),
            width: box * 2.6,
            height: box * 2.6,
          ),
          Paint()..filterQuality = FilterQuality.medium,
        );
        final img = rec.endRecording().toImageSync(px, px);
        final bytes = await img.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        return SpecimenGrains.fromRgba(
          bytes!.buffer.asUint8List(),
          px,
          px,
          pixelRatio: 2.6,
        );
      }

      grains = [
        await read('assets/images/creatures/rare/HOR01_firehorn_spritesheet.png', 178),
        await read('assets/images/creatures/common/LET02_waterlet_spritesheet.png', 115),
      ];
    });

    final shotKey = GlobalKey();
    final frames = <(String, ui.Image)>[];
    final outcomes = <String, FusionRevealData>{
      'standard': FusionRevealData(
        kind: FusionRevealKind.standard,
        accent: Color.lerp(fire, water, 0.5)!,
      ),
      'pure fire': const FusionRevealData(
        kind: FusionRevealKind.pureElement,
        accent: fire,
        element: 'fire',
        caption: 'NEW FIRE LINEAGE',
        foundedNewLine: true,
      ),
      'pure both': const FusionRevealData(
        kind: FusionRevealKind.pureBoth,
        accent: Color(0xFFE8B45A),
        element: 'earth',
        caption: 'PURE LINE ESTABLISHED',
        foundedNewLine: true,
      ),
    };

    for (final entry in outcomes.entries) {
      late BuildContext host;
      await tester.pumpWidget(
        RepaintBoundary(
          key: shotKey,
          child: MaterialApp(
            key: ValueKey(entry.key),
            debugShowCheckedModeBanner: false,
            home: Builder(
              builder: (context) {
                host = context;
                // The chamber, roughly: a dark card with the orb at full
                // charge where the merge left it.
                return Scaffold(
                  backgroundColor: const Color(0xFF0B0A12),
                  body: Stack(
                    children: [
                      Positioned(
                        left: core.dx - 52,
                        top: core.dy - 52,
                        child: Container(
                          width: 104,
                          height: 104,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [fire, water]),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      final outcome = ValueNotifier<FusionRevealData?>(null);
      final done = showAlchemyFusionCinematic<bool>(
        context: host,
        leftSprite: const SizedBox(),
        rightSprite: const SizedBox(),
        drawSpecimens: false,
        leftColor: fire,
        rightColor: water,
        coreRect: Rect.fromCenter(center: core, width: 52, height: 52),
        outcome: outcome,
        grains: grains,
        minDuration: const Duration(milliseconds: 2800),
        task: () async {
          outcome.value = entry.value;
          return true;
        },
      );
      var elapsed = 0;
      for (final at in [0, 250, 450, 600, 800, 1000, 1250, 1500, 1750, 2050, 2400, 2800]) {
        await tester.pump(Duration(milliseconds: at - elapsed));
        elapsed = at;
        final boundary =
            shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
        frames.add(('${entry.key} +${at}ms', img!));
      }
      var finished = false;
      done.then((_) => finished = true);
      for (var i = 0; i < 100 && !finished; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // ignore: avoid_print
      print('${entry.key}: closed $finished');
    }

    await tester.runAsync(() async {
      final w = screen.width, h = screen.height * 0.62;
      const cols = 4;
      final rows = (frames.length / cols).ceil();
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      for (var i = 0; i < frames.length; i++) {
        final (label, img) = frames[i];
        final at = Offset((i % cols) * (w + 6), (i ~/ cols) * (h + 6));
        // The middle band of the screen, where the fusion plays.
        c.drawImageRect(
          img,
          Rect.fromLTWH(0, core.dy - h * 0.55, w, h),
          Rect.fromLTWH(at.dx, at.dy, w, h),
          Paint(),
        );
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(color: Color(0xFF8A8AA0), fontSize: 14),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c, at + const Offset(8, 4));
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
