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
    if (_isHeart) return _heartPreview(a);
    return null;
  }

  bool _planningNear(DungeonCreature a, Offset? at) =>
      at != null && (a.position - at).distance <= 100;

  String _planRoom(String id) =>
      _roomIdentityLine(id) ?? id.replaceAll('_', ' ');

  /// The Black Sun shows its aim on the floor itself (a ghost mouth on the
  /// face a Dark is looking at); a line in the capsule would say it twice.
  String? _vaultPreview(DungeonCreature a) => null;

  String? _heartPreview(DungeonCreature a) {
    for (final o in ostiaIn(currentRoomId)) {
      if (!_planningNear(a, o.position) || heart.ostiaPrimed.contains(o.id)) {
        continue;
      }
      return '${o.element} · prime on ${phaseTag(o.phase)}\n'
          'Lay a hand, then use NEXT PULSE to reach its phase. Stay in this room.';
    }
    // The exits in the NEXT phase make the skip a route decision, not a blind
    // fast-forward. Hidden collaterals remain undisclosed until grafted.
    final next = nextPulsePhase(heart.phase);
    final exits = <String>[];
    for (final d in currentRoom.doors) {
      final p = _heartPassageFor(currentRoom, d);
      if (p == null || _heartDoorHidden(currentRoom, d)) continue;
      if (_guardianDoorSealed(d) || _guardianFightSeal(currentRoom)) continue;
      final finale = layout.finaleDoor;
      if (finale != null &&
          finale.matches(currentRoom, d) &&
          !guardianRiteUnlocked) {
        continue;
      }
      if (p.carriesFrom(
        currentRoomId,
        next,
        grafted: heart.grafted.contains(p.id),
      )) {
        exits.add(_planRoom(d.targetRoomId));
      }
    }
    return 'Next pulse · ${phaseTag(next)}\n'
        '${exits.isEmpty ? 'No flowing exits; another phase will open them' : 'Routes: ${exits.join(', ')}'}. '
        'Advance when ready.';
  }
}
