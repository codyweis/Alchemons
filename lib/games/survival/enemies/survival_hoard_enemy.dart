// lib/games/survival/survival_hoard_enemy.dart
import 'dart:math';
import 'dart:ui';

import 'package:alchemons/games/survival/components/alchemy_orb.dart';
import 'package:alchemons/games/survival/components/enemy_spawn_effect.dart';
import 'package:alchemons/games/survival/scaling_system.dart';
import 'package:alchemons/games/survival/survival_combat.dart';
import 'package:alchemons/games/survival/survival_creature_sprite.dart';
import 'package:alchemons/games/survival/survival_game.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

import 'survival_enemy_types.dart';
import 'survival_enemy_visuals.dart';

// ============================================================================
//                                HOARD ENEMY
// ============================================================================

class HoardEnemy extends PositionComponent with HasGameRef<SurvivalHoardGame> {
  static final Random _rng = Random();

  final AlchemyOrb targetOrb;
  final SurvivalEnemyTemplate template;
  final EnemyRole role;
  final SurvivalUnit unit;
  final double sizeScale;
  double _hitFlash = 0.0; // 0..1, driven by damage & decays in update
  final int hydraGeneration;

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

  // Boss positioning: "sniper perches" on a ring instead of constant orbit
  double _bossAnchorAngle = 0.0;
  double _bossAnchorAngleTarget = 0.0;
  double _bossAnchorSwapTimer = 0.0;
  static const double _bossAnchorSwapInterval = 6.0;

  double _timeAlive = 0;
  double _timeSinceLastDamage = 0;

  bool _spawnEffectStarted = false;

  // Shooter "ship" state - flies in, then orbits and shoots
  bool _shooterInPosition = false;

  // Leecher state - attaches to target and drains
  bool _isAttached = false;
  Object? _attachedTarget;
  double _leechTickTimer = 0;
  final double _leechTickInterval = 0.5;
  int _leechDamagePerTick = 0;
  int _leechHealPerTick = 0;

  // Boss state (simplified)
  bool get isAnyBoss => isBoss || isMiniBoss || isMegaBoss;
  bool _isInvulnerable = false;
  double _bossAttackCooldown = 0.0;

  // Boss phase tracking
  bool _hasEnteredPhase2 = false; // <60%
  bool _hasEnteredPhase1 = false; // <30%

  // Boss focus target smoothing
  HoardGuardian? _focusGuardian;
  double _focusGuardianRetargetTimer = 0.0;

  // Juggernaut charge
  bool _isCharging = false;
  double _chargeTime = 0.0;
  double _chargeDuration = 0.8;
  Vector2? _chargeStart;
  Vector2? _chargeEnd;
  final Set<HoardGuardian> _chargeHitGuardians =
      {}; // Track who we've already hit
  bool _chargeHitOrb = false; // Track if we hit the orb this charge

  // Summoner empowerment
  double _summonerBuffTimer = 0.0;
  double _summonerBuffSpeedMult = 1.0;
  double _summonerBuffDamageMult = 1.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // HYDRA BOSS STATE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Maximum times this hydra can split (decrements each generation)
  int get hydraCanSplit => (4 - hydraGeneration).clamp(0, 4);

  /// Whether this hydra has already split (prevents double-splitting)
  bool _hydraSplitTriggered = false;

  /// Hydra ground slam cooldown
  double _hydraSlamCooldown = 0.0;

  /// Hydra is currently performing slam animation
  bool _hydraIsSlammingGround = false;
  double _hydraSlamTimer = 0.0;

