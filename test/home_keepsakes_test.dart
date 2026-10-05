import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/models/home_biome.dart';
import 'package:alchemons/models/home_keepsakes.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// What keepsakes the player owns: read from the deeds themselves, never
// stored — and everything, with the developer tools on.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('owned is read from the maxims found, the arenas won, the bred', () {
    final stars = PlanetStarState.fresh()
        .withDiscoveredCloud('Fire', 'egg:fire_epitaph')
        .withDiscoveredCloud('Dark', 'egg:dark_ouroboros')
        // A cache is not a maxim.
        .withDiscoveredCloud('Water', 'cache:water_vault');
    final contests = CosmicContestProgress.fresh()
        .withCompleted(CosmicContestTrait.speed, 5)
        .withCompleted(CosmicContestTrait.beauty, 4);
    final ledger = KeepsakeLedger.from(
      starsRaw: stars.serialise(),
      contestsRaw: contests.serialise(),
      bred: const {'LET01': 100, 'PIP02': 99},
      speciesName: (id) => id,
    );
    expect(ledger.owned.map((k) => k.id), [
      'ember_torch',
      'twin_portals',
      'victory_arch',
      'effigy:LET01',
    ]);
    expect(ledger.byId('twin_portals')!.copies, 2);
  });

  test('every maxim keepsake has its own egg id', () {
    final eggs = [
      for (final k in Keepsake.all)
        if (k.eggId != null) k.eggId,
    ];
    expect(eggs.length, 17);
    expect(eggs.toSet().length, 17);
  });

  test('with the developer tools on, everything is open', () async {
    SharedPreferences.setMockInitialValues({
      'debug.developer_tools_enabled': true,
    });
    final db = AlchemonsDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.creatureDao.insertInstance(
      instanceId: 'a',
      baseId: 'HOR01',
      level: 1,
    );
    final ledger = await KeepsakeLedger.load(db, (id) => id);
    for (final k in Keepsake.all) {
      expect(ledger.owns(k.id), isTrue, reason: k.id);
    }
    expect(ledger.owns('effigy:HOR01'), isTrue);
    expect(await HomeRealm.arcaneOpen(db.settingsDao), isTrue);
  });
}
