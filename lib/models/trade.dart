// lib/models/trade.dart
//
// Trading Alchemons with friends: one for one, three a week.
//
// Two friends share one trade table (trades/{a}_{b} in Firestore, the two
// uids in order). Each puts one Alchemon on their side of it. Changing what
// is on either side clears both confirmations; when both have confirmed the
// same two, the trade is done and can't be undone. Each player's game then
// collects it: their own Alchemon leaves their save and the friend's arrives,
// whole — level, stats, Potential, nature, costumes, effect, case and trail,
// and its history, which says who has owned it.
//
// An Alchemon whose owner has confirmed waits on the table, out of their
// collection, until the trade is done or they take it back
// (TradeService keeps it in the save meanwhile).
//
// A trade uses one of each player's three for the week (Monday 00:00 UTC to
// the next); 100 gold gives three more.

import 'dart:convert';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/celebration_costume.dart';
import 'package:alchemons/models/cosmetic_wear.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/widgets/fx/alchemy_effects/alchemy_effect_paint.dart';
import 'package:drift/drift.dart' show Value;

abstract final class TradeRules {
  /// Trades each player has a week.
  static const int perWeek = 3;

  /// Gold for three more, once a week's are used.
  static const int resetGold = 100;

  /// The Monday (UTC) starting the week [t] falls in, as 2026-10-05.
  static String weekOf(DateTime t) {
    final u = t.toUtc();
    final day = DateTime.utc(u.year, u.month, u.day);
    final monday = day.subtract(Duration(days: day.weekday - DateTime.monday));
    String two(int n) => n.toString().padLeft(2, '0');
    return '${monday.year}-${two(monday.month)}-${two(monday.day)}';
  }

  /// When the week [now] falls in ends.
  static DateTime nextReset(DateTime now) {
    final u = now.toUtc();
    final day = DateTime.utc(u.year, u.month, u.day);
    final monday = day.subtract(Duration(days: day.weekday - DateTime.monday));
    return monday.add(const Duration(days: 7));
  }

  /// "2d 4h", "5h 12m", "40m": how long until [to].
  static String untilText(DateTime now, DateTime to) {
    final d = to.difference(now);
    if (d.inMinutes < 1) return '1m';
    if (d.inHours < 1) return '${d.inMinutes}m';
    if (d.inDays < 1) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inDays}d ${d.inHours % 24}h';
  }
}

/// How many of the week's trades a player has used (trade_allowance/{uid}).
class TradeAllowance {
  const TradeAllowance({this.week, this.used = 0});

  /// The week [used] counts in (TradeRules.weekOf); another week's count
  /// is nothing.
  final String? week;
  final int used;

  static const TradeAllowance none = TradeAllowance();

  int usedIn(DateTime now) => week == TradeRules.weekOf(now) ? used : 0;

  /// Trades left this week, before any waiting on a table.
  int left(DateTime now) =>
      (TradeRules.perWeek - usedIn(now)).clamp(0, TradeRules.perWeek);

  /// With one more used in [now]'s week.
  TradeAllowance plusOne(DateTime now) =>
      TradeAllowance(week: TradeRules.weekOf(now), used: usedIn(now) + 1);

  Map<String, dynamic> toJson() => {'week': week, 'used': used};

  static TradeAllowance fromJson(Map<String, dynamic>? d) {
    if (d == null) return none;
    final week = d['week'], used = d['used'];
    return TradeAllowance(
      week: week is String ? week : null,
      used: used is num ? used.toInt().clamp(0, 999) : 0,
    );
  }
}

/// One owner handing an Alchemon to the next.
class TradeStep {
  const TradeStep({
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.toName,
    required this.atMs,
  });

  final String fromUid, fromName, toUid, toName;
  final int atMs;

  DateTime get at => DateTime.fromMillisecondsSinceEpoch(atMs, isUtc: true);

  Map<String, dynamic> toJson() => {
    'from': fromUid,
    'fromName': fromName,
    'to': toUid,
    'toName': toName,
    'at': atMs,
  };

  static TradeStep? fromJson(Object? j) {
    if (j is! Map) return null;
    final from = j['from'], to = j['to'], at = j['at'];
    if (from is! String || to is! String || at is! num) return null;
    return TradeStep(
      fromUid: from,
      fromName: _name(j['fromName']),
      toUid: to,
      toName: _name(j['toName']),
      atMs: at.toInt(),
    );
  }
}

/// Who has owned an Alchemon, as traded: the alchemist it began with (the
/// first to trade it away) and each trade since, oldest first. Saved in its
/// `provenance` column; null for one never traded.
class TradeProvenance {
  const TradeProvenance(this.steps);

  final List<TradeStep> steps;

  /// The alchemist it began with.
  String? get firstName => steps.isEmpty ? null : steps.first.fromName;
  String? get firstUid => steps.isEmpty ? null : steps.first.fromUid;

  /// The trade that brought it to its owner now.
  TradeStep? get last => steps.isEmpty ? null : steps.last;

