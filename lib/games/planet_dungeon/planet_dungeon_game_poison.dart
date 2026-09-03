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

  // ── THE CAULDRON ────────────────────────────────────────
  //
  // Six hands' worth of contribution against six slots. Forced with the
  // ideal trio, which is why the interesting question is not who gives but
  // WHEN: a contributor is drained until the plague it woke is down.

  /// instanceId → how many brews this alchemon has given to.
  final Map<String, int> given = {};

  /// What is in the pot right now, in the order it went in.
  final List<String> pot = [];

  /// A finished potion in hand, by [PlaguePotion.id].
  String? carriedPotion;

  /// Plagues woken and not yet killed — they wait in the ambulatory.
  final Set<String> woken = {};

  /// Plagues put down for good.
  final Set<String> slain = {};

  /// instanceId → drained until the next plague falls.
  final Set<String> drained = {};

  /// A plague woken and still crawling — it lands when the crawl ends.
  String? pendingFight;

  /// The plague currently loose in the cloister, being fought.
  String? fighting;

  /// The hands currently standing over the pot, in order given.
  final List<String> potHands = [];

  /// potionId → the two hands that made it. They are what the waking spends.
  final Map<String, List<String>> potionHands = {};

  /// Whether the cauldron has explained itself yet this run.
  bool cauldronTold = false;

  /// Wards whose board has been read out, so it is said once each.
  final Set<String> symptomTold = {};

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
    m.given.clear();
    m.pot.clear();
    m.carriedPotion = null;
    m.woken.clear();
    m.slain.clear();
    m.drained.clear();
    m.potHands.clear();
    m.potionHands.clear();
    m.pendingFight = null;
    m.fighting = null;
    m.cauldronTold = false;
    m.symptomTold.clear();
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
      // A plague that has drunk its brew has LEFT. The ward it came out of
      // has to be empty afterwards or the crawl into the walk is a lie.
      for (final p in kPlaguePotions) {
        if (p.wardId != ward.id) continue;
        if (monastery.woken.contains(p.id) || monastery.slain.contains(p.id)) {
          return const [];
        }
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
      if (monastery.invade >= 1) {
        monastery.invading = false;
        final pending = monastery.pendingFight;
        if (pending != null) {
          monastery.pendingFight = null;
          _plagueLands(pending);
        }
      }
    }
    _maybeWakeWard(room);
    _tellTheHouse(room);
    _tickPlagueFight();
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
      speakConsequence(
        'The sacristy opens — the ward\'s own physic mends you',
        3.2,
      );
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
        speakConsequence('Blightfang sheds the strain and takes another', 2.8);
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
      speakConsequence(
        'The dose bites — patient zero reels into the lull',
        3.2,
      );
      _spawnAlchemyBurst(
        _guardianPosition(g),
        producedElement: 'Poison',
        reagentElements: const ['Plant', 'Mud'],
        particleCount: 26,
        intensity: 1.2,
      );
    } else {
      // It FEEDS — the planet's own rule, turned on the player.
      final e = _guardianEnemy;
      if (e != null && !e.isDead) {
        e.hp = min(e.maxHp.toDouble(), e.hp + e.maxHp * _kBlightFeedHeal);
      }
      speakConsequence('Wrong physic — Blightfang drinks it and swells', 3.4);
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
        speakConsequence(
          'The wax softens and runs — the lazaret stands open',
          3.4,
        );
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

    // 2) THE CAULDRON. Before the old still, because in the infirmary the pot
    //    IS the still now — the four-tap draught rack survives only in the
    //    crypt, where the carrion font wears the same shape.
    if (room.apothecary != null && room.guardian == null) {
      if (_tryCauldron(a, room)) return true;
    }

    // 2b) The crypt's carrion font: draw a draught.
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
      return _readTheRoll(seal);
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
            ? 'Roots go through the joints and the brick comes apart. '
                  'Something in the dead-house has been waiting.'
            : 'The seal parts, and what is in there wakes.',
        3.6,
      );
      _spawnAlchemyBurst(
        door.rect.center,
        producedElement: 'Poison',
        reagentElements: ward.bricked ? const ['Plant'] : const [],
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
    // The braid follows the larder: the house's own three, minus Poison.
    if (e != 'Plant' && e != 'Mud') return false;
    final want = e == 'Plant' ? 'Mud' : 'Plant';
    return creatures.any(
      (c) => c.alive && !identical(c, a) && c.member.element == want,
    );
  }

  /// STAND AT THE POT AND GIVE. Two matching elements make a potion.
  ///
  /// The whole rule, and the room says it out loud the first time you walk in
  /// because it is an arithmetic constraint rather than a discovery: an
  /// alchemon can give to TWO brews. Three of them, three brews of two — the
  /// slots and the hands come out exactly even, so the question the player is
  /// really answering is not *who* but *when*, because giving DRAINS you
  /// until the plague you woke is down.
  bool _tryCauldron(DungeonCreature a, DungeonRoom room) {
    final still = room.apothecary;
    if (still == null) return false;
    if ((a.position - still.cistern).distance > _kMonasteryReach + 14) {
      return false;
    }
    final m = monastery;
    final el = a.member.element;
    final id = a.member.instanceId;

    if (m.carriedPotion != null) {
      _setBlockedHint('A hand already carries a brew');
      return true;
    }
    if ((m.given[id] ?? 0) >= kPotionContributionsEach) {
      _setBlockedHint(
        '${a.member.displayName} has given to two brews — that is all any '
        'one of them has in it',
      );
      return true;
    }
    if (!kPotionIngredientEffect.containsKey(el)) {
      _setBlockedHint('The pot takes Poison, Plant or Mud. $el is neither.');
      return true;
    }
    if (m.pot.contains(el)) {
      _setBlockedHint(
        'That is already in the pot — a brew wants two DIFFERENT',
      );
      return true;
    }

    m.pot.add(el);
    m.potHands.add(id);
    m.given[id] = (m.given[id] ?? 0) + 1;
    _spawnAlchemyBurst(
      still.cistern,
      producedElement: el,
      particleCount: 16,
      intensity: 0.8,
    );

    if (m.pot.length < 2) {
      speakConsequence(
        '${a.member.displayName} gives to the pot. ${_capitalisePoison(el)} '
        '${kPotionIngredientEffect[el]}.',
        3.6,
      );
      return true;
    }

    // Two in: it either makes something or it does not.
    final made = kPlaguePotions.where(
      (p) => p.takes(m.pot[0]) && p.takes(m.pot[1]),
    );
    if (made.isEmpty) {
      m.pot.clear();
      m.potHands.clear();
      speakConsequence(
        'They fight in the pot and go to nothing. Both hands are spent for '
        'it.',
        4.2,
      );
      _spawnAlchemyBurst(
        still.cistern,
        producedElement: 'Poison',
        unstable: true,
        particleCount: 22,
        intensity: 1.0,
      );
      return true;
    }
    final potion = made.first;
    m.pot.clear();
    m.potionHands[potion.id] = List<String>.from(m.potHands);
    m.potHands.clear();
    m.carriedPotion = potion.id;
    speakConsequence('The pot settles into ${potion.name}.', 4.0);
    _spawnAlchemyBurst(
      still.cistern,
      producedElement: 'Light',
      reagentElements: const ['Poison'],
      particleCount: 26,
      intensity: 1.1,
    );
    return true;
  }

  String _capitalisePoison(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// HOW MUCH OF AN ALCHEMON IS LEFT. A hand that gave to a brew is spent
  /// until the plague that brew woke is down: it hits softer and it moves
  /// slower, and it is the only reason the order you brew in matters.
  ///
  /// Deliberately a TAX, never a lockout. Brew all three before waking
  /// anything and all three of them are spent at once — which is a bad fight
  /// and a lesson, not a dead run.
  double venomDrainMul(DungeonCreature? a) {
    if (a == null) return 1.0;
    return monastery.drained.contains(a.member.instanceId)
        ? _kVenomDrainMul
        : 1.0;
  }

  /// GIVE THE BREW TO THE PLAGUE. It wakes, it comes out into the walk, and
  /// then it is a fight — which is the whole shape of this planet now.
  bool _tryWakePlague(PlaguePotion potion, WardCell ward) {
    final m = monastery;
    if (m.slain.contains(potion.id)) {
      _setBlockedHint('This one is already down');
      return true;
    }
    if (m.woken.contains(potion.id)) {
      _setBlockedHint('It is awake and out in the walk — go and finish it');
      return true;
    }
    final held = m.carriedPotion;
    if (held == null) {
      _setBlockedHint('Nothing in hand. The pot in the apothecary makes it.');
      return true;
    }
    if (held != potion.id) {
      final wrong = kPlaguePotions.firstWhere((p) => p.id == held);
      // Not spent — a brew carried to the wrong door is a walk, not a
      // failure. The scarce thing on this planet is HANDS, and none were
      // used here.
      _setBlockedHint(
        'It shrugs off ${wrong.name} — that was mixed for another door',
      );
      return true;
    }

    m.carriedPotion = null;
    m.woken.add(potion.id);
    m.drained.addAll(m.potionHands[potion.id] ?? const <String>[]);
    speakConsequence(
      'It drinks ${potion.name} and comes awake. It is going out into the '
      'walk — and the hands that mixed it have nothing left in them until '
      'it falls.',
      5.0,
    );
    _plagueEntersTheWalk(ward.id, sick: false);
    m.pendingFight = potion.id;
    return true;
  }

  /// The plague lands in the cloister at the end of its crawl. Spawned here
  /// rather than at the press so the thing you fight is the thing you just
  /// watched arrive.
  void _plagueLands(String potionId) {
    final walk = layout.rooms['ambulatory'];
    if (walk == null) return;
    final at = monastery.invadeTo;
    spawnDungeonEnemy(
      tier: EnemyTier.brute,
      conduct: EnemyConduct.charge,
      element: 'Poison',
      from: at,
      hp: 190,
      speed: 58,
      damage: 15,
      radius: 22,
      steers: true,
    );
    for (var i = 0; i < 3; i++) {
      spawnDungeonEnemy(
        tier: EnemyTier.wisp,
        conduct: EnemyConduct.stalk,
        element: 'Poison',
        from: at,
        hp: 26,
        speed: 84,
        damage: 7,
        radius: 10,
      );
    }
    monastery.fighting = potionId;
  }

  /// The fight is over when nothing of it is left standing in the walk.
  void _tickPlagueFight() {
    final m = monastery;
    final id = m.fighting;
    if (id == null) return;
    if (currentRoomId != 'ambulatory') return;
    final live = combatEnemies.where((e) => !e.isDead).length;
    if (live > 0) return;
    m.fighting = null;
    m.woken.remove(id);
    m.slain.add(id);
    // The hands come back. All of them — a fallen plague clears the whole
    // house's exhaustion, so brewing the next one is a fresh decision.
    m.drained.clear();
    final potion = kPlaguePotions.firstWhere((p) => p.id == id);
    if (m.slain.length >= kPlaguePotions.length) {
      speakConsequence(
        'The last of the three goes down. The lazaret is quiet for the first '
        'time in a long while.',
        5.0,
      );
      final seal = layout.rooms['ambulatory']?.priorsSeal;
      if (seal != null) {
        if (!hasStar(seal.diagnosisStarIndex)) {
          earnStar(seal.diagnosisStarIndex);
        }
        if (!hasStar(seal.triageStarIndex)) earnStar(seal.triageStarIndex);
      }
    } else {
      final left = kPlaguePotions.length - m.slain.length;
      speakConsequence(
        'It comes apart. ${_capitalisePoison(potion.name)} is done with — '
        '$left still sleeping, and every hand is rested.',
        4.4,
      );
    }
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
        // NAME THE OTHER WAY. "Only Poison" reads as impossible to a party
        // that has none — the same refusal Steam's accumulator and Lava's
        // die both used to give. The braid is what it actually wants.
        _setBlockedHint(
          'The font answers only Poison — or a Plant and a Mud heart '
          'standing at it together',
        );
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
        // Not a refusal you can fix — it is the planet's whole thesis
        // arriving — so it is spoken, not remembered.
        speakConsequence(
          'The cistern is dry. There was never physic for a fourth ward.',
          4.2,
        );
        return true;
      }
      final braid = a.member.element != 'Poison';
      // SAY IT. This was `_setHint`, which for unasked world speech is
      // DROPPED — so drawing a draught printed nothing, showed nothing, and
      // put an invisible phial in an invisible hand. Reported from play as
      // "it doesn't seem like I'm interacting with anything".
      speakConsequence(
        '${draughtFixtureName(spout.draught)} fills the phial'
        '${braid ? ' — and the braid roars; something heard that' : ''}.',
        3.4,
      );
      _spawnAlchemyBurst(
        spout.position,
        producedElement: 'Poison',
        reagentElements: braid ? const ['Plant', 'Mud'] : const [],
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
    // A plague ward wants a BREW, not a phial — the old draught rack lives
    // on only in the crypt.
    for (final p in kPlaguePotions) {
      if (p.wardId == ward.id) return _tryWakePlague(p, ward);
    }
    final outcome = m.triage.dose(ward.id);
    switch (outcome) {
      case DoseOutcome.noPhial:
        _setBlockedHint('Nothing in hand to give');
      case DoseOutcome.sealed:
        _setBlockedHint('The ward is still shut');
      case DoseOutcome.settled:
        _setBlockedHint('This ward is settled — nothing here to physic');
      case DoseOutcome.cured:
        speakConsequence('The strain lets go — ${ward.name} is clean.', 3.8);
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

  /// THE PRIOR'S ROLL. It used to commit a triage and hand out both stars;
  /// the plagues do that now, so what is left is the tally — which is worth
  /// keeping, because three plagues in three wards is exactly the kind of
  /// thing a player loses count of.
  bool _readTheRoll(PriorsSeal seal) {
    final m = monastery;
    final down = kPlaguePotions.where((p) => m.slain.contains(p.id)).length;
    final awake = kPlaguePotions.where((p) => m.woken.contains(p.id)).toList();
    if (awake.isNotEmpty) {
      speakConsequence(
        'The roll is open at one name and the ink is still wet. '
        '${_capitalisePoison(awake.first.name)} woke something, and it is in '
        'the walk with you.',
        4.6,
      );
      return true;
    }
    if (down >= kPlaguePotions.length) {
      speakConsequence('Three struck through. The house owes nothing.', 4.0);
      return true;
    }
    final left = kPlaguePotions
        .where((p) => !m.slain.contains(p.id))
        .map((p) => p.name)
        .join(', ');
    speakConsequence(
      '$down of ${kPlaguePotions.length} struck through. Still on the roll: '
      '$left.',
      5.0,
    );
    return true;
  }

  bool _tryOubliette(DungeonCreature a, WardCell ward) {
    final m = monastery;
    if (ward.id != kCryptWard || m.oublietteOpen) return false;
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
    speakConsequence(
      'The lead runs off the stone — Blightfang stirs in the dark below',
      4.2,
    );
    _spawnAlchemyBurst(
      ward.oubliette,
      producedElement: 'Poison',
      reagentElements: const ['Plant', 'Mud'],
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
      speakConsequence(
        'The sick wisp shies from the phial — wrong physic',
        3.2,
      );
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
    speakConsequence('The wisp drinks, and quietens', 4.0);
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

  /// The oubliette exists only in the dead-house, and only once its lead
  /// seal is dissolved (§5.5 vault trick — the way down is a consequence of
  /// the three plagues, never a door you could have used before).
  bool _monasteryDoorHidden(DungeonRoom room, DungeonDoor door) {
    if (!_isVenom) return false;
    if (door.targetRoomId == 'lazar_crypt') {
      return room.ward?.id != kCryptWard || !monastery.oublietteOpen;
    }
    if (room.id == 'lazar_crypt') {
      return door.targetRoomId != kCryptWard;
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
      final entry = kPlaguePotions.where((p) => p.wardId == ward.id);
      if (entry.isNotEmpty) {
        final potion = entry.first;
        if (monastery.slain.contains(potion.id)) {
          _setInsightHint('Nothing left in here to read');
          return;
        }
        if (monastery.woken.contains(potion.id)) {
          _setInsightHint('It is not in here any more. It is in the walk.');
          return;
        }
        // The board already names the pair. What the reading adds is WHY —
        // and, at the top tier, who is still fit to mix it.
        _setInsightHint(switch (revealTier) {
          0 => potion.symptom,
          1 =>
            '${potion.symptom} ${_capitalisePoison(potion.first)} '
                '${kPotionIngredientEffect[potion.first]}; '
                '${potion.second.toLowerCase()} '
                '${kPotionIngredientEffect[potion.second]}.',
          _ => _whoIsLeftFor(potion),
        });
        return;
      }
      if (!t.opened.contains(ward.id)) {
        _setInsightHint('The wax hides whatever walks in there');
        return;
      }
      final s = t.strainOf(ward.id);
      if (s == null) {
        _setInsightHint('Nothing left in here to read');
        return;
      }
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
      if (room.guardian == null) {
        final spent = <String>[
          for (final c in creatures)
            if ((monastery.given[c.member.instanceId] ?? 0) >=
                kPotionContributionsEach)
              c.member.displayName,
        ];
        _setInsightHint(switch (revealTier) {
          0 => 'The pot takes two and makes one',
          1 =>
            'Three jars, three plagues, and two brews in every alchemon — '
                'the sums come out exactly even, so the question is ORDER',
          _ when spent.isEmpty =>
            'Nothing is spent yet. Wake one plague at a time: whoever mixes '
                'the brew is worth little in the fight that follows it.',
          _ => 'Spent already: ${spent.join(', ')}',
        });
        return;
      }
      _setInsightHint(
        revealTier < 1
            ? 'Four taps, four different physics'
            : 'A bell that damps, a kiln that burns off, a pot that fills a '
                  'gap, bitters that will not let a thing lie',
      );
      return;
    }

    if (room.id == 'ambulatory') {
      final awake = kPlaguePotions
          .where((p) => monastery.woken.contains(p.id))
          .toList();
      if (awake.isNotEmpty) {
        _setInsightHint(
          '${_capitalisePoison(awake.first.name)} woke something and it came '
          'out here. Nothing else in the house moves until it is down.',
        );
        return;
      }
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

  /// Who can still give to [potion], for the top tier of the reading. The
  /// only thing the house genuinely knows that the player might have lost
  /// track of — and it is bookkeeping, not method.
  String _whoIsLeftFor(PlaguePotion potion) {
    final fit = <String>[];
    for (final c in creatures) {
      if (!potion.takes(c.member.element)) continue;
      if ((monastery.given[c.member.instanceId] ?? 0) >=
          kPotionContributionsEach) {
        continue;
      }
      fit.add(c.member.displayName);
    }
    if (fit.isEmpty) {
      return '${_capitalisePoison(potion.name)} wants ${potion.first} and '
          '${potion.second}, and no hand here has a give left in it.';
    }
    return '${_capitalisePoison(potion.name)}: ${potion.first} and '
        '${potion.second}. Still able to give — ${fit.join(', ')}.';
  }

  /// PROGRESS READOUT (§5.6) — state leaves the capsule.
  DungeonProgressReadout? get _monasteryProgressReadout {
    final t = monastery.triage;
    if (t.isEmpty) return null;
    final m = monastery;
    final held = m.carriedPotion;
    if (held != null) {
      return DungeonProgressReadout(
        label: 'BREW',
        value: kPlaguePotions.firstWhere((p) => p.id == held).name,
      );
    }
    if (m.pot.isNotEmpty) {
      return DungeonProgressReadout(label: 'POT', value: m.pot.join(' + '));
    }
    final phial = t.carried;
    if (phial != null) {
      return DungeonProgressReadout(
        label: 'PHIAL',
        value: draughtFixtureName(phial),
      );
    }
    final n = kPlaguePotions.length;
    return DungeonProgressReadout(
      label: 'PLAGUES',
      value: '${m.slain.length}/$n down',
      fraction: (m.slain.length / n).clamp(0.0, 1.0),
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
    _renderCarriedPhial(canvas);
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

  /// What a spent hand is worth — both its damage and its walk.
  static const double _kVenomDrainMul = 0.55;

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

  /// THE PHIAL IN HAND. Drawn on whoever is carrying it, every frame.
  ///
  /// Drawing a draught set a field and changed nothing anybody could see:
  /// no phial, and a success line that the hint system drops unasked. You
  /// pressed at a still and the room did not react, which is the whole of
  /// "it doesn't seem like I'm interacting with anything".
  void _renderCarriedPhial(Canvas canvas) {
    final d = monastery.triage.carried;
    if (d == null) return;
    final a = active;
    if (a == null || !a.alive) return;
    final at = a.position + Offset(15, -30 + sin(_time * 3.0) * 2.0);
    // Coloured by the draught, matching the vessel it came out of, so what
    // is in your hand and what you took it from are the same thing.
    final tint = switch (d) {
      WardDraught.stilling => const Color(0xFFBFD8D0),
      WardDraught.quicklime => const Color(0xFFEDE7D2),
      WardDraught.binding => const Color(0xFF6E5A46),
      WardDraught.rousing => _venomSick,
    };

    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(sin(_time * 1.4) * 0.10);
    // Glass, liquid, stopper — small, but a phial and not a dot.
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-6, -9, 12, 20),
      const Radius.circular(5),
    );
    canvas.drawRRect(
      body,
      Paint()..color = const Color(0xFF20302C).withValues(alpha: 0.9),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-4.5, -1, 9, 10.5),
        const Radius.circular(4),
      ),
      Paint()..color = tint.withValues(alpha: 0.9),
    );
    canvas.drawRect(
      const Rect.fromLTWH(-3.5, -13, 7, 5),
      Paint()..color = _venomBronze,
    );
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _venomBone.withValues(alpha: 0.65),
    );
    canvas.restore();
    if (_fx.ready) {
      drawGlow(canvas, _fx.glow!, at, 22, tint.withValues(alpha: 0.28));
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

  /// THE TWO THINGS THE HOUSE SAYS OUT LOUD.
  ///
  /// §5.6 keeps method off the walls, and both of these stay the right side
  /// of it. The cauldron states an ARITHMETIC CONSTRAINT — two brews each —
  /// which is not a method and cannot be discovered by looking at a pot; a
  /// rule the player must plan against has to be known before they plan. And
  /// a ward's board states a SYMPTOM, never a recipe: what is wrong in there,
  /// so that the cauldron's own list of what each ingredient DOES turns into
  /// a deduction rather than a lookup.
  void _tellTheHouse(DungeonRoom room) {
    final m = monastery;
    if (room.apothecary != null && room.guardian == null && !m.cauldronTold) {
      m.cauldronTold = true;
      speakConsequence(
        'The pot takes two things and makes one. Any alchemon has two brews '
        'in it and no more — three of them, three brews, and nothing spare.',
        6.5,
      );
      return;
    }
    final ward = room.ward;
    if (ward == null) return;
    final potion = kPlaguePotions.where((p) => p.wardId == room.id);
    if (potion.isEmpty) return;
    if (!m.triage.opened.contains(ward.id)) return;
    if (m.woken.contains(potion.first.id) ||
        m.slain.contains(potion.first.id)) {
      return;
    }
    if (!m.symptomTold.add(potion.first.id)) return;
    speakConsequence(potion.first.symptom, 5.5);
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
    // Standing in it counts. The seal at the door is ceremony, not a lock,
    // and the room must never depend on having pressed it.
    m.triage.open(ward.id);
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
      if (!carrion) {
        // THE POT. In the infirmary the still is gone and this is a cauldron
        // over a fire: you give two things to it and it makes one.
        _renderLarder(canvas, room);
        _renderCauldron(canvas, c);
      }
      if (carrion) {
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
    }

    final ward = room.ward;
    if (ward != null) {
      _renderWardBoard(canvas, ward);
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

  /// THE BOARD OVER THE DOOR. The house nailed up what this ward needs, and
  /// it is a RECIPE, not a method: two ingredients, plainly named. The
  /// reasoning the player does is at the pot — which hands can still give,
  /// and whether waking this one now is a fight they can take.
  void _renderWardBoard(Canvas canvas, WardCell ward) {
    final entry = kPlaguePotions.where((p) => p.wardId == ward.id);
    if (entry.isEmpty) return;
    final potion = entry.first;
    final done = monastery.slain.contains(potion.id);
    final at = Offset(ward.censer.dx, ward.censer.dy - 78);

    final recipe =
        '${potion.first.toUpperCase()} + '
        '${potion.second.toUpperCase()}';
    final under = done ? 'ANSWERED' : potion.name.toUpperCase();
    // MEASURE, THEN CUT THE PLANK. A fixed 128px board with a 21-character
    // brew name on it hangs the words off both ends — the first thing the
    // render showed.
    final w = max(_tinyLabelWidth(recipe), _tinyLabelWidth(under)) + 22;

    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(0.025);
    final plank = Rect.fromCenter(center: Offset.zero, width: w, height: 44);
    canvas.drawRRect(
      RRect.fromRectAndRadius(plank, const Radius.circular(3)),
      Paint()..color = const Color(0xFF2A2419),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(plank, const Radius.circular(3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = _venomBronze.withValues(alpha: done ? 0.35 : 0.9),
    );
    for (final dx in [-w / 2 + 8, w / 2 - 8]) {
      canvas.drawCircle(
        Offset(dx, -15),
        1.7,
        Paint()..color = _venomBronzeLit.withValues(alpha: 0.8),
      );
    }
    canvas.restore();

    // Two nails and a chain up to the lintel, so it hangs rather than floats.
    for (final dx in [-w / 2 + 8, w / 2 - 8]) {
      canvas.drawLine(
        Offset(at.dx + dx, at.dy - 34),
        Offset(at.dx + dx, at.dy - 15),
        Paint()
          ..strokeWidth = 1.2
          ..color = _venomIron.withValues(alpha: 0.85),
      );
    }

    _drawTinyLabel(canvas, Offset(at.dx, at.dy - 15), recipe);
    _drawTinyLabel(canvas, Offset(at.dx, at.dy + 2), under);
  }

  /// THE LARDER SHELF. Three jars on a rack, one per thing the pot drinks,
  /// each labelled with what it DOES rather than what it is.
  ///
  /// Two jobs. It fills a room that had four taps taken out of it and was
  /// left as one pot in a big dark box. And it is the other half of the
  /// deduction: the ward's board names the ingredients, and this names their
  /// effects — so a player who has read both knows not just WHAT to mix but
  /// WHY that pair answers that plague. Neither surface states a method.
  void _renderLarder(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final y = b.top + 78;
    final els = kPotionIngredientEffect.keys.toList();
    // The rack, running under all three.
    final x0 = b.center.dx - 250;
    final x1 = b.center.dx + 250;
    canvas.drawRect(
      Rect.fromLTWH(x0, y + 26, x1 - x0, 7),
      Paint()..color = const Color(0xFF2A2419),
    );
    canvas.drawRect(
      Rect.fromLTWH(x0, y + 26, x1 - x0, 2),
      Paint()..color = _venomBronze.withValues(alpha: 0.55),
    );
    for (var i = 0; i < els.length; i++) {
      final el = els[i];
      final spent = _larderSpent(el);
      final x = x0 + 60 + (x1 - x0 - 120) * (els.length == 1 ? 0.5 : i / 2);
      final at = Offset(x, y);
      final col = _elementBrewColour(el);
      // A stoppered jar, filled to the level of what the house has left in
      // hands rather than in glass: two gives per alchemon, and the jar
      // empties as they are spent.
      final jar = Rect.fromCenter(center: at, width: 26, height: 34);
      canvas.drawRRect(
        RRect.fromRectAndRadius(jar, const Radius.circular(4)),
        Paint()..color = const Color(0xFF0B0F0B),
      );
      final fill = (1.0 - spent).clamp(0.0, 1.0);
      if (fill > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              jar.left + 2,
              jar.bottom - 2 - (jar.height - 4) * fill,
              jar.width - 4,
              (jar.height - 4) * fill,
            ),
            const Radius.circular(3),
          ),
          Paint()..color = col.withValues(alpha: 0.85),
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(jar, const Radius.circular(4)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _venomBronze.withValues(alpha: fill > 0 ? 0.9 : 0.4),
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(at.dx, jar.top - 3),
          width: 12,
          height: 6,
        ),
        Paint()..color = _venomBronzeLit.withValues(alpha: 0.85),
      );
      _drawTinyLabel(canvas, Offset(at.dx, jar.top - 26), el.toUpperCase());
      _drawTinyLabel(
        canvas,
        Offset(at.dx, jar.bottom + 12),
        _larderVerb(el).toUpperCase(),
      );
    }
  }

  /// The single word off the front of the ingredient's line — the label has
  /// to fit on a jar, and the sentence is what the pot says out loud.
  String _larderVerb(String element) {
    final line = kPotionIngredientEffect[element] ?? '';
    final cut = line.indexOf(' ');
    return cut <= 0 ? line : line.substring(0, cut);
  }

  /// How much of this element the party has already poured away, 0 → 1.
  double _larderSpent(String element) {
    var have = 0, used = 0;
    for (final c in creatures) {
      if (c.member.element != element) continue;
      have += kPotionContributionsEach;
      used += min(
        kPotionContributionsEach,
        monastery.given[c.member.instanceId] ?? 0,
      );
    }
    if (have == 0) return 1.0;
    return used / have;
  }

  /// THE CAULDRON, and what is standing in it.
  ///
  /// The pot has to answer the hand — one contribution has to be visible as
  /// a change in the pot, or giving reads as pressing a button at a prop.
  /// So: the brew's colour is the elements in it, the surface lifts a ring
  /// per ingredient, and a finished brew sits on the rim as a stoppered
  /// flask until a hand carries it out.
  void _renderCauldron(Canvas canvas, Offset c) {
    final m = monastery;
    // The fire under it.
    final coals = Rect.fromCenter(
      center: Offset(c.dx, c.dy + 27),
      width: 62,
      height: 16,
    );
    canvas.drawOval(coals, Paint()..color = const Color(0xFF160C08));
    for (var i = 0; i < 7; i++) {
      final f = (i * 0.1737 + _time * 0.21) % 1.0;
      final x = coals.left + 7 + (coals.width - 14) * ((i * 0.19 + 0.11) % 1.0);
      canvas.drawCircle(
        Offset(x, coals.center.dy + sin(_time * 2.4 + i) * 1.4),
        2.2 + 1.1 * sin(_time * 3.1 + i * 1.7),
        Paint()
          ..color = Color.lerp(
            const Color(0xFFB4451C),
            const Color(0xFFF2A63A),
            f,
          )!.withValues(alpha: 0.72),
      );
    }
    // Three iron legs.
    for (final dx in const [-19.0, 0.0, 19.0]) {
      canvas.drawLine(
        Offset(c.dx + dx * 0.72, c.dy + 14),
        Offset(c.dx + dx, c.dy + 27),
        Paint()
          ..strokeWidth = 3.4
          ..color = _venomIron,
      );
    }
    // The belly: wider at the shoulder than the foot.
    final belly = Path()
      ..moveTo(c.dx - 36, c.dy - 12)
      ..cubicTo(c.dx - 40, c.dy + 16, c.dx - 22, c.dy + 22, c.dx, c.dy + 22)
      ..cubicTo(
        c.dx + 22,
        c.dy + 22,
        c.dx + 40,
        c.dy + 16,
        c.dx + 36,
        c.dy - 12,
      )
      ..close();
    canvas.drawPath(belly, Paint()..color = const Color(0xFF1B1E1A));
    canvas.drawPath(
      belly,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = _venomIron,
    );

    // What is in it. Empty pot reads dark; each ingredient tints and raises.
    final pot = m.pot;
    final mouth = Rect.fromCenter(
      center: Offset(c.dx, c.dy - 12),
      width: 72,
      height: 20,
    );
    canvas.drawOval(mouth, Paint()..color = const Color(0xFF090C09));
    if (pot.isNotEmpty) {
      Color brew = _elementBrewColour(pot.first);
      for (var i = 1; i < pot.length; i++) {
        brew = Color.lerp(brew, _elementBrewColour(pot[i]), 0.5)!;
      }
      final lift = 2.0 + 3.0 * pot.length;
      final surf = Rect.fromCenter(
        center: Offset(c.dx, c.dy - 12 - lift * 0.4),
        width: mouth.width - 8,
        height: mouth.height - 6,
      );
      canvas.drawOval(surf, Paint()..color = brew.withValues(alpha: 0.9));
      // Roll: two rings turning over, so a full pot is never still.
      for (var i = 0; i < 2; i++) {
        final k = ((_time * 0.55 + i * 0.5) % 1.0);
        canvas.drawOval(
          Rect.fromCenter(
            center: surf.center,
            width: surf.width * (0.2 + 0.72 * k),
            height: surf.height * (0.2 + 0.72 * k),
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Colors.white.withValues(alpha: 0.20 * (1 - k)),
        );
      }
      // Steam off a working pot.
      for (var i = 0; i < 3 + pot.length; i++) {
        final k = ((_time * 0.34 + i * 0.29) % 1.0);
        canvas.drawCircle(
          Offset(
            c.dx + sin(_time * 0.9 + i * 2.1) * (5 + 9 * k),
            c.dy - 18 - 34 * k,
          ),
          2.4 + 5.0 * k,
          Paint()..color = brew.withValues(alpha: 0.20 * (1 - k)),
        );
      }
    }
    canvas.drawOval(
      mouth,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = _venomBronze,
    );

    // A finished brew waits on the rim until somebody picks it up.
    final made = m.carriedPotion;
    if (made != null) {
      final potion = kPlaguePotions.firstWhere((p) => p.id == made);
      final at = Offset(c.dx + 44, c.dy - 6 + sin(_time * 2.0) * 1.6);
      final col = Color.lerp(
        _elementBrewColour(potion.first),
        _elementBrewColour(potion.second),
        0.5,
      )!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: at, width: 11, height: 16),
          const Radius.circular(3),
        ),
        Paint()..color = col,
      );
      canvas.drawRect(
        Rect.fromCenter(center: Offset(at.dx, at.dy - 11), width: 5, height: 6),
        Paint()..color = _venomBronzeLit,
      );
      canvas.drawCircle(
        at,
        13 + 3 * sin(_time * 2.6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = col.withValues(alpha: 0.34),
      );
    }
  }

  Color _elementBrewColour(String element) => switch (element) {
    'Poison' => const Color(0xFF6FBF3A),
    'Plant' => const Color(0xFF2E8B4A),
    'Mud' => const Color(0xFF8A6A3C),
    _ => const Color(0xFF7A7A7A),
  };

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
