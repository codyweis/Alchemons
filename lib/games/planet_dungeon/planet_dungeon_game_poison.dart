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

/// ONE THING THE PLAGUE PUT ON THE FLOOR during a gate: a rot-bulb to stand
/// on, a spore-pod drifting home, or a pool of blood to stopper. All three
/// are "a spot that wants a body", which is why they are one class — what
/// differs is how it moves and what finishing it takes.
class PlagueMark {
  PlagueMark({required this.at, this.from});

  /// Where it is now. Pods move; bulbs and pools do not.
  Offset at;

  /// Where a pod started, so the drift can be drawn as a path.
  final Offset? from;

  /// 0 → 1. A bulb or a pod finishes at the first touch; a pool has to be
  /// stood in, so it fills.
  double fill = 0;

  bool get done => fill >= 1;
}

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

  /// Which bottle the bench hands over next.
  int benchPick = 0;

  /// The cloister's seals have let go — the pure vial went into the font.
  bool cloisterOpen = false;

  /// The font taking the vial, 1 → 0.
  double lustral = 0;

  /// THE SEALS COMING OFF, one door at a time — 0 → 1 across the whole
  /// parade. The one moment on this planet that is worth a camera, and it
  /// says nothing: three doors, three sheets of wax, and the corridor is
  /// open. Words would only be describing what is already on screen.
  double parade = -1;
  int paradeDoor = -1;

  /// Brews standing in their bottles on the laboratory rack. A brew is made
  /// ONCE and lives in glass until it is poured — so a wrong pour can hand
  /// it back without the run losing a hand for it.
  final Set<String> bottled = {};

  /// Relics off the three plagues: dropped where each one died, carried one
  /// at a time, socketed at the cross.
  final Set<String> relicsDropped = {};
  final Map<String, Offset> relicAt = {};
  String? carriedRelic;
  final Set<String> relicsPlaced = {};

  /// The cross lighting, 0 → 1, once all three are socketed.
  double crossLight = 0;

  /// The pot's reaction, 1 → 0, and which one is playing.
  double reaction = 0;
  CauldronReaction? reactionKind;

  /// The pour landing on a plague, 1 → 0, and whose.
  double pour = 0;
  String? pourPotion;
  Offset pourAt = Offset.zero;

  /// A plague woken and still crawling — it lands when the crawl ends.
  String? pendingFight;

  // ── THE FIGHT ────────────────────────────────────────────
  //
  // THREE BARS AND THREE GATES. A plague does not simply have a lot of
  // health: each bar ends with it closing up, and the only thing that opens
  // it again is the mechanic that belongs to THAT plague. Rot puts bulbs on
  // the floor to be stood on; Breath scatters and its pods must be cut off
  // before it inhales them; Blood opens pools that have to be stoppered by
  // bodies. Three fights that are actually three different fights.

  /// THE BODY ITSELF, held by reference.
  ///
  /// It used to be found by scanning for the first live enemy that was not
  /// the guardian, which is wrong twice over: a wisp left over from a wrong
  /// pour would be picked as the boss, and a single frame with no enemies at
  /// all — a spawn refused by the pool cap, say — read as the plague having
  /// died, which dropped its reliquary without a fight.
  CosmicSurvivalEnemy? body;

  /// Bars still to break, 3 → 0.
  int bars = 0;

  /// True while it is closed up and running its mechanic.
  bool gated = false;

  /// Seconds left on the gate. Running out HEALS THE BAR BACK — generous on
  /// purpose: this is meant to be pressure, not a reaction test.
  double gateLeft = 0;

  /// The rot-bulbs / spore-pods / blood-pools of the current gate.
  final List<PlagueMark> marks = [];

  /// Pulses when a gate opens or closes, for the render, 1 → 0.
  double gateFlash = 0;

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
    m.body = null;
    m.bars = 0;
    m.gated = false;
    m.gateLeft = 0;
    m.marks.clear();
    m.gateFlash = 0;
    m.benchPick = 0;
    m.cloisterOpen = false;
    m.lustral = 0;
    m.parade = -1;
    m.paradeDoor = -1;
    m.bottled.clear();
    m.relicsDropped.clear();
    m.relicAt.clear();
    m.carriedRelic = null;
    m.relicsPlaced.clear();
    m.crossLight = 0;
    m.reaction = 0;
    m.reactionKind = null;
    m.pour = 0;
    m.pourPotion = null;
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
    if (!_isVenom) return;
    final m = monastery;
    _maybeWakeWard(room);
    _tellTheHouse(room);
    _tickPlagueFight(dt);
    if (m.reaction > 0) {
      m.reaction = max(0.0, m.reaction - dt / _kReactionSeconds);
      if (m.reaction == 0) m.reactionKind = null;
    }
    if (m.pour > 0) {
      m.pour = max(0.0, m.pour - dt / _kPourSeconds);
      if (m.pour == 0) m.pourPotion = null;
    }
    if (m.crossLight > 0) {
      m.crossLight = max(0.0, m.crossLight - dt / _kCrossLightSeconds);
    }
    if (m.lustral > 0) {
      m.lustral = max(0.0, m.lustral - dt / _kLustralSeconds);
    }
    _tickSealParade(dt, room);
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
      if (_tryBottleBench(a, room)) return true;
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
    // 4b) The lustral font in the middle of the cloister: the pure vial
    //     goes in here and every wax seal on the corridor lets go.
    if (_tryLustralFont(a, room)) return true;

    final seal = room.priorsSeal;
    if (seal != null &&
        (a.position - seal.position).distance <= _kMonasteryReach + 30) {
      return _tryCross(seal);
    }

    // 5b) A reliquary lying on the stones where a plague came apart.
    if (_tryTakeRelic(a, room)) return true;

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
      // A PLAGUE WARD IS NOT OPENED BY HAND. The wax on those three answers
      // the font in the middle of the corridor and nothing else; only the
      // dead-house is still a thing you break into yourself.
      if (!ward.bricked) {
        _setBlockedHint(
          monastery.carriedPotion == kPureVial.id
              ? 'The wax will not part here — the basin in the middle of the '
                    'cloister is what the vial is for'
              : kPureVial.clue,
        );
        return true;
      }
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
  /// The bottle bench, a table's length along from the pot.
  ///
  /// SEPARATE ON PURPOSE. When taking a bottle and giving to the pot were
  /// the same press at the same spot, the two could not be told apart: with
  /// anything at all standing in glass, a press always picked the bottle up
  /// and a new brew could never be started. The pot is where you give; the
  /// bench is where bottles live.
  Offset _benchAt(Apothecary still) => still.cistern + const Offset(200, 0);

  bool _tryBottleBench(DungeonCreature a, DungeonRoom room) {
    final still = room.apothecary;
    if (still == null || room.guardian != null) return false;
    final at = _benchAt(still);
    if ((a.position - at).distance > _kMonasteryReach) return false;
    final m = monastery;
    final held = m.carriedPotion;
    if (held != null) {
      // No line. The bottle leaves the hand and lands on the bench, both
      // on screen, and the HUD's BREW readout empties.
      m.carriedPotion = null;
      return true;
    }
    if (m.bottled.isEmpty) {
      _setBlockedHint('The bench is bare — the pot is where brews are made');
      return true;
    }
    // Round-robin, so a bench with three on it can hand over any of them.
    final ready = kAllBrews.where((p) => m.bottled.contains(p.id)).toList();
    final i = (m.benchPick % ready.length);
    m
      ..benchPick = (m.benchPick + 1) % ready.length
      ..carriedPotion = ready[i].id;
    return true;
  }

  bool _tryCauldron(DungeonCreature a, DungeonRoom room) {
    final still = room.apothecary;
    if (still == null) return false;
    if ((a.position - still.cistern).distance > _kMonasteryReach + 14) {
      return false;
    }
    final m = monastery;
    final el = a.member.element;
    final id = a.member.instanceId;

    // THE BENCH IS A PLACE, NOT A HAND. Bottles are taken and set down at
    // the bench along the wall; the pot only ever takes a give. A full hand
    // here is a refusal that names where to put it.
    if (m.carriedPotion != null) {
      _setBlockedHint('Set the bottle on the bench before giving to the pot');
      return true;
    }
    final allowed = contributionsAllowedFor(el);
    if ((m.given[id] ?? 0) >= allowed) {
      _setBlockedHint(
        '${a.member.displayName} has given $allowed times — that is all it '
        'has in it',
      );
      return true;
    }
    if (!kPotionIngredientEffect.containsKey(el)) {
      _setBlockedHint('The pot takes Poison, Plant or Mud. $el is neither.');
      return true;
    }
    // POISON TWICE IS A RECIPE. Everything else wants two different things,
    // and saying so is the tell that the pure vial exists at all.
    if (m.pot.contains(el) && el != 'Poison') {
      _setBlockedHint('$el is already in the pot — this wants something else');
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

    // NO LINE FOR A GIVE. The pot takes the colour, the jar on the shelf
    // drops by one, and both are on screen — saying it as well is the same
    // fact three times, eight times a run.
    if (m.pot.length < 2) return true;

    // Two in: it either makes something or it does not.
    final made = kAllBrews.where(
      (p) =>
          (p.first == m.pot[0] && p.second == m.pot[1]) ||
          (p.first == m.pot[1] && p.second == m.pot[0]),
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
    m.bottled.add(potion.id);
    m.carriedPotion = potion.id;
    // THE POT REACTS, AND EACH PAIR REACTS DIFFERENTLY. The receipt is the
    // whole reason giving to a cauldron feels like anything: three brews
    // that all made the same green flash would be three presses of one
    // button.
    m
      ..reaction = 1.0
      ..reactionKind = potion.pot;
    // The reaction is the sentence. All the words add is the NAME, which is
    // the one thing a picture cannot give you.
    speakConsequence(potion.name, 2.6);
    _spawnAlchemyBurst(
      still.cistern,
      producedElement: switch (potion.pot) {
        CauldronReaction.pure => 'Poison',
        CauldronReaction.bloom => 'Light',
        CauldronReaction.climb => 'Poison',
        CauldronReaction.rot => 'Plant',
      },
      reagentElements: [potion.first, potion.second],
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
  /// Is [enemy] the plague body, closed up behind its mechanic? Nothing
  /// reaches it while this is true, which is the whole shape of the fight.
  bool venomGated(CosmicSurvivalEnemy enemy) {
    if (!monastery.gated) return false;
    return identical(enemy, _plagueBody);
  }

  double venomDrainMul(DungeonCreature? a) {
    if (a == null) return 1.0;
    return monastery.drained.contains(a.member.instanceId)
        ? _kVenomDrainMul
        : 1.0;
  }

  /// THE FONT IN THE MIDDLE. One errand that opens three doors.
  ///
  /// The wards used to unseal one at a time, by walking up and pressing —
  /// which was three presses of the same button and taught nothing. Now the
  /// corridor is shut until pure poison goes into the basin at its centre,
  /// which makes the vial the first thing anybody brews and the reason the
  /// Poison alchemon carries four gives instead of two.
  bool _tryLustralFont(DungeonCreature a, DungeonRoom room) {
    final at = room.lustralFont;
    if (at == null) return false;
    if ((a.position - at).distance > _kMonasteryReach + 14) return false;
    final m = monastery;
    // SPENT MEANS GONE. It sinks into the floor once the seals are off, so
    // it is neither in the way of the fight nor still answering presses in
    // the middle of it — the cloister is the arena, and the arena wants
    // clear ground.
    if (m.cloisterOpen) return false;
    if (m.carriedPotion != kPureVial.id) {
      _setBlockedHint(
        m.carriedPotion == null
            ? kPureVial.clue
            : 'The basin will not take that. ${kPureVial.clue}',
      );
      return true;
    }

    m
      ..bottled.remove(kPureVial.id)
      ..carriedPotion = null
      ..cloisterOpen = true
      ..lustral = 1.0;
    // The hands that made the key come back. The vial spends two of Poison's
    // four gives, and that arithmetic is the puzzle — but a mandatory first
    // errand that also handicaps the first fight would be a tax with no
    // decision inside it, which is the opposite of the point.
    for (final id in m.potionHands[kPureVial.id] ?? const <String>[]) {
      m.drained.remove(id);
    }
    // NOT HERE. Opening all three the moment the vial goes in made every
    // sheet of wax vanish before the camera had been anywhere — the parade
    // then toured three doors that were already open. Each ward opens as the
    // shot arrives at it; `_tickSealParade` does that, and catches up any
    // that are still shut if the walk is cut short.
    m.parade = 0;
    m.paradeDoor = -1;
    // The camera holds the font for the pour, then walks the doors itself.
    cutTo(room.id, at, hold: _kLustralSeconds + _kParadeSeconds + 0.5);
    _shake = 6.0;
    _spawnAlchemyBurst(
      at,
      producedElement: 'Poison',
      reagentElements: const ['Light'],
      particleCount: 30,
      intensity: 1.3,
    );
    return true;
  }

  /// THE PARADE. After the font, the camera leaves the party and walks the
  /// corridor, stopping at each ward door as its wax lets go.
  ///
  /// WORDLESS ON PURPOSE. This used to be one long sentence explaining that
  /// every seal had opened, which is a caption for a thing the player could
  /// simply have been shown. Three doors, three sheets of wax coming off,
  /// and the camera back where it started.
  void _tickSealParade(double dt, DungeonRoom room) {
    final m = monastery;
    if (m.parade < 0) {
      // THE MECHANISM IS THE POUR, NOT THE WALK. If the vial went in and the
      // parade is not running — it finished, it never started, the run was
      // reloaded — anything still sealed opens now. A cinematic must never
      // be the only thing standing between the player and three rooms.
      if (m.cloisterOpen) {
        for (final p in kPlaguePotions) {
          m.triage.open(p.wardId!);
        }
      }
      return;
    }
    // The pour finishes first — the doors do not move until the font has.
    if (m.lustral > 0) return;
    final walk = layout.rooms['ambulatory'];
    if (walk == null) {
      m.parade = -1;
      return;
    }
    final doors = _paradeDoors(walk);
    if (doors.isEmpty) {
      m.parade = -1;
      return;
    }

    m.parade += dt / _kParadeSeconds;
    final leg = 1.0 / doors.length;
    final i = min(doors.length - 1, (m.parade / leg).floor());

    // ARRIVING AT A DOOR IS WHAT OPENS IT. The wax blows out and the ward
    // becomes a room in the same frame, so the burst is the seal breaking
    // rather than a firework over a door that opened a moment ago.
    if (i != m.paradeDoor) {
      m.paradeDoor = i;
      m.triage.open(doors[i].$1);
      m
        ..sealBurst = 1.0
        ..sealBurstAt = doors[i].$2
        ..burstIsSick = false;
      _shake = 4.0;
    }
    // Slide between doors rather than snapping, so it reads as one shot
    // down the length of the cloister.
    final within = ((m.parade - i * leg) / leg).clamp(0.0, 1.0);
    final from = i == 0 ? (walk.lustralFont ?? doors[0].$2) : doors[i - 1].$2;
    followRoomId = walk.id;
    followAt = Offset.lerp(
      from,
      doors[i].$2,
      Curves.easeInOutCubic.transform(within),
    );

    if (m.parade >= 1.0) {
      m.parade = -1;
      m.paradeDoor = -1;
      // CATCH UP. The walk is a cinematic, not the mechanism — whatever it
      // did not reach still opens, so a parade cut short by anything at all
      // cannot leave a ward sealed for the rest of the run.
      for (final d in doors) {
        m.triage.open(d.$1);
      }
    }
  }

  /// The three plague doors, left to right along the cloister, each with the
  /// ward it belongs to — the parade has to know WHICH seal it is breaking.
  List<(String, Offset)> _paradeDoors(DungeonRoom walk) {
    final wards = {for (final p in kPlaguePotions) p.wardId};
    final out = <(String, Offset)>[
      for (final d in walk.doors)
        if (wards.contains(d.targetRoomId))
          (d.targetRoomId, Offset(d.rect.center.dx, d.rect.center.dy + 40)),
    ];
    out.sort((a, b) => a.$2.dx.compareTo(b.$2.dx));
    return out;
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
      final wrong = brewById(held)!;
      // A WRONG POUR COSTS SOMETHING, AND IT IS NEVER THE BREW. One
      // misreading of a riddle must not be able to make the house
      // unfinishable, so the bottle comes back full — and the room makes you
      // pay for the guess in the only currency that cannot strand you.
      _wrongPour(potion, wrong, ward);
      return true;
    }

    m.bottled.remove(potion.id);
    m.carriedPotion = null;
    m.woken.add(potion.id);
    m.drained.addAll(m.potionHands[potion.id] ?? const <String>[]);
    m
      ..pour = 1.0
      ..pourPotion = potion.id
      ..pourAt = ward.heart;
    // The pour plays on the plague and then it crawls out through the door
    // in front of you. Nothing here needs saying twice.
    speakConsequence('${_capitalisePoison(potion.plague)} wakes.', 2.8);
    _plagueEntersTheWalk(ward.id, sick: false);
    m.pendingFight = potion.id;
    return true;
  }

  /// THE WRONG BOTTLE. Three complications, one per brew, so which mistake
  /// you made is legible from what happens — and none of them take the brew.
  void _wrongPour(PlaguePotion sleeper, PlaguePotion wrong, WardCell ward) {
    final m = monastery;
    m
      ..pour = 1.0
      ..pourPotion = wrong.id
      ..pourAt = ward.heart;
    _shake = 4.0;
    switch (wrong.pot) {
      case CauldronReaction.pure:
        // The key, poured on a sleeper. It washes the ward and does nothing
        // else — the cheapest mistake on the planet, and the one the font in
        // the middle of the cloister exists to prevent.
        speakConsequence('It runs off clean. The bottle is still full.', 3.6);
      case CauldronReaction.bloom:
        // Spores off a brew nothing drank: the room fills and it stings.
        spawnWispWave(
          element: 'Plant',
          center: ward.heart,
          count: 3,
          unstable: true,
          announce: false,
        );
        speakConsequence('It will not drink. The bottle is still full.', 3.6);
      case CauldronReaction.climb:
        // It climbs the wrong host: something comes up out of the floor.
        spawnDungeonEnemy(
          tier: EnemyTier.wisp,
          conduct: EnemyConduct.charge,
          element: 'Mud',
          from: ward.heart,
          hp: 30,
          speed: 78,
          damage: 8,
          radius: 11,
        );
        spawnDungeonEnemy(
          tier: EnemyTier.wisp,
          conduct: EnemyConduct.stalk,
          element: 'Mud',
          from: ward.heart,
          hp: 30,
          speed: 78,
          damage: 8,
          radius: 11,
        );
        speakConsequence('Wrong sleeper. The bottle is still full.', 3.6);
      case CauldronReaction.rot:
        // The sleeper stirs, and settles. The cheapest of the three, and
        // the loudest tell that you were at the wrong door.
        m.wake = 0;
        m.wakeWard = ward.id;
        speakConsequence(
          'It turns over and goes under. The bottle is still full.',
          3.6,
        );
    }
    _spawnAlchemyBurst(
      ward.heart,
      producedElement: wrong.first,
      reagentElements: [wrong.second],
      unstable: true,
      particleCount: 20,
      intensity: 1.0,
    );
  }

  /// The plague lands in the cloister at the end of its crawl. Spawned here
  /// rather than at the press so the thing you fight is the thing you just
  /// watched arrive — ONE body, no swarm: three bars and three gates are
  /// enough to hold a fight together, and adds would only bury the mechanic
  /// the plague is actually about.
  void _plagueLands(String potionId) {
    final walk = layout.rooms['ambulatory'];
    if (walk == null) return;
    final at = monastery.invadeTo;
    final ok = spawnDungeonEnemy(
      tier: EnemyTier.brute,
      conduct: EnemyConduct.charge,
      element: 'Poison',
      from: at,
      hp: _kPlagueBarHp,
      speed: 54,
      damage: 14,
      radius: 26,
      steers: true,
    );
    if (!ok) return;
    // WHERE THE CRAWL ENDED, not off the edge of the screen. `spawnDungeonEnemy`
    // brings everything in from off-viewport, which is right for an ambush
    // and exactly wrong here: the thing you watched arrive would vanish and
    // a different thing would walk in from the wall a second later.
    final spawned = combatEnemies.isEmpty ? null : combatEnemies.last;
    spawned?.position = at;
    monastery
      ..body = spawned
      ..fighting = potionId
      ..bars = kPlagueBars
      ..gated = false
      ..gateLeft = 0
      ..gateFlash = 1.0
      ..marks.clear();
  }

  /// The body currently being fought, if it is still standing.
  CosmicSurvivalEnemy? get _plagueBody {
    final b = monastery.body;
    if (b == null || b.isDead) return null;
    return b;
  }

  /// THE FIGHT, ONE TICK.
  ///
  /// A bar runs out → it closes up and puts its mechanic on the floor →
  /// the mechanic is finished, which breaks that bar for good, or the gate
  /// times out and the bar comes back. Three times.
  void _tickPlagueFight(double dt) {
    final m = monastery;
    final id = m.fighting;
    if (id == null) return;
    if (currentRoomId != 'ambulatory') return;
    final potion = brewById(id);
    if (potion == null) {
      m.fighting = null;
      return;
    }
    // ── IT CANNOT DIE ON A BAR ──
    //
    // The bug that made the whole fight invisible on a real device. Every
    // damage site flags an enemy dead the instant its health reaches zero,
    // and the combat cull sweeps it out of the list in the SAME frame — so
    // the first bar running out killed the plague outright and dropped its
    // reliquary, before the gate had any chance to look at it. Headless
    // tests never saw it because they set `hp = 0` and let this tick read it
    // first; a party actually hitting the thing does not take turns.
    //
    // So: while a bar remains, a dead body is not a dead plague. It comes
    // back on one point of health, goes back in the list if the cull took
    // it, and the gate opens.
    final body = monastery.body;
    if (body == null) {
      m.fighting = null;
      return;
    }
    if (m.bars > 0 && (body.isDead || body.hp <= 0)) {
      body
        ..isDead = false
        ..hp = 1;
      if (!combatEnemies.contains(body)) combatEnemies.add(body);
      if (!m.gated) {
        _openGate(potion, body);
        return;
      }
    }
    if (m.gateFlash > 0) m.gateFlash = max(0.0, m.gateFlash - dt / 0.8);
    if (!m.gated) return;

    // ── GATED ──
    body.hp = max(1.0, body.hp);
    _tickMarks(potion, body, dt);
    if (m.marks.every((k) => k.done)) {
      _closeGate(potion, body);
      return;
    }
    m.gateLeft -= dt;
    if (m.gateLeft <= 0) {
      // TIME. The bar comes back — the one real failure in the fight, and
      // it costs progress rather than lives.
      m
        ..gated = false
        ..gateFlash = 1.0
        ..marks.clear();
      body.hp = body.maxHp;
      _shake = 5.0;
      speakConsequence('It closes over. The bar comes back.', 3.2);
    }
  }

  /// A bar has run out: it shuts, and its own mechanic goes on the floor.
  void _openGate(PlaguePotion potion, CosmicSurvivalEnemy body) {
    final m = monastery;
    final walk = layout.rooms['ambulatory'];
    if (walk == null) return;
    m
      ..gated = true
      ..gateLeft = _kGateSeconds
      ..gateFlash = 1.0
      ..marks.clear();
    _shake = 6.0;

    final b = walk.bounds.deflate(60);
    switch (potion.pot) {
      case CauldronReaction.rot:
        // STAND ON THEM. Bulbs come up out of the floor around it.
        for (var i = 0; i < _kGateMarks; i++) {
          final a = -pi / 2 + (i - (_kGateMarks - 1) / 2) * 0.9;
          final at = body.position + Offset(cos(a), sin(a) * 0.65) * 120;
          m.marks.add(PlagueMark(at: _clampInto(at, b)));
        }
      case CauldronReaction.bloom:
        // CUT THEM OFF. Pods drift home from the edges of the cloister.
        for (var i = 0; i < _kGateMarks; i++) {
          final left = i.isEven;
          final at = Offset(
            left ? b.left : b.right,
            b.top + b.height * ((i + 1) / (_kGateMarks + 1)),
          );
          m.marks.add(PlagueMark(at: at, from: at));
        }
      case CauldronReaction.climb:
        // PUT BODIES IN THEM. Pools open, and standing in one is slow work.
        for (var i = 0; i < _kGateMarks; i++) {
          final a = pi / 2 + (i - (_kGateMarks - 1) / 2) * 1.15;
          final at = body.position + Offset(cos(a), sin(a) * 0.6) * 140;
          m.marks.add(PlagueMark(at: _clampInto(at, b)));
        }
      case CauldronReaction.pure:
        // The vial wakes nothing, so this is unreachable — but a gate with
        // no marks would hang the fight until the timer, so it opens empty
        // and closes at once rather than stalling.
        break;
    }
  }

  Offset _clampInto(Offset at, Rect b) =>
      Offset(at.dx.clamp(b.left, b.right), at.dy.clamp(b.top, b.bottom));

  /// Work the marks against where the party is standing.
  void _tickMarks(PlaguePotion potion, CosmicSurvivalEnemy body, double dt) {
    final m = monastery;
    for (final mark in m.marks) {
      if (mark.done) continue;

      if (potion.pot == CauldronReaction.bloom) {
        // It is going home. Cut it off on the way.
        final toward = body.position - mark.at;
        final d = toward.distance;
        if (d > 1) {
          mark.at += (toward / d) * _kPodSpeed * dt;
        }
        if (d <= 30) {
          // Breathed back in: it starts again from the edge rather than
          // failing the gate outright, so the cost of missing one is time.
          mark.at = mark.from ?? mark.at;
          _spawnAlchemyBurst(
            body.position,
            producedElement: 'Plant',
            particleCount: 10,
            intensity: 0.7,
          );
          continue;
        }
      }

      final touching = creatures.any(
        (c) => c.alive && (c.position - mark.at).distance <= _kMarkReach,
      );
      if (!touching) {
        // A pool half-stoppered slides back if the body walks away.
        if (potion.pot == CauldronReaction.climb) {
          mark.fill = max(0.0, mark.fill - dt / (_kPoolFillSeconds * 2));
        }
        continue;
      }
      // A bulb or a pod goes at the first touch; a pool has to be held.
      mark.fill = potion.pot == CauldronReaction.climb
          ? min(1.0, mark.fill + dt / _kPoolFillSeconds)
          : 1.0;
      if (mark.done) {
        _spawnAlchemyBurst(
          mark.at,
          producedElement: potion.first,
          reagentElements: [potion.second],
          particleCount: 16,
          intensity: 0.9,
        );
      }
    }
  }

  /// The mechanic is finished: that bar is gone for good.
  void _closeGate(PlaguePotion potion, CosmicSurvivalEnemy body) {
    final m = monastery;
    m
      ..gated = false
      ..gateLeft = 0
      ..gateFlash = 1.0
      ..marks.clear()
      ..bars = max(0, m.bars - 1);
    _shake = 7.0;
    _spawnAlchemyBurst(
      body.position,
      producedElement: 'Light',
      reagentElements: [potion.first, potion.second],
      particleCount: 28,
      intensity: 1.2,
    );
    if (m.bars <= 0) {
      body.isDead = true;
      _plagueFalls(potion);
      return;
    }
    body.hp = body.maxHp;
  }

  /// It is down. What it leaves behind is the point.
  void _plagueFalls(PlaguePotion potion) {
    final m = monastery;
    m
      ..fighting = null
      ..gated = false
      ..bars = 0
      ..marks.clear();
    m.woken.remove(potion.id);
    m.slain.add(potion.id);
    // The hands come back. All of them — a fallen plague clears the whole
    // house's exhaustion, so brewing the next one is a fresh decision.
    m.drained.clear();
    final walk = layout.rooms['ambulatory'];
    final at = walk == null ? m.invadeTo : _relicRestingPlace(walk, m.invadeTo);
    m.relicsDropped.add(potion.id);
    m.relicAt[potion.id] = at;
    _shake = 5.0;
    _spawnAlchemyBurst(
      at,
      producedElement: 'Light',
      reagentElements: [potion.first, potion.second],
      particleCount: 26,
      intensity: 1.1,
    );
    // The reliquary drops where it died and the cross has an empty socket
    // waiting for it. Both are on screen; neither needs narrating.
  }

  /// Clear floor in the cloister for a plague to be fought on: away from the
  /// font in the middle and away from the cross at the end, so neither
  /// fixture ends up underneath the fight or underneath what it drops.
  Offset _plagueArena(DungeonRoom walk) {
    final avoid = <Offset>[
      if (walk.lustralFont != null) walk.lustralFont!,
      if (walk.priorsSeal != null) walk.priorsSeal!.position,
    ];
    final b = walk.bounds.deflate(70);
    if (avoid.length < 2) return b.center;
    // THE STRETCH BETWEEN THE FONT AND THE CROSS. Scanning the whole
    // corridor for the point farthest from both fixtures put every fight in
    // the far left corner — clear of everything, and a thousand pixels of
    // empty floor between the reliquary and the socket it belongs in, three
    // times. Between them is clear of both and a short carry.
    final lo = avoid[0].dx < avoid[1].dx ? avoid[0] : avoid[1];
    final hi = avoid[0].dx < avoid[1].dx ? avoid[1] : avoid[0];
    var best = Offset((lo.dx + hi.dx) / 2, b.center.dy);
    // …unless they are too close together for anything to stand between, in
    // which case fall back to the widest clear spot in the room.
    var bestScore = min((best - lo).distance, (best - hi).distance);
    if (bestScore < 130) {
      for (var i = 0; i <= 16; i++) {
        final at = Offset(b.left + b.width * i / 16, b.center.dy);
        final score = min((at - lo).distance, (at - hi).distance);
        if (score > bestScore) {
          bestScore = score;
          best = at;
        }
      }
    }
    return Offset(
      best.dx.clamp(b.left, b.right),
      best.dy.clamp(b.top, b.bottom),
    );
  }

  /// Where a relic actually comes to rest. The plague dies wherever the
  /// fight ended, which can be inside a wall or on top of the cross — so the
  /// drop is nudged onto ground you can stand on and away from the socket
  /// stones, or picking it up is impossible and nobody can tell why.
  Offset _relicRestingPlace(DungeonRoom walk, Offset want) {
    final b = walk.bounds.deflate(46);
    var at = Offset(
      want.dx.clamp(b.left, b.right),
      want.dy.clamp(b.top, b.bottom),
    );
    // Clear of EVERY fixture with a verb on it, not just the cross. A relic
    // inside the font's reach is a relic you cannot pick up, because the
    // font answers the press first and says the basin is spent.
    for (final o in <Offset>[
      if (walk.priorsSeal != null) walk.priorsSeal!.position,
      if (walk.lustralFont != null) walk.lustralFont!,
    ]) {
      if ((at - o).distance >= 110) continue;
      final away = at - o;
      final unit = away.distance < 1
          ? const Offset(-1, 0)
          : away / away.distance;
      at = o + unit * 110;
      at = Offset(at.dx.clamp(b.left, b.right), at.dy.clamp(b.top, b.bottom));
    }
    return at;
  }

  /// PICK ONE UP. One relic at a time, and never with a bottle in the same
  /// hand — the walk back to the cross is meant to be its own trip.
  bool _tryTakeRelic(DungeonCreature a, DungeonRoom room) {
    final m = monastery;
    if (room.id != 'ambulatory') return false;
    for (final p in kPlaguePotions) {
      if (!m.relicsDropped.contains(p.id)) continue;
      if (m.relicsPlaced.contains(p.id)) continue;
      final at = m.relicAt[p.id];
      if (at == null) continue;
      if ((a.position - at).distance > _kMonasteryReach) continue;
      if (m.carriedRelic != null) {
        _setBlockedHint('A hand already carries a reliquary');
        return true;
      }
      if (m.carriedPotion != null) {
        _setBlockedHint('Put the bottle down first');
        return true;
      }
      m.carriedRelic = p.id;
      m.relicAt.remove(p.id);
      return true;
    }
    return false;
  }

  /// SOCKET IT. Three stones at the foot of the cross; the third lights it.
  bool _tryCross(PriorsSeal seal) {
    final m = monastery;
    final held = m.carriedRelic;
    if (held == null) return _readTheRoll(seal);
    final potion = brewById(held);
    if (potion == null) return _readTheRoll(seal);
    m.carriedRelic = null;
    m.relicsPlaced.add(held);
    _spawnAlchemyBurst(
      _relicSocket(seal, held),
      producedElement: 'Light',
      reagentElements: [potion.first, potion.second],
      particleCount: 22,
      intensity: 1.0,
    );
    if (m.relicsPlaced.length < kPlaguePotions.length) {
      // The socket fills and the empty ones stay empty, in plain sight.
      return true;
    }
    // THE CROSS TAKES THE LIGHT.
    m.crossLight = 1.0;
    cutTo(currentRoomId, seal.position, hold: _kCrossLightSeconds + 0.4);
    _shake = 7.0;
    // No line: the cut goes to the cross, it takes light, and two stars
    // announce themselves.
    if (!hasStar(seal.diagnosisStarIndex)) earnStar(seal.diagnosisStarIndex);
    if (!hasStar(seal.triageStarIndex)) earnStar(seal.triageStarIndex);
    return true;
  }

  /// Where each relic sits at the foot of the cross — three stones in a row,
  /// in the order the brews are authored so the row reads the same every run.
  Offset _relicSocket(PriorsSeal seal, String potionId) {
    final i = kPlaguePotions.indexWhere((p) => p.id == potionId);
    return Offset(seal.position.dx + (i - 1) * 34, seal.position.dy + 46);
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
        '${_capitalisePoison(awake.first.plague)} is loose.',
        3.4,
      );
      return true;
    }
    if (down >= kPlaguePotions.length) {
      speakConsequence('Three struck through. The house owes nothing.', 4.0);
      return true;
    }
    speakConsequence('$down of ${kPlaguePotions.length} struck through.', 3.6);
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
        // The board states the riddle and nothing else. What the reading
        // adds is the working: the three verbs off the larder shelf, then —
        // for a party that has read a lot of books — who can still give.
        _setInsightHint(switch (revealTier) {
          0 =>
            '${_capitalisePoison(potion.plague)} sleeps here. '
                '${potion.clue}',
          1 =>
            '${potion.clue} The pot knows three verbs: '
                '${kPotionIngredientEffect.entries.map((e) => '${e.key} '
                    '${e.value.split(' ').first}').join(', ')}.',
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
    final held = brewById(m.carriedPotion);
    if (held != null) {
      return DungeonProgressReadout(label: 'BREW', value: held.name);
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
    _renderLustralFont(canvas, room);
    _renderPlagueFight(canvas, room);
    _renderRelics(canvas, room);
    _renderPourOnPlague(canvas, room);
    _renderCarriedPhial(canvas);
    _renderCarriedBottle(canvas);
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
  /// The crawl. Slow on purpose — it is the one look at the thing you get
  /// before it is a fight, and at five seconds the shrink and the travel
  /// both read as a blink.
  static const double _kInvadeSeconds = 8.0;

  // ── THE FIGHT ────────────────────────────────────────────
  //
  /// One bar's worth of body. Three of these is a plague.
  ///
  /// The first number here was 78, which a real party erased in well under a
  /// second — the whole fight was over before anyone saw a gate. The old
  /// single-body plague was 190 plus three wisps; three bars of 150 is a
  /// boss, and the gates between them are most of the length anyway.
  static const double _kPlagueBarHp = 150;

  /// How long a gate stands before the bar comes back.
  ///
  /// GENEROUS ON PURPOSE. The standing rule on this game is that a puzzle
  /// rewards thinking and never reflexes; a gate that punishes a slow hand
  /// would be exactly the thing that rule forbids. Fourteen seconds is long
  /// enough to walk the cloister and think about it, and short enough that
  /// ignoring the mechanic entirely does not work.
  static const double _kGateSeconds = 14.0;

  /// Bulbs, pods or pools per gate.
  static const int _kGateMarks = 3;

  /// How close a body has to be to work one.
  static const double _kMarkReach = 34.0;

  /// A pool wants a body held in it, not brushed past.
  static const double _kPoolFillSeconds = 1.4;

  /// How fast a spore-pod drifts home.
  static const double _kPodSpeed = 44.0;

  /// The font taking the vial and the seals letting go down the corridor.
  static const double _kLustralSeconds = 1.6;

  /// The camera's walk down the three doors after it.
  static const double _kParadeSeconds = 3.6;

  /// The pot's reaction to a pair landing in it, and a pour landing on a
  /// plague. Both are receipts — long enough to read, short enough that a
  /// player brewing three of them is never waiting on the game.
  static const double _kReactionSeconds = 2.2;
  static const double _kPourSeconds = 2.0;

  /// The cross taking the light, once the third relic is in.
  static const double _kCrossLightSeconds = 3.2;

  /// What a spent hand is worth — both its damage and its walk.
  static const double _kVenomDrainMul = 0.55;

  /// How far through the sequence it goes through the doorway.
  static const double _kInvadeCross = 0.34;

  /// How far into the crawl the thing has finished gathering itself off the
  /// heart. Before this it is still pulling in off the walls of the ward.
  static const double _kInvadeGather = 0.24;

  /// Where it has finished opening back out in the cloister. The rest of the
  /// crawl is it standing at full size, so the fight starts on something you
  /// have already been looking at.
  static const double _kInvadeSettle = 0.86;

  /// Full size: the crawl's head at this scale is the radius of the body.
  static const double _kPlagueScale = 2.4;

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
      // WHERE IT COMES TO REST, and it is not the room's centre — the
      // lustral font stands there, and a plague that landed on the basin
      // dropped its reliquary onto it, where the font's own verb swallowed
      // every press to pick it up. The fight has its own floor.
      ..invadeTo = _plagueArena(walk);
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
    // GREEN COMING OFF THE HEART, ITS OWN COLOUR BY THE DOOR. A woken plague
    // stops being "the sick green in the wards" the moment it is awake.
    final col = m.invadeSick
        ? _venomSick
        : _invadeColour(t, brewById(m.pendingFight ?? m.fighting));
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
      if (t < _kInvadeCross) {
        _drawInvadeHead(canvas, head, col, _invadeScale(t));
      }
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
        if (headRoom == 'ambulatory') {
          _drawInvadeHead(canvas, head, col, _invadeScale(t));
        }
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
  void _drawInvadeHead(Canvas canvas, Offset head, Color col, [double s = 1]) {
    for (var i = 0; i < 9; i++) {
      final a = i * 2 * pi / 9 + _time * 0.9;
      canvas.drawLine(
        head,
        head + Offset(cos(a), sin(a)) * ((14 + 7 * sin(_time * 5 + i)) * s),
        Paint()
          ..strokeWidth = 2.4 * s
          ..strokeCap = StrokeCap.round
          ..color = col.withValues(alpha: 0.55),
      );
    }
    canvas.drawCircle(
      head,
      11 * s,
      Paint()..color = col.withValues(alpha: 0.85),
    );
    if (_fx.ready) {
      drawGlow(canvas, _fx.glow!, head, 46 * s, col.withValues(alpha: 0.34));
    }
  }

  /// WHAT COLOUR THIS PLAGUE IS ONCE IT IS AWAKE.
  ///
  /// Everything in the lazaret is the same sick green until it is woken, and
  /// then each of the three becomes its own thing — the way a wrongly-dosed
  /// strain used to go violet when it took the wrong physic and swelled. If
  /// all three arrive green there is nothing to tell them apart in the one
  /// room where telling them apart is the whole fight.
  Color _plagueColour(PlaguePotion p) => switch (p.pot) {
    CauldronReaction.bloom => const Color(0xFFE3B23C), // Breath: pollen gold
    CauldronReaction.climb => const Color(0xFFB03050), // Blood: crimson
    CauldronReaction.rot => const Color(0xFF8A4FB0), // Decay: violet rot
    CauldronReaction.pure => _venomLive,
  };

  /// The colour partway through the crawl: it is still the ward's green when
  /// it comes off the heart, and fully itself by the time it is through the
  /// door.
  Color _invadeColour(double t, PlaguePotion? p) {
    if (p == null) return _venomLive;
    final k = (t / _kInvadeCross).clamp(0.0, 1.0);
    return Color.lerp(_venomLive, _plagueColour(p), k)!;
  }

  /// HOW BIG THE THING IS, ACROSS THE WHOLE CRAWL.
  ///
  /// It has to gather itself before it can leave. Reported from play as the
  /// plague simply appearing in the corridor: without this it was full size
  /// from the first frame, so the ward phase read as a shape sliding to a
  /// door rather than a sickness pulling in off the walls to fit through
  /// one. Swells: pulls in tight over the heart, squeezes down to nothing
  /// at the sill, and opens back out on the far side.
  double _invadeScale(double t) {
    if (t < _kInvadeGather) {
      // Off the heart and drawing in — big and loose, then compact. Slow:
      // this is a sickness pulling itself in off the walls of a room, and at
      // the first speed it read as a blink.
      final k = (t / _kInvadeGather).clamp(0.0, 1.0);
      return 2.4 - 1.5 * Curves.easeInOutCubic.transform(k);
    }
    if (t < _kInvadeCross) {
      // Squeezing through: down to a thread at the doorway.
      final k = ((t - _kInvadeGather) / (_kInvadeCross - _kInvadeGather)).clamp(
        0.0,
        1.0,
      );
      return 0.9 - 0.55 * Curves.easeInQuad.transform(k);
    }
    // OUT THE OTHER SIDE, and it opens all the way back out — to the size of
    // the body you are about to fight, not to something smaller that then
    // gets swapped for a monster. The last stretch is held at full size, so
    // the fight starts on a thing you have already been looking at.
    final k = ((t - _kInvadeCross) / (_kInvadeSettle - _kInvadeCross)).clamp(
      0.0,
      1.0,
    );
    return 0.35 + (_kPlagueScale - 0.35) * Curves.easeOutCubic.transform(k);
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
        'Two in, one out. Poison has four gives; the others have two.',
        5.5,
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
    // NOT SPOKEN. The board over the censer carries the riddle and keeps
    // carrying it — a popup that says the same thing and then goes away is
    // strictly worse than a sign that stays up.
    m.symptomTold.add(potion.first.id);
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
    // Standing in it counts — for the dead-house, which you broke into
    // yourself. The three plague wards are opened by the font, and if you
    // are inside one at all then the font has already been poured.
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
      final m = monastery;
      final placed = m.relicsPlaced.length;
      final lit = placed >= kPlaguePotions.length;
      // Ready = there is a reliquary in hand and a socket to put it in. The
      // old readiness was the triage's, and the triage is gone.
      final ready = m.carriedRelic != null || lit;
      final sp = seal.position;
      _stoneBlock(
        canvas,
        Rect.fromCenter(
          center: sp + const Offset(0, 34),
          width: 46,
          height: 18,
        ),
      );

      // THE THREE SOCKETS at the foot of it, cut in the stone from the start
      // — so an empty cross states what it wants before you have anything to
      // give it, and a player who has killed one plague knows where to take
      // what it dropped.
      for (var i = 0; i < kPlaguePotions.length; i++) {
        final potion = kPlaguePotions[i];
        final at = _relicSocket(seal, potion.id);
        final full = m.relicsPlaced.contains(potion.id);
        _stoneBlock(
          canvas,
          Rect.fromCenter(center: at, width: 26, height: 20),
          radius: 3,
        );
        canvas.drawOval(
          Rect.fromCenter(center: at, width: 15, height: 11),
          Paint()..color = const Color(0xFF07090A),
        );
        if (!full) continue;
        final col = _brewColour(potion);
        canvas.drawOval(
          Rect.fromCenter(center: at, width: 13, height: 9),
          Paint()..color = col.withValues(alpha: 0.92),
        );
        canvas.drawCircle(
          at,
          13 + 3 * sin(_time * 2.0 + i),
          Paint()..color = col.withValues(alpha: 0.16),
        );
      }

      final take = lit
          ? Curves.easeOutCubic.transform(
              (1 - monastery.crossLight).clamp(0.0, 1.0),
            )
          : 0.0;
      final p = Paint()
        ..color = Color.lerp(
          (ready ? _venomBone : const Color(0xFF474C52)),
          const Color(0xFFF2E7A8),
          take,
        )!.withValues(alpha: 0.95)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.square;
      // TALL ON PURPOSE. At its old height the whole cross sat behind the
      // creature standing at it — the one fixture on the planet that has to
      // be legible from the moment it lights, and the party was wearing it.
      canvas.drawLine(sp + const Offset(0, -66), sp + const Offset(0, 26), p);
      canvas.drawLine(
        sp + const Offset(-24, -40),
        sp + const Offset(24, -40),
        p,
      );
      canvas.drawLine(
        sp + const Offset(-2, -64),
        sp + const Offset(-2, 24),
        Paint()
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: ready ? 0.22 : 0.10),
      );

      // THE CROSS TAKING LIGHT: rings off it, once, as the third goes home.
      if (monastery.crossLight > 0) {
        final k = 1 - monastery.crossLight;
        for (var i = 0; i < 3; i++) {
          final r = ((k * 1.4) - i * 0.18).clamp(0.0, 1.0);
          if (r <= 0) continue;
          canvas.drawCircle(
            sp + const Offset(0, -20),
            30 + 170 * r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 7 * (1 - r)
              ..color = const Color(
                0xFFF2E7A8,
              ).withValues(alpha: 0.5 * (1 - r)),
          );
        }
      }
      if ((lit || ready) && _fx.ready) {
        final pulse = 0.5 + 0.5 * sin(_time * 2.2);
        drawGlow(
          canvas,
          _fx.glow!,
          sp + const Offset(0, -20),
          (lit ? 86 : 48) + 10 * pulse,
          (lit ? const Color(0xFFF2E7A8) : _venomBone).withValues(
            alpha: (lit ? 0.26 : 0.16) + 0.12 * pulse,
          ),
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
    final at = Offset(ward.censer.dx, ward.censer.dy - 86);

    // THE BOARD IS A RIDDLE NOW, not a recipe. It names the sleeper and says
    // what the answer must DO — and the larder shelf in the laboratory says
    // what each of the three things DOES, so the pair falls out of the two
    // together. Naming the ingredients here made the walk to the pot a
    // shopping trip.
    final title = potion.plague.toUpperCase();
    final lines = _wrapTiny(potion.clue, 230);
    var w = _tinyLabelWidth(title);
    for (final l in lines) {
      w = max(w, _tinyLabelWidth(l));
    }
    w += 22;
    final h = 36.0 + 15.0 * lines.length;

    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(0.02);
    final plank = Rect.fromCenter(center: Offset.zero, width: w, height: h);
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
    // A rule under the title, so the name and the riddle are two things.
    canvas.drawLine(
      Offset(-w / 2 + 10, -h / 2 + 19),
      Offset(w / 2 - 10, -h / 2 + 19),
      Paint()
        ..strokeWidth = 1
        ..color = _venomBronze.withValues(alpha: 0.4),
    );
    canvas.restore();

    for (final dx in [-w / 2 + 8, w / 2 - 8]) {
      canvas.drawLine(
        Offset(at.dx + dx, at.dy - h / 2 - 20),
        Offset(at.dx + dx, at.dy - h / 2),
        Paint()
          ..strokeWidth = 1.2
          ..color = _venomIron.withValues(alpha: 0.85),
      );
    }

    _drawTinyLabel(canvas, Offset(at.dx, at.dy - h / 2 + 6), title);
    if (done) {
      _drawTinyLabel(canvas, Offset(at.dx, at.dy - h / 2 + 24), 'ANSWERED');
      return;
    }
    for (var i = 0; i < lines.length; i++) {
      _drawTinyLabel(
        canvas,
        Offset(at.dx, at.dy - h / 2 + 24 + 15.0 * i),
        lines[i],
      );
    }
  }

  /// Break [text] into lines no wider than [maxWidth] at `_drawTinyLabel`'s
  /// size. A sign has to be cut to its own words; guessing a character count
  /// is how the first one hung off both ends of its plank.
  List<String> _wrapTiny(String text, double maxWidth) {
    final out = <String>[];
    var line = '';
    for (final word in text.split(' ')) {
      final tryLine = line.isEmpty ? word : '$line $word';
      if (line.isNotEmpty && _tinyLabelWidth(tryLine) > maxWidth) {
        out.add(line);
        line = word;
      } else {
        line = tryLine;
      }
    }
    if (line.isNotEmpty) out.add(line);
    return out;
  }

  /// THE LUSTRAL FONT. A basin on a plinth in the middle of the cloister,
  /// with the one thing the house asks for cut into its rim.
  ///
  /// It has to state its want before you have anything to give it — a basin
  /// you can only understand after brewing the right bottle is a basin you
  /// walk past three times.
  void _renderLustralFont(Canvas canvas, DungeonRoom room) {
    final at = room.lustralFont;
    if (at == null) return;
    final m = monastery;
    final done = m.cloisterOpen;
    // Once the parade has finished with it, the font goes down into the
    // floor and the corridor gets its middle back.
    if (done && m.parade < 0 && m.lustral <= 0) {
      _renderSpentFont(canvas, at);
      return;
    }

    // A FOOTPRINT WIDER THAN A CREATURE. At its first size the whole basin
    // sat behind whoever was standing at it — the same way the cross did —
    // and a fixture you cannot see while you are using it may as well not be
    // drawn. So: a stepped kerb on the floor, then the plinth, then a bowl
    // wide enough to show either side of a body.
    canvas.drawOval(
      Rect.fromCenter(center: at + const Offset(0, 30), width: 132, height: 46),
      Paint()..color = const Color(0xFF191C17),
    );
    canvas.drawOval(
      Rect.fromCenter(center: at + const Offset(0, 30), width: 132, height: 46),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _venomBronze.withValues(alpha: 0.35),
    );
    _stoneBlock(
      canvas,
      Rect.fromCenter(center: at + const Offset(0, 24), width: 46, height: 24),
    );
    _stoneBlock(
      canvas,
      Rect.fromCenter(center: at + const Offset(0, 8), width: 26, height: 28),
    );
    final bowl = Rect.fromCenter(center: at, width: 96, height: 38);
    canvas.drawOval(bowl, Paint()..color = const Color(0xFF23281F));
    canvas.drawOval(bowl.deflate(4), Paint()..color = const Color(0xFF070A08));
    // What is standing in it: sick green until the vial goes in, then clear.
    final water = done ? const Color(0xFFD8F0E4) : _venomSick;
    canvas.drawOval(
      bowl.deflate(9),
      Paint()..color = water.withValues(alpha: done ? 0.55 : 0.30),
    );
    for (var i = 0; i < 2; i++) {
      final k = ((_time * 0.4 + i * 0.5) % 1.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: at,
          width: (bowl.width - 18) * (0.25 + 0.7 * k),
          height: (bowl.height - 18) * (0.25 + 0.7 * k),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = water.withValues(alpha: 0.26 * (1 - k)),
      );
    }
    canvas.drawOval(
      bowl,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = (done ? _venomBronzeLit : _venomBronze).withValues(
          alpha: 0.95,
        ),
    );

    if (done) {
      // Spent, and saying so — no second errand here.
      _drawTinyLabel(canvas, Offset(at.dx, at.dy - 52), 'THE SEALS ARE OPEN');
      return;
    }

    // THE RIM INSCRIPTION. The clue, on the object that wants it.
    final lines = _wrapTiny(kPureVial.clue, 210);
    var w = 0.0;
    for (final l in lines) {
      w = max(w, _tinyLabelWidth(l));
    }
    final plate = Rect.fromCenter(
      center: Offset(at.dx, at.dy - 50),
      width: w + 20,
      height: 12.0 + 15.0 * lines.length,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(plate, const Radius.circular(3)),
      Paint()..color = const Color(0xFF2A2419),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(plate, const Radius.circular(3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = _venomBronze.withValues(alpha: 0.9),
    );
    for (var i = 0; i < lines.length; i++) {
      _drawTinyLabel(canvas, Offset(at.dx, plate.top + 3 + 15.0 * i), lines[i]);
    }

    // Lit while a hand is actually carrying the answer.
    if (m.carriedPotion == kPureVial.id && _fx.ready) {
      final pulse = 0.5 + 0.5 * sin(_time * 2.4);
      drawGlow(
        canvas,
        _fx.glow!,
        at,
        40 + 10 * pulse,
        const Color(0xFFD8F0E4).withValues(alpha: 0.18 + 0.12 * pulse),
      );
    }

    // THE POUR, and the seals letting go all down the corridor.
    if (m.lustral > 0) {
      final k = 1 - m.lustral;
      for (var i = 0; i < 3; i++) {
        final r = ((k * 1.5) - i * 0.2).clamp(0.0, 1.0);
        if (r <= 0) continue;
        canvas.drawOval(
          Rect.fromCenter(
            center: at,
            width: 40 + 700 * r,
            height: 16 + 200 * r,
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6 * (1 - r)
            ..color = const Color(0xFFD8F0E4).withValues(alpha: 0.42 * (1 - r)),
        );
      }
    }
  }

  /// WHAT IS LEFT WHERE THE FONT WAS. A ring of wet stone and a drain — so
  /// the room still remembers what happened there, and a player who comes
  /// back looking for the basin can see it did not simply vanish.
  ///
  /// Flat, and nothing to walk into: the plague is fought over this ground.
  void _renderSpentFont(Canvas canvas, Offset at) {
    canvas.drawOval(
      Rect.fromCenter(center: at + const Offset(0, 24), width: 128, height: 44),
      Paint()..color = const Color(0xFF14170F).withValues(alpha: 0.8),
    );
    canvas.drawOval(
      Rect.fromCenter(center: at + const Offset(0, 24), width: 128, height: 44),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _venomBronze.withValues(alpha: 0.28),
    );
    canvas.drawOval(
      Rect.fromCenter(center: at + const Offset(0, 24), width: 34, height: 14),
      Paint()..color = const Color(0xFF05070A),
    );
    for (var i = 0; i < 5; i++) {
      final a = i * 2 * pi / 5 + 0.4;
      canvas.drawLine(
        at + Offset(cos(a), sin(a) * 0.34) * 20 + const Offset(0, 24),
        at + Offset(cos(a), sin(a) * 0.34) * 58 + const Offset(0, 24),
        Paint()
          ..strokeWidth = 1.4
          ..color = const Color(0xFF2A3325).withValues(alpha: 0.7),
      );
    }
  }

  /// THE FIGHT, ON SCREEN. Three pips over the body, the mechanic on the
  /// floor, and a ring that closes as the gate runs out.
  ///
  /// Everything here exists because the fight is otherwise unreadable: a
  /// plague that has simply stopped taking damage looks like a bug, and a
  /// bulb on the floor looks like scenery unless it is plainly the only lit
  /// thing in the room while the boss is dark.
  void _renderPlagueFight(Canvas canvas, DungeonRoom room) {
    final m = monastery;
    if (m.fighting == null || room.id != 'ambulatory') return;
    final potion = brewById(m.fighting);
    if (potion == null) return;
    final body = _plagueBody;
    // The plague's own colour, not the brew's — what is on the floor belongs
    // to the thing that put it there.
    final col = _plagueColour(potion);

    // ── THE MARKS ──
    for (final mark in m.marks) {
      final at = mark.at;
      switch (potion.pot) {
        case CauldronReaction.rot:
          // A bulb swelling out of the floor, wanting a foot.
          if (mark.done) {
            canvas.drawCircle(
              at,
              16,
              Paint()..color = const Color(0xFF2A2016).withValues(alpha: 0.7),
            );
            break;
          }
          final pulse = 0.5 + 0.5 * sin(_time * 3.2 + at.dx * 0.02);
          canvas.drawCircle(
            at,
            26 + 5 * pulse,
            Paint()..color = col.withValues(alpha: 0.16),
          );
          canvas.drawCircle(
            at,
            13 + 2.5 * pulse,
            Paint()..color = const Color(0xFF6B8F3A),
          );
          canvas.drawCircle(
            at + const Offset(-3, -3),
            4.5,
            Paint()..color = col.withValues(alpha: 0.85),
          );
          for (var i = 0; i < 5; i++) {
            final a = i * 2 * pi / 5 + _time * 0.6;
            canvas.drawLine(
              at,
              at + Offset(cos(a), sin(a) * 0.6) * (17 + 3 * pulse),
              Paint()
                ..strokeWidth = 2
                ..color = const Color(0xFF3E5424).withValues(alpha: 0.8),
            );
          }
        case CauldronReaction.bloom:
          // A pod on its way home, with the path it is taking drawn ahead.
          if (mark.done) break;
          if (body != null) {
            canvas.drawLine(
              at,
              body.position,
              Paint()
                ..strokeWidth = 1
                ..color = col.withValues(alpha: 0.18),
            );
          }
          canvas.drawCircle(
            at,
            20,
            Paint()..color = col.withValues(alpha: 0.14),
          );
          canvas.drawCircle(at, 9, Paint()..color = col.withValues(alpha: 0.9));
          for (var i = 0; i < 8; i++) {
            final a = i * 2 * pi / 8 + _time * 1.6;
            canvas.drawCircle(
              at + Offset(cos(a), sin(a)) * 13,
              1.8,
              Paint()..color = const Color(0xFFEAF7B0).withValues(alpha: 0.7),
            );
          }
        case CauldronReaction.climb:
          // A pool. It fills as a body stands in it, and slides back if
          // one walks away.
          canvas.drawOval(
            Rect.fromCenter(center: at, width: 74, height: 40),
            Paint()..color = const Color(0xFF120C16).withValues(alpha: 0.9),
          );
          if (mark.fill > 0) {
            canvas.drawOval(
              Rect.fromCenter(
                center: at,
                width: 74 * mark.fill,
                height: 40 * mark.fill,
              ),
              Paint()..color = col.withValues(alpha: 0.8),
            );
          }
          canvas.drawOval(
            Rect.fromCenter(center: at, width: 74, height: 40),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = (mark.done ? const Color(0xFFB98FD6) : col).withValues(
                alpha: 0.85,
              ),
          );
        case CauldronReaction.pure:
          break;
      }
    }

    if (body == null) return;

    // ── THE BODY: THE SAME THING THAT CRAWLED IN ──
    //
    // Drawn here rather than by the shared enemy painter, at the size and in
    // the colour the crawl left it, because the point of the crawl is that
    // this IS that. A generic blob appearing where the animation ended makes
    // the whole arrival a cutscene about something else.
    final hue = _plagueColour(potion);
    final hit = body.hitFlash > 0
        ? Color.lerp(hue, Colors.white, body.hitFlash.clamp(0.0, 1.0))!
        : hue;
    _drawInvadeHead(canvas, body.position, hit, _kPlagueScale);
    // Bulk under the tendrils, so it has weight the crawl's head did not.
    canvas.drawCircle(
      body.position,
      body.radius * 0.9,
      Paint()..color = Color.lerp(hue, const Color(0xFF05070A), 0.45)!,
    );
    canvas.drawCircle(
      body.position,
      body.radius * 0.9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = hit.withValues(alpha: 0.9),
    );
    // The bar it is on, read straight off the body.
    final frac = (body.hp / body.maxHp).clamp(0.0, 1.0);
    final barAt = body.position - const Offset(0, 44);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: barAt, width: 68, height: 7),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF0B0D0A).withValues(alpha: 0.85),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barAt.dx - 33, barAt.dy - 2.5, 66 * frac, 5),
        const Radius.circular(2),
      ),
      Paint()..color = hue,
    );

    final head = body.position - const Offset(0, 56);

    // ── THREE PIPS ── how much of the thing is actually left, which its own
    // health bar cannot say: that bar is one third of a plague.
    for (var i = 0; i < kPlagueBars; i++) {
      final at = Offset(head.dx + (i - 1) * 20, head.dy - 12);
      final spent = i >= m.bars;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: at, width: 15, height: 8),
          const Radius.circular(2),
        ),
        Paint()
          ..color = spent
              ? const Color(0xFF241E28).withValues(alpha: 0.85)
              : col.withValues(alpha: 0.95),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: at, width: 15, height: 8),
          const Radius.circular(2),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = _venomBronze.withValues(alpha: 0.8),
      );
    }

    // ── CLOSED ── a shell over it, and a ring counting the gate down.
    if (m.gated) {
      final shell = 0.5 + 0.5 * sin(_time * 4.0);
      canvas.drawCircle(
        body.position,
        34 + 3 * shell,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = _venomBone.withValues(alpha: 0.5 + 0.2 * shell),
      );
      canvas.drawCircle(
        body.position,
        34,
        Paint()..color = const Color(0xFF0B0D0A).withValues(alpha: 0.45),
      );
      final left = (m.gateLeft / _kGateSeconds).clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: body.position, radius: 42),
        -pi / 2,
        2 * pi * left,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round
          ..color = (left < 0.25 ? const Color(0xFFD86A4A) : col).withValues(
            alpha: 0.9,
          ),
      );
      final undone = m.marks.where((k) => !k.done).length;
      _drawTinyLabel(
        canvas,
        Offset(body.position.dx, head.dy - 34),
        switch (potion.pot) {
          CauldronReaction.rot => 'STAND ON THEM  ·  $undone',
          CauldronReaction.bloom => 'CUT THEM OFF  ·  $undone',
          CauldronReaction.climb => 'STOPPER THEM  ·  $undone',
          CauldronReaction.pure => '',
        },
      );
    }

    // A bar breaking or coming back.
    if (m.gateFlash > 0) {
      final k = 1 - m.gateFlash;
      canvas.drawCircle(
        body.position,
        30 + 130 * k,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8 * (1 - k)
          ..color = col.withValues(alpha: 0.5 * (1 - k)),
      );
    }
  }

  /// A RELIQUARY ON THE STONES. What a plague leaves when it comes apart —
  /// and the only thing in the cloister worth walking back for.
  void _renderRelics(Canvas canvas, DungeonRoom room) {
    if (room.id != 'ambulatory') return;
    final m = monastery;
    for (final p in kPlaguePotions) {
      final at = m.relicAt[p.id];
      if (at == null) continue;
      final col = _brewColour(p);
      final lift = sin(_time * 1.8 + at.dx * 0.02) * 3.0;
      final c = Offset(at.dx, at.dy + lift);
      // Halo on the floor, so it is findable across a dark corridor.
      canvas.drawCircle(
        Offset(at.dx, at.dy + 12),
        22 + 5 * sin(_time * 1.6),
        Paint()..color = col.withValues(alpha: 0.13),
      );
      // A little house-shaped casket on a foot.
      final body = Path()
        ..moveTo(c.dx - 11, c.dy + 10)
        ..lineTo(c.dx - 11, c.dy - 2)
        ..lineTo(c.dx, c.dy - 13)
        ..lineTo(c.dx + 11, c.dy - 2)
        ..lineTo(c.dx + 11, c.dy + 10)
        ..close();
      canvas.drawPath(body, Paint()..color = const Color(0xFF1B1E1A));
      canvas.drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = _venomBronzeLit,
      );
      // The brew's own light behind a grille.
      canvas.drawCircle(c + const Offset(0, 1), 4.6, Paint()..color = col);
      for (final dx in const [-3.0, 0.0, 3.0]) {
        canvas.drawLine(
          Offset(c.dx + dx, c.dy - 4),
          Offset(c.dx + dx, c.dy + 6),
          Paint()
            ..strokeWidth = 1
            ..color = const Color(0xFF1B1E1A),
        );
      }
    }
  }

  /// THE POUR LANDING. Each brew does its own thing on the plague, so what
  /// went in is legible from across the room — including, and especially,
  /// when it was the wrong bottle.
  void _renderPourOnPlague(Canvas canvas, DungeonRoom room) {
    final m = monastery;
    if (m.pour <= 0 || room.ward == null) return;
    final potion = brewById(m.pourPotion);
    if (potion == null) return;
    final at = m.pourAt;
    final k = 1 - m.pour; // 0 → 1 over the beat
    final col = _brewColour(potion);

    // The bottle's contents arriving: a stream down onto the heart.
    if (k < 0.34) {
      final f = k / 0.34;
      canvas.drawLine(
        Offset(at.dx, at.dy - 70 + 70 * f),
        Offset(at.dx, at.dy - 60 + 62 * f),
        Paint()
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = col.withValues(alpha: 0.9),
      );
      return;
    }
    final f = ((k - 0.34) / 0.66).clamp(0.0, 1.0);
    switch (potion.pot) {
      case CauldronReaction.pure:
        // Poured on a sleeper it simply runs off — a wash and a shrug, so
        // the wrong-bottle complication reads as "nothing happened" on
        // purpose.
        for (var i = 0; i < 10; i++) {
          final t = ((f * 1.4 + i * 0.1) % 1.0);
          canvas.drawCircle(
            at + Offset((i * 9.1) % 56 - 28, 6 + 34 * t),
            2.2 * (1 - t),
            Paint()
              ..color = const Color(
                0xFFD8F0E4,
              ).withValues(alpha: 0.55 * (1 - t)),
          );
        }
      case CauldronReaction.bloom:
        // FLOWERS. Stems shoot off the heart, open, and shed spores.
        for (var i = 0; i < 9; i++) {
          final ang = (i / 9) * 2 * pi + 0.3;
          final len = 16 + 46 * Curves.easeOutCubic.transform(f);
          final tip = at + Offset(cos(ang), sin(ang) * 0.62) * len;
          canvas.drawLine(
            at,
            tip,
            Paint()
              ..strokeWidth = 2.2
              ..color = const Color(
                0xFF2E8B4A,
              ).withValues(alpha: 0.85 * (1 - f * 0.4)),
          );
          final open = ((f - 0.35) / 0.65).clamp(0.0, 1.0);
          if (open <= 0) continue;
          for (var pet = 0; pet < 5; pet++) {
            final pa = (pet / 5) * 2 * pi + ang;
            canvas.drawCircle(
              tip + Offset(cos(pa), sin(pa)) * 4.2 * open,
              3.0 * open,
              Paint()..color = col.withValues(alpha: 0.9 * (1 - f * 0.3)),
            );
          }
        }
        for (var i = 0; i < 20; i++) {
          final sp = ((f * 1.4 + i * 0.07) % 1.0);
          final ang = i * 2.399;
          canvas.drawCircle(
            at +
                Offset(cos(ang), sin(ang) * 0.7) * (24 + 70 * sp) -
                Offset(0, 46 * sp),
            1.8 * (1 - sp),
            Paint()
              ..color = const Color(
                0xFFDCEB9A,
              ).withValues(alpha: 0.7 * (1 - sp)),
          );
        }
      case CauldronReaction.climb:
        // BLACK, AND CLIMBING THE PLAGUE. Bands sheeting up over the heart,
        // each with a lit edge so the shape survives a dark room.
        for (var i = 0; i < 5; i++) {
          final band = ((f * 1.5) - i * 0.12).clamp(0.0, 1.0);
          if (band <= 0) continue;
          final r = RRect.fromRectAndRadius(
            Rect.fromLTWH(
              at.dx - 26 + i * 2.0,
              at.dy + 22 - 66 * band,
              52 - i * 4.0,
              66 * band,
            ),
            const Radius.circular(9),
          );
          canvas.drawRRect(
            r,
            Paint()
              ..color = Color.lerp(
                const Color(0xFF6B4B86),
                const Color(0xFF0A0810),
                0.42 + 0.11 * i,
              )!.withValues(alpha: 0.8 - 0.09 * i),
          );
          canvas.drawLine(
            Offset(r.left + 4, r.top),
            Offset(r.right - 4, r.top),
            Paint()
              ..strokeWidth = 2
              ..strokeCap = StrokeCap.round
              ..color = const Color(
                0xFFB98FD6,
              ).withValues(alpha: 0.7 - 0.11 * i),
          );
        }
        for (var i = 0; i < 12; i++) {
          final t = ((f * 1.2 + i * 0.083) % 1.0);
          canvas.drawCircle(
            Offset(at.dx - 22 + (i * 4.1) % 44, at.dy + 20 - 68 * t),
            1.6 + 1.4 * (1 - t),
            Paint()
              ..color = const Color(
                0xFF9A79B8,
              ).withValues(alpha: 0.6 * (1 - t)),
          );
        }
      case CauldronReaction.rot:
        // ROOTS UP, THEN GONE. They thread out and blacken behind themselves.
        for (var i = 0; i < 7; i++) {
          final ang = -pi / 2 + (i - 3) * 0.42;
          final grow = Curves.easeOutQuad.transform(
            ((f * 1.6) - i * 0.05).clamp(0.0, 1.0),
          );
          final decay = ((f - 0.5) / 0.5).clamp(0.0, 1.0);
          if (grow <= 0) continue;
          final path = Path()..moveTo(at.dx, at.dy);
          for (var seg = 1; seg <= 6; seg++) {
            final t = grow * seg / 6;
            final wob = sin(seg * 1.7 + i) * 9 * t;
            path.lineTo(
              at.dx + cos(ang) * 62 * t + wob,
              at.dy + sin(ang) * 52 * t,
            );
          }
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.0 * (1 - decay * 0.6)
              ..strokeCap = StrokeCap.round
              ..color = Color.lerp(
                const Color(0xFF6B8F3A),
                const Color(0xFF2A2016),
                decay,
              )!.withValues(alpha: 0.9 - 0.55 * decay),
          );
        }
        for (var i = 0; i < 14; i++) {
          final t = (((f - 0.45) / 0.55).clamp(0.0, 1.0) + i * 0.06) % 1.0;
          if (f < 0.45) break;
          canvas.drawCircle(
            at + Offset((i * 7.3) % 60 - 30, 10 + 30 * t),
            1.7 * (1 - t),
            Paint()
              ..color = const Color(
                0xFF3A2E1E,
              ).withValues(alpha: 0.7 * (1 - t)),
          );
        }
    }
  }

  /// The bottle in hand, wearing its own brew's colour — the same colour it
  /// had in the pot and will have on the plague.
  void _renderCarriedBottle(Canvas canvas) {
    final m = monastery;
    final a = active;
    if (a == null || !a.alive) return;
    final held = m.carriedPotion;
    final relic = m.carriedRelic;
    if (held == null && relic == null) return;
    final at = a.position + Offset(16, -30 + sin(_time * 3.0) * 2.0);
    if (relic != null) {
      final p = brewById(relic);
      if (p == null) return;
      final col = _brewColour(p);
      canvas.drawCircle(at, 13, Paint()..color = col.withValues(alpha: 0.18));
      final body = Path()
        ..moveTo(at.dx - 8, at.dy + 8)
        ..lineTo(at.dx - 8, at.dy - 2)
        ..lineTo(at.dx, at.dy - 10)
        ..lineTo(at.dx + 8, at.dy - 2)
        ..lineTo(at.dx + 8, at.dy + 8)
        ..close();
      canvas.drawPath(body, Paint()..color = const Color(0xFF1B1E1A));
      canvas.drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _venomBronzeLit,
      );
      canvas.drawCircle(at, 3.4, Paint()..color = col);
      return;
    }
    final p = brewById(held);
    if (p == null) return;
    final col = _brewColour(p);
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(sin(_time * 1.4) * 0.10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-6.5, -9, 13, 21),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFF20302C).withValues(alpha: 0.92),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-5, -2, 10, 13),
        const Radius.circular(4),
      ),
      Paint()..color = col.withValues(alpha: 0.92),
    );
    canvas.drawRect(
      const Rect.fromLTWH(-3.5, -13, 7, 5),
      Paint()..color = _venomBronze,
    );
    canvas.restore();
  }

  /// A brew's colour, used in the pot, in the bottle, on the plague and on
  /// the relic — one identity in every place it is seen.
  Color _brewColour(PlaguePotion p) => switch (p.pot) {
    CauldronReaction.pure => const Color(0xFFD8F0E4),
    CauldronReaction.bloom => const Color(0xFFB6E24A),
    CauldronReaction.climb => const Color(0xFF6B4B86),
    CauldronReaction.rot => const Color(0xFF6E7C33),
  };

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
    final allowed = contributionsAllowedFor(element);
    var have = 0, used = 0;
    for (final c in creatures) {
      if (c.member.element != element) continue;
      have += allowed;
      used += min(allowed, monastery.given[c.member.instanceId] ?? 0);
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

    // THE REACTION. Three pairs, three unmistakably different things — this
    // is the receipt for a give, and it is the reason the pot is not a
    // button.
    if (m.reaction > 0 && m.reactionKind != null) {
      _renderCauldronReaction(canvas, c, m.reactionKind!, 1 - m.reaction);
    }

    // THE BOTTLES, on their own bench along from the pot. They stand empty
    // from the moment you walk in, which is how the room states its own
    // shape without a word: four vessels, and you can count them.
    final bench = c + const Offset(200, 0);
    canvas.drawRect(
      Rect.fromLTWH(bench.dx - 78, bench.dy + 13, 156, 7),
      Paint()..color = const Color(0xFF2A2419),
    );
    canvas.drawRect(
      Rect.fromLTWH(bench.dx - 78, bench.dy + 13, 156, 2),
      Paint()..color = _venomBronze.withValues(alpha: 0.55),
    );
    for (var i = 0; i < kAllBrews.length; i++) {
      final potion = kAllBrews[i];
      final at = Offset(bench.dx - 60 + i * 40.0, bench.dy);
      final full =
          m.bottled.contains(potion.id) || m.carriedPotion == potion.id;
      final gone = m.woken.contains(potion.id) || m.slain.contains(potion.id);
      final inHand = m.carriedPotion == potion.id;
      final col = _brewColour(potion);
      final glass = RRect.fromRectAndRadius(
        Rect.fromCenter(center: at, width: 15, height: 22),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        glass,
        Paint()..color = const Color(0xFF0B0F0B).withValues(alpha: 0.85),
      );
      if (full) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(at.dx - 5.5, at.dy - 5, 11, 15),
            const Radius.circular(3),
          ),
          Paint()..color = col.withValues(alpha: inHand ? 0.28 : 0.92),
        );
      }
      canvas.drawRRect(
        glass,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = (gone ? _venomIron : _venomBronze).withValues(
            alpha: gone ? 0.5 : 0.9,
          ),
      );
      canvas.drawRect(
        Rect.fromCenter(center: Offset(at.dx, at.dy - 14), width: 7, height: 5),
        Paint()..color = _venomBronzeLit.withValues(alpha: gone ? 0.4 : 0.9),
      );
      if (full && !inHand) {
        canvas.drawCircle(
          at,
          15 + 3 * sin(_time * 2.6 + i),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = col.withValues(alpha: 0.34),
        );
      }
    }
  }

  /// WHAT THE POT DOES WHEN A PAIR LANDS IN IT. One per recipe, and they are
  /// meant to be tellable apart at a glance and from across the room.
  void _renderCauldronReaction(
    Canvas canvas,
    Offset c,
    CauldronReaction kind,
    double k,
  ) {
    final mouth = Offset(c.dx, c.dy - 12);
    switch (kind) {
      case CauldronReaction.pure:
        // IT GOES CLEAR AND STOPS. The one reaction that is an absence: the
        // surface flattens to glass, a ring of it lifts, and everything the
        // pot was doing quietly ceases. On a planet made of drifting spores
        // and crawling rot, stillness is the loudest thing available.
        final settle = Curves.easeOutCubic.transform(k);
        canvas.drawOval(
          Rect.fromCenter(center: mouth, width: 66, height: 19),
          Paint()
            ..color = Color.lerp(
              const Color(0xFF4A5A3A),
              const Color(0xFFD8F0E4),
              settle,
            )!.withValues(alpha: 0.9),
        );
        for (var i = 0; i < 3; i++) {
          final r = ((settle * 1.5) - i * 0.22).clamp(0.0, 1.0);
          if (r <= 0) continue;
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(mouth.dx, mouth.dy - 26 * r),
              width: 30 + 54 * r,
              height: 9 + 16 * r,
            ),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0 * (1 - r)
              ..color = const Color(
                0xFFE6FFF4,
              ).withValues(alpha: 0.6 * (1 - r)),
          );
        }
        // A single held highlight on dead-flat liquid.
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(mouth.dx - 12, mouth.dy - 2),
            width: 18 * settle,
            height: 4 * settle,
          ),
          Paint()..color = Colors.white.withValues(alpha: 0.5 * settle),
        );
      case CauldronReaction.bloom:
        // Luminous flowers erupt, open, and shed sparkling spores.
        for (var i = 0; i < 7; i++) {
          final ang = -pi / 2 + (i - 3) * 0.34;
          final grow = Curves.easeOutBack.transform(
            ((k * 1.7) - i * 0.06).clamp(0.0, 1.0),
          );
          if (grow <= 0) continue;
          final tip = mouth + Offset(cos(ang), sin(ang)) * (46 * grow);
          canvas.drawLine(
            mouth,
            tip,
            Paint()
              ..strokeWidth = 2.0
              ..color = const Color(0xFF2E8B4A).withValues(alpha: 0.9),
          );
          final open = ((k - 0.3) / 0.7).clamp(0.0, 1.0);
          for (var pet = 0; pet < 5; pet++) {
            final pa = (pet / 5) * 2 * pi + i;
            canvas.drawCircle(
              tip + Offset(cos(pa), sin(pa)) * 4.6 * open,
              3.2 * open,
              Paint()..color = const Color(0xFFB6E24A).withValues(alpha: 0.92),
            );
          }
        }
        for (var i = 0; i < 22; i++) {
          final sp = ((k * 1.3 + i * 0.045) % 1.0);
          canvas.drawCircle(
            mouth +
                Offset(sin(i * 2.4 + k * 3) * (10 + 40 * sp), -20 - 62 * sp),
            1.9 * (1 - sp),
            Paint()
              ..color = const Color(
                0xFFEAF7B0,
              ).withValues(alpha: 0.8 * (1 - sp)),
          );
        }
      case CauldronReaction.climb:
        // IT GOES BLACK AND CLIMBS. Drawn as near-black on a black floor the
        // whole thing was invisible in the shot — so the substance keeps its
        // dark violet body and every climbing tongue carries a lit meniscus,
        // which is what actually reads as liquid going the wrong way.
        final rise = Curves.easeInOutCubic.transform(k);
        for (var i = 0; i < 7; i++) {
          final x = c.dx - 32 + i * 10.7;
          final h = 62 * rise * (0.55 + 0.45 * sin(i * 1.9 + k * 4));
          final top = mouth.dy + 6 - h;
          final p = Path()
            ..moveTo(x - 4.6, mouth.dy + 8)
            ..lineTo(x - 3.0, top + 3)
            ..quadraticBezierTo(x, top - 3, x + 3.0, top + 3)
            ..lineTo(x + 4.6, mouth.dy + 8)
            ..close();
          canvas.drawPath(
            p,
            Paint()
              ..color = Color.lerp(
                const Color(0xFF6B4B86),
                const Color(0xFF0D0A12),
                0.45 + 0.07 * i,
              )!.withValues(alpha: 0.95),
          );
          // The lit head of the tongue — the only bright thing in the beat.
          canvas.drawCircle(
            Offset(x, top),
            2.6,
            Paint()..color = const Color(0xFFB98FD6).withValues(alpha: 0.9),
          );
        }
        canvas.drawOval(
          Rect.fromCenter(
            center: mouth,
            width: 74 * (0.7 + 0.3 * rise),
            height: 22 * (0.7 + 0.3 * rise),
          ),
          Paint()..color = const Color(0xFF2B1F38).withValues(alpha: 0.95),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: mouth,
            width: 74 * (0.7 + 0.3 * rise),
            height: 22 * (0.7 + 0.3 * rise),
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = const Color(0xFF8B6BA6).withValues(alpha: 0.7),
        );
        for (var i = 0; i < 10; i++) {
          final t = ((k * 1.4 + i * 0.1) % 1.0);
          canvas.drawCircle(
            Offset(c.dx - 26 + (i * 5.6) % 52, mouth.dy - 62 * t),
            1.5 + 1.6 * (1 - t),
            Paint()
              ..color = const Color(
                0xFF9A79B8,
              ).withValues(alpha: 0.55 * (1 - t)),
          );
        }
      case CauldronReaction.rot:
        // Roots thread up through the sludge and rot away as fast as they
        // grew — the whole beat is grow-then-blacken, in one gesture.
        final decay = ((k - 0.45) / 0.55).clamp(0.0, 1.0);
        for (var i = 0; i < 6; i++) {
          final ang = -pi / 2 + (i - 2.5) * 0.30;
          final grow = Curves.easeOutQuad.transform(
            ((k * 1.9) - i * 0.05).clamp(0.0, 1.0),
          );
          if (grow <= 0) continue;
          final path = Path()..moveTo(mouth.dx, mouth.dy);
          for (var seg = 1; seg <= 6; seg++) {
            final t = grow * seg / 6;
            path.lineTo(
              mouth.dx + cos(ang) * 50 * t + sin(seg * 1.6 + i) * 7 * t,
              mouth.dy + sin(ang) * 44 * t,
            );
          }
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.0 * (1 - decay * 0.7)
              ..strokeCap = StrokeCap.round
              ..color = Color.lerp(
                const Color(0xFF6B8F3A),
                const Color(0xFF241C12),
                decay,
              )!.withValues(alpha: 0.95 - 0.6 * decay),
          );
        }
        if (decay > 0) {
          for (var i = 0; i < 12; i++) {
            final t = ((decay * 1.3 + i * 0.08) % 1.0);
            canvas.drawCircle(
              Offset(mouth.dx - 24 + (i * 4.3) % 48, mouth.dy + 18 * t),
              1.6 * (1 - t),
              Paint()
                ..color = const Color(
                  0xFF33291B,
                ).withValues(alpha: 0.7 * (1 - t)),
            );
          }
        }
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
