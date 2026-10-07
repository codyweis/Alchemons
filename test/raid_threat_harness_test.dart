@Tags(['preview'])
library;

// RAID THREAT HARNESS — measures what a raid does to the squad.
//
// Not a pass/fail test: it prints one line per raid. Run with
//   flutter test test/raid_threat_harness_test.dart --tags preview
// Nobody's health is refilled. The other four follow the game's own idle AI.
// The active Alchemon follows a [Stance]. Never park it at exactly 90 px:
// that is the edge of both the rage aura (< 90) and the lull strike's reach
// (<= 90), so whether the aura lands depends on which way the guardian
// drifted that frame. The 2026-10-07 baseline did, and its "Let Lava
// carries L1" finding was that artifact. `taken=` is the damage each slot
// took, which is how you check it is spread across the squad rather than
// poured into the front line.
// See docs/plans/raid_threat_plan.md.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/raid_state.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _m(int slot, String element, String family, double stat) =>
    CosmicPartyMember(
      instanceId: 'r$slot',
      baseId: 'b$slot',
      displayName: '$element $family',
      element: element,
      family: family,
      level: 10,
      statSpeed: stat,
      statIntelligence: stat,
      statStrength: stat,
      statBeauty: stat,
      slotIndex: slot,
      staminaBars: 9,
      staminaMax: 9,
    );

/// Where the active Alchemon stands.
enum Stance {
  /// 60 px off the guardian the whole fight: inside the rage aura.
  hug,

  /// 130 px off (outside the aura) until a lull opens, then 60 px to strike.
  step,
}

class RaidRun {
  RaidRun(this.cleared, this.seconds, this.downs, this.taken, this.healed);
  final bool cleared;
  final double seconds;
  final List<String> downs;
  final List<double> taken;
  final List<double> healed;

  @override
  String toString() {
    final share = [for (final x in taken) x.round()].join('/');
    final heal = [for (final x in healed) x.round()].join('/');
    return '${cleared ? 'CLEAR' : 'WIPE '} ${seconds.round()}s '
        'downs=${downs.join(",")} taken=$share healed=$heal';
  }
}

/// One raid. [squad] is a list of 'Element/family'. When [healer] is set,
/// that slot is played as a healer: whenever anyone standing is under 60%
/// and its special is ready, swap to it, cast, and swap back. A healer only
/// casts when it is the active Alchemon, so an idle one heals nothing.
RaidRun raid(
  String arena,
  int level,
  double stat,
  List<String> squad, {
  Stance stance = Stance.step,
  int? healer,
  RaidConfig? config,
}) {
  final members = [
    for (var i = 0; i < squad.length; i++)
      _m(i, squad[i].split('/')[0], squad[i].split('/')[1], stat),
  ];
  var wiped = false;
  var t = 0.0;
  final downs = <String>[];
  final g = PlanetDungeonGame(
    element: arena,
    party: members,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
    raid: config ?? RaidConfig(level: level),
    onRaidCleared: () async {},
    onRaidCreatureDown: (id) => downs.add(
      '${t.round()}s:${members.firstWhere((m) => m.instanceId == id).family}',
    ),
    onRaidWiped: () => wiped = true,
    layoutOverride: buildRaidArenaLayout(arena),
  );
  g.onGameResize(Vector2(412, 915));
  g.currentRoomId = g.layout.entranceRoomId;
  final spawn = g.layout.entranceSpawn;
  for (var i = 0; i < members.length; i++) {
    final at = spawn + Offset((i - 2) * 50.0, 0);
    g.creatures.add(
      DungeonCreature(member: members[i])
        ..position = at
        ..lastSafe = at,
    );
    g.combatCompanions.add(g.debugCreateCombatCompanion(members[i], at));
  }
  final star = g.currentRoom.guardian!.starIndex;
  final prev = [for (final c in g.combatCompanions) c.currentHp];
  final taken = List<double>.filled(members.length, 0);
  final healed = List<double>.filled(members.length, 0);
  while (t < kRaidFightLimit.inSeconds) {
    final boss = g.combatEnemies.where((e) => e.isElite).firstOrNull;
    final a = g.active;
    if (a != null && a.alive && boss != null) {
      final off = stance == Stance.step && !g.guardianVulnerable ? 130.0 : 60.0;
      final stand = boss.position + Offset(0, off);
      a
        ..position = stand
        ..lastSafe = stand;
    }
    if (g.autoAttackReady) g.activateAutoAttack();
    if (g.abilityReady) g.activateCombatAbility();
    if (g.guardianVulnerable) g.activateAbility();
    final h = healer;
    if (h != null &&
        h != g.activeIndex &&
        g.creatures[h].alive &&
        g.combatCompanions[h].specialCooldown <= 0 &&
        g.creatures.any((c) => c.alive && c.hpFraction < 0.6)) {
      final back = g.activeIndex;
      g.setActive(h);
      if (g.abilityReady) g.activateCombatAbility();
      if (g.creatures[back].alive) g.setActive(back);
    }
    g.update(1 / 60);
    t += 1 / 60;
    for (var i = 0; i < g.combatCompanions.length; i++) {
      final now = g.combatCompanions[i].currentHp;
      if (now < prev[i]) taken[i] += prev[i] - now;
      if (now > prev[i]) healed[i] += now - prev[i];
      prev[i] = now;
    }
    if (g.hasStar(star)) return RaidRun(true, t, downs, taken, healed);
    if (wiped || g.creatures.every((c) => !c.alive)) {
      return RaidRun(false, t, downs, taken, healed);
    }
  }
  return RaidRun(false, t, downs, taken, healed);
}

