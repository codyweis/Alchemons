// tool/heart_puzzle_search.dart
//
// Finds THE ALTARS' levels by search and writes
// lib/games/heart_puzzle/heart_puzzle_levels.dart:
//
//   dart run tool/heart_puzzle_search.dart [seed]
//
// Random layouts per chapter, kept only when (the author's puzzle rules —
// no chance, recipe-grounded, nothing repeated, everything matters, and
// since 2026-10-08 every orb taken before a level is done):
//   · there is ONE shortest way (the same moves in another order are one);
//   · no recipe is made twice on it;
//   · every creature on the stage, every element hanging, every altar and
//     the split stage changes the answer if it is taken away;
//   · from the split on, longer ways exist too, so the stars mean something;
//   · in species levels the family in the goal matters, and no pair of
//     families breeding has no recipe for can ever meet.
// Then each chapter is spread over its par range, easiest first.

import 'dart:io';
import 'dart:math';

import 'package:alchemons/games/heart_puzzle/heart_puzzle_levels.dart' as existing;
import 'package:alchemons/games/heart_puzzle/heart_puzzle_rules.dart';

class Chapter {
  const Chapter(
    this.name,
    this.count, {
    required this.altars,
    required this.depth,
    required this.hand,
    required this.par,
    this.split = false,
    this.species = false,
    this.handPool = _all,
    this.hangPool = _all,
    this.goal,
    this.longer = false,
    this.minHanging = 0,
    bool? speciesGoal,
    this.seconds = 240,
    this.familyPool = _families,
    this.authored = false,
  }) : speciesGoal = speciesGoal ?? species;
  final String name;
  final int count;
  final (int, int) altars, depth, hand, par;
  final bool split, species, longer;
  final List<String> handPool, hangPool;
  final String? goal;
  final int minHanging;

  /// The goal names a family too (species levels, unless it is Blood).
  final bool speciesGoal;
  final int seconds;

  /// The families a hand is dealt from.
  final List<String> familyPool;

  /// Made by hand: never searched, always kept.
  final bool authored;
}

const _base = ['Fire', 'Water', 'Earth', 'Air'];
const _all = [
  'Fire', 'Water', 'Earth', 'Air', 'Steam', 'Lava', 'Lightning', 'Mud', 'Ice', //
  'Dust', 'Crystal', 'Plant', 'Poison', 'Spirit', 'Dark', 'Light',
];
const _early = [..._base, 'Lava', 'Mud', 'Ice', 'Dust', 'Lightning', 'Steam'];
const _bloodPool = [
  'Fire', 'Water', 'Earth', 'Air', 'Spirit', 'Crystal', 'Poison', 'Lava', //
  'Mud', 'Lightning', 'Plant', 'Ice', 'Dark', 'Light',
];
const _families = ['Let', 'Let', 'Let', 'Pip', 'Mane', 'Mask', 'Horn'];

/// Let, Pip and Mask only ever make each other by the one family rule.
const _closedFamilies = ['Let', 'Let', 'Pip', 'Mask'];

const chapters = [
  // Made by hand, and always kept as they are.
  Chapter('Basics', 3,
      altars: (1, 2), depth: (0, 1), hand: (2, 3), par: (1, 2), authored: true),
  Chapter('Rising', 8,
      altars: (1, 3), depth: (0, 1), hand: (2, 5), par: (2, 5),
      handPool: _early, minHanging: 1),
  Chapter('The Split', 9,
      altars: (1, 3), depth: (0, 2), hand: (2, 4), par: (3, 7),
      split: true, longer: true, minHanging: 1),
  Chapter('Species', 9,
      altars: (1, 3), depth: (0, 1), hand: (2, 5), par: (2, 6),
      species: true, longer: true, handPool: _early, seconds: 600),
  Chapter('Stacks', 8,
      altars: (2, 3), depth: (0, 2), hand: (2, 4), par: (4, 8),
      split: true, species: true, longer: true, minHanging: 3,
      seconds: 600),
  Chapter('Blood', 8,
      altars: (2, 4), depth: (0, 2), hand: (2, 5), par: (4, 10),
      split: true, species: true, longer: true, goal: 'Blood',
      speciesGoal: false, handPool: _bloodPool, hangPool: _bloodPool,
      minHanging: 2, seconds: 900, familyPool: _closedFamilies),
];

