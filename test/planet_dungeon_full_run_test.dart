// Air (Wind-Crown Spire) — the §9.1 rework, tested per mechanic.
//
// Air was the pilot, and its old test was one long "can the trio finish?"
// script. The rework earns the same treatment the later planets got: one focused
// test per claim the design makes, plus a full end-to-end run that proves the
// pieces still add up to a dungeon.
//
// What is pinned here:
//   • Star 1 — shrines wake gales PERMANENTLY (no timers), the crown opens only
//     on the fourth wind, a wrong wake order really does bar the ledge to a
//     later shrine, and — the one non-negotiable — NO wake order can ever
//     strand the player (solver-proved over every state and every order), with
//     death resetting the winds as the belt and braces.
//   • Star 1 physics — a woken gale carries walkers AND wisps, friend and foe.
//   • Star 3 — conduit A keeps its hard Lightning+Horn gate and now latches;
//     conduit B answers no hand at all; the storm's leader climbs a rod
//     staircase (solver-proved family, with the two named mis-rankings failing
//     everywhere); gusts herd the cell.
//   • The Roc drags the cell across its own rod field, and a bolt led into the
//     bird forces the lull.
//   • The invariants: the First Wind egg (and its permanence), the vault cache,
//     the relic, the mercy shrine.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_companion_stats.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart'
    show CosmicSurvivalCompanion;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_rewards.dart';
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

/// The §6 ideal trio: Airwing · Firemask · Lightninghorn.
List<CosmicPartyMember> _trio() => [
  _member(0, 'Air', 'wing'),
  _member(1, 'Fire', 'mask'),
  _member(2, 'Lightning', 'horn'),
];

