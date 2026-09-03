// lib/games/planet_dungeon/planet_dungeon_game_poison.dart
//
// THE VENOM MONASTERY — the Poison planet's puzzle logic + rendering, as a
// part of planet_dungeon_game.dart (the same shape Fire, Water, Earth,
// Lightning and Steam use).
//
// World rule (docs/dungeons.md §6.13): *every strain BEHAVES — behavior is
// the diagnosis; and one ward cannot be saved.*
//  • Entry — the quarantine door is waxed shut; a Poison creature softens it.
//  • A ward is SEALED until you break its wax, and breaking it is the only
//    way to watch what lives inside: opening one lets the contagion in
//    (§5.5 topology). The charnel is bricked instead of waxed — a Lava HORN
//    and nothing else (§4 hard gate).
//  • Star 1 (Physician's) — DIAGNOSIS. Read the strain by its habit, pour
//    the draught that answers it at the still, carry it back. A wrong
//    draught FEEDS the strain: permanently virulent, and out into the
//    ambulatory. The first correct cure banks the star.
//  • Star 2 (Triage) — THE SACRIFICE. The house holds three draughts and has
//    four wards. Which three you save IS the decision; the prior's seal then
//    crosses off the fourth, irreversibly.
//  • Star 3 — Blightfang, patient zero, in the crypt under the ward you gave
//    up. It fights WITH the planet's rule (§7 guardian principle): it never
//    opens a lull on a clock — only a correctly diagnosed dose forces one,
//    and it takes a fresh habit after every lull.
//  • Vault — the bottled essence lies in that same crypt: **you may only
//    loot what you sacrificed** (§5.5 vault trick).
//  • Lost Maxim — The Dose: one sick wisp wanders the ambulatory; cure it
//    with a draught instead of a blade (Paracelsus).
//
// The RULES themselves are not in this file: they live in
// planet_dungeon_layout_poison.dart as [WardTriage], with no engine and no
// Flutter in them, so test/venom_monastery_test.dart proves the shipped
// rules rather than a copy of them (the burn_field.dart model).

part of 'planet_dungeon_game.dart';

// ── Tunables (device-tunable knobs, all in one place) ──

/// Seconds of the pulse strain's beat: it swells and shrinks, and only the
/// swollen half of the beat bites — so it is a rhythm you walk in and out of.
const double _kPulseBeat = 2.6;
const double _kPulseMinR = 34.0;
const double _kPulseMaxR = 152.0;
const double _kPulseBiteR = 90.0;

/// Laps per second the wall-creeper's fringe makes of a room's perimeter.
const double _kCreepLapsPerSec = 0.055;

/// How much of the perimeter the fringe covers, and how far in it reaches.
const double _kCreepArc = 0.20;
const double _kCreepDepth = 46.0;

/// Seconds between the leaper's jumps, and its bite radius.
const double _kLeapPeriod = 3.2;
const double _kLeapBiteR = 52.0;

/// The feigner: it lies dead until a body is this close, erupts for this
/// long over this radius, then plays dead again after a cooling beat.
const double _kFeignTrigger = 42.0;
const double _kFeignErupt = 1.1;
const double _kFeignCool = 2.6;
const double _kFeignBiteR = 76.0;

/// Contact damage per second — doubled once a strain has been fed.
const double _kStrainDps = 20.0;
const double _kVirulentDps = 34.0;

/// Reach for every monastery fixture (spout, censer, seal, oubliette).
const double _kMonasteryReach = 62.0;

/// Seconds the plague-cross takes to rot off the ward it barred — the beat
/// that makes the seal a thing you watch happen, not a flag that flips.
const double _kCrossRot = 4.0;

/// Seconds of lull a correct dose buys against patient zero.
const double _kBlightLull = 3.4;

/// Fraction of its pool Blightfang drinks back from a wrong dose (it FEEDS —
/// the planet's own rule, turned on the player).
const double _kBlightFeedHeal = 0.06;

/// Everything the Venom Monastery tracks for one run. Bundled into a single
/// object so the shared engine class carries ONE new field for this planet.
class VenomMonastery {
  /// The pure rules (planet_dungeon_layout_poison.dart). Rolled here rather
  /// than in `_resetPuzzleState` because that only runs on a wipe/restart —
  /// a fresh run's state has to come from the field initialisers, the same
  /// way Steam's starting pressure does.
  WardTriage triage = rollWardTriage();

  /// Shared strain clock — the pulse's beat rides it.
  double clock = 0;

  /// A seal breaking: 1 → 0 over the burst, and where it happened. This is
  /// the one moment on the planet where you have DONE something irreversible
  /// on purpose, so the camera stops and makes you watch it.
  double sealBurst = 0;
  Offset sealBurstAt = Offset.zero;

  /// Whether the burst is a wrong dose (violet) rather than a seal parting
  /// (green). Same animation, and it must not be the same colour: one is
  /// what was always in there, the other is what you just made.
  bool burstIsSick = false;

  /// A ward WAKING: 0 → 1 as its contagion establishes itself, and which one.
  /// Zero means nothing is waking.
  double wake = 0;
  String? wakeWard;

  /// Wards whose waking has already been shown, so it plays once — the first
  /// time you walk in — and never again on a re-entry.
  final Set<String> wakeShown = {};

  /// Which room the monastery last saw the party in, for spotting arrivals.
  String? lastRoomId;

  /// A ward whose sickness is about to come out into the walk, once whatever
  /// is playing now has finished. Chains the condemnation into it.
  String? pendingWalk;

  /// THE INVASION: 0 → 1 as the plague crawls out of a ward door, travels
  /// the cloister and settles into it. Zero means nothing is coming through.
  double invade = 0;
  bool invading = false;
  bool invadeSick = false;
  Offset invadeFrom = Offset.zero;
  Offset invadeTo = Offset.zero;

  /// The first half of it happens in the WARD: which room, where it gathers,
  /// and the doorway it leaves by. You watch it come off the heart and go
  /// out through the door you are standing next to.
  String invadeWardRoom = '';
  Offset invadeWardFrom = Offset.zero;
  Offset invadeWardExit = Offset.zero;

  /// THE CROSS GOING UP: 1 → 0 over the condemnation. The planet's signature
  /// move — the ward you give up — and it had less ceremony than opening a
  /// door did.
  double condemn = 0;
  Offset condemnAt = Offset.zero;

  /// Room+strain key → the wall-creeper's head, as a 0..1 perimeter param.
  final Map<String, double> creepHead = {};

  /// Room+strain key → where the leaper is standing right now.
  final Map<String, Offset> leapMote = {};

  /// Room+strain key → seconds until the leaper jumps again.
  final Map<String, double> leapTimer = {};

  /// Patch key → eruption clock: >0 erupting, <0 cooling, 0 playing dead.
  final Map<String, double> feignFuse = {};

  /// Seconds left on the plague-cross before it rots off the barred ward.
  double crossRot = 0;

  /// The oubliette stone has been dissolved — patient zero is exposed.
  bool oublietteOpen = false;

  /// The sick wisp (the lost maxim), drifting the ambulatory.
  Offset? wisp = const Offset(560, 260);
  WardStrain wispStrain = WardStrain.pulse;
  double wispDrift = 0;

  /// Patient zero's live habit, and the lull a correct dose bought.
  WardStrain? blightStrain;
  double blightLull = 0;
}

extension VenomMonasteryPuzzle on PlanetDungeonGame {
  // ── Lifecycle ────────────────────────────────────────────

  void _resetMonasteryState() {
    if (!_isVenom) return;
    final m = monastery;
    // ROLLED PER RUN, like Earth's scale: the diagnosis is a reading of the
    // world, so a wiki must never be able to name which ward holds what.
    m.triage = rollWardTriage();
    m.clock = 0;
    m.creepHead.clear();
    m.leapMote.clear();
    m.leapTimer.clear();
    m.feignFuse.clear();
    m.crossRot = 0;
    m.oublietteOpen = false;
    m.wisp = const Offset(560, 260);
    m.wispStrain =
        WardStrain.values[Random().nextInt(WardStrain.values.length)];
    m.wispDrift = 0;
    m.blightStrain = null;
    m.blightLull = 0;
  }

  // ── The strains: behaviour is the diagnosis ──────────────

  /// The strains alive in [room] right now, each with whether it has been
  /// fed. A ward carries its own until it is cured; the AMBULATORY carries
  /// everything the player let loose — the surrendered strain, and any strain
  /// a wrong draught fattened.
  List<(WardStrain, bool)> _liveStrains(DungeonRoom room) {
    final t = monastery.triage;
    if (t.isEmpty) return const [];
    final ward = room.ward;
    if (ward != null) {
      if (!t.opened.contains(ward.id) || t.cured.contains(ward.id)) {
        return const [];
      }
      final s = t.strainOf(ward.id);
      if (s == null) return const [];
      return [(s, t.virulent.contains(ward.id))];
    }
    if (room.id != 'ambulatory') return const [];
    return [for (final s in t.loose) (s, true)];
  }

  /// Where a strain is centred in [room].
  Offset _strainHeart(DungeonRoom room) =>
      room.ward?.heart ?? room.bounds.center;

  /// The three places a feigner lies down in [room] — authored as fractions
  /// of the room so one rule serves a ward and the long ambulatory alike.
  List<Offset> _feignPatches(DungeonRoom room) {
    final b = room.bounds;
    return [
      Offset(b.left + b.width * 0.24, b.top + b.height * 0.36),
      Offset(b.left + b.width * 0.56, b.top + b.height * 0.70),
      Offset(b.left + b.width * 0.82, b.top + b.height * 0.30),
    ];
  }

  /// Distance from [p] to the nearest wall of [b].
  double _borderDepth(Offset p, Rect b) => min(
    min(p.dx - b.left, b.right - p.dx),
    min(p.dy - b.top, b.bottom - p.dy),
  );

  /// [p]'s position around [b]'s perimeter, as 0..1 clockwise from top-left.
  double _perimeterU(Offset p, Rect b) {
    final w = b.width, h = b.height;
    final per = 2 * (w + h);
    if (per <= 0) return 0;
    final dTop = p.dy - b.top;
    final dRight = b.right - p.dx;
    final dBottom = b.bottom - p.dy;
    final dLeft = p.dx - b.left;
    final nearest = min(min(dTop, dRight), min(dBottom, dLeft));
    if (nearest == dTop) return ((p.dx - b.left) / per).clamp(0.0, 1.0);
    if (nearest == dRight) return ((w + dTop) / per).clamp(0.0, 1.0);
    if (nearest == dBottom) return ((w + h + dRight) / per).clamp(0.0, 1.0);
    return ((2 * w + h + dBottom) / per).clamp(0.0, 1.0);
  }

  /// The pulse strain's live radius on the shared beat.
  double _pulseRadius() {
    final phase = (monastery.clock % _kPulseBeat) / _kPulseBeat;
    final swell = 0.5 - 0.5 * cos(phase * 2 * pi);
    return _kPulseMinR + (_kPulseMaxR - _kPulseMinR) * swell;
  }

  String _strainKey(String roomId, WardStrain s) => '$roomId#${s.index}';

