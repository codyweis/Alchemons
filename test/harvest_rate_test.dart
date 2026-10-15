import 'package:alchemons/database/alchemons_db.dart' as db;
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/wild_fusion.dart';
import 'package:alchemons/utils/harvest_rate.dart';
import 'package:flutter_test/flutter_test.dart';

db.CreatureInstance _inst({
  int level = 1,
  String? mutation,
  String? nature,
  String? nature2,
}) => db.CreatureInstance(
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
  natureId: nature,
  natureId2: nature2,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadNatures);

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

  test('harvest natures speed it up, and both of them count', () {
    final plain = computeHarvestRatePerMinute(_inst(level: 10));
    expect(
      computeHarvestRatePerMinute(_inst(level: 10, nature: 'Metabolic')),
      greaterThan(plain),
    );
    expect(
      computeHarvestRatePerMinute(_inst(level: 10, nature: 'Hypermetabolic')),
      greaterThan(
        computeHarvestRatePerMinute(_inst(level: 10, nature: 'Anabolic')),
      ),
    );
  });

  test('an Alchemized Alchemon\'s natures count on top of its fixed rate', () {
    int alchemized({String? nature, String? nature2}) =>
        computeHarvestRatePerMinute(
          _inst(
            mutation: AlchemonMutation.alchemized.id,
            nature: nature,
            nature2: nature2,
          ),
        );
    expect(alchemized(), 60);
    expect(alchemized(nature: 'Metabolic'), 72);
    expect(alchemized(nature: 'Anabolic'), 81);
    expect(alchemized(nature: 'Hypermetabolic'), 90);
    expect(alchemized(nature: 'Metabolic', nature2: 'Hypermetabolic'), 108);
    expect(alchemized(nature: 'Swift'), 60);
  });
}
