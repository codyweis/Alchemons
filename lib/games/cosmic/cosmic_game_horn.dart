part of 'cosmic_game.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  HORN IN OPEN SPACE: Cosmic Survival's Horn specials, run the same way
//
//  A Horn's special owns its body for a while: it winds up (Dark's void,
//  Crystal's orbit, Spirit's phantoms), rams (straight, round Water's
//  circle, or sideways painting Ice's wall), and Lightning brews a storm
//  where it lands. While it does, it holds still or rams, and its cooldowns,
//  basics, passives and timers wait — survival's order exactly. The numbers
//  come from horn_runtime.dart and the particles from horn_vfx.dart, the
//  modules survival itself now runs on.
//
//  Every entry point takes the caster. Foes are reached only through
//  [enemies] (and [activeBoss] for the ram), allies through
//  [activeCompanions], the ship and [companionProjectiles], so the wild
//  Alchemon runs the very same code on its own side (cosmic_game_duel.dart).
// ─────────────────────────────────────────────────────────────────────────────
extension CosmicHornRuntime on CosmicGame {
  bool _isHornCaster(CosmicCompanion c) =>
      c.member.family.toLowerCase() == 'horn';

  // ── sinks for the shared emitters ───────────────────────────────────────

  void _hornParticle(
    double x,
    double y,
    double vx,
    double vy,
    double size,
    double life,
    Color color, {
    bool arc = false,
  }) => _abilityVfx.add(x, y, vx, vy, size, life, color);

  void _hornBeam(Offset a, Offset b, Color color, double width, double life) =>
      _spawnBeamFx(a, b, color, width: width, life: life);

  // ── what the runtime may do to the world ────────────────────────────────

  /// A hit from [caster] on [e]: through [_damageOpenEnemy], so a combat
  /// body books an execute and a real kill gets its VFX, loot and the cast's
  /// kill payoff.
  bool _hornHitFoe(
    CosmicCompanion caster,
    CosmicEnemy e,
    double amount, {
    String? element,
    bool spark = true,
    bool provoke = true,
  }) {
    final killed = _damageOpenEnemy(
      e,
      amount,
      element: element ?? caster.member.element,
      sourceSlot: caster.member.slotIndex,
    );
    if (spark) _spawnHitSpark(e.position, elementColor(caster.member.element));
    if (provoke && !e.provoked) _provokePackOf(e);
    if (killed) _creditHornKill(caster, e);
    return killed;
  }

  /// Moves a foe. A real enemy lives on the wrapped world; a combat body is
  /// read back as a shove, so it keeps the frame it stands in.
  void _hornMoveFoe(CosmicEnemy e, Offset to) {
    e.position = _isCombatBody(e) ? to : _wrap(to);
  }

  /// Plant: held where it stands. The timer is what the vine wrap draws.
  void _hornRoot(CosmicEnemy e, double duration) {
    e.hornPlantRootTimer = max(e.hornPlantRootTimer, duration);
    e.applySlow(0, duration);
  }

  /// Appends [p] as [caster]'s. The pool keeps survival's ceiling itself
  /// ([CappedProjectileList]), so a Steam kill chain cannot run away.
  void _hornEmit(CosmicCompanion caster, Projectile p) {
    p.sourceSlotIndex = caster.member.slotIndex;
    companionProjectiles.add(p);
  }

  void _hornEmitAll(CosmicCompanion caster, List<Projectile> projectiles) {
    for (final p in projectiles) {
      p.sourceSlotIndex = caster.member.slotIndex;
    }
    companionProjectiles.addAll(projectiles);
  }

  // ── the cast ────────────────────────────────────────────────────────────

