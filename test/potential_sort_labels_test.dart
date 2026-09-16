import 'package:alchemons/database/daos/creature_dao.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Potential sort labels keep only the prefix lowercase', () {
    expect(SortBy.potentialSpeed.shortLabel, 'pSPD');
    expect(SortBy.potentialIntelligence.shortLabel, 'pINT');
    expect(SortBy.potentialStrength.shortLabel, 'pSTR');
    expect(SortBy.potentialBeauty.shortLabel, 'pBEA');
    expect(SortBy.combinedPotential.shortLabel, 'pTOTAL');
  });

  test('pTOTAL is the summed final option in the stat-sort cycle', () {
    expect(
      SortBy.potentialBeauty.nextStatSort(includePotential: true),
      SortBy.combinedPotential,
    );
    expect(SortBy.combinedPotential.isStatSort, isTrue);

    final instance = CreatureInstance(
      instanceId: 'potential-total',
      baseId: 'TST01',
      level: 1,
      xp: 0,
      locked: false,
      isPrismaticSkin: false,
      source: 'test',
      staminaMax: 3,
      staminaBars: 3,
      staminaLastUtcMs: 0,
      createdAtUtcMs: 0,
      statSpeed: 1,
      statIntelligence: 1,
      statStrength: 1,
      statBeauty: 1,
      statSpeedPotential: 10,
      statIntelligencePotential: 20,
      statStrengthPotential: 30,
      statBeautyPotential: 40,
      statSpeedEnhancement: 0,
      statIntelligenceEnhancement: 0,
      statStrengthEnhancement: 0,
      statBeautyEnhancement: 0,
      generationDepth: 0,
      isPure: false,
      isFavorite: false,
    );

    expect(SortBy.combinedPotential.valueForInstance(instance), 100);
  });
}
