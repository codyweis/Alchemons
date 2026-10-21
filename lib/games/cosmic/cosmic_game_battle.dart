part of 'cosmic_game.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  THE BATTLE: two players, two Alchemons each on the field
//
//  Player against player, with the combat every other mode uses. Each side
//  brings four and fights two at a time. The rules (user, 2026-10-19):
//
//  • Auto attacks and specials fire on their own, a special as soon as it is
//    ready and in reach (user, later the same day: tapping them meant "too
//    busy trying to tap it as fast as I can and not paying attention").
//  • A fallen Alchemon's place is filled from the bench on its own, a
//    moment after it falls, by the healthiest one there.
//  • A player decides who their side goes for (a focus) and when to swap a
//    living one out for one on the bench: [kBattleSwaps] a fight. It goes
//    back with the health and special charge it had, as in survival.
//  • A side with nobody left on the field has lost, bench or no bench: both
//    falling at once, or the bench run out.
//  • Overtime, the last 30 seconds ([kBattleOvertime]): heals and shields
//    land at less than half, and blows grow harder to the end, so two sides
//    that cannot finish each other still do. At the limit, the side with
//    the most health left wins.
//  • No Mystics: their special is their world, which only Survival runs.
//  • A Fire kin's phoenix, which saves the ship in open space, saves the
//    first of its side's Alchemons that would fall.
//
//  Both sides take their turn the way the wild Alchemon does in a duel
//  (cosmic_game_duel.dart): for the length of a side's turn its Alchemons
//  are the only companions, the other side's stand in the enemy list as
//  combat bodies, and what those bodies took is carried onto them after.
//  Both sides go through the same code, so neither player's Alchemons play
//  by different rules, and which side goes first alternates by frame.
// ─────────────────────────────────────────────────────────────────────────────

/// Alchemons a side fights with at once.
const int kBattleFieldSpots = 2;

/// Alchemons a side brings.
const int kBattleTeamSize = 4;

/// Times a side may swap a living Alchemon out. Filling a fallen one's place
/// is free.
const int kBattleSwaps = 2;

/// A fight that runs this long goes to the side with the most health left.
const double kBattleTimeLimit = 90.0;

/// What overtime does, from [at] seconds: heals and shields land at [heal]
/// of their size, and blows grow until they are [damage] times as hard at
/// the limit.
class BattleOvertime {
  const BattleOvertime({this.at = 60, this.heal = 1, this.damage = 1});

  final double at;
  final double heal;
  final double damage;
}

/// The battle's overtime: the last 30 seconds. Set from the harness
/// (2026-10-19, 400 mixed fights): time-ups 13% → 2%, median length and
/// every family's win share unchanged. Trimming heals alone did little —
/// the stalls were Horns behind shields — and so shields are trimmed too.
const BattleOvertime kBattleOvertime = BattleOvertime(
  at: 60,
  heal: 0.4,
  damage: 2.6,
);

/// What a Wing beam's heal (Crystal's and Light's lifesteal, meant for the
/// orb) gives back to the caster in a battle.
const double kBattleBeamSelfHealShare = 0.3;

/// Creature-on-creature damage in a battle, on top of the duel's own scale:
/// set so a fight lasts about 47 s (user 2026-10-20 asked for 10–20% longer
/// than the 42 s fights were then). Raised from 0.85 the same day, after the
/// family rebuild (Wing bolts one hit per body, focus beams) left fights
/// 30% longer and a quarter of them timing out: real catalog species, 500
/// mixed fights, average 45 s at P50 and 49 s at P80, time-ups 5% and 10%
/// (test/gem_battle_ladder_test.dart 'species balance', LADDER_SCALE).
const double kBattleDamageScale = 1.3;

/// How long a fallen Alchemon's place stays empty before the bench fills it,
/// so the fall is seen.
const double kBattleReplaceDelay = 0.8;

/// How long a summoned Alchemon gathers before it acts. Until then it can
/// neither be hit nor hit back, but it holds its place on the field.
const double kBattleArrival = 0.8;

/// The floor the fight is held on: an oval, taller than it is wide, so it
/// fills an upright phone with the two sides at its ends.
const double kBattleArenaRx = kBattleFloorHalfWidth;
const double kBattleArenaRy = kBattleFloorHalfHeight;

/// The camera follows the fight: it frames everyone on the field, but
/// never closer than this much of the floor's height, nor wider than all
/// of it.
const double kBattleCloseFrame = 640.0;

/// How quickly an Alchemon changes pace or direction (u/s²): the dungeon's
/// eased stop and start.
const double kBattleAcceleration = 900.0;

/// How fast a creature travels a throw (an Air Mane's gust): nine tenths
/// of it in about a sixth of a second.
const double kBattleThrowRate = 14.0;

/// The step an auto attack puts into the body (u/s): a lunge in for a Horn
/// or a Mane, a kick back for the rest.
const double kBattleLunge = 150.0;
const double kBattleRecoil = 55.0;

/// Where the two sides start, either side of the middle.
const double kBattleStartDepth = 330.0;
const double kBattleSpotGap = 110.0;

/// Side 0 casts from slots 20–23 and side 1 from 30–33: clear of the
/// party's, the ship's (-1) and the wild Alchemon's ([kWildCasterSlot]).
const int kBattleSlotBase = 20;

int battleSlotFor(int side, int creature) =>
    kBattleSlotBase + side * 10 + creature;

/// Whether [member] may be brought to a battle at all.
bool battleAllows(CosmicPartyMember member) =>
    castsSpecialOutsideSurvival(member.family);

/// Whether [member] has a special to tap: the passive-only ones have none.
bool battleHasSpecial(CosmicPartyMember member) =>
    castsSpecialOutsideSurvival(member.family) &&
    !isPassiveOnlyCosmicAbility(member.family, member.element);

/// One of a side's four, on the field or off it.
class BattleCreature {
  BattleCreature(this.member);

  final CosmicPartyMember member;

  /// Its health, as a share of its pool, while it is off the field. On the
  /// field [body] holds it.
  double hpFraction = 1.0;

  /// Its special's wait when it last left the field.
  double? specialCooldown;

  /// A Fire kin's phoenix fires once a fight.
  bool phoenixSpent = false;

  /// The battle clock when its special last went off, for the HUD.
  double lastSpecialAt = -1;

  // How far it has walked since its last step on the floor.
  Offset? _lastAt;
  double _stride = 0;

  bool fallen = false;

  /// The creature itself, while it is on the field.
  CosmicCompanion? body;

  bool get onField => body != null;

  /// Its health share now, wherever it is.
  double get healthShare {
    if (fallen) return 0;
    final b = body;
    return b == null ? hpFraction : b.currentHp / b.maxHp;
  }
}

enum BattleEventKind { summon, swap, fall, phoenix, special }

class BattleEvent {
  const BattleEvent(this.at, this.side, this.kind, this.creature);

  final double at;
  final int side;
  final BattleEventKind kind;
  final int creature;
}

