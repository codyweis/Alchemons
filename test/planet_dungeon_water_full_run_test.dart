// The Mirror-Tide Temple (Water), mechanic by mechanic — the focused style
// Steam and Lightning use. One end-to-end run proves the dungeon is
// completable with the real verbs; the rest of the file pins the pieces that
// can silently rot:
//
//  • Star 2 is the MOON-LANTERN now (docs §6.4 REWORK): the gallery's canal
//    network, its two public rules (SILL and SPILL), the tide as the steering
//    wheel, Ice as the second verb, Spirit's foresight, and both cheap
//    failures — grounding on a bare sill and going under in a torrent.
//  • The Leviathan turns the tide on its roar (§7 retrofit) and hides in the
//    swell — and raids stay exempt.
//  • The invariants the rework was not allowed to touch: the Water+Pip
//    pipe-mouth hard gate, the moon-pool rite, the Frozen Moon egg, the
//    pearl cache, the guardian relic.

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
}) {
  return CosmicPartyMember(
    instanceId: 'inst_$slot',
    baseId: 'base_$slot',
    displayName: '$element $family',
    element: element,
    family: family,
    level: 10,
    statSpeed: 3,
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
  void Function(int)? onStarEarned,
  void Function(String)? onCloudDiscovered,
  void Function()? onPlayerDown,
}) {
  final game = PlanetDungeonGame(
    element: 'Water',
    party: party,
    initialStarMask: 0,
    onStarEarned: onStarEarned ?? (_) {},
    onCloudDiscovered: onCloudDiscovered,
    onPlayerDown: onPlayerDown ?? () {},
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

/// A moon-well harness with the rite unlocked and the tide settled MID — the
/// only state in which the pools take ice. Slot 0 is a Water Pip (it works the
/// pipe-mouth); [m] is the creature under test, left active in slot 1.
/// The well, ready to be worked: the rite unlocked, the party standing in it,
/// and the moon parked at a notch some basin is actually listening for.
PlanetDungeonGame _moonWellReady(CosmicPartyMember m) {
  final game = _harness([_member(0, 'Water', 'pip'), m]);
  game.starMask = (1 << 0) | (1 << 1); // the well waits on the rite
  game.currentRoomId = 'moon_well';
  final at = game.layout.rooms['moon_well']!.bounds.center;
  for (final c in game.creatures) {
    c
      ..position = at
      ..lastSafe = at;
  }
  // Nothing in the well agrees with the sky until the broken main is plugged,
  // and the pip plugs it by STANDING in the mouth.
  _plugSpout(game);
  return game;
}

/// Stand the Water pip in the mouth of the well's broken main.
void _plugSpout(PlanetDungeonGame g) {
  final valve = g.layout.rooms['moon_well']!.tideValves.firstWhere(
    (v) => v.pipOnly,
  );
  final pip = g.creatures.firstWhere(
    (c) => c.member.element == 'Water' && c.member.family == 'pip',
  );
  pip
    ..position = valve.position
    ..lastSafe = valve.position;
}

/// Let the well's water come to the stand the moon is calling for.
void _settleWell(PlanetDungeonGame g) {
  for (var i = 0; i < 60 * 8; i++) {
    if (g.wellAgreesWithMoon) return;
    g.update(1 / 60);
    g.moonWaxT = 0; // hold the sky while the water catches up
  }
}

/// The id of a basin that is listening this run, and the notch it wants.
(String, int) _listening(PlanetDungeonGame g) {
  final e = g.poolWants.entries.first;
  return (e.key, e.value);
}

/// Stand the moon at [notch] and let it settle there.
void _parkMoon(PlanetDungeonGame g, int notch) {
  // One frame first: walking in, the moon reconciles itself to the standing
  // water, and it would overwrite anything parked before that had happened.
  _plugSpout(g);
  g.update(1 / 60);
  g.moonNotch = notch;
  g.moonWaxT = 0;
  _settleWell(g);
  g.moonHoldT = 99;
}


/// A gallery harness: the party stands in the Lantern Gallery's south-east
/// floor, clear of every basin and every sluice wheel, so a press means what
/// the test says it means and nothing else.
PlanetDungeonGame _gallery(List<CosmicPartyMember> party) {
  final game = _harness(party);
  game.currentRoomId = 'ghost_gallery';
  const clear = Offset(500, 690);
  for (final c in game.creatures) {
    c
      ..position = clear
      ..lastSafe = clear;
  }
  return game;
}

Offset _nodeAt(PlanetDungeonGame game, String id) => game
    .layout
    .rooms['ghost_gallery']!
    .canalNodes
    .firstWhere((n) => n.id == id)
    .position;

/// Walk the active creature onto [at] and press ACT — the whole player input
/// vocabulary for this puzzle, in one line.
void _act(PlanetDungeonGame game, Offset at) {
  game.creatures[game.activeIndex]
    ..position = at
    ..lastSafe = at;
  game.activateAbility();
}

/// Set the lantern at [nodeId] and light it with a hand, as a player does.
/// For a basin mid-network the test seeds the RESTING state first (the same
/// state a grounding leaves behind) rather than spending twenty seconds of
/// drift getting there — the setting press itself is the real verb.
void _setLanternAt(PlanetDungeonGame game, String nodeId) {
  if (nodeId != 'spring') {
    game.lanternNodeId = nodeId;
    game.lanternLit = false;
  }
  _act(game, _nodeAt(game, nodeId));
}

/// Let the temple run until [done], healing as we go. False on timeout.
bool _driftUntil(
  PlanetDungeonGame game,
  bool Function() done, {
  double seconds = 30,
}) {
  final steps = (seconds * 60).round();
  for (var i = 0; i < steps; i++) {
    if (done()) return true;
    game.update(1 / 60);
    for (final c in game.creatures) {
      c.hp = c.maxHp;
    }
  }
  return done();
}

/// Longer than `_kPoolHold`; the basins want the moon STILL.
const double _kPoolHoldForTest = 99.0;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the authored trio can earn all three Water stars end-to-end', () {
    final earned = <int>[];
    final discovered = <String>[];
    final party = [
      _member(0, 'Water', 'pip'),
      _member(1, 'Spirit', 'mask'),
      _member(2, 'Ice', 'mane'),
    ];
    final game = _harness(
      party,
      onStarEarned: earned.add,
      onCloudDiscovered: discovered.add,
      onPlayerDown: () => fail('the scripted run must never wipe'),
    );

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

    void settleTide() {
      var guard = 0;
      while (!game.tideSettled && guard++ < 600) {
        game.update(1 / 60);
      }
      expect(game.tideSettled, isTrue, reason: 'the tide must settle');
    }

    // ── Entry: Water fills the dry offering-bowl ──
    game.setActive(0); // Water pip
    teleport('tide_gate', kTideGateBowl);
    game.activateAbility();
    step();
    expect(game.entryDoorRevealed, isTrue, reason: 'water wakes the way in');
    expect(discovered, contains(PlanetDungeonGame.entryDoorDiscoveryId));

    // ── The mirror gate is sealed until both stars bank ──
    final court = room('drowned_court');
    final mirrorGate = court.doors.firstWhere(
      (d) => d.targetRoomId == 'moon_hall',
    );
    expect(game.isDoorLocked(court, mirrorGate), isTrue);

    // ── Star 1: three sluice seals, one per tide stand ──
    final works = room('tide_works');
    Offset sealAt(String id) =>
        works.tideSeals.firstWhere((s) => s.id == id).position;
    Offset valveAt(int level) =>
        works.tideValves.firstWhere((v) => v.level == level).position;

    expect(game.tideLevel, 0);
    expect(game.tideSettled, isTrue, reason: 'the temple starts at low water');
    teleport('tide_works', sealAt('seal_low'));
    game.activateAbility();
    expect(game.openedSeals, contains('seal_low'));
    // The tally is a READOUT now, not a line that fades (§5.6).
    expect(game.progressReadout?.label, 'SLUICES');
    expect(game.progressReadout?.value, '1/3');
    clearWisps();

    // The tide ANIMATES: setting mid leaves the water moving, then settled.
    teleport('tide_works', valveAt(1));
    game.activateAbility(); // Water PIP = the valve answers instantly
    expect(game.tideLevel, 1);
    expect(game.tideSettled, isFalse, reason: 'the flood is animated');
    step(0.5);
    expect(
      game.tideSettled,
      isFalse,
      reason: 'half a second in, the water is still climbing',
    );
    expect(game.tideAnim, greaterThan(0.05));
    settleTide();
    teleport('tide_works', sealAt('seal_mid'));
    game.activateAbility();
    expect(game.openedSeals, contains('seal_mid'));
    clearWisps();

    teleport('tide_works', valveAt(2));
    game.activateAbility();
    settleTide();
    teleport('tide_works', sealAt('seal_high'));
    game.activateAbility();
    step();
    expect(game.hasStar(0), isTrue, reason: 'three sluices bank Star 1');
    clearWisps();

    // ── The pearl passage drowns above low tide ──
    final gallery = room('ghost_gallery');
    final pearlDoor = gallery.doors.firstWhere(
      (d) => d.targetRoomId == 'pearl_vault',
    );
    expect(
      game.isDoorLocked(gallery, pearlDoor),
      isTrue,
      reason: 'high water drowns the pearl passage',
    );

    // ── Star 2: float the moon-lantern out to the sea ──
    game.currentRoomId = 'ghost_gallery';
    Offset nodeAt(String id) =>
        gallery.canalNodes.firstWhere((n) => n.id == id).position;
    // The wheels live in the COURT now, one door west of the canal.
    Offset wheelAt(int stand) =>
        court.tideValves.firstWhere((v) => v.level == stand).position;

    // The Spirit reads the deep cuts before committing anything to the water
    // — the same first move a player makes, and pure foresight either way.
    game.setActive(1); // Spirit mask
    teleport('ghost_gallery', gallery.bounds.center);
    game.activateAbility();
    expect(
      game.sumpsRead,
      isTrue,
      reason: 'Spirit names the deep cuts for the rest of the run',
    );

    // The player reads the stone and plans a route. So does the test — using
    // the game's OWN solver, which walks the game's OWN sill and spill rules,
    // so this stays a real playthrough instead of a script free to rot away
    // from the mechanic it is meant to be exercising.
    final proof = game.solveLanternDrift();
    expect(proof.solvable, isTrue, reason: 'the canals must be floatable');
    expect(proof.strandable, 0, reason: 'and must not be able to strand us');

    void setDams(List<String> want) {
      game.setActive(2); // the Ice mane plugs the basins
      final target = want.toSet();
      for (final id in {...game.dammedNodes, ...target}) {
        if (game.dammedNodes.contains(id) == target.contains(id)) continue;
        teleport('ghost_gallery', nodeAt(id));
        game.activateAbility();
      }
      expect(game.dammedNodes, target);
    }

    void setStand(int stand) {
      // Out to the court, turn the wheel, back to the water. The lantern is
      // frozen for the whole trip — the temple holds its breath behind you.
      game.setActive(0); // the Water pip works the wheels
      teleport('drowned_court', wheelAt(stand));
      game.activateAbility();
      expect(game.tideLevel, stand, reason: 'the wheel answers Water at once');
      settleTide();
      game.currentRoomId = 'ghost_gallery';
    }

    var standing = 'spring';
    for (final leg in proof.route) {
      expect(leg.from, standing, reason: 'the route must be connected');
      // Commit the ice and the water BEFORE the lantern is at the fork.
      setDams(leg.dams);
      setStand(leg.stand);
      if (game.lanternNodeId == null) {
        // Any hand may float it — the lamp is not an elemental act.
        game.setActive(1);
        teleport('ghost_gallery', nodeAt('spring'));
        game.activateAbility();
        expect(game.lanternLit, isTrue, reason: 'the wick catches');
        expect(game.progressReadout?.label, 'LANTERN');
        expect(game.progressReadout?.value, 'ADRIFT');
      }
      final arrived = _driftUntil(
        game,
        () => game.lanternNodeId == leg.to && game.lanternChannel == null,
        seconds: 60,
      );
      expect(arrived, isTrue, reason: 'the lantern must ride $leg');
      standing = leg.to;
    }
    expect(
      game.lanternLosses,
      0,
      reason: 'a proved route, played as proved, never loses the lantern',
    );
    expect(standing, 'sea');
    expect(game.hasStar(1), isTrue, reason: 'the sea drain banks Star 2');
    expect(game.guardianRiteUnlocked, isTrue);
    expect(
      game.isDoorLocked(court, mirrorGate),
      isFalse,
      reason: 'Tide and Current part the mirror gate',
    );
    clearWisps();

    // ── Star 3: the moon-pools at the settled MIDDLE water ──
    final well = room('moon_well');
    Offset poolAt(String id) =>
        well.moonPools.firstWhere((p) => p.id == id).position;
    final pipMouth = well.tideValves.single.position;

    // THE BROKEN MAIN is plugged by STANDING in it, and only by a Water pip.
    game.setActive(2); // Ice mane
    teleport('moon_well', pipMouth);
    game.update(1 / 60);
    expect(
      game.spoutPlugged,
      isFalse,
      reason: 'an Ice mane in the mouth is not a plug',
    );
    game.setActive(0);
    teleport('moon_well', pipMouth);
    game.update(1 / 60);
    expect(game.spoutPlugged, isTrue, reason: 'the pip fits the mouth');
    // And stepping away opens it again — it is a place, not a switch.
    teleport('moon_well', room('moon_well').bounds.center);
    game.update(1 / 60);
    expect(game.spoutPlugged, isFalse);
    teleport('moon_well', pipMouth);
    game.update(1 / 60);

    // The pearl passage is bared from the wheels, as everywhere else.
    game.setActive(0);
    teleport('drowned_court', wheelAt(0));
    game.activateAbility();
    expect(game.tideLevel, 0);
    settleTide();
    expect(
      game.isDoorLocked(gallery, pearlDoor),
      isFalse,
      reason: 'low water bares the pearl passage',
    );

    // ── The pearl vault's cache, behind the low-tide passage ──
    teleport('pearl_vault', room('pearl_vault').vaultCache!);
    step();
    expect(
      discovered,
      contains('cache:water_vault'),
      reason: 'the pearl vault pays its bottled essence, once',
    );

    // ── THE MOON WELL. Three hands: Spirit wanes the moon, the pip calms
    // the well, Ice locks a basin when the moon stands where it wants. ──
    final wants = Map<String, int>.from(game.poolWants);
    expect(wants.length, 4, reason: 'all four basins listen');
    expect(
      wants.values.toSet(),
      hasLength(4),
      reason: 'and no two want the same moon',
    );

    /// Walk the moon to [notch] with Spirit, and let it settle there.
    void moonTo(int notch) {
      game.setActive(1); // the Spirit mask owns the dial
      teleport('moon_well', well.moonDial!);
      var guard = 0;
      // Spirit only ever WANES. Going the other way means letting the sky do
      // it, which is the room's whole clock — so the test waits, exactly as a
      // player does.
      while (game.moonNotch != notch && guard++ < 4000) {
        if (game.moonNotch > notch) {
          game.activateAbility();
        } else {
          game.update(1 / 60);
        }
      }
      expect(game.moonNotch, notch, reason: 'the moon comes to $notch');
      _plugSpout(game);
      _settleWell(game);
      game.moonHoldT = _kPoolHoldForTest;
    }

    // A basin refuses a moon that is not its own.
    final ids = wants.keys.toList();
    moonTo(wants[ids[0]]!);
    game.setActive(2); // Ice
    teleport('moon_well', poolAt(ids[1]));
    game.activateAbility();
    expect(
      game.poolStates[ids[1]] ?? 0,
      0,
      reason: 'this basin is waiting for a different moon',
    );
    expect(
      game.combatEnemies.where((e) => !e.isDead),
      isEmpty,
      reason: 'a wrong moon is not a punishment',
    );

    // All four, each at the moon it asked for — and IN ORDER. The ice
    // displaces water, so once two basins stand the well rides higher and the
    // two whose stand sat at the top of their band are out of reach. Those go
    // first. The pip never leaves the mouth of the main; Spirit and Ice walk.
    bool fragile(String id) =>
        moonStandForLocks(wants[id]!, kMoonRiseAfterLocks) !=
        moonStandFor(wants[id]!);
    final ordered = [...ids.where(fragile), ...ids.where((i) => !fragile(i))];
    expect(
      ids.where(fragile).length,
      2,
      reason: 'two of the four are drowned by the rise',
    );
    for (final id in ordered) {
      moonTo(wants[id]!);
      game.setActive(2);
      teleport('moon_well', poolAt(id));
      game.activateAbility();
      expect(game.poolStates[id], 1, reason: 'basin $id takes its moon');
    }
    expect(game.moonBridgeWhole, isTrue);
    expect(
      game.guardianAwake,
      isTrue,
      reason: 'the bridged well wakes the deep',
    );
    expect(
      game.combatEnemies.where((e) => !e.isDead && e.isElite).length,
      greaterThanOrEqualTo(3),
      reason: 'and the deep sends its wardens up',
    );
    for (final e in game.combatEnemies) {
      e.hp = 0;
    }
    clearWisps();

    // The maxim wants the settled MID water, and the moon has been moved all
    // over the sky — put it back.
    game.setActive(0);
    teleport('drowned_court', wheelAt(1));
    game.activateAbility();
    settleTide();

    // ── The Lost Maxim: STILL the water, then take the moon out of it ──
    //
    // The reflection runs because the water runs. Ice on a moving moon is
    // refused; a Water creature standing motionless in the pool flattens it
    // to glass and the moon comes to rest in the middle of it.
    game.currentRoomId = 'reflection_court';
    game.setActive(0); // the Water pip stands in the pool and does not move
    teleport('reflection_court', const Offset(320, 330));
    for (var i = 0; i < 60 * 5; i++) {
      game.update(1 / 60);
    }
    expect(
      game.mirrorIsGlass,
      isTrue,
      reason: 'standing still in the pool flattens it',
    );
    game.setActive(2); // Ice
    final glint = game.frozenMoonGlint();
    expect(glint, isNotNull, reason: 'mid tide floats the moon glint');
    game.creatures[2]
      ..position = glint!
      ..lastSafe = glint;
    game.activateAbility();
    // THE RITE OF THREE runs before the gold lands (see `beginMaximRite`).
    for (var tick = 0; tick < 200; tick++) {
      game.update(1 / 60);
    }
    expect(
      discovered,
      contains(kWaterFrozenMoonEggId),
      reason: 'ice on the glint freezes the moon (screen pays the 20 gold)',
    );

    // ── The Leviathan: paced lull strikes until it yields ──
    final guardianNode = room('leviathan_depths').guardian!;
    teleport('leviathan_depths', guardianNode.position + const Offset(0, 80));
    var safety = 0;
    while (!game.hasStar(2) && safety++ < 900) {
      final leviathan = game.combatEnemies.where((e) => e.isElite).firstOrNull;
      if (leviathan != null && !leviathan.isDead) {
        leviathan.position = game.creatures[game.activeIndex].position;
      }
      if (game.guardianVulnerable) game.activateAbility();
      step(0.3);
    }
    expect(game.hasStar(2), isTrue, reason: 'lull strikes fell the guardian');
    expect(
      game.leviathanRoars,
      greaterThan(0),
      reason: 'the deep turned the tide during the fight',
    );
    expect(game.relicDropActive, isTrue);

    expect(earned, [0, 1, 2], reason: 'stars bank in play order, once each');
    expect(game.starsEarnedCount, 3);
  });

  // ── Star 2: the sill rule and the spill rule ─────────────

  test('THE SILL RULE: what runs at which stand of water', () {
    final game = _harness([_member(0, 'Water', 'pip')]);
    // low 0.0 · mid 0.5 · high 1.0 — the same scale as tideAnim.
    for (final water in const [0.0, 0.5, 1.0]) {
      expect(
        game.canalChannelLive(CanalSill.low, water),
        isTrue,
        reason: 'a floor groove runs at every stand',
      );
    }
    expect(game.canalChannelLive(CanalSill.mid, 0.0), isFalse);
    expect(game.canalChannelLive(CanalSill.mid, 0.5), isTrue);
    expect(game.canalChannelLive(CanalSill.mid, 1.0), isTrue);

    expect(game.canalChannelLive(CanalSill.crest, 0.0), isFalse);
    expect(game.canalChannelLive(CanalSill.crest, 0.5), isFalse);
    expect(
      game.canalChannelLive(CanalSill.crest, 1.0),
      isTrue,
      reason: 'only the high water crests it',
    );

    // The deep cut: an ordinary groove at low and middle, and a TORRENT at
    // high — which is the one thing about the network you can learn the
    // expensive way instead of reading it.
    expect(game.canalChannelLive(CanalSill.deep, 0.0), isTrue);
    expect(game.canalChannelLive(CanalSill.deep, 0.5), isTrue);
    expect(game.canalChannelLive(CanalSill.deep, 1.0), isFalse);
    expect(game.canalChannelTorrent(CanalSill.deep, 1.0), isTrue);
    expect(game.canalChannelTorrent(CanalSill.deep, 0.5), isFalse);
    expect(
      game.canalChannelTorrent(CanalSill.low, 1.0),
      isFalse,
      reason: 'only a DEEP cut drowns',
    );

    // The sills line up with the tide zones exactly, so a groove starts
    // running on the same frame its chamber starts to flood.
    expect(game.canalSillThreshold(CanalSill.mid), 0.47);
    expect(game.canalSillThreshold(CanalSill.crest), 0.97);
  });

  test('THE SPILL RULE: a basin pours down the lowest live groove it has', () {
    final game = _harness([_member(0, 'Water', 'pip')]);
    String? spill(String from, int stand, [Set<String> dammed = const {}]) =>
        game.canalSpillFrom(from, water: stand / 2, dammed: dammed)?.to;

    // The north lock is the fork the tide alone decides: at low and middle
    // water the deep cut is the lowest thing on offer; at high it is a
    // torrent, so the water reaches for the next sill up.
    expect(spill('north_lock', 0), 'heart_basin');
    expect(spill('north_lock', 1), 'heart_basin');
    expect(
      spill('north_lock', 2),
      'blind_sump',
      reason:
          'at high water the deep cut is gone and the MID groove is the '
          'lowest live one — straight into the blind sump',
    );
    // …and the ice is what buys the crest.
    expect(
      spill('north_lock', 2, {'blind_sump'}),
      'east_shelf',
      reason: 'plug the sump and the water has to reach for the crest',
    );

    // The natural fall, all the way down, ends nowhere.
    expect(spill('heart_basin', 0), 'south_race');
    expect(spill('heart_basin', 2), 'blind_sump');
    expect(spill('south_race', 1), 'blind_sump');
    expect(spill('south_race', 2), 'blind_sump');
    expect(
      spill('south_race', 2, {'blind_sump'}),
      'sea',
      reason:
          'the sea groove is a crest, and it is never the lowest thing '
          'on offer — the ice has to take the alternative away',
    );
    expect(
      spill('south_race', 0, {'blind_sump'}),
      isNull,
      reason: 'nothing runs: the lantern simply turns and waits on the water',
    );

    // A dam can only ever take a destination AWAY. Nothing but the tide
    // opens a dry sill.
    expect(
      spill('north_lock', 0, {'heart_basin', 'blind_sump'}),
      isNull,
      reason: 'the crest stays dry at low water however much ice you lay',
    );
  });

  test('the blind sump is a visible dead end, and gives the lantern back', () {
    final game = _gallery([_member(0, 'Ice', 'mane')]);
    // The temple's own fall, played straight and never fought: no dams, and
    // the high water the deep cuts cannot take.
    game.tideLevel = 2;
    game.tideAnim = 1.0;
    _setLanternAt(game, 'spring');
    final ended = _driftUntil(game, () => !game.lanternLit, seconds: 90);
    expect(ended, isTrue, reason: 'the natural fall must end somewhere');
    expect(
      game.lanternLosses,
      1,
      reason:
          'spring → north lock → the blind sump, exactly as the stone '
          'says it would',
    );
    expect(
      game.lanternNodeId,
      'north_lock',
      reason:
          'the backwash hands it back to the last mouth it passed — the '
          'sump is a cost, never a trap',
    );
    expect(
      game.combatEnemies.where((e) => !e.isDead),
      isEmpty,
      reason: 'a dry loss is not punished; only the torrent rouses brine',
    );
    // And it is not softlocked there: the solver says the sea is still
    // reachable from that mouth, and so it is.
    expect(game.solveLanternDrift().strandable, 0);
  });

  test('the high water swallows a lantern still in a deep cut', () {
    final game = _gallery([_member(0, 'Water', 'pip')]);
    // From the MIDDLE water the deep cut still runs, and the flood to high is
    // one stand away — which is exactly the mistake this punishes.
    game.tideLevel = 1;
    game.tideAnim = 0.5;
    _setLanternAt(game, 'north_lock');
    // Let it commit to the deep cut down to the heart basin…
    _driftUntil(game, () => game.lanternChannel != null, seconds: 10);
    expect(game.lanternChannel?.sill, CanalSill.deep);
    _driftUntil(game, () => game.lanternT > 0.15, seconds: 10);
    // …then bring the high water in on top of it.
    game.tideLevel = 2;
    final lost = _driftUntil(game, () => !game.lanternLit, seconds: 20);
    expect(lost, isTrue);
    expect(
      game.lanternNodeId,
      'north_lock',
      reason: 'the sump spits it back into the basin it left',
    );
    expect(
      game.combatEnemies.where((e) => !e.isDead),
      isNotEmpty,
      reason: 'the torrent is loud, and the temple\'s old brine hears it',
    );
  });

  test('a groove that dries out grounds the lantern where it lies', () {
    final game = _gallery([_member(0, 'Water', 'pip')]);
    game.tideLevel = 2;
    game.tideAnim = 1.0;
    game.dammedNodes.add('blind_sump');
    _setLanternAt(game, 'north_lock');
    _driftUntil(game, () => game.lanternChannel != null, seconds: 10);
    expect(
      game.lanternChannel?.sill,
      CanalSill.crest,
      reason: 'the plugged sump forces the crest to the east shelf',
    );
    _driftUntil(game, () => game.lanternT > 0.3, seconds: 12);
    // Drop the water mid-crossing and the crest simply stops running.
    game.tideLevel = 1;
    final grounded = _driftUntil(game, () => !game.lanternLit, seconds: 20);
    expect(grounded, isTrue);
    expect(game.lanternNodeId, 'north_lock');
    expect(
      game.combatEnemies.where((e) => !e.isDead),
      isEmpty,
      reason: 'grounding on a bare sill costs the walk and nothing else',
    );
  });

  test('the lantern will not leave a basin while the water is moving', () {
    final game = _gallery([_member(0, 'Water', 'pip')]);
    _setLanternAt(game, 'north_lock');
    game.tideLevel = 2; // the flood begins, and the basin churns
    for (var i = 0; i < 60 * 6; i++) {
      game.update(1 / 60);
      if (!game.tideSettled) {
        expect(
          game.lanternChannel,
          isNull,
          reason:
              'it turns in the basin until the water settles — which is '
              'what makes a change begun in time still land',
        );
      }
    }
    expect(
      game.tideSettled,
      isTrue,
      reason: 'and six seconds is more than the ~4.5s a low→high flood takes',
    );
  });

  test('the spring always answers: a lost lantern can never end a run', () {
    final game = _gallery([_member(0, 'Water', 'pip')]);
    game.tideLevel = 2;
    game.tideAnim = 1.0;
    _setLanternAt(game, 'spring');
    _driftUntil(game, () => !game.lanternLit, seconds: 90);
    expect(game.lanternLit, isFalse);
    expect(game.lanternNodeId, isNot('spring'));

    // Any hand, any element: wade to the spring mouth and set it again.
    _act(
      game,
      game.layout.rooms['ghost_gallery']!.canalNodes
          .firstWhere((n) => n.isSpring)
          .position,
    );
    expect(game.lanternLit, isTrue);
    expect(game.lanternNodeId, 'spring');
  });

  test('a grounded lantern is re-lit by hand where it lies', () {
    final game = _gallery([_member(0, 'Ice', 'mane')]);
    game.tideLevel = 2;
    game.tideAnim = 1.0;
    _setLanternAt(game, 'spring');
    _driftUntil(game, () => !game.lanternLit, seconds: 90);
    final rest = game.lanternNodeId!;
    // Wait out the backwash so the lantern is truly at rest on the stone.
    for (var i = 0; i < 90; i++) {
      game.update(1 / 60);
    }
    _act(game, _nodeAt(game, rest));
    expect(game.lanternLit, isTrue);
    expect(game.lanternNodeId, rest, reason: 'it rides on from where it lay');
  });

  // ── Star 2: the ice ──────────────────────────────────────

  test(
    'the dam is element-only: every Ice family plugs a basin identically',
    () {
      for (final family in const [
        'pip',
        'mane',
        'horn',
        'mask',
        'wing',
        'kin',
      ]) {
        final game = _gallery([_member(0, 'Ice', family)]);
        _act(game, _nodeAt(game, 'blind_sump'));
        expect(game.dammedNodes, {
          'blind_sump',
        }, reason: 'an Ice $family must plug the basin');
        expect(
          game.combatEnemies.where((e) => !e.isDead),
          isEmpty,
          reason: 'and do it silently ($family)',
        );
        // Toggled: a second hand takes the plug back out, so no arrangement of
        // ice can ever be a dead end.
        _act(game, _nodeAt(game, 'blind_sump'));
        expect(game.dammedNodes, isEmpty);
      }
    },
  );

  test('only Ice plugs a basin — one clause, and nothing moves', () {
    // (Spirit is deliberately absent: a Spirit hand at a basin READS the
    // canals — the ordering that keeps the reading verb and the damming verb
    // off the same stone. Its own test is below.)
    for (final element in const ['Water', 'Fire', 'Light']) {
      final game = _gallery([_member(0, element, 'mane')]);
      _act(game, _nodeAt(game, 'blind_sump'));
      expect(game.dammedNodes, isEmpty, reason: '$element must be refused');
      game.askForRoomHint();
      expect(game.hintChannel, DungeonHintChannel.blocked);
      game.askForRoomHint();
      expect(game.hintText, 'Only Ice plugs a basin');
      expect(
        game.combatEnemies.where((e) => !e.isDead),
        isEmpty,
        reason: 'a clean refusal is not a penalty',
      );
    }
  });

  test('a Spirit hand at a basin READS the canals — it never plugs them', () {
    // The ordering that keeps the temple's Spirit+Water→Ice braid from
    // hijacking the reading verb: the dam is Ice, element-only, no recipe.
    final game = _gallery([_member(0, 'Spirit', 'mane')]);
    _act(game, _nodeAt(game, 'blind_sump'));
    expect(game.dammedNodes, isEmpty);
    expect(game.sumpsRead, isTrue);
    game.askForRoomHint();
    expect(game.hintChannel, DungeonHintChannel.insight);
  });

  test('the basin the lantern turns in will not take the ice', () {
    final game = _gallery([_member(0, 'Ice', 'mane')]);
    _setLanternAt(game, 'heart_basin');
    _act(game, _nodeAt(game, 'heart_basin'));
    expect(game.dammedNodes, isEmpty);
    game.askForRoomHint();
    expect(game.hintChannel, DungeonHintChannel.blocked);
    game.askForRoomHint();
    expect(game.hintText, contains('will not take'));
  });

  // ── Star 2: Spirit's reading is FORESIGHT, never the answer ──

  test('Spirit reads the deep cuts, and Intelligence buys the forecast', () {
    // t0 — the deep cuts are named. That is the whole of the low-Int reading,
    // and it is a thing the high water would have told you for free.
    final t0 = _gallery([_member(0, 'Spirit', 'mask', intelligence: 1)]);
    // The canal reveal is an ELEMENT verb (any Spirit), so the press still
    // does the work — it is only its TEXT that now waits to be asked for.
    t0.activateAbility();
    expect(t0.sumpsRead, isTrue);
    expect(t0.canalRevealTier, 0);
    // ONE press delivers the reading the verb earned. Pressing again would
    // move on to the room's own reveal, so the assertions share a press.
    t0.askForRoomHint();
    expect(t0.hintChannel, DungeonHintChannel.insight);
    expect(t0.hintText, contains('deep cuts'));
    expect(t0.hintText, contains('torrent'));

    // t1 — …and where the water would take the lantern NEXT.
    final t1 = _gallery([_member(0, 'Spirit', 'mask', intelligence: 3)]);
    t1.activateAbility();
    expect(t1.canalRevealTier, 1);
    t1.askForRoomHint();
    expect(t1.hintText, contains('next'));

    // t2 — …and the whole fall, at the water as it stands. Still not the
    // answer: the answer is which stands to hold, and when.
    final t2 = _gallery([_member(0, 'Spirit', 'mask', intelligence: 5)]);
    t2.activateAbility();
    expect(t2.canalRevealTier, 2);
    t2.askForRoomHint();
    expect(t2.hintText, contains('whole fall'));

    // The forecast rides a timer Intelligence buys; the NAMING does not.
    expect(t2.canalRevealTimer, greaterThan(t0.canalRevealTimer));
    for (var i = 0; i < 60 * 30; i++) {
      t0.update(1 / 60);
    }
    expect(t0.canalRevealTimer, lessThanOrEqualTo(0));
    expect(
      t0.sumpsRead,
      isTrue,
      reason: 'a warning you cannot look at twice is only a memory test',
    );
  });

  test('a non-Spirit Mask still reads the frieze — the rules were never the '
      'secret', () {
    // Standing clear of every basin, an insight press IS the reading.
    final game = _gallery([_member(0, 'Ice', 'mask', intelligence: 5)]);
    game.activateAbility();
    expect(game.sumpsRead, isFalse, reason: 'the foresight stays Spirit\'s');
    game.askForRoomHint();
    expect(game.hintText, contains('LOWEST'));
    game.askForRoomHint();
    expect(
      game.hintText,
      contains('sill'),
      reason: 'the frieze is where the temple wrote its own two rules down',
    );
  });

  // ── Star 2: the readout and the objective line ───────────

  test('the readout says where the lantern stands, and the doorway does not '
      'teach', () {
    final game = _gallery([_member(0, 'Water', 'pip')]);
    expect(game.progressReadout?.label, 'LANTERN');
    expect(game.progressReadout?.value, 'UNSET');
    _setLanternAt(game, 'spring');
    expect(game.progressReadout?.value, 'ADRIFT');
    game.tideLevel = 2;
    game.tideAnim = 1.0;
    _driftUntil(game, () => !game.lanternLit, seconds: 90);
    expect(game.progressReadout?.value, 'AGROUND');
  });

  test('walking through a doorway says nothing at all', () {
    final game = _harness([_member(0, 'Water', 'pip')]);
    game.currentRoomId = 'drowned_court';
    final door = game.currentRoom.doors.firstWhere(
      (d) => d.targetRoomId == 'ghost_gallery',
    );
    game.creatures[game.activeIndex].position = door.rect.center;
    for (var i = 0; i < 12; i++) {
      game.update(1 / 60);
    }
    expect(game.currentRoomId, 'ghost_gallery');
    // WAS: the doorway announced the room's goal. It no longer announces
    // anything — arriving somewhere is not a reason to speak, and the old
    // no-method rule it enforced is moot once the line does not exist.
    expect(
      game.hintText,
      isNull,
      reason: 'crossing a threshold is not an event worth narrating',
    );
    // What the room holds is still available — the player asks for it. Note
    // the reading IS allowed to teach method (§5.6 always let insight do
    // that); the no-leak rule belonged to the objective line, which is gone.
    game.askForRoomHint();
    expect(game.hintText, isNotNull);
    expect(game.hintChannel, DungeonHintChannel.insight);
  });

  // ── The Leviathan turns the tide (§7 retrofit) ───────────

  PlanetDungeonGame leviathanFight() {
    final game = _harness([_member(0, 'Water', 'pip')]);
    game.starMask = (1 << 0) | (1 << 1);
    game.currentRoomId = 'leviathan_depths';
    final node = game.layout.rooms['leviathan_depths']!.guardian!;
    final stand = node.position + const Offset(0, 200);
    game.creatures.single
      ..position = stand
      ..lastSafe = stand;
    game.guardianAwake = true;
    return game;
  }

  test('Leviathan hauls the tide a stand on every roar, low→mid→high→mid', () {
    final game = leviathanFight();
    final stands = <int>{game.tideLevel};
    for (var i = 0; i < 60 * 40; i++) {
      game.update(1 / 60);
      game.creatures.single.hp = game.creatures.single.maxHp;
      stands.add(game.tideLevel);
    }
    expect(
      game.leviathanRoars,
      greaterThanOrEqualTo(4),
      reason: 'the roar rides the shut of every lull',
    );
    expect(
      stands,
      {0, 1, 2},
      reason:
          'the fight is played across ALL THREE stands — the tide rolls, '
          'it does not park',
    );
  });

  test('the lull only opens on SETTLED water — the swell is its armour', () {
    final game = leviathanFight();
    var sawMovingWater = false;
    var sawWindow = false;
    for (var i = 0; i < 60 * 40; i++) {
      game.update(1 / 60);
      game.creatures.single.hp = game.creatures.single.maxHp;
      if (!game.tideSettled) {
        sawMovingWater = true;
        expect(
          game.guardianVulnerable,
          isFalse,
          reason: 'nothing touches Leviathan while it rides the swell',
        );
      } else if (game.guardianVulnerable) {
        sawWindow = true;
      }
    }
    expect(sawMovingWater, isTrue, reason: 'the arena really did turn');
    expect(
      sawWindow,
      isTrue,
      reason: 'and the fight stays winnable: settled water still lulls',
    );
  });

  test('the drowned arena answers the tide like every other chamber', () {
    final game = leviathanFight();
    final zones = game.layout.rooms['leviathan_depths']!.tideZones;
    expect(zones.any((z) => !z.ledge), isTrue, reason: 'a sink to swim');
    expect(
      zones.any((z) => z.ledge),
      isTrue,
      reason: 'and piers that drown at high water',
    );
    // Nothing the tide can raise may stand across the way back in.
    final door = game.layout.rooms['leviathan_depths']!.doors.single;
    for (final z in zones.where((z) => z.ledge)) {
      expect(
        z.rect.inflate(24).overlaps(door.rect),
        isFalse,
        reason: 'a rearing pier must never seal the exit',
      );
    }
  });

  test('the tide turns in a raid — the arena carries its own zones', () {
    // This used to assert the opposite. Leviathan was exempt because the
    // generated arena had no tide, which left it — and every other guardian —
    // playing as a plain charging phantom.
    //
    // Also note the star mask: this test used to pass 7, which would have
    // short-circuited the mechanic on hasStar regardless. Raids really run
    // with 0.
    final game = PlanetDungeonGame(
      element: 'Water',
      party: [_member(0, 'Water', 'pip')],
      initialStarMask: 0,
      onStarEarned: (_) {},
      onPlayerDown: () {},
      onChanged: () {},
      raid: const RaidConfig(),
      layoutOverride: buildRaidArenaLayout('Water'),
    );
    final c = DungeonCreature(member: game.party.single)
      ..position = game.layout.entranceSpawn
      ..lastSafe = game.layout.entranceSpawn;
    game.creatures.add(c);
    game.currentRoomId = game.layout.entranceRoomId;
    expect(game.currentRoom.tideZones, isNotEmpty);

    for (var i = 0; i < 60 * 25; i++) {
      game.update(1 / 60);
      c.hp = c.maxHp;
    }
    expect(
      game.leviathanRoars,
      greaterThan(0),
      reason: 'the guardian should be hauling the tide on its cycle',
    );
  });

  // ── Invariants the rework was not allowed to touch ───────

  // v2: the master wheels are ELEMENT-ONLY — every Water family sets the stand
  // at once, silently.
  test('the master valve is element-only: every Water family sets the stand '
      'identically', () {
    for (final family in const ['pip', 'mane', 'horn', 'mask', 'wing', 'kin']) {
      final game = _harness([_member(0, 'Water', family)]);
      final valve = game.layout.rooms['tide_works']!.tideValves.firstWhere(
        (v) => v.level == 1,
      );
      game.currentRoomId = 'tide_works';
      game.creatures.single
        ..position = valve.position
        ..lastSafe = valve.position;

      game.activateAbility();
      expect(
        game.tideLevel,
        1,
        reason: 'a Water $family turns the wheel INSTANTLY — no waiting',
      );
      expect(
        game.combatEnemies.where((e) => !e.isDead),
        isEmpty,
        reason: 'a Water $family turns the wheel SILENTLY — no brine',
      );
    }
  });

  test('the pipe-mouth is a hard gate: only a Water pip cycles the tide', () {
    // Right element, wrong family: refused outright — the tide does not move,
    // now or later, and nothing is roused by the refusal.
    for (final family in const ['mane', 'horn', 'mask', 'wing', 'kin']) {
      final game = _harness([_member(0, 'Water', family)]);
      final mouth = game.layout.rooms['moon_well']!.tideValves.single;
      game.currentRoomId = 'moon_well';
      game.creatures.single
        ..position = mouth.position
        ..lastSafe = mouth.position;
      game.update(1 / 60);
      // The mouth is plugged by standing in it now, and only a Water PIP
      // fits — so what the gate protects, and what this asserts, is the plug.
      expect(
        game.spoutPlugged,
        isFalse,
        reason: 'a Water $family must never fit the pipe-mouth',
      );
      for (var i = 0; i < 400; i++) {
        game.update(1 / 60);
        game.creatures.single.hp = game.creatures.single.maxHp;
      }
      expect(
        game.combatEnemies.where((e) => !e.isDead),
        isEmpty,
        reason: 'a clean refusal is not a penalty — no brine rises',
      );
    }

    // A Water Pip works it at once — and what it works is the STILL.
    final pip = _harness([_member(0, 'Water', 'pip')]);
    final mouth = pip.layout.rooms['moon_well']!.tideValves.single;
    pip.currentRoomId = 'moon_well';
    pip.creatures.single
      ..position = mouth.position
      ..lastSafe = mouth.position;
    pip.update(1 / 60);
    expect(
      pip.spoutPlugged,
      isTrue,
      reason: 'the Pip fits the mouth and the main chokes',
    );
    expect(
      pip.combatEnemies.where((e) => !e.isDead),
      isEmpty,
      reason: 'the Pip rides the pipes silently',
    );
  });

  test('the broken main is what makes the pip load-bearing', () {
    // While it runs the well stands ABOVE the moon, so no basin will agree
    // with the sky — which is what pins the pip in place while the other two
    // work the moon. If this ever stops being true the pip is decoration.
    final g = _moonWellReady(_member(1, 'Ice', 'mane'));
    g.update(1 / 60);
    expect(g.spoutPlugged, isTrue, reason: 'the harness parks the pip in it');
    _settleWell(g);
    expect(g.wellAgreesWithMoon, isTrue);

    // Walk the pip out of the mouth and the main opens.
    g.creatures[0].position = g.currentRoom.bounds.center;
    g.update(1 / 60);
    expect(g.spoutPlugged, isFalse);
    expect(
      g.wellStand,
      greaterThan(moonStandFor(g.moonNotch)),
      reason: 'the running main holds the well above the moon',
    );
    for (var i = 0; i < 60 * 6; i++) {
      g.update(1 / 60);
      g.moonWaxT = 0;
    }
    expect(
      g.wellAgreesWithMoon,
      isFalse,
      reason: 'and nothing in the room will agree with the sky while it runs',
    );

    // A basin refuses outright, and costs nothing for it.
    final e = g.poolWants.entries.first;
    g.moonNotch = e.value;
    g.moonHoldT = 99;
    final pool = g.currentRoom.moonPools.firstWhere((p) => p.id == e.key);
    g.setActive(1);
    g.creatures[1]
      ..position = pool.position
      ..lastSafe = pool.position;
    g.activateAbility();
    expect(g.poolStates[e.key] ?? 0, 0);
    expect(g.combatEnemies.where((x) => !x.isDead), isEmpty);
  });

  test('the basin is element-only, but the recipe keeps its downside', () {
    // Every ICE family locks a listening basin clean and SILENT…
    for (final family in const ['pip', 'mane', 'horn', 'mask', 'wing', 'kin']) {
      final game = _moonWellReady(_member(1, 'Ice', family));
      final (id, want) = _listening(game);
      _parkMoon(game, want);
      final pool = game.layout.rooms['moon_well']!.moonPools.firstWhere(
        (p) => p.id == id,
      );
      _plugSpout(game);
      game.creatures[1]
        ..position = pool.position
        ..lastSafe = pool.position;
      game.setActive(1);
      game.activateAbility();
      expect(
        game.poolStates[pool.id],
        1,
        reason: 'an Ice $family must lock the basin',
      );
      expect(
        game.combatEnemies.where((e) => !e.isDead),
        isEmpty,
        reason: 'ice laid DIRECT is silent for every family ($family)',
      );
    }

    // …while the Spirit+Water→Ice RECIPE still rouses the brine. That is the
    // braid's cost, not a family penalty.
    final spirit = _moonWellReady(_member(1, 'Spirit', 'mane'));
    final (id, want) = _listening(spirit);
    _parkMoon(spirit, want);
    final pool = spirit.layout.rooms['moon_well']!.moonPools.firstWhere(
      (p) => p.id == id,
    );
    _plugSpout(spirit);
    spirit.creatures[1]
      ..position = pool.position
      ..lastSafe = pool.position;
    spirit.setActive(1);
    spirit.activateAbility();
    expect(spirit.poolStates[pool.id], 1, reason: 'the braid locks it too');
    expect(
      spirit.combatEnemies.where((e) => !e.isDead),
      isNotEmpty,
      reason: 'the recipe keeps its wisps',
    );
  });
}
