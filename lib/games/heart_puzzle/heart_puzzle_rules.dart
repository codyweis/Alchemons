// lib/games/heart_puzzle/heart_puzzle_rules.dart
//
// THE ALTARS — the Blood Heart's rite as a puzzle of its own, in levels (the
// author's idea, 2026-10-07). The pure rules and the solver; the levels are
// heart_puzzle_levels.dart, found by tool/heart_puzzle_search.dart and held
// to their proofs by test/heart_puzzle_test.dart.
//
// The Heart's ONE RULE, with the stage taken away (walking was always free
// there, so where a creature stands was never part of the puzzle):
//   · Two seated on an ALTAR fuse into what the recipe table makes (main
//     result only). A pair with no recipe doesn't fuse.
//   · What they make RISES up the altar's column. If it has a recipe with
//     the first element hanging there, the two fuse up there and what THEY
//     make comes down. If not, it simply comes back down.
//   · The SPLIT STAGE takes anything made apart into the two it was made
//     of — so splitting what fused up there brings the hanging one down.
//   · The level's GOAL, once made, stays on the stage: made on an altar it
//     does not rise.
//   · EVERY ORB MUST BE TAKEN (the author, 2026-10-08, after a tutorial
//     left the Ice hanging: "every orb needs to be taken to pass"). A level
//     is done with its goal on the stage and nothing hanging over any altar
//     — so what hangs there is part of the plan, never scenery to avoid.
//
// SPECIES (from level 26; the author, 2026-10-07: "let and let gives pip").
// A creature is an element AND a family. The element follows the recipe
// table; the family follows ONE fixed rule, the same in every level (the
// author picked it over per-level rules, 2026-10-07: learnable, nothing to
// read per level): the likeliest family breeding gives that is neither
// parent ([kTopNewFamily]); two of the same family stay that family. A pair
// breeding has no recipe for (a coin-flip between the parents there) never
// meets in a level — the search refuses one where it could. An element
// freed from up there comes down as a Let. Before species, everyone is a
// Let and stays one.
//
// A move is a fusion or a split. Seating is free. Nothing is timed and
// nothing is chance.

import 'package:alchemons/games/planet_dungeon/planet_dungeon_blood_heart.dart';

/// What [a] and [b] make together, or null — the game's recipe table.
String? altarRecipe(String a, String b) => heartRecipe(a, b);

/// The family every element is at its plainest (and what a freed one is).
const String kBaseFamily = 'Let';

/// The families the puzzle uses (Mystics are never bred from others).
const List<String> kAltarFamilies = [
  'Let',
  'Pip',
  'Mane',
  'Mask',
  'Horn',
  'Kin',
  'Wing',
];

String familyKey(String a, String b) => ([a, b]..sort()).join('+');

/// Every family breeding can give each pair — the family table with the
/// backlinks its loader adds; a pair it has no row for gives one of the
/// parents (the same family sticks). test/heart_puzzle_test.dart holds this
/// to FamilyRecipeConfig.
final Map<String, List<String>> kFamilyOutcomes = {
  for (final a in kAltarFamilies)
    for (final b in kAltarFamilies)
      if (a.compareTo(b) <= 0)
        familyKey(a, b): _kFamilyTable[familyKey(a, b)] ?? {a, b}.toList(),
};

const Map<String, List<String>> _kFamilyTable = {
  'Horn+Kin': ['Pip', 'Kin', 'Horn'],
  'Horn+Let': ['Mane', 'Let', 'Horn'],
  'Horn+Mane': ['Horn', 'Mane', 'Mask', 'Wing'],
  'Horn+Mask': ['Mane', 'Mask', 'Horn'],
  'Horn+Pip': ['Horn', 'Pip', 'Kin', 'Mane'],
  'Kin+Mask': ['Wing', 'Mask', 'Kin', 'Mane'],
  'Kin+Pip': ['Horn', 'Kin', 'Pip'],
  'Kin+Wing': ['Mask', 'Wing', 'Kin'],
  'Let+Let': ['Let', 'Mane', 'Pip'],
  'Let+Mane': ['Horn', 'Pip', 'Mane'],
  'Let+Mask': ['Pip', 'Let', 'Mask'],
  'Let+Pip': ['Mask', 'Let', 'Pip'],
  'Mane+Mask': ['Pip', 'Mask', 'Mane'],
  'Mane+Pip': ['Pip', 'Mane', 'Mask', 'Horn'],
  'Mask+Pip': ['Let', 'Mask', 'Pip'],
  'Mask+Wing': ['Kin', 'Mask', 'Wing', 'Mane'],
};

