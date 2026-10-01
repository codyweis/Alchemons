part of 'cosmic_game.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  KIN IN OPEN SPACE
//
//  Cosmic Survival's Kin, run on its shared rules (kin_support_runtime.dart):
//  the charged laser that is the family's basic attack, and each element's
//  support path — what its cast sets running, what that does every frame, and
//  what it shows. What Survival protects is its orb; out here the ship is
//  what a cast protects, and on the wild Alchemon's side (cosmic_game_duel.dart)
//  the "ship" stands where the wild one does, so a wild Kin protects itself.
//
//  Party companions, the wild Alchemon they duel and home-planet garrison
//  creatures all cast through here ([_KinCaster]).
// ─────────────────────────────────────────────────────────────────────────────

/// A creature casting a Kin support: a companion (or the wild Alchemon) or a
/// home-planet garrison creature.
class _KinCaster {
  _KinCaster.companion(CosmicCompanion this.companion) : garrison = null;
  _KinCaster.garrison(_GarrisonCreature this.garrison) : companion = null;

  final CosmicCompanion? companion;
  final _GarrisonCreature? garrison;

  KinSupportFields get kin => companion ?? garrison!;
  CosmicPartyMember get member => companion?.member ?? garrison!.member;
  Offset get position => companion?.position ?? garrison!.position;
  int? get slot => member.slotIndex;
  double get facing => companion?.angle ?? garrison!.faceAngle;

  /// Survival reads these through its `_effective*` stats (power-ups on top,
  /// floored at 0.5); open space has no power-ups.
  double get beauty => max(0.5, member.statBeauty.toDouble());
  double get intelligence => max(0.5, member.statIntelligence.toDouble());
  double get speed => max(0.5, member.statSpeed.toDouble());

  double get abilityAtk =>
      companion?.abilityAtk.toDouble() ?? garrison!.specialDamage;
  int get hp => companion?.currentHp ?? garrison!.hp;

  /// The basic attack's haste, held at [multiplier] for at least [duration].
  void haste(double duration, double multiplier) {
    final c = companion;
    if (c != null) {
      c.basicHasteTimer = max(c.basicHasteTimer, duration);
      c.basicHasteMultiplier = min(c.basicHasteMultiplier, multiplier);
    } else {
      final g = garrison!;
      g.basicHasteTimer = max(g.basicHasteTimer, duration);
      g.basicHasteMultiplier = min(g.basicHasteMultiplier, multiplier);
    }
  }

  /// A damage amp held at [amp] for at least [duration].
  void holdDamageAmp(double duration, double amp) {
    final c = companion;
    if (c != null) {
      c.damageAmpTimer = max(c.damageAmpTimer, duration);
      c.damageAmpMultiplier = max(c.damageAmpMultiplier, amp);
    } else {
      final g = garrison!;
      g.damageAmpTimer = max(g.damageAmpTimer, duration);
      g.damageAmpMultiplier = max(g.damageAmpMultiplier, amp);
    }
  }
}

/// A flower the Plant kin's garden grew, waiting for the ship (on the wild
/// Alchemon's side, for the wild one). Collecting it heals every alchemon
/// and the ship.
class _KinFlower {
  _KinFlower({
    required this.position,
    required this.healAmount,
    required this.bobPhase,
  });

  Offset position;
  final double healAmount;
  final double bobPhase;
  double life = WingBeamRules.flowerLife;
  bool get dead => life <= 0;
}

extension CosmicKin on CosmicGame {
  /// Lengths of the Kin lasers being drawn, for tests.
  List<double> get debugKinLaserLengths => [
    for (final b in _kinLaserBeams) (b.end - b.origin).distance,
  ];

  /// Where this side's Kin garden flowers lie, for tests.
  List<Offset> get debugKinFlowers => [for (final f in _kinFlowers) f.position];

  bool _isKinMember(CosmicPartyMember m) => m.family.toLowerCase() == 'kin';

  bool _kinVfxHasRoom() => _abilityVfx.length < 150;

  // ── the objective ───────────────────────────────────────────────────────

  /// Whether the body this side's casts protect is standing: the ship, or on
  /// the wild Alchemon's side the wild one itself (it is, while it acts).
  bool get _objectiveStands => _onWildSideNow || !_shipDead;

  /// Heals the body this side's casts protect: the ship, or on the wild
  /// Alchemon's side the wild one itself (survival's orb).
  void _healOpenObjective(double amount) {
    if (amount <= 0) return;
    if (_onWildSideNow) {
      for (final comp in _livingActiveCompanions) {
        comp.currentHp = min(comp.maxHp, comp.currentHp + amount.round());
      }
    } else if (!_shipDead) {
      shipHealth = min(CosmicGame.shipMaxHealth, shipHealth + amount);
    }
  }

