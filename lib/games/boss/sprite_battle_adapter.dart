// This file shows how to integrate your CreatureSpriteComponent into the battle system

import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:alchemons/games/boss/attack_animations.dart';
import 'package:alchemons/games/boss/battle_game.dart';
import 'package:alchemons/services/boss_battle_engine_service.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart'
    show Colors, TextStyle, TextPaint, Paint, MaskFilter, BlurStyle, Curves;

final _rng = math.Random();

/// Enhanced CreatureBattleSprite that uses your actual CreatureSpriteComponent
/// Replace the placeholder CircleComponent in battle_game.dart with this
class CreatureBattleSpriteWithVisuals extends PositionComponent
    with HasGameRef<BattleGame>, TapCallbacks {
  final BattleCombatant combatant;
  final int index;
  final SpriteSheetDef sheet;
  final SpriteVisuals visuals;
  final String? alchemyEffect; // 💡 NEW: Effect name to be displayed

  late PositionComponent statusIconContainer;
  late CircleComponent selectionIndicator;
  late PositionComponent _effectLayer;

  // The actual creature sprite component
  late CreatureSpriteComponentBattle creatureVisual;

  CreatureBattleSpriteWithVisuals({
    required this.combatant,
    required Vector2 position,
    required this.index,
    required this.sheet,
    required this.visuals,
    this.alchemyEffect, // 💡 Must be provided when the effect is active
  }) : super(
         position: position,
         size: Vector2(100, 120),
         anchor: Anchor.center,
       );

  @override
  Future<void> onLoad() async {
    // Add the actual creature sprite using your color filter system
    creatureVisual = CreatureSpriteComponentBattle(
      sheet: sheet,
      visuals: visuals,
      desiredSize: Vector2(80, 80), // Size for battle display
    );
    creatureVisual.position = size / 2;
    creatureVisual.anchor = Anchor.center;
    add(creatureVisual);

    _effectLayer = PositionComponent(
      // We know the creature's center is at (50, 60) relative to the parent's top-left corner (0, 0).
      // Let's set the effect layer's position to this exact point.
      position: size / 2,
      // Set the anchor to TOP_LEFT (the default).
      // This means the visual center of the glow component must be at (0, 0) for perfect alignment.
      anchor: Anchor.topLeft, // <<< CHANGE TO TOP_LEFT (Default)
      size: Vector2(
        1,
        1,
      ), // Set size to a minimal value, as it just holds the effect.
    )..priority = -2;
    add(_effectLayer);

    // 💡 Add the effect if present
    if (alchemyEffect != null) {
      _addEffectComponent(alchemyEffect!);
    }

    // Status icon container - above the creature visual (closer)
    statusIconContainer = PositionComponent(position: Vector2(0, -45));
    add(statusIconContainer);

    // Selection indicator (behind creature)
    selectionIndicator = CircleComponent(
      radius: 48,
      paint: Paint()
        ..color = Colors.yellow.withOpacity(0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .5,
      anchor: Anchor.center,
      position: size / 2,
    );
    add(selectionIndicator..priority = -1);
  }

  void _addEffectComponent(String effectName) {
    Component effectComponent;

    // The visual size of the creature is ~80x80. We need the effect to be larger.
    const double baseSize = 80;

    switch (effectName) {
      case 'alchemy_glow':
        // Replicates the pulsing radial glow
        effectComponent = FlameAlchemyGlow(baseSize: baseSize);
        break;
      case 'elemental_aura':
        // Replicates the orbiting particles
        // NOTE: We're passing a placeholder color, replace with your FactionColors lookup
        final elementColor = _getElementColor('Aqua');
        effectComponent = FlameElementalAura(
          baseSize: baseSize,
          color: elementColor,
        );
        break;
      default:
        return; // No known effect
    }

    _effectLayer.add(effectComponent);
  }

  // Placeholder for FactionColors logic
  Color _getElementColor(String element) {
    switch (element) {
      case 'Pyro':
        return Colors.red;
      case 'Aqua':
        return Colors.blue;
      case 'Terra':
        return Colors.green;
      default:
        return Colors.white;
    }
  }

  // Stub method - HP bar displayed elsewhere in the UI
  void updateHpBar() {
    // HP bar now handled by external UI components
  }

  void updateStatusIcons() {
    // Clear the old icons
    final toRemove = statusIconContainer.children.toList();
    for (final child in toRemove) {
      child.removeFromParent();
    }

    // Separate status effects and stat modifiers
    final effects = combatant.statusEffects.values.toList();
    final modifiers = combatant.statModifiers.values.toList();

    if (effects.isEmpty && modifiers.isEmpty) return;

    const double iconWidth = 38.0;
    const double rowSpacing = 18.0;

    // Create effects row
    if (effects.isNotEmpty) {
      final effectsRow = PositionComponent(position: Vector2(0, 0));

      for (int i = 0; i < effects.length; i++) {
        final icon = _createStatusIcon(effects[i].type);
        icon.position = Vector2(
          (i - effects.length / 2 + 0.5) * (iconWidth + 2),
          0,
        );
        effectsRow.add(icon);
      }

      statusIconContainer.add(effectsRow);
    }

    // Create modifiers row
    if (modifiers.isNotEmpty) {
      final modifiersRow = PositionComponent(
        position: Vector2(0, effects.isEmpty ? 0 : rowSpacing),
      );

      for (int i = 0; i < modifiers.length; i++) {
        final icon = _createStatModifierIcon(modifiers[i].type);
        icon.position = Vector2(
          (i - modifiers.length / 2 + 0.5) * (iconWidth + 2),
          0,
        );
        modifiersRow.add(icon);
      }

      statusIconContainer.add(modifiersRow);
    }
  }

  PositionComponent _createStatusIcon(String statusType) {
    Color bgColor;
    Color textColor;
    String text;

    switch (statusType) {
      case 'burn':
        bgColor = Colors.orange.withOpacity(0.85);
        textColor = Colors.white;
        text = 'BRN';
        break;
      case 'poison':
        bgColor = Colors.purple.withOpacity(0.85);
        textColor = Colors.white;
        text = 'PSN';
        break;
      case 'freeze':
        bgColor = Colors.cyan.withOpacity(0.85);
        textColor = Colors.black;
        text = 'FRZ';
        break;
      case 'curse':
        bgColor = Colors.purple.shade900.withOpacity(0.85);
        textColor = Colors.white;
        text = 'CRS';
        break;
      case 'regen':
        bgColor = Colors.green.withOpacity(0.85);
        textColor = Colors.white;
        text = 'REG';
        break;
      default:
        bgColor = Colors.grey.withOpacity(0.85);
        textColor = Colors.white;
        text = '???';
    }

    final container = PositionComponent(
      size: Vector2(36, 14),
      anchor: Anchor.center,
    );

    // Background pill
    final bg = RectangleComponent(
      size: Vector2(36, 14),
      paint: Paint()..color = bgColor,
      anchor: Anchor.center,
    )..position = Vector2(18, 7);

    container.add(bg);

    // Text
    container.add(
      TextComponent(
        text: text,
        anchor: Anchor.center,
        position: Vector2(18, 7),
        textRenderer: TextPaint(
          style: TextStyle(
            color: textColor,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    return container;
  }

  PositionComponent _createStatModifierIcon(String modifierType) {
    Color bgColor;
    Color textColor;
    String text;

    switch (modifierType) {
      case 'attack_up':
        bgColor = Colors.red.withOpacity(0.85);
        textColor = Colors.white;
        text = 'ATK↑';
        break;
      case 'attack_down':
        bgColor = Colors.red.shade300.withOpacity(0.85);
        textColor = Colors.white;
        text = 'ATK↓';
        break;
      case 'defense_up':
        bgColor = Colors.blue.withOpacity(0.85);
        textColor = Colors.white;
        text = 'DEF↑';
        break;
      case 'defense_down':
        bgColor = Colors.blue.shade300.withOpacity(0.85);
        textColor = Colors.white;
        text = 'DEF↓';
        break;
      case 'speed_up':
        bgColor = Colors.yellow.withOpacity(0.85);
        textColor = Colors.black;
        text = 'SPD↑';
        break;
      case 'speed_down':
        bgColor = Colors.yellow.shade700.withOpacity(0.85);
        textColor = Colors.white;
        text = 'SPD↓';
        break;
      default:
        bgColor = Colors.grey.withOpacity(0.85);
        textColor = Colors.white;
        text = '???';
    }

    final container = PositionComponent(
      size: Vector2(36, 14),
      anchor: Anchor.center,
    );

    // Background pill
    final bg = RectangleComponent(
      size: Vector2(36, 14),
      paint: Paint()..color = bgColor,
      anchor: Anchor.center,
    )..position = Vector2(18, 7);

    container.add(bg);

    // Text
    container.add(
      TextComponent(
        text: text,
        anchor: Anchor.center,
        position: Vector2(18, 7),
        textRenderer: TextPaint(
          style: TextStyle(
            color: textColor,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    return container;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!combatant.isDead) {
      gameRef.selectCreature(index);
    }
  }

  void playDeathAnimation() {
    // Mark as unselectable immediately
    setSelectionIndicator(false);

    // Calculate the target Y position to be completely off-screen
    final offScreenY = gameRef.size.y + size.y;

    const double duration = 1.5;

    // 1. Sink the creature down off the screen
    add(
      MoveEffect.to(
        Vector2(position.x, offScreenY),
        EffectController(duration: duration, curve: Curves.easeIn),
      ),
    );

    // 2. Add a subtle rotation for that satisfying "defeated" tumble
    add(
      RotateEffect.by(
        math.pi / 4, // Rotate by 45 degrees
        EffectController(duration: duration),
      ),
    );

    // 3. Remove the component (and all its children) completely after the animation
    add(RemoveEffect(delay: duration + 0.1));
  }

  Future<void> playAttackAnimation(BattleMove move, BossSprite target) async {
    // Safety check: don't attack if we're dead or dying
    if (combatant.isDead) return;

    final originalPos = position.clone();
    final isPhysical = move.type == MoveType.physical;

    // Full lunge for physical, small hop for others
    final forwardPos = isPhysical
        ? target.position + Vector2(0, 50)
        : position + Vector2(0, 10);

    // Attack FX
    final effect = AttackAnimations.getAnimation(
      move,
      combatant.types.first,
    ).createEffect(target.position);
    gameRef.post(() => gameRef.add(effect));

    // Sequence: forward -> back
    final completer = Completer<void>();

    final seq = SequenceEffect([
      MoveEffect.to(
        forwardPos,
        EffectController(duration: 0.20, curve: Curves.easeOut),
      ),
      MoveEffect.to(
        originalPos,
        EffectController(duration: 0.20, curve: Curves.easeIn),
      ),
    ]);

    seq.onComplete = () => completer.complete();

    add(seq);

    await completer.future;
  }

  void showDamage(int damage, double typeMultiplier) {
    // Safety check: don't show damage if we're already dead
    if (combatant.isDead) return;

    final color = typeMultiplier > 1.0
        ? Colors.orange
        : typeMultiplier < 1.0
        ? Colors.grey
        : Colors.white;

    // Put the text in a container so we can animate it cleanly
    final container = PositionComponent(
      position: position + Vector2(0, -50),
      anchor: Anchor.center,
    );

    final damageText = TextComponent(
      text: '-$damage',
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          color: color,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(blurRadius: 8, color: Colors.black),
            Shadow(blurRadius: 4, color: Colors.black),
          ],
        ),
      ),
    );

    container.add(damageText);
    gameRef.add(container);

    // Move up, then remove.
    container.add(
      SequenceEffect([
        MoveEffect.by(
          Vector2(0, -50),
          EffectController(duration: 0.8, curve: Curves.easeOut),
        ),
        RemoveEffect(),
      ]),
    );

    // Shake the creature when hit
    add(
      MoveEffect.by(
        Vector2(_rng.nextDouble() * 16 - 8, _rng.nextDouble() * 16 - 8),
        EffectController(duration: 0.05, reverseDuration: 0.05, repeatCount: 3),
      ),
    );
  }

  void setSelectionIndicator(bool selected) {
    selectionIndicator.paint.color = selected
        ? Colors.yellow.withOpacity(0.2)
        : Colors.yellow.withOpacity(0);
  }

  void setSelected(bool selected) {
    setSelectionIndicator(selected);

    // Remove any existing scale effects first
    removeWhere((component) => component is ScaleEffect);

    add(
      ScaleEffect.to(
        Vector2.all(selected ? 1.1 : 1.0),
        EffectController(duration: 0.15, curve: Curves.easeOut),
      ),
    );
  }

  void playSpawnAnimation() {
    // Start from below the screen and scale from small
    final startY = position.y + 100;
    position.y = startY;
    scale = Vector2.all(0.0);

    // Move up with bounce
    add(
      MoveEffect.by(
        Vector2(0, -100),
        EffectController(duration: 0.5, curve: Curves.easeOut),
      ),
    );

    // Scale up with overshoot then settle
    add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(1.2),
          EffectController(duration: 0.3, curve: Curves.easeOut),
        ),
        ScaleEffect.to(
          Vector2.all(1.0),
          EffectController(duration: 0.2, curve: Curves.easeIn),
        ),
      ]),
    );
  }
}

/// Adapted version of your CreatureSpriteComponent for battle use
class CreatureSpriteComponentBattle extends PositionComponent
    with HasGameRef<BattleGame> {
  final SpriteSheetDef sheet;
  final SpriteVisuals visuals;
  final Vector2 desiredSize;

  late final SpriteAnimationComponent _anim;
  double _prismaticHue = 0;

  CreatureSpriteComponentBattle({
    required this.sheet,
    required this.visuals,
    required this.desiredSize,
  });
  @override
  Future<void> onLoad() async {
    size = desiredSize;

    try {
      // Try loading the actual sprite sheet
      await gameRef.images.load(sheet.path);

      final image = gameRef.images.fromCache(sheet.path);
      final cols = (sheet.totalFrames + sheet.rows - 1) ~/ sheet.rows;

      final anim = SpriteAnimation.fromFrameData(
        image,
        SpriteAnimationData.sequenced(
          amount: sheet.totalFrames,
          amountPerRow: cols,
          textureSize: sheet.frameSize,
          stepTime: sheet.stepTime,
          loop: true,
        ),
      );

      final fit = _fitScale(sheet.frameSize, desiredSize);
      final finalScale = fit * visuals.scale;

      _anim =
          SpriteAnimationComponent(
              animation: anim,
              size: sheet.frameSize,
              anchor: Anchor.center,
              position: size / 2,
              priority: priority,
            )
            ..paint.filterQuality = FilterQuality.high
            ..scale = Vector2.all(finalScale);

      _applyColorFilters();
      add(_anim);
      return;
    } catch (e) {
      // FALLBACK CIRCLE
      final circle = CircleComponent(
        radius: desiredSize.x / 2,
        anchor: Anchor.center,
        position: size / 2,
        paint: Paint()
          ..color = Colors.red.withOpacity(0.5)
          ..style = PaintingStyle.fill,
      );

      add(circle);
      return;
    }
  }

  double _fitScale(Vector2 frame, Vector2 box) {
    final sx = box.x / frame.x;
    final sy = box.y / frame.y;
    return sx < sy ? sx : sy;
  }

  void _applyColorFilters() {
    final paint = _anim.paint;

    if (visuals.isAlbino && !visuals.isPrismatic) {
      paint.colorFilter = ColorFilter.matrix(albinoMatrix(visuals.brightness));
    } else {
      final hue = visuals.isPrismatic
          ? (visuals.hueShiftDeg + _prismaticHue)
          : visuals.hueShiftDeg;

      paint.colorFilter = ColorFilter.matrix(
        _combinedColorMatrix(
          brightness: visuals.brightness,
          saturation: visuals.saturation,
          hueShift: hue,
        ),
      );
    }

    if (visuals.tint != null && !(visuals.isAlbino && !visuals.isPrismatic)) {
      final currentColor = paint.color;
      paint.color = Color.alphaBlend(
        visuals.tint!.withOpacity(0.3),
        currentColor,
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (visuals.isPrismatic) {
      _prismaticHue = (_prismaticHue + 360 * dt / 8.0) % 360;
      _applyColorFilters();
    }
  }

  List<double> _combinedColorMatrix({
    required double brightness,
    required double saturation,
    required double hueShift,
  }) {
    final bsMat = brightnessSaturationMatrix(brightness, saturation);
    if (hueShift == 0) return bsMat;
    final hueMat = hueRotationMatrix(hueShift);
    return _multiplyMatrices(bsMat, hueMat);
  }

  List<double> _multiplyMatrices(List<double> a, List<double> b) {
    final result = List<double>.filled(20, 0);
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 5; col++) {
        if (col == 4) {
          result[row * 5 + 4] = a[row * 5 + 4] + b[row * 5 + 4];
        } else {
          double sum = 0;
          for (int k = 0; k < 4; k++) {
            sum += a[row * 5 + k] * b[k * 5 + col];
          }
          result[row * 5 + col] = sum;
        }
      }
    }
    return result;
  }
}

// ── FLAME EFFECT IMPLEMENTATIONS ────────────────────────────────────

/// Flame implementation of AlchemyGlow (Pulsing Radial Glow)
class FlameAlchemyGlow extends PositionComponent with HasGameRef {
  final double baseSize;
  double _time = 0;

  // The size of the glow component is twice the base size
  FlameAlchemyGlow({required this.baseSize})
    : super(
        // Set a huge size so the glow isn't clipped
        size: Vector2.all(baseSize * 4),
        // Position the anchor at the center of the component
        anchor: Anchor.center,
        // Place the center of the component at the parent's origin (0, 0)
        position: Vector2(0, 10),
      );

  @override
  void update(double dt) {
    _time += dt;
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    // Replicate the pulsing scale logic (0.4 to 1.2 over 1 second)
    final progress =
        (math.sin(_time * math.pi * 2) * 0.5 + 0.5); // 0..1 over 1s
    final pulseScale = 0.4 + progress * (1.2 - 0.4);

    final center = size / 2;
    final maxRadius = baseSize * pulseScale;

    // Create a paint with a subtle blur to mimic the soft edges of a glow/gradient
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12.0 * pulseScale);

    // Draw a series of circles with diminishing opacity to simulate radial gradient
    // Outer glow (largest and most transparent)
    canvas.drawCircle(center.toOffset(), maxRadius, paint);

    // Inner glow (brighter core)
    paint.color = Colors.purple.withOpacity(0.2);
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 4.0 * pulseScale);
    canvas.drawCircle(center.toOffset(), maxRadius * 0.6, paint);
  }
}

