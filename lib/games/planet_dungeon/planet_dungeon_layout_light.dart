// lib/games/planet_dungeon/planet_dungeon_layout_light.dart
//
// SOLARIN — THE SHADOW FLOOR (the redesign of 2026-09-28; it replaces the
// Beacon Archive whole). Light's layout, its pure rules, and the proof tools.
//
// WORLD RULE — *in this archive light is nothing. You fall through it. Only
// shadow holds your weight.* The rooms float over a lightwell. Glass over the
// well is a floor only where every starlight that reaches it is blocked, and
// a shadow belongs to whatever casts it: nothing stands on its own shadow.
//
// The starlights are shards of Solarin's star that fell into the archive.
// The party is Light · Dark · Steam:
//   · LIGHT turns the cranks that walk a railed starlight along its notches,
//     and in the key room sets the starlight on a brass stud.
//   · DARK pins the shadow it stands in: the casters holding its square, and
//     every glass square those casters alone hold, set into stone for good.
//     A blank wall takes a pin only from the door-shaped monolith: the shadow
//     of a door is a door.
//   · STEAM breathes a veil at a vent (a still caster that stays where it was
//     breathed), and rises once through a one-way pipe.
//
// THE SHAPE — a hub that grows. The great hall is a lightwell with a stone
// island in the middle. Rooms I and II open off the near ledge, III and IV
// off the island. Each room you solve sets one span of shadow-stone across
// the hall: I and II bridge the near well, III and IV the far one, and the
// far ledge holds the Door of Shadow (the rite), which leads down to Solarin.
//
// Every room's depth was proved by exhaustive search before it was built
// (docs/prototypes/light_shadow_floor, the JS solver the prototype runs on),
// and [solveShadowRoom] is the same search in Dart for the tests.

import 'dart:math';
import 'dart:ui';

import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_verbs.dart';

// ─────────────────────────────────────────────────────────
// THE GRID
// ─────────────────────────────────────────────────────────

/// One square of floor, in world units.
const double kShadowCell = 64;

/// Where the grid starts under a room's north wall face.
const double kShadowTop = 48;

/// The three bodies, in the order the party lists them.
const List<String> kShadowNames = ['Light', 'Dark', 'Steam'];

const double kShadowBodyR = 0.36;
const double kShadowVeilR = 0.45;
const double kShadowStoneR = 0.5;

/// A square on a room's grid.
typedef Sq = ({int x, int y});

Sq sq(int x, int y) => (x: x, y: y);

int sqKey(int x, int y) => y * 64 + x;
Sq sqOf(int key) => (x: key % 64, y: key ~/ 64);

/// World centre of grid square (x, y).
Offset shadowCentre(int x, int y) =>
    Offset((x + .5) * kShadowCell, kShadowTop + (y + .5) * kShadowCell);

/// The grid square a world point stands in (clamped onto the grid).
Sq shadowSquareAt(Offset p, int cols, int rows) => (
  x: (p.dx / kShadowCell).floor().clamp(0, cols - 1),
  y: ((p.dy - kShadowTop) / kShadowCell).floor().clamp(0, rows - 1),
);

/// A starlight: a shard of Solarin's star, shining every way or, with a
/// [face], into a cone.
class ShadowLamp {
  final double x, y;
  final double? face;
  final double half;

  /// 'fixed', 'rail' (walked by a crank) or 'solarin' (the star itself).
  final String kind;
  const ShadowLamp(
    this.x,
    this.y, {
    this.face,
    this.half = 0,
    this.kind = 'fixed',
  });
}

/// A round thing that throws a shadow: a body, the veil, a pillar, the
/// monolith or the relic.
class ShadowCaster {
  final String id;
  final double cx, cy, r;
  final int x, y;
  const ShadowCaster(this.id, this.cx, this.cy, this.r, this.x, this.y);
}

/// One room of the shadow floor, as authored. Map legend:
///
///   .  stone      ~  glass (floor only in shadow)      #  wall (blocks light)
///   L  a starlight every way;  E N W S  one facing one way
///   V  a steam vent   p  a pipe mouth (see [pipes])   G  goal stone
///   P  pillar   M  the door-shaped monolith   R  the relic's plinth
///   B  blank wall (opens only to the monolith's pinned shadow)
///   n  a notch on the starlight's rail (see [rail])   C  the crank
///   d  the dais (stone)
class ShadowRoomDef {
  final String id;
  final List<String> map;
  final Map<String, Sq> start;
  final int pins;
  final double cone;
  final double? pillarR;
  final List<Sq>? rail;
  final int railStart;
  final List<Sq>? orbit;
  final int orbitStart;

  /// 'all' three on G, 'any' one on G, or 'hits' (Solarin struck thrice).
  final String goal;

  /// One-way, once-only pipes: Steam goes in at the first and rises at the
  /// second.
  final List<(Sq, Sq)> pipes;

  const ShadowRoomDef({
    required this.id,
    required this.map,
    required this.start,
    this.pins = 0,
    this.cone = 0.52,
    this.pillarR,
    this.rail,
    this.railStart = 0,
    this.orbit,
    this.orbitStart = 0,
    this.goal = 'all',
    this.pipes = const [],
  });

