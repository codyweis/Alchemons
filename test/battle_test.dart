// The PvP battle's rules (cosmic_game_battle.dart): two on the field from
// four, tapped specials, free replacements, two swaps, a side with nobody on
// the field has lost, no Mystics, a Fire kin's phoenix saves a teammate.

import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember battleMember(
  String family,
  String element, {
  double stat = 3,
  String? id,
}) => CosmicPartyMember(
  instanceId: id ?? '$family-$element-${stat.toStringAsFixed(1)}',
  baseId: '${family.substring(0, 3).toUpperCase()}01',
  displayName: '$element $family',
  family: family,
  element: element,
  level: 10,
  slotIndex: 0,
  statSpeed: stat,
  statIntelligence: stat,
  statStrength: stat,
  statBeauty: stat,
  staminaBars: 5,
  staminaMax: 5,
);

/// A game standing in deep space, away from every planet, ready to battle.
Future<(CosmicGame, Offset)> battleArena() async {
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
  return (game, home);
}

/// Runs [game]'s battle to its end, or [limit] seconds.
void runBattle(CosmicGame game, {double limit = 100, void Function()? each}) {
  const dt = 1 / 60;
  var t = 0.0;
  while (!(game.battle?.over ?? true) && t < limit) {
    each?.call();
    game.update(dt);
    t += dt;
  }
}

