import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/services/debug_settings_service.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// The developer-tools switch collapses Mystic's cadence to five seconds so a
/// field can be judged more than twice a run.
///
/// It must not reach a player who has the switch off. `DebugSettingsService`
/// exists at all because a previous version of this gate was `|| kDebugMode`,
/// which meant developer affordances leaked into normal play — that file
/// documents the incident. This test is the guard against repeating it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => DebugSettingsService.enabledNotifier.value = false);

  CosmicPartyMember member(String family, String element) => CosmicPartyMember(
    instanceId: 'cd',
    baseId: 'CD001',
    displayName: '$family $element',
    family: family,
    element: element,
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
  );

  Future<double> cooldownOnDeploy(String family, String element) async {
    final game = CosmicSurvivalGame(
      party: [member(family, element)],
      random: Random(4),
      onGameOver: () {},
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    game.summonCompanion(0);
    return game.activeCompanions[0]!.specialCooldown;
  }

  test('with developer tools OFF a Mystic keeps its full cadence', () async {
    DebugSettingsService.enabledNotifier.value = false;
    final cd = await cooldownOnDeploy('Mystic', 'Fire');
    expect(
      cd,
      greaterThan(CosmicSurvivalGame.kDebugMysticCooldown),
      reason:
          'the five-second cadence must never reach a player with the switch '
          'off — Mystic carries the longest cooldown in the game on purpose',
    );
  });

  test('with developer tools ON a Mystic waits five seconds', () async {
    DebugSettingsService.enabledNotifier.value = true;
    final cd = await cooldownOnDeploy('Mystic', 'Fire');
    expect(cd, lessThanOrEqualTo(CosmicSurvivalGame.kDebugMysticCooldown));
  });

  test('no other family is touched by the switch', () async {
    // Compared against itself rather than against five seconds: Mane's natural
    // cadence is already about 3.3s, so an absolute threshold would fail on a
    // family the switch never touches. What matters is that flipping the
    // switch changes nothing for anyone but Mystic.
    for (final family in ['Pip', 'Mane', 'Let', 'Kin']) {
      DebugSettingsService.enabledNotifier.value = false;
      final off = await cooldownOnDeploy(family, 'Fire');
      DebugSettingsService.enabledNotifier.value = true;
      final on = await cooldownOnDeploy(family, 'Fire');
      expect(
        on,
        closeTo(off, 0.0001),
        reason: '$family cadence moved when developer tools flipped',
      );
    }
  });
}
