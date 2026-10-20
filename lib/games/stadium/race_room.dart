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
//
// A room races the ladder's courses, or fights a gem cup's bout (the
// island, the space course: three to a bout, the bout's two rivals filling
// in), each phone running the same bout the same way; for the space course
// each player's route goes in with their READY. (The Emerald Cup's battle
// ladder is not fought with friends yet.)

import 'dart:math';

import 'package:alchemons/games/cosmic/contest_judging.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/stadium/flight_rules.dart';
import 'package:alchemons/games/stadium/gem_cups.dart';
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

/// The rooms this game understands: 2 added READY and the host's choice of
/// computer lanes. A seat from an older game has no version, and races in
/// no room of this one (it would line up a different six).
const int kRaceRoomVersion = 2;

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
    this.version = kRaceRoomVersion,
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

  /// The game it was written by (see [kRaceRoomVersion]).
  final int version;

  /// Written by a game that races rooms as this one does.
  bool get current => version >= kRaceRoomVersion;

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
    'v': kRaceRoomVersion,
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
      version: json['v'] is num ? (json['v'] as num).toInt() : 1,
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

/// What a room races: the ladder's courses, or the gem cups' bouts.
enum RaceRoomEvent { race, gem }

/// The most in one gem cup bout.
const int kGemBoutSeats = 3;

/// A player's route through the space course: for the run and the place
/// it was planned for ([RaceRoom.placeKey]), a way at each fork.
@immutable
class RacePlan {
  const RacePlan({required this.run, required this.at, required this.route});

  final int run;
  final String at;
  final List<int> route;

  Map<String, Object?> toJson() => {'run': run, 'at': at, 'r': route};

