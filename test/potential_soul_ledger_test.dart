import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/potential_soul.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/services/breeding_config.dart';
import 'package:alchemons/services/breeding_engine.dart';
import 'package:alchemons/services/creature_instance_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AlchemonsDatabase db;
  late CreatureCatalog catalog;

  setUp(() {
    db = AlchemonsDatabase(NativeDatabase.memory());
    catalog = CreatureCatalog.fromList([
      Creature(
        id: 'SOUL01',
        name: 'Soulmon',
        types: const ['Water'],
        rarity: 'Common',
        description: '',
        image: 'test.png',
        baseStats: const SpeciesBaseStats(
          speed: 60,
          intelligence: 60,
          strength: 60,
          beauty: 60,
        ),
      ),
    ]);
  });

  tearDown(() => db.close());

  Future<void> creature() => db.creatureDao.insertInstance(
    instanceId: 'souled',
    baseId: 'SOUL01',
    level: 5,
    statSpeedPotential: 40,
    statIntelligencePotential: 40,
    statStrengthPotential: 40,
    statBeautyPotential: 40,
  );

  Future<PotentialSoulApplyResult> apply(AlchemicalPowerupType stat) =>
      CreatureInstanceService(db).applyPotentialSoul(
        targetInstanceId: 'souled',
        stat: stat,
        repo: catalog,
      );

  test('the ledger reads back what it wrote', () {
    final ledger = PotentialSoulLedger.empty
        .plus('speed', 3)
        .plus('beauty', 5)
        .plus('speed', 2);
    final read = PotentialSoulLedger.decode(ledger.encode());
    expect(read.count, 3);
    expect(read.gainIn('speed'), 5);
    expect(read.gainIn('beauty'), 5);
    expect(PotentialSoulLedger.decode(null).count, 0);
  });

  test('an Alchemon holds at most ten Souls', () async {
    await creature();
    await db.inventoryDao.addItemQty(InvKeys.potentialSoul, 12);
    await db.settingsDao.setSetting('wallet_silver', '1000000');
    for (var i = 0; i < PotentialSoulRules.maxPerAlchemon; i++) {
      final stat = AlchemicalPowerupType.values[i % 4];
      expect((await apply(stat)).ok, isTrue, reason: 'soul ${i + 1}');
    }
    final eleventh = await apply(AlchemicalPowerupType.speed);
    expect(eleventh.ok, isFalse);
    expect(await db.inventoryDao.getItemQty(InvKeys.potentialSoul), 2);
    final row = (await db.creatureDao.getInstance('souled'))!;
    expect(PotentialSoulLedger.decode(row.potentialSouls).count, 10);
  });

  test(
    'taking them back returns the Souls and the Potential, for Gold',
    () async {
      await creature();
      await db.inventoryDao.addItemQty(InvKeys.potentialSoul, 3);
      await db.settingsDao.setSetting('wallet_silver', '1000000');
      await apply(AlchemicalPowerupType.speed);
      await apply(AlchemicalPowerupType.speed);
      await apply(AlchemicalPowerupType.beauty);
      final souled = (await db.creatureDao.getInstance('souled'))!;
      expect(souled.statSpeedPotential, greaterThan(40));
      expect(await db.inventoryDao.getItemQty(InvKeys.potentialSoul), 0);

      final service = CreatureInstanceService(db);
      // Short of Gold: nothing changes.
      await db.settingsDao.setSetting('wallet_gold', '14');
      final short = await service.refundPotentialSouls(
        targetInstanceId: 'souled',
        repo: catalog,
      );
      expect(short.ok, isFalse);
      expect(await db.inventoryDao.getItemQty(InvKeys.potentialSoul), 0);

      await db.settingsDao.setSetting('wallet_gold', '20');
      final refund = await service.refundPotentialSouls(
        targetInstanceId: 'souled',
        repo: catalog,
      );
      expect(refund.ok, isTrue);
      expect(refund.souls, 3);
      expect(refund.goldCost, 3 * PotentialSoulRules.refundGoldEach);
      expect(await db.currencyDao.getGoldBalance(), 5);
      expect(await db.inventoryDao.getItemQty(InvKeys.potentialSoul), 3);
      final back = (await db.creatureDao.getInstance('souled'))!;
      expect(back.statSpeedPotential, 40);
      expect(back.statBeautyPotential, 40);
      expect(back.potentialSouls, isNull);
      expect(back.statSpeed, lessThan(souled.statSpeed));
    },
  );

  test('a cross with no recipe leans toward the commoner family', () {
    Creature of(String family, String rarity) => Creature(
      id: '$family$rarity',
      name: family,
      types: const ['Water'],
      rarity: rarity,
      description: '',
      image: '',
      mutationFamily: family,
    );
    final engine = BreedingEngine(
      CreatureCatalog.fromList([of('Let', 'Common'), of('Kin', 'Legendary')]),
      elementRecipes: ElementRecipeConfig(recipes: const {}),
      familyRecipes: const FamilyRecipeConfig(recipes: {}),
    );
    Map<String, double> odds(Creature a, Creature b) =>
        engine.getFamilyDistribution(a, b).asPercentages();

    expect(odds(of('Let', 'Common'), of('Kin', 'Legendary')), {
      'Let': closeTo(80, 1e-9),
      'Kin': closeTo(20, 1e-9),
    });
    expect(odds(of('Kin', 'Legendary'), of('Let', 'Common')), {
      'Kin': closeTo(20, 1e-9),
      'Let': closeTo(80, 1e-9),
    });
    expect(odds(of('Let', 'Rare'), of('Kin', 'Rare')), {
      'Let': closeTo(50, 1e-9),
      'Kin': closeTo(50, 1e-9),
    });
    expect(
      odds(of('Let', 'Uncommon'), of('Kin', 'Rare'))['Let'],
      closeTo(60, 1e-9),
    );
  });
}
