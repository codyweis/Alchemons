// GLACIUS — the Frozen Observatory, pinned.
//
// Ice's topology is a VERTICAL SHAFT whose descents are one-way slides, and
// whose vault sits on a ledge you can only fall onto (docs §5.5). That
// combination is a stranding machine unless the state graph is
// checked, so the centrepiece of this file is the FULL REACHABILITY SEARCH:
// every state the player can legally reach (room × every flue's
// drift/stair/scoured state × the rimefall), and from each of them, whether
// every room in the dungeon is still reachable.
//
// The orrery gets a search of its own (`solveOrreryBoards`) for the same
// reason, and it is the one this file was missing: the shaft's proof is
// about the PARTY, and a star-block shoved somewhere it can never leave ends
// a run just as dead. It is SOLVED here as well, move by move.
//
// The gallery is pinned as what it now is — a room you WALK to read, with
// nothing in it that runs down.

import 'dart:math' show atan2, pi;
import 'dart:ui' show Offset, Rect;

import 'package:alchemons/audio/sound_cue.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_companion_stats.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart'
    show CosmicSurvivalCompanion;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_ice.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// The §6 ideal trio: Icemane · Lightmask · Airwing.
List<CosmicPartyMember> _idealTrio() => [
  _member(0, 'Ice', 'mane'),
  _member(1, 'Light', 'mask'),
  _member(2, 'Air', 'wing'),
];

const int ice = 0, light = 1, air = 2;

