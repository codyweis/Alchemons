@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/black_market_button.dart';
import 'package:alchemons/widgets/home_emblems.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The way into the black market (BlackMarketPassage), frame by frame, at
// phone size.
//
//   PASSAGE_OUT=/tmp/market flutter test \
//     test/black_market_passage_preview_test.dart --tags preview
//
// PASSAGE_PAGE=1_buy.png (from black_market_preview_test) lays the market
// under the landing frames; without it, a flat stand-in.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Platform.environment['PASSAGE_OUT'];
  final pagePath = Platform.environment['PASSAGE_PAGE'];

  test('black market passage', () async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    const screen = Size(390, 844);
    // The ball's place in the shop header.
    const box = Rect.fromLTWH(318, 96, 54, 54);
    ui.Image? dest;
    if (pagePath != null && File(pagePath).existsSync()) {
      final codec = await ui.instantiateImageCodec(
        File(pagePath).readAsBytesSync(),
      );
      dest = (await codec.getNextFrame()).image;
    }
    const frames = [
      (0.0, 0.0, false),
      (0.2, 0.0, false),
      (0.4, 0.0, false),
      (0.6, 0.0, false),
      (0.8, 0.0, false),
      (1.0, 0.0, false),
      (1.0, 0.15, false),
      (1.0, 0.3, false),
      (1.0, 0.5, false),
      (1.0, 0.7, false),
      (1.0, 0.9, false),
      (0.4, 0.0, true),
    ];
    const scene = BlackMarketPassage();
    const cols = 6;
    final rows = (frames.length / cols).ceil();
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    for (final (i, (open, land, closing)) in frames.indexed) {
      canvas.save();
      canvas.translate((i % cols) * screen.width, (i ~/ cols) * screen.height);
      canvas.clipRect(Offset.zero & screen);
      // A stand-in for the shop: its parchment-dark ground.
      canvas.drawRect(
        Offset.zero & screen,
        Paint()..color = const Color(0xFF2A2620),
      );
      final stage = EmblemStage(
        box: box,
        screen: screen,
        time: 4 + i * 0.08,
        open: open,
        land: land,
        closing: closing,
      );
      scene.paint(canvas, stage, back: true, front: false);
      final shown = scene.pageShown(land);
      if (shown > 0.01) {
        final p = Paint()..color = Color.fromRGBO(255, 255, 255, shown);
        if (dest != null) {
          canvas.drawImageRect(
            dest,
            Offset.zero & Size(dest.width.toDouble(), dest.height.toDouble()),
            Offset.zero & screen,
            p,
          );
        } else {
          canvas.drawRect(
            Offset.zero & screen,
            Paint()..color = const Color(0xFF3A2A18).withValues(alpha: shown),
          );
        }
      }
      scene.paint(canvas, stage, back: false, front: true);
      final tp = TextPainter(
        text: TextSpan(
          text:
              '${closing ? 'back ' : ''}open ${open.toStringAsFixed(2)}'
              '  land ${land.toStringAsFixed(2)}',
          style: const TextStyle(color: Color(0xFFFF66CC), fontSize: 14),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, const Offset(8, 8));
      canvas.restore();
    }
    final image = await rec.endRecording().toImage(
      (screen.width * cols).round(),
      (screen.height * rows).round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/passage.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
