// Open space runs Cosmic Survival's Kin (cosmic_game_kin.dart on
// kin_support_runtime.dart): the charged laser that is the family's basic
// attack, the ×1.6 special cooldown, and each element's support path — the
// Spirit wisp, the Earth wall, the Dust cloud, the Ice release, the Fire
// phoenix and its rebirth, the Plant garden's flowers.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/games/cosmic/kin_support_runtime.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

const _dt = 1 / 60;

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

CosmicEnemy _foe(Offset at, {double health = 100000}) => CosmicEnemy(
  position: at,
  element: 'Fire',
  tier: EnemyTier.drone,
  radius: 10,
  health: health,
  speed: 0,
);

/// A Kin beside the ship with one foe [foeAt] away.
Future<CosmicGame> _openKinArena(
  String element, {
  Offset foeAt = const Offset(80, 0),
}) async {
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
  game.enemies.add(_foe(const Offset(80, 0)));
  game.onGameResize(Vector2(900, 700));
  await game.onLoad();
  game.activeCompanions[0]!
    ..position = game.ship.pos
    ..anchorPosition = game.ship.pos
    ..specialCooldown = 0;
  game.enemies
    ..clear()
    ..add(_foe(game.ship.pos + foeAt));
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
      game.update(_dt);
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

    // The foe stands clear of the Spirit wisp's orbit: survival's wisp is
    // spent on the first body it touches.
    for (final element in const ['Dust', 'Earth', 'Spirit']) {
      final game = await _openKinArena(element, foeAt: const Offset(200, 0));
      game.update(_dt);
      expect(
        game.companionProjectiles.any(
          (p) => p.abilityFamily == 'kin' && p.element == element,
        ),
        isTrue,
        reason: '$element spent an empty cast',
      );
    }
  });

  test('a Kin special waits 1.6× its table cooldown', () async {
    final game = await _openKinArena('Lava');
    final comp = game.activeCompanions[0]!;
    game.update(_dt);
    expect(comp.kinLavaPlateTimer, greaterThan(0));
    expect(
      comp.specialCooldown,
      closeTo(comp.effectiveSpecialCooldown * kKinSpecialCooldownStretch, 1e-6),
    );
  });

  test('the Kin basic is a charged laser, not a thrown orb', () async {
    final game = await _openKinArena('Dark');
    final comp = game.activeCompanions[0]!;
    final foe = game.enemies.first;
    comp.specialCooldown = 1000;
    comp.basicCooldown = 0;
    final startHealth = foe.health;
    var chargeStarted = -1;
    var fired = -1;
    for (var f = 0; f < 240 && fired < 0; f++) {
      game.update(_dt);
      if (chargeStarted < 0 && comp.kinAutoChargeTimer > 0) {
        chargeStarted = f;
        // It holds still while it gathers.
        expect(comp.velocity, Offset.zero);
      }
      if (game.debugKinLaserLengths.isNotEmpty) fired = f;
      // Nothing is thrown.
      expect(
        game.companionProjectiles.where((p) => p.abilityFamily.isEmpty),
        isEmpty,
      );
    }
    expect(chargeStarted, greaterThanOrEqualTo(0), reason: 'never charged');
    expect(fired, greaterThan(chargeStarted), reason: 'never fired');
    expect((fired - chargeStarted) * _dt, closeTo(KinLaser.chargeTime, 0.05));
    expect(
      startHealth - foe.health,
      closeTo(comp.physAtk * KinLaser.damageScale, 0.01),
    );
  });

  test(
    'the Spirit wisp follows its kin, draws aggro, and feeds on laser kills',
    () async {
      final game = await _openKinArena('Spirit', foeAt: const Offset(150, 0));
      final comp = game.activeCompanions[0]!;
      game.update(_dt);
      final wisp = game.companionProjectiles.firstWhere(
        (p) => p.abilityFamily == 'kin' && p.element == 'Spirit',
      );
      expect(wisp.followSourceCompanion, isTrue);
      expect(wisp.decoy, isFalse);
      expect(wisp.damage, 0);
      expect(wisp.effectCount, 1);
      comp.specialCooldown = 1000;

      // Five frail bodies on the laser's line, clear of the wisp's orbit.
      game.enemies
        ..clear()
        ..addAll([
          for (var i = 0; i < 5; i++)
            _foe(comp.position + Offset(110 + i * 12.0, 0), health: 1),
        ]);
      comp.basicCooldown = 0;
      for (var f = 0; f < 200 && comp.kinSpiritWispKills < 5; f++) {
        game.update(_dt);
      }
      expect(comp.kinSpiritWispKills, 5);
      game.update(_dt);
      expect(wisp.effectCount, 2, reason: 'tier 2 at five kills');
      expect(wisp.tauntRadius, 160);
    },
  );

  test('the Earth wall is a reflecting shove, not a decoy', () async {
    final game = await _openKinArena('Earth', foeAt: const Offset(200, 0));
    game.update(_dt);
    final wall = game.companionProjectiles
        .where((p) => p.abilityFamily == 'kin' && p.element == 'Earth')
        .toList();
    expect(wall.length, greaterThanOrEqualTo(7));
    for (final segment in wall) {
      expect(segment.decoy, isFalse);
      expect(segment.reflectsProjectiles, isTrue);
      expect(segment.tauntRadius, 0);
      expect(segment.hitEffect, AbilityEffectKind.knockback);
      expect((segment.position - game.ship.pos).distance, closeTo(110, 0.01));
    }
  });

  test('a Dust cloud is a wide slowing snare', () async {
    final game = await _openKinArena('Dust', foeAt: const Offset(200, 0));
    game.update(_dt);
    final cloud = game.companionProjectiles.firstWhere(
      (p) => p.abilityFamily == 'kin' && p.element == 'Dust',
    );
    expect(cloud.effectRadius, greaterThanOrEqualTo(136));
    expect(cloud.snareRadius, cloud.effectRadius);
    expect(cloud.tickEffect, AbilityEffectKind.slow);
  });

  test('the Ice release slows everything in reach to a tenth', () async {
    final game = await _openKinArena('Ice');
    final comp = game.activeCompanions[0]!;
    final foe = game.enemies.first;
    game.update(_dt);
    expect(comp.kinIceChargeTimer, greaterThan(0));
    for (var f = 0; f < 600 && comp.kinIceChargeTimer > 0; f++) {
      game.update(_dt);
    }
    expect(comp.kinIceChargeTimer, 0);
    expect(foe.slowMultiplier, closeTo(KinSupport.iceSlowMultiplier, 1e-9));
    expect(foe.slowTimer, greaterThan(3));
  });

  test('open Cosmic Fire Kin saves the ship, not itself', () async {
    final game = await _openKinArena('Fire');
    final kin = game.activeCompanions[0]!;
    game.shipHealth = 1;
    game.enemies.first
      ..position = game.ship.pos
      ..speed = 0;

    for (var i = 0; i < 120 && !kin.kinFireOrbitalFlameActive; i++) {
      game.update(_dt);
    }

    expect(kin.kinFireOrbitalFlameActive, isTrue);
    expect(game.shipHealth, closeTo(CosmicGame.shipMaxHealth * 0.25, 0.01));
    // Reborn: the flame and the buff are rolled from its own stats.
    expect(kin.kinFireRebirthDamageAmp, greaterThan(1));
    expect(kin.kinFireRebirthHaste, lessThan(1));
    game.update(_dt);
    expect(kin.damageAmp, closeTo(kin.kinFireRebirthDamageAmp, 1e-9));
  });

  test('the Plant garden grows flowers that heal the party', () async {
    final game = await _openKinArena('Plant', foeAt: const Offset(200, 0));
    final comp = game.activeCompanions[0]!;
    game.update(_dt);
    final garden = game.companionProjectiles.where(
      (p) => p.abilityFamily == 'kin' && p.element == 'Plant' && p.stationary,
    );
    expect(garden, isNotEmpty);
    comp.specialCooldown = 1000;
    var sawFlower = false;
    comp.currentHp = 40;
    for (var f = 0; f < 60 * 12; f++) {
      game.update(_dt);
      if (game.debugKinFlowers.isNotEmpty) sawFlower = true;
    }
    expect(sawFlower, isTrue, reason: 'no flower in 12s');
    expect(comp.currentHp, greaterThan(40));
  });
}