  int get rows => map.length;
  int get cols => map.first.length;
  String at(int x, int y) => map[y][x];
  bool inside(int x, int y) => x >= 0 && y >= 0 && x < cols && y < rows;
  bool isGlass(int x, int y) => inside(x, y) && at(x, y) == '~';

  List<ShadowLamp> get fixedLamps => [
    for (var y = 0; y < rows; y++)
      for (var x = 0; x < cols; x++)
        if ('LENWS'.contains(at(x, y)))
          ShadowLamp(
            x.toDouble(),
            y.toDouble(),
            face: switch (at(x, y)) {
              'E' => 0,
              'S' => pi / 2,
              'W' => pi,
              'N' => -pi / 2,
              _ => null,
            },
            half: cone,
          ),
  ];

  List<Sq> get vents => [
    for (var y = 0; y < rows; y++)
      for (var x = 0; x < cols; x++)
        if (at(x, y) == 'V') sq(x, y),
  ];

  List<ShadowCaster> get fixedCasters => [
    for (var y = 0; y < rows; y++)
      for (var x = 0; x < cols; x++)
        if ('PMR'.contains(at(x, y)))
          ShadowCaster(
            '${at(x, y)}:$x,$y',
            x + .5,
            y + .5,
            at(x, y) == 'P' && pillarR != null ? pillarR! : kShadowStoneR,
            x,
            y,
          ),
  ];
}

/// Everything that changes in a shadow room.
class ShadowState {
  final Map<String, Sq> pos;
  final int pins;
  final Sq? veil;
  final Set<int> pinned;
  final int rail;
  final int orbit;
  final int hits;
  final bool piped;

  const ShadowState({
    required this.pos,
    required this.pins,
    this.veil,
    required this.pinned,
    this.rail = 0,
    this.orbit = 0,
    this.hits = 0,
    this.piped = false,
  });

  factory ShadowState.start(ShadowRoomDef d) => ShadowState(
    pos: Map.of(d.start),
    pins: d.pins,
    pinned: const {},
    rail: d.railStart,
    orbit: d.orbitStart,
  );

  ShadowState copyWith({
    Map<String, Sq>? pos,
    int? pins,
    Sq? veil,
    Set<int>? pinned,
    int? rail,
    int? orbit,
    int? hits,
    bool? piped,
  }) => ShadowState(
    pos: pos ?? this.pos,
    pins: pins ?? this.pins,
    veil: veil ?? this.veil,
    pinned: pinned ?? this.pinned,
    rail: rail ?? this.rail,
    orbit: orbit ?? this.orbit,
    hits: hits ?? this.hits,
    piped: piped ?? this.piped,
  );

  ShadowState moved(String who, Sq to) => copyWith(pos: {...pos, who: to});

  String get encoded {
    final b = StringBuffer();
    for (final n in kShadowNames) {
      b.write('${pos[n]!.x}.${pos[n]!.y}|');
    }
    b
      ..write('$pins|')
      ..write(veil == null ? '-' : '${veil!.x}.${veil!.y}')
      ..write('|${piped ? 1 : 0}|$rail|$orbit|$hits|');
    final p = pinned.toList()..sort();
    b.write(p.join(';'));
    return b.toString();
  }
}

// ─────────────────────────────────────────────────────────
// THE RULES (pure — the same sentences as the prototype's engine)
// ─────────────────────────────────────────────────────────

/// Every starlight burning right now.
List<ShadowLamp> shadowLamps(ShadowRoomDef d, ShadowState s) {
  final out = d.fixedLamps;
  if (d.rail != null) {
    final n = d.rail![s.rail];
    out.add(ShadowLamp(n.x.toDouble(), n.y.toDouble(), kind: 'rail'));
  }
  if (d.orbit != null && s.hits < 3) {
    final o = d.orbit![s.orbit];
    out.add(ShadowLamp(o.x.toDouble(), o.y.toDouble(), kind: 'solarin'));
  }
  return out;
}

bool shadowSolid(ShadowRoomDef d, int x, int y, ShadowState s) {
  if (!d.inside(x, y)) return true;
  final c = d.at(x, y);
  if ('#LENWSnPMR'.contains(c)) return true;
  if (c == 'B') return !s.pinned.contains(sqKey(x, y));
  if (d.orbit != null && s.hits < 3) {
    final o = d.orbit![s.orbit];
    if (o.x == x && o.y == y) return true;
  }
  return false;
}

/// Does starlight [l] reach square (x,y)? Inside its cone, no wall between.
bool shadowLights(ShadowRoomDef d, ShadowLamp l, int x, int y) {
  final lx = l.x + .5, ly = l.y + .5, px = x + .5, py = y + .5;
  if (l.face != null) {
    var a = atan2(py - ly, px - lx) - l.face!;
    a = atan2(sin(a), cos(a));
    if (a.abs() > l.half) return false;
  }
  final n = (sqrt((px - lx) * (px - lx) + (py - ly) * (py - ly)) * 6).ceil();
  for (var i = 1; i < n; i++) {
    final t = i / n;
    final sx = (lx + (px - lx) * t).floor(), sy = (ly + (py - ly) * t).floor();
    if ((sx == l.x.floor() && sy == l.y.floor()) || (sx == x && sy == y)) {
      continue;
    }
    if (d.inside(sx, sy) && d.at(sx, sy) == '#') return false;
  }
  return true;
}

