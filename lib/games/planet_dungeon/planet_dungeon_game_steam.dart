// lib/games/planet_dungeon/planet_dungeon_game_steam.dart
//
// VAPORIS — the Boiler Ring. The Steam planet's puzzle logic + rendering,
// as a part of planet_dungeon_game.dart.
//
// World rule: *the ring main holds only so much pressure, and every mouth you
// shut sends its head somewhere else.*
//   • The main starts at 40; each clamped junction costs 15 to open, and Fire
//     stokes a firebox for 20 more at the price of wisps.
//   • Entry — a Steam creature cracks the relief vent and the seal hisses open.
//   • Star 0 (Causeway) — the geyser field: cap every mouth (bodies, Earth's
//     one stone, the choked one) and the heart takes the whole head.
//   • Star 1 (Cinder Forge) — the launch: hold the field so the riser throws
//     two across the chasm, where Earth and Fire cast the moat to its foot.
//   • Rite (Crucible) — four corners, each shut by its own hand; every shut
//     corner adds head to the next throw, and the centre exists only once all
//     four are shut. Stand on it → Boilrog.
//   • Vault — vent ≥60 of the main into the burst-disc at once.
//   • Maxim (Hidden Harmony) — the scald cellar, down the split pipe at full
//     blast.

part of 'planet_dungeon_game.dart';

/// Steam's lost maxim discovery id (screen pays 20 gold on first find).
const String kSteamHiddenHarmonyEggId = 'egg:steam_hidden_harmony';

// ── Ring-main pressure economy ──
/// The boiler's head at the start of every run: enough for TWO junctions,
/// not four — choose your way around the ring.
const int kSteamStartPressure = 40;

/// The main never holds more than this.
const int kSteamPressureMax = 99;

/// Pressure gained per Fire stoke of a firebox (the roar draws wisps).
const int kSteamStokeGain = 20;

/// Reach for throwing a junction release / stoking / venting the disc.
const double _kPressureReach = 78.0;

// ── Star 1 · geyser-field knobs (device-tunable) ──
const double _kGeyserPeriod = 6.0;
const double _kGeyserBlast = 2.4;
const double _kGeyserReach = 44.0;
const double _kBlastReach = 96.0;

/// A riser's throw: this far, plus this much again for every mouth shut.

/// Seconds a thrown body spends in the air.
const double _kFlightSeconds = 0.75;

/// What one plugged mouth puts back into the main.
const int kSteamCapHead = 40;

/// What one mouth STILL ROARING takes out of it. Deliberately more than a plug
/// puts back: a boiler at its rated maximum with one mouth left open reads 94,
/// so no amount of stoking can stand in for a plug. Without this the main
/// could simply buy its way past a mouth you never covered — which is exactly
/// what it was doing, and why the chasm could be cleared under the redline.
const int kSteamVentBleed = 45;

/// A throw made on an overpressured main clears the chasm; one made under the
/// redline is a lob that falls into it. The surplus above 99 adds a little
/// distance on top, so a fuller main visibly throws you further in.
const double _kThrowClear = 210.0;
const double _kThrowLob = 150.0;
const double _kThrowPerOver = 1.2;

/// How close a body must stand to a channel lip to work it.
const double _kCastReach = 62.0;

/// How close a body must stand to a corner's seal to work it.
const double _kSealReach = 74.0;

/// The crucible's own throw: its corners are further apart than the forge's
/// chasm is wide, so it clears more at the redline and gains more per unit of
/// surplus. (Tuning the FORGE's numbers to suit this room would have moved a
/// chasm that already plays.)
const double _kCrucibleClear = 340.0;
const double _kCrucibleLob = 190.0;

/// …and it gains MORE per unit of surplus than the forge does, because the
/// surplus is the only thing that can carry a body across the room once the
/// near corners are sealed. A body standing on an already-sealed vent adds
/// nothing — that is what deadlocked the first tuning of this room, and it is
/// why the crossing has to be bought with head rather than with hands.
const double _kCruciblePerOver = 1.8;

/// How close you have to stand to a lost maxim to take it.
const double _kMaximReach = 60.0;

/// And how long the room lets you stand there afterwards before the pipe
/// takes you home. Measured from the moment the rite settles, so it is three
/// seconds of having the thing, not three seconds of watching the reaction.
const double _kMaximExitSeconds = 3.0;

/// How far one press of flame runs the melt down the moat, how much of the
/// boulder it spends doing it, and how fast an unfed front skins over.
const double _kMoatPerPour = 0.25;
const double _kBoulderPerPour = 0.34;
const double _kMoatCoolPerSecond = 0.055;
const double _kMoatGraceSeconds = 1.2;
const int _kBodyHoldLimit = 3;
const double _kRockRaiseSeconds = 0.55;
const double _kRockReach = 46.0;
const double _kRockPlaceAhead = 52.0;
const double _kRockRadius = 24.0;

extension BoilerRing on PlanetDungeonGame {
  // ── Lifecycle ────────────────────────────────────────────

  void _resetPressureState() {
    if (!_isVapor) return;
    moltenRiteDone = false;
    _moltenPulse = 0;
    boilerPressure = kSteamStartPressure;
    unclampedSeals.clear();
    burstDiscBlown = false;
    cappedGeysers.clear();
    geyserCycle = 0;
    _geyserBlastAt = -1;
    earthRock = null;
    earthRockRaise = 0;
    burstCapstoneRooms.clear();
    sealedCorners.clear();
    shortThrows = 0;
    maximExitTimer = 0;
    moatFill = 0;
    boulderCharge = 0;
    _moatIdle = 0;
    castingGreeted = false;
    geyserFlights.clear();
  }

  // ── STAR 1 · THE GEYSER FIELD ────────────────────────────
  //
  // Every mouth in the room breathes on ONE cycle: a long build, then a short
  // blast. Capping a mouth (a body on the stone, the rock, or authored
  // rubble) takes it out of the system and its head goes to whatever is still
  // open — so the field grows angrier the closer you get, and the last mouths
  // blow hard enough to throw a body clear. Only the rock can hold one then.

  /// Seconds of the shared geyser cycle: [_kGeyserBlast] of it is the blast.

  /// Standing this close to a mouth caps it (and is where a blast throws you
  /// from, if it is not capped).

  /// A blast at pressure p throws anything within this of the mouth.

  /// The pressure (capped count) at which a blast is strong enough to throw a
  /// BODY off the mouth it is holding. The rock never cares.

  bool get _geyserBlasting =>
      (geyserCycle % _kGeyserPeriod) >= (_kGeyserPeriod - _kGeyserBlast);

  /// 0..1 through the current cycle — the render's build-up, and the fair
  /// warning before every blast.
  double get geyserCharge =>
      ((geyserCycle % _kGeyserPeriod) / (_kGeyserPeriod - _kGeyserBlast)).clamp(
        0.0,
        1.0,
      );

  /// How many mouths are shut right now — the system's pressure.
  int get geyserPressure => cappedGeysers.length;

  /// THE LAUNCH HEAD, and it is the boiler's own gauge. A plugged mouth stops
  /// venting and its head goes back into the main, so smothering the field
  /// RAISES THE PRESSURE — which means the ring you have been managing all
  /// run is the thing that throws you, and the riser is the one place on the
  /// planet where the main is asked to go past its rated maximum.
  ///
  /// Over 99 is an overpressure. Under it the throw is a lob into the chasm.
  /// The bleed is what makes both plugs NECESSARY rather than merely helpful.
  int get launchHead {
    final room = currentRoom;
    final held = cappedFieldMouths;
    // THE BLEED IS FOR A SMALL FIELD. It exists so a fat boiler cannot buy its
    // way past a mouth left open in the Cinder Forge, where there are two of
    // them. The crucible has EIGHT, and charging 45 for each still-open one
    // put the head at −150 on arrival: nothing could ever fly. There the
    // pressure comes from what is HELD, and the redline does the same job —
    // two vents held or nobody moves.
    if (room.crucibleSeals.isNotEmpty) {
      return boilerPressure + kSteamCapHead * held;
    }
    final field = room.geysers.where((g) => !g.isRiser).length;
    return boilerPressure +
        kSteamCapHead * held -
        kSteamVentBleed * (field - held);
  }

  /// Mouths in this field still roaring — each one bleeding the main.
  int get openFieldMouths =>
      currentRoom.geysers.where((g) => !g.isRiser).length - cappedFieldMouths;

  /// Mouths held that are not risers (a riser cannot be smothered).
  int get cappedFieldMouths {
    final room = currentRoom;
    var n = 0;
    for (final id in cappedGeysers) {
      final g = room.geysers.where((m) => m.id == id);
      if (g.isNotEmpty && !g.first.isRiser) n++;
    }
    return n;
  }

  /// Is the main redlining — the only state in which a riser clears the gap?
  bool get launchOverpressured => launchHead > kSteamPressureMax;

  /// Bodies in the air. While a creature is flying its position belongs to
  /// the arc and nothing else — walking input, shoves and caps all wait.
  void _updateGeyserFlights(double dt) {
    if (geyserFlights.isEmpty) return;
    final done = <int>[];
    for (final e in geyserFlights.entries) {
      final f = e.value;
      f.t = min(1.0, f.t + dt / _kFlightSeconds);
      final cr = e.key < creatures.length ? creatures[e.key] : null;
      if (cr == null) {
        done.add(e.key);
        continue;
      }
      final ease = Curves.easeInOutSine.transform(f.t);
      final along = Offset.lerp(f.from, f.to, ease)!;
      cr.position = along - Offset(0, sin(pi * f.t) * f.lift);
      if (f.t >= 1.0) {
        cr.position = f.to;
        done.add(e.key);
        // A THROW THAT FALLS SHORT is the room's whole way of saying "not
        // enough head" — so it is answered here rather than left to the
        // generic fall recovery, which only ever speaks for the creature you
        // happen to be steering. You watch the arc drop into the chasm and
        // the body scrambles back onto the shore it left.
        if (_blocksPlacement(f.to, currentRoom)) {
          shortThrows++;
          cr.position = cr.lastSafe;
          _setBlockedHint('Not enough pressure. The throw falls short', 3.0);
        }
      }
    }
    for (final k in done) {
      geyserFlights.remove(k);
    }
  }

  /// Is anyone still in the air? (Caps and the win check both wait for the
  /// room to settle, so a body counts where it LANDS, not where it passes.)
  bool get geyserFlightActive => geyserFlights.isNotEmpty;

