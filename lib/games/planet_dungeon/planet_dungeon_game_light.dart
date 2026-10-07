// lib/games/planet_dungeon/planet_dungeon_game_light.dart
//
// SOLARIN — THE SHADOW FLOOR. Light's rules, as a `part of
// planet_dungeon_game.dart`. The grids, the pure rules and the solver live
// in planet_dungeon_layout_light.dart; the drawing in
// planet_dungeon_game_light_art.dart; this file is the play.
//
// World rule: *light is nothing here. Only shadow holds your weight.* The
// rules the party walks by are EXACTLY the solver's: every body stands on a
// grid square, casts from that square's centre, and may step onto glass only
// where every starlight reaching it is blocked by something that is not
// itself. The drawn shadows sweep with the bodies as they walk; the floor
// they are allowed onto is the discrete rule, so what the proof proved is
// what the phone plays.
//
//  • Entry — the hall's star is dark. LIGHT wakes it, and Room I's door with
//    it.
//  • Star 1 (Shadow) — rooms I and II, off the near ledge. Each solved sets a
//    span across the near well.
//  • Star 2 (Stone) — rooms III and IV, off the island. Each sets a span
//    across the far well.
//  • Rite — the Door of Shadow, on the far ledge: the monolith's pinned
//    shadow is both the bridge and a door cut through a blank wall.
//  • Star 3 (Corona) — Solarin, the star itself, struck from two squares off
//    on floor that holds; each blow swings it round its orbit and the floor
//    re-forms under everyone.
//  • Vault — the Sunless Reliquary, whose road is the relic's own shadow.
//  • Lost Maxim — Light walks on light: the gold sun in the far well.
//
// Nothing here is timed and nothing is chance. Anyone caught on bare light
// when a starlight moves falls back to where the room let them in.

part of 'planet_dungeon_game.dart';

/// The Lost Maxim's discovery id (the screen pays 20 gold on first find).
const String kLightEggId = 'egg:light_walks_on_light';

extension ShadowFloorDungeon on PlanetDungeonGame {
  // ── Lifecycle ────────────────────────────────────────────

  void _resetArchiveState() {
    if (!_isArchive) return;
    archive.reset();
    // A WON STAR STAYS WON: its rooms' floors are set in stone and their
    // spans stand across the hall on every later descent.
    if (hasStar(0)) {
      _markSolved('own_shadow');
      _markSolved('key_room');
    }
    if (hasStar(1)) {
      _markSolved('two_suns');
      _markSolved('two_gaps');
    }
    if (hasStar(2)) {
      _markSolved('door_of_shadow');
      _markSolved('eclipse_walk');
    }
    for (final id in kBridgeRooms) {
      if (archive.solved.contains(id)) archive.spanSet[id] = -99;
    }
  }

  /// Set a room's whole floor into stone without the moment (a banked star).
  void _markSolved(String id) {
    archive.solved.add(id);
    if (id == 'key_room') {
      archive.keyPinned = true;
      archive.keyVeil = true;
      archive.keyLampX = kKeyAnswerX;
      archive.keyLampY = kKeyAnswerY;
      return;
    }
    final def = kShadowRooms[id];
    if (def == null) return;
    final s = archive.state(id);
    archive.rooms[id] = s.copyWith(pinned: {...s.pinned, ..._allGlass(def)});
  }

  Set<int> _allGlass(ShadowRoomDef d) => {
    for (var y = 0; y < d.rows; y++)
      for (var x = 0; x < d.cols; x++)
        if (d.at(x, y) == '~' || d.at(x, y) == 'B') sqKey(x, y),
  };

  // ── Who is who ───────────────────────────────────────────

  /// The grid name of a body: its element, or its slot when the party
  /// carries a double.
  String _shadowName(DungeonCreature c) {
    if (isRaid) return _raidShadowNames()[c] ?? '';
    final el = c.member.element;
    final i = creatures.indexOf(c);
    final single = creatures.where((o) => o.member.element == el).length == 1;
    if (single && kShadowNames.contains(el)) return el;
    return kShadowNames[i.clamp(0, 2)];
  }