/// Is (x,y) in the shadow of a round caster at (cx,cy), radius r, from [l]?
bool shadowCast(ShadowLamp l, double cx, double cy, double r, int x, int y) {
  final lx = l.x + .5, ly = l.y + .5, px = x + .5, py = y + .5;
  final dcx = cx - lx, dcy = cy - ly;
  final dc = sqrt(dcx * dcx + dcy * dcy);
  final dx = px - lx, dy = py - ly;
  final dp = sqrt(dx * dx + dy * dy);
  if (dp <= dc + .05) return false;
  if (dcx * dx + dcy * dy <= 0) return false;
  return (dcx * dy - dcy * dx).abs() / dp < r;
}

List<ShadowCaster> shadowCasters(
  ShadowRoomDef d,
  ShadowState s, {
  String? except,
}) => [
  for (final n in kShadowNames)
    if (n != except)
      ShadowCaster(
        n,
        s.pos[n]!.x + .5,
        s.pos[n]!.y + .5,
        kShadowBodyR,
        s.pos[n]!.x,
        s.pos[n]!.y,
      ),
  if (s.veil != null)
    ShadowCaster(
      'veil',
      s.veil!.x + .5,
      s.veil!.y + .5,
      kShadowVeilR,
      s.veil!.x,
      s.veil!.y,
    ),
  ...d.fixedCasters,
];

List<ShadowCaster> _holders(
  ShadowRoomDef d,
  ShadowState s,
  ShadowLamp l,
  int x,
  int y, {
  String? except,
}) => [
  for (final c in shadowCasters(d, s, except: except))
    if (!(c.x == x && c.y == y) && shadowCast(l, c.cx, c.cy, c.r, x, y)) c,
];

/// Is glass (x,y) a floor for [who]? Pinned stone always is. Otherwise EVERY
/// starlight reaching it must be blocked by something that is not [who].
/// Glass no starlight reaches is still just glass: nothing.
bool shadowHolds(ShadowRoomDef d, ShadowState s, int x, int y, String? who) {
  if (s.pinned.contains(sqKey(x, y))) return true;
  var lit = false;
  for (final l in shadowLamps(d, s)) {
    if (!shadowLights(d, l, x, y)) continue;
    lit = true;
    if (_holders(d, s, l, x, y, except: who).isEmpty) return false;
  }
  return lit;
}

String? shadowOccupant(ShadowState s, int x, int y, [String? except]) {
  for (final n in kShadowNames) {
    if (n != except && s.pos[n]!.x == x && s.pos[n]!.y == y) return n;
  }
  return null;
}

bool shadowCanStand(ShadowRoomDef d, ShadowState s, int x, int y, String who) {
  if (shadowSolid(d, x, y, s)) return false;
  if (shadowOccupant(s, x, y, who) != null) return false;
  if (!d.isGlass(x, y)) return true;
  return shadowHolds(d, s, x, y, who);
}

/// Would everyone else still be held if [who] stood at (x,y)? The name of
/// whoever would fall, or null.
String? shadowWouldDrop(
  ShadowRoomDef d,
  ShadowState s,
  String who,
  int x,
  int y,
) {
  final t = s.moved(who, sq(x, y));
  for (final n in kShadowNames) {
    if (n == who) continue;
    final p = t.pos[n]!;
    if (d.isGlass(p.x, p.y) && !shadowHolds(d, t, p.x, p.y, n)) return n;
  }
  return null;
}

/// Why [who] may not step to (x,y): 'floor', 'holds:<name>', or null.
String? shadowStepCheck(
  ShadowRoomDef d,
  ShadowState s,
  String who,
  int x,
  int y,
) {
  if (!shadowCanStand(d, s, x, y, who)) return 'floor';
  final drop = shadowWouldDrop(d, s, who, x, y);
  return drop == null ? null : 'holds:$drop';
}

/// Dark pins "the shadow it stands in": the casters that hold its square,
/// and every glass square those casters alone hold, become stone. A blank
/// wall takes the pin only from the MONOLITH. Null when there is no shadow
/// under Dark to pin.
List<int>? shadowPinCells(ShadowRoomDef d, ShadowState s) {
  final dk = s.pos['Dark']!;
  if (!d.isGlass(dk.x, dk.y) || s.pinned.contains(sqKey(dk.x, dk.y))) {
    return null;
  }
  final lamps = shadowLamps(d, s);
  final used = <String>{};
  for (final l in lamps) {
    if (!shadowLights(d, l, dk.x, dk.y)) continue;
    final h = _holders(d, s, l, dk.x, dk.y, except: 'Dark');
    if (h.isEmpty) return null;
    used.addAll(h.map((c) => c.id));
  }
  final monolith = used.any((id) => id.startsWith('M:'));
  final out = <int>[];
  for (var y = 0; y < d.rows; y++) {
    for (var x = 0; x < d.cols; x++) {
      final c = d.at(x, y);
      if (!(c == '~' || (c == 'B' && monolith))) continue;
      if (s.pinned.contains(sqKey(x, y))) continue;
      var ok = true, lit = false;
      for (final l in lamps) {
        if (!shadowLights(d, l, x, y)) continue;
        lit = true;
        final h = _holders(d, s, l, x, y).where((c) => used.contains(c.id));
        if (h.isEmpty) {
          ok = false;
          break;
        }
      }
      if (ok && lit) out.add(sqKey(x, y));
    }
  }
  return out;
}

