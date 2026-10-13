// lib/games/stadium/race_room.dart
//
// A race run live with friends (the author, 2026-10-12: race friends LIVE,
// invited from a friend's page while they are online, up to six of them,
// the cup's computer rivals filling the lanes left empty). One room in
// Firestore holds who is invited, each one's racer as numbers, and the
// ticks each tapped a boost at. Every phone runs the same race from those:
// race_rules.dart is + − × ÷ only, and a racer's ratings travel as its
// owner worked them out (the stat curve has a log in it, which two phones
// need not agree on to the last bit), so only the taps go between them.

import 'package:alchemons/games/cosmic/contest_judging.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/stadium/race_cups.dart';
import 'package:alchemons/games/stadium/race_rules.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:flutter/foundation.dart';

/// The most players in one race: every lane.
const int kRaceRoomSeats = 6;

/// An invitation older than this is left alone.
const Duration kRaceInviteLife = Duration(minutes: 20);

/// How long before the gun a race starts, from the host's START: time for
/// every phone to hear it, load the six and turn for the race.
const Duration kRaceRoomLead = Duration(seconds: 9);

/// One player's racer, as everyone races it.
@immutable
class RaceSeat {
  const RaceSeat({
    required this.uid,
    required this.player,
    required this.instanceId,
    required this.entrant,
    required this.ratings,
    required this.boosts,
    required this.look,
  });

  final String uid;

  /// The player's name.
  final String player;

  /// Their Alchemon's id in their own save (its id in the race).
  final String instanceId;

  /// What the judges see, as its owner's game made it.
  final ContestEntrant entrant;

  /// Each trait on the 1–5 gameplay rating, as its owner's game worked it
  /// out.
  final Map<CosmicContestTrait, double> ratings;
  final int boosts;

  /// How it looks, to draw it.
  final ResidentLook look;

  /// The racer in the race; [isPlayer] for the phone's own.
  Racer racer({required bool isPlayer}) => Racer(
    id: 'live:$uid',
    isPlayer: isPlayer,
    entrant: entrant,
    ratings: ratings,
    boosts: boosts,
  );

  /// [racer] as a seat for [uid] called [player].
  factory RaceSeat.of({
    required String uid,
    required String player,
    required String instanceId,
    required Racer racer,
    required ResidentLook look,
  }) => RaceSeat(
    uid: uid,
    player: player,
    instanceId: instanceId,
    entrant: racer.entrant,
    ratings: racer.ratings,
    boosts: racer.boosts,
    look: look,
  );

  static const _traits = {
    CosmicContestTrait.speed: 'spd',
    CosmicContestTrait.strength: 'str',
    CosmicContestTrait.intelligence: 'int',
    CosmicContestTrait.beauty: 'bea',
  };

  Map<String, Object?> toJson() => {
    'player': player,
    'id': instanceId,
    'entrant': entrantToJson(entrant),
    'ratings': {
      for (final e in _traits.entries) e.value: ratings[e.key] ?? 1.0,
    },
    'boosts': boosts,
    'look': look.toJson(),
  };

  static RaceSeat? fromJson(String uid, Object? json) {
    if (json is! Map) return null;
    final entrant = entrantFromJson(json['entrant']);
    final look = ResidentLook.fromJson(json['look']);
    final ratings = json['ratings'];
    final player = json['player'];
    final id = json['id'];
    final boosts = json['boosts'];
    if (entrant == null ||
        look == null ||
        ratings is! Map ||
        player is! String ||
        id is! String ||
        boosts is! num) {
      return null;
    }
    final out = <CosmicContestTrait, double>{};
    for (final e in _traits.entries) {
      final v = ratings[e.value];
      if (v is! num) return null;
      out[e.key] = v.toDouble();
    }
    return RaceSeat(
      uid: uid,
      player: player,
      instanceId: id,
      entrant: entrant,
      ratings: out,
      boosts: boosts.toInt().clamp(0, 6),
      look: look,
    );
  }
}

/// [e] as numbers and words, every field the judges read.
Map<String, Object?> entrantToJson(ContestEntrant e) => {
  'name': e.name,
  'el': e.element,
  'fam': e.family,
  'scale': e.scale,
  'pris': e.prismatic,
  'fx': e.effect,
  'var': e.variant,
  'tint': e.tinted,
  'pEl': e.pureElement,
  'pFam': e.pureFamily,
  'pure': e.speciesPure,
  'kEl': e.elementKinds,
  'kFac': e.factionKinds,
  'kFam': e.familyKinds,
  'gen': e.generations,
};

ContestEntrant? entrantFromJson(Object? json) {
  if (json is! Map) return null;
  final name = json['name'], el = json['el'], fam = json['fam'];
  if (name is! String || el is! String || fam is! String) return null;
  String? s(String k) => json[k] is String ? json[k] as String : null;
  int n(String k) => json[k] is num ? (json[k] as num).toInt() : 0;
  return ContestEntrant(
    name: name,
    element: el,
    family: fam,
    statRating: 0,
    scale: json['scale'] is num ? (json['scale'] as num).toDouble() : 1,
    prismatic: json['pris'] == true,
    effect: s('fx'),
    variant: json['var'] == true,
    tinted: json['tint'] == true,
    pureElement: s('pEl'),
    pureFamily: s('pFam'),
    speciesPure: json['pure'] == true,
    elementKinds: n('kEl'),
    factionKinds: n('kFac'),
    familyKinds: n('kFam'),
    generations: n('gen'),
  );
}