late Random rnd;
T pick<T>(List<T> xs) => xs[rnd.nextInt(xs.length)];
int between((int, int) r) => r.$1 + rnd.nextInt(r.$2 - r.$1 + 1);

// ── exploring everything reachable ─────────────────────────

class Reach {
  final Map<String, int> depth = {}; // 'El' and 'El Fam' → fewest moves
  final Set<String> nullPairs = {}, pairs = {};

  /// It stopped at the cap: what can meet is not known for certain.
  bool cut = false;
}

/// Everything reachable, to [cap] states: what can be made how soon, and
/// which family pairs meet (and which have no rule).
Reach explore(AltarLevel l, {int cap = 150000, int maxDepth = 99}) {
  final r = Reach();
  final seen = <String>{};
  var layer = [altarStart(l)];
  seen.add(layer.first.key);
  for (var d = 1; d <= maxDepth && layer.isNotEmpty && seen.length < cap; d++) {
    final next = <AltarState>[];
    for (final s in layer) {
      final us = s.units;
      for (var i = 0; i < us.length; i++) {
        for (var j = i + 1; j < us.length; j++) {
          if (altarRecipe(us[i].el, us[j].el) == null) continue;
          final fk = familyKey(us[i].fam, us[j].fam);
          r.pairs.add(fk);
          if (l.familyOf(us[i].fam, us[j].fam) == null) {
            r.nullPairs.add(fk);
            continue;
          }
          for (var ai = 0; ai < l.altars; ai++) {
            final f = altarFuse(l, s, ai, us[i], us[j])!;
            for (final u in [f.made, f.landed]) {
              r.depth.putIfAbsent(u.el, () => d);
              r.depth.putIfAbsent('${u.el} ${u.fam}', () => d);
            }
            if (seen.add(f.state.key)) next.add(f.state);
          }
        }
      }
      if (l.split) {
        for (final u in us) {
          final sp = altarSplit(s, u);
          if (sp == null) continue;
          for (final p in [sp.$2, sp.$3]) {
            r.depth.putIfAbsent(p.el, () => d);
            r.depth.putIfAbsent('${p.el} ${p.fam}', () => d);
          }
          if (seen.add(sp.$1.key)) next.add(sp.$1);
        }
      }
    }
    layer = next;
  }
  r.cut = layer.isNotEmpty;
  return r;
}

// ── the checks ─────────────────────────────────────────────

bool same(AltarProof a, AltarProof b) =>
    b.solvable == a.solvable &&
    b.par == a.par &&
    b.unique == a.unique &&
    b.longer.length == a.longer.length &&
    b.longer.containsAll(a.longer);

AltarLevel with_(
  AltarLevel l, {
  List<String>? hand,
  List<List<String>>? columns,
  bool? split,
  bool clearFamily = false,
  int par = 0,
}) => AltarLevel(
  goal: l.goal,
  goalFamily: clearFamily ? null : l.goalFamily,
  hand: hand ?? l.hand,
  columns: columns ?? l.columns,
  split: split ?? l.split,
  species: l.species,
  par: par,
);

/// The fusion a move makes on its altar, whatever it meets up there: the
/// same pair making the same thing twice is the same action repeated.
String recipeOf(String move) => move.replaceAll(RegExp(r' on altar \d+.*'), '');

AltarProof? check(AltarLevel l, Chapter c) {
  final p = altarSolve(l);
  if (!p.solvable || !p.unique) return null;
  if (p.par < c.par.$1 || p.par > c.par.$2) return null;
  if (c.longer && p.longer.isEmpty) return null;
  final recipes = p.plan.map(recipeOf).toList();
  if (recipes.toSet().length != recipes.length) return null;
  if (c.split && !p.plan.any((m) => m.startsWith('split'))) return null;
  // Altars over the same thing are one altar.
  final cols = l.columns.map((c) => c.join(',')).toList();
  if (cols.toSet().length != cols.length) return null;

  bool matters(AltarLevel without) => !same(p, altarSolve(without));

  for (final h in l.hand.toSet()) {
    final i = l.hand.indexOf(h);
    if (!matters(with_(l, hand: [...l.hand]..removeAt(i)))) return null;
  }
  for (var a = 0; a < l.altars; a++) {
    if (l.altars > 1 &&
        !matters(with_(l, columns: [...l.columns]..removeAt(a)))) {
      return null;
    }
    for (var k = 0; k < l.columns[a].length; k++) {
      final cs = [for (final c in l.columns) List<String>.of(c)];
      cs[a].removeAt(k);
      if (!matters(with_(l, columns: cs))) return null;
    }
  }
  if (l.split) {
    final q = altarSolve(with_(l, split: false));
    if (q.solvable && q.par <= p.par) return null;
  }
  if (l.species) {
    if (l.goalFamily != null && !matters(with_(l, clearFamily: true))) {
      return null;
    }
  }
  return p;
}