enum BattleEnd { fieldEmpty, timeUp }

class BattleResult {
  const BattleResult({required this.winner, required this.end, required this.at});

  /// 0 or 1; null is a draw.
  final int? winner;
  final BattleEnd end;
  final double at;
}

/// One player's side of a battle.
class BattleSide {
  BattleSide._(this.index, List<CosmicPartyMember> team, {required this.auto})
    : creatures = [
        for (var i = 0; i < team.length; i++)
          BattleCreature(team[i].withSlot(battleSlotFor(index, i))),
      ];

  /// 0 starts below the middle, 1 above it.
  final int index;
  final List<BattleCreature> creatures;

  /// Which creature stands in each field place, by its index; null is empty.
  final List<int?> spots = List<int?>.filled(kBattleFieldSpots, null);

  int swapsLeft = kBattleSwaps;

  /// True for the computer: it picks its own focus and pulls out a badly
  /// hurt Alchemon on its own.
  bool auto;

  /// How long the computer waits before it swaps.
  double thinkDelay = 1.0;

  /// Below this health share the computer swaps an Alchemon out...
  double swapBelow = 0.3;

  /// ...for a bench one with at least this much.
  double swapFor = 0.7;

  /// The other side's creature (by index) this side's Alchemons go for, a
  /// player's tap or the computer's pick; null fights whoever is nearest.
  int? focus;
  double _focusT = 0;

  double _thinkT = 0;
  double _replaceT = 0;
  final _WildSide _state = _WildSide();
  final List<Projectile> projectiles = CappedProjectileList();
  final Map<CosmicCompanion, _CombatBody> _bodies = {};
  final Map<int, CosmicCompanion> _acting = {};
  final Map<CosmicCompanion, CosmicCompanion> _targets = {};

  /// Alchemons on their way back to the bench, drawn coming apart.
  final List<CosmicCompanion> _leaving = [];

  /// The creature in field place [spot], if one stands there.
  BattleCreature? at(int spot) {
    final i = spots[spot];
    return i == null ? null : creatures[i];
  }

  Iterable<BattleCreature> get onField sync* {
    for (final i in spots) {
      if (i != null) yield creatures[i];
    }
  }

  /// Bench creatures that can still be summoned.
  Iterable<int> get bench sync* {
    for (var i = 0; i < creatures.length; i++) {
      final c = creatures[i];
      if (!c.fallen && !c.onField) yield i;
    }
  }

  bool get anyOnField => spots.any((s) => s != null);

  /// The side's health, as a share of all it brought.
  double get healthShare =>
      creatures.fold(0.0, (sum, c) => sum + c.healthShare) / creatures.length;
}

class CosmicBattle {
  CosmicBattle._({
    required this.center,
    required this.sides,
    required this.damageScale,
    required this.hitGrace,
    required this.arena,
    required this.overtime,
  }) : floor = battleFloorFor(arena, rx: kBattleArenaRx, ry: kBattleArenaRy);

  final Offset center;
  final List<BattleSide> sides;

  /// Which arena it is fought in (models/battle_arenas.dart): the host's.
  /// Looks only.
  final String arena;

  /// The floor's art, which the fight's steps, blows and specials touch.
  final BattleFloor floor;

  /// The bands of the screen the HUD covers, in logical pixels: the floor
  /// is framed in what is left. The battle screen sets them.
  EdgeInsets viewInsets = EdgeInsets.zero;

  /// Creature-on-creature damage on top of the duel's own scale: set by the
  /// battle harness so a fight lasts long enough for specials to matter.
  final double damageScale;

  /// What changes once the fight runs long, so two sides that cannot
  /// finish each other still come to an end.
  final BattleOvertime overtime;

  /// Whether the fight has run into overtime.
  bool get inOvertime => clock >= overtime.at;

  /// Creature-on-creature damage now: [damageScale], rising through
  /// overtime to [BattleOvertime.damage] at the time limit.
  double get damageNow {
    if (!inOvertime || overtime.damage == 1) return damageScale;
    final u = ((clock - overtime.at) / (kBattleTimeLimit - overtime.at))
        .clamp(0.0, 1.0);
    return damageScale * (1 + (overtime.damage - 1) * u);
  }

  /// What share of a heal lands now: all of it, or in overtime
  /// [BattleOvertime.heal].
  double get healNow => inOvertime ? overtime.heal : 1;

  /// Whether a hit leaves an Alchemon briefly untouchable, as it does in
  /// open space where a horde can swarm it. Off, every hit lands.
  final bool hitGrace;

  /// Where the camera looks and how much of the floor's height it frames,
  /// eased after the fight; null until the first frame frames it.
  Offset? _camAt;
  double _camHeight = 0;

  double clock = 0;
  BattleResult? result;

  /// How fast the fight runs against the real clock: slowed for the
  /// finishing blows and the moment after them, so the end is seen.
  double timeScale = 1;

  /// Real seconds since it began, and when it ended.
  double _real = 0;
  double? _endedReal;
  double _slowSpent = 0;

  /// Real seconds since it ended, or null while it runs.
  double? get sinceEnd => _endedReal == null ? null : _real - _endedReal!;
  final List<BattleEvent> log = [];
  int _frame = 0;

  bool get over => result != null;

  /// The bench end of [side]'s half: where a swapped-out Alchemon goes.
  Offset benchAt(int side) =>
      center + Offset(0, (side == 0 ? 1 : -1) * (kBattleArenaRy + 80));

  /// Where field place [spot] of [side] starts. Each player sees their own
  /// side at the bottom, so side 1's places run the other way.
  Offset spotAt(int side, int spot) {
    final x = (spot == 0 ? -kBattleSpotGap : kBattleSpotGap) * (side == 0 ? 1 : -1);
    final y = side == 0 ? kBattleStartDepth : -kBattleStartDepth;
    return center + Offset(x, y);
  }
}

extension CosmicGameBattle on CosmicGame {
  CosmicBattle? get battle => _battle;

  /// Starts a battle of [home] (side 0) against [away] (side 1), each 1–4
  /// Alchemons and no Mystics; the first two of each lead. The open world
  /// stands still until [endBattle].
  CosmicBattle startBattle({
    required List<CosmicPartyMember> home,
    required List<CosmicPartyMember> away,
    bool homeAuto = false,
    bool awayAuto = true,
    Offset? center,
    double damageScale = kBattleDamageScale,
    bool hitGrace = false,
    String arena = 'obsidian',
    BattleOvertime overtime = kBattleOvertime,
  }) {
    for (final team in [home, away]) {
      if (team.isEmpty || team.length > kBattleTeamSize) {
        throw ArgumentError('A side brings 1 to $kBattleTeamSize Alchemons.');
      }
      if (!team.every(battleAllows)) {
        throw ArgumentError('Mystics cannot be brought to a battle.');
      }
    }
    _endBattleState();
    enemies.clear();
    activeBoss = null;
    projectiles.clear();
    bossProjectiles.clear();
    companionProjectiles.clear();
    activeCompanions.clear();
    dismissDuelOpponent();
    _shipDead = true;
    final mid = center ?? ship.pos;
    ship.pos = mid;
    final b = CosmicBattle._(
      center: mid,
      damageScale: damageScale,
      hitGrace: hitGrace,
      arena: arena,
      overtime: overtime,
      sides: [
        BattleSide._(0, home, auto: homeAuto),
        BattleSide._(1, away, auto: awayAuto),
      ],
    );
    _battle = b;
    for (final side in b.sides) {
      for (var spot = 0; spot < kBattleFieldSpots; spot++) {
        if (spot < side.creatures.length) _enterBattle(side, spot, spot);
      }
    }
    return b;
  }

