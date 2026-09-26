// NYTHRALOR'S SKY, ALONE — the black hole at phone proportions, at the
// porch's mood and the deep's, so it can be judged without a room over it.
// With `build/room_audit` present it writes DarkSky_<mood>.png.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/planet_dungeon/planet_dungeon_sky.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the dark sky loads and draws', (tester) async {
    await tester.runAsync(() async {
      final sky = DungeonSky();
      await sky.load('Dark');
      expect(sky.ready, isTrue);
      final out = Directory('build/room_audit');
      for (final mood in const [0.34, 0.12]) {
        final rec = ui.PictureRecorder();
        sky.paint(Canvas(rec), const Size(1000, 460), 12.0, mood: mood);
        final img = await rec.endRecording().toImage(1000, 460);
        if (!out.existsSync()) continue;
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File(
          'build/room_audit/DarkSky_$mood.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
      }
    });
  });
}
