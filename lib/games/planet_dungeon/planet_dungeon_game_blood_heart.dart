// lib/games/planet_dungeon/planet_dungeon_game_blood_heart.dart
//
// HEMAVORN — THE HEART, played (the author's design, 2026-10-06). The rules
// are planet_dungeon_blood_heart.dart (proved against the prototype); the
// drawing is planet_dungeon_game_blood_heart_art.dart.
//
//   · THE CAPTURE. Blood walks down from the seal onto the stage, comes
//     apart into grains of itself, and is drawn up into the open space and
//     bound there. The four it freed pour in after it and stand on the
//     stage; the player now steers them (the swap rail), Blood's own body is
//     out of the party.
//   · FUSING. Walk one onto an altar's stone while another stands on the
//     other, and stand still a moment: they come apart and gather into a
//     creature of what they make (a real species of that element). It comes
//     apart into its element, which rises up the altar's column in its own
//     way to the first element hanging there. If the two have a recipe they
//     fuse up there and what they make pours down onto the altar in its
//     place; if not, it gathers back. A pair with no recipe doesn't fuse.
//   · THE CAMERA plays close on the stage and cuts up to the elements: it
//     rises to frame whatever happens in the open space, then comes down.
//   · SPLITTING. A fused creature standing still on the split stage comes
//     apart into the two that made it.
//   · BLOOD. Light + Dark make Blood, which pours into the bound Blood; its
//     bands let go, everything else comes apart, and the four re-form beside
//     it (the author's pick). Star 2; the floor opens on Sanguorath.
//
// Nothing is timed and nothing is chance (a fused creature's SPECIES is a
// random one of its element; what it is and does never is).

part of 'planet_dungeon_game.dart';

/// Seconds a creature stands still on a stone before it acts, so walking
/// across an altar never fuses anything.
const double kHeartDwell = .35;

/// The new creature comes apart into its element this long after the
/// fusion starts: once it has formed and stood a beat.
const double kHeartPowerAt = 2.0;

/// Bodies coming apart and gathering: the grains, and which bodies the
/// drawing stands in for (sources come apart top first; targets fade in).
class HeartMorph {
  HeartMorph(
    this.fx, {
    this.sources = const [],
    this.targets = const [],
    this.onDone,
  });
  final RiteMorphFx fx;
  final List<(DungeonCreature, Offset)> sources;
  final List<(DungeonCreature, Offset)> targets;
  final VoidCallback? onDone;
}

/// What two made on an altar, rising up its column: the creature [made]
/// comes apart into its element, in grains ([fx]). If it fuses with what
/// hangs there, what they make ([landed], its body) comes down to the altar
/// in its place; otherwise [made] gathers back.
class HeartPower {
  HeartPower(
    this.altar,
    this.el,
    this.run,
    this.made,
    RiteBody body, {
    this.landed,
    this.landedUnit,
  }) : fx = HeartRiseFx(
         body: body,
         el: el,
         at: riteCentreOf(altar.front.x, altar.front.y),
         reach: _reachOf(run),
         dir: altar.dir,
         hits: run.hit != null,
         into: run.fused,
       );
  final HeartAltar altar;
  final String el;
  final HeartRun run;
  final DungeonCreature made;
  final DungeonCreature? landed;
  final HeartUnit? landedUnit;
  final HeartRiseFx fx;
  double t = 0;
  bool out = false, met = false, down = false;

  /// How far it rises: to the near side of what hangs there, or the top.
  static double _reachOf(HeartRun run) => run.hit != null
      ? (run.path.length + .5) * kRiteCell
      : max(kRiteCell, run.path.length * kRiteCell);
  double get reach => fx.reach;
  double get travel => fx.travel;

  /// Seconds from the fusion's start to the head reaching what hangs
  /// there, to its coming back down, and to the end of it.
  double get hitAt => kHeartPowerAt + fx.hitAt;
  double get returnAt => kHeartPowerAt + fx.returnAt;
  double get duration => kHeartPowerAt + fx.duration;

  /// Where it met what hangs there (the middle of the cloud).
  Offset get head => fx.at + fx.up * (fx.reach + 20);
}

/// The Heart's state for one run.
class HeartRunState {
  final HeartRoom room = heartRoom();
  late HeartState state = heartStart(room);

  /// The game's body for each creature in the rules (by unit id).
  final Map<String, DungeonCreature> bodies = {};

  /// Blood's own body (and its combat companion) while it is bound.
  DungeonCreature? blood;
  CosmicSurvivalCompanion? bloodCompanion;

  /// Blood has been taken this visit, and not yet freed.
  bool taken = false;

  /// Blood was freed (this run, or before it began).
  bool freed = false;