  /// Every mouth a body, the rock or the rubble is holding, recomputed from
  /// the world each frame (§ state is never an intention).
  void _recomputeCaps(DungeonRoom room) {
    cappedGeysers.clear();
    // A SEALED CORNER holds its own vents, with nobody standing on them. That
    // is the whole engine of the crucible: finishing a corner permanently
    // raises the room's head, so the next throw goes further than the last.
    final sealedVents = <String>{
      for (final seal in room.crucibleSeals)
        if (sealedCorners.contains(seal.id)) ...seal.vents,
    };
    for (final gy in room.geysers) {
      if (sealedVents.contains(gy.id) || gy.blockedAtStart) {
        cappedGeysers.add(gy.id);
        continue;
      }
      final rock = earthRock;
      if (rock != null &&
          earthRockRaise >= 1 &&
          (rock - gy.position).distance <= _kGeyserReach) {
        cappedGeysers.add(gy.id);
        continue;
      }
      // A RISER's throat is too wide for one body to smother: standing on it
      // does not shut it, it puts you in the plume. Only the stone caps one.
      if (gy.isRiser) continue;
      for (final cr in creatures) {
        if (!cr.alive) continue;
        if ((cr.position - gy.position).distance <= _kGeyserReach) {
          cappedGeysers.add(gy.id);
          break;
        }
      }
    }
  }

  void _updateGeyserField(DungeonCreature a, DungeonRoom room, double dt) {
    if (room.geysers.isEmpty) return;
    final star = room.capstone?.starIndex;
    if (star != null && hasStar(star)) return; // solved: the field sleeps

    if (earthRockRaise < 1 && earthRock != null) {
      earthRockRaise = min(1.0, earthRockRaise + dt / _kRockRaiseSeconds);
    }
    _updateCastingMoat(room, dt);
    // Standing on the plinth performs the rite — you only get there by having
    // shut all four, so the rite cannot be walked past the way it once could.
    final plinth = room.centrePlinth;
    if (plinth != null &&
        !moltenRiteDone &&
        sealedCorners.length >= room.crucibleSeals.length &&
        creatures.any((c) => c.alive && plinth.contains(c.position))) {
      moltenRiteDone = true;
      // The wake itself is SPOKEN by `_maybeWakeBoilrog` on the next tick
      // (layout.riteWakeLine) — a plain line from update is dropped unasked.
      onChanged();
    }
    if (geyserFlightActive) return; // let the arc finish before anything reads
    final wasBlasting = _geyserBlasting;
    geyserCycle += dt;
    _recomputeCaps(room);

    // THE BURST: every mouth shut, and the head has one place left to go.
    final cap = room.capstone;
    if (cap != null &&
        !capstoneBurst &&
        cappedGeysers.length >= room.geysers.length) {
      capstoneBurst = true;
      _setHint(
        'Every mouth is shut, the heart takes the whole head and the '
        'slab splits',
        4.0,
      );
      _spawnAlchemyBurst(
        cap.position,
        producedElement: 'Steam',
        reagentElements: const ['Earth'],
        unstable: true,
        particleCount: 34,
        intensity: 1.4,
      );
      if (!hasStar(cap.starIndex)) earnStar(cap.starIndex);
      onChanged();
      return;
    }

    // THE BLAST, on the edge where it opens: everything still open throws.
    if (!wasBlasting && _geyserBlasting) {
      _geyserBlastAt = _moltenPulse;
      _geyserBlastLen = double.infinity;
      _eruptGeysers(room);
    } else if (wasBlasting && !_geyserBlasting) {
      _geyserBlastLen = (_moltenPulse - _geyserBlastAt) % 1000.0;
    }

    // STAR 2 — THE CASTING. It used to bank when the WHOLE PARTY stood on the
    // far shore, which cannot happen any more: the field needs a body holding
    // it or nobody gets across at all. The pour is the win now (see
    // `_tryCasting`); all this does is keep a line for whoever comes down
    // over there, once, because a party arriving mid-air on an unfamiliar
    // shore should be able to ask what the shore is for.
    final far = room.platforms.isEmpty ? null : room.platforms.last;
    if (!castingGreeted &&
        far != null &&
        room.castingMoat != null &&
        creatures.any((c) => c.alive && far.inflate(2).contains(c.position))) {
      castingGreeted = true;
      // Arriving on the far shore is an arrival, so like every arrival it
      // holds its line for HINT (see `_arriveIn`) and lights the button.
      _holdLine(
        'The casting moat. Earth raises rock onto the lip and Fire melts it '
        'down the channel. The melt cools back if nobody feeds it',
        roomId: currentRoomId,
      );
    }
  }

  /// Seconds the raised rock takes to heave up out of the floor.

  /// Where a riser's throw actually puts a body: the FIRST ground along the
  /// aim, or the end of the arc if it crosses none.
  ///
  /// It used to land at EXACTLY `reach`, which made too much head as fatal as
  /// too little. With all four corners of the crucible sealed every mouth is
  /// capped, the head is 340 and the arc carries 774 — so it sailed five
  /// hundred pixels past a plinth two hundred and seventy away, and the last
  /// hop of the room could not be made at all. Reported from play as *"how do
  /// I get to the middle square?"*, which was a fair question with no answer.
  ///
  /// Landing on first ground keeps every rung of the ladder intact: not
  /// enough head still means the arc ends in the dark, because there is no
  /// ground on the way. What it removes is a failure mode that could not be
  /// seen, reasoned about, or fixed by playing better.
  ///
  /// It asks `_blocksPlacement`, not `_onSolidGround` — the crucible's centre
  /// is a PLATFORM in the layout but is not there until four corners are
  /// sealed, and only the block rule knows that. Ground you cannot stand on
  /// is not ground to land on.
  Offset _throwLanding(
    Offset from,
    Offset aim,
    double reach,
    DungeonRoom room,
  ) {
    var left = false;
    for (var d = 10.0; d <= reach; d += 8.0) {
      final pt = from + aim * d;
      final landable = room.bounds.contains(pt) && !_blocksPlacement(pt, room);
      if (!landable) {
        left = true;
        continue;
      }
      // Not the lip you launched from — you have to have crossed something.
      if (left) return pt;
    }
    return from + aim * reach;
  }

  void _eruptGeysers(DungeonRoom room) {
    final p = geyserPressure;
    var threw = false;
    for (final gy in room.geysers) {
      if (cappedGeysers.contains(gy.id)) continue;
      // A RISER throws whoever is riding it, as far as the shut field allows:
      // every body you send across is one fewer cap behind it, so the throws
      // get weaker the closer the room is to solved. That decay IS the puzzle.
      if (gy.isRiser) {
        for (final cr in creatures) {
          if (!cr.alive) continue;
          if ((cr.position - gy.position).distance > _kGeyserReach) continue;
          final over = launchHead - kSteamPressureMax;
          final corners = room.crucibleSeals.isNotEmpty;
          final reach = over > 0
              ? (corners ? _kCrucibleClear : _kThrowClear) +
                    over * (corners ? _kCruciblePerOver : _kThrowPerOver)
              : (corners ? _kCrucibleLob : _kThrowLob);
          final aim = Offset(cos(cr.aimAngle), sin(cr.aimAngle));
          // THE THROW LEAVES THE MOUTH, not the body. You may ride from
          // anywhere within `_kGeyserReach` (44) of the throat, and measuring
          // from the creature handed you up to 44px of free distance — more
          // than the 25px margin that separates "a full head clears the
          // chasm" from "half a head falls in". Standing on the far lip of
          // the ring made a half-held field enough, which is not a choice the
          // room ever meant to offer.
          final to = _clampToBounds(
            _throwLanding(gy.position, aim, reach, room),
            room,
          );
          // ARC, don't teleport. The landing is identical; what changes is
          // that a short throw can now be WATCHED falling short, which is the
          // room's only way of saying "not enough head" without a line of
          // text. (`_updateGeyserFlights` owns the position until it lands.)
          final i = creatures.indexOf(cr);
          if (i >= 0) geyserFlights[i] = GeyserFlight(gy.position, to);
          cr.lastSafe = _onSolidGround(to, room) ? to : cr.lastSafe;
          _spawnAlchemyBurst(
            gy.position,
            producedElement: 'Steam',
            particleCount: 18,
            intensity: 0.9,
          );
          _setHint(
            'The riser throws ${cr.member.displayName} across the dark',
            2.4,
          );
          threw = true;
        }
        continue;
      }
      for (final cr in creatures) {
        if (!cr.alive) continue;
        final d = (cr.position - gy.position).distance;
        if (d > _kBlastReach) continue;
        // A body ON the mouth is capping it, so it never erupts under anyone;
        // this is for everyone caught standing in the plume's skirt.
        final away = d < 1
            ? const Offset(0, -1)
            : (cr.position - gy.position) / d;
        final shove = 78.0 + 26.0 * p;
        final to = _clampToBounds(cr.position + away * shove, room);
        if (_canPlaceBody(to, cr.position, room)) {
          cr
            ..position = to
            ..lastSafe = to;
        }
        // The field's rule, not a guardian's attack: defence does not trim
        // a throw (see `_guardianAttackMitigation`).
        cr.hp = max(0, cr.hp - (6.0 + 3.0 * p) * progressDmgMul);
        threw = true;
      }
      // At full head a plume will even walk the rock off its stone — but only
      // a mouth that is ROARING, which a capped one never is.
      final rock = earthRock;
      if (rock != null && p >= _kBodyHoldLimit) {
        final d = (rock - gy.position).distance;
        if (d <= _kBlastReach && d > 1) {
          final away = (rock - gy.position) / d;
          earthRock = _clampToBounds(rock + away * 40, room);
        }
      }
    }
    if (threw) {
      _setHint('The field blows, it throws you off the stone', 2.4);
      onChanged();
    }
  }

  /// EARTH's verb on this planet: heave one rock out of the floor, and
  /// heave it back down. Only ever ONE — pressing again on your own rock
  /// destroys it, which is what makes WHERE you spend it the question.
  /// Is this creature standing at something the ring-main answers for — a
  /// clamped junction, a stoke port, or the burst disc?
  bool _nearPressureFixture(DungeonCreature a, DungeonRoom room) {
    // A corner's seal is a fixture too — without this the stone verb swallows
    // every non-Earth press in the crucible (it is a geyser room), so Steam
    // and Fire could never shut their own corners. Third time this exact
    // refusal has eaten a legal action; the rule stands: a refusal must never
    // outrank a thing that would actually work.
    for (final seal in room.crucibleSeals) {
      if ((a.position - seal.position).distance <= _kSealReach) return true;
    }
    final moat = room.castingMoat;
    if (moat != null && (a.position - moat.boulderAt).distance <= _kCastReach) {
      return true;
    }
    final port = room.stokePort;
    if (port != null && (a.position - port).distance <= _kPressureReach) {
      return true;
    }
    final disc = room.burstDisc;
    if (disc != null &&
        (a.position - disc.position).distance <= _kPressureReach) {
      return true;
    }
    for (final door in room.doors) {
      if (_sealFor(room, door) == null) continue;
      if (!_sealBlocked(room, door)) continue;
      if ((a.position - door.rect.center).distance <= _kPressureReach) {
        return true;
      }
    }
    return false;
  }