  /// A zone heal tends the one ally with the lowest share of its health —
  /// the ship (while it stands) or a companion, the ship first on a tie.
  void _healOpenLowestAlly(double amount) {
    if (amount <= 0) return;
    final comps = [
      for (final comp in _livingActiveCompanions)
        if (comp.maxHp > 0) comp,
    ];
    final shipIn = !_shipDead;
    final pick = CosmicAbilityRuntime.lowestFraction([
      if (shipIn) shipHealth / CosmicGame.shipMaxHealth,
      for (final comp in comps) comp.currentHp / comp.maxHp,
    ]);
    if (pick < 0) return;
    if (shipIn && pick == 0) {
      shipHealth = min(CosmicGame.shipMaxHealth, shipHealth + amount);
      return;
    }
    final comp = comps[pick - (shipIn ? 1 : 0)];
    comp.currentHp = min(comp.maxHp, comp.currentHp + amount.round());
  }

  /// Every living alchemon and the ship, healed by [amount].
  void _healOpenAlliesAndShip(double amount) {
    if (amount <= 0) return;
    if (!_shipDead) {
      shipHealth = min(CosmicGame.shipMaxHealth, shipHealth + amount);
    }
    for (final comp in _livingActiveCompanions) {
      comp.currentHp = min(comp.maxHp, comp.currentHp + amount.round());
    }
  }

  // ── kills ───────────────────────────────────────────────────────────────

  /// What any kill credited to [sourceSlot] sets off, however it was made —
  /// a projectile, a laser, a zone, a splash — as survival's `_killEnemy`
  /// runs it: a Mane Plant root blows up on everything near, and a Spirit
  /// kin's wisp is fed.
  void _onOpenKill(int? sourceSlot, CosmicEnemy enemy) {
    if (sourceSlot == null) return;
    final comp = activeCompanions[sourceSlot];
    _GarrisonCreature? g;
    if (comp == null) {
      for (final other in _garrison) {
        if (other.member.slotIndex == sourceSlot) {
          g = other;
          break;
        }
      }
    }
    // Mane+Plant: a body killed inside its root window blows the root up on
    // everything near, and roots them in turn.
    final rootSlot = enemy.maneRootSlot;
    if (rootSlot != null && enemy.maneRootTimer > 0) {
      final explodeDamage =
          (comp?.elemAtk.toDouble() ?? g?.specialDamage ?? 4.0) *
          ManeRuntime.plantRootExplodeShare;
      for (final other in enemies) {
        if (other.dead || identical(other, enemy)) continue;
        if ((other.position - enemy.position).distance >=
            ManeRuntime.plantRootExplodeRadius) {
          continue;
        }
        _damageOpenEnemy(other, explodeDamage, sourceSlot: rootSlot);
        other.maneRootSlot = rootSlot;
        other.maneRootTimer = max(
          other.maneRootTimer,
          ManeRuntime.plantRootChainTime,
        );
        other.applySlow(0, ManeRuntime.plantRootChainTime);
      }
      _spawnHitSpark(enemy.position, elementColor('Plant'));
    }
    // Kin+Spirit: every kill the Spirit kin makes feeds its wisp.
    final member = comp?.member ?? g?.member;
    if (member != null && _isKinMember(member) && member.element == 'Spirit') {
      (comp ?? g!).kinSpiritWispKills++;
    }
  }

  /// [damage] to every foe within [radius] of [center], each kill credited
  /// to [sourceSlot].
  void _damageOpenFoesNear(
    Offset center,
    double radius,
    double damage, {
    int? sourceSlot,
    String? element,
  }) {
    for (final enemy in enemies) {
      if (enemy.dead || (enemy.position - center).distance > radius) continue;
      _damageOpenEnemy(enemy, damage, element: element, sourceSlot: sourceSlot);
    }
  }

  CosmicEnemy? _nearestOpenFoe(
    Offset origin,
    double range, {
    CosmicEnemy? exclude,
  }) {
    CosmicEnemy? target;
    var best = range;
    for (final enemy in enemies) {
      if (enemy.dead || identical(enemy, exclude)) continue;
      final d = (enemy.position - origin).distance;
      if (d < best) {
        best = d;
        target = enemy;
      }
    }
    return target;
  }

  /// Chain lightning off a struck body: each hop the nearest other body
  /// within reach, for a falling share of [base] (survival's chain; a Kin
  /// Lightning tesla channel is what grants it out here).
  void _chainOpenLightning(
    CosmicEnemy from,
    double base,
    int charges,
    int? sourceSlot,
  ) {
    if (charges <= 0 || sourceSlot == null) return;
    var current = from;
    for (var i = 0; i < charges; i++) {
      final next = _nearestOpenFoe(
        current.position,
        CosmicAbilityRuntime.chainRange,
        exclude: current,
      );
      if (next == null) break;
      _spawnHitSpark(next.position, elementColor('Lightning'));
      _damageOpenEnemy(
        next,
        CosmicAbilityRuntime.chainBounceDamage(base, i),
        element: 'Lightning',
        sourceSlot: sourceSlot,
      );
      current = next;
    }
  }

