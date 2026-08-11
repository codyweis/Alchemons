// Full-run simulation of the Steam dungeon (Vaporis — the Molten Labyrinth,
// PRESSURE RING-MAIN): a headless Steam+Earth+Fire trio plays the INTENDED
// solutions from a fresh save — the Steam-vent entry, paying ring junctions
// out of the boiler's one budget, the Ember Causeway (read the dam, breach
// the dry stone), condensate earned by cooling, the Cinder Forge (bunker the
// gate BEFORE melting), the Crucible rite, the Hidden-Harmony egg (zero
// scalds), stoking the main to blow the burst-disc vault, and Boilrog.
//
// The scripts document the designed strategy: the starting head (40) cannot
// unclamp the whole ring (4 × 15), cooling condenses pressure back (+4 a
// cell — the flood is also fuel), Fire stokes at the cost of wisps, and the
// vault demands ≥60 dumped in one surge.

import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_companion_stats.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart'
    show CosmicSurvivalCompanion;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _member(int slot, String element, String family) {
  return CosmicPartyMember(
    instanceId: 'inst_$slot',
    baseId: 'base_$slot',
    displayName: '$element $family',
    element: element,
    family: family,
    level: 10,
    statSpeed: 3,
    statIntelligence: 3,
    statStrength: 3,
    statBeauty: 3,
    slotIndex: slot,
    staminaBars: 3,
    staminaMax: 3,
  );
}

