import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Developer tools toggle — persisted, so it works in release builds on a real
/// device (unlike `kDebugMode`, which is compile-time and off in a release
/// install). Debug affordances gate on `DebugSettingsService.enabledNotifier`
/// alone: the switch is the whole answer, in every build type.
///
/// Mirrors [CinematicQualityService]'s shape: a static cache plus a notifier so
/// widgets can rebuild the moment it flips, without threading a service down.
class DebugSettingsService {
  static const String _key = 'debug.developer_tools_enabled';
  static bool? _cached;
  static bool _hydrated = false;
  static final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(false);

  Future<bool> isEnabled() async {
    if (_cached != null) return _cached!;
    if (_hydrated) return enabledNotifier.value;

    final prefs = await SharedPreferences.getInstance();
    _cached = prefs.getBool(_key) ?? false;
    _hydrated = true;
    if (enabledNotifier.value != _cached) {
      enabledNotifier.value = _cached!;
    }
    return _cached!;
  }

  Future<void> setEnabled(bool enabled) async {
    _cached = enabled;
    _hydrated = true;
    if (enabledNotifier.value != enabled) {
      enabledNotifier.value = enabled;
    }
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
}