  // ── what is running, on this side ───────────────────────────────────────

  bool _anyOpenKin(String element, double Function(KinSupportFields k) timer) {
    for (final comp in activeCompanions.values) {
      if (comp.isAlive &&
          _isKinMember(comp.member) &&
          comp.member.element == element &&
          timer(comp) > 0) {
        return true;
      }
    }
    for (final g in _garrison) {
      if (g.hp > 0 &&
          _isKinMember(g.member) &&
          g.member.element == element &&
          timer(g) > 0) {
        return true;
      }
    }
    return false;
  }

  bool get _openKinLightningActive =>
      _anyOpenKin('Lightning', (k) => k.kinLightningChargeTimer);

  bool get _openKinDarkCloakActive =>
      _anyOpenKin('Dark', (k) => k.kinDarkCloakTimer);

  bool get _openKinLavaPlateActive =>
      _anyOpenKin('Lava', (k) => k.kinLavaPlateTimer);

  bool get _openKinBloodPactActive =>
      _anyOpenKin('Blood', (k) => k.kinBloodPactTimer);

  /// A Kin holds still while it gathers its laser (only while it has a
  /// target to fire at), charges its Ice release, or channels its tesla.
  bool _kinHoldsBody(
    KinSupportFields k,
    CosmicPartyMember m, {
    bool engaged = true,
  }) {
    if (!_isKinMember(m)) return false;
    if (engaged && k.kinAutoChargeTimer > 0) return true;
    return (m.element == 'Ice' && k.kinIceChargeTimer > 0) ||
        (m.element == 'Lightning' && k.kinLightningChargeTimer > 0);
  }

  // ── the cast ────────────────────────────────────────────────────────────

  void _activateOpenKinSupport(CosmicCompanion comp, Offset target) =>
      _activateOpenKinCast(_KinCaster.companion(comp), target);

  void _activateOpenGarrisonKinSupport(_GarrisonCreature g, Offset target) =>
      _activateOpenKinCast(_KinCaster.garrison(g), target);

  /// What a Kin's cast sets running: a timer on the caster for most, a piece
  /// laid on the field for Dust, Spirit and Earth.
  void _activateOpenKinCast(_KinCaster c, Offset target) {
    switch (c.member.element) {
      case 'Dust':
        // Field-placed: first cast places one, later casts add more.
        if (KinSupport.countDustClouds(companionProjectiles, c.slot) <
            KinSupport.dustCloudCap) {
          companionProjectiles.add(
            KinSupport.dustCloud(
              target,
              beauty: c.beauty,
              intelligence: c.intelligence,
              slot: c.slot,
            ),
          );
        }
      case 'Spirit':
        final existing = KinSupport.findSpiritWisp(
          companionProjectiles,
          c.slot,
        );
        if (existing != null) {
          // Refresh its life so the wisp persists between casts.
          existing.life = max(existing.life, KinSupport.spiritWispLife);
        } else {
          c.kin.kinSpiritWispKills = 0;
          companionProjectiles.add(KinSupport.spiritWisp(c.position, c.slot));
        }
      case 'Earth':
        // Round what the cast protects, facing where it was cast.
        companionProjectiles.addAll(
          KinSupport.earthWallArc(
            center: ship.pos,
            facing: c.facing,
            beauty: c.beauty,
            slot: c.slot,
          ),
        );
      default:
        KinSupport.activateTimers(
          c.kin,
          c.member.element,
          intelligence: c.intelligence,
        );
    }
  }

  // ── every frame ─────────────────────────────────────────────────────────

  /// This side's Kin supports, once a frame: party companions (or the wild
  /// Alchemon on its side).
  void _updateOpenKinSupports(double dt) {
    // Ship damage this frame, for the reactive paths (Lava, Steam, Blood).
    final shipDelta = _openKinPrevShipHealth >= 0 && !_shipDead
        ? max(0.0, _openKinPrevShipHealth - shipHealth)
        : 0.0;
    _openKinPrevShipHealth = shipHealth.toDouble();
    _openKinLastShipDamage = shipDelta;
    for (final comp in activeCompanions.values.toList(growable: false)) {
      if (!comp.isAlive || !_isKinMember(comp.member)) continue;
      _tickOpenKinSupport(_KinCaster.companion(comp), shipDelta, dt);
    }
  }

  void _updateOpenGarrisonKinSupport(_GarrisonCreature g, double dt) {
    if (!_isKinMember(g.member) || g.hp <= 0) return;
    _tickOpenKinSupport(_KinCaster.garrison(g), _openKinLastShipDamage, dt);
  }

