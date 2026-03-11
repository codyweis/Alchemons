import 'dart:ui';
import 'dart:math' as math;

import 'package:alchemons/games/sprite_effects/sprite_beauty_radiance_component.dart';
import 'package:alchemons/games/sprite_effects/sprite_elemental_aura_component.dart';
import 'package:alchemons/games/sprite_effects/sprite_glow_component.dart';
import 'package:alchemons/games/sprite_effects/sprite_intelligence_halo_component.dart';
import 'package:alchemons/games/sprite_effects/sprite_prismatic_cascade_component.dart';
import 'package:alchemons/games/sprite_effects/sprite_speed_flux_component.dart';
import 'package:alchemons/games/sprite_effects/sprite_strength_forge_component.dart';
import 'package:alchemons/games/sprite_effects/sprite_void_rift_component.dart';
import 'package:alchemons/games/sprite_effects/sprite_volcanic_aura.dart';
import 'package:alchemons/utils/color_util.dart';
import 'package:alchemons/utils/effect_size.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';

class CreatureSpriteComponent<G extends FlameGame> extends PositionComponent
    with HasGameReference<G> {
  final SpriteSheetDef sheet;
  final SpriteVisuals visuals;
  final Vector2 desiredSize;
  final String? alchemyEffect;
  final String? variantFaction;
  final double effectScale;

  late final SpriteAnimationComponent _anim;
  double _prismaticHue = 0;

  bool get _isAlbino => visuals.brightness == 1.45;

  CreatureSpriteComponent({
    required this.sheet,
    required this.visuals,
    required this.desiredSize,
    this.alchemyEffect,
    this.variantFaction,
    this.effectScale = 1.0,
  });

  @override
  Future<void> onLoad() async {
    size = desiredSize;

    // Effect layer FIRST so it renders behind the sprite
    if (alchemyEffect != null) {
      final effectComponent = _buildEffectComponent(alchemyEffect!);
      if (effectComponent != null) {
        effectComponent.position = size / 2;
        effectComponent.priority = -1; // Behind sprite
        add(effectComponent);
      }
    }

    Image image;
    try {
      image = await game.images.load(sheet.path);
    } catch (e) {
      image = await _loadFallbackImage();
    }

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
            priority: 0, // Sprite on top
          )
          ..paint.filterQuality = FilterQuality.high
          ..scale = Vector2.all(finalScale);

    _applyColorFilters();
    add(_anim);
  }

  Future<Image> _loadFallbackImage() async {
    // Fallback logic: load a default image or handle the error gracefully
    // For now, just load a placeholder image
    return await game.images.load('backgrounds/scenes/swamp/sky.png');
  }

  PositionComponent? _buildEffectComponent(String effect) {
    final displayBase = displayBaseFromVisuals(
      baseBox: desiredSize.x,
      visualsScale: visuals.scale,
    );
    final baseSize = effectSizeFromDisplayBase(
      displayBase,
      multiplier: effectScale,
      minSize: 28.0,
      maxSize: 132.0,
    );
    final prismaticSize = prismaticCascadeSizeFromDisplayBase(displayBase);

    switch (effect) {
      case 'alchemy_glow':
        return AlchemyGlowComponent(baseSize: baseSize);
      case 'elemental_aura':
        return ElementalAuraComponent(
          baseSize: baseSize,
          element: variantFaction,
        );
      case 'volcanic_aura':
        return VolcanicAuraComponent(baseSize: baseSize);
      case 'void_rift':
        return VoidRiftComponent(baseSize: baseSize * 0.8);
      case 'prismatic_cascade':
        return PrismaticCascadeComponent(
          baseSize: prismaticSize.clamp(30.0, 128.0),
        );
      case 'beauty_radiance':
        return BeautyRadianceComponent(baseSize: baseSize);
      case 'speed_flux':
        return SpeedFluxComponent(baseSize: baseSize);
      case 'strength_forge':
        return StrengthForgeComponent(baseSize: baseSize);
      case 'intelligence_halo':
        return IntelligenceHaloComponent(baseSize: baseSize);
      default:
        return null;
    }
  }

  double _fitScale(Vector2 frame, Vector2 box) {
    final sx = box.x / frame.x;
    final sy = box.y / frame.y;
    return sx < sy ? sx : sy;
  }

  /// Apply all color effects (SV, hue, tint, albino) as a single color matrix.
  void _applyColorFilters() {
    final paint = _anim.paint;

    // Albino (non-prismatic) matches widget: grayscale + brightness
    if (_isAlbino && !visuals.isPrismatic) {
      paint.colorFilter = ColorFilter.matrix(albinoMatrix(visuals.brightness));
      paint.color = const Color(0xFFFFFFFF);
      return;
    }

    // Start from identity
    List<double> m = _identityMatrix();

    // 1) Brightness / saturation
    if (visuals.saturation != 1.0 || visuals.brightness != 1.0) {
      final sv = brightnessSaturationMatrix(
        visuals.brightness,
        visuals.saturation,
      );
      // Apply SV first
      m = _multiplyColorMatrices(sv, m);
    }

    // 2) Hue rotation (or prismatic)
    final currentHue = visuals.isPrismatic
        ? (visuals.hueShiftDeg + _prismaticHue)
        : visuals.hueShiftDeg;

    final normalizedHue = ((currentHue % 360) + 360) % 360;

    if (normalizedHue != 0) {
      final hue = hueRotationMatrix(normalizedHue);
      // Hue after SV
      m = _multiplyColorMatrices(hue, m);
    }

    // 3) Variant tint — equivalent to ColorFiltered.mode(tint, BlendMode.modulate)
    final tintColor = visuals.tint ?? _deriveVariantTint();

    if (tintColor != null && !(_isAlbino && !visuals.isPrismatic)) {
      final tr = tintColor.r;
      final tg = tintColor.g;
      final tb = tintColor.b;

      // Modulate RGB channels by tint; keep alpha.
      final tintMatrix = <double>[
        tr,
        0,
        0,
        0,
        0,
        0,
        tg,
        0,
        0,
        0,
        0,
        0,
        tb,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ];

      // Tint after hue + SV
      m = _multiplyColorMatrices(tintMatrix, m);
    }

    paint.colorFilter = ColorFilter.matrix(m);
    // Keep base color neutral so matrix does all the work
    paint.color = const Color(0xFFFFFFFF);
  }

  /// Derives tint color from variantFaction (matches deriveLineageTint logic).
  Color? _deriveVariantTint() {
    if (variantFaction == null || variantFaction!.isEmpty) return null;
    return FactionColors.of(variantFaction!);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (visuals.isPrismatic) {
      _prismaticHue = (_prismaticHue + 360 * dt / 8.0) % 360;
      _applyColorFilters();
    }
  }

  // ── color matrix helpers ─────────────────────────────────────

  List<double> _identityMatrix() {
    // 4x5 identity color matrix: leaves color unchanged.
    return <double>[
      1, 0, 0, 0, 0, // R'
      0, 1, 0, 0, 0, // G'
      0, 0, 1, 0, 0, // B'
      0, 0, 0, 1, 0, // A'
    ];
  }

  /// Matrix multiplication for 4x5 color matrices:
  /// result = a ∘ b (apply b first, then a).
  List<double> _multiplyColorMatrices(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0.0);

    for (int row = 0; row < 4; row++) {
      // RGB/A columns
      for (int col = 0; col < 4; col++) {
        double sum = 0.0;
        for (int k = 0; k < 4; k++) {
          sum += a[row * 5 + k] * b[k * 5 + col];
        }
        out[row * 5 + col] = sum;
      }

      // Translation column (index 4)
      double t = a[row * 5 + 4];
      for (int k = 0; k < 4; k++) {
        t += a[row * 5 + k] * b[k * 5 + 4];
      }
      out[row * 5 + 4] = t;
    }

    return out;
  }
}

// ── color math functions (same as widget version) ─────────────

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
