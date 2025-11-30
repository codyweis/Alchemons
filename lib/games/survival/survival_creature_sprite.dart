// // lib/games/survival/survival_creature_sprite.dart
// import 'dart:math' as math;
// import 'package:alchemons/games/survival/components/alchemy_projectile.dart'; // REQUIRED IMPORT
// import 'package:alchemons/games/survival/survival_combat.dart';
// import 'package:alchemons/games/survival/survival_enemies.dart';
// import 'package:alchemons/games/survival/survival_game.dart';
// import 'package:alchemons/widgets/wilderness/creature_sprite_component.dart';
// import 'package:flame/components.dart';
// import 'package:flame/effects.dart';
// import 'package:flutter/material.dart';

// class HoardGuardian extends PositionComponent
//     with HasGameRef<SurvivalHoardGame> {
//   final SurvivalUnit unit;
//   bool isDead = false;

//   double _basicAttackTimer = 0;
//   double _specialAbilityTimer = 0;
//   late double _basicInterval;
//   late double _specialInterval;

//   bool _isFlipped = false;
//   late PositionComponent _spriteContainer;

//   HoardGuardian({required this.unit, required Vector2 position})
//     : super(position: position, size: Vector2.all(100), anchor: Anchor.center);

//   @override
//   Future<void> onLoad() async {
//     // --- 1. STAT SCALING SETUP ---
//     _basicInterval = 1.5 / unit.cooldownReduction;
//     _specialInterval = 8.0 / unit.cooldownReduction;

//     // Initialize sprite container
//     _spriteContainer = PositionComponent(
//       size: size,
//       anchor: Anchor.center,
//       position: size / 2,
//     );
//     add(_spriteContainer);

//     // Visuals
//     if (unit.sheetDef != null && unit.spriteVisuals != null) {
//       final visual =
//           CreatureSpriteComponent<SurvivalHoardGame>(
//               sheet: unit.sheetDef!,
//               visuals: unit.spriteVisuals!,
//               desiredSize: size * 0.8,
//               alchemyEffect: unit.spriteVisuals!.alchemyEffect,
//               variantFaction: unit.spriteVisuals!.variantFaction,
//             )
//             ..anchor = Anchor.center
//             ..position = _spriteContainer.size / 2;
//       _spriteContainer.add(visual);
//     } else {
//       _spriteContainer.add(
//         CircleComponent(
//           radius: 40,
//           paint: Paint()
//             ..color = _getElementColor(
//               unit.types.firstOrNull ?? 'Normal',
//             ).withOpacity(0.7),
//           anchor: Anchor.center,
//           position: _spriteContainer.size / 2,
//         ),
//       );
//     }
//     _addNameLabel();
//   }

//   @override
//   void update(double dt) {
//     super.update(dt);
//     SurvivalCombat.tickRealtimeStatuses(unit, dt);

//     if (isDead || unit.isDead) {
//       if (!isDead) {
//         isDead = true;
//         _playDeathAnimation();
//       }
//       return;
//     }

//     // --- 2. COMBAT LOGIC ---

//     if (_basicAttackTimer > 0) _basicAttackTimer -= dt;
//     if (_specialAbilityTimer > 0) _specialAbilityTimer -= dt;

//     final target = gameRef.getNearestEnemy(position, unit.attackRange);

//     if (target != null) {
//       _faceTarget(target.position);

//       // PRIORITY SYSTEM:
//       if (_specialAbilityTimer <= 0) {
//         _performSpecialAbility(target);
//         _specialAbilityTimer = _specialInterval;
//       } else if (_basicAttackTimer <= 0) {
//         _performBasicAttack(target);
//         _basicAttackTimer = _basicInterval;
//       }
//     }
//   }

//   void _performBasicAttack(HoardEnemy target) {
//     // Basic = Physical Damage, uses Strength
//     final damage = SurvivalCombat.computeHitDamage(
//       SurvivalAttackContext(
//         attacker: unit,
//         defender: target.unit,
//         damageKind: SurvivalDamageKind.physical,
//         isSpecial: false,
//       ),
//     );

