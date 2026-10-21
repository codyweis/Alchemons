part of 'cosmic_game.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  WING BEAMS IN OPEN SPACE
//
//  Cosmic Survival is the source of truth, and this is its beam runtime
//  (`_activateWingBeamEffects`, `_updateBeamEffects`, `_resolveBeamTick` and
//  the Lightning, Steam, Light and Plant hooks) run against open space's
//  world. The numbers are WingBeamRules (cosmic_ability_runtime.dart) and the
//  look is wing_vfx.dart, both shared with survival, so the two cannot drift.
//
//  Open space has no orb. Where survival's beams lean on it the ship stands
//  in: Earth's mirror beam fires from the ship, and a leech or flower hit
//  feeds the ship. A healing tick already heals the ship in survival, so the
//  orb's share of it is dropped rather than paid to the ship twice.
//
//  A beam reaches foes only through [CosmicGame.enemies] and
//  [CosmicGame.activeBoss], and allies only through the companions, the
//  garrison and the ship. The wild Alchemon a party duels runs this same code
//  on its own side (cosmic_game_duel.dart), where those lists hold the other
//  side's bodies — so nothing here needs to know which side it is on.
// ─────────────────────────────────────────────────────────────────────────────

/// Where a live beam stands, re-read every frame.
enum _WingAnchor {
  /// On its caster; it holds where the caster last stood once it is gone,
  /// and burns out on its own time.
  caster,

  /// Earth's mirror beam, on survival's orb — the ship, here.
  core,

  /// Spirit's second beam, on the ship; it ends if the ship is destroyed.
  ship,
}

/// Who cast a Wing beam, captured when it was cast: a companion (the
/// party's, or the wild Alchemon on its own side) or a home-planet defender.
class _WingCaster {
  _WingCaster.companion(CosmicCompanion this.companion) : garrison = null;
  _WingCaster.garrison(_GarrisonCreature this.garrison) : companion = null;

  final CosmicCompanion? companion;
  final _GarrisonCreature? garrison;

  CosmicPartyMember get member => companion?.member ?? garrison!.member;
  Offset get position => companion?.position ?? garrison!.position;

  /// Survival reads these through `_effectiveBeauty/_effectiveIntelligence`
  /// (its power-ups on top, floored at 0.5); open space has no power-ups.
  double get beauty => max(0.5, member.statBeauty.toDouble());
  double get intelligence => max(0.5, member.statIntelligence.toDouble());

  bool identifies(Object who) =>
      identical(who, companion) || identical(who, garrison);

  /// Whether [other] was cast by the same creature, however many casts apart.
  bool sameAs(_WingCaster other) =>
      identical(other.companion ?? other.garrison, companion ?? garrison);

  int get killStacks =>
      companion?.abilityKillStacks ?? garrison!.abilityKillStacks;

  void addKillStack() {
    final c = companion;
    if (c != null) {
      c.abilityKillStacks++;
    } else {
      garrison!.abilityKillStacks++;
    }
  }

  void heal(int hp) {
    final c = companion;
    if (c != null) {
      c.currentHp = min(c.maxHp, c.currentHp + hp);
    } else {
      final g = garrison!;
      g.hp = min(g.maxHp, g.hp + hp);
    }
  }

  /// Survival's buff: the basic attack hastes to [multiplier] for at least
  /// [duration].
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
}

class _ActiveWingBeam {
  _ActiveWingBeam({
    required this.descriptor,
    required this.caster,
    required this.origin,
    required this.angle,
    this.anchor = _WingAnchor.caster,
    this.refractedFrom,
    this.huntTarget,
  }) : life = anchor == _WingAnchor.caster
           ? descriptor.duration
           : WingBeamRules.coBeamLife(descriptor),
       tickTimer = descriptor.tickInterval,
       chargeTimer = descriptor.chargeTime,
       // A refraction never refracts again.
       refractionsDone = refractedFrom != null ? 1 : 0;

  final WingBeamEffect descriptor;
  final _WingCaster caster;
  final _WingAnchor anchor;
  Offset origin;
  double angle;
  double life;
  double tickTimer;
  double chargeTimer;
  int refractionsDone;

  /// Steam executes the first body it touches, once.
  bool steamKillUsed = false;

  /// Where the beam landed on its last update, for the render pass to paint
  /// it from (null until it has fired). Visual only.
  Offset? drawEnd;

  /// Light: the beam this one refracted out of, or null for a beam the Wing
  /// cast. A refraction hunts a body of its own ([huntTarget]) rather than
  /// the nearest one, which is the body its parent is already on.
  final _ActiveWingBeam? refractedFrom;
  CosmicEnemy? huntTarget;

  /// The body this beam aimed at on its last update.
  CosmicEnemy? aimedAt;

  /// Water: the ally (or the ship) its beam was on at its last update.
  Object? aimedAlly;

  /// Where the body (or boss) it is aimed at stood on its last update, for
  /// the art: a sweeping beam runs on past it, and its heat pools there.
  Offset? focusAt;

  /// Focus: how long the beam has been held on [aimedAt], and so how hot its
  /// tick there is (WingBeamRules.heatAt). Survival's rule.
  final WingBeamHeat heat = WingBeamHeat();

