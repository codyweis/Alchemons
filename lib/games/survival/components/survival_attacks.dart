import 'dart:math';
import 'dart:ui';

import 'package:alchemons/games/survival/components/alchemy_projectile.dart';
import 'package:alchemons/games/survival/special_attacks/horn_special.dart';
import 'package:alchemons/games/survival/special_attacks/kin_special.dart';
import 'package:alchemons/games/survival/special_attacks/let_special.dart';
import 'package:alchemons/games/survival/special_attacks/mane_special.dart';
import 'package:alchemons/games/survival/special_attacks/mask_special.dart';
import 'package:alchemons/games/survival/special_attacks/mystic_special.dart';
import 'package:alchemons/games/survival/special_attacks/pip_special.dart';
import 'package:alchemons/games/survival/special_attacks/wing_special.dart';
import 'package:alchemons/games/survival/survival_combat.dart';
import 'package:alchemons/games/survival/survival_creature_sprite.dart';
import 'package:alchemons/games/survival/survival_enemies.dart';
import 'package:alchemons/games/survival/survival_game.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

// ... [SurvivalAttackManager and performBasic remain unchanged] ...
// Copy the top part of your file down to 'class LetMeteorMechanic'
// I will rewrite the Mechanic classes below to include the new logic.

class SurvivalAttackManager {
  static void triggerScreenShake(SurvivalHoardGame game, double intensity) {
    final offset = Vector2(
      (Random().nextDouble() - 0.5) * intensity,
      (Random().nextDouble() - 0.5) * intensity,
    );
    game.cameraComponent.viewfinder.position += offset;
    game.cameraComponent.viewfinder.add(
      MoveEffect.by(-offset, EffectController(duration: 0.1)),
    );
  }

  static void performSpecial({
    required SurvivalHoardGame game,
    required HoardGuardian attacker,
    required HoardEnemy? target,
  }) {
    final family = attacker.unit.family;
    final element = attacker.unit.types.firstOrNull ?? 'Normal';

    if (target == null &&
        family != 'Horn' &&
        family != 'Mask' &&
        family != 'Kin')
      return;

    switch (family) {
      case 'Let':
        LetMeteorMechanic.execute(game, attacker, target!, element);
        break;
      case 'Pip':
        PipRicochetMechanic.execute(game, attacker, target!, element);
        break;
      case 'Mane':
        ManeHazardMechanic.execute(game, attacker, target, element);
        break;
      case 'Horn':
        HornNovaMechanic.execute(game, attacker, target, element);
        break;
      case 'Mask':
        MaskVoidMechanic.execute(game, attacker, target, element);
        break;
      case 'Wing':
        WingPierceMechanic.execute(game, attacker, target!, element);
        break;
      case 'Kin':
        KinBlessingMechanic.execute(game, attacker, target, element);
        break;
      case 'Mystic':
        MysticOrbitalMechanic.execute(game, attacker, target, element);
        break;
      default:
        if (target != null) {
          _fireProjectile(game, attacker, target, element, damageMult: 1.5);
        }
    }
  }

  static void performBasic({
    required SurvivalHoardGame game,
    required HoardGuardian attacker,
    required HoardEnemy target,
  }) {
    final element = attacker.unit.types.firstOrNull ?? 'Normal';
    double speed = 1.0;
    if (attacker.unit.family == 'Wing' || attacker.unit.family == 'Pip')
      speed = 1.4;
    if (attacker.unit.family == 'Horn') speed = 0.8;

    _fireProjectile(
      game,
      attacker,
      target,
      element,
      speedMult: speed,
      onHitExtra: () {
        _applyElementalPassive(target, element, attacker.unit);
      },
    );
  }

