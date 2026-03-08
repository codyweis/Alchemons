// lib/widgets/creature_sprite.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/utils/color_util.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/animations/sprite_effects/alchemy_glow.dart';
import 'package:alchemons/widgets/animations/sprite_effects/orbiting_particles.dart';
import 'package:alchemons/widgets/animations/sprite_effects/prismatic_cascade.dart';
import 'package:alchemons/utils/effect_size.dart';
import 'package:alchemons/widgets/animations/sprite_effects/void_rift.dart';
import 'package:alchemons/widgets/animations/sprite_effects/volcanic_aura.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flame/flame.dart' show Flame;
import 'package:flame/sprite.dart';
import 'package:flame/widgets.dart';
import 'package:flutter/material.dart';

class _ErrorIndicator extends StatelessWidget {
  final String error;

  const _ErrorIndicator({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
    );
  }
}

class CreatureSprite extends StatefulWidget {
  final String spritePath;
  final int totalFrames;
  final int rows;
  final Vector2 frameSize;
  final double stepTime;

  // Genetics-based modifiers
  final double scale; // from size genetics (e.g. 0.75, 1.0, 1.3)
  final double saturation; // S
  final double brightness; // V
  final double hueShift; // degrees
  final bool isPrismatic; // animated hue cycle
  final Color? tint; // optional extra tint (usually null)

  // New: Alchemy effect
  final String? alchemyEffect;

  // New: Variant faction
  final String? variantFaction;

  const CreatureSprite({
    super.key,
    required this.spritePath,
    required this.totalFrames,
    required this.rows,
    required this.frameSize,
    required this.stepTime,
    this.scale = 1.0,
    this.saturation = 1.0,
    this.brightness = 1.0,
    this.hueShift = 0.0,
    this.isPrismatic = false,
    this.tint,
    this.alchemyEffect,
    this.variantFaction,
  });

  @override
  State<CreatureSprite> createState() => _CreatureSpriteState();
}

