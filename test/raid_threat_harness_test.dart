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

import 'dart:math' show max;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/raid_state.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';

import 'guardian_rule_harness.dart';

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
  RaidRun(
    this.cleared,
    this.seconds,
    this.downs,
    this.taken,
    this.healed, {
    this.lulls = 0,
    this.answering = 0,
  });
  final bool cleared;
  final double seconds;
  final List<String> downs;
  final List<double> taken;
  final List<double> healed;

  /// Lulls opened, and seconds spent answering the planet's rule.
  final int lulls;
  final double answering;

  @override
  String toString() {
    final share = [for (final x in taken) x.round()].join('/');
    final heal = [for (final x in healed) x.round()].join('/');
    return '${cleared ? 'CLEAR' : 'WIPE '} ${seconds.round()}s '
        'downs=${downs.join(",")} taken=$share healed=$heal';
  }
}

/// Who answers a guardian's planet rule in a raid. [key] is the slot that
/// stands at the thing and presses (null: whoever is played, for the rules
/// anyone can answer); [ring] are the other hands Botanica's ring needs;
/// [brew] is the Plant or Mud slot that takes turns with the Poison [key] at
/// Blightfang's pot.
class RuleHands {
  const RuleHands({this.key, this.ring = const [], this.brew});
  final int? key;
  final List<int> ring;
  final int? brew;
}

/// One frame of answering the planet's rule, the way a player would (see
/// guardian_rule_harness.dart): while the guardian is shut and a press can
/// work ([guardianAnswerReady]), the key walks to the thing and presses once
/// there (Botanica's ring once every hand has walked in; a ring head only as
/// Magmara comes past); against Solarin, whoever is played keeps to the
/// shade the whole fight and strikes from it. Returns false when there is
/// nothing to answer yet, or the hand it needs is down (no fallback: losing
/// the key keeps the guardian shut, as in the game); the fighter takes over.
bool _answerRule(PlanetDungeonGame g, RuleHands h, double dt) {
  final shut = !g.guardianVulnerable;
  switch (g.layout.element) {
    case 'Poison':
      return shut && blightfangStep(g, h.key!, h.brew!, walkDt: dt);
    case 'Light':
      final a = g.active;
      if (a == null || !a.alive || g.currentRoom.hall?.def?.orbit == null) {
        return false;
      }
      walkTo(a, solarinShadedStep(g, name: raidShadowName(a)), dt);
      return true;
  }
  final at = guardianAnswerAt(g);
  if (at == null || !shut || !guardianAnswerReady(g)) return false;
  final k = h.key ?? g.activeIndex;
  if (!g.creatures[k].alive) return false;
  if (g.activeIndex != k) g.setActive(k);
  var there = walkTo(g.creatures[k], at, dt);
  for (final (n, i) in h.ring.indexed) {
    if (!g.creatures[i].alive) continue;
    final off = Offset(n == 0 ? 18 : -18, 0);
    if (!walkTo(g.creatures[i], at + off, dt)) there = false;
  }
  if (g.layout.element == 'Lava') {
    final boss = g.combatEnemies.where((e) => e.isElite).first;
    if ((boss.position - at).distance > kHarnessHeadCatch) there = false;
  }
  if (there) g.activateAbility();
  return true;
}

