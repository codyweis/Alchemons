// lib/games/survival/survival_enemies.dart
import 'dart:math';
import 'dart:ui';

import 'package:alchemons/games/survival/components/alchemy_orb.dart';
import 'package:alchemons/games/survival/scaling_system.dart';
import 'package:alchemons/games/survival/survival_combat.dart';
import 'package:alchemons/games/survival/survival_creature_sprite.dart';
import 'package:alchemons/games/survival/survival_game.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

enum EnemyRole { charger, shooter }

enum BossArchetype {
  juggernaut, // currently all bosses share the same simple AI, archetype kept for future flavor
  summoner,
  artillery,
}

/// Creature families (not guardian families)
enum CreatureFamily {
  // Tier 1 - Swarm
  gloop,
  skitter,
  wisp,
  mote,
  speck,
  // Tier 2 - Grunt / Brute
  crawler,
  shambler,
  lurker,
  creep,
  // Tier 3 - Elite
  ravager,
  stalker,
  howler,
  shade,
  // Tier 4 - Champion / MiniBoss
  brute,
  terror,
  dread,
  blight,
  // Tier 5 - Titan / Boss
  colossus,
  leviathan,
  behemoth,
  apex,
}

enum EnemyTier {
  // Tier 1 - fodder / swarm
  swarm(1, 'Swarm', 0.6, 0.6),

  // Tier 2 - “brute” units: fewer, tougher than swarm
  grunt(2, 'Brute', 0.7, 0.7),

  // Tier 3 - elites: small packs, noticeable threat
  elite(3, 'Elite', 0.8, 0.8),

  // Tier 4/5 are reserved for mini-boss/boss scaling, not regular trash
  champion(4, 'MiniBoss', 1.0, 0.9),
  titan(5, 'Boss', 1.4, 1.2);

  final int tier;
  final String name;
  final double statMultiplier;
  final double hpMultiplier;

  const EnemyTier(this.tier, this.name, this.statMultiplier, this.hpMultiplier);
}

const List<String> allElements = [
  'Fire',
  'Water',
  'Earth',
  'Air',
  'Ice',
  'Lightning',
  'Plant',
  'Poison',
  'Steam',
  'Lava',
  'Mud',
  'Dust',
  'Crystal',
  'Spirit',
  'Dark',
  'Light',
  'Blood',
];

class SurvivalEnemyTemplate {
  final EnemyTier tier;
  final String element;
  final CreatureFamily creatureFamily;

  const SurvivalEnemyTemplate({
    required this.tier,
    required this.element,
    required this.creatureFamily,
  });

  String get name => '${creatureFamily.name.capitalize()} ${element}ling';
  String get id =>
      '${element.toLowerCase()}_${tier.name.toLowerCase()}_${creatureFamily.name}';
  String get family => creatureFamily.name;
}

extension StringExtension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

class SurvivalEnemyCatalog {
  static final Random _rng = Random();
  static final List<SurvivalEnemyTemplate> _allTemplates =
      _generateAllTemplates();

  static List<SurvivalEnemyTemplate> _generateAllTemplates() {
    final templates = <SurvivalEnemyTemplate>[];
    for (final tier in EnemyTier.values) {
      for (final element in allElements) {
        final families = _getFamiliesForTier(tier);
        for (final family in families) {
          templates.add(
            SurvivalEnemyTemplate(
              tier: tier,
              element: element,
              creatureFamily: family,
            ),
          );
        }
      }
    }
    return templates;
  }

  /// Map tiers to visual “families”.
  ///  - swarm  = fodder blobs (lots of them)
  ///  - grunt  = “brute” blobs (tougher frontliners)
  ///  - elite  = rare elite packs
  ///  - champion/titan = mini-boss / boss visuals
  static List<CreatureFamily> _getFamiliesForTier(EnemyTier tier) {
    switch (tier) {
      case EnemyTier.swarm:
        return [
          CreatureFamily.gloop,
          CreatureFamily.skitter,
          CreatureFamily.wisp,
          CreatureFamily.mote,
          CreatureFamily.speck,
        ];
      case EnemyTier.grunt:
        return [
          CreatureFamily.crawler,
          CreatureFamily.shambler,
          CreatureFamily.lurker,
          CreatureFamily.creep,
        ];
      case EnemyTier.elite:
        return [
          CreatureFamily.ravager,
          CreatureFamily.stalker,
          CreatureFamily.howler,
          CreatureFamily.shade,
        ];
      case EnemyTier.champion:
        return [
          CreatureFamily.brute,
          CreatureFamily.terror,
          CreatureFamily.dread,
          CreatureFamily.blight,
        ];
      case EnemyTier.titan:
        return [
          CreatureFamily.colossus,
          CreatureFamily.leviathan,
          CreatureFamily.behemoth,
          CreatureFamily.apex,
        ];
    }
  }