  bool get dead => life <= 0;
  bool get isRefraction => refractedFrom != null;

  /// Earth's and Spirit's second beams, fired from the ship.
  bool get isCoBeam => anchor != _WingAnchor.caster;
}

/// A flower a Wing+Plant beam kill leaves, waiting for the ship.
class _WingFlower {
  _WingFlower({
    required this.position,
    required this.caster,
    required this.bobPhase,
  });

  Offset position;
  double life = WingBeamRules.flowerLife;
  final _WingCaster caster;
  final double bobPhase;

  bool get dead => life <= 0;
}

/// What a test may read of a live Wing beam.
typedef WingBeamView = ({
  String element,
  WingBeamTargetPolicy policy,
  Offset origin,
  String anchor,
  bool charging,
  double life,
  double damagePerTick,
  double width,
  CosmicCompanion? caster,
  Offset? end,
  Object? heldOn,
  Offset? focus,
  double heat,
});

extension CosmicWing on CosmicGame {
  // ── casting ─────────────────────────────────────────────────────────────

  /// Opens a cast's beams. Earth's orb co-fires a mirror beam (from the
  /// ship, here); Spirit tethers to the ship, which fires one of its own.
  void _activateWingBeamEffects(
    List<WingBeamEffect> beams, {
    required _WingCaster caster,
    required double angle,
  }) {
    if (beams.isEmpty) return;
    // The cast's one sound, sized to how long the beam will hold.
    onSound?.call(
      SoundCue.forWingBeam(beams.first.element, beams.first.duration),
    );
    for (final d in beams) {
      final own = _ActiveWingBeam(
        descriptor: d,
        caster: caster,
        origin: caster.position,
        angle: angle,
      );
      if (!_addWingBeam(own)) continue;
      if (d.element == 'Earth') {
        _addWingBeam(
          _ActiveWingBeam(
            descriptor: d,
            caster: caster,
            origin: ship.pos,
            angle: angle,
            anchor: _WingAnchor.core,
          ),
          keep: own,
        );
      }
      if (d.element == 'Spirit' && !_shipDead) {
        _addWingBeam(
          _ActiveWingBeam(
            descriptor: d,
            caster: caster,
            origin: ship.pos,
            angle: angle,
            anchor: _WingAnchor.ship,
          ),
          keep: own,
        );
      }
    }
  }

  /// Survival's `_addWingBeam`: adds [beam] under the cap, making room by
  /// giving up its caster's own oldest beam, never another Wing's, never a
  /// co-fired one and never [keep], the beam this one belongs with. The cap
  /// used to drop whatever was first in the list, so a Light Wing splitting
  /// on its kills pushed every other Wing's beam off the field (2026-10-20
  /// audit). When the caster has nothing of its own to give up, the new beam
  /// is the one that does not fire.
  bool _addWingBeam(_ActiveWingBeam beam, {_ActiveWingBeam? keep}) {
    if (_activeWingBeams.length >= WingBeamRules.beamCap) {
      var evict = -1;
      for (var i = 0; i < _activeWingBeams.length; i++) {
        final b = _activeWingBeams[i];
        if (!b.caster.sameAs(beam.caster) ||
            b.isCoBeam ||
            identical(b, keep)) {
          continue;
        }
        evict = i;
        break;
      }
      if (evict < 0) return false;
      _activeWingBeams.removeAt(evict);
    }
    _activeWingBeams.add(beam);
    return true;
  }

  /// The caster is still in the fight: a companion still out and standing,
  /// a defender still standing at its post.
  bool _wingCasterLive(_WingCaster caster) {
    final c = caster.companion;
    if (c != null) {
      if (!c.isAlive) return false;
      for (final active in activeCompanions.values) {
        if (identical(active, c)) return true;
      }
      return false;
    }
    final g = caster.garrison!;
    return g.hp > 0 && _garrison.contains(g);
  }

  /// Held where it stands by a beam of its own still charging (Lightning's
  /// three seconds), so the blast fires from where the wing committed. Either
  /// side's beams: the wild Alchemon's live on its side between turns.
  bool _heldByWingCharge(Object who) {
    for (final beam in _activeWingBeams) {
      if (beam.chargeTimer > 0 && beam.caster.identifies(who)) return true;
    }
    for (final beam in _wildSide.wingBeams) {
      if (beam.chargeTimer > 0 && beam.caster.identifies(who)) return true;
    }
    return false;
  }

  // ── each frame ──────────────────────────────────────────────────────────

  /// Ages the segments and trap visuals every beam and trap draws. Once a
  /// frame, whichever side laid them.
  void _ageBeamFx(double dt) {
    _maskTrapVisuals.update(dt);
    for (final fx in _beamFx) {
      fx.update(dt);
    }
    _beamFx.removeWhere((fx) => fx.dead);
  }

  void _wingSegment(
    Offset start,
    Offset end,
    Color color,
    double width,
    double life,
    String? wingElement,
  ) => _spawnBeamFx(
    start,
    end,
    color,
    width: width,
    life: life,
    wingElement: wingElement,
  );