  /// How many have owned it, its owner now included.
  int get owners => steps.length + 1;

  TradeProvenance plus(TradeStep step) => TradeProvenance([...steps, step]);

  /// The most a history keeps: the first owner's trade and the latest.
  static const int maxSteps = 24;

  String encode() {
    final kept = steps.length <= maxSteps
        ? steps
        : [steps.first, ...steps.sublist(steps.length - maxSteps + 1)];
    return jsonEncode({
      'v': 1,
      'steps': [for (final s in kept) s.toJson()],
    });
  }

  static TradeProvenance? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw);
      if (j is! Map || j['steps'] is! List) return null;
      final steps = [
        for (final s in j['steps'] as List)
          if (TradeStep.fromJson(s) case final step?) step,
      ];
      return steps.isEmpty ? null : TradeProvenance(steps);
    } catch (_) {
      return null;
    }
  }
}

/// An Alchemon as it travels in a trade: its saved row, the case and trail
/// it stands in, and its history (in the row).
class TradedCreature {
  const TradedCreature({required this.instance, this.caseStyle, this.trail});

  final CreatureInstance instance;
  final CaseStyle? caseStyle;
  final TrailStyle? trail;

  static const int version = 1;

  /// The longest a card may be (the rules allow 120000).
  static const int maxLength = 100000;

  String get id => instance.instanceId;
  TradeProvenance? get provenance =>
      TradeProvenance.decode(instance.provenance);

  String encode() => jsonEncode({
    'v': version,
    'row': instance.toJson(),
    if (caseStyle != null) 'case': caseStyle!.id,
    if (trail != null) 'trail': trail!.id,
  });

  /// [raw] as a traded Alchemon, cleaned ([clean]); null when it can't be
  /// one. [knownSpecies] says whether a species id is in the catalog.
  static TradedCreature? decode(
    String? raw, {
    required bool Function(String baseId) knownSpecies,
  }) {
    if (raw == null || raw.isEmpty || raw.length > maxLength) return null;
    try {
      final j = jsonDecode(raw);
      if (j is! Map || j['row'] is! Map) return null;
      final row = CreatureInstance.fromJson(
        Map<String, dynamic>.from(j['row'] as Map),
      );
      if (!knownSpecies(row.baseId)) return null;
      return TradedCreature(
        instance: clean(row),
        caseStyle: CaseStyle.byId(j['case']),
        trail: TrailStyle.byId(j['trail']),
      );
    } catch (_) {
      return null;
    }
  }

  /// [row] with everything kept in the ranges a game can make: level,
  /// Potential and training ranks clamped, strings cut short, an unknown
  /// effect or costume dropped, and it unlocked and no one's favorite.
  /// Its stats are worked out again from these on arrival.
  static CreatureInstance clean(CreatureInstance row) {
    double potential(double v) =>
        AlchemonStatSystem.normalizePotential(v.isFinite ? v : 50).toDouble();
    int rank(int v) => v.clamp(0, AlchemonStatSystem.maxEnhancementRank);
    String? cut(String? s, int n) =>
        s == null ? null : (s.length > n ? s.substring(0, n) : s);
    final effect = row.alchemyEffect;
    final costumes = row.costumes;
    return row.copyWith(
      level: row.level.clamp(1, AlchemonStatSystem.maxLevel),
      xp: row.xp.clamp(0, 1 << 30),
      locked: false,
      isFavorite: false,
      nickname: Value(cut(row.nickname?.trim(), 24)),
      staminaMax: row.staminaMax.clamp(1, 12),
      staminaBars: row.staminaBars.clamp(0, row.staminaMax.clamp(1, 12)),
      statSpeedPotential: potential(row.statSpeedPotential),
      statIntelligencePotential: potential(row.statIntelligencePotential),
      statStrengthPotential: potential(row.statStrengthPotential),
      statBeautyPotential: potential(row.statBeautyPotential),
      statSpeedEnhancement: rank(row.statSpeedEnhancement),
      statIntelligenceEnhancement: rank(row.statIntelligenceEnhancement),
      statStrengthEnhancement: rank(row.statStrengthEnhancement),
      statBeautyEnhancement: rank(row.statBeautyEnhancement),
      generationDepth: row.generationDepth.clamp(0, 999),
      alchemyEffect: Value(AlchemyEffectPaint.has(effect) ? effect : null),
      costumes: Value(
        costumes == null
            ? null
            : WornCostumes.on(row.baseId, costumes).encode(),
      ),
      likelihoodAnalysisJson: Value(cut(row.likelihoodAnalysisJson, 20000)),
      provenance: Value(cut(row.provenance, 8000)),
    );
  }
}

/// A side's offer on the table: the Alchemon's id and its card
/// ([TradedCreature.encode]).
class TradeOffer {
  const TradeOffer({required this.id, required this.card});

  final String id;
  final String card;

  Map<String, dynamic> toJson() => {'id': id, 'card': card};

