import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferencesService {
  static const String cultivationKey = 'notif.cultivations.enabled';
  static const String wildernessKey = 'notif.wilderness.enabled';
  static const String extractionKey = 'notif.extractions.enabled';

  static const bool _defaultEnabled = true;

  Future<bool> isCultivationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(cultivationKey) ?? _defaultEnabled;
  }

  Future<bool> isWildernessEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(wildernessKey) ?? _defaultEnabled;
  }

  Future<bool> isExtractionsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(extractionKey) ?? _defaultEnabled;
  }

  Future<void> setCultivationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(cultivationKey, enabled);
  }

  Future<void> setWildernessEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(wildernessKey, enabled);
  }

  Future<void> setExtractionsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(extractionKey, enabled);
  }
}
