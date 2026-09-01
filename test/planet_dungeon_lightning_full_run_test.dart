// Focused per-mechanic tests of the Lightning dungeon (Voltara — the Storm
// Circuit, ZERO-SUM DYNAMO rework §6.3/§9.1): a headless Lightning+Air+Fire
// trio plays the INTENDED solutions from a fresh save, and each rework
// mechanic gets its own guard:
//   • zero-sum trunk exclusivity (feeding one wing darkens the others),
//   • dark dead segments stay walkable, with capped spark-wisp prowl,
//   • the vault only opens UNPOWERED (cut the trunk you stand in),
//   • S1 fulminate vats: a bolt over a vat trips the dynamo dark,
//   • S3 stationing incl. the geometrically-impossible decoy pair,
//   • Raikuma FEEDS on the powered core trunk (grounding forces the lull),
//   • the Thunderbolt egg, the vault cache, and the guardian relic.
// (S1 uniqueness itself is brute-forced in planet_dungeon_layout_test.dart.)

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

/// The authored trunk-breaker position at the dynamo court.
Offset _breaker(PlanetDungeonGame game, String trunkId) =>
    game.layout.dynamoTrunks.firstWhere((t) => t.id == trunkId).breakerPosition;

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

    void throwTrunk(String trunkId) {
      game.setActive(0); // Lightning throws the breakers
      teleport('dynamo_court', _breaker(game, trunkId));
      game.activateAbility();
      expect(
        game.activeTrunk,
        trunkId,
        reason: 'the dynamo swings to $trunkId',
      );
      step(1.5); // let darkness/bolt/breaker eases settle
      clearWisps();
    }

    // ── Entry: any Lightning charges the dead bus ──
    game.setActive(0); // Lightning horn
    teleport('arc_gate', _node(room('arc_gate'), 'g_src'));
    game.activateAbility();
    step();
    expect(game.entryDoorRevealed, isTrue, reason: 'power lights the passage');
    expect(discovered, contains(PlanetDungeonGame.entryDoorDiscoveryId));

    // The dynamo idles into the VAULT trunk — every star wing starts dark.
    expect(game.activeTrunk, 'trunk_vault');
    expect(game.circuitRoomLit('pylon_hall'), isFalse);
    expect(game.circuitRoomLit('cloud_works'), isFalse);

    // ── The breaker gate is dead until both stars bank ──
    final hub = room('dynamo_court');
    final breakerDoor = hub.doors.firstWhere(
      (d) => d.targetRoomId == 'overload_maze',
    );
    expect(game.isDoorLocked(hub, breakerDoor), isTrue);

    // ── Star 1: feed the pylon trunk, then thread the bolt ──
    throwTrunk('trunk_pylon');
    expect(game.circuitRoomLit('pylon_hall'), isTrue);
    final pylon = room('pylon_hall');
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

    // The solver-proven unique solution: pa='\', pd='\', pb=pc='/'.
    // pd first so no intermediate config ever cooks a vat.
    s1flip('pd', 1);
    s1flip('pa', 1);
    step();
    expect(
      game.hasStar(0),
      isTrue,
      reason: 'one bolt across all three terminals → Circuit Star',
    );
    expect(
      game.activeTrunk,
      'trunk_pylon',
      reason: 'a clean threading never trips the dynamo',
    );

    // ── The vault: cut, then walk the dead segment ──
    // The pylon trunk is fed, so the vault trunk is DEAD and its bolt has
    // fallen open — the treasury answers only to darkness.
    expect(game.circuitRoomLit('capacitor_vault'), isFalse);
    step(1.5); // the bolt finishes sliding aside
    teleport('capacitor_vault', room('capacitor_vault').vaultCache!);
    step();
    expect(
      discovered,
      contains('cache:lightning_vault'),
      reason: 'the vault cache pays out (screen grants the 5 gold)',
    );
    clearWisps();

    // ── Star 2: bare the storm-cells, herd + heat them, then feed the works ──
    final gallery = room('mirror_gallery');
    game.setActive(1); // Air wing
    for (final cell in gallery.stormCells) {
      teleport('mirror_gallery', cell.position);
      step();
      expect(
        game.discoveredClouds,
        contains(cell.id),
        reason: 'close approach bares the storm-cell echo',
      );
    }
    clearWisps();

    final works = room('cloud_works');
    final slotX = works.bounds.left + 110;
    void herd(String cellId, double slotY, String sockId) {
      game.setActive(1); // Air wing herds
      teleport('cloud_works', Offset(slotX, works.bounds.top + slotY));
      game.activateAbility();
      expect(game.carriedCloudId, cellId, reason: 'the echo is gathered');
      final sock = works.cellSockets.firstWhere((s) => s.id == sockId);
      teleport('cloud_works', sock.position);
      game.activateAbility();
    }

    // The whole wing is DARK (the pylon trunk still holds the dynamo) — the
    // sockets can be staged in the dark, but the works cannot sing.
    expect(game.circuitRoomLit('cloud_works'), isFalse);
    herd('cell_spark', 180, 'sock_a');
    expect(game.energizedSockets, contains('sock_a'));
    herd('cell_veil', 350, 'sock_b');
    expect(game.energizedSockets, contains('sock_b'));
    // Anvil cell: deposit cold, then a Fire creature heats it.
    herd('cell_anvil', 520, 'sock_anvil');
    expect(
      game.energizedSockets.contains('sock_anvil'),
      isFalse,
      reason: 'the anvil cell is cold until heated',
    );
    game.setActive(2); // Fire pip
    final anvil = works.cellSockets.firstWhere((s) => s.id == 'sock_anvil');
    teleport('cloud_works', anvil.position);
    game.activateAbility();
    step();
    expect(
      game.energizedSockets,
      contains('sock_anvil'),
      reason: 'Air+Fire→Lightning wakes the Thundercloud',
    );
    expect(
      game.hasStar(1),
      isFalse,
      reason: 'ZERO-SUM: a staged wing cannot sing while its trunk is dark',
    );
    clearWisps();

    // Feed the cloud trunk → the works light and the star banks.
    throwTrunk('trunk_cloud');
    game.setActive(2);
    teleport('cloud_works', works.bounds.center);
    step(0.5);
    expect(
      game.hasStar(1),
      isTrue,
      reason: 'sockets staged + trunk fed → Storm Star',
    );
    clearWisps();

    // Both stars banked → the breaker gate throws open.
    expect(game.guardianRiteUnlocked, isTrue);
    expect(
      game.isDoorLocked(hub, breakerDoor),
      isFalse,
      reason: 'Circuit and Storm open the breaker gate',
    );

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
    // THE RITE OF THREE. The find no longer pays out on the frame it fires:
    // the trio's elements are drawn out, bound over the tower, and the
    // BINDING hands over the gold. So the reaction has to run.
    expect(
      game.riteActive,
      isTrue,
      reason: 'Air+Fire born a bolt and a Horn crowned the tower = Thunderbolt',
    );
    expect(
      discovered,
      isNot(contains(kLightningThunderboltEggId)),
      reason: 'and it is NOT paid yet — the reaction pays it',
    );
    step(3.0);
    expect(
      discovered,
      contains(kLightningThunderboltEggId),
      reason: 'the binding takes, and the gold falls out of it',
    );
    clearWisps();

    // ── Star 3: Raikuma FEEDS on the powered trunk — ground it, then strike ──
    final core = room('storm_core');
    final guardianNode = core.guardian!;
    game.setActive(0); // Lightning grounds the spike
    teleport('storm_core', guardianNode.position + const Offset(0, 80));
    // The beam latch WOKE it back in the maze (the sealed hatch parts only
    // for a roused guardian); walking in plays the arrival, and it seizes the
    // grid when it lands.
    expect(game.guardianAwake, isTrue, reason: 'the latched beam woke Raikuma');
    step(2.2); // kGuardianArrivalSeconds + a beat
    expect(
      game.activeTrunk,
      'trunk_core',
      reason: 'Raikuma seizes the dynamo as it lands',
    );
    expect(game.raikumaFed, isTrue);

    var safety = 0;
    while (!game.hasStar(2) && safety++ < 900) {
      final raikuma = game.combatEnemies.where((e) => e.isElite).firstOrNull;
      if (game.raikumaFed) {
        // Ground the trunk at the spike (the body parked clear so the
        // guardian's own catch cannot swallow the act).
        if (raikuma != null && !raikuma.isDead) {
          raikuma.position = const Offset(650, 200);
        }
        teleport('storm_core', core.coreBreaker!);
        game.activateAbility();
        expect(
          game.activeTrunk,
          isNull,
          reason: 'the spike grounds the core trunk',
        );
        teleport('storm_core', const Offset(480, 350));
        step(0.15);
      } else {
        if (raikuma != null && !raikuma.isDead) {
          raikuma.position = game.creatures[game.activeIndex].position;
        }
        if (game.guardianVulnerable) game.activateAbility();
        step(0.3);
      }
    }
    expect(
      game.hasStar(2),
      isTrue,
      reason: 'grounded-trunk lull strikes fell Raikuma',
    );
    expect(game.relicDropActive, isTrue);

    expect(earned, [0, 1, 2], reason: 'stars bank in play order, once each');
    expect(game.starsEarnedCount, 3);
  });

  test('zero-sum: the dynamo feeds ONE trunk and throwing another darkens '
      'the rest', () {
    final game = _harness([_member(0, 'Lightning', 'horn')]);
    // The run begins with the treasury hoarding the storm.
    expect(game.activeTrunk, 'trunk_vault');
    expect(game.circuitRoomLit('capacitor_vault'), isTrue);
    expect(game.circuitRoomLit('pylon_hall'), isFalse);
    expect(game.circuitRoomLit('cloud_works'), isFalse);
    expect(game.circuitRoomLit('mirror_gallery'), isFalse);
    expect(game.circuitRoomLit('overload_maze'), isFalse);
    // The spine (hub + gate) is never on a trunk — always lit.
    expect(game.circuitRoomLit('dynamo_court'), isTrue);
    expect(game.circuitRoomLit('arc_gate'), isTrue);

    void throwAt(String trunkId) {
      game.currentRoomId = 'dynamo_court';
      game.creatures.single
        ..position = _breaker(game, trunkId)
        ..lastSafe = _breaker(game, trunkId);
      game.activateAbility();
    }

    // Feed the pylon wing → the vault (and everything else) goes dark.
    throwAt('trunk_pylon');
    expect(game.activeTrunk, 'trunk_pylon');
    expect(game.circuitRoomLit('pylon_hall'), isTrue);
    expect(game.circuitRoomLit('capacitor_vault'), isFalse);
    expect(game.circuitRoomLit('cloud_works'), isFalse);

    // Feed the cloud wing → BOTH its rooms light; the pylon dies.
    throwAt('trunk_cloud');
    expect(game.activeTrunk, 'trunk_cloud');
    expect(game.circuitRoomLit('cloud_works'), isTrue);
    expect(game.circuitRoomLit('mirror_gallery'), isTrue);
    expect(game.circuitRoomLit('pylon_hall'), isFalse);

    // Throwing the LIVE breaker grounds the dynamo entirely.
    throwAt('trunk_cloud');
    expect(game.activeTrunk, isNull);
    expect(game.circuitRoomLit('cloud_works'), isFalse);

    // A banked wing freezes LIT whatever the dynamo feeds (solved is solved).
    game.starMask = 1; // Circuit Star banked
    expect(game.circuitRoomLit('pylon_hall'), isTrue);
  });

  test('the trunk breakers are element-only: every Lightning family throws '
      'them; other elements are refused', () {
    for (final family in const ['pip', 'mane', 'horn', 'mask', 'wing', 'kin']) {
      final game = _harness([_member(0, 'Lightning', family)]);
      game.currentRoomId = 'dynamo_court';
      game.creatures.single
        ..position = _breaker(game, 'trunk_pylon')
        ..lastSafe = _breaker(game, 'trunk_pylon');
      game.activateAbility();
      expect(
        game.activeTrunk,
        'trunk_pylon',
        reason: 'a Lightning $family must throw the breaker',
      );
      expect(
        game.combatEnemies.where((e) => !e.isDead),
        isEmpty,
        reason: 'a Lightning $family throws it SILENTLY — no spark tax',
      );
    }

    final wrong = _harness([_member(0, 'Water', 'horn')]);
    wrong.currentRoomId = 'dynamo_court';
    wrong.creatures.single
      ..position = _breaker(wrong, 'trunk_pylon')
      ..lastSafe = _breaker(wrong, 'trunk_pylon');
    wrong.activateAbility();
    expect(
      wrong.activeTrunk,
      'trunk_vault',
      reason: 'the breaker answers only Lightning — the dynamo never moves',
    );
  });

  test('dark dead segments stay walkable, with a capped spark-wisp prowl', () {
    final game = _harness([_member(0, 'Lightning', 'horn')]);
    // The pylon wing starts dark (the vault trunk holds the dynamo).
    expect(game.circuitRoomLit('pylon_hall'), isFalse);
    game.currentRoomId = 'pylon_hall';
    final c = game.creatures.single
      ..position = const Offset(300, 350)
      ..lastSafe = const Offset(300, 350);

    // Walkable: plain movement works in the dark at full speed.
    game.joystickDirection = const Offset(1, 0);
    for (var i = 0; i < 60; i++) {
      game.update(1 / 60);
      c.hp = c.maxHp;
    }
    expect(
      c.position.dx,
      greaterThan(360),
      reason: 'a dead segment is dark, not a wall',
    );
    game.joystickDirection = Offset.zero;

    // The prowl: wisps appear on a slow clock, capped at a modest number.
    for (var i = 0; i < 60 * 3; i++) {
      game.update(1 / 60);
      c.hp = c.maxHp;
    }
    var live = game.combatEnemies.where((e) => !e.isDead).length;
    expect(live, greaterThan(0), reason: 'spark wisps prowl the dead wires');
    expect(live, lessThanOrEqualTo(2), reason: 'atmosphere, never a flood');
    for (var i = 0; i < 60 * 16; i++) {
      game.update(1 / 60);
      c.hp = c.maxHp;
    }
    live = game.combatEnemies.where((e) => !e.isDead).length;
    expect(
      live,
      lessThanOrEqualTo(2),
      reason: 'the prowl tops up to the cap and no further',
    );

    // Relight the wing → the prowl stops (the survivors remain, no top-ups).
    game.activeTrunk = 'trunk_pylon';
    for (final e in game.combatEnemies) {
      e.isDead = true;
    }
    for (var i = 0; i < 60 * 16; i++) {
      game.update(1 / 60);
      c.hp = c.maxHp;
    }
    expect(
      game.combatEnemies.where((e) => !e.isDead),
      isEmpty,
      reason: 'a lit wing spawns no prowl',
    );
  });

  test('the vault only opens UNPOWERED: the bolt bars a fed trunk and falls '
      'open in the dark', () {
    final discovered = <String>[];
    final game = _harness([
      _member(0, 'Lightning', 'horn'),
    ], onCloud: discovered.add);
    final vault = game.layout.rooms['capacitor_vault']!;
    final bolt = vault.vaultBolt!;

    String driveUp() {
      game.currentRoomId = 'capacitor_vault';
      game.creatures.single
        ..position = const Offset(320, 470)
        ..lastSafe = const Offset(320, 470);
      game.joystickDirection = const Offset(0, -1);
      for (var i = 0; i < 300; i++) {
        game.update(1 / 60);
        game.creatures.single.hp = game.creatures.single.maxHp;
      }
      game.joystickDirection = Offset.zero;
      return discovered.contains('cache:lightning_vault')
          ? 'claimed'
          : 'blocked';
    }

    // The vault trunk is fed at run start: the bolt is DOWN.
    expect(game.activeTrunk, 'trunk_vault');
    expect(
      driveUp(),
      'blocked',
      reason: 'a powered trunk keeps the treasury sealed',
    );
    expect(
      game.creatures.single.position.dy,
      greaterThan(bolt.bottom),
      reason: 'the bolt is solid — the sanctum mouth cannot be crossed',
    );

    // Cut the very trunk you stand in (route the dynamo elsewhere)…
    game.currentRoomId = 'dynamo_court';
    game.creatures.single
      ..position = _breaker(game, 'trunk_pylon')
      ..lastSafe = _breaker(game, 'trunk_pylon');
    game.activateAbility();
    expect(game.activeTrunk, 'trunk_pylon');
    // …give the bolt its eased slide…
    for (var i = 0; i < 120; i++) {
      game.update(1 / 60);
      game.creatures.single.hp = game.creatures.single.maxHp;
    }
    expect(
      game.vaultBoltOpenness,
      greaterThan(0.9),
      reason: 'the bolt slides aside (eased, never a snap)',
    );
    // …and walk the dead segment in the dark to the cache.
    expect(game.circuitRoomLit('capacitor_vault'), isFalse);
    expect(
      driveUp(),
      'claimed',
      reason: 'the dark trunk is the only way into the treasury',
    );
  });

  test('S1: a bolt lying on a fulminate vat trips the dynamo dark — even '
      'when it also strings every terminal', () {
    final game = _harness([_member(0, 'Lightning', 'horn')]);
    game.activeTrunk = 'trunk_pylon'; // the hall is fed
    game.currentRoomId = 'pylon_hall';
    game.creatures.single
      ..position = const Offset(200, 350)
      ..lastSafe = const Offset(200, 350);
    // The NEAR-solution: pa='\' pd='\' pc='/' pb='\' — the bolt lies on all
    // three terminals, then runs back along the top and cooks vat A. Without
    // the vat this would be a second solution; with it, it detonates.
    game.mirrorOrient['pa'] = 1;
    game.mirrorOrient['pd'] = 1;
    game.mirrorOrient['pc'] = 0;
    game.mirrorOrient['pb'] = 1;
    for (var i = 0; i < 60 * 2; i++) {
      game.update(1 / 60);
      game.creatures.single.hp = game.creatures.single.maxHp;
    }
    expect(
      game.hasStar(0),
      isFalse,
      reason: 'a vat-crossing bolt can NEVER bank the star',
    );
    expect(
      game.activeTrunk,
      isNull,
      reason: 'the cooked vat detonates and the dynamo trips dark',
    );
    expect(
      game.combatEnemies.where((e) => !e.isDead),
      isNotEmpty,
      reason: 'the detonation spits spark wisps',
    );
    expect(
      game.circuitRoomLit('pylon_hall'),
      isFalse,
      reason: 'the hall goes dark with the trip',
    );
  });

  test('the ring circuit is element-only: every Lightning family charges a '
      'node to the same window', () {
    final windows = <String, double>{};
    for (final family in const ['pip', 'mane', 'horn', 'mask', 'wing', 'kin']) {
      final game = _harness([_member(0, 'Lightning', family)]);
      final room = game.layout.rooms.values.firstWhere(
        (r) => r.circuitNodes.any(
          (n) => n.kind == CircuitNodeKind.source && !n.latching,
        ),
      );
      final node = room.circuitNodes.firstWhere(
        (n) => n.kind == CircuitNodeKind.source && !n.latching,
      );
      game.currentRoomId = room.id;
      game.creatures.single
        ..position = node.position
        ..lastSafe = node.position;
      game.activateAbility();
      windows[family] = game.circuitCharge[node.id] ?? 0;
      expect(
        windows[family],
        greaterThan(0.0),
        reason: 'a Lightning $family must charge the node',
      );
      expect(
        game.combatEnemies.where((e) => !e.isDead),
        isEmpty,
        reason: 'a Lightning $family charges it SILENTLY',
      );
    }
    expect(
      windows.values.toSet().length,
      1,
      reason: 'no family holds the charge longer than another: $windows',
    );
  });

  test('only Lightning turns the S1 conductors', () {
    final game = _harness([_member(0, 'Air', 'wing')]); // wrong element
    final pylon = game.layout.rooms['pylon_hall']!;
    final mirror = pylon.beamMirrors.first;
    game.currentRoomId = 'pylon_hall';
    game.creatures.single
      ..position = mirror.position
      ..lastSafe = mirror.position;
    game.activateAbility();
    expect(
      game.mirrorOrient[mirror.id] ?? 0,
      0,
      reason: 'the conductor is dead iron to everything but Lightning',
    );
  });

  test('Raikuma FEEDS on the powered trunk: no lull while it drinks; '
      'grounding the spike forces the window; it seizes the trunk back', () {
    final game = _harness([
      _member(0, 'Lightning', 'horn'),
      _member(1, 'Air', 'wing'),
      _member(2, 'Fire', 'pip'),
    ]);
    final core = game.layout.rooms['storm_core']!;
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

    // Wake it: Raikuma seizes the dynamo for its own trunk.
    game.setActive(0);
    game.currentRoomId = 'storm_core';
    game.creatures[0]
      ..position = core.guardian!.position + const Offset(0, 80)
      ..lastSafe = core.guardian!.position + const Offset(0, 80);
    step();
    expect(game.guardianAwake, isTrue);
    expect(
      game.activeTrunk,
      'trunk_core',
      reason: 'the guardian seizes the dynamo as it wakes',
    );
    expect(game.raikumaFed, isTrue);

    // While it feeds there is NO lull — ever.
    var sawLull = false;
    for (var i = 0; i < 60 * 8; i++) {
      game.update(1 / 60);
      if (game.guardianVulnerable) sawLull = true;
      for (final c in game.creatures) {
        c.hp = c.maxHp;
      }
    }
    expect(
      sawLull,
      isFalse,
      reason: 'a fed Raikuma never offers the vulnerability window',
    );

    // Ground the trunk at the spike (Lightning only) → the window opens.
    final raikuma = game.combatEnemies.where((e) => e.isElite).firstOrNull;
    raikuma?.position = const Offset(650, 200); // parked clear of the spike
    game.creatures[0]
      ..position = core.coreBreaker!
      ..lastSafe = core.coreBreaker!;
    game.activateAbility();
    expect(game.activeTrunk, isNull, reason: 'the spike grounds the trunk');
    step(0.2);
    expect(game.raikumaFed, isFalse);
    expect(
      game.guardianVulnerable,
      isTrue,
      reason: 'cutting its power forces the lull',
    );

    // The window closes → Raikuma seizes the trunk back and feeds again.
    step(4.0);
    expect(
      game.raikumaFed,
      isTrue,
      reason: 'the guardian re-seizes the dynamo when the window shuts',
    );
    expect(game.activeTrunk, 'trunk_core');
    expect(game.guardianVulnerable, isFalse);

    // The wrong element is refused at the spike outright.
    raikuma?.position = const Offset(650, 200);
    game.setActive(1); // Air
    game.creatures[1]
      ..position = core.coreBreaker!
      ..lastSafe = core.coreBreaker!;
    game.activateAbility();
    expect(
      game.activeTrunk,
      'trunk_core',
      reason: 'the grounding spike answers only Lightning',
    );
  });

  test('the storm-core gate opens with the star and never re-locks', () {
    // Drive the active creature DOWN toward the core gate (y≈648) below the
    // tower; report whether it gets blocked or passes through to the core.
    String crawl(PlanetDungeonGame game) {
      game.currentRoomId = 'overload_maze';
      game.creatures.single
        ..position =
            const Offset(230, 545) // above the gate, below the tower
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
    expect(crawl(blocked), 'overload_maze', reason: 'the unlit gate is shut');

    // Overload Star banked: the gate stays open, so you pass to the core.
    final solved = _harness([_member(0, 'Lightning', 'horn')]);
    solved.starMask = 1 << 2;
    expect(
      crawl(solved),
      'storm_core',
      reason: 'a banked Overload Star keeps the gate open',
    );
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
      game.joystickDirection = to.distance < 1
          ? Offset.zero
          : Offset(to.dx, to.dy) / to.distance;
      game.update(1 / 60);
      c.hp = c.maxHp;
    }
    expect(
      game.currentRoomId,
      'storm_core',
      reason: 'the arena must reach the core door',
    );
  });

  test(
    'the Storm Tower needs BOTH Air on the vent and Fire on the converter',
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
      expect(
        passGate(game),
        'overload_maze',
        reason: 'no Fire on the converter → no lightning → tower stays dark',
      );

      // Now station Fire too → conversion → tower lights → gate opens.
      game.creatures[1].position = maze.beamEmitters[0].position;
      game.creatures[2].position = maze.beamConverters[0];
      for (var i = 0; i < 30; i++) {
        game.update(1 / 60);
        game.creatures[1].position = maze.beamEmitters[0].position;
        game.creatures[2].position = maze.beamConverters[0];
      }
      expect(
        passGate(game),
        'storm_core',
        reason: 'Air+Fire both stationed → the bolt crowns the tower',
      );
    },
  );

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
    expect(
      litWith(0, 2),
      isFalse,
      reason: 'converter FC is past the last mirror',
    );
    expect(
      litWith(3, 3),
      isFalse,
      reason:
          'the dead-aligned decoy pair VD+FD is a geometric lie — '
          'no conductor waits beyond FD',
    );
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
    expect(
      game.poweredNodes,
      contains('g_sink'),
      reason: 'the entry bus must stay lit, not bleed back to dark',
    );
  });
}
