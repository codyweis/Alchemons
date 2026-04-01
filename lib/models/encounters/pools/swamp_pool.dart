import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';

/// Returns a scene-wide pool plus per-location overrides (by SpawnPoint.id).
({EncounterPool sceneWide, Map<String, EncounterPool> perSpawn})
swampEncounterPools(SceneDefinition scene) {
  bool isNight(DateTime now) => now.hour >= 20 || now.hour < 5;
  bool isDay(DateTime now) => !isNight(now);
  final now = DateTime.now();

  final perSpawn = <String, EncounterPool>{
    'SP_swamp_03': EncounterPool(
      entries: [
        EncounterEntry(
          speciesId: 'LET02',
          rarity: EncounterRarity.common,
          weightMul: 0.75,
        ),
        EncounterEntry(
          speciesId: 'LET08',
          rarity: EncounterRarity.uncommon,
          weightMul: 0.3,
        ),
        EncounterEntry(
          speciesId: 'LET13',
          rarity: EncounterRarity.rare,
          weightMul: 0.12,
          condition: isNight,
        ),
        EncounterEntry(
          speciesId: 'LET14',
          rarity: EncounterRarity.rare,
          weightMul: 0.1,
          condition: isNight,
        ),
        EncounterEntry(
          speciesId: 'WNG08',
          rarity: EncounterRarity.legendary,
          weightMul: 0.08,
          condition: isDay,
        ),
        EncounterEntry(
          speciesId: 'MSK14',
          rarity: EncounterRarity.legendary,
          weightMul: 0.06,
          condition: isNight,
        ),
      ],
    ),
  };

  final List<EncounterEntry> entries = [];

  // Environment-specific spawns (Day or Night)
  entries.addAll([
    // Common
    EncounterEntry(
      speciesId: 'LET08',
      rarity: EncounterRarity.uncommon,
      weightMul: 0.35,
    ), // Mudlet
    EncounterEntry(
      speciesId: 'LET02',
      rarity: EncounterRarity.common,
      weightMul: 2.1,
    ), // Waterlet
    // Uncommon
    EncounterEntry(
      speciesId: 'MAN08',
      rarity: EncounterRarity.uncommon,
      weightMul: 0.35,
    ), // Mudmane
    EncounterEntry(
      speciesId: 'MAN13',
      rarity: EncounterRarity.uncommon,
      weightMul: 0.25,
    ), // Poisonmane
    EncounterEntry(
      speciesId: 'PIP08',
      rarity: EncounterRarity.uncommon,
      weightMul: 0.3,
    ), // Mudpip
    EncounterEntry(
      speciesId: 'PIP13',
      rarity: EncounterRarity.rare,
      weightMul: 0.18,
    ), // Poisonpip
    // Rare
    EncounterEntry(
      speciesId: 'HOR08',
      rarity: EncounterRarity.rare,
      weightMul: 0.2,
    ), // Mudhorn
    EncounterEntry(
      speciesId: 'HOR13',
      rarity: EncounterRarity.rare,
      weightMul: 0.15,
    ), // Poisonhorn
    EncounterEntry(
      speciesId: 'MSK13',
      rarity: EncounterRarity.rare,
      weightMul: 0.12,
    ), // Poisonmask
  ]);

  if (isDay(now)) {
    entries.addAll([
      EncounterEntry(
        speciesId: 'WNG08',
        rarity: EncounterRarity.legendary,
        weightMul: 0.08,
      ), // Mudwing
    ]);
  } else if (isNight(now)) {
    entries.addAll([
      // --- Night Spawns ---
      // Dark
      EncounterEntry(
        speciesId: 'LET13',
        rarity: EncounterRarity.rare,
        weightMul: 0.16,
      ), // Poisonlet
      EncounterEntry(
        speciesId: 'LET15',
        rarity: EncounterRarity.rare,
        weightMul: 0.12,
      ), // Darklet
      EncounterEntry(
        speciesId: 'MAN15',
        rarity: EncounterRarity.rare,
        weightMul: 0.1,
      ), // Darkmane
      // Spirit
      EncounterEntry(
        speciesId: 'LET14',
        rarity: EncounterRarity.rare,
        weightMul: 0.1,
      ), // Spiritlet
      EncounterEntry(
        speciesId: 'MSK14',
        rarity: EncounterRarity.legendary,
        weightMul: 0.08,
      ), // Spiritmask
      // Legendary
      EncounterEntry(
        speciesId: 'KIN13',
        rarity: EncounterRarity.legendary,
        weightMul: 0.06,
      ), // Poisonkin
      EncounterEntry(
        speciesId: 'KIN08',
        rarity: EncounterRarity.legendary,
        weightMul: 0.06,
      ), // Mudkin
    ]);
  }

  final sceneWide = EncounterPool(entries: entries);

  return (sceneWide: sceneWide, perSpawn: perSpawn);
}
