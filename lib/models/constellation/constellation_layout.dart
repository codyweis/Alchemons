// lib/models/constellation/constellation_layout.dart
//
// Where each stone stands on the constellation chart. The chart game lays
// its stones out by this, and the home biome's night sky draws the
// player's constellations from it, so the figures overhead are the same
// shapes as on the chart.

import 'dart:math' as math;
import 'dart:ui';

import 'package:alchemons/models/constellation/constellation_catalog.dart';

/// Each tree's centre on the chart.
const Map<ConstellationTree, Offset> kConstellationTreeCentres = {
  ConstellationTree.breeder: Offset(0, -600),
  ConstellationTree.combat: Offset(-700, 400),
  ConstellationTree.extraction: Offset(700, 400),
};

/// Rows of a tree are this far apart, stones in a row this far.
const double kConstellationRowGap = 180;
const double kConstellationColumnGap = 220;

/// Where each stone of [tree] stands, from the tree's own centre.
///
/// The Alchemy and Explorer trees stand in rows by tier, rising from the
/// root, each row centred; a stone whose parent is on its own row stands
/// one column further out than its parent. Combat is a cross: four arms
/// (attack up, intellect right, beauty down, speed left), a tier a step.
Map<String, Offset> constellationTreeLayout(ConstellationTree tree) {
  if (tree == ConstellationTree.combat) {
    double angleOf(ConstellationSkill s) {
      final id = s.id;
      if (id.startsWith('combat_int_')) return 0;
      if (id.startsWith('combat_beauty_')) return math.pi / 2;
      if (id.startsWith('combat_speed_')) return math.pi;
      return -math.pi / 2;
    }

    return {
      for (final s in ConstellationCatalog.forTree(tree))
        s.id: Offset(
          math.cos(angleOf(s)) * s.tier * kConstellationRowGap,
          math.sin(angleOf(s)) * s.tier * kConstellationRowGap,
        ),
    };
  }
  final tiers = ConstellationCatalog.byTierForTree(tree);
  final maxTier = tiers.keys.reduce(math.max);
  final baseY = maxTier * kConstellationRowGap / 2;
  final out = <String, Offset>{};
  for (final e in tiers.entries) {
    final inTier = e.value;
    final rowIds = {for (final s in inTier) s.id};
    bool isSide(ConstellationSkill s) => s.prerequisites.any(rowIds.contains);
    final row = inTier.where((s) => !isSide(s)).toList();
    final gap = row.length > 1 ? kConstellationColumnGap : 0.0;
    final startX = -(row.length - 1) * gap / 2;
    final xOf = <String, double>{
      for (var i = 0; i < row.length; i++) row[i].id: startX + i * gap,
    };
    for (final side in inTier.where(isSide)) {
      final parentX = xOf[side.prerequisites.firstWhere(rowIds.contains)] ?? 0;
      xOf[side.id] =
          parentX +
          (parentX < 0 ? -kConstellationColumnGap : kConstellationColumnGap);
    }
    for (final s in inTier) {
      out[s.id] = Offset(xOf[s.id]!, baseY - e.key * kConstellationRowGap);
    }
  }
  return out;
}

/// Where each stone of every tree stands on the chart.
Map<String, Offset> constellationChartLayout() => {
  for (final tree in ConstellationTree.values)
    for (final e in constellationTreeLayout(tree).entries)
      e.key: kConstellationTreeCentres[tree]! + e.value,
};
