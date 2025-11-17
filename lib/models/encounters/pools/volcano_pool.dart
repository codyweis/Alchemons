import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';

/// Returns a scene-wide pool plus per-location overrides (by SpawnPoint.id).
({EncounterPool sceneWide, Map<String, EncounterPool> perSpawn})
volcanoEncounterPools(SceneDefinition scene) {
  bool isNight(DateTime now) => now.hour >= 20 || now.hour < 5;
  bool isDay(DateTime now) => !isNight(now);
  final now = DateTime.now();

  final List<EncounterEntry> entries = [];

  // Environment-specific spawns (Day or Night)
  entries.addAll([
    // Common
    EncounterEntry(
      speciesId: 'LET01',
      rarity: EncounterRarity.common,
    ), // Firelet
    EncounterEntry(
      speciesId: 'LET06',
      rarity: EncounterRarity.common,
    ), // Lavalet
    EncounterEntry(
      speciesId: 'LET10',
      rarity: EncounterRarity.uncommon,
    ), // Dustlet (ash)

    EncounterEntry(
      speciesId: 'MAN01',
      rarity: EncounterRarity.uncommon,
    ), // Firemane
    EncounterEntry(speciesId: 'PIP06', rarity: EncounterRarity.rare), // Lavapip
    EncounterEntry(
      speciesId: 'PIP01',
      rarity: EncounterRarity.uncommon,
    ), // Lavamane
    // Rare
    EncounterEntry(
      speciesId: 'HOR01',
      rarity: EncounterRarity.rare,
    ), // Firehorn
    EncounterEntry(
      speciesId: 'HOR06',
      rarity: EncounterRarity.legendary,
    ), // Lavahorn
    EncounterEntry(
      speciesId: 'MSK01',
      rarity: EncounterRarity.rare,
    ), // Firemask
  ]);

  if (isDay(now)) {
    entries.addAll([
      EncounterEntry(
        speciesId: 'WNG06',
        rarity: EncounterRarity.legendary,
      ), // Lavawing
      //firewing
      EncounterEntry(
        speciesId: 'WNG01',
        rarity: EncounterRarity.legendary,
      ), // Firewing
    ]);
  } else if (isNight(now)) {
    entries.addAll([
      // --- Night Spawns ---
      // Spirit
      EncounterEntry(
        speciesId: 'LET14',
        rarity: EncounterRarity.rare,
      ), // Spiritlet
      EncounterEntry(
        speciesId: 'MSK14',
        rarity: EncounterRarity.legendary,
      ), // Spiritmask
      EncounterEntry(
        speciesId: 'MSK06',
        rarity: EncounterRarity.rare,
      ), // Lavamask
      //firekin
      EncounterEntry(
        speciesId: 'KIN01',
        rarity: EncounterRarity.legendary,
      ), // Firekin
      // Legendary
    ]);
  }

  final sceneWide = EncounterPool(entries: entries);

  return (sceneWide: sceneWide, perSpawn: {});
}
