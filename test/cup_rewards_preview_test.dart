@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/stadium/cup_rewards.dart';
import 'package:alchemons/screens/stadium/cup_won_dialog.dart';
import 'package:alchemons/widgets/fx/alchemy_effects/alchemy_effect_paint.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/utils/faction_util.dart';

// What a cup in the Trials gives: the Copper, Silver and Gold Spotlights
// round a few Alchemons, over a few moments; and the card that says so
// (SPOT_OUT with _card before .png).
//
//   SPOT_OUT=/tmp/spot.png flutter test test/cup_rewards_preview_test.dart \
//     --tags preview
void main() {
  final out = Platform.environment['SPOT_OUT'];

  test('the spotlights', () async {
    if (out == null) return;
    const sprites = ['HOR15_darkhorn', 'HOR09_icehorn', 'HOR01_firehorn'];
    const times = [0.6, 1.9, 3.1];
    const side = 120.0, cell = 230.0;
    final images = <ui.Image>[];
    for (final name in sprites) {
      final codec = await ui.instantiateImageCodec(
        File('assets/images/creatures/rare/$name.png').readAsBytesSync(),
        targetWidth: (side * 2).round(),
      );
      images.add((await codec.getNextFrame()).image);
    }
    final keys = AlchemyEffectPaint.trialsKeys;
    final cols = keys.length * times.length;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(
      Rect.fromLTWH(0, 0, cell * cols, cell * sprites.length),
      Paint()..color = const Color(0xFF0B0A10),
    );
    for (var row = 0; row < sprites.length; row++) {
      for (var k = 0; k < keys.length; k++) {
        for (var j = 0; j < times.length; j++) {
          final center = Offset(
            (k * times.length + j + 0.5) * cell,
            (row + 0.62) * cell,
          );
          const r = side / 2;
          AlchemyEffectPaint.paint(c, keys[k], center, r, times[j]);
          final img = images[row];
          c.drawImageRect(
            img,
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            Rect.fromCenter(center: center, width: side, height: side),
            Paint()..filterQuality = FilterQuality.medium,
          );
          AlchemyEffectPaint.paint(
            c,
            keys[k],
            center,
            r,
            times[j],
            front: true,
          );
        }
      }
    }
    final image = await rec.endRecording().toImage(
      (cell * cols).round(),
      (cell * sprites.length).round(),
    );
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File(out).writeAsBytesSync(png!.buffer.asUint8List());
  });

  testWidgets('the card', (tester) async {
    if (out == null) return;
    await tester.runAsync(() async {
      final file = File('/System/Library/Fonts/Supplemental/Arial.ttf');
      if (file.existsSync()) {
        await (FontLoader('Roboto')..addFont(
              Future.value(ByteData.view(file.readAsBytesSync().buffer)),
            ))
            .load();
      }
    });
    tester.view.physicalSize = const Size(475, 751) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final shot = GlobalKey();
    await tester.pumpWidget(
      Provider<FactionTheme>.value(
        value: factionThemeFor(null, brightness: Brightness.dark),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) =>
              RepaintBoundary(key: shot, child: child!),
          home: Builder(
            builder: (context) => Scaffold(
              backgroundColor: const Color(0xFF09090B),
              body: Center(
                child: TextButton(
                  onPressed: () => showCupsWon(context, [kCupRewards[2]]),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    await tester.runAsync(() async {
      final b =
          shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 1);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File(
        out.replaceFirst('.png', '_card.png'),
      ).writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
