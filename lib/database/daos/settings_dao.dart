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

  // --- ADD THESE CONSTANTS ---
  static const String _fontKey = 'app_font';
  static const String _defaultFont = 'Aboreto'; // Your default font
  Future<String> getFontName() async {
    final font = await getSetting(_fontKey);
    return font ?? _defaultFont;
  }

  Future<void> setFontName(String fontName) async {
    await setSetting(_fontKey, fontName);
  }

  /// Reactive stream of font name so UI can rebuild on change
  Stream<String> watchFontName() {
    return watchSetting(_fontKey).map((font) {
      return font ?? _defaultFont;
    });
  }

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

  /// Reactive stream of a single setting value (or null if unset)
  Stream<String?> watchSetting(String key) {
    final q = select(settings)..where((t) => t.key.equals(key));
    return q.watch().map((rows) => rows.isEmpty ? null : rows.first.value);
  }

  /// Convenience helpers for the nav lock used by BottomNav / extraction flow
  Future<bool> getNavLocked() async {
    final v = await getSetting('nav_locked_until_extraction_ack');
    return v == '1' || (v != null && v.toLowerCase() == 'true');
  }

  Future<void> setNavLocked(bool locked) async {
    await setSetting('nav_locked_until_extraction_ack', locked ? '1' : '0');
  }

  Future<void> deleteSetting(String key) async {
    await (delete(settings)..where((t) => t.key.equals(key))).go();
  }

  Future<bool> hasCompletedFieldTutorial() async {
    final v = await getSetting('tutorial_field_completed');
    return v == '1';
  }

  Future<void> setFieldTutorialCompleted() async {
    await setSetting('tutorial_field_completed', '1');
  }

  Future<bool> hasCompletedExtractionTutorial() async {
    final v = await getSetting('first_extraction_done');
    return v == '1';
  }

  Stream<bool> watchFieldTutorialState() {
    return watchSetting('tutorial_field_completed').map((v) => v == '1');
  }

  Stream<bool> watchExtractionTutorialState() {
    return watchSetting('first_extraction_done').map((v) => v == '1');
  }

  /// If true, app should force-open the FactionPicker until user selects one.
  Future<bool> getMustPickFaction() async {
    final v = await getSetting('require_faction_picker');
    return v == '1' || (v != null && v.toLowerCase() == 'true');
  }

  Future<void> setMustPickFaction(bool value) async {
    await setSetting('require_faction_picker', value ? '1' : '0');
  }

  /// Reactive stream to observe the lock (useful at app shell level).
  Stream<bool> watchMustPickFaction() {
    return watchSetting(
      'require_faction_picker',
    ).map((v) => v == '1' || (v != null && v.toLowerCase() == 'true'));
  }
}
