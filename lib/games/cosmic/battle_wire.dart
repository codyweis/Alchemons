// lib/games/cosmic/battle_wire.dart
//
// A battle fought live between two phones (docs/battle/live_pvp_design.md):
// what goes between them. The host's phone runs the real fight; the guest's
// runs the same fight as a replica of it, from what the host sends:
//
//  • samples, ten a second: who stands where, their health, shields and
//    specials' waits, who each side goes for, swaps left, the bench's
//    health. Each is whole, so one lost costs nothing.
//  • events: each special as it was cast (where from, which way, at what,
//    and the seed its scatter came from, so the guest's cast lands the same),
//    the summons, swaps, falls, a phoenix, and the end.
//
// Four packets a second carry them, each with the samples since the last
// and the events of the last few seconds again, numbered, so a packet lost
// leaves no gap. The guest plays them back a little behind the newest
// (BattlePlayback), smoothing positions between samples.
//
// The guest sees its own side at the bottom, so on the guest's phone the
// two sides are the other way round: everything from the host is turned
// half a turn about the floor's middle as it arrives (mirrored()). The
// floor is the same under that turn.
//
// The guest's taps go the other way as BattleInputs: a focus, a bench one
// called in, a swap, a concession.
//
// Pure Dart: Firestore (services/battle_room_service.dart) and the tests'
// fake wire both carry these as lists of ints.

import 'dart:math';
import 'dart:ui' show Offset;

/// The link this game speaks: a phone of another version cannot battle
/// this one (the lobby says so). 2: what lingers (burn, poison, an
/// interrupt) travels with each creature, and the fight has typing.
const int kBattleLinkVersion = 2;

/// How often the host samples the fight, in its own milliseconds.
const int kBattleSampleMs = 100;

/// How often the host sends a packet.
const int kBattlePacketMs = 250;

/// How far back each packet repeats the events.
const int kBattleEventsWindowMs = 6000;

/// The most events one packet repeats.
const int kBattleEventsPerPacket = 32;

/// The stream's documents: each is written every [kBattleStreamSlots]
/// packets, well under Firestore's one write a second to a document.
const int kBattleStreamSlots = 8;

/// How far the guest plays behind the newest sample it has: enough for
/// Firestore's usual delays and their unevenness.
const int kBattleGuestDelayMs = 800;

/// Where one of a side's creatures is.
enum BattlePlace { bench, field, fallen }

/// One creature in a sample.
class BattleCreatureSample {
  const BattleCreatureSample({
    required this.place,
    this.at = Offset.zero,
    this.hp = 0,
    this.maxHp = 0,
    this.shield = 0,
    this.cooldown,
    this.life = 0,
    this.faceRight,
    this.share = 1,
    this.phoenixSpent = false,
    this.burning = false,
    this.poisoned = false,
    this.interrupted = false,
  });

  final BattlePlace place;

  /// On the field: where it stands, from the floor's middle.
  final Offset at;
  final int hp, maxHp, shield;

  /// Its special's wait (on the bench, the wait it went back with).
  final double? cooldown;

  /// On the field: how long it has been there.
  final double life;
  final bool? faceRight;

  /// Off the field: its health share.
  final double share;
  final bool phoenixSpent;

  /// What lingers on it, to show: a burn, a poison, a freeze's interrupt
  /// just now.
  final bool burning, poisoned, interrupted;

  bool get onField => place == BattlePlace.field;

  BattleCreatureSample mirrored() => BattleCreatureSample(
    place: place,
    at: -at,
    hp: hp,
    maxHp: maxHp,
    shield: shield,
    cooldown: cooldown,
    life: life,
    faceRight: faceRight == null ? null : !faceRight!,
    share: share,
    phoenixSpent: phoenixSpent,
    burning: burning,
    poisoned: poisoned,
    interrupted: interrupted,
  );

  static const int ints = 8;

