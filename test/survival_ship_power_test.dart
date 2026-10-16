import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_balance.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// The ship keeps pace with the waves: its hull follows the enemies' damage
/// and its hits their health, so the picks built into it keep their worth;
/// Reinforced Hull adds to the hull and has it rebuilt sooner.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<CosmicSurvivalGame> arena() async {
    final game = CosmicSurvivalGame(
      party: [
        CosmicPartyMember(
          instanceId: 'pip-0',
          baseId: 'PIP01',
          displayName: 'Pip',
          family: 'Pip',
          element: 'Fire',
          level: 10,
          slotIndex: 0,
          statSpeed: 3,
          statIntelligence: 3,
          statStrength: 3,
          statBeauty: 3,
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

  test(
    'hull and hits grow with the wave, keeping what the ship has left',
    () async {
      final game = await arena();
      final first = game.debugShipPower;
      final firstWave = game.spawner.currentWave;
      game.ship.currentHp = game.ship.maxHp * 0.5;
      while (game.spawner.currentWave < 31) {
        game.spawner.forceNextWaveForTest();
      }
      final later = game.debugShipPower;
      expect(
        later.hull / first.hull,
        closeTo(
          CosmicSurvivalBalance.enemyWaveDamageScale(31) /
              CosmicSurvivalBalance.enemyWaveDamageScale(firstWave),
          1e-9,
        ),
      );
      expect(
        later.hit / first.hit,
        closeTo(
          CosmicSurvivalBalance.enemyWaveHpScale(31) /
              CosmicSurvivalBalance.enemyWaveHpScale(firstWave),
          1e-9,
        ),
      );
      expect(later.hull, greaterThan(first.hull * 2));
      expect(game.ship.currentHp / game.ship.maxHp, closeTo(0.5, 1e-9));
    },
  );

  test('Reinforced Hull: half again the hull, rebuilt 6 s sooner', () async {
    final game = await arena();
    final hull = kAllPowerUps.firstWhere((d) => d.id == 'ship_hull');
    expect(hull.category, PowerUpCategory.shipWeapon);
    final plain = game.debugShipPower.hull;
    expect(game.debugShipRespawnDelay, 30);
    for (var level = 1; level <= hull.maxStacks; level++) {
      game.applyPowerUp(hull);
      expect(
        game.debugShipPower.hull,
        closeTo(plain * (1 + 0.5 * level), 1e-9),
      );
      expect(game.debugShipRespawnDelay, 30 - 6 * level);
    }
  });
}