  /// One Kin's support path for a frame, as survival's `_updateKinSupportTick`
  /// runs it. [shipDelta] is what the ship took this frame.
  void _tickOpenKinSupport(_KinCaster c, double shipDelta, double dt) {
    final k = c.kin;
    final element = c.member.element;
    final slot = c.slot;
    final hp = c.hp;
    final ownDelta = k.kinPrevHp > 0
        ? max(0, k.kinPrevHp - hp).toDouble()
        : 0.0;
    k.kinPrevHp = hp;
    // Damage to the alchemons themselves and to what they protect.
    final bodyDamage = shipDelta + ownDelta;

    // ── Fire: the reborn flame (permanent once the phoenix has fired) ──
    if (k.kinFireOrbitalFlameActive) {
      // The reborn kin keeps its buff for good, so the windows the rest of
      // the game buffs through are simply held open.
      c.haste(0.5, k.kinFireRebirthHaste);
      c.holdDamageAmp(0.5, k.kinFireRebirthDamageAmp);
      k.kinFireFlameTimer -= dt;
      if (k.kinFireFlameTimer <= 0) {
        k.kinFireFlameTimer = k.kinFireFlameInterval;
        _damageOpenFoesNear(
          c.position,
          k.kinFireFlameRadius,
          KinSupport.fireFlameDamage(c.abilityAtk),
          sourceSlot: slot,
          element: 'Fire',
        );
      }
    }

    // ── Lava: splash at whatever struck, near what it protects ──
    if (k.kinLavaPlateTimer > 0) {
      k.kinLavaPlateTimer = max(0, k.kinLavaPlateTimer - dt);
      if (element == 'Lava' && bodyDamage > 0) {
        final target = _nearestOpenFoe(ship.pos, KinSupport.lavaSearchShip);
        if (target != null) {
          final at = target.position;
          _damageOpenFoesNear(
            at,
            KinSupport.lavaSplashRadius,
            KinSupport.lavaSplashDamage(bodyDamage, c.abilityAtk),
            sourceSlot: slot,
            element: 'Lava',
          );
          _spawnHitSpark(at, KinSupport.lavaSplashColor);
        }
      }
    }

    // ── Steam: damage taken becomes attack speed for everyone ──
    if (k.kinSteamBoilerTimer > 0 && element == 'Steam') {
      k.kinSteamBoilerTimer = max(0, k.kinSteamBoilerTimer - dt);
      final boiler = KinSupport.steamStep(
        stacks: k.kinSteamBoilerStacks,
        carry: k.kinSteamStackCarry,
        decayTimer: k.kinSteamStackDecayTimer,
        gain: bodyDamage > 0
            ? bodyDamage / KinSupport.steamBodyUnit(CosmicGame.shipMaxHealth)
            : 0,
        dt: dt,
      );
      k.kinSteamBoilerStacks = boiler.stacks;
      k.kinSteamStackCarry = boiler.carry;
      k.kinSteamStackDecayTimer = boiler.decayTimer;
      final mult = KinSupport.steamHasteMultiplier(
        k.kinSteamBoilerStacks,
        c.beauty,
      );
      for (final ally in activeCompanions.values) {
        ally.basicHasteTimer = max(ally.basicHasteTimer, 0.5);
        ally.basicHasteMultiplier = min(ally.basicHasteMultiplier, mult);
      }
      if (c.garrison != null) {
        for (final ally in _garrison) {
          ally.basicHasteTimer = max(ally.basicHasteTimer, 0.5);
          ally.basicHasteMultiplier = min(ally.basicHasteMultiplier, mult);
        }
      }
    }

    // ── Ice: the charge, then the release ──
    if (k.kinIceChargeTimer > 0) {
      k.kinIceChargeTimer = max(0, k.kinIceChargeTimer - dt);
      if (k.kinIceChargeTimer <= 0 && element == 'Ice') _releaseOpenKinIce(c);
    }

    // ── Lightning: the tesla channel (the kin holds still) ──
    if (k.kinLightningChargeTimer > 0) {
      k.kinLightningChargeTimer = max(0, k.kinLightningChargeTimer - dt);
    }

    // ── Dark: the veil ──
    if (k.kinDarkCloakTimer > 0) {
      k.kinDarkCloakTimer = max(0, k.kinDarkCloakTimer - dt);
    }

    // ── Blood: what they take is healed back across the living ──
    if (k.kinBloodPactTimer > 0) {
      k.kinBloodPactTimer = max(0, k.kinBloodPactTimer - dt);
      if (element == 'Blood' && bodyDamage > 0) {
        _splitOpenBloodPact(
          bodyDamage * KinSupport.bloodHealShare,
          withGarrison: c.garrison != null,
        );
      }
    }

    // ── Mud: the enchanted ship trails slowing mud ──
    if (k.kinMudShipEnchantTimer > 0) {
      k.kinMudShipEnchantTimer = max(0, k.kinMudShipEnchantTimer - dt);
      if (element == 'Mud' && _objectiveStands) {
        // The Mud kin's tick gate; it has no boiler of its own.
        k.kinSteamStackDecayTimer -= dt;
        if (k.kinSteamStackDecayTimer <= 0) {
          k.kinSteamStackDecayTimer = KinSupport.mudPatchInterval;
          companionProjectiles.add(KinSupport.mudPatch(ship.pos, slot));
        }
      }
    }

    // ── Spirit: the wisp's form follows the kills ──
    if (element == 'Spirit') {
      final wisp = KinSupport.findSpiritWisp(companionProjectiles, slot);
      if (wisp != null) {
        KinSupport.applySpiritWispTier(wisp, k.kinSpiritWispKills);
      }
    }
  }

