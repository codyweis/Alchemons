part of 'cosmic_game.dart';

/// Placed turrets (Mask Steam's geysers) hold fire while this many companion
/// projectiles are in flight — Survival's ceiling, 72% of its 220-projectile
/// pool, so a self-firing field never crowds out the casts the player made.
const int _kMaskTurretFireCeiling = 158;

/// How far past the edge of the field a Dark hole puts what it ejects.
const double _kMaskEjectBeyondField = 70;

/// Mask placements have their own lifecycle; contact effects must never turn
/// the pools or shards they create back into fresh parent traps.
///
/// Survival is the source of truth, and the pieces themselves come from the
/// shared modules (mask_trap_placement.dart, mask_trap_vfx.dart). What is
/// open space's own is who the allies and foes are: allies are reached only
/// through the ship, [activeCompanions] and [_garrison], foes only through
/// [enemies] and [activeBoss], so the wild Alchemon's side runs the same code
/// with those swapped (cosmic_game_duel.dart).
extension CosmicMaskRuntime on CosmicGame {
  /// The field a Mask cast works in. Open space has no arena; the fight is
  /// round the body the side defends, the ship, and as wide as Survival's
  /// arena would be on this screen — never so wide that a body put out of it
  /// lands where open space stops running enemies (1800 from the ship).
  Offset get _maskFieldCenter => ship.pos;

  double get _maskFieldRadius {
    if (!hasLayout) return 1140.0;
    final view = max(size.x, size.y) / _currentZoom * 0.54;
    return view.clamp(1140.0, 1660.0).toDouble();
  }

  @visibleForTesting
  double get debugMaskFieldRadius => _maskFieldRadius;

  @visibleForTesting
  List<MaskSpiritWisp> get debugMaskSpiritWisps => _maskSpiritWisps;

  @visibleForTesting
  double get debugMaskSpiritNukeFlash => _maskSpiritNukeFlash;

  /// The body that collects Spirit wisps: the ship while it flies, or on the
  /// wild Alchemon's side the Alchemon itself.
  Offset? get _maskCollector => !_shipDead || _onWildSideNow ? ship.pos : null;

  /// [caster] and [target] lay the field where Survival lays it: one trap on
  /// the chosen enemy and a compact field on its approach to what it is
  /// attacking, heal pools under the injured, the ice pillar among the party.
  ///
  /// A [fromGarrison] caster defends home, not the ship: its field is laid
  /// among the garrison, and the ship and party count only while they are at
  /// home with it.
  bool activateMaskPlacements(
    List<Projectile> placements, {
    Offset? caster,
    Offset? target,
    bool fromGarrison = false,
  }) {
    if (placements.isEmpty || placements.first.abilityFamily != 'mask') {
      return false;
    }
    final seed = placements.first;
    final centre = caster ?? ship.pos;
    final reach = _maskFieldRadius;
    bool local(Offset p) => !fromGarrison || (p - centre).distance <= reach;
    final shipLocal = !_shipDead && local(ship.pos);
    if (caster != null && target != null) {
      final allies = <({Offset position, double health})>[
        if (shipLocal)
          (position: ship.pos, health: shipHealth / CosmicGame.shipMaxHealth),
        for (final comp in _livingActiveCompanions)
          if (local(comp.position))
            (
              position: comp.position,
              health: comp.currentHp / max(1, comp.maxHp),
            ),
        if (fromGarrison)
          for (final g in _garrison)
            if (g.hp > 0 && local(g.position))
              (position: g.position, health: g.hp / max(1, g.maxHp)),
      ]..sort((a, b) => a.health.compareTo(b.health));
      placeMaskTraps(
        traps: placements,
        caster: caster,
        ship: fromGarrison && !shipLocal ? caster : ship.pos,
        allies: allies.map((a) => a.position).toList(),
        target: target,
        // Open space has no arena wall to keep the field inside.
        arenaCenter: fromGarrison ? caster : ship.pos,
        arenaRadius: double.infinity,
      );
    }
    switch (seed.element) {
      case 'Spirit':
        // Collectibles for the ship, not traps: nothing collides with them.
        for (final trap in placements) {
          if (_maskSpiritWisps.length >= kMaskSpiritWispCap) break;
          _maskSpiritWisps.add(
            MaskSpiritWisp.fromTrap(
              trap,
              sourceSlotIndex: seed.sourceSlotIndex,
              bobPhase: _rng.nextDouble() * pi * 2,
            ),
          );
        }
        return true;
      case 'Plant':
        _feedMaskPlantVine(seed);
        return true;
      case 'Dust':
        _shieldMaskAllies(seed, caster: centre, fromGarrison: fromGarrison);
        return true;
    }
    companionProjectiles.addAll(placements);
    return true;
  }

