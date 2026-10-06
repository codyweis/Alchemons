// The Blood Rites, played through the real game object: the stick, the pad
// and the doors, room by room, with the plans the prototype proved — then
// the stars, the rite, the vault, the maxim and Sanguorath's four shells.

import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart'
    show CosmicSurvivalCompanion;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_blood_rites.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_blood.dart';
import 'package:alchemons/games/shared/alchemon_combat_stats.dart';
import 'package:flutter/painting.dart' show Offset;
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _blood() => CosmicPartyMember(
  instanceId: 'inst_0',
  baseId: 'base_0',
  displayName: 'Blood Mane',
  element: 'Blood',
  family: 'mane',
  level: 10,
  statSpeed: 3,
  statIntelligence: 3,
  statStrength: 3,
  statBeauty: 3,
  slotIndex: 0,
  staminaBars: 3,
  staminaMax: 3,
);

PlanetDungeonGame harness({
  int stars = 0,
  void Function(int)? onStar,
  void Function(String)? onCloud,
}) {
  final party = [_blood()];
  final game = PlanetDungeonGame(
    element: 'Blood',
    party: party,
    initialStarMask: stars,
    onStarEarned: onStar ?? (_) {},
    onCloudDiscovered: onCloud,
    onPlayerDown: () {},
    onChanged: () {},
  );
  game.currentRoomId = game.layout.entranceRoomId;
  game.starMask = stars; // onLoad reads these; a headless run never loads
  for (final m in party) {
    final c = DungeonCreature(member: m)
      ..position = game.layout.entranceSpawn
      ..lastSafe = game.layout.entranceSpawn;
    game.creatures.add(c);
    final s = deriveAlchemonCombatStats(member: m);
    game.combatCompanions.add(
      CosmicSurvivalCompanion(
        member: m,
        slotIndex: m.slotIndex,
        position: c.position,
        anchor: c.position,
        maxHp: s.maxHp,
        currentHp: s.maxHp,
        physAtk: s.physAtk,
        elemAtk: s.elemAtk,
        abilityAtk: s.elemAtk,
        physDef: s.physDef,
        elemDef: s.elemDef,
        cooldownReduction: s.cooldownReduction,
        attackRange: s.attackRange,
        specialAbilityRange: s.specialAbilityRange,
        tethered: false,
        invincibleTimer: 0,
      ),
    );
  }
  game.update(1 / 60);
  return game;
}

void tick(PlanetDungeonGame g, [int n = 1]) {
  for (var i = 0; i < n; i++) {
    g.update(1 / 60);
  }
}

/// Take the door from the room we are in to [room].
void enter(PlanetDungeonGame g, String room) {
  final d = g.currentRoom.doors.firstWhere((d) => d.targetRoomId == room);
  g.passThroughDoor(d);
  tick(g, 2);
}

/// The rules' word for where things stand in the room we are in.
String where(PlanetDungeonGame g) => switch (g.currentRoom.rite?.kind) {
  RiteKind.earth => '${g.rites.earthAt}|${g.rites.earth.lines}',
  RiteKind.water => g.rites.water.key,
  RiteKind.fire => g.rites.fire.key,
  RiteKind.air => g.rites.air.key,
  _ => '${g.active!.position}',
};

/// Push the stick [dir] until the room's state changes, let go, and let the
/// room settle.
void walk(PlanetDungeonGame g, int dir) {
  final before = where(g);
  g.joystickDirection = Offset(kRiteDx[dir] * 1.0, kRiteDy[dir] * 1.0);
  for (var i = 0; i < 150; i++) {
    g.update(1 / 60);
    if (where(g) != before) break;
  }
  g.joystickDirection = Offset.zero;
  for (var i = 0; i < 90 && g.rites.waterFrames.isNotEmpty; i++) {
    g.update(1 / 60);
  }
  tick(g, 2);
}

int dirOf(String c) => 'NESW'.indexOf(c);

