import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';

// Geode Hollow, a realm bought in the shop (see models/shop_scenes.dart).
// Its reason to be bought: Alchemons the wild has nowhere else — the
// Crystal horn, mask, wing and kin, and the Darkhorn by night — and in its
// frostfall the Icemask and Icekin. Everything else here is Crystal and Ice.

/// Returns a scene-wide pool plus per-location overrides (by SpawnPoint.id).
({EncounterPool sceneWide, Map<String, EncounterPool> perSpawn})
geodeEncounterPools(SceneDefinition scene) {
  bool isNight(DateTime now) => now.hour >= 20 || now.hour < 5;
  final now = DateTime.now();

  // The air under the roof: only what flies or floats.
  const aloft = EncounterPool(
    entries: [
      EncounterEntry(
        speciesId: 'LET05',
        rarity: EncounterRarity.uncommon,
        weightMul: 0.6,
      ), // Steamlet, rising off the cold
      EncounterEntry(
        speciesId: 'WNG11',
        rarity: EncounterRarity.legendary,
        weightMul: 0.12,
      ), // Crystalwing — nowhere else in the wild
      EncounterEntry(
        speciesId: 'WNG09',
        rarity: EncounterRarity.legendary,
        weightMul: 0.08,
      ), // Icewing
    ],
  );
  final perSpawn = <String, EncounterPool>{
    'SP_geode_04': aloft,
    'SP_geode_08': aloft,
  };

  final entries = isNight(now)
      ? const [
          EncounterEntry(
            speciesId: 'LET11',
            rarity: EncounterRarity.common,
            weightMul: 1.3,
          ), // Crystalet
          EncounterEntry(
            speciesId: 'LET15',
            rarity: EncounterRarity.uncommon,
            weightMul: 0.3,
          ), // Darklet
          EncounterEntry(
            speciesId: 'PIP11',
            rarity: EncounterRarity.uncommon,
            weightMul: 0.35,
          ), // Crystalpip
          EncounterEntry(
            speciesId: 'MAN11',
            rarity: EncounterRarity.uncommon,
            weightMul: 0.3,
          ), // Crystalmane
          EncounterEntry(
            speciesId: 'HOR15',
            rarity: EncounterRarity.rare,
            weightMul: 0.14,
          ), // Darkhorn — nowhere else in the wild
          EncounterEntry(
            speciesId: 'MSK11',
            rarity: EncounterRarity.rare,
            weightMul: 0.16,
          ), // Crystalmask — nowhere else in the wild
          EncounterEntry(
            speciesId: 'HOR11',
            rarity: EncounterRarity.rare,
            weightMul: 0.12,
          ), // Crystalhorn — nowhere else in the wild
          EncounterEntry(
            speciesId: 'KIN11',
            rarity: EncounterRarity.legendary,
            weightMul: 0.08,
          ), // Crystalkin — nowhere else in the wild
        ]
      : const [
          EncounterEntry(
            speciesId: 'LET11',
            rarity: EncounterRarity.common,
            weightMul: 1.5,
          ), // Crystalet
          EncounterEntry(
            speciesId: 'LET09',
            rarity: EncounterRarity.common,
            weightMul: 0.7,
          ), // Icelet
          EncounterEntry(
            speciesId: 'PIP11',
            rarity: EncounterRarity.uncommon,
            weightMul: 0.4,
          ), // Crystalpip
          EncounterEntry(
            speciesId: 'MAN11',
            rarity: EncounterRarity.uncommon,
            weightMul: 0.35,
          ), // Crystalmane
          EncounterEntry(
            speciesId: 'PIP09',
            rarity: EncounterRarity.uncommon,
            weightMul: 0.3,
          ), // Icepip
          EncounterEntry(
            speciesId: 'HOR11',
            rarity: EncounterRarity.rare,
            weightMul: 0.16,
          ), // Crystalhorn — nowhere else in the wild
          EncounterEntry(
            speciesId: 'MSK11',
            rarity: EncounterRarity.rare,
            weightMul: 0.12,
          ), // Crystalmask — nowhere else in the wild
          EncounterEntry(
            speciesId: 'KIN11',
            rarity: EncounterRarity.legendary,
            weightMul: 0.07,
          ), // Crystalkin — nowhere else in the wild
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

/// A frostfall in Geode Hollow. About one Geode batch in five comes with
/// one, day or night, and brings Ice Alchemons with it: at least one, and
/// each other creature of the batch half the time. They stand on the floor
/// and the ledge; only the Icewing takes the air. The Icemask and Icekin are
/// found nowhere else in the wild. The first clear visit after it finds the
/// cave rimed white.
const geodeFrostfall = WildWeather(
  kind: WeatherKind.frostfall,
  label: 'FROSTFALL',
  aftermath: true,
  chance: 0.2,
  guaranteed: 1,
  extra: 0.5,
  pool: EncounterPool(
    entries: [
      EncounterEntry(speciesId: 'LET09', rarity: EncounterRarity.common),
      EncounterEntry(speciesId: 'PIP09', rarity: EncounterRarity.uncommon),
      EncounterEntry(speciesId: 'MAN09', rarity: EncounterRarity.uncommon),
      EncounterEntry(speciesId: 'MSK09', rarity: EncounterRarity.rare),
      EncounterEntry(speciesId: 'KIN09', rarity: EncounterRarity.legendary),
      EncounterEntry(
        speciesId: 'WNG09',
        rarity: EncounterRarity.legendary,
        weightMul: 1.5,
      ),
    ],
  ),
);

/// Geode Hollow singing. About one Geode batch in seven comes with it (a
/// frostfall and the singing never come together), day or night: light
/// rolls through every crystal on its own, and Light and Spirit Alchemons
/// come to it — at least one, and each other creature of the batch half the
/// time. The Spiritwing is found nowhere else in the wild.
const geodeSinging = WildWeather(
  kind: WeatherKind.singing,
  label: 'SINGING',
  chance: 0.15,
  guaranteed: 1,
  extra: 0.5,
  pool: EncounterPool(
    entries: [
      EncounterEntry(speciesId: 'LET16', rarity: EncounterRarity.common),
      EncounterEntry(speciesId: 'LET14', rarity: EncounterRarity.common),
      EncounterEntry(speciesId: 'MSK16', rarity: EncounterRarity.rare),
      EncounterEntry(speciesId: 'MSK14', rarity: EncounterRarity.rare),
      EncounterEntry(speciesId: 'WNG14', rarity: EncounterRarity.legendary),
    ],
  ),
);