  /// Each cast feeds the caster's one vine rather than planting another.
  void _feedMaskPlantVine(Projectile seed) {
    final slot = seed.sourceSlotIndex;
    Projectile? vine;
    for (final p in companionProjectiles) {
      if (p.life > 0 &&
          p.sourceSlotIndex == slot &&
          p.abilityFamily == 'mask' &&
          p.element == 'Plant' &&
          p.stationary) {
        vine = p;
        break;
      }
    }
    if (vine == null) {
      // Survival's vine lives the whole run. Open space's withers once its
      // caster is recalled, so it regrows from what it had been fed.
      final feeds = ((slot == null ? 0 : _maskPlantFeeds[slot] ?? 0) + 1).clamp(
        1,
        kMaskPlantMaxFeeds,
      );
      seed.effectStacks = feeds;
      applyMaskPlantVineFeed(seed, feeds);
      if (slot != null) _maskPlantFeeds[slot] = feeds;
      _playMaskPlantFeed(seed, newTendril: true);
      companionProjectiles.add(seed);
      return;
    }
    final prevFeeds = vine.effectStacks;
    final feeds = (prevFeeds + 1).clamp(1, kMaskPlantMaxFeeds);
    final newTendril = maskPlantFeedSproutsTendril(prevFeeds, feeds);
    vine.effectStacks = feeds;
    if (slot != null) _maskPlantFeeds[slot] = feeds;
    vine.life = max(vine.life, seed.life);
    final delta = seed.position - vine.position;
    final dist = delta.distance;
    if (dist > _maskFieldRadius) {
      // Survival's arena keeps the vine near the fight. In open space the
      // fight moves on, and a vine left behind across the map would never be
      // fed at anything, so it is replanted where the cast was aimed.
      vine.position = seed.position;
    } else if (dist > 0.01) {
      // Gentle re-anchor: at most 60px toward where the caster keeps aiming.
      vine.position += delta * (min(60.0, dist) / dist);
    }
    applyMaskPlantVineFeed(vine, feeds);
    _playMaskPlantFeed(vine, newTendril: newTendril);
  }

  /// The feed's flash (the renderer reads above 1 as a new tendril) and its
  /// burst of particles.
  void _playMaskPlantFeed(Projectile vine, {required bool newTendril}) {
    vine.abilityGrowthTimer = newTendril ? 2.0 : 1.0;
    emitMaskPlantFeedBurst(
      at: vine.position,
      newTendril: newTendril,
      rng: _rng,
      poolSize: () => _abilityVfx.length,
      emit: _emitMaskVfx,
    );
  }