  void writeTo(List<int> out) {
    var flags = place.index;
    if (faceRight != null) flags |= 4;
    if (faceRight == true) flags |= 8;
    if (phoenixSpent) flags |= 16;
    if (burning) flags |= 32;
    if (poisoned) flags |= 64;
    if (interrupted) flags |= 128;
    final cd = cooldown == null ? -1 : (cooldown! * 100).round();
    if (onField) {
      out.addAll([
        flags,
        (at.dx * 10).round(),
        (at.dy * 10).round(),
        hp,
        maxHp,
        shield,
        cd,
        (life * 100).round(),
      ]);
    } else {
      out.addAll([flags, (share * 10000).round(), 0, hp, maxHp, 0, cd, 0]);
    }
  }

  static BattleCreatureSample read(List<int> v, int i) {
    final flags = v[i];
    final place = BattlePlace.values[(flags & 3).clamp(0, 2)];
    final cd = v[i + 6] < 0 ? null : v[i + 6] / 100;
    final face = flags & 4 == 0 ? null : flags & 8 != 0;
    final phoenix = flags & 16 != 0;
    if (place == BattlePlace.field) {
      return BattleCreatureSample(
        place: place,
        at: Offset(v[i + 1] / 10, v[i + 2] / 10),
        hp: v[i + 3],
        maxHp: v[i + 4],
        shield: v[i + 5],
        cooldown: cd,
        life: v[i + 7] / 100,
        faceRight: face,
        phoenixSpent: phoenix,
        burning: flags & 32 != 0,
        poisoned: flags & 64 != 0,
        interrupted: flags & 128 != 0,
      );
    }
    return BattleCreatureSample(
      place: place,
      share: v[i + 1] / 10000,
      hp: v[i + 3],
      maxHp: v[i + 4],
      cooldown: cd,
      phoenixSpent: phoenix,
    );
  }
}

/// One side in a sample.
class BattleSideSample {
  const BattleSideSample({
    required this.spots,
    required this.swapsLeft,
    required this.focus,
    required this.auto,
    required this.creatures,
  });

  /// Which creature stands in each field place; null is empty.
  final List<int?> spots;
  final int swapsLeft;

  /// The other side's creature this side goes for.
  final int? focus;

  /// The computer is playing this side (a guest away).
  final bool auto;
  final List<BattleCreatureSample> creatures;

  BattleSideSample mirrored() => BattleSideSample(
    spots: spots,
    swapsLeft: swapsLeft,
    focus: focus,
    auto: auto,
    creatures: [for (final c in creatures) c.mirrored()],
  );

  void writeTo(List<int> out) {
    out.addAll([
      creatures.length,
      spots.isNotEmpty ? spots[0] ?? -1 : -1,
      spots.length > 1 ? spots[1] ?? -1 : -1,
      swapsLeft,
      focus ?? -1,
      auto ? 1 : 0,
    ]);
    for (final c in creatures) {
      c.writeTo(out);
    }
  }

  /// Reads a side at [i]; returns it and where the next begins.
  static (BattleSideSample, int) read(List<int> v, int i) {
    final n = v[i];
    int? opt(int x) => x < 0 ? null : x;
    final creatures = <BattleCreatureSample>[];
    var at = i + 6;
    for (var k = 0; k < n; k++) {
      creatures.add(BattleCreatureSample.read(v, at));
      at += BattleCreatureSample.ints;
    }
    return (
      BattleSideSample(
        spots: [opt(v[i + 1]), opt(v[i + 2])],
        swapsLeft: v[i + 3],
        focus: opt(v[i + 4]),
        auto: v[i + 5] == 1,
        creatures: creatures,
      ),
      at,
    );
  }
}

/// The whole fight at one moment, as the host had it.
class BattleSample {
  const BattleSample({
    required this.at,
    required this.clock,
    required this.timeScale,
    required this.applied,
    required this.sides,
  });

  /// The host's real time since the fight began, in milliseconds: the
  /// timeline the guest plays back on (slow motion included).
  final int at;

  /// The fight's own clock, in seconds.
  final double clock;

  /// How fast the fight ran against the real clock (slow motion).
  final double timeScale;

  /// How many of the guest's inputs the host had taken in.
  final int applied;
  final List<BattleSideSample> sides;

  BattleSample mirrored() => BattleSample(
    at: at,
    clock: clock,
    timeScale: timeScale,
    applied: applied,
    sides: [sides[1].mirrored(), sides[0].mirrored()],
  );

