// A live battle on two phones in one process (docs/battle/live_pvp_design.md):
// the host's game runs the fight, the guest's game plays it back as a
// replica through a fake network with delay, unevenness and loss, at its
// own uneven frame rate. The guest's taps go back the other way.
//
//   BATTLE_LIVE_REPORT=1 flutter test test/battle_live_test.dart
//     prints how far the guest's creatures stood from the host's.

import 'dart:io';
import 'dart:math';

import 'package:alchemons/games/cosmic/battle_link.dart';
import 'package:alchemons/games/cosmic/battle_wire.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:flutter_test/flutter_test.dart';

import 'battle_test.dart' show battleArena, battleMember;

List<CosmicPartyMember> _team(List<String> four, String tag) => [
  for (final (i, s) in four.indexed)
    battleMember(s.split(':')[0], s.split(':')[1], stat: 4, id: '$tag$i$s'),
];

/// A message on its way, arriving at [at] (wall ms).
class _Msg<T> {
  _Msg(this.at, this.value);
  final double at;
  final T value;
}

/// Two phones and the network between them, run on one wall clock.
class _TwoPhones {
  _TwoPhones({
    required this.host,
    required this.guest,
    required this.hostCenter,
    required this.guestCenter,
    int seed = 1,
    this.drop = 0,
  }) : rng = Random(seed);

  final CosmicGame host, guest;
  final Offset hostCenter, guestCenter;
  final Random rng;

  /// The network: each message takes 150–450 ms, and [drop] of them are
  /// lost.
  final double minMs = 150, maxMs = 450;
  final double drop;

  double wall = 0;
  late final BattleHostLink hostLink;
  late final BattleGuestLink guestLink;
  final List<_Msg<(int, List<int>)>> _toGuest = [];
  final List<_Msg<(List<BattleInput>, int)>> _toHost = [];

  /// The host's phone is asleep (its loop stops), or the guest's network
  /// is out (nothing it sends arrives).
  bool Function(double wall) hostAsleep = (_) => false;
  bool Function(double wall) guestCut = (_) => false;

  /// The host's state each frame, by its real ms: side, creature → where
  /// (from the middle), health, shield.
  final Map<int, Map<(int, int), (Offset, int, int)>> hostFrames = {};
  double _hostReal = 0;

  /// How far each guest creature stood from the host's, each guest frame.
  final List<double> errors = [];
  int healthMismatches = 0;

  /// When each of the guest's inputs was sent, and when the host took it.
  final Map<int, double> sentAt = {};
  final Map<int, double> takenAt = {};

  double _latency() => minMs + rng.nextDouble() * (maxMs - minMs);

  void start(
    List<CosmicPartyMember> hostTeam,
    List<CosmicPartyMember> guestTeam,
  ) {
    hostLink = BattleHostLink(
      game: host,
      now: () => wall.round(),
      send: (seq, packet) {
        if (rng.nextDouble() < drop) return;
        _toGuest.add(_Msg(wall + _latency(), (seq, packet)));
      },
    );
    guestLink = BattleGuestLink(
      now: () => wall.round(),
      send: (inputs, beat) {
        if (guestCut(wall) || rng.nextDouble() < drop) return;
        _toHost.add(_Msg(wall + _latency(), (inputs, beat)));
      },
    );
    host.startBattle(
      home: hostTeam,
      away: guestTeam,
      awayAuto: false,
      center: hostCenter,
      tape: hostLink.tape,
    );
    guest.startBattle(
      home: guestTeam,
      away: hostTeam,
      center: guestCenter,
      replica: guestLink.playback,
    );
  }

  /// Runs both phones until [until] (wall ms), the host at 60 Hz, the
  /// guest unevenly; [guestFrame] runs before each guest frame.
  void run(double until, {void Function()? guestFrame}) {
    var nextHost = wall, nextGuest = wall;
    while (wall < until) {
      if (nextHost <= nextGuest) {
        wall = nextHost;
        nextHost += 1000 / 60;
        if (hostAsleep(wall)) continue;
        final applied = host.battle!.remoteApplied;
        _deliver(_toHost, (m) {
          hostLink.heard(m.$1, m.$2);
        });
        hostLink.tick();
        for (var i = applied; i < host.battle!.remoteApplied; i++) {
          takenAt[i] = wall;
        }
        host.update(1 / 60);
        _hostReal += 1 / 60;
        _recordHost();
      } else {
        wall = nextGuest;
        final dt = 1000 / (50 + rng.nextDouble() * 70);
        nextGuest += dt;
        _deliver(_toGuest, (m) => guestLink.packet(m.$1, m.$2));
        guestFrame?.call();
        guestLink.tick(guest);
        guest.update(dt / 1000);
        _compare();
      }
    }
  }

