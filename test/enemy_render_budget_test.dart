// THE ENEMIES' BUDGET. Survival fields up to 3,000 bodies, and every one in
// view is drawn every frame — live under 250, from the horde atlas above
// that. The bodies are built on the unit disc with cached shaders (see
// lib/games/cosmic/enemy_body_art.dart); this keeps them blur-free and keeps
// each body's draw count where it was measured.
//
// A budget test, not a golden: it does not care what the enemies look like
// (test/enemy_look_preview_test.dart renders that), only what they cost.

import 'dart:ui';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_enemy_vfx.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/enemy_action.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter_test/flutter_test.dart';

/// Records what a frame asks the GPU to do.
class _CensusCanvas implements Canvas {
  final Map<String, int> counts = {};
  int blurredDraws = 0;

  @override
  dynamic noSuchMethod(Invocation i) {
    final n = i.memberName.toString();
    final key = n.substring(8, n.length - 2);
    counts[key] = (counts[key] ?? 0) + 1;
    for (final a in i.positionalArguments) {
      if (a is Paint && a.maskFilter != null) blurredDraws++;
    }
    if (key == 'getSaveCount') return 1;
    return null;
  }

  int get draws => counts.entries
      .where((e) => e.key.startsWith('draw'))
      .fold(0, (s, e) => s + e.value);
}

CosmicSurvivalEnemy _enemy(EnemyTier tier, {String element = 'Fire'}) =>
    CosmicSurvivalEnemy(
      position: const Offset(100, 100),
      hp: 100,
      maxHp: 100,
      speed: 60,
      damage: 10,
      radius: tierRadius(tier),
      tier: tier,
      element: element,
      conduct: EnemyConduct.charge,
      target: CosmicEnemyTarget.orb,
    );

void main() {
  // Peak draws per plain body, idle or mid-attack (the tell included), over
  // a minute of time. Measured when the bodies were rebuilt (2026-09-29);
  // the bodies before them peaked at 3 (wisp), 9 (drone), 14 (sentinel),
  // 17 (phantom), 15 (brute) and 31 (colossus). The brute and colossus are
  // faceted solids now: however many faces, each solid is one drawVertices.
  const budget = {
    EnemyTier.wisp: 3,
    EnemyTier.drone: 8,
    EnemyTier.sentinel: 11,
    EnemyTier.phantom: 10,
    EnemyTier.brute: 6,
    EnemyTier.colossus: 9,
  };

  test('no enemy body draws a blur, in any phase', () {
    for (final tier in EnemyTier.values) {
      for (final element in kElementColors.keys) {
        for (final phase in EnemyActionPhase.values) {
          final e = _enemy(tier, element: element)
            ..hitFlash = 0.6
            ..action.phase = phase
            ..action.timer = 0.1;
          final c = _CensusCanvas();
          drawSurvivalEnemy(canvas: c as Canvas, enemy: e, time: 1.3);
          expect(c.blurredDraws, 0, reason: '$tier $element $phase blurs');
        }
      }
    }
  });

  test('each body stays inside its draw budget', () {
    for (final tier in EnemyTier.values) {
      var worst = 0;
      for (var t = 0.0; t < 60; t += 0.37) {
        for (final phase in [null, ...EnemyActionPhase.values]) {
          final e = _enemy(tier);
          if (phase != null && kEnemyActions.containsKey(tier)) {
            e.action
              ..phase = phase
              ..timer = 0.1;
          }
          final c = _CensusCanvas();
          drawSurvivalEnemy(canvas: c as Canvas, enemy: e, time: t);
          if (c.draws > worst) worst = c.draws;
        }
      }
      expect(
        worst,
        lessThanOrEqualTo(budget[tier]!),
        reason: '$tier peaks at $worst draws',
      );
    }
  });

  test('bosses draw no blur and stay bounded', () {
    for (final type in BossType.values) {
      for (final enraged in [false, true]) {
        final ow = CosmicBoss(
          position: Offset.zero,
          name: type.name,
          element: 'Dark',
          level: 3,
          radius: 42,
          maxHealth: 1000,
          speed: 60,
          forcedType: type,
          charging: true,
          shieldUp: true,
          shieldHealth: 100,
        )..enraged = enraged;
        final c = _CensusCanvas();
        drawOpenWorldBoss(canvas: c as Canvas, boss: ow, time: 2.2);
        expect(c.blurredDraws, 0, reason: 'open-world $type blurs');
        expect(c.draws, lessThanOrEqualTo(30), reason: 'open-world $type');
      }
    }
    for (final d in SurvivalBossDiscipline.values) {
      final template = kBossTemplates.first;
      final boss = SurvivalBoss(
        template: template,
        type: BossType.warden,
        discipline: d,
        level: 5,
        position: Offset.zero,
        hp: 800,
        maxHp: 1000,
        speed: 70,
        baseSpeed: 70,
        radius: 40,
        color: Colors.orange,
      );
      final c = _CensusCanvas();
      drawSurvivalBoss(canvas: c as Canvas, boss: boss, time: 2.2);
      expect(c.blurredDraws, 0, reason: 'survival $d blurs');
      expect(c.draws, lessThanOrEqualTo(30), reason: 'survival $d');
    }
  });
}
