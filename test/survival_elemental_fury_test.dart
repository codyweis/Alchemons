// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Elemental Fury erupts once per kill, from the killer's elemental attack.
///
/// It used to splash a flat amount and every body the splash finished erupted
/// in turn, so one kill in a packed front chained through all of it. These
/// lay bodies out in a line, each inside the splash of its neighbour and
/// outside the splash of the one after, and kill the first.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember pip(double stat) => CosmicPartyMember(
    instanceId: 'pip-0',
    baseId: 'PIP01',
    displayName: 'Pip',
    family: 'Pip',
    element: 'Fire',
    level: 10,
    slotIndex: 0,
    statSpeed: stat,
    statIntelligence: stat,
    statStrength: stat,
    statBeauty: stat,
    statSpeedPotential: 50,
    statIntelligencePotential: 50,
    statStrengthPotential: 50,
    statBeautyPotential: 50,
    staminaBars: 3,
    staminaMax: 3,
  );

  CosmicSurvivalEnemy body(Offset at, double hp) => CosmicSurvivalEnemy(
    position: at,
    hp: hp,
    maxHp: hp,
    speed: 0,
    damage: 0,
    radius: 10,
    tier: EnemyTier.drone,
    element: 'Earth',
    conduct: EnemyConduct.charge,
    target: CosmicEnemyTarget.orb,
    retargetTimer: 0,
  );

  Future<CosmicSurvivalGame> furyArena({
    required double stat,
    required int furyLevel,
  }) async {
    final game = CosmicSurvivalGame(
      party: [pip(stat)],
      onGameOver: () {},
      random: Random(5),
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    game.summonCompanion(0);
    game.enemies.clear();
    final fury = kAllPowerUps.firstWhere((d) => d.id == 'elemental_fury');
    for (var i = 0; i < furyLevel; i++) {
      game.applyPowerUp(fury);
    }
    return game;
  }

  /// A line of bodies 60 px apart: each is inside its neighbour's 80 px
  /// splash and outside the next one's.
  List<CosmicSurvivalEnemy> line(CosmicSurvivalGame game, double hp) {
    final origin = game.orb.position + const Offset(400, 0);
    final bodies = [
      for (var i = 0; i < 12; i++) body(origin + Offset(i * 60.0, 0), hp),
    ];
    game.enemies.addAll(bodies);
    game.debugRebuildEnemyGrid();
    return bodies;
  }

  test('a kill erupts once; the bodies it finishes do not', () async {
    final game = await furyArena(stat: 4.25, furyLevel: 3);
    final bodies = line(game, 1);

    game.debugKillEnemy(bodies.first);

    expect(bodies[1].isDead, isTrue, reason: 'the splash reaches its neighbour');
    expect(
      bodies.skip(2).where((b) => b.isDead),
      isEmpty,
      reason: 'a splash kill erupted again and chained down the line',
    );
  });

  test('the splash grows with the killer\'s elemental attack', () async {
    Future<double> splashFrom(double stat) async {
      final game = await furyArena(stat: stat, furyLevel: 1);
      final bodies = line(game, 1e6);
      game.debugKillEnemy(bodies.first);
      return 1e6 - bodies[1].hp;
    }

    final average = await splashFrom(4.25);
    final bred = await splashFrom(8.0);
    expect(average, greaterThan(0));
    expect(bred, greaterThan(average * 1.3));
  });
}