  static TradeOffer? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], card = j['card'];
    if (id is! String || id.isEmpty || card is! String) return null;
    return TradeOffer(id: id, card: card);
  }

  @override
  bool operator ==(Object other) =>
      other is TradeOffer && other.id == id && other.card == card;

  @override
  int get hashCode => Object.hash(id, card);
}

enum TradeStatus { open, done }

/// The trade table two friends share, as stored.
class TradeTable {
  const TradeTable({
    required this.a,
    required this.b,
    this.aName = 'Alchemist',
    this.bName = 'Alchemist',
    this.aOffer,
    this.bOffer,
    this.aReady = false,
    this.bReady = false,
    this.status = TradeStatus.open,
    this.aClaimed = false,
    this.bClaimed = false,
    this.lastBy,
    this.doneAt,
  });

  /// The two players, in order.
  final String a, b;
  final String aName, bName;
  final TradeOffer? aOffer, bOffer;
  final bool aReady, bReady;
  final TradeStatus status;

  /// Each side's game has collected the done trade.
  final bool aClaimed, bClaimed;

  /// Who wrote last.
  final String? lastBy;
  final DateTime? doneAt;

  String get id => idFor(a, b);

  static String idFor(String x, String y) =>
      x.compareTo(y) < 0 ? '${x}_$y' : '${y}_$x';

  bool get done => status == TradeStatus.done;

  /// [uid]'s view of it.
  TradeView of(String uid) => TradeView(this, uid == a);

  static TradeTable? fromDoc(Map<String, dynamic>? d) {
    if (d == null) return null;
    final a = d['a'], b = d['b'];
    if (a is! String || b is! String) return null;
    final doneAt = d['doneAt'];
    return TradeTable(
      a: a,
      b: b,
      aName: _name(d['aName']),
      bName: _name(d['bName']),
      aOffer: TradeOffer.fromJson(d['aOffer']),
      bOffer: TradeOffer.fromJson(d['bOffer']),
      aReady: d['aReady'] == true,
      bReady: d['bReady'] == true,
      status: d['status'] == 'done' ? TradeStatus.done : TradeStatus.open,
      aClaimed: d['aClaimed'] == true,
      bClaimed: d['bClaimed'] == true,
      lastBy: d['lastBy'] is String ? d['lastBy'] as String : null,
      doneAt: _time(doneAt),
    );
  }
}

/// Where a table stands, for one side.
enum TradePhase {
  /// Nothing on it.
  empty,

  /// Only this side has put one up.
  waitingForThem,

  /// Only the friend has put one up.
  yourTurn,

  /// Both up, neither confirmed.
  bothUp,

  /// This side confirmed; waiting for the friend.
  youConfirmed,

  /// The friend confirmed; waiting for this side.
  theyConfirmed,

  /// Traded.
  done,
}

/// One side's view of a [TradeTable].
class TradeView {
  const TradeView(this.table, this.isA);

  final TradeTable table;
  final bool isA;

  String get me => isA ? table.a : table.b;
  String get them => isA ? table.b : table.a;
  String get myName => isA ? table.aName : table.bName;
  String get theirName => isA ? table.bName : table.aName;
  TradeOffer? get mine => isA ? table.aOffer : table.bOffer;
  TradeOffer? get theirs => isA ? table.bOffer : table.aOffer;
  bool get iReady => isA ? table.aReady : table.bReady;
  bool get theyReady => isA ? table.bReady : table.aReady;
  bool get iClaimed => isA ? table.aClaimed : table.bClaimed;
  bool get theyClaimed => isA ? table.bClaimed : table.aClaimed;

  /// The field names of this side and the other, as stored ('a' / 'b').
  String get my => isA ? 'a' : 'b';
  String get their => isA ? 'b' : 'a';

  TradePhase get phase {
    if (table.done) return TradePhase.done;
    final m = mine, t = theirs;
    if (m == null && t == null) return TradePhase.empty;
    if (t == null) return TradePhase.waitingForThem;
    if (m == null) return TradePhase.yourTurn;
    if (iReady) return TradePhase.youConfirmed;
    if (theyReady) return TradePhase.theyConfirmed;
    return TradePhase.bothUp;
  }

  /// The friend is waiting on this side: they put one up for nothing yet,
  /// or confirmed and this side hasn't.
  bool get waitingOnMe => switch (phase) {
    TradePhase.yourTurn || TradePhase.theyConfirmed => true,
    TradePhase.bothUp => table.lastBy == them,
    _ => false,
  };
}

String _name(Object? v) {
  final s = v is String ? v.trim() : '';
  if (s.isEmpty) return 'Alchemist';
  return s.length > 24 ? s.substring(0, 24) : s;
}

DateTime? _time(Object? v) {
  if (v == null) return null;
  try {
    // A Firestore Timestamp, read without importing it here.
    final d = (v as dynamic).toDate();
    if (d is DateTime) return d.toUtc();
  } catch (_) {}
  if (v is DateTime) return v.toUtc();
  if (v is num) {
    return DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true);
  }
  return null;
}
