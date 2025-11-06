// lib/database/models/stored_theme_mode.dart
enum StoredThemeMode {
  light,
  dark,
  system;

  static StoredThemeMode fromString(String? raw) {
    switch (raw) {
      case 'light':
        return StoredThemeMode.light;
      case 'dark':
        return StoredThemeMode.dark;
      case 'system':
      default:
        return StoredThemeMode.system;
    }
  }

  String get asString {
    switch (this) {
      case StoredThemeMode.light:
        return 'light';
      case StoredThemeMode.dark:
        return 'dark';
      case StoredThemeMode.system:
        return 'system';
    }
  }
}
