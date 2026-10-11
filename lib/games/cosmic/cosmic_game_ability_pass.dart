part of 'cosmic_game.dart';

/// One pass over the ability projectiles in flight: movement, orbits, Let
/// skyfall, trails, contact with bodies, zone ticks, bosses. The party's
/// projectiles run it every frame; the wild Alchemon's run it too, on their
/// own side (see cosmic_game_duel.dart), so both are the same abilities.
extension CosmicAbilityPass on CosmicGame {
  void _updateAbilityProjectiles(double dt) {
    // A Horn Light barrier throws back what walks into it, on whichever side
    // it stands, before anything else moves.
    _applyHornLightBounce();
    // The other side's shots meet this side's Kin pieces (cosmic_game_kin.dart).
    _screenFoeShots();

    /// [origin] is where the effect acts from, as survival passes it: the
    /// projectile for a hit (the default), the body for a pierce or a kill.
    void resolveAbilityEffect(
      AbilityEffectKind effect,
      Projectile projectile,
      CosmicEnemy enemy, {
      Offset? origin,
    }) {
      if (effect == AbilityEffectKind.none || enemy.dead) return;
      final from = origin ?? projectile.position;
      final power = CosmicAbilityRuntime.projectileEffectPower(projectile);
      final radius = CosmicAbilityRuntime.projectileEffectRadius(
        projectile,
        fallbackRadius: 90.0,
      );
      switch (effect) {
        case AbilityEffectKind.knockback:
          _knockOpenEnemy(
            enemy,
            enemy.position - projectile.position,
            CosmicAbilityRuntime.knockbackImpulse(projectile.effectPower),
          );
          break;
        case AbilityEffectKind.pull:
        case AbilityEffectKind.blackHole:
          // Survival's: everything within the radius of the origin is
          // dragged in and slowed, and a black hole eats the nearly-dead
          // inside it.
          final reach = projectile.effectRadius > 0
              ? projectile.effectRadius
              : 80.0;
          final hold = CosmicAbilityRuntime.projectileEffectDuration(
            projectile,
          );
          for (final other in enemies) {
            if (other.dead) continue;
            final dir = from - other.position;
            final dist = dir.distance;
            if (dist <= 0.01 || dist > reach) continue;
            other.position +=
                (dir / dist) * CosmicAbilityRuntime.blackHolePullStep(dist);
            other.applySlow(CosmicAbilityRuntime.blackHoleSlow, hold);
            if (effect == AbilityEffectKind.blackHole &&
                other.health / other.maxHealth <=
                    CosmicAbilityRuntime.blackHoleExecute) {
              _damageOpenEnemy(
                other,
                other.health + 1,
                sourceSlot: projectile.sourceSlotIndex,
              );
            }
          }
          break;
        case AbilityEffectKind.slow:
        case AbilityEffectKind.root:
        case AbilityEffectKind.freeze:
        case AbilityEffectKind.stun:
        case AbilityEffectKind.suppressShooting:
          _crowdControlOpenEnemy(
            enemy,
            effect,
            CosmicAbilityRuntime.projectileEffectDuration(projectile),
          );
          if (effect == AbilityEffectKind.root) enemy.health -= power;
          break;
        case AbilityEffectKind.burn:
        case AbilityEffectKind.poison:
        case AbilityEffectKind.zoneDamage:
        case AbilityEffectKind.execute:
        case AbilityEffectKind.geyser:
        case AbilityEffectKind.refraction:
        case AbilityEffectKind.chargeBlast:
          enemy.health -= CosmicAbilityRuntime.directDamageForEffect(
            effect,
            power: power,
            targetHp: enemy.health,
            targetHpFraction: enemy.health / enemy.maxHealth,
          );
          // A geyser pushes as well as scalds.
          if (effect == AbilityEffectKind.geyser) {
            enemy.knockbackVelocity += CosmicAbilityRuntime.geyserKnockback;
          }
          break;
        case AbilityEffectKind.splash:
        case AbilityEffectKind.split:
        case AbilityEffectKind.chain:
          for (final other in enemies) {
            if (other.dead || identical(other, enemy)) continue;
            if ((other.position - enemy.position).distance <= radius) {
              other.health -=
                  power * CosmicAbilityRuntime.splashMultiplier(effect);
              if (other.health <= 0) {
                other.dead = true;
                _spawnKillVfx(
                  other.position,
                  elementColor(other.element),
                  other.radius,
                  false,
                );
                _spawnLootDrops(
                  other.position,
                  other.element,
                  other.shardDrop,
                  other.particleDrop,
                );
              }
            }
          }
          break;
        case AbilityEffectKind.leech:
        case AbilityEffectKind.zoneHeal:
          // Survival's: what the cast protects takes a share, the caster the
          // whole (the ship when the caster is gone) — except Pip Blood,
          // which feeds only itself, and Pip Light, only what it protects.
          final isPip = projectile.abilityFamily == 'pip';
          final casterOnly = isPip && projectile.element == 'Blood';
          final objectiveOnly = isPip && projectile.element == 'Light';
          if (!casterOnly) {
            final objectiveHeal =
                power *
                (objectiveOnly ? 1.0 : CosmicAbilityRuntime.leechObjectiveShare);
            // Mane Blood heals with every body its shot crosses: survival's
            // per-caster ceiling.
            _healOpenObjective(
              projectile.abilityFamily == 'mane'
                  ? _healCeiling.grant(
                      slot: projectile.sourceSlotIndex,
                      amount: objectiveHeal,
                      pool: CosmicGame.shipMaxHealth,
                      beauty:
                          _sourceMember(projectile)?.statBeauty ??
                          kAbilityStatAverage,
                      now: _elapsed,
                    )
                  : objectiveHeal,
            );
          }
          if (!objectiveOnly) {
            final caster = _sourceCompanion(projectile);
            final g = caster == null ? _sourceGarrison(projectile) : null;
            if (caster != null) {
              caster.currentHp = min(
                caster.maxHp,
                caster.currentHp + power.round(),
              );
            } else if (g != null) {
              g.hp = min(g.maxHp, g.hp + power.round());
            } else if (!_shipDead) {
              shipHealth = min(CosmicGame.shipMaxHealth, shipHealth + power);
            }
          }
          break;
        case AbilityEffectKind.alchemyBonus:
        case AbilityEffectKind.flower:
          break;
        case AbilityEffectKind.buff:
        case AbilityEffectKind.cooldownRefund:
          final sourceMember = _sourceMember(projectile);
          if (sourceMember?.family.toLowerCase() == 'mask' &&
              sourceMember?.element == 'Ice') {
            final ampDuration = CosmicAbilityRuntime.projectileEffectDuration(
              projectile,
              fallbackDuration: 1.5,
            );
            final ampRadius = radius * 1.4;
            for (final comp in _livingActiveCompanions) {
              if ((comp.position - projectile.position).distance > ampRadius) {
                continue;
              }
              comp.damageAmpTimer = max(comp.damageAmpTimer, ampDuration);
              comp.damageAmpMultiplier = max(comp.damageAmpMultiplier, 2.4);
            }
            for (final g in _garrison) {
              if (g.hp <= 0) continue;
              if ((g.position - projectile.position).distance > ampRadius) {
                continue;
              }
              g.damageAmpTimer = max(g.damageAmpTimer, ampDuration);
              g.damageAmpMultiplier = max(g.damageAmpMultiplier, 2.4);
            }
          }
          // Survival's buff: its caster's basic attack hastes for the
          // effect's duration (a Mane Light ring's pierce).
          final hasteFor = CosmicAbilityRuntime.projectileEffectDuration(
            projectile,
          );
          final comp = _sourceCompanion(projectile);
          final g = comp == null ? _sourceGarrison(projectile) : null;
          if (comp != null) {
            comp.basicHasteTimer = max(comp.basicHasteTimer, hasteFor);
            comp.basicHasteMultiplier = min(
              comp.basicHasteMultiplier,
              CosmicAbilityRuntime.buffHasteMultiplier,
            );
            if (effect == AbilityEffectKind.cooldownRefund) {
              comp.specialCooldown = max(0, comp.specialCooldown - 0.45);
            }
          } else if (g != null) {
            g.basicHasteTimer = max(g.basicHasteTimer, hasteFor);
            g.basicHasteMultiplier = min(
              g.basicHasteMultiplier,
              CosmicAbilityRuntime.buffHasteMultiplier,
            );
            if (effect == AbilityEffectKind.cooldownRefund) {
              g.specialCooldown = max(0, g.specialCooldown - 0.45);
            }
          }
          break;
        case AbilityEffectKind.carry:
          // A carry hit pushes the body a little away from the contact.
          final away = enemy.position - from;
          final d = away.distance;
          if (d > 0.01) {
            enemy.position += away / d * CosmicAbilityRuntime.carryHitPush;
          }
          break;
        case AbilityEffectKind.taunt:
        case AbilityEffectKind.none:
          break;
      }
    }

    void spawnDarkLetKillMeteors(Projectile source, Offset center) {
      final count = CosmicAbilityRuntime.darkLetFollowupCount(
        source.letCasterIntelligence,
      );
      final targets = enemies
          .where(
            (enemy) =>
                !enemy.dead &&
                enemy.health > 0 &&
                (enemy.position - center).distance <=
                    max(420.0, source.effectRadius * 3.0),
          )
          .take(count)
          .toList(growable: false);
      for (var mi = 0; mi < count; mi++) {
        final target = mi < targets.length ? targets[mi].position : null;
        final a = target != null
            ? atan2(target.dy - center.dy, target.dx - center.dx)
            : source.angle + (mi - 2) * 0.42;
        // The follow-ups fall too. Per design this is a bombardment, and a
        // volley of sideways meteors next to a parent that dropped from the
        // sky would look like two different abilities. Staggered so they
        // arrive as a rolling barrage rather than one simultaneous thud.
        final aim = target ?? center + Offset(cos(a), sin(a)) * 180.0;
        final drop = letSkyfallDrop(aim, a, timeScale: 0.72 + mi * 0.16);
        companionProjectiles.add(
          Projectile(
            position: drop.position,
            angle: drop.angle,
            element: 'Dark',
            damage: source.damage * 0.7,
            life: drop.duration + 0.4,
            speedMultiplier: 0,
            skyfallDuration: drop.duration,
            skyfallImpact: aim,
            skyfallDistance: drop.distance,
            // Bigger than its parent, per design — the same as survival.
            radiusMultiplier: CosmicAbilityRuntime.darkLetFollowupRadius(
              source,
            ),
            visualScale: CosmicAbilityRuntime.darkLetFollowupVisualScale(
              source,
            ),
            visualStyle: ProjectileVisualStyle.meteor,
            homing: false,
            homingStrength: 2.4,
            sourceSlotIndex: source.sourceSlotIndex,
            abilityFamily: 'let',
            hitEffect: AbilityEffectKind.pull,
            effectPower: source.effectPower * 0.85,
            effectRadius: max(140.0, source.effectRadius),
            effectDuration: source.effectDuration,
            effectStacks: 1,
          ),
        );
      }
    }

    // A Let zone, from the shared table. It carries its effect as a
    // TICK, so the aura pass applies it to everything inside its radius every
    // 0.35s — the same as survival. It used to carry it as a hit effect with
    // no family, which meant contact every frame with a ~14px centre under a
    // 130px drawing: Lava burned only what touched its middle, and a stun
    // piled 3s onto a body per frame.
    void spawnLetZone(
      Projectile source,
      Offset center,
      String element,
      LetZoneSpec spec,
    ) {
      companionProjectiles.add(
        CosmicAbilityRuntime.letZone(source, center, element, spec),
      );
    }

    /// One body taking [amount], dying the way the crater's bodies do.
    void hurtEnemy(CosmicEnemy enemy, double amount) {
      if (enemy.dead || enemy.health <= 0) return;
      enemy.health -= amount;
      if (enemy.health <= 0) {
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
      }
    }

    void damageEnemiesNear(
      Offset center,
      double radius,
      double damage, {
      CosmicEnemy? exclude,
    }) {
      for (final other in enemies) {
        if (other.dead || other.health <= 0 || identical(other, exclude)) {
          continue;
        }
        if ((other.position - center).distance > radius) continue;
        other.health -= damage;
        if (other.health <= 0) {
          other.dead = true;
          _spawnKillVfx(
            other.position,
            elementColor(other.element),
            other.radius,
            false,
          );
          _spawnLootDrops(
            other.position,
            other.element,
            other.shardDrop,
            other.particleDrop,
          );
        }
      }
    }

    void healCompanionOrShip(double amount) {
      if (amount <= 0) return;
      final companions = _livingActiveCompanions.toList(growable: false);
      if (companions.isNotEmpty) {
        for (final comp in companions) {
          comp.currentHp = min(comp.maxHp, comp.currentHp + amount.round());
        }
      } else {
        shipHealth = min(CosmicGame.shipMaxHealth, shipHealth + amount);
      }
    }

    void healAllCompanionsAndShip(double amount) {
      if (amount <= 0) return;
      shipHealth = min(CosmicGame.shipMaxHealth, shipHealth + amount);
      for (final comp in _livingActiveCompanions) {
        comp.currentHp = min(comp.maxHp, comp.currentHp + amount.round());
      }
    }

    // Aura tick for kin wards / escort orbs: a projectile carrying a
    // tickEffect periodically applies it. Support effects (zoneHeal)
    // restore allies once per tick; leech drains enemies in radius and
    // converts it to party healing; every other effect routes through
    // resolveAbilityEffect for each enemy inside effectRadius.
    void applyKinAuraTick(Projectile p) {
      if (tickMaskPlacement(p)) return;
      final radius = p.effectRadius;
      final power = p.effectPower > 0 ? p.effectPower : p.damage * 0.35;
      if (p.tickEffect == AbilityEffectKind.zoneHeal) {
        // A heal zone tends the one ally worst off, as survival's does.
        _healOpenLowestAlly(power);
        return;
      }
      if (p.tickEffect == AbilityEffectKind.blackHole) {
        // Survival's standing black hole: each body inside is drawn in and
        // chipped, and eaten once it is nearly gone.
        final zoneRadius = max(24.0, radius);
        for (final enemy in enemies) {
          if (enemy.dead) continue;
          final dir = p.position - enemy.position;
          final dist = dir.distance;
          if (dist > zoneRadius) continue;
          if (dist > 0.01) {
            enemy.position += (dir / dist) * min(16.0, 340.0 / max(dist, 9.0));
          }
          _damageOpenEnemy(
            enemy,
            enemy.health / enemy.maxHealth <= 0.10
                ? enemy.health + 1
                : p.effectPower * 0.4,
            sourceSlot: p.sourceSlotIndex,
          );
        }
        return;
      }
      if (p.tickEffect == AbilityEffectKind.leech) {
        var drained = 0.0;
        for (final enemy in enemies) {
          if (enemy.dead) continue;
          if ((enemy.position - p.position).distance > radius) continue;
          final before = enemy.health;
          enemy.health -= power;
          drained += before - max(0.0, enemy.health);
          if (enemy.health <= 0 && !enemy.dead) {
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
          }
        }
        healAllCompanionsAndShip(drained * 0.6);
        return;
      }
      for (final enemy in enemies) {
        if (enemy.dead) continue;
        if ((enemy.position - p.position).distance > radius) continue;
        final alive = enemy.health > 0;
        resolveAbilityEffect(p.tickEffect, p, enemy);
        // A zone's kill is its caster's: what any kill sets off (a Mane
        // Plant root, a Spirit kin's wisp), and a Horn zone's kill (a geyser,
        // a burning lane, a quake) pays the cast's kill effect, as in
        // survival.
        if (alive && enemy.health <= 0 && !_isCombatBody(enemy)) {
          _onOpenKill(p.sourceSlotIndex, enemy);
          if (p.abilityFamily == 'horn') _settleHornZoneKill(p, enemy);
        }
      }
    }

    /// Kill-gated: every element here is authored "if the meteor kills". Air
    /// is the one deliberate exception and fires on any hit, because its
    /// knockback is the cast's crowd control. See the survival implementation.
    void resolveLetMeteorImpactAftermath(
      Projectile projectile,
      Offset center, {
      CosmicEnemy? primary,
      required bool killed,
    }) {
      if (!killed && projectile.element != 'Air') return;
      final isMeteorCore = CosmicAbilityRuntime.isLetMeteorCore(projectile);
      final zone = CosmicAbilityRuntime.letKillZone(projectile.element);
      if (zone != null && isMeteorCore) {
        spawnLetZone(projectile, center, projectile.element!, zone);
      }
      switch (projectile.element) {
        case 'Air':
          final reach = CosmicAbilityRuntime.letAirReach(projectile);
          for (final other in enemies) {
            if (other.dead) continue;
            final dir = other.position - center;
            if (dir.distance > reach) continue;
            _knockOpenEnemy(
              other,
              dir,
              340 + projectile.damage * 5.0,
              byMass: true,
            );
          }
          if (isMeteorCore) {
            pushLetFx(_letFx, LetFx.gust(position: center, radius: reach));
          }
          break;
        case 'Plant':
          if (isMeteorCore) {
            for (final spot in CosmicAbilityRuntime.letVineSpots(
              center,
              projectile.angle,
            )) {
              companionProjectiles.add(
                CosmicAbilityRuntime.letVine(projectile, spot),
              );
            }
          }
          break;
        case 'Blood':
          final drain = projectile.damage * 0.22;
          final reach = max(170.0, projectile.effectRadius);
          var drawn = 0;
          for (final other in enemies) {
            if (other.dead || identical(other, primary)) continue;
            if ((other.position - center).distance > reach) continue;
            if (drawn < 8) {
              drawn++;
              pushLetFx(_letFx, LetFx.drain(from: other.position, to: center));
            }
            hurtEnemy(other, drain);
          }
          healAllCompanionsAndShip(drain * 0.18);
          break;
        case 'Fire':
          final reach = CosmicAbilityRuntime.letFireReach(projectile);
          damageEnemiesNear(
            center,
            reach,
            projectile.damage * 0.72,
            exclude: primary,
          );
          pushLetFx(_letFx, LetFx.blast(position: center, radius: reach));
          break;
        case 'Dark':
          if (projectile.effectStacks == 0) {
            spawnDarkLetKillMeteors(projectile, center);
          } else {
            for (final other in enemies) {
              if (other.dead) continue;
              final dir = center - other.position;
              final dist = dir.distance;
              if (dist > 0.01 && dist <= max(120.0, projectile.effectRadius)) {
                other.position += (dir / dist) * min(28.0, 720.0 / dist);
                other.applySlow(0.25, projectile.effectDuration);
              }
            }
          }
          break;
        default:
          break;
      }
    }

    /// Lightning's contact: a chain hopping from the struck body to its
    /// nearest neighbours — survival's chain, not an area burst.
    void chainLetLightning(Projectile projectile, CosmicEnemy from) {
      final hops = max(2, projectile.effectCount);
      final points = <Offset>[from.position];
      final struck = <CosmicEnemy>{from};
      var at = from;
      for (var h = 0; h < hops; h++) {
        CosmicEnemy? next;
        var bestSq = 180.0 * 180.0;
        for (final other in enemies) {
          if (other.dead || other.health <= 0 || struck.contains(other)) {
            continue;
          }
          final d = other.position - at.position;
          final dSq = d.dx * d.dx + d.dy * d.dy;
          if (dSq < bestSq) {
            bestSq = dSq;
            next = other;
          }
        }
        final hop = next;
        if (hop == null) break;
        struck.add(hop);
        points.add(hop.position);
        hurtEnemy(hop, projectile.damage * 0.72);
        at = hop;
      }
      if (points.length > 1) {
        pushLetFx(_letFx, LetFx.chain(points: points));
      }
    }

    void resolveLetMeteorHit(
      Projectile projectile,
      CosmicEnemy enemy, {
      required bool killed,
    }) {
      final element = projectile.element;
      final isMeteorCore = CosmicAbilityRuntime.isLetMeteorCore(projectile);
      final zone = CosmicAbilityRuntime.letContactZone(element);
      if (zone != null && isMeteorCore) {
        spawnLetZone(projectile, enemy.position, element!, zone);
      }
      switch (element) {
        case 'Poison':
          enemy.applySlow(0.72, 2.2);
          enemy.health -= projectile.damage * 0.20;
          break;
        case 'Earth':
          healCompanionOrShip(projectile.damage * 0.26);
          damageEnemiesNear(
            enemy.position,
            max(150, projectile.effectRadius),
            projectile.damage * 0.38,
            exclude: enemy,
          );
          break;
        case 'Spirit':
          if (enemy.health > 0 &&
              (enemy.health / enemy.maxHealth <= 0.35 ||
                  _rng.nextDouble() <= projectile.effectChance) &&
              !_bookExecute(enemy)) {
            enemy.health = 0;
            if (isMeteorCore) {
              pushLetFx(
                _letFx,
                LetFx.soul(position: enemy.position, bodyRadius: enemy.radius),
              );
            }
          } else {
            enemy.health -= projectile.damage * 0.35;
          }
          break;
        case 'Crystal':
          enemy.applySlow(0.10, CosmicAbilityRuntime.kLetCrystalHold);
          enemy.knockbackVelocity = Offset.zero;
          enemy.health -= projectile.damage * 0.25;
          damageEnemiesNear(
            enemy.position,
            max(140, projectile.effectRadius),
            projectile.damage * 0.32,
            exclude: enemy,
          );
          if (isMeteorCore && enemy.health > 0) {
            final held = enemy;
            pushLetFx(
              _letFx,
              LetFx.crystal(
                position: held.position,
                bodyRadius: held.radius,
                duration: CosmicAbilityRuntime.kLetCrystalHold,
                anchor: () =>
                    held.dead || held.health <= 0 ? null : held.position,
              ),
            );
          }
          break;
        case 'Lightning':
          chainLetLightning(projectile, enemy);
          enemy.health -= projectile.damage * 0.18;
          break;
        case 'Ice':
          enemy.applySlow(0.05, CosmicAbilityRuntime.kLetIceHold);
          enemy.knockbackVelocity = Offset.zero;
          if (isMeteorCore && enemy.health > 0) {
            final held = enemy;
            pushLetFx(
              _letFx,
              LetFx.frost(
                position: held.position,
                bodyRadius: held.radius,
                duration: CosmicAbilityRuntime.kLetIceHold,
                anchor: () =>
                    held.dead || held.health <= 0 ? null : held.position,
              ),
            );
          }
          break;
        case 'Water':
          final reach = CosmicAbilityRuntime.letWaterReach(projectile);
          damageEnemiesNear(
            enemy.position,
            reach,
            projectile.damage * 0.42,
            exclude: enemy,
          );
          if (isMeteorCore) {
            pushLetFx(
              _letFx,
              LetFx.splash(position: enemy.position, radius: reach),
            );
          }
          break;
        default:
          break;
      }
      resolveLetMeteorImpactAftermath(
        projectile,
        enemy.position,
        primary: enemy,
        killed: killed || enemy.dead || enemy.health <= 0,
      );
    }

    void resolveAbilityKill(Projectile projectile, CosmicEnemy enemy) {
      if (projectile.abilityFamily == 'let') {
        resolveLetMeteorImpactAftermath(
          projectile,
          enemy.position,
          primary: enemy,
          killed: true,
        );
        return;
      }
      resolveAbilityEffect(
        projectile.killEffect,
        projectile,
        enemy,
        origin: enemy.position,
      );
      _applyOpenKillIdentityHooks(projectile, enemy);
    }

    void resolveAbilityHit(
      Projectile projectile,
      CosmicEnemy enemy, {
      required bool killed,
    }) {
      if (_maskTrapVisuals.contact(projectile)) _soundMaskSpring(projectile);
      if (projectile.abilityFamily == 'let') {
        resolveLetMeteorHit(projectile, enemy, killed: killed);
        return;
      }
      if (!resolveMaskContact(projectile, enemy)) {
        resolveAbilityEffect(projectile.hitEffect, projectile, enemy);
      }
      if (killed) resolveAbilityKill(projectile, enemy);
    }

    void resolveAbilityPierce(Projectile projectile, CosmicEnemy enemy) {
      final id = identityHashCode(enemy);
      if (!projectile.effectHitIds.add(id)) return;
      final slot = projectile.sourceSlotIndex;
      final isMane = projectile.abilityFamily == 'mane';
      if (isMane && projectile.element == 'Air') {
        // Thrown along the shot, still carried by a shove, and slowed.
        final dir = Offset(cos(projectile.angle), sin(projectile.angle));
        enemy.position =
            enemy.position + dir * ManeRuntime.airPushDistance(projectile);
        enemy.knockbackVelocity += dir * ManeRuntime.airShoveSpeed;
        enemy.applySlow(
          ManeRuntime.airSlow,
          ManeRuntime.airSlowDuration(projectile),
        );
        _spawnHitSpark(enemy.position, elementColor('Air'));
        return;
      }
      if (projectile.pierceEffect == AbilityEffectKind.carry) {
        // Dragged along the shot rather than pushed back, and slowed.
        final isManeWaterWall = ManeRuntime.isWaterWall(projectile);
        final dragDistance = isManeWaterWall
            ? ManeRuntime.waterWallDrag(projectile)
            : CosmicAbilityRuntime.maneCarryDistance(projectile.effectPower);
        enemy.position = Offset(
          enemy.position.dx + cos(projectile.angle) * dragDistance,
          enemy.position.dy + sin(projectile.angle) * dragDistance,
        );
        enemy.applySlow(
          isManeWaterWall ? ManeRuntime.waterWallSlow : ManeRuntime.carrySlow,
          projectile.effectDuration +
              (isManeWaterWall ? ManeRuntime.waterWallExtraSlowTime : 0.0),
        );
        if (isManeWaterWall) {
          _spawnHitSpark(enemy.position, elementColor('Water'));
        }
        return;
      }
      if (isMane) {
        switch (projectile.element) {
          case 'Plant':
            // Rooted, and the vine thickens on every body it passes through.
            enemy.maneRootSlot = slot;
            enemy.maneRootTimer = max(
              enemy.maneRootTimer,
              ManeRuntime.plantRootTime,
            );
            enemy.applySlow(0, ManeRuntime.plantRootTime);
            ManeRuntime.growPlantVine(projectile);
            _spawnHitSpark(enemy.position, elementColor('Plant'));
            break;
          case 'Lava':
            if (!ManeRuntime.dropsLavaBlob(projectile)) break;
            companionProjectiles.add(
              ManeRuntime.lavaBlob(projectile, enemy.position),
            );
            break;
          case 'Blood':
            // Every pierce restores what the cast protects.
            _healOpenObjective(
              _healCeiling.grant(
                slot: projectile.sourceSlotIndex,
                amount: ManeRuntime.bloodPierceHeal(projectile).toDouble(),
                pool: CosmicGame.shipMaxHealth,
                beauty:
                    _sourceMember(projectile)?.statBeauty ??
                    kAbilityStatAverage,
                now: _elapsed,
              ),
            );
            _spawnHitSpark(enemy.position, elementColor('Blood'));
            break;
          case 'Poison':
            // Each pierce stacks poison on the body, and the stacked hit
            // lands harder; the generic effect is skipped.
            final (stacks, stackMul) = ManeRuntime.poisonStackStep(
              enemy.manePoisonStacks,
            );
            enemy.manePoisonStacks = stacks;
            final dose = projectile.effectPower * stackMul;
            _damageOpenEnemy(
              enemy,
              dose > 0 ? dose : 4.0,
              element: 'Poison',
              sourceSlot: slot,
            );
            _spawnHitSpark(enemy.position, elementColor('Poison'));
            return;
          case 'Dark':
            // The void bolt eats the nearly-dead it passes through.
            if (enemy.health / enemy.maxHealth <=
                ManeRuntime.darkExecuteFraction) {
              _damageOpenEnemy(
                enemy,
                enemy.health + 1,
                element: 'Dark',
                sourceSlot: slot,
              );
              _spawnHitSpark(enemy.position, elementColor('Dark'));
            }
            break;
        }
      }
      resolveAbilityEffect(
        projectile.pierceEffect,
        projectile,
        enemy,
        origin: enemy.position,
      );
    }

    /// A Let meteor touching down. Full damage to the body it lands on, a
    /// reduced share to everything else in the crater, and the element's
    /// ground effects whether or not anything was standing there.
    void detonateLetSkyfall(Projectile p) {
      final centre = p.skyfallImpact;
      final blast = letSkyfallBlastRadius(p);
      pushLetSkyfallImpact(
        _letSkyfallImpacts,
        LetSkyfallImpact(
          position: centre,
          color: elementColor(p.element ?? 'Fire'),
          element: p.element,
          radius: blast,
        ),
      );
      onSound?.call(
        SoundCue.forLetImpact(
          p.element ?? '',
          barrageChild: p.effectStacks >= 1,
        ),
      );

      CosmicEnemy? primary;
      var bestSq = blast * blast;
      for (final enemy in enemies) {
        if (enemy.dead || enemy.health <= 0) continue;
        final d = enemy.position - centre;
        final dSq = d.dx * d.dx + d.dy * d.dy;
        if (dSq < bestSq) {
          bestSq = dSq;
          primary = enemy;
        }
      }

      final struck = primary;
      // The crater catches everything in it whether or not there was a body at
      // the centre. Routed through damageEnemiesNear so kills keep running the
      // loot and vfx that lives inside it.
      // Who is in the crater before it goes off, so the kill gate counts
      // bodies finished by the splash as well as by the direct hit.
      final inBlast = <CosmicEnemy>[
        for (final enemy in enemies)
          if (!enemy.dead &&
              enemy.health > 0 &&
              (enemy.position - centre).distance <= blast)
            enemy,
      ];
      damageEnemiesNear(
        centre,
        blast,
        p.damage * kLetSkyfallSplashShare,
        exclude: struck,
      );
      if (struck != null) {
        damageEnemiesNear(struck.position, 0.5, p.damage);
        resolveLetMeteorHit(
          p,
          struck,
          killed: inBlast.any((enemy) => enemy.dead || enemy.health <= 0),
        );
      }
      // No aftermath when nothing was struck — those behaviours are kill-gated
      // by design. See the survival implementation.
      p.life = 0;
    }

    for (var i = companionProjectiles.length - 1; i >= 0; i--) {
      final p = companionProjectiles[i];
      var transferringToShip = false;

      // Let meteors fall. A descending meteor takes no collisions, lays no
      // trail and does not age — everything it does happens when it lands.
      if (p.isDescending) {
        final landed = CosmicAbilityRuntime.advanceSkyfall(p, dt);
        if (landed) {
          detonateLetSkyfall(p);
          companionProjectiles.removeAt(i);
        }
        continue;
      }

      // Mane Dark: the slow void bolt drags every body near it in, every
      // frame it flies; it eats the nearly-dead on pierce.
      if (ManeRuntime.pullsInFlight(p)) _pullOpenManeDark(p, dt);

      if (p.transferToShipOrbit && !p.followShipOrbit) {
        if (p.shipOrbitDelay > 0) {
          p.shipOrbitDelay = max(0.0, p.shipOrbitDelay - dt);
        } else {
          transferringToShip = true;
          p.orbitAngle += p.orbitSpeed * dt;
          final desiredPos = Offset(
            ship.pos.dx + cos(p.orbitAngle) * p.orbitRadius,
            ship.pos.dy + sin(p.orbitAngle) * p.orbitRadius,
          );
          final toDesired = desiredPos - p.position;
          final dist = toDesired.distance;
          final attachStep = Projectile.speed * p.shipOrbitTransferSpeed * dt;
          if (dist <= attachStep || dist < 8) {
            p.position = desiredPos;
            p.orbitCenter = ship.pos;
            p.followShipOrbit = true;
            transferringToShip = false;
          } else {
            p.position += (toDesired / dist) * attachStep;
          }
        }
      } else if (p.transferOrbitCenter != null) {
        if (p.shipOrbitDelay > 0) {
          p.shipOrbitDelay = max(0.0, p.shipOrbitDelay - dt);
        } else {
          transferringToShip = true;
          p.orbitAngle += p.orbitSpeed * dt;
          final desiredCenter = p.transferOrbitCenter!;
          final desiredPos = Offset(
            desiredCenter.dx + cos(p.orbitAngle) * p.orbitRadius,
            desiredCenter.dy + sin(p.orbitAngle) * p.orbitRadius,
          );
          final toDesired = desiredPos - p.position;
          final dist = toDesired.distance;
          final attachStep = Projectile.speed * p.shipOrbitTransferSpeed * dt;
          if (dist <= attachStep || dist < 8) {
            p.position = desiredPos;
            p.orbitCenter = desiredCenter;
            p.transferOrbitCenter = null;
            transferringToShip = false;
          } else {
            p.position += (toDesired / dist) * attachStep;
          }
        }
      }

      if (p.followShipOrbit) {
        p.orbitCenter = ship.pos;
      }

      // Homing: steer toward nearest enemy
      if (p.homing) {
        double bestDist = double.infinity;
        Offset? bestTarget;
        for (final e in enemies) {
          if (e.dead) continue;
          final d = (e.position - p.position).distance;
          if (d < bestDist) {
            bestDist = d;
            bestTarget = e.position;
          }
        }
        if (activeBoss != null) {
          final bd = (activeBoss!.position - p.position).distance;
          if (bd < bestDist) {
            bestTarget = activeBoss!.position;
          }
        }
        if (bestTarget != null) {
          final desired = atan2(
            bestTarget.dy - p.position.dy,
            bestTarget.dx - p.position.dx,
          );
          // Shortest-arc turn
          double diff = desired - p.angle;
          while (diff > pi) {
            diff -= 2 * pi;
          }
          while (diff < -pi) {
            diff += 2 * pi;
          }
          final maxTurn = p.homingStrength * dt;
          p.angle += diff.clamp(-maxTurn, maxTurn);
        }
      }

      if (_updateOpenManeLightningOrbTransfer(p, dt)) {
        transferringToShip = true;
      }

      final pSpeed = Projectile.speed * p.speedMultiplier;

      // Orbital projectiles: orbit their center before launching
      if (!transferringToShip &&
          p.orbitCenter != null &&
          (p.holdOrbit || p.orbitTime > 0)) {
        if (!p.holdOrbit) {
          p.orbitTime -= dt;
        }
        p.orbitAngle += p.orbitSpeed * dt;
        p.position = Offset(
          p.orbitCenter!.dx + cos(p.orbitAngle) * p.orbitRadius,
          p.orbitCenter!.dy + sin(p.orbitAngle) * p.orbitRadius,
        );
        if (p.turretInterval > 0 &&
            (!p.transferToShipOrbit || p.followShipOrbit) &&
            p.transferOrbitCenter == null) {
          p.turretTimer += dt;
          if (p.turretTimer >= p.turretInterval) {
            p.turretTimer -= p.turretInterval;
            final target = _nearestEscortTarget(p.position);
            if (target != null) {
              companionProjectiles.add(_createEscortTurretShot(p, target));
            }
          }
        }
        // When orbit time expires, launch outward
        if (!p.holdOrbit && p.orbitTime <= 0) {
          p.angle = p.orbitAngle; // launch in current orbital direction
          p.orbitCenter = null; // stop orbiting
        }
      } else if (p.stationary) {
        // Stationary projectiles don't move (mines, lingering clouds)
        // no position change
        if (p.abilityFamily == 'mask') {
          _fireMaskTurret(p, dt);
        } else if (p.turretInterval > 0) {
          p.turretTimer += dt;
          if (p.turretTimer >= p.turretInterval) {
            p.turretTimer -= p.turretInterval;
            final target = _nearestEscortTarget(p.position);
            if (target != null) {
              companionProjectiles.add(_createEscortTurretShot(p, target));
            }
          }
        }
      } else if (!transferringToShip) {
        p.position = Offset(
          p.position.dx + cos(p.angle) * pSpeed * dt,
          p.position.dy + sin(p.angle) * pSpeed * dt,
        );
        // Mane Dust paints a trailing dust line as it flies.
        if (ManeRuntime.shedsDustPuffs(p)) {
          p.trailTimer += dt;
          if (p.trailTimer >= ManeRuntime.dustPuffInterval) {
            p.trailTimer = 0;
            if (ManeRuntime.dustTrailHasRoom(companionProjectiles)) {
              companionProjectiles.add(ManeRuntime.dustTrailPuff(p));
            }
          }
        }
        if (p.turretInterval > 0 &&
            p.visualStyle == ProjectileVisualStyle.mysticOrbital &&
            p.element == 'Lava') {
          p.turretTimer += dt;
          while (p.turretTimer >= p.turretInterval) {
            p.turretTimer -= p.turretInterval;
            companionProjectiles.add(
              Projectile(
                position: p.position,
                angle: 0,
                element: 'Lava',
                damage: 0,
                life: 8.5,
                speedMultiplier: 0,
                stationary: true,
                piercing: true,
                radiusMultiplier: 1.8,
                visualScale: 1.7,
                visualStyle: ProjectileVisualStyle.mysticOrbital,
                sourceSlotIndex: p.sourceSlotIndex,
                abilityFamily: 'mystic',
                tickEffect: AbilityEffectKind.burn,
                effectPower: p.turretDamage,
                effectRadius: 70,
                effectDuration: 1.6,
                snareRadius: 70,
                snareMoveMultiplier: 0.65,
              ),
            );
          }
        }
        if (p.turretInterval > 0 && p.abilityFamily == 'mane') {
          if (p.element == 'Earth') {
            p.turretTimer += dt;
            while (p.turretTimer >= p.turretInterval) {
              p.turretTimer -= p.turretInterval;
              _spawnOpenManeEarthQuakePulse(p);
            }
            ManeRuntime.earthShrink(p, dt);
          } else if (p.element == 'Steam') {
            p.turretTimer += dt;
            while (p.turretTimer >= p.turretInterval) {
              p.turretTimer -= p.turretInterval;
              companionProjectiles.add(ManeRuntime.steamPuff(p));
            }
          }
        }
      }
      // Trail-dropping: spawn stationary residue projectiles periodically,
      // credited to the caster, and — a source that generates itself — only
      // while the list has room for what the player actually cast.
      if (p.trailInterval > 0 &&
          !p.stationary &&
          p.orbitCenter == null &&
          companionProjectiles.length < CosmicGame._trailProjectileCeiling) {
        p.trailTimer += dt;
        if (p.trailTimer >= p.trailInterval) {
          p.trailTimer -= p.trailInterval;
          companionProjectiles.add(
            Projectile(
              position: p.position,
              angle: 0,
              element: p.element,
              damage: p.trailDamage,
              life: p.trailLife,
              stationary: true,
              radiusMultiplier: 1.5,
              piercing: true,
              visualScale: 1.2,
              sourceSlotIndex: p.sourceSlotIndex,
              abilityFamily: p.abilityFamily,
              hitEffect: p.tickEffect == AbilityEffectKind.none
                  ? p.hitEffect
                  : p.tickEffect,
              tickEffect: p.tickEffect,
              effectPower: p.effectPower * 0.55,
              effectRadius: p.effectRadius,
              effectDuration: p.effectDuration,
            ),
          );
        }
      }

      // Kin ward aura tick: stationary ward placements and kin orbiting
      // escort orbs emanate their tickEffect to enemies/allies in radius
      // on a fixed cadence (mirrors survival's updatePersistentAbilityEffects).
      final isKinOrbitingAura =
          p.abilityFamily == 'kin' &&
          (p.holdOrbit ||
              p.transferToShipOrbit ||
              p.transferOrbitCenter != null);
      if (p.tickEffect != AbilityEffectKind.none &&
          p.effectRadius > 0 &&
          (p.stationary || isKinOrbitingAura)) {
        p.tickTimer += dt;
        if (p.tickTimer >= 0.35) {
          // Survival's traps drop the remainder, so theirs tick a frame
          // behind the exact beat.
          p.tickTimer = p.abilityFamily == 'mask' ? 0 : p.tickTimer - 0.35;
          applyKinAuraTick(p);
        }
        // Ambient per-element wisps so the painted zone feels alive (embers,
        // bubbles, rain, etc.). Pool-capped so it never floods the frame.
        // Only a zone on the ground sheds them, as survival's do; a Kin's
        // orbiting aura ticks without them.
        if (p.stationary && _abilityVfx.length < 130) {
          _spawnZoneParticles(p);
        }
      }
      // A Horn piece's own trail — Spirit's phantoms, Crystal's shards, the
      // Light barrier's storm — on top of any zone wisps, as survival runs.
      if (p.abilityFamily == 'horn' && _abilityVfx.length < 130) {
        emitHornProjectileParticles(p, _rng, _hornParticle);
      }

      // Cluster fragmentation: split into sub-projectiles at half-life
      if (p.clusterCount > 0 && !p.clustered) {
        // Estimate initial life by checking if we're past halfway
        // We trigger when remaining life < 50% of original
        // Since we don't store original life, trigger when life < 0.75s for meteors
        if (p.life < 0.75) {
          p.clustered = true;
          for (var ci = 0; ci < p.clusterCount; ci++) {
            final ca = ci * (pi * 2 / p.clusterCount);
            companionProjectiles.add(
              Projectile(
                position: Offset(
                  p.position.dx + cos(ca) * 10,
                  p.position.dy + sin(ca) * 10,
                ),
                angle: ca,
                element: p.element,
                damage: p.clusterDamage,
                life: 1.5,
                speedMultiplier: 0.7,
                radiusMultiplier: 1.5,
                piercing: true,
                visualScale: 1.0,
                visualStyle: p.visualStyle == ProjectileVisualStyle.letShard
                    ? ProjectileVisualStyle.letShard
                    : ProjectileVisualStyle.standard,
                sourceSlotIndex: p.sourceSlotIndex,
                abilityFamily: p.abilityFamily,
                hitEffect: p.hitEffect,
                killEffect: p.killEffect,
                pierceEffect: p.pierceEffect,
                tickEffect: p.tickEffect,
                effectPower: p.effectPower * 0.65,
                effectRadius: p.effectRadius,
                effectDuration: p.effectDuration,
                effectCount: p.effectCount,
              ),
            );
          }
        }
      }

      p.life -= dt;
      if (p.life <= 0) {
        if (p.decoy && p.deathExplosionCount > 0) {
          _spawnDecoyExplosion(p);
        }
        companionProjectiles.removeAt(i);
        continue;
      }

      // Kin Plant's garden grows a flower every few seconds.
      if (isKinGarden(p)) _growOpenKinGarden(p, dt);

      final hitRadius = Projectile.radius * p.radiusMultiplier;
      bool consumed = false;

      // Decoys/taunt traps resolve damage through the dedicated
      // enemy->decoy collision path so they persist as lures.
      if (p.decoy) {
        continue;
      }

      // Let's ground never collides. Its zones act through their tick (the
      // aura pass above), and a vine strikes the first body in its reach and
      // is spent.
      if (p.stationary && p.abilityFamily == 'let') {
        if (CosmicAbilityRuntime.isLetVine(p)) {
          for (final enemy in enemies) {
            if (enemy.dead || enemy.health <= 0) continue;
            final reach = p.effectRadius + enemy.radius;
            final d = enemy.position - p.position;
            if (d.dx * d.dx + d.dy * d.dy > reach * reach) continue;
            pushLetFx(_letFx, LetFx.lash(from: p.position, to: enemy.position));
            hurtEnemy(enemy, p.effectPower);
            companionProjectiles.removeAt(i);
            break;
          }
        }
        continue;
      }
      // An unbounded re-hitter touches on a fixed 60 Hz clock, not per frame
      // (see `Projectile.takeContactTick`).
      if (!p.takeContactTick(dt)) continue;

      // Hit enemies
      for (var ei = enemies.length - 1; ei >= 0; ei--) {
        if (p.trapSpent) break;
        final enemy = enemies[ei];
        if (enemy.dead) continue;
        final edx = p.position.dx - enemy.position.dx;
        final edy = p.position.dy - enemy.position.dy;
        final hitR = enemy.radius + hitRadius;
        if (edx * edx + edy * edy < hitR * hitR) {
          // Contact is re-tested every frame, so a piercing projectile's
          // per-body ceiling is what stops it billing a standing body once a
          // frame. Survival applies it to every projectile.
          if (p.abilityFamily == 'mask' && p.stationary) p.maxHitsPerEnemy = 1;
          final hitId = identityHashCode(enemy);
          if (!p.canHitEnemy(hitId)) continue;
          p.noteEnemyHit(hitId);
          // A piercing projectile hits every body for its full damage, as
          // survival's do.
          final preRootForPlantKill =
              p.piercing && p.abilityFamily == 'mane' && p.element == 'Plant';
          if (preRootForPlantKill) resolveAbilityPierce(p, enemy);
          final wasAlive = enemy.health > 0 && !enemy.dead;
          enemy.health -= p.damage;
          final killedByBase = wasAlive && enemy.health <= 0;
          resolveAbilityHit(p, enemy, killed: killedByBase);
          if (p.piercing) resolveAbilityPierce(p, enemy);
          _applyOpenBasicHitIdentityHooks(p, enemy, killed: enemy.health <= 0);
          // Mane Mud: the first body struck splits it into ten fragments.
          if (ManeRuntime.shattersOnHit(p)) {
            p.clustered = true;
            onSound?.call(SoundCue.specialManeBurst);
            companionProjectiles.addAll(
              ManeRuntime.mudShards(p, enemy.position),
            );
            consumed = true;
          }
          // A trap sparks in its own color, as Survival's do.
          _spawnHitSpark(
            p.position,
            elementColor(
              p.abilityFamily == 'mask' ? (p.element ?? 'Fire') : enemy.element,
            ),
          );
          if (!enemy.provoked &&
              (enemy.behavior == EnemyBehavior.feeding ||
                  enemy.behavior == EnemyBehavior.territorial ||
                  enemy.behavior == EnemyBehavior.drifting)) {
            _provokePackOf(enemy);
          }
          // Chain lightning off the struck body — what a Kin Lightning tesla
          // channel grants every companion basic while it holds.
          if (p.chainLightningCharges > 0 && _openKinLightningActive) {
            _chainOpenLightning(
              enemy,
              p.damage,
              p.chainLightningCharges,
              p.sourceSlotIndex,
            );
          }
          // Ricochet (Pip), as Survival chains it: the next body within 110
          // of the struck one, never one across the screen; each bounce sheds
          // damage and a little speed. Only the moving dart is spent by
          // running out — Pip's parked puffs, pools and lines are not darts.
          final isPipSpecialProjectile =
              p.abilityFamily == 'pip' &&
              p.visualStyle == ProjectileVisualStyle.dart;
          if (!consumed && p.bounceCount > 0) {
            p.bounceCount--;
            if (isPipSpecialProjectile) p.pierceCount++;
            CosmicEnemy? next;
            var bestSq = 110.0 * 110.0;
            for (final other in enemies) {
              if (other.dead || identical(other, enemy)) continue;
              final d = other.position - enemy.position;
              final dSq = d.dx * d.dx + d.dy * d.dy;
              if (dSq < bestSq) {
                bestSq = dSq;
                next = other;
              }
            }
            if (next != null) {
              if (isPipSpecialProjectile) {
                onSound?.call(SoundCue.specialPipRicochet);
              }
              p.angle = atan2(
                next.position.dy - p.position.dy,
                next.position.dx - p.position.dx,
              );
              p.life = isPipSpecialProjectile
                  ? min(max(p.life, 0.18), kPipRicochetPostHitLife)
                  : max(p.life, 0.45);
              p.damage *= p.element == 'Lightning' ? 0.85 : 0.70;
              p.speedMultiplier = max(0.6, p.speedMultiplier * 0.92);
            } else {
              p.bounceCount = 0;
              if (isPipSpecialProjectile) consumed = true;
            }
          } else if (!consumed && !p.piercing) {
            consumed = true;
          } else if (!consumed) {
            p.pierceCount++;
            if (isPipSpecialProjectile && p.pierceCount >= kPipMaxPierceHits) {
              consumed = true;
            }
          }
          if (enemy.health <= 0 && !enemy.dead) {
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
            // What any kill sets off, when the hit's own kill path (a base
            // kill resolved through the identity hooks) did not already.
            if (!killedByBase || p.abilityFamily == 'let') {
              _onOpenKill(p.sourceSlotIndex, enemy);
            }
          }
          if (consumed) break;
        }
      }
      if (consumed) {
        companionProjectiles.removeAt(i);
        continue;
      }

      if (p.trapSpent) continue;
      // Hit boss
      if (i < companionProjectiles.length && activeBoss != null) {
        final cp = companionProjectiles[i];
        if (!cp.hitBoss) {
          final boss = activeBoss!;
          final bdx = cp.position.dx - boss.position.dx;
          final bdy = cp.position.dy - boss.position.dy;
          if (bdx * bdx + bdy * bdy <
              (boss.radius + hitRadius) * (boss.radius + hitRadius)) {
            // Every projectile strikes the boss at full weight however many
            // bodies it has already touched, as Survival's do.
            final isCrystalmaneBossHit =
                cp.abilityFamily == 'mane' && cp.element == 'Crystal';
            if (isCrystalmaneBossHit) {
              onSound?.call(SoundCue.specialManeShatter);
              boss.shieldUp = false;
              boss.shieldHealth = 0;
              _damageOpenFoesNear(
                boss.position,
                ManeRuntime.crystalBossBlastRadius,
                cp.damage * ManeRuntime.crystalBossBlastShare,
                sourceSlot: cp.sourceSlotIndex,
                element: 'Crystal',
              );
              _damageOpenBoss(boss.health + 1, element: 'Crystal');
              _spawnHitSpark(boss.position, elementColor('Crystal'));
              companionProjectiles.removeAt(i);
              continue;
            }
            if (cp.abilityFamily == 'mask') {
              _activateMaskContactPlacement(cp, boss.position, flash: false);
              if (cp.trapSpent && _maskTrapVisuals.contact(cp)) {
                _soundMaskSpring(cp);
              }
            }
            final bossDamage = cp.damage;
            if (boss.shieldUp &&
                (boss.type == BossType.gunner ||
                    boss.type == BossType.bulwark)) {
              boss.shieldHealth -= bossDamage;
              _spawnHitSpark(cp.position, Colors.cyanAccent);
              if (boss.shieldHealth <= 0) {
                boss.shieldUp = false;
                boss.shieldTimer = CosmicBoss.shieldCooldown;
              }
            } else {
              boss.health -= bossDamage;
              _spawnHitSpark(
                cp.position,
                elementColor(
                  cp.abilityFamily == 'mask'
                      ? (cp.element ?? 'Fire')
                      : boss.element,
                ),
              );
              if (boss.health <= 0) {
                _handleBossKill(boss);
              }
            }
            if (cp.piercing && cp.abilityFamily != 'pip') {
              cp.pierceCount++;
              cp.hitBoss = true;
            } else {
              companionProjectiles.removeAt(i);
            }
          }
        }
      }
    }
  }
}
