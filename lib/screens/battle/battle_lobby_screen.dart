// lib/screens/battle/battle_lobby_screen.dart
//
// Battling a friend, before the fight (docs/battle/live_pvp_design.md): the
// lobby of one room. The host's arena, live; the head-to-head between the
// two; your four (CHANGE picks them again) and theirs, which is the team
// preview; the friend's READY and the host's START. Both go to the fight
// together when the host starts it, at the same moment on both phones;
// REMATCH on the result card comes back here ready for the next.
//
// Each brings the four they keep for battles (setting battle_team_v1), the
// first two leading. Nothing is paid.

import 'dart:async';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/battle_arena_art.dart'
    show kBattleBrass, kBattleSilver;
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart' show kBattleTeamSize;
import 'package:alchemons/models/battle_arenas.dart';
import 'package:alchemons/models/battle_record.dart';
import 'package:alchemons/models/battle_room.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/screens/battle/battle_how_to.dart';
import 'package:alchemons/screens/battle/battle_hub_screen.dart';
import 'package:alchemons/screens/battle/battle_journey.dart';
import 'package:alchemons/screens/battle/battle_live.dart';
import 'package:alchemons/screens/battle/battle_screen.dart';
import 'package:alchemons/screens/friends/friend_planet_screen.dart'
    show kFriendOnlineColor;
import 'package:alchemons/services/battle_room_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/friend_service.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/battle/battle_arena_preview.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:alchemons/widgets/notification_banner_system.dart'
    show HomeNoticeDot;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

const Color _ink = Color(0xFFE6E2DA);
const Color _muted = Color(0xFF8E8C88);
const Color _bg = Color(0xFF09090B);
const Color _bg1 = Color(0xFF131316);

class BattleLobbyScreen extends StatefulWidget {
  const BattleLobbyScreen({super.key, required this.roomId});

  final String roomId;

  /// Opens [roomId]'s lobby.
  static Future<void> open(BuildContext context, String roomId) =>
      Navigator.of(context).push(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (_, _, _) => BattleLobbyScreen(roomId: roomId),
          transitionsBuilder: (_, a, _, child) => FadeTransition(
            opacity: CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
            child: child,
          ),
        ),
      );

  /// Makes a room in this player's arena, asks [invite] in (or nobody yet:
  /// the lobby's INVITE), and opens it at once: the room shows on this
  /// phone before the server has it, and nothing here waits on the server.
  static Future<void> host(BuildContext context, {FriendCard? invite}) async {
    final rooms = context.read<BattleRoomService>();
    final settings = context.read<AlchemonsDatabase>().settingsDao;
    final arena = await chosenBattleArena(settings);
    if (!context.mounted) return;
    final String id;
    try {
      id = rooms.hostNow(arena: arena, invite: invite);
    } on BattleRoomException catch (e) {
      showGameSnack(context, e.message);
      return;
    }
    await open(context, id);
  }

  @override
  State<BattleLobbyScreen> createState() => _BattleLobbyScreenState();
}

class _BattleLobbyScreenState extends State<BattleLobbyScreen> {
  late final BattleRoomService _rooms = context.read<BattleRoomService>();
  late final FriendService? _friends = context.read<FriendService?>();
  StreamSubscription<BattleRoom?>? _sub;
  BattleRoom? _room;
  bool _heard = false;

  /// This player's four, and the ids they were last sat with.
  List<CosmicPartyMember> _team = const [];
  bool _teamLoaded = false;
  bool _sitting = false;
  String? _satWith;

  /// The head-to-head with the friend in the room.
  BattleRecord _record = const BattleRecord();
  String? _recordOf;

  /// A fight on, on this phone; the last fight seen begun.
  bool _fighting = false, _leaving = false;
  int _seenRun = -1;

  /// REMATCH: the guest readies, the host starts, once the room is back.
  bool _rematch = false;

  /// The room is gone (closed while a fight was on here).
  bool _gone = false;

  /// The host's place, pictured for the way into the first fight; whose
  /// it was prepared for.
  BattleJourneyArt? _journey;
  String? _journeyOf;

  String? get _me => _rooms.me;
  bool get _hosting => _room != null && _room!.host == _me;