//     // FIX 1: Reset the angle explicitly to stop unwanted spinning.
//     _spriteContainer.angle = 0.0;

//     // Subtle animation
//     _spriteContainer.add(
//       ScaleEffect.to(
//         Vector2(1.1, 0.9),
//         EffectController(duration: 0.1, reverseDuration: 0.1),
//       ),
//     );

//     // FIX 2: Use the Elemental Alchemy Projectile logic
//     final color = _getElementColor(unit.types.firstOrNull ?? 'Normal');
//     final (shape, speed) = _getBasicAttackProperties(unit.family);

//     gameRef.spawnAlchemyProjectile(
//       // Corrected call
//       start: position,
//       target: target,
//       damage: damage,
//       color: color,
//       shape: shape,
//       speed: speed,
//     );
//   }

//   void _performSpecialAbility(HoardEnemy mainTarget) {
//     // FIX 1: Reset the angle explicitly to stop unwanted spinning.
//     _spriteContainer.angle = 0.0;

//     // Big animation "Cast"
//     _spriteContainer.add(
//       SequenceEffect([
//         ScaleEffect.by(Vector2.all(1.3), EffectController(duration: 0.2)),
//         ScaleEffect.by(Vector2.all(1 / 1.3), EffectController(duration: 0.2)),
//       ]),
//     );

//     // Ability logic depends on Family
//     switch (unit.family) {
//       case 'Let':
//         _doAoeAbility(mainTarget);
//         break;
//       case 'Horn':
//         _doShieldAbility();
//         break;
//       case 'Wing':
//         _doMultiShotAbility(mainTarget);
//         break;
//       case 'Mystic':
//         _doHealAbility();
//         break;
//       case 'Pip':
//       case 'Mane':
//         _doRapidFireAbility(mainTarget);
//         break;
//       default:
//         _doGenericNuke(mainTarget);
//     }
//   }

//   // --- ABILITY IMPLEMENTATIONS ---

//   void _doAoeAbility(HoardEnemy target) {
//     final dmg = _calcSpecialDmg(target.unit);
//     final color = _getElementColor(unit.types.firstOrNull ?? 'Fire');
//     final (shape, speed) = _getBasicAttackProperties(
//       unit.family,
//     ); // Use special shape

//     gameRef.spawnAlchemyProjectile(
//       // Corrected call
//       start: position,
//       target: target,
//       damage: dmg,
//       color: color,
//       shape: shape,
//       speed: speed,
//     );

//     final neighbors = gameRef.getEnemiesInRange(target.position, 150);
//     for (var n in neighbors) {
//       if (n != target) n.takeDamage((dmg * 0.6).toInt());
//     }
//   }

//   void _doShieldAbility() {
//     final amount = 20 + (unit.statIntelligence * 5).toInt();
//     gameRef.orb.heal(amount);

//     add(
//       CircleComponent(
//         radius: 60,
//         paint: Paint()
//           ..color = Colors.cyan.withOpacity(0.3)
//           ..style = PaintingStyle.stroke
//           ..strokeWidth = 4,
//       )..add(RemoveEffect(delay: 1.0)),
//     );
//   }

//   void _doMultiShotAbility(HoardEnemy primary) {
//     final targets = gameRef.getRandomEnemies(3);
//     if (!targets.contains(primary)) targets.add(primary);

//     final color = _getElementColor(unit.types.firstOrNull ?? 'Air');
//     final (shape, speed) = _getBasicAttackProperties(unit.family);

//     for (var t in targets) {
//       final dmg = _calcSpecialDmg(t.unit);
//       gameRef.spawnAlchemyProjectile(
//         // Corrected call
//         start: position,
//         target: t,
//         damage: dmg,
//         color: color,
//         shape: shape,
//         speed: speed,
//       );
//     }
//   }

//   void _doHealAbility() {
//     final heal = (unit.statIntelligence * 8 + 40).toInt();
//     gameRef.orb.heal(heal);