// ── making one ─────────────────────────────────────────────

AltarLevel? attempt(Chapter c) {
  final n = between(c.altars);
  final columns = [
    for (var a = 0; a < n; a++)
      [for (var k = between(c.depth); k > 0; k--) pick(c.hangPool)],
  ];
  if (columns.fold<int>(0, (m, c) => m + c.length) < c.minHanging) return null;
  final hand = [
    for (var k = between(c.hand); k > 0; k--)
      c.species
          ? () {
              final f = pick(c.familyPool);
              final e = pick(c.handPool);
              return f == 'Let' ? e : '$e $f';
            }()
          : pick(c.handPool),
  ];
  final l = AltarLevel(
    goal: 'x',
    hand: hand,
    columns: columns,
    split: c.split,
    species: c.species,
    par: 0,
  );
  // One family rule everywhere: a level where two families breeding has no
  // recipe for could meet is no level.
  final r = explore(l);
  if (r.cut || r.nullPairs.isNotEmpty) return null;
  final inHand = hand.map((h) => parseSpecies(h).$1).toSet();
  final goals = [
    for (final MapEntry(key: g, value: d) in r.depth.entries)
      if (d >= c.par.$1 &&
          d <= c.par.$2 &&
          (c.goal == null || g.split(' ').first == c.goal) &&
          (c.speciesGoal ? g.contains(' ') : !g.contains(' ')) &&
          !inHand.contains(g.split(' ').first))
        g,
  ];
  if (goals.isEmpty) return null;
  final g = pick(goals);
  final (el, fam) = c.speciesGoal ? parseSpecies(g) : (g, null);
  return AltarLevel(
    goal: el,
    goalFamily: fam,
    hand: hand,
    columns: columns,
    split: c.split,
    species: c.species,
    par: 0,
  );
}

String keyOf(AltarLevel l) =>
    '${l.goal} ${l.goalFamily}|${([...l.hand]..sort()).join(',')}|'
    '${(l.columns.map((c) => c.join(',')).toList()..sort()).join('/')}';

const _dungeonHeart = 'Blood null|Air,Earth,Fire,Water|/Earth/Spirit/Spirit,Lava';

