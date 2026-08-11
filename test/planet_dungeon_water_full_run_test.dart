// The Mirror-Tide Temple (Water), mechanic by mechanic — the focused style
// Steam and Lightning use. One end-to-end run proves the dungeon is
// completable with the real verbs; the rest of the file pins the pieces that
// can silently rot:
//
//  • Star 2 is a DEDUCTION now (docs §6.4 REWORK / §9.1 item 2): the spin
//    rule, the spin→flow derivation, the solver's uniqueness guarantee, the
//    per-run roll, the re-cut insight tiers, and the wrong-eddy scatter.
//  • The Leviathan turns the tide on its roar (§7 retrofit) and hides in the
//    swell — and raids stay exempt.
//  • The invariants the rework was not allowed to touch: the Water+Pip
//    pipe-mouth hard gate, the moon-pool rite, the Frozen Moon egg, the
//    pearl cache, the guardian relic.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/raid_state.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_companion_stats.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart'
    show CosmicSurvivalCompanion;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _member(
  int slot,
  String element,
  String family, {
  double intelligence = 3,
}) {
  return CosmicPartyMember(
    instanceId: 'inst_$slot',
    baseId: 'base_$slot',
    displayName: '$element $family',
    element: element,
    family: family,
    level: 10,
    statSpeed: 3,
    statIntelligence: intelligence,
    statStrength: 3,
    statBeauty: 3,
    slotIndex: slot,
    staminaBars: 3,
    staminaMax: 3,
  );
}

