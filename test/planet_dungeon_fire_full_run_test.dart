// Full-run simulation of the Fire dungeon (Cinder Cathedral): a headless
// party (the authored Fire+Air+Plant trio) plays every star from a fresh
// save — the narthex hearth ignition, the choir's ritual brazier order
// (including a wrong-flame snuff + consequence), the cloister's grow→burn ash
// garden, the chancel-gate rite lock, the bell-gallery vesper (ignite + gust
// to all three bells), and the Simurgh guardian — proving the whole dungeon
// is completable end-to-end with the real verbs.

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

PlanetDungeonGame _harness(List<CosmicPartyMember> party) {
  final game = PlanetDungeonGame(
    element: 'Fire',
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
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the authored trio can earn all three Fire stars end-to-end', () {
    final earned = <int>[];
    final discovered = <String>[];
    final party = [
      _member(0, 'Fire', 'mask'),
      _member(1, 'Air', 'wing'),
      _member(2, 'Plant', 'mane'),
    ];
    final game = PlanetDungeonGame(
      element: 'Fire',
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

    void clearWisps() {
      for (final e in game.combatEnemies) {
        e.isDead = true;
      }
      step();
    }

    // ── Entry: Fire rekindles the cold narthex hearth ──
    game.setActive(0); // Fire mask
    final hearth = room('narthex').braziers.single;
    teleport('narthex', hearth.position);
    game.activateAbility();
    step();
    expect(game.entryDoorRevealed, isTrue, reason: 'flame wakes the way in');
    expect(
      discovered,
      contains(PlanetDungeonGame.entryDoorDiscoveryId),
      reason: 'the reveal must persist like other discoveries',
    );

    // ── The Lost Maxim: the Ember Epitaph (easter egg) ──
    // Insight writes the maxim into the floor (animated) and bares the
    // garden; Plant fills it, Fire lights it, three gusts of Air set the
    // script ablaze. Wordless: no hint popups along the way.
    expect(game.epitaphStage, 0, reason: 'the egg starts invisible');
    game.setActive(0); // Fire MASK — insight reads the mural
    teleport('scriptorium', room('scriptorium').bounds.center);
    game.activateAbility();
    expect(game.epitaphStage, 1, reason: 'insight starts the floor-script');
    // The garden refuses interaction until the quill finishes writing.
    game.setActive(2); // Plant
    teleport('scriptorium', kEmberEpitaphPlanter);
    game.activateAbility();
    expect(
      game.epitaphStage,
      1,
      reason: 'the garden only settles once the writing completes',
    );
    step(4.6); // let the ember-quill finish the three lines
    teleport('scriptorium', kEmberEpitaphPlanter);
    game.activateAbility();
    expect(game.epitaphStage, 2, reason: 'shoots take to the planter');
    game.setActive(0); // Fire
    teleport('scriptorium', kEmberEpitaphPlanter);
    game.activateAbility();
    expect(game.epitaphStage, 3, reason: 'the shoots catch');
    game.setActive(1); // Air, fanning the blaze
    for (var i = 0; i < 3; i++) {
      teleport('scriptorium', kEmberEpitaphPlanter);
      game.activateAbility();
    }
    expect(
      discovered,
      contains(kFireEpitaphEggId),
      reason: 'three gusts blaze the maxim (the screen pays the 20 gold)',
    );

    // ── The chancel gate is sealed until both stars bank ──
    final nave = room('nave');
    final chancel = nave.doors.firstWhere((d) => d.targetRoomId == 'vestry');
    expect(game.isDoorLocked(nave, chancel), isTrue);

    // The vesper censers refuse flame before the rite unlocks.
    final gallery = room('bell_gallery');
    teleport(
      'bell_gallery',
      game.chainIgnitionPoint(gallery.incenseChains.first),
    );
    game.activateAbility();
    expect(
      game.vesperFlamePosition(gallery.incenseChains.first.id),
      isNull,
      reason: 'the vesper waits on the Ember and Ash stars',
    );

    // ── Star 1: the choir's remembered order ──
    final choir = room('choir');
    Offset brazierAt(int order) =>
        choir.braziers.firstWhere((b) => b.order == order).position;

    // A wrong flame snuffs the rite and angers the ash (consequence).
    game.setActive(0); // Fire mask carries the rite
    teleport('choir', brazierAt(1));
    game.activateAbility();
    expect(game.ritualProgress, 0, reason: 'wrong order resets the rite');
    expect(
      game.combatEnemies.where((e) => !e.isDead),
      isNotEmpty,
      reason: 'the snuffed rite spawns ash wisps',
    );
    clearWisps();

    for (var order = 0; order < choir.braziers.length; order++) {
      teleport('choir', brazierAt(order));
      game.activateAbility();
      step();
    }
    expect(game.hasStar(0), isTrue, reason: 'the full sequence banks Star 1');
    clearWisps();

    // ── Star 2: grow each bed, then burn it to ash ──
    final cloister = room('cloister');
    for (final bed in cloister.vineBeds) {
      game.setActive(2); // Plant mane
      teleport('cloister', bed.position);
      game.activateAbility();
      expect(game.bedStates[bed.id], 1, reason: '${bed.id} overgrows');
      game.setActive(0); // Fire mask
      teleport('cloister', bed.position);
      game.activateAbility();
      expect(game.bedStates[bed.id], 2, reason: '${bed.id} reveals its sigil');
      step();
    }
    expect(game.hasStar(1), isTrue, reason: 'four sigils bank Star 2');
    expect(game.guardianRiteUnlocked, isTrue);
    expect(
      game.isDoorLocked(nave, chancel),
      isFalse,
      reason: 'Ember and Ash part the chancel gate',
    );
    clearWisps();

    // ── Star 3 consequences: ignition rouses the ash; neglect enrages it ──
    final firstChain = gallery.incenseChains.first;
    game.setActive(0); // Fire
    teleport('bell_gallery', game.chainIgnitionPoint(firstChain));
    game.activateAbility();
    expect(game.vesperFlamePosition(firstChain.id), isNotNull);
    expect(
      game.combatEnemies.where((e) => !e.isDead),
      isNotEmpty,
      reason: 'lighting a censer rouses ash wisps at once',
    );
    clearWisps(); // isolate the fury wave from the ignite wave
    var starve = 0;
    while (game.vesperFlamePosition(firstChain.id) != null && starve++ < 400) {
      game.update(1 / 60);
      for (final c in game.creatures) {
        c.hp = c.maxHp;
      }
    }
    expect(
      game.vesperFlamePosition(firstChain.id),
      isNull,
      reason: 'an ungusted flame starves between censers',
    );
    expect(
      game.combatEnemies.where((e) => !e.isDead),
      isNotEmpty,
      reason: 'a dead flame spawns a fury wave',
    );
    clearWisps();

    // ── Star 3: carry the flame down each chain; ring all three bells ──
    for (final chain in gallery.incenseChains) {
      var guard = 0;
      while (!game.bellsRung.contains(chain.id) && guard++ < 600) {
        final flamePos = game.vesperFlamePosition(chain.id);
        if (flamePos == null) {
          game.setActive(0); // Fire re-lights at the checkpoint censer
          teleport('bell_gallery', game.chainIgnitionPoint(chain));
          game.activateAbility();
        } else {
          game.setActive(1); // Air wing gusts the flame onward
          teleport('bell_gallery', flamePos);
          game.activateAbility();
        }
        game.update(1 / 60);
        for (final c in game.creatures) {
          c.hp = c.maxHp;
        }
      }
      expect(
        game.bellsRung,
        contains(chain.id),
        reason: 'ignite + gusts ring ${chain.id}',
      );
    }
    expect(game.guardianAwake, isTrue, reason: 'three tolls wake the Simurgh');
    clearWisps();

    // ── The Simurgh: paced lull strikes until it yields ──
    game.setActive(0);
    final guardianNode = room('sanctum').guardian!;
    teleport('sanctum', guardianNode.position + const Offset(0, 80));
    var safety = 0;
    while (!game.hasStar(2) && safety++ < 600) {
      final simurgh = game.combatEnemies.where((e) => e.isElite).firstOrNull;
      if (simurgh != null && !simurgh.isDead) {
        // Keep the wheeling Simurgh within reach for the scripted strikes.
        simurgh.position = game.creatures[game.activeIndex].position;
      }
      if (game.guardianVulnerable) game.activateAbility();
      step(0.3);
    }
    expect(game.hasStar(2), isTrue, reason: 'lull strikes fell the guardian');
    expect(
      game.relicDropActive,
      isTrue,
      reason: 'the guardian relic drops and hovers where the Simurgh fell',
    );

    expect(earned, [0, 1, 2], reason: 'stars bank in play order, once each');
    expect(game.starsEarnedCount, 3);
  });

  // v2: the ash-garden bed is ELEMENT-ONLY. Any Plant lays the growth, and
  // lays it CLEAN — there is no rustling tax on the wrong family.
  test('the vine bed is element-only: every Plant family grows it '
      'identically', () {
    for (final family in const [
      'pip', 'mane', 'horn', 'mask', 'wing', 'kin',
    ]) {
      final game = _harness([_member(0, 'Plant', family)]);
      final bed = game.layout.rooms['cloister']!.vineBeds.first;
      game.currentRoomId = 'cloister';
      game.creatures.single
        ..position = bed.position
        ..lastSafe = bed.position;

      game.activateAbility();
      expect(
        game.bedStates[bed.id],
        1,
        reason: 'a Plant $family must overgrow the bed',
      );
      expect(
        game.combatEnemies.where((e) => !e.isDead),
        isEmpty,
        reason: 'a Plant $family grows CLEAN — the ash sleeps through it',
      );
    }
  });

  test('the vesper gust is element-only: every Air family carries the flame '
      'the same distance', () {
    final landings = <String, Offset>{};
    for (final family in const [
      'pip', 'mane', 'horn', 'mask', 'wing', 'kin',
    ]) {
      final game = _harness([
        _member(0, 'Fire', 'mask'),
        _member(1, 'Air', family),
      ]);
      game.starMask = (1 << 0) | (1 << 1); // the vesper waits on the rite
      final chain = game.layout.rooms['bell_gallery']!.incenseChains.first;
      game.currentRoomId = 'bell_gallery';
      // Fire lights the chain, then the Air creature gusts the live flame.
      final ignition = game.chainIgnitionPoint(chain);
      for (final c in game.creatures) {
        c
          ..position = ignition
          ..lastSafe = ignition;
      }
      game.setActive(0);
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
      expect(after, isNot(before),
          reason: 'an Air $family must move the flame');
      landings[family] = after!;
    }
    expect(
      landings.values.toSet().length,
      1,
      reason: 'no Air family gusts the flame further than another: $landings',
    );
  });
}
