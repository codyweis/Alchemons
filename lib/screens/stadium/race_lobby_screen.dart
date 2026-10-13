// lib/screens/stadium/race_lobby_screen.dart
//
// Racing friends, before the gun (the author, 2026-10-12: "race vs
// friends", live, invited while they are online). The lobby of one room:
// the course (the host steps through the ones they have opened), the six
// lanes — the players who have joined with their racers, the friends asked
// and not yet in, the cup's computer rivals in the rest (the host takes
// any lane out, and puts a computer back in an open one) — your own racer
// to change, a player's READY and LEAVE, and the host's INVITE and START,
// once everyone in is ready. Everyone in it goes to the race together when
// the host starts: the lights go down, the phone turns, and the gun goes
// at the same moment on every phone.

import 'dart:async';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/stadium/bout_stage.dart';
import 'package:alchemons/games/stadium/flight_rules.dart';
import 'package:alchemons/games/stadium/flight_stage.dart';
import 'package:alchemons/games/stadium/gem_cups.dart';
import 'package:alchemons/games/stadium/island_stage.dart';
import 'package:alchemons/games/stadium/race_bodies.dart';
import 'package:alchemons/games/stadium/race_cups.dart';
import 'package:alchemons/games/stadium/race_painter.dart';
import 'package:alchemons/games/stadium/race_room.dart';
import 'package:alchemons/games/stadium/race_scenes.dart';
import 'package:alchemons/games/stadium/sky_rules.dart';
import 'package:alchemons/games/stadium/sky_stage.dart';
import 'package:alchemons/games/stadium/trials_records.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/screens/stadium/bout_screen.dart';
import 'package:alchemons/screens/friends/friend_planet_screen.dart'
    show kFriendOnlineColor;
import 'package:alchemons/screens/stadium/course_map.dart';
import 'package:alchemons/screens/stadium/race_screen.dart';
import 'package:alchemons/screens/stadium/racer_gate.dart';
import 'package:alchemons/screens/stadium/route_planner.dart';
import 'package:alchemons/screens/stadium/stadium_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/friend_service.dart';
import 'package:alchemons/services/race_room_service.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:alchemons/widgets/notification_banner_system.dart'
    show HomeNoticeDot;
import 'package:flame/flame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _ink = Color(0xFFE6E2DA);
const Color _muted = Color(0xFF8E8C88);
const Color _brass = Color(0xFFCDB07A);
const Color _brassHot = Color(0xFFE2C98F);
const Color _bg = Color(0xFF09090B);
const Color _bg1 = Color(0xFF131316);

class RaceLobbyScreen extends StatefulWidget {
  const RaceLobbyScreen({super.key, required this.roomId});

  final String roomId;

  /// Opens [roomId]'s lobby.
  static Future<void> open(BuildContext context, String roomId) =>
      Navigator.of(context).push(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (_, _, _) => RaceLobbyScreen(roomId: roomId),
          transitionsBuilder: (_, a, _, child) => FadeTransition(
            opacity: CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
            child: child,
          ),
        ),
      );

  /// Makes a room for [cup]'s race [race] (with [gem], a gem cup's bout),
  /// asks [invite] in, and opens it.
  static Future<void> host(
    BuildContext context, {
    required int cup,
    required int race,
    bool gem = false,
    List<FriendCard> invite = const [],
  }) async {
    final rooms = context.read<RaceRoomService>();
    try {
      final id = await rooms.host(
        cup: cup,
        race: race,
        gem: gem,
        invite: invite,
      );
      if (context.mounted) await open(context, id);
    } on RaceRoomException catch (e) {
      if (context.mounted) showGameSnack(context, e.message);
    }
  }

  @override
  State<RaceLobbyScreen> createState() => _RaceLobbyScreenState();
}