/// The puzzle's usual family for a pair: the likeliest that is neither
/// parent (ties go to the table's first; Let+Let to Pip, the author's).
const Map<String, String> kTopNewFamily = {
  'Horn+Kin': 'Pip',
  'Horn+Let': 'Mane',
  'Horn+Mane': 'Mask',
  'Horn+Mask': 'Mane',
  'Horn+Pip': 'Kin',
  'Kin+Mask': 'Wing',
  'Kin+Pip': 'Horn',
  'Kin+Wing': 'Mask',
  'Let+Let': 'Pip',
  'Let+Mane': 'Horn',
  'Let+Mask': 'Pip',
  'Let+Pip': 'Mask',
  'Mane+Mask': 'Pip',
  'Mane+Pip': 'Mask',
  'Mask+Pip': 'Let',
  'Mask+Wing': 'Kin',
};

/// What two families make, by the one rule: the likeliest new family, or a
/// family with itself stays itself. Null for a pair breeding has no recipe
/// for (never met in a level).
String? altarFamily(String a, String b) =>
    kTopNewFamily[familyKey(a, b)] ?? (a == b ? a : null);

/// A creature as levels write it: 'Fire' is a Fire Let, 'Fire Pip' a Fire
/// Pip.
(String, String) parseSpecies(String s) {
  final sp = s.indexOf(' ');
  return sp < 0 ? (s, kBaseFamily) : (s.substring(0, sp), s.substring(sp + 1));
}

class AltarLevel {
  const AltarLevel({
    required this.goal,
    this.goalFamily,
    required this.hand,
    required this.columns,
    this.split = false,
    this.species = false,
    required this.par,
  });

  /// What to make (or bring down): an element, and from species on, maybe
  /// a family too.
  final String goal;
  final String? goalFamily;

  /// The creatures on the stage at the start ('Fire', 'Fire Pip').
  final List<String> hand;

  /// What hangs over each altar, nearest the altar first.
  final List<List<String>> columns;

  /// Whether there is a split stage.
  final bool split;

  /// Families count (from level 26). Before, everyone is a Let and stays
  /// one.
  final bool species;

  /// The fewest moves it can be done in (proved).
  final int par;

  int get altars => columns.length;

  /// What families [a] and [b] make here (null: a pair no level lets meet).
  String? familyOf(String a, String b) =>
      species ? altarFamily(a, b) : kBaseFamily;

  bool caught(AltarUnit u) =>
      u.el == goal && (goalFamily == null || u.fam == goalFamily);

  /// Stars for a solution of [moves] moves: par is three, two more is two,
  /// anything else that gets there is one.
  int starsFor(int moves) => moves <= par
      ? 3
      : moves <= par + 2
      ? 2
      : 1;
}

/// One creature on the stage: its element and family and, if it was made,
/// the two it was made of. [id] is stable for its life (the screen maps it
/// to a body).
class AltarUnit {
  AltarUnit(this.id, this.el, this.fam, {this.parts});
  final String id;
  final String el;
  final String fam;
  final List<AltarUnit>? parts;

  String get name => fam == kBaseFamily ? el : '$el $fam';

  /// Its make-up, for the solver's state keys.
  String get sig => parts == null
      ? '$el.$fam'
      : '$el.$fam(${parts![0].sig},${parts![1].sig})';
}

class AltarState {
  AltarState(this.units, this.columns, this.nextId);
  final List<AltarUnit> units;
  final List<List<String>> columns;
  int nextId;

