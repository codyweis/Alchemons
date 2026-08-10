// Full-run simulation of the Air dungeon: a headless party (the authored
// Air+Fire+Lightning trio) plays every star from a fresh save — entry
// ignition, the three-ring spire ascent, the complete Sky Loom (including the
// Anvil→Thundercloud charge), the twin-conduit sync, and the Roc guardian —
// proving the whole dungeon is completable end-to-end with the real verbs.

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

  test('the authored trio can earn all three Air stars end-to-end', () {
    final earned = <int>[];
    final discovered = <String>[];
    final party = [
      _member(0, 'Air', 'wing'),
      _member(1, 'Fire', 'mask'),
      _member(2, 'Lightning', 'horn'),
    ];
    final game = PlanetDungeonGame(
      element: 'Air',
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
      // The sim verifies puzzle flow, not survival — keep the party healthy
      // so consequence wisps can't derail the script.
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

    // ── Entry: Fire ignites the wind current → hidden passage reveals ──
    game.setActive(1); // Fire mask
    teleport('entry', room('entry').currents.first.rect.center);
    game.activateAbility();
    step();
    expect(game.entryDoorRevealed, isTrue, reason: 'Air+Fire reveals entry');
    expect(
      discovered,
      contains(PlanetDungeonGame.entryDoorDiscoveryId),
      reason: 'the reveal must persist like other discoveries',
    );

    // ── Star 1: ride all three rings in order, then stand on the crown ──
    game.setActive(0); // Air wing
    final ringRooms = <String, Offset>{
      for (final r in game.layout.rooms.values)
        for (final ring in r.rings) r.id: ring.position,
    };
    for (final entry in const [
      'lower_spire',
      'crosswind_hall',
      'cloud_platforms',
    ]) {
      teleport(entry, ringRooms[entry]!);
      game.flightActive = true;
      game.flightMeter = 5;
      step();
    }
    expect(game.summitOpen, isTrue, reason: 'three rings open the crown');
    game.flightActive = false;
    teleport('spire_summit', room('spire_summit').summit!.rect.center);
    step();
    expect(game.hasStar(0), isTrue, reason: 'Star 1 banks at the crown');

    // ── Star 2 prelude: EARN the five echoes through their trials ──
    // Spiral — ride the three gale eddies in order (Air).
    game.setActive(0);
    for (final eddy in game.spiralEddies(room('spiral_cloud'))) {
      teleport('spiral_cloud', eddy);
      step();
    }
    expect(
      game.discoveredClouds,
      contains('c_spiral'),
      reason: 'riding the eddies in order earns the Spiral echo',
    );

    // Ring — seal the orbit at the trio conjunction.
    teleport('ring_cloud', room('ring_cloud').bounds.center);
    var guard = 0;
    while (!game.ringMotesAligned && guard++ < 1400) {
      game.update(1 / 60);
    }
    expect(game.ringMotesAligned, isTrue, reason: 'the reagents must gather');
    game.activateAbility();
    expect(
      game.discoveredClouds,
      contains('c_ring'),
      reason: 'sealing the gathered orbit earns the Ring echo',
    );

    // Anvil — Fire braided through the wind cracks the shell (the
    // Air+Fire→Lightning recipe), then the storm-spark trio falls.
    game.setActive(1); // Fire
    teleport('anvil_cloud', room('anvil_cloud').currents.first.rect.center);
    game.activateAbility();
    expect(
      game.combatEnemies.length,
      3,
      reason: 'cracking the shell wakes the Air/Fire/Lightning spark trio',
    );
    for (final e in game.combatEnemies) {
      e.isDead = true;
    }
    step();
    expect(
      game.discoveredClouds,
      contains('c_anvil'),
      reason: 'clearing the wave hammers the Anvil awake',
    );

    // Feather — catch three falling plumes (Air draws them in).
    game.setActive(0);
    teleport('feather_cloud', room('feather_cloud').platforms.first.center);
    guard = 0;
    while (!game.discoveredClouds.contains('c_feather') && guard++ < 4000) {
      final feathers = game.fallingFeatherPositions;
      if (feathers.isNotEmpty) {
        game.creatures[game.activeIndex].position = feathers.first;
      }
      game.update(1 / 60);
      for (final c in game.creatures) {
        c.hp = c.maxHp;
      }
    }
    expect(
      game.discoveredClouds,
      contains('c_feather'),
      reason: 'three caught plumes earn the Feather echo',
    );

    // Veil — pin each breathing fold (Lightning pins from range).
    game.setActive(2); // Lightning
    teleport('veil_cloud', room('veil_cloud').bounds.center);
    guard = 0;
    while (!game.discoveredClouds.contains('c_veil') && guard++ < 4000) {
      final vis = game.veilVisibleSpotIndex;
      if (vis != null) {
        game.creatures[game.activeIndex].position = game.veilSpots(
          room('veil_cloud'),
        )[vis];
        game.activateAbility();
      }
      game.update(1 / 60);
      for (final c in game.creatures) {
        c.hp = c.maxHp;
      }
    }
    expect(
      game.discoveredClouds,
      contains('c_veil'),
      reason: 'three pinned folds earn the Veil echo',
    );

    expect(
      game.discoveredClouds.where((id) => !id.startsWith('rune:')).length,
      5,
      reason: 'all five wonder-clouds earned through their trials',
    );

    final loom = room('sky_loom');
    Offset loomCloud(String type) =>
        loom.clouds.firstWhere((c) => c.cloudType == type).position;
    Offset loomAnchor(String type) =>
        loom.anchors.firstWhere((a) => a.requiredCloudType == type).position;

    for (final type in const ['Spiral', 'Ring', 'Feather', 'Veil']) {
      teleport('sky_loom', loomCloud(type));
      step();
      expect(game.carriedCloudType, type);
      teleport('sky_loom', loomAnchor(type));
      step();
      expect(game.carriedCloudType, isNull, reason: '$type slots cleanly');
    }

    // The Anvil needs Fire inside the weaving stream to become a Thundercloud.
    teleport('sky_loom', loomCloud('Anvil'));
    step();
    expect(game.carriedCloudType, 'Anvil');
    game.setActive(1); // swap to the Fire mask (the carry is party-wide)
    teleport('sky_loom', loom.currents.first.rect.center);
    game.activateAbility();
    expect(game.carriedCloudType, 'Thundercloud', reason: 'Air+Fire charges');
    teleport('sky_loom', loomAnchor('Thundercloud'));
    step();
    expect(game.hasStar(1), isTrue, reason: 'Star 2 banks on the fifth anchor');

    // ── Star 3: channel A (Lightning Horn), arc B (Fire in the current) ──
    final conduitRoom = room('twin_conduit');
    game.setActive(2); // Lightning horn
    teleport(
      'twin_conduit',
      conduitRoom.conduits.firstWhere((c) => c.id == 'A').position,
    );
    game.activateAbility();
    expect(game.conduitEnergy['A'], greaterThan(0), reason: 'perfect channel');

    game.setActive(1); // Fire mask
    game.creatures[1].position = conduitRoom.currents.first.rect.center;
    game.activateAbility();
    expect(game.conduitEnergy['B'], greaterThan(0), reason: 'recipe arc');
    step();
    expect(game.altarOpen, isTrue, reason: 'both conduits live → altar opens');
    expect(game.guardianAwake, isTrue);

    // Clear the consequence wisps; the scripted fight is about the Roc.
    for (final e in game.combatEnemies) {
      e.isDead = true;
    }

    // ── The Roc: paced lull strikes until it falls ──
    final guardianNode = room('guardian_summit').guardian!;
    teleport('guardian_summit', guardianNode.position + const Offset(0, 80));
    var safety = 0;
    while (!game.hasStar(2) && safety++ < 600) {
      final roc = game.combatEnemies.where((e) => e.isElite).firstOrNull;
      if (roc != null && !roc.isDead) {
        // Keep the hovering Roc within melee reach for the scripted strikes.
        roc.position = game.creatures[game.activeIndex].position;
      }
      if (game.guardianVulnerable) game.activateAbility();
      step(0.3);
    }
    expect(game.hasStar(2), isTrue, reason: 'lull strikes fell the guardian');

    expect(earned, [0, 1, 2], reason: 'stars bank in play order, once each');
    expect(game.starsEarnedCount, 3);

    // ── The Lost Maxim: commune at the compass heart (easter egg) ──
    teleport('hub', room('hub').bounds.center);
    game.activateAbility();
    expect(
      discovered,
      contains(kAirFirstWindEggId),
      reason: 'the 3-star commune yields the maxim (screen pays 20 gold)',
    );
  });
}
