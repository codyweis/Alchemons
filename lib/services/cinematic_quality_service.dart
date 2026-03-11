import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CinematicQuality { high, balanced }

class CinematicQualityService {
  static const String _key = 'visual.cinematic_quality';
  static const CinematicQuality _defaultQuality = CinematicQuality.high;
  static CinematicQuality? _cached;
  static bool _hydrated = false;
  static final ValueNotifier<CinematicQuality> qualityNotifier =
      ValueNotifier<CinematicQuality>(_defaultQuality);

  Future<CinematicQuality> getQuality() async {
    if (_cached != null) return _cached!;
    if (_hydrated) return qualityNotifier.value;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    CinematicQuality? parsed;
    for (final q in CinematicQuality.values) {
      if (q.name == raw) {
        parsed = q;
        break;
      }
    }
    _cached = parsed ?? _defaultQuality;
    _hydrated = true;
    if (qualityNotifier.value != _cached) {
      qualityNotifier.value = _cached!;
    }
    return _cached!;
  }

  Future<void> setQuality(CinematicQuality quality) async {
    _cached = quality;
    _hydrated = true;
    if (qualityNotifier.value != quality) {
      qualityNotifier.value = quality;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, quality.name);
  }
}
