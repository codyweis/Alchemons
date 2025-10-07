// lib/constants/unlock_costs.dart
import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/models/harvest_biome.dart';

/// Centralized unlock costs for biomes & shop items.
/// All maps returned are already in DB settings-key space (e.g. res_fire).
class UnlockCosts {
  // Biome unlock costs
  static final Map<Biome, Map<String, int>> _biomeByElementNames = {
    Biome.volcanic: {'Water': 60},
    Biome.oceanic: {'Fire': 60, 'Water': 0, 'Air': 40, 'Earth': 40},
    Biome.earthen: {'Fire': 40, 'Water': 40, 'Air': 60, 'Earth': 0},
    Biome.verdant: {'Fire': 40, 'Water': 60, 'Air': 0, 'Earth': 40},
    Biome.arcane: {'Fire': 80, 'Water': 80, 'Air': 80, 'Earth': 80},
  };

  /// Biome unlock cost in DB keys (e.g. {'res_fire': X, ...})
  static Map<String, int> biome(Biome b) =>
      ElementResources.costByElements(_biomeByElementNames[b]!);

  /// Bubble slot unlock costs (DB keys)
  static Map<String, int> bubbleSlot(int n) {
    switch (n) {
      case 2:
        return ElementResources.costByElements({
          'Fire': 60,
          'Water': 60,
          'Air': 60,
          'Earth': 60,
        });
      case 3:
        return ElementResources.costByElements({
          'Fire': 140,
          'Water': 140,
          'Air': 140,
          'Earth': 140,
        });
      default:
        return const {};
    }
  }
}