  void _deliver<T>(List<_Msg<T>> queue, void Function(T) take) {
    queue.sort((a, b) => a.at.compareTo(b.at));
    while (queue.isNotEmpty && queue.first.at <= wall) {
      take(queue.removeAt(0).value);
    }
  }

  void _recordHost() {
    final b = host.battle!;
    final key = (_hostReal * 1000).round();
    hostFrames[key] = {
      for (final side in b.sides)
        for (var i = 0; i < side.creatures.length; i++)
          if (side.creatures[i].body case final body?)
            (side.index, i): (
              body.position - b.center,
              body.currentHp,
              body.shieldHp,
            ),
    };
  }

  /// The guest's field against the host's at the guest's playback time.
  void _compare() {
    final b = guest.battle!;
    final step = b.lastStep;
    final sample = step?.sample;
    if (step == null || sample == null || !guestLink.playback.started) return;
    // The host's frame nearest the playback time.
    final at = step.at.round();
    Map<(int, int), (Offset, int, int)>? frame;
    for (var d = 0; d <= 9 && frame == null; d++) {
      frame = hostFrames[at - d] ?? hostFrames[at + d];
    }
    // The sample the replica stands on, as the host took it.
    final hostSample = hostLink.tape.taken
        .firstWhere((s) => s.at == step.from)
        .mirrored();
    for (final side in b.sides) {
      for (var i = 0; i < side.creatures.length; i++) {
        final body = side.creatures[i].body;
        if (body == null) continue;
        final mine = hostSample.sides[side.index].creatures[i];
        if (mine.onField) {
          if (body.currentHp != mine.hp || body.shieldHp != mine.shield) {
            healthMismatches++;
          }
        }
        final theirs = frame?[(1 - side.index, i)];
        if (theirs == null) continue;
        final mirrored = -theirs.$1;
        errors.add(((body.position - b.center) - mirrored).distance);
      }
    }
  }
}

Future<_TwoPhones> _phones({int seed = 1, double drop = 0}) async {
  final (host, hc) = await battleArena();
  final (guest, gc) = await battleArena();
  return _TwoPhones(
    host: host,
    guest: guest,
    hostCenter: hc,
    guestCenter: gc,
    seed: seed,
    drop: drop,
  );
}

final _hostFour = _team([
  'Horn:Fire',
  'Mask:Spirit',
  'Mane:Lightning',
  'Kin:Fire',
], 'h');
final _guestFour = _team([
  'Wing:Dust',
  'Mask:Air',
  'Let:Ice',
  'Pip:Earth',
], 'g');

double _pct(List<double> v, double p) {
  if (v.isEmpty) return 0;
  final s = [...v]..sort();
  return s[(s.length * p).floor().clamp(0, s.length - 1)];
}

