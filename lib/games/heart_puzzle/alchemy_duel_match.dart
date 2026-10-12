// lib/games/heart_puzzle/alchemy_duel_match.dart
//
// ALCHEMY FOR TWO, between two people on one phone: which board, who moves
// first, and the score so far. A board's first word always moves first;
// every new match (AGAIN, or the next board) swaps who sits there, so each
// player starts every other match. Which board each set opens on next is
// kept on the device.

import 'dart:convert';

import 'package:alchemons/games/heart_puzzle/alchemy_duel_boards.dart';
import 'package:alchemons/games/heart_puzzle/alchemy_duel_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DuelMatch {
  const DuelMatch({
    required this.number,
    this.firstPlayer = 0,
    this.wins = const [0, 0],
    this.draws = 0,
  });

  /// The board, from 1.
  final int number;

  /// The player who moves first (0 is PLAYER 1).
  final int firstPlayer;

  /// Matches won by PLAYER 1 and PLAYER 2 so far, and drawn.
  final List<int> wins;
  final int draws;

  DuelBoard get board => kDuelBoards[number - 1];

  DuelSetInfo get set =>
      kDuelSets.firstWhere((s) => number >= s.first && number <= s.last);

  /// The player in [seat] (seat 0 moves first).
  int playerAt(int seat) => seat ^ firstPlayer;

  /// The next board in this set, round to its first after its last.
  int get nextNumber => number >= set.last ? set.first : number + 1;

  /// The score once this match has ended so.
  DuelMatch scored(DuelEnd end) {
    final w = [...wins];
    final seat = end.winner;
    if (seat != null) w[playerAt(seat)]++;
    return DuelMatch(
      number: number,
      firstPlayer: firstPlayer,
      wins: w,
      draws: seat == null ? draws + 1 : draws,
    );
  }

  /// The match after this one, on [board] (this one again by default), the
  /// other player first.
  DuelMatch following({int? board}) => DuelMatch(
    number: board ?? number,
    firstPlayer: 1 - firstPlayer,
    wins: wins,
    draws: draws,
  );
}

/// Which board each set opens on next.
class DuelProgress {
  static const String _key = 'alchemy.duel.next.v1';

  static Future<Map<String, int>> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return {};
      return (jsonDecode(raw) as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      );
    } catch (_) {
      return {};
    }
  }

  /// The board [s] opens on.
  static Future<int> nextOf(DuelSetInfo s) async {
    final n = (await _load())[s.name];
    return n != null && n >= s.first && n <= s.last ? n : s.first;
  }

  /// A match on [m]'s board is over: its set opens on the next one.
  static Future<void> played(DuelMatch m) async {
    try {
      final all = await _load();
      all[m.set.name] = m.nextNumber;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(all));
    } catch (_) {}
  }
}
