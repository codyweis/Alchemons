// lib/services/battle_room_service.dart
//
// Live battles with a friend, the Firestore side (docs/battle/
// live_pvp_design.md): `battle_rooms/{id}`. The host makes a room and asks
// one friend in; each writes their four (as numbers, models/battle_room.dart)
// into their own seat; the guest says READY; the host starts the fight with
// a start time on the server's clock.
//
// While it is on, the host's phone sends the fight into the room's stream,
// `battle_rooms/{id}/stream/{0..7}`: four packets a second, each into the
// next of eight documents, so each document is written every two seconds
// (Firestore takes about one write a second to a document). The guest's
// inputs go into the room itself, the whole list each time, with a beat.
//
// The server's clock: a seat is written with the server's time, read back,
// and the difference from this phone's clock (about the round trip's
// middle) kept, so a start time means the same moment on both phones.
//
// Screens never wait on these writes (the author, 2026-10-21: LEAVE "froze
// for a bit"). Firestore has a write on this phone at once — the room's
// snapshots show it straight away, and the screens follow those — and
// sends it when it can. A screen starts a write with [later] (or makes a
// room with [hostNow]) and goes on; only a refusal comes back, as a notice
// wherever the player is by then. Being offline is not a refusal: the
// write waits in Firestore and goes when the phone is back.

import 'dart:async';

import 'package:alchemons/games/cosmic/battle_wire.dart';
import 'package:alchemons/models/battle_room.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/services/friend_service.dart';
import 'package:alchemons/widgets/game_snack.dart' show showGameSnackAnywhere;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BattleRoomException implements Exception {
  const BattleRoomException(this.message, {this.offline = false});
  final String message;

  /// Only not sent yet: Firestore still has it, and sends it when it can.
  final bool offline;

  @override
  String toString() => message;
}

class BattleRoomService extends ChangeNotifier {
  BattleRoomService({
    required this.account,
    required this.friends,
    FirebaseFirestore? firestore,
    DateTime Function()? now,
  }) : _firestore = firestore,
       _now = now ?? DateTime.now {
    account.addListener(_restart);
    friends.addListener(_restart);
    _restart();
  }

  final AccountService account;
  final FriendService friends;
  FirebaseFirestore? _firestore;
  final DateTime Function() _now;

  FirebaseFirestore get _fs => _firestore ??= FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _rooms =>
      _fs.collection('battle_rooms');
  CollectionReference<Map<String, dynamic>> _stream(String roomId) =>
      _rooms.doc(roomId).collection('stream');

  String? _uid;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  List<BattleRoom> _known = const [];
  Set<String> _dismissed = const {};
  bool _disposed = false;

  /// The server's clock less this phone's, in milliseconds.
  int _offsetMs = 0;

  /// Signed in, with a friend code (so with friends to battle).
  bool get available => friends.available && friends.code != null;

  String? get me => _uid;

  /// Rooms this player has been asked into and not joined, newest first.
  List<BattleRoom> get invites {
    final me = _uid;
    if (me == null) return const [];
    final now = _now();
    return [
      for (final r in _known)
        if (r.host != me &&
            r.guest == me &&
            r.state == BattleRoomState.lobby &&
            !r.seats.containsKey(me) &&
            !_dismissed.contains(r.id) &&
            (r.createdAt == null ||
                now.difference(r.createdAt!) < kBattleInviteLife))
          r,
    ]..sort((a, b) => (b.createdAt ?? now).compareTo(a.createdAt ?? now));
  }

  // ── Listening ───────────────────────────────────────────────────────────

  void _restart() {
    final uid = available ? account.user?.uid : null;
    if (uid == _uid) return;
    _uid = uid;
    unawaited(_sub?.cancel());
    _sub = null;
    _known = const [];
    if (uid != null) {
      unawaited(_loadDismissed(uid));
      _sub = _rooms
          .where('players', arrayContains: uid)
          .snapshots()
          .listen(
            (snap) {
              if (_uid != uid || _disposed) return;
              _known = [
                for (final d in snap.docs)
                  if (_read(d) case final r?) r,
              ];
              notifyListeners();
            },
            onError: (Object e) {
              debugPrint('BattleRoomService: invitations stopped: $e');
            },
          );
    }
    if (!_disposed) notifyListeners();
  }