  List<int> encode() {
    final out = <int>[
      at,
      (clock * 1000).round(),
      (timeScale * 1000).round(),
      applied,
    ];
    for (final s in sides) {
      s.writeTo(out);
    }
    return out;
  }

  static BattleSample decode(List<int> v) {
    final (a, next) = BattleSideSample.read(v, 4);
    final (b, _) = BattleSideSample.read(v, next);
    return BattleSample(
      at: v[0],
      clock: v[1] / 1000,
      timeScale: v[2] / 1000,
      applied: v[3],
      sides: [a, b],
    );
  }

  /// Between this sample and [next], [u] of the way: where those on the
  /// field in both (in the same place) stand, the fight's clock and the
  /// specials' waits run smoothly; the rest is this sample's.
  BattleSample toward(BattleSample next, double u) {
    if (u <= 0) return this;
    double lerp(double a, double b) => a + (b - a) * u;
    return BattleSample(
      at: (at + (next.at - at) * u).round(),
      clock: lerp(clock, next.clock),
      timeScale: timeScale,
      applied: applied,
      sides: [
        for (var s = 0; s < sides.length; s++)
          BattleSideSample(
            spots: sides[s].spots,
            swapsLeft: sides[s].swapsLeft,
            focus: sides[s].focus,
            auto: sides[s].auto,
            creatures: [
              for (var i = 0; i < sides[s].creatures.length; i++)
                _between(
                  sides[s].creatures[i],
                  i < next.sides[s].creatures.length
                      ? next.sides[s].creatures[i]
                      : null,
                  sides[s].spots.contains(i) &&
                      sides[s].spots.indexOf(i) ==
                          next.sides[s].spots.indexOf(i),
                  lerp,
                ),
            ],
          ),
      ],
    );
  }

  static BattleCreatureSample _between(
    BattleCreatureSample a,
    BattleCreatureSample? b,
    bool samePlace,
    double Function(double, double) lerp,
  ) {
    if (b == null || !a.onField || !b.onField || !samePlace) return a;
    final ca = a.cooldown, cb = b.cooldown;
    return BattleCreatureSample(
      place: a.place,
      at: Offset(lerp(a.at.dx, b.at.dx), lerp(a.at.dy, b.at.dy)),
      hp: a.hp,
      maxHp: a.maxHp,
      shield: a.shield,
      // A special cast in between starts its wait again: no smoothing
      // across that.
      cooldown: ca != null && cb != null && cb <= ca ? lerp(ca, cb) : ca,
      life: lerp(a.life, b.life),
      faceRight: a.faceRight,
      phoenixSpent: a.phoenixSpent,
      burning: a.burning,
      poisoned: a.poisoned,
      interrupted: a.interrupted,
    );
  }
}

/// What an event is.
enum BattleWireKind { special, summon, swap, fall, phoenix, end }

/// How a fight ended, on the wire.
enum BattleWireEnd { fieldEmpty, timeUp, conceded, noContest }

/// One thing that happened in the fight, numbered by the host.
class BattleWireEvent {
  const BattleWireEvent({
    required this.seq,
    required this.kind,
    required this.side,
    required this.creature,
    required this.at,
    required this.clock,
    this.data = const [],
  });

  final int seq;
  final BattleWireKind kind;
  final int side;
  final int creature;

  /// The host's real time in milliseconds (the samples' timeline).
  final int at;

  /// The fight's clock, in seconds.
  final double clock;

  /// What it carries: a special's origin, angle, target and seed (see
  /// [BattleCast]); a phoenix's fallen one; the end's winner, how and the
  /// breakdown (see [BattleEnding]).
  final List<int> data;

  BattleWireEvent mirrored() {
    final d = switch (kind) {
      BattleWireKind.special => BattleCast.fromData(data).mirrored().data,
      BattleWireKind.end => BattleEnding.fromData(data).mirrored().data,
      _ => data,
    };
    return BattleWireEvent(
      seq: seq,
      kind: kind,
      side: 1 - side,
      creature: creature,
      at: at,
      clock: clock,
      data: d,
    );
  }

