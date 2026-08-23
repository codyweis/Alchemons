// Focused per-mechanic tests of the Fire dungeon (Pyrathis — the Cinder
// Cathedral, FORENSIC RITE + ROUTE DECISION rework §6.1/§9.1 item 3): a
// headless Fire+Air+Plant trio plays the INTENDED solutions from a fresh save,
// and each rework mechanic gets its own guard:
//   • S1 the rite is ROLLED PER RUN, and every roll's planted evidence is
//     PROVABLY sufficient — the solver reconstructs exactly one order, over
//     many seeds, from the same testimony the braziers wear;
//   • S1 the deduction is possible with NO Mask in the party (the evidence is
//     on the iron, not behind an ability), and the three channels are each
//     partial — wax alone leaves eight candidates;
//   • S1 Mask insight ASSISTS and never answers (tier gating, one link);
//   • S1 the scriptorium mural CONFIRMS two non-adjacent positions, never the
//     order;
//   • S1 a wrong flame snuffs the rite + ash wisps, and re-lays the evidence;
//   • S2 THE WIND CARRIES THE REACTION — the grooves are rolled per run out of
//     a pool the solver has swept exhaustively (728 of 729 assignments are
//     solvable, 176 need the wind, 137 sit in the band); the rolled garth is
//     always solvable, always needs a turn of the vane, and is never
//     strandable; and the solver's own plan, played press for press, banks it;
//   • S3 both censer runs are genuinely viable, and the run commits when the
//     first censer takes flame;
//   • S3 Simurgh re-lights the rite braziers as its telegraph (raids exempt);
//   • the Ember Epitaph egg, the vault cache, and the guardian relic.

