import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';

/// Returns a scene-wide pool plus per-location overrides (by SpawnPoint.id).
({EncounterPool sceneWide, Map<String, EncounterPool> perSpawn})
volcanoEncounterPools(SceneDefinition scene) {
  bool isNight(DateTime now) => now.hour >= 20 || now.hour < 5;
  bool isDay(DateTime now) => !isNight(now);
  final now = DateTime.now();

  final perSpawn = <String, EncounterPool>{
    'SP_volcano_03': EncounterPool(
      entries: [
        // Aerial ash perch — flying/floating creatures only
        EncounterEntry(
          speciesId: 'LET05',
          rarity: EncounterRarity.uncommon,
          weightMul: 0.45,
        ), // Steamlet (rises from lava)
        EncounterEntry(
          speciesId: 'LET14',
          rarity: EncounterRarity.uncommon,
          weightMul: 0.25,
          condition: isNight,
        ), // Spiritlet (floats)
        EncounterEntry(
          speciesId: 'WNG06',
          rarity: EncounterRarity.legendary,
          weightMul: 0.08,
          condition: isDay,
        ), // Lavawing
        EncounterEntry(
          speciesId: 'WNG01',
          rarity: EncounterRarity.legendary,
          weightMul: 0.08,
          condition: isDay,
        ), // Firewing
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
      speciesId: 'LET01',
      rarity: EncounterRarity.common,
      weightMul: 2.1,
    ), // Firelet
    EncounterEntry(
      speciesId: 'LET06',
      rarity: EncounterRarity.uncommon,
      weightMul: 0.4,
    ), // Lavalet
    EncounterEntry(
      speciesId: 'LET10',
      rarity: EncounterRarity.uncommon,
      weightMul: 0.3,
    ), // Dustlet (ash)

    EncounterEntry(
      speciesId: 'MAN01',
      rarity: EncounterRarity.uncommon,
      weightMul: 0.35,
    ), // Firemane
    EncounterEntry(
      speciesId: 'PIP06',
      rarity: EncounterRarity.uncommon,
      weightMul: 0.30,
    ), // Lavapip
    EncounterEntry(
      speciesId: 'PIP01',
      rarity: EncounterRarity.uncommon,
      weightMul: 0.3,
    ), // Firepip
    // Rare
    EncounterEntry(
      speciesId: 'HOR01',
      rarity: EncounterRarity.rare,
      weightMul: 0.2,
    ), // Firehorn
    EncounterEntry(
      speciesId: 'HOR06',
      rarity: EncounterRarity.rare,
      weightMul: 0.15,
    ), // Lavahorn
    EncounterEntry(
      speciesId: 'MSK01',
      rarity: EncounterRarity.rare,
      weightMul: 0.15,
    ), // Firemask
  ]);

  if (isDay(now)) {
    // Wings only spawn at aerial SP_volcano_03
  } else if (isNight(now)) {
    entries.addAll([
      // --- Night Spawns ---
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
      EncounterEntry(
        speciesId: 'MSK06',
        rarity: EncounterRarity.rare,
        weightMul: 0.12,
      ), // Lavamask
      //firekin
      EncounterEntry(
        speciesId: 'KIN01',
        rarity: EncounterRarity.legendary,
        weightMul: 0.06,
      ), // Firekin
      // Legendary
    ]);
  }

  final sceneWide = EncounterPool(entries: entries);

  return (sceneWide: sceneWide, perSpawn: perSpawn);
}
