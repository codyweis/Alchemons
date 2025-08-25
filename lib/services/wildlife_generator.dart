import 'dart:math';

import 'package:alchemons/helpers/genetics_loader.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/genetics.dart';
import 'package:alchemons/models/nature.dart';
import 'package:alchemons/services/breeding_engine.dart';
import 'package:alchemons/services/creature_repository.dart';

/// Tunables for wild spawns (kept close to BreedingTuning defaults)
class WildlifeTuning {
  final double prismaticSkinChance; // e.g. 0.01
  final bool excludeParentageSnapshot; // true for wild spawns
  const WildlifeTuning({
    this.prismaticSkinChance = 0.01,
    this.excludeParentageSnapshot = true,
  });
}

/// Generates a fully-hydrated Creature for wildlife:
/// - base catalog creature by speciesId
/// - fresh RNG genetics (tracks use same rules as BreedingEngine)
/// - fresh weighted nature
/// - optional prismatic flag
class WildlifeGenerator {
  final CreatureRepository repo;
  final WildlifeTuning tuning;
  final Random _rng;

  WildlifeGenerator(
    this.repo, {
    this.tuning = const WildlifeTuning(),
    Random? rng,
  }) : _rng = rng ?? Random();

  /// Main entry.
  /// rarity is passed in case you later want rarity-skewed genetics/nature;
  /// it is not required for the base hydration here.
  Creature? generate(String speciesId, {String? rarity}) {
    final base = repo.getCreatureById(speciesId);
    if (base == null) return null;

    // 1) roll genetics (fresh, no parents) to match breeding style
    final Genetics g = _rollGeneticsFor(base);

    // 2) roll nature (same catalog weighting used in breeding)
    final NatureDef n = NatureCatalogWeighted.weightedRandom(_rng);

    // 3) prismatic cosmetic flag
    final bool prism = _rng.nextDouble() < tuning.prismaticSkinChance;

    // 4) no parentage for wild
    return base.copyWith(
      genetics: g,
      nature: n,
      isPrismaticSkin: prism,
      parentage: tuning.excludeParentageSnapshot ? null : base.parentage,
    );
  }

  // ────────────────── genetics rolls (parity with BreedingEngine) ──────────────────
  Genetics _rollGeneticsFor(Creature base) {
    final chosen = <String, String>{};
    final types = base.types; // used for tint bias

    for (final track in GeneticsCatalog.all) {
      final mutates = _rng.nextDouble() < track.mutationChance;
      String resultId;

      switch (track.inheritance) {
        case 'blended':
          // draw near the middle, allow noise + occasional extreme via mutation
          final normal = _getScale(track, 'normal');
          // small gaussian-ish jiggle around normal
          final value = normal + _noise(0.0, 0.07);
          resultId = _nearestBy(
            track,
            value: value,
            read: (v) => _getScale(track, v.id),
          );
          if (mutates) resultId = _adjacentSnap(track, resultId);
          break;

        case 'weighted':
          if (track.key == 'tinting') {
            // dominance-based, biased by the creature's own element(s)
            final baseDom = {for (final v in track.variants) v.id: v.dominance};
            final biased = _applyTintBias(baseDom, types);
            resultId = _weightedPickMap(biased);
            if (mutates)
              resultId = _mutateAwayFromNormal(track, from: resultId);
          } else {
            // generic dominance weighted
            resultId = _weightedPickByDominance(track);
            if (mutates)
              resultId = _mutateAwayFromNormal(track, from: resultId);
          }
          break;

        case 'dominant_recessive':
        default:
          // with no parents, just treat like dominance-weighted
          resultId = _weightedPickByDominance(track);
          if (mutates) resultId = _mutateAwayFromNormal(track, from: resultId);
      }

      chosen[track.key] = resultId;
    }

    return Genetics(chosen);
  }

  // == helpers mirroring breeding math ==
  double _getScale(GeneTrack t, String id) {
    final v = t.byId(id);
    return (v.effect['scale'] ?? 1.0).toDouble();
  }

  double _noise(double mean, double sigma) =>
      (_rng.nextDouble() * 2 - 1) * sigma + mean;

  String _nearestBy(
    GeneTrack track, {
    required double value,
    required double Function(GeneVariant) read,
  }) {
    GeneVariant best = track.variants.first;
    double bestD = (read(best) - value).abs();
    for (final v in track.variants.skip(1)) {
      final d = (read(v) - value).abs();
      if (d < bestD) {
        best = v;
        bestD = d;
      }
    }
    return best.id;
  }

  String _adjacentSnap(GeneTrack track, String currentId) {
    final list = track.variants;
    final idx = list.indexWhere((v) => v.id == currentId);
    if (idx < 0) return currentId;
    final options = <int>[];
    if (idx > 0) options.add(idx - 1);
    if (idx + 1 < list.length) options.add(idx + 1);
    if (options.isEmpty) return currentId;
    return list[options[_rng.nextInt(options.length)]].id;
  }

  String _weightedPickByDominance(GeneTrack track) {
    final items = track.variants;
    final total = items.fold<int>(0, (sum, v) => sum + v.dominance);
    if (total <= 0) return items.first.id;
    var roll = _rng.nextInt(total);
    for (final v in items) {
      roll -= v.dominance;
      if (roll < 0) return v.id;
    }
    return items.last.id;
  }

  Map<String, double> _applyTintBias(
    Map<String, int> baseDom,
    List<String> types,
  ) {
    final w = baseDom.map((k, v) => MapEntry(k, v.toDouble()));
    for (final t in types) {
      final b = tintBiasPerType[t];
      if (b == null) continue;
      b.forEach((variantId, mult) {
        w[variantId] = (w[variantId] ?? 0) * mult;
      });
    }
    w['normal'] = (w['normal'] ?? 0).clamp(0.01, double.infinity);
    return w;
  }

  String _weightedPickMap(Map<String, double> weights) {
    final total = weights.values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return weights.keys.first;
    var roll = _rng.nextDouble() * total;
    for (final e in weights.entries) {
      roll -= e.value;
      if (roll <= 0) return e.key;
    }
    return weights.keys.last;
  }

  String _mutateAwayFromNormal(GeneTrack track, {required String from}) {
    final pool = track.variants.where((v) => v.id != 'normal').toList();
    if (pool.isEmpty) return from;
    return pool[_rng.nextInt(pool.length)].id;
  }
}
