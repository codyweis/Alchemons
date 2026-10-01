import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';

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
        // Cloud layer — air/steam only
        EncounterEntry(
          speciesId: 'LET04',
          rarity: EncounterRarity.common,
          weightMul: 0.75,
        ),
        EncounterEntry(
          speciesId: 'LET05',
          rarity: EncounterRarity.uncommon,
          weightMul: 0.35,
        ),
      ],
    ),
    'SP_valley_04': EncounterPool(
      entries: [
        EncounterEntry(
          speciesId: 'LET03',
          rarity: EncounterRarity.common,
          weightMul: 0.85,
        ),
        EncounterEntry(
          speciesId: 'MAN03',
          rarity: EncounterRarity.uncommon,
          weightMul: 0.35,
        ),
        EncounterEntry(
          speciesId: 'HOR03',
          rarity: EncounterRarity.rare,
          weightMul: 0.16,
        ),
      ],
    ),
    'SP_valley_01': EncounterPool(
      entries: [
        // Sky area — flying creatures only
        EncounterEntry(
          speciesId: 'WNG03',
          rarity: EncounterRarity.legendary,
          weightMul: 0.08,
        ),
        EncounterEntry(
          speciesId: 'WNG04',
          rarity: EncounterRarity.legendary,
          weightMul: 0.08,
        ),
        EncounterEntry(
          speciesId: 'LET04',
          rarity: EncounterRarity.common,
          weightMul: 0.75,
        ),
      ],
    ),
    'SP_valley_08': EncounterPool(
      entries: [
        // Cloud layer — air/flying only
        EncounterEntry(
          speciesId: 'WNG03',
          rarity: EncounterRarity.legendary,
          weightMul: 0.08,
        ),
        EncounterEntry(
          speciesId: 'LET04',
          rarity: EncounterRarity.common,
          weightMul: 0.75,
        ),
        EncounterEntry(
          speciesId: 'LET05',
          rarity: EncounterRarity.uncommon,
          weightMul: 0.35,
        ),
      ],
    ),
  };

  // 2. === GET ALL EXCLUSIVE SPECIES ===
  // Collect every speciesId that is locked to a specific point.
  // LET03/LET04 appear in overrides but should still be in scene-wide.
  final exclusiveSpecies = perSpawn.values
      .expand((pool) => pool.entries) // Get all entries from all override pools
      .map((entry) => entry.speciesId) // Get their speciesId
      .where((id) => id != 'LET03' && id != 'LET04')
      .toSet(); // Use a Set for fast filtering

  // 3. === DEFINE BASE SCENE-WIDE POOL ===
  // This is the "master list" of everything that *could* spawn.
  final List<EncounterEntry> baseEntries = isNight(now)
      ? [
          // --- Night Spawns ---
          // Exclusive (will be filtered out)

          // Regular scene-wide
          EncounterEntry(
            speciesId: 'LET03',
            rarity: EncounterRarity.common,
            weightMul: 0.55,
          ),
          EncounterEntry(
            speciesId: 'LET15',
            rarity: EncounterRarity.uncommon,
            weightMul: 0.25,
          ),
          EncounterEntry(
            speciesId: 'MAN03',
            rarity: EncounterRarity.uncommon,
            weightMul: 0.35,
          ),
          EncounterEntry(
            speciesId: 'KIN03',
            rarity: EncounterRarity.legendary,
            weightMul: 0.08,
          ),
        ]
      : [
          // --- Day Spawns ---
          // Exclusive (will be filtered out)

          // Regular scene-wide
          EncounterEntry(
            speciesId: 'LET03',
            rarity: EncounterRarity.common,
            weightMul: 0.75,
          ),
          EncounterEntry(
            speciesId: 'MAN12',
            rarity: EncounterRarity.uncommon,
            weightMul: 0.30,
          ),
          EncounterEntry(
            speciesId: 'LET16',
            rarity: EncounterRarity.uncommon,
            weightMul: 0.25,
          ),
          EncounterEntry(
            speciesId: 'MAN03',
            rarity: EncounterRarity.uncommon,
            weightMul: 0.35,
          ),
          EncounterEntry(
            speciesId: 'HOR03',
            rarity: EncounterRarity.rare,
            weightMul: 0.18,
          ),
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

/// Rain over the Valley. One Valley batch in four comes with it, day or
/// night, and brings Water Alchemons out into it: at least one, and each
/// other creature of the batch half the time. They stand in the meadow and
/// on the hill — only the Waterwing can take the open air. The first clear
/// visit after a rainy one is guaranteed a rainbow (a moonbow by night).
const valleyRain = WildWeather(
  kind: WeatherKind.rain,
  label: 'RAIN',
  aftermath: true,
  chance: 0.25,
  guaranteed: 1,
  extra: 0.5,
  pool: EncounterPool(
    entries: [
      EncounterEntry(speciesId: 'LET02', rarity: EncounterRarity.common),
      EncounterEntry(speciesId: 'PIP02', rarity: EncounterRarity.uncommon),
      EncounterEntry(speciesId: 'MAN02', rarity: EncounterRarity.uncommon),
      EncounterEntry(speciesId: 'HOR02', rarity: EncounterRarity.rare),
      EncounterEntry(
        speciesId: 'WNG02',
        rarity: EncounterRarity.legendary,
        weightMul: 1.5,
      ),
    ],
  ),
);

/// Snow over the Valley. About one Valley batch in seven comes with it
/// (rain and snow never come together), day or night, and Ice Alchemons are
/// far likelier in it: each creature of the batch is Ice six times in ten —
/// likely, not certain. They stand in the meadow and on the hill; only the
/// Icewing can take the open air.
const valleySnow = WildWeather(
  kind: WeatherKind.snow,
  label: 'SNOW',
  chance: 0.15,
  guaranteed: 0,
  extra: 0.6,
  pool: EncounterPool(
    entries: [
      EncounterEntry(speciesId: 'LET09', rarity: EncounterRarity.common),
      EncounterEntry(speciesId: 'PIP09', rarity: EncounterRarity.uncommon),
      EncounterEntry(speciesId: 'MAN09', rarity: EncounterRarity.uncommon),
      EncounterEntry(speciesId: 'HOR09', rarity: EncounterRarity.rare),
      EncounterEntry(
        speciesId: 'WNG09',
        rarity: EncounterRarity.legendary,
        weightMul: 1.5,
      ),
    ],
  ),
);
