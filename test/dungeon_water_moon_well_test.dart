// Water Star 3 — the moon well.
//
// What this replaced was four pools, two of them true, frozen at settled mid
// tide: you read the room, you picked two, you were done. The moon well is a
// live balancing act instead, and the things worth pinning are the ones that
// decide whether it is playable rather than merely present.
//
//   The roll must always give a pair that pulls in OPPOSITE directions, or
//   the room is one target held twice.
//   The moon must be reachable in both directions from anywhere, forever, or
//   a run can strand in a finale.
//   A deaf basin must cost NOTHING — the shattering false pool is the exact
//   cruelty this design set out to remove.
//   And the three hands must stay three: the still must never move the moon.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _m(String e, String f) => CosmicPartyMember(
  instanceId: '$e$f',
  baseId: 'b',
  displayName: '$e $f',
  imagePath: null,
  element: e,
  family: f,
  level: 10,
  statSpeed: 4,
  statIntelligence: 4,
  statStrength: 4,
  statBeauty: 4,
  slotIndex: -1,
  staminaBars: 9,
  staminaMax: 9,
);

/// Water's ideal trio, standing in the well with the rite unlocked.
PlanetDungeonGame _well() {
  final party = [
    _m('Water', 'pip'),
    _m('Spirit', 'mask'),
    _m('Ice', 'mane'),
  ];
  final g = PlanetDungeonGame(
    element: 'Water',
    party: party,
    initialStarMask: (1 << 0) | (1 << 1),
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  // onLoad never runs headless, so the rite gate has to be opened by hand.
  g.starMask = (1 << 0) | (1 << 1);
  g.currentRoomId = 'moon_well';
  final at = g.currentRoom.bounds.center;
  for (final m in party) {
    g.creatures.add(DungeonCreature(member: m)..position = at..lastSafe = at);
  }
  g.onGameResize(Vector2(412, 915));
  g.update(1 / 60); // the moon reconciles with the standing water
  return g;
}

DungeonCreature _of(PlanetDungeonGame g, String element) =>
    g.creatures.firstWhere((c) => c.member.element == element);

void _pressAt(PlanetDungeonGame g, String element, Offset at) {
  final c = _of(g, element);
  g.activeIndex = g.creatures.indexOf(c);
  c
    ..position = at
    ..lastSafe = at;
  g.activateAbility();
}

Offset _poolAt(PlanetDungeonGame g, String id) => g.currentRoom.moonPools
    .firstWhere((p) => p.id == id)
    .position;

void main() {
  group('the roll', () {
    test('two basins listen, and they pull opposite ways', () {
      for (var run = 0; run < 60; run++) {
        final g = _well();
        expect(g.poolWants, hasLength(2));
        final v = g.poolWants.values.toList();
        expect(
          (v.first - v.last).abs(),
          greaterThanOrEqualTo(2),
          reason: 'a pair one notch apart is one target held twice',
        );
        for (final n in v) {
          expect(
            n,
            inInclusiveRange(1, 5),
            reason: 'never 0 or 6 — the drift PARKS there, and a target you '
                'hold by doing nothing is not a target',
          );
        }
      }
    });

    test('it is not the same two basins every run', () {
      final seen = {
        for (var i = 0; i < 60; i++)
          (_well().poolWants.keys.toList()..sort()).join(),
      };
      expect(seen.length, greaterThan(1), reason: 'rolled, not authored');
    });
  });

  group('the moon', () {
    test('the sky waxes it, and never stops', () {
      final g = _well();
      final start = g.moonNotch;
      for (var i = 0; i < 60 * 6; i++) {
        g.update(1 / 60);
      }
      expect(g.moonNotch, greaterThan(start));
    });

    test('it parks at full rather than wrapping round to dark', () {
      // Wrapping would make the drift a way of REACHING a low notch, which
      // would quietly remove Spirit from the room.
      final g = _well();
      for (var i = 0; i < 60 * 60; i++) {
        g.update(1 / 60);
      }
      expect(g.moonNotch, 6);
    });

    test('only Spirit moves it, and only backwards', () {
      final g = _well();
      final dial = g.currentRoom.moonDial!;
      final start = g.moonNotch;
      for (final e in ['Water', 'Ice']) {
        _pressAt(g, e, dial);
        expect(g.moonNotch, start, reason: '$e has no purchase on the moon');
      }
      _pressAt(g, 'Spirit', dial);
      expect(g.moonNotch, start - 1);
    });

    test('every notch is reachable from every notch, forever', () {
      // The no-strand argument. Spirit walks it down, the sky walks it up, so
      // no state in this room can be a dead end.
      for (var from = 0; from <= 6; from++) {
        for (var to = 0; to <= 6; to++) {
          final g = _well();
          g.moonNotch = from;
          final dial = g.currentRoom.moonDial!;
          var guard = 0;
          while (g.moonNotch != to && guard++ < 5000) {
            if (g.moonNotch > to) {
              _pressAt(g, 'Spirit', dial);
            } else {
              g.update(1 / 60);
            }
          }
          expect(g.moonNotch, to, reason: '$from → $to');
        }
      }
    });
  });

  group('the basins', () {
    test('a deaf basin costs nothing at all', () {
      // The cruelty this design removed: the old false pool SHATTERED and
      // threw fury wisps, which made a wrong guess in a finale expensive.
      final g = _well();
      final deaf = g.currentRoom.moonPools
          .map((p) => p.id)
          .firstWhere((id) => !g.poolWants.containsKey(id));
      _pressAt(g, 'Ice', _poolAt(g, deaf));
      expect(g.poolStates[deaf] ?? 0, 0);
      expect(g.combatEnemies.where((e) => !e.isDead), isEmpty);
      expect(g.creatures.every((c) => c.alive), isTrue);
    });

    test('the wrong moon is refused, and costs nothing either', () {
      final g = _well();
      final id = g.poolWants.keys.first;
      g.moonNotch = (g.poolWants[id]! + 2).clamp(0, 6);
      g.moonHoldT = 99;
      _pressAt(g, 'Ice', _poolAt(g, id));
      expect(g.poolStates[id] ?? 0, 0);
      expect(g.combatEnemies.where((e) => !e.isDead), isEmpty);
    });

    test('a moon still in motion is refused — it must SIT', () {
      final g = _well();
      final id = g.poolWants.keys.first;
      g.moonNotch = g.poolWants[id]!;
      g.moonHoldT = 0;
      _pressAt(g, 'Ice', _poolAt(g, id));
      expect(g.poolStates[id] ?? 0, 0);
      g.moonHoldT = 99;
      _pressAt(g, 'Ice', _poolAt(g, id));
      expect(g.poolStates[id], 1);
    });

    test('both locked wakes the deep', () {
      final g = _well();
      for (final e in g.poolWants.entries) {
        g.moonNotch = e.value;
        g.moonHoldT = 99;
        _pressAt(g, 'Ice', _poolAt(g, e.key));
      }
      expect(g.moonBridgeWhole, isTrue);
      expect(g.guardianAwake, isTrue);
    });
  });

  test('the moon takes the standing water when you walk in', () {
    // The well can be entered at any stand, because the tide is temple-wide
    // and set three rooms away. A moon that disagreed with it dragged the
    // water to a new stand on its first wax, without anyone touching a thing.
    for (final stand in [0, 1, 2]) {
      final g = _well();
      g.currentRoomId = 'drowned_court';
      g.update(1 / 60);
      g.tideLevel = stand;
      g.currentRoomId = 'moon_well';
      g.update(1 / 60);
      expect(
        moonStandFor(g.moonNotch),
        stand,
        reason: 'the moon and the water agree from the first frame',
      );
    }
  });
}
