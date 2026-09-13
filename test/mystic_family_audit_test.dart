import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A sweep over the whole Mystic family, element by element.
///
/// The per-world tests each prove one mechanic works. This proves the family is
/// COMPLETE and consistent — that nothing was left half-converted when the
/// seventeen were done one and two at a time over a long stretch, which is
/// exactly the situation where one element quietly keeps the old shape.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember mystic(String element) => CosmicPartyMember(
    instanceId: 'aud-$element',
    baseId: 'AUD01',
    displayName: '$element Mystic',
    family: 'Mystic',
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

  Future<CosmicSurvivalGame> boot(String element) async {
    final game = CosmicSurvivalGame(
      party: [mystic(element)],
      random: Random(3),
      onGameOver: () {},
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    game.summonCompanion(0);
    for (var i = 0;
        i < 1200 && game.enemies.where((e) => !e.isDead).isEmpty;
        i++) {
      game.orb.currentHp = game.orb.maxHp;
      if (game.showingPowerUpSelection) {
        game.alchemicalMeter = 0;
        game.dismissPowerUpSelection();
      }
      game.update(1 / 60);
    }
    return game;
  }

  Future<void> castOnce(CosmicSurvivalGame game) async {
    final comp = game.activeCompanions[0]!;
    final target = game.enemies.firstWhere((e) => !e.isDead);
    comp.specialCooldown = 0;
    for (var f = 0; f < 1200; f++) {
      target
        ..isDead = false
        ..hp = 1e9
        ..position = comp.position + const Offset(70, 0);
      game.orb.currentHp = game.orb.maxHp;
      if (game.showingPowerUpSelection) {
        game.alchemicalMeter = 0;
        game.dismissPowerUpSelection();
      }
      game.update(1 / 60);
      if (game.isMysticFieldSpent(0)) return;
    }
    fail('the Mystic never cast');
  }

  test('every element is named, described and surged', () {
    final missingSurge = <String>[];
    final names = <String, String>{};
    for (final element in kCosmicAbilityElements) {
      final name = cosmicSpecialAbilityName('mystic', element);
      names[element] = name;
      expect(
        name,
        isNot('Guardian Ultimate'),
        reason: '$element fell through to the default ability name',
      );
      if (!kMysticWorldPowerUps.any((d) => d.mysticElement == element)) {
        missingSurge.add(element);
      }
    }
    expect(missingSurge, isEmpty, reason: 'elements with no world surge');
    // No two Mystics share a name.
    expect(names.values.toSet(), hasLength(kCosmicAbilityElements.length));
  });

  test('only Fire authors projectiles; the rest are worlds', () {
    final authoring = <String>[];
    for (final element in kCosmicAbilityElements) {
      final result = createCosmicSpecialAbility(
        origin: Offset.zero,
        baseAngle: 0,
        family: 'mystic',
        element: element,
        damage: 10,
        maxHp: 120,
      );
      if (result.projectiles.isNotEmpty) authoring.add(element);
    }
    expect(
      authoring,
      ['Fire'],
      reason:
          'a world grew a second, older implementation of itself in the shared '
          'ability table',
    );
  });

  for (final element in kCosmicAbilityElements) {
    test('$element is a complete world', () async {
      final game = await boot(element);

      // Nothing before the cast.
      expect(game.mysticWorldReadout(0), isNull);
      await castOnce(game);

      // Cast once, and the button goes dark for the deployment.
      expect(game.isMysticFieldSpent(0), isTrue);
      expect(game.activeCompanions[0]!.specialCooldown.isFinite, isFalse);
      expect(game.mysticWorldIgnitions(0), 1);

      // The environment is up.
      expect(
        game.mysticWorldStrength(0),
        greaterThan(0),
        reason: '$element lit no world',
      );

      // And it can say what it is doing, in a sentence rather than a fragment.
      final readout = game.mysticWorldReadout(0);
      expect(readout, isNotNull, reason: '$element has no pause readout');
      expect(readout!.element, element);
      expect(
        readout.effect.length,
        greaterThan(40),
        reason: '$element has no real description of what its world does',
      );
      expect(
        readout.effect.endsWith('.'),
        isTrue,
        reason: '$element describes itself in a fragment, not a sentence',
      );
      expect(
        readout.effect,
        isNot('This world holds while its Mystic stands.'),
        reason: '$element fell through to the placeholder description',
      );

      // Recall gives the cast back and closes the world.
      game.returnCompanion(0);
      expect(game.isMysticFieldSpent(0), isFalse);
      for (var f = 0; f < 600; f++) {
        game.update(1 / 60);
      }
      expect(
        game.mysticWorldStrength(0),
        isZero,
        reason: '$element outlived its Mystic',
      );
      expect(
        game.mysticWorldEntityCount(0),
        isZero,
        reason: '$element left something standing after its world ended',
      );
    });
  }
}
