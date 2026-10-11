// Open space runs Cosmic Survival's Mane specials (cosmic_game_mane.dart and
// the ability pass, on mane_runtime.dart): Light hangs a ward rather than
// throwing anything, Spirit's stream grows cast by cast, and what each
// catapult does to the bodies it pierces is survival's — Poison stacks,
// Blood feeds what it protects, Dark drags and eats the nearly-dead, Plant's
// vine thickens — and a piercing shot hits every body at full weight.

import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_ability_runtime.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

const _dt = 1 / 60;

CosmicPartyMember _mane(String element) => CosmicPartyMember(
  instanceId: 'mane-$element',
  baseId: 'MAN01',
  displayName: '$element Mane',
  family: 'Mane',
  element: element,
  level: 10,
  slotIndex: 0,
  statSpeed: 4,
  statIntelligence: 4,
  statStrength: 4,
  statBeauty: 4,
  statBeautyPotential: 80,
  staminaBars: 5,
  staminaMax: 5,
);

class _Arena {
  _Arena(this.game, this.mane);
  final CosmicGame game;
  final CosmicCompanion mane;
  late final Offset post = mane.position;

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

  /// Steps until the mane casts; false if it never did.
  bool castSpecial({int maxFrames = 240}) {
    mane.specialCooldown = 0;
    for (var f = 0; f < maxFrames; f++) {
      game.update(_dt);
      if (mane.specialCooldown > 0.5) return true;
    }
    return false;
  }

  void step([int frames = 1]) {
    for (var f = 0; f < frames; f++) {
      game.update(_dt);
    }
  }

  /// The table's catapult for this element, flying from [from] along +x,
  /// as this mane's.
  Projectile shot(Offset from) {
    final p = createCosmicSpecialAbility(
      origin: post + from,
      baseAngle: 0,
      family: 'mane',
      element: mane.member.element,
      damage: 40,
      maxHp: 400,
    ).projectiles.first;
    p
      ..position = post + from
      ..angle = 0
      ..sourceSlotIndex = 0;
    return p;
  }
}

/// A mane out beside the ship in deep space, away from every planet.
Future<_Arena> _arena(String element) async {
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
  game.summonCompanion(_mane(element), slotIndex: 0, initialSpecialCooldown: 0);
  final mane = game.activeCompanions[0]!;
  final post = game.ship.pos + const Offset(0, 160);
  mane
    ..maxHp = 100000
    ..currentHp = 100000
    ..invincibleTimer = 10
    ..basicCooldown = 1000
    ..position = post
    ..anchorPosition = post;
  return _Arena(game, mane);
}

