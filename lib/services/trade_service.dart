// lib/services/trade_service.dart
//
// Trading with friends (lib/models/trade.dart): the tables this player shares
// with each friend, kept live, and what they do at them — trade or fuse, put
// an Alchemon up, take it back, confirm, take a confirmation back — plus the
// week's three trades or fusions and the 100 gold that gives three more.
//
// The save's side of every move is TradeVault's (lib/services/trade_vault.dart)
// and, for fusions, FriendFusionLab's (lib/services/friend_fusion_lab.dart).
// This keeps the save and the tables in step: whenever a table changes (or
// the game starts, or a save is restored) it looks at each one and settles
// the save to match — a confirmed Alchemon waits on its trade table, one no
// longer confirmed comes back, and a done trade or fusion is collected, once,
// and marked so on the table.
//
// Firestore (rules in firestore.rules):
//   trades/{a}_{b}   the table (TradeTable)
//   traders/{uid}    {week, used, gone: {instanceId: doneAtMs}, updatedAt}

import 'dart:async';
import 'dart:convert';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/models/trade.dart';
import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/services/cosmetic_wear_service.dart';
import 'package:alchemons/services/breeding_service.dart'
    show EggCreationResult, EggPlacement;
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/friend_fusion_lab.dart';
import 'package:alchemons/services/friend_service.dart';
import 'package:alchemons/services/save_generation_service.dart';
import 'package:alchemons/services/trade_vault.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TradeException implements Exception {
  const TradeException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// A done trade or fusion this player has not watched yet: the two
/// Alchemons as they were on the table, the friend's as it arrived. For a
/// fusion, [gave] is this player's parent and [got] the friend's, both still
/// with their owners, and [vial] the cultivation each got.
class TradeArrival {
  const TradeArrival({
    required this.tableId,
    required this.key,
    required this.friendUid,
    required this.friendName,
    required this.gave,
    required this.got,
    this.mode = TradeMode.trade,
    this.vial,
    this.chamber,
  });

  final String tableId, key, friendUid, friendName;
  final TradedCreature gave;
  final TradedCreature got;
  final TradeMode mode;

  /// A fusion's cultivation, as it was on the table (an EggPayload, JSON).
  final String? vial;

  /// The chamber this player's cultivation went into (from 0); null for
  /// cold storage.
  final int? chamber;

  bool get fused => mode == TradeMode.fuse;

  Map<String, dynamic> toJson() => {
    'table': tableId,
    'key': key,
    'friend': friendUid,
    'friendName': friendName,
    'gave': gave.encode(),
    'got': got.encode(),
    if (fused) 'mode': mode.name,
    if (vial != null) 'vial': vial,
    if (chamber != null) 'chamber': chamber,
  };

  static TradeArrival? fromJson(
    Object? j,
    TradedCreature? Function(String?) read,
  ) {
    if (j is! Map) return null;
    final table = j['table'], key = j['key'], friend = j['friend'];
    if (table is! String || key is! String || friend is! String) return null;
    final gave = read(j['gave'] as String?);
    final got = read(j['got'] as String?);
    if (gave == null || got == null) return null;
    final name = j['friendName'];
    final vial = j['vial'], chamber = j['chamber'];
    return TradeArrival(
      tableId: table,
      key: key,
      friendUid: friend,
      friendName: name is String ? name : 'Alchemist',
      gave: gave,
      got: got,
      mode: TradeMode.of(j['mode']),
      vial: vial is String ? vial : null,
      chamber: chamber is num ? chamber.toInt() : null,
    );
  }
}

/// What confirming did.
enum ConfirmResult {
  /// Waiting for the friend to confirm too.
  waiting,

  /// Both have: traded.
  traded,

  /// Both have: fused.
  fused,

  /// This player's Alchemon had changed since it went up; the table has it
  /// as it is now, and both confirm again.
  refreshed,
}

