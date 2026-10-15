import 'package:alchemons/database/alchemons_db.dart' as db;
import 'package:alchemons/models/wild_fusion.dart';
import 'package:alchemons/utils/harvest_rate.dart';
import 'package:flutter_test/flutter_test.dart';

db.CreatureInstance _inst({int level = 1, String? mutation}) =>
    db.CreatureInstance(
      instanceId: 'test',
      baseId: 'base',
      level: level,
      xp: 0,
      locked: false,
      isPrismaticSkin: false,
      source: 'test',
      staminaMax: 3,
      staminaBars: 3,
      staminaLastUtcMs: 0,
      createdAtUtcMs: 0,
      statSpeed: 3,
      statIntelligence: 3,
      statStrength: 3,
      statBeauty: 3,
      statSpeedPotential: 50,
      statIntelligencePotential: 50,
      statStrengthPotential: 50,
      statBeautyPotential: 50,
      statSpeedEnhancement: 0,
      statIntelligenceEnhancement: 0,
      statStrengthEnhancement: 0,
      statBeautyEnhancement: 0,
      generationDepth: 0,
      isPure: true,
      isFavorite: false,
      mutation: mutation,
    );

void main() {
  test('an Alchemized Alchemon extracts a fixed ten times a normal one', () {
    final normalTop = computeHarvestRatePerMinute(_inst(level: 10));
    expect(normalTop, 6);
    for (final level in [1, 5, 10]) {
      expect(
        computeHarvestRatePerMinute(
          _inst(level: level, mutation: AlchemonMutation.alchemized.id),
        ),
        kAlchemizedHarvestRate,
      );
    }
    expect(kAlchemizedHarvestRate, normalTop * 10);
  });

  test('other mutations extract as normal', () {
    expect(
      computeHarvestRatePerMinute(
        _inst(level: 10, mutation: AlchemonMutation.transmuted.id),
      ),
      computeHarvestRatePerMinute(_inst(level: 10)),
    );
  });
}
