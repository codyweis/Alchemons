import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/arena_wear.dart';
import 'package:alchemons/games/cosmic_survival/boss_roster_art.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/dust_sea.dart';
import 'package:alchemons/games/cosmic_survival/survival_kind.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'every discipline is drawn in grains: its own boss, or its old form',
    () {
      final spawner = CosmicSurvivalSpawner(random: Random(4));
      for (final (wave, kind) in const [
        (35, SurvivalBossKind.drift),
        (70, SurvivalBossKind.drift),
        (25, SurvivalBossKind.harvester),
        (50, SurvivalBossKind.harvester),
        (5, SurvivalBossKind.unhatched),
        (55, SurvivalBossKind.unhatched),
        (20, SurvivalBossKind.pair),
        (40, SurvivalBossKind.pair),
        (15, SurvivalBossKind.otherOrb),
        (45, SurvivalBossKind.otherOrb),
        // Artillery and siegebreaker keep their archetype's form, in grains.
        (10, SurvivalBossKind.form),
        (30, SurvivalBossKind.form),
      ]) {
        spawner.currentWave = wave;
        final boss = spawner.createBossForWave(wave, const ui.Offset(0, 0))!;
        expect(survivalBossKindOf(boss), kind, reason: 'wave $wave');
      }
    },
  );

  testWidgets('a creature sprite reads as a shadow of grains, its edge '
      'marked', (tester) async {
    // A 64 x 32 sheet: frame 0 holds a disc, frame 1 is empty.
    final rec = ui.PictureRecorder();
    ui.Canvas(rec).drawCircle(
      const ui.Offset(16, 16),
      12,
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
    final sheet = rec.endRecording().toImageSync(64, 32);
    late BossShadow? shadow;
    await tester.runAsync(() async {
      shadow = await bossShadowFromSheet(sheet, 32, 32, across: 32);
    });
    expect(shadow, isNotNull);
    final s = shadow!;
    final edges = [for (var i = 0; i < s.length; i++) s.edge[i]];
    expect(s.length, inInclusiveRange(380, 520), reason: 'a disc of r 12');
    expect(edges.where((e) => e == 1).length, inInclusiveRange(50, 110));
    for (var i = 0; i < s.length; i++) {
      expect(s.x[i].abs(), lessThanOrEqualTo(0.5));
    }
  });

  test('an Other Orb darkens the arena while it lives', () {
    final lit = ArenaWear(), dark = ArenaWear();
    for (var f = 0; f < 60 * 10; f++) {
      for (final (w, e) in [(lit, false), (dark, true)]) {
        w.update(
          1 / 60,
          wave: 15,
          fill: 0.5,
          bearing: 0,
          bossAlive: true,
          eclipse: e,
        );
      }
    }
    expect(dark.gloom, greaterThan(lit.gloom + 0.15));
    expect(dark.floorLight, lessThan(lit.floorLight * 0.8));
  });

  test('the Unhatched sends Strands at every depth', () {
    final spawner = CosmicSurvivalSpawner(random: Random(5));
    for (final wave in const [5, 55, 95]) {
      spawner.currentWave = wave;
      final boss = spawner.createBossForWave(wave, const ui.Offset(0, 0))!;
      final adds = spawner.spawnBossAdds(boss, const ui.Offset(0, 0), 412, 915);
      expect(adds, isNotEmpty);
      for (final a in adds) {
        expect(a.kind, SurvivalKind.strand, reason: 'wave $wave');
      }
    }
  });

  testWidgets('the Unhatched hatches them out of its crack', (tester) async {
    final game = CosmicSurvivalGame(
      party: [
        CosmicPartyMember(
          instanceId: 'p0',
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
      random: Random(11),
      onGameOver: () {},
    );
    game.onGameResize(Vector2(412, 915));
    await game.onLoad();
    game.startGame();
    game.spawner.currentWave = 4;
    game.spawner.resumeAfterIntermission();
    void step() {
      game.alchemicalMeter = 0;
      game.gamePaused = false;
      game.showingPowerUpSelection = false;
      game.orb.currentHp = game.orb.maxHp.toDouble();
      game.ship.currentHp = game.ship.maxHp.toDouble();
      game.update(1 / 60);
    }

    for (var f = 0; f < 60 * 20 && game.activeBoss == null; f++) {
      step();
    }
    final boss = game.activeBoss!;
    expect(survivalBossKindOf(boss), SurvivalBossKind.unhatched);
    while (boss.isSpawning) {
      step();
    }
    boss.hp = boss.maxHp;
    final before = game.enemies.toSet();
    boss.summonTimer = 0.001;
    step();
    final hatched = game.enemies.where((e) => !before.contains(e)).toList();
    final crack = unhatchedCrack(boss);
    final strands = hatched.where((e) => e.kind == SurvivalKind.strand);
    expect(strands.length, greaterThanOrEqualTo(3), reason: '${boss.type}');
    for (final e in strands) {
      expect((e.position - crack).distance, lessThan(boss.radius * 0.6));
    }
    // Half broken open, it hatches a third sooner.
    expect(boss.summonTimer, closeTo(SurvivalBoss.summonCooldown, 0.05));
    boss.hp = boss.maxHp * 0.4;
    boss.summonTimer = 0.001;
    step();
    expect(boss.summonTimer, closeTo(SurvivalBoss.summonCooldown * 0.65, 0.05));
    game.onRemove();
  });

  test('the dust sea settles in while it is called and settles out after', () {
    final sea = DustSea();
    for (var f = 0; f < 60 * 6; f++) {
      sea.update(1 / 60, active: true);
    }
    expect(sea.amount, greaterThan(0.95));
    for (var f = 0; f < 60 * 12; f++) {
      sea.update(1 / 60, active: false);
    }
    expect(sea.visible, isFalse);
    expect(sea.amount, 0);
  });

  testWidgets('a Drift fills the arena with dust; it clears once it falls', (
    tester,
  ) async {
    final game = CosmicSurvivalGame(
      party: [
        CosmicPartyMember(
          instanceId: 'p0',
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
      random: Random(11),
      onGameOver: () {},
    );
    game.onGameResize(Vector2(412, 915));
    await game.onLoad();
    game.startGame();
    game.spawner.currentWave = 34;
    game.spawner.resumeAfterIntermission();
    void keepAlive() {
      game.alchemicalMeter = 0;
      game.gamePaused = false;
      game.showingPowerUpSelection = false;
      game.orb.currentHp = game.orb.maxHp.toDouble();
      game.ship.currentHp = game.ship.maxHp.toDouble();
    }

    void frame() {
      keepAlive();
      game.update(1 / 60);
      final rec = ui.PictureRecorder();
      game.render(ui.Canvas(rec));
      rec.endRecording().dispose();
    }

    for (var f = 0; f < 60 * 20 && game.activeBoss == null; f++) {
      frame();
    }
    expect(game.activeBoss, isNotNull);
    expect(survivalBossKindOf(game.activeBoss!), SurvivalBossKind.drift);
    for (var f = 0; f < 60 * 6; f++) {
      for (final b in game.allLivingBosses) {
        b.hp = b.maxHp;
      }
      frame();
    }
    expect(game.debugDustSea.amount, greaterThan(0.95));
    expect(game.debugDustSea.lastGrains, greaterThan(2000));
    // The Drift and its stream, the core and the bodies all part it.
    expect(game.debugDustSea.sources, greaterThan(10));

    for (final b in game.allLivingBosses.toList()) {
      b.shieldUp = false;
      // Past its phase lines, so one blow fells it (a hit stops at a line).
      b.phasesPassed = SurvivalBoss.phaseGates.length;
      b.wardTimer = 0;
      game.damageBoss(1e9, target: b);
    }
    for (var f = 0; f < 60 * 12; f++) {
      frame();
    }
    expect(game.anyBossAlive, isFalse);
    expect(game.debugDustSea.visible, isFalse);
    game.onRemove();
  });
}