  /// A Horn's cast, survival's order: the ram's burst held for the impact
  /// (or the Light barrier raised now), the shield and heals, then the ram
  /// itself — a wind-up, Water's circle, Ice's wall, or a straight charge.
  void _castOpenHorn(
    CosmicCompanion caster,
    CosmicSpecialResult result,
    Offset target,
  ) {
    final fireAngle = caster.angle;
    final element = caster.member.element;
    if (result.chargeTimer > 0) {
      clampHornChargeBurst(result.projectiles);
      caster.pendingChargeBurst = result.projectiles;
      caster.pendingChargeOrigin = caster.position;
      caster.pendingChargeAngle = fireAngle;
    } else {
      _hornEmitAll(caster, result.projectiles);
    }

    if (result.shieldHp > 0) {
      caster.shieldHp = max(caster.shieldHp, result.shieldHp);
    }
    if (result.selfHeal > 0) {
      caster.currentHp = min(caster.maxHp, caster.currentHp + result.selfHeal);
    }
    if (result.shipHeal > 0 && !_shipDead) {
      shipHealth = min(CosmicGame.shipMaxHealth, shipHealth + result.shipHeal);
    }
    if (result.blessingTimer > 0) {
      caster.blessingTimer = max(caster.blessingTimer, result.blessingTimer);
      caster.blessingHealPerTick = max(
        caster.blessingHealPerTick,
        result.blessingHealPerTick,
      );
    }

    if (result.chargeTimer > 0) {
      caster
        ..chargeDamage = result.chargeDamage
        ..chargeSpeedMultiplier = result.chargeSpeedMultiplier
        ..chargeSweepRadius = result.chargeSweepRadius
        ..chargeOvershootDistance = result.chargeOvershootDistance
        ..chargeFinalSweepRadius = result.chargeFinalSweepRadius
        ..chargeHitIds = <int>{}
        ..pendingChargeTimerValue = result.chargeTimer
        ..hornSpecialActiveWindow =
            HornRules.activeWindowBase + result.windUpTime
        ..hornLightningAbsorbed = 0;
      if (element == 'Blood') {
        final sac = hornBloodSacrifice(caster.currentHp);
        if (sac != null) {
          caster.currentHp -= sac.sacrifice;
          caster.hitFlash = 1.0;
          pushHornFx(_hornFx, HornFx.sacrifice(position: caster.position));
          caster.chargeDamage += sac.bonus;
        }
      }
      if (result.windUpTime > 0) {
        caster
          ..windUpTimer = result.windUpTime
          ..windUpElement = result.windUpElement
          ..windUpDashTarget = target
          ..windUpFireAngle = fireAngle;
      } else if (element == 'Water') {
        final circle = hornWaterCircle(
          fireAngle,
          caster.chargeOvershootDistance,
        );
        caster
          ..chargePathType = 'circle'
          ..chargeCircleCenter = caster.position
          ..chargeCircleRadius = circle.radius
          ..chargeCircleAngle = circle.startAngle
          ..chargeCircleAngularSpeed = circle.angularSpeed
          ..chargeTimer = circle.duration
          ..chargeTarget = null
          ..chargeHitIds = <int>{}
          ..chargeLeashAllowance = 0;
      } else if (element == 'Ice') {
        final dash = hornIceWallDash(
          caster.position,
          target,
          fireAngle,
          caster.chargeSpeedMultiplier,
        );
        caster
          ..chargeTarget = dash.target
          ..chargeHitIds = <int>{}
          ..chargePathType = 'ice-wall'
          ..iceWallTrailTimer = 0
          ..chargeTimer = dash.timer
          ..chargeLeashAllowance = HornRules.iceWallLength;
      } else {
        _startOpenHornDash(caster, target, result.chargeTimer);
      }
    }
    if (result.basicHasteTimer > 0) {
      caster.basicHasteTimer = result.basicHasteTimer;
      caster.basicHasteMultiplier = result.basicHasteMultiplier;
    }
  }

