// lib/services/friend_service.dart
//
// Friends, for players who sign in: the game is whole without them.
//
// A player gets a friend code the first time they open FRIENDS on their
// profile. Someone who enters it sends them a request; once they accept,
// each can see the other's home planet and visit the home biome under it.
// Either can remove the other, block them, or report them.
//
// What a friend sees is published here from the player's own save whenever
// it may have changed (signing in, coming back up from the home biome,
// opening FRIENDS), and only when it has: the planet and name in
// players/{uid}, the home biome in homes/{uid} (lib/models/friend_home.dart).
// Only friends can read either (firestore.rules). Nothing is published for a
// player who has never opened FRIENDS, nor from a game that belongs to
// another account (SaveGenerationService).
//
// Firestore:
//   friend_codes/{CODE}            {uid, createdAt}
//   players/{uid}                  {name, faction, code, planet, title?,
//                                   featured?, updatedAt}
//   players/{uid}/friends/{uid}    {since}       — one each side
//   players/{uid}/blocked/{uid}    {at}
//   homes/{uid}                    {v, home, updatedAt}
//   friend_requests/{from}_{to}    {from, to, fromName, fromFaction, toCode,
//                                   createdAt}
//   reports/{auto}                 {from, about, reason, createdAt}

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/models/profile_titles.dart';
import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/services/cosmetic_wear_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/save_generation_service.dart';
import 'package:alchemons/utils/featured_instance.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FriendException implements Exception {
  const FriendException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// A request waiting on one side or the other.
class FriendRequest {
  const FriendRequest({
    required this.from,
    required this.to,
    required this.fromName,
    this.fromFaction,
    this.toCode,
  });

  final String from, to, fromName;
  final String? fromFaction;

  /// The code it was sent to, shown to the sender while it waits.
  final String? toCode;

  String get id => '${from}_$to';

  static FriendRequest? fromDoc(Map<String, dynamic> d) {
    final from = d['from'], to = d['to'];
    if (from is! String || to is! String) return null;
    final name = d['fromName'];
    return FriendRequest(
      from: from,
      to: to,
      fromName: name is String && name.trim().isNotEmpty
          ? name.trim()
          : 'Alchemist',
      fromFaction: d['fromFaction'] is String
          ? d['fromFaction'] as String
          : null,
      toCode: d['toCode'] is String ? d['toCode'] as String : null,
    );
  }
}

/// What a report is about.
enum FriendReportReason {
  name('name', 'Their name'),
  home('home', 'Their home'),
  other('other', 'Something else');

  const FriendReportReason(this.id, this.label);
  final String id;
  final String label;
}

/// Friend codes: eight characters with nothing that reads as something else
/// (no I, L, O, 0 or 1).
abstract final class FriendCode {
  static const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const length = 8;

  static String random([math.Random? rng]) {
    final r = rng ?? math.Random.secure();
    return String.fromCharCodes([
      for (var i = 0; i < length; i++)
        alphabet.codeUnitAt(r.nextInt(alphabet.length)),
    ]);
  }

  /// [input] as a code (upper case, spaces and dashes dropped), or null when
  /// it cannot be one.
  static String? normalize(String input) {
    final s = input.toUpperCase().replaceAll(RegExp(r'[\s\-_.]'), '');
    if (s.length != length) return null;
    for (final c in s.codeUnits) {
      if (!alphabet.codeUnits.contains(c)) return null;
    }
    return s;
  }

  /// ABCD-EFGH.
  static String pretty(String code) => code.length == length
      ? '${code.substring(0, 4)}-${code.substring(4)}'
      : code;
}

