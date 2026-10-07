// lib/games/planet_dungeon/planet_dungeon_layout_dark.dart
//
// NYTHRALOR — THE BLACK SUN (the rebuild of 2026-09-30; it replaces the
// Eclipse Vault whole). Dark's layout, its pure rules, and the room grids.
//
// THE PARTY is two Darks and a Light, and — alone of every planet — they do
// not travel together. Every body stays exactly where it was left; a door
// takes only the one you are steering. So a Dark left in one room holds its
// portal open there while you work in the next.
//
//   · LIGHT shines a beam in one direction and holds it until told to stop,
//     but only from a BURNING-GLASS set in the floor; step off it and the
//     beam goes out. Its body lets light straight through.
//   · Each DARK owns ONE PORTAL — two ends, I and II. The first Dark's are
//     black with PURPLE motes, the second's black with ORANGE. A Dark casts
//     an end straight ahead onto the first wall it sees; only OBSIDIAN takes
//     it. Casting an end onto the face it already holds closes it. A Dark's
//     body DRINKS light: a beam stops dead at it.
//
// WHAT GOES THROUGH A PORTAL: bodies (all three) and beams — whatever enters
// one end leaves the other end's face heading straight out of it, and the
// two ends may be in different rooms.
//
// DARK + LIGHT = BLOOD. A beam through ONE Dark's portal is still white
// light, only moved. Through BOTH Darks' portals, in either order, it comes
// out as BLOOD-LIGHT, and blood-light is SOLID: over the void it is a bridge.
// A Dark drinks the beam it stands in, so it can only walk a bridge towards
// its source.
//
// Every room was proved in the prototype before it was built — the same maps,
// by breadth-first search (docs/prototypes/dark_portals: portal-engine.js is
// these rules in JavaScript, solve.js the proofs, proofs.txt the last run).
// The tests replay the prototype's plans against THESE rules.
//
// Map legend:
//   .  floor          #  stone wall          O  obsidian (takes portals)
//   ~  the void (you stand on it only where blood-light crosses it)
//   *  a burning-glass (floor; Light shines only from one)
//   p  a plate (held down by any body)     E  a goal pad (all three: solved)
//   |  a door in the room: open while its circuit is live, or while a body
//      stands in it (a LATCHING circuit keeps it open once it has been live)
//   w  a white seal (lit by white light)  r  a red seal (lit by blood-light)
//   > < ^ v  a star set in the wall, shining that way
//   V  the vault cache (floor)
//   D  a doorway to another room (floor)  S  the island's stair (floor)

import 'dart:ui';

import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_verbs.dart';

// ─────────────────────────────────────────────────────────
// THE GRID
// ─────────────────────────────────────────────────────────

/// One square of floor, in world units. A room's bounds are exactly its grid.
const double kSunCell = 64;

/// The three bodies, in the order a Dark·Dark·Light party lists them.
const List<String> kSunBodies = ['light', 'purple', 'orange'];
const List<String> kSunDarks = ['purple', 'orange'];

/// The four directions: north, east, south, west.
const List<int> kSunDx = [0, 1, 0, -1];
const List<int> kSunDy = [-1, 0, 1, 0];
const List<String> kSunDirWord = ['north', 'east', 'south', 'west'];
int sunOpp(int d) => (d + 2) % 4;

/// Beam colour bits.
const int kSunWhite = 1, kSunBlood = 2;

typedef SunCell = ({int x, int y});

/// Where a body is: which room, which square.
typedef SunAt = ({String room, int x, int y});

/// Where a portal end is: which room, which obsidian face.
typedef SunEnd = ({String room, int face});

/// World centre of square (x, y).
Offset sunCentre(int x, int y) =>
    Offset((x + .5) * kSunCell, (y + .5) * kSunCell);

/// The square a world point stands in (clamped onto the grid).
SunCell sunSquareAt(Offset p, int cols, int rows) => (
  x: (p.dx / kSunCell).floor().clamp(0, cols - 1),
  y: (p.dy / kSunCell).floor().clamp(0, rows - 1),
);

/// One face of an obsidian block: the block's square and the side it looks
/// out of. A portal end sits on a face; what comes out of it comes out of
/// that side.
class SunFace {
  final int x, y, d;
  const SunFace(this.x, this.y, this.d);

  /// The square in front of the face.
  SunCell get front => (x: x + kSunDx[d], y: y + kSunDy[d]);
}

/// A star set in a wall, shining one way. [star] is the dungeon star whose
/// winning lights it; null burns from the start.
class SunEmitter {
  final int x, y, d;
  final int? star;
  const SunEmitter(this.x, this.y, this.d, this.star);
}

/// One circuit: every trigger (plate or seal) live at once holds every door.
class SunCircuit {
  final List<SunCell> triggers;
  final List<SunCell> doors;
  final bool latch;
  const SunCircuit({
    required this.triggers,
    required this.doors,
    this.latch = false,
  });
}

/// Squares nothing walks through (a shut door is decided at runtime).
const String kSunSolid = '#Owr><^v';

/// One room of the Black Sun, as authored.
class SunRoomDef {
  final String id;
  final List<String> map;

  /// Where bodies come in by the room's door, in order: the first free one.
  /// Also where a body falls back to.
  final List<SunCell> arrivals;

  /// Explicit circuits; null means one circuit — every plate and seal in the
  /// room together hold every door.
  final List<SunCircuit>? circuits;

  /// Whether the default circuit latches.
  final bool latch;

  /// Stars in the wall that burn only once a dungeon star is won
  /// ((x, y) → star index).
  final Map<SunCell, int> starGated;

  /// The dungeon star this chamber counts towards (null: not a chamber).
  final int? starIndex;

  const SunRoomDef({
    required this.id,
    required this.map,
    required this.arrivals,
    this.circuits,
    this.latch = false,
    this.starGated = const {},
    this.starIndex,
  });

  int get rows => map.length;
  int get cols => map.first.length;
  bool inside(int x, int y) => x >= 0 && y >= 0 && x < cols && y < rows;
  String at(int x, int y) => inside(x, y) ? map[y][x] : '#';

  /// Is there a goal pad in this room (a chamber)?
  bool get isChamber => exits.isNotEmpty;

