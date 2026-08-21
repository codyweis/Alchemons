import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/enemy_movement.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Characterisation tests: these pin the movement behaviour AS IT IS, so the
/// taxonomy change (role + variant → one conduct, docs/enemy_taxonomy.md §3)
/// can be proved to preserve it. They are not a statement that the current
/// behaviour is desirable — §2.2 argues it is not.
void main() {
  const norm = Offset(1, 0);
  const tangent = Offset(0, 1);

  Offset move(
    CosmicEnemyRole role,
    SurvivalEnemyVariant variant,
    double dist,
  ) => enemyMoveVector(
    role: role,
    variant: variant,
    dist: dist,
    norm: norm,
    tangent: tangent,
  );

  group('role movement', () {
    test('striker drives straight at the target', () {
      expect(
        move(CosmicEnemyRole.striker, SurvivalEnemyVariant.standard, 300),
        norm,
      );
    });

    test('hunter is IDENTICAL to striker — two roles, one vector', () {
      for (final d in [50.0, 200.0, 400.0]) {
        expect(
          move(CosmicEnemyRole.hunter, SurvivalEnemyVariant.standard, d),
          move(CosmicEnemyRole.striker, SurvivalEnemyVariant.standard, d),
          reason: 'documented redundancy at distance $d',
        );
      }
    });

    test('orbiter mixes approach with strafe', () {
      final m = move(
        CosmicEnemyRole.orbiter,
        SurvivalEnemyVariant.standard,
        300,
      );
      expect(m.dx, closeTo(0.55, 1e-9));
      expect(m.dy, closeTo(0.85, 1e-9));
    });

    test('shooter closes beyond 240 and strafes inside it', () {
      expect(
        move(CosmicEnemyRole.shooter, SurvivalEnemyVariant.standard, 300),
        norm,
      );
      final near = move(
        CosmicEnemyRole.shooter,
        SurvivalEnemyVariant.standard,
        100,
      );
      expect(near.dx, closeTo(0.0, 1e-9));
      expect(near.dy, closeTo(0.8, 1e-9));
    });
  });

  group('variant overrides role', () {
    test('crusher ignores its role entirely', () {
      for (final role in CosmicEnemyRole.values) {
        final m = move(role, SurvivalEnemyVariant.crusher, 300);
        expect(m.dx, closeTo(1.08, 1e-9), reason: 'role $role was discarded');
        expect(m.dy, closeTo(0.0, 1e-9));
      }
    });

    test('pouncer ignores its role, and darts only when far', () {
      final far = move(
        CosmicEnemyRole.orbiter,
        SurvivalEnemyVariant.pouncer,
        300,
      );
      expect(far.dx, closeTo(1.15, 1e-9));
      expect(far.dy, closeTo(0.12, 1e-9));
      expect(
        move(CosmicEnemyRole.orbiter, SurvivalEnemyVariant.pouncer, 100),
        norm,
      );
    });

    test('every other variant leaves the role vector alone', () {
      const passthrough = [
        SurvivalEnemyVariant.standard,
        SurvivalEnemyVariant.orbBreaker,
        SurvivalEnemyVariant.siegeShooter,
        SurvivalEnemyVariant.summoner,
        SurvivalEnemyVariant.splitter,
      ];
      for (final v in passthrough) {
        expect(
          move(CosmicEnemyRole.orbiter, v, 300),
          move(CosmicEnemyRole.orbiter, SurvivalEnemyVariant.standard, 300),
          reason: '$v should not touch movement',
        );
      }
    });
  });

  group('conduct equivalence with the old scheme', () {
    Offset c(EnemyConduct conduct, double dist) => conductMoveVector(
      conduct: conduct,
      dist: dist,
      norm: norm,
      tangent: tangent,
    );

    test('charge == striker', () {
      for (final d in [50.0, 200.0, 400.0]) {
        expect(
          c(EnemyConduct.charge, d),
          move(CosmicEnemyRole.striker, SurvivalEnemyVariant.standard, d),
        );
      }
    });

    test('orbit == orbiter', () {
      for (final d in [50.0, 200.0, 400.0]) {
        expect(
          c(EnemyConduct.orbit, d),
          move(CosmicEnemyRole.orbiter, SurvivalEnemyVariant.standard, d),
        );
      }
    });

    test('standoff == shooter, including the 240 threshold', () {
      for (final d in [100.0, 239.0, 241.0, 400.0]) {
        expect(
          c(EnemyConduct.standoff, d),
          move(CosmicEnemyRole.shooter, SurvivalEnemyVariant.standard, d),
          reason: 'distance $d',
        );
      }
    });

    test('stalk == the old POUNCER, not the old hunter', () {
      for (final d in [100.0, 139.0, 141.0, 400.0]) {
        expect(
          c(EnemyConduct.stalk, d),
          move(CosmicEnemyRole.orbiter, SurvivalEnemyVariant.pouncer, d),
          reason: 'distance $d',
        );
      }
    });

    test('stalk deliberately DIFFERS from the old hunter when far', () {
      // The intended behaviour change: hunters used to drive straight in.
      expect(
        c(EnemyConduct.stalk, 400),
        isNot(move(CosmicEnemyRole.hunter, SurvivalEnemyVariant.standard, 400)),
      );
    });
  });

  group('mappings', () {
    test('crusher and pouncer become conducts, carrying no trait', () {
      expect(
        conductFromRoleVariant(
          CosmicEnemyRole.orbiter,
          SurvivalEnemyVariant.crusher,
        ),
        EnemyConduct.charge,
      );
      expect(
        conductFromRoleVariant(
          CosmicEnemyRole.shooter,
          SurvivalEnemyVariant.pouncer,
        ),
        EnemyConduct.stalk,
      );
      expect(traitFromVariant(SurvivalEnemyVariant.crusher), isNull);
      expect(traitFromVariant(SurvivalEnemyVariant.pouncer), isNull);
    });

    test('only the three real mechanics survive as traits', () {
      expect(
        traitFromVariant(SurvivalEnemyVariant.summoner),
        EnemyTrait.summoner,
      );
      expect(
        traitFromVariant(SurvivalEnemyVariant.splitter),
        EnemyTrait.splitter,
      );
      expect(
        traitFromVariant(SurvivalEnemyVariant.orbBreaker),
        EnemyTrait.breaker,
      );
      expect(traitFromVariant(SurvivalEnemyVariant.siegeShooter), isNull);
      expect(traitFromVariant(SurvivalEnemyVariant.standard), isNull);
    });

    test("the crusher's hidden speed bonus survives as an explicit stat", () {
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

  group('the two modes now agree', () {
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

    test('crusher means the same thing in both modes', () {
      expect(
        conductFromOpenWorld(
          EnemyBehavior.drifting,
          CosmicEnemyVariant.crusher,
        ),
        conductFromRoleVariant(
          CosmicEnemyRole.shooter,
          SurvivalEnemyVariant.crusher,
        ),
        reason: 'the duplication this whole change exists to remove',
      );
    });

    test('pouncer means the same thing in both modes', () {
      expect(
        conductFromOpenWorld(EnemyBehavior.feeding, CosmicEnemyVariant.pouncer),
        conductFromRoleVariant(
          CosmicEnemyRole.orbiter,
          SurvivalEnemyVariant.pouncer,
        ),
      );
    });

    test('every conduct yields a finite vector', () {
      for (final c in EnemyConduct.values) {
        for (final d in [0.0, 100.0, 500.0]) {
          final m = conductMoveVector(
            conduct: c,
            dist: d,
            norm: norm,
            tangent: tangent,
          );
          expect(m.dx.isFinite && m.dy.isFinite, isTrue, reason: '$c at $d');
        }
      }
    });

    test('drift does not move — it is provoked, not driven', () {
      expect(
        conductMoveVector(
          conduct: EnemyConduct.drift,
          dist: 100,
          norm: norm,
          tangent: tangent,
        ),
        Offset.zero,
      );
    });
  });
}
