// Where the chart's stones stand: every tree a figure (Alchemy in rows,
// Combat a four-point star, Explorer a key), each stone with room round it,
// and the key's verse written clear of its stones.

import 'dart:math' as math;
import 'dart:ui';

import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:alchemons/models/constellation/constellation_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every skill has a place on its tree', () {
    for (final tree in ConstellationTree.values) {
      final layout = constellationTreeLayout(tree);
      final ids = {for (final s in ConstellationCatalog.forTree(tree)) s.id};
      expect(layout.keys.toSet(), ids, reason: tree.name);
    }
  });

  test('no two stones of a tree crowd each other', () {
    // A stone is 62 across with its price chip beneath it.
    for (final tree in ConstellationTree.values) {
      final at = constellationTreeLayout(tree).entries.toList();
      for (var i = 0; i < at.length; i++) {
        for (var j = i + 1; j < at.length; j++) {
          expect(
            (at[i].value - at[j].value).distance,
            greaterThanOrEqualTo(130),
            reason: '${at[i].key} and ${at[j].key}',
          );
        }
      }
    }
  });

  test('the trees keep apart on the chart', () {
    final chart = constellationChartLayout();
    final treeOf = {
      for (final s in ConstellationCatalog.allSkills) s.id: s.tree,
    };
    for (final a in chart.entries) {
      for (final b in chart.entries) {
        if (treeOf[a.key] == treeOf[b.key]) continue;
        expect(
          (a.value - b.value).distance,
          greaterThan(250),
          reason: '${a.key} and ${b.key}',
        );
      }
    }
  });

  test("the star's four points are the same, a stat each", () {
    final star = constellationTreeLayout(ConstellationTree.combat);
    Offset turn(Offset p, double a) => Offset(
      p.dx * math.cos(a) - p.dy * math.sin(a),
      p.dx * math.sin(a) + p.dy * math.cos(a),
    );
    for (final (stat, quarter) in [('int', 1), ('beauty', 2), ('speed', 3)]) {
      for (var tier = 1; tier <= 5; tier++) {
        final strength = star['combat_atk_boost_$tier']!;
        final other = star['combat_${stat}_boost_$tier']!;
        final expected = turn(strength, quarter * math.pi / 2);
        expect((other - expected).distance, lessThan(0.01), reason: '$stat $tier');
      }
    }
  });

  test("the key's verse is written clear of its stones", () {
    final key = constellationTreeLayout(ConstellationTree.extraction);
    final spots = explorerKeyVerseSpots();
    // Inside the bow: every stone round it stands well off the middle.
    for (final p in key.values) {
      expect((p - spots.bow).distance, greaterThanOrEqualTo(150));
    }
    // Over the shaft: the plate is about 230 x 105, and no stone is under
    // it.
    final plate = Rect.fromCenter(center: spots.shaft, width: 230, height: 105);
    for (final e in key.entries) {
      expect(
        plate.inflate(31).contains(e.value),
        isFalse,
        reason: e.key,
      );
    }
  });
}