  /// Bodies the engine leaves undrawn (the Heart draws them mid-morph).
  final Set<DungeonCreature> hidden = {};
  final List<HeartMorph> morphs = [];
  final List<HeartPower> powers = [];

  /// Elements hanging there that something rising will fuse with, still
  /// drawn until it reaches them ('x,y' → the element), and when each was
  /// drawn into what rose (that plays from it).
  final Map<String, String> pending = {};
  final Map<String, (String, double)> broke = {};

  /// The capture's clock (−1 when not playing), and the finale's.
  double captureT = -1, finaleT = -1;

  /// Blood drawn bound in its niche (since when), and how far its bands
  /// have let go.
  bool bound = false;
  double boundT = -9;
  double bandsK = 0;

  /// The Blood made from Light and Dark, while it pours into the niche.
  DungeonCreature? finaleMade;

  /// Standing still on a stone.
  String? dwellKey;
  double dwell = 0;
  String? actedKey;

  /// A body ready for each element a fusion can make (the screen's species;
  /// a fresh one is loaded after each use, so species vary).
  final Map<String, DungeonCreature> templates = {};

  /// A small fizzle where a pair would not fuse, in both their colours.
  Offset? fizzleAt;
  double fizzleT = -9;
  List<Color> fizzleCols = const [Color(0xFFB8B0A8), Color(0xFFB8B0A8)];

  /// THE CAMERA: close on the stage while it is played, up into the open
  /// space while something happens there (eased, never a jump).
  Offset? camAt;
  double camZoom = 1;

  /// Names shown by tapping what hangs there ('x,y' → the showing), and
  /// each name laid out as grains once it has been read.
  final Map<String, HeartWordFx> words = {};
  final Map<String, HeartWord> wordGrains = {};
  final Set<String> wordReading = {};
}

extension BloodHeartDungeon on PlanetDungeonGame {
  HeartRunState get _heart => rites.heart;

  bool get riteHeartFreed => discoveredClouds.contains(kRiteHeartFreedId);

  /// Busy: the capture, a morph, a power or the finale is playing (nobody
  /// walks while the camera is up in the open space).
  bool get _heartBusy =>
      _heart.captureT >= 0 ||
      _heart.morphs.isNotEmpty ||
      _heart.powers.isNotEmpty ||
      _heart.finaleT >= 0;

  // ── Species ──────────────────────────────────────────────

  /// The elements a fusion here can make, or the room can free.
  static const List<String> _kHeartElements = [
    'Steam',
    'Lava',
    'Mud',
    'Ice',
    'Dust',
    'Lightning',
    'Crystal',
    'Fire',
    'Water',
    'Earth',
    'Air',
    'Spirit',
    'Light',
    'Dark',
    'Poison',
    'Plant',
    'Blood',
  ];

  /// Load a body for [el] (a random species of it, or a stand-in).
  Future<void> _heartPrepare(String el) async {
    final pool = riteSpecies[el] ?? const <CosmicPartyMember>[];
    final m = pool.isEmpty
        ? (party.isEmpty ? null : _riteStandIn(party.first, el))
        : pool[_combatRng.nextInt(pool.length)];
    if (m == null) return;
    final c = DungeonCreature(member: m);
    await _loadSprite(c);
    _heart.templates[el] = c;
  }

  Future<void> _heartPrepareAll() async {
    await Future.wait([for (final el in _kHeartElements) _heartPrepare(el)]);
  }

  /// A new body of [el] from its template (a fresh one is loaded behind it).
  DungeonCreature _heartBody(String el, Offset at) {
    final tpl = _heart.templates[el];
    final m =
        tpl?.member ??
        (party.isEmpty
            ? CosmicPartyMember(
                instanceId: 'heart_$el',
                baseId: 'heart_$el',
                displayName: el,
                element: el,
                family: 'kin',
                level: 1,
                statSpeed: 1,
                statIntelligence: 1,
                statStrength: 1,
                statBeauty: 1,
                slotIndex: -1,
                staminaBars: 1,
                staminaMax: 1,
              )
            : _riteStandIn(party.first, el));
    final c = DungeonCreature(member: m)
      ..position = at
      ..lastSafe = at;
    final anim = tpl?.ticker?.spriteAnimation;
    if (anim != null) {
      c
        ..ticker = anim.createTicker()
        ..spriteScale = tpl!.spriteScale
        ..sizeK = tpl.sizeK;
    }
    unawaited(_heartPrepare(el));
    return c;
  }

  /// A body read into grains for a morph.
  RiteBody _heartRead(DungeonCreature c) {
    final b = RiteBody(elementColor(c.member.element));
    final img = _riteSnapshot(c);
    if (img != null) {
      unawaited(b.read(img, kRiteSnapRatio));
    } else {
      b.force();
    }
    return b;
  }

  // ── The party ────────────────────────────────────────────

