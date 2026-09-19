import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kin protects the orb. Ordinary bodies go for the orb three times in four
/// and the ship and companions almost never lose health, so a Kin whose
/// reactive kit only read ship and companion damage sat idle. These pin the
/// orb-facing half of each kit, driven through the real game.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember kin(String element, {int slotIndex = 0}) =>
      CosmicPartyMember(
        instanceId: 'kin-$slotIndex',
        baseId: 'KIN01',
        displayName: 'Kin $element',
        family: 'Kin',
        element: element,
        level: 10,
        slotIndex: slotIndex,
        statSpeed: 4.25,
        statIntelligence: 4.25,
        statStrength: 4.25,
        statBeauty: 4.25,
        statSpeedPotential: 50,
        statIntelligencePotential: 50,
        statStrengthPotential: 50,
        statBeautyPotential: 50,
        staminaBars: 3,
        staminaMax: 3,
      );

  /// A quiet arena: the kin is out, nothing is spawned, the special is held.
  Future<CosmicSurvivalGame> arena(String element) async {
    final game = CosmicSurvivalGame(
      party: [kin(element)],
      onGameOver: () {},
      random: Random(5),
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    game.summonCompanion(0);
    game.activeCompanions[0]!.specialCooldown = 99999;
    game.enemies.clear();
    game.orb.shieldHp = 0;
    return game;
  }

  CosmicSurvivalEnemy body(
    Offset at, {
    EnemyConduct conduct = EnemyConduct.charge,
    double speed = 0,
  }) => CosmicSurvivalEnemy(
    position: at,
    hp: 1e6,
    maxHp: 1e6,
    speed: speed,
    damage: 0,
    radius: 10,
    tier: EnemyTier.drone,
    element: 'Earth',
    conduct: conduct,
    target: CosmicEnemyTarget.orb,
    retargetTimer: 0,
  );

  /// One frame with nothing else on the field.
  void quietFrame(CosmicSurvivalGame game) {
    game.enemies.removeWhere((e) => e.hp < 1e5);
    game.update(1 / 60);
    game.enemies.removeWhere((e) => e.hp < 1e5);
  }

  test('a Steam boiler stacks off damage the orb takes', () async {
    final game = await arena('Steam');
    final comp = game.activeCompanions[0]!;
    comp.kinSteamBoilerTimer = 10;
    quietFrame(game);
    expect(comp.kinSteamBoilerStacks, 0);
    // 1.5% of the orb's health is one stack: 6% is four.
    game.debugDamageOrb(game.orb.maxHp * 0.06);
    quietFrame(game);
    expect(comp.kinSteamBoilerStacks, 4);
    // Chaff chipping the orb carries between frames instead of being lost.
    for (var i = 0; i < 6; i++) {
      game.debugDamageOrb(game.orb.maxHp * 0.004);
      quietFrame(game);
    }
    expect(comp.kinSteamBoilerStacks, 5);
  });

  test('a Blood pact makes the companions bleed for the orb', () async {
    final game = await arena('Blood');
    final comp = game.activeCompanions[0]!;
    comp.currentHp = comp.maxHp;
    final orbBefore = game.orb.currentHp;
    final compBefore = comp.currentHp;

    game.debugDamageOrb(200);
    expect(game.orb.currentHp, orbBefore - 200);
    expect(comp.currentHp, compBefore);

    game.orb.currentHp = orbBefore;
    comp.kinBloodPactTimer = 9;
    game.debugDamageOrb(200);
    // 40% is taken by the living companions, split evenly: one kin, 80.
    expect(game.orb.currentHp, orbBefore - 120);
    expect(comp.currentHp, compBefore - 80);
  });

  test('a Blood pact never takes a companion\'s last point', () async {
    final game = await arena('Blood');
    final comp = game.activeCompanions[0]!;
    comp.currentHp = 3;
    comp.kinBloodPactTimer = 9;
    final orbBefore = game.orb.currentHp;
    game.debugDamageOrb(400);
    expect(comp.currentHp, 1);
    // What it could not take, the orb still took.
    expect(game.orb.currentHp, orbBefore - 398);
  });

  test('a Dark veil sends bodies that came for the orb at the ship', () async {
    final game = await arena('Dark');
    final comp = game.activeCompanions[0]!;
    final rim = game.debugArenaRadius;
    final far = game.orb.position + Offset(rim, 0);

    final plain = body(far);
    game.enemies.add(plain);
    quietFrame(game);
    expect(plain.target, CosmicEnemyTarget.orb);

    comp.kinDarkCloakTimer = 7;
    final veiled = body(far);
    game.enemies.add(veiled);
    quietFrame(game);
    expect(veiled.target, CosmicEnemyTarget.ship);

    // Artillery shells a position, so the veil does not move it.
    final gun = body(far, conduct: EnemyConduct.siege);
    game.enemies.add(gun);
    quietFrame(game);
    expect(gun.target, CosmicEnemyTarget.orb);

    // With the ship down there is no decoy to send them at.
    game.ship.isDead = true;
    final noDecoy = body(far);
    game.enemies.add(noDecoy);
    quietFrame(game);
    expect(noDecoy.target, CosmicEnemyTarget.orb);
  });

  test('a Lava plate splashes the body pressing the orb', () async {
    Future<double> splash({required bool plate}) async {
      final game = await arena('Lava');
      final comp = game.activeCompanions[0]!;
      // Park the kin across the arena so its own attacks cannot reach.
      comp.position = game.orb.position + Offset(-800, 0);
      game.clearCompanionTether();
      final pressing = body(game.orb.position + const Offset(120, 0));
      game.enemies.add(pressing);
      if (plate) comp.kinLavaPlateTimer = 9;
      game.debugDamageOrb(50);
      quietFrame(game);
      return pressing.maxHp - pressing.hp;
    }

    expect(await splash(plate: false), 0);
    expect(await splash(plate: true), greaterThan(40));
  });

  test('a Kin\'s cast heals the orb by a share of the orb\'s pool', () async {
    final game = await arena('Light');
    final comp = game.activeCompanions[0]!;
    game.orb.currentHp = game.orb.maxHp * 0.5;
    game.enemies.add(body(comp.position + const Offset(160, 0)));
    comp.specialCooldown = 0;
    var healed = 0.0;
    for (var i = 0; i < 90; i++) {
      final before = game.orb.currentHp;
      game.update(1 / 60);
      healed += max(0.0, game.orb.currentHp - before);
      game.enemies.removeWhere((e) => e.hp < 1e5);
    }
    // Light's ship heal is 8% of the ship's hundred points. Against the
    // orb's pool that is 8% of eight hundred, not eight.
    expect(healed, greaterThan(game.orb.maxHp * 0.06));
  });
}