/// A stable 64-bit FNV-1a of [s], hex: what was last published, compared
/// without keeping it.
String publishHash(String s) {
  var h = BigInt.parse('cbf29ce484222325', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  final mask = (BigInt.one << 64) - BigInt.one;
  for (final b in utf8.encode(s)) {
    h = ((h ^ BigInt.from(b)) * prime) & mask;
  }
  return h.toRadixString(16);
}

class FriendService extends ChangeNotifier {
  FriendService({
    required this.account,
    required this.db,
    this.wear,
    this.factions,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore {
    account.addListener(_onAccount);
    _onAccount();
    // A new title or featured Alchemon goes out to friends a moment later
    // (publishIfChanged writes only what changed).
    for (final key in [kFeaturedInstanceSettingKey, ProfileTitles.settingKey]) {
      _settingSubs.add(
        db.settingsDao.watchSetting(key).skip(1).listen((_) => publishSoon()),
      );
    }
  }

  final AccountService account;
  final AlchemonsDatabase db;
  final CosmeticWearService? wear;
  final FactionService? factions;
  FirebaseFirestore? _firestore;

  /// How many friends one player can have.
  static const int maxFriends = 100;

  String? _uid;
  String? _code;
  List<FriendCard> _friends = const [];
  List<FriendRequest> _incoming = const [];
  List<FriendRequest> _outgoing = const [];
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  Timer? _publishTimer;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _incomingSub;
  final List<StreamSubscription<String?>> _settingSubs = [];
  bool _publishing = false;
  bool _disposed = false;

  /// Signed in with an account that can use friends.
  bool get available =>
      account.initialized && account.isConfigured && account.isSignedIn;

  /// This player's code, once they have one (ABCD-EFGH).
  String? get code => _code == null ? null : FriendCode.pretty(_code!);

  List<FriendCard> get friends => _friends;
  List<FriendRequest> get incoming => _incoming;
  List<FriendRequest> get outgoing => _outgoing;
  bool get loading => _loading;

  /// The lists have been read at least once since signing in.
  bool get loaded => _loaded;

  /// Why the last refresh failed, if it did.
  String? get error => _error;

  FirebaseFirestore get _fs => _firestore ??= FirebaseFirestore.instance;

  String get _me {
    final uid = account.user?.uid;
    if (uid == null) throw const FriendException('Sign in first.');
    return uid;
  }

  DocumentReference<Map<String, dynamic>> _player(String uid) =>
      _fs.collection('players').doc(uid);
  CollectionReference<Map<String, dynamic>> _friendsOf(String uid) =>
      _player(uid).collection('friends');
  CollectionReference<Map<String, dynamic>> _blockedBy(String uid) =>
      _player(uid).collection('blocked');
  DocumentReference<Map<String, dynamic>> _home(String uid) =>
      _fs.collection('homes').doc(uid);
  CollectionReference<Map<String, dynamic>> get _requests =>
      _fs.collection('friend_requests');
  DocumentReference<Map<String, dynamic>> _codeDoc(String code) =>
      _fs.collection('friend_codes').doc(code);

  // ── The account ─────────────────────────────────────────────────────────

  void _onAccount() {
    final uid = available ? account.user?.uid : null;
    if (uid == _uid) return;
    _uid = uid;
    _code = null;
    _friends = const [];
    _incoming = const [];
    _outgoing = const [];
    _loaded = false;
    _error = null;
    _publishTimer?.cancel();
    _incomingSub?.cancel();
    _incomingSub = null;
    if (uid != null) {
      unawaited(_listenIfKnown(uid));
      // Once the game has settled after starting: anything changed while
      // signed out (or on another build) goes out — for a player who has
      // opened FRIENDS on this device (their code is kept here), so the
      // rest cost nothing.
      _publishTimer = Timer(const Duration(seconds: 12), () async {
        try {
          final prefs = await SharedPreferences.getInstance();
          final kept = prefs.getString(_codeKey(uid));
          if (kept == null || _uid != uid) return;
          _code ??= kept;
          await publishIfChanged();
        } catch (e) {
          debugPrint('FriendService: startup publish skipped: $e');
        }
      });
    }
    if (!_disposed) notifyListeners();
  }

  static String _codeKey(String uid) => 'friends.code.$uid';

  /// Reads this player's code, if they have one: the one kept here, else
  /// the published one (kept here from then on). Kept first, so a player
  /// whose profile is not published (another account's game on this
  /// device) is not handed a new code every time.
  Future<void> _loadCode() async {
    final me = _me;
    final prefs = await SharedPreferences.getInstance();
    final kept = prefs.getString(_codeKey(me));
    if (kept != null && FriendCode.normalize(kept) == kept) {
      _code = kept;
      return;
    }
    final snap = await _player(me).get().timeout(_wait);
    final code = snap.data()?['code'];
    if (code is String && FriendCode.normalize(code) == code) {
      await _keepCode(me, code);
    }
  }

  Future<void> _keepCode(String uid, String code) async {
    _code = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_codeKey(uid), code);
  }

  /// Makes this player a code if they have none yet.
  Future<void> _ensureCode() async {
    if (_code != null) return;
    await _loadCode();
    if (_code != null) return;
    final me = _me;
    for (var attempt = 0; attempt < 6; attempt++) {
      final code = FriendCode.random();
      try {
        // Taken codes refuse: the rules only let a code be created.
        await _codeDoc(code)
            .set({'uid': me, 'createdAt': FieldValue.serverTimestamp()})
            .timeout(_wait);
        await _keepCode(me, code);
        await publishIfChanged(force: true);
        return;
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
      } on TimeoutException {
        throw const FriendException('You are offline.');
      }
    }
    throw const FriendException('Could not make a friend code. Try again.');
  }

  /// Whether a request is waiting for this player to answer: the home
  /// screen's profile button wears a dot while one is.
  bool get hasRequests => _incoming.isNotEmpty;

  /// For a player who has opened FRIENDS on this device (their code is kept
  /// here), listens for requests from the start, so the dot shows without
  /// opening the profile. No one else can be sent one.
  Future<void> _listenIfKnown(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final kept = prefs.getString(_codeKey(uid));
      if (kept == null || _uid != uid || _disposed) return;
      _code ??= kept;
      _listenIncoming(uid);
    } catch (e) {
      debugPrint('FriendService: not listening for requests: $e');
    }
  }

  /// Keeps [incoming] live while [uid] is signed in.
  void _listenIncoming(String uid) {
    if (_incomingSub != null || _uid != uid || _disposed) return;
    _incomingSub = _requests
        .where('to', isEqualTo: uid)
        .snapshots()
        .listen(
          (snap) {
            if (_uid != uid || _disposed) return;
            final friendIds = {for (final f in _friends) f.uid};
            _incoming = [
              for (final d in snap.docs)
                if (FriendRequest.fromDoc(d.data()) case final r?)
                  if (!friendIds.contains(r.from)) r,
            ];
            notifyListeners();
          },
          onError: (Object e) {
            debugPrint('FriendService: request listener stopped: $e');
            _incomingSub = null;
          },
        );
  }

  // ── Reading ─────────────────────────────────────────────────────────────

  /// Reads the code, friends and requests, making a code if this is the
  /// first time, and publishes anything changed.
  Future<void> refresh() async {
    if (!available || _loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _ensureCode();
      _listenIncoming(_me);
      final me = _me;
      final results = await Future.wait([
        _friendsOf(me).get(),
        _requests.where('to', isEqualTo: me).get(),
        _requests.where('from', isEqualTo: me).get(),
      ]).timeout(_wait);
      final ids = [for (final d in results[0].docs) d.id];
      final cards = await Future.wait(ids.map(_card));
      _friends = [...cards.whereType<FriendCard>()]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      final friendIds = {for (final f in _friends) f.uid};
      _incoming = [
        for (final d in results[1].docs)
          if (FriendRequest.fromDoc(d.data()) case final r?)
            if (!friendIds.contains(r.from)) r,
      ];
      _outgoing = [
        for (final d in results[2].docs)
          if (FriendRequest.fromDoc(d.data()) case final r?)
            if (!friendIds.contains(r.to)) r,
      ];
      _loaded = true;
      unawaited(publishIfChanged());
    } on FriendException catch (e) {
      _error = e.message;
    } on FirebaseException catch (e) {
      _error = _friendly(e);
    } on TimeoutException {
      _error = 'You are offline.';
    } catch (e) {
      _error = 'Friends could not load.';
      debugPrint('FriendService.refresh: $e');
    } finally {
      _loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<FriendCard?> _card(String uid) async {
    try {
      final snap = await _player(uid).get();
      return FriendCard.fromJson(uid, snap.data());
    } on FirebaseException {
      // A friendship only one side of which survived: shown nameless, so
      // it can still be removed.
      return FriendCard(uid: uid, name: 'Alchemist');
    }
  }

  /// [uid]'s home biome, or null when they have not published one.
  Future<FriendHome?> fetchHome(String uid) async {
    try {
      final snap = await _home(uid).get().timeout(_wait);
      final raw = snap.data()?['home'];
      return FriendHome.decode(raw is String ? raw : null);
    } on FirebaseException catch (e) {
      throw FriendException(_friendly(e));
    } on TimeoutException {
      throw const FriendException('You are offline.');
    }
  }

  // ── Requests ────────────────────────────────────────────────────────────

  /// Sends a request to whoever has [input] as their code. Returns what
  /// happened, to tell the player.
  Future<String> sendRequest(String input) async {
    final me = _me;
    final code = FriendCode.normalize(input);
    if (code == null) {
      throw const FriendException('That is not a friend code.');
    }
    if (code == _code) {
      throw const FriendException('That is your own code.');
    }
    try {
      final snap = await _codeDoc(code).get().timeout(_wait);
      final them = snap.data()?['uid'];
      if (them is! String || them.isEmpty) {
        throw const FriendException('No one has that code.');
      }
      if (them == me) throw const FriendException('That is your own code.');
      if (_friends.any((f) => f.uid == them)) {
        throw const FriendException('You are already friends.');
      }
      // They asked first: that is an answer.
      final theirs = _incoming.where((r) => r.from == them).firstOrNull;
      if (theirs != null) {
        await accept(theirs);
        return 'You and ${theirs.fromName} are now friends.';
      }
      if (_outgoing.any((r) => r.to == them)) {
        throw const FriendException('Your request is already waiting.');
      }
      if (_friends.length >= maxFriends) {
        throw const FriendException('Your friends list is full.');
      }
      try {
        await _requests
            .doc('${me}_$them')
            .set({
              'from': me,
              'to': them,
              'fromName': _name,
              'fromFaction': factions?.current?.name,
              'toCode': code,
              'createdAt': FieldValue.serverTimestamp(),
            })
            .timeout(_wait);
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          throw const FriendException('The request could not be sent.');
        }
        rethrow;
      }
      await refresh();
      return 'Request sent.';
    } on FirebaseException catch (e) {
      throw FriendException(_friendly(e));
    } on TimeoutException {
      throw const FriendException('You are offline.');
    }
  }

  /// Accepts [r]: each side is written into the other's friends, and the
  /// request goes.
  Future<void> accept(FriendRequest r) async {
    final me = _me;
    if (r.to != me) return;
    if (_friends.length >= maxFriends) {
      throw const FriendException('Your friends list is full.');
    }
    await _run(() async {
      final since = {'since': FieldValue.serverTimestamp()};
      await (_fs.batch()
            ..set(_friendsOf(me).doc(r.from), since)
            ..set(_friendsOf(r.from).doc(me), since)
            ..delete(_requests.doc(r.id)))
          .commit();
    });
    await refresh();
  }

  /// Declines [r] if it came to this player, or takes it back if they sent
  /// it.
  Future<void> dismiss(FriendRequest r) async {
    await _run(() => _requests.doc(r.id).delete());
    _incoming = [..._incoming.where((o) => o.id != r.id)];
    _outgoing = [..._outgoing.where((o) => o.id != r.id)];
    notifyListeners();
  }

  // ── Friends ─────────────────────────────────────────────────────────────

  /// No longer friends, on either side.
  Future<void> remove(String uid) async {
    final me = _me;
    await _run(
      () =>
          (_fs.batch()
                ..delete(_friendsOf(me).doc(uid))
                ..delete(_friendsOf(uid).doc(me)))
              .commit(),
    );
    _friends = [..._friends.where((f) => f.uid != uid)];
    notifyListeners();
  }

  /// Removed, and no request from them reaches this player again.
  Future<void> block(String uid) async {
    final me = _me;
    await _run(() async {
      final batch = _fs.batch()
        ..delete(_friendsOf(me).doc(uid))
        ..delete(_friendsOf(uid).doc(me))
        ..set(_blockedBy(me).doc(uid), {'at': FieldValue.serverTimestamp()});
      // Requests either way, those known to stand (the rules refuse
      // deleting one that does not).
      for (final r in [..._incoming, ..._outgoing]) {
        if (r.from == uid || r.to == uid) batch.delete(_requests.doc(r.id));
      }
      await batch.commit();
    });
    _friends = [..._friends.where((f) => f.uid != uid)];
    _incoming = [..._incoming.where((r) => r.from != uid)];
    _outgoing = [..._outgoing.where((r) => r.to != uid)];
    notifyListeners();
  }

  /// Tells us about [uid]: kept for review, never shown to them.
  Future<void> report(String uid, FriendReportReason reason) async {
    final me = _me;
    await _run(
      () => _fs.collection('reports').add({
        'from': me,
        'about': uid,
        'reason': reason.id,
        'createdAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  // ── Publishing ──────────────────────────────────────────────────────────

  /// Publishes in a moment (calls close together go out once).
  void publishSoon() {
    if (!available) return;
    _publishTimer?.cancel();
    _publishTimer = Timer(const Duration(seconds: 2), () {
      unawaited(
        publishIfChanged().catchError((Object e) {
          debugPrint('FriendService.publishSoon: $e');
        }),
      );
    });
  }

  String get _name {
    final n = account.user?.displayName?.trim() ?? '';
    final name = n.isEmpty ? 'Alchemist' : n;
    return name.length > 24 ? name.substring(0, 24) : name;
  }

  /// Publishes this player's planet and home if either changed since they
  /// were last published from this device. Nothing before they have a code,
  /// nor from a game another account owns.
  Future<void> publishIfChanged({bool force = false}) async {
    if (!available || _publishing) return;
    final me = account.user?.uid;
    final code = _code;
    if (me == null || code == null) return;
    final owner = await SaveGenerationService.owner(db);
    if (owner != null && owner != me) return;
    _publishing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final planet = PlanetLook.read(prefs);
      final worn = (await ProfileTitles.load(db)).worn;
      final title = worn == null ? null : ProfileTitles.nameOf(worn);
      final featured = await loadFeaturedInstance(db);
      final player = <String, dynamic>{
        'name': _name,
        'faction': factions?.current?.name,
        'code': code,
        'planet': planet?.toJson(),
        if (title != null && title.length <= FriendCard.maxTitleLength)
          'title': title,
        if (featured != null)
          'featured': ResidentLook.of(
            featured,
            trail: wear?.trailOf(featured.instanceId)?.id,
          ).toJson(),
      };
      final home = (await FriendHome.capture(
        db,
        trailOf: (id) => wear?.trailOf(id)?.id,
        ambienceIn: (realm) => wear?.ambienceIn(realm)?.id,
      )).encode();
      final playerKey = 'friends.published.$me.player';
      final homeKey = 'friends.published.$me.home';
      final playerHash = publishHash(jsonEncode(player));
      final homeHash = publishHash(home);
      if (force || prefs.getString(playerKey) != playerHash) {
        await _player(
          me,
        ).set({...player, 'updatedAt': FieldValue.serverTimestamp()});
        await prefs.setString(playerKey, playerHash);
      }
      if (force || prefs.getString(homeKey) != homeHash) {
        await _home(me).set({
          'v': FriendHome.version,
          'home': home,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await prefs.setString(homeKey, homeHash);
      }
    } finally {
      _publishing = false;
    }
  }

  // ── Leaving ─────────────────────────────────────────────────────────────

  /// Takes everything this player published down, and them out of every
  /// friend's list: run before their account is deleted, while they can
  /// still write.
  Future<void> forget() async {
    final me = _me;
    final refs = <DocumentReference<Map<String, dynamic>>>[];
    final friends = await _friendsOf(me).get();
    for (final d in friends.docs) {
      refs
        ..add(d.reference)
        ..add(_friendsOf(d.id).doc(me));
    }
    final blocked = await _blockedBy(me).get();
    refs.addAll(blocked.docs.map((d) => d.reference));
    for (final field in ['from', 'to']) {
      final q = await _requests.where(field, isEqualTo: me).get();
      refs.addAll(q.docs.map((d) => d.reference));
    }
    final player = await _player(me).get();
    final code = player.data()?['code'];
    if (code is String && code.isNotEmpty) refs.add(_codeDoc(code));
    refs
      ..add(_home(me))
      ..add(_player(me));
    for (var i = 0; i < refs.length; i += 400) {
      final batch = _fs.batch();
      for (final r in refs.skip(i).take(400)) {
        batch.delete(r);
      }
      await batch.commit();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('friends.published.$me.player');
    await prefs.remove('friends.published.$me.home');
    await prefs.remove(_codeKey(me));
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// How long a read or write is waited on: Firestore holds a write made
  /// offline until it is back online, and would leave the player waiting.
  static const Duration _wait = Duration(seconds: 20);

  Future<void> _run(Future<void> Function() write) async {
    try {
      await write().timeout(_wait);
    } on FirebaseException catch (e) {
      throw FriendException(_friendly(e));
    } on TimeoutException {
      throw const FriendException('You are offline.');
    }
  }

  static String _friendly(FirebaseException e) => switch (e.code) {
    'unavailable' => 'You are offline.',
    'permission-denied' => 'That is not allowed.',
    'not-found' => 'They could not be found.',
    _ => 'Something went wrong (${e.code}).',
  };

  @override
  void dispose() {
    _disposed = true;
    _incomingSub?.cancel();
    for (final s in _settingSubs) {
      s.cancel();
    }
    _publishTimer?.cancel();
    account.removeListener(_onAccount);
    super.dispose();
  }
}
