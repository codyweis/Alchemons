@Tags(['preview'])
library;

// What a busy late wave costs a frame on the UI thread: the game's update,
// and recording its drawing commands (the DisplayList the raster thread is
// handed). A full party is out at the flying zoom on a phone, every special
// is cast once, and the medians and p95 of the next frames are printed.
// Raster time is the GPU's and is not measured here; a phone is the judge
// of that (tool/survival_horde_arena.dart).
//   LATE_COST=1 flutter test test/survival_late_wave_cost_test.dart \
//     --tags preview
// LATE_WAVES (default 62) takes a comma list.

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/ability_grains.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

const _party = <(String, String, String, String)>[
  ('MAN06', 'Lavamane', 'Mane', 'Lava'),
  ('KIN12', 'Plantkin', 'Kin', 'Plant'),
  ('WNG15', 'Darkwing', 'Wing', 'Dark'),
  ('MSK13', 'Poisonmask', 'Mask', 'Poison'),
  ('HOR01', 'Firehorn', 'Horn', 'Fire'),
];

double _at(List<int> sorted, double q) =>
    sorted[((sorted.length - 1) * q).round()] / 1000.0;

bool _grainsLoaded = false;

void main() {
  final on = Platform.environment['LATE_COST'] != null;
  final waves = (Platform.environment['LATE_WAVES'] ?? '62')
      .split(',')
      .map(int.parse);
  for (final wave in waves) {
    testWidgets('late wave cost w$wave', (tester) async {
      if (!on) return;
      final game = CosmicSurvivalGame(
        party: [
          for (final (i, (id, n, f, e)) in _party.indexed)
            CosmicPartyMember(
              instanceId: 'p$i',
              baseId: id,
              displayName: n,
              family: f,
              element: e,
              level: 10,
              slotIndex: i,
              statSpeed: 4,
              statIntelligence: 4,
              statStrength: 4,
              statBeauty: 4,
              staminaBars: 3,
              staminaMax: 3,
            ),
        ],
        random: Random(11),
        onGameOver: () {},
      );
      const w = 412.0, h = 915.0;
      game.onGameResize(Vector2(w, h));
      await game.onLoad();
      game.startGame();
      final pack = kAllPowerUps.firstWhere((d) => d.id == 'pack_leader');
      for (var i = 0; i < 4; i++) {
        game.powerUps.apply(pack);
      }
      game.spawner.currentWave = wave - 1;
      game.spawner.resumeAfterIntermission();
      // The floor a run this deep would have left.
      game.debugWear.seed(wave);
      game.spawner.isBossWave = false;
      void keepAlive() {
        game.alchemicalMeter = 0;
        game.gamePaused = false;
        game.showingPowerUpSelection = false;
        game.orb.currentHp = game.orb.maxHp.toDouble();
        game.ship.currentHp = game.ship.maxHp.toDouble();
        for (final c in game.activeCompanions.values) {
          c.currentHp = c.maxHp;
        }
      }

      if (!_grainsLoaded) {
        _grainsLoaded = true;
        await tester.runAsync(() => AbilityGrainSprite.ensureLoaded());
      }
      for (var f = 0; f < 60 * 3; f++) {
        keepAlive();
        game.update(1 / 60);
      }
      for (var i = 0; i < _party.length; i++) {
        game.summonCompanion(i);
      }
      for (var f = 0; f < 60 * 16; f++) {
        keepAlive();
        game.update(1 / 60);
      }
      game.setCameraZoom(0.595);
      game.cameraPanOffset = Offset.zero;
      for (final c in game.activeCompanions.values) {
        c.specialCooldown = 0;
      }

      void draw() {
        final rec = ui.PictureRecorder();
        final canvas = ui.Canvas(rec);
        canvas.clipRect(const ui.Rect.fromLTWH(0, 0, w, h));
        game.render(canvas);
        rec.endRecording().dispose();
      }

      // Warm, then sample.
      for (var f = 0; f < 30; f++) {
        keepAlive();
        game.update(1 / 60);
        draw();
      }
      final updates = <int>[], draws = <int>[];
      final clock = Stopwatch();
      for (var f = 0; f < 240; f++) {
        keepAlive();
        clock
          ..reset()
          ..start();
        game.update(1 / 60);
        updates.add(clock.elapsedMicroseconds);
        clock
          ..reset()
          ..start();
        draw();
        draws.add(clock.elapsedMicroseconds);
      }
      updates.sort();
      draws.sort();
      stdout.writeln(
        'late cost w$wave: bodies ${game.enemies.where((e) => !e.isDead).length} '
        'update median ${_at(updates, 0.5).toStringAsFixed(2)} ms '
        'p95 ${_at(updates, 0.95).toStringAsFixed(2)} ms | '
        'draw median ${_at(draws, 0.5).toStringAsFixed(2)} ms '
        'p95 ${_at(draws, 0.95).toStringAsFixed(2)} ms',
      );
      game.onRemove();
    });
  }
}
