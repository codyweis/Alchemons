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
  // The pip holds the broken main. Nothing in this room agrees with the sky
  // until it does, so every test that is not ABOUT the spout starts plugged.
  plugSpout(g);
  g.update(1 / 60); // the moon reconciles with the standing water
  return g;
}

/// Stand the Water pip in the mouth of the broken main.
void plugSpout(PlanetDungeonGame g) {
  final valve = g.layout.rooms['moon_well']!.tideValves
      .firstWhere((v) => v.pipOnly);
  final pip = g.creatures.firstWhere((c) => c.member.element == 'Water');
  pip
    ..position = valve.position
    ..lastSafe = valve.position;
}

/// Settle the water where the moon is calling it, the way waiting does.
void settleWell(PlanetDungeonGame g) {
  for (var i = 0; i < 60 * 8; i++) {
    if (g.wellAgreesWithMoon) return;
    g.update(1 / 60);
    g.moonWaxT = 0; // hold the sky still while the water catches up
  }
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

/// A working order: the basins the RISE will drown, first.
///
/// Two of the four sit at the top of their band, so once the ice displaces
/// enough water their stand is out of reach. Those two have to be taken while
/// the well is still low; the other two are safe at any point.
List<String> validOrder(PlanetDungeonGame g) {
  final ids = g.poolWants.keys.toList();
  bool fragile(String id) =>
      moonStandForLocks(g.poolWants[id]!, kMoonRiseAfterLocks) !=
      moonStandFor(g.poolWants[id]!);
  return [
    ...ids.where(fragile),
    ...ids.where((id) => !fragile(id)),
  ];
}

/// Freeze [id]: bring the moon to it, let the well settle, and lay the ice.
void takeBasin(PlanetDungeonGame g, String id) {
  g.moonNotch = g.poolWants[id]!;
  plugSpout(g);
  settleWell(g);
  g.moonHoldT = 99;
  _pressAt(g, 'Ice', _poolAt(g, id));
}

Offset _poolAt(PlanetDungeonGame g, String id) => g.currentRoom.moonPools
    .firstWhere((p) => p.id == id)
    .position;

void main() {
  group('the roll', () {
    test('all four basins listen, and no two want the same moon', () {
      for (var run = 0; run < 60; run++) {
        final g = _well();
        expect(g.poolWants, hasLength(4));
        expect(
          g.poolWants.values.toSet(),
          hasLength(4),
          reason: 'four basins asking for the same moon is one basin',
        );
        for (final n in g.poolWants.values) {
          expect(
            n,
            inInclusiveRange(1, 5),
            reason: 'never 0 or 6 — the drift PARKS there, and a target you '
                'hold by doing nothing is not a target',
          );
        }
      }
    });

    test('which basin wants which is not the same every run', () {
      final seen = {
        for (var i = 0; i < 60; i++)
          _well().poolWants.entries.map((e) => '${e.key}=${e.value}').join(),
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
    test('the wrong moon costs nothing at all', () {
      // The cruelty this design removed: the old false pool SHATTERED and
      // threw fury wisps, which made a wrong guess in a finale expensive.
      // Every basin listens now, so the only wrong answer is the wrong moon,
      // and it must still be free.
      final g = _well();
      final id = g.poolWants.keys.first;
      g.moonNotch = g.poolWants.values.firstWhere((n) => n != g.poolWants[id]);
      g.moonHoldT = 99;
      settleWell(g);
      _pressAt(g, 'Ice', _poolAt(g, id));
      expect(g.poolStates[id] ?? 0, 0);
      expect(g.combatEnemies.where((e) => !e.isDead), isEmpty);
      expect(g.creatures.every((c) => c.alive), isTrue);
    });

    test('a moon still in motion is refused — it must SIT', () {
      final g = _well();
      final id = g.poolWants.keys.first;
      g.moonNotch = g.poolWants[id]!;
      settleWell(g);
      g.moonHoldT = 0;
      _pressAt(g, 'Ice', _poolAt(g, id));
      expect(g.poolStates[id] ?? 0, 0);
      g.moonHoldT = 99;
      plugSpout(g);
      _pressAt(g, 'Ice', _poolAt(g, id));
      expect(g.poolStates[id], 1);
    });

    test('all four locked wakes the deep, and it sends something up', () {
      final g = _well();
      for (final id in validOrder(g)) {
        takeBasin(g, id);
        expect(g.poolStates[id], 1, reason: 'basin $id');
      }
      expect(g.moonBridgeWhole, isTrue);
      expect(g.guardianAwake, isTrue);
      final wardens = g.combatEnemies.where((e) => !e.isDead && e.isElite);
      expect(
        wardens.length,
        greaterThanOrEqualTo(3),
        reason: 'the fourth basin brings the deep up, not three more wisps',
      );
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

  group('the mirror room says the middle water matters', () {
    // The Frozen Moon only exists at a settled mid tide, and nothing in the
    // room said so: the glint is deliberately faint (it is a secret), so
    // walking in at mid looked almost identical to walking in at low. The
    // moon drops a shaft onto the pool at the middle water now — no words,
    // no naming, just a room that is plainly lit at one stand and not the
    // others. This pins the value that drives it.
    PlanetDungeonGame mirror() {
      final g = _well();
      g.currentRoomId = 'reflection_court';
      return g;
    }

    test('it is brightest at the middle and dark at both ends', () {
      final g = mirror();
      g.tideAnim = 0.5;
      expect(g.tideMidness, closeTo(1.0, 0.001));
      g.tideAnim = 0.0;
      expect(g.tideMidness, closeTo(0.0, 0.001));
      g.tideAnim = 1.0;
      expect(g.tideMidness, closeTo(0.0, 0.001));
    });

    test('and it eases rather than snapping at a threshold', () {
      // A tell that appears in one frame reads as a bug; one that swells as
      // the water eases reads as the moon finding the room.
      final g = mirror();
      double at(double a) {
        g.tideAnim = a;
        return g.tideMidness;
      }
      var prev = at(0.0);
      for (var a = 0.05; a <= 0.5; a += 0.05) {
        final now = at(a);
        expect(now, greaterThan(prev), reason: 'rising toward the middle');
        prev = now;
      }
    });

    test('the glint only exists where the light does', () {
      final g = mirror();
      g.tideLevel = 1;
      g.tideAnim = 0.5;
      expect(g.frozenMoonGlint(), isNotNull);
      expect(g.tideMidness, greaterThan(0.9));
      g.tideLevel = 0;
      g.tideAnim = 0.0;
      expect(g.frozenMoonGlint(), isNull);
      expect(g.tideMidness, lessThan(0.1));
    });
  });


  group('the broken main', () {
    test('only a Water pip plugs it, and only by standing there', () {
      final g = _well();
      final mouth = g.currentRoom.tideValves.firstWhere((v) => v.pipOnly);
      // Everyone else standing in the mouth does nothing at all.
      for (final e in ['Spirit', 'Ice']) {
        final c = _of(g, e);
        c.position = mouth.position;
        _of(g, 'Water').position = g.currentRoom.bounds.center;
        g.update(1 / 60);
        expect(g.spoutPlugged, isFalse, reason: '$e does not fit the mouth');
        c.position = g.currentRoom.bounds.center;
      }
      plugSpout(g);
      g.update(1 / 60);
      expect(g.spoutPlugged, isTrue);
    });

    test('it opens the moment the pip walks away', () {
      // A PLACE, not a switch. The pip is pinned for the whole rite, which
      // is the point: two creatures do the walking, not three.
      final g = _well();
      g.update(1 / 60);
      expect(g.spoutPlugged, isTrue);
      _of(g, 'Water').position = g.currentRoom.bounds.center;
      g.update(1 / 60);
      expect(g.spoutPlugged, isFalse);
    });

    test('while it runs the well stands above the moon', () {
      final g = _well();
      _of(g, 'Water').position = g.currentRoom.bounds.center;
      g.update(1 / 60);
      for (var n = 0; n <= 4; n++) {
        g.moonNotch = n;
        expect(
          g.wellStand,
          greaterThan(moonStandFor(n)),
          reason: 'the running main holds the water a stand high',
        );
      }
      plugSpout(g);
      g.update(1 / 60);
      for (var n = 0; n <= 6; n++) {
        g.moonNotch = n;
        expect(g.wellStand, moonStandFor(n));
      }
    });
  });

  group('the moon is drawn continuously', () {
    test('the phase slides toward the notch instead of snapping to it', () {
      final g = _well();
      g.moonNotch = 6;
      final start = g.moonPhaseAnim;
      expect(start, lessThan(0.9), reason: 'it begins where it was');
      g.update(1 / 60);
      final oneFrame = g.moonPhaseAnim;
      expect(oneFrame, greaterThan(start));
      expect(
        oneFrame,
        lessThan(1.0),
        reason: 'one frame must not arrive — that is the snap this removed',
      );
      for (var i = 0; i < 60 * 3; i++) {
        g.update(1 / 60);
      }
      expect(g.moonPhaseAnim, closeTo(1.0, 0.02));
    });

    test('it keeps sliding between notches, not only at them', () {
      // The face must move while the sky is waxing, or the moon reads as a
      // dial with seven pictures on it.
      final g = _well();
      g.moonNotch = 2;
      for (var i = 0; i < 120; i++) {
        g.update(1 / 60);
      }
      final held = g.moonNotch;
      final a = g.moonPhaseAnim;
      for (var i = 0; i < 30; i++) {
        g.update(1 / 60);
      }
      if (g.moonNotch == held) {
        expect(
          g.moonPhaseAnim,
          isNot(closeTo(a, 0.0005)),
          reason: 'the face moves between notches too',
        );
      }
    });
  });

  group('the stilled mirror', () {
    PlanetDungeonGame mirrorAtMid() {
      final g = _well();
      g.currentRoomId = 'reflection_court';
      g.tideLevel = 1;
      g.tideAnim = 0.5;
      for (final c in g.creatures) {
        c.position = const Offset(320, 330);
      }
      return g;
    }

    test('a moving moon cannot be frozen', () {
      final g = mirrorAtMid();
      g.update(1 / 60);
      expect(g.mirrorIsGlass, isFalse);
      final glint = g.frozenMoonGlint()!;
      _pressAt(g, 'Ice', glint);
      expect(g.discoveredClouds, isNot(contains(kWaterFrozenMoonEggId)));
      expect(g.riteActive, isFalse);
    });

    test('standing still in the pool flattens it, and the moon comes to rest',
        () {
      final g = mirrorAtMid();
      for (var i = 0; i < 60 * 5; i++) {
        g.update(1 / 60);
      }
      expect(g.mirrorIsGlass, isTrue);
      expect(
        (g.frozenMoonGlint()! - const Offset(320, 330)).distance,
        lessThan(6),
        reason: 'on glass the moon stops running',
      );
      _pressAt(g, 'Ice', g.frozenMoonGlint()!);
      expect(g.riteActive, isTrue, reason: 'and now it can be taken');
    });

    test('moving breaks it — the water has to be LEFT alone', () {
      final g = mirrorAtMid();
      for (var i = 0; i < 60 * 2; i++) {
        g.update(1 / 60);
      }
      expect(g.mirrorStillT, greaterThan(1.0));
      _of(g, 'Water').position = const Offset(300, 330);
      g.update(1 / 60);
      expect(g.mirrorStillT, 0, reason: 'a step resets the stilling');
    });

    test('and it only stills at the middle water', () {
      final g = mirrorAtMid();
      g.tideLevel = 0;
      g.tideAnim = 0.0;
      for (var i = 0; i < 60 * 5; i++) {
        g.update(1 / 60);
      }
      expect(g.mirrorIsGlass, isFalse);
    });
  });


  group('the ice raises the well, and that is the puzzle', () {
    test('exactly two of the four are drowned by the rise', () {
      // The shape of the decision. One would be trivial, three would leave
      // nothing free, and four would be unsolvable.
      for (var run = 0; run < 40; run++) {
        final g = _well();
        final fragile = g.poolWants.entries
            .where(
              (e) =>
                  moonStandForLocks(e.value, kMoonRiseAfterLocks) !=
                  moonStandFor(e.value),
            )
            .length;
        expect(fragile, 2, reason: 'two constrained, two free');
      }
    });

    test('taking the fragile pair first always works', () {
      for (var run = 0; run < 20; run++) {
        final g = _well();
        for (final id in validOrder(g)) {
          takeBasin(g, id);
          expect(g.poolStates[id], 1, reason: 'run $run, basin $id');
        }
        expect(g.moonBridgeWhole, isTrue);
      }
    });

    test('taking the free pair first drowns the other two', () {
      final g = _well();
      final order = validOrder(g);
      final free = order.sublist(2);
      final fragile = order.sublist(0, 2);
      for (final id in free) {
        takeBasin(g, id);
        expect(g.poolStates[id], 1);
      }
      expect(g.wellHasRisen, isTrue);
      for (final id in fragile) {
        expect(g.basinDrowned(id), isTrue, reason: '$id is out of reach now');
        takeBasin(g, id);
        expect(g.poolStates[id] ?? 0, 0, reason: 'and it refuses');
      }
      // …and it costs nothing but the walk.
      expect(g.combatEnemies.where((e) => !e.isDead), isEmpty);
      expect(g.creatures.every((c) => c.alive), isTrue);
    });

    test('breaking the ice brings the well back down — nothing can strand',
        () {
      // The anti-strand argument, walked: get it wrong, undo, get it right.
      final g = _well();
      final order = validOrder(g);
      for (final id in order.sublist(2)) {
        takeBasin(g, id);
      }
      expect(g.basinDrowned(order.first), isTrue);

      // Break them open. Ice on frozen ice cracks it, and the well drops.
      //
      // BOTH have to go: the fragile pair can only be locks #1 and #2, so a
      // run that froze the free pair first has to unwind all the way. That is
      // the cost of the wrong order, and it is a walk rather than a run.
      for (final id in order.sublist(2)) {
        _pressAt(g, 'Ice', _poolAt(g, id));
        expect(g.poolStates[id] ?? 0, 0, reason: 'the ice gives on $id');
      }
      expect(g.wellHasRisen, isFalse);
      expect(g.basinDrowned(order.first), isFalse, reason: 'reachable again');

      // And now the whole rite completes from here.
      for (final id in order) {
        takeBasin(g, id);
        expect(g.poolStates[id], 1, reason: 'basin $id after the recovery');
      }
      expect(g.moonBridgeWhole, isTrue);
    });

    test('the wardens come up once, however many times you re-freeze', () {
      final g = _well();
      for (final id in validOrder(g)) {
        takeBasin(g, id);
      }
      expect(
        g.combatEnemies.where((e) => e.isElite).length,
        greaterThanOrEqualTo(3),
      );
      final before = g.combatEnemies.length;
      final id = validOrder(g).last;
      _pressAt(g, 'Ice', _poolAt(g, id)); // break
      takeBasin(g, id); // and re-freeze
      expect(
        g.combatEnemies.length,
        lessThanOrEqualTo(before),
        reason: 'the deep does not send a second escort',
      );
    });
  });

}
