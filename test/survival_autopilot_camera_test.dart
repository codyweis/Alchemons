import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Autopilot: the ship orbits on its own, the arena becomes a camera.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<CosmicSurvivalGame> arena() async {
    final game = CosmicSurvivalGame(
      party: [
        CosmicPartyMember(
          instanceId: 'ap',
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
      onGameOver: () {},
      random: Random(5),
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    return game;
  }

  test('on autopilot the ship holds an orbit and keeps moving', () async {
    final game = await arena();
    game.ship.position = game.orb.position + const Offset(300, 0);
    game.setAutopilot(true);
    final radius = (game.ship.position - game.orb.position).distance;
    final start = game.ship.position;
    for (var i = 0; i < 60 * 6; i++) {
      game.enemies.clear();
      game.update(1 / 60);
    }
    final now = (game.ship.position - game.orb.position).distance;
    expect(now, closeTo(radius, 40));
    expect((game.ship.position - start).distance, greaterThan(120));
    expect(game.autopilot, isTrue);
  });

  test(
    'camera mode clears held input and stays on until explicit exit',
    () async {
      final game = await arena();
      final changes = <bool>[];
      game.autopilotState.addListener(() => changes.add(game.autopilot));
      game.setJoystickInput(const Offset(0.8, 0));
      game.setAutopilot(true);
      game.enemies.clear();
      game.update(1 / 60);
      expect(game.autopilot, isTrue);
      game.beginCameraGesture();
      game.cameraGesture(panDelta: const Offset(80, 40), scale: 1.3);
      expect(game.cameraPanOffset, isNot(Offset.zero));
      // Late callbacks from the old joystick cannot cancel camera mode.
      game.setJoystickInput(const Offset(0.8, 0));
      game.update(1 / 60);
      expect(game.autopilot, isTrue);
      game.setAutopilot(false);
      expect(game.autopilot, isFalse);
      expect(game.cameraPanOffset, Offset.zero);
      expect(changes, [true, false]);
      final start = game.ship.position;
      game.setJoystickInput(const Offset(1, 0));
      game.update(1 / 60);
      expect(game.ship.position.dx, greaterThan(start.dx));
    },
  );

  test(
    'panned view stays fixed while the ship orbits; recenter follows again',
    () async {
      final game = await arena();
      game.setAutopilot(true);
      game.beginCameraGesture();
      game.cameraGesture(panDelta: const Offset(90, 50), scale: 1);
      final centre = game.ship.position + game.cameraPanOffset;
      final shipStart = game.ship.position;
      for (var i = 0; i < 90; i++) {
        game.enemies.clear();
        game.update(1 / 60);
      }
      expect((game.ship.position - shipStart).distance, greaterThan(1));
      expect(
        (game.ship.position + game.cameraPanOffset - centre).distance,
        lessThan(1e-8),
      );
      game.recenterCamera();
      game.update(1 / 60);
      expect(game.autopilot, isTrue);
      expect(game.cameraPanOffset, Offset.zero);
    },
  );

  test('pinch preserves the world point under the fingers', () async {
    final game = await arena();
    game.setAutopilot(true);
    game.setCameraZoom(0.6);
    const focal = Offset(610, 310);
    final before = Offset(game.camX, game.camY) + focal / game.cameraZoom;
    game.beginCameraGesture();
    game.cameraGesture(panDelta: Offset.zero, scale: 1.3, focalPoint: focal);
    final after = Offset(game.camX, game.camY) + focal / game.cameraZoom;
    expect((after - before).distance, lessThan(1e-8));
  });

  test('entry zooms out and a drag interrupts the zoom animation', () async {
    final game = await arena();
    game.setAutopilot(true);
    for (var i = 0; i < 30; i++) {
      game.enemies.clear();
      game.update(1 / 60);
    }
    expect(game.cameraZoom, closeTo(0.5, 1e-9));
    game.recenterCamera();
    game.update(1 / 60);
    game.beginCameraGesture();
    final zoom = game.cameraZoom;
    for (var i = 0; i < 30; i++) {
      game.enemies.clear();
      game.update(1 / 60);
    }
    expect(game.cameraZoom, zoom);
  });

  test('a run pinches out to the whole arena and in to 1x', () async {
    final game = await arena();
    game.setAutopilot(true);
    game.beginCameraGesture();
    game.cameraGesture(panDelta: Offset.zero, scale: 0.01);
    // Out to the point where the view covers the arena, and the arena has
    // not grown to meet it.
    expect(game.cameraZoom, closeTo(game.cameraZoomMin, 1e-9));
    expect(game.cameraZoom, lessThan(0.5));
    expect(game.debugArenaRadius, closeTo(1140, 1e-6));
    expect(
      max(game.size.x, game.size.y) / game.cameraZoom * 0.54,
      closeTo(1140, 1e-6),
    );
    game.beginCameraGesture();
    game.cameraGesture(panDelta: Offset.zero, scale: 50);
    expect(game.cameraZoom, closeTo(1.0, 1e-9));
  });

  test('the camera cannot be dragged far past the rim', () async {
    final game = await arena();
    game.setAutopilot(true);
    game.beginCameraGesture();
    for (var i = 0; i < 40; i++) {
      game.cameraGesture(panDelta: const Offset(-400, 0), scale: 1.0);
    }
    final centre = game.ship.position + game.cameraPanOffset;
    final fromOrb = (centre - game.orb.position).distance;
    expect(fromOrb, lessThanOrEqualTo(game.debugArenaRadius + 80 + 1e-6));
    expect(fromOrb, greaterThan(game.debugArenaRadius - 1));
  });
}