void main() {
  test('one Blood goes down alone', () {
    expect(kCosmicPlanetEntry['Blood'], ['Blood']);
    expect(bloodLayout.riddle, hasLength(1));
  });

  test('the four captive rooms open off the Circle at its compass points',
      () {
    final circle = bloodLayout.rooms['rite_circle']!;
    for (final el in kRiteElements) {
      expect(
        circle.doors.any((d) => d.targetRoomId == kRiteRoomOf[el]),
        isTrue,
        reason: el,
      );
    }
  });

  group('the rooms, played', () {
    test('WATER: the proved plan, with the stick and FLIP', () {
      final g = harness();
      enter(g, 'rite_water');
      expect(g.rites.water.b, kRiteArrival['Water']);
      expect(g.riteUtilityLabel, 'FLIP');
      for (final m in 'N N N N W W N W flip S S S W W flip W flip N'.split(' ')) {
        if (m == 'flip') {
          g.activateAbility();
          for (var i = 0; i < 200 && (g.rites.waterFrames.isNotEmpty || g.rites.flipT < 1); i++) {
            g.update(1 / 60);
          }
        } else {
          walk(g, dirOf(m));
        }
      }
      expect(flipSolved(g.rites.water), isTrue);
      expect(g.riteFreed, contains('Water'));
    });

    test('WATER: the vault is a dive through the flooded pit', () {
      final g = harness();
      enter(g, 'rite_water');
      for (final m in 'flip flip N W'.split(' ')) {
        if (m == 'flip') {
          g.activateAbility();
          for (var i = 0; i < 200 && (g.rites.waterFrames.isNotEmpty || g.rites.flipT < 1); i++) {
            g.update(1 / 60);
          }
        } else {
          walk(g, dirOf(m));
        }
      }
      final d = flipDiveFrom(g.rites.water);
      expect(d, greaterThanOrEqualTo(0));
      g.joystickDirection = Offset(kRiteDx[d] * 1.0, kRiteDy[d] * 1.0);
      for (var i = 0; i < 150 && g.currentRoomId == 'rite_water'; i++) {
        g.update(1 / 60);
      }
      g.joystickDirection = Offset.zero;
      expect(g.currentRoomId, 'rite_vault');
    });

    test('FIRE: the proved plan; a wall stops Blood and steps the twin', () {
      final g = harness();
      enter(g, 'rite_fire');
      expect(g.rites.fire.b, kRiteArrival['Fire']);
      // The first E: Blood is held by the shut gate, the twin walks west.
      final t0 = g.rites.fire.t;
      walk(g, 1);
      expect(g.rites.fire.b, kRiteArrival['Fire']);
      expect(g.rites.fire.t, (x: t0.x - 1, y: t0.y));
      for (final c in 'ESSSSENNNSWWWSSSSEEE'.split('')) {
        walk(g, dirOf(c));
      }
      expect(twinSolved(g.rites.fireRoom, g.rites.fire), isTrue);
      expect(g.riteFreed, contains('Fire'));
    });

    test('AIR: the proved plan, one flick per push', () {
      final g = harness();
      enter(g, 'rite_air');
      expect(g.rites.air.b, kRiteArrival['Air']);
      for (final c in 'NNWWENWSSWNESEENESS'.split('')) {
        final d = dirOf(c);
        g.joystickDirection = Offset(kRiteDx[d] * 1.0, kRiteDy[d] * 1.0);
        tick(g, 3);
        g.joystickDirection = Offset.zero;
        for (var i = 0; i < 120 && g.rites.driftT < 1; i++) {
          g.update(1 / 60);
        }
        tick(g, 2);
      }
      expect(driftSolved(g.rites.airRoom, g.rites.air), isTrue);
      expect(g.riteFreed, contains('Air'));
    });

    test('AIR: pushing out through the door from its square leaves', () {
      final g = harness();
      enter(g, 'rite_air');
      g.joystickDirection = const Offset(0, 1);
      tick(g, 3);
      g.joystickDirection = Offset.zero;
      tick(g, 2);
      expect(g.currentRoomId, 'rite_circle');
    });

    test('EARTH: turn both plates, then lead every tendril home', () {
      final g = harness();
      enter(g, 'rite_earth');
      final f = g.rites.earthFloor;
      expect(g.rites.earthAt, kRiteArrival['Earth']);

      // Walk Blood to [target] over floor (BFS over the current grid).
      void goTo(RiteCell target) {
        for (var guard = 0; guard < 60 && g.rites.earthAt != target; guard++) {
          final grid = f.grid(g.rites.earth.turns);
          final prev = <RiteCell, int>{};
          final q = [g.rites.earthAt];
          final seen = {g.rites.earthAt};
          while (q.isNotEmpty) {
            final c = q.removeAt(0);
            if (c == target) break;
            for (var d = 0; d < 4; d++) {
              final n = (x: c.x + kRiteDx[d], y: c.y + kRiteDy[d]);
              if (n.y < 0 || n.y >= f.h || n.x < 0 || n.x >= f.w) continue;
              if (grid[n.y][n.x] != '.' || seen.contains(n)) continue;
              seen.add(n);
              prev[n] = d;
              q.add(n);
            }
          }
          expect(prev.containsKey(target), isTrue, reason: 'no way to $target');
          var c = target;
          var first = prev[c]!;
          while (true) {
            final d = prev[c]!;
            final back = (x: c.x - kRiteDx[d], y: c.y - kRiteDy[d]);
            first = d;
            if (back == g.rites.earthAt) break;
            c = back;
          }
          walk(g, first);
        }
      }

      // Turn a plate from beside its axle.
      void turn(int i, int times) {
        final p = f.plates[i];
        for (var d = 0; d < 4; d++) {
          final s = (x: p.cx + kRiteDx[d], y: p.cy + kRiteDy[d]);
          final grid = f.grid(g.rites.earth.turns);
          if (grid[s.y][s.x] != '.') continue;
          goTo(s);
          break;
        }
        for (var k = 0; k < times; k++) {
          expect(g.riteUtilityLabel, anyOf('TURN', 'LEAD'));
          final before = g.rites.earth.turns[i];
          g.activateAbility();
          expect(g.rites.earth.turns[i], (before + 1) % 4);
          tick(g, 2);
        }
      }

      turn(0, 2);
      turn(1, 1);
      final paths = tendrilRoute(f, g.rites.earth.turns)!;
      for (final e in paths.entries) {
        final pts = e.value;
        goTo(pts[1]);
        // Face the root, then take it up.
        final dx = pts[0].x - pts[1].x, dy = pts[0].y - pts[1].y;
        g.active!.aimAngle = atan2(dy.toDouble(), dx.toDouble());
        expect(g.riteUtilityLabel, 'LEAD');
        g.activateAbility();
        expect(g.rites.leading, e.key);
        for (var k = 2; k < pts.length; k++) {
          final d = [
            for (var dd = 0; dd < 4; dd++)
              if (pts[k - 1].x + kRiteDx[dd] == pts[k].x &&
                  pts[k - 1].y + kRiteDy[dd] == pts[k].y)
                dd,
          ].single;
          walk(g, d);
        }
        expect(g.rites.leading, isNull, reason: '${e.key} joined');
      }
      expect(tendrilSolved(f, g.rites.earth), isTrue);
      expect(g.riteFreed, contains('Earth'));
    });
  });

  group('the Circle', () {
    test('all four freed: both stars, every cup, and Sanguorath wakes', () {
      final stars = <int>[];
      final g = harness(onStar: stars.add);
      for (final el in kRiteElements) {
        g.discoveredClouds.add(riteFreedId(el));
      }
      // The last one freed in play banks the pair.
      g.discoveredClouds.remove(riteFreedId('Air'));
      enter(g, 'rite_air');
      for (final c in 'NNWWENWSSWNESEENESS'.split('')) {
        final d = dirOf(c);
        g.joystickDirection = Offset(kRiteDx[d] * 1.0, kRiteDy[d] * 1.0);
        tick(g, 3);
        g.joystickDirection = Offset.zero;
        for (var i = 0; i < 120 && g.rites.driftT < 1; i++) {
          g.update(1 / 60);
        }
        tick(g, 2);
      }
      expect(stars, containsAll([0, 1]));
      enter(g, 'rite_circle');
      tick(g, 3);
      expect(g.rites.cups, hasLength(4));
      expect(g.guardianAwake, isTrue);
    });

    test('a ring turns from its band; two streams make a fusion; all four '
        'the quintessence', () {
      final g = harness(stars: 3);
      tick(g, 2);
      expect(g.rites.cups, hasLength(4));
      // Stand on the outer band.
      g.active!.position = kRiteCircleCentre + const Offset(0, 262);
      tick(g);
      expect(g.riteUtilityLabel, 'TURN');
      g.activateAbility();
      expect(g.rites.outerTurn, 1);
      // Now the inner band, once: all four meet.
      g.active!.position = kRiteCircleCentre + const Offset(0, 160);
      tick(g);
      g.activateAbility();
      expect(g.rites.innerTurn, 1);
      expect(
        riteCentre(g.riteFreed, g.rites.outerTurn, g.rites.innerTurn).kind,
        RiteCentreKind.quintessence,
      );
      tick(g, 2);
      expect(g.debugMaximPending, kBloodEggId);
    });
  });

  group('Sanguorath', () {
    Future<PlanetDungeonGame> arena() async {
      final g = harness(stars: 3);
      await g.debugLoadRiteAllies();
      tick(g, 2);
      g.guardianAwake = true;
      enter(g, 'sanguorath_heart');
      // The four come down with Blood.
      expect(g.creatures, hasLength(5));
      for (var i = 0; i < 400 && g.debugGuardianBody == null; i++) {
        g.update(1 / 60);
      }
      expect(g.debugGuardianBody, isNotNull);
      return g;
    }

    test('it shells at 80%: no hit gets past, and nothing lands', () async {
      final g = await arena();
      final b = g.debugGuardianBody!;
      b.hp = b.maxHp * .81;
      g.debugDamageEnemy(b, b.maxHp * .5);
      expect(b.hp, closeTo(b.maxHp * .8, 1e-6));
      tick(g);
      expect(g.rites.shellUp, isTrue);
      expect(kRiteElements, contains(g.rites.shellElement));
      final hp = b.hp;
      g.debugDamageEnemy(b, b.maxHp * .5);
      expect(b.hp, hp);
    });

    test('the wrong ally is thrown back and it mends; the right one gives '
        'itself; after four, Blood alone', () async {
      final g = await arena();
      final b = g.debugGuardianBody!;
      for (var round = 0; round < 4; round++) {
        // A refused ally can't be refused again for a moment.
        tick(g, 100);
        b.hp = b.maxHp * kRiteShellAt[round];
        tick(g);
        expect(g.rites.shellUp, isTrue);
        final want = kRiteOpposite[g.rites.shellElement]!;
        final wrong = g.creatures.where(
          (c) => c.member.element != 'Blood' && c.member.element != want,
        );
        if (wrong.isNotEmpty) {
          final before = b.hp;
          wrong.first.position = b.position;
          tick(g);
          expect(b.hp, greaterThan(before));
          expect(g.rites.shellUp, isTrue);
          expect(g.creatures.contains(wrong.first), isTrue);
        }
        final right = g.creatures.firstWhere((c) => c.member.element == want);
        right.position = b.position;
        tick(g);
        expect(g.rites.shellUp, isFalse);
        expect(g.creatures.contains(right), isFalse);
      }
      expect(g.creatures, hasLength(1));
      expect(g.creatures.single.member.element, 'Blood');
      expect(g.rites.shellsBroken, 4);
    });
  });
}