  void _heartAddBody(DungeonCreature c, {CosmicSurvivalCompanion? companion}) {
    if (creatures.contains(c)) return;
    c
      ..hp = c.maxHp
      ..downHandled = false
      ..respawnTimer = 0;
    creatures.add(c);
    combatCompanions.add(
      companion ?? _createCombatCompanion(c.member, c.position),
    );
  }

  void _heartRemoveBody(DungeonCreature c) {
    final i = creatures.indexOf(c);
    if (i < 0) return;
    final wasActive = i == activeIndex;
    creatures.removeAt(i);
    if (i < combatCompanions.length) combatCompanions.removeAt(i);
    if (activeIndex > i || activeIndex >= creatures.length) {
      activeIndex = max(0, activeIndex - 1);
    }
    if (wasActive && creatures.isNotEmpty)
      activeIndex = min(activeIndex, creatures.length - 1);
  }

  void _heartActivate(DungeonCreature c) {
    final i = creatures.indexOf(c);
    if (i >= 0) activeIndex = i;
  }

  DungeonCreature? _heartBodyOf(HeartUnit u) => _heart.bodies[u.id];

  HeartUnit? _heartUnitOf(DungeonCreature c) {
    for (final u in _heart.state.units) {
      if (identical(_heart.bodies[u.id], c)) return u;
    }
    return null;
  }

  // ── Arriving ─────────────────────────────────────────────

  /// Down through the seal: begin the capture (or, freed before, nothing).
  void _heartArrive() {
    final h = _heart
      ..camAt = null
      ..camZoom = 1;
    if (riteHeartFreed || h.freed) {
      h.freed = true;
      h.state = _heartClearedState();
      return;
    }
    if (h.taken) return; // came back in mid-rite (cannot happen: no way out)
    // The names of what hangs there, read into grains ahead of a tap.
    for (final el in {...h.room.holds.values, 'Blood'}) {
      unawaited(_heartReadWord(el));
    }
    h
      ..state = heartStart(h.room)
      ..taken = true
      ..captureT = 0
      ..bound = false
      ..bandsK = 0
      ..pending.clear()
      ..broke.clear()
      ..powers.clear()
      ..morphs.clear()
      ..hidden.clear()
      ..bodies.clear();
    unawaited(_heartPrepareAll());
  }

  /// The Heart as it stands once Blood is free: nothing in the way.
  HeartState _heartClearedState() {
    final s = heartStart(_heart.room);
    for (final row in s.cells) {
      for (var x = 0; x < row.length; x++) {
        if (row[x] == kHeartHanging) row[x] = 'v';
      }
    }
    s.holds.clear();
    s.units.clear();
    return s;
  }

  /// THE CAPTURE, step by step, from [HeartRunState.captureT].
  void _heartCaptureTick(double dt) {
    final h = _heart;
    final t0 = h.captureT;
    h.captureT += dt;
    final t = h.captureT;
    final room = h.room;
    // 0.8s: Blood comes apart and is drawn into its niche.
    if (t0 < .8 && t >= .8) {
      final b = active;
      if (b != null) {
        h.blood = b;
        final i = creatures.indexOf(b);
        h.bloodCompanion = i >= 0 && i < combatCompanions.length
            ? combatCompanions[i]
            : null;
        h.hidden.add(b);
        final niche = riteCentreOf(room.blood.x, room.blood.y);
        final body = _heartRead(b);
        h.morphs.add(
          HeartMorph(
            RiteMorphFx(
              sources: [(body, b.position)],
              targets: [(body, niche)],
              flight: 1.5,
              bow: .22,
              spread: .5,
            ),
            sources: [(b, b.position)],
            targets: [(b, niche)],
            onDone: () {
              h
                ..bound = true
                ..boundT = _time;
            },
          ),
        );
        _cue(SoundCue.dungeonHazardTrigger);
      }
    }
    // 3.7s, once Blood has been bound and held a beat: the four pour in
    // after it, one after another, and Blood's body leaves the party.
    if (t0 < 3.7 && t >= 3.7) {
      final stair = riteCentreOf(0, 7) + const Offset(20, 0);
      var k = 0;
      for (final (el, at) in room.starts) {
        final ally = rites.allies
            .where((c) => c.member.element == el)
            .firstOrNull;
        if (ally == null) continue;
        final pos = riteCentreOf(at.x, at.y);
        ally
          ..position = pos
          ..lastSafe = pos;
        _heartAddBody(ally);
        h.hidden.add(ally);
        h.bodies[el] = ally;
        final body = _heartRead(ally);
        final fx = RiteMorphFx(
          targets: [(body, pos)],
          from: stair,
          flight: .9 + k * .25,
          spread: .3,
        );
        h.morphs.add(
          HeartMorph(
            fx,
            targets: [(ally, pos)],
            onDone: () => h.hidden.remove(ally),
          ),
        );
        k++;
      }
      final b = h.blood;
      if (b != null) _heartRemoveBody(b);
      final first = h.bodies['Fire'];
      if (first != null) _heartActivate(first);
      _cue(SoundCue.dungeonSecretReveal);
    }
    if (t >= 3.9 && h.morphs.isEmpty) {
      h.captureT = -1;
      onChanged();
    }
  }

