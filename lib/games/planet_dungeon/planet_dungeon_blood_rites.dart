// lib/games/planet_dungeon/planet_dungeon_blood_rites.dart
//
// HEMAVORN — THE BLOOD RITES. The pure rules of Blood's four captive rooms
// and the Circle, with no engine in them. Every rule here is a line-for-line
// port of the prototype the author played and every room was proved in
// (docs/prototypes/blood_rites: earth-, water-, fire-, air- and hub-engine.js
// are these rules in JavaScript; solve.js is the proofs; proofs.txt the last
// run). test/planet_dungeon_blood_rites_test.dart replays the proved plans
// against THESE rules, so the two can never drift apart unnoticed.
//
// One Blood Alchemon goes down alone. Four rooms each hold a captive of a
// classical element; each room's two ingredients meet at the captive (the
// game's own recipes), and its blood runs home to the Circle.
//
//   · EARTH — the tendril floor. Dust + Water → Earth.
//   · WATER — the turning room. Fire + Ice → Water.
//   · FIRE  — the twin. Air + Lava → Fire.
//   · AIR   — the weightless room. Ice + Light → Air.
//   · THE CIRCLE — four doors, four cups, two turning rings; the Lost Maxim
//     is the quintessence (all four streams in the middle at once).
//
// Nothing here is timed and nothing is chance. Grids are strings, y down.

const List<int> kRiteDx = [0, 1, 0, -1]; // north east south west
const List<int> kRiteDy = [-1, 0, 1, 0];

typedef RiteCell = ({int x, int y});

List<List<String>> _parse(List<String> map) =>
    [for (final r in map) r.split('')];

String _k(int x, int y) => '$x,$y';

// ═════════════════════════════════════════════════════════
// EARTH — THE TENDRIL FLOOR
// ═════════════════════════════════════════════════════════
//
// Blood tendrils grow out of the walls in pairs. Blood leads each one across
// the floor to its partner. Two tendrils never share a square, so they never
// cross. The floor is laid in TURNING PLATES: a plate turns a quarter round
// its axle, and everything standing on it turns with it. A plate will not
// turn while a tendril lies on it. The last two tendrils are not a pair: one
// runs with Dust and one with Water, and both must be led to the captive.
//
//   #  wall   .  floor   X  stone standing on a plate   o  a plate's axle
//   a..k  blood roots (pairs)   d  the Dust root   w  the Water root
//   C  the captive (needs d and w)

class TendrilPlate {
  final int cx, cy;
  const TendrilPlate(this.cx, this.cy);
}

class TendrilJob {
  final String id;
  final RiteCell a, b;
  const TendrilJob(this.id, this.a, this.b);
}

class TendrilFloor {
  final List<List<String>> base;
  final int w, h;
  final List<TendrilPlate> plates;

  TendrilFloor._(this.base, this.plates)
    : h = base.length,
      w = base.first.length;

  factory TendrilFloor(List<String> map) {
    final g = _parse(map);
    final plates = <TendrilPlate>[];
    for (var y = 0; y < g.length; y++) {
      for (var x = 0; x < g[y].length; x++) {
        if (g[y][x] == 'o') plates.add(TendrilPlate(x, y));
      }
    }
    return TendrilFloor._(g, plates);
  }

  /// The squares as they stand with each plate turned `turns[i]` quarters
  /// clockwise.
  List<List<String>> grid(List<int> turns) {
    final g = [for (final r in base) List<String>.of(r)];
    for (var i = 0; i < plates.length; i++) {
      final p = plates[i];
      final t = ((i < turns.length ? turns[i] : 0) % 4 + 4) % 4;
      if (t == 0) continue;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          var x = dx, y = dy;
          for (var k = 0; k < t; k++) {
            final nx = -y, ny = x;
            x = nx;
            y = ny;
          }
          g[p.cy + y][p.cx + x] = base[p.cy + dy][p.cx + dx];
        }
      }
    }
    return g;
  }

  int plateOf(int x, int y) {
    for (var i = 0; i < plates.length; i++) {
      final p = plates[i];
      if ((x - p.cx).abs() <= 1 && (y - p.cy).abs() <= 1) return i;
    }
    return -1;
  }

  static bool isRoot(String ch) => RegExp(r'^[a-kdw]$').hasMatch(ch);
  static bool isTerminal(String ch) => RegExp(r'^[a-kdwC]$').hasMatch(ch);

  /// Every pair joined; Dust and Water each led to the captive.
  List<TendrilJob> jobs(List<List<String>> g) {
    final at = <String, List<RiteCell>>{};
    for (var y = 0; y < g.length; y++) {
      for (var x = 0; x < g[y].length; x++) {
        if (isTerminal(g[y][x])) (at[g[y][x]] ??= []).add((x: x, y: y));
      }
    }
    final keys = at.keys.toList()..sort();
    final out = <TendrilJob>[];
    for (final k in keys) {
      if (k == 'C' || k == 'd' || k == 'w') continue;
      if (at[k]!.length == 2) out.add(TendrilJob(k, at[k]![0], at[k]![1]));
    }
    if (at['C'] != null) {
      if (at['d'] != null) out.add(TendrilJob('d', at['d']![0], at['C']![0]));
      if (at['w'] != null) out.add(TendrilJob('w', at['w']![0], at['C']![0]));
    }
    return out;
  }
}

class TendrilState {
  final List<int> turns;

  /// Each tendril, from its root, through floor squares.
  final Map<String, List<RiteCell>> lines;

  const TendrilState(this.turns, this.lines);