  /// The Ice release: everything in reach slowed to a tenth for a while,
  /// frost shooting out to each body it caught.
  void _releaseOpenKinIce(_KinCaster c) {
    final origin = c.position;
    final radius = KinSupport.iceReleaseRadius(c.beauty);
    final slowDuration = KinSupport.iceSlowDuration(c.intelligence);
    final struck = <Offset>[];
    for (final e in enemies) {
      if (e.dead || (e.position - origin).distance > radius) continue;
      e.applySlow(KinSupport.iceSlowMultiplier, slowDuration);
      struck.add(e.position);
    }
    emitKinIceRelease(
      origin: origin,
      targets: struck,
      rng: _rng,
      hasRoom: _kinVfxHasRoom,
      emit: _abilityVfx.add,
      spark: _spawnHitSpark,
      iceColor: elementColor('Ice'),
    );
    _spawnHitSpark(origin, elementColor('Ice'));
  }

  /// The Blood pact's heal, split evenly over the living: the ship (while it
  /// stands) and every living alchemon — a garrison Kin's home defenders too.
  void _splitOpenBloodPact(double pool, {bool withGarrison = false}) {
    final comps = _livingActiveCompanions.toList(growable: false);
    final garrison = withGarrison
        ? _garrison.where((g) => g.hp > 0).toList(growable: false)
        : const <_GarrisonCreature>[];
    final shipIn = !_shipDead;
    final living = comps.length + garrison.length + (shipIn ? 1 : 0);
    if (living == 0) return;
    final perAlly = pool / living;
    if (shipIn) {
      shipHealth = min(CosmicGame.shipMaxHealth, shipHealth + perAlly);
    }
    for (final ally in comps) {
      ally.currentHp = min(ally.maxHp, ally.currentHp + perAlly.round());
    }
    for (final g in garrison) {
      g.hp = min(g.maxHp, g.hp + perAlly.round());
    }
  }

  // ── Fire: the phoenix ───────────────────────────────────────────────────

  /// The ship has fallen: a deployed Fire kin whose phoenix has not yet fired
  /// catches it at a quarter health. True if one did.
  bool _tryOpenKinPhoenixSave() {
    _KinCaster? phoenix;
    for (final comp in activeCompanions.values) {
      if (comp.isAlive &&
          _isKinMember(comp.member) &&
          comp.member.element == 'Fire' &&
          !comp.kinFireOrbitalFlameActive) {
        phoenix = _KinCaster.companion(comp);
        break;
      }
    }
    if (phoenix == null) {
      for (final g in _garrison) {
        if (g.hp > 0 &&
            _isKinMember(g.member) &&
            g.member.element == 'Fire' &&
            !g.kinFireOrbitalFlameActive) {
          phoenix = _KinCaster.garrison(g);
          break;
        }
      }
    }
    if (phoenix == null) return false;
    shipHealth = CosmicGame.shipMaxHealth * KinSupport.phoenixRestoreFraction;
    _awakenOpenPhoenix(phoenix, ship.pos);
    return true;
  }

  /// The wild Alchemon has fallen: a wild Fire kin protects itself the way a
  /// party one protects the ship, once. True if it rose again.
  bool _tryWildKinPhoenixSave(CosmicCompanion opp) {
    if (!_isKinMember(opp.member) ||
        opp.member.element != 'Fire' ||
        opp.kinFireOrbitalFlameActive) {
      return false;
    }
    opp.currentHp = max(
      1,
      (opp.maxHp * KinSupport.phoenixRestoreFraction).round(),
    );
    _awakenOpenPhoenix(_KinCaster.companion(opp), opp.position);
    return true;
  }

  /// The phoenix fires at [at]: its burst, and the rebirth rolled from the
  /// kin's own stats and kept for good.
  void _awakenOpenPhoenix(_KinCaster c, Offset at) {
    _spawnHitSpark(at, KinSupport.phoenixEmber);
    _spawnHitSpark(at, KinSupport.phoenixFlash);
    emitKinPhoenixBurst(
      at: at,
      rng: _rng,
      hasRoom: _kinVfxHasRoom,
      emit: _abilityVfx.add,
    );
    final k = c.kin;
    k.kinFireOrbitalFlameActive = true;
    final rebirth = KinSupport.fireRebirth(beauty: c.beauty, speed: c.speed);
    k.kinFireFlameRadius = rebirth.radius;
    k.kinFireFlameInterval = rebirth.interval;
    k.kinFireRebirthHaste = rebirth.haste;
    k.kinFireRebirthDamageAmp = rebirth.damageAmp;
    k.kinFireFlameTimer = 0;
  }

