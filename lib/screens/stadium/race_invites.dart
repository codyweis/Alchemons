// lib/screens/stadium/race_invites.dart
//
// A friend asking to race, wherever the player is: the game's notice at
// the top — "Bo asks you to race · Flare Track" — with JOIN, which opens
// the race's lobby. Each invitation is told once; one missed waits on the
// Trials (and runs out after a while).

import 'package:alchemons/games/stadium/race_room.dart';
import 'package:alchemons/screens/stadium/race_lobby_screen.dart';
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
  final Set<String> _told = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rooms = context.read<RaceRoomService?>();
    if (rooms == _rooms) return;
    _rooms?.removeListener(_changed);
    _rooms = rooms?..addListener(_changed);
    _changed();
  }

  @override
  void dispose() {
    _rooms?.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final rooms = _rooms;
    if (rooms == null) return;
    // One notice at a time: the newest not yet told.
    for (final r in rooms.invites) {
      if (_told.add(r.id)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _tell(r);
        });
        WidgetsBinding.instance.ensureVisualUpdate();
        return;
      }
    }
  }

  void _tell(RaceRoom room) {
    final nav = rootNavigatorKey.currentState;
    final overlay = nav?.overlay;
    if (nav == null || overlay == null) return;
    showGameSnack(
      nav.context,
      '${room.nameOf(room.host)} asks you to race · ${room.course.name}',
      overlay: overlay,
      accent: _brass,
      duration: const Duration(seconds: 14),
      action: SnackBarAction(
        label: 'JOIN',
        onPressed: () => RaceLobbyScreen.open(nav.context, room.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
