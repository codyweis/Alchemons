import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Developer tools toggle — persisted, so it works in release builds on a real
/// device (unlike `kDebugMode`, which is compile-time and off in a release
/// install). Debug affordances gate on `DebugSettingsService.enabledNotifier`
/// OR `kDebugMode`, so a debug build keeps its tools without the switch.
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

  /// True when developer tools should show: either the switch is on, or this
  /// is a debug build. Safe to read synchronously during `build` once
  /// [isEnabled] has hydrated it (call that from `initState`).
  static bool get toolsVisible => enabledNotifier.value || kDebugMode;
}
