import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_enemy_vfx.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'dart:ui' as ui;
import 'package:alchemons/games/shared/enemy_action.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:flutter_test/flutter_test.dart';
import '../tool/survival_horde_arena.dart';
import 'package:flame/components.dart';

void main() {
  CosmicSurvivalEnemy enemy({
    EnemyTier tier = EnemyTier.wisp,
    EnemyTrait? trait,
    bool elite = false,
    bool core = false,
  }) => CosmicSurvivalEnemy(
    position: Offset.zero,
    hp: 100,
    maxHp: 100,
    speed: 14,
    damage: 0,
    radius: 8,
    tier: tier,
    element: 'Fire',
    conduct: EnemyConduct.charge,
    target: CosmicEnemyTarget.orb,
    trait: trait,
    isElite: elite,
    isPlagueCore: core,
  );
  test('crowd simplification retains important threats and control cues', () {
    expect(canSimplifySurvivalSwarmEnemy(enemy()), isTrue);
    expect(canSimplifySurvivalSwarmEnemy(enemy(tier: EnemyTier.drone)), isTrue);
    for (final tier in [
      EnemyTier.sentinel,
      EnemyTier.phantom,
      EnemyTier.brute,
      EnemyTier.colossus,
    ]) {
      expect(canSimplifySurvivalSwarmEnemy(enemy(tier: tier)), isFalse);
    }
    for (final trait in EnemyTrait.values) {
      expect(canSimplifySurvivalSwarmEnemy(enemy(trait: trait)), isFalse);
    }
    expect(canSimplifySurvivalSwarmEnemy(enemy(elite: true)), isFalse);
    expect(canSimplifySurvivalSwarmEnemy(enemy(core: true)), isFalse);
    final root = enemy()..maneRootTimer = 1;
    expect(canSimplifySurvivalSwarmEnemy(root), isFalse);
    final frozen = enemy()
      ..slowTimer = 2
      ..slowMultiplier = 0.05;
    expect(canSimplifySurvivalSwarmEnemy(frozen), isFalse);
    final acting = enemy(tier: EnemyTier.drone)
      ..action.phase = EnemyActionPhase.windUp;
    expect(canSimplifySurvivalSwarmEnemy(acting), isFalse);
  });
  test('swarm batch takes plain bodies and declines the detailed ones', () {
    final batch = SurvivalSwarmBatch();
    expect(batch.add(enemy(), 0), isTrue);
    expect(batch.add(enemy(tier: EnemyTier.drone)..hitFlash = 1, 0), isTrue);
    expect(batch.add(enemy(elite: true), 0), isFalse);
    expect(batch.add(enemy(tier: EnemyTier.brute), 0), isFalse);
    expect(batch.length, 2);
    // A dense field also bakes shooters and blinkers, and keeps a body
    // mid-attack in the batch with its telegraph drawn live.
    expect(batch.add(enemy(tier: EnemyTier.sentinel), 0), isFalse);
    expect(batch.add(enemy(tier: EnemyTier.sentinel), 0, dense: true), isTrue);
    expect(batch.add(enemy(tier: EnemyTier.phantom), 0, dense: true), isTrue);
    final winding = enemy(tier: EnemyTier.drone)
      ..action.phase = EnemyActionPhase.windUp;
    expect(batch.add(winding, 0), isFalse);
    expect(batch.add(winding, 0, dense: true), isTrue);
    expect(batch.add(enemy(elite: true), 0, dense: true), isFalse);
    expect(batch.add(enemy(tier: EnemyTier.brute), 0, dense: true), isFalse);
    final frozen = enemy()
      ..slowTimer = 2
      ..slowMultiplier = 0;
    expect(batch.add(frozen, 0, dense: true), isFalse);
    expect(batch.length, 5);
    final rec = ui.PictureRecorder();
    batch.flush(ui.Canvas(rec), 0);
    rec.endRecording().dispose();
    expect(batch.length, 0);
  });
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
