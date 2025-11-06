// lib/services/inventory_service.dart
import 'package:alchemons/models/inventory.dart';
import 'package:flutter/foundation.dart';
import 'package:alchemons/database/alchemons_db.dart';

class InventoryService extends ChangeNotifier {
  final AlchemonsDatabase _db;
  late final Map<String, InventoryItemDef> registry;

  InventoryService(this._db) {
    registry = buildInventoryRegistry(_db);
  }

  Stream<List<InventoryItem>> watchAll() =>
      _db.inventoryDao.watchItemInventory();

  Future<int> qty(String key) => _db.inventoryDao.getItemQty(key);
  Future<void> add(String key, int delta) =>
      _db.inventoryDao.addItemQty(key, delta);

  Future<bool> use(String key) async {
    final def = registry[key];
    if (def?.onUse == null) return false;
    final ok = await _db.inventoryDao.consumeItem(key);
    if (!ok) return false;
    final applied = await def!.onUse!(_db);
    if (!applied) {
      // rollback if effect failed unexpectedly
      await _db.inventoryDao.addItemQty(key, 1);
      return false;
    }
    notifyListeners();
    return true;
  }
}