  // ── Walking ──────────────────────────────────────────────

  /// Can't the active creature step from [here] in [dir]?
  bool _heartStepBlocked(DungeonRoom room, RiteCell here, int dir) {
    if (_heartBusy) return true;
    final t = (x: here.x + kRiteDx[dir], y: here.y + kRiteDy[dir]);
    if (_riteDoorSquare(room, t)) return false;
    // The floor that opens on Sanguorath, once it has.
    if (_heart.freed && t == kRiteHeartWayDown) return false;
    final ok =
        heartWalkable(_heart.room, _heart.state.cells, t.x, t.y) &&
        !_heart.pending.containsKey('${t.x},${t.y}');
    if (!ok) _riteBump(here, dir);
    return !ok;
  }

  // ── Standing still on a stone ────────────────────────────

  void _heartDwellTick(DungeonCreature a, double dt) {
    final h = _heart;
    if (_heartBusy || !h.taken || h.freed) return;
    final sq = riteSquareAt(a.position);
    final mid = riteCentreOf(sq.x, sq.y);
    final still =
        (a.position - mid).distance < 16 && joystickDirection.distance < .25;
    final key = '${identityHashCode(a)}@${sq.x},${sq.y}';
    if (key != h.dwellKey) {
      h.dwellKey = key;
      h.dwell = 0;
    }
    if (h.actedKey != null && h.actedKey != key) h.actedKey = null;
    if (!still || h.actedKey == key) return;
    h.dwell += dt;
    if (h.dwell < kHeartDwell) return;
    h.actedKey = key;
    final me = _heartUnitOf(a);
    if (me == null) return;
    // An altar: someone on the other stone?
    for (var ai = 0; ai < h.room.altars.length; ai++) {
      final alt = h.room.altars[ai];
      final onBack = sq == alt.back, onFront = sq == alt.front;
      if (!onBack && !onFront) continue;
      final other = onBack ? alt.front : alt.back;
      HeartUnit? them;
      for (final u in h.state.units) {
        if (u.id == me.id) continue;
        final b = _heartBodyOf(u);
        if (b == null || h.hidden.contains(b)) continue;
        if (riteSquareAt(b.position) == other) them = u;
      }
      if (them == null) return;
      _heartFuse(ai, onBack ? me : them, onBack ? them : me);
      return;
    }
    // The split stage.
    if (h.room.cells[sq.y][sq.x] == 'S' && me.parts != null)
      _heartSplit(me, sq);
  }

  // ── Fusing ───────────────────────────────────────────────

  void _heartFuse(int ai, HeartUnit back, HeartUnit front) {
    final h = _heart;
    final alt = h.room.altars[ai];
    final bb = _heartBodyOf(back), fb = _heartBodyOf(front);
    if (bb == null || fb == null) return;
    final f = heartFuse(
      h.room,
      _heartNow(),
      ai,
      back.moved(alt.back),
      front.moved(alt.front),
    );
    if (f == null) {
      // They don't fuse: a little of each colour, and nothing more.
      h
        ..fizzleAt = riteCentreOf(alt.front.x, alt.front.y)
        ..fizzleT = _time
        ..fizzleCols = [elementColor(back.el), elementColor(front.el)];
      _cue(SoundCue.dungeonInteract);
      return;
    }
    // What hangs there stays drawn until what rises reaches it.
    final hit = f.run.hit;
    if (f.run.fuses && hit != null) {
      h.pending['${hit.x},${hit.y}'] = f.run.hanging!;
    }
    h.state = f.state;
    final at = riteCentreOf(alt.front.x, alt.front.y);
    final made = _heartBody(f.made.el, at);
    h.bodies[f.made.id] = made;
    // The two come apart and gather into what they make.
    final sources = [(bb, bb.position), (fb, fb.position)];
    h.hidden
      ..add(bb)
      ..add(fb)
      ..add(made);
    _heartAddBody(made);
    final fx = RiteMorphFx(
      sources: [(_heartRead(bb), bb.position), (_heartRead(fb), fb.position)],
      targets: [(_heartRead(made), at)],
      flight: .8,
      spread: .35,
      bow: .35,
    );
    h.morphs.add(
      HeartMorph(
        fx,
        sources: sources,
        targets: [(made, at)],
        onDone: () {
          h.hidden.remove(made);
          _heartRemoveBody(bb);
          _heartRemoveBody(fb);
          h.hidden
            ..remove(bb)
            ..remove(fb);
          _heartActivate(made);
          // It stands on the front stone: don't let it act there at once.
          h.actedKey =
              '${identityHashCode(made)}@${alt.front.x},${alt.front.y}';
        },
      ),
    );
    _cue(SoundCue.dungeonSwitch);
    _haptic(DungeonHaptic.success);
    if (f.made.el == 'Blood') {
      _heartFinaleBegin(made);
      return;
    }
    // If it fuses with what hangs there, what they make comes down in its
    // place: its body now (unseen until it does), and one for the element
    // that hung there, so the split stage can give it back.
    DungeonCreature? landed;
    if (f.run.fuses) {
      landed = _heartBody(f.landed.el, at);
      h.bodies[f.landed.id] = landed;
      final up = f.landed.parts![1];
      h.bodies[up.id] = _heartBody(up.el, at);
    }
    h.powers.add(
      HeartPower(
        alt,
        f.made.el,
        f.run,
        made,
        _heartRead(made),
        landed: landed,
        landedUnit: f.landed,
      ),
    );
    onChanged();
  }