  factory TendrilState.start(TendrilFloor f) =>
      TendrilState(List.filled(f.plates.length, 0), const {});

  TendrilState withLine(String id, List<RiteCell> pts) {
    final l = Map<String, List<RiteCell>>.of(lines);
    if (pts.length <= 1) {
      l.remove(id);
    } else {
      l[id] = List.unmodifiable(pts);
    }
    return TendrilState(turns, l);
  }

  TendrilState cleared(String id) => withLine(id, const []);
}

/// What a tendril move did: a new state, or why it was refused.
class RiteResult<S> {
  final S? state;
  final String? why;
  const RiteResult.ok(S this.state) : why = null;
  const RiteResult.no(String this.why) : state = null;
  bool get ok => state != null;
}

bool tendrilLineOnPlate(TendrilFloor f, TendrilState s, int i) =>
    s.lines.values.any((pts) => pts.any((c) => f.plateOf(c.x, c.y) == i));

RiteResult<TendrilState> tendrilTurn(TendrilFloor f, TendrilState s, int i) {
  if (tendrilLineOnPlate(f, s, i)) {
    return const RiteResult.no('A tendril lies across that plate.');
  }
  final turns = List<int>.of(s.turns);
  turns[i] = (turns[i] + 1) % 4;
  return RiteResult.ok(TendrilState(turns, s.lines));
}

/// A pair can be led from EITHER root (Dust and Water only from their own
/// roots — the captive is not a root). Joined when the far end is reached.
bool tendrilJoined(TendrilJob j, List<RiteCell>? pts) =>
    pts != null &&
    pts.length >= 2 &&
    ((pts.first == j.a && pts.last == j.b) ||
        (pts.first == j.b && pts.last == j.a));

/// The end a tendril is being led towards.
RiteCell tendrilGoal(TendrilJob j, List<RiteCell> pts) =>
    pts.first == j.b ? j.a : j.b;

/// Lead (or pull back) tendril [id] one square, to (x, y). The first point of
/// a line is the root it was taken from ([from] — either root of a pair,
/// defaulting to the first; Dust and Water only from their own root).
RiteResult<TendrilState> tendrilExtend(
  TendrilFloor f,
  TendrilState s,
  String id,
  int x,
  int y, {
  RiteCell? from,
}) {
  final g = f.grid(s.turns);
  final jobs = f.jobs(g);
  final j = jobs.where((j) => j.id == id).firstOrNull;
  if (j == null) return const RiteResult.no('No such tendril.');
  final start = from ?? j.a;
  if (s.lines[id] == null &&
      start != j.a &&
      (start != j.b || id == 'd' || id == 'w')) {
    return const RiteResult.no('No such tendril.');
  }
  final pts = List<RiteCell>.of(s.lines[id] ?? [start]);
  final tip = pts.last;
  if ((tip.x - x).abs() + (tip.y - y).abs() != 1) {
    return const RiteResult.no('One square at a time.');
  }
  final c = (x: x, y: y);
  if (pts.length > 1 && pts[pts.length - 2] == c) {
    pts.removeLast();
    return RiteResult.ok(s.withLine(id, pts));
  }
  if (tendrilJoined(j, s.lines[id])) {
    return const RiteResult.no('That tendril is already joined.');
  }
  if (y < 0 || y >= f.h || x < 0 || x >= f.w) {
    return const RiteResult.no('blocked');
  }
  final goal = c == tendrilGoal(j, pts);
  if (!goal && g[y][x] != '.') return const RiteResult.no('blocked');
  if (pts.contains(c)) {
    return const RiteResult.no('A tendril cannot cross itself.');
  }
  if (!goal) {
    for (final e in s.lines.entries) {
      if (e.key != id && e.value.contains(c)) {
        return const RiteResult.no('Tendrils never cross.');
      }
    }
  }
  pts.add(c);
  return RiteResult.ok(s.withLine(id, pts));
}

bool tendrilSolved(TendrilFloor f, TendrilState s) {
  final g = f.grid(s.turns);
  return f.jobs(g).every((j) => tendrilJoined(j, s.lines[j.id]));
}

