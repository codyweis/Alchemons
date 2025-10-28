import 'dart:async';
import 'package:flutter/material.dart';
import '../database/alchemons_db.dart';

class ThemeNotifier extends ChangeNotifier {
  final AlchemonsDatabase _db;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  StreamSubscription<StoredThemeMode>? _sub;

  ThemeNotifier(this._db) {
    // initial load
    _init();
  }

  Future<void> _init() async {
    // Get current from DB
    final stored = await _db.getStoredThemeMode();
    _themeMode = _toFlutter(stored);
    notifyListeners();

    // Listen for future changes (in case something else flips it)
    _sub = _db.watchStoredThemeMode().listen((storedMode) {
      final nextMode = _toFlutter(storedMode);
      if (nextMode != _themeMode) {
        _themeMode = nextMode;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // Public API to change theme
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    await _db.setStoredThemeMode(_fromFlutter(mode));
  }

  // convenience toggles
  Future<void> toggleLightDark() async {
    if (_themeMode == ThemeMode.dark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }

  // -- helpers --
  ThemeMode _toFlutter(StoredThemeMode s) {
    switch (s) {
      case StoredThemeMode.light:
        return ThemeMode.light;
      case StoredThemeMode.dark:
        return ThemeMode.dark;
      case StoredThemeMode.system:
        return ThemeMode.system;
    }
  }

  StoredThemeMode _fromFlutter(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return StoredThemeMode.light;
      case ThemeMode.dark:
        return StoredThemeMode.dark;
      case ThemeMode.system:
      default:
        return StoredThemeMode.system;
    }
  }

  bool get isDarkEffective {
    // "effective" means what the UI should look like right now,
    // not just what ThemeMode enum says.
    switch (_themeMode) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        // caller (like a widget) can override this with MediaQuery if needed.
        return false;
    }
  }
}