  void _startOpenHornDash(
    CosmicCompanion caster,
    Offset target,
    double requested,
  ) {
    final dash = hornStandardDash(
      caster.position,
      target,
      caster.chargeOvershootDistance,
      caster.chargeSpeedMultiplier,
      requested,
    );
    caster
      ..chargeTarget = dash.target
      ..chargeTimer = dash.timer
      ..chargeHitIds = <int>{}
      ..chargeLeashAllowance = caster.chargeOvershootDistance;
  }

  // ── the frame ───────────────────────────────────────────────────────────

  /// The special's hold on its caster this frame: a ram, a wind-up or
  /// Lightning's brew. True while it holds the body; the caller then skips
  /// steering, cooldowns, timers, passives, basics and the special, as
  /// survival does. Runs for both sides of a duel.
  bool _updateHornPhases(CosmicCompanion caster, double dt) {
    if (caster.hitFlash > 0) {
      caster.hitFlash = max(0.0, caster.hitFlash - dt * 4);
    }
    if (caster.chargeTimer > 0) {
      _holdHornBody(caster);
      _hornChargeStep(caster, dt);
      return true;
    }
    if (caster.windUpTimer > 0) {
      _holdHornBody(caster);
      _hornWindUpStep(caster, dt);
      return true;
    }
    if (caster.hornPostDashWindUpTimer > 0) {
      _holdHornBody(caster);
      _hornBrewStep(caster, dt);
      return true;
    }
    if (caster.hornSpecialActiveWindow > 0) {
      caster.hornSpecialActiveWindow -= dt;
    }
    return false;
  }

  /// The ability moves the body; its steering picks up from rest after.
  void _holdHornBody(CosmicCompanion caster) {
    caster.velocity = Offset.zero;
    caster.steerGoal = null;
  }

  void _hornChargeStep(CosmicCompanion c, double dt) {
    c.chargeTimer -= dt;
    final horn = _isHornCaster(c);
    final element = c.member.element;
    if (horn && element == 'Lava' && _abilityVfx.length < 130) {
      // Approximate progress 0 → 1 over the dash (survival's fixed 1.5 s).
      final progress = (1.5 - c.chargeTimer).clamp(0.0, 1.5) / 1.5;
      emitHornLavaChargeTelegraph(c.position, progress, _rng, _hornParticle);
    }
    if (c.chargePathType == 'circle' && c.chargeCircleCenter != null) {
      final center = c.chargeCircleCenter!;
      final from = hornCirclePoint(
        center,
        c.chargeCircleRadius,
        c.chargeCircleAngle,
      );
      c.chargeCircleAngle += c.chargeCircleAngularSpeed * dt;
      c.position = hornCirclePoint(
        center,
        c.chargeCircleRadius,
        c.chargeCircleAngle,
      );
      c.angle = c.chargeCircleAngle + pi / 2;
      _hornSweep(c, from, c.position, c.chargeSweepRadius);
    } else if (c.chargeTarget != null) {
      final dir = c.chargeTarget! - c.position;
      final dist = dir.distance;
      if (dist > HornRules.arriveEps) {
        final from = c.position;
        final step = HornRules.chargeSpeed * c.chargeSpeedMultiplier * dt;
        c.position += (dir / dist) * min(step, dist);
        c.angle = atan2(dir.dy, dir.dx);
        _hornSweep(
          c,
          from,
          c.position,
          c.chargeSweepRadius,
          onSurvivor: horn && (element == 'Plant' || element == 'Poison')
              ? (e) => _hornRamHook(c, e)
              : null,
        );
      }
      // Laid while it rams and while it waits out the end of the dash.
      if (c.chargePathType == 'ice-wall') {
        c.iceWallTrailTimer -= dt;
        if (c.iceWallTrailTimer <= 0) {
          c.iceWallTrailTimer = HornRules.iceWallSegmentInterval;
          _hornEmit(
            c,
            hornIceWallSegment(
              position: c.position,
              maxHp: c.maxHp,
              abilityAtk: c.abilityAtk,
              sourceSlot: c.member.slotIndex,
            ),
          );
        }
      }
      if (horn && element == 'Fire') {
        c.iceWallTrailTimer -= dt;
        if (c.iceWallTrailTimer <= 0) {
          c.iceWallTrailTimer = HornRules.fireTrailInterval;
          _hornEmit(
            c,
            hornFireTrailSegment(
              position: c.position,
              abilityAtk: c.abilityAtk,
              sourceSlot: c.member.slotIndex,
            ),
          );
        }
      }
    }
    if (c.chargeTimer <= 0) _hornChargeEnd(c);
  }

