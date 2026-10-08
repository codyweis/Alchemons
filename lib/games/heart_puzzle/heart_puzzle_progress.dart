// lib/games/heart_puzzle/heart_puzzle_progress.dart
//
// THE ALTARS' progress: the best stars won on each level. Kept on the
// device only for now (the mode is reached from the debug tools); it joins
// the cloud save when the mode finds its home in the story.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AltarProgress {
  AltarProgress._(this._stars, this._mastered);

  static const String _key = 'altars.stars.v1';

  /// Every star won, and its 500 gold collected (paid once).
  static const String _masteryKey = 'altars.mastery.v1';
  bool _mastered;
  bool get masteryClaimed => _mastered;

  /// Level number (from 1) → best stars (1–3). Missing: never solved.
  final Map<int, int> _stars;

  static Future<AltarProgress> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      final mastered = prefs.getBool(_masteryKey) ?? false;
      if (raw == null) return AltarProgress._({}, mastered);
      final m = (jsonDecode(raw) as Map<String, dynamic>).map(
        (k, v) => MapEntry(int.parse(k), (v as num).toInt()),
      );
      return AltarProgress._(m, mastered);
    } catch (_) {
      return AltarProgress._({}, false);
    }
  }

  int starsOf(int level) => _stars[level] ?? 0;

  /// Every star in every level ([levels] of them, three each).
  bool allStars(int levels) =>
      List.generate(levels, (i) => starsOf(i + 1)).every((s) => s >= 3);

  /// Mark the mastery reward collected. True the first time only.
  Future<bool> claimMastery() async {
    if (_mastered) return false;
    _mastered = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_masteryKey, true);
    } catch (_) {}
    return true;
  }
  int get totalStars => _stars.values.fold(0, (a, b) => a + b);

  /// A level is open once the one before it is solved.
  bool isOpen(int level) => level <= 1 || starsOf(level - 1) > 0;

  /// Record [stars] for [level] (keeps the best). True when it improved.
  Future<bool> record(int level, int stars) async {
    if (stars <= starsOf(level)) return false;
    _stars[level] = stars;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(_stars.map((k, v) => MapEntry('$k', v))),
      );
    } catch (_) {}
    return true;
  }
}
