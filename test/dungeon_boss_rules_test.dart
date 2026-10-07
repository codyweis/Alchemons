// A DUNGEON BOSS IS FOUGHT LIKE SURVIVAL'S BOSS.
//
// Survival keeps its boss out of the enemy list, so nothing built for trash
// reaches it: a projectile strikes it once, for its plain damage, and only a
// floored slow rides along. The dungeon's guardian lives IN the list, and
// until 2026-10-07 it inherited everything — measured with production-built
// parties, one Air Wing special took half of a fresh guardian (its piercing
// bolt billed it every frame while shoving it 1,700 units out of the room),
// Mask Light's void executed it on contact, Mask Blood bled 6% of its pool a
// second. Early guardians died before their fight could be seen.
//
// The same pass found the Poison plagues at 333 health a bar on a fresh save
// — 1.5s of a mid trio — and ×17.5 by the last dungeon, because they took the
// wisps' campaign curve AND the guardians'.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_balance.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_poison.dart';
import 'package:flame/game.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _member(
  int slot,
  String element,
  String family, {
  double stat = 3,
}) => CosmicPartyMember(
  instanceId: 'inst_$slot',
  baseId: 'base_$slot',
  displayName: '$element $family',
  element: element,
  family: family,
  level: 10,
  statSpeed: stat,
  statIntelligence: stat,
  statStrength: stat,
  statBeauty: stat,
  slotIndex: slot,
  staminaBars: 3,
  staminaMax: 3,
);