/// For one set of plate turns: vertex-disjoint paths for every job, or null.
/// (Backtracking with a reachability prune; a path never touches itself,
/// since any solution shortcuts to one that doesn't.)
Map<String, List<RiteCell>>? tendrilRoute(
  TendrilFloor f,
  List<int> turns, {
  int budget = 2000000,
}) {
  final g = f.grid(turns);
  final jobs = f.jobs(g);
  final used = List.generate(f.h, (_) => List.filled(f.w, false));
  bool open(int x, int y) =>
      x >= 0 && y >= 0 && x < f.w && y < f.h && g[y][x] == '.' && !used[y][x];
  final paths = <List<RiteCell>>[for (final _ in jobs) []];
  var left = budget;

  bool reach(RiteCell a, RiteCell b) {
    final seen = List.generate(f.h, (_) => List.filled(f.w, false));
    final q = [a];
    seen[a.y][a.x] = true;
    while (q.isNotEmpty) {
      final c = q.removeLast();
      for (var d = 0; d < 4; d++) {
        final nx = c.x + kRiteDx[d], ny = c.y + kRiteDy[d];
        if (nx == b.x && ny == b.y) return true;
        if (open(nx, ny) && !seen[ny][nx]) {
          seen[ny][nx] = true;
          q.add((x: nx, y: ny));
        }
      }
    }
    return false;
  }

  bool viable(int from, RiteCell? tip) {
    for (var j = from; j < jobs.length; j++) {
      if (!reach(j == from && tip != null ? tip : jobs[j].a, jobs[j].b)) {
        return false;
      }
    }
    return true;
  }

  bool touchesSelf(List<RiteCell> path, int nx, int ny) {
    for (var i = 0; i < path.length - 1; i++) {
      if ((path[i].x - nx).abs() + (path[i].y - ny).abs() == 1) return true;
    }
    return false;
  }

  bool go(int j, List<RiteCell> path) {
    if (--left < 0) throw StateError('budget');
    final job = jobs[j];
    final t = path.last;
    for (var d = 0; d < 4; d++) {
      final nx = t.x + kRiteDx[d], ny = t.y + kRiteDy[d];
      if (nx == job.b.x && ny == job.b.y) {
        paths[j] = [...path, job.b];
        if (j + 1 == jobs.length) return true;
        if (viable(j + 1, null) && go(j + 1, [jobs[j + 1].a])) return true;
        continue;
      }
      if (!open(nx, ny) || touchesSelf(path, nx, ny)) continue;
      used[ny][nx] = true;
      path.add((x: nx, y: ny));
      if (viable(j, (x: nx, y: ny)) && go(j, path)) return true;
      path.removeLast();
      used[ny][nx] = false;
    }
    return false;
  }

  if (jobs.isEmpty || !viable(0, null)) return null;
  if (!go(0, [jobs[0].a])) return null;
  return {for (var i = 0; i < jobs.length; i++) jobs[i].id: paths[i]};
}

// ═════════════════════════════════════════════════════════
// WATER — THE TURNING ROOM
// ═════════════════════════════════════════════════════════
//
// The room has a DOWNHILL. FLIP turns the room over. Everything loose slides
// downhill a square at a time until something stops it: ice straight down
// its line; water too, but water that lands runs along the floor to the
// nearest place it can drop (west wins a tie). Blood stops things too, and
// when Blood steps aside what rested on it falls on. Ice resting against a
// lit brazier melts (Fire + Ice → Water); water touching fire puts it out.
// Water runs through grates; ice and Blood do not. Ice that drops into a pit
// fills it as floor; water makes it a deep POOL — Blood can dive in: the
// VAULT. Fill every basin square with water and the rite is done.
//
//   #  wall  .  floor  B  Blood  I  ice  ~  water  F  lit brazier
//   f  spent brazier  =  grate  _  pit  C  basin (dry)  c  basin (full)
//   p  a flooded pit (a pool; the way to the vault)

class FlipRoom {
  final List<List<String>> fixed;
  final int w, h;
  final RiteCell blood0;
  final Map<String, String> loose0;

  FlipRoom._(this.fixed, this.blood0, this.loose0)
    : h = fixed.length,
      w = fixed.first.length;

  factory FlipRoom(List<String> map) {
    final g = _parse(map);
    RiteCell? b;
    final loose = <String, String>{};
    for (var y = 0; y < g.length; y++) {
      for (var x = 0; x < g[y].length; x++) {
        final ch = g[y][x];
        if (ch == 'B') {
          b = (x: x, y: y);
          g[y][x] = '.';
        } else if (ch == 'I' || ch == '~') {
          loose[_k(x, y)] = ch;
          g[y][x] = '.';
        }
      }
    }
    return FlipRoom._(g, b!, loose);
  }
}

class FlipState {
  /// 2 = downhill is south, 0 = north.
  final int down;
  final RiteCell b;
  final List<List<String>> cells;
  final Map<String, String> loose;

  FlipState(this.down, this.b, this.cells, this.loose);

  FlipState copy() => FlipState(
    down,
    b,
    [for (final r in cells) List<String>.of(r)],
    Map<String, String>.of(loose),
  );

  String get key {
    final ks = loose.entries.map((e) => '${e.key}=${e.value}').toList()
      ..sort();
    return '$down|${b.x},${b.y}|${cells.map((r) => r.join()).join()}|'
        '${ks.join(';')}';
  }
}

/// One picture of the loose things and the squares that change, for the
/// game to play back a pass at a time.
class FlipFrame {
  final List<List<String>> cells;
  final Map<String, String> loose;

  /// What moved in the pass that ended here: new square → old square.
  final Map<String, String> moves;

  /// What a pit or the basin took in that pass: old square → the square it
  /// went into.
  final Map<String, String> gone;

  FlipFrame(
    FlipState s, {
    this.moves = const {},
    this.gone = const {},
  }) : cells = [for (final r in s.cells) List<String>.of(r)],
       loose = Map<String, String>.of(s.loose);
}

/// What happened during a settle (melts, dousings, pits, basins).
class FlipEvent {
  final String t; // melt, douse, pit, basin
  final int x, y;
  final String? kind;
  const FlipEvent(this.t, this.x, this.y, [this.kind]);
}

class FlipStep {
  final FlipState? state;
  final List<FlipEvent> log;
  final List<FlipFrame> frames;
  const FlipStep(this.state, this.log, this.frames);
  bool get ok => state != null;
}

FlipState flipStart(FlipRoom r) {
  final s = FlipState(
    2,
    r.blood0,
    [for (final row in r.fixed) List<String>.of(row)],
    Map<String, String>.of(r.loose0),
  );
  _flipSettle(r, s, [], null);
  return s;
}

