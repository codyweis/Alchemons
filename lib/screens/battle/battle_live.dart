// lib/screens/battle/battle_live.dart
//
// A battle fought live with a friend, as the battle screen plays it
// (docs/battle/live_pvp_design.md). The lobby (battle_lobby_screen.dart)
// makes one for each fight; the screen starts the fight through it, sends
// the guest's taps through it, and tells it when the fight is over.
//
// The defaults (the author, 2026-10-21): nothing is paid, and each phone
// keeps a head-to-head with that friend; if the guest drops, the computer
// plays their side and the result stands; a host gone for 30 s is no
// contest; leaving concedes.

import 'dart:async';

import 'package:alchemons/database/daos/settings_dao.dart';
import 'package:alchemons/games/cosmic/battle_link.dart';
import 'package:alchemons/games/cosmic/battle_wire.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/models/battle_record.dart';
import 'package:alchemons/models/battle_room.dart';
import 'package:alchemons/services/battle_room_service.dart';
import 'package:flutter/foundation.dart';

/// What the battle screen needs of a live battle.
abstract class BattleLive {
  /// This phone runs the fight; otherwise it shows the host's.
  bool get hosting;

  /// The friend's name.
  String get friendName;

  /// When the fight starts, on this phone's clock (ms since the epoch).
  int get startAtMs;

  /// This phone's clock (ms since the epoch).
  int nowMs();

  /// Starts the fight in [game]: [team] (this phone's four) against
  /// [rival] in [arena].
  CosmicBattle begin(
    CosmicGame game, {
    required List<CosmicPartyMember> team,
    required List<CosmicPartyMember> rival,
    required String arena,
  });

  /// The guest's tap, sent to the host; its number.
  int send(BattleInput input);

  /// Each frame.
  void tick(CosmicGame game);

  /// The guest: nothing from the host for a while.
  bool get waiting;

  /// The host: the guest is away, and the computer plays their side.
  bool get friendAway;

  /// The fight is over on this phone.
  Future<void> finished(CosmicBattle battle);

  /// LEAVE in the middle of it: this phone's side gives the fight up. It
  /// returns at once; what goes to the room goes when it can.
  void concede(CosmicGame game);

  /// REMATCH on the result card.
  void rematch();

  void dispose();
}

/// A live battle in a room (services/battle_room_service.dart).
class RoomBattleLive implements BattleLive {
  RoomBattleLive({
    required this.rooms,
    required BattleRoom room,
    required this.me,
    required this.settings,
    required this.onRematch,
    int Function()? now,
  }) : roomId = room.id,
       run = room.run,
       hosting = room.host == me,
       friend = room.otherOf(me) ?? '',
       friendName = room.nameOf(room.otherOf(me)),
       startAtMs = rooms.localMs(room.startAt ?? rooms.serverNowMs()),
       _room = room,
       _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final BattleRoomService rooms;
  final String roomId;
  final int run;
  final String me;
  final String friend;

  /// Where the head-to-head is kept.
  final SettingsDao settings;

  /// The lobby readies (or starts) the next fight.
  final VoidCallback onRematch;

  final int Function() _now;

  @override
  final bool hosting;

  @override
  final String friendName;

  @override
  final int startAtMs;

  BattleRoom? _room;
  CosmicGame? _game;
  BattleHostLink? _host;
  BattleGuestLink? _guest;
  final List<StreamSubscription<Object?>> _subs = [];
  bool _closed = false, _recorded = false;

  @override
  CosmicBattle begin(
    CosmicGame game, {
    required List<CosmicPartyMember> team,
    required List<CosmicPartyMember> rival,
    required String arena,
  }) {
    _game = game;
    _subs.add(rooms.watch(roomId).listen(_onRoom));
    if (hosting) {
      final host = _host = BattleHostLink(
        game: game,
        now: _now,
        send: (seq, packet) => rooms.sendPacket(roomId, run, seq, packet),
      );
      final b = game.startBattle(
        home: team,
        away: rival,
        awayAuto: false,
        center: game.ship.pos,
        arena: arena,
        tape: host.tape,
      );
      if (_room case final room?) _onRoom(room);
      return b;
    }
    final guest = _guest = BattleGuestLink(
      now: _now,
      send: (inputs, beat) => rooms.sendInputs(roomId, run, inputs, beat),
    );
    _subs.add(
      rooms.packets(roomId, run).listen((p) => guest.packet(p.$1, p.$2)),
    );
    return game.startBattle(
      home: team,
      away: rival,
      center: game.ship.pos,
      arena: arena,
      replica: guest.playback,
    );
  }

