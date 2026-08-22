// The Raid Beacon costs 25 gold, so a raid has to be worth roughly that or
// buying one is a tax. These pin the three levers that make it so: guaranteed
// gold, stat-orb drops, and the fact that neither leaks into the farmable
// survival loop.

import 'dart:math';

import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('raid gold is guaranteed and sits in the 5-10 band', () {
    test('never below 5 or above 10, at any planet order', () {
      for (var order = 1; order <= 17; order++) {
        for (var seed = 0; seed < 400; seed++) {
          final gold = LootBoxConfig.rollRaidVictoryCurrency(
            order,
            Random(seed),
          )['gold']!;
          expect(gold, greaterThanOrEqualTo(5), reason: 'order $order');
          expect(gold, lessThanOrEqualTo(10), reason: 'order $order');
        }
      }
    });

    test('gold is always present — never a 1-in-20 tease', () {
      for (var seed = 0; seed < 500; seed++) {
        expect(
          LootBoxConfig.rollRaidVictoryCurrency(9, Random(seed))['gold'],
          isNotNull,
        );
      }
    });

    test('harder planets pay better', () {
      double avg(int order) {
        var t = 0.0;
        for (var i = 0; i < 4000; i++) {
          t += LootBoxConfig.rollRaidVictoryCurrency(order, Random(i))['gold']!;
        }
        return t / 4000;
      }

      expect(avg(17), greaterThan(avg(1) + 1.5));
    });

    test('silver still scales with order', () {
      final low = LootBoxConfig.rollRaidVictoryCurrency(1, Random(7))['silver']!;
      final high = LootBoxConfig.rollRaidVictoryCurrency(
        17,
        Random(7),
      )['silver']!;
      expect(high, greaterThan(low));
    });
  });

  group('stat orbs drop from raids and nowhere else', () {
    final orbKeys = {
      for (final t in AlchemicalPowerupType.values) t.inventoryKey,
    };

    test('the raid pool is exactly the four stat orbs', () {
      expect(
        LootBoxConfig.raidPowerupPool.map((d) => d.itemKey).toSet(),
        orbKeys,
      );
    });

    test('every raid yields all four orbs, guaranteed', () {
      for (var i = 0; i < 500; i++) {
        final drops = LootBoxConfig.rollRaidPowerupDrops(Random(i));
        expect(
          drops.map((e) => e.key).toSet(),
          orbKeys,
          reason: 'one of each, so no raid gives four of a stat you have',
        );
        expect(drops.fold<int>(0, (a, e) => a + e.value), 4);
      }
    });

    test('the payout does not depend on the roll — it is not a chance', () {
      final a = LootBoxConfig.rollRaidPowerupDrops(Random(1));
      final b = LootBoxConfig.rollRaidPowerupDrops(Random(999));
      expect(a.map((e) => '${e.key}:${e.value}').toSet(),
          b.map((e) => '${e.key}:${e.value}').toSet());
    });

    test('orbs stay out of the shared boss pool, which survival farms', () {
      // Survival opens the same boss loot boxes on a repeatable loop. Seeding
      // 40-gold items into it is how an economy comes apart.
      final shared = LootBoxConfig.bossLootBoxPool.map((d) => d.itemKey);
      for (final key in orbKeys) {
        expect(shared, isNot(contains(key)), reason: key);
      }
    });
  });

  test('boss rematches stay gold-scarce — raids did not drag them along', () {
    // Rematches are repeatable, so their scarcity is deliberate and separate.
    var total = 0;
    for (var i = 0; i < 5000; i++) {
      total +=
          LootBoxConfig.rollBossRematchBonusCurrency(17, Random(i))['gold'] ?? 0;
    }
    expect(total / 5000.0, lessThan(0.10));
  });

  test('a raid is worth roughly the beacon that summons it', () {
    // Prices are resolved from the live offer list rather than transcribed.
    // A hardcoded table is what got this wrong the first time: the stat orbs
    // were assumed to be 40 gold (the price of the unrelated stat AURAS) when
    // they are 5, which overstated a raid by more than 10,000 silver.
    int unit(String key) {
      for (final o in ShopService.allOffers) {
        if (o.inventoryKey != key) continue;
        final g = o.cost['gold'];
        if (g != null) return g * 1000; // shop's own rate: 1 gold = 1,000
        return o.cost['silver'] ?? 0;
      }
      return 0;
    }

    const n = 20000;
    var value = 0.0;
    for (var i = 0; i < n; i++) {
      final r = Random(i);
      for (final d in LootBoxConfig.rollBossLootBoxDropsForQuantity(
        'lootbox.boss.fire',
        3,
        r,
      )) {
        value += unit(d.key) * d.value;
      }
      for (final o in LootBoxConfig.rollRaidPowerupDrops(r)) {
        value += unit(o.key) * o.value;
      }
      final c = LootBoxConfig.rollRaidVictoryCurrency(9, r);
      value += (c['silver'] ?? 0) + (c['gold'] ?? 0) * 1000;
    }
    final goldEquivalent = value / n / 1000;
    final beacon = ShopService.allOffers
        .firstWhere((o) => o.inventoryKey == InvKeys.raidBeacon)
        .cost['gold']!;

    // A beacon buys immediacy on content the 48h rotation gives away, so a
    // small premium is fine — but the raid must not pay only a fraction of
    // what summoning it cost.
    expect(
      goldEquivalent,
      greaterThan(beacon.toDouble()),
      reason:
          'raid pays ${goldEquivalent.toStringAsFixed(1)}g '
          'vs a ${beacon}g beacon — summoning must be worth it',
    );
    // Generous by design, but a beacon that pays for two more is a loop that
    // prints gold. Raids are also free on the 48h rotation, so this ceiling
    // is what keeps beacon-buying a choice rather than an obligation.
    expect(
      goldEquivalent,
      lessThan(beacon * 2.0),
      reason: 'a raid must not fund two more beacons',
    );
  });
}
