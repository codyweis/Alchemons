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
import 'package:flame/game.dart' show Vector2;
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
  for (var i = 0; i < 600 && g.rites.waterFrames.isNotEmpty; i++) {
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

  test('the four captive rooms open off the Circle at its compass points', () {
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
      for (final m in 'N N N N W W N W flip S S S W W flip W flip N'.split(
        ' ',
      )) {
        if (m == 'flip') {
          g.activateAbility();
          for (
            var i = 0;
            i < 600 && (g.rites.waterFrames.isNotEmpty || g.rites.flipT < 1);
            i++
          ) {
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
          for (
            var i = 0;
            i < 600 && (g.rites.waterFrames.isNotEmpty || g.rites.flipT < 1);
            i++
          ) {
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
      // Freed, every gate stands open: Blood walks back to the door (from
      // the solved squares it never could, with gate b held by nobody).
      for (final c in 'NNNNNWWW'.split('')) {
        walk(g, dirOf(c));
      }
      expect(g.rites.fire.b, kRiteArrival['Fire']);
      for (var i = 0; i < 4 && g.currentRoomId == 'rite_fire'; i++) {
        walk(g, dirOf('W'));
      }
      expect(g.currentRoomId, 'rite_circle', reason: 'and out');
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

  group('the polish (2026-10-06)', () {
    void flip(PlanetDungeonGame g) {
      g.activateAbility();
      for (
        var i = 0;
        i < 600 && (g.rites.waterFrames.isNotEmpty || g.rites.flipT < 1);
        i++
      ) {
        g.update(1 / 60);
      }
    }

    test('a captive room is played close, and shows itself whole only to '
        'show something', () {
      final g = harness();
      g.onGameResize(Vector2(916, 265)); // the Fold folded, landscape
      enter(g, 'rite_water');
      final b = g.currentRoom.bounds;
      // On the way in: the whole room, for a moment.
      expect(g.viewZoom, lessThan(.6));
      expect(b.height * g.viewZoom, lessThanOrEqualTo(265));
      tick(g, 150);
      expect(g.viewZoom, closeTo(1.0, .02), reason: 'then close on Blood');
      // A flip pulls back to the whole room while it turns and settles…
      g.activateAbility();
      tick(g, 40);
      expect(g.viewZoom, lessThan(.7));
      for (var i = 0; i < 600 && g.rites.waterFrames.isNotEmpty; i++) {
        g.update(1 / 60);
      }
      // …and closes in again after.
      tick(g, 150);
      expect(g.viewZoom, closeTo(1.0, .02));
    });

    test('FIRE: the twin\'s room holds still, every floor square in view',
        () {
      final g = harness();
      g.onGameResize(Vector2(916, 265)); // the Fold folded, landscape
      enter(g, 'rite_fire');
      tick(g, 150);
      final z = g.viewZoom;
      expect(z, lessThan(.7), reason: 'wider than the other rooms');
      expect(z, greaterThan(.5), reason: 'closer than the whole room');
      // Every floor square (rows 1–6) is on screen…
      final b = g.currentRoom.bounds;
      expect(g.worldToScreen(Offset(0, kRiteCell)).dy, greaterThanOrEqualTo(-1));
      expect(
        g.worldToScreen(Offset(0, b.height - kRiteCell)).dy,
        lessThanOrEqualTo(266),
      );
      // …and the camera doesn't move as the two walk apart.
      final cam = g.worldToScreen(Offset.zero);
      for (final c in 'ESSSS'.split('')) {
        walk(g, dirOf(c));
      }
      tick(g, 60);
      expect(g.viewZoom, closeTo(z, .01));
      expect((g.worldToScreen(Offset.zero) - cam).distance, lessThan(1));
    });

    test('the Water room turns before anything moves, and a fall takes its '
        'time', () {
      final g = harness();
      enter(g, 'rite_water');
      final before = g.rites.water.key;
      g.activateAbility();
      expect(g.rites.water.key, isNot(before)); // the rules settle at once
      var frames = 0;
      while (g.rites.waterFrames.isNotEmpty || g.rites.flipT < 1) {
        g.update(1 / 60);
        frames++;
        if (frames == 40) {
          // Still turning: nothing has slid yet.
          expect(g.rites.flipT, lessThan(1));
          expect(g.rites.waterFrom?.loose, isNotNull);
        }
        expect(frames, lessThan(600));
      }
      expect(frames / 60, greaterThan(2.0), reason: 'was 0.9s');
    });

    test('a jammed room never says so', () {
      final g = harness();
      enter(g, 'rite_water');
      // The commonest mistake: flip without thinking, flip back.
      flip(g);
      flip(g);
      for (var i = 0; i < 300; i++) {
        g.update(1 / 60);
        expect(g.hintText ?? '', isNot(contains('finished')));
        expect(g.hintText ?? '', isNot(contains('can\'t')));
      }
    });

    test('RESET ROOM: shown in a captive room, puts it back as it began; the '
        'first captive room says where it is, once', () {
      final g = harness();
      expect(g.riteResetShown, isFalse, reason: 'not in the Circle');
      enter(g, 'rite_water');
      expect(g.riteResetShown, isTrue);
      expect(g.discoveredClouds, contains('teach:rite_reset'));
      expect(g.hintText, contains('RESET ROOM'));
      expect(g.riteResetLit, isTrue);
      final start = g.rites.water.key;
      flip(g);
      expect(g.rites.water.key, isNot(start));
      g.resetRiteRoom();
      expect(g.rites.water.key, start);
      expect(g.riteResetLit, isFalse);
      // The next captive room doesn't say it again.
      enter(g, 'rite_circle');
      enter(g, 'rite_fire');
      expect(g.riteResetShown, isTrue);
      expect(g.hintText ?? '', isNot(contains('RESET ROOM')));
    });

    test('EARTH: HINT says the two element tendrils fuse at the captive', () {
      final g = harness();
      enter(g, 'rite_earth');
      g.askForRoomHint();
      expect(
        g.hintText,
        contains('Both element tendrils must reach the captive'),
      );
    });

    test('a wall stops Blood inside its own square, and shows itself', () {
      final g = harness();
      enter(g, 'rite_earth');
      walk(g, 3); // (6,1): the north wall is above it
      final at = g.rites.earthAt;
      expect(at, (x: 6, y: 1));
      g.joystickDirection = const Offset(0, -1);
      tick(g, 60);
      g.joystickDirection = Offset.zero;
      expect(g.rites.earthAt, at);
      final mid = riteCentreOf(at.x, at.y);
      expect(
        (g.active!.position - mid).distance,
        lessThanOrEqualTo(kRiteLean + 1),
      );
      expect(g.rites.bumpFrom, at);
      expect(g.rites.bumpDir, 0);
    });
  });

  group('the Circle', () {
    test('all four freed: the first star and every cup; the seal stays shut '
        'until the maxim is found, then opens on the Heart', () {
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
      expect(stars, [0], reason: 'the Heart is the second');
      enter(g, 'rite_circle');
      tick(g, 3);
      expect(g.rites.cups, hasLength(4));
      expect(g.guardianAwake, isFalse);
      final seal = g.currentRoom.doors.firstWhere((d) => d.targetRoomId == 'rite_heart');
      expect(g.isDoorHidden(g.currentRoom, seal), isTrue, reason: 'the maxim first');
      // Turn the rings until the four meet: the quintessence, the maxim, and
      // the seal opens.
      g.active!.position = kRiteCircleCentre + const Offset(0, 262);
      tick(g);
      g.activateAbility();
      g.active!.position = kRiteCircleCentre + const Offset(0, 160);
      tick(g);
      g.activateAbility();
      for (var i = 0; i < 900 && !g.discoveredClouds.contains(kBloodEggId); i++) {
        g.update(1 / 60);
      }
      expect(g.discoveredClouds, contains(kBloodEggId));
      tick(g, 2);
      expect(g.isDoorHidden(g.currentRoom, seal), isFalse);
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
      g.discoveredClouds.add(kRiteHeartFreedId);
      enter(g, 'rite_heart');
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