Iterable<Projectile> _rings(CosmicGame game) => game.companionProjectiles.where(
  (p) => p.abilityFamily == 'mane' && p.holdOrbit,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Light hangs three rings, then feeds the outer one', () async {
    final a = await _arena('Light');
    final target = a.foe(const Offset(120, 0));
    for (var i = 0; i < 3; i++) {
      target.position = a.mane.position + const Offset(120, 0);
      expect(a.castSpecial(), isTrue, reason: 'cast ${i + 1}');
      a.mane.basicCooldown = 1000;
    }
    final rings = _rings(a.game).toList()
      ..sort((x, y) => y.orbitRadius.compareTo(x.orbitRadius));
    expect(rings.map((r) => r.orbitRadius), kManeLightOrbitRadii.take(3));
    expect(rings.every((r) => r.followSourceCompanion), isTrue);
    expect(rings.every((r) => r.effectStacks == 0), isTrue);

    target.position = a.mane.position + const Offset(120, 0);
    expect(a.castSpecial(), isTrue, reason: 'cast 4');
    final fed = _rings(a.game).toList()
      ..sort((x, y) => y.orbitRadius.compareTo(x.orbitRadius));
    expect(fed.length, 3, reason: 'the fourth cast hung another ring');
    expect(fed.map((r) => r.effectStacks).toList(), [1, 0, 0]);
    expect(fed.first.radiusMultiplier, kManeLightRadiusByLevel[1]);

    // Nothing grows on a pierce: a ring cutting through a body stays as fed.
    final before = fed.map((r) => r.radiusMultiplier).toList();
    for (var i = 0; i < 6; i++) {
      a.foe(Offset(cos(i.toDouble()) * 66, sin(i.toDouble()) * 66));
    }
    a.step(120);
    expect(
      (_rings(a.game).toList()
            ..sort((x, y) => y.orbitRadius.compareTo(x.orbitRadius)))
          .map((r) => r.radiusMultiplier)
          .toList(),
      before,
    );
  });

  test('Spirit streams one more shot a cast, up to ten, then resets', () async {
    final a = await _arena('Spirit');
    final target = a.foe(const Offset(150, 0));
    final counts = <int>[];
    for (var i = 0; i < 11; i++) {
      a.game.companionProjectiles.clear();
      target.position = a.mane.position + const Offset(150, 0);
      expect(a.castSpecial(), isTrue, reason: 'cast ${i + 1}');
      counts.add(
        a.game.companionProjectiles
            .where((p) => p.abilityFamily == 'mane' && p.element == 'Spirit')
            .length,
      );
    }
    expect(counts, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 1]);
  });

  test('a piercing catapult hits every body at full weight', () async {
    final a = await _arena('Fire');
    a.mane.specialCooldown = 1000;
    final foes = [for (var i = 0; i < 4; i++) a.foe(Offset(80.0 + i * 40, 0))];
    final shot = a.shot(Offset.zero);
    a.game.companionProjectiles.add(shot);
    a.step(90);
    final losses = [for (final f in foes) 1e5 - f.health];
    expect(losses.first, greaterThanOrEqualTo(shot.damage));
    for (final loss in losses) {
      expect(loss, closeTo(losses.first, 1e-6), reason: 'no falloff');
    }
  });

  test('Poison stacks on the body it pierces', () async {
    final a = await _arena('Poison');
    a.mane.specialCooldown = 1000;
    final foe = a.foe(const Offset(80, 0));
    for (var i = 0; i < 3; i++) {
      a.game.companionProjectiles.add(a.shot(Offset.zero));
      a.step(60);
    }
    expect(foe.manePoisonStacks, 3);
  });

  test('Blood feeds the ship on a pierce, up to the heal ceiling', () async {
    final a = await _arena('Blood');
    a.mane.specialCooldown = 1000;
    a.foe(const Offset(80, 0));
    a.game.shipHealth = 40;
    final shot = a.shot(Offset.zero);
    a.game.companionProjectiles.add(shot);
    a.step(60);
    expect(a.game.shipHealth, greaterThan(40), reason: 'the pierce fed nothing');
    // Survival's per-caster ceiling (HealCeiling): what the caster had banked
    // plus a second of refill, at most perfect Beauty's 1.7x rate.
    const rate =
        CosmicGame.shipMaxHealth * HealCeiling.sharePerSecond * 1.7;
    expect(
      a.game.shipHealth,
      lessThanOrEqualTo(40 + rate * (HealCeiling.bucketSeconds + 1) + 0.01),
      reason: 'Blood healed past the ceiling',
    );
  });

  test('Dark drags bodies in as it flies and eats the nearly-dead', () async {
    final a = await _arena('Dark');
    a.mane.specialCooldown = 1000;
    final shot = a.shot(Offset.zero);
    expect(shot.snareRadius, greaterThan(0));
    final dragged = a.foe(Offset(60, shot.snareRadius * 0.6));
    final frail = a.foe(const Offset(140, 0), health: 1e5);
    frail.health = frail.maxHealth * 0.17;
    final startGap = (dragged.position - shot.position).distance;
    a.game.companionProjectiles.add(shot);
    a.step(2);
    expect(
      (dragged.position - shot.position).distance,
      lessThan(startGap),
      reason: 'the bolt did not pull',
    );
    a.step(120);
    expect(frail.dead, isTrue, reason: 'the bolt did not eat a body at 17%');
  });

  test('Plant thickens by 1.42 on every body it passes through', () async {
    final a = await _arena('Plant');
    a.mane.specialCooldown = 1000;
    final shot = a.shot(Offset.zero);
    final start = shot.radiusMultiplier;
    final foe = a.foe(const Offset(80, 0));
    a.game.companionProjectiles.add(shot);
    a.step(60);
    expect(
      shot.radiusMultiplier,
      closeTo(min(start * 1.42, kManePlantMaxRadius), 1e-9),
    );
    expect(foe.maneRootTimer, greaterThan(0));
  });
}