//     add(
//       CircleComponent(
//           radius: 10,
//           paint: Paint()
//             ..color = Colors.white
//             ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
//         )
//         ..add(
//           ScaleEffect.to(Vector2.all(15.0), EffectController(duration: 0.4)),
//         )
//         ..add(RemoveEffect(delay: 0.4)),
//     );
//   }

//   void _doRapidFireAbility(HoardEnemy target) async {
//     final color = _getElementColor(unit.types.firstOrNull ?? 'Plant');
//     final (shape, speed) = _getBasicAttackProperties(unit.family);

//     for (int i = 0; i < 5; i++) {
//       if (target.isDead) break;
//       final dmg = (_calcSpecialDmg(target.unit) * 0.3).toInt();

//       gameRef.spawnAlchemyProjectile(
//         // Corrected call
//         start: position,
//         target: target,
//         damage: dmg,
//         color: color,
//         shape: shape,
//         speed: speed,
//       );
//       await Future.delayed(const Duration(milliseconds: 150));
//     }
//   }

//   void _doGenericNuke(HoardEnemy target) {
//     final dmg = (_calcSpecialDmg(target.unit) * 1.8).toInt();
//     final color = _getElementColor(unit.types.firstOrNull ?? 'Normal');
//     final (shape, speed) = _getBasicAttackProperties(unit.family);

//     gameRef.spawnAlchemyProjectile(
//       // Corrected call
//       start: position,
//       target: target,
//       damage: dmg,
//       color: color,
//       shape: shape,
//       speed: speed,
//     );
//   }

//   // --- NEW PROJECTILE HELPERS (Duplicated from earlier) ---

//   (ProjectileShape shape, double speed) _getBasicAttackProperties(
//     String family,
//   ) {
//     double speedMod = 1.0;
//     ProjectileShape shape;

//     switch (family) {
//       case 'Wing':
//       case 'Pip':
//         shape = ProjectileShape.blade;
//         speedMod = 1.3;
//         break;
//       case 'Let':
//         shape = ProjectileShape.shard;
//         speedMod = 1.0;
//         break;
//       case 'Mystic':
//       case 'Spirit':
//         shape = ProjectileShape.star;
//         speedMod = 0.9;
//         break;
//       case 'Mane':
//       case 'Plant':
//         shape = ProjectileShape.thorn;
//         speedMod = 1.1;
//         break;
//       case 'Horn':
//       default:
//         shape = ProjectileShape.orb;
//         speedMod = 0.8;
//         break;
//     }
//     return (shape, speedMod);
//   }

//   int _calcSpecialDmg(SurvivalUnit defender) {
//     return SurvivalCombat.computeHitDamage(
//       SurvivalAttackContext(
//         attacker: unit,
//         defender: defender,
//         damageKind: SurvivalDamageKind.elemental,
//         isSpecial: true,
//       ),
//     );
//   }

//   // --- UTILS ---

//   void takeDamage(int amount) {
//     if (isDead) return;
//     unit.takeDamage(amount);
//     _flashDamage();
//     if (unit.isDead) {
//       isDead = true;
//       _playDeathAnimation();
//     }
//   }

//   void _flashDamage() {
//     _spriteContainer.add(
//       SequenceEffect([
//         ScaleEffect.to(Vector2(1.1, 0.9), EffectController(duration: 0.06)),
//         ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.08)),
//       ]),
//     );
//   }

//   void _playDeathAnimation() {
//     add(
//       SequenceEffect([
//         ScaleEffect.to(Vector2.zero(), EffectController(duration: 0.4)),
//         RemoveEffect(),
//       ]),
//     );

//     add(MoveEffect.by(Vector2(0, 30), EffectController(duration: 0.4)));
//   }

//   void _faceTarget(Vector2 targetPos) {
//     final shouldFlip = targetPos.x < position.x;
//     if (shouldFlip != _isFlipped) {
//       _isFlipped = shouldFlip;
//       _spriteContainer.scale.x = _isFlipped ? -1 : 1;
//     }
//   }