  void _onRoom(BattleRoom? room) {
    _room = room ?? _room;
    final game = _game;
    final b = game?.battle;
    if (game == null || b == null) return;
    if (room == null) {
      // The host closed the room in the middle of it: they left it.
      if (!hosting) game.concedeBattle(1);
      return;
    }
    if (hosting) {
      // The friend left the room in the middle of it.
      if (room.guest != friend) {
        game.concedeBattle(1);
        return;
      }
      _host?.heard(room.inputsFor(run), room.beat);
      return;
    }
    // The room has the end the stream never brought.
    final result = room.result;
    if (!b.over && result != null && result.run == run) {
      game.settleBattle(
        winner: result.winner == null ? null : (result.winner == me ? 0 : 1),
        end: _endOf(result.end),
      );
    }
  }

  static BattleEnd _endOf(BattleWireEnd end) => switch (end) {
    BattleWireEnd.fieldEmpty => BattleEnd.fieldEmpty,
    BattleWireEnd.timeUp => BattleEnd.timeUp,
    BattleWireEnd.conceded => BattleEnd.conceded,
    BattleWireEnd.noContest => BattleEnd.noContest,
  };

  @override
  int nowMs() => _now();

  @override
  int send(BattleInput input) => _guest?.input(input) ?? -1;

  @override
  void tick(CosmicGame game) {
    _host?.tick();
    _guest?.tick(game);
    final b = game.battle;
    // The host keeps the stream going a moment past the end, so the guest
    // sees the last of it, then brings the room back.
    if (hosting && b != null && b.over && (b.sinceEnd ?? 0) > 3) {
      unawaited(_close(b));
    }
  }

  @override
  bool get waiting => _guest?.waiting ?? false;

  @override
  bool get friendAway => _host?.away ?? false;

  @override
  Future<void> finished(CosmicBattle battle) async {
    final r = battle.result;
    if (r == null || _recorded || r.end == BattleEnd.noContest) return;
    _recorded = true;
    final key = BattleRecord.friendKey(friend);
    final record = await BattleRecord.load(settings, key: key);
    await record.after(r.winner).save(settings, key: key);
  }

  @override
  void concede(CosmicGame game) {
    final b = game.battle;
    if (b == null || b.over) return;
    if (hosting) {
      game.concedeBattle(0);
      // The end goes out at once: this phone stops sending as it leaves.
      _host?.tape.flush(_now());
      unawaited(finished(b));
      unawaited(_close(b));
      return;
    }
    send(const BattleInput.concede());
    game.concedeBattle(0);
    unawaited(finished(b));
  }

  /// The host: the fight is over, and the room is back to gathering.
  Future<void> _close(CosmicBattle b) async {
    final room = _room;
    final r = b.result;
    if (_closed || room == null || r == null || !hosting) return;
    _closed = true;
    try {
      // Not waited on by the screen (it has gone on): what comes back is
      // only the server's word.
      await rooms.finish(
        room,
        BattleRoomResult(
          run: run,
          winner: switch (r.winner) {
            0 => me,
            1 => friend,
            _ => null,
          },
          end: switch (r.end) {
            BattleEnd.fieldEmpty => BattleWireEnd.fieldEmpty,
            BattleEnd.timeUp => BattleWireEnd.timeUp,
            BattleEnd.conceded => BattleWireEnd.conceded,
            BattleEnd.noContest => BattleWireEnd.noContest,
          },
        ),
      );
    } on BattleRoomException catch (e) {
      debugPrint('RoomBattleLive: the room was not brought back: $e');
    }
  }

  @override
  void rematch() => onRematch();

  @override
  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    // Left before the stream's last moment: the room comes back now.
    final b = _game?.battle;
    if (hosting && b != null && b.over) unawaited(_close(b));
  }
}