/// Flame implementation of ElementalAura (Orbiting Particles)
class FlameElementalAura extends PositionComponent with HasGameRef {
  final double baseSize;
  final Color color;
  double _time = 0;

  FlameElementalAura({required this.baseSize, required this.color})
    : super(size: Vector2.all(baseSize), anchor: Anchor.center);

  @override
  void update(double dt) {
    _time += dt; // Time is the progress for the animation
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final center = (size / 2).toOffset();
    final radius = baseSize * 0.4;

    // Flame equivalent of the Flutter CustomPainter logic
    final progress = (_time / 4.0) % 1.0; // Repeat every 4 seconds

    // Draw 5 orbiting particles
    for (int i = 0; i < 5; i++) {
      final angle = (progress * 2 * math.pi) + (i * 2 * math.pi / 5);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      // Particle size fixed at 3.0
      canvas.drawCircle(Offset(x, y), 3.0, paint);
    }
  }
}

// ── color matrix functions ────────────────────────────────────

List<double> brightnessSaturationMatrix(double brightness, double saturation) {
  final r = brightness, g = brightness, b = brightness, s = saturation;
  return <double>[
    s * r,
    0,
    0,
    0,
    0,
    0,
    s * g,
    0,
    0,
    0,
    0,
    0,
    s * b,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}

List<double> hueRotationMatrix(double degrees) {
  final radians = degrees * (math.pi / 180.0);
  final c = math.cos(radians), s = math.sin(radians);
  return <double>[
    0.213 + c * 0.787 - s * 0.213,
    0.715 - c * 0.715 - s * 0.715,
    0.072 - c * 0.072 + s * 0.928,
    0,
    0,
    0.213 - c * 0.213 + s * 0.143,
    0.715 + c * 0.285 + s * 0.140,
    0.072 - c * 0.072 - s * 0.283,
    0,
    0,
    0.213 - c * 0.213 - s * 0.787,
    0.715 - c * 0.715 + s * 0.715,
    0.072 + c * 0.928 + s * 0.072,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}

List<double> albinoMatrix(double brightness) {
  const double rLum = 0.299;
  const double gLum = 0.587;
  const double bLum = 0.114;

  return <double>[
    rLum * brightness,
    gLum * brightness,
    bLum * brightness,
    0,
    0,
    rLum * brightness,
    gLum * brightness,
    bLum * brightness,
    0,
    0,
    rLum * brightness,
    gLum * brightness,
    bLum * brightness,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}