  static RacePlan? fromJson(Object? json) {
    if (json is! Map) return null;
    final run = json['run'], at = json['at'], r = json['r'];
    if (run is! num || at is! String || r is! List) return null;
    return RacePlan(
      run: run.toInt(),
      at: at,
      route: [
        for (final c in r)
          if (c is num) c.toInt().clamp(0, 1),
      ],
    );
  }
}

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
    this.cpu,
    this.ready = const {},
    this.event = RaceRoomEvent.race,
    this.plans = const {},
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

  /// The most computer racers the host wants in the empty lanes; null for
  /// as many as there is room for.
  final int? cpu;

  /// Each player's READY, as the [run] they were ready after: a race run
  /// moves [run] on, so everyone is not ready again for the next.
  final Map<String, int> ready;

  /// A race of the ladder ([cup], [race]), or a gem cup's bout ([cup] the
  /// gem cup, [race] the bout).
  final RaceRoomEvent event;

  /// Each player's route, for the space course.
  final Map<String, RacePlan> plans;

  /// When the gun goes, in milliseconds on the server's clock.
  final int? startAt;
  final DateTime? createdAt;

  RaceCup get cupDef => kRaceCups[cup.clamp(0, kRaceCups.length - 1)];
  RaceCourse get course =>
      cupDef.courses[race.clamp(0, cupDef.courses.length - 1)];

  bool get gem => event == RaceRoomEvent.gem;
  GemCup get gemDef => kGemCups[cup.clamp(0, kGemCups.length - 1)];
  int get boutIndex => race.clamp(0, gemDef.bouts.length - 1);
  GemBout get bout => gemDef.bouts[boutIndex];

  /// Where this room races, by name: the course, or the bout.
  String get placeName => gem ? bout.name : course.name;

  /// Where this room races, as a key (a route is planned for one).
  String get placeKey => '${gem ? 'gem' : 'race'}:$cup:$race';

  /// The most who race here: six lanes, or three to a bout.
  int get held => gem ? kGemBoutSeats : kRaceRoomSeats;

  /// The space course: each player plans a route before READY.
  bool get needsPlan => gem && gemDef.event == GemEvent.flight;

  /// [uid]'s route for the race to come, if they have planned one here.
  List<int>? planOf(String uid) {
    final p = plans[uid];
    return p != null && p.run == run && p.at == placeKey ? p.route : null;
  }

  /// The computer's who could race here (the cup's, or the bout's two).
  List<RaceRival> get rivalPool =>
      gem ? gemDef.rivalsOf(boutIndex) : cupDef.rivals;

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

  /// Whether [uid] is ready for the next race (the host starts it, so is
  /// always ready): READY, and on the space course a route planned here.
  bool isReady(String uid) =>
      uid == host || (ready[uid] == run && (!needsPlan || planOf(uid) != null));

  /// Those in who are not ready yet, the host aside.
  List<RaceSeat> get notReady => [
    for (final s in racing.take(kRaceRoomSeats))
      if (!isReady(s.uid)) s,
  ];

  /// Enough in, no more than there is room for, and every one of them
  /// ready: the host may start.
  bool get canStart =>
      state == RaceRoomState.lobby &&
      racing.length >= 2 &&
      racing.length <= held &&
      notReady.isEmpty;

  /// How many of the computer's race beside [players] players: as many as
  /// the host wants and there is room for.
  int rivalsBeside(int players) =>
      max(0, min(held - players, min(cpu ?? kRaceRoomSeats, rivalPool.length)));

  /// The racers, lane for lane, as [me] races them: the cup's rivals in the
  /// back lanes (as many as the host wants and the players leave room for),
  /// the players in front. Every phone builds the same field in the same
  /// order; with fewer than six, the back lanes stand empty.
  List<Racer> racers(String me) {
    final players = lineup;
    final rivals = cupDef.rivals.take(rivalsBeside(players.length));
    final form = race < cupDef.rivalForm.length ? cupDef.rivalForm[race] : 1.0;
    return [
      for (final r in rivals) r.racer(course, form: form),
      for (final s in players) s.racer(isPlayer: s.uid == me),
    ];
  }

  /// A gem cup bout's fighters, in order, as every phone fights them: the
  /// bout's rivals (as many as the host wants and there is room for), then
  /// the players. A player's is driven by its taps alone, never by the
  /// computer (so each is a player's here, whoever watches).
  List<Racer> fighters() {
    final players = lineup;
    final rivals = gemDef
        .rivalsOf(boutIndex)
        .take(rivalsBeside(players.length));
    final b = boutIndex;
    final form = b < gemDef.rivalForm.length ? gemDef.rivalForm[b] : 1.0;
    return [
      for (final r in rivals) gemRivalRacer(r, form),
      for (final s in players) s.racer(isPlayer: true),
    ];
  }

  /// The space course's routes, fighter for fighter (see [fighters]): each
  /// player's own plan (the best way for its racer, if it has none), the
  /// way that suits each rival.
  List<List<int>> routes(List<Racer> fighters) {
    final course = flightCourseOf(bout);
    final players = lineup;
    final rivals = fighters.length - players.length;
    return [
      for (var i = 0; i < fighters.length; i++)
        i < rivals
            ? bestFlightRoute(fighters[i], course)
            : planOf(players[i - rivals].uid) ??
                  bestFlightRoute(fighters[i], course),
    ];
  }

  /// The lane each player races in (see [racers], [fighters]).
  Map<String, int> lanes() {
    final players = lineup;
    final rivals = rivalsBeside(players.length);
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
    final ready = <String, int>{
      for (final e in (json['ready'] as Map? ?? const {}).entries)
        if (e.key is String && e.value is num)
          e.key as String: (e.value as num).toInt(),
    };
    final plans = <String, RacePlan>{
      for (final e in (json['plans'] as Map? ?? const {}).entries)
        if (e.key is String)
          if (RacePlan.fromJson(e.value) case final p?) e.key as String: p,
    };
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
      cpu: json['cpu'] is num
          ? (json['cpu'] as num).toInt().clamp(0, kRaceRoomSeats - 1)
          : null,
      ready: ready,
      event: json['ev'] == 'gem' ? RaceRoomEvent.gem : RaceRoomEvent.race,
      plans: plans,
      startAt: json['startAt'] is num ? (json['startAt'] as num).toInt() : null,
      createdAt: createdAt,
    );
  }
}