/// After the light moves (a crank, or Solarin struck), anyone on glass that
/// no longer holds falls back to where the room lets them in.
({ShadowState state, List<String> fell}) shadowResolveFalls(
  ShadowRoomDef d,
  ShadowState s,
) {
  var pos = Map.of(s.pos);
  final fell = <String>[];
  for (final n in kShadowNames) {
    final p = pos[n]!;
    if (!d.isGlass(p.x, p.y)) continue;
    if (shadowHolds(d, s.copyWith(pos: pos), p.x, p.y, n)) continue;
    fell.add(n);
  }
  for (final n in fell) {
    final homes = [d.start[n]!, ...d.start.values];
    final free = homes.firstWhere(
      (h) => !kShadowNames.any(
        (m) => m != n && pos[m]!.x == h.x && pos[m]!.y == h.y,
      ),
      orElse: () => d.start[n]!,
    );
    pos = {...pos, n: free};
  }
  return (state: s.copyWith(pos: pos), fell: fell);
}

/// Can [who] strike Solarin from where it stands? Two squares, no further.
bool shadowSolarinReach(ShadowRoomDef d, ShadowState s, String who) {
  if (d.orbit == null || s.hits >= 3) return false;
  final o = d.orbit![s.orbit], p = s.pos[who]!;
  final dx = (p.x - o.x).toDouble(), dy = (p.y - o.y).toDouble();
  return sqrt(dx * dx + dy * dy) <= 2.01;
}

bool shadowSolved(ShadowRoomDef d, ShadowState s) {
  if (d.goal == 'hits') return s.hits >= 3;
  bool on(String n) => d.at(s.pos[n]!.x, s.pos[n]!.y) == 'G';
  return d.goal == 'any' ? kShadowNames.any(on) : kShadowNames.every(on);
}

/// Every legal move from [s], for the solver.
List<(String, ShadowState)> shadowMoves(
  ShadowRoomDef d,
  ShadowState s, {
  Set<String>? actors,
}) {
  bool may(String n) => actors == null || actors.contains(n);
  final out = <(String, ShadowState)>[];
  for (final n in kShadowNames) {
    if (!may(n)) continue;
    final p = s.pos[n]!;
    for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final x = p.x + dx, y = p.y + dy;
      if (shadowStepCheck(d, s, n, x, y) != null) continue;
      out.add(('$n>$x,$y', s.moved(n, sq(x, y))));
    }
  }
  if (s.pins > 0 && may('Dark')) {
    final cells = shadowPinCells(d, s);
    if (cells != null && cells.isNotEmpty) {
      out.add((
        'pin',
        s.copyWith(pinned: {...s.pinned, ...cells}, pins: s.pins - 1),
      ));
    }
  }
  final st = s.pos['Steam']!;
  if (may('Steam')) {
    if (d.vents.any((v) => v.x == st.x && v.y == st.y) &&
        !(s.veil != null && s.veil!.x == st.x && s.veil!.y == st.y)) {
      out.add(('veil', s.copyWith(veil: st)));
    }
    if (!s.piped) {
      for (final (a, b) in d.pipes) {
        if (st.x != a.x || st.y != a.y) continue;
        if (shadowOccupant(s, b.x, b.y, 'Steam') != null) continue;
        out.add(('pipe', s.copyWith(piped: true, pos: {...s.pos, 'Steam': b})));
      }
    }
  }
  final li = s.pos['Light']!;
  if (d.rail != null && d.at(li.x, li.y) == 'C' && may('Light')) {
    out.add((
      'crank',
      shadowResolveFalls(
        d,
        s.copyWith(rail: (s.rail + 1) % d.rail!.length),
      ).state,
    ));
  }
  if (d.orbit != null) {
    for (final n in kShadowNames) {
      if (!may(n) || !shadowSolarinReach(d, s, n)) continue;
      out.add((
        'strike($n)',
        shadowResolveFalls(
          d,
          s.copyWith(hits: s.hits + 1, orbit: (s.orbit + 1) % d.orbit!.length),
        ).state,
      ));
    }
  }
  return out;
}

/// Breadth-first search to a solved state: the fewest moves, and the plan.
({bool solvable, int states, List<String> plan}) solveShadowRoom(
  ShadowRoomDef d, {
  ShadowState? from,
  Set<String>? actors,
  int limit = 400000,
  bool Function(String label)? allow,
}) {
  final s0 = from ?? ShadowState.start(d);
  final seen = <String, (String, String)?>{s0.encoded: null};
  final q = <ShadowState>[s0];
  var head = 0;
  ShadowState? goal;
  while (head < q.length && seen.length < limit) {
    final s = q[head++];
    if (shadowSolved(d, s)) {
      goal = s;
      break;
    }
    for (final (label, t) in shadowMoves(d, s, actors: actors)) {
      if (allow != null && !allow(label)) continue;
      final e = t.encoded;
      if (seen.containsKey(e)) continue;
      seen[e] = (s.encoded, label);
      q.add(t);
    }
  }
  if (goal == null) {
    return (solvable: false, states: seen.length, plan: const <String>[]);
  }
  final plan = <String>[];
  for (var e = goal.encoded; seen[e] != null; e = seen[e]!.$1) {
    plan.insert(0, seen[e]!.$2);
  }
  return (solvable: true, states: seen.length, plan: plan);
}

