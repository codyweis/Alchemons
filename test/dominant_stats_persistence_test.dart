import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/potential_genetics.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AlchemonsDatabase db;

  setUp(() {
    db = AlchemonsDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('an instance with no supplied Dominants derives its best two', () async {
    await db.creatureDao.insertInstance(
      instanceId: 'wild-1',
      baseId: 'LET02',
      statSpeedPotential: 30,
      statIntelligencePotential: 91,
      statStrengthPotential: 74,
      statBeautyPotential: 12,
    );

    final stored = await db.creatureDao.getInstance('wild-1');
    final dominants = DominantStats.decode(stored!.dominantStats);

    expect(dominants, isNotNull);
    expect(dominants!.contains(StatKind.intelligence), isTrue);
    expect(dominants.contains(StatKind.strength), isTrue);
    expect(dominants.contains(StatKind.speed), isFalse);
    expect(dominants.contains(StatKind.beauty), isFalse);
  });

  test('supplied Dominants survive the round trip unchanged', () async {
    final bred = DominantStats(StatKind.speed, StatKind.beauty);

    await db.creatureDao.insertInstance(
      instanceId: 'bred-1',
      baseId: 'LET02',
      // Deliberately at odds with the potentials: a bred Alchemon carries what
      // its parents gave it, not whatever it happens to be best at.
      statSpeedPotential: 20,
      statIntelligencePotential: 95,
      statStrengthPotential: 90,
      statBeautyPotential: 25,
      dominantStats: bred.encode(),
    );

    final stored = await db.creatureDao.getInstance('bred-1');
    expect(DominantStats.decode(stored!.dominantStats), bred);
  });

  test('a hatched egg payload carries its bred Dominants through', () async {
    final bred = DominantStats(StatKind.strength, StatKind.beauty);

    final id = await db.creatureDao.insertInstanceFromHatchPayload(
      baseId: 'LET02',
      payload: {
        'baseId': 'LET02',
        'source': 'breeding',
        'stats': {
          'speed': 1.0,
          'intelligence': 1.0,
          'strength': 1.0,
          'beauty': 1.0,
        },
        'statPotentials': {
          'scaleVersion': 2,
          'speed': 44.0,
          'intelligence': 88.0,
          'strength': 61.0,
          'beauty': 52.0,
          'dominants': bred.encode(),
        },
      },
      fallbackGenerationDepth: 1,
      fallbackFactionLineage: const {},
      fallbackElementLineage: const {},
      fallbackFamilyLineage: const {},
    );

    expect(id, isNotNull);
    final stored = await db.creatureDao.getInstance(id!);
    // Its best two are Intelligence and Strength; what it inherited is not.
    expect(DominantStats.decode(stored!.dominantStats), bred);
  });
}