void main(List<String> args) {
  // --only=Stacks,Blood searches just those; the rest are kept as they are.
  final only = args
      .where((a) => a.startsWith('--only='))
      .expand((a) => a.substring(7).split(','))
      .toSet();
  final seed = args.where((a) => !a.startsWith('--')).firstOrNull;
  // --seconds=N caps each chapter's search.
  final cap = args
      .where((a) => a.startsWith('--seconds='))
      .map((a) => int.parse(a.substring(10)))
      .firstOrNull;
  // --out=path writes there instead (searches run side by side).
  final outPath = args
          .where((a) => a.startsWith('--out='))
          .map((a) => a.substring(6))
          .firstOrNull ??
      'lib/games/heart_puzzle/heart_puzzle_levels.dart';
  rnd = Random(seed == null ? 7 : int.parse(seed));
  final out = StringBuffer();
  var number = 0;
  final chosenAll = <(Chapter, List<(AltarLevel, AltarProof)>)>[];
  for (final c in chapters) {
    if (c.authored || (only.isNotEmpty && !only.contains(c.name))) {
      final had = existing.kAltarChapters.where((e) => e.name == c.name).firstOrNull;
      chosenAll.add((
        c,
        [
          if (had != null)
            for (var n = had.first; n <= had.last; n++)
              (existing.kAltarLevels[n - 1], altarSolve(existing.kAltarLevels[n - 1])),
        ],
      ));
      continue;
    }
    final found = <String, (AltarLevel, AltarProof)>{};
    final want = c.count * 6;
    final sw = Stopwatch()..start();
    var tries = 0;
    while (found.length < want && sw.elapsed.inSeconds < (cap ?? c.seconds)) {
      tries++;
      final l = attempt(c);
      if (l == null) continue;
      final k = keyOf(l);
      if (found.containsKey(k) || k == _dungeonHeart) continue;
      final p = check(l, c);
      if (p == null) continue;
      found[k] = (with_(l, par: p.par), p);
      stderr.write('\r${c.name}: ${found.length}/$want ($tries tries)   ');
    }
    stderr.writeln();
    final all = found.values.toList()
      ..sort((a, b) {
        final d = a.$2.par.compareTo(b.$2.par);
        return d != 0 ? d : a.$2.states.compareTo(b.$2.states);
      });
    if (all.length < c.count) {
      stderr.writeln('  only ${all.length} for ${c.name}');
    }
    // Spread over the PARS found, not the list (most of what a search finds
    // is easy): easiest first, hardest last, and within a par the busier
    // boards later.
    final byPar = <int, List<(AltarLevel, AltarProof)>>{};
    for (final x in all) {
      (byPar[x.$2.par] ??= []).add(x);
    }
    final pars = byPar.keys.toList()..sort();
    final chosen = <(AltarLevel, AltarProof)>[];
    for (var i = 0; i < c.count && pars.isNotEmpty; i++) {
      final want = pars[c.count == 1 ? 0 : (i * (pars.length - 1) / (c.count - 1)).round()];
      // The nearest par with something left.
      final order = [...pars]..sort((a, b) => (a - want).abs().compareTo((b - want).abs()));
      for (final p in order) {
        final left = byPar[p]!.where((x) => !chosen.contains(x)).toList();
        if (left.isEmpty) continue;
        chosen.add(left[left.length ~/ 2]);
        break;
      }
    }
    chosen.sort((a, b) {
      final d = a.$2.par.compareTo(b.$2.par);
      return d != 0 ? d : a.$2.states.compareTo(b.$2.states);
    });
    chosenAll.add((c, chosen));
  }

  out.writeln('// lib/games/heart_puzzle/heart_puzzle_levels.dart');
  out.writeln('//');
  out.writeln('// GENERATED by tool/heart_puzzle_search.dart — found by search and');
  out.writeln('// proved; test/heart_puzzle_test.dart holds each to its par and its');
  out.writeln('// one way. The way is written above each level.');
  out.writeln();
  out.writeln("import 'package:alchemons/games/heart_puzzle/heart_puzzle_rules.dart';");
  out.writeln();
  out.writeln('class AltarChapter {');
  out.writeln('  const AltarChapter(this.name, this.first, this.last);');
  out.writeln('  final String name;');
  out.writeln('  final int first, last;');
  out.writeln('}');
  out.writeln();
  final chs = StringBuffer('const List<AltarChapter> kAltarChapters = [\n');
  final lv = StringBuffer('const List<AltarLevel> kAltarLevels = [\n');
  for (final (c, chosen) in chosenAll) {
    chs.writeln("  AltarChapter('${c.name}', ${number + 1}, ${number + chosen.length}),");
    lv.writeln('  // ── ${c.name} ──');
    for (final (l, p) in chosen) {
      number++;
      lv.writeln('  // $number. par ${p.par}, ${p.states} states'
          '${p.longer.isEmpty ? '' : ', longer: ${(p.longer.toList()..sort()).join('/')}'}');
      for (final m in p.plan) {
        lv.writeln('  //   $m');
      }
      lv.writeln('  AltarLevel(');
      lv.writeln("    goal: '${l.goal}',");
      if (l.goalFamily != null) lv.writeln("    goalFamily: '${l.goalFamily}',");
      lv.writeln('    hand: [${l.hand.map((h) => "'$h'").join(', ')}],');
      lv.writeln('    columns: [');
      for (final col in l.columns) {
        lv.writeln('      [${col.map((h) => "'$h'").join(', ')}],');
      }
      lv.writeln('    ],');
      if (l.split) lv.writeln('    split: true,');
      if (l.species) lv.writeln('    species: true,');
      lv.writeln('    par: ${p.par},');
      lv.writeln('  ),');
    }
  }
  chs.writeln('];');
  lv.writeln('];');
  out
    ..write(chs)
    ..writeln()
    ..write(lv);
  File(outPath).writeAsStringSync(out.toString());
  stderr.writeln('wrote $number levels');
}