  /// A dust shield on every ally in the fight: a recast tops up the shields
  /// its caster already set rather than stacking new ones. A companion's cast
  /// always wraps the ship it escorts.
  void _shieldMaskAllies(
    Projectile seed, {
    required Offset caster,
    required bool fromGarrison,
  }) {
    final slot = seed.sourceSlotIndex;
    final existing = <int, Projectile>{};
    for (final p in companionProjectiles) {
      if (p.life > 0 &&
          p.sourceSlotIndex == slot &&
          p.abilityFamily == 'mask' &&
          p.element == 'Dust' &&
          p.attachedToSlot != -2) {
        existing[p.attachedToSlot] = p;
      }
    }
    final reach = _maskFieldRadius;
    bool near(Offset p) => (p - caster).distance <= reach;
    // A garrison slot can share its number with a party slot; one host per
    // number, as attached pieces are found by it.
    final wrapped = <int>{};
    void shield(int host, Offset position) {
      if (!wrapped.add(host)) return;
      final prev = existing.remove(host);
      if (prev != null) {
        refreshMaskDustShield(prev, seed);
        return;
      }
      companionProjectiles.add(
        maskDustShield(
          seed,
          sourceSlotIndex: slot,
          attachedToSlot: host,
          position: position,
        ),
      );
    }

    if (!_shipDead && (!fromGarrison || near(ship.pos))) shield(-1, ship.pos);
    for (final comp in _livingActiveCompanions) {
      if (near(comp.position)) shield(comp.member.slotIndex, comp.position);
    }
    for (final g in _garrison) {
      if (g.hp > 0 && near(g.position)) shield(g.member.slotIndex, g.position);
    }
  }

  double get maskShipDamageAmp =>
      companionProjectiles.any(
        (p) =>
            p.life > 0 &&
            p.abilityFamily == 'mask' &&
            p.element == 'Ice' &&
            (ship.pos - p.position).distance <= p.effectRadius,
      )
      ? 2.4
      : 1.0;

  void _healMaskAllies(double amount, {Projectile? pool}) {
    bool near(Offset position) =>
        pool == null ||
        (position - pool.position).distance <= pool.effectRadius;
    if (!_shipDead && near(ship.pos)) {
      shipHealth = min(CosmicGame.shipMaxHealth, shipHealth + amount);
    }
    for (final comp in _livingActiveCompanions) {
      if (near(comp.position)) {
        comp.currentHp = min(comp.maxHp, comp.currentHp + amount.round());
      }
    }
    for (final g in _garrison) {
      if (g.hp > 0 && near(g.position)) {
        g.hp = min(g.maxHp, g.hp + amount.round());
      }
    }
  }

  /// Blood's contact pulse: the caster drinks what the blob struck, or the
  /// ship does once the caster is gone.
  void _healMaskCaster(Projectile p) {
    final heal = p.effectPower;
    final comp = _sourceCompanion(p);
    if (comp != null) {
      comp.currentHp = min(comp.maxHp, comp.currentHp + heal.round());
      return;
    }
    final g = _sourceGarrison(p);
    if (g != null) {
      g.hp = min(g.maxHp, g.hp + heal.round());
      return;
    }
    if (!_shipDead) {
      shipHealth = min(CosmicGame.shipMaxHealth, shipHealth + heal);
    }
  }

  /// Called each frame for persistent blood marks, the traps' own clocks and
  /// the Spirit wisps.
  void updateMaskRuntime(double dt) {
    _updateMaskBloodDrain(dt);
    for (final p in companionProjectiles) {
      if (p.abilityFamily != 'mask' || p.life <= 0) continue;
      // A trap's "just fired" or "just fed" flash, read by its renderer,
      // subsides at Survival's rate.
      if (p.stationary && p.abilityGrowthTimer > 0) {
        p.abilityGrowthTimer = max(0.0, p.abilityGrowthTimer - dt * 1.6);
      }
      // Survival's vine lives the whole run; open space's lives while its
      // caster is out.
      if (p.element == 'Plant' && p.stationary) {
        final comp = _sourceCompanion(p);
        final g = _sourceGarrison(p);
        if ((comp != null && comp.isAlive && !comp.returning) ||
            (g != null && g.hp > 0)) {
          p.life = max(p.life, 1.0 + dt);
        }
      }
    }
    stepMaskSpiritWisps(
      _maskSpiritWisps,
      _maskCollector,
      dt,
      _collectMaskSpiritWisp,
    );
  }