  static SurvivalEnemyTemplate? getTemplate(String element, int tierNum) {
    try {
      final tier = EnemyTier.values.firstWhere((t) => t.tier == tierNum);
      return _allTemplates.firstWhere(
        (t) => t.element == element && t.tier == tier,
      );
    } catch (e) {
      return null;
    }
  }

  static SurvivalEnemyTemplate getRandomTemplateForTier(int tierNum) {
    final tier = EnemyTier.values.firstWhere((t) => t.tier == tierNum);
    final tieredTemplates = _allTemplates.where((t) => t.tier == tier).toList();
    return tieredTemplates[_rng.nextInt(tieredTemplates.length)];
  }

  static SurvivalUnit buildEnemy({
    required SurvivalEnemyTemplate template,
    required int tier,
    required int wave,
    bool isShooter = false,
  }) {
    return ImprovedScalingSystem.buildScaledEnemy(
      template: template,
      tier: tier,
      wave: wave,
      isShooter: isShooter,
    );
  }

  static SurvivalUnit buildMiniBoss({
    required SurvivalEnemyTemplate template,
    required int wave,
  }) {
    return ImprovedScalingSystem.buildMiniBoss(template: template, wave: wave);
  }

  static SurvivalUnit buildMegaBoss({
    required SurvivalEnemyTemplate template,
    required int wave,
  }) {
    return ImprovedScalingSystem.buildMegaBoss(template: template, wave: wave);
  }
}

// ============================================================================
//                                HOARD ENEMY
// ============================================================================

class HoardEnemy extends PositionComponent with HasGameRef<SurvivalHoardGame> {
  final AlchemyOrb targetOrb;
  final SurvivalEnemyTemplate template;
  final EnemyRole role;
  final SurvivalUnit unit;
  final double sizeScale;

  final BossArchetype? bossArchetype;
  final bool isMegaBoss;
  bool isBoss = false;
  bool isMiniBoss = false;

  final double speedMultiplier;
  bool isDead = false;

  // Logical blob radius used for visuals + hitbox
  final double _logicalRadius;

  // -- Physics & Movement --
  late double _maxSpeed;
  Vector2 _velocity = Vector2.zero();
  double get mass => template.tier.tier.toDouble() + (isMegaBoss ? 10.0 : 0.0);

  late int _contactDamage;
  late int _shotDamage;
  late double _baseAttackCooldown;
  double _attackCooldown = 0;
  final double _idealRange = 350;
  double _orbitAngle = 0.0;
  double _meleeCooldown = 0;

  double _timeAlive = 0;
  double _timeSinceLastDamage = 0;

  // Boss state (simplified)
  bool get isAnyBoss => isBoss || isMiniBoss || isMegaBoss;
  bool _isInvulnerable = false;
  double _bossAttackCooldown = 0.0;

  // HP bar smoothing
  RectangleComponent? _hpFill;
  double _hpVisual = 1.0;
  double _hpBarBaseWidth = 0.0;

  late CircleComponent _coreVisual;
  late AlchemicalBlobBody _body;

  HoardEnemy({
    required Vector2 position,
    required this.targetOrb,
    required this.template,
    required this.role,
    required this.unit,
    this.sizeScale = 1.0,
    this.bossArchetype,
    this.isMegaBoss = false,
    this.speedMultiplier = 1.0,
  }) : _logicalRadius =
           (12.0 + (template.tier.tier * 1.5)) * sizeScale, // visual + hitbox
       super(
         position: position,
         size: Vector2.all(
           ((12.0 + (template.tier.tier * 1.5)) * sizeScale) *
               2, // match blob radius
         ),
         anchor: Anchor.center,
       ) {
    _orbitAngle = Random().nextDouble() * pi * 2;
    scale = Vector2.all(1.0);

    // If an archetype is provided or it's a mega boss, treat as boss
    if (bossArchetype != null && !isMegaBoss && !isMiniBoss) {
      isBoss = true;
    }

    _configureBehaviorFromUnit();

    // Bosses start invulnerable during entrance
    if (isAnyBoss) {
      _isInvulnerable = true;
    }
  }