  /// The rules' state with everyone where they stand now (the rules only
  /// know where each was put), so what is freed or split off comes down on
  /// a square nobody is standing on.
  HeartState _heartNow() {
    final now = _heart.state.copy();
    for (var i = 0; i < now.units.length; i++) {
      final b = _heartBodyOf(now.units[i]);
      if (b != null)
        now.units[i] = now.units[i].moved(riteSquareAt(b.position));
    }
    return now;
  }

  // ── Splitting ────────────────────────────────────────────

  void _heartSplit(HeartUnit u, RiteCell at) {
    final h = _heart;
    final r = heartSplit(h.room, _heartNow(), u, at);
    final body = _heartBodyOf(u);
    if (r == null || body == null) return;
    final (s, p, q) = r;
    h.state = s;
    final pb = _heartBodyOf(p), qb = _heartBodyOf(q);
    if (pb == null || qb == null) return;
    final pAt = riteCentreOf(p.at.x, p.at.y),
        qAt = riteCentreOf(q.at.x, q.at.y);
    pb
      ..position = pAt
      ..lastSafe = pAt;
    qb
      ..position = qAt
      ..lastSafe = qAt;
    _heartAddBody(pb);
    _heartAddBody(qb);
    h.hidden
      ..add(body)
      ..add(pb)
      ..add(qb);
    final fx = RiteMorphFx(
      sources: [(_heartRead(body), body.position)],
      targets: [(_heartRead(pb), pAt), (_heartRead(qb), qAt)],
      flight: .6,
      spread: .3,
      bow: .25,
    );
    h.morphs.add(
      HeartMorph(
        fx,
        sources: [(body, body.position)],
        targets: [(pb, pAt), (qb, qAt)],
        onDone: () {
          _heartRemoveBody(body);
          h.hidden
            ..remove(body)
            ..remove(pb)
            ..remove(qb);
          _heartActivate(pb);
          h.actedKey = '${identityHashCode(pb)}@${at.x},${at.y}';
        },
      ),
    );
    h.bodies.remove(u.id);
    _cue(SoundCue.dungeonBlockMove);
    onChanged();
  }

  // ── Powers ───────────────────────────────────────────────

  void _heartPowersTick(double dt) {
    final h = _heart;
    for (final p in List.of(h.powers)) {
      p.t += dt;
      // The creature gives way to its grains (the art draws it coming back).
      if (!p.out && p.t >= kHeartPowerAt) {
        p.out = true;
        h.hidden.add(p.made);
      }
      if (!p.met && p.t >= p.hitAt) {
        p.met = true;
        if (p.run.fuses) _heartMeet(p);
      }
      if (!p.down && p.landed != null && p.t >= p.returnAt) {
        p.down = true;
        _heartComeDown(p);
      }
      if (p.t >= p.duration) {
        h.powers.remove(p);
        if (p.landed == null) h.hidden.remove(p.made);
      }
    }
  }

  /// What rose reached what hangs there and the two fuse: the hanging one
  /// is drawn into it.
  void _heartMeet(HeartPower p) {
    final h = _heart;
    final hit = p.run.hit!;
    final k = '${hit.x},${hit.y}';
    final was = h.pending.remove(k);
    if (was != null) h.broke[k] = (was, _time);
    _cue(SoundCue.dungeonSecretReveal);
    _haptic(DungeonHaptic.success);
  }

