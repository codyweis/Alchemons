import 'dart:math';
import 'dart:ui';

import 'package:alchemons/games/survival/components/alchemy_orb.dart';
import 'package:alchemons/games/survival/components/alchemy_projectile.dart';
import 'package:alchemons/games/survival/survival_combat.dart';
import 'package:alchemons/games/survival/survival_creature_sprite.dart';
import 'package:alchemons/games/survival/survival_game.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

enum EnemyRole {
  charger, // rushes the orb
  shooter, // stays at distance and shoots guardians / orb
}

/// Boss behavior archetypes for variety
enum BossArchetype {
  orbitingSummoner, // floats around orb and periodically spawns minions
  bulletHell, // mostly stationary turret that fires radial volleys
  ringBreaker, // slow heavy boss that dives toward rings and nova-pulses
}

/// 5 Enemy Tiers with scaling stats
enum EnemyTier {
  swarm(1, 'Swarm', 0.2, 0.3), // Weakest, most numerous
  grunt(2, 'Grunt', 0.8, 0.7),
  elite(3, 'Elite', 1.0, 0.9),
  champion(4, 'Champion', 1.3, 1.2),
  titan(5, 'Titan', 1.8, 1.6); // Strongest, rarest

  final int tier;
  final String name;
  final double statMultiplier;
  final double hpMultiplier;

  const EnemyTier(this.tier, this.name, this.statMultiplier, this.hpMultiplier);
}

/// 17 Elemental Types
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

/// Enemy template combining tier + element
class SurvivalEnemyTemplate {
  final EnemyTier tier;
  final String element;
  final String family; // For move compatibility

  const SurvivalEnemyTemplate({
    required this.tier,
    required this.element,
    required this.family,
  });

  String get name => '${tier.name} ${element}ling';
  String get id => '${element.toLowerCase()}_${tier.name.toLowerCase()}';
}

/// Enemy catalog with all combinations
class SurvivalEnemyCatalog {
  static final Random _rng = Random();

  static final List<SurvivalEnemyTemplate> _allTemplates =
      _generateAllTemplates();

  /// Get template by exact element and tier
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

