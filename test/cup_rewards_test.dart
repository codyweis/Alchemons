// What a cup in the Trials gives: its spotlight once, its title and its
// keepsake read off the Trials' progress.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/stadium/cup_rewards.dart';
import 'package:alchemons/games/stadium/race_cups.dart';
import 'package:alchemons/models/home_keepsakes.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/profile_titles.dart';
import 'package:alchemons/utils/alchemy_effect_apply.dart';
import 'package:alchemons/widgets/fx/alchemy_effects/alchemy_effect_paint.dart';
import 'package:alchemons/widgets/fx/keepsake_art.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AlchemonsDatabase db;
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AlchemonsDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  RaceProgress won(List<int> perCup) => RaceProgress({
    for (var i = 0; i < perCup.length; i++) kRaceCups[i].id: perCup[i],
  });

  test('a cup won gives its spotlight once', () async {
    expect(await giveCupRewards(db, won([2])), isEmpty);
    final first = await giveCupRewards(db, won([3, 1]));
    expect(first.map((r) => r.cupId), ['copper']);
    expect(await db.inventoryDao.getItemQty(InvKeys.alchemyCopperSpotlight), 1);
    // Won again (RACE AGAIN), or the Trials opened again: nothing more.
    expect(await giveCupRewards(db, won([3, 1])), isEmpty);
    expect(await db.inventoryDao.getItemQty(InvKeys.alchemyCopperSpotlight), 1);
    // Two at once, for a save that won them before cups gave anything.
    final later = await giveCupRewards(db, won([3, 3, 3]));
    expect(later.map((r) => r.cupId), ['silver', 'gold']);
    expect(later.map((r) => r.effectName), [
      'Silver Spotlight',
      'Gold Spotlight',
    ]);
  });

  test('each spotlight is an alchemy effect an Alchemon can wear', () async {
    for (final r in kCupRewards) {
      expect(AlchemyEffectPaint.has(r.effect), isTrue);
      expect(InvKeys.alchemyItemFor(r.effect), r.effectItem);
    }
    await db.creatureDao.insertInstance(instanceId: 'x', baseId: 'HOR01');
    await db.inventoryDao.addItemQty(InvKeys.alchemyGoldSpotlight, 1);
    expect(
      await applyAlchemyEffect(
        db,
        instanceId: 'x',
        itemKey: InvKeys.alchemyGoldSpotlight,
      ),
      isTrue,
    );
    expect(
      (await db.creatureDao.getInstance('x'))!.alchemyEffect,
      'gold_spotlight',
    );
  });

  test('a cup won is a title to wear', () async {
    SharedPreferences.setMockInitialValues({
      RaceProgress.prefsKey: won([3, 3, 1]).serialise(),
    });
    final titles = await ProfileTitles.load(db);
    expect(titles.earned, containsAll(['trials.copper', 'trials.silver']));
    expect(titles.earned, isNot(contains('trials.gold')));
    expect(ProfileTitles.nameOf('trials.silver'), 'Silver Cup Winner');
    expect(ProfileTitles.earnable(), containsAll(kCupTitles.keys));
    expect(await ProfileTitles.wear(db, 'trials.copper'), isTrue);
    expect(await ProfileTitles.wear(db, 'trials.gold'), isFalse);
  });

  test('a cup won is a keepsake for the home realm', () {
    final ledger = KeepsakeLedger.from(
      starsRaw: '',
      contestsRaw: '',
      racesRaw: won([3, 2]).serialise(),
      bred: const {},
      speciesName: (id) => id,
    );
    expect(ledger.owns('copper_cup'), isTrue);
    expect(ledger.owns('silver_cup'), isFalse);
    for (final r in kCupRewards) {
      expect(Keepsake.byId(r.keepsake)?.source, KeepsakeSource.cup);
      expect(KeepsakeArt.of(r.keepsake), isNotNull);
    }
  });

  test('a gem cup gives the same: its spotlight, title and keepsake', () async {
    final progress = RaceProgress({'copper': 3, 'silver': 3, 'ruby': 5});
    final given = await giveCupRewards(db, progress);
    expect(given.map((r) => r.cupId), ['copper', 'silver', 'ruby']);
    expect(await db.inventoryDao.getItemQty(InvKeys.alchemyRubySpotlight), 1);
    expect(given.last.effect, 'ruby_spotlight');
    SharedPreferences.setMockInitialValues({
      RaceProgress.prefsKey: progress.serialise(),
    });
    expect((await ProfileTitles.load(db)).earned, contains('trials.ruby'));
    final ledger = KeepsakeLedger.from(
      starsRaw: '',
      contestsRaw: '',
      racesRaw: progress.serialise(),
      bred: const {},
      speciesName: (id) => id,
    );
    expect(ledger.owns('ruby_cup'), isTrue);
    expect(ledger.owns('sapphire_cup'), isFalse);
  });
}