bool _flipCanEnter(FlipState s, String k, int x, int y) {
  if (y < 0 || y >= s.cells.length || x < 0 || x >= s.cells[y].length) {
    return false;
  }
  final ch = s.cells[y][x];
  if (s.b.x == x && s.b.y == y) return false;
  if (s.loose.containsKey(_k(x, y))) return false;
  if (ch == '.' || ch == '_' || ch == 'c' || ch == 'p') return true;
  if (ch == '=' || ch == 'C') return k == '~';
  return false;
}

void _flipSettle(
  FlipRoom r,
  FlipState s,
  List<FlipEvent> log,
  List<FlipFrame>? frames,
) {
  for (var guard = 0; guard < 200; guard++) {
    final moved = _flipSlideAll(r, s, log, frames);
    final changed = _flipReact(s, log);
    if (changed && frames != null) frames.add(FlipFrame(s));
    if (!moved && !changed) return;
  }
}

/// Which way (−1 west, +1 east, 0 stay) a landed water unit runs.
int _flipRunTo(FlipRoom r, FlipState s, int x, int y, int dy) {
  var best = 0, bestD = 1 << 30;
  for (final side in const [-1, 1]) {
    for (var d = 1; d < r.w; d++) {
      final cx = x + side * d;
      if (!_flipCanEnter(s, '~', cx, y)) break;
      final ch = s.cells[y][cx];
      final sink = ch == '_' || ch == 'C';
      final ny = y + dy;
      final drop = sink || (ny >= 0 && ny < r.h && _flipCanEnter(s, '~', cx, ny));
      if (drop) {
        if (d < bestD) {
          bestD = d;
          best = side;
        }
        break;
      }
    }
  }
  return best;
}

bool _flipSlideAll(
  FlipRoom r,
  FlipState s,
  List<FlipEvent> log,
  List<FlipFrame>? frames,
) {
  final dy = kRiteDy[s.down];
  var any = false;
  for (var pass = 0; pass < 100; pass++) {
    var moved = false;
    final moves = <String, String>{}, gone = <String, String>{};
    // Downhill-most first, so a column falls together. STABLE, like the
    // prototype's sort: water in one row keeps the order it was laid in.
    final keys = [
      for (final k in s.loose.keys) [for (final v in k.split(',')) int.parse(v)],
    ];
    // (An insertion sort: stable, and a room has a handful of loose things.)
    for (var i = 1; i < keys.length; i++) {
      final k = keys[i];
      var j = i - 1;
      while (j >= 0 && (k[1] - keys[j][1]) * dy > 0) {
        keys[j + 1] = keys[j];
        j--;
      }
      keys[j + 1] = k;
    }
    for (final c in keys) {
      final x = c[0], y = c[1];
      final k = s.loose[_k(x, y)];
      if (k == null) continue;
      var nx = x, ny = y + dy;
      if (ny < 0 || ny >= r.h || !_flipCanEnter(s, k, x, ny)) {
        if (k != '~') continue;
        final side = _flipRunTo(r, s, x, y, dy);
        if (side == 0) continue;
        nx = x + side;
        ny = y;
      }
      s.loose.remove(_k(x, y));
      final ch = s.cells[ny][nx];
      // Where it came from: an item already moved this pass carries its
      // first square (one pass moves each thing once, but be safe).
      final origin = moves.remove(_k(x, y)) ?? _k(x, y);
      if (ch == '_') {
        s.cells[ny][nx] = k == '~' ? 'p' : '.';
        log.add(FlipEvent('pit', nx, ny, k));
        gone[origin] = _k(nx, ny);
      } else if (ch == 'C') {
        s.cells[ny][nx] = 'c';
        log.add(FlipEvent('basin', nx, ny));
        gone[origin] = _k(nx, ny);
      } else {
        s.loose[_k(nx, ny)] = k;
        moves[_k(nx, ny)] = origin;
      }
      moved = any = true;
    }
    if (!moved) break;
    frames?.add(FlipFrame(s, moves: moves, gone: gone));
  }
  return any;
}

bool _flipTouches(FlipState s, int x, int y, String ch) {
  for (var d = 0; d < 4; d++) {
    final ny = y + kRiteDy[d], nx = x + kRiteDx[d];
    if (ny >= 0 && ny < s.cells.length && nx >= 0 && nx < s.cells[ny].length) {
      if (s.cells[ny][nx] == ch) return true;
    }
  }
  return false;
}

bool _flipReact(FlipState s, List<FlipEvent> log) {
  var changed = false;
  for (final e in s.loose.entries.toList()) {
    if (e.value != 'I') continue;
    final p = e.key.split(',').map(int.parse).toList();
    if (_flipTouches(s, p[0], p[1], 'F')) {
      s.loose[e.key] = '~';
      log.add(FlipEvent('melt', p[0], p[1]));
      changed = true;
    }
  }
  for (final e in s.loose.entries.toList()) {
    if (e.value != '~') continue;
    final p = e.key.split(',').map(int.parse).toList();
    for (var d = 0; d < 4; d++) {
      final nx = p[0] + kRiteDx[d], ny = p[1] + kRiteDy[d];
      if (ny >= 0 && ny < s.cells.length && s.cells[ny][nx] == 'F') {
        s.cells[ny][nx] = 'f';
        log.add(FlipEvent('douse', nx, ny));
        changed = true;
      }
    }
  }
  return changed;
}

bool flipWalkable(FlipState s, int x, int y) {
  if (y < 0 || y >= s.cells.length || x < 0 || x >= s.cells[y].length) {
    return false;
  }
  final ch = s.cells[y][x];
  return (ch == '.' || ch == 'c') && !s.loose.containsKey(_k(x, y));
}