  int get contactDamage => (_contactDamage * _summonerBuffDamageMult).round();
  int get shotDamage => (_shotDamage * _summonerBuffDamageMult).round();

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
    this.hydraGeneration = 0,
  }) : _logicalRadius = _calculateLogicalRadius(
         template,
         sizeScale,
         bossArchetype,
         hydraGeneration,
       ),
       super(
         position: position,
         size: Vector2.all(
           _calculateLogicalRadius(
                 template,
                 sizeScale,
                 bossArchetype,
                 hydraGeneration,
               ) *
               2, // match blob radius
         ),
         anchor: Anchor.center,
       ) {
    _orbitAngle = _rng.nextDouble() * pi * 2;

    _bossAnchorAngle = _orbitAngle;
    _bossAnchorAngleTarget = _bossAnchorAngle;
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

  /// Calculate logical radius - Hydra gen 0 is 3x normal mega boss size
  static double _calculateLogicalRadius(
    SurvivalEnemyTemplate template,
    double sizeScale,
    BossArchetype? archetype,
    int hydraGen,
  ) {
    final baseRadius = (12.0 + (template.tier.tier * 1.5)) * sizeScale;

    if (archetype == BossArchetype.hydra) {
      // Gen 0: 3.0x, Gen 1: 2.0x, Gen 2: 1.4x, Gen 3: 1.0x, Gen 4: 0.7x
      final hydraScales = [3.0, 2.0, 1.4, 1.0, 0.7];
      final scaleIndex = hydraGen.clamp(0, hydraScales.length - 1);
      return baseRadius * hydraScales[scaleIndex];
    }

    return baseRadius;
  }

  void _configureBehaviorFromUnit() {
    final baseSpeed = 60.0;

    if (role == EnemyRole.charger) {
      _maxSpeed = baseSpeed * (1.0 + unit.statStrength * 0.12);
      // lowered from 0.7 → 0.45
      _contactDamage = max(1, (unit.physAtk * 0.25).round());
      _shotDamage = max(1, (unit.elemAtk * 0.15).round());
    } else if (role == EnemyRole.shooter) {
      // Shooters fly in faster initially
      _maxSpeed = baseSpeed * (1.2 + unit.statSpeed * 0.2);
      _contactDamage = max(1, (unit.physAtk * 0.2).round());
      _shotDamage = max(1, (unit.elemAtk * 0.45).round());
    } else if (role == EnemyRole.bomber) {
      // Bombers are fast kamikazes
      _maxSpeed = baseSpeed * (1.8 + unit.statSpeed * 0.25);
      _contactDamage = max(
        1,
        (unit.physAtk * 2.5).round(),
      ); // Big explosion damage
      _shotDamage = 0;
    } else if (role == EnemyRole.leecher) {
      // Leechers are medium speed, attach and drain
      _maxSpeed = baseSpeed * (1.1 + unit.statSpeed * 0.15);
      _contactDamage = max(1, (unit.physAtk * 0.1).round()); // Low initial hit
      _leechDamagePerTick = max(1, (unit.elemAtk * 0.3).round());
      _leechHealPerTick = (_leechDamagePerTick * 0.5).round();
      _shotDamage = 0;
    }

    // Strong, simple boss multipliers
    if (isAnyBoss) {
      double bossMult = isMegaBoss
          ? 2.5
          : (isBoss ? 2.0 : 1.6); // mini < boss < mega
      // NEW: chargers get a milder multiplier than others
      if (role == EnemyRole.charger) {
        bossMult *= 0.75; // previously 1.0
      }
      if (role == EnemyRole.shooter) {
        bossMult *= 0.7; // <- key nerf for boss shooters
      }

      _contactDamage = max(10, (_contactDamage * bossMult).round());
      _shotDamage = max(8, (_shotDamage * bossMult).round());

      // Boss shooters fire slower than before
      final baseCd = role == EnemyRole.charger ? 2.0 : 2.4;
      _baseAttackCooldown = baseCd / max(0.5, unit.cooldownReduction);
    } else {
      _baseAttackCooldown = role == EnemyRole.charger
          ? 2.5 / unit.cooldownReduction
          : 2.2 / unit.cooldownReduction;
    }

    _attackCooldown = _baseAttackCooldown;
    _maxSpeed *= speedMultiplier;

    if (isAnyBoss) {
      print(
        '[BOSS-SPAWN] id=${template.id} '
        'role=$role '
        'tier=${template.tier} '
        'hp=${unit.maxHp} '
        'physAtk=${unit.physAtk} '
        'elemAtk=${unit.elemAtk} '
        'contactDamage=$_contactDamage '
        'shotDamage=$_shotDamage '
        'isMegaBoss=$isMegaBoss '
        'archetype=$bossArchetype',
      );
    }

    print('[ENEMY] ${template.id} role=$role contactDamage=$_contactDamage');
  }

  @override
  Future<void> onLoad() async {
    final baseColor = _elementColor(template.element);
    final radius = _logicalRadius;

    if (template.tier != EnemyTier.swarm) {
      final tier = template.tier;
      int maxParticles;

      if (isAnyBoss) {
        maxParticles = 10;
      } else if (tier == EnemyTier.grunt) {
        maxParticles = 2;
      } else if (tier == EnemyTier.elite) {
        maxParticles = 4;
      } else {
        maxParticles = 1;
      }

      // Disable trails if too many enemies or wave too high
      final enemyCount = gameRef.enemyCount;
      final wave = gameRef.currentWave;

      final allowTrail =
          enemyCount < 50 && wave < 40; // tweak thresholds as needed

      if (allowTrail) {
        add(
          AlchemicalTrail(
            color: baseColor,
            radius: radius * 0.6,
            maxParticles: maxParticles,
          ),
        );
      }
    }

    _body = AlchemicalBlobBody(
      template: template,
      role: role,
      color: baseColor,
      isBoss: isAnyBoss,
      radius: radius,
      bossArchetype: bossArchetype,
      hydraGeneration: hydraGeneration,
    );
    add(_body);

    // Elites get extra runes; bosses stay clean blobs.
    if (template.tier.tier >= 3 && !isAnyBoss) {
      _addFloatingRunes(baseColor, template.tier.tier - 1);
    }

    if (isAnyBoss) {
      _startBossEntrance();
    }

    _playSpawnEffect();
  }

  void _playSpawnEffect() {
    if (_spawnEffectStarted) return;
    _spawnEffectStarted = true;

    if (isAnyBoss) {
      _playBossSpawnEffect();
    } else {
      _playSimpleSpawnEffect();
    }
  }

  /// Simple, efficient spawn for regular enemies - just a quick scale pop
  void _playSimpleSpawnEffect() {
    scale = Vector2.zero();

    add(
      ScaleEffect.to(
        Vector2.all(1.0),
        EffectController(duration: 1, curve: Curves.easeOutBack),
      ),
    );
  }

  /// Dramatic spawn for bosses - portal with lightning and rise effect
  void _playBossSpawnEffect() {
    final color = _elementColor(template.element);
    final portalRadius = _logicalRadius * 2.0;

    // Start tiny and below final position
    scale = Vector2.zero();
    final riseAmount = _logicalRadius * 0.8;
    position.y += riseAmount;

    // Spawn the portal effect
    gameRef.world.add(
      BossSpawnPortal(
        position: position.clone() + Vector2(0, riseAmount * 0.5),
        color: color,
        radius: portalRadius,
        duration: isMegaBoss ? 3.5 : 2.5,
      ),
    );

    // Delay the boss appearing slightly so portal forms first
    final appearDelay = isMegaBoss ? 1.2 : 0.8;
    final riseDuration = isMegaBoss ? 1.5 : 1.0;

    Future.delayed(Duration(milliseconds: (appearDelay * 1000).toInt()), () {
      if (!isMounted || isDead) return;

      // Scale up with dramatic bounce
      add(
        ScaleEffect.to(
          Vector2.all(1.0),
          EffectController(duration: riseDuration, curve: Curves.easeOutBack),
        ),
      );

      // Rise up from portal
      add(
        MoveByEffect(
          Vector2(0, -riseAmount),
          EffectController(duration: riseDuration, curve: Curves.easeOutCubic),
        ),
      );
    });
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
            radius: 20,
            position: position.clone(),
            anchor: Anchor.center,
            paint: Paint()
              ..color = _elementColor(template.element).withOpacity(0.5)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
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

  @override
  void update(double dt) {
    super.update(dt);
    if (isDead) return;

    // Decay hit flash and push into body
    _hitFlash = (_hitFlash - dt * 6.0).clamp(0.0, 1.0);
    _body.hitFlash = _hitFlash;
    if (isAnyBoss) {
      _body.hpPercent = unit.hpPercent;
    }

    // Summoner buff decay
    if (_summonerBuffTimer > 0) {
      _summonerBuffTimer -= dt;
      if (_summonerBuffTimer <= 0) {
        _summonerBuffTimer = 0;
        _summonerBuffSpeedMult = 1.0;
        _summonerBuffDamageMult = 1.0;
      }
    }

    // Update boss phases for mega bosses
    if (isMegaBoss) {
      _updateBossPhase();
    }

    // Check hydra split condition
    if (bossArchetype == BossArchetype.hydra) {
      _checkHydraSplit();
    }

    // Hydra slam cooldown decay
    _hydraSlamCooldown = (_hydraSlamCooldown - dt).clamp(0, double.infinity);

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
  }

  //
  // SIMPLE, FLOWY BOSS AI (CLEAN ORBIT RING, NO GLITCHING INTO CENTER)
  //

  void _updateSimpleBossAI(double dt) {
    // Juggernaut charge overrides normal orbit movement
    if (_isCharging) {
      _updateCharge(dt);
      return;
    }

    // Hydra ground slam animation overrides normal movement
    if (_hydraIsSlammingGround) {
      _updateHydraSlam(dt);
      return;
    }

    // 1) Maintain a “sticky” focus guardian so we don't retarget every frame.
    _focusGuardianRetargetTimer -= dt;
    if (_focusGuardian == null ||
        _focusGuardian!.isDead ||
        _focusGuardianRetargetTimer <= 0 ||
        _focusGuardian!.position.distanceTo(targetOrb.position) > 2200) {
      _focusGuardian = gameRef.getRandomGuardianInRange(
        center: targetOrb.position,
        range: 2000,
      );
      _focusGuardianRetargetTimer = 2.5 + _rng.nextDouble() * 2.0;
    }

    final HoardGuardian? focusGuardian = _focusGuardian;
    final Vector2 focusCenter = focusGuardian?.position ?? targetOrb.position;
    final Vector2 toCenter = focusCenter - position;
    final double distToCenter = toCenter.length;

    // 2) Archetype-based preferred radius band (outside the inner guardian ring).
    double desiredRadius;
    double minRadius;
    double maxRadius;
    double speedFactor = isMegaBoss ? 0.9 : 0.7;

    switch (bossArchetype) {
      case BossArchetype.juggernaut:
        desiredRadius = isMegaBoss ? 520.0 : 430.0;
        minRadius = desiredRadius - 80.0;
        maxRadius = desiredRadius + 110.0;
        speedFactor *= 1.05;
        break;

      case BossArchetype.summoner:
        desiredRadius = isMegaBoss ? 640.0 : 540.0;
        minRadius = desiredRadius - 90.0;
        maxRadius = desiredRadius + 130.0;
        speedFactor *= 0.95;
        break;

      case BossArchetype.artillery:
        desiredRadius = isMegaBoss ? 720.0 : 620.0;
        minRadius = desiredRadius - 80.0;
        maxRadius = desiredRadius + 150.0;
        speedFactor *= 0.9;
        break;

      case BossArchetype.hydra:
        // Hydra prefers closer range - it's a bruiser that slams
        final hydraRadii = [450.0, 400.0, 350.0, 300.0, 260.0];
        desiredRadius = hydraRadii[hydraGeneration.clamp(0, 4)];
        minRadius = desiredRadius - 60.0;
        maxRadius = desiredRadius + 100.0;
        speedFactor *= 0.85 + hydraGeneration * 0.1; // Smaller = faster
        break;

      default:
        desiredRadius = isMegaBoss ? 600.0 : 500.0;
        minRadius = desiredRadius - 90.0;
        maxRadius = desiredRadius + 120.0;
        break;
    }

    // Add a comfort band inside the min/max so we don't bounce on exact edges.
    final double innerComfort = minRadius + 40.0;
    final double outerComfort = maxRadius - 40.0;

    // 3) Periodically flip the anchor to the opposite side ("half orbit").
    _bossAnchorSwapTimer -= dt;
    if (_bossAnchorSwapTimer <= 0.0) {
      final double jitter = (_rng.nextDouble() - 0.5) * 0.6; // ±0.3 rad
      _bossAnchorAngleTarget =
          (_bossAnchorAngleTarget + pi + jitter) % (2 * pi);

      _bossAnchorSwapTimer =
          _bossAnchorSwapInterval + (_rng.nextDouble() - 0.5) * 2.0;
    }

    // Smoothly move anchor angle toward target
    final double angleDiff = _wrapAngle(
      _bossAnchorAngleTarget - _bossAnchorAngle,
    );
    _bossAnchorAngle += angleDiff * (dt * 1.5);

    // 4) Compute our *ideal perch* on the ring.
    final Vector2 radialDir = distToCenter > 0.001
        ? (toCenter / distToCenter)
        : Vector2(1, 0);
    final Vector2 anchorOffset =
        Vector2(cos(_bossAnchorAngle), sin(_bossAnchorAngle)) * desiredRadius;
    final Vector2 targetPerch = focusCenter + anchorOffset;

    // 5) Build movement direction.
    Vector2 moveDir = Vector2.zero();

    if (distToCenter < 1.0) {
      moveDir = Vector2(1, 0);
    } else {
      final radialIn = radialDir;
      final radialOut = -radialDir;

      if (distToCenter < innerComfort) {
        moveDir += radialOut;
      } else if (distToCenter > outerComfort) {
        moveDir += radialIn;
      }

      final Vector2 toPerch = targetPerch - position;
      final double distToPerch = toPerch.length;

      if (distToPerch > 15.0) {
        moveDir += toPerch / (distToPerch == 0 ? 1 : distToPerch) * 0.7;
      } else {
        moveDir += _computeSeparation(radius: size.x * 1.0) * 0.3;
      }

      moveDir += _computeSeparation(radius: size.x * 1.2) * 0.2;
    }

    if (moveDir.length2 > 0) {
      moveDir.normalize();
    }

    final double bossSpeed = _maxSpeed * speedFactor * _summonerBuffSpeedMult;
    final Vector2 desiredVel = moveDir * bossSpeed;

    final double bossTurnSpeed = isMegaBoss ? 3.0 : 2.0;
    _velocity.lerp(desiredVel, dt * bossTurnSpeed);
    position += _velocity * dt;

    if (_velocity.length2 > 10) {
      final double targetAngle = atan2(_velocity.y, _velocity.x);
      angle = _smoothAngle(angle, targetAngle, dt * 6.0);
    }

    _bossAttackCooldown -= dt;
    if (_bossAttackCooldown <= 0) {
      _performBossAttack();
    }
  }

  void _updateCharge(double dt) {
    if (!_isCharging || _chargeStart == null || _chargeEnd == null) return;

    _chargeTime += dt;
    final t = (_chargeTime / _chargeDuration).clamp(0.0, 1.0);
    position = _chargeStart! + (_chargeEnd! - _chargeStart!) * t;

    // Damage along the path - only hit each guardian ONCE per charge
    final chargeDmg = (contactDamage * 1.2).round();
    final guardians = gameRef.getGuardiansInRange(center: position, range: 70);
    for (final g in guardians) {
      if (!g.isDead && !_chargeHitGuardians.contains(g)) {
        _chargeHitGuardians.add(g); // Mark as hit this charge
        print(
          '[JUGGERNAUT-CHARGE] Hitting ${g.unit.name} for $chargeDmg (base contactDamage=$contactDamage)',
        );
        g.takeDamage(
          chargeDmg,
          source: 'Juggernaut Charge (${template.id})',
          isBossAttack: true,
        );
      }
    }

    if (position.distanceTo(targetOrb.position) < 90 && !_chargeHitOrb) {
      _chargeHitOrb = true;
      targetOrb.takeDamage((contactDamage * 0.8).round());
    }

    if (t >= 1.0) {
      _isCharging = false;
      _chargeStart = null;
      _chargeEnd = null;
      _chargeHitGuardians.clear(); // Reset for next charge
      _chargeHitOrb = false;
      _triggerScreenShake(isMegaBoss ? 12.0 : 8.0);
    }
  }

  void _startChargeAttack() {
    if (_isCharging) return;

    final HoardGuardian? focus =
        _focusGuardian ??
        gameRef.getRandomGuardianInRange(
          center: targetOrb.position,
          range: 2000,
        );

    final Vector2 center = focus?.position ?? targetOrb.position;
    final Vector2 dir = (center - position).normalized();

    _chargeStart = position.clone();
    _chargeEnd = center + dir * 150;
    _chargeTime = 0.0;
    _chargeDuration = isMegaBoss ? 1.1 : 0.8;
    _isCharging = true;

    // little windup flash
    _hitFlash = 1.0;
  }

  void _empowerMinionsPulse() {
    final minions = gameRef.getRandomEnemies(isMegaBoss ? 6 : 4);
    for (final m in minions) {
      if (m == this || m.isAnyBoss) continue;

      m._applySummonerBuff(
        duration: isMegaBoss ? 6.0 : 4.5,
        speedMult: 1.3,
        damageMult: 1.2,
      );

      // small visual ring
      gameRef.world.add(
        CircleComponent(
          radius: m._logicalRadius * 1.1,
          position: m.position.clone(),
          anchor: Anchor.center,
          paint: Paint()
            ..color = _elementColor(template.element).withOpacity(0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        )..add(
          SequenceEffect([
            ScaleEffect.to(Vector2.all(1.4), EffectController(duration: 0.4)),
            OpacityEffect.fadeOut(EffectController(duration: 0.3)),
            RemoveEffect(),
          ]),
        ),
      );
    }
  }

  void _dropMinesAroundOrb(int count) {
    for (int i = 0; i < count; i++) {
      final angle = (i / count) * 2 * pi + _rng.nextDouble() * 0.5;
      final radius = 380.0 + _rng.nextDouble() * 220.0;
      final pos = targetOrb.position + Vector2(cos(angle), sin(angle)) * radius;

      gameRef.world.add(
        ArtilleryMine(
          position: pos,
          triggerRadius: 80,
          blastRadius: 120,
          damage: (shotDamage * (isMegaBoss ? 1.0 : 0.7)).round(),
          color: _elementColor(template.element),
        ),
      );
    }
  }

  void _performBossAttack() {
    final rng = _rng.nextDouble();
    final archetype = bossArchetype;

    if (archetype == null) {
      if (rng < 0.5) {
        _fireRadialVolley(projectiles: isMegaBoss ? 16 : 10);
        _bossAttackCooldown = isMegaBoss ? 3.2 : 3.6;
      } else {
        if (!isMegaBoss) {
          _summonMinions(isBoss ? 5 : 3);
        } else {
          _summonMinions(6);
        }
        _bossAttackCooldown = isMegaBoss ? 3.4 : 3.0;
      }
      return;
    }

    switch (archetype) {
      case BossArchetype.juggernaut:
        // Pure melee/bruiser: charges + close-range volleys, NO summons
        if (rng < 0.5) {
          // charge more often
          _startChargeAttack();
          _bossAttackCooldown = isMegaBoss ? 3.6 : 4.0;
        } else {
          // short-range pressure volley
          _fireRadialVolley(projectiles: isMegaBoss ? 9 : 7, damageScale: 0.85);
          _bossAttackCooldown = isMegaBoss ? 3.2 : 3.6;
        }
        if (rng < 0.2) {
          // extra chance to charge
          _summonMinions(2);
        }
        break;

      case BossArchetype.summoner:
        if (rng < 0.55) {
          _summonMinions(isMegaBoss ? 8 : 5);
          _bossAttackCooldown = isMegaBoss ? 3.3 : 2.9;
        } else {
          _empowerMinionsPulse();
          _bossAttackCooldown = isMegaBoss ? 3.8 : 3.4;
        }
        break;

      case BossArchetype.artillery:
        if (rng < 0.5) {
          _fireRadialVolley(
            projectiles: isMegaBoss ? 14 : 10,
            damageScale: 0.7,
          );
          _bossAttackCooldown = isMegaBoss ? 3.7 : 3.9;
        } else {
          _dropMinesAroundOrb(isMegaBoss ? 4 : 3);
          _bossAttackCooldown = isMegaBoss ? 4.0 : 4.4;
        }
        break;
      case BossArchetype.hydra:
        _performHydraAttack(rng);
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HYDRA SPLIT LOGIC
  // ═══════════════════════════════════════════════════════════════════════════

  void _checkHydraSplit() {
    if (_hydraSplitTriggered) return;
    if (hydraCanSplit <= 0) return;

    // Split when HP drops below threshold
    // Gen 0 splits at 60%, subsequent gens split at lower thresholds
    final splitThresholds = [0.60, 0.50, 0.40, 0.30, 0.0];
    final threshold = splitThresholds[hydraGeneration.clamp(0, 4)];

    if (unit.hpPercent <= threshold) {
      _hydraSplitTriggered = true;
      _performHydraSplit();
    }
  }

  void _performHydraSplit() {
    print(
      '[HYDRA-SPLIT] Generation $hydraGeneration splitting into ${_getSplitCount()} children',
    );

    // Visual: flash and pulse
    _hitFlash = 1.0;
    _triggerScreenShake(12.0 + (4 - hydraGeneration) * 4.0);

    // Spawn split children
    final childCount = _getSplitCount();
    final childGen = hydraGeneration + 1;

    for (int i = 0; i < childCount; i++) {
      final angle = (i / childCount) * 2 * pi + _rng.nextDouble() * 0.5;
      final distance = _logicalRadius * 2.5;
      final spawnPos = position + Vector2(cos(angle), sin(angle)) * distance;

      // Build the child unit with scaled stats
      final childUnit = SurvivalEnemyCatalog.buildHydraBoss(
        template: template,
        wave: gameRef.currentWave,
        generation: childGen,
      );

      // Create the child enemy
      final child = HoardEnemy(
        position: spawnPos,
        targetOrb: targetOrb,
        template: template,
        role: role,
        unit: childUnit,
        sizeScale: sizeScale,
        bossArchetype: BossArchetype.hydra,
        isMegaBoss: childGen <= 1, // Gen 0 & 1 are "mega", rest mini
        speedMultiplier: speedMultiplier,
        hydraGeneration: childGen,
      );

      // If gen 2+, they're mini bosses not full bosses
      if (childGen >= 2) {
        child.isMiniBoss = true;
        child.isBoss = false;
      }

      gameRef.addHoardEnemy(child);

      // Spawn split particle effect
      _spawnSplitEffect(spawnPos);
    }

    // Original dies after splitting (no reward)
    _dieWithoutReward();
  }

  int _getSplitCount() {
    // Gen 0 splits into 4, subsequent gens split into 2-3
    if (hydraGeneration == 0) return 4;
    if (hydraGeneration == 1) return 3;
    if (hydraGeneration == 2) return 2;
    return 2;
  }

  void _spawnSplitEffect(Vector2 pos) {
    final color = _elementColor(template.element);

    // Burst of particles
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * pi;
      final speed = 100 + _rng.nextDouble() * 80;

      gameRef.world.add(
        CircleComponent(
          radius: 6,
          position: pos.clone(),
          anchor: Anchor.center,
          paint: Paint()..color = color.withOpacity(0.8),
        )..add(
          SequenceEffect([
            MoveEffect.by(
              Vector2(cos(angle), sin(angle)) * speed,
              EffectController(duration: 0.5, curve: Curves.easeOut),
            ),
            OpacityEffect.fadeOut(EffectController(duration: 0.2)),
            RemoveEffect(),
          ]),
        ),
      );
    }

    // Central flash
    gameRef.world.add(
      CircleComponent(
        radius: 20,
        position: pos.clone(),
        anchor: Anchor.center,
        paint: Paint()..color = Colors.white.withOpacity(0.9),
      )..add(
        SequenceEffect([
          ScaleEffect.to(Vector2.all(3), EffectController(duration: 0.3)),
          OpacityEffect.fadeOut(EffectController(duration: 0.2)),
          RemoveEffect(),
        ]),
      ),
    );
  }

  /// Die without giving rewards (used when splitting)
  void _dieWithoutReward() {
    if (isDead) return;
    isDead = true;

    // Dramatic death for hydra split
    _triggerScreenShake(15.0);

    // Explosion particles
    for (int i = 0; i < 16; i++) {
      final angle = (i / 16) * pi * 2;
      final speed = 150 + _rng.nextDouble() * 100;

      gameRef.world.add(
        CircleComponent(
          radius: 10,
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

    add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.zero(),
          EffectController(duration: 0.3, curve: Curves.easeInBack),
        ),
        RemoveEffect(),
      ]),
    );

    gameRef.removeEnemy(this);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HYDRA ATTACKS
  // ═══════════════════════════════════════════════════════════════════════════

  void _performHydraAttack(double rng) {
    // Hydra attack patterns based on generation
    // Gen 0: Ground slams + massive volleys + spawns mini hydras
    // Gen 1-2: Slams + volleys
    // Gen 3-4: Fast attacks, more desperate

    if (hydraGeneration == 0) {
      // Original Hydra - devastating attacks
      if (rng < 0.35) {
        _startHydraGroundSlam();
        _bossAttackCooldown = 4.5;
      } else if (rng < 0.65) {
        _fireHydraMultiVolley();
        _bossAttackCooldown = 3.8;
      } else {
        // Spawn some regular minions (not hydra children)
        _summonMinions(4);
        _bossAttackCooldown = 4.0;
      }
    } else if (hydraGeneration <= 2) {
      // Medium hydras
      if (rng < 0.4) {
        _startHydraGroundSlam();
        _bossAttackCooldown = 3.5 - hydraGeneration * 0.3;
      } else {
        _fireRadialVolley(projectiles: 8 - hydraGeneration, damageScale: 0.8);
        _bossAttackCooldown = 3.0 - hydraGeneration * 0.2;
      }
    } else {
      // Small hydras - fast and aggressive
      if (rng < 0.5) {
        _startChargeAttack(); // They charge like juggernauts
        _bossAttackCooldown = 2.5;
      } else {
        _fireRadialVolley(projectiles: 5, damageScale: 0.6);
        _bossAttackCooldown = 2.2;
      }
    }
  }

  void _startHydraGroundSlam() {
    if (_hydraIsSlammingGround || _hydraSlamCooldown > 0) return;

    _hydraIsSlammingGround = true;
    _hydraSlamTimer = 0;
    _velocity = Vector2.zero();
    _hydraSlamCooldown = 3.0; // simple global cooldown

    // Visual telegraph - rise up
    add(
      MoveByEffect(
        Vector2(0, -_logicalRadius * 0.5),
        EffectController(duration: 0.4, curve: Curves.easeOut),
      ),
    );

    // Warning circle on ground
    final warningRadius = _logicalRadius * (1.5 + (3 - hydraGeneration) * 0.5);
    final warningPos = position.clone() + Vector2(0, _logicalRadius * 0.5);

    // Soft red glow
    gameRef.world.add(
      CircleComponent(
        radius: warningRadius,
        position: warningPos,
        anchor: Anchor.center,
        paint: Paint()
          ..color = Colors.red.withOpacity(0.16)
          ..style = PaintingStyle.fill,
      )..add(
        SequenceEffect([
          OpacityEffect.fadeOut(EffectController(duration: 0.6)),
          RemoveEffect(),
        ]),
      ),
    );

    // Thin alchemical outline ring
    gameRef.world.add(
      CircleComponent(
        radius: warningRadius,
        position: warningPos,
        anchor: Anchor.center,
        paint: Paint()
          ..color = Colors.red.withOpacity(0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      )..add(
        SequenceEffect([
          OpacityEffect.fadeOut(EffectController(duration: 0.6)),
          RemoveEffect(),
        ]),
      ),
    );
  }

  void _updateHydraSlam(double dt) {
    _hydraSlamTimer += dt;

    // Wind up for 0.5s, then slam
    if (_hydraSlamTimer >= 0.5 && _hydraSlamTimer < 0.55) {
      // Execute the slam
      _executeHydraSlam();
    }

    // Recovery time
    if (_hydraSlamTimer >= 1.0) {
      _hydraIsSlammingGround = false;
      _hydraSlamTimer = 0;

      // Move back down
      add(
        MoveByEffect(
          Vector2(0, _logicalRadius * 0.5),
          EffectController(duration: 0.3, curve: Curves.easeIn),
        ),
      );
    }
  }

  void _executeHydraSlam() {
    final slamRadius = _logicalRadius * (2.5 + (4 - hydraGeneration) * 0.5);
    final slamDamage = (contactDamage * 1.5).round();

    // Screen shake scales with hydra size
    _triggerScreenShake(10.0 + (4 - hydraGeneration) * 5.0);

    // Damage guardians in range
    final guardians = gameRef.getGuardiansInRange(
      center: position,
      range: slamRadius,
    );
    for (final g in guardians) {
      if (!g.isDead) {
        g.takeDamage(
          slamDamage,
          source: 'Hydra Ground Slam (Gen $hydraGeneration)',
          isBossAttack: true,
        );
      }
    }

    // Damage orb if in range
    if (position.distanceTo(targetOrb.position) < slamRadius) {
      targetOrb.takeDamage((slamDamage * 0.8).round());
    }

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (!isMounted || isDead) return;

        final baseRadius = 28.0;

        // Soft outer glow
        gameRef.world.add(
          CircleComponent(
            radius: baseRadius,
            position: position.clone(),
            anchor: Anchor.center,
            paint: Paint()
              ..color = _elementColor(template.element).withOpacity(0.22)
              ..style = PaintingStyle.fill,
          )..add(
            SequenceEffect([
              ScaleEffect.to(
                Vector2.all(slamRadius / baseRadius),
                EffectController(duration: 0.4, curve: Curves.easeOut),
              ),
              OpacityEffect.fadeOut(EffectController(duration: 0.2)),
              RemoveEffect(),
            ]),
          ),
        );

        // Thin alchemical shockwave ring
        gameRef.world.add(
          CircleComponent(
            radius: baseRadius,
            position: position.clone(),
            anchor: Anchor.center,
            paint: Paint()
              ..color = _elementColor(template.element).withOpacity(0.85)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.12, // key: extremely thin, then scaled
          )..add(
            SequenceEffect([
              ScaleEffect.to(
                Vector2.all(slamRadius / baseRadius),
                EffectController(duration: 0.4, curve: Curves.easeOut),
              ),
              OpacityEffect.fadeOut(EffectController(duration: 0.2)),
              RemoveEffect(),
            ]),
          ),
        );
      });
    }

    // Spawn debris particles
    for (int i = 0; i < 12; i++) {
      final angle = (i / 12) * 2 * pi + _rng.nextDouble() * 0.3;
      final speed = 150 + _rng.nextDouble() * 100;

      gameRef.world.add(
        RectangleComponent(
          size: Vector2(8, 8),
          position: position.clone(),
          anchor: Anchor.center,
          angle: _rng.nextDouble() * pi,
          paint: Paint()
            ..color = _elementColor(template.element).withOpacity(0.7),
        )..add(
          SequenceEffect([
            MoveEffect.by(
              Vector2(cos(angle), sin(angle)) * speed,
              EffectController(duration: 0.5, curve: Curves.easeOut),
            ),
            OpacityEffect.fadeOut(EffectController(duration: 0.2)),
            RemoveEffect(),
          ]),
        ),
      );
    }
  }

  /// Multi-directional volley unique to the original Hydra
  void _fireHydraMultiVolley() {
    final color = _elementColor(template.element);
    final damage = (shotDamage * 0.8).round();

    // Fire in 4 "heads" - groups of projectiles
    for (int head = 0; head < 4; head++) {
      final baseAngle = (head / 4) * 2 * pi + _timeAlive * 0.1;

      // Each head fires 3 projectiles in a spread
      for (int p = 0; p < 3; p++) {
        final spreadAngle = baseAngle + (p - 1) * 0.2;
        final dir = Vector2(cos(spreadAngle), sin(spreadAngle));
        final end = position + dir * 700;

        gameRef.spawnEnemyProjectile(
          start: position.clone() + dir * _logicalRadius,
          targetPosition: end,
          color: color,
          onHit: () {
            final guardians = gameRef.getGuardiansInRange(
              center: end,
              range: 60,
            );
            for (final g in guardians) {
              g.takeDamage(damage, source: 'Hydra Volley');
            }
            if (end.distanceTo(targetOrb.position) < 80) {
              targetOrb.takeDamage(damage);
            }
          },
        );
      }
    }
  }

  //
  // REGULAR ENEMY MOVEMENT / AI
  //

  void _updateMovementAndAI(double dt) {
    // Handle attached leecher separately
    if (role == EnemyRole.leecher && _isAttached) {
      _updateLeecherAttached(dt);
      return;
    }

    final targetGuardian = gameRef.getRandomGuardianInRange(
      center: position,
      range: 800,
    );

    Vector2 steeringForce = Vector2.zero();
    double currentMaxSpeed = _maxSpeed * _summonerBuffSpeedMult;

    if (role == EnemyRole.shooter) {
      steeringForce = _getShooterSteering(targetGuardian, dt);
      if (_shooterInPosition) {
        _tryShoot(targetGuardian);
      }
    } else if (role == EnemyRole.bomber) {
      steeringForce = _getBomberSteering(targetGuardian, dt);
    } else if (role == EnemyRole.leecher) {
      steeringForce = _getLeecherSteering(targetGuardian, dt);
    } else {
      steeringForce = _getChargerSteering(
        targetGuardian,
        dt,
        outSpeed: (s) => currentMaxSpeed = s * _summonerBuffSpeedMult,
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
    // 1. Swarm units skip separation
    if (template.tier == EnemyTier.swarm) {
      return Vector2.zero();
    }

    // 2. If there are many enemies, only elites/bosses separate
    final manyEnemies = gameRef.enemyCount > 50;
    final isHighPriority =
        template.tier.index >= EnemyTier.elite.index || isAnyBoss;

    if (manyEnemies && !isHighPriority) {
      return Vector2.zero();
    }

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
      if (gDist < oDist * 0.9) {
        dest = guardian.position;
        huntingGuardian = true;
      }
    }

    outSpeed(_maxSpeed);

    final distToTarget = position.distanceTo(dest);
    if (distToTarget < (huntingGuardian ? 40 : 55)) {
      _applyContactDamage(
        huntingGuardian ? guardian! : targetOrb,
        huntingGuardian,
      );
    }

    return (dest - position).normalized();
  }

  Vector2 _getShooterSteering(HoardGuardian? guardian, double dt) {
    final orbPos = targetOrb.position;
    final toOrb = orbPos - position;
    final distToOrb = toOrb.length;

    // Phase 1: Fly in until we reach ideal range from the ORB
    if (!_shooterInPosition) {
      if (distToOrb <= _idealRange + 30) {
        // We've arrived at orbit distance - start orbiting
        _shooterInPosition = true;
        // Set orbit angle based on where we are relative to orb
        _orbitAngle = atan2(position.y - orbPos.y, position.x - orbPos.x);
      } else {
        // Still flying in - head toward a point at ideal range, not the center
        final approachDir = toOrb.normalized();
        return approachDir;
      }
    }

    // Phase 2: Orbit around the ORB at ideal range
    // Vary orbit speed slightly per enemy to prevent clumping
    final orbitSpeedVariance = 0.2 + (hashCode % 100) * 0.003;
    _orbitAngle += dt * orbitSpeedVariance;

    // Calculate our desired position on the orbit ring
    final orbitPos =
        orbPos +
        Vector2(cos(_orbitAngle) * _idealRange, sin(_orbitAngle) * _idealRange);

    final toOrbitPos = orbitPos - position;
    final distToOrbitPos = toOrbitPos.length;

    // If we drifted too far in or out, correct
    if (distToOrb > _idealRange + 60) {
      // Too far out - move in while continuing orbit
      return (toOrb.normalized() * 0.6 + toOrbitPos.normalized() * 0.4)
          .normalized();
    } else if (distToOrb < _idealRange - 40) {
      // Too close to center - back away!
      return -toOrb.normalized();
    }

    // Normal orbit - follow the ring
    if (distToOrbitPos > 10) {
      return toOrbitPos.normalized();
    }

    // Very close to orbit position - gentle tangential movement
    final tangent = Vector2(-sin(_orbitAngle), cos(_orbitAngle));
    return tangent;
  }

  /// Bomber steering: flies fast and straight, explodes on contact
  Vector2 _getBomberSteering(HoardGuardian? guardian, double dt) {
    Vector2 dest = targetOrb.position;
    bool huntingGuardian = false;

    if (guardian != null) {
      final gDist = position.distanceTo(guardian.position);
      final oDist = position.distanceTo(targetOrb.position);
      if (gDist < oDist * 1.2) {
        dest = guardian.position;
        huntingGuardian = true;
      }
    }

    final distToTarget = position.distanceTo(dest);

    if (distToTarget < 45) {
      _explode(huntingGuardian ? guardian : targetOrb, huntingGuardian);
      return Vector2.zero();
    }

    return (dest - position).normalized();
  }

  /// Leecher steering: chases target to attach
  Vector2 _getLeecherSteering(HoardGuardian? guardian, double dt) {
    Vector2 dest = targetOrb.position;
    bool huntingGuardian = false;

    if (guardian != null) {
      final gDist = position.distanceTo(guardian.position);
      final oDist = position.distanceTo(targetOrb.position);
      if (gDist < oDist * 0.8) {
        dest = guardian.position;
        huntingGuardian = true;
      }
    }

    final distToTarget = position.distanceTo(dest);

    if (distToTarget < 35) {
      // If hunting a guardian, guardian is non-null here so assert non-null to
      // ensure a non-null Object is passed.
      _attachToTarget(huntingGuardian ? guardian! : targetOrb, huntingGuardian);
      return Vector2.zero();
    }

    return (dest - position).normalized();
  }

  /// Leecher attached behavior: stick to target, drain HP
  void _updateLeecherAttached(double dt) {
    if (_attachedTarget == null) {
      _isAttached = false;
      return;
    }

    bool targetDead = false;
    if (_attachedTarget is HoardGuardian) {
      targetDead = (_attachedTarget as HoardGuardian).isDead;
    } else if (_attachedTarget is AlchemyOrb) {
      targetDead = (_attachedTarget as AlchemyOrb).currentHp <= 0;
    }

    if (targetDead) {
      _detachFromTarget();
      return;
    }

    _orbitAngle += dt * 2.0;
    final offset = Vector2(cos(_orbitAngle), sin(_orbitAngle)) * 25;
    if (_attachedTarget is PositionComponent) {
      position = (_attachedTarget as PositionComponent).position + offset;
    }

    _leechTickTimer += dt;
    if (_leechTickTimer >= _leechTickInterval) {
      _leechTickTimer = 0;

      if (_attachedTarget is HoardGuardian) {
        (_attachedTarget as HoardGuardian).takeDamage(
          _leechDamagePerTick,
          source: 'Leecher Drain (${template.id})',
        );
      } else if (_attachedTarget is AlchemyOrb) {
        (_attachedTarget as AlchemyOrb).takeDamage(_leechDamagePerTick);
      }

      unit.heal(_leechHealPerTick);

      _body.add(
        ScaleEffect.by(
          Vector2.all(1.2),
          EffectController(duration: 0.1, reverseDuration: 0.1),
        ),
      );

      _spawnDrainParticle();
    }
  }

  void _attachToTarget(Object target, bool isGuardian) {
    _isAttached = true;
    _attachedTarget = target;
    _leechTickTimer = 0;
    _orbitAngle = _rng.nextDouble() * pi * 2;

    if (target is HoardGuardian) {
      target.takeDamage(
        contactDamage,
        source: 'Leecher Attach (${template.id})',
      );
    } else if (target is AlchemyOrb) {
      target.takeDamage(contactDamage);
    }

    _body.bodyOpacity = 0.7;
  }

  void _detachFromTarget() {
    _isAttached = false;
    _attachedTarget = null;
    _body.bodyOpacity = 1.0;
  }

  void _spawnDrainParticle() {
    if (!(_attachedTarget is PositionComponent)) return;

    final PositionComponent target = _attachedTarget as PositionComponent;
    final drainColor = const Color(0xFFB71C1C);
    gameRef.world.add(
      CircleComponent(
        radius: 4,
        position: target.position.clone(),
        anchor: Anchor.center,
        paint: Paint()..color = drainColor,
      )..add(
        SequenceEffect([
          MoveEffect.to(
            position.clone(),
            EffectController(duration: 0.3, curve: Curves.easeIn),
          ),
          RemoveEffect(),
        ]),
      ),
    );
  }

  void _explode(Object? target, bool isGuardian) {
    if (isDead) return;

    final explosionRadius = 80.0;
    final explosionColor = _elementColor(template.element);

    if (target is HoardGuardian) {
      target.takeDamage(
        contactDamage,
        source: 'Bomber Explosion (${template.id})',
      );
    } else if (target is AlchemyOrb) {
      target.takeDamage(contactDamage);
    }

    final nearbyGuardians = gameRef.getGuardiansInRange(
      center: position,
      range: explosionRadius,
    );
    for (final g in nearbyGuardians) {
      if (g != target) {
        g.takeDamage(
          (contactDamage * 0.5).round(),
          source: 'Bomber Splash (${template.id})',
        );
      }
    }

    if (position.distanceTo(targetOrb.position) < explosionRadius &&
        target != targetOrb) {
      targetOrb.takeDamage((contactDamage * 0.5).round());
    }

    gameRef.world.add(
      CircleComponent(
        radius: 20,
        position: position.clone(),
        anchor: Anchor.center,
        paint: Paint()..color = explosionColor,
      )..add(
        SequenceEffect([
          ScaleEffect.to(
            Vector2.all(explosionRadius / 20),
            EffectController(duration: 0.2, curve: Curves.easeOut),
          ),
          OpacityEffect.fadeOut(EffectController(duration: 0.15)),
          RemoveEffect(),
        ]),
      ),
    );

    _triggerScreenShake(6.0);
    _die();
  }

  void _tryShoot(HoardGuardian? guardian) {
    if (_attackCooldown > 0) return;

    final projectileColor = _elementColor(template.element);
    final dmg = shotDamage;
    final isBoss = isAnyBoss;

    if (guardian != null && !guardian.isDead) {
      print(
        '[ENEMY-SHOT] ${template.id} shooting at ${guardian.unit.name} for $dmg damage',
      );
      gameRef.spawnEnemyProjectile(
        start: position.clone(),
        targetPosition: guardian.position.clone(),
        color: projectileColor,
        onHit: () => guardian.takeDamage(
          dmg,
          source: 'Enemy Shot (${template.id})',
          isBossAttack: isBoss,
        ),
      );
    } else {
      gameRef.spawnEnemyProjectile(
        start: position.clone(),
        targetPosition: targetOrb.position.clone(),
        color: projectileColor,
        onHit: () => targetOrb.takeDamage(dmg),
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

  void _applyContactDamage(Object target, bool isGuardian) {
    if (isAnyBoss) {
      _body.hpPercent = unit.hpPercent;
      if (_meleeCooldown <= 0) {
        if (target is HoardGuardian) {
          print(
            '[BOSS-MELEE] ${template.id} '
            'role=$role '
            'dmg=$contactDamage '
            'target=${target.unit.name} '
            'hpBefore=${target.unit.currentHp}',
          );
          target.takeDamage(
            contactDamage,
            source: 'Boss Melee (${template.id})',
            isBossAttack: true,
          );
        } else if (target is AlchemyOrb) {
          print(
            '[BOSS-MELEE] ${template.id} '
            'role=$role '
            'dmg=$contactDamage '
            'target=ORB '
            'hpBefore=${target.currentHp}',
          );
          target.takeDamage(contactDamage);
        }
        _meleeCooldown = 0.9;
      }
    } else {
      if (target is HoardGuardian) {
        print(
          '[ENEMY-MELEE] ${template.id} '
          'role=$role '
          'dmg=$contactDamage '
          'target=${target.unit.name} '
          'hpBefore=${target.unit.currentHp}',
        );
        target.takeDamage(
          contactDamage,
          source: 'Enemy Melee (${template.id})',
        );
      } else if (target is AlchemyOrb) {
        print(
          '[ENEMY-MELEE] ${template.id} '
          'role=$role '
          'dmg=$contactDamage '
          'target=ORB '
          'hpBefore=${target.currentHp}',
        );
        target.takeDamage(contactDamage);
      }
      _die();
    }
  }

  double _smoothAngle(double current, double target, double rate) {
    double diff = target - current;
    while (diff < -pi) diff += 2 * pi;
    while (diff > pi) diff -= 2 * pi;
    return current + diff * rate;
  }

  double _wrapAngle(double a) {
    while (a < -pi) a += 2 * pi;
    while (a > pi) a -= 2 * pi;
    return a;
  }

  void takeDamage(int amount) {
    print(
      '[-HIT] ${unit.name} '
      'incoming=$amount '
      'hpBefore=${unit.currentHp} '
      'hpAfter=${unit.currentHp - amount}',
    );
    if (isDead) return;

    if (_isInvulnerable) {
      _hitFlash = 0.5;
      return;
    }

    _timeSinceLastDamage = 0;
    unit.takeDamage(amount);

    _hitFlash = 1.0;

    if (unit.isDead) _die();
  }

  void _applySummonerBuff({
    required double duration,
    required double speedMult,
    required double damageMult,
  }) {
    _summonerBuffTimer = duration;
    _summonerBuffSpeedMult = max(_summonerBuffSpeedMult, speedMult);
    _summonerBuffDamageMult = max(_summonerBuffDamageMult, damageMult);
    _hitFlash = max(_hitFlash, 0.7);
  }

  void _die() {
    if (isDead) return;
    isDead = true;

    if (isAnyBoss) {
      _triggerScreenShake(20.0);

      for (int i = 0; i < 20; i++) {
        final angle = (i / 20) * pi * 2;
        final speed = 200 + _rng.nextDouble() * 100;

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
      (_rng.nextDouble() - 0.5) * intensity,
      (_rng.nextDouble() - 0.5) * intensity,
    );
    gameRef.cameraComponent.viewfinder.position += offset;
    gameRef.cameraComponent.viewfinder.add(
      MoveEffect.by(-offset, EffectController(duration: 0.1)),
    );
  }

  void _fireRadialVolley({int projectiles = 10, double damageScale = 1.0}) {
    final col = _elementColor(template.element);

    final baseScale = isMegaBoss ? 1.0 : 0.7;
    final damage = (shotDamage * baseScale * damageScale).round();

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

  /// Update boss phase based on HP percentage
  void _updateBossPhase() {}

  /// Take damage with affinity calculation
  void takeDamageWithAffinity(int baseDamage, DamageAffinity attackAffinity) {
    final affinityMult = getAffinityMultiplier(
      attackAffinity,
      template.creatureFamily,
    );
    final finalDamage = (baseDamage * affinityMult).round();

    takeDamage(finalDamage);

    if (affinityMult > 1.2) {
      _showEffectivenessText('SUPER!', Colors.green);
    } else if (affinityMult < 0.8) {
      _showEffectivenessText('Resist', Colors.red.shade300);
    }
  }

  void _showEffectivenessText(String text, Color color) {
    final textComponent = TextComponent(
      text: text,
      position: position.clone() + Vector2(0, -50),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    textComponent.add(
      SequenceEffect([
        MoveByEffect(
          Vector2(0, -30),
          EffectController(duration: 0.5, curve: Curves.easeOut),
        ),
        RemoveEffect(),
      ]),
    );

    textComponent.add(OpacityEffect.fadeOut(EffectController(duration: 0.5)));

    gameRef.world.add(textComponent);
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
//  ARTILLERY MINE - used by artillery bosses
// ============================================================================

class ArtilleryMine extends PositionComponent
    with HasGameRef<SurvivalHoardGame> {
  final double triggerRadius;
  final double blastRadius;
  final int damage;
  final Color color;
  double _timer = 0.0;
  final double armTime;
  final double lifetime;

  ArtilleryMine({
    required Vector2 position,
    required this.triggerRadius,
    required this.blastRadius,
    required this.damage,
    required this.color,
    this.armTime = 0.6,
    this.lifetime = 6.0,
  }) : super(
         position: position,
         size: Vector2.all(blastRadius * 2),
         anchor: Anchor.center,
       );

  @override
  void update(double dt) {
    super.update(dt);
    _timer += dt;

    if (_timer >= armTime) {
      final guardians = gameRef.getGuardiansInRange(
        center: position,
        range: triggerRadius,
      );
      if (guardians.isNotEmpty) {
        _explode();
        return;
      }
    }

    if (_timer >= lifetime) {
      _explode();
    }
  }

  @override
  void render(Canvas canvas) {
    final pulse = 0.5 + 0.5 * sin(_timer * 6.0);
    final r = blastRadius * (0.4 + 0.2 * pulse);
    final center = Offset.zero;

    final fill = Paint()
      ..color = color.withOpacity(0.15 + 0.15 * pulse)
      ..style = PaintingStyle.fill;
    final outline = Paint()
      ..color = color.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, r, fill);
    canvas.drawCircle(center, r, outline);
  }

  void _explode() {
    final guardians = gameRef.getGuardiansInRange(
      center: position,
      range: blastRadius,
    );
    for (final g in guardians) {
      g.takeDamage(damage);
    }

    if (position.distanceTo(gameRef.orb.position) <= blastRadius) {
      gameRef.orb.takeDamage(damage);
    }

    gameRef.world.add(
      CircleComponent(
        radius: blastRadius * 0.3,
        position: position.clone(),
        anchor: Anchor.center,
        paint: Paint()..color = color,
      )..add(
        SequenceEffect([
          ScaleEffect.to(
            Vector2.all(blastRadius / (blastRadius * 0.3)),
            EffectController(duration: 0.25, curve: Curves.easeOut),
          ),
          OpacityEffect.fadeOut(EffectController(duration: 0.15)),
          RemoveEffect(),
        ]),
      ),
    );

    removeFromParent();
  }
}

// ============================================================================
//  SIMPLE PROJECTILE
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
