// lib/database/daos/shop_dao.dart
import 'package:drift/drift.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/database/schema_tables.dart';

part 'shop_dao.g.dart';

@DriftAccessor(tables: [ShopPurchases])
class ShopDao extends DatabaseAccessor<AlchemonsDatabase> with _$ShopDaoMixin {
  ShopDao(super.db);

  // =================== SHOP PURCHASES ===================

  Future<List<Map<String, dynamic>>> getShopPurchaseHistory() async {
    final results = await select(shopPurchases).get();
    return results
        .map(
          (row) => {
            'offerId': row.offerId,
            'count': row.purchaseCount,
            'lastPurchaseUtcMs': row.lastPurchaseUtcMs,
          },
        )
        .toList();
  }

  Future<void> recordShopPurchase({
    required String offerId,
    required int timestamp,
  }) async {
    // Get existing record
    final existing = await (select(
      shopPurchases,
    )..where((t) => t.offerId.equals(offerId))).getSingleOrNull();

    if (existing == null) {
      // First purchase
      await into(shopPurchases).insert(
        ShopPurchasesCompanion(
          offerId: Value(offerId),
          purchaseCount: const Value(1),
          lastPurchaseUtcMs: Value(timestamp),
        ),
      );
    } else {
      // Increment count
      await (update(
        shopPurchases,
      )..where((t) => t.offerId.equals(offerId))).write(
        ShopPurchasesCompanion(
          purchaseCount: Value(existing.purchaseCount + 1),
          lastPurchaseUtcMs: Value(timestamp),
        ),
      );
    }
  }

  Future<int> getShopPurchaseCount(String offerId) async {
    final row = await (select(
      shopPurchases,
    )..where((t) => t.offerId.equals(offerId))).getSingleOrNull();
    return row?.purchaseCount ?? 0;
  }

  Future<DateTime?> getShopLastPurchaseTime(String offerId) async {
    final row = await (select(
      shopPurchases,
    )..where((t) => t.offerId.equals(offerId))).getSingleOrNull();

    if (row?.lastPurchaseUtcMs == null) return null;

    return DateTime.fromMillisecondsSinceEpoch(
      row!.lastPurchaseUtcMs!,
      isUtc: true,
    );
  }

  Stream<List<ShopPurchase>> watchShopPurchases() {
    return select(shopPurchases).watch();
  }
}