/// Blood steps one square; afterwards everything settles (something resting
/// on Blood may now fall).
FlipStep flipStep(FlipRoom r, FlipState s, int d, {bool frames = false}) {
  final x = s.b.x + kRiteDx[d], y = s.b.y + kRiteDy[d];
  if (!flipWalkable(s, x, y)) return const FlipStep(null, [], []);
  final n = s.copy();
  final next = FlipState(n.down, (x: x, y: y), n.cells, n.loose);
  final log = <FlipEvent>[];
  final fr = frames ? <FlipFrame>[] : null;
  _flipSettle(r, next, log, fr);
  return FlipStep(next, log, fr ?? const []);
}

/// FLIP: downhill becomes uphill, and the room settles.
FlipStep flipTurn(FlipRoom r, FlipState s, {bool frames = false}) {
  final n = s.copy();
  final next = FlipState(s.down == 2 ? 0 : 2, n.b, n.cells, n.loose);
  final log = <FlipEvent>[];
  final fr = frames ? <FlipFrame>[] : null;
  _flipSettle(r, next, log, fr);
  return FlipStep(next, log, fr ?? const []);
}

bool flipSolved(FlipState s) => !s.cells.any((r) => r.contains('C'));

/// The direction of a flooded pit Blood could dive into, or −1.
int flipDiveFrom(FlipState s) {
  for (var d = 0; d < 4; d++) {
    final x = s.b.x + kRiteDx[d], y = s.b.y + kRiteDy[d];
    if (y >= 0 &&
        y < s.cells.length &&
        x >= 0 &&
        x < s.cells[y].length &&
        s.cells[y][x] == 'p' &&
        !s.loose.containsKey(_k(x, y))) {
      return d;
    }
  }
  return -1;
}

/// Every state that can still be finished (for "can't be finished from
/// here — reset it"), plus the whole graph's size.
({Set<String> live, int states}) flipLiveStates(FlipRoom r, {int max = 500000}) {
  final s0 = flipStart(r);
  final idx = <String, int>{s0.key: 0};
  final states = [s0];
  final edges = <List<int>>[[]];
  final goals = <int>[];
  for (var i = 0; i < states.length; i++) {
    if (states.length > max) break;
    final s = states[i];
    if (flipSolved(s)) {
      goals.add(i);
      continue;
    }
    for (var m = -1; m < 4; m++) {
      final st = m < 0 ? flipTurn(r, s) : flipStep(r, s, m);
      if (!st.ok) continue;
      final k = st.state!.key;
      var j = idx[k];
      if (j == null) {
        j = states.length;
        idx[k] = j;
        states.add(st.state!);
        edges.add([]);
      }
      edges[i].add(j);
    }
  }
  final rev = [for (final _ in states) <int>[]];
  for (var i = 0; i < edges.length; i++) {
    for (final j in edges[i]) {
      rev[j].add(i);
    }
  }
  final live = List.filled(states.length, false);
  final q = [...goals];
  for (final g in goals) {
    live[g] = true;
  }
  while (q.isNotEmpty) {
    final j = q.removeLast();
    for (final i in rev[j]) {
      if (!live[i]) {
        live[i] = true;
        q.add(i);
      }
    }
  }
  return (
    live: {for (var i = 0; i < states.length; i++) if (live[i]) states[i].key},
    states: states.length,
  );
}

// ═════════════════════════════════════════════════════════
// FIRE — THE TWIN
// ═════════════════════════════════════════════════════════
//
// A pool of blood runs down the middle of the room. Blood stands on one side
// and its twin on the other, as its mirror image: every step Blood takes the
// twin takes the mirrored one (north is north, east is west). Each is
// stopped by its own side's walls, so walking into a wall moves only the
// other one. A plate holds the gate of its number open (on either side) while
// somebody stands on it; a gate won't close on anybody in it. Once the
// captive is freed every gate stands open ([twinStep]'s `freed`): the room
// is done, and the way out is behind gate b. A pit sends
// both back to the pool. Blood on the bellows and the twin on the lava sluice
// after the same step: air meets lava at the captive's hearth.
//
//   #  wall  .  floor  |  the pool  @  Blood's start (the twin mirrored)
//   B  bellows  L  lava sluice  1 2 3  plates  a b c  their gates
//   O  pit  H  the captive's hearth (on the pool)

const List<int> kTwinMirror = [0, 3, 2, 1];

class TwinRoom {
  final List<List<String>> cells;
  final int w, h;
  final RiteCell b0, t0;

  TwinRoom._(this.cells, this.b0, this.t0)
    : h = cells.length,
      w = cells.first.length;

  factory TwinRoom(List<String> map) {
    final g = _parse(map);
    RiteCell? b;
    for (var y = 0; y < g.length; y++) {
      for (var x = 0; x < g[y].length; x++) {
        if (g[y][x] == '@') {
          b = (x: x, y: y);
          g[y][x] = '.';
        }
      }
    }
    final w = g.first.length;
    return TwinRoom._(g, b!, (x: w - 1 - b.x, y: b.y));
  }
}

class TwinState {
  final RiteCell b, t;
  const TwinState(this.b, this.t);
  String get key => '${b.x},${b.y}|${t.x},${t.y}';
}

class TwinStepResult {
  final TwinState? state;
  final bool bMoved, tMoved;

  /// 'b' or 't' when somebody fell into a pit (both rose at the pool).
  final String? pit;
  final TwinState? fellFrom;
  const TwinStepResult(
    this.state, {
    this.bMoved = false,
    this.tMoved = false,
    this.pit,
    this.fellFrom,
  });
  bool get ok => state != null;
}

