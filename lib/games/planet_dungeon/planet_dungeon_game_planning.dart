part of 'planet_dungeon_game.dart';

/// A nearby control's consequences, shown before committing. These readings
/// describe the rules, not the solution, and never mutate the live puzzle.
extension DungeonPlanning on PlanetDungeonGame {
  String? get puzzlePreview {
    final a = active;
    if (a == null || isRaid || hasCombatTargets || inGuardianFight) return null;
    if (!entryDoorRevealed) return null;
    if (_isConservatory) return _conservatoryPreview(a);
    // Requia shows a flag's flips on the floor itself; walking the court
    // should not raise a line on every square (the author, 2026-09-28).
    if (_isFuneral) return null;
    if (_isVault) return _vaultPreview(a);
    // The Beacon Archive shows NEXT PRESS in the readout instead; a line in
    // the capsule at every beacon covered the room (the author, 2026-09-28).
    if (_isArchive) return null;
    // The Blood Rites show their previews in the rooms themselves (the
    // Water room's flip ghost); nothing to say in the capsule.
    return null;
  }

  /// The Black Sun shows its aim on the floor itself (a ghost mouth on the
  /// face a Dark is looking at); a line in the capsule would say it twice.
  String? _vaultPreview(DungeonCreature a) => null;
}