  /// Plant roots and Poison bites every body the ram passes and leaves alive.
  void _hornRamHook(CosmicCompanion c, CosmicEnemy e) {
    switch (c.member.element) {
      case 'Plant':
        _hornRoot(
          e,
          hornPlantRootDuration(c.member.statIntelligence.toDouble()),
        );
      case 'Poison':
        _hornHitFoe(
          c,
          e,
          c.abilityAtk * HornRules.poisonDashShare,
          element: 'Poison',
        );
    }
  }

  /// Every body within [radius] of the ram's path from [from] to [to], once
  /// per ram. The boss is struck too: open space is fought round bosses,
  /// and a companion's ram is meant to hurt one.
  void _hornSweep(
    CosmicCompanion c,
    Offset from,
    Offset to,
    double radius, {
    void Function(CosmicEnemy e)? onSurvivor,
  }) {
    final hit = c.chargeHitIds ??= <int>{};
    for (final e in enemies) {
      if (e.dead || hit.contains(e.hashCode)) continue;
      if (_distanceToSegment(e.position, from, to) >= e.radius + radius) {
        continue;
      }
      hit.add(e.hashCode);
      _hornHitFoe(c, e, c.chargeDamage);
      if (!e.dead) onSurvivor?.call(e);
    }
    final boss = activeBoss;
    if (boss != null && !boss.dead && !hit.contains(boss.hashCode)) {
      if (_distanceToSegment(boss.position, from, to) < boss.radius + radius) {
        hit.add(boss.hashCode);
        boss.health -= c.chargeDamage;
        _spawnHitSpark(to, elementColor(c.member.element));
        if (boss.health <= 0) _handleBossKill(boss);
      }
    }
  }

  void _hornChargeEnd(CosmicCompanion c) {
    final horn = _isHornCaster(c);
    c.chargeTimer = 0;
    _hornSweep(c, c.position, c.position, c.chargeFinalSweepRadius);
    if (horn) {
      pushHornFx(
        _hornFx,
        HornFx.slam(
          position: c.position,
          angle: c.angle,
          radius: c.chargeFinalSweepRadius,
          element: c.member.element,
        ),
      );
      _soundHornSlam(c.member.element);
    }
    // Lightning brews its storm where it landed before the burst goes.
    if (horn &&
        c.member.element == 'Lightning' &&
        c.pendingChargeBurst != null) {
      c
        ..hornPostDashWindUpTimer = HornRules.postDashBrew
        ..chargeTarget = null
        ..chargeHitIds = null;
      onSound?.call(SoundCue.specialHornBrew);
      _postChargeReanchor(c);
      return;
    }
    final pending = c.pendingChargeBurst;
    if (pending != null && pending.isNotEmpty) {
      final delta = c.position - (c.pendingChargeOrigin ?? c.position);
      for (final p in pending) {
        p.position += delta;
      }
      _hornEmitAll(c, pending);
      _spawnHitSpark(c.position, elementColor(c.member.element));
    }
    // Dark delivers what its void caught to where the dash ends.
    final captured = c.hornDarkCaptured;
    if (captured != null && captured.isNotEmpty) {
      for (final e in captured) {
        if (e.dead || !enemies.contains(e)) continue;
        final a = _rng.nextDouble() * 2 * pi;
        final r =
            HornRules.darkCaptureJitterMin +
            _rng.nextDouble() * HornRules.darkCaptureJitterSpan;
        _hornMoveFoe(e, c.position + Offset(cos(a) * r, sin(a) * r));
        e.flightSteering = null;
        _hornHitFoe(
          c,
          e,
          c.chargeDamage * HornRules.darkCaptureDamageMul,
          element: 'Dark',
        );
      }
    }
    c
      ..hornDarkCaptured = null
      ..pendingChargeBurst = null
      ..pendingChargeOrigin = null
      ..chargeTarget = null
      ..chargeHitIds = null
      ..chargePathType = ''
      ..chargeCircleCenter = null
      ..iceWallTrailTimer = 0;
    _postChargeReanchor(c);
  }

