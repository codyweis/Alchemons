// Open-space boss difficulty curve targets.
//
// Design intent (see CosmicBalance boss section): levels 1-5 map onto the
// stat range — Lv3 must be beatable by a stats ~1.5-2.0 loadout (~8 DPS),
// while Lv5 keeps the previous endgame tuning exactly.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('boss health curve', () {
    test('is monotonically increasing across levels', () {
      for (var l = 1; l < 5; l++) {
        expect(
          CosmicBalance.bossHealthScale(l + 1),
          greaterThan(CosmicBalance.bossHealthScale(l)),
        );
      }
    });

    test('Lv5 endgame tuning is preserved (21×)', () {
      expect(CosmicBalance.bossHealthScale(5), closeTo(21.0, 0.001));
    });

    test('Lv3 is a stats ~2.0 fight: ≤45s at a low-stat ~8 DPS loadout', () {
      // Typical boss template health is ~28-45 (35 median).
      final lv3Hp = 35 * CosmicBalance.bossHealthScale(3);
      const lowStatDps = 8.0;
      expect(
        lv3Hp / lowStatDps,
        lessThanOrEqualTo(45),
        reason: 'Lv3 must be killable by stats 1.5-2.0 inside ~45s',
      );
      // …but not trivial either: at least ~25s for the band it targets.
      expect(lv3Hp / lowStatDps, greaterThanOrEqualTo(25));
    });

    test('early levels are flattened (Lv2 ≤ half of Lv4)', () {
      expect(
        CosmicBalance.bossHealthScale(2),
        lessThanOrEqualTo(CosmicBalance.bossHealthScale(4) / 2),
      );
    });
  });

  group('boss shield curve', () {
    test('Lv3 shield strips in ~2s at low-stat DPS; Lv5 preserved', () {
      expect(CosmicBalance.bossShieldHealth(3) / 8.0, lessThanOrEqualTo(2.2));
      expect(CosmicBalance.bossShieldHealth(5), closeTo(34.5, 0.001));
    });
  });

  group('boss damage curves', () {
    test('Lv3 gunner needs ≥6 projectile hits to kill the ship', () {
      final legacy = CosmicBalance.bossProjectileDamage(
        level: 3,
        type: BossType.gunner,
      );
      // _damageShip rescales legacy 6-HP-pool units onto the 100 HP ship.
      final shipHpPerHit = legacy * (CosmicBalance.shipMaxHealth / 6.0);
      expect(100 / shipHpPerHit, greaterThanOrEqualTo(6.0));
    });

    test('Lv5 damage ceilings are preserved', () {
      expect(
        CosmicBalance.bossProjectileDamage(level: 5, type: BossType.gunner),
        closeTo(1.5, 0.001),
      );
      expect(
        CosmicBalance.bossProjectileDamage(level: 5, type: BossType.warden),
        closeTo(1.75, 0.001),
      );
      expect(
        CosmicBalance.bossCollisionDamage(level: 5, type: BossType.charger),
        closeTo(2.2, 0.001),
      );
      expect(
        CosmicBalance.bossCollisionDamage(level: 5, type: BossType.bulwark),
        closeTo(2.25, 0.001),
      );
    });

    test('damage grows with level for every type', () {
      for (final type in BossType.values) {
        for (var l = 1; l < 5; l++) {
          expect(
            CosmicBalance.bossCollisionDamage(level: l + 1, type: type),
            greaterThan(CosmicBalance.bossCollisionDamage(level: l, type: type)),
          );
          if (type != BossType.charger) {
            expect(
              CosmicBalance.bossProjectileDamage(level: l + 1, type: type),
              greaterThan(
                CosmicBalance.bossProjectileDamage(level: l, type: type),
              ),
            );
          }
        }
      }
    });
  });

  group('boss escalation', () {
    test('post-kill escalation caps at +50%', () {
      expect(CosmicBalance.bossEscalationScale(0), 1.0);
      expect(CosmicBalance.bossEscalationScale(4), closeTo(1.2, 0.001));
      expect(CosmicBalance.bossEscalationScale(10), closeTo(1.5, 0.001));
      expect(CosmicBalance.bossEscalationScale(60), closeTo(1.5, 0.001));
    });
  });
}