  /// Survival's `_updateBeamEffects`, beam for beam.
  void _updateOpenWingBeams(double dt) {
    for (final beam in _activeWingBeams) {
      final d = beam.descriptor;
      beam.life -= dt;
      switch (beam.anchor) {
        case _WingAnchor.caster:
          if (_wingCasterLive(beam.caster)) beam.origin = beam.caster.position;
        case _WingAnchor.core:
          beam.origin = ship.pos;
        case _WingAnchor.ship:
          // The tether is to the ship, not to where the ship used to be.
          if (!_shipDead) {
            beam.origin = ship.pos;
          } else {
            beam.life = 0;
          }
      }
      // Face the current target, so a charge and the line both track it.
      Offset? endNow;
      if (d.targetPolicy != WingBeamTargetPolicy.ring) {
        endNow = _wingBeamEndpoint(beam);
        final dir = endNow - beam.origin;
        if (dir.distanceSquared > 0.5) beam.angle = atan2(dir.dy, dir.dx);
      }
      if (beam.chargeTimer > 0) {
        final wasCharging = beam.chargeTimer;
        beam.chargeTimer = max(0.0, beam.chargeTimer - dt);
        final progress = d.chargeTime > 0
            ? 1.0 - (beam.chargeTimer / d.chargeTime)
            : 1.0;
        emitWingChargeVisual(
          descriptor: d,
          center: beam.origin,
          progress: progress,
          particleRoom: _abilityVfx.length < kWingChargeParticleBudget,
          rng: _rng,
          emit: _abilityVfx.add,
          segment: _wingSegment,
        );
        // Charged: one blast along the line, and the beam is spent.
        if (wasCharging > 0 &&
            beam.chargeTimer <= 0 &&
            d.element == 'Lightning') {
          _resolveWingLightningBlast(beam, _wingBeamEndpoint(beam));
          beam.life = 0;
        }
        continue;
      }

      final end = endNow ?? _wingBeamEndpoint(beam);
      // The render pass paints the beam once a frame from here (see
      // _renderOpenWingBeams), as survival does; nothing goes into _beamFx.
      // Its sparks burst where it is held, not where a sweep runs out.
      beam.drawEnd = end;
      if (_abilityVfx.length < kWingBeamParticleBudget) {
        emitWingBeamParticles(
          descriptor: d,
          origin: beam.origin,
          end: beam.focusAt ?? end,
          tetherTo: ship.pos,
          beamLife: beam.life,
          rng: _rng,
          emit: _abilityVfx.add,
          heat: WingBeamRules.heatGlow(beam.heat.current),
        );
      }

      beam.tickTimer -= dt;
      if (beam.tickTimer > 0) continue;
      beam.tickTimer += d.tickInterval;
      _resolveWingBeamTick(beam, end);
    }
    if (_pendingWingBeams.isNotEmpty) {
      for (final beam in _pendingWingBeams) {
        _addWingBeam(beam, keep: beam.refractedFrom);
      }
      _pendingWingBeams.clear();
    }
    _activeWingBeams.removeWhere((beam) => beam.dead);
  }

  /// Where a beam lands this frame. Water finds the most hurt ally (the ship
  /// first), never an enemy; Blood the most hurt enemy; the rest the
  /// nearest; then a boss in range; else straight on at full range. A beam
  /// aimed at the nearest body runs on through it to full range (survival's
  /// sweep).
  Offset _wingBeamEndpoint(_ActiveWingBeam beam) {
    final d = beam.descriptor;
    final fallback =
        beam.origin + Offset(cos(beam.angle), sin(beam.angle)) * d.range;
    if (d.targetPolicy == WingBeamTargetPolicy.lowestHealthAllyOrShip) {
      Offset? bestPos;
      Object? best;
      var bestFraction = double.infinity;
      if (!_shipDead && CosmicGame.shipMaxHealth > 0) {
        if ((ship.pos - beam.origin).distance <= d.range) {
          final f = shipHealth / CosmicGame.shipMaxHealth;
          if (f < bestFraction) {
            bestFraction = f;
            bestPos = ship.pos;
            best = ship;
          }
        }
      }
      for (final c in activeCompanions.values) {
        if (!c.isAlive || c.maxHp <= 0) continue;
        if (beam.caster.identifies(c)) continue;
        if ((c.position - beam.origin).distance > d.range) continue;
        final f = c.currentHp / c.maxHp;
        if (f < bestFraction) {
          bestFraction = f;
          bestPos = c.position;
          best = c;
        }
      }
      beam.aimedAlly = best;
      return bestPos ?? fallback;
    }
    CosmicEnemy? target;
    if (beam.isRefraction) {
      target = _wingRefractionTarget(beam);
    } else if (d.targetPolicy == WingBeamTargetPolicy.lowestHealthEnemy) {
      for (final enemy in enemies) {
        if (enemy.dead) continue;
        if ((enemy.position - beam.origin).distance > d.range) continue;
        if (target == null ||
            enemy.health / enemy.maxHealth < target.health / target.maxHealth) {
          target = enemy;
        }
      }
    } else {
      target = _nearestOpenEnemy(beam.origin, d.range);
    }
    beam.aimedAt = target;
    var aim = target?.position;
    final boss = activeBoss;
    if (aim == null &&
        boss != null &&
        !boss.dead &&
        (boss.position - beam.origin).distance <= d.range) {
      aim = boss.position;
    }
    beam.focusAt = aim;
    if (aim == null) return fallback;
    if (WingBeamRules.sweeps(d) || beam.anchor == _WingAnchor.ship) {
      return WingBeamRules.sweepEnd(beam.origin, aim, d.range, beam.angle);
    }
    return aim;
  }