  void endBattle() {
    _endBattleState();
    _battle?.floor.dispose();
    _battle = null;
  }

  void _endBattleState() {
    final b = _battle;
    if (b == null) return;
    for (final side in b.sides) {
      for (final cb in side._bodies.values) {
        _combatBodies.remove(cb.body);
      }
      side._bodies.clear();
    }
  }

  /// [side]'s Alchemons go for the other side's creature [creature]; the
  /// same one again, or null, lets them fight whoever is nearest. False when
  /// that one is not on the field.
  bool focusBattleTarget(int side, int? creature) {
    final b = _battle;
    if (b == null || b.over) return false;
    final s = b.sides[side];
    if (creature == null || creature == s.focus) {
      s.focus = null;
      return true;
    }
    final foe = b.sides[1 - side];
    if (creature < 0 || creature >= foe.creatures.length) return false;
    if (!foe.creatures[creature].onField) return false;
    s.focus = creature;
    return true;
  }

  /// A player brings bench creature [creature] on: into an empty place for
  /// free, or (with [spot] and a swap left) in place of the Alchemon there,
  /// which goes back to the bench as it is.
  bool battleSummon(int side, int creature, {int? spot}) {
    final b = _battle;
    if (b == null || b.over) return false;
    final s = b.sides[side];
    if (creature < 0 || creature >= s.creatures.length) return false;
    final c = s.creatures[creature];
    if (c.fallen || c.onField) return false;
    final empty = spot == null
        ? s.spots.indexOf(null)
        : (s.spots[spot] == null ? spot : -1);
    if (empty >= 0) {
      _enterBattle(s, empty, creature);
      b.log.add(BattleEvent(b.clock, side, BattleEventKind.summon, creature));
      return true;
    }
    if (spot == null || s.swapsLeft <= 0) return false;
    final out = s.creatures[s.spots[spot]!];
    final outBody = out.body;
    // One still gathering cannot be sent back before it has arrived.
    if (outBody == null || !_battleArrived(outBody)) return false;
    _leaveBattle(s, spot);
    _enterBattle(s, spot, creature);
    s.swapsLeft--;
    b.log.add(BattleEvent(b.clock, side, BattleEventKind.swap, creature));
    return true;
  }

  bool _battleArrived(CosmicCompanion comp) => comp.life >= kBattleArrival;

  /// Puts creature [index] of [side] in field place [spot], as it last was.
  void _enterBattle(BattleSide side, int spot, int index) {
    final b = _battle!;
    final c = side.creatures[index];
    final member = c.member;
    final stats = deriveAlchemonCombatStats(member: member);
    final at = b.spotAt(side.index, spot);
    final comp = CosmicCompanion(
      member: member,
      position: at,
      anchor: at,
      maxHp: stats.maxHp,
      currentHp: (stats.maxHp * c.hpFraction).round().clamp(1, stats.maxHp),
      physAtk: stats.physAtk,
      elemAtk: stats.elemAtk,
      abilityAtk: stats.abilityAtk,
      physDef: stats.physDef,
      elemDef: stats.elemDef,
      cooldownReduction: stats.cooldownReduction,
      specialCooldownReduction: stats.specialCooldownReduction,
      attackRange: stats.attackRange,
      specialAbilityRange: stats.specialAbilityRange,
      speciesScale: CosmicGame._companionSpeciesScale[member.family
              .toLowerCase()] ??
          1.0,
      invincibleTimer: kBattleArrival,
      visualVariant: member.visualVariant,
    );
    comp.primeSpecialCooldown(savedCooldown: c.specialCooldown);
    // Facing the other side.
    comp.angle = side.index == 0 ? -pi / 2 : pi / 2;
    c.body = comp;
    side.spots[spot] = index;
    // Its sprite and grains are kept by its slot, so they load once a fight.
    if (!_companionTickers.containsKey(member.slotIndex)) {
      _loadCompanionSprite(member, member.slotIndex);
    }
  }

  /// Sends the Alchemon in [spot] back to the bench, keeping its health and
  /// its special's wait.
  void _leaveBattle(BattleSide side, int spot) {
    final i = side.spots[spot];
    if (i == null) return;
    final c = side.creatures[i];
    final comp = c.body;
    if (comp != null) {
      c.hpFraction = comp.currentHp / comp.maxHp;
      c.specialCooldown = comp.specialCooldown;
      _dropBattleBody(side, comp);
      // It comes apart and streams back to the bench, as a recalled
      // companion streams back to the ship.
      side._leaving.add(
        comp
          ..returning = true
          ..returnTimer = 0.6,
      );
    }
    c.body = null;
    side.spots[spot] = null;
    _unfocus(side, i);
  }

  /// The other side stops going for [side]'s creature [i]: it has left.
  void _unfocus(BattleSide side, int i) {
    final other = _battle!.sides[1 - side.index];
    if (other.focus == i) other.focus = null;
  }

  void _dropBattleBody(BattleSide side, CosmicCompanion comp) {
    final cb = side._bodies.remove(comp);
    if (cb != null) {
      _combatBodies.remove(cb.body);
      for (final other in _battle!.sides) {
        other._state.bloodMarked.remove(cb.body);
      }
    }
    for (final other in _battle!.sides) {
      other._targets.remove(comp);
      other._targets.removeWhere((_, t) => identical(t, comp));
    }
  }

  // ── each frame ──────────────────────────────────────────────────────────

