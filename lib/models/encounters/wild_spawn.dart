// lib/models/encounters/wild_spawn.dart
import 'package:alchemons/models/encounters/encounter_pool.dart';

class WildSpawn {
  final String speciesId;
  final EncounterRarity rarity;
  final String spawnPointId;

  const WildSpawn({
    required this.speciesId,
    required this.rarity,
    required this.spawnPointId,
  });
}
