// lib/games/planet_dungeon/planet_dungeon_blood_heart.dart
//
// HEMAVORN — THE HEART, the fifth rite (the author's design, 2026-10-06).
// The pure rules; test/planet_dungeon_blood_heart_test.dart proves the room
// against them and checks the recipe copy against the game's own table.
//
// Once all four captives are freed, the seal in the Circle opens on the
// Heart. Blood goes in, comes apart and is bound at the top of the room; the
// four it freed pour in and stand on the stage. Fire, Water, Earth and Air
// can make everything between them, so the room is the game's recipe table,
// played out — all the way up to Blood.
//
// THE ONE RULE (the author, 2026-10-06, after the first build: "why would we
// know lightning would break crystal? that's not in any of my recipes" —
// nothing here is anything but a recipe):
//   · Two standing together on an ALTAR fuse into what the recipe table
//     makes (main result only — a right answer always works). A pair with no
//     recipe doesn't fuse.
//   · What they make RISES up the altar's column. If it has a recipe with
//     the first element hanging there, the two fuse up there and what THEY
//     make comes down to the altar. If not, it simply comes back down.
//   · The SPLIT STAGE takes anything apart into the two it was made of — so
//     splitting what fused up there brings the hanging element down too.
//   · LIGHT + DARK make BLOOD, and Blood made here frees the Blood that was
//     taken.
//
// Nothing is timed and nothing is chance. Grids are strings, y down.
//
// THE THEATRE (the author: "stages on the bottom with the open space up top
// where a theatre of elements can occur"). The four stand on a stage along
// the bottom; every altar faces up into an open space where elements hang,
// and Blood is bound at the top.
//
//   #  wall   .  stage   S  the split stage   v  the open space
//   B  Blood, bound (in the open space)
//   f w e a  where Fire, Water, Earth and Air start
//   *  an element hanging in the open space (which one: [HeartRoom.holds])

import 'package:alchemons/games/planet_dungeon/planet_dungeon_blood_rites.dart';

const List<String> kHeartBase = ['Fire', 'Water', 'Earth', 'Air'];

/// assets/data/alchemons_element_recipes.json, each pair's main result. The
/// test reads the file and holds this copy to it.
const Map<String, String> kHeartRecipes = {
  'Fire+Water': 'Steam',
  'Earth+Fire': 'Lava',
  'Earth+Water': 'Mud',
  'Air+Water': 'Ice',
  'Air+Earth': 'Dust',
  'Air+Fire': 'Lightning',
  'Fire+Ice': 'Water',
  'Crystal+Spirit': 'Light',
  'Poison+Spirit': 'Dark',
  'Dark+Light': 'Blood',
  'Lava+Mud': 'Poison',
  'Crystal+Lightning': 'Spirit',
  'Dark+Plant': 'Poison',
  'Fire+Plant': 'Dust',
  'Earth+Lightning': 'Crystal',
  'Spirit+Water': 'Ice',
  'Air+Spirit': 'Lightning',
  'Earth+Spirit': 'Crystal',
  'Fire+Spirit': 'Steam',
  'Air+Lava': 'Fire',
  'Lightning+Plant': 'Fire',
  'Earth+Light': 'Plant',
  'Light+Spirit': 'Air',
  'Dust+Water': 'Earth',
  'Crystal+Lava': 'Earth',
  'Light+Poison': 'Fire',
  'Air+Ice': 'Water',
  'Dust+Steam': 'Water',
  'Dust+Mud': 'Earth',
  'Ice+Light': 'Air',
  'Ice+Lava': 'Steam',
  'Fire+Mud': 'Lava',
  'Ice+Water': 'Steam',
  'Earth+Poison': 'Lava',
  'Plant+Water': 'Mud',
  'Air+Crystal': 'Ice',
  'Air+Mud': 'Dust',
  'Ice+Poison': 'Crystal',
  'Light+Mud': 'Plant',
  'Mud+Plant': 'Poison',
  'Dark+Water': 'Spirit',
};

