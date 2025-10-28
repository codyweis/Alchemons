// lib/constants/unlock_costs.dart
import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/models/harvest_biome.dart';

/// Centralized unlock costs for biomes & other features.
/// All public methods return maps in DB settings-key space
/// (e.g. {'res_volcanic': 60}).
class UnlockCosts {
  // High-level design note:
  //
  // We now price everything directly in biome currencies.
  // Keys here are biomeIds that match Biome.id:
  //   'volcanic', 'oceanic', 'earthen', 'verdant', 'arcane'
  //
  // Then we convert those biomeIds into actual settings keys
  // ('res_volcanic', etc.) before returning.

  static final Map<Biome, Map<String, int>> _biomeByBiomeId = {
    // Example tuning below. Adjust numbers however you want.
    // The idea is: to unlock a biome, the player might need
    // some of OTHER biomes' resources so you're gated by progression.
    Biome.volcanic: {
      // Maybe volcanic is first/cheap?
      // e.g. needs a little Oceanic to cool vents:
      'oceanic': 60,
    },

    Biome.oceanic: {
      // Needs Volcanic + Earthen to stabilize turbines, etc.
      'volcanic': 60,
    },

    Biome.earthen: {'volcanic': 40, 'oceanic': 40, 'verdant': 60, 'earthen': 0},

    Biome.verdant: {'volcanic': 40, 'oceanic': 60, 'earthen': 40, 'verdant': 0},

    Biome.arcane: {
      // late-game, wants a chunk of everything:
      'volcanic': 80,
      'oceanic': 80,
      'earthen': 80,
      'verdant': 80,
      'arcane': 80,
    },
  };

  /// Returns cost map using DB keys like 'res_volcanic'.
  static Map<String, int> biome(Biome b) {
    final raw = _biomeByBiomeId[b]!;
    return ElementResources.costByBiome(raw);
  }

  /// Bubble slot unlock costs (DB keys).
  /// Previously this charged Fire/Water/Air/Earth evenly.
  /// Now we charge across the 5 biome currencies.
  static Map<String, int> bubbleSlot(int n) {
    switch (n) {
      case 2:
        return ElementResources.costByBiome({
          'volcanic': 60,
          'oceanic': 60,
          'earthen': 60,
          'verdant': 60,
          'arcane': 60,
        });
      case 3:
        return ElementResources.costByBiome({
          'volcanic': 140,
          'oceanic': 140,
          'earthen': 140,
          'verdant': 140,
          'arcane': 140,
        });
      default:
        return const {};
    }
  }
}
