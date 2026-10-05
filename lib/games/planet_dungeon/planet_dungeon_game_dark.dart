// lib/games/planet_dungeon/planet_dungeon_game_dark.dart
//
// NYTHRALOR — THE BLACK SUN. Dark's rules, as a `part of
// planet_dungeon_game.dart`. The grids, the pure rules and the rooms live in
// planet_dungeon_layout_dark.dart; the drawing in
// planet_dungeon_game_dark_art.dart; this file is the play.
//
// World rule: *each Dark carries one portal, and light that passes through
// both comes out as blood.* The rules the party walks by are EXACTLY the
// prototype's: every body stands on a grid square, and a step, a cast or a
// shine is the same sentence the solver proved the rooms with.
//
// THE PARTY DOES NOT TRAVEL TOGETHER. Alone of every planet, a door takes
// only the body you are steering; the others stay exactly where they were
// left, in whatever room that was. Choosing a body in another room takes the
// view there. A portal can join two rooms, and a body or a beam can go
// through it.
//
//  • The porch — cross the void by portal; the door beyond is the Hall.
//  • Star 1 (Nigredo) — chambers II and III, off the Hall's south ledge.
//    Winning it lights the Hall's two stars.
//  • Star 2 (Albedo) — chambers IV and V, off the far ledge, which only a
//    blood bridge reaches (two crossings; the second cast from the island).
//  • Rite — the Heart, down the island's stair: blood on the Great Seal.
//  • Star 3 (Rubedo) — Noctryos, the engine's fight; its enemies come out
//    of black holes in the arena floor, and the party fights it together.
//  • Vault — the Hall's alcove, seen only from a blood bridge.
//  • Lost Maxim — a light that does not end: a beam that goes round through
//    a portal and comes back to where it has already been.
//
// Nothing here is timed and nothing is chance. Anyone left over the void
// when a beam moves falls back to where their room lets them in.

part of 'planet_dungeon_game.dart';

/// The Lost Maxim's discovery id (the screen pays 20 gold on first find).
const String kDarkEggId = 'egg:dark_ouroboros';

/// Everything the Black Sun tracks for one run, and the clocks the render
/// reads (named here so the render has somewhere to keep them).
class SunRun {
  SunRun() {
    reset();
  }

  /// The rules' state: every body, Light's beam, both portals, latches.
  late SunState state;

  /// Chambers solved (their void set, their doors open for good).
  final Set<String> solved = {};

  /// What the world looks like right now (re-derived when the state moves).
  SunEval? eval;
  String? evalKey;

  /// A step into a portal the active body has asked for (dir), run next
  /// frame.
  int? pendingTransit;

  /// Which end the next cast press is for (0 = I, 1 = II).
  int castEnd = 0;

  /// In the arena, the party fights together; the grid rooms are left as
  /// they were.
  bool inArena = false;

  /// The Great Seal's rite has latched A and B, and when (the red black sun
  /// rising over it is drawn from this).
  bool riteLatched = false;
  double riteT = -9;

  // ── The moments: seconds since each began (visual only) ──
  final Map<String, double> castT = {}; // 'purple0' -> when it opened
  final Map<String, (SunEnd, double)> closedT = {}; // an end closing
  final Map<String, double> transitT = {}; // body -> when it came through
  final Map<String, (Offset, String, double)> transitFrom = {};
  final Map<String, double> fellT = {};
  final Map<String, double> solvedT = {}; // chamber -> when it set
  final Map<String, double> sealT = {}; // seal key -> when it lit
  final Map<String, double> doorShown = {}; // door key -> eased openness
  double shineT = -9;
  (Offset, int, String, double)? castStreak; // from, dir, owner, when

