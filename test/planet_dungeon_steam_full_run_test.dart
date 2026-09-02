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

    // ── STAR 2: THE CINDER FORGE — hold the field, split the party, pour ──
    // Two mouths can be covered and three Alchemons want to cross, so one has
    // to stay holding the field: the stone takes one mouth, Steam takes the
    // other, and Earth and Fire ride the wide throat together. What waits on
    // the far shore is a dry casting mould — Earth's boulder, Fire's flame —
    // which is why Steam is the one that can be spared.
    final forgeRoom0 = room('cinder_forge');
    game.currentRoomId = 'cinder_forge';
    expect(game.earthRock, isNull, reason: 'the causeway keeps its own stone');
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

    // Earth's stone smothers one mouth.
    game.setActive(earth);
    place(earth, mouth('r_hob_a') + const Offset(0, 60), aim: -pi / 2);
    game.activateAbility();
    expect(game.earthRock, isNotNull);
    step(0.8);
    expect(game.cappedGeysers, contains('r_hob_a'));

    // Steam holds the other, and stays there for good.
    place(steam, mouth('r_hob_b'));
    step();
    // A plugged mouth stops venting and its head goes back into the MAIN, so
    // the field feeds the same gauge the ring does — and the riser only
    // clears the chasm on an OVERPRESSURE. Two plugs are worth 80; the main
    // is down to 10 after the junctions, so 90 is not enough and the boiler
    // has to be stoked before anyone rides. This is the one place the ring's
    // economy and a star puzzle are the same number.
    expect(game.launchHead, kSteamStartPressure - 30 + 2 * kSteamCapHead);
    expect(
      game.launchOverpressured,
      isFalse,
      reason: 'a flat main cannot throw anyone, however well the field is held',
    );
    final southPort2 = south.stokePort!;
    actAt('manifold_south', fire, southPort2 + const Offset(30, 0));
    clearWisps();
    game.currentRoomId = 'cinder_forge';
    place(steam, mouth('r_hob_b'));
    place(earth, mouth('r_hob_a') + const Offset(0, 60));
    step();
    expect(game.launchOverpressured, isTrue, reason: 'stoked past the redline');

    // Earth and Fire ride together, east.
    for (final slot in [earth, fire]) {
      place(slot, mouth('r_riser'), aim: 0);
    }
    var frames = 0;
    while (frames++ < 60 * 10) {
      place(steam, mouth('r_hob_b'));
      game.update(1 / 60);
      for (final cr in game.creatures) {
        if (cr.alive) cr.hp = cr.maxHp;
      }
      if (farShore.inflate(2).contains(game.creatures[earth].position) &&
          farShore.inflate(2).contains(game.creatures[fire].position)) {
        break;
      }
    }
    expect(
      farShore.inflate(2).contains(game.creatures[earth].position),
      isTrue,
    );
    expect(farShore.inflate(2).contains(game.creatures[fire].position), isTrue);
    expect(
      farShore.inflate(2).contains(game.creatures[steam].position),
      isFalse,
      reason: 'Steam is still holding the field on the near shore',
    );

    // THE CASTING: a rock on the lip, a flame under it, and keep it running.
    final moat = forgeRoom0.castingMoat!;
    var castGuard = 0;
    while (game.moatFill < 1.0 && castGuard++ < 40) {
      if (game.boulderCharge <= 0.05) {
        game.setActive(earth);
        place(earth, moat.boulderAt);
        game.activateAbility();
      }
      game.setActive(fire);
      place(fire, moat.boulderAt);
      game.activateAbility();
    }
    expect(game.moatFill, 1.0);
    step();
    expect(
      game.hasStar(1),
      isTrue,
      reason: 'the melt reaches the foot — the pedestal yields',
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
    // The ring's last two clamps, paid out of what the launch stoke left.
    // (The main stood at 10 before Star 2 and the third junction was out of
    // reach; the stoke that took the field over its redline is what also
    // bought the rest of the ring. One boiler, one budget, and Star 2 spends
    // from it — which is the whole point of plugged mouths feeding the main.)
    expect(game.boilerPressure, kSteamStartPressure - 30 + kSteamStokeGain);
    actAt(
      'cinder_forge',
      steam,
      forgeNorthDoor.rect.center + const Offset(0, 40),
    );
    expect(game.isDoorLocked(forgeRoom, forgeNorthDoor), isFalse);
    final afterNorth = kSteamStartPressure - 30 + kSteamStokeGain - 15;
    expect(game.boilerPressure, afterNorth);
    // Exactly one junction's worth left, and nothing else. Closing the ring
    // empties the main, and the burst-disc vault wants a 60-surge in one go,
    // so the whole cost is paid again in stokes — and in the wisps each one
    // brings — before the treasury is even on the table.
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

    // ── Rite: the Crucible — FOUR CORNERS, and the party is the pressure ──
    // Each corner's vents bleed until it is sealed; a sealed corner holds its
    // own for ever, so every one you finish throws the next further. A throw
    // wants the head past the redline, which on this boiler means TWO VENTS
    // HELD — one of you moves, two of you stand.
    final cruc = room('crucible');
    game.currentRoomId = 'crucible';
    Offset mouth2(String id) =>
        cruc.geysers.firstWhere((gy) => gy.id == id).position;
    Offset sealAt(String id) =>
        cruc.crucibleSeals.firstWhere((cs) => cs.id == id).position;
    void put(int slot, Offset at, {double? aim}) {
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

    void sealWith(int slot, String corner) {
      game.setActive(slot);
      put(slot, sealAt(corner));
      game.activateAbility();
      expect(game.sealedCorners, contains(corner), reason: '$corner shuts');
    }

    /// Hold [holders] on vents and throw [rider] along [aim].
    void fly(int rider, String from, double aim, List<(int, String)> holders) {
      for (final (slot, vent) in holders) {
        put(slot, mouth2(vent));
      }
      put(rider, mouth2(from), aim: aim);
      var frames = 0;
      final before = game.creatures[rider].position;
      while (frames++ < 60 * 12) {
        for (final (slot, vent) in holders) {
          put(slot, mouth2(vent));
        }
        game.update(1 / 60);
        for (final cr in game.creatures) {
          if (cr.alive) cr.hp = cr.maxHp;
        }
        if ((game.creatures[rider].position - before).distance > 60 &&
            !game.geyserFlightActive) {
          break;
        }
      }
    }

    // The ring left the main empty, and a throw wants it past the redline —
    // so the finale is paid for out of the same boiler as everything else.
    while (game.boilerPressure < 20) {
      actAt('manifold_north', fire, north.stokePort! + const Offset(30, 0));
      clearWisps();
    }
    game.currentRoomId = 'crucible';
    put(0, mouth2('nw_a'));
    put(1, mouth2('nw_b'));
    put(2, sealAt('nw'));
    step();
    expect(
      game.launchOverpressured,
      isTrue,
      reason: 'two vents held is a working head',
    );

    // The centre is not there, and the way on is not open.
    final onward = cruc.doors.firstWhere(
      (d) => d.targetRoomId == 'boiler_heart',
    );
    expect(game.isDoorLocked(cruc, onward), isTrue);

    // NW is Steam's. Sealing needs no head at all — it is the throws that do.
    sealWith(steam, 'nw');

    // Earth south to SW (300px), two holding.
    fly(earth, 'nw_r', pi / 2, [(steam, 'nw_a'), (fire, 'nw_b')]);
    expect(
      cruc.platforms[2].inflate(2).contains(game.creatures[earth].position),
      isTrue,
      reason: 'the vertical hop is the only one in reach cold',
    );
    sealWith(earth, 'sw');
    expect(game.sealedCorners.length, 2);

    // TWO SEALED opens the crossing. Fire east to NE (520px) — and it takes
    // two bodies on vents on top of the seals to make that reach.
    fly(fire, 'nw_r', 0, [(steam, 'nw_a'), (earth, 'sw_a')]);
    expect(
      cruc.platforms[1].inflate(2).contains(game.creatures[fire].position),
      isTrue,
      reason: 'the horizontal only opens once two corners hold themselves',
    );
    sealWith(fire, 'ne');

    // The last corner wants Earth AND Fire together, which is why it waits
    // for three seals and the slack they bring.
    fly(earth, 'sw_r', 0, [(steam, 'nw_a'), (fire, 'ne_a')]);
    expect(
      cruc.platforms[3].inflate(2).contains(game.creatures[earth].position),
      isTrue,
    );
    put(fire, sealAt('se'));
    game.setActive(earth);
    put(earth, sealAt('se'));
    game.activateAbility();
    expect(game.sealedCorners.length, 4, reason: 'both hands on the last one');

    // FOUR SEALED puts the plinth there — but the way on is still shut,
    // because the rite is standing in the heart, not merely being able to.
    expect(game.isDoorLocked(cruc, onward), isTrue);
    put(steam, cruc.centrePlinth!.center);
    step();
    expect(
      game.moltenRiteDone,
      isTrue,
      reason: 'standing in the heart performs the rite',
    );
    expect(
      game.isDoorLocked(cruc, onward),
      isFalse,
      reason: 'and the rite is what opens the way to Boilrog',
    );
    clearWisps();

    // ── Hidden Harmony: the whole labyrinth without one scald ──
    // The rite PAYS OUT through the Rite of Three, so the egg lands when that
    // reaction settles (~4.2s), not on the frame the pedestal sinks.
    expect(game.moltenScalds, 0);
    step(5.0);
    expect(discovered, contains(kSteamHiddenHarmonyEggId));
    clearWisps();

    // ── The burst-disc: stoke the main to a 60-surge, then vent it all ──
    final disc = south.burstDisc!;
    // Set the main deliberately short of the disc: what is being tested here
    // is the REFUSAL, not the arithmetic of everything that came before it.
    // (The pour READS the head to size a run but never spends it, so a
    // re-plan in the crucible costs nothing — which is the point of the room.)
    game.boilerPressure = disc.threshold - 5;
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

  // v2: damming is ELEMENT-ONLY. Any Earth drives the wall home clean — the
  // old "a Horn sets it clean, everyone else raises a racket that draws wisps"
  // split is gone.
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
        // Let any previous transition's door cooldown lapse. Without this a
        // short walk can cross the whole doorway while the cooldown is still
        // running and come out the far side of it — which looked exactly like
        // an unreachable door and was nothing of the kind.
        game.joystickDirection = Offset.zero;
        for (var i = 0; i < 45; i++) {
          game.update(1 / 60);
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
}
