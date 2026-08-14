// Regression tests for the planet-dungeon combat layer: floaty hover/dive
// enemy steering, idle-companion auto-attacks, and downed-creature handling.
//
// The game is exercised headless: onLoad (sprites/shaders) is skipped and the
// party is wired up manually, mirroring what onLoad does minus asset loading.

import 'dart:math' show cos, max, pi, sqrt;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_companion_stats.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart'
    show CosmicSurvivalCompanion;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _member({
  required int slot,
  String element = 'Air',
  String family = 'wing',
}) {
  return CosmicPartyMember(
    instanceId: 'inst_$slot',
    baseId: 'base_$slot',
    displayName: 'Test $slot',
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

CosmicSurvivalCompanion _companion(CosmicPartyMember member, Offset position) {
  final stats = deriveCosmicSurvivalCompanionStats(member: member);
  return CosmicSurvivalCompanion(
    member: member,
    slotIndex: member.slotIndex,
    position: position,
    anchor: position,
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
  );
}

PlanetDungeonGame _buildGame({int partySize = 2}) {
  final party = [for (var i = 0; i < partySize; i++) _member(slot: i)];
  final game = PlanetDungeonGame(
    element: 'Air',
    party: party,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  // Headless wiring (what onLoad does, minus sprite/shader assets).
  game.currentRoomId = game.layout.entranceRoomId;
  final spawn = game.layout.entranceSpawn;
  for (var i = 0; i < party.length; i++) {
    final c = DungeonCreature(member: party[i])
      ..position = spawn + Offset(i * 60.0, 0)
      ..lastSafe = spawn + Offset(i * 60.0, 0);
    game.creatures.add(c);
    game.combatCompanions.add(_companion(party[i], c.position));
  }
  return game;
}

void _step(PlanetDungeonGame game, double seconds, {double dt = 1 / 60}) {
  var t = 0.0;
  while (t < seconds) {
    game.update(dt);
    t += dt;
  }
}

/// Make spawned wisps effectively unkillable so steering tests can sample
/// motion without the (working) companion auto-attacks deleting the subjects.
void _toughen(PlanetDungeonGame game) {
  for (final e in game.combatEnemies) {
    e.hp = 1e9;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('enemy steering', () {
    test('wisps hover around the target instead of grinding on contact', () {
      final game = _buildGame();
      final player = game.creatures.first;
      game.spawnWispWave(element: 'Air', center: player.position, count: 3);
      _toughen(game);

      // Let the steering settle, then sample distances over a few seconds.
      _step(game, 2.0);
      var samples = 0;
      var touching = 0;
      for (var i = 0; i < 240; i++) {
        game.update(1 / 60);
        for (final e in game.combatEnemies) {
          samples++;
          final d = (e.position - player.position).distance;
          if (d < e.radius + 18) touching++;
        }
      }
      expect(samples, greaterThan(0));
      // Hovering enemies spend the bulk of their time OFF the player; the old
      // chase AI sat at contact range ~100% of the time.
      expect(
        touching / samples,
        lessThan(0.35),
        reason: 'enemies should hover/dive, not grind on contact',
      );
    });

    test('enemies separate instead of stacking into one blob', () {
      final game = _buildGame();
      final player = game.creatures.first;
      game.spawnWispWave(element: 'Air', center: player.position, count: 5);
      _toughen(game);
      _step(game, 4.0);
      final live = game.combatEnemies.where((e) => !e.isDead).toList();
      expect(live.length, greaterThanOrEqualTo(2));
      var minPair = double.infinity;
      for (var i = 0; i < live.length; i++) {
        for (var j = i + 1; j < live.length; j++) {
          final d = (live[i].position - live[j].position).distance;
          if (d < minPair) minPair = d;
        }
      }
      expect(minPair, greaterThan(8), reason: 'no two enemies fully stacked');
    });

    test(
      'enemies target the nearest living creature, not just the active one',
      () {
        final game = _buildGame();
        // Park the idle creature far from the active one and spawn next to it.
        final idle = game.creatures[1];
        idle.position = const Offset(700, 600);
        game.combatCompanions[1].position = idle.position;
        game.spawnWispWave(element: 'Air', center: idle.position, count: 2);
        _toughen(game);
        final idleHpBefore = game.combatCompanions[1].currentHp;
        _step(game, 10.0);
        final active = game.creatures[0];
        for (final e in game.combatEnemies) {
          final dIdle = (e.position - idle.position).distance;
          final dActive = (e.position - active.position).distance;
          expect(dIdle, lessThan(dActive));
        }
        // And they actually fight that creature (dive impacts landed), with
        // damage that registers on the HP bar — not survival-scale chip damage
        // that rounds to nothing against dungeon pools.
        expect(
          game.combatCompanions[1].currentHp,
          lessThan((idleHpBefore * 0.92).round()),
          reason: 'sustained wisp dives must deal meaningful damage',
        );
      },
    );
  });

  group('idle companions', () {
    test('auto-fire basics when enemies are in range', () {
      final game = _buildGame();
      final idle = game.creatures[1];
      game.spawnWispWave(element: 'Air', center: idle.position, count: 2);
      _step(game, 3.0);
      final idleShots = game.combatProjectiles.where(
        (p) => p.sourceSlotIndex == game.combatCompanions[1].slotIndex,
      );
      final firedOrHit =
          idleShots.isNotEmpty ||
          game.combatEnemies.any((e) => e.hp < e.maxHp) ||
          game.combatEnemies.isEmpty;
      expect(
        firedOrHit,
        isTrue,
        reason: 'idle companion should have attacked nearby wisps',
      );
    });

    test('do not fire with no enemies present', () {
      final game = _buildGame();
      _step(game, 2.0);
      expect(game.combatProjectiles, isEmpty);
    });
  });

  group('downs', () {
    test('a downed teammate does not reset the run; control auto-swaps', () {
      var downs = 0;
      final game = PlanetDungeonGame(
        element: 'Air',
        party: [_member(slot: 0), _member(slot: 1)],
        initialStarMask: 0,
        onStarEarned: (_) {},
        onPlayerDown: () => downs++,
        onChanged: () {},
      );
      game.currentRoomId = game.layout.entranceRoomId;
      final spawn = game.layout.entranceSpawn;
      for (var i = 0; i < 2; i++) {
        final m = _member(slot: i);
        final c = DungeonCreature(member: m)
          ..position = spawn + Offset(i * 50.0, 0)
          ..lastSafe = spawn + Offset(i * 50.0, 0);
        game.creatures.add(c);
        game.combatCompanions.add(_companion(m, c.position));
      }

      // Down the ACTIVE creature only.
      game.creatures[0].hp = 0;
      game.combatCompanions[0].currentHp = 0;
      game.update(1 / 60);

      expect(downs, 0, reason: 'one down with a living teammate is not a wipe');
      expect(game.activeIndex, 1, reason: 'control swaps to teammate');
      expect(game.creatures[0].alive, isFalse);

      // Down the last creature → full wipe → reset fires and party revives.
      game.creatures[1].hp = 0;
      game.combatCompanions[1].currentHp = 0;
      game.update(1 / 60);
      expect(downs, 1, reason: 'party wipe resets the run');
      expect(game.creatures.every((c) => c.alive), isTrue);
    });

    test('setActive refuses a downed creature', () {
      final game = _buildGame();
      game.creatures[1].hp = 0;
      game.setActive(1);
      expect(game.activeIndex, 0);
    });
  });

  group('pursuit through doors', () {
    test('living wisps are re-placed near the arrival point on room change', () {
      final game = _buildGame();
      final player = game.creatures.first;
      game.spawnWispWave(element: 'Air', center: player.position, count: 3);
      _step(game, 1.0);

      // Walk the active creature into the first door.
      final door = game.currentRoom.doors.first;
      // The entry→hub door may be hidden until revealed; force the flag so the
      // transition is exercised either way.
      game.entryDoorRevealed = true;
      player.position = door.rect.center;
      for (final c in game.creatures) {
        c.hp = c.maxHp;
      }
      _step(game, 0.6);

      expect(game.currentRoomId, isNot('entry'));
      final spawnRoom = game.currentRoom;
      for (final e in game.combatEnemies) {
        expect(
          spawnRoom.bounds.inflate(1).contains(e.position),
          isTrue,
          reason: 'pursuing wisps must be inside the new room',
        );
      }
    });
  });

  group('wind spire — waking the winds', () {
    void wake(PlanetDungeonGame game, String roomId, String shrineId) {
      game.currentRoomId = roomId;
      final shrine = game.currentRoom.gustShrines.firstWhere(
        (s) => s.id == shrineId,
      );
      final walker = game.creatures[game.activeIndex]
        ..position = shrine.position
        ..lastSafe = shrine.position;
      expect(walker.position, shrine.position);
      game.activateAbility();
      _step(game, 0.1);
    }

    test('the crown opens only once EVERY wind blows', () {
      final game = _buildGame();
      expect(game.wokenGales, isEmpty, reason: 'the spire is born calm');

      wake(game, 'lower_spire', 'shrine_ridge');
      expect(game.summitOpen, isFalse, reason: 'one wind of four is not four');
      wake(game, 'lower_spire', 'shrine_first');
      expect(game.summitOpen, isFalse);
      wake(game, 'crosswind_hall', 'shrine_crown');
      expect(game.summitOpen, isFalse);
      wake(game, 'crosswind_hall', 'shrine_span');
      expect(game.summitOpen, isTrue, reason: 'the fourth wind opens the crown');

      // Standing in the crown banks Star 1.
      game.currentRoomId = 'spire_summit';
      final summit = game.currentRoom.summit!;
      game.creatures[game.activeIndex]
        ..position = summit.rect.center
        ..lastSafe = summit.rect.center;
      game.flightActive = false;
      _step(game, 0.1);
      expect(game.hasStar(0), isTrue);
    });
  });

  group('sky loom', () {
    test('wrong-anchor rejection is rate-limited, not per-frame', () {
      final game = _buildGame();
      game.currentRoomId = 'sky_loom';
      game.discoveredClouds.add('c_spiral');
      final loom = game.currentRoom;
      final spiral = loom.clouds.firstWhere((c) => c.id == 'c_spiral');
      final wrongAnchor = loom.anchors.firstWhere(
        (a) => a.requiredCloudType != 'Spiral',
      );
      final carrier = game.creatures[game.activeIndex];

      // Pick the spiral echo up…
      carrier.position = spiral.position;
      _step(game, 0.1);
      expect(game.carriedCloudType, 'Spiral');

      // …then stand on a mismatched anchor for a dozen frames.
      carrier.position = wrongAnchor.position;
      _step(game, 0.18);
      expect(
        game.combatEnemies.length,
        2,
        reason: 'one rejection (2 wisps), not one rejection per frame',
      );
      expect(
        game.hintText,
        contains('Incorrect placement'),
        reason: 'the wisp-wave hint must not stomp the placement feedback',
      );
      expect(
        game.hintText,
        contains(wrongAnchor.clue),
        reason: 'a rejection teaches the anchor\'s riddle',
      );
    });

    test('a carried echo can be dropped, then picked back up later', () {
      final game = _buildGame();
      game.currentRoomId = 'sky_loom';
      game.discoveredClouds.add('c_spiral');
      final loom = game.currentRoom;
      final spiral = loom.clouds.firstWhere((c) => c.id == 'c_spiral');
      final carrier = game.creatures[game.activeIndex];

      carrier.position = spiral.position;
      _step(game, 0.1);
      expect(game.carriedCloudType, 'Spiral');

      game.dropCarriedCloud();
      expect(game.carriedCloudId, isNull);
      expect(game.carriedCloudType, isNull);

      // Grace period: standing on the echo right after dropping must NOT
      // instantly re-grab it…
      _step(game, 0.3);
      expect(game.carriedCloudId, isNull);

      // …but it is re-carriable once the grace expires.
      _step(game, 1.0);
      expect(game.carriedCloudType, 'Spiral');
    });
  });

  group('survival-parity abilities', () {
    PlanetDungeonGame buildParty(List<(String, String)> elementFamilies) {
      final party = [
        for (var i = 0; i < elementFamilies.length; i++)
          _member(
            slot: i,
            element: elementFamilies[i].$1,
            family: elementFamilies[i].$2,
          ),
      ];
      final game = PlanetDungeonGame(
        element: 'Air',
        party: party,
        initialStarMask: 0,
        onStarEarned: (_) {},
        onPlayerDown: () {},
        onChanged: () {},
      );
      game.currentRoomId = game.layout.entranceRoomId;
      final spawn = game.layout.entranceSpawn;
      for (var i = 0; i < party.length; i++) {
        final c = DungeonCreature(member: party[i])
          ..position = spawn + Offset(i * 60.0, 0)
          ..lastSafe = spawn + Offset(i * 60.0, 0);
        game.creatures.add(c);
        game.combatCompanions.add(_companion(party[i], c.position));
      }
      return game;
    }

    test('horn special runs the real dash flow and releases its burst', () {
      final game = buildParty([('Lightning', 'horn'), ('Air', 'wing')]);
      final caster = game.creatures.first;
      game.spawnWispWave(
        element: 'Air',
        center: caster.position + const Offset(140, 0),
        count: 1,
      );
      _toughen(game);
      final startPos = caster.position;
      final comp = game.combatCompanions.first;
      comp.specialCooldown = 0;

      expect(game.activateCombatAbility(), isTrue);
      expect(
        comp.windUpTimer > 0 || comp.chargeTimer > 0,
        isTrue,
        reason: 'horn cast must begin a wind-up or dash, not an instant burst',
      );
      expect(comp.pendingChargeBurst, isNotNull);

      // Run the full sequence out (dash + possible 3s lightning brew).
      var moved = false;
      for (var t = 0.0; t < 7.0; t += 1 / 60) {
        game.update(1 / 60);
        if ((caster.position - startPos).distance > 24) moved = true;
        for (final c in game.creatures) {
          c.hp = c.maxHp;
        }
      }
      expect(moved, isTrue, reason: 'the dash must carry the creature');
      expect(comp.chargeTimer, lessThanOrEqualTo(0));
      expect(comp.hornPostDashWindUpTimer, lessThanOrEqualTo(0));
      expect(
        comp.pendingChargeBurst,
        isNull,
        reason: 'the impact burst must release by the end of the sequence',
      );
      final wisp = game.combatEnemies.where((e) => !e.isDead).firstOrNull;
      if (wisp != null) {
        expect(
          wisp.hp,
          lessThan(1e9),
          reason: 'the dash sweep / burst must damage swept enemies',
        );
      }
    });

    test('horn dash crosses open sky and settles back to footing', () {
      final game = buildParty([('Lightning', 'horn'), ('Air', 'wing')]);
      // Platform room: the horn stands on a ledge, the wisp hovers over
      // the void between platforms. The old walking-collision dash stopped
      // dead at the platform edge ("charges for half a second").
      game.currentRoomId = 'lower_spire';
      final platform = game.currentRoom.platforms.first;
      for (final c in game.creatures) {
        c.position = platform.center;
        c.lastSafe = platform.center;
      }
      game.spawnWispWave(element: 'Air', center: platform.center, count: 1);
      _toughen(game);
      final wisp = game.combatEnemies.first;
      wisp.position = platform.center + const Offset(120, -145); // over sky
      final caster = game.creatures.first;
      final comp = game.combatCompanions.first;
      comp.specialCooldown = 0;

      expect(game.activateCombatAbility(), isTrue);
      var maxTravel = 0.0;
      final start = caster.position;
      for (var t = 0.0; t < 9.0; t += 1 / 60) {
        wisp.position = platform.center + const Offset(120, -145); // hold it
        game.update(1 / 60);
        maxTravel = max(maxTravel, (caster.position - start).distance);
        for (final c in game.creatures) {
          c.hp = c.maxHp;
        }
      }
      expect(
        maxTravel,
        greaterThan(90),
        reason: 'the airborne ram must cross the platform edge',
      );
      expect(comp.chargeTimer, lessThanOrEqualTo(0));
      expect(comp.hornPostDashWindUpTimer, lessThanOrEqualTo(0));
      final onSolid = game.currentRoom.platforms.any(
        (p) => p.inflate(2).contains(caster.position),
      );
      expect(
        onSolid,
        isTrue,
        reason: 'the horn must never end stranded over the void',
      );
    });

    test('kin basics charge a laser instead of generic projectiles', () {
      final game = buildParty([('Air', 'kin'), ('Air', 'wing')]);
      final caster = game.creatures.first;
      game.spawnWispWave(
        element: 'Air',
        center: caster.position + const Offset(90, 0),
        count: 1,
      );
      _toughen(game);
      final comp = game.combatCompanions.first;
      comp.basicCooldown = 0;

      expect(game.activateAutoAttack(), isTrue);
      expect(
        comp.kinAutoChargeTimer,
        greaterThan(0),
        reason: 'kin auto must begin the charged-laser hold',
      );
      expect(
        game.combatProjectiles,
        isEmpty,
        reason: 'no generic basics while the laser charges',
      );
      _step(game, 1.8);
      expect(comp.kinAutoChargeTimer, 0, reason: 'laser fired');
      expect(comp.basicCooldown, greaterThan(0));
      final wisp = game.combatEnemies.where((e) => !e.isDead).firstOrNull;
      if (wisp != null) {
        expect(wisp.hp, lessThan(1e9), reason: 'the beam must hit its mark');
      }
    });

    test(
      'mane+lightning special scatters sigil orbs that bloom into fields',
      () {
        final game = buildParty([('Lightning', 'mane'), ('Air', 'wing')]);
        final comp = game.combatCompanions.first;
        comp.specialCooldown = 0;
        game.spawnWispWave(
          element: 'Air',
          center: game.creatures.first.position + const Offset(120, 0),
          count: 1,
        );
        _toughen(game);

        expect(game.activateCombatAbility(), isTrue);
        final orbs = game.combatProjectiles
            .where((p) => p.abilityFamily == 'mane' && p.effectStacks == 1)
            .length;
        expect(orbs, greaterThanOrEqualTo(5), reason: '5-10 scattered orbs');
        _step(game, 4.0);
        final fields = game.combatProjectiles
            .where(
              (p) =>
                  p.abilityFamily == 'mane' &&
                  p.stationary &&
                  p.effectStacks == 2,
            )
            .length;
        expect(fields, greaterThan(0), reason: 'orbs bloom into shock fields');
      },
    );
  });

  group('auto-targeting', () {
    test('manual attack and special aim at enemies beyond stat range', () {
      final game = _buildGame();
      final caster = game.creatures.first;
      game.spawnWispWave(
        element: 'Air',
        center: caster.position + const Offset(600, 0),
        count: 1,
      );
      _toughen(game);
      game.combatEnemies.first.position =
          caster.position + const Offset(600, 0); // far outside attackRange
      caster.angle = pi; // facing the wrong way entirely

      expect(game.activateAutoAttack(), isTrue);
      expect(game.combatProjectiles, isNotEmpty);
      expect(
        cos(caster.angle),
        greaterThan(0.8),
        reason: 'the attack must swing the creature toward the enemy',
      );

      caster.angle = pi;
      game.combatCompanions.first.specialCooldown = 0;
      expect(game.activateCombatAbility(), isTrue);
      expect(
        cos(caster.angle),
        greaterThan(0.8),
        reason: 'the special must auto-target the distant enemy too',
      );
    });
  });

  group('wonder trials', () {
    test('spiral eddies reset when ridden out of order', () {
      final game = _buildGame();
      game.currentRoomId = 'spiral_cloud';
      final eddies = game.spiralEddies(game.currentRoom);
      final rider = game.creatures[game.activeIndex];

      rider.position = eddies[0];
      _step(game, 0.1);
      expect(game.wonderProgress('spiral_cloud'), 1);

      rider.position = eddies[2]; // skipped one — the winds scatter
      _step(game, 0.1);
      expect(game.wonderProgress('spiral_cloud'), 0);
      expect(game.discoveredClouds, isNot(contains('c_spiral')));
    });

    test('ring trial refuses to seal while the reagents are scattered', () {
      final game = _buildGame();
      game.currentRoomId = 'ring_cloud';
      game.creatures[game.activeIndex].position =
          game.currentRoom.bounds.center;
      // Find a moment where the motes are NOT gathered.
      var guard = 0;
      while (game.ringMotesAligned && guard++ < 1400) {
        game.update(1 / 60);
      }
      expect(game.ringMotesAligned, isFalse);
      game.activateAbility();
      expect(game.discoveredClouds, isNot(contains('c_ring')));
    });

    test('walking over a sealed echo no longer discovers it', () {
      final game = _buildGame();
      game.currentRoomId = 'veil_cloud';
      game.creatures[game.activeIndex].position =
          game.currentRoom.clouds.first.position;
      _step(game, 1.0);
      expect(game.discoveredClouds, isNot(contains('c_veil')));
    });
  });

  group('updrafts', () {
    test('a walking creature rides a thermal column upward', () {
      final game = _buildGame();
      game.currentRoomId = 'lower_spire';
      final walker = game.creatures[game.activeIndex];
      // The spire is born calm: the thermal must be WOKEN before it carries
      // anyone (§9.1 — gales are authored, not found).
      final first = game.currentRoom.gustShrines.firstWhere(
        (s) => s.id == 'shrine_first',
      );
      walker
        ..position = first.position
        ..lastSafe = first.position;
      game.activateAbility();
      expect(game.wokenGales, contains('g_thermal'));
      // Stand on the base ledge inside the west thermal's entry overlap.
      walker.position = const Offset(200, 830);
      walker.lastSafe = walker.position;
      expect(game.flightActive, isFalse);
      _step(game, 1.6); // let the wind swell to full (it never snaps on)

      final startY = walker.position.dy;
      _step(game, 2.5);
      expect(game.updraftRiding, isTrue, reason: 'the column carries walkers');
      expect(
        walker.position.dy,
        lessThan(startY - 120),
        reason: 'the thermal lifts the walker well off the platform',
      );
    });

    test('leaving the column over the void drifts back to footing', () {
      final game = _buildGame();
      game.currentRoomId = 'lower_spire';
      final walker = game.creatures[game.activeIndex];
      final first = game.currentRoom.gustShrines.firstWhere(
        (s) => s.id == 'shrine_first',
      );
      walker
        ..position = first.position
        ..lastSafe = first.position;
      game.activateAbility();
      walker.position = const Offset(200, 830);
      walker.lastSafe = walker.position;
      _step(game, 3.0); // riding up
      // Shove the walker clear of ALL currents, over open sky.
      walker.position = const Offset(620, 560); // void, no current
      _step(game, 2.5);
      // Not stranded = back on solid footing OR being carried by a thermal
      // (the recovery spot on platform 2 sits inside the west column, so
      // the walker may legitimately be riding again).
      final onSolid = game.currentRoom.platforms.any(
        (p) => p.inflate(2).contains(walker.position),
      );
      expect(
        onSolid || game.updraftRiding,
        isTrue,
        reason: 'never stranded over the void',
      );
    });
  });

  group('lightning parity', () {
    test('Lightning arcs everything the Air+Fire braid can electrify', () {
      final game = PlanetDungeonGame(
        element: 'Air',
        party: [
          _member(slot: 0, element: 'Lightning', family: 'horn'),
          _member(slot: 1),
        ],
        initialStarMask: 0,
        onStarEarned: (_) {},
        onPlayerDown: () {},
        onChanged: () {},
      );
      game.currentRoomId = game.layout.entranceRoomId;
      final spawn = game.layout.entranceSpawn;
      for (var i = 0; i < 2; i++) {
        final m = i == 0
            ? _member(slot: 0, element: 'Lightning', family: 'horn')
            : _member(slot: 1);
        final c = DungeonCreature(member: m)
          ..position = spawn
          ..lastSafe = spawn;
        game.creatures.add(c);
        game.combatCompanions.add(_companion(m, spawn));
      }
      final bolt = game.creatures[0];

      // 1. Entry passage: arc from inside the gust reveals the door.
      bolt.position = game.currentRoom.currents.first.rect.center;
      game.activateAbility();
      expect(game.entryDoorRevealed, isTrue, reason: 'Lightning reveals too');

      // 2. A carried Anvil: electrify the cloud, no wind needed. (Must run
      // before the loom star is banked — cleared stars hide their clouds.)
      game.discoveredClouds.add('c_anvil');
      game.currentRoomId = 'sky_loom';
      final anvil = game.currentRoom.clouds.firstWhere(
        (c) => c.id == 'c_anvil',
      );
      bolt.position = anvil.position;
      _step(game, 0.1);
      expect(game.carriedCloudType, 'Anvil');
      game.activateAbility();
      expect(
        game.carriedCloudType,
        'Thundercloud',
        reason: 'Lightning electrifies the carried cloud directly',
      );
      game.carriedCloudId = null;
      game.carriedCloudType = null;

      // 3. Conduit B is the one place the parity rule NO LONGER reaches:
      // §9.1 took it away from every hand, Lightning's included, and gave it
      // to the storm. The refusal must say so in one clause.
      game.earnStar(0);
      game.earnStar(1);
      game.currentRoomId = 'twin_conduit';
      final conduitB = game.currentRoom.conduits.firstWhere((c) => c.id == 'B');
      bolt.position = conduitB.position;
      game.activateAbility();
      expect(
        game.conduitEnergy['B'] ?? 0,
        0,
        reason: 'conduit B waits on the storm, not on an arc',
      );
      expect(game.hintText, contains('storm'));
      expect(game.hintChannel, DungeonHintChannel.blocked);
    });
  });

  group('survival hit parity', () {
    test('Mane+Air pierce shoves enemies along the gale path', () {
      final game = _buildGame();
      final player = game.creatures.first;
      game.spawnWispWave(element: 'Air', center: player.position, count: 1);
      _toughen(game);
      final enemy = game.combatEnemies.single;
      enemy.position = player.position + const Offset(120, 0);
      final before = enemy.position;

      game.combatProjectiles.add(
        Projectile(
          position: enemy.position,
          angle: 0, // shoving due east
          element: 'Air',
          damage: 1,
          life: 1.0,
          piercing: true,
          abilityFamily: 'mane',
          effectPower: 150,
          effectDuration: 1.0,
        ),
      );
      game.update(1 / 60);

      expect(
        enemy.position.dx - before.dx,
        greaterThan(60),
        reason: 'the gale carries the enemy down its path',
      );
      expect(enemy.slowMultiplier, lessThanOrEqualTo(0.68));
    });

    test('pip ricochet bounces toward the nearest clustered enemy', () {
      final game = _buildGame();
      final player = game.creatures.first;
      game.spawnWispWave(element: 'Air', center: player.position, count: 2);
      _toughen(game);
      final a = game.combatEnemies[0];
      final b = game.combatEnemies[1];
      a.position = player.position + const Offset(150, 0);
      b.position = a.position + const Offset(0, 80);

      final dart = Projectile(
        position: a.position,
        angle: 0,
        element: 'Fire',
        damage: 50,
        life: 1.0,
        piercing: false,
        abilityFamily: 'pip',
        visualStyle: ProjectileVisualStyle.dart,
        bounceCount: 2,
      );
      game.combatProjectiles.add(dart);
      game.update(1 / 60);

      expect(
        game.combatProjectiles,
        contains(dart),
        reason: 'a bounce keeps the dart alive instead of consuming it',
      );
      expect(dart.damage, lessThan(50), reason: 'damage sheds per hop');
      // The new heading points at the second enemy (roughly straight down).
      expect(cos(dart.angle).abs(), lessThan(0.5));
      expect(dart.bounceCount, 1);
    });
  });

  group('summit shortcut', () {
    test('the loom↔summit passage stays hidden until the Wind Star', () {
      final game = _buildGame();
      game.currentRoomId = 'sky_loom';
      final shortcut = game.currentRoom.doors.firstWhere(
        (d) => d.targetRoomId == 'spire_summit',
      );
      expect(game.isDoorHidden(game.currentRoom, shortcut), isTrue);

      // Standing in a hidden door does nothing.
      game.creatures[game.activeIndex].position = shortcut.rect.center;
      _step(game, 0.3);
      expect(game.currentRoomId, 'sky_loom');

      // Claiming the Wind Star reveals the reward exit, both directions.
      game.earnStar(0);
      expect(game.isDoorHidden(game.currentRoom, shortcut), isFalse);
      final summit = game.layout.rooms['spire_summit']!;
      final back = summit.doors.firstWhere((d) => d.targetRoomId == 'sky_loom');
      expect(game.isDoorHidden(summit, back), isFalse);
      game.creatures[game.activeIndex].position = shortcut.rect.center;
      _step(game, 0.6);
      expect(game.currentRoomId, 'spire_summit');
    });
  });

  group('storm wing lock', () {
    test('the loom→storm door needs BOTH leading stars, in any order', () {
      final game = _buildGame();
      game.currentRoomId = 'sky_loom';
      final stormDoor = game.currentRoom.doors.firstWhere(
        (d) => d.targetRoomId == 'storm_rune_hall',
      );
      expect(game.isDoorLocked(game.currentRoom, stormDoor), isTrue);

      game.creatures[game.activeIndex].position = stormDoor.rect.center;
      _step(game, 0.3);
      expect(
        game.currentRoomId,
        'sky_loom',
        reason: 'a sealed door must not transition',
      );
      expect(game.hintText, contains('sealed'));

      // One star — either one — is not enough.
      game.earnStar(1);
      expect(game.isDoorLocked(game.currentRoom, stormDoor), isTrue);

      game.earnStar(0);
      expect(game.isDoorLocked(game.currentRoom, stormDoor), isFalse);
      game.creatures[game.activeIndex].position = stormDoor.rect.center;
      _step(game, 0.6);
      expect(game.currentRoomId, 'storm_rune_hall');
    });

    test('the altar conduits refuse offerings until both stars are banked', () {
      final game = PlanetDungeonGame(
        element: 'Air',
        party: [_member(slot: 0, element: 'Lightning', family: 'horn')],
        initialStarMask: 0,
        onStarEarned: (_) {},
        onPlayerDown: () {},
        onChanged: () {},
      );
      game.currentRoomId = 'twin_conduit';
      final m = _member(slot: 0, element: 'Lightning', family: 'horn');
      final c = DungeonCreature(member: m)
        ..position = game.currentRoom.conduits.first.position
        ..lastSafe = game.currentRoom.conduits.first.position;
      game.creatures.add(c);
      game.combatCompanions.add(_companion(m, c.position));

      // §9.1: conduit B answers no hand at all now — the storm strikes it.
      // The rite lock is proved on the conduit a hand CAN reach: A.
      final conduitA = game.currentRoom.conduits.firstWhere((k) => k.id == 'A');
      c.position = conduitA.position;

      // No stars: the horn's grip lands but the pylon swallows it.
      game.activateAbility();
      expect(game.conduitEnergy['A'] ?? 0, 0, reason: 'rite still sealed');
      expect(game.guardianRiteUnlocked, isFalse);

      // One star: still sealed.
      game.earnStar(0);
      game.activateAbility();
      expect(game.conduitEnergy['A'] ?? 0, 0, reason: 'one star is not enough');

      // Both stars (order-free): the offering takes, and it LATCHES.
      game.earnStar(1);
      expect(game.guardianRiteUnlocked, isTrue);
      game.activateAbility();
      expect(game.conduitEnergy['A'], double.infinity);
    });
  });

  group('discovery persistence', () {
    test('entry-door reveal survives a party-wipe reset once discovered', () {
      final game = _buildGame();
      game.discoveredClouds.add(PlanetDungeonGame.entryDoorDiscoveryId);
      game.entryDoorRevealed = true;
      for (var i = 0; i < game.creatures.length; i++) {
        game.creatures[i].hp = 0;
        game.combatCompanions[i].currentHp = 0;
      }
      game.update(1 / 60); // wipe → reset run
      expect(game.creatures.every((c) => c.alive), isTrue);
      expect(
        game.entryDoorRevealed,
        isTrue,
        reason: 'the entry passage is knowledge — it stays revealed',
      );
    });

    test('debugResetDungeon wipes stars, discoveries and the live run', () {
      final game = _buildGame();
      game.earnStar(0);
      game.discoveredClouds.add('spiral_1');
      game.discoveredClouds.add(PlanetDungeonGame.entryDoorDiscoveryId);
      game.entryDoorRevealed = true;
      game.spawnWispWave(
        element: 'Air',
        center: game.creatures.first.position,
        count: 2,
      );

      game.debugResetDungeon();

      expect(game.starMask, 0);
      expect(game.starsEarnedCount, 0);
      expect(game.discoveredClouds, isEmpty);
      expect(game.entryDoorRevealed, isFalse);
      expect(game.combatEnemies, isEmpty);
      expect(game.currentRoomId, game.layout.entranceRoomId);
      expect(game.creatures.every((c) => c.alive), isTrue);
    });

    test('entry-door reveal resets when it was never discovered', () {
      final game = _buildGame();
      game.entryDoorRevealed = true; // transient, not banked
      for (var i = 0; i < game.creatures.length; i++) {
        game.creatures[i].hp = 0;
        game.combatCompanions[i].currentHp = 0;
      }
      game.update(1 / 60);
      expect(game.entryDoorRevealed, isFalse);
    });
  });

  group('numeric sanity', () {
    test('steering never produces NaN positions', () {
      final game = _buildGame();
      final player = game.creatures.first;
      game.spawnWispWave(element: 'Air', center: player.position, count: 4);
      _toughen(game);
      // Include a degenerate case: enemy exactly on top of the player.
      game.combatEnemies.first.position = player.position;
      _step(game, 5.0);
      for (final e in game.combatEnemies) {
        expect(e.position.dx.isFinite, isTrue);
        expect(e.position.dy.isFinite, isTrue);
        expect(
          sqrt((e.position - player.position).distanceSquared).isFinite,
          isTrue,
        );
      }
    });
  });
}
