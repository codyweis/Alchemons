import 'dart:async';
import 'package:alchemons/database/models/stored_theme_mode.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/alchemons_db.dart';

const String defaultAppFontName = 'IM Fell English';

/// The game is dark only. Its art makes its own light — grains, glass, glows —
/// and on paper every piece needed a second, hand-authored ink version; most
/// of it never got one, so light mode was the weaker game, and the one a
/// light-mode phone opened into by default.
///
/// The light palettes are left in place behind this switch. Whatever mode a
/// save has stored is kept, and is ignored while this is false.
const bool kLightModeEnabled = false;

final Map<String, TextTheme Function(TextTheme)> appFontMap = {
  defaultAppFontName: GoogleFonts.imFellEnglishTextTheme,
  'ABeeZee': GoogleFonts.aBeeZeeTextTheme,
  'Lato': GoogleFonts.latoTextTheme,
  'Roboto': GoogleFonts.robotoTextTheme,
  'Montserrat': GoogleFonts.montserratTextTheme,
  'Crimson Text': GoogleFonts.crimsonTextTextTheme,
};

class ThemeNotifier extends ChangeNotifier {
  final AlchemonsDatabase _db;

  // Theme state
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => kLightModeEnabled ? _themeMode : ThemeMode.dark;

  String _fontName = defaultAppFontName;
  String get fontName => _fontName;

  TextTheme Function(TextTheme) get currentTextThemeFn {
    return appFontMap[_fontName] ?? GoogleFonts.imFellEnglishTextTheme;
  }

  StreamSubscription<StoredThemeMode>? _themeSub;
  StreamSubscription<String>? _fontSub;

  ThemeNotifier(this._db) {
    // initial load
    _init();
  }

  Future<void> _init() async {
    // Get current theme from DB
    final stored = await _db.settingsDao.getStoredThemeMode();
    _themeMode = _toFlutter(stored);

    final storedFont = await _db.settingsDao.getFontName();
    _fontName = _normalizeFontName(storedFont);
    if (_fontName != storedFont) {
      unawaited(_db.settingsDao.setFontName(_fontName));
    }

    notifyListeners();

    // Listen for future changes
    _themeSub = _db.settingsDao.watchStoredThemeMode().listen((storedMode) {
      final nextMode = _toFlutter(storedMode);
      if (nextMode != _themeMode) {
        _themeMode = nextMode;
        notifyListeners();
      }
    });

    _fontSub = _db.settingsDao.watchFontName().listen((font) {
      final normalizedFont = _normalizeFontName(font);
      if (normalizedFont != font) {
        unawaited(_db.settingsDao.setFontName(normalizedFont));
      }
      if (normalizedFont != _fontName) {
        _fontName = normalizedFont;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _themeSub?.cancel();
    _fontSub?.cancel();
    super.dispose();
  }

  // Public API to change theme
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    await _db.settingsDao.setStoredThemeMode(_fromFlutter(mode));
  }

  Future<void> setFont(String newFontName) async {
    if (appFontMap.containsKey(newFontName)) {
      _fontName = newFontName;
      notifyListeners();
      await _db.settingsDao.setFontName(newFontName);
    }
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
        return StoredThemeMode
            .system; // --- MODIFIED: Fixed bug (was .dark) ---
    }
  }

  bool get isDarkEffective {
    // "effective" means what the UI should look like right now,
    // not just what ThemeMode enum says.
    switch (themeMode) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        // caller (like a widget) can override this with MediaQuery if needed.
        return false;
    }
  }

  String _normalizeFontName(String? fontName) {
    if (fontName != null && appFontMap.containsKey(fontName)) {
      return fontName;
    }
    return defaultAppFontName;
  }
}
