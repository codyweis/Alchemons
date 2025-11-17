import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';

/// Returns a scene-wide pool plus per-location overrides (by SpawnPoint.id).
({EncounterPool sceneWide, Map<String, EncounterPool> perSpawn})
skyEncounterPools(SceneDefinition scene) {
  bool isNight(DateTime now) => now.hour >= 20 || now.hour < 5;
  bool isDay(DateTime now) => !isNight(now);
  final now = DateTime.now();

  final List<EncounterEntry> entries = [];

  // Environment-specific spawns (Day or Night)
  entries.addAll([
    // Common
    EncounterEntry(
      speciesId: 'LET04',
      rarity: EncounterRarity.common,
    ), // Airlet
    EncounterEntry(
      speciesId: 'LET05',
      rarity: EncounterRarity.common,
    ), // Steamlet (clouds)
    // Uncommon
    EncounterEntry(
      speciesId: 'MAN04',
      rarity: EncounterRarity.uncommon,
    ), // Airmane
    EncounterEntry(
      speciesId: 'PIP04',
      rarity: EncounterRarity.uncommon,
    ), // Airpip
    // Rare
    EncounterEntry(speciesId: 'HOR04', rarity: EncounterRarity.rare), // Airhorn
    EncounterEntry(
      speciesId: 'HOR09',
      rarity: EncounterRarity.rare,
    ), // Icehorn (high altitude)
  ]);

  if (isDay(now)) {
    entries.addAll([
      // --- Day Spawns ---
      // Light
      EncounterEntry(
        speciesId: 'LET16',
        rarity: EncounterRarity.rare,
      ), // Lightlet
      // Legendary
      EncounterEntry(speciesId: 'WNG04', rarity: EncounterRarity.rare),
      EncounterEntry(
        speciesId: 'WNG16',
        rarity: EncounterRarity.legendary,
      ), // Lightwing
    ]);
  } else if (isNight(now)) {
    entries.addAll([
      EncounterEntry(
        speciesId: 'WNG07',
        rarity: EncounterRarity.legendary,
      ), // Lightningwing
      // --- Night Spawns ---
      EncounterEntry(
        speciesId: 'LET07',
        rarity: EncounterRarity.common,
      ), // Lightninglet
      // Spirit
      EncounterEntry(
        speciesId: 'LET14',
        rarity: EncounterRarity.common,
      ), // Spiritlet
      EncounterEntry(speciesId: 'WNG14', rarity: EncounterRarity.legendary),
    ]);
  }

  final sceneWide = EncounterPool(entries: entries);

  return (sceneWide: sceneWide, perSpawn: {});
}