  AltarState copy() => AltarState(
    List<AltarUnit>.of(units),
    [for (final c in columns) List<String>.of(c)],
    nextId,
  );

  String get key {
    final us = [for (final u in units) u.sig]..sort();
    return '${us.join(';')}|${columns.map((c) => c.join(',')).join('/')}';
  }
}

AltarState altarStart(AltarLevel l) => AltarState(
  [
    for (var i = 0; i < l.hand.length; i++)
      () {
        final (el, fam) = parseSpecies(l.hand[i]);
        return AltarUnit('u$i', el, fam);
      }(),
  ],
  [for (final c in l.columns) List<String>.of(c)],
  l.hand.length,
);

/// Done: the goal is on the stage and every orb has been taken.
bool altarDone(AltarLevel l, AltarState s) =>
    s.columns.every((c) => c.isEmpty) && s.units.any(l.caught);

/// The goal is made, but something still hangs there.
bool altarHeld(AltarLevel l, AltarState s) =>
    s.units.any(l.caught) && s.columns.any((c) => c.isNotEmpty);

/// A fusion, played out: what the two made on the altar, what (if anything)
/// it met up the column, and what came down.
class AltarFusion {
  const AltarFusion(this.state, this.made, this.met, this.landed, this.rose);
  final AltarState state;
  final AltarUnit made;

  /// The element it met up the column (it is gone from there), or null when
  /// it rose and came back.
  final String? met;

  /// What came down: [made] itself, or what it made up there.
  final AltarUnit landed;

  /// It rose (it was not the goal, caught on the altar).
  final bool rose;

  bool get fusedUp => met != null;
}

/// Fuse [a] and [b] on altar [ai]. Null when they make nothing.
AltarFusion? altarFuse(
  AltarLevel l,
  AltarState s,
  int ai,
  AltarUnit a,
  AltarUnit b,
) {
  final el = altarRecipe(a.el, b.el);
  final fam = l.familyOf(a.fam, b.fam);
  if (el == null || fam == null) return null;
  final n = s.copy();
  final made = AltarUnit('m${n.nextId++}', el, fam, parts: [a, b]);
  n.units.removeWhere((u) => u.id == a.id || u.id == b.id);
  final col = n.columns[ai];
  final caught = l.caught(made);
  final up = caught || col.isEmpty ? null : col.first;
  final fused = up == null ? null : altarRecipe(el, up);
  if (fused == null) {
    n.units.add(made);
    return AltarFusion(n, made, null, made, !caught);
  }
  col.removeAt(0);
  final landed = AltarUnit(
    'm${n.nextId++}',
    fused,
    fam,
    parts: [made, AltarUnit('h${n.nextId++}', up!, kBaseFamily)],
  );
  n.units.add(landed);
  return AltarFusion(n, made, up, landed, true);
}

/// Take [u] apart on the split stage. Null when it isn't made of anything.
(AltarState, AltarUnit, AltarUnit)? altarSplit(AltarState s, AltarUnit u) {
  final parts = u.parts;
  if (parts == null) return null;
  final n = s.copy();
  n.units
    ..removeWhere((x) => x.id == u.id)
    ..addAll(parts);
  return (n, parts[0], parts[1]);
}

// ── THE PROOF ──────────────────────────────────────────────

/// One move, as the solver names it.
String _fuseName(AltarUnit a, AltarUnit b, int ai, AltarFusion f) {
  final pair = ([a.name, b.name]..sort()).join(' + ');
  // The goal goes straight up to its word: which altar made it is no
  // choice at all, so making it on another is not another way.
  if (!f.rose) return '$pair → ${f.made.name}, the goal';
  return f.fusedUp
      ? '$pair → ${f.made.name} on altar ${ai + 1}, meets ${f.met} → '
            '${f.landed.name}'
      : '$pair → ${f.made.name} on altar ${ai + 1}';
}

class AltarProof {
  const AltarProof({
    required this.solvable,
    required this.par,
    required this.states,
    required this.plan,
    required this.ways,
    required this.longer,
  });
  final bool solvable;