// ─────────────────────────────────────────────────────────
// THE ROOMS
// ─────────────────────────────────────────────────────────

const ShadowRoomDef kRoomOwnShadow = ShadowRoomDef(
  id: 'own_shadow',
  map: [
    '...~~~~~GGG',
    '...~~~~~GGG',
    '...~~~~~GGG',
    'L..~~~~~GGG',
    '...~~~~~GGG',
    '...~~~~~GGG',
    '...~~~~~GGG',
  ],
  start: {'Light': (x: 1, y: 5), 'Dark': (x: 2, y: 5), 'Steam': (x: 1, y: 4)},
  pins: 1,
);

const ShadowRoomDef kRoomTwoSuns = ShadowRoomDef(
  id: 'two_suns',
  map: [
    '...~~~~~GGG',
    '...~~~~~GGG',
    '...~~~~~GGG',
    'L..~~~~~GGL',
    '...~~~~~GGG',
    '...~~~~~GGG',
    '..p~~~~~pGG',
  ],
  pipes: [((x: 2, y: 6), (x: 8, y: 6))],
  start: {'Light': (x: 1, y: 5), 'Dark': (x: 0, y: 5), 'Steam': (x: 1, y: 4)},
  pins: 1,
);

const ShadowRoomDef kRoomTwoGaps = ShadowRoomDef(
  id: 'two_gaps',
  // Authored upside down from the prototype (a mirror image proves the same
  // thing), so its door can sit on its north wall under the hall's south one.
  map: [
    '....~~.S.##',
    '..V.~~...##',
    'E...~~...##',
    '....~~#..##',
    '#######~~##',
    '#######~~##',
    '#######~~##',
    '######GGGGG',
    '######GGGGG',
  ],
  start: {'Light': (x: 1, y: 1), 'Dark': (x: 1, y: 0), 'Steam': (x: 0, y: 0)},
  pins: 1,
);

const ShadowRoomDef kRoomDoorOfShadow = ShadowRoomDef(
  id: 'door_of_shadow',
  map: [
    'n..~~~~~BGG',
    'n..~~~~~BGG',
    'n..~~~~~BGG',
    'nM.~~~~~BGG',
    'n..~~~~~BGG',
    'n..~~~~~BGG',
    'C..~~~~~BGG',
  ],
  rail: [
    (x: 0, y: 0),
    (x: 0, y: 1),
    (x: 0, y: 2),
    (x: 0, y: 3),
    (x: 0, y: 4),
    (x: 0, y: 5),
  ],
  start: {'Light': (x: 1, y: 5), 'Dark': (x: 2, y: 5), 'Steam': (x: 2, y: 4)},
  pins: 1,
);

const ShadowRoomDef kRoomSolarin = ShadowRoomDef(
  id: 'solarin_orbit',
  map: [
    '~~~~~~~~~~~',
    '..~~~~~~~~~',
    '..~~~P~~~~~',
    '..~~~~~~~~~',
    '..~~~d~~P~~',
    '..~~~~~~~~~',
    '..~~~P~~~~~',
    '..~~~~~~~~~',
    '~~~~~~~~~~~',
  ],
  orbit: [(x: 9, y: 4), (x: 5, y: 7), (x: 5, y: 1)],
  pillarR: 0.42,
  goal: 'hits',
  start: {'Light': (x: 1, y: 3), 'Dark': (x: 1, y: 4), 'Steam': (x: 0, y: 5)},
);

const ShadowRoomDef kRoomReliquary = ShadowRoomDef(
  id: 'sunless_reliquary',
  map: [
    '...#~~~~~~n',
    '...#~~~~~~n',
    '...#~~~~~~n',
    '...~~GR~~~n',
    '...#~~~~~~n',
    '...#~~~~~~n',
    'C..#~~~~~~n',
  ],
  rail: [
    (x: 10, y: 0),
    (x: 10, y: 1),
    (x: 10, y: 2),
    (x: 10, y: 3),
    (x: 10, y: 4),
    (x: 10, y: 5),
  ],
  goal: 'any',
  start: {'Light': (x: 0, y: 1), 'Dark': (x: 0, y: 2), 'Steam': (x: 1, y: 2)},
);