  // ── the basic attack: a charge, then a laser ────────────────────────────

  /// A companion's (or the wild Alchemon's) Kin basic attack for a frame.
  void _tickOpenKinChargedAuto(
    CosmicCompanion comp,
    Offset targetPos,
    double distToTarget,
    double dt,
  ) {
    _tickOpenKinCharge(
      comp,
      origin: comp.position,
      targetPos: targetPos,
      distToTarget: distToTarget,
      attackRange: comp.attackRange,
      ready: comp.basicCooldown <= 0,
      dt: dt,
      fire: (aim) {
        _fireOpenKinLaser(
          origin: comp.position,
          target: aim,
          damage:
              comp.physAtk.toDouble() * KinLaser.damageScale * comp.damageAmp,
          element: comp.member.element,
          sourceSlot: comp.member.slotIndex,
        );
        comp.basicCooldown = comp.effectiveBasicCooldown;
      },
    );
  }

  /// A garrison Kin's basic attack for a frame; [cooldown] is what it waits
  /// between shots.
  void _tickOpenGarrisonKinChargedAuto(
    _GarrisonCreature g,
    Offset targetPos,
    double distToTarget,
    double cooldown,
    double dt,
  ) {
    _tickOpenKinCharge(
      g,
      origin: g.position,
      targetPos: targetPos,
      distToTarget: distToTarget,
      attackRange: g.attackRange,
      ready: g.attackCooldown <= 0,
      dt: dt,
      fire: (aim) {
        _fireOpenKinLaser(
          origin: g.position,
          target: aim,
          damage:
              g.attackDamage * KinLaser.damageScale * _openGarrisonDamageAmp(g),
          element: g.member.element,
          sourceSlot: g.member.slotIndex,
        );
        g.attackCooldown = cooldown;
      },
    );
  }

  /// Survival's `_tickKinChargedAuto`: cooldown spent and the target in
  /// range, the kin starts gathering and locks the body nearest what it
  /// aimed at; 1.5s later it fires at that body if it still stands, else the
  /// nearest in reach, else where it aimed.
  void _tickOpenKinCharge(
    KinSupportFields k, {
    required Offset origin,
    required Offset targetPos,
    required double distToTarget,
    required double attackRange,
    required bool ready,
    required double dt,
    required void Function(Offset aim) fire,
  }) {
    if (k.kinAutoChargeTimer > 0) {
      k.kinAutoChargeTimer += dt;
      if (k.kinAutoChargeTimer >= KinLaser.chargeTime) {
        final locked = k.kinAutoChargeEnemy;
        final Offset aim;
        if (locked != null && !locked.dead && enemies.contains(locked)) {
          aim = locked.position;
        } else {
          aim =
              _nearestOpenFoe(
                origin,
                attackRange + KinLaser.fallbackExtra,
              )?.position ??
              k.kinAutoChargeTarget ??
              targetPos;
        }
        fire(aim);
        k.kinAutoChargeTimer = 0;
        k.kinAutoChargeTarget = null;
        k.kinAutoChargeEnemy = null;
      }
      return;
    }
    if (ready && distToTarget <= attackRange) {
      k.kinAutoChargeTimer = 0.001; // marker: the charge has started
      k.kinAutoChargeTarget = targetPos;
      k.kinAutoChargeEnemy =
          _nearestOpenFoe(targetPos, KinLaser.lockRadius) ??
          _nearestOpenFoe(origin, attackRange + KinLaser.fallbackExtra);
    }
  }

  /// The laser: every foe along the line takes [damage] (bosses are not in
  /// the list, as survival's laser never reaches its bosses), and a kill is
  /// credited to [sourceSlot] — a Spirit kin's wisp feeds on these.
  void _fireOpenKinLaser({
    required Offset origin,
    required Offset target,
    required double damage,
    required String element,
    required int? sourceSlot,
  }) {
    final dir = target - origin;
    final dist = dir.distance;
    if (dist < 0.01) return;
    final end = origin + dir / dist * KinLaser.length(dist);
    final color = elementColor(element);
    for (final enemy in enemies) {
      if (enemy.dead) continue;
      if (KinLaser.distanceToSegment(enemy.position, origin, end) >
          enemy.radius + KinLaser.lateral) {
        continue;
      }
      _damageOpenEnemy(enemy, damage, element: element, sourceSlot: sourceSlot);
      _spawnHitSpark(enemy.position, color);
      if (!enemy.dead &&
          !enemy.provoked &&
          (enemy.behavior == EnemyBehavior.feeding ||
              enemy.behavior == EnemyBehavior.territorial ||
              enemy.behavior == EnemyBehavior.drifting)) {
        _provokePackOf(enemy);
      }
    }
    pushKinLaserBeam(
      _kinLaserBeams,
      KinLaserBeam(origin: origin, end: end, color: color),
    );
  }

