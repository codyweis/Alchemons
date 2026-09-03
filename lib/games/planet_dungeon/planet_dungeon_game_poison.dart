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
      _setHint(
        ward.bricked
            ? 'The brick blows in — something in the dead-house wakes'
            : 'The seal parts — something in there is awake',
        3.2,
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
        _setHint('Wrong physic — the strain drinks it and doubles', 3.6);
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
    _setHint(
      'The cross goes up over ${ward?.name ?? 'the last ward'} — it is given up',
      4.2,
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
    _renderLazarGloom(canvas, room);
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
    final reach = (virulent ? 300.0 : 210.0) * (0.94 + 0.06 * breath);

    // Inside the room only — a vein crawling out through a wall reads as a
    // render bug, not as sickness.
    canvas.save();
    canvas.clipRect(room.bounds);

    // The bloom: three soft rings, darkest at the heart.
    for (var i = 3; i >= 1; i--) {
      canvas.drawCircle(
        heart,
        reach * i / 3,
        Paint()..color = col.withValues(alpha: 0.035 * (4 - i)),
      );
    }
    // VEINS. Deterministic, so the sickness does not crawl between frames —
    // it grows when the ward changes, and only then.
    var seed = room.id.codeUnits.fold<int>(53, (a, c) => (a * 31 + c) % 30011);
    double rnd() {
      seed = (seed * 1103515245 + 12345) % 2147483648;
      return seed / 2147483648;
    }

    for (var i = 0; i < 14; i++) {
      var at = heart;
      var a = rnd() * pi * 2;
      final path = Path()..moveTo(at.dx, at.dy);
      final len = reach * (0.35 + rnd() * 0.6);
      const steps = 6;
      for (var k = 0; k < steps; k++) {
        a += (rnd() - 0.5) * 1.1;
        at = at + Offset(cos(a), sin(a)) * (len / steps);
        path.lineTo(at.dx, at.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 + rnd() * 2.0
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = col.withValues(alpha: 0.10 + 0.16 * rnd()),
      );
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
    final at = active?.position ?? b.center;
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
        ..shader = ui.Gradient.linear(b.topCenter, b.bottomCenter, const [
          Color(0xFF161A15),
          Color(0xFF0E120E),
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
              )!,
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

  void _renderMonasteryFixtures(Canvas canvas, DungeonRoom room) {
    final t = monastery.triage;

    final still = room.apothecary;
    if (still != null) {
      // The cistern: a squat vessel with its level showing.
      final carrion = room.guardian != null;
      final c = still.cistern;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: 62, height: 46),
          const Radius.circular(8),
        ),
        Paint()..color = _venomDeep,
      );
      if (!carrion) {
        final fill = (t.cistern / kMonasteryCistern).clamp(0.0, 1.0);
        canvas.drawRect(
          Rect.fromLTWH(c.dx - 25, c.dy + 17 - 32 * fill, 50, 32 * fill),
          Paint()..color = _venomLive.withValues(alpha: 0.75),
        );
      }
      for (final spout in still.spouts) {
        _renderSpout(canvas, spout);
      }
    }

    final ward = room.ward;
    if (ward != null) {
      final cured = t.cured.contains(ward.id);
      // The censer: a hanging bowl on three chains.
      canvas.drawCircle(
        ward.censer,
        13,
        Paint()..color = cured ? _venomBone : _venomDeep,
      );
      canvas.drawCircle(
        ward.censer,
        13,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _venomBone.withValues(alpha: 0.7),
      );
      // The sacristy: a small door, sealed until the ward is clean.
      final taken = t.sacristiesTaken.contains(ward.id);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: ward.sacristy, width: 34, height: 46),
          const Radius.circular(6),
        ),
        Paint()
          ..color = cured
              ? (taken ? _venomDeep : _venomBone.withValues(alpha: 0.9))
              : const Color(0xFF2E2438),
      );
      if (ward.id == t.surrendered) {
        _renderOubliette(canvas, ward);
      }
    }

    final seal = room.priorsSeal;
    if (seal != null) {
      // The prior's seal: a lead cross on a stand, lit once it can be taken.
      final ready = t.canCommit && t.surrendered == null;
      final p = Paint()
        ..color = (ready ? _venomBone : _venomDeep).withValues(alpha: 0.95)
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        seal.position + const Offset(0, -26),
        seal.position + const Offset(0, 26),
        p,
      );
      canvas.drawLine(
        seal.position + const Offset(-18, -6),
        seal.position + const Offset(18, -6),
        p,
      );
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

  void _renderSpout(Canvas canvas, ApothecarySpout spout) {
    final p = spout.position;
    final ink = Paint()..color = _venomBone.withValues(alpha: 0.92);
    final body = Paint()..color = _venomDeep;
    switch (spout.draught) {
      case WardDraught.stilling:
        // A bell jar: a dome that damps whatever is under it.
        canvas.drawArc(
          Rect.fromCenter(center: p, width: 46, height: 46),
          pi,
          pi,
          true,
          body,
        );
        canvas.drawLine(
          p + const Offset(-24, 0),
          p + const Offset(24, 0),
          ink..strokeWidth = 3,
        );
      case WardDraught.quicklime:
        // A kiln mouth: a squat arch with a bright throat.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: p, width: 46, height: 38),
            const Radius.circular(4),
          ),
          body,
        );
        canvas.drawCircle(
          p + const Offset(0, 4),
          9,
          Paint()..color = const Color(0xFFE8E2CE),
        );
      case WardDraught.binding:
        // A smoke pot: a squat pot with a lattice over its mouth.
        canvas.drawOval(
          Rect.fromCenter(
            center: p + const Offset(0, 6),
            width: 44,
            height: 30,
          ),
          body,
        );
        for (var i = -1; i <= 1; i++) {
          canvas.drawLine(
            p + Offset(i * 12.0, -12),
            p + Offset(i * 12.0, 4),
            ink..strokeWidth = 2,
          );
        }
      case WardDraught.rousing:
        // The wake-bitters: a narrow flask with a struck clapper beside it.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: p, width: 22, height: 46),
            const Radius.circular(10),
          ),
          body,
        );
        canvas.drawCircle(p + const Offset(20, -12), 6, ink);
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
