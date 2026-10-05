@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

// Renders a real Survival run as the player sees the arena: at the ship, at
// the rim, and with the whole arena in frame.
// ARENA_OUT=/tmp/arena flutter test test/survival_arena_preview_test.dart
void main() {
  final out = Platform.environment['ARENA_OUT'];
  testWidgets('survival arena preview', (tester) async {
    CosmicPartyMember member(
      int slot,
      String id,
      String name,
      String family,
      String element,
    ) => CosmicPartyMember(
      instanceId: 'p$slot',
      baseId: id,
      displayName: name,
      family: family,
      element: element,
      level: 10,
      slotIndex: slot,
      statSpeed: 4,
      statIntelligence: 4,
      statStrength: 4,
      statBeauty: 4,
      staminaBars: 3,
      staminaMax: 3,
    );
    final game = CosmicSurvivalGame(
      party: [
        member(0, 'MAN06', 'Lavamane', 'Mane', 'Lava'),
        member(1, 'WNG15', 'Darkwing', 'Wing', 'Dark'),
        member(2, 'PIP07', 'Lightningpip', 'Pip', 'Lightning'),
      ],
      random: Random(7),
      onGameOver: () {},
    );
    const w = 900.0, h = 1900.0;
    game.onGameResize(Vector2(w, h));
    await game.onLoad();
    game.startGame();
    game.spawner.currentWave = 11;
    game.spawner.resumeAfterIntermission();
    game.spawner.isBossWave = false;
    for (var f = 0; f < 60 * 14; f++) {
      game.alchemicalMeter = 0;
      game.gamePaused = false;
      game.showingPowerUpSelection = false;
      game.update(1 / 60);
    }

    // Enemy fire in view of the ship: a siege beam, a shockwave, shots.
    final at = game.ship.position;
    game.enemyHazards
      ..add(
        SurvivalEnemyHazard(
          kind: EnemyHazardKind.beam,
          origin: at + const Offset(-380, -420),
          angle: 0.35,
          element: 'Fire',
          damage: 0,
          life: 0.5,
          maxLife: 0.6,
          length: 900,
          width: 16,
        ),
      )
      ..add(
        SurvivalEnemyHazard(
          kind: EnemyHazardKind.shockwave,
          origin: at + const Offset(200, 500),
          angle: 0,
          element: 'Poison',
          damage: 0,
          life: 0.35,
          maxLife: 0.7,
          maxRadius: 340,
        ),
      );
    for (var i = 0; i < 8; i++) {
      final el = ['Water', 'Lightning', 'Dark', 'Fire'][i % 4];
      game.enemyProjectiles.add(
        SurvivalEnemyProjectile(
          position: at + Offset(-300 + i * 70.0, 160 + (i % 3) * 30.0),
          angle: -1.2 + i * 0.1,
          element: el,
          damage: 0,
          target: CosmicEnemyTarget.orb,
        ),
      );
      game.bossProjectiles.add(
        SurvivalBossProjectile(
          position: at + Offset(-260 + i * 60.0, -150),
          angle: 2.0,
          element: 'Blood',
          damage: 0,
        ),
      );
    }

    final shots = <(String, double, Offset)>[
      ('ship', 0.6, Offset.zero),
      ('rim', 0.6, const Offset(-1, 0)),
      ('whole', game.cameraZoomMin, Offset.zero),
    ];
    for (final (name, zoom, toward) in shots) {
      game.setCameraZoom(zoom);
      game.cameraPanOffset = toward == Offset.zero
          ? (name == 'whole'
                ? game.orb.position - game.ship.position
                : Offset.zero)
          : game.orb.position +
                toward * (game.debugArenaRadius - 120) -
                game.ship.position;
      final rec = ui.PictureRecorder();
      final canvas = ui.Canvas(rec);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, w, h),
        ui.Paint()..color = game.backgroundColor(),
      );
      game.render(canvas);
      final pic = rec.endRecording();
      if (out != null) {
        await tester.runAsync(() async {
          final img = await pic.toImage(w.toInt(), h.toInt());
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          Directory(out).createSync(recursive: true);
          File(
            '$out/arena_$name.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
          img.dispose();
        });
      }
      pic.dispose();
    }
    game.onRemove();
  });
}
