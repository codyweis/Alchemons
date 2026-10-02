part of 'cosmic_game.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  THE DUEL: one fight, two sides, the same abilities
//
//  A wild Alchemon fights with the abilities the party's companions use —
//  the same casts, projectiles, zones, beams and look — so it runs the same
//  code rather than a copy of it. Two things make that possible.
//
//  • The party's abilities reach it through a body in the enemy list (its
//    combat body). A trap, a zone, a beam or a charge touches that body
//    exactly as it touches any enemy, and what the body took — damage, a
//    shove, a slow — is then carried onto the creature.
//
//  • Its own abilities resolve on its side ([_onWildSide]). For the length of
//    its turn the enemy list holds bodies standing in for the party's
//    companions and the ship, it is the only companion, the "ship" its
//    abilities defend is a stand-in at its own position, and the projectiles,
//    beams and marks in flight are its own. So its heal pools heal it, its
//    traps lie on the approach to it, and its charge sweeps the party.
//
//  An instant kill is not what an ability does to the player's companions, or
//  to a creature that is meant to be worn down and caught: against a combat
//  body an execute takes a quarter of the creature's health instead, the way
//  a boss shrugs one off.
// ─────────────────────────────────────────────────────────────────────────────

/// The slot the wild Alchemon casts from, apart from the party's slots and
/// the ship's -1.
const int kWildCasterSlot = -7;

/// A combat body's health: far more than any pass can take, so a pass never
/// kills it, and what it lost is read back as damage.
const double _kCombatBodyHealth = 1e6;

/// A combat body's speed. Slows scale it, so the fraction left is how fast
/// its creature may move.
const double _kCombatBodySpeed = 100;

/// How far one pass may carry a creature. A Dark hole puts an enemy out of
/// the area; a duellist is only thrown back.
const double _kCombatBodyMaxShove = 180;

/// The fastest a knockback may carry a duellist (px/s). Knockback grows with
/// the hit, and a creature's hits are big enough to throw a body clean out of
/// the fight; a duellist is only thrown back.
const double _kCombatBodyMaxKnockSpeed = 260;

/// What an instant kill takes from an Alchemon, as a share of its health.
const double _kExecuteShare = 0.25;

/// The ship's body is keyed by this, a companion's by the companion.
const Object _kShipBodyKey = Object();

/// A creature standing in the enemy list for the other side's abilities.
class _CombatBody {
  _CombatBody(this.body);

  final CosmicEnemy body;

  /// Where the creature stood when the pass began.
  Offset from = Offset.zero;

  /// Damage owed in fractions of a point, paid in whole points.
  double damageCarry = 0;

  /// Instant kills taken this pass.
  int executes = 0;

  double mudTrailTimer = 0;
}

/// The wild Alchemon's side of the fight: what it has in flight and the
/// marks it has left. Its projectiles are [CosmicGame.duelOpponentProjectiles].
class _WildSide {
  List<_ActiveWingBeam> wingBeams = [];
  List<_ActiveWingBeam> pendingWingBeams = [];
  Set<CosmicEnemy> bloodMarked = {};
  Map<int, int> spiritBank = {};
  double bloodTimer = 0;
  double bloodHealing = 0;
  List<MaskSpiritWisp> spiritWisps = [];
  Map<int, int> plantFeeds = {};
  final Map<int, CosmicCompanion> companions = {};
  List<_GarrisonCreature> garrison = [];

  /// Its Kin Plant garden's flowers, which drift to it.
  List<_KinFlower> kinFlowers = [];

  /// The ship damage its Kin supports have seen (its side has no ship).
  double kinPrevShipHealth = -1;
  double kinLastShipDamage = 0;

  /// The party's projectiles, while its turn runs: the shots its Kin pieces
  /// screen (cosmic_game_kin.dart).
  List<Projectile>? foeProjectiles;

  /// The "ship" its abilities defend and orbit: itself.
  final ShipComponent standIn = ShipComponent(pos: Offset.zero);

  /// Ship damage owed, in the ship's own points.
  double shipCarry = 0;

