import 'package:alchemons/games/survival/components/alchemy_projectile.dart'; // REQUIRED IMPORT
import 'package:alchemons/games/survival/components/guardian_indicator.dart';
import 'package:alchemons/games/survival/components/survival_attacks.dart';
import 'package:alchemons/games/survival/survival_combat.dart';
import 'package:alchemons/games/survival/enemies/survival_enemies.dart';
import 'package:alchemons/games/survival/survival_game.dart';
import 'package:alchemons/widgets/wilderness/creature_sprite_component.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

enum TargetPriority { closest, furthest, boss }

const bool _debugGuardianDamageLogs = false;

class HoardGuardian extends PositionComponent
    with HasGameReference<SurvivalHoardGame>, TapCallbacks {
  final SurvivalUnit unit;
  bool isDead = false;

  TargetPriority targetPriority = TargetPriority.closest;

  void cycleTargetPriority() {
    final all = TargetPriority.values;
    final nextIndex = (all.indexOf(targetPriority) + 1) % all.length;
    targetPriority = all[nextIndex];
  }

  String get targetPriorityLabel {
    switch (targetPriority) {
      case TargetPriority.closest:
        return 'Closest';
      case TargetPriority.furthest:
        return 'Furthest';
      case TargetPriority.boss:
        return 'Boss';
    }
  }

  double _basicAttackTimer = 0;
  double _specialAbilityTimer = 0;
  late double _basicInterval;
  late double _specialInterval;

  late PositionComponent _animContainer;

  bool _isFlipped = false;
  late PositionComponent _spriteContainer;

  HoardGuardian({required this.unit, required Vector2 position})
    : super(position: position, size: Vector2.all(100), anchor: Anchor.center);

  Vector2 _sizeForSpecies(Vector2 baseSize, String family) {
    // Example: use your own data/model here instead of hardcoding
    const Map<String, double> speciesScale = {
      'let': 1,
      'pip': 1,
      'mane': 1.2,
      'horn': 1.7,
      'mask': 1.5,
      'wing': 2.0,
      'kin': 2.0,
      'mystic': 2.4,
    };

    final scale = speciesScale.containsKey(family.toLowerCase())
        ? speciesScale[family.toLowerCase()]!
        : 1.0;
    // Make all guardians 15% bigger
    return baseSize * scale * 1.15;
  }

  @override
  Future<void> onLoad() async {
    _basicInterval = .9 / unit.cooldownReduction;
    // Mystics have a longer special cooldown — their orbitals are very powerful
    _specialInterval =
        (unit.family == 'Mystic' ? 14.0 : 5.0) / unit.cooldownReduction;

    size = _sizeForSpecies(Vector2.all(100), unit.family);

    // Root sprite container: handles flipping
    _spriteContainer = PositionComponent(
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    );
    add(_spriteContainer);

    // Inner container: handles scaling / hit / cast / damage effects
    _animContainer = PositionComponent(
      size: size,
      anchor: Anchor.center,
      position: _spriteContainer.size / 2,
    );
    _spriteContainer.add(_animContainer);

    if (unit.sheetDef != null && unit.spriteVisuals != null) {
      final visual =
          CreatureSpriteComponent<SurvivalHoardGame>(
              sheet: unit.sheetDef!,
              visuals: unit.spriteVisuals!,
              desiredSize: size * 0.8,
              alchemyEffect: unit.spriteVisuals!.alchemyEffect,
              variantFaction: unit.spriteVisuals!.variantFaction,
              effectScale: 0.72,
            )
            ..anchor = Anchor.center
            ..position = _animContainer.size / 2;
      _animContainer.add(visual);
    } else {
      _animContainer.add(
        CircleComponent(
          radius: 40,
          paint: Paint()
            ..color = _getElementColor(
              unit.types.firstOrNull ?? 'Normal',
            ).withValues(alpha: 0.7),
          anchor: Anchor.center,
          position: _animContainer.size / 2,
        ),
      );
    }

    _addNameLabel();

    // When selected, add a range indicator as a child
    game.selectedGuardianNotifier.addListener(() {
      final selected = game.selectedGuardianNotifier.value;
      if (selected == this) {
        // Add indicator (as child so it follows position)
        if (children.whereType<GuardianRangeIndicator>().isEmpty) {
          add(GuardianRangeIndicator(guardian: this));
        }
      } else {
        // Remove if deselected
        children.whereType<GuardianRangeIndicator>().forEach(
          (c) => c.removeFromParent(),
        );
      }
    });
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);

    // Toggle selection: tap again to deselect
    if (game.selectedGuardianNotifier.value == this) {
      game.selectGuardian(null);
    } else {
      game.selectGuardian(this);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    SurvivalCombat.tickRealtimeStatuses(unit, dt);

    if (isDead || unit.isDead) {
      if (!isDead) {
        isDead = true;
        _playDeathAnimation();
      }
      return;
    }

    // --- 2. COMBAT LOGIC ---

    if (_basicAttackTimer > 0) _basicAttackTimer -= dt;
    if (_specialAbilityTimer > 0) _specialAbilityTimer -= dt;

    // Use target priority for both basic & special
    final specialTarget = _pickTarget(unit.specialAbilityRange);
    final basicTarget = _pickTarget(unit.attackRange);

    if (specialTarget != null && _specialAbilityTimer <= 0) {
      _faceTarget(specialTarget.position);
      _performSpecialAbility(specialTarget);
      _specialAbilityTimer = _specialInterval;
    } else if (basicTarget != null && _basicAttackTimer <= 0) {
      _faceTarget(basicTarget.position);
      _performBasicAttack(basicTarget);
      _basicAttackTimer = _basicInterval;
    }
  }

  /// Picks target based on this guardian's [targetPriority].
  HoardEnemy? _pickTarget(double range) {
    switch (targetPriority) {
      case TargetPriority.closest:
        return game.getNearestEnemy(position, range);

      case TargetPriority.furthest:
        return _getFurthestEnemyInRange(range);

      case TargetPriority.boss:
        return _getBossInRange(range) ?? game.getNearestEnemy(position, range);
    }
  }

  HoardEnemy? _getFurthestEnemyInRange(double range) {
    final enemies = game.enemies;
    HoardEnemy? furthest;
    double maxDstSq = 0;
    final rangeSq = range * range;

    for (final e in enemies) {
      if (e.isDead) continue;
      final dstSq = position.distanceToSquared(e.position);
      if (dstSq <= rangeSq && dstSq > maxDstSq) {
        maxDstSq = dstSq;
        furthest = e;
      }
    }
    return furthest;
  }

  HoardEnemy? _getBossInRange(double range) {
    final enemies = game.enemies;
    HoardEnemy? best;
    double minDstSq = range * range;

    for (final e in enemies) {
      if (e.isDead || !e.isBoss) continue;
      final dstSq = position.distanceToSquared(e.position);
      if (dstSq < minDstSq) {
        minDstSq = dstSq;
        best = e;
      }
    }

    return best;
  }

  void _performBasicAttack(HoardEnemy target) {
    final damage = SurvivalCombat.computeHitDamage(
      SurvivalAttackContext(
        attacker: unit,
        defender: target.unit,
        damageKind: SurvivalDamageKind.physical,
        isSpecial: false,
      ),
    );

    // No need to touch angle for spinning; we’re not rotating this container.
    // _spriteContainer.angle = 0.0;  // <- you can safely drop this

    // Clear any existing squash effects to avoid compounding
    _clearScaleEffects();

    _animContainer.add(
      ScaleEffect.to(
        Vector2(1.1, 0.9),
        EffectController(duration: 0.1, reverseDuration: 0.1),
      ),
    );

    SurvivalAttackManager.performBasic(
      game: game,
      attacker: this,
      target: target,
    );

    final color = _getElementColor(unit.types.firstOrNull ?? 'Normal');
    final (shape, speed) = _getBasicAttackProperties(unit.family);

    game.spawnAlchemyProjectile(
      start: position,
      target: target,
      damage: damage,
      color: color,
      shape: shape,
      speed: speed,
    );
  }

  void _performSpecialAbility(HoardEnemy mainTarget) {
    _clearScaleEffects();

    _animContainer.add(
      SequenceEffect([
        ScaleEffect.by(Vector2.all(1.3), EffectController(duration: 0.2)),
        ScaleEffect.by(Vector2.all(1 / 1.3), EffectController(duration: 0.2)),
      ]),
    );

    SurvivalAttackManager.performSpecial(
      game: game,
      attacker: this,
      target: mainTarget,
    );
  }
  // --- NEW PROJECTILE HELPERS (Duplicated from earlier) ---

  (ProjectileShape shape, double speed) _getBasicAttackProperties(
    String family,
  ) {
    double speedMod = 1.0;
    ProjectileShape shape;

    switch (family) {
      case 'Wing':
      case 'Pip':
        shape = ProjectileShape.blade;
        speedMod = 1.3;
        break;
      case 'Let':
        shape = ProjectileShape.shard;
        speedMod = 1.0;
        break;
      case 'Mystic':
      case 'Spirit':
        shape = ProjectileShape.star;
        speedMod = 0.9;
        break;
      case 'Mane':
      case 'Plant':
        shape = ProjectileShape.thorn;
        speedMod = 1.1;
        break;
      case 'Horn':
      default:
        shape = ProjectileShape.orb;
        speedMod = 0.8;
        break;
    }
    return (shape, speedMod);
  }

  // --- UTILS ---

  void takeDamage(int amount, {String? source, bool isBossAttack = false}) {
    if (isDead) return;

    if (_debugGuardianDamageLogs) {
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('🛡️ GUARDIAN TAKING DAMAGE: ${unit.name}');
      debugPrint('───────────────────────────────────────────────────');
      debugPrint('   Source: ${source ?? "unknown"}');
      debugPrint('   Incoming Damage: $amount');
      debugPrint('   HP Before: ${unit.currentHp}/${unit.maxHp}');
      debugPrint('   Shield: ${unit.shieldHp ?? 0}');
    }

    unit.takeDamage(amount);

    if (_debugGuardianDamageLogs) {
      debugPrint('   HP After: ${unit.currentHp}/${unit.maxHp}');
      if (unit.isDead) {
        debugPrint('   💀 GUARDIAN KILLED!');
      }
      debugPrint('═══════════════════════════════════════════════════');
    }

    _flashDamage();

    // Boss attack visual feedback
    if (isBossAttack) {
      _playBossHitEffect(amount);
    }

    if (unit.isDead) {
      isDead = true;
      _playDeathAnimation();
    }
  }

  void _playBossHitEffect(int damage) {
    // 1. Screen shake
    game.camera.viewfinder.add(
      MoveEffect.by(
        Vector2(8, 0),
        EffectController(duration: 0.03, reverseDuration: 0.03, repeatCount: 3),
      ),
    );

    // 2. Guardian knockback/squash
    _clearScaleEffects();

    _animContainer.add(
      SequenceEffect([
        ScaleEffect.to(Vector2(1.3, 0.7), EffectController(duration: 0.08)),
        ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.15)),
      ]),
    );

    // 3. Impact ring expansion
    final impactRing = CircleComponent(
      radius: 20,
      position: size / 2,
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.redAccent.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    add(impactRing);

    impactRing.add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(3.0),
          EffectController(duration: 0.25, curve: Curves.easeOut),
        ),
        RemoveEffect(),
      ]),
    );

    // 4. Red flash overlay
    final flashOverlay = CircleComponent(
      radius: size.x / 2,
      position: size / 2,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.red.withValues(alpha: 0.6),
    );
    add(flashOverlay);

    flashOverlay.add(
      SequenceEffect([
        ScaleEffect.to(Vector2.all(0.8), EffectController(duration: 0.15)),
        RemoveEffect(),
      ]),
    );

    // 5. Damage number popup
    final damageText = TextComponent(
      text: '-$damage',
      position: Vector2(size.x / 2, -10),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          color: Colors.red.shade300,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
        ),
      ),
    );
    add(damageText);

    damageText.add(
      SequenceEffect([
        MoveEffect.by(
          Vector2(0, -30),
          EffectController(duration: 0.6, curve: Curves.easeOut),
        ),
        RemoveEffect(),
      ]),
    );
  }

  void _flashDamage() {
    _clearScaleEffects();

    _animContainer.add(
      SequenceEffect([
        ScaleEffect.to(Vector2(1.1, 0.9), EffectController(duration: 0.06)),
        ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.08)),
      ]),
    );
  }

  void _clearScaleEffects() {
    _animContainer.children
        .whereType<Effect>()
        .where((e) => e is ScaleEffect || e is SequenceEffect)
        .toList()
        .forEach((e) => e.removeFromParent());

    // If an effect was interrupted mid-frame, force a clean baseline scale.
    _animContainer.scale = Vector2.all(1.0);

    // Keep facing direction but reset any accidental Y distortion.
    _spriteContainer.scale = Vector2(_isFlipped ? -1.0 : 1.0, 1.0);
  }

  void _playDeathAnimation() {
    add(
      SequenceEffect([
        ScaleEffect.to(Vector2.zero(), EffectController(duration: 0.4)),
        RemoveEffect(),
      ]),
    );

    add(MoveEffect.by(Vector2(0, 30), EffectController(duration: 0.4)));
    game.onGuardianDied(this);
  }

  void _faceTarget(Vector2 targetPos) {
    final dx = targetPos.x - position.x;

    // Don’t flip if target is almost directly above/below (prevents jitter)
    if (dx.abs() < 8) return;

    final shouldFlip = dx > 0;
    if (shouldFlip == _isFlipped) return;

    _isFlipped = shouldFlip;
    _spriteContainer.scale.x = _isFlipped ? -1 : 1;
  }

  void _addNameLabel() {
    add(
      TextComponent(
        text: unit.name,
        anchor: Anchor.center,
        position: Vector2(size.x / 2, size.y + 10),
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(blurRadius: 2, color: Colors.black)],
          ),
        ),
      ),
    );
  }

  Color _getElementColor(String type) {
    switch (type) {
      case 'Fire':
      case 'Lava':
        return Colors.deepOrange;
      case 'Water':
      case 'Steam':
        return Colors.blueAccent;
      case 'Ice':
        return Colors.cyanAccent;
      case 'Earth':
      case 'Mud':
        return Colors.brown;
      case 'Air':
      case 'Dust':
        return Colors.blueGrey;
      case 'Lightning':
        return Colors.yellowAccent;
      case 'Plant':
        return Colors.green;
      case 'Poison':
        return Colors.purpleAccent;
      case 'Crystal':
        return Colors.tealAccent;
      case 'Spirit':
        return Colors.indigoAccent;
      case 'Dark':
        return Colors.purple.shade900;
      case 'Light':
        return Colors.amberAccent;
      case 'Blood':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }
}
