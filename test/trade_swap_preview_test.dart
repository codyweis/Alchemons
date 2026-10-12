@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/trade_swap.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The trade's swap, frame by frame, with real sprites where the trade table
// stands them — theirs above, the player's below — plus what a frame costs.
//
//   TRADE_SWAP_OUT=/tmp/swap.png flutter test \
//     test/trade_swap_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['TRADE_SWAP_OUT'];

  testWidgets('trade swap preview', (tester) async {
    if (out == null) return;
    const ratio = 2.6;
    const box = 150.0;
    const spriteSize = 150.0;

    late (ui.Image, SpecimenGrains) mine, theirs;
    await tester.runAsync(() async {
      Future<(ui.Image, SpecimenGrains)> read(
        String name,
        String rarity,
      ) async {
        final data = await rootBundle.load(
          'assets/images/creatures/$rarity/${name}_spritesheet.png',
        );
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final sheet = (await codec.getNextFrame()).image;
        final frame = sheet.height.toDouble();
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        const px = box * ratio;
        const s = spriteSize * ratio;
        c.drawImageRect(
          sheet,
          Rect.fromLTWH(0, 0, frame, frame),
          Rect.fromCenter(
            center: const Offset(px / 2, px / 2),
            width: s,
            height: s,
          ),
          Paint()..filterQuality = FilterQuality.medium,
        );
        final img = rec.endRecording().toImageSync(px.round(), px.round());
        final bytes = await img.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        return (
          img,
          SpecimenGrains.fromRgba(
            bytes!.buffer.asUint8List(),
            img.width,
            img.height,
            pixelRatio: ratio,
            maxGrains: 2200,
            tones: 16,
          ),
        );
      }

      mine = await read('HOR01_firehorn', 'rare');
      theirs = await read('WNG03_earthwing', 'legendary');
    });

    const stage = Size(390, 560);
    const posMine = Offset(195, 440);
    const posTheirs = Offset(195, 120);
    const center = Offset(195, 280);
    final swap = TradeSwap(
      a: mine.$2,
      b: theirs.$2,
      accentA: BreedConstants.getTypeColor('Fire'),
      accentB: BreedConstants.getTypeColor('Earth'),
    );
    final sigil = TradeSigil();

    void sprite(Canvas c, ui.Image img, Offset at, double opacity) {
      if (opacity <= 0) return;
      c.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromCenter(center: at, width: box, height: box),
        Paint()
          ..filterQuality = FilterQuality.medium
          ..color = Color.fromRGBO(0, 0, 0, opacity),
      );
    }

    ui.Image shoot(double t) {
      const scale = 1.0;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawRect(Offset.zero & stage, Paint()..color = const Color(0xFF09090B));
      final light = TradeSwap.light(t);
      paintLightPool(
        c,
        posMine + const Offset(0, 60),
        110,
        const Color(0xFFB89656),
        0.5 + light,
      );
      paintLightPool(
        c,
        posTheirs + const Offset(0, 60),
        110,
        const Color(0xFFB89656),
        0.5 + light,
      );
      paintLightPool(
        c,
        center,
        120,
        const Color(0xFFE4C16A),
        light * 0.6,
        squash: 1,
      );
      sigil.paint(
        c,
        center,
        64,
        lower: 1,
        upper: 1,
        scatter: (t / 0.5).clamp(0.0, 1.0) * (t < 0.9 ? 1 : 0),
        opacity: t < 0.5 ? 1 : 0,
      );
      // Before: theirs above, the player's below; after, the other way.
      final leave = TradeSwap.leavingOpacity(t);
      final arrive = TradeSwap.arrivedOpacity(t);
      sprite(c, mine.$1, posMine, leave);
      sprite(c, theirs.$1, posTheirs, leave);
      swap.paint(c, t, posA: posMine, posB: posTheirs);
      sprite(c, mine.$1, posTheirs, arrive);
      sprite(c, theirs.$1, posMine, arrive);
      return rec.endRecording().toImageSync(
        (stage.width * scale).round(),
        (stage.height * scale).round(),
      );
    }

    const times = [
      0.0,
      0.08,
      0.16,
      0.26,
      0.36,
      0.46,
      0.56,
      0.66,
      0.76,
      0.86,
      0.92,
      0.97,
    ];
    final frames = [for (final t in times) shoot(t)];

    // Cost of one frame, recorded.
    final sw = Stopwatch()..start();
    const n = 200;
    for (var i = 0; i < n; i++) {
      final rec = ui.PictureRecorder();
      swap.paint(Canvas(rec), i / n, posA: posMine, posB: posTheirs);
      rec.endRecording().dispose();
    }
    // ignore: avoid_print
    print(
      'grains ${mine.$2.length} + ${theirs.$2.length}; '
      '${(sw.elapsedMicroseconds / n).toStringAsFixed(0)} µs a frame',
    );

    const cols = 6;
    final rows = (frames.length / cols).ceil();
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    for (var i = 0; i < frames.length; i++) {
      c.drawImage(
        frames[i],
        Offset(
          (i % cols) * (stage.width + 6),
          (i ~/ cols) * (stage.height + 6),
        ),
        Paint(),
      );
    }
    final sheet = rec.endRecording().toImageSync(
      (cols * (stage.width + 6)).round(),
      (rows * (stage.height + 6)).round(),
    );
    await tester.runAsync(() async {
      final png = await sheet.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