  static void _applyElementalPassive(
    HoardEnemy target,
    String element,
    SurvivalUnit attacker,
  ) {
    final rng = Random();
    switch (element) {
      case 'Fire':
      case 'Lava':
      case 'Blood':
        target.unit.applyStatusEffect(
          SurvivalStatusEffect(
            type: 'Burn',
            damagePerTick: (attacker.statIntelligence * 2.5).toInt() + 5,
            ticksRemaining: 3,
            tickInterval: 0.8,
          ),
        );
        break;
      case 'Ice':
      case 'Water':
      case 'Steam':
      case 'Mud':
        final pushDir = (target.position - target.targetOrb.position)
            .normalized();
        target.position += pushDir * 12;
        break;
      case 'Poison':
      case 'Dark':
      case 'Spirit':
        target.unit.applyStatusEffect(
          SurvivalStatusEffect(
            type: 'Poison',
            damagePerTick: (attacker.statIntelligence * 0.8).toInt() + 3,
            ticksRemaining: 10,
            tickInterval: 0.4,
          ),
        );
        break;
      case 'Lightning':
      case 'Crystal':
      case 'Light':
        if (rng.nextDouble() < 0.25) {
          target.takeDamage((attacker.statStrength * 4).toInt());
          target.add(
            MoveEffect.by(
              Vector2(5, 0),
              EffectController(duration: 0.05, alternate: true, repeatCount: 2),
            ),
          );
        }
        break;
      default:
        break;
    }
  }

  static void _fireProjectile(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
    String element, {
    double damageMult = 1.0,
    double speedMult = 1.0,
    ProjectileShape? overrideShape,
    VoidCallback? onHitExtra,
  }) {
    final damage = SurvivalCombat.computeHitDamage(
      SurvivalAttackContext(
        attacker: attacker.unit,
        defender: target.unit,
        damageKind: SurvivalDamageKind.elemental,
        isSpecial: damageMult > 1.0,
      ),
    );
    final color = getElementColor(element);
    final shape = overrideShape ?? _getShapeForElement(element);

    game.spawnAlchemyProjectile(
      start: attacker.position,
      target: target,
      damage: (damage * damageMult).round(),
      color: color,
      shape: shape,
      speed: speedMult,
      onHit: () {
        target.takeDamage((damage * damageMult).round());
        ImpactVisuals.play(game, target.position, element);
        if (onHitExtra != null) onHitExtra();
      },
    );
  }

  // [Copy _getElementColor and _getShapeForElement from previous file]
  static Color getElementColor(String element) {
    switch (element) {
      case 'Fire':
      case 'Lava':
      case 'Blood':
        return Colors.deepOrangeAccent;
      case 'Water':
      case 'Ice':
      case 'Steam':
        return Colors.cyanAccent;
      case 'Earth':
      case 'Mud':
      case 'Dust':
        return Colors.brown;
      case 'Air':
        return Colors.lightBlueAccent;
      case 'Lightning':
      case 'Crystal':
        return Colors.yellow;
      case 'Plant':
        return Colors.greenAccent;
      case 'Poison':
      case 'Dark':
        return Colors.purpleAccent;
      case 'Light':
        return Colors.amber;
      case 'Spirit':
      case 'Mystic':
        return Colors.indigoAccent;
      default:
        return Colors.white;
    }
  }

  static ProjectileShape _getShapeForElement(String element) {
    switch (element) {
      case 'Fire':
      case 'Lava':
        return ProjectileShape.shard;
      case 'Air':
      case 'Lightning':
        return ProjectileShape.bolt;
      case 'Plant':
      case 'Poison':
        return ProjectileShape.thorn;
      case 'Water':
      case 'Ice':
        return ProjectileShape.blade;
      case 'Spirit':
      case 'Mystic':
        return ProjectileShape.star;
      default:
        return ProjectileShape.orb;
    }
  }
}

// ============================================================
//  REDESIGNED MECHANICS WITH RANK BONUSES
// ============================================================

class PiercingProjectile extends PositionComponent {
  final Vector2 start;
  final Vector2 end;
  final double speed;
  final double width;
  final int damage;
  final Color color;
  final SurvivalHoardGame game;
  final HoardGuardian attacker; // Added attacker reference
  final int rank; // Added rank

  final Set<HoardEnemy> _hitList = {};