  void _hornWindUpStep(CosmicCompanion c, double dt) {
    c.windUpTimer -= dt;
    final element = c.windUpElement;
    switch (element) {
      case 'Dark':
        _hornDarkVoidSuck(c, dt);
        if (_abilityVfx.length < 130) {
          emitHornDarkVoidBrew(
            c.position,
            c.windUpTimer,
            _rng,
            _hornParticle,
            _hornBeam,
          );
        }
      case 'Crystal':
        if (_beamFx.length < 22) {
          emitHornCrystalOrbit(c.position, c.windUpTimer, _hornBeam);
        }
      case 'Spirit':
        if (_abilityVfx.length < 130) {
          emitHornSpiritSwarm(
            c.position,
            c.windUpTimer,
            _rng,
            _hornParticle,
            _hornBeam,
          );
        }
    }
    if (c.windUpTimer > 0) return;
    if (element == 'Dark') {
      final captureRadius = hornDarkCaptureRadius(
        c.member.statBeauty.toDouble(),
      );
      c.hornDarkCaptured = [
        for (final e in enemies)
          if (!e.dead && (e.position - c.position).distance <= captureRadius) e,
      ];
      final dash = hornDarkEdgeDash(
        c.position,
        c.windUpFireAngle,
        c.chargeOvershootDistance,
        c.chargeSpeedMultiplier,
      );
      c
        ..chargeTarget = dash.target
        ..chargeHitIds = <int>{}
        ..chargeTimer = dash.timer
        ..chargeLeashAllowance =
            c.chargeOvershootDistance + HornRules.darkEdgeExtra;
    } else {
      _startOpenHornDash(
        c,
        c.windUpDashTarget ?? c.position,
        c.pendingChargeTimerValue,
      );
    }
    c
      ..windUpElement = ''
      ..windUpDashTarget = null
      ..windUpTimer = 0;
  }

  /// Dark's wind-up: everything in the void is dragged in, harder as it
  /// builds, and slowed while it is.
  void _hornDarkVoidSuck(CosmicCompanion c, double dt) {
    final aura = hornDarkAuraRadius(c.member.statBeauty.toDouble());
    final pull = hornDarkPullSpeed(c.windUpTimer);
    for (final e in enemies) {
      if (e.dead) continue;
      final dx = c.position.dx - e.position.dx;
      final dy = c.position.dy - e.position.dy;
      final distSq = dx * dx + dy * dy;
      if (distSq < 4.0 || distSq > aura * aura) continue;
      final dist = sqrt(distSq);
      _hornMoveFoe(e, e.position + Offset(dx / dist, dy / dist) * (pull * dt));
      e.applySlow(HornRules.darkDragSlowMul, HornRules.darkDragSlowDur);
    }
  }

