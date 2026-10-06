// THE HEART, played through the real game: down through the seal, Blood is
// taken and the four pour in; then the proved plan — every fusion made by
// walking two creatures onto an altar's stones and standing still, every
// split by standing a fused creature on the split stage — until Light and
// Dark make Blood, Blood is free, the four re-form beside it, the second
// star is banked and Sanguorath wakes below.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart'
    show CosmicSurvivalCompanion;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_blood_heart.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_blood_rites.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_blood.dart';
import 'package:alchemons/games/shared/alchemon_combat_stats.dart';
import 'package:flutter/painting.dart' show Offset;
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _blood() => CosmicPartyMember(
  instanceId: 'inst_0',
  baseId: 'base_0',
  displayName: 'Blood Mane',
  element: 'Blood',
  family: 'mane',
  level: 10,
  statSpeed: 3,
  statIntelligence: 3,
  statStrength: 3,
  statBeauty: 3,
  slotIndex: 0,
  staminaBars: 3,
  staminaMax: 3,
);

Future<PlanetDungeonGame> harness({void Function(int)? onStar}) async {
  final party = [_blood()];
  final g = PlanetDungeonGame(
    element: 'Blood',
    party: party,
    initialStarMask: 1, // all four freed before: the first star
    onStarEarned: onStar ?? (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  g.currentRoomId = g.layout.entranceRoomId;
  g.starMask = 1;
  for (final el in kRiteElements) {
    g.discoveredClouds.add(riteFreedId(el));
  }
  for (final m in party) {
    final c = DungeonCreature(member: m)
      ..position = g.layout.entranceSpawn
      ..lastSafe = g.layout.entranceSpawn;
    g.creatures.add(c);
    final s = deriveAlchemonCombatStats(member: m);
    g.combatCompanions.add(
      CosmicSurvivalCompanion(
        member: m,
        slotIndex: m.slotIndex,
        position: c.position,
        anchor: c.position,
        maxHp: s.maxHp,
        currentHp: s.maxHp,
        physAtk: s.physAtk,
        elemAtk: s.elemAtk,
        abilityAtk: s.elemAtk,
        physDef: s.physDef,
        elemDef: s.elemDef,
        cooldownReduction: s.cooldownReduction,
        attackRange: s.attackRange,
        specialAbilityRange: s.specialAbilityRange,
        tethered: false,
        invincibleTimer: 0,
      ),
    );
  }
  await g.debugLoadRiteAllies();
  g.update(1 / 60);
  return g;
}

void tick(PlanetDungeonGame g, [int n = 1]) {
  for (var i = 0; i < n; i++) {
    g.update(1 / 60);
  }
}

void enter(PlanetDungeonGame g, String room) {
  final d = g.currentRoom.doors.firstWhere((d) => d.targetRoomId == room);
  g.passThroughDoor(d);
  tick(g, 2);
}

/// Let whatever is moving in the Heart finish.
void settle(PlanetDungeonGame g) {
  for (var i = 0; i < 1200; i++) {
    final h = g.rites.heart;
    if (h.morphs.isEmpty && h.powers.isEmpty && h.captureT < 0 && h.finaleT < 0) break;
    g.update(1 / 60);
  }
  tick(g, 2);
}

/// Steer the creature of [el] (standing on [from], when two share an
/// element) to [to], square by square, then stand it still.
void goTo(PlanetDungeonGame g, String el, RiteCell to, {RiteCell? from}) {
  final r = g.rites.heart.room;
  final i = g.creatures.indexWhere(
    (c) =>
        c.member.element == el &&
        (from == null || riteSquareAt(c.position) == from),
  );
  expect(i, greaterThanOrEqualTo(0), reason: 'no $el${from == null ? '' : ' at $from'}');
  g.setActive(i);
  final a = g.creatures[i];
  for (var guard = 0; guard < 40; guard++) {
    final at = riteSquareAt(a.position);
    if (at == to) break;
    // Breadth-first over the open floor.
    final prev = <RiteCell, RiteCell>{};
    final q = [at];
    final seen = {at};
    while (q.isNotEmpty) {
      final c = q.removeAt(0);
      if (c == to) break;
      for (var d = 0; d < 4; d++) {
        final n = (x: c.x + kRiteDx[d], y: c.y + kRiteDy[d]);
        if (!heartWalkable(r, g.rites.heart.state.cells, n.x, n.y) || !seen.add(n)) continue;
        prev[n] = c;
        q.add(n);
      }
    }
    expect(prev.containsKey(to), isTrue, reason: 'no way from $at to $to');
    var next = to;
    while (prev[next] != at) {
      next = prev[next]!;
    }
    g.joystickDirection = Offset((next.x - at.x).toDouble(), (next.y - at.y).toDouble());
    for (var f = 0; f < 120 && riteSquareAt(a.position) != next; f++) {
      g.update(1 / 60);
    }
  }
  // Onto the middle of the square, then still.
  final mid = riteCentreOf(to.x, to.y);
  for (var f = 0; f < 60 && (a.position - mid).distance > 6; f++) {
    final d = mid - a.position;
    g.joystickDirection = d / d.distance;
    g.update(1 / 60);
  }
  g.joystickDirection = Offset.zero;
  tick(g, 40);
  settle(g);
}

int count(PlanetDungeonGame g, String el) =>
    g.creatures.where((c) => c.member.element == el).length;

void main() {
  test('THE HEART: taken, fused up to Blood, freed — the second star', () async {
    final stars = <int>[];
    final g = await harness(onStar: stars.add);
    tick(g, 3);
    expect(g.rites.cups, hasLength(4));
    enter(g, 'rite_heart');
    // THE CAPTURE: Blood comes apart and is bound; the four pour in.
    expect(g.rites.heart.captureT, greaterThanOrEqualTo(0));
    settle(g);
    expect(g.rites.heart.bound, isTrue);
    expect(g.creatures.map((c) => c.member.element).toSet(), {'Fire', 'Water', 'Earth', 'Air'});
    expect(g.riteResetShown, isTrue);

    // The four altars along the stage (back stone, front stone), each
    // facing up into the open space; the split stage at the west end.
    // Over altar 1 nothing hangs; over 2 a Spirit; over 3 a Spirit with Lava
    // above it; over 4 Earth.
    const a1b = (x: 2, y: 7), a1f = (x: 2, y: 6);
    const a2b = (x: 5, y: 7), a2f = (x: 5, y: 6);
    const a3b = (x: 8, y: 7), a3f = (x: 8, y: 6);
    const a4b = (x: 11, y: 7), a4f = (x: 11, y: 6);
    const split = (x: 1, y: 7);

    // 1. Air + Fire on altar 4: Lightning rises into the Earth, and the
    //    Crystal they make comes down to the altar.
    goTo(g, 'Air', a4b);
    goTo(g, 'Fire', a4f);
    expect(count(g, 'Crystal'), 1);
    expect(count(g, 'Lightning'), 0);
    expect(g.debugHeartState.cells[4][11], 'v', reason: 'the Earth is gone from up there');
    // 2. Split it: the Lightning, and the Earth from up there.
    goTo(g, 'Crystal', split);
    expect(count(g, 'Lightning'), 1);
    expect(count(g, 'Earth'), 2);
    expect(
      g.creatures.map((c) => riteSquareAt(c.position)).toSet(),
      hasLength(g.creatures.length),
      reason: 'nobody comes down on anybody',
    );
    // 3. Earth + Lightning on altar 3: Crystal rises into the Spirit; Light
    //    comes down, and the Lava behind the Spirit is uncovered.
    goTo(g, 'Lightning', a3b);
    goTo(g, 'Earth', a3f);
    expect(count(g, 'Light'), 1);
    goTo(g, 'Light', (x: 7, y: 7));
    // 4. Earth + Water on altar 3: Mud rises into the Lava → Poison.
    goTo(g, 'Earth', a3b);
    goTo(g, 'Water', a3f);
    expect(count(g, 'Poison'), 1);
    // 5. Split the Poison: Lava and Mud.
    goTo(g, 'Poison', split);
    expect(count(g, 'Lava'), 1);
    expect(count(g, 'Mud'), 1);
    // 6. Lava + Mud on altar 2: Poison rises into the Spirit → Dark.
    goTo(g, 'Lava', a2b);
    goTo(g, 'Mud', a2f);
    expect(count(g, 'Dark'), 1);
    // 7. Dark + Light → Blood: Blood is free, and the four re-form beside it.
    goTo(g, 'Light', a1b);
    goTo(g, 'Dark', a1f);
    settle(g);
    final h = g.rites.heart;
    expect(h.freed, isTrue);
    expect(stars, contains(1));
    expect(g.discoveredClouds, contains(kRiteHeartFreedId));
    expect(
      g.creatures.map((c) => c.member.element).toSet(),
      {'Blood', 'Fire', 'Water', 'Earth', 'Air'},
    );
    expect(g.active?.member.element, 'Blood');
    // The floor opens on Sanguorath, and it wakes.
    final down = g.currentRoom.doors.firstWhere((d) => d.targetRoomId == 'sanguorath_heart');
    expect(g.isDoorHidden(g.currentRoom, down), isFalse);
    tick(g, 3);
    expect(g.guardianAwake, isTrue);
  });

  test('RESET ROOM in the Heart: what was made comes apart, the four stand '
      'where they began', () async {
    final g = await harness();
    tick(g, 3);
    enter(g, 'rite_heart');
    settle(g);
    goTo(g, 'Air', (x: 11, y: 7));
    goTo(g, 'Fire', (x: 11, y: 6));
    expect(count(g, 'Crystal'), 1);
    expect(g.debugHeartState.cells[4][11], 'v', reason: 'the Earth is gone from up there');
    g.resetRiteRoom();
    tick(g, 2);
    expect(g.creatures.map((c) => c.member.element).toSet(), {'Fire', 'Water', 'Earth', 'Air'});
    expect(g.debugHeartState.cells[4][11], kHeartHanging, reason: 'and back');
    expect(g.rites.heart.bound, isTrue, reason: 'Blood stays bound');
  });

  test('the planet\'s heart is felt: at rest every 0.9s, racing while Blood '
      'is taken', () async {
    final g = await harness();
    final felt = <double>[];
    var t = 0.0;
    g.onHaptic = (k) {
      if (k == DungeonHaptic.heartbeat) felt.add(t);
    };
    void run(double secs) {
      for (var i = 0; i < (secs * 60).round(); i++) {
        g.update(1 / 60);
        t += 1 / 60;
      }
    }

    // In the Circle, at rest: the portal's beat.
    run(9.05);
    expect(felt, hasLength(10));
    for (var i = 1; i < felt.length; i++) {
      expect(felt[i] - felt[i - 1], closeTo(.9, .02));
    }
    // Down into the Heart: Blood is taken and the beat quickens.
    felt.clear();
    enter(g, 'rite_heart');
    run(1.2);
    final from = felt.length;
    run(2.4);
    final racing = felt.length - from;
    expect(racing, greaterThan(2.4 / .9), reason: 'quicker than at rest');
  });

  test('a pair with no recipe does not fuse', () async {
    final g = await harness();
    tick(g, 3);
    enter(g, 'rite_heart');
    settle(g);
    goTo(g, 'Fire', (x: 2, y: 7));
    goTo(g, 'Water', (x: 2, y: 6));
    expect(count(g, 'Steam'), 1, reason: 'nothing hangs over altar 1: it stays Steam');
    goTo(g, 'Steam', (x: 5, y: 6));
    goTo(g, 'Earth', (x: 5, y: 7)); // Earth + Steam: nothing
    expect(count(g, 'Steam'), 1);
    expect(count(g, 'Earth'), 1);
  });
}