  void reset() {
    state = SunState(
      pos: {
        for (var i = 0; i < kSunBodies.length; i++)
          kSunBodies[i]: (
            room: 'sun_porch',
            x: kSunPorch.arrivals[i].x,
            y: kSunPorch.arrivals[i].y,
          ),
      },
    );
    solved.clear();
    eval = null;
    evalKey = null;
    pendingTransit = null;
    castEnd = 0;
    inArena = false;
    riteLatched = false;
    riteT = -9;
    castT.clear();
    closedT.clear();
    transitT.clear();
    transitFrom.clear();
    fellT.clear();
    solvedT.clear();
    sealT.clear();
    doorShown.clear();
    shineT = -9;
    castStreak = null;
  }
}

extension BlackSunDungeon on PlanetDungeonGame {
  // ── Lifecycle ────────────────────────────────────────────

  void _resetVaultState() {
    if (!_isVault) return;
    blackSun.reset();
    // A WON STAR STAYS WON: its chambers stay set, and on a new descent their
    // voids are still solid and their doors still open.
    for (final e in kSunStarChambers.entries) {
      if (hasStar(e.key)) blackSun.solved.addAll(e.value);
    }
    if (hasStar(2)) {
      blackSun.riteLatched = true;
      blackSun.state = blackSun.state.copyWith(
        latched: {...blackSun.state.latched, kSunRiteLatch},
      );
    }
    _sunSyncedCount = -1;
  }

  SunWorld get _sunWorld => SunWorld(
    stars: {
      for (var i = 0; i < 3; i++)
        if (hasStar(i)) i,
    },
    solved: blackSun.solved,
  );

  SunEval get _sunEval {
    final w = _sunWorld;
    final key =
        '${blackSun.state.encoded}#${w.stars.join()}#${blackSun.solved.join(',')}';
    if (blackSun.evalKey != key || blackSun.eval == null) {
      blackSun.eval = sunEvaluate(w, blackSun.state);
      blackSun.evalKey = key;
    }
    return blackSun.eval!;
  }

  // ── Who is who, and where ────────────────────────────────

  /// The rules' name for a body: 'light', 'purple' (the party's first Dark)
  /// or 'orange' (its second). A party that is not two Darks and a Light
  /// (a debug descent) falls back to slot order.
  String _sunName(DungeonCreature c) {
    final darks = [
      for (final o in creatures)
        if (o.member.element == 'Dark') o,
    ];
    final lights = creatures.where((o) => o.member.element == 'Light');
    if (darks.length == 2 && lights.length == 1) {
      if (c.member.element == 'Light') return 'light';
      return identical(darks.first, c) ? 'purple' : 'orange';
    }
    return kSunBodies[creatures.indexOf(c).clamp(0, 2)];
  }

  DungeonCreature? _sunBody(String name) {
    for (final c in creatures) {
      if (_sunName(c) == name) return c;
    }
    return null;
  }

  /// Is [c] in the room the view is on? (Only these are drawn.)
  bool _sunHere(DungeonCreature c) {
    if (!_isVault) return true;
    if (blackSun.inArena) return true;
    return blackSun.state.pos[_sunName(c)]!.room == currentRoomId;
  }

  SunRoomDef? get _sunDef => currentRoom.sun?.def;

  /// Put every creature on its square (a new party, a fall, a reset).
  void _sunSnapAll() {
    for (final c in creatures) {
      final p = blackSun.state.pos[_sunName(c)]!;
      c
        ..position = sunCentre(p.x, p.y)
        ..lastSafe = sunCentre(p.x, p.y);
    }
  }

  /// The run starts with all three on the porch's own squares.
  void _sunPlaceParty() {
    if (!_isVault) return;
    blackSun.state = blackSun.state.copyWith(
      pos: {
        for (var i = 0; i < kSunBodies.length; i++)
          kSunBodies[i]: (
            room: 'sun_porch',
            x: kSunPorch.arrivals[i].x,
            y: kSunPorch.arrivals[i].y,
          ),
      },
      shine: -1,
    );
    blackSun.inArena = false;
    currentRoomId = 'sun_porch';
    _sunSnapAll();
    _sunSyncedCount = creatures.length;
  }

