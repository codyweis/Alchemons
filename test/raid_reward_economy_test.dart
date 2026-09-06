// The Raid Beacon costs 25 gold, so completing its three-level ladder has to
// feel worthwhile. These pin the tiered currency and orb payouts while
// keeping the repeatable survival loop separate.

import 'dart:math';

import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/models/economy_balance.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('raid currency scales only with raid level', () {
    const ranges = {
      1: (200, 350, 2, 4),
      2: (400, 600, 4, 6),
      3: (650, 900, 7, 10),
    };

    test('every tier stays inside its configured range', () {
      for (final entry in ranges.entries) {
        final (silverMin, silverMax, goldMin, goldMax) = entry.value;
        for (var seed = 0; seed < 500; seed++) {
          final reward = LootBoxConfig.rollRaidVictoryCurrency(
            entry.key,
            Random(seed),
          );
          expect(reward['silver'], inInclusiveRange(silverMin, silverMax));
          expect(reward['gold'], inInclusiveRange(goldMin, goldMax));
        }
      }
    });

    test('each next tier has a strictly better reward floor', () {
      for (var seed = 0; seed < 500; seed++) {
        final l1 = LootBoxConfig.rollRaidVictoryCurrency(1, Random(seed));
        final l2 = LootBoxConfig.rollRaidVictoryCurrency(2, Random(seed));
        final l3 = LootBoxConfig.rollRaidVictoryCurrency(3, Random(seed));
        expect(l2['silver']!, greaterThan(l1['silver']!));
        expect(l3['silver']!, greaterThan(l2['silver']!));
        expect(l2['gold']!, greaterThanOrEqualTo(l1['gold']!));
        expect(l3['gold']!, greaterThan(l2['gold']!));
      }
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

    test('levels grant one, one, then two distinct orbs', () {
      for (var seed = 0; seed < 500; seed++) {
        final l1 = LootBoxConfig.rollRaidPowerupDropsForLevel(1, Random(seed));
        final l2 = LootBoxConfig.rollRaidPowerupDropsForLevel(2, Random(seed));
        final l3 = LootBoxConfig.rollRaidPowerupDropsForLevel(3, Random(seed));
        expect(l1, hasLength(1));
        expect(l2, hasLength(1));
        expect(l3, hasLength(2));
        // Level 3 must not hand out the same orb twice to fill its quota.
        expect(l3.map((e) => e.key).toSet(), hasLength(2));
        expect(l3.every((e) => orbKeys.contains(e.key)), isTrue);
        expect(l3.fold<int>(0, (a, e) => a + e.value), 2);
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
          LootBoxConfig.rollBossRematchBonusCurrency(17, Random(i))['gold'] ??
          0;
    }
    expect(total / 5000.0, lessThan(0.10));
  });

  test('wave-50 trophy copies cost 50 gold after the unlock', () {
    final offer = ShopService.allOffers.firstWhere(
      (o) => o.id == ShopService.wavebreakerCrownEffectOfferId,
    );
    expect(offer.inventoryKey, InvKeys.alchemyWavebreakerCrown);
    expect(offer.cost, const {'gold': 50});
    expect(offer.limit, PurchaseLimit.unlimited);
  });

  test('the complete raid ladder is worth the beacon that summons it', () {
    // Prices are resolved from the live offer list rather than transcribed.
    // A hardcoded table is what got this wrong the first time: the stat orbs
    // were assumed to be 40 gold (the price of the unrelated stat AURAS) when
    // they are 10, which overstated a raid by more than 10,000 silver.
    int unit(String key) {
      for (final o in ShopService.allOffers) {
        if (o.inventoryKey != key) continue;
        final g = o.cost['gold'];
        if (g != null) return g * EconomyBalance.silverPerGoldPayout;
        return o.cost['silver'] ?? 0;
      }
      return 0;
    }

    const n = 20000;
    var value = 0.0;
    for (var i = 0; i < n; i++) {
      final r = Random(i);
      // One event is L1, L2, L3, then the single delayed L3 echo.
      for (final level in const [1, 2, 3, 3]) {
        for (final d in LootBoxConfig.rollBossLootBoxDropsForQuantity(
          'lootbox.boss.fire',
          level,
          r,
        )) {
          value += unit(d.key) * d.value;
        }
        for (final o in LootBoxConfig.rollRaidPowerupDropsForLevel(level, r)) {
          value += unit(o.key) * o.value;
        }
        final c = LootBoxConfig.rollRaidVictoryCurrency(level, r);
        value +=
            (c['silver'] ?? 0) +
            (c['gold'] ?? 0) * EconomyBalance.silverPerGoldPayout;
      }
    }
    final goldEquivalent = value / n / EconomyBalance.silverPerGoldPayout;
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
    // The full event is endgame content and includes nine cache openings plus
    // six orbs. Most of that value is account-bound loot rather than Gold,
    // and the echo enforces a twelve-hour time gate, but the bundle still must
    // not wildly exceed the premium summon price.
    expect(
      goldEquivalent,
      lessThan(beacon * 5.0),
      reason: 'a raid event must stay below five times its beacon value',
    );
  });
}