  /// A raid squad is five on a floor that knows three names. The one you
  /// play always has one of its own, since its burn, its reach and its step
  /// are read from where it stands; then the rest of the squad in order.
  /// Each takes its own element's name when that is one of the three and
  /// still free, else the first free one. The last two cast no shadow.
  Map<DungeonCreature, String> _raidShadowNames() {
    final a = active;
    if (identical(_raidNamesFor, a) && _raidNamesAt == _time) {
      return _raidNames;
    }
    final free = [...kShadowNames];
    _raidNames = {};
    for (final c in [
      ?a,
      ...creatures.where((c) => c.alive && !identical(c, a)),
    ]) {
      if (free.isEmpty) break;
      final el = c.member.element;
      final name = free.contains(el) ? el : free.first;
      free.remove(name);
      _raidNames[c] = name;
    }
    _raidNamesFor = a;
    _raidNamesAt = _time;
    return _raidNames;
  }

  DungeonCreature? _shadowBody(String name) {
    for (final c in creatures) {
      if (_shadowName(c) == name) return c;
    }
    return null;
  }

  ShadowRoomDef? _gridOf(DungeonRoom room) => room.hall?.def;

  /// The live state of [room]'s grid, with every body where it stands.
  ShadowState _liveState(DungeonRoom room) {
    final def = _gridOf(room)!;
    final s = archive.state(def.id);
    final pos = <String, Sq>{};
    for (final n in kShadowNames) {
      final c = _shadowBody(n);
      pos[n] = c == null
          ? s.pos[n]!
          : shadowSquareAt(c.position, def.cols, def.rows);
    }
    return s.copyWith(pos: pos);
  }

  // ── Walking: the floor is the rule ───────────────────────

  static const String _shadowBlockPrefix = 'shadow:';

  /// Does the ACTIVE body's next position leave the floor? The hall's wells
  /// hold only their spans (and, for Light, the sun); a grid room holds only
  /// what the rules say; the key room is stone.
  bool _archiveBlocksAt(Offset center, DungeonRoom room) {
    final bay = room.hall;
    if (bay == null) return false;
    final a = active;
    if (a == null) return false;
    if (bay.kind == 'hall') {
      final t = shadowSquareAt(center, kHallCols, kHallRows);
      final c = kHallMap[t.y][t.x];
      if (c == '.') return false;
      if (c == 'O') {
        if (_shadowName(a) == 'Light') return false;
        _setBlockedHintOnce(
          '${_shadowBlockPrefix}sun',
          'That is only light. There is nothing to stand on',
        );
        return true;
      }
      for (final e in kHallSpans.entries) {
        if (e.value.x == t.x &&
            e.value.y == t.y &&
            archive.solved.contains(e.key)) {
          return false;
        }
      }
      _setBlockedHintOnce(
        '${_shadowBlockPrefix}well',
        'The well is only light. There is nothing to stand on',
      );
      return true;
    }
    if (bay.kind != 'grid') return false;
    final def = bay.def!;
    final me = _shadowName(a);
    final s = _liveState(room);
    final here = s.pos[me]!;
    final t = shadowSquareAt(center, def.cols, def.rows);
    if (t.x == here.x && t.y == here.y) return false;
    // Solarin's glass is all floor: its light does not drop you, it burns.
    if (def.orbit != null) {
      return shadowSolid(def, t.x, t.y, s) ||
          shadowOccupant(s, t.x, t.y, me) != null;
    }
    final why = shadowStepCheck(def, s, me, t.x, t.y);
    if (why == null) {
      _releaseBlockedExcept(_shadowBlockPrefix, const {});
      return false;
    }
    final String line;
    if (why.startsWith('holds:')) {
      line = '${why.substring(6)} is standing on $me\'s shadow';
    } else if (shadowSolid(def, t.x, t.y, s)) {
      line = switch (def.at(t.x, t.y)) {
        'B' => 'A blank wall. There is no door in it',
        'M' => 'A statue of a door, standing in front of nothing',
        _ => '',
      };
    } else if (def.isGlass(t.x, t.y) &&
        shadowHolds(def, s, t.x, t.y, null) &&
        !shadowHolds(def, s, t.x, t.y, me)) {
      line = 'Nothing stands on its own shadow';
    } else if (def.isGlass(t.x, t.y)) {
      line = 'That is only light. There is nothing to stand on';
    } else {
      line = '';
    }
    if (line.isNotEmpty) {
      _setBlockedHintOnce('$_shadowBlockPrefix${t.x},${t.y}', line);
    }
    return true;
  }