  /// The view goes to [room] (the active body went there, or you chose a
  /// body standing there).
  void _sunShowRoom(String room) {
    if (currentRoomId == room) return;
    currentRoomId = room;
    final def = kSunRooms[room];
    if (def != null) {
      final a = def.arrivals.first;
      _roomEntryAnchor = sunCentre(a.x, a.y);
    }
    _doorCooldown = 0.5;
    _camFocus = null;
    _clearHints();
    final hint = _roomObjectiveHint(room) ?? _roomIdentityLine(room);
    if (hint != null) _announceRoomEntry(hint);
    _teachRoom(currentRoom);
    onChanged();
  }

  /// Choosing a body in another room takes the view there.
  void _sunFollowActive() {
    if (!_isVault || blackSun.inArena) return;
    final a = active;
    if (a == null) return;
    _sunShowRoom(blackSun.state.pos[_sunName(a)]!.room);
  }

  // ── Walking: the floor is the rule ───────────────────────

  static const String _sunBlockPrefix = 'sun:';

  /// Does the ACTIVE body's next position leave what the rules allow? A step
  /// into a portal is not a wall: it is recorded, and taken next frame.
  bool _sunBlocksAt(Offset center, DungeonRoom room) {
    final def = room.sun?.def;
    if (def == null || blackSun.inArena) return false;
    final a = active;
    if (a == null) return false;
    final me = _sunName(a);
    final here = blackSun.state.pos[me]!;
    if (here.room != room.id) return false;
    final t = sunSquareAt(center, def.cols, def.rows);
    final dx = t.x - here.x, dy = t.y - here.y;
    if (dx == 0 && dy == 0) return false;
    if (dx.abs() + dy.abs() != 1) return true;
    final dir = dx == 1
        ? 1
        : dx == -1
        ? 3
        : dy == 1
        ? 2
        : 0;
    final e = _sunEval;
    final w = _sunWorld;
    final st = sunStepTarget(w, blackSun.state, e, me, dir);
    if (st.why == null) {
      if (st.through != null) {
        blackSun.pendingTransit = dir;
        return true;
      }
      // Would the step leave the mover itself on nothing?
      final r = sunPlace(w, blackSun.state, me, st.to!);
      if (r.ok) {
        _releaseBlockedExcept(_sunBlockPrefix, const {});
        return false;
      }
      _setBlockedHintOnce(
        '$_sunBlockPrefix${t.x},${t.y}',
        _sunRefusal(r.why!, me),
      );
      return true;
    }
    // Walls say nothing; everything else says what is wrong.
    if (st.why != 'wall') {
      _setBlockedHintOnce(
        '$_sunBlockPrefix${t.x},${t.y}',
        _sunRefusal(st.why!, me),
      );
    }
    return true;
  }

  String _sunRefusal(String why, String who) => switch (why) {
    'own light' => 'That light is Light\'s own. Nothing stands on its own light',
    'would fall' => 'There is nothing under that',
    'void' => 'There is nothing to stand on',
    'door' => 'The door is shut',
    'body' => 'Someone is standing there',
    'obsidian' => 'Obsidian. There is no portal on it',
    'lone mouth' => 'That portal has no other end',
    'blocked exit' => 'Someone is standing at the other end',
    'exit over void' => 'The other end opens onto nothing',
    'stone' => 'Only obsidian takes a portal',
    'taken' => 'The other Dark\'s portal is there',
    'no lens' => 'Light shines only from the burning-glass',
    _ => '',
  };