  /// What they made up there comes down to the altar, in place of what rose.
  void _heartComeDown(HeartPower p) {
    final h = _heart;
    final b = p.landed!;
    final at = p.fx.at;
    b
      ..position = at
      ..lastSafe = at;
    _heartRemoveBody(p.made);
    _heartAddBody(b);
    h.hidden.add(b);
    _heartActivate(b);
    final fx = RiteMorphFx(
      targets: [(_heartRead(b), at)],
      from: p.head,
      flight: 1.0,
      bow: .1,
      spread: .25,
    );
    h.morphs.add(
      HeartMorph(
        fx,
        targets: [(b, at)],
        onDone: () {
          h.hidden.remove(b);
          h.hidden.remove(p.made);
          _heartActivate(b);
          h.actedKey = '${identityHashCode(b)}@${p.altar.front.x},${p.altar.front.y}';
          // Blood made up there: it pours into the Blood that was taken.
          if (b.member.element == 'Blood') _heartFinaleBegin(b);
        },
      ),
    );
    _cue(SoundCue.dungeonBlockMove);
  }

  // ── Blood ────────────────────────────────────────────────

  /// Light and Dark made Blood: it pours into the Blood that was taken.
  void _heartFinaleBegin(DungeonCreature made) {
    final h = _heart;
    h
      ..finaleT = 0
      ..finaleMade = made;
    h.powers.clear();
    _cue(SoundCue.dungeonPuzzleSolved);
    _haptic(DungeonHaptic.big);
  }

  /// THE FINALE, from [HeartRunState.finaleT]:
  ///  * 0.0 – 1.9  the Blood made from Light and Dark gathers on its stone;
  ///  * 1.9 – 4.2  it comes apart and pours, a bowed ribbon, into the Blood
  ///               bound in the niche;
  ///  * 4.3 – 5.3  the bands let go;
  ///  * 5.4 –      Blood steps out onto the stage, everything else comes
  ///               apart, and the four re-form beside it.
  void _heartFinaleTick(double dt) {
    final h = _heart;
    final t0 = h.finaleT;
    h.finaleT += dt;
    final t = h.finaleT;
    final made = h.finaleMade;
    if (t0 < 1.9 && t >= 1.9 && made != null) {
      final niche = riteCentreOf(h.room.blood.x, h.room.blood.y);
      final b = h.blood;
      final into = b == null
          ? (RiteBody(elementColor('Blood'))..force())
          : _heartRead(b);
      h.hidden.add(made);
      h.morphs.add(
        HeartMorph(
          RiteMorphFx(
            sources: [(_heartRead(made), made.position)],
            targets: [(into, niche)],
            flight: 1.4,
            spread: .5,
            bow: .32,
          ),
          sources: [(made, made.position)],
          onDone: () {
            // Blood's own body is back in the party before the made one
            // leaves it (an empty party is a wipe). It stays drawn bound.
            final b = h.blood;
            if (b != null) {
              b
                ..position = niche
                ..lastSafe = niche;
              _heartAddBody(b, companion: h.bloodCompanion);
              h.hidden.add(b);
              _heartActivate(b);
            }
            _heartRemoveBody(made);
            h.finaleMade = null;
          },
        ),
      );
      _cue(SoundCue.dungeonSecretReveal);
    }
    // The bands let go.
    if (t > 4.3) h.bandsK = _riteEase((t - 4.3) / 1.0);
    // Blood steps out of its niche onto the stage, everything else comes
    // apart, and the four re-form beside it.
    if (t0 < 5.4 && t >= 5.4) {
      final niche = riteCentreOf(h.room.blood.x, h.room.blood.y);
      final spots = <String, RiteCell>{
        'Blood': kRiteHeartFreedAt,
        'Fire': (x: 6, y: 7),
        'Water': (x: 9, y: 7),
        'Earth': (x: 6, y: 6),
        'Air': (x: 9, y: 6),
      };
      final sources = <(RiteBody, Offset)>[];
      final drawn = <(DungeonCreature, Offset)>[];
      for (final c in List.of(creatures)) {
        if (rites.allies.contains(c) || identical(c, h.blood)) continue;
        sources.add((_heartRead(c), c.position));
        drawn.add((c, c.position));
        h.hidden.add(c);
      }
      final b = h.blood;
      final targets = <(RiteBody, Offset)>[];
      final arriving = <(DungeonCreature, Offset)>[];
      if (b != null) {
        final at = riteCentreOf(spots['Blood']!.x, spots['Blood']!.y);
        b
          ..position = at
          ..lastSafe = at;
        _heartAddBody(b, companion: h.bloodCompanion);
        h.hidden.add(b);
        targets.add((_heartRead(b), at));
        arriving.add((b, at));
        sources.add((_heartRead(b), niche));
      }
      for (final ally in rites.allies) {
        final sq = spots[ally.member.element];
        if (sq == null) continue;
        final at = riteCentreOf(sq.x, sq.y);
        ally
          ..position = at
          ..lastSafe = at;
        _heartAddBody(ally);
        h.hidden.add(ally);
        targets.add((_heartRead(ally), at));
        arriving.add((ally, at));
      }
      h.bound = false;
      h.morphs.add(
        HeartMorph(
          RiteMorphFx(
            sources: sources,
            targets: targets,
            flight: 1.2,
            spread: .5,
            bow: .25,
          ),
          sources: drawn,
          targets: arriving,
          onDone: () {
            for (final (c, _) in drawn) {
              _heartRemoveBody(c);
            }
            h.hidden.clear();
            final blood = h.blood;
            if (blood != null) _heartActivate(blood);
            h.blood = null;
            h.state = _heartClearedState();
            h.bodies.clear();
          },
        ),
      );
    }
    if (t >= 5.6 && h.morphs.isEmpty) {
      h
        ..finaleT = -1
        ..freed = true
        ..taken = false;
      _discoverCloud(kRiteHeartFreedId);
      if (!hasStar(1)) earnStar(1);
      // The allies came down with Blood: the arena won't add them again.
      rites.alliesDown = true;
      onChanged();
    }
  }