  /// A grid room lays each body on its own square by the door, so the rules
  /// and the bodies agree from the first step.
  void _onArchiveArrive(DungeonDoor d) {
    final room = layout.rooms[d.targetRoomId];
    final def = room == null ? null : _gridOf(room);
    if (def == null) return;
    for (final n in kShadowNames) {
      final c = _shadowBody(n);
      if (c == null) continue;
      final at = def.start[n]!;
      c
        ..position = shadowCentre(at.x, at.y)
        ..lastSafe = shadowCentre(at.x, at.y);
    }
    final s = archive.state(def.id);
    archive.rooms[def.id] = s.copyWith(pos: Map.of(def.start));
    if (def.orbit != null) {
      archive
        ..orbitFrom = -1
        ..swingNext = kSolarinHold
        ..boltNext = kSolarinBoltEvery;
      archive.bolts.clear();
    }
  }

  // ── Verbs ────────────────────────────────────────────────

  bool _tryArchiveVerb(DungeonCreature a) {
    if (!_isArchive) return false;
    final room = currentRoom;
    final bay = room.hall;
    if (bay == null) return false;
    if (bay.kind == 'hall') return _tryHallVerb(a);
    if (bay.kind == 'key') return _tryKeyVerb(a);
    return _tryGridVerb(a, room);
  }

  /// The entry rite: Light wakes the hall's star.
  bool _tryHallVerb(DungeonCreature a) {
    if (entryDoorRevealed) return false;
    if ((a.position - kHallKindle).distance > 80) return false;
    if (_shadowName(a) != 'Light') {
      _setBlockedHint('The star needs Light');
      return true;
    }
    entryDoorRevealed = true;
    archive.keyT = _time; // the hall's star blooming
    _discoverCloud(PlanetDungeonGame.entryDoorDiscoveryId);
    _cue(SoundCue.dungeonGateOpen);
    _spawnAlchemyBurst(
      kHallKindle,
      producedElement: 'Light',
      particleCount: 34,
      intensity: 1.3,
    );
    speakConsequence(
      'The hall\'s star wakes, and a door opens on the north wall',
    );
    return true;
  }

  /// ROOM II: Light sets the starlight on a stud; Steam hangs the veil in
  /// the arch; Dark pins the key's shadow in the lock.
  bool _tryKeyVerb(DungeonCreature a) {
    if (archive.solved.contains('key_room') || archive.keyPinned) return false;
    final me = _shadowName(a);
    final p = a.position;
    final atArch =
        p.dy < kKeyFace + 1.5 * kKeyU &&
        p.dx > (kArchL - .6) * kKeyU &&
        p.dx < (kArchR + .6) * kKeyU;
    if (me == 'Light') {
      for (final sx in kKeyStudX) {
        for (final sy in kKeyStudY) {
          if ((p - keyFloor(sx, sy)).distance > 40) continue;
          if (archive.keyLampX == sx && archive.keyLampY == sy) return true;
          archive
            ..keyLampX = sx
            ..keyLampY = sy
            ..railT = _time;
          _cue(SoundCue.dungeonSwitch);
          return true;
        }
      }
      return false;
    }
    if (!atArch) return false;
    if (me == 'Steam') {
      if (archive.keyVeil) {
        _setBlockedHint('The veil is already hanging');
        return true;
      }
      archive
        ..keyVeil = true
        ..veilT = _time;
      _cue(SoundCue.dungeonInteract);
      speakConsequence('A veil of steam hangs in the arch');
      return true;
    }
    if (me == 'Dark') {
      if (!archive.keyVeil) {
        _setBlockedHint('There is no shadow on the arch to pin');
        return true;
      }
      if (!keyFits(archive.keyLampX, archive.keyLampY)) {
        archive.pinT = _time; // the shadow shakes in the lock
        archive.keyT = -_time;
        _cue(SoundCue.dungeonSwitch);
        _setBlockedHint('It does not fit the lock');
        return true;
      }
      archive
        ..keyPinned = true
        ..keyT = _time;
      _cue(SoundCue.dungeonSecretReveal);
      speakConsequence('The shadow sets, and the key turns');
      return true;
    }
    return false;
  }