  void _updateBattle(double dt) {
    final b = _battle!;
    dt = _battleSlowMotion(b, dt);
    _elapsed += dt;
    for (final side in b.sides) {
      for (final comp in side._leaving) {
        comp.returnTimer -= dt;
      }
      side._leaving.removeWhere((c) => c.returnTimer <= 0);
      // Their sprites move, as the party's do in open space (a Wing that
      // never flaps reads as broken), the fight over or not.
      for (final c in side.onField) {
        _companionTickers[c.member.slotIndex]?.update(dt);
      }
    }
    if (!b.over) {
      b.clock += dt;
      for (final side in b.sides) {
        for (final c in side.onField) {
          final comp = c.body!;
          comp.life += dt;
          comp.invincibleTimer = (comp.invincibleTimer - dt).clamp(0.0, 10.0);
        }
      }
      // A throw still to travel goes on: fast, easing out.
      for (final side in b.sides) {
        for (final c in side.onField) {
          final comp = c.body!;
          final g = comp.shoveGlide;
          if (g == Offset.zero) continue;
          final step = g.distance < 0.5
              ? g
              : g * (1 - exp(-dt * kBattleThrowRate));
          comp.position += step;
          comp.shoveGlide = g - step;
        }
      }
      // What landed last frame carries on: a shove, a slow, a root.
      for (final side in b.sides) {
        final foe = b.sides[1 - side.index];
        for (final entry in side._bodies.entries) {
          _tickCombatBody(
            entry.value,
            entry.key,
            dt,
            trailInto: foe.projectiles,
            trailSlot: battleSlotFor(foe.index, 0),
          );
        }
      }
      final first = b._frame.isEven ? 0 : 1;
      b._frame++;
      for (final i in [first, 1 - first]) {
        final side = b.sides[i];
        final foe = b.sides[1 - i];
        _battleTurnHealed(side, foe, dt);
        _settleBattleBodies(foe);
        _battleFalls(side);
        _battleFalls(foe);
      }
      _keepBattleApart();
      _fizzleOffFloor();
      for (final side in b.sides) {
        _battleReplace(side, dt);
        if (side.auto) _battleThink(side, dt);
      }
      _judgeBattle(b);
    }
    _frameBattle(dt);
    _tellBattleFloor(b, dt);
    // What is only drawn ages whoever laid it.
    _ageBeamFx(dt);
    _updateMaskVisuals(dt);
    _updateWingFlowers(dt);
    updateLetSkyfallImpacts(_letSkyfallImpacts, dt);
    updateLetFx(_letFx, dt);
    updateHornFx(_hornFx, dt);
    updateKinLaserBeams(_kinLaserBeams, dt);
    _abilityVfx.update(dt);
    for (var i = vfxParticles.length - 1; i >= 0; i--) {
      vfxParticles[i].update(dt);
      if (vfxParticles[i].dead) vfxParticles.removeAt(i);
    }
    for (var i = vfxRings.length - 1; i >= 0; i--) {
      vfxRings[i].update(dt);
      if (vfxRings[i].dead) vfxRings.removeAt(i);
    }
  }

  /// [side]'s turn, with what it restored to its own trimmed in overtime:
  /// every heal (a Kin's, a blessing, a Mask's drain) and every shield (a
  /// Horn's) lands on its own turn, so what its creatures gained over it is
  /// what they restored. The stalls overtime is for were Horns behind
  /// their shields and Kins healing (the harness, 2026-10-19).
  void _battleTurnHealed(BattleSide side, BattleSide foe, double dt) {
    final b = _battle!;
    final share = b.healNow;
    if (share >= 1) {
      _battleTurn(side, foe, dt);
      return;
    }
    final before = <CosmicCompanion, (int, int)>{
      for (final c in side.onField)
        c.body!: (c.body!.currentHp, c.body!.shieldHp),
    };
    _battleTurn(side, foe, dt);
    for (final entry in before.entries) {
      final comp = entry.key;
      final (hp, shield) = entry.value;
      final gained = comp.currentHp - hp;
      if (gained > 0) {
        final carry = comp.overtimeHealCarry + gained * share;
        final kept = carry.floor();
        comp.overtimeHealCarry = carry - kept;
        comp.currentHp = hp + kept;
      }
      final shielded = comp.shieldHp - shield;
      if (shielded > 0) {
        comp.shieldHp = shield + (shielded * share).round();
      }
    }
  }

  /// [foe]'s arrived Alchemons as bodies [side]'s abilities can touch.
  List<CosmicEnemy> _standUpBattleBodies(BattleSide foe) {
    final bodies = <CosmicEnemy>[];
    for (final c in foe.onField) {
      final comp = c.body!;
      if (!_battleArrived(comp) || !comp.isAlive) continue;
      final cb = foe._bodies[comp] ??= _newCombatBody(
        comp.member.element,
        _companionBodyRadius(comp),
      );
      _standUp(cb, comp.position);
      _carryHealthOf(cb, comp);
      bodies.add(cb.body);
    }
    return bodies;
  }

  /// [side]'s turn: each of its arrived Alchemons moves on its target, then
  /// does what a companion does in a frame, then everything it has in
  /// flight moves — all on its own side.
  void _battleTurn(BattleSide side, BattleSide foe, double dt) {
    side._acting.clear();
    for (final c in side.onField) {
      final comp = c.body!;
      if (_battleArrived(comp) && comp.isAlive) {
        side._acting[comp.member.slotIndex] = comp;
      }
    }
    final bodies = _standUpBattleBodies(foe);
    var standIn = _battle!.center;
    if (side._acting.isNotEmpty) {
      var sum = Offset.zero;
      for (final comp in side._acting.values) {
        sum += comp.position;
      }
      standIn = sum / side._acting.length.toDouble();
    }
    _runAsSide(
      side._state,
      companions: side._acting,
      bodies: bodies,
      projectiles: side.projectiles,
      foeProjectiles: foe.projectiles,
      standInAt: standIn,
      standInAngle: side.index == 0 ? -pi / 2 : pi / 2,
      turn: () {
        _updateOpenWingBeams(dt);
        updateAttachedAbilityPieces();
        updateMaskRuntime(dt);
        for (final comp in side._acting.values.toList(growable: false)) {
          if (comp.isAlive) _battlerTurn(side, foe, comp, dt);
        }
        _updateOpenKinSupports(dt);
        _updateKinFlowers(dt);
        _updateAbilityProjectiles(dt);
      },
    );
  }

  /// The foe [comp] fights: the nearest, held until another is clearly
  /// closer or it leaves, as the wild Alchemon picks.
  CosmicCompanion? _battleTargetFor(
    BattleSide side,
    BattleSide foe,
    CosmicCompanion comp,
  ) {
    final focus = side.focus;
    if (focus != null) {
      final body = foe.creatures[focus].body;
      if (body != null && body.isAlive && _battleArrived(body)) {
        side._targets[comp] = body;
        return body;
      }
    }
    final held = side._targets[comp];
    CosmicCompanion? best;
    var bestScore = double.infinity;
    for (final c in foe.onField) {
      final other = c.body!;
      if (!other.isAlive || !_battleArrived(other)) continue;
      var score = (other.position - comp.position).distance;
      if (identical(other, held)) score -= 110;
      if (score < bestScore) {
        bestScore = score;
        best = other;
      }
    }
    if (best == null) {
      side._targets.remove(comp);
    } else {
      side._targets[comp] = best;
    }
    return best;
  }

