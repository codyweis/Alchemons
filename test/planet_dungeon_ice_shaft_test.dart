// GLACIUS — the Frozen Observatory, pinned.
//
// Ice's topology is a VERTICAL SHAFT whose descents are one-way slides, and
// whose vault is "enterable only from a slide you can't repeat" (docs
// §5.5). That combination is a stranding machine unless the state graph is
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

import 'dart:math' show atan2;
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
        reason: 'docs §5.5: enterable only from a slide you cannot repeat',
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

    test('a shelf CAN be lost — the slide really is unrepeatable', () {
      final game = _harness(_idealTrio());
      final r = game.solveShaftDescent();
      expect(
        r.shelfLosable,
        greaterThan(0),
        reason:
            'freezing a flue seals its shelf, and riding it spends it: '
            'without paying a thaw the treasure is gone for the run',
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

    test('RIDING THE CHUTE SPENDS THE CHUTE, AND NOTHING ELSE', () {
      // The whole point of the split. The chute and the shaft are two holes
      // with one destination each, and neither touches the other.
      final game = _harness(_idealTrio());
      openTheFloor(game);
      final head = game.layout.rooms['rime_head']!;
      final chuteDoor = head.doors.firstWhere(
        (d) => d.targetRoomId == 'shelf_glass',
      );
      game.onShaftTransitForTest(head, chuteDoor);

      expect(game.spentChutes, contains('flue_a'));
      expect(
        game.isDoorHidden(head, chuteDoor),
        isTrue,
        reason: 'a bare slot is no ramp',
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

    test('an Air sweep stills the water and shows it all at once', () {
      final game = _gallery();
      final ring = game.layout.rooms['mirror_gallery']!.rime!.mirrors!;
      game.creatures[light].position = ring.frameAt(0);
      final dark = [
        for (var k = 0; k < kIceChartStars; k++)
          if (!game.chartStarVisible(ring, k)) k,
      ];
      expect(dark, isNotEmpty);
      game.setActive(air);
      game.creatures[air].position = ring.vent;
      game.activateAbility();
      expect(game.poolStill, greaterThan(0));
      for (final k in dark) {
        expect(game.chartStarVisible(ring, k), isTrue);
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
        contains('lets go'),
        reason: 'the room named itself over the top of the thaw',
      );
    });

    test('a ride says the snow went with you, and what that leaves', () {
      final game = _harness(_idealTrio());
      game.entryDoorRevealed = true;
      final head = game.layout.rooms['rime_head']!;
      game.passThroughDoor(
        head.doors.firstWhere((d) => d.targetRoomId == 'shelf_glass'),
      );
      expect(game.hintText, contains('snow comes down after you'));
      expect(
        game.hintText,
        contains('no ramp in that slot'),
        reason: 'the chute says what riding it did to the chute',
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
        expect(game.hintText, isNot(contains('lets go')));
        expect(game.currentRoomId, 'cold_sump');

        // A stair standing: now it costs, so now it says so — UNASKED,
        // because a warning held back for the hint button is not a warning.
        game.flueState['flue_b'] = RimeFlueState.stair;
        game.update(1 / 60);
        expect(game.hintText, contains('lets go behind you'));

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

      // A ride that scours.
      heard.clear();
      game.flueState['flue_b'] = RimeFlueState.drift;
      final gallery = game.layout.rooms['mirror_gallery']!;
      game.currentRoomId = 'mirror_gallery';
      game.onShaftTransitForTest(
        gallery,
        gallery.doors.firstWhere((d) => d.targetRoomId == 'shelf_lens'),
      );
      expect(heard, contains(SoundCue.dungeonHazardTrigger));

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

    test('conduit A is the Air+WING gate and stamps its own chip', () {
      final stamped = <String>[];
      final game = _harness([
        _member(0, 'Ice', 'mane'),
        _member(1, 'Light', 'mask'),
        _member(2, 'Air', 'pip'), // wrong family
      ], onCloud: stamped.add);
      final room = game.layout.rooms['star_font']!;
      game.currentRoomId = 'star_font';
      game.earnStar(0);
      game.earnStar(1);
      game.setActive(air);
      game.creatures[air].position = room.conduits
          .firstWhere((c) => c.id == 'A')
          .position;
      game.activateAbility();
      expect(game.conduitEnergy['A'] ?? 0, 0);
      expect(stamped, contains('gate:air_wing'));
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
}
