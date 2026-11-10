import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import '../tool/survival_horde_arena.dart';
import 'package:flame/components.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final entry in kHordeArenaParties.entries) {
    testWidgets('device stress arena: ${entry.key} fields its whole party', (
      tester,
    ) async {
      final game = HordeArenaGame(
        party: entry.value,
        population: 250,
        mixed: false,
        sustain: false,
      );
      game.onGameResize(Vector2(900, 700));
      await game.onLoad();
      expect(game.activeCompanions.length, entry.value.length);
      for (final count in [250, 500, 1000, 2000]) {
        game.seed(count);
        expect(game.enemies.length, count);
        final kills = game.stats.kills;
        game.massKill();
        expect(game.stats.kills - kills, count ~/ 2);
        expect(game.vfxParticleCount, lessThanOrEqualTo(150));
        game.update(1 / 60);
        expect(game.gamePaused, isFalse);
      }
      // Sustain tops the crowd back up at the rim while bodies keep dying.
      game
        ..seed(500)
        ..massKill()
        ..sustain = true;
      for (var i = 0; i < 10; i++) {
        game.update(1 / 60);
      }
      expect(game.aliveCount, greaterThanOrEqualTo(480));
      game.seed(1000, mixed: true);
      expect(
        game.enemies.where((e) => e.tier == EnemyTier.sentinel).length,
        50,
      );
      game.forceSpecials();
      for (final c in game.activeCompanions.values) {
        expect(c.specialCooldown, 0);
      }
      for (var i = 0; i < 30; i++) {
        game.update(1 / 60);
      }
      final rec = ui.PictureRecorder();
      game.render(ui.Canvas(rec));
      rec.endRecording().dispose();
      game.onRemove();
    });
  }
}
