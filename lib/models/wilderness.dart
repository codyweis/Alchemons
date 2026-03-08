// models/wilderness.dart

import 'package:alchemons/models/creature.dart';
import 'package:flutter/material.dart';

class PartyMember {
  final String instanceId;

  const PartyMember({required this.instanceId});
}

class WildEncounter {
  final String wildBaseId; // e.g. CR045
  final double baseBreedChance; // e.g. 0.10 (10%)
  final String rarity; // for flavor text/rewards
  final ValueChanged<Creature>? onPartyCreatureSelected;

  /// When true the player entered a Rift Void — fusion offspring is
  /// guaranteed to be prismatic regardless of the normal RNG roll.
  final bool voidBred;

  /// Acquisition source tag written to the creature instance on capture/breed.
  /// Defaults to null (encounter_sheet falls back to 'wild_capture' / 'wild_fusion').
  final String? source;

  const WildEncounter({
    required this.wildBaseId,
    required this.baseBreedChance,
    required this.rarity,
    this.onPartyCreatureSelected,
    this.voidBred = false,
    this.source,
  });
}

enum EncounterPhase { scouting, presenting, tryingBreed, success, fail, fled }