  // ── RESET ROOM ───────────────────────────────────────────

  /// Start the Heart again: whatever was made comes apart, the four stand
  /// where they began, and everything in the way is back. Blood stays
  /// bound. False while something is still moving.
  bool _heartReset() {
    final h = _heart;
    if (_heartBusy || !h.taken || h.freed) return false;
    for (final c in List.of(creatures)) {
      if (!rites.allies.contains(c)) _heartRemoveBody(c);
    }
    h
      ..state = heartStart(h.room)
      ..pending.clear()
      ..broke.clear()
      ..powers.clear()
      ..hidden.clear()
      ..bodies.clear()
      ..dwellKey = null
      ..actedKey = null;
    for (final (el, at) in h.room.starts) {
      final ally = rites.allies
          .where((c) => c.member.element == el)
          .firstOrNull;
      if (ally == null) continue;
      final pos = riteCentreOf(at.x, at.y);
      ally
        ..position = pos
        ..lastSafe = pos;
      _heartAddBody(ally);
      h.bodies[el] = ally;
    }
    final first = h.bodies['Fire'];
    if (first != null) _heartActivate(first);
    return true;
  }

  // ── Every frame ──────────────────────────────────────────

  void _heartTick(DungeonCreature a, double dt) {
    final h = _heart;
    for (final m in List.of(h.morphs)) {
      m.fx.update(dt);
      if (m.fx.done) {
        h.morphs.remove(m);
        m.onDone?.call();
      }
    }
    for (final e in List.of(h.words.entries)) {
      e.value.t += dt;
      if (e.value.done) h.words.remove(e.key);
    }
    if (h.captureT >= 0) _heartCaptureTick(dt);
    if (h.finaleT >= 0) _heartFinaleTick(dt);
    _heartPowersTick(dt);
    final b = active;
    if (b != null) _heartDwellTick(b, dt);
    // Blood free: Sanguorath wakes below.
    if (h.freed &&
        guardianRiteUnlocked &&
        (conduitEnergy['A'] ?? 0) <= 0 &&
        !hasStar(2)) {
      conduitEnergy['A'] = double.infinity;
      conduitEnergy['B'] = double.infinity;
    }
  }

  // ── Tapping what hangs there ─────────────────────────────

  Future<void> _heartReadWord(String el) async {
    final h = _heart;
    if (h.wordGrains.containsKey(el) || !h.wordReading.add(el)) return;
    try {
      h.wordGrains[el] = await heartWordOf(el);
    } finally {
      h.wordReading.remove(el);
    }
  }

  /// A tap at [world]: on an element hanging there (or on Blood, bound),
  /// its name comes out of it in grains and drifts away. True if it hit.
  bool _heartTap(Offset world) {
    final h = _heart;
    final r = h.room;
    (String, Offset, String)? hit;
    for (var y = 0; y < r.h && hit == null; y++) {
      for (var x = 0; x < r.w; x++) {
        final k = '$x,$y';
        final el =
            h.pending[k] ??
            (h.state.cells[y][x] == kHeartHanging ? h.state.holds[k] : null);
        if (el == null) continue;
        final c = riteCentreOf(x, y) + Offset(0, sin(_time * .9 + x * 1.7 + y * .6) * 3);
        if ((world - c).distance <= kHeartOrbRadius + 16) {
          hit = (el, c, k);
          break;
        }
      }
    }
    final niche = riteCentreOf(r.blood.x, r.blood.y);
    if (hit == null && (h.bound || !h.freed) && (world - niche).distance <= 36) {
      hit = ('Blood', niche, 'blood');
    }
    if (hit == null) return false;
    final (el, c, key) = hit;
    _heartShowWord(el, c, key);
    return true;
  }

