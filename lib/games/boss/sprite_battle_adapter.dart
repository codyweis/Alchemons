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

    // Status icon container - above the creature visual
    statusIconContainer = PositionComponent(position: Vector2(0, -60));
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

    int iconIndex = 0;
    final iconSpacing = 32.0; // Spacing for the short text
    final totalIcons =
        combatant.statusEffects.length + combatant.statModifiers.length;

    for (final effect in combatant.statusEffects.values) {
      final icon = _createStatusText(effect.type);
      icon.position = Vector2(
        (iconIndex - totalIcons / 2 + 0.5) * iconSpacing,
        0,
      );
      statusIconContainer.add(icon);
      iconIndex++;
    }

    for (final modifier in combatant.statModifiers.values) {
      final icon = _createStatModifierText(modifier.type);
      icon.position = Vector2(
        (iconIndex - totalIcons / 2 + 0.5) * iconSpacing,
        0,
      );
      statusIconContainer.add(icon);
      iconIndex++;
    }
  }

  // ... (rest of helper methods like _createStatusText, _createStatModifierText, etc. remain unchanged)
  // ... (rest of interaction methods like onTapDown, playDeathAnimation, etc. remain unchanged)

  TextComponent _createStatusText(String statusType) {
    Color color;
    String text;
    switch (statusType) {
      case 'burn':
        color = Colors.orange;
        text = 'BRN';
        break;
      case 'poison':
        color = Colors.purple;
        text = 'PSN';
        break;
      case 'freeze':
        color = Colors.cyan;
        text = 'FRZ';
        break;
      case 'curse':
        color = Colors.purple.shade900;
        text = 'CRS';
        break;
      case 'regen':
        color = Colors.green;
        text = 'REG';
        break;
      default:
        color = Colors.grey;
        text = '???';
    }
    return TextComponent(
      text: text,
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          color: color,
          fontSize: 10, // Smaller for creature
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(blurRadius: 2, color: Colors.black.withOpacity(0.8)),
          ],
        ),
      ),
    );
  }

  TextComponent _createStatModifierText(String modifierType) {
    Color color;
    String text;
    switch (modifierType) {
      case 'attack_up':
        color = Colors.red;
        text = 'ATK⬆';
        break;
      case 'attack_down':
        color = Colors.red.shade300;
        text = 'ATK⬇';
        break;
      case 'defense_up':
        color = Colors.blue;
        text = 'DEF⬆';
        break;
      case 'defense_down':
        color = Colors.blue.shade300;
        text = 'DEF⬇';
        break;
      case 'speed_up':
        color = Colors.yellow;
        text = 'SPD⬆';
        break;
      case 'speed_down':
        color = Colors.yellow.shade700;
        text = 'SPD⬇';
        break;
      default:
        color = Colors.grey;
        text = '???';
    }
    return TextComponent(
      text: text,
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          color: color,
          fontSize: 10, // Smaller for creature
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(blurRadius: 2, color: Colors.black.withOpacity(0.8)),
          ],
        ),
      ),
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!combatant.isDead) {
      gameRef.selectCreature(index);
    }
  }

  void playDeathAnimation() {
    // Make sure we can't select it anymore
    setSelectionIndicator(false);

    // Also fade out all the UI elements (status icons, selection indicator)
    // We apply the opacity to the main component so everything moves/fades together.

    // --- START SINKING IMPLEMENTATION ---

    // Calculate the target Y position to be completely off-screen
    // gameRef.size.y is the absolute bottom of the screen.
    final offScreenY = gameRef.size.y + size.y;

    const double duration = 1.5;

    // 1. Sink the creature down off the screen
    add(
      MoveEffect.to(
        // Keep the current X, move to the bottom edge.
        Vector2(position.x, offScreenY),
        EffectController(duration: duration, curve: Curves.easeIn),
      ),
    );

    // 3. Optional: Add a subtle rotation for that satisfying "defeated" tumble
    add(
      RotateEffect.by(
        math.pi / 4, // Rotate by 45 degrees
        EffectController(duration: duration),
      ),
    );

    // 4. Remove the component (and all its children) completely after the animation
    add(RemoveEffect(delay: duration + 0.1));

    // --- END SINKING IMPLEMENTATION ---
  }

  Future<void> playAttackAnimation(BattleMove move, BossSprite target) async {
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

    gameRef.shakeCamera(intensity: 8); // Add camera shake on hit
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
