import 'dart:math';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/services/inventory_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AlchemonsDatabase db;
  late InventoryService service;
  final key = BossLootKeys.lootBoxKeyForElement('ice');
  setUp(() {
    db = AlchemonsDatabase(NativeDatabase.memory());
    service = InventoryService(db);
  });
  tearDown(() async {
    service.dispose();
    await db.close();
  });
  test(
    'opens one ice cache and grants exactly the displayed rewards',
    () async {
      await db.inventoryDao.addItemQty(key, 2);
      final before = <String, int>{};
      for (final drop in LootBoxConfig.contentsForBox(key)) {
        before[drop.itemKey] = await db.inventoryDao.getItemQty(drop.itemKey);
      }
      expect(service.registry[key]!.canUse, isTrue);
      final rewards = await service.openLootBox(key, rng: Random(12));
      expect(rewards, isNotEmpty);
      expect(await service.qty(key), 1);
      for (final reward in rewards) {
        expect(
          await service.qty(reward.key),
          before[reward.key]! + reward.value,
        );
      }
    },
  );
  test('empty or invalid caches do not grant rewards', () async {
    expect(await service.openLootBox(key), isEmpty);
    expect(await service.openLootBox('lootbox.boss.invalid'), isEmpty);
    expect(await service.openLootBox(InvKeys.wildFusion), isEmpty);
  });
}
