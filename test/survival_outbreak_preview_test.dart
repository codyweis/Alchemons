@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:alchemons/games/cosmic/cosmic_enemy_vfx.dart';
import 'package:alchemons/games/cosmic_survival/survival_outbreak.dart';
import 'package:alchemons/games/cosmic_survival/survival_outbreak_vfx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final outDir = Platform.environment['ENEMY_SHEET_OUT'];
  testWidgets('ten outbreak arena previews', (tester) async {
    for (final path in [
      'C:/Windows/Fonts/arial.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    ]) {
      final file = File(path);
      if (file.existsSync()) {
        await (FontLoader('Preview')..addFont(
              Future.value(ByteData.view(file.readAsBytesSync().buffer)),
            ))
            .load();
        break;
      }
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xFF06050E), BlendMode.src);
    const width = 1200;
    const height = 2000;
    void label(
      String text,
      Offset position,
      double width,
      Color color,
      double size,
    ) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontFamily: 'Preview', fontSize: size, color: color),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width);
      painter.paint(canvas, position);
    }

    for (final kind in SurvivalOutbreakKind.values) {
      SurvivalOutbreak? event;
      for (var seed = 0; seed < 1000; seed++) {
        final candidate = SurvivalOutbreak.forWave(
          20,
          Offset.zero,
          1140,
          random: Random(seed),
        )!;
        if (candidate.kind == kind) {
          event = candidate;
          break;
        }
      }
      expect(event, isNotNull);
      final chosen = event!;
      chosen.advance(9.4);
      final x = (kind.index % 2) * 600.0;
      final y = (kind.index ~/ 2) * 400.0;
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(x, y, 600, 400));
      label(chosen.name, Offset(x + 16, y + 12), 480, chosen.color, 18);
      label(
        chosen.instruction,
        Offset(x + 16, y + 40),
        560,
        Colors.white70,
        12,
      );
      canvas.save();
      canvas.translate(x + 365, y + 236);
      canvas.scale(0.235);
      drawSurvivalOutbreak(canvas, chosen, Offset.zero);
      canvas.drawCircle(Offset.zero, 25, Paint()..color = Colors.white54);
      for (final core in chosen.cores) {
        drawSurvivalEnemy(canvas: canvas, enemy: core, time: chosen.elapsed);
      }
      canvas.restore();
      // Full-size source inset shows the tendril detail at gameplay scale.
      canvas.save();
      canvas.translate(x + 100, y + 300);
      final core = chosen.cores.first;
      core.position = Offset.zero;
      drawSurvivalEnemy(canvas: canvas, enemy: core, time: chosen.elapsed);
      canvas.restore();
      canvas.drawLine(
        Offset(x, y + 399),
        Offset(x + 600, y + 399),
        Paint()..color = Colors.white12,
      );
      canvas.restore();
    }
    final picture = recorder.endRecording();
    await tester.runAsync(() async {
      final img = await picture.toImage(width, height);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory(outDir!).createSync(recursive: true);
      File(
        '$outDir/outbreak_roster.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      img.dispose();
    });
    picture.dispose();
  }, skip: outDir == null);
}
