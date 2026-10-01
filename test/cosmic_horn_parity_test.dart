// Open space runs Cosmic Survival's Horn specials (cosmic_game_horn.dart on
// horn_runtime.dart): the wind-ups hold the horn and resolve into a ram,
// Water rams round a circle, Ice dashes sideways painting a wall, Lightning
// brews a storm where it lands, Light holds a barrier, Blood pays for its
// ram, Crystal's shards orbit the live horn, the burst lands where the ram
// does, and kills in the window pay each element's kill effect.

import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/games/cosmic/horn_runtime.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

const _dt = 1 / 60;

CosmicPartyMember _horn(String element, {int slot = 0}) => CosmicPartyMember(
  instanceId: 'horn-$element-$slot',
  baseId: 'HOR01',
  displayName: '$element Horn',
  family: 'Horn',
  element: element,
  level: 10,
  slotIndex: slot,
  statSpeed: 3,
  statIntelligence: 3,
  statStrength: 3,
  statBeauty: 3,
  staminaBars: 5,
  staminaMax: 5,
);

class _Arena {
  _Arena(this.game, this.horn);
  final CosmicGame game;
  final CosmicCompanion horn;

  /// Where the horn stood when the arena was made; foes are placed round it.
  late final Offset post = horn.position;

  CosmicEnemy foe(Offset at, {double health = 1e5}) {
    final e = CosmicEnemy(
      position: post + at,
      element: 'Fire',
      tier: EnemyTier.drone,
      radius: 10,
      health: health,
      speed: 0,
    );
    game.enemies.add(e);
    return e;
  }

  /// Steps until the horn casts; false if it never did.
  bool castSpecial({int maxFrames = 240}) {
    horn.specialCooldown = 0;
    for (var f = 0; f < maxFrames; f++) {
      game.update(_dt);
      if (horn.specialCooldown > 0.5) return true;
    }
    return false;
  }

  void step([int frames = 1]) {
    for (var f = 0; f < frames; f++) {
      game.update(_dt);
    }
  }

  Iterable<Projectile> hornPieces() => game.companionProjectiles.where(
    (p) => p.abilityFamily == 'horn' && p.sourceSlotIndex == 0,
  );
}

