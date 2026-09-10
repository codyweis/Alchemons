// Stat Infusion is a door that only exists once you can walk through it.
//
// It is offered in two places — the Enhance entry card and the tray inside
// the screen — so the rule lives in one place or they drift: a door to an
// empty room, or a room behind a door that is not there.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/services/infusion_discovery.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AlchemonsDatabase db;

  setUp(() => db = AlchemonsDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  const noOrb = <String, int>{};
  final oneOrb = {AlchemicalPowerupType.speed.inventoryKey: 1};
  const oneSoul = {InvKeys.potentialSoul: 1};

  test('a fresh save has no infusion', () async {
    expect(await InfusionDiscovery.anyDiscovered(db.settingsDao), isFalse);
    expect(InfusionDiscovery.orbCount(noOrb), 0);
  });

  test('holding an orb opens it, and spending it does not close it', () async {
    await InfusionDiscovery.observe(db.settingsDao, oneOrb);
    expect(await InfusionDiscovery.orbsDiscovered(db.settingsDao), isTrue);
    expect(await InfusionDiscovery.anyDiscovered(db.settingsDao), isTrue);

    // Spent them all.
    await InfusionDiscovery.observe(db.settingsDao, noOrb);
    expect(
      await InfusionDiscovery.anyDiscovered(db.settingsDao),
      isTrue,
      reason: 'discovery is one-way; the feature must not retract',
    );
  });

  test('a soul opens it too, independently of orbs', () async {
    await InfusionDiscovery.observe(db.settingsDao, oneSoul);
    expect(await InfusionDiscovery.soulsDiscovered(db.settingsDao), isTrue);
    expect(await InfusionDiscovery.orbsDiscovered(db.settingsDao), isFalse);
    expect(await InfusionDiscovery.anyDiscovered(db.settingsDao), isTrue);
  });

  test('orbs of every stat count toward the same door', () async {
    for (final type in AlchemicalPowerupType.values) {
      expect(InfusionDiscovery.orbCount({type.inventoryKey: 2}), 2,
          reason: '${type.name} orbs must count');
    }
    expect(
      InfusionDiscovery.orbCount({
        for (final t in AlchemicalPowerupType.values) t.inventoryKey: 1,
      }),
      AlchemicalPowerupType.values.length,
    );
  });

  test('readHoldings sees what the inventory holds', () async {
    await db.inventoryDao.addItemQty(AlchemicalPowerupType.beauty.inventoryKey, 3);
    final held = await InfusionDiscovery.readHoldings(db.inventoryDao);
    expect(InfusionDiscovery.orbCount(held), 3);
    expect(InfusionDiscovery.soulCount(held), 0);
  });
}
