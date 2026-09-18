import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fire kin is the one companion whose whole kit is dormant until the orb
/// dies. It reads as NOTHING on every axis of the ability testbed, because
/// the testbed's orb never dies — and that is the design, not a bug.
///
/// What was wrong is that the phoenix paid nothing for the wait. The flame it
/// unlocked burned a hardcoded 70 units on a hardcoded half-second tick, so a
/// perfect Fire kin and a terrible one were reborn into exactly the same
/// companion. The rebirth now rolls from the kin's own stats.
Future<CosmicSurvivalGame> _fireKin({required double beauty}) async {
  final game = CosmicSurvivalGame(
    party: [
      CosmicPartyMember(
        instanceId: 'fk-$beauty',
        baseId: 'K01',
        displayName: 'Ashling',
        family: 'Kin',
        element: 'Fire',
        level: 10,
        slotIndex: 0,
        statSpeed: 4,
        statIntelligence: 4,
        statStrength: 4,
        statBeauty: beauty,
        statSpeedPotential: 50,
        statIntelligencePotential: 50,
        statStrengthPotential: 50,
        statBeautyPotential: 50,
        staminaBars: 3,
        staminaMax: 3,
      ),
    ],
    random: Random(7),
    onGameOver: () {},
  );
  game.onGameResize(Vector2(900, 700));
  await game.onLoad();
  game.startGame();
  game.summonCompanion(0);
  return game;
}

/// Drops the orb and runs the frame that the phoenix watches for.
void _killOrb(CosmicSurvivalGame game) {
  game.orb.currentHp = 0;
  game.update(1 / 60);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the phoenix saves the orb and never fires twice', () async {
    final game = await _fireKin(beauty: kAbilityStatAverage);
    final comp = game.activeCompanions[0]!;

    expect(comp.kinFireOrbitalFlameActive, isFalse);
    _killOrb(game);

    expect(comp.kinFireOrbitalFlameActive, isTrue);
    expect(game.orb.currentHp, closeTo(game.orb.maxHp * 0.25, 1));

    // A second death is not saved — the flame is the one-shot's receipt.
    final saved = game.orb.currentHp;
    game.orb.currentHp = 0;
    game.update(1 / 60);
    expect(game.orb.currentHp, lessThan(saved));
  });

  test('rebirth pays the kin for the wait', () async {
    final game = await _fireKin(beauty: kAbilityStatAverage);
    final comp = game.activeCompanions[0]!;
    _killOrb(game);

    // The buff is permanent, so the windows the rest of the game buffs
    // through are simply held open.
    expect(comp.kinFireRebirthDamageAmp, greaterThan(1.0));
    expect(comp.kinFireRebirthHaste, lessThan(1.0));
    expect(comp.damageAmpTimer, greaterThan(0));
    expect(comp.basicHasteTimer, greaterThan(0));

    for (var i = 0; i < 120; i++) {
      game.update(1 / 60);
    }
    expect(
      comp.damageAmpTimer,
      greaterThan(0),
      reason: 'the rebirth buff must not expire',
    );
    expect(comp.basicHasteMultiplier, lessThan(1.0));
  });

  test('Beauty decides how wide the reborn flame burns', () async {
    final plain = await _fireKin(beauty: kAbilityStatLow);
    final perfect = await _fireKin(beauty: kAbilityStatPerfect);
    _killOrb(plain);
    _killOrb(perfect);

    final plainRadius = plain.activeCompanions[0]!.kinFireFlameRadius;
    final perfectRadius = perfect.activeCompanions[0]!.kinFireFlameRadius;

    expect(plainRadius, lessThan(70));
    expect(perfectRadius, greaterThan(plainRadius * 1.5));
  });

  test('the flame keeps its own tick gate, not the Steam boiler\'s', () async {
    final game = await _fireKin(beauty: kAbilityStatAverage);
    final comp = game.activeCompanions[0]!;
    _killOrb(game);

    // This used to borrow kinSteamStackDecayTimer, which the boiler also
    // drives — a collision waiting for one companion to hold both.
    comp.kinSteamStackDecayTimer = 99;
    comp.kinFireFlameTimer = 0;
    game.update(1 / 60);
    expect(comp.kinFireFlameTimer, closeTo(comp.kinFireFlameInterval, 0.02));
  });
}