  /// One Alchemon's frame, as the wild Alchemon's turn runs it
  /// ([_wildTurn]), with its steering first.
  void _battlerTurn(
    BattleSide side,
    BattleSide foe,
    CosmicCompanion comp,
    double dt,
  ) {
    final target = _battleTargetFor(side, foe, comp);
    if (target == null) return;
    final family = comp.member.family.toLowerCase();

    // A Horn special holding it (a ram, a wind-up, a brew, a Light
    // barrier), a Wing's charging beam or a Kin's gather holds it here too.
    if (!comp.hornHoldsBody &&
        !_hornLightChanneling(comp) &&
        !_heldByWingCharge(comp) &&
        !_kinHoldsBody(comp, comp.member)) {
      _battleSteer(side, comp, target, family, dt);
    } else {
      comp.velocity = Offset.zero;
    }

    if (_updateHornPhases(comp, dt)) return;
    if (comp.basicHasteTimer > 0) {
      comp.basicHasteTimer = max(0.0, comp.basicHasteTimer - dt);
      if (comp.basicHasteTimer <= 0) comp.basicHasteMultiplier = 1.0;
    }
    _tickOpenCompanionIdentity(comp, dt);
    _tickOpenFamilyPassives(comp.member.slotIndex, comp, dt);
    if (!_hornLightChanneling(comp)) {
      comp.basicCooldown = (comp.basicCooldown - dt).clamp(0.0, 100.0);
      comp.specialCooldown = (comp.specialCooldown - dt).clamp(0.0, 100.0);
    }
    _tickCompanionBlessing(comp, dt);

    final toTarget = target.position - comp.position;
    comp.angle = atan2(toTarget.dy, toTarget.dx);
    // It turns its sprite only once its aim is clearly to the other side.
    final c = cos(comp.angle);
    final faced = comp.faceRight;
    if (faced == null || (faced && c < -0.3) || (!faced && c > 0.3)) {
      comp.faceRight = c > 0;
    }
    final reach = max(0.0, toTarget.distance - _companionBodyRadius(target));
    if (_isKinMember(comp.member)) {
      _tickOpenKinChargedAuto(comp, target.position, reach, dt);
    } else if (comp.basicCooldown <= 0 && reach <= comp.attackRange) {
      _fireCompanionBasic(comp);
      // The attack moves the body: a short lunge in for the families that
      // fight up close, a little kick back for those that shoot. The glide
      // takes it back to its place.
      final close = family == 'horn' || family == 'mane';
      final dir = toTarget.distance > 0.001
          ? toTarget / toTarget.distance
          : Offset.zero;
      comp.velocity += dir * (close ? kBattleLunge : -kBattleRecoil);
    }
    if (_companionSpecialReady(comp) && reach <= comp.specialAbilityRange) {
      _castCompanionSpecial(comp, target.position);
      final index = comp.member.slotIndex - battleSlotFor(side.index, 0);
      final b = _battle!;
      side.creatures[index].lastSpecialAt = b.clock;
      b.floor.special(
        target.position - b.center,
        elementColor(comp.member.element),
        _elapsed,
      );
      b.log.add(BattleEvent(b.clock, side.index, BattleEventKind.special, index));
    }
  }

  /// Where [comp] wants to stand against [target], and the glide there.
  ///
  /// The station is the dungeon's ([companionStation]): off the target's
  /// edge, at the distance its family likes (a Horn presses in, a Kin hangs
  /// back), on its own side's side of the target so the two sides face each
  /// other, swaying at its own pace. The station is kept on the floor, and
  /// the creature glides to it at its family's speed with an eased start
  /// and stop, rather than being set down where a rule says.
  void _battleSteer(
    BattleSide side,
    CosmicCompanion comp,
    CosmicCompanion target,
    String family,
    double dt,
  ) {
    final b = _battle!;
    // Its side of the target is toward a point inside its own half, not its
    // far edge: pushed back, it steps round its foe rather than into a wall.
    final home =
        b.center +
        Offset(0, (side.index == 0 ? 1 : -1) * kBattleArenaRy * 0.45);
    final fromTarget = home - target.position;
    final stance = stanceForFamily(family);
    final index = comp.member.slotIndex - battleSlotFor(side.index, 0);
    // The pair stands apart: the one in the left place keeps to its
    // target's left, the other to its right, so one blow seldom takes both.
    final spot = side.spots.indexOf(index);
    final spread = (spot == 0 ? 1 : -1) * (side.index == 0 ? 1 : -1) * 0.5;
    final radius = _companionBodyRadius(comp);
    var station = companionStation(
      target: target.position,
      targetRadius: _companionBodyRadius(target),
      bodyRadius: radius,
      attackRange: comp.attackRange,
      // The battle keeps the two sides facing: nobody loops round behind.
      stance: CompanionStance(
        engageFraction: stance.engageFraction,
        orbitWeight: min(stance.orbitWeight, 0.85),
        tooCloseFraction: stance.tooCloseFraction,
      ),
      homeBearing: atan2(fromTarget.dy, fromTarget.dx) + spread,
      slot: index,
      time: b.clock,
    );
    station = _onBattleFloor(station, radius + 40);

    // Thrown, it is carried by the blow until it settles: it does not steer
    // against it (that read as a snap back), it only slows.
    final knock = side._bodies[comp]?.body.knockbackVelocity.distance ?? 0;
    if (comp.shoveGlide.distance > 3 || knock > 30) {
      comp.velocity *= exp(-dt * 6);
      comp.position += comp.velocity * dt * comp.ccMoveFactor;
      return;
    }
    final to = station - comp.position;
    final dist = to.distance;
    final top = _combatChaseSpeed(family, comp.member.statSpeed);
    // Full pace from afar, easing in over the last stretch.
    final want = dist < 0.5 ? Offset.zero : to / dist * min(top, dist * 2.6);
    final dv = want - comp.velocity;
    final step = kBattleAcceleration * dt;
    comp.velocity += dv.distance > step ? dv / dv.distance * step : dv;
    // What the other side's abilities left on it (a slow, a root) holds it.
    comp.position += comp.velocity * dt * comp.ccMoveFactor;
  }

  /// [p] kept [margin] inside the floor's edge.
  Offset _onBattleFloor(Offset p, double margin) {
    final b = _battle!;
    final from = p - b.center;
    final ex = from.dx / (kBattleArenaRx - margin);
    final ey = from.dy / (kBattleArenaRy - margin);
    final d = sqrt(ex * ex + ey * ey);
    return d > 1 ? b.center + from / d : p;
  }

  /// What [side]'s bodies took on the other side's turn, onto its Alchemons.
  void _settleBattleBodies(BattleSide side) {
    final b = _battle!;
    for (final entry in side._bodies.entries) {
      final comp = entry.key;
      if (comp.isAlive && _battleArrived(comp)) {
        final before = comp.currentHp + comp.shieldHp;
        _settleOnCompanion(entry.value, comp, pool: side.projectiles);
        final lost = before - (comp.currentHp + comp.shieldHp);
        // The floor feels a blow worth seeing.
        if (lost > comp.maxHp * 0.02) {
          b.floor.hit(
            comp.position - b.center,
            elementColor(comp.member.element),
            (lost / (comp.maxHp * 0.12)).clamp(0.0, 1.0),
            _elapsed,
          );
        }
      }
    }
  }