class _RaceLobbyScreenState extends State<RaceLobbyScreen>
    with SingleTickerProviderStateMixin {
  late final RaceRoomService _rooms = context.read<RaceRoomService>();
  late final FriendService? _friends = context.read<FriendService?>();
  StreamSubscription<RaceRoom?>? _sub;
  RaceRoom? _room;
  bool _heard = false;

  final ValueNotifier<double> _clock = ValueNotifier(0);
  late final Ticker _ticker;

  /// This player's racer, and the courses they have opened (the host picks
  /// among them).
  CosmicPartyMember? _member;
  RaceProgress _progress = const RaceProgress();

  /// Writing this player's seat; the racer it was last written with.
  bool _sitting = false;
  String? _satWith;

  /// A race underway on this phone, the last run raced (or seen begun
  /// without this player), and the lanes it was raced in.
  bool _racing = false, _lining = false, _leaving = false;
  int _seenRun = -1;
  Map<String, int> _lanes = const {};
  final ValueNotifier<Map<int, List<int>>> _taps = ValueNotifier(const {});
  final ValueNotifier<bool> _flying = ValueNotifier(false);

  String? get _me => _rooms.me;
  bool get _hosting => _room != null && _room!.host == _me;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) => _clock.value = e.inMicroseconds / 1e6)
      ..start();
    _friends?.watchPresence();
    _sub = _rooms
        .watch(widget.roomId)
        .listen(
          _onRoom,
          // Shut out of it: taken off its list (or it was never ours).
          onError: (Object e) {
            debugPrint('RaceLobby: room not read: $e');
            _closed(message: 'You are no longer in this race.');
          },
        );
    unawaited(_loadRacer());
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _friends?.unwatchPresence();
    _ticker.dispose();
    _clock.dispose();
    _taps.dispose();
    _flying.dispose();
    super.dispose();
  }

  Future<void> _loadRacer() async {
    final (progress, racer) = await loadTrialsStart(context);
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _member = racer;
    });
    _sitIfNeeded();
  }

  void _onRoom(RaceRoom? room) {
    if (!mounted) return;
    if (room == null) {
      _closed();
      return;
    }
    // A race already on as this player came in is not theirs.
    if (!_heard) {
      _heard = true;
      if (room.state == RaceRoomState.racing) _seenRun = room.run;
    }
    final me = _me;
    // The host took this player out.
    if (me != null && room.host != me && !room.invited.contains(me)) {
      _closed(message: 'You are no longer in this race.');
      return;
    }
    setState(() => _room = room);
    _sitIfNeeded();
    if (_racing) {
      _taps.value = {
        for (final e in room.taps.entries)
          if (_lanes[e.key] case final lane?) lane: e.value,
      };
    } else if (room.state == RaceRoomState.racing &&
        room.run > _seenRun &&
        me != null &&
        room.field.contains(me)) {
      unawaited(_launch(room));
    }
  }

  /// The room is gone (the host closed it), or this player is out of it.
  /// Mid-race, the race runs on here and the lobby goes once it is left.
  void _closed({String message = 'The race was closed.'}) {
    if (_leaving || !mounted) return;
    if (_racing) {
      _gone = message;
      return;
    }
    _leaving = true;
    if (!_hosting) showGameSnack(context, message);
    Navigator.of(context).pop();
  }

  /// Why the lobby goes once the race on here is left.
  String? _gone;

  /// Takes (or updates) this player's seat with their racer.
  Future<void> _sitIfNeeded() async {
    final room = _room, member = _member, me = _me;
    if (room == null || member == null || me == null || _sitting) return;
    if (room.state != RaceRoomState.lobby) return;
    if (_satWith == member.instanceId && room.seats.containsKey(me)) return;
    _sitting = true;
    try {
      final db = context.read<AlchemonsDatabase>();
      final inst = await db.creatureDao.getInstance(member.instanceId);
      if (!mounted || inst == null) return;
      await _rooms.sit(
        room.id,
        RaceSeat.of(
          uid: me,
          player: _rooms.myName,
          instanceId: member.instanceId,
          racer: racerFromMember(member, inst),
          look: ResidentLook.of(inst),
        ),
      );
      _satWith = member.instanceId;
    } on RaceRoomException catch (e) {
      if (mounted) showGameSnack(context, e.message);
    } finally {
      _sitting = false;
    }
  }

  Future<void> _chooseRacer() async {
    final room = _room;
    if (_racing || room == null || room.state != RaceRoomState.lobby) return;
    // Not ready while choosing: the host cannot start without them.
    final me = _me;
    if (me != null && !_hosting && room.isReady(me)) {
      unawaited(_setReady(room, false));
    }
    _flying.value = false;
    await pickRacer(
      context,
      current: _member?.instanceId,
      flying: _flying,
      onPick: (inst) async {
        if (!mounted) return null;
        final m = stadiumMemberOf(context, inst);
        setState(() => _member = m);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(kStadiumRacerKey, inst.instanceId);
        return m;
      },
    );
    unawaited(_sitIfNeeded());
  }

  // ── The host ────────────────────────────────────────────────────────────

  /// The courses the host has opened, in ladder order.
  List<(int, int)> get _courses => [
    for (var c = 0; c < kRaceCups.length; c++)
      if (_progress.cupOpen(c))
        for (var r = 0; r < kRaceCups[c].courses.length; r++)
          if (_progress.raceOpen(kRaceCups[c], r)) (c, r),
  ];

  /// The gem cups' bouts the host has opened, in order.
  List<(int, int)> get _bouts => [
    for (var g = 0; g < kGemCups.length; g++)
      if (_progress.gemOpen(g))
        for (var b = 0; b < kGemCups[g].bouts.length; b++)
          if (_progress.boutOpen(kGemCups[g], b)) (g, b),
  ];

  void _stepCourse(int by) {
    final room = _room;
    if (room == null || !_hosting) return;
    final list = room.gem ? _bouts : _courses;
    if (list.isEmpty) return;
    var at = list.indexOf((room.cup, room.race));
    at = at < 0 ? 0 : (at + by) % list.length;
    HapticFeedback.selectionClick();
    final (c, r) = list[at];
    unawaited(_rooms.setCourse(room, c, r, gem: room.gem));
  }

  /// RACES or GEMS: the host moves the room to the first it has opened.
  void _switchEvent(bool gem) {
    final room = _room;
    if (room == null || !_hosting || room.gem == gem) return;
    final list = gem ? _bouts : _courses;
    if (list.isEmpty) return;
    HapticFeedback.selectionClick();
    final (c, r) = list.first;
    unawaited(_rooms.setCourse(room, c, r, gem: gem));
  }

  /// This player's route through the space course, planned now; null if
  /// they backed out.
  Future<List<int>?> _planRoute(RaceRoom room) async {
    final me = _me;
    final seat = me == null ? null : room.seats[me];
    if (seat == null) return null;
    return planFlightRoute(
      context,
      title: room.bout.name,
      subtitle:
          '${room.gemDef.name.toUpperCase()} · WITH FRIENDS · '
          'PLAN YOUR ROUTE',
      course: flightCourseOf(room.bout),
      racer: seat.racer(isPlayer: true),
    );
  }

  Future<void> _invite() async {
    final room = _room, friends = _friends;
    if (room == null || friends == null) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _bg1,
      isScrollControlled: true,
      builder: (_) =>
          _InviteSheet(roomId: room.id, rooms: _rooms, friends: friends),
    );
  }

  /// Takes [uid] out of the race: a friend asked who has not come, or one
  /// in (asked first) who keeps the rest waiting.
  Future<void> _remove(RaceRoom room, String uid) async {
    if (room.seats.containsKey(uid)) {
      final go = await showBracketConfirm(
        context,
        palette: BracketPalette.dark,
        accent: kLeaveDangerAccent,
        title: 'TAKE ${room.nameOf(uid).toUpperCase()} OUT?',
        message: 'They leave the lobby. You can invite them again.',
        cancelLabel: 'KEEP',
        confirmLabel: 'TAKE OUT',
      );
      if (!go || !mounted) return;
    }
    HapticFeedback.selectionClick();
    try {
      await _rooms.remove(_room ?? room, uid);
    } on RaceRoomException catch (e) {
      if (mounted) showGameSnack(context, e.message);
    }
  }

  /// The computer's racers in the lanes left: [count] of them.
  Future<void> _computers(RaceRoom room, int count) async {
    HapticFeedback.selectionClick();
    try {
      await _rooms.setComputers(room, count);
    } on RaceRoomException catch (e) {
      if (mounted) showGameSnack(context, e.message);
    }
  }

  Future<void> _start() async {
    final room = _room, me = _me;
    if (room == null || me == null || !_hosting || _lining) return;
    // The space course: the host's own route first.
    if (room.needsPlan && room.planOf(me) == null) {
      final plan = await _planRoute(room);
      if (plan == null || !mounted) return;
      try {
        await _rooms.setPlan(_room ?? room, plan);
      } on RaceRoomException catch (e) {
        if (mounted) showGameSnack(context, e.message);
      }
      return;
    }
    if (!room.canStart) return;
    HapticFeedback.mediumImpact();
    try {
      await _rooms.start(room);
    } on RaceRoomException catch (e) {
      if (mounted) showGameSnack(context, e.message);
    }
  }

  // ── The race ────────────────────────────────────────────────────────────

  /// The room has started a race with this player in it: the field is read
  /// and loaded, and the race (or bout) opens on the shared gun.
  Future<void> _launch(RaceRoom room) async {
    final me = _me, startAt = room.startAt;
    if (me == null || startAt == null || _racing) return;
    _racing = true;
    _seenRun = room.run;
    setState(() => _lining = true);
    HapticFeedback.mediumImpact();
    _lanes = room.lanes();
    final link = RaceLink(
      gunAtMs: _rooms.localMs(startAt),
      taps: _taps,
      send: (ticks) {
        final now = _room;
        if (now != null) unawaited(_rooms.sendTaps(now, ticks));
      },
    );
    try {
      if (room.gem) {
        await _fight(room, me, link);
      } else {
        await _race(room, me, link);
      }
    } finally {
      _racing = false;
    }
    if (!mounted) return;
    if (_gone case final message?) {
      _closed(message: message);
      return;
    }
    setState(() => _lining = false);
    // The host brings the room back for the next one.
    final now = _room;
    if (now != null && now.host == me) unawaited(_rooms.backToLobby(now));
  }

  /// The taps so far, by lane, as the race opens.
  void _tapsNow(RaceRoom room) => _taps.value = {
    for (final e in (_room ?? room).taps.entries)
      if (_lanes[e.key] case final lane?) lane: e.value,
  };

  Future<void> _race(RaceRoom room, String me, RaceLink link) async {
    final catalog = context.read<CreatureCatalog>();
    final racers = room.racers(me);
    final lineup = room.lineup;
    final rivals = racers.length - lineup.length;
    // The players by their names; the computer's by their species.
    final bodies = [
      for (var i = 0; i < racers.length; i++)
        if (i < rivals)
          rivalBody(catalog, room.cupDef.rivals[i])
        else
          RaceBody(seatMember(catalog, lineup[i - rivals])),
    ];
    final forms = raceForms(catalog, racers, bodies, room.course);
    for (final f in forms) {
      for (final b in f.values) {
        if (b.ticker == null) await b.load(Flame.images);
      }
    }
    if (!mounted) return;
    _tapsNow(room);
    setState(() => _lining = false);
    await VoidPortal.pushThroughTurn<RaceOutcome>(
      context,
      page: RaceSeries(
        cup: room.cupDef,
        race: room.race.clamp(0, room.cupDef.courses.length - 1),
        racers: racers,
        bodies: bodies,
        forms: forms,
        // A race with friends is for the race: nothing is paid.
        onFinished: (_) async => const TrialsPayout(),
        live: link,
      ),
      scene: const RaceLightsScene(),
      from: null,
      to: () => null,
      orientation: const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      returnOrientation: const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ],
    );
  }

  /// A gem cup's bout with friends: the three loaded, the bout opened
  /// upright on the shared gun.
  Future<void> _fight(RaceRoom room, String me, RaceLink link) async {
    final catalog = context.read<CreatureCatalog>();
    final cup = room.gemDef, b = room.boutIndex;
    final fighters = room.fighters();
    final lineup = room.lineup;
    final rivals = fighters.length - lineup.length;
    final pool = cup.rivalsOf(b);
    final bodies = [
      for (var i = 0; i < fighters.length; i++)
        if (i < rivals)
          rivalBody(catalog, pool[i])
        else
          RaceBody(seatMember(catalog, lineup[i - rivals])),
    ];
    for (final body in bodies) {
      if (body.ticker == null) await body.load(Flame.images);
    }
    final figures = cup.event == GemEvent.sky
        ? await loadSkyFigures(bodies)
        : null;
    final routes = room.needsPlan ? room.routes(fighters) : null;
    final player = _lanes[me];
    if (!mounted || player == null) return;
    _tapsNow(room);
    final live = BoutLive(
      gunAt: link.gunAtMs / 1000,
      wall: () => DateTime.now().millisecondsSinceEpoch / 1000,
    );
    setState(() => _lining = false);
    await Navigator.of(context).push<RaceOutcome>(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, _, _) => BoutScreen(
          cup: cup,
          bout: b,
          fighters: fighters,
          bodies: bodies,
          live: link,
          stage: () => switch (cup.event) {
            GemEvent.flight => FlightStage(
              course: flightCourseOf(cup.bouts[b]),
              fighters: fighters,
              bodies: bodies,
              player: player,
              choices: routes!,
              live: live,
            ),
            GemEvent.sky => SkyStage(
              bout: skyBoutOf(cup.bouts[b]),
              figures: figures,
              fighters: fighters,
              bodies: bodies,
              player: player,
              live: live,
            ),
            GemEvent.island => IslandStage(
              bout: islandBoutOf(cup.bouts[b]),
              fighters: fighters,
              bodies: bodies,
              player: player,
              live: live,
            ),
          },
          // A bout with friends is for the bout: nothing is paid.
          onFinished: (_) async => const TrialsPayout(),
        ),
        transitionsBuilder: (_, a, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
          child: child,
        ),
      ),
    );
  }

  // ── A player ────────────────────────────────────────────────────────────

  bool _readying = false;

  /// READY (or not); on the space course, READY plans the route first.
  Future<void> _setReady(RaceRoom room, bool ready) async {
    if (_readying) return;
    List<int>? plan;
    if (ready && room.needsPlan) {
      plan = await _planRoute(room);
      if (plan == null || !mounted) return;
    }
    setState(() => _readying = true);
    try {
      await _rooms.setReady(_room ?? room, ready, plan: plan);
    } on RaceRoomException catch (e) {
      if (mounted) showGameSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _readying = false);
    }
  }

  Future<void> _leave() async {
    if (_leaving) return;
    final room = _room;
    if (room != null && _hosting && room.racing.length > 1) {
      final go = await showBracketConfirm(
        context,
        palette: BracketPalette.dark,
        accent: kLeaveDangerAccent,
        title: 'CLOSE THE RACE?',
        message: 'Everyone in the lobby is sent home.',
        cancelLabel: 'STAY',
        confirmLabel: 'CLOSE',
      );
      if (!go || !mounted) return;
    }
    _leaving = true;
    HapticFeedback.selectionClick();
    if (room != null) {
      try {
        await _rooms.leave(room);
      } on RaceRoomException catch (e) {
        debugPrint('RaceLobby: not left cleanly: $e');
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  // ── The screen ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final room = _room;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _Backdrop(_clock, MediaQuery.paddingOf(context)),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(context),
                    if (room == null)
                      const Expanded(child: SizedBox.shrink())
                    else ...[
                      const SizedBox(height: 8),
                      _course(context, room),
                      const SizedBox(height: 14),
                      _label(context, 'LANES'),
                      const SizedBox(height: 6),
                      Expanded(child: _lanesList(context, room)),
                      const SizedBox(height: 10),
                      _actions(context, room),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => SizedBox(
    height: kTrialsHeaderHeight,
    child: Row(
      children: [
        BracketIconButton(
          icon: AppIcons.arrow_back_rounded,
          onTap: _leave,
          palette: BracketPalette.dark,
          size: 34,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'WITH FRIENDS',
              style: bracketText(
                context,
                15,
                _ink,
                weight: FontWeight.w800,
                letterSpacing: 2.6,
              ),
            ),
          ),
        ),
        const Spacer(),
        if (_room case final room?
            when _hosting &&
                room.state == RaceRoomState.lobby &&
                _bouts.isNotEmpty)
          _eventSwitch(context, room),
      ],
    ),
  );

  /// RACES · GEMS, for the host: what the room races.
  Widget _eventSwitch(BuildContext context, RaceRoom room) {
    Widget side(String label, bool gem) {
      final on = room.gem == gem;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: on || _lining ? null : () => _switchEvent(gem),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: bracketText(
                  context,
                  11,
                  on ? _brassHot : _muted,
                  weight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                width: on ? 18 : 0,
                height: 2,
                color: _brass,
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [side('RACES', false), side('GEMS', true)],
    );
  }

  Widget _label(BuildContext context, String text) => Text(
    text,
    style: bracketText(
      context,
      9.5,
      _muted,
      weight: FontWeight.w700,
      letterSpacing: 1.8,
    ),
  );

  /// The course: its name, where it runs, and its map — or the gem cup's
  /// bout: its name, its cup and event, and what it asks. The host steps
  /// through the ones they have opened.
  Widget _course(BuildContext context, RaceRoom room) {
    final course = room.course;
    final gem = room.gem;
    final canStep = _hosting && room.state == RaceRoomState.lobby;
    Widget arrow(IconData icon, int by) => canStep
        ? BracketIconButton(
            icon: icon,
            onTap: () => _stepCourse(by),
            palette: BracketPalette.dark,
            size: 30,
          )
        : const SizedBox(width: 30);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            arrow(AppIcons.chevron_left_rounded, -1),
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: Column(
                  key: ValueKey(room.placeKey),
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        room.placeName.toUpperCase(),
                        style: bracketText(
                          context,
                          19,
                          _brassHot,
                          weight: FontWeight.w800,
                          letterSpacing: 2.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      gem
                          ? '${room.gemDef.name.toUpperCase()} · '
                                '${room.gemDef.event.title}'
                          : '${room.cupDef.name.toUpperCase()} · '
                                '${raceSceneName(course.scene)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: bracketText(
                        context,
                        9.5,
                        _muted,
                        weight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            arrow(AppIcons.chevron_right_rounded, 1),
          ],
        ),
        SizedBox(
          height: 60,
          child: gem
              ? Center(
                  child: Text(
                    room.needsPlan
                        ? '${room.gemDef.event.line} Each of you plans '
                              'a route before READY.'
                        : room.gemDef.event.line,
                    textAlign: TextAlign.center,
                    style: bracketText(context, 12, _ink.withValues(alpha: .8)),
                  ),
                )
              : RepaintBoundary(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: CourseMapPainter(
                      course: course,
                      clock: _clock,
                      textStyle:
                          Theme.of(context).textTheme.bodyMedium ??
                          const TextStyle(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  /// The lanes (six, or a bout's three): the players in, the friends
  /// asked, the computer's, and any the host has left open. Between races
  /// the host takes any lane out but their own, and puts a computer back
  /// in an open one.
  Widget _lanesList(BuildContext context, RaceRoom room) {
    final catalog = context.read<CreatureCatalog>();
    final me = _me;
    final between = room.state == RaceRoomState.lobby && !_racing;
    final edit = _hosting && between && !_lining;
    final joined = room.racing.take(kRaceRoomSeats).toList();
    final asked = [
      for (final uid in room.invited)
        if (!room.seats.containsKey(uid)) uid,
    ];
    final rivals = room.rivalsBeside(joined.length + asked.length);
    final open = (room.held - joined.length - asked.length - rivals).clamp(
      0,
      room.held,
    );
    // Room for another computer: an open lane, and a rival left to fill it.
    final more = open > 0 && rivals < room.rivalPool.length;
    String tagOf(RaceSeat seat) {
      if (seat.uid == room.host) return 'HOST';
      if (!between) return room.field.contains(seat.uid) ? 'RACING' : '';
      return room.isReady(seat.uid) ? 'READY' : 'NOT READY';
    }

    final rows = <Widget>[
      for (final seat in joined)
        _LaneRow(
          sprite: stadiumSprite(
            seat.uid == me && _member != null
                ? _member!
                : seatMember(catalog, seat),
            40,
          ),
          title: seat.uid == me ? '${seat.player} · YOU' : seat.player,
          line: seat.current
              ? '${seat.entrant.name.toUpperCase()} · '
                    '${seat.entrant.element.toUpperCase()}'
              : 'NEEDS THE LATEST VERSION OF THE GAME',
          tag: tagOf(seat),
          tagLit: seat.uid == room.host || room.isReady(seat.uid),
          lit: true,
          onTap: seat.uid == me && between ? _chooseRacer : null,
          action: seat.uid == me && between ? 'CHANGE' : null,
          onRemove: edit && seat.uid != room.host
              ? () => _remove(room, seat.uid)
              : null,
        ),
      for (final uid in asked)
        _LaneRow(
          title: room.nameOf(uid),
          line: 'ASKED · NOT IN YET',
          tag: '',
          lit: false,
          onRemove: edit ? () => _remove(room, uid) : null,
        ),
      for (final rival in room.rivalPool.take(rivals))
        _LaneRow(
          sprite: rivalMember(catalog, rival) == null
              ? null
              : stadiumSprite(rivalMember(catalog, rival)!, 40),
          title: rival.name,
          line: 'COMPUTER · ${rival.element.toUpperCase()}',
          tag: '',
          lit: false,
          onRemove: edit ? () => _computers(room, rivals - 1) : null,
        ),
      for (var i = 0; i < open; i++)
        _LaneRow(
          title: 'OPEN LANE',
          line: 'NO ONE RACES HERE',
          tag: '',
          lit: false,
          onTap: edit && more ? () => _computers(room, rivals + 1) : null,
          action: edit && more ? 'ADD COMPUTER' : null,
        ),
    ];
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, i) => rows[i],
    );
  }

  Widget _actions(BuildContext context, RaceRoom room) {
    final on = room.state == RaceRoomState.racing && !_racing;
    // Back from a race the host has not come back from yet, or come in
    // while one was on.
    final mine = on && room.field.contains(_me) && room.run == _seenRun;
    final host = room.nameOf(room.host).toUpperCase();
    final me = _me;
    final what = room.gem ? 'BOUT' : 'RACE';
    final crowded = room.racing.length > room.held;
    if (!_hosting) {
      final seated = me != null && room.seats.containsKey(me);
      final ready = me != null && room.isReady(me);
      final between = room.state == RaceRoomState.lobby && !_racing;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _status(
            context,
            _lining
                ? 'ON YOUR MARKS…'
                : mine
                ? 'WAITING FOR $host'
                : on
                ? 'A $what IS ON · YOU ARE IN THE NEXT ONE'
                : crowded
                ? 'A BOUT HOLDS ${room.held} · WAITING FOR $host'
                : ready
                ? 'READY · $host STARTS THE $what'
                : '$host STARTS WHEN EVERYONE IS READY',
            lit: _lining || ready,
          ),
          Row(
            children: [
              Expanded(
                child: BracketButton(
                  label: 'LEAVE',
                  palette: BracketPalette.dark,
                  accent: _brass,
                  primary: false,
                  height: 42,
                  enabled: !_lining,
                  onTap: _leave,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: BracketButton(
                  label: ready
                      ? 'NOT READY'
                      : (room.needsPlan ? 'PLAN YOUR ROUTE' : 'READY UP'),
                  palette: BracketPalette.dark,
                  accent: _brass,
                  primary: !ready,
                  height: 42,
                  enabled: seated && between && !_lining && !_readying,
                  onTap: () => _setReady(room, !ready),
                ),
              ),
            ],
          ),
        ],
      );
    }
    final waiting = room.notReady;
    final full = room.invited.length >= room.held;
    // The space course: the host plans a route before starting.
    final plan = room.needsPlan && me != null && room.planOf(me) == null;
    final String status;
    if (_lining) {
      status = 'ON YOUR MARKS…';
    } else if (crowded) {
      status = 'A BOUT HOLDS ${room.held} · TAKE SOMEONE OUT';
    } else if (room.racing.length < 2) {
      status = room.invited.length < 2
          ? 'INVITE A FRIEND TO RACE'
          : 'WAITING FOR FRIENDS TO JOIN';
    } else if (waiting.length == 1) {
      status = 'WAITING FOR ${waiting.first.player.toUpperCase()} TO GET READY';
    } else if (waiting.isNotEmpty) {
      status = 'WAITING FOR ${waiting.length} TO GET READY';
    } else {
      status = 'EVERYONE IS READY';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _status(context, status, lit: _lining || room.canStart),
        Row(
          children: [
            Expanded(
              child: BracketButton(
                label: full ? 'LANES FULL' : 'INVITE',
                palette: BracketPalette.dark,
                accent: _brass,
                primary: false,
                height: 42,
                enabled: !full && room.state == RaceRoomState.lobby,
                onTap: _invite,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: BracketButton(
                label: _lining
                    ? 'LINING UP…'
                    : (plan ? 'PLAN YOUR ROUTE' : 'START'),
                palette: BracketPalette.dark,
                accent: _brass,
                height: 42,
                enabled:
                    !_lining &&
                    (plan ? room.state == RaceRoomState.lobby : room.canStart),
                onTap: _start,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// A line over the buttons: what the room is waiting on.
  Widget _status(BuildContext context, String text, {required bool lit}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: bracketText(
            context,
            10.5,
            lit ? _brassHot : _muted,
            weight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
      );
}

/// One lane in the lobby.
class _LaneRow extends StatelessWidget {
  const _LaneRow({
    required this.title,
    required this.line,
    required this.tag,
    required this.lit,
    this.tagLit = true,
    this.sprite,
    this.onTap,
    this.action,
    this.onRemove,
  });

  final Widget? sprite;
  final String title, line, tag;
  final bool lit, tagLit;
  final VoidCallback? onTap;
  final String? action;

  /// The host's ×: takes the lane out.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: lit
              ? _brass.withValues(alpha: .7)
              : BracketPalette.dark.lineSoft,
          strokeWidth: 1.1,
        ),
        child: Container(
          height: 54,
          color: lit ? _bg1 : _bg1.withValues(alpha: .4),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Opacity(
                  opacity: lit ? 1 : .55,
                  child:
                      sprite ??
                      Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _muted.withValues(alpha: .5),
                          ),
                        ),
                      ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: bracketText(
                        context,
                        12.5,
                        lit ? _ink : _muted,
                        weight: FontWeight.w800,
                        letterSpacing: .6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: bracketText(
                        context,
                        9,
                        _muted.withValues(alpha: lit ? 1 : .7),
                        weight: FontWeight.w700,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (tag.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    tag,
                    style: bracketText(
                      context,
                      9.5,
                      tagLit ? _brassHot : _muted,
                      weight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
              if (action != null)
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Text(
                    action!,
                    style: bracketText(
                      context,
                      9.5,
                      _brass,
                      weight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
              if (onRemove != null)
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: BracketIconButton(
                    icon: AppIcons.close_rounded,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onRemove!();
                    },
                    palette: BracketPalette.dark,
                    size: 28,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Friends to ask in, those here now first.
class _InviteSheet extends StatefulWidget {
  const _InviteSheet({
    required this.roomId,
    required this.rooms,
    required this.friends,
  });

  final String roomId;
  final RaceRoomService rooms;
  final FriendService friends;

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  late final Stream<RaceRoom?> _room = widget.rooms.watch(widget.roomId);
  final Set<String> _asking = {};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .7,
        ),
        child: ListenableBuilder(
          listenable: widget.friends,
          builder: (context, _) => StreamBuilder<RaceRoom?>(
            stream: _room,
            builder: (context, snap) {
              final room = snap.data;
              final list = [...widget.friends.friends]
                ..sort((a, b) {
                  final oa = widget.friends.isOnline(a.uid) ? 0 : 1;
                  final ob = widget.friends.isOnline(b.uid) ? 0 : 1;
                  return oa != ob
                      ? oa.compareTo(ob)
                      : a.name.toLowerCase().compareTo(b.name.toLowerCase());
                });
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
                    child: Text(
                      'INVITE A FRIEND',
                      style: bracketText(
                        context,
                        13,
                        _ink,
                        weight: FontWeight.w800,
                        letterSpacing: 2.2,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                    child: Text(
                      'Friends playing now can join straight away.',
                      style: bracketText(context, 11, _muted),
                    ),
                  ),
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                      child: Text(
                        'Add friends from your profile first.',
                        style: bracketText(context, 12, _muted),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        children: [
                          for (final f in list) _row(context, room, f),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, RaceRoom? room, FriendCard f) {
    final online = widget.friends.isOnline(f.uid);
    final asked = room?.invited.contains(f.uid) ?? false;
    final full = (room?.invited.length ?? 0) >= kRaceRoomSeats;
    final seen = widget.friends.seenLabel(f.uid);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: room == null || asked || full || _asking.contains(f.uid)
          ? null
          : () async {
              HapticFeedback.selectionClick();
              setState(() => _asking.add(f.uid));
              try {
                await widget.rooms.invite(room, f);
              } on RaceRoomException catch (e) {
                if (context.mounted) showGameSnack(context, e.message);
              } finally {
                if (mounted) setState(() => _asking.remove(f.uid));
              }
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              child: online
                  ? const HomeNoticeDot(color: kFriendOnlineColor, size: 9)
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: bracketText(
                      context,
                      13,
                      online ? _ink : _muted,
                      weight: FontWeight.w700,
                    ),
                  ),
                  if (!online && seen != null)
                    Text(seen, style: bracketText(context, 10, _muted)),
                ],
              ),
            ),
            Text(
              asked ? 'ASKED' : (full ? '' : 'INVITE'),
              style: bracketText(
                context,
                10,
                asked ? _muted : _brass,
                weight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The stands drifting across the top, as on the Trials.
class _Backdrop extends CustomPainter {
  _Backdrop(this.clock, this.pad) : super(repaint: clock);

  final ValueListenable<double> clock;
  final EdgeInsets pad;

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    canvas.drawRect(Offset.zero & size, Paint()..color = _bg);
    final band = trialsStandsBand(size, pad);
    final virtual = band.height / 0.235;
    canvas.save();
    canvas.translate(0, band.top - virtual * 0.1);
    paintStadiumStands(
      canvas,
      Size(size.width, virtual),
      t: t,
      camX: t * 9,
      cheer: 0.3,
    );
    canvas.restore();
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _bg.withValues(alpha: 0.35),
            _bg.withValues(alpha: 0.9),
            _bg,
          ],
          stops: const [0, .3, .6],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_Backdrop old) => old.pad != pad;
}