const Map<String, String> _gatePlate = {'a': '1', 'b': '2', 'c': '3'};

TwinState twinStart(TwinRoom r) => TwinState(r.b0, r.t0);

/// The plates held down: by whoever stands on them, or all of them once
/// the room is done ([freed]).
Set<String> twinPressed(TwinRoom r, TwinState s, {bool freed = false}) => {
  if (freed) ...const ['1', '2', '3'],
  for (final c in [s.b, s.t])
    if (RegExp(r'^[123]$').hasMatch(r.cells[c.y][c.x])) r.cells[c.y][c.x],
};

bool twinOpen(TwinRoom r, int x, int y, Set<String> on) {
  if (y < 0 || y >= r.h || x < 0 || x >= r.w) return false;
  final ch = r.cells[y][x];
  if (ch == '#' || ch == '|' || ch == 'H') return false;
  final plate = _gatePlate[ch];
  if (plate != null) return on.contains(plate);
  return true;
}

TwinStepResult twinStep(TwinRoom r, TwinState s, int d, {bool freed = false}) {
  final on = twinPressed(r, s, freed: freed);
  final nb = (x: s.b.x + kRiteDx[d], y: s.b.y + kRiteDy[d]);
  final md = kTwinMirror[d];
  final nt = (x: s.t.x + kRiteDx[md], y: s.t.y + kRiteDy[md]);
  final bm = twinOpen(r, nb.x, nb.y, on);
  final tm = twinOpen(r, nt.x, nt.y, on);
  if (!bm && !tm) return const TwinStepResult(null);
  final n = TwinState(bm ? nb : s.b, tm ? nt : s.t);
  final bPit = r.cells[n.b.y][n.b.x] == 'O';
  final tPit = r.cells[n.t.y][n.t.x] == 'O';
  if (bPit || tPit) {
    return TwinStepResult(
      twinStart(r),
      bMoved: bm,
      tMoved: tm,
      pit: bPit ? 'b' : 't',
      fellFrom: n,
    );
  }
  return TwinStepResult(n, bMoved: bm, tMoved: tm);
}

bool twinSolved(TwinRoom r, TwinState s) =>
    r.cells[s.b.y][s.b.x] == 'B' && r.cells[s.t.y][s.t.x] == 'L';

/// Shortest plan (breadth-first), as directions; null if none.
List<int>? twinSolve(TwinRoom r) {
  final s0 = twinStart(r);
  final prev = <String, (String, int)?>{s0.key: null};
  final byKey = <String, TwinState>{s0.key: s0};
  var q = [s0];
  String? goal;
  while (q.isNotEmpty && goal == null) {
    final n = <TwinState>[];
    for (final s in q) {
      for (var d = 0; d < 4; d++) {
        final st = twinStep(r, s, d);
        if (!st.ok) continue;
        final k = st.state!.key;
        if (prev.containsKey(k)) continue;
        prev[k] = (s.key, d);
        byKey[k] = st.state!;
        if (twinSolved(r, st.state!)) {
          goal = k;
          break;
        }
        n.add(st.state!);
      }
      if (goal != null) break;
    }
    q = n;
  }
  if (goal == null) return null;
  final plan = <int>[];
  for (var k = goal; prev[k] != null; k = prev[k]!.$1) {
    plan.insert(0, prev[k]!.$2);
  }
  return plan;
}

// ═════════════════════════════════════════════════════════
// AIR — THE WEIGHTLESS ROOM
// ═════════════════════════════════════════════════════════
//
// There is no floor to push against. Blood pushes off in a direction and
// drifts in a straight line until something stops it. Up against a block of
// ice, a push sends the ICE drifting that way instead; Blood stays. Ice that
// drifts into a shaft of sunlight turns to air and is gone (Ice + Light →
// Air): beside the glass bell the air goes in; anywhere else it is lost. The
// ice is both the only thing to stop against and the only fuel.
//
//   #  wall  .  open air  @  Blood  I  ice  *  sunlight  C  the glass bell

class DriftRoom {
  final List<List<String>> cells;
  final int w, h;
  final RiteCell b0;
  final List<String> ice0;
  final int need;

  DriftRoom._(this.cells, this.b0, this.ice0, this.need)
    : h = cells.length,
      w = cells.first.length;

  factory DriftRoom(List<String> map, {int need = 1}) {
    final g = _parse(map);
    RiteCell? b;
    final ice = <String>[];
    for (var y = 0; y < g.length; y++) {
      for (var x = 0; x < g[y].length; x++) {
        if (g[y][x] == '@') {
          b = (x: x, y: y);
          g[y][x] = '.';
        } else if (g[y][x] == 'I') {
          ice.add(_k(x, y));
          g[y][x] = '.';
        }
      }
    }
    ice.sort();
    return DriftRoom._(g, b!, ice, need);
  }

  bool solid(int x, int y) {
    if (y < 0 || y >= h || x < 0 || x >= w) return true;
    final ch = cells[y][x];
    return ch == '#' || ch == 'C';
  }

  bool bellBeside(int x, int y) {
    for (var d = 0; d < 4; d++) {
      final nx = x + kRiteDx[d], ny = y + kRiteDy[d];
      if (ny >= 0 && ny < h && nx >= 0 && nx < w && cells[ny][nx] == 'C') {
        return true;
      }
    }
    return false;
  }
}

class DriftState {
  final RiteCell b;
  final List<String> ice; // sorted 'x,y'
  final int air;
  const DriftState(this.b, this.ice, this.air);
  String get key => '${b.x},${b.y}|${ice.join(';')}|$air';
}