  /// Alchemons of [side] whose health has run out: a Fire kin's phoenix
  /// catches the first, otherwise it leaves its place empty.
  void _battleFalls(BattleSide side) {
    final b = _battle!;
    for (var spot = 0; spot < kBattleFieldSpots; spot++) {
      final i = side.spots[spot];
      if (i == null) continue;
      final c = side.creatures[i];
      final comp = c.body!;
      if (comp.currentHp > 0) continue;
      if (_battlePhoenix(side, comp)) continue;
      _spawnKillVfx(comp.position, elementColor(comp.member.element), 12, false);
      b.floor.hit(
        comp.position - b.center,
        elementColor(comp.member.element),
        1,
        _elapsed,
      );
      _dropBattleBody(side, comp);
      c
        ..fallen = true
        ..hpFraction = 0
        ..body = null;
      side.spots[spot] = null;
      _unfocus(side, i);
      b.log.add(BattleEvent(b.clock, side.index, BattleEventKind.fall, i));
    }
  }

  /// A Fire kin on the field whose phoenix has not fired catches [fallen]
  /// (itself or its teammate) at a quarter health, once a fight.
  bool _battlePhoenix(BattleSide side, CosmicCompanion fallen) {
    for (var i = 0; i < side.creatures.length; i++) {
      final c = side.creatures[i];
      final kin = c.body;
      if (kin == null || c.phoenixSpent) continue;
      if (!_isKinMember(kin.member) || kin.member.element != 'Fire') continue;
      if (!identical(kin, fallen) && !kin.isAlive) continue;
      c.phoenixSpent = true;
      fallen.currentHp = max(
        1,
        (fallen.maxHp * KinSupport.phoenixRestoreFraction).round(),
      );
      _awakenOpenPhoenix(_KinCaster.companion(kin), fallen.position);
      final b = _battle!;
      b.log.add(BattleEvent(b.clock, side.index, BattleEventKind.phoenix, i));
      return true;
    }
    return false;
  }

  /// Nobody stands in anyone else, friend or foe, and nobody leaves the
  /// floor. One held by its own ability (a ram, a channel) is not moved;
  /// the other one gives way.
  void _keepBattleApart() {
    final b = _battle!;
    final all = [
      for (final side in b.sides)
        for (final c in side.onField) c.body!,
    ];
    bool held(CosmicCompanion c) => c.hornHoldsBody;
    for (var i = 0; i < all.length; i++) {
      for (var j = i + 1; j < all.length; j++) {
        final a = all[i];
        final c = all[j];
        final gap = (_companionBodyRadius(a) + _companionBodyRadius(c)) * 0.95;
        final d = c.position - a.position;
        final dist = d.distance;
        if (dist >= gap) continue;
        final dir = dist > 0.001 ? d / dist : Offset(i.isEven ? 1 : -1, 0);
        final push = gap - dist;
        final aHeld = held(a), cHeld = held(c);
        if (aHeld && cHeld) continue;
        final share = aHeld ? 0.0 : (cHeld ? 1.0 : 0.5);
        a.position -= dir * push * share;
        c.position += dir * push * (1 - share);
      }
    }
    for (final side in b.sides) {
      final field = [for (final c in side.onField) c.body!];
      for (final comp in field) {
        final r = _companionBodyRadius(comp);
        final from = comp.position - b.center;
        final ex = from.dx / (kBattleArenaRx - r);
        final ey = from.dy / (kBattleArenaRy - r);
        final d = sqrt(ex * ex + ey * ey);
        if (d > 1) comp.position = b.center + from / d;
      }
    }
  }

  /// The floor hears where everyone stands and where their feet come
  /// down: a step every so far a creature travels.
  void _tellBattleFloor(CosmicBattle b, double dt) {
    final at = <Offset>[];
    for (final side in b.sides) {
      for (final c in side.onField) {
        final body = c.body!;
        final p = body.position - b.center;
        at.add(p);
        final last = c._lastAt;
        c._lastAt = p;
        if (last == null || !_battleArrived(body)) continue;
        c._stride += (p - last).distance;
        if (c._stride > 46) {
          c._stride = 0;
          b.floor.step(p, _elapsed);
        }
      }
    }
    b.floor.fighters(at, dt);
  }

  /// The fighters mirrored in the floor (the Tidal Mirror): each sprite
  /// flipped about its feet, faint, under everything else.
  void _paintBattleReflections(Canvas canvas) {
    final b = _battle!;
    for (final side in b.sides) {
      for (final c in side.onField) {
        final comp = c.body!;
        if (!comp.isAlive) continue;
        final slot = comp.member.slotIndex;
        final ticker = _companionTickers[slot];
        if (ticker == null) continue;
        final scale = _companionSpriteScales[slot] ?? 1.0;
        final feet = _companionBodyRadius(comp) * 1.25;
        final arrive = (comp.life / kBattleArrival).clamp(0.0, 1.0);
        final paint = Paint()
          ..color = Colors.white.withValues(alpha: 0.2 * arrive)
          ..filterQuality = ui.FilterQuality.medium;
        final v = _companionVisualsBySlot[slot];
        if (v != null) paint.colorFilter = _creatureFilter(v);
        final right = comp.faceRight ?? cos(comp.angle) > 0;
        canvas.save();
        canvas.translate(comp.position.dx, comp.position.dy + feet * 2);
        canvas.scale(right ? -scale : scale, -scale * 0.9);
        ticker.getSprite().render(
          canvas,
          anchor: Anchor.center,
          overridePaint: paint,
        );
        canvas.restore();
      }
    }
  }

  /// A shot that leaves the floor goes out there instead of flying on
  /// through space. A meteor still on its way down is in the sky, not off
  /// the floor.
  void _fizzleOffFloor() {
    final b = _battle!;
    const margin = 60.0;
    for (final side in b.sides) {
      for (final p in side.projectiles) {
        if (p.life <= 0 || p.isDescending) continue;
        final from = p.position - b.center;
        final ex = from.dx / (kBattleArenaRx + margin);
        final ey = from.dy / (kBattleArenaRy + margin);
        if (ex * ex + ey * ey > 1) p.life = 0;
      }
    }
  }

  /// The healthiest on [side]'s bench, the first brought on a tie.
  int? _healthiestOnBench(BattleSide side) {
    int? best;
    for (final i in side.bench) {
      if (best == null ||
          side.creatures[i].hpFraction > side.creatures[best].hpFraction) {
        best = i;
      }
    }
    return best;
  }

  /// Either side: a place left empty by a fall is filled from the bench a
  /// moment later, by the healthiest one there.
  void _battleReplace(BattleSide side, double dt) {
    final empty = side.spots.indexOf(null);
    final best = _healthiestOnBench(side);
    if (empty < 0 || best == null) {
      side._replaceT = 0;
      return;
    }
    side._replaceT += dt;
    if (side._replaceT < kBattleReplaceDelay) return;
    side._replaceT = 0;
    battleSummon(side.index, best, spot: empty);
  }

