import 'dart:math';
import 'dart:ui';

import 'package:alchemons/games/survival/components/alchemy_projectile.dart';
import 'package:alchemons/games/survival/components/survival_attacks.dart';
import 'package:alchemons/games/survival/survival_combat.dart';
import 'package:alchemons/games/survival/survival_creature_sprite.dart';
import 'package:alchemons/games/survival/enemies/survival_enemies.dart';
import 'package:alchemons/games/survival/survival_game.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

/// LET FAMILY - METEOR MECHANIC (CREATIVE RANK 3 PATTERNS)
/// Rank 0: no special
/// Rank 1: basic meteor unlocked
/// Rank 2: stronger meteor (bigger radius / damage)
/// Rank 3+: ELEMENT-SPECIFIC APOCALYPTIC PATTERNS!
class LetMeteorMechanic {
  static void execute(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
    String element,
  ) {
    // Force to int so it can be passed everywhere safely
    final int rank = game
        .getSpecialAbilityRank(attacker.unit.id, element)
        .clamp(1, 3)
        .toInt();

    // ✨ RANK 3: UNIQUE ELEMENTAL METEOR PATTERNS!
    if (rank >= 3) {
      _executeRank3Apocalypse(game, attacker, target, element);
      return;
    }

    // Ranks 1-2: Standard single meteor
    _executeStandardMeteor(game, attacker, target, element, rank);
  }