  void clear() {
    wingBeams.clear();
    pendingWingBeams.clear();
    bloodMarked.clear();
    spiritBank.clear();
    bloodTimer = 0;
    bloodHealing = 0;
    spiritWisps.clear();
    plantFeeds.clear();
    companions.clear();
    kinFlowers.clear();
    kinPrevShipHealth = -1;
    kinLastShipDamage = 0;
    foeProjectiles = null;
    shipCarry = 0;
  }
}

extension CosmicDuel on CosmicGame {
  bool _isCombatBody(CosmicEnemy enemy) => _combatBodies.containsKey(enemy);

  /// A pass took an instant kill on [enemy]'s combat body; true if it was
  /// one, and the kill is booked as a heavy hit instead.
  bool _bookExecute(CosmicEnemy enemy) {
    final cb = _combatBodies[enemy];
    if (cb == null) return false;
    cb.executes++;
    return true;
  }

  /// Forgets every body and the wild side's state, at a duel's start or end.
  void _resetDuelCombat() {
    final wild = _wildBody;
    for (final cb in [..._partyBodies.values, if (wild != null) wild]) {
      enemies.remove(cb.body);
      _combatBodies.remove(cb.body);
    }
    _partyBodies.clear();
    _wildBody = null;
    _wildSide.clear();
    for (final comp in activeCompanions.values) {
      comp.ccMoveFactor = 1.0;
    }
  }

  _CombatBody _newCombatBody(String element, double radius) {
    final body = CosmicEnemy(
      position: Offset.zero,
      element: element,
      tier: EnemyTier.drone,
      radius: radius / enemySizeScale(EnemyTier.drone),
      health: _kCombatBodyHealth,
      speed: _kCombatBodySpeed,
      provoked: true,
    );
    final cb = _CombatBody(body);
    _combatBodies[body] = cb;
    return cb;
  }

  void _standUp(_CombatBody cb, Offset at) {
    cb.body
      ..position = at
      ..health = _kCombatBodyHealth
      ..dead = false;
    cb.from = at;
    cb.executes = 0;
  }

  // ── the party's abilities reaching the wild Alchemon ────────────────────

  /// Puts the wild Alchemon's body among the enemies, for a stretch of the
  /// frame in which the party's abilities resolve.
  void _admitWildBody() {
    final opp = duelOpponent;
    if (_onWildSideNow || !wildDuelActive || opp == null || !opp.isAlive) {
      return;
    }
    final cb = _wildBody ??= _newCombatBody(
      opp.member.element,
      _companionBodyRadius(opp),
    );
    _standUp(cb, opp.position);
    if (!enemies.contains(cb.body)) enemies.add(cb.body);
  }

  /// Takes the body back out and carries what it took onto the creature.
  void _releaseWildBody() {
    final cb = _wildBody;
    if (cb == null) return;
    enemies.remove(cb.body);
    final opp = duelOpponent;
    if (opp == null || !opp.isAlive || !wildDuelActive) return;
    _settleOnCompanion(cb, opp, pool: duelOpponentProjectiles);
  }

  /// What the pass took from [cb]'s health. A pass that emptied it outright
  /// ran an instant kill on it, whichever path did so; that is booked as one.
  double _takenBy(_CombatBody cb) {
    final taken = max(0.0, _kCombatBodyHealth - cb.body.health);
    if (taken < _kCombatBodyHealth * 0.5) return taken;
    cb.executes++;
    return 0;
  }

