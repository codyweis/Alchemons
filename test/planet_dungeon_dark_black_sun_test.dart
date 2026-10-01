// NYTHRALOR — THE BLACK SUN. The rules, and the game playing by them.
//
// Every room was proved in the prototype (docs/prototypes/dark_portals) on
// these same maps. The first group replays each proved plan against the
// Dart rules from a fresh start and checks it ends where the proof said —
// so the game and the proof cannot drift. The rest drive the game object:
// a door takes only the body you steer, a portal joins two rooms, a pair of
// chambers banks a star, blood on the Great Seal wakes Noctryos, a light
// that does not end is the maxim, and the arena's enemies come out of black
// holes.

import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_companion_stats.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart'
    show CosmicSurvivalCompanion;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_dark.dart';
import 'package:flame/game.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';

import 'black_sun_plans.dart';

CosmicPartyMember _member(int slot, String element, String family) =>
    CosmicPartyMember(
      instanceId: 'inst_$slot',
      baseId: 'base_$slot',
      displayName: '$element $family',
      element: element,
      family: family,
      level: 10,
      statSpeed: 3,
      statIntelligence: 5,
      statStrength: 3,
      statBeauty: 3,
      slotIndex: slot,
      staminaBars: 3,
      staminaMax: 3,
    );

/// Dark · Dark · Light: slot 0 is the purple Dark, 1 the orange, 2 Light.
List<CosmicPartyMember> _trio() => [
  _member(0, 'Dark', 'mask'),
  _member(1, 'Dark', 'wing'),
  _member(2, 'Light', 'horn'),
];

const int purple = 0, orange = 1, light = 2;

PlanetDungeonGame harness({
  void Function(int)? onStar,
  void Function(String)? onCloud,
}) {
  final party = _trio();
  final game = PlanetDungeonGame(
    element: 'Dark',
    party: party,
    initialStarMask: 0,
    onStarEarned: onStar ?? (_) {},
    onCloudDiscovered: onCloud,
    onPlayerDown: () => fail('the scripted run must never wipe'),
    onChanged: () {},
  );
  game.currentRoomId = game.layout.entranceRoomId;
  for (final m in party) {
    final c = DungeonCreature(member: m)
      ..position = game.layout.entranceSpawn
      ..lastSafe = game.layout.entranceSpawn;
    game.creatures.add(c);
    final stats = deriveCosmicSurvivalCompanionStats(member: m);
    game.combatCompanions.add(
      CosmicSurvivalCompanion(
        member: m,
        slotIndex: m.slotIndex,
        position: c.position,
        anchor: c.position,
        maxHp: stats.maxHp,
        currentHp: stats.maxHp,
        physAtk: stats.physAtk,
        elemAtk: stats.elemAtk,
        abilityAtk: stats.elemAtk,
        physDef: stats.physDef,
        elemDef: stats.elemDef,
        cooldownReduction: stats.cooldownReduction,
        critChance: stats.critChance,
        attackRange: stats.attackRange,
        specialAbilityRange: stats.specialAbilityRange,
        tethered: false,
        invincibleTimer: 0,
      ),
    );
  }
  game.update(1 / 60);
  return game;
}

SunAt at(String room, int x, int y) => (room: room, x: x, y: y);
SunEnd face(String room, int x, int y, int d) =>
    (room: room, face: kSunRooms[room]!.faceAt(x, y, d)!);

/// Put the three where [pos] says (and their creatures on those squares).
void stage(
  PlanetDungeonGame g,
  Map<String, SunAt> pos, {
  Map<String, List<SunEnd?>>? ends,
  int shine = -1,
}) {
  g.blackSun.state = g.blackSun.state.copyWith(
    pos: pos,
    ends: ends ?? g.blackSun.state.ends,
    shine: shine,
  );
  const names = ['purple', 'orange', 'light'];
  for (var i = 0; i < 3; i++) {
    final p = pos[names[i]]!;
    g.creatures[i]
      ..position = sunCentre(p.x, p.y)
      ..lastSafe = sunCentre(p.x, p.y);
  }
}

