import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/purity_stat_bonus.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/models/variant_stat_bonus.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('what a variant is worth', () {
    test('each joinable faction lifts its one stat by 8%', () {
      for (final (faction, stat) in [
        ('Volcanic', kStatStrength),
        ('Oceanic', kStatIntelligence),
        ('Verdant', kStatSpeed),
        ('Earthen', kStatBeauty),
      ]) {
        final b = resolveVariantStatBonus(
          variantFaction: faction,
          joinedFaction: null,
        );
        expect(b.statKeys, [stat], reason: faction);
        expect(b.multiplierFor(stat), closeTo(1.08, 1e-9), reason: faction);
        expect(b.joined, isFalse);
      }
    });

    test('12% when it is the faction the player joined', () {
      final b = resolveVariantStatBonus(
        variantFaction: 'Volcanic',
        joinedFaction: 'volcanic',
      );
      expect(b.joined, isTrue);
      expect(b.multiplierFor(kStatStrength), closeTo(1.12, 1e-9));
      expect(b.multiplierFor(kStatSpeed), 1.0);
    });

    test('Arcane lifts all four by 3%; Bloodborn and none, nothing', () {
      final arcane = resolveVariantStatBonus(
        variantFaction: 'Arcane',
        joinedFaction: 'volcanic',
      );
      for (final stat in kFullPurityStatPool) {
        expect(arcane.multiplierFor(stat), closeTo(1.03, 1e-9));
      }
      for (final none in ['bloodborn', '', null]) {
        expect(
          resolveVariantStatBonus(
            variantFaction: none,
            joinedFaction: null,
          ).isNone,
          isTrue,
        );
      }
    });
  });

  test('stored stats carry it, and change with the faction joined', () async {
    final db = AlchemonsDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final catalog = CreatureCatalog.fromList([
      Creature(
        id: 'VAR01',
        name: 'Variantmon',
        types: const ['Water'],
        rarity: 'Rare',
        description: 'Test creature',
        image: 'test.png',
        baseStats: const SpeciesBaseStats(
          speed: 70,
          intelligence: 70,
          strength: 70,
          beauty: 70,
        ),
      ),
    ]);
    await db.creatureDao.insertInstance(
      instanceId: 'variant',
      baseId: 'VAR01',
      level: 5,
      variantFaction: 'Volcanic',
      statSpeedPotential: 50,
      statIntelligencePotential: 50,
      statStrengthPotential: 50,
      statBeautyPotential: 50,
    );
    await db.settingsDao.setSetting('player_faction_v1', 'oceanic');
    final game = GameDataService(db: db, catalog: catalog);
    await game.init();
    final asOceanic = (await db.creatureDao.getInstance('variant'))!;

    await db.settingsDao.setSetting('player_faction_v1', 'volcanic');
    await game.reconcileInstanceStats();
    final asVolcanic = (await db.creatureDao.getInstance('variant'))!;

    expect(
      asVolcanic.statStrength / asOceanic.statStrength,
      closeTo(1.12 / 1.08, 1e-9),
    );
    expect(asVolcanic.statSpeed, asOceanic.statSpeed);
    expect(asVolcanic.statBeauty, asOceanic.statBeauty);
  });
}
