// lib/games/planet_dungeon/burn_field.dart
//
// THE BURN — Fire Star 2's rules, as pure functions.
//
// The cathedral's garth is plantable soil. Plant lays vine, Fire lights one
// cell, Air swings the vane a quarter — and then the flame walks ITSELF: one
// cell per beat, DOWNWIND, into whatever vine is in front of it. The player
// never moves the fire. They lay fuel ahead of it and turn the wind to bend it.
//
// Everything here is a rule the player already owns:
//   · fire needs FUEL — no vine downwind, no advance;
//   · fire follows the WIND — it only ever walks the quarter the vane shows;
//   · burnt ground is SPENT — it carries nothing and takes no new vine, so the
//     fire's own trail is the wall it can crash into (the snake falls out of
//     what burning is, rather than being imposed on top of it);
//   · water is not fuel — wet ground grows vine happily and never catches,
//     which is the trap that teaches fuel and fire are not the same thing.
//
// Kept as a standalone module (like AshGardenRules before it) so the engine,
// the renderer and the solver all reason about ONE copy of the rules.

/// What occupies a cell of the garth.
enum BurnCell {
  /// Bare, plantable soil.
  soil,

  /// Vine standing on soil: the fuel.
  vine,

  /// Burnt out. Spent for the run — carries no flame and takes no vine.
  ash,

  /// Fallen stone: no vine, no flame, ever. The maze wall.
  stone,

  /// Wet ground: vine grows here and will NEVER catch.
  wet,

  /// Wet ground with vine standing in it — green, and useless as fuel.
  wetVine,
}

/// The quarter the vane shows. The flame walks this way and no other.
enum BurnWind { north, east, south, west }

extension BurnWindStep on BurnWind {
  /// (dCol, dRow) for this quarter.
  (int, int) get delta => switch (this) {
    BurnWind.north => (0, -1),
    BurnWind.east => (1, 0),
    BurnWind.south => (0, 1),
    BurnWind.west => (-1, 0),
  };

  BurnWind get quarterRight => switch (this) {
    BurnWind.north => BurnWind.east,
    BurnWind.east => BurnWind.south,
    BurnWind.south => BurnWind.west,
    BurnWind.west => BurnWind.north,
  };
}

/// What the flame did on a beat — the renderer and the hint channel both read
/// this, so "why did my fire die" is always answerable from one place.
enum BurnStep {
  /// It ate the cell downwind and moved into it.
  advanced,

  /// Nothing to eat downwind: the head is smouldering, one beat of grace to
  /// plant ahead of it or swing the vane.
  smouldered,

  /// The grace ran out. This chain is over.
  died,

  /// There is no live flame (not lit yet, or already out).
  idle,
}

/// One garth: the authored field plus the live burn walking across it.
class BurnField {
  BurnField({
    required this.cols,
    required this.rows,
    required List<BurnCell> cells,
    required this.wind,
    this.coverageGoal = 0,
  }) : _cells = List.of(cells),
       assert(cells.length == cols * rows);

  /// Parse an authored field. `.` soil · `#` stone · `~` wet · `v` vine.
  factory BurnField.parse(
    List<String> art, {
    BurnWind wind = BurnWind.east,
    int coverageGoal = 0,
  }) {
    final cols = art.first.length;
    final cells = <BurnCell>[];
    for (final line in art) {
      for (final ch in line.split('')) {
        cells.add(switch (ch) {
          '#' => BurnCell.stone,
          '~' => BurnCell.wet,
          'v' => BurnCell.vine,
          _ => BurnCell.soil,
        });
      }
    }
    return BurnField(
      cols: cols,
      rows: art.length,
      cells: cells,
      wind: wind,
      coverageGoal: coverageGoal,
    );
  }

  final int cols;
  final int rows;
  final List<BurnCell> _cells;

  /// How many cells must burn before the ember pool stands full.
  final int coverageGoal;

  /// The live quarter. Swinging it mid-burn is how a chain turns a corner.
  BurnWind wind;

  /// Where the flame stands, or null when nothing is alight.
  int? head;

  /// Beats the head has gone unfed. One is grace; two is over.
  int smoulder = 0;

  /// Cells burnt this run — the ember pool reads this.
  int burnt = 0;

  int index(int c, int r) => r * cols + c;
  int colOf(int i) => i % cols;
  int rowOf(int i) => i ~/ cols;
  BurnCell at(int i) => _cells[i];
  BurnCell cell(int c, int r) => _cells[index(c, r)];

  bool inBounds(int c, int r) => c >= 0 && r >= 0 && c < cols && r < rows;

  /// The cell downwind of [i], or null if that is off the field.
  int? downwind(int i) {
    final (dc, dr) = wind.delta;
    final c = colOf(i) + dc, r = rowOf(i) + dr;
    return inBounds(c, r) ? index(c, r) : null;
  }

