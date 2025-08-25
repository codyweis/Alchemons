import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/creature_instance_service.dart';
import 'package:drift/drift.dart';

import '../services/game_data_service.dart';
import '../database/alchemons_db.dart';
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

  /// Try to breed two creatures, unlock the species, and persist an instance.
  /// Returns summary including instanceId & finalize status for UI.
  Future<Map<String, dynamic>?> breed(
    String parent1Id,
    String parent2Id,
  ) async {
    final result = engine.breed(parent1Id, parent2Id);
    if (!result.success || result.creature == null) return null;

    final child = result.creature!;

    // 1) Unlock species in dex
    await _unlockCreature(child.id);

    // 2) Persist a player-owned instance (enforces per-species cap)
    final finalize = await _manageCreatureInstances(child);

    // 3) Track newly discovered runtime variant (for your compendium)
    if (result.variantUnlocked != null) {
      await gameData.addDiscoveredVariant(result.variantUnlocked!);
    }

    // 4) Return compact payload for UI (show new instance or handle "full")
    return {
      'status': finalize.status.name, // created | speciesFull | failed
      'instanceId': finalize.instanceId, // null unless created
      'id': child.id, // species id
      'name': child.name,
      'types': child.types,
      'rarity': child.rarity,
      'isPrismatic': child.isPrismaticSkin,
      'natureId': child.nature?.id,
      'genetics': child.genetics?.variants,
      'variantUnlocked': result.variantUnlocked == null
          ? null
          : {
              'id': result.variantUnlocked!.id,
              'name': result.variantUnlocked!.name,
              'types': result.variantUnlocked!.types,
              'rarity': result.variantUnlocked!.rarity,
            },
    };
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Creature instance management
  // ────────────────────────────────────────────────────────────────────────────
  Future<InstanceFinalizeResult> _manageCreatureInstances(
    Creature child,
  ) async {
    final svc = CreatureInstanceService(db);
    final resp = await svc.finalizeInstance(
      baseId: child.id,
      rarity: child.rarity,
      natureId: child.nature?.id,
      genetics: child.genetics?.variants,
      parentage: child.parentage?.toJson(),
      isPrismaticSkin: child.isPrismaticSkin,
    );

    // You can also surface UX here (toasts/analytics) if you want.
    return resp;
  }

  /// Unlock species if not already discovered in the dex.
  Future<void> _unlockCreature(String id) async {
    final existing = await db.getCreature(id);
    if (existing == null || existing.discovered == false) {
      await db.addOrUpdateCreature(
        PlayerCreaturesCompanion(id: Value(id), discovered: const Value(true)),
      );
    }
  }
}