import 'dart:math' as math;

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
  double speed = 3,
}) {
  return CosmicPartyMember(
    instanceId: 'inst_$slot',
    baseId: 'base_$slot',
    displayName: '$element $family',
    element: element,
    family: family,
    level: 10,
    statSpeed: speed,
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
  void Function(int)? onStar,
  void Function(String)? onCloud,
}) {
  final game = PlanetDungeonGame(
    element: 'Fire',
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

DungeonRoom _room(PlanetDungeonGame g, String id) => g.layout.rooms[id]!;

/// Walk the rite in this run's rolled order (the ONLY way to bank Star 1).
void _performRite(PlanetDungeonGame game, {void Function()? between}) {
  final choir = _room(game, 'choir');
  game.setActive(0);
  for (var rank = 0; rank < choir.braziers.length; rank++) {
    final b = choir.braziers[game.riteBrazierAt(rank)];
    game.currentRoomId = 'choir';
    game.creatures[game.activeIndex]
      ..position = b.position
      ..lastSafe = b.position;
    game.activateAbility();
    between?.call();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── S1: the forensic rite ────────────────────────────────

  test(
    'the rolled rite is PROVABLY deducible: over many seeds, the planted '
    'evidence admits exactly ONE order — and it is the rolled one',
    () {
      // Each fresh game rolls its own rite. Sweep many of them: the solver
      // reads only the testimony the braziers actually wear, so this is the
      // §6.1 "consistent and sufficient" promise checked against gameplay.
      final seen = <String>{};
      for (var seed = 0; seed < 200; seed++) {
        final game = _harness([_member(0, 'Fire', 'mask')]);
        final result = game.solveRiteOrder();
        expect(
          result.satisfying,
          1,
          reason: 'roll #$seed left ambiguous evidence: '
              '${result.satisfying} orders fit ${game.riteOrder}',
        );
        expect(
          result.solution,
          game.riteOrder,
          reason: 'roll #$seed: the deduction must land on the rite that '
              'actually happened, not merely on something self-consistent',
        );
        expect(result.searched, greaterThan(0));
        seen.add(game.riteOrder.join(','));
      }
      // A per-run roll that always lands on the same order would be an
      // authored answer wearing a disguise.
      expect(
        seen.length,
        greaterThan(20),
        reason: 'the rite must genuinely vary run to run (a wiki can never '
            'spoil it); saw only ${seen.length} distinct orders',
      );
    },
  );

  test('the rite is deducible with NO Mask in the party — the evidence is on '
      'the iron, not behind an ability', () {
    // A party with no insight at all: the testimony is still planted and
    // still uniquely solvable, and the rite still banks by reasoning alone.
    final game = _harness([
      _member(0, 'Fire', 'horn'),
      _member(1, 'Air', 'wing'),
      _member(2, 'Plant', 'mane'),
    ]);
    expect(
      game.creatures.any((c) => c.member.family == 'mask'),
      isFalse,
      reason: 'this run must carry no Mask',
    );
    expect(game.choirRevealTier, -1, reason: 'nothing has been read');
    final solved = game.solveRiteOrder();
    expect(
      solved.satisfying,
      1,
      reason: 'the braziers alone must pin the rite down',
    );
    _performRite(game);
    expect(
      game.hasStar(0),
      isTrue,
      reason: 'a Mask-less party that reasons it out must bank the Ember Star',
    );
  });

  test('every evidence channel is partial: wax alone leaves eight candidates, '
      'and the ash drift is load-bearing', () {
    final game = _harness([_member(0, 'Fire', 'mask')]);
    final choir = _room(game, 'choir');
    final n = choir.braziers.length;

    // WAX: three tiers, two braziers each — coarse by construction, so it
    // narrows the rite to 2*2*2 = 8 orders and never hands it over.
    final byTier = <int, int>{};
    for (var i = 0; i < n; i++) {
      final t = game.testimonyFor(i)!;
      byTier[t.waxTier] = (byTier[t.waxTier] ?? 0) + 1;
    }
    expect(byTier.keys.toList()..sort(), [0, 1, 2]);
    expect(byTier.values.toSet(), {2},
        reason: 'two braziers must share every wax tier');
    // …and two braziers of one tier must be drawn IDENTICALLY, or the wax
    // height would leak the exact rank.
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        final a = game.testimonyFor(i)!;
        final b = game.testimonyFor(j)!;
        if (a.waxTier != b.waxTier) continue;
        expect(a.waxFill, b.waxFill,
            reason: 'braziers $i and $j share a tier and must look the same');
      }
    }
    // The tier ordering is the rite's own: earlier ranks stand in lower tiers.
    for (var rank = 0; rank < n; rank++) {
      expect(game.testimonyFor(game.riteBrazierAt(rank))!.waxTier, rank ~/ 2,
          reason: 'lowest wax burned longest');
    }

    // SOOT: exactly one even collar, and it is the fire lit FIRST.
    final collars = [
      for (var i = 0; i < n; i++)
        if (game.testimonyFor(i)!.sootLean == null) i,
    ];
    expect(collars, [game.riteBrazierAt(0)],
        reason: 'only the first fire had no burning neighbour to lean from');

    // ASH: one quantised compass direction, shared by the whole choir, and
    // genuinely constraining — dropping it must make the rite ambiguous far
    // more often than keeping it.
    expect(game.riteAshDrift, isNot(Offset.zero));
    expect(game.riteAshDrift.distance, closeTo(1.0, 1e-6),
        reason: 'the drift is a direction, not a bearing with magnitude');
    var ambiguousWithoutAsh = 0;
    for (var seed = 0; seed < 60; seed++) {
      final g = _harness([_member(0, 'Fire', 'mask')]);
      if (_solveIgnoringAsh(g) > 1) ambiguousWithoutAsh++;
    }
    expect(
      ambiguousWithoutAsh,
      greaterThan(20),
      reason: 'if the ash drift were decorative, removing it would barely '
          'change the count — it is a real third channel',
    );
  });

  test('the scriptorium mural CONFIRMS two non-adjacent positions and never '
      'the order', () {
    final game = _harness([_member(0, 'Fire', 'mask')]);
    final n = _room(game, 'choir').braziers.length;
    expect(game.riteMuralRanks.length, 2, reason: 'two of the six, no more');
    for (final r in game.riteMuralRanks) {
      expect(r, inInclusiveRange(0, n - 1));
    }
    expect(
      (game.riteMuralRanks[1] - game.riteMuralRanks[0]).abs(),
      greaterThanOrEqualTo(2),
      reason: 'two ADJACENT positions would hand over a step of the sequence',
    );
    // Even knowing both confirmed positions, the order is not given: the
    // remaining four fires still have to be reasoned out.
    expect(n - game.riteMuralRanks.length, 4);
  });

  test('Mask insight ASSISTS, it never answers: tier gating and one link', () {
    // Tier 0 (Intelligence 1) marks nothing beyond the evidence itself.
    final dim = _harness([_member(0, 'Fire', 'mask', intelligence: 1)]);
    dim.currentRoomId = 'choir';
    dim.creatures.single.position = _room(dim, 'choir').bounds.center;
    dim.activateAbility();
    expect(dim.revealTier, 0);
    expect(
      (dim.hintText ?? '').toLowerCase(),
      isNot(contains('draws itself')),
      reason: 'tier 0 gets no annotated link',
    );
    expect(dim.testimonyLinkRank, isNull);

    // Tier 2 (Intelligence 5) annotates exactly ONE link — and STICKS to it,
    // so re-reading can never walk the player through the whole rite.
    final bright = _harness([_member(0, 'Fire', 'mask', intelligence: 5)]);
    bright.currentRoomId = 'choir';
    bright.creatures.single.position = _room(bright, 'choir').bounds.center;
    bright.activateAbility();
    expect(bright.revealTier, 2);
    final firstLink = bright.testimonyLinkRank;
    expect(firstLink, isNotNull, reason: 'tier 2 draws one deduced link');
    for (var i = 0; i < 6; i++) {
      bright.activateAbility();
      expect(
        bright.testimonyLinkRank,
        firstLink,
        reason: 're-reading must not hand over link after link',
      );
    }
    // No tier ever speaks the order aloud.
    for (final tier in const [1.0, 3.0, 5.0]) {
      final g = _harness([_member(0, 'Fire', 'mask', intelligence: tier)]);
      g.currentRoomId = 'choir';
      g.creatures.single.position = _room(g, 'choir').bounds.center;
      g.activateAbility();
      final line = (g.hintText ?? '').toLowerCase();
      for (final word in const ['first', 'then', 'last', 'begins at']) {
        expect(line.contains('$word the '), isFalse,
            reason: 'insight must not recite the sequence: "${g.hintText}"');
      }
    }
  });

  test('a wrong flame snuffs the rite, rouses the ash, and LAYS THE EVIDENCE '
      'BACK DOWN', () {
    final game = _harness([_member(0, 'Fire', 'mask')]);
    final choir = _room(game, 'choir');
    game.currentRoomId = 'choir';
    // Light the first two fires correctly…
    for (var rank = 0; rank < 2; rank++) {
      final b = choir.braziers[game.riteBrazierAt(rank)];
      game.creatures.single
        ..position = b.position
        ..lastSafe = b.position;
      game.activateAbility();
    }
    expect(game.ritualProgress, 2);

    // …then take the LAST fire out of turn.
    final wrong = choir.braziers[game.riteBrazierAt(choir.braziers.length - 1)];
    game.creatures.single
      ..position = wrong.position
      ..lastSafe = wrong.position;
    game.activateAbility();
    expect(game.ritualProgress, 0, reason: 'a wrong flame snuffs the rite');
    expect(
      game.combatEnemies.where((e) => !e.isDead),
      isNotEmpty,
      reason: 'the snuffed rite spawns ash wisps',
    );
    // The evidence survives the mistake — the deduction still holds, and the
    // rite can be walked again from the top.
    expect(game.solveRiteOrder().satisfying, 1);
    for (final e in game.combatEnemies) {
      e.isDead = true;
    }
    _performRite(game);
    expect(game.hasStar(0), isTrue, reason: 'the second attempt must land');
  });

  test('the rite survives death: the cathedral remembers, so a deduction '
      'already made still holds', () {
    var wiped = false;
    final game = PlanetDungeonGame(
      element: 'Fire',
      party: [_member(0, 'Fire', 'mask')],
      initialStarMask: 0,
      onStarEarned: (_) {},
      onPlayerDown: () => wiped = true,
      onChanged: () {},
    );
    game.currentRoomId = 'choir';
    final c = DungeonCreature(member: game.party.first);
    game.creatures.add(c);
    final choir = _room(game, 'choir');
    final before = [...game.riteOrder];
    final drift = game.riteAshDrift;
    final mural = [...game.riteMuralRanks];

    // Walk two fires of the rite, then wipe — the real death path.
    for (var rank = 0; rank < 2; rank++) {
      final b = choir.braziers[game.riteBrazierAt(rank)];
      c
        ..position = b.position
        ..lastSafe = b.position;
      game.activateAbility();
    }
    expect(game.ritualProgress, 2);
    c.hp = 0;
    var guard = 0;
    while (!wiped && guard++ < 600) {
      game.update(1 / 60);
    }
    expect(wiped, isTrue, reason: 'the party must actually go down');
    expect(game.riteOrder, before,
        reason: 'death re-lays the fires, never the history');
    expect(game.riteAshDrift, drift);
    expect(game.riteMuralRanks, mural);
    expect(game.solveRiteOrder().satisfying, 1,
        reason: 'the evidence is intact, so the deduction still stands');
    expect(game.ritualProgress, 0, reason: 'the rite itself starts over');
    expect(game.vesperRouteId, isNull,
        reason: 'and Star 3\'s decision re-opens with it');
  });

  test('the braziers are element-only, and refuse anything but Fire', () {
    for (final family in const ['pip', 'mane', 'horn', 'mask', 'wing', 'kin']) {
      final game = _harness([_member(0, 'Fire', family)]);
      final choir = _room(game, 'choir');
      game.currentRoomId = 'choir';
      final first = choir.braziers[game.riteBrazierAt(0)];
      game.creatures.single
        ..position = first.position
        ..lastSafe = first.position;
      game.activateAbility();
      expect(game.ritualProgress, 1,
          reason: 'a Fire $family must light the rite just the same');
    }
    final cold = _harness([_member(0, 'Plant', 'mane')]);
    final choir = _room(cold, 'choir');
    cold.currentRoomId = 'choir';
    final first = choir.braziers[cold.riteBrazierAt(0)];
    cold.creatures.single
      ..position = first.position
      ..lastSafe = first.position;
    cold.activateAbility();
    expect(cold.ritualProgress, 0, reason: 'the braziers answer Fire alone');
  });

  // ── S3: the route decision ───────────────────────────────

  test('both censer runs are declared at their own stand, and they are not '
      'the same walk', () {
    final game = _harness([_member(0, 'Fire', 'mask')]);
    final gallery = _room(game, 'bell_gallery');
    expect(gallery.vesperRoutes.length, 2, reason: 'one decision, two answers');
    final nave = gallery.vesperRoutes.firstWhere((r) => r.id == 'route_nave');
    final cloister =
        gallery.vesperRoutes.firstWhere((r) => r.id == 'route_cloister');

    game.currentRoomId = 'bell_gallery';
    game.creatures.single.position = nave.standPosition;
    game.activateAbility();
    expect(game.vesperRouteId, 'route_nave');
    final naveChain = game.chainNodes(gallery.incenseChains.first);

    game.creatures.single.position = cloister.standPosition;
    game.activateAbility();
    expect(game.vesperRouteId, 'route_cloister',
        reason: 'the choice is free until the vesper begins');
    final cloisterChain = game.chainNodes(gallery.incenseChains.first);

    // The long run really is two extra censers per chain, and the short run
    // really does starve the flame faster.
    for (final chain in gallery.incenseChains) {
      final short = nave.chainNodes[chain.id] ?? chain.nodes;
      final long = cloister.chainNodes[chain.id] ?? chain.nodes;
      expect(long.length, short.length + 2,
          reason: '${chain.id}: the cloister is two censers longer');
    }
    expect(nave.flameLifeScale, lessThan(cloister.flameLifeScale));
    expect(nave.igniteWisps, greaterThan(cloister.igniteWisps));
    expect(nave.unstableWisps, isTrue);
    expect(cloister.unstableWisps, isFalse);
    expect(naveChain, isNot(cloisterChain));
    // The bells never move — only the way to them does.
    for (final chain in gallery.incenseChains) {
      final long = cloister.chainNodes[chain.id]!;
      expect(long.first, chain.nodes.first,
          reason: 'both runs start at the same censer');
    }
  });

  test('BOTH routes are genuinely viable: at a brisk pace AND at a harried '
      'one, each rings all three bells', () {
    final gusts = <String, int>{};
    for (final routeId in const ['route_nave', 'route_cloister']) {
      // ~0.4s between acts (unhurried) and ~1.0s (fighting through the ash).
      for (final frames in const [24, 60]) {
        final run = _runVesper(routeId, tendFrames: frames);
        expect(run.tolls, 3,
            reason: '$routeId must reach three tolls at ${frames}f');
        expect(run.awake, isTrue);
        if (frames == 24) gusts[routeId] = run.gusts;
      }
    }
    // Neither run is a formality: both cost real gusts, and the long way round
    // costs MORE of them (two extra censers per chain to keep alight).
    for (final id in gusts.keys) {
      expect(gusts[id], greaterThan(3), reason: '$id must be tended, not won');
    }
    expect(gusts['route_cloister'], greaterThanOrEqualTo(gusts['route_nave']!),
        reason: 'the cloister is the longer walk: $gusts');
  });

  test('the trade is structural: one gust clears any cloister gap, no gust '
      'clears a nave gap, and the nave\'s flame holds for far less', () {
    // THE TUNING, measured against the real relay rather than asserted.
    final probe = _harness([
      _member(0, 'Fire', 'mask'),
      _member(1, 'Air', 'wing'),
    ]);
    probe.starMask = (1 << 0) | (1 << 1);
    final gallery = _room(probe, 'bell_gallery');
    final nave = gallery.vesperRoutes.firstWhere((r) => r.id == 'route_nave');
    final cloister =
        gallery.vesperRoutes.firstWhere((r) => r.id == 'route_cloister');

    // Fuse length: the nave gives roughly half the seconds per feeding.
    expect(nave.flameLifeScale, lessThan(cloister.flameLifeScale * 0.7),
        reason: 'the ash-storm run must genuinely starve the flame faster');

    // Gap length: a single gust (Speed 3 → 155px) carries the flame clean onto
    // the next cloister censer, but strands it mid-air over the nave.
    for (final routeId in const ['route_nave', 'route_cloister']) {
      final game = _harness([
        _member(0, 'Fire', 'mask'),
        _member(1, 'Air', 'wing'),
      ]);
      game.starMask = (1 << 0) | (1 << 1);
      final g = _room(game, 'bell_gallery');
      final route = g.vesperRoutes.firstWhere((r) => r.id == routeId);
      game.currentRoomId = 'bell_gallery';
      _place(game, route.standPosition);
      game.setActive(0);
      game.activateAbility();
      final chain = g.incenseChains.first;
      _place(game, game.chainIgnitionPoint(chain));
      game.activateAbility();
      final nodes = game.chainNodes(chain);
      game.setActive(1);
      _place(game, game.vesperFlamePosition(chain.id)!);
      game.activateAbility();
      // Did one gust reach the next censer? (The checkpoint only advances
      // when the flame actually crosses one.)
      final reached = game.chainIgnitionPoint(chain) != nodes.first;
      if (routeId == 'route_cloister') {
        expect(reached, isTrue,
            reason: 'a cloister gap is one comfortable gust');
      } else {
        expect(reached, isFalse,
            reason: 'a nave gap strands the flame — it must survive the walk '
                'to a second gust, on a fuse half as long');
      }
    }
  });

  test('the run COMMITS when the first censer takes flame', () {
    final game = _harness([_member(0, 'Fire', 'mask')]);
    game.starMask = (1 << 0) | (1 << 1);
    final gallery = _room(game, 'bell_gallery');
    final nave = gallery.vesperRoutes.firstWhere((r) => r.id == 'route_nave');
    final cloister =
        gallery.vesperRoutes.firstWhere((r) => r.id == 'route_cloister');
    game.currentRoomId = 'bell_gallery';

    _place(game, nave.standPosition);
    game.activateAbility();
    expect(game.vesperCommitted, isFalse, reason: 'nothing burns yet');

    // Light the vesper — the decision is now made.
    _place(game, game.chainIgnitionPoint(gallery.incenseChains.first));
    game.activateAbility();
    expect(game.vesperCommitted, isTrue);
    _place(game, cloister.standPosition);
    game.activateAbility();
    expect(game.vesperRouteId, 'route_nave',
        reason: 'the vesper has begun — this run is committed');
  });

  test('the vesper refuses flame before Ember and Ash are banked, and before '
      'a run is declared', () {
    final locked = _harness([_member(0, 'Fire', 'mask')]);
    final gallery = _room(locked, 'bell_gallery');
    final chain = gallery.incenseChains.first;
    locked.currentRoomId = 'bell_gallery';
    _place(locked, locked.chainIgnitionPoint(chain));
    locked.activateAbility();
    expect(locked.vesperFlamePosition(chain.id), isNull,
        reason: 'the vesper waits on the Ember and Ash stars');

    final undeclared = _harness([_member(0, 'Fire', 'mask')]);
    undeclared.starMask = (1 << 0) | (1 << 1);
    undeclared.currentRoomId = 'bell_gallery';
    _place(undeclared, undeclared.chainIgnitionPoint(chain));
    undeclared.activateAbility();
    expect(undeclared.vesperFlamePosition(chain.id), isNull,
        reason: 'no run declared — the censers hang idle');
  });

  test('the vesper gust stays element-only: every Air family carries the '
      'flame the same distance', () {
    final landings = <String, Offset>{};
    for (final family in const ['pip', 'mane', 'horn', 'mask', 'wing', 'kin']) {
      final game = _harness([
        _member(0, 'Fire', 'mask'),
        _member(1, 'Air', family),
      ]);
      game.starMask = (1 << 0) | (1 << 1);
      final gallery = _room(game, 'bell_gallery');
      final chain = gallery.incenseChains.first;
      game.currentRoomId = 'bell_gallery';
      _place(game, gallery.vesperRoutes.first.standPosition);
      game.setActive(0);
      game.activateAbility();
      _place(game, game.chainIgnitionPoint(chain));
      game.activateAbility();
      final before = game.vesperFlamePosition(chain.id);
      expect(before, isNotNull, reason: 'Fire must light the chain first');
      game.setActive(1);
      game.creatures[1]
        ..position = before!
        ..lastSafe = before;
      game.activateAbility();
      final after = game.vesperFlamePosition(chain.id);
      expect(after, isNotNull);
      expect(after, isNot(before), reason: 'an Air $family must move the flame');
      landings[family] = after!;
    }
    expect(landings.values.toSet().length, 1,
        reason: 'no Air family gusts further than another: $landings');
  });

  test('an ungusted flame starves and its ash rises in fury', () {
    final game = _harness([_member(0, 'Fire', 'mask')]);
    game.starMask = (1 << 0) | (1 << 1);
    final gallery = _room(game, 'bell_gallery');
    final chain = gallery.incenseChains.first;
    game.currentRoomId = 'bell_gallery';
    _place(game, gallery.vesperRoutes.first.standPosition);
    game.activateAbility();
    _place(game, game.chainIgnitionPoint(chain));
    game.activateAbility();
    expect(game.vesperFlamePosition(chain.id), isNotNull);
    expect(game.combatEnemies.where((e) => !e.isDead), isNotEmpty,
        reason: 'lighting a censer rouses ash wisps at once');
    for (final e in game.combatEnemies) {
      e.isDead = true;
    }
    var guard = 0;
    while (game.vesperFlamePosition(chain.id) != null && guard++ < 600) {
      game.update(1 / 60);
      for (final c in game.creatures) {
        c.hp = c.maxHp;
      }
    }
    expect(game.vesperFlamePosition(chain.id), isNull,
        reason: 'an ungusted flame starves between censers');
    expect(game.combatEnemies.where((e) => !e.isDead), isNotEmpty,
        reason: 'a dead flame spawns a fury wave');
  });

  // ── S2: the ash garden — THE WIND CARRIES THE REACTION ───

  test(
    'the rolled garth is PROVABLY solvable, ALWAYS needs the wind, and lands '
    'inside the difficulty band',
    () {
      // Each fresh descent rolls its own grooves. Sweep many of them: the
      // solver walks the same grow/burn/turn rules the player presses, so this
      // is a promise about gameplay and not about a model of it.
      final seen = <String>{};
      for (var seed = 0; seed < 120; seed++) {
        final game = _harness([_member(0, 'Fire', 'mask')]);
        expect(game.gardenDemands.length, 6,
            reason: 'roll #$seed left the garth uncut');
        final solved = game.solveAshGarden();
        expect(solved.plan, isNotNull,
            reason: 'roll #$seed is unsolvable: ${game.gardenDemands}');
        expect(solved.minActions, inInclusiveRange(8, 12),
            reason: 'roll #$seed sits outside the band: ${solved.minActions} '
                'moves for ${game.gardenDemands}');
        // THE WIND IS LOAD-BEARING, every single run: nail the vane down and
        // the garth cannot be finished from ANY quarter.
        for (var w = 0; w < 4; w++) {
          expect(
            game.solveAshGarden(wind: w, allowWindTurns: false).plan,
            isNull,
            reason: 'roll #$seed could be done without the wind, from '
                'quarter $w: ${game.gardenDemands}',
          );
        }
        seen.add(game.gardenDemands.map((d) => d.name).join(','));
      }
      expect(seen.length, greaterThan(20),
          reason: 'the roll must give real variety, not one garth in a hat: '
              '${seen.length} distinct');
    },
  );

  test(
    'the exhaustive sweep: of all 729 groove assignments exactly ONE is '
    'impossible, and 176 cannot be done without turning the wind',
    () {
      final game = _harness([_member(0, 'Fire', 'mask')]);
      final rules = game.ashGardenRules!;
      expect(rules.bedCount, 6);
      expect(rules.boardCount, 15625, reason: '5 states per bed, six beds');
      final analysis = rules.analyse(0);
      expect(analysis.states, 62500, reason: 'board × the four quarters');
      expect(analysis.reachable, 53252,
          reason: 'the empty garth reaches this much of its own state graph');
      // 3^6 assignments; every one but the all-drift garth can be made true.
      expect(analysis.minActions.length, 728);
      final impossible = [
        for (var k = 0; k < 729; k++)
          if (!analysis.minActions.containsKey(k)) rules.demandsOf(k),
      ];
      expect(impossible, hasLength(1));
      expect(
        impossible.single,
        List.filled(6, GrooveDemand.ash),
        reason: 'the ONE dead garth is all-drift — every groove wants ash, so '
            'nothing is left to burn and feed the last one',
      );
      final needWind = analysis.minActions.keys
          .where((k) => !analysis.noTurnSolvable.contains(k))
          .toList();
      expect(needWind.length, 176);
      final inBand = needWind
          .where((k) =>
              analysis.minActions[k]! >= 8 && analysis.minActions[k]! <= 12)
          .length;
      expect(inBand, 137, reason: 'the pool the roll actually draws from');
    },
  );

  test(
    'NO SOFTLOCK, structurally: from every state the garth can reach, a '
    'solution still remains',
    () {
      // Air\'s `strandable == 0` proof, applied to the garden. Growing is legal
      // on any bed that is not already green, so a fouled garth is a detour
      // and never a wall — asserted exhaustively, not argued.
      final game = _harness([_member(0, 'Fire', 'mask')]);
      expect(game.ashGardenStrandable(), 0,
          reason: 'this run\'s garth: ${game.gardenDemands}');
      // …and for the authored extremes, including the ones a careless player
      // is likeliest to wreck.
      const cases = <List<GrooveDemand>>[
        [
          GrooveDemand.scorch, GrooveDemand.scorch, GrooveDemand.scorch,
          GrooveDemand.scorch, GrooveDemand.scorch, GrooveDemand.scorch,
        ],
        [
          GrooveDemand.clean, GrooveDemand.clean, GrooveDemand.clean,
          GrooveDemand.clean, GrooveDemand.clean, GrooveDemand.clean,
        ],
        [
          GrooveDemand.ash, GrooveDemand.clean, GrooveDemand.scorch,
          GrooveDemand.scorch, GrooveDemand.ash, GrooveDemand.clean,
        ],
      ];
      for (final demands in cases) {
        expect(game.ashGardenStrandable(demands: demands), 0,
            reason: 'stranded somewhere in $demands');
      }
    },
  );

  test(
    'the solver\'s plan is the GAME\'S plan: playing it move for move banks '
    'the Ash Star',
    () {
      for (var seed = 0; seed < 12; seed++) {
        final game = _harness([
          _member(0, 'Fire', 'mask'),
          _member(1, 'Air', 'wing'),
          _member(2, 'Plant', 'mane'),
        ]);
        final moves = _playGardenPlan(game);
        expect(game.hasStar(1), isTrue,
            reason: 'roll #$seed: $moves moves left the garth unfinished — '
                '${game.gardenDemands}');
      }
    },
  );

  test(
    'a burn brands its own bed and throws the reaction DOWNWIND — onto the '
    'beds the forecast already named',
    () {
      final game = _harness([
        _member(0, 'Fire', 'mask'),
        _member(1, 'Air', 'wing'),
        _member(2, 'Plant', 'mane'),
      ]);
      game.currentRoomId = 'cloister';
      _turnWindTo(game, 1); // east: the three-bed lane
      expect(game.plumeTargetsAt(0), [1, 2],
          reason: 'the forecast names the whole lane downwind, nearest first');
      _growBed(game, 0);
      // The forecast the player reads BEFORE committing is the same list the
      // burn consumes.
      final forecast = game.plumeTargetsAt(0);
      _burnBed(game, 0);
      expect(game.bedStateAt(0), AshBedState.scorch);
      for (final t in forecast) {
        expect(game.bedStateAt(t), AshBedState.ash,
            reason: 'bed $t stood downwind and must have caught the drift');
      }
      for (final untouched in const [3, 4, 5]) {
        expect(game.bedStateAt(untouched), AshBedState.barren,
            reason: 'the south lane is out of this wind entirely');
      }
      // Turn a quarter and the same bed throws its ash somewhere else.
      _turnWindTo(game, 2); // south
      expect(game.plumeTargetsAt(0), [3]);
    },
  );

  test('ash fouls a standing brand — and growing the bed again buries the '
      'ruin', () {
    final game = _harness([
      _member(0, 'Fire', 'mask'),
      _member(1, 'Air', 'wing'),
      _member(2, 'Plant', 'mane'),
    ]);
    game.currentRoomId = 'cloister';
    _turnWindTo(game, 1); // east
    // Brand the far bed first, then burn one upwind of it: the drift lands on
    // a brand, and spoils it.
    _growBed(game, 2);
    _burnBed(game, 2);
    expect(game.bedStateAt(2), AshBedState.scorch);
    _growBed(game, 0);
    _burnBed(game, 0);
    expect(game.bedStateAt(1), AshBedState.ash);
    expect(game.bedStateAt(2), AshBedState.spoiled,
        reason: 'ash over a brand answers no groove at all');
    expect(game.ashGardenRules!.satisfies(AshBedState.spoiled), isNull);
    // RECOVERY: the regrowth buries it, and the bed is a clean slate again.
    _growBed(game, 2);
    expect(game.bedStateAt(2), AshBedState.green);
    _burnBed(game, 2);
    expect(game.bedStateAt(2), AshBedState.scorch,
        reason: 'nothing about a spoiled bed is permanent');
  });

  test('the wind-cross is element-only: every Air family turns it the same '
      'quarter, and no one else turns it at all', () {
    final quarters = <String, int>{};
    for (final family in const ['pip', 'mane', 'horn', 'mask', 'wing', 'kin']) {
      final game = _harness([_member(0, 'Air', family)]);
      final vane = _room(game, 'cloister').windVane!;
      game.currentRoomId = 'cloister';
      final before = game.gardenWind;
      _place(game, vane);
      game.activateAbility();
      expect(game.gardenWind, (before + 1) % 4,
          reason: 'an Air $family must swing the cross one quarter');
      quarters[family] = (game.gardenWind - before) % 4;
      expect(game.combatEnemies.where((e) => !e.isDead), isEmpty,
          reason: 'an Air $family turns it CLEAN — no off-family racket');
    }
    expect(quarters.values.toSet(), {1},
        reason: 'no Air family turns further than another: $quarters');
    // Fire and Plant are refused with one clause, and change nothing.
    for (final element in const ['Fire', 'Plant']) {
      final game = _harness([_member(0, element, 'mane')]);
      final vane = _room(game, 'cloister').windVane!;
      game.currentRoomId = 'cloister';
      final before = game.gardenWind;
      _place(game, vane);
      game.activateAbility();
      expect(game.gardenWind, before, reason: '$element must not turn it');
      expect(game.hintText, contains('Air'));
    }
  });

  test('young shoots will not catch: a bed must TAKE before it burns', () {
    final game = _harness([
      _member(0, 'Fire', 'mask'),
      _member(1, 'Air', 'wing'),
      _member(2, 'Plant', 'mane'),
    ]);
    final beds = _room(game, 'cloister').vineBeds;
    game.currentRoomId = 'cloister';
    game.setActive(2);
    _placeActive(game, beds[0].position);
    game.activateAbility();
    expect(game.bedStateAt(0), AshBedState.green);
    expect(game.bedGrowthAt(0), lessThan(1.0));
    game.setActive(0);
    _placeActive(game, beds[0].position);
    game.activateAbility();
    expect(game.bedStateAt(0), AshBedState.green,
        reason: 'a bed just planted must refuse the flame');
    expect(game.hintText, contains('green'));
    // Give the shoots their time, and the same press works.
    for (var i = 0; i < 120; i++) {
      game.update(1 / 60);
    }
    expect(game.bedGrowthAt(0), 1.0);
    _placeActive(game, beds[0].position);
    game.activateAbility();
    expect(game.bedStateAt(0), AshBedState.scorch);
  });

  test('every burn breathes cinders, and the garth grows angrier as it '
      'settles', () {
    final game = _harness([
      _member(0, 'Fire', 'mask'),
      _member(1, 'Air', 'wing'),
      _member(2, 'Plant', 'mane'),
    ]);
    game.currentRoomId = 'cloister';
    _growBed(game, 0);
    _burnBed(game, 0);
    expect(game.combatEnemies.where((e) => !e.isDead), isNotEmpty,
        reason: 'a burning bed rouses the cinders at once');
    // Growing is the quiet verb — the ash sleeps through it.
    for (final e in game.combatEnemies) {
      e.isDead = true;
    }
    _growBed(game, 4);
    expect(game.combatEnemies.where((e) => !e.isDead), isEmpty,
        reason: 'growth is clean; only fire wakes the garth');
  });

  test('Mask insight assists the garth and never plans it', () {
    // t0/t1 teach the reading; only t2 draws a single source→groove link, and
    // it is STICKY — re-reading never walks the plan out one burn at a time.
    // A corner of the garth, clear of every bed and of the wind-cross.
    const readingSpot = Offset(60, 370);
    final dim = _harness([_member(0, 'Fire', 'mask', intelligence: 1)]);
    dim.currentRoomId = 'cloister';
    _place(dim, readingSpot);
    dim.activateAbility();
    expect(dim.revealTier, 0);
    expect(dim.gardenInsightLink, isNull,
        reason: 'a dim reading names the shapes, never a link');

    final sharp = _harness([_member(0, 'Fire', 'mask', intelligence: 5)]);
    sharp.currentRoomId = 'cloister';
    _place(sharp, readingSpot);
    sharp.activateAbility();
    expect(sharp.revealTier, 2);
    final link = sharp.gardenInsightLink;
    expect(link, isNotNull, reason: 'a sharp reading draws ONE link');
    expect(sharp.grooveDemandAt(link!.groove), GrooveDemand.ash,
        reason: 'the link always ends on a groove that wants the drift');
    expect(
      (sharp.hintText ?? '').toLowerCase(),
      isNot(contains('then')),
      reason: 'insight never recites a sequence',
    );
    for (var i = 0; i < 5; i++) {
      sharp.activateAbility();
      expect(sharp.gardenInsightLink, link,
          reason: 'the link is sticky — insight assists once, it does not '
              'recite the plan');
    }
  });

  // ── §7: Simurgh's brazier telegraph ──────────────────────

  test('Simurgh re-lights the rite braziers as its telegraph — in THIS run\'s '
      'order, only while it strikes', () {
    final game = _harness([_member(0, 'Fire', 'mask')]);
    game.starMask = (1 << 0) | (1 << 1);
    final sanctum = _room(game, 'sanctum');
    final choir = _room(game, 'choir');
    final spots = game.simurghTelegraphSpots(sanctum);
    expect(spots.length, choir.braziers.length,
        reason: 'the arena wears the choir\'s own arrangement');
    for (final p in spots) {
      expect(sanctum.bounds.contains(p), isTrue,
          reason: 'a phantom brazier must stand inside the roost');
    }
    // The pattern is the RITE, not the layout order: the ring is walked by
    // rank, so the spots light in riteOrder.
    expect(game.simurghPillars, isEmpty, reason: 'nothing burns before it wakes');

    game.guardianAwake = true;
    game.currentRoomId = 'sanctum';
    game.creatures.single
      ..position = sanctum.bounds.topLeft + const Offset(60, 60)
      ..lastSafe = sanctum.bounds.topLeft + const Offset(60, 60);
    final ranksSeen = <int>[];
    var guard = 0;
    while (ranksSeen.length < 3 && guard++ < 2000) {
      game.update(1 / 60);
      for (final c in game.creatures) {
        c.hp = c.maxHp;
      }
      for (final rank in game.simurghPillars.keys) {
        if (!ranksSeen.contains(rank)) ranksSeen.add(rank);
      }
    }
    expect(ranksSeen.length, greaterThanOrEqualTo(3),
        reason: 'the guardian must actually walk the rite');
    // Ranks arrive in sequence, from the top of the rite.
    expect(ranksSeen.take(3).toList(), [0, 1, 2],
        reason: 'the ORDER is the bullet pattern: $ranksSeen');
  });

  test('the telegraph runs in a raid — the arena carries its own braziers',
      () {
    final game = PlanetDungeonGame(
      element: 'Fire',
      party: [_member(0, 'Fire', 'mask')],
      initialStarMask: 0,
      onStarEarned: (_) {},
      onPlayerDown: () {},
      onChanged: () {},
      raid: const RaidConfig(),
      layoutOverride: buildRaidArenaLayout('Fire'),
    );
    expect(game.isRaid, isTrue);
    game.currentRoomId = game.layout.entranceRoomId;
    final c = DungeonCreature(member: game.party.first)
      ..position = game.layout.entranceSpawn
      ..lastSafe = game.layout.entranceSpawn;
    game.creatures.add(c);
    for (var i = 0; i < 400; i++) {
      game.update(1 / 60);
      c.hp = c.maxHp;
    }
    // This used to assert the opposite. The telegraph was exempt because the
    // generated arena had no braziers, which left Simurgh — and every other
    // guardian — playing as a plain charging phantom. The arena now generates
    // the furniture its own mechanic reads.
    expect(
      game.simurghTelegraphSpots(game.currentRoom),
      isNotEmpty,
      reason: 'the raid arena should carry braziers for the telegraph',
    );
    // The braziers are here for the telegraph only; a raid has no rite to
    // solve, so the lighting puzzle stays switched off.
    expect(game.currentRoom.brazierStarIndex, isNull);
  });

  // ── The full run: every star, the egg, the cache, the relic ──

  test('the authored trio can earn all three Fire stars end-to-end', () {
    final earned = <int>[];
    final discovered = <String>[];
    final party = [
      _member(0, 'Fire', 'mask'),
      _member(1, 'Air', 'wing'),
      _member(2, 'Plant', 'mane'),
    ];
    final game = _harness(party, onStar: earned.add, onCloud: discovered.add);

    void step([double seconds = 0.1]) {
      var t = 0.0;
      while (t < seconds) {
        game.update(1 / 60);
        t += 1 / 60;
      }
      // The sim verifies puzzle flow, not survival.
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

    // ── Entry: Fire rekindles the cold narthex hearth ──
    game.setActive(0);
    final hearth = _room(game, 'narthex').braziers.single;
    teleport('narthex', hearth.position);
    game.activateAbility();
    step();
    expect(game.entryDoorRevealed, isTrue, reason: 'flame wakes the way in');
    expect(discovered, contains(PlanetDungeonGame.entryDoorDiscoveryId));

    // ── The Lost Maxim: the Ember Epitaph — still WORDLESS ──
    expect(game.epitaphStage, 0, reason: 'the egg starts invisible');
    game.setActive(0); // Fire MASK — insight writes the mural's dead words
    teleport('scriptorium', _room(game, 'scriptorium').bounds.center);
    game.activateAbility();
    expect(game.epitaphStage, 1, reason: 'insight starts the floor-script');
    expect(game.choirRevealTier, greaterThanOrEqualTo(0),
        reason: 'and the mural\'s two confirmations come with it');
    game.setActive(2); // Plant
    teleport('scriptorium', kEmberEpitaphPlanter);
    game.activateAbility();
    expect(game.epitaphStage, 1,
        reason: 'the garden only settles once the writing completes');
    step(4.6); // let the ember-quill finish the three lines
    teleport('scriptorium', kEmberEpitaphPlanter);
    game.activateAbility();
    expect(game.epitaphStage, 2, reason: 'shoots take to the planter');
    game.setActive(0);
    teleport('scriptorium', kEmberEpitaphPlanter);
    game.activateAbility();
    expect(game.epitaphStage, 3, reason: 'the shoots catch');
    game.setActive(1); // Air, fanning the blaze
    for (var i = 0; i < 3; i++) {
      teleport('scriptorium', kEmberEpitaphPlanter);
      game.activateAbility();
    }
    expect(discovered, contains(kFireEpitaphEggId),
        reason: 'three gusts blaze the maxim (the screen pays the 20 gold)');

    // ── The chancel gate is sealed until both stars bank ──
    final nave = _room(game, 'nave');
    final chancel = nave.doors.firstWhere((d) => d.targetRoomId == 'vestry');
    expect(game.isDoorLocked(nave, chancel), isTrue);

    // ── Star 1: the rite, walked in this run's rolled order ──
    _performRite(game, between: step);
    expect(game.hasStar(0), isTrue, reason: 'the full sequence banks Star 1');
    clearWisps();

    // ── Star 2: read the garth, choose a wind, and work the beds in order ──
    // The trio plans it the way a player must: the wind has to be turned at
    // least once, and every burn's ash has to land where a groove wants it.
    expect(game.gardenGroovesTrue, lessThan(6),
        reason: 'the garth starts unfinished');
    final gardenMoves = _playGardenPlan(game, between: step);
    expect(gardenMoves, inInclusiveRange(8, 12));
    expect(game.hasStar(1), isTrue,
        reason: 'six grooves sitting true at once bank Star 2');
    expect(game.gardenGroovesTrue, 6);
    expect(game.guardianRiteUnlocked, isTrue);
    expect(game.isDoorLocked(nave, chancel), isFalse,
        reason: 'Ember and Ash part the chancel gate');
    clearWisps();

    // ── The reliquary cache ──
    final reliquary = _room(game, 'reliquary');
    game.setActive(0);
    teleport('reliquary', reliquary.vaultCache!);
    step();
    expect(discovered.any((d) => d.startsWith('cache:')), isTrue,
        reason: 'the reliquary keeps the planet\'s one vault cache');

    // ── Star 3: declare a run, then ring all three bells ──
    final gallery = _room(game, 'bell_gallery');
    game.setActive(0);
    teleport('bell_gallery', gallery.vesperRoutes.last.standPosition);
    game.activateAbility();
    expect(game.vesperRouteId, isNotNull, reason: 'a run must be declared');
    clearWisps();

    for (final chain in gallery.incenseChains) {
      var guard = 0;
      while (!game.bellsRung.contains(chain.id) && guard++ < 900) {
        final flamePos = game.vesperFlamePosition(chain.id);
        if (flamePos == null) {
          game.setActive(0);
          teleport('bell_gallery', game.chainIgnitionPoint(chain));
        } else {
          game.setActive(1);
          teleport('bell_gallery', flamePos);
        }
        game.activateAbility();
        game.update(1 / 60);
        for (final c in game.creatures) {
          c.hp = c.maxHp;
        }
      }
      expect(game.bellsRung, contains(chain.id),
          reason: 'ignite + gusts ring ${chain.id}');
    }
    expect(game.guardianAwake, isTrue, reason: 'three tolls wake the Simurgh');
    clearWisps();

    // ── The Simurgh: paced lull strikes until it yields ──
    game.setActive(0);
    final guardianNode = _room(game, 'sanctum').guardian!;
    teleport('sanctum', guardianNode.position + const Offset(0, 80));
    var safety = 0;
    while (!game.hasStar(2) && safety++ < 900) {
      final simurgh = game.combatEnemies.where((e) => e.isElite).firstOrNull;
      if (simurgh != null && !simurgh.isDead) {
        simurgh.position = game.creatures[game.activeIndex].position;
      }
      if (game.guardianVulnerable) game.activateAbility();
      step(0.3);
    }
    expect(game.hasStar(2), isTrue, reason: 'lull strikes fell the guardian');
    expect(game.relicDropActive, isTrue,
        reason: 'the guardian relic drops where the Simurgh fell');

    expect(earned, [0, 1, 2], reason: 'stars bank in play order, once each');
    expect(game.starsEarnedCount, 3);
  });
}

/// The outcome of tending one censer run at a given pace.
typedef _VesperRun = ({int gusts, int relights, int tolls, bool awake});

/// Declare [routeId], then tend the vesper with [tendFrames] of walking
/// between every action — the knob that separates "prompt" from "dawdling".
_VesperRun _runVesper(
  String routeId, {
  required int tendFrames,
  int chainsToRun = 3,
}) {
  final game = _harness([
    _member(0, 'Fire', 'mask'),
    _member(1, 'Air', 'wing'),
  ]);
  game.starMask = (1 << 0) | (1 << 1); // the vesper waits on the rite
  final gallery = _room(game, 'bell_gallery');
  final route = gallery.vesperRoutes.firstWhere((r) => r.id == routeId);
  game.currentRoomId = 'bell_gallery';
  _place(game, route.standPosition);
  game.setActive(0);
  game.activateAbility();
  expect(game.vesperRouteId, routeId);

  var gusts = 0;
  var relights = 0;
  for (final chain in gallery.incenseChains.take(chainsToRun)) {
    var guard = 0;
    while (!game.bellsRung.contains(chain.id) && guard++ < 900) {
      final flame = game.vesperFlamePosition(chain.id);
      if (flame == null) {
        game.setActive(0);
        _place(game, game.chainIgnitionPoint(chain));
        game.activateAbility();
        relights++;
      } else {
        game.setActive(1);
        _place(game, flame);
        game.activateAbility();
        gusts++;
      }
      for (var f = 0; f < tendFrames; f++) {
        game.update(1 / 60);
        for (final c in game.creatures) {
          c.hp = c.maxHp;
        }
      }
    }
    expect(game.bellsRung, contains(chain.id),
        reason: '$routeId must be able to ring ${chain.id}');
  }
  return (
    gusts: gusts,
    relights: relights,
    tolls: game.bellsRung.length,
    awake: game.guardianAwake,
  );
}

void _place(PlanetDungeonGame game, Offset pos) {
  for (final c in game.creatures) {
    c
      ..position = pos
      ..lastSafe = pos;
  }
}

/// Move only the creature currently under the player's hand.
void _placeActive(PlanetDungeonGame game, Offset pos) {
  game.creatures[game.activeIndex]
    ..position = pos
    ..lastSafe = pos;
}

// ── Playing the garth the way a player does ───────────────
// Every helper below goes through `activateAbility()` — the same press the
// screen sends — so nothing here can pass on a mechanic the game does not
// actually implement.

/// Walk an Air creature to the wind-cross and swing it until the crosswind
/// runs [want] (0 N · 1 E · 2 S · 3 W).
void _turnWindTo(PlanetDungeonGame game, int want) {
  final vane = _room(game, 'cloister').windVane!;
  final air = game.party.indexWhere((m) => m.element == 'Air');
  var guard = 0;
  while (game.gardenWind != want && guard++ < 8) {
    game.setActive(air);
    _placeActive(game, vane);
    game.activateAbility();
  }
  expect(game.gardenWind, want);
}

/// Grow bed [index] with a Plant creature, and let the shoots take.
void _growBed(PlanetDungeonGame game, int index) {
  final beds = _room(game, 'cloister').vineBeds;
  final plant = game.party.indexWhere((m) => m.element == 'Plant');
  game.setActive(plant);
  _placeActive(game, beds[index].position);
  game.activateAbility();
  var guard = 0;
  while (game.bedGrowthAt(index) < 1.0 && guard++ < 600) {
    game.update(1 / 60);
    for (final c in game.creatures) {
      c.hp = c.maxHp;
    }
  }
}

/// Burn bed [index] with a Fire creature.
void _burnBed(PlanetDungeonGame game, int index) {
  final beds = _room(game, 'cloister').vineBeds;
  final fire = game.party.indexWhere((m) => m.element == 'Fire');
  game.setActive(fire);
  _placeActive(game, beds[index].position);
  game.activateAbility();
}

/// Play THIS RUN's shortest garden plan, move for move, as a player would:
/// swap to the creature that holds the verb, walk to the bed (or to the
/// wind-cross), press ACT — and wait for shoots to take before asking them to
/// burn. Returns how many moves it took.
int _playGardenPlan(PlanetDungeonGame game, {void Function()? between}) {
  final room = _room(game, 'cloister');
  final solved = game.solveAshGarden();
  final plan = solved.plan;
  expect(plan, isNotNull,
      reason: 'the rolled garth must have a solution: ${game.gardenDemands}');
  game.currentRoomId = 'cloister';
  for (final move in plan!) {
    switch (move.verb) {
      case AshGardenVerb.turnWind:
        game.setActive(game.party.indexWhere((m) => m.element == 'Air'));
        _placeActive(game, room.windVane!);
        game.activateAbility();
      case AshGardenVerb.grow:
        _growBed(game, move.bed);
      case AshGardenVerb.burn:
        _burnBed(game, move.bed);
    }
    between?.call();
  }
  return plan.length;
}

/// Re-run the rite deduction with the ASH DRIFT channel switched off, to show
/// the drift is a real constraint rather than decoration. Mirrors the game's
/// own solver (wax tiers + soot leans) and simply skips the drift check.
int _solveIgnoringAsh(PlanetDungeonGame game) {
  final room = game.layout.rooms.values
      .firstWhere((r) => r.brazierStarIndex != null && r.braziers.length >= 2);
  final n = room.braziers.length;
  var satisfying = 0;
  final current = <int>[];
  final used = List<bool>.filled(n, false);

  void walk() {
    if (current.length == n) {
      satisfying++;
      return;
    }
    final rank = current.length;
    for (var idx = 0; idx < n; idx++) {
      if (used[idx]) continue;
      final t = game.testimonyFor(idx)!;
      if (t.waxTier != rank ~/ 2) continue;
      if (rank == 0) {
        if (t.sootLean != null) continue;
      } else {
        if (t.sootLean == null) continue;
        var pred = current.first;
        var bestD = double.infinity;
        for (final j in current) {
          final d =
              (room.braziers[idx].position - room.braziers[j].position).distance;
          if (d < bestD) {
            bestD = d;
            pred = j;
          }
        }
        final d = room.braziers[idx].position - room.braziers[pred].position;
        final len = d.distance;
        if (len < 1e-6) continue;
        final u = d / len;
        final lean = t.sootLean!;
        final dot = (u.dx * lean.dx + u.dy * lean.dy).clamp(-1.0, 1.0);
        if (math.acos(dot) > 0.40) continue;
      }
      used[idx] = true;
      current.add(idx);
      walk();
      current.removeLast();
      used[idx] = false;
    }
  }

  walk();
  return satisfying;
}
