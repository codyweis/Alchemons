// Full-run simulation of the Lightning dungeon (Voltara, the Storm Circuit): a
// headless party (the authored Lightning+Air+Fire trio) plays every star from a
// fresh save — the dead-bus entry charge, the pylon-hall routing (charge +
// rotate mirrors so all three terminals light), the cloud-works storm-cells
// (herd onto sockets + heat the anvil, Air+Fire→Lightning), the rite-shut
// breaker gate, the overload maze + the Thunderbolt egg, the vault cache, and
// Raikuma — proving the whole dungeon is completable end-to-end with the real
// circuit engine. A second test guards the off-family slow-and-loud penalty.

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
    element: 'Lightning',
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

Offset _node(DungeonRoom room, String id) =>
    room.circuitNodes.firstWhere((n) => n.id == id).position;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the authored trio can earn all three Lightning stars end-to-end', () {
    final earned = <int>[];
    final discovered = <String>[];
    final party = [
      _member(0, 'Lightning', 'horn'),
      _member(1, 'Air', 'wing'),
      _member(2, 'Fire', 'pip'),
    ];
    final game = _harness(party, onStar: earned.add, onCloud: discovered.add);

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

    // ── Entry: a Lightning Horn charges the dead bus ──
    game.setActive(0); // Lightning horn
    teleport('arc_gate', _node(room('arc_gate'), 'g_src'));
    game.activateAbility();
    step();
    expect(game.entryDoorRevealed, isTrue, reason: 'power lights the passage');
    expect(discovered, contains(PlanetDungeonGame.entryDoorDiscoveryId));

    // ── The breaker gate is dead until both stars bank ──
    final hub = room('dynamo_court');
    final breaker = hub.doors.firstWhere(
      (d) => d.targetRoomId == 'overload_maze',
    );
    expect(game.isDoorLocked(hub, breaker), isTrue);

    // ── Star 1: thread one bolt through all three terminals ──
    final pylon = room('pylon_hall');
    game.setActive(0); // Lightning horn
    // Charge the pylon (the bolt leaps from it, clean for a Horn).
    teleport('pylon_hall', pylon.beamEmitters.first.position);
    game.activateAbility();
    expect(
      game.combatEnemies.where((e) => !e.isDead),
      isEmpty,
      reason: 'a Horn wakes the pylon CLEAN — no spark wisps',
    );
    // Turn conductors A and B so the one bolt snakes through all three.
    Offset s1mirror(String id) =>
        pylon.beamMirrors.firstWhere((m) => m.id == id).position;
    void s1flip(String id, int target) {
      teleport('pylon_hall', s1mirror(id));
      var guard = 0;
      while ((game.mirrorOrient[id] ?? 0) != target && guard++ < 4) {
        game.activateAbility();
      }
      expect(game.mirrorOrient[id], target);
    }

    s1flip('pa', 1);
    s1flip('pb', 1); // pc stays 0
    step();
    expect(game.hasStar(0), isTrue,
        reason: 'one bolt across all three terminals → Circuit Star');

    // The capacitor vault essence fizzles, once ever.
    teleport('capacitor_vault', room('capacitor_vault').vaultCache!);
    step();
    expect(discovered, contains('cache:lightning_vault'),
        reason: 'the vault cache pays out (screen grants the 5 gold)');

    // ── Star 2: bare the storm-cells, then herd + heat them ──
    final gallery = room('mirror_gallery');
    game.setActive(1); // Air wing
    for (final cell in gallery.stormCells) {
      teleport('mirror_gallery', cell.position);
      step();
      expect(game.discoveredClouds, contains(cell.id),
          reason: 'close approach bares the storm-cell echo');
    }

    final works = room('cloud_works');
    final slotX = works.bounds.left + 110;
    // Spark → socket A, Veil → socket B (both latch live on deposit).
    void herd(String cellId, double slotY, String sockId) {
      game.setActive(1); // Air wing herds clean
      teleport('cloud_works', Offset(slotX, works.bounds.top + slotY));
      game.activateAbility();
      expect(game.carriedCloudId, cellId, reason: 'the echo is gathered');
      final sock = works.cellSockets.firstWhere((s) => s.id == sockId);
      teleport('cloud_works', sock.position);
      game.activateAbility();
    }

    herd('cell_spark', 180, 'sock_a');
    expect(game.energizedSockets, contains('sock_a'));
    herd('cell_veil', 350, 'sock_b');
    expect(game.energizedSockets, contains('sock_b'));
    // Anvil cell: deposit cold, then a Fire creature heats it.
    herd('cell_anvil', 520, 'sock_anvil');
    expect(game.energizedSockets.contains('sock_anvil'), isFalse,
        reason: 'the anvil cell is cold until heated');
    game.setActive(2); // Fire pip
    final anvil = works.cellSockets.firstWhere((s) => s.id == 'sock_anvil');
    teleport('cloud_works', anvil.position);
    game.activateAbility();
    step();
    expect(game.energizedSockets, contains('sock_anvil'),
        reason: 'Air+Fire→Lightning wakes the Thundercloud');
    expect(game.hasStar(1), isTrue, reason: 'three live sockets → Storm Star');
    clearWisps();

    // Both stars banked → the breaker gate throws open.
    expect(game.guardianRiteUnlocked, isTrue);
    expect(game.isDoorLocked(hub, breaker), isFalse,
        reason: 'Circuit and Storm open the breaker gate');

    // ── Storm Spire: station Air + Fire, aim the conductors with Lightning ──
    final maze = room('overload_maze');
    void pinStations() {
      // Air on the vent, Fire on the converter — held there (swap-control
      // placement) while we control Lightning.
      game.creatures[1].position = maze.beamEmitters[0].position; // Air wing
      game.creatures[2].position = maze.beamConverters[0]; // Fire pip
    }

    game.setActive(0); // Lightning horn turns the heavy conductors
    Offset mirror(String id) =>
        maze.beamMirrors.firstWhere((m) => m.id == id).position;
    void flip(String id, int target) {
      pinStations();
      teleport('overload_maze', mirror(id));
      var guard = 0;
      while ((game.mirrorOrient[id] ?? 0) != target && guard++ < 4) {
        game.activateAbility();
      }
      expect(game.mirrorOrient[id], target, reason: '$id set to $target');
    }

    // Solution: A='\'(1) B='/'(0) C='\'(1) D='\'(1) E='/'(0).
    flip('A', 1);
    flip('C', 1);
    flip('D', 1);
    pinStations();
    // Park Lightning clear of the pads; let the beam settle onto the tower.
    teleport('overload_maze', const Offset(420, 200));
    pinStations();
    step();
    expect(discovered, contains(kLightningThunderboltEggId),
        reason: 'Air+Fire born a bolt and a Horn crowned the tower = Thunderbolt');

    // ── Star 3: reach the storm core and fell Raikuma ──
    final guardianNode = room('storm_core').guardian!;
    teleport('storm_core', guardianNode.position + const Offset(0, 80));
    step();
    expect(game.guardianAwake, isTrue, reason: 'the core wakes Raikuma');
    var safety = 0;
    while (!game.hasStar(2) && safety++ < 600) {
      final raikuma = game.combatEnemies.where((e) => e.isElite).firstOrNull;
      if (raikuma != null && !raikuma.isDead) {
        raikuma.position = game.creatures[game.activeIndex].position;
      }
      if (game.guardianVulnerable) game.activateAbility();
      step(0.3);
    }
    expect(game.hasStar(2), isTrue, reason: 'lull strikes fell Raikuma');
    expect(game.relicDropActive, isTrue);

    expect(earned, [0, 1, 2], reason: 'stars bank in play order, once each');
    expect(game.starsEarnedCount, 3);
  });

  test('off-family pylon charge is loud (wrong-family penalty)', () {
    final game = _harness([_member(0, 'Lightning', 'mane')]); // not a Horn
    final pylon = game.layout.rooms['pylon_hall']!;
    game.currentRoomId = 'pylon_hall';
    game.creatures.single
      ..position = pylon.beamEmitters.first.position
      ..lastSafe = pylon.beamEmitters.first.position;

    game.activateAbility(); // an off-family Lightning sputters the pylon alight
    expect(
      game.combatEnemies.where((e) => !e.isDead),
      isNotEmpty,
      reason: 'the loud spark wakes wisps at once',
    );
  });

  test('the storm-core gate opens with the star and never re-locks', () {
    // Drive the active creature DOWN toward the core gate (y≈648) below the
    // tower; report whether it gets blocked or passes through to the core.
    String crawl(PlanetDungeonGame game) {
      game.currentRoomId = 'overload_maze';
      game.creatures.single
        ..position = const Offset(230, 545) // above the gate, below the tower
        ..lastSafe = const Offset(230, 545);
      game.joystickDirection = const Offset(0, 1);
      for (var i = 0; i < 300; i++) {
        game.update(1 / 60);
        if (game.currentRoomId != 'overload_maze') break;
        game.creatures.single.hp = game.creatures.single.maxHp;
      }
      return game.currentRoomId;
    }

    // Fresh, unlit tower: the gate is a wall — you stay in the arena.
    final blocked = _harness([_member(0, 'Lightning', 'horn')]);
    expect(crawl(blocked), 'overload_maze',
        reason: 'the unlit gate is shut');

    // Overload Star banked: the gate stays open, so you pass to the core.
    final solved = _harness([_member(0, 'Lightning', 'horn')]);
    solved.starMask = 1 << 2;
    expect(crawl(solved), 'storm_core',
        reason: 'a banked Overload Star keeps the gate open');
  });

  test('the Storm Spire arena connects to the storm core', () {
    // With the gate open, steer across the arena to the storm_core door (guards
    // the arena geometry / door placement).
    final game = _harness([_member(0, 'Lightning', 'horn')]);
    game.starMask = 1 << 2; // the core gate held open
    game.currentRoomId = 'overload_maze';
    final c = game.creatures.single
      ..position = const Offset(230, 470)
      ..lastSafe = const Offset(230, 470);
    final route = <Offset>[
      const Offset(230, 560), // down past the tower toward the gate
      const Offset(230, 660), // through the gate into the core door
    ];
    var wp = 0;
    var frames = 0;
    while (game.currentRoomId == 'overload_maze' && frames++ < 900) {
      final target = route[wp];
      final to = target - c.position;
      if (to.distance < 14 && wp < route.length - 1) wp++;
      game.joystickDirection =
          to.distance < 1 ? Offset.zero : Offset(to.dx, to.dy) / to.distance;
      game.update(1 / 60);
      c.hp = c.maxHp;
    }
    expect(game.currentRoomId, 'storm_core',
        reason: 'the arena must reach the core door');
  });

  test('the Storm Tower needs BOTH Air on the vent and Fire on the converter',
      () {
    // Aim the mirrors correctly, then test the stationing requirement: only
    // when Air AND Fire are both placed does the tower light (the gate opens).
    String passGate(PlanetDungeonGame game) {
      game.currentRoomId = 'overload_maze';
      game.creatures[0]
        ..position = const Offset(230, 545)
        ..lastSafe = const Offset(230, 545);
      game.joystickDirection = const Offset(0, 1);
      for (var i = 0; i < 240; i++) {
        game.update(1 / 60);
        if (game.currentRoomId != 'overload_maze') break;
        for (final cr in game.creatures) {
          if (cr.alive) cr.hp = cr.maxHp;
        }
      }
      return game.currentRoomId;
    }

    final game = _harness([
      _member(0, 'Lightning', 'horn'),
      _member(1, 'Air', 'wing'),
      _member(2, 'Fire', 'pip'),
    ]);
    final maze = game.layout.rooms['overload_maze']!;
    game.currentRoomId = 'overload_maze';
    game.mirrorOrient['A'] = 1;
    game.mirrorOrient['C'] = 1;
    game.mirrorOrient['D'] = 1;

    // Air stationed, but NOT Fire → the beam stays "air", tower dark.
    game.creatures[1].position = maze.beamEmitters[0].position;
    game.creatures[2].position = const Offset(900, 300); // Fire parked away
    for (var i = 0; i < 30; i++) {
      game.update(1 / 60);
    }
    expect(passGate(game), 'overload_maze',
        reason: 'no Fire on the converter → no lightning → tower stays dark');

    // Now station Fire too → conversion → tower lights → gate opens.
    game.creatures[1].position = maze.beamEmitters[0].position;
    game.creatures[2].position = maze.beamConverters[0];
    for (var i = 0; i < 30; i++) {
      game.update(1 / 60);
      game.creatures[1].position = maze.beamEmitters[0].position;
      game.creatures[2].position = maze.beamConverters[0];
    }
    expect(passGate(game), 'storm_core',
        reason: 'Air+Fire both stationed → the bolt crowns the tower');
  });

  test('only the right vent + converter combination lights the Storm Tower', () {
    // The solution uses vent 0 (VA) + converter 0 (FA). A decoy vent or a decoy
    // converter — even with the mirrors solved — must NOT light the tower.
    bool litWith(int ventIdx, int convIdx) {
      final game = _harness([
        _member(0, 'Lightning', 'horn'),
        _member(1, 'Air', 'wing'),
        _member(2, 'Fire', 'pip'),
      ]);
      final maze = game.layout.rooms['overload_maze']!;
      game.currentRoomId = 'overload_maze';
      game.mirrorOrient['A'] = 1;
      game.mirrorOrient['C'] = 1;
      game.mirrorOrient['D'] = 1; // the solution config
      for (var i = 0; i < 40; i++) {
        game.creatures[1].position = maze.beamEmitters[ventIdx].position;
        game.creatures[2].position = maze.beamConverters[convIdx];
        game.update(1 / 60);
      }
      // Did the gate open (tower lit)? Drive up-through it.
      game.creatures[0]
        ..position = const Offset(230, 545)
        ..lastSafe = const Offset(230, 545);
      game.joystickDirection = const Offset(0, 1);
      for (var i = 0; i < 240; i++) {
        game.update(1 / 60);
        if (game.currentRoomId != 'overload_maze') break;
        for (final c in game.creatures) {
          if (c.alive) c.hp = c.maxHp;
        }
      }
      return game.currentRoomId == 'storm_core';
    }

    expect(litWith(0, 0), isTrue, reason: 'VA + FA is the viable chain');
    expect(litWith(1, 0), isFalse, reason: 'decoy vent VB cannot be routed');
    expect(litWith(2, 0), isFalse, reason: 'decoy vent VC escapes the arena');
    expect(litWith(0, 1), isFalse, reason: 'converter FB is off the beam path');
    expect(litWith(0, 2), isFalse, reason: 'converter FC is past the last mirror');
  });

  test('the entry-rite bus stays lit after the charge would have decayed', () {
    final game = _harness([_member(0, 'Lightning', 'horn')]);
    final gate = game.layout.rooms['arc_gate']!;
    final src = gate.circuitNodes.firstWhere((n) => n.id == 'g_src').position;
    game.currentRoomId = 'arc_gate';
    game.creatures.single
      ..position = src
      ..lastSafe = src;
    game.activateAbility(); // charge the dead bus
    // Run well past the 8s charge window.
    for (var i = 0; i < 60 * 12; i++) {
      game.update(1 / 60);
    }
    expect(game.entryDoorRevealed, isTrue);
    expect(game.poweredNodes, contains('g_sink'),
        reason: 'the entry bus must stay lit, not bleed back to dark');
  });

  test('only a Lightning creature can wake the dead pylon', () {
    final game = _harness([_member(0, 'Air', 'wing')]); // wrong element
    final pylon = game.layout.rooms['pylon_hall']!;
    game.currentRoomId = 'pylon_hall';
    game.creatures.single
      ..position = pylon.beamEmitters.first.position
      ..lastSafe = pylon.beamEmitters.first.position;
    game.activateAbility();
    expect(game.pylonBeamOn, isFalse,
        reason: 'the dead pylon answers only to Lightning');
  });
}