  /// Once a frame, whichever side set it off: a Spirit clear's flash dies
  /// away. (Contact echoes age with the beam effects, in `_ageBeamFx`.)
  void _updateMaskVisuals(double dt) {
    if (_maskSpiritNukeFlash > 0) {
      _maskSpiritNukeFlash = max(0.0, _maskSpiritNukeFlash - dt * 1.2);
    }
  }

  /// Marked bodies bleed every frame until they die, and a share of it heals
  /// the party. Drops of blood run from each to the ally nearest it.
  void _updateMaskBloodDrain(double dt) {
    if (_maskBloodMarked.isEmpty) return;
    // A body that left the world without dying is let go on a slower beat;
    // looking it up in the enemy list every frame is not worth it.
    _maskBloodTimer += dt;
    if (_maskBloodTimer >= 0.35) {
      _maskBloodTimer = 0;
      _maskBloodMarked.removeWhere((e) => e.dead || !enemies.contains(e));
    }
    var drained = 0.0;
    for (final enemy in _maskBloodMarked) {
      if (enemy.dead) continue;
      final before = enemy.health;
      _damageOpenEnemy(
        enemy,
        maskBloodDrainPerSecond(enemy.maxHealth) * dt,
        element: 'Blood',
      );
      drained += before - max(0.0, enemy.health);
      // About six a second, keyed off dt so the stream holds at any rate.
      if (_abilityVfx.length < 140 && _rng.nextDouble() < dt * 6.0) {
        emitMaskBloodDrainWisp(
          from: enemy.position,
          toward: _nearestMaskAlly(enemy.position),
          rng: _rng,
          emit: _emitMaskVfx,
        );
      }
    }
    _maskBloodHealing += drained * kMaskBloodHealShare;
    if (_maskBloodHealing >= 1) {
      final heal = _maskBloodHealing.floorToDouble();
      _maskBloodHealing -= heal;
      _healMaskAllies(heal);
    }
  }

  /// Where the ally nearest [from] is — the ship or a companion — or [from]
  /// itself when there is none.
  Offset _nearestMaskAlly(Offset from) {
    var target = _shipDead ? from : ship.pos;
    var bestSq = _shipDead ? double.infinity : (target - from).distanceSquared;
    for (final comp in _livingActiveCompanions) {
      final ds = (comp.position - from).distanceSquared;
      if (ds < bestSq) {
        bestSq = ds;
        target = comp.position;
      }
    }
    return target;
  }

  /// A wisp reached the collector. It banks for its caster only while the
  /// caster is still out; the sixth clears the field.
  void _collectMaskSpiritWisp(MaskSpiritWisp wisp) {
    final slot = wisp.sourceSlotIndex;
    if (slot == null) return;
    final comp = activeCompanions[slot];
    Offset? casterAt = comp != null && comp.isAlive ? comp.position : null;
    if (casterAt == null) {
      for (final g in _garrison) {
        if (g.member.slotIndex == slot && g.hp > 0) {
          casterAt = g.position;
          break;
        }
      }
    }
    if (casterAt == null) return;
    _spawnHitSpark(ship.pos, elementColor('Spirit'));
    final bank = (_maskSpiritBank[slot] ?? 0) + 1;
    if (bank >= kMaskSpiritNukeThreshold) {
      _maskSpiritBank[slot] = 0;
      _fireMaskSpiritNuke(casterAt);
    } else {
      _maskSpiritBank[slot] = bank;
    }
  }

