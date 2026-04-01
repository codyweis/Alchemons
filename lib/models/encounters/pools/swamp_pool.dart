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
        // Hovering marsh pocket — flying/floating creatures only
        EncounterEntry(
          speciesId: 'LET04',
          rarity: EncounterRarity.common,
          weightMul: 0.75,
        ), // Airlet
        EncounterEntry(
          speciesId: 'LET13',
          rarity: EncounterRarity.uncommon,
          weightMul: 0.25,
          condition: isNight,
        ), // Poisonlet (toxic gas rises)
        EncounterEntry(
          speciesId: 'LET14',
          rarity: EncounterRarity.uncommon,
          weightMul: 0.20,
          condition: isNight,
        ), // Spiritlet (floats)
        EncounterEntry(
          speciesId: 'WNG08',
          rarity: EncounterRarity.legendary,
          weightMul: 0.08,
          condition: isDay,
        ), // Mudwing
        EncounterEntry(
          speciesId: 'MSK14',
          rarity: EncounterRarity.rare,
          weightMul: 0.12,
          condition: isNight,
        ), // Spiritmask (floats)
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
      weightMul: 0.45,
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
      rarity: EncounterRarity.uncommon,
      weightMul: 0.25,
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
    // Wings only spawn at aerial SP_swamp_03
  } else if (isNight(now)) {
    entries.addAll([
      // --- Night Spawns ---
      // Dark
      EncounterEntry(
        speciesId: 'LET13',
        rarity: EncounterRarity.uncommon,
        weightMul: 0.30,
      ), // Poisonlet
      EncounterEntry(
        speciesId: 'LET15',
        rarity: EncounterRarity.uncommon,
        weightMul: 0.25,
      ), // Darklet
      EncounterEntry(
        speciesId: 'MAN15',
        rarity: EncounterRarity.uncommon,
        weightMul: 0.25,
      ), // Darkmane
      // Spirit
      EncounterEntry(
        speciesId: 'LET14',
        rarity: EncounterRarity.uncommon,
        weightMul: 0.25,
      ), // Spiritlet
      EncounterEntry(
        speciesId: 'MSK14',
        rarity: EncounterRarity.rare,
        weightMul: 0.15,
      ), // Spiritmask
      // Legendary
      EncounterEntry(
        speciesId: 'KIN13',
        rarity: EncounterRarity.legendary,
        weightMul: 0.06,
      ), // Poisonkin
    ]);
  }

  final sceneWide = EncounterPool(entries: entries);

  return (sceneWide: sceneWide, perSpawn: perSpawn);
}