  /// A door takes only the body you are steering (the arena excepted: the
  /// party goes down to Noctryos together). True when handled.
  bool _sunPassThroughDoor(DungeonDoor d) {
    if (!_isVault) return false;
    final a = active;
    if (a == null) return false;
    final target = layout.rooms[d.targetRoomId]!;
    final tdef = target.sun?.def;
    final me = _sunName(a);
    if (tdef == null) {
      // Down to Noctryos: everyone comes.
      blackSun.inArena = true;
      currentRoomId = d.targetRoomId;
      _roomEntryAnchor = d.targetSpawn;
      _spreadCreaturesAround(d.targetSpawn);
      return false; // the engine finishes the transit (fight, lines)
    }
    if (blackSun.inArena) {
      // Back up from the arena: everyone comes back to the Heart.
      blackSun.inArena = false;
      var s = blackSun.state;
      for (final n in kSunBodies) {
        s = s.moved(n, (room: '-', x: -9, y: -9));
      }
      for (final n in kSunBodies) {
        s = s.moved(n, sunLanding(_sunWorld, s, tdef.id, n));
      }
      blackSun.state = s;
    } else {
      final sq = sunSquareAt(d.targetSpawn, tdef.cols, tdef.rows);
      final s = blackSun.state;
      SunAt to = (room: tdef.id, x: sq.x, y: sq.y);
      if (sunBodyAt(s, tdef.id, sq.x, sq.y, me) != null) {
        to = sunLanding(_sunWorld, s.moved(me, (room: '-', x: -9, y: -9)), tdef.id, me);
      }
      final r = sunPlace(_sunWorld, s, me, to);
      blackSun.state = r.ok ? r.state! : s.moved(me, to);
      if (r.ok) _sunApplyFalls(r.fell);
    }
    currentRoomId = d.targetRoomId;
    _roomEntryAnchor = d.targetSpawn;
    _sunSnapAll();
    _doorCooldown = 0.5;
    _clearHints();
    final hint =
        _roomObjectiveHint(currentRoomId) ?? _roomIdentityLine(currentRoomId);
    if (hint != null) _announceRoomEntry(hint);
    _teachRoom(currentRoom);
    onChanged();
    return true;
  }

  // ── Verbs ────────────────────────────────────────────────

  /// Aim: the way the stick last pointed, snapped to the four directions.
  int _sunAim(DungeonCreature a) {
    final k = ((a.aimAngle / (pi / 2)).round() % 4 + 4) % 4;
    return const [1, 2, 3, 0][k];
  }

  /// Is the active body a Dark standing in a grid room (so the pad shows
  /// CAST I and CAST II)?
  bool get sunCastMode {
    if (!_isVault || blackSun.inArena) return false;
    final a = active;
    if (a == null || _sunDef == null) return false;
    return _sunName(a) != 'light';
  }

  /// Whether the active body is the purple Dark (the pad tints its tiles).
  bool get sunActiveIsPurple {
    final a = active;
    return a != null && _sunName(a) == 'purple';
  }

  /// The pad's label for Light in a grid room: SHINE, or PUT OUT.
  String? get sunUtilityLabel {
    if (!_isVault || blackSun.inArena) return null;
    final a = active;
    if (a == null || _sunDef == null) return null;
    if (_sunName(a) != 'light') return null;
    return blackSun.state.shine >= 0 ? 'PUT OUT' : 'SHINE';
  }

  /// CAST I / CAST II on the pad: the press, for one end.
  void activateSunCast(int end) {
    blackSun.castEnd = end.clamp(0, 1);
    activateAbility();
  }

  bool _tryVaultVerb(DungeonCreature a) {
    if (!_isVault || blackSun.inArena) return false;
    final def = _sunDef;
    if (def == null) return false;
    final me = _sunName(a);
    final dir = _sunAim(a);
    final w = _sunWorld;
    final s = blackSun.state;
    if (me == 'light') {
      final p = s.pos['light']!;
      if (s.shine < 0 && def.at(p.x, p.y) != '*') {
        _setBlockedHint(_sunRefusal('no lens', me));
        return true;
      }
      final r = sunShine(w, s, s.shine >= 0 ? -1 : dir);
      _sunCommit(r);
      blackSun.shineT = _time;
      _cue(s.shine >= 0 ? SoundCue.dungeonSwitch : SoundCue.dungeonInteract);
      return true;
    }
    final end = blackSun.castEnd;
    final r = sunCast(w, s, me, end, dir);
    if (!r.ok) {
      _setBlockedHint(_sunRefusal(r.why!, me));
      return true;
    }
    final before = s.ends[me]![end];
    final after = r.state!.ends[me]![end];
    final key = '$me$end';
    if (before != null) blackSun.closedT[key] = (before, _time);
    if (after != null) {
      blackSun.castT[key] = _time;
      blackSun.castStreak = (a.position, dir, me, _time);
      _cue(SoundCue.dungeonSecretReveal);
    } else {
      _cue(SoundCue.dungeonSwitch);
    }
    _sunCommit(r);
    return true;
  }

