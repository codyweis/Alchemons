import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';

/// Returns a scene-wide pool plus per-location overrides (by SpawnPoint.id).
({EncounterPool sceneWide, Map<String, EncounterPool> perSpawn})
swampEncounterPools(SceneDefinition scene) {
  bool isNight(DateTime now) => now.hour >= 20 || now.hour < 5;
  bool isDay(DateTime now) => !isNight(now);
  final now = DateTime.now();

  final List<EncounterEntry> entries = [];

  // Environment-specific spawns (Day or Night)
  entries.addAll([
    // Common
    EncounterEntry(
      speciesId: 'LET08',
      rarity: EncounterRarity.common,
    ), // Mudlet
    EncounterEntry(
      speciesId: 'LET13',
      rarity: EncounterRarity.common,
    ), // Poisonlet
    EncounterEntry(
      speciesId: 'LET02',
      rarity: EncounterRarity.common,
    ), // Waterlet
    EncounterEntry(
      speciesId: 'LET12',
      rarity: EncounterRarity.common,
    ), // Leaflet
    // Uncommon
    EncounterEntry(
      speciesId: 'MAN08',
      rarity: EncounterRarity.uncommon,
    ), // Mudmane
    EncounterEntry(
      speciesId: 'MAN13',
      rarity: EncounterRarity.uncommon,
    ), // Poisonmane
    EncounterEntry(
      speciesId: 'PIP08',
      rarity: EncounterRarity.uncommon,
    ), // Mudpip
    EncounterEntry(
      speciesId: 'PIP13',
      rarity: EncounterRarity.uncommon,
    ), // Poisonpip
    // Rare
    EncounterEntry(speciesId: 'HOR08', rarity: EncounterRarity.rare), // Mudhorn
    EncounterEntry(
      speciesId: 'HOR13',
      rarity: EncounterRarity.rare,
    ), // Poisonhorn
    EncounterEntry(
      speciesId: 'MSK13',
      rarity: EncounterRarity.rare,
    ), // Poisonmask
  ]);

  if (isDay(now)) {
    entries.addAll([
      // --- Day Spawns ---
      EncounterEntry(
        speciesId: 'MAN12',
        rarity: EncounterRarity.uncommon,
      ), // Plantmane
      EncounterEntry(
        speciesId: 'MSK12',
        rarity: EncounterRarity.rare,
      ), // Plantmask
      EncounterEntry(
        speciesId: 'KIN12',
        rarity: EncounterRarity.legendary,
      ), // Plantkin
    ]);
  } else if (isNight(now)) {
    entries.addAll([
      // --- Night Spawns ---
      // Dark
      EncounterEntry(
        speciesId: 'LET15',
        rarity: EncounterRarity.common,
      ), // Darklet
      EncounterEntry(
        speciesId: 'MAN15',
        rarity: EncounterRarity.uncommon,
      ), // Darkmane
      // Spirit
      EncounterEntry(
        speciesId: 'LET14',
        rarity: EncounterRarity.uncommon,
      ), // Spiritlet
      EncounterEntry(
        speciesId: 'MSK14',
        rarity: EncounterRarity.rare,
      ), // Spiritmask
      // Legendary
      EncounterEntry(
        speciesId: 'KIN13',
        rarity: EncounterRarity.legendary,
      ), // Poisonkin
      EncounterEntry(
        speciesId: 'KIN08',
        rarity: EncounterRarity.legendary,
      ), // Mudkin
    ]);
  }

  final sceneWide = EncounterPool(entries: entries);

  return (sceneWide: sceneWide, perSpawn: {});
}
