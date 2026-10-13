import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/services/timed_boost_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The space contests are retired and their stat effects come with the
// Trials' cups now; a save that mastered a contest keeps its effect, even
// one that never went back to space (which used to unlock it on a visit).
void main() {
  test('a contest mastered before keeps its effect, given once', () async {
    SharedPreferences.setMockInitialValues({
      'cosmic_trait_contests_v1': '{"speed":5,"beauty":3}',
    });
    final db = AlchemonsDatabase(NativeDatabase.memory());
    ShopService open() => ShopService(
      db,
      ConstellationEffectsService(db),
      FactionService(db),
      TimedBoostService(db.settingsDao),
    );
    final shop = open();
    await shop.reloadFromStorage();
    expect(
      await db.settingsDao.getSetting('shop_unlock.effect.speed_flux'),
      '1',
    );
    expect(
      await db.settingsDao.getSetting('shop_unlock.effect.beauty_radiance'),
      isNull,
    );
    expect(await db.inventoryDao.getItemQty(InvKeys.alchemySpeedFlux), 1);
    // Opening the shop again gives nothing more.
    final again = open();
    await again.reloadFromStorage();
    expect(await db.inventoryDao.getItemQty(InvKeys.alchemySpeedFlux), 1);
    shop.dispose();
    again.dispose();
    await db.close();
  });
}
