import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/wild_rotation.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// The wild map shows four realms. These pin which: the first four until
// anything is bought (and through the opening), then a random four a day of
// all owned, held for the day, a realm just bought always among them, and
// each of the first four in its own corner when it is out.
void main() {
  late AlchemonsDatabase db;
  setUp(() => db = AlchemonsDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> buyDunes() =>
      db.settingsDao.setSetting('scene_unlocked_dunes', '1');
  Future<void> pastOpening() =>
      db.settingsDao.setSetting('cosmic_ship_unlocked', '1');

  test('nothing bought: the first four, every day', () async {
    await pastOpening();
    for (var d = 1; d <= 20; d++) {
      expect(
        await WildRotation.today(db.settingsDao, now: DateTime(2026, 10, d)),
        kCoreRealms,
      );
    }
  });

  test('through the opening the first four stay, bought or not', () async {
    await buyDunes();
    expect(await WildRotation.today(db.settingsDao), kCoreRealms);
  });

  test('a realm bought is out the day it is bought', () async {
    await pastOpening();
    final day = DateTime(2026, 10, 5);
    expect(await WildRotation.today(db.settingsDao, now: day), kCoreRealms);
    await buyDunes();
    final four = await WildRotation.today(db.settingsDao, now: day);
    expect(four, contains('dunes'));
    expect(four.toSet(), hasLength(4));
    // And held for the day.
    for (var i = 0; i < 5; i++) {
      expect(await WildRotation.today(db.settingsDao, now: day), four);
    }
  });

  test('after that, a random four a day of all five, each core realm in '
      'its own corner', () async {
    await pastOpening();
    await buyDunes();
    await WildRotation.today(db.settingsDao, now: DateTime(2026, 10, 5));
    final seen = <String>{};
    var withoutDunes = 0;
    for (var d = 6; d <= 60; d++) {
      final four = await WildRotation.today(
        db.settingsDao,
        now: DateTime(2026, 10, 1).add(Duration(days: d)),
      );
      expect(four.toSet(), hasLength(4));
      seen.addAll(four);
      if (!four.contains('dunes')) withoutDunes++;
      for (var i = 0; i < 4; i++) {
        final home = kCoreRealms.indexOf(four[i]);
        if (home >= 0) expect(home, i, reason: '${four[i]} out of its corner');
      }
    }
    expect(seen, {...kCoreRealms, 'dunes'});
    // Not always the Dunes: about one day in five without it.
    expect(withoutDunes, inInclusiveRange(3, 25));
  });

  test('Living Sands is a home only: bought, it never comes out', () async {
    await pastOpening();
    await db.settingsDao.setSetting('scene_unlocked_sand', '1');
    // Bought alone, nothing changes in the wild.
    expect(await WildRotation.today(db.settingsDao), kCoreRealms);
    await buyDunes();
    for (var d = 1; d <= 40; d++) {
      expect(
        await WildRotation.today(db.settingsDao, now: DateTime(2026, 10, d)),
        isNot(contains('sand')),
      );
    }
  });
}