  PiercingProjectile({
    required this.start,
    required this.end,
    required this.speed,
    required this.width,
    required this.damage,
    required this.color,
    required this.game,
    required this.attacker,
    required this.rank,
  }) : super(position: start, size: Vector2(40, width), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    final angle = atan2(end.y - start.y, end.x - start.x);
    this.angle = angle;

    add(
      RectangleComponent(
        size: Vector2(60, width),
        anchor: Anchor.center,
        paint: Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      ),
    );

    add(
      MoveEffect.to(
        end,
        EffectController(
          duration: start.distanceTo(end) / speed,
          curve: Curves.linear,
        ),
      ),
    );
    add(RemoveEffect(delay: start.distanceTo(end) / speed));
  }

  @override
  void update(double dt) {
    super.update(dt);
    final hitBoxRadius = width / 2 + 10;
    final victims = game.getEnemiesInRange(position, hitBoxRadius);

    for (var v in victims) {
      if (!_hitList.contains(v)) {
        _hitList.add(v);
        v.takeDamage(damage);
        ImpactVisuals.play(game, v.position, 'Air', scale: 0.5);

        // RANK 1 BONUS: PRECISION HEAL
        if (rank >= 1) {
          attacker.unit.heal((damage * 0.05).toInt().clamp(1, 50));
        }
      }
    }
  }
}

// [Include helper methods _calcDmg, ImpactVisuals, OrbitParticle from previous file]
double calcDmg(HoardGuardian att, HoardEnemy? def) {
  final defUnit =
      def?.unit ??
      SurvivalUnit(
        id: 'dummy',
        name: 'dummy',
        types: [],
        family: '',
        level: 1,
        statSpeed: 1,
        statIntelligence: 1,
        statStrength: 1,
        statBeauty: 1,
      );
  return SurvivalCombat.computeHitDamage(
    SurvivalAttackContext(
      attacker: att.unit,
      defender: defUnit,
      damageKind: SurvivalDamageKind.elemental,
      isSpecial: true,
    ),
  ).toDouble();
}

class ImpactVisuals {
  static void playExplosion(
    SurvivalHoardGame game,
    Vector2 pos,
    String element,
    double radius,
  ) {
    final color = SurvivalAttackManager.getElementColor(element);
    game.world.add(
      CircleComponent(
        radius: radius,
        position: pos,
        anchor: Anchor.center,
        paint: Paint()
          ..color = color.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      )..add(
        SequenceEffect([
          ScaleEffect.to(Vector2.all(1.2), EffectController(duration: 0.2)),
          OpacityEffect.fadeOut(EffectController(duration: 0.2)),
          RemoveEffect(),
        ]),
      ),
    );
    game.world.add(
      ParticleSystemComponent(
        position: pos,
        particle: Particle.generate(
          count: 20,
          lifespan: 0.6,
          generator: (i) => AcceleratedParticle(
            speed: Vector2(
              (Random().nextDouble() - 0.5) * 300,
              (Random().nextDouble() - 0.5) * 300,
            ),
            child: CircleParticle(radius: 4, paint: Paint()..color = color),
          ),
        ),
      ),
    );
  }

  static void play(
    SurvivalHoardGame game,
    Vector2 pos,
    String element, {
    double scale = 1.0,
  }) {
    game.world.add(
      ParticleSystemComponent(
        particle: Particle.generate(
          count: 8,
          lifespan: 0.4,
          generator: (i) => AcceleratedParticle(
            speed: Vector2(
              (Random().nextDouble() - 0.5) * 150,
              (Random().nextDouble() - 0.5) * 150,
            ),
            child: CircleParticle(
              radius: 2 * scale,
              paint: Paint()
                ..color = SurvivalAttackManager.getElementColor(element),
            ),
          ),
        ),
        position: pos,
      ),
    );
  }
}

class OrbitParticle extends Particle {
  final Particle child;
  final double radius;
  final double speed;
  final double initialAngle;

  OrbitParticle({
    required this.child,
    this.radius = 20.0,
    this.speed = 1.0,
    this.initialAngle = 0.0,
    super.lifespan,
  });

  @override
  void render(Canvas canvas) {
    final t = (1 - progress) * pi * 2 * speed;
    final dx = cos(initialAngle + t) * radius;
    final dy = sin(initialAngle + t) * radius;
    canvas.save();
    canvas.translate(dx, dy);
    child.render(canvas);
    canvas.restore();
  }

  @override
  void update(double dt) {
    super.update(dt);
    child.update(dt);
  }
}
