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
/// Each tree draws a figure. Alchemy stands in rows by tier, rising from
/// the root, each row centred; a stone whose parent is on its own row
/// stands one column further out than its parent. Combat is a four-point
/// star ([_combatStar]) and Explorer a key lying on its side
/// ([_explorerKey]).
Map<String, Offset> constellationTreeLayout(ConstellationTree tree) {
  switch (tree) {
    case ConstellationTree.combat:
      return _combatStar();
    case ConstellationTree.extraction:
      return {..._explorerKey.stones};
    case ConstellationTree.breeder:
      break;
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

/// Combat's four-point star: a point a stat (Strength up, Intelligence
/// right, Beauty down, Speed left), all four the same, so no stat looks the
/// favoured one. A stat's I and II climb one edge of its point from the
/// waist, III is the tip, and IV and V come down the other edge; the
/// combat verse sits in the open middle.
Map<String, Offset> _combatStar() {
  const tip = 520.0, waist = 215.0;
  // How far along an edge, waist to tip, I and II stand: spaced so no two
  // stones crowd, across a waist corner or across a tip.
  const atI = 0.19, atII = 0.545;

  double angleOf(ConstellationSkill s) {
    final id = s.id;
    if (id.startsWith('combat_int_')) return 0;
    if (id.startsWith('combat_beauty_')) return math.pi / 2;
    if (id.startsWith('combat_speed_')) return math.pi;
    return -math.pi / 2;
  }

  Offset polar(double r, double a) =>
      Offset(math.cos(a) * r, math.sin(a) * r);

  final out = <String, Offset>{};
  for (final s in ConstellationCatalog.forTree(ConstellationTree.combat)) {
    final a = angleOf(s);
    final point = polar(tip, a);
    final climbFrom = polar(waist, a - math.pi / 4);
    final comeTo = polar(waist, a + math.pi / 4);
    out[s.id] = switch (s.tier) {
      1 => Offset.lerp(climbFrom, point, atI)!,
      2 => Offset.lerp(climbFrom, point, atII)!,
      3 => point,
      4 => Offset.lerp(comeTo, point, atII)!,
      _ => Offset.lerp(comeTo, point, atI)!,
    };
  }
  return out;
}

/// Explorer's key, lying on its side and centred on the tree's centre. The
/// first stone is the tooth, hung under the far end of the shaft; the
/// shaft runs to the bow, with Batch Extraction the collar over its last
/// stone; the 24/7 Black Market opens the bow, and the sale and XP stones
/// run round it, over and under. The verse is written on two plates: one
/// over the shaft, one inside the bow.
final ({Map<String, Offset> stones, Offset shaftVerse, Offset bowVerse})
_explorerKey = () {
  const bow = 190.0, step = 150.0, tooth = 170.0, collar = 160.0;
  const round = 2 * math.pi / 7;
  final shaft = [
    ConstellationCatalog.instantReload,
    ConstellationCatalog.wildernessPreview,
    ConstellationCatalog.resourceAlchemy,
    ConstellationCatalog.marketplaceInsight,
  ];
  final over = [
    ConstellationCatalog.salePriceBoost1,
    ConstellationCatalog.salePriceBoost2,
    ConstellationCatalog.salePriceBoost3,
  ];
  final under = [
    ConstellationCatalog.xpBoost1,
    ConstellationCatalog.xpBoost2,
    ConstellationCatalog.xpBoost3,
  ];
  // Laid out round the bow's centre, then moved so the key is centred.
  final at = <String, Offset>{
    ConstellationCatalog.allDayBlackMarket.id: const Offset(-bow, 0),
    for (var i = 0; i < shaft.length; i++)
      shaft[i].id: Offset(-bow - step * (i + 1), 0),
    for (var i = 0; i < 3; i++) ...{
      over[i].id: Offset(
        bow * math.cos(math.pi + round * (i + 1)),
        bow * math.sin(math.pi + round * (i + 1)),
      ),
      under[i].id: Offset(
        bow * math.cos(math.pi - round * (i + 1)),
        bow * math.sin(math.pi - round * (i + 1)),
      ),
    },
  };
  final end = at[ConstellationCatalog.marketplaceInsight.id]!;
  at[ConstellationCatalog.alchemonExchange.id] = end + const Offset(0, tooth);
  at[ConstellationCatalog.batchExtraction.id] =
      at[ConstellationCatalog.instantReload.id]! + const Offset(0, -collar);

  final bounds = at.values
      .map((p) => Rect.fromCircle(center: p, radius: 0))
      .reduce((a, b) => a.expandToInclude(b));
  final shift = -bounds.center;
  return (
    stones: {for (final e in at.entries) e.key: e.value + shift},
    // Over the middle of the shaft, clear of the collar.
    shaftVerse: Offset(end.dx + step * 1.5, -125) + shift,
    bowVerse: shift,
  );
}();

/// Where the Explorer key's two verse plates sit, from the tree's centre.
({Offset shaft, Offset bow}) explorerKeyVerseSpots() =>
    (shaft: _explorerKey.shaftVerse, bow: _explorerKey.bowVerse);

/// Where each stone of every tree stands on the chart.
Map<String, Offset> constellationChartLayout() => {
  for (final tree in ConstellationTree.values)
    for (final e in constellationTreeLayout(tree).entries)
      e.key: kConstellationTreeCentres[tree]! + e.value,
};
