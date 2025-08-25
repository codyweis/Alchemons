// lib/models/encounters/valley_pools.dart
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';

/// Returns a scene-wide pool plus per-location overrides (by SpawnPoint.id).
({EncounterPool sceneWide, Map<String, EncounterPool> perSpawn})
valleyEncounterPools(SceneDefinition scene) {
  bool isNight(DateTime now) => now.hour >= 20 || now.hour < 5;
  bool isDay(DateTime now) => !isNight(now);

  final sceneWide = EncounterPool(
    entries: [
      EncounterEntry(
        speciesId: 'WNG01',
        rarity: EncounterRarity.common,
        weightMul: 1.0,
      ),
      EncounterEntry(
        speciesId: 'WNG02',
        rarity: EncounterRarity.uncommon,
        weightMul: 1.0,
      ),
      EncounterEntry(
        speciesId: 'WNG03',
        rarity: EncounterRarity.uncommon,
        weightMul: 0.8,
      ),

      // time-gated rares
      EncounterEntry(
        speciesId: 'CR045',
        rarity: EncounterRarity.rare,
        weightMul: 0.7,
        condition: isDay,
      ),
      EncounterEntry(
        speciesId: 'CR046',
        rarity: EncounterRarity.rare,
        weightMul: 0.7,
        condition: isNight,
      ),

      EncounterEntry(
        speciesId: 'CR070',
        rarity: EncounterRarity.epic,
        weightMul: 0.35,
      ),
      EncounterEntry(
        speciesId: 'CR099',
        rarity: EncounterRarity.legendary,
        weightMul: 0.12,
      ),
    ],
  );

  final perSpawn = <String, EncounterPool>{
    'SP_valley_01': EncounterPool(
      entries: [
        EncounterEntry(
          speciesId: 'WNG01',
          rarity: EncounterRarity.rare,
          weightMul: 1.0,
        ),
        EncounterEntry(
          speciesId: 'WNG02',
          rarity: EncounterRarity.common,
          weightMul: 0.8,
        ),
      ],
    ),
    'SP_valley_02': EncounterPool(
      entries: [
        EncounterEntry(
          speciesId: 'WNG03',
          rarity: EncounterRarity.rare,
          weightMul: 1.0,
        ),
        EncounterEntry(
          speciesId: 'WNG04',
          rarity: EncounterRarity.uncommon,
          weightMul: 0.8,
        ),
      ],
    ),
  };

  return (sceneWide: sceneWide, perSpawn: perSpawn);
}
