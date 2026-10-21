import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_balance.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/burn_healing.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Menders: survival's healers. They walk in from wave 12, a few to a wave,
/// hold back and mend the most wounded bodies near them. A burning body takes
/// half of every heal, a mender's and a vampiric elite's alike.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember member(String element, {int slot = 0}) => CosmicPartyMember(
    instanceId: 'horn-$slot',
    baseId: 'HRN01',
    displayName: 'Horn $element',
    family: 'Horn',
    element: element,
    level: 10,
    slotIndex: slot,
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
  );

  void hold(CosmicSurvivalGame game) {
    game.alchemicalMeter = 0;
    game.showingPowerUpSelection = false;
    game.gamePaused = false;
    game.orb.currentHp = game.orb.maxHp;
    game.ship.currentHp = game.ship.maxHp.toDouble();
  }

  void run(CosmicSurvivalGame game, double seconds) {
    for (var i = 0; i < (seconds * 60).round(); i++) {
      hold(game);
      game.update(1 / 60);
    }
  }

  // ── Spawning ──────────────────────────────────────────────────────────────

  Future<CosmicSurvivalGame> gameAtWave(int wave) async {
    final game = CosmicSurvivalGame(
      party: const [],
      random: Random(9),
      onGameOver: () {},
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    game.spawner.currentWave = wave - 1;
    game.spawner.resumeAfterIntermission();
    game.spawner.isBossWave = false;
    return game;
  }

  /// Every mender a wave sends, and how much of the wave had been sent when
  /// each first appeared.
  Future<(List<CosmicSurvivalEnemy>, List<double>)> mendersOf(int wave) async {
    final game = await gameAtWave(wave);
    final seen = <CosmicSurvivalEnemy>[];
    final sentAt = <double>[];
    for (var i = 0; i < 60 * 120; i++) {
      hold(game);
      game.spawner.isBossWave = false;
      game.update(1 / 60);
      for (final e in game.enemies) {
        if (e.isMender && !seen.any((m) => identical(m, e))) {
          seen.add(e);
          sentAt.add(
            game.spawner.spawnedThisWave / game.spawner.targetCountThisWave,
          );
        }
      }
      if (game.spawner.spawnedThisWave >= game.spawner.targetCountThisWave) {
        break;
      }
    }
    expect(
      game.spawner.spawnedThisWave,
      game.spawner.targetCountThisWave,
      reason: 'the wave never finished sending',
    );
    game.onRemove();
    return (seen, sentAt);
  }

  test(
    'menders come in from wave 12, one more every ten waves, four at most',
    () {
      expect(CosmicSurvivalBalance.menderCountForWave(1), 0);
      expect(CosmicSurvivalBalance.menderCountForWave(11), 0);
      expect(CosmicSurvivalBalance.menderCountForWave(12), 1);
      expect(CosmicSurvivalBalance.menderCountForWave(21), 1);
      expect(CosmicSurvivalBalance.menderCountForWave(22), 2);
      expect(CosmicSurvivalBalance.menderCountForWave(32), 3);
      expect(CosmicSurvivalBalance.menderCountForWave(42), 4);
      expect(CosmicSurvivalBalance.menderCountForWave(200), 4);
    },
  );

  test('no wave before 12 sends a mender', () async {
    final (menders, _) = await mendersOf(11);
    expect(menders, isEmpty);
  });

  test('wave 12 sends one, after the wave is under way', () async {
    final (menders, sentAt) = await mendersOf(12);
    expect(menders, hasLength(1));
    // Spread through the wave, not with its first band.
    expect(sentAt.single, greaterThanOrEqualTo(0.45));
    final m = menders.single;
    expect(m.trait, EnemyTrait.mender);
    expect(m.tier, EnemyTier.phantom);
    expect(m.conduct, EnemyConduct.siege);
    expect(m.isElite, isFalse);
    // Its pulse is its only act: it neither shells nor counts as artillery.
    expect(m.isShooter, isFalse);
    expect(m.isSiegeArtillery, isFalse);
  });

  test('wave 22 sends its cap of two, spread through the wave', () async {
    final (menders, sentAt) = await mendersOf(22);
    expect(menders, hasLength(CosmicSurvivalBalance.menderCountForWave(22)));
    expect(sentAt[0], greaterThanOrEqualTo(0.30));
    expect(sentAt[1], greaterThanOrEqualTo(0.63));
  });

  test('a boss wave sends no menders', () async {
    final game = await gameAtWave(25);
    game.spawner.isBossWave = true;
    for (var i = 0; i < 60 * 20; i++) {
      hold(game);
      game.update(1 / 60);
      expect(game.enemies.where((e) => e.isMender), isEmpty);
    }
    game.onRemove();
  });

  test('a mender holds back from the orb instead of walking in', () async {
    final game = await gameAtWave(12);
    CosmicSurvivalEnemy? mender;
    for (var i = 0; i < 60 * 120 && mender == null; i++) {
      hold(game);
      game.update(1 / 60);
      for (final e in game.enemies) {
        if (e.isMender) mender = e;
      }
    }
    expect(mender, isNotNull);
    run(game, 40);
    final dist = (mender!.position - game.orb.position).distance;
    expect(
      (dist - CosmicSurvivalBalance.menderHoldRange).abs(),
      lessThan(120),
      reason: 'it stopped at $dist',
    );
    game.onRemove();
  });

  // ── Mending ───────────────────────────────────────────────────────────────

  /// A quiet arena: the opening wave is gone, the ship's guns are held and it
  /// is parked out of the way. Bodies a test places keep the wave open, so
  /// nothing new walks in.
  Future<CosmicSurvivalGame> arena({
    List<CosmicPartyMember> party = const [],
  }) async {
    final game = CosmicSurvivalGame(
      party: party,
      random: Random(5),
      onGameOver: () {},
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    for (
      var i = 0;
      i < 60 * 60 &&
          game.spawner.spawnedThisWave < game.spawner.targetCountThisWave;
      i++
    ) {
      hold(game);
      game.update(1 / 60);
    }
    for (final e in game.enemies) {
      e.isDead = true;
    }
    game.ship.position = game.orb.position + const Offset(0, -900);
    game.ship.fireTimer = -1e9;
    return game;
  }

  CosmicSurvivalEnemy place(
    CosmicSurvivalGame game,
    Offset at, {
    EnemyTier tier = EnemyTier.brute,
    EnemyTrait? trait,
    double hp = 1000,
    double hpFraction = 0.5,
  }) {
    final e = CosmicSurvivalEnemy(
      position: at,
      hp: hp * hpFraction,
      maxHp: hp,
      speed: 0,
      damage: 0,
      radius: tierRadius(tier),
      tier: tier,
      element: 'Plant',
      conduct: trait == EnemyTrait.mender
          ? EnemyConduct.siege
          : EnemyConduct.charge,
      trait: trait,
      target: CosmicEnemyTarget.orb,
    );
    game.enemies.add(e);
    return e;
  }

  CosmicSurvivalEnemy mender(CosmicSurvivalGame game, Offset at) => place(
    game,
    at,
    tier: EnemyTier.phantom,
    trait: EnemyTrait.mender,
    hp: 120,
  )..menderPulseTimer = 0.05;

  // One pulse, and the flow's time to arrive, and a little.
  const pulse = 0.05 + CosmicSurvivalBalance.menderMendTravel + 0.1;
  const share = CosmicSurvivalBalance.menderHealShare;

  test(
    'a pulse mends a wounded body by its share when the flow arrives',
    () async {
      final game = await arena();
      final at = game.orb.position + const Offset(0, 520);
      mender(game, at);
      final brute = place(game, at + const Offset(140, 0));
      final before = brute.hp;
      run(game, 0.3);
      // Sent, not landed: the heal arrives with the grains.
      expect(brute.hp, before);
      expect(game.debugMendsInFlight, 1);
      expect(game.debugMenderFlows.length, 1);
      run(game, pulse - 0.3);
      expect(brute.hp, closeTo(before + brute.maxHp * share, 1e-6));
      game.onRemove();
    },
  );

  test('a burning body takes half the mend', () async {
    final game = await arena();
    final at = game.orb.position + const Offset(0, 520);
    mender(game, at);
    final brute = place(game, at + const Offset(140, 0));
    game.debugApplyAbilityEffect(AbilityEffectKind.burn, brute, power: 0);
    expect(brute.burnTimer, kBurnSeconds);
    final before = brute.hp;
    run(game, pulse);
    expect(
      brute.hp,
      closeTo(before + brute.maxHp * share * kBurnHealingMultiplier, 1e-6),
    );
    game.onRemove();
  });

  test(
    'burn wears off a few seconds after the last one, and the full mend returns',
    () async {
      final game = await arena();
      final at = game.orb.position + const Offset(0, 520);
      final m = mender(game, at)..menderPulseTimer = kBurnSeconds + 0.2;
      final brute = place(game, at + const Offset(140, 0));
      game.debugApplyAbilityEffect(AbilityEffectKind.burn, brute, power: 0);
      run(game, kBurnSeconds + 0.1);
      expect(brute.burnTimer, 0);
      expect(m.menderPulseTimer, greaterThan(0));
      final before = brute.hp;
      run(game, 0.1 + CosmicSurvivalBalance.menderMendTravel + 0.1);
      expect(brute.hp, closeTo(before + brute.maxHp * share, 1e-6));
      game.onRemove();
    },
  );

  test('it never mends itself or another mender', () async {
    final game = await arena();
    final at = game.orb.position + const Offset(0, 520);
    final a = mender(game, at)..hp = 30;
    final b = mender(game, at + const Offset(90, 0))..hp = 30;
    run(game, pulse);
    expect(a.hp, 30);
    expect(b.hp, 30);
    expect(game.debugMendsInFlight, 0);
    game.onRemove();
  });

  test(
    'two menders do not stack on one body: it is mended once a pulse',
    () async {
      final game = await arena();
      final at = game.orb.position + const Offset(0, 520);
      mender(game, at);
      mender(game, at + const Offset(0, 60));
      final brute = place(game, at + const Offset(140, 30));
      final before = brute.hp;
      run(game, pulse);
      expect(brute.hp, closeTo(before + brute.maxHp * share, 1e-6));
      game.onRemove();
    },
  );

  test(
    'it mends the three bodies missing the most, within its reach',
    () async {
      final game = await arena();
      final at = game.orb.position + const Offset(0, 520);
      mender(game, at);
      final heavy = place(game, at + const Offset(100, 0), hp: 2000);
      final mid = place(game, at + const Offset(-100, 0), hp: 1000);
      final light = place(game, at + const Offset(0, 100), hp: 400);
      final scratched = place(game, at + const Offset(0, -100), hp: 100);
      final far = place(
        game,
        at + const Offset(CosmicSurvivalBalance.menderHealRange + 40, 0),
        hp: 4000,
      );
      final whole = place(game, at + const Offset(60, 60), hpFraction: 1);
      final hp = {
        for (final e in [heavy, mid, light, scratched, far, whole]) e: e.hp,
      };
      run(game, pulse);
      expect(heavy.hp, greaterThan(hp[heavy]!));
      expect(mid.hp, greaterThan(hp[mid]!));
      expect(light.hp, greaterThan(hp[light]!));
      expect(scratched.hp, hp[scratched], reason: 'only three a pulse');
      expect(far.hp, hp[far], reason: 'out of reach');
      expect(whole.hp, hp[whole], reason: 'nothing to mend');
      game.onRemove();
    },
  );

  test(
    'a body it mended waits a pulse before it can be mended again',
    () async {
      final game = await arena();
      final at = game.orb.position + const Offset(0, 520);
      mender(game, at);
      final brute = place(game, at + const Offset(140, 0), hpFraction: 0.2);
      final start = brute.hp;
      run(game, pulse);
      final once = brute.hp;
      expect(once, closeTo(start + brute.maxHp * share, 1e-6));
      run(game, CosmicSurvivalBalance.menderPulseInterval - 0.2);
      expect(brute.hp, once);
      run(game, 0.2 + CosmicSurvivalBalance.menderMendTravel + 0.1);
      expect(brute.hp, closeTo(start + 2 * brute.maxHp * share, 1e-6));
      game.onRemove();
    },
  );

  // ── Burn ──────────────────────────────────────────────────────────────────

  test(
    'a Fire or Lava ability burns what it hits; a basic attack and other elements do not',
    () async {
      final game = await arena(
        party: [
          member('Fire'),
          member('Water', slot: 1),
          member('Lava', slot: 2),
        ],
      );
      final at = game.orb.position + const Offset(0, 520);
      final fire = place(game, at);
      final water = place(game, at + const Offset(60, 0));
      final lava = place(game, at + const Offset(120, 0));
      final basic = place(game, at + const Offset(180, 0));
      game.debugAbilityDamage(fire, 1, sourceSlotIndex: 0);
      game.debugAbilityDamage(water, 1, sourceSlotIndex: 1);
      game.debugAbilityDamage(lava, 1, sourceSlotIndex: 2);
      game.debugAutoAttackDamage(basic, 1, sourceSlotIndex: 0);
      expect(fire.burnTimer, kBurnSeconds);
      expect(lava.burnTimer, kBurnSeconds);
      expect(water.burnTimer, 0);
      expect(basic.burnTimer, 0);
      game.onRemove();
    },
  );

  test('burn halves a vampiric heal too', () async {
    final game = await arena();
    final at = game.orb.position + const Offset(0, 520);
    final elite = place(game, at, hpFraction: 0.5);
    expect(game.debugHealEnemy(elite, 40), 40);
    game.debugApplyAbilityEffect(AbilityEffectKind.burn, elite, power: 0);
    expect(game.debugHealEnemy(elite, 40), 40 * kBurnHealingMultiplier);
    game.onRemove();
  });
}
