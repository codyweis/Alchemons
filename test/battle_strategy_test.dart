// The battle's strategy rules (games/cosmic/cosmic_game_battle_status.dart):
// typing, a burn halving heals, poison over time and cured by the bench,
// a freeze holding back a special, and a Horn's taunt drawing the other
// side unless their player has picked a target.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/games/shared/battle_typing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'battle_test.dart' show battleArena, battleMember;

List<CosmicPartyMember> _four(List<String> specs, String tag) => [
  for (final (i, s) in specs.indexed)
    battleMember(s.split(':')[0], s.split(':')[1], stat: 4, id: '$tag$i$s'),
];

/// Runs [b] in [game] until [stop] or [seconds] of the fight.
void _run(
  CosmicGame game,
  CosmicBattle b, {
  double seconds = 90,
  bool Function()? stop,
}) {
  while (!b.over && b.clock < seconds) {
    if (stop?.call() ?? false) return;
    game.update(1 / 60);
  }
}

void main() {
  test('typing: the chart, softened; off is even', () {
    expect(battleTypeMultiplier('Water', 'Fire'), kBattleTypeStrong);
    expect(battleTypeMultiplier('Fire', 'Water'), kBattleTypeWeak);
    expect(battleTypeMultiplier('Fire', 'Fire'), 1);
    expect(battleTypeMultiplier('Dark', 'Light'), kBattleTypeStrong);
    expect(battleStrongAgainst('Fire'), containsAll(['Plant', 'Ice']));
    expect(battleWeakAgainst('Fire'), containsAll(['Water', 'Earth']));
    battleTypingOn = false;
    expect(battleTypeMultiplier('Water', 'Fire'), 1);
    battleTypingOn = true;
  });

  test(
    'typing moves the blows: up against the weak, down against the strong',
    () async {
      final (game, at) = await battleArena();
      final b = game.startBattle(
        home: _four([
          'Horn:Water',
          'Wing:Water',
          'Pip:Water',
          'Mane:Water',
        ], 'w'),
        away: _four(['Horn:Fire', 'Wing:Fire', 'Pip:Fire', 'Mane:Fire'], 'f'),
        homeAuto: true,
        center: at,
      );
      _run(game, b);
      // Water hits Fire harder; Fire hits Water softer.
      expect(b.counts.typeUp, greaterThan(0));
      expect(b.counts.typeDown, greaterThan(0));
    },
  );

  test(
    'a burn halves the heals it lands on, and the bench puts it out',
    () async {
      final (game, at) = await battleArena();
      final b = game.startBattle(
        home: _four(['Mane:Fire', 'Wing:Fire', 'Pip:Lava', 'Horn:Fire'], 'f'),
        away: _four(['Kin:Water', 'Kin:Light', 'Kin:Plant', 'Mask:Earth'], 'k'),
        homeAuto: true,
        center: at,
      );
      BattleCreature? burnt;
      _run(
        game,
        b,
        stop: () {
          for (final c in b.sides[1].onField) {
            if (c.burning) burnt = c;
          }
          return burnt != null && b.counts.healCut > 0;
        },
      );
      expect(b.counts.burns, greaterThan(0));
      expect(burnt, isNotNull);
      expect(
        b.counts.healCut,
        greaterThan(0),
        reason: 'a burning Kin was healed for less',
      );
      // Swapped out: no longer burning.
      final side = b.sides[1];
      final spot = side.spots.indexOf(side.creatures.indexOf(burnt!));
      final bench = side.bench.toList();
      if (spot >= 0 && bench.isNotEmpty && burnt!.body!.life > kBattleArrival) {
        expect(game.battleSummon(1, bench.first, spot: spot), isTrue);
        expect(burnt!.burning, isFalse);
      }
    },
  );

  test(
    'poison hurts over time, its giver credited, and the bench ends it',
    () async {
      final (game, at) = await battleArena();
      final b = game.startBattle(
        home: _four([
          'Pip:Poison',
          'Mane:Poison',
          'Wing:Poison',
          'Kin:Poison',
        ], 'p'),
        away: _four(['Horn:Earth', 'Let:Ice', 'Mask:Dust', 'Kin:Water'], 'e'),
        homeAuto: true,
        center: at,
      );
      BattleCreature? sick;
      _run(
        game,
        b,
        stop: () {
          for (final c in b.sides[1].onField) {
            if (c.poisoned && c.poisonDps > 0) sick = c;
          }
          return sick != null && b.counts.poisonHarm > 0;
        },
      );
      expect(sick, isNotNull);
      expect(b.counts.poisonHarm, greaterThan(0));
      // Over time: it keeps hurting with no new poison (a few frames on).
      final hpBefore = sick!.body!.currentHp + sick!.body!.shieldHp;
      final takenBefore = sick!.damageTaken;
      for (var i = 0; i < 30 && sick!.poisoned; i++) {
        game.update(1 / 60);
      }
      expect(sick!.damageTaken, greaterThanOrEqualTo(takenBefore));
      expect(
        (sick!.body?.currentHp ?? 0) + (sick!.body?.shieldHp ?? 0),
        lessThanOrEqualTo(hpBefore),
      );
      // What one side dealt is what the other side took, poison and all.
      final dealt = b.sides[0].creatures.fold(0.0, (s, c) => s + c.damageDealt);
      final taken = b.sides[1].creatures.fold(0.0, (s, c) => s + c.damageTaken);
      expect(dealt, closeTo(taken, taken * 0.02 + 2));
    },
  );

  test(
    'a freeze holds back the frozen one\'s special, not too often',
    () async {
      final (game, at) = await battleArena();
      final b = game.startBattle(
        home: _four(['Pip:Ice', 'Mane:Ice', 'Pip:Ice', 'Mane:Ice'], 'i'),
        away: _four(['Wing:Air', 'Horn:Fire', 'Let:Dust', 'Kin:Water'], 'a'),
        homeAuto: true,
        center: at,
      );
      _run(game, b, stop: () => b.counts.interrupts > 0);
      expect(b.counts.interrupts, greaterThan(0));
      final hit = b.sides[1].creatures.firstWhere((c) => c.interruptedAt >= 0);
      expect(hit.interruptGap, greaterThan(0));
    },
  );

  test(
    'a Horn\'s taunt draws the computer\'s side, never a player\'s pick',
    () async {
      // The other side picks its own target (the computer): taunts draw it.
      final (game, at) = await battleArena();
      final b = game.startBattle(
        home: _four(['Wing:Air', 'Mane:Water', 'Pip:Water', 'Let:Ice'], 'w'),
        away: _four([
          'Horn:Fire',
          'Horn:Earth',
          'Horn:Dark',
          'Horn:Light',
        ], 'h'),
        homeAuto: true,
        center: at,
      );
      _run(game, b, seconds: 40);
      expect(b.counts.tauntSeconds, greaterThan(0));

      // A player's side with a target picked: the taunt does not draw it.
      final (game2, at2) = await battleArena();
      final b2 = game2.startBattle(
        home: _four(['Wing:Air', 'Mane:Water', 'Pip:Water', 'Let:Ice'], 'w'),
        away: _four([
          'Horn:Fire',
          'Horn:Earth',
          'Horn:Dark',
          'Horn:Light',
        ], 'h'),
        homeAuto: false,
        awayAuto: false,
        center: at2,
      );
      var picked = 0.0, held = 0;
      while (!b2.over && b2.clock < 40) {
        // Always a target picked: the first of theirs that can be fought.
        final theirs = b2.sides[1].creatures.indexWhere(
          (c) => c.onField && c.body!.isAlive && c.body!.life >= kBattleArrival,
        );
        if (theirs >= 0 && b2.sides[0].focus != theirs) {
          game2.setBattleFocus(0, theirs);
        }
        final before = b2.counts.tauntSeconds;
        game2.update(1 / 60);
        // While the pick can be fought, nothing draws side 0 off it (side 1
        // has no taunts of side 0's to answer).
        if (theirs >= 0) {
          held++;
          picked += b2.counts.tauntSeconds - before;
        }
      }
      expect(held, greaterThan(60));
      expect(picked, 0);
    },
  );
}
