// lib/services/race_room_service.dart
//
// Live races with friends, the Firestore side: `race_rooms/{id}`. The host
// makes a room for one course and asks friends in; each who joins writes
// their racer (as numbers, race_room.dart) into their own seat; the host
// starts it with a gun time on the server's clock; each phone then writes
// only its own boost taps, as ticks, and runs the same race as the rest.
//
// The server's clock: a seat is written with the server's time, read back,
// and the difference from this phone's clock (about the round trip's
// middle) kept — so a gun time means the same moment on every phone.

import 'dart:async';

import 'package:alchemons/games/stadium/race_room.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/services/friend_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RaceRoomException implements Exception {
  const RaceRoomException(this.message);
  final String message;

  @override
  String toString() => message;
}

class RaceRoomService extends ChangeNotifier {
  RaceRoomService({
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
      _fs.collection('race_rooms');

  String? _uid;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  List<RaceRoom> _asked = const [];
  Set<String> _dismissed = const {};
  bool _disposed = false;

  /// The server's clock less this phone's, in milliseconds.
  int _offsetMs = 0;

  /// Signed in, with a friend code (so with friends to race).
  bool get available => friends.available && friends.code != null;

  String? get me => _uid;

  /// Rooms this player has been asked into and not joined, newest first:
  /// still gathering, not too old, not waved away.
  List<RaceRoom> get invites {
    final me = _uid;
    if (me == null) return const [];
    final now = _now();
    return [
      for (final r in _asked)
        if (r.host != me &&
            r.state == RaceRoomState.lobby &&
            !r.seats.containsKey(me) &&
            !_dismissed.contains(r.id) &&
            (r.createdAt == null ||
                now.difference(r.createdAt!) < kRaceInviteLife))
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
    _asked = const [];
    if (uid != null) {
      unawaited(_loadDismissed(uid));
      _sub = _rooms
          .where('invited', arrayContains: uid)
          .snapshots()
          .listen(
            (snap) {
              if (_uid != uid || _disposed) return;
              _asked = [
                for (final d in snap.docs)
                  if (_read(d) case final r?) r,
              ];
              notifyListeners();
            },
            onError: (Object e) {
              debugPrint('RaceRoomService: invitations stopped: $e');
            },
          );
    }
    if (!_disposed) notifyListeners();
  }

  static String _dismissedKey(String uid) => 'race_rooms.dismissed.$uid';

  Future<void> _loadDismissed(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    if (_uid != uid) return;
    _dismissed = (prefs.getStringList(_dismissedKey(uid)) ?? const []).toSet();
    if (!_disposed) notifyListeners();
  }

  /// Says no to [room]'s invitation: it goes from this phone at once, and
  /// this player leaves the room's list, so the host sees the lane free.
  Future<void> decline(RaceRoom room) async {
    await dismiss(room.id);
    try {
      await leave(room);
    } on RaceRoomException catch (e) {
      debugPrint('RaceRoomService: the host was not told: $e');
    }
  }

  /// Waves an invitation away.
  Future<void> dismiss(String roomId) async {
    final uid = _uid;
    if (uid == null) return;
    _dismissed = {..._dismissed, roomId};
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    // The newest few are enough: older invitations have run out anyway.
    final keep = _dismissed.toList();
    await prefs.setStringList(
      _dismissedKey(uid),
      keep.length > 40 ? keep.sublist(keep.length - 40) : keep,
    );
  }

  RaceRoom? _read(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    final created = data?['createdAt'];
    return RaceRoom.fromJson(
      d.id,
      data,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }

  /// The room as it changes; null once it is gone.
  Stream<RaceRoom?> watch(String roomId) =>
      _rooms.doc(roomId).snapshots().map((d) => d.exists ? _read(d) : null);

  // ── The host ────────────────────────────────────────────────────────────

  String get _me {
    final uid = _uid;
    if (uid == null) throw const RaceRoomException('Sign in first.');
    return uid;
  }

  /// This player's name, as rooms show it.
  String get myName {
    final n = account.user?.displayName?.trim() ?? '';
    final name = n.isEmpty ? 'Alchemist' : n;
    return name.length > 24 ? name.substring(0, 24) : name;
  }

  static String _cut(String name) =>
      name.length > 24 ? name.substring(0, 24) : name;

  /// Makes a room for [cup]'s race [race] (with [gem], a gem cup's bout)
  /// with [invite] asked in; returns its id.
  Future<String> host({
    required int cup,
    required int race,
    bool gem = false,
    List<FriendCard> invite = const [],
  }) async {
    final me = _me;
    final asked = invite.where((f) => f.uid != me).take(kRaceRoomSeats - 1);
    final doc = _rooms.doc();
    await _run(
      () => doc.set({
        'host': me,
        'invited': [me, for (final f in asked) f.uid],
        'names': {me: myName, for (final f in asked) f.uid: _cut(f.name)},
        'cup': cup,
        'race': race,
        if (gem) 'ev': 'gem',
        'state': 'lobby',
        'run': 0,
        'seats': <String, Object?>{},
        'taps': <String, Object?>{},
        'field': <String>[],
        'startAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
    return doc.id;
  }

  /// Asks [friend] into [room] (the host only), while there is a lane.
  Future<void> invite(RaceRoom room, FriendCard friend) async {
    final me = _me;
    if (room.host != me) throw const RaceRoomException('Only the host asks.');
    if (room.invited.contains(friend.uid)) return;
    if (room.invited.length >= kRaceRoomSeats) {
      throw const RaceRoomException('Every lane is taken.');
    }
    await _run(
      () => _rooms.doc(room.id).update({
        'invited': [...room.invited, friend.uid],
        'names.${friend.uid}': _cut(friend.name),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  /// Sets the course — with [gem], a gem cup's bout (the host, between
  /// races).
  Future<void> setCourse(
    RaceRoom room,
    int cup,
    int race, {
    bool gem = false,
  }) async {
    if (room.host != _me || room.state != RaceRoomState.lobby) return;
    await _run(
      () => _rooms.doc(room.id).update({
        'ev': gem ? 'gem' : 'race',
        'cup': cup,
        'race': race,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  /// Takes [uid] out of [room] (the host, between races): a friend asked
  /// who has not come, or one in who keeps the rest waiting. Their lane
  /// goes back to the computer.
  Future<void> remove(RaceRoom room, String uid) async {
    if (room.host != _me || uid == room.host) return;
    if (room.state != RaceRoomState.lobby) return;
    await _run(
      () => _rooms.doc(room.id).update({
        'invited': FieldValue.arrayRemove([uid]),
        'seats.$uid': FieldValue.delete(),
        'ready.$uid': FieldValue.delete(),
        'plans.$uid': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  /// How many computer racers may fill the lanes the players leave (the
  /// host, between races).
  Future<void> setComputers(RaceRoom room, int count) async {
    if (room.host != _me || room.state != RaceRoomState.lobby) return;
    await _run(
      () => _rooms.doc(room.id).update({
        'cpu': count.clamp(0, kRaceRoomSeats - 1),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  /// Starts the race (the host): the gun goes [kRaceRoomLead] from now on
  /// the server's clock, and the taps of the last race are cleared.
  Future<void> start(RaceRoom room) async {
    if (room.host != _me || !room.canStart) return;
    final gun = serverNowMs() + kRaceRoomLead.inMilliseconds;
    await _run(
      () => _rooms.doc(room.id).update({
        'state': 'racing',
        'run': room.run + 1,
        'startAt': gun,
        'field': [for (final s in room.racing.take(kRaceRoomSeats)) s.uid],
        'taps': <String, Object?>{},
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  /// Back to gathering after a race (the host). The seats of any who left
  /// during it (kept for the race's sake) go now.
  Future<void> backToLobby(RaceRoom room) async {
    if (room.host != _me || room.state == RaceRoomState.lobby) return;
    await _run(
      () => _rooms.doc(room.id).update({
        'state': 'lobby',
        'startAt': null,
        'field': <String>[],
        for (final uid in room.seats.keys)
          if (!room.invited.contains(uid)) 'seats.$uid': FieldValue.delete(),
        for (final uid in room.ready.keys)
          if (!room.invited.contains(uid)) 'ready.$uid': FieldValue.delete(),
        for (final uid in room.plans.keys)
          if (!room.invited.contains(uid)) 'plans.$uid': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  // ── Everyone ────────────────────────────────────────────────────────────

  /// Takes this player's seat in [roomId] with [seat] (again, to change
  /// racer), and reads the server's clock while at it.
  Future<void> sit(String roomId, RaceSeat seat) async {
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
      debugPrint('RaceRoomService: the server clock was not read: $e');
    }
  }

  /// READY (or not) for the next race, between races; on the space course
  /// with the [plan]ned route.
  Future<void> setReady(RaceRoom room, bool ready, {List<int>? plan}) async {
    final me = _me;
    if (room.host == me || room.state != RaceRoomState.lobby) return;
    await _run(
      () => _rooms.doc(room.id).update({
        'ready.$me': ready ? room.run : FieldValue.delete(),
        if (ready && plan != null) 'plans.$me': _plan(room, plan),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  /// This player's route through the space course, between races (the
  /// host's, before START).
  Future<void> setPlan(RaceRoom room, List<int> plan) async {
    final me = _me;
    if (room.state != RaceRoomState.lobby) return;
    await _run(
      () => _rooms.doc(room.id).update({
        'plans.$me': _plan(room, plan),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  static Map<String, Object?> _plan(RaceRoom room, List<int> plan) =>
      RacePlan(run: room.run, at: room.placeKey, route: plan).toJson();

  /// Leaves [room]: a player goes from its list and gives up their seat
  /// (kept while a race is on, so the phones still loading it can draw
  /// them — the host clears it after); the host closes it.
  Future<void> leave(RaceRoom room) async {
    final me = _me;
    final doc = _rooms.doc(room.id);
    if (room.host == me) {
      await _run(() => doc.delete());
      return;
    }
    final between = room.state == RaceRoomState.lobby;
    await _run(
      () => doc.update({
        'invited': FieldValue.arrayRemove([me]),
        if (between && room.seats.containsKey(me))
          'seats.$me': FieldValue.delete(),
        if (between && room.ready.containsKey(me))
          'ready.$me': FieldValue.delete(),
        if (between && room.plans.containsKey(me))
          'plans.$me': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  /// This player's taps in [room]'s race so far, all of them each time (a
  /// write that fails is made good by the next).
  Future<void> sendTaps(RaceRoom room, List<int> ticks) async {
    final me = _me;
    try {
      await _run(
        () => _rooms.doc(room.id).update({
          'taps.$me': {'run': room.run, 't': ticks},
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      );
    } on RaceRoomException catch (e) {
      debugPrint('RaceRoomService: taps not sent: $e');
    }
  }

  /// The server's clock now, as near as this phone can tell.
  int serverNowMs() => _now().millisecondsSinceEpoch + _offsetMs;

  /// [serverMs] on this phone's clock.
  int localMs(int serverMs) => serverMs - _offsetMs;

  // ── Writing ─────────────────────────────────────────────────────────────

  static const Duration _wait = Duration(seconds: 20);

  Future<void> _run(Future<void> Function() write) async {
    try {
      await write().timeout(_wait);
    } on FirebaseException catch (e) {
      throw RaceRoomException(switch (e.code) {
        'unavailable' => 'You are offline.',
        'permission-denied' => 'That is not allowed.',
        'not-found' => 'That race is over.',
        _ => 'Something went wrong (${e.code}).',
      });
    } on TimeoutException {
      throw const RaceRoomException('You are offline.');
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