  static List<SurvivalEnemyTemplate> _generateAllTemplates() {
    final templates = <SurvivalEnemyTemplate>[];
    for (final tier in EnemyTier.values) {
      for (final element in allElements) {
        templates.add(
          SurvivalEnemyTemplate(
            tier: tier,
            element: element,
            family: _getElementFamily(element),
          ),
        );
      }
    }
    return templates;
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
  }) {
    final baseLevel = _getBaseLevelForTier(tier, wave);
    final baseStats = _getBaseStats(tier);
    double clampStat(double v) => v.clamp(0.0, 5.0);

    final enemyTier = template.tier;

    final unit = SurvivalUnit(
      id: '...',
      name: template.name,
      types: [template.element],
      family: template.family,
      statSpeed: clampStat(baseStats['speed']!),
      statIntelligence: clampStat(baseStats['intelligence']!),
      statStrength: clampStat(baseStats['strength']!),
      statBeauty: clampStat(baseStats['beauty']!),
      level: baseLevel,
    );

    // --- TIER MULTIPLIERS (gentle) ---
    unit.maxHp = (unit.maxHp * enemyTier.hpMultiplier).round();
    unit.currentHp = unit.maxHp;
    unit.physAtk = (unit.physAtk * enemyTier.statMultiplier).round();
    unit.elemAtk = (unit.elemAtk * enemyTier.statMultiplier).round();

    // --- WAVE SCALING (keep pretty chill) ---
    final tierNum = enemyTier.tier.toDouble();
    final waveDifficulty = (1.0 + (wave - 1) * 0.02).clamp(1.0, 2.0);
    final tierFactor = (0.9 + (tierNum - 1) * 0.10).clamp(0.9, 1.6);

    final atkScale = (0.40 * waveDifficulty * tierFactor).clamp(0.4, 0.9);
    final hpScale = (0.70 * waveDifficulty * tierFactor).clamp(0.8, 1.4);

    unit.maxHp = (unit.maxHp * hpScale).round();
    unit.currentHp = unit.maxHp;
    unit.physAtk = (unit.physAtk * atkScale).round();
    unit.elemAtk = (unit.elemAtk * atkScale).round();

    return unit;
  }

  static int _getBaseLevelForTier(int tier, int wave) {
    switch (tier) {
      case 1:
        return max(1, wave ~/ 2);
      case 2:
        return max(2, 2 + wave ~/ 2);
      case 3:
        return max(5, 5 + wave ~/ 2);
      case 4:
        return max(7, 7 + wave ~/ 2);
      case 5:
        return max(10, 10 + wave ~/ 2);
      default:
        return 1;
    }
  }

  static Map<String, double> _getBaseStats(int tier) {
    double baseSpeed, baseInt, baseStr, baseBeauty;
    switch (tier) {
      case 1: // Swarm
        baseSpeed = 0.5 + _rng.nextDouble() * 0.7;
        baseInt = 0.5 + _rng.nextDouble() * 0.6;
        baseStr = 0.8 + _rng.nextDouble() * 0.8;
        baseBeauty = 0.6 + _rng.nextDouble() * 0.5;
        break;
      case 2: // Grunt
        baseSpeed = 1.4 + _rng.nextDouble() * 0.7;
        baseInt = 1.2 + _rng.nextDouble() * 0.7;
        baseStr = 1.3 + _rng.nextDouble() * 0.9;
        baseBeauty = 1.0 + _rng.nextDouble() * 0.6;
        break;
      case 3: // Elite
        baseSpeed = 1.6 + _rng.nextDouble() * 0.7;
        baseInt = 1.8 + _rng.nextDouble() * 0.7;
        baseStr = 2.2 + _rng.nextDouble() * 0.7;
        baseBeauty = 1.5 + _rng.nextDouble() * 0.6;
        break;
      case 4: // Champion
        baseSpeed = 2.4 + _rng.nextDouble() * 0.7;
        baseInt = 2.4 + _rng.nextDouble() * 0.7;
        baseStr = 2.8 + _rng.nextDouble() * 0.7;
        baseBeauty = 2.0 + _rng.nextDouble() * 0.6;
        break;
      case 5: // Titan
        baseSpeed = 2.8 + _rng.nextDouble() * 0.6;
        baseInt = 3.0 + _rng.nextDouble() * 0.6;
        baseStr = 3.2 + _rng.nextDouble() * 0.6;
        baseBeauty = 2.6 + _rng.nextDouble() * 0.6;
        break;
      default:
        baseSpeed = baseInt = baseStr = 2.0;
        baseBeauty = 1.5;
        break;
    }
    return {
      'speed': baseSpeed,
      'intelligence': baseInt,
      'strength': baseStr,
      'beauty': baseBeauty,
    };
  }

  static String _getElementFamily(String element) {
    switch (element) {
      case 'Fire':
      case 'Lava':
      case 'Blood':
        return 'Let'; // Aggressive
      case 'Water':
      case 'Ice':
      case 'Steam':
        return 'Pip'; // Quick
      case 'Earth':
      case 'Mud':
      case 'Crystal':
        return 'Horn'; // Defensive
      case 'Air':
      case 'Dust':
      case 'Lightning':
        return 'Wing'; // Fast
      case 'Plant':
      case 'Poison':
        return 'Mane'; // Tricky
      case 'Spirit':
      case 'Light':
      case 'Dark':
        return 'Mystic'; // Magical
      default:
        return 'Let';
    }
  }
}

// ============================================================================
//                                GAME ENTITIES
// ============================================================================

class HoardEnemy extends PositionComponent with HasGameRef<SurvivalHoardGame> {
  final AlchemyOrb targetOrb;
  final SurvivalEnemyTemplate template;
  final EnemyRole role;
  final SurvivalUnit unit;
  final double sizeScale;

  /// Boss flags
  final BossArchetype? bossArchetype;
  final bool isMegaBoss;
  bool isBoss = false;

  /// External speed scale (set by spawner, no gameRef in constructor)
  final double speedMultiplier;

  bool isDead = false;

  // Movement & Combat Vars
  late double _moveSpeed;
  late int _contactDamage;
  late int _shotDamage;
  late double _baseAttackCooldown;
  double _attackCooldown = 0;
  final double _idealRange = 350;
  double _orbitAngle = 0.0;
  double _meleeCooldown = 0;

