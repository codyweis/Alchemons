// lib/database/daos/currency_dao.dart
import 'package:drift/drift.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/database/schema_tables.dart';
import 'package:alchemons/constants/element_resources.dart';

part 'currency_dao.g.dart';

@DriftAccessor(tables: [Settings])
class CurrencyDao extends DatabaseAccessor<AlchemonsDatabase>
    with _$CurrencyDaoMixin {
  CurrencyDao(super.db);

  // Helper getters to access the SettingsDao
  Future<String?> _getSetting(String key) => db.settingsDao.getSetting(key);
  Future<void> _setSetting(String key, String value) =>
      db.settingsDao.setSetting(key, value);

  // =================== WALLET (Soft) ===================

  Future<int> getSoftBalance() async =>
      int.tryParse(await _getSetting('wallet_soft') ?? '0') ?? 0;

  Future<void> addSoft(int amount) async {
    final cur = await getSoftBalance();
    await _setSetting('wallet_soft', (cur + amount).toString());
  }

  Future<bool> spendSoft(int amount) async {
    final cur = await getSoftBalance();
    if (cur < amount) return false;
    await _setSetting('wallet_soft', (cur - amount).toString());
    return true;
  }

  // =================== RESOURCES ===================

  Future<int> getResource(String key) async =>
      int.tryParse(await _getSetting(key) ?? '0') ?? 0;

  Future<void> addResource(String key, int delta) async {
    final cur = await getResource(key);
    await _setSetting(key, (cur + delta).toString());
  }

  Future<bool> spendResources(Map<String, int> costMap) async {
    // Verify all resources available
    for (final e in costMap.entries) {
      final available = switch (e.key) {
        'gold' => await getGoldBalance(),
        'silver' => await getSilverBalance(),
        'soft' => await getSoftBalance(),
        _ => await getResource(e.key),
      };
      if (available < e.value) return false;
    }
    // Deduct
    for (final e in costMap.entries) {
      switch (e.key) {
        case 'gold':
          await addGold(-e.value);
          break;
        case 'silver':
          await addSilver(-e.value);
          break;
        case 'soft':
          await addSoft(-e.value);
          break;
        default:
          await addResource(e.key, -e.value);
      }
    }
    return true;
  }

  Stream<Map<String, int>> watchResourceBalances() {
    final q = select(settings)
      ..where((t) => t.key.isIn(ElementResources.settingsKeys));
    return q.watch().map((rows) {
      final m = {for (final k in ElementResources.settingsKeys) k: 0};
      for (final r in rows) {
        m[r.key] = int.tryParse(r.value) ?? 0;
      }
      return m;
    });
  }

  // =================== CURRENCY - GOLD ===================

  Future<int> getGoldBalance() async =>
      int.tryParse(await _getSetting('wallet_gold') ?? '0') ?? 0;

  Future<void> addGold(int amount) async {
    final cur = await getGoldBalance();
    await _setSetting('wallet_gold', (cur + amount).toString());
  }

  Future<bool> spendGold(int amount) async {
    final cur = await getGoldBalance();
    if (cur < amount) return false;
    await _setSetting('wallet_gold', (cur - amount).toString());
    return true;
  }

  // ---- Purchased gold ----------------------------------------------------
  //
  // Gold that arrived from a verified in-app purchase and has not been spent
  // yet. It is tracked apart from the balance so a restored save can be
  // reconciled against the account's server entitlement: a backup handed to
  // somebody else arrives with no matching entitlement of their own, and the
  // purchased portion does not survive the restore.

  static const String purchasedGoldOutstandingKey =
      'wallet_gold_purchased_outstanding';

  Future<int> getPurchasedGoldOutstanding() async =>
      int.tryParse(await _getSetting(purchasedGoldOutstandingKey) ?? '0') ?? 0;

  Future<void> setPurchasedGoldOutstanding(int value) async {
    await _setSetting(
      purchasedGoldOutstandingKey,
      (value < 0 ? 0 : value).toString(),
    );
  }

  /// Credits gold from a purchase the server has already verified.
  ///
  /// Only [MobileStoreService] should call this, and only after `redeemPurchase`
  /// has returned. Gameplay rewards use [addGold].
  Future<void> creditPurchasedGold(int amount) async {
    if (amount <= 0) return;
    await addGold(amount);
    await setPurchasedGoldOutstanding(
      await getPurchasedGoldOutstanding() + amount,
    );
  }

  Future<void> settleVerifiedPurchase({
    required String localKey,
    required int amount,
    required bool includedInReset,
  }) async {
    await db.transaction(() async {
      if (await _getSetting(localKey) == '1') return;
      if (!includedInReset) await creditPurchasedGold(amount);
      await _setSetting(localKey, '1');
    });
  }

  Stream<int> watchGoldBalance() {
    final q = select(settings)..where((t) => t.key.equals('wallet_gold'));
    return q.watch().map((rows) {
      if (rows.isEmpty) return 0;
      return int.tryParse(rows.first.value) ?? 0;
    });
  }

  // =================== CURRENCY - SILVER ===================

  Future<int> getSilverBalance() async =>
      int.tryParse(await _getSetting('wallet_silver') ?? '0') ?? 0;

  Future<void> addSilver(int amount) async {
    final cur = await getSilverBalance();
    await _setSetting('wallet_silver', (cur + amount).toString());
  }

  Future<bool> spendSilver(int amount) async {
    final cur = await getSilverBalance();
    if (cur < amount) return false;
    await _setSetting('wallet_silver', (cur - amount).toString());
    return true;
  }

  Stream<int> watchSilverBalance() {
    final q = select(settings)..where((t) => t.key.equals('wallet_silver'));
    return q.watch().map((rows) {
      if (rows.isEmpty) return 0;
      return int.tryParse(rows.first.value) ?? 0;
    });
  }

  // =================== COMBINED CURRENCY WATCH ===================

  Stream<Map<String, int>> watchAllCurrencies() {
    final q = select(settings)
      ..where(
        (t) => t.key.isIn(['wallet_soft', 'wallet_gold', 'wallet_silver']),
      );
    return q.watch().map((rows) {
      final map = {'soft': 0, 'gold': 0, 'silver': 0};
      for (final r in rows) {
        if (r.key == 'wallet_soft') map['soft'] = int.tryParse(r.value) ?? 0;
        if (r.key == 'wallet_gold') map['gold'] = int.tryParse(r.value) ?? 0;
        if (r.key == 'wallet_silver') {
          map['silver'] = int.tryParse(r.value) ?? 0;
        }
      }
      return map;
    });
  }

  Future<Map<String, int>> getAllCurrencies() async {
    final goldFuture = getGoldBalance();
    final silverFuture = getSilverBalance();
    final softFuture = getSoftBalance();

    final results = await Future.wait([goldFuture, silverFuture, softFuture]);

    final currencies = {
      'gold': results[0],
      'silver': results[1],
      'soft': results[2],
    };

    // 👇 ADD: Get all resources and merge them in
    for (final key in ElementResources.settingsKeys) {
      currencies[key] = await getResource(key);
    }

    return currencies;
  }
}