class DriftResult {
  final DriftState? state;
  final String? why;

  /// The squares Blood drifted through (when Blood moved).
  final List<RiteCell> bloodPath;

  /// The squares the shoved ice drifted through (when ice moved).
  final List<RiteCell> icePath;

  /// Where the ice turned to air, and whether the bell took it.
  final RiteCell? meltedAt;
  final bool intoBell;

  const DriftResult(
    this.state, {
    this.why,
    this.bloodPath = const [],
    this.icePath = const [],
    this.meltedAt,
    this.intoBell = false,
  });
  bool get ok => state != null;
}

DriftState driftStart(DriftRoom r) => DriftState(r.b0, r.ice0, 0);

DriftResult driftPush(DriftRoom r, DriftState s, int d) {
  final bx = s.b.x, by = s.b.y;
  final nx = bx + kRiteDx[d], ny = by + kRiteDy[d];
  if (s.ice.contains(_k(nx, ny))) {
    var x = nx, y = ny;
    final path = <RiteCell>[(x: x, y: y)];
    final others = s.ice.where((k) => k != _k(nx, ny)).toList();
    RiteCell? gone;
    while (true) {
      if (r.cells[y][x] == '*' && !(x == nx && y == ny)) {
        gone = (x: x, y: y);
        break;
      }
      final tx = x + kRiteDx[d], ty = y + kRiteDy[d];
      if (r.solid(tx, ty) ||
          others.contains(_k(tx, ty)) ||
          (tx == bx && ty == by)) {
        break;
      }
      x = tx;
      y = ty;
      path.add((x: x, y: y));
    }
    if (path.length == 1 && gone == null) {
      return const DriftResult(null, why: 'The ice is up against something.');
    }
    var ice = others;
    var air = s.air;
    var bell = false;
    if (gone != null) {
      if (r.bellBeside(gone.x, gone.y)) {
        air++;
        bell = true;
      }
    } else {
      ice = [...others, _k(x, y)]..sort();
    }
    return DriftResult(
      DriftState(s.b, ice, air),
      icePath: path,
      meltedAt: gone,
      intoBell: bell,
    );
  }
  var x = bx, y = by;
  final path = <RiteCell>[(x: x, y: y)];
  while (true) {
    final tx = x + kRiteDx[d], ty = y + kRiteDy[d];
    if (r.solid(tx, ty) || s.ice.contains(_k(tx, ty))) break;
    x = tx;
    y = ty;
    path.add((x: x, y: y));
  }
  if (path.length == 1) return const DriftResult(null, why: 'blocked');
  return DriftResult(DriftState((x: x, y: y), s.ice, s.air), bloodPath: path);
}

bool driftSolved(DriftRoom r, DriftState s) => s.air >= r.need;

/// Every state that can still be finished, the fewest pushes, and its plan.
({Set<String> live, int states, List<int> plan}) driftGraph(
  DriftRoom r, {
  int max = 500000,
}) {
  final s0 = driftStart(r);
  final idx = <String, int>{s0.key: 0};
  final states = [s0];
  final edges = <List<(int, int)>>[[]];
  final goals = <int>[];
  for (var i = 0; i < states.length; i++) {
    if (states.length > max) break;
    final s = states[i];
    if (driftSolved(r, s)) {
      goals.add(i);
      continue;
    }
    for (var d = 0; d < 4; d++) {
      final p = driftPush(r, s, d);
      if (!p.ok) continue;
      final k = p.state!.key;
      var j = idx[k];
      if (j == null) {
        j = states.length;
        idx[k] = j;
        states.add(p.state!);
        edges.add([]);
      }
      edges[i].add((j, d));
    }
  }
  final rev = [for (final _ in states) <int>[]];
  for (var i = 0; i < edges.length; i++) {
    for (final (j, _) in edges[i]) {
      rev[j].add(i);
    }
  }
  final live = List.filled(states.length, false);
  final q = [...goals];
  for (final g in goals) {
    live[g] = true;
  }
  while (q.isNotEmpty) {
    final j = q.removeLast();
    for (final i in rev[j]) {
      if (!live[i]) {
        live[i] = true;
        q.add(i);
      }
    }
  }
  // Fewest pushes, breadth-first.
  final prev = List<(int, int)?>.filled(states.length, null);
  final seen = List.filled(states.length, false)..[0] = true;
  final bq = [0];
  int? goal;
  for (var h = 0; h < bq.length; h++) {
    final i = bq[h];
    if (driftSolved(r, states[i])) {
      goal = i;
      break;
    }
    for (final (j, d) in edges[i]) {
      if (!seen[j]) {
        seen[j] = true;
        prev[j] = (i, d);
        bq.add(j);
      }
    }
  }
  final plan = <int>[];
  for (var j = goal; j != null && prev[j] != null; j = prev[j]!.$1) {
    plan.insert(0, prev[j]!.$2);
  }
  return (
    live: {for (var i = 0; i < states.length; i++) if (live[i]) states[i].key},
    states: states.length,
    plan: plan,
  );
}

// ═════════════════════════════════════════════════════════
// THE CIRCLE — four streams, four cups, two rings
// ═════════════════════════════════════════════════════════
//
// A freed captive's blood runs from its door into its cup. Two turning rings
// of eight sectors lie across the streams. A stream reaches the CENTRE only
// where BOTH rings have a groove at its angle; anywhere else it fills its cup.
// Two streams in the middle fuse (the game's own recipes); all four make the
// quintessence — the Lost Maxim. Cups latch: turning the rings never undoes
// progress. (Proved: home sends nothing to the middle; both rings must turn
// for the quintessence; no setting ever puts one or three in.)

