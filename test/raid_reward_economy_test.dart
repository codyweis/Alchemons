// The Raid Beacon costs 25 gold, so a raid has to be worth roughly that or
// buying one is a tax. These pin the three levers that make it so: guaranteed
// gold, stat-orb drops, and the fact that neither leaks into the farmable
// survival loop.

import 'dart:math';

import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/models/inventory.dart';
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

    test('roughly one orb every three raids', () {
      var orbs = 0;
      const n = 40000;
      for (var i = 0; i < n; i++) {
        for (final e in LootBoxConfig.rollRaidPowerupDrops(Random(i))) {
          orbs += e.value;
        }
      }
      final perRaid = orbs / n;
      // Two independent 15% chances.
      expect(perRaid, greaterThan(0.24));
      expect(perRaid, lessThan(0.36));
    });

    test('a single raid can never dump more than two', () {
      for (var i = 0; i < 5000; i++) {
        final total = LootBoxConfig.rollRaidPowerupDrops(
          Random(i),
        ).fold<int>(0, (a, e) => a + e.value);
        expect(total, lessThanOrEqualTo(LootBoxConfig.raidPowerupChances));
      }
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

  test('a raid out-earns the 25 gold beacon that summons it', () {
    // Valued at the shop's own rate: 1 gold = 1,000 silver.
    const shopSilver = {
      'item.stamina_potion': 2500,
      'alchemy.glow': 10000,
      'alchemy.elemental_aura': 10000,
      'alchemy.volcanic_aura': 10000,
      'item.harvest_guaranteed': 1000,
      'item.boss_refresh': 25000,
    };
    int unit(String k) {
      if (shopSilver.containsKey(k)) return shopSilver[k]!;
      if (k.startsWith('item.powerup.')) return 40000;
      if (k.startsWith('key.portal') || k.startsWith('item.portal_key')) {
        return 5000;
      }
      return 999; // harvesters
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
    expect(
      goldEquivalent,
      greaterThan(25),
      reason: 'a beacon must not cost more than the raid pays',
    );
    // ...but not so far above that beacons are free money.
    expect(goldEquivalent, lessThan(45));
  });
}