void main() {
  final report = Platform.environment['BATTLE_LIVE_REPORT'] == '1';

  group('the wire', () {
    test('a packet comes back as it went, and turned twice is itself', () {
      final sample = BattleSample(
        at: 1234,
        clock: 1.5,
        timeScale: 0.45,
        applied: 3,
        sides: [
          BattleSideSample(
            spots: [2, null],
            swapsLeft: 1,
            focus: 0,
            auto: false,
            creatures: [
              const BattleCreatureSample(place: BattlePlace.fallen, share: 0),
              const BattleCreatureSample(
                place: BattlePlace.bench,
                share: 0.42,
                cooldown: 3.25,
              ),
              const BattleCreatureSample(
                place: BattlePlace.field,
                at: Offset(-120.5, 310.2),
                hp: 812,
                maxHp: 1400,
                shield: 40,
                cooldown: 2.1,
                life: 4.5,
                faceRight: true,
                phoenixSpent: true,
                burning: true,
                poisoned: true,
              ),
            ],
          ),
          const BattleSideSample(
            spots: [0, 1],
            swapsLeft: 2,
            focus: null,
            auto: true,
            creatures: [
              BattleCreatureSample(
                place: BattlePlace.field,
                at: Offset(10, -300),
                hp: 5,
                maxHp: 900,
              ),
              BattleCreatureSample(
                place: BattlePlace.field,
                at: Offset(-90, -280),
                hp: 900,
                maxHp: 900,
              ),
            ],
          ),
        ],
      );
      final cast = const BattleCast(
        origin: Offset(-100, 300),
        angle: -2.5,
        target: Offset(40, -250),
        seed: 99,
      );
      final packet = BattlePacket(
        samples: [sample],
        events: [
          BattleWireEvent(
            seq: 7,
            kind: BattleWireKind.special,
            side: 0,
            creature: 2,
            at: 1200,
            clock: 1.45,
            data: cast.data,
          ),
          BattleWireEvent(
            seq: 8,
            kind: BattleWireKind.end,
            side: 0,
            creature: 0,
            at: 1300,
            clock: 1.5,
            data: const BattleEnding(
              winner: 1,
              end: BattleWireEnd.fieldEmpty,
              tallies: [
                [(1, 2, 3), (4, 5, 6), (7, 8, 9)],
                [(10, 11, 12), (13, 14, 15)],
              ],
            ).data,
          ),
        ],
      );
      final back = BattlePacket.decode(packet.encode())!;
      expect(back.encode(), packet.encode());
      final s = back.samples.single;
      expect(s.sides[0].spots, [2, null]);
      expect(s.sides[0].creatures[2].at, const Offset(-120.5, 310.2));
      expect(s.sides[0].creatures[2].faceRight, isTrue);
      expect(s.sides[0].creatures[1].cooldown, 3.25);
      // What lingers travels too.
      expect(s.sides[0].creatures[2].burning, isTrue);
      expect(s.sides[0].creatures[2].poisoned, isTrue);
      expect(s.sides[0].creatures[2].interrupted, isFalse);
      expect(s.sides[1].auto, isTrue);
      // Turned twice: itself.
      expect(packet.mirrored().mirrored().encode(), packet.encode());
      // Turned once: the sides change places, and everything turns about
      // the middle.
      final m = packet.mirrored();
      expect(
        m.samples.single.sides[1].creatures[2].at,
        const Offset(120.5, -310.2),
      );
      expect(m.samples.single.sides[1].creatures[2].faceRight, isFalse);
      final mc = BattleCast.fromData(m.events.first.data);
      expect(m.events.first.side, 1);
      expect(mc.origin, const Offset(100, -300));
      expect(mc.angle, closeTo(-2.5 + pi, 1e-3));
      final ending = BattleEnding.fromData(m.events.last.data);
      expect(ending.winner, 0);
      expect(ending.tallies.first.length, 2);
      // Another version's packet is not read.
      expect(BattlePacket.decode([kBattleLinkVersion + 1, 0, 0]), isNull);
      expect(BattlePacket.decode([kBattleLinkVersion, 3]), isNull);
    });

    test(
      'playback runs behind, smooths between samples, and holds when starved',
      () {
        BattleSample at(int ms, double x) => BattleSample(
          at: ms,
          clock: ms / 1000,
          timeScale: 1,
          applied: 0,
          sides: [
            BattleSideSample(
              spots: const [0, null],
              swapsLeft: 2,
              focus: null,
              auto: false,
              creatures: [
                BattleCreatureSample(
                  place: BattlePlace.field,
                  at: Offset(x, 0),
                  hp: 10,
                  maxHp: 10,
                ),
              ],
            ),
            const BattleSideSample(
              spots: [null, null],
              swapsLeft: 2,
              focus: null,
              auto: false,
              creatures: [],
            ),
          ],
        );
        final p = BattlePlayback(delayMs: 300);
        p.add(
          0,
          BattlePacket(
            samples: [at(0, 0), at(100, 10), at(200, 20)],
            events: const [],
          ),
        );
        // The same packet again changes nothing.
        p.add(0, BattlePacket(samples: [at(0, 0)], events: const []));
        var step = p.advance(16);
        expect(step.sample!.at, 0);
        p.add(
          1,
          BattlePacket(
            samples: [at(300, 30), at(400, 40), at(500, 50)],
            events: const [],
          ),
        );
        for (var i = 0; i < 12; i++) {
          step = p.advance(16);
        }
        // About the newest less the delay, and between two samples.
        expect(p.behind, inInclusiveRange(150, 450));
        final x = step.sample!.sides[0].creatures[0].at.dx;
        expect(x, closeTo(step.at / 10, 0.01));
        // Nothing new: it catches up to the newest and holds there.
        for (var i = 0; i < 60; i++) {
          step = p.advance(16);
        }
        expect(p.starved, isTrue);
        expect(step.sample!.sides[0].creatures[0].at.dx, 50);
        expect(step.fightDt, 0);
      },
    );
  });

  group('two phones', () {
    test('the guest sees the host\'s fight, turned, and its taps land', () async {
      final phones = await _phones();
      phones.start(_hostFour, _guestFour);
      final hostB = phones.host.battle!;
      final guestB = phones.guest.battle!;
      int? swapIndex;
      int? swapCreature;
      var focused = false;
      phones.run(
        130000,
        guestFrame: () {
          final t = phones.wall;
          // The guest picks a focus at 4 s: drawn at once on its own phone.
          if (!focused && t >= 4000) {
            focused = true;
            final i = phones.guestLink.input(const BattleInput.focus(1));
            phones.sentAt[i] = t;
            phones.guest.predictBattleFocus(1, i);
            expect(guestB.sides[0].focus, 1);
          }
          // A swap at 12 s, of the first on the bench that can come on.
          if (swapIndex == null && t >= 12000 && !guestB.over) {
            final side = guestB.sides[0];
            final bench = side.bench.toList();
            final out = side.at(0)?.body;
            if (bench.isNotEmpty && out != null && out.life > 1.5) {
              swapCreature = bench.first;
              swapIndex = phones.guestLink.input(
                BattleInput.swap(bench.first, 0),
              );
              phones.sentAt[swapIndex!] = t;
            }
          }
          if (hostB.over && guestB.over && t > 125000) return;
        },
      );
      expect(hostB.over, isTrue);
      expect(guestB.over, isTrue, reason: 'the guest saw the end');
      // The same result, turned.
      final hw = hostB.result!.winner;
      expect(guestB.result!.winner, hw == null ? null : 1 - hw);
      expect(guestB.result!.end, hostB.result!.end);
      // The host took the focus, and the guest's side went for it there.
      expect(phones.takenAt.containsKey(0), isTrue);
      expect(phones.takenAt[0]! - phones.sentAt[0]!, lessThan(450 + 17 + 1));
      // The swap landed on the host within the network's delay and a frame,
      // and came back to the guest as a swap of its own side.
      if (swapIndex != null) {
        final i = swapIndex!;
        expect(phones.takenAt[i]! - phones.sentAt[i]!, lessThan(450 + 17 + 1));
        final swapped = hostB.log.any(
          (e) =>
              e.kind == BattleEventKind.swap &&
              e.side == 1 &&
              e.creature == swapCreature,
        );
        if (swapped) {
          expect(
            guestB.log.any(
              (e) =>
                  e.kind == BattleEventKind.swap &&
                  e.side == 0 &&
                  e.creature == swapCreature,
            ),
            isTrue,
          );
        }
      }
      // Every host event reached the guest, turned, in order.
      expect(guestB.log.length, hostB.log.length);
      for (var i = 0; i < hostB.log.length; i++) {
        final h = hostB.log[i], g = guestB.log[i];
        expect((g.kind, g.side, g.creature), (h.kind, 1 - h.side, h.creature));
      }
      // Each special the host cast was cast again on the guest's phone.
      final specials = hostB.log
          .where((e) => e.kind == BattleEventKind.special)
          .length;
      expect(specials, greaterThan(4));
      expect(guestB.replayedCasts, specials);
      // Health exactly the host's; places within a few pixels of it.
      expect(phones.healthMismatches, 0);
      final p95 = _pct(phones.errors, 0.95);
      if (report) {
        stdout.writeln(
          'guest vs host: ${phones.errors.length} looks, '
          'p50 ${_pct(phones.errors, .5).toStringAsFixed(2)} px, '
          'p95 ${p95.toStringAsFixed(2)} px, max ${_pct(phones.errors, 1).toStringAsFixed(1)} px; '
          'fight ${hostB.result!.at.toStringAsFixed(1)} s, ${hostB.log.length} events, '
          '${phones.hostLink.tape.packetsSent} packets',
        );
      }
      expect(p95, lessThan(6));
      // The guest's own side is at the bottom of its phone.
      expect(
        guestB.sides[0].creatures.first.member.instanceId,
        _guestFour.first.instanceId,
      );
    }, timeout: const Timeout(Duration(minutes: 3)));

    test(
      'a fifth of the packets lost: the guest still has the host\'s fight',
      () async {
        final phones = await _phones(seed: 5, drop: 0.2);
        phones.start(_hostFour, _guestFour);
        phones.run(110000);
        final hostB = phones.host.battle!;
        final guestB = phones.guest.battle!;
        expect(hostB.over, isTrue);
        expect(guestB.over, isTrue);
        final hw = hostB.result!.winner;
        expect(guestB.result!.winner, hw == null ? null : 1 - hw);
        expect(phones.healthMismatches, 0);
        // Who stood where at the end, and their health, the same.
        for (final side in hostB.sides) {
          final mine = guestB.sides[1 - side.index];
          expect(mine.spots, side.spots);
          for (var i = 0; i < side.creatures.length; i++) {
            expect(mine.creatures[i].fallen, side.creatures[i].fallen);
            expect(
              mine.creatures[i].body?.currentHp,
              side.creatures[i].body?.currentHp,
            );
          }
        }
        if (report) {
          stdout.writeln(
            'lossy: p95 ${_pct(phones.errors, .95).toStringAsFixed(2)} px, '
            'events ${guestB.log.length}/${hostB.log.length}',
          );
        }
        // Events can be lost only past the repeat window; there were none.
        expect(guestB.log.length, hostB.log.length);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'the host asleep: the guest waits, picks up again, and after 30 s it is no contest',
      () async {
        final phones = await _phones(seed: 3);
        // Asleep for 5 s from 8 s, then for good from 20 s.
        phones.hostAsleep = (t) => (t >= 8000 && t < 13000) || t >= 20000;
        phones.start(_hostFour, _guestFour);
        var waited = false, resumed = false;
        phones.run(
          13000,
          guestFrame: () {
            if (phones.guestLink.waiting) waited = true;
          },
        );
        phones.run(
          16000,
          guestFrame: () {
            if (waited && !phones.guestLink.waiting) resumed = true;
          },
        );
        expect(waited, isTrue);
        expect(resumed, isTrue);
        expect(phones.guest.battle!.over, isFalse);
        phones.run(20000 + 29000);
        expect(phones.guest.battle!.over, isFalse);
        phones.run(20000 + 32000);
        expect(phones.guest.battle!.over, isTrue);
        expect(phones.guest.battle!.result!.end, BattleEnd.noContest);
        expect(phones.guest.battle!.result!.winner, isNull);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'the guest silent 7 s: the computer plays their side, then gives it back',
      () async {
        final phones = await _phones(seed: 4);
        phones.guestCut = (t) => t >= 3000 && t < 10000;
        phones.start(_hostFour, _guestFour);
        var away = false;
        phones.run(
          12000,
          guestFrame: () {
            if (phones.hostLink.away) away = true;
          },
        );
        expect(away, isTrue);
        // Heard again: their side is theirs again.
        expect(phones.hostLink.away, isFalse);
        expect(phones.host.battle!.sides[1].auto, isFalse);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test('the guest concedes: the host wins, and the guest is told', () async {
      final phones = await _phones(seed: 6);
      phones.start(_hostFour, _guestFour);
      phones.run(
        9000,
        guestFrame: () {
          if (phones.wall >= 5000 && phones.guestLink.inputs.isEmpty) {
            phones.guestLink.input(const BattleInput.concede());
          }
        },
      );
      final hostB = phones.host.battle!;
      expect(hostB.result?.winner, 0);
      expect(hostB.result?.end, BattleEnd.conceded);
      expect(phones.guest.battle!.result?.winner, 1);
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  test(
    'the fight against the computer is unchanged by a link it does not have',
    () async {
      final (game, home) = await battleArena();
      final b = game.startBattle(
        home: _hostFour,
        away: _guestFour,
        homeAuto: true,
        center: home,
      );
      var t = 0.0;
      while (!b.over && t < 100) {
        game.update(1 / 60);
        t += 1 / 60;
      }
      expect(b.over, isTrue);
      expect(b.tape, isNull);
      expect(b.isReplica, isFalse);
      // Specials carry their cast for a guest that is not there.
      final special = b.log.firstWhere(
        (e) => e.kind == BattleEventKind.special,
      );
      expect(special.data.length, 6);
    },
  );
}