  List<SunFace> get faces => _sunParsed(this).faces;
  int? faceAt(int x, int y, int d) => _sunParsed(this).faceAt['$x,$y,$d'];
  List<SunEmitter> get emitters => _sunParsed(this).emitters;
  List<SunCell> get plates => _sunParsed(this).plates;
  List<SunCell> get seals => _sunParsed(this).seals;
  List<SunCell> get doors => _sunParsed(this).doors;
  List<SunCell> get exits => _sunParsed(this).exits;
  List<SunCircuit> get allCircuits => _sunParsed(this).circuits;
}

class _SunParse {
  final List<SunFace> faces = [];
  final Map<String, int> faceAt = {};
  final List<SunEmitter> emitters = [];
  final List<SunCell> plates = [], seals = [], doors = [], exits = [];
  late final List<SunCircuit> circuits;
}

final Map<String, _SunParse> _sunParseCache = {};

_SunParse _sunParsed(SunRoomDef d) => _sunParseCache.putIfAbsent(d.id, () {
  final p = _SunParse();
  for (var y = 0; y < d.rows; y++) {
    for (var x = 0; x < d.cols; x++) {
      final c = d.map[y][x];
      if (c == 'O') {
        for (var k = 0; k < 4; k++) {
          final nx = x + kSunDx[k], ny = y + kSunDy[k];
          if (!d.inside(nx, ny)) continue;
          if (kSunSolid.contains(d.map[ny][nx])) continue;
          p.faceAt['$x,$y,$k'] = p.faces.length;
          p.faces.add(SunFace(x, y, k));
        }
      }
      final ed = switch (c) {
        '^' => 0,
        '>' => 1,
        'v' => 2,
        '<' => 3,
        _ => -1,
      };
      if (ed >= 0) {
        p.emitters.add(SunEmitter(x, y, ed, d.starGated[(x: x, y: y)]));
      }
      if (c == 'p') p.plates.add((x: x, y: y));
      if (c == 'w' || c == 'r') p.seals.add((x: x, y: y));
      if (c == '|') p.doors.add((x: x, y: y));
      if (c == 'E') p.exits.add((x: x, y: y));
    }
  }
  p.circuits =
      d.circuits ??
      [
        SunCircuit(
          triggers: [...p.plates, ...p.seals],
          doors: p.doors,
          latch: d.latch,
        ),
      ];
  return p;
});

// ─────────────────────────────────────────────────────────
// THE STATE — one per descent
// ─────────────────────────────────────────────────────────

/// Everything the rules read that the player can change. Immutable: every
/// action returns a new one, so the solver and the game share one set of
/// sentences.
class SunState {
  /// Where each body is.
  final Map<String, SunAt> pos;

  /// Light's beam: the direction it shines, or -1.
  final int shine;

  /// Each Dark's two ends, I and II (null: not cast).
  final Map<String, List<SunEnd?>> ends;

  /// Latched circuits, as 'room#index'.
  final Set<String> latched;

  const SunState({
    required this.pos,
    this.shine = -1,
    this.ends = const {
      'purple': [null, null],
      'orange': [null, null],
    },
    this.latched = const {},
  });

  SunState copyWith({
    Map<String, SunAt>? pos,
    int? shine,
    Map<String, List<SunEnd?>>? ends,
    Set<String>? latched,
  }) => SunState(
    pos: pos ?? this.pos,
    shine: shine ?? this.shine,
    ends: ends ?? this.ends,
    latched: latched ?? this.latched,
  );

  SunState moved(String who, SunAt to) => copyWith(pos: {...pos, who: to});

  SunState withEnd(String who, int end, SunEnd? at) {
    final both = List<SunEnd?>.of(ends[who]!);
    both[end] = at;
    return copyWith(ends: {...ends, who: both});
  }

  /// A key for the search: the Darks' two ends are the same physics either
  /// way round, so each Dark's pair is sorted.
  String get encoded {
    final b = StringBuffer();
    for (final n in kSunBodies) {
      final p = pos[n]!;
      b.write('${p.room}.${p.x}.${p.y}|');
    }
    b.write('$shine|');
    for (final o in kSunDarks) {
      final e = [
        for (final v in ends[o]!) v == null ? '-' : '${v.room}.${v.face}',
      ]..sort();
      b.write('${e.join(',')}|');
    }
    b.write((latched.toList()..sort()).join(','));
    return b.toString();
  }
}

/// The world the state lives in: the rooms, which dungeon stars are won,
/// and which chambers are solved (a solved chamber's void is set solid and
/// its doors stand open for good).
class SunWorld {
  final Map<String, SunRoomDef> rooms;
  final Set<int> stars;
  final Set<String> solved;

  /// The doors between rooms, as the rules see them (the game's own doors
  /// are `DungeonDoor`s; these mirror them so the solver can walk the whole
  /// descent).
  final List<SunLink> links;
  const SunWorld({
    this.rooms = kSunRooms,
    this.stars = const {},
    this.solved = const {},
    this.links = kSunLinks,
  });
}

/// A door between rooms: standing on its square in [room], a body can go
/// through to [to]'s square (tx, ty). [heldBy] is a plate or seal in [room]
/// that must be live for it to open (null: always open).
class SunLink {
  final String room;
  final int x, y;
  final String to;
  final int tx, ty;
  final SunCell? heldBy;
  const SunLink(
    this.room,
    this.x,
    this.y,
    this.to,
    this.tx,
    this.ty, {
    this.heldBy,
  });
}

/// Is [l] open with the world as [e] has it?
bool sunLinkOpen(SunLink l, SunEval e) =>
    l.heldBy == null || e.live.contains(sunKey(l.room, l.heldBy!.x, l.heldBy!.y));

/// [who], standing on [l]'s square, goes through it.
SunResult sunTakeLink(SunWorld w, SunState s, String who, SunLink l, {SunEval? eval}) {
  final p = s.pos[who]!;
  if (p.room != l.room || p.x != l.x || p.y != l.y) {
    return const SunResult.no('not at the door');
  }
  if (!w.rooms.containsKey(l.to)) return const SunResult.no('no room');
  final e = eval ?? sunEvaluate(w, s);
  if (!sunLinkOpen(l, e)) return const SunResult.no('door');
  if (sunBodyAt(s, l.to, l.tx, l.ty, who) != null) {
    return const SunResult.no('body');
  }
  return sunPlace(w, s, who, (room: l.to, x: l.tx, y: l.ty));
}

// ─────────────────────────────────────────────────────────
// THE RULES (pure — the same sentences as the prototype's engine)
// ─────────────────────────────────────────────────────────

