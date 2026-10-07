@Tags(['preview'])
library;

// DUNGEON GUARDIAN HARNESS — what each planet's guardian fight costs the
// trio its dungeon asks for.
//
// Not a pass/fail test: it prints one line per planet. Run with
//   flutter test test/dungeon_guardian_harness_test.dart --tags preview
// The trio is the planet's own entry trio (kCosmicPlanetEntry), production
// built, all stats [stat]. It starts in the guardian's room with the
// guardian roused. Nobody's health is refilled; a down revives after
// respawnSeconds, as in any dungeon. Where the guardian fights by its planet's
// rule, the trio answers it the way a player would (guardian_rule_harness);
// otherwise one body fights from outside the aura and steps in to strike
// each lull. `taken=` is the share of the trio's pooled health lost, per
// slot. Blood is left out: its fight is the shell rites, being rebuilt.
// See docs/plans/raid_threat_plan.md, Phase 7.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';

import 'guardian_rule_harness.dart';

const _planets = [
  'Air', 'Fire', 'Water', 'Earth', 'Steam', 'Dark', // the shared clock
  'Ice', 'Mud', 'Dust', 'Crystal', 'Plant', 'Spirit', 'Lava', 'Lightning',
  'Poison', 'Light', // their own rule
];

/// The entry slot that answers each planet's rule; it plays as the Pip.
/// (Spirit's chime takes a Blood Pip, the rest any family.)
int _keySlot(String element) => switch (element) {
  'Spirit' => 1, // Spirit · BLOOD · Dust
  'Plant' => 2, // Crystal · Spirit · WATER (the other two stand in too)
  _ => 0,
};

CosmicPartyMember _m(int slot, String element, String family, double stat) =>
    CosmicPartyMember(
      instanceId: 'd$slot',
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

String _fight(String element, {double stat = 3.0, int cleared = 0}) {
  final entry = kCosmicPlanetEntry[element]!;
  final key = _keySlot(element);
  final others = ['horn', 'wing'];
  final members = [
    for (var i = 0; i < 3; i++)
      _m(i, entry[i], i == key ? 'pip' : others.removeAt(0), stat),
  ];
  final g = PlanetDungeonGame(
    element: element,
    party: members,
    // Stars 1 and 2 banked, so the guardian's rite is unlocked; Star 3 not.
    initialStarMask: 0x3,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
    clearedGuardianCount: cleared,
  );
  g.onGameResize(Vector2(412, 915));
  final room = g.layout.rooms.values.firstWhere((r) => r.guardian != null);
  g.currentRoomId = room.id;
  final b = room.bounds.deflate(60);
  final from = room.guardian!.position + const Offset(0, 170);
  final start = Offset(
    from.dx.clamp(b.left, b.right),
    from.dy.clamp(b.top, b.bottom),
  );
  for (var i = 0; i < 3; i++) {
    final at = start + Offset((i - 1) * 40.0, 0);
    g.creatures.add(
      DungeonCreature(member: members[i])
        ..position = at
        ..lastSafe = at,
    );
    g.combatCompanions.add(g.debugCreateCombatCompanion(members[i], at));
  }
  g.guardianAwake = true;
  final pool = g.combatCompanions.fold(0, (a, c) => a + c.maxHp);
  final prev = [for (final c in g.combatCompanions) c.currentHp];
  final taken = List<double>.filled(3, 0);
  var downs = 0;
  final wasAlive = [for (final c in g.creatures) c.alive];
  var t = 0.0;
  while (t < 300) {
    final boss = g.combatEnemies.where((e) => e.isElite).firstOrNull;
    final shut = !g.guardianVulnerable;
    final answer = guardianAnswerAt(g);
    if (boss != null && element == 'Poison' && shut) {
      blightfangStep(g, 0, 1);
    } else if (boss != null &&
        answer != null &&
        (shut || element == 'Light') &&
        g.creatures[key].alive) {
      if (g.activeIndex != key) g.setActive(key);
      g.creatures[key]
        ..position = answer
        ..lastSafe = answer;
      if (element == 'Plant') {
        for (var i = 0; i < 3; i++) {
          if (i == key) continue;
          g.creatures[i]
            ..position = answer + Offset(i == 0 ? -18 : 18, 0)
            ..lastSafe = answer + Offset(i == 0 ? -18 : 18, 0);
        }
      }
      g.activateAbility();
    } else if (boss != null) {
      final a = g.active;
      if (a != null && a.alive) {
        // Below it, unless that is a doorway (stepping through one would
        // leave the fight): then above, or beside.
        final off = shut ? 130.0 : 60.0;
        final stand =
            [Offset(0, off), Offset(0, -off), Offset(off, 0), Offset(-off, 0)]
                .map((d) => boss.position + d)
                .firstWhere(
                  (p) =>
                      room.bounds.deflate(30).contains(p) &&
                      !room.doors.any((d) => d.rect.inflate(40).contains(p)),
                  orElse: () => boss.position + Offset(0, off),
                );
        a
          ..position = stand
          ..lastSafe = stand;
      }
      if (g.autoAttackReady) g.activateAutoAttack();
      if (g.abilityReady) g.activateCombatAbility();
      if (!shut) g.activateAbility();
    }
    g.update(1 / 60);
    t += 1 / 60;
    for (var i = 0; i < 3; i++) {
      final now = g.combatCompanions[i].currentHp;
      if (now < prev[i]) taken[i] += prev[i] - now;
      prev[i] = now;
      final alive = g.creatures[i].alive;
      if (wasAlive[i] && !alive) downs++;
      wasAlive[i] = alive;
    }
    if (g.hasStar(2)) break;
  }
  final share = [for (final x in taken) (100 * x / pool).round()].join('/');
  final total = (100 * taken.fold(0.0, (a, b) => a + b) / pool).round();
  return '${g.hasStar(2) ? 'CLEAR' : 'NOT  '} ${t.round().toString().padLeft(3)}s '
      'downs=$downs taken=$total% ($share)';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('every guardian, with its own trio', () {
    for (final cleared in const [0, 16]) {
      for (final el in _planets) {
        // ignore: avoid_print
        print(
          'GUARD ${cleared == 0 ? 'fresh' : 'late '} ${el.padRight(9)} '
          '${_fight(el, cleared: cleared)}',
        );
      }
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