PlanetDungeonGame _harness(
  List<CosmicPartyMember> party, {
  void Function(int)? onStar,
  void Function(String)? onCloud,
}) {
  final game = PlanetDungeonGame(
    element: 'Steam',
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

// ── Grid helpers (mirror the engine's bounds-filling cell math) ──
(double, double) _cs(DungeonRoom room, MoltenGrid g) =>
    (room.bounds.width / g.cols, room.bounds.height / g.rowCount);

Offset _center(DungeonRoom room, MoltenGrid g, int c, int r) {
  final (cw, ch) = _cs(room, g);
  return Offset(
      room.bounds.left + (c + 0.5) * cw, room.bounds.top + (r + 0.5) * ch);
}

String _sealKeyOf(String a, String b) => ([a, b]..sort()).join('|');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the authored trio can earn all three Steam stars end-to-end', () {
    final earned = <int>[];
    final discovered = <String>[];
    final party = [
      _member(0, 'Steam', 'pip'),
      _member(1, 'Earth', 'horn'),
      _member(2, 'Fire', 'mask'),
    ];
    final game = _harness(party, onStar: earned.add, onCloud: discovered.add);
    const steam = 0, earth = 1, fire = 2;

    DungeonRoom room(String id) => game.layout.rooms[id]!;
    void step([double seconds = 0.1]) {
      var t = 0.0;
      while (t < seconds) {
        game.update(1 / 60);
        t += 1 / 60;
      }
      for (final c in game.creatures) {
        c.hp = c.maxHp;
      }
    }

    void teleport(String roomId, Offset pos) {
      game.currentRoomId = roomId;
      game.creatures[game.activeIndex]
        ..position = pos
        ..lastSafe = pos;
    }

    void clearWisps() {
      for (final e in game.combatEnemies) {
        e.isDead = true;
      }
      step();
    }

    // Park the whole trio on cell (c,r), facing toward (fc,fr).
    void standAt(String roomId, int c, int r, int fc, int fr) {
      game.currentRoomId = roomId;
      final rm = room(roomId);
      final g = rm.molten!;
      final p = _center(rm, g, c, r);
      final ang = atan2((fr - r).toDouble(), (fc - c).toDouble());
      for (final cr in game.creatures) {
        cr
          ..position = p
          ..lastSafe = p
          ..angle = ang
          ..aimAngle = ang;
      }
    }

    // Use [idx]'s verb on the faced cell from (c,r).
    void act(String roomId, int idx, int c, int r, int fc, int fr) {
      game.setActive(idx);
      standAt(roomId, c, r, fc, fr);
      game.activateAbility();
      game.update(1 / 60);
    }

    // Stand the whole trio at [pos] in [roomId] and press ACTION as [idx].
    void actAt(String roomId, int idx, Offset pos) {
      game.currentRoomId = roomId;
      for (final cr in game.creatures) {
        cr
          ..position = pos
          ..lastSafe = pos;
      }
      game.setActive(idx);
      game.activateAbility();
      game.update(1 / 60);
    }

    void waitForBreath(int n) {
      var guard = 0;
      while (game.steamBreath < n && guard++ < 60 * 30) {
        game.update(1 / 60);
      }
      expect(game.steamBreath, greaterThanOrEqualTo(n));
    }

    // ── Entry: a Steam creature cracks the gate vent ──
    game.setActive(steam);
    teleport('boiler_gate', room('boiler_gate').steamVent!);
    game.activateAbility();
    expect(game.entryDoorRevealed, isTrue);
    expect(discovered, contains(PlanetDungeonGame.entryDoorDiscoveryId));

    // ── The crucible gate is rite-sealed until both stars bank ──
    final north = room('manifold_north');
    final crucibleGate =
        north.doors.firstWhere((d) => d.targetRoomId == 'crucible');
    expect(game.isDoorLocked(north, crucibleGate), isTrue);

    // ── The ring is clamped and the head starts at 40 ──
    expect(game.boilerPressure, kSteamStartPressure);
    final south = room('manifold_south');
    final westJunction =
        south.doors.firstWhere((d) => d.targetRoomId == 'ember_causeway');
    final eastJunction =
        south.doors.firstWhere((d) => d.targetRoomId == 'cinder_forge');
    expect(game.isDoorLocked(south, westJunction), isTrue);
    expect(game.isDoorLocked(south, eastJunction), isTrue);
    // The vault shaft is invisible until the burst-disc blows.
    final vaultShaft =
        south.doors.firstWhere((d) => d.targetRoomId == 'burst_vault');
    expect(game.isDoorHidden(south, vaultShaft), isTrue);

    // ── Pay the west junction: any hands, the MAIN pays ──
    actAt('manifold_south', steam, westJunction.rect.center + const Offset(0, 40));
    expect(game.isDoorLocked(south, westJunction), isFalse);
    expect(game.boilerPressure, kSteamStartPressure - 15);
    // Paying one side opens the causeway's side of the same junction too.
    final causewayRoom = room('ember_causeway');
    final causewaySouthDoor = causewayRoom.doors
        .firstWhere((d) => d.targetRoomId == 'manifold_south');
    expect(game.isDoorLocked(causewayRoom, causewaySouthDoor), isFalse);

    // ── Star 0: the Ember Causeway — read the dam, breach the DRY stone ──
    // The molten sleeps until Fire breaks rock: idling spreads nothing.
    standAt('ember_causeway', 3, 8, 3, 7);
    step(3.0);
    final causeway = game.moltenCells['ember_causeway']!;
    expect(causeway[7][2], 0,
        reason: 'the sealed reservoir must not creep before any melt');
    // Wet faces at (2,6)/(8,6) glow; the dry passage is col 5.
    act('ember_causeway', fire, 5, 7, 5, 6); // breach the dry south face → WAKE
    expect(game.wokeRooms, contains('ember_causeway'));
    act('ember_causeway', steam, 5, 7, 5, 6); // cool the spill (+condensate)
    standAt('ember_causeway', 5, 6, 5, 5);
    game.update(1 / 60);
    act('ember_causeway', fire, 5, 5, 5, 4); // breach the north face
    act('ember_causeway', steam, 5, 5, 5, 4); // cool the doorway
    // A correct read stays calm: the wet pockets are sealed — waking the room
    // via the DRY slot floods nothing, even beats later.
    step(3.0);
    expect(causeway[7][2], 0);
    expect(causeway[7][8], 0);
    // Two cools condensed pressure back to the main.
    expect(game.boilerPressure,
        kSteamStartPressure - 15 + 2 * kSteamCondensateGain);
    standAt('ember_causeway', 5, 2, 5, 2); // the pedestal
    step();
    expect(game.hasStar(0), isTrue,
        reason: 'reaching the pedestal banks star 0');
    clearWisps();

    // ── Pay the east junction and bunker the Cinder Forge ──
    actAt('manifold_south', steam, eastJunction.rect.center + const Offset(0, 40));
    expect(game.isDoorLocked(south, eastJunction), isFalse);
    final afterEast = kSteamStartPressure - 30 + 2 * kSteamCondensateGain;
    expect(game.boilerPressure, afterEast);

    standAt('cinder_forge', 6, 8, 6, 7);
    waitForBreath(2);
    // Wall the bunker around the gate mouth (5,5) while everything sleeps.
    act('cinder_forge', earth, 5, 5, 5, 4); // wall above the mouth
    act('cinder_forge', earth, 5, 5, 6, 5); // wall east of the mouth
    act('cinder_forge', earth, 5, 5, 5, 6); // wall below the mouth
    final forge = game.moltenCells['cinder_forge']!;
    expect(forge[4][5], 1);
    expect(forge[5][6], 1);
    expect(forge[6][5], 1);
    // Break the gate — every cistern in the forge wakes.
    act('cinder_forge', fire, 5, 5, 4, 5);
    expect(game.wokeRooms, contains('cinder_forge'));
    // Cool the spill and slip into the sanctuary.
    act('cinder_forge', steam, 5, 5, 4, 5);
    standAt('cinder_forge', 4, 5, 3, 5);
    game.update(1 / 60);
    standAt('cinder_forge', 1, 5, 1, 5); // the pedestal
    step();
    expect(game.hasStar(1), isTrue,
        reason: 'reaching the sanctuary pedestal banks star 1');
    // The sanctuary interior never flooded.
    expect(forge[5][2], 0);
    clearWisps();

    // Both stars banked → the crucible gate grinds open.
    expect(game.guardianRiteUnlocked, isTrue);
    expect(game.isDoorLocked(north, crucibleGate), isFalse);

    // ── Pay the forge↔north junction; the LAST junction is unaffordable ──
    final forgeRoom = room('cinder_forge');
    final forgeNorthDoor = forgeRoom.doors
        .firstWhere((d) => d.targetRoomId == 'manifold_north');
    actAt('cinder_forge', steam, forgeNorthDoor.rect.center + const Offset(0, 40));
    expect(game.isDoorLocked(forgeRoom, forgeNorthDoor), isFalse);
    final afterNorth = afterEast - 15 + kSteamCondensateGain; // +1 forge cool
    expect(game.boilerPressure, afterNorth);
    expect(afterNorth, lessThan(15),
        reason: 'the strategic pinch: the fourth junction cannot be bought');
    final northWestDoor = north.doors
        .firstWhere((d) => d.targetRoomId == 'ember_causeway');
    actAt('manifold_north', steam,
        northWestDoor.rect.center + const Offset(0, -40));
    expect(game.isDoorLocked(north, northWestDoor), isTrue,
        reason: 'an unaffordable clamp refuses — and takes nothing');
    expect(game.boilerPressure, afterNorth);

    // ── Rite: the Crucible — bunker, break, quench the source ──
    standAt('crucible', 4, 4, 4, 3);
    waitForBreath(2);
    act('crucible', earth, 4, 4, 3, 4); // wall left of the stand
    act('crucible', earth, 4, 4, 5, 4); // wall right of the stand
    act('crucible', fire, 4, 4, 4, 5); // break the band-gate → WAKE
    act('crucible', steam, 4, 4, 4, 5); // cool the spill
    standAt('crucible', 4, 5, 4, 6);
    game.update(1 / 60);
    standAt('crucible', 4, 6, 3, 6);
    game.update(1 / 60);
    act('crucible', steam, 4, 6, 3, 6); // quench the lower cistern's source
    final crucible = game.moltenCells['crucible']!;
    expect(crucible[6][3], 0, reason: 'the near cistern is quenched');
    standAt('crucible', 6, 7, 6, 7); // the pedestal
    step();
    expect(game.moltenRiteDone, isTrue,
        reason: 'the crucible pedestal performs the guardian rite');

    // ── Hidden Harmony: the whole labyrinth without one scald ──
    expect(game.moltenScalds, 0);
    expect(discovered, contains(kSteamHiddenHarmonyEggId));
    clearWisps();

    // ── The burst-disc: stoke the main to a 60-surge, then vent it all ──
    final disc = south.burstDisc!;
    // Below threshold the valve refuses and takes NOTHING.
    actAt('manifold_south', steam, disc.position + const Offset(30, 0));
    expect(game.burstDiscBlown, isFalse);
    expect(game.boilerPressure, greaterThan(0));
    // Only Fire stokes; each stoke rouses wisps.
    final port = north.stokePort!;
    actAt('manifold_north', steam, port + const Offset(30, 0));
    final beforeStokes = game.boilerPressure;
    actAt('manifold_north', fire, port + const Offset(30, 0));
    expect(game.boilerPressure, beforeStokes + kSteamStokeGain);
    expect(game.combatEnemies.where((e) => !e.isDead), isNotEmpty,
        reason: 'the stoke roar draws wisps');
    clearWisps();
    while (game.boilerPressure < disc.threshold) {
      actAt('manifold_north', fire, port + const Offset(30, 0));
      clearWisps();
    }
    final dumped = game.boilerPressure;
    expect(dumped, greaterThanOrEqualTo(disc.threshold));
    actAt('manifold_south', steam, disc.position + const Offset(30, 0));
    expect(game.burstDiscBlown, isTrue);
    expect(game.boilerPressure, 0,
        reason: 'venting the main dumps EVERYTHING — the sacrifice is whole');
    expect(game.isDoorHidden(south, vaultShaft), isFalse,
        reason: 'the blown disc opens the vault shaft');

    // The vault essence fizzles, once ever.
    game.setActive(steam);
    teleport('burst_vault', room('burst_vault').vaultCache!);
    step();
    expect(discovered, contains('cache:steam_vault'));

    // ── Star 2: Boilrog wakes from the rite, felled by lull strikes ──
    final guardianNode = room('boiler_heart').guardian!;
    teleport('boiler_heart', guardianNode.position + const Offset(0, 80));
    step();
    expect(game.guardianAwake, isTrue);
    var safety = 0;
    while (!game.hasStar(2) && safety++ < 600) {
      final boilrog = game.combatEnemies.where((e) => e.isElite).firstOrNull;
      if (boilrog != null && !boilrog.isDead) {
        boilrog.position = game.creatures[game.activeIndex].position;
      }
      if (game.guardianVulnerable) game.activateAbility();
      step(0.3);
    }
    expect(game.hasStar(2), isTrue, reason: 'lull strikes fell Boilrog');
    expect(game.relicDropActive, isTrue);

    expect(earned, [0, 1, 2]);
    expect(game.starsEarnedCount, 3);
  });

  test('each molten verb answers only its own family', () {
    final game = _harness([
      _member(0, 'Steam', 'pip'),
      _member(1, 'Earth', 'horn'),
      _member(2, 'Fire', 'mask'),
    ]);
    final room = game.layout.rooms['ember_causeway']!;
    final g = room.molten!;
    game.currentRoomId = 'ember_causeway';
    game.update(1 / 60);
    final cells = game.moltenCells['ember_causeway']!;

    // The dry meltable face sits at col5/row6.
    const wc = 5, wr = 6;
    expect(cells[wr][wc], 1);

    void faceWallAs(int idx) {
      game.setActive(idx);
      game.creatures[idx]
        ..position = _center(room, g, wc - 1, wr)
        ..lastSafe = _center(room, g, wc - 1, wr)
        ..angle = 0
        ..aimAngle = 0; // facing right toward the wall
    }

    faceWallAs(0); // Steam
    game.activateAbility();
    expect(cells[wr][wc], 1, reason: 'only Fire melts the rock wall');

    faceWallAs(2); // Fire
    game.activateAbility();
    expect(cells[wr][wc], 3, reason: 'Fire melts the wall to lava');
    expect(game.wokeRooms, contains('ember_causeway'),
        reason: 'the first melt wakes the room');

    // Earth cannot wall a lava cell (only open ground).
    faceWallAs(1); // Earth
    game.activateAbility();
    expect(cells[wr][wc], 3, reason: 'Earth cannot wall over molten');

    // Steam cools the lava back to open — spending one breath, earning
    // condensate for the main.
    final breathBefore = game.steamBreath;
    final pressureBefore = game.boilerPressure;
    faceWallAs(0); // Steam
    game.activateAbility();
    expect(cells[wr][wc], 0, reason: 'Steam cools the lava to standing stone');
    expect(game.steamBreath, breathBefore - 1,
        reason: 'cooling spends a breath');
    expect(game.boilerPressure, pressureBefore + kSteamCondensateGain,
        reason: 'cooling condenses pressure back to the main');
  });

  // v2: damming is ELEMENT-ONLY. Any Earth drives the wall home clean — the
  // old "a Horn sets it clean, everyone else raises a racket that draws wisps"
  // split is gone.
  test('the molten dam is element-only: every Earth family walls identically',
      () {
    for (final family in const [
      'pip', 'mane', 'horn', 'mask', 'wing', 'kin',
    ]) {
      final game = _harness([_member(0, 'Earth', family)]);
      final room = game.layout.rooms['ember_causeway']!;
      final g = room.molten!;
      game.currentRoomId = 'ember_causeway';
      game.update(1 / 60);
      final cells = game.moltenCells['ember_causeway']!;

      // Find open ground with open ground to its left to stand on.
      int? tc, tr;
      for (var r = 0; r < cells.length && tc == null; r++) {
        for (var c = 1; c < cells[r].length; c++) {
          if (cells[r][c] == 0 && cells[r][c - 1] == 0) {
            tc = c;
            tr = r;
            break;
          }
        }
      }
      expect(tc, isNotNull, reason: 'the causeway must have open ground');

      game.setActive(0);
      game.creatures.single
        ..position = _center(room, g, tc! - 1, tr!)
        ..lastSafe = _center(room, g, tc - 1, tr)
        ..angle = 0
        ..aimAngle = 0; // facing right at the open cell
      game.activateAbility();

      expect(
        cells[tr][tc],
        1,
        reason: 'an Earth $family must raise the dam wall',
      );
      expect(
        game.combatEnemies.where((e) => !e.isDead),
        isEmpty,
        reason: 'an Earth $family raises it CLEAN — no racket, no wisps',
      );
    }
  });

  test('every molten-room door is passable on foot (not just by teleport)', () {
    final game = _harness([_member(0, 'Steam', 'pip')]);
    // Geometry test, not economy: pre-pay every ring junction.
    for (final room in game.layout.rooms.values) {
      for (final s in room.pressureSeals) {
        game.unclampedSeals.add(_sealKeyOf(room.id, s.targetRoomId));
      }
    }
    for (final room in game.layout.rooms.values) {
      if (room.molten == null) continue;
      for (final door in room.doors) {
        game.currentRoomId = room.id;
        // Stand one step inside the room, centred on the door, and walk at it.
        final r = door.rect;
        final horizontal = r.width >= r.height;
        final inward = horizontal
            ? Offset(0, r.center.dy < room.bounds.center.dy ? 1 : -1)
            : Offset(r.center.dx < room.bounds.center.dx ? 1 : -1, 0);
        final start = r.center + inward * 60;
        game.creatures.single
          ..position = start
          ..lastSafe = start;
        game.joystickDirection = -inward; // walk toward the door
        var frames = 0;
        while (game.currentRoomId == room.id && frames++ < 60 * 4) {
          game.update(1 / 60);
        }
        game.joystickDirection = Offset.zero;
        expect(game.currentRoomId, door.targetRoomId,
            reason: '${room.id} → ${door.targetRoomId} must be walkable');
      }
    }
  });

  test('a clamped junction blocks travel until its cost is paid', () {
    final game = _harness([_member(0, 'Steam', 'pip')]);
    final south = game.layout.rooms['manifold_south']!;
    final west =
        south.doors.firstWhere((d) => d.targetRoomId == 'ember_causeway');
    // Walk at the clamped junction: the door refuses.
    game.currentRoomId = 'manifold_south';
    final start = west.rect.center + const Offset(0, 60);
    game.creatures.single
      ..position = start
      ..lastSafe = start;
    game.joystickDirection = const Offset(0, -1);
    for (var i = 0; i < 60 * 2; i++) {
      game.update(1 / 60);
    }
    game.joystickDirection = Offset.zero;
    expect(game.currentRoomId, 'manifold_south');
    // Throw the release (the main pays), and the same walk crosses.
    game.creatures.single
      ..position = west.rect.center + const Offset(0, 40)
      ..lastSafe = west.rect.center + const Offset(0, 40);
    game.activateAbility();
    expect(game.boilerPressure, kSteamStartPressure - 15);
    game.creatures.single
      ..position = start
      ..lastSafe = start;
    game.joystickDirection = const Offset(0, -1);
    var frames = 0;
    while (game.currentRoomId == 'manifold_south' && frames++ < 60 * 4) {
      game.update(1 / 60);
    }
    game.joystickDirection = Offset.zero;
    expect(game.currentRoomId, 'ember_causeway');
  });

  test('the flood sleeps until woken, then creeps on the beat', () {
    final game = _harness([_member(0, 'Steam', 'pip')]);
    final room = game.layout.rooms['cinder_forge']!;
    final g = room.molten!;
    game.currentRoomId = 'cinder_forge';
    void park() {
      game.creatures.single
        ..position = _center(room, g, 1, 9)
        ..lastSafe = _center(room, g, 1, 9);
    }

    park();
    game.update(1 / 60);
    final cells = game.moltenCells['cinder_forge']!;
    // An authored cistern sits at col4/row2 in the open field.
    expect(cells[2][4], 3);
    // Asleep: nothing creeps, however long you wait.
    for (var i = 0; i < 60 * 5; i++) {
      park();
      game.update(1 / 60);
    }
    expect(cells[2][5], 0, reason: 'a sleeping cistern never creeps');

    // Woken: the flood claims the neighbour within a beat.
    game.wokeRooms.add('cinder_forge');
    for (var i = 0; i < 60 * 3; i++) {
      park();
      game.update(1 / 60);
    }
    expect(cells[2][5], 3, reason: 'a woken cistern floods its neighbours');
  });

  test('breaching a WET dam section floods your own chamber', () {
    final game = _harness([
      _member(0, 'Steam', 'pip'),
      _member(1, 'Earth', 'horn'),
      _member(2, 'Fire', 'mask'),
    ]);
    final room = game.layout.rooms['ember_causeway']!;
    final g = room.molten!;
    game.currentRoomId = 'ember_causeway';
    game.update(1 / 60);
    final cells = game.moltenCells['ember_causeway']!;
    // (2,6) is a wet face: the sealed reservoir at (2,5) presses on it.
    expect(cells[5][2], 3);
    // Fire breaches it from the south field.
    game.setActive(2);
    final stand = _center(room, g, 2, 7);
    for (final c in game.creatures) {
      c
        ..position = stand
        ..lastSafe = stand
        ..angle = -pi / 2
        ..aimAngle = -pi / 2; // facing up at the wet dam face
    }
    game.activateAbility();
    expect(cells[6][2], 3, reason: 'the breach itself runs molten');
    // Park clear of the flood's first rings and let the beats pass: the
    // reservoir pours through the hole into YOUR chamber.
    final safe = _center(room, g, 8, 9);
    for (var i = 0; i < 60 * 3; i++) {
      for (final c in game.creatures) {
        c
          ..position = safe
          ..lastSafe = safe;
      }
      game.update(1 / 60);
    }
    expect(cells[7][2], 3,
        reason: 'the flood crosses into the player\'s chamber — the wrong '
            'breach has a consequence');
    // And the pocket stays sealed on the pedestal side: the north field
    // never floods through the bedrock.
    expect(cells[3][2], 0);
  });

  test('cooling breath is finite and returns with the beat', () {
    final game = _harness([_member(0, 'Steam', 'pip')]);
    final room = game.layout.rooms['ember_causeway']!;
    final g = room.molten!;
    game.currentRoomId = 'ember_causeway';
    game.update(1 / 60);
    final cells = game.moltenCells['ember_causeway']!;
    // Lay a row of lava directly (no wake — no creep interference).
    for (var c = 4; c < 4 + kSteamBreathMax + 1; c++) {
      cells[9][c] = 3;
    }
    // Cool from the left, one cell at a time: the meter runs dry.
    for (var k = 0; k <= kSteamBreathMax; k++) {
      final c = 4 + k;
      game.creatures.single
        ..position = _center(room, g, c - 1, 9)
        ..lastSafe = _center(room, g, c - 1, 9)
        ..angle = 0
        ..aimAngle = 0;
      game.activateAbility();
    }
    expect(game.steamBreath, 0);
    expect(cells[9][4 + kSteamBreathMax], 3,
        reason: 'the breath ran out before the last cell');
    // A beat returns one breath, and the cooling works again.
    for (var i = 0; i < 60 * 3; i++) {
      game.update(1 / 60);
    }
    expect(game.steamBreath, greaterThan(0));
    game.creatures.single.angle = 0;
    game.activateAbility();
    expect(cells[9][4 + kSteamBreathMax], 0);
  });

  test('the flood spares no one: idle companions scald and scramble too', () {
    final game = _harness([
      _member(0, 'Steam', 'pip'),
      _member(1, 'Earth', 'horn'),
      _member(2, 'Fire', 'mask'),
    ]);
    final room = game.layout.rooms['ember_causeway']!;
    final g = room.molten!;
    game.currentRoomId = 'ember_causeway';
    game.setActive(0);
    game.update(1 / 60);
    final cells = game.moltenCells['ember_causeway']!;
    // Active stands clear; the IDLE Earth companion stands at (2,8).
    game.creatures[0]
      ..position = _center(room, g, 7, 9)
      ..lastSafe = _center(room, g, 7, 9);
    final idle = game.creatures[1]
      ..position = _center(room, g, 2, 8)
      ..lastSafe = _center(room, g, 3, 8);
    game.creatures[2]
      ..position = _center(room, g, 8, 9)
      ..lastSafe = _center(room, g, 8, 9);
    // The flood claims the idle companion's cell.
    cells[8][2] = 3;
    game.update(1 / 60);
    expect(idle.hp, lessThan(idle.maxHp),
        reason: 'an idle companion standing in molten scalds');
    expect(game.moltenScalds, greaterThan(0),
        reason: 'a companion scald spoils the Hidden Harmony too');
    final (ic, ir) = (
      ((idle.position.dx - room.bounds.left) / (room.bounds.width / g.cols))
          .floor(),
      ((idle.position.dy - room.bounds.top) / (room.bounds.height / g.rowCount))
          .floor()
    );
    expect(cells[ir][ic], 0,
        reason: 'the companion scrambled to open ground');
  });

  test('a molten rescue never crosses the dam (no teleport through walls)', () {
    final game = _harness([_member(0, 'Steam', 'pip')]);
    final room = game.layout.rooms['ember_causeway']!;
    final g = room.molten!;
    game.currentRoomId = 'ember_causeway';
    game.update(1 / 60);
    final cells = game.moltenCells['ember_causeway']!;
    // Flood the ENTIRE south field (rows 7-10). The nearest open cell by
    // pure distance is now the dam's hollow (5,5) — on the FAR side of a
    // meltable wall. The rescue must NOT put the creature there.
    for (var r = 7; r <= 10; r++) {
      for (var c = 1; c <= 8; c++) {
        cells[r][c] = 3;
      }
    }
    final pos = _center(room, g, 5, 7); // right below the dry dam face
    game.creatures.single
      ..position = pos
      ..lastSafe = pos; // last safe ground is drowned too
    game.update(1 / 60);
    final me = game.creatures.single.position;
    expect(me.dy, greaterThan(room.bounds.top + room.bounds.height * 7 / 12),
        reason: 'the creature stays on ITS side of the dam — the old spiral '
            'search teleported it through the wall into the hollow');
    expect(cells[7][5], 0,
        reason: 'with no reachable ground, the footing crusts underfoot');
  });

  test('Earth cannot entomb a companion by walling their cell', () {
    final game = _harness([
      _member(0, 'Steam', 'pip'),
      _member(1, 'Earth', 'horn'),
      _member(2, 'Fire', 'mask'),
    ]);
    final room = game.layout.rooms['ember_causeway']!;
    final g = room.molten!;
    game.currentRoomId = 'ember_causeway';
    game.update(1 / 60);
    final cells = game.moltenCells['ember_causeway']!;
    // The Steam companion stands at (3,8); Earth stands beside it, aiming in.
    game.creatures[0]
      ..position = _center(room, g, 3, 8)
      ..lastSafe = _center(room, g, 3, 8);
    game.creatures[2]
      ..position = _center(room, g, 7, 9)
      ..lastSafe = _center(room, g, 7, 9);
    game.setActive(1);
    game.creatures[1]
      ..position = _center(room, g, 2, 8)
      ..lastSafe = _center(room, g, 2, 8)
      ..angle = 0
      ..aimAngle = 0; // facing the occupied cell
    game.activateAbility();
    expect(cells[8][3], 0,
        reason: 'the wall must refuse to rise on an occupied cell');
  });

  test('a fully flooded room never strands you, and restart wipes it clean', () {
    final game = _harness([_member(0, 'Steam', 'pip')]);
    final room = game.layout.rooms['ember_causeway']!;
    final g = room.molten!;
    game.currentRoomId = 'ember_causeway';
    game.update(1 / 60); // build the grid
    final cells = game.moltenCells['ember_causeway']!;

    // Flood every non-bedrock cell with lava — the worst case.
    for (var r = 0; r < g.rowCount; r++) {
      for (var c = 0; c < g.cols; c++) {
        if (cells[r][c] != 2) cells[r][c] = 3;
      }
    }
    // Stand the creature in the middle of the flood.
    final pos = _center(room, g, 3, 8);
    game.creatures.single
      ..position = pos
      ..lastSafe = pos;
    game.update(1 / 60);
    // It must end on crusted-open ground (scalded, but never frozen).
    expect(cells[8][3], 0, reason: 'the engulfed cell crusts to a foothold');
    expect(game.moltenScalds, greaterThan(0),
        reason: 'being engulfed counts as a scald');

    // Restart wipes the chamber back to its authored layout, asleep again.
    game.wokeRooms.add('ember_causeway');
    game.restartRoom();
    expect(game.wokeRooms, isNot(contains('ember_causeway')));
    expect(game.steamBreath, kSteamBreathMax);
    final fresh = game.moltenCells['ember_causeway']!;
    var lava = 0, wall = 0;
    for (final rowCells in fresh) {
      lava += rowCells.where((c) => c == 3).length;
      wall += rowCells.where((c) => c == 1).length;
    }
    final authoredLava =
        g.rows.fold<int>(0, (n, line) => n + 'L'.allMatches(line).length);
    final authoredWall =
        g.rows.fold<int>(0, (n, line) => n + '#'.allMatches(line).length);
    expect(lava, authoredLava, reason: 'restart restores the authored lava');
    expect(wall, authoredWall, reason: 'restart restores the authored walls');
  });
}