/// One beam, as drawn: its points and what it had been through at each.
class SunBeamPoint {
  final String room;
  final double x, y; // grid units (square centres; mouths at the face)
  final int via; // 1 purple, 2 orange, 3 both (blood)
  final bool jump; // arrived through a portal (no line to it)
  const SunBeamPoint(this.room, this.x, this.y, this.via, {this.jump = false});
}

class SunBeam {
  final String from; // 'light' or 'star'
  final List<SunBeamPoint> path;
  final String end; // 'wall', 'seal', 'drunk', 'loop', 'lone mouth', …
  const SunBeam(this.from, this.path, this.end);

  /// A light that does not end: it went round through a portal and came back
  /// to where it had already been.
  bool get loopsThroughPortal => end == 'loop' && path.any((p) => p.jump);
}

/// What the world looks like in [s]: which squares are lit (and how), which
/// seals burn, which doors stand open, and every beam's road.
class SunEval {
  final Map<String, Map<int, int>> lit; // room → square key → colour bits
  final Set<String> sealsLit; // 'room:x,y'
  final Set<String> live; // triggers live, 'room:x,y'
  final Set<String> open; // doors open, 'room:x,y'
  final Set<String> nowLatched; // circuits that latch now, 'room#i'
  final List<SunBeam> beams;
  const SunEval({
    required this.lit,
    required this.sealsLit,
    required this.live,
    required this.open,
    required this.nowLatched,
    required this.beams,
  });

  int litAt(String room, int x, int y) => lit[room]?[y * 64 + x] ?? 0;
}

String sunKey(String room, int x, int y) => '$room:$x,$y';

/// Which body stands at (room, x, y), other than [except].
String? sunBodyAt(SunState s, String room, int x, int y, [String? except]) {
  for (final n in kSunBodies) {
    if (n == except) continue;
    final p = s.pos[n]!;
    if (p.room == room && p.x == x && p.y == y) return n;
  }
  return null;
}

/// The portal end sitting on face [f] of [room], as (owner, end).
(String, int)? sunMouthOn(SunState s, String room, int f) {
  for (final o in kSunDarks) {
    final e = s.ends[o]!;
    for (var i = 0; i < 2; i++) {
      final v = e[i];
      if (v != null && v.room == room && v.face == f) return (o, i);
    }
  }
  return null;
}

/// Where [mouth]'s pair leads, or null while the pair is not whole.
SunEnd? sunPartner(SunState s, (String, int) mouth) =>
    s.ends[mouth.$1]![1 - mouth.$2];

bool _sunSolidAt(
  SunWorld w,
  SunRoomDef d,
  Set<String> open,
  int x,
  int y,
) {
  final c = d.at(x, y);
  if (kSunSolid.contains(c)) return true;
  if (c == '|') return !open.contains(sunKey(d.id, x, y));
  return false;
}

/// Doors hang off seals, seals off beams, beams off doors. Opening a door
/// only ever LENGTHENS a beam, so starting with every door shut and opening
/// what the circuits allow until nothing changes lands on one answer.
SunEval sunEvaluate(SunWorld w, SunState s) {
  final occupied = {
    for (final n in kSunBodies) sunKey(s.pos[n]!.room, s.pos[n]!.x, s.pos[n]!.y),
  };
  var open = <String>{};
  for (final d in w.rooms.values) {
    for (final c in d.doors) {
      final k = sunKey(d.id, c.x, c.y);
      if (occupied.contains(k) || w.solved.contains(d.id)) open.add(k);
    }
    final cs = d.allCircuits;
    for (var i = 0; i < cs.length; i++) {
      if (!s.latched.contains('${d.id}#$i')) continue;
      for (final c in cs[i].doors) {
        open.add(sunKey(d.id, c.x, c.y));
      }
    }
  }
  late _SunTrace t;
  var live = <String>{};
  var nowLatched = <String>{};
  for (var round = 0; round < 8; round++) {
    t = _sunTraceAll(w, s, open);
    live = {
      for (final d in w.rooms.values)
        for (final p in d.plates)
          if (occupied.contains(sunKey(d.id, p.x, p.y))) sunKey(d.id, p.x, p.y),
      ...t.sealsLit,
    };
    final next = {...open};
    nowLatched = {};
    for (final d in w.rooms.values) {
      final cs = d.allCircuits;
      for (var i = 0; i < cs.length; i++) {
        final c = cs[i];
        if (c.triggers.isEmpty) continue;
        if (!c.triggers.every((q) => live.contains(sunKey(d.id, q.x, q.y)))) {
          continue;
        }
        for (final q in c.doors) {
          next.add(sunKey(d.id, q.x, q.y));
        }
        if (c.latch) nowLatched.add('${d.id}#$i');
      }
    }
    if (next.length == open.length) break;
    open = next;
  }
  return SunEval(
    lit: t.lit,
    sealsLit: t.sealsLit,
    live: live,
    open: open,
    nowLatched: nowLatched,
    beams: t.beams,
  );
}

class _SunTrace {
  final Map<String, Map<int, int>> lit = {};
  final Set<String> sealsLit = {};
  final List<SunBeam> beams = [];
}

_SunTrace _sunTraceAll(SunWorld w, SunState s, Set<String> open) {
  final t = _SunTrace();
  final lp = s.pos['light']!;
  if (s.shine >= 0) _sunTrace(w, s, open, lp.room, lp.x, lp.y, s.shine, 'light', t);
  for (final d in w.rooms.values) {
    for (final e in d.emitters) {
      if (e.star != null && !w.stars.contains(e.star)) continue;
      _sunTrace(w, s, open, d.id, e.x, e.y, e.d, 'star', t);
    }
  }
  return t;
}

