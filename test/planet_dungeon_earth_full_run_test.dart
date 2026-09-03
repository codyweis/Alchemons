// Full-run simulation of the Earth dungeon (the Buried Giant): a headless
// party (the authored Earth+Lightning+Crystal trio) plays every star from a
// fresh save — the fallen-lintel entry, the track-notch rib shoves (animated
// grinds, with a wrong-family slow-and-loud penalty in a second test), the
// marrow bridge and sternum plate, the socket arcs (Pip clean + Crystal
// parity), the rite-shut jaw, the stone-scale balance, the Giant's Palm
// easter egg, and Terradon — proving the whole dungeon is completable
// end-to-end with the real verbs.

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
    element: 'Earth',
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the authored trio can earn all three Earth stars end-to-end', () {
    final earned = <int>[];
    final discovered = <String>[];
    final party = [
      _member(0, 'Earth', 'horn'),
      _member(1, 'Lightning', 'pip'),
      _member(2, 'Crystal', 'mask'),
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

    // ── Entry: Earth raises the fallen lintel ──
    game.setActive(0); // Earth horn
    teleport('barrow_gate', kBarrowLintel);
    game.activateAbility();
    step();
    expect(game.entryDoorRevealed, isTrue, reason: 'earth raises the way in');
    expect(discovered, contains(PlanetDungeonGame.entryDoorDiscoveryId));

    // ── The skull's jaw is shut until both stars bank ──
    final court = room('sternum_court');
    final jaw = court.doors.firstWhere(
      (d) => d.targetRoomId == 'skull_antechamber',
    );
    expect(game.isDoorLocked(court, jaw), isTrue);

    // The scale and its plinth refuse everything before the rite.
    final eye = room('eye_chamber').stoneScale!;
    teleport('eye_chamber', eye.weights.first.position);
    game.activateAbility();
    expect(
      game.scalePanRight,
      isEmpty,
      reason: 'the scale sleeps until the rite unlocks',
    );
    teleport('eye_chamber', eye.plinth);
    game.activateAbility();
    expect(
      game.prismStage,
      0,
      reason: 'the plinth sleeps until the rite unlocks',
    );

    // ── Star 1: shove the three ribs home (animated grinds), then the
    //    sternum plate beyond the bridged marrow ──
    final hall = room('rib_hall');

    /// THE CAGE IS ONE BONE. Shoving a rib levers its neighbours the other
    /// way, so the star is no longer six identical shoves — it is a sequence,
    /// and the test walks it with the game's OWN solver rather than a script
    /// that would rot away from the mechanic it is meant to exercise.
    List<int> board() => [
      for (final r in hall.fossilRibs) game.ribNotches[r.id] ?? 0,
    ];

    /// Shove rib [i] one notch in [step], and let every grind it causes land.
    void shove(int i, int step) {
      final rib = hall.fossilRibs[i];
      final at = rib.notches[game.ribNotches[rib.id] ?? 0];
      // Stand behind it on the track: west shoves onward, east shoves back.
      teleport('rib_hall', at + Offset(step > 0 ? -110 : 110, 0));
      game.activateAbility();
      var guard = 0;
      while (game.ribGrinding && guard++ < 400) {
        game.update(1 / 60);
      }
    }

    expect(
      game.ribCageDistance(hall, board()),
      greaterThanOrEqualTo(4),
      reason: 'the rolled cage is a real walk, not nearly solved already',
    );

    // Greedy on the solver: every shove must strictly shorten the distance.
    var guard = 0;
    while (game.ribCageDistance(hall, board()) > 0 && guard++ < 40) {
      final was = game.ribCageDistance(hall, board());
      var took = false;
      for (var i = 0; i < hall.fossilRibs.length && !took; i++) {
        for (final step in const [1, -1]) {
          // The cage drags THE RIB BELOW, and only that one — mirror the
          // game's rule exactly or the greedy walks off the mechanic.
          final trial = [...board()];
          trial[i] += step;
          if (i + 1 < trial.length) trial[i + 1] -= step;
          if (trial.any((v) => v < 0 || v > 2)) continue;
          if (game.ribCageDistance(hall, trial) != was - 1) continue;
          shove(i, step);
          took = true;
          break;
        }
      }
      expect(took, isTrue, reason: 'the solver always has a move');
    }
    expect(
      hall.fossilRibs.every((r) => game.ribNotches[r.id] == 2),
      isTrue,
      reason: 'every rib lies true in the marrow groove',
    );

    expect(
      game.combatEnemies.where((e) => !e.isDead),
      isEmpty,
      reason: 'a Horn shoves CLEAN — no marrow woken',
    );
    teleport('rib_hall', hall.sternumPlate!.center);
    step();
    expect(game.hasStar(0), isTrue, reason: 'the bridged plate banks Star 1');
    clearWisps();

    // The marrow vault beyond the bridge: its essence fizzles, once ever.
    teleport('marrow_vault', room('marrow_vault').vaultCache!);
    step();
    expect(
      discovered,
      contains('cache:earth_vault'),
      reason: 'the vault cache pays out (screen grants the 5 gold)',
    );

    // ── Star 2: charge the sockets — each draws the storm over a window and
    // must be DEFENDED until it lights (Crystal parity + Pip both fast) ──
    final crypt = room('pillar_crypt');

    /// EARTH WALKS THE SPINE. Standing on a vertebra warms it; pressing
    /// there seats it for good. Seat all five and the giant's back takes the
    /// weight — the buried pillars come up and their sockets open.
    void walkTheSpine() {
      game.setActive(0); // the Earth horn
      for (var i = 0; i < kSpineSteps; i++) {
        final at = game.spineStepAt(crypt, i);
        teleport('pillar_crypt', at);
        game.update(1 / 60); // the step warms under the foot
        game.activateAbility();
        expect(game.spineLatched, contains(i), reason: 'step $i seats');
      }
      expect(game.cryptOpen, isTrue, reason: 'the back takes the weight');
      game.update(1 / 60);
      expect(
        game.pillarBared,
        hasLength(crypt.fossilPillars.length),
        reason: 'and the sockets come up with the pillars',
      );
    }

    /// LIGHTNING lights a bared socket, over a charge window it must survive.
    void light(FossilPillar p) {
      game.setActive(1); // the Lightning pip
      teleport('pillar_crypt', p.position);
      game.activateAbility();
      expect(
        game.lockedPillars.contains(p.id),
        isFalse,
        reason: 'the socket CHARGES first — it does not light instantly',
      );
      var guard = 0;
      while (!game.lockedPillars.contains(p.id) && guard++ < 600) {
        game.update(1 / 60);
        // Hold the leak off the others while the charge runs: this test is
        // about the ORDER, and the clock has its own test.
        for (final q in crypt.fossilPillars) {
          if (game.pillarLife.containsKey(q.id)) game.pillarLife[q.id] = 99;
        }
      }
      expect(game.lockedPillars, contains(p.id), reason: 'the crystal lights');
      clearWisps(); // the defend-wave came at charge start
    }

    /// CRYSTAL seals one for good — only with both ring neighbours holding.
    void seal(FossilPillar p) {
      game.setActive(2); // the Crystal mask
      teleport('pillar_crypt', p.position);
      game.activateAbility();
    }

    walkTheSpine();

    // CRYSTAL GROWS OUT OF CRYSTAL. A lit socket with a dark side refuses.
    final ring = crypt.fossilPillars;
    light(ring[0]);
    seal(ring[0]);
    expect(
      game.pillarSealed,
      isEmpty,
      reason: 'both sides of it are still dark — crystal will not start',
    );

    // Light its two ring neighbours, then it takes.
    final firstRing = game.pillarRingOf(crypt, ring[0].id);
    for (final id in firstRing) {
      light(crypt.fossilPillars.firstWhere((p) => p.id == id));
    }
    seal(ring[0]);
    expect(
      game.pillarSealed,
      contains(ring[0].id),
      reason: 'flanked on both sides, the crystal takes',
    );

    // A sealed socket is a permanent anchor its neighbours can grow from, so
    // the rest fall in order.
    var sealGuard = 0;
    while (game.pillarSealed.length < crypt.fossilPillars.length &&
        sealGuard++ < 20) {
      for (final p in crypt.fossilPillars) {
        if (game.pillarSealed.contains(p.id)) continue;
        if (!game.lockedPillars.contains(p.id)) light(p);
        seal(p);
      }
    }
    expect(game.hasStar(1), isTrue, reason: 'four SEALED sockets bank Star 2');
    expect(game.guardianRiteUnlocked, isTrue);
    expect(
      game.isDoorLocked(court, jaw),
      isFalse,
      reason: 'Marrow and Crystal open the jaw',
    );
    clearWisps();

    // ── Star 3: build the eye its lens, then balance by batched readings ──
    // The eye is BLIND until the gaze prism stands: Earth raises the core…
    game.setActive(0); // Earth horn
    teleport('eye_chamber', eye.plinth);
    game.activateAbility();
    expect(game.prismStage, 1, reason: 'stone rises on the plinth');
    // …and Lightning crystallises it (the planet's own braid).
    game.setActive(1); // Lightning pip
    teleport('eye_chamber', eye.plinth);
    game.activateAbility();
    expect(game.prismStage, 2, reason: 'the prism stands; the eye can see');

    // Communing at the prism is the ONLY reading (stones stay silent). The
    // count itself is STATE (§5.6): it snapshots into the progress readout,
    // never the capsule.
    expect(
      game.progressReadout,
      isNull,
      reason: 'the eye has not judged yet — no readout before a communion',
    );
    game.activateAbility();
    expect(
      game.hintText,
      isNot(contains('sit true')),
      reason: 'the capsule keeps the communing, never the count',
    );
    final judged = game.progressReadout;
    expect(judged, isNotNull, reason: 'the communion snapshots the judgment');
    expect(judged!.label, 'STONES');
    expect(judged.value, contains('of ${eye.weights.length} true'));

    // The solution is PER-RUN (the eye remembers differently each burial):
    // solve from the run's own answer. Stones start on the left pan.
    game.setActive(2); // Crystal mask
    for (final w in eye.weights) {
      if (game.scaleSolution[w.id] != true) continue;
      teleport('eye_chamber', w.position);
      game.activateAbility();
      step();
    }
    expect(
      game.guardianAwake,
      isTrue,
      reason: 'the true scale wakes the heart',
    );
    clearWisps();

    // ── The Lost Maxim: the hand is given something to hold ──
    //
    // A CHAIN now, in the barrow's own braid: Earth raises a core, Lightning
    // (or Crystal) braids it to a seed, and Crystal refracts light down each
    // of the palm's three creases until it roots. Three elements, four beats
    // — the Ember Epitaph's shape, on this planet's vocabulary.
    void atPalm(int who) {
      game.setActive(who);
      teleport('palm_hollow', kGiantsPalm);
      game.activateAbility();
    }

    atPalm(0); // the Earth horn raises the core
    expect(game.palmStage, 1, reason: 'stone rises in the palm');
    atPalm(1); // the Lightning pip braids it
    expect(game.palmStage, 2, reason: 'Earth+Lightning braid to a seed');
    for (var i = 0; i < 3; i++) {
      expect(
        discovered,
        isNot(contains(kEarthGiantsPalmEggId)),
        reason: 'nothing is earned until the third crease is lit',
      );
      atPalm(2); // the Crystal mask lights a crease
    }
    expect(game.palmStage, 3, reason: 'the seed roots');
    // THE RITE OF THREE runs before the gold lands (see `beginMaximRite`).
    for (var tick = 0; tick < 200; tick++) {
      game.update(1 / 60);
    }
    expect(
      discovered,
      contains(kEarthGiantsPalmEggId),
      reason: 'crystal in the palm earns the maxim (screen pays the 20 gold)',
    );

    // ── Terradon: paced lull strikes until it yields ──
    final guardianNode = room('heart_chamber').guardian!;
    teleport('heart_chamber', guardianNode.position + const Offset(0, 80));
    var safety = 0;
    while (!game.hasStar(2) && safety++ < 600) {
      final terradon = game.combatEnemies.where((e) => e.isElite).firstOrNull;
      if (terradon != null && !terradon.isDead) {
        terradon.position = game.creatures[game.activeIndex].position;
      }
      if (game.guardianVulnerable) game.activateAbility();
      step(0.3);
    }
    expect(game.hasStar(2), isTrue, reason: 'lull strikes fell the guardian');
    expect(game.relicDropActive, isTrue);

    expect(earned, [0, 1, 2], reason: 'stars bank in play order, once each');
    expect(game.starsEarnedCount, 3);
  });

  // v2: the rib is a HARD GATE (Earth + Horn). There is no off-family shove to
  // grade — the wrong family is refused, and every shove that happens is clean.
  test('the ribs are a hard gate: the wrong family is refused outright', () {
    void shove(PlanetDungeonGame game) {
      final rib = game.layout.rooms['rib_hall']!.fossilRibs.first;
      game.currentRoomId = 'rib_hall';
      // The cage's opening arrangement is ROLLED now, so park the rib at
      // notch 0 by hand — this test is about the family gate, not the puzzle.
      for (final r in game.layout.rooms['rib_hall']!.fossilRibs) {
        game.ribNotches[r.id] = 0;
      }
      final at = rib.notches.first - const Offset(110, 0);
      game.creatures.single
        ..position = at
        ..lastSafe = at;
      game.activateAbility();
      for (var i = 0; i < 180; i++) {
        game.update(1 / 60);
        game.creatures.single.hp = game.creatures.single.maxHp;
      }
    }

    // Right element, wrong family: nothing moves, and nothing is roused —
    // a refusal is not a penalty.
    for (final family in const ['mane', 'pip', 'mask', 'wing', 'kin']) {
      final blocked = _harness([_member(0, 'Earth', family)]);
      final ribId = blocked.layout.rooms['rib_hall']!.fossilRibs.first.id;
      shove(blocked);
      expect(
        blocked.ribNotches[ribId] ?? 0,
        0,
        reason: 'an Earth $family must not shift the giant\'s bone',
      );
      expect(
        blocked.combatEnemies.where((e) => !e.isDead),
        isEmpty,
        reason: 'a clean refusal never rouses the marrow',
      );
    }

    // Right element AND family: one clean shove, no consequence wave.
    final horn = _harness([_member(0, 'Earth', 'horn')]);
    shove(horn);
    // The top rib has a rib below it, so a legal shove from (0,0,0) would
    // drive that one to -1 — the cage refuses. Shove the LOWEST rib instead:
    // nothing hangs under it, so it moves alone.
    final lowest = horn.layout.rooms['rib_hall']!.fossilRibs.last;
    horn.currentRoomId = 'rib_hall';
    for (final r in horn.layout.rooms['rib_hall']!.fossilRibs) {
      horn.ribNotches[r.id] = 0;
    }
    final at = lowest.notches.first - const Offset(110, 0);
    horn.creatures.single
      ..position = at
      ..lastSafe = at;
    horn.activateAbility();
    for (var i = 0; i < 180; i++) {
      horn.update(1 / 60);
      horn.creatures.single.hp = horn.creatures.single.maxHp;
    }
    expect(
      horn.ribNotches[lowest.id],
      1,
      reason: 'the Horn lands the shove on the rib that hangs free',
    );
    expect(
      horn.combatEnemies.where((e) => !e.isDead),
      isEmpty,
      reason: 'a clean shove is silent',
    );
  });

  test('the buried socket is element-only: every Lightning family charges it '
      'identically', () {
    // (framesToLight, wispsRoused) per family — must be one and the same.
    final results = <String, (int, int)>{};
    for (final family in const ['pip', 'mane', 'horn', 'mask', 'wing', 'kin']) {
      final game = _harness([_member(0, 'Lightning', family)]);
      final pillar = game.layout.rooms['pillar_crypt']!.fossilPillars.first;
      game.currentRoomId = 'pillar_crypt';
      // The sockets are BURIED now — Earth takes the rock off before anything
      // can be put in. This test is about the family parity of the CHARGE, so
      // the digging is done by hand.
      game.pillarBared.add(pillar.id);
      game.creatures.single
        ..position = pillar.position
        ..lastSafe = pillar.position;
      game.activateAbility();
      // The defend-the-socket wave is a PUZZLE consequence: it comes for
      // EVERYONE, and it is the same size for everyone.
      final roused = game.combatEnemies.where((e) => !e.isDead).length;
      expect(roused, greaterThan(0), reason: 'the charge wakes the marrow');
      var frames = 0;
      while (!game.lockedPillars.contains(pillar.id) && frames++ < 600) {
        game.update(1 / 60);
        game.creatures.single.hp = game.creatures.single.maxHp;
      }
      expect(
        game.lockedPillars,
        contains(pillar.id),
        reason: 'a Lightning $family must light the socket',
      );
      results[family] = (frames, roused);
    }
    expect(
      results.values.toSet().length,
      1,
      reason:
          'no family charges faster, slower, or louder than another: '
          '$results',
    );
  });

  test('every scale stone has a body-mark recorded in a real room', () {
    // The answer is NOT noise — each stone's true pan is written into the
    // giant's anatomy. Guard the clue map against authoring drift.
    final earth = kPlanetDungeonLayouts['Earth']!;
    final scale = earth.rooms['eye_chamber']!.stoneScale!;
    for (final w in scale.weights) {
      expect(
        kScaleClueRooms.containsKey(w.id),
        isTrue,
        reason: 'stone ${w.id} must record its truth somewhere in the body',
      );
      expect(
        earth.rooms.containsKey(kScaleClueRooms[w.id]),
        isTrue,
        reason: '${w.id} clue points at a real room',
      );
    }
    expect(
      kScaleClueRooms.length,
      scale.weights.length,
      reason: 'one body-mark per stone, no orphans',
    );
  });

  test('the scale solution is rolled per run, always two-sided', () {
    final signatures = <String>{};
    for (var i = 0; i < 10; i++) {
      final game = _harness([_member(0, 'Earth', 'horn')]);
      final scale = game.layout.rooms['eye_chamber']!.stoneScale!;
      expect(
        game.scaleSolution.keys.toSet(),
        scale.weights.map((w) => w.id).toSet(),
        reason: 'every weight gets a rolled answer',
      );
      expect(
        game.scaleSolution.values.toSet().length,
        2,
        reason: 'the answer always uses both pans (never all-one-side)',
      );
      signatures.add(
        scale.weights.map((w) => game.scaleSolution[w.id]).join(','),
      );
    }
    expect(
      signatures.length,
      greaterThan(1),
      reason:
          'ten runs must not all share one answer — the eye remembers '
          'differently each burial',
    );
  });
}
