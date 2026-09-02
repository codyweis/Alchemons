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

  /// How much THIS fire has eaten. The pool answers to a single chain, not to
  /// a lifetime total, so this resets on every ignition.
  int burntThisFire = 0;

  /// LIGHT. Only standing vine on dry ground takes a flame, and only when
  /// nothing else is already burning — one fire at a time is what makes the
  /// route a route.
  bool light(int i) {
    if (head != null) return false;
    if (_cells[i] != BurnCell.vine) return false;
    _cells[i] = BurnCell.ash;
    burnt++;
    burntThisFire = 1;
    head = i;
    smoulder = 0;
    return true;
  }

  /// Is the fire alight (burning or smouldering)?
  bool get alight => head != null;

  /// Has the pool filled?
  ///
  /// ONE CHAIN. This counted the run's lifetime total, so the pool could be
  /// filled by relighting over and over — which made the garth a scratchpad
  /// rather than a route, and meant the player never had to commit to a plan
  /// before striking. A fire that dies short is now a failed attempt, and the
  /// spent ground it left behind is the cost of it.
  bool get poolFull => burntThisFire >= coverageGoal && coverageGoal > 0;

  /// Fraction of the pool, for the render — of the CURRENT fire.
  double get poolFraction =>
      coverageGoal <= 0 ? 0 : (burntThisFire / coverageGoal).clamp(0.0, 1.0);

  /// ONE BEAT of the flame.
  BurnStep step() {
    final h = head;
    if (h == null) return BurnStep.idle;
    final next = downwind(h);
    if (next != null && _cells[next] == BurnCell.vine) {
      _cells[next] = BurnCell.ash;
      burnt++;
      burntThisFire++;
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

    bool open(int j) => walls[j] == BurnCell.soil || walls[j] == BurnCell.vine;

    List<int> nbrs(int i) {
      final c0 = colOf(i), r0 = rowOf(i);
      final out = <int>[];
      for (final w in BurnWind.values) {
        final (dc, dr) = w.delta;
        final c = c0 + dc, r = r0 + dr;
        if (!inBounds(c, r)) continue;
        final j = index(c, r);
        if (open(j)) out.add(j);
      }
      return out;
    }

    /// How much ground is still reachable from [i]. A chain can never take
    /// more than this, so a branch that strands part of the field is dead the
    /// moment it is made — which is the prune that turns an intractable walk
    /// into an instant answer on a field this size.
    int reachable(int i) {
      final seen = <int>{i};
      final stack = <int>[i];
      var n = 0;
      while (stack.isNotEmpty) {
        final u = stack.removeLast();
        n++;
        for (final v in nbrs(u)) {
          if (seen.add(v)) stack.add(v);
        }
      }
      return n;
    }

    void walk(int i, int len) {
      if (found || visits > 2000000) return;
      visits++;
      if (len >= target) {
        found = true;
        return;
      }
      // Dead end: what is left in front cannot make up the shortfall.
      if (len + reachable(i) < target) return;
      // WARNSDORFF: step into the most constrained square first. Squares with
      // one way out have to be taken when they are still takeable, and trying
      // them last is what makes the naive walk explode.
      final options = nbrs(i)
        ..sort((a, b) => nbrs(a).length.compareTo(nbrs(b).length));
      for (final j in options) {
        if (found) return;
        if (!open(j)) continue;
        final k = walls[j];
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