//   void _addNameLabel() {
//     add(
//       TextComponent(
//         text: unit.name,
//         anchor: Anchor.center,
//         position: Vector2(size.x / 2, size.y + 10),
//         textRenderer: TextPaint(
//           style: const TextStyle(
//             color: Colors.white,
//             fontSize: 10,
//             fontWeight: FontWeight.bold,
//             shadows: [Shadow(blurRadius: 2, color: Colors.black)],
//           ),
//         ),
//       ),
//     );
//   }

//   Color _getElementColor(String type) {
//     switch (type) {
//       case 'Fire':
//       case 'Lava':
//         return Colors.deepOrange;
//       case 'Water':
//       case 'Steam':
//         return Colors.blueAccent;
//       case 'Ice':
//         return Colors.cyanAccent;
//       case 'Earth':
//       case 'Mud':
//         return Colors.brown;
//       case 'Air':
//       case 'Dust':
//         return Colors.blueGrey;
//       case 'Lightning':
//         return Colors.yellowAccent;
//       case 'Plant':
//         return Colors.green;
//       case 'Poison':
//         return Colors.purpleAccent;
//       case 'Crystal':
//         return Colors.tealAccent;
//       case 'Spirit':
//         return Colors.indigoAccent;
//       case 'Dark':
//         return Colors.purple.shade900;
//       case 'Light':
//         return Colors.amberAccent;
//       case 'Blood':
//         return Colors.redAccent;
//       default:
//         return Colors.grey;
//     }
//   }
// }
// lib/games/survival/survival_creature_sprite.dart
import 'dart:math' as math;
import 'package:alchemons/games/survival/components/alchemy_projectile.dart'; // REQUIRED IMPORT
import 'package:alchemons/games/survival/components/guardian_indicator.dart';
import 'package:alchemons/games/survival/components/survival_attacks.dart';
import 'package:alchemons/games/survival/survival_combat.dart';
import 'package:alchemons/games/survival/survival_enemies.dart';
import 'package:alchemons/games/survival/survival_game.dart';
import 'package:alchemons/widgets/wilderness/creature_sprite_component.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