/// Where a room is: gathering, or racing (from [RaceRoom.startAt]).
enum RaceRoomState { lobby, racing }

/// A room as last read.
@immutable
class RaceRoom {
  const RaceRoom({
    required this.id,
    required this.host,
    required this.invited,
    required this.names,
    required this.cup,
    required this.race,
    required this.state,
    required this.run,
    required this.seats,
    required this.taps,
    this.field = const [],
    this.startAt,
    this.createdAt,
  });

  final String id;
  final String host;

  /// Everyone invited, the host first, in the order they were asked.
  final List<String> invited;

  /// Their names, as the host knows them.
  final Map<String, String> names;
  final int cup, race;
  final RaceRoomState state;

  /// Counts the races run in this room; taps belong to one.
  final int run;

  /// Those who have joined, with their racers.
  final Map<String, RaceSeat> seats;

  /// Each player's boost taps in this [run], as ticks.
  final Map<String, List<int>> taps;

  /// Who is in this [run]'s race, in lane order: fixed by the host's START,
  /// so every phone races the same six whoever comes or goes.
  final List<String> field;

  /// When the gun goes, in milliseconds on the server's clock.
  final int? startAt;
  final DateTime? createdAt;

  RaceCup get cupDef => kRaceCups[cup.clamp(0, kRaceCups.length - 1)];
  RaceCourse get course =>
      cupDef.courses[race.clamp(0, cupDef.courses.length - 1)];

  /// The players who have joined, in lane order: the host, then the rest
  /// in the order they were asked.
  List<RaceSeat> get racing => [
    for (final uid in invited)
      if (seats[uid] case final seat?) seat,
  ];

  /// The players in the race: its [field] once started, else those who
  /// have joined.
  List<RaceSeat> get lineup => field.isEmpty
      ? racing.take(kRaceRoomSeats).toList()
      : [
          for (final uid in field)
            if (seats[uid] case final seat?) seat,
        ];

  String nameOf(String uid) => seats[uid]?.player ?? names[uid] ?? 'Friend';

  /// The six, lane for lane, as [me] races them: the cup's rivals in the
  /// back lanes (as many as the players leave room for), the players in
  /// front. Every phone builds the same six in the same order.
  List<Racer> racers(String me) {
    final players = lineup;
    final rivals = cupDef.rivals.take(kRaceRoomSeats - players.length);
    final form = race < cupDef.rivalForm.length ? cupDef.rivalForm[race] : 1.0;
    return [
      for (final r in rivals) r.racer(course, form: form),
      for (final s in players) s.racer(isPlayer: s.uid == me),
    ];
  }

  /// The lane each player races in (see [racers]).
  Map<String, int> lanes() {
    final players = lineup;
    final first = kRaceRoomSeats - players.length;
    final rivals = first.clamp(0, cupDef.rivals.length);
    return {
      for (var i = 0; i < players.length; i++) players[i].uid: rivals + i,
    };
  }

  /// The taps so far, by lane.
  Map<int, List<int>> tapsByLane() {
    final lanes = this.lanes();
    return {
      for (final e in taps.entries)
        if (lanes[e.key] case final lane?) lane: e.value,
    };
  }

  /// A room from its document; [createdAt] as the store's own time type
  /// reads it.
  static RaceRoom? fromJson(
    String id,
    Map<String, dynamic>? json, {
    DateTime? createdAt,
  }) {
    if (json == null) return null;
    final host = json['host'];
    if (host is! String) return null;
    final invited = [
      for (final u in (json['invited'] as List? ?? const []))
        if (u is String) u,
    ];
    final names = <String, String>{
      for (final e in (json['names'] as Map? ?? const {}).entries)
        if (e.key is String && e.value is String)
          e.key as String: e.value as String,
    };
    final seats = <String, RaceSeat>{};
    for (final e in (json['seats'] as Map? ?? const {}).entries) {
      if (e.key is! String) continue;
      final seat = RaceSeat.fromJson(e.key as String, e.value);
      if (seat != null) seats[e.key as String] = seat;
    }
    final run = json['run'] is num ? (json['run'] as num).toInt() : 0;
    // Taps from another run (a write that landed after the next began)
    // are not this race's.
    final taps = <String, List<int>>{};
    for (final e in (json['taps'] as Map? ?? const {}).entries) {
      final v = e.value;
      if (e.key is! String || v is! Map || v['run'] != run) continue;
      taps[e.key as String] = [
        for (final t in (v['t'] as List? ?? const []))
          if (t is num) t.toInt(),
      ]..sort();
    }
    return RaceRoom(
      id: id,
      host: host,
      invited: invited,
      names: names,
      cup: json['cup'] is num ? (json['cup'] as num).toInt() : 0,
      race: json['race'] is num ? (json['race'] as num).toInt() : 0,
      state: json['state'] == 'racing'
          ? RaceRoomState.racing
          : RaceRoomState.lobby,
      run: run,
      seats: seats,
      taps: taps,
      field: [
        for (final u in (json['field'] as List? ?? const []))
          if (u is String) u,
      ],
      startAt: json['startAt'] is num ? (json['startAt'] as num).toInt() : null,
      createdAt: createdAt,
    );
  }
}
