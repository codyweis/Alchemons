import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';

/// Returns a scene-wide pool plus per-location overrides for the Arcane Portal.
/// This biome is unlocked when every altar relic is placed.
/// It features Spirit, Crystal, Dark, Light, and Mystic creatures.
({EncounterPool sceneWide, Map<String, EncounterPool> perSpawn})
arcaneEncounterPools(SceneDefinition scene) {
  bool isNight(DateTime now) => now.hour >= 20 || now.hour < 5;
  final now = DateTime.now();

  final List<EncounterEntry> entries = [];

  // ── Always-available spawns ──────────────────────────────────────────────

  // Spirit family — common / uncommon
  entries.addAll([
    EncounterEntry(
      speciesId: 'LET14',
      rarity: EncounterRarity.common,
    ), // Spiritlet
    EncounterEntry(
      speciesId: 'PIP14',
      rarity: EncounterRarity.uncommon,
    ), // Spiritpip
    EncounterEntry(
      speciesId: 'MAN14',
      rarity: EncounterRarity.uncommon,
    ), // Spiritmane
  ]);

  // Crystal family — common / uncommon
  entries.addAll([
    EncounterEntry(
      speciesId: 'LET11',
      rarity: EncounterRarity.common,
    ), // Crystalet
    EncounterEntry(
      speciesId: 'PIP11',
      rarity: EncounterRarity.uncommon,
    ), // Crystalpip
    EncounterEntry(
      speciesId: 'MAN11',
      rarity: EncounterRarity.uncommon,
    ), // Crystalmane
  ]);

  // Dark family — uncommon / rare
  entries.addAll([
    EncounterEntry(
      speciesId: 'LET15',
      rarity: EncounterRarity.uncommon,
    ), // Darklet
    EncounterEntry(speciesId: 'PIP15', rarity: EncounterRarity.rare), // Darkpip
    EncounterEntry(
      speciesId: 'MSK15',
      rarity: EncounterRarity.rare,
    ), // Darkmask
  ]);

  // Light family — uncommon / rare
  entries.addAll([
    EncounterEntry(
      speciesId: 'LET16',
      rarity: EncounterRarity.uncommon,
    ), // Lightlet
    EncounterEntry(
      speciesId: 'PIP16',
      rarity: EncounterRarity.rare,
    ), // Lightpip
    EncounterEntry(
      speciesId: 'MSK16',
      rarity: EncounterRarity.rare,
    ), // Lightmask
  ]);

  // Rare evolved forms
  entries.addAll([
    EncounterEntry(
      speciesId: 'HOR14',
      rarity: EncounterRarity.rare,
    ), // Spirithorn
    EncounterEntry(
      speciesId: 'LET17',
      rarity: EncounterRarity.rare,
    ), // bloodlet
    EncounterEntry(
      speciesId: 'WNG14',
      rarity: EncounterRarity.rare,
    ), // Spiritwing
  ]);

  // ── Time-of-day specials ─────────────────────────────────────────────────

  if (isNight(now)) {
    // Night: more Dark & Spirit evolved forms
    entries.addAll([
      EncounterEntry(
        speciesId: 'HOR15',
        rarity: EncounterRarity.rare,
      ), // Darkhorn
      EncounterEntry(
        speciesId: 'WNG15',
        rarity: EncounterRarity.legendary,
      ), // Darkwing
      EncounterEntry(
        speciesId: 'MSK14',
        rarity: EncounterRarity.rare,
      ), // Spiritmask
      EncounterEntry(
        speciesId: 'KIN15',
        rarity: EncounterRarity.legendary,
      ), // Darkkin
      EncounterEntry(
        speciesId: 'KIN14',
        rarity: EncounterRarity.legendary,
      ), // Spiritkin
    ]);
  } else {
    // Day: more Light & Crystal evolved forms
    entries.addAll([
      EncounterEntry(
        speciesId: 'HOR16',
        rarity: EncounterRarity.rare,
      ), // Lighthorn
      EncounterEntry(
        speciesId: 'WNG16',
        rarity: EncounterRarity.legendary,
      ), // Lightwing
      EncounterEntry(
        speciesId: 'KIN16',
        rarity: EncounterRarity.legendary,
      ), // Lightkin
    ]);
  }

  // NOTE: No Mystic (MYS*) creatures spawn in the arcane biome.

  final sceneWide = EncounterPool(entries: entries);
  return (sceneWide: sceneWide, perSpawn: {});
}
