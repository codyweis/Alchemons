import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class CreatureSpriteComponent extends PositionComponent with HasGameRef {
  final String spritePath;
  final int totalFrames;
  final int rows;
  final Vector2 frameSize; // frame width/height in px
  final double stepTime;

  // Genetics-based modifiers
  final double scaleFactor; // e.g. 0.75, 1.0, 1.3
  final double saturation; // 1.0 = no change
  final double brightness; // 1.0 = no change
  final double baseHueShift; // degrees
  final bool isPrismatic; // animate hue

  late final SpriteAnimationComponent _anim;
  double _prismaticHue = 0.0; // animated degrees

  CreatureSpriteComponent({
    required this.spritePath,
    required this.totalFrames,
    required this.rows,
    required this.frameSize,
    required this.stepTime,
    this.scaleFactor = 1.0,
    this.saturation = 1.0,
    this.brightness = 1.0,
    this.baseHueShift = 0.0,
    this.isPrismatic = false,
    Vector2? desiredSize, // optional, if you want to force a box size
  }) {
    anchor = Anchor.center;
    if (desiredSize != null) size = desiredSize;
    priority = 20;
  }

  @override
  Future<void> onLoad() async {
    try {
      final image = await game.images.load(spritePath);
      final fw = frameSize.x;
      final fh = frameSize.y;

      final cols = (image.width / fw).floor();
      // If caller gave desiredSize, use it; otherwise default to frame size,
      // then apply gene scale.
      final baseBox = (size.x == 0 && size.y == 0) ? Vector2(fw, fh) : size;
      size = baseBox * scaleFactor;

      final data = SpriteAnimationData.sequenced(
        amount: totalFrames,
        amountPerRow: cols,
        textureSize: frameSize,
        stepTime: stepTime,
        loop: true,
      );

      _anim = SpriteAnimationComponent.fromFrameData(image, data)
        ..anchor = Anchor.center
        ..position =
            size /
            2 // ✅ center inside this component
        ..size =
            size // ✅ fill this component’s box
        ..priority = 20;

      _applyColorMatrix();
      add(_anim);
    } catch (e, st) {
      print('[CreatureSpriteComponent] load failed for $spritePath: $e\n$st');
      // draw a visible error box so it’s obvious
      add(
        RectangleComponent(
          size: size == Vector2.zero() ? Vector2(48, 48) : size,
          anchor: Anchor.center,
          position: (size == Vector2.zero() ? Vector2(48, 48) : size) / 2,
          paint: Paint()..color = Colors.orange.withOpacity(0.5),
          priority: 999,
        ),
      );
      add(
        TextComponent(
          text: 'IMG ERR',
          anchor: Anchor.center,
          position: (size == Vector2.zero() ? Vector2(48, 48) : size) / 2,
          priority: 1000,
          textRenderer: TextPaint(
            style: const TextStyle(fontSize: 10, color: Colors.white),
          ),
        ),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isPrismatic) {
      // cycle 360° every ~8s
      _prismaticHue = (_prismaticHue + (360 / 8.0) * dt) % 360.0;
      _applyColorMatrix();
    }
  }

  void _applyColorMatrix() {
    final hue = baseHueShift + _prismaticHue;
    final m = _composeMatrix(
      brightness: brightness,
      saturation: saturation,
      hueDeg: hue,
    );
    _anim.paint = Paint()..colorFilter = ColorFilter.matrix(m);
  }

  // ---------- Color math (combine brightness, saturation, hue) ----------
  List<double> _composeMatrix({
    required double brightness,
    required double saturation,
    required double hueDeg,
  }) {
    final bs = _brightnessSaturationMatrix(brightness, saturation);
    final hue = _hueRotationMatrix(hueDeg);
    return _mul5x4(hue, bs); // hue ∘ (brightness+saturation)
  }

  List<double> _brightnessSaturationMatrix(double b, double s) {
    // Same simple model you used in the widget
    final r = b, g = b, bl = b;
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
      s * bl,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _hueRotationMatrix(double degrees) {
    final rad = degrees * (math.pi / 180.0);
    final c = math.cos(rad);
    final s = math.sin(rad);
    return <double>[
      0.213 + 0.787 * c - 0.213 * s,
      0.715 - 0.715 * c - 0.715 * s,
      0.072 - 0.072 * c + 0.928 * s,
      0,
      0,
      0.213 - 0.213 * c + 0.143 * s,
      0.715 + 0.285 * c + 0.140 * s,
      0.072 - 0.072 * c - 0.283 * s,
      0,
      0,
      0.213 - 0.213 * c - 0.787 * s,
      0.715 - 0.715 * c + 0.715 * s,
      0.072 + 0.928 * c + 0.072 * s,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  // Multiply two 4x5 color matrices (B ∘ A) so we can apply as one filter.
  List<double> _mul5x4(List<double> b, List<double> a) {
    // matrices are 4 rows x 5 cols flattened row-major
    List<double> out = List.filled(20, 0.0);
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 5; c++) {
        double sum = 0;
        for (int k = 0; k < 4; k++) {
          sum += b[r * 5 + k] * a[k * 5 + c];
        }
        if (c == 4) sum += b[r * 5 + 4]; // bias term
        out[r * 5 + c] = sum;
      }
    }
    return out;
  }
}