  /// Lightning's brew where the ram landed; then the discharge, carrying
  /// what the horn absorbed on the way in.
  void _hornBrewStep(CosmicCompanion c, double dt) {
    c.hornPostDashWindUpTimer -= dt;
    if (_abilityVfx.length < 130) {
      emitHornLightningStormBrew(
        c.position,
        c.hornPostDashWindUpTimer,
        _rng,
        _hornParticle,
        _hornBeam,
      );
    }
    if (c.hornPostDashWindUpTimer > 0) return;
    c.hornPostDashWindUpTimer = 0;
    final pending = c.pendingChargeBurst;
    if (pending != null && pending.isNotEmpty) {
      final delta = c.position - (c.pendingChargeOrigin ?? c.position);
      final absorbMul = hornLightningAbsorbMultiplier(
        c.member.statBeauty.toDouble(),
      );
      for (final p in pending) {
        p.position += delta;
        if (p.tickEffect == AbilityEffectKind.chain &&
            c.hornLightningAbsorbed > 0) {
          p.effectPower += c.hornLightningAbsorbed * absorbMul;
        }
      }
      c.hornLightningAbsorbed = 0;
      final chainZone = pending.firstWhere(
        (p) => p.tickEffect == AbilityEffectKind.chain,
        orElse: () => pending.first,
      );
      emitHornLightningChainBurst(
        chainZone.position,
        chainZone.effectRadius > 0 ? chainZone.effectRadius : 140.0,
        145 - _abilityVfx.length,
        _rng,
        _hornParticle,
      );
      onSound?.call(SoundCue.specialHornDischarge);
      _spawnHitSpark(chainZone.position, hornLightningFlashColor);
      _hornEmitAll(c, pending);
    }
    c
      ..pendingChargeBurst = null
      ..pendingChargeOrigin = null;
  }

  // ── Light: the channel ──────────────────────────────────────────────────

  /// A Light horn holds still, and its cooldowns wait, while its barrier
  /// stands. [pool] is where the caster's projectiles are, when the caller
  /// is not on the caster's side (the duel's steering).
  bool _hornLightChanneling(CosmicCompanion c, [List<Projectile>? pool]) {
    if (!_isHornCaster(c) || c.member.element != 'Light') return false;
    for (final p in pool ?? companionProjectiles) {
      if (p.sourceSlotIndex == c.member.slotIndex && isHornLightBarrier(p)) {
        return true;
      }
    }
    return false;
  }

  /// A barrier throws back what walks into it: a body inside is put on its
  /// rim and shoved on. Survival does this with the first barrier found,
  /// once a frame, before its enemies move.
  void _applyHornLightBounce() {
    Projectile? barrier;
    for (final p in companionProjectiles) {
      if (isHornLightBarrier(p)) {
        barrier = p;
        break;
      }
    }
    if (barrier == null) return;
    final centre = barrier.position;
    final reach = hornLightProtectRadius(barrier);
    for (final e in enemies) {
      if (e.dead) continue;
      final dx = e.position.dx - centre.dx;
      final dy = e.position.dy - centre.dy;
      final distSq = dx * dx + dy * dy;
      final r = reach + e.radius;
      if (distSq >= r * r || distSq <= 0.5) continue;
      final dist = sqrt(distSq);
      final norm = Offset(dx / dist, dy / dist);
      _hornMoveFoe(e, centre + norm * r);
      _knockOpenEnemy(e, norm, HornRules.lightBounceKnock);
    }
  }

  // ── passives ────────────────────────────────────────────────────────────

