import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/encounters/wild_weather.dart';
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

/// A lightning storm over Skyward Reach. One Sky batch in four comes
/// with one, day or night, and brings Lightning Alchemons with it: at least
/// one, and each other creature of the batch half the time. They all float
/// (Lightning is of the air), so any point can take them. The storm is the
/// only place the pip, mane and horn are found in the wild.
const skyStorm = WildWeather(
  kind: WeatherKind.storm,
  label: 'STORM',
  chance: 0.25,
  guaranteed: 1,
  extra: 0.5,
  pool: EncounterPool(
    entries: [
      EncounterEntry(speciesId: 'LET07', rarity: EncounterRarity.common),
      EncounterEntry(speciesId: 'PIP07', rarity: EncounterRarity.uncommon),
      EncounterEntry(speciesId: 'MAN07', rarity: EncounterRarity.uncommon),
      EncounterEntry(speciesId: 'HOR07', rarity: EncounterRarity.rare),
      EncounterEntry(
        speciesId: 'WNG07',
        rarity: EncounterRarity.legendary,
        weightMul: 1.5,
      ),
    ],
  ),
);
