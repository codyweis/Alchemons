import 'package:alchemons/games/wilderness/field/grain_field.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';

// The Tidal Shelf, a realm bought in the shop (see models/shop_scenes.dart).
// Its reason to be bought: Alchemons the wild has nowhere else — the
// Watermask, out on the columns; the Mudmask and Mudkin, only while the tide
// is out and the flat is bare; and the Waterkin, only in a swell.

/// Whether the tide is out at [now]: the bottom third of its range.
bool tidalLowWater(DateTime now) => TidalField.tideAt(now) < 0.35;

/// Returns a scene-wide pool plus per-location overrides (by SpawnPoint.id).
({EncounterPool sceneWide, Map<String, EncounterPool> perSpawn})
tidalEncounterPools(SceneDefinition scene) {
  bool isNight(DateTime now) => now.hour >= 20 || now.hour < 5;
  final now = DateTime.now();

  // The air over the sea: only what flies or floats.
  const aloft = EncounterPool(
    entries: [
      EncounterEntry(
        speciesId: 'LET04',
        rarity: EncounterRarity.common,
        weightMul: 0.6,
      ), // Airlet
      EncounterEntry(
        speciesId: 'LET05',
        rarity: EncounterRarity.uncommon,
        weightMul: 0.35,
      ), // Steamlet, off the spray
      EncounterEntry(
        speciesId: 'WNG02',
        rarity: EncounterRarity.legendary,
        weightMul: 0.12,
      ), // Waterwing
    ],
  );
  final perSpawn = <String, EncounterPool>{
    'SP_tidal_04': aloft,
    'SP_tidal_08': aloft,
  };

  final entries = [
    const EncounterEntry(
      speciesId: 'LET02',
      rarity: EncounterRarity.common,
      weightMul: 1.5,
    ), // Waterlet
    const EncounterEntry(
      speciesId: 'PIP02',
      rarity: EncounterRarity.uncommon,
      weightMul: 0.4,
    ), // Waterpip
    const EncounterEntry(
      speciesId: 'MAN02',
      rarity: EncounterRarity.uncommon,
      weightMul: 0.35,
    ), // Watermane
    const EncounterEntry(
      speciesId: 'HOR02',
      rarity: EncounterRarity.rare,
      weightMul: 0.16,
    ), // Waterhorn
    const EncounterEntry(
      speciesId: 'MSK02',
      rarity: EncounterRarity.rare,
      weightMul: 0.14,
    ), // Watermask — nowhere else in the wild
    if (isNight(now))
      const EncounterEntry(
        speciesId: 'LET14',
        rarity: EncounterRarity.uncommon,
        weightMul: 0.2,
      ), // Spiritlet, over the dark water
    // The flat bare: the mud's own come out onto it.
    if (tidalLowWater(now)) ...const [
      EncounterEntry(
        speciesId: 'LET08',
        rarity: EncounterRarity.common,
        weightMul: 0.9,
      ), // Mudlet
      EncounterEntry(
        speciesId: 'PIP08',
        rarity: EncounterRarity.uncommon,
        weightMul: 0.35,
      ), // Mudpip
      EncounterEntry(
        speciesId: 'MSK08',
        rarity: EncounterRarity.rare,
        weightMul: 0.14,
      ), // Mudmask — nowhere else in the wild
      EncounterEntry(
        speciesId: 'KIN08',
        rarity: EncounterRarity.legendary,
        weightMul: 0.08,
      ), // Mudkin — nowhere else in the wild
    ],
  ];

  final exclusive = {
    for (final p in perSpawn.values) ...p.entries,
  }.map((e) => e.speciesId).toSet();
  final sceneWide = EncounterPool(
    entries: [
      for (final e in entries)
        if (!exclusive.contains(e.speciesId)) e,
    ],
  );
  return (sceneWide: sceneWide, perSpawn: perSpawn);
}

/// Sea fog on the Tidal Shelf. About one batch in six comes with it, day or
/// night, and Spirit Alchemons come out of it: at least one, and each other
/// creature of the batch half the time.
const tidalFog = WildWeather(
  kind: WeatherKind.fog,
  label: 'FOG',
  chance: 0.16,
  guaranteed: 1,
  extra: 0.5,
  pool: EncounterPool(
    entries: [
      EncounterEntry(speciesId: 'LET14', rarity: EncounterRarity.common),
      EncounterEntry(speciesId: 'PIP14', rarity: EncounterRarity.uncommon),
      EncounterEntry(speciesId: 'MAN14', rarity: EncounterRarity.uncommon),
      EncounterEntry(speciesId: 'MSK14', rarity: EncounterRarity.rare),
      EncounterEntry(speciesId: 'KIN14', rarity: EncounterRarity.legendary),
    ],
  ),
);

/// A swell on the Tidal Shelf. About one batch in six comes with it (never
/// with fog), day or night, and brings Water Alchemons up the columns with
/// it: at least one, and each other creature of the batch half the time.
/// The Waterkin is found nowhere else in the wild. The first clear visit
/// after it finds shells and glass floats left on the sand.
const tidalSwell = WildWeather(
  kind: WeatherKind.swell,
  label: 'SWELL',
  aftermath: true,
  chance: 0.16,
  guaranteed: 1,
  extra: 0.5,
  pool: EncounterPool(
    entries: [
      EncounterEntry(speciesId: 'LET02', rarity: EncounterRarity.common),
      EncounterEntry(speciesId: 'MAN02', rarity: EncounterRarity.uncommon),
      EncounterEntry(speciesId: 'HOR02', rarity: EncounterRarity.rare),
      EncounterEntry(speciesId: 'MSK02', rarity: EncounterRarity.rare),
      EncounterEntry(speciesId: 'KIN02', rarity: EncounterRarity.legendary),
    ],
  ),
);