/// Aim [who] the way [dir] points (0 north, 1 east, 2 south, 3 west).
void aim(PlanetDungeonGame g, int who, int dir) {
  g.creatures[who].aimAngle = const [-pi / 2, 0.0, pi / 2, pi][dir];
}

/// Push the stick [dir] until the active body's square changes (or it goes
/// through a portal), then let go.
void walk(PlanetDungeonGame g, int dir) {
  final who = g.blackSun.state.pos;
  final before = '${who.values.toList()}';
  g.joystickDirection = Offset(kSunDx[dir] * 1.0, kSunDy[dir] * 1.0);
  for (var i = 0; i < 120; i++) {
    g.update(1 / 60);
    if ('${g.blackSun.state.pos.values.toList()}' != before) break;
  }
  g.joystickDirection = Offset.zero;
}

void main() {
  // ── THE PROOFS, REPLAYED ────────────────────────────────
  group('every room\'s proved plan replays against the Dart rules', () {
    SunWorld only(String id, {Set<int> stars = const {}}) =>
        SunWorld(rooms: {id: kSunRooms[id]!}, stars: stars);

    SunState startIn(String id) {
      final d = kSunRooms[id]!;
      return SunState(
        pos: {
          for (var i = 0; i < 3; i++)
            kSunBodies[i]: (room: id, x: d.arrivals[i].x, y: d.arrivals[i].y),
        },
      );
    }

    bool allIn(SunState s, String room, bool Function(int x, int y) where) =>
        kSunBodies.every((n) {
          final p = s.pos[n]!;
          return p.room == room && where(p.x, p.y);
        });

    test('the porch: all three across, under the Hall door', () {
      final r = sunReplay(only('sun_porch'), startIn('sun_porch'), kBlackSunPlans['sun_porch']!);
      expect(r.failed, isNull);
      expect(allIn(r.state!, 'sun_porch', (x, y) => x >= 7), isTrue);
    });

    for (final id in const [
      'through_the_dark',
      'two_darks',
      'into_the_light',
      'hold_the_light',
    ]) {
      test('$id: all three on the gold', () {
        final r = sunReplay(only(id), startIn(id), kBlackSunPlans[id]!);
        expect(r.failed, isNull);
        expect(sunChamberSolved(kSunRooms[id]!, r.state!), isTrue);
      });
    }

    test('the Hall, its stars lit: out to the island and on to the far '
        'ledge', () {
      final r = sunReplay(
        only('sun_hall', stars: {0}),
        startIn('sun_hall'),
        kBlackSunPlans['sun_hall']!,
      );
      expect(r.failed, isNull);
      expect(allIn(r.state!, 'sun_hall', (x, y) => x >= 8 && y <= 2), isTrue);
    });

    test('the vault: cast from the bridge, fall, and walk in', () {
      final plan = kBlackSunPlans['sun_hall_vault']!;
      // The leap of faith: somewhere in it a Dark casts while standing over
      // the void, on a bridge — the only place the vault can be seen from.
      final w = only('sun_hall', stars: {0});
      var castFromVoid = false;
      for (var i = 0; i < plan.length; i++) {
        if (!plan[i].contains('casts')) continue;
        final before = sunReplay(w, startIn('sun_hall'), plan.sublist(0, i)).state!;
        final who = plan[i].split(' ').first;
        final p = before.pos[who]!;
        if (kSunHall.at(p.x, p.y) == '~') castFromVoid = true;
      }
      expect(castFromVoid, isTrue);
      final r = sunReplay(w, startIn('sun_hall'), plan);
      expect(r.failed, isNull);
      expect(
        kSunBodies.any((n) {
          final p = r.state!.pos[n]!;
          return p.x == kSunVault.x && p.y == kSunVault.y;
        }),
        isTrue,
      );
    });

    test('THE RITE, across two rooms: the Lantern\'s star carried down to '
        'the Great Seal, and Light comes down last through the dark', () {
      final w = SunWorld(
        rooms: {'sun_lantern': kSunLantern, 'sun_heart': kSunHeart},
        links: [
          for (final l in kSunLinks)
            if ({'sun_lantern', 'sun_heart'}.contains(l.room) &&
                {'sun_lantern', 'sun_heart'}.contains(l.to))
              l,
        ],
      );
      final r = sunReplay(w, startIn('sun_lantern'), kBlackSunPlans['sun_rite']!);
      expect(r.failed, isNull);
      expect(r.state!.latched, contains(kSunRiteLatch));
      expect(allIn(r.state!, 'sun_heart', (x, y) => y == 6), isTrue);
    });

    test('without its stars the Hall has no light to bridge with', () {
      final r = sunReplay(only('sun_hall'), startIn('sun_hall'), kBlackSunPlans['sun_hall']!);
      expect(r.failed, isNotNull);
    });
  });

  // ── THE RULES ───────────────────────────────────────────
  group('the rules', () {
    test('through one Dark it stays white; through both it is blood', () {
      final w = SunWorld(rooms: {'two_darks': kSunRooms['two_darks']!});
      final base = SunState(
        pos: {
          'light': at('two_darks', 1, 2),
          'purple': at('two_darks', 5, 3),
          'orange': at('two_darks', 6, 1),
        },
        shine: 1,
      );
      // Purple only: round to the red seal's column, still white.
      final one = base.copyWith(
        ends: {
          'purple': [face('two_darks', 7, 2, 3), face('two_darks', 3, 4, 0)],
          'orange': [null, null],
        },
      );
      expect(sunEvaluate(w, one).sealsLit, isEmpty);
      // Both: blood on the red seal.
      final both = base.copyWith(
        ends: {
          'purple': [face('two_darks', 7, 2, 3), face('two_darks', 1, 4, 0)],
          'orange': [face('two_darks', 1, 0, 2), face('two_darks', 3, 4, 0)],
        },
      );
      expect(sunEvaluate(w, both).sealsLit, contains('two_darks:3,0'));
    });

    test('a Dark drinks the beam it stands in; Light lets it through', () {
      final w = SunWorld(rooms: {'two_darks': kSunRooms['two_darks']!});
      final s = SunState(
        pos: {
          'light': at('two_darks', 1, 2),
          'purple': at('two_darks', 4, 2),
          'orange': at('two_darks', 6, 1),
        },
        shine: 1,
      );
      final e = sunEvaluate(w, s);
      expect(e.litAt('two_darks', 4, 2), isNonZero);
      expect(e.litAt('two_darks', 5, 2), 0, reason: 'past the Dark is dark');
    });

    test('Light shines only from the burning-glass, and goes out off it', () {
      final w = SunWorld(rooms: {'two_darks': kSunRooms['two_darks']!});
      final off = SunState(
        pos: {
          'light': at('two_darks', 2, 2),
          'purple': at('two_darks', 4, 3),
          'orange': at('two_darks', 6, 1),
        },
      );
      expect(sunShine(w, off, 1).why, 'no lens');
      final on = off.moved('light', at('two_darks', 1, 2));
      final lit = sunShine(w, on, 1).state!;
      expect(lit.shine, 1);
      expect(sunMove(w, lit, 'light', 1).state!.shine, -1);
    });

    test('a Dark can only walk a blood bridge towards its source', () {
      // Room IV with its bridge up: the orange Dark on it.
      final w = SunWorld(rooms: {'into_the_light': kSunRooms['into_the_light']!});
      final s = SunState(
        pos: {
          'light': at('into_the_light', 1, 1),
          'purple': at('into_the_light', 3, 2),
          'orange': at('into_the_light', 7, 3),
        },
        ends: {
          'purple': [face('into_the_light', 12, 4, 3), face('into_the_light', 2, 6, 0)],
          'orange': [face('into_the_light', 0, 4, 1), face('into_the_light', 12, 3, 3)],
        },
      );
      expect(sunMove(w, s, 'orange', 1).ok, isTrue, reason: 'toward the source');
      expect(sunMove(w, s, 'orange', 3).ok, isFalse, reason: 'away from it');
    });
  });

  // ── WHY THE RITE CANNOT BE DONE IN ONE ROOM ─────────────
  group('the rite, by its structure', () {
    test('the Heart has no light of its own: no star, no burning-glass', () {
      for (var y = 0; y < kSunHeart.rows; y++) {
        for (var x = 0; x < kSunHeart.cols; x++) {
          expect('><^v*'.contains(kSunHeart.at(x, y)), isFalse);
        }
      }
      // So blood on the Great Seal is light from upstairs, through a portal
      // whose two ends are in different rooms — nothing else crosses.
    });

    test('only Light, on its burning-glass, holds the way down — so Light '
        'can never take it', () {
      final down = kSunLinks.firstWhere(
        (l) => l.room == 'sun_lantern' && l.to == 'sun_heart',
      );
      final seal = down.heldBy!;
      expect(kSunLantern.at(seal.x, seal.y), 'w');
      // No obsidian face in the Lantern looks down the seal's column, so no
      // portal can throw light onto it: only a beam shone from the glass.
      for (final f in kSunLantern.faces) {
        expect(f.x == seal.x && f.d == 2, isFalse);
      }
      final glass = (x: 2, y: 3);
      expect(kSunLantern.at(glass.x, glass.y), '*');
      expect(glass.x, seal.x, reason: 'the glass looks straight at the seal');
      // And the doorway is not the glass: standing in it, Light is not
      // shining, the seal is dark and the door is shut.
      expect(down.x == glass.x && down.y == glass.y, isFalse);
    });

    test('the blood chain and Light\'s way down cannot both stand: the seal '
        'burns first, and someone goes back up for Light', () {
      // The star's only obsidian is the east block, across a void; Light's
      // only way into a portal upstairs is the west block's face. One Dark's
      // portal can hold one Lantern face, so a chain (the star's face plus a
      // pair in the Heart) leaves no end for Light's.
      final starFace = kSunLantern.faces.where((f) => f.x == 9 && f.y == 2);
      expect(starFace, hasLength(1));
      expect(kSunLantern.at(starFace.single.front.x, starFace.single.front.y), '~',
          reason: 'nobody walks into the star\'s portal');
      final walkable = [
        for (final f in kSunLantern.faces)
          if ('.*pD'.contains(kSunLantern.at(f.front.x, f.front.y))) f,
      ];
      expect(walkable, hasLength(1));
      expect((walkable.single.x, walkable.single.y), (0, 4));
    });
  });

  // ── THE GAME, PLAYING BY THEM ───────────────────────────
  group('the game', () {
    test('the party is two Darks and a Light, and the gate asks for it', () {
      expect(kCosmicPlanetEntry['Dark'], ['Dark', 'Dark', 'Light']);
      expect(cosmicPartySatisfiesEntry(_trio(), kCosmicPlanetEntry['Dark']!), isTrue);
      expect(kPlanetDungeonLayouts['Dark']!.familyGates, isEmpty);
    });

    test('a door takes only the body you steer', () {
      final g = harness();
      stage(g, {
        'purple': at('sun_porch', 1, 2),
        'orange': at('sun_porch', 2, 3),
        'light': at('sun_porch', 7, 1),
      });
      g.setActive(light);
      final door = g.layout.rooms['sun_porch']!.doors.single;
      g.creatures[light].position = door.rect.center;
      g.update(1 / 60);
      expect(g.currentRoomId, 'sun_hall');
      expect(g.blackSun.state.pos['light']!.room, 'sun_hall');
      expect(g.blackSun.state.pos['purple']!.room, 'sun_porch');
      expect(g.blackSun.state.pos['orange']!.room, 'sun_porch');
      // Choosing a body in the porch takes the view back there.
      g.setActive(purple);
      expect(g.currentRoomId, 'sun_porch');
    });

    test('a Dark casts where it looks, and a portal can join two rooms', () {
      final g = harness();
      stage(g, {
        'purple': at('sun_porch', 1, 2),
        'orange': at('sun_porch', 2, 3),
        'light': at('sun_porch', 2, 1),
      });
      g.setActive(purple);
      aim(g, purple, 3);
      g.activateSunCast(0);
      expect(g.blackSun.state.ends['purple']![0], face('sun_porch', 0, 2, 1));
      // Purple goes up to the Hall and casts II onto the south wall's block.
      stage(g, {
        'purple': at('sun_hall', 2, 7),
        'orange': at('sun_porch', 2, 3),
        'light': at('sun_porch', 2, 1),
      });
      g.currentRoomId = 'sun_hall';
      aim(g, purple, 2);
      g.activateSunCast(1);
      expect(g.blackSun.state.ends['purple']![1], face('sun_hall', 2, 8, 0));
      // Purple steps off the mouth's square; Light walks into the porch's
      // mouth and comes out in the Hall.
      stage(g, {
        'purple': at('sun_hall', 3, 7),
        'orange': at('sun_porch', 2, 3),
        'light': at('sun_porch', 1, 2),
      });
      g.setActive(light);
      expect(g.currentRoomId, 'sun_porch');
      walk(g, 3);
      g.update(1 / 60);
      expect(g.blackSun.state.pos['light'], at('sun_hall', 2, 7));
      expect(g.currentRoomId, 'sun_hall');
    });

    test('a pair of chambers banks its star, and the chamber stays set', () {
      final stars = <int>[];
      final g = harness(onStar: stars.add);
      for (final id in const ['through_the_dark', 'two_darks']) {
        final d = kSunRooms[id]!;
        final pads = d.exits.take(3).toList();
        g.currentRoomId = id;
        stage(g, {
          'purple': at(id, pads[0].x, pads[0].y),
          'orange': at(id, pads[1].x, pads[1].y),
          'light': at(id, pads[2].x, pads[2].y),
        });
        g.setActive(light);
        g.update(1 / 60);
        expect(g.blackSun.solved, contains(id));
      }
      expect(stars, contains(0));
      // A new run keeps them set.
      g.debugResetPuzzleState();
      expect(g.blackSun.solved, containsAll(['through_the_dark', 'two_darks']));
    });

    test('blood on the Great Seal latches the rite and wakes Noctryos', () {
      final g = harness();
      g.earnStar(0);
      g.earnStar(1);
      g.currentRoomId = 'sun_heart';
      stage(
        g,
        {
          'light': at('sun_heart', 3, 1),
          'purple': at('sun_heart', 1, 2),
          'orange': at('sun_heart', 3, 4),
        },
      );
      g.blackSun.state = g.blackSun.state.copyWith(
        latched: {...g.blackSun.state.latched, kSunRiteLatch},
      );
      g.setActive(orange);
      for (var i = 0; i < 3; i++) {
        g.update(1 / 60);
      }
      expect(g.conduitEnergy['A'], double.infinity);
      expect(g.guardianAwake, isTrue);
    });

    test('THE LOST MAXIM: a light that does not end', () {
      final clouds = <String>[];
      final g = harness(onCloud: clouds.add);
      g.currentRoomId = 'two_darks';
      // Purple's two ends face each other down the burning-glass's column;
      // Light shines up it, and the beam goes round forever.
      stage(
        g,
        {
          'light': at('two_darks', 1, 2),
          'purple': at('two_darks', 5, 3),
          'orange': at('two_darks', 6, 1),
        },
        ends: {
          'purple': [face('two_darks', 1, 0, 2), face('two_darks', 1, 4, 0)],
          'orange': [null, null],
        },
        shine: 0,
      );
      g.setActive(light);
      for (var tick = 0; tick < 400; tick++) {
        g.update(1 / 60);
      }
      expect(clouds, contains('egg:dark_ouroboros'));
    });

    test('down to Noctryos together; its enemies come out of black holes', () {
      final g = harness();
      g.earnStar(0);
      g.earnStar(1);
      g.currentRoomId = 'sun_heart';
      stage(g, {
        'light': at('sun_heart', 4, 6),
        'purple': at('sun_heart', 3, 6),
        'orange': at('sun_heart', 5, 6),
      });
      g.blackSun.state = g.blackSun.state.copyWith(
        latched: {...g.blackSun.state.latched, kSunRiteLatch},
      );
      g.setActive(light);
      // The seal has burned: the rite latches and Noctryos wakes first.
      for (var i = 0; i < 3; i++) {
        g.update(1 / 60);
      }
      expect(g.guardianAwake, isTrue);
      final door = g.layout.rooms['sun_heart']!.doors.firstWhere(
        (d) => d.targetRoomId == 'noctryos_totality',
      );
      g.creatures[light].position = door.rect.center;
      g.update(1 / 60);
      expect(g.currentRoomId, 'noctryos_totality');
      expect(g.blackSun.inArena, isTrue);
      final arena = g.layout.rooms['noctryos_totality']!;
      final spawn = g.offscreenSpawn(arena, const Offset(450, 330));
      expect(
        kSunArenaHoles.any((h) => (h - spawn).distance < 16),
        isTrue,
        reason: 'a spawn comes out of one of the arena\'s black holes',
      );
    });

    test('a grid room is framed whole: the camera pulls back to fit it', () {
      final g = harness();
      g.onGameResize(Vector2(820, 420)); // a folded phone, landscape
      for (final id in const ['sun_hall', 'into_the_light', 'sun_lantern', 'sun_heart']) {
        g.currentRoomId = id;
        final b = g.layout.rooms[id]!.bounds;
        final z = g.viewZoom;
        expect(z, lessThan(1.0), reason: '$id should pull back');
        expect(b.width * z, lessThanOrEqualTo(820), reason: id);
        expect(b.height * z, lessThanOrEqualTo(420), reason: id);
      }
      // The arena's fight keeps the ordinary camera.
      g.currentRoomId = 'noctryos_totality';
      expect(g.viewZoom, 1.0);
    });

    test('gather: everyone who can WALK there comes to the one you steer',
        () {
      final g = harness();
      // Orange and Light on the near side of the porch's void; purple across
      // it. Steering orange, the other two near-side bodies come; nobody can
      // walk the void, so purple stays.
      stage(g, {
        'orange': at('sun_porch', 1, 1),
        'light': at('sun_porch', 3, 3),
        'purple': at('sun_porch', 8, 2),
      });
      g.setActive(orange);
      g.regroup();
      final s = g.blackSun.state;
      final o = s.pos['orange']!;
      final l = s.pos['light']!;
      expect((l.x - o.x).abs() + (l.y - o.y).abs(), 1, reason: 'Light came');
      expect(s.pos['purple'], at('sun_porch', 8, 2), reason: 'not across the void');
      expect(g.hintText, contains('can\'t get here'));
    });

    test('gather goes through doors and open portals, never over gaps', () {
      final g = harness();
      // Purple's portal joins the porch's far side to the Hall's south
      // ledge: Light, in the porch, walks through it to purple in the Hall.
      stage(
        g,
        {
          'purple': at('sun_hall', 3, 7),
          'orange': at('sun_porch', 1, 2),
          'light': at('sun_porch', 1, 1),
        },
        ends: {
          'purple': [face('sun_porch', 0, 2, 1), face('sun_hall', 2, 8, 0)],
          'orange': [null, null],
        },
      );
      g.setActive(purple);
      g.currentRoomId = 'sun_hall';
      g.regroup();
      final s = g.blackSun.state;
      expect(s.pos['light']!.room, 'sun_hall');
      expect(s.pos['orange']!.room, 'sun_hall');
    });
  });
}