void _sunTrace(
  SunWorld w,
  SunState s,
  Set<String> open,
  String room0,
  int x0,
  int y0,
  int d0,
  String from,
  _SunTrace t,
) {
  var room = room0;
  var x = x0, y = y0, d = d0, via = 0;
  final path = <SunBeamPoint>[SunBeamPoint(room, x.toDouble(), y.toDouble(), 0)];
  final seen = <String>{};
  var end = 'wall';
  for (var step = 0; step < 600; step++) {
    final def = w.rooms[room]!;
    final nx = x + kSunDx[d], ny = y + kSunDy[d];
    final c = def.at(nx, ny);
    if (!def.inside(nx, ny) || _sunSolidAt(w, def, open, nx, ny)) {
      final hx = x + kSunDx[d] * .5, hy = y + kSunDy[d] * .5;
      if (c == 'O') {
        final f = def.faceAt(nx, ny, sunOpp(d));
        final m = f == null ? null : sunMouthOn(s, room, f);
        final p = m == null ? null : sunPartner(s, m);
        if (m != null && p != null) {
          path.add(SunBeamPoint(room, hx, hy, via));
          via |= m.$1 == 'purple' ? 1 : 2;
          final pd = w.rooms[p.room]!;
          final pf = pd.faces[p.face];
          room = p.room;
          x = pf.x;
          y = pf.y;
          d = pf.d;
          path.add(
            SunBeamPoint(
              room,
              x + kSunDx[d] * .5,
              y + kSunDy[d] * .5,
              via,
              jump: true,
            ),
          );
          final k = '$room,$x,$y,$d,$via';
          if (!seen.add(k)) {
            end = 'loop';
            break;
          }
          continue;
        }
        end = m != null ? 'lone mouth' : 'obsidian';
      } else if (c == 'w' || c == 'r') {
        final blood = via == 3;
        if ((c == 'w' && !blood) || (c == 'r' && blood)) {
          t.sealsLit.add(sunKey(room, nx, ny));
        }
        end = 'seal';
      }
      path.add(SunBeamPoint(room, hx, hy, via));
      break;
    }
    x = nx;
    y = ny;
    final bits = via == 3 ? kSunBlood : kSunWhite;
    final roomLit = t.lit.putIfAbsent(room, () => {});
    roomLit[y * 64 + x] = (roomLit[y * 64 + x] ?? 0) | bits;
    final b = sunBodyAt(s, room, x, y);
    if (b == 'purple' || b == 'orange') {
      path.add(SunBeamPoint(room, x.toDouble(), y.toDouble(), via));
      end = 'drunk';
      break;
    }
    final k = '$room,$x,$y,$d,$via';
    if (!seen.add(k)) {
      path.add(SunBeamPoint(room, x.toDouble(), y.toDouble(), via));
      end = 'loop';
      break;
    }
    path.add(SunBeamPoint(room, x.toDouble(), y.toDouble(), via));
  }
  t.beams.add(SunBeam(from, path, end));
}

/// Can a body stand on (room, x, y) with the world as [e] has it?
bool sunHolds(SunWorld w, SunEval e, String room, int x, int y) {
  final d = w.rooms[room]!;
  final c = d.at(x, y);
  if ('.pE*VDS'.contains(c)) return true;
  if (c == '|') return e.open.contains(sunKey(room, x, y));
  if (c == '~') {
    return w.solved.contains(room) || (e.litAt(room, x, y) & kSunBlood) != 0;
  }
  return false;
}

/// The result of an action: the new state, who fell, and whether a body
/// went through a portal. Or a reason it was refused.
class SunResult {
  final SunState? state;
  final SunEval? eval;
  final List<String> fell;
  final (String, int)? through;
  final String? why;
  const SunResult.ok(
    SunState this.state,
    SunEval this.eval, {
    this.fell = const [],
    this.through,
  }) : why = null;
  const SunResult.no(String this.why)
    : state = null,
      eval = null,
      fell = const [],
      through = null;
  bool get ok => why == null;
}

/// Anyone left over the void falls back to where their room lets them in.
/// Repeats, since a fall can move a beam. Latches what has latched.
({SunState state, SunEval eval, List<String> fell}) sunSettle(
  SunWorld w,
  SunState s0, [
  SunEval? e0,
]) {
  var s = s0;
  var e = e0 ?? sunEvaluate(w, s);
  if (e.nowLatched.any((c) => !s.latched.contains(c))) {
    s = s.copyWith(latched: {...s.latched, ...e.nowLatched});
    e = sunEvaluate(w, s);
  }
  final fell = <String>[];
  for (var round = 0; round < 4; round++) {
    final down = [
      for (final n in kSunBodies)
        if (!sunHolds(w, e, s.pos[n]!.room, s.pos[n]!.x, s.pos[n]!.y)) n,
    ];
    if (down.isEmpty) break;
    fell.addAll(down);
    var pos = {...s.pos};
    for (final n in down) {
      pos[n] = (room: '-', x: -9, y: -9);
    }
    for (final n in down) {
      final room = s.pos[n]!.room;
      final l = sunLanding(w, s.copyWith(pos: pos), room, n);
      pos = {...pos, n: l};
    }
    s = s.copyWith(pos: pos);
    e = sunEvaluate(w, s);
    if (e.nowLatched.any((c) => !s.latched.contains(c))) {
      s = s.copyWith(latched: {...s.latched, ...e.nowLatched});
      e = sunEvaluate(w, s);
    }
  }
  return (state: s, eval: e, fell: fell);
}

/// Where a body lands in [room]: the room's first free arrival square, or
/// the nearest free floor to it.
SunAt sunLanding(SunWorld w, SunState s, String room, String who) {
  final d = w.rooms[room]!;
  for (final a in d.arrivals) {
    if (sunBodyAt(s, room, a.x, a.y, who) == null) {
      return (room: room, x: a.x, y: a.y);
    }
  }
  final a0 = d.arrivals.first;
  final q = [a0];
  final seen = {'${a0.x},${a0.y}'};
  for (var i = 0; i < q.length; i++) {
    final c = q[i];
    final ch = d.at(c.x, c.y);
    if ('.pE*VDS'.contains(ch) && sunBodyAt(s, room, c.x, c.y, who) == null) {
      return (room: room, x: c.x, y: c.y);
    }
    for (var k = 0; k < 4; k++) {
      final n = (x: c.x + kSunDx[k], y: c.y + kSunDy[k]);
      if (!d.inside(n.x, n.y) || kSunSolid.contains(d.at(n.x, n.y))) continue;
      if (seen.add('${n.x},${n.y}')) q.add(n);
    }
  }
  return (room: room, x: a0.x, y: a0.y);
}