  /// Standard meteor for Rank 1-2
  static void _executeStandardMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
    String element,
    int rank,
  ) {
    final color = SurvivalAttackManager.getElementColor(element);
    final baseRadius = 100.0 + rank * 20;
    final baseDmg = (calcDmg(attacker, target) * (1.5 + 0.3 * rank)).toInt();
    final radius = baseRadius;
    final damage = baseDmg;

    final impactPos = target.position.clone();
    final startPos = impactPos + Vector2(0, -400);

    final meteor = CircleComponent(
      radius: 25,
      position: startPos,
      anchor: Anchor.center,
      paint: Paint()..color = color,
    );

    meteor.add(
      TimerComponent(
        period: 0.03,
        repeat: true,
        onTick: () {
          game.world.add(
            CircleComponent(
              radius: 12,
              position: meteor.position.clone(),
              anchor: Anchor.center,
              paint: Paint()..color = color.withOpacity(0.4),
            )..add(
              SequenceEffect([
                ScaleEffect.to(
                  Vector2.all(0.3),
                  EffectController(duration: 0.3),
                ),
                RemoveEffect(),
              ]),
            ),
          );
        },
      ),
    );

    meteor.add(
      MoveEffect.to(
        impactPos,
        EffectController(duration: 0.4, curve: Curves.easeIn),
        onComplete: () {
          meteor.removeFromParent();
          SurvivalAttackManager.triggerScreenShake(game, 6.0);

          final victims = game.getEnemiesInRange(impactPos, radius);
          for (final v in victims) {
            final dist = v.position.distanceTo(impactPos);
            final falloff = 1.0 - (dist / radius) * 0.4;
            v.takeDamage((damage * falloff).toInt());
            ImpactVisuals.play(game, v.position, element, scale: 0.9);
          }

          ImpactVisuals.playExplosion(game, impactPos, element, radius);

          if (rank >= 1) {
            // ✅ Fixed names + removed non-existent `damage` arg
            _applyElementalMeteor(
              game: game,
              attacker: attacker,
              element: element,
              rank: rank,
              center: impactPos,
              radius: radius,
              enemiesHit: victims,
            );
          }
        },
      ),
    );

    game.world.add(meteor);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  RANK 3 APOCALYPTIC PATTERNS - ELEMENT-SPECIFIC CREATIVITY!
  // ═══════════════════════════════════════════════════════════════════════════

  static void _executeRank3Apocalypse(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
    String element,
  ) {
    switch (element) {
      case 'Fire':
        _fireMeteorShower(game, attacker, target);
        break;
      case 'Lava':
        _lavaVolcanicBombardment(game, attacker, target);
        break;
      case 'Ice':
        _iceCometCluster(game, attacker, target);
        break;
      case 'Lightning':
        _lightningOrbitalStrike(game, attacker, target);
        break;
      case 'Earth':
        _earthMoonDrop(game, attacker, target);
        break;
      case 'Crystal':
        _crystalStarfall(game, attacker, target);
        break;
      case 'Dark':
        _darkVoidMeteor(game, attacker, target);
        break;
      case 'Light':
        _lightCelestialRain(game, attacker, target);
        break;
      case 'Poison':
        _poisonToxicStorm(game, attacker, target);
        break;
      case 'Plant':
        _plantSeedBombardment(game, attacker, target);
        break;
      case 'Water':
        _waterDelugeSurge(game, attacker, target);
        break;
      case 'Steam':
        _steamGeyserField(game, attacker, target);
        break;
      case 'Blood':
        _bloodSanguineRain(game, attacker, target);
        break;
      case 'Mud':
        _mudMireQuake(game, attacker, target);
        break;
      case 'Dust':
        _dustHaboob(game, attacker, target);
        break;
      case 'Air':
        _airAtmosphericBomb(game, attacker, target);
        break;
      case 'Spirit':
        _spiritSoulHarvest(game, attacker, target);
        break;
      default:
        // Fallback to huge single meteor
        _massiveSingleMeteor(game, attacker, target, element);
    }
  }

  /// 🔥 FIRE - Meteor Shower (5 smaller meteors in quick succession)
  static void _fireMeteorShower(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
  ) {
    final color = SurvivalAttackManager.getElementColor('Fire');
    final baseDamage = (calcDmg(attacker, target) * 1.2).toInt();

    // Find 5 impact positions in a cluster
    final centerPos = target.position.clone();
    final positions = <Vector2>[
      centerPos,
      centerPos + Vector2(80, 60),
      centerPos + Vector2(-70, 50),
      centerPos + Vector2(50, -80),
      centerPos + Vector2(-60, -70),
    ];

    for (int i = 0; i < 5; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (attacker.isDead) return;

        final impactPos = positions[i];
        final startPos =
            impactPos + Vector2(Random().nextDouble() * 100 - 50, -450);
        final meteor = CircleComponent(
          radius: 20,
          position: startPos,
          anchor: Anchor.center,
          paint: Paint()..color = color,
        );

        // Trail
        meteor.add(
          TimerComponent(
            period: 0.025,
            repeat: true,
            onTick: () {
              game.world.add(
                CircleComponent(
                  radius: 10,
                  position: meteor.position.clone(),
                  anchor: Anchor.center,
                  paint: Paint()..color = color.withOpacity(0.5),
                )..add(
                  SequenceEffect([
                    ScaleEffect.to(
                      Vector2.all(0.2),
                      EffectController(duration: 0.25),
                    ),
                    RemoveEffect(),
                  ]),
                ),
              );
            },
          ),
        );

        meteor.add(
          MoveEffect.to(
            impactPos,
            EffectController(duration: 0.35, curve: Curves.easeIn),
            onComplete: () {
              meteor.removeFromParent();
              SurvivalAttackManager.triggerScreenShake(game, 4.0);

              final victims = game.getEnemiesInRange(impactPos, 100);
              for (final v in victims) {
                v.takeDamage(baseDamage);
                // Ignite all hit enemies
                v.unit.applyStatusEffect(
                  SurvivalStatusEffect(
                    type: 'Burn',
                    damagePerTick: (baseDamage * 0.2).toInt(),
                    ticksRemaining: 6,
                    tickInterval: 0.5,
                  ),
                );
              }
              ImpactVisuals.playExplosion(game, impactPos, 'Fire', 100);
            },
          ),
        );

        game.world.add(meteor);
      });
    }
  }

  /// 🌋 LAVA - Volcanic Bombardment (random meteors across entire screen for 3 seconds)
  static void _lavaVolcanicBombardment(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
  ) {
    final color = SurvivalAttackManager.getElementColor('Lava');
    final baseDamage = (calcDmg(attacker, target) * 0.8).toInt();
    final rng = Random();

    // 15 meteors over 3 seconds at random positions
    for (int i = 0; i < 15; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (attacker.isDead) return;

        // Random position near enemies
        final enemies = game.getEnemiesInRange(game.orb.position, 600);
        Vector2 impactPos;

        if (enemies.isNotEmpty) {
          final randomEnemy = enemies[rng.nextInt(enemies.length)];
          impactPos =
              randomEnemy.position +
              Vector2(rng.nextDouble() * 80 - 40, rng.nextDouble() * 80 - 40);
        } else {
          impactPos =
              game.orb.position +
              Vector2(
                rng.nextDouble() * 400 - 200,
                rng.nextDouble() * 400 - 200,
              );
        }

        final startPos = impactPos + Vector2(0, -400);
        final meteor = CircleComponent(
          radius: 18,
          position: startPos,
          anchor: Anchor.center,
          paint: Paint()..color = color,
        );

        meteor.add(
          MoveEffect.to(
            impactPos,
            EffectController(duration: 0.3, curve: Curves.easeIn),
            onComplete: () {
              meteor.removeFromParent();

              final victims = game.getEnemiesInRange(impactPos, 90);
              for (final v in victims) {
                v.takeDamage(baseDamage);
                // Knockback
                final dir = (v.position - impactPos).normalized();
                v.add(
                  MoveEffect.by(dir * 50, EffectController(duration: 0.15)),
                );
              }
              ImpactVisuals.playExplosion(game, impactPos, 'Lava', 90);
            },
          ),
        );

        game.world.add(meteor);
      });
    }

    SurvivalAttackManager.triggerScreenShake(game, 8.0);
  }

  /// ❄️ ICE - Comet Cluster (3 large comets that leave freezing zones)
  static void _iceCometCluster(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
  ) {
    final color = SurvivalAttackManager.getElementColor('Ice');
    final baseDamage = (calcDmg(attacker, target) * 1.5).toInt();

    final centerPos = target.position.clone();
    final positions = [
      centerPos,
      centerPos + Vector2(120, 0),
      centerPos + Vector2(-120, 0),
    ];

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 300), () {
        if (attacker.isDead) return;

        final impactPos = positions[i];
        final startPos = impactPos + Vector2(0, -500);
        final meteor = CircleComponent(
          radius: 30,
          position: startPos,
          anchor: Anchor.center,
          paint: Paint()..color = color,
        );

        meteor.add(
          MoveEffect.to(
            impactPos,
            EffectController(duration: 0.5, curve: Curves.easeIn),
            onComplete: () {
              meteor.removeFromParent();
              SurvivalAttackManager.triggerScreenShake(game, 7.0);

              final victims = game.getEnemiesInRange(impactPos, 140);
              for (final v in victims) {
                v.takeDamage(baseDamage);
              }
              ImpactVisuals.playExplosion(game, impactPos, 'Ice', 140);

              // Leave freezing zone for 4 seconds
              final freezeZone = CircleComponent(
                radius: 140,
                position: impactPos,
                anchor: Anchor.center,
                paint: Paint()..color = color.withOpacity(0.2),
              );

              freezeZone.add(
                TimerComponent(
                  period: 0.3,
                  repeat: true,
                  onTick: () {
                    final zoneVictims = game.getEnemiesInRange(impactPos, 140);
                    for (final v in zoneVictims) {
                      // Slow/push away from orb
                      final pushDir = (v.position - game.orb.position)
                          .normalized();
                      v.position += pushDir * 15;
                    }
                  },
                ),
              );

              freezeZone.add(RemoveEffect(delay: 4.0));
              game.world.add(freezeZone);
            },
          ),
        );

        game.world.add(meteor);
      });
    }
  }

  /// ⚡ LIGHTNING - Orbital Strike (fast consecutive strikes at different targets)
  static void _lightningOrbitalStrike(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
  ) {
    final color = SurvivalAttackManager.getElementColor('Lightning');
    final baseDamage = (calcDmg(attacker, target) * 1.3).toInt();

    // Hit 8 different enemies
    final enemies = game
        .getEnemiesInRange(game.orb.position, 700)
        .take(8)
        .toList();
    if (enemies.isEmpty) return;

    for (int i = 0; i < enemies.length; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (attacker.isDead) return;

        final targetEnemy = enemies[i];
        if (targetEnemy.isDead) return;

        final impactPos = targetEnemy.position.clone();
        final startPos = impactPos + Vector2(0, -600);

        // Lightning bolt (very fast)
        final bolt = CircleComponent(
          radius: 15,
          position: startPos,
          anchor: Anchor.center,
          paint: Paint()..color = color,
        );

        bolt.add(
          MoveEffect.to(
            impactPos,
            EffectController(duration: 0.15, curve: Curves.linear),
            onComplete: () {
              bolt.removeFromParent();

              targetEnemy.takeDamage(baseDamage);

              // Chain to nearby enemies
              final nearby = game
                  .getEnemiesInRange(impactPos, 150)
                  .where((e) => e != targetEnemy)
                  .take(3);
              for (final n in nearby) {
                game.spawnAlchemyProjectile(
                  start: impactPos,
                  target: n,
                  damage: (baseDamage * 0.6).toInt(),
                  color: color,
                  shape: ProjectileShape.bolt,
                  speed: 6.0,
                  isEnemy: false,
                  onHit: () {
                    if (!n.isDead) {
                      n.takeDamage((baseDamage * 0.6).toInt());
                      ImpactVisuals.play(
                        game,
                        n.position,
                        'Lightning',
                        scale: 0.6,
                      );
                    }
                  },
                );
              }

              ImpactVisuals.playExplosion(game, impactPos, 'Lightning', 80);
            },
          ),
        );

        game.world.add(bolt);
      });
    }

    SurvivalAttackManager.triggerScreenShake(game, 6.0);
  }

  /// 🌍 EARTH - Moon Drop (ONE MASSIVE meteor, huge radius)
  static void _earthMoonDrop(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
  ) {
    final color = SurvivalAttackManager.getElementColor('Earth');
    final baseDamage = (calcDmg(attacker, target) * 2.5).toInt();

    final impactPos = target.position.clone();
    final startPos = impactPos + Vector2(0, -700);

    // HUGE meteor
    final meteor = CircleComponent(
      radius: 60,
      position: startPos,
      anchor: Anchor.center,
      paint: Paint()..color = color,
    );

    // Thick trail
    meteor.add(
      TimerComponent(
        period: 0.02,
        repeat: true,
        onTick: () {
          game.world.add(
            CircleComponent(
              radius: 35,
              position: meteor.position.clone(),
              anchor: Anchor.center,
              paint: Paint()..color = color.withOpacity(0.4),
            )..add(
              SequenceEffect([
                ScaleEffect.to(
                  Vector2.all(0.3),
                  EffectController(duration: 0.4),
                ),
                RemoveEffect(),
              ]),
            ),
          );
        },
      ),
    );

    meteor.add(
      MoveEffect.to(
        impactPos,
        EffectController(duration: 0.6, curve: Curves.easeIn),
        onComplete: () {
          meteor.removeFromParent();
          SurvivalAttackManager.triggerScreenShake(game, 15.0);

          // MASSIVE radius
          final victims = game.getEnemiesInRange(impactPos, 250);
          for (final v in victims) {
            final dist = v.position.distanceTo(impactPos);
            final falloff = 1.0 - (dist / 250) * 0.3;
            v.takeDamage((baseDamage * falloff).toInt());

            // Huge knockback
            final dir = (v.position - impactPos).normalized();
            v.add(MoveEffect.by(dir * 120, EffectController(duration: 0.3)));
          }

          ImpactVisuals.playExplosion(game, impactPos, 'Earth', 250);

          // Shockwave particles
          game.world.add(
            ParticleSystemComponent(
              position: impactPos,
              particle: Particle.generate(
                count: 30,
                lifespan: 1.0,
                generator: (i) {
                  final angle = (i / 30.0) * pi * 2;
                  return AcceleratedParticle(
                    speed: Vector2(cos(angle) * 200, sin(angle) * 200),
                    child: CircleParticle(
                      radius: 8,
                      paint: Paint()..color = color,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );

    game.world.add(meteor);
  }

  /// 💎 CRYSTAL - Starfall (grid pattern of small meteors)
  static void _crystalStarfall(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
  ) {
    final color = SurvivalAttackManager.getElementColor('Crystal');
    final baseDamage = (calcDmg(attacker, target) * 0.9).toInt();

    // 3x3 grid of meteors
    final centerPos = target.position.clone();
    final gridPositions = <Vector2>[];

    for (int x = -1; x <= 1; x++) {
      for (int y = -1; y <= 1; y++) {
        gridPositions.add(centerPos + Vector2(x * 100.0, y * 100.0));
      }
    }

    for (int i = 0; i < gridPositions.length; i++) {
      Future.delayed(Duration(milliseconds: i * 80), () {
        if (attacker.isDead) return;

        final impactPos = gridPositions[i];
        final startPos = impactPos + Vector2(0, -400);

        final meteor = CircleComponent(
          radius: 15,
          position: startPos,
          anchor: Anchor.center,
          paint: Paint()..color = color,
        );

        meteor.add(
          MoveEffect.to(
            impactPos,
            EffectController(duration: 0.35, curve: Curves.easeIn),
            onComplete: () {
              meteor.removeFromParent();

              final victims = game.getEnemiesInRange(impactPos, 70);
              for (final v in victims) {
                v.takeDamage(baseDamage);
              }
              ImpactVisuals.playExplosion(game, impactPos, 'Crystal', 70);
            },
          ),
        );

        game.world.add(meteor);
      });
    }

    SurvivalAttackManager.triggerScreenShake(game, 6.0);
  }

  /// 🌑 DARK - Void Meteor (sucks enemies in, then explodes)
  static void _darkVoidMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
  ) {
    final color = SurvivalAttackManager.getElementColor('Dark');
    final baseDamage = (calcDmg(attacker, target) * 2.2).toInt();

    final impactPos = target.position.clone();
    final startPos = impactPos + Vector2(0, -500);

    final meteor = CircleComponent(
      radius: 40,
      position: startPos,
      anchor: Anchor.center,
      paint: Paint()..color = color,
    );

    meteor.add(
      MoveEffect.to(
        impactPos,
        EffectController(duration: 0.45, curve: Curves.easeIn),
        onComplete: () {
          meteor.removeFromParent();

          // Void zone appears
          final voidZone = CircleComponent(
            radius: 50,
            position: impactPos,
            anchor: Anchor.center,
            paint: Paint()..color = color.withOpacity(0.7),
          );
          voidZone.add(
            ScaleEffect.to(Vector2.all(3.5), EffectController(duration: 1.5)),
          );
          game.world.add(voidZone);

          // Pull enemies in for 1.5 seconds
          for (int i = 0; i < 15; i++) {
            Future.delayed(Duration(milliseconds: i * 100), () {
              final victims = game.getEnemiesInRange(impactPos, 300);
              for (final v in victims) {
                final toVoid = (impactPos - v.position);
                final dist = toVoid.length;
                if (dist > 10) {
                  v.position += toVoid.normalized() * min(dist * 0.25, 30.0);
                }
              }
            });
          }

          // EXPLOSION
          Future.delayed(const Duration(milliseconds: 1500), () {
            voidZone.removeFromParent();
            SurvivalAttackManager.triggerScreenShake(game, 12.0);

            final victims = game.getEnemiesInRange(impactPos, 180);
            for (final v in victims) {
              v.takeDamage(baseDamage);
              // Execute low HP
              if (!v.isBoss && v.unit.hpPercent < 0.3) {
                v.takeDamage(99999);
              }
            }
            ImpactVisuals.playExplosion(game, impactPos, 'Dark', 180);
          });
        },
      ),
    );

    game.world.add(meteor);
  }

  /// ☠️ POISON - Toxic Storm (random poison meteors + huge lingering cloud)
  static void _poisonToxicStorm(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
  ) {
    final color = SurvivalAttackManager.getElementColor('Poison');
    final rng = Random();

    // Base damage / poison scaled off attacker
    final baseHitDamage = (calcDmg(attacker, target) * 0.7).toInt();
    final poisonPerTick = (attacker.unit.statIntelligence * 1.4).toInt().clamp(
      5,
      120,
    );
    const poisonTickInterval = 0.5;
    const poisonTicks = 8;

    // Spawn ~10 toxic meteors around the target / orb region
    final Vector2 center = target.position.clone();
    const int meteorCount = 10;

    for (int i = 0; i < meteorCount; i++) {
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (attacker.isDead) return;

        // Random impact around center
        final offset = Vector2(
          rng.nextDouble() * 260 - 130,
          rng.nextDouble() * 260 - 130,
        );
        final impactPos = center + offset;
        final startPos = impactPos + Vector2(0, -420);

        final meteor = CircleComponent(
          radius: 18,
          position: startPos,
          anchor: Anchor.center,
          paint: Paint()..color = color,
        );

        meteor.add(
          MoveEffect.to(
            impactPos,
            EffectController(duration: 0.4, curve: Curves.easeIn),
            onComplete: () {
              meteor.removeFromParent();
              SurvivalAttackManager.triggerScreenShake(game, 3.0);

              // Direct impact damage
              final victims = game.getEnemiesInRange(impactPos, 80);
              for (final v in victims) {
                v.takeDamage(baseHitDamage);

                // Apply strong poison on hit
                v.unit.applyStatusEffect(
                  SurvivalStatusEffect(
                    type: 'Poison',
                    damagePerTick: poisonPerTick,
                    ticksRemaining: poisonTicks,
                    tickInterval: poisonTickInterval,
                  ),
                );
              }

              ImpactVisuals.playExplosion(game, impactPos, 'Poison', 80);
            },
          ),
        );

        game.world.add(meteor);
      });
    }

    // Big lingering toxic cloud over the main center
    final cloudRadius = 220.0;
    final cloudDuration = 4.0;
    final cloud = CircleComponent(
      radius: cloudRadius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()..color = color.withOpacity(0.25),
    );

    // Periodically re-apply weaker poison inside the cloud
    final cloudTickDamage = (poisonPerTick * 0.6).toInt().clamp(
      2,
      poisonPerTick,
    );
    cloud.add(
      TimerComponent(
        period: 0.7,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(center, cloudRadius);
          for (final v in victims) {
            v.unit.applyStatusEffect(
              SurvivalStatusEffect(
                type: 'Poison',
                damagePerTick: cloudTickDamage,
                ticksRemaining: 3,
                tickInterval: 0.5,
              ),
            );
          }
        },
      ),
    );

    cloud.add(RemoveEffect(delay: cloudDuration));
    game.world.add(cloud);

    SurvivalAttackManager.triggerScreenShake(game, 7.0);
  }

  /// 🌱 PLANT - Seed Bombardment (multiple seed meteors that grow thorn gardens)
  static void _plantSeedBombardment(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
  ) {
    final color = SurvivalAttackManager.getElementColor('Plant');
    final rng = Random();

    final Vector2 center = target.position.clone();

    // Each seed impact will create a plant "garden" using similar logic
    // to _plantMeteor (thorn damage + slow + healing at rank 3)
    const int seedCount = 6;
    const double gardenRadius = 130.0;
    const double baseImpactRadius = 70.0;

    final int thornDps = (attacker.unit.statIntelligence * 1.6).toInt().clamp(
      5,
      120,
    );
    final double slowStrength = 12.0;
    const double gardenDuration = 4.5;

    for (int i = 0; i < seedCount; i++) {
      Future.delayed(Duration(milliseconds: i * 220), () {
        if (attacker.isDead) return;

        // Scatter seeds around the initial target
        final offset = Vector2(
          rng.nextDouble() * 260 - 130,
          rng.nextDouble() * 260 - 130,
        );
        final impactPos = center + offset;
        final startPos = impactPos + Vector2(0, -430);

        final seed = CircleComponent(
          radius: 16,
          position: startPos,
          anchor: Anchor.center,
          paint: Paint()..color = color,
        );

        // Cute leaf trail
        seed.add(
          TimerComponent(
            period: 0.03,
            repeat: true,
            onTick: () {
              game.world.add(
                CircleComponent(
                  radius: 8,
                  position: seed.position.clone(),
                  anchor: Anchor.center,
                  paint: Paint()..color = color.withOpacity(0.5),
                )..add(
                  SequenceEffect([
                    ScaleEffect.to(
                      Vector2.all(0.4),
                      EffectController(duration: 0.25),
                    ),
                    RemoveEffect(),
                  ]),
                ),
              );
            },
          ),
        );

        seed.add(
          MoveEffect.to(
            impactPos,
            EffectController(duration: 0.45, curve: Curves.easeIn),
            onComplete: () {
              seed.removeFromParent();
              SurvivalAttackManager.triggerScreenShake(game, 3.5);

              // Immediate impact damage + small knockback
              final impactVictims = game.getEnemiesInRange(
                impactPos,
                baseImpactRadius,
              );
              for (final v in impactVictims) {
                final hitDmg = (calcDmg(attacker, v) * 0.9).toInt().clamp(
                  5,
                  200,
                );
                v.takeDamage(hitDmg);

                final dir = (v.position - impactPos).normalized();
                v.add(
                  MoveEffect.by(
                    dir * 40,
                    EffectController(duration: 0.2, curve: Curves.easeOut),
                  ),
                );
              }

              ImpactVisuals.playExplosion(game, impactPos, 'Plant', 80);

              // Grow a thorn garden at the impact spot
              final garden = CircleComponent(
                radius: gardenRadius,
                position: impactPos,
                anchor: Anchor.center,
                paint: Paint()..color = Colors.green.withOpacity(0.28),
              );

              garden.add(
                TimerComponent(
                  period: 0.45,
                  repeat: true,
                  onTick: () {
                    final victims = game.getEnemiesInRange(
                      impactPos,
                      gardenRadius,
                    );
                    for (final v in victims) {
                      v.takeDamage(thornDps);
                      final pushBack =
                          (v.targetOrb.position - v.position).normalized() *
                          -slowStrength;
                      v.position += pushBack;
                    }

                    // Minor heal to guardians standing in the garden
                    final allies = game.getGuardiansInRange(
                      center: impactPos,
                      range: gardenRadius,
                    );
                    final allyHeal = (thornDps * 0.4).toInt().clamp(3, 120);
                    for (final g in allies) {
                      g.unit.heal(allyHeal);
                      ImpactVisuals.playHeal(game, g.position, scale: 0.5);
                    }
                  },
                ),
              );

              garden.add(RemoveEffect(delay: gardenDuration));
              game.world.add(garden);
            },
          ),
        );

        game.world.add(seed);
      });
    }

    SurvivalAttackManager.triggerScreenShake(game, 6.0);
  }

  /// ☀️ LIGHT - Celestial Rain (healing + damaging rain)
  static void _lightCelestialRain(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
  ) {
    final color = SurvivalAttackManager.getElementColor('Light');
    final baseDamage = (calcDmg(attacker, target) * 1.0).toInt();

    // explicitly int so heal() calls are happy
    final int healAmount = (attacker.unit.statBeauty * 8).toInt().clamp(
      30,
      200,
    );

    // 12 meteors that heal allies and damage enemies
    for (int i = 0; i < 12; i++) {
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (attacker.isDead) return;

        final enemies = game.getEnemiesInRange(game.orb.position, 500);
        Vector2 impactPos;

        if (enemies.isNotEmpty) {
          impactPos = enemies[Random().nextInt(enemies.length)].position;
        } else {
          impactPos =
              game.orb.position +
              Vector2(
                Random().nextDouble() * 300 - 150,
                Random().nextDouble() * 300 - 150,
              );
        }

        final startPos = impactPos + Vector2(0, -450);
        final meteor = CircleComponent(
          radius: 18,
          position: startPos,
          anchor: Anchor.center,
          paint: Paint()..color = color,
        );

        meteor.add(
          MoveEffect.to(
            impactPos,
            EffectController(duration: 0.35, curve: Curves.easeIn),
            onComplete: () {
              meteor.removeFromParent();

              // Damage enemies
              final victims = game.getEnemiesInRange(impactPos, 90);
              for (final v in victims) {
                v.takeDamage(baseDamage);
              }

              // Heal allies in range
              final allies = game.getGuardiansInRange(
                center: impactPos,
                range: 120,
              );
              for (final ally in allies) {
                ally.unit.heal(healAmount);
                ImpactVisuals.playHeal(game, ally.position, scale: 0.6);
              }

              ImpactVisuals.playExplosion(game, impactPos, 'Light', 90);
            },
          ),
        );

        game.world.add(meteor);
      });
    }

    SurvivalAttackManager.triggerScreenShake(game, 5.0);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  RANK 3 APOCALYPTIC ULTIMATES — ADDITIONAL ELEMENTS
  // ═══════════════════════════════════════════════════════════════════════════

  /// 💧 WATER - Deluge Surge (4 staggered tidal waves, healing + heavy push)
  static void _waterDelugeSurge(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
  ) {
    final baseDamage = (calcDmg(attacker, target) * 1.4).toInt();
    final center = target.position.clone();
    final int healAmount = (attacker.unit.statIntelligence * 4).toInt().clamp(
      10,
      180,
    );

    for (int i = 0; i < 4; i++) {
      Future.delayed(Duration(milliseconds: i * 280), () {
        if (attacker.isDead) return;
        final wavePos = center + Vector2((i - 1.5) * 80, 0);
        final waveRadius = 130.0 + i * 25;

        final victims = game.getEnemiesInRange(wavePos, waveRadius);
        for (final v in victims) {
          v.takeDamage(baseDamage);
          final pushDir = (v.position - game.orb.position).normalized();
          v.add(
            MoveEffect.by(
              pushDir * (100 + i * 20),
              EffectController(duration: 0.3, curve: Curves.easeOut),
            ),
          );
        }

        final allies = game.getGuardiansInRange(
          center: wavePos,
          range: waveRadius * 1.3,
        );
        for (final g in allies) {
          g.unit.heal(healAmount);
          ImpactVisuals.playHeal(game, g.position, scale: 0.7);
        }
        game.orb.heal((healAmount * 0.5).toInt());
        ImpactVisuals.playExplosion(game, wavePos, 'Water', waveRadius);
      });
    }
    SurvivalAttackManager.triggerScreenShake(game, 7.0);
  }

  /// 🌫️ STEAM - Geyser Field (7 eruptions in ring + center with steam patches)
  static void _steamGeyserField(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
  ) {
    final baseDamage = (calcDmg(attacker, target) * 1.3).toInt();
    final color = SurvivalAttackManager.getElementColor('Steam');
    final center = target.position.clone();

    final geyserPositions = <Vector2>[
      center.clone(),
      ...List.generate(6, (i) {
        final angle = (i / 6.0) * pi * 2;
        return center + Vector2(cos(angle) * 130, sin(angle) * 130);
      }),
    ];

    for (int i = 0; i < geyserPositions.length; i++) {
      final gpos = geyserPositions[i].clone();
      Future.delayed(Duration(milliseconds: i * 140), () {
        if (attacker.isDead) return;

        game.world.add(
          CircleComponent(
            radius: 35,
            position: gpos,
            anchor: Anchor.center,
            paint: Paint()
              ..color = color.withOpacity(0.45)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3,
          )..add(
            SequenceEffect([
              ScaleEffect.to(Vector2.all(1.3), EffectController(duration: 0.1)),
              OpacityEffect.fadeOut(EffectController(duration: 0.1)),
              RemoveEffect(),
            ]),
          ),
        );

        Future.delayed(const Duration(milliseconds: 120), () {
          final victims = game.getEnemiesInRange(gpos, 70);
          for (final v in victims) {
            v.takeDamage(baseDamage);
            final jitterDir = Vector2(
              Random().nextDouble() - 0.5,
              Random().nextDouble() - 0.5,
            ).normalized();
            v.add(
              MoveEffect.by(
                jitterDir * 70,
                EffectController(duration: 0.2, curve: Curves.easeOut),
              ),
            );
            v.unit.applyStatusEffect(
              SurvivalStatusEffect(
                type: 'Burn',
                damagePerTick: (baseDamage * 0.1).toInt().clamp(2, 30),
                ticksRemaining: 4,
                tickInterval: 0.5,
              ),
            );
          }
          ImpactVisuals.playExplosion(game, gpos, 'Steam', 70);

          final patch = CircleComponent(
            radius: 50,
            position: gpos,
            anchor: Anchor.center,
            paint: Paint()..color = color.withOpacity(0.25),
          );
          patch.add(
            TimerComponent(
              period: 0.4,
              repeat: true,
              onTick: () {
                for (final v in game.getEnemiesInRange(gpos, 50)) {
                  v.takeDamage(max(1, baseDamage ~/ 10));
                }
              },
            ),
          );
          patch.add(RemoveEffect(delay: 4.0));
          game.world.add(patch);
        });
      });
    }
    SurvivalAttackManager.triggerScreenShake(game, 6.0);
  }

  /// 🩸 BLOOD - Sanguine Rain (8 blood meteors, stolen HP split to all guardians)
  static void _bloodSanguineRain(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
  ) {
    final baseDamage = (calcDmg(attacker, target) * 1.1).toInt();
    final color = SurvivalAttackManager.getElementColor('Blood');
    final center = target.position.clone();
    final rng = Random();

    for (int i = 0; i < 8; i++) {
      const spread = 200.0;
      final impactPos =
          center +
          Vector2(
            rng.nextDouble() * spread - spread / 2,
            rng.nextDouble() * spread - spread / 2,
          );
      final startPos = impactPos + Vector2(rng.nextDouble() * 80 - 40, -500);

      Future.delayed(Duration(milliseconds: i * 160), () {
        if (attacker.isDead) return;
        final meteor = CircleComponent(
          radius: 18,
          position: startPos,
          anchor: Anchor.center,
          paint: Paint()..color = color,
        );
        meteor.add(
          TimerComponent(
            period: 0.03,
            repeat: true,
            onTick: () {
              game.world.add(
                CircleComponent(
                  radius: 8,
                  position: meteor.position.clone(),
                  anchor: Anchor.center,
                  paint: Paint()..color = color.withOpacity(0.5),
                )..add(
                  SequenceEffect([
                    ScaleEffect.to(
                      Vector2.all(0.2),
                      EffectController(duration: 0.3),
                    ),
                    RemoveEffect(),
                  ]),
                ),
              );
            },
          ),
        );
        meteor.add(
          MoveEffect.to(
            impactPos,
            EffectController(duration: 0.38, curve: Curves.easeIn),
            onComplete: () {
              meteor.removeFromParent();
              SurvivalAttackManager.triggerScreenShake(game, 3.0);
              final victims = game.getEnemiesInRange(impactPos, 100);
              int totalDrained = 0;
              for (final v in victims) {
                v.takeDamage(baseDamage);
                totalDrained += baseDamage;
              }
              ImpactVisuals.playExplosion(game, impactPos, 'Blood', 100);

              if (totalDrained > 0) {
                final guardianCount = max(1, game.guardians.length);
                final healPerGuardian = max(1, totalDrained ~/ guardianCount);
                for (final g in game.guardians) {
                  if (!g.isDead) {
                    g.unit.heal(healPerGuardian);
                    ImpactVisuals.playHeal(game, g.position, scale: 0.5);
                  }
                }
                game.orb.heal(max(1, totalDrained ~/ 8));
              }
            },
          ),
        );
        game.world.add(meteor);
      });
    }
  }

  /// 🟤 MUD - Mire Quake (giant persistent slow swamp that pulls enemies in)
  static void _mudMireQuake(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
  ) {
    final color = SurvivalAttackManager.getElementColor('Mud');
    final baseDamage = (calcDmg(attacker, target) * 2.0).toInt();
    final impactPos = target.position.clone();
    final startPos = impactPos + Vector2(0, -600);

    final meteor = CircleComponent(
      radius: 55,
      position: startPos,
      anchor: Anchor.center,
      paint: Paint()..color = color,
    );
    meteor.add(
      TimerComponent(
        period: 0.025,
        repeat: true,
        onTick: () {
          game.world.add(
            CircleComponent(
              radius: 28,
              position: meteor.position.clone(),
              anchor: Anchor.center,
              paint: Paint()..color = color.withOpacity(0.35),
            )..add(
              SequenceEffect([
                ScaleEffect.to(
                  Vector2.all(0.4),
                  EffectController(duration: 0.4),
                ),
                RemoveEffect(),
              ]),
            ),
          );
        },
      ),
    );
    meteor.add(
      MoveEffect.to(
        impactPos,
        EffectController(duration: 0.55, curve: Curves.easeIn),
        onComplete: () {
          meteor.removeFromParent();
          SurvivalAttackManager.triggerScreenShake(game, 12.0);

          final victims = game.getEnemiesInRange(impactPos, 210);
          for (final v in victims) {
            v.takeDamage(baseDamage);
          }
          ImpactVisuals.playExplosion(game, impactPos, 'Mud', 210);

          // Giant mire zone that pulls enemies inward
          const swampRadius = 180.0;
          const swampDuration = 6.0;
          final swamp = CircleComponent(
            radius: swampRadius,
            position: impactPos,
            anchor: Anchor.center,
            paint: Paint()..color = color.withOpacity(0.3),
          );
          swamp.add(
            TimerComponent(
              period: 0.4,
              repeat: true,
              onTick: () {
                for (final v in game.getEnemiesInRange(
                  impactPos,
                  swampRadius,
                )) {
                  final pullDir = (impactPos - v.position).normalized();
                  v.add(
                    MoveEffect.by(
                      pullDir * 18,
                      EffectController(duration: 0.2),
                    ),
                  );
                  v.unit.applyStatusEffect(
                    SurvivalStatusEffect(
                      type: 'Slow',
                      damagePerTick: 0,
                      ticksRemaining: 2,
                      tickInterval: 0.4,
                    ),
                  );
                }
              },
            ),
          );
          swamp.add(RemoveEffect(delay: swampDuration));
          game.world.add(swamp);
        },
      ),
    );
    game.world.add(meteor);
  }

  /// 🌪️ DUST - Haboob (massive sandstorm, blinding randomised confusion for 3.5s)
  static void _dustHaboob(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
  ) {
    final color = SurvivalAttackManager.getElementColor('Dust');
    final baseDamage = (calcDmg(attacker, target) * 1.8).toInt();
    final impactPos = target.position.clone();
    final startPos = impactPos + Vector2(0, -500);

    final meteor = CircleComponent(
      radius: 45,
      position: startPos,
      anchor: Anchor.center,
      paint: Paint()..color = color,
    );
    meteor.add(
      TimerComponent(
        period: 0.03,
        repeat: true,
        onTick: () {
          game.world.add(
            CircleComponent(
              radius: 22,
              position: meteor.position.clone(),
              anchor: Anchor.center,
              paint: Paint()..color = color.withOpacity(0.4),
            )..add(
              SequenceEffect([
                ScaleEffect.to(
                  Vector2.all(0.3),
                  EffectController(duration: 0.35),
                ),
                RemoveEffect(),
              ]),
            ),
          );
        },
      ),
    );
    meteor.add(
      MoveEffect.to(
        impactPos,
        EffectController(duration: 0.5, curve: Curves.easeIn),
        onComplete: () {
          meteor.removeFromParent();
          SurvivalAttackManager.triggerScreenShake(game, 9.0);

          final victims = game.getEnemiesInRange(impactPos, 230);
          for (final v in victims) {
            v.takeDamage(baseDamage);
          }
          ImpactVisuals.playExplosion(game, impactPos, 'Dust', 230);

          const stormRadius = 200.0;
          final rng = Random();
          final storm = CircleComponent(
            radius: stormRadius,
            position: impactPos,
            anchor: Anchor.center,
            paint: Paint()..color = color.withOpacity(0.2),
          );
          storm.add(
            TimerComponent(
              period: 0.15,
              repeat: true,
              onTick: () {
                for (final v in game.getEnemiesInRange(
                  impactPos,
                  stormRadius,
                )) {
                  final jitter = Vector2(
                    rng.nextDouble() * 80 - 40,
                    rng.nextDouble() * 80 - 40,
                  );
                  v.add(MoveEffect.by(jitter, EffectController(duration: 0.1)));
                }
              },
            ),
          );
          storm.add(RemoveEffect(delay: 3.5));
          game.world.add(storm);
        },
      ),
    );
    game.world.add(meteor);
  }

  /// 💨 AIR - Atmospheric Bomb (3 expanding shockwave rings, massive radial scatter)
  static void _airAtmosphericBomb(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
  ) {
    final color = SurvivalAttackManager.getElementColor('Air');
    final baseDamage = (calcDmg(attacker, target) * 2.2).toInt();
    final impactPos = target.position.clone();

    for (int wave = 0; wave < 3; wave++) {
      Future.delayed(Duration(milliseconds: wave * 200), () {
        if (attacker.isDead) return;
        const waveRadius = 280.0;
        final victims = game.getEnemiesInRange(impactPos, waveRadius);
        for (final v in victims) {
          final dist = v.position.distanceTo(impactPos);
          final falloff = (1.0 - dist / waveRadius).clamp(0.2, 1.0);
          v.takeDamage((baseDamage * falloff * (0.6 + 0.2 * wave)).toInt());
          final dir = (v.position - impactPos).normalized();
          v.add(
            MoveEffect.by(
              dir * (180 + wave * 40),
              EffectController(duration: 0.35, curve: Curves.easeOut),
            ),
          );
        }
        game.world.add(
          CircleComponent(
            radius: 10,
            position: impactPos,
            anchor: Anchor.center,
            paint: Paint()
              ..color = color.withOpacity(0.7)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5,
          )..add(
            SequenceEffect([
              ScaleEffect.to(
                Vector2.all(waveRadius / 10),
                EffectController(duration: 0.35),
              ),
              OpacityEffect.fadeOut(EffectController(duration: 0.15)),
              RemoveEffect(),
            ]),
          ),
        );
      });
    }
    SurvivalAttackManager.triggerScreenShake(game, 14.0);
  }

  /// 👻 SPIRIT - Soul Harvest (5 soul meteors, delayed coordinated detonation + group heal)
  static void _spiritSoulHarvest(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
  ) {
    final baseDamage = (calcDmg(attacker, target) * 1.0).toInt();
    final color = SurvivalAttackManager.getElementColor('Spirit');
    final center = target.position.clone();
    final rng = Random();

    for (int i = 0; i < 5; i++) {
      final impactPos =
          center +
          Vector2(rng.nextDouble() * 160 - 80, rng.nextDouble() * 160 - 80);
      final startPos = impactPos + Vector2(rng.nextDouble() * 60 - 30, -480);

      Future.delayed(Duration(milliseconds: i * 220), () {
        if (attacker.isDead) return;
        final meteor = CircleComponent(
          radius: 22,
          position: startPos,
          anchor: Anchor.center,
          paint: Paint()..color = color,
        );
        meteor.add(
          TimerComponent(
            period: 0.03,
            repeat: true,
            onTick: () {
              game.world.add(
                CircleComponent(
                  radius: 10,
                  position: meteor.position.clone(),
                  anchor: Anchor.center,
                  paint: Paint()..color = color.withOpacity(0.45),
                )..add(
                  SequenceEffect([
                    ScaleEffect.to(
                      Vector2.all(0.2),
                      EffectController(duration: 0.3),
                    ),
                    RemoveEffect(),
                  ]),
                ),
              );
            },
          ),
        );
        meteor.add(
          MoveEffect.to(
            impactPos,
            EffectController(duration: 0.42, curve: Curves.easeIn),
            onComplete: () {
              meteor.removeFromParent();
              SurvivalAttackManager.triggerScreenShake(game, 4.0);

              final victims = game.getEnemiesInRange(impactPos, 110);
              for (final v in victims) {
                v.takeDamage(baseDamage ~/ 2);
                // Delayed soul detonation per marked enemy
                Future.delayed(const Duration(milliseconds: 1400), () {
                  if (v.isDead) return;
                  final detonDmg = (baseDamage * 1.5).toInt();
                  v.takeDamage(detonDmg);
                  ImpactVisuals.playExplosion(game, v.position, 'Spirit', 80);
                  final guardianCount = max(1, game.guardians.length);
                  final healAmt = max(1, detonDmg ~/ guardianCount);
                  for (final g in game.guardians) {
                    if (!g.isDead) g.unit.heal(healAmt);
                  }
                  game.orb.heal(max(1, detonDmg ~/ 6));
                });
              }
              ImpactVisuals.playExplosion(game, impactPos, 'Spirit', 110);
            },
          ),
        );
        game.world.add(meteor);
      });
    }
  }

  /// Fallback massive single meteor
  static void _massiveSingleMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
    String element,
  ) {
    final color = SurvivalAttackManager.getElementColor(element);
    final damage = (calcDmg(attacker, target) * 2.4).toInt();
    final impactPos = target.position.clone();
    final startPos = impactPos + Vector2(0, -550);

    final meteor = CircleComponent(
      radius: 45,
      position: startPos,
      anchor: Anchor.center,
      paint: Paint()..color = color,
    );

    meteor.add(
      MoveEffect.to(
        impactPos,
        EffectController(duration: 0.5, curve: Curves.easeIn),
        onComplete: () {
          meteor.removeFromParent();
          SurvivalAttackManager.triggerScreenShake(game, 10.0);

          final victims = game.getEnemiesInRange(impactPos, 200);
          for (final v in victims) {
            v.takeDamage(damage);
          }
          ImpactVisuals.playExplosion(game, impactPos, element, 200);
        },
      ),
    );

    game.world.add(meteor);
  }

  //
  //  ELEMENT ROUTER
  //

  static void _applyElementalMeteor({
    required SurvivalHoardGame game,
    required HoardGuardian attacker,
    required String element,
    required int rank,
    required Vector2 center,
    required double radius,
    required List<HoardEnemy> enemiesHit,
  }) {
    switch (element) {
      // 🔥 FIRE / LAVA / BLOOD
      case 'Fire':
        _fireMeteor(game, attacker, rank, center, radius);
        break;
      case 'Lava':
        _lavaMeteor(game, attacker, rank, center, radius, enemiesHit);
        break;
      case 'Blood':
        _bloodMeteor(game, attacker, rank, center, enemiesHit);
        break;

      // 💧 WATER / ICE / STEAM
      case 'Water':
        _waterMeteor(game, attacker, rank, center, radius, enemiesHit);
        break;
      case 'Ice':
        _iceMeteor(game, attacker, rank, center, radius, enemiesHit);
        break;
      case 'Steam':
        _steamMeteor(game, attacker, rank, center, radius, enemiesHit);
        break;

      // 🌿 PLANT / POISON
      case 'Plant':
        _plantMeteor(game, attacker, rank, center, radius);
        break;
      case 'Poison':
        _poisonMeteor(game, attacker, rank, center, radius, enemiesHit);
        break;

      // 🌍 EARTH / MUD / CRYSTAL
      case 'Earth':
        _earthMeteor(game, attacker, rank, center, radius, enemiesHit);
        break;
      case 'Mud':
        _mudMeteor(game, attacker, rank, center, radius);
        break;
      case 'Crystal':
        _crystalMeteor(game, attacker, rank, center, radius, enemiesHit);
        break;

      // 🌬️ AIR / DUST / LIGHTNING
      case 'Air':
        _airMeteor(game, attacker, rank, center, radius, enemiesHit);
        break;
      case 'Dust':
        _dustMeteor(game, attacker, rank, center, radius, enemiesHit);
        break;
      case 'Lightning':
        _lightningMeteor(game, attacker, rank, center, radius, enemiesHit);
        break;

      // 🌗 SPIRIT / DARK / LIGHT
      case 'Spirit':
        _spiritMeteor(game, attacker, rank, center, enemiesHit);
        break;
      case 'Dark':
        _darkMeteor(game, attacker, rank, center, enemiesHit);
        break;
      case 'Light':
        _lightMeteor(game, attacker, rank, center, radius);
        break;

      default:
        break;
    }
  }

  //
  //  FIRE / LAVA / BLOOD
  //

  /// Fire Meteor - Leaves burning crater that damages over time
  static void _fireMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final burnRadius = radius * 0.8;
    final duration = 3.0 + 0.5 * rank;

    final int dps = (attacker.unit.statIntelligence * (2.0 + 0.3 * rank))
        .toInt()
        .clamp(5, 200);

    final fireZone = CircleComponent(
      radius: burnRadius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.deepOrange.withOpacity(0.3)
        ..style = PaintingStyle.fill,
    );

    fireZone.add(
      TimerComponent(
        period: 0.5,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(center, burnRadius);
          for (final v in victims) {
            v.takeDamage(dps);
            ImpactVisuals.play(game, v.position, 'Fire', scale: 0.4);
          }
        },
      ),
    );

    fireZone.add(RemoveEffect(delay: duration));
    game.world.add(fireZone);

    // Rank 3: Heal from burning enemies
    if (rank >= 3) {
      final heal = (dps * 0.3).toInt();
      attacker.unit.heal(heal);
    }
  }

  /// Lava Meteor - Massive damage with knockback and molten pool
  static void _lavaMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    // Knockback all hit enemies
    for (final v in victims) {
      final dir = (v.position - center).normalized();
      v.add(
        MoveEffect.by(
          dir * (80.0 + 15.0 * rank),
          EffectController(duration: 0.2, curve: Curves.easeOut),
        ),
      );
    }

    // Leave molten pool
    final poolRadius = radius * 0.6;
    final duration = 2.5 + 0.3 * rank;
    final int poolDps = (attacker.unit.statIntelligence * (1.5 + 0.2 * rank))
        .toInt()
        .clamp(3, 150);

    final lavaPool = CircleComponent(
      radius: poolRadius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.orange.shade800.withOpacity(0.4),
    );

    lavaPool.add(
      TimerComponent(
        period: 0.4,
        repeat: true,
        onTick: () {
          final poolVictims = game.getEnemiesInRange(center, poolRadius);
          for (final v in poolVictims) {
            v.takeDamage(poolDps);
          }
        },
      ),
    );

    lavaPool.add(RemoveEffect(delay: duration));
    game.world.add(lavaPool);
  }

  /// Blood Meteor - Heavy lifesteal from all enemies hit
  static void _bloodMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    List<HoardEnemy> victims,
  ) {
    final int drainPerEnemy = (calcDmg(attacker, null) * (0.3 + 0.08 * rank))
        .toInt()
        .clamp(5, 200);

    int totalDrain = 0;
    for (final v in victims) {
      v.takeDamage(drainPerEnemy);
      totalDrain += drainPerEnemy;
      ImpactVisuals.play(game, v.position, 'Blood', scale: 0.8);
    }

    // Heal attacker and orb
    final selfHeal = (totalDrain * (0.4 + 0.1 * rank)).toInt();
    final orbHeal = (totalDrain * (0.2 + 0.05 * rank)).toInt();
    attacker.unit.heal(selfHeal);
    game.orb.heal(orbHeal);

    ImpactVisuals.playHeal(game, attacker.position);

    // Rank 3: Also heal nearby guardians
    if (rank >= 3) {
      final nearbyGuardians = game.getGuardiansInRange(
        center: center,
        range: 200,
      );
      for (final g in nearbyGuardians) {
        g.unit.heal((selfHeal * 0.3).toInt());
      }
    }
  }

  //
  //  WATER / ICE / STEAM
  //

  /// Water Meteor - Tidal wave that pushes enemies back and heals allies
  static void _waterMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    // Push enemies away from orb
    for (final v in victims) {
      final pushDir = (v.position - game.orb.position).normalized();
      v.add(
        MoveEffect.by(
          pushDir * (60.0 + 12.0 * rank),
          EffectController(duration: 0.25, curve: Curves.easeOut),
        ),
      );
    }

    // Heal allies in range
    final int healAmount = (attacker.unit.statIntelligence * (2.0 + 0.4 * rank))
        .toInt()
        .clamp(5, 150);

    final nearbyGuardians = game.getGuardiansInRange(
      center: center,
      range: radius,
    );
    for (final g in nearbyGuardians) {
      g.unit.heal(healAmount);
      ImpactVisuals.playHeal(game, g.position, scale: 0.6);
    }

    // Heal orb if in range
    if (game.orb.position.distanceTo(center) <= radius) {
      game.orb.heal(healAmount);
    }
  }

  /// Ice Meteor - Freezing impact that heavily slows and creates ice field
  static void _iceMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    // Create ice field
    final iceRadius = radius * 0.9;
    final duration = 4.0 + 0.5 * rank;
    final slowStrength = 15.0 + 3.0 * rank;

    final iceField = CircleComponent(
      radius: iceRadius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.cyanAccent.withOpacity(0.25),
    );

    iceField.add(
      TimerComponent(
        period: 0.3,
        repeat: true,
        onTick: () {
          final iceVictims = game.getEnemiesInRange(center, iceRadius);
          for (final v in iceVictims) {
            final pushBack =
                (v.targetOrb.position - v.position).normalized() *
                -slowStrength;
            v.position += pushBack;
          }
        },
      ),
    );

    iceField.add(RemoveEffect(delay: duration));
    game.world.add(iceField);

    // Rank 3: Freeze enemies in place briefly (stun)
    if (rank >= 3) {
      for (final v in victims) {
        v.add(MoveEffect.by(Vector2.zero(), EffectController(duration: 1.5)));
      }
    }
  }

  /// Steam Meteor - Scalding burst that damages and confuses enemies
  static void _steamMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final rng = Random();
    final int scaldDmg = (calcDmg(attacker, null) * (0.4 + 0.1 * rank))
        .toInt()
        .clamp(3, 120);

    for (final v in victims) {
      // Damage
      v.takeDamage(scaldDmg);

      // Confusion: random movement
      final randomDir = Vector2(
        rng.nextDouble() * 2 - 1,
        rng.nextDouble() * 2 - 1,
      ).normalized();
      v.add(
        MoveEffect.by(
          randomDir * (30.0 + 8.0 * rank),
          EffectController(duration: 0.3),
        ),
      );

      ImpactVisuals.play(game, v.position, 'Steam', scale: 0.6);
    }

    // Steam cloud visual
    final cloud = CircleComponent(
      radius: radius * 0.7,
      position: center,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.blueGrey.shade300.withOpacity(0.3),
    );
    cloud.add(
      SequenceEffect([
        ScaleEffect.to(Vector2.all(1.5), EffectController(duration: 1.0)),
        OpacityEffect.fadeOut(EffectController(duration: 0.5)),
        RemoveEffect(),
      ]),
    );
    game.world.add(cloud);
  }

  //
  //  PLANT / POISON
  //

  /// Plant Meteor - Seeds a thorny garden that damages and ensnares
  static void _plantMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final gardenRadius = radius * 0.85;
    final duration = 4.0 + 0.6 * rank;

    final int thornDps = (attacker.unit.statIntelligence * (1.2 + 0.2 * rank))
        .toInt()
        .clamp(2, 100);

    final slowStrength = 8.0 + 2.0 * rank;

    final garden = CircleComponent(
      radius: gardenRadius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.green.withOpacity(0.3),
    );

    garden.add(
      TimerComponent(
        period: 0.4,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(center, gardenRadius);
          for (final v in victims) {
            v.takeDamage(thornDps);
            // Slow effect
            final pushBack =
                (v.targetOrb.position - v.position).normalized() *
                -slowStrength;
            v.position += pushBack;
          }
        },
      ),
    );

    garden.add(RemoveEffect(delay: duration));
    game.world.add(garden);

    // Rank 3: Garden also heals guardians inside
    if (rank >= 3) {
      garden.add(
        TimerComponent(
          period: 1.0,
          repeat: true,
          onTick: () {
            final allies = game.getGuardiansInRange(
              center: center,
              range: gardenRadius,
            );
            for (final g in allies) {
              g.unit.heal((thornDps * 0.5).toInt());
            }
          },
        ),
      );
    }
  }

  /// Poison Meteor - Toxic explosion that applies stacking poison
  static void _poisonMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final int poisonDmg = (attacker.unit.statIntelligence * (0.8 + 0.15 * rank))
        .toInt()
        .clamp(2, 80);
    final poisonTicks = 6 + rank;

    for (final v in victims) {
      v.unit.applyStatusEffect(
        SurvivalStatusEffect(
          type: 'Poison',
          damagePerTick: poisonDmg,
          ticksRemaining: poisonTicks,
          tickInterval: 0.5,
        ),
      );
      ImpactVisuals.play(game, v.position, 'Poison', scale: 0.7);
    }

    // Poison cloud lingers
    final cloudDuration = 2.0 + 0.3 * rank;
    final cloud = CircleComponent(
      radius: radius * 0.6,
      position: center,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.purple.withOpacity(0.25),
    );

    cloud.add(
      TimerComponent(
        period: 0.6,
        repeat: true,
        onTick: () {
          final newVictims = game.getEnemiesInRange(center, radius * 0.6);
          for (final v in newVictims) {
            v.unit.applyStatusEffect(
              SurvivalStatusEffect(
                type: 'Poison',
                damagePerTick: (poisonDmg * 0.5).toInt(),
                ticksRemaining: 3,
                tickInterval: 0.5,
              ),
            );
          }
        },
      ),
    );

    cloud.add(RemoveEffect(delay: cloudDuration));
    game.world.add(cloud);
  }

  //
  //  EARTH / MUD / CRYSTAL
  //

  /// Earth Meteor - Devastating impact with shrapnel and shield
  static void _earthMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    // Shrapnel damage to nearby enemies
    final shrapnelRadius = radius * 1.3;

    final int shrapnelDmg = (calcDmg(attacker, null) * (0.5 + 0.1 * rank))
        .toInt()
        .clamp(3, 150);

    final shrapnelVictims = game.getEnemiesInRange(center, shrapnelRadius);
    for (final v in shrapnelVictims) {
      if (!victims.contains(v)) {
        v.takeDamage(shrapnelDmg);
        ImpactVisuals.play(game, v.position, 'Earth', scale: 0.5);
      }
    }

    // Grant shield to attacker
    final int shieldAmount = (attacker.unit.maxHp * (0.1 + 0.03 * rank))
        .toInt()
        .clamp(20, 400);

    attacker.unit.shieldHp = (attacker.unit.shieldHp ?? 0) + shieldAmount;

    // Rank 3: Also grant shield to nearby guardians
    if (rank >= 3) {
      final allies = game.getGuardiansInRange(
        center: attacker.position,
        range: 200,
      );
      for (final g in allies) {
        g.unit.shieldHp = (g.unit.shieldHp ?? 0) + (shieldAmount * 0.4).toInt();
      }
    }
  }

  /// Mud Meteor - Creates sticky mud that heavily slows
  static void _mudMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final mudRadius = radius * 1.0;
    final duration = 5.0 + 0.5 * rank;
    final slowStrength = 20.0 + 4.0 * rank;

    final mudPool = CircleComponent(
      radius: mudRadius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.brown.shade600.withOpacity(0.4),
    );

    mudPool.add(
      TimerComponent(
        period: 0.25,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(center, mudRadius);
          for (final v in victims) {
            final pushBack =
                (v.targetOrb.position - v.position).normalized() *
                -slowStrength;
            v.position += pushBack;
          }
        },
      ),
    );

    mudPool.add(RemoveEffect(delay: duration));
    game.world.add(mudPool);
  }

  /// Crystal Meteor - Shatters into homing crystal shards
  static void _crystalMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final shardCount = 4 + rank;

    final int shardDmg = (calcDmg(attacker, null) * (0.4 + 0.08 * rank))
        .toInt()
        .clamp(3, 120);

    final rng = Random();
    final allEnemies = game.getEnemiesInRange(center, radius * 2);

    for (int i = 0; i < shardCount; i++) {
      if (allEnemies.isEmpty) break;
      final target = allEnemies[rng.nextInt(allEnemies.length)];

      Future.delayed(Duration(milliseconds: i * 80), () {
        if (target.isDead) return;

        game.spawnAlchemyProjectile(
          start: center,
          target: target,
          damage: shardDmg,
          color: Colors.tealAccent,
          shape: ProjectileShape.shard,
          speed: 2.5,
          isEnemy: false,
          onHit: () {
            target.takeDamage(shardDmg);
            ImpactVisuals.play(game, target.position, 'Crystal', scale: 0.6);
          },
        );
      });
    }
  }

  //
  //  AIR / DUST / LIGHTNING
  //

  /// Air Meteor - Powerful shockwave that blasts enemies away
  static void _airMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    // Massive knockback
    for (final v in victims) {
      final dir = (v.position - center).normalized();
      final knockbackDist = 120.0 + 25.0 * rank;

      v.add(
        MoveEffect.by(
          dir * knockbackDist,
          EffectController(duration: 0.25, curve: Curves.easeOut),
        ),
      );
    }

    SurvivalAttackManager.triggerScreenShake(game, 4.0 + rank);

    // Rank 3: Second shockwave
    if (rank >= 3) {
      Future.delayed(const Duration(milliseconds: 300), () {
        final secondWaveVictims = game.getEnemiesInRange(center, radius * 1.3);
        for (final v in secondWaveVictims) {
          final dir = (v.position - center).normalized();
          v.add(
            MoveEffect.by(
              dir * 80.0,
              EffectController(duration: 0.2, curve: Curves.easeOut),
            ),
          );
        }
        ImpactVisuals.playExplosion(game, center, 'Air', radius * 1.3);
      });
    }
  }

  /// Dust Meteor - Blinding sandstorm that confuses and damages
  static void _dustMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final rng = Random();
    final duration = 3.0 + 0.4 * rank;

    final int tickDmg = (attacker.unit.statIntelligence * (0.6 + 0.1 * rank))
        .toInt()
        .clamp(1, 60);

    final sandstorm = CircleComponent(
      radius: radius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.amber.shade300.withOpacity(0.35),
    );

    sandstorm.add(
      TimerComponent(
        period: 0.4,
        repeat: true,
        onTick: () {
          final stormVictims = game.getEnemiesInRange(center, radius);
          for (final v in stormVictims) {
            v.takeDamage(tickDmg);
            // Confusion: jitter movement
            final jitter = Vector2(
              (rng.nextDouble() - 0.5) * (20 + 4 * rank),
              (rng.nextDouble() - 0.5) * (20 + 4 * rank),
            );
            v.position += jitter;
          }
        },
      ),
    );

    sandstorm.add(RemoveEffect(delay: duration));
    game.world.add(sandstorm);
  }

  /// Lightning Meteor - Thunderbolt strike with chain lightning
  static void _lightningMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final chainCount = 2 + rank;

    final int chainDmg = (calcDmg(attacker, null) * (0.5 + 0.1 * rank))
        .toInt()
        .clamp(4, 150);

    final rng = Random();

    for (final src in victims) {
      final nearby = game
          .getEnemiesInRange(src.position, 250)
          .where((e) => e != src && !victims.contains(e))
          .toList();

      final chains = min(chainCount, nearby.length);
      for (int i = 0; i < chains; i++) {
        if (nearby.isEmpty) break;
        final target = nearby[rng.nextInt(nearby.length)];

        Future.delayed(Duration(milliseconds: i * 60), () {
          if (target.isDead) return;

          game.spawnAlchemyProjectile(
            start: src.position,
            target: target,
            damage: chainDmg,
            color: Colors.yellow,
            shape: ProjectileShape.bolt,
            speed: 4.0,
            isEnemy: false,
            onHit: () {
              target.takeDamage(chainDmg);
              ImpactVisuals.play(
                game,
                target.position,
                'Lightning',
                scale: 0.8,
              );
            },
          );
        });
      }
    }

    SurvivalAttackManager.triggerScreenShake(game, 3.0 + rank * 0.5);
  }

  //
  //  SPIRIT / DARK / LIGHT
  //

  /// Spirit Meteor - Marks enemies for delayed spirit explosions
  static void _spiritMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    List<HoardEnemy> victims,
  ) {
    final int markDmg = (calcDmg(attacker, null) * (0.8 + 0.15 * rank))
        .toInt()
        .clamp(5, 250);
    final explosionRadius = 60.0 + 8.0 * rank;

    for (final e in victims) {
      // Mark visual
      ImpactVisuals.play(game, e.position, 'Spirit', scale: 0.8);

      // Delayed explosion
      Future.delayed(const Duration(milliseconds: 800), () {
        if (e.isDead) return;
        final explosionVictims = game.getEnemiesInRange(
          e.position,
          explosionRadius,
        );
        for (final v in explosionVictims) {
          v.takeDamage(markDmg);
          ImpactVisuals.play(game, v.position, 'Spirit', scale: 0.5);
        }
      });
    }
  }

  /// Dark Meteor - Execute low HP enemies, bonus damage to weakened
  static void _darkMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    List<HoardEnemy> victims,
  ) {
    final executeThreshold = 0.15 + 0.05 * rank;

    final int bonusDmg = (calcDmg(attacker, null) * (0.8 + 0.2 * rank))
        .toInt()
        .clamp(5, 400);

    for (final v in victims) {
      if (!v.isBoss && v.unit.hpPercent < executeThreshold) {
        // Execute!
        v.takeDamage(99999);
        ImpactVisuals.play(game, v.position, 'Dark', scale: 1.4);
      } else {
        // Bonus damage to weakened enemies
        final extraDmg = v.unit.hpPercent < 0.5
            ? (bonusDmg * 1.5).toInt()
            : bonusDmg;
        v.takeDamage(extraDmg);
        ImpactVisuals.play(game, v.position, 'Dark', scale: 0.8);
      }
    }

    // Rank 3: Lifesteal from executes
    if (rank >= 3) {
      final executed = victims.where((v) => v.isDead).length;
      attacker.unit.heal(executed * 50);
    }
  }

  /// Light Meteor - Holy explosion that damages enemies and heals team
  static void _lightMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    // Damage enemies
    final int lightDmg = (calcDmg(attacker, null) * (1.2 + 0.2 * rank))
        .toInt()
        .clamp(10, 500);

    final victims = game.getEnemiesInRange(center, radius);
    for (final v in victims) {
      v.takeDamage(lightDmg);
      ImpactVisuals.play(game, v.position, 'Light', scale: 0.9);
    }

    // Heal all guardians
    final int healAmount = (attacker.unit.statIntelligence * (3.0 + 0.5 * rank))
        .toInt()
        .clamp(10, 200);
    for (final g in game.guardians) {
      if (!g.isDead) {
        g.unit.heal(healAmount);
        ImpactVisuals.playHeal(game, g.position, scale: 0.6);
      }
    }

    // Heal orb
    game.orb.heal((healAmount * 0.5).toInt());

    // Rank 3: Purify debuffs (clear negative status effects)
    if (rank >= 3) {
      for (final g in game.guardians) {
        g.unit.statusEffects.clear();
      }
    }
  }
}