  /// A zone a beam leaves, under survival's ceiling on companion projectiles.
  void _appendWingZone(Projectile zone) {
    if (companionProjectiles.length >= 220) return;
    companionProjectiles.add(zone);
  }

  /// Survival's `_resolveBeamTick`: one tick of a live beam ending at [end].
  void _resolveWingBeamTick(_ActiveWingBeam beam, Offset end) {
    final d = beam.descriptor;
    final caster = beam.caster;
    // Focus, survival's rule: the body the beam is held on takes the beam's
    // heat, every other body on the line the unheated tick. The rings and
    // Lightning's blast have no heat. Water heats on the ally it is held on,
    // and every body it crosses takes that heat.
    final heats = WingBeamRules.heats(d);
    final onAlly = d.targetPolicy == WingBeamTargetPolicy.lowestHealthAllyOrShip;
    final focus = heats && !onAlly ? beam.aimedAt : null;
    final heat = heats
        ? beam.heat.tick(onAlly ? beam.aimedAlly : focus, d.tickInterval)
        : 1.0;
    final lineShare = !heats
        ? 1.0
        : onAlly
        ? heat
        : WingBeamRules.lineShare;
    // Lava carves a glowing scar where it is held every tick.
    if (d.element == 'Lava') {
      _appendWingZone(
        WingBeamRules.lavaScar(
          d,
          beam.focusAt ?? end,
          beauty: caster.beauty,
          intelligence: caster.intelligence,
          sourceSlotIndex: caster.member.slotIndex,
        ),
      );
    }
    if (d.healPerTick > 0) {
      // Water's heal is its own; Crystal's and Light's are the beam's damage
      // coming back, at its heat.
      final heal = d.targetPolicy == WingBeamTargetPolicy.lowestHealthAllyOrShip
          ? d.healPerTick
          : d.healPerTick * heat;
      if (!_shipDead) {
        shipHealth = min(CosmicGame.shipMaxHealth, shipHealth + heal);
      }
      // Survival's orb share (WingBeamRules.orbHealShare) has no open-space
      // objective beyond the ship, which has just taken the full heal. A
      // battle has no orb either: the caster keeps only a share.
      if (_wingCasterLive(caster)) {
        caster.heal((heal * _wingBeamSelfHealShare).round());
      }
    }

    if (d.targetPolicy == WingBeamTargetPolicy.ring && d.radius > 0) {
      final r2 = d.radius * d.radius;
      for (final enemy in enemies) {
        if (enemy.dead) continue;
        if ((enemy.position - beam.origin).distanceSquared >= r2) continue;
        _damageOpenEnemy(
          enemy,
          d.damagePerTick,
          element: d.element,
          sourceSlot: beam.caster.member.slotIndex,
        );
        _applyWingBeamEffect(
          beam,
          d.tickEffect,
          enemy,
          beam.origin,
          d.effectPower,
          d.radius,
          d.effectDuration,
        );
      }
    } else {
      final radius = WingBeamRules.hitRadius(d);
      final riderScales = WingBeamRules.riderScales(d.tickEffect);
      for (final enemy in enemies) {
        if (enemy.dead) continue;
        if (_distanceToSegment(enemy.position, beam.origin, end) >
            enemy.radius + radius) {
          continue;
        }
        // Steam executes the first body it touches and erupts a field of
        // clouds where it stood: the one it is held on, the line running on.
        if (d.element == 'Steam' &&
            !beam.steamKillUsed &&
            (focus == null || identical(enemy, focus))) {
          beam.steamKillUsed = true;
          final killPos = enemy.position;
          _damageOpenEnemy(
            enemy,
            enemy.health + 1,
            element: 'Steam',
            sourceSlot: beam.caster.member.slotIndex,
          );
          for (final cloud in WingBeamRules.steamClouds(
            d,
            killPos,
            _rng,
            beauty: caster.beauty,
            intelligence: caster.intelligence,
            sourceSlotIndex: caster.member.slotIndex,
          )) {
            _appendWingZone(cloud);
          }
          continue;
        }
        final wasDead = enemy.dead;
        final share = identical(enemy, focus) ? heat : lineShare;
        // The flowers it has collected grow a Plant wing's beam — while the
        // wing is still out, as survival reads it off the live companion.
        final plantBonus =
            d.element == 'Plant' &&
                _isWingPlant(caster.member) &&
                _wingCasterLive(caster)
            ? WingBeamRules.plantStackBonus(caster.killStacks, caster.beauty)
            : 1.0;
        _damageOpenEnemy(
          enemy,
          WingBeamRules.tickDamage(
                d,
                hp: enemy.health,
                hpFraction: enemy.health / enemy.maxHealth,
                heat: share,
              ) *
              plantBonus,
          element: d.element,
          sourceSlot: beam.caster.member.slotIndex,
        );
        _applyWingBeamEffect(
          beam,
          d.tickEffect,
          enemy,
          beam.origin,
          riderScales ? d.effectPower * share : d.effectPower,
          WingBeamRules.lineEffectRadius(d),
          d.effectDuration,
        );
        // Ice ramps a frost that snaps into a hard freeze once full. It
        // holds while the beam is on the body and thaws once it moves off.
        if (d.element == 'Ice' && !enemy.dead) {
          enemy.frostGrace = WingBeamRules.frostGrace(d);
          enemy.frostBuildup = min(
            1.0,
            enemy.frostBuildup + WingBeamRules.frostPerTick,
          );
          if (enemy.frostBuildup >= 1.0) {
            enemy.frostBuildup = 0;
            enemy.applySlow(WingBeamRules.freezeSlow, WingBeamRules.freezeHold);
            enemy.knockbackVelocity = Offset.zero;
            _spawnHitSpark(enemy.position, elementColor('Ice'));
          }
        }
        // A Light kill refracts the beam into smaller hunting beams.
        if (!wasDead && enemy.dead && d.element == 'Light') {
          _spawnWingLightSplit(beam, enemy.position);
        }
        // A Plant kill leaves a flower for the ship to collect.
        if (!wasDead && enemy.dead && d.element == 'Plant') {
          _spawnWingFlower(enemy.position, caster);
        }
      }
    }

    // A boss takes the authored tick wherever the line crosses it, as in
    // survival. Open space's bosses have no crowd control to chill with.
    final boss = activeBoss;
    if (boss != null && !boss.dead) {
      final hitsBoss = d.targetPolicy == WingBeamTargetPolicy.ring
          ? (boss.position - beam.origin).distanceSquared <
                (d.radius + boss.radius) * (d.radius + boss.radius)
          : _distanceToSegment(boss.position, beam.origin, end) <=
                boss.radius + WingBeamRules.hitRadius(d);
      if (hitsBoss) _damageOpenBoss(d.damagePerTick, element: d.element);
    }
  }