  /// Every enemy in the fight dies. Bosses are not in [enemies] and are
  /// untouched. Survival clears its whole arena; open space clears the field
  /// round the ship rather than the whole world.
  void _fireMaskSpiritNuke(Offset casterAt) {
    final centre = _maskFieldCenter;
    final reach = _maskFieldRadius;
    final reachSq = reach * reach;
    // A snapshot: a kill can add bodies to the list (a splitter's brood).
    for (final enemy in List<CosmicEnemy>.of(enemies)) {
      if (enemy.dead) continue;
      if ((enemy.position - centre).distanceSquared > reachSq) continue;
      _damageOpenEnemy(enemy, enemy.health + 1, element: 'Spirit');
    }
    _maskSpiritNukeFlash = 1.0;
    _maskSpiritNukeOrigin = centre;
    _spawnHitSpark(centre, elementColor('Spirit'));
    _spawnHitSpark(casterAt, elementColor('Spirit'));
    emitMaskSpiritNukeMotes(
      origin: centre,
      rng: _rng,
      poolSize: () => _abilityVfx.length,
      emit: _emitMaskVfx,
    );
  }

  /// A shared emitter's particle, into the ability pool. Callers gate on the
  /// pool's size.
  void _emitMaskVfx(
    double x,
    double y,
    double vx,
    double vy,
    double size,
    double life,
    Color color, {
    bool arc = false,
  }) {
    _abilityVfx.add(x, y, vx, vy, size, life, color);
  }

  /// A placed Mask turret (Steam's geysers) fires as Survival's do: at the
  /// nearest enemy in reach, else the boss, as many shots as its clock has
  /// run, and not while the projectile list is near full.
  void _fireMaskTurret(Projectile p, double dt) {
    if (p.turretInterval <= 0 || p.turretDamage <= 0) return;
    if (companionProjectiles.length >= _kMaskTurretFireCeiling) return;
    p.turretTimer += dt;
    while (p.turretTimer >= p.turretInterval) {
      p.turretTimer -= p.turretInterval;
      final target = _maskTurretTarget(p.position);
      if (target == null) continue;
      companionProjectiles.add(
        CosmicAbilityRuntime.companionTurretShot(p, target),
      );
    }
  }

  /// Survival's turret aims at the nearest enemy within reach, else at the
  /// boss wherever it is; a boss across open space is not in this fight, so
  /// it has to be within the field.
  Offset? _maskTurretTarget(Offset from) {
    const range = CosmicAbilityRuntime.turretTargetRange;
    CosmicEnemy? best;
    var bestSq = range * range;
    for (final e in enemies) {
      if (e.dead) continue;
      final dSq = (e.position - from).distanceSquared;
      if (dSq >= bestSq) continue;
      bestSq = dSq;
      best = e;
    }
    if (best != null) return best.position;
    final boss = activeBoss;
    if (boss != null &&
        !boss.dead &&
        (boss.position - from).distance <= _maskFieldRadius) {
      return boss.position;
    }
    return null;
  }

