// lib/models/battle_room.dart
//
// A battle fought live between two friends (docs/battle/live_pvp_design.md):
// one room in Firestore, `battle_rooms/{id}`, holds the host and the friend
// asked, each one's four as numbers (their owner's game works out the
// stats, constellation and all, so both phones fight the same four), READY,
// the guest's inputs while a fight is on, and how the last one ended. The
// fight itself goes in the room's stream (services/battle_room_service.dart,
// games/cosmic/battle_wire.dart).
//
// Each brings the four they keep for battles, the first two leading; the
// host's arena is fought in. Nothing is paid: a head-to-head record with
// that friend is kept on each phone (models/battle_record.dart).

import 'package:alchemons/games/cosmic/battle_wire.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:flutter/foundation.dart';

/// An invitation older than this is left alone.
const Duration kBattleInviteLife = Duration(minutes: 20);

/// From the host's START to the first fight: time for both phones to hear
/// it and load the eight, which the way in to the host's place fills
/// (screens/battle/battle_journey.dart).
const Duration kBattleRoomLead = Duration(seconds: 5);

/// From START to a rematch: straight onto the floor, the eight loaded.
const Duration kBattleRematchLead = Duration(seconds: 3);

/// One of a player's four, as both phones fight it.
@immutable
class BattleSeatMember {
  const BattleSeatMember({
    required this.id,
    required this.name,
    required this.element,
    required this.family,
    required this.level,
    required this.speed,
    required this.intelligence,
    required this.strength,
    required this.beauty,
    this.speedPotential = 50,
    this.intelligencePotential = 50,
    this.strengthPotential = 50,
    this.beautyPotential = 50,
    required this.look,
  });

  /// Its id in its owner's save.
  final String id;
  final String name;
  final String element, family;
  final int level;

  /// Its stats, as its owner's game works them out (the constellation's
  /// bonuses in).
  final double speed, intelligence, strength, beauty;
  final double speedPotential,
      intelligencePotential,
      strengthPotential,
      beautyPotential;

  /// How it looks, to draw it.
  final ResidentLook look;

  factory BattleSeatMember.of(CosmicPartyMember m, ResidentLook look) =>
      BattleSeatMember(
        id: m.instanceId,
        name: m.displayName,
        element: m.element,
        family: m.family,
        level: m.level,
        speed: m.statSpeed,
        intelligence: m.statIntelligence,
        strength: m.statStrength,
        beauty: m.statBeauty,
        speedPotential: m.statSpeedPotential,
        intelligencePotential: m.statIntelligencePotential,
        strengthPotential: m.statStrengthPotential,
        beautyPotential: m.statBeautyPotential,
        look: look,
      );

  /// It in the fight, in place [slot], drawn from [catalog] when there is
  /// one.
  CosmicPartyMember member(CreatureCatalog? catalog, int slot) {
    final base = catalog?.getCreatureById(look.baseId);
    return CosmicPartyMember(
      instanceId: id,
      baseId: look.baseId,
      displayName: name,
      element: element,
      family: family,
      level: level,
      statSpeed: speed,
      statIntelligence: intelligence,
      statStrength: strength,
      statBeauty: beauty,
      statSpeedPotential: speedPotential,
      statIntelligencePotential: intelligencePotential,
      statStrengthPotential: strengthPotential,
      statBeautyPotential: beautyPotential,
      slotIndex: slot,
      staminaBars: 3,
      staminaMax: 3,
      spriteSheet: base?.spriteData != null ? sheetFromCreature(base!) : null,
      spriteVisuals: visualsFromInstance(base, look.instance(id)),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'el': element,
    'fam': family,
    'lv': level,
    's': [speed, intelligence, strength, beauty],
    'p': [
      speedPotential,
      intelligencePotential,
      strengthPotential,
      beautyPotential,
    ],
    'look': look.toJson(),
  };

  static BattleSeatMember? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], name = json['name'];
    final el = json['el'], fam = json['fam'], lv = json['lv'];
    final s = json['s'], p = json['p'];
    final look = ResidentLook.fromJson(json['look']);
    if (id is! String ||
        name is! String ||
        el is! String ||
        fam is! String ||
        lv is! num ||
        s is! List ||
        s.length != 4 ||
        look == null) {
      return null;
    }
    double at(List v, int i, double fallback) =>
        i < v.length && v[i] is num ? (v[i] as num).toDouble() : fallback;
    final pots = p is List ? p : const [];
    return BattleSeatMember(
      id: id,
      name: name,
      element: el,
      family: fam,
      level: lv.toInt(),
      speed: at(s, 0, 1),
      intelligence: at(s, 1, 1),
      strength: at(s, 2, 1),
      beauty: at(s, 3, 1),
      speedPotential: at(pots, 0, 50),
      intelligencePotential: at(pots, 1, 50),
      strengthPotential: at(pots, 2, 50),
      beautyPotential: at(pots, 3, 50),
      look: look,
    );
  }
}

/// One player's place in a room: their name and their four.
@immutable
class BattleSeat {
  const BattleSeat({
    required this.uid,
    required this.player,
    required this.team,
    this.version = kBattleLinkVersion,
  });

  final String uid;
  final String player;
  final List<BattleSeatMember> team;

  /// The link the game that wrote it speaks ([kBattleLinkVersion]).
  final int version;

  /// Written by a game that battles as this one does.
  bool get current => version == kBattleLinkVersion;

  /// The four in the fight, drawn from [catalog].
  List<CosmicPartyMember> members(CreatureCatalog? catalog) => [
    for (var i = 0; i < team.length; i++) team[i].member(catalog, i),
  ];