  /// Take a rules result: the new state, and anyone it dropped.
  void _sunCommit(SunResult r) {
    if (!r.ok) return;
    blackSun.state = r.state!;
    _sunApplyFalls(r.fell);
    onChanged();
  }

  void _sunApplyFalls(List<String> fell) {
    if (fell.isEmpty) return;
    for (final n in fell) {
      final c = _sunBody(n);
      final to = blackSun.state.pos[n]!;
      blackSun.fellT[n] = _time;
      if (c == null) continue;
      if (to.room == currentRoomId) {
        _spawnAlchemyBurst(c.position, producedElement: 'Blood', particleCount: 14);
      }
      c
        ..position = sunCentre(to.x, to.y)
        ..lastSafe = sunCentre(to.x, to.y);
    }
    final names = fell.map(_sunWord).toSet().toList();
    speakConsequence(
      '${names.join(' and ')} ${names.length > 1 ? 'fall' : 'falls'} '
      'through the void, back to the door',
    );
  }

  String _sunWord(String n) => switch (n) {
    'light' => 'Light',
    'purple' => 'The purple Dark',
    _ => 'The orange Dark',
  };

  // ── Per-frame ────────────────────────────────────────────

  void _updateVault(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isVault) return;
    if (_sunSyncedCount != creatures.length) {
      // A party just arrived without the run placing it (a headless harness
      // or a render audit that set the room itself): bring everyone into the
      // room the view is on, on its own squares.
      _sunSyncedCount = creatures.length;
      final def = room.sun?.def;
      if (def != null &&
          blackSun.state.pos[_sunName(a)]!.room != room.id) {
        var s = blackSun.state;
        for (final n in kSunBodies) {
          s = s.moved(n, (room: '-', x: -9, y: -9));
        }
        for (final n in kSunBodies) {
          s = s.moved(n, sunLanding(_sunWorld, s, def.id, n));
        }
        blackSun.state = s;
      }
      _sunSnapAll();
    }
    if (blackSun.inArena) return;
    final def = room.sun?.def;
    final me = _sunName(a);

    // A step into a portal, asked for last frame.
    final dir = blackSun.pendingTransit;
    blackSun.pendingTransit = null;
    if (dir != null && def != null) {
      final r = sunMove(_sunWorld, blackSun.state, me, dir);
      if (r.ok) {
        final from = a.position;
        final to = r.state!.pos[me]!;
        blackSun
          ..transitT[me] = _time
          ..transitFrom[me] = (from, room.id, _time);
        _cue(SoundCue.dungeonGateOpen);
        _sunCommit(r);
        a
          ..position = sunCentre(to.x, to.y)
          ..lastSafe = sunCentre(to.x, to.y);
        if (to.room != currentRoomId) _sunShowRoom(to.room);
        return;
      }
      _setBlockedHint(_sunRefusal(r.why!, me));
    }

    // The active body walked onto a new square: the rules follow it.
    if (def != null) {
      final here = blackSun.state.pos[me]!;
      if (here.room == room.id) {
        final t = sunSquareAt(a.position, def.cols, def.rows);
        if (t.x != here.x || t.y != here.y) {
          final r = sunPlace(
            _sunWorld,
            blackSun.state,
            me,
            (room: room.id, x: t.x, y: t.y),
          );
          if (r.ok) {
            _sunCommit(r);
          } else {
            a.position = sunCentre(here.x, here.y);
          }
        }
      }
    }