  /// Advance every live strain in [room] one frame, and bite whoever it can
  /// reach. Only the strains actually in this room tick — nothing simulates
  /// off-screen (the perf toolkit rule: don't pay for what nobody can see).
  void _tickStrains(DungeonCreature a, DungeonRoom room, double dt) {
    final live = _liveStrains(room);
    if (live.isEmpty) return;
    final b = room.bounds;
    final heart = _strainHeart(room);
    for (final (s, virulent) in live) {
      final key = _strainKey(room.id, s);
      var bites = false;
      switch (s) {
        case WardStrain.pulse:
          final r = _pulseRadius() * (virulent ? 1.25 : 1.0);
          bites = r > _kPulseBiteR && (a.position - heart).distance < r;

        case WardStrain.creep:
          final head =
              ((monastery.creepHead[key] ?? 0) +
                  dt * _kCreepLapsPerSec * (virulent ? 1.7 : 1.0)) %
              1.0;
          monastery.creepHead[key] = head;
          if (_borderDepth(a.position, b) < _kCreepDepth) {
            final u = _perimeterU(a.position, b);
            final behind = (head - u + 1.0) % 1.0;
            bites = behind < _kCreepArc;
          }

        case WardStrain.leap:
          var t = (monastery.leapTimer[key] ?? 0) - dt;
          if (t <= 0) {
            // It jumps to whoever is walking — never ON them, always beside.
            final ang = Random().nextDouble() * 2 * pi;
            final reach = 62.0 + Random().nextDouble() * 46.0;
            monastery.leapMote[key] = _clampToBounds(
              a.position + Offset(cos(ang), sin(ang)) * reach,
              room,
            );
            t = _kLeapPeriod * (virulent ? 0.62 : 1.0);
          }
          monastery.leapTimer[key] = t;
          final mote = monastery.leapMote[key];
          bites = mote != null && (a.position - mote).distance < _kLeapBiteR;

        case WardStrain.feign:
          final patches = _feignPatches(room);
          for (var i = 0; i < patches.length; i++) {
            final pk = '$key/$i';
            var fuse = monastery.feignFuse[pk] ?? 0;
            final near = (a.position - patches[i]).distance;
            if (fuse > 0) {
              fuse = max(0.0, fuse - dt);
              if (fuse == 0) fuse = -_kFeignCool;
              if (near < _kFeignBiteR) bites = true;
            } else if (fuse < 0) {
              fuse = min(0.0, fuse + dt);
            } else if (near < _kFeignTrigger) {
              fuse = _kFeignErupt * (virulent ? 1.5 : 1.0);
              bites = true;
            }
            monastery.feignFuse[pk] = fuse;
          }
      }
      if (bites) {
        a.hp = max(
          0,
          a.hp - (virulent ? _kVirulentDps : _kStrainDps) * progressDmgMul * dt,
        );
      }
    }
  }

  // ── Update ───────────────────────────────────────────────

  void _updateMonastery(DungeonCreature a, DungeonRoom room, double dt) {
    if (monastery.sealBurst > 0) {
      monastery.sealBurst = max(
        0.0,
        monastery.sealBurst - dt / _kSealBurstSeconds,
      );
    }
    if (monastery.condemn > 0) {
      monastery.condemn = max(0.0, monastery.condemn - dt / _kCondemnSeconds);
      // …and when the cross has landed, the second beat: what was in that
      // ward comes out of its door into the cloister. Two shots, because
      // they are two different facts — you gave it up, and now you live
      // beside it.
      if (monastery.condemn == 0 && monastery.pendingWalk != null) {
        final w = monastery.pendingWalk;
        monastery.pendingWalk = null;
        if (w != null) _plagueEntersTheWalk(w, sick: false);
      }
    }
    if (monastery.wakeWard != null && monastery.wake < 1) {
      monastery.wake = min(1.0, monastery.wake + dt / _kWakeSeconds);
      if (monastery.wake >= 1) monastery.wakeWard = null;
    }
    if (monastery.invading) {
      monastery.invade = min(1.0, monastery.invade + dt / _kInvadeSeconds);
      // The camera RIDES it, and changes ROOMS with it — a fixed shot of a
      // thing crawling out of frame is a worse shot than no shot, and a shot
      // that stays in the ward after it has left is a shot of a doorway.
      final (r, at) = _invadeAt(monastery.invade);
      followRoomId = r;
      followAt = at;
      if (monastery.invade >= 1) monastery.invading = false;
    }
    _maybeWakeWard(room);
    if (!_isVenom) return;
    final m = monastery;
    m.clock += dt;
    _tickStrains(a, room, dt);

    // The plague-cross rots off the ward it barred: the sacrifice is sealed,
    // then the contagion eats its own door open again (§6.13 — the finale is
    // fought among everything you didn't save).
    if (m.crossRot > 0) {
      m.crossRot = max(0.0, m.crossRot - dt);
      if (m.crossRot == 0) {
        final s = m.triage.surrendered;
        if (s != null) _queueDoorReveal('ambulatory', s);
      }
    }

    // The sick wisp drifts the ambulatory (the lost maxim).
    if (room.id == 'ambulatory' && m.wisp != null) {
      m.wispDrift += dt * 0.35;
      final b = room.bounds;
      m.wisp = Offset(
        b.left + b.width * (0.5 + 0.34 * sin(m.wispDrift)),
        b.top + b.height * (0.55 + 0.22 * sin(m.wispDrift * 1.7)),
      );
    }

    // A cured ward's sacristy: one mercy each, taken by walking to it.
    final ward = room.ward;
    if (ward != null &&
        m.triage.cured.contains(ward.id) &&
        !m.triage.sacristiesTaken.contains(ward.id) &&
        (a.position - ward.sacristy).distance < 44) {
      m.triage.sacristiesTaken.add(ward.id);
      for (final c in creatures) {
        if (c.alive) c.hp = min(c.maxHp, c.hp + c.maxHp * 0.35);
      }
      _setHint('The sacristy opens — the ward\'s own physic mends you', 3.2);
      _spawnAlchemyBurst(
        ward.sacristy,
        producedElement: 'Light',
        reagentElements: const ['Poison'],
        particleCount: 18,
        intensity: 0.8,
      );
      onChanged();
    }
  }

  /// §7 GUARDIAN PRINCIPLE — Blightfang fights WITH the planet's rule.
  /// Patient zero carries every strain the house ever held, and shows one at
  /// a time. It never opens a lull on a clock: only the draught that answers
  /// the habit it is WEARING forces the window, and it takes a fresh habit
  /// the moment the window closes. The finale is one more diagnosis, under
  /// fire, with no squint to read it through.
  void _applyBlightfangStrain(DungeonRoom room, double dt) {
    if (!_isVenom || isRaid) return;
    final g = room.guardian;
    if (g == null) return;
    final m = monastery;
    m.blightStrain ??=
        WardStrain.values[Random().nextInt(WardStrain.values.length)];
    if (m.blightLull > 0) {
      m.blightLull = max(0.0, m.blightLull - dt);
      guardianVulnerable = m.blightLull > 0;
      if (m.blightLull == 0) {
        // A new habit, never the one just answered.
        final pool = WardStrain.values
            .where((s) => s != m.blightStrain)
            .toList();
        m.blightStrain = pool[Random().nextInt(pool.length)];
        _setHint('Blightfang sheds the strain and takes another', 2.6);
      }
    } else {
      guardianVulnerable = false;
    }
  }

  // ── Action button ────────────────────────────────────────

  /// The dose intercept: checked BEFORE the shared guardian catch (the same
  /// precedence Lightning's grounding spike takes), because the phial IS the
  /// fight's verb. Empty-handed, it declines and the strike path runs.
  bool _tryDoseBlightfang(DungeonCreature a) {
    if (!_isVenom || isRaid) return false;
    final room = currentRoom;
    final g = room.guardian;
    final m = monastery;
    if (g == null || !guardianAwake || hasStar(g.starIndex)) return false;
    final phial = m.triage.carried;
    if (phial == null) return false;
    if ((a.position - _guardianPosition(g)).distance > 118) return false;
    m.triage.spend();
    final habit = m.blightStrain;
    if (habit != null && antidoteFor(habit) == phial) {
      m.blightLull = _kBlightLull;
      guardianVulnerable = true;
      _setHint('The dose bites — patient zero reels into the lull', 3.2);
      _spawnAlchemyBurst(
        _guardianPosition(g),
        producedElement: 'Poison',
        reagentElements: const ['Lava', 'Mud'],
        particleCount: 26,
        intensity: 1.2,
      );
    } else {
      // It FEEDS — the planet's own rule, turned on the player.
      final e = _guardianEnemy;
      if (e != null && !e.isDead) {
        e.hp = min(e.maxHp.toDouble(), e.hp + e.maxHp * _kBlightFeedHeal);
      }
      _setHint('Wrong physic — Blightfang drinks it and swells', 3.2);
      _spawnAlchemyBurst(
        _guardianPosition(g),
        producedElement: 'Poison',
        unstable: true,
        particleCount: 20,
        intensity: 1.0,
      );
    }
    return true;
  }

  bool _tryMonastery(DungeonCreature a) {
    if (!_isVenom) return false;
    final room = currentRoom;
    final m = monastery;

    // 0) Entry rite — a Poison creature softens the quarantine wax.
    if (room.id == layout.entranceRoomId && !entryDoorRevealed) {
      final door = room.doors.first;
      if ((a.position - door.rect.center).distance <= 96) {
        if (a.member.element != 'Poison') {
          _setBlockedHint('The quarantine wax answers only Poison');
          return true;
        }
        entryDoorRevealed = true;
        _discoverCloud(PlanetDungeonGame.entryDoorDiscoveryId);
        _setHint('The wax softens and runs — the lazaret stands open');
        _spawnAlchemyBurst(
          door.rect.center,
          producedElement: 'Poison',
          particleCount: 26,
          intensity: 1.1,
        );
        return true;
      }
    }

    // 1) Break a ward's seal, from the corridor. Opening one lets the
    // contagion in — and is the only way to watch what lives there.
    if (room.id == 'ambulatory' && _tryBreakWardSeal(a, room)) return true;

    // 2) The still (or, in the crypt, the carrion font): draw a draught.
    if (room.apothecary != null && _tryDrawDraught(a, room)) return true;

    // 3) The censer: administer what is in hand.
    final ward = room.ward;
    if (ward != null &&
        (a.position - ward.censer).distance <= _kMonasteryReach) {
      return _tryAdminister(a, ward);
    }

    // 4) The oubliette rite, in the ward that was given up.
    if (ward != null && _tryOubliette(a, ward)) return true;

    // 5) The prior's seal: commit the triage.
    final seal = room.priorsSeal;
    if (seal != null &&
        (a.position - seal.position).distance <= _kMonasteryReach) {
      return _tryCommitTriage(seal);
    }

    // 6) The sick wisp — cure it instead of killing it (the lost maxim).
    final wisp = m.wisp;
    if (room.id == 'ambulatory' &&
        wisp != null &&
        (a.position - wisp).distance <= _kMonasteryReach) {
      return _tryDoseWisp();
    }
    return false;
  }