  void _configureBehaviorFromUnit() {
    final baseSpeed = 60.0;

    if (role == EnemyRole.charger) {
      _maxSpeed = baseSpeed * (1.0 + unit.statStrength * 0.15);
      _contactDamage = (unit.physAtk * 0.7).round();
      _shotDamage = (unit.elemAtk * 0.2).round();
    } else {
      _maxSpeed = baseSpeed * (0.85 + unit.statSpeed * 0.18);
      _contactDamage = (unit.physAtk * 0.2).round();
      _shotDamage = (unit.elemAtk * 0.45).round();
    }

    // Strong, simple boss multipliers
    if (isAnyBoss) {
      final bossMult = isMegaBoss
          ? 2.5
          : (isBoss ? 2.0 : 1.6); // mini < boss < mega

      _contactDamage = max(10, (_contactDamage * bossMult).round());
      _shotDamage = max(8, (_shotDamage * bossMult).round());

      _baseAttackCooldown =
          (role == EnemyRole.charger ? 2.0 : 1.8) /
          max(0.5, unit.cooldownReduction);
    } else {
      _baseAttackCooldown = role == EnemyRole.charger
          ? 2.5 / unit.cooldownReduction
          : 2.2 / unit.cooldownReduction;
    }

    _attackCooldown = _baseAttackCooldown;
    _maxSpeed *= speedMultiplier;
  }

  @override
  Future<void> onLoad() async {
    final baseColor = _elementColor(template.element);
    final radius = _logicalRadius;

    add(
      AlchemicalTrail(
        color: baseColor,
        radius: radius * 0.6,
        maxParticles: isAnyBoss ? 20 : 8,
      ),
    );

    _body = AlchemicalBlobBody(
      template: template,
      role: role,
      color: baseColor,
      isBoss: isAnyBoss,
      radius: radius,
    );
    add(_body);

    _coreVisual = CircleComponent(paint: Paint()..color = baseColor);
    _coreVisual.opacity = 0;
    add(_coreVisual);

    // Elites get extra runes; bosses stay clean blobs.
    if (template.tier.tier >= 3 && !isAnyBoss) {
      _addFloatingRunes(baseColor, template.tier.tier - 1);
    }

    if (isAnyBoss) {
      _setupBossVisuals(baseColor, radius);
      _startBossEntrance();
    }
  }

