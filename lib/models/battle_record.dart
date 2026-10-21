import 'package:alchemons/database/daos/settings_dao.dart';

/// The player's battles: won, lost, drawn. Against the computer under
/// [settingKey]; against each friend, live, under their own [friendKey]
/// (a head-to-head, "You 3 – 2 Bo"). Kept in Settings, so it travels with
/// the save.
class BattleRecord {
  const BattleRecord({this.wins = 0, this.losses = 0, this.draws = 0});

  final int wins;
  final int losses;
  final int draws;

  static const String settingKey = 'battle_record_v1';

  /// Where the record against the friend [uid] is kept.
  static String friendKey(String uid) => 'battle_vs_$uid';

  int get played => wins + losses + draws;

  /// After one more battle: [winner] 0 is the player, 1 the other side,
  /// null a draw.
  BattleRecord after(int? winner) => BattleRecord(
    wins: wins + (winner == 0 ? 1 : 0),
    losses: losses + (winner == 1 ? 1 : 0),
    draws: draws + (winner == null ? 1 : 0),
  );

  static Future<BattleRecord> load(
    SettingsDao settings, {
    String key = settingKey,
  }) async {
    final raw = await settings.getSetting(key);
    final parts = (raw ?? '').split(',').map(int.tryParse).toList();
    int at(int i) => i < parts.length ? (parts[i] ?? 0) : 0;
    return BattleRecord(wins: at(0), losses: at(1), draws: at(2));
  }

  Future<void> save(SettingsDao settings, {String key = settingKey}) =>
      settings.setSetting(key, '$wins,$losses,$draws');
}