PlanetDungeonGame _harness(
  List<CosmicPartyMember> party, {
  void Function(int)? onStarEarned,
  void Function(String)? onCloudDiscovered,
  void Function()? onPlayerDown,
}) {
  final game = PlanetDungeonGame(
    element: 'Water',
    party: party,
    initialStarMask: 0,
    onStarEarned: onStarEarned ?? (_) {},
    onCloudDiscovered: onCloudDiscovered,
    onPlayerDown: onPlayerDown ?? () {},
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

/// A moon-well harness with the rite unlocked and the tide settled MID — the
/// only state in which the pools take ice. Slot 0 is a Water Pip (it works the
/// pipe-mouth); [m] is the creature under test, left active in slot 1.
PlanetDungeonGame _moonWellAtMidTide(CosmicPartyMember m) {
  final game = _harness([_member(0, 'Water', 'pip'), m]);
  game.starMask = (1 << 0) | (1 << 1); // the pools wait on the rite
  game.currentRoomId = 'moon_well';
  final mouth = game.layout.rooms['moon_well']!.tideValves.single;
  for (final c in game.creatures) {
    c
      ..position = mouth.position
      ..lastSafe = mouth.position;
  }
  game.setActive(0);
  var guard = 0;
  while (game.tideLevel != 1 && guard++ < 6) {
    game.activateAbility();
  }
  expect(game.tideLevel, 1, reason: 'the pipe-mouth must reach mid water');
  guard = 0;
  while (!game.tideSettled && guard++ < 900) {
    game.update(1 / 60);
    for (final c in game.creatures) {
      c.hp = c.maxHp;
    }
  }
  expect(game.tideSettled, isTrue, reason: 'the tide must settle');
  game.setActive(1);
  return game;
}

/// A gallery harness with a Spirit creature in slot 0 (Int decides the tier)
/// and the current pinned to a known course, so a test never has to fight the
/// per-run roll to say something exact about the wade.
PlanetDungeonGame _galleryWithCourse(
  List<String> route, {
  double intelligence = 3,
}) {
  final game = _harness([_member(0, 'Spirit', 'mask', intelligence: intelligence)]);
  game.adoptGhostRoute(route);
  game.currentRoomId = 'ghost_gallery';
  final at = game.layout.rooms['ghost_gallery']!.bounds.center;
  game.creatures.single
    ..position = at
    ..lastSafe = at;
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the authored trio can earn all three Water stars end-to-end', () {
    final earned = <int>[];
    final discovered = <String>[];
    final party = [
      _member(0, 'Water', 'pip'),
      _member(1, 'Spirit', 'mask'),
      _member(2, 'Ice', 'mane'),
    ];
    final game = _harness(
      party,
      onStarEarned: earned.add,
      onCloudDiscovered: discovered.add,
      onPlayerDown: () => fail('the scripted run must never wipe'),
    );

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

    void settleTide() {
      var guard = 0;
      while (!game.tideSettled && guard++ < 600) {
        game.update(1 / 60);
      }
      expect(game.tideSettled, isTrue, reason: 'the tide must settle');
    }

    // ── Entry: Water fills the dry offering-bowl ──
    game.setActive(0); // Water pip
    teleport('tide_gate', kTideGateBowl);
    game.activateAbility();
    step();
    expect(game.entryDoorRevealed, isTrue, reason: 'water wakes the way in');
    expect(discovered, contains(PlanetDungeonGame.entryDoorDiscoveryId));

    // ── The mirror gate is sealed until both stars bank ──
    final court = room('drowned_court');
    final mirrorGate = court.doors.firstWhere(
      (d) => d.targetRoomId == 'moon_hall',
    );
    expect(game.isDoorLocked(court, mirrorGate), isTrue);

    // ── Star 1: three sluice seals, one per tide stand ──
    final works = room('tide_works');
    Offset sealAt(String id) =>
        works.tideSeals.firstWhere((s) => s.id == id).position;
    Offset valveAt(int level) =>
        works.tideValves.firstWhere((v) => v.level == level).position;

    expect(game.tideLevel, 0);
    expect(game.tideSettled, isTrue, reason: 'the temple starts at low water');
    teleport('tide_works', sealAt('seal_low'));
    game.activateAbility();
    expect(game.openedSeals, contains('seal_low'));
    // The tally is a READOUT now, not a line that fades (§5.6).
    expect(game.progressReadout?.label, 'SLUICES');
    expect(game.progressReadout?.value, '1/3');
    clearWisps();

    // The tide ANIMATES: setting mid leaves the water moving, then settled.
    teleport('tide_works', valveAt(1));
    game.activateAbility(); // Water PIP = the valve answers instantly
    expect(game.tideLevel, 1);
    expect(game.tideSettled, isFalse, reason: 'the flood is animated');
    step(0.5);
    expect(
      game.tideSettled,
      isFalse,
      reason: 'half a second in, the water is still climbing',
    );
    expect(game.tideAnim, greaterThan(0.05));
    settleTide();
    teleport('tide_works', sealAt('seal_mid'));
    game.activateAbility();
    expect(game.openedSeals, contains('seal_mid'));
    clearWisps();

    teleport('tide_works', valveAt(2));
    game.activateAbility();
    settleTide();
    teleport('tide_works', sealAt('seal_high'));
    game.activateAbility();
    step();
    expect(game.hasStar(0), isTrue, reason: 'three sluices bank Star 1');
    clearWisps();

    // ── The pearl passage drowns above low tide ──
    final gallery = room('ghost_gallery');
    final pearlDoor = gallery.doors.firstWhere(
      (d) => d.targetRoomId == 'pearl_vault',
    );
    expect(
      game.isDoorLocked(gallery, pearlDoor),
      isTrue,
      reason: 'high water drowns the pearl passage',
    );

    // ── Star 2: Spirit bares the SPINS; the order is derived from them ──
    game.setActive(1); // Spirit mask
    teleport('ghost_gallery', gallery.bounds.center);
    game.activateAbility();
    expect(
      game.eddiesBared,
      isTrue,
      reason: 'Spirit insight bares the ghost current',
    );
    // The player derives the course from what they can see; so does the test.
    final derived = game.solveGhostCurrent();
    expect(derived.satisfying, 1, reason: 'the spins allow exactly one course');
    final course = derived.order!;
    Offset eddyAt(String id) =>
        gallery.ghostEddies.firstWhere((e) => e.id == id).position;

    // Start the course, then blunder into a later eddy: the current scatters.
    teleport('ghost_gallery', eddyAt(course[0]));
    step();
    expect(game.eddyProgress, 1);
    expect(game.progressReadout?.label, 'EDDIES');
    expect(game.progressReadout?.value, '1/5');
    teleport('ghost_gallery', eddyAt(course[2]));
    step();
    expect(game.eddyProgress, 0, reason: 'a wrong eddy scatters the current');
    expect(
      game.combatEnemies.where((e) => !e.isDead),
      isNotEmpty,
      reason: 'the scattered ghost-water rises angry',
    );
    clearWisps();
    for (final id in course) {
      teleport('ghost_gallery', eddyAt(id));
      step();
    }
    expect(game.hasStar(1), isTrue, reason: 'the derived course banks Star 2');
    expect(game.guardianRiteUnlocked, isTrue);
    expect(
      game.isDoorLocked(court, mirrorGate),
      isFalse,
      reason: 'Tide and Current part the mirror gate',
    );
    clearWisps();

    // ── Star 3: the moon-pools at the settled MIDDLE water ──
    final well = room('moon_well');
    Offset poolAt(String id) =>
        well.moonPools.firstWhere((p) => p.id == id).position;
    final pipMouth = well.tideValves.single.position;

    // The pipe-mouth refuses a non-Pip…
    game.setActive(2); // Ice mane
    teleport('moon_well', pipMouth);
    game.activateAbility();
    expect(game.tideLevel, 2, reason: 'the pipe-mouth answers only a Pip');
    // …and cycles for the Water pip: high → low.
    game.setActive(0);
    teleport('moon_well', pipMouth);
    game.activateAbility();
    expect(game.tideLevel, 0);
    settleTide();
    expect(
      game.isDoorLocked(gallery, pearlDoor),
      isFalse,
      reason: 'low water bares the pearl passage',
    );

    // ── The pearl vault's cache, behind the low-tide passage ──
    teleport('pearl_vault', room('pearl_vault').vaultCache!);
    step();
    expect(
      discovered,
      contains('cache:water_vault'),
      reason: 'the pearl vault pays its bottled essence, once',
    );

    // Pools refuse the wrong tide.
    game.setActive(2); // Ice
    teleport('moon_well', poolAt('pool_nw'));
    game.activateAbility();
    expect(
      game.poolStates['pool_nw'] ?? 0,
      0,
      reason: 'low water holds no moon',
    );

    // Cycle low → mid and freeze.
    game.setActive(0);
    teleport('moon_well', pipMouth);
    game.activateAbility();
    expect(game.tideLevel, 1);
    settleTide();

    game.setActive(2); // Ice mane — the clean freeze
    teleport('moon_well', poolAt('pool_nw'));
    game.activateAbility();
    expect(game.poolStates['pool_nw'], 1, reason: 'the true pool takes the ice');

    // A false pool shatters and rouses the brine.
    teleport('moon_well', poolAt('pool_ne'));
    game.activateAbility();
    expect(game.poolStates['pool_ne'] ?? 0, 0, reason: 'false pools shatter');
    expect(game.combatEnemies.where((e) => !e.isDead), isNotEmpty);
    clearWisps();

    // PARITY: Spirit standing in the water braids the same ice (recipe).
    game.setActive(1); // Spirit mask
    teleport('moon_well', poolAt('pool_se'));
    game.activateAbility();
    expect(
      game.poolStates['pool_se'],
      1,
      reason: 'Spirit+Water→Ice freezes the second true pool',
    );
    expect(
      game.guardianAwake,
      isTrue,
      reason: 'the bridged well wakes the deep',
    );
    clearWisps();

    // ── The Lost Maxim: freeze the moon's drifting reflection (mid tide) ──
    game.setActive(2); // Ice
    final glint = game.frozenMoonGlint();
    expect(glint, isNotNull, reason: 'mid tide floats the moon glint');
    teleport('reflection_court', glint!);
    game.activateAbility();
    expect(
      discovered,
      contains(kWaterFrozenMoonEggId),
      reason: 'ice on the glint freezes the moon (screen pays the 20 gold)',
    );

    // ── The Leviathan: paced lull strikes until it yields ──
    final guardianNode = room('leviathan_depths').guardian!;
    teleport('leviathan_depths', guardianNode.position + const Offset(0, 80));
    var safety = 0;
    while (!game.hasStar(2) && safety++ < 900) {
      final leviathan = game.combatEnemies
          .where((e) => e.isElite)
          .firstOrNull;
      if (leviathan != null && !leviathan.isDead) {
        leviathan.position = game.creatures[game.activeIndex].position;
      }
      if (game.guardianVulnerable) game.activateAbility();
      step(0.3);
    }
    expect(game.hasStar(2), isTrue, reason: 'lull strikes fell the guardian');
    expect(
      game.leviathanRoars,
      greaterThan(0),
      reason: 'the deep turned the tide during the fight',
    );
    expect(game.relicDropActive, isTrue);

    expect(earned, [0, 1, 2], reason: 'stars bank in play order, once each');
    expect(game.starsEarnedCount, 3);
  });

  // ── Star 2: the spin → flow derivation ────────────────────

  test('THE RULE: an eddy rolls the way its feeder drives it', () {
    final game = _harness([_member(0, 'Spirit', 'mask')]);
    final gallery = game.layout.rooms['ghost_gallery']!;
    final at = {
      for (final m in gallery.ghostMouths) m.id: m.position,
      for (final e in gallery.ghostEddies) e.id: e.position,
    };
    // Every route the stone allows, every eddy on it: the spin the gallery
    // shows must be exactly "is my feeder west of me?" — nothing else is
    // hidden, and nothing else may leak in.
    for (final route in game.ghostRoutes()) {
      game.adoptGhostRoute(route);
      for (var i = 1; i < route.length - 1; i++) {
        final eddy = route[i], feeder = route[i - 1];
        expect(
          game.eddySpinSunwise(eddy),
          at[feeder]!.dx < at[eddy]!.dx,
          reason: '$eddy fed from $feeder must roll '
              '${at[feeder]!.dx < at[eddy]!.dx ? 'sunwise' : 'widdershins'}',
        );
      }
    }
  });

  test('the wade order is DERIVED from the spins, and the spins alone pin it',
      () {
    final game = _harness([_member(0, 'Spirit', 'mask')]);
    final gallery = game.layout.rooms['ghost_gallery']!;
    final routes = game.ghostRoutes();
    expect(routes.length, 6, reason: 'twelve channels, six spring→sea routes');

    for (final route in routes) {
      game.adoptGhostRoute(route);
      // Hand the solver ONLY what a player can see.
      final spins = {
        for (final e in gallery.ghostEddies) e.id: game.eddySpinSunwise(e.id)!,
      };
      final result = game.solveGhostCurrent(spins);
      expect(result.searched, 6);
      expect(
        result.satisfying,
        1,
        reason: 'the spins of ${route.join('→')} must single it out',
      );
      expect(result.order, route.sublist(1, route.length - 1));
      expect(game.ghostWadeOrder, result.order);
    }
  });

  test('a scrambled reading finds no course at all (the spins are load-bearing)',
      () {
    final game = _harness([_member(0, 'Spirit', 'mask')]);
    final gallery = game.layout.rooms['ghost_gallery']!;
    game.adoptGhostRoute(game.ghostRoutes().first);
    final spins = {
      for (final e in gallery.ghostEddies) e.id: game.eddySpinSunwise(e.id)!,
    };
    // Flip one eddy's spin: no route in the gallery explains the water now.
    final victim = gallery.ghostEddies.first.id;
    final lied = {...spins, victim: !spins[victim]!};
    final result = game.solveGhostCurrent(lied);
    expect(result.searched, 6);
    expect(
      result.satisfying,
      0,
      reason: 'one wrong spin and the reading stops being a course — the '
          'derivation really is driven by the spins',
    );
  });

  test('the current is rolled per run, and never one the spins cannot pin',
      () {
    final seen = <String>{};
    for (var i = 0; i < 24; i++) {
      final game = _harness([_member(0, 'Spirit', 'mask')]);
      expect(game.ghostWadeOrder.length, 5);
      expect(game.solveGhostCurrent().satisfying, 1);
      seen.add(game.ghostWadeOrder.join('>'));
    }
    expect(seen.length, greaterThan(1), reason: 'a wiki must not spoil it');
  });

  test('death does not reroll the current — the water keeps its course', () {
    var wiped = false;
    final game = _harness(
      [_member(0, 'Spirit', 'mask')],
      onPlayerDown: () => wiped = true,
    );
    final before = game.ghostWadeOrder;
    final gallery = game.layout.rooms['ghost_gallery']!;
    game.currentRoomId = 'ghost_gallery';
    final first = gallery.ghostEddies
        .firstWhere((e) => e.id == before.first)
        .position;
    game.creatures.single
      ..position = first
      ..lastSafe = first;
    game.activateAbility(); // bare the water
    game.update(1 / 60);
    expect(game.eddyProgress, 1);
    expect(game.eddiesBared, isTrue);

    // A party wipe resets the run.
    game.creatures.single.hp = 0;
    game.update(1 / 60);
    expect(wiped, isTrue, reason: 'the party went down');
    expect(game.eddyProgress, 0, reason: 'the wade resets');
    expect(game.eddiesBared, isFalse, reason: 'the water hides itself again');
    expect(
      game.ghostWadeOrder,
      before,
      reason: 'but the course itself survives the descent — a death costs the '
          'walk back, never the deduction',
    );
  });

  // ── Star 2: insight tiers ────────────────────────────────

  test('insight tiers give progressively more: spins → flow → pips', () {
    final route = _harness([_member(0, 'Spirit', 'mask')]).ghostRoutes().first;

    // t0 — the low-Int Spirit bares the SPINS and is taught the RULE. That is
    // all: the evidence, and how to read it.
    final t0 = _galleryWithCourse(route, intelligence: 1);
    t0.activateAbility();
    expect(t0.eddiesBared, isTrue);
    expect(t0.eddyRevealTier, 0);
    expect(t0.hintChannel, DungeonHintChannel.insight);
    expect(t0.hintText, contains('feeder'));
    expect(
      t0.hintText,
      contains('sunwise'),
      reason: 'tier 0 teaches the rule, not the answer',
    );

    // t1 — the flow itself, drawn along the channels: no deduction left, but
    // the course still has to be traced.
    final t1 = _galleryWithCourse(route, intelligence: 3);
    t1.activateAbility();
    expect(t1.eddyRevealTier, 1);
    expect(t1.hintText, contains('flow'));

    // t2 — the water counts itself: the pips, today's old baseline, now the
    // high-Int reward instead of the default.
    final t2 = _galleryWithCourse(route, intelligence: 5);
    t2.activateAbility();
    expect(t2.eddyRevealTier, 2);
    expect(t2.hintText, contains('counts'));

    // The tiered extras ride a timer that Intelligence buys; the SPINS do
    // not — they stay bare for the run.
    expect(t2.eddyRevealTimer, greaterThan(t0.eddyRevealTimer));
    for (var i = 0; i < 60 * 30; i++) {
      t0.update(1 / 60);
    }
    expect(t0.eddyRevealTimer, lessThanOrEqualTo(0));
    expect(
      t0.eddiesBared,
      isTrue,
      reason: 'a deduction you cannot look at twice is only a memory test',
    );
  });

  test('only Spirit bares the water; a non-Spirit Mask still reads the rule',
      () {
    final route = _harness([_member(0, 'Spirit', 'mask')]).ghostRoutes().first;

    // A Water horn: one clause of refusal, and nothing bared.
    final horn = _harness([_member(0, 'Water', 'horn')]);
    horn.adoptGhostRoute(route);
    horn.currentRoomId = 'ghost_gallery';
    horn.creatures.single.position =
        horn.layout.rooms['ghost_gallery']!.bounds.center;
    horn.activateAbility();
    expect(horn.eddiesBared, isFalse);
    expect(horn.hintChannel, DungeonHintChannel.blocked);
    expect(horn.hintText, 'Only Spirit bares the ghost-water');

    // An Ice mask cannot bare the water either — but the frieze is stone, and
    // a high-Int reading of it gives the RULE (the method channel's job).
    final mask = _harness([_member(0, 'Ice', 'mask', intelligence: 5)]);
    mask.adoptGhostRoute(route);
    mask.currentRoomId = 'ghost_gallery';
    mask.creatures.single.position =
        mask.layout.rooms['ghost_gallery']!.bounds.center;
    mask.activateAbility();
    expect(mask.eddiesBared, isFalse, reason: 'the water stays hidden');
    expect(mask.hintChannel, DungeonHintChannel.insight);
    expect(mask.hintText, contains('sunwise'));
  });

  // ── Star 2: the consequence ──────────────────────────────

  test('a later eddy mid-wade scatters the course and rouses ghost wisps', () {
    final route = _harness([_member(0, 'Spirit', 'mask')]).ghostRoutes().first;
    final game = _galleryWithCourse(route);
    final gallery = game.layout.rooms['ghost_gallery']!;
    Offset at(String id) =>
        gallery.ghostEddies.firstWhere((e) => e.id == id).position;
    final course = game.ghostWadeOrder;

    void wade(String id) {
      game.creatures.single
        ..position = at(id)
        ..lastSafe = at(id);
      game.update(1 / 60);
      game.creatures.single.hp = game.creatures.single.maxHp;
    }

    // Stepping into the WRONG first eddy is free — a course can always be
    // started over cleanly.
    wade(course[1]);
    expect(game.eddyProgress, 0);
    expect(game.combatEnemies.where((e) => !e.isDead), isEmpty);

    wade(course[0]);
    wade(course[1]);
    expect(game.eddyProgress, 2);

    // …but jumping ahead mid-course scatters everything.
    wade(course[4]);
    expect(game.eddyProgress, 0, reason: 'the current scatters');
    expect(
      game.combatEnemies.where((e) => !e.isDead),
      isNotEmpty,
      reason: 'and the ghost-water rises angry',
    );
    expect(game.hintText, contains('scatters'));
  });

  // ── The Leviathan turns the tide (§7 retrofit) ───────────

  PlanetDungeonGame leviathanFight() {
    final game = _harness([_member(0, 'Water', 'pip')]);
    game.starMask = (1 << 0) | (1 << 1);
    game.currentRoomId = 'leviathan_depths';
    final node = game.layout.rooms['leviathan_depths']!.guardian!;
    final stand = node.position + const Offset(0, 200);
    game.creatures.single
      ..position = stand
      ..lastSafe = stand;
    game.guardianAwake = true;
    return game;
  }

  test('Leviathan hauls the tide a stand on every roar, low→mid→high→mid', () {
    final game = leviathanFight();
    final stands = <int>{game.tideLevel};
    for (var i = 0; i < 60 * 40; i++) {
      game.update(1 / 60);
      game.creatures.single.hp = game.creatures.single.maxHp;
      stands.add(game.tideLevel);
    }
    expect(
      game.leviathanRoars,
      greaterThanOrEqualTo(4),
      reason: 'the roar rides the shut of every lull',
    );
    expect(
      stands,
      {0, 1, 2},
      reason: 'the fight is played across ALL THREE stands — the tide rolls, '
          'it does not park',
    );
  });

  test('the lull only opens on SETTLED water — the swell is its armour', () {
    final game = leviathanFight();
    var sawMovingWater = false;
    var sawWindow = false;
    for (var i = 0; i < 60 * 40; i++) {
      game.update(1 / 60);
      game.creatures.single.hp = game.creatures.single.maxHp;
      if (!game.tideSettled) {
        sawMovingWater = true;
        expect(
          game.guardianVulnerable,
          isFalse,
          reason: 'nothing touches Leviathan while it rides the swell',
        );
      } else if (game.guardianVulnerable) {
        sawWindow = true;
      }
    }
    expect(sawMovingWater, isTrue, reason: 'the arena really did turn');
    expect(
      sawWindow,
      isTrue,
      reason: 'and the fight stays winnable: settled water still lulls',
    );
  });

  test('the drowned arena answers the tide like every other chamber', () {
    final game = leviathanFight();
    final zones = game.layout.rooms['leviathan_depths']!.tideZones;
    expect(zones.any((z) => !z.ledge), isTrue, reason: 'a sink to swim');
    expect(
      zones.any((z) => z.ledge),
      isTrue,
      reason: 'and piers that drown at high water',
    );
    // Nothing the tide can raise may stand across the way back in.
    final door = game.layout.rooms['leviathan_depths']!.doors.single;
    for (final z in zones.where((z) => z.ledge)) {
      expect(
        z.rect.inflate(24).overlaps(door.rect),
        isFalse,
        reason: 'a rearing pier must never seal the exit',
      );
    }
  });

  test('raids are exempt: the generated arena has no tide to turn', () {
    final game = PlanetDungeonGame(
      element: 'Water',
      party: [_member(0, 'Water', 'pip')],
      initialStarMask: 7,
      onStarEarned: (_) {},
      onPlayerDown: () {},
      onChanged: () {},
      raid: const RaidConfig(),
      layoutOverride: buildRaidArenaLayout('Water'),
    );
    final c = DungeonCreature(member: game.party.single)
      ..position = game.layout.entranceSpawn
      ..lastSafe = game.layout.entranceSpawn;
    game.creatures.add(c);
    game.currentRoomId = game.layout.entranceRoomId;
    expect(
      game.currentRoom.tideZones,
      isEmpty,
      reason: 'the raid arena is generated, and has no tide zones',
    );
    for (var i = 0; i < 60 * 20; i++) {
      game.update(1 / 60);
      c.hp = c.maxHp;
    }
    expect(
      game.leviathanRoars,
      0,
      reason: 'no tide-turn in a raid — the shared cycle carries it',
    );
  });

  // ── Invariants the rework was not allowed to touch ───────

  // v2: the master wheels are ELEMENT-ONLY — every Water family sets the stand
  // at once, silently.
  test('the master valve is element-only: every Water family sets the stand '
      'identically', () {
    for (final family in const [
      'pip', 'mane', 'horn', 'mask', 'wing', 'kin',
    ]) {
      final game = _harness([_member(0, 'Water', family)]);
      final valve = game.layout.rooms['tide_works']!.tideValves
          .firstWhere((v) => v.level == 1);
      game.currentRoomId = 'tide_works';
      game.creatures.single
        ..position = valve.position
        ..lastSafe = valve.position;

      game.activateAbility();
      expect(
        game.tideLevel,
        1,
        reason: 'a Water $family turns the wheel INSTANTLY — no waiting',
      );
      expect(
        game.combatEnemies.where((e) => !e.isDead),
        isEmpty,
        reason: 'a Water $family turns the wheel SILENTLY — no brine',
      );
    }
  });

  test('the pipe-mouth is a hard gate: only a Water pip cycles the tide', () {
    // Right element, wrong family: refused outright — the tide does not move,
    // now or later, and nothing is roused by the refusal.
    for (final family in const ['mane', 'horn', 'mask', 'wing', 'kin']) {
      final game = _harness([_member(0, 'Water', family)]);
      final mouth = game.layout.rooms['moon_well']!.tideValves.single;
      game.currentRoomId = 'moon_well';
      game.creatures.single
        ..position = mouth.position
        ..lastSafe = mouth.position;
      final before = game.tideLevel;
      game.activateAbility();
      for (var i = 0; i < 400; i++) {
        game.update(1 / 60);
        game.creatures.single.hp = game.creatures.single.maxHp;
      }
      expect(
        game.tideLevel,
        before,
        reason: 'a Water $family must never reach down the pipe-mouth',
      );
      expect(
        game.combatEnemies.where((e) => !e.isDead),
        isEmpty,
        reason: 'a clean refusal is not a penalty — no brine rises',
      );
    }

    // A Water Pip cycles it at once.
    final pip = _harness([_member(0, 'Water', 'pip')]);
    final mouth = pip.layout.rooms['moon_well']!.tideValves.single;
    pip.currentRoomId = 'moon_well';
    pip.creatures.single
      ..position = mouth.position
      ..lastSafe = mouth.position;
    final before = pip.tideLevel;
    pip.activateAbility();
    expect(pip.tideLevel, (before + 1) % 3, reason: 'the Pip rides the pipes');
    expect(
      pip.combatEnemies.where((e) => !e.isDead),
      isEmpty,
      reason: 'the Pip rides the pipes silently',
    );
  });

  test('the moon-pool is element-only, but the recipe keeps its downside', () {
    // Every ICE family freezes a true pool clean and SILENT…
    for (final family in const [
      'pip', 'mane', 'horn', 'mask', 'wing', 'kin',
    ]) {
      final game = _moonWellAtMidTide(_member(1, 'Ice', family));
      final pool = game.layout.rooms['moon_well']!.moonPools
          .firstWhere((p) => p.isTrue);
      game.creatures[1]
        ..position = pool.position
        ..lastSafe = pool.position;
      game.activateAbility();
      expect(
        game.poolStates[pool.id],
        1,
        reason: 'an Ice $family must freeze the pool',
      );
      expect(
        game.combatEnemies.where((e) => !e.isDead),
        isEmpty,
        reason: 'ice laid DIRECT is silent for every family ($family)',
      );
    }

    // …while the Spirit+Water→Ice RECIPE still rouses the brine. That is the
    // braid's cost, not a family penalty.
    final spirit = _moonWellAtMidTide(_member(1, 'Spirit', 'mane'));
    final pool = spirit.layout.rooms['moon_well']!.moonPools
        .firstWhere((p) => p.isTrue);
    spirit.creatures[1]
      ..position = pool.position
      ..lastSafe = pool.position;
    spirit.activateAbility();
    expect(spirit.poolStates[pool.id], 1, reason: 'the braid freezes it too');
    expect(
      spirit.combatEnemies.where((e) => !e.isDead),
      isNotEmpty,
      reason: 'the recipe keeps its wisps',
    );
  });
}
