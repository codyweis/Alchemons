// lib/database/daos/inventory_dao.dart
import 'package:drift/drift.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/database/schema_tables.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';

part 'inventory_dao.g.dart';

@DriftAccessor(tables: [InventoryItems])
class InventoryDao extends DatabaseAccessor<AlchemonsDatabase>
    with _$InventoryDaoMixin {
  InventoryDao(super.db);

  // =================== INVENTORY ===================
  Future<int> getItemQty(String key) async {
    final row = await (select(
      inventoryItems,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.qty ?? 0;
  }

  Future<void> addItemQty(String key, int delta) async {
    if (delta == 0) return;
    final existing = await (select(
      inventoryItems,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    if (existing == null) {
      await into(inventoryItems).insert(
        InventoryItemsCompanion(
          key: Value(key),
          qty: Value(delta.clamp(0, 1 << 31)),
        ),
        mode: InsertMode.insertOrReplace,
      );
    } else {
      final newQty = (existing.qty + delta).clamp(0, 1 << 31);
      await (update(inventoryItems)..where((t) => t.key.equals(key))).write(
        InventoryItemsCompanion(qty: Value(newQty)),
      );
    }
  }

  // --- VIAL SHORTCUTS ----------------------------------------------------------

  Future<void> addVial(
    String name,
    ElementalGroup group,
    VialRarity rarity, {
    int qty = 1,
  }) async {
    final key = 'vial.${group.name}.${rarity.name}.$name';
    await addItemQty(key, qty);
  }

  Future<int> getVialQty(
    ElementalGroup group,
    VialRarity rarity,
    String name,
  ) async {
    final key = 'vial.${group.name}.${rarity.name}.$name';
    return getItemQty(key);
  }

  Future<bool> consumeVial(
    String name,
    ElementalGroup group,
    VialRarity rarity, {
    int qty = 1,
  }) async {
    final key = 'vial.${group.name}.${rarity.name}.$name';
    return consumeItem(key, qty: qty);
  }

  // Track last-legendary time for pity/hard-cap logic
  Future<DateTime?> getLastLegendaryAward() async {
    final v = await db.settingsDao.getSetting('legendary_last_award_ms');
    if (v == null || v.isEmpty) return null;
    final ms = int.tryParse(v);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  Future<void> setLastLegendaryAward(DateTime utc) async {
    await db.settingsDao.setSetting(
      'legendary_last_award_ms',
      utc.millisecondsSinceEpoch.toString(),
    );
  }

  Future<bool> consumeItem(String key, {int qty = 1}) async {
    final have = await getItemQty(key);
    if (have < qty) return false;
    await addItemQty(key, -qty);
    return true;
  }

  Stream<List<InventoryItem>> watchItemInventory() =>
      (select(inventoryItems)
            ..where((t) => t.qty.isBiggerThanValue(0))
            ..orderBy([(t) => OrderingTerm.asc(t.key)]))
          .watch();

  //removeinvenvtory items
  // Set an exact quantity; deletes the row if qty <= 0
  Future<void> setItemQty(String key, int qty) async {
    if (qty <= 0) {
      await (delete(inventoryItems)..where((t) => t.key.equals(key))).go();
      return;
    }
    // upsert
    final existing = await (select(
      inventoryItems,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    if (existing == null) {
      await into(inventoryItems).insert(
        InventoryItemsCompanion(key: Value(key), qty: Value(qty)),
        mode: InsertMode.insertOrReplace,
      );
    } else {
      await (update(inventoryItems)..where((t) => t.key.equals(key))).write(
        InventoryItemsCompanion(qty: Value(qty)),
      );
    }
  }

  // Hard-delete a single item key
  Future<void> removeItem(String key) async {
    await (delete(inventoryItems)..where((t) => t.key.equals(key))).go();
  }

  // Remove all inventory (careful!)
  Future<void> clearInventory() async {
    await delete(inventoryItems).go();
  }

  // Clean up any lingering zero/negative rows (defensive)
  Future<void> purgeZeroOrNegative() async {
    await (delete(
      inventoryItems,
    )..where((t) => t.qty.isSmallerOrEqualValue(0))).go();
  }

  // Bulk-remove by key prefix (great for families like vials)
  Future<int> removeByPrefix(String prefix) async {
    // SQLite: prefix match via LIKE 'prefix%'
    final affected = await customUpdate(
      'DELETE FROM inventory_items WHERE key LIKE ?',
      variables: [Variable<String>('$prefix%')],
    );
    return affected; // rows deleted
  }

  // Decrement by N; deletes when it hits zero
  Future<void> decrementItem(String key, {int by = 1}) async {
    if (by <= 0) return;
    final row = await (select(
      inventoryItems,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    if (row == null) return;
    final newQty = row.qty - by;
    if (newQty <= 0) {
      await (delete(inventoryItems)..where((t) => t.key.equals(key))).go();
    } else {
      await (update(inventoryItems)..where((t) => t.key.equals(key))).write(
        InventoryItemsCompanion(qty: Value(newQty)),
      );
    }
  }
}
