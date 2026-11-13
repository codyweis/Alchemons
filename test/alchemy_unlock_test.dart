import 'dart:convert';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/heart_puzzle/alchemy_unlock.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/services/alchemical_encyclopedia_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ALCHEMY opens once a formula is found that makes each of the seventeen
// elements: one each is enough, and family formulas do not count.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadNatures);

  test('one formula for each element opens Alchemy, and not one fewer', () async {
    SharedPreferences.setMockInitialValues({});
    final db = AlchemonsDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final fresh = await AlchemyUnlock.load(db: db);
    expect(fresh.total, 17);
    expect(fresh.found, 0);
    expect(fresh.open, isFalse);

    // One formula that makes each element, and no other.
    final snap = await AlchemicalEncyclopediaService.loadSnapshot(db: db);
    final elements = {
      for (final r in snap.elementRecipes)
        for (final o in r.outcomes) o.result,
    }.toList()..sort();
    final keys = [
      for (final el in elements)
        snap.elementMadeFrom(el).first.outcomePathKey(el),
    ];
    expect(keys.length, 17);
    expect(keys.length, lessThan(snap.elementRecipes.length));

    Future<void> found(List<String> k) =>
        db.settingsDao.setSetting('enc.element.outcomes.v2', jsonEncode(k));

    await found(keys.sublist(1));
    final short = await AlchemyUnlock.load(db: db);
    expect(short.found, 16);
    expect(short.open, isFalse);

    await found(keys);
    final all = await AlchemyUnlock.load(db: db);
    expect(all.found, 17);
    expect(all.open, isTrue);
  });
}