/// THE ECLIPSE — the last room before Solarin, and the hard one. Found by a
/// search over several hundred layouts (docs/prototypes/light_shadow_floor,
/// gen2.js) for the room where the crank, the pin and the veil are each
/// necessary: fifty moves at best, and four of every five positions the
/// party can reach are dead ends.
///
/// Its idea: WALLS BLOCK STARLIGHT. The railed star walks along the top, the
/// two blocks in the glass eclipse it, and each turn of the crank walks their
/// shadow across the floor — you ride it, and a body left on glass the
/// shadow has moved off falls back to the ledge. The veil holds the fixed
/// star off the path; the pin is spent at the one moment it keeps the road.
const ShadowRoomDef kRoomEclipse = ShadowRoomDef(
  id: 'eclipse_walk',
  map: [
    '..nnnnnGG',
    '..~~~~~GG',
    '..~~~~~GG',
    'E.~~##~GG',
    '.V~~~~~GG',
    'C.~~~~~GG',
  ],
  rail: [(x: 2, y: 0), (x: 3, y: 0), (x: 4, y: 0), (x: 5, y: 0), (x: 6, y: 0)],
  railStart: 1,
  cone: 0.8,
  start: {'Light': (x: 1, y: 3), 'Dark': (x: 0, y: 0), 'Steam': (x: 1, y: 2)},
  pins: 1,
);

/// Every grid room, by the id [ShadowBay.grid] names.
const Map<String, ShadowRoomDef> kShadowRooms = {
  'own_shadow': kRoomOwnShadow,
  'two_suns': kRoomTwoSuns,
  'two_gaps': kRoomTwoGaps,
  'door_of_shadow': kRoomDoorOfShadow,
  'eclipse_walk': kRoomEclipse,
  'solarin_orbit': kRoomSolarin,
  'sunless_reliquary': kRoomReliquary,
};

/// The four rooms whose spans build the hall's bridge, in order, and the
/// star each pair banks.
const List<String> kBridgeRooms = [
  'own_shadow',
  'key_room',
  'two_suns',
  'two_gaps',
];
const Map<String, int> kBridgeStar = {
  'own_shadow': 0,
  'key_room': 0,
  'two_suns': 1,
  'two_gaps': 1,
};

// ─────────────────────────────────────────────────────────
// THE HALL
// ─────────────────────────────────────────────────────────

/// The great hall: near ledge, near well, island, far well, far ledge. The
/// wells are DEEP light, lit from below, where no shadow can hold: only the
/// spans a solved room sets, and — for one body — the gold sun.
const List<String> kHallMap = [
  '...**...**...',
  '...**...**...',
  '...**...**...',
  '...**...**...',
  '...**...O*...',
  '...**...**...',
  '...**...**...',
];

const int kHallCols = 13, kHallRows = 7;

/// Which span each room sets.
const Map<String, Sq> kHallSpans = {
  'own_shadow': (x: 3, y: 3),
  'key_room': (x: 4, y: 3),
  'two_suns': (x: 8, y: 3),
  'two_gaps': (x: 9, y: 3),
};

/// The gold sun inlaid in the far well — the Lost Maxim. Light walks on
/// light; nothing else does.
const Sq kHallSun = (x: 8, y: 4);

/// The hall's own star on its stand, on the near ledge. Waking it is the
/// entry rite.
const Offset kHallKindle = Offset(160, 400);

// ─────────────────────────────────────────────────────────
// ROOM II — THE KEY (a floor below, the arch on the north face)
// ─────────────────────────────────────────────────────────

/// How deep the key room's north face is: tall, because the arch is in it.
const double kKeyFace = 176;

/// One key-room unit, in world.
const double kKeyU = 64;

/// The tiny key on its plinth, in floor units (x across, y out from the
/// arch's wall, z up).
const double kKeyX = 6.5, kKeyY = 3.6, kKeyZ = 0.55;
const double kKeyLampZ = 0.5;
const double kArchL = 3, kArchR = 7, kArchSpring = 1.6, kArchApex = 2.4;
const List<double> kKeyStudX = [3, 4, 5, 6, 7, 8, 9];
const List<double> kKeyStudY = [4.0, 4.8, 5.6];
const double kKeyAnswerX = 7, kKeyAnswerY = 4.8;

/// Floor units to world.
Offset keyFloor(double x, double y) => Offset(x * kKeyU, kKeyFace + y * kKeyU);

/// How much the key's shadow is magnified on the arch from a starlight at
/// floor distance [ly] from the wall.
double keyMagnify(double ly) => ly / (ly - kKeyY);

/// A key point (x, z) projected onto the arch from a starlight at (lx, ly).
(double, double) keyProject(double lx, double ly, double x, double z) {
  final m = keyMagnify(ly);
  return (lx + (x - lx) * m, kKeyLampZ + (z - kKeyLampZ) * m);
}

/// The one stud that lays the key's shadow in the lock.
bool keyFits(double lx, double ly) =>
    (lx - kKeyAnswerX).abs() < .01 && (ly - kKeyAnswerY).abs() < .01;

// ─────────────────────────────────────────────────────────
// PER-ROOM CONTENT
// ─────────────────────────────────────────────────────────

/// Everything the shadow floor puts in one room. Carried on
/// `DungeonRoom.hall`, so one field serves the planet.
class ShadowBay {
  /// 'hall', 'grid' or 'key'.
  final String kind;

  /// The grid room id in [kShadowRooms] (kind 'grid').
  final String? grid;

  const ShadowBay.hall() : kind = 'hall', grid = null;
  const ShadowBay.grid(String this.grid) : kind = 'grid';
  const ShadowBay.key() : kind = 'key', grid = null;

