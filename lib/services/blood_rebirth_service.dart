import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/services/campaign_journal_service.dart';
import 'package:drift/drift.dart';

class BloodRebirthService {
  BloodRebirthService(this.db);
  final AlchemonsDatabase db;
  static const potential = 95.0;

  /// Transform the same living instance. Never clone it, delete it, or reset
  /// its training. The completion marker and aura grant commit with the change.
  Future<void> transform(String instanceId, Creature species) => db.transaction(
    () async {
      if ((await db.settingsDao.getSetting(CampaignJournalService.endingKey) ??
              '')
          .isNotEmpty) {
        return;
      }
      final instance = await db.creatureDao.getInstance(instanceId);
      if (instance == null || instance.baseId != species.id) {
        throw StateError('The chosen companion is no longer available.');
      }
      final base = species.baseStats;
      double stat(String key, int? points, int enhancement) =>
          AlchemonStatSystem.effectiveInternal(
            speciesBase: points ?? 60,
            level: instance.level,
            potential: potential,
            enhancementRank: enhancement,
            additionalMultiplier: AlchemonStatSystem.natureMultiplier(
              instance.natureId,
              key,
              instance.natureId2,
            ),
          );
      await (db.update(
        db.creatureInstances,
      )..where((t) => t.instanceId.equals(instanceId))).write(
        CreatureInstancesCompanion(
          variantFaction: const Value('bloodborn'),
          statSpeedPotential: const Value(potential),
          statIntelligencePotential: const Value(potential),
          statStrengthPotential: const Value(potential),
          statBeautyPotential: const Value(potential),
          statSpeed: Value(
            stat('speed', base?.speed, instance.statSpeedEnhancement),
          ),
          statIntelligence: Value(
            stat(
              'intelligence',
              base?.intelligence,
              instance.statIntelligenceEnhancement,
            ),
          ),
          statStrength: Value(
            stat('strength', base?.strength, instance.statStrengthEnhancement),
          ),
          statBeauty: Value(
            stat('beauty', base?.beauty, instance.statBeautyEnhancement),
          ),
        ),
      );
      await db.inventoryDao.addItemQty(InvKeys.alchemyBloodAura, 1);
      await db.settingsDao.setSetting(
        CampaignJournalService.endingKey,
        instanceId,
      );
      await CampaignJournalService(db).record('ending');
    },
  );
}