/// What [a] and [b] make together, or null.
String? heartRecipe(String a, String b) =>
    kHeartRecipes[([a, b]..sort()).join('+')];

const Set<String> kHeartWalk = {'.', 'S'};

/// What rises through without stopping (the open space).
const Set<String> kHeartOpen = {'v'};

/// An element hanging in the open space.
const String kHeartHanging = '*';

const Map<String, String> _kStart = {
  'f': 'Fire',
  'w': 'Water',
  'e': 'Earth',
  'a': 'Air',
};

String _k(int x, int y) => '$x,$y';

class HeartAltar {
  /// The two stones; the power leaves [front] in direction [dir] (0 north,
  /// 1 east, 2 south, 3 west).
  final RiteCell back, front;
  final int dir;
  const HeartAltar(this.back, this.front, this.dir);
}

class HeartRoom {
  final List<List<String>> cells;
  final int w, h;

  /// Where the four start (in base order), and where Blood is bound.
  final List<(String, RiteCell)> starts;
  final RiteCell blood;
  final List<HeartAltar> altars;

  /// The element hanging at each '*', 'x,y' → element.
  final Map<String, String> holds;

  HeartRoom._(
    this.cells,
    this.starts,
    this.blood,
    this.altars,
    this.holds,
  ) : h = cells.length,
      w = cells.first.length;

  factory HeartRoom(
    List<String> map, {
    required List<(RiteCell, RiteCell)> altars,
    required Map<String, String> holds,
  }) {
    final g = [for (final r in map) r.split('')];
    final starts = <(String, RiteCell)>[];
    RiteCell? blood;
    for (var y = 0; y < g.length; y++) {
      for (var x = 0; x < g[y].length; x++) {
        final el = _kStart[g[y][x]];
        if (el != null) {
          starts.add((el, (x: x, y: y)));
          g[y][x] = '.';
        }
        if (g[y][x] == 'B') blood = (x: x, y: y);
      }
    }
    starts.sort((p, q) => kHeartBase.indexOf(p.$1) - kHeartBase.indexOf(q.$1));
    return HeartRoom._(
      g,
      starts,
      blood!,
      [
        for (final (b, f) in altars)
          HeartAltar(
            b,
            f,
            List.generate(4, (d) => d).firstWhere(
              (d) => kRiteDx[d] == f.x - b.x && kRiteDy[d] == f.y - b.y,
            ),
          ),
      ],
      Map.unmodifiable(holds),
    );
  }

  bool _isStone(int x, int y) => altars.any(
    (a) => (a.back.x == x && a.back.y == y) || (a.front.x == x && a.front.y == y),
  );

  /// The split stages.
  List<RiteCell> get splits => [
    for (var y = 0; y < h; y++)
      for (var x = 0; x < w; x++)
        if (cells[y][x] == 'S') (x: x, y: y),
  ];
}

/// One creature in the Heart: its element and, if it was made, the two it
/// was made of. [id] is stable for the creature's life (the game maps it to
/// a body); a fused creature is a new id.
class HeartUnit {
  final String id;
  final String el;
  final List<HeartUnit>? parts;
  RiteCell at;

  HeartUnit(this.id, this.el, this.at, {this.parts});

  HeartUnit moved(RiteCell to) => HeartUnit(id, el, to, parts: parts);

  /// Its make-up, for the proof's state keys.
  String get sig =>
      parts == null ? el : '$el(${parts![0].sig},${parts![1].sig})';
}

class HeartState {
  final List<List<String>> cells;
  final Map<String, String> holds;
  final List<HeartUnit> units;
  int nextId;

  HeartState(this.cells, this.holds, this.units, this.nextId);

  HeartState copy() => HeartState(
    [for (final r in cells) List<String>.of(r)],
    Map<String, String>.of(holds),
    List<HeartUnit>.of(units),
    nextId,
  );

  /// Is there Blood among them (the rite is done)?
  bool get blood => units.any((u) => u.el == 'Blood');
}