  /// The fewest moves, and one way in that many.
  final int par;
  final List<String> plan;
  final int states;

  /// Different ways at par, as SETS of moves (the same moves in another
  /// order are one way) — capped at 2.
  final int ways;

  /// Moves of the other ways there, up to par + 2, by how many moves (each
  /// reaching a different end).
  final Set<int> longer;

  bool get unique => solvable && ways == 1;
}

/// Breadth-first by moves, on to [slack] past par to see the longer ways.
AltarProof altarSolve(AltarLevel l, {int slack = 2, int max = 400000}) {
  final s0 = altarStart(l);
  if (altarDone(l, s0)) {
    return const AltarProof(
      solvable: true,
      par: 0,
      states: 1,
      plan: [],
      ways: 1,
      longer: {},
    );
  }
  // Per state: its depth, and the move sets that reach it at that depth
  // (at most two, which is all uniqueness needs), and one way there.
  final depth = <String, int>{};
  final sets = <String, Set<String>>{};
  final via = <String, (String, String)?>{};
  var layer = <String, AltarState>{s0.key: s0};
  depth[s0.key] = 0;
  sets[s0.key] = {''};
  via[s0.key] = null;
  int? par;
  String? goal;
  final ends = <String>{};
  final longer = <int>{};
  for (var d = 0; layer.isNotEmpty && depth.length < max; d++) {
    if (par != null && d >= par + slack) break;
    final next = <String, AltarState>{};
    void reach(AltarState from, String fromKey, AltarState to, String how) {
      final k = to.key;
      final had = depth[k];
      if (had != null && had < d + 1) return;
      if (had == null) {
        depth[k] = d + 1;
        sets[k] = {};
        via[k] = (fromKey, how);
        next[k] = to;
      }
      final mine = sets[k]!;
      for (final set in sets[fromKey]!) {
        if (mine.length >= 2) break;
        final moves = [if (set.isNotEmpty) ...set.split('\n'), how]..sort();
        mine.add(moves.join('\n'));
      }
    }

    for (final MapEntry(key: k, value: s) in layer.entries) {
      if (altarDone(l, s)) continue;
      final us = s.units;
      for (var ai = 0; ai < l.altars; ai++) {
        // Altars with the same column are one choice.
        if (Iterable.generate(ai).any((j) => _same(s.columns[j], s.columns[ai]))) {
          continue;
        }
        final tried = <String>{};
        for (var i = 0; i < us.length; i++) {
          for (var j = i + 1; j < us.length; j++) {
            final pk = ([us[i].sig, us[j].sig]..sort()).join('&');
            if (!tried.add(pk)) continue;
            final f = altarFuse(l, s, ai, us[i], us[j]);
            if (f == null) continue;
            reach(s, k, f.state, _fuseName(us[i], us[j], ai, f));
          }
        }
      }
      if (l.split) {
        final tried = <String>{};
        for (final u in us) {
          if (u.parts == null || !tried.add(u.sig)) continue;
          reach(s, k, altarSplit(s, u)!.$1, 'split ${u.name}');
        }
      }
    }
    for (final MapEntry(key: k, value: s) in next.entries) {
      if (!altarDone(l, s)) continue;
      if (par == null) {
        par = d + 1;
        goal = k;
      }
      if (d + 1 == par) {
        ends.add(k);
      } else {
        longer.add(d + 1);
      }
    }
    layer = next;
  }
  if (par == null) {
    return AltarProof(
      solvable: false,
      par: 0,
      states: depth.length,
      plan: const [],
      ways: 0,
      longer: const {},
    );
  }
  final all = <String>{for (final e in ends) ...sets[e]!};
  final plan = <String>[];
  for (var k = goal!; via[k] != null; k = via[k]!.$1) {
    plan.insert(0, via[k]!.$2);
  }
  return AltarProof(
    solvable: true,
    par: par,
    states: depth.length,
    plan: plan,
    ways: all.length.clamp(0, 2),
    longer: longer,
  );
}

bool _same(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
