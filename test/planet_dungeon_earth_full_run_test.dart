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
    for (final rib in hall.fossilRibs) {
      for (var shove = 0; shove < rib.notches.length - 1; shove++) {
        final cur = game.ribNotches[rib.id] ?? 0;
        // Stand WEST of the rib (behind it on the track) and shove onward.
        teleport('rib_hall', rib.notches[cur] - const Offset(110, 0));
        game.activateAbility();
        expect(
          game.ribNotches[rib.id] ?? 0,
          cur,
          reason: 'the grind is ANIMATED — the notch lands later',
        );
        var guard = 0;
        while ((game.ribNotches[rib.id] ?? 0) == cur && guard++ < 200) {
          game.update(1 / 60);
        }
        expect(game.ribNotches[rib.id], cur + 1, reason: 'the grind lands');
      }
    }
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
    void chargePillar(int activeIdx, String pillarId, Offset pos) {
      game.setActive(activeIdx);
      teleport('pillar_crypt', pos);
      game.activateAbility();
      expect(
        game.lockedPillars.contains(pillarId),
        isFalse,
        reason: 'the socket CHARGES first — it does not light instantly',
      );
      var guard = 0;
      while (!game.lockedPillars.contains(pillarId) && guard++ < 600) {
        game.update(1 / 60);
      }
      expect(
        game.lockedPillars,
        contains(pillarId),
        reason: 'the charge fills and the crystal lights',
      );
      clearWisps(); // the defend-wave came at charge start
    }

    chargePillar(
      2,
      crypt.fossilPillars.first.id,
      crypt.fossilPillars.first.position,
    ); // Crystal parity
    for (final pillar in crypt.fossilPillars.skip(1)) {
      chargePillar(1, pillar.id, pillar.position); // Lightning pip
    }
    expect(game.hasStar(1), isTrue, reason: 'four sockets bank Star 2');
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

    // ── The Lost Maxim: a crystal takes root in the open palm ──
    teleport('palm_hollow', kGiantsPalm);
    game.activateAbility();
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
      game.creatures.single
        ..position = rib.notches.first - const Offset(110, 0)
        ..lastSafe = rib.notches.first - const Offset(110, 0);
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
    final ribId = horn.layout.rooms['rib_hall']!.fossilRibs.first.id;
    shove(horn);
    expect(horn.ribNotches[ribId], 1, reason: 'the Horn lands the shove');
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