  void _startBossEntrance() {
    final entranceDuration = isMegaBoss ? 5.0 : 3.5;

    final dir = (targetOrb.position - position).normalized();

    // Pulsing invulnerability shield (temporary)
    final shield = CircleComponent(
      radius: _logicalRadius * 1.1,
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.white.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    shield.add(
      ScaleEffect.by(
        Vector2.all(1.15),
        EffectController(duration: 0.4, alternate: true, infinite: true),
      ),
    );
    add(shield);

    // Warning rings expanding from boss (temporary telegraph)
    for (int i = 0; i < 4; i++) {
      Future.delayed(Duration(milliseconds: i * 600), () {
        if (!isMounted) return;

        gameRef.world.add(
          CircleComponent(
            radius: 40,
            position: position.clone(),
            anchor: Anchor.center,
            paint: Paint()
              ..color = _elementColor(template.element).withOpacity(0.5)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3,
          )..add(
            SequenceEffect([
              ScaleEffect.to(
                Vector2.all(12),
                EffectController(duration: 1.2, curve: Curves.easeOut),
              ),
              RemoveEffect(),
            ]),
          ),
        );
      });
    }

    // Slow approach movement
    add(
      MoveEffect.by(
        dir * 300,
        EffectController(duration: entranceDuration, curve: Curves.easeInOut),
      ),
    );

    // End entrance after duration
    Future.delayed(
      Duration(milliseconds: (entranceDuration * 1000).toInt()),
      () {
        if (!isMounted || isDead) return;

        _isInvulnerable = false;
        shield.removeFromParent();

        _triggerScreenShake(isMegaBoss ? 12.0 : 8.0);

        // Shockwave
        gameRef.world.add(
          CircleComponent(
            radius: _logicalRadius * 1.1,
            position: position.clone(),
            anchor: Anchor.center,
            paint: Paint()
              ..color = _elementColor(template.element)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6,
          )..add(
            SequenceEffect([
              ScaleEffect.to(Vector2.all(5), EffectController(duration: 0.4)),
              RemoveEffect(),
            ]),
          ),
        );
      },
    );
  }

  void _setupBossVisuals(Color baseColor, double radius) {
    // Bosses are just big blobs with a health bar.
    // No permanent rotating rings or orbit lines; keeps the arena clean.
    _buildHpBar();
  }

  void _addFloatingRunes(Color color, int count) {
    final orbitContainer = PositionComponent(
      size: size,
      anchor: Anchor.center,
      position: Vector2.zero(),
    );
    double orbitRadius = (size.x / 2) * 1.3;

    for (int i = 0; i < count; i++) {
      orbitContainer.add(
        RectangleComponent(
          size: Vector2(5, 5),
          position: Vector2(
            orbitRadius * cos(i * 2 * pi / count),
            orbitRadius * sin(i * 2 * pi / count),
          ),
          anchor: Anchor.center,
          angle: pi / 4,
          paint: Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        ),
      );
    }
    orbitContainer.add(
      RotateEffect.by(pi * 2, EffectController(duration: 5.0, infinite: true)),
    );
    add(orbitContainer);
  }

  void _buildHpBar() {
    final r = _logicalRadius;

    // Width scales with radius but stays within sane limits.
    final barWidth =
        (r *
                (isMegaBoss
                    ? 2.4
                    : isMiniBoss
                    ? 1.8
                    : 1.5))
            .clamp(60.0, isMegaBoss ? 220.0 : 160.0);
    final barHeight = isMegaBoss ? 10.0 : 6.0;

    // Always just above the visual blob, not multiplied twice by sizeScale.
    final yOffset = -r - (isMegaBoss ? 32.0 : 24.0);

    final bg = RectangleComponent(
      size: Vector2(barWidth, barHeight),
      anchor: Anchor.center,
      position: Vector2(0, yOffset),
      paint: Paint()..color = Colors.black87,
    );

    _hpBarBaseWidth = barWidth - 4;

    final fill = RectangleComponent(
      size: Vector2(_hpBarBaseWidth, barHeight - 2),
      anchor: Anchor.centerLeft,
      position: Vector2(-barWidth / 2 + 2, 0),
      paint: Paint()
        ..color = isMegaBoss
            ? Colors.red
            : (isMiniBoss ? Colors.yellow : Colors.orange),
    );
    bg.add(fill);
    _hpFill = fill;
    add(bg);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isDead) return;

    _timeAlive += dt;
    _timeSinceLastDamage += dt;
    _meleeCooldown = (_meleeCooldown - dt).clamp(0, double.infinity);
    _attackCooldown = (_attackCooldown - dt).clamp(0, double.infinity);

    SurvivalCombat.tickRealtimeStatuses(unit, dt);

    if (unit.isDead) {
      _die();
      return;
    }

    if (isAnyBoss) {
      _updateSimpleBossAI(dt);
    } else {
      _updateMovementAndAI(dt);
    }

    // Smooth HP bar
    if (_hpFill != null) {
      final targetRatio = unit.hpPercent.clamp(0.0, 1.0);
      // FPS-friendly exponential smoothing
      final lerpFactor = 1 - pow(0.001, dt);
      _hpVisual += (targetRatio - _hpVisual) * lerpFactor;
      _hpFill!.size.x = _hpBarBaseWidth * _hpVisual;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SIMPLE, FLOWY BOSS AI (CLEAN ORBIT RING, NO GLITCHING INTO CENTER)
  // ═══════════════════════════════════════════════════════════════════════════

  void _updateSimpleBossAI(double dt) {
    // Bosses stay in a ring around the orb
    final desiredRadius = isMegaBoss ? 420.0 : 320.0;
    final minRadius = isMegaBoss ? 280.0 : 240.0; // never inside this
    final maxRadius = desiredRadius + 80.0; // don't wander too far out

    final center = targetOrb.position;
    final toCenter = center - position;
    final dist = toCenter.length;

    Vector2 moveDir = Vector2.zero();

    if (dist < 1.0) {
      // super safety: if we ever land basically on top of the orb, shove outward
      moveDir = Vector2(1, 0);
    } else {
      final radialIn = toCenter / dist;
      final radialOut = -radialIn;

      // Hard band: if we get way too close or too far, strongly correct
      if (dist < minRadius) {
        moveDir += radialOut; // push away from center
      } else if (dist > maxRadius) {
        moveDir += radialIn; // pull back toward center
      } else {
        // Soft steering to hug the desired radius
        if (dist > desiredRadius + 20) moveDir += radialIn * 0.7;
        if (dist < desiredRadius - 20) moveDir += radialOut * 0.7;

        // Tangential orbit motion so they “flow” around the orb
        final tangent = Vector2(-radialIn.y, radialIn.x);
        moveDir += tangent * 0.9;

        // Very small separation so they don't jitter like crazy
        // Comment this out entirely if you want bosses to ignore other enemies.
        moveDir += _computeSeparation(radius: size.x * 1.0) * 0.2;
      }
    }

    if (moveDir.length2 > 0) {
      moveDir.normalize();
    }

    final bossSpeed = _maxSpeed * (isMegaBoss ? 0.85 : 0.65);
    final desiredVel = moveDir * bossSpeed;

    _velocity.lerp(desiredVel, dt * 4.0);
    position += _velocity * dt;

    if (_velocity.length2 > 10) {
      final targetAngle = atan2(_velocity.y, _velocity.x);
      angle = _smoothAngle(angle, targetAngle, dt * 6.0);
    }

    // Simple boss attack rhythm
    _bossAttackCooldown -= dt;
    if (_bossAttackCooldown <= 0) {
      _performBossAttack();
    }
  }

  void _performBossAttack() {
    final rng = Random().nextDouble();

    if (rng < 0.5) {
      // Main pattern: radial shots
      _fireRadialVolley(projectiles: isMegaBoss ? 18 : 12);
      _bossAttackCooldown = isMegaBoss ? 3.0 : 3.5;
    } else {
      // Secondary pattern: summon minions
      if (!isMegaBoss) {
        _summonMinions(isBoss ? 5 : 3);
      } else {
        _summonMinions(6);
      }
      _bossAttackCooldown = isMegaBoss ? 3.2 : 2.8;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REGULAR ENEMY MOVEMENT / AI
  // ═══════════════════════════════════════════════════════════════════════════

  void _updateMovementAndAI(double dt) {
    final targetGuardian = gameRef.getRandomGuardianInRange(
      center: position,
      range: 800,
    );

    Vector2 steeringForce = Vector2.zero();
    double currentMaxSpeed = _maxSpeed;

    if (role == EnemyRole.shooter) {
      steeringForce = _getShooterSteering(targetGuardian, dt);
      _tryShoot(targetGuardian);
    } else {
      steeringForce = _getChargerSteering(
        targetGuardian,
        dt,
        outSpeed: (s) => currentMaxSpeed = s,
      );
    }

    final separationForce = _computeSeparation(radius: size.x * 0.8);

    Vector2 desiredVelocity =
        (steeringForce + separationForce * 2.5).normalized() * currentMaxSpeed;
    double turnSpeed = 4.0;
    _velocity.lerp(desiredVelocity, dt * turnSpeed);
    position += _velocity * dt;

    if (_velocity.length2 > 10) {
      final double targetAngle = atan2(_velocity.y, _velocity.x);
      angle = _smoothAngle(angle, targetAngle, dt * 6.0);
    }
  }

  Vector2 _computeSeparation({double radius = 50.0}) {
    Vector2 separation = Vector2.zero();
    int count = 0;

    final neighbors = gameRef.getEnemiesInRange(position, radius);

    for (final other in neighbors) {
      if (other == this) continue;

      final dist = position.distanceTo(other.position);
      if (dist < 0.1) continue;

      if (mass > other.mass + 1) continue;

      Vector2 push = (position - other.position).normalized();
      double weight = 1.0 - (dist / radius);

      if (other.mass > mass) {
        weight *= 1.5;
      }

      separation += push * weight;
      count++;
    }

    if (count > 0) {
      separation /= count.toDouble();
      if (separation.length2 > 0) separation.normalize();
    }
    return separation;
  }

  Vector2 _getChargerSteering(
    HoardGuardian? guardian,
    double dt, {
    required Function(double) outSpeed,
  }) {
    Vector2 dest = targetOrb.position;
    bool huntingGuardian = false;

    if (guardian != null) {
      final gDist = position.distanceTo(guardian.position);
      final oDist = position.distanceTo(targetOrb.position);
      if (gDist < oDist * 0.75) {
        dest = guardian.position;
        huntingGuardian = true;
      }
    }

    outSpeed(_maxSpeed);

    final distToTarget = position.distanceTo(dest);
    if (distToTarget < (huntingGuardian ? 40 : 55)) {
      _applyContactDamage(
        huntingGuardian ? guardian : targetOrb,
        huntingGuardian,
      );
    }

    return (dest - position).normalized();
  }

  Vector2 _getShooterSteering(HoardGuardian? guardian, double dt) {
    final targetPos = guardian?.position ?? targetOrb.position;
    final toTarget = targetPos - position;
    final dist = toTarget.length;
    final dir = toTarget.normalized();

    if (dist > _idealRange + 60) {
      return dir;
    } else if (dist < _idealRange - 60) {
      return -dir;
    } else {
      return Vector2(-dir.y, dir.x) * 0.5;
    }
  }

  void _tryShoot(HoardGuardian? guardian) {
    if (_attackCooldown > 0) return;

    final projectileColor = _elementColor(template.element);

    if (guardian != null && !guardian.isDead) {
      gameRef.spawnEnemyProjectile(
        start: position.clone(),
        targetPosition: guardian.position.clone(),
        color: projectileColor,
        onHit: () => guardian.takeDamage(_shotDamage),
      );
    } else {
      gameRef.spawnEnemyProjectile(
        start: position.clone(),
        targetPosition: targetOrb.position.clone(),
        color: projectileColor,
        onHit: () => targetOrb.takeDamage(_shotDamage),
      );
    }

    _attackCooldown = _baseAttackCooldown;
  }

  void _summonMinions(int count) {
    gameRef.spawnBossMinions(
      boss: this,
      element: template.element,
      tier: template.tier.tier.clamp(1, 3),
      count: count,
      ringRadius: 180,
    );
  }

  void _applyContactDamage(dynamic target, bool isGuardian) {
    if (isAnyBoss) {
      if (_meleeCooldown <= 0) {
        target.takeDamage(_contactDamage);
        _meleeCooldown = 0.9;
      }
    } else {
      target.takeDamage(_contactDamage);
      _die();
    }
  }

  double _smoothAngle(double current, double target, double rate) {
    double diff = target - current;
    while (diff < -pi) diff += 2 * pi;
    while (diff > pi) diff -= 2 * pi;
    return current + diff * rate;
  }

  void takeDamage(int amount) {
    if (isDead) return;

    if (_isInvulnerable) {
      // Visual feedback that damage was blocked
      add(
        ColorEffect(
          Colors.white.withOpacity(0.3),
          EffectController(duration: 0.1),
        ),
      );
      return;
    }

    _timeSinceLastDamage = 0;
    unit.takeDamage(amount);

    _body.add(
      ColorEffect(
        Colors.white,
        EffectController(duration: 0.1, reverseDuration: 0.1),
      ),
    );

    if (unit.isDead) _die();
  }

  void _die() {
    if (isDead) return;
    isDead = true;

    if (isAnyBoss) {
      _triggerScreenShake(20.0);

      for (int i = 0; i < 20; i++) {
        final angle = (i / 20) * pi * 2;
        final speed = 200 + Random().nextDouble() * 100;

        gameRef.world.add(
          CircleComponent(
            radius: 8,
            position: position.clone(),
            anchor: Anchor.center,
            paint: Paint()..color = _elementColor(template.element),
          )..add(
            SequenceEffect([
              MoveEffect.by(
                Vector2(cos(angle), sin(angle)) * speed,
                EffectController(duration: 0.6, curve: Curves.easeOut),
              ),
              RemoveEffect(),
            ]),
          ),
        );
      }
    }

    add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.zero(),
          EffectController(duration: 0.25, curve: Curves.easeInBack),
        ),
        RemoveEffect(),
      ]),
    );
    gameRef.removeEnemy(this);
  }

