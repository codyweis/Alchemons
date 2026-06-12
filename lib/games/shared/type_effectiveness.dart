// lib/games/shared/type_effectiveness.dart
//
// Element type-effectiveness chart shared by the real-time combat modes.
// Extracted from the retired turn-based battle engine so the matchup rules
// stay identical everywhere.

/// attacker element → elements it is super effective (x2) against.
const Map<String, List<String>> kTypeChart = {
  'Fire': ['Plant', 'Ice'],
  'Water': ['Fire', 'Lava', 'Dust'],
  'Earth': ['Fire', 'Lightning', 'Poison'],
  'Air': ['Plant', 'Mud'],
  'Plant': ['Water', 'Earth', 'Mud'],
  'Ice': ['Plant', 'Earth', 'Air'],
  'Lightning': ['Water', 'Air'],
  'Poison': ['Plant', 'Water'],
  'Steam': ['Ice', 'Plant'],
  'Lava': ['Ice', 'Plant', 'Crystal'],
  'Mud': ['Fire', 'Lightning', 'Poison'],
  'Dust': ['Fire', 'Lightning'],
  'Crystal': ['Ice', 'Lightning'],
  'Spirit': ['Poison', 'Blood'],
  'Blood': ['Spirit', 'Earth'],
  'Light': ['Dark', 'Spirit', 'Poison'],
  'Dark': ['Light', 'Spirit'],
};

/// x2 when the attack type is strong against any defender type, x0.5 when a
/// defender type is strong against the attack type, x1 otherwise.
double typeEffectivenessMultiplier(
  String attackType,
  List<String> defenderTypes,
) {
  for (final defenderType in defenderTypes) {
    if (kTypeChart[attackType]?.contains(defenderType) ?? false) {
      return 2.0;
    }
    if (kTypeChart[defenderType]?.contains(attackType) ?? false) {
      return 0.5;
    }
  }
  return 1.0;
}
