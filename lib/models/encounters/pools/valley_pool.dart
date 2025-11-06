import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';

/// Returns a scene-wide pool plus per-location overrides (by SpawnPoint.id).
({EncounterPool sceneWide, Map<String, EncounterPool> perSpawn})
valleyEncounterPools(SceneDefinition scene) {
  bool isNight(DateTime now) => now.hour >= 20 || now.hour < 5;
  bool isDay(DateTime now) => !isNight(now);
  final now = DateTime.now();

  final List<EncounterEntry> entries = [];

  if (isDay(now)) {
    entries.addAll([
      // --- Day Spawns ---
      // Common
      EncounterEntry(
        speciesId: 'LET03',
        rarity: EncounterRarity.common,
      ), // Earthlet
      EncounterEntry(
        speciesId: 'LET12',
        rarity: EncounterRarity.common,
      ), // Leaflet
      EncounterEntry(
        speciesId: 'LET02',
        rarity: EncounterRarity.common,
      ), // Waterlet (rivers)
      EncounterEntry(
        speciesId: 'LET16',
        rarity: EncounterRarity.common,
      ), // Lightlet
      EncounterEntry(
        speciesId: 'LET04',
        rarity: EncounterRarity.common,
      ), // Airlet
      // Uncommon
      EncounterEntry(
        speciesId: 'MAN03',
        rarity: EncounterRarity.uncommon,
      ), // Earthmane
      EncounterEntry(
        speciesId: 'MAN12',
        rarity: EncounterRarity.uncommon,
      ), // Plantmane
      EncounterEntry(
        speciesId: 'PIP03',
        rarity: EncounterRarity.uncommon,
      ), // Earthpip
      EncounterEntry(
        speciesId: 'MAN16',
        rarity: EncounterRarity.uncommon,
      ), // Lightmane
      // Rare
      EncounterEntry(
        speciesId: 'HOR03',
        rarity: EncounterRarity.rare,
      ), // Earthhorn
      EncounterEntry(
        speciesId: 'HOR12',
        rarity: EncounterRarity.rare,
      ), // Planthorn
      EncounterEntry(
        speciesId: 'MSK16',
        rarity: EncounterRarity.rare,
      ), // Lightmask
      // Legendary
      EncounterEntry(
        speciesId: 'KIN03',
        rarity: EncounterRarity.legendary,
      ), // Earthkin
      EncounterEntry(
        speciesId: 'WNG12',
        rarity: EncounterRarity.legendary,
      ), // Plantwing
    ]);
  } else if (isNight(now)) {
    entries.addAll([
      // --- Night Spawns ---
      // Common
      EncounterEntry(
        speciesId: 'LET03',
        rarity: EncounterRarity.common,
      ), // Earthlet
      EncounterEntry(
        speciesId: 'LET15',
        rarity: EncounterRarity.common,
      ), // Darklet
      EncounterEntry(
        speciesId: 'LET14',
        rarity: EncounterRarity.rare,
      ), // Spiritlet
      // Uncommon
      EncounterEntry(
        speciesId: 'MAN03',
        rarity: EncounterRarity.uncommon,
      ), // Earthmane
      EncounterEntry(
        speciesId: 'MAN15',
        rarity: EncounterRarity.rare,
      ), // Darkmane
      EncounterEntry(
        speciesId: 'MAN14',
        rarity: EncounterRarity.rare,
      ), // Spiritmane
      // Rare
      EncounterEntry(
        speciesId: 'HOR15',
        rarity: EncounterRarity.rare,
      ), // Darkhorn
      EncounterEntry(
        speciesId: 'HOR14',
        rarity: EncounterRarity.rare,
      ), // Spirithorn
      EncounterEntry(
        speciesId: 'MSK15',
        rarity: EncounterRarity.rare,
      ), // Darkmask
      // Legendary
      EncounterEntry(
        speciesId: 'KIN15',
        rarity: EncounterRarity.legendary,
      ), // Darkkin
      EncounterEntry(
        speciesId: 'KIN14',
        rarity: EncounterRarity.legendary,
      ), // Spiritkin
    ]);
  }

  final sceneWide = EncounterPool(entries: entries);

  return (sceneWide: sceneWide, perSpawn: {});
}
