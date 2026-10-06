// THE HEART, proved — the fifth rite's rules against the prototype's proof
// (docs/prototypes/blood_rites/proofs.txt) and the game's own recipe table.

import 'dart:convert';
import 'dart:io';

import 'package:alchemons/games/planet_dungeon/planet_dungeon_blood_heart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the recipe copy is the game\'s own table (main result only)', () {
    final table =
        (jsonDecode(File('assets/data/alchemons_element_recipes.json').readAsStringSync())
                as Map<String, dynamic>)['recipes']
            as Map<String, dynamic>;
    String cap(String s) => s[0].toUpperCase() + s.substring(1);
    var pairs = 0;
    for (final e in table.entries) {
      if (!e.key.contains('+')) continue;
      pairs++;
      final [a, b] = e.key.split('+').map(cap).toList();
      final odds = (e.value as Map<String, dynamic>).entries.toList()
        ..sort((p, q) => (q.value as num).compareTo(p.value as num));
      expect(heartRecipe(a, b), cap(odds.first.key), reason: '$a+$b');
    }
    expect(pairs, kHeartRecipes.length);
    expect(heartRecipe('Light', 'Dark'), 'Blood');
  });

  test('the proof: five fusions and two splits, and only the one way', () {
    final p = heartSolve(heartRoom());
    expect(p.solvable, isTrue);
    expect(p.fusions, 5);
    expect(p.splits, 2);
    expect(p.plan, [
      'Fire+Air→Lightning on altar 4, meets Earth→Crystal',
      'split Crystal',
      'Earth+Lightning→Crystal on altar 3, meets Spirit→Light',
      'Water+Earth→Mud on altar 3, meets Lava→Poison',
      'split Poison',
      'Mud+Lava→Poison on altar 2, meets Spirit→Dark',
      'Light+Dark→Blood on altar 1',
    ]);
  });

  test('impossible without the split stage', () {
    final r = HeartRoom(
      [for (final row in kHeartMap) row.replaceAll('S', '.')],
      altars: kHeartAltars,
      holds: kHeartHolds,
    );
    expect(heartSolve(r).solvable, isFalse);
  });

  test('every element hanging there is needed', () {
    for (final k in kHeartHolds.keys) {
      final [x, y] = k.split(',').map(int.parse).toList();
      final map = [
        for (var j = 0; j < kHeartMap.length; j++)
          j == y ? kHeartMap[j].replaceRange(x, x + 1, 'v') : kHeartMap[j],
      ];
      final holds = Map.of(kHeartHolds)..remove(k);
      final r = HeartRoom(map, altars: kHeartAltars, holds: holds);
      expect(heartSolve(r).solvable, isFalse, reason: 'without the ${kHeartHolds[k]} at $k');
    }
  });

  test('what rises fuses with what hangs there, by the recipe table only', () {
    final r = heartRoom();
    var s = heartStart(r);
    HeartUnit u(String el) => s.units.firstWhere((x) => x.el == el);
    // Air + Fire on altar 4: Lightning rises into the Earth; Crystal comes
    // down to the altar, and the Earth is gone from up there.
    final f = heartFuse(r, s, 3, u('Air'), u('Fire'))!;
    expect(f.made.el, 'Lightning');
    expect(f.run.hanging, 'Earth');
    expect(f.landed.el, 'Crystal');
    expect(f.landed.at, r.altars[3].front);
    expect(f.state.cells[4][11], 'v');
    // The split stage gives back what rose and what hung there.
    final (s2, p, q) = heartSplit(r, f.state, f.landed, r.splits.first)!;
    expect({p.el, q.el}, {'Lightning', 'Earth'});
    expect(s2.units.where((x) => x.el == 'Earth'), hasLength(2));
    s = heartStart(r);
    // Earth + Water on altar 2: Mud meets the Spirit; they make nothing, so
    // the Mud just comes back down, and the Spirit stays.
    final g = heartFuse(r, s, 1, u('Earth'), u('Water'))!;
    expect(g.run.hanging, 'Spirit');
    expect(g.run.fuses, isFalse);
    expect(g.landed.el, 'Mud');
    expect(g.state.cells[4][5], kHeartHanging);
    // Over altar 1 nothing hangs.
    final h = heartFuse(r, s, 0, u('Fire'), u('Water'))!;
    expect(h.run.hit, isNull);
    expect(h.landed.el, 'Steam');
    // Two with no recipe don't fuse.
    expect(heartFuse(r, s, 0, u('Earth'), h.made), isNull, reason: 'Earth+Steam is nothing');
  });
}
