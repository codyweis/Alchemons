@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

// Renders real Survival waves (the actual spawner, pacing and caps) a few
// seconds in, so the shape of a horde front can be judged by eye.
// HORDE_WAVE_OUT=docs/horde_stress flutter test test/survival_horde_wave_preview_test.dart
void main() {
  final out = Platform.environment['HORDE_WAVE_OUT'];
  for (final wave in [6, 12, 21, 31]) {
    testWidgets('horde wave $wave preview', (tester) async {
      final game = CosmicSurvivalGame(
        party: [
          CosmicPartyMember(
            instanceId: 'p',
            baseId: 'MAN06',
            displayName: 'Lavamane',
            family: 'Mane',
            element: 'Lava',
            level: 10,
            slotIndex: 0,
            statSpeed: 4,
            statIntelligence: 4,
            statStrength: 4,
            statBeauty: 4,
            staminaBars: 3,
            staminaMax: 3,
          ),
        ],
        random: Random(7),
        onGameOver: () {},
      );
      game.onGameResize(Vector2(900, 1400));
      await game.onLoad();
      game.startGame();
      game.spawner.currentWave = wave - 1;
      game.spawner.resumeAfterIntermission();
      game.spawner.isBossWave = false;
      // Overhead map: every body relative to the orb, three moments in.
      const mapSize = 700.0;
      const worldSpan = 3000.0; // world units across the map
      final rec = ui.PictureRecorder();
      final canvas = ui.Canvas(rec);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, mapSize * 3, mapSize),
        ui.Paint()..color = const ui.Color(0xFF080D19),
      );
      var peak = 0;
      var frame = 0;
      for (final (panel, seconds) in [(0, 3), (1, 12), (2, 24)]) {
        for (; frame < 60 * seconds; frame++) {
          game.alchemicalMeter = 0;
          game.gamePaused = false;
          game.showingPowerUpSelection = false;
          game.update(1 / 60);
          peak = max(peak, game.enemies.where((e) => !e.isDead).length);
        }
        final origin = ui.Offset(panel * mapSize + mapSize / 2, mapSize / 2);
        const k = mapSize / worldSpan;
        final view = ui.Rect.fromCenter(
          center: origin,
          width: game.size.x * k,
          height: game.size.y * k,
        );
        canvas.drawRect(
          view,
          ui.Paint()
            ..style = ui.PaintingStyle.stroke
            ..color = const ui.Color(0x55FFFFFF),
        );
        canvas.drawCircle(
          origin,
          game.debugArenaRadius * k,
          ui.Paint()
            ..style = ui.PaintingStyle.stroke
            ..color = const ui.Color(0x889BE7FF),
        );
        canvas.drawCircle(
          origin,
          6,
          ui.Paint()..color = const ui.Color(0xFF7DD3FC),
        );
        for (final e in game.enemies) {
          if (e.isDead) continue;
          final d = e.position - game.orb.position;
          canvas.drawCircle(
            origin + d * k,
            e.radius * k * 2 + 1,
            ui.Paint()..color = elementColor(e.element),
          );
        }
        // ignore: avoid_print
        print(
          'wave $wave t=${seconds}s alive='
          '${game.enemies.where((e) => !e.isDead).length} '
          'spawned=${game.spawner.targetCountThisWave}',
        );
      }
      // ignore: avoid_print
      print(
        'wave $wave pattern=${game.spawner.currentPattern.name} '
        'target=${game.spawner.targetCountThisWave} peak=$peak',
      );
      final pic = rec.endRecording();
      if (out != null) {
        await tester.runAsync(() async {
          final img = await pic.toImage((mapSize * 3).toInt(), mapSize.toInt());
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File(
            '$out/wave_$wave.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
          img.dispose();
        });
      }
      pic.dispose();
      game.onRemove();
    });
  }
}