  bool _tryBreakWardSeal(DungeonCreature a, DungeonRoom room) {
    final t = monastery.triage;
    for (final door in room.doors) {
      final target = layout.rooms[door.targetRoomId];
      final ward = target?.ward;
      if (ward == null || t.opened.contains(ward.id)) continue;
      if ((a.position - door.rect.center).distance > 96) continue;
      if (ward.bricked) {
        // §4 HARD GATE: the charnel is brick, not wax. A party with no Lava
        // horn cannot open it — which decides their sacrifice for them, and
        // still leaves both stars earnable on the other three wards.
        final gate = layout.familyGateFor('ward_charnel_brick');
        if (gate != null &&
            !(a.member.element == gate.element &&
                abilityForFamily(a.member.family) ==
                    abilityForFamily(gate.family))) {
          _stampFamilyGate(gate);
          return true;
        }
      }
      t.open(ward.id);
      // NO CUT. Breaking the wax does not take the camera anywhere — the
      // contagion comes up when you WALK IN and see it, which is the same
      // animation without stopping the game to show you a room you were
      // about to enter anyway. (See `_maybeWakeWard`.)
      speakConsequence(
        ward.bricked
            ? 'The brick blows in. Something in the dead-house has been '
                  'waiting.'
            : 'The seal parts, and what is in there wakes.',
        3.6,
      );
      _spawnAlchemyBurst(
        door.rect.center,
        producedElement: 'Poison',
        reagentElements: ward.bricked ? const ['Lava'] : const [],
        unstable: true,
        particleCount: 20,
        intensity: 1.0,
      );
      return true;
    }
    return false;
  }

  /// Does this creature carry the still's power — Poison itself, or the
  /// monastery's own braid **Lava+Mud→Poison** (§4: a recipe substitutes an
  /// ELEMENT, never a family, and pays its authored downside).
  bool _canBrew(DungeonCreature a) =>
      a.member.element == 'Poison' || _monasteryBraidReady(a);

  bool _monasteryBraidReady(DungeonCreature a) {
    final e = a.member.element;
    if (e != 'Lava' && e != 'Mud') return false;
    final want = e == 'Lava' ? 'Mud' : 'Lava';
    return creatures.any(
      (c) => c.alive && !identical(c, a) && c.member.element == want,
    );
  }

  bool _tryDrawDraught(DungeonCreature a, DungeonRoom room) {
    final still = room.apothecary!;
    final t = monastery.triage;
    // The crypt's font is patient zero's own venom: it never runs dry and it
    // never touches the cistern — the finale is a diagnosis, not a supply run.
    final carrion = room.guardian != null;
    for (final spout in still.spouts) {
      if ((a.position - spout.position).distance > _kMonasteryReach) continue;
      if (!_canBrew(a)) {
        _setBlockedHint('The still answers only Poison');
        return true;
      }
      if (t.carried != null) {
        _setBlockedHint('A hand carries one phial');
        return true;
      }
      final ok = carrion ? t.drawCarrion(spout.draught) : t.draw(spout.draught);
      if (!ok) {
        // Only ever reachable with three wards already clean: the house has
        // no physic for a fourth, and that is the whole planet.
        _setBlockedHint('The cistern holds nothing for a fourth ward');
        return true;
      }
      final braid = a.member.element != 'Poison';
      _setHint(
        '${draughtFixtureName(spout.draught)} fills the phial'
        '${braid ? ' — the braid runs hot' : ''}',
        3.0,
      );
      _spawnAlchemyBurst(
        spout.position,
        producedElement: 'Poison',
        reagentElements: braid ? const ['Lava', 'Mud'] : const [],
        unstable: braid,
        particleCount: braid ? 22 : 16,
        intensity: braid ? 1.1 : 0.8,
      );
      // The braid's authored downside (§4): the roar of it draws wisps.
      if (braid) {
        spawnWispWave(
          element: 'Poison',
          center: spout.position,
          count: 2,
          unstable: true,
          announce: false,
        );
      }
      return true;
    }
    return false;
  }

  bool _tryAdminister(DungeonCreature a, WardCell ward) {
    final m = monastery;
    final outcome = m.triage.dose(ward.id);
    switch (outcome) {
      case DoseOutcome.noPhial:
        _setBlockedHint('Nothing in hand to give');
      case DoseOutcome.sealed:
        _setBlockedHint('The ward is still shut');
      case DoseOutcome.settled:
        _setHint('This ward is settled — nothing here to physic');
      case DoseOutcome.cured:
        _setHint('The strain lets go — ${ward.name} is clean', 3.6);
        _spawnAlchemyBurst(
          ward.censer,
          producedElement: 'Light',
          reagentElements: const ['Poison'],
          particleCount: 26,
          intensity: 1.1,
        );
        final seal = layout.rooms['ambulatory']?.priorsSeal;
        if (seal != null && !hasStar(seal.diagnosisStarIndex)) {
          earnStar(seal.diagnosisStarIndex);
        }
      case DoseOutcome.fed:
        // §6.13: a wrong brew FEEDS it — permanently, and out into the
        // corridor. The cost of a misdiagnosis is danger you must live with,
        // never a star you can no longer earn (see WardTriage.dregsAvailable).
        // THE OTHER THING THAT PUTS A STRAIN LOOSE, and until now the
        // quieter of the two by a long way. It is permanent unless you come
        // back and cure this ward, and it walks the cloister meanwhile — so
        // it gets the shot and the shake, like the cross does.
        _plagueEntersTheWalk(currentRoomId, sick: true);
        speakConsequence(
          'Wrong physic. The strain drinks it and doubles — and it is loose '
          'in the walk until this ward is cured.',
          4.4,
        );
        _spawnAlchemyBurst(
          ward.heart,
          producedElement: 'Poison',
          unstable: true,
          particleCount: 24,
          intensity: 1.2,
        );
        spawnWispWave(
          element: 'Poison',
          center: ward.heart,
          count: 2,
          unstable: true,
          announce: false,
        );
    }
    return true;
  }

  bool _tryCommitTriage(PriorsSeal seal) {
    final t = monastery.triage;
    if (t.surrendered != null) {
      _setHint('The cross is already up');
      return true;
    }
    if (!t.canCommit) {
      final left = kMonasteryCures - t.cured.length;
      _setBlockedHint(
        'The cross waits on $left more cure${left == 1 ? '' : 's'}',
      );
      return true;
    }
    final given = t.commit();
    monastery.crossRot = _kCrossRot;
    final ward = layout.rooms[given]?.ward;
    // THE CUT. Breaking a seal got a cinematic and THIS did not, which had
    // the ceremony exactly backwards: a broken seal is how you look inside,
    // and this is the ward you are never going to save. The cost of it walks
    // the cloister for the rest of the run.
    monastery
      ..condemn = 1.0
      ..condemnAt = seal.position;
    cutTo(currentRoomId, seal.position, hold: _kCondemnSeconds + 0.4);
    monastery.pendingWalk = given;
    _shake = 7.0;
    speakConsequence(
      'The cross goes up over ${ward?.name ?? 'the last ward'}. It is given '
      'up, and what is in it is loose in the walk from here on.',
      4.6,
    );
    _spawnAlchemyBurst(
      seal.position,
      producedElement: 'Poison',
      reagentElements: const ['Lava', 'Mud'],
      particleCount: 28,
      intensity: 1.2,
    );
    if (!hasStar(seal.triageStarIndex)) earnStar(seal.triageStarIndex);
    return true;
  }

  bool _tryOubliette(DungeonCreature a, WardCell ward) {
    final m = monastery;
    if (ward.id != m.triage.surrendered || m.oublietteOpen) return false;
    if ((a.position - ward.oubliette).distance > _kMonasteryReach) return false;
    if (!guardianRiteUnlocked) {
      _setBlockedHint(
        'The oubliette answers only a bearer of the ${layout.starName(0)} '
        'and ${layout.starName(1)}',
      );
      return true;
    }
    if (!_canBrew(a)) {
      _setBlockedHint('The lead seal answers only Poison');
      return true;
    }
    m.oublietteOpen = true;
    guardianAwake = true;
    guardianHp = PlanetDungeonGame.maxGuardianHp;
    _setHint(
      'The lead runs off the stone — Blightfang stirs in the dark below',
      4.2,
    );
    _spawnAlchemyBurst(
      ward.oubliette,
      producedElement: 'Poison',
      reagentElements: const ['Lava', 'Mud'],
      particleCount: 30,
      intensity: 1.3,
    );
    _queueDoorReveal(ward.id, 'lazar_crypt');
    return true;
  }

  /// THE DOSE (Paracelsus) — the lost maxim. One sick wisp wanders the
  /// ambulatory; a blade is not the answer. Diagnose it like a ward and pour.
  bool _tryDoseWisp() {
    final m = monastery;
    final phial = m.triage.carried;
    if (phial == null) {
      _setBlockedHint('Nothing in hand to give');
      return true;
    }
    m.triage.spend();
    final wisp = m.wisp!;
    if (antidoteFor(m.wispStrain) != phial) {
      _setHint('The sick wisp shies from the phial — wrong physic', 3.0);
      _spawnAlchemyBurst(
        wisp,
        producedElement: 'Poison',
        unstable: true,
        particleCount: 14,
        intensity: 0.7,
      );
      return true;
    }
    m.wisp = null;
    // THE RITE OF THREE pays this out (see `beginMaximRite`).
    _setHint('The wisp drinks, and quietens', 4.0);
    beginMaximRite(kPoisonDoseEggId, wisp);
    _spawnAlchemyBurst(
      wisp,
      producedElement: 'Light',
      reagentElements: const ['Poison'],
      particleCount: 26,
      intensity: 1.1,
    );
    return true;
  }

  // ── Doors ────────────────────────────────────────────────

  /// The oubliettes exist only in the ward that was surrendered, and only
  /// once its lead seal is dissolved (§5.5 vault trick — the way down is a
  /// consequence of the sacrifice, never a door you could have used before).
  bool _monasteryDoorHidden(DungeonRoom room, DungeonDoor door) {
    if (!_isVenom) return false;
    final t = monastery.triage;
    if (door.targetRoomId == 'lazar_crypt') {
      return room.ward?.id != t.surrendered || !monastery.oublietteOpen;
    }
    if (room.id == 'lazar_crypt') {
      return door.targetRoomId != t.surrendered;
    }
    return false;
  }

  /// Is [door] a squint between two wards (the Mud MANE gate)?
  bool _isSquint(DungeonRoom room, DungeonDoor door) =>
      room.ward != null && layout.rooms[door.targetRoomId]?.ward != null;

  bool _monasteryDoorLocked(DungeonRoom room, DungeonDoor door) {
    if (!_isVenom) return false;
    final t = monastery.triage;
    final target = layout.rooms[door.targetRoomId];
    // The squints are a hard family gate on the DOOR itself (§4): a Mud mane
    // and nobody else. The ambulatory still reaches every ward, so this
    // closes a shortcut, never a route.
    if (_isSquint(room, door)) return !_monasterySquintPasses(door);
    // A ward you have not unsealed is not a room yet.
    if (room.id == 'ambulatory' &&
        target?.ward != null &&
        !t.opened.contains(target!.ward!.id)) {
      return true;
    }
    // The plague-cross bars the ward it crossed off, until it rots away.
    if (monastery.crossRot > 0) {
      if (door.targetRoomId == t.surrendered) return true;
      if (room.ward?.id == t.surrendered) return true;
    }
    return false;
  }

  /// The squint gate, evaluated against the ACTIVE creature: only a Mud mane
  /// walks a live ward with a phial still good. Blocks nothing — the
  /// ambulatory reaches every ward — so this is a legal family-exclusive
  /// shortcut (§4), not a wall in front of a star.
  bool _monasterySquintPasses(DungeonDoor door) {
    final a = active;
    final gate = layout.familyGateFor('ward_squint');
    if (a == null || gate == null) return false;
    final t = monastery.triage;
    final target = layout.rooms[door.targetRoomId]?.ward;
    if (target == null || !t.opened.contains(target.id)) return false;
    return a.member.element == gate.element &&
        abilityForFamily(a.member.family) == abilityForFamily(gate.family);
  }

