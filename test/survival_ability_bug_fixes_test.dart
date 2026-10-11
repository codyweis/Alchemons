import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_ability_runtime.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/mane_runtime.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 1 of the ability pass (2026-10-09): specials that broke at high
/// stats or ran away. Each of these failed on the code before the fix.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember kin(String element, double stat) => CosmicPartyMember(
    instanceId: 'kin-0',
    baseId: 'KIN01',
    displayName: 'Kin $element',
    family: 'Kin',
    element: element,
    level: 10,
    slotIndex: 0,
    statSpeed: stat,
    statIntelligence: stat,
    statStrength: stat,
    statBeauty: stat,
    statSpeedPotential: 100,
    statIntelligencePotential: 100,
    statStrengthPotential: 100,
    statBeautyPotential: 100,
    staminaBars: 3,
    staminaMax: 3,
  );

  CosmicSurvivalEnemy dummy(Offset at) => CosmicSurvivalEnemy(
    position: at,
    hp: 1e6,
    maxHp: 1e6,
    speed: 0,
    damage: 0,
    radius: 10,
    tier: EnemyTier.drone,
    element: 'Earth',
    conduct: EnemyConduct.charge,
    target: CosmicEnemyTarget.orb,
    retargetTimer: 0,
  );

  Future<CosmicSurvivalGame> arena(String element) async {
    final game = CosmicSurvivalGame(
      party: [kin(element, 11)],
      onGameOver: () {},
      random: Random(5),
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    game.summonCompanion(0);
    game.enemies.clear();
    final comp = game.activeCompanions[0]!;
    game.enemies.add(dummy(comp.position + const Offset(140, 0)));
    return game;
  }

  void frames(CosmicSurvivalGame game, int n) {
    for (var i = 0; i < n; i++) {
      game.enemies.removeWhere((e) => e.hp < 1e5);
      game.update(1 / 60);
    }
  }

  group('Kin recasts', () {
    test('a recast mid-charge leaves Kin Ice charging, so it releases', () async {
      final game = await arena('Ice');
      final comp = game.activeCompanions[0]!;
      comp.specialCooldown = 0;
      var guard = 0;
      while (comp.kinIceChargeTimer <= 0 && guard++ < 120) {
        frames(game, 1);
      }
      expect(comp.kinIceChargeTimer, greaterThan(0), reason: 'never cast');
      final total = comp.kinIceChargeTotal;

      frames(game, 60);
      final beforeRecast = comp.kinIceChargeTimer;
      comp.specialCooldown = 0;
      frames(game, 1);
      expect(
        comp.kinIceChargeTimer,
        lessThan(beforeRecast),
        reason: 'the recast restarted the charge',
      );

      // The charge reaches zero and releases. A fast Kin comes back in about
      // two seconds and starts a fresh charge, which can only follow a
      // release now that a running charge cannot be restarted.
      var released = false;
      var last = comp.kinIceChargeTimer;
      for (var i = 0; i < (total * 60).ceil() + 30 && !released; i++) {
        frames(game, 1);
        final now = comp.kinIceChargeTimer;
        if (now <= 0 || now > last) released = true;
        last = now;
      }
      expect(released, isTrue, reason: 'the frost never released');
    });

    test('a recast while the boiler is lit keeps Kin Steam\'s stacks', () async {
      final game = await arena('Steam');
      final comp = game.activeCompanions[0]!;
      comp.specialCooldown = 0;
      var guard = 0;
      while (comp.kinSteamBoilerTimer <= 0 && guard++ < 120) {
        frames(game, 1);
      }
      expect(comp.kinSteamBoilerTimer, greaterThan(0), reason: 'never cast');

      comp.kinSteamBoilerStacks = 6;
      comp.specialCooldown = 0;
      frames(game, 1);
      expect(comp.kinSteamBoilerStacks, greaterThanOrEqualTo(5));
    });
  });

  group('Mane pool crowding', () {
    Projectile shot({bool stationary = false}) => Projectile(
      position: Offset.zero,
      angle: 0,
      damage: 40,
      element: 'Lava',
      piercing: true,
      stationary: stationary,
      abilityFamily: 'mane',
    );

    test('only the Lava shot drops blobs, never a blob', () {
      final first = shot()..effectHitIds.add(1);
      expect(ManeRuntime.dropsLavaBlob(first), isTrue);
      final blob = ManeRuntime.lavaBlob(first, Offset.zero)..effectHitIds.add(1);
      expect(ManeRuntime.dropsLavaBlob(blob), isFalse);
    });

    test('a Lava shot drops blobs for its first few bodies only', () {
      final p = shot();
      final drops = <bool>[];
      for (var id = 0; id < ManeRuntime.lavaBlobsPerShot + 3; id++) {
        p.effectHitIds.add(id);
        drops.add(ManeRuntime.dropsLavaBlob(p));
      }
      expect(drops.where((d) => d).length, ManeRuntime.lavaBlobsPerShot);
    });

    test('the Dust trail stops at its budget', () {
      final dust = Projectile(
        position: Offset.zero,
        angle: 0,
        element: 'Dust',
        abilityFamily: 'mane',
      );
      final puffs = [
        for (var i = 0; i < ManeRuntime.dustTrailBudget - 1; i++)
          ManeRuntime.dustTrailPuff(dust),
      ];
      expect(ManeRuntime.dustTrailHasRoom(puffs), isTrue);
      puffs.add(ManeRuntime.dustTrailPuff(dust));
      expect(ManeRuntime.dustTrailHasRoom(puffs), isFalse);
    });
  });

  group('heal ceiling', () {
    test('a caster heals at most its banked share, then refills', () {
      final ceiling = HealCeiling();
      const pool = 1000.0;
      final first = ceiling.grant(
        slot: 0,
        amount: 1e6,
        pool: pool,
        beauty: kAbilityStatAverage,
        now: 0,
      );
      // Two seconds of 1.2 % a second at average Beauty.
      expect(first, closeTo(pool * 0.012 * 2, 0.01));
      expect(
        ceiling.grant(
          slot: 0,
          amount: 1e6,
          pool: pool,
          beauty: kAbilityStatAverage,
          now: 0,
        ),
        0,
      );
      expect(
        ceiling.grant(
          slot: 0,
          amount: 1e6,
          pool: pool,
          beauty: kAbilityStatAverage,
          now: 1,
        ),
        closeTo(pool * 0.012, 0.01),
      );
    });

    test('each caster has its own budget, and Beauty raises it', () {
      final ceiling = HealCeiling();
      double take(int slot, double beauty) => ceiling.grant(
        slot: slot,
        amount: 1e6,
        pool: 1000,
        beauty: beauty,
        now: 0,
      );
      final average = take(0, kAbilityStatAverage);
      final perfect = take(1, 12);
      expect(perfect, greaterThan(average * 1.5));
    });

    test('small heals pass whole while the budget lasts', () {
      final ceiling = HealCeiling();
      expect(
        ceiling.grant(
          slot: 0,
          amount: 3,
          pool: 1000,
          beauty: kAbilityStatAverage,
          now: 0,
        ),
        3,
      );
    });
  });
}
