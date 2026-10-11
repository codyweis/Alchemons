// Tincture is earned inside the flows that already pay their rewards
// (docs/athanor_design.md, "Earning tincture"), each with a line where that
// flow shows what it paid.
//
// Covered here: raid victory, dungeon stars and achievement claims, which
// have database-level grant functions. Survival's run end, the pureblood
// rite and space contests grant inside screen state or need a full
// creature to offer; their amounts are pinned in athanor_draw_test.dart.

import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_rewards.dart';
import 'package:alchemons/games/planet_dungeon/raid_rewards.dart';
import 'package:alchemons/models/athanor.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/services/campaign_journal_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AlchemonsDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AlchemonsDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<int> tincture() => db.inventoryDao.getItemQty(InvKeys.athanorTincture);

  test('a raid victory pays 3 / 5 / 8 tincture, with its own line', () async {
    var expected = 0;
    for (final level in [1, 2, 3]) {
      final entries = await grantRaidRewards(
        db: db,
        element: 'volcanic',
        raidLevel: level,
        rng: Random(level),
      );
      expected += athanorRaidTincture(level);
      expect(await tincture(), expected);
      final line = entries.where((e) => e.itemKey == InvKeys.athanorTincture);
      expect(line, hasLength(1));
      expect(line.single.label, '+${athanorRaidTincture(level)} Tincture');
    }
    expect(expected, 3 + 5 + 8);
  });

  test('each dungeon star pays 3 tincture, with its own line', () async {
    final star1 = await grantStarReward(
      db: db,
      element: 'volcanic',
      starIndex: 0,
    );
    expect(star1, ['+10 Gold', '+3 Tincture']);
    expect(await tincture(), 3);

    final star2 = await grantStarReward(
      db: db,
      element: 'volcanic',
      starIndex: 1,
      rng: Random(1),
    );
    expect(star2.last, '+3 Tincture');
    expect(await tincture(), 6);

    final star3 = await grantStarReward(
      db: db,
      element: 'volcanic',
      starIndex: 2,
      choice: Star3Choice.gold,
    );
    expect(star3.last, '+3 Tincture');
    expect(star3, contains('+25 Gold'));
    expect(await tincture(), 9);

    // Not a star: nothing at all.
    expect(
      await grantStarReward(db: db, element: 'volcanic', starIndex: 5),
      isEmpty,
    );
    expect(await tincture(), 9);
    // Each counted as paid, so first fire does not pay them back.
    expect(await db.settingsDao.getSetting(kAthanorPaidStarsKey), '3');
  });

  test(
    'an achievement claim pays 3 tincture, once, in its transaction',
    () async {
      await db.settingsDao.setSetting('first_extraction_done', '1');
      final service = CampaignJournalService(db);
      final results = await Future.wait([
        service.claim('first_extraction'),
        service.claim('first_extraction'),
      ]);
      expect(results.where((r) => r), hasLength(1));
      expect(await tincture(), kAthanorAchievementTincture);
      expect(await service.claim('first_extraction'), isFalse);
      expect(await tincture(), kAthanorAchievementTincture);
      // Counted as paid, so first fire does not pay it back.
      expect(await db.settingsDao.getSetting(kAthanorPaidAchievementsKey), '1');
      expect(await CampaignJournalService.claimedCount(db), 1);
    },
  );

  test('a tincture write that fails rolls the whole claim back', () async {
    await db.settingsDao.setSetting('first_extraction_done', '1');
    final gold = await db.currencyDao.getGoldBalance();
    await db.customStatement(
      "CREATE TRIGGER fail_tincture BEFORE INSERT ON inventory_items WHEN "
      "NEW.key = '${InvKeys.athanorTincture}' "
      "BEGIN SELECT RAISE(ABORT, 'injected'); END",
    );
    await expectLater(
      CampaignJournalService(db).claim('first_extraction'),
      throwsA(anything),
    );
    expect(
      await db.settingsDao.getSetting('campaign_claim_first_extraction'),
      isNull,
    );
    expect(await db.currencyDao.getGoldBalance(), gold);
    expect(await tincture(), 0);
  });
}
