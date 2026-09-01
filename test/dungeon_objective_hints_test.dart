// The room you walk into does not tell you how to solve it.
//
// §5.6 splits the voices: the entry line says WHAT the place is and what
// state it is in, and the METHOD belongs to a Mask reading. The line is easy
// to cross by accident — a helpful second clause, and the puzzle is answered
// on the way through the door. Air's ring room was doing it twice (its entry
// line AND its refusal both said "seal the orbit when the three gather"),
// Air's loom said "match it with the echo it describes", and Earth's eye
// chamber said "set the stones, then ask the eye at its prism".
//
// So this reads every *ObjectiveHint in the game and fails on the grammar
// those three share: a clause after a dash or a semicolon that OPENS with a
// bare imperative — the shape of an instruction rather than a description.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Verbs that, at the head of a clause, are the game telling you what to do.
const _imperatives = {
  'set', 'match', 'seal', 'catch', 'pin', 'bring', 'use', 'melt', 'cool',
  'carry', 'plant', 'light', 'dam', 'raise', 'swing', 'drag', 'haul',
  'steady', 'channel', 'gust', 'wake', 'stand', 'place', 'lay', 'burn',
  'freeze', 'thaw', 'quench', 'breach', 'feed', 'offer', 'hang', 'toll',
  'pour', 'sink', 'climb', 'push', 'pull', 'hold', 'read', 'sing', 'build',
  'ask', 'open', 'close', 'turn', 'strike', 'find', 'take', 'give', 'walk',
};

/// The guardian rooms all wear the same combat readout — "face X: calm it, or
/// strike in its lulls". That is a fight's rules, not a puzzle's answer, and
/// it is deliberately identical on every planet. Anything else has to earn
/// its exemption here, in writing.
bool _isGuardianReadout(String line) =>
    line.contains(': calm it, or strike in its lulls');

void main() {
  final files = Directory('lib/games/planet_dungeon')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  /// Every string literal inside a *ObjectiveHint body, with adjacent
  /// literals joined so multi-line copy reads as one sentence.
  List<(String, String)> objectiveLines() {
    final out = <(String, String)>[];
    final fn = RegExp(r"String\?\s+_\w*[Oo]bjectiveHint\(DungeonRoom room\)");
    for (final f in files) {
      final src = f.readAsStringSync();
      for (final m in fn.allMatches(src)) {
        var i = src.indexOf('{', m.start);
        var depth = 0;
        var j = i;
        while (j < src.length) {
          if (src[j] == '{') depth++;
          if (src[j] == '}') {
            depth--;
            if (depth == 0) break;
          }
          j++;
        }
        // Strip line comments first: prose in a `//` explaining a fix can
        // carry an apostrophe, and the literal-scanner would read the rest of
        // the comment as copy the game shows to players.
        final body = src
            .substring(i, j)
            .replaceAll(RegExp(r'//[^\n]*'), '')
            .replaceAll(RegExp(r"'\s*\n\s*'"), '');
        for (final lit in RegExp(r"'((?:[^'\\]|\\.){20,})'").allMatches(body)) {
          out.add((f.uri.pathSegments.last, lit.group(1)!));
        }
      }
    }
    return out;
  }

  test('there are objective lines to audit at all', () {
    // Guards the extractor: a rename that empties this list would turn every
    // assertion below into a silent pass.
    expect(objectiveLines().length, greaterThan(60));
  });

  test('no entry line hands over the method', () {
    final offenders = <String>[];
    for (final (file, line) in objectiveLines()) {
      if (_isGuardianReadout(line)) continue;
      final clauses = line.split(RegExp(r'—|;'));
      for (var c = 1; c < clauses.length; c++) {
        final words = clauses[c].trim().toLowerCase().split(RegExp(r'\s+'));
        if (words.isEmpty) continue;
        var head = words.first.replaceAll(RegExp(r'[^a-z]'), '');
        // "…, then ask the eye" — the instruction is what follows the joiner.
        if (head == 'then' && words.length > 1) {
          head = words[1].replaceAll(RegExp(r'[^a-z]'), '');
        }
        if (_imperatives.contains(head)) {
          offenders.add('$file: "$line"  → clause opens with "$head"');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'these say HOW on a channel reserved for WHAT — move it to the '
          'planet\'s Mask reading:\n${offenders.join('\n')}',
    );
  });
}