  bool _isWingPlant(CosmicPartyMember member) =>
      member.family.toLowerCase() == 'wing' && member.element == 'Plant';

  /// Survival's `_applyAbilityEffectToEnemy`, for the riders a beam carries.
  void _applyWingBeamEffect(
    _ActiveWingBeam beam,
    AbilityEffectKind effect,
    CosmicEnemy enemy,
    Offset origin,
    double power,
    double radius,
    double duration,
  ) {
    if (effect == AbilityEffectKind.none) return;
    // A kill effect arrives with its target already dead; only the riders
    // that act on the body itself need it standing.
    if (enemy.dead && !CosmicAbilityRuntime.resolvesOnDeadTarget(effect)) {
      return;
    }
    final effectPower = power > 0 ? power : 4.0;
    final effectDuration = duration > 0 ? duration : 1.5;
    final caster = beam.caster;
    switch (effect) {
      case AbilityEffectKind.knockback:
        _knockOpenEnemy(
          enemy,
          enemy.position - origin,
          CosmicAbilityRuntime.knockbackImpulse(effectPower),
        );
      case AbilityEffectKind.slow:
      case AbilityEffectKind.freeze:
      case AbilityEffectKind.root:
      case AbilityEffectKind.stun:
        _crowdControlOpenEnemy(enemy, effect, effectDuration);
        if (effect == AbilityEffectKind.root) {
          _damageOpenEnemy(
            enemy,
            effectPower,
            sourceSlot: beam.caster.member.slotIndex,
          );
        }
      case AbilityEffectKind.suppressShooting:
        // Dust disorients a body's shots onto its own side. Open space's
        // roaming bodies never shoot, so there is nothing for it to turn.
        break;
      case AbilityEffectKind.burn:
      case AbilityEffectKind.poison:
      case AbilityEffectKind.zoneDamage:
        _damageOpenEnemy(
          enemy,
          effectPower,
          sourceSlot: beam.caster.member.slotIndex,
        );
      case AbilityEffectKind.geyser:
        _damageOpenEnemy(
          enemy,
          effectPower,
          sourceSlot: beam.caster.member.slotIndex,
        );
        // Away from the wing that casts the beam.
        enemy.knockbackVelocity += CosmicAbilityRuntime.geyserKnockbackFrom(
          origin,
          enemy.position,
        );
      case AbilityEffectKind.execute:
      case AbilityEffectKind.refraction:
      case AbilityEffectKind.chargeBlast:
        _damageOpenEnemy(
          enemy,
          CosmicAbilityRuntime.directDamageForEffect(
            effect,
            power: effectPower,
            targetHp: enemy.health,
            targetHpFraction: enemy.health / enemy.maxHealth,
          ),
          sourceSlot: beam.caster.member.slotIndex,
        );
      case AbilityEffectKind.leech:
      case AbilityEffectKind.zoneHeal:
        // The objective's share (the ship, standing in for the orb), and the
        // caster's whole — the ship's instead if the caster is gone.
        _feedWingObjective(
          _healCeiling.grant(
            slot: beam.caster.member.slotIndex,
            amount: effectPower * CosmicAbilityRuntime.leechObjectiveShare,
            pool: CosmicGame.shipMaxHealth,
            beauty: beam.caster.member.statBeauty,
            now: _elapsed,
          ),
        );
        if (_wingCasterLive(caster)) {
          caster.heal((effectPower * _wingBeamSelfHealShare).round());
        } else if (!_shipDead) {
          shipHealth = min(CosmicGame.shipMaxHealth, shipHealth + effectPower);
        }
      case AbilityEffectKind.buff:
        if (_wingCasterLive(caster)) {
          caster.haste(
            effectDuration,
            CosmicAbilityRuntime.buffHasteMultiplier,
          );
        }
      case AbilityEffectKind.alchemyBonus:
        _feedWingObjective(
          effectPower * CosmicAbilityRuntime.flowerObjectiveShare,
        );
      case AbilityEffectKind.flower:
        // Survival's rule: a Plant beam's flowers are its reward, not a
        // heal on every tick.
        break;
      default:
        _applyOpenWingEffect(effect, enemy, origin, power, radius, duration);
    }
  }

