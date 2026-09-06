import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/services/creature_instance_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _MaxSoulRollRandom implements Random {
  const _MaxSoulRollRandom();

  @override
  bool nextBool() => true;

  @override
  double nextDouble() => 0.5;

  @override
  int nextInt(int max) => max - 1;
}

void main() {
  late AlchemonsDatabase db;
  late CreatureCatalog catalog;

  setUp(() {
    db = AlchemonsDatabase(NativeDatabase.memory());
    catalog = CreatureCatalog.fromList([
      Creature(
        id: 'TEST01',
        name: 'Testmon',
        types: const ['Fire'],
        rarity: 'Common',
        description: 'Test creature',
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

  test('orb atomically buys one deterministic Enhancement rank', () async {
    await db.creatureDao.insertInstance(
      instanceId: 'instance-1',
      baseId: 'TEST01',
      level: 10,
      statSpeedPotential: 50,
      statIntelligencePotential: 50,
      statStrengthPotential: 50,
      statBeautyPotential: 50,
    );
    await db.inventoryDao.addItemQty(InvKeys.powerupSpeed, 1);
    await db.settingsDao.setSetting('wallet_silver', '5000');

    final result = await CreatureInstanceService(db).applyAlchemicalPowerup(
      targetInstanceId: 'instance-1',
      powerup: AlchemicalPowerupType.speed,
      repo: catalog,
    );
    final updated = await db.creatureDao.getInstance('instance-1');

    expect(result.ok, isTrue);
    expect(result.delta, 3);
    expect(updated!.statSpeedEnhancement, 1);
    expect(updated.statSpeed, closeTo(3.5535, 0.0001));
    expect(updated.statIntelligence, closeTo(3.45, 0.0001));
    expect(await db.inventoryDao.getItemQty(InvKeys.powerupSpeed), 0);
  });

  test('Enhancement no longer waits for level ten', () async {
    await db.creatureDao.insertInstance(
      instanceId: 'instance-2',
      baseId: 'TEST01',
      level: 1,
    );
    await db.inventoryDao.addItemQty(InvKeys.powerupSpeed, 1);
    await db.settingsDao.setSetting('wallet_silver', '5000');

    final result = await CreatureInstanceService(db).applyAlchemicalPowerup(
      targetInstanceId: 'instance-2',
      powerup: AlchemicalPowerupType.speed,
      repo: catalog,
    );

    expect(result.ok, isTrue);
    // The Orb is spent and the rank actually lands, so the level gate is gone
    // rather than merely unreported.
    expect(await db.inventoryDao.getItemQty(InvKeys.powerupSpeed), 0);
    final updated = await db.creatureDao.getInstance('instance-2');
    expect(updated!.statSpeedEnhancement, 1);
  });

  test(
    'combat constellation rank grants 1% without discounting Orbs',
    () async {
      await db.constellationDao.unlockSkill('combat_speed_boost_1', 2);
      final constellationEffects = ConstellationEffectsService(db);
      await Future<void>.delayed(Duration.zero);

      await db.creatureDao.insertInstance(
        instanceId: 'instance-discount',
        baseId: 'TEST01',
        level: 10,
        statSpeedEnhancement: 3,
        statSpeedPotential: 50,
        statIntelligencePotential: 50,
        statStrengthPotential: 50,
        statBeautyPotential: 50,
      );
      await db.inventoryDao.addItemQty(InvKeys.powerupSpeed, 1);

      final result = await CreatureInstanceService(db).applyAlchemicalPowerup(
        targetInstanceId: 'instance-discount',
        powerup: AlchemicalPowerupType.speed,
        repo: catalog,
      );
      final updated = await db.creatureDao.getInstance('instance-discount');

      expect(constellationEffects.getCombatStatBonusPercent('speed'), 1);
      expect(
        constellationEffects.applyCombatStatBonus('speed', 3.5),
        closeTo(3.535, 0.000001),
      );
      expect(result.ok, isFalse);
      expect(updated!.statSpeedEnhancement, 3);
      expect(await db.inventoryDao.getItemQty(InvKeys.powerupSpeed), 1);
    },
  );

  test('each completed combat branch grants exactly 5%', () async {
    for (final prefix in ['atk', 'int', 'beauty', 'speed']) {
      for (var rank = 1; rank <= 5; rank++) {
        await db.constellationDao.unlockSkill(
          'combat_${prefix}_boost_$rank',
          0,
        );
      }
    }

    final effects = ConstellationEffectsService(db);
    await Future<void>.delayed(Duration.zero);

    for (final stat in ['strength', 'intelligence', 'beauty', 'speed']) {
      expect(effects.getCombatStatBonusPercent(stat), 5);
      expect(effects.getCombatStatMultiplier(stat), closeTo(1.05, 0.000001));
      expect(effects.applyCombatStatBonus(stat, 4.0), closeTo(4.2, 0.000001));
    }
    expect(effects.getCombatStatBonusPercent('atk'), 5);
    expect(effects.getCombatStatBonusPercent('int'), 5);
  });

  test(
    'database preserves legitimate Power above the legacy ceiling',
    () async {
      await db.creatureDao.insertInstance(
        instanceId: 'instance-overcap',
        baseId: 'TEST01',
        level: 10,
        statSpeed: 8.2,
        statIntelligence: 7.4,
        statStrength: 6.8,
        statBeauty: 5.6,
        statSpeedPotential: 100,
        statIntelligencePotential: 100,
        statStrengthPotential: 100,
        statBeautyPotential: 100,
      );

      final stored = await db.creatureDao.getInstance('instance-overcap');
      expect(stored, isNotNull);
      expect(stored!.statSpeed, 8.2);
      expect(stored.statIntelligence, 7.4);
      expect(stored.statStrength, 6.8);
      expect(stored.statBeauty, 5.6);
    },
  );

  test('Potential Soul atomically applies a capped 1–5 genetic roll', () async {
    await db.creatureDao.insertInstance(
      instanceId: 'instance-soul',
      baseId: 'TEST01',
      level: 1,
      statSpeedPotential: 98,
      statIntelligencePotential: 50,
      statStrengthPotential: 50,
      statBeautyPotential: 50,
    );
    await db.inventoryDao.addItemQty(InvKeys.potentialSoul, 1);
    await db.settingsDao.setSetting('wallet_silver', '50000');

    final result = await CreatureInstanceService(db).applyPotentialSoul(
      targetInstanceId: 'instance-soul',
      stat: AlchemicalPowerupType.speed,
      repo: catalog,
      random: const _MaxSoulRollRandom(),
    );
    final updated = await db.creatureDao.getInstance('instance-soul');

    expect(result.ok, isTrue);
    expect(result.rolledGain, 5);
    expect(result.appliedGain, 2);
    expect(result.newPotential, 100);
    expect(result.silverCost, 50000);
    expect(updated!.statSpeedPotential, 100);
    expect(updated.statIntelligencePotential, 50);
    expect(updated.statSpeed, closeTo(2.145, 0.0001));
    expect(await db.inventoryDao.getItemQty(InvKeys.potentialSoul), 0);
    expect(await db.currencyDao.getSilverBalance(), 0);
  });

  test('Potential Soul cost tiers rise with current Potential', () {
    expect(AlchemonStatSystem.potentialSoulSilverCost(1), 10000);
    expect(AlchemonStatSystem.potentialSoulSilverCost(59), 10000);
    expect(AlchemonStatSystem.potentialSoulSilverCost(60), 20000);
    expect(AlchemonStatSystem.potentialSoulSilverCost(79), 20000);
    expect(AlchemonStatSystem.potentialSoulSilverCost(80), 35000);
    expect(AlchemonStatSystem.potentialSoulSilverCost(89), 35000);
    expect(AlchemonStatSystem.potentialSoulSilverCost(90), 50000);
    expect(AlchemonStatSystem.potentialSoulSilverCost(99), 50000);
  });

  test('insufficient Silver preserves the Soul and genetics', () async {
    await db.creatureDao.insertInstance(
      instanceId: 'instance-soul-poor',
      baseId: 'TEST01',
      statSpeedPotential: 70,
    );
    await db.inventoryDao.addItemQty(InvKeys.potentialSoul, 1);
    await db.settingsDao.setSetting('wallet_silver', '19999');

    final result = await CreatureInstanceService(db).applyPotentialSoul(
      targetInstanceId: 'instance-soul-poor',
      stat: AlchemicalPowerupType.speed,
      repo: catalog,
      random: const _MaxSoulRollRandom(),
    );

    expect(result.ok, isFalse);
    expect(result.error, contains('20000 Silver'));
    expect(
      (await db.creatureDao.getInstance(
        'instance-soul-poor',
      ))!.statSpeedPotential,
      70,
    );
    expect(await db.inventoryDao.getItemQty(InvKeys.potentialSoul), 1);
    expect(await db.currencyDao.getSilverBalance(), 19999);
  });

  test('Potential Soul failure preserves genetics and inventory', () async {
    await db.creatureDao.insertInstance(
      instanceId: 'instance-full-potential',
      baseId: 'TEST01',
      statBeautyPotential: 100,
    );
    await db.inventoryDao.addItemQty(InvKeys.potentialSoul, 1);

    final result = await CreatureInstanceService(db).applyPotentialSoul(
      targetInstanceId: 'instance-full-potential',
      stat: AlchemicalPowerupType.beauty,
      repo: catalog,
      random: const _MaxSoulRollRandom(),
    );

    expect(result.ok, isFalse);
    expect(
      (await db.creatureDao.getInstance(
        'instance-full-potential',
      ))!.statBeautyPotential,
      100,
    );
    expect(await db.inventoryDao.getItemQty(InvKeys.potentialSoul), 1);
  });

  test('Enhancement Silver runs 50 to 1000 across the ten ranks', () {
    expect(AlchemonStatSystem.enhancementSilverForNextRank(0), 50);
    expect(AlchemonStatSystem.enhancementSilverForNextRank(9), 1000);
    // No next rank to buy at the cap.
    expect(
      AlchemonStatSystem.enhancementSilverForNextRank(
        AlchemonStatSystem.maxEnhancementRank,
      ),
      0,
    );
    var previous = 0;
    for (var rank = 0; rank < AlchemonStatSystem.maxEnhancementRank; rank++) {
      final cost = AlchemonStatSystem.enhancementSilverForNextRank(rank);
      expect(cost, greaterThan(previous), reason: 'rank $rank');
      previous = cost;
    }
    // Summed independently of the implementation, so a reshuffled ladder
    // cannot silently desync the running total the tray quotes.
    var expected = 0;
    for (var rank = 0; rank < AlchemonStatSystem.maxEnhancementRank; rank++) {
      expected += AlchemonStatSystem.enhancementSilverForNextRank(rank);
    }
    expect(AlchemonStatSystem.enhancementSilverToMaxRank(0), expected);
    expect(AlchemonStatSystem.enhancementSilverToMaxRank(0), 3990);
    expect(
      AlchemonStatSystem.enhancementSilverToMaxRank(
        AlchemonStatSystem.maxEnhancementRank,
      ),
      0,
    );
  });

  test('an Enhancement charges Orbs and Silver together', () async {
    await db.creatureDao.insertInstance(
      instanceId: 'instance-silver',
      baseId: 'TEST01',
      level: 10,
    );
    await db.inventoryDao.addItemQty(InvKeys.powerupSpeed, 1);
    await db.settingsDao.setSetting('wallet_silver', '500');

    final result = await CreatureInstanceService(db).applyAlchemicalPowerup(
      targetInstanceId: 'instance-silver',
      powerup: AlchemicalPowerupType.speed,
      repo: catalog,
    );

    expect(result.ok, isTrue);
    expect(await db.inventoryDao.getItemQty(InvKeys.powerupSpeed), 0);
    expect(await db.currencyDao.getSilverBalance(), 450);
  });

  test('too little Silver leaves the Orb unspent', () async {
    await db.creatureDao.insertInstance(
      instanceId: 'instance-broke',
      baseId: 'TEST01',
      level: 10,
    );
    await db.inventoryDao.addItemQty(InvKeys.powerupSpeed, 1);
    await db.settingsDao.setSetting('wallet_silver', '49');

    final result = await CreatureInstanceService(db).applyAlchemicalPowerup(
      targetInstanceId: 'instance-broke',
      powerup: AlchemicalPowerupType.speed,
      repo: catalog,
    );
    final updated = await db.creatureDao.getInstance('instance-broke');

    expect(result.ok, isFalse);
    // The Orb is consumed before the Silver is taken, so the whole
    // transaction has to roll back or the player pays for nothing.
    expect(await db.inventoryDao.getItemQty(InvKeys.powerupSpeed), 1);
    expect(await db.currencyDao.getSilverBalance(), 49);
    expect(updated!.statSpeedEnhancement, 0);
  });
}