HeartState heartStart(HeartRoom r) => HeartState(
  [for (final row in r.cells) List<String>.of(row)],
  Map<String, String>.of(r.holds),
  [for (final (el, at) in r.starts) HeartUnit(el, el, at)],
  0,
);

bool heartWalkable(HeartRoom r, List<List<String>> cells, int x, int y) =>
    x >= 0 && y >= 0 && x < r.w && y < r.h && kHeartWalk.contains(cells[y][x]);

/// What rises from altar [a] meets: the squares it crosses, then the first
/// element hanging in its column (null when there is none), and what the two
/// make together (null when they make nothing — then it just comes back).
class HeartRun {
  final List<RiteCell> path;

  /// The square of the first element hanging in the column, and which.
  final RiteCell? hit;
  final String? hanging;

  /// What the risen element and the hanging one make, if anything.
  final String? fused;
  const HeartRun(this.path, this.hit, this.hanging, this.fused);
  bool get fuses => fused != null;

  static const HeartRun none = HeartRun([], null, null, null);
}

HeartRun _heartRise(
  HeartRoom r,
  List<List<String>> cells,
  Map<String, String> holds,
  HeartAltar a,
  String el,
) {
  final d = a.dir, run = <RiteCell>[];
  var x = a.front.x + kRiteDx[d], y = a.front.y + kRiteDy[d];
  while (x >= 0 && y >= 0 && x < r.w && y < r.h) {
    final ch = cells[y][x];
    if (ch == kHeartHanging) {
      final h = holds[_k(x, y)];
      return HeartRun(run, (x: x, y: y), h, h == null ? null : heartRecipe(el, h));
    }
    if (!kHeartWalk.contains(ch) && !kHeartOpen.contains(ch)) break;
    run.add((x: x, y: y));
    x += kRiteDx[d];
    y += kRiteDy[d];
  }
  return HeartRun(run, null, null, null);
}

class HeartFusion {
  final HeartState state;

  /// What the two on the altar made (it rose).
  final HeartUnit made;
  final HeartRun run;

  /// What came down: the fusion of [made] and the hanging element when they
  /// make something, else [made] itself.
  final HeartUnit landed;

  /// Blood was made (on the altar, or up there): the rite is done.
  bool get blood => landed.el == 'Blood' || made.el == 'Blood';
  const HeartFusion(this.state, this.made, this.run, this.landed);
}

/// Fuse [back] and [front] (standing on altar [ai]'s two stones). Null when
/// the pair has no recipe.
HeartFusion? heartFuse(
  HeartRoom r,
  HeartState s,
  int ai,
  HeartUnit back,
  HeartUnit front,
) {
  final el = heartRecipe(back.el, front.el);
  if (el == null) return null;
  final a = r.altars[ai];
  final n = s.copy();
  final made = HeartUnit('m${n.nextId++}', el, a.front, parts: [back, front]);
  n.units.removeWhere((u) => u.id == back.id || u.id == front.id);
  if (el == 'Blood') {
    n.units.add(made);
    return HeartFusion(n, made, HeartRun.none, made);
  }
  final run = _heartRise(r, n.cells, n.holds, a, el);
  if (!run.fuses) {
    n.units.add(made);
    return HeartFusion(n, made, run, made);
  }
  // It meets the hanging element and the two fuse up there; what they make
  // comes down to the altar. The hanging one is gone from the open space —
  // it is inside what came down, and the split stage can give it back.
  final hit = run.hit!;
  n.cells[hit.y][hit.x] = 'v';
  n.holds.remove(_k(hit.x, hit.y));
  final up = HeartUnit('h${hit.x},${hit.y}', run.hanging!, a.front);
  final landed = HeartUnit('m${n.nextId++}', run.fused!, a.front, parts: [made, up]);
  n.units.add(landed);
  return HeartFusion(n, made, run, landed);
}

