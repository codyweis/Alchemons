import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/components/survival_hud.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_balance.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The orb's shield (2026-10-10). Companion shields used to be copied onto
/// the orb, a second health bar that refilled on every Horn or Kin cast and
/// carried weak teams far past where they fell. Now a companion's shield
/// stays on the companion; the orb's shield comes from cleared boss waves;
/// and past the opening waves the orb hardens instead.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember member(String family, String element) => CosmicPartyMember(
    instanceId: '$family-$element',
    baseId: 'HOR02',
    displayName: '$family $element',
    family: family,
    element: element,
    level: 10,
    slotIndex: 0,
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

  Future<CosmicSurvivalGame> start(CosmicPartyMember m) async {
    final game = CosmicSurvivalGame(
      party: [m],
      onGameOver: () {},
      random: Random(5),
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    return game;
  }

  test('a shield special stays on its companion, not the orb', () async {
    final game = await start(member('Horn', 'Earth'));
    game.summonCompanion(0);
    for (
      var i = 0;
      i < 600 && game.enemies.where((e) => !e.isDead).isEmpty;
      i++
    ) {
      game.update(1 / 60);
    }
    final template = game.enemies.first;
    for (final e in game.enemies) {
      e.isDead = true;
    }
    final target = CosmicSurvivalEnemy(
      position: game.orb.position + const Offset(300, 0),
      hp: 1000000,
      maxHp: 1000000,
      speed: 0,
      damage: 0,
      radius: 14,
      tier: template.tier,
      element: template.element,
      conduct: template.conduct,
      target: template.target,
    );
    game.enemies.add(target);
    final comp = game.activeCompanions[0]!;
    comp.position = target.position - const Offset(120, 0);
    comp.specialCooldown = 0;
    game.orb.shieldHp = 0;
    for (var i = 0; i < 600 && comp.shieldHp <= 0; i++) {
      game.update(1 / 60);
    }
    expect(comp.shieldHp, greaterThan(0), reason: 'the Earth Horn cast');
    expect(game.orb.shieldHp, 0);
    expect(game.orbShieldFraction, 0);
  });

  test('a cleared boss wave shields the orb for 4% of its health', () async {
    final game = await start(member('Pip', 'Fire'));
    for (var w = 1; w < 5; w++) {
      game.spawner.resumeAfterIntermission();
    }
    expect(game.spawner.isBossWave, isTrue);
    expect(game.orb.shieldHp, 0);
    var sawBoss = false;
    for (var i = 0; i < 30 * 240 && game.spawner.currentWave == 5; i++) {
      for (final e in game.enemies) {
        e.isDead = true;
      }
      for (final boss in game.allLivingBosses.toList()) {
        sawBoss = true;
        game.damageBoss(1e12, target: boss);
      }
      if (game.showingPowerUpSelection) {
        game.alchemicalMeter = 0;
        game.dismissPowerUpSelection();
      }
      game.update(1 / 30);
    }
    expect(sawBoss, isTrue);
    expect(game.spawner.currentWave, 6);
    final grant = max(12, (game.orb.maxHp * 0.04).round());
    expect(game.orb.shieldHp, grant);
    expect(game.orbShieldFraction, closeTo(grant / game.orb.maxHp, 1e-9));
  });

  test('the orb takes every point through the opening waves', () {
    for (var wave = 1; wave <= CosmicSurvivalBalance.orbHardeningWave; wave++) {
      expect(CosmicSurvivalBalance.orbWaveDamageShare(wave), 1.0);
    }
    var last = 1.0;
    for (var wave = 11; wave <= 120; wave++) {
      final share = CosmicSurvivalBalance.orbWaveDamageShare(wave);
      expect(share, lessThan(last), reason: 'wave $wave');
      expect(share, greaterThan(0.1), reason: 'wave $wave');
      last = share;
    }
  });

  test('a hit on the orb late in a run lands at the hardened share', () async {
    final game = await start(member('Pip', 'Fire'));
    for (var w = 1; w < 30; w++) {
      game.spawner.resumeAfterIntermission();
    }
    final before = game.orb.currentHp;
    game.debugDamageOrb(100);
    expect(
      before - game.orb.currentHp,
      closeTo(100 * CosmicSurvivalBalance.orbWaveDamageShare(30), 1e-6),
    );
  });

  testWidgets('the orb gauge reads a held shield, and nothing without one', (
    tester,
  ) async {
    Widget hud(double shield) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 420,
          child: SurvivalTopHud(
            wave: 6,
            time: '02:10',
            keys: const [],
            shipFraction: 1,
            shipGhost: false,
            orbFraction: 0.62,
            orbColor: const Color(0xFF1FD3EA),
            orbShield: shield,
          ),
        ),
      ),
    );
    await tester.pumpWidget(hud(0.06));
    expect(find.textContaining('+6'), findsOneWidget);
    final tubes = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((p) => p.painter)
        .whereType<HudTubePainter>()
        .toList();
    expect(tubes.map((t) => t.shield), containsAll([0.0, 0.06]));

    await tester.pumpWidget(hud(0));
    expect(find.textContaining('+'), findsNothing);
  });
}