  void writeTo(List<int> out) {
    out
      ..add(6 + data.length)
      ..addAll([seq, kind.index, side, creature, at, (clock * 1000).round()])
      ..addAll(data);
  }

  /// Reads an event at [i]; returns it and where the next begins.
  static (BattleWireEvent, int) read(List<int> v, int i) {
    final len = v[i];
    return (
      BattleWireEvent(
        seq: v[i + 1],
        kind: BattleWireKind.values[v[i + 2].clamp(0, 5)],
        side: v[i + 3],
        creature: v[i + 4],
        at: v[i + 5],
        clock: v[i + 6] / 1000,
        data: v.sublist(i + 7, i + 1 + len),
      ),
      i + 1 + len,
    );
  }
}

/// A special as it was cast: from where (from the floor's middle), which
/// way, at what, and the seed of its scatter.
class BattleCast {
  const BattleCast({
    required this.origin,
    required this.angle,
    required this.target,
    required this.seed,
  });

  final Offset origin;
  final double angle;
  final Offset target;
  final int seed;

  List<int> get data => [
    (origin.dx * 10).round(),
    (origin.dy * 10).round(),
    (angle * 10000).round(),
    (target.dx * 10).round(),
    (target.dy * 10).round(),
    seed,
  ];

  static BattleCast fromData(List<int> d) => BattleCast(
    origin: Offset(d[0] / 10, d[1] / 10),
    angle: d[2] / 10000,
    target: Offset(d[3] / 10, d[4] / 10),
    seed: d[5],
  );

  BattleCast mirrored() {
    var a = angle + pi;
    if (a > pi) a -= 2 * pi;
    return BattleCast(origin: -origin, angle: a, target: -target, seed: seed);
  }
}

/// How the fight ended: the winner (null a draw), how, and each side's
/// creatures' dealt, taken and healed for the result card.
class BattleEnding {
  const BattleEnding({
    required this.winner,
    required this.end,
    required this.tallies,
  });

  final int? winner;
  final BattleWireEnd end;

  /// By side, by creature: (dealt, taken, healed).
  final List<List<(int, int, int)>> tallies;

  List<int> get data => [
    winner ?? -1,
    end.index,
    for (final side in tallies) ...[
      side.length,
      for (final (a, b, c) in side) ...[a, b, c],
    ],
  ];

  static BattleEnding fromData(List<int> d) {
    final tallies = <List<(int, int, int)>>[];
    var i = 2;
    while (i < d.length) {
      final n = d[i++];
      tallies.add([
        for (var k = 0; k < n; k++)
          (d[i + k * 3], d[i + k * 3 + 1], d[i + k * 3 + 2]),
      ]);
      i += n * 3;
    }
    return BattleEnding(
      winner: d[0] < 0 ? null : d[0],
      end: BattleWireEnd.values[d[1].clamp(0, BattleWireEnd.values.length - 1)],
      tallies: tallies,
    );
  }

  BattleEnding mirrored() => BattleEnding(
    winner: winner == null ? null : 1 - winner!,
    end: end,
    tallies: tallies.reversed.toList(),
  );
}

/// One packet: samples, and the recent events again.
class BattlePacket {
  const BattlePacket({required this.samples, required this.events});

  final List<BattleSample> samples;
  final List<BattleWireEvent> events;

  BattlePacket mirrored() => BattlePacket(
    samples: [for (final s in samples) s.mirrored()],
    events: [for (final e in events) e.mirrored()],
  );

  List<int> encode() {
    final out = <int>[kBattleLinkVersion, samples.length];
    for (final s in samples) {
      final v = s.encode();
      out
        ..add(v.length)
        ..addAll(v);
    }
    out.add(events.length);
    for (final e in events) {
      e.writeTo(out);
    }
    return out;
  }

  /// A packet from its ints; null if it is from another version or cannot
  /// be read.
  static BattlePacket? decode(List<int> v) {
    try {
      if (v.isEmpty || v[0] != kBattleLinkVersion) return null;
      var i = 1;
      final samples = <BattleSample>[];
      final ns = v[i++];
      for (var k = 0; k < ns; k++) {
        final len = v[i++];
        samples.add(BattleSample.decode(v.sublist(i, i + len)));
        i += len;
      }
      final events = <BattleWireEvent>[];
      final ne = v[i++];
      for (var k = 0; k < ne; k++) {
        final (e, next) = BattleWireEvent.read(v, i);
        events.add(e);
        i = next;
      }
      return BattlePacket(samples: samples, events: events);
    } on RangeError {
      return null;
    }
  }
}

