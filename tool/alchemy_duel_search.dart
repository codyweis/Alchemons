// tool/alchemy_duel_search.dart
//
// Finds ALCHEMY FOR TWO's boards by search and writes
// lib/games/heart_puzzle/alchemy_duel_boards.dart:
//
//   dart run tool/alchemy_duel_search.dart [seed] [--seconds=N]
//
// Random stages per set — each side's own creatures, a few in the middle,
// circles with orbs over them — with a word for either side, kept only when
// (the author's rules for the puzzle, and the pitch the author took up on
// 2026-10-11: both words can be made, in the same number of moves, and
// neither player can force a win):
//   · alone, each side needs the same number of moves for its word (two at
//     least), so neither is a move away at the start;
//   · played perfectly by both, the match is a draw;
//   · but it is not a quiet one: the first side has a first move that
//     loses; two RACERS (each taking a win, never leaving one, otherwise
//     going for its own word) settle it at least seven times in ten, and
//     not always the same way; and no match played safely is over in under
//     three moves;
//   · every orb hanging can be reached, and in species sets no pair of
//     families breeding has no recipe for can ever meet.
// Then each set is spread over what was found, simplest first.
//
//   --probe prints every board found and what it is like, writing nothing.
//   --out=path writes there instead.

import 'dart:io';
import 'dart:math';

import 'package:alchemons/games/heart_puzzle/alchemy_duel_rules.dart';
import 'package:alchemons/games/heart_puzzle/heart_puzzle_rules.dart';

class DuelSet {
  const DuelSet(
    this.name,
    this.count, {
    required this.altars,
    required this.depth,
    required this.own,
    this.middle = (0, 0),
    required this.reach,
    this.split = false,
    this.species = false,
    this.seconds = 300,
  });
  final String name;
  final int count;

  /// Circles, orbs over each, each side's creatures, the middle's, and the
  /// fewest moves to either word.
  final (int, int) altars, depth, own, middle, reach;
  final bool split, species;
  final int seconds;
}

const _all = [
  'Fire',
  'Water',
  'Earth',
  'Air',
  'Steam',
  'Lava',
  'Lightning',
  'Mud',
  'Ice', //
  'Dust', 'Crystal', 'Plant', 'Poison', 'Spirit', 'Dark', 'Light',
];
const _families = ['Let', 'Let', 'Let', 'Pip', 'Mane', 'Mask', 'Horn'];

const sets = [
  DuelSet(
    'Elements',
    8,
    altars: (2, 3),
    depth: (0, 2),
    own: (3, 3),
    middle: (2, 3),
    reach: (3, 3),
  ),
  DuelSet(
    'The Split',
    8,
    altars: (2, 3),
    depth: (0, 2),
    own: (2, 3),
    middle: (1, 2),
    reach: (3, 4),
    split: true,
    seconds: 1500,
  ),
  DuelSet(
    'Species',
    8,
    altars: (2, 3),
    depth: (0, 1),
    own: (3, 3),
    middle: (2, 3),
    reach: (3, 3),
    species: true,
    seconds: 600,
  ),
];

late Random rnd;
T pick<T>(List<T> xs) => xs[rnd.nextInt(xs.length)];
int between((int, int) r) => r.$1 + rnd.nextInt(r.$2 - r.$1 + 1);

// ── exploring everything reachable ─────────────────────────

class Reach {
  final Map<String, int> depth = {}; // 'El' and 'El Fam' → fewest moves
  final Set<String> nullPairs = {};

  /// Which hanging orbs some fusion can meet ('altar:slot').
  final Set<String> met = {};
  bool cut = false;
}