  /// Returns true when Mask owns this tick, including support with no enemies.
  bool tickMaskPlacement(Projectile p) {
    if (p.abilityFamily != 'mask') return false;
    if (p.life <= 0 || p.trapSpent) return true;
    final boss = activeBoss;
    if (p.isMaskDamageZone &&
        boss != null &&
        !boss.dead &&
        (boss.position - p.position).distance <= p.effectRadius + boss.radius) {
      _damageOpenBoss(p.effectPower, element: p.element);
      // Survival also chills a boss standing in a Plant vine. Open space's
      // bosses take no crowd control from any ability yet.
      if (p.element == 'Lightning' &&
          p.noteMaskGrowthHit(identityHashCode(boss))) {
        p.effectRadius = min(260.0, p.effectRadius + 14);
        p.life = min(18.0, p.life + 0.6);
      }
    }
    if (p.element == 'Earth') {
      _healMaskAllies(p.effectPower, pool: p);
      // The pool flares on every heal.
      p.abilityGrowthTimer = max(p.abilityGrowthTimer, 0.8);
      return true;
    }
    final radius = max(24.0, p.effectRadius);
    if (p.element == 'Ice') {
      for (final comp in _livingActiveCompanions) {
        if ((comp.position - p.position).distance > radius) continue;
        if (comp.damageAmpTimer <= 0) comp.damageAmpMultiplier = 1;
        comp.damageAmpTimer = max(comp.damageAmpTimer, 0.5);
        comp.damageAmpMultiplier = max(comp.damageAmpMultiplier, 2.4);
      }
      for (final g in _garrison) {
        if (g.hp <= 0 || (g.position - p.position).distance > radius) continue;
        if (g.damageAmpTimer <= 0) g.damageAmpMultiplier = 1;
        g.damageAmpTimer = max(g.damageAmpTimer, 0.5);
        g.damageAmpMultiplier = max(g.damageAmpMultiplier, 2.4);
      }
      return true;
    }
    if (p.element == 'Mud') {
      // The slow lingers after a body walks out of the pool; inside it the
      // snare slows it further.
      for (final enemy in enemies) {
        if (enemy.dead || (enemy.position - p.position).distance > radius) {
          continue;
        }
        _crowdControlOpenEnemy(enemy, AbilityEffectKind.slow, p.effectDuration);
      }
      return true;
    }
    if (p.element == 'Dark') {
      // The hole moves bodies and nothing else: it draws them in, and
      // whatever reaches the middle is put out of the fight.
      for (final enemy in enemies) {
        if (enemy.dead) continue;
        final delta = p.position - enemy.position;
        final dist = delta.distance;
        if (dist > radius) continue;
        if (dist > 56 && dist > 0.01) {
          enemy.position += delta / dist * min(16.0, 340 / max(dist, 9.0));
        } else {
          _maskTrapVisuals.contact(p);
          _ejectMaskEnemy(p, enemy, holeRadius: radius);
        }
      }
      return true;
    }
    if (p.isMaskDamageZone) {
      for (final enemy in enemies) {
        if (enemy.dead || (enemy.position - p.position).distance > radius) {
          continue;
        }
        switch (p.tickEffect) {
          case AbilityEffectKind.root:
            // The vine holds what it bites (Survival's root), then bites.
            _crowdControlOpenEnemy(
              enemy,
              AbilityEffectKind.root,
              p.effectDuration,
            );
            _damageOpenEnemy(
              enemy,
              p.effectPower,
              element: p.element,
              sourceSlot: p.sourceSlotIndex,
            );
          case AbilityEffectKind.geyser:
            _damageOpenEnemy(
              enemy,
              p.effectPower,
              element: p.element,
              sourceSlot: p.sourceSlotIndex,
            );
            enemy.knockbackVelocity += CosmicAbilityRuntime.geyserKnockback;
          default:
            _damageOpenEnemy(
              enemy,
              p.effectPower,
              element: p.element,
              sourceSlot: p.sourceSlotIndex,
            );
        }
        if (p.element == 'Lightning' &&
            p.noteMaskGrowthHit(identityHashCode(enemy))) {
          p.effectRadius = min(260.0, p.effectRadius + 14);
          p.life = min(18.0, p.life + 0.6);
        }
      }
      // Plant's snare is evaluated by the spatial movement path.
      return true;
    }
    return false;
  }

  /// Throws [enemy] out of the fight, unharmed: onto the ring just outside
  /// the field, never back into the hole, held a moment as it lands.
  void _ejectMaskEnemy(
    Projectile p,
    CosmicEnemy enemy, {
    required double holeRadius,
  }) {
    final hole = p.position;
    enemy.position = CosmicAbilityRuntime.fieldEjectLanding(
      center: _maskFieldCenter,
      ring: _maskFieldRadius + _kMaskEjectBeyondField,
      hole: hole,
      holeRadius: holeRadius,
      rng: _rng,
    );
    enemy.knockbackVelocity = Offset.zero;
    enemy.applySlow(
      CosmicAbilityRuntime.ejectSlowMultiplier,
      CosmicAbilityRuntime.ejectSlowDuration,
    );
    _spawnHitSpark(hole, const Color(0xFFB89AFF));
    _spawnHitSpark(enemy.position, const Color(0xFF6A4AA8));
  }