  /// The grid verbs: Dark's pin, Steam's veil and pipe, Light's crank.
  bool _tryGridVerb(DungeonCreature a, DungeonRoom room) {
    final def = _gridOf(room)!;
    if (archive.solved.contains(def.id)) return false;
    final me = _shadowName(a);
    final s = _liveState(room);
    final here = s.pos[me]!;
    switch (me) {
      case 'Dark':
        if (def.pins <= 0) return false;
        if (s.pins == 0 && s.pinned.contains(sqKey(here.x, here.y))) {
          // Release, if nobody would be left on nothing.
          final bare = s.copyWith(pinned: const {});
          for (final n in kShadowNames) {
            final p = s.pos[n]!;
            if (!s.pinned.contains(sqKey(p.x, p.y))) continue;
            if (def.at(p.x, p.y) == 'B' ||
                (def.orbit == null && !shadowHolds(def, bare, p.x, p.y, n))) {
              _setBlockedHint('$n is standing on the stone');
              return true;
            }
          }
          archive.rooms[def.id] = s.copyWith(pinned: const {}, pins: def.pins);
          archive.stoneSet.clear();
          _cue(SoundCue.dungeonSwitch);
          speakConsequence('The stone lets go and is shadow again');
          return true;
        }
        if (!def.isGlass(here.x, here.y)) return false;
        if (s.pins == 0) {
          _setBlockedHint('The pin is spent');
          return true;
        }
        final cells = shadowPinCells(def, s);
        if (cells == null || cells.isEmpty) {
          _setBlockedHint('There is no shadow here to pin');
          return true;
        }
        archive.stoneRoom = def.id;
        final origin = Offset(here.x.toDouble(), here.y.toDouble());
        for (final k in cells) {
          final q = sqOf(k);
          // The stone sets outward from where Dark stands.
          final d = (Offset(q.x.toDouble(), q.y.toDouble()) - origin).distance;
          archive.stoneSet[k] = _time + d * 0.07;
        }
        archive.rooms[def.id] = s.copyWith(
          pinned: {...s.pinned, ...cells},
          pins: s.pins - 1,
        );
        archive.pinT = _time;
        _cue(SoundCue.dungeonSecretReveal);
        final wall = cells.any((k) => def.at(sqOf(k).x, sqOf(k).y) == 'B');
        speakConsequence(
          wall
              ? 'The shadow sets into stone, and where it lay on the wall '
                    'there is a door'
              : 'The shadow sets into stone',
        );
        return true;
      case 'Steam':
        if (def.vents.any((v) => v.x == here.x && v.y == here.y)) {
          if (s.veil != null && s.veil!.x == here.x && s.veil!.y == here.y) {
            _setBlockedHint('The veil is already hanging here');
            return true;
          }
          archive.rooms[def.id] = s.copyWith(veil: here);
          archive.veilT = _time;
          _cue(SoundCue.dungeonInteract);
          speakConsequence('A veil of steam rises from the vent and hangs');
          return true;
        }
        for (final (from, to) in def.pipes) {
          if (from.x != here.x || from.y != here.y) continue;
          if (s.piped) {
            _setBlockedHint('The pipe is spent');
            return true;
          }
          if (shadowOccupant(s, to.x, to.y, 'Steam') != null) {
            _setBlockedHint('Something is standing on the far mouth');
            return true;
          }
          _spawnAlchemyBurst(
            shadowCentre(here.x, here.y),
            producedElement: 'Steam',
            particleCount: 22,
          );
          a
            ..position = shadowCentre(to.x, to.y)
            ..lastSafe = shadowCentre(to.x, to.y);
          archive.rooms[def.id] = s.copyWith(
            piped: true,
            pos: {...s.pos, 'Steam': to},
          );
          _spawnAlchemyBurst(
            shadowCentre(to.x, to.y),
            producedElement: 'Steam',
            particleCount: 22,
          );
          _cue(SoundCue.dungeonInteract);
          speakConsequence(
            'Steam rises through the pipe, and the pipe is spent',
          );
          return true;
        }
        return false;
      case 'Light':
        if (def.rail == null || def.at(here.x, here.y) != 'C') return false;
        archive
          ..railFrom = s.rail.toDouble()
          ..railT = _time;
        _applyShadowFalls(
          def,
          s.copyWith(rail: (s.rail + 1) % def.rail!.length),
        );
        _cue(SoundCue.dungeonSwitch);
        return true;
    }
    return false;
  }