  bool _tryEarthRock(DungeonCreature a) {
    if (!_isVapor) return false;
    final room = currentRoom;
    if (room.geysers.isEmpty) return false;
    // At a corner's seal, Earth's press belongs to `_trySeal`. (The
    // non-Earth branch above already stands back for these; EARTH's own
    // branch did not, so Earth walked up to a corner it was meant to cap and
    // raised a field stone instead. Fourth time this verb has eaten another
    // one's press.)
    for (final seal in room.crucibleSeals) {
      if ((a.position - seal.position).distance <= _kSealReach) return false;
    }
    // At the moat's lip, Earth's stone is a BOULDER for the casting — that
    // press belongs to `_tryCasting`, not to the field.
    final moat = room.castingMoat;
    if (moat != null && (a.position - moat.boulderAt).distance <= _kCastReach) {
      return false;
    }
    if (_probing) {
      if (a.member.element != 'Earth' && _nearPressureFixture(a, room)) {
        return false;
      }
      final rock = earthRock;
      final atRock =
          a.member.element == 'Earth' &&
          rock != null &&
          (a.position - rock).distance <= _kRockReach;
      return _probeHit(atRock ? 'SINK' : 'RAISE');
    }
    if (a.member.element != 'Earth') {
      // A REFUSAL MUST NEVER OUTRANK A THING THAT WOULD ACTUALLY WORK. Earth's
      // stone answers before the ring-main's fixtures on purpose, but this
      // branch claimed EVERY non-Earth press anywhere in a geyser room — and
      // both geyser rooms have pressure-sealed doors. So a Steam creature
      // standing on a clamped junction inside the Cinder Forge got "only Earth
      // raises stone from this floor" and the junction was never thrown: a
      // refusal that was both wrong and about something the player had not
      // asked for. Stand back and let the fixture answer.
      if (_nearPressureFixture(a, room)) return false;
      _setBlockedHint('Only Earth can raise stone here');
      return true;
    }
    final rock = earthRock;
    if (rock != null && (a.position - rock).distance <= _kRockReach) {
      earthRock = null;
      earthRockRaise = 0;
      _setHint('The stone sinks back into the floor');
      onChanged();
      return true;
    }
    if (rock != null) {
      _setBlockedHint(
        'Your stone is already up. Break it first to raise another',
      );
      return true;
    }
    final at =
        a.position +
        Offset(cos(a.aimAngle), sin(a.aimAngle)) * _kRockPlaceAhead;
    final placed = _clampToBounds(at, room);
    if (!_canPlaceBody(placed, a.position, room)) {
      _setBlockedHint('Can\'t raise a stone there');
      return true;
    }
    earthRock = placed;
    earthRockRaise = 0;
    _setHint('Earth heaves a stone up out of the floor');
    _spawnAlchemyBurst(
      placed,
      producedElement: 'Earth',
      particleCount: 16,
      intensity: 0.8,
    );
    onChanged();
    return true;
  }

  /// Walking into the stone shoves it — the only way to move it, so the rock
  /// travels at a walking pace and every metre of it is a decision.
  void _pushEarthRock(DungeonCreature a, DungeonRoom room, Offset before) {
    final rock = earthRock;
    if (rock == null || earthRockRaise < 1) return;
    final d = (a.position - rock).distance;
    if (d >= _kRockRadius + PlanetDungeonGame._radius) return;
    final step = a.position - before;
    if (step.distanceSquared < 0.000001) {
      a.position = before; // standing against it: the stone does not budge
      return;
    }
    final dir = step / step.distance;
    final to = _clampToBounds(rock + dir * step.distance * 1.6, room);
    if (_canPlaceBody(to, rock, room)) {
      earthRock = to;
    } else {
      a.position = before; // the stone is against something solid
    }
  }

  // ── Ring-main junction seals ─────────────────────────────

  String _sealKey(String a, String b) =>
      (a.compareTo(b) < 0) ? '$a|$b' : '$b|$a';

  /// The authored seal on [room] guarding the door to [door.targetRoomId].
  PressureSeal? _sealFor(DungeonRoom room, DungeonDoor door) {
    for (final s in room.pressureSeals) {
      if (s.targetRoomId == door.targetRoomId) return s;
    }
    return null;
  }

  /// True while a junction door's clamp is still down (unpaid this run).
  /// THE RITE HAS TO GATE SOMETHING, and it was gating nothing at all.
  ///
  /// The crucible's onward door drops into the furnace heart, and it was
  /// simply open: melt the middle gate — the DRY one, the door — walk down the
  /// fall and out the bottom, and Boilrog was in front of you with the mould
  /// never touched. Reported from play, and the whole of Star 3 was optional.
  ///
  /// The way to the heart is the cast. Fill the mould and it opens.
  /// What a shut Steam rite-door says. It used to be one fixed line about an
  /// empty mould, on a planet that no longer has a mould and now has three
  /// different reasons a way on can be closed.
  String _vaporRiteDoorHint(DungeonRoom room, DungeonDoor door) {
    if (door.targetRoomId == 'scald_cellar') {
      // Names the key, not the prize: you should be told exactly what the
      // pipe wants and left to wonder why you would ever give it that.
      return 'The main reads $boilerPressure. This pipe only takes you at '
          'full pressure';
    }
    if (room.centrePlinth != null && room.crucibleSeals.isNotEmpty) {
      final left = room.crucibleSeals.length - sealedCorners.length;
      return left == 1
          ? 'One corner is still open. The centre won\'t form until it\'s shut'
          : '$left corners are still open. There\'s no centre to cross to yet';
    }
    return 'The centre isn\'t there yet';
  }

  bool _vaporRiteDoorShut(DungeonRoom room, DungeonDoor door) {
    // THE SPLIT PIPE. Not a door — a hole in the main, and a hole only
    // carries a body when the main is screaming. The whole budget, spent on
    // something that is not a junction: that is the maxim's question.
    if (door.targetRoomId == 'scald_cellar') {
      return boilerPressure < kSteamPressureMax;
    }
    // The corner room's way on stands ON the centre plinth, which does not
    // exist until all four are sealed — so it is unreachable rather than
    // locked. Saying so out loud matters anyway: anything that asks "is this
    // door open" (the on-foot sweep included) should get the truth.
    if (room.centrePlinth != null && room.crucibleSeals.isNotEmpty) {
      if (door.targetRoomId != room.doors.last.targetRoomId) return false;
      return sealedCorners.length < room.crucibleSeals.length && !hasStar(2);
    }
    return false;
  }

  bool _sealBlocked(DungeonRoom room, DungeonDoor door) {
    final seal = _sealFor(room, door);
    if (seal == null) return false;
    return !unclampedSeals.contains(_sealKey(room.id, seal.targetRoomId));
  }

  /// One BLOCKED clause naming what's missing (§5.6) — how to RAISE the
  /// main (condensate, the firebox) is the manifold's earned reading
  /// (_steamReveal), never a door refusal.
  String _sealDoorHint(DungeonRoom room, DungeonDoor door) {
    final seal = _sealFor(room, door)!;
    if (boilerPressure >= seal.cost) {
      return 'Clamped. The release beside it costs ${seal.cost} pressure';
    }
    return 'The clamp needs ${seal.cost} pressure, and the main has only '
        '$boilerPressure';
  }

  /// Whether the current room is a molten puzzle that can be restarted.
  /// Dispatched from the core `canRestartRoom` (Fire's garth has one too).
  bool get _canRestartVaporRoom =>
      _isVapor && (layout.rooms[currentRoomId]?.geysers.isNotEmpty ?? false);

  /// Wipe the current geyser room back to its authored state and return the
  /// party to the chamber entrance — the puzzle's clean-slate button. Earned
  /// stars are untouched (a cleared room has nothing to reset).
  void _restartVaporRoom() {
    if (!_canRestartVaporRoom) return;
    // A geyser room resets the same way: the stone sinks, the field re-lays,
    // and the party comes back to the door — which is what keeps a party
    // stranded on the wrong shore from ever being a dead run.
    earthRock = null;
    earthRockRaise = 0;
    cappedGeysers.clear();
    geyserCycle = 0;
    _geyserBlastAt = -1;
    final spawn = _roomEntrySpawn(currentRoomId);
    for (final c in creatures) {
      c
        ..position = spawn
        ..lastSafe = spawn;
    }
    _fallRecovering = false;
    _setHint('The field resets, and the stone sinks back into the floor');
    onChanged();
  }

  /// The spawn a neighbour's door drops you onto when entering [roomId] (always
  /// authored open ground); the dungeon entrance as a last resort.
  Offset _roomEntrySpawn(String roomId) {
    for (final r in layout.rooms.values) {
      for (final d in r.doors) {
        if (d.targetRoomId == roomId) return d.targetSpawn;
      }
    }
    return layout.entranceSpawn;
  }

  // ── Per-frame update ─────────────────────────────────────