class HoardGuardian extends PositionComponent
    with HasGameRef<SurvivalHoardGame>, TapCallbacks {
  final SurvivalUnit unit;
  bool isDead = false;

  double _basicAttackTimer = 0;
  double _specialAbilityTimer = 0;
  late double _basicInterval;
  late double _specialInterval;

  bool _isFlipped = false;
  late PositionComponent _spriteContainer;

  HoardGuardian({required this.unit, required Vector2 position})
    : super(position: position, size: Vector2.all(100), anchor: Anchor.center);

  Vector2 _sizeForSpecies(Vector2 baseSize, String family) {
    // Example: use your own data/model here instead of hardcoding
    const Map<String, double> speciesScale = {
      'let': 1.05,
      'pip': 1.35,
      'mane': 1.35,
      'horn': 1.5,
      'mask': 1.575,
      'wing': 1.65,
      'kin': 1.5,
      'mystic': 1.5,
    };

    final scale = speciesScale.containsKey(family.toLowerCase())
        ? speciesScale[family.toLowerCase()]!
        : 1.0;
    return baseSize * scale;
  }

  @override
  Future<void> onLoad() async {
    // --- 1. STAT SCALING SETUP ---
    _basicInterval = .9 / unit.cooldownReduction;
    _specialInterval = 5.0 / unit.cooldownReduction;

    size = _sizeForSpecies(Vector2.all(100), unit.family);

    // Initialize sprite container
    _spriteContainer = PositionComponent(
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    );
    add(_spriteContainer);

    // Visuals
    if (unit.sheetDef != null && unit.spriteVisuals != null) {
      final visual =
          CreatureSpriteComponent<SurvivalHoardGame>(
              sheet: unit.sheetDef!,
              visuals: unit.spriteVisuals!,
              desiredSize: size * 0.8,
              alchemyEffect: unit.spriteVisuals!.alchemyEffect,
              variantFaction: unit.spriteVisuals!.variantFaction,
            )
            ..anchor = Anchor.center
            ..position = _spriteContainer.size / 2;
      _spriteContainer.add(visual);
    } else {
      _spriteContainer.add(
        CircleComponent(
          radius: 40,
          paint: Paint()
            ..color = _getElementColor(
              unit.types.firstOrNull ?? 'Normal',
            ).withOpacity(0.7),
          anchor: Anchor.center,
          position: _spriteContainer.size / 2,
        ),
      );
    }
    _addNameLabel();

    // When selected, add a range indicator as a child
    gameRef.selectedGuardianNotifier.addListener(() {
      final selected = gameRef.selectedGuardianNotifier.value;
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
    if (gameRef.selectedGuardianNotifier.value == this) {
      gameRef.selectGuardian(null);
    } else {
      gameRef.selectGuardian(this);
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

    final basicTarget = gameRef.getNearestEnemy(position, unit.attackRange);
    final specialTarget = gameRef.getNearestEnemy(
      position,
      unit.specialAbilityRange,
    );

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

  void _performBasicAttack(HoardEnemy target) {
    // Basic = Physical Damage, uses Strength
    final damage = SurvivalCombat.computeHitDamage(
      SurvivalAttackContext(
        attacker: unit,
        defender: target.unit,
        damageKind: SurvivalDamageKind.physical,
        isSpecial: false,
      ),
    );

    // FIX 1: Reset the angle explicitly to stop unwanted spinning.
    _spriteContainer.angle = 0.0;

    // Subtle animation
    _spriteContainer.add(
      ScaleEffect.to(
        Vector2(1.1, 0.9),
        EffectController(duration: 0.1, reverseDuration: 0.1),
      ),
    );

    // DELEGATE TO MANAGER
    SurvivalAttackManager.performBasic(
      game: gameRef,
      attacker: this,
      target: target,
    );

    // FIX 2: Use the Elemental Alchemy Projectile logic
    final color = _getElementColor(unit.types.firstOrNull ?? 'Normal');
    final (shape, speed) = _getBasicAttackProperties(unit.family);

    gameRef.spawnAlchemyProjectile(
      // Corrected call
      start: position,
      target: target,
      damage: damage,
      color: color,
      shape: shape,
      speed: speed,
    );
  }

  void _performSpecialAbility(HoardEnemy mainTarget) {
    // FIX 1: Reset the angle explicitly to stop unwanted spinning.
    _spriteContainer.angle = 0.0;

    // Big animation "Cast"
    _spriteContainer.add(
      SequenceEffect([
        ScaleEffect.by(Vector2.all(1.3), EffectController(duration: 0.2)),
        ScaleEffect.by(Vector2.all(1 / 1.3), EffectController(duration: 0.2)),
      ]),
    );

    SurvivalAttackManager.performSpecial(
      game: gameRef,
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

  int _calcSpecialDmg(SurvivalUnit defender) {
    return SurvivalCombat.computeHitDamage(
      SurvivalAttackContext(
        attacker: unit,
        defender: defender,
        damageKind: SurvivalDamageKind.elemental,
        isSpecial: true,
      ),
    );
  }

  // --- UTILS ---

  void takeDamage(int amount) {
    if (isDead) return;
    unit.takeDamage(amount);
    _flashDamage();
    if (unit.isDead) {
      isDead = true;
      _playDeathAnimation();
    }
  }

  void _flashDamage() {
    _spriteContainer.add(
      SequenceEffect([
        ScaleEffect.to(Vector2(1.1, 0.9), EffectController(duration: 0.06)),
        ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.08)),
      ]),
    );
  }

  void _playDeathAnimation() {
    add(
      SequenceEffect([
        ScaleEffect.to(Vector2.zero(), EffectController(duration: 0.4)),
        RemoveEffect(),
      ]),
    );

    add(MoveEffect.by(Vector2(0, 30), EffectController(duration: 0.4)));
  }

  void _faceTarget(Vector2 targetPos) {
    final shouldFlip = targetPos.x < position.x;
    if (shouldFlip != _isFlipped) {
      _isFlipped = shouldFlip;
      _spriteContainer.scale.x = _isFlipped ? -1 : 1;
    }
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