  String _monasteryDoorHint(DungeonRoom room, DungeonDoor door) {
    final t = monastery.triage;
    if (_isSquint(room, door)) {
      final target = layout.rooms[door.targetRoomId]?.ward;
      if (target != null && !t.opened.contains(target.id)) {
        return 'The wax holds on this side too';
      }
      final gate = layout.familyGateFor('ward_squint');
      if (gate != null) {
        _discoverCloud(gate.discoveryId); // THE SEAL REMEMBERS (§4)
        return gate.hintLine;
      }
    }
    if (monastery.crossRot > 0 &&
        (door.targetRoomId == t.surrendered ||
            room.ward?.id == t.surrendered)) {
      return 'The plague-cross bars this ward';
    }
    final target = layout.rooms[door.targetRoomId]?.ward;
    if (target != null) {
      if (target.bricked) {
        final gate = layout.familyGateFor('ward_charnel_brick');
        if (gate != null) {
          _discoverCloud(gate.discoveryId);
          return gate.hintLine;
        }
      }
      return 'The quarantine wax holds';
    }
    return 'The way is shut';
  }

  // ── Hints (§5.6) ─────────────────────────────────────────

  /// OBJECTIVE — one line on entry, WHAT and never HOW.
  String? _monasteryObjectiveHint(DungeonRoom room) {
    final t = monastery.triage;
    switch (room.id) {
      case 'lazar_gate':
        return entryDoorRevealed ? null : 'The quarantine door is waxed shut';
      case 'apothecary':
        return t.carried == null
            ? 'The infirmary still stands cold'
            : 'A phial is drawn';
      case 'ambulatory':
        if (t.surrendered != null) return null;
        return t.canCommit
            ? 'Three wards are clean — the prior\'s seal waits'
            : 'Four wards, and physic for three';
      case 'lazar_crypt':
        return 'Patient zero keeps every strain the house ever held';
    }
    final ward = room.ward;
    if (ward == null) return null;
    if (t.cured.contains(ward.id)) return null;
    if (ward.id == t.surrendered) {
      return monastery.oublietteOpen
          ? null
          : 'A stone in the floor is leaded shut';
    }
    return 'Something lives in ${ward.name}';
  }

  /// AMBIENT — atmosphere only. No mechanics, no stats, no families.
  void _monasteryAmbientHint(DungeonCreature a, DungeonRoom room) {
    if (room.id == 'ambulatory' && monastery.triage.loose.isNotEmpty) {
      _setAmbientHint('The corridor breathes where it should not');
      return;
    }
    if (room.ward != null && monastery.triage.cured.contains(room.ward!.id)) {
      _setAmbientHint('This cell smells only of lime and old linen');
    }
  }

  /// INSIGHT — Mask's earned how-to, and the ONLY channel allowed to teach
  /// method (§5.6). Tier 0 says there is a habit; tier 1 names the habit;
  /// tier 2 names the tap that answers it.
  void _monasteryReveal(DungeonCreature a, DungeonRoom room) {
    revealFlash = 0.6;
    revealTier = revealHintTier(a.member.statIntelligence);
    final t = monastery.triage;

    final ward = room.ward;
    if (ward != null) {
      if (!t.opened.contains(ward.id)) {
        _setInsightHint('The wax hides whatever walks in there');
        return;
      }
      if (t.cured.contains(ward.id)) {
        _setInsightHint('Nothing left in here to read');
        return;
      }
      final s = t.strainOf(ward.id);
      if (s == null) return;
      _setInsightHint(switch (revealTier) {
        0 => 'The sickness has a habit — watch it before you pour',
        1 => 'Read it: ${strainHabit(s)}',
        _ =>
          'Read it: ${strainHabit(s)} — ${draughtFixtureName(antidoteFor(s))} answers it',
      });
      return;
    }

    if (room.guardian != null) {
      final habit = monastery.blightStrain;
      _setInsightHint(
        habit == null || revealTier < 1
            ? 'It wears one strain at a time — read it before you pour'
            : 'Right now: ${strainHabit(habit)}',
      );
      return;
    }

    if (room.apothecary != null) {
      _setInsightHint(
        revealTier < 1
            ? 'Four taps, four different physics'
            : 'A bell that damps, a kiln that burns off, a pot that fills a '
                  'gap, bitters that will not let a thing lie',
      );
      return;
    }

    if (room.id == 'ambulatory') {
      final loose = t.loose;
      _setInsightHint(
        loose.isEmpty
            ? 'The corridor is clean — for now'
            : 'Loose in the walk: ${loose.map(strainHabit).join('; ')}',
      );
      return;
    }
    _setInsightHint('Nothing here reads back');
  }

  /// PROGRESS READOUT (§5.6) — state leaves the capsule.
  DungeonProgressReadout? get _monasteryProgressReadout {
    final t = monastery.triage;
    if (t.isEmpty) return null;
    final phial = t.carried;
    if (phial != null) {
      return DungeonProgressReadout(
        label: 'PHIAL',
        value: draughtFixtureName(phial),
      );
    }
    return DungeonProgressReadout(
      label: 'WARDS',
      value: '${t.cured.length}/$kMonasteryCures cured · ${t.cistern} left',
      fraction: (t.cured.length / kMonasteryCures).clamp(0.0, 1.0),
    );
  }

  double get _monasteryMoodTarget => switch (currentRoomId) {
    'lazar_crypt' => 0.18,
    'apothecary' => 0.48,
    'lazar_gate' => 0.42,
    _ => 0.3,
  };

  // ── Render ───────────────────────────────────────────────
  //
  // VISUAL GRAMMAR (§5.5): nothing here may read like another planet in a
  // screenshot. Poison's language is SPORE-WORK — soft rings of motes, a
  // fringe of bristles growing off the stone, a mote on a filament, dead
  // grey scabs on the floor. No tile floods (Steam owns those), no jagged
  // bolts (Lightning), no beams, no tide.

  static const Color _venomDeep = Color(0xFF4A2B62);
  static const Color _venomLive = Color(0xFF8FD14F);
  static const Color _venomSick = Color(0xFFB86FE0);
  static const Color _venomBone = Color(0xFFD8CBA8);

  /// SPORES, going up. Slow, uneven, lit — the air in a plague house is not
  /// still, it is FULL, and the one thing that has to read from a still frame
  /// is that you are breathing it.
  ///
  /// Screen-space, like every other planet's air: it is the room you are IN
  /// rather than a thing at a place, and it must not scroll with the camera
  /// or it becomes scenery you could walk away from.
  void _drawSporeDrift(Canvas canvas, Size vp) {
    for (var i = 0; i < 26; i++) {
      final seed = i * 79;
      final speed = 0.020 + (seed % 7) * 0.004;
      final t = ((_time * speed) + (seed % 100) / 100.0) % 1.0;
      final x =
          ((seed * 37) % vp.width.toInt()).toDouble() +
          sin(_time * 0.5 + i) * 16;
      final y = vp.height * (1.08 - 1.16 * t);
      final r = 1.1 + (seed % 5) * 0.5;
      // Most are the dull green of the place; a few are the sick violet, and
      // those are the ones the eye keeps catching.
      final sick = i % 7 == 0;
      canvas.drawCircle(
        Offset(x % vp.width, y),
        r,
        Paint()
          ..color = (sick ? _venomSick : _venomLive).withValues(
            alpha: (sick ? 0.30 : 0.16) * sin(t * pi).clamp(0.0, 1.0),
          ),
      );
    }
  }

  void _renderMonastery(Canvas canvas, DungeonRoom room) {
    _renderLazarFloor(canvas, room);
    _renderContagion(canvas, room);
    _renderStrains(canvas, room);
    _renderMonasteryFixtures(canvas, room);
    _renderWardSeals(canvas, room);
    _renderLazarGloom(canvas, room);
    // AFTER the gloom. Drawn under it the burst was darkened by the very
    // thing it should be lighting — and worse, the gloom centres on the
    // PARTY, so during the cut the doorway sat in the dark ring and the
    // whole animation was invisible. Reported from play as "I don't see
    // anything". Light cuts through dark; that is what light is for.
    _renderSealBurst(canvas);
    _renderCondemnation(canvas);
    _renderWalkInvasion(canvas, room);
  }

