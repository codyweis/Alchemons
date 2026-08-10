// Full-run simulation of the Water dungeon (Mirror-Tide Temple): a headless
// party (the authored Water+Spirit+Ice trio) plays every star from a fresh
// save — the offering-bowl entry, the ANIMATED tide (floods are eased, never
// teleported), the three tide-stand sluice seals, the tide-gated pearl
// passage, the ghost-current eddies (with a wrong-order consequence), the
// moon-pool rite (Ice direct + the Spirit+Water→Ice recipe + a false-pool
// shatter), the frozen-moon easter egg, and the Leviathan — proving the
// whole dungeon is completable end-to-end with the real verbs.

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
    final game = PlanetDungeonGame(
      element: 'Water',
      party: party,
      initialStarMask: 0,
      onStarEarned: earned.add,
      onCloudDiscovered: discovered.add,
      onPlayerDown: () => fail('the scripted run must never wipe'),
      onChanged: () {},
    );
    // Headless wiring (onLoad minus assets).
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

    // ── Star 2: Spirit bares the current; wade the eddies in order ──
    game.setActive(1); // Spirit mask
    teleport('ghost_gallery', gallery.bounds.center);
    game.activateAbility();
    expect(
      game.eddyRevealTimer,
      greaterThan(0),
      reason: 'Spirit insight bares the ghost current',
    );
    Offset eddyAt(int order) =>
        gallery.ghostEddies.firstWhere((e) => e.order == order).position;
    // Start the course, then blunder into a later eddy: the current scatters.
    teleport('ghost_gallery', eddyAt(0));
    step();
    expect(game.eddyProgress, 1);
    teleport('ghost_gallery', eddyAt(2));
    step();
    expect(game.eddyProgress, 0, reason: 'a wrong eddy scatters the current');
    expect(
      game.combatEnemies.where((e) => !e.isDead),
      isNotEmpty,
      reason: 'the scattered ghost-water rises angry',
    );
    clearWisps();
    for (var order = 0; order < gallery.ghostEddies.length; order++) {
      teleport('ghost_gallery', eddyAt(order));
      step();
    }
    expect(game.hasStar(1), isTrue, reason: 'the full course banks Star 2');
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

    // Pools refuse the wrong tide.
    game.setActive(2); // Ice
    teleport('moon_well', poolAt('pool_nw'));
    game.activateAbility();
    expect(game.poolStates['pool_nw'] ?? 0, 0, reason: 'low water holds no moon');

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
    expect(game.guardianAwake, isTrue, reason: 'the bridged well wakes the deep');
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
    while (!game.hasStar(2) && safety++ < 600) {
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
    expect(game.relicDropActive, isTrue);

    expect(earned, [0, 1, 2], reason: 'stars bank in play order, once each');
    expect(game.starsEarnedCount, 3);
  });

  test('a non-Pip valve turn is slow AND loud (wrong-family penalty)', () {
    final party = [_member(0, 'Water', 'mane')]; // right element, wrong family
    final game = PlanetDungeonGame(
      element: 'Water',
      party: party,
      initialStarMask: 0,
      onStarEarned: (_) {},
      onPlayerDown: () {},
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
    final works = game.layout.rooms['tide_works']!;
    final valve = works.tideValves.firstWhere((v) => v.level == 1);
    game.currentRoomId = 'tide_works';
    game.creatures.single
      ..position = valve.position
      ..lastSafe = valve.position;

    game.activateAbility();
    expect(
      game.tideLevel,
      0,
      reason: 'the wrong family waits on the groaning pipes',
    );
    expect(
      game.combatEnemies.where((e) => !e.isDead),
      isNotEmpty,
      reason: 'the groan draws the brine at once',
    );
    // ~5 seconds later the pipes finally answer.
    for (var i = 0; i < 320; i++) {
      game.update(1 / 60);
      game.creatures.single.hp = game.creatures.single.maxHp;
    }
    expect(game.tideLevel, 1, reason: 'the sluggish turn lands after ~5s');
  });
}