  /// Air blows back what comes near, Mud trails sludge while it is out
  /// fighting ([engaged]), Poison's aura bites what stands in it.
  void _tickOpenHornPassive(
    CosmicCompanion c,
    double dt, {
    required bool engaged,
  }) {
    final intelligence = c.member.statIntelligence.toDouble();
    switch (c.member.element) {
      case 'Air':
        final aura = hornAirAura(intelligence);
        for (final e in enemies) {
          if (e.dead) continue;
          final away = e.position - c.position;
          final distSq = away.dx * away.dx + away.dy * away.dy;
          if (distSq < aura.inner * aura.inner ||
              distSq > aura.outer * aura.outer) {
            continue;
          }
          final dist = sqrt(distSq);
          final falloff = 1.0 - (dist - aura.inner) / (aura.outer - aura.inner);
          _hornMoveFoe(
            e,
            e.position +
                away / dist * (aura.push * (0.45 + 0.55 * falloff) * dt),
          );
        }
        if (_abilityVfx.length >= 130) return;
        c.hornAirParticleTimer -= dt;
        if (c.hornAirParticleTimer <= 0) {
          c.hornAirParticleTimer = HornRules.airParticleInterval;
          emitHornAirWind(
            c.position,
            aura.inner,
            aura.outer,
            _rng,
            _hornParticle,
          );
        }
      case 'Mud':
        if (!engaged) return;
        c.hornMudTrailTimer -= dt;
        if (c.hornMudTrailTimer > 0) return;
        c.hornMudTrailTimer = hornMudInterval(intelligence);
        final jitter = Offset(
          (_rng.nextDouble() - 0.5) * 8.0,
          (_rng.nextDouble() - 0.5) * 8.0,
        );
        _hornEmit(
          c,
          hornMudSludge(
            position: c.position + jitter,
            abilityAtk: c.abilityAtk,
            sourceSlot: c.member.slotIndex,
          ),
        );
      case 'Poison':
        c.hornPoisonAuraTimer -= dt;
        if (c.hornPoisonAuraTimer > 0) return;
        c.hornPoisonAuraTimer = HornRules.poisonAuraInterval;
        final auraScale = hornPoisonAuraScale(intelligence);
        final reach = HornRules.poisonAuraRadius * auraScale;
        final damage = max(1.0, c.abilityAtk * 0.18);
        for (final e in enemies) {
          if (e.dead || (e.position - c.position).distance > reach) continue;
          _hornHitFoe(
            c,
            e,
            damage,
            element: 'Poison',
            spark: false,
            provoke: false,
          );
        }
        _hornEmit(
          c,
          hornPoisonAuraPuff(
            position: c.position,
            auraScale: auraScale,
            sourceSlot: c.member.slotIndex,
          ),
        );
    }
  }

  // ── kills ───────────────────────────────────────────────────────────────

  /// A kill [caster] made, by any of its hits, while its special's window
  /// is open: Steam's geyser and reset, Lava's seeking flames, Blood's heal.
  void _creditHornKill(CosmicCompanion? caster, CosmicEnemy enemy) {
    if (caster == null ||
        !_isHornCaster(caster) ||
        caster.hornSpecialActiveWindow <= 0 ||
        _isCombatBody(enemy)) {
      return;
    }
    final beauty = caster.member.statBeauty.toDouble();
    switch (caster.member.element) {
      case 'Steam':
        caster.specialCooldown = 0;
        final steam = hornSteamKillScales(
          beauty,
          caster.member.statIntelligence.toDouble(),
        );
        _hornEmit(
          caster,
          hornSteamKillGeyser(
            position: enemy.position,
            abilityAtk: caster.abilityAtk,
            sizeScale: steam.size,
            durScale: steam.dur,
            sourceSlot: caster.member.slotIndex,
          ),
        );
      case 'Lava':
        if (_abilityVfx.length < 140) {
          emitHornLavaKillExplosion(enemy.position, _rng, _hornParticle);
          _spawnHitSpark(enemy.position, kHornLavaKillSparkColor);
        }
        final seek = hornLavaSeek(beauty);
        final prey = [
          for (final other in enemies)
            if (!other.dead &&
                !identical(other, enemy) &&
                (other.position - enemy.position).distance <= seek.radius)
              other,
        ];
        if (prey.isEmpty) return;
        final flames = min(seek.maxFlames, prey.length);
        for (var i = 0; i < flames; i++) {
          final dir = prey[i % prey.length].position - enemy.position;
          _hornEmit(
            caster,
            hornLavaSeekerFlame(
              position: enemy.position,
              angle: atan2(dir.dy, dir.dx),
              abilityAtk: caster.abilityAtk,
              sourceSlot: caster.member.slotIndex,
            ),
          );
        }
      case 'Blood':
        final heal = hornBloodKillHeal(caster.maxHp, beauty);
        pushHornFx(
          _hornFx,
          HornFx.siphon(from: enemy.position, to: caster.position),
        );
        caster.currentHp = min(caster.maxHp, caster.currentHp + heal);
    }
  }