const List<String> kRiteElements = ['Air', 'Fire', 'Earth', 'Water'];

/// The sector (45° steps, clockwise from north) of each element's door.
const Map<String, int> kRiteDoorSector = {
  'Air': 0,
  'Fire': 2,
  'Earth': 4,
  'Water': 6,
};

/// Sectors with a groove through the outer ring (at turn 0).
const List<int> kRiteOuterGrooves = [0, 1, 2, 3, 5, 7];

/// Sectors with a groove through the inner ring (at turn 0).
const List<int> kRiteInnerGrooves = [1, 3, 5, 7];

/// What two streams make when they meet in the middle.
const Map<String, String> kRiteFusions = {
  'Fire+Water': 'Steam',
  'Earth+Fire': 'Lava',
  'Earth+Water': 'Mud',
  'Air+Water': 'Ice',
  'Air+Earth': 'Dust',
  'Air+Fire': 'Lightning',
};

bool _riteGroove(List<int> grooves, int sector, int turn) =>
    grooves.contains(((sector - turn) % 8 + 8) % 8);

/// Does [element]'s stream run past its cup into the middle?
bool riteStreamToCentre(String element, int outerTurn, int innerTurn) {
  final s = kRiteDoorSector[element]!;
  return _riteGroove(kRiteOuterGrooves, s, outerTurn) &&
      _riteGroove(kRiteInnerGrooves, s, innerTurn);
}

enum RiteCentreKind { none, one, fusion, churn, quintessence }

class RiteCentre {
  final RiteCentreKind kind;
  final List<String> ins;
  final String? result;
  const RiteCentre(this.kind, this.ins, [this.result]);
}

/// What the middle holds for these freed elements and ring turns.
RiteCentre riteCentre(Set<String> freed, int outerTurn, int innerTurn) {
  final ins = [
    for (final el in kRiteElements)
      if (freed.contains(el) && riteStreamToCentre(el, outerTurn, innerTurn))
        el,
  ];
  if (ins.length == 4) return RiteCentre(RiteCentreKind.quintessence, ins);
  if (ins.length == 2) {
    final k = ([...ins]..sort()).join('+');
    return RiteCentre(RiteCentreKind.fusion, ins, kRiteFusions[k]);
  }
  if (ins.length == 3) return RiteCentre(RiteCentreKind.churn, ins);
  return RiteCentre(
    ins.isEmpty ? RiteCentreKind.none : RiteCentreKind.one,
    ins,
  );
}

// ═════════════════════════════════════════════════════════
// THE ROOMS (the prototype's maps, exactly)
// ═════════════════════════════════════════════════════════

const List<String> kRiteEarthMap = [
  '###########',
  'a.........#',
  '#.......b.#',
  'b.......o.#',
  '#.......aX#',
  'c.....#...#',
  'd...o.....c',
  '#..XC.....w',
  '###########',
];

const List<String> kRiteWaterMap = [
  '#########',
  '#CCC..F##',
  '#..F....#',
  '#.......#',
  '#.......#',
  '#.F.._..#',
  '#I..I.IB#',
  '#########',
];

const List<String> kRiteFireMap = [
  '###########',
  '#@b..|....#',
  '##...|....#',
  '#..1.|L...#',
  '#....|...a#',
  '#....H.2..#',
  '#...B|....#',
  '###########',
];

const List<String> kRiteAirMap = [
  '#########',
  '#.......#',
  '#...I...#',
  '#.I.....#',
  '#.I.....#',
  '#......*#',
  '#....I.C#',
  '#.*.@..*#',
  '#########',
];

/// How much air the Air room's bell needs.
const int kRiteAirNeed = 2;

// ═════════════════════════════════════════════════════════
// THE BOSS — Sanguorath, in stages (the author's design, 2026-10-05)
// ═════════════════════════════════════════════════════════
//
// The four freed captives reform and come down with Blood; the player
// controls all five. At 80%, 60%, 40% and 20% Sanguorath pulls into a shell
// of blood and takes no damage until one ally gives itself. The shell shows
// an element, and its OPPOSITE ally breaks it. A wrong ally is thrown back
// and Sanguorath heals a little (never above the top of the stretch). The
// last 20% is Blood alone.

/// The health fractions at which Sanguorath shells.
const List<double> kRiteShellAt = [0.8, 0.6, 0.4, 0.2];

/// How close to Sanguorath an ally comes before its shell takes it: the right
/// one gives itself, a wrong one is thrown back and mends it.
const double kRiteShellReach = 74;

/// The element whose shell each ally breaks (its opposite).
const Map<String, String> kRiteOpposite = {
  'Fire': 'Water',
  'Water': 'Fire',
  'Earth': 'Air',
  'Air': 'Earth',
};

/// How much a refused ally heals Sanguorath, as a share of its max health.
const double kRiteWrongHeal = 0.04;

/// The shell's element for the next break, chosen among the allies still
/// standing so that its opposite is one of them. [pick] chooses the index
/// (the game rolls it per fight; tests pass a fixed one). A shell never
/// shows an element whose breaker is gone.
String riteShellElement(Set<String> standing, int Function(int n) pick) {
  final options = [
    for (final el in kRiteElements)
      if (standing.contains(kRiteOpposite[el])) el,
  ];
  return options[pick(options.length)];
}