    // Seals that have just lit.
    final e = _sunEval;
    for (final k in e.sealsLit) {
      blackSun.sealT.putIfAbsent(k, () {
        _cue(SoundCue.dungeonSwitch);
        return _time;
      });
    }
    blackSun.sealT.removeWhere((k, _) => !e.sealsLit.contains(k));

    // A chamber with all three on its pads is solved: its void sets, its
    // doors stand open, and a pair banks its star.
    for (final d in kSunRooms.values) {
      if (!d.isChamber || blackSun.solved.contains(d.id)) continue;
      if (!sunChamberSolved(d, blackSun.state)) continue;
      _sunSolveChamber(d);
    }

    // THE RITE: blood on the Great Seal latches A and B.
    if (!blackSun.riteLatched && blackSun.state.latched.contains(kSunRiteLatch)) {
      blackSun.riteLatched = true;
      blackSun.riteT = _time;
      conduitEnergy['A'] = double.infinity;
      conduitEnergy['B'] = double.infinity;
      _cue(SoundCue.dungeonPuzzleSolved);
      if (currentRoomId == 'sun_heart') {
        _spawnAlchemyBurst(
          sunCentre(kSunGreatSeal.x, kSunGreatSeal.y),
          producedElement: 'Blood',
          particleCount: 40,
          intensity: 1.4,
        );
      }
    }