/// A one-Alchemon Air spire, combat body built the way a run builds it.
PlanetDungeonGame _solo(CosmicPartyMember m) {
  final g = PlanetDungeonGame(
    element: 'Air',
    party: [m],
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  g.currentRoomId = g.layout.entranceRoomId;
  final c = DungeonCreature(member: m)
    ..position = g.layout.entranceSpawn
    ..lastSafe = g.layout.entranceSpawn;
  g.creatures.add(c);
  g.combatCompanions.add(g.debugCreateCombatCompanion(m, c.position));
  return g;
}

const _stand = Offset(410, 560);
const _pin = Offset(410, 450);

/// Holds the party still and out of trouble, and keeps every basic attack
/// and special down so only what the test fires lands.
void _hold(PlanetDungeonGame g) {
  for (var i = 0; i < g.creatures.length; i++) {
    g.creatures[i]
      ..position = _stand
      ..lastSafe = _stand
      ..hp = g.creatures[i].maxHp;
    final comp = g.combatCompanions[i];
    comp
      ..basicCooldown = 99
      ..specialCooldown = 99
      ..currentHp = comp.maxHp;
  }
}

CosmicSurvivalEnemy? _boss(PlanetDungeonGame g) =>
    g.combatEnemies.where((e) => e.isElite).firstOrNull;

/// Calls the guardian down, lets it land, and waits for a lull — the window
/// it takes FULL damage in, so every number below is the worst case. The
/// guardian is pinned in front of the party.
CosmicSurvivalEnemy _landInALull(PlanetDungeonGame g) {
  g.debugSpawnGuardian();
  for (var f = 0; f < 60 * 30; f++) {
    _hold(g);
    final b = _boss(g);
    if (b != null) {
      b.position = _pin;
      b.flightSteering?.velocity = Offset.zero;
      if (g.guardianVulnerable) return b;
    }
    g.update(1 / 60);
  }
  fail('the guardian never landed into a lull');
}

/// Steps [seconds], re-pinning the guardian after each frame unless [pin] is
/// off. Returns whether anything put it outside its room in the meantime.
bool _run(
  PlanetDungeonGame g,
  CosmicSurvivalEnemy boss,
  double seconds, {
  bool pin = true,
}) {
  final room = g.currentRoom.bounds;
  var left = false;
  for (var f = 0; f < (seconds * 60).round(); f++) {
    _hold(g);
    g.update(1 / 60);
    if (boss.isDead) break;
    if (!room.contains(boss.position)) left = true;
    if (!pin) continue;
    boss
      ..position = _pin
      ..flightSteering?.velocity = Offset.zero;
  }
  return left;
}

/// Fraction of a fresh guardian's pool one special takes, cast into a lull.
/// [pin] off lets the guardian go wherever the cast sends it.
(double, bool) _oneCast(
  String family,
  String element, {
  double stat = 3,
  bool pin = true,
}) {
  final g = _solo(_member(0, element, family, stat: stat));
  final boss = _landInALull(g);
  final before = boss.hp;
  g.combatCompanions.first.specialCooldown = 0;
  g.activateCombatAbility();
  final left = _run(g, boss, 4, pin: pin);
  return ((before - (boss.isDead ? 0 : boss.hp)) / boss.maxHp, left);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a projectile strikes a guardian once', () {
    test('the Air Wing bolt no longer rides its own knockback', () {
      // The case that took 52% of the pool from a stat-2 Wing. Unpinned:
      // the bug WAS the guardian travelling with the bolt.
      final (taken, left) = _oneCast('wing', 'Air', stat: 2, pin: false);
      expect(taken, lessThan(0.10), reason: 'one cast took $taken');
      expect(left, isFalse, reason: 'the bolt carried it out of the room');
    });

    test('no special from a mid caster takes a fifth of a fresh guardian, '
        'or puts it out of its room', () {
      // Measured after the fix: the worst at stat 3 is Wing Lava's beam at
      // ~13%, into a lull. Before it, Wing Lava's projectiles alone billed a
      // standing body for 22k — three fresh guardians.
      final worst = <String>[];
      for (final family in const [
        'pip',
        'wing',
        'horn',
        'mane',
        'let',
        'mask',
        'kin',
      ]) {
        for (final element in kCosmicAbilityElements) {
          final (taken, left) = _oneCast(family, element);
          if (taken >= 0.20 || left) {
            worst.add(
              '$element $family: ${(taken * 100).round()}%'
              '${left ? ' and LEFT THE ROOM' : ''}',
            );
          }
        }
      }
      expect(worst, isEmpty);
    });
  });

  group('nothing built for trash ends a guardian', () {
    test("Mask Light's void hits it; it does not execute it", () {
      final g = _solo(_member(0, 'Light', 'mask'));
      final boss = _landInALull(g);
      g.combatProjectiles.add(
        Projectile(
          position: boss.position,
          angle: 0,
          element: 'Light',
          damage: 40,
          life: 5,
          stationary: true,
          piercing: true,
          abilityFamily: 'mask',
          sourceSlotIndex: 0,
        ),
      );
      _run(g, boss, 1);
      expect(boss.isDead, isFalse);
      expect(boss.hpFraction, greaterThan(0.95));
    });

    test('Mask Blood does not bleed it by percent', () {
      final g = _solo(_member(0, 'Blood', 'mask'));
      final boss = _landInALull(g);
      g.combatProjectiles.add(
        Projectile(
          position: boss.position,
          angle: 0,
          element: 'Blood',
          damage: 0,
          life: 5,
          stationary: true,
          piercing: true,
          abilityFamily: 'mask',
          sourceSlotIndex: 0,
        ),
      );
      _run(g, boss, 2);
      expect(boss.maskBloodDrainSlot, isNull);
      expect(boss.hpFraction, greaterThan(0.99));
    });

    test('an execute has no low-health threshold on it', () {
      final g = _solo(_member(0, 'Blood', 'wing'));
      final boss = _landInALull(g);
      boss.hp = boss.maxHp * 0.10; // well under the 20% execute line
      g.combatProjectiles.add(
        Projectile(
          position: boss.position,
          angle: 0,
          element: 'Blood',
          damage: 0,
          life: 1,
          stationary: true,
          piercing: true,
          tickEffect: AbilityEffectKind.execute,
          effectRadius: 120,
          effectPower: 10,
          sourceSlotIndex: 0,
        ),
      );
      _run(g, boss, 0.5);
      expect(boss.isDead, isFalse);
      expect(boss.hpFraction, greaterThan(0.09));
    });
  });

  group('a Poison plague is a boss', () {
    const els = ['Poison', 'Plant', 'Mud'];
    PlanetDungeonGame venom({int cleared = 0}) {
      final party = [
        for (var i = 0; i < els.length; i++)
          _member(i, els[i], const ['mask', 'horn', 'mane'][i]),
      ];
      final g = PlanetDungeonGame(
        element: 'Poison',
        party: party,
        initialStarMask: 0,
        onStarEarned: (_) {},
        onPlayerDown: () {},
        onChanged: () {},
        clearedGuardianCount: cleared,
      );
      g.onGameResize(Vector2(900, 600));
      for (final m in party) {
        final c = DungeonCreature(member: m)
          ..position = const Offset(200, 300)
          ..lastSafe = const Offset(200, 300);
        g.creatures.add(c);
        g.combatCompanions.add(g.debugCreateCombatCompanion(m, c.position));
      }
      return g;
    }

    void press(PlanetDungeonGame g, String element, String room, Offset at) {
      g.currentRoomId = room;
      final i = g.creatures.indexWhere((c) => c.member.element == element);
      g.activeIndex = i;
      g.creatures[i]
        ..position = at
        ..lastSafe = at;
      g.activateAbility();
    }

    /// Pours the font, brews the first plague's potion, wakes it, and lets
    /// it crawl out into the walk.
    CosmicSurvivalEnemy wake(PlanetDungeonGame g) {
      final pot = poisonLayout.rooms['apothecary']!.apothecary!.cistern;
      final font = poisonLayout.rooms['ambulatory']!.lustralFont!;
      final bench = pot + const Offset(200, 0);
      press(g, 'Poison', 'apothecary', pot);
      press(g, 'Poison', 'apothecary', pot);
      press(g, 'Poison', 'ambulatory', font);
      for (var i = 0; i < 60 * 12 && g.monastery.parade >= 0; i++) {
        g.update(1 / 60);
      }
      if (g.monastery.carriedPotion != null) {
        press(g, 'Poison', 'apothecary', bench);
      }
      final potion = kPlaguePotions.first;
      press(g, potion.first, 'apothecary', pot);
      press(g, potion.second, 'apothecary', pot);
      final ward = poisonLayout.rooms[potion.wardId!]!.ward!.censer;
      press(g, 'Poison', potion.wardId!, ward);
      g.currentRoomId = 'ambulatory';
      for (var i = 0; i < 60 * 14 && g.monastery.invading; i++) {
        g.update(1 / 60);
      }
      final body = g.monastery.body;
      expect(body, isNotNull, reason: 'the crawl has to end in a plague');
      return body!;
    }

    test('a bar rides the guardian curve, and only that one', () {
      final fresh = wake(venom()).maxHp;
      final late = wake(venom(cleared: 16)).maxHp;
      expect(
        fresh,
        closeTo(900 * CosmicSurvivalBalance.enemyWaveHpScale(4), 1),
      );
      // ×3.88 like a guardian — not ×17.5 (×3.88 on top of the wisps' ×4.52).
      expect(late / fresh, closeTo(1 + 0.18 * 16, 0.01));
    });

    test("a fresh bar outlasts a mid trio's opening", () {
      // It was 1.5s of open fighting: the bar was gone before the plague
      // had thrown anything. Measured ~5s now.
      final g = venom();
      final body = wake(g);
      final m = g.monastery;
      for (var f = 0; f < 600 && m.unfurl > 0; f++) {
        g.update(1 / 60);
      }
      g.activeIndex = 0;
      var t = 0.0;
      while (!m.gated && m.fighting != null && t < 60) {
        final stand = body.position + const Offset(0, 70);
        for (var i = 0; i < g.creatures.length; i++) {
          g.creatures[i]
            ..position = stand
            ..lastSafe = stand
            ..hp = g.creatures[i].maxHp;
          final comp = g.combatCompanions[i];
          comp.currentHp = comp.maxHp;
        }
        if (g.autoAttackReady) g.activateAutoAttack();
        if (g.abilityReady) g.activateCombatAbility();
        g.update(1 / 60);
        t += 1 / 60;
      }
      expect(m.gated, isTrue, reason: 'the bar never emptied');
      expect(t, greaterThan(3.0), reason: 'the bar fell in ${t}s');
    });
  });
}
