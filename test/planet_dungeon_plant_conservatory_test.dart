// VERDANTHOS — THE CONSERVATORY (docs/dungeons.md §9.20).
//
// The pure rules first — the recipes, the tendril's rule, the rite's root lattice —
// then the whole planet played through the engine: three wings and the
// cutscene's star, the trellis garden and its vault, the rite, Botanica's
// climate fight and the grey seed.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/shared/alchemon_combat_stats.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart'
    show CosmicSurvivalCompanion;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_plant.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _member(int i, String element, String family) =>
    CosmicPartyMember(
      instanceId: 'i$i',
      baseId: 'b$i',
      displayName: element,
      element: element,
      family: family,
      level: 10,
      statSpeed: 3,
      statIntelligence: 3,
      statStrength: 3,
      statBeauty: 3,
      slotIndex: i,
      staminaBars: 3,
      staminaMax: 3,
    );

PlanetDungeonGame _game({String crystalFamily = 'mask', int stars = 0}) {
  final party = [
    _member(0, 'Crystal', crystalFamily),
    _member(1, 'Spirit', 'kin'),
    _member(2, 'Water', 'mane'),
  ];
  final g = PlanetDungeonGame(
    element: 'Plant',
    party: party,
    initialStarMask: stars,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  g.starMask = stars;
  g.currentRoomId = g.layout.entranceRoomId;
  g.entryDoorRevealed = true;
  for (final m in party) {
    g.creatures.add(
      DungeonCreature(member: m)
        ..position = g.layout.entranceSpawn
        ..lastSafe = g.layout.entranceSpawn,
    );
  }
  return g;
}

/// onLoad never runs headless, so the fight's companions are made here, as
/// the raid test makes them.
void _arm(PlanetDungeonGame g) {
  for (final c in g.creatures) {
    final stats = deriveAlchemonCombatStats(member: c.member);
    g.combatCompanions.add(
      CosmicSurvivalCompanion(
        member: c.member,
        slotIndex: c.member.slotIndex,
        position: c.position,
        anchor: c.position,
        maxHp: stats.maxHp,
        currentHp: stats.maxHp,
        physAtk: stats.physAtk,
        elemAtk: stats.elemAtk,
        abilityAtk: stats.elemAtk,
        physDef: stats.physDef,
        elemDef: stats.elemDef,
        cooldownReduction: stats.cooldownReduction,
        attackRange: stats.attackRange,
        specialAbilityRange: stats.specialAbilityRange,
        tethered: false,
        invincibleTimer: 0,
      ),
    );
  }
}

/// Put [inRing] in the ring at [at], everyone else well away, and press with
/// the first of them.
void _tend(PlanetDungeonGame g, String room, Offset at, List<String> inRing) {
  g.currentRoomId = room;
  final park = g.layout.rooms[room]!.bounds.bottomRight - const Offset(40, 40);
  for (final c in g.creatures) {
    final i = inRing.indexOf(c.member.element);
    c.position = i < 0 ? park : at + Offset(-14.0 + 14 * i, 0);
  }
  g.activeIndex = g.creatures.indexWhere(
    (c) => c.member.element == inRing.first,
  );
  g.activateAbility();
}

void _run(PlanetDungeonGame g, double seconds) {
  for (var i = 0; i < (seconds * 60).round(); i++) {
    g.update(1 / 60);
  }
}

bool _doorShown(PlanetDungeonGame g, String from, String to) {
  final room = g.layout.rooms[from]!;
  return !g.isDoorHidden(
    room,
    room.doors.firstWhere((d) => d.targetRoomId == to),
  );
}

Offset _wingRing(String room) =>
    kPlanetDungeonLayouts['Plant']!.rooms[room]!.grove!.wing!.ring;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the rules', () {
    test('each climate has one fix, and extra bodies never spoil it', () {
      expect(tendMissing('Water', ['Water']), isEmpty);
      expect(tendMissing('Ice', ['Water']), ['Spirit']);
      expect(tendMissing('Ice', ['Water', 'Spirit', 'Crystal']), isEmpty);
      expect(tendMissing('Light', ['Crystal']), ['Spirit']);
      expect(tendMissing('Light', <String>[]), ['Spirit', 'Crystal']);
      // A creature that IS the product answers on its own.
      expect(tendMissing('Ice', ['Ice']), isEmpty);
      // The recipes are the game's own.
      expect(tendBraid('Water', 'Spirit'), 'Ice');
      expect(tendBraid('Spirit', 'Crystal'), 'Light');
      // A refusal names the climate, never the missing body.
      expect(tendMissingLine('Ice', ['Spirit']), isNot(contains('Spirit')));
    });

    test('no hint, primer or refusal gives a recipe away', () {
      // The most a line may say is the climate ("it may need light").
      final lines = [
        ...plantLayout.primer,
        ...plantLayout.riddle.skip(1),
        for (final p in ['Water', 'Ice', 'Light']) tendMissingLine(p, ['x']),
      ];
      final recipe = RegExp(
        r'(Water|Spirit|Crystal) and (Water|Spirit|Crystal)|'
        r'(make|makes|takes) (Ice|Light)',
      );
      for (final l in lines) {
        expect(recipe.hasMatch(l), isFalse, reason: l);
      }
    });

    test('the tendril: one fork, and every stop is visible', () {
      final s = TrellisState();
      var r = growTendril(s);
      expect(r.path, isEmpty);
      expect(r.stop, TendrilStop.dry);

      // The east lamp starts lit. Watered, it heads for the bud — and stops
      // at open water.
      expect(s.lit, TrellisLamp.east);
      s.watered = true;
      r = growTendril(s);
      expect(r.path.last, (5, 3));
      expect(r.stop, TendrilStop.water);

      // Freeze it and it reaches the bud.
      s.frozen = true;
      r = growTendril(s);
      expect(r.path.last, kTrellisIsland);
      expect(r.stop, TendrilStop.bud);

      // Light the west lamp instead and it goes to the short dead end: ice
      // cannot steer.
      s.lit = TrellisLamp.west;
      r = growTendril(s);
      expect(r.path, [kTrellisRoot, kTrellisFork, ...kTrellisWestBed]);
      expect(r.stop, TendrilStop.bedEnd);
    });

    test('the fork exits point straight at their lamps', () {
      final fork = trellisCellCentre(kTrellisFork);
      final west = trellisCellCentre(kTrellisWestBed.first);
      final east = trellisCellCentre(kTrellisEastBed.first);
      final wl = trellisCellCentre(kTrellisWestLamp);
      final el = trellisCellCentre(kTrellisEastLamp);
      expect(west.dy, fork.dy);
      expect(east.dy, fork.dy);
      expect(wl.dy, fork.dy);
      expect(el.dy, fork.dy);
      expect(west.dx < fork.dx && wl.dx < west.dx, isTrue);
      expect(east.dx > fork.dx && el.dx > east.dx, isTrue);
      expect(trellisIsPond(kTrellisPondCrossing), isTrue);
      expect(trellisIsPond(kTrellisIsland), isFalse);
    });

    test('the roots: water rises, frost crawls through wet, light climbs '
        'dry', () {
      final r = RootLattice();
      // Water rises from its tip to the knot, and only up its own root.
      r.apply('C', 'Water');
      expect(r.state['C'], RootState.wet);
      expect(r.state['A'], RootState.wet);
      expect(r.state['K'], RootState.wet);
      expect(r.state['D'], RootState.dry);
      expect(r.state['B'], RootState.dry);
      // Light climbs dry bark and stops at wet.
      r.apply('E', 'Light');
      expect(r.state['E'], RootState.lit);
      expect(r.state['B'], RootState.lit);
      expect(r.state['K'], RootState.wet);
      // Frost crawls through every connected wet bud — and no further.
      r.apply('C', 'Ice');
      expect(
        [r.state['C'], r.state['A'], r.state['K']],
        [RootState.frozen, RootState.frozen, RootState.frozen],
      );
      expect(r.state['B'], RootState.lit);
      // Light thaws the first frost it meets, and only that one.
      r.apply('C', 'Light');
      expect(r.state['C'], RootState.wet);
      expect(r.state['A'], RootState.frozen);
      // Ice is a dam: water stops below a frozen bud.
      r.apply('D', 'Water');
      expect(r.state['D'], RootState.wet);
      expect(r.state['A'], RootState.frozen);
      // Nothing that changes nothing: frost cannot take on a lit tip.
      expect(r.preview('E', 'Ice'), isEmpty);
    });

    test('the door wants three ideas, and pruning makes nothing a trap', () {
      // Exhaustive: every state reachable from bare roots, by any of the
      // twelve presses (four rings × three climates).
      String key(RootLattice l) =>
          kRootNodes.map((n) => l.state[n]!.index).join();
      RootLattice from(String k) => RootLattice()
        ..setAll({
          for (final (i, n) in kRootNodes.indexed)
            n: RootState.values[int.parse(k[i])],
        });
      final start = key(RootLattice());
      final dist = {start: 0};
      final queue = [start];
      while (queue.isNotEmpty) {
        final k = queue.removeAt(0);
        for (final tip in kRootTips) {
          for (final p in ['Water', 'Ice', 'Light']) {
            final l = from(k);
            if (l.apply(tip, p).isEmpty) continue;
            final nk = key(l);
            if (dist.containsKey(nk)) continue;
            dist[nk] = dist[k]! + 1;
            queue.add(nk);
          }
        }
      }
      final target = key(RootLattice()..setAll(kRootTarget));
      expect(dist[target], 7, reason: 'the crown takes seven presses at best');
      // PRUNE returns any state to bare, so the target is always reachable.
      expect(dist.containsKey(start), isTrue);
    });

    test('Plant is partied Crystal · Spirit · Water, and its gate fits it', () {
      expect(kCosmicPlanetEntry['Plant'], ['Crystal', 'Spirit', 'Water']);
      final ideal = kDungeonIdealFamilies['Plant']!;
      final gate = plantLayout.familyGateFor('root_light')!;
      final slot = kCosmicPlanetEntry['Plant']!.indexOf(gate.element);
      expect(ideal[slot], gate.family);
      expect(plantLayout.totalStars, 3);
    });
  });

  group('the planet, played', () {
    test('three wings bloom, the cut plays, and the north door opens', () {
      final g = _game();
      expect(_doorShown(g, 'conservatory', 'trellis_garden'), isFalse);

      // A wrong ring spends nothing.
      _tend(g, 'hothouse', _wingRing('hothouse'), ['Water']);
      expect(g.greenhouse.healed, isEmpty);

      _tend(g, 'dry_bed', _wingRing('dry_bed'), ['Water']);
      _tend(g, 'hothouse', _wingRing('hothouse'), ['Water', 'Spirit']);
      // A third body in the ring does not spoil the pair.
      _tend(g, 'shadehouse', _wingRing('shadehouse'), [
        'Spirit',
        'Crystal',
        'Water',
      ]);
      expect(g.greenhouse.wingsHealed, isTrue);
      expect(g.hasStar(0), isFalse);

      // The cut: to the hub, the bind banks the star, and the door is hidden
      // until the roots have it open.
      _run(g, 2.2); // the bloom plays in its wing first
      expect(g.followRoomId, 'conservatory');
      expect(g.hasStar(0), isFalse);
      _run(g, 2.4); // the motes fly in and bind
      expect(g.hasStar(0), isTrue);
      expect(_doorShown(g, 'conservatory', 'trellis_garden'), isFalse);
      _run(g, 2.8); // the plant rises and its roots prise the door
      expect(_doorShown(g, 'conservatory', 'trellis_garden'), isTrue);
      expect(g.followRoomId, 'trellis_garden');
      _run(g, 3.0);
      expect(g.followRoomId, isNull);
    });

    test('the trellis: the ghost, the vault under the dead end, the bud', () {
      final g = _game(stars: 1);
      final t = g.greenhouse.trellis;

      _tend(g, 'trellis_garden', kTrellisWaterRing.at, ['Water']);
      expect(t.watered, isTrue);

      // Light the WEST lamp and GROW: the dead end, and its stone comes up.
      _tend(g, 'trellis_garden', kTrellisWestLightRing.at, [
        'Crystal',
        'Spirit',
      ]);
      expect(t.lit, TrellisLamp.west);
      expect(_doorShown(g, 'trellis_garden', 'root_cellar'), isFalse);
      _tend(g, 'trellis_garden', kTrellisRootKnuckle, ['Water']);
      expect(g.greenhouse.grown, isTrue);
      _run(g, 2.0);
      expect(g.greenhouse.hatchOpen, isTrue);
      expect(_doorShown(g, 'trellis_garden', 'root_cellar'), isTrue);
      expect(g.hasStar(1), isFalse);

      // PULL is free, and keeps the water.
      _tend(g, 'trellis_garden', kTrellisRootKnuckle, ['Water']);
      expect(g.greenhouse.grown, isFalse);
      expect(t.watered, isTrue);
      _run(g, 1.0);

      // Freeze, light east (the lamps draw from each other), grow.
      _tend(g, 'trellis_garden', kTrellisIceRing.at, ['Spirit', 'Water']);
      expect(t.frozen, isTrue);
      _tend(g, 'trellis_garden', kTrellisEastLightRing.at, ['Crystal']);
      expect(t.lit, TrellisLamp.west); // Crystal alone makes no Light
      _tend(g, 'trellis_garden', kTrellisEastLightRing.at, [
        'Crystal',
        'Spirit',
      ]);
      expect(t.lit, TrellisLamp.east);
      _tend(g, 'trellis_garden', kTrellisRootKnuckle, ['Spirit']);
      // The tip arrives, coils, and the bud swells: no star yet, and the
      // shot is held on the island.
      _run(g, 2.2);
      expect(g.hasStar(1), isFalse);
      expect(g.followRoomId, 'trellis_garden');
      // It bursts: the star banks, but the way north waits for the pollen.
      _run(g, 1.0);
      expect(g.hasStar(1), isTrue);
      expect(_doorShown(g, 'trellis_garden', 'rootbound_door'), isFalse);
      // PULL does nothing mid-bloom.
      _tend(g, 'trellis_garden', kTrellisRootKnuckle, ['Spirit']);
      expect(g.greenhouse.grown, isTrue);
      _run(g, 2.4);
      expect(_doorShown(g, 'trellis_garden', 'rootbound_door'), isTrue);
      // The stone stays up.
      expect(_doorShown(g, 'trellis_garden', 'root_cellar'), isTrue);
    });

    test('the rite: the crown\'s pattern, the Mask gate, and the stump', () {
      Offset ring(String tip) => kRootRings[tip]!.at;
      final g = _game(stars: 3, crystalFamily: 'horn');
      _tend(g, 'rootbound_door', ring('E'), ['Spirit', 'Crystal']);
      expect(g.greenhouse.roots.bare, isTrue, reason: 'only a Mask focuses');
      expect(
        g.discoveredClouds,
        contains(plantLayout.familyGateFor('root_light')!.discoveryId),
      );

      final m = _game(stars: 3);
      final roots = m.greenhouse.roots;
      // A wrong start, then PRUNE: free, and back to bare.
      _tend(m, 'rootbound_door', ring('E'), ['Water']);
      expect(roots.bare, isFalse);
      _tend(m, 'rootbound_door', kRootStump, ['Water']);
      expect(roots.bare, isTrue);
      // All three in one ring is refused, not guessed at.
      _tend(m, 'rootbound_door', ring('C'), ['Spirit', 'Crystal', 'Water']);
      expect(roots.bare, isTrue);

      // The crown, in seven presses: wet a path to the knot, light the east
      // root while it is dry, freeze the wet path from below, then thaw back
      // down one bud per climb — and the frozen knot dams the last water.
      _tend(m, 'rootbound_door', ring('C'), ['Water']);
      _tend(m, 'rootbound_door', ring('E'), ['Spirit', 'Crystal']);
      _tend(m, 'rootbound_door', ring('F'), ['Spirit', 'Crystal']);
      _tend(m, 'rootbound_door', ring('C'), ['Water', 'Spirit']);
      _tend(m, 'rootbound_door', ring('C'), ['Spirit', 'Crystal']);
      _tend(m, 'rootbound_door', ring('D'), ['Spirit', 'Crystal']);
      expect(m.greenhouse.rootsOpen, isFalse);
      _tend(m, 'rootbound_door', ring('D'), ['Water']);
      expect(roots.matches, isTrue);
      expect(m.greenhouse.rootsOpen, isTrue);
      expect(m.conduitEnergy['A'], double.infinity);
      expect(m.conduitEnergy['B'], double.infinity);
      _run(m, 0.2);
      expect(m.guardianAwake, isTrue);
      expect(_doorShown(m, 'rootbound_door', 'botanica_heart'), isTrue);
    });

    test('Botanica wrecks the climate; fixing it opens the full lull', () {
      final g = _game(stars: 3);
      g.greenhouse.roots.setAll(kRootTarget);
      g.greenhouse.rootsOpen = true;
      g.conduitEnergy['A'] = double.infinity;
      g.conduitEnergy['B'] = double.infinity;
      g.currentRoomId = 'botanica_heart';
      final heart = g.layout.rooms['botanica_heart']!;
      final safe = heart.bounds.bottomLeft + const Offset(80, -80);
      for (final c in g.creatures) {
        c.position = safe;
      }
      _run(g, 6.0); // wake, land, and the first strike
      expect(g.guardianAwake, isTrue);
      final climate = g.greenhouse.arena;
      expect(climate, isNotNull);
      expect(g.guardianVulnerable, isFalse);
      // It holds: no reroll while the party is placed.
      _run(g, 4.0);
      expect(g.greenhouse.arena, climate);
      expect(g.guardianVulnerable, isFalse);

      final ring = heart.grove!.arenaRings.last;
      final need = kTendRecipes[climateFix(climate!)]!;
      _tend(g, 'botanica_heart', ring, need);
      expect(g.greenhouse.arena, isNull);
      _run(g, 1.2); // the restoration plays first
      expect(g.guardianVulnerable, isTrue);
      _run(g, 4.0);
      expect(g.guardianVulnerable, isTrue, reason: 'the lull runs in full');
      _run(g, 3.5);
      // A new strike, never the same climate twice running.
      expect(g.guardianVulnerable, isFalse);
      expect(g.greenhouse.arena, isNot(climate));
    });

    test('a body parked in an arena circle holds it through the fight', () {
      final g = _game(stars: 3);
      g.greenhouse.roots.setAll(kRootTarget);
      g.greenhouse.rootsOpen = true;
      g.conduitEnergy['A'] = double.infinity;
      g.conduitEnergy['B'] = double.infinity;
      g.currentRoomId = 'botanica_heart';
      final heart = g.layout.rooms['botanica_heart']!;
      final ring = heart.grove!.arenaRings.first;
      final spirit = g.creatures.firstWhere(
        (c) => c.member.element == 'Spirit',
      );
      final other = g.creatures.firstWhere(
        (c) => c.member.element == 'Crystal',
      );
      // Water is driven; Spirit is parked in the ring; Crystal stands free.
      g.activeIndex = g.creatures.indexWhere(
        (c) => c.member.element == 'Water',
      );
      final free = heart.bounds.bottomLeft + const Offset(120, -60);
      for (final c in g.creatures) {
        c.position = free;
      }
      spirit.position = ring;
      other.position = free + const Offset(60, 0);
      _arm(g);
      _run(g, 7.0); // wake, land, and the fight is on
      expect(g.guardianAwake, isTrue);
      expect(g.hasCombatTargets, isTrue);
      expect(spirit.position, ring, reason: 'the parked body stays put');
      expect(
        other.position,
        isNot(free + const Offset(60, 0)),
        reason: 'a free companion still joins the fight',
      );
    });

    test('the grey seed: three channels drawn back, and it blooms', () {
      final g = _game(stars: 3);
      final seed = kPlanetDungeonLayouts['Plant']!
          .rooms['conservatory']!
          .grove!
          .seedPlanter!;
      for (final e in ['Water', 'Water', 'Crystal', 'Spirit']) {
        _tend(g, 'conservatory', seed, [e]);
      }
      expect(g.greenhouse.drawn, SeedChannel.values.toSet());
      _run(g, 3.0); // the Rite of Three binds, and pays
      expect(g.discoveredClouds, contains(kPlantOppositeSeedEggId));
    });

    test('before the Bud Star there is no grey seed to draw from', () {
      final g = _game(stars: 1);
      final seed = kPlanetDungeonLayouts['Plant']!
          .rooms['conservatory']!
          .grove!
          .seedPlanter!;
      _tend(g, 'conservatory', seed, ['Water']);
      expect(g.greenhouse.drawn, isEmpty);
    });

    test('every room can be walked back out of (nothing strands)', () {
      final layout = kPlanetDungeonLayouts['Plant']!;
      for (final room in layout.rooms.values) {
        for (final d in room.doors) {
          final back = layout.rooms[d.targetRoomId]!;
          expect(
            back.doors.any((x) => x.targetRoomId == room.id),
            isTrue,
            reason: '${room.id} → ${d.targetRoomId} has no way back',
          );
          // Arrivals land inside the room and clear of every door there.
          expect(back.bounds.contains(d.targetSpawn), isTrue);
          for (final x in back.doors) {
            expect(
              x.rect.inflate(12).contains(d.targetSpawn),
              isFalse,
              reason: 'arriving in ${back.id} on its door to ${x.targetRoomId}',
            );
          }
        }
      }
    });

    test('later descents keep what was made (§5.7)', () {
      final g = _game(stars: 7);
      // onLoad never runs headless; reset as a run start does.
      g.debugResetPuzzleState();
      expect(g.greenhouse.wingsHealed, isTrue);
      expect(g.greenhouse.grown, isTrue);
      expect(g.greenhouse.roots.matches, isTrue);
      expect(g.greenhouse.rootsOpen, isTrue);
      expect(_doorShown(g, 'conservatory', 'trellis_garden'), isTrue);
    });
  });
}