/// Where [who] would land stepping [dir] — through a portal if it walks into
/// one — or why it can't.
({SunAt? to, (String, int)? through, String? why}) sunStepTarget(
  SunWorld w,
  SunState s,
  SunEval e,
  String who,
  int dir,
) {
  final p = s.pos[who]!;
  final d = w.rooms[p.room]!;
  final nx = p.x + kSunDx[dir], ny = p.y + kSunDy[dir];
  final c = d.at(nx, ny);
  if (c == 'O') {
    final f = d.faceAt(nx, ny, sunOpp(dir));
    final m = f == null ? null : sunMouthOn(s, p.room, f);
    if (m == null) return (to: null, through: null, why: 'obsidian');
    final q = sunPartner(s, m);
    if (q == null) return (to: null, through: null, why: 'lone mouth');
    final qd = w.rooms[q.room]!;
    final front = qd.faces[q.face].front;
    if (sunBodyAt(s, q.room, front.x, front.y, who) != null) {
      return (to: null, through: null, why: 'blocked exit');
    }
    if (!sunHolds(w, e, q.room, front.x, front.y)) {
      return (to: null, through: null, why: 'exit over void');
    }
    return (to: (room: q.room, x: front.x, y: front.y), through: m, why: null);
  }
  if (!d.inside(nx, ny) || _sunSolidAt(w, d, e.open, nx, ny)) {
    return (to: null, through: null, why: c == '|' ? 'door' : 'wall');
  }
  if (sunBodyAt(s, p.room, nx, ny, who) != null) {
    return (to: null, through: null, why: 'body');
  }
  if (!sunHolds(w, e, p.room, nx, ny)) {
    return (to: null, through: null, why: c == '~' ? 'void' : 'wall');
  }
  return (to: (room: p.room, x: nx, y: ny), through: null, why: null);
}

/// [who] steps [dir] (or is placed at [to], for a door or the game's own
/// walking). Refused if it would leave the mover standing on nothing; anyone
/// else it leaves on nothing falls back.
SunResult sunMove(
  SunWorld w,
  SunState s,
  String who,
  int dir, {
  SunEval? eval,
}) {
  final e = eval ?? sunEvaluate(w, s);
  final t = sunStepTarget(w, s, e, who, dir);
  if (t.why != null) return SunResult.no(t.why!);
  return sunPlace(w, s, who, t.to!, through: t.through);
}

SunResult sunPlace(
  SunWorld w,
  SunState s,
  String who,
  SunAt to, {
  (String, int)? through,
}) {
  var n = s.moved(who, to);
  // Off the burning-glass, the beam goes out.
  if (who == 'light' &&
      n.shine >= 0 &&
      w.rooms[to.room]!.at(to.x, to.y) != '*') {
    n = n.copyWith(shine: -1);
  }
  final after = sunEvaluate(w, n);
  if (!sunHolds(w, after, to.room, to.x, to.y)) {
    return SunResult.no(who == 'light' ? 'own light' : 'would fall');
  }
  final r = sunSettle(w, n, after);
  return SunResult.ok(r.state, r.eval, fell: r.fell, through: through);
}

/// Light shines [dir] (or goes out, [dir] < 0). Only from a burning-glass.
SunResult sunShine(SunWorld w, SunState s, int dir) {
  final p = s.pos['light']!;
  if (dir >= 0 && w.rooms[p.room]!.at(p.x, p.y) != '*') {
    return const SunResult.no('no lens');
  }
  final n = s.copyWith(shine: dir < 0 || s.shine == dir ? -1 : dir);
  final r = sunSettle(w, n);
  return SunResult.ok(r.state, r.eval, fell: r.fell);
}

/// The face a Dark would hit casting [dir]: the first solid thing straight
/// ahead, if it is obsidian. Bodies and shut doors stop the cast.
({int? face, String? why}) sunCastFace(
  SunWorld w,
  SunState s,
  SunEval e,
  String who,
  int dir,
) {
  final p = s.pos[who]!;
  final d = w.rooms[p.room]!;
  var x = p.x, y = p.y;
  for (var i = 0; i < 64; i++) {
    x += kSunDx[dir];
    y += kSunDy[dir];
    if (!d.inside(x, y)) return (face: null, why: 'stone');
    if (sunBodyAt(s, p.room, x, y) != null) return (face: null, why: 'body');
    if (_sunSolidAt(w, d, e.open, x, y)) {
      if (d.at(x, y) != 'O') return (face: null, why: 'stone');
      final f = d.faceAt(x, y, sunOpp(dir));
      return f == null ? (face: null, why: 'stone') : (face: f, why: null);
    }
  }
  return (face: null, why: 'stone');
}

/// [who] casts end [end] (0 = I, 1 = II) [dir]. Casting onto the face the
/// end already holds closes it.
SunResult sunCast(
  SunWorld w,
  SunState s,
  String who,
  int end,
  int dir, {
  SunEval? eval,
}) {
  final e = eval ?? sunEvaluate(w, s);
  final c = sunCastFace(w, s, e, who, dir);
  if (c.why != null) return SunResult.no(c.why!);
  final room = s.pos[who]!.room;
  final m = sunMouthOn(s, room, c.face!);
  final SunState n;
  if (m != null && m.$1 == who && m.$2 == end) {
    n = s.withEnd(who, end, null);
  } else if (m != null) {
    return const SunResult.no('taken');
  } else {
    n = s.withEnd(who, end, (room: room, face: c.face!));
  }
  final r = sunSettle(w, n);
  return SunResult.ok(r.state, r.eval, fell: r.fell);
}

/// A chamber is solved with all three on its goal pads.
bool sunChamberSolved(SunRoomDef d, SunState s) =>
    d.isChamber &&
    kSunBodies.every((n) {
      final p = s.pos[n]!;
      return p.room == d.id && d.at(p.x, p.y) == 'E';
    });

/// Every legal action from [s], labelled as the prototype labels them.
List<(String, SunState)> sunActions(SunWorld w, SunState s) {
  final e = sunEvaluate(w, s);
  final out = <(String, SunState)>[];
  for (final b in kSunBodies) {
    for (var d = 0; d < 4; d++) {
      final r = sunMove(w, s, b, d, eval: e);
      if (r.ok) out.add(('$b ${kSunDirWord[d]}', r.state!));
    }
  }
  final lp = s.pos['light']!;
  if (s.shine >= 0 || w.rooms[lp.room]!.at(lp.x, lp.y) == '*') {
    for (var d = -1; d < 4; d++) {
      if (d == s.shine || (d < 0 && s.shine < 0)) continue;
      final r = sunShine(w, s, d);
      if (r.ok) {
        out.add((d < 0 ? 'light dims' : 'light shines ${kSunDirWord[d]}', r.state!));
      }
    }
  }
  for (final b in kSunBodies) {
    for (final l in w.links) {
      final p = s.pos[b]!;
      if (p.room != l.room || p.x != l.x || p.y != l.y) continue;
      final r = sunTakeLink(w, s, b, l, eval: e);
      if (r.ok) out.add(('$b takes the door to ${l.to}', r.state!));
    }
  }
  for (final o in kSunDarks) {
    for (var d = 0; d < 4; d++) {
      if (sunCastFace(w, s, e, o, d).why != null) continue;
      for (var end = 0; end < 2; end++) {
        final r = sunCast(w, s, o, end, d, eval: e);
        if (r.ok) {
          out.add(('$o casts ${end == 0 ? 'I' : 'II'} ${kSunDirWord[d]}', r.state!));
        }
      }
    }
  }
  return out;
}