  // Passive Strategy Vars
  double _timeAlive = 0;
  double _timeSinceLastDamage = 0;

  // Dasher specific
  double _dashTimer = 0;
  bool _isDashing = false;

  // Boss behavior state
  double _bossPhaseTime = 0;
  double _bossSummonTimer = 0;
  double _bossVolleyTimer = 0;

  RectangleComponent? _hpFill;
  late CircleComponent _coreVisual; // Stores color for logic use
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
  }) : super(
         position: position,
         size: Vector2.all(60 * sizeScale),
         anchor: Anchor.center,
       ) {
    _orbitAngle = Random().nextDouble() * pi * 2;
    scale = Vector2.all(1.0); // keep parent scale stable
    _configureBehaviorFromUnit();
  }

  void _configureBehaviorFromUnit() {
    final baseSpeed = 60.0;
    if (role == EnemyRole.charger) {
      _moveSpeed = baseSpeed * (1.0 + unit.statStrength * 0.18);
      _contactDamage = (unit.physAtk * 0.85).round();
      _shotDamage = (unit.elemAtk * 0.3).round();
    } else {
      _moveSpeed = baseSpeed * (0.9 + unit.statSpeed * 0.22);
      _contactDamage = (unit.physAtk * 0.30).round();
      _shotDamage = (unit.elemAtk * 1.0).round();
    }

    // Boss speed scaling is handled via speedMultiplier from the spawner
    _moveSpeed *= speedMultiplier;

    _baseAttackCooldown = role == EnemyRole.charger
        ? 2.5 / unit.cooldownReduction
        : 1.6 / unit.cooldownReduction;
    _attackCooldown = _baseAttackCooldown;
  }

  @override
  Future<void> onLoad() async {
    // Color based on Element
    final baseColor = _elementColor(template.element);

    // Calculate base size
    final radius = (15.0 + (template.tier.tier * 2.0)) * sizeScale;

    // --- BLOB BODY ---
    _body = AlchemicalBlobBody(
      template: template,
      role: role,
      color: baseColor,
      isBoss: isBoss,
      radius: radius,
    );
    add(_body);

    // Invisible core used just to store the color for projectile logic
    _coreVisual = CircleComponent(paint: Paint()..color = baseColor);
    _coreVisual.opacity = 0;
    add(_coreVisual);

    // Floating Particles (runes) for higher tiers
    if (template.tier.tier >= 3) {
      _addFloatingRunes(baseColor, template.tier.tier - 1);
    }

    // Boss ring
    if (isBoss) {
      add(
        CircleComponent(
          radius: 40 + (template.tier.tier * 3.0) * sizeScale,
          paint: Paint()
            ..color = baseColor.withOpacity(0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
          anchor: Anchor.center,
          position: Vector2.zero(),
        ),
      );
    }

    // HP bar only for bosses
    if (isBoss) {
      _buildHpBar();
    }
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
          size: Vector2(6, 6),
          position: Vector2(
            orbitRadius * cos(i * 2 * pi / count),
            orbitRadius * sin(i * 2 * pi / count),
          ),
          anchor: Anchor.center,
          angle: pi / 4,
          paint: Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        ),
      );
    }
    orbitContainer.add(
      RotateEffect.by(pi * 2, EffectController(duration: 5.0, infinite: true)),
    );
    add(orbitContainer);
  }

  void _buildHpBar() {
    final bg = RectangleComponent(
      size: Vector2(40 * sizeScale, 5),
      anchor: Anchor.center,
      position: Vector2(0, -40 * sizeScale),
      paint: Paint()..color = Colors.black87,
    );
    final fill = RectangleComponent(
      size: Vector2(38 * sizeScale, 3),
      anchor: Anchor.centerLeft,
      position: Vector2(-19 * sizeScale, 0),
      paint: Paint()..color = Colors.redAccent,
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

    // Logic Ticks
    SurvivalCombat.tickRealtimeStatuses(unit, dt);
    _applyUniquePassives(dt); // Strategy update

    if (unit.isDead) {
      _die();
      return;
    }

    // AI Logic
    _updateAI(dt);

    // Update HP Visual (only if bar exists, i.e., bosses)
    if (_hpFill != null) {
      final ratio = unit.hpPercent.clamp(0.0, 1.0);
      _hpFill!.scale.x = ratio;
    }
  }

  void _applyUniquePassives(double dt) {
    // 1. REGENERATION (Nature/Plant/Water)
    if (template.family == 'Mane' || template.family == 'Pip') {
      if (_timeSinceLastDamage > 2.5 && unit.currentHp < unit.maxHp) {
        final heal = (unit.maxHp * 0.05 * dt).ceil();
        unit.currentHp = min(unit.maxHp, unit.currentHp + heal);
      }
    }

    // 2. ACCELERATION (Fire/Lava - 'Let' Family)
    if (template.family == 'Let') {
      if (_timeAlive < 10) {
        _moveSpeed += dt * 3.0;
      }
    }
  }

  // ==========================================================================
  //                             AI & MOVEMENT
  // ==========================================================================

  void _updateAI(double dt) {
    if (isBoss && bossArchetype != null) {
      _updateBossAI(dt);
      return;
    }

    // 1. Determine Target
    final targetGuardian = gameRef.getRandomGuardianInRange(
      center: position,
      range: 800,
    );

    // 2. Calculate "Steering"
    Vector2 steering = Vector2.zero();
    double currentMoveSpeed = _moveSpeed;

    if (role == EnemyRole.shooter) {
      steering = _getShooterSteering(targetGuardian, dt);
      _tryShoot(targetGuardian);
    } else {
      steering = _getChargerSteering(
        targetGuardian,
        dt,
        outSpeed: (s) => currentMoveSpeed = s,
      );
    }

    // 3. Separation
    final separation = _computeSeparation(radius: 50.0);

    // 4. Combine Forces
    Vector2 finalDir = (steering + separation * 1.8);
    if (finalDir.length2 > 0.01) {
      finalDir.normalize();
    }

    // 5. Apply Movement
    position += finalDir * (currentMoveSpeed * dt);

    // 6. Smooth Rotation
    if (finalDir.length2 > 0.1) {
      final double targetAngle = atan2(finalDir.y, finalDir.x);
      angle = _smoothAngle(angle, targetAngle, dt * 8.0);
    }
  }

  // ------------------------- Boss AI ---------------------------------------

  void _updateBossAI(double dt) {
    _bossPhaseTime += dt;
    _bossSummonTimer += dt;
    _bossVolleyTimer += dt;

    switch (bossArchetype!) {
      case BossArchetype.orbitingSummoner:
        _updateOrbitingSummoner(dt);
        break;
      case BossArchetype.bulletHell:
        _updateBulletHell(dt);
        break;
      case BossArchetype.ringBreaker:
        _updateRingBreaker(dt);
        break;
    }
  }

  // Boss pattern 1: orbiting summoner
  void _updateOrbitingSummoner(double dt) {
    const double orbitRadiusBase = 520.0;
    final double orbitRadius = orbitRadiusBase * (isMegaBoss ? 1.1 : 1.0);
    final double orbitSpeed = isMegaBoss ? 0.45 : 0.3;

    _orbitAngle += orbitSpeed * dt;

    final desiredPos =
        targetOrb.position +
        Vector2(cos(_orbitAngle), sin(_orbitAngle)) * orbitRadius;

    final toTarget = desiredPos - position;
    position += toTarget * (dt * 1.5);

    // Face inward toward the orb
    final dirToOrb = targetOrb.position - position;
    angle = _smoothAngle(angle, atan2(dirToOrb.y, dirToOrb.x), dt * 4.0);

    // Summon minion rings periodically
    final double summonInterval = isMegaBoss ? 4.0 : 6.0;
    if (_bossSummonTimer >= summonInterval) {
      _bossSummonTimer = 0;
      final tier = template.tier.tier.clamp(1, 4);
      final count = isMegaBoss ? 10 : 6;

      gameRef.spawnBossMinions(
        boss: this,
        element: template.element,
        tier: tier,
        count: count,
        ringRadius: 160,
      );
    }

    // Shooters also fire while orbiting
    if (role == EnemyRole.shooter) {
      _tryShoot(gameRef.getRandomGuardianInRange(center: position, range: 999));
    }
  }

  // Boss pattern 2: bullet-hell turret
  void _updateBulletHell(double dt) {
    final targetAnchor =
        targetOrb.position + Vector2(0, isMegaBoss ? -260 : -220);
    final toAnchor = targetAnchor - position;
    position += toAnchor * (dt * 1.2);

    // Slow spin for style
    angle += dt * 0.6;

    // Fire radial volleys
    final double volleyInterval = isMegaBoss ? 2.2 : 3.0;
    if (_bossVolleyTimer >= volleyInterval) {
      _bossVolleyTimer = 0;
      _fireRadialVolley(projectiles: isMegaBoss ? 18 : 12);
    }

    // Occasionally surround with a guard ring
    final double summonInterval = isMegaBoss ? 8.0 : 10.0;
    if (_bossSummonTimer >= summonInterval) {
      _bossSummonTimer = 0;
      gameRef.spawnBossMinions(
        boss: this,
        element: template.element,
        tier: template.tier.tier.clamp(1, 3),
        count: isMegaBoss ? 8 : 5,
        ringRadius: 200,
      );
    }
  }

  void _fireRadialVolley({int projectiles = 12}) {
    final col = _coreVisual.paint?.color ?? _elementColor(template.element);
    final damage = (_shotDamage * (isMegaBoss ? 1.5 : 1.0)).round();

    for (int i = 0; i < projectiles; i++) {
      final theta = (i / projectiles) * 2 * pi + _bossPhaseTime * 0.3;
      final dir = Vector2(cos(theta), sin(theta));
      final end = position + dir * 900;

      gameRef.spawnEnemyProjectile(
        start: position.clone(),
        targetPosition: end,
        color: col,
        onHit: () {
          final guardians = gameRef.getGuardiansInRange(center: end, range: 80);
          for (final g in guardians) {
            g.takeDamage(damage);
          }
          if (end.distanceTo(targetOrb.position) < 120) {
            targetOrb.takeDamage(damage);
          }
        },
      );
    }
  }

  // Boss pattern 3: ring breaker
  void _updateRingBreaker(double dt) {
    final HoardGuardian? nearestGuardian = gameRef.getRandomGuardianInRange(
      center: position,
      range: 1200,
    );

    final Vector2 focus = nearestGuardian?.position ?? targetOrb.position;
    final toFocus = focus - position;
    if (toFocus.length2 > 1) {
      final dir = toFocus.normalized();
      final double speed = isMegaBoss ? _moveSpeed * 0.7 : _moveSpeed * 0.5;
      position += dir * speed * dt;
      angle = _smoothAngle(angle, atan2(dir.y, dir.x), dt * 3.0);
    }

    // Nova pulses on a rhythm
    final double novaInterval = isMegaBoss ? 5.0 : 7.0;
    if (_bossPhaseTime >= novaInterval) {
      _bossPhaseTime = 0;
      _doRingBreakerNova();
    }

    // Also shoot a bit if shooter
    if (role == EnemyRole.shooter) {
      _tryShoot(nearestGuardian);
    }
  }

  void _doRingBreakerNova() {
    final color = _coreVisual.paint?.color ?? _elementColor(template.element);
    final radius = isMegaBoss ? 260.0 : 220.0;
    final dmg = (_contactDamage * (isMegaBoss ? 1.4 : 1.1)).round();

    add(
      CircleComponent(
        radius: radius * 0.2,
        paint: Paint()
          ..color = color.withOpacity(0.4)
          ..blendMode = BlendMode.plus,
        anchor: Anchor.center,
        position: Vector2.zero(),
      )..add(
        SequenceEffect([
          ScaleEffect.to(Vector2.all(1.8), EffectController(duration: 0.4)),
          RemoveEffect(),
        ]),
      ),
    );

    final guardians = gameRef.getGuardiansInRange(
      center: position,
      range: radius,
    );
    for (final g in guardians) {
      g.takeDamage(dmg);
      final push = (g.position - position)..normalize();
      g.position += push * 60;
    }

    if (position.distanceTo(targetOrb.position) <= radius) {
      targetOrb.takeDamage(dmg);
    }
  }

  /// Calculates a force that pushes this enemy away from crowded neighbors.
  Vector2 _computeSeparation({double radius = 50.0}) {
    Vector2 separation = Vector2.zero();
    int count = 0;

    final neighbors = gameRef.getEnemiesInRange(position, radius);

    for (final other in neighbors) {
      if (other == this) continue;

      final dist = position.distanceTo(other.position);
      if (dist < 0.1) continue;

      Vector2 push = (position - other.position).normalized();
      push /= dist;
      separation += push;
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
      if (gDist < oDist * 0.8) {
        dest = guardian.position;
        huntingGuardian = true;
      }
    }

    if (_isDasherType) {
      _dashTimer -= dt;
      if (_dashTimer <= 0) {
        _isDashing = !_isDashing;
        _dashTimer = _isDashing ? 0.4 : 0.8;
      }

      if (_isDashing) {
        outSpeed(_moveSpeed * 2.8);
        _body.scale.lerp(Vector2(1.4, 0.6), dt * 10);
      } else {
        outSpeed(_moveSpeed * 0.2);
        _body.scale.lerp(Vector2.all(1.0), dt * 5);
      }
    } else {
      outSpeed(_moveSpeed);
    }

    final distToTarget = position.distanceTo(dest);
    if (distToTarget < (huntingGuardian ? 45 : 60)) {
      _applyContactDamage(
        huntingGuardian ? guardian : targetOrb,
        huntingGuardian,
      );
    }

    return (dest - position).normalized();
  }

  Vector2 _getShooterSteering(HoardGuardian? guardian, double dt) {
    if (_isOrbiterType) {
      const double orbitRadius = 380.0;
      const double orbitSpeed = 0.7;
      _orbitAngle += orbitSpeed * dt;

      final orbitPos =
          targetOrb.position +
          Vector2(cos(_orbitAngle), sin(_orbitAngle)) * orbitRadius;

      return (orbitPos - position).normalized();
    } else {
      final targetPos = guardian?.position ?? targetOrb.position;
      final toTarget = targetPos - position;
      final dist = toTarget.length;
      final dir = toTarget.normalized();

      if (dist > _idealRange + 70) {
        return dir;
      } else if (dist < _idealRange - 70) {
        return -dir;
      } else {
        return Vector2(-dir.y, dir.x) * 0.6;
      }
    }
  }

  /// Shooter projectiles – actually hit guardians/orb.
  void _tryShoot(HoardGuardian? guardian) {
    if (_attackCooldown > 0) return;

    final projectileColor =
        (_coreVisual.paint?.color ?? _elementColor(template.element));

    if (guardian != null && !guardian.isDead) {
      gameRef.spawnEnemyProjectile(
        start: position.clone(),
        targetPosition: guardian.position.clone(),
        color: projectileColor,
        onHit: () {
          guardian.takeDamage(_shotDamage);
        },
      );
    } else {
      gameRef.spawnEnemyProjectile(
        start: position.clone(),
        targetPosition: targetOrb.position.clone(),
        color: projectileColor,
        onHit: () {
          targetOrb.takeDamage(_shotDamage);
        },
      );
    }

    _attackCooldown = _baseAttackCooldown;
  }

  void _applyContactDamage(dynamic target, bool isGuardian) {
    if (_isDrainerType) {
      if (_meleeCooldown <= 0) {
        target.takeDamage(_contactDamage);
        unit.currentHp = (unit.currentHp + (_contactDamage * 0.5).round())
            .clamp(0, unit.maxHp);
        _meleeCooldown = 0.8;
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

  // --- STRATEGIC TYPE GETTERS ---
  bool get _isDasherType =>
      (template.element == 'Air' ||
          template.element == 'Lightning' ||
          template.element == 'Light') &&
      role == EnemyRole.charger;

  bool get _isOrbiterType =>
      (role == EnemyRole.shooter) &&
      (template.element == 'Air' ||
          template.element == 'Lightning' ||
          template.element == 'Spirit');

  bool get _isDrainerType =>
      (template.element == 'Dark' || template.element == 'Poison');

  bool get _isSplitterType =>
      !isBoss &&
      template.tier.tier > 1 &&
      (template.element == 'Mud' ||
          template.element == 'Plant' ||
          template.element == 'Blood');

  bool get _isExploderType =>
      !isBoss && (template.element == 'Fire' || template.element == 'Lava');

  void _triggerExplosion() {
    final double radius = 120.0 * sizeScale;
    add(
      CircleComponent(
        radius: radius * 0.8,
        paint: Paint()
          ..color = Colors.orange.withOpacity(0.5)
          ..blendMode = BlendMode.plus,
        anchor: Anchor.center,
        position: Vector2.zero(),
      )..add(
        SequenceEffect([
          ScaleEffect.to(Vector2.all(1.5), EffectController(duration: 0.2)),
          RemoveEffect(),
        ]),
      ),
    );

    final guardians = gameRef.getGuardiansInRange(
      center: position,
      range: radius,
    );
    final explosionDamage = (_contactDamage * 0.8).round();
    for (final g in guardians) {
      g.takeDamage(explosionDamage);
    }
    if (position.distanceTo(targetOrb.position) <= radius) {
      targetOrb.takeDamage(explosionDamage);
    }
  }

  void takeDamage(int amount) {
    if (isDead) return;

    _timeSinceLastDamage = 0;

    if (template.family == 'Horn') {
      amount = (amount * 0.75).round();
    }

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

    if (_isSplitterType) {
      gameRef.spawnSplitChildren(parent: this, count: 2, speedMultiplier: 1.4);
    }

    if (_isExploderType) _triggerExplosion();

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
    canvas.drawCircle(Offset.zero, 8, Paint()..color = color);
  }

  @override
  void update(double dt) {
    t += dt * 3.0;
    if (t >= 1.0) {
      onHit();
      removeFromParent();
    } else {
      position = start + (end - start) * t;
    }
  }
}

// ============================================================================
//                          THE ANIMATED BLOB BODY
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

  AlchemicalBlobBody({
    required this.template,
    required this.role,
    required this.color,
    required this.isBoss,
    required this.radius,
  }) : super(size: Vector2.all(radius * 2), anchor: Anchor.center) {
    _phaseOffset = Random().nextDouble() * 100;
    scale = Vector2.all(1.0);
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
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

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
  }

  @override
  void render(Canvas canvas) {
    final center = size / 2;

    canvas.drawCircle(center.toOffset(), radius * 0.8, _glowPaint);

    final path = _createBlobPath(center, radius * 0.85);

    canvas.drawPath(path, paint);
    canvas.drawPath(path, _borderPaint);

    _drawFace(canvas, center);

    if (isBoss) {
      canvas.drawCircle(
        center.toOffset(),
        radius * 0.5,
        Paint()
          ..color = Colors.white.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  Path _createBlobPath(Vector2 center, double r) {
    final path = Path();
    final points = 20;
    final double angleStep = (pi * 2) / points;

    double frequency = 3.0;
    double amplitude = 3.0;
    double speed = 4.0;

    switch (template.family) {
      case 'Let':
        frequency = 6.0;
        amplitude = 5.0;
        speed = 8.0;
        break;
      case 'Pip':
        frequency = 3.0;
        amplitude = 4.0;
        speed = 3.0;
        break;
      case 'Horn':
        frequency = 2.0;
        amplitude = 2.0;
        speed = 1.0;
        break;
      case 'Wing':
        frequency = 8.0;
        amplitude = 2.0;
        speed = 10.0;
        break;
      case 'Mystic':
        frequency = 4.0;
        amplitude = 6.0;
        speed = 2.0;
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

    if (role == EnemyRole.charger && template.family == 'Let') {
      _drawAngryEye(
        canvas,
        center.x - eyeOffsetX,
        center.y + eyeOffsetY,
        eyeSize,
        true,
      );
      _drawAngryEye(
        canvas,
        center.x + eyeOffsetX,
        center.y + eyeOffsetY,
        eyeSize,
        false,
      );
    } else if (role == EnemyRole.shooter) {
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

  void _drawAngryEye(
    Canvas canvas,
    double x,
    double y,
    double size,
    bool isLeft,
  ) {
    final path = Path();
    path.moveTo(x, y - size);
    path.lineTo(x + (isLeft ? size : -size), y);
    path.lineTo(x, y + size);
    path.lineTo(x - (isLeft ? size : -size), y);
    path.close();
    canvas.drawPath(path, _eyePaint);
  }
}
