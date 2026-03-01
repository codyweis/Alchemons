// lib/games/survival/survival_hoard_enemy.dart
import 'dart:math';

import 'package:alchemons/games/survival/components/alchemy_orb.dart';
import 'package:alchemons/games/survival/components/enemy_spawn_effect.dart';
import 'package:alchemons/games/survival/enemies/survival_enemy_visuals.dart';
import 'package:alchemons/games/survival/survival_combat.dart';
import 'package:alchemons/games/survival/survival_creature_sprite.dart';
import 'package:alchemons/games/survival/survival_game.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

import 'survival_enemy_types.dart';

// ============================================================================
//                                HOARD ENEMY
// ============================================================================

class HoardEnemy extends PositionComponent with HasGameRef<SurvivalHoardGame> {
  static final Random _rng = Random();
  static const double _enemyGuardianCrashMult = 1.25;
  static const double _enemyOrbCrashMult = 6.15;
  static const double _bossGuardianCrashMult = 1.2;
  static const double _bossOrbCrashMult = 5.85;

  final AlchemyOrb targetOrb;
  final SurvivalEnemyTemplate template;
  final EnemyRole role;
  final SurvivalUnit unit;
  final double sizeScale;
  double _hitFlash = 0.0;
  final int hydraGeneration;

  final BossArchetype? bossArchetype;
  final bool isMegaBoss;
  bool isBoss = false;
  bool isMiniBoss = false;

  final double speedMultiplier;
  bool isDead = false;

  final double _logicalRadius;

  // Expose for death cascade
  double get logicalRadius => _logicalRadius;

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

  double _bossAnchorAngle = 0.0;
  double _bossAnchorAngleTarget = 0.0;
  double _bossAnchorSwapTimer = 0.0;
  static const double _bossAnchorSwapInterval = 6.0;

  double _timeAlive = 0;

  bool _spawnEffectStarted = false;
  bool _shooterInPosition = false;

  bool _isAttached = false;
  Object? _attachedTarget;
  double _leechTickTimer = 0;
  final double _leechTickInterval = 0.5;
  int _leechDamagePerTick = 0;
  int _leechHealPerTick = 0;

  bool get isAnyBoss => isBoss || isMiniBoss || isMegaBoss;
  bool _isInvulnerable = false;
  double _bossAttackCooldown = 0.0;


  HoardGuardian? _focusGuardian;
  double _focusGuardianRetargetTimer = 0.0;

  bool _isCharging = false;
  double _chargeTime = 0.0;
  double _chargeDuration = 0.8;
  Vector2? _chargeStart;
  Vector2? _chargeEnd;
  final Set<HoardGuardian> _chargeHitGuardians = {};
  bool _chargeHitOrb = false;

  double _summonerBuffTimer = 0.0;
  double _summonerBuffSpeedMult = 1.0;
  double _summonerBuffDamageMult = 1.0;

  int get hydraCanSplit => (4 - hydraGeneration).clamp(0, 4);
  bool _hydraSplitTriggered = false;
  double _hydraSlamCooldown = 0.0;
  bool _hydraIsSlammingGround = false;
  double _hydraSlamTimer = 0.0;

  int get contactDamage => (_contactDamage * _summonerBuffDamageMult).round();
  int get shotDamage => (_shotDamage * _summonerBuffDamageMult).round();

