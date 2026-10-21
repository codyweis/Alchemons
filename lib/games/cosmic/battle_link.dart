// lib/games/cosmic/battle_link.dart
//
// The two ends of a live battle (docs/battle/live_pvp_design.md), between a
// phone's game and whatever carries the packets (Firestore in the game,
// services/battle_room_service.dart; a fake wire in the tests).
//
//  • The host's end: the game's tape goes out; the guest's inputs come in
//    as a whole list each time, with a beat, and the new ones are played on
//    the guest's side. A guest heard from not at all for [kBattleAwayMs] is
//    away: the computer plays their side until they are heard again, and
//    the result stands.
//  • The guest's end: packets come in, are turned to this phone's side and
//    played back; this phone's taps go out, the whole list each time, with
//    a beat every two seconds. Nothing from the host for [kBattleWaitMs]
//    shows as waiting for them; for [kBattleLostMs], the fight is no
//    contest.

import 'package:alchemons/games/cosmic/battle_wire.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';

/// A guest silent this long is away.
const int kBattleAwayMs = 6000;

/// Nothing from the host this long: waiting for them.
const int kBattleWaitMs = 3000;

/// Nothing from the host this long: no contest.
const int kBattleLostMs = 30000;

/// How often the guest beats when it has nothing to send.
const int kBattleBeatMs = 2000;

/// The host's end.
class BattleHostLink {
  BattleHostLink({
    required this.game,
    required void Function(int seq, List<int> packet) send,
    required this.now,
  }) : tape = BattleTape(send: send),
       _heardAt = now();

  final CosmicGame game;
  final BattleTape tape;

  /// This phone's clock, in milliseconds.
  final int Function() now;

  int _heardAt;
  int _beat = -1;
  List<BattleInput> _inputs = const [];

  /// Whether the guest is away now.
  bool get away => game.battle?.sides[1].auto ?? false;

  /// The guest's inputs so far this fight, and their beat, as just heard.
  void heard(List<BattleInput> inputs, int beat) {
    if (beat != _beat || inputs.length != _inputs.length) {
      _heardAt = now();
      _beat = beat;
    }
    _inputs = inputs;
    _apply();
  }

  void _apply() {
    final b = game.battle;
    if (b == null) return;
    while (b.remoteApplied < _inputs.length) {
      game.applyRemoteBattleInput(_inputs[b.remoteApplied]);
    }
  }

  /// Now and then on the host: is the guest away, or back?
  void tick() {
    final silent = now() - _heardAt;
    game.setBattleSideAway(1, silent > kBattleAwayMs);
    _apply();
  }
}

/// The guest's end.
class BattleGuestLink {
  BattleGuestLink({
    required this.send,
    required this.now,
    int delayMs = kBattleGuestDelayMs,
  }) : playback = BattlePlayback(delayMs: delayMs),
       _heardAt = now(),
       _beatAt = now();

  /// Sends this phone's inputs (all of them) and its beat.
  final void Function(List<BattleInput> inputs, int beat) send;

  /// This phone's clock, in milliseconds.
  final int Function() now;

  final BattlePlayback playback;
  final List<BattleInput> _inputs = [];
  int _beat = 0;
  int _heardAt;
  int _beatAt;
  bool _lost = false;

  List<BattleInput> get inputs => List.unmodifiable(_inputs);

  /// Waiting for the host: nothing heard for a while.
  bool get waiting => now() - _heardAt > kBattleWaitMs;

  /// The host is lost: the fight is no contest.
  bool get lost => _lost;

  /// Packet number [seq] from the host, as it came.
  void packet(int seq, List<int> ints) {
    final p = BattlePacket.decode(ints);
    if (p == null) return;
    _heardAt = now();
    playback.add(seq, p.mirrored());
  }

  /// This phone's tap: sent, with the rest. Returns its number.
  int input(BattleInput input) {
    _inputs.add(input);
    _send();
    return _inputs.length - 1;
  }

  void _send() {
    _beat++;
    _beatAt = now();
    send(List.of(_inputs), _beat);
  }

  /// Now and then on the guest: a beat when one is due; no contest once
  /// the host has been gone long enough.
  void tick(CosmicGame game) {
    final t = now();
    if (t - _beatAt >= kBattleBeatMs) _send();
    final b = game.battle;
    if (!_lost && b != null && !b.over && t - _heardAt > kBattleLostMs) {
      _lost = true;
      game.endBattleNoContest();
    }
  }
}