  void _updatePressure(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isVapor) return;
    // A BODY THAT HAS LEFT THE ROOM IS NOT STILL IN THE AIR. Flights used to
    // tick only from the geyser update, so a throw taken in the Cinder Forge
    // stayed live all the way to the crucible: `geyserFlightActive` never
    // cleared, the cap recompute never ran, and the crucible was still
    // counting the FORGE's mouths. A stale flight could also seize a
    // creature's position in a room it was never thrown in.
    _maybeTakeMaxim(room, a, dt);
    if (_vaporPrevRoomId != room.id) {
      _vaporPrevRoomId = room.id;
      geyserFlights.clear();
      cappedGeysers.clear();
      _geyserBlastAt = -1; // a plume does not follow you through a door
    }
    _moltenPulse = (_moltenPulse + dt) % 1000.0;
    // …and they tick for EVERY Steam room, so one can never hang mid-arc
    // because the party walked somewhere with no geysers in it.
    _updateGeyserFlights(dt);
    // The guardian wakes once the rite is done, even from the heart.
    _maybeWakeBoilrog(room);
  }

  void _maybeWakeBoilrog(DungeonRoom room) {
    // The rite is performed in the CRUCIBLE, but Boilrog sleeps in the heart
    // next door — and waking him only from inside his own room sealed that
    // room forever: `_guardianDoorSealed` holds the door shut until he is
    // awake, and he could not wake until someone was already through it. So
    // the antechamber wakes him too, which is what the rite's own hint has
    // always claimed happens ("Boilrog heaves up BEYOND it").
    var guardian = room.guardian;
    if (guardian == null && room.doors.isNotEmpty) {
      guardian = layout.rooms[room.doors.last.targetRoomId]?.guardian;
    }
    if (guardian == null || guardianAwake || hasStar(guardian.starIndex)) {
      return;
    }
    if (!moltenRiteDone) return;
    guardianAwake = true;
    guardianHp = PlanetDungeonGame.maxGuardianHp;
    // SPOKEN: this runs from update, where a plain line is dropped unasked,
    // and a guardian waking is a consequence the player must hear (§5.7).
    speakConsequence(
      layout.riteWakeLine ??
          'All four corners are shut. Boilrog is awake in the Furnace Heart',
    );
    spawnWispWave(
      element: 'Steam',
      center: guardian.position,
      count: 3,
      unstable: true,
      announce: false,
    );
  }

  /// The Hidden Harmony — Steam's lost maxim, and it is a PLACE.
  ///
  /// It used to be a run-long CONDITION: zero scalds, later zero short
  /// throws. Both were achievements rather than puzzles (§7's table grades
  /// most of the seventeen that way), and the short-throw version was worse
  /// than that — the Cinder Forge teaches by letting you watch a throw fall
  /// in, so the move the room invites silently spoiled the maxim twenty
  /// minutes before you could claim it, with nothing on screen saying so.
  ///
  /// What it asks now is the only thing this planet has to spend. The main
  /// holds forty and every junction costs fifteen; the maxim is at the end of
  /// a spur no junction uses, down a split in the pipe that will only carry a
  /// body at FULL BLAST. Spending the whole budget on something that is not a
  /// door is the question, and stoking to 99 draws wisps each time, so it is
  /// a real price and not a walk.
  void _maybeTakeMaxim(DungeonRoom room, DungeonCreature a, double dt) {
    final cache = room.maximCache;
    if (cache == null) return;
    if (discoveredClouds.contains(kSteamHiddenHarmonyEggId)) {
      // AND THE PIPE TAKES YOU BACK. The way out is the mouth you were blown
      // in through, which is a hole in a wall and not a door — the one thing
      // it cannot do is announce itself, and a player who has just been paid
      // should not then have to hunt for the exit. So the cellar returns you
      // itself, a beat after the rite settles.
      if (room.doors.isEmpty) return;
      final was = maximExitTimer;
      maximExitTimer += dt;
      if (was < _kMaximExitSeconds * 0.35 &&
          maximExitTimer >= _kMaximExitSeconds * 0.35) {
        _setHint('The split draws its breath back, and you with it', 2.6);
      }
      if (maximExitTimer >= _kMaximExitSeconds) {
        maximExitTimer = 0;
        passThroughDoor(room.doors.first);
      }
      return;
    }
    if ((a.position - cache).distance > _kMaximReach) return;
    _setHint('The foundry forgot this room. You did not.', 4.0);
    beginMaximRite(kSteamHiddenHarmonyEggId, cache);
    _spawnAlchemyBurst(
      cache,
      producedElement: 'Steam',
      unstable: true,
      particleCount: 36,
      intensity: 1.2,
    );
  }

  // ── Action button ────────────────────────────────────────

  /// Shut a corner. Each wants its own hand; the last wants two, which is why
  /// it is the one across the room.
  bool _trySeal(DungeonCreature a) {
    final room = currentRoom;
    if (room.crucibleSeals.isEmpty) return false;
    for (final seal in room.crucibleSeals) {
      if ((a.position - seal.position).distance > _kSealReach) continue;
      if (_probing) {
        return _probeHit(sealedCorners.contains(seal.id) ? null : 'SHUT');
      }
      if (sealedCorners.contains(seal.id)) {
        _setHint('This corner is shut, its vents hold themselves now');
        return true;
      }
      final needs = <String>[
        seal.element,
        if (seal.second != null) seal.second!,
      ];
      if (!needs.contains(a.member.element)) {
        _setBlockedHint(
          needs.length > 1
              ? 'This corner needs both ${needs.first} and ${needs.last}'
              : 'Only ${seal.element} can shut this corner',
        );
        return true;
      }
      // A two-handed corner needs the other pair of hands ON the corner.
      if (needs.length > 1) {
        final other = needs.firstWhere((e) => e != a.member.element);
        final present = creatures.any(
          (c) =>
              c.alive &&
              c.member.element == other &&
              (c.position - seal.position).distance <= _kSealReach,
        );
        if (!present) {
          _setBlockedHint('It needs $other here too. Bring them across');
          return true;
        }
      }
      sealedCorners.add(seal.id);
      _cue(SoundCue.elementSteam);
      _recomputeCaps(room);
      final left = room.crucibleSeals.length - sealedCorners.length;
      _setHint(
        left == 0
            ? 'The last corner shuts, every vent holds, and the plinth stands '
                  'up out of the dark'
            : 'The corner shuts, and its vents hold themselves, $left to go',
        3.6,
      );
      _spawnAlchemyBurst(
        seal.position,
        producedElement: a.member.element,
        particleCount: 20,
        intensity: 1.0,
      );
      onChanged();
      return true;
    }
    return false;
  }

  /// THE CASTING, on the Cinder Forge's far shore. Earth heaves a rock onto
  /// the lip at the head of the moat; Fire melts it and the melt runs down.
  /// Every press pushes the front a little further; left alone it skins over
  /// and creeps back. Reach the foot and the pedestal yields.
  bool _tryCasting(DungeonCreature a) {
    final moat = currentRoom.castingMoat;
    if (moat == null) return false;
    if ((a.position - moat.boulderAt).distance > _kCastReach) return false;
    final cap = currentRoom.capstone;
    if (_probing) {
      if (cap != null && hasStar(cap.starIndex)) return _probeHit(null);
      return _probeHit(a.member.element == 'Earth' ? 'RAISE' : 'MELT');
    }
    if (cap != null && hasStar(cap.starIndex)) {
      _setHint('The cast is made, the moat lies cold and full');
      return true;
    }

    if (a.member.element == 'Earth') {
      if (boulderCharge > 0.05) {
        _setBlockedHint('There\'s still rock on the lip to melt');
        return true;
      }
      boulderCharge = 1.0;
      _setHint('Earth heaves a fresh boulder onto the lip');
      _spawnAlchemyBurst(
        moat.boulderAt,
        producedElement: 'Earth',
        particleCount: 14,
        intensity: 0.7,
      );
      onChanged();
      return true;
    }

    if (a.member.element != 'Fire') {
      _setBlockedHint('Only Fire can melt this rock');
      return true;
    }
    if (boulderCharge <= 0.05) {
      _setBlockedHint('The lip is bare. Raise rock here first, then melt it');
      return true;
    }
    boulderCharge = max(0.0, boulderCharge - _kBoulderPerPour);
    moatFill = min(1.0, moatFill + _kMoatPerPour);
    _moatIdle = 0;
    _spawnAlchemyBurst(
      moat.boulderAt,
      producedElement: 'Lava',
      reagentElements: const ['Earth', 'Fire'],
      unstable: true,
      particleCount: 18,
      intensity: 1.0,
    );
    if (moatFill >= 1.0 && cap != null && !hasStar(cap.starIndex)) {
      _setHint(
        'The melt reaches the foot of the moat, the pedestal yields',
        4.0,
      );
      earnStar(cap.starIndex);
    } else {
      _setHint(
        boulderCharge <= 0.05
            ? 'The rock is spent, the run wants feeding again'
            : 'The melt runs on down the channel',
      );
    }
    onChanged();
    return true;
  }

  /// The front of a run of lava skins over the moment nobody is feeding it,
  /// so an unattended moat creeps back up the hill. This is the clock the far
  /// shore runs on, and the reason the pair over there cannot dawdle.
  void _updateCastingMoat(DungeonRoom room, double dt) {
    if (room.castingMoat == null) return;
    final cap = room.capstone;
    if (cap != null && hasStar(cap.starIndex)) return;
    _moatIdle += dt;
    if (_moatIdle < _kMoatGraceSeconds || moatFill <= 0) return;
    moatFill = max(0.0, moatFill - _kMoatCoolPerSecond * dt);
  }

  bool _tryPressure(DungeonCreature a) {
    if (!_isVapor) return false;
    final room = currentRoom;
    if (_trySeal(a)) return true;
    if (_tryCasting(a)) return true;

    // Entry rite: a Steam creature cracks the gate vent → the seal hisses open.
    final vent = room.steamVent;
    if (vent != null &&
        room.id == layout.entranceRoomId &&
        !entryDoorRevealed) {
      if ((a.position - vent).distance <= 64) {
        if (_probing) return _probeHit('OPEN');
        if (a.member.element != 'Steam') {
          _setBlockedHint('Only Steam can open this vent');
          return true;
        }
        entryDoorRevealed = true;
        _discoverCloud(PlanetDungeonGame.entryDoorDiscoveryId);
        _setHint('Steam bleeds the clamp, the pressure door hisses open');
        _spawnAlchemyBurst(
          room.doors.isNotEmpty ? room.doors.first.rect.center : vent,
          producedElement: 'Steam',
          unstable: true,
          particleCount: 28,
          intensity: 1.1,
        );
        return true;
      }
    }

    // Junction release: any hands can throw it — the MAIN pays, not the
    // creature. Standing near a clamped junction door spends its cost.
    for (final door in room.doors) {
      final seal = _sealFor(room, door);
      if (seal == null || !_sealBlocked(room, door)) continue;
      if ((a.position - door.rect.center).distance > _kPressureReach) continue;
      if (_probing) return _probeHit('OPEN');
      if (boilerPressure < seal.cost) {
        _setBlockedHint(
          'This junction costs ${seal.cost} pressure. The main has only '
          '$boilerPressure',
        );
        return true;
      }
      boilerPressure -= seal.cost;
      unclampedSeals.add(_sealKey(room.id, seal.targetRoomId));
      // The gauge carries the number (§5.6 — state is not speech).
      _setHint('The main surges into the clamp, the junction hisses open');
      _spawnAlchemyBurst(
        door.rect.center,
        producedElement: 'Steam',
        particleCount: 20,
        intensity: 1.0,
      );
      return true;
    }

    // Stoke firebox: Fire feeds the main (+20) — and the roar draws wisps.
    final port = room.stokePort;
    if (port != null && (a.position - port).distance <= _kPressureReach) {
      if (_probing) return _probeHit('STOKE');
      if (a.member.element != 'Fire') {
        _setBlockedHint('Only Fire can stoke the firebox');
        return true;
      }
      if (boilerPressure >= kSteamPressureMax) {
        _setBlockedHint('The main is full ($kSteamPressureMax)');
        return true;
      }
      boilerPressure = min(kSteamPressureMax, boilerPressure + kSteamStokeGain);
      _setHint(
        'Fire roars in the box, the main surges, and something '
        'stirs at the noise',
      );
      spawnWispWave(
        element: 'Steam',
        center: port,
        count: 2,
        unstable: true,
        announce: false,
      );
      _spawnAlchemyBurst(
        port,
        producedElement: 'Fire',
        particleCount: 18,
        intensity: 1.0,
      );
      return true;
    }

    // Vent the main into the burst-disc: ALL pressure, one surge. At or
    // above the threshold the disc blows and the vault shaft stands open;
    // below it, the valve refuses — the sacrifice must be whole.
    final disc = room.burstDisc;
    if (disc != null &&
        !burstDiscBlown &&
        (a.position - disc.position).distance <= _kPressureReach) {
      if (_probing) return _probeHit('VENT');
      if (boilerPressure < disc.threshold) {
        _setBlockedHint(
          'The burst-disc needs ${disc.threshold} pressure at once. The main '
          'has only $boilerPressure',
        );
        return true;
      }
      boilerPressure = 0;
      burstDiscBlown = true;
      _setHint(
        'You vent the whole main in one surge, the burst-disc '
        'BLOWS, and the vault shaft stands open',
        4.5,
      );
      _spawnAlchemyBurst(
        disc.position,
        producedElement: 'Steam',
        unstable: true,
        particleCount: 40,
        intensity: 1.4,
      );
      return true;
    }
    return false;
  }

  // ── Insight (Mask) ───────────────────────────────────────

  /// The crucible's reading. All of it is answerable standing still.
  void _crucibleReveal(DungeonCreature a, DungeonRoom room) {
    final tier = revealHintTier(a.member.statIntelligence);
    final left = room.crucibleSeals.length - sealedCorners.length;
    final want = room.crucibleSeals
        .where((s) => !sealedCorners.contains(s.id))
        .map((s) => s.second == null ? s.element : '${s.element}+${s.second}')
        .join(', ');
    // The throw is the main plus 40 per vent held (a shut corner holds both
    // of its own), and it has to pass the gauge's 99. Say how far off it is.
    final head = launchHead;
    final more = head > kSteamPressureMax
        ? 0
        : (kSteamPressureMax - head) ~/ kSteamCapHead + 1;
    final need = more == 0
        ? 'That is enough to throw'
        : 'Hold $more more vent${more == 1 ? '' : 's'} to throw';
    _setHint(
      tier >= 2
          ? 'A shut corner stays shut, so each one makes the next throw '
                'stronger. Nothing reaches the far side until two are shut. '
                'Leave the corner that needs two elements until last'
          : tier >= 1
          ? 'Each vent held adds $kSteamCapHead to the main, and a shut corner '
                'holds both its vents. A throw needs more than '
                '$kSteamPressureMax. It reads $head now. $need. Whoever lands '
                'must hold a vent so the others can follow '
                '($left corner${left == 1 ? '' : 's'} still open: $want)'
          : 'Four open corners. The centre plinth appears once all four are '
                'shut',
      5.5,
    );
  }

  /// The far shore of the Cinder Forge: the casting moat's own reading.
  void _castingReveal(DungeonCreature a, DungeonRoom room) {
    final tier = revealHintTier(a.member.statIntelligence);
    final pct = (moatFill * 100).round();
    _setHint(
      tier >= 2
          ? 'One rock is worth three melts, and the moat needs four. Keep '
                'Fire melting and have Earth raise fresh rock the moment the '
                'lip is bare'
          : tier >= 1
          ? 'Earth raises rock onto the lip. Fire melts it and the melt runs '
                'down the channel. Left alone, it cools back up the channel '
                '($pct% full)'
          : 'Fill the moat with melt down to the pedestal at its foot',
      5.0,
    );
  }

  /// The field's own reading, tiered: what the room IS, then the rule that
  /// governs it, then the shape of the answer — never the answer itself.
  void _steamGeyserReveal(DungeonCreature a, DungeonRoom room) {
    final tier = revealHintTier(a.member.statIntelligence);
    final riser = room.geysers.where((g) => g.isRiser).length;
    final shut = cappedGeysers.length;
    final total = room.geysers.where((g) => !g.isRiser).length;

    if (riser == 0) {
      // The Causeway: shut everything, and the field fights you for it.
      // Blasts shove harder per cap, a body ON a mouth is never thrown (it
      // caps it), and from three caps (the rubble counts) a roaring mouth
      // walks the stone 40px away — see `_eruptGeysers`.
      _setHint(
        tier >= 2
            ? 'Each mouth you cover makes the open ones blow harder. Once '
                  'three are covered, counting the rubble, a blast knocks the '
                  'stone away from any open mouth it\'s near. Push the stone '
                  'onto its mouth before you cover the others'
            : tier >= 1
            ? 'Standing on a mouth covers it, and so does a stone. Cover them '
                  'all to send the pressure to the heart ($shut of $total '
                  'held)'
            : 'The vents erupt on a beat, and one mouth is already blocked '
                  'with rubble',
        5.0,
      );
      return;
    }

    // The far shore has its own puzzle, and it is not the field.
    final moat = room.castingMoat;
    final far = room.platforms.isEmpty ? null : room.platforms.last;
    final cap = room.capstone;
    if (moat != null &&
        far != null &&
        !(cap != null && hasStar(cap.starIndex)) &&
        far.inflate(2).contains(a.position)) {
      _castingReveal(a, room);
      return;
    }

    // The Forge: one mouth cannot be covered, and that is the way across.
    final head = launchHead;
    _setHint(
      tier >= 2
          ? 'Every mouth covered AND the head over $kSteamPressureMax. The '
                'stone holds one mouth and a creature the other, so two ride '
                'across. The far moat needs Earth and Fire, so Steam is the '
                'one to leave behind'
          : tier >= 1
          ? 'A covered mouth feeds pressure into the main. An open one drains '
                'it faster than a plug feeds. Cover every mouth AND get the '
                'head above $kSteamPressureMax (it reads $head)'
          : 'Two mouths can be covered and one can\'t. The far shore is past '
                'the one that can\'t',
      5.0,
    );
  }

  // Every Vaporis room is grid-less now (the molten tile grids retired with
  // the geyser rework), so the readings key off each room's furniture. The
  // old molten-grid branches — dam walls, cisterns, condensate — described
  // rooms that no longer exist and were removed with this rewrite.
  void _steamReveal(DungeonCreature a, DungeonRoom room) {
    // THE GEYSER ROOMS FIRST. Both of them carry pressure seals on their
    // doors, so they used to fall straight through to the ring-economy
    // reading below — a paragraph about junction costs and burst discs,
    // asked for while standing in front of a field of geysers. The hint
    // never once spoke about the puzzle the player was looking at.
    if (room.crucibleSeals.isNotEmpty) {
      _crucibleReveal(a, room);
      return;
    }
    if (room.geysers.isNotEmpty) {
      _steamGeyserReveal(a, room);
      return;
    }
    // The Boiler Gate: the entry rite's vent.
    if (room.steamVent != null &&
        room.id == layout.entranceRoomId &&
        !entryDoorRevealed) {
      _setHint('The relief vent is clamped shut. Only Steam can open it');
      return;
    }
    // The manifolds: insight reads the ring's ECONOMY.
    if (room.pressureSeals.isNotEmpty || room.burstDisc != null) {
      _setHint(
        'The main starts at $kSteamStartPressure and each junction costs '
        '15. Fire stoking a firebox adds $kSteamStokeGain, up to '
        '$kSteamPressureMax, and the noise draws wisps. The burst-disc takes '
        'the whole main and needs at least 60 in it',
        5.5,
      );
      return;
    }
    _setHint(_nothingHiddenLine());
  }

  // ── Collision ────────────────────────────────────────────

  /// Test seam for the Steam collision rules (the cast span in particular).
  @visibleForTesting
  bool steamBlocksAtForTest(Offset center) =>
      _steamBlocksAt(center, currentRoom);

  bool _steamBlocksAt(Offset center, DungeonRoom room) {
    // THE CAST SPAN is a platform that does not exist yet. It is listed with
    // the shores so the walk will accept it, and held shut here until the
    // star is banked — at which point the melt has set and the span is the
    // way home. (Blocking it rather than adding a platform at runtime keeps
    // the room's geometry authored in one place.)
    // THE CENTRE IS NOT THERE YET. It is listed with the corners so the walk
    // will accept it, and held shut until every corner is sealed — gated by
    // EXISTING rather than by distance, because it sits between the corners
    // and is always the shortest throw of the room.
    final plinth = room.centrePlinth;
    if (plinth != null &&
        plinth.inflate(2).contains(center) &&
        sealedCorners.length < room.crucibleSeals.length &&
        !hasStar(2)) {
      // Solved is solved: once the guardian is down the plinth stays, so the
      // room never re-locks behind a finished run.
      return true;
    }
    final span = room.castSpan;
    if (span != null && span.inflate(2).contains(center)) {
      final cap = room.capstone;
      if (cap == null || !hasStar(cap.starIndex)) return true;
    }
    return false;
  }

  // ── Hints ────────────────────────────────────────────────

  void _steamAmbientHint(DungeonCreature a, DungeonRoom room) {
    final vent = room.steamVent;
    if (vent != null &&
        !entryDoorRevealed &&
        (a.position - vent).distance < 70) {
      _setAmbientHint('A clamped relief vent hisses at its rivets');
      return;
    }
    for (final door in room.doors) {
      final seal = _sealFor(room, door);
      if (seal != null &&
          _sealBlocked(room, door) &&
          (a.position - door.rect.center).distance < _kPressureReach) {
        _setAmbientHint('A clamped ring junction, wound tight');
        return;
      }
    }
    final port = room.stokePort;
    if (port != null && (a.position - port).distance < _kPressureReach) {
      _setAmbientHint('A firebox. Cold iron, breathing old soot');
      return;
    }
    final disc = room.burstDisc;
    if (disc != null &&
        !burstDiscBlown &&
        (a.position - disc.position).distance < _kPressureReach) {
      // The etching is diegetic — the yield condition is the manifold's
      // earned reading (_steamReveal), not proximity copy.
      _setAmbientHint('A riveted burst-disc, etched "${disc.threshold}"');
      return;
    }
  }

  String? _steamObjectiveHint(DungeonRoom room) {
    // WHAT, never HOW (§5.6). The lines key off the room id.
    if (room.guardian != null) {
      return 'Furnace Heart. Face Boilrog: strike in its lulls';
    }
    return switch (room.id) {
      'boiler_gate' when !entryDoorRevealed =>
        'Boiler Gate. The pressure door is clamped shut',
      'manifold_south' =>
        'South Manifold. The ring main runs through clamped junctions',
      'manifold_north' => 'North Manifold. The way to the crucible is here',
      'burst_vault' => 'The Burst Vault. Something is stored below',
      'ember_causeway' =>
        'Ember Causeway. Five mouths vent the field, and one is choked',
      'cinder_forge' =>
        'Cinder Forge. The far shore is across a chasm too wide to jump',
      'crucible' => 'The Crucible. Four open corners, and no centre yet',
      _ => null,
    };
  }

  double get _steamMoodTarget {
    switch (currentRoomId) {
      case 'ember_causeway':
      case 'cinder_forge':
        return 0.30;
      case 'crucible':
        return 0.24;
      case 'boiler_heart':
        return guardianAwake ? 0.16 : 0.22;
      case 'boiler_gate':
        return 0.42;
      default:
        return 0.44;
    }
  }

  // ── Rendering ────────────────────────────────────────────

  /// STAR 1/2 — the geyser field, in stone. Every mouth shows three things at
  /// a glance: whether it is HELD, how close the shared cycle is to blowing
  /// (heat climbing in the throat, the mutter thickening), and — for a riser
  /// — the iron collar of a throat too wide to smother. The steam itself is
  /// grains drawn over the party (`_renderSteamOverParty`).
  void _drawGeyserField(Canvas canvas, DungeonRoom room) {
    if (room.geysers.isEmpty) return;
    final solved = room.capstone != null && hasStar(room.capstone!.starIndex);
    final charge = geyserCharge;
    final sealedBy = <String, String>{
      for (final seal in room.crucibleSeals)
        if (sealedCorners.contains(seal.id))
          for (final v in seal.vents) v: seal.second ?? seal.element,
    };

    for (final gy in room.geysers) {
      final r = gy.isRiser ? 34.0 : 24.0;
      _drawVentGeology(canvas, gy, r);
      if (gy.blockedAtStart) {
        _drawRubblePlug(canvas, gy.position, r, _steamSeed(gy.id));
        continue;
      }
      final by = sealedBy[gy.id];
      if (by != null) {
        _drawVentPlug(canvas, gy.position, r, by);
        continue;
      }
      if (solved || cappedGeysers.contains(gy.id)) continue;
      // OPEN: heat deep in the throat, climbing as the head builds under it,
      // and the wet far lip catching it.
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          gy.position - Offset(0, r * 0.15),
          r * (0.55 + 0.45 * charge),
          const Color(0xFFBFF2FF).withValues(alpha: 0.05 + 0.30 * charge),
        );
      }
      canvas.drawArc(
        Rect.fromCircle(center: gy.position, radius: r + 1.5),
        pi + 0.35,
        pi - 0.7,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = const Color(
            0xFFCFEFF6,
          ).withValues(alpha: 0.12 + 0.36 * charge),
      );
    }

    // THE HEART'S LIGHT, once it is open — the column itself is grains.
    final heart = room.capstone;
    if (heart != null &&
        !room.geysers.any((g) => g.isRiser) &&
        (capstoneBurst || solved) &&
        _fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        heart.position - const Offset(0, 20),
        70 + 10 * sin(_moltenPulse * 2.0),
        const Color(0xFFBFF2FF).withValues(alpha: 0.26),
      );
    }

    _drawCastSpan(canvas, room);
    _drawCastingMoat(canvas, room);
    _drawForgeMould(canvas, room);
    _drawCapstoneSlab(canvas, room);

    // THE STONE: Earth's one boulder, heaving up out of the floor.
    final rock = earthRock;
    if (rock != null) {
      _drawSteamStone(
        canvas,
        rock,
        _kRockRadius,
        4231,
        rise: earthRockRaise.clamp(0.0, 1.0),
      );
    }
  }

  void _renderSteamFloor(Canvas canvas, DungeonRoom room) {
    _renderVaporFabric(canvas, room);
    _renderForgeAmbient(canvas, room);
  }

  /// A stable 0..1 value per grid cell — variation without allocating, and
  /// identical every frame so the floor never crawls.
  double _forgeNoise(int x, int y) {
    var h = x * 374761393 + y * 668265263;
    h = (h ^ (h >> 13)) * 1274126177;
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0;
  }

  /// THE FOUNDRY FLOOR. Vaporis was a 104px square lattice under every
  /// chamber — the same fault Lightning had, and for the same reason: a
  /// planet whose whole premise is a PRESSURE RING-MAIN was drawing itself as
  /// graph paper. It is firebrick laid in offset courses now, sooted and
  /// heat-bloomed, with the ring-main's own pipe runs sunk into it under
  /// bolted flanges and a condensate grate cut across the low side.
  void _drawFoundryFloor(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    _paintFirebrick(canvas, b);
    _drawRingMainAndGrate(canvas, b);
  }

  /// Firebrick courses over [b], every other one offset by half a brick —
  /// the boiler house's one floor, rooms and ledges alike.
  void _paintFirebrick(Canvas canvas, Rect b, {double alpha = 0.82}) {
    const bw = 78.0, bh = 34.0;
    final rows = (b.height / bh).ceil();
    final brick = Paint();
    final joint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0x38120C08);

    // 1) Firebrick courses, every other one offset by half a brick.
    for (var r = 0; r < rows; r++) {
      final y = b.top + r * bh;
      final off = (r.isOdd ? bw * 0.5 : 0.0);
      for (var x = b.left - off; x < b.right; x += bw) {
        final c = ((x - b.left) / bw).floor();
        final n = _forgeNoise(c, r);
        final cell = Rect.fromLTWH(x, y, bw, bh).intersect(b);
        if (cell.isEmpty) continue;
        // Fired clay, kilned unevenly — some bricks darker, some scorched
        // ruddy where something hot has stood on them.
        brick.color = Color.lerp(
          const Color(0xFF2A2119),
          n > 0.93 ? const Color(0xFF3E2718) : const Color(0xFF322820),
          n,
        )!.withValues(alpha: alpha);
        canvas.drawRect(cell, brick);
        canvas.drawRect(cell.deflate(0.5), joint);
      }
    }
  }

  /// The ring-main sunk in the floor, and the condensate grate.
  void _drawRingMainAndGrate(Canvas canvas, Rect b) {
    // THE RING-MAIN ITSELF, sunk into the floor: two heavy pipe runs with
    // bolted flanges. This planet's one big idea is that pressure travels
    // between the rooms — so the pipe that carries it is under your feet in
    // every one of them.
    for (final run in [
      Rect.fromLTWH(b.left, b.top + b.height * 0.13, b.width, 26),
      Rect.fromLTWH(b.left, b.top + b.height * 0.885, b.width, 22),
    ]) {
      // The trench it lies in.
      canvas.drawRect(run.inflate(5), Paint()..color = const Color(0x66120D09));
      canvas.drawRect(run, Paint()..color = const Color(0xFF3B3B40));
      // Barrel highlight along the top of the pipe.
      canvas.drawRect(
        Rect.fromLTWH(run.left, run.top + 3, run.width, 4),
        Paint()..color = const Color(0x3AD8E4EA),
      );
      canvas.drawRect(
        Rect.fromLTWH(run.left, run.bottom - 5, run.width, 4),
        Paint()..color = const Color(0x33000000),
      );
      // Flanged joints every 180px, each with its ring of bolts.
      for (var x = b.left + 90; x < b.right; x += 180) {
        final fl = Rect.fromLTWH(x - 7, run.top - 4, 14, run.height + 8);
        canvas.drawRect(fl, Paint()..color = const Color(0xFF4C4C52));
        canvas.drawRect(
          fl,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0x55151013),
        );
        for (final by in [fl.top + 4.0, fl.bottom - 4.0]) {
          canvas.drawCircle(
            Offset(x, by),
            1.8,
            Paint()..color = const Color(0xFF8A8A90),
          );
        }
      }
    }

    // A condensate grate down the low side — where the cooled breath goes.
    final grate = Rect.fromLTWH(b.left + 26, b.bottom - 40, b.width - 52, 12);
    canvas.drawRect(grate, Paint()..color = const Color(0xFF15100C));
    final bar = Paint()
      ..color = const Color(0xFF44464B)
      ..strokeWidth = 3;
    for (var x = grate.left + 5; x < grate.right; x += 13) {
      canvas.drawLine(
        Offset(x, grate.top + 1),
        Offset(x, grate.bottom - 1),
        bar,
      );
    }
  }

  /// Heat in the brick and breath off the grate. The rooms used to be ringed
  /// by a molten seam behind grate bars — the lava planet's furniture, left
  /// over from when this one flooded, and at play zoom an orange dashed
  /// border round every room. The warmth stays, as heat in the walls; the
  /// seam is gone. The grate's steam rises only where nothing else is
  /// steaming: in a geyser room the field carries it.
  void _renderForgeAmbient(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final t = _moltenPulse;
    if (_fx.ready) {
      const inset = 19.0;
      final spots = <Offset>[
        for (final f in const [0.2, 0.5, 0.8]) ...[
          Offset(b.left + b.width * f, b.top + inset),
          Offset(b.left + b.width * f, b.bottom - inset),
        ],
        for (final f in const [0.3, 0.7]) ...[
          Offset(b.left + inset, b.top + b.height * f),
          Offset(b.right - inset, b.top + b.height * f),
        ],
      ];
      for (var i = 0; i < spots.length; i++) {
        final pulse = 0.45 + 0.35 * sin(t * 1.1 + i * 1.3);
        drawGlow(
          canvas,
          _fx.glow!,
          spots[i],
          30,
          const Color(0xFFFF7A33).withValues(alpha: 0.06 + 0.06 * pulse),
        );
      }
    }
    if (room.geysers.isEmpty) _paintForgeWisps(canvas, b, t);
  }

  /// Ring-main fixtures: clamped junction plates over sealed doors, the
  /// stoke firebox, and the riveted burst-disc. Drawn in every steam room.
  void _renderPressureFixtures(Canvas canvas, DungeonRoom room) {
    // Clamp plates on unpaid junction doors.
    for (final door in room.doors) {
      if (!_sealBlocked(room, door)) continue;
      final r = door.rect.inflate(6);
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(4));
      canvas.drawRRect(rr, Paint()..color = const Color(0xFF2B333B));
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF8FA6B0),
      );
      // Cross-bolted bars.
      final bars = Paint()
        ..color = const Color(0xFF5A6A74)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        r.topLeft + const Offset(6, 6),
        r.bottomRight - const Offset(6, 6),
        bars,
      );
      canvas.drawLine(
        r.topRight + const Offset(-6, 6),
        r.bottomLeft + const Offset(6, -6),
        bars,
      );
      // The release wheel beside the door, pulsing while affordable.
      final seal = _sealFor(room, door);
      final wheel =
          door.rect.center +
          (door.rect.width >= door.rect.height
              ? Offset(door.rect.width / 2 + 26, 0)
              : Offset(0, door.rect.height / 2 + 26));
      final afford = seal != null && boilerPressure >= seal.cost;
      final pulse = 0.6 + 0.4 * sin(_moltenPulse * 2.4);
      canvas.drawCircle(
        wheel,
        11,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = afford ? const Color(0xFF8FE0EC) : const Color(0xFF5A6A74),
      );
      for (var k = 0; k < 4; k++) {
        final ang = k * pi / 2 + _moltenPulse * 0.5;
        canvas.drawLine(
          wheel,
          wheel + Offset(cos(ang), sin(ang)) * 11,
          Paint()
            ..strokeWidth = 2
            ..color = afford
                ? const Color(0x998FE0EC)
                : const Color(0x775A6A74),
        );
      }
      _drawGaugeHub(canvas, wheel, lit: afford);
      if (_fx.ready && afford) {
        drawGlow(
          canvas,
          _fx.glow!,
          wheel,
          20,
          const Color(0xFF8FE0EC).withValues(alpha: 0.12 + 0.14 * pulse),
        );
      }
      // THE LINKAGE (2026-08-14, playtest: "it should be clear that turning
      // the wheel opens the door"). A wheel sitting NEXT to a clamp is just
      // scenery; a wheel visibly BOLTED TO one is a control. The rod runs
      // from the hub into the clamp plate, and it lights with the wheel.
      final linkPaint = Paint()
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = afford ? const Color(0xCC8FE0EC) : const Color(0x995A6A74);
      final toPlate = r.center - wheel;
      final len = toPlate.distance;
      if (len > 1) {
        final dir = toPlate / len;
        canvas.drawLine(
          wheel + dir * 11,
          wheel + dir * (len * 0.52),
          linkPaint,
        );
        // A collar where the rod enters the plate — the joint reads as driven.
        canvas.drawCircle(
          wheel + dir * (len * 0.52),
          4,
          Paint()..color = linkPaint.color,
        );
      }
      // THE PRICE, on the object (§5.6: state leaves the capsule). The door
      // refusal names the cost only once you lean on it; the wheel now says
      // it from across the room, so the junction can be PLANNED against the
      // gauge instead of discovered by walking into it.
      if (seal != null) {
        _drawTinyLabel(canvas, wheel + const Offset(0, 16), '${seal.cost}');
      }
    }

    final port = room.stokePort;
    if (port != null) _drawFirebox(canvas, port);
    final disc = room.burstDisc;
    if (disc != null) _drawBurstDisc(canvas, disc.position, disc.threshold);
  }

  /// THE WESTERN SPUR AND THE SPLIT. The main runs off past the last junction
  /// into a dead end no door uses, and at the end of it the pipe is torn.
  ///
  /// The tear has to be legible as a THING, not as scenery, from the moment
  /// you first wander down here with a half-empty main — otherwise the spur
  /// is just a long walk that says nothing. So the jet scales with the gauge:
  /// a whisper at forty, a plume you can hear at eighty, and a column at full
  /// blast. What changes is only how hard it blows, so the answer is legible
  /// before you ever have the pressure to use it.
  void _drawSplitPipe(Canvas canvas, DungeonRoom room) {
    DungeonDoor? split;
    for (final d in room.doors) {
      if (d.targetRoomId == 'scald_cellar') split = d;
    }
    if (split == null) return;
    final c = split.rect.center;
    final full = boilerPressure >= kSteamPressureMax;

    // The spur itself, running east back toward the ring.
    final run = Rect.fromLTRB(
      c.dx - 62,
      c.dy - 17,
      room.bounds.width,
      c.dy + 17,
    );
    canvas.drawRect(run, Paint()..color = const Color(0xFF241F1A));
    canvas.drawRect(
      Rect.fromLTRB(run.left, run.top, run.right, run.top + 6),
      Paint()..color = const Color(0xFF3A332B),
    );
    canvas.drawRect(
      Rect.fromLTRB(run.left, run.bottom - 5, run.right, run.bottom),
      Paint()..color = const Color(0xFF14110E),
    );
    // Flanges every so often, and a CAP at the dead end so the spur reads as
    // finished rather than as a pipe that ran off the edge of the room.
    for (var x = c.dx + 40; x < room.bounds.width; x += 150) {
      canvas.drawRect(
        Rect.fromLTRB(x, run.top - 5, x + 9, run.bottom + 5),
        Paint()..color = const Color(0xFF4A4038),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(run.left - 14, run.top - 9, run.left + 4, run.bottom + 9),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF4A4038),
    );

    // DISUSED FITTINGS. Six hundred pixels of nothing is a bug; six hundred
    // pixels of a spur that was CLOSED is a story, and it is the only thing
    // telling you why no junction runs down here.
    final valve = Offset(c.dx + 210, c.dy);
    canvas.drawCircle(valve, 17, Paint()..color = const Color(0xFF2B241C));
    final spoke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF5A4B3A);
    canvas.drawCircle(valve, 17, spoke);
    for (var k = 0; k < 3; k++) {
      final ang = k * pi / 3 + 0.4;
      canvas.drawLine(
        valve - Offset(cos(ang), sin(ang)) * 15,
        valve + Offset(cos(ang), sin(ang)) * 15,
        spoke,
      );
    }
    // A dead gauge, needle slack at the pin.
    final gauge = Offset(c.dx + 330, c.dy - 34);
    canvas.drawCircle(gauge, 15, Paint()..color = const Color(0xFF191512));
    canvas.drawCircle(
      gauge,
      15,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0xFF4A4038),
    );
    canvas.drawLine(
      gauge,
      gauge + const Offset(-9, 8),
      Paint()
        ..strokeWidth = 2
        ..color = const Color(0xFF7A6A55),
    );

    // THE TEAR — iron lips peeled back off a dark throat.
    final tear = Rect.fromCenter(center: c, width: 46, height: 26);
    canvas.drawRRect(
      RRect.fromRectAndRadius(tear, const Radius.circular(10)),
      Paint()..color = const Color(0xFF07090B),
    );
    final lip = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0xFF6B5B47);
    for (var k = 0; k < 5; k++) {
      final x = tear.left + tear.width * (k / 4);
      final up = k.isEven;
      canvas.drawLine(
        Offset(x, up ? tear.top : tear.bottom),
        Offset(x + 6, (up ? tear.top : tear.bottom) + (up ? -9 : 9)),
        lip,
      );
    }

    // THE JET, AND IT IS COUNTABLE. One mark of steam per mark on the gauge:
    // a wisp at twenty, a column at ninety-nine. That is what makes the spur
    // legible on the FIRST walk down here — you can see the pipe answering
    // the main long before you have the main to open it, and you can read the
    // gauge off the plume without looking at the gauge.
    //
    // It is GRAINS now (steam_art.dart, 2026-10-08): a hard, fast stream at
    // the tear that slows and opens into a plume, taller and thicker with
    // every mark. It was a pale lozenge under sprite puffs — and before that
    // a lozenge with hard circles in it — which read as a pill and smoke.
    final marks = boilerPressure <= 0
        ? 0
        : max(1, (boilerPressure / 20).round());
    if (marks == 0) return;
    final h = 22.0 + 26.0 * marks;

    _paintSplitJet(canvas, c, h, marks);
    if (_fx.ready) {
      if (full) {
        drawGlow(
          canvas,
          _fx.glow!,
          Offset(c.dx, c.dy - h * 0.35),
          h * 0.6,
          const Color(0xFF8FE0EC).withValues(alpha: 0.24),
        );
      }
    }
  }

  /// A LOST MAXIM, lying where nothing sent you.
  void _drawMaximCache(Canvas canvas, DungeonRoom room) {
    final cache = room.maximCache;
    if (cache == null) return;
    final taken = discoveredClouds.contains(kSteamHiddenHarmonyEggId);

    // A ROOM THE FOUNDRY FORGOT. Rendered with the same brick and the same
    // ring-main as every other chamber, the cellar read as just another room
    // — which is the one thing it must not be. Silt drifted into the corners,
    // fallen block, and the light closing in at the edges.
    final b = room.bounds;
    for (var i = 0; i < 9; i++) {
      final x = b.width * ((i * 0.113 + 0.04) % 1.0);
      final top = b.bottom - 26 - 16 * sin(i * 1.7);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x, top, x + 90 + 40 * cos(i * 2.1), b.bottom),
          const Radius.circular(12),
        ),
        Paint()..color = const Color(0xFF1B1610).withValues(alpha: 0.9),
      );
    }
    for (var i = 0; i < 5; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            b.width * (0.16 + 0.17 * i),
            b.height * (0.62 + 0.13 * sin(i * 2.3)),
            34,
            15,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFF241E18),
      );
    }
    canvas.drawRect(
      b,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0x00000000),
            const Color(0xFF06070A).withValues(alpha: 0.72),
          ],
          stops: const [0.42, 1.0],
        ).createShader(b),
    );

    // THE MOUTH YOU CAME IN BY, and it has to be findable. Chromeless means
    // the engine paints no frame on it, which is right — it is a hole, not a
    // door — but it also means that if this renderer says nothing, the way
    // home is invisible. Reported from play, immediately: *"how do I get
    // back?"*
    for (final d in room.doors) {
      if (!d.chromeless) continue;
      final m = d.rect.center;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          d.rect.inflate(7),
          Radius.circular(d.rect.shortestSide * 0.5),
        ),
        Paint()..color = const Color(0xFF3A332B),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          d.rect.deflate(1),
          Radius.circular(d.rect.shortestSide * 0.45),
        ),
        Paint()..color = const Color(0xFF05070A),
      );
      // Rivets round the collar, so it reads as pipe and not as a cave.
      for (var k = 0; k < 8; k++) {
        final ang = k * pi / 4;
        canvas.drawCircle(
          m + Offset(cos(ang), sin(ang)) * (d.rect.shortestSide * 0.5 + 4),
          2.0,
          Paint()..color = const Color(0xFF6B5B47),
        );
      }
      // And it BREATHES — the only moving thing in a dead room, which is what
      // makes the eye find it from the far end. A slow breath of grains
      // (steam_art.dart); it was four sprite puffs.
      _paintCellarBreath(canvas, m);
    }

    // A low plinth of the same dressed block the foundry is built of.
    final base = Rect.fromCenter(
      center: cache + const Offset(0, 22),
      width: 96,
      height: 30,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(base, const Radius.circular(6)),
      Paint()..color = const Color(0xFF2A2620),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(base.left, base.top, base.right, base.top + 7),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFF443C31),
    );
    // Taken, the sigil is an inlay of steam glass in the plinth, for good —
    // and it sinks there on the rite's own beat (planet_dungeon_game_steam_art).
    _drawHarmonyInlay(canvas, cache);
    if (taken || _harmonySet > 0) return;

    // The maxim itself: a turning sigil over the stone.
    final a = _moltenPulse * 0.5;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFE0A24A).withValues(alpha: 0.85);
    canvas.drawCircle(cache, 26, ring);
    for (var k = 0; k < 3; k++) {
      final ang = a + k * 2 * pi / 3;
      canvas.drawLine(
        cache + Offset(cos(ang), sin(ang)) * 26,
        cache + Offset(cos(ang + 2 * pi / 3), sin(ang + 2 * pi / 3)) * 26,
        ring,
      );
    }
    canvas.drawCircle(
      cache,
      7 + 1.5 * sin(_moltenPulse * 2.4),
      Paint()..color = const Color(0xFFFFD79A),
    );
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        cache,
        46,
        const Color(0xFFE0A24A).withValues(alpha: 0.30),
      );
    }
  }

  /// The shape of a run of melt in a channel.
  ///
  /// A rounded rectangle is a progress bar. Molten rock crawling down a stone
  /// gutter is not: it wets one wall more than the other, and it leads with a
  /// TONGUE. So both edges wobble on a slow travelling phase and the front
  /// bulges past the fill line — which is also the honest read, because the
  /// front is the part the player is actually watching.
  Path _moltenRunPath(Rect run, double phase, {double tongue = 7}) {
    const steps = 16;
    const wob = 2.6;
    final p = Path()..moveTo(run.left + 3, run.top);
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      p.lineTo(
        run.left + 3 + sin(t * 5.4 + phase) * wob,
        run.top + run.height * t,
      );
    }
    p.quadraticBezierTo(
      run.center.dx,
      run.bottom + tongue,
      run.right - 3,
      run.bottom,
    );
    for (var i = steps - 1; i >= 0; i--) {
      final t = i / steps;
      p.lineTo(
        run.right - 3 - sin(t * 5.4 + phase + 1.7) * wob,
        run.top + run.height * t,
      );
    }
    return p..close();
  }

  /// The four corner seals, and the heart that is not there yet.
  ///
  /// A corner is a SOCKET in the rock: a ring of old iron with one arc per
  /// element it wants. Reading the room has to work before any of it is
  /// touched — you should be able to look at a corner from across the void
  /// and know it wants Fire, or Earth AND Fire, without walking over. So the
  /// arcs carry the element's own color, and a two-handed corner is split
  /// down the middle rather than being some blended third color that reads
  /// as a fourth element nobody has.
  void _drawCrucibleSeals(Canvas canvas, DungeonRoom room) {
    if (room.crucibleSeals.isEmpty) return;

    for (final seal in room.crucibleSeals) {
      final shut = sealedCorners.contains(seal.id);
      final c = seal.position;
      const rOuter = 26.0;

      // The socket itself — iron sunk into the terrace, always visible.
      canvas.drawCircle(
        c,
        rOuter + 5,
        Paint()..color = const Color(0xFF15171C).withValues(alpha: 0.85),
      );
      canvas.drawCircle(
        c,
        rOuter + 5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(
            0xFF4A4038,
          ).withValues(alpha: shut ? 0.95 : 0.6),
      );
      // Four bolts, so a sealed cap has something to have been bolted TO.
      for (var k = 0; k < 4; k++) {
        final a = k * pi / 2 + pi / 4;
        canvas.drawCircle(
          c + Offset(cos(a), sin(a)) * (rOuter + 5),
          2.2,
          Paint()..color = const Color(0xFF6B5B47).withValues(alpha: 0.9),
        );
      }

      // One pane of its own glass per element wanted; two split the ring.
      _drawCornerGlass(canvas, c, [
        seal.element,
        if (seal.second != null) seal.second!,
      ], shut);

      if (shut) {
        // A bolted plate, cross-braced. Flat and final — the corner is spent,
        // and nothing about it should still look like it wants something.
        final brace = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = const Color(0xFF8A7355).withValues(alpha: 0.9);
        // A CROSS, not a saltire. The braces first went on at 45° and the
        // sealed corners read as four big red X's — and this planet has
        // already taught, once, that a player asked "why did some x out?"
        // A cross-braced cap is a plug; an X is a refusal.
        for (var k = 0; k < 2; k++) {
          final a = k * pi / 2;
          canvas.drawLine(
            c - Offset(cos(a), sin(a)) * (rOuter - 8),
            c + Offset(cos(a), sin(a)) * (rOuter - 8),
            brace,
          );
        }
        if (_fx.ready) {
          drawGlow(
            canvas,
            _fx.glow!,
            c,
            rOuter + 10,
            const Color(0xFFE0A24A).withValues(alpha: 0.20),
          );
        }
      } else {
        // Open: a slow sweep round the socket, so an untouched corner reads
        // as WAITING rather than as decoration.
        final a = _moltenPulse * 1.1 + c.dx * 0.01;
        canvas.drawCircle(
          c + Offset(cos(a), sin(a)) * (rOuter - 7),
          3.0,
          Paint()..color = elementColor(seal.element).withValues(alpha: 0.75),
        );
        canvas.drawCircle(
          c,
          rOuter - 7,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0xFF6E6558).withValues(alpha: 0.35),
        );
      }
    }

    // THE HEART. It is real ground only once all four are shut, so before
    // that it is drawn as a thing being ASSEMBLED — one quarter of its rim
    // for each corner already held — rather than as floor you could walk on
    // and are mysteriously blocked from. The block is honest; the art has to
    // be too.
    final plinth = room.centrePlinth;
    if (plinth == null) return;
    final shutCount = sealedCorners.length;
    final total = room.crucibleSeals.length;
    if (shutCount < total) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(plinth, const Radius.circular(16)),
        Paint()
          ..color = const Color(
            0xFF06070A,
          ).withValues(alpha: 0.62 - 0.10 * shutCount),
      );
    }
    // Inside the stone, and with real gaps: at 0.52 the ring spilled off the
    // plinth's short side and the four arcs closed into one unbroken ellipse,
    // which is exactly the one thing this ring must never look like.
    final rim = Rect.fromCircle(
      center: plinth.center,
      radius: plinth.shortestSide * 0.40,
    );
    for (var i = 0; i < total; i++) {
      final held = i < shutCount;
      canvas.drawArc(
        rim,
        -pi / 2 + i * (2 * pi / total) + 0.22,
        2 * pi / total - 0.44,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = held ? 4 : 1.6
          ..color = const Color(
            0xFFE0A24A,
          ).withValues(alpha: held ? 0.85 : 0.22),
      );
    }
    if (shutCount >= total && _fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        plinth.center,
        plinth.shortestSide * 0.7,
        const Color(0xFFE0A24A).withValues(alpha: 0.26),
      );
    }
  }

  void _renderSteam(Canvas canvas, DungeonRoom room) {
    _renderGlassDoorPlugs(canvas, room);
    _renderPressureFixtures(canvas, room);
    _drawGeyserField(canvas, room);
    _drawCrucibleSeals(canvas, room);
    _drawSplitPipe(canvas, room);
    _drawMaximCache(canvas, room);
    final vent = room.steamVent;
    if (vent != null) {
      _drawReliefValve(canvas, vent, room.bounds, open: entryDoorRevealed);
    }
    if (room.guardian != null) _drawFurnaceMouths(canvas, room);
  }

  /// The boiler-pressure gauge (always on for Steam).
  /// Test seam: the HUD paints straight to a canvas so the gauge can be
  /// LOOKED AT. It ran off the edge of a phone screen and no test could have
  /// told me — the numbers were all correct.
  @visibleForTesting
  void drawSteamHudForDebug(Canvas canvas, Size vp) =>
      _drawSteamPhaseHud(canvas, vp);

  void _drawSteamPhaseHud(Canvas canvas, Size vp) {
    // ── The main's gauge — the run's one budget, always visible ──
    //
    // Rebuilt after it ran off the edge of a phone: the header was drawn from
    // a fixed left position, so "HEAD 20 · 1 VENTING" simply walked off the
    // screen, and the bleed was painted as a red segment ON TOP of the amber
    // and cyan ones, which read as a single broken bar rather than a boiler,
    // its plugs and its leak. It is right-ALIGNED to the bar now, the venting
    // count has its own line, and the bar shows one number.
    final field = layout.rooms[currentRoomId]?.geysers ?? const [];
    final onField = field.isNotEmpty;
    final head = onField ? launchHead : boilerPressure;
    final over = head > kSteamPressureMax;
    final gaugeBar = Rect.fromLTWH(
      vp.width - 128.0,
      vp.height * 0.5 - 62,
      100,
      7,
    );

    void label(String text, Color color, double dy, double size) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: size,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      // Right-aligned to the bar, so it can never walk off the screen.
      tp.paint(canvas, Offset(gaugeBar.right - tp.width, gaugeBar.top + dy));
    }

    label(
      onField ? 'HEAD $head' : 'MAIN $boilerPressure',
      over ? const Color(0xFFFF9A4A) : const Color(0xFFE4C16A),
      -16,
      11,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(gaugeBar, const Radius.circular(3)),
      Paint()..color = const Color(0x6606141C),
    );
    final headFrac = (head / kSteamPressureMax).clamp(0.0, 1.0).toDouble();
    if (headFrac > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            gaugeBar.left,
            gaugeBar.top,
            gaugeBar.width * headFrac,
            gaugeBar.height,
          ),
          const Radius.circular(3),
        ),
        Paint()
          ..color = over ? const Color(0xFFFF7A33) : const Color(0xD9E4C16A),
      );
    }
    // The rated maximum. Past it the whole bar burns and the number carries
    // the surplus — no nub hanging off the end pretending to be a reading.
    canvas.drawLine(
      Offset(gaugeBar.right, gaugeBar.top - 3),
      Offset(gaugeBar.right, gaugeBar.bottom + 3),
      Paint()
        ..color = const Color(0xFFFF7A33)
        ..strokeWidth = 2,
    );
    if (over && _fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        gaugeBar.centerRight,
        26,
        const Color(0xFFFF7A33).withValues(alpha: 0.45),
      );
    }
    // What is leaking, on its own line, so the header never has to carry it.
    if (onField && openFieldMouths > 0) {
      label(
        '$openFieldMouths VENTING',
        const Color(0xFFE06A55),
        gaugeBar.height + 4,
        9,
      );
    }
    if (!onField) {
      const burstTick = 60 / kSteamPressureMax;
      canvas.drawLine(
        Offset(gaugeBar.left + gaugeBar.width * burstTick, gaugeBar.top - 2),
        Offset(gaugeBar.left + gaugeBar.width * burstTick, gaugeBar.bottom + 2),
        Paint()
          ..color = const Color(0xFF8FE0EC)
          ..strokeWidth = 2,
      );
    }
  }
}