/// Replay a plan written the prototype's way ('purple casts I east',
/// 'light south (through purple)', 'light shines east', 'light dims').
/// Returns the end state, or the step that was refused.
({SunState? state, String? failed}) sunReplay(
  SunWorld w,
  SunState s0,
  List<String> plan,
) {
  var s = s0;
  const dirs = {'north': 0, 'east': 1, 'south': 2, 'west': 3};
  for (final step in plan) {
    final words = step.replaceAll(RegExp(r' \(.*$| \[.*$'), '').split(' ');
    final SunResult r;
    if (words[1] == 'takes') {
      final to = words.last;
      final p = s.pos[words[0]]!;
      final l = w.links.firstWhere(
        (l) => l.room == p.room && l.x == p.x && l.y == p.y && l.to == to,
        orElse: () => const SunLink('-', -1, -1, '-', -1, -1),
      );
      r = sunTakeLink(w, s, words[0], l);
    } else if (words[1] == 'casts') {
      r = sunCast(w, s, words[0], words[2] == 'II' ? 1 : 0, dirs[words[3]]!);
    } else if (words[1] == 'shines') {
      r = sunShine(w, s, dirs[words[2]]!);
    } else if (words[1] == 'dims') {
      r = sunShine(w, s, -1);
    } else {
      r = sunMove(w, s, words[0], dirs[words[1]]!);
    }
    if (!r.ok) return (state: null, failed: '$step: ${r.why}');
    s = r.state!;
  }
  return (state: s, failed: null);
}

// ─────────────────────────────────────────────────────────
// THE ROOMS — the prototype's maps, doorways and all
// ─────────────────────────────────────────────────────────

/// I · THE PORCH (the entry). The void splits it; a Dark casts both ends of
/// its portal and everyone walks through to the Hall door.
const SunRoomDef kSunPorch = SunRoomDef(
  id: 'sun_porch',
  map: [
    '#######D###',
    '#...~~~...#',
    'O...~~~...O',
    '#...~~~...#',
    '###########',
  ],
  arrivals: [(x: 2, y: 1), (x: 1, y: 2), (x: 2, y: 3)],
);

/// THE HALL OF THE BLACK SUN — the hub that grows. A void with an island,
/// the south ledge you arrive on, a far ledge in the north-east. Its two
/// stars burn once the Nigredo Star is won, and crossing means routing them
/// through both portals into blood bridges — one at a time, so the second
/// crossing is cast from the island. The vault is the alcove on the west
/// wall that only a bridge can see.
const SunRoomDef kSunHall = SunRoomDef(
  id: 'sun_hall',
  map: [
    '##O##O##D##',
    '#~~~~~~#..#',
    '#~~~~~~#..D',
    '#~~~...~~~O',
    '#~~~.S.~~~#',
    'OV~~~~~~~~#',
    '##........<',
    '>.........O',
    '#DO##D##D##',
  ],
  arrivals: [(x: 5, y: 7), (x: 4, y: 7), (x: 6, y: 7)],
  starGated: {(x: 0, y: 7): 0, (x: 10, y: 6): 0},
);

/// II · THROUGH THE DARK. The burning-glass cannot see the white seal; the
/// beam goes round the corner by portal.
const SunRoomDef kSunChamberII = SunRoomDef(
  id: 'through_the_dark',
  map: [
    '##D##w#######',
    '#.........#E#',
    '#.........#E#',
    '#*........OE#',
    '#.........|E#',
    '#####O#######',
  ],
  arrivals: [(x: 2, y: 1), (x: 3, y: 1), (x: 1, y: 1)],
  latch: true,
  starIndex: 0,
);

/// III · TWO DARKS MAKE BLOOD. The red seal wants the beam through both
/// portals; its road runs straight back through the burning-glass.
const SunRoomDef kSunChamberIII = SunRoomDef(
  id: 'two_darks',
  map: [
    '#O#r#D##',
    '#......#',
    '#*.....O',
    '#......#',
    '#O#O##|#',
    '####EEE#',
    '########',
  ],
  arrivals: [(x: 5, y: 1), (x: 4, y: 1), (x: 6, y: 1)],
  latch: true,
  starIndex: 0,
);

/// IV · WALK INTO THE LIGHT. A fixed star, both portals, and the blood
/// bridge a Dark can only walk towards its source.
const SunRoomDef kSunChamberIV = SunRoomDef(
  id: 'into_the_light',
  map: [
    '##v##########',
    '#...~~~~~EEE#',
    '#...~~~~~...#',
    '#...~~~~~~~~O',
    'O...~~~~~~~~O',
    '#...~~~~~~~~#',
    '#DO##########',
  ],
  arrivals: [(x: 1, y: 5), (x: 3, y: 5), (x: 1, y: 4)],
  starIndex: 1,
);

/// V · HOLD THE LIGHT. The seal is LIVE: whoever holds the burning-glass
/// cannot leave by the door, and leaves by the dark.
const SunRoomDef kSunChamberV = SunRoomDef(
  id: 'hold_the_light',
  map: [
    '#O##r#######',
    '#.......#EE#',
    '#*......O.E#',
    '#.......#..#',
    'D.......|..#',
    '#O##O#######',
  ],
  arrivals: [(x: 1, y: 4), (x: 2, y: 4), (x: 1, y: 3)],
  starIndex: 1,
);

