// Wing's beams in open space run survival's beam runtime (the source of
// truth) against open space's world: the numbers are WingBeamRules and the
// look is wing_vfx.dart, both shared. These drive the real game, element by
// element, and check what the design board promises.

import 'dart:io';
import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_ability_runtime.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/games/cosmic/wing_vfx.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

const _dt = 1 / 60;

CosmicPartyMember _member(
  String family,
  String element,
  int slot, {
  double beauty = 3,
}) => CosmicPartyMember(
  instanceId: '$family-$element-$slot',
  baseId: '${family.substring(0, 3).toUpperCase()}01',
  displayName: '$element $family',
  family: family,
  element: element,
  level: 10,
  slotIndex: slot,
  statSpeed: 3,
  statIntelligence: 3,
  statStrength: 3,
  statBeauty: beauty,
  staminaBars: 5,
  staminaMax: 5,
);

/// Deep space, away from every planet (and so every garrison).
Future<CosmicGame> _deepSpace() async {
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
  return game;
}

CosmicCompanion _summon(
  CosmicGame game,
  String family,
  String element, {
  int slot = 0,
  double beauty = 3,
}) {
  game.summonCompanion(
    _member(family, element, slot, beauty: beauty),
    slotIndex: slot,
  );
  final c = game.activeCompanions[slot]!;
  c
    ..invincibleTimer = 0
    ..basicCooldown = 100
    ..specialCooldown = 100;
  return c;
}

CosmicEnemy _enemy(
  CosmicGame game,
  Offset offset, {
  double health = 1e5,
  double speed = 0,
  EnemyTier tier = EnemyTier.drone,
}) {
  final e = CosmicEnemy(
    position: game.ship.pos + offset,
    element: 'Fire',
    tier: tier,
    radius: 10,
    health: health,
    speed: speed,
  );
  game.enemies.add(e);
  return e;
}

/// One frame; anything the spawner brought in is taken back out, so only
/// the bodies a test placed are in play.
void _step(CosmicGame game, List<CosmicEnemy> keep, [int frames = 1]) {
  for (var i = 0; i < frames; i++) {
    game.enemies.removeWhere((e) => !keep.contains(e));
    game.update(_dt);
  }
}

/// As [_step], holding [enemy] at [at] so its own AI never carries it into
/// the ship or out of the beam.
void _stepPinned(
  CosmicGame game,
  List<CosmicEnemy> keep,
  CosmicEnemy enemy,
  Offset at, [
  int frames = 1,
]) {
  for (var i = 0; i < frames; i++) {
    _step(game, keep);
    enemy.position = at;
  }
}

