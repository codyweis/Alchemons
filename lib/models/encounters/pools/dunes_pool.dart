import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';

// The Glass Dunes, a realm bought in the shop (see models/shop_scenes.dart).
// Its reason to be bought: Alchemons the wild has nowhere else — Dustkin,
// Earthpip, Earthmask and Lightmane in the sand, and in its sandstorms
// Airmask, Lightningmask and the Air and Lightning kin. Everything else here
// is Dust, Earth and the desert's light.

/// Returns a scene-wide pool plus per-location overrides (by SpawnPoint.id).
({EncounterPool sceneWide, Map<String, EncounterPool> perSpawn})
dunesEncounterPools(SceneDefinition scene) {
  bool isNight(DateTime now) => now.hour >= 20 || now.hour < 5;
  final now = DateTime.now();

  // The open air over the great dunes: only what flies or floats.
  const aloft = EncounterPool(
    entries: [
      EncounterEntry(
        speciesId: 'LET04',
        rarity: EncounterRarity.common,
        weightMul: 0.8,
      ), // Airlet
      EncounterEntry(
        speciesId: 'MSK04',
        rarity: EncounterRarity.rare,
        weightMul: 0.14,
      ), // Airmask — nowhere else in the wild
      EncounterEntry(
        speciesId: 'WNG10',
        rarity: EncounterRarity.legendary,
        weightMul: 0.1,
      ), // Dustwing
    ],
  );
  final perSpawn = <String, EncounterPool>{
    'SP_dunes_04': aloft,
    'SP_dunes_08': aloft,
  };

  final entries = isNight(now)
      ? const [
          EncounterEntry(
            speciesId: 'LET10',
            rarity: EncounterRarity.common,
            weightMul: 1.4,
          ), // Dustlet
          EncounterEntry(
            speciesId: 'LET15',
            rarity: EncounterRarity.uncommon,
            weightMul: 0.25,
          ), // Darklet
          EncounterEntry(
            speciesId: 'PIP10',
            rarity: EncounterRarity.uncommon,
            weightMul: 0.4,
          ), // Dustpip
          EncounterEntry(
            speciesId: 'MAN10',
            rarity: EncounterRarity.uncommon,
            weightMul: 0.35,
          ), // Dustmane
          EncounterEntry(
            speciesId: 'MSK10',
            rarity: EncounterRarity.rare,
            weightMul: 0.16,
          ), // Dustmask, out by night
          EncounterEntry(
            speciesId: 'MSK03',
            rarity: EncounterRarity.rare,
            weightMul: 0.12,
          ), // Earthmask — nowhere else in the wild
          EncounterEntry(
            speciesId: 'HOR10',
            rarity: EncounterRarity.rare,
            weightMul: 0.16,
          ), // Dusthorn
          EncounterEntry(
            speciesId: 'KIN10',
            rarity: EncounterRarity.legendary,
            weightMul: 0.08,
          ), // Dustkin — nowhere else in the wild
        ]
      : const [
          EncounterEntry(
            speciesId: 'LET10',
            rarity: EncounterRarity.common,
            weightMul: 1.6,
          ), // Dustlet
          EncounterEntry(
            speciesId: 'LET03',
            rarity: EncounterRarity.common,
            weightMul: 0.6,
          ), // Earthlet
          EncounterEntry(
            speciesId: 'PIP10',
            rarity: EncounterRarity.uncommon,
            weightMul: 0.4,
          ), // Dustpip
          EncounterEntry(
            speciesId: 'PIP03',
            rarity: EncounterRarity.uncommon,
            weightMul: 0.32,
          ), // Earthpip — nowhere else in the wild
          EncounterEntry(
            speciesId: 'MAN10',
            rarity: EncounterRarity.uncommon,
            weightMul: 0.35,
          ), // Dustmane
          EncounterEntry(
            speciesId: 'HOR10',
            rarity: EncounterRarity.rare,
            weightMul: 0.2,
          ), // Dusthorn
          EncounterEntry(
            speciesId: 'MAN16',
            rarity: EncounterRarity.rare,
            weightMul: 0.14,
          ), // Lightmane, in the desert sun — nowhere else in the wild
          EncounterEntry(
            speciesId: 'MSK03',
            rarity: EncounterRarity.rare,
            weightMul: 0.1,
          ), // Earthmask — nowhere else in the wild
          EncounterEntry(
            speciesId: 'KIN10',
            rarity: EncounterRarity.legendary,
            weightMul: 0.07,
          ), // Dustkin — nowhere else in the wild
        ];

  // Day or night alike, nothing the air points hold is rolled on the sand.
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

/// A sandstorm over the Glass Dunes. About one Dunes batch in five comes
/// with one, day or night, and brings the storm's Alchemons with it: at
/// least one, and each other creature of the batch half the time. Air and
/// Lightning float, so any point can take them; the masks and kin here are
/// found nowhere else in the wild. The first clear visit after a storm
/// finds the glass its lightning left in the sand.
const dunesSandstorm = WildWeather(
  kind: WeatherKind.sandstorm,
  label: 'SANDSTORM',
  aftermath: true,
  chance: 0.2,
  guaranteed: 1,
  extra: 0.5,
  pool: EncounterPool(
    entries: [
      EncounterEntry(speciesId: 'LET04', rarity: EncounterRarity.common),
      EncounterEntry(speciesId: 'LET07', rarity: EncounterRarity.common),
      EncounterEntry(speciesId: 'PIP07', rarity: EncounterRarity.uncommon),
      EncounterEntry(speciesId: 'MSK04', rarity: EncounterRarity.rare),
      EncounterEntry(speciesId: 'MSK07', rarity: EncounterRarity.rare),
      EncounterEntry(speciesId: 'KIN04', rarity: EncounterRarity.legendary),
      EncounterEntry(speciesId: 'KIN07', rarity: EncounterRarity.legendary),
    ],
  ),
);
