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
        EncounterEntry(
          speciesId: 'LET01',
          rarity: EncounterRarity.common,
          weightMul: 0.7,
        ),
        EncounterEntry(
          speciesId: 'LET10',
          rarity: EncounterRarity.uncommon,
          weightMul: 0.35,
        ),
        EncounterEntry(
          speciesId: 'LET14',
          rarity: EncounterRarity.rare,
          weightMul: 0.12,
          condition: isNight,
        ),
        EncounterEntry(
          speciesId: 'WNG06',
          rarity: EncounterRarity.legendary,
          weightMul: 0.08,
          condition: isDay,
        ),
        EncounterEntry(
          speciesId: 'WNG01',
          rarity: EncounterRarity.legendary,
          weightMul: 0.08,
          condition: isDay,
        ),
        EncounterEntry(
          speciesId: 'MSK14',
          rarity: EncounterRarity.legendary,
          weightMul: 0.06,
          condition: isNight,
        ),
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
      rarity: EncounterRarity.rare,
      weightMul: 0.18,
    ), // Lavapip
    EncounterEntry(
      speciesId: 'PIP01',
      rarity: EncounterRarity.uncommon,
      weightMul: 0.3,
    ), // Lavamane
    // Rare
    EncounterEntry(
      speciesId: 'HOR01',
      rarity: EncounterRarity.rare,
      weightMul: 0.2,
    ), // Firehorn
    EncounterEntry(
      speciesId: 'HOR06',
      rarity: EncounterRarity.legendary,
      weightMul: 0.08,
    ), // Lavahorn
    EncounterEntry(
      speciesId: 'MSK01',
      rarity: EncounterRarity.rare,
      weightMul: 0.15,
    ), // Firemask
  ]);

  if (isDay(now)) {
    entries.addAll([
      EncounterEntry(
        speciesId: 'WNG06',
        rarity: EncounterRarity.legendary,
        weightMul: 0.08,
      ), // Lavawing
      //firewing
      EncounterEntry(
        speciesId: 'WNG01',
        rarity: EncounterRarity.legendary,
        weightMul: 0.08,
      ), // Firewing
    ]);
  } else if (isNight(now)) {
    entries.addAll([
      // --- Night Spawns ---
      // Spirit
      EncounterEntry(
        speciesId: 'LET14',
        rarity: EncounterRarity.rare,
        weightMul: 0.1,
      ), // Spiritlet
      EncounterEntry(
        speciesId: 'MSK14',
        rarity: EncounterRarity.legendary,
        weightMul: 0.08,
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