void main() {
  test('Mystics cannot be brought', () async {
    final (game, home) = await battleArena();
    expect(
      () => game.startBattle(
        home: [battleMember('Mystic', 'Fire'), battleMember('Wing', 'Air')],
        away: [battleMember('Horn', 'Fire'), battleMember('Pip', 'Water')],
        center: home,
      ),
      throwsArgumentError,
    );
  });

  test('two computer sides fight to a finish', () async {
    final (game, home) = await battleArena();
    final b = game.startBattle(
      home: [
        battleMember('Horn', 'Fire'),
        battleMember('Wing', 'Air'),
        battleMember('Kin', 'Water'),
        battleMember('Pip', 'Earth'),
      ],
      away: [
        battleMember('Mane', 'Lava'),
        battleMember('Mask', 'Plant'),
        battleMember('Let', 'Ice'),
        battleMember('Wing', 'Light'),
      ],
      homeAuto: true,
      center: home,
    );
    runBattle(game);
    expect(b.over, isTrue);
    expect(b.result!.at, lessThanOrEqualTo(kBattleTimeLimit + 0.1));
    // Both sides fought: specials were cast and someone fell or time ran out.
    expect(
      b.log.where((e) => e.kind == BattleEventKind.special).length,
      greaterThan(0),
    );
    // No stand-in body is left in the world between turns.
    expect(game.enemies, isEmpty);
  });

  test("a player's specials fire on their own", () async {
    final (game, home) = await battleArena();
    final b = game.startBattle(
      home: [battleMember('Wing', 'Air'), battleMember('Pip', 'Fire')],
      away: [battleMember('Horn', 'Earth'), battleMember('Kin', 'Water')],
      center: home,
    );
    runBattle(game, limit: 20);
    expect(
      b.log.where((e) => e.side == 0 && e.kind == BattleEventKind.special),
      isNotEmpty,
    );
    expect(b.sides[0].creatures[0].lastSpecialAt, greaterThan(0));
  });

  test('a fallen one is replaced from the bench a moment later', () async {
    final (game, home) = await battleArena();
    final b = game.startBattle(
      home: [
        battleMember('Wing', 'Air'),
        battleMember('Pip', 'Fire'),
        battleMember('Horn', 'Earth'),
        battleMember('Kin', 'Water'),
      ],
      away: [battleMember('Horn', 'Fire'), battleMember('Mane', 'Lava')],
      center: home,
    );
    final side = b.sides[0];
    runBattle(game, limit: 1.0);
    side.creatures[3].hpFraction = 0.4;
    side.at(0)!.body!.currentHp = 0;
    game.update(1 / 60);
    expect(side.spots[0], isNull);
    runBattle(game, limit: kBattleReplaceDelay - 0.2);
    expect(side.spots[0], isNull, reason: 'the fall is seen first');
    runBattle(game, limit: 0.5);
    expect(side.spots[0], 2, reason: 'the healthiest on the bench comes on');
    expect(side.swapsLeft, kBattleSwaps, reason: 'a replacement is free');
  });

  test('a fallen place is filled for free; a swap costs one of two', () async {
    final (game, home) = await battleArena();
    final b = game.startBattle(
      home: [
        battleMember('Wing', 'Air'),
        battleMember('Pip', 'Fire'),
        battleMember('Horn', 'Earth'),
        battleMember('Kin', 'Water'),
      ],
      away: [battleMember('Horn', 'Fire'), battleMember('Mane', 'Lava')],
      center: home,
    );
    final side = b.sides[0];
    // Let the leads arrive.
    runBattle(game, limit: 1.0);
    expect(game.battleSummon(0, 2), isFalse, reason: 'no empty place');
    expect(game.battleSummon(0, 2, spot: 0), isTrue);
    expect(side.swapsLeft, kBattleSwaps - 1);
    expect(side.spots[0], 2);
    // The one swapped out keeps its health on the bench.
    expect(side.creatures[0].onField, isFalse);
    expect(side.creatures[0].fallen, isFalse);
    runBattle(game, limit: 1.0);
    expect(game.battleSummon(0, 0, spot: 1), isTrue);
    expect(side.swapsLeft, 0);
    runBattle(game, limit: 1.0);
    expect(game.battleSummon(0, 3, spot: 0), isFalse, reason: 'no swaps left');

    // Knock one out: its place is filled for free.
    side.at(0)!.body!.currentHp = 0;
    game.update(1 / 60);
    expect(side.spots[0], isNull);
    expect(game.battleSummon(0, 3), isTrue);
    expect(side.swapsLeft, 0);
    expect(side.spots[0], 3);
  });

  test('a double fall brings the bench out; the last fall loses', () async {
    final (game, home) = await battleArena();
    final b = game.startBattle(
      home: [
        battleMember('Wing', 'Air'),
        battleMember('Pip', 'Fire'),
        battleMember('Horn', 'Earth'),
        battleMember('Kin', 'Water'),
      ],
      away: [battleMember('Horn', 'Fire'), battleMember('Mane', 'Lava')],
      center: home,
    );
    runBattle(game, limit: 1.0);
    final side = b.sides[0];
    for (final c in side.onField.toList()) {
      c.body!.currentHp = 0;
    }
    game.update(1 / 60);
    expect(side.anyOnField, isFalse);
    expect(b.over, isFalse, reason: 'the bench is still to come out');

    // Both places are filled together, a moment later.
    for (var i = 0; i < 60 && side.spots.contains(null); i++) {
      game.update(1 / 60);
    }
    expect(b.over, isFalse);
    expect(side.spots.toSet(), {2, 3});
    expect(side.bench, isEmpty);

    // The last two down: now it is over.
    runBattle(game, limit: 1.0);
    for (final c in side.onField.toList()) {
      c.body!.currentHp = 0;
    }
    game.update(1 / 60);
    expect(b.over, isTrue);
    expect(b.result!.winner, 1);
    expect(b.result!.end, BattleEnd.fieldEmpty);
  });

  test("a Fire kin's phoenix catches its teammate, once", () async {
    final (game, home) = await battleArena();
    final b = game.startBattle(
      home: [battleMember('Kin', 'Fire'), battleMember('Wing', 'Air')],
      away: [battleMember('Horn', 'Fire'), battleMember('Mane', 'Lava')],
      center: home,
    );
    runBattle(game, limit: 1.0);
    final wing = b.sides[0].at(1)!.body!;
    wing.currentHp = 0;
    game.update(1 / 60);
    expect(b.sides[0].spots[1], 1, reason: 'the wing is still on the field');
    expect(wing.currentHp, greaterThan(0));
    expect(b.log.where((e) => e.kind == BattleEventKind.phoenix), hasLength(1));
    wing.currentHp = 0;
    game.update(1 / 60);
    expect(b.sides[0].spots[1], isNull, reason: 'a phoenix fires once');
  });

  test('a focus is held until it is let go or its target leaves', () async {
    final (game, home) = await battleArena();
    final b = game.startBattle(
      home: [battleMember('Horn', 'Fire'), battleMember('Wing', 'Air')],
      away: [
        battleMember('Kin', 'Water'),
        battleMember('Pip', 'Earth'),
        battleMember('Mane', 'Lava'),
      ],
      center: home,
    );
    runBattle(game, limit: 1.0);
    expect(game.focusBattleTarget(0, 2), isFalse, reason: 'on the bench');
    expect(game.focusBattleTarget(0, 1), isTrue);
    expect(b.sides[0].focus, 1);
    expect(game.focusBattleTarget(0, 1), isTrue, reason: 'again lets go');
    expect(b.sides[0].focus, isNull);
    game.focusBattleTarget(0, 0);
    b.sides[1].at(0)!.body!.currentHp = 0;
    game.update(1 / 60);
    expect(b.sides[0].focus, isNull, reason: 'its target fell');
    // The computer picks a focus of its own.
    runBattle(game, limit: 1.0);
    expect(b.sides[1].focus, isNotNull);
  });

  test('overtime: the last 30 seconds trim heals and grow blows', () async {
    final (game, home) = await battleArena();
    // No blows at all, so only the blessing moves its health.
    final b = game.startBattle(
      home: [battleMember('Wing', 'Air')],
      away: [battleMember('Horn', 'Earth')],
      center: home,
      damageScale: 0,
    );
    runBattle(game, limit: 1.0);
    final wing = b.sides[0].at(0)!.body!;
    double healedOver(double seconds) {
      wing.currentHp = wing.maxHp ~/ 4;
      wing.blessingTimer = 10;
      // Big enough that whole points don't round the share away.
      wing.blessingHealPerTick = 150;
      final from = wing.currentHp;
      runBattle(game, limit: seconds);
      return (wing.currentHp - from).toDouble();
    }

    final before = healedOver(2);
    expect(before, greaterThan(0));
    expect(b.inOvertime, isFalse);
    b.clock = kBattleOvertime.at + 1;
    final during = healedOver(2);
    expect(b.inOvertime, isTrue);
    expect(during / before, closeTo(kBattleOvertime.heal, 0.05));

    // Blows rise to the overtime's full weight at the limit.
    final c = game.startBattle(
      home: [battleMember('Wing', 'Air')],
      away: [battleMember('Horn', 'Earth')],
      center: home,
    );
    expect(c.damageNow, kBattleDamageScale);
    c.clock = kBattleOvertime.at;
    expect(c.damageNow, kBattleDamageScale);
    c.clock = kBattleTimeLimit;
    expect(
      c.damageNow,
      closeTo(kBattleDamageScale * kBattleOvertime.damage, 1e-9),
    );
  });
}