/// A horn out beside the ship in deep space, away from every planet.
/// [tethered] false frees it of the ship's leash, which is open space's own
/// and pulls back a horn that strays past 240, even one its special holds.
Future<_Arena> _arena(String element, {bool tethered = true}) async {
  final game = CosmicGame(
    world_: CosmicWorld.generate(seed: 37),
    onMeterChanged: () {},
  );
  game.ship = ShipComponent(pos: Offset.zero);
  game.onGameResize(Vector2(900, 700));
  await game.onLoad();
  final world = game.world_;
  var home = Offset.zero;
  var best = -1.0;
  for (var gx = 1; gx < 20; gx++) {
    for (var gy = 1; gy < 20; gy++) {
      final p = Offset(
        world.worldSize.width * gx / 20,
        world.worldSize.height * gy / 20,
      );
      var nearest = double.infinity;
      for (final planet in world.planets) {
        nearest = min(nearest, (planet.position - p).distance);
      }
      if (nearest > best) {
        best = nearest;
        home = p;
      }
    }
  }
  game.teleportTo(home);
  game.enemies.clear();
  game.activeBoss = null;
  game.summonCompanion(_horn(element), slotIndex: 0, initialSpecialCooldown: 0);
  game.companionTethered = tethered;
  final horn = game.activeCompanions[0]!;
  // Out beside the ship, clear of its hull (a body pulled into the ship is
  // rammed), and in reach of what it fights.
  final post = game.ship.pos + const Offset(0, 160);
  horn
    ..maxHp = 100000
    ..currentHp = 100000
    ..invincibleTimer = 10
    ..basicCooldown = 1000
    ..position = post
    ..anchorPosition = post;
  return _Arena(game, horn);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (element, windUp) in const [
    ('Dark', 5.0),
    ('Crystal', 1.2),
    ('Spirit', 2.0),
  ]) {
    test('$element winds up in place for ${windUp}s, then rams', () async {
      final a = await _arena(element);
      a.foe(const Offset(150, 0));
      expect(a.castSpecial(), isTrue);
      final horn = a.horn;
      expect(horn.windUpTimer, greaterThan(0));
      final heldAt = horn.position;
      final cooldown = horn.specialCooldown;
      var frames = 0;
      while (horn.windUpTimer > 0 && frames < 600) {
        a.step();
        if (horn.windUpTimer > 0) {
          frames++;
          expect(horn.position, heldAt, reason: 'the wind-up moved the horn');
        }
      }
      expect(frames * _dt, closeTo(windUp, 0.05));
      expect(horn.isCharging, isTrue, reason: 'the wind-up never rammed');
      while (horn.hornHoldsBody && frames < 1200) {
        a.step();
        frames++;
      }
      expect(horn.hornHoldsBody, isFalse, reason: 'the ram never landed');
      expect(
        horn.specialCooldown,
        cooldown,
        reason: 'the cooldown ran while the special held the horn',
      );
    });
  }

  test('Dark gathers the void and delivers the catch where it lands', () async {
    final a = await _arena('Dark');
    final near = a.foe(const Offset(150, 0));
    final drift = a.foe(const Offset(0, 200));
    expect(a.castSpecial(), isTrue);
    final horn = a.horn;
    final before = (drift.position - horn.position).distance;
    a.step(60);
    expect(
      (drift.position - horn.position).distance,
      lessThan(before),
      reason: 'the void did not pull',
    );
    while (horn.windUpTimer > 0) {
      a.step();
    }
    expect(horn.hornDarkCaptured, containsAll([near, drift]));
    while (horn.isCharging) {
      a.step();
    }
    for (final e in [near, drift]) {
      expect((e.position - horn.position).distance, lessThan(90));
    }
  });

  test(
    'Water rams round a circle and leaves its whirlpool on the rim',
    () async {
      final a = await _arena('Water', tethered: false);
      a.foe(const Offset(150, 0));
      expect(a.castSpecial(), isTrue);
      final horn = a.horn;
      expect(horn.chargePathType, 'circle');
      final center = horn.chargeCircleCenter!;
      final radius = horn.chargeCircleRadius;
      expect(radius, inInclusiveRange(90, 200));
      while (horn.isCharging) {
        a.step();
        if (horn.isCharging) {
          expect((horn.position - center).distance, closeTo(radius, 0.5));
        }
      }
      final pool = a.hornPieces().where((p) => p.element == 'Water').toList();
      expect(pool, isNotEmpty, reason: 'no whirlpool');
      expect((pool.first.position - center).distance, closeTo(radius, 2));
    },
  );

  test('Ice dashes square to its target, painting a wall', () async {
    final a = await _arena('Ice');
    final target = a.foe(const Offset(150, 0));
    expect(a.castSpecial(), isTrue);
    final horn = a.horn;
    expect(horn.chargePathType, 'ice-wall');
    final from = horn.pendingChargeOrigin!;
    while (horn.isCharging) {
      a.step();
    }
    final aim = target.position - from;
    final moved = horn.position - from;
    final along = (moved.dx * aim.dx + moved.dy * aim.dy) / aim.distance;
    expect(moved.distance, greaterThan(150));
    expect(along.abs(), lessThan(moved.distance * 0.3), reason: 'not sideways');
    final wall = a.hornPieces().where(
      (p) => p.element == 'Ice' && p.decoy && p.reflectsProjectiles,
    );
    expect(wall.length, greaterThanOrEqualTo(8));
  });

  test('Fire lays a burning lane along the ram', () async {
    final a = await _arena('Fire');
    a.foe(const Offset(200, 0));
    expect(a.castSpecial(), isTrue);
    while (a.horn.isCharging) {
      a.step();
    }
    final lane = a.hornPieces().where(
      (p) =>
          p.element == 'Fire' &&
          p.stationary &&
          p.tickEffect == AbilityEffectKind.burn &&
          p.effectRadius == 40,
    );
    expect(lane.length, greaterThanOrEqualTo(3));
  });

  test(
    'Lightning brews 3s where it lands, then discharges what it absorbed',
    () async {
      final a = await _arena('Lightning', tethered: false);
      a.foe(const Offset(150, 0));
      expect(a.castSpecial(), isTrue);
      final horn = a.horn;
      final zone = horn.pendingChargeBurst!.firstWhere(
        (p) => p.tickEffect == AbilityEffectKind.chain,
      );
      final basePower = zone.effectPower;
      horn.invincibleTimer = 0;
      while (horn.isCharging) {
        a.step();
      }
      // Something struck it mid-ram.
      horn.hornLightningAbsorbed = max(horn.hornLightningAbsorbed, 40);
      final absorbed = horn.hornLightningAbsorbed;
      expect(horn.hornPostDashWindUpTimer, greaterThan(2.9));
      final landed = horn.position;
      expect(a.game.companionProjectiles.contains(zone), isFalse);
      var brew = 0;
      while (horn.hornPostDashWindUpTimer > 0) {
        a.step();
        brew++;
        expect(horn.position, landed);
      }
      expect(brew * _dt, closeTo(HornRules.postDashBrew, 0.05));
      expect(a.game.companionProjectiles.contains(zone), isTrue);
      expect(
        zone.effectPower,
        closeTo(basePower + absorbed * hornLightningAbsorbMultiplier(3), 1e-6),
      );
    },
  );

  test(
    'Light holds its barrier: rooted, cooldowns frozen, bodies bounced',
    () async {
      final a = await _arena('Light');
      a.foe(const Offset(150, 0));
      expect(a.castSpecial(), isTrue);
      final horn = a.horn;
      final barrier = a.hornPieces().firstWhere(isHornLightBarrier);
      final at = horn.position;
      final special = horn.specialCooldown;
      final intruder = a.foe(barrier.position - a.post + const Offset(10, 0));
      a.step(2);
      final reach = hornLightProtectRadius(barrier) + intruder.radius;
      expect(
        (intruder.position - barrier.position).distance,
        greaterThanOrEqualTo(reach - 1),
      );
      a.step(60);
      expect(horn.position, at);
      expect(horn.specialCooldown, special);
    },
  );

  test('Blood pays 18% for its ram and every kill heals it', () async {
    final a = await _arena('Blood');
    a.horn.currentHp = 50000;
    for (var i = 0; i < 3; i++) {
      a.foe(Offset(140 + i * 12.0, i * 6.0), health: 1);
    }
    final hp = a.horn.currentHp;
    expect(a.castSpecial(), isTrue);
    final sac = hornBloodSacrifice(hp)!;
    expect(a.horn.currentHp, hp - sac.sacrifice);
    expect(a.horn.hitFlash, greaterThan(0));
    final afterCast = a.horn.currentHp;
    while (a.horn.isCharging) {
      a.step();
    }
    final kills =
        a.game.enemies.where((e) => e.dead).length +
        (3 - a.game.enemies.length);
    expect(kills, greaterThan(0));
    expect(
      a.horn.currentHp,
      afterCast + kills * hornBloodKillHeal(a.horn.maxHp, 3),
    );
    expect(a.game.lootDrops, isNotEmpty, reason: 'a ram kill dropped nothing');
  });

  test('Crystal shards come at the impact and orbit the live horn', () async {
    final a = await _arena('Crystal');
    a.foe(const Offset(150, 0));
    expect(a.castSpecial(), isTrue);
    bool shard(Projectile p) => p.element == 'Crystal' && p.orbitRadius > 0;
    while (a.horn.hornHoldsBody) {
      expect(a.hornPieces().where(shard), isEmpty);
      a.step();
    }
    final shards = a.hornPieces().where(shard).toList();
    expect(shards, isNotEmpty);
    a.step(30);
    for (final s in shards.where((s) => s.life > 0)) {
      expect((s.orbitCenter! - a.horn.position).distance, lessThan(20));
    }
  });

  test('a ram\'s burst goes off where it lands', () async {
    final a = await _arena('Earth');
    a.foe(const Offset(150, 0));
    expect(a.castSpecial(), isTrue);
    while (a.horn.isCharging) {
      expect(a.hornPieces(), isEmpty);
      a.step();
    }
    final cairn = a.hornPieces().firstWhere((p) => p.decoy);
    expect((cairn.position - a.horn.position).distance, lessThan(40));
  });

  test('Plant roots what its ram passes', () async {
    final a = await _arena('Plant');
    final e = a.foe(const Offset(150, 0));
    expect(a.castSpecial(), isTrue);
    var rooted = 0.0;
    while (a.horn.isCharging) {
      a.step();
      rooted = max(rooted, e.hornPlantRootTimer);
    }
    expect(rooted, closeTo(hornPlantRootDuration(3), 0.05));
    expect(e.moveSpeed, 0);
  });

  test('Poison bites once more with each ram hit', () async {
    final a = await _arena('Poison');
    final e = a.foe(const Offset(150, 0));
    expect(a.castSpecial(), isTrue);
    final before = e.health;
    while (a.horn.isCharging) {
      a.step();
    }
    expect(
      before - e.health,
      closeTo(
        a.horn.chargeDamage + a.horn.abilityAtk * HornRules.poisonDashShare,
        1e-6,
      ),
    );
  });

  test(
    'Steam: a kill in the window resets the special and leaves a geyser',
    () async {
      final a = await _arena('Steam');
      final victim = a.foe(const Offset(150, 0), health: 1);
      expect(a.castSpecial(), isTrue);
      while (a.horn.isCharging && !victim.dead) {
        a.step();
      }
      expect(victim.dead, isTrue);
      expect(a.horn.specialCooldown, 0);
      expect(
        a.hornPieces().any(
          (p) =>
              p.tickEffect == AbilityEffectKind.geyser &&
              (p.position - victim.position).distance < 1,
        ),
        isTrue,
      );
    },
  );

  test(
    'Lava: a kill throws seeking flames at the prey nearby, none alone',
    () async {
      for (final withPrey in [true, false]) {
        final a = await _arena('Lava');
        final victim = a.foe(const Offset(150, 0), health: 1);
        if (withPrey) {
          a.foe(const Offset(150, 250));
          a.foe(const Offset(120, -250));
        }
        expect(a.castSpecial(), isTrue);
        while (a.horn.isCharging && !victim.dead) {
          a.step();
        }
        expect(victim.dead, isTrue);
        final flames = a.hornPieces().where(
          (p) => p.element == 'Fire' && p.homing,
        );
        if (withPrey) {
          expect(flames.length, inInclusiveRange(2, 6));
        } else {
          expect(flames, isEmpty);
        }
      }
    },
  );

  test('passives reach survival\'s radii at stat 3', () async {
    expect(hornAirAura(3).outer, 230);
    expect(hornPoisonAuraScale(3) * HornRules.poisonAuraRadius, 140);
    // Past the old 4.0-baseline reach (207 and 126), inside survival's.
    final air = await _arena('Air');
    final blown = air.foe(const Offset(0, 220));
    final start = blown.position;
    air.step();
    expect(blown.position.dy, greaterThan(start.dy));

    final poison = await _arena('Poison');
    final bitten = poison.foe(const Offset(0, 135));
    poison.horn.specialCooldown = 1000;
    poison.step();
    expect(bitten.health, lessThan(1e5));
  });

  test('Mud trails sludge only while out fighting', () async {
    final idle = await _arena('Mud');
    idle.step(240);
    expect(idle.hornPieces().where((p) => p.element == 'Mud'), isEmpty);

    final fighting = await _arena('Mud');
    fighting.foe(const Offset(150, 0));
    fighting.step(240);
    expect(fighting.hornPieces().where((p) => p.element == 'Mud'), isNotEmpty);
  });
}