/// The host's side of the link: samples the fight as it runs and sends a
/// packet four times a second.
class BattleTape {
  BattleTape({required this.send});

  /// Sends packet number [seq].
  final void Function(int seq, List<int> packet) send;

  int _seq = 0;
  int _eventSeq = 0;
  int _nextSample = 0;
  int _nextPacket = kBattlePacketMs;
  final List<BattleSample> _unsent = [];
  final List<BattleWireEvent> _events = [];
  BattleWireEvent? _end;

  /// Every sample taken, for the tests.
  final List<BattleSample> taken = [];

  /// Every event, in order.
  List<BattleWireEvent> get events => List.unmodifiable(_events);

  int get packetsSent => _seq;

  /// Notes an event at the host's real time [at] (ms).
  void event(
    BattleWireKind kind,
    int side,
    int creature,
    int at,
    double clock, [
    List<int> data = const [],
  ]) {
    final e = BattleWireEvent(
      seq: _eventSeq++,
      kind: kind,
      side: side,
      creature: creature,
      at: at,
      clock: clock,
      data: data,
    );
    _events.add(e);
    if (kind == BattleWireKind.end) _end = e;
  }

  /// Each frame on the host, at its real time [now] (ms): a sample when one
  /// is due, a packet when one is.
  void frame(int now, BattleSample Function() sample) {
    if (now >= _nextSample) {
      final s = sample();
      _unsent.add(s);
      taken.add(s);
      _nextSample = (now ~/ kBattleSampleMs + 1) * kBattleSampleMs;
    }
    if (now >= _nextPacket) flush(now);
  }

  /// Sends what is waiting now.
  void flush(int now) {
    final recent = [
      for (final e in _events)
        if (e.at >= now - kBattleEventsWindowMs) e,
    ];
    final events = recent.length > kBattleEventsPerPacket
        ? recent.sublist(recent.length - kBattleEventsPerPacket)
        : recent;
    // The end goes in every packet once there is one.
    final end = _end;
    if (end != null && !events.contains(end)) events.add(end);
    send(
      _seq++,
      BattlePacket(samples: List.of(_unsent), events: events).encode(),
    );
    _unsent.clear();
    _nextPacket = now + kBattlePacketMs;
  }
}

/// One step of the guest's playback: the fight as it was at the playback
/// time (between two samples), the events that came due, and how much of
/// the fight's own time passed.
class BattlePlaybackStep {
  const BattlePlaybackStep({
    required this.sample,
    required this.events,
    required this.fightDt,
    required this.at,
    this.from = -1,
  });

  final BattleSample? sample;
  final List<BattleWireEvent> events;
  final double fightDt;

  /// The playback time, on the host's timeline (ms).
  final double at;

  /// The time of the sample it stands on (the one at or before [at]): its
  /// health and places are that sample's.
  final int from;
}

/// The guest's side of the link: packets in, the fight played back
/// [delayMs] behind the newest sample — a little faster when it falls
/// behind, held when nothing new has come, jumped forward after a long gap.
class BattlePlayback {
  BattlePlayback({this.delayMs = kBattleGuestDelayMs});

  final int delayMs;

  final List<BattleSample> _samples = [];
  final List<BattleWireEvent> _waiting = [];
  final Set<int> _seen = {};
  final Set<int> _packets = {};
  double _at = 0;
  bool _started = false;

  /// The newest sample's time, or -1 before any.
  int get newest => _samples.isEmpty ? -1 : _samples.last.at;

  /// The playback time on the host's timeline (ms).
  double get at => _at;

  /// How far playback is behind the newest sample (ms).
  double get behind => newest < 0 ? 0 : newest - _at;

  /// Whether playback is waiting on the host: caught up to the newest.
  bool get starved => _started && _at >= newest;