  void _heartShowWord(String el, Offset c, String key) {
    final h = _heart;
    final w = h.wordGrains[el];
    if (w == null) {
      // Not read yet: read it, and show it the moment it is.
      unawaited(_heartReadWord(el).then((_) {
        if (h.wordGrains.containsKey(el)) _heartShowWord(el, c, key);
      }));
      return;
    }
    h.words[key] = HeartWordFx(
      w,
      c,
      c + const Offset(0, kHeartOrbRadius + 26),
      essenceRamp(EssenceElement.of(el)),
    );
    _cue(SoundCue.dungeonInteract);
    _haptic(DungeonHaptic.success);
  }

  // ── The camera ───────────────────────────────────────────

  /// CUT TO THE ELEMENTS (the author: "we should be zoomed in more and cut
  /// scene to the elements"). The stage is played close, held at the foot of
  /// the view with as much of the open space above it as fits (it never
  /// rises and falls with a step). When something happens up there the
  /// camera goes to it: close on a fusion as it forms, then up the column
  /// with its element, holding on what it reaches, and back down with
  /// whatever comes out; up with Blood as it is taken and bound, and up and
  /// down again when Blood is made and freed. Eased, never a jump.
  void _heartCamera(DungeonCreature a, double dt) {
    final h = _heart;
    final niche = riteCentreOf(h.room.blood.x, h.room.blood.y);
    // A cut frames about four squares of the open space.
    final cutZoom = hasLayout
        ? min(1.0, max(_riteWholeZoom(currentRoom), size.y / (kRiteCell * 4.5)))
        : 1.0;
    // The stage at the foot of the view, at [zoom].
    Offset stage(double x, double zoom) {
      final vh = hasLayout ? size.y / zoom : 400.0;
      return Offset(x, _kHeartStageFront + 8 - vh / 2);
    }

    var zoom = 1.0;
    var focus = stage(a.position.dx, 1);
    Offset up(Offset from, Offset to, double k) {
      zoom = cutZoom;
      return Offset.lerp(from, to, _riteEase(k))!;
    }

    final mid = h.room.w * kRiteCell / 2;
    if (h.captureT >= 0) {
      // Blood comes apart on the stage, rises to its binding, is bound; the
      // camera comes back down for the four.
      final t = h.captureT;
      if (t >= .8 && t < 3.7) {
        focus = up(stage(niche.dx, cutZoom), niche, (t - 1.05) / 1.5);
      } else if (t >= 3.7) {
        focus = stage(mid, 1);
      }
    } else if (h.finaleT >= 0) {
      final t = h.finaleT;
      final made = h.finaleMade?.position;
      if (t < 1.9) {
        if (made != null) focus = stage(made.dx, 1);
      } else if (t < 5.4) {
        final from =
            made ?? riteCentreOf(kRiteHeartFreedAt.x, kRiteHeartFreedAt.y);
        focus = up(stage(from.dx, cutZoom), niche, (t - 2.1) / 1.3);
      } else {
        focus = stage(
          riteCentreOf(kRiteHeartFreedAt.x, kRiteHeartFreedAt.y).dx,
          1,
        );
      }
    } else if (h.powers.isNotEmpty) {
      final p = h.powers.last;
      final front = riteCentreOf(p.altar.front.x, p.altar.front.y);
      final d = Offset(
        kRiteDx[p.altar.dir].toDouble(),
        kRiteDy[p.altar.dir].toDouble(),
      );
      if (p.t < kHeartPowerAt + HeartRiseFx.release) {
        // Close on the fusion as it forms, and on the creature as it comes
        // apart into its element.
        focus = stage(front.dx, 1);
      } else if (p.t < p.returnAt) {
        // Up the column with the element, to what it reaches, and held
        // there while it washes over it.
        final k = ((p.t - kHeartPowerAt - HeartRiseFx.release) / p.travel).clamp(0.0, 1.0);
        zoom = cutZoom;
        focus = front + d * p.reach * (1 - (1 - k) * (1 - k));
      } else {
        // Down again with it (and with whatever came out of what it broke).
        focus = stage(front.dx, 1);
      }
    }
    final k = 1 - exp(-dt / .4);
    h.camAt = h.camAt == null ? focus : Offset.lerp(h.camAt, focus, k);
    h.camZoom += (zoom - h.camZoom) * k;
  }

  /// The doors of the Heart: the stair up and the floor down exist once
  /// Blood is free.
  bool _heartDoorHidden(DungeonDoor door) => !_heart.freed;

  // ── Test seams ───────────────────────────────────────────

  /// The Heart's rules state.
  @visibleForTesting
  HeartState get debugHeartState => _heart.state;

  /// Load the species templates (onLoad does it on the way in).
  @visibleForTesting
  Future<void> debugHeartPrepare() => _heartPrepareAll();
}
