// lib/games/heart_puzzle/alchemy_duel_rules.dart
//
// ALCHEMY FOR TWO (the author, 2026-10-11: "what if we made my alchemy
// puzzle game a 2 player battle"; open goals, two players on one phone
// first). The pure rules and the game's solver; the boards are
// alchemy_duel_boards.dart, found by tool/alchemy_duel_search.dart and held
// to their proofs by test/alchemy_duel_test.dart.
//
// One stage between two players. Each has a word to make and creatures of
// their own; the circles, the orbs over them, the split stage and any
// creatures left in the middle are for whoever gets there first.
// Everything is in view. The puzzle's rules stand as they are
// (heart_puzzle_rules.dart); taking turns adds these:
//   · ONE MOVE A TURN: a fusion or a split, with your own creatures or the
//     ones in the middle. What it makes, and what comes down, is yours.
//   · FIRST TO MAKE THEIR WORD WINS.
//   · No move at all: the turn passes. After [kDuelMoveCap] moves, or when
//     neither can move, it is a DRAW.
// The puzzle's "every orb taken" rule is left out: a word wins at once.
//
// Nothing is timed and nothing is chance. Who moves first is the board's
// first word; a rematch swaps the players over, not the board.

import 'package:alchemons/games/heart_puzzle/heart_puzzle_rules.dart';

/// Moves in a match, both players together, before it is a draw.
const int kDuelMoveCap = 20;

/// Whose a creature is: either side's, or the middle's (anyone's).
const int kDuelMiddle = -1;

/// A board for two: the stage of a puzzle level, with a word and creatures
/// for each side. [goal] and [first] are the side that moves first's,
/// [rival] and [second] the other's; [hand] waits in the middle.
class DuelBoard extends AltarLevel {
  const DuelBoard({
    required super.goal,
    super.goalFamily,
    required this.rival,
    this.rivalFamily,
    required this.first,
    required this.second,
    List<String> middle = const [],
    required super.columns,
    super.split,
    super.species,
  }) : super(hand: middle, par: 0);

  final String rival;
  final String? rivalFamily;
  final List<String> first, second;

  List<String> get middle => hand;

  String wordOf(int side) => side == 0 ? goal : rival;
  String? wordFamilyOf(int side) => side == 0 ? goalFamily : rivalFamily;
  List<String> creaturesOf(int side) => side == 0 ? first : second;

  /// Whether [u] is [side]'s word.
  bool isWord(int side, AltarUnit u) {
    final fam = wordFamilyOf(side);
    return u.el == wordOf(side) && (fam == null || u.fam == fam);
  }

  /// Either word, made on a circle, stays there: it does not rise.
  @override
  bool caught(AltarUnit u) => isWord(0, u) || isWord(1, u);
}

/// Where a match stands: the stage, whose each creature is, and how many
/// turns have gone (a pass is a turn too).
class DuelPosition {
  DuelPosition(this.stage, this.side, {this.turns = 0});
  final AltarState stage;

  /// Creature id → 0, 1 or [kDuelMiddle].
  final Map<String, int> side;
  final int turns;

  /// The side to move: 0 moved first.
  int get toMove => turns.isEven ? 0 : 1;

  /// Whose [u] is.
  int sideOf(AltarUnit u) => side[u.id] ?? kDuelMiddle;

  /// The board itself: every creature with whose it is, and the columns.
  late final String board = () {
    final us = [for (final u in stage.units) '${sideOf(u)}:${u.sig}']..sort();
    return '${us.join(';')}|'
        '${stage.columns.map((c) => c.join(',')).join('/')}';
  }();

  String get key => '$board#$turns';
}

DuelPosition duelStart(DuelBoard b) {
  final units = <AltarUnit>[];
  final side = <String, int>{};
  var n = 0;
  void add(String s, int who) {
    final (el, fam) = parseSpecies(s);
    final u = AltarUnit('u${n++}', el, fam);
    units.add(u);
    side[u.id] = who;
  }

  for (final s in b.first) {
    add(s, 0);
  }
  for (final s in b.second) {
    add(s, 1);
  }
  for (final s in b.middle) {
    add(s, kDuelMiddle);
  }
  return DuelPosition(
    AltarState(units, [for (final c in b.columns) List<String>.of(c)], n),
    side,
  );
}

/// One move: what it is called, the position it leaves, and what it was —
/// the two fused on which circle (and how it played out), or the one split.
class DuelStep {
  const DuelStep(
    this.name,
    this.next, {
    this.fusion,
    this.altar = -1,
    this.pair,
    this.split,
  });
  final String name;
  final DuelPosition next;
  final AltarFusion? fusion;
  final int altar;
  final (AltarUnit, AltarUnit)? pair;
  final AltarUnit? split;

  /// The turn passing, with no move to make.
  bool get pass => name == kDuelPass;
}

const String kDuelPass = 'pass';

/// Whether [p]'s side may use [u].
bool duelMayUse(DuelPosition p, AltarUnit u) {
  final s = p.sideOf(u);
  return s == p.toMove || s == kDuelMiddle;
}

