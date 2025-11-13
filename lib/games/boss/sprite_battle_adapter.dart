// lib/game/creature_battle_sprite_adapter.dart
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
import 'package:flutter/material.dart';

/// Enhanced CreatureBattleSprite that uses your actual CreatureSpriteComponent
/// Replace the placeholder CircleComponent in battle_game.dart with this
class CreatureBattleSpriteWithVisuals extends PositionComponent
    with HasGameRef<BattleGame>, TapCallbacks {
  final BattleCombatant combatant;
  final int index;
  final SpriteSheetDef sheet;
  final SpriteVisuals visuals;

  late PositionComponent statusIconContainer;
  late CircleComponent selectionIndicator;

  // The actual creature sprite component
  late CreatureSpriteComponentBattle creatureVisual;

  CreatureBattleSpriteWithVisuals({
    required this.combatant,
    required Vector2 position,
    required this.index,
    required this.sheet,
    required this.visuals,
  }) : super(position: position, size: Vector2(100, 120));

  @override
  Future<void> onLoad() async {
    // Add the actual creature sprite using your color filter system
    creatureVisual = CreatureSpriteComponentBattle(
      sheet: sheet,
      visuals: visuals,
      desiredSize: Vector2(80, 80), // Size for battle display
    );
    creatureVisual.position = Vector2(0, -10);
    creatureVisual.anchor = Anchor.center;
    add(creatureVisual);

    // Selection indicator (behind creature)
    selectionIndicator = CircleComponent(
      radius: 48,
      paint: Paint()
        ..color = Colors.yellow.withOpacity(0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
      anchor: Anchor.center,
      position: Vector2(0, -10),
    );
    add(selectionIndicator..priority = -1);

    // Status icon container - above the creature visual
    statusIconContainer = PositionComponent(position: Vector2(0, -60));
    add(statusIconContainer);
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
    // Fade out the main visual component and then remove self from the game
    creatureVisual.add(
      OpacityEffect.fadeOut(
        EffectController(duration: 0.5, curve: Curves.easeIn),
        onComplete: () => removeFromParent(),
      ),
    );
    // Also fade out all the UI elements (status icons)
    add(
      OpacityEffect.fadeOut(
        EffectController(duration: 0.5, curve: Curves.easeIn),
      ),
    );
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
        ? Colors.yellow.withOpacity(0.8)
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

    await gameRef.images.load(sheet.path);

    final image = game.images.fromCache(sheet.path);
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

// Color matrix functions
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