  // ── hostile shots meeting Kin pieces ────────────────────────────────────

  /// The other side's basic shots — the duel's analog of survival's enemy
  /// shots — against this side's pieces: a reflector (an Earth wall, a Horn
  /// wall) throws one back at the nearest foe, a Dust cloud swallows it at
  /// 80% a frame, and a Light or Crystal escort takes it (a Crystal one
  /// refracting a beam into the nearest foe).
  ///
  /// The Dust screen is the party's only: a wild Dust kin lays its cloud on
  /// the companions it fights, and at 80% a frame it swallowed every shot
  /// they fired from inside it, which left the duel unwinnable.
  void _screenFoeShots() {
    if (!wildDuelActive) return;
    final foes = _onWildSideNow
        ? _wildSide.foeProjectiles
        : duelOpponentProjectiles;
    if (foes == null || foes.isEmpty) return;
    List<Projectile>? reflectors;
    var anyDust = false;
    var anyInterceptor = false;
    for (final p in companionProjectiles) {
      if (p.life <= 0) continue;
      if (p.reflectsProjectiles && p.stationary) {
        (reflectors ??= <Projectile>[]).add(p);
      }
      if (!_onWildSideNow && KinSupport.isDustCloud(p)) anyDust = true;
      if (p.interceptCharges > 0 && p.interceptRadius > 0) {
        anyInterceptor = true;
      }
    }
    if (reflectors == null && !anyDust && !anyInterceptor) return;
    for (var i = foes.length - 1; i >= 0; i--) {
      if (i >= foes.length) continue;
      final shot = foes[i];
      if (shot.abilityFamily.isNotEmpty ||
          shot.stationary ||
          shot.orbitCenter != null ||
          shot.isDescending ||
          shot.life <= 0) {
        continue;
      }
      final shotRadius = Projectile.radius * shot.radiusMultiplier;
      if (reflectors != null && _reflectFoeShot(shot, shotRadius, reflectors)) {
        foes.removeAt(i);
        continue;
      }
      if (anyDust &&
          KinSupport.insideDustCloud(companionProjectiles, shot.position) &&
          _rng.nextDouble() < KinSupport.dustShotMissChance) {
        foes.removeAt(i);
        continue;
      }
      if (anyInterceptor &&
          _consumeEscortInterceptionAt(shot.position, shotRadius)) {
        foes.removeAt(i);
      }
    }
  }

  /// Survival's `_attemptProjectileReflect`: a shot inside a fixture is
  /// turned at the nearest foe (or straight back) and becomes this side's.
  bool _reflectFoeShot(
    Projectile shot,
    double shotRadius,
    List<Projectile> reflectors,
  ) {
    for (final fixture in reflectors) {
      final reach = shotRadius + KinSupport.reflectorRadius(fixture);
      if ((fixture.position - shot.position).distanceSquared >= reach * reach) {
        continue;
      }
      final near = _nearestOpenFoe(
        shot.position,
        KinSupport.reflectRetargetRange,
      );
      final to = near == null ? null : near.position - shot.position;
      shot.angle = to != null && to.distanceSquared > 0.01
          ? atan2(to.dy, to.dx)
          : shot.angle + pi;
      shot.sourceSlotIndex = null;
      companionProjectiles.add(shot);
      _spawnHitSpark(fixture.position, const Color(0xFFE5F4FF));
      return true;
    }
    return false;
  }

  /// A Crystal refractor that took a shot fires a refracted beam into the
  /// nearest foe.
  void _refractOpenKinShot(Projectile shard) {
    if (shard.abilityFamily != 'kin' || shard.element != 'Crystal') return;
    final target = _nearestOpenFoe(
      shard.position,
      KinSupport.crystalRefractRange,
    );
    if (target == null) return;
    _damageOpenEnemy(
      target,
      KinSupport.crystalRefractDamage(shard),
      element: 'Crystal',
      sourceSlot: shard.sourceSlotIndex,
    );
    _spawnHitSpark(target.position, elementColor('Crystal'));
    pushKinLaserBeam(
      _kinLaserBeams,
      KinLaserBeam(
        origin: shard.position,
        end: target.position,
        color: KinSupport.refractColor,
      ),
    );
  }

  // ── Plant: the garden's flowers ─────────────────────────────────────────

  /// A garden drops a flower every few seconds; called from the ability pass.
  void _growOpenKinGarden(Projectile garden, double dt) {
    garden.abilityGrowthTimer += dt;
    if (garden.abilityGrowthTimer < kKinGardenFlowerInterval) return;
    garden.abilityGrowthTimer = 0;
    final spot = kinGardenFlowerSpot(garden, _rng);
    if (_kinFlowers.length >= WingBeamRules.flowerCap) return;
    _kinFlowers.add(
      _KinFlower(
        position: spot,
        healAmount: kinGardenFlowerHeal(garden),
        bobPhase: _rng.nextDouble() * pi * 2,
      ),
    );
  }