  /// Survival's `_healOrb`; the ship is open space's objective.
  /// What of a beam's heal the caster keeps for itself: all of it in open
  /// space, [kBattleBeamSelfHealShare] in a battle, where the heal meant for
  /// the orb otherwise made a Crystal Wing outlast anything (the harness,
  /// 2026-10-20: 92% of its fights).
  double get _wingBeamSelfHealShare =>
      _battle == null ? 1.0 : kBattleBeamSelfHealShare;

  void _feedWingObjective(double amount) {
    if (amount <= 0 || _shipDead) return;
    shipHealth = min(CosmicGame.shipMaxHealth, shipHealth + amount);
  }

  /// Survival's `_resolveLightningBlast`: one massive hit along the line,
  /// the charged rider on whatever lives through it.
  void _resolveWingLightningBlast(_ActiveWingBeam beam, Offset end) {
    final d = beam.descriptor;
    // The element accent, moved here from the cast: it is the blast.
    onSound?.call(SoundCue.elementLightning);
    emitWingLightningBlastFlash(
      descriptor: d,
      origin: beam.origin,
      end: end,
      segment: _wingSegment,
    );
    final radius = WingBeamRules.blastRadius(d);
    final blastDamage = d.damagePerTick * WingBeamRules.blastDamageScale;
    for (final enemy in enemies) {
      if (enemy.dead) continue;
      if (_distanceToSegment(enemy.position, beam.origin, end) >
          enemy.radius + radius) {
        continue;
      }
      _damageOpenEnemy(
        enemy,
        blastDamage,
        element: 'Lightning',
        sourceSlot: beam.caster.member.slotIndex,
      );
      _applyWingBeamEffect(
        beam,
        d.tickEffect,
        enemy,
        beam.origin,
        d.effectPower * WingBeamRules.blastEffectScale,
        radius * 6,
        d.effectDuration,
      );
    }
    final boss = activeBoss;
    if (boss != null &&
        !boss.dead &&
        _distanceToSegment(boss.position, beam.origin, end) <=
            boss.radius + radius) {
      _damageOpenBoss(blastDamage, element: 'Lightning');
    }
    _spawnHitSpark(end, elementColor('Lightning'));
  }

  /// Survival's `_spawnLightSplitBeams`. A beam refracts once: the parent is
  /// marked as well as its children. Only the children used to be, so a
  /// parent split again on every kill it made (2026-10-20 audit). And the
  /// children used to re-aim every frame at the nearest body, which is the
  /// body the parent was already on; the board says they target nearby
  /// enemies, so each one hunts a body of its own near [killedAt].
  void _spawnWingLightSplit(_ActiveWingBeam parent, Offset killedAt) {
    if (parent.refractionsDone > 0 || parent.isRefraction) return;
    final remaining = parent.life;
    if (remaining < WingBeamRules.lightSplitMinRemaining) return;
    parent.refractionsDone = 1;
    final beauty = parent.caster.beauty;
    final child = WingBeamRules.lightSplitChild(
      parent.descriptor,
      remaining: remaining,
      beauty: beauty,
    );
    final offsets = WingBeamRules.lightSplitOffsets(beauty);
    // Where the parent goes next, so no child doubles it.
    parent.aimedAt = _nearestOpenEnemy(parent.origin, parent.descriptor.range);
    final prey = _wingRefractionPrey(
      killedAt,
      origin: parent.origin,
      reach: child.range,
      count: offsets.length,
      avoid: parent.aimedAt,
    );
    for (var i = 0; i < offsets.length; i++) {
      final hunted = i < prey.length ? prey[i] : null;
      final dir = hunted == null ? null : hunted.position - parent.origin;
      _pendingWingBeams.add(
        _ActiveWingBeam(
          descriptor: child,
          caster: parent.caster,
          origin: parent.origin,
          angle: dir != null && dir.distanceSquared > 0.5
              ? atan2(dir.dy, dir.dx)
              : parent.angle + offsets[i],
          refractedFrom: parent,
          huntTarget: hunted,
        ),
      );
    }
  }