  /// WHAT IS IN THE ROOM WITH YOU, on the floor rather than in the air.
  ///
  /// A ward with a live strain has it growing out from the heart: bloom on
  /// the flags, veins running into the mortar, and a wet shine where it is
  /// thickest. A VIRULENT one — one you fed the wrong draught — goes violet
  /// and reaches further, so the mistake is a thing you can see from the door
  /// rather than a word in a readout.
  void _renderContagion(Canvas canvas, DungeonRoom room) {
    final live = _liveStrains(room);
    if (live.isEmpty) return;
    final heart = _strainHeart(room);
    final virulent = live.any((e) => e.$2);
    final col = virulent ? _venomSick : _venomLive;
    final breath = 0.5 + 0.5 * sin(_time * 0.8);
    // WAKING: the same veins, drawn to a fraction of their length, so the
    // thing grows into the shape it is going to hold rather than snapping
    // into it. Eased out, because it comes up fast and then settles.
    final waking = room.ward != null && monastery.wakeWard == room.ward!.id;
    final grow = waking
        ? Curves.easeOutCubic.transform(monastery.wake.clamp(0.0, 1.0))
        : 1.0;
    if (grow <= 0.01) return;
    final reach = (virulent ? 300.0 : 210.0) * (0.90 + 0.10 * breath) * grow;

    // Inside the room only — a vein crawling out through a wall reads as a
    // render bug, not as sickness.
    canvas.save();
    canvas.clipRect(room.bounds);

    // The bloom: three soft rings, darkest at the heart.
    for (var i = 3; i >= 1; i--) {
      canvas.drawCircle(
        heart,
        reach * i / 3,
        // Lighter than it was: the strains animate ON this, and a bloom
        // heavy enough to read on its own flattens them into it.
        Paint()..color = col.withValues(alpha: 0.022 * (4 - i)),
      );
    }
    // VEINS. Deterministic, so the sickness does not crawl between frames —
    // it grows when the ward changes, and only then.
    var seed = room.id.codeUnits.fold<int>(53, (a, c) => (a * 31 + c) % 30011);
    double rnd() {
      seed = (seed * 1103515245 + 12345) % 2147483648;
      return seed / 2147483648;
    }

    // VEINS, and they PULSE. The geometry stays deterministic — sickness that
    // rewrites its own shape every frame is a screensaver — but a wave runs
    // outward along every vein from the heart, so the thing is alive without
    // ever moving. Drawn flat it was the biggest object in the room and the
    // only motionless one, which made the strains animating on top of it read
    // as the static thing. Reported from play as the plague looking frozen.
    for (var i = 0; i < 14; i++) {
      var at = heart;
      var a = rnd() * pi * 2;
      final len = reach * (0.35 + rnd() * 0.6);
      final w = 1.2 + rnd() * 2.0;
      final base = 0.09 + 0.12 * rnd();
      const steps = 6;
      for (var k = 0; k < steps; k++) {
        a += (rnd() - 0.5) * 1.1;
        final next = at + Offset(cos(a), sin(a)) * (len / steps);
        // The wave: one per vein, travelling out, offset per vein so they do
        // not beat in unison like a heart monitor.
        final wave = sin(_time * 2.2 - k * 0.9 - i * 0.7);
        final lit = base + 0.26 * (wave * 0.5 + 0.5) * (wave > 0 ? 1 : 0.35);
        canvas.drawLine(
          at,
          next,
          Paint()
            ..strokeWidth = w + 0.9 * (wave.clamp(0.0, 1.0))
            ..strokeCap = StrokeCap.round
            ..color = col.withValues(alpha: lit),
        );
        at = next;
      }
    }
    // And a wet shine at the heart itself.
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        heart,
        70 + 18 * breath,
        col.withValues(alpha: virulent ? 0.26 : 0.16),
      );
    }
    canvas.restore();
  }

  /// THE DARK CLOSING IN. A lazar house is lit by whatever somebody carried
  /// in, so the room is bright where the party is and black at the edges.
  ///
  /// Drawn in WORLD space, over the room's own fabric and under everything
  /// living, so it darkens the place rather than the picture — the screen
  /// vignette is a frame, and a frame does not make a room feel enclosed.
  void _renderLazarGloom(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    // Centred on the SHOT, not the party: while the camera is holding
    // somewhere else, the light has to be there too or it is looking into a
    // dark corner of its own making.
    final at = followAt ?? active?.position ?? b.center;
    canvas.drawRect(
      b,
      Paint()
        ..shader = ui.Gradient.radial(
          at,
          460,
          [
            const Color(0x00000000),
            const Color(0x66070A06),
            const Color(0xCC040604),
          ],
          const [0.0, 0.58, 1.0],
        ),
    );
  }

  /// A LAZAR HOUSE FLOOR. Worn flags, lime thrown down against the contagion,
  /// straw where the sick lay, and a drain cut down one side.
  ///
  /// This planet had no floor renderer at all — every room was the engine's
  /// green gradient with a rounded border and two or three flat primitives on
  /// it, which is placeholder art rather than a place. It is the same first
  /// move Steam and Lava each needed, and for the same reason: the ground is
  /// the only thing in every single room, so it is the cheapest sentence the
  /// planet can say about what it is.
  void _renderLazarFloor(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    canvas.drawRect(
      b,
      Paint()
        // NOT OPAQUE. The floor sits a little off the sky so the planet's own
        // light comes up through the flags and the miasma behind them keeps
        // showing — a sealed house that is nonetheless full of something.
        // Solid, the stage cut the background off and every room was a lit
        // box with weather happening somewhere you could not see.
        ..shader = ui.Gradient.linear(b.topCenter, b.bottomCenter, [
          const Color(0xFF161A15).withValues(alpha: _kLazarFloorAlpha),
          const Color(0xFF0E120E).withValues(alpha: _kLazarFloorAlpha),
        ]),
    );

    var seed = room.id.codeUnits.fold<int>(
      131,
      (a, c) => (a * 137 + c) % 65413,
    );
    double rnd() {
      seed = (seed * 1103515245 + 12345) % 2147483648;
      return seed / 2147483648;
    }

    // FLAGSTONES. Irregular courses — a monastery floor was laid by hand out
    // of whatever came off the hill, and a regular grid is the one thing that
    // reads as a diagram (the lesson Lava's floor cost three attempts).
    var y = b.top - 10;
    while (y < b.bottom) {
      final h = 46 + rnd() * 26;
      var x = b.left - 20 - rnd() * 40;
      while (x < b.right) {
        final w = 60 + rnd() * 70;
        final slab = Rect.fromLTWH(x + 1.5, y + 1.5, w - 3, h - 3);
        if (slab.overlaps(b)) {
          canvas.drawRect(
            slab,
            Paint()
              ..color = Color.lerp(
                const Color(0xFF20241D),
                const Color(0xFF171B16),
                rnd(),
              )!.withValues(alpha: _kLazarFloorAlpha),
          );
          // Lit top edge, so a flag is a flag and not a rectangle.
          canvas.drawRect(
            Rect.fromLTWH(slab.left, slab.top, slab.width, 1.6),
            Paint()..color = const Color(0xFF2E342A).withValues(alpha: 0.6),
          );
          // Worn hollow in the middle of the older ones.
          // A worn hollow, on a few. At a third of all flags these stacked
          // with the lime into a mottle and the floor read as blotches
          // rather than as stone.
          if (rnd() < 0.16) {
            canvas.drawOval(
              slab.deflate(slab.width * 0.3),
              Paint()..color = const Color(0xFF1A1E18).withValues(alpha: 0.5),
            );
          }
        }
        x += w;
      }
      y += h;
    }

    // QUICKLIME, thrown down against the contagion and never swept up.
    for (var i = 0; i < 9; i++) {
      final at = Offset(b.left + rnd() * b.width, b.top + rnd() * b.height);
      final r = 9 + rnd() * 17;
      canvas.drawOval(
        Rect.fromCenter(center: at, width: r * 2, height: r * 1.25),
        Paint()..color = _venomBone.withValues(alpha: 0.035 + rnd() * 0.035),
      );
      // A harder scatter at the middle of each throw, so it reads as
      // something tipped out rather than a stain.
      for (var k = 0; k < 5; k++) {
        canvas.drawCircle(
          at + Offset((rnd() - 0.5) * r * 1.6, (rnd() - 0.5) * r),
          0.8 + rnd() * 1.4,
          Paint()..color = _venomBone.withValues(alpha: 0.10 + rnd() * 0.10),
        );
      }
    }

    // STRAW, where the sick were laid — only in the wards.
    if (room.ward != null) {
      final straw = Paint()
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 90; i++) {
        final at = Offset(b.left + rnd() * b.width, b.top + rnd() * b.height);
        final a = rnd() * pi;
        straw.color = const Color(
          0xFF6E6242,
        ).withValues(alpha: 0.10 + rnd() * 0.12);
        canvas.drawLine(
          at,
          at + Offset(cos(a), sin(a)) * (6 + rnd() * 9),
          straw,
        );
      }
    }

    // THE DRAIN, down the low side. Everything in a lazar house runs somewhere.
    final drain = Rect.fromLTWH(b.left + 18, b.bottom - 40, b.width - 36, 13);
    canvas.drawRect(drain, Paint()..color = const Color(0xFF0A0D0A));
    canvas.drawRect(
      Rect.fromLTWH(drain.left, drain.top, drain.width, 1.6),
      Paint()..color = const Color(0xFF2A3026).withValues(alpha: 0.7),
    );
    for (var x = drain.left + 12; x < drain.right; x += 26) {
      canvas.drawRect(
        Rect.fromLTWH(x, drain.top + 2, 3, drain.height - 4),
        Paint()..color = const Color(0xFF232922).withValues(alpha: 0.85),
      );
    }
  }

  void _renderStrains(Canvas canvas, DungeonRoom room) {
    final live = _liveStrains(room);
    if (live.isEmpty) return;
    final b = room.bounds;
    final heart = _strainHeart(room);
    for (final (s, virulent) in live) {
      final key = _strainKey(room.id, s);
      final col = virulent ? _venomSick : _venomLive;
      switch (s) {
        case WardStrain.pulse:
          final r = _pulseRadius() * (virulent ? 1.25 : 1.0);
          // Concentric mote rings, breathing on the beat — a bloom, not a
          // shockwave: nothing in this game rings like this.
          for (var ring = 0; ring < 3; ring++) {
            final rr = r * (0.5 + 0.25 * ring);
            final motes = 10 + ring * 5;
            final paint = Paint()
              ..color = col.withValues(alpha: 0.55 - 0.13 * ring);
            for (var i = 0; i < motes; i++) {
              final ang =
                  (i / motes) * 2 * pi +
                  monastery.clock * 0.4 * (ring.isEven ? 1 : -1);
              canvas.drawCircle(
                heart + Offset(cos(ang), sin(ang)) * rr,
                2.4 + 0.6 * ring,
                paint,
              );
            }
          }
          canvas.drawCircle(
            heart,
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = col.withValues(alpha: r > _kPulseBiteR ? 0.5 : 0.22),
          );

        case WardStrain.creep:
          // A bristled fringe growing off the stone, walking the perimeter.
          final head = monastery.creepHead[key] ?? 0;
          final paint = Paint()..color = col.withValues(alpha: 0.6);
          const steps = 46;
          for (var i = 0; i < steps; i++) {
            final u = (head - _kCreepArc * (i / steps) + 1.0) % 1.0;
            final p = _perimeterPoint(u, b);
            final inward = _inwardNormal(u, b);
            final len = 10.0 + 14.0 * sin(i * 0.7 + monastery.clock * 3);
            canvas.drawLine(p, p + inward * len, paint..strokeWidth = 3.0);
          }

        case WardStrain.leap:
          final mote = monastery.leapMote[key];
          if (mote == null) break;
          // A single mote on a taut filament back to the ward's heart.
          canvas.drawLine(
            heart,
            mote,
            Paint()
              ..color = col.withValues(alpha: 0.22)
              ..strokeWidth = 1.2,
          );
          canvas.drawCircle(
            mote,
            12,
            Paint()..color = col.withValues(alpha: 0.35),
          );
          canvas.drawCircle(mote, 5.5, Paint()..color = col);

        case WardStrain.feign:
          for (var i = 0; i < 3; i++) {
            final p = _feignPatches(room)[i];
            final fuse = monastery.feignFuse['$key/$i'] ?? 0;
            if (fuse > 0) {
              final f = (fuse / _kFeignErupt).clamp(0.0, 1.0);
              canvas.drawCircle(
                p,
                _kFeignBiteR * (1.15 - 0.35 * f),
                Paint()..color = col.withValues(alpha: 0.30 * f + 0.18),
              );
            }
            // Playing dead: a dull grey scab that gives nothing away.
            canvas.drawCircle(
              p,
              15,
              Paint()..color = const Color(0xFF3A3A34).withValues(alpha: 0.72),
            );
          }
      }
    }
  }

  Offset _perimeterPoint(double u, Rect b) {
    final w = b.width, h = b.height;
    final per = 2 * (w + h);
    var d = (u % 1.0) * per;
    if (d < w) return Offset(b.left + d, b.top);
    d -= w;
    if (d < h) return Offset(b.right, b.top + d);
    d -= h;
    if (d < w) return Offset(b.right - d, b.bottom);
    d -= w;
    return Offset(b.left, b.bottom - d);
  }

  Offset _inwardNormal(double u, Rect b) {
    final w = b.width, h = b.height;
    final per = 2 * (w + h);
    var d = (u % 1.0) * per;
    if (d < w) return const Offset(0, 1);
    d -= w;
    if (d < h) return const Offset(-1, 0);
    d -= h;
    if (d < w) return const Offset(0, -1);
    return const Offset(1, 0);
  }

  /// Dressed stone, the material this whole house is built of. A lit top
  /// edge and a shadowed foot is the whole difference between a block and a
  /// rectangle of a slightly different colour.
  void _stoneBlock(Canvas canvas, Rect r, {double radius = 3}) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    canvas.drawRRect(rr, Paint()..color = const Color(0xFF262B24));
    canvas.drawRect(
      Rect.fromLTWH(r.left + 2, r.top, r.width - 4, 2),
      Paint()..color = const Color(0xFF3A4136).withValues(alpha: 0.8),
    );
    canvas.drawRect(
      Rect.fromLTWH(r.left + 2, r.bottom - 2, r.width - 4, 2),
      Paint()..color = const Color(0xFF0B0E0A).withValues(alpha: 0.85),
    );
  }

  /// Old bronze — the censers, the bands, anything that was cast and has been
  /// breathing this air for a century.
  /// How solid the floor is. Below about 0.6 the flags stop reading as stone
  /// and the room becomes a window; above about 0.85 the sky may as well not
  /// be there.
  static const double _kLazarFloorAlpha = 0.72;

  /// How long the plague takes to come through a broken seal.
  static const double _kSealBurstSeconds = 1.7;

  /// How long the cross takes to go up. Longer than a seal breaking, because
  /// this is the bigger thing and the pacing should say so.
  static const double _kCondemnSeconds = 2.4;

  /// How long a ward's contagion takes to establish once the wax is broken.
  static const double _kWakeSeconds = 1.9;

  /// The invasion, end to end: out of the door, across the walk, and settled.
  /// Long on purpose — this is the only thing on the planet that permanently
  /// changes the room you have to keep crossing, and it should take as long
  /// as it takes to feel like an arrival rather than an effect.
  static const double _kInvadeSeconds = 5.0;

  /// How far through the sequence it goes through the doorway.
  static const double _kInvadeCross = 0.34;

  static const Color _venomBronze = Color(0xFF6E6A3E);
  static const Color _venomBronzeLit = Color(0xFF9A9358);
  static const Color _venomIron = Color(0xFF3A3E42);

  /// THE PLAGUE COMING THROUGH. Plays once, at the door it came through.
  void _renderSealBurst(Canvas canvas) {
    final t = monastery.sealBurst;
    if (t <= 0) return;
    final at = monastery.sealBurstAt;
    final k = 1 - t; // 0 → 1
    final col = monastery.burstIsSick ? _venomSick : _venomLive;

    // The wax blowing out: shards thrown clear on the first third.
    if (t > 0.62) {
      final s = (t - 0.62) / 0.38;
      for (var i = 0; i < 9; i++) {
        final a = i * 2 * pi / 9;
        canvas.drawCircle(
          at + Offset(cos(a), sin(a)) * (14 + 70 * (1 - s)),
          3.5 * s,
          Paint()..color = const Color(0xFF8A3044).withValues(alpha: s),
        );
      }
    }
    // The front: a wall of it rolling out of the doorway.
    for (var ring = 0; ring < 3; ring++) {
      final rk = (k - ring * 0.12).clamp(0.0, 1.0);
      if (rk <= 0) continue;
      canvas.drawCircle(
        at,
        18 + 190 * rk,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16 * (1 - rk)
          ..color = col.withValues(alpha: 0.30 * (1 - rk) * t),
      );
    }
    // And what is IN it — motes carried out on the front, tumbling.
    for (var i = 0; i < 18; i++) {
      final a = (i / 18) * pi * 2 + k * 0.8;
      final d = 20 + 210 * k * (0.55 + (i % 5) / 8);
      canvas.drawCircle(
        at + Offset(cos(a), sin(a) * 0.72) * d,
        1.6 + 2.6 * t,
        Paint()
          ..color = (i % 6 == 0 ? _venomBone : col).withValues(alpha: 0.75 * t),
      );
    }
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        at,
        60 + 90 * k,
        col.withValues(alpha: 0.30 * t),
      );
    }
  }

  /// THE PLAGUE COMES OUT INTO THE WALK.
  ///
  /// The one thing on this planet that genuinely escapes into the main room,
  /// and the only two ways it happens are a ward you gave up and a ward you
  /// dosed wrong. Both are a press, both are permanent, and both used to
  /// resolve somewhere you were not looking.
  ///
  /// So the camera goes to the cloister and watches it come through that
  /// ward's own door: the door you broke, now with the thing you failed to
  /// deal with walking out of it into the corridor you have to keep using.
  void _plagueEntersTheWalk(String wardRoomId, {required bool sick}) {
    final walk = layout.rooms['ambulatory'];
    if (walk == null) return;
    Offset? at;
    for (final d in walk.doors) {
      if (d.targetRoomId == wardRoomId) at = d.rect.center;
    }
    if (at == null) return;
    // …and where it leaves FROM: the ward's own door out to the walk.
    final wardRoom = layout.rooms[wardRoomId];
    Offset exit = at;
    for (final d in wardRoom?.doors ?? const <DungeonDoor>[]) {
      if (d.targetRoomId == 'ambulatory') exit = d.rect.center;
    }
    monastery
      ..invade = 0
      ..invading = true
      ..invadeSick = sick
      ..invadeWardRoom = wardRoomId
      ..invadeWardFrom = wardRoom?.ward?.heart ?? exit
      ..invadeWardExit = exit
      ..invadeFrom = at
      // Where a loose strain lives: `_strainHeart` gives the room's centre
      // for the ambulatory, which has no ward of its own.
      ..invadeTo = walk.bounds.center;
    // OPEN IN THE WARD. The shot starts where the party is standing, watches
    // the thing come off the heart and go out through the door beside them,
    // and only then follows it into the walk.
    cutTo(wardRoomId, monastery.invadeWardFrom, hold: _kInvadeSeconds + 0.7);
    _shake = 5.0;
  }

  /// Where the head of the invasion is, and WHICH ROOM it is in. The sequence
  /// crosses a doorway, so the shot has to change rooms with it.
  (String, Offset) _invadeAt(double t) {
    final m = monastery;
    if (t < _kInvadeCross) {
      // In the ward: off the heart and over to the door, gathering speed.
      final k = Curves.easeInCubic.transform(
        (t / _kInvadeCross).clamp(0.0, 1.0),
      );
      return (
        m.invadeWardRoom,
        Offset.lerp(m.invadeWardFrom, m.invadeWardExit, k)!,
      );
    }
    final travel = ((t - _kInvadeCross - 0.10) / 0.38).clamp(0.0, 1.0);
    final k = Curves.easeInOutCubic.transform(travel);
    final straight = Offset.lerp(m.invadeFrom, m.invadeTo, k)!;
    // IT SNAKES. A dead-straight line reads as a projectile fired at the
    // room; a thing crawling casts about as it comes. Deterministic in the
    // parameter, so the trail behind the head is the path the head took.
    final d = m.invadeTo - m.invadeFrom;
    final len = d.distance;
    if (len < 1) return ('ambulatory', straight);
    final n = Offset(-d.dy, d.dx) / len;
    return (
      'ambulatory',
      straight + n * (sin(k * pi * 2.6) * 34 * sin(k * pi)),
    );
  }

  /// THE PLAGUE CRAWLING OUT AND TAKING THE WALK. Three beats over five
  /// seconds: it gropes out of the doorway, it comes across the floor, and it
  /// settles in the middle of the room you have to keep crossing and starts
  /// to breathe there.
  void _renderWalkInvasion(Canvas canvas, DungeonRoom room) {
    final m = monastery;
    if (!m.invading) return;
    final t = m.invade;
    final col = m.invadeSick ? _venomSick : _venomLive;
    final (headRoom, head) = _invadeAt(t);
    final inWard = room.id == m.invadeWardRoom;
    if (!inWard && room.id != 'ambulatory') return;

    canvas.save();
    canvas.clipRect(room.bounds);

    // ── IN THE WARD ── it comes off the heart and goes for the door, right
    // past the party. Drawn while the head is still in here, and for a beat
    // after so the tail is seen leaving.
    if (inWard && t < _kInvadeCross + 0.12) {
      final trail = Path()..moveTo(m.invadeWardFrom.dx, m.invadeWardFrom.dy);
      const n = 10;
      for (var i = 1; i <= n; i++) {
        final (_, p) = _invadeAt(min(t, _kInvadeCross) * i / n);
        trail.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        trail,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round
          ..color = col.withValues(alpha: 0.12),
      );
      canvas.drawPath(
        trail,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = col.withValues(alpha: 0.34),
      );
      if (t < _kInvadeCross) _drawInvadeHead(canvas, head, col);
    }

    // ── THROUGH THE DOOR ── tendrils groping over the sill on the far side,
    // before the body follows it out.
    if (!inWard) {
      final out = ((t - _kInvadeCross) / 0.14).clamp(0.0, 1.0);
      if (out > 0) {
        for (var i = 0; i < 7; i++) {
          var at = m.invadeFrom;
          var a = pi / 2 + (i - 3) * 0.34;
          for (var k = 0; k < 5; k++) {
            a += sin(_time * 2 + i * 2.0 + k) * 0.16;
            final next = at + Offset(cos(a), sin(a)) * (16 * out);
            canvas.drawLine(
              at,
              next,
              Paint()
                ..strokeWidth = (4.0 - k * 0.5) * out
                ..strokeCap = StrokeCap.round
                ..color = col.withValues(alpha: 0.42 * out),
            );
            at = next;
          }
        }
      }

      // ── ACROSS THE WALK ── the body comes over, and marks the floor.
      if (t > _kInvadeCross + 0.08) {
        final trail = Path()..moveTo(m.invadeFrom.dx, m.invadeFrom.dy);
        const n = 16;
        for (var i = 1; i <= n; i++) {
          final (_, p) = _invadeAt(
            _kInvadeCross + 0.10 + (t - _kInvadeCross - 0.10) * i / n,
          );
          trail.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(
          trail,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 13
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = col.withValues(alpha: 0.13),
        );
        canvas.drawPath(
          trail,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = col.withValues(alpha: 0.34),
        );
        if (headRoom == 'ambulatory') _drawInvadeHead(canvas, head, col);
      }

      // ── IT SETTLES ── and begins to breathe in the middle of the walk.
      final settle = ((t - 0.76) / 0.24).clamp(0.0, 1.0);
      if (settle > 0) {
        final pulse = 0.5 + 0.5 * sin(_time * 2.4);
        final r = 150 * Curves.easeOutCubic.transform(settle);
        for (var i = 3; i >= 1; i--) {
          canvas.drawCircle(
            m.invadeTo,
            r * i / 3 * (0.94 + 0.06 * pulse),
            Paint()..color = col.withValues(alpha: 0.05 * (4 - i) * settle),
          );
        }
        if (_fx.ready) {
          drawGlow(
            canvas,
            _fx.glow!,
            m.invadeTo,
            70 + 20 * pulse,
            col.withValues(alpha: 0.26 * settle),
          );
        }
      }
    }
    canvas.restore();
  }

  /// The head of the thing: a knot with legs feeling ahead of it.
  void _drawInvadeHead(Canvas canvas, Offset head, Color col) {
    for (var i = 0; i < 9; i++) {
      final a = i * 2 * pi / 9 + _time * 0.9;
      canvas.drawLine(
        head,
        head + Offset(cos(a), sin(a)) * (14 + 7 * sin(_time * 5 + i)),
        Paint()
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..color = col.withValues(alpha: 0.55),
      );
    }
    canvas.drawCircle(head, 11, Paint()..color = col.withValues(alpha: 0.85));
    if (_fx.ready) {
      drawGlow(canvas, _fx.glow!, head, 46, col.withValues(alpha: 0.34));
    }
  }

  /// THE CONTAGION COMES UP AS YOU WALK IN.
  ///
  /// It used to play as a cut the moment the wax broke: the camera went
  /// through the door into a room you were not in and held there. The
  /// animation was right and the cut was not — it stopped the game to show a
  /// room you were about to walk into under your own steam.
  ///
  /// Once per ward, on the first arrival after it is opened. A second visit
  /// finds it already established, which is also the truth of the place.
  void _maybeWakeWard(DungeonRoom room) {
    final m = monastery;
    if (m.lastRoomId == room.id) return;
    m.lastRoomId = room.id;
    final ward = room.ward;
    if (ward == null) return;
    if (!m.triage.opened.contains(ward.id)) return;
    if (!m.wakeShown.add(ward.id)) return;
    m
      ..wake = 0
      ..wakeWard = ward.id;
  }

  /// THE CROSS GOING UP. The plague cross planted over a ward you have
  /// decided not to save, and the sickness walking out of it into the
  /// cloister — which is the thing you will be living with for the rest of
  /// the run, so it gets the longer, heavier shot of the two.
  void _renderCondemnation(Canvas canvas) {
    final t = monastery.condemn;
    if (t <= 0) return;
    final at = monastery.condemnAt;
    final k = 1 - t;

    // The cross rises, then slams.
    final rise = Curves.easeOutBack.transform(k.clamp(0.0, 1.0));
    final drop = k < 0.55 ? 0.0 : ((k - 0.55) / 0.45);
    final y = at.dy - 70 * (1 - rise) + 4 * sin(drop * pi);
    final c = Offset(at.dx, y);
    final arm = Paint()
      ..color = const Color(0xFF7A1F2E)
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(c + const Offset(0, -40), c + const Offset(0, 40), arm);
    canvas.drawLine(c + const Offset(-26, -12), c + const Offset(26, -12), arm);
    canvas.drawLine(
      c + const Offset(-3, -38),
      c + const Offset(-3, 36),
      Paint()
        ..strokeWidth = 2.5
        ..color = Colors.white.withValues(alpha: 0.18),
    );

    // Struck home: dust out of the floor and a ring off the impact.
    if (drop > 0) {
      canvas.drawCircle(
        Offset(at.dx, at.dy + 38),
        30 + 150 * drop,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9 * (1 - drop)
          ..color = _venomBone.withValues(alpha: 0.34 * (1 - drop)),
      );
      // And what was in the ward, leaving it — a slow crawl outward rather
      // than a blast, because nothing about this is sudden.
      for (var i = 0; i < 14; i++) {
        final a = i * 2 * pi / 14 + drop * 0.5;
        final d = 26 + 200 * drop * (0.5 + (i % 4) / 6);
        canvas.drawCircle(
          Offset(at.dx, at.dy + 30) + Offset(cos(a), sin(a) * 0.6) * d,
          1.5 + 3.0 * (1 - drop),
          Paint()..color = _venomSick.withValues(alpha: 0.7 * (1 - drop)),
        );
      }
    }
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        54 + 26 * drop,
        const Color(0xFF7A1F2E).withValues(alpha: 0.30 * t),
      );
    }
  }

  /// A SEALED WARD DOOR, in the vocabulary of a quarantine rather than a lock.
  ///
  /// These wore the engine's generic locked slab — the amber bar and rune
  /// that everywhere else in this game means *you need a key you do not
  /// have*. So a player walked up expecting a key hunt, pressed, and it
  /// simply opened, and the whole beat read as a pointless speed bump.
  /// Reported from play as "the doors don't require anything".
  ///
  /// They do. Breaking the wax is the moment the strain inside goes live, and
  /// choosing WHEN is the point. It just has to look like wax.
  void _renderWardSeals(Canvas canvas, DungeonRoom room) {
    final t = monastery.triage;
    for (final d in room.doors) {
      if (!d.chromeless) continue;
      final ward = layout.rooms[d.targetRoomId]?.ward;
      if (ward == null) continue;
      final r = d.rect;
      final sealed = !t.opened.contains(ward.id);
      final horizontal = r.width >= r.height;

      if (!sealed) {
        // OPEN: a dark mouth with the broken wax still on the jamb.
        canvas.drawRect(r, Paint()..color = const Color(0xFF07090A));
        canvas.drawRect(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFF3B3228),
        );
        for (var i = 0; i < 4; i++) {
          final along = (i + 0.5) / 4;
          final at = horizontal
              ? Offset(r.left + r.width * along, i.isEven ? r.top : r.bottom)
              : Offset(i.isEven ? r.left : r.right, r.top + r.height * along);
          canvas.drawCircle(
            at,
            2.6,
            Paint()..color = const Color(0xFF7A2E2E).withValues(alpha: 0.7),
          );
        }
        continue;
      }

      // SEALED. Boards across the opening, wax over the seam, and a cross
      // daubed on. The charnel is BRICK instead — the one hard gate here, and
      // it must not look like the three soft ones.
      if (ward.bricked) {
        canvas.drawRect(r, Paint()..color = const Color(0xFF2B211C));
        final course = horizontal ? r.height / 3 : r.width / 3;
        for (var i = 0; i < 3; i++) {
          final off = (i.isOdd ? 0.5 : 0.0);
          for (var k = -1; k < 5; k++) {
            final brick = horizontal
                ? Rect.fromLTWH(
                    r.left + (k + off) * 26,
                    r.top + i * course + 1,
                    24,
                    course - 2,
                  )
                : Rect.fromLTWH(
                    r.left + i * course + 1,
                    r.top + (k + off) * 26,
                    course - 2,
                    24,
                  );
            if (!brick.overlaps(r)) continue;
            canvas.save();
            canvas.clipRect(r);
            canvas.drawRect(
              brick,
              Paint()
                ..color = Color.lerp(
                  const Color(0xFF3E2F26),
                  const Color(0xFF32261F),
                  ((k * 7 + i * 3) % 5) / 5,
                )!,
            );
            canvas.restore();
          }
        }
        canvas.drawRect(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFF17110D),
        );
        continue;
      }

      // Boards.
      canvas.drawRect(r, Paint()..color = const Color(0xFF3A3025));
      final planks = horizontal ? 3 : 4;
      for (var i = 1; i < planks; i++) {
        final f = i / planks;
        canvas.drawLine(
          horizontal
              ? Offset(r.left, r.top + r.height * f)
              : Offset(r.left + r.width * f, r.top),
          horizontal
              ? Offset(r.right, r.top + r.height * f)
              : Offset(r.left + r.width * f, r.bottom),
          Paint()
            ..strokeWidth = 1.4
            ..color = const Color(0xFF241C14),
        );
      }
      // WAX, poured down the seam and stamped. This is the thing that says
      // "sealed against something" instead of "locked".
      final seam = horizontal
          ? Rect.fromLTWH(r.left - 3, r.center.dy - 6, r.width + 6, 12)
          : Rect.fromLTWH(r.center.dx - 6, r.top - 3, 12, r.height + 6);
      canvas.drawRect(seam, Paint()..color = const Color(0xFF6E2436));
      // Runs, where it was poured hot and set crooked.
      for (var i = 0; i < 5; i++) {
        final along = (i + 0.5) / 5;
        final drip = horizontal
            ? Rect.fromLTWH(
                r.left + r.width * along - 3,
                seam.bottom - 2,
                6,
                4 + (i % 3) * 4,
              )
            : Rect.fromLTWH(
                seam.right - 2,
                r.top + r.height * along - 3,
                4 + (i % 3) * 4,
                6,
              );
        canvas.drawRRect(
          RRect.fromRectAndRadius(drip, const Radius.circular(3)),
          Paint()..color = const Color(0xFF6E2436),
        );
      }
      // The stamp.
      final stamp = r.center;
      canvas.drawCircle(stamp, 8, Paint()..color = const Color(0xFF8A3044));
      canvas.drawCircle(
        stamp,
        8,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xFFC08A96).withValues(alpha: 0.7),
      );
      final cross = Paint()
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFE8DFC8).withValues(alpha: 0.85);
      canvas.drawLine(
        stamp + const Offset(0, -5),
        stamp + const Offset(0, 5),
        cross,
      );
      canvas.drawLine(
        stamp + const Offset(-5, -1),
        stamp + const Offset(5, -1),
        cross,
      );
    }
  }

  void _renderMonasteryFixtures(Canvas canvas, DungeonRoom room) {
    final t = monastery.triage;

    final still = room.apothecary;
    if (still != null) {
      // The cistern: a squat vessel with its level showing.
      final carrion = room.guardian != null;
      // THE CISTERN: a stone tank, iron-banded, with a sight-glass down its
      // face and a tap at the foot. It was a rounded rect with a green bar
      // in it — the bar was the only honest part, and even that read as a
      // progress meter rather than as liquid you are going to spend.
      final c = still.cistern;
      final tank = Rect.fromCenter(center: c, width: 66, height: 52);
      _stoneBlock(canvas, tank, radius: 4);
      for (final y in [tank.top + 11, tank.bottom - 11]) {
        canvas.drawRect(
          Rect.fromLTWH(tank.left - 3, y, tank.width + 6, 5),
          Paint()..color = _venomIron,
        );
        canvas.drawCircle(
          Offset(tank.left + 4, y + 2.5),
          1.8,
          Paint()..color = _venomBronzeLit.withValues(alpha: 0.8),
        );
        canvas.drawCircle(
          Offset(tank.right - 4, y + 2.5),
          1.8,
          Paint()..color = _venomBronzeLit.withValues(alpha: 0.8),
        );
      }
      // The sight-glass: a narrow tube where you actually read the level.
      final glass = Rect.fromLTWH(
        tank.right - 15,
        tank.top + 6,
        9,
        tank.height - 12,
      );
      canvas.drawRect(glass, Paint()..color = const Color(0xFF0B0F0B));
      if (!carrion) {
        final fill = (t.cistern / kMonasteryCistern).clamp(0.0, 1.0);
        canvas.drawRect(
          Rect.fromLTWH(
            glass.left + 1,
            glass.bottom - (glass.height - 2) * fill - 1,
            glass.width - 2,
            (glass.height - 2) * fill,
          ),
          Paint()..color = _venomLive.withValues(alpha: 0.85),
        );
        // …and the body of it behind the stone, so the tank reads as FULL
        // rather than as a gauge bolted to a box.
        canvas.drawRect(
          Rect.fromLTWH(
            tank.left + 6,
            tank.bottom - 8 - (tank.height - 20) * fill,
            tank.width - 26,
            (tank.height - 20) * fill,
          ),
          Paint()..color = _venomLive.withValues(alpha: 0.18),
        );
      }
      canvas.drawRect(
        glass,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = _venomBronze.withValues(alpha: 0.9),
      );
      // The tap.
      canvas.drawRect(
        Rect.fromLTWH(tank.left - 8, tank.bottom - 14, 10, 5),
        Paint()..color = _venomBronze,
      );
      canvas.drawCircle(
        Offset(tank.left - 10, tank.bottom - 11.5),
        4,
        Paint()..color = _venomBronzeLit,
      );
      for (final spout in still.spouts) {
        _renderSpout(canvas, spout);
      }
    }

    final ward = room.ward;
    if (ward != null) {
      final cured = t.cured.contains(ward.id);
      // THE CENSER: a pierced bronze bowl hung on three chains, smoking.
      // It was a circle with a ring round it, which is a token for a censer
      // rather than one — and this is the thing you burn a ward clean with,
      // so it has to look like it could.
      final cen = ward.censer;
      final swing = sin(_time * 1.1 + cen.dx * 0.01) * 3.0;
      final hang = Offset(cen.dx + swing, cen.dy);
      for (final dx in const [-9.0, 0.0, 9.0]) {
        canvas.drawLine(
          Offset(cen.dx + dx * 0.35, cen.dy - 54),
          Offset(hang.dx + dx, hang.dy - 10),
          Paint()
            ..strokeWidth = 1.3
            ..color = _venomIron.withValues(alpha: 0.9),
        );
      }
      // The bowl, and the lid that makes it a censer and not a cup.
      canvas.drawArc(
        Rect.fromCenter(center: hang, width: 30, height: 26),
        0,
        pi,
        true,
        Paint()..color = cured ? _venomBronzeLit : _venomBronze,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: hang - const Offset(0, 3),
          width: 28,
          height: 20,
        ),
        pi,
        pi,
        true,
        Paint()
          ..color = (cured ? _venomBronzeLit : _venomBronze).withValues(
            alpha: 0.85,
          ),
      );
      for (var i = -1; i <= 1; i++) {
        canvas.drawCircle(
          hang + Offset(i * 7.0, -7),
          1.6,
          Paint()..color = const Color(0xFF11140F),
        );
      }
      canvas.drawLine(
        hang + const Offset(-15, -1),
        hang + const Offset(15, -1),
        Paint()
          ..strokeWidth = 2
          ..color = _venomBone.withValues(alpha: 0.55),
      );
      // Smoke: sick and thin while the ward is live, clean and full once it
      // has been burned through.
      if (_fx.ready) {
        for (var i = 0; i < 4; i++) {
          final k = ((_time * (cured ? 0.34 : 0.20) + i / 4) % 1.0);
          drawPuff(
            canvas,
            _fx.puff!,
            hang + Offset(sin(k * 5 + i) * (5 + 9 * k), -12 - 46 * k),
            10 + 26 * k,
            (cured ? _venomBone : _venomLive).withValues(
              alpha: (cured ? 0.16 : 0.10) * (1 - k),
            ),
          );
        }
      }
      // The sacristy: a small door, sealed until the ward is clean.
      final taken = t.sacristiesTaken.contains(ward.id);
      // THE SACRISTY: an arched cupboard set in the wall, iron-banded and
      // barred while the ward is foul. Three readable states — barred, open
      // and holding something, emptied — where before all three were one
      // rounded rectangle in three colours.
      final sr = Rect.fromCenter(center: ward.sacristy, width: 38, height: 50);
      _stoneBlock(canvas, sr.inflate(5), radius: 6);
      final arch = Path()
        ..moveTo(sr.left, sr.bottom)
        ..lineTo(sr.left, sr.top + 12)
        ..arcToPoint(
          Offset(sr.right, sr.top + 12),
          radius: Radius.circular(sr.width / 2),
        )
        ..lineTo(sr.right, sr.bottom)
        ..close();
      canvas.drawPath(
        arch,
        Paint()
          ..color = cured && !taken
              ? const Color(0xFF1C2A1A)
              : const Color(0xFF0D110C),
      );
      if (!cured) {
        // BARRED. Iron across the mouth, and it is the bars that say "not
        // yet" rather than a colour you have to have seen before.
        for (var i = 0; i < 3; i++) {
          canvas.drawLine(
            Offset(sr.left + 3, sr.top + 16 + i * 12.0),
            Offset(sr.right - 3, sr.top + 16 + i * 12.0),
            Paint()
              ..strokeWidth = 3.4
              ..strokeCap = StrokeCap.round
              ..color = _venomIron,
          );
        }
      } else if (!taken) {
        // Open, and there is something in it.
        canvas.drawCircle(
          sr.center + const Offset(0, 4),
          8,
          Paint()..color = _venomBone.withValues(alpha: 0.9),
        );
        if (_fx.ready) {
          drawGlow(
            canvas,
            _fx.glow!,
            sr.center,
            28,
            _venomBone.withValues(alpha: 0.22),
          );
        }
      }
      canvas.drawPath(
        arch,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _venomBronze.withValues(alpha: cured ? 0.9 : 0.55),
      );
      if (ward.id == t.surrendered) {
        _renderOubliette(canvas, ward);
      }
    }

    final seal = room.priorsSeal;
    if (seal != null) {
      // The prior's seal: a lead cross on a stand, lit once it can be taken.
      final ready = t.canCommit && t.surrendered == null;
      // THE PRIOR'S SEAL: a lead cross on a stone plinth. Dull while there is
      // nothing to decide; lit, and worth walking to, the moment the choice
      // is actually in front of you — which is the whole of this planet's
      // signature move, so it had better not be two grey lines.
      final sp = seal.position;
      _stoneBlock(
        canvas,
        Rect.fromCenter(
          center: sp + const Offset(0, 34),
          width: 46,
          height: 18,
        ),
      );
      final p = Paint()
        ..color = (ready ? _venomBone : const Color(0xFF474C52)).withValues(
          alpha: 0.95,
        )
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.square;
      canvas.drawLine(sp + const Offset(0, -28), sp + const Offset(0, 26), p);
      canvas.drawLine(sp + const Offset(-18, -8), sp + const Offset(18, -8), p);
      // Cast lead is soft and it shows: a bevel down the upright.
      canvas.drawLine(
        sp + const Offset(-2, -26),
        sp + const Offset(-2, 24),
        Paint()
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: ready ? 0.22 : 0.10),
      );
      if (ready && _fx.ready) {
        final pulse = 0.5 + 0.5 * sin(_time * 2.2);
        drawGlow(
          canvas,
          _fx.glow!,
          sp,
          44 + 10 * pulse,
          _venomBone.withValues(alpha: 0.16 + 0.12 * pulse),
        );
      }
    }

    final wisp = monastery.wisp;
    if (wisp != null && room.id == 'ambulatory') {
      final t2 = 0.5 + 0.5 * sin(monastery.clock * 2.4);
      canvas.drawCircle(
        wisp,
        10 + 3 * t2,
        Paint()..color = _venomSick.withValues(alpha: 0.30),
      );
      canvas.drawCircle(wisp, 5, Paint()..color = _venomSick);
    }
  }

  /// THE FOUR DRAUGHTS, each one a piece of apothecary kit you could name
  /// with the labels off — which is the whole design: §5.6 says the pairing
  /// of draught to strain must be deducible from BEHAVIOUR, so the vessel is
  /// allowed to say what it does and never which sickness it answers.
  ///
  /// They were four flat purple shapes. Silhouette alone was carrying it, and
  /// two of the four (a dome and an oval) are nearly the same silhouette.
  void _renderSpout(Canvas canvas, ApothecarySpout spout) {
    final p = spout.position;
    final glass = Paint()
      ..color = const Color(0xFF2A3630).withValues(alpha: 0.85);
    switch (spout.draught) {
      case WardDraught.stilling:
        // THE STILLING BELL. A glass dome on a stone foot, and the air inside
        // it visibly DEAD — no motes, no drift, while the whole room outside
        // is full of them.
        _stoneBlock(
          canvas,
          Rect.fromCenter(center: p + const Offset(0, 4), width: 52, height: 9),
        );
        final dome = Rect.fromCenter(center: p, width: 46, height: 46);
        canvas.drawArc(dome, pi, pi, true, glass);
        canvas.drawArc(
          dome,
          pi,
          pi,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = _venomBone.withValues(alpha: 0.65),
        );
        // The highlight that makes it read as glass rather than as a lid.
        canvas.drawArc(
          Rect.fromCenter(
            center: p + const Offset(-6, 2),
            width: 26,
            height: 30,
          ),
          pi * 1.15,
          pi * 0.5,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..color = Colors.white.withValues(alpha: 0.16),
        );
        canvas.drawCircle(
          p + const Offset(0, -24),
          3.5,
          Paint()..color = _venomBone.withValues(alpha: 0.7),
        );
      case WardDraught.quicklime:
        // THE LIME KILN. A brick mouth with a white-hot throat and lime dust
        // banked at its foot.
        final mouth = Rect.fromCenter(center: p, width: 50, height: 40);
        _stoneBlock(canvas, mouth, radius: 3);
        final arch = Path()
          ..moveTo(mouth.left + 9, mouth.bottom - 3)
          ..lineTo(mouth.left + 9, mouth.center.dy)
          ..arcToPoint(
            Offset(mouth.right - 9, mouth.center.dy),
            radius: const Radius.circular(16),
          )
          ..lineTo(mouth.right - 9, mouth.bottom - 3)
          ..close();
        canvas.drawPath(arch, Paint()..color = const Color(0xFF0A0C09));
        canvas.drawCircle(
          p + const Offset(0, 6),
          8,
          Paint()..color = const Color(0xFFEDE7D2),
        );
        if (_fx.ready) {
          drawGlow(
            canvas,
            _fx.glow!,
            p + const Offset(0, 6),
            26,
            const Color(0xFFEDE7D2).withValues(alpha: 0.22),
          );
        }
        for (var i = 0; i < 7; i++) {
          canvas.drawCircle(
            Offset(mouth.left + 6 + i * 6.5, mouth.bottom + 2.0 + (i % 2)),
            1.6,
            Paint()..color = _venomBone.withValues(alpha: 0.5),
          );
        }
      case WardDraught.binding:
        // THE SMOKE POT. A bellied pot with a pierced lid, and smoke that
        // spreads SIDEWAYS along the ground — it fills the space between
        // things, which is exactly what it does to a strain.
        final pot = Rect.fromCenter(
          center: p + const Offset(0, 8),
          width: 44,
          height: 32,
        );
        canvas.drawOval(pot, Paint()..color = const Color(0xFF37302A));
        canvas.drawOval(
          Rect.fromCenter(
            center: pot.center - const Offset(0, 4),
            width: 40,
            height: 24,
          ),
          Paint()..color = const Color(0xFF241F1B),
        );
        canvas.drawOval(
          Rect.fromCenter(center: pot.topCenter, width: 30, height: 11),
          Paint()..color = _venomBronze,
        );
        for (var i = -1; i <= 1; i++) {
          canvas.drawCircle(
            pot.topCenter + Offset(i * 8.0, 0),
            1.7,
            Paint()..color = const Color(0xFF10130E),
          );
        }
        if (_fx.ready) {
          for (var i = 0; i < 3; i++) {
            final k = ((_time * 0.24 + i / 3) % 1.0);
            drawPuff(
              canvas,
              _fx.puff!,
              pot.topCenter + Offset((i - 1) * 26.0 * k, -6 - 10 * k),
              14 + 30 * k,
              _venomDeep.withValues(alpha: 0.16 * (1 - k)),
            );
          }
        }
      case WardDraught.rousing:
        // THE WAKE-BITTERS. A tall flask, and a clapper on a stand beside it
        // that is visibly STRUCK — the one draught that makes noise, for the
        // strain that plays dead.
        final flask = Rect.fromCenter(center: p, width: 24, height: 44);
        canvas.drawRRect(
          RRect.fromRectAndRadius(flask, const Radius.circular(11)),
          glass,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(flask.left + 3, flask.center.dy, flask.width - 6, 18),
            const Radius.circular(8),
          ),
          Paint()..color = _venomSick.withValues(alpha: 0.55),
        );
        canvas.drawRect(
          Rect.fromCenter(center: flask.topCenter, width: 10, height: 8),
          Paint()..color = _venomBronze,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(flask, const Radius.circular(11)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = _venomBone.withValues(alpha: 0.6),
        );
        final swing = sin(_time * 5.0) * 5;
        canvas.drawLine(
          p + const Offset(22, -26),
          p + Offset(22 + swing, -12),
          Paint()
            ..strokeWidth = 1.4
            ..color = _venomIron,
        );
        canvas.drawCircle(
          p + Offset(22 + swing, -10),
          5,
          Paint()..color = _venomBronzeLit,
        );
    }
  }

  void _renderOubliette(Canvas canvas, WardCell ward) {
    final open = monastery.oublietteOpen;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: ward.oubliette, width: 60, height: 50),
        const Radius.circular(6),
      ),
      Paint()..color = open ? const Color(0xFF120A18) : const Color(0xFF54463A),
    );
    if (!open) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: ward.oubliette, width: 60, height: 50),
          const Radius.circular(6),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = _venomBone.withValues(alpha: 0.55),
      );
    }
  }
}