  /// This side's flowers drift to what the side protects (the ship; on the
  /// wild side the wild one) and heal every alchemon and the ship when
  /// collected.
  void _updateKinFlowers(double dt) {
    if (_kinFlowers.isEmpty) return;
    final collector = _objectiveStands ? ship.pos : null;
    for (final flower in _kinFlowers) {
      flower.life -= dt;
      if (flower.dead || collector == null) continue;
      final next = WingBeamRules.flowerStep(flower.position, collector, dt);
      if (next == null) {
        flower.life = 0;
        _healOpenAlliesAndShip(flower.healAmount);
        _spawnHitSpark(collector, elementColor('Plant'));
        continue;
      }
      flower.position = next;
    }
    _kinFlowers.removeWhere((f) => f.dead);
  }

  // ── what it shows ───────────────────────────────────────────────────────

  /// A Kin's running support worn round its body (canvas at its centre):
  /// its aura, the laser gathering, the Steam badge — and, for anyone on the
  /// side of a raised Lava plate, the plate. [lavaTeam] is whether a Lava
  /// plate holds on the wearer's side.
  void _renderKinOverlay(
    Canvas canvas,
    KinSupportFields k,
    CosmicPartyMember member, {
    required Offset position,
    required bool lavaTeam,
  }) {
    final isKin = _isKinMember(member);
    if (isKin) {
      drawAdvancedKinSupportAura(
        canvas: canvas,
        element: member.element,
        color: elementColor(member.element),
        time: _elapsed,
        iceChargeProgress: k.kinIceChargeTimer > 0 && k.kinIceChargeTotal > 0
            ? 1 - k.kinIceChargeTimer / k.kinIceChargeTotal
            : 0,
        lightningActive: k.kinLightningChargeTimer > 0,
        fireOrbitalActive: k.kinFireOrbitalFlameActive,
        fireOrbitalRadius: k.kinFireFlameRadius,
        lavaPlateActive: k.kinLavaPlateTimer > 0,
        darkCloakActive: k.kinDarkCloakTimer > 0,
        steamPressure: k.kinSteamBoilerTimer > 0
            ? k.kinSteamBoilerStacks / KinSupport.steamMaxStacks
            : 0,
      );
    }
    // The team-wide plate on everyone but the Lava kin itself.
    if (lavaTeam && !(isKin && member.element == 'Lava')) {
      drawKinLavaPlate(canvas: canvas, time: _elapsed, scale: 0.85);
    }
    if (!isKin) return;
    if (k.kinAutoChargeTimer > 0) {
      final locked = k.kinAutoChargeEnemy;
      final aim = locked != null && !locked.dead
          ? locked.position
          : k.kinAutoChargeTarget;
      drawAdvancedKinCharge(
        canvas: canvas,
        color: elementColor(member.element),
        progress: (k.kinAutoChargeTimer / KinLaser.chargeTime).clamp(0.0, 1.0),
        time: _elapsed,
        aimDirection: aim == null ? null : aim - position,
      );
    }
    if (member.element == 'Steam' && k.kinSteamBoilerTimer > 0) {
      drawKinSteamBadge(canvas: canvas, stacks: k.kinSteamBoilerStacks);
    }
  }

  /// The party's Kin on the ship (canvas at its centre, unrotated): a Lava
  /// plate's glow and a tesla channel's current.
  void _renderKinShipOverlay(Canvas canvas) {
    final lava = _openKinLavaPlateActive;
    final tesla = _openKinLightningActive;
    if (!lava && !tesla) return;
    canvas.save();
    canvas.translate(ship.pos.dx, ship.pos.dy);
    if (lava) drawKinLavaShipGlow(canvas: canvas, time: _elapsed);
    if (tesla) drawKinTeslaShip(canvas: canvas, time: _elapsed, rng: _rng);
    canvas.restore();
  }

  /// World-space Kin art: the Blood pact's threads between the party, the
  /// lasers (both sides'), and the garden flowers (both sides').
  void _renderKinWorld(Canvas canvas) {
    if (_openKinBloodPactActive) {
      drawKinBloodThreads(
        canvas: canvas,
        allies: [
          if (!_shipDead) ship.pos,
          for (final c in _livingActiveCompanions) c.position,
        ],
        time: _elapsed,
      );
    }
    for (final beam in _kinLaserBeams) {
      if (beam.dead) continue;
      drawKinLaser(
        canvas: canvas,
        start: beam.origin,
        end: beam.end,
        color: beam.color,
        width: KinLaser.beamWidth,
        alpha: beam.alpha,
      );
    }
  }

  void _renderKinFlowers(Canvas canvas) {
    for (final list in [_kinFlowers, _wildSide.kinFlowers]) {
      for (final flower in list) {
        drawWingFlowerPickup(
          canvas: canvas,
          position: flower.position,
          life: flower.life,
          bobPhase: flower.bobPhase,
          time: _elapsed,
        );
      }
    }
  }
}
