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
      weightMul: 1.6,
    ), // Airlet
    EncounterEntry(
      speciesId: 'LET05',
      rarity: EncounterRarity.uncommon,
      weightMul: 0.45,
    ), // Steamlet (clouds)
    // Uncommon
    EncounterEntry(
      speciesId: 'MAN04',
      rarity: EncounterRarity.uncommon,
      weightMul: 0.35,
    ), // Airmane
    EncounterEntry(
      speciesId: 'PIP04',
      rarity: EncounterRarity.uncommon,
      weightMul: 0.35,
    ), // Airpip
    // Rare
    EncounterEntry(
      speciesId: 'HOR04',
      rarity: EncounterRarity.rare,
      weightMul: 0.25,
    ), // Airhorn
  ]);

  if (isDay(now)) {
    entries.addAll([
      // --- Day Spawns ---
      // Light
      EncounterEntry(
        speciesId: 'LET16',
        rarity: EncounterRarity.uncommon,
        weightMul: 0.30,
      ), // Lightlet
      // Legendary
      EncounterEntry(
        speciesId: 'WNG04',
        rarity: EncounterRarity.legendary,
        weightMul: 0.10,
      ), // Airwing
      EncounterEntry(
        speciesId: 'WNG16',
        rarity: EncounterRarity.legendary,
        weightMul: 0.08,
      ), // Lightwing
    ]);
  } else if (isNight(now)) {
    entries.addAll([
      EncounterEntry(
        speciesId: 'WNG07',
        rarity: EncounterRarity.legendary,
        weightMul: 0.08,
      ), // Lightningwing
      // --- Night Spawns ---
      EncounterEntry(
        speciesId: 'LET07',
        rarity: EncounterRarity.uncommon,
        weightMul: 0.30,
      ), // Lightninglet
      // Spirit
      EncounterEntry(
        speciesId: 'LET14',
        rarity: EncounterRarity.uncommon,
        weightMul: 0.25,
      ), // Spiritlet
    ]);
  }

  final sceneWide = EncounterPool(entries: entries);

  return (sceneWide: sceneWide, perSpawn: {});
}