  @override
  void initState() {
    super.initState();
    _friends?.watchPresence();
    _sub = _rooms
        .watch(widget.roomId)
        .listen(
          _onRoom,
          onError: (Object e) {
            debugPrint('BattleLobby: room not read: $e');
            _closed(message: 'You are no longer in this battle.');
          },
        );
    unawaited(_loadTeam());
    // The first time a battle is opened: the rules.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(maybeShowBattleHowTo(context));
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _friends?.unwatchPresence();
    _journey?.dispose();
    super.dispose();
  }

  Future<void> _loadTeam() async {
    final team = await loadBattleTeam(context);
    if (!mounted) return;
    setState(() {
      _team = team;
      _teamLoaded = true;
    });
    unawaited(_sitIfNeeded());
  }

  void _onRoom(BattleRoom? room) {
    if (!mounted) return;
    if (room == null) {
      _gone = true;
      _closed();
      return;
    }
    if (!_heard) {
      _heard = true;
      // A fight already on as this player came in is not theirs.
      if (room.state == BattleRoomState.fighting) _seenRun = room.run;
    }
    final me = _me;
    if (me != null && room.host != me && room.guest != me) {
      _closed(message: 'You are no longer in this battle.');
      return;
    }
    setState(() => _room = room);
    unawaited(_sitIfNeeded());
    unawaited(_loadRecord(room));
    if (!_fighting &&
        room.state == BattleRoomState.fighting &&
        room.run > _seenRun &&
        room.hostSeat != null &&
        room.guestSeat != null) {
      unawaited(_launch(room));
      return;
    }
    // REMATCH, once the room is back between fights.
    if (_rematch &&
        !_fighting &&
        room.state == BattleRoomState.lobby &&
        me != null) {
      if (_hosting) {
        if (room.canStart) {
          _rematch = false;
          _start();
        }
      } else {
        _rematch = false;
        if (!room.isReady(me)) _setReady(true);
      }
    }
  }

  /// The room is gone (the host closed it), or this player is out of it.
  void _closed({String message = 'The battle was closed.'}) {
    if (_leaving || !mounted || _fighting) return;
    _leaving = true;
    if (!_hosting) showGameSnack(context, message);
    Navigator.of(context).pop();
  }

  Future<void> _loadRecord(BattleRoom room) async {
    final me = _me;
    final other = me == null ? null : room.otherOf(me);
    if (other == null || other == _recordOf) return;
    _recordOf = other;
    final record = await BattleRecord.load(
      context.read<AlchemonsDatabase>().settingsDao,
      key: BattleRecord.friendKey(other),
    );
    if (mounted && _recordOf == other) setState(() => _record = record);
  }

  /// Takes (or updates) this player's seat with their four.
  Future<void> _sitIfNeeded() async {
    final room = _room, me = _me;
    if (room == null || me == null || _sitting || !_teamLoaded) return;
    if (room.state != BattleRoomState.lobby || _team.isEmpty) return;
    final ids = [for (final m in _team) m.instanceId].join(',');
    if (_satWith == ids && room.seats.containsKey(me)) return;
    _sitting = true;
    try {
      final db = context.read<AlchemonsDatabase>();
      final team = <BattleSeatMember>[];
      for (final m in _team.take(kBattleTeamSize)) {
        final inst = await db.creatureDao.getInstance(m.instanceId);
        if (inst == null) continue;
        team.add(BattleSeatMember.of(m, ResidentLook.of(inst)));
      }
      if (!mounted || team.isEmpty) return;
      await _rooms.sit(
        room.id,
        BattleSeat(uid: me, player: _rooms.myName, team: team),
      );
      _satWith = ids;
    } on BattleRoomException catch (e) {
      if (mounted) showGameSnack(context, e.message);
    } finally {
      _sitting = false;
    }
  }

  Future<void> _changeTeam() async {
    final room = _room, me = _me;
    if (_fighting || room == null || room.state != BattleRoomState.lobby) {
      return;
    }
    // Not ready while choosing: the host cannot start without them.
    if (me != null && !_hosting && room.isReady(me)) {
      _setReady(false);
    }
    final picked = await pickBattleTeam(context, _team);
    if (picked == null || !mounted) return;
    setState(() => _team = picked);
    unawaited(_sitIfNeeded());
  }

  // ── The host ────────────────────────────────────────────────────────────

