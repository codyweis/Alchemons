import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/nature.dart';

const String guaranteeSecondNatureInheritanceKey =
    'guarantee_second_nature_inheritance';

/// The protected second Nature for a parent carrying a Hereditary-style
/// effect in either slot. Null means that parent has nothing to guarantee.
NatureDef? guaranteedSecondNature(Creature parent) {
  final second = parent.nature2;
  if (second == null) return null;
  final guarantees = [parent.nature, parent.nature2].any(
    (nature) => (nature?.effect[guaranteeSecondNatureInheritanceKey] ?? 0) > 0,
  );
  return guarantees ? second : null;
}

double saleValueMultiplierForNatures(String? natureId, String? natureId2) {
  var multiplier = 1.0;
  for (final id in {natureId, natureId2}) {
    if (id == null || id.isEmpty) continue;
    multiplier *=
        NatureCatalog.byId(
          id,
        )?.effect.getDouble('sale_value_mult', fallback: 1.0) ??
        1.0;
  }
  return multiplier.clamp(1.0, 2.25);
}

double wildFusionStabilityBonusForNatures(String? natureId, String? natureId2) {
  var bonus = 0.0;
  for (final id in [natureId, natureId2]) {
    if (id == null || id.isEmpty) continue;
    bonus +=
        NatureCatalog.byId(
          id,
        )?.effect.getDouble('wild_fusion_stability_add', fallback: 0) ??
        0;
  }
  return bonus.clamp(0.0, 0.10);
}

double hatchMultForNature(String? natureId) {
  return hatchMultForNatures(natureId, null);
}

double hatchMultForNatures(String? natureId, String? natureId2) {
  var result = 1.0;
  for (final id in [natureId, natureId2]) {
    if (id == null || id.isEmpty) continue;
    result *=
        NatureCatalog.byId(
          id,
        )?.effect.getDouble('egg_hatch_time_mult', fallback: 1) ??
        1;
  }
  return result.clamp(0.5, 2.0);
}

double natureMult(NatureDef? n, String key) {
  final v = n?.effect[key];
  if (v is num) return v.toDouble();
  return 1.0;
}

double combinedNatureMult(Creature p1, Creature p2, String key) {
  final m =
      natureMult(p1.nature, key) *
      natureMult(p1.nature2, key) *
      natureMult(p2.nature, key) *
      natureMult(p2.nature2, key);
  return (m.clamp(0.25, 2.0) as num).toDouble();
}

Map<String, int> applyTypeNatureBias(
  Map<String, int> weighted,
  Creature? p1,
  Creature? p2,
) {
  // Work in doubles
  final w = weighted.map((k, v) => MapEntry(k, v.toDouble()));

  void biasForParent(Creature? p) {
    if (p == null) return;
    final mult =
        natureMult(p.nature, 'breed_same_type_chance_mult') *
        natureMult(p.nature2, 'breed_same_type_chance_mult');
    final t = p.types.isNotEmpty ? p.types.first : null;
    if (t == null) return;
    if (w.containsKey(t)) {
      w[t] = (w[t]! * mult).clamp(0.0, double.infinity);
    }
  }

  biasForParent(p1);
  biasForParent(p2);

  // Convert back to ints, keep floor of 1 for any non-zero entry
  final out = <String, int>{};
  for (final e in w.entries) {
    final v = e.value.isFinite ? e.value : 0.0;
    out[e.key] = v <= 0 ? 0 : v.round().clamp(1, 1000000);
  }
  return out;
}