  /// Survival's `_refractionPrey`: up to [count] distinct living bodies
  /// nearest [from] and within [reach] of [origin], other than [avoid],
  /// nearest first. Open space holds few enough bodies to walk the list.
  List<CosmicEnemy> _wingRefractionPrey(
    Offset from, {
    required Offset origin,
    required double reach,
    required int count,
    CosmicEnemy? avoid,
  }) {
    final picked = <CosmicEnemy>[];
    final distSq = <double>[];
    final reachSq = reach * reach;
    for (final enemy in enemies) {
      if (enemy.dead || identical(enemy, avoid)) continue;
      if ((enemy.position - origin).distanceSquared > reachSq) continue;
      final dSq = (enemy.position - from).distanceSquared;
      if (picked.length == count && dSq >= distSq.last) continue;
      var at = picked.length;
      while (at > 0 && distSq[at - 1] > dSq) {
        at--;
      }
      picked.insert(at, enemy);
      distSq.insert(at, dSq);
      if (picked.length > count) {
        picked.removeLast();
        distSq.removeLast();
      }
    }
    return picked;
  }

  /// Survival's `_refractionTarget`: the body a refraction was given while it
  /// lives and stays in reach, then the nearest to where that one fell that
  /// neither its parent nor a sibling is on. With nothing like that left it
  /// takes the nearest body at all, so it never idles.
  CosmicEnemy? _wingRefractionTarget(_ActiveWingBeam beam) {
    final range = beam.descriptor.range;
    final held = beam.huntTarget;
    if (held != null &&
        !held.dead &&
        (held.position - beam.origin).distance <= range) {
      return held;
    }
    final parent = beam.refractedFrom;
    final from = held?.position ?? beam.origin;
    final rangeSq = range * range;
    CosmicEnemy? best;
    var bestSq = double.infinity;
    for (final enemy in enemies) {
      if (enemy.dead) continue;
      if ((enemy.position - beam.origin).distanceSquared > rangeSq) continue;
      final dSq = (enemy.position - from).distanceSquared;
      if (dSq >= bestSq) continue;
      if (identical(enemy, parent?.aimedAt)) continue;
      var sibling = false;
      for (final other in _activeWingBeams) {
        if (!identical(other, beam) &&
            identical(other.refractedFrom, parent) &&
            identical(other.huntTarget, enemy)) {
          sibling = true;
          break;
        }
      }
      if (sibling) continue;
      bestSq = dSq;
      best = enemy;
    }
    beam.huntTarget = best;
    return best ?? _nearestOpenEnemy(beam.origin, range);
  }

  // ── Plant's flowers ─────────────────────────────────────────────────────

  void _spawnWingFlower(Offset at, _WingCaster caster) {
    if (_wingFlowers.length >= WingBeamRules.flowerCap) return;
    _wingFlowers.add(
      _WingFlower(
        position: at,
        caster: caster,
        bobPhase: _rng.nextDouble() * pi * 2,
      ),
    );
  }

  /// The ship collects flowers it flies near, and pulls in those close by;
  /// each one it collects grows its caster's beam.
  void _updateWingFlowers(double dt) {
    if (_wingFlowers.isEmpty) return;
    if (_shipDead) {
      for (final flower in _wingFlowers) {
        flower.life -= dt;
      }
      _wingFlowers.removeWhere((f) => f.dead);
      return;
    }
    for (final flower in _wingFlowers) {
      flower.life -= dt;
      if (flower.dead) continue;
      final next = WingBeamRules.flowerStep(flower.position, ship.pos, dt);
      if (next == null) {
        flower.life = 0;
        if (_wingCasterLive(flower.caster)) {
          flower.caster.addKillStack();
          _spawnHitSpark(ship.pos, elementColor('Plant'));
        }
        continue;
      }
      flower.position = next;
    }
    _wingFlowers.removeWhere((f) => f.dead);
  }

  // ── drawing ─────────────────────────────────────────────────────────────

  Rect get _wingView =>
      Rect.fromLTWH(camX, camY, size.x / cameraZoom, size.y / cameraZoom);

  static bool _wingInView(Offset p, double radius, Rect view, double margin) =>
      p.dx + radius >= view.left - margin &&
      p.dx - radius <= view.right + margin &&
      p.dy + radius >= view.top - margin &&
      p.dy - radius <= view.bottom + margin;

  /// Every live line beam on both sides, painted once straight from the live
  /// beams (as survival does), then the short-lived pieces in the beam list
  /// (Lightning's blast, a charge's sparks), then the party's Fire and
  /// Poison rings.
  /// [fx] false leaves out the faded segments (one list, whichever side
  /// laid them): a battle draws each side's beams on its own side and the
  /// segments once.
  void _renderOpenWingBeams(Canvas canvas, {bool fx = true}) {
    final view = _wingView;
    for (final beams in [_activeWingBeams, _wildSide.wingBeams]) {
      for (final beam in beams) {
        final end = beam.drawEnd;
        if (beam.dead || beam.chargeTimer > 0 || end == null) continue;
        final fade = wingBeamFade(beam.life);
        // Focus: drawn as hot as it is, its heat pooled where it is held.
        final glow = WingBeamRules.heats(beam.descriptor)
            ? WingBeamRules.heatGlow(beam.heat.current)
            : null;
        emitWingBeamSegments(
          descriptor: beam.descriptor,
          origin: beam.origin,
          end: end,
          tetherTo: ship.pos,
          segment: (start, segEnd, color, width, life, element) {
            final mid = Offset(
              (start.dx + segEnd.dx) * 0.5,
              (start.dy + segEnd.dy) * 0.5,
            );
            final halfLength = (segEnd - start).distance * 0.5;
            if (!_wingInView(mid, halfLength + width * 2, view, 28)) return;
            drawAdvancedAbilityBeam(
              canvas: canvas,
              start: start,
              end: segEnd,
              color: color,
              wingElement: element,
              width: width,
              alpha: fade,
              time: _elapsed,
              heat: glow,
              focus: segEnd == end ? beam.focusAt : null,
            );
          },
        );
      }
    }
    for (final fx in fx ? _beamFx : const <_BeamFx>[]) {
      final alpha = fx.alpha;
      if (alpha <= 0) continue;
      final mid = Offset(
        (fx.start.dx + fx.end.dx) * 0.5,
        (fx.start.dy + fx.end.dy) * 0.5,
      );
      final halfLength = (fx.end - fx.start).distance * 0.5;
      if (!_wingInView(mid, halfLength + fx.width * 2, view, 28)) continue;
      drawAdvancedAbilityBeam(
        canvas: canvas,
        start: fx.start,
        end: fx.end,
        color: fx.color,
        wingElement: fx.wingElement,
        width: fx.width,
        alpha: alpha,
        time: _elapsed,
      );
    }
    _renderWingRings(canvas, _activeWingBeams, view);
  }