const _core = ['Fire/wing', 'Earth/horn', 'Lightning/mane', 'Water/pip'];

const _squads = {
  // The squad the 2026-10-07 baseline was measured with.
  'lava': [..._core, 'Lava/let'],
  // The same squad without Let Lava.
  'mask': [..._core, 'Fire/mask'],
  // The same squad with a healer in the fifth slot.
  'heal': [..._core, 'Water/kin'],
};

/// Everything that heals, per the author's design boards: every Kin, and
/// the healing elements of the other families.
final _healers = [
  for (final e in [
    'Fire', 'Water', 'Earth', 'Air', 'Steam', 'Lava', 'Lightning', 'Mud',
    'Ice', 'Dust', 'Crystal', 'Plant', 'Poison', 'Spirit', 'Dark', 'Light',
    'Blood',
  ])
    '$e/kin',
  'Blood/horn',
  'Light/let',
  'Earth/let',
  'Blood/let',
  'Blood/pip',
  'Light/pip',
  'Blood/mane',
  'Water/wing',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('raid threat', () {
    for (final arena in const ['Air']) {
      for (final level in const [1, 2, 3]) {
        for (final stat in const [3.0, 4.5]) {
          for (final stance in Stance.values) {
            for (final entry in _squads.entries) {
              final run = raid(
                arena,
                level,
                stat,
                entry.value,
                stance: stance,
                healer: entry.key == 'heal' ? 4 : null,
              );
              // ignore: avoid_print
              print(
                '$arena L$level s$stat ${stance.name.padRight(4)} '
                '${entry.key.padRight(4)} $run',
              );
            }
          }
        }
      }
    }
  }, timeout: const Timeout(Duration(minutes: 30)));

  // The author's tier table, measured the way Phase 6 tuned it: three
  // squads (so no one ability decides it) on three planets, each without and
  // with a Water Kin in the fifth slot (played as a healer). Prints, per
  // tier and stat level, the clears and the losses per run, then holds the
  // mid squad (stats 3) to the table, loosely.
  test('tier table', () {
    const squads = [
      [..._core, 'Lava/let'],
      [..._core, 'Fire/mask'],
      ['Air/wing', 'Water/horn', 'Earth/mane', 'Fire/pip', 'Dark/mask'],
    ];
    final rows = <String, ({int clears, int runs, double meanLoss})>{};
    var worstShareL2Up = 0.0;
    for (final level in const [1, 2, 3]) {
      for (final stat in const [3.0, 4.5]) {
        for (final healed in const [false, true]) {
          var clears = 0;
          final losses = <int>[];
          var seconds = 0.0;
          var worstShare = 0.0;
          var runs = 0;
          for (final arena in const ['Air', 'Earth', 'Fire']) {
            for (final squad in squads) {
              final members = [
                for (var i = 0; i < 4; i++) squad[i],
                healed ? 'Water/kin' : squad[4],
              ];
              final run = raid(
                arena,
                level,
                stat,
                members,
                healer: healed ? 4 : null,
              );
              runs++;
              if (run.cleared) clears++;
              losses.add(run.downs.length);
              seconds += run.seconds;
              final total = run.taken.fold(0.0, (a, b) => a + b);
              if (total > 0) {
                final top = run.taken.reduce((a, b) => a > b ? a : b);
                if (top / total > worstShare) worstShare = top / total;
              }
            }
          }
          losses.sort();
          final mean = losses.fold(0, (a, b) => a + b) / runs;
          rows['L$level s$stat ${healed ? 'healed' : 'none'}'] = (
            clears: clears,
            runs: runs,
            meanLoss: mean,
          );
          if (level >= 2 && worstShare > worstShareL2Up) {
            worstShareL2Up = worstShare;
          }
          // ignore: avoid_print
          print(
            'TIER L$level s$stat ${healed ? 'healed' : 'none  '} '
            'clears $clears/$runs  losses ${losses.join(",")}  '
            'mean ${(seconds / runs).round()}s  '
            'worst share ${(worstShare * 100).round()}%',
          );
        }
      }
    }
    // L1: no healer loses about one and clears; a healer loses none.
    expect(rows['L1 s3.0 none']!.clears, rows['L1 s3.0 none']!.runs);
    expect(rows['L1 s3.0 none']!.meanLoss, inInclusiveRange(0.5, 2.5));
    expect(rows['L1 s3.0 healed']!.meanLoss, lessThanOrEqualTo(0.5));
    // L2: a healer clears, losing 0–1; without one the squad loses most.
    expect(rows['L2 s3.0 healed']!.clears, greaterThanOrEqualTo(8));
    expect(rows['L2 s3.0 healed']!.meanLoss, lessThanOrEqualTo(1.0));
    expect(rows['L2 s3.0 none']!.meanLoss, greaterThanOrEqualTo(2.0));
    // L3: no healer wipes; a healer clears with a loss or few.
    expect(rows['L3 s3.0 none']!.clears, 0);
    expect(rows['L3 s3.0 healed']!.clears, greaterThanOrEqualTo(7));
    expect(rows['L3 s3.0 healed']!.meanLoss, inInclusiveRange(0.5, 3.0));
    // No one body takes the raid for the squad.
    expect(worstShareL2Up, lessThanOrEqualTo(0.55));
  }, timeout: const Timeout(Duration(minutes: 30)));

  // Which part of an L3 raid kills a mid squad: the guardian's damage
  // multiplier, or the add waves.
  test('breakdown', () {
    final variants = {
      'L2 as is': const RaidConfig(level: 2),
      'L2 no adds': const RaidConfig(level: 2, addPhaseThresholds: []),
      'L2 L1 dmgMul': const RaidConfig(level: 2, dmgMul: 1.6),
      'L2 1 wave': const RaidConfig(level: 2, addPhaseThresholds: [0.5]),
    };
    for (final v in variants.entries) {
      for (final sq in const [
        [..._core, 'Fire/mask'],
        [..._core, 'Lava/let'],
      ]) {
        final run = raid('Air', 2, 3.0, sq, config: v.value);
        // ignore: avoid_print
        print('BD ${v.key.padRight(13)} ${sq[4].padRight(9)} $run');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 30)));

  // HP each healer restores per second of fight, to its allies and to
  // itself, in the fifth slot of a mid squad at L2 (where a healer is meant
  // to decide the raid).
  test('healer audit', () {
    for (final h in _healers) {
      final run = raid('Air', 2, 3.0, [..._core, h], healer: 4);
      final allies = run.healed.take(4).fold(0.0, (a, b) => a + b);
      final self = run.healed[4];
      // ignore: avoid_print
      print(
        'HEAL ${h.padRight(14)} '
        'allies ${(allies / run.seconds).toStringAsFixed(1).padLeft(5)}/s '
        'self ${(self / run.seconds).toStringAsFixed(1).padLeft(5)}/s  $run',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
