part of 'planet_dungeon_game.dart';

/// A nearby control's consequences, shown before committing. These readings
/// describe the rules, not the solution, and never mutate the live puzzle.
extension DungeonPlanning on PlanetDungeonGame {
  String? get puzzlePreview {
    final a = active;
    if (a == null || isRaid || hasCombatTargets || inGuardianFight) return null;
    if (!entryDoorRevealed) return null;
    if (_isCrypt) return _cryptPreview(a);
    if (_isWake) return _gravePreview(a);
    if (_isVault) return _vaultPreview(a);
    if (_isArchive) return _archivePreview(a);
    if (_isHeart) return _heartPreview(a);
    return null;
  }

  bool _planningNear(DungeonCreature a, Offset? at) =>
      at != null && (a.position - at).distance <= 100;

  String _planRoom(String id) =>
      _roomIdentityLine(id) ?? id.replaceAll('_', ' ');

  String? _cryptPreview(DungeonCreature a) {
    final g = currentRoom.grove;
    if (_planningNear(a, g?.bole)) {
      return 'Plant · change to ${crypt.isTiny ? 'full size' : 'tiny'}\n'
          'Tiny fits cracks; full size crosses steps. Beds grow roads for the other size.';
    }
    if (_planningNear(a, g?.mulchPit)) {
      return 'Mud · reset the garden\n'
          'Two presses remove every vine and return you to the gate. Lamp and altar progress stays.';
    }
    final lamp = _lampIn(currentRoom);
    if (lamp != null && _planningNear(a, lamp.position)) {
      return crypt.lampsLit.contains(lamp.id)
          ? 'Lamp lit · ${crypt.lampsLit.length}/${kGraveLamps.length}'
          : 'Light · light the lamp\n'
                'Requires ${lamp.reach == PlantScale.tiny ? 'tiny' : 'full'} size. '
                '${crypt.lampsLit.length}/${kGraveLamps.length} lit.';
    }
    if (_planningNear(a, g?.growthAltar)) {
      return 'Growth altar · ${crypt.bloomStep}/3\n'
          'Mud at full size → Plant while tiny → Light Mask at full size.';
    }
    for (final b in cryptBedsIn(currentRoomId)) {
      if (!_planningNear(a, b.crown)) continue;
      if (!crypt.canPlant(b.id)) {
        return '${crypt.stateOf(b.id) == VineState.trunk ? 'Trunk' : 'Creeper'} planted\n'
            'Mud at a mulch pit resets the garden; your star progress stays.';
      }
      final need = crypt.isTiny ? SpanNeed.trunk : SpanNeed.creeper;
      final spans = kCryptSpans.where((s) => s.bedId == b.id);
      final road = spans.firstWhere((s) => s.need == need);
      final far = road.from == currentRoomId ? road.to : road.from;
      final fissure = spans
          .where((s) => s.need == SpanNeed.fissure)
          .firstOrNull;
      final cost = crypt.isTiny && fissure != null
          ? 'Closes the crack to ${_planRoom(fissure.from == currentRoomId ? fissure.to : fissure.from)}.'
          : 'Keeps the crack open.';
      return 'Plant · ${crypt.isTiny ? 'grow trunk' : 'grow creeper'}\n'
          '${crypt.isTiny ? 'Full-size' : 'Tiny'} road to ${_planRoom(far)}. $cost';
    }
    return null;
  }

  String? _gravePreview(DungeonCreature a) {
    for (final r in graveRevenantsIn(currentRoomId)) {
      if (!_planningNear(a, r.seat) || _field.isRested(r.id)) continue;
      final x = graveCrossingById(r.crossingId)!;
      return 'Spirit · lay ${r.name} to rest${_field.isGhost ? '' : ' in the ghost world'}\n'
          '${_planRoom(x.from)} ↔ ${_planRoom(x.to)}: opens for the living, closes for ghosts.';
    }
    if (_planningNear(a, currentRoom.grave?.lychStone)) {
      return 'Spirit · enter the ${_field.isGhost ? 'living' : 'ghost'} world\n'
          'Resting a ghost transfers its road to the living. Plan the funeral route before resting them.';
    }
    return null;
  }

  String? _vaultPreview(DungeonCreature a) {
    final g = vaultGnomonIn(currentRoomId);
    if (g == null || !_planningNear(a, g.shaft)) return null;
    final next = EclipseVault()
      ..shadow.clear()
      ..shadow.addAll(vault.shadow);
    final entered = next.turn(g.id)!;
    final changes = <String>[];
    for (final leaf in EclipseLeaf.values) {
      if (next.isDark(leaf) == vault.isDark(leaf)) continue;
      changes.add(
        '${leafWord(leaf)} becomes ${next.isDark(leaf) ? 'dark' : 'lit'}',
      );
    }
    return 'Dark · shadow toward ${leafWord(entered)}\n'
        '${changes.isEmpty ? 'Other shadows keep the same quarters dark' : changes.join('; ')}. '
        'Dark opens crossings; light joins rooms within a quarter.';
  }

  String? _archivePreview(DungeonCreature a) {
    final b = archiveBeaconIn(currentRoomId);
    if (b == null || !_planningNear(a, b.post)) return null;
    final next = archive.previewPress(b.id);
    final setting = next.settingOf(b.id);
    final exposure = next.lumens;
    final ready = kCourtEffigies
        .where((e) => !archive.effigiesRead.contains(e.id) && next.canRead(e))
        .length;
    return 'Light · ${setting?.look ?? 'extinguish beacon'}\n'
        '${archive.lumens} → $exposure lumens · '
        '${exposure <= kArchiveHush ? 'within the hush' : 'too bright for slips'} · '
        '$ready unread shadows readable.';
  }

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
