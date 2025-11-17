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
      rarity: EncounterRarity.uncommon,
    ), // Mudlet
    EncounterEntry(
      speciesId: 'LET02',
      rarity: EncounterRarity.common,
    ), // Waterlet
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
      rarity: EncounterRarity.rare,
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
      EncounterEntry(
        speciesId: 'WNG08',
        rarity: EncounterRarity.legendary,
      ), // Mudwing
    ]);
  } else if (isNight(now)) {
    entries.addAll([
      // --- Night Spawns ---
      // Dark
      EncounterEntry(
        speciesId: 'LET13',
        rarity: EncounterRarity.uncommon,
      ), // Poisonlet
      EncounterEntry(
        speciesId: 'LET15',
        rarity: EncounterRarity.rare,
      ), // Darklet
      EncounterEntry(
        speciesId: 'MAN15',
        rarity: EncounterRarity.rare,
      ), // Darkmane
      // Spirit
      EncounterEntry(
        speciesId: 'LET14',
        rarity: EncounterRarity.rare,
      ), // Spiritlet
      EncounterEntry(
        speciesId: 'MSK14',
        rarity: EncounterRarity.legendary,
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
