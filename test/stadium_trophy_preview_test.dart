@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/stadium_trophy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The stadium's cup in every metal and fill, large and small, and loosening
// into its ring.
//
//   TROPHY_OUT=/tmp/trophy flutter test \
//     test/stadium_trophy_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['TROPHY_OUT'];

  Future<void> save(
    String name,
    Size size,
    void Function(Canvas c) paint,
  ) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.scale(2);
    c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF09090B));
    paint(c);
    final img = await rec.endRecording().toImage(
      (size.width * 2).round(),
      (size.height * 2).round(),
    );
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  }

  test('trophy sheet', () async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    const metals = TrophyMetal.values;
    const fills = [0.0, 1 / 3, 2 / 3, 1.0];
    await save('01_sheet', const Size(560, 640), (c) {
      for (var m = 0; m < metals.length; m++) {
        for (var f = 0; f < fills.length; f++) {
          paintStadiumTrophy(
            c,
            Offset(80 + f * 130.0, 90 + m * 150.0),
            88,
            TrophyLook(metals[m], fill: fills[f]),
            2.0 + f,
          );
        }
      }
    });
    await save('02_large', const Size(560, 300), (c) {
      paintStadiumTrophy(
        c,
        const Offset(140, 170),
        170,
        const TrophyLook(TrophyMetal.gold, fill: 2 / 3),
        3,
      );
      // Mid-glint.
      paintStadiumTrophy(
        c,
        const Offset(420, 170),
        170,
        const TrophyLook(TrophyMetal.copper, fill: 1),
        6.5 * 3 + .75,
      );
    });
    await save('03_loosen', const Size(900, 260), (c) {
      const loose = [0.0, 0.25, 0.5, 0.75, 1.0];
      for (var i = 0; i < loose.length; i++) {
        final at = Offset(90 + i * 180.0, 140);
        paintStadiumTrophy(
          c,
          at,
          130,
          const TrophyLook(TrophyMetal.copper, fill: 1 / 3),
          4,
          ring: TrophyRing(centre: at, radius: 70, loose: loose[i]),
        );
      }
    });
    // Every cup, at a third, two thirds and full.
    await save('04_cups', const Size(1080, 560), (c) {
      const metals = [
        TrophyMetal.copper,
        TrophyMetal.silver,
        TrophyMetal.gold,
        TrophyMetal.ruby,
        TrophyMetal.sapphire,
        TrophyMetal.emerald,
      ];
      for (var i = 0; i < metals.length; i++) {
        final x = 90 + i * 180.0;
        paintStadiumTrophy(
          c,
          Offset(x, 170),
          150,
          TrophyLook(metals[i], fill: const [1 / 3, 2 / 3, 1.0][i % 3]),
          2.3 + i,
        );
        paintStadiumTrophy(
          c,
          Offset(x, 440),
          90,
          TrophyLook(metals[i], fill: const [1.0, 1 / 3, 2 / 3][i % 3]),
          4.1 + i,
        );
      }
    });
  });
}
