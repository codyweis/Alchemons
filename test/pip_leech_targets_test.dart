import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pip+Blood and Pip+Light both resolve to the `leech` effect, and the handler
/// used to heal the orb AND the casting companion for either one — which made
/// two elements mechanically identical.
///
/// The design board gives them different targets, and that difference is the
/// only thing separating them: "enemies that die heal the blood pip" against
/// "enemies that die heal the orb".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember pip(String element) => CosmicPartyMember(
    instanceId: 'leech',
    baseId: 'LCH01',
    displayName: '$element Pip',
    family: 'Pip',
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

  /// Kills one enemy with a [element] pip dart and reports what got healed.
  Future<({int orbHealed, int compHealed})> killOne(String element) async {
    final game = CosmicSurvivalGame(
      party: [pip(element)],
      random: Random(5),
      onGameOver: () {},
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    game.summonCompanion(0);
    for (var i = 0; i < 900 && game.enemies.where((e) => !e.isDead).isEmpty; i++) {
      if (game.showingPowerUpSelection) {
        game.alchemicalMeter = 0;
        game.dismissPowerUpSelection();
      }
      game.update(1 / 60);
    }

    final comp = game.activeCompanions[0]!;
    final target = game.enemies.firstWhere((e) => !e.isDead);

    // Wound both so a heal has somewhere to land.
    game.orb.currentHp = game.orb.maxHp * 0.5;
    comp.currentHp = (comp.maxHp * 0.5).round();
    final orbBefore = game.orb.currentHp;
    final compBefore = comp.currentHp;

    // Resolve the ability directly rather than driving the sim. Letting the
    // game kill the enemy meant the companion's own basic attacks got there
    // first, so the dart's kill effect never ran and both heals read zero.
    final dart = Projectile(
      position: comp.position + const Offset(40, 0),
      angle: 0,
      element: element,
      damage: 50,
      life: 2.0,
      speedMultiplier: 0.01,
      visualStyle: ProjectileVisualStyle.dart,
      abilityFamily: 'pip',
      sourceSlotIndex: 0,
      killEffect: AbilityEffectKind.leech,
      effectPower: 40,
    );
    target
      ..isDead = true
      ..hp = 0
      ..position = comp.position + const Offset(40, 0);
    game.resolveAbilityKill(dart, target);

    return (
      orbHealed: (game.orb.currentHp - orbBefore).round(),
      compHealed: (comp.currentHp - compBefore).round(),
    );
  }

  test('Blood heals the pip itself and not the orb', () async {
    final r = await killOne('Blood');
    expect(
      r.compHealed,
      greaterThan(0),
      reason: 'Blood feeds itself — "enemies that die heal the blood pip"',
    );
    expect(
      r.orbHealed,
      isZero,
      reason: 'Blood healing the orb too is what made it identical to Light',
    );
  });

  test('Light heals the orb and not the pip', () async {
    final r = await killOne('Light');
    expect(
      r.orbHealed,
      greaterThan(0),
      reason: 'Light feeds the orb — "enemies that die heal the orb"',
    );
    expect(
      r.compHealed,
      isZero,
      reason: 'Light healing the caster too is what made it identical to Blood',
    );
  });
}
