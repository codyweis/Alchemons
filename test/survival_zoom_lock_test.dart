import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// A zoom locked in camera mode is the zoom the ship is flown at (user,
/// 2026-10-21: "can we add a way to lock camera when zooming out? So I can
/// fly around zoomed out").
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<CosmicSurvivalGame> arena() async {
    final game = CosmicSurvivalGame(
      party: [
        CosmicPartyMember(
          instanceId: 'horn-0',
          baseId: 'HOR02',
          displayName: 'Horn Water',
          family: 'Horn',
          element: 'Water',
          level: 10,
          slotIndex: 0,
          statSpeed: 4.25,
          statIntelligence: 4.25,
          statStrength: 4.25,
          statBeauty: 4.25,
          staminaBars: 3,
          staminaMax: 3,
        ),
      ],
      random: Random(5),
      onGameOver: () {},
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    return game;
  }

  void settle(CosmicSurvivalGame game) {
    for (var i = 0; i < 180; i++) {
      game.update(1 / 60);
    }
  }

  test('a locked zoom stays when the ship is flown, and unlocking ends it', () async {
    final game = await arena();
    settle(game);
    final preset = game.cameraZoom;

    game.setAutopilot(true);
    settle(game);
    game.beginCameraGesture();
    game.cameraGesture(panDelta: Offset.zero, scale: 0.5);
    final out = game.cameraZoom;
    expect(out, lessThan(preset));

    game.setZoomLock(true);
    expect(game.zoomLocked, isTrue);
    game.setAutopilot(false);
    settle(game);
    expect(game.cameraZoom, closeTo(out, 1e-6), reason: 'flown zoomed out');
    expect(game.cameraPanOffset, Offset.zero, reason: 'following the ship');

    game.setZoomLock(false);
    settle(game);
    expect(game.zoomLocked, isFalse);
    expect(game.cameraZoom, closeTo(preset, 1e-6), reason: 'back to the preset');
  });

  test('without a lock, leaving camera mode goes back to the preset', () async {
    final game = await arena();
    settle(game);
    final preset = game.cameraZoom;
    game.setAutopilot(true);
    settle(game);
    game.beginCameraGesture();
    game.cameraGesture(panDelta: Offset.zero, scale: 0.5);
    game.setAutopilot(false);
    settle(game);
    expect(game.cameraZoom, closeTo(preset, 1e-6));
  });
}
