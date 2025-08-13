import '../services/game_data_service.dart';
import '../database/alchemons_db.dart';
import 'package:drift/drift.dart';
import 'breeding_engine.dart';

class BreedingService {
  final GameDataService gameData;
  final AlchemonsDatabase db;
  final BreedingEngine engine;

  BreedingService({
    required this.gameData,
    required this.db,
    required this.engine,
  });

  /// Try to breed two creatures and unlock them in DB
  Future<Map<String, dynamic>?> breed(
    String parent1Id,
    String parent2Id,
  ) async {
    final result = engine.breed(parent1Id, parent2Id);
    if (!result.success || result.creature == null) return null;

    final creature = result.creature!;
    await _unlockCreature(creature.id);

    // Handle variant discovery
    if (result.variantUnlocked != null) {
      final variant = result.variantUnlocked!;

      // Use GameDataService to add the variant (this handles both DB and memory)
      await gameData.addDiscoveredVariant(variant);
    }

    return {
      'id': creature.id,
      'name': creature.name,
      'types': creature.types,
      'rarity': creature.rarity,
      'variantUnlocked': result.variantUnlocked != null
          ? {
              'id': result.variantUnlocked!.id,
              'name': result.variantUnlocked!.name,
              'types': result.variantUnlocked!.types,
              'rarity': result.variantUnlocked!.rarity,
            }
          : null,
    };
  }

  /// Unlock creature if not already discovered
  Future<void> _unlockCreature(String id) async {
    final existing = await db.getCreature(id);
    if (existing == null || existing.discovered == false) {
      await db.addOrUpdateCreature(
        PlayerCreaturesCompanion(id: Value(id), discovered: const Value(true)),
      );
    }
  }
}