/// THE LANTERN — the rite's upper room, down the island's stair. Two
/// lights: the star in its west wall, and Light's own burning-glass. The
/// door down to the Heart stands open only while the WHITE SEAL by it burns
/// — and only Light, shining from the glass, can light it. So only Light can
/// hold the way down, and the moment it steps off the glass the door shuts:
/// Light can never take the stairs. It comes down last, through the dark.
const SunRoomDef kSunLantern = SunRoomDef(
  id: 'sun_lantern',
  map: [
    '#####D####',
    '#........#',
    '>.......~O',
    '#.*......#',
    'O........#',
    '##w##D####',
  ],
  arrivals: [(x: 5, y: 1), (x: 4, y: 1), (x: 6, y: 1)],
);

/// THE HEART — the rite. No light of its own: the Great Seal wants blood,
/// and the only light is upstairs. Burning, it latches, opens the way down
/// and wakes Noctryos.
const SunRoomDef kSunHeart = SunRoomDef(
  id: 'sun_heart',
  map: [
    '###OD#####',
    '#........#',
    'O........O',
    '#........#',
    '#........#',
    '###r|#####',
    '###...####',
    '####D#####',
  ],
  arrivals: [(x: 4, y: 1), (x: 5, y: 1), (x: 3, y: 1)],
  circuits: [
    SunCircuit(
      triggers: [(x: 3, y: 5)],
      doors: [(x: 4, y: 5)],
      latch: true,
    ),
  ],
);

/// The Great Seal's latch: blood has burned on it (the rite).
const String kSunRiteLatch = 'sun_heart#0';

/// The doors between rooms, as the rules see them.
const List<SunLink> kSunLinks = [
  SunLink('sun_porch', 7, 0, 'sun_hall', 5, 7),
  SunLink('sun_hall', 5, 8, 'sun_porch', 7, 1),
  SunLink('sun_hall', 1, 8, 'through_the_dark', 2, 1),
  SunLink('through_the_dark', 2, 0, 'sun_hall', 1, 7),
  SunLink('sun_hall', 8, 8, 'two_darks', 5, 1),
  SunLink('two_darks', 5, 0, 'sun_hall', 8, 7),
  SunLink('sun_hall', 8, 0, 'into_the_light', 1, 5),
  SunLink('into_the_light', 1, 6, 'sun_hall', 8, 1),
  SunLink('sun_hall', 10, 2, 'hold_the_light', 1, 4),
  SunLink('hold_the_light', 0, 4, 'sun_hall', 9, 2),
  SunLink('sun_hall', 5, 4, 'sun_lantern', 5, 1),
  SunLink('sun_lantern', 5, 0, 'sun_hall', 4, 4),
  // Down to the Heart: held by the white seal Light lights.
  SunLink('sun_lantern', 5, 5, 'sun_heart', 4, 1, heldBy: (x: 2, y: 5)),
  SunLink('sun_heart', 4, 0, 'sun_lantern', 5, 4),
];

/// Every grid room, by the id [SunBay.grid] names.
const Map<String, SunRoomDef> kSunRooms = {
  'sun_porch': kSunPorch,
  'sun_hall': kSunHall,
  'through_the_dark': kSunChamberII,
  'two_darks': kSunChamberIII,
  'into_the_light': kSunChamberIV,
  'hold_the_light': kSunChamberV,
  'sun_lantern': kSunLantern,
  'sun_heart': kSunHeart,
};

/// The chambers each star needs solved.
const Map<int, List<String>> kSunStarChambers = {
  0: ['through_the_dark', 'two_darks'],
  1: ['into_the_light', 'hold_the_light'],
};

/// The Great Seal in the Heart.
const SunCell kSunGreatSeal = (x: 3, y: 5);

/// The vault cache: the Hall's alcove.
const SunCell kSunVault = (x: 1, y: 5);

// ─────────────────────────────────────────────────────────
// PER-ROOM CONTENT
// ─────────────────────────────────────────────────────────

/// What the Black Sun puts in one room: which grid it is (null for the
/// arena, which is the engine's fight). Carried on `DungeonRoom.sun`.
class SunBay {
  final String? grid;
  const SunBay.grid(String this.grid);
  const SunBay.arena() : grid = null;

  SunRoomDef? get def => grid == null ? null : kSunRooms[grid];

  /// The star a chamber's solving counts towards (the pairs bank together).
  int? get starIndex => def?.starIndex;
}

// ─────────────────────────────────────────────────────────
// THE LAYOUT
// ─────────────────────────────────────────────────────────
//
// A room's bounds are exactly its grid (64px squares). A 'D' square on a
// room's edge is the doorway: its outer 24px is the door rect, and you
// arrive through it on the square just inside. The island's stair is a door
// in the floor. (Numbers, because the layout is const: see the grids.)

