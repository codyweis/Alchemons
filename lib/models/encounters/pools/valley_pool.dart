import 'dart:math';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';

EncounterPool poolForSpawn({
  required String spawnId,
  required EncounterPool sceneWide,
  required Map<String, EncounterPool> perSpawn,
  bool unique = true, // This parameter is not used by the override logic
}) {
  // Check if there is an OVERRIDE pool for this specific spawnId
  final overridePool = perSpawn[spawnId];

  if (overridePool != null) {
    // If yes, return ONLY that pool. This creature is exclusive.
    return overridePool;
  }

  // Otherwise, return the normal scene-wide pool.
  return sceneWide;
}

/// Returns a scene-wide pool AND per-location *overrides*.
({EncounterPool sceneWide, Map<String, EncounterPool> perSpawn})
valleyEncounterPools(SceneDefinition scene) {
  bool isNight(DateTime now) => now.hour >= 20 || now.hour < 5;
  final now = DateTime.now();

  // 1. === DEFINE OVERRIDES FIRST ===
  // These pools are EXCLUSIVE to these spots, as requested.
  final perSpawn = <String, EncounterPool>{
    'SP_valley_05': EncounterPool(
      entries: [
        EncounterEntry(speciesId: 'WNG01', rarity: EncounterRarity.legendary),
        //add let
        EncounterEntry(speciesId: 'LET04', rarity: EncounterRarity.common),
      ],
    ),
    'SP_valley_04': EncounterPool(
      entries: [
        EncounterEntry(speciesId: 'WNG02', rarity: EncounterRarity.legendary),
        EncounterEntry(speciesId: 'LET04', rarity: EncounterRarity.common),
      ],
    ),
    'SP_valley_01': EncounterPool(
      entries: [
        // This spawn point can spawn two different exclusive creatures
        EncounterEntry(speciesId: 'WNG03', rarity: EncounterRarity.rare),
        EncounterEntry(speciesId: 'WNG04', rarity: EncounterRarity.legendary),
        EncounterEntry(speciesId: 'LET04', rarity: EncounterRarity.common),
      ],
    ),
  };

  // 2. === GET ALL EXCLUSIVE SPECIES ===
  // Collect every speciesId that is locked to a specific point.
  final exclusiveSpecies = perSpawn.values
      .expand((pool) => pool.entries) // Get all entries from all override pools
      .map((entry) => entry.speciesId) // Get their speciesId
      .toSet(); // Use a Set for fast filtering

  // 3. === DEFINE BASE SCENE-WIDE POOL ===
  // This is the "master list" of everything that *could* spawn.
  final List<EncounterEntry> baseEntries = isNight(now)
      ? [
          // --- Night Spawns ---
          // Exclusive (will be filtered out)

          // Regular scene-wide
          EncounterEntry(speciesId: 'LET03', rarity: EncounterRarity.common),
          EncounterEntry(speciesId: 'LET15', rarity: EncounterRarity.rare),
          EncounterEntry(speciesId: 'MAN03', rarity: EncounterRarity.uncommon),
          EncounterEntry(speciesId: 'KIN03', rarity: EncounterRarity.legendary),
        ]
      : [
          // --- Day Spawns ---
          // Exclusive (will be filtered out)

          // Regular scene-wide
          EncounterEntry(speciesId: 'LET03', rarity: EncounterRarity.common),
          EncounterEntry(speciesId: 'MAN12', rarity: EncounterRarity.rare),
          EncounterEntry(speciesId: 'LET16', rarity: EncounterRarity.rare),
          EncounterEntry(speciesId: 'MAN03', rarity: EncounterRarity.uncommon),
          EncounterEntry(speciesId: 'HOR03', rarity: EncounterRarity.rare),
          EncounterEntry(speciesId: 'WNG04', rarity: EncounterRarity.legendary),
          EncounterEntry(speciesId: 'WNG03', rarity: EncounterRarity.rare),
        ];

  // 4. === FILTER THE SCENE-WIDE POOL ===
  // Create the final list by removing any species that has an exclusive spot.
  final filteredEntries = baseEntries
      .where((entry) => !exclusiveSpecies.contains(entry.speciesId))
      .toList();

  final sceneWide = EncounterPool(entries: filteredEntries);

  // Return both the filtered scene-wide pool and the override map
  return (sceneWide: sceneWide, perSpawn: perSpawn);
}
