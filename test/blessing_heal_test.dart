import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Blessings have to actually pay out.
///
/// They did not. The tick rounded the per-FRAME amount, and every blessing in
/// the game is between 2.3 and 5.4 HP a second — 0.04 to 0.09 of a point per
/// frame, which `.round()` turns into zero. Not a weak heal: a heal that never
/// landed once, for any family, at any level. The same rounding would have
/// paid 60 HP a second the moment a tick crossed 30, so it was a cliff too.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a blessing pays out its rate, not zero and not sixty', () async {
    final game = CosmicSurvivalGame(
      party: [
        CosmicPartyMember(
          instanceId: 'b',
          baseId: 'B01',
          displayName: 'Blessed',
          family: 'Kin',
          element: 'Light',
          level: 10,
          slotIndex: 0,
          statSpeed: 4,
          statIntelligence: 4,
          statStrength: 4,
          statBeauty: 4,
          statSpeedPotential: 80,
          statIntelligencePotential: 80,
          statStrengthPotential: 80,
          statBeautyPotential: 80,
          staminaBars: 3,
          staminaMax: 3,
        ),
      ],
      random: Random(2),
      onGameOver: () {},
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    game.summonCompanion(0);

    final comp = game.activeCompanions[0]!;
    comp.currentHp = (comp.maxHp * 0.3).round();
    final before = comp.currentHp;

    // A typical rate straight out of the ability table.
    const rate = 4.0;
    comp.blessingHealPerTick = rate;
    comp.blessingTimer = 3.0;
    for (var f = 0; f < 180; f++) {
      game.orb.currentHp = game.orb.maxHp;
      if (game.showingPowerUpSelection) {
        game.alchemicalMeter = 0;
        game.dismissPowerUpSelection();
      }
      game.update(1 / 60);
    }

    final healed = comp.currentHp - before;
    // Three seconds at four a second, give or take the carry and whatever the
    // fight did to it in the meantime.
    expect(
      healed,
      greaterThan(6),
      reason: 'the blessing paid out nothing — the rounding hole is back',
    );
    expect(
      healed,
      lessThan(40),
      reason:
          'the blessing paid out far more than its rate; the old rounding '
          'would have given sixty a second once a tick crossed thirty',
    );
  });
}
