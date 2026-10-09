// The ship comes down on the eighth visit to the wild, in whichever realm
// that is.
//
// It used to be armed the moment all four core realms had been seen — the
// fourth visit, since the opening walks the player through them in order —
// and then always landed in the Valley with its next batch. It arrived
// before the map had been the player's for a single trip, and only ever in
// one place.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/opening_wilderness_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AlchemonsDatabase db;

  setUp(() => db = AlchemonsDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String?> setting(String key) => db.settingsDao.getSetting(key);
  Future<bool> visit(String scene, {bool tutorial = false}) =>
      OpeningWildernessService.registerWildVisit(
        db.settingsDao,
        scene,
        tutorial: tutorial,
      );

  test('seven visits bring nothing; the eighth lands it where it is', () async {
    const road = ['valley', 'sky', 'swamp', 'volcano', 'sky', 'valley', 'sky'];
    for (final scene in road) {
      expect(await visit(scene), isFalse);
    }
    expect(await setting('cosmic_ship_scene'), isNull);

    expect(await visit('swamp'), isTrue);
    expect(await setting('cosmic_ship_scene'), 'swamp');
    expect(await setting('cosmic_ship_arrival_pending'), '1');
    expect(await setting(OpeningWildernessService.wildVisitsKey), '8');
  });

  test('any realm will do, not only the core four', () async {
    for (var i = 0; i < 7; i++) {
      await visit('valley');
    }
    expect(await visit('arcane'), isTrue);
    expect(await setting('cosmic_ship_scene'), 'arcane');
  });

  test('a tutorial field arms it for the next visit instead', () async {
    for (var i = 0; i < 7; i++) {
      await visit('valley');
    }
    expect(await visit('sky', tutorial: true), isFalse);
    expect(await setting('cosmic_ship_scene'), isNull);
    expect(await setting(OpeningWildernessService.shipArmedKey), '1');

    expect(await visit('volcano'), isTrue);
    expect(await setting('cosmic_ship_scene'), 'volcano');
    expect(await setting(OpeningWildernessService.shipArmedKey), isNull);
  });

  test('once down it stays put, and a claimed ship never returns', () async {
    for (var i = 0; i < 8; i++) {
      await visit('valley');
    }
    expect(await setting('cosmic_ship_scene'), 'valley');
    expect(await visit('sky'), isFalse);
    expect(await setting('cosmic_ship_scene'), 'valley');

    await db.settingsDao.deleteSetting('cosmic_ship_scene');
    await db.settingsDao.setSetting('cosmic_ship_claimed', '1');
    expect(await visit('sky'), isFalse);
    expect(await setting('cosmic_ship_scene'), isNull);
  });

  test('an older save armed for the Valley lands on its next visit', () async {
    await db.settingsDao.setSetting(
      'visited_biomes',
      'valley,sky,swamp,volcano',
    );
    await db.settingsDao.setSetting(OpeningWildernessService.shipArmedKey, '1');

    expect(await visit('sky'), isTrue);
    expect(await setting('cosmic_ship_scene'), 'sky');
  });

  test('an older save is credited with the realms it had seen', () async {
    await db.settingsDao.setSetting('visited_biomes', 'valley,sky,swamp');

    await visit('volcano');
    expect(await setting(OpeningWildernessService.wildVisitsKey), '4');
  });
}
