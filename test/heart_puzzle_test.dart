// THE ALTARS, proved — the rules against the dungeon's own Heart, the family
// table against breeding's, and every level against its recorded proof.

import 'dart:convert';
import 'dart:io';

import 'package:alchemons/games/heart_puzzle/heart_puzzle_levels.dart';
import 'package:alchemons/games/heart_puzzle/heart_puzzle_rules.dart';
import 'package:alchemons/services/breeding_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the dungeon\'s Heart, without its stage, is still seven moves and one way', () {
    const heart = AltarLevel(
      goal: 'Blood',
      hand: ['Fire', 'Water', 'Earth', 'Air'],
      columns: [
        [],
        ['Spirit'],
        ['Spirit', 'Lava'],
        ['Earth'],
      ],
      split: true,
      par: 7,
    );
    final p = altarSolve(heart);
    expect(p.solvable, isTrue);
    expect(p.par, 7);
    expect(p.unique, isTrue, reason: p.plan.join('\n'));
  });

  test('family outcomes are breeding\'s own', () {
    final map =
        json.decode(
              File('assets/data/alchemons_family_recipes.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final raw = (map['recipes'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(
        k,
        (v as Map<String, dynamic>).map(
          (kk, vv) => MapEntry(FamilyRecipeConfig.norm(kk), (vv as num).toInt()),
        ),
      ),
    );
    final cfg = FamilyRecipeConfig.fromRaw(raw);
    for (final a in kAltarFamilies) {
      for (final b in kAltarFamilies) {
        final row = cfg.recipeFor(a, b);
        final can = kFamilyOutcomes[familyKey(a, b)]!;
        if (row == null) {
          // Same family sticks; otherwise one of the parents.
          expect(can.toSet(), {a, b}, reason: '$a+$b');
          continue;
        }
        expect(can.toSet(), row.keys.where((f) => f != 'Mystic').toSet(), reason: '$a+$b');
        final top = kTopNewFamily[familyKey(a, b)];
        expect(top, isNotNull, reason: '$a+$b');
        final best = row.entries
            .where((e) => e.key != a && e.key != b)
            .fold<int>(0, (m, e) => e.value > m ? e.value : m);
        expect(row[top], best, reason: '$a+$b → $top is the likeliest new family');
        expect(can, contains(top), reason: '$a+$b');
      }
    }
  });

  test('the chapters run 1 to the last level with no gaps', () {
    var next = 1;
    for (final c in kAltarChapters) {
      expect(c.first, next, reason: c.name);
      expect(c.last, greaterThanOrEqualTo(c.first), reason: c.name);
      next = c.last + 1;
    }
    expect(next - 1, kAltarLevels.length);
  });

  for (var i = 0; i < kAltarLevels.length; i++) {
    final l = kAltarLevels[i];
    test('level ${i + 1}: par ${l.par}, one way', () {
      expect(
        l.hand.map((h) => parseSpecies(h).$1),
        isNot(contains(l.goal)),
        reason: 'the goal is not in hand',
      );
      final p = altarSolve(l);
      expect(p.solvable, isTrue);
      expect(p.par, l.par, reason: p.plan.join('\n'));
      expect(p.unique, isTrue, reason: p.plan.join('\n'));
      // No action repeated: the same pair making the same thing twice.
      final fusions = [
        for (final m in p.plan) m.replaceAll(RegExp(r' on altar \d+.*'), ''),
      ];
      expect(fusions.toSet(), hasLength(fusions.length), reason: p.plan.join('\n'));
      if (!l.species) return;
      // No two families breeding has no recipe for can ever meet.
      final seen = <String>{};
      var layer = [altarStart(l)];
      seen.add(layer.first.key);
      while (layer.isNotEmpty && seen.length < 150000) {
        final next = <AltarState>[];
        for (final s in layer) {
          final us = s.units;
          for (var a = 0; a < us.length; a++) {
            for (var b = a + 1; b < us.length; b++) {
              if (altarRecipe(us[a].el, us[b].el) == null) continue;
              expect(
                l.familyOf(us[a].fam, us[b].fam),
                isNotNull,
                reason: '${us[a].fam}+${us[b].fam} can meet',
              );
              for (var ai = 0; ai < l.altars; ai++) {
                final f = altarFuse(l, s, ai, us[a], us[b])!;
                if (seen.add(f.state.key)) next.add(f.state);
              }
            }
          }
          if (l.split) {
            for (final u in us) {
              final sp = altarSplit(s, u);
              if (sp != null && seen.add(sp.$1.key)) next.add(sp.$1);
            }
          }
        }
        layer = next;
      }
      expect(layer, isEmpty, reason: 'everything reachable was seen');
    });
  }
}