  /// Damage (through the creature's defence and its grace window), instant
  /// kills and the shove, from [cb] onto [comp]. [pool] is [comp]'s side's
  /// projectiles, for a Horn's cover, when that is not the side in hand.
  void _settleOnCompanion(
    _CombatBody cb,
    CosmicCompanion comp, {
    List<Projectile>? pool,
  }) {
    final body = cb.body;
    final taken = _takenBy(cb);
    body
      ..health = _kCombatBodyHealth
      ..dead = false;
    final hit = taken > 0
        ? taken *
              CosmicGame._duelDamageMultiplier *
              100 /
              (100 + comp.elemDef * CosmicGame._duelDefenseScale)
        : 0.0;
    // A Horn's say in what the other side's abilities did: Spirit phasing,
    // a Light barrier's cover, Lightning banking it for its discharge.
    final cover = taken > 0 || cb.executes > 0
        ? _hornIncomingScale(comp, hit, pool: pool)
        : 1.0;
    if (taken > 0) {
      cb.damageCarry += hit * cover;
      // Through the same grace window as every other hurt in open space,
      // so a fight is paced as it always was: what lands inside it is lost.
      final whole = cb.damageCarry.floor();
      if (whole > 0) {
        cb.damageCarry -= whole;
        comp.takeDamage(whole);
      }
    }
    // An instant kill is the cast's big moment and always lands.
    if (cb.executes > 0) {
      comp.takeAbilityDamage(
        (comp.maxHp * _kExecuteShare * cb.executes * cover).round(),
      );
      _spawnHitSpark(comp.position, Colors.white);
      cb.executes = 0;
    }
    var shove = body.position - cb.from;
    if (shove.distance > _kCombatBodyMaxShove) {
      shove = shove / shove.distance * _kCombatBodyMaxShove;
    }
    comp.position += shove;
    body.position = comp.position;
    cb.from = comp.position;
  }

  /// The ship takes damage in its own small points, through its own hit
  /// grace; it is never shoved about by an ability.
  void _settleOnShip(_CombatBody cb) {
    final body = cb.body;
    final taken = _takenBy(cb);
    body
      ..health = _kCombatBodyHealth
      ..dead = false
      ..position = ship.pos
      ..knockbackVelocity = Offset.zero;
    cb.from = ship.pos;
    final side = _wildSide;
    if (taken > 0) {
      // Creature damage onto the ship's own small points: the ship is world,
      // authored against the lighter hits of the old creature scale.
      side.shipCarry +=
          taken *
          CosmicGame._duelDamageMultiplier /
          (45.0 * CosmicBalance.spaceIncomingScale);
    }
    if (cb.executes > 0) {
      side.shipCarry += 0.9 * cb.executes;
      cb.executes = 0;
    }
    if (side.shipCarry >= 0.25) {
      _damageShip(min(0.9, side.shipCarry));
      side.shipCarry = 0;
    }
  }

  /// Once a frame: a shove in progress carries its creature on, a slow runs
  /// down, and what is left of a creature's speed is what it may move at.
  void _tickCombatBodies(double dt) {
    final opp = duelOpponent;
    final wild = _wildBody;
    if (wild != null && opp != null) _tickCombatBody(wild, opp, dt);
    for (final entry in _partyBodies.entries) {
      final host = entry.key;
      _tickCombatBody(entry.value, host is CosmicCompanion ? host : null, dt);
    }
  }

  void _tickCombatBody(_CombatBody cb, CosmicCompanion? host, double dt) {
    final body = cb.body;
    var v = body.knockbackVelocity;
    if (v.distance > _kCombatBodyMaxKnockSpeed) {
      v = v / v.distance * _kCombatBodyMaxKnockSpeed;
    }
    if (v != Offset.zero) {
      if (host != null) host.position += v * dt;
      final next = v * exp(-CosmicAbilityRuntime.knockbackDamping * dt);
      body.knockbackVelocity =
          host == null ||
              next.distance < CosmicAbilityRuntime.knockbackRestSpeed
          ? Offset.zero
          : next;
    }
    if (body.maneRootTimer > 0) {
      body.maneRootTimer = max(0.0, body.maneRootTimer - dt);
      if (body.maneRootTimer <= 0) body.maneRootSlot = null;
    }
    // Horn Plant's root reaches the creature as its zero slow below.
    if (body.hornPlantRootTimer > 0) {
      body.hornPlantRootTimer = max(0.0, body.hornPlantRootTimer - dt);
    }
    body.tickSlow(dt);
    if (host != null) host.ccMoveFactor = body.moveSpeed / _kCombatBodySpeed;
    // Pip Mud's mark: a marked body trails mud that slows whatever follows
    // through it, on the side that marked it.
    if (body.pipMudTrail) {
      cb.mudTrailTimer -= dt;
      if (cb.mudTrailTimer <= 0) {
        cb.mudTrailTimer = 0.42;
        final puff = _pipMudTrailPuff(host?.position ?? ship.pos);
        if (identical(cb, _wildBody)) {
          companionProjectiles.add(puff);
        } else {
          duelOpponentProjectiles.add(puff..sourceSlotIndex = kWildCasterSlot);
        }
      }
    }
  }

