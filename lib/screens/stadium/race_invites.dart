// lib/screens/stadium/race_invites.dart
//
// A friend asking to race, wherever the player is: the game's notice at
// the top — "Bo asks you to race · Flare Track" — with JOIN, which opens
// the race's lobby, and DECLINE, which says no (the host sees the lane
// free). Each invitation is told once; one missed waits on the Trials
// (and runs out after a while). A friend asking to battle is told the same
// way: "Bo asks you to battle · Glass Orrery".

import 'package:alchemons/games/stadium/race_room.dart';
import 'package:alchemons/models/battle_arenas.dart';
import 'package:alchemons/models/battle_room.dart';
import 'package:alchemons/screens/battle/battle_lobby_screen.dart';
import 'package:alchemons/screens/stadium/race_lobby_screen.dart';
import 'package:alchemons/services/battle_room_service.dart';
import 'package:alchemons/services/race_room_service.dart';
import 'package:alchemons/utils/app_scaffold_messenger.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const Color _brass = Color(0xFFCDB07A);

class RaceInvites extends StatefulWidget {
  const RaceInvites({super.key, required this.child});

  final Widget child;

  @override
  State<RaceInvites> createState() => _RaceInvitesState();
}

class _RaceInvitesState extends State<RaceInvites> {
  RaceRoomService? _rooms;
  BattleRoomService? _battles;
  final Set<String> _told = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rooms = context.read<RaceRoomService?>();
    if (rooms != _rooms) {
      _rooms?.removeListener(_changed);
      _rooms = rooms?..addListener(_changed);
    }
    final battles = context.read<BattleRoomService?>();
    if (battles != _battles) {
      _battles?.removeListener(_changed);
      _battles = battles?..addListener(_changed);
    }
    _changed();
  }

  @override
  void dispose() {
    _rooms?.removeListener(_changed);
    _battles?.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    // One notice at a time: the newest not yet told.
    for (final r in _rooms?.invites ?? const <RaceRoom>[]) {
      if (_told.add(r.id)) {
        _soon(() => _tell(r));
        return;
      }
    }
    for (final r in _battles?.invites ?? const <BattleRoom>[]) {
      if (_told.add('battle:${r.id}')) {
        _soon(() => _tellBattle(r));
        return;
      }
    }
  }

  void _soon(VoidCallback tell) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) tell();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _tellBattle(BattleRoom room) {
    final nav = rootNavigatorKey.currentState;
    final overlay = nav?.overlay;
    final battles = _battles;
    if (nav == null || overlay == null || battles == null) return;
    showGameSnack(
      nav.context,
      '${room.nameOf(room.host)} asks you to battle · '
      '${battleArenaOf(room.arena).title}',
      overlay: overlay,
      accent: _brass,
      duration: const Duration(seconds: 14),
      secondary: SnackBarAction(
        label: 'DECLINE',
        onPressed: () => battles.decline(room),
      ),
      action: SnackBarAction(
        label: 'JOIN',
        onPressed: () => BattleLobbyScreen.open(nav.context, room.id),
      ),
    );
  }

  void _tell(RaceRoom room) {
    final nav = rootNavigatorKey.currentState;
    final overlay = nav?.overlay;
    final rooms = _rooms;
    if (nav == null || overlay == null || rooms == null) return;
    showGameSnack(
      nav.context,
      '${room.nameOf(room.host)} asks you to race · ${room.placeName}',
      overlay: overlay,
      accent: _brass,
      duration: const Duration(seconds: 14),
      secondary: SnackBarAction(
        label: 'DECLINE',
        onPressed: () => rooms.decline(room),
      ),
      action: SnackBarAction(
        label: 'JOIN',
        onPressed: () => RaceLobbyScreen.open(nav.context, room.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
