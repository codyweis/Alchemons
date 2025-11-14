import 'dart:async';
import 'package:alchemons/database/models/stored_theme_mode.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/alchemons_db.dart';

// --- ADDED: Font map ---
final Map<String, TextTheme Function(TextTheme)> appFontMap = {
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
  ThemeMode get themeMode => _themeMode;

  // --- ADDED: Font state ---
  String _fontName = 'ABeeZee'; // Default
  String get fontName => _fontName;

  TextTheme Function(TextTheme) get currentTextThemeFn {
    return appFontMap[_fontName] ?? GoogleFonts.aboretoTextTheme;
  }
  // --- END ADDED ---

  StreamSubscription<StoredThemeMode>? _themeSub; // --- MODIFIED: Renamed ---
  StreamSubscription<String>? _fontSub; // --- ADDED ---

  ThemeNotifier(this._db) {
    // initial load
    _init();
  }

  Future<void> _init() async {
    // Get current theme from DB
    final stored = await _db.settingsDao.getStoredThemeMode();
    _themeMode = _toFlutter(stored);

    // --- ADDED: Get current font from DB ---
    _fontName = await _db.settingsDao.getFontName();
    // --- END ADDED ---

    notifyListeners();

    // Listen for future changes
    _themeSub = _db.settingsDao.watchStoredThemeMode().listen((storedMode) {
      // --- MODIFIED: Renamed _sub ---
      final nextMode = _toFlutter(storedMode);
      if (nextMode != _themeMode) {
        _themeMode = nextMode;
        notifyListeners();
      }
    });

    // --- ADDED: Listen for font changes ---
    _fontSub = _db.settingsDao.watchFontName().listen((font) {
      if (font != _fontName) {
        _fontName = font;
        notifyListeners();
      }
    });
    // --- END ADDED ---
  }

  @override
  void dispose() {
    _themeSub?.cancel(); // --- MODIFIED: Renamed _sub ---
    _fontSub?.cancel(); // --- ADDED ---
    super.dispose();
  }

  // Public API to change theme
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    await _db.settingsDao.setStoredThemeMode(_fromFlutter(mode));
  }

  // --- ADDED: Public API to change font ---
  Future<void> setFont(String newFontName) async {
    if (appFontMap.containsKey(newFontName)) {
      _fontName = newFontName;
      notifyListeners();
      // This assumes you added setFontName to your settingsDao
      await _db.settingsDao.setFontName(newFontName);
    }
  }
  // --- END ADDED ---

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
        return StoredThemeMode
            .system; // --- MODIFIED: Fixed bug (was .dark) ---
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