  /// The computer's side: pick a focus, and pull out a badly hurt Alchemon
  /// for a fresh one after a moment's thought.
  void _battleThink(BattleSide side, double dt) {
    _battleThinkFocus(side, dt);
    final best = _healthiestOnBench(side);
    if (best == null || side.spots.contains(null)) {
      side._thinkT = 0;
      return;
    }
    int? want;
    int? into;
    if (side.swapsLeft > 0 &&
        side.creatures[best].hpFraction >= side.swapFor) {
      for (var spot = 0; spot < kBattleFieldSpots; spot++) {
        final comp = side.at(spot)?.body;
        if (comp == null || !_battleArrived(comp)) continue;
        if (comp.currentHp / comp.maxHp < side.swapBelow) {
          want = best;
          into = spot;
          break;
        }
      }
    }
    if (want == null) {
      side._thinkT = 0;
      return;
    }
    side._thinkT += dt;
    if (side._thinkT < side.thinkDelay) return;
    side._thinkT = 0;
    battleSummon(side.index, want, spot: into);
  }

  /// The computer goes for whichever of the other side's is lowest, looked
  /// at twice a second, so a hurt one is finished rather than let go.
  void _battleThinkFocus(BattleSide side, double dt) {
    side._focusT -= dt;
    if (side._focusT > 0) return;
    side._focusT = 0.5;
    final foe = _battle!.sides[1 - side.index];
    int? pick;
    var lowest = double.infinity;
    for (var i = 0; i < foe.creatures.length; i++) {
      final body = foe.creatures[i].body;
      if (body == null || !body.isAlive || !_battleArrived(body)) continue;
      final share = body.currentHp / body.maxHp;
      if (share < lowest - 0.05) {
        lowest = share;
        pick = i;
      }
    }
    side.focus = pick;
  }

  void _judgeBattle(CosmicBattle b) {
    final home = b.sides[0].anyOnField;
    final away = b.sides[1].anyOnField;
    if (!home || !away) {
      b.result = BattleResult(
        winner: home ? 0 : (away ? 1 : null),
        end: BattleEnd.fieldEmpty,
        at: b.clock,
      );
      b._endedReal = b._real;
      return;
    }
    if (b.clock < kBattleTimeLimit) return;
    final a = b.sides[0].healthShare;
    final c = b.sides[1].healthShare;
    b.result = BattleResult(
      winner: (a - c).abs() < 1e-9 ? null : (a > c ? 0 : 1),
      end: BattleEnd.timeUp,
      at: b.clock,
    );
    b._endedReal = b._real;
  }

  /// Slow motion, eased in and out: while a side is down to its last and
  /// that one is nearly gone (the finishing blows, up to a few seconds),
  /// and for a moment once it falls. Returns the fight's time step for the
  /// real one, [dt].
  double _battleSlowMotion(CosmicBattle b, double dt) {
    b._real += dt;
    final since = b.sinceEnd;
    final double target;
    if (since != null) {
      target = since < 0.9 ? 0.32 : 1;
    } else if (b._slowSpent < 2.5 && _battleFinishing(b)) {
      target = 0.45;
    } else {
      target = 1;
    }
    b.timeScale += (target - b.timeScale) * (1 - exp(-dt * 7));
    if (since == null && b.timeScale < 0.95) b._slowSpent += dt;
    return dt * b.timeScale;
  }

  /// Whether a side is on its last: nobody left on its bench, and what is
  /// on its field nearly gone.
  bool _battleFinishing(CosmicBattle b) {
    for (final side in b.sides) {
      if (side.bench.isNotEmpty) continue;
      final field = [
        for (final c in side.onField)
          if (c.body!.isAlive) c.body!,
      ];
      if (field.isEmpty) continue;
      if (field.every((c) => c.currentHp / c.maxHp < 0.16)) return true;
    }
    return false;
  }

  // ── drawing ─────────────────────────────────────────────────────────────

  /// What the HUD leaves of the screen, in logical pixels.
  Rect get _battleBand {
    final inset = _battle!.viewInsets;
    return Rect.fromLTWH(
      inset.left,
      inset.top,
      max(1.0, size.x - inset.horizontal),
      max(1.0, size.y - inset.vertical),
    );
  }

  /// The zoom that fits the camera's frame in the band.
  double get _battleZoom {
    final b = _battle!;
    if (b._camAt == null) _frameBattle(0);
    return _battleBand.height / b._camHeight;
  }

  /// The camera's top-left in the world: what it looks at, in the middle of
  /// the band.
  Offset get _battleCamera {
    final b = _battle!;
    if (b._camAt == null) _frameBattle(0);
    final band = _battleBand;
    return b._camAt! - band.center / _battleZoom;
  }

  /// Eases the camera toward framing everyone on the field with room round
  /// them: in close when they fight close, out when they spread, never
  /// closer than [kBattleCloseFrame] nor wider than the floor. [dt] 0 frames
  /// at once.
  void _frameBattle(double dt) {
    final b = _battle!;
    final band = _battleBand;
    final aspect = band.width / band.height;
    Rect? box;
    for (final side in b.sides) {
      for (final c in side.onField) {
        final r = Rect.fromCircle(
          center: c.body!.position,
          radius: _companionBodyRadius(c.body!) + 130,
        );
        box = box?.expandToInclude(r) ?? r;
      }
    }
    box ??= Rect.fromCenter(
      center: b.center,
      width: kBattleArenaRx * 2,
      height: kBattleArenaRy * 2,
    );
    final widest = max(kBattleArenaRy * 2 + 80, (kBattleArenaRx * 2 + 80) / aspect);
    final double height = max(box.height, box.width / aspect)
        .clamp(min(kBattleCloseFrame, widest), widest)
        .toDouble();
    // Its middle stays where the frame still covers floor, not open space.
    final halfW = height * aspect / 2, halfH = height / 2;
    final slackX = max(0.0, kBattleArenaRx + 40 - halfW);
    final slackY = max(0.0, kBattleArenaRy + 40 - halfH);
    final at = Offset(
      b.center.dx + (box.center.dx - b.center.dx).clamp(-slackX, slackX),
      b.center.dy + (box.center.dy - b.center.dy).clamp(-slackY, slackY),
    );
    final cam = b._camAt;
    if (cam == null) {
      // It opens on the whole floor (what the hub's arena grows into), then
      // comes in on the fight.
      b._camAt = b.center;
      b._camHeight = widest;
      return;
    }
    if (dt <= 0) {
      b._camAt = at;
      b._camHeight = height;
      return;
    }
    final k = 1 - exp(-dt * 1.8);
    b._camAt = cam + (at - cam) * k;
    b._camHeight += (height - b._camHeight) * k;
  }

