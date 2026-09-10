import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

List<CosmicPartyMember> potentialParty(int potential) {
  final data =
      jsonDecode(
            File('assets/data/alchemons_creatures.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final creatures = data['creatures'] as List;
  const ids = ['PIP01', 'HOR02', 'MAN04', 'MSK12', 'LET02'];
  return [
    for (var i = 0; i < ids.length; i++)
      (() {
        final row = creatures.cast<Map<String, dynamic>>().firstWhere(
          (c) => c['id'] == ids[i],
        );
        final base = row['baseStats'] as Map<String, dynamic>;
        double stat(String key) => AlchemonStatSystem.effectiveInternal(
          speciesBase: base[key] as int,
          level: 10,
          potential: potential,
        );
        return CosmicPartyMember(
          instanceId: 'benchmark_$i',
          baseId: ids[i],
          displayName: row['name'] as String,
          family: row['mutationFamily'] as String,
          element: (row['types'] as List).first as String,
          level: 10,
          slotIndex: i,
          statSpeed: stat('speed'),
          statIntelligence: stat('intelligence'),
          statStrength: stat('strength'),
          statBeauty: stat('beauty'),
          statSpeedPotential: potential.toDouble(),
          statIntelligencePotential: potential.toDouble(),
          statStrengthPotential: potential.toDouble(),
          statBeautyPotential: potential.toDouble(),
          staminaBars: 3,
          staminaMax: 3,
        );
      })(),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('boss projectile intercepted by ship cannot also hit the orb', () async {
    final game = CosmicSurvivalGame(
      party: potentialParty(80),
      onGameOver: () {},
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    game.ship.position = game.orb.position;
    final orbHp = game.orb.currentHp;
    final shipHp = game.ship.currentHp;
    game.bossProjectiles.add(
      SurvivalBossProjectile(
        position: game.orb.position,
        angle: 0,
        element: 'Fire',
        damage: 10,
        speed: 0,
      ),
    );
    game.update(1 / 30);
    expect(game.ship.currentHp, lessThan(shipHp));
    expect(game.orb.currentHp, orbHp);
    expect(game.bossProjectiles, isEmpty);
  });

  test('heavy breaker orb collision is one bounded impact', () async {
    final game = CosmicSurvivalGame(
      party: potentialParty(80),
      onGameOver: () {},
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    final hp = game.orb.currentHp;
    final enemy = CosmicSurvivalEnemy(
      position: game.orb.position,
      hp: 100000,
      maxHp: 100000,
      speed: 0,
      damage: 100000,
      radius: 30,
      tier: EnemyTier.colossus,
      element: 'Fire',
      target: CosmicEnemyTarget.orb,
      conduct: EnemyConduct.charge,
      trait: EnemyTrait.breaker,
    );
    game.enemies.add(enemy);
    game.update(1 / 30);
    expect(enemy.isDead, isTrue);
    expect(hp - game.orb.currentHp, closeTo(game.orb.maxHp * 0.264, 0.001));
  });

  test(
    'boss escorts pause at capacity and resume when enemies are cleared',
    () {
      final spawner = CosmicSurvivalSpawner(random: Random(11))
        ..startFirstWave();
      for (var wave = 1; wave < 50; wave++) {
        spawner.resumeAfterIntermission();
      }
      expect(spawner.update(2, 24, 900, 700, Offset.zero), isEmpty);
      final escorts = spawner.update(2, 0, 900, 700, Offset.zero);
      expect(escorts, isNotEmpty);
      expect(escorts.length, lessThanOrEqualTo(2));
      for (final enemy in escorts) {
        expect(enemy.tier, isNot(EnemyTier.colossus));
        expect(enemy.trait, isNot(EnemyTrait.summoner));
        expect(enemy.trait, isNot(EnemyTrait.splitter));
      }
    },
  );

  for (final (potential, waveTarget, seed) in [
    (35, 10, 11),
    (70, 30, 11),
    (80, 50, 11),
    (80, 50, 29),
    (80, 50, 47),
    (95, 75, 11),
  ]) {
    test(
      '$potential Potential level-10 party can clear wave $waveTarget, seed $seed',
      () async {
        final game = CosmicSurvivalGame(
          party: potentialParty(potential),
          random: Random(seed),
          onGameOver: () {},
        );
        game.onGameResize(Vector2(900, 700));
        await game.onLoad();
        void pick(String id, {int? slot}) => game.applyPowerUp(
          kAllPowerUps.firstWhere((def) => def.id == id),
          targetSlot: slot,
        );
        // Twenty achievable run picks, no permanent upgrades or enhancements.
        for (var i = 0; i < 4; i++) {
          pick('pack_leader');
        }
        for (var i = 0; i < 5; i++) {
          pick('strength_up', slot: i);
        }
        pick('orb_vitality');
        pick('orb_vitality');
        pick('lifesteal', slot: 0);
        for (var i = 0; i < 2; i++) {
          pick('auto_turret');
          pick('regen_field');
        }
        pick('mirror_shield');
        pick('command_strength');
        pick('command_intelligence');
        pick('command_speed');
        game.startGame();
        for (var wave = 1; wave < waveTarget; wave++) {
          game.spawner.resumeAfterIntermission();
        }
        for (var i = 0; i < 5; i++) {
          game.summonCompanion(i);
        }
        game.clearCompanionTether();
        var elapsed = 0.0;
        while (!game.isGameOver &&
            game.spawner.currentWave == waveTarget &&
            elapsed < 360) {
          // Simple legal pilot: protect the orb, purge sources, then close on boss.
          Offset? target;
          var best = double.infinity;
          for (final enemy in game.enemies) {
            if (enemy.isDead) continue;
            final orbDistance = (enemy.position - game.orb.position).distance;
            final score = !enemy.isPlagueCore && orbDistance < 300
                ? orbDistance - 2000
                : enemy.isPlagueCore
                ? -1000.0
                : orbDistance;
            if (score < best) {
              best = score;
              target = enemy.position;
            }
          }
          target ??= game.activeBoss?.position ?? game.orb.position;
          final delta = target - game.ship.position;
          final tangent = delta.distance > 0
              ? Offset(-delta.dy, delta.dx) / delta.distance
              : Offset.zero;
          final movement = delta.distance > 170
              ? delta / delta.distance
              : tangent;
          game.setJoystickInput(movement);
          if (game.showingPowerUpSelection) {
            // No extra strength from mid-encounter drafts in this benchmark.
            game.alchemicalMeter = 0;
            game.dismissPowerUpSelection();
          }
          game.update(1 / 30);
          elapsed += 1 / 30;
        }
        debugPrint(
          'P$potential seed=$seed wave=${game.spawner.currentWave} seconds=${elapsed.round()} '
          'orb=${game.orb.currentHp.round()} bossHp=${game.activeBoss?.hp.round()} '
          'party=${game.activeCompanions.length} outbreak=${game.outbreak?.name}',
        );
        expect(game.isGameOver, isFalse);
        expect(game.spawner.currentWave, greaterThan(waveTarget));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}
