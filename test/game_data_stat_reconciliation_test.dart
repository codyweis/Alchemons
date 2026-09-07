import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'existing saves reconcile every current stat from canonical inputs',
    () async {
      final db = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final catalog = CreatureCatalog.fromList([
        Creature(
          id: 'RECON01',
          name: 'Reconcilemon',
          types: const ['Light'],
          rarity: 'Rare',
          description: 'Test creature',
          image: 'test.png',
          baseStats: const SpeciesBaseStats(
            speed: 100,
            intelligence: 80,
            strength: 60,
            beauty: 40,
          ),
        ),
      ]);

      await db.creatureDao.insertInstance(
        instanceId: 'legacy-instance',
        baseId: 'RECON01',
        level: 10,
        natureId: 'Swift',
        statSpeed: 5,
        statIntelligence: 5,
        statStrength: 5,
        statBeauty: 5,
        statSpeedPotential: 100,
        statIntelligencePotential: 80,
        statStrengthPotential: 60,
        statBeautyPotential: 40,
        statSpeedEnhancement: 10,
        statIntelligenceEnhancement: 7,
        statStrengthEnhancement: 4,
        statBeautyEnhancement: 1,
      );

      await GameDataService(db: db, catalog: catalog).init();
      final reconciled = await db.creatureDao.getInstance('legacy-instance');

      double expected(int base, int potential, int rank, String key) =>
          AlchemonStatSystem.effectiveInternal(
            speciesBase: base,
            level: 10,
            potential: potential,
            enhancementRank: rank,
            additionalMultiplier: AlchemonStatSystem.natureMultiplier(
              'Swift',
              key,
            ),
          );

      expect(reconciled, isNotNull);
      expect(
        reconciled!.statSpeed,
        closeTo(expected(100, 100, 10, 'speed'), 1e-9),
      );
      expect(
        reconciled.statIntelligence,
        closeTo(expected(80, 80, 7, 'intelligence'), 1e-9),
      );
      expect(
        reconciled.statStrength,
        closeTo(expected(60, 60, 4, 'strength'), 1e-9),
      );
      expect(
        reconciled.statBeauty,
        closeTo(expected(40, 40, 1, 'beauty'), 1e-9),
      );
      expect(reconciled.statSpeed, greaterThan(5));
    },
  );
}