PlanetDungeonGame _harness(
  List<CosmicPartyMember> party, {
  void Function(int)? onStar,
  void Function(String)? onCloud,
  void Function(SoundCue)? onSound,
  void Function()? onDown,
}) {
  final game = PlanetDungeonGame(
    element: 'Ice',
    party: party,
    initialStarMask: 0,
    onStarEarned: onStar ?? (_) {},
    onCloudDiscovered: onCloud,
    onSound: onSound,
    onPlayerDown: onDown ?? () => fail('the scripted run must never wipe'),
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
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final layout = kPlanetDungeonLayouts['Ice']!;

  group('the shaft — topology', () {
    test('every flue names real rooms, and every leg has a door', () {
      for (final f in kRimeFlues) {
        final head = layout.rooms[f.headRoom];
        final foot = layout.rooms[f.footRoom];
        expect(head, isNotNull, reason: '${f.id} head');
        expect(foot, isNotNull, reason: '${f.id} foot');
        expect(
          head!.doors.any((d) => d.targetRoomId == f.footRoom),
          isTrue,
          reason: '${f.id}: no long-drop door out of ${f.headRoom}',
        );
        expect(
          foot!.doors.any((d) => d.targetRoomId == f.headRoom),
          isTrue,
          reason: '${f.id}: no climb door back to ${f.headRoom}',
        );
        if (f.shelfRoom != null) {
          expect(
            head.doors.any((d) => d.targetRoomId == f.shelfRoom),
            isTrue,
            reason: '${f.id}: no drift-landing door onto ${f.shelfRoom}',
          );
          // A shelf is a DEAD END that scrambles back to the head and nowhere
          // else — that is what keeps a slide from ever being a trap.
          final shelf = layout.rooms[f.shelfRoom]!;
          expect(
            shelf.doors.length,
            1,
            reason: '${f.shelfRoom} must be a pocket',
          );
          expect(shelf.doors.single.targetRoomId, f.headRoom);
        }
        // The freeze verb has to be inside its own room.
        expect(
          head.bounds.contains(f.headPos),
          isTrue,
          reason: '${f.id} head pos',
        );
      }
    });

    test('the vault sits on a shelf, so the cache IS the slide trick', () {
      final cacheRoom = layout.rooms.values.singleWhere(
        (r) => r.vaultCache != null,
      );
      expect(
        rimeFlueForShelf(cacheRoom.id),
        isNotNull,
        reason: 'docs §5.5: visible in a mirror, reached by falling onto it',
      );
    });

    test('no STAR lives on a shelf — only optional treasure does', () {
      // The whole non-strandability argument depends on this: a shelf can be
      // lost for the run, so nothing required may sit on one.
      for (final f in kRimeFlues) {
        if (f.shelfRoom == null) continue;
        expect(layout.rooms[f.shelfRoom]!.rime?.starIndex, isNull);
      }
    });

    test(
      '§4: two hard gates, on different slots, and the ORRERY is ungated',
      () {
        expect(layout.familyGates.length, 2);
        final slots = kCosmicPlanetEntry['Ice']!;
        final gated = layout.familyGates.map((g) => g.element).toSet();
        expect(gated.length, 2, reason: 'one gate per entry slot at most');
        for (final g in layout.familyGates) {
          if (g.needsElement) expect(slots, contains(g.element));
        }
        // The orrery — the star a first descent must be able to earn — carries
        // no family gate of any kind.
        expect(gated, isNot(contains('Ice')));
      },
    );
  });

  group('THE NO-STRAND PROOF', () {
    test('no state reachable by legal play can strand the party', () {
      final game = _harness(_idealTrio());
      final r = game.solveShaftDescent();
      expect(r.states, greaterThan(20), reason: 'the search must be real');
      expect(
        r.strandable,
        0,
        reason:
            'from EVERY reachable state, every room — the exit, both star '
            'rooms, the rite, the vault shelf and the maxim niche — must '
            'still be reachable',
      );
    });

    test('the rimefall is load-bearing, not decoration', () {
      // Delete the sump valve and the planet becomes exactly the stranding
      // machine the design warns about. If this ever reaches zero, somebody
      // has quietly made the descent two-way and Ice has lost its identity.
      final game = _harness(_idealTrio());
      final r = game.solveShaftDescent();
      expect(
        r.strandableWithoutRimefall,
        greaterThan(0),
        reason: 'one-way descent must actually be one-way',
      );
    });

    test('a shelf CAN be lost — gravity, not the chute', () {
      final game = _harness(_idealTrio());
      final r = game.solveShaftDescent();
      expect(
        r.shelfLosable,
        greaterThan(0),
        reason:
            'a ledge is entered from the level above it: below, with no '
            'stair back up, the treasure is gone until you pay a thaw',
      );
    });
  });

  group('TWO MOUTHS, ONE DESTINATION EACH', () {
    /// Open every plate in the mouth, the way a party does on the way in.
    void openTheFloor(PlanetDungeonGame game) {
      final head = game.layout.rooms['rime_head']!;
      game.setActive(light);
      for (final f in kRimeFlues.where((f) => f.headRoom == 'rime_head')) {
        for (final p in [f.headPos, if (f.chutePos != null) f.chutePos!]) {
          for (final c in game.creatures) {
            c.position = p;
          }
          game.activateAbility();
        }
      }
      expect(
        head.doors.every((d) => !game.isDoorHidden(head, d)),
        isTrue,
        reason: 'every plate drunk, every hole open',
      );
    }

    test('LIGHT OPENS ONE HOLE AT A TIME', () {
      // One press used to open the whole floor, which taught that the holes
      // were one thing — and the planet's first lesson is that they are not.
      final game = _harness(_idealTrio());
      final head = game.layout.rooms['rime_head']!;
      for (final d in head.doors) {
        expect(game.isDoorHidden(head, d), isTrue, reason: 'all plated');
      }
      final flue = kRimeFlues.firstWhere((f) => f.id == 'flue_a');
      final shaftDoor = head.doors.firstWhere(
        (d) => d.targetRoomId == 'mirror_gallery',
      );
      final chuteDoor = head.doors.firstWhere(
        (d) => d.targetRoomId == 'shelf_glass',
      );

      game.setActive(light);
      for (final c in game.creatures) {
        c.position = flue.headPos;
      }
      game.activateAbility();
      expect(game.isDoorHidden(head, shaftDoor), isFalse);
      expect(
        game.isDoorHidden(head, chuteDoor),
        isTrue,
        reason: 'the plate you drank is the plate you were standing on',
      );
      expect(game.entryDoorRevealed, isTrue);

      for (final c in game.creatures) {
        c.position = flue.chutePos!;
      }
      game.activateAbility();
      expect(game.isDoorHidden(head, chuteDoor), isFalse);
    });

    test('a melted plate is knowledge: it survives a wipe', () {
      var wiped = false;
      final game = _harness(_idealTrio(), onDown: () => wiped = true);
      openTheFloor(game);
      final melted = {...game.meltedCaps};
      expect(melted, isNotEmpty);
      for (final c in game.creatures) {
        c.hp = 0;
      }
      for (var i = 0; i < 6; i++) {
        game.update(1 / 60);
      }
      expect(wiped, isTrue, reason: 'the party really did go down');
      expect(game.meltedCaps, melted);
    });

    test('the shaft goes down whatever its snow, and up only as a stair', () {
      final game = _harness(_idealTrio());
      openTheFloor(game);
      final head = game.layout.rooms['rime_head']!;
      final gallery = game.layout.rooms['mirror_gallery']!;
      final flue = kRimeFlues.firstWhere((f) => f.id == 'flue_a');
      final shaftDoor = head.doors.firstWhere(
        (d) => d.targetRoomId == 'mirror_gallery',
      );
      final up = gallery.doors.firstWhere((d) => d.targetRoomId == 'rime_head');

      // Drifted: the way down is open, the way back is not.
      expect(game.isDoorHidden(head, shaftDoor), isFalse);
      expect(game.isDoorLocked(gallery, up), isTrue);

      // Frozen: a stair, and now it climbs.
      game.setActive(ice);
      for (final c in game.creatures) {
        c.position = flue.headPos;
      }
      game.activateAbility();
      expect(game.flueState['flue_a'], RimeFlueState.stair);
      expect(game.isDoorHidden(head, shaftDoor), isFalse);
      expect(game.isDoorLocked(gallery, up), isFalse);
    });

    test('a ridden shaft is bare for good and takes no more frost', () {
      final game = _harness(_idealTrio());
      openTheFloor(game);
      final head = game.layout.rooms['rime_head']!;
      final flue = kRimeFlues.firstWhere((f) => f.id == 'flue_a');
      game.onShaftTransitForTest(
        head,
        head.doors.firstWhere((d) => d.targetRoomId == 'mirror_gallery'),
      );
      expect(game.flueState['flue_a'], RimeFlueState.scoured);

      game.setActive(ice);
      for (final c in game.creatures) {
        c.position = flue.headPos;
      }
      game.activateAbility();
      expect(
        game.flueState['flue_a'],
        RimeFlueState.scoured,
        reason: 'frost will not key onto polished ice',
      );
      final gallery = game.layout.rooms['mirror_gallery']!;
      expect(
        game.isDoorLocked(
          gallery,
          gallery.doors.firstWhere((d) => d.targetRoomId == 'rime_head'),
        ),
        isTrue,
        reason: 'the ladder is what a ride costs you',
      );
    });

    test('RIDING THE CHUTE SPENDS NOTHING — not the chute, not the shaft', () {
      // The chute and the shaft are two holes with one destination each, and
      // neither touches the other. And the chute is a ramp EVERY time
      // (2026-09-20): a ledge you could enter once a run gated nothing and
      // made the lens niche a one-shot.
      final game = _harness(_idealTrio());
      openTheFloor(game);
      final head = game.layout.rooms['rime_head']!;
      final chuteDoor = head.doors.firstWhere(
        (d) => d.targetRoomId == 'shelf_glass',
      );
      game.onShaftTransitForTest(head, chuteDoor);
      game.onShaftTransitForTest(head, chuteDoor);

      expect(
        game.isDoorHidden(head, chuteDoor),
        isFalse,
        reason: 'the snow holds; the ledge can be gone back to',
      );
      expect(
        game.flueState['flue_a'],
        RimeFlueState.drift,
        reason: 'the shaft beside it is untouched, and still takes frost',
      );

      // And it really does still take frost.
      game.setActive(ice);
      for (final c in game.creatures) {
        c.position = kRimeFlues.firstWhere((f) => f.id == 'flue_a').headPos;
      }
      game.activateAbility();
      expect(game.flueState['flue_a'], RimeFlueState.stair);
    });

    test('freezing the shaft leaves the chute alone', () {
      final game = _harness(_idealTrio());
      openTheFloor(game);
      final head = game.layout.rooms['rime_head']!;
      final chuteDoor = head.doors.firstWhere(
        (d) => d.targetRoomId == 'shelf_glass',
      );
      game.setActive(ice);
      for (final c in game.creatures) {
        c.position = kRimeFlues.firstWhere((f) => f.id == 'flue_a').headPos;
      }
      game.activateAbility();
      expect(game.flueState['flue_a'], RimeFlueState.stair);
      expect(
        game.isDoorHidden(head, chuteDoor),
        isFalse,
        reason: 'nothing at this head is coupled to anything else at it',
      );
    });

    test('the rimefall climbs home and THAWS the whole shaft behind you', () {
      final game = _harness(_idealTrio());
      final sump = game.layout.rooms['cold_sump']!;
      final up = sump.doors.firstWhere((d) => d.targetRoomId == 'rime_head');
      // Build a stair, then spend it on the sump's do-over.
      game.flueState['flue_b'] = RimeFlueState.stair;
      game.flueState['flue_c'] = RimeFlueState.scoured;
      expect(
        game.isDoorLocked(sump, up),
        isTrue,
        reason: 'running water is not a ladder',
      );

      game.setActive(ice);
      game.creatures[ice].position = sump.rime!.rimefall!;
      game.currentRoomId = 'cold_sump';
      game.activateAbility();
      expect(game.rimefallFrozen, isTrue);
      expect(game.isDoorLocked(sump, up), isFalse);

      game.onShaftTransitForTest(sump, up);
      expect(game.rimefallFrozen, isFalse);
      expect(game.shaftThaws, 1);
      for (final f in kRimeFlues) {
        expect(
          game.flueState[f.id],
          RimeFlueState.drift,
          reason: 'the price is everything you cut',
        );
      }
    });

    test('an Ice creature is all the rimefall ever needs', () {
      // The valve may never depend on a family: a party without the ideal
      // trio still has to be able to get out.
      final game = _harness([
        _member(0, 'Ice', 'pip'),
        _member(1, 'Light', 'horn'),
        _member(2, 'Air', 'kin'),
      ]);
      final sump = game.layout.rooms['cold_sump']!;
      game.currentRoomId = 'cold_sump';
      game.setActive(0);
      game.creatures[0].position = sump.rime!.rimefall!;
      game.activateAbility();
      expect(game.rimefallFrozen, isTrue);
    });
  });

  group('Star 1 (index 1) \u2014 THE STANDING ORRERY', () {
    late PlanetDungeonGame game;
    late DungeonRoom room;
    late OrreryGrid grid;
    final earned = <int>[];

    setUp(() {
      earned.clear();
      game = _harness(_idealTrio(), onStar: earned.add);
      room = game.layout.rooms['orrery_floor']!;
      grid = room.rime!.orrery!;
      game.currentRoomId = 'orrery_floor';
    });

    /// Stand [idx] on cell (c,r) FACING (fc,fr) and press the verb. Every
    /// orrery verb acts on the cell in front of you, so this is the only way
    /// the puzzle is ever driven \u2014 in a test or on a phone.
    void act(int idx, int c, int r, int fc, int fr) {
      game.setActive(idx);
      final p = grid.centerAt(c, r);
      final ang = atan2((fr - r).toDouble(), (fc - c).toDouble());
      for (final cr in game.creatures) {
        cr
          ..position = p
          ..lastSafe = p
          ..angle = ang
          ..aimAngle = ang;
      }
      game.activateAbility();
    }

    /// Glaze / melt / shove the cell one step [dir] of (c,r).
    void glaze(int c, int r, int fc, int fr) => act(ice, c, r, fc, fr);
    void melt(int c, int r, int fc, int fr) => act(light, c, r, fc, fr);
    void shove(int c, int r, int fc, int fr) => act(air, c, r, fc, fr);

    int? blockCell(int c, int r) {
      final idx = r * grid.cols + c;
      for (final e in game.orreryBlocks.entries) {
        if (e.value == idx) return e.key;
      }
      return null;
    }

    test('the floor opens with three blocks off three sockets', () {
      expect(game.orreryBlocks.length, 3);
      expect(game.orrerySeated, isEmpty);
      expect(blockCell(1, 2), isNotNull);
      expect(blockCell(6, 2), isNotNull);
      expect(blockCell(3, 4), isNotNull);
    });

    test('a star-block will not budge across bare stone', () {
      shove(0, 2, 1, 2);
      expect(blockCell(1, 2), isNotNull, reason: 'still where it started');
      expect(game.orrerySeated, isEmpty);
    });

    test('a glaze throws a ROAD, and Light takes the whole sheet', () {
      glaze(1, 2, 2, 2); // stand on the block's cell, throw ice east
      expect(
        game.orreryGlass.length,
        3,
        reason: 'one press lays three cells of road',
      );
      // NO TRIMMING. Melting one cell let you lay any road and whittle it to
      // the length you wanted, so "where does this road end" — the only real
      // question on this floor — never had to be answered before laying it.
      melt(4, 2, 3, 2);
      expect(
        game.orreryGlass,
        isEmpty,
        reason: 'the whole connected sheet goes at once',
      );
    });

    test('and a sheet that is not connected to it stays', () {
      glaze(1, 2, 2, 2); // (2,2) (3,2) (4,2)
      glaze(7, 4, 7, 3); // a separate patch up the east edge
      final before = game.orreryGlass.length;
      expect(before, greaterThan(3));
      melt(4, 2, 3, 2); // melts only the road it touches
      expect(game.orreryGlass, isNotEmpty);
      expect(game.orreryGlass.length, before - 3);
    });

    test('A KERB OPENS ONE WAY', () {
      // The bottom kerb takes a block running WEST. The block starts just
      // west of it, so the shove that used to seat it now stops at the lip.
      shove(2, 4, 3, 4); // pushing EAST into the kerb
      expect(game.orrerySeated, isEmpty, reason: 'it is running against it');
      expect(blockCell(3, 4), isNotNull, reason: 'stopped dead at the lip');
    });

    test('and takes the block that runs WITH the sky', () {
      // Brought round to the east side, the same kerb opens for it.
      final id = blockCell(3, 4)!;
      game.orreryBlocks[id] = 4 * grid.cols + 5; // stand it east of the kerb
      shove(6, 4, 5, 4); // and run it west
      expect(game.orrerySeated, contains(id));
      expect(blockCell(4, 4), isNotNull);
    });

    test('THE AUTHORED SOLUTION seats every block and banks the star', () {
      // TEN shoves, and not one of them a nudge into the nearest hole: every
      // kerb is cut for ONE block and opens only with its own orbit, so each
      // block has to be taken the long way round to meet its socket head-on.

      // ── the west block: out to the edge, up it, and east into its kerb.
      glaze(0, 3, 0, 2); // the west edge, three cells of it
      shove(2, 2, 1, 2); // W — it stops at the wall
      expect(blockCell(0, 2), isNotNull);
      shove(0, 3, 0, 2); // N — up the edge to the corner
      expect(blockCell(0, 0), isNotNull);
      glaze(1, 1, 1, 0); // one cell of road to the kerb
      shove(-1, 0, 0, 0); // E — running with the top orbit
      expect(game.orrerySeated.length, 1);
      expect(blockCell(2, 0), isNotNull);

      // ── the east block: in to the middle, up, and east into ITS kerb.
      glaze(3, 2, 4, 2); // road stops dead against the block itself
      shove(7, 2, 6, 2); // W
      expect(blockCell(4, 2), isNotNull);
      glaze(4, -1, 4, 0); // laid from the margin, back down the column
      shove(4, 3, 4, 2); // N
      expect(blockCell(4, 0), isNotNull);
      shove(3, 0, 4, 0); // E — straight into the kerb beside it
      expect(game.orrerySeated.length, 2);
      expect(blockCell(5, 0), isNotNull);

      // ── the south block: a full circuit, because its kerb opens WEST and
      // it starts on the wrong side of it.
      glaze(3, 2, 3, 3); // one cell: the road stops on the block
      shove(3, 5, 3, 4); // N
      expect(blockCell(3, 3), isNotNull);
      glaze(4, 2, 4, 3);
      glaze(5, 2, 5, 3);
      shove(2, 3, 3, 3); // E — until the standard stops it
      expect(blockCell(5, 3), isNotNull);
      shove(5, 2, 5, 3); // S — down onto the bottom row
      expect(blockCell(5, 4), isNotNull);
      shove(6, 4, 5, 4); // W — with the bottom orbit, into its kerb
      expect(game.orrerySeated.length, 3);
      expect(earned, contains(1));
      expect(game.hasStar(1), isTrue);
    });

    test('A KERB IS CUT FOR ONE BLOCK ONLY', () {
      // The east block, brought to the west block's kerb from the right side
      // and the right direction: it still will not go in.
      final id = blockCell(6, 2)!;
      game.orreryBlocks[id] = 0; // stand it at (0,0)
      glaze(1, 1, 1, 0);
      shove(-1, 0, 0, 0); // E into (2,0), which is the WEST block's kerb
      expect(game.orrerySeated, isEmpty, reason: 'not its socket');
      expect(blockCell(1, 0), isNotNull, reason: 'it stopped at the lip');
    });

    test('THE START BOARD IS ALWAYS SOLVABLE', () {
      // Star-blocks are solid, so three of them CAN be packed into a corner
      // where each blocks the square the next would be pushed from — 151 of
      // the 7,140 reachable boards are jammed like that. The answer is the
      // crank, not a rule against jamming; what has to hold is that the
      // board the crank restores is a board you can win from.
      final r = game.solveOrreryBoards();
      expect(r.boards, greaterThan(1000), reason: 'the search must be real');
      expect(r.startDead, isFalse);
      expect(
        r.dead,
        greaterThan(0),
        reason:
            'solid blocks CAN jam; if this is ever zero, either the bodies '
            'went soft again or the board changed and the crank needs '
            'rethinking',
      );
    });

    test('THE CRANK PUTS A JAMMED FLOOR BACK, and keeps your seated work', () {
      // A jam, built by hand: three blocks packed into the north-west corner,
      // each standing on the only square the next could be pushed from. (The
      // harness can teleport a pusher into a block; a player cannot, which is
      // what makes this shape a dead board — see the search above.)
      game.orreryBlocks[0] = 0; // (0,0)
      game.orreryBlocks[1] = 1; // (1,0)
      game.orreryBlocks[2] = grid.cols; // (0,1)
      glaze(3, 2, 4, 2); // and some road laid about the place

      final crank = Offset(
        grid.origin.dx + grid.cols * grid.cell + 50,
        grid.origin.dy + grid.rows * grid.cell / 2,
      );
      game.setActive(ice);
      for (final c in game.creatures) {
        c.position = crank;
      }
      game.activateAbility();
      expect(
        {...game.orreryBlocks.values},
        {0, 1, grid.cols},
        reason: 'a cold hand does not turn it',
      );

      game.setActive(light);
      for (final c in game.creatures) {
        c.position = crank;
      }
      game.activateAbility();
      expect(game.orreryBlocks.values.toSet(), {
        2 * grid.cols + 1,
        2 * grid.cols + 6,
        4 * grid.cols + 3,
      }, reason: 'every loose block back on its own standard');
      expect(game.orreryGlass, isEmpty, reason: 'and the road taken up');
    });

    test('the crank never undoes a SEATED block', () {
      // It undoes your working, not your progress.
      final id = blockCell(3, 4)!;
      game.orreryBlocks[id] = 4 * grid.cols + 5;
      shove(6, 4, 5, 4);
      expect(game.orrerySeated, contains(id));

      final crank = Offset(
        grid.origin.dx + grid.cols * grid.cell + 50,
        grid.origin.dy + grid.rows * grid.cell / 2,
      );
      game.setActive(light);
      for (final c in game.creatures) {
        c.position = crank;
      }
      game.activateAbility();
      expect(game.orrerySeated, contains(id));
      expect(game.orreryBlocks[id], 4 * grid.cols + 4);
    });

    test('the crank only answers from OFF the floor', () {
      // A lever that overlaps the board is a lever you pull by accident: it
      // used to sit at the middle of the grid, where Light melting one cell
      // of road reset the whole floor instead.
      game.orreryBlocks[0] = 0;
      game.setActive(light);
      for (final c in game.creatures) {
        c.position = grid.centerAt(4, 2);
      }
      game.activateAbility();
      expect(
        game.orreryBlocks[0],
        0,
        reason: 'standing on the floor works the floor',
      );
    });

    test('Light melts a glaze back, so no lay of ice is a dead end', () {
      glaze(2, 2, 3, 2);
      expect(game.orreryGlass.length, 3, reason: 'a road, not a tile');
      // Light takes it back a cell at a time, which is how a road is trimmed
      // to stop a block exactly where you want it.
      melt(2, 2, 3, 2);
      melt(3, 2, 4, 2);
      melt(4, 2, 5, 2);
      expect(game.orreryGlass, isEmpty);
    });
  });

  group('Star 0 (index 0) — THE MIRROR GALLERY', () {
    PlanetDungeonGame _gallery() {
      final game = _harness(_idealTrio());
      final ring = game.layout.rooms['mirror_gallery']!.rime!.mirrors!;
      game.currentRoomId = 'mirror_gallery';
      game.setActive(light);
      for (final c in game.creatures) {
        c.position = ring.frameAt(ring.lodestoneIndex);
      }
      game.activateAbility();
      return game;
    }

    void silver(PlanetDungeonGame game, MirrorRing ring, int i) {
      game.setActive(ice);
      game.creatures[ice].position = ring.frameAt(i);
      game.activateAbility();
    }

    test('the lodestone is a HARD gate: no frost, no other family', () {
      final stamped = <String>[];
      final game = _harness([
        _member(0, 'Ice', 'mane'),
        _member(1, 'Light', 'horn'), // wrong family on purpose
        _member(2, 'Air', 'wing'),
      ], onCloud: stamped.add);
      final ring = game.layout.rooms['mirror_gallery']!.rime!.mirrors!;
      game.currentRoomId = 'mirror_gallery';

      game.setActive(ice);
      game.creatures[ice].position = ring.frameAt(ring.lodestoneIndex);
      game.activateAbility();
      expect(game.lodestoneLit, isFalse);

      game.setActive(light);
      game.creatures[light].position = ring.frameAt(ring.lodestoneIndex);
      game.activateAbility();
      expect(game.lodestoneLit, isFalse);
      expect(stamped, contains('gate:light_mask'));
    });

    test('the water is dead until the lodestone is struck', () {
      final game = _harness(_idealTrio());
      final ring = game.layout.rooms['mirror_gallery']!.rime!.mirrors!;
      game.currentRoomId = 'mirror_gallery';
      silver(game, ring, 3);
      expect(game.silveredFrames, isEmpty, reason: 'nothing to build in yet');
      expect(game.hintHasAnswer, isTrue);
    });

    test('the anchor goes into the water with the strike', () {
      final game = _gallery();
      final ring = game.layout.rooms['mirror_gallery']!.rime!.mirrors!;
      expect(game.lodestoneLit, isTrue);
      expect(game.silveredFrames, contains(ring.lodestoneIndex));
      expect(
        game.frameOffset[ring.lodestoneIndex],
        0,
        reason: 'the one frame the room is chained from cannot lie',
      );
    });

    test('no two false frames sit side by side', () {
      // Two adjacent frames left out would leave a stretch of chart nothing
      // covers, and the puzzle would have no answer at all.
      for (var run = 0; run < 40; run++) {
        final game = _gallery();
        final ring = game.layout.rooms['mirror_gallery']!.rime!.mirrors!;
        final bad = game.mirrorFalseFrames;
        expect(bad.length, inInclusiveRange(3, 5));
        for (final i in bad) {
          expect(bad, isNot(contains((i + 1) % ring.count)));
          expect(bad, isNot(contains((i - 1 + ring.count) % ring.count)));
        }
      }
    });

    test('silvering the WHOLE ring never wins it', () {
      // The brute-force move, and the one that has to fail: a false frame in
      // the water forks the chart wherever it overlaps its neighbours.
      final earned = <int>[];
      final game = _harness(_idealTrio(), onStar: earned.add);
      final ring = game.layout.rooms['mirror_gallery']!.rime!.mirrors!;
      game.currentRoomId = 'mirror_gallery';
      game.setActive(light);
      for (final c in game.creatures) {
        c.position = ring.frameAt(ring.lodestoneIndex);
      }
      game.activateAbility();
      for (var i = 0; i < ring.count; i++) {
        if (i == ring.lodestoneIndex) continue;
        silver(game, ring, i);
      }
      expect(game.silveredFrames.length, ring.count);
      expect(game.chartStarsWhole, lessThan(kIceChartStars));
      expect(earned, isEmpty);
    });

    test('leaving out exactly the false frames closes the chart', () {
      final earned = <int>[];
      final game = _harness(_idealTrio(), onStar: earned.add);
      final ring = game.layout.rooms['mirror_gallery']!.rime!.mirrors!;
      game.currentRoomId = 'mirror_gallery';
      game.setActive(light);
      for (final c in game.creatures) {
        c.position = ring.frameAt(ring.lodestoneIndex);
      }
      game.activateAbility();
      // Read the board at the moment of acting, never before (§7.9).
      final bad = game.mirrorFalseFrames;
      for (var i = 0; i < ring.count; i++) {
        if (i == ring.lodestoneIndex || bad.contains(i)) continue;
        silver(game, ring, i);
      }
      expect(game.chartStarsWhole, kIceChartStars);
      expect(earned, contains(0));
    });

    test('a mark is never spent: frost goes on and comes off', () {
      final game = _gallery();
      final ring = game.layout.rooms['mirror_gallery']!.rime!.mirrors!;
      final i = (ring.lodestoneIndex + 3) % ring.count;
      silver(game, ring, i);
      expect(game.silveredFrames, contains(i));
      silver(game, ring, i);
      expect(game.silveredFrames, isNot(contains(i)));
    });

    test('THE WHOLE SEARCH: what wins, and that winning is possible', () {
      // Every set of frames the player could put in the water, checked
      // against the room's own rule. A set wins exactly when it covers all
      // 24 stars and holds no frame that is hung false — which is the thing
      // the seams are evidence FOR, and never evidence of on their own.
      final game = _gallery();
      final ring = game.layout.rooms['mirror_gallery']!.rime!.mirrors!;
      final bad = game.mirrorFalseFrames;
      final others = [
        for (var i = 0; i < ring.count; i++)
          if (i != ring.lodestoneIndex) i,
      ];
      var wins = 0;
      for (var mask = 0; mask < (1 << others.length); mask++) {
        game.silveredFrames
          ..clear()
          ..add(ring.lodestoneIndex);
        for (var b = 0; b < others.length; b++) {
          if (mask & (1 << b) != 0) game.silveredFrames.add(others[b]);
        }
        final whole = game.chartStarsWhole == kIceChartStars;
        if (whole) {
          wins++;
          expect(
            game.silveredFrames.intersection(bad),
            isEmpty,
            reason: 'a false frame in the water must always fork the chart',
          );
        }
      }
      expect(wins, greaterThan(0), reason: 'the room must be solvable');
    });

    test('THE LIGHT HAND IS THE LAMP, wherever it is standing', () {
      final game = _gallery();
      final ring = game.layout.rooms['mirror_gallery']!.rime!.mirrors!;

      // No lamp at the rim: black glass, whoever you are driving.
      for (final c in game.creatures) {
        c.position = ring.center;
      }
      for (var k = 0; k < kIceChartStars; k++) {
        expect(
          game.chartStarVisible(ring, k),
          isFalse,
          reason: 'a lamp over the water has no far side to be read from',
        );
      }

      // Park the Light hand at the rim and drive ICE somewhere else: the
      // water still reads, because the lamp is where you left it.
      game.setActive(ice);
      game.creatures[light].position = ring.frameAt(0);
      game.creatures[ice].position = ring.frameAt(4);
      final far = [
        for (var k = 0; k < kIceChartStars; k++)
          if (game.chartStarVisible(ring, k)) k,
      ];
      expect(far, isNotEmpty, reason: 'the parked lamp keeps reading');
      expect(
        far.every((k) => k > kIceChartStars / 6 && k < 5 * kIceChartStars / 6),
        isTrue,
        reason: 'what it reads is the far side, never the water at its feet',
      );

      // Take the LIGHT hand away and the water closes: the reading is the
      // lamp's, not the party's.
      game.creatures[light].position = ring.center;
      for (var k = 0; k < kIceChartStars; k++) {
        expect(game.chartStarVisible(ring, k), isFalse);
      }
    });

    test('the lamp reads a different stretch from a different place', () {
      final game = _gallery();
      final ring = game.layout.rooms['mirror_gallery']!.rime!.mirrors!;
      game.creatures[light].position = ring.frameAt(0);
      final here = {
        for (var k = 0; k < kIceChartStars; k++)
          if (game.chartStarVisible(ring, k)) k,
      };
      game.creatures[light].position = ring.frameAt(6);
      final there = {
        for (var k = 0; k < kIceChartStars; k++)
          if (game.chartStarVisible(ring, k)) k,
      };
      expect(here, isNotEmpty);
      expect(there, isNotEmpty);
      expect(
        here.intersection(there).length,
        lessThan(here.length),
        reason: 'walking the lamp is how the chart is read',
      );
    });

    test('the lamp eases off at the edge of its reach', () {
      // Jaggy on a device: the water snapped open and shut star by star as
      // the light walked. The reach falls away instead of ending.
      final game = _gallery();
      final ring = game.layout.rooms['mirror_gallery']!.rime!.mirrors!;
      game.creatures[light].position = ring.frameAt(0);
      final partial = [
        for (var k = 0; k < kIceChartStars; k++)
          if (game.chartStarLight(ring, k) > 0 &&
              game.chartStarLight(ring, k) < 1)
            k,
      ];
      expect(
        partial,
        isNotEmpty,
        reason: 'there has to be an edge that is neither lit nor dark',
      );
    });

    test('BANKING THE STAR LIGHTS THE CHART UP, and it stays lit', () {
      final earned = <int>[];
      final game = _harness(_idealTrio(), onStar: earned.add);
      final ring = game.layout.rooms['mirror_gallery']!.rime!.mirrors!;
      game.currentRoomId = 'mirror_gallery';
      game.setActive(light);
      for (final c in game.creatures) {
        c.position = ring.frameAt(ring.lodestoneIndex);
      }
      game.activateAbility();
      expect(game.chartTriumph, 0);

      final bad = game.mirrorFalseFrames;
      game.setActive(ice);
      for (var i = 0; i < ring.count; i++) {
        if (i == ring.lodestoneIndex || bad.contains(i)) continue;
        game.creatures[ice].position = ring.frameAt(i);
        game.activateAbility();
      }
      expect(earned, contains(0));
      expect(game.chartTriumph, greaterThan(0), reason: 'the light-up runs');

      // It runs down, and the solved chart stays readable afterwards — with
      // the lamp parked over the water, where it would otherwise show none.
      for (var t = 0.0; t < 5; t += 1 / 60) {
        game.update(1 / 60);
      }
      expect(game.chartTriumph, 0);
      game.creatures[light].position = ring.center;
      for (var k = 0; k < kIceChartStars; k++) {
        expect(
          game.chartStarVisible(ring, k),
          isTrue,
          reason: 'a trophy you have to walk a lamp round is not a trophy',
        );
      }
    });

    test('an Air sweep FLASHES the whole chart, then it fades back', () {
      // A glimpse, not a reveal (2026-09-20): the sweep used to still the
      // water for 12s, which made it the way to read the room and the lamp a
      // formality. Now it holds for half a second, fades, and the water is
      // the lamp's again.
      final game = _gallery();
      final ring = game.layout.rooms['mirror_gallery']!.rime!.mirrors!;
      game.creatures[light].position = ring.frameAt(0);
      final before = [
        for (var k = 0; k < kIceChartStars; k++) game.chartStarLight(ring, k),
      ];
      final dark = [
        for (var k = 0; k < kIceChartStars; k++)
          if (before[k] == 0) k,
      ];
      expect(dark, isNotEmpty);
      expect(before.any((b) => b > 0), isTrue);
      game.setActive(air);
      game.creatures[air].position = ring.vent;
      game.activateAbility();
      expect(game.sweepLight, 1.0);
      for (final k in dark) {
        expect(game.chartStarLight(ring, k), 1.0, reason: 'the flash');
      }
      // Still whole at the end of the hold.
      for (var i = 0; i < 24; i++) {
        game.update(1 / 60);
      }
      for (final k in dark) {
        expect(game.chartStarLight(ring, k), 1.0, reason: 'held for 0.5s');
      }
      // Half-way through the fade: dimmer, and not gone.
      for (var i = 0; i < 40; i++) {
        game.update(1 / 60);
      }
      expect(game.sweepLight, lessThan(0.7));
      expect(game.sweepLight, greaterThan(0.2));
      for (final k in dark) {
        expect(game.chartStarLight(ring, k), game.sweepLight);
      }
      // Gone, and the lamp's stretch is exactly what it was.
      for (var i = 0; i < 60; i++) {
        game.update(1 / 60);
      }
      expect(game.sweepLight, 0);
      for (final k in dark) {
        expect(game.chartStarVisible(ring, k), isFalse, reason: 'faded');
      }
      for (var k = 0; k < kIceChartStars; k++) {
        expect(
          game.chartStarLight(ring, k),
          before[k],
          reason: 'the lamp holds',
        );
      }
    });
  });

  group('THE MOUTH — the first room of the planet', () {
    test('either hole is the same plate, and both answer', () {
      // The cap seals the whole floor. It used to answer at ONE hole, so a
      // player who walked to the other one got no melt, no refusal and no
      // reason — and concluded the ELEMENT was wrong rather than the spot.
      for (final f in kRimeFlues.where((f) => f.headRoom == 'rime_head')) {
        final game = _harness(_idealTrio());
        game.setActive(light);
        for (final c in game.creatures) {
          c.position = f.headPos;
        }
        game.activateAbility();
        expect(
          game.entryDoorRevealed,
          isTrue,
          reason: 'Light at ${f.id}\'s mouth must drink the same plate',
        );
      }
    });

    test('the wrong hand is refused at either hole, and told why', () {
      for (final f in kRimeFlues.where((f) => f.headRoom == 'rime_head')) {
        final game = _harness(_idealTrio());
        game.setActive(ice);
        for (final c in game.creatures) {
          c.position = f.headPos;
        }
        game.activateAbility();
        expect(game.entryDoorRevealed, isFalse);
        // §5.6: an unasked refusal is REMEMBERED, not spoken. It is held for
        // the hint button, which is where the player goes to ask.
        expect(game.hintHasAnswer, isTrue);
        game.askForRoomHint();
        expect(game.hintText, contains('Light'));
      }
    });

    test('the floor says what the plate is, once, at the hole', () {
      final game = _harness(_idealTrio());
      game.beginRun();
      // The primer owns the arrival: it is the rule of the whole shaft.
      expect(game.hintText, contains(game.layout.primer.first));

      // Walk up to a hole and the plate names itself, unasked.
      final cap = game.layout.rooms['rime_head']!.rime!.iceCap!;
      for (final c in game.creatures) {
        c.position = cap;
      }
      game.update(1 / 60);
      expect(game.hintText, contains('black ice'));

      // Once. Never again.
      game.hintText = null;
      game.update(1 / 60);
      expect(game.hintText, isNull);
    });
  });

  group('A CLOSING ANNOUNCES ITSELF (§5.7)', () {
    test('the thaw is spoken on the arrival it happens on', () {
      // It was set as a hint by `passThroughDoor` and wiped by the same call
      // one line later, so this planet's one world-scale act was silent.
      final game = _harness(_idealTrio());
      game.beginRun(); // the mouth's one-time teach is spent on arrival
      final sump = game.layout.rooms['cold_sump']!;
      game.currentRoomId = 'cold_sump';
      game.flueState['flue_a'] = RimeFlueState.stair;
      game.rimefallFrozen = true;
      game.passThroughDoor(
        sump.doors.firstWhere((d) => d.targetRoomId == 'rime_head'),
      );
      expect(game.currentRoomId, 'rime_head');
      expect(
        game.hintText,
        contains('shaft resets'),
        reason: 'the room named itself over the top of the thaw',
      );
    });

    test(
      'the price is told at the foot of the rimefall, before it is paid',
      () {
        final game = _harness(_idealTrio());
        final sump = game.layout.rooms['cold_sump']!;
        final door = sump.doors.firstWhere(
          (d) => d.targetRoomId == 'rime_head',
        );
        game.currentRoomId = 'cold_sump';
        game.rimefallFrozen = true;

        // At the foot of the stair, NOT on it — standing on a door rect
        // walks you through it.
        final foot = door.rect.center + const Offset(0, 80);
        for (final c in game.creatures) {
          c.position = foot;
        }
        // Nothing cut: the climb is free and the line would be noise.
        game.update(1 / 60);
        expect(game.hintText, isNot(contains('shaft resets')));
        expect(game.currentRoomId, 'cold_sump');

        // A stair standing: now it costs, so now it says so — UNASKED,
        // because a warning held back for the hint button is not a warning.
        game.flueState['flue_b'] = RimeFlueState.stair;
        game.update(1 / 60);
        expect(game.hintText, contains('resets the whole shaft'));

        // And never again: it is a teach, not a nag.
        game.hintText = null;
        game.update(1 / 60);
        expect(game.hintText, isNull);
      },
    );
  });

  group('the shaft is AUDIBLE', () {
    // The sound funnel has been silently undone on this planet once before
    // (a worktree merge, §7.10), and a planet with one cue in it is a planet
    // nobody hears. These are the beats the shaft is made of.
    test('every beat of the shaft speaks', () {
      final heard = <SoundCue>[];
      final game = _harness(_idealTrio(), onSound: heard.add);

      // The cap.
      final head = game.layout.rooms['rime_head']!;
      game.setActive(light);
      game.creatures[light].position = head.rime!.iceCap!;
      game.activateAbility();
      expect(heard, contains(SoundCue.dungeonGateOpen));

      // A freeze.
      heard.clear();
      game.setActive(ice);
      game.creatures[ice].position = kRimeFlues
          .firstWhere((f) => f.id == 'flue_a')
          .headPos;
      game.activateAbility();
      expect(heard, contains(SoundCue.elementIce));

      // A ride that scours — the SHAFT, not the chute: a ledge chute is a
      // ramp every time, and spends nothing to be heard.
      heard.clear();
      game.flueState['flue_b'] = RimeFlueState.drift;
      final gallery = game.layout.rooms['mirror_gallery']!;
      game.currentRoomId = 'mirror_gallery';
      game.onShaftTransitForTest(
        gallery,
        gallery.doors.firstWhere((d) => d.targetRoomId == 'orrery_floor'),
      );
      expect(heard, contains(SoundCue.dungeonHazardTrigger));
      expect(game.flueState['flue_b'], RimeFlueState.scoured);

      // A stretch of chart put into the water.
      heard.clear();
      final ring = gallery.rime!.mirrors!;
      game.lodestoneLit = true;
      game.setActive(ice);
      game.update(1 / 60);
      game.creatures[ice].position = ring.frameAt(3);
      game.activateAbility();
      expect(heard, contains(SoundCue.dungeonSwitch));

      // A block on its road.
      heard.clear();
      game.currentRoomId = 'orrery_floor';
      final grid = game.layout.rooms['orrery_floor']!.rime!.orrery!;
      game.orreryGlass.add(2 * grid.cols + 2);
      game.setActive(air);
      for (final c in game.creatures) {
        c
          ..position = grid.centerAt(0, 2)
          ..angle = 0
          ..aimAngle = 0;
      }
      game.activateAbility();
      expect(heard, contains(SoundCue.dungeonBlockMove));
    });
  });

  group('THE LOST MAXIM · STAR-WALKER — the stranger', () {
    // The maxim standard (§7): a CHAIN — ride flue A bare so the shaft over
    // the pool is a mirror; wake the water and read the stranger's bearing;
    // ride chute B; turn the lens to the bearing; lock the sighting. Every
    // link is proved here against the same code the buttons call.
    final ring = layout.rooms['mirror_gallery']!.rime!.mirrors!;
    const bearing = 4;

    /// The gallery awake, and the lamp parked ACROSS from the bearing — the
    /// only place the water reads it from.
    PlanetDungeonGame awake() {
      final game = _harness(_idealTrio());
      game.currentRoomId = 'mirror_gallery';
      game.strangerFrame = bearing;
      game.setActive(light);
      for (final c in game.creatures) {
        c.position = ring.frameAt(ring.lodestoneIndex);
      }
      game.activateAbility(); // Light+Mask strikes the lodestone
      expect(game.lodestoneLit, isTrue);
      game.creatures[light].position = ring.frameAt(
        (bearing + ring.count ~/ 2) % ring.count,
      );
      return game;
    }

    /// The lens niche, with the sighting already shown (or not) upstairs.
    PlanetDungeonGame niche({bool seen = true, int notch = 0}) {
      final game = _harness(_idealTrio());
      final lens = layout.rooms['shelf_lens']!.rime!.telescope!;
      game.currentRoomId = 'shelf_lens';
      game.strangerFrame = bearing;
      game.strangerSeen = seen;
      game.telescopeNotch = notch;
      for (final c in game.creatures) {
        c.position = lens;
      }
      return game;
    }

    test('the stranger hangs only over a shaft ridden BARE', () {
      final game = awake();
      // Drift: snow shows the water nothing.
      expect(game.shaftAboveIsMirror, isFalse);
      expect(game.strangerLight(ring), 0);
      game.update(1 / 60);
      expect(game.strangerSeen, isFalse);
      // A stair: cut steps show it nothing either. Doing the RIGHT thing on
      // the way down is exactly what hides the secret.
      game.flueState['flue_a'] = RimeFlueState.stair;
      expect(game.strangerLight(ring), 0);
      // Bare ice is a mirror, and the sky is in it.
      game.flueState['flue_a'] = RimeFlueState.scoured;
      expect(game.shaftAboveIsMirror, isTrue);
      expect(game.strangerLight(ring), 1.0);
      game.update(1 / 60);
      expect(game.strangerSeen, isTrue);
      // Said once, unasked, the first time — the star is new in the water.
      expect(game.hintText, contains('no frame charts'));
    });

    test('and only where the water is reading', () {
      final game = awake();
      game.flueState['flue_a'] = RimeFlueState.scoured;
      // A lamp on the SAME side reads the far side; the stranger stays dark.
      game.creatures[light].position = ring.frameAt(bearing);
      expect(game.strangerLight(ring), 0);
      game.update(1 / 60);
      expect(game.strangerSeen, isFalse);
      // Air's sweep stills the whole surface, and that shows it too.
      game.setActive(air);
      game.creatures[air].position = ring.vent;
      game.activateAbility();
      expect(game.strangerLight(ring), 1.0);
      game.update(1 / 60);
      expect(game.strangerSeen, isTrue);
    });

    test('the water is dead until the lodestone wakes it, stranger or no', () {
      final game = _harness(_idealTrio());
      game.currentRoomId = 'mirror_gallery';
      game.strangerFrame = bearing;
      game.flueState['flue_a'] = RimeFlueState.scoured;
      game.creatures[light].position = ring.frameAt(
        (bearing + ring.count ~/ 2) % ring.count,
      );
      game.update(1 / 60);
      expect(game.lodestoneLit, isFalse);
      expect(game.strangerLight(ring), 0);
      expect(game.strangerSeen, isFalse);
    });

    test('the roll never lands on the rest position', () {
      for (var i = 0; i < 40; i++) {
        final game = _harness(_idealTrio());
        expect(game.strangerFrame, isNot(ring.lodestoneIndex));
        expect(game.strangerFrame, inInclusiveRange(0, ring.count - 1));
        expect(game.telescopeNotch, ring.lodestoneIndex);
        expect(game.strangerSeen, isFalse);
      }
    });

    test('the lens refuses a sighting the water has not shown', () {
      final game = niche(seen: false, notch: bearing);
      game.setActive(ice);
      game.activateAbility();
      expect(game.riteActive, isFalse);
      // §5.6: a refusal is held for the hint button, and names WHAT is
      // missing — never how to get it.
      expect(game.hintHasAnswer, isTrue);
      game.askForRoomHint();
      expect(game.hintText, contains('where the water saw'));
    });

    test('Air turns the wheel a notch a breath, and it comes round', () {
      final game = niche();
      game.setActive(air);
      for (var i = 1; i <= ring.count; i++) {
        game.activateAbility();
        expect(game.telescopeNotch, i % ring.count);
        expect(game.riteActive, isFalse);
      }
    });

    test('frost on the wrong bearing is empty sky, and costs nothing', () {
      final game = niche(notch: bearing - 1);
      game.setActive(ice);
      game.activateAbility();
      expect(game.riteActive, isFalse);
      expect(game.telescopeNotch, bearing - 1);
      expect(game.strangerSeen, isTrue);
      expect(game.discoveredClouds, isNot(contains(kIceStarWalkerEggId)));
      // §5.6: the world does not narrate an unasked tap. The puff of frost
      // is the answer; the sentence waits for the hint button like every
      // other world-response line on the planet.
      expect(game.hintText, isNull);
    });

    test('a Light hand in the lens sees only itself', () {
      final game = niche(notch: bearing);
      game.setActive(light);
      game.activateAbility();
      expect(game.riteActive, isFalse);
      expect(game.telescopeNotch, bearing);
    });

    test('THE SIGHTING LANDS on the stranger\'s bearing, and pays out', () {
      final game = niche(notch: bearing);
      game.setActive(ice);
      game.activateAbility();
      expect(game.riteActive, isTrue);
      // The rite of three binds, and the screen is paid.
      for (var i = 0; i < 200; i++) {
        game.update(1 / 60);
      }
      expect(game.discoveredClouds, contains(kIceStarWalkerEggId));
      // Found once, the lens is done: nothing answers at it again.
      game.setActive(air);
      final notch = game.telescopeNotch;
      game.activateAbility();
      expect(game.telescopeNotch, notch);
    });

    test('the sighting is reached by turning, not by knowing the code', () {
      // Twelve breaths and a press each is the brute-force ceiling — and it
      // still needs the water to have shown the stranger first.
      final game = niche(seen: true, notch: 0);
      var landed = false;
      for (var i = 0; i < ring.count && !landed; i++) {
        game.setActive(ice);
        game.activateAbility();
        landed = game.riteActive;
        if (!landed) {
          game.setActive(air);
          game.activateAbility();
        }
      }
      expect(landed, isTrue);
      expect(game.telescopeNotch, bearing);
    });

    test('THE SOLVED CHART STANDS when you walk back in', () {
      // A later descent, the Mirror Star already banked: the pool used to
      // open dead black with every frame dark, as if never solved.
      final game = _harness(_idealTrio());
      game.starMask = 1 << 0; // onLoad would read this off the save
      game.currentRoomId = 'mirror_gallery';
      game.update(1 / 60);
      expect(game.lodestoneLit, isTrue);
      expect(game.mirrorChart, hasLength(kIceChartStars));
      expect(game.silveredFrames, hasLength(ring.count));
      expect(game.chartStarsWhole, kIceChartStars);
      // And the stranger reads without a lamp, once the shaft is bare — the
      // secret stays open to a player who cleared the stars first.
      game.strangerFrame = bearing;
      expect(game.strangerLight(ring), 0);
      game.flueState['flue_a'] = RimeFlueState.scoured;
      expect(game.strangerLight(ring), 1.0);
    });

    test('the star path never passes it', () {
      // The niche is a shelf: nothing on it banks a star, and the Frost Star
      // is reached down flue C with A frozen — the shaft never bare.
      final niche = layout.rooms['shelf_lens']!;
      expect(niche.rime?.starIndex, isNull);
      expect(niche.doors.map((d) => d.targetRoomId), ['mirror_gallery']);
      final game = _harness(_idealTrio());
      game.flueState['flue_a'] = RimeFlueState.stair;
      expect(game.shaftAboveIsMirror, isFalse);
    });
  });

  group('the rite and the guardian', () {
    test('the font refuses until both stars are banked, then sings', () {
      final game = _harness(_idealTrio());
      final room = game.layout.rooms['star_font']!;
      game.currentRoomId = 'star_font';
      game.setActive(ice);
      game.creatures[ice].position = room.rime!.coldFont!;
      game.activateAbility();
      expect(game.conduitEnergy['B'] ?? 0, 0);

      game.earnStar(0);
      game.earnStar(1);
      game.activateAbility();
      expect(game.conduitEnergy['B'], double.infinity);
    });

    test('Frowyrm keeps its lull shut while the hoarfrost is down', () {
      final game = _harness(_idealTrio());
      final room = game.layout.rooms['frowyrm_hollow']!;
      game.currentRoomId = 'frowyrm_hollow';
      game.guardianAwake = true;
      game.guardianVulnerable = true;
      game.hoarfrostWhole = false;
      game.update(1 / 60);
      expect(game.guardianVulnerable, isFalse);

      game.setActive(ice);
      game.creatures[ice].position = room.rime!.hoarfrost!;
      game.activateAbility();
      expect(game.hoarfrostWhole, isTrue);
    });
  });

  group('THE ROOF OF THE HOLLOW — the rite', () {
    // The rite room's floor is the ice over the wyrm's lair (2026-09-20).
    // Snow bears all and shows nothing; Light bares a pane and bare ice over
    // the hollow bears one body; every bared pane says which way the head
    // lies; the glass over the head is the throat the breath goes down and,
    // once the wyrm is awake, the way in — for all three together.
    final room = layout.rooms['star_font']!;
    final roof = room.rime!.roof!;
    // A wyrm laid by hand: head at (3,3), body west along row 3 and down.
    const wyrm = [30, 29, 28, 37, 38];

    PlanetDungeonGame onTheRoof({List<CosmicPartyMember>? party}) {
      final game = _harness(party ?? _idealTrio());
      game.currentRoomId = 'star_font';
      game.earnStar(0);
      game.earnStar(1);
      game.seedRoofForTest(wyrm);
      for (final c in game.creatures) {
        c
          ..position = const Offset(400, 70)
          ..lastSafe = const Offset(400, 70);
      }
      return game;
    }

    /// Stand [who] at [p] facing [angle], make them active, and press.
    void press(PlanetDungeonGame g, int who, Offset p, double angle) {
      g.setActive(who);
      g.creatures[who]
        ..position = p
        ..aimAngle = angle;
      g.activateAbility();
    }

    const down = pi / 2, left = pi, right = 0.0;

    test('the roof is authored honestly: one pier, an island, and water', () {
      expect(roof.cols, 9);
      expect(roof.rows, 5);
      final pier = roof.pierCell;
      expect(roof.centerAt(pier), room.rime!.coldFont);
      // Water on three sides of the pier, hollow on the fourth: the font is
      // reached across the roof or by Ice freezing a way.
      final around = roof.neighbours(pier);
      expect(around.where(roof.waterAt).length, 3);
      expect(
        around
            .where(
              (c) => roof.bedAt(c) == IceRoofBed.hollow && !roof.waterAt(c),
            )
            .length,
        1,
      );
      // The way in is never a door on a wall.
      final drop = room.doors.firstWhere(
        (d) => d.targetRoomId == 'frowyrm_hollow',
      );
      final game = _harness(_idealTrio());
      expect(game.isDoorHidden(room, drop), isTrue);
    });

    test('the wyrm is rolled as a connected line of hollow panes', () {
      for (var roll = 0; roll < 40; roll++) {
        final game = _harness(_idealTrio());
        final w = game.roofWyrm;
        expect(w.length, kIceWyrmLength, reason: 'roll $roll');
        expect(w.toSet().length, w.length, reason: 'no pane twice');
        for (var i = 0; i < w.length; i++) {
          expect(roof.bedAt(w[i]), IceRoofBed.hollow, reason: 'roll $roll');
          expect(game.roofIsWater(w[i]), isFalse, reason: 'roll $roll');
          if (i > 0) {
            expect(roof.adjacent(w[i - 1], w[i]), isTrue, reason: 'roll $roll');
          }
        }
        // And the authored water is water from the start.
        for (var c = 0; c < roof.count; c++) {
          expect(game.roofIsWater(c), roof.waterAt(c));
        }
        expect(game.roofBare, isEmpty);
        expect(game.roofThroat, isNull);
      }
    });

    test('Light bares the pane AHEAD, and the ice says what it lies on', () {
      final game = onTheRoof();
      // From the near shore, facing down: the first pane of the roof.
      press(game, light, Offset(roof.centerAt(1).dx, 100), down);
      expect(game.roofTargetCell(game.creatures[light]), 1);
      expect(game.roofBare, contains(1));
      expect(game.hintText, contains('Dark water under this ice'));
      // The rule is said once, the first time the hollow shows.
      expect(game.discoveredClouds, contains(kIceRoofTeachId));
      // Standing on that pane, facing the corner: rock.
      press(game, light, roof.centerAt(1), left);
      expect(game.roofBare, contains(0));
      // A reading is held for the hint button (the dungeon does not narrate).
      game.askForRoomHint();
      expect(game.hintText, contains('Stone under this ice'));
      // Never the pane under your own feet.
      expect(game.roofTargetCell(game.creatures[light]), isNot(1));
    });

    test(
      'every bared pane is a bearing: the drift runs AWAY from the head',
      () {
        final game = onTheRoof();
        final head = roof.centerAt(wyrm.first);
        for (var c = 0; c < roof.count; c++) {
          if (roof.bedAt(c) != IceRoofBed.hollow || wyrm.contains(c)) continue;
          final d = game.roofDrift(roof, c);
          final away = roof.centerAt(c) - head;
          expect(
            d.dx * away.dx + d.dy * away.dy,
            greaterThan(0),
            reason: 'pane $c',
          );
        }
        // And under the body, the scales run TOWARD the head.
        for (var i = 1; i < wyrm.length; i++) {
          final run = game.roofScaleRun(roof, wyrm[i]);
          final toHead = roof.centerAt(wyrm[i - 1]) - roof.centerAt(wyrm[i]);
          expect(run.dx * toHead.dx + run.dy * toHead.dy, greaterThan(0));
        }
        expect(game.roofScaleRun(roof, wyrm.first), Offset.zero);
      },
    );

    test('snow bears all; bare glass over the hollow bears ONE body', () {
      final game = onTheRoof();
      game.setActive(ice);
      // Snow, with Light already standing on it: Ice may join.
      game.creatures[light].position = roof.centerAt(10);
      expect(game.shaftBlocksAtForTest(roof.centerAt(10)), isFalse);
      // Bared, it is thin, and Light is on it: Ice is refused, and told why.
      game.roofBare.add(10);
      expect(game.shaftBlocksAtForTest(roof.centerAt(10)), isTrue);
      game.update(1 / 60);
      expect(game.hintHasAnswer, isTrue, reason: 'a refusal is remembered');
      game.askForRoomHint();
      expect(game.hintText, contains('only holds one'));
      // Bare glass over ROCK is thick: the corner bears the whole party.
      game.roofBare.add(0);
      game.creatures[light].position = roof.centerAt(0);
      game.creatures[air].position = roof.centerAt(0);
      expect(game.shaftBlocksAtForTest(roof.centerAt(0)), isFalse);
      // Water bears nobody, and says nothing about it.
      expect(game.shaftBlocksAtForTest(roof.centerAt(4)), isTrue);
    });

    test('Light melts bare glass to water, Ice freezes it back thin', () {
      final game = onTheRoof();
      game.roofBare.add(10);
      // Light on pane 1 facing down works pane 10.
      press(game, light, roof.centerAt(1), down);
      expect(game.roofIsWater(10), isTrue);
      // Ice, same spot: the water takes frost again, thin.
      press(game, ice, roof.centerAt(1), down);
      expect(game.roofIsWater(10), isFalse);
      expect(game.roofIsBare(10), isTrue);
      expect(game.roofIsThin(roof, 10), isTrue);
      // Stone will not open, and a pane with a body on it will not be melted
      // from under them.
      game.roofBare.add(0);
      press(game, light, roof.centerAt(1), left);
      expect(game.roofIsWater(0), isFalse);
      game.askForRoomHint();
      expect(game.hintText, contains('Nothing to open'));
      game.creatures[air].position = roof.centerAt(10);
      press(game, light, roof.centerAt(1), down);
      expect(game.roofIsWater(10), isFalse);
      game.askForRoomHint();
      expect(game.hintText, contains('standing on that ice'));
    });

    test('the glass over the head opens into the THROAT, twice pressed', () {
      final game = onTheRoof();
      // Light on pane 31 facing west works pane 30 — the head.
      press(game, light, roof.centerAt(31), left);
      expect(game.roofBare, contains(30));
      expect(game.hintText, contains('head is under this ice'));
      expect(game.roofThroat, isNull);
      press(game, light, roof.centerAt(31), left);
      expect(game.roofThroat, 30);
      expect(game.roofIsWater(30), isFalse);
      // Frost will not close it again.
      press(game, ice, roof.centerAt(31), left);
      expect(game.roofThroat, 30);
      game.askForRoomHint();
      expect(game.hintText, contains('stops this from freezing'));
      // Sealed, it bears nobody: the wyrm is asleep under it.
      game.setActive(ice);
      expect(game.shaftBlocksAtForTest(roof.centerAt(30)), isTrue);
    });

    test('the breath is the Air+WING gate, and it stamps its own chip', () {
      final stamped = <String>[];
      final game = _harness([
        _member(0, 'Ice', 'mane'),
        _member(1, 'Light', 'mask'),
        _member(2, 'Air', 'pip'), // wrong family
      ], onCloud: stamped.add);
      game.currentRoomId = 'star_font';
      game.earnStar(0);
      game.earnStar(1);
      game.seedRoofForTest(wyrm);
      game.roofBare.add(30);
      game.roofThroat = 30;
      // No throat open elsewhere: Air is told what is missing.
      press(game, air, roof.centerAt(1), down);
      game.askForRoomHint();
      expect(game.hintText, contains('over the wyrm\'s head first'));
      // At the throat, the wrong family is refused and the seal remembers.
      press(game, air, roof.centerAt(31), left);
      expect(game.conduitEnergy['A'] ?? 0, 0);
      expect(stamped, contains('gate:air_wing'));
    });

    test('the Wing turns the breath down the throat, once the stars allow', () {
      final game = _harness(_idealTrio());
      game.currentRoomId = 'star_font';
      game.seedRoofForTest(wyrm);
      game.roofBare.add(30);
      game.roofThroat = 30;
      press(game, air, roof.centerAt(31), left);
      expect(game.conduitEnergy['A'] ?? 0, 0, reason: 'no stars, no breath');
      game.askForRoomHint();
      expect(game.hintText, contains('Mirror Star'));
      game.earnStar(0);
      game.earnStar(1);
      press(game, air, roof.centerAt(31), left);
      expect(game.conduitEnergy['A'], double.infinity);
    });

    test(
      'on the pier, Ice sings the font; the water round it is frozen from the roof',
      () {
        final game = onTheRoof();
        final pier = roof.pierCell;
        // Standing on the pier facing the water: the FONT answers, not the
        // water (a body on the pier is working the font).
        press(game, ice, roof.centerAt(pier), right);
        expect(game.conduitEnergy['B'], double.infinity);
        expect(game.roofIsWater(pier + 1), isTrue);
        // From the hollow pane below, facing up at the pier's water neighbour
        // — no: facing the water beside it from the roof freezes it.
        press(game, ice, roof.centerAt(pier + roof.cols + 1), -pi / 2);
        expect(game.roofIsWater(pier + 1), isFalse);
      },
    );

    test('both halves sung, the wyrm wakes under the roof', () {
      final game = onTheRoof();
      game.roofBare.add(30);
      game.roofThroat = 30;
      press(game, ice, roof.centerAt(roof.pierCell), down);
      expect(game.conduitEnergy['B'], double.infinity);
      expect(game.guardianAwake, isFalse, reason: 'half a rite wakes nothing');
      press(game, air, roof.centerAt(31), left);
      game.update(1 / 60);
      expect(game.altarOpen, isTrue);
      expect(game.guardianAwake, isTrue);
      expect(game.hintText, contains('wyrm stirs'));
    });

    test('the throat takes the three of you together, or nobody', () {
      final game = onTheRoof();
      game.roofBare.add(30);
      game.roofThroat = 30;
      game.conduitEnergy['A'] = double.infinity;
      game.conduitEnergy['B'] = double.infinity;
      game.update(1 / 60);
      expect(game.guardianAwake, isTrue);
      game.setActive(ice);
      game.creatures[ice].position = roof.centerAt(31);
      // The others still on the shore: the step in is refused, and told.
      expect(game.shaftBlocksAtForTest(roof.centerAt(30)), isTrue);
      game.update(1 / 60);
      game.askForRoomHint();
      expect(game.hintText, contains('at the edge first'));
      expect(game.currentRoomId, 'star_font');
      // Gathered at the edge — each on their own pane — the step in bears.
      game.creatures[light].position = roof.centerAt(21);
      game.creatures[air].position = roof.centerAt(39);
      expect(game.shaftBlocksAtForTest(roof.centerAt(30)), isFalse);
      game.creatures[ice].position = roof.centerAt(30);
      game.update(1 / 60);
      expect(game.currentRoomId, 'frowyrm_hollow');
      // The hollow's own once-only teach outranks the fall's line on arrival,
      // which is the engine's rule; what matters is that the party went.
      expect(game.guardianAwake, isTrue);
    });

    test('the roof reads itself: arrival, insight, readout', () {
      final game = onTheRoof();
      // Arriving names the room, and what it is the roof OF.
      game.currentRoomId = 'cold_sump';
      final sump = game.layout.rooms['cold_sump']!;
      game.passThroughDoor(
        sump.doors.firstWhere((d) => d.targetRoomId == 'star_font'),
      );
      expect(game.hintText, contains('hollow'));
      final r = game.progressReadout;
      expect(r?.label, 'RITE');
      expect(r?.value, '0/2');
      // The hint button reads the roof, not the shaft.
      game.setActive(light);
      game.askForRoomHint();
      expect(game.hintText, anyOf(contains('glass'), contains('drift')));
    });
  });
}