  /// PLANT. Vine takes on bare soil and on wet ground — and nowhere else, so
  /// ash really is spent and stone really is a wall.
  bool plant(int i) {
    switch (_cells[i]) {
      case BurnCell.soil:
        _cells[i] = BurnCell.vine;
        return true;
      case BurnCell.wet:
        _cells[i] = BurnCell.wetVine;
        return true;
      default:
        return false;
    }
  }

  /// LIGHT. Only standing vine on dry ground takes a flame, and only when
  /// nothing else is already burning — one fire at a time is what makes the
  /// route a route.
  bool light(int i) {
    if (head != null) return false;
    if (_cells[i] != BurnCell.vine) return false;
    _cells[i] = BurnCell.ash;
    burnt++;
    head = i;
    smoulder = 0;
    return true;
  }

  /// Is the fire alight (burning or smouldering)?
  bool get alight => head != null;

  /// Has the pool filled?
  bool get poolFull => burnt >= coverageGoal && coverageGoal > 0;

  /// Fraction of the pool, for the render.
  double get poolFraction =>
      coverageGoal <= 0 ? 0 : (burnt / coverageGoal).clamp(0.0, 1.0);

  /// ONE BEAT of the flame.
  BurnStep step() {
    final h = head;
    if (h == null) return BurnStep.idle;
    final next = downwind(h);
    if (next != null && _cells[next] == BurnCell.vine) {
      _cells[next] = BurnCell.ash;
      burnt++;
      head = next;
      smoulder = 0;
      return BurnStep.advanced;
    }
    // Nothing to eat: one beat of grace to plant ahead or swing the vane.
    smoulder++;
    if (smoulder <= 1) return BurnStep.smouldered;
    head = null;
    return BurnStep.died;
  }

  /// Every cell a flame at [from] could still reach, under ANY sequence of
  /// wind turns and any planting the player could still do. Used to prove a
  /// field is not already lost, and to answer "can this run still fill the
  /// pool" honestly rather than by hope.
  int reachableCoverage(int from) {
    final seen = <int>{from};
    final queue = <int>[from];
    var count = 0;
    while (queue.isNotEmpty) {
      final i = queue.removeLast();
      count++;
      for (final w in BurnWind.values) {
        final (dc, dr) = w.delta;
        final c = colOf(i) + dc, r = rowOf(i) + dr;
        if (!inBounds(c, r)) continue;
        final j = index(c, r);
        if (!seen.add(j)) continue;
        // A flame can pass through anything that can still hold dry vine.
        final k = _cells[j];
        if (k == BurnCell.soil || k == BurnCell.vine) queue.add(j);
      }
    }
    return count;
  }

  /// Can this run still fill the pool from where the flame stands? False means
  /// the fire has sealed itself in (or the field is spent) and the honest
  /// answer is the restart, not another beat of hope.
  bool get canStillFill {
    if (coverageGoal <= 0) return true;
    final h = head;
    if (h == null) return false;
    return burnt + reachableCoverage(h) - 1 >= coverageGoal;
  }

  /// Can a perfect player still burn a chain of [target] cells starting at
  /// [from]? Walks the REAL rules — dry ground only, never re-entering its own
  /// trail — and STOPS THE MOMENT it finds one.
  ///
  /// Deliberately not "what is the longest chain": that is an exhaustive walk
  /// over every self-avoiding path, which is fine on a toy field and hangs
  /// forever on a real one (learned the expensive way). A layout only needs to
  /// know its goal is reachable, which is an existence question, and existence
  /// answers fast because a snaking path turns up early.
  bool canBurnAtLeast(int from, int target) {
    if (target <= 0) return true;
    final walls = List.of(_cells);
    var found = false;
    var visits = 0;

    void walk(int i, int len) {
      if (found || visits > 400000) return;
      visits++;
      if (len >= target) {
        found = true;
        return;
      }
      final c0 = colOf(i), r0 = rowOf(i);
      // Try the straight-on continuations first: a chain that keeps going
      // finds length sooner than one that keeps turning.
      for (final w in BurnWind.values) {
        if (found) return;
        final (dc, dr) = w.delta;
        final c = c0 + dc, r = r0 + dr;
        if (!inBounds(c, r)) continue;
        final j = index(c, r);
        final k = walls[j];
        if (k != BurnCell.soil && k != BurnCell.vine) continue;
        walls[j] = BurnCell.ash; // the trail is the wall
        walk(j, len + 1);
        walls[j] = k;
      }
    }

    final start = walls[from];
    if (start != BurnCell.soil && start != BurnCell.vine) return false;
    walls[from] = BurnCell.ash;
    walk(from, 1);
    walls[from] = start;
    return found;
  }
}