/// Nythralor — the Black Sun.
const DungeonLayout darkLayout = DungeonLayout(
  element: 'Dark',
  entranceRoomId: 'sun_porch',
  entranceSpawn: Offset(160, 160),
  title: 'THE BLACK SUN',
  descentTitle: 'Nythralor Vault',
  stars: [
    DungeonStarSpec(
      name: 'Nigredo Star',
      earnAnnouncement:
          'The Nigredo Star is yours. Two stars wake in the Hall',
    ),
    DungeonStarSpec(
      name: 'Albedo Star',
      earnAnnouncement:
          'The Albedo Star is yours. The stair on the island is open',
    ),
    DungeonStarSpec(name: 'Rubedo Star'),
  ],
  finaleDoor: DungeonDoorRef('sun_hall', 'sun_lantern'),
  riteAnnouncement:
      'Nigredo and Albedo are won. The stair on the island is open',
  riteWakeLine: 'Blood burns on the Great Seal. Noctryos wakes below',
  finaleSealedHint:
      'The stair stays shut until you have the Nigredo and Albedo stars',
  guardianSealedHint:
      'Noctryos won\'t wake until blood burns on the Great Seal',
  mercyShrineRoomId: 'sun_hall',
  riddle: [
    'Send me Dark, to open a black sun wherever it looks;',
    'Dark again, for light must pass through both suns to bleed;',
    'and Light, for I keep no light of my own.',
  ],
  primer: [
    'Each Dark carries one portal. Light shines through them.',
    'Through one Dark it stays light. Through both, it bleeds.',
  ],
  rooms: {
    // ── I · THE PORCH (entrance) ── 11×5 ──────────────────
    'sun_porch': DungeonRoom(
      id: 'sun_porch',
      bounds: Rect.fromLTWH(0, 0, 704, 320),
      doors: [
        // (7,0) north → the Hall's south ledge, above its (5,8).
        DungeonDoor(
          rect: Rect.fromLTWH(448, 0, 64, 24),
          targetRoomId: 'sun_hall',
          targetSpawn: Offset(352, 480),
        ),
      ],
      sun: SunBay.grid('sun_porch'),
    ),

    // ── THE HALL OF THE BLACK SUN (hub) ── 11×9 ───────────
    'sun_hall': DungeonRoom(
      id: 'sun_hall',
      bounds: Rect.fromLTWH(0, 0, 704, 576),
      doors: [
        // (5,8) south → the porch.
        DungeonDoor(
          rect: Rect.fromLTWH(320, 552, 64, 24),
          targetRoomId: 'sun_porch',
          targetSpawn: Offset(480, 96),
        ),
        // (1,8) south → II.
        DungeonDoor(
          rect: Rect.fromLTWH(64, 552, 64, 24),
          targetRoomId: 'through_the_dark',
          targetSpawn: Offset(160, 96),
        ),
        // (8,8) south → III.
        DungeonDoor(
          rect: Rect.fromLTWH(512, 552, 64, 24),
          targetRoomId: 'two_darks',
          targetSpawn: Offset(352, 96),
        ),
        // (8,0) north, off the far ledge → IV.
        DungeonDoor(
          rect: Rect.fromLTWH(512, 0, 64, 24),
          targetRoomId: 'into_the_light',
          targetSpawn: Offset(96, 352),
        ),
        // (10,2) east, off the far ledge → V.
        DungeonDoor(
          rect: Rect.fromLTWH(680, 128, 24, 64),
          targetRoomId: 'hold_the_light',
          targetSpawn: Offset(96, 288),
        ),
        // The island's stair (5,4), down to the Lantern: a door in the floor.
        DungeonDoor(
          rect: Rect.fromLTWH(332, 268, 40, 40),
          targetRoomId: 'sun_lantern',
          targetSpawn: Offset(352, 96),
          chromeless: true,
        ),
      ],
      vaultCache: Offset(96, 352),
      sun: SunBay.grid('sun_hall'),
    ),

    // ── II · THROUGH THE DARK ── 13×6 ─────────────────────
    'through_the_dark': DungeonRoom(
      id: 'through_the_dark',
      bounds: Rect.fromLTWH(0, 0, 832, 384),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(128, 0, 64, 24),
          targetRoomId: 'sun_hall',
          targetSpawn: Offset(96, 480),
        ),
      ],
      teach: 'Light shines from the burning-glass',
      sun: SunBay.grid('through_the_dark'),
    ),

    // ── III · TWO DARKS MAKE BLOOD ── 8×7 ─────────────────
    'two_darks': DungeonRoom(
      id: 'two_darks',
      bounds: Rect.fromLTWH(0, 0, 512, 448),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(320, 0, 64, 24),
          targetRoomId: 'sun_hall',
          targetSpawn: Offset(544, 480),
        ),
      ],
      sun: SunBay.grid('two_darks'),
    ),

    // ── IV · WALK INTO THE LIGHT ── 13×7 ──────────────────
    'into_the_light': DungeonRoom(
      id: 'into_the_light',
      bounds: Rect.fromLTWH(0, 0, 832, 448),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(64, 424, 64, 24),
          targetRoomId: 'sun_hall',
          targetSpawn: Offset(544, 96),
        ),
      ],
      sun: SunBay.grid('into_the_light'),
    ),

    // ── V · HOLD THE LIGHT ── 12×6 ────────────────────────
    'hold_the_light': DungeonRoom(
      id: 'hold_the_light',
      bounds: Rect.fromLTWH(0, 0, 768, 384),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(0, 256, 24, 64),
          targetRoomId: 'sun_hall',
          targetSpawn: Offset(608, 160),
        ),
      ],
      sun: SunBay.grid('hold_the_light'),
    ),

    // ── THE LANTERN (the rite, above) ── 10×6 ─────────────
    'sun_lantern': DungeonRoom(
      id: 'sun_lantern',
      bounds: Rect.fromLTWH(0, 0, 640, 384),
      doors: [
        // (5,0) north → up the stair to the island.
        DungeonDoor(
          rect: Rect.fromLTWH(320, 0, 64, 24),
          targetRoomId: 'sun_hall',
          targetSpawn: Offset(288, 288),
        ),
        // (5,5) south → down to the Heart, while the white seal burns.
        DungeonDoor(
          rect: Rect.fromLTWH(320, 360, 64, 24),
          targetRoomId: 'sun_heart',
          targetSpawn: Offset(288, 96),
        ),
      ],
      sun: SunBay.grid('sun_lantern'),
    ),

    // ── THE HEART (the rite, below) ── 10×8 ───────────────
    'sun_heart': DungeonRoom(
      id: 'sun_heart',
      bounds: Rect.fromLTWH(0, 0, 640, 512),
      doors: [
        // (4,0) north → back up to the Lantern.
        DungeonDoor(
          rect: Rect.fromLTWH(256, 0, 64, 24),
          targetRoomId: 'sun_lantern',
          targetSpawn: Offset(352, 288),
        ),
        // (4,7) south → down to Noctryos.
        DungeonDoor(
          rect: Rect.fromLTWH(256, 488, 64, 24),
          targetRoomId: 'noctryos_totality',
          targetSpawn: Offset(450, 120),
        ),
      ],
      sun: SunBay.grid('sun_heart'),
    ),

    // ── NOCTRYOS (Star 3) — the engine's fight; the enemies come out of
    // black holes (the author's call: the boss is not a puzzle).
    'noctryos_totality': DungeonRoom(
      id: 'noctryos_totality',
      bounds: Rect.fromLTWH(0, 0, 900, 640),
      doors: [
        DungeonDoor(
          rect: Rect.fromLTWH(395, 0, 110, 24),
          targetRoomId: 'sun_heart',
          targetSpawn: Offset(288, 416),
        ),
      ],
      guardian: GuardianNode(
        position: Offset(450, 330),
        starIndex: 2,
        encounter: GuardianEncounterRequirement(
          element: 'Dark',
          mysticId: 'Noctryos',
        ),
      ),
      sun: SunBay.arena(),
    ),
  },
);

/// Black holes in the arena floor, where Noctryos' enemies come out.
const List<Offset> kSunArenaHoles = [
  Offset(170, 170),
  Offset(730, 170),
  Offset(170, 500),
  Offset(730, 500),
];