  Future<void> _invite() async {
    final room = _room, friends = _friends;
    if (room == null || friends == null) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _bg1,
      isScrollControlled: true,
      builder: (_) => _InviteSheet(room: room, rooms: _rooms, friends: friends),
    );
  }

  Future<void> _remove() async {
    final room = _room;
    if (room == null || room.guest == null) return;
    if (room.guestSeat != null) {
      final go = await showBracketConfirm(
        context,
        palette: BracketPalette.dark,
        accent: kLeaveDangerAccent,
        title: 'TAKE ${room.nameOf(room.guest).toUpperCase()} OUT?',
        message: 'They leave the lobby. You can invite them again.',
        cancelLabel: 'KEEP',
        confirmLabel: 'TAKE OUT',
      );
      if (!go || !mounted) return;
    }
    HapticFeedback.selectionClick();
    _rooms.later(_rooms.remove(_room ?? room));
  }

  /// The run START was last pressed for: once a fight, however quickly the
  /// button is pressed again before the room says it has begun.
  int _startedFor = -1;

  void _start() {
    final room = _room;
    if (room == null || !_hosting || !room.canStart || _fighting) return;
    if (_startedFor == room.run) return;
    _startedFor = room.run;
    HapticFeedback.mediumImpact();
    _rooms.later(_rooms.start(room));
  }

  // ── The fight ───────────────────────────────────────────────────────────

  /// The room has started a fight: both fours from the seats (this phone's
  /// own too, so both phones fight the same eight), and the battle on the
  /// room's start time.
  Future<void> _launch(BattleRoom room) async {
    final me = _me;
    final mine = me == null ? null : room.seats[me];
    final theirs = me == null ? null : room.seats[room.otherOf(me)];
    if (mine == null || theirs == null || _fighting) return;
    setState(() => _fighting = true);
    _seenRun = room.run;
    HapticFeedback.mediumImpact();
    final catalog = context.read<CreatureCatalog>();
    final live = RoomBattleLive(
      rooms: _rooms,
      room: room,
      me: me!,
      settings: context.read<AlchemonsDatabase>().settingsDao,
      onRematch: () => _rematch = true,
    );
    try {
      await Navigator.of(context).push(
        BattleScreen.liveRoute(
          BattleScreen(
            team: mine.members(catalog),
            rival: theirs.members(catalog),
            rivalName: theirs.player.toUpperCase(),
            arena: room.arena,
            leaveLabel: 'BACK TO THE LOBBY',
            live: live,
            // The first fight comes in by the host's place; a rematch
            // straight onto the floor.
            journey: room.run == 1 ? _journey : null,
          ),
        ),
      );
    } finally {
      _fighting = false;
    }
    if (!mounted) return;
    final now = _room;
    if (now == null || _gone) {
      _closed();
      return;
    }
    _recordOf = null;
    unawaited(_loadRecord(now));
    _onRoom(now);
  }

  // ── The guest ───────────────────────────────────────────────────────────

  /// READY (or not): the button turns at once, as the room on this phone
  /// does; the server hears it when it can.
  void _setReady(bool ready) {
    final room = _room;
    if (room == null) return;
    HapticFeedback.selectionClick();
    _rooms.later(_rooms.setReady(room, ready));
  }

  Future<void> _leave() async {
    if (_leaving) return;
    final room = _room;
    if (room != null && _hosting && room.guestSeat != null) {
      final go = await showBracketConfirm(
        context,
        palette: BracketPalette.dark,
        accent: kLeaveDangerAccent,
        title: 'CLOSE THE BATTLE?',
        message: '${room.nameOf(room.guest)} is sent home.',
        cancelLabel: 'STAY',
        confirmLabel: 'CLOSE',
      );
      if (!go || !mounted) return;
    }
    _leaving = true;
    HapticFeedback.selectionClick();
    // Gone at once; the room hears it when it can.
    if (mounted) Navigator.of(context).pop();
    if (room != null) _rooms.later(_rooms.leave(room));
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
            // The host's place, pictured offstage for the way in.
            // (Not while a fight is on: it would only be caught up in it.)
            if (room != null && _journeyOf != room.host && !_fighting)
              BattleJourneyPrep(
                key: ValueKey('journey.${room.host}'),
                host: room.host,
                hostName: room.nameOf(room.host),
                mine: _hosting,
                onReady: (art) {
                  if (!mounted) {
                    art.dispose();
                    return;
                  }
                  _journey?.dispose();
                  setState(() {
                    _journey = art;
                    _journeyOf = room.host;
                  });
                },
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
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 6),
                              _stage(context, room),
                              const SizedBox(height: 18),
                              _you(context, room),
                              const SizedBox(height: 18),
                              _them(context, room),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _status(context, room),
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
    height: 56,
    child: Row(
      children: [
        BracketIconButton(
          icon: AppIcons.arrow_back_rounded,
          onTap: _leave,
          palette: BracketPalette.dark,
          size: 34,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'BATTLE A FRIEND',
            style: bracketText(
              context,
              15,
              _ink,
              weight: FontWeight.w800,
              letterSpacing: 2.6,
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showBattleHowTo(context),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'RULES',
              style: bracketText(
                context,
                10,
                kBattleBrass,
                weight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  /// The host's arena, live, with its name, and the two's head-to-head.
  Widget _stage(BuildContext context, BattleRoom room) {
    final arena = battleArenaOf(room.arena);
    final me = _me;
    final other = me == null ? null : room.otherOf(me);
    final name = room.nameOf(other).toUpperCase();
    final r = _record;
    final record = other == null
        ? 'ASK A FRIEND IN'
        : r.played == 0
        ? 'YOUR FIRST BATTLE WITH $name'
        : 'YOU ${r.wins} – ${r.losses} $name'
              '${r.draws > 0 ? ' · ${r.draws} DRAWN' : ''}';
    return SizedBox(
      height: (MediaQuery.sizeOf(context).height * 0.22).clamp(130.0, 210.0),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: kBattleBrass.withValues(alpha: 0.7),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            BattleArenaPreview(arena: arena.id),
            Positioned(
              left: 12,
              right: 12,
              top: 10,
              child: Text(
                record,
                key: const ValueKey('battle.lobby.record'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: bracketText(
                  context,
                  10,
                  kBattleBrass,
                  weight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Text(
                '${arena.title.toUpperCase()} · '
                '${room.host == me ? 'YOUR ARENA' : '${room.nameOf(room.host).toUpperCase()}\'S ARENA'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: bracketText(
                  context,
                  12,
                  _ink,
                  weight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(
    BuildContext context,
    String text, {
    Color color = _muted,
    (String, VoidCallback)? action,
  }) => Row(
    children: [
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: bracketText(
            context,
            10,
            color,
            weight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
      ),
      if (action != null)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: action.$2,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Text(
              action.$1,
              style: bracketText(
                context,
                10,
                kBattleBrass,
                weight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
          ),
        ),
    ],
  );

  Widget _four(
    List<CosmicPartyMember> four, {
    required bool rival,
    VoidCallback? onTap,
  }) => Row(
    children: [
      for (var i = 0; i < kBattleTeamSize; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: i < four.length
                ? BattleCase(
                    member: four[i],
                    height: rival ? 88 : 100,
                    rival: rival,
                  )
                : BattleEmptyCase(height: rival ? 88 : 100),
          ),
        ),
      ],
    ],
  );

  Widget _you(BuildContext context, BattleRoom room) {
    final between = room.state == BattleRoomState.lobby && !_fighting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(
          context,
          'YOUR FOUR · THE FIRST TWO LEAD',
          action: between ? ('CHANGE', _changeTeam) : null,
        ),
        const SizedBox(height: 8),
        _four(_team, rival: false, onTap: between ? _changeTeam : null),
      ],
    );
  }

  Widget _them(BuildContext context, BattleRoom room) {
    final me = _me;
    final other = me == null ? null : room.otherOf(me);
    final seat = other == null ? null : room.seats[other];
    final name = room.nameOf(other).toUpperCase();
    final between = room.state == BattleRoomState.lobby && !_fighting;
    if (other == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(context, 'THEIR FOUR'),
          const SizedBox(height: 8),
          SizedBox(
            height: 88,
            child: BracketButton(
              key: const ValueKey('battle.lobby.invite'),
              label: 'INVITE A FRIEND',
              palette: BracketPalette.dark,
              accent: kBattleBrass,
              primary: false,
              onTap: _invite,
            ),
          ),
        ],
      );
    }
    final online = _friends?.isOnline(other) ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (online) ...[
              const HomeNoticeDot(color: kFriendOnlineColor, size: 8),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: _label(
                context,
                seat == null ? '$name · ASKED' : '$name\'S FOUR',
                color: kBattleSilver,
                action: _hosting && between ? ('TAKE OUT', _remove) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (seat == null)
          Container(
            height: 88,
            color: _bg1,
            alignment: Alignment.center,
            child: Text(
              'NOT HERE YET',
              style: bracketText(
                context,
                10,
                _muted,
                weight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
          )
        else
          _four(seat.members(context.read<CreatureCatalog>()), rival: true),
      ],
    );
  }

  /// What the room is waiting on, in a line.
  Widget _status(BuildContext context, BattleRoom room) {
    final me = _me;
    final other = me == null ? null : room.otherOf(me);
    final name = room.nameOf(other);
    final guestSeat = room.guestSeat, hostSeat = room.hostSeat;
    final String text;
    if (_fighting || room.state == BattleRoomState.fighting) {
      text = 'The battle is on.';
    } else if (_teamLoaded && _team.isEmpty) {
      text = 'Bring four Alchemons first (Mystics stay home).';
    } else if (other == null) {
      text = 'Invite a friend to battle.';
    } else if (_hosting) {
      if (guestSeat == null) {
        text = 'Waiting for $name to join.';
      } else if (!guestSeat.current) {
        text = '$name needs the latest version of the game.';
      } else if (hostSeat != null && !hostSeat.current) {
        text = 'Your game needs the latest version.';
      } else if (!room.isReady(guestSeat.uid)) {
        text = 'Waiting for $name to be ready.';
      } else {
        text = '$name is ready.';
      }
    } else {
      if (hostSeat != null && !hostSeat.current) {
        text = '$name needs the latest version of the game.';
      } else if (guestSeat != null && !guestSeat.current) {
        text = 'Your game needs the latest version.';
      } else if (me != null && room.isReady(me)) {
        text = 'Waiting for $name to start.';
      } else {
        text = 'Ready up when your four are set.';
      }
    }
    return Text(
      text,
      key: const ValueKey('battle.lobby.status'),
      textAlign: TextAlign.center,
      style: bracketText(context, 12.5, _ink.withValues(alpha: .85)),
    );
  }

  Widget _actions(BuildContext context, BattleRoom room) {
    final me = _me;
    final between = room.state == BattleRoomState.lobby && !_fighting;
    final Widget main;
    if (_hosting) {
      main = BracketButton(
        key: const ValueKey('battle.lobby.start'),
        label: 'START',
        enabled: between && room.canStart,
        onTap: _start,
        palette: BracketPalette.dark,
        accent: kBattleBrass,
        height: 48,
      );
    } else {
      final ready = me != null && room.isReady(me);
      final current =
          (room.guestSeat?.current ?? false) &&
          (room.hostSeat?.current ?? false);
      main = BracketButton(
        key: const ValueKey('battle.lobby.ready'),
        label: ready ? 'NOT READY' : 'READY',
        enabled: between && room.guestSeat != null && current,
        onTap: () => _setReady(!ready),
        palette: BracketPalette.dark,
        accent: kBattleBrass,
        primary: !ready,
        height: 48,
      );
    }
    return Row(
      children: [
        Expanded(
          child: BracketButton(
            label: 'LEAVE',
            onTap: _leave,
            palette: BracketPalette.dark,
            accent: kBattleBrass,
            primary: false,
            height: 48,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: main),
      ],
    );
  }
}

/// The host's INVITE: their friends, those playing now first.
class _InviteSheet extends StatefulWidget {
  const _InviteSheet({
    required this.room,
    required this.rooms,
    required this.friends,
  });

  final BattleRoom room;
  final BattleRoomService rooms;
  final FriendService friends;

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  bool _asking = false;

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
          builder: (context, _) {
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
                      children: [for (final f in list) _row(context, f)],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _row(BuildContext context, FriendCard f) {
    final online = widget.friends.isOnline(f.uid);
    final seen = widget.friends.seenLabel(f.uid);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _asking
          ? null
          : () {
              // Asked at once: the sheet goes, and the lobby shows them asked
              // as the room on this phone does.
              HapticFeedback.selectionClick();
              _asking = true;
              final Future<void> ask;
              try {
                ask = widget.rooms.invite(widget.room, f);
              } on BattleRoomException catch (e) {
                showGameSnack(context, e.message);
                _asking = false;
                return;
              }
              widget.rooms.later(ask);
              Navigator.of(context).pop();
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
              'INVITE',
              style: bracketText(
                context,
                10,
                kBattleBrass,
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
