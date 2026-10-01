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
  }) : life = descriptor.duration,
       tickTimer = descriptor.tickInterval,
       chargeTimer = descriptor.chargeTime;

  final WingBeamEffect descriptor;
  final _WingCaster caster;
  final _WingAnchor anchor;
  Offset origin;
  double angle;
  double life;
  double tickTimer;
  double chargeTimer;
  int refractionsDone = 0;

  /// Steam executes the first body it touches, once.
  bool steamKillUsed = false;

  bool get dead => life <= 0;
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
    for (final d in beams) {
      _addWingBeam(
        _ActiveWingBeam(
          descriptor: d,
          caster: caster,
          origin: caster.position,
          angle: angle,
        ),
      );
      if (d.element == 'Earth') {
        _addWingBeam(
          _ActiveWingBeam(
            descriptor: d,
            caster: caster,
            origin: ship.pos,
            angle: angle,
            anchor: _WingAnchor.core,
          ),
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
        );
      }
    }
  }

  void _addWingBeam(_ActiveWingBeam beam) {
    if (_activeWingBeams.length >= WingBeamRules.beamCap) {
      _activeWingBeams.removeAt(0);
    }
    _activeWingBeams.add(beam);
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
      if (d.targetPolicy != WingBeamTargetPolicy.ring) {
        final endNow = _wingBeamEndpoint(beam);
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

      final end = _wingBeamEndpoint(beam);
      emitWingBeamSegments(
        descriptor: d,
        origin: beam.origin,
        end: end,
        tetherTo: ship.pos,
        segment: _wingSegment,
      );
      if (_abilityVfx.length < kWingBeamParticleBudget) {
        emitWingBeamParticles(
          descriptor: d,
          origin: beam.origin,
          end: end,
          tetherTo: ship.pos,
          beamLife: beam.life,
          rng: _rng,
          emit: _abilityVfx.add,
        );
      }

      beam.tickTimer -= dt;
      if (beam.tickTimer > 0) continue;
      beam.tickTimer += d.tickInterval;
      _resolveWingBeamTick(beam, end);
    }
    if (_pendingWingBeams.isNotEmpty) {
      for (final beam in _pendingWingBeams) {
        _addWingBeam(beam);
      }
      _pendingWingBeams.clear();
    }
    _activeWingBeams.removeWhere((beam) => beam.dead);
  }

  /// Where a beam lands this frame. Water finds the most hurt ally (the ship
  /// first), never an enemy; Blood the most hurt enemy; the rest the
  /// nearest; then a boss in range; else straight on at full range.
  Offset _wingBeamEndpoint(_ActiveWingBeam beam) {
    final d = beam.descriptor;
    final fallback =
        beam.origin + Offset(cos(beam.angle), sin(beam.angle)) * d.range;
    if (d.targetPolicy == WingBeamTargetPolicy.lowestHealthAllyOrShip) {
      Offset? bestPos;
      var bestFraction = double.infinity;
      if (!_shipDead && CosmicGame.shipMaxHealth > 0) {
        if ((ship.pos - beam.origin).distance <= d.range) {
          final f = shipHealth / CosmicGame.shipMaxHealth;
          if (f < bestFraction) {
            bestFraction = f;
            bestPos = ship.pos;
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
        }
      }
      return bestPos ?? fallback;
    }
    CosmicEnemy? target;
    if (d.targetPolicy == WingBeamTargetPolicy.lowestHealthEnemy) {
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
    if (target != null) return target.position;
    final boss = activeBoss;
    if (boss != null &&
        !boss.dead &&
        (boss.position - beam.origin).distance <= d.range) {
      return boss.position;
    }
    return fallback;
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
    // Lava carves a glowing scar at its tip every tick.
    if (d.element == 'Lava') {
      _appendWingZone(
        WingBeamRules.lavaScar(
          d,
          end,
          beauty: caster.beauty,
          intelligence: caster.intelligence,
          sourceSlotIndex: caster.member.slotIndex,
        ),
      );
    }
    if (d.healPerTick > 0) {
      if (!_shipDead) {
        shipHealth = min(CosmicGame.shipMaxHealth, shipHealth + d.healPerTick);
      }
      // Survival's orb share (WingBeamRules.orbHealShare) has no open-space
      // objective beyond the ship, which has just taken the full heal.
      if (_wingCasterLive(caster)) caster.heal(d.healPerTick.round());
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
      for (final enemy in enemies) {
        if (enemy.dead) continue;
        if (_distanceToSegment(enemy.position, beam.origin, end) >
            enemy.radius + radius) {
          continue;
        }
        // Steam executes the first body it touches and erupts a field of
        // clouds where it stood.
        if (d.element == 'Steam' && !beam.steamKillUsed) {
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
          d.effectPower,
          WingBeamRules.lineEffectRadius(d),
          d.effectDuration,
        );
        // Ice ramps a frost that snaps into a hard freeze once full.
        if (d.element == 'Ice' && !enemy.dead) {
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
          _spawnWingLightSplit(beam);
        }
        // A Plant kill leaves a flower for the ship to collect.
        if (!wasDead && enemy.dead && d.element == 'Plant') {
          _spawnWingFlower(enemy.position, caster);
        }
      }
    }

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
        enemy.knockbackVelocity += CosmicAbilityRuntime.geyserKnockback;
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
          effectPower * CosmicAbilityRuntime.leechObjectiveShare,
        );
        if (_wingCasterLive(caster)) {
          caster.heal(effectPower.round());
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
      case AbilityEffectKind.flower:
      case AbilityEffectKind.alchemyBonus:
        _feedWingObjective(
          effectPower * CosmicAbilityRuntime.flowerObjectiveShare,
        );
      default:
        _applyOpenWingEffect(effect, enemy, origin, power, radius, duration);
    }
  }

  /// Survival's `_healOrb`; the ship is open space's objective.
  void _feedWingObjective(double amount) {
    if (amount <= 0 || _shipDead) return;
    shipHealth = min(CosmicGame.shipMaxHealth, shipHealth + amount);
  }

  /// Survival's `_resolveLightningBlast`: one massive hit along the line,
  /// the charged rider on whatever lives through it.
  void _resolveWingLightningBlast(_ActiveWingBeam beam, Offset end) {
    final d = beam.descriptor;
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

  /// Survival's `_spawnLightSplitBeams`. Only a child is marked refracted, so
  /// a parent may refract on each kill it makes, as in survival.
  void _spawnWingLightSplit(_ActiveWingBeam parent) {
    if (parent.refractionsDone > 0) return;
    final remaining = parent.life;
    if (remaining < WingBeamRules.lightSplitMinRemaining) return;
    final beauty = parent.caster.beauty;
    final child = WingBeamRules.lightSplitChild(
      parent.descriptor,
      remaining: remaining,
      beauty: beauty,
    );
    for (final offset in WingBeamRules.lightSplitOffsets(beauty)) {
      _pendingWingBeams.add(
        _ActiveWingBeam(
          descriptor: child,
          caster: parent.caster,
          origin: parent.origin,
          angle: parent.angle + offset,
        )..refractionsDone = 1,
      );
    }
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

  /// Every beam segment laid this frame (both sides lay into one list), then
  /// the party's Fire and Poison rings.
  void _renderOpenWingBeams(Canvas canvas) {
    final view = _wingView;
    for (final fx in _beamFx) {
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
        alpha: fx.alpha,
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
      ),
  ];

  /// Where the Plant flowers waiting for the ship lie.
  @visibleForTesting
  List<Offset> get debugWingFlowers => [
    for (final f in _wingFlowers) f.position,
  ];

  /// The beam segments laid for drawing this frame: (element, width).
  @visibleForTesting
  List<({Offset start, Offset end, String? wingElement, double width})>
  get debugBeamFx => [
    for (final fx in _beamFx)
      (
        start: fx.start,
        end: fx.end,
        wingElement: fx.wingElement,
        width: fx.width,
      ),
  ];

  /// Particles in the shared ability pool.
  @visibleForTesting
  int get debugAbilityVfxCount => _abilityVfx.length;
}
