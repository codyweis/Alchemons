import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/enemy_movement.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Conduct is the single movement authority (docs/enemy_taxonomy.md §2.2).
///
/// This file previously also held characterisation tests pinning the old
/// role+variant behaviour, and equivalence tests proving charge==striker,
/// orbit==orbiter and standoff==shooter across the migration. Those did their
/// job and were deleted with the legacy code path — there is no longer a
/// second implementation to compare against, which was the point.
void main() {
  const norm = Offset(1, 0);
  const tangent = Offset(0, 1);

  Offset move(EnemyConduct conduct, double dist) => conductMoveVector(
    conduct: conduct,
    dist: dist,
    norm: norm,
    tangent: tangent,
  );

  group('conduct decides movement, and nothing overrides it', () {
    test('charge drives straight at the target', () {
      expect(move(EnemyConduct.charge, 300), norm);
    });

    test('stalk holds at range and lunges when far', () {
      // Deliberately the old POUNCER vector, not the old hunter one: hunter
      // and striker produced an identical vector, so carrying that forward
      // would have preserved a redundancy for nothing.
      final far = move(EnemyConduct.stalk, 400);
      expect(far.dx, closeTo(1.15, 1e-9));
      expect(far.dy, closeTo(0.12, 1e-9));
      expect(move(EnemyConduct.stalk, 100), norm);
    });

    test('orbit mixes approach with strafe', () {
      final m = move(EnemyConduct.orbit, 300);
      expect(m.dx, closeTo(0.55, 1e-9));
      expect(m.dy, closeTo(0.85, 1e-9));
    });

    test('standoff closes beyond 240 and kites inside it', () {
      expect(move(EnemyConduct.standoff, 300), norm);
      final near = move(EnemyConduct.standoff, 100);
      expect(near.dx, closeTo(0.0, 1e-9));
      expect(near.dy, closeTo(0.8, 1e-9));
    });

    test('drift does not move — it is provoked, not driven', () {
      expect(move(EnemyConduct.drift, 100), Offset.zero);
    });

    test('every conduct yields a finite vector at any distance', () {
      for (final c in EnemyConduct.values) {
        for (final d in [0.0, 100.0, 500.0]) {
          final m = move(c, d);
          expect(m.dx.isFinite && m.dy.isFinite, isTrue, reason: '$c at $d');
        }
      }
    });
  });

  group('one vocabulary across both modes', () {
    test('open-world behaviours map one-to-one onto conduct', () {
      expect(
        conductFromBehavior(EnemyBehavior.aggressive),
        EnemyConduct.charge,
      );
      expect(conductFromBehavior(EnemyBehavior.stalking), EnemyConduct.stalk);
      expect(conductFromBehavior(EnemyBehavior.drifting), EnemyConduct.drift);
      expect(conductFromBehavior(EnemyBehavior.feeding), EnemyConduct.graze);
      expect(
        conductFromBehavior(EnemyBehavior.territorial),
        EnemyConduct.patrol,
      );
      expect(conductFromBehavior(EnemyBehavior.swarming), EnemyConduct.swarm);
    });

    test('crusher and pouncer mean one thing now, not two', () {
      // These names existed independently in BOTH mode enums — the
      // duplication the convergence exists to remove.
      expect(
        conductFromOpenWorld(
          EnemyBehavior.drifting,
          CosmicEnemyVariant.crusher,
        ),
        EnemyConduct.charge,
      );
      expect(
        conductFromOpenWorld(EnemyBehavior.feeding, CosmicEnemyVariant.pouncer),
        EnemyConduct.stalk,
      );
    });

    test('survival roles still resolve to a conduct while the enum lives', () {
      expect(conductFromRole(CosmicEnemyRole.striker), EnemyConduct.charge);
      expect(conductFromRole(CosmicEnemyRole.hunter), EnemyConduct.stalk);
      expect(conductFromRole(CosmicEnemyRole.orbiter), EnemyConduct.orbit);
      expect(conductFromRole(CosmicEnemyRole.shooter), EnemyConduct.standoff);
    });
  });

  group('stats that used to hide inside the movement vector', () {
    test("the crusher's speed bonus is an explicit stat now", () {
      // It used to multiply the DIRECTION by 1.08 — a stat wearing a steering
      // rule's clothes.
      expect(
        conductSpeedMultiplier(EnemyConduct.charge, heavyBody: true),
        closeTo(1.08, 1e-9),
      );
      expect(
        conductSpeedMultiplier(EnemyConduct.charge, heavyBody: false),
        1.0,
      );
      expect(conductSpeedMultiplier(EnemyConduct.stalk, heavyBody: true), 1.0);
    });
  });
}