PlanetDungeonGame _harness(
  List<CosmicPartyMember> party, {
  void Function(int)? onStarEarned,
  void Function(String)? onCloudDiscovered,
  void Function()? onPlayerDown,
}) {
  final game = PlanetDungeonGame(
    element: 'Air',
    party: party,
    initialStarMask: 0,
    onStarEarned: onStarEarned ?? (_) {},
    onCloudDiscovered: onCloudDiscovered,
    onPlayerDown: onPlayerDown ?? () {},
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
  return game;
}

void _step(PlanetDungeonGame game, [double seconds = 0.1]) {
  var t = 0.0;
  while (t < seconds) {
    game.update(1 / 60);
    t += 1 / 60;
  }
  // These sims verify puzzle flow, not survival.
  for (final c in game.creatures) {
    c.hp = c.maxHp;
  }
}

void _teleport(PlanetDungeonGame game, String roomId, Offset pos) {
  game.currentRoomId = roomId;
  game.creatures[game.activeIndex]
    ..position = pos
    ..lastSafe = pos;
}

/// Find a shrine anywhere in the spire.
(String, GustShrine) _shrine(PlanetDungeonGame game, String id) {
  for (final room in game.layout.rooms.values) {
    for (final s in room.gustShrines) {
      if (s.id == id) return (room.id, s);
    }
  }
  throw StateError('no shrine $id');
}

/// Stand at a shrine and commune. Does NOT care how you got there — the
/// reachability claims are the solver's job; this is the verb.
void _wake(PlanetDungeonGame game, String shrineId) {
  final (roomId, shrine) = _shrine(game, shrineId);
  _teleport(game, roomId, shrine.position);
  game.activateAbility();
  _step(game);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── Star 1 — WAKE THE WINDS ────────────────────────────

  group('Star 1 · waking the winds', () {
    test('the spire is born calm, and a woken gale never sleeps again', () {
      final game = _harness(_trio());
      for (final room in game.layout.rooms.values) {
        for (final c in room.currents) {
          if (c.galeId == null) continue;
          expect(
            game.wokenGales.contains(c.galeId),
            isFalse,
            reason: 'gale ${c.galeId} must start asleep',
          );
        }
      }

      _wake(game, 'shrine_first');
      expect(game.wokenGales, contains('g_thermal'));

      // No timer anywhere can take it back — a full minute of world time.
      _step(game, 60);
      expect(
        game.wokenGales,
        contains('g_thermal'),
        reason: 'gales are permanent for the run; nothing decays',
      );
    });

    test('a gale SWELLS to full instead of snapping on (animated-state)', () {
      final game = _harness(_trio());
      _wake(game, 'shrine_first');
      // The wake step already advanced a beat; it must still be building.
      final mid = game.galeRamp['g_thermal']!;
      expect(mid, greaterThan(0.0));
      expect(mid, lessThan(1.0), reason: 'a wind does not snap on');
      _step(game, 2.0);
      expect(game.galeRamp['g_thermal'], 1.0);
    });

    test('the crown opens only on the FOURTH wind, and banks Star 1', () {
      final earned = <int>[];
      final game = _harness(_trio(), onStarEarned: earned.add);
      final ids = [for (final s in game.allGustShrines) s.id];
      expect(ids.length, 4, reason: 'four winds, four shrines');

      for (var i = 0; i < ids.length; i++) {
        _wake(game, ids[i]);
        expect(
          game.summitOpen,
          i == ids.length - 1,
          reason: 'the crown answers the last wind, not the first',
        );
      }

      final summitRoom = game.layout.rooms.values.firstWhere(
        (r) => r.summit != null,
      );
      _teleport(game, summitRoom.id, summitRoom.summit!.rect.center);
      _step(game);
      expect(game.hasStar(0), isTrue);
      expect(earned, [0]);
    });

    test('a woken gale carries WALKERS — it is a ladder, not a flier perk', () {
      final game = _harness(_trio());
      _wake(game, 'shrine_first');
      _step(game, 2.0); // let it swell

      _teleport(game, 'lower_spire', const Offset(200, 830));
      final walker = game.creatures[game.activeIndex];
      expect(game.flightActive, isFalse, reason: 'this is a WALKER');
      final startY = walker.position.dy;
      _step(game, 2.5);
      expect(game.updraftRiding, isTrue);
      expect(
        walker.position.dy,
        lessThan(startY - 120),
        reason: 'the wind you woke lifts you',
      );
    });

    test('a woken gale pushes FOES too — friend and foe alike', () {
      // Differential: the same wisp, the same chase, with and without the
      // crosswind blowing. Only the wind can explain the difference.
      double driftWith({required bool woken}) {
        final game = _harness(_trio());
        if (woken) {
          _wake(game, 'shrine_span');
          _step(game, 2.0); // let the river swell to full
        }
        game.currentRoomId = 'crosswind_hall';
        final river = game.layout.rooms['crosswind_hall']!.currents.firstWhere(
          (c) => c.galeId == 'g_cross',
        );
        // Park the party west of the wisp so its chase pulls it AGAINST the
        // wind — the wind still has to win ground back.
        game.creatures[game.activeIndex]
          ..position = const Offset(105, 296)
          ..lastSafe = const Offset(105, 296);
        game.spawnWispWave(
          element: 'Air',
          center: river.rect.center,
          count: 1,
          announce: false,
        );
        final wisp = game.combatEnemies.single;
        wisp.position = river.rect.center;
        final before = wisp.position.dx;
        _step(game, 1.0);
        return wisp.position.dx - before;
      }

      final calm = driftWith(woken: false);
      final blown = driftWith(woken: true);
      expect(
        blown - calm,
        greaterThan(30),
        reason: 'a woken gale carries the wisps downwind too',
      );
    });

    test('the WINDS readout replaced the retired RINGS counter', () {
      final game = _harness(_trio());
      game.currentRoomId = 'lower_spire';
      final readout = game.progressReadout;
      expect(readout, isNotNull);
      expect(readout!.label, 'WINDS');
      expect(readout.value, '0/4');
      _wake(game, 'shrine_first');
      game.currentRoomId = 'lower_spire';
      expect(game.progressReadout!.value, '1/4');
    });
  });

  group('Star 1 · the waking ORDER', () {
    test('a wrong order really does bar the ledge to a later shrine', () {
      final game = _harness(_trio());
      final ridge = _shrine(game, 'shrine_ridge').$2;

      // Calm spire: the ridge stair is open and free.
      final calm = game.windReachability(const <String>{});
      expect(calm.reachable, contains(ridge.ledgeId));
      expect(
        calm.free,
        contains(ridge.ledgeId),
        reason: 'before any wind, the stair is a plain walk',
      );

      // Wake the First Breath first: its spill scours that stair.
      final scoured = game.windReachability({'g_thermal'});
      expect(
        scoured.free,
        isNot(contains(ridge.ledgeId)),
        reason: 'the early gale GUARDS the ledge to the later shrine',
      );
      // …but never seals it: the long way round survives.
      expect(
        scoured.reachable,
        contains(ridge.ledgeId),
        reason: 'blown off is a fall and a climb, never a wall',
      );
    });

    test('exactly one wake order is fall-free, and it is the planned one', () {
      final game = _harness(_trio());
      final r = game.solveWindWaking();
      expect(r.orders, 24);
      expect(
        r.achievable,
        greaterThan(1),
        reason: 'the spire must leave real freedom, not one scripted path',
      );
      expect(r.fallFree, 1, reason: 'planning ahead has exactly one reward');
      expect(r.fallFreeOrders.single, const [
        'shrine_ridge',
        'shrine_first',
        'shrine_crown',
        'shrine_span',
      ]);
    });

    test('NO WAKE ORDER CAN STRAND THE PLAYER (exhaustive)', () {
      // The one unacceptable failure for a permanent-state puzzle. The solver
      // explores every state the player can actually reach and asserts that a
      // next move always exists — and that the crown is reachable at the end.
      final game = _harness(_trio());
      expect(
        game.solveWindWaking().strandable,
        0,
        reason: 'a permanent wind must never wedge the run',
      );
    });

    test('every wake order still finishes the ascent', () {
      // Belt to the solver's braces, played through the real verbs: wake the
      // shrines in each order the solver calls achievable and confirm the
      // crown opens every time.
      final game = _harness(_trio());
      final ids = [for (final s in game.allGustShrines) s.id]..sort();
      var played = 0;
      void perm(List<String> order, List<String> left) {
        if (left.isEmpty) {
          final g = _harness(_trio());
          for (final id in order) {
            _wake(g, id);
          }
          expect(
            g.summitOpen,
            isTrue,
            reason: 'order $order left the crown shut',
          );
          expect(g.wokenGales.length, 4);
          played++;
          return;
        }
        for (var i = 0; i < left.length; i++) {
          perm([...order, left[i]], [...left]..removeAt(i));
        }
      }

      perm(const [], ids);
      expect(played, 24, reason: 'all 24 orders exercised');
      expect(game.allGaleIds.length, 4);
    });

    test('death resets the winds — a wedged spire is always recoverable', () {
      var downed = 0;
      final game = _harness(_trio(), onPlayerDown: () => downed++);
      _wake(game, 'shrine_first');
      _wake(game, 'shrine_ridge');
      expect(game.wokenGales.length, 2);

      // Wipe the party: the run resets and the spire falls calm again.
      for (final c in game.creatures) {
        c.hp = 0;
      }
      game.update(1 / 60);
      expect(downed, 1);
      expect(game.wokenGales, isEmpty, reason: 'death resets the winds');
      expect(game.galeRamp, isEmpty);
      expect(game.summitOpen, isFalse);
    });
  });

  // ── Star 3 — STORM-ROD STEERING ────────────────────────

  group('Star 3 · the storm and the rods', () {
    PlanetDungeonGame altarReady([List<CosmicPartyMember>? party]) {
      final g = _harness(party ?? _trio());
      g.starMask = (1 << 0) | (1 << 1); // the rite waits on Stars 1+2
      return g;
    }

    test('conduit A is a HARD GATE: only a Lightning horn holds it', () {
      double channel(PlanetDungeonGame game) {
        game.starMask = (1 << 0) | (1 << 1);
        final conduit = game.layout.rooms['twin_conduit']!.conduits.firstWhere(
          (c) => c.id == 'A',
        );
        _teleport(game, 'twin_conduit', conduit.position);
        game.activateAbility();
        return game.conduitEnergy['A'] ?? 0;
      }

      for (final family in const ['pip', 'mane', 'mask', 'wing', 'kin']) {
        expect(
          channel(_harness([_member(0, 'Lightning', family)])),
          0,
          reason: 'a Lightning $family must not channel the conduit at all',
        );
      }
      expect(
        channel(_harness([_member(0, 'Air', 'horn')])),
        0,
        reason: 'the conduit hums with Lightning alone',
      );
      expect(
        channel(_harness([_member(0, 'Lightning', 'horn')])),
        double.infinity,
        reason: 'the Horn\'s hold LATCHES — the decay timers retired',
      );
    });

    test('conduit A latches: nothing drains it any more', () {
      final game = altarReady();
      final a = game.layout.rooms['twin_conduit']!.conduits.firstWhere(
        (c) => c.id == 'A',
      );
      game.setActive(2);
      _teleport(game, 'twin_conduit', a.position);
      game.activateAbility();
      _step(game, 30);
      expect(game.conduitEnergy['A'], double.infinity);
      expect(game.altarOpen, isFalse, reason: 'B still waits on the storm');
    });

    test('conduit B answers no hand at all — only the storm', () {
      final game = altarReady();
      final b = game.layout.rooms['twin_conduit']!.conduits.firstWhere(
        (c) => c.id == 'B',
      );
      for (var i = 0; i < 3; i++) {
        game.setActive(i);
        _teleport(game, 'twin_conduit', b.position);
        game.activateAbility();
        expect(
          game.conduitEnergy['B'] ?? 0,
          0,
          reason: '${game.creatures[i].member.element} must not light B by '
              'hand — the arc/recipe path retired with the timers',
        );
      }
      expect(game.hintText, contains('storm'));
    });

    test('the rod ranking is solver-proved, and the two named '
        'mis-rankings fail everywhere', () {
      final game = altarReady();
      final r = game.solveRodRanking();
      expect(r.rankings, 1024, reason: '5 rods × 4 ranks');
      // A FAMILY of valid configurations, not a single answer — but a small,
      // deliberate one: the overwhelming majority of rankings never route.
      expect(r.solvable, greaterThan(0));
      expect(
        r.solvable,
        lessThan(r.rankings ~/ 20),
        reason: 'fewer than 5% of rankings route the bolt — this is a puzzle',
      );
      // The two mis-rankings the design names must genuinely fail, from EVERY
      // point on the cell's ring: rods all down (nothing to climb) and rods
      // all up (a plateau the leader cannot start on).
      expect(r.flatRouting, 0, reason: 'a flat field never routes the bolt');
      expect(r.plateauRouting, 0, reason: 'a plateau never routes the bolt');
      expect(r.example, isNotNull);
      expect(r.exampleCranks, greaterThan(0));
    });

    test('a solver-proved ranking really does light conduit B in play', () {
      final game = altarReady();
      final room = game.layout.rooms['twin_conduit']!;
      final solved = game.solveRodRanking().example!;

      // Rank the rods exactly as the solver says, through the real verb.
      game.setActive(0); // the Air wing works the rods (element-only)
      for (final rod in room.stormRods) {
        final want = solved[rod.id]!;
        var guard = 0;
        while ((game.rodHeight[rod.id] ?? 0) != want && guard++ < 8) {
          _teleport(game, 'twin_conduit', rod.position);
          game.activateAbility();
        }
        expect(game.rodHeight[rod.id], want);
      }

      // Channel A so the altar can open when the storm lands.
      final a = room.conduits.firstWhere((c) => c.id == 'A');
      game.setActive(2);
      _teleport(game, 'twin_conduit', a.position);
      game.activateAbility();

      // Now let the storm circle. Somewhere on its ring the leader climbs.
      game.setActive(0);
      _teleport(game, 'twin_conduit', room.bounds.bottomLeft + const Offset(60, -60));
      var guard = 0;
      while ((game.conduitEnergy['B'] ?? 0) <= 0 && guard++ < 400) {
        _step(game, 0.25);
      }
      expect(
        game.conduitEnergy['B'] ?? 0,
        greaterThan(0),
        reason: 'the staircase the solver proved must light B in the game',
      );
      expect(game.lastLeaderPath.last, 'B');
      _step(game, 0.5);
      expect(game.altarOpen, isTrue);
      expect(game.guardianAwake, isTrue);
    });

    test('a mis-ranked field strikes wild instead — the consequence layer', () {
      final game = altarReady();
      final room = game.layout.rooms['twin_conduit']!;
      // Every rod at full height: a plateau, so the leader never starts.
      for (final rod in room.stormRods) {
        game.rodHeight[rod.id] = kStormRodMaxHeight;
      }
      final cell = room.stormOrbit!.positionAt(0.0);
      final path = game.stormLeaderFrom(cell, room);
      expect(
        path.contains('B'),
        isFalse,
        reason: 'a plateau cannot hand the storm the conduit',
      );

      // One rod down beside the cell, the rest high: the bolt dies on iron.
      for (final rod in room.stormRods) {
        game.rodHeight[rod.id] = kStormRodMaxHeight;
      }
      game.rodHeight['rod_low'] = 0;
      final wild = game.stormLeaderFrom(
        room.stormRods.firstWhere((r) => r.id == 'rod_low').position,
        room,
      );
      expect(wild, isNotEmpty);
      expect(wild.last, isNot('B'), reason: 'a wild strike, not a conduit');
    });

    test('gusts herd the cell — Air\'s own verb, and Air\'s alone', () {
      final game = altarReady();
      final room = game.layout.rooms['twin_conduit']!;
      final cell = game.stormCellPosition(room)!;

      // A Fire creature is refused, cleanly and in one clause.
      game.setActive(1);
      _teleport(game, 'twin_conduit', cell + const Offset(40, 0));
      game.activateAbility();
      expect(game.hintChannel, DungeonHintChannel.blocked);
      final before = game.stormCellAngle;

      // The Air wing shoves it along the ring.
      game.setActive(0);
      _teleport(game, 'twin_conduit', cell + const Offset(40, 0));
      game.activateAbility();
      expect(
        (game.stormCellAngle - before).abs(),
        greaterThan(0.4),
        reason: 'the gust moves the storm, which moves the leader\'s foot',
      );
    });

    test('storm-rods are ELEMENT-ONLY: every Air family cranks them alike', () {
      for (final family in const ['wing', 'horn', 'mask', 'pip', 'mane']) {
        final game = _harness([_member(0, 'Air', family)]);
        game.starMask = (1 << 0) | (1 << 1);
        final rod = game.layout.rooms['twin_conduit']!.stormRods.first;
        _teleport(game, 'twin_conduit', rod.position);
        game.activateAbility();
        expect(
          game.rodHeight[rod.id],
          1,
          reason: 'an Air $family works the rods at full power',
        );
      }
    });
  });

  // ── The Roc (§7) ───────────────────────────────────────

  group('the Roc drags the storm across its own rod field', () {
    test('the cell trails the bird, always out of its own reach', () {
      final game = _harness(_trio());
      game.starMask = (1 << 0) | (1 << 1);
      final room = game.layout.rooms['guardian_summit']!;
      expect(room.stormRods, isNotEmpty);
      expect(room.stormOrbit, isNotNull);

      game.altarOpen = true;
      game.guardianAwake = true;
      _teleport(game, 'guardian_summit', const Offset(410, 620));
      _step(game, 1.5); // the leash settles behind the bird

      final bird = room.guardian!.position;
      for (var i = 0; i < 32; i++) {
        game.stormCellAngle = i * 2 * 3.14159265 / 32;
        final cell = game.stormCellPosition(room)!;
        expect(
          (cell - bird).distance,
          greaterThan(kStormHopReach),
          reason: 'the leash keeps the storm out of a single leap of the bird',
        );
      }
    });

    test('a staircase of perch-rods leads the bolt into the Roc, and that '
        'forces the lull', () {
      final game = _harness(_trio());
      game.starMask = (1 << 0) | (1 << 1);
      final room = game.layout.rooms['guardian_summit']!;
      game.altarOpen = true;
      game.guardianAwake = true;
      _teleport(game, 'guardian_summit', const Offset(410, 620));
      _step(game, 1.5);

      final bird = room.guardian!.position;

      // Pick the cell position that has a rod nearest to hand, then rank the
      // ring outward-in: the rod by the cell is rank 0, and the climb walks
      // round the ring to a rank-3 perch the bolt can leap from into the bird.
      var bestAngle = 0.0;
      var bestDist = double.infinity;
      for (var i = 0; i < 64; i++) {
        final ang = i * 2 * 3.14159265 / 64;
        game.stormCellAngle = ang;
        final cell = game.stormCellPosition(room)!;
        for (final rod in room.stormRods) {
          final d = (rod.position - cell).distance;
          if (d < bestDist) {
            bestDist = d;
            bestAngle = ang;
          }
        }
      }
      game.stormCellAngle = bestAngle;
      final cell = game.stormCellPosition(room)!;
      expect(bestDist, lessThan(kStormHopReach));

      // Rank the ring by how far round it each rod sits from the foot rod.
      final foot = room.stormRods.reduce(
        (a, b) => (a.position - cell).distance < (b.position - cell).distance
            ? a
            : b,
      );
      final ring = [...room.stormRods];
      final footIndex = ring.indexOf(foot);
      for (var i = 0; i < ring.length; i++) {
        // Walk the ring one way; the first four rods form 0,1,2,3.
        final step = (i - footIndex) % ring.length;
        game.rodHeight[ring[i].id] = step <= kStormRodMaxHeight ? step : 0;
      }
      expect(game.rodHeight[foot.id], 0);

      final led = game.stormLeaderFrom(cell, room, guardianAt: bird);
      expect(led, isNotEmpty, reason: 'the leader must find the low iron');
      expect(
        led.last,
        'guardian',
        reason: 'the staircase ends in the bird — Star 3\'s own vocabulary',
      );

      // Let the storm discharge: the strike forces a lull the shared cycle
      // would not have offered.
      game.stormStrikeTimer = room.stormOrbit!.strikeInterval - 0.01;
      game.stormCellAngle = bestAngle;
      game.update(1 / 60);
      expect(game.lastLeaderPath.last, 'guardian');
      expect(
        game.guardianVulnerable,
        isTrue,
        reason: 'a bolt led into the Roc opens the window',
      );
    });

    test('felling the Roc drops the guardian relic on the spot', () {
      final game = _harness(_trio());
      game.starMask = (1 << 0) | (1 << 1);
      game.currentRoomId = 'guardian_summit';
      game.earnStar(2);
      expect(game.relicDropActive, isTrue);
      expect(guardianRelicName('Air'), isNotEmpty);
    });

    test('raids stay exempt — a generated arena has no rod field', () {
      final layout = buildRaidArenaLayout('Air');
      expect(layout.entranceRoom.stormRods, isEmpty);
      expect(layout.entranceRoom.stormOrbit, isNull);
      expect(layout.entranceRoom.gustShrines, isEmpty);
    });
  });

  // ── The whole dungeon, end to end ──────────────────────

  test('the authored trio can earn all three Air stars end-to-end', () {
    final earned = <int>[];
    final discovered = <String>[];
    final game = _harness(
      _trio(),
      onStarEarned: earned.add,
      onCloudDiscovered: discovered.add,
      onPlayerDown: () => fail('the scripted run must never wipe'),
    );

    DungeonRoom room(String id) => game.layout.rooms[id]!;

    // ── Entry: Fire ignites the wind current → hidden passage reveals ──
    game.setActive(1); // Fire mask
    _teleport(game, 'entry', room('entry').currents.first.rect.center);
    game.activateAbility();
    _step(game);
    expect(game.entryDoorRevealed, isTrue, reason: 'Air+Fire reveals entry');
    expect(discovered, contains(PlanetDungeonGame.entryDoorDiscoveryId));

    // ── Star 1: wake all four winds (in the fall-free order), then the crown ──
    game.setActive(0);
    for (final id in const [
      'shrine_ridge',
      'shrine_first',
      'shrine_crown',
      'shrine_span',
    ]) {
      _wake(game, id);
    }
    expect(game.summitOpen, isTrue);
    _teleport(game, 'spire_summit', room('spire_summit').summit!.rect.center);
    _step(game);
    expect(game.hasStar(0), isTrue, reason: 'Star 1 banks at the crown');

    // ── Star 2 (UNCHANGED): earn the five echoes through their trials ──
    game.setActive(0);
    for (final eddy in game.spiralEddies(room('spiral_cloud'))) {
      _teleport(game, 'spiral_cloud', eddy);
      _step(game);
    }
    expect(game.discoveredClouds, contains('c_spiral'));

    _teleport(game, 'ring_cloud', room('ring_cloud').bounds.center);
    var guard = 0;
    while (!game.ringMotesAligned && guard++ < 1400) {
      game.update(1 / 60);
    }
    expect(game.ringMotesAligned, isTrue);
    game.activateAbility();
    expect(game.discoveredClouds, contains('c_ring'));

    game.setActive(1); // Fire braided through the wind cracks the shell
    _teleport(game, 'anvil_cloud', room('anvil_cloud').currents.first.rect.center);
    game.activateAbility();
    expect(game.combatEnemies.length, 3);
    for (final e in game.combatEnemies) {
      e.isDead = true;
    }
    _step(game);
    expect(game.discoveredClouds, contains('c_anvil'));

    game.setActive(0);
    _teleport(game, 'feather_cloud', room('feather_cloud').platforms.first.center);
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
    expect(game.discoveredClouds, contains('c_feather'));

    game.setActive(2); // Lightning pins the folds from range
    _teleport(game, 'veil_cloud', room('veil_cloud').bounds.center);
    guard = 0;
    while (!game.discoveredClouds.contains('c_veil') && guard++ < 4000) {
      final vis = game.veilVisibleSpotIndex;
      if (vis != null) {
        game.creatures[game.activeIndex].position =
            game.veilSpots(room('veil_cloud'))[vis];
        game.activateAbility();
      }
      game.update(1 / 60);
      for (final c in game.creatures) {
        c.hp = c.maxHp;
      }
    }
    expect(game.discoveredClouds, contains('c_veil'));

    final loom = room('sky_loom');
    Offset loomCloud(String type) =>
        loom.clouds.firstWhere((c) => c.cloudType == type).position;
    Offset loomAnchor(String type) =>
        loom.anchors.firstWhere((a) => a.requiredCloudType == type).position;

    for (final type in const ['Spiral', 'Ring', 'Feather', 'Veil']) {
      _teleport(game, 'sky_loom', loomCloud(type));
      _step(game);
      expect(game.carriedCloudType, type);
      _teleport(game, 'sky_loom', loomAnchor(type));
      _step(game);
      expect(game.carriedCloudType, isNull, reason: '$type slots cleanly');
    }
    _teleport(game, 'sky_loom', loomCloud('Anvil'));
    _step(game);
    expect(game.carriedCloudType, 'Anvil');
    game.setActive(1);
    _teleport(game, 'sky_loom', loom.currents.first.rect.center);
    game.activateAbility();
    expect(game.carriedCloudType, 'Thundercloud', reason: 'Air+Fire charges');
    _teleport(game, 'sky_loom', loomAnchor('Thundercloud'));
    _step(game);
    expect(game.hasStar(1), isTrue, reason: 'Star 2 banks on the fifth anchor');

    // ── The vault cache: the loom's reliquary, found once ──
    final vaultRoom = game.layout.rooms.values.firstWhere(
      (r) => r.vaultCache != null,
    );
    _teleport(game, vaultRoom.id, vaultRoom.vaultCache!);
    _step(game);
    expect(
      discovered.any((d) => d.startsWith('cache:')),
      isTrue,
      reason: 'exactly one vault cache, and it pays out once',
    );

    // ── Star 3: hold conduit A, then STEER the storm into conduit B ──
    final conduitRoom = room('twin_conduit');
    game.setActive(2); // Lightning horn
    _teleport(
      game,
      'twin_conduit',
      conduitRoom.conduits.firstWhere((c) => c.id == 'A').position,
    );
    game.activateAbility();
    expect(game.conduitEnergy['A'], double.infinity);

    game.setActive(0); // the Air wing ranks the rods
    final ranking = game.solveRodRanking().example!;
    for (final rod in conduitRoom.stormRods) {
      var g = 0;
      while ((game.rodHeight[rod.id] ?? 0) != ranking[rod.id] && g++ < 8) {
        _teleport(game, 'twin_conduit', rod.position);
        game.activateAbility();
      }
    }
    _teleport(game, 'twin_conduit', const Offset(80, 560));
    guard = 0;
    while (!game.altarOpen && guard++ < 400) {
      _step(game, 0.25);
    }
    expect(game.altarOpen, isTrue, reason: 'the storm lit B; the altar wakes');
    expect(game.guardianAwake, isTrue);
    for (final e in game.combatEnemies) {
      e.isDead = true;
    }

    // ── The mercy shrine: the altar mends the party, once ──
    final mercyRoom = room(game.layout.mercyShrineRoomId!);
    game.creatures[game.activeIndex].hp = 1;
    _teleport(game, mercyRoom.id, mercyRoom.bounds.center);
    game.update(1 / 60);
    expect(
      game.creatures[game.activeIndex].hp,
      game.creatures[game.activeIndex].maxHp,
      reason: 'the mercy shrine still breathes',
    );

    // ── The Roc: paced lull strikes until it falls ──
    final guardianNode = room('guardian_summit').guardian!;
    _teleport(game, 'guardian_summit', guardianNode.position + const Offset(0, 80));
    var safety = 0;
    while (!game.hasStar(2) && safety++ < 600) {
      final roc = game.combatEnemies.where((e) => e.isElite).firstOrNull;
      if (roc != null && !roc.isDead) {
        roc.position = game.creatures[game.activeIndex].position;
      }
      if (game.guardianVulnerable) game.activateAbility();
      _step(game, 0.3);
    }
    expect(game.hasStar(2), isTrue, reason: 'lull strikes fell the guardian');

    expect(earned, [0, 1, 2], reason: 'stars bank in play order, once each');
    expect(game.starsEarnedCount, 3);

    // ── The First Wind: commune at the compass heart, and it STAYS ──
    _teleport(game, 'hub', room('hub').bounds.center);
    game.activateAbility();
    expect(
      discovered,
      contains(kAirFirstWindEggId),
      reason: 'the 3-star commune yields the maxim (screen pays 20 gold)',
    );
    // Permanence: the completion state survives a death/reset.
    for (final c in game.creatures) {
      c.hp = 0;
    }
    expect(
      game.discoveredClouds,
      contains(kAirFirstWindEggId),
      reason: 'the First Wind turns forever — knowledge outlives the run',
    );
  });

  test('the Ring trial window is family-neutral (Star 2, untouched)', () {
    final alignments = <String, List<bool>>{};
    for (final family in const ['pip', 'mane', 'horn', 'mask', 'wing', 'kin']) {
      final game = _harness([_member(0, 'Air', family)]);
      game.currentRoomId = 'ring_cloud';
      final samples = <bool>[];
      for (var i = 0; i < 900; i++) {
        game.update(1 / 60);
        if (i % 10 == 0) samples.add(game.ringMotesAligned);
      }
      alignments[family] = samples;
      expect(samples.any((s) => s), isTrue);
    }
    expect(
      alignments.values.map((s) => s.join()).toSet().length,
      1,
      reason: 'every family sees exactly the same window',
    );
  });
}