/// Take [u] apart on the split stage at [at]: its two parts stand there and
/// on the nearest open square that is no altar's stone and nobody stands on
/// (else the first open square beside it). Null when it isn't made of
/// anything.
(HeartState, HeartUnit, HeartUnit)? heartSplit(
  HeartRoom r,
  HeartState s,
  HeartUnit u,
  RiteCell at,
) {
  final parts = u.parts;
  if (parts == null) return null;
  final n = s.copy();
  final busy = {for (final o in n.units) if (o.id != u.id) o.at};
  RiteCell? other;
  final seen = {at};
  final queue = [at];
  for (var i = 0; i < queue.length && other == null; i++) {
    for (var d = 0; d < 4; d++) {
      final c = (x: queue[i].x + kRiteDx[d], y: queue[i].y + kRiteDy[d]);
      if (!heartWalkable(r, n.cells, c.x, c.y) || !seen.add(c)) continue;
      if (!busy.contains(c) && !r._isStone(c.x, c.y)) {
        other = c;
        break;
      }
      queue.add(c);
    }
  }
  if (other == null) {
    other = at;
    for (var d = 0; d < 4; d++) {
      final x = at.x + kRiteDx[d], y = at.y + kRiteDy[d];
      if (heartWalkable(r, n.cells, x, y)) {
        other = (x: x, y: y);
        break;
      }
    }
  }
  final p = parts[0].moved(at), q = parts[1].moved(other ?? at);
  n.units
    ..removeWhere((x) => x.id == u.id)
    ..addAll([p, q]);
  return (n, p, q);
}

// ── THE PROOF ──────────────────────────────────────────────
// Walking is free, so a creature is only ever WHERE it can get to: its
// region. A state is what is still in the way plus each creature's make-up
// and region. A move is a fusion on an altar (both stones reachable by the
// two) or a split on a stage. Blood made is the goal.

List<List<int>> _heartRegions(HeartRoom r, List<List<String>> cells) {
  final id = [for (var y = 0; y < r.h; y++) List.filled(r.w, -1)];
  var n = 0;
  for (var y = 0; y < r.h; y++) {
    for (var x = 0; x < r.w; x++) {
      if (id[y][x] >= 0 || !heartWalkable(r, cells, x, y)) continue;
      final q = <RiteCell>[(x: x, y: y)];
      id[y][x] = n;
      while (q.isNotEmpty) {
        final c = q.removeLast();
        for (var d = 0; d < 4; d++) {
          final nx = c.x + kRiteDx[d], ny = c.y + kRiteDy[d];
          if (!heartWalkable(r, cells, nx, ny) || id[ny][nx] >= 0) continue;
          id[ny][nx] = n;
          q.add((x: nx, y: ny));
        }
      }
      n++;
    }
  }
  return id;
}

class HeartProof {
  final bool solvable;
  final int states, fusions, splits;
  final List<String> plan;
  final Set<String> made;
  const HeartProof(
    this.solvable,
    this.states,
    this.fusions,
    this.splits,
    this.plan,
    this.made,
  );
}