  /// A light pool under [body]'s feet, breathing, in [color].
  void _paintBattleFocus(Canvas canvas, CosmicCompanion body, Color color) {
    final r = _companionBodyRadius(body);
    final at = body.position + Offset(0, r * 0.8);
    final breathe = 0.82 + 0.18 * sin(_elapsed * 3.0);
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(1, 0.36);
    for (final (radius, alpha) in [(r * 2.0, 0.30), (r * 1.1, 0.34)]) {
      canvas.drawCircle(
        Offset.zero,
        radius,
        Paint()
          ..shader = ui.Gradient.radial(Offset.zero, radius, [
            color.withValues(alpha: alpha * breathe),
            color.withValues(alpha: 0),
          ]),
      );
    }
    canvas.restore();
  }

  /// The battle creature under [screen] (logical pixels): its side and index.
  (int, int)? battleCreatureAt(Offset screen) {
    final b = _battle;
    if (b == null) return null;
    final world = _battleCamera + screen / _battleZoom;
    (int, int)? best;
    var bestDist = double.infinity;
    for (final side in b.sides) {
      for (var i = 0; i < side.creatures.length; i++) {
        final body = side.creatures[i].body;
        if (body == null) continue;
        final d = (body.position - world).distance;
        final reach = _companionBodyRadius(body) * 1.6 + 12 / _battleZoom;
        if (d < reach && d < bestDist) {
          bestDist = d;
          best = (side.index, i);
        }
      }
    }
    return best;
  }

  /// Draws as [side], so the code that draws the party's abilities and
  /// companions draws this side's: [companions] stand in its place and its
  /// ship stands in at [standInAt].
  void _drawAsSide(
    BattleSide side,
    Map<int, CosmicCompanion> companions,
    Offset standInAt,
    void Function() draw,
  ) {
    final foe = _battle!.sides[1 - side.index];
    _runAsSide(
      side._state,
      companions: companions,
      bodies: <CosmicEnemy>[],
      projectiles: side.projectiles,
      foeProjectiles: foe.projectiles,
      standInAt: standInAt,
      standInAngle: side.index == 0 ? -pi / 2 : pi / 2,
      turn: draw,
    );
  }

  void _renderBattle(Canvas canvas) {
    final b = _battle!;
    final zoom = _battleZoom;
    final cam = _battleCamera;
    final view = Rect.fromLTWH(cam.dx, cam.dy, size.x / zoom, size.y / zoom);
    canvas.save();
    canvas.scale(zoom, zoom);
    canvas.translate(-cam.dx, -cam.dy);
    b.floor.paint(canvas, b.center, _elapsed, view);
    if (b.floor.reflects) _paintBattleReflections(canvas);

    bool inView(Offset p) => view.inflate(120).contains(p);

    // Let meteors' marked ground, under everything.
    for (final side in b.sides) {
      for (final cp in side.projectiles) {
        if (!cp.isDescending || !inView(cp.skyfallImpact)) continue;
        drawLetSkyfallTelegraph(
          canvas: canvas,
          centre: cp.skyfallImpact,
          color: elementColor(cp.element ?? 'Fire'),
          element: cp.element,
          radius: letSkyfallBlastRadius(cp),
          progress: cp.skyfallProgress,
          time: _elapsed,
        );
      }
    }
    for (final impact in _letSkyfallImpacts) {
      drawLetSkyfallImpact(
        canvas: canvas,
        centre: impact.position,
        color: impact.color,
        element: impact.element,
        minor: impact.minor,
        radius: impact.radius,
        age: impact.t,
      );
    }
    drawLetFx(canvas, _letFx);
    drawHornFx(canvas, _hornFx);

    maneLavaPoolCrowd = b.sides.fold(
      0,
      (n, side) => n + ManeRuntime.countLavaPools(side.projectiles),
    );
    final fields = [
      for (final side in b.sides)
        {
          for (final c in side.onField)
            if (c.body!.isAlive) c.body!.member.slotIndex: c.body!,
        },
    ];
    Offset middleOf(int i) {
      final field = fields[i];
      if (field.isEmpty) return b.spotAt(i, 0);
      var sum = Offset.zero;
      for (final comp in field.values) {
        sum += comp.position;
      }
      return sum / field.length.toDouble();
    }

    // What each side has laid and has in flight.
    for (final side in b.sides) {
      _drawAsSide(side, fields[side.index], middleOf(side.index), () {
        _renderOpenWingBeams(canvas, fx: side.index == 0);
        _renderKinFlowers(canvas);
        for (final cp in companionProjectiles) {
          if (inView(cp.position)) _renderAbilityProjectile(canvas, cp);
        }
        _renderMaskOverlays(canvas, view, traps: side.index == 0);
      });
    }
    _renderWingFlowers(canvas);

    // Once it is won, light rises off the winner's half and the other half
    // goes dark.
    final since = b.sinceEnd;
    final winner = b.result?.winner;
    if (since != null && winner != null) {
      final k = Curves.easeInOut.transform((since / 1.6).clamp(0.0, 1.0));
      final up = winner == 0 ? 1.0 : -1.0;
      final color = winner == 0 ? kBattleBrass : kBattleSilver;
      BattleFloor.pool(
        canvas,
        b.center + Offset(0, up * kBattleArenaRy * 0.42),
        kBattleArenaRx * 1.1,
        kBattleArenaRy * 0.7,
        [color.withValues(alpha: 0.2 * k), color.withValues(alpha: 0)],
      );
      BattleFloor.pool(
        canvas,
        b.center - Offset(0, up * kBattleArenaRy * 0.45),
        kBattleArenaRx * 1.15,
        kBattleArenaRy * 0.7,
        [
          Colors.black.withValues(alpha: 0.45 * k),
          Colors.black.withValues(alpha: 0),
        ],
      );
    }

    // Who each side is going for: a pool of its colour under that one —
    // brass under the player's pick, silver under the other side's.
    for (final side in b.sides) {
      final focus = side.focus;
      if (focus == null) continue;
      final body = b.sides[1 - side.index].creatures[focus].body;
      if (body == null || !body.isAlive) continue;
      _paintBattleFocus(
        canvas,
        body,
        side.index == 0 ? kBattleBrass : kBattleSilver,
      );
    }

    // The Alchemons: those leaving first, coming apart toward the bench.
    for (final side in b.sides) {
      if (side._leaving.isEmpty) continue;
      _drawAsSide(side, const {}, b.benchAt(side.index), () {
        for (final comp in side._leaving) {
          _renderCompanion(canvas, comp.member.slotIndex, comp);
        }
      });
    }
    for (final side in b.sides) {
      _drawAsSide(side, fields[side.index], middleOf(side.index), () {
        for (final entry in fields[side.index].entries) {
          _renderCompanion(canvas, entry.key, entry.value);
        }
        _renderKinWorld(canvas, lasers: side.index == 0);
      });
    }
    _renderMaskSpiritNukeFlash(canvas, view);
    _renderVfxParticles(canvas);
    canvas.restore();
  }
}