  /// A Horn zone's tick emptied [enemy]: it dies as a hit would kill it, and
  /// the kill is its caster's.
  void _settleHornZoneKill(Projectile zone, CosmicEnemy enemy) {
    if (enemy.dead || enemy.health > 0 || _isCombatBody(enemy)) return;
    enemy.dead = true;
    _spawnKillVfx(
      enemy.position,
      elementColor(enemy.element),
      enemy.radius,
      false,
    );
    _spawnLootDrops(
      enemy.position,
      enemy.element,
      enemy.shardDrop,
      enemy.particleDrop,
    );
    _creditHornKill(_sourceCompanion(zone), enemy);
  }

  // ── what reaches a companion ────────────────────────────────────────────

  /// Horn's say in a hit of [raw] on [comp]: Lightning banks what it takes
  /// mid-ram for its discharge, Spirit phases through its wind-up and ram,
  /// and anyone inside a Light barrier on its side is covered. [pool] is
  /// that side's projectiles when the caller stands on the other one.
  double _hornIncomingScale(
    CosmicCompanion comp,
    double raw, {
    List<Projectile>? pool,
  }) {
    var scale = 1.0;
    if (_isHornCaster(comp)) {
      if (comp.member.element == 'Lightning' && comp.chargeTimer > 0) {
        comp.hornLightningAbsorbed += raw;
      }
      if (comp.member.element == 'Spirit' &&
          (comp.windUpTimer > 0 || comp.chargeTimer > 0)) {
        scale *= HornRules.spiritPhaseMul;
      }
    }
    for (final p in pool ?? companionProjectiles) {
      if (!isHornLightBarrier(p)) continue;
      if ((comp.position - p.position).distance <= hornLightProtectRadius(p)) {
        scale *= HornRules.lightAllyMul;
      }
      break;
    }
    return scale;
  }

  /// A hit on a party companion from the world (contact, a boss), through
  /// Horn's cover and the companion's grace window. [damage] is after the
  /// companion's defence, in the world's authored units.
  void _openCompanionIncomingDamage(CosmicCompanion comp, double damage) {
    final hit = damage * CosmicBalance.spaceIncomingScale;
    final scale = _hornIncomingScale(comp, hit);
    comp.takeDamage(max(1, (hit * scale).round()));
  }

  // ── what it wears ───────────────────────────────────────────────────────

  /// Its own abilities worn round a fighting Alchemon's body — a Horn
  /// Poison's reach, a shield, a ram's wake. The canvas is at its centre.
  /// Party companions and the wild Alchemon they fight both wear these.
  void _renderCasterOverlay(
    Canvas canvas,
    CosmicCompanion comp, {
    double scale = 1,
  }) {
    if (_isHornCaster(comp) && comp.member.element == 'Poison') {
      drawHornPoisonAura(canvas: canvas, radius: 140, time: _elapsed);
    }
    if (comp.hasShield) {
      drawAdvancedCompanionShield(canvas: canvas, time: _elapsed, scale: scale);
    }
    if (comp.isCharging) {
      drawAdvancedChargeTrail(
        canvas: canvas,
        color: elementColor(comp.member.element),
        angle: comp.angle,
        sweepRadius: comp.chargeSweepRadius,
        overshootDistance: comp.chargeOvershootDistance,
        element: comp.member.element,
        time: _elapsed,
        scale: scale,
      );
    }
  }

  /// A Blood horn flashes white as it pays its price, as in survival.
  void _applyCasterHitFlash(Paint paint, CosmicCompanion comp) {
    if (comp.hitFlash <= 0) return;
    paint.colorFilter = const ColorFilter.mode(Colors.white, BlendMode.srcATop);
  }
}