  // ── the wild Alchemon's own abilities, on its side ──────────────────────

  /// The party as bodies the wild Alchemon's abilities can touch.
  List<CosmicEnemy> _standUpPartyBodies() {
    final bodies = <CosmicEnemy>[];
    final present = <Object>{};
    for (final comp in _livingActiveCompanions) {
      final cb = _partyBodies[comp] ??= _newCombatBody(
        comp.member.element,
        _companionBodyRadius(comp),
      );
      _standUp(cb, comp.position);
      bodies.add(cb.body);
      present.add(comp);
    }
    if (!_shipDead) {
      final cb = _partyBodies[_kShipBodyKey] ??= _newCombatBody('Air', 20);
      _standUp(cb, ship.pos);
      bodies.add(cb.body);
      present.add(_kShipBodyKey);
    }
    _partyBodies.removeWhere((key, cb) {
      if (present.contains(key)) return false;
      _combatBodies.remove(cb.body);
      _wildSide.bloodMarked.remove(cb.body);
      if (key is CosmicCompanion) key.ccMoveFactor = 1.0;
      return true;
    });
    return bodies;
  }

  /// Runs [turn] in the wild Alchemon's world: the party's bodies are the
  /// enemies, it is the only companion and the ship it defends stands where
  /// it does, and what is in flight is its own. Then carries what the party's
  /// bodies took onto the party.
  void _onWildSide(CosmicCompanion opp, void Function() turn) {
    final side = _wildSide;
    final bodies = _standUpPartyBodies();

    final partyEnemies = enemies;
    final partyProjectiles = companionProjectiles;
    final partyCompanions = activeCompanions;
    final partyGarrison = _garrison;
    final partyBeams = _activeWingBeams;
    final partyPendingBeams = _pendingWingBeams;
    final partyBloodMarked = _maskBloodMarked;
    final partySpiritBank = _maskSpiritBank;
    final partyBloodTimer = _maskBloodTimer;
    final partyBloodHealing = _maskBloodHealing;
    final partySpiritWisps = _maskSpiritWisps;
    final partyPlantFeeds = _maskPlantFeeds;
    final partyShip = ship;
    final partyShipHealth = shipHealth;
    final partyShipDead = _shipDead;
    final partyBoss = activeBoss;
    final partyKinFlowers = _kinFlowers;
    final partyKinPrevShipHealth = _openKinPrevShipHealth;
    final partyKinLastShipDamage = _openKinLastShipDamage;

    side.companions
      ..clear()
      ..[kWildCasterSlot] = opp;
    enemies = bodies;
    companionProjectiles = duelOpponentProjectiles;
    activeCompanions = side.companions;
    _garrison = side.garrison;
    _activeWingBeams = side.wingBeams;
    _pendingWingBeams = side.pendingWingBeams;
    _maskBloodMarked = side.bloodMarked;
    _maskSpiritBank = side.spiritBank;
    _maskBloodTimer = side.bloodTimer;
    _maskBloodHealing = side.bloodHealing;
    _maskSpiritWisps = side.spiritWisps;
    _maskPlantFeeds = side.plantFeeds;
    _kinFlowers = side.kinFlowers;
    _openKinPrevShipHealth = side.kinPrevShipHealth;
    _openKinLastShipDamage = side.kinLastShipDamage;
    side.foeProjectiles = partyProjectiles;
    ship = side.standIn
      ..pos = opp.position
      ..angle = opp.angle;
    // Its side has no ship of its own to shield, heal or hurt.
    _shipDead = true;
    activeBoss = null;
    _onWildSideNow = true;
    try {
      turn();
    } finally {
      side.bloodTimer = _maskBloodTimer;
      side.bloodHealing = _maskBloodHealing;
      side.kinPrevShipHealth = _openKinPrevShipHealth;
      side.kinLastShipDamage = _openKinLastShipDamage;
      side.foeProjectiles = null;
      _kinFlowers = partyKinFlowers;
      _openKinPrevShipHealth = partyKinPrevShipHealth;
      _openKinLastShipDamage = partyKinLastShipDamage;
      enemies = partyEnemies;
      companionProjectiles = partyProjectiles;
      activeCompanions = partyCompanions;
      _garrison = partyGarrison;
      _activeWingBeams = partyBeams;
      _pendingWingBeams = partyPendingBeams;
      _maskBloodMarked = partyBloodMarked;
      _maskSpiritBank = partySpiritBank;
      _maskBloodTimer = partyBloodTimer;
      _maskBloodHealing = partyBloodHealing;
      _maskSpiritWisps = partySpiritWisps;
      _maskPlantFeeds = partyPlantFeeds;
      ship = partyShip;
      shipHealth = partyShipHealth;
      _shipDead = partyShipDead;
      activeBoss = partyBoss;
      _onWildSideNow = false;
    }

    for (final entry in _partyBodies.entries) {
      final host = entry.key;
      if (host is CosmicCompanion) {
        if (host.isAlive) _settleOnCompanion(entry.value, host);
      } else {
        _settleOnShip(entry.value);
      }
    }
  }

