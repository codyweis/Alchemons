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
// The rest pins the two star puzzles against the real rules — the orrery is
// SOLVED here, move by move, and the mirror ring's thaw window is checked
// against the ring's own geometry.

import 'dart:math' show atan2;

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
}) {
  final game = PlanetDungeonGame(
    element: 'Ice',
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
          expect(shelf.doors.length, 1, reason: '${f.shelfRoom} must be a pocket');
          expect(shelf.doors.single.targetRoomId, f.headRoom);
        }
        // The freeze verb has to be inside its own room.
        expect(head.bounds.contains(f.headPos), isTrue, reason: '${f.id} head pos');
      }
    });

    test('the vault sits on a shelf, so the cache IS the slide trick', () {
      final cacheRoom =
          layout.rooms.values.singleWhere((r) => r.vaultCache != null);
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

    test('§4: two hard gates, on different slots, and Star 0 is ungated', () {
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
    });
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

  group('the flue trade', () {
    test('freezing a drift makes a two-way stair and shuts the shelf', () {
      final game = _harness(_idealTrio());
      final head = game.layout.rooms['rime_head']!;
      final flue = kRimeFlues.firstWhere((f) => f.id == 'flue_a');
      // The mouth is capped until Light melts it.
      for (final d in head.doors) {
        expect(game.isDoorHidden(head, d), isTrue);
      }
      game.setActive(light);
      game.creatures[light].position = head.rime!.iceCap!;
      game.activateAbility();
      expect(game.entryDoorRevealed, isTrue);

      final shelfDoor =
          head.doors.firstWhere((d) => d.targetRoomId == 'shelf_glass');
      final dropDoor =
          head.doors.firstWhere((d) => d.targetRoomId == 'mirror_gallery');
      expect(game.isDoorHidden(head, shelfDoor), isFalse,
          reason: 'a drift brakes you onto the shelf');
      expect(game.isDoorHidden(head, dropDoor), isTrue,
          reason: 'and the long drop does not exist yet');

      game.setActive(ice);
      game.creatures[ice].position = flue.headPos;
      game.activateAbility();
      expect(game.flueState['flue_a'], RimeFlueState.stair);
      expect(game.isDoorHidden(head, shelfDoor), isTrue,
          reason: 'a stair has no fall, so the shelf is sealed for the run');
      expect(game.isDoorHidden(head, dropDoor), isFalse);
      // And the climb back up exists at last.
      final gallery = game.layout.rooms['mirror_gallery']!;
      final up = gallery.doors.firstWhere((d) => d.targetRoomId == 'rime_head');
      expect(game.isDoorLocked(gallery, up), isFalse);
    });

    test('a ridden flue is scoured for good and takes no more frost', () {
      final game = _harness(_idealTrio());
      final head = game.layout.rooms['rime_head']!;
      final flue = kRimeFlues.firstWhere((f) => f.id == 'flue_a');
      game.entryDoorRevealed = true;
      final shelfDoor =
          head.doors.firstWhere((d) => d.targetRoomId == 'shelf_glass');
      game.onShaftTransitForTest(head, shelfDoor);
      expect(game.flueState['flue_a'], RimeFlueState.scoured);

      game.setActive(ice);
      game.creatures[ice].position = flue.headPos;
      game.activateAbility();
      expect(game.flueState['flue_a'], RimeFlueState.scoured,
          reason: 'frost will not key onto polished ice');

      final gallery = game.layout.rooms['mirror_gallery']!;
      final up = gallery.doors.firstWhere((d) => d.targetRoomId == 'rime_head');
      expect(game.isDoorLocked(gallery, up), isTrue,
          reason: 'the ladder is what you paid for the shelf');
    });

    test('the rimefall climbs home and THAWS the whole shaft behind you', () {
      final game = _harness(_idealTrio());
      final sump = game.layout.rooms['cold_sump']!;
      final up = sump.doors.firstWhere((d) => d.targetRoomId == 'rime_head');
      // Build a stair, then spend it on the sump's do-over.
      game.flueState['flue_b'] = RimeFlueState.stair;
      game.flueState['flue_c'] = RimeFlueState.scoured;
      expect(game.isDoorLocked(sump, up), isTrue,
          reason: 'running water is not a ladder');

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
        expect(game.flueState[f.id], RimeFlueState.drift,
            reason: 'the price is everything you cut');
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

  group('Star 0 \u2014 THE STANDING ORRERY', () {
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

    test('a block glides to the end of the glass \u2014 and cracks it', () {
      glaze(1, 2, 2, 2); // stand ON the block's cell, glaze east of it
      glaze(2, 2, 3, 2);
      shove(0, 2, 1, 2);
      expect(blockCell(3, 2), isNotNull, reason: 'it ran the whole road');
      expect(
        game.orreryGlass,
        isEmpty,
        reason: 'a run that misses a socket cracks the road behind it',
      );
    });

    test('a kerbed socket catches a block, glazed or not', () {
      // The block on row 4 sits one cell west of its socket.
      shove(2, 4, 3, 4);
      expect(game.orrerySeated.length, 1);
      expect(blockCell(4, 4), isNotNull);
    });

    test('THE AUTHORED SOLUTION seats every block and banks the star', () {
      // b_south: straight into its kerb, no ice at all \u2014 the room's lesson.
      shove(2, 4, 3, 4);
      expect(game.orrerySeated.length, 1);

      // b_west: run east to col 2, then north into the socket at (2,0).
      glaze(3, 2, 2, 2); // glaze (2,2) from the east side
      shove(0, 2, 1, 2); // the block runs onto (2,2) and the glass ends
      expect(blockCell(2, 2), isNotNull);
      glaze(3, 1, 2, 1); // glaze (2,1)
      shove(2, 3, 2, 2); // north: (2,1) glass, then the kerb at (2,0)
      expect(blockCell(2, 0), isNotNull);
      expect(game.orrerySeated.length, 2);

      // b_east: the mirror image, into the socket at (5,0).
      glaze(4, 2, 5, 2);
      shove(7, 2, 6, 2);
      expect(blockCell(5, 2), isNotNull);
      glaze(4, 1, 5, 1);
      shove(5, 3, 5, 2);

      expect(game.orrerySeated.length, 3);
      expect(earned, contains(0));
      expect(game.hasStar(0), isTrue);
    });

    test('Light melts a glaze back, so no lay of ice is a dead end', () {
      glaze(2, 2, 3, 2);
      expect(game.orreryGlass, isNotEmpty);
      melt(2, 2, 3, 2);
      expect(game.orreryGlass, isEmpty);
    });
  });

  group('Star 1 — THE TWELVE MIRRORS', () {
    test('the lodestone is a HARD gate: no frost, no other family', () {
      final earned = <int>[];
      final stamped = <String>[];
      final game = _harness([
        _member(0, 'Ice', 'mane'),
        _member(1, 'Light', 'horn'), // wrong family on purpose
        _member(2, 'Air', 'wing'),
      ], onStar: earned.add, onCloud: stamped.add);
      final room = game.layout.rooms['mirror_gallery']!;
      final ring = room.rime!.mirrors!;
      game.currentRoomId = 'mirror_gallery';

      // Ice cannot silver it.
      game.setActive(ice);
      game.creatures[ice].position = ring.frameAt(ring.lodestoneIndex);
      game.activateAbility();
      expect(game.lodestoneLit, isFalse);
      expect(game.silveredMirrors, isEmpty);

      // A Light HORN is refused — and the refusal stamps the chip (§4).
      game.setActive(light);
      game.creatures[light].position = ring.frameAt(ring.lodestoneIndex);
      game.activateAbility();
      expect(game.lodestoneLit, isFalse);
      expect(stamped, contains('gate:light_mask'));
    });

    test('the ideal trio reads the whole ring inside one thaw window', () {
      final earned = <int>[];
      final game = _harness(_idealTrio(), onStar: earned.add);
      final room = game.layout.rooms['mirror_gallery']!;
      final ring = room.rime!.mirrors!;
      game.currentRoomId = 'mirror_gallery';

      // The lodestone first — it never thaws, so it is the anchor.
      game.setActive(light);
      for (final c in game.creatures) {
        c.position = ring.frameAt(ring.lodestoneIndex);
      }
      game.activateAbility();
      expect(game.lodestoneLit, isTrue);

      // Then the lap: walk frame to frame at the engine's own walk speed and
      // silver each one. The clock runs for real between frames.
      const walkSpeed = 150.0;
      game.setActive(ice);
      for (var i = 1; i < ring.count; i++) {
        final travel = ring.ringStep / walkSpeed;
        var t = 0.0;
        while (t < travel) {
          game.update(1 / 60);
          t += 1 / 60;
        }
        for (final c in game.creatures) {
          c.position = ring.frameAt(i);
        }
        game.activateAbility();
      }
      expect(game.mirrorsShowing, ring.count,
          reason: 'a clean lap must fit inside the hold window');
      expect(earned, contains(1));
    });

    test('a dawdled ring loses its earliest frames', () {
      final game = _harness(_idealTrio());
      final room = game.layout.rooms['mirror_gallery']!;
      final ring = room.rime!.mirrors!;
      game.currentRoomId = 'mirror_gallery';
      game.setActive(ice);
      game.creatures[ice].position = ring.frameAt(3);
      game.activateAbility();
      expect(game.silveredMirrors, contains(3));
      for (var t = 0.0; t < 20; t += 1 / 60) {
        game.update(1 / 60);
      }
      expect(game.silveredMirrors, isEmpty, reason: 'frost does not keep');
      expect(game.hasStar(1), isFalse);
    });

    test('an Air sweep renews the whole ring at once', () {
      final game = _harness(_idealTrio());
      final room = game.layout.rooms['mirror_gallery']!;
      final ring = room.rime!.mirrors!;
      game.currentRoomId = 'mirror_gallery';
      game.setActive(ice);
      for (final i in [2, 3, 4]) {
        game.creatures[ice].position = ring.frameAt(i);
        game.activateAbility();
      }
      for (var t = 0.0; t < 8; t += 1 / 60) {
        game.update(1 / 60);
      }
      final before = game.mirrorThaw[2]!;
      game.setActive(air);
      game.creatures[air].position = ring.vent;
      game.activateAbility();
      expect(game.mirrorThaw[2]!, greaterThan(before));
      expect(game.silveredMirrors.length, 3);
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
      game.creatures[air].position =
          room.conduits.firstWhere((c) => c.id == 'A').position;
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
