import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _kin(String element) => CosmicPartyMember(
  instanceId: 'kin-$element',
  baseId: 'KIN01',
  displayName: '$element Kin',
  family: 'Kin',
  element: element,
  level: 10,
  slotIndex: 0,
  statSpeed: 4,
  statIntelligence: 4,
  statStrength: 4,
  statBeauty: 4,
  staminaBars: 5,
  staminaMax: 5,
);

Future<CosmicGame> _openKinArena(String element) async {
  final game = CosmicGame(
    world_: CosmicWorld.generate(seed: 37),
    onMeterChanged: () {},
  );
  game.ship = ShipComponent(pos: Offset.zero);
  game.activeCompanions[0] = CosmicCompanion(
    member: _kin(element),
    position: Offset.zero,
    maxHp: 100,
    currentHp: 100,
    physAtk: 8,
    elemAtk: 12,
    abilityAtk: 12,
    physDef: 5,
    elemDef: 5,
    cooldownReduction: 1,
    critChance: 0,
    attackRange: 180,
    specialAbilityRange: 240,
    specialCooldown: 0,
  );
  game.enemies.add(
    CosmicEnemy(
      position: const Offset(80, 0),
      element: 'Fire',
      tier: EnemyTier.drone,
      radius: 10,
      health: 100000,
      speed: 0,
    ),
  );
  game.onGameResize(Vector2(900, 700));
  await game.onLoad();
  game.activeCompanions[0]!
    ..position = game.ship.pos
    ..anchorPosition = game.ship.pos
    ..specialCooldown = 0;
  game.enemies.clear();
  game.enemies.add(
    CosmicEnemy(
      position: game.ship.pos + const Offset(80, 0),
      element: 'Fire',
      tier: EnemyTier.drone,
      radius: 10,
      health: 100000,
      speed: 0,
    ),
  );
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('open Cosmic starts every active Kin signature', () async {
    const timed = <String>[
      'Lava',
      'Ice',
      'Steam',
      'Lightning',
      'Dark',
      'Blood',
      'Mud',
    ];
    for (final element in timed) {
      final game = await _openKinArena(element);
      game.update(1 / 60);
      final comp = game.activeCompanions[0]!;
      final active = switch (element) {
        'Lava' => comp.kinLavaPlateTimer,
        'Ice' => comp.kinIceChargeTimer,
        'Steam' => comp.kinSteamBoilerTimer,
        'Lightning' => comp.kinLightningChargeTimer,
        'Dark' => comp.kinDarkCloakTimer,
        'Blood' => comp.kinBloodPactTimer,
        'Mud' => comp.kinMudShipEnchantTimer,
        _ => 0.0,
      };
      expect(active, greaterThan(0), reason: '$element spent an empty cast');
    }

    for (final element in const ['Dust', 'Earth', 'Spirit']) {
      final game = await _openKinArena(element);
      game.update(1 / 60);
      expect(
        game.companionProjectiles.any(
          (p) => p.abilityFamily == 'kin' && p.element == element,
        ),
        isTrue,
        reason: '$element spent an empty cast',
      );
    }
  });

  test('open Cosmic Fire Kin saves the ship, not itself', () async {
    final game = await _openKinArena('Fire');
    final kin = game.activeCompanions[0]!;
    game.shipHealth = 1;
    game.enemies.first
      ..position = game.ship.pos
      ..speed = 0;

    for (var i = 0; i < 120 && !kin.kinFireOrbitalFlameActive; i++) {
      game.update(1 / 60);
    }

    expect(kin.kinFireOrbitalFlameActive, isTrue);
    expect(game.shipHealth, closeTo(CosmicGame.shipMaxHealth * 0.25, 0.01));
  });
}