  /// The wild Alchemon's turn, on its side: what a companion does in a
  /// frame — a Horn special holding its body (a ram, a wind-up, a brew), or
  /// passives, a blessing, its basic attack and its special at [target] —
  /// then everything it has in flight.
  void _wildTurn(
    CosmicCompanion opp,
    _WildDuelTarget target,
    double targetRadius,
    double dt,
  ) {
    _updateOpenWingBeams(dt);
    updateAttachedAbilityPieces();
    updateMaskRuntime(dt);

    // Survival's order, as the party's companions run it: while a Horn
    // special holds the body its cooldowns, timers, passives, basics and
    // special wait (cosmic_game_horn.dart).
    if (!_updateHornPhases(opp, dt)) {
      if (opp.basicHasteTimer > 0) {
        opp.basicHasteTimer = max(0.0, opp.basicHasteTimer - dt);
        if (opp.basicHasteTimer <= 0) opp.basicHasteMultiplier = 1.0;
      }
      _tickOpenCompanionIdentity(opp, dt);
      _tickOpenFamilyPassives(kWildCasterSlot, opp, dt);
      // A Light horn's cooldowns wait while its barrier stands.
      if (!_hornLightChanneling(opp)) {
        opp.basicCooldown = (opp.basicCooldown - dt).clamp(0.0, 100.0);
        opp.specialCooldown = (opp.specialCooldown - dt).clamp(0.0, 100.0);
      }
      _tickCompanionBlessing(opp, dt);

      final toTarget = target.position - opp.position;
      opp.angle = atan2(toTarget.dy, toTarget.dx);
      final reach = max(0.0, toTarget.distance - targetRadius);
      // A Kin's basic attack is a charged laser (cosmic_game_kin.dart).
      if (_isKinMember(opp.member)) {
        _tickOpenKinChargedAuto(opp, target.position, reach, dt);
      } else if (opp.basicCooldown <= 0 && reach <= opp.attackRange) {
        _fireCompanionBasic(opp);
      }
      if (_companionSpecialReady(opp) && reach <= opp.specialAbilityRange) {
        _castCompanionSpecial(opp, target.position);
      }
    }

    _updateOpenKinSupports(dt);
    _updateKinFlowers(dt);
    _updateAbilityProjectiles(dt);
  }

  /// The wild Alchemon's Fire and Poison rings, drawn with the party's
  /// painter. Its beam segments are laid into the one list both sides draw
  /// from (see _renderOpenWingBeams), so they are not drawn twice.
  void _renderWildWingBeams(Canvas canvas) {
    if (_wildSide.wingBeams.isEmpty) return;
    _renderWingRings(canvas, _wildSide.wingBeams, _wingView);
  }
}
