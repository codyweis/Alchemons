// lib/database/daos/settings_dao.dart
import 'package:drift/drift.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/database/schema_tables.dart';
import 'package:alchemons/database/models/stored_theme_mode.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<AlchemonsDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  // =================== SETTINGS ===================

  Future<String?> getSetting(String key) async {
    final row = await (select(
      settings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) async {
    await into(settings).insertOnConflictUpdate(
      SettingsCompanion(key: Value(key), value: Value(value)),
    );
  }

  // =================== BLOB PARTY (OVERLAY) ===================

  Future<int> getBlobSlotsUnlocked() async {
    final v = await getSetting('blob_slots_unlocked');
    if (v == null) {
      await setSetting('blob_slots_unlocked', '1');
      return 1;
    }
    final n = int.tryParse(v) ?? 1;
    return n.clamp(1, 3);
  }

  Future<void> setBlobSlotsUnlocked(int n) async {
    final clamped = n.clamp(1, 3);
    await setSetting('blob_slots_unlocked', clamped.toString());
  }

  Future<List<String?>> getBlobInstanceSlots() async {
    final keys = ['blob_slot_0', 'blob_slot_1', 'blob_slot_2'];
    final vals = <String?>[];
    for (final k in keys) {
      final v = await getSetting(k);
      vals.add(v == '' ? null : v);
    }
    return vals;
  }

  Future<String?> getFeaturedInstanceId() async {
    return await getSetting('featured_instance_id');
  }

  Future<void> setFeaturedInstanceId(String? instanceId) async {
    await setSetting('featured_instance_id', instanceId ?? '');
  }

  Future<void> setBlobSlotInstance(int index, String? instanceId) async {
    if (index < 0 || index > 2) return;
    final key = 'blob_slot_$index';
    await setSetting(key, instanceId ?? '');
  }

  // =================== THEME SETTINGS ===================

  Future<StoredThemeMode> getStoredThemeMode() async {
    final raw = await getSetting('theme_mode');
    return StoredThemeMode.fromString(raw);
  }

  Future<void> setStoredThemeMode(StoredThemeMode mode) async {
    await setSetting('theme_mode', mode.asString);
  }

  /// Reactive stream of theme mode so UI can rebuild on change
  Stream<StoredThemeMode> watchStoredThemeMode() {
    final q = select(settings)..where((t) => t.key.equals('theme_mode'));
    return q.watch().map((rows) {
      if (rows.isEmpty) return StoredThemeMode.system;
      return StoredThemeMode.fromString(rows.first.value);
    });
  }

  // =================== SHOP PREFS ===================

  Future<bool> getShopShowPurchased() async {
    final v = await getSetting('shop_show_purchased');
    if (v == null) {
      await setSetting('shop_show_purchased', '0');
      return false;
    }
    return v == '1' || v.toLowerCase() == 'true';
  }

  Future<void> setShopShowPurchased(bool value) async {
    await setSetting('shop_show_purchased', value ? '1' : '0');
  }
}