  /// The light has moved: anyone left on bare light falls back to the door.
  void _applyShadowFalls(ShadowRoomDef def, ShadowState next) {
    final r = shadowResolveFalls(def, next);
    archive.rooms[def.id] = r.state;
    for (final n in r.fell) {
      final c = _shadowBody(n);
      if (c == null) continue;
      final to = r.state.pos[n]!;
      _spawnAlchemyBurst(
        c.position,
        producedElement: 'Light',
        particleCount: 14,
      );
      c
        ..position = shadowCentre(to.x, to.y)
        ..lastSafe = shadowCentre(to.x, to.y);
      archive.fellT[n] = _time;
    }
    if (r.fell.isNotEmpty) {
      speakConsequence(
        '${r.fell.join(' and ')} ${r.fell.length > 1 ? 'fall' : 'falls'} '
        'through the light, back to the ledge',
      );
    }
  }

  // ── Solarin ──────────────────────────────────────────────

  /// Where Solarin hangs right now, in world (swinging round its orbit
  /// while it moves).
  Offset _solarinDrawn(ShadowRoomDef def) {
    final s = archive.state(def.id);
    final to = def.orbit![s.orbit];
    final end = shadowCentre(to.x, to.y);
    if (archive.orbitFrom < 0) return end;
    final t = ((_time - archive.orbitT) / kSolarinSwing).clamp(0.0, 1.0);
    if (t >= 1) return end;
    final e = t * t * (3 - 2 * t);
    final fr = def.orbit![archive.orbitFrom.toInt()];
    final start = shadowCentre(fr.x, fr.y);
    final pivot = def.swingCentre;
    final mid = shadowCentre(pivot.x, pivot.y);
    final a0 = atan2(start.dy - mid.dy, start.dx - mid.dx);
    final a1 = atan2(end.dy - mid.dy, end.dx - mid.dx);
    var da = a1 - a0;
    da = atan2(sin(da), cos(da));
    final r0 = (start - mid).distance, r1 = (end - mid).distance;
    final a = a0 + da * e, rr = r0 + (r1 - r0) * e;
    return mid + Offset(cos(a), sin(a)) * rr;
  }

  /// Every frame of the fight. Solarin holds, shows where it goes next, and
  /// swings on; the shadows sweep with it. Its light burns the active body
  /// on bare glass, it fires bolts at the party, and it can be struck only
  /// from its shadow, two squares off.
  void _applySolarinOrbit(DungeonRoom room, double dt) {
    final def = _gridOf(room);
    if (def?.orbit == null) return;
    final e = _guardianEnemy;
    // Brought down: its light goes out where it fell. Nothing swings, burns
    // or fires any more (a debug rematch keeps this hook running after).
    if ((e != null && e.isDead) || _guardianHpFraction <= 0) {
      guardianVulnerable = false;
      archive.bolts.clear();
      final s = archive.state(def!.id);
      if (s.sun != null) archive.rooms[def.id] = s.copyWith(still: true);
      archive.orbitFrom = -1;
      return;
    }
    // ITS RHYTHM: hold, warn, swing. Faster once it is hurt.
    archive.swingNext -= dt;
    if (archive.swingNext <= 0) _solarinSwing(def!, _liveState(room));
    final at = _solarinDrawn(def!);
    if (e != null && !e.isDead) e.position = at;
    // Mid-swing its light comes from where it is along the arc, so the
    // shadows sweep with it rather than jump.
    final swinging =
        archive.orbitFrom >= 0 && _time - archive.orbitT < kSolarinSwing;
    final s = _liveState(room).copyWith(
      sun: swinging
          ? (
              x: at.dx / kShadowCell - .5,
              y: (at.dy - kShadowTop) / kShadowCell - .5,
            )
          : null,
      still: !swinging,
    );
    archive.rooms[def.id] = s;

    final a = active;
    if (a == null || !a.alive) {
      guardianVulnerable = false;
      return;
    }
    final me = _shadowName(a);
    final burns = shadowSolarinBurns(def, s, me);
    guardianVulnerable = !burns && shadowSolarinReach(def, s, me);

    // ITS LIGHT BURNS: bare glass it reaches, with nothing between.
    if (burns) {
      a.hp = max(
        0,
        a.hp -
            kSolarinBurnDps *
                progressDmgMul *
                _guardianAttackMitigation(a) *
                dt,
      );
      archive.burnT = _time;
      if (!archive.burnTold) {
        archive.burnTold = true;
        _setHint('Its light burns', 2.4);
      }
    }

    _solarinBolts(def, s, at, dt);
  }