  void _triggerScreenShake(double intensity) {
    final offset = Vector2(
      (Random().nextDouble() - 0.5) * intensity,
      (Random().nextDouble() - 0.5) * intensity,
    );
    gameRef.cameraComponent.viewfinder.position += offset;
    gameRef.cameraComponent.viewfinder.add(
      MoveEffect.by(-offset, EffectController(duration: 0.1)),
    );
  }

  void _fireRadialVolley({int projectiles = 10}) {
    final col = _elementColor(template.element);
    final damage = (_shotDamage * (isMegaBoss ? 1.0 : 0.7)).round();

    for (int i = 0; i < projectiles; i++) {
      final theta = (i / projectiles) * 2 * pi + _timeAlive * 0.25;
      final dir = Vector2(cos(theta), sin(theta));
      final end = position + dir * 800;

      gameRef.spawnEnemyProjectile(
        start: position.clone(),
        targetPosition: end,
        color: col,
        onHit: () {
          final guardians = gameRef.getGuardiansInRange(center: end, range: 70);
          for (final g in guardians) {
            g.takeDamage(damage);
          }
          if (end.distanceTo(targetOrb.position) < 100) {
            targetOrb.takeDamage(damage);
          }
        },
      );
    }
  }

  Color _elementColor(String element) {
    switch (element) {
      case 'Fire':
        return Colors.deepOrangeAccent;
      case 'Water':
        return Colors.blueAccent;
      case 'Earth':
        return const Color(0xFF795548);
      case 'Air':
        return Colors.cyanAccent;
      case 'Lightning':
        return Colors.yellowAccent;
      case 'Plant':
        return Colors.lightGreenAccent;
      case 'Poison':
        return Colors.purpleAccent;
      case 'Dark':
        return Colors.deepPurple;
      case 'Light':
        return const Color(0xFFFFF176);
      case 'Blood':
        return const Color(0xFFB71C1C);
      case 'Spirit':
        return Colors.indigoAccent;
      case 'Ice':
        return const Color(0xFF80DEEA);
      case 'Lava':
        return const Color(0xFFFF5722);
      case 'Mud':
        return const Color(0xFF5D4037);
      case 'Dust':
        return const Color(0xFFD7CCC8);
      case 'Crystal':
        return const Color(0xFFF06292);
      case 'Steam':
        return const Color(0xFFCFD8DC);
      default:
        return Colors.grey;
    }
  }
}