/// Everything reachable by either side, to [cap] states.
Reach explore(AltarLevel l, {int cap = 60000}) {
  final r = Reach();
  final seen = <String>{};
  var layer = [altarStart(l)];
  seen.add(layer.first.key);
  for (var d = 1; layer.isNotEmpty && seen.length < cap; d++) {
    final next = <AltarState>[];
    for (final s in layer) {
      final us = s.units;
      for (var i = 0; i < us.length; i++) {
        for (var j = i + 1; j < us.length; j++) {
          if (altarRecipe(us[i].el, us[j].el) == null) continue;
          if (l.familyOf(us[i].fam, us[j].fam) == null) {
            r.nullPairs.add(familyKey(us[i].fam, us[j].fam));
            continue;
          }
          for (var ai = 0; ai < l.altars; ai++) {
            final f = altarFuse(l, s, ai, us[i], us[j])!;
            if (f.fusedUp) {
              r.met.add('$ai:${l.columns[ai].length - s.columns[ai].length}');
            }
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

class Proof {
  Proof(
    this.value,
    this.positions,
    this.losing,
    this.safe,
    this.replies, {
    required this.decisions,
    required this.quiet,
    required this.shortest,
  });
  final int value, positions;

  /// The first side's first moves that lose, and that don't.
  final int losing, safe;

  /// After each safe first move, how many of the second side's replies
  /// lose.
  final List<int> replies;

  /// Over every line of safe play (neither side ever losing what it has)
  /// for the first [kLook] moves: the turns where the side to move had a
  /// move that loses, and the turns where it had none.
  final int decisions, quiet;

  /// The fewest moves a match played safely can last.
  final int shortest;

  double get sharpness => decisions / max(1, decisions + quiet);

  /// Two players who look one move ahead (take a win, never leave the
  /// other one), and otherwise pick at random: how often each side wins.
  late (double, double, double) casual;
}

/// The odds of each end with both sides playing as RACERS from [p]
/// (first wins, second wins, draw): a racer takes a win when it has one,
/// never leaves the other side one if it can help it, and otherwise makes
/// whichever move brings its own word nearest (alone), at random among
/// equals. A board where racers settle it is a race; the search wants one
/// where looking further than that pays.
class Racer {
  Racer(this.b);
  final DuelBoard b;
  final Map<String, (double, double, double)> _memo = {};
  final Map<String, int> _near = {};

  int? owner(DuelPosition q) => duelWordOnStage(b, q)?.$2;

  /// The fewest moves [side] needs from [q] alone (99: it can't).
  int near(DuelPosition q, int side) =>
      _near.putIfAbsent('${q.board}@$side', () {
        final fam = b.wordFamilyOf(side);
        final want = fam == null ? b.wordOf(side) : '${b.wordOf(side)} $fam';
        var layer = [DuelPosition(q.stage, q.side, turns: side)];
        final seen = {layer.first.board};
        for (var d = 0; d < 6 && layer.isNotEmpty; d++) {
          final next = <DuelPosition>[];
          for (final p in layer) {
            if (owner(p) == side) return d;
            for (final s in duelSteps(b, p)) {
              if (s.pass) continue;
              final n = DuelPosition(s.next.stage, s.next.side, turns: side);
              if (seen.add(n.board)) next.add(n);
            }
          }
          layer = next;
        }
        final _ = want;
        return 99;
      });

  (double, double, double) from(DuelPosition p) {
    final k = p.key;
    final had = _memo[k];
    if (had != null) return had;
    final end = duelOutcome(b, p);
    if (end != null) {
      return _memo[k] = switch (end) {
        DuelEnd.firstWins => (1, 0, 0),
        DuelEnd.secondWins => (0, 1, 0),
        DuelEnd.draw => (0, 0, 1),
      };
    }
    final me = p.toMove;
    final after = [for (final s in duelSteps(b, p)) s.next];
    final wins = after.where((q) => owner(q) == me).toList();
    List<DuelPosition> pool;
    if (wins.isNotEmpty) {
      pool = wins;
    } else {
      bool gives(DuelPosition q) =>
          q.turns < kDuelMoveCap &&
          duelSteps(b, q).any((s) => owner(s.next) == 1 - me);
      final safe = after.where((q) => !gives(q)).toList();
      final options = safe.isNotEmpty ? safe : after;
      final best = options.map((q) => near(q, me)).reduce(min);
      pool = [
        for (final q in options)
          if (near(q, me) == best) q,
      ];
    }
    var a = 0.0, c = 0.0, d = 0.0;
    for (final q in pool) {
      final (x, y, z) = from(q);
      a += x;
      c += y;
      d += z;
    }
    final n = pool.length;
    return _memo[k] = (a / n, c / n, d / n);
  }
}

const kLook = 4;

Proof? prove(DuelBoard b, {int cap = 400000}) {
  final solver = DuelSolver(b);
  final p0 = duelStart(b);
  final v = solver.value(p0);
  if (solver.positions > cap) return null;
  var losing = 0, safe = 0;
  final replies = <int>[];
  for (final (s, w) in solver.graded(p0)) {
    if (w != v) {
      losing++;
      continue;
    }
    safe++;
    final p1 = s.next;
    replies.add(solver.graded(p1).where((r) => r.$2 != v).length);
  }
  var decisions = 0, quiet = 0, shortest = 1 << 30;
  final seen = <String>{};
  void walk(DuelPosition p, int depth) {
    if (duelOutcome(b, p) != null) {
      shortest = min(shortest, p.turns);
      return;
    }
    if (depth >= kLook) return;
    final g = solver.graded(p);
    final counted = seen.add(p.key);
    if (counted) {
      if (g.any((x) => x.$2 != v)) {
        decisions++;
      } else {
        quiet++;
      }
    }
    for (final (s, w) in g) {
      if (w == v) walk(s.next, depth + 1);
    }
  }

  walk(p0, 0);
  final casual = Racer(b).from(p0);
  return Proof(
    v,
    solver.positions,
    losing,
    safe,
    replies,
    decisions: decisions,
    quiet: quiet,
    shortest: shortest,
  )..casual = casual;
}

/// What [side] can make alone — its own creatures and the middle's, the
/// other side never moving — and the fewest moves to each ('El', 'El Fam').
Map<String, int> solo(DuelBoard b, int side, {int cap = 40000}) {
  final out = <String, int>{};
  final p0 = duelStart(b);
  var layer = [DuelPosition(p0.stage, p0.side, turns: side)];
  final seen = {layer.first.board};
  for (var d = 1; layer.isNotEmpty && seen.length < cap; d++) {
    final next = <DuelPosition>[];
    for (final p in layer) {
      if (duelWordOnStage(b, p) != null) continue;
      for (final s in duelSteps(b, p)) {
        if (s.pass) continue;
        final q = DuelPosition(s.next.stage, s.next.side, turns: side);
        for (final u in q.stage.units) {
          if (q.sideOf(u) != side) continue;
          out.putIfAbsent(u.el, () => d);
          out.putIfAbsent('${u.el} ${u.fam}', () => d);
        }
        if (seen.add(q.board)) next.add(q);
      }
    }
    layer = next;
  }
  return out;
}

String _creature(DuelSet c) {
  if (!c.species) return pick(_all);
  final f = pick(_families);
  final e = pick(_all);
  return f == 'Let' ? e : '$e $f';
}

/// Why each attempt was thrown away, per set (printed as it ends).
final why = <String, int>{};
void no(String r) => why[r] = (why[r] ?? 0) + 1;

DuelBoard? attempt(DuelSet c) {
  final n = between(c.altars);
  final columns = [
    for (var a = 0; a < n; a++)
      [for (var k = between(c.depth); k > 0; k--) pick(_all)],
  ];
  final first = [for (var k = between(c.own); k > 0; k--) _creature(c)];
  final second = [for (var k = between(c.own); k > 0; k--) _creature(c)];
  final middle = [for (var k = between(c.middle); k > 0; k--) _creature(c)];
  // What either side can bring together — its own and the middle's: no
  // pair of families breeding has no recipe for may meet, and every orb
  // hanging can be reached by someone.
  final met = <String>{};
  for (final own in [first, second]) {
    final r = explore(
      AltarLevel(
        goal: 'x',
        hand: [...own, ...middle],
        columns: columns,
        split: c.split,
        species: c.species,
        par: 0,
      ),
    );
    if (r.cut) {
      no('cut');
      return null;
    }
    if (r.nullPairs.isNotEmpty) {
      no('null');
      return null;
    }
    met.addAll(r.met);
  }
  for (var a = 0; a < n; a++) {
    for (var k = 0; k < columns[a].length; k++) {
      if (!met.contains('$a:$k')) {
        no('orb');
        return null;
      }
    }
  }
  DuelBoard board(String w0, String w1) {
    final (e0, f0) = c.species ? parseSpecies(w0) : (w0, null);
    final (e1, f1) = c.species ? parseSpecies(w1) : (w1, null);
    return DuelBoard(
      goal: e0,
      goalFamily: f0,
      rival: e1,
      rivalFamily: f1,
      first: first,
      second: second,
      middle: middle,
      columns: columns,
      split: c.split,
      species: c.species,
    );
  }

  final held = {
    for (final h in [...first, ...second, ...middle]) parseSpecies(h).$1,
  };
  Map<String, int> words(int side) => {
    for (final MapEntry(key: g, value: d) in solo(
      board('x', 'y'),
      side,
    ).entries)
      if (d >= c.reach.$1 &&
          d <= c.reach.$2 &&
          (c.species ? g.contains(' ') : !g.contains(' ')) &&
          !held.contains(g.split(' ').first))
        g: d,
  };
  final w0s = words(0), w1s = words(1);
  if (w0s.isEmpty || w1s.isEmpty) {
    no('words');
    return null;
  }
  final w0 = pick(w0s.keys.toList());
  final d = w0s[w0]!;
  final rivals = [
    for (final MapEntry(key: g, value: dd) in w1s.entries)
      if (dd == d && g.split(' ').first != w0.split(' ').first) g,
  ];
  if (rivals.isEmpty) {
    no('rivals');
    return null;
  }
  final b = board(w0, pick(rivals));
  // With the real words (made on a circle, a word stays there), still the
  // same distance each.
  if (distanceOf(b, 0) != d || distanceOf(b, 1) != d) {
    no('dist');
    return null;
  }
  no('ok');
  return b;
}

/// The fewest moves [side] needs for its word, alone.
int? distanceOf(DuelBoard b, int side) {
  final fam = b.wordFamilyOf(side);
  return solo(b, side)[fam == null ? b.wordOf(side) : '${b.wordOf(side)} $fam'];
}

/// Fair, and worth thinking about: played perfectly it is a draw, but
/// two racers settle it (and not always the same way), the first side can
/// lose on its first move, and no safe match is over in under three.
bool sharp(Proof p) =>
    p.value == 0 &&
    p.losing >= 1 &&
    p.casual.$3 <= .3 &&
    p.casual.$1 >= .2 &&
    p.casual.$1 <= .8 &&
    p.shortest >= 3;

String keyOf(DuelBoard b) =>
    '${b.goal} ${b.goalFamily}|${b.rival} ${b.rivalFamily}|'
    '${([...b.first]..sort()).join(',')}|${([...b.second]..sort()).join(',')}|'
    '${([...b.middle]..sort()).join(',')}|'
    '${(b.columns.map((c) => c.join(',')).toList()..sort()).join('/')}';

void main(List<String> args) {
  final seed = args.where((a) => !a.startsWith('--')).firstOrNull;
  // --probe prints what each fair board found is like, and writes nothing.
  final probe = args.contains('--probe');
  final cap = args
      .where((a) => a.startsWith('--seconds='))
      .map((a) => int.parse(a.substring(10)))
      .firstOrNull;
  if (probe) stdout.writeln('probing');
  final outPath =
      args
          .where((a) => a.startsWith('--out='))
          .map((a) => a.substring(6))
          .firstOrNull ??
      'lib/games/heart_puzzle/alchemy_duel_boards.dart';
  rnd = Random(seed == null ? 11 : int.parse(seed));
  final chosenAll = <(DuelSet, List<(DuelBoard, Proof, int)>)>[];
  for (final c in sets) {
    final found = <String, (DuelBoard, Proof, int)>{};
    final want = c.count * 4;
    final sw = Stopwatch()..start();
    var tries = 0, values = <int, int>{};
    while (found.length < want && sw.elapsed.inSeconds < (cap ?? c.seconds)) {
      tries++;
      final b = attempt(c);
      if (b == null) continue;
      final k = keyOf(b);
      if (found.containsKey(k)) continue;
      final p = prove(b);
      if (p == null) continue;
      values[p.value] = (values[p.value] ?? 0) + 1;
      if (probe) {
        stdout.writeln(
          '${c.name}\tv=${p.value}\td=${distanceOf(b, 0)}'
          '\tpos=${p.positions}\tfirst=${p.losing}/${p.losing + p.safe}'
          '\treplies=${p.replies}\tsharp=${p.sharpness.toStringAsFixed(2)}'
          '(${p.decisions}/${p.decisions + p.quiet})\tshortest=${p.shortest > 99 ? '>$kLook' : p.shortest}'
          '\tcasual=${p.casual.$1.toStringAsFixed(2)}/${p.casual.$2.toStringAsFixed(2)}/${p.casual.$3.toStringAsFixed(2)}'
          '\thands=${b.first.length}/${b.second.length}/${b.middle.length}\tcols=${b.columns}',
        );
      }
      if (!sharp(p)) continue;
      final d = distanceOf(b, 0)!;
      found[k] = (b, p, d);
      stderr.write(
        '\r${c.name}: ${found.length}/$want '
        '($tries tries, values $values)   ',
      );
    }
    stderr.writeln('\n$why');
    why.clear();
    final all = found.values.toList()
      ..sort((a, b) => a.$2.positions.compareTo(b.$2.positions));
    if (all.length < c.count) {
      stderr.writeln('  only ${all.length} for ${c.name}');
    }
    // Spread over what was found, simplest first.
    final chosen = <(DuelBoard, Proof, int)>[
      for (var i = 0; i < c.count && i < all.length; i++)
        all[c.count == 1 || all.length <= c.count
            ? i
            : (i * (all.length - 1) / (c.count - 1)).round()],
    ];
    chosenAll.add((c, chosen));
  }

  final out = StringBuffer()
    ..writeln('// lib/games/heart_puzzle/alchemy_duel_boards.dart')
    ..writeln('//')
    ..writeln(
      '// GENERATED by tool/alchemy_duel_search.dart — found by search and',
    )
    ..writeln(
      '// proved; test/alchemy_duel_test.dart holds each to its proof: a draw',
    )
    ..writeln(
      '// played perfectly, a first move that loses, and two racers settling',
    )
    ..writeln(
      '// it. Above each board: the fewest moves to either word, the positions',
    )
    ..writeln(
      '// the proof visits, and how many of the first side\'s first moves lose.',
    )
    ..writeln()
    ..writeln(
      "import 'package:alchemons/games/heart_puzzle/alchemy_duel_rules.dart';",
    )
    ..writeln()
    ..writeln('class DuelSetInfo {')
    ..writeln('  const DuelSetInfo(this.name, this.first, this.last);')
    ..writeln('  final String name;')
    ..writeln('  final int first, last;')
    ..writeln('}')
    ..writeln();
  final ss = StringBuffer('const List<DuelSetInfo> kDuelSets = [\n');
  final bs = StringBuffer('const List<DuelBoard> kDuelBoards = [\n');
  var number = 0;
  for (final (c, chosen) in chosenAll) {
    ss.writeln(
      "  DuelSetInfo('${c.name}', ${number + 1}, ${number + chosen.length}),",
    );
    bs.writeln('  // ── ${c.name} ──');
    for (final (b, p, d) in chosen) {
      number++;
      bs.writeln(
        '  // $number. $d moves to either word, ${p.positions} positions, '
        '${p.losing} of ${p.losing + p.safe} first moves lose',
      );
      bs.writeln('  DuelBoard(');
      bs.writeln("    goal: '${b.goal}',");
      if (b.goalFamily != null) {
        bs.writeln("    goalFamily: '${b.goalFamily}',");
      }
      bs.writeln("    rival: '${b.rival}',");
      if (b.rivalFamily != null) {
        bs.writeln("    rivalFamily: '${b.rivalFamily}',");
      }
      bs.writeln('    first: [${b.first.map((h) => "'$h'").join(', ')}],');
      bs.writeln('    second: [${b.second.map((h) => "'$h'").join(', ')}],');
      if (b.middle.isNotEmpty) {
        bs.writeln('    middle: [${b.middle.map((h) => "'$h'").join(', ')}],');
      }
      bs.writeln('    columns: [');
      for (final col in b.columns) {
        bs.writeln('      [${col.map((h) => "'$h'").join(', ')}],');
      }
      bs.writeln('    ],');
      if (b.split) bs.writeln('    split: true,');
      if (b.species) bs.writeln('    species: true,');
      bs.writeln('  ),');
    }
  }
  ss.writeln('];');
  bs.writeln('];');
  out
    ..write(ss)
    ..writeln()
    ..write(bs);
  if (probe) return;
  File(outPath).writeAsStringSync(out.toString());
  stderr.writeln('wrote $number boards');
}