/// Breadth-first by moves. [ban]: elements that may not be made.
HeartProof heartSolve(HeartRoom r, {Set<String> ban = const {}, int max = 2000000}) {
  final s0 = heartStart(r);
  final splitAt = r.splits;
  String keyOf(HeartState s, List<List<int>> reg) {
    final cs = [for (final u in s.units) '${u.sig}@${reg[u.at.y][u.at.x]}']..sort();
    return '${s.cells.map((row) => row.join()).join()}|${cs.join(';')}';
  }

  final seen = <String, (String, String)?>{};
  final q = <(HeartState, String)>[];
  final k0 = keyOf(s0, _heartRegions(r, s0.cells));
  seen[k0] = null;
  q.add((s0, k0));
  final made = <String>{};
  String? goal;
  for (var i = 0; i < q.length && seen.length < max; i++) {
    final (s, k) = q[i];
    if (s.blood) {
      goal = k;
      break;
    }
    final reg = _heartRegions(r, s.cells);
    int rOf(HeartUnit u) => reg[u.at.y][u.at.x];
    final nexts = <(HeartState, String)>[];
    for (var ai = 0; ai < r.altars.length; ai++) {
      final a = r.altars[ai];
      final rb = reg[a.back.y][a.back.x], rf = reg[a.front.y][a.front.x];
      if (rb < 0 || rf < 0) continue;
      for (var x = 0; x < s.units.length; x++) {
        for (var y = 0; y < s.units.length; y++) {
          if (x == y) continue;
          if (rOf(s.units[x]) != rb || rOf(s.units[y]) != rf) continue;
          if (x > y && rb == rf) continue;
          final el = heartRecipe(s.units[x].el, s.units[y].el);
          if (el == null || ban.contains(el)) continue;
          final f = heartFuse(
            r,
            s,
            ai,
            s.units[x].moved(a.back),
            s.units[y].moved(a.front),
          )!;
          made.add(el);
          made.add(f.landed.el);
          nexts.add((
            f.state,
            '${s.units[x].el}+${s.units[y].el}→$el on altar ${ai + 1}'
                '${f.run.fuses ? ', meets ${f.run.hanging}→${f.landed.el}' : ''}',
          ));
        }
      }
    }
    for (final at in splitAt) {
      final rs = reg[at.y][at.x];
      for (final u in s.units) {
        if (u.parts == null || rOf(u) != rs) continue;
        nexts.add((heartSplit(r, s, u, at)!.$1, 'split ${u.el}'));
      }
    }
    for (final (ns, how) in nexts) {
      final kk = keyOf(ns, _heartRegions(r, ns.cells));
      if (seen.containsKey(kk)) continue;
      seen[kk] = (k, how);
      q.add((ns, kk));
    }
  }
  if (goal == null) {
    return HeartProof(false, seen.length, 0, 0, const [], made);
  }
  final plan = <String>[];
  for (var k = goal; seen[k] != null; k = seen[k]!.$1) {
    plan.insert(0, seen[k]!.$2);
  }
  final splits = plan.where((p) => p.startsWith('split')).length;
  return HeartProof(true, seen.length, plan.length - splits, splits, plan, made);
}

// ═════════════════════════════════════════════════════════
// THE ROOM (found by search and proved: one way, seven moves)
// ═════════════════════════════════════════════════════════
//
// Altar 1 has nothing over it; altar 2 a Spirit; altar 3 a Spirit with Lava
// above it; altar 4 Earth. The way (the proof finds no other):
//   1. Air + Fire on altar 4: Lightning rises into the Earth → Crystal.
//   2. Split the Crystal: Lightning, and the Earth from up there (you need
//      two Earths and have one).
//   3. Earth + Lightning on altar 3: Crystal rises into the Spirit → Light,
//      and the Lava behind it is uncovered (on altar 2 it would not be).
//   4. Earth + Water on altar 3: Mud rises into the Lava → Poison.
//   5. Split the Poison: Lava and Mud (Poison only rises if it is MADE).
//   6. Lava + Mud on altar 2: Poison rises into the Spirit → Dark.
//   7. Dark + Light → Blood.

const List<String> kHeartMap = [
  'vvvvvvvBvvvvvv',
  'vvvvvvvvvvvvvv',
  'vvvvvvvv*vvvvv',
  'vvvvvvvvvvvvvv',
  'vvvvv*vv*vv*vv',
  'vvvvvvvvvvvvvv',
  '#............#',
  '#S.a..f..w..e#',
  '##############',
];

/// Each altar: its back stone on the stage's back row, its front stone in
/// front of it; it faces up into the open space.
const List<(RiteCell, RiteCell)> kHeartAltars = [
  ((x: 2, y: 7), (x: 2, y: 6)),
  ((x: 5, y: 7), (x: 5, y: 6)),
  ((x: 8, y: 7), (x: 8, y: 6)),
  ((x: 11, y: 7), (x: 11, y: 6)),
];

const Map<String, String> kHeartHolds = {
  '5,4': 'Spirit',
  '8,4': 'Spirit',
  '8,2': 'Lava',
  '11,4': 'Earth',
};

HeartRoom heartRoom() =>
    HeartRoom(kHeartMap, altars: kHeartAltars, holds: kHeartHolds);
