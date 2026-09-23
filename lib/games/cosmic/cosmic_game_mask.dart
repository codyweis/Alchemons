part of 'cosmic_game.dart';

/// Mask placements have their own lifecycle; contact effects must never turn
/// the pools or shards they create back into fresh parent traps.
extension CosmicMaskRuntime on CosmicGame {
  bool activateMaskPlacements(List<Projectile> placements) {
    if (placements.isEmpty || placements.first.abilityFamily != 'mask') {
      return false;
    }
    final seed = placements.first;
    if (seed.element == 'Plant') {
      final existing = companionProjectiles
          .where(
            (p) =>
                p.life > 0 &&
                p.abilityFamily == 'mask' &&
                p.element == 'Plant' &&
                p.sourceSlotIndex == seed.sourceSlotIndex,
          )
          .firstOrNull;
      final vine = existing ?? seed;
      vine.maskBasePower ??= max(1.0, seed.effectPower);
      vine.effectStacks = (vine.effectStacks + 1).clamp(1, 100);
      final t = vine.effectStacks / 100;
      vine.snareRadius = 90 + 210 * t;
      vine.effectRadius = 90 + 230 * t;
      vine.snareMoveMultiplier = 0.5 - 0.4 * t;
      vine.visualScale = vine.radiusMultiplier = 2.4 + 4.1 * t;
      vine.effectPower = vine.maskBasePower! * (1 + 5 * t);
      vine.life = max(vine.life, seed.life);
      vine.abilityGrowthTimer = 1;
      if (existing == null) {
        companionProjectiles.add(vine);
      } else {
        final delta = seed.position - vine.position;
        if (delta.distance > 0) {
          vine.position += delta * min(1.0, 60 / delta.distance);
        }
      }
      return true;
    }
    if (seed.element == 'Dust') {
      void shield(int slot, Offset position) {
        final existing = companionProjectiles
            .where(
              (p) =>
                  p.life > 0 &&
                  p.abilityFamily == 'mask' &&
                  p.element == 'Dust' &&
                  p.sourceSlotIndex == seed.sourceSlotIndex &&
                  p.attachedToSlot == slot,
            )
            .firstOrNull;
        if (existing != null) {
          existing.life = max(existing.life, seed.life);
          existing.interceptCharges = 5;
          return;
        }
        companionProjectiles.add(
          Projectile(
            position: position,
            angle: 0,
            element: 'Dust',
            damage: 0,
            life: seed.life,
            stationary: true,
            piercing: true,
            visualStyle: ProjectileVisualStyle.sigil,
            visualScale: seed.visualScale,
            radiusMultiplier: seed.radiusMultiplier,
            abilityFamily: 'mask',
            sourceSlotIndex: seed.sourceSlotIndex,
            attachedToSlot: slot,
            tickEffect: AbilityEffectKind.zoneDamage,
            effectPower: seed.effectPower,
            effectRadius: max(72, seed.effectRadius),
            interceptRadius: max(72, seed.effectRadius),
            interceptCharges: 5,
          ),
        );
      }

      shield(-1, ship.pos);
      for (final comp in _livingActiveCompanions) {
        shield(comp.member.slotIndex, comp.position);
      }
      for (final g in _garrison) {
        if (g.hp > 0) shield(g.member.slotIndex, g.position);
      }
      return true;
    }
    companionProjectiles.addAll(placements);
    return true;
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
    if (near(ship.pos)) {
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

  /// Called each frame for persistent blood marks and attached/collectible traps.
  void updateMaskRuntime(double dt) {
    _maskBloodTimer += dt;
    if (_maskBloodTimer >= 0.35) {
      final elapsed = _maskBloodTimer;
      _maskBloodTimer = 0;
      var drained = 0.0;
      for (final enemy in _maskBloodMarked.toList()) {
        if (enemy.dead || !enemies.contains(enemy)) {
          _maskBloodMarked.remove(enemy);
          continue;
        }
        final before = enemy.health;
        _damageOpenEnemy(
          enemy,
          max(2.0, enemy.maxHealth * 0.06) * elapsed,
          element: 'Blood',
        );
        drained += before - max(0.0, enemy.health);
      }
      _maskBloodHealing += drained * 0.35;
      if (_maskBloodHealing >= 1) {
        final heal = _maskBloodHealing.floorToDouble();
        _maskBloodHealing -= heal;
        _healMaskAllies(heal);
      }
    }
    for (final p in companionProjectiles) {
      if (p.abilityFamily != 'mask' || p.life <= 0) continue;
      if (p.element == 'Dust' && p.attachedToSlot != -2) {
        final comp = activeCompanions[p.attachedToSlot];
        final g = _garrison
            .where((g) => g.member.slotIndex == p.attachedToSlot && g.hp > 0)
            .firstOrNull;
        if (p.attachedToSlot == -1) {
          p.position = ship.pos;
        } else if (comp != null && comp.isAlive && !comp.returning) {
          p.position = comp.position;
        } else if (g != null) {
          p.position = g.position;
        } else {
          p.life = 0;
        }
      }
      if (p.element == 'Plant' && p.stationary) {
        final comp = _sourceCompanion(p);
        final g = _sourceGarrison(p);
        if ((comp != null && comp.isAlive && !comp.returning) ||
            (g != null && g.hp > 0)) {
          p.life = max(p.life, 1.0 + dt);
        }
      }
      if (p.element == 'Spirit' &&
          p.hitEffect == AbilityEffectKind.flower &&
          (ship.pos - p.position).distance <= 36) {
        p.life = 0;
        final slot = p.sourceSlotIndex ?? -1;
        final bank = (_maskSpiritBank[slot] ?? 0) + 1;
        _maskSpiritBank[slot] = bank % 6;
        _maskTrapVisuals.contact(p);
        if (bank >= 6) {
          // Bosses live outside this list and are intentionally unaffected.
          for (final enemy in enemies) {
            if (!enemy.dead) {
              _damageOpenEnemy(enemy, enemy.health + 1, element: 'Spirit');
            }
          }
        }
      }
    }
  }

  /// Returns true when Mask owns this tick, including support with no enemies.
  bool tickMaskPlacement(Projectile p) {
    if (p.abilityFamily != 'mask') return false;
    if (p.life <= 0 || p.trapSpent) return true;
    final radius = p.effectRadius;
    final boss = activeBoss;
    if (p.isMaskDamageZone &&
        boss != null &&
        !boss.dead &&
        (boss.position - p.position).distance <= radius + boss.radius) {
      _damageOpenBoss(p.effectPower, element: p.element);
      if (p.element == 'Lightning' &&
          p.noteMaskGrowthHit(identityHashCode(boss))) {
        p.effectRadius = min(260.0, p.effectRadius + 14);
        p.life = min(18.0, p.life + 0.6);
      }
    }
    if (p.element == 'Earth') {
      _healMaskAllies(p.effectPower, pool: p);
      return true;
    }
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
      return true; // The snare slows only inside the pool.
    }
    if (p.element == 'Dark') {
      for (final enemy in enemies) {
        if (enemy.dead || (enemy.position - p.position).distance > radius) {
          continue;
        }
        final delta = p.position - enemy.position;
        if (delta.distance <= 56) {
          _ejectMaskEnemy(p, enemy);
        } else {
          enemy.position +=
              delta /
              delta.distance *
              min(16.0, 340 / max(delta.distance, 9.0));
        }
      }
      return true;
    }
    if (p.isMaskDamageZone) {
      for (final enemy in enemies) {
        if (enemy.dead || (enemy.position - p.position).distance > radius) {
          continue;
        }
        _damageOpenEnemy(enemy, p.effectPower, element: p.element);
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

  void _ejectMaskEnemy(Projectile p, CosmicEnemy enemy) {
    final delta = enemy.position - p.position;
    final dir = delta.distance > 0.01
        ? delta / delta.distance
        : const Offset(1, 0);
    enemy.position = p.position + dir * max(700.0, p.effectRadius * 3);
    _maskTrapVisuals.contact(p);
  }

  bool resolveMaskContact(Projectile p, CosmicEnemy enemy) {
    if (p.abilityFamily != 'mask') return false;
    if (p.trapSpent) return true;
    switch (p.element) {
      case 'Light':
        p.trapSpent = true;
        p.life = min(p.life, 0.4);
        _damageOpenEnemy(enemy, enemy.health + 1, element: 'Light');
        return true;
      case 'Dark':
        _ejectMaskEnemy(p, enemy);
        return true;
      case 'Spirit':
        return true;
      case 'Blood':
        if (!enemy.dead) _maskBloodMarked.add(enemy);
        return true;
      case 'Crystal':
      case 'Fire':
        return _activateMaskContactPlacement(p, enemy.position);
    }
    return false;
  }

  bool _activateMaskContactPlacement(Projectile p, Offset at) {
    if (p.trapSpent) return true;
    switch (p.element) {
      case 'Crystal':
        if (p.hitEffect != AbilityEffectKind.split) return false;
        p.trapSpent = true;
        p.life = min(p.life, 0.3);
        for (var i = 0; i < 3; i++) {
          final a = i * pi * 2 / 3;
          companionProjectiles.add(
            Projectile(
              position: at + Offset(cos(a), sin(a)) * 18,
              angle: a,
              element: 'Crystal',
              damage: p.damage * 0.55,
              life: 4,
              stationary: true,
              piercing: true,
              abilityFamily: 'mask',
              sourceSlotIndex: p.sourceSlotIndex,
              visualStyle: ProjectileVisualStyle.sigil,
              radiusMultiplier: max(0.9, p.radiusMultiplier * 0.55),
              visualScale: max(1.0, p.visualScale * 0.55),
              hitEffect: AbilityEffectKind.splash,
              effectPower: p.effectPower * 0.55,
              effectRadius: max(60, p.effectRadius * 0.65),
            ),
          );
        }
        return true;
      case 'Fire':
        if (p.hitEffect != AbilityEffectKind.burn) return true;
        p.trapSpent = true;
        p.life = min(p.life, 0.35);
        companionProjectiles.add(
          Projectile(
            position: p.position,
            angle: 0,
            element: 'Fire',
            damage: 0,
            life: max(4, p.effectDuration),
            stationary: true,
            piercing: true,
            abilityFamily: 'mask',
            sourceSlotIndex: p.sourceSlotIndex,
            visualStyle: ProjectileVisualStyle.sigil,
            radiusMultiplier: max(1.2, p.radiusMultiplier * 1.2),
            visualScale: max(1.6, p.visualScale * 1.2),
            tickEffect: AbilityEffectKind.burn,
            effectPower: p.effectPower,
            effectRadius: max(80, p.effectRadius),
            effectDuration: max(4, p.effectDuration),
          ),
        );
        return true;
    }
    return false;
  }
}
