// The Chronal Catalyst: half cultivation time for a day.
//
// Three different paths switch it on — a shop purchase, the hundred-species
// milestone, and the grant that comes with a new save — so the rule about
// what happens when they overlap has to be one rule.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/campaign_journal_service.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/services/timed_boost_service.dart';
import 'package:alchemons/utils/cultivation_time.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AlchemonsDatabase db;
  late TimedBoostService boosts;

  setUp(() {
    db = AlchemonsDatabase(NativeDatabase.memory());
    boosts = TimedBoostService(db.settingsDao);
  });
  tearDown(() async => db.close());

  group('the boost itself', () {
    test('a fresh save has none', () async {
      await boosts.load();
      expect(boosts.halfCultivationActive, isFalse);
      expect(boosts.halfCultivationRemaining, Duration.zero);
    });

    test('granting runs for a day and survives a reload', () async {
      await boosts.grantHalfCultivation();
      expect(boosts.halfCultivationActive, isTrue);
      expect(
        boosts.halfCultivationRemaining.inHours,
        greaterThanOrEqualTo(23),
      );

      // A relaunch reads it back off the clock, not off a counter.
      final reloaded = TimedBoostService(db.settingsDao);
      await reloaded.load();
      expect(reloaded.halfCultivationActive, isTrue);
    });

    test('a second grant stacks instead of resetting', () async {
      await boosts.grantHalfCultivation();
      await boosts.grantHalfCultivation();
      expect(
        boosts.halfCultivationRemaining.inHours,
        greaterThanOrEqualTo(47),
        reason: 'buying a day while a day runs must not throw the first away',
      );
    });

    test('an expired boost is not active', () async {
      final past = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      await db.settingsDao.setSetting(
        TimedBoostService.halfCultivationKey,
        '${past.millisecondsSinceEpoch}',
      );
      await boosts.load();
      expect(boosts.halfCultivationActive, isFalse);
      expect(boosts.halfCultivationRemaining, Duration.zero);
    });

    test('the opening grant happens once per save', () async {
      await boosts.giveOpeningGrant();
      final first = boosts.halfCultivationUntil;
      await boosts.giveOpeningGrant();
      expect(
        boosts.halfCultivationUntil,
        first,
        reason: 'a second call must not extend it',
      );
    });
  });

  group('what it does to a cultivation', () {
    const base = Duration(hours: 4);

    test('halves the time, and only while it is on', () {
      expect(cultivationDuration(base: base), base);
      expect(
        cultivationDuration(base: base, halfCultivation: true),
        const Duration(hours: 2),
      );
    });

    test('multiplies with the other reductions rather than replacing them', () {
      // 4h, 10% constellation gestation, fire perk halving, then the boost.
      final withoutBoost = cultivationDuration(
        base: base,
        gestationReduction: 0.10,
        fireMultiplier: 0.5,
      );
      final withBoost = cultivationDuration(
        base: base,
        gestationReduction: 0.10,
        fireMultiplier: 0.5,
        halfCultivation: true,
      );
      expect(withoutBoost, const Duration(hours: 1, minutes: 48));
      expect(withBoost.inMilliseconds, withoutBoost.inMilliseconds ~/ 2);
    });
  });

  group('where it comes from', () {
    test('the shop sells it for 250 gold', () {
      final offer = ShopService.allOffers.firstWhere(
        (o) => o.id == ShopService.halfCultivationOfferId,
      );
      expect(offer.cost['gold'], 250);
      expect(offer.rewardType, 'boost');
    });

    test('a hundred species pays in time', () {
      final achievement = campaignAchievements.firstWhere(
        (a) => a.id == 'collection_100',
      );
      expect(achievement.target, 100);
      expect(
        achievement.halfCultivation,
        TimedBoostService.halfCultivationDuration,
      );
    });

    test('nothing else hands out a timed boost unnoticed', () {
      final withBoost = campaignAchievements
          .where((a) => a.halfCultivation != null)
          .map((a) => a.id);
      expect(withBoost, ['collection_100']);
    });
  });
}
