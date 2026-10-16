// lib/games/cosmic_survival/survival_best_run.dart
//
// The best Survival run, as friends see it: the best wave and score the
// lobby shows ("BEST W23 48.2K"), when the run that reached that wave
// ended, and the species it took in. No stats, no levels, no names.
//
// The lobby's own records (the high-score table and its two settings keys)
// keep only the numbers, so the run itself is noted here as each one ends
// (cosmic_survival_screen.dart _saveHighScore): the furthest, then the
// highest scoring, is kept. FriendService publishes what [load] gives.

import 'dart:convert';
import 'dart:math' as math;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/database/daos/settings_dao.dart';

class SurvivalBestRun {
  const SurvivalBestRun({
    required this.wave,
    required this.score,
    this.at,
    this.team = const [],
  });

  /// Where the run kept is saved.
  static const String settingKey = 'survival.best_run_v1';

  /// The most species a team carries, as kept, published and read.
  static const int maxTeam = 5;

  /// The longest a species id can run, as published and read.
  static const int maxIdLength = 24;

  final int wave;
  final int score;

  /// When the run that reached [wave] ended; null for a best from before
  /// runs were noted.
  final DateTime? at;

  /// The species (baseIds) it took in; empty when not known.
  final List<String> team;

  /// Further, or as far and scoring more.
  bool beats(SurvivalBestRun other) =>
      wave != other.wave ? wave > other.wave : score > other.score;

  /// "W23 · 48.2K".
  String get figures => 'W$wave · ${compact(score)}';

  /// 48200 → "48.2K", as the lobby writes it.
  static String compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  Map<String, dynamic> toJson() => {
    'w': wave,
    's': score,
    if (at != null) 'at': at!.millisecondsSinceEpoch,
    'team': team,
  };

  /// [team] read as it may come: strings only, none empty or too long, at
  /// most [maxTeam].
  static List<String> teamOf(Object? raw) => raw is List
      ? [
          for (final id in raw.whereType<String>())
            if (id.isNotEmpty && id.length <= maxIdLength) id,
        ].take(maxTeam).toList(growable: false)
      : const [];

  /// Null for nothing, or anything malformed.
  static SurvivalBestRun? fromJson(Object? json) {
    if (json is! Map) return null;
    final w = json['w'], s = json['s'], at = json['at'];
    if (w is! num || s is! num || w < 0 || s < 0) return null;
    return SurvivalBestRun(
      wave: w.toInt(),
      score: s.toInt(),
      at: at is num ? DateTime.fromMillisecondsSinceEpoch(at.toInt()) : null,
      team: teamOf(json['team']),
    );
  }

  static Future<SurvivalBestRun?> _kept(SettingsDao settings) async {
    final raw = await settings.getSetting(settingKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  /// A run that has just ended: kept when it beats the one kept.
  static Future<void> note(
    SettingsDao settings, {
    required int wave,
    required int score,
    required List<String> team,
    DateTime? at,
  }) async {
    final run = SurvivalBestRun(
      wave: wave,
      score: score,
      at: at ?? DateTime.now(),
      team: teamOf(team),
    );
    final kept = await _kept(settings);
    if (kept != null && !run.beats(kept)) return;
    await settings.setSetting(settingKey, jsonEncode(run.toJson()));
  }

  /// The best as the lobby shows it (the table, or its keys where they are
  /// ahead), with when and the team of the run kept when that run reached
  /// the same wave. Null before any run has ended.
  static Future<SurvivalBestRun?> load(AlchemonsDatabase db) async {
    final settings = db.settingsDao;
    final table = await db.getSurvivalHighScore();
    int key(String? v) => int.tryParse(v?.trim() ?? '') ?? 0;
    final wave = math.max(
      table?.bestWave ?? 0,
      key(await settings.getSetting('cosmic_survival_best_wave')),
    );
    final score = math.max(
      table?.bestScore ?? 0,
      key(await settings.getSetting('cosmic_survival_high_score')),
    );
    if (wave <= 0 && score <= 0) return null;
    final kept = await _kept(settings);
    final ran = kept != null && kept.wave == wave ? kept : null;
    return SurvivalBestRun(
      wave: wave,
      score: score,
      at: ran?.at,
      team: ran?.team ?? const [],
    );
  }
}