/// The position after [p]'s side leaves [next] — everything new on the
/// stage is theirs.
DuelPosition duelAfter(DuelPosition p, AltarState next) {
  final me = p.toMove;
  final side = <String, int>{
    for (final u in next.units) u.id: p.side[u.id] ?? me,
  };
  return DuelPosition(next, side, turns: p.turns + 1);
}

/// Like [duelAfter], for a split: both halves are the splitter's.
DuelPosition duelAfterSplit(DuelPosition p, AltarState next, AltarUnit u) {
  final me = p.toMove;
  final parts = {for (final x in u.parts!) x.id};
  final side = <String, int>{
    for (final x in next.units)
      x.id: parts.contains(x.id) ? me : (p.side[x.id] ?? me),
  };
  return DuelPosition(next, side, turns: p.turns + 1);
}

/// Every move [p]'s side may make, one per different board it leaves; a
/// lone pass when it has none.
List<DuelStep> duelSteps(DuelBoard b, DuelPosition p) {
  final s = p.stage;
  final us = [
    for (final u in s.units)
      if (duelMayUse(p, u)) u,
  ];
  final seen = <String>{};
  final out = <DuelStep>[];
  void add(DuelStep step) {
    if (seen.add(step.next.board)) out.add(step);
  }

  for (var ai = 0; ai < b.altars; ai++) {
    for (var i = 0; i < us.length; i++) {
      for (var j = i + 1; j < us.length; j++) {
        final f = altarFuse(b, s, ai, us[i], us[j]);
        if (f == null) continue;
        final pair = ([us[i].name, us[j].name]..sort()).join(' + ');
        add(
          DuelStep(
            f.fusedUp
                ? '$pair → ${f.made.name} on circle ${ai + 1}, meets '
                      '${f.met} → ${f.landed.name}'
                : '$pair → ${f.made.name} on circle ${ai + 1}',
            duelAfter(p, f.state),
            fusion: f,
            altar: ai,
            pair: (us[i], us[j]),
          ),
        );
      }
    }
  }
  if (b.split) {
    for (final u in us) {
      if (p.sideOf(u) != p.toMove) continue;
      final sp = altarSplit(s, u);
      if (sp != null) {
        add(DuelStep('split ${u.name}', duelAfterSplit(p, sp.$1, u), split: u));
      }
    }
  }
  if (out.isEmpty) {
    out.add(DuelStep(kDuelPass, DuelPosition(s, p.side, turns: p.turns + 1)));
  }
  return out;
}

/// How a match ended.
enum DuelEnd { firstWins, secondWins, draw }

extension DuelEndSide on DuelEnd {
  /// The winning side, or null for a draw.
  int? get winner => switch (this) {
    DuelEnd.firstWins => 0,
    DuelEnd.secondWins => 1,
    DuelEnd.draw => null,
  };
}

/// A word made, and whose: only its own side can make it, so one move only
/// ever makes one.
(AltarUnit, int)? duelWordOnStage(DuelBoard b, DuelPosition p) {
  for (final u in p.stage.units) {
    final s = p.sideOf(u);
    if (s != kDuelMiddle && b.isWord(s, u)) return (u, s);
  }
  return null;
}

/// Whether the match is over at [p], and how; null while it goes on.
DuelEnd? duelOutcome(DuelBoard b, DuelPosition p) {
  final w = duelWordOnStage(b, p);
  if (w != null) return w.$2 == 0 ? DuelEnd.firstWins : DuelEnd.secondWins;
  if (p.turns >= kDuelMoveCap) return DuelEnd.draw;
  // Neither side can move: the last turn was a pass, and this one would be.
  if (duelSteps(b, p).first.pass && _passed(b, p)) return DuelEnd.draw;
  return null;
}

bool _passed(DuelBoard b, DuelPosition p) {
  final other = DuelPosition(p.stage, p.side, turns: p.turns + 1);
  return duelSteps(b, other).first.pass;
}

// ── THE PROOF ──────────────────────────────────────────────

/// The match played perfectly from a position, by both sides.
class DuelSolver {
  DuelSolver(this.board);
  final DuelBoard board;

  /// Position key → its value for the first side: 1 it wins, -1 it loses,
  /// 0 a draw.
  final Map<String, int> _memo = {};

  int get positions => _memo.length;

  /// [p]'s value with perfect play: 1 the first side wins, -1 the second
  /// does, 0 neither can force it.
  int value(DuelPosition p) {
    final k = p.key;
    final had = _memo[k];
    if (had != null) return had;
    final end = duelOutcome(board, p);
    final int v;
    if (end != null) {
      v = switch (end) {
        DuelEnd.firstWins => 1,
        DuelEnd.secondWins => -1,
        DuelEnd.draw => 0,
      };
    } else {
      final best = p.toMove == 0 ? 1 : -1;
      var got = -best;
      for (final s in duelSteps(board, p)) {
        final w = value(s.next);
        if (p.toMove == 0 ? w > got : w < got) got = w;
        if (got == best) break;
      }
      v = got;
    }
    _memo[k] = v;
    return v;
  }

  /// Each move [p]'s side may make, with the value it leaves.
  List<(DuelStep, int)> graded(DuelPosition p) => [
    for (final s in duelSteps(board, p)) (s, value(s.next)),
  ];
}
