// lib/games/survival/components/alchemy_orb.dart
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart'; // Needed for Pulse/Shake effects
import 'package:flutter/material.dart';

class AlchemyOrb extends PositionComponent {
  final double maxHp;
  double currentHp;

  late CircleComponent _core;
  late CircleComponent _glow;
  late RectangleComponent _hpBarFill;

  AlchemyOrb({required this.maxHp})
    : currentHp = maxHp,
      super(size: Vector2.all(120), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    // 1. Outer Mystical Glow (Deep Indigo/Purple to match the rune)
    _glow = CircleComponent(
      radius: 65,
      paint: Paint()
        ..color = Colors.indigoAccent.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25),
      anchor: Anchor.center,
      position: size / 2,
    );
    add(_glow);

    // 2. The Core (Bright Energy)
    _core = CircleComponent(
      radius: 35,
      paint: Paint()
        ..color = Colors.cyanAccent
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.solid,
          5,
        ), // Slight bloom
      anchor: Anchor.center,
      position: size / 2,
    );
    add(_core);

    // 3. "Breathing" Animation (Idle Pulse)
    // Makes the orb look like it's containing unstable power
    add(
      ScaleEffect.by(
        Vector2.all(1.05),
        EffectController(
          duration: 1.5,
          reverseDuration: 1.5,
          infinite: true,
          curve: Curves.easeInOut,
        ),
      ),
    );

    // 4. HP Bar (Essential for survival mode)
    _buildHpBar();
  }

  void _buildHpBar() {
    // Background (Dark)
    final barBg = RectangleComponent(
      size: Vector2(80, 8),
      paint: Paint()..color = Colors.black.withOpacity(0.6),
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y + 15),
    );

    // Fill (Green/Cyan)
    _hpBarFill = RectangleComponent(
      size: Vector2(76, 4), // Slightly smaller than BG
      paint: Paint()..color = Colors.cyanAccent,
      anchor: Anchor.centerLeft,
      position: Vector2(2, 4), // Relative to BG
    );

    barBg.add(_hpBarFill);
    add(barBg);
  }

  void takeDamage(int amount) {
    if (currentHp <= 0) return;

    currentHp -= amount;
    _updateHpBar();

    // Visual: Flash Red
    _core.add(
      ColorEffect(
        Colors.redAccent,
        EffectController(duration: 0.1, reverseDuration: 0.1),
      ),
    );

    // Visual: Shake Effect (Impact)
    add(
      MoveEffect.by(
        Vector2(2, 0),
        EffectController(
          duration: 0.05,
          reverseDuration: 0.05,
          repeatCount: 3, // Shake 3 times
        ),
      ),
    );
  }

  void heal(int amount) {
    if (currentHp >= maxHp || currentHp <= 0) return;

    currentHp = (currentHp + amount).clamp(0, maxHp).toDouble();
    _updateHpBar();

    // Visual: Flash Gold/White
    _core.add(
      ColorEffect(
        Colors.amberAccent, // Gold for "Divine/Alchemy" repair
        EffectController(duration: 0.2, reverseDuration: 0.2),
      ),
    );

    // Visual: Slight Grow to show restoration
    _core.add(
      ScaleEffect.by(
        Vector2.all(1.2),
        EffectController(duration: 0.1, reverseDuration: 0.1),
      ),
    );
  }

  void _updateHpBar() {
    final percent = (currentHp / maxHp).clamp(0.0, 1.0);
    _hpBarFill.scale.x = percent;

    // Change color based on health
    if (percent > 0.5) {
      _hpBarFill.paint.color = Colors.cyanAccent;
    } else if (percent > 0.25) {
      _hpBarFill.paint.color = Colors.orangeAccent;
    } else {
      _hpBarFill.paint.color = Colors.redAccent;
    }
  }

  bool get isDestroyed => currentHp <= 0;
}