  /// ITS BOLTS: slow light, at each of the party out on the glass in turn
  /// (a fan of three once it is hurt). A bolt stops at the first pillar,
  /// veil or body in its way — whatever shades you from Solarin also shields
  /// you. The ledge by the door is out of its reach.
  void _solarinBolts(ShadowRoomDef def, ShadowState s, Offset from, double dt) {
    final hurt = _guardianHpFraction < 0.5;
    archive.boltNext -= dt;
    if (archive.boltNext <= 0) {
      archive.boltNext = hurt ? kSolarinBoltEveryHurt : kSolarinBoltEvery;
      final targets = [
        for (final c in creatures)
          if (c.alive && c.position.dx > 2 * kShadowCell) c,
      ];
      if (targets.isNotEmpty) {
        final t = targets[archive.boltTurn++ % targets.length];
        final d = t.position - from;
        if (d.distance > 1) {
          final base = atan2(d.dy, d.dx);
          for (final da in hurt ? const [-0.26, 0.0, 0.26] : const [0.0]) {
            archive.bolts.add(
              SolarBolt(
                from,
                Offset(cos(base + da), sin(base + da)) * kSolarinBoltSpeed,
              ),
            );
          }
          _cue(SoundCue.dungeonHazardTrigger);
        }
      }
    }
    if (archive.bolts.isEmpty) return;
    final grid = Rect.fromLTWH(
      0,
      kShadowTop,
      def.cols * kShadowCell,
      def.rows * kShadowCell,
    );
    final shields = [
      for (final c in def.fixedCasters)
        (shadowCentre(c.x, c.y), c.r * kShadowCell),
      if (s.veil != null)
        (shadowCentre(s.veil!.x, s.veil!.y), kShadowVeilR * kShadowCell),
    ];
    archive.bolts.removeWhere((b) {
      b
        ..p += b.v * dt
        ..age += dt;
      if (!grid.contains(b.p) || b.age > 8) return true;
      for (final (c, r) in shields) {
        if ((b.p - c).distance < r + kSolarinBoltRadius) {
          archive.boltBursts.add((b.p, _time));
          return true;
        }
      }
      for (final c in creatures) {
        if (!c.alive) continue;
        if ((b.p - c.position).distance > 20 + kSolarinBoltRadius) continue;
        c.hp = max(
          0,
          c.hp -
              kSolarinBoltDamage *
                  progressDmgMul *
                  _guardianAttackMitigation(c),
        );
        archive.boltBursts.add((b.p, _time));
        _spawnAlchemyBurst(b.p, producedElement: 'Light', particleCount: 12);
        return true;
      }
      return false;
    });
    archive.boltBursts.removeWhere((e) => _time - e.$2 > .5);
  }

  /// Solarin swings to the next point of its orbit and holds again.
  void _solarinSwing(ShadowRoomDef def, ShadowState s) {
    archive
      ..orbitFrom = s.orbit.toDouble()
      ..orbitT = _time
      // It holds once it has arrived, not from when it set off.
      ..swingNext =
          kSolarinSwing +
          (_guardianHpFraction < 0.5 ? kSolarinHoldHurt : kSolarinHold);
    archive.rooms[def.id] = s.copyWith(
      orbit: (s.orbit + 1) % def.orbit!.length,
      still: true,
    );
    _cue(SoundCue.dungeonSwitch);
  }