  /// Ring beams as a churning perimeter, full strength until their last
  /// 0.45 s.
  void _renderWingRings(Canvas canvas, List<_ActiveWingBeam> beams, Rect view) {
    for (final beam in beams) {
      final d = beam.descriptor;
      if (d.targetPolicy != WingBeamTargetPolicy.ring || d.radius <= 0) {
        continue;
      }
      if (!_wingInView(beam.origin, d.radius + kWingRingCullPad, view, 32)) {
        continue;
      }
      drawAdvancedWingBeamRing(
        canvas: canvas,
        center: beam.origin,
        radius: d.radius,
        width: d.width,
        color: elementColor(d.element),
        element: d.element,
        alpha: wingRingFade(beam.life),
        time: _elapsed,
      );
    }
  }

  void _renderWingFlowers(Canvas canvas) {
    if (_wingFlowers.isEmpty) return;
    final view = _wingView;
    for (final flower in _wingFlowers) {
      if (!_wingInView(flower.position, 24, view, 28)) continue;
      drawWingFlowerPickup(
        canvas: canvas,
        position: flower.position,
        life: flower.life,
        bobPhase: flower.bobPhase,
        time: _elapsed,
      );
    }
  }

  // ── for tests ───────────────────────────────────────────────────────────

  /// The live Wing beams on the party's side, or the wild Alchemon's.
  @visibleForTesting
  List<WingBeamView> debugWingBeams({bool wildSide = false}) => [
    for (final b in wildSide ? _wildSide.wingBeams : _activeWingBeams)
      (
        element: b.descriptor.element,
        policy: b.descriptor.targetPolicy,
        origin: b.origin,
        anchor: b.anchor.name,
        charging: b.chargeTimer > 0,
        life: b.life,
        damagePerTick: b.descriptor.damagePerTick,
        width: b.descriptor.width,
        caster: b.caster.companion,
        end: b.drawEnd,
        heldOn: b.heat.on,
        focus: b.focusAt,
        heat: b.heat.current,
      ),
  ];

  /// Opens [beam] for [caster] the way its special does, so a test can hold
  /// one beam of known numbers.
  @visibleForTesting
  void debugCastWingBeam(CosmicCompanion caster, WingBeamEffect beam) =>
      _activateWingBeamEffects(
        [beam],
        caster: _WingCaster.companion(caster),
        angle: 0,
      );

  /// Where the Plant flowers waiting for the ship lie.
  @visibleForTesting
  List<Offset> get debugWingFlowers => [
    for (final f in _wingFlowers) f.position,
  ];

  /// The beam pieces the render pass paints this frame: each live beam's
  /// pieces, once (as [_renderOpenWingBeams] gets them from
  /// [emitWingBeamSegments]), then the short-lived pieces in the beam list.
  @visibleForTesting
  List<({Offset start, Offset end, String? wingElement, double width})>
  get debugBeamFx {
    final out =
        <({Offset start, Offset end, String? wingElement, double width})>[];
    for (final beams in [_activeWingBeams, _wildSide.wingBeams]) {
      for (final beam in beams) {
        final end = beam.drawEnd;
        if (beam.dead || beam.chargeTimer > 0 || end == null) continue;
        emitWingBeamSegments(
          descriptor: beam.descriptor,
          origin: beam.origin,
          end: end,
          tetherTo: ship.pos,
          segment: (start, segEnd, color, width, life, element) => out.add((
            start: start,
            end: segEnd,
            wingElement: element,
            width: width,
          )),
        );
      }
    }
    for (final fx in _beamFx) {
      out.add((
        start: fx.start,
        end: fx.end,
        wingElement: fx.wingElement,
        width: fx.width,
      ));
    }
    return out;
  }

  /// Entries in the beam list itself (short-lived pieces only: a live beam
  /// no longer lays a copy of itself there every frame).
  @visibleForTesting
  int get debugBeamListLength => _beamFx.length;

  /// Particles in the shared ability pool.
  @visibleForTesting
  int get debugAbilityVfxCount => _abilityVfx.length;
}