  Map<String, Object?> toJson() => {
    'player': player,
    'team': [for (final m in team) m.toJson()],
    'v': version,
  };

  static BattleSeat? fromJson(String uid, Object? json) {
    if (json is! Map) return null;
    final player = json['player'];
    final team = json['team'];
    if (player is! String || team is! List) return null;
    final members = <BattleSeatMember>[];
    for (final m in team) {
      final member = BattleSeatMember.fromJson(m);
      if (member == null) return null;
      members.add(member);
    }
    if (members.isEmpty) return null;
    return BattleSeat(
      uid: uid,
      player: player,
      team: members.take(4).toList(),
      version: json['v'] is num ? (json['v'] as num).toInt() : 0,
    );
  }
}

/// Where a room is: gathering, or a fight on.
enum BattleRoomState { lobby, fighting }

/// How a room's last fight ended, as the host wrote it.
@immutable
class BattleRoomResult {
  const BattleRoomResult({required this.run, this.winner, required this.end});

  final int run;

  /// The winner's uid; null a draw or no contest.
  final String? winner;
  final BattleWireEnd end;

  Map<String, Object?> toJson() => {'run': run, 'w': winner, 'end': end.index};

  static BattleRoomResult? fromJson(Object? json) {
    if (json is! Map) return null;
    final run = json['run'], end = json['end'], w = json['w'];
    if (run is! num || end is! num) return null;
    return BattleRoomResult(
      run: run.toInt(),
      winner: w is String ? w : null,
      end: BattleWireEnd
          .values[end.toInt().clamp(0, BattleWireEnd.values.length - 1)],
    );
  }
}

/// A room as last read.
@immutable
class BattleRoom {
  const BattleRoom({
    required this.id,
    required this.host,
    required this.guest,
    required this.names,
    required this.arena,
    required this.state,
    required this.run,
    required this.seats,
    this.ready = const {},
    this.inputs = const [],
    this.inputsRun = -1,
    this.beat = 0,
    this.result,
    this.startAt,
    this.createdAt,
  });

  final String id;
  final String host;

  /// The friend asked; null once they have gone.
  final String? guest;

  /// Their names, as the host knows them.
  final Map<String, String> names;

  /// The host's arena (models/battle_arenas.dart): looks only.
  final String arena;
  final BattleRoomState state;

  /// Counts the fights in this room; READY and inputs belong to one.
  final int run;
  final Map<String, BattleSeat> seats;

  /// The guest's READY, as the [run] they were ready after.
  final Map<String, int> ready;

  /// The guest's inputs in the fight [inputsRun], and their beat.
  final List<BattleInput> inputs;
  final int inputsRun;
  final int beat;
  final BattleRoomResult? result;

  /// When the fight starts, in milliseconds on the server's clock.
  final int? startAt;
  final DateTime? createdAt;

  BattleSeat? get hostSeat => seats[host];
  BattleSeat? get guestSeat => guest == null ? null : seats[guest];

  /// The other player, as [me] sees the room.
  String? otherOf(String me) => me == host ? guest : host;

  String nameOf(String? uid) =>
      uid == null ? 'Friend' : seats[uid]?.player ?? names[uid] ?? 'Friend';

  /// The guest is ready for the next fight (the host starts it, so is
  /// always ready).
  bool isReady(String uid) => uid == host || ready[uid] == run;

  /// Both in, both on this game's link, the guest ready: the host may
  /// start.
  bool get canStart {
    final h = hostSeat, g = guestSeat;
    return state == BattleRoomState.lobby &&
        h != null &&
        g != null &&
        h.current &&
        g.current &&
        isReady(g.uid);
  }

  /// This [run]'s inputs from the guest.
  List<BattleInput> inputsFor(int run) => inputsRun == run ? inputs : const [];

  static BattleRoom? fromJson(
    String id,
    Map<String, dynamic>? json, {
    DateTime? createdAt,
  }) {
    if (json == null) return null;
    final host = json['host'];
    if (host is! String) return null;
    final guest = json['guest'] is String ? json['guest'] as String : null;
    final seats = <String, BattleSeat>{};
    for (final e in (json['seats'] as Map? ?? const {}).entries) {
      if (e.key is! String) continue;
      final seat = BattleSeat.fromJson(e.key as String, e.value);
      if (seat != null) seats[e.key as String] = seat;
    }
    final inputs = json['inputs'];
    return BattleRoom(
      id: id,
      host: host,
      guest: guest,
      names: {
        for (final e in (json['names'] as Map? ?? const {}).entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
      },
      arena: json['arena'] is String ? json['arena'] as String : 'obsidian',
      state: json['state'] == 'fighting'
          ? BattleRoomState.fighting
          : BattleRoomState.lobby,
      run: json['run'] is num ? (json['run'] as num).toInt() : 0,
      seats: seats,
      ready: {
        for (final e in (json['ready'] as Map? ?? const {}).entries)
          if (e.key is String && e.value is num)
            e.key as String: (e.value as num).toInt(),
      },
      inputs: inputs is Map && inputs['l'] is List
          ? BattleInput.decodeAll([
              for (final v in inputs['l'] as List)
                if (v is num) v.toInt(),
            ])
          : const [],
      inputsRun: inputs is Map && inputs['run'] is num
          ? (inputs['run'] as num).toInt()
          : -1,
      beat: inputs is Map && inputs['b'] is num
          ? (inputs['b'] as num).toInt()
          : 0,
      result: BattleRoomResult.fromJson(json['result']),
      startAt: json['startAt'] is num ? (json['startAt'] as num).toInt() : null,
      createdAt: createdAt,
    );
  }
}
