import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Firebase Auth UIDs whose release builds may use the developer tools.
/// Debug and profile builds always may; a release build (the App Store, Play
/// and web builds every player runs) only when signed in to one of these.
const Set<String> kDeveloperAccountUids = {};

/// Developer tools toggle — persisted, so it works in release builds on a real
/// device (unlike `kDebugMode`, which is compile-time and off in a release
/// install). Debug affordances gate on `DebugSettingsService.enabledNotifier`
/// alone, which is the switch AND [toolsAllowed]: in a release build the
/// switch answers only to a developer's account, so a player who finds it
/// (or turned it on before 0.9.2) gets nothing from it — no free shop, no
/// unlocked masteries, no forced mutations.
///
/// Mirrors [CinematicQualityService]'s shape: a static cache plus a notifier so
/// widgets can rebuild the moment it flips, without threading a service down.
class DebugSettingsService {
  static const String _key = 'debug.developer_tools_enabled';
  static bool _stored = false;
  static bool _hydrated = false;

  /// The switch as it takes effect: on, and allowed on this install.
  static final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(false);

  /// Whether this install may use the developer tools at all: every debug or
  /// profile build, and a release build signed in to a developer's account.
  static final ValueNotifier<bool> allowedNotifier = ValueNotifier<bool>(
    !kReleaseMode,
  );
  static bool get toolsAllowed => allowedNotifier.value;

  /// Whether this is a release build; tests stand in for one with it.
  @visibleForTesting
  static bool releaseBuild = kReleaseMode;

  /// Called by [AccountService] whenever the signed-in account changes.
  static void setAccount(String? uid) {
    allowedNotifier.value =
        !releaseBuild || (uid != null && kDeveloperAccountUids.contains(uid));
    _publish();
  }

  static void _publish() {
    final on = _stored && allowedNotifier.value;
    if (enabledNotifier.value != on) enabledNotifier.value = on;
  }

  Future<bool> isEnabled() async {
    if (!_hydrated) {
      final prefs = await SharedPreferences.getInstance();
      // A setEnabled that landed during the read wins.
      if (!_hydrated) {
        _stored = prefs.getBool(_key) ?? false;
        _hydrated = true;
      }
      _publish();
    }
    return enabledNotifier.value;
  }

  Future<void> setEnabled(bool enabled) async {
    _stored = enabled;
    _hydrated = true;
    _publish();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }

  /// True when developer tools should show. Safe to read synchronously during
  /// `build` once [isEnabled] has hydrated it (call that from `initState`).
  ///
  /// This used to be `|| kDebugMode`, which meant the switch did nothing in a
  /// debug build — and debug is the only build most testing happens in, so
  /// developer affordances leaked into normal play with the toggle off. The
  /// switch is now the only thing that decides.
  static bool get toolsVisible => enabledNotifier.value;

  // ── free shop ──────────────────────────────────────────────────────────

  static const String _freeShopKey = 'debug.free_shop';
  static bool _freeShopHydrated = false;

  /// The FREE SHOP switch under the developer tools, persisted like them.
  static final ValueNotifier<bool> freeShopNotifier = ValueNotifier<bool>(
    false,
  );

  Future<bool> isFreeShop() async {
    if (_freeShopHydrated) return freeShopNotifier.value;
    final prefs = await SharedPreferences.getInstance();
    _freeShopHydrated = true;
    freeShopNotifier.value = prefs.getBool(_freeShopKey) ?? false;
    return freeShopNotifier.value;
  }

  Future<void> setFreeShop(bool free) async {
    _freeShopHydrated = true;
    freeShopNotifier.value = free;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_freeShopKey, free);
  }

  /// Whether every shop purchase costs nothing: the switch is on and so are
  /// the developer tools, so turning the tools off restores real prices
  /// without having to remember this one too.
  static bool get freeShop => toolsVisible && freeShopNotifier.value;

  /// [cost], or the same currencies at zero while [freeShop] is on — for
  /// the shop's purchases that do not go through ShopService.
  static Map<String, int> priced(Map<String, int> cost) =>
      freeShop ? {for (final k in cost.keys) k: 0} : cost;

  // ── forced wild mutation ───────────────────────────────────────────────

  static const String _forcedMutationKey = 'debug.force_wild_mutation';
  static bool _forcedMutationHydrated = false;

  /// The mutation id ([AlchemonMutation.id]) the next successful
  /// wilderness fusion is forced to, or null. One-shot: spent by that fusion,
  /// so a debug choice never quietly mutates everything after it.
  static final ValueNotifier<String?> forcedWildMutationNotifier =
      ValueNotifier<String?>(null);

  Future<String?> forcedWildMutation() async {
    if (_forcedMutationHydrated) return forcedWildMutationNotifier.value;
    final prefs = await SharedPreferences.getInstance();
    _forcedMutationHydrated = true;
    forcedWildMutationNotifier.value = prefs.getString(_forcedMutationKey);
    return forcedWildMutationNotifier.value;
  }

  Future<void> setForcedWildMutation(String? id) async {
    _forcedMutationHydrated = true;
    forcedWildMutationNotifier.value = id;
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_forcedMutationKey);
    } else {
      await prefs.setString(_forcedMutationKey, id);
    }
  }

  /// The forced mutation for a fusion about to happen — only while the
  /// developer tools are on. Clear it with [setForcedWildMutation] once the
  /// fusion has landed.
  Future<String?> pendingForcedWildMutation() async {
    if (!await isEnabled()) return null;
    return forcedWildMutation();
  }
}