  bool get started => _started;

  /// Takes in packet number [seq]; one already had is passed over.
  void add(int seq, BattlePacket packet) {
    if (!_packets.add(seq)) return;
    for (final s in packet.samples) {
      if (_samples.isNotEmpty && s.at <= _at - 1000) continue;
      var i = _samples.length;
      while (i > 0 && _samples[i - 1].at > s.at) {
        i--;
      }
      if (i > 0 && _samples[i - 1].at == s.at) continue;
      _samples.insert(i, s);
    }
    for (final e in packet.events) {
      if (_seen.add(e.seq)) _waiting.add(e);
    }
    _waiting.sort((a, b) => a.seq.compareTo(b.seq));
  }

  /// Moves playback on by [dtMs] of this phone's time.
  BattlePlaybackStep advance(double dtMs) {
    if (_samples.isEmpty) {
      return BattlePlaybackStep(
        sample: null,
        events: const [],
        fightDt: 0,
        at: _at,
      );
    }
    final target = (newest - delayMs).toDouble();
    final before = _at;
    if (!_started) {
      _started = true;
      _at = max(_samples.first.at.toDouble(), target);
    } else if (target - _at > 2000) {
      // A long gap (the host's network, this phone asleep): catch up at
      // once rather than run the fight fast.
      _at = target;
    } else {
      var rate = 1.0;
      if (_at < target - 150) rate = 1.1;
      if (_at > target + 150) rate = 0.9;
      _at = min(_at + dtMs * rate, newest.toDouble());
    }
    // Where the playback is: between the last sample at or before it and
    // the next.
    var i = _samples.length - 1;
    while (i > 0 && _samples[i].at > _at) {
      i--;
    }
    final a = _samples[i];
    final b = i + 1 < _samples.length ? _samples[i + 1] : null;
    final u = b == null || b.at <= a.at
        ? 0.0
        : ((_at - a.at) / (b.at - a.at)).clamp(0.0, 1.0);
    final sample = b == null ? a : a.toward(b, u);
    // What is too old to need again.
    while (_samples.length > 2 && _samples[1].at <= _at - 1000) {
      _samples.removeAt(0);
    }
    final due = <BattleWireEvent>[];
    while (_waiting.isNotEmpty && _waiting.first.at <= _at) {
      due.add(_waiting.removeAt(0));
    }
    return BattlePlaybackStep(
      sample: sample,
      events: due,
      fightDt: max(0.0, _at - before) / 1000 * sample.timeScale,
      at: _at,
      from: a.at,
    );
  }
}

/// A guest's tap, as it goes to the host: [a] and [b] are its creature and
/// field place, or the other side's creature for a focus.
enum BattleInputKind { focus, fill, swap, concede }

class BattleInput {
  const BattleInput(this.kind, [this.a = -1, this.b = -1]);

  /// Its side goes for the other side's [creature] (null: whoever is
  /// nearest).
  const BattleInput.focus(int? creature)
    : this(BattleInputKind.focus, creature ?? -1);

  /// Bench [creature] into an empty place.
  const BattleInput.fill(int creature) : this(BattleInputKind.fill, creature);

  /// Bench [creature] in place of the one in [spot].
  const BattleInput.swap(int creature, int spot)
    : this(BattleInputKind.swap, creature, spot);

  const BattleInput.concede() : this(BattleInputKind.concede);

  final BattleInputKind kind;
  final int a, b;

  static List<int> encodeAll(List<BattleInput> inputs) => [
    for (final i in inputs) ...[i.kind.index, i.a, i.b],
  ];

  static List<BattleInput> decodeAll(List<int> v) => [
    for (var i = 0; i + 2 < v.length; i += 3)
      if (v[i] >= 0 && v[i] < BattleInputKind.values.length)
        BattleInput(BattleInputKind.values[v[i]], v[i + 1], v[i + 2]),
  ];

  @override
  bool operator ==(Object other) =>
      other is BattleInput &&
      other.kind == kind &&
      other.a == a &&
      other.b == b;

  @override
  int get hashCode => Object.hash(kind, a, b);

  @override
  String toString() => 'BattleInput(${kind.name}, $a, $b)';
}