  static String _dismissedKey(String uid) => 'battle_rooms.dismissed.$uid';

  Future<void> _loadDismissed(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    if (_uid != uid) return;
    _dismissed = (prefs.getStringList(_dismissedKey(uid)) ?? const []).toSet();
    if (!_disposed) notifyListeners();
  }

  /// Says no to [room]'s invitation: it goes from this phone at once, and
  /// this player leaves the room, so the host sees them gone.
  Future<void> decline(BattleRoom room) async {
    await dismiss(room.id);
    try {
      await leave(room);
    } on BattleRoomException catch (e) {
      debugPrint('BattleRoomService: the host was not told: $e');
    }
  }

  /// Waves an invitation away.
  Future<void> dismiss(String roomId) async {
    final uid = _uid;
    if (uid == null) return;
    _dismissed = {..._dismissed, roomId};
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final keep = _dismissed.toList();
    await prefs.setStringList(
      _dismissedKey(uid),
      keep.length > 40 ? keep.sublist(keep.length - 40) : keep,
    );
  }

  BattleRoom? _read(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    final created = data?['createdAt'];
    return BattleRoom.fromJson(
      d.id,
      data,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }

  /// The room as it changes; null once it is gone.
  Stream<BattleRoom?> watch(String roomId) =>
      _rooms.doc(roomId).snapshots().map((d) => d.exists ? _read(d) : null);

  // ── The host ────────────────────────────────────────────────────────────

  String get _me {
    final uid = _uid;
    if (uid == null) throw const BattleRoomException('Sign in first.');
    return uid;
  }

  /// This player's name, as rooms show it.
  String get myName {
    final n = account.user?.displayName?.trim() ?? '';
    return _cut(n.isEmpty ? 'Alchemist' : n);
  }

  static String _cut(String name) =>
      name.length > 24 ? name.substring(0, 24) : name;

  /// Makes a room in [arena] with [invite] asked in; returns its id once
  /// the server has it.
  Future<String> host({required String arena, FriendCard? invite}) async {
    final doc = _rooms.doc();
    await _hostInto(doc, arena: arena, invite: invite);
    return doc.id;
  }

  /// [host], not waited on: the room's id at once, for its lobby to open on
  /// (it shows on this phone straight away); only a refusal is told,
  /// [onFailed]. Throws at once when not signed in.
  String hostNow({
    required String arena,
    FriendCard? invite,
    void Function(String message)? onFailed,
  }) {
    _me;
    final doc = _rooms.doc();
    later(_hostInto(doc, arena: arena, invite: invite), onFailed: onFailed);
    return doc.id;
  }

  Future<void> _hostInto(
    DocumentReference<Map<String, dynamic>> doc, {
    required String arena,
    FriendCard? invite,
  }) {
    final me = _me;
    final friend = invite?.uid == me ? null : invite;
    return _run(
      () => doc.set({
        'host': me,
        'guest': friend?.uid,
        'players': [me, ?friend?.uid],
        'names': {
          me: myName,
          if (friend != null) friend.uid: _cut(friend.name),
        },
        'arena': arena,
        'state': 'lobby',
        'run': 0,
        'seats': <String, Object?>{},
        'ready': <String, Object?>{},
        'startAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  /// Asks [friend] into [room] (the host, while nobody else is asked).
  Future<void> invite(BattleRoom room, FriendCard friend) async {
    final me = _me;
    if (room.host != me) throw const BattleRoomException('Only the host asks.');
    if (room.guest == friend.uid) return;
    if (room.guest != null) {
      throw const BattleRoomException('Someone is asked already.');
    }
    await _run(
      () => _rooms.doc(room.id).update({
        'guest': friend.uid,
        'players': [me, friend.uid],
        'names.${friend.uid}': _cut(friend.name),
        ..._goneSeats(room, keep: friend.uid),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  /// Takes the friend asked out of [room] (the host, between fights).
  Future<void> remove(BattleRoom room) async {
    final guest = room.guest;
    if (room.host != _me || guest == null) return;
    if (room.state != BattleRoomState.lobby) return;
    await _run(
      () => _rooms.doc(room.id).update({
        'guest': null,
        'players': [room.host],
        'seats.$guest': FieldValue.delete(),
        'ready.$guest': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  /// The arena the fights are held in (the host, between fights).
  Future<void> setArena(BattleRoom room, String arena) async {
    if (room.host != _me || room.state != BattleRoomState.lobby) return;
    await _run(
      () => _rooms.doc(room.id).update({
        'arena': arena,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  /// Starts the fight (the host): it begins [kBattleRoomLead] from now on
  /// the server's clock ([kBattleRematchLead] for a rematch); the last
  /// fight's inputs are cleared.
  Future<void> start(BattleRoom room) async {
    if (room.host != _me || !room.canStart) return;
    final lead = room.run == 0 ? kBattleRoomLead : kBattleRematchLead;
    final at = serverNowMs() + lead.inMilliseconds;
    await _run(
      () => _rooms.doc(room.id).update({
        'state': 'fighting',
        'run': room.run + 1,
        'startAt': at,
        'inputs': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  /// The fight [run] is over (the host): how it ended, and the room is
  /// back to gathering for the next. The seat of a friend who left during
  /// it (kept for the fight's sake) goes now.
  Future<void> finish(BattleRoom room, BattleRoomResult result) async {
    if (room.host != _me || room.state != BattleRoomState.fighting) return;
    await _run(
      () => _rooms.doc(room.id).update({
        'state': 'lobby',
        'startAt': null,
        'result': result.toJson(),
        ..._goneSeats(room),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  /// The seats and READY of any no longer in [room], to take away ([keep]
  /// stays).
  static Map<String, Object?> _goneSeats(BattleRoom room, {String? keep}) {
    bool gone(String uid) =>
        uid != room.host && uid != room.guest && uid != keep;
    return {
      for (final uid in room.seats.keys)
        if (gone(uid)) 'seats.$uid': FieldValue.delete(),
      for (final uid in room.ready.keys)
        if (gone(uid)) 'ready.$uid': FieldValue.delete(),
    };
  }

  // ── Everyone ────────────────────────────────────────────────────────────

  /// Takes this player's seat in [roomId] with [seat] (again, to change
  /// their four), and reads the server's clock while at it.
  Future<void> sit(String roomId, BattleSeat seat) async {
    final me = _me;
    final doc = _rooms.doc(roomId);
    final t0 = _now().millisecondsSinceEpoch;
    await _run(
      () => doc.update({
        'seats.$me': {...seat.toJson(), 'at': FieldValue.serverTimestamp()},
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
    final t1 = _now().millisecondsSinceEpoch;
    try {
      final snap = await doc
          .get(const GetOptions(source: Source.server))
          .timeout(_wait);
      final at = (snap.data()?['seats'] as Map?)?[me]?['at'];
      if (at is Timestamp) {
        _offsetMs = at.millisecondsSinceEpoch - (t0 + t1) ~/ 2;
      }
    } catch (e) {
      debugPrint('BattleRoomService: the server clock was not read: $e');
    }
  }

  /// READY (or not) for the next fight: the guest, between fights.
  Future<void> setReady(BattleRoom room, bool ready) async {
    final me = _me;
    if (room.host == me || room.state != BattleRoomState.lobby) return;
    await _run(
      () => _rooms.doc(room.id).update({
        'ready.$me': ready ? room.run : FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  /// Leaves [room]: the guest goes from it, giving up their seat (kept
  /// while a fight is on, for the host's sake: the host clears it after);
  /// the host closes it, and its stream with it, in one write (the stream's
  /// rules read the room, so they go with it rather than after it).
  Future<void> leave(BattleRoom room) async {
    final me = _me;
    final doc = _rooms.doc(room.id);
    if (room.host == me) {
      final batch = _fs.batch();
      for (var slot = 0; slot < kBattleStreamSlots; slot++) {
        batch.delete(_stream(room.id).doc('$slot'));
      }
      batch.delete(doc);
      await _run(batch.commit);
      return;
    }
    if (room.guest != me) return;
    final between = room.state == BattleRoomState.lobby;
    await _run(
      () => doc.update({
        'guest': null,
        'players': [room.host],
        if (between && room.seats.containsKey(me))
          'seats.$me': FieldValue.delete(),
        if (between && room.ready.containsKey(me))
          'ready.$me': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  // ── The fight ───────────────────────────────────────────────────────────

  /// The host's packet [seq] of fight [run], into the stream's next
  /// document. Not waited on: the next packet makes good a lost one.
  void sendPacket(String roomId, int run, int seq, List<int> packet) {
    final slot = seq % kBattleStreamSlots;
    unawaited(
      _stream(roomId)
          .doc('$slot')
          .set({'run': run, 'seq': seq, 'p': packet})
          .timeout(_wait)
          .catchError((Object e) {
            debugPrint('BattleRoomService: packet $seq not sent: $e');
          }),
    );
  }

  /// The host's packets of fight [run], as they come: (number, ints).
  Stream<(int, List<int>)> packets(String roomId, int run) =>
      _stream(roomId).snapshots().expand(
        (snap) => [
          for (final change in snap.docChanges)
            if (change.type != DocumentChangeType.removed)
              if (_packet(change.doc.data(), run) case final p?) p,
        ],
      );

  static (int, List<int>)? _packet(Map<String, dynamic>? data, int run) {
    if (data == null || data['run'] != run) return null;
    final seq = data['seq'], p = data['p'];
    if (seq is! num || p is! List) return null;
    return (
      seq.toInt(),
      [
        for (final v in p)
          if (v is num) v.toInt(),
      ],
    );
  }

  /// The guest's inputs in fight [run], all of them, and its [beat]. A
  /// write that fails is made good by the next.
  void sendInputs(String roomId, int run, List<BattleInput> inputs, int beat) {
    unawaited(
      _rooms
          .doc(roomId)
          .update({
            'inputs': {
              'run': run,
              'b': beat,
              'l': BattleInput.encodeAll(inputs),
            },
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(_wait)
          .catchError((Object e) {
            debugPrint('BattleRoomService: inputs not sent: $e');
          }),
    );
  }

  /// The server's clock now, as near as this phone can tell.
  int serverNowMs() => _now().millisecondsSinceEpoch + _offsetMs;

  /// [serverMs] on this phone's clock.
  int localMs(int serverMs) => serverMs - _offsetMs;

  // ── Writing ─────────────────────────────────────────────────────────────

  static const Duration _wait = Duration(seconds: 20);

  /// [write], not waited on by whoever started it: only a refusal is told
  /// ([onFailed]; by default a notice wherever the player is). Offline is
  /// not one — Firestore keeps the write and sends it later.
  void later(Future<void> write, {void Function(String message)? onFailed}) {
    unawaited(
      write.then<void>(
        (_) {},
        onError: (Object e) {
          debugPrint('BattleRoomService: a write was not made: $e');
          if (e is! BattleRoomException || e.offline) return;
          (onFailed ?? showGameSnackAnywhere)(e.message);
        },
      ),
    );
  }

  Future<void> _run(Future<void> Function() write) async {
    try {
      await write().timeout(_wait);
    } on FirebaseException catch (e) {
      throw BattleRoomException(switch (e.code) {
        'unavailable' => 'You are offline.',
        'permission-denied' => 'That is not allowed.',
        'not-found' => 'That battle is over.',
        _ => 'Something went wrong (${e.code}).',
      }, offline: e.code == 'unavailable');
    } on TimeoutException {
      throw const BattleRoomException('You are offline.', offline: true);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    account.removeListener(_restart);
    friends.removeListener(_restart);
    super.dispose();
  }
}
