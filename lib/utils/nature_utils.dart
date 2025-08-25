import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/nature.dart';

double hatchMultForNature(String? natureId) {
  if (natureId == null || natureId.isEmpty) return 1.0;
  final n = NatureCatalog.byId(natureId);
  final v = (n?.effect['egg_hatch_time_mult'])?.toDouble();
  // guardrails so nobody sets something wild in data
  return (v ?? 1.0).clamp(0.5, 2.0);
}

double natureMult(NatureDef? n, String key) {
  final v = n?.effect[key];
  if (v is num) return v.toDouble();
  return 1.0;
}

double combinedNatureMult(Creature p1, Creature p2, String key) {
  final m = natureMult(p1.nature, key) * natureMult(p2.nature, key);
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
    final mult = natureMult(
      p.nature,
      'breed_same_type_chance_mult',
    ); // e.g. 1.25 or 0.75
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