class TradeService extends ChangeNotifier {
  TradeService({
    required this.account,
    required this.db,
    required this.catalog,
    required this.friends,
    this.wear,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore,
       vault = TradeVault(db, catalog: catalog) {
    account.addListener(_onAccount);
    friends.addListener(_onFriends);
    _onAccount();
  }

  final AccountService account;
  final AlchemonsDatabase db;
  final CreatureCatalog catalog;
  final FriendService friends;
  final CosmeticWearService? wear;
  final TradeVault vault;
  FirebaseFirestore? _firestore;

  FirebaseFirestore get _fs => _firestore ??= FirebaseFirestore.instance;

  /// Fusing's side of the save, once the lab's recipes have loaded; a fusion
  /// done before then is collected when it is given.
  FriendFusionLab? get lab => _lab;
  FriendFusionLab? _lab;

  void attachLab(FriendFusionLab? lab) {
    if (identical(lab, _lab)) return;
    _lab = lab;
    if (lab != null && _uid != null) unawaited(_settle());
  }

  String? _uid;
  Map<String, TradeTable> _tables = const {};
  Map<String, CreatureInstance> _waiting = const {};
  TradeAllowance _allowance = TradeAllowance.none;
  Map<String, int> _gone = const {};
  bool _traderLoaded = false;
  List<TradeArrival> _arrivals = const [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _traderSub;
  Future<void> _settling = Future.value();
  bool _disposed = false;

  /// Signed in, with friends to trade with.
  bool get available => friends.available && friends.code != null;

  /// The table shared with [friendUid], as this player sees it; null when
  /// there is none yet.
  TradeView? tableWith(String friendUid) {
    final me = _uid;
    final t = _tables[friendUid];
    return me == null || t == null ? null : t.of(me);
  }

  /// What waits, confirmed, on the table with [friendUid] (out of the
  /// collection until the trade is done or taken back).
  CreatureInstance? waitingWith(String friendUid) {
    final me = _uid;
    if (me == null) return null;
    return _waiting[TradeTable.idFor(me, friendUid)];
  }

  /// Done trades not watched yet.
  List<TradeArrival> get arrivals => _arrivals;

  TradeArrival? arrivalWith(String friendUid) =>
      _arrivals.where((a) => a.friendUid == friendUid).firstOrNull;

  /// A table with [friendUid] waits on this player, or a trade with them is
  /// done and not watched.
  bool attentionWith(String friendUid) =>
      (tableWith(friendUid)?.waitingOnMe ?? false) ||
      arrivalWith(friendUid) != null;

  /// Any table waits on this player: the home screen's profile button and
  /// each friend in FRIENDS wear a dot.
  bool get hasAttention =>
      _arrivals.isNotEmpty ||
      _tables.keys.any((uid) => tableWith(uid)?.waitingOnMe ?? false);

  /// Trades or fusions left this week: the week's three (or more, bought),
  /// less those done and those confirmed and waiting.
  int left([DateTime? now]) {
    final n = _allowance.left(now ?? DateTime.now()) - _confirmedWaiting();
    return n < 0 ? 0 : n;
  }

  /// The week's trades have been read.
  bool get allowanceKnown => _traderLoaded;

  int _confirmedWaiting({String? except}) {
    final me = _uid;
    if (me == null) return 0;
    var n = 0;
    for (final e in _tables.entries) {
      if (e.key == except) continue;
      final v = e.value.of(me);
      if (!e.value.done && v.iConfirmed) n++;
    }
    return n;
  }

  /// The Alchemons this player has up on tables, by id.
  Set<String> get offered {
    final me = _uid;
    if (me == null) return const {};
    return {
      for (final t in _tables.values)
        if (!t.done)
          if (t.of(me).mine?.id case final id?) id,
    };
  }

  // ── Listening ───────────────────────────────────────────────────────────

  void _onAccount() => _restart();
  void _onFriends() {
    _restart();
    // A friendship that ended leaves nothing waiting on its table.
    if (friends.loaded) unawaited(_settle());
  }

  void _restart() {
    final uid = available ? account.user?.uid : null;
    if (uid == _uid) return;
    _uid = uid;
    _sub?.cancel();
    _traderSub?.cancel();
    _sub = null;
    _traderSub = null;
    _tables = const {};
    _allowance = TradeAllowance.none;
    _gone = const {};
    _traderLoaded = false;
    _arrivals = const [];
    if (uid != null) {
      unawaited(_loadArrivals(uid));
      _sub = _fs
          .collection('trades')
          .where('parties', arrayContains: uid)
          .snapshots()
          .listen(
            (snap) {
              if (_uid != uid || _disposed) return;
              _tables = {
                for (final d in snap.docs)
                  if (TradeTable.fromDoc(d.data()) case final t?)
                    t.a == uid ? t.b : t.a: t,
              };
              notifyListeners();
              unawaited(_settle());
            },
            onError: (Object e) {
              debugPrint('TradeService: table listener stopped: $e');
            },
          );
      _traderSub = _trader(uid).snapshots().listen(
        (snap) {
          if (_uid != uid || _disposed) return;
          final d = snap.data();
          _allowance = TradeAllowance.fromJson(d);
          _gone = _readGone(d?['gone']);
          final first = !_traderLoaded;
          _traderLoaded = true;
          notifyListeners();
          if (first) unawaited(_enforceGone());
        },
        onError: (Object e) {
          debugPrint('TradeService: allowance listener stopped: $e');
        },
      );
    }
    if (!_disposed) notifyListeners();
  }

  static Map<String, int> _readGone(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final e in raw.entries)
        if (e.key is String && e.value is num)
          e.key as String: (e.value as num).toInt(),
    };
  }

  DocumentReference<Map<String, dynamic>> _table(String id) =>
      _fs.collection('trades').doc(id);
  DocumentReference<Map<String, dynamic>> _trader(String uid) =>
      _fs.collection('traders').doc(uid);

  String get _me {
    final uid = _uid;
    if (uid == null) throw const TradeException('Sign in first.');
    return uid;
  }

  String get _myName {
    final n = account.user?.displayName?.trim() ?? '';
    final name = n.isEmpty ? 'Alchemist' : n;
    return name.length > 24 ? name.substring(0, 24) : name;
  }

  /// Trades only from this account's own game.
  Future<void> _ownGame() async {
    final owner = await SaveGenerationService.owner(db);
    if (owner != null && owner != _me) {
      throw const TradeException('This game belongs to another account.');
    }
  }

  // ── At the table ────────────────────────────────────────────────────────

  /// Why [instance] can't go up, or null. On a fusion table it stays the
  /// player's, so only being up on another table stops it.
  Future<String?> whyNot(CreatureInstance instance, {String? friendUid}) async {
    final me = _uid;
    final here = me == null || friendUid == null ? null : tableWith(friendUid);
    final elsewhere = {...offered}..remove(here?.mine?.id);
    if (here?.fusing ?? false) {
      return elsewhere.contains(instance.instanceId)
          ? 'It is on another table.'
          : null;
    }
    return vault.whyNot(instance, elsewhere: elsewhere);
  }

  /// Why the two up on the fusion table with [friendUid] can't fuse in this
  /// game, or null (also when there aren't two up to ask about).
  Future<String?> whyNotFuse(String friendUid) async {
    final v = tableWith(friendUid);
    final lab = _lab;
    final mine = v?.mine, theirs = read(v?.theirs?.card);
    if (v == null || !v.fusing || lab == null || mine == null) return null;
    if (theirs == null) return "This game can't fuse with their Alchemon.";
    final now = await db.creatureDao.getInstance(mine.id);
    if (now == null) return 'Yours is no longer in your collection.';
    return lab.whyNot(now, theirs.instance);
  }

  /// [raw] (a friend's card) read and cleaned, or null.
  TradedCreature? read(String? raw) {
    if (raw == null) return null;
    return _cards.putIfAbsent(raw, () => vault.read(raw));
  }

  final Map<String, TradedCreature?> _cards = {};

  /// Puts [instanceId] up on the table with [friend], in place of whatever
  /// this player had there. Both confirmations clear.
  Future<void> put(FriendCard friend, String instanceId) async {
    final me = _me;
    await _ownGame();
    final row = await db.creatureDao.getInstance(instanceId);
    if (row == null) {
      throw const TradeException('That Alchemon is not in your collection.');
    }
    final why = await whyNot(row, friendUid: friend.uid);
    if (why != null) throw TradeException(why);
    final card = (await vault.card(instanceId))!.encode();
    if (card.length > TradedCreature.maxLength) {
      throw const TradeException('That Alchemon can not be traded.');
    }
    final offer = TradeOffer(id: instanceId, card: card);
    final id = TradeTable.idFor(me, friend.uid);
    await _run(
      () => _fs.runTransaction((tx) async {
        final snap = await tx.get(_table(id));
        final t = TradeTable.fromDoc(snap.data());
        if (t == null || (t.done && t.aClaimed && t.bClaimed)) {
          tx.set(_table(id), _fresh(me, friend, offer, mode: t?.mode));
          return;
        }
        if (t.done) throw _stillCollecting(t);
        final v = t.of(me);
        if (v.mine == offer) return;
        tx.update(_table(id), {
          '${v.my}Name': _myName,
          '${v.my}Offer': offer.toJson(),
          ..._unconfirmed,
          'lastBy': me,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }),
    );
  }

  /// Every confirmation, cleared: what goes with any change to the table.
  static const Map<String, Object> _unconfirmed = {
    'aReady': false,
    'bReady': false,
    'aFuse': false,
    'bFuse': false,
  };

  static TradeException _stillCollecting(TradeTable t) => TradeException(
    t.fused
        ? 'The last fusion is still being collected.'
        : 'The last trade is still being collected.',
  );

  /// A new table, or one cleared after the last was collected by both: it
  /// keeps doing what the last did ([mode]).
  Map<String, dynamic> _fresh(
    String me,
    FriendCard friend,
    TradeOffer? mine, {
    TradeMode? mode,
  }) {
    final meIsA = me.compareTo(friend.uid) < 0;
    final a = meIsA ? me : friend.uid, b = meIsA ? friend.uid : me;
    return {
      'a': a,
      'b': b,
      'parties': [a, b],
      'aName': meIsA ? _myName : _cut(friend.name),
      'bName': meIsA ? _cut(friend.name) : _myName,
      'aOffer': meIsA ? mine?.toJson() : null,
      'bOffer': meIsA ? null : mine?.toJson(),
      ..._unconfirmed,
      'mode': (mode ?? TradeMode.trade).name,
      'result': null,
      'status': 'open',
      'aClaimed': false,
      'bClaimed': false,
      'lastBy': me,
      'updatedAt': FieldValue.serverTimestamp(),
      'doneAt': null,
    };
  }

  static String _cut(String s) => s.length > 24 ? s.substring(0, 24) : s;

  /// Takes this player's Alchemon off the table with [friendUid] (back into
  /// the collection, if it waited there). The table goes once it is empty.
  Future<void> takeBack(String friendUid) async {
    await _takeBack(friendUid);
    await _settle();
  }

  /// [takeBack] on the table only (the save settles after).
  Future<void> _takeBack(String friendUid) async {
    final me = _me;
    final id = TradeTable.idFor(me, friendUid);
    await _run(
      () => _fs.runTransaction((tx) async {
        final snap = await tx.get(_table(id));
        final t = TradeTable.fromDoc(snap.data());
        if (t == null || t.done) return;
        final v = t.of(me);
        if (v.mine == null) return;
        if (v.theirs == null) {
          tx.delete(_table(id));
          return;
        }
        tx.update(_table(id), {
          '${v.my}Offer': null,
          ..._unconfirmed,
          'lastBy': me,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }),
    );
  }

  /// Has the table with [friend] trade or fuse. What is up stays up; both
  /// confirmations clear.
  Future<void> setMode(FriendCard friend, TradeMode mode) async {
    final me = _me;
    await _ownGame();
    final id = TradeTable.idFor(me, friend.uid);
    await _run(
      () => _fs.runTransaction((tx) async {
        final snap = await tx.get(_table(id));
        final t = TradeTable.fromDoc(snap.data());
        if (t == null || (t.done && t.aClaimed && t.bClaimed)) {
          tx.set(_table(id), _fresh(me, friend, null, mode: mode));
          return;
        }
        if (t.done) throw _stillCollecting(t);
        if (t.mode == mode) return;
        tx.update(_table(id), {
          'mode': mode.name,
          ..._unconfirmed,
          'lastBy': me,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }),
    );
    await _settle();
  }

  /// Confirms the two on the table with [friend] as they are. Done at once
  /// if the friend has confirmed already.
  Future<ConfirmResult> confirm(FriendCard friend) async {
    final me = _me;
    await _ownGame();
    final id = TradeTable.idFor(me, friend.uid);
    final seen = tableWith(friend.uid);
    final mine = seen?.mine, theirs = seen?.theirs;
    if (seen == null || seen.table.done || mine == null || theirs == null) {
      throw const TradeException('Both need an Alchemon on the table.');
    }
    if (seen.fusing) return _confirmFusion(friend, seen, mine, theirs);
    if (seen.iReady) return ConfirmResult.waiting;
    final got = read(theirs.card);
    if (got == null) {
      throw const TradeException("Their Alchemon can't come to this game.");
    }
    final why = await vault.whyNotReceive(got);
    if (why != null) throw TradeException(why);
    if (left() < 1) {
      throw const TradeException('No trades left this week.');
    }

    // Still as it went up? Stamina comes and goes and is no change.
    final now = await vault.card(mine.id);
    if (now == null) {
      await takeBack(friend.uid);
      throw const TradeException(
        'Your Alchemon is no longer in your collection.',
      );
    }
    final busy = await vault.whyNot(now.instance, elsewhere: {});
    if (busy != null) throw TradeException(busy);
    if (_substance(now.encode()) != _substance(mine.card)) {
      await put(friend, mine.id);
      return ConfirmResult.refreshed;
    }

    var traded = false;
    await _run(
      () => _fs.runTransaction((tx) async {
        final snap = await tx.get(_table(id));
        final t = TradeTable.fromDoc(snap.data());
        if (t == null || t.done) {
          throw const TradeException('The table has changed.');
        }
        final v = t.of(me);
        if (v.mine != mine || v.theirs != theirs) {
          throw const TradeException('The table has changed. Look again.');
        }
        if (v.iReady) return;
        traded = v.theyReady;
        tx.update(_table(id), {
          '${v.my}Ready': true,
          '${v.my}Name': _myName,
          if (traded) ...{
            'status': 'done',
            'doneAt': FieldValue.serverTimestamp(),
          },
          'lastBy': me,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }),
    );
    await _settle();
    return traded ? ConfirmResult.traded : ConfirmResult.waiting;
  }

  /// [confirm] on a fusion table. The second to confirm makes the
  /// cultivation, from the two as the table has them, and writes it there
  /// in the same write that finishes it.
  Future<ConfirmResult> _confirmFusion(
    FriendCard friend,
    TradeView seen,
    TradeOffer mine,
    TradeOffer theirs,
  ) async {
    final me = _me;
    final id = seen.table.id;
    if (seen.iFuse) return ConfirmResult.waiting;
    final lab = _lab;
    if (lab == null) {
      throw const TradeException('The lab is still opening. Try again.');
    }
    final got = read(theirs.card);
    if (got == null) {
      throw const TradeException("This game can't fuse with their Alchemon.");
    }
    if (left() < 1) {
      throw const TradeException('No trades or fusions left this week.');
    }
    final now = await vault.card(mine.id);
    if (now == null) {
      await takeBack(friend.uid);
      throw const TradeException(
        'Your Alchemon is no longer in your collection.',
      );
    }
    final why = await lab.whyNot(now.instance, got.instance);
    if (why != null) throw TradeException(why);
    if (_substance(now.encode()) != _substance(mine.card)) {
      await put(friend, mine.id);
      return ConfirmResult.refreshed;
    }
    // Made whether or not the friend has confirmed yet: they may while this
    // is being written.
    final a = read(seen.isA ? mine.card : theirs.card);
    final b = read(seen.isA ? theirs.card : mine.card);
    final result = a == null || b == null
        ? null
        : lab.brew(a.instance, b.instance);
    if (result == null) {
      throw const TradeException('These two make nothing together.');
    }

    var fused = false;
    await _run(
      () => _fs.runTransaction((tx) async {
        final snap = await tx.get(_table(id));
        final t = TradeTable.fromDoc(snap.data());
        if (t == null || t.done) {
          throw const TradeException('The table has changed.');
        }
        final v = t.of(me);
        if (!v.fusing || v.mine != mine || v.theirs != theirs) {
          throw const TradeException('The table has changed. Look again.');
        }
        if (v.iFuse) return;
        fused = v.theyFuse;
        tx.update(_table(id), {
          '${v.my}Fuse': true,
          '${v.my}Name': _myName,
          if (fused) ...{
            'status': 'fused',
            'result': result,
            'doneAt': FieldValue.serverTimestamp(),
          },
          'lastBy': me,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }),
    );
    await _settle();
    return fused ? ConfirmResult.fused : ConfirmResult.waiting;
  }

  /// A card without what changes on its own (stamina), to compare.
  static String _substance(String card) {
    try {
      final j = jsonDecode(card) as Map<String, dynamic>;
      final row = Map<String, dynamic>.from(j['row'] as Map)
        ..remove('staminaBars')
        ..remove('staminaLastUtcMs');
      return jsonEncode({...j, 'row': row});
    } catch (_) {
      return card;
    }
  }

  /// Takes this player's confirmation back (on a trade table, their
  /// Alchemon returns to the collection, still up on it).
  Future<void> unconfirm(String friendUid) async {
    final me = _me;
    final id = TradeTable.idFor(me, friendUid);
    await _run(
      () => _fs.runTransaction((tx) async {
        final snap = await tx.get(_table(id));
        final t = TradeTable.fromDoc(snap.data());
        if (t == null || t.done) return;
        final v = t.of(me);
        if (!v.iConfirmed) return;
        tx.update(_table(id), {
          '${v.my}${v.fusing ? 'Fuse' : 'Ready'}': false,
          'lastBy': me,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }),
    );
    await _settle();
  }

  /// Three more trades or fusions this week, for [TradeRules.resetGold]
  /// gold, once the week's are used. False when there isn't the gold.
  Future<bool> buyMore() async {
    final me = _me;
    await _ownGame();
    if (_allowance.left(DateTime.now()) > 0) {
      throw const TradeException('You still have trades this week.');
    }
    final paid = await db.transaction(
      () => db.currencyDao.spendGold(TradeRules.resetGold),
    );
    if (!paid) return false;
    try {
      await _run(
        () => _fs.runTransaction((tx) async {
          final snap = await tx.get(_trader(me));
          final d = snap.data();
          tx.set(_trader(me), {
            'week': TradeRules.weekOf(DateTime.now()),
            'used': 0,
            'gone': _readGone(d?['gone']),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }),
      );
    } catch (_) {
      await db.currencyDao.addGold(TradeRules.resetGold);
      rethrow;
    }
    return true;
  }

  /// [arrival] has been watched.
  Future<void> seen(TradeArrival arrival) async {
    _arrivals = [..._arrivals.where((a) => a.key != arrival.key)];
    notifyListeners();
    await _saveArrivals();
  }

  /// Takes this player's Alchemon off the table with [friendUid] and
  /// clears it, before the two stop being friends.
  Future<void> leave(String friendUid) async {
    try {
      await _takeBack(friendUid);
    } catch (e) {
      debugPrint('TradeService.leave: $e');
    }
    await _settle();
  }

  // ── Keeping the save in step ────────────────────────────────────────────

  /// Settles the save to the tables, one pass at a time.
  Future<void> _settle() {
    final next = _settling.then((_) => _settleOnce()).catchError((Object e) {
      debugPrint('TradeService: settle failed: $e');
    });
    _settling = next;
    return next;
  }

  Future<void> _settleOnce() async {
    final me = _uid;
    if (me == null || _disposed) return;
    final owner = await SaveGenerationService.owner(db);
    if (owner != null && owner != me) return;
    final tables = {for (final t in _tables.values) t.id: t};
    final friendIds = {for (final f in friends.friends) f.uid};

    // What waits comes back unless its table still has it confirmed, or
    // traded and not collected yet.
    for (final e in (await vault.escrowed()).entries) {
      final t = tables[e.key];
      final v = t?.of(me);
      if (t != null &&
          v!.mine?.id == e.value.instanceId &&
          (t.done ? t.traded && !v.iClaimed : !v.fusing && v.iReady)) {
        continue;
      }
      await vault.release(e.key, gone: _gone);
    }

    var changed = false;
    for (final t in tables.values) {
      final v = t.of(me);
      final mine = v.mine;
      if (!t.done) {
        // A friendship that ended: nothing stays up.
        if (friends.loaded && !friendIds.contains(v.them) && mine != null) {
          await _quietly(() => _takeBack(v.them));
          continue;
        }
        if (!v.fusing && v.iReady && mine != null) {
          final held = await vault.escrow(t.id, mine.id);
          if (!held && (await vault.escrowed())[t.id] == null) {
            // Confirmed, and gone from the collection some other way.
            await _quietly(() => _takeBack(v.them));
          }
        }
        continue;
      }
      if (v.iClaimed) continue;
      if (t.traded ? await _collect(t, v) : await _collectFusion(t, v)) {
        changed = true;
      }
    }

    _waiting = {
      for (final e in (await vault.escrowed()).entries)
        if (tables[e.key] case final t?)
          if (!t.done) e.key: e.value,
    };
    if (changed) {
      await wear?.load();
      friends.publishSoon();
    }
    if (!_disposed) notifyListeners();
  }

  /// Collects the done trade on [t] into the save, then marks it collected
  /// on the table and counts it. True when the save changed.
  Future<bool> _collect(TradeTable t, TradeView v) async {
    final me = v.me;
    final mine = v.mine, theirs = v.theirs;
    final doneAt = t.doneAt;
    if (mine == null || theirs == null || doneAt == null) return false;
    final key = '${t.id}@${doneAt.millisecondsSinceEpoch}';
    final got = read(theirs.card);
    if (got == null) {
      debugPrint('TradeService: their card on ${t.id} could not be read');
      return false;
    }
    var changed = false;
    if (!await vault.collected(key)) {
      final arrived = await vault.collect(
        key: key,
        tableId: t.id,
        giveId: mine.id,
        got: got,
        step: TradeStep(
          fromUid: v.them,
          fromName: v.theirName,
          toUid: me,
          toName: v.myName,
          atMs: doneAt.millisecondsSinceEpoch,
        ),
      );
      if (arrived != null) {
        changed = true;
        final gave = read(mine.card);
        if (gave != null) {
          _arrivals = [
            ..._arrivals.where((a) => a.key != key),
            TradeArrival(
              tableId: t.id,
              key: key,
              friendUid: v.them,
              friendName: v.theirName,
              gave: gave,
              got: TradedCreature(
                instance: arrived,
                caseStyle: got.caseStyle,
                trail: got.trail,
              ),
            ),
          ];
          await _saveArrivals();
        }
      }
    }
    await _claim(t, me, doneAt, gave: mine.id, got: got.id);
    return changed;
  }

  /// Collects the fusion on [t]: this player's cultivation into a chamber
  /// (or cold storage) and a rest for their parent, once, then marks it
  /// collected on the table and counts it. True when the save changed.
  Future<bool> _collectFusion(TradeTable t, TradeView v) async {
    final lab = _lab;
    // Collected once the lab is open ([attachLab] settles again).
    if (lab == null) return false;
    final me = v.me;
    final mine = v.mine, theirs = v.theirs;
    final doneAt = t.doneAt;
    if (mine == null || theirs == null || doneAt == null) return false;
    final atMs = doneAt.millisecondsSinceEpoch;
    final key = '${t.id}@$atMs';
    final payload = lab.read(t.result);
    final got = read(theirs.card);
    if (payload == null || got == null) {
      debugPrint('TradeService: the fusion on ${t.id} could not be read');
      return false;
    }
    final EggCreationResult? placed;
    try {
      placed = await db.transaction(() async {
        if (await vault.collected(key)) return null;
        final r = await lab.place(
          payload: payload,
          origin: FusionOrigin(
            byUid: me,
            byName: v.myName,
            withUid: v.them,
            withName: v.theirName,
            atMs: atMs,
          ),
          mineId: mine.id,
          theirs: got.instance,
        );
        final eggId = r.eggId;
        if (!r.success || eggId == null) {
          throw TradeException(r.message ?? 'It could not be kept.');
        }
        await vault.keepReceipt(
          key,
          TradeReceipt(gave: mine.id, got: eggId, atMs: atMs),
        );
        return r;
      });
    } catch (e) {
      // Tried again on the next settling.
      debugPrint('TradeService: the fusion on ${t.id} was not collected: $e');
      return false;
    }
    if (placed != null) {
      final gave = read(mine.card);
      if (gave != null) {
        _arrivals = [
          ..._arrivals.where((a) => a.key != key),
          TradeArrival(
            tableId: t.id,
            key: key,
            friendUid: v.them,
            friendName: v.theirName,
            gave: gave,
            got: got,
            mode: TradeMode.fuse,
            vial: t.result,
            chamber: placed.placement == EggPlacement.incubator
                ? placed.slotId
                : null,
          ),
        ];
        await _saveArrivals();
      }
    }
    await _claim(t, me, doneAt);
    return placed != null;
  }

  /// Marks the done trade or fusion on [t] collected by this player and
  /// counts it in the week it was done; a trade also notes what left ([gave])
  /// and what came back ([got]).
  Future<void> _claim(
    TradeTable t,
    String me,
    DateTime doneAt, {
    String? gave,
    String? got,
  }) async {
    try {
      await _fs
          .runTransaction((tx) async {
            final snap = await tx.get(_table(t.id));
            final now = TradeTable.fromDoc(snap.data());
            if (now == null || !now.done) return;
            final nv = now.of(me);
            if (nv.iClaimed) return;
            final trader = await tx.get(_trader(me));
            final d = trader.data();
            final allowance = TradeAllowance.fromJson(d);
            final gone = {..._readGone(d?['gone'])};
            if (got != null) gone.remove(got);
            if (gave != null) gone[gave] = doneAt.millisecondsSinceEpoch;
            final counts =
                TradeRules.weekOf(doneAt) == TradeRules.weekOf(DateTime.now());
            final next = counts ? allowance.plusOne(DateTime.now()) : allowance;
            tx.update(_table(t.id), {
              '${nv.my}Claimed': true,
              'lastBy': me,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            tx.set(_trader(me), {
              'week': next.week ?? TradeRules.weekOf(DateTime.now()),
              'used': next.usedIn(DateTime.now()),
              'gone': _trimGone(gone),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          })
          .timeout(_wait);
    } catch (e) {
      // Collected in the save; marked on the table next time.
      debugPrint('TradeService: collected ${t.id}, not marked yet: $e');
    }
  }

  /// The newest [n] of [gone].
  static Map<String, int> _trimGone(Map<String, int> gone, {int n = 4000}) {
    if (gone.length <= n) return gone;
    final sorted = gone.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in sorted.take(n)) e.key: e.value};
  }

  Future<void> _enforceGone() async {
    try {
      final owner = await SaveGenerationService.owner(db);
      if (owner != null && owner != _uid) return;
      final n = await vault.enforceGone(_gone);
      if (n > 0) {
        debugPrint('TradeService: $n traded-away Alchemon(s) left the save');
        await wear?.load();
      }
    } catch (e) {
      debugPrint('TradeService: could not check traded-away: $e');
    }
  }

  /// After a save is restored: nothing traded away comes back with it, and
  /// the tables are settled again.
  Future<void> afterRestore() async {
    await _enforceGone();
    await _settle();
  }

  // ── Arrivals not watched, kept on the device ────────────────────────────

  static String _arrivalsKey(String uid) => 'trades.unwatched.$uid';

  Future<void> _loadArrivals(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_arrivalsKey(uid));
      if (raw == null || _uid != uid) return;
      final list = jsonDecode(raw);
      if (list is! List) return;
      _arrivals = [
        for (final j in list)
          if (TradeArrival.fromJson(j, read) case final a?) a,
      ];
      if (!_disposed) notifyListeners();
    } catch (e) {
      debugPrint('TradeService: unwatched trades unreadable: $e');
    }
  }

  Future<void> _saveArrivals() async {
    final uid = _uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _arrivalsKey(uid),
      jsonEncode([for (final a in _arrivals) a.toJson()]),
    );
  }

  /// Done once every settling asked for so far is (tests).
  @visibleForTesting
  Future<void> get idle => _settling;

  // ── Leaving ─────────────────────────────────────────────────────────────

  /// Takes everything this player has up off every table, before their
  /// account is deleted.
  Future<void> forget() async {
    final me = _me;
    for (final uid in [..._tables.keys]) {
      final t = _tables[uid]!;
      if (!t.done) {
        await leave(uid);
      } else if (!t.of(me).iClaimed) {
        await _settle();
      }
    }
    await _trader(me).delete();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  static const Duration _wait = Duration(seconds: 20);

  static Future<void> _quietly(Future<void> Function() write) async {
    try {
      await write();
    } catch (e) {
      debugPrint('TradeService: $e');
    }
  }

  Future<void> _run(Future<void> Function() write) async {
    try {
      await write().timeout(_wait);
    } on TradeException {
      rethrow;
    } on FirebaseException catch (e) {
      throw TradeException(switch (e.code) {
        'unavailable' => 'You are offline.',
        'permission-denied' => 'That is not allowed.',
        'aborted' || 'failed-precondition' => 'The table has changed.',
        _ => 'Something went wrong (${e.code}).',
      });
    } on TimeoutException {
      throw const TradeException('You are offline.');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _traderSub?.cancel();
    account.removeListener(_onAccount);
    friends.removeListener(_onFriends);
    super.dispose();
  }
}
