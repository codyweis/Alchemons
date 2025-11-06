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
    EncounterEntry(
      speciesId: 'MAN07',
      rarity: EncounterRarity.uncommon,
    ), // Lightningmane
    // Rare
    EncounterEntry(speciesId: 'HOR04', rarity: EncounterRarity.rare), // Airhorn
    EncounterEntry(
      speciesId: 'HOR07',
      rarity: EncounterRarity.rare,
    ), // Lightninghorn
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
        rarity: EncounterRarity.uncommon,
      ), // Lightlet
      EncounterEntry(
        speciesId: 'MAN16',
        rarity: EncounterRarity.rare,
      ), // Lightmane
      EncounterEntry(
        speciesId: 'HOR16',
        rarity: EncounterRarity.legendary,
      ), // Lighthorn
      // Legendary
      EncounterEntry(
        speciesId: 'WNG04',
        rarity: EncounterRarity.rare,
      ), // Airwing (common legendary here)
      EncounterEntry(
        speciesId: 'WNG16',
        rarity: EncounterRarity.legendary,
      ), // Lightwing
      EncounterEntry(
        speciesId: 'WNG07',
        rarity: EncounterRarity.legendary,
      ), // Lightningwing
      EncounterEntry(
        speciesId: 'KIN16',
        rarity: EncounterRarity.legendary,
      ), // Lightkin
    ]);
  } else if (isNight(now)) {
    entries.addAll([
      // --- Night Spawns ---
      EncounterEntry(
        speciesId: 'LET07',
        rarity: EncounterRarity.common,
      ), // Lightninglet
      // Dark
      EncounterEntry(
        speciesId: 'LET15',
        rarity: EncounterRarity.uncommon,
      ), // Darklet
      EncounterEntry(
        speciesId: 'MAN15',
        rarity: EncounterRarity.uncommon,
      ), // Darkmane
      EncounterEntry(
        speciesId: 'MSK15',
        rarity: EncounterRarity.rare,
      ), // Darkmask
      // Spirit
      EncounterEntry(
        speciesId: 'LET14',
        rarity: EncounterRarity.rare,
      ), // Spiritlet
      EncounterEntry(
        speciesId: 'MSK14',
        rarity: EncounterRarity.rare,
      ), // Spiritmask
      // Legendary
      EncounterEntry(
        speciesId: 'WNG15',
        rarity: EncounterRarity.legendary,
      ), // Darkwing (common legendary here)
      EncounterEntry(
        speciesId: 'WNG14',
        rarity: EncounterRarity.legendary,
      ), // Spiritwing
      EncounterEntry(
        speciesId: 'KIN04',
        rarity: EncounterRarity.legendary,
      ), // Airkin
    ]);
  }

  final sceneWide = EncounterPool(entries: entries);

  return (sceneWide: sceneWide, perSpawn: {});
}