  ShadowRoomDef? get def => grid == null ? null : kShadowRooms[grid];

  /// The star a room's solving counts toward (the pairs bank together).
  int? get starIndex => kind == 'key' ? 0 : kBridgeStar[grid];
}

// ─────────────────────────────────────────────────────────
// THE RUN — pure state, one per descent
// ─────────────────────────────────────────────────────────

/// Everything the Shadow Floor tracks for one run, and the visual clocks the
/// render reads (named here so the render has somewhere to keep them).
class ShadowRun {
  ShadowRun() {
    reset();
  }

  /// Each grid room's state, made on first entry.
  final Map<String, ShadowState> rooms = {};

  /// Rooms solved this run (the bridge rooms, the rite, the vault).
  final Set<String> solved = {};

  /// ROOM II: where its starlight stands, whether the veil hangs, and
  /// whether the key has been set in the lock.
  double keyLampX = 4, keyLampY = 5.6;
  bool keyVeil = false;
  bool keyPinned = false;

  // ── The moments: seconds since each began (visual only) ──
  final Map<String, double> spanSet = {}; // room id -> time its span set
  final Map<int, double> stoneSet = {}; // square key -> time it set, per room
  String? stoneRoom;
  double railFrom = -1, railT = -9; // the railed starlight gliding
  double orbitFrom = -1, orbitT = -9; // Solarin swinging round
  double veilT = -9, pinT = -9, keyT = -9, solvedT = -9, maximT = -9;
  final Map<String, double> fellT = {};

  // ── The render's caches (so a frame does not re-derive the floor) ──
  /// Which glass squares hold for someone right now, and when each began to.
  String? heldKey;
  Set<int> held = const {};
  final Map<int, double> heldSince = {};
  String? heldRoom;

  /// SOLARIN'S FLARE: when it began charging, and at whom; and the
  /// last time one landed (visual).
  double flareT = -9, flareHitT = -9, flareNext = 3;
  String? flareAt;

  /// What the floor will be once Solarin swings on (cached per floor).
  String? nextHeldKey;
  Set<int> nextHeld = const {};

  /// What a pin would set from where Dark stands (cached per floor).
  String? pinPreviewKey;
  List<int> pinPreview = const [];

  /// Where ROOM II's starlight is drawn (it glides between studs).
  double keyShowX = 4, keyShowY = 5.6;

  ShadowState state(String id) =>
      rooms.putIfAbsent(id, () => ShadowState.start(kShadowRooms[id]!));

  void resetRoom(String id) {
    rooms.remove(id);
    solved.remove(id);
    if (id == 'key_room') {
      keyLampX = 4;
      keyLampY = 5.6;
      keyVeil = false;
      keyPinned = false;
    }
  }

  void reset() {
    rooms.clear();
    solved.clear();
    keyLampX = 4;
    keyLampY = 5.6;
    keyVeil = false;
    keyPinned = false;
    spanSet.clear();
    stoneSet.clear();
    stoneRoom = null;
    fellT.clear();
  }

  bool get bridgeWhole => kBridgeRooms.every(solved.contains);
}

// ─────────────────────────────────────────────────────────
// THE LAYOUT (grid squares: centre = ((x+.5)·64, 48+(y+.5)·64))
// ─────────────────────────────────────────────────────────
//
// Every doorway faces the hall across the wall between them: the hall's
// north doors come up through a room's south wall, its south doors down
// through a north wall, so you never arrive on the side you left from.