    // THE LOST MAXIM: a light that does not end.
    if (!discoveredClouds.contains(kDarkEggId) &&
        _ritePendingEgg != kDarkEggId) {
      for (final b in e.beams) {
        if (!b.loopsThroughPortal) continue;
        final at = b.path.lastWhere(
          (p) => p.room == currentRoomId,
          orElse: () => b.path.last,
        );
        _cue(SoundCue.dungeonSecretReveal);
        soundedSecrets.add(kDarkEggId);
        beginMaximRite(
          kDarkEggId,
          at.room == currentRoomId
              ? Offset((at.x + .5) * kSunCell, (at.y + .5) * kSunCell)
              : a.position,
        );
        break;
      }
    }
  }

  void _sunSolveChamber(SunRoomDef d) {
    blackSun.solved.add(d.id);
    blackSun.solvedT[d.id] = _time;
    _cue(SoundCue.dungeonPuzzleSolved);
    speakConsequence('All three are through. The void sets behind you');
    final star = d.starIndex;
    if (star != null && !hasStar(star)) {
      final pair = kSunStarChambers[star]!;
      if (pair.every(blackSun.solved.contains)) earnStar(star);
    }
    onChanged();
  }

  // ── The arena ────────────────────────────────────────────

  /// Noctryos' enemies come out of black holes in the arena floor.
  Offset? _sunArenaSpawn(DungeonRoom room, Offset toward) {
    if (!_isVault || room.guardian == null) return null;
    var best = kSunArenaHoles.first;
    var bestD = double.infinity;
    for (final h in kSunArenaHoles) {
      final d = (h - toward).distance + _combatRng.nextDouble() * 220;
      if (d < bestD) {
        bestD = d;
        best = h;
      }
    }
    return best +
        Offset(
          (_combatRng.nextDouble() - .5) * 20,
          (_combatRng.nextDouble() - .5) * 20,
        );
  }

  // ── Doors ────────────────────────────────────────────────

  bool _vaultDoorHidden(DungeonRoom room, DungeonDoor door) => false;

  /// A door between rooms that the rules hold shut (the Lantern's way down,
  /// open only while Light's white seal burns).
  bool _vaultDoorBlocked(DungeonRoom room, DungeonDoor door) {
    if (!_isVault) return false;
    final l = _sunLinkFor(room, door);
    if (l == null || l.heldBy == null) return false;
    return !sunLinkOpen(l, _sunEval);
  }

  String _vaultDoorHint(DungeonRoom room, DungeonDoor door) =>
      'The door is shut';

  /// The rules' link for one of the game's doors.
  SunLink? _sunLinkFor(DungeonRoom room, DungeonDoor door) {
    final def = room.sun?.def;
    if (def == null) return null;
    for (final l in kSunLinks) {
      if (l.room != room.id || l.to != door.targetRoomId) continue;
      final cell = Rect.fromLTWH(l.x * kSunCell, l.y * kSunCell, kSunCell, kSunCell);
      if (door.rect.overlaps(cell)) return l;
    }
    return null;
  }

  /// THE GATHER BUTTON, here (the author, 2026-09-30: "group on the one who
  /// pressed it"). Everyone who could WALK to the body you are steering —
  /// across floor and bridges, through doors and open portals, by exactly the
  /// rules — comes and stands beside it. Anyone who could not get there
  /// stays where they are: the button never carries a body over a gap the
  /// puzzle has not bridged, or one crossing would be the whole party's.
  bool _sunRegroup() {
    if (!_isVault || blackSun.inArena) return false;
    final a = active;
    if (a == null || _sunDef == null) return false;
    final me = _sunName(a);
    final w = _sunWorld;
    var s = blackSun.state;
    final target = s.pos[me]!;
    final came = <String>[];
    var waiting = [
      for (final n in kSunBodies)
        if (n != me) n,
    ];
    // One body can be standing in another's way: go round again while
    // anyone is still coming.
    for (var pass = 0; pass < 3 && waiting.isNotEmpty; pass++) {
      final still = <String>[];
      for (final n in waiting) {
        final p = s.pos[n]!;
        if (p.room == target.room &&
            (p.x - target.x).abs() + (p.y - target.y).abs() == 1) {
          continue; // already beside it
        }
        final walked = _sunWalkBeside(w, s, n, target);
        if (walked == null) {
          still.add(n);
        } else {
          s = walked;
          came.add(n);
        }
      }
      if (still.length == waiting.length) break;
      waiting = still;
    }
    final stuck = waiting.where((n) {
      final p = s.pos[n]!;
      return !(p.room == target.room &&
          (p.x - target.x).abs() + (p.y - target.y).abs() == 1);
    }).toList();
    blackSun.state = s;
    _sunSnapAll();
    if (came.isNotEmpty) _cue(SoundCue.dungeonCheckpoint);
    speakConsequence(
      stuck.isEmpty
          ? (came.isEmpty ? 'Everyone is already here' : 'The party gathers')
          : stuck.length == 2
          ? 'Neither of the others can get here'
          : '${_sunWord(stuck.single)} can\'t get here',
    );
    onChanged();
    return true;
  }

  /// [who] walking, by the rules, to the nearest free square beside
  /// [target]: the state when it gets there, or null if it can't. Doors
  /// between rooms count as steps (the island's stair too, while it is
  /// open); the arena does not.
  SunState? _sunWalkBeside(SunWorld w, SunState s0, String who, SunAt target) {
    String key(SunState s) {
      final p = s.pos[who]!;
      return '${p.room}.${p.x}.${p.y}.${s.shine}';
    }

    bool beside(SunAt p) =>
        p.room == target.room &&
        (p.x - target.x).abs() + (p.y - target.y).abs() == 1;

    // A square in front of a portal mouth is where the next one through
    // comes out: stand there only if there is nowhere else beside it.
    bool mouthFront(SunState s, SunAt p) {
      for (final o in kSunDarks) {
        for (final e in s.ends[o]!) {
          if (e == null || e.room != p.room) continue;
          final f = kSunRooms[e.room]!.faces[e.face].front;
          if (f.x == p.x && f.y == p.y) return true;
        }
      }
      return false;
    }

    SunState? fallback;
    final seen = {key(s0)};
    final q = [s0];
    for (var i = 0; i < q.length && i < 4000; i++) {
      final s = q[i];
      final p = s.pos[who]!;
      if (beside(p)) {
        if (!mouthFront(s, p)) return s;
        fallback ??= s;
      }
      final e = sunEvaluate(w, s);
      final next = <SunState>[];
      for (var d = 0; d < 4; d++) {
        final r = sunMove(w, s, who, d, eval: e);
        // A road that drops someone else is not a road to call them by.
        if (r.ok && r.fell.isEmpty) next.add(r.state!);
      }
      // A doorway is a step into the next room.
      final room = layout.rooms[p.room]!;
      final cell = Rect.fromLTWH(
        p.x * kSunCell,
        p.y * kSunCell,
        kSunCell,
        kSunCell,
      );
      for (final door in room.doors) {
        if (!door.rect.overlaps(cell)) continue;
        if (isDoorHidden(room, door) || isDoorLocked(room, door)) continue;
        final tdef = layout.rooms[door.targetRoomId]?.sun?.def;
        if (tdef == null) continue;
        final sq = sunSquareAt(door.targetSpawn, tdef.cols, tdef.rows);
        if (sunBodyAt(s, tdef.id, sq.x, sq.y, who) != null) continue;
        final r = sunPlace(w, s, who, (room: tdef.id, x: sq.x, y: sq.y));
        if (r.ok && r.fell.isEmpty) next.add(r.state!);
      }
      for (final n in next) {
        if (seen.add(key(n))) q.add(n);
      }
    }
    return fallback;
  }

  /// The pad's gather button reads as a huddle here, not a way back.
  bool get sunGathers => _isVault && !blackSun.inArena && _sunDef != null;

  // ── Readouts, hints ──────────────────────────────────────

  DungeonProgressReadout? _vaultProgressReadout() => null;

  String _sunRoomWord(String roomId) => switch (roomId) {
    'sun_porch' => 'The Porch',
    'sun_hall' => 'The Hall of the Black Sun',
    'through_the_dark' => 'Through the Dark',
    'two_darks' => 'Two Darks Make Blood',
    'into_the_light' => 'Walk into the Light',
    'hold_the_light' => 'Hold the Light',
    'sun_lantern' => 'The Lantern',
    'sun_heart' => 'The Heart',
    'noctryos_totality' => 'Noctryos',
    _ => roomId,
  };

  /// The line a room says as you arrive: its name, and nothing about how.
  String? _vaultObjectiveHint(DungeonRoom room) {
    final word = _sunRoomWord(room.id);
    if (blackSun.solved.contains(room.id)) return '$word. Solved';
    return word;
  }

  void _vaultAmbientHint(DungeonCreature a, DungeonRoom room) {}

  /// THE HINT BUTTON — bare: what is wrong here, never how.
  void _vaultReveal(DungeonCreature a, DungeonRoom room) {
    _setInsightHint(_sunWhatsWrong(room));
  }

  String _sunWhatsWrong(DungeonRoom room) {
    if (room.guardian != null) return 'Noctryos';
    final def = room.sun?.def;
    if (def == null) return 'Nothing is wrong here';
    final s = blackSun.state;
    switch (def.id) {
      case 'sun_porch':
        return 'The door is across the void';
      case 'sun_hall':
        if (!hasStar(0)) return 'The Hall\'s stars are dark';
        if (!hasStar(1)) return 'The far ledge is across the void';
        return 'The stair is on the island';
      case 'sun_lantern':
        return blackSun.riteLatched
            ? 'The Great Seal has burned'
            : 'The Great Seal below is dark';
      case 'sun_heart':
        return blackSun.riteLatched
            ? 'The way down is open'
            : 'The Great Seal is dark';
    }
    if (blackSun.solved.contains(def.id)) return 'This chamber is solved';
    final off = kSunBodies.where((n) {
      final p = s.pos[n]!;
      return p.room != def.id || def.at(p.x, p.y) != 'E';
    }).length;
    return off == 1
        ? 'One of you is not on the gold'
        : '$off of you are not on the gold';
  }

  /// A dark planet: the rooms sit in the void, lit only by what you bring.
  double get _vaultMoodTarget => switch (currentRoomId) {
    'sun_hall' => 0.28,
    'sun_lantern' => 0.26,
    'sun_heart' => blackSun.riteLatched ? 0.4 : 0.2,
    'noctryos_totality' => guardianAwake ? 0.34 : 0.18,
    _ => 0.24,
  };
}