  // CHANGED: Use ImprovedBlobBody
  late ImprovedBlobBody _body;

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
               2,
         ),
         anchor: Anchor.center,
       ) {
    _orbitAngle = _rng.nextDouble() * pi * 2;
    _bossAnchorAngle = _orbitAngle;
    _bossAnchorAngleTarget = _bossAnchorAngle;
    scale = Vector2.all(1.0);

    if (bossArchetype != null && !isMegaBoss && !isMiniBoss) {
      isBoss = true;
    }

    _configureBehaviorFromUnit();

    if (isAnyBoss) {
      _isInvulnerable = true;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CHANGED: New size calculation - MUCH BEEFIER enemies
  // ════════════════════════════════════════════════════════════════════════════
  static double _calculateLogicalRadius(
    SurvivalEnemyTemplate template,
    double sizeScale,
    BossArchetype? archetype,
    int hydraGen,
  ) {
    // NEW: Use tier-based sizing from EnemySizeConfig
    final tierRadius = EnemySizeConfig.baseRadius[template.tier] ?? 18.0;

    // NEW: Apply family-specific modifier for visual variety
    final familyMod =
        EnemySizeConfig.familySizeScale[template.creatureFamily] ?? 1.0;

    final baseRadius = tierRadius * familyMod * sizeScale;

    if (archetype == BossArchetype.hydra) {
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
      _contactDamage = max(1, (unit.physAtk * 0.25).round());
      _shotDamage = max(1, (unit.elemAtk * 0.15).round());
    } else if (role == EnemyRole.shooter) {
      _maxSpeed = baseSpeed * (1.2 + unit.statSpeed * 0.2);
      _contactDamage = max(1, (unit.physAtk * 0.2).round());
      _shotDamage = max(1, (unit.elemAtk * 0.45).round());
    } else if (role == EnemyRole.bomber) {
      _maxSpeed = baseSpeed * (1.8 + unit.statSpeed * 0.25);
      _contactDamage = max(1, (unit.physAtk * 2.5).round());
      _shotDamage = 0;
    } else if (role == EnemyRole.leecher) {
      _maxSpeed = baseSpeed * (1.1 + unit.statSpeed * 0.15);
      _contactDamage = max(1, (unit.physAtk * 0.1).round());
      _leechDamagePerTick = max(1, (unit.elemAtk * 0.3).round());
      _leechHealPerTick = (_leechDamagePerTick * 0.5).round();
      _shotDamage = 0;
    }

    if (isAnyBoss) {
      double bossMult = isMegaBoss ? 2.5 : (isBoss ? 2.0 : 1.6);
      if (role == EnemyRole.charger) bossMult *= 0.75;
      if (role == EnemyRole.shooter) bossMult *= 0.7;

      _contactDamage = max(10, (_contactDamage * bossMult).round());
      _shotDamage = max(8, (_shotDamage * bossMult).round());

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

  // ════════════════════════════════════════════════════════════════════════════
  // CHANGED: onLoad uses ImprovedBlobBody and ImprovedTrail
  // ════════════════════════════════════════════════════════════════════════════
  @override
  Future<void> onLoad() async {
    final baseColor = _elementColor(template.element);
    final radius = _logicalRadius;

    // CHANGED: Use ImprovedTrail with more particles
    if (template.tier != EnemyTier.swarm) {
      final tier = template.tier;
      int maxParticles;
      bool isElite = false;

      if (isAnyBoss) {
        maxParticles = 15;
        isElite = true;
      } else if (tier == EnemyTier.grunt) {
        maxParticles = 6;
      } else if (tier == EnemyTier.elite) {
        maxParticles = 10;
        isElite = true;
      } else {
        maxParticles = 3;
      }

      final enemyCount = gameRef.enemyCount;
      final wave = gameRef.currentWave;
      final allowTrail = enemyCount < 60 && wave < 50;

      if (allowTrail) {
        add(
          ImprovedTrail(
            color: baseColor,
            radius: radius * 0.5,
            maxParticles: maxParticles,
            isElite: isElite,
          ),
        );
      }
    }

    // CHANGED: Use ImprovedBlobBody with family-specific shapes
    _body = ImprovedBlobBody(
      template: template,
      role: role,
      color: baseColor,
      isBoss: isAnyBoss,
      radius: radius,
      bossArchetype: bossArchetype,
      hydraGeneration: hydraGeneration,
    );
    add(_body);

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

  void _playSimpleSpawnEffect() {
    scale = Vector2.zero();
    add(
      ScaleEffect.to(
        Vector2.all(1.0),
        EffectController(duration: 0.8, curve: Curves.easeOutBack),
      ),
    );
  }

  void _playBossSpawnEffect() {
    final color = _elementColor(template.element);
    final portalRadius = _logicalRadius * 2.0;

    scale = Vector2.zero();
    final riseAmount = _logicalRadius * 0.8;
    position.y += riseAmount;

    gameRef.world.add(
      BossSpawnPortal(
        position: position.clone() + Vector2(0, riseAmount * 0.5),
        color: color,
        radius: portalRadius,
        duration: isMegaBoss ? 3.5 : 2.5,
      ),
    );

    final appearDelay = isMegaBoss ? 1.2 : 0.8;
    final riseDuration = isMegaBoss ? 1.5 : 1.0;

    Future.delayed(Duration(milliseconds: (appearDelay * 1000).toInt()), () {
      if (!isMounted || isDead) return;

      add(
        ScaleEffect.to(
          Vector2.all(1.0),
          EffectController(duration: riseDuration, curve: Curves.easeOutBack),
        ),
      );

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

    final shield = CircleComponent(
      radius: _logicalRadius * 1.1,
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
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

    for (int i = 0; i < 4; i++) {
      Future.delayed(Duration(milliseconds: i * 600), () {
        if (!isMounted) return;

        gameRef.world.add(
          CircleComponent(
            radius: 20,
            position: position.clone(),
            anchor: Anchor.center,
            paint: Paint()
              ..color = _elementColor(template.element).withValues(alpha: 0.5)
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

    add(
      MoveEffect.by(
        dir * 300,
        EffectController(duration: entranceDuration, curve: Curves.easeInOut),
      ),
    );

    Future.delayed(
      Duration(milliseconds: (entranceDuration * 1000).toInt()),
      () {
        if (!isMounted || isDead) return;

        _isInvulnerable = false;
        shield.removeFromParent();

        _triggerScreenShake(isMegaBoss ? 12.0 : 8.0);

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

    _hitFlash = (_hitFlash - dt * 6.0).clamp(0.0, 1.0);
    _body.hitFlash = _hitFlash;
    if (isAnyBoss) {
      _body.hpPercent = unit.hpPercent;
    }

    if (_summonerBuffTimer > 0) {
      _summonerBuffTimer -= dt;
      if (_summonerBuffTimer <= 0) {
        _summonerBuffTimer = 0;
        _summonerBuffSpeedMult = 1.0;
        _summonerBuffDamageMult = 1.0;
      }
    }

    if (isMegaBoss) _updateBossPhase();
    if (bossArchetype == BossArchetype.hydra) _checkHydraSplit();

    _hydraSlamCooldown = (_hydraSlamCooldown - dt).clamp(0, double.infinity);

    _timeAlive += dt;
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

  // ════════════════════════════════════════════════════════════════════════════
  // BOSS AI
  // ════════════════════════════════════════════════════════════════════════════

  void _updateSimpleBossAI(double dt) {
    if (_isCharging) {
      _updateCharge(dt);
      return;
    }

    if (_hydraIsSlammingGround) {
      _updateHydraSlam(dt);
      return;
    }

    final bool isShooterBoss =
        role == EnemyRole.shooter || bossArchetype == BossArchetype.artillery;

    HoardGuardian? focusGuardian;
    if (!isShooterBoss) {
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
      focusGuardian = _focusGuardian;
    }

    final Vector2 focusCenter = isShooterBoss
        ? targetOrb.position
        : (focusGuardian?.position ?? targetOrb.position);
    final Vector2 toCenter = focusCenter - position;
    final double distToCenter = toCenter.length;

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
        final hydraRadii = [450.0, 400.0, 350.0, 300.0, 260.0];
        desiredRadius = hydraRadii[hydraGeneration.clamp(0, 4)];
        minRadius = desiredRadius - 60.0;
        maxRadius = desiredRadius + 100.0;
        speedFactor *= 0.85 + hydraGeneration * 0.1;
        break;
      default:
        desiredRadius = isMegaBoss ? 600.0 : 500.0;
        minRadius = desiredRadius - 90.0;
        maxRadius = desiredRadius + 120.0;
        break;
    }

    final double innerComfort = minRadius + 40.0;
    final double outerComfort = maxRadius - 40.0;

    if (!isShooterBoss) {
      _bossAnchorSwapTimer -= dt;
      if (_bossAnchorSwapTimer <= 0.0) {
        final double jitter = (_rng.nextDouble() - 0.5) * 0.6;
        _bossAnchorAngleTarget =
            (_bossAnchorAngleTarget + pi + jitter) % (2 * pi);
        _bossAnchorSwapTimer =
            _bossAnchorSwapInterval + (_rng.nextDouble() - 0.5) * 2.0;
      }
    } else {
      _bossAnchorSwapTimer -= dt;
      if (_bossAnchorSwapTimer <= 0.0) {
        final double jitter = (_rng.nextDouble() - 0.5) * 0.25;
        _bossAnchorAngleTarget = (_bossAnchorAngleTarget + jitter) % (2 * pi);
        _bossAnchorSwapTimer = 1.8 + _rng.nextDouble() * 1.6;
      }
    }

    final double angleDiff = _wrapAngle(
      _bossAnchorAngleTarget - _bossAnchorAngle,
    );
    _bossAnchorAngle += angleDiff * (dt * 1.5);

    final Vector2 radialDir = distToCenter > 0.001
        ? (toCenter / distToCenter)
        : Vector2(1, 0);
    final Vector2 anchorOffset =
        Vector2(cos(_bossAnchorAngle), sin(_bossAnchorAngle)) * desiredRadius;
    final Vector2 targetPerch = focusCenter + anchorOffset;

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
        final double perchPull = isShooterBoss ? 0.35 : 0.7;
        moveDir += toPerch / (distToPerch == 0 ? 1 : distToPerch) * perchPull;
      }

      // Intentionally allow boss overlap to avoid separation-induced jitter.
    }

    if (moveDir.length2 > 0) moveDir.normalize();

    final double bossSpeed = _maxSpeed * speedFactor * _summonerBuffSpeedMult;
    final Vector2 desiredVel = moveDir * bossSpeed;

    final double bossTurnSpeed = isMegaBoss ? 3.0 : 2.0;
    final double turnLerp = (dt * bossTurnSpeed).clamp(0.0, 1.0);
    _velocity.lerp(desiredVel, turnLerp);
    position += _velocity * dt;

    if (_velocity.length2 > 36) {
      final double targetAngle = atan2(_velocity.y, _velocity.x);
      final double rotateLerp = (dt * 3.8).clamp(0.0, 1.0);
      angle = _smoothAngle(angle, targetAngle, rotateLerp);
    }

    _bossAttackCooldown -= dt;
    if (_bossAttackCooldown <= 0) _performBossAttack();
  }

  void _updateCharge(double dt) {
    if (!_isCharging || _chargeStart == null || _chargeEnd == null) return;

    _chargeTime += dt;
    final t = (_chargeTime / _chargeDuration).clamp(0.0, 1.0);
    position = _chargeStart! + (_chargeEnd! - _chargeStart!) * t;

    final chargeDmg = (contactDamage * 1.45).round();
    final guardians = gameRef.getGuardiansInRange(center: position, range: 70);
    for (final g in guardians) {
      if (!g.isDead && !_chargeHitGuardians.contains(g)) {
        _chargeHitGuardians.add(g);
        g.takeDamage(
          chargeDmg,
          source: 'Juggernaut Charge',
          isBossAttack: true,
        );
      }
    }

    if (position.distanceTo(targetOrb.position) < 90 && !_chargeHitOrb) {
      _chargeHitOrb = true;
      targetOrb.takeDamage((contactDamage * 5.85).round());
    }

    if (t >= 1.0) {
      _isCharging = false;
      _chargeStart = null;
      _chargeEnd = null;
      _chargeHitGuardians.clear();
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

      gameRef.world.add(
        CircleComponent(
          radius: m._logicalRadius * 1.1,
          position: m.position.clone(),
          anchor: Anchor.center,
          paint: Paint()
            ..color = _elementColor(template.element).withValues(alpha: 0.4)
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
        _summonMinions(isMegaBoss ? 6 : (isBoss ? 5 : 3));
        _bossAttackCooldown = isMegaBoss ? 3.4 : 3.0;
      }
      return;
    }

    switch (archetype) {
      case BossArchetype.juggernaut:
        if (rng < 0.5) {
          _startChargeAttack();
          _bossAttackCooldown = isMegaBoss ? 3.6 : 4.0;
        } else {
          _fireRadialVolley(projectiles: isMegaBoss ? 9 : 7, damageScale: 0.85);
          _bossAttackCooldown = isMegaBoss ? 3.2 : 3.6;
        }
        if (rng < 0.2) _summonMinions(2);
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

  // ════════════════════════════════════════════════════════════════════════════
  // HYDRA LOGIC
  // ════════════════════════════════════════════════════════════════════════════

  void _checkHydraSplit() {
    if (_hydraSplitTriggered || hydraCanSplit <= 0) return;

    final splitThresholds = [0.60, 0.50, 0.40, 0.30, 0.0];
    final threshold = splitThresholds[hydraGeneration.clamp(0, 4)];

    if (unit.hpPercent <= threshold) {
      _hydraSplitTriggered = true;
      _performHydraSplit();
    }
  }

  void _performHydraSplit() {
    _hitFlash = 1.0;
    _triggerScreenShake(12.0 + (4 - hydraGeneration) * 4.0);

    final childCount = _getSplitCount();
    final childGen = hydraGeneration + 1;

    for (int i = 0; i < childCount; i++) {
      final angle = (i / childCount) * 2 * pi + _rng.nextDouble() * 0.5;
      final distance = _logicalRadius * 2.5;
      final spawnPos = position + Vector2(cos(angle), sin(angle)) * distance;

      final childUnit = SurvivalEnemyCatalog.buildHydraBoss(
        template: template,
        wave: gameRef.currentWave,
        generation: childGen,
      );

      final child = HoardEnemy(
        position: spawnPos,
        targetOrb: targetOrb,
        template: template,
        role: role,
        unit: childUnit,
        sizeScale: sizeScale,
        bossArchetype: BossArchetype.hydra,
        isMegaBoss: childGen <= 1,
        speedMultiplier: speedMultiplier,
        hydraGeneration: childGen,
      );

      if (childGen >= 2) {
        child.isMiniBoss = true;
        child.isBoss = false;
      }

      gameRef.addHoardEnemy(child);
      _spawnSplitEffect(spawnPos);
    }

    _dieWithoutReward();
  }

  int _getSplitCount() {
    if (hydraGeneration == 0) return 4;
    if (hydraGeneration == 1) return 3;
    return 2;
  }

  void _spawnSplitEffect(Vector2 pos) {
    final color = _elementColor(template.element);

    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * pi;
      final speed = 100 + _rng.nextDouble() * 80;

      gameRef.world.add(
        CircleComponent(
          radius: 6,
          position: pos.clone(),
          anchor: Anchor.center,
          paint: Paint()..color = color.withValues(alpha: 0.8),
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

    gameRef.world.add(
      CircleComponent(
        radius: 20,
        position: pos.clone(),
        anchor: Anchor.center,
        paint: Paint()..color = Colors.white.withValues(alpha: 0.9),
      )..add(
        SequenceEffect([
          ScaleEffect.to(Vector2.all(3), EffectController(duration: 0.3)),
          OpacityEffect.fadeOut(EffectController(duration: 0.2)),
          RemoveEffect(),
        ]),
      ),
    );
  }

  void _dieWithoutReward() {
    if (isDead) return;
    isDead = true;

    _triggerScreenShake(15.0);

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

    gameRef.removeEnemyWithoutReward(this);
  }

  void _performHydraAttack(double rng) {
    if (hydraGeneration == 0) {
      if (rng < 0.35) {
        _startHydraGroundSlam();
        _bossAttackCooldown = 4.5;
      } else if (rng < 0.65) {
        _fireHydraMultiVolley();
        _bossAttackCooldown = 3.8;
      } else {
        _summonMinions(4);
        _bossAttackCooldown = 4.0;
      }
    } else if (hydraGeneration <= 2) {
      if (rng < 0.4) {
        _startHydraGroundSlam();
        _bossAttackCooldown = 3.5 - hydraGeneration * 0.3;
      } else {
        _fireRadialVolley(projectiles: 8 - hydraGeneration, damageScale: 0.8);
        _bossAttackCooldown = 3.0 - hydraGeneration * 0.2;
      }
    } else {
      if (rng < 0.5) {
        _startChargeAttack();
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
    _hydraSlamCooldown = 3.0;

    add(
      MoveByEffect(
        Vector2(0, -_logicalRadius * 0.5),
        EffectController(duration: 0.4, curve: Curves.easeOut),
      ),
    );

    final warningRadius = _logicalRadius * (1.5 + (3 - hydraGeneration) * 0.5);
    final warningPos = position.clone() + Vector2(0, _logicalRadius * 0.5);

    gameRef.world.add(
      CircleComponent(
        radius: warningRadius,
        position: warningPos,
        anchor: Anchor.center,
        paint: Paint()
          ..color = Colors.red.withValues(alpha: 0.16)
          ..style = PaintingStyle.fill,
      )..add(
        SequenceEffect([
          OpacityEffect.fadeOut(EffectController(duration: 0.6)),
          RemoveEffect(),
        ]),
      ),
    );

    gameRef.world.add(
      CircleComponent(
        radius: warningRadius,
        position: warningPos,
        anchor: Anchor.center,
        paint: Paint()
          ..color = Colors.red.withValues(alpha: 0.55)
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

    if (_hydraSlamTimer >= 0.5 && _hydraSlamTimer < 0.55) {
      _executeHydraSlam();
    }

    if (_hydraSlamTimer >= 1.0) {
      _hydraIsSlammingGround = false;
      _hydraSlamTimer = 0;

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
    final slamDamage = (contactDamage * 1.75).round();

    _triggerScreenShake(10.0 + (4 - hydraGeneration) * 5.0);

    final guardians = gameRef.getGuardiansInRange(
      center: position,
      range: slamRadius,
    );
    for (final g in guardians) {
      if (!g.isDead) {
        g.takeDamage(
          slamDamage,
          source: 'Hydra Ground Slam',
          isBossAttack: true,
        );
      }
    }

    if (position.distanceTo(targetOrb.position) < slamRadius) {
      targetOrb.takeDamage((slamDamage * 5.1).round());
    }

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (!isMounted || isDead) return;

        final baseRadius = 28.0;

        gameRef.world.add(
          CircleComponent(
            radius: baseRadius,
            position: position.clone(),
            anchor: Anchor.center,
            paint: Paint()
              ..color = _elementColor(template.element).withValues(alpha: 0.22)
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

        gameRef.world.add(
          CircleComponent(
            radius: baseRadius,
            position: position.clone(),
            anchor: Anchor.center,
            paint: Paint()
              ..color = _elementColor(template.element).withValues(alpha: 0.85)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.12,
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
            ..color = _elementColor(template.element).withValues(alpha: 0.7),
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

  void _fireHydraMultiVolley() {
    final color = _elementColor(template.element);
    final damage = (shotDamage * 0.8).round();

    for (int head = 0; head < 4; head++) {
      final baseAngle = (head / 4) * 2 * pi + _timeAlive * 0.1;

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
              targetOrb.takeDamage((damage * 3).round());
            }
          },
        );
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // REGULAR ENEMY AI
  // ════════════════════════════════════════════════════════════════════════════

  void _updateMovementAndAI(double dt) {
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
      if (_shooterInPosition) _tryShoot(targetGuardian);
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

    final separationForce = isAnyBoss
        ? Vector2.zero()
        : _computeSeparation(radius: size.x * 0.8);
    final combined = steeringForce + separationForce * 2.5;
    final desiredVelocity = combined.length2 > 0.0001
        ? combined.normalized() * currentMaxSpeed
        : Vector2.zero();

    double turnSpeed = 4.0;
    _velocity.lerp(desiredVelocity, dt * turnSpeed);
    position += _velocity * dt;

    if (_velocity.length2 > 10) {
      final double targetAngle = atan2(_velocity.y, _velocity.x);
      angle = _smoothAngle(angle, targetAngle, dt * 6.0);
    }
  }

  Vector2 _computeSeparation({double radius = 50.0}) {
    if (template.tier == EnemyTier.swarm) return Vector2.zero();

    Vector2 force = Vector2.zero();
    int count = 0;

    final neighbors = gameRef.getEnemiesInRange(position, radius);
    for (final other in neighbors) {
      if (other == this) continue;
      if (isAnyBoss && !other.isAnyBoss) continue;

      final delta = position - other.position;
      final dist = delta.length;
      if (dist < 0.001) continue;

      // stronger when closer
      final t = (1.0 - (dist / radius)).clamp(0.0, 1.0);

      // heavier enemies get nudged less, but never ignore
      final massRatio = (other.mass / mass).clamp(0.35, 1.8);

      force += (delta / dist) * (t * t) * massRatio;
      count++;
    }

    if (count == 0) return Vector2.zero();
    force /= count.toDouble();
    if (isAnyBoss && force.length > 1.0) {
      force = force.normalized();
    }
    return force; // don’t normalize; let magnitude matter
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

    if (!_shooterInPosition) {
      if (distToOrb <= _idealRange + 30) {
        _shooterInPosition = true;
        _orbitAngle = atan2(position.y - orbPos.y, position.x - orbPos.x);
      } else {
        return toOrb.normalized();
      }
    }

    final orbitSpeedVariance = 0.2 + (hashCode % 100) * 0.003;
    _orbitAngle += dt * orbitSpeedVariance;

    final orbitPos =
        orbPos +
        Vector2(cos(_orbitAngle) * _idealRange, sin(_orbitAngle) * _idealRange);

    final toOrbitPos = orbitPos - position;
    final distToOrbitPos = toOrbitPos.length;

    if (distToOrb > _idealRange + 60) {
      return (toOrb.normalized() * 0.6 + toOrbitPos.normalized() * 0.4)
          .normalized();
    } else if (distToOrb < _idealRange - 40) {
      return -toOrb.normalized();
    }

    if (distToOrbitPos > 10) return toOrbitPos.normalized();

    final tangent = Vector2(-sin(_orbitAngle), cos(_orbitAngle));
    return tangent;
  }

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
      _attachToTarget(huntingGuardian ? guardian! : targetOrb, huntingGuardian);
      return Vector2.zero();
    }

    return (dest - position).normalized();
  }

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
          source: 'Leecher Drain',
        );
      } else if (_attachedTarget is AlchemyOrb) {
        (_attachedTarget as AlchemyOrb).takeDamage(
          (_leechDamagePerTick * 3).round(),
        );
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
        (contactDamage * _enemyGuardianCrashMult).round(),
        source: 'Leecher Attach',
      );
    } else if (target is AlchemyOrb) {
      target.takeDamage((contactDamage * _enemyOrbCrashMult).round());
    }

    _body.bodyOpacity = 0.7;
  }

  void _detachFromTarget() {
    _isAttached = false;
    _attachedTarget = null;
    _body.bodyOpacity = 1.0;
  }

  void _spawnDrainParticle() {
    if (_attachedTarget is! PositionComponent) return;

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
        (contactDamage * _enemyGuardianCrashMult).round(),
        source: 'Bomber Explosion',
      );
    } else if (target is AlchemyOrb) {
      target.takeDamage((contactDamage * _enemyOrbCrashMult).round());
    }

    final nearbyGuardians = gameRef.getGuardiansInRange(
      center: position,
      range: explosionRadius,
    );
    for (final g in nearbyGuardians) {
      if (g != target) {
        g.takeDamage((contactDamage * 0.7).round(), source: 'Bomber Splash');
      }
    }

    if (position.distanceTo(targetOrb.position) < explosionRadius &&
        target != targetOrb) {
      targetOrb.takeDamage((contactDamage * 3.6).round());
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
      gameRef.spawnEnemyProjectile(
        start: position.clone(),
        targetPosition: guardian.position.clone(),
        color: projectileColor,
        onHit: () => guardian.takeDamage(
          dmg,
          source: 'Enemy Shot',
          isBossAttack: isBoss,
        ),
      );
    } else {
      gameRef.spawnEnemyProjectile(
        start: position.clone(),
        targetPosition: targetOrb.position.clone(),
        color: projectileColor,
        onHit: () => targetOrb.takeDamage((dmg * 3).round()),
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
          target.takeDamage(
            (contactDamage * _bossGuardianCrashMult).round(),
            source: 'Boss Melee',
            isBossAttack: true,
          );
        } else if (target is AlchemyOrb) {
          target.takeDamage((contactDamage * _bossOrbCrashMult).round());
        }
        _meleeCooldown = 0.9;
      }
    } else {
      if (target is HoardGuardian) {
        target.takeDamage(
          (contactDamage * _enemyGuardianCrashMult).round(),
          source: 'Enemy Melee',
        );
      } else if (target is AlchemyOrb) {
        target.takeDamage((contactDamage * _enemyOrbCrashMult).round());
      }
      _die();
    }
  }

  double _smoothAngle(double current, double target, double rate) {
    double diff = target - current;
    while (diff < -pi) {
      diff += 2 * pi;
    }
    while (diff > pi) {
      diff -= 2 * pi;
    }
    return current + diff * rate;
  }

  double _wrapAngle(double a) {
    while (a < -pi) {
      a += 2 * pi;
    }
    while (a > pi) {
      a -= 2 * pi;
    }
    return a;
  }

  void takeDamage(int amount) {
    if (isDead) return;

    if (_isInvulnerable) {
      _hitFlash = 0.5;
      return;
    }

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

  // ════════════════════════════════════════════════════════════════════════════
  // CHANGED: Death effects with DeathExplosion for satisfying kills
  // ════════════════════════════════════════════════════════════════════════════
  void _die() {
    if (isDead) return;
    isDead = true;

    final color = _elementColor(template.element);

    // Register with cascade manager if available
    if (gameRef.deathCascade != null) {
      gameRef.deathCascade!.registerDeath(
        position.clone(),
        color,
        _logicalRadius,
        isAnyBoss,
      );
    }

    // CHANGED: Use DeathExplosion for satisfying visual feedback
    final chainMult = gameRef.deathCascade?.currentChainCount ?? 1;

    gameRef.world.add(
      DeathExplosion(
        position: position.clone(),
        color: color,
        radius: _logicalRadius,
        isBoss: isAnyBoss,
        chainMultiplier: chainMult,
      ),
    );

    // Extra effects for bosses
    if (isAnyBoss) {
      _triggerScreenShake(20.0);

      gameRef.world.add(
        CircleComponent(
          radius: _logicalRadius,
          position: position.clone(),
          anchor: Anchor.center,
          paint: Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        )..add(
          SequenceEffect([
            ScaleEffect.to(
              Vector2.all(8),
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
          EffectController(duration: 0.2, curve: Curves.easeInBack),
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
            targetOrb.takeDamage((damage * 3).round());
          }
        },
      );
    }
  }

  void _updateBossPhase() {}

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
//  ARTILLERY MINE
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

    if (_timer >= lifetime) _explode();
  }

  @override
  void render(Canvas canvas) {
    final pulse = 0.5 + 0.5 * sin(_timer * 6.0);
    final r = blastRadius * (0.4 + 0.2 * pulse);
    final center = Offset.zero;

    final fill = Paint()
      ..color = color.withValues(alpha: 0.15 + 0.15 * pulse)
      ..style = PaintingStyle.fill;
    final outline = Paint()
      ..color = color.withValues(alpha: 0.9)
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
      gameRef.orb.takeDamage((damage * 3).round());
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
