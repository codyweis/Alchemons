// lib/screens/stadium/race_lobby_screen.dart
//
// Racing friends, before the gun (the author, 2026-10-12: "race vs
// friends", live, invited while they are online). The lobby of one room:
// the course (the host steps through the ones they have opened), the six
// lanes — the players who have joined with their racers, the friends asked
// and not yet in, the cup's computer rivals in the rest — your own racer
// to change, and the host's INVITE and START. Everyone in it goes to the
// race together when the host starts: the lights go down, the phone turns,
// and the gun goes at the same moment on every phone.

import 'dart:async';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/stadium/race_bodies.dart';
import 'package:alchemons/games/stadium/race_cups.dart';
import 'package:alchemons/games/stadium/race_painter.dart';
import 'package:alchemons/games/stadium/race_room.dart';
import 'package:alchemons/games/stadium/race_scenes.dart';
import 'package:alchemons/games/stadium/trials_records.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/screens/friends/friend_planet_screen.dart'
    show kFriendOnlineColor;
import 'package:alchemons/screens/stadium/course_map.dart';
import 'package:alchemons/screens/stadium/race_screen.dart';
import 'package:alchemons/screens/stadium/racer_gate.dart';
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

  /// Makes a room for [cup]'s race [race], asks [invite] in, and opens it.
  static Future<void> host(
    BuildContext context, {
    required int cup,
    required int race,
    List<FriendCard> invite = const [],
  }) async {
    final rooms = context.read<RaceRoomService>();
    try {
      final id = await rooms.host(cup: cup, race: race, invite: invite);
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
          onError: (Object e) {
            debugPrint('RaceLobby: room not read: $e');
            _closed();
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
    setState(() => _room = room);
    _sitIfNeeded();
    final me = _me;
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

  /// The room is gone: the host closed it. Mid-race, the race runs on
  /// here and the lobby goes once it is left.
  void _closed() {
    if (_leaving || !mounted) return;
    if (_racing) {
      _gone = true;
      return;
    }
    _leaving = true;
    if (!_hosting) showGameSnack(context, 'The race was closed.');
    Navigator.of(context).pop();
  }

  bool _gone = false;

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
    if (_racing || _room?.state != RaceRoomState.lobby) return;
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

  void _stepCourse(int by) {
    final room = _room;
    if (room == null || !_hosting) return;
    final list = _courses;
    if (list.isEmpty) return;
    var at = list.indexOf((room.cup, room.race));
    at = at < 0 ? 0 : (at + by) % list.length;
    HapticFeedback.selectionClick();
    final (c, r) = list[at];
    unawaited(_rooms.setCourse(room, c, r));
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

  Future<void> _start() async {
    final room = _room;
    if (room == null || !_hosting || _lining) return;
    HapticFeedback.mediumImpact();
    try {
      await _rooms.start(room);
    } on RaceRoomException catch (e) {
      if (mounted) showGameSnack(context, e.message);
    }
  }

  // ── The race ────────────────────────────────────────────────────────────

  /// The room has started a race with this player in it: the six are read
  /// and loaded, and the race opens on the shared gun.
  Future<void> _launch(RaceRoom room) async {
    final me = _me, startAt = room.startAt;
    if (me == null || startAt == null || _racing) return;
    _racing = true;
    _seenRun = room.run;
    setState(() => _lining = true);
    HapticFeedback.mediumImpact();
    final catalog = context.read<CreatureCatalog>();
    _lanes = room.lanes();
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
    _taps.value = {
      for (final e in (_room ?? room).taps.entries)
        if (_lanes[e.key] case final lane?) lane: e.value,
    };
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
        live: RaceLink(
          gunAtMs: _rooms.localMs(startAt),
          taps: _taps,
          send: (ticks) {
            final now = _room;
            if (now != null) unawaited(_rooms.sendTaps(now, ticks));
          },
        ),
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
    _racing = false;
    if (!mounted) return;
    if (_gone) {
      _closed();
      return;
    }
    setState(() {});
    // The host brings the room back for the next one.
    final now = _room;
    if (now != null && now.host == me) unawaited(_rooms.backToLobby(now));
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
              'RACE WITH FRIENDS',
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
      ],
    ),
  );

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

  /// The course: its name, where it runs, and its map. The host steps
  /// through the courses they have opened.
  Widget _course(BuildContext context, RaceRoom room) {
    final course = room.course;
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
                  key: ValueKey(course.id),
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        course.name.toUpperCase(),
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
                      '${room.cupDef.name.toUpperCase()} · '
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
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size.infinite,
              painter: CourseMapPainter(
                course: course,
                clock: _clock,
                textStyle:
                    Theme.of(context).textTheme.bodyMedium ?? const TextStyle(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The six lanes: the players in, the friends asked, the computer's.
  Widget _lanesList(BuildContext context, RaceRoom room) {
    final catalog = context.read<CreatureCatalog>();
    final me = _me;
    final joined = room.racing.take(kRaceRoomSeats).toList();
    final asked = [
      for (final uid in room.invited)
        if (!room.seats.containsKey(uid)) uid,
    ];
    final rivals = (kRaceRoomSeats - joined.length - asked.length).clamp(
      0,
      room.cupDef.rivals.length,
    );
    final rows = <Widget>[
      for (final seat in joined)
        _LaneRow(
          sprite: stadiumSprite(
            seat.uid == me && _member != null
                ? _member!
                : seatMember(catalog, seat),
            40,
          ),
          title: seat.player,
          line:
              '${seat.entrant.name.toUpperCase()} · '
              '${seat.entrant.element.toUpperCase()}',
          tag: seat.uid == me ? 'YOU' : (seat.uid == room.host ? 'HOST' : ''),
          lit: true,
          onTap: seat.uid == me ? _chooseRacer : null,
          action: seat.uid == me && room.state == RaceRoomState.lobby
              ? 'CHANGE'
              : null,
        ),
      for (final uid in asked)
        _LaneRow(
          title: room.nameOf(uid),
          line: 'ASKED · NOT IN YET',
          tag: '',
          lit: false,
        ),
      for (final rival in room.cupDef.rivals.take(rivals))
        _LaneRow(
          sprite: rivalMember(catalog, rival) == null
              ? null
              : stadiumSprite(rivalMember(catalog, rival)!, 40),
          title: rival.name,
          line: 'COMPUTER · ${rival.element.toUpperCase()}',
          tag: '',
          lit: false,
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
    if (!_hosting) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          _lining
              ? 'ON YOUR MARKS…'
              : mine
              ? 'WAITING FOR $host'
              : on
              ? 'A RACE IS ON · YOU ARE IN THE NEXT ONE'
              : '$host STARTS THE RACE',
          textAlign: TextAlign.center,
          style: bracketText(
            context,
            11,
            _lining ? _brassHot : _muted,
            weight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
      );
    }
    final ready = room.racing.length >= 2;
    final full = room.invited.length >= kRaceRoomSeats;
    return Row(
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
                : (ready ? 'START' : 'WAITING FOR FRIENDS'),
            palette: BracketPalette.dark,
            accent: _brass,
            height: 42,
            enabled: ready && !_lining && room.state == RaceRoomState.lobby,
            onTap: _start,
          ),
        ),
      ],
    );
  }
}

/// One lane in the lobby.
class _LaneRow extends StatelessWidget {
  const _LaneRow({
    required this.title,
    required this.line,
    required this.tag,
    required this.lit,
    this.sprite,
    this.onTap,
    this.action,
  });

  final Widget? sprite;
  final String title, line, tag;
  final bool lit;
  final VoidCallback? onTap;
  final String? action;

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
                      _brassHot,
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