class _CreatureSpriteState extends State<CreatureSprite>
    with TickerProviderStateMixin {
  // Helper to detect albino based on brightness value
  bool get _isAlbino => widget.brightness == 1.45;

  AnimationController? _hueController;
  SpriteAnimation? _spriteAnimation;
  SpriteAnimationTicker? _spriteTicker;

  String? _loadError;
  Timer? _retryTimer;
  int _retryCount = 0;
  static const int _maxLoadRetries = 2;

  @override
  void initState() {
    super.initState();
    // Start prismatic animation if enabled (prismatic trumps albino)
    if (widget.isPrismatic) {
      _hueController = AnimationController(
        duration: const Duration(seconds: 8),
        vsync: this,
      )..repeat();
    }
    _loadAnimation();
  }

  @override
  void didUpdateWidget(covariant CreatureSprite oldWidget) {
    super.didUpdateWidget(oldWidget);

    // toggle prismatic hue cycling (prismatic trumps albino)
    if (widget.isPrismatic != oldWidget.isPrismatic) {
      _hueController?.dispose();
      _hueController = null;
      if (widget.isPrismatic) {
        _hueController = AnimationController(
          duration: const Duration(seconds: 8),
          vsync: this,
        )..repeat();
      }
      setState(() {});
    }

    // reload animation if sprite config changed
    final baseChanged =
        widget.spritePath != oldWidget.spritePath ||
        widget.totalFrames != oldWidget.totalFrames ||
        widget.rows != oldWidget.rows ||
        widget.frameSize != oldWidget.frameSize ||
        widget.stepTime != oldWidget.stepTime;

    if (baseChanged) _loadAnimation();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _hueController?.dispose();
    _spriteTicker = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Error state
    if (_loadError != null) {
      return _ErrorIndicator(error: _loadError!);
    }

    // Loading state
    if (_spriteAnimation == null) {
      return Icon(Icons.science, size: 50);
    }

    // Prismatic trumps everything - even albino
    if (widget.isPrismatic && _hueController != null) {
      return AnimatedBuilder(
        animation: _hueController!,
        builder: (_, __) {
          final currentHue = (_hueController!.value * 360.0);
          return _buildSprite(dynamicHueShift: currentHue);
        },
      );
    }

    return _buildSprite();
  }

  Widget _buildSprite({double dynamicHueShift = 0.0}) {
    Widget sprite = SpriteAnimationWidget(
      animation: _spriteAnimation!,
      anchor: Anchor.topLeft,
      animationTicker: _spriteTicker!,
    );

    // Prismatic trumps albino - only use albino processing if not prismatic
    if (_isAlbino && !widget.isPrismatic) {
      // For albino: apply desaturation matrix to convert to grayscale,
      // then brighten without any hue shifts
      sprite = ColorFiltered(
        colorFilter: ColorFilter.matrix(albinoMatrix(widget.brightness)),
        child: sprite,
      );
    } else {
      // Normal color processing for non-albino creatures or prismatic creatures
      final normalizedHue =
          ((widget.hueShift + dynamicHueShift) % 360 + 360) % 360;

      // apply S, V first
      if (widget.saturation != 1.0 || widget.brightness != 1.0) {
        sprite = ColorFiltered(
          colorFilter: ColorFilter.matrix(
            brightnessSaturationMatrix(widget.brightness, widget.saturation),
          ),
          child: sprite,
        );
      }

      // then hue rotation
      if (normalizedHue != 0) {
        sprite = ColorFiltered(
          colorFilter: ColorFilter.matrix(hueRotationMatrix(normalizedHue)),
          child: sprite,
        );
      }
    }

    // optional overall tint (rarely needed, skip for non-prismatic albino)
    if (widget.tint != null && !(_isAlbino && !widget.isPrismatic)) {
      sprite = ColorFiltered(
        colorFilter: ColorFilter.mode(widget.tint!, BlendMode.modulate),
        child: sprite,
      );
    }

    final scaled = Transform.scale(
      scale: widget.scale,
      child: RepaintBoundary(
        child: SizedBox.square(dimension: 69, child: sprite),
      ),
    );

    // If an alchemy/visual effect is present, render the effect layer behind
    // the sprite (match the behavior used by `InstanceSprite`).
    if (widget.alchemyEffect != null) {
      return Stack(
        alignment: Alignment.center,
        children: [
          // effect may overflow bounds intentionally
          _buildEffectLayer(widget.alchemyEffect!),
          Padding(padding: const EdgeInsets.all(8.0), child: scaled),
        ],
      );
    }

    return scaled;
  }

  Widget _buildEffectLayer(String effect) {
    // Use the canonical display base (69px box * genetics scale) for sizing.
    final displayBase = displayBaseFromVisuals(visualsScale: widget.scale);
    switch (effect) {
      case 'alchemy_glow':
        return AlchemyGlow(size: displayBase);
      case 'elemental_aura':
        return ElementalAura(size: displayBase, element: widget.variantFaction);
      case 'volcanic_aura':
        return VolcanicAura(size: displayBase);
      case 'void_rift':
        return VoidRift(size: displayBase * 0.8);
      case 'prismatic_cascade':
        final eff = effectSizeFromDisplayBase(displayBase);
        return PrismaticCascade(size: eff);
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _loadAnimation() async {
    try {
      final images = Flame.images;

      // If the image is already cached, do everything synchronously
      if (images.containsKey(widget.spritePath)) {
        final image = images.fromCache(widget.spritePath);

        final cols = (widget.totalFrames + widget.rows - 1) ~/ widget.rows;

        final anim = SpriteAnimation.fromFrameData(
          image,
          SpriteAnimationData.sequenced(
            amount: widget.totalFrames,
            amountPerRow: cols,
            textureSize: widget.frameSize,
            stepTime: widget.stepTime,
            loop: true,
          ),
        );

        // Synchronous path: set state immediately if we're mounted
        if (mounted) {
          setState(() {
            _spriteAnimation = anim;
            _spriteTicker = anim.createTicker();
            _loadError = null;
            _retryCount = 0;
          });
        }
        return;
      }

      // Otherwise, fall back to async loading
      final image = await images.load(widget.spritePath);

      final cols = (widget.totalFrames + widget.rows - 1) ~/ widget.rows;

      final anim = SpriteAnimation.fromFrameData(
        image,
        SpriteAnimationData.sequenced(
          amount: widget.totalFrames,
          amountPerRow: cols,
          textureSize: widget.frameSize,
          stepTime: widget.stepTime,
          loop: true,
        ),
      );

      if (!mounted) return;
      setState(() {
        _spriteAnimation = anim;
        _spriteTicker = anim.createTicker();
        _loadError = null;
        _retryCount = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
      });

      if (_retryCount < _maxLoadRetries) {
        _retryCount += 1;
        _retryTimer?.cancel();
        _retryTimer = Timer(Duration(milliseconds: 180 * _retryCount), () {
          if (!mounted) return;
          setState(() {
            _loadError = null;
          });
          _loadAnimation();
        });
      }
    }
  }
}

class InstanceSprite extends StatelessWidget {
  final Creature creature;
  final CreatureInstance instance;
  final double size;
  final bool flipX;

  const InstanceSprite({
    super.key,
    required this.creature,
    required this.instance,
    required this.size,
    this.flipX = false,
  });

  @override
  Widget build(BuildContext context) {
    final sheet = sheetFromCreature(creature);
    final visuals = visualsFromInstance(creature, instance);

    Widget sprite = SizedBox(
      width: size,
      height: size,
      child: CreatureSprite(
        spritePath: sheet.path,
        totalFrames: sheet.totalFrames,
        rows: sheet.rows,
        frameSize: sheet.frameSize,
        stepTime: sheet.stepTime,
        scale: visuals.scale,
        saturation: visuals.saturation,
        brightness: visuals.brightness,
        hueShift: visuals.hueShiftDeg,
        isPrismatic: visuals.isPrismatic,
        tint: visuals.tint,
      ),
    );

    if (instance.alchemyEffect != null) {
      // Use a simple Stack. The effect layer and the padded sprite are centered.
      sprite = Stack(
        alignment: Alignment.center,
        children: [
          // Background glow/particles - this child will overflow its bounds
          _buildEffectLayer(instance.alchemyEffect!, visuals),
          // Creature sprite on top (keep the padding to ensure the sprite
          // image itself isn't pushed to the edge and clipped by its own BoxShadow)
          Padding(
            padding: const EdgeInsets.all(
              8.0,
            ), // Keep this for internal glow space
            child: sprite,
          ),
        ],
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: OverflowBox(
        minWidth: 0.0,
        maxWidth: double.infinity,
        minHeight: 0.0,
        maxHeight: double.infinity,
        alignment: Alignment.center,
        child: flipX
            ? Transform(
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(-1, 1, 1),
                child: sprite,
              )
            : sprite,
      ),
    );
  }

  Widget _buildEffectLayer(String effect, SpriteVisuals visuals) {
    // For InstanceSprite (small UI slot), derive effect sizes from the
    // widget slot `size` rather than the canonical 69px display base so
    // previews remain visually balanced.
    final widgetEff = effectSizeFromWidgetSize(size);
    switch (effect) {
      case 'alchemy_glow':
        return AlchemyGlow(size: widgetEff);
      case 'elemental_aura':
        return ElementalAura(size: widgetEff, element: instance.variantFaction);
      case 'volcanic_aura':
        return VolcanicAura(size: widgetEff);
      case 'void_rift':
        return VoidRift(size: widgetEff * 0.8);
      case 'prismatic_cascade':
        return PrismaticCascade(size: widgetEff);
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Pulls a faction name from instance lineage data (variant → native → dominant),
/// returns a soft tint color for the sprite.
Color? deriveLineageTint(CreatureInstance? inst) {
  if (inst == null) return null;
  // 1) Try explicit variant/native faction fields if present
  final variantFaction = _tryGetString(inst, 'variantFaction'); // e.g. "Pyro"

  String? chosen = variantFaction?.isNotEmpty == true ? variantFaction : null;
  if (chosen == null) return null;

  // 3) Map faction → color using your palette (use your real helper here)
  // If you already have getFactionColors(FactionId), replace this with that.
  final base = FactionColors.of(chosen); // e.g., Color(0xFF60A5FA) for Aqua
  // 4) soften so it doesn’t overtake the sprite
  return base;
}

/// Safe JSON string getter from the drift data class.
String? _tryGetString(CreatureInstance inst, String field) {
  try {
    final j = inst.toJson();
    final v = j[field];
    return v is String ? v : null;
  } catch (_) {
    return null;
  }
}

// ── color math helpers ────────────────────────────────────

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

// Albino matrix that desaturates to grayscale and applies brightness
List<double> albinoMatrix(double brightness) {
  // Luminance coefficients for RGB -> grayscale conversion
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