// ============================================================================
//  SIMPLE PROJECTILE (if you still need it elsewhere)
// ============================================================================

class SimpleProjectile extends PositionComponent {
  final Vector2 start;
  final Vector2 end;
  final Color color;
  final VoidCallback onHit;
  double t = 0;

  SimpleProjectile({
    required this.start,
    required this.end,
    required this.color,
    required this.onHit,
  }) : super(position: start, size: Vector2.all(10));

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset.zero, 6, Paint()..color = color);
  }

  @override
  void update(double dt) {
    t += dt * 2.2;
    if (t >= 1.0) {
      onHit();
      removeFromParent();
    } else {
      position = start + (end - start) * t;
    }
  }
}

// ============================================================================
//  BLOB BODY (shared for all enemies; bosses are just bigger / slower pulses)
// ============================================================================

class AlchemicalBlobBody extends PositionComponent with HasPaint {
  final SurvivalEnemyTemplate template;
  final EnemyRole role;
  final Color color;
  final bool isBoss;
  final double radius;

  double _time = 0;
  late Paint _borderPaint;
  late Paint _glowPaint;
  late Paint _eyePaint;
  late Paint _eyePupilPaint;
  late double _phaseOffset;
  double _pulseSpeed = 2.0;

  AlchemicalBlobBody({
    required this.template,
    required this.role,
    required this.color,
    required this.isBoss,
    required this.radius,
  }) : super(size: Vector2.all(radius * 2), anchor: Anchor.center) {
    _phaseOffset = Random().nextDouble() * 100;
    scale = Vector2.all(1.0);
    if (isBoss) _pulseSpeed = 1.0;
  }