/// Solarin — the Shadow Floor.
const DungeonLayout lightLayout = DungeonLayout(
  element: 'Light',
  entranceRoomId: 'light_hall',
  entranceSpawn: Offset(96, 272),
  title: 'THE SHADOW FLOOR',
  descentTitle: 'Solarin Archive',
  stars: [
    DungeonStarSpec(
      name: 'Shadow Star',
      earnAnnouncement:
          'The Shadow Star is yours. The near well is bridged in shadow',
    ),
    DungeonStarSpec(
      name: 'Stone Star',
      earnAnnouncement:
          'The Stone Star is yours. The far well is bridged, and the Door of '
          'Shadow waits',
    ),
    DungeonStarSpec(name: 'Corona Star'),
  ],
  // The hall's star is dark until Light wakes it, and Room I's door with it.
  entranceRevealDoor: DungeonDoorRef('light_hall', 'own_shadow'),
  finaleDoor: DungeonDoorRef('light_hall', 'door_of_shadow'),
  riteAnnouncement:
      'Shadow and Stone are won. The Door of Shadow is on the far ledge',
  riteWakeLine: 'Solarin wakes, and turns its light on you',
  finaleSealedHint: 'The Door of Shadow waits on the Shadow and Stone stars',
  guardianSealedHint: 'Solarin sleeps behind a wall with no door in it',
  mercyShrineRoomId: 'light_hall',
  riddle: [
    'Send me Light, to turn my stars on their rails, for my floors are only shadow;',
    'Dark, to set a passing shadow into stone and keep it there;',
    'and Steam, to hang a veil where the light has nothing to land on.',
  ],
  primer: [
    'Light is nothing here. Only shadow holds your weight.',
    'Nothing stands on its own shadow.',
  ],
  rooms: {
    // ── THE GREAT HALL (entrance, hub) ───────────────────
    'light_hall': DungeonRoom(
      id: 'light_hall',
      bounds: Rect.fromLTWH(0, 0, 832, 496),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(72, 0, 110, 24),
          targetRoomId: 'own_shadow',
          targetSpawn: Offset(96, 400),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(0, 313, 24, 110),
          targetRoomId: 'key_room',
          targetSpawn: Offset(560, 298),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(328, 0, 110, 24),
          targetRoomId: 'two_suns',
          targetSpawn: Offset(96, 400),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(328, 472, 110, 24),
          targetRoomId: 'two_gaps',
          targetSpawn: Offset(96, 144),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(72, 472, 110, 24),
          targetRoomId: 'sunless_reliquary',
          targetSpawn: Offset(96, 144),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(808, 185, 24, 110),
          targetRoomId: 'door_of_shadow',
          targetSpawn: Offset(96, 400),
        ),
      ],
      hall: ShadowBay.hall(),
    ),

    // ── I · NOTHING STANDS ON ITS OWN SHADOW ─────────────
    'own_shadow': DungeonRoom(
      id: 'own_shadow',
      bounds: Rect.fromLTWH(0, 0, 704, 496),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(72, 472, 110, 24),
          targetRoomId: 'light_hall',
          targetSpawn: Offset(96, 80),
        ),
      ],
      // The verb, once ever — never the answer.
      teach: 'Dark can set the shadow it stands in into stone',
      hall: ShadowBay.grid('own_shadow'),
    ),

    // ── II · THE KEY ─────────────────────────────────────
    'key_room': DungeonRoom(
      id: 'key_room',
      bounds: Rect.fromLTWH(0, 0, 640, 560),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(616, 236, 24, 110),
          targetRoomId: 'light_hall',
          targetSpawn: Offset(96, 336),
        ),
      ],
      hall: ShadowBay.key(),
    ),

    // ── III · TWO SUNS ───────────────────────────────────
    'two_suns': DungeonRoom(
      id: 'two_suns',
      bounds: Rect.fromLTWH(0, 0, 704, 496),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(72, 472, 110, 24),
          targetRoomId: 'light_hall',
          targetSpawn: Offset(416, 80),
        ),
      ],
      teach: 'Steam can rise through a pipe, once',
      hall: ShadowBay.grid('two_suns'),
    ),

    // ── IV · TWO GAPS, ONE PIN ───────────────────────────
    'two_gaps': DungeonRoom(
      id: 'two_gaps',
      bounds: Rect.fromLTWH(0, 0, 704, 624),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(72, 0, 110, 24),
          targetRoomId: 'light_hall',
          targetSpawn: Offset(416, 400),
        ),
      ],
      hall: ShadowBay.grid('two_gaps'),
    ),

    // ── THE DOOR OF SHADOW (the rite) ────────────────────
    'door_of_shadow': DungeonRoom(
      id: 'door_of_shadow',
      bounds: Rect.fromLTWH(0, 0, 704, 496),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(72, 472, 110, 24),
          targetRoomId: 'light_hall',
          targetSpawn: Offset(736, 208),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(680, 185, 24, 110),
          targetRoomId: 'eclipse_walk',
          targetSpawn: Offset(96, 144),
        ),
      ],
      hall: ShadowBay.grid('door_of_shadow'),
    ),

    // ── THE ECLIPSE (the last room before Solarin) ───────
    'eclipse_walk': DungeonRoom(
      id: 'eclipse_walk',
      bounds: Rect.fromLTWH(0, 0, 576, 432),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 57, 24, 110),
          targetRoomId: 'door_of_shadow',
          targetSpawn: Offset(608, 208),
        ),
        DungeonDoor(
          rect: Rect.fromLTWH(552, 185, 24, 110),
          targetRoomId: 'solarin_orbit',
          targetSpawn: Offset(96, 272),
        ),
      ],
      hall: ShadowBay.grid('eclipse_walk'),
    ),

    // ── SOLARIN (Star 3) ─────────────────────────────────
    'solarin_orbit': DungeonRoom(
      id: 'solarin_orbit',
      bounds: Rect.fromLTWH(0, 0, 704, 624),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 249, 24, 110),
          targetRoomId: 'eclipse_walk',
          targetSpawn: Offset(480, 208),
        ),
      ],
      guardian: GuardianNode(
        position: Offset(608, 336),
        starIndex: 2,
        encounter: GuardianEncounterRequirement(
          element: 'Light',
          mysticId: 'Solarin',
          canCalm: true,
          canDefeat: true,
        ),
      ),
      hall: ShadowBay.grid('solarin_orbit'),
    ),

    // ── THE SUNLESS RELIQUARY (the vault) ────────────────
    'sunless_reliquary': DungeonRoom(
      id: 'sunless_reliquary',
      bounds: Rect.fromLTWH(0, 0, 704, 496),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(72, 0, 110, 24),
          targetRoomId: 'light_hall',
          targetSpawn: Offset(96, 400),
        ),
      ],
      vaultCache: Offset(352, 272),
      hall: ShadowBay.grid('sunless_reliquary'),
    ),
  },
);
