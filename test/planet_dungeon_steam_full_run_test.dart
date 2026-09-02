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

// STATUS: eight tests in this file fail against the current Steam content.
//
// They are stale, not evidence of a broken dungeon — the same situation the
// Fire file was in before its ash-garden pass. But unlike Fire they are NOT
// uniformly mechanical:
//
//   • Some are pure coordinate drift. The crucible's meltable '#' band sits on
//     row 5 of its authored rows; tests written against an older art still
//     look at row 6. Fixing the lookup is enough.
//
//   • At least one is semantic. 'each molten verb answers only its own family'
//     melts in the crucible and expects ember_causeway to wake; the crucible
//     wakes instead. That needs the flood-propagation rule settled before the
//     test can be trusted either way.
//
// Do not bulk-shift every row index by one. Check each against the authored
// rows in planet_dungeon_data.dart.

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
    room.bounds.left + (c + 0.5) * cw,
    room.bounds.top + (r + 0.5) * ch,
  );
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
    // Star 1's geyser field needs the Earth hand for its one stone.
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
    final crucibleGate = north.doors.firstWhere(
      (d) => d.targetRoomId == 'crucible',
    );
    expect(game.isDoorLocked(north, crucibleGate), isTrue);

    // ── The ring is clamped and the head starts at 40 ──
    expect(game.boilerPressure, kSteamStartPressure);
    final south = room('manifold_south');
    final westJunction = south.doors.firstWhere(
      (d) => d.targetRoomId == 'ember_causeway',
    );
    final eastJunction = south.doors.firstWhere(
      (d) => d.targetRoomId == 'cinder_forge',
    );
    expect(game.isDoorLocked(south, westJunction), isTrue);
    expect(game.isDoorLocked(south, eastJunction), isTrue);
    // The vault shaft is invisible until the burst-disc blows.
    final vaultShaft = south.doors.firstWhere(
      (d) => d.targetRoomId == 'burst_vault',
    );
    expect(game.isDoorHidden(south, vaultShaft), isTrue);

    // ── Pay the west junction: any hands, the MAIN pays ──
    actAt(
      'manifold_south',
      steam,
      westJunction.rect.center + const Offset(0, 40),
    );
    expect(game.isDoorLocked(south, westJunction), isFalse);
    expect(game.boilerPressure, kSteamStartPressure - 15);
    // Paying one side opens the causeway's side of the same junction too.
    // ── STAR 1: THE GEYSER FIELD — shut every mouth and the heart bursts ──
    final field = room('ember_causeway');
    game.currentRoomId = 'ember_causeway';
    step();
    expect(game.geyserPressure, 1, reason: 'one mouth starts under rubble');

    // The stone goes down FIRST, while the field is still calm to cross.
    final east = field.geysers.firstWhere((g) => g.id == 'g_east').position;
    game.setActive(earth);
    for (final c in game.creatures) {
      c
        ..position = east + const Offset(0, 60)
        ..lastSafe = east + const Offset(0, 60)
        ..aimAngle = -pi / 2;
    }
    game.activateAbility();
    expect(game.earthRock, isNotNull, reason: 'Earth heaves up the one stone');
    step(0.8);

    // Then the three bodies take the three mouths still blowing.
    void park(int slot, String id) {
      final at = field.geysers.firstWhere((g) => g.id == id).position;
      game.creatures[slot]
        ..position = at
        ..lastSafe = at;
    }

    park(steam, 'g_north');
    park(earth, 'g_south');
    park(fire, 'g_west');
    step(0.5);
    expect(game.geyserPressure, 5, reason: 'every mouth shut');
    expect(game.capstoneBurst, isTrue);
    expect(game.hasStar(0), isTrue, reason: 'the heart takes the whole head');
    clearWisps();

    // ── Pay the east junction and bunker the Cinder Forge ──
    actAt(
      'manifold_south',
      steam,
      eastJunction.rect.center + const Offset(0, 40),
    );
    expect(game.isDoorLocked(south, eastJunction), isFalse);
    // THE GEYSER FIELD EARNS NO CONDENSATE. This used to read
    // `- 30 + 2 * kSteamCondensateGain`, because the old tile-lava causeway
    // made you cool two cells on the way through and cooling pays the main
    // back. Star 1 is a geyser field now: you cap mouths, you never cool
    // anything, so the head after two junctions is simply what is left of it.
    // Worth knowing rather than patching quietly — the ring's economy got
    // tighter when the causeway went, and Fire's stoke port is now the only
    // income before the crucible.
    expect(game.boilerPressure, kSteamStartPressure - 30);

    // ── STAR 2: THE CINDER FORGE — cap the hobs, ride the risers ──
    // WHAT THIS REPLACES: a molten forge with a two-thick plug, two pours
    // boxed in bedrock, and a vault pedestal behind it. That room was retired
    // on 2026-08-14 and rebuilt as a geyser field with a chasm across it, so
    // the script below was playing furniture that no longer exists.
    //
    // The field's own puzzle is a DECAY. Every capped mouth sends its head to
    // the ones still open, so a riser throws further the more of the field is
    // held — and each body you send across the chasm is one fewer body holding
    // it down for the next. The far throw has to be taken FIRST, while the
    // field is at its fullest, and Earth's one stone is what frees a third
    // body to ride at all.
    final forgeRoom0 = room('cinder_forge');
    game.currentRoomId = 'cinder_forge';
    expect(
      game.earthRock,
      isNull,
      reason:
          'the causeway keeps its own stone — a stone belongs to the floor it '
          'came out of, so Earth can raise a fresh one here',
    );
    Offset mouth(String id) =>
        forgeRoom0.geysers.firstWhere((g) => g.id == id).position;
    final farShore = forgeRoom0.platforms.last;
    void place(int slot, Offset at, {double? aim}) {
      final c = game.creatures[slot];
      c
        ..position = at
        ..lastSafe = at;
      if (aim != null) {
        c
          ..angle = aim
          ..aimAngle = aim;
      }
    }

    /// Hold everyone still through the field's next eruption.
    void rideTheBlast(List<int> holders, Map<int, Offset> stations) {
      var frames = 0;
      final before = Map<int, Offset>.fromEntries(
        stations.keys.map((k) => MapEntry(k, game.creatures[k].position)),
      );
      while (frames++ < 60 * 9) {
        for (final h in holders) {
          place(h, stations[h]!);
        }
        game.update(1 / 60);
        for (final cr in game.creatures) {
          if (cr.alive) cr.hp = cr.maxHp;
        }
        final moved = stations.keys.any(
          (k) =>
              !holders.contains(k) &&
              (game.creatures[k].position - before[k]!).distance > 40,
        );
        if (moved) break;
      }
    }

    // Earth heaves its one stone onto a hob — that is the third capper, and
    // without it nobody is free to ride.
    game.setActive(earth);
    place(earth, mouth('r_hob_a') + const Offset(0, 60), aim: -pi / 2);
    game.activateAbility();
    expect(game.earthRock, isNotNull);
    step(0.8);
    expect(
      game.cappedGeysers,
      contains('r_hob_a'),
      reason: 'the stone smothers the hob it was pushed onto',
    );

    // THE LONG THROW, taken while the field is fullest: bodies on the other
    // two hobs, and Earth rides the far riser.
    place(steam, mouth('r_hob_b'));
    place(fire, mouth('r_hob_c'));
    place(earth, mouth('r_long'), aim: 0); // the chasm runs east
    game.update(1 / 60);
    expect(
      game.geyserPressure,
      4,
      reason: 'choked + stone + two bodies — every mouth but the risers',
    );
    rideTheBlast([steam, fire], {
      steam: mouth('r_hob_b'),
      fire: mouth('r_hob_c'),
      earth: mouth('r_long'),
    });
    expect(
      farShore.inflate(2).contains(game.creatures[earth].position),
      isTrue,
      reason: 'a full field throws the long riser clear across the chasm',
    );

    // Now the field is one body weaker, and the long riser can no longer make
    // it — the short one at the lip is the only crossing left.
    place(steam, mouth('r_short'), aim: 0);
    game.update(1 / 60);
    expect(game.geyserPressure, 3, reason: 'a capper left to ride');
    rideTheBlast([fire], {fire: mouth('r_hob_c'), steam: mouth('r_short')});
    expect(
      farShore.inflate(2).contains(game.creatures[steam].position),
      isTrue,
    );

    // And the last body across rides on the weakest field of all.
    place(fire, mouth('r_short'), aim: 0);
    game.update(1 / 60);
    expect(game.geyserPressure, 2, reason: 'only the choked mouth and stone');
    rideTheBlast([], {fire: mouth('r_short')});
    expect(farShore.inflate(2).contains(game.creatures[fire].position), isTrue);

    step();
    expect(
      game.hasStar(1),
      isTrue,
      reason: 'the whole party on the far shore yields the pedestal',
    );
    clearWisps();

    // Both stars banked → the crucible gate grinds open.
    expect(game.guardianRiteUnlocked, isTrue);
    expect(game.isDoorLocked(north, crucibleGate), isFalse);

    // ── Pay the forge↔north junction; the LAST junction is unaffordable ──
    final forgeRoom = room('cinder_forge');
    final forgeNorthDoor = forgeRoom.doors.firstWhere(
      (d) => d.targetRoomId == 'manifold_north',
    );
    // THE PINCH MOVED. With both star rooms rebuilt as geyser fields there is
    // no cooling on the way round any more, so the head does not top itself
    // up: after two junctions it stands at 10 and the third is already out of
    // reach. The clamp refuses and takes nothing.
    expect(game.boilerPressure, lessThan(15));
    actAt(
      'cinder_forge',
      steam,
      forgeNorthDoor.rect.center + const Offset(0, 40),
    );
    expect(
      game.isDoorLocked(forgeRoom, forgeNorthDoor),
      isTrue,
      reason: 'an unaffordable clamp refuses',
    );
    expect(
      game.boilerPressure,
      kSteamStartPressure - 30,
      reason: 'and takes nothing for the attempt',
    );

    // So the ring has to be PAID FOR, and Fire's stoke port is the only
    // income left before the crucible — at the price of the wisps each roar
    // pulls in. That is the strategic pinch now: it costs you fights.
    final southPort = south.stokePort!;
    actAt('manifold_south', fire, southPort + const Offset(30, 0));
    expect(game.boilerPressure, kSteamStartPressure - 30 + kSteamStokeGain);
    expect(
      game.combatEnemies.where((e) => !e.isDead),
      isNotEmpty,
      reason: 'the stoke roar draws wisps',
    );
    clearWisps();

    actAt(
      'cinder_forge',
      steam,
      forgeNorthDoor.rect.center + const Offset(0, 40),
    );
    expect(game.isDoorLocked(forgeRoom, forgeNorthDoor), isFalse);
    final afterNorth = kSteamStartPressure - 30 + kSteamStokeGain - 15;
    expect(game.boilerPressure, afterNorth);
    // Exactly one junction's worth left, and nothing else. The ring CAN be
    // closed on a single stoke — but doing it empties the main, and the
    // burst-disc vault wants a 60-surge in one go, so the whole cost of a
    // fully-open ring is paid again in stokes (and in the wisps each one
    // brings) before the treasury is even on the table.
    expect(afterNorth, 15);
    // The last clamp takes exactly what is left, and the ring closes on an
    // empty main. (This used to expect a refusal here — with the causeway's
    // condensate income the fourth junction really was out of reach. One
    // stoke replaced that income and then some, so the pinch is no longer
    // "you cannot open the ring"; it is "opening it leaves you nothing", and
    // the burst-disc vault upstairs wants a 60-surge in a single go.)
    final northWestDoor = north.doors.firstWhere(
      (d) => d.targetRoomId == 'ember_causeway',
    );
    actAt(
      'manifold_north',
      steam,
      northWestDoor.rect.center + const Offset(0, -40),
    );
    expect(game.isDoorLocked(north, northWestDoor), isFalse);
    expect(
      game.boilerPressure,
      0,
      reason: 'the ring is open and the main is spent to the last unit',
    );

    // ── Rite: the Crucible — THE SOURCE, QUENCHED (reworked) ──
    // The pedestal will not sink while one vein still runs, and the cisterns
    // lie beyond the band — so the order is the rite: still the reservoir
    // FIRST, while the chamber sleeps, then break in for the rest.
    standAt('crucible', 5, 4, 5, 3);
    step();
    final crucible = game.moltenCells['crucible']!;
    expect(crucible[3][5], 3, reason: 'the reservoir hangs over the band');
    for (final c in [5, 6, 7]) {
      waitForBreath(1);
      act('crucible', steam, c, 4, c, 3); // quench the reservoir, asleep
      expect(crucible[3][c], 0);
    }
    expect(
      game.wokeRooms.contains('crucible'),
      isFalse,
      reason: 'quenching never wakes anything — only breaking rock does',
    );

    // Now break in. The breach itself runs molten and counts as a live vein.
    waitForBreath(2);
    act('crucible', fire, 4, 4, 4, 5);
    expect(game.wokeRooms, contains('crucible'));
    act('crucible', steam, 4, 4, 4, 5);

    standAt('crucible', 6, 7, 6, 7);
    step();
    expect(
      game.moltenRiteDone,
      isTrue,
      reason: 'a stilled chamber performs the guardian rite',
    );

    // ── Hidden Harmony: the whole labyrinth without one scald ──
    // The rite PAYS OUT through the Rite of Three, so the egg lands when that
    // reaction settles (~4.2s), not on the frame the pedestal sinks.
    expect(game.moltenScalds, 0);
    step(5.0);
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
    expect(
      game.combatEnemies.where((e) => !e.isDead),
      isNotEmpty,
      reason: 'the stoke roar draws wisps',
    );
    clearWisps();
    while (game.boilerPressure < disc.threshold) {
      actAt('manifold_north', fire, port + const Offset(30, 0));
      clearWisps();
    }
    final dumped = game.boilerPressure;
    expect(dumped, greaterThanOrEqualTo(disc.threshold));
    actAt('manifold_south', steam, disc.position + const Offset(30, 0));
    expect(game.burstDiscBlown, isTrue);
    expect(
      game.boilerPressure,
      0,
      reason: 'venting the main dumps EVERYTHING — the sacrifice is whole',
    );
    expect(
      game.isDoorHidden(south, vaultShaft),
      isFalse,
      reason: 'the blown disc opens the vault shaft',
    );

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
    final room = game.layout.rooms['crucible']!;
    final g = room.molten!;
    game.currentRoomId = 'crucible';
    game.update(1 / 60);
    final cells = game.moltenCells['crucible']!;

    // A DRY meltable face — col4/row5 of the '#' band. (Two corrections: the
    // band moved to row 5 in an art edit, and col 5 is one of the two WET
    // gates since the cisterns were put back behind the inner pair, so a verb
    // test that wants nothing to burst has to use an outer one.)
    const wc = 4, wr = 5;
    expect(cells[wr][wc], 1);
    expect(
      game.gateWetness('crucible')['$wc,$wr'],
      isFalse,
      reason: 'this test wants a face that will not burst on breaching',
    );

    void faceWallAs(int idx) {
      game.setActive(idx);
      // Standing on the FLOOR north of the gate, facing down at it. (This
      // used to stand at (wc-1, wr), which is inside the band itself.)
      game.creatures[idx]
        ..position = _center(room, g, wc, wr - 1)
        ..lastSafe = _center(room, g, wc, wr - 1)
        ..angle = pi / 2
        ..aimAngle = pi / 2;
    }

    faceWallAs(0); // Steam
    game.activateAbility();
    expect(cells[wr][wc], 1, reason: 'only Fire melts the rock wall');

    faceWallAs(2); // Fire
    game.activateAbility();
    expect(cells[wr][wc], 3, reason: 'Fire melts the wall to lava');
    // Settled: waking is per-room and the melt happens HERE, so the crucible
    // is what wakes. (The Ember Causeway has not been a molten room since the
    // 2026-08-14 geyser rework, so it can no longer wake at all.)
    expect(
      game.wokeRooms,
      contains('crucible'),
      reason: 'the first melt wakes the room it happens in',
    );

    // Earth cannot wall a lava cell (only open ground).
    faceWallAs(1); // Earth
    game.activateAbility();
    expect(cells[wr][wc], 3, reason: 'Earth cannot wall over molten');

    // Steam cools the lava back to open — spending one breath, earning
    // condensate for the main. FRESH fire-blood will not take the breath (see
    // 'a breach RUNS'), so the beat has to pass first.
    for (var i = 0; i < 60 * 2.5; i++) {
      game.update(1 / 60);
    }
    faceWallAs(0);
    final breathBefore = game.steamBreath;
    final pressureBefore = game.boilerPressure;
    faceWallAs(0); // Steam
    game.activateAbility();
    expect(cells[wr][wc], 0, reason: 'Steam cools the lava to standing stone');
    expect(
      game.steamBreath,
      breathBefore - 1,
      reason: 'cooling spends a breath',
    );
    expect(
      game.boilerPressure,
      pressureBefore + kSteamCondensateGain,
      reason: 'cooling condenses pressure back to the main',
    );
  });

  // v2: damming is ELEMENT-ONLY. Any Earth drives the wall home clean — the
  // old "a Horn sets it clean, everyone else raises a racket that draws wisps"
  // split is gone.
  test(
    'the molten dam is element-only: every Earth family walls identically',
    () {
      for (final family in const [
        'pip',
        'mane',
        'horn',
        'mask',
        'wing',
        'kin',
      ]) {
        final game = _harness([_member(0, 'Earth', family)]);
        final room = game.layout.rooms['crucible']!;
        final g = room.molten!;
        game.currentRoomId = 'crucible';
        game.update(1 / 60);
        final cells = game.moltenCells['crucible']!;

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
    },
  );

  test('every Steam door is passable on foot (not just by teleport)', () {
    final game = _harness([_member(0, 'Steam', 'pip')]);
    // Geometry test, not economy: pre-pay every ring junction. And not
    // gating either — rouse Boilrog so the heart's door is unsealed too (the
    // seal itself is tested where it belongs).
    for (final room in game.layout.rooms.values) {
      for (final s in room.pressureSeals) {
        game.unclampedSeals.add(_sealKeyOf(room.id, s.targetRoomId));
      }
    }
    // GEOMETRY, NOT GATING — so open everything the run would have opened.
    // All three stars banked matters for the boss room in particular: Boilrog
    // seals his chamber while he is up, and "solved is solved" is what leaves
    // it open again. (Asking `isDoorLocked` once before stepping is not
    // enough there — he spawns DURING the walk and the lock appears with him.)
    game.entryDoorRevealed = true;
    game.burstDiscBlown = true;
    game.starMask = 0x7;
    for (final room in game.layout.rooms.values) {
      // Was `molten == null → skip`, which let the geyser rooms out of a
      // check they needed more than the crucible did: in a room with
      // PLATFORMS only a platform is solid ground, so a door standing off the
      // end of one cannot be walked into — you step into the void and the
      // fall puts you back. The Cinder Forge shipped exactly that and could
      // not be left on foot at all.
      for (final door in room.doors) {
        game.currentRoomId = room.id;
        // A LOCKED door is a design decision; an UNREACHABLE one is a bug.
        // Boilrog's heart holds you while he is roused, and that is the point
        // of a boss room — so ask the game which doors are shut and test only
        // the ones that claim to be open.
        if (game.isDoorLocked(room, door) || game.isDoorHidden(room, door)) {
          continue;
        }
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
        expect(
          game.currentRoomId,
          door.targetRoomId,
          reason: '${room.id} → ${door.targetRoomId} must be walkable',
        );
      }
    }
  });

  test('a clamped junction blocks travel until its cost is paid', () {
    final game = _harness([_member(0, 'Steam', 'pip')]);
    final south = game.layout.rooms['manifold_south']!;
    final west = south.doors.firstWhere(
      (d) => d.targetRoomId == 'ember_causeway',
    );
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
    // (Was written against `cinder_forge`, which has had no molten grid since
    // the 2026-08-14 geyser rework — `room.molten!` on it now throws. The
    // crucible is the planet's one remaining molten chamber.)
    final game = _harness([_member(0, 'Steam', 'pip')]);
    final room = game.layout.rooms['crucible']!;
    final g = room.molten!;
    game.currentRoomId = 'crucible';
    void park() {
      // The north field, on the far side of the band from both cisterns.
      game.creatures.single
        ..position = _center(room, g, 1, 1)
        ..lastSafe = _center(room, g, 1, 1);
    }

    park();
    game.update(1 / 60);
    final cells = game.moltenCells['crucible']!;
    // The two cisterns sit behind the inner gates of the band.
    expect(cells[6][5], 3);
    expect(cells[6][7], 3);
    // Asleep: nothing creeps, however long you wait.
    for (var i = 0; i < 60 * 5; i++) {
      park();
      game.update(1 / 60);
    }
    expect(cells[7][5], 0, reason: 'a sleeping cistern never creeps');
    expect(cells[7][7], 0);

    // Woken: each claims its neighbours within a beat.
    game.wokeRooms.add('crucible');
    for (var i = 0; i < 60 * 3; i++) {
      park();
      game.update(1 / 60);
    }
    expect(cells[7][5], 3, reason: 'a woken cistern floods its neighbours');
    expect(cells[7][7], 3, reason: 'and so does the other');
  });

  test('the crucible rite is a QUENCHING: the source, before the pedestal', () {
    final game = _harness([
      _member(0, 'Steam', 'pip'),
      _member(1, 'Earth', 'horn'),
      _member(2, 'Fire', 'mask'),
    ]);
    final room = game.layout.rooms['crucible']!;
    final g = room.molten!;
    game.currentRoomId = 'crucible';
    game.update(1 / 60);
    final cells = game.moltenCells['crucible']!;

    void park(int c, int r, int fc, int fr) {
      final p = _center(room, g, c, r);
      final ang = atan2((fr - r).toDouble(), (fc - c).toDouble());
      for (final cr in game.creatures) {
        cr
          ..position = p
          ..lastSafe = p
          ..angle = ang
          ..aimAngle = ang;
      }
    }

    // Break the band and walk to the pedestal with the reservoir still live.
    game.setActive(2);
    park(4, 4, 4, 5);
    game.activateAbility();
    expect(game.wokeRooms, contains('crucible'));
    park(6, 7, 6, 7);
    game.update(1 / 60);
    expect(
      game.moltenRiteDone,
      isFalse,
      reason: 'the pedestal will not sink while the source still runs',
    );
    game.askForRoomHint();
    expect(game.hintChannel, DungeonHintChannel.blocked);
    game.askForRoomHint();
    expect(game.hintText, contains('run'));

    // Still the reservoir — the three veins that hang above the band — and
    // the same pedestal answers. (Quenching never wakes anything; only
    // breaking rock does, which is why the order is the whole rite.)
    game.setActive(0);
    for (final c in [5, 6, 7]) {
      var guard = 0;
      while (game.steamBreath < 1 && guard++ < 60 * 10) {
        game.update(1 / 60);
      }
      park(c, 4, c, 3);
      game.activateAbility();
      expect(cells[3][c], 0, reason: 'reservoir vein $c stilled');
    }
    park(6, 7, 6, 7);
    game.update(1 / 60);
    expect(
      game.moltenRiteDone,
      isTrue,
      reason: 'a stilled source performs the rite',
    );
  });

  test('a breach RUNS: fresh fire-blood will not take the breath', () {
    // THE PLANET'S POINT (playtest): melt and quench used to cancel, so two
    // presses turned a wall into floor and the creep never happened. A breach
    // now runs for its beat before it can be stilled.
    final game = _harness([
      _member(0, 'Steam', 'pip'),
      _member(1, 'Earth', 'horn'),
      _member(2, 'Fire', 'mask'),
    ]);
    final room = game.layout.rooms['crucible']!;
    final g = room.molten!;
    game.currentRoomId = 'crucible';
    game.update(1 / 60);
    final cells = game.moltenCells['crucible']!;

    void park(int c, int r, int fc, int fr) {
      final p = _center(room, g, c, r);
      final ang = atan2((fr - r).toDouble(), (fc - c).toDouble());
      for (final cr in game.creatures) {
        cr
          ..position = p
          ..lastSafe = p
          ..angle = ang
          ..aimAngle = ang;
      }
    }

    // Break a band gate.
    game.setActive(2);
    park(4, 4, 4, 5);
    game.activateAbility();
    expect(cells[5][4], 3, reason: 'the breach runs molten');

    // Quench it on the spot: refused, and the breath is NOT spent.
    final breath = game.steamBreath;
    game.setActive(0);
    game.activateAbility();
    expect(cells[5][4], 3, reason: 'you cannot cork your own breach');
    expect(game.steamBreath, breath, reason: 'a refusal costs nothing');
    game.askForRoomHint();
    expect(game.hintChannel, DungeonHintChannel.blocked);

    // Let it have its beat — now the breath takes.
    for (var i = 0; i < 60 * 2.5; i++) {
      game.update(1 / 60);
    }
    park(4, 4, 4, 5);
    game.setActive(0);
    game.activateAbility();
    expect(cells[5][4], 0, reason: 'a spent breach stills to standing stone');
  });

  test('the vault cannot be taken cheaply: the disc refuses a short surge and '
      'takes nothing for the attempt', () {
    // WHAT THIS REPLACES: a test of the old Cinder Forge — a two-thick plug
    // with two pours boxed in bedrock under the only cell it could be worked
    // from. That whole room was retired on 2026-08-14 and rebuilt as a geyser
    // field, so the test was describing furniture that no longer exists. The
    // vault's guard is the BURST DISC now, and this is that guard: it opens to
    // one whole-main surge or to nothing, and a short one is not part-paid.
    final game = _harness([
      _member(0, 'Steam', 'pip'),
      _member(1, 'Earth', 'horn'),
      _member(2, 'Fire', 'mask'),
    ]);
    final south = game.layout.rooms['manifold_south']!;
    final disc = south.burstDisc!;
    game.currentRoomId = 'manifold_south';
    game.setActive(0);
    game.update(1 / 60);

    expect(
      game.boilerPressure,
      lessThan(disc.threshold),
      reason: 'the starting head is deliberately short of the disc',
    );
    final before = game.boilerPressure;
    final at = disc.position + const Offset(30, 0);
    game.creatures[0]
      ..position = at
      ..lastSafe = at;
    game.activateAbility();
    expect(game.burstDiscBlown, isFalse, reason: 'a short surge does nothing');
    expect(
      game.boilerPressure,
      before,
      reason:
          'and it costs NOTHING — a disc that skimmed the main on a failed '
          'attempt would make the vault a grind rather than a decision',
    );

    // Stoked past the threshold, the same act blows it and spends everything.
    game.boilerPressure = disc.threshold + 5;
    game.activateAbility();
    expect(game.burstDiscBlown, isTrue);
    expect(
      game.boilerPressure,
      0,
      reason: 'venting the main dumps EVERYTHING — the sacrifice is whole',
    );
  });

  test('breaching a WET dam section floods your own chamber', () {
    // This test had no subject for weeks: the crucible's cisterns sat
    // DIAGONALLY beside the gates instead of orthogonally behind them, and
    // `_wallIsWet` only looks at the four orthogonal neighbours, so every gate
    // on the planet was dry. Two characters in the authored rows put the
    // choice back — see the layout test's gate-wetness invariant.
    final game = _harness([
      _member(0, 'Steam', 'pip'),
      _member(1, 'Earth', 'horn'),
      _member(2, 'Fire', 'mask'),
    ]);
    final room = game.layout.rooms['crucible']!;
    final g = room.molten!;
    game.currentRoomId = 'crucible';
    game.update(1 / 60);
    final cells = game.moltenCells['crucible']!;
    // (5,5) is the west pair's INNER gate — the short way to the pedestal, and
    // the one with a cistern leaning on it from behind.
    expect(cells[5][5], 1);
    expect(cells[6][5], 3, reason: 'the cistern that makes it wet');
    expect(game.gateWetness('crucible')['5,5'], isTrue);

    // Fire breaches it from the NORTH field — the side the player is on.
    game.setActive(2);
    final stand = _center(room, g, 5, 4);
    for (final c in game.creatures) {
      c
        ..position = stand
        ..lastSafe = stand
        ..angle = pi / 2
        ..aimAngle = pi / 2; // facing down at the wet gate
    }
    game.activateAbility();
    expect(cells[5][5], 3, reason: 'the breach itself runs molten');

    // Stand clear and let the beats pass: what was behind the gate comes
    // through it, into the chamber you are standing in.
    final safe = _center(room, g, 1, 1);
    for (var i = 0; i < 60 * 4; i++) {
      for (final c in game.creatures) {
        c
          ..position = safe
          ..lastSafe = safe;
      }
      game.update(1 / 60);
    }
    expect(
      cells[4][5],
      3,
      reason: 'a wet breach floods NORTH — your own side of the band',
    );
  });

  test('cooling breath is finite and returns with the beat', () {
    final game = _harness([_member(0, 'Steam', 'pip')]);
    final room = game.layout.rooms['crucible']!;
    final g = room.molten!;
    game.currentRoomId = 'crucible';
    game.update(1 / 60);
    final cells = game.moltenCells['crucible']!;
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
    expect(
      cells[9][4 + kSteamBreathMax],
      3,
      reason: 'the breath ran out before the last cell',
    );
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
    final room = game.layout.rooms['crucible']!;
    final g = room.molten!;
    // (This read `ember_causeway` while measuring against the crucible's
    // geometry — fine while that room had a grid of its own shape, fatal
    // since the 2026-08-14 geyser rework took its grid away entirely.)
    game.currentRoomId = 'crucible';
    game.setActive(0);
    game.update(1 / 60);
    final cells = game.moltenCells['crucible']!;
    // Active stands clear on the south field; the IDLE Earth companion is at
    // (2,8). Row 9 is bedrock, so everyone stands a row up from where this
    // test used to put them.
    game.creatures[0]
      ..position = _center(room, g, 7, 8)
      ..lastSafe = _center(room, g, 7, 8);
    final idle = game.creatures[1]
      ..position = _center(room, g, 2, 8)
      ..lastSafe = _center(room, g, 3, 8);
    game.creatures[2]
      ..position = _center(room, g, 9, 8)
      ..lastSafe = _center(room, g, 9, 8);
    // The flood claims the idle companion's cell.
    cells[8][2] = 3;
    game.update(1 / 60);
    expect(
      idle.hp,
      lessThan(idle.maxHp),
      reason: 'an idle companion standing in molten scalds',
    );
    expect(
      game.moltenScalds,
      greaterThan(0),
      reason: 'a companion scald spoils the Hidden Harmony too',
    );
    final (ic, ir) = (
      ((idle.position.dx - room.bounds.left) / (room.bounds.width / g.cols))
          .floor(),
      ((idle.position.dy - room.bounds.top) / (room.bounds.height / g.rowCount))
          .floor(),
    );
    expect(cells[ir][ic], 0, reason: 'the companion scrambled to open ground');
  });

  test('a molten rescue never crosses the dam (no teleport through walls)', () {
    final game = _harness([_member(0, 'Steam', 'pip')]);
    final room = game.layout.rooms['crucible']!;
    final g = room.molten!;
    game.currentRoomId = 'crucible';
    game.update(1 / 60);
    final cells = game.moltenCells['crucible']!;
    // Drown the ENTIRE south field (rows 6-8). The nearest open ground by
    // pure distance is then across the band, on the north side of a wall the
    // creature cannot pass — the rescue must never put it there.
    // (Rows 7-10 of a twelve-row chamber, once. The crucible is ten rows.)
    for (var r = 6; r <= 8; r++) {
      for (var c = 1; c <= 11; c++) {
        cells[r][c] = 3;
      }
    }
    final pos = _center(room, g, 4, 6); // just south of the dry west gate
    game.creatures.single
      ..position = pos
      ..lastSafe = pos; // last safe ground is drowned too
    game.update(1 / 60);
    expect(
      game.creatures.single.position.dy,
      greaterThan(room.bounds.top + room.bounds.height * 6 / 10),
      reason:
          'the creature stays on ITS side of the band — the old spiral '
          'search teleported it through the wall into the north field',
    );
    expect(
      cells[6][4],
      0,
      reason: 'with no reachable ground, the footing crusts underfoot',
    );
  });

  test('Earth cannot entomb a companion by walling their cell', () {
    final game = _harness([
      _member(0, 'Steam', 'pip'),
      _member(1, 'Earth', 'horn'),
      _member(2, 'Fire', 'mask'),
    ]);
    final room = game.layout.rooms['crucible']!;
    final g = room.molten!;
    game.currentRoomId = 'crucible';
    game.update(1 / 60);
    final cells = game.moltenCells['crucible']!;
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
    expect(
      cells[8][3],
      0,
      reason: 'the wall must refuse to rise on an occupied cell',
    );
  });

  test(
    'a fully flooded room never strands you, and restart wipes it clean',
    () {
      final game = _harness([_member(0, 'Steam', 'pip')]);
      final room = game.layout.rooms['crucible']!;
      final g = room.molten!;
      // (Read `ember_causeway` while measuring the crucible — see above.)
      game.currentRoomId = 'crucible';
      game.update(1 / 60); // build the grid
      final cells = game.moltenCells['crucible']!;

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
      expect(
        game.moltenScalds,
        greaterThan(0),
        reason: 'being engulfed counts as a scald',
      );

      // Restart wipes the chamber back to its authored layout, asleep again.
      game.wokeRooms.add('crucible');
      game.restartRoom();
      expect(game.wokeRooms, isNot(contains('crucible')));
      expect(game.steamBreath, kSteamBreathMax);
      final fresh = game.moltenCells['crucible']!;
      var lava = 0, wall = 0;
      for (final rowCells in fresh) {
        lava += rowCells.where((c) => c == 3).length;
        wall += rowCells.where((c) => c == 1).length;
      }
      final authoredLava = g.rows.fold<int>(
        0,
        (n, line) => n + 'L'.allMatches(line).length,
      );
      final authoredWall = g.rows.fold<int>(
        0,
        (n, line) => n + '#'.allMatches(line).length,
      );
      expect(lava, authoredLava, reason: 'restart restores the authored lava');
      expect(wall, authoredWall, reason: 'restart restores the authored walls');
    },
  );
}