  /// Why a blow at Solarin did not land: bare, what is wrong.
  String _solarinBlockedLine() {
    final def = _gridOf(currentRoom);
    final a = active;
    if (def?.orbit == null || a == null) return 'Out of reach';
    final s = _liveState(currentRoom);
    return shadowSolarinBurns(def!, s, _shadowName(a))
        ? 'Too bright. Its light blinds you'
        : 'Too far';
  }

  /// A blow landed: Solarin swings on at once (unless it already is).
  void _solarinStruck() {
    final room = currentRoom;
    final def = _gridOf(room);
    if (def?.orbit == null) return;
    if (archive.orbitFrom >= 0 && _time - archive.orbitT < kSolarinSwing) {
      return;
    }
    _solarinSwing(def!, _liveState(room));
  }

  // ── Per-frame ────────────────────────────────────────────

  void _updateArchive(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isArchive) return;
    final bay = room.hall;
    if (bay == null) return;
    if (bay.kind == 'hall') {
      // The spans a solved room owes the hall set as you walk back in.
      for (final id in kBridgeRooms) {
        if (archive.solved.contains(id) && !archive.spanSet.containsKey(id)) {
          archive.spanSet[id] = _time + 0.5;
          _cue(SoundCue.dungeonGateOpen);
        }
      }
      // THE LOST MAXIM: Light, out on the gold sun.
      if (!discoveredClouds.contains(kLightEggId) &&
          _ritePendingEgg != kLightEggId &&
          _shadowName(a) == 'Light') {
        final t = shadowSquareAt(a.position, kHallCols, kHallRows);
        if (t.x == kHallSun.x && t.y == kHallSun.y) {
          archive.maximT = _time;
          _cue(SoundCue.dungeonSecretReveal);
          soundedSecrets.add(kLightEggId);
          beginMaximRite(kLightEggId, shadowCentre(kHallSun.x, kHallSun.y));
        }
      }
      return;
    }
    if (bay.kind == 'key') {
      if (archive.keyPinned &&
          !archive.solved.contains('key_room') &&
          _time - archive.keyT > 2.2) {
        _solveRoom('key_room');
      }
      return;
    }
    final def = bay.def!;
    if (def.orbit != null) return; // the fight is the engine's
    final s = _liveState(room);
    archive.rooms[def.id] = s;
    if (!archive.solved.contains(def.id) && shadowSolved(def, s)) {
      _solveRoom(def.id);
    }
  }

  /// A room is solved: its whole floor sets into stone (so the way back is
  /// walkable), its span is owed to the hall, and a pair banks its star.
  void _solveRoom(String id) {
    archive.solved.add(id);
    archive.solvedT = _time;
    final def = kShadowRooms[id];
    if (def != null) {
      final s = archive.state(id);
      archive.stoneRoom = id;
      final g = def.start.values.first;
      for (final k in _allGlass(def)) {
        if (s.pinned.contains(k)) continue;
        final q = sqOf(k);
        final d =
            (Offset(q.x.toDouble(), q.y.toDouble()) -
                    Offset(g.x.toDouble(), g.y.toDouble()))
                .distance;
        archive.stoneSet[k] = _time + 0.4 + d * 0.06;
      }
      archive.rooms[id] = s.copyWith(pinned: {...s.pinned, ..._allGlass(def)});
    }
    _cue(SoundCue.dungeonPuzzleSolved);
    speakConsequence(switch (id) {
      'own_shadow' => 'All three across. The floor sets in stone behind you',
      'key_room' => 'The arch opens. The light was the door all along',
      'two_suns' => 'All three across, and not a lit square under you',
      'two_gaps' => 'All three at the top. The floor sets in stone',
      'door_of_shadow' => 'Through a door that was only a shadow',
      'eclipse_walk' => 'Across on the eclipse. Solarin is below',
      'sunless_reliquary' => 'The relic\'s own shadow was the road to it',
      _ => 'The floor sets in stone',
    });
    final star = kBridgeStar[id];
    if (star != null && !hasStar(star)) {
      final pair = kBridgeRooms.where((r) => kBridgeStar[r] == star);
      if (pair.every(archive.solved.contains)) earnStar(star);
    }
    if (id == 'door_of_shadow') {
      // The rite: Solarin wakes when the party comes down the stair.
      conduitEnergy['A'] = double.infinity;
      conduitEnergy['B'] = double.infinity;
    }
  }

  // ── Doors ────────────────────────────────────────────────

  bool _archiveDoorHidden(DungeonRoom room, DungeonDoor door) => false;

  bool _archiveDoorBlocked(DungeonRoom room, DungeonDoor door) {
    if (!_isArchive) return false;
    // The reliquary's dim door takes the key room's lesson to open.
    return room.id == layout.entranceRoomId &&
        door.targetRoomId == 'sunless_reliquary' &&
        !archive.solved.contains('key_room');
  }

  String _archiveDoorHint(DungeonRoom room, DungeonDoor door) =>
      'A dim door, and it is locked';

  // ── Readouts, hints ──────────────────────────────────────

  DungeonProgressReadout? _archiveProgressReadout() {
    final def = currentRoom.hall?.def;
    if (def == null || def.pins <= 0) return null;
    if (archive.solved.contains(def.id)) return null;
    final s = archive.state(def.id);
    return DungeonProgressReadout(
      label: 'PIN',
      value: s.pins > 0 ? 'READY' : 'SPENT',
      fraction: s.pins / def.pins,
    );
  }

  String _archiveRoomWord(String roomId) => switch (roomId) {
    'light_hall' => 'The Great Hall',
    'own_shadow' => 'Nothing Stands on Its Own Shadow',
    'key_room' => 'The Key',
    'two_suns' => 'Two Suns',
    'two_gaps' => 'Two Gaps, One Pin',
    'door_of_shadow' => 'The Door of Shadow',
    'eclipse_walk' => 'The Eclipse',
    'solarin_orbit' => 'Solarin',
    'sunless_reliquary' => 'The Sunless Reliquary',
    _ => roomId,
  };

  /// The line a room says as you arrive: its name, and nothing about how.
  String? _archiveObjectiveHint(DungeonRoom room) {
    final word = _archiveRoomWord(room.id);
    if (room.hall?.kind == 'hall') {
      return entryDoorRevealed ? word : '$word. Its star is dark';
    }
    if (archive.solved.contains(room.id)) return '$word. Set in stone';
    return word;
  }

  void _archiveAmbientHint(DungeonCreature a, DungeonRoom room) {}

  /// THE HINT BUTTON — bare: what is wrong here, never how.
  void _archiveReveal(DungeonCreature a, DungeonRoom room) {
    _setInsightHint(_archiveWhatsWrong(room));
  }

  String _archiveWhatsWrong(DungeonRoom room) {
    final bay = room.hall;
    if (bay == null) return 'Nothing is wrong here';
    if (bay.kind == 'hall') {
      if (!entryDoorRevealed) return 'The hall\'s star is dark';
      if (!archive.bridgeWhole) return 'The well is not bridged';
      return 'The Door of Shadow waits';
    }
    if (bay.kind == 'key') {
      if (archive.solved.contains('key_room')) return 'The arch is open';
      if (!archive.keyVeil) return 'The arch is only light';
      return keyFits(archive.keyLampX, archive.keyLampY)
          ? 'The shadow fits the lock'
          : 'The shadow does not fit the lock';
    }
    final def = bay.def!;
    if (def.orbit != null) {
      final a = active;
      if (a != null &&
          shadowSolarinBurns(def, archive.state(def.id), _shadowName(a))) {
        return 'You are standing in its light';
      }
      return 'Solarin hangs in its own light';
    }
    if (archive.solved.contains(def.id)) return 'This floor is set in stone';
    final s = archive.state(def.id);
    if (def.goal == 'any') return 'The relic is across the light';
    final left = kShadowNames
        .where((n) => def.at(s.pos[n]!.x, s.pos[n]!.y) != 'G')
        .length;
    return left == 1
        ? 'One of you is not across'
        : '$left of you are not across';
  }

  /// Per-room mood: a sanctuary, bright throughout; brightest at Solarin.
  double get _archiveMoodTarget => switch (currentRoomId) {
    'light_hall' => 0.9,
    'solarin_orbit' => guardianAwake ? 0.98 : 0.8,
    'sunless_reliquary' => 0.62,
    _ => 0.82,
  };
}
