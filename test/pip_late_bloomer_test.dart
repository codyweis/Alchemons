import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_ability_runtime.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pip, the late bloomer (the 2026-10-20 survival family rebuild): weak
/// early, threading crowds late.
///
/// A special dart that kills carries the damage the body did not need on to
/// the next body and spends nothing; a body that survives costs a bounce and
/// the falloff; a dart strikes no body twice; a boss is a survivor the dart
/// bounces on from; and a dart touches at most [PipRicochet.maxContacts]
/// bodies. Counts and bounces grow to the board's maxima, reached at
/// Potential 95. The rules are shared by survival, open space and the
/// dungeons ([PipRicochet]); the contact tests drive survival's real arena.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember pip(String element, {double stat = 4.25}) =>
      CosmicPartyMember(
        instanceId: 'pip-0',
        baseId: 'PIP01',
        displayName: 'Pip $element',
        family: 'Pip',
        element: element,
        level: 10,
        slotIndex: 0,
        statSpeed: stat,
        statIntelligence: stat,
        statStrength: stat,
        statBeauty: stat,
        statSpeedPotential: 50,
        statIntelligencePotential: 50,
        statStrengthPotential: 50,
        statBeautyPotential: 50,
        staminaBars: 3,
        staminaMax: 3,
      );

  /// A cleared arena with one Pip out (and a Horn beside it, with
  /// [partner]) and the ship parked far away.
  Future<CosmicSurvivalGame> arena({
    String element = 'Earth',
    bool partner = false,
  }) async {
    final game = CosmicSurvivalGame(
      party: [
        pip(element),
        if (partner)
          CosmicPartyMember(
            instanceId: 'horn-1',
            baseId: 'HOR02',
            displayName: 'Horn Water',
            family: 'Horn',
            element: 'Water',
            level: 10,
            slotIndex: 1,
            statSpeed: 4.25,
            statIntelligence: 4.25,
            statStrength: 4.25,
            statBeauty: 4.25,
            statSpeedPotential: 50,
            statIntelligencePotential: 50,
            statStrengthPotential: 50,
            statBeautyPotential: 50,
            staminaBars: 3,
            staminaMax: 3,
          ),
      ],
      onGameOver: () {},
      random: Random(5),
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    // A second place on the field, for the partner.
    if (partner) {
      game.applyPowerUp(kAllPowerUps.firstWhere((d) => d.id == 'pack_leader'));
    }
    game.startGame();
    game.summonCompanion(0);
    if (partner) game.summonCompanion(1);
    for (
      var i = 0;
      i < 600 && game.enemies.where((e) => !e.isDead).isEmpty;
      i++
    ) {
      game.update(1 / 60);
    }
    for (final e in game.enemies) {
      e.isDead = true;
    }
    game.orb.shieldHp = 0;
    game.ship.position = game.orb.position + const Offset(0, 900);
    game.ship.fireTimer = -1e9;
    return game;
  }

  CosmicSurvivalEnemy body(
    CosmicSurvivalGame game,
    Offset at, {
    double hp = 1e6,
  }) {
    final e = CosmicSurvivalEnemy(
      position: at,
      hp: hp,
      maxHp: hp,
      speed: 0,
      damage: 0,
      radius: 11,
      tier: EnemyTier.drone,
      element: 'Ice',
      target: CosmicEnemyTarget.orb,
      conduct: EnemyConduct.stalk,
    );
    game.enemies.add(e);
    return e;
  }

  SurvivalBoss boss(CosmicSurvivalGame game, Offset at) {
    final b = game.spawner.createBossForWave(5, at)!;
    b
      ..position = at
      ..spawnIntroTimer = 0
      ..spawnFromPosition = null
      ..spawnTargetPosition = null
      ..chillTimer = 1e9
      ..chillMultiplier = 0
      ..shieldUp = false
      ..shieldTimer = 1e9;
    game.activeBoss = b;
    return b;
  }

  /// A special dart as the ability table throws it, with the numbers under
  /// test: flying straight (no homing) so its path is the test's.
  Projectile dart(
    Offset at,
    double angle, {
    double damage = 100,
    int bounces = 0,
    bool piercing = false,
    String element = 'Earth',
  }) => Projectile(
    position: at,
    angle: angle,
    element: element,
    damage: damage,
    life: 2.0,
    speedMultiplier: 1.0,
    homing: false,
    homingStrength: 0,
    piercing: piercing,
    bounceCount: bounces,
    visualStyle: ProjectileVisualStyle.dart,
    sourceSlotIndex: 0,
    abilityFamily: 'pip',
  )..maxHitsPerEnemy = 1;

  /// Frames with the Pip's own attacks held and anything the spawner sends
  /// in put down at once.
  void run(
    CosmicSurvivalGame game,
    int frames, {
    Set<CosmicSurvivalEnemy> keep = const {},
    SurvivalBoss? still,
  }) {
    for (var f = 0; f < frames; f++) {
      for (final comp in game.activeCompanions.values) {
        comp.specialCooldown = 99999;
        comp.basicCooldown = 99999;
      }
      for (final e in game.enemies) {
        if (!keep.contains(e)) e.isDead = true;
      }
      if (still != null) {
        still
          ..shieldUp = false
          ..shieldTimer = 1e9;
      }
      game.update(1 / 60);
    }
  }

  /// Somewhere well away from the orb, the Pip and the ship.
  Offset field(CosmicSurvivalGame game) =>
      game.orb.position + const Offset(-520, -260);

  group('the rule', () {
    test('a kill carries what the body did not need and spends nothing', () {
      final p = dart(Offset.zero, 0, damage: 100, bounces: 2);
      final share = PipRicochet.carriedShare(30, -70);
      expect(share, closeTo(0.7, 1e-9));
      final step = PipRicochet.settle(p, killed: true, carried: share);
      expect(step, PipDartStep.carry);
      expect(p.damage, closeTo(70, 1e-9));
      expect(p.bounceCount, 2);
      expect(p.pipKills, 1);
    });

    test('a survivor costs one bounce and the falloff', () {
      final p = dart(Offset.zero, 0, damage: 100, bounces: 2);
      expect(PipRicochet.settle(p, killed: false), PipDartStep.bounce);
      expect(p.bounceCount, 1);
      expect(p.damage, closeTo(70, 1e-9));
      final lightning = dart(
        Offset.zero,
        0,
        damage: 100,
        bounces: 1,
        element: 'Lightning',
      );
      PipRicochet.settle(lightning, killed: false);
      expect(lightning.damage, closeTo(85, 1e-9));
    });

    test('a piercing dart out of bounces passes two survivors, then stops', () {
      final p = dart(Offset.zero, 0, bounces: 1, piercing: true);
      expect(PipRicochet.settle(p, killed: false), PipDartStep.bounce);
      expect(PipRicochet.settle(p, killed: false), PipDartStep.pierce);
      expect(PipRicochet.settle(p, killed: false), PipDartStep.pierce);
      expect(PipRicochet.settle(p, killed: false), PipDartStep.spent);
      // A non-piercing one is stopped by the first survivor past its bounces.
      final q = dart(Offset.zero, 0);
      expect(PipRicochet.settle(q, killed: false), PipDartStep.spent);
    });

    test('no dart touches more than the contact cap', () {
      final p = dart(Offset.zero, 0, damage: 1e9);
      var steps = 0;
      while (PipRicochet.settle(p, killed: true, carried: 0.99) !=
          PipDartStep.spent) {
        steps++;
        expect(steps, lessThan(1000));
      }
      expect(p.pipContacts, PipRicochet.maxContacts);
    });
  });

  group('in the arena', () {
    test('a killing dart threads a crowd and keeps its bounces', () async {
      // Five bodies in a row, each well under the dart. Before the rebuild a
      // dart with two bounces touched three and was spent, kill or no kill.
      final game = await arena();
      final start = field(game);
      final row = [
        for (var i = 0; i < 5; i++)
          body(game, start + Offset(40.0 + i * 45, 0), hp: 20),
      ];
      final p = dart(start, 0, damage: 200, bounces: 2);
      game.companionProjectiles.add(p);
      run(game, 90, keep: row.toSet());
      expect(row.every((e) => e.isDead), isTrue);
      expect(p.pipKills, 5);
      expect(p.bounceCount, 2, reason: 'a kill spends no bounce');
      // It carried what it did not spend: 200 less five bodies' health in
      // dart units (the family's 1.06 against trash).
      expect(p.damage, closeTo(200 - 5 * 20 / 1.06, 1.0));
    });

    test('a survivor spends a bounce and takes the falloff', () async {
      final game = await arena();
      final start = field(game);
      final a = body(game, start + const Offset(40, 0));
      final b = body(game, start + const Offset(40, 80));
      final p = dart(start, 0, damage: 100, bounces: 2);
      game.companionProjectiles.add(p);
      run(game, 90, keep: {a, b});
      expect(a.maxHp - a.hp, closeTo(106, 0.5));
      expect(b.maxHp - b.hp, closeTo(70 * 1.06, 0.5));
      expect(p.bounceCount, 0);
    });

    test('a dart never goes back to a body it struck (no A, B, A)', () async {
      // Two survivors and four bounces: it used to ping-pong A, B, A, B, A.
      final game = await arena();
      final start = field(game);
      final a = body(game, start + const Offset(40, 0));
      final b = body(game, start + const Offset(40, 70));
      final p = dart(start, 0, damage: 100, bounces: 4);
      game.companionProjectiles.add(p);
      run(game, 120, keep: {a, b});
      expect(p.pipContacts, 2);
      expect(a.maxHp - a.hp, closeTo(106, 0.5), reason: 'A struck once');
      expect(b.maxHp - b.hp, closeTo(70 * 1.06, 0.5), reason: 'B struck once');
    });

    test('a boss is a survivor the dart bounces on from', () async {
      // Every dart used to be spent on its first boss touch.
      final game = await arena();
      final at = field(game);
      final b = boss(game, at);
      final behind = body(game, at + Offset(b.radius + 55, 0));
      final bossBefore = b.hp;
      final p = dart(at - Offset(b.radius + 40, 0), 0, bounces: 1);
      game.companionProjectiles.add(p);
      run(game, 120, keep: {behind}, still: b);
      expect(b.hp, lessThan(bossBefore), reason: 'the boss was struck');
      expect(p.hitBoss, isTrue);
      expect(
        behind.maxHp - behind.hp,
        greaterThan(0),
        reason: 'and the dart went on to the body beyond it',
      );
      expect(p.bounceCount, 0, reason: 'the boss cost the bounce');
    });

    test('a thread through a packed crowd stops at the contact cap', () async {
      final game = await arena();
      final centre = field(game);
      final crowd = [
        for (var i = 0; i < 40; i++)
          body(
            game,
            centre +
                Offset(cos(i * 2.39996) * 7.0 * sqrt(i + 1), sin(i * 2.39996) *
                    7.0 *
                    sqrt(i + 1)),
            hp: 1,
          ),
      ];
      final p = dart(centre - const Offset(60, 0), 0, damage: 1e6);
      game.companionProjectiles.add(p);
      run(game, 240, keep: crowd.toSet());
      expect(p.pipContacts, PipRicochet.maxContacts);
      expect(crowd.where((e) => e.isDead).length, PipRicochet.maxContacts);
    });

    test('a long thread lays its element piece every few kills', () async {
      // Fire's pool on every body of a twenty-body thread would fill the
      // shared projectile list.
      final game = await arena(element: 'Fire');
      final start = field(game);
      final row = [
        for (var i = 0; i < 9; i++)
          body(game, start + Offset(40.0 + i * 40, 0), hp: 50),
      ];
      final fire = createCosmicSpecialAbility(
        origin: start,
        baseAngle: 0,
        family: 'pip',
        element: 'Fire',
        damage: 10,
        maxHp: 100,
      ).projectiles.first;
      final p = copyProjectile(
        fire,
        position: start,
        angle: 0,
        damage: 1000,
        bounceCount: 0,
        homing: false,
        sourceSlotIndex: 0,
      );
      game.companionProjectiles.add(p);
      run(game, 120, keep: row.toSet());
      expect(p.pipKills, 9);
      final pools = game.companionProjectiles
          .where((q) => q.abilityFamily == 'pip' && q.stationary)
          .length;
      expect(pools, 3, reason: 'kills 1, 5 and 9');
    });

    test('a boss takes the dart, not the crowd payload it carries', () async {
      Future<double> bossLoss(double damage, double payload) async {
        final game = await arena();
        final at = field(game);
        final b = boss(game, at);
        final before = b.hp;
        final p = dart(at - Offset(b.radius + 30, 0), 0, damage: damage)
          ..pipPayload = payload;
        game.companionProjectiles.add(p);
        run(game, 60, still: b);
        return before - b.hp;
      }

      final plain = await bossLoss(100, 1);
      expect(plain, greaterThan(0));
      expect(await bossLoss(400, 4), closeTo(plain, plain * 0.01));
    });

    test('a Light dart blocks a shot and flies on', () async {
      // It was deleted with its one intercept charge, ricochet and all.
      final game = await arena(element: 'Light');
      final at = field(game);
      final p = dart(at, 0, element: 'Light', bounces: 2, piercing: true);
      final light = copyProjectile(
        p,
        speedMultiplier: 0.01,
        interceptRadius: 24,
        interceptCharges: 1,
      );
      game.companionProjectiles.add(light);
      game.enemyProjectiles.add(
        SurvivalEnemyProjectile(
          position: at,
          angle: pi,
          element: 'Fire',
          damage: 10,
          target: CosmicEnemyTarget.orb,
          speed: 1,
        ),
      );
      run(game, 2);
      expect(light.interceptCharges, 0, reason: 'it blocked the shot');
      expect(game.companionProjectiles, contains(light));
    });

    test('a Pip holds off the orb while the fight is on it', () async {
      // The bodies that reach the orb burst there, and the Pip, following a
      // ship parked on the orb, was standing in every burst. A Horn is out
      // to hold the orb.
      final game = await arena(partner: true);
      game.clearCompanionTether();
      final atOrb = body(game, game.orb.position + const Offset(140, 0));
      for (var f = 0; f < 600; f++) {
        // The ship on the orb, as a pilot fighting at the core holds it.
        game.ship.position = game.orb.position;
        run(game, 1, keep: {atOrb});
      }
      final comp = game.activeCompanions[0]!;
      expect(
        (comp.position - game.orb.position).distance,
        greaterThan(250),
      );
    });

    test('a Pip alone on the field fights at the orb', () async {
      // Nobody else holds it: a new team's first Pip, held off the orb, let
      // the early bosses grind it (the fresh-team report, 2026-10-20).
      final game = await arena();
      game.clearCompanionTether();
      final atOrb = body(game, game.orb.position + const Offset(140, 0));
      for (var f = 0; f < 600; f++) {
        game.ship.position = game.orb.position;
        run(game, 1, keep: {atOrb});
      }
      final comp = game.activeCompanions[0]!;
      expect(
        (comp.position - game.orb.position).distance,
        lessThan(250),
      );
    });
  });

  test("survival's crowd payload is the late bloomer's", () {
    // 1 for a weak Pip, growing past an average one, full by about P80.
    expect(pipSurvivalPayload(2.5), 1.0);
    expect(pipSurvivalPayload(kPipPayloadFrom), 1.0);
    expect(pipSurvivalPayload(4.06), inInclusiveRange(1.5, 3.5));
    expect(pipSurvivalPayload(6.5), kPipPayloadCeiling);
    expect(pipSurvivalPayload(14), kPipPayloadCeiling);
  });

  group('the volley grows with breeding', () {
    // Authored per element: (average, the board's maximum).
    const counts = {
      'Fire': (3, 5),
      'Lightning': (6, 8),
      'Ice': (3, 4),
      'Crystal': (3, 5),
      'Lava': (2, 3),
      'Mud': (3, 4),
      'Plant': (3, 5),
      'Spirit': (3, 4),
      'Dust': (5, 7),
      'Air': (4, 6),
      'Blood': (3, 4),
      'Water': (3, 5),
      'Steam': (3, 5),
      'Earth': (3, 4),
      'Poison': (3, 4),
      'Light': (4, 6),
    };

    CosmicSpecialResult cast(String element, double stat, double potential) =>
        createCosmicSpecialAbility(
          origin: Offset.zero,
          baseAngle: 0,
          family: 'pip',
          element: element,
          damage: 10,
          maxHp: 100,
          casterBeauty: stat,
          casterIntelligence: stat,
          casterBeautyPotential: potential,
        );

    test('an average Pip throws the authored volley', () {
      for (final MapEntry(key: element, value: (base, _)) in counts.entries) {
        expect(
          cast(element, 4.25, 50).projectiles.length,
          base,
          reason: element,
        );
      }
    });

    test('Potential 100 throws every element\'s maximum', () {
      for (final MapEntry(key: element, value: (_, top)) in counts.entries) {
        expect(cast(element, 8.0, 100).projectiles.length, top, reason: element);
      }
    });

    test('Potential 100 bounces to the top, Lightning the most', () {
      int bounces(String element) => cast(
        element,
        8.0,
        100,
      ).projectiles.map((p) => p.bounceCount).reduce(max);
      expect(bounces('Lightning'), 8);
      expect(bounces('Air'), 4);
      expect(bounces('Fire'), 2);
      for (final element in counts.keys) {
        expect(bounces(element), lessThanOrEqualTo(bounces('Lightning')));
      }
    });

    test('every special dart remembers the bodies it struck', () {
      for (final element in counts.keys) {
        for (final p in cast(element, 4.25, 50).projectiles) {
          expect(p.maxHitsPerEnemy, 1, reason: element);
        }
      }
    });
  });
}
