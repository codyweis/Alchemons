import 'dart:ui';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/enemy_action.dart';
import 'package:flutter_test/flutter_test.dart';

/// The four-phase performance is what makes an enemy read as a creature rather
/// than a moving obstacle: idle → windUp → commit → recover.
///
/// These assert the shape of the contract, not the tuning — the numbers are
/// design values and should be free to move.
void main() {
  group('every body that acts has a readable performance', () {
    test('wisps deliberately have no action', () {
      // Thirty telegraphed attacks at once would be unreadable noise; wisps
      // are swarm chaff and fight by contact.
      expect(kEnemyActions[EnemyTier.wisp], isNull);
    });

    test('every other body has one', () {
      for (final tier in EnemyTier.values) {
        if (tier == EnemyTier.wisp) continue;
        expect(
          kEnemyActions[tier],
          isNotNull,
          reason: '${tier.name} has no signature action',
        );
      }
    });

    test('the wind-up is always long enough to see and react to', () {
      for (final entry in kEnemyActions.entries) {
        expect(
          entry.value.windUp,
          greaterThanOrEqualTo(0.3),
          reason: '${entry.key.name} fires too fast to read',
        );
      }
    });

    test('every action leaves a recover window to punish', () {
      for (final entry in kEnemyActions.entries) {
        expect(
          entry.value.recover,
          greaterThan(0),
          reason: '${entry.key.name} has no punish window',
        );
      }
    });

    test('heavier bodies telegraph longer than lighter ones', () {
      // The fairness curve: the more it hurts, the longer you get to move.
      final drone = kEnemyActions[EnemyTier.drone]!;
      final brute = kEnemyActions[EnemyTier.brute]!;
      final colossus = kEnemyActions[EnemyTier.colossus]!;
      expect(brute.windUp, greaterThan(drone.windUp));
      expect(colossus.windUp, greaterThan(brute.windUp));
    });

    test('cooldown exceeds the performance, so actions cannot chain', () {
      for (final entry in kEnemyActions.entries) {
        expect(
          entry.value.cooldown,
          greaterThan(entry.value.total),
          reason: '${entry.key.name} can re-fire before it finishes recovering',
        );
      }
    });
  });

  group('action state', () {
    test('starts idle and unbusy', () {
      final a = EnemyActionState();
      expect(a.phase, EnemyActionPhase.idle);
      expect(a.isBusy, isFalse);
      expect(a.isExposed, isFalse);
    });

    test('recover is the exposed window', () {
      final a = EnemyActionState()..phase = EnemyActionPhase.recover;
      expect(a.isExposed, isTrue);
      expect(a.isBusy, isTrue);
    });

    test('progress runs 0 to 1 and is safe at zero length', () {
      final a = EnemyActionState()..timer = 1.0;
      expect(a.progress(1.0), closeTo(0.0, 1e-9));
      a.timer = 0.25;
      expect(a.progress(1.0), closeTo(0.75, 1e-9));
      a.timer = 0.0;
      expect(a.progress(1.0), closeTo(1.0, 1e-9));
      // A zero-length phase must not divide by zero.
      expect(a.progress(0), 1.0);
    });

    test('progress clamps if the timer overshoots', () {
      final a = EnemyActionState()..timer = -0.5;
      expect(a.progress(1.0), 1.0);
      a.timer = 2.0;
      expect(a.progress(1.0), 0.0);
    });
  });

  group('ranged bosses can be caught', () {
    // The complaint this fixes: snipers backed away from the player forever,
    // so the only way to kill one was to drag it across the arena.
    test('the sniper ring fits inside the arena', () {
      // Arena radius is ~1140. The old ring was 620-760 — over half of it,
      // measured from the PLAYER, so the boss could be walked anywhere.
      final spawner = CosmicSurvivalSpawner();
      for (var i = 0; i < 50; i++) {
        final r = spawner.engagementRangeForTest(
          SurvivalBossMovementStyle.sniper,
        );
        expect(r, greaterThanOrEqualTo(430));
        expect(
          r,
          lessThan(560),
          reason: 'a ranged boss should still be reachable on screen',
        );
      }
    });

    test('snipers strafe rather than reverse', () {
      final spawner = CosmicSurvivalSpawner();
      expect(
        spawner.strafeWeightForTest(SurvivalBossMovementStyle.sniper),
        greaterThan(0.4),
        reason: 'at 0.18 it barely circled and just backed straight up',
      );
    });

    test('venting is a state a boss can actually be in', () {
      final boss = SurvivalBoss(
        template: kBossTemplates.first,
        type: BossType.gunner,
        level: 3,
        position: Offset.zero,
        hp: 100,
        maxHp: 100,
        speed: 60,
        baseSpeed: 60,
        radius: 30,
        color: const Color(0xFFFFFFFF),
      );
      expect(boss.isVenting, isFalse);
      boss.overheatTimer = 1.0;
      expect(boss.isVenting, isTrue, reason: 'the punish window must exist');
    });
  });
}