  bool resolveMaskContact(Projectile p, CosmicEnemy enemy) {
    if (p.abilityFamily != 'mask') return false;
    if (p.trapSpent) return true;
    switch (p.element) {
      case 'Air':
        // The pad flares as it fires; the generic knockback does the push.
        p.abilityGrowthTimer = 1.0;
        return false;
      case 'Light':
        // A void consumes exactly one body, then collapses.
        p.trapSpent = true;
        if (!enemy.dead) {
          _damageOpenEnemy(
            enemy,
            enemy.health + 1,
            element: 'Light',
            sourceSlot: p.sourceSlotIndex,
          );
        }
        p.abilityGrowthTimer = 1.0;
        p.life = min(p.life, 0.4);
        return true;
      case 'Dark':
        _ejectMaskEnemy(p, enemy, holeRadius: max(p.effectRadius, 40));
        return true;
      case 'Lightning':
        // Area ticks handle both damage and growth, including lone enemies.
        return true;
      case 'Spirit':
        return true;
      case 'Blood':
        // Marked to bleed for the party until it dies, and the caster
        // drinks the first cut.
        if (!enemy.dead) _maskBloodMarked.add(enemy);
        _healMaskCaster(p);
        return true;
      case 'Crystal':
      case 'Fire':
        return _activateMaskContactPlacement(p, enemy.position);
    }
    return false;
  }

  /// A crystal breaking or a fire ball bursting into its pool. [flash] is
  /// the trap's flare as it goes, which Survival shows on an enemy's touch
  /// and not a boss's.
  bool _activateMaskContactPlacement(
    Projectile p,
    Offset at, {
    bool flash = true,
  }) {
    if (p.trapSpent) return true;
    switch (p.element) {
      case 'Crystal':
        if (p.hitEffect != AbilityEffectKind.split) return false;
        p.trapSpent = true;
        companionProjectiles.addAll(
          maskCrystalShards(p, at, _rng.nextDouble() * pi * 2),
        );
        if (flash) p.abilityGrowthTimer = 1.0;
        p.life = min(p.life, 0.3);
        return true;
      case 'Fire':
        if (p.hitEffect != AbilityEffectKind.burn) return true;
        p.trapSpent = true;
        companionProjectiles.add(maskFirePool(p, p.position));
        if (flash) p.abilityGrowthTimer = 1.0;
        p.life = min(p.life, 0.35);
        return true;
    }
    return false;
  }

  /// Contact echoes over the traps, then the Spirit wisps on both sides of a
  /// duel. Drawn after the ability projectiles, as Survival draws them.
  void _renderMaskOverlays(Canvas canvas, Rect viewport) {
    _maskTrapVisuals.render(canvas, viewport: viewport);
    final visible = viewport.inflate(50);
    void wisps(List<MaskSpiritWisp> list) {
      for (final wisp in list) {
        if (!visible.contains(wisp.position)) continue;
        drawMaskSpiritWisp(
          canvas: canvas,
          position: wisp.position,
          life: wisp.life,
          bobPhase: wisp.bobPhase,
          time: _elapsed,
        );
      }
    }

    wisps(_maskSpiritWisps);
    wisps(_wildSide.spiritWisps);
  }

  /// A Spirit clear's ring and wash, over the ship as Survival draws it.
  void _renderMaskSpiritNukeFlash(Canvas canvas, Rect viewport) {
    drawMaskSpiritNukeFlash(
      canvas: canvas,
      origin: _maskSpiritNukeOrigin,
      flash: _maskSpiritNukeFlash,
      viewport: viewport,
    );
  }
}
