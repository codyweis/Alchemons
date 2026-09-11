import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Let aftermath — vines, geysers, healing pools, Dark's bombardment — is
/// authored "if the meteor kills". It used to fire on any hit: the `let` branch
/// of `resolveAbilityHit` returned before ever reading the `killed` flag it was
/// handed. Dark was the sharpest case, throwing five follow-up meteors on a
/// graze rather than a finish.
///
/// Air is the deliberate exception and still fires on any hit, because its
/// knockback is the cast's crowd control and a shove that only lands on a kill
/// is not something a player can plan around.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember member(String element) => CosmicPartyMember(
    instanceId: 'gate',
    baseId: 'GAT01',
    displayName: 'Let $element',
    family: 'Let',
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

  /// Lands one Let meteor on a single enemy and reports how many companion
  /// projectiles exist afterwards. [enemyHp] decides whether the impact kills.
  Future<int> landMeteorOn(String element, {required double enemyHp}) async {
    final game = CosmicSurvivalGame(party: [member(element)], onGameOver: () {});
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    game.summonCompanion(0);

    // Let the spawner produce something to shoot at.
    for (var i = 0; i < 600 && game.enemies.where((e) => !e.isDead).isEmpty; i++) {
      game.update(1 / 60);
    }
    expect(game.enemies.where((e) => !e.isDead), isNotEmpty,
        reason: 'test setup: spawner produced no enemies');

    // Park a lone target away from the spawner's traffic, and clear the rest so
    // the crater can only contain this one body.
    final spot = game.orb.position + const Offset(300, 0);
    final target = game.enemies.firstWhere((e) => !e.isDead);
    for (final enemy in game.enemies) {
      if (!identical(enemy, target)) enemy.isDead = true;
    }
    target
      ..position = spot
      ..hp = enemyHp;

    final result = createCosmicSpecialAbility(
      origin: game.orb.position,
      baseAngle: 0,
      family: 'let',
      element: element,
      damage: 10,
      maxHp: 400,
      targetPos: spot,
    );
    final meteor = result.projectiles.first..sourceSlotIndex = 0;
    game.companionProjectiles.add(meteor);

    // Fly it all the way down and one frame past the landing.
    for (var i = 0; i < 90 && meteor.isDescending; i++) {
      game.update(1 / 60);
    }
    game.update(1 / 60);

    expect(
      target.isDead,
      enemyHp < 50,
      reason: 'test setup: enemy should ${enemyHp < 50 ? "die" : "survive"}',
    );
    // The parent meteor is spent by now; anything left is a follow-up.
    return game.companionProjectiles
        .where((p) => p.element == 'Dark' && p.visualStyle == ProjectileVisualStyle.meteor)
        .length;
  }

  test('Dark throws no follow-up meteors on a hit that does not kill', () async {
    final followUps = await landMeteorOn('Dark', enemyHp: 100000);
    expect(
      followUps,
      isZero,
      reason:
          'A Dark Let that only grazed spawned $followUps follow-up meteors. '
          'The design gates the bombardment on a kill.',
    );
  });

  test('Dark still throws its bombardment on a kill', () async {
    final followUps = await landMeteorOn('Dark', enemyHp: 1);
    expect(
      followUps,
      greaterThan(0),
      reason: 'A Dark Let that killed should still bombard.',
    );
  });
}