/// One raid. [squad] is a list of 'Element/family'. When [healer] is set,
/// that slot is played as a healer: whenever anyone standing is under 60%
/// and its special is ready, swap to it, cast, and swap back. A healer only
/// casts when it is the active Alchemon, so an idle one heals nothing. When
/// [rule] is set, the squad answers the planet's rule ([_answerRule]) and
/// swaps back to whoever was fighting once it is answered.
RaidRun raid(
  String arena,
  int level,
  double stat,
  List<String> squad, {
  Stance stance = Stance.step,
  int? healer,
  RaidConfig? config,
  RuleHands? rule,
  bool walk = false,
  void Function(PlanetDungeonGame g, double t)? onFrame,
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
  int? fighter;
  var lulls = 0;
  var wasOpen = false;
  var answered = 0.0;
  RaidRun done(bool cleared) => RaidRun(
    cleared,
    t,
    downs,
    taken,
    healed,
    lulls: lulls,
    answering: answered,
  );
  while (t < kRaidFightLimit.inSeconds) {
    final boss = g.combatEnemies.where((e) => e.isElite).firstOrNull;
    final before = g.activeIndex;
    final answering =
        rule != null && boss != null && _answerRule(g, rule, 1 / 60);
    if (answering) {
      answered += 1 / 60;
      if (g.activeIndex != before) fighter ??= before;
    } else if (fighter != null) {
      if (g.creatures[fighter].alive) g.setActive(fighter);
      fighter = null;
    }
    final a = g.active;
    if (!answering && a != null && a.alive && boss != null) {
      final off = stance == Stance.step && !g.guardianVulnerable ? 130.0 : 60.0;
      final stand = boss.position + Offset(0, off);
      if (walk) {
        walkTo(a, stand, 1 / 60);
      } else {
        a
          ..position = stand
          ..lastSafe = stand;
      }
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
    onFrame?.call(g, t);
    if (g.guardianVulnerable && !wasOpen) lulls++;
    wasOpen = g.guardianVulnerable;
    for (var i = 0; i < g.combatCompanions.length; i++) {
      final now = g.combatCompanions[i].currentHp;
      if (now < prev[i]) taken[i] += prev[i] - now;
      if (now > prev[i]) healed[i] += now - prev[i];
      prev[i] = now;
    }
    if (g.hasStar(star)) return done(true);
    if (wiped || g.creatures.every((c) => !c.alive)) return done(false);
  }
  return done(false);
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

/// What each planet's rule needs in the squad: per hand, the elements that
/// answer it (and, for Wraithord's chime, the family). The first hand is
/// the key. Lava and Light take anyone, so the body played answers them;
/// the rest have no rule a hand answers.
const _ruleNeeds = <String, List<(List<String>, String?)>>{
  'Ice': [
    (['Ice'], null),
  ],
  'Mud': [
    (['Mud'], null),
  ],
  'Dust': [
    (['Dust', 'Earth'], null),
  ],
  'Spirit': [
    (['Blood'], 'pip'),
  ],
  'Crystal': [
    (['Crystal'], null),
  ],
  'Plant': [
    (['Water'], null),
    (['Crystal'], null),
    (['Spirit'], null),
  ],
  'Poison': [
    (['Poison'], null),
    (['Plant', 'Mud'], null),
  ],
  'Lightning': [
    (['Lightning'], null),
  ],
};

/// [squad] carrying [planet]'s key Alchemon(s). A hand the first four slots
/// already hold is used as it is; otherwise it replaces a damage dealer's
/// element, from the back (keeping that slot's family), never the fifth
/// slot (the healer's, in a healed row).
({List<String> squad, RuleHands hands}) _withKeys(
  String planet,
  List<String> squad,
) {
  final needs = _ruleNeeds[planet] ?? const [];
  final out = [...squad];
  String el(int i) => out[i].split('/')[0];
  String fam(int i) => out[i].split('/')[1];
  final slots = <int>[];
  final claimed = <int>{};
  for (final (els, family) in needs) {
    final at = [0, 1, 2, 3].where(
      (i) =>
          !claimed.contains(i) &&
          els.contains(el(i)) &&
          (family == null || fam(i) == family),
    );
    slots.add(at.isEmpty ? -1 : at.first);
    if (at.isNotEmpty) claimed.add(at.first);
  }
  for (var n = 0; n < needs.length; n++) {
    if (slots[n] >= 0) continue;
    final (els, family) = needs[n];
    final i = [3, 2, 1, 0].firstWhere(
      (i) => !claimed.contains(i) && (family == null || fam(i) == family),
    );
    out[i] = '${els.first}/${fam(i)}';
    slots[n] = i;
    claimed.add(i);
  }
  final hands = switch (planet) {
    'Plant' => RuleHands(key: slots[0], ring: slots.sublist(1)),
    'Poison' => RuleHands(key: slots[0], brew: slots[1]),
    _ => RuleHands(key: slots.isEmpty ? null : slots[0]),
  };
  return (squad: out, hands: hands);
}

/// The key always walks to its rule: that trip is the rule's cost. The
/// fighter is set down at its stance, as the Phase 6 table that tuned the
/// tiers did, unless `--dart-define=WALK=true` walks it too (which costs
/// about a notch everywhere: it is in the rage aura while it walks out).
const _walk = bool.fromEnvironment('WALK');

const _tableSquads = [
  [..._core, 'Lava/let'],
  [..._core, 'Fire/mask'],
  ['Air/wing', 'Water/horn', 'Earth/mane', 'Fire/pip', 'Dark/mask'],
];

/// A run on the author's scale: 0 clears losing none, 1 clears losing one,
/// 2 loses two or three, 3 loses four or more. A run that does not clear
/// with fewer down (the ten minutes ran out) is a 3 too: the raid is lost.
int _notch(RaidRun r) {
  final lost = r.downs.length;
  if (lost >= 4 || !r.cleared) return 3;
  return lost >= 2 ? 2 : lost;
}

/// The author's tier table on that scale. A strong squad (stats 4.5) sits
/// one notch easier on every row.
({int lo, int hi}) _target(int level, double stat, bool healed) {
  final mid = switch ((level, healed)) {
    (1, false) => (lo: 1, hi: 1),
    (1, true) => (lo: 0, hi: 0),
    (2, false) => (lo: 2, hi: 2),
    (2, true) => (lo: 0, hi: 1),
    (_, false) => (lo: 3, hi: 3),
    (_, true) => (lo: 1, hi: 2),
  };
  if (stat < 4) return mid;
  return (lo: max(0, mid.lo - 1), hi: max(0, mid.hi - 1));
}

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

  // The same tier table on every raid-eligible planet but Blood (its raid
  // runs the shared clock while Blood is rebuilt). Each squad carries the
  // planet's key Alchemon(s) in place of a damage dealer, never the healer
  // (`_withKeys`), and answers the rule the way a player would. Prints the
  // 12 rows per planet, each as a notch on the author's scale, and flags
  // every planet more than one notch off. Measures; asserts nothing.
  test('tier table, every planet', () {
    const squads = _tableSquads;
    final only = const String.fromEnvironment('PLANETS');
    final planets = [
      for (final p in kRaidGuardianIds.keys)
        if (p != 'Blood' && (only.isEmpty || only.split(',').contains(p))) p,
    ];
    final flagged = <String>[];
    for (final planet in planets) {
      var worstOff = 0.0;
      for (final level in const [1, 2, 3]) {
        for (final stat in const [3.0, 4.5]) {
          for (final healed in const [false, true]) {
            var clears = 0;
            final losses = <int>[];
            var seconds = 0.0;
            var notch = 0.0;
            var lulls = 0;
            var answering = 0.0;
            for (final squad in squads) {
              final keyed = _withKeys(planet, [
                for (var i = 0; i < 4; i++) squad[i],
                healed ? 'Water/kin' : squad[4],
              ]);
              final run = raid(
                planet,
                level,
                stat,
                keyed.squad,
                healer: healed ? 4 : null,
                rule: keyed.hands,
                walk: _walk,
              );
              if (run.cleared) clears++;
              losses.add(run.downs.length);
              seconds += run.seconds;
              notch += _notch(run);
              lulls += run.lulls;
              answering += run.answering;
            }
            notch /= squads.length;
            final want = _target(level, stat, healed);
            final off = notch < want.lo
                ? want.lo - notch
                : (notch > want.hi ? notch - want.hi : 0.0);
            if (off > worstOff) worstOff = off;
            // ignore: avoid_print
            print(
              'PLANET ${planet.padRight(9)} L$level s$stat '
              '${healed ? 'healed' : 'none  '} '
              'clears $clears/${squads.length}  losses ${losses.join(",")}  '
              'mean ${(seconds / squads.length).round().toString().padLeft(3)}s  '
              'lulls ${(lulls / squads.length).round().toString().padLeft(2)} '
              'answer ${(100 * answering / seconds).round().toString().padLeft(2)}%  '
              'notch ${notch.toStringAsFixed(1)} '
              '(table ${want.lo == want.hi ? '${want.lo}' : '${want.lo}-${want.hi}'})'
              '${off > 1 ? '  OFF ${off.toStringAsFixed(1)}' : ''}',
            );
          }
        }
      }
      if (worstOff > 1) flagged.add('$planet (${worstOff.toStringAsFixed(1)})');
    }
    // ignore: avoid_print
    print(
      'PLANETS more than one notch off: '
      '${flagged.isEmpty ? 'none' : flagged.join(', ')}',
    );
  }, timeout: const Timeout(Duration(minutes: 60)));

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
