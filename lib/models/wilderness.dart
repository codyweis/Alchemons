// models/wilderness.dart

class PartyMember {
  final String instanceId;
  final double luck; // derived from genes/nature/species if you like

  const PartyMember({required this.instanceId, this.luck = 0.0});
}

class WildEncounter {
  final String wildBaseId; // e.g. CR045
  final double baseBreedChance; // e.g. 0.10 (10%)
  final String rarity; // for flavor text/rewards

  const WildEncounter({
    required this.wildBaseId,
    required this.baseBreedChance,
    required this.rarity,
  });
}

enum EncounterPhase { scouting, presenting, tryingBreed, success, fail, fled }
