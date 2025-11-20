import 'dart:ui';
import 'dart:math' as math;

import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';

class CreatureSpriteComponent<G extends FlameGame> extends PositionComponent
    with HasGameRef<G> {
  final SpriteSheetDef sheet;
  final SpriteVisuals visuals;
  final Vector2 desiredSize;

  late final SpriteAnimationComponent _anim;
  double _prismaticHue = 0; // degrees

  CreatureSpriteComponent({
    required this.sheet,
    required this.visuals,
    required this.desiredSize,
  });

  @override
  Future<void> onLoad() async {
    size = desiredSize;

    final image = game.images.fromCache(sheet.path); // or gameRef.images
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
      // Albino: grayscale + brightness
      paint.colorFilter = ColorFilter.matrix(albinoMatrix(visuals.brightness));
    } else {
      // Normal: compute the combined matrix
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

    // Apply tint if present (excluding albino cases)
    if (visuals.tint != null && !(visuals.isAlbino && !visuals.isPrismatic)) {
      // Since we can't easily stack filters in Flame, we'll apply tint via color
      final currentColor = paint.color;
      paint.color = Color.alphaBlend(
        visuals.tint!.withOpacity(0.3), // adjust opacity as needed
        currentColor,
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (visuals.isPrismatic) {
      _prismaticHue = (_prismaticHue + 360 * dt / 8.0) % 360;
      _applyColorFilters(); // Re-apply with updated hue
    }
  }

  // Combine brightness, saturation, and hue into one matrix
  List<double> _combinedColorMatrix({
    required double brightness,
    required double saturation,
    required double hueShift,
  }) {
    // First apply brightness and saturation
    final bsMat = brightnessSaturationMatrix(brightness, saturation);

    // If no hue shift, return as-is
    if (hueShift == 0) return bsMat;

    // Otherwise multiply with hue rotation
    final hueMat = hueRotationMatrix(hueShift);
    return _multiplyMatrices(bsMat, hueMat);
  }

  // Proper 4x5 color matrix multiplication
  List<double> _multiplyMatrices(List<double> a, List<double> b) {
    final result = List<double>.filled(20, 0);

    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 5; col++) {
        if (col == 4) {
          // Translation column
          result[row * 5 + 4] = a[row * 5 + 4] + b[row * 5 + 4];
        } else {
          // Regular matrix multiply for 4x4 part
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

// Copy these from creature_sprite.dart if not already accessible
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