/// Lets [comp] cast its special and returns the beams it opened. The
/// projectiles a Wing special also throws are cleared, so only the beams act.
List<WingBeamView> _cast(
  CosmicGame game,
  CosmicCompanion comp,
  List<CosmicEnemy> keep,
) {
  comp.specialCooldown = 0;
  for (var f = 0; f < 240; f++) {
    _step(game, keep);
    final beams = game.debugWingBeams();
    if (beams.isNotEmpty) {
      comp
        ..specialCooldown = 100
        ..basicCooldown = 100;
      game.companionProjectiles.removeWhere((p) => p.abilityFamily == 'wing');
      return beams;
    }
  }
  fail('${comp.member.element} Wing never cast its beam');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Lightning brews in place, blasts once, and is spent', () async {
    final game = await _deepSpace();
    final comp = _summon(game, 'Wing', 'Lightning');
    final target = _enemy(game, const Offset(160, 0));
    final keep = [target];
    final beam = _cast(game, comp, keep).single;
    expect(beam.charging, isTrue);
    final hp0 = target.health;
    final at = comp.position;

    var sawBrew = false;
    for (var f = 0; f < 170; f++) {
      _step(game, keep);
      expect(target.health, hp0, reason: 'the charge dealt damage');
      expect(
        (comp.position - at).distance,
        lessThan(1e-9),
        reason: 'the wing moved while charging',
      );
      expect(
        game.debugBeamFx.where((fx) => fx.wingElement == 'Lightning'),
        isEmpty,
        reason: 'a line was drawn before the blast',
      );
      if (game.debugAbilityVfxCount > 0) sawBrew = true;
    }
    expect(sawBrew, isTrue, reason: 'no storm brewed');

    var blasted = false;
    for (var f = 0; f < 30 && game.debugWingBeams().isNotEmpty; f++) {
      _step(game, keep);
      if (game.debugBeamFx.any(
        (fx) =>
            fx.wingElement == 'Lightning' &&
            (fx.width - beam.width * kWingLightningBlastWidthScale).abs() <
                1e-9,
      )) {
        blasted = true;
      }
    }
    expect(
      game.debugWingBeams(),
      isEmpty,
      reason: 'the beam outlived its blast',
    );
    expect(blasted, isTrue, reason: 'no blast flash');
    // 18 ticks' damage, then the charged rider (2.8 × 3 × effect power, the
    // effect power being half a tick) on a body that lived through it.
    final dpt = beam.damagePerTick;
    expect(hp0 - target.health, closeTo(dpt * 18 + 2.8 * 3 * 0.5 * dpt, 1e-6));

    final after = target.health;
    _step(game, keep, 60);
    expect(target.health, after, reason: 'it kept firing after the blast');
  });

  test('Earth fires a mirror beam from the ship', () async {
    final game = await _deepSpace();
    final comp = _summon(game, 'Wing', 'Earth');
    final keep = [_enemy(game, const Offset(160, 0))];
    final beams = _cast(game, comp, keep);
    expect(beams.map((b) => b.anchor).toSet(), {'caster', 'core'});
    final core = beams.firstWhere((b) => b.anchor == 'core');
    expect(core.origin, game.ship.pos);
  });

  test(
    'Spirit tethers to the ship, the ship fires, and hits haste the wing',
    () async {
      final game = await _deepSpace();
      final comp = _summon(game, 'Wing', 'Spirit');
      final keep = [_enemy(game, const Offset(160, 0))];
      final beams = _cast(game, comp, keep);
      expect(beams.map((b) => b.anchor).toSet(), {'caster', 'ship'});
      _step(game, keep, 30);
      final ship = game.debugWingBeams().firstWhere((b) => b.anchor == 'ship');
      expect(ship.origin, game.ship.pos);
      // The cable runs into the ship, a little narrower than the beam.
      expect(
        game.debugBeamFx.any(
          (fx) =>
              fx.wingElement == 'Spirit' &&
              fx.end == game.ship.pos &&
              (fx.width - ship.width * kWingTetherCableWidthScale).abs() < 1e-9,
        ),
        isTrue,
      );
      expect(comp.basicHasteTimer, greaterThan(0));
      expect(
        comp.basicHasteMultiplier,
        CosmicAbilityRuntime.buffHasteMultiplier,
      );
    },
  );

  test('Water lands on the most hurt ally, never the enemy', () async {
    final game = await _deepSpace();
    final comp = _summon(game, 'Wing', 'Water');
    final keep = [_enemy(game, const Offset(160, 0))];
    game.shipHealth = CosmicGame.shipMaxHealth * 0.3;
    _cast(game, comp, keep);
    _step(game, keep, 2);
    final water = game.debugBeamFx.where((fx) => fx.wingElement == 'Water');
    expect(water, isNotEmpty);
    expect(water.last.end, game.ship.pos);
    final shipBefore = game.shipHealth;
    _step(game, keep, 40);
    expect(game.shipHealth, greaterThan(shipBefore), reason: 'no heal');

    // With a companion more hurt than the ship, the beam goes to it.
    final game2 = await _deepSpace();
    final wing = _summon(game2, 'Wing', 'Water');
    final pip = _summon(game2, 'Pip', 'Fire', slot: 1)
      ..currentHp = 1
      ..basicCooldown = 100;
    final keep2 = [_enemy(game2, const Offset(160, 0))];
    _cast(game2, wing, keep2);
    _step(game2, keep2, 2);
    final ends = game2.debugBeamFx
        .where((fx) => fx.wingElement == 'Water')
        .map((fx) => fx.end);
    expect(ends.last, pip.position);
  });

  test('Plant kills leave flowers; collected, they grow the beam', () async {
    final game = await _deepSpace();
    final comp = _summon(game, 'Wing', 'Plant');
    final prey = _enemy(game, const Offset(150, 0), health: 0.5);
    final keep = [prey];
    final first = _cast(game, comp, keep).single;
    for (var f = 0; f < 60 && !prey.dead; f++) {
      _step(game, keep);
    }
    expect(prey.dead, isTrue);
    expect(game.debugWingFlowers, hasLength(1));
    // It lies inside the ship's pull and drifts in to be collected.
    for (var f = 0; f < 240 && game.debugWingFlowers.isNotEmpty; f++) {
      _step(game, keep);
    }
    expect(game.debugWingFlowers, isEmpty);
    expect(comp.abilityKillStacks, 1);

    for (var f = 0; f < 400 && game.debugWingBeams().isNotEmpty; f++) {
      _step(game, keep);
    }
    final target = _enemy(game, const Offset(160, 0));
    keep.add(target);
    final second = _cast(game, comp, keep).single;
    expect(second.damagePerTick, first.damagePerTick);
    final hp0 = target.health;
    for (var f = 0; f < 60 && target.health == hp0; f++) {
      _step(game, keep);
    }
    expect(
      hp0 - target.health,
      closeTo(second.damagePerTick * WingBeamRules.plantStackBonus(1, 3), 1e-6),
    );
  });

  test(
    'Steam executes its first touch and erupts survival\'s clouds',
    () async {
      final game = await _deepSpace();
      final comp = _summon(game, 'Wing', 'Steam');
      final target = _enemy(game, const Offset(160, 0));
      final keep = [target];
      final beam = _cast(game, comp, keep).single;
      for (var f = 0; f < 60 && !target.dead; f++) {
        _step(game, keep);
      }
      expect(target.dead, isTrue, reason: 'the first touch did not execute');
      final clouds = game.companionProjectiles
          .where((p) => p.abilityFamily == 'wing' && p.element == 'Steam')
          .toList();
      expect(clouds.length, inInclusiveRange(5, 14));
      for (final c in clouds) {
        expect(c.effectPower, closeTo(beam.damagePerTick * 0.42, 1e-9));
        expect(c.effectRadius, closeTo(44, 1e-9));
      }
    },
  );

  test('Lava drops survival\'s scar every tick', () async {
    final game = await _deepSpace();
    final comp = _summon(game, 'Wing', 'Lava');
    final keep = [_enemy(game, const Offset(160, 0))];
    final beam = _cast(game, comp, keep).single;
    _step(game, keep, 40);
    final scars = game.companionProjectiles
        .where((p) => p.abilityFamily == 'wing' && p.element == 'Lava')
        .toList();
    expect(scars, isNotEmpty);
    expect(scars.first.effectPower, closeTo(beam.damagePerTick * 0.45, 1e-9));
    expect(scars.first.effectRadius, closeTo(38, 1e-9));
    expect(scars.first.life, lessThanOrEqualTo(2.6));
  });

  test('Light refracts on a kill, three ways for a beautiful wing', () async {
    for (final (beauty, children) in [(3.0, 2), (5.0, 3)]) {
      final game = await _deepSpace();
      final comp = _summon(game, 'Wing', 'Light', beauty: beauty);
      final prey = _enemy(game, const Offset(150, 0), health: 0.5);
      final keep = [prey];
      final parent = _cast(game, comp, keep).single;
      for (var f = 0; f < 60 && !prey.dead; f++) {
        _step(game, keep);
      }
      final beams = game.debugWingBeams();
      expect(beams, hasLength(1 + children), reason: 'beauty $beauty');
      final scale = WingBeamRules.lightSplitChild(
        const WingBeamEffect(
          element: 'Light',
          targetPolicy: WingBeamTargetPolicy.nearestEnemy,
          duration: 1,
          tickInterval: 1,
          damagePerTick: 1,
        ),
        remaining: 1,
        beauty: beauty,
      ).damagePerTick;
      for (final child in beams.skip(1)) {
        expect(
          child.damagePerTick,
          closeTo(parent.damagePerTick * scale, 1e-9),
        );
      }
    }
  });

  test('Blood\'s execute rider is survival\'s 1.35×', () async {
    final game = await _deepSpace();
    final comp = _summon(game, 'Wing', 'Blood');
    final target = _enemy(
      game,
      const Offset(160, 0),
      tier: EnemyTier.colossus,
      health: CosmicBalance.enemyBaseHealth(EnemyTier.colossus) * 0.9,
    );
    final keep = [target];
    final beam = _cast(game, comp, keep).single;
    final hp0 = target.health;
    for (var f = 0; f < 60 && target.health == hp0; f++) {
      _step(game, keep);
    }
    final dpt = beam.damagePerTick;
    expect(hp0 - target.health, closeTo(dpt + dpt * 0.5 * 1.35, 1e-6));
  });

  test(
    'Crystal heals the ship and caster; its leech deals no extra damage',
    () async {
      final game = await _deepSpace();
      final comp = _summon(game, 'Wing', 'Crystal');
      final target = _enemy(game, const Offset(160, 0));
      final keep = [target];
      game.shipHealth = 20;
      comp.currentHp = comp.maxHp ~/ 2;
      final hpBefore = comp.currentHp;
      final beam = _cast(game, comp, keep).single;
      final hp0 = target.health;
      for (var f = 0; f < 60 && target.health == hp0; f++) {
        _step(game, keep);
      }
      expect(hp0 - target.health, closeTo(beam.damagePerTick, 1e-9));
      expect(game.shipHealth, greaterThan(20));
      expect(comp.currentHp, greaterThan(hpBefore));
    },
  );

  test(
    'crowd control is timed: Ice frost freezes, then everything lapses',
    () async {
      final game = await _deepSpace();
      final comp = _summon(game, 'Wing', 'Ice');
      final target = _enemy(game, const Offset(160, 0), speed: 40);
      final keep = [target];
      final at = target.position;
      _cast(game, comp, keep);
      target.frostBuildup = 0.99;
      for (var f = 0; f < 60 && target.slowMultiplier > 0.05 + 1e-9; f++) {
        _stepPinned(game, keep, target, at);
      }
      expect(target.slowMultiplier, closeTo(WingBeamRules.freezeSlow, 1e-12));
      expect(target.frostBuildup, lessThan(0.5), reason: 'frost did not reset');
      expect(target.slowTimer, greaterThan(2.0));
      // The beam ends and every slow runs down; nothing is left on the body.
      _stepPinned(game, keep, target, at, 60 * 7);
      expect(game.debugWingBeams(), isEmpty);
      expect(target.slowTimer, 0);
      expect(target.moveSpeed, target.speed);
      expect(target.speed, 40, reason: 'a slow compounded into its speed');
    },
  );

  test('Mud\'s long slow does not compound', () async {
    final game = await _deepSpace();
    final comp = _summon(game, 'Wing', 'Mud');
    final target = _enemy(game, const Offset(160, 0), speed: 40);
    final keep = [target];
    final at = target.position;
    _cast(game, comp, keep);
    _stepPinned(game, keep, target, at, 60 * 4);
    expect(target.speed, 40);
    expect(target.moveSpeed, closeTo(40 * 0.45, 1e-9));
    expect(target.slowTimer, greaterThan(50));
  });

  test('Air shoves along the beam', () async {
    final game = await _deepSpace();
    final comp = _summon(game, 'Wing', 'Air');
    final target = _enemy(game, const Offset(160, 0));
    final keep = [target];
    _cast(game, comp, keep);
    final from = target.position;
    for (var f = 0; f < 60 && target.knockbackVelocity == Offset.zero; f++) {
      _step(game, keep);
    }
    expect(target.knockbackVelocity, isNot(Offset.zero));
    _step(game, keep, 6);
    expect(
      (target.position - comp.position).distance,
      greaterThan((from - comp.position).distance),
    );
  });

  test('rings hold full strength and fade over their last 0.45 s', () {
    expect(wingRingFade(2.0), 1.0);
    expect(wingRingFade(0.45), 1.0);
    expect(wingRingFade(0.225), closeTo(0.5, 1e-12));
    expect(wingRingFade(0), 0.0);
  });

  test('a wild Lightning Wing holds still and brews on its own side', () async {
    final game = await _deepSpace();
    final wild = SpaceWildAlchemon(
      id: 'wild-lightning-wing',
      member: _member('Wing', 'Lightning', -1),
      rarity: 'Common',
      position: game.ship.pos + const Offset(260, 40),
    );
    game.addWildAlchemon(wild);
    game.engageWild(wild);
    final opp = game.duelOpponent!;
    opp
      ..maxHp = 1 << 20
      ..currentHp = 1 << 20
      ..specialCooldown = 0;
    for (
      var f = 0;
      f < 240 && game.debugWingBeams(wildSide: true).isEmpty;
      f++
    ) {
      game.update(_dt);
    }
    final beam = game.debugWingBeams(wildSide: true).single;
    expect(beam.charging, isTrue);
    expect(identical(beam.caster, opp), isTrue);
    final at = opp.position;
    var brewed = false;
    for (var f = 0; f < 150; f++) {
      game.update(_dt);
      expect((opp.position - at).distance, lessThan(1e-9));
      if (game.debugAbilityVfxCount > 0) brewed = true;
    }
    expect(brewed, isTrue);
    for (var f = 0; f < 60; f++) {
      game.update(_dt);
    }
    expect(game.debugWingBeams(wildSide: true), isEmpty);
  });

  test('both games draw and rule Wing from the one shared copy', () {
    final survival = File(
      'lib/games/cosmic_survival/cosmic_survival_game.dart',
    ).readAsStringSync();
    final open = File(
      'lib/games/cosmic/cosmic_game_wing.dart',
    ).readAsStringSync();
    for (final shared in [
      'emitWingBeamSegments(',
      'emitWingBeamParticles(',
      'emitWingChargeVisual(',
      'emitWingLightningBlastFlash(',
      'drawWingFlowerPickup(',
      'WingBeamRules.lavaScar(',
      'WingBeamRules.steamClouds(',
      'WingBeamRules.lightSplitChild(',
      'WingBeamRules.plantStackBonus(',
      'WingBeamRules.flowerStep(',
      'WingBeamRules.tickDamage(',
      'wingRingFade(',
    ]) {
      expect(survival, contains(shared), reason: 'survival lost $shared');
      expect(open, contains(shared), reason: 'open space lost $shared');
    }
  });
}
