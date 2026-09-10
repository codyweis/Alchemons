// Open-space bosses use level-10 breeding benchmarks. These are stationary
// basic-attack timing checks, not simulated win rates or guaranteed clears.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/models/stat_system.dart';
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

    test('Lv5 has room for optimized level-10 team damage (60×)', () {
      expect(CosmicBalance.bossHealthScale(5), closeTo(60.0, 0.001));
    });

    test('Lv3 fits a level-10 P70 trio basic-attack budget', () {
      // Typical boss template health is ~28-45 (35 median).
      final lv3Hp = 35 * CosmicBalance.bossHealthScale(3);
      final stat = AlchemonStatSystem.effectiveInternal(
        speciesBase: 60,
        level: 10,
        potential: 70,
      );
      final attack = CosmicBalance.companionPhysAtk(level: 10, strength: stat);
      final cooldown =
          CosmicCompanion.baseBasicCooldown /
          CosmicBalance.companionCooldownReduction(stat) /
          (1.0 + (attack - 1) * 0.05);
      final lowStatDps = 3 * attack / cooldown;
      expect(
        lv3Hp / lowStatDps,
        lessThanOrEqualTo(45),
        reason: 'A neutral P70 trio should have a 25-45s basic-only HP budget',
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
            greaterThan(
              CosmicBalance.bossCollisionDamage(level: l, type: type),
            ),
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
}
