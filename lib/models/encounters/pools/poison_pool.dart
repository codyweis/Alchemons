import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';

/// Poison-only wilderness pool for the poison elemental pathway.
({EncounterPool sceneWide, Map<String, EncounterPool> perSpawn})
poisonEncounterPools(SceneDefinition scene) {
  final entries = <EncounterEntry>[
    EncounterEntry(speciesId: 'LET13', rarity: EncounterRarity.common),
    EncounterEntry(speciesId: 'MAN13', rarity: EncounterRarity.uncommon),
    EncounterEntry(speciesId: 'PIP13', rarity: EncounterRarity.uncommon),
    EncounterEntry(speciesId: 'HOR13', rarity: EncounterRarity.rare),
    EncounterEntry(speciesId: 'MSK13', rarity: EncounterRarity.rare),
    EncounterEntry(speciesId: 'WNG13', rarity: EncounterRarity.legendary),
    EncounterEntry(speciesId: 'KIN13', rarity: EncounterRarity.legendary),
  ];

  return (
    sceneWide: EncounterPool(entries: entries),
    perSpawn: <String, EncounterPool>{},
  );
}
