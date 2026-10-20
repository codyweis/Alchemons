// lib/games/stadium/trials_records.dart
//
// The Trials' records (the author, 2026-10-12: "make sure we keep fastest
// times records, and then we can show them on our home planet friends
// area"): the best the player has done at every race and every gem bout,
// and the Alchemon that did it. A race and a space course keep the fastest
// time over the line, an island and a battle the quickest win. Kept in
// prefs, and published to friends (friend_service.dart) so their planet
// page can set theirs against yours.
//
// Also here: what a race or bout reports when it ends (its place and its
// mark), what its end paid, and what each first win pays besides its gold —
// shards and Athanor tincture, which the retired space contests used to pay
// (the author, 2026-10-12: "remove them and transfer their rewards to our
// new trials").

import 'dart:convert';

import 'package:alchemons/games/stadium/gem_cups.dart';
import 'package:alchemons/games/stadium/race_cups.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What a record measures.
enum TrialsMark {
  /// Seconds, the fewer the better (kept as milliseconds).
  time,
}

/// One race or bout that keeps a record.
class TrialsEvent {
  const TrialsEvent(this.id, this.name, this.cupId, this.mark);

  final String id, name, cupId;
  final TrialsMark mark;

  /// [value] as it is shown: a time to the hundredth.
  String show(int value) => switch (mark) {
    TrialsMark.time => '${(value / 1000).toStringAsFixed(2)}s',
  };

  /// Whether [a] is better than [b].
  bool better(int a, int b) => switch (mark) {
    TrialsMark.time => a < b,
  };
}

/// Every event that keeps a record, in the order they are shown: the
/// races cup by cup, then the gem bouts.
final List<TrialsEvent> kTrialsEvents = [
  for (final cup in kRaceCups)
    for (final course in cup.courses)
      TrialsEvent(course.id, course.name, cup.id, TrialsMark.time),
  for (final cup in kGemCups)
    for (final bout in cup.bouts)
      TrialsEvent(bout.id, bout.name, cup.id, TrialsMark.time),
];

TrialsEvent? trialsEvent(String id) {
  for (final e in kTrialsEvents) {
    if (e.id == id) return e;
  }
  return null;
}

/// A record: the value (milliseconds or stars), the Alchemon that set it
/// (its name and species), and when.
class TrialsRecord {
  const TrialsRecord({
    required this.value,
    required this.by,
    this.baseId = '',
    this.at = 0,
  });

  final int value;
  final String by, baseId;

  /// Milliseconds since the epoch.
  final int at;

  Map<String, Object> toJson() => {
    'v': value,
    'by': by,
    if (baseId.isNotEmpty) 'b': baseId,
    if (at > 0) 'at': at,
  };

  static TrialsRecord? fromJson(Object? j) {
    if (j is! Map) return null;
    final v = j['v'];
    if (v is! num) return null;
    final by = j['by'];
    final b = j['b'];
    final at = j['at'];
    return TrialsRecord(
      value: v.round(),
      by: by is String ? by : '',
      baseId: b is String ? b : '',
      at: at is num ? at.round() : 0,
    );
  }
}

/// The player's records, by event id.
class TrialsRecords {
  const TrialsRecords([this.best = const {}]);

  static const prefsKey = 'trials_records_v1';

  final Map<String, TrialsRecord> best;

  /// Whether [value] at [id] would be a new record.
  bool beats(String id, int value) {
    final e = trialsEvent(id);
    if (e == null) return false;
    final old = best[id];
    return old == null || e.better(value, old.value);
  }

  TrialsRecords withRecord(String id, TrialsRecord r) =>
      TrialsRecords({...best, id: r});

  String serialise() =>
      jsonEncode({for (final e in best.entries) e.key: e.value.toJson()});

  static TrialsRecords deserialise(String? raw) {
    if (raw == null || raw.isEmpty) return const TrialsRecords();
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return const TrialsRecords();
      return TrialsRecords({
        for (final e in j.entries)
          if (e.key is String && trialsEvent(e.key as String) != null)
            if (TrialsRecord.fromJson(e.value) case final r?)
              e.key as String: r,
      });
    } catch (_) {
      return const TrialsRecords();
    }
  }

  static Future<TrialsRecords> load([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    return deserialise(p.getString(prefsKey));
  }

  Future<void> save([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(prefsKey, serialise());
  }

  /// The records as friends see them: event id → value.
  Map<String, int> get published => {
    for (final e in best.entries) e.key: e.value.value,
  };
}

/// How a race or bout ended for the player: its place, and its mark for
/// the record (seconds over the line or to the win, or stars; null when
/// there is none — an island lost, a race not finished).
class TrialsFinish {
  const TrialsFinish(this.place, this.mark);

  final int place;
  final double? mark;
}

/// What an end paid: the first win's gold, and whether it set a record.
class TrialsPayout {
  const TrialsPayout({this.gold = 0, this.record = false});

  final int gold;
  final bool record;
}

/// What each first win pays besides its gold — shards for the home bank
/// and tincture for the Athanor — by cup id and race or bout. About what
/// the space contests paid in all (1,080 shards, 120 tincture); the gem
/// cups' five bouts share what their three used to pay.
const Map<String, List<int>> kTrialsFirstWinShards = {
  'copper': [20, 25, 30],
  'silver': [40, 45, 50],
  'gold': [60, 70, 80],
  'ruby': [30, 35, 40, 45, 50],
  'sapphire': [35, 40, 45, 50, 60],
  'emerald': [45, 50, 60, 70, 85],
};

const Map<String, int> kTrialsFirstWinTincture = {
  'copper': 2,
  'silver': 4,
  'gold': 6,
  'ruby': 5,
  'sapphire': 6,
  'emerald': 7,
};

/// Shards a first win has paid that the home bank has not taken yet. The
/// home planet lives in space's own state while space is open, so the
/// Trials leave shards here and space banks them (cosmic_screen.dart).
const String kTrialsShardsPendingKey = 'trials_shards_pending_v1';

Future<void> addPendingTrialsShards(int shards) async {
  if (shards <= 0) return;
  final p = await SharedPreferences.getInstance();
  await p.setInt(
    kTrialsShardsPendingKey,
    (p.getInt(kTrialsShardsPendingKey) ?? 0) + shards,
  );
}

/// Takes the shards waiting for the home bank (and leaves none).
Future<int> takePendingTrialsShards() async {
  final p = await SharedPreferences.getInstance();
  final n = p.getInt(kTrialsShardsPendingKey) ?? 0;
  if (n > 0) await p.remove(kTrialsShardsPendingKey);
  return n;
}
