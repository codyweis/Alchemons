// lib/providers/boss_progress_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BossProgressNotifier extends ChangeNotifier {
  static const String _prefKey = 'boss_progress';

  // Maps boss ID to defeat count (can fight multiple times)
  final Map<String, int> _defeatedBosses = {};

  // Current active boss order (1-17)
  int _currentBossOrder = 1;

  bool _isLoaded = false;

  BossProgressNotifier() {
    _loadProgress();
  }

  bool get isLoaded => _isLoaded;
  int get currentBossOrder => _currentBossOrder;
  Map<String, int> get defeatedBosses => Map.unmodifiable(_defeatedBosses);

  /// Get the next undefeated boss order
  int get nextUndefeatedBoss {
    for (int i = 1; i <= 17; i++) {
      if (!isBossDefeated('boss_${i.toString().padLeft(3, '0')}')) {
        return i;
      }
    }
    return 17; // All defeated, stay on final boss
  }

  /// Check if a boss has been defeated at least once
  bool isBossDefeated(String bossId) {
    return _defeatedBosses.containsKey(bossId) && _defeatedBosses[bossId]! > 0;
  }

  /// Get defeat count for a specific boss
  int getDefeatCount(String bossId) {
    return _defeatedBosses[bossId] ?? 0;
  }

  /// Get total bosses defeated (at least once)
  int get totalBossesDefeated {
    return _defeatedBosses.values.where((count) => count > 0).length;
  }

  /// Mark a boss as defeated
  Future<void> defeatBoss(String bossId, int bossOrder) async {
    _defeatedBosses[bossId] = (_defeatedBosses[bossId] ?? 0) + 1;

    // Auto-advance to next boss if this was the current one
    if (bossOrder == _currentBossOrder && bossOrder < 17) {
      _currentBossOrder = bossOrder + 1;
    }

    await _saveProgress();
    notifyListeners();
  }

  /// Manually set current boss
  Future<void> setCurrentBoss(int order) async {
    if (order >= 1 && order <= 17) {
      _currentBossOrder = order;
      await _saveProgress();
      notifyListeners();
    }
  }

  /// Reset all progress (for testing or new game)
  Future<void> resetProgress() async {
    _defeatedBosses.clear();
    _currentBossOrder = 1;
    await _saveProgress();
    notifyListeners();
  }

  // Persistence
  Future<void> _loadProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_prefKey);

      if (json != null && json.isNotEmpty) {
        final data = Map<String, dynamic>.from(Uri.splitQueryString(json));

        _currentBossOrder = int.tryParse(data['current'] ?? '1') ?? 1;

        // Parse defeated bosses
        for (int i = 1; i <= 17; i++) {
          final bossId = 'boss_${i.toString().padLeft(3, '0')}';
          final count = int.tryParse(data[bossId] ?? '0') ?? 0;
          if (count > 0) {
            _defeatedBosses[bossId] = count;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading boss progress: $e');
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final data = <String, String>{'current': _currentBossOrder.toString()};

      for (final entry in _defeatedBosses.entries) {
        data[entry.key] = entry.value.toString();
      }

      // Simple query string format
      final json = data.entries.map((e) => '${e.key}=${e.value}').join('&');
      await prefs.setString(_prefKey, json);
    } catch (e) {
      debugPrint('Error saving boss progress: $e');
    }
  }
}