  @override
  Future<void> onLoad() async {
    paint = Paint()
      ..color = color.withOpacity(0.85)
      ..style = PaintingStyle.fill;

    _borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isBoss ? 3.0 : 1.5;

    _glowPaint = Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, isBoss ? 30 : 20);

    _eyePaint = Paint()..color = Colors.white;
    _eyePupilPaint = Paint()..color = Colors.black;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;

    if (role == EnemyRole.shooter) {
      angle = sin(_time * 0.5) * 0.1;
    }

    final breath = 1.0 + sin(_time * _pulseSpeed) * 0.05;
    scale = Vector2.all(breath);
  }

  @override
  void render(Canvas canvas) {
    final center = size / 2;
    canvas.drawCircle(center.toOffset(), radius * 0.8, _glowPaint);

    final path = _createBlobPath(center, radius * 0.85);
    canvas.drawPath(path, paint);

    final innerRimPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawPath(_createBlobPath(center, radius * 0.65), innerRimPaint);
    canvas.drawPath(path, _borderPaint);
    _drawFace(canvas, center);
  }

  Path _createBlobPath(Vector2 center, double r) {
    final path = Path();
    final points = 20;
    final double angleStep = (pi * 2) / points;

    double frequency = 3.0;
    double amplitude = 3.0;
    double speed = 4.0;

    switch (template.creatureFamily) {
      case CreatureFamily.gloop:
      case CreatureFamily.shambler:
        frequency = 2.0;
        amplitude = 5.0;
        speed = 2.0;
        break;
      case CreatureFamily.skitter:
      case CreatureFamily.crawler:
        frequency = 8.0;
        amplitude = 2.0;
        speed = 10.0;
        break;
      case CreatureFamily.wisp:
      case CreatureFamily.shade:
        frequency = 4.0;
        amplitude = 6.0;
        speed = 3.0;
        break;
      case CreatureFamily.ravager:
      case CreatureFamily.brute:
        frequency = 6.0;
        amplitude = 4.0;
        speed = 8.0;
        break;
      default:
        break;
    }

    if (isBoss) {
      amplitude *= 0.5;
      speed *= 0.5;
    }

    for (int i = 0; i <= points; i++) {
      final theta = i * angleStep;
      final noise =
          sin(theta * frequency + _time * speed + _phaseOffset) * amplitude;
      final noise2 =
          cos(theta * (frequency + 2) - _time * speed) * (amplitude * 0.5);
      final currentRadius = r + noise + noise2;
      final x = center.x + cos(theta) * currentRadius;
      final y = center.y + sin(theta) * currentRadius;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  void _drawFace(Canvas canvas, Vector2 center) {
    final eyeOffsetX = radius * 0.35;
    final eyeOffsetY = -radius * 0.1;
    final eyeSize = radius * 0.15;

    if (role == EnemyRole.shooter) {
      canvas.drawCircle(
        Offset(center.x, center.y - radius * 0.1),
        eyeSize * 1.5,
        _eyePaint,
      );
      canvas.drawCircle(
        Offset(center.x, center.y - radius * 0.1),
        eyeSize * 0.5,
        _eyePupilPaint,
      );
    } else {
      canvas.drawCircle(
        Offset(center.x - eyeOffsetX, center.y + eyeOffsetY),
        eyeSize,
        _eyePaint,
      );
      canvas.drawCircle(
        Offset(center.x + eyeOffsetX, center.y + eyeOffsetY),
        eyeSize,
        _eyePaint,
      );
      canvas.drawCircle(
        Offset(center.x - eyeOffsetX, center.y + eyeOffsetY),
        eyeSize / 3,
        _eyePupilPaint,
      );
      canvas.drawCircle(
        Offset(center.x + eyeOffsetX, center.y + eyeOffsetY),
        eyeSize / 3,
        _eyePupilPaint,
      );
    }
  }
}

class AlchemicalTrail extends PositionComponent {
  final Color color;
  final double radius;
  final int maxParticles;
  final List<_TrailParticle> _particles = [];
  double _spawnTimer = 0;

  AlchemicalTrail({
    required this.color,
    required this.radius,
    this.maxParticles = 10,
  });

  @override
  void update(double dt) {
    super.update(dt);

    if (parent is! PositionComponent) return;
    final parentPc = parent as PositionComponent;

    _spawnTimer += dt;
    if (_spawnTimer > 0.1) {
      _spawnTimer = 0;
      _particles.add(
        _TrailParticle(
          position: Vector2(
            -cos(parentPc.angle) * (radius * 0.5),
            -sin(parentPc.angle) * (radius * 0.5),
          ),
          life: 1.0,
          scale: 1.0,
          angle: parentPc.angle,
        ),
      );
    }

    for (int i = _particles.length - 1; i >= 0; i--) {
      final particle = _particles[i];
      particle.life -= dt * 1.5;

      final driftDir = Vector2(cos(particle.angle), sin(particle.angle));
      particle.position -= driftDir * (dt * 40);
      particle.scale = particle.life;

      if (particle.life <= 0) {
        _particles.removeAt(i);
      }
    }

    if (_particles.length > maxParticles) {
      _particles.removeAt(0);
    }
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    for (final particle in _particles) {
      paint.color = color.withOpacity(0.4 * particle.life);
      canvas.drawCircle(
        particle.position.toOffset(),
        radius * 0.6 * particle.scale,
        paint,
      );
    }
  }
}

class _TrailParticle {
  Vector2 position;
  double life;
  double scale;
  double angle;

  _TrailParticle({
    required this.position,
    required this.life,
    required this.scale,
    required this.angle,
  });
}
