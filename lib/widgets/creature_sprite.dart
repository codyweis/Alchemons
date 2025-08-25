import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flame/widgets.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

class CreatureSprite extends StatefulWidget {
  final String spritePath;
  final int totalFrames;
  final int rows;
  final Vector2 frameSize;
  final double stepTime;

  // Genetics-based modifiers
  final double scale; // from size genetics (e.g. 0.75, 1.0, 1.3)
  final Color? tint; // from tinting genetics (applied as ColorFilter)
  final double saturation;
  final double brightness;
  final double hueShift; // in degrees, for static hue shifts
  final bool isPrismatic; // for animated rainbow cycling

  const CreatureSprite({
    super.key,
    required this.spritePath,
    required this.totalFrames,
    required this.rows,
    required this.frameSize,
    required this.stepTime,
    this.scale = 1.0,
    this.tint,
    this.saturation = 1.0,
    this.brightness = 1.0,
    this.hueShift = 0.0,
    this.isPrismatic = false,
  });

  @override
  State<CreatureSprite> createState() => _CreatureSpriteState();
}

class _CreatureSpriteState extends State<CreatureSprite>
    with SingleTickerProviderStateMixin {
  AnimationController? _hueController;
  SpriteAnimation? _spriteAnimation;
  SpriteAnimationTicker? _spriteTicker;

  @override
  void initState() {
    super.initState();

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

    // Swap prismatic animation on/off when toggled
    if (widget.isPrismatic != oldWidget.isPrismatic) {
      _hueController?.dispose();
      _hueController = null;
      if (widget.isPrismatic) {
        _hueController = AnimationController(
          duration: const Duration(seconds: 8),
          vsync: this,
        )..repeat();
      }
      setState(() {}); // rebuild to reflect change
    }

    // Reload animation if sprite sheet / frames changed
    final pathChanged = widget.spritePath != oldWidget.spritePath;
    final framesChanged =
        widget.totalFrames != oldWidget.totalFrames ||
        widget.rows != oldWidget.rows ||
        widget.frameSize != oldWidget.frameSize ||
        widget.stepTime != oldWidget.stepTime;

    if (pathChanged || framesChanged) {
      _loadAnimation();
    }
  }

  @override
  void dispose() {
    _hueController?.dispose();
    _spriteTicker = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPrismatic && _hueController != null) {
      return AnimatedBuilder(
        animation: _hueController!,
        builder: (context, child) {
          final currentHue = _hueController!.value * 360;
          return _buildSprite(dynamicHueShift: currentHue);
        },
      );
    }

    return _buildSprite();
  }

  Widget _buildSprite({double dynamicHueShift = 0.0}) {
    if (_spriteAnimation == null) return const _LoadingIndicator();

    final normalizedHue =
        ((widget.hueShift + dynamicHueShift) % 360 + 360) % 360;

    Widget sprite = SpriteAnimationWidget(
      animation: _spriteAnimation!,
      anchor: Anchor.center,
      animationTicker: _spriteTicker!,
    );

    sprite = _applyColorEffects(sprite, normalizedHue);

    return Transform.scale(
      scale: widget.scale,
      child: RepaintBoundary(
        child: SizedBox.square(dimension: 69, child: sprite),
      ),
    );
  }

  Widget _applyColorEffects(Widget sprite, double hueShiftDegrees) {
    Widget result = sprite;

    // Apply brightness and saturation first
    if (widget.saturation != 1.0 || widget.brightness != 1.0) {
      final matrix = _createBrightnessSaturationMatrix(
        widget.brightness,
        widget.saturation,
      );
      result = ColorFiltered(
        colorFilter: ColorFilter.matrix(matrix),
        child: result,
      );
    }

    if (hueShiftDegrees != 0) {
      final hueMatrix = _createHueRotationMatrix(hueShiftDegrees);
      result = ColorFiltered(
        colorFilter: ColorFilter.matrix(hueMatrix),
        child: result,
      );
    }

    // Apply tint if specified
    if (widget.tint != null) {
      result = ColorFiltered(
        colorFilter: ColorFilter.mode(widget.tint!, BlendMode.modulate),
        child: result,
      );
    }

    return result;
  }

  void _loadAnimation() async {
    final image = await Flame.images.load(widget.spritePath);
    final cols = (widget.totalFrames + widget.rows - 1) ~/ widget.rows;

    final animation = SpriteAnimation.fromFrameData(
      image,
      SpriteAnimationData.sequenced(
        amount: widget.totalFrames,
        amountPerRow: cols,
        textureSize: widget.frameSize,
        stepTime: widget.stepTime,
        loop: true,
      ),
    );

    setState(() {
      _spriteAnimation = animation;
      _spriteTicker = animation.createTicker();
    });
  }

  List<double> _createBrightnessSaturationMatrix(
    double brightness,
    double saturation,
  ) {
    final r = brightness;
    final g = brightness;
    final b = brightness;
    final s = saturation;

    return <double>[
      s * r,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      s * g,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      s * b,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ];
  }

  List<double> _createHueRotationMatrix(double degrees) {
    final radians = degrees * (math.pi / 180);
    final cos = math.cos(radians);
    final sin = math.sin(radians);

    return [
      0.213 + cos * 0.787 - sin * 0.213,
      0.715 - cos * 0.715 - sin * 0.715,
      0.072 - cos * 0.072 + sin * 0.928,
      0,
      0,
      0.213 - cos * 0.213 + sin * 0.143,
      0.715 + cos * 0.285 + sin * 0.140,
      0.072 - cos * 0.072 - sin * 0.283,
      0,
      0,
      0.213 - cos * 0.213 - sin * 0.787,
      0.715 - cos * 0.715 + sin * 0.715,
      0.072 + cos * 0.928 + sin * 0.072,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox.square(
        dimension: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

// Helper class to convert genetics JSON to sprite parameters
class GeneticsEffects {
  final double scale;
  final Color? tint;
  final double saturation;
  final double brightness;
  final double hueShift;
  final bool isPrismatic;

  const GeneticsEffects({
    this.scale = 1.0,
    this.tint,
    this.saturation = 1.0,
    this.brightness = 1.0,
    this.hueShift = 0.0,
    this.isPrismatic = false,
  });

  factory GeneticsEffects.fromGenes(Map<String, dynamic> genes) {
    double scale = 1.0;
    if (genes.containsKey('size')) {
      switch (genes['size']) {
        case 'tiny':
          scale = 0.75;
          break;
        case 'small':
          scale = 0.9;
          break;
        case 'large':
          scale = 1.15;
          break;
        case 'giant':
          scale = 1.3;
          break;
        default:
          scale = 1.0;
      }
    }

    double saturation = 1.0;
    double brightness = 1.0;
    double hueShift = 0.0;
    // IMPORTANT: prismatic not handled here anymore
    if (genes.containsKey('tinting')) {
      switch (genes['tinting']) {
        case 'warm':
          hueShift = 15;
          saturation = 1.1;
          brightness = 1.05;
          break;
        case 'cool':
          hueShift = -15;
          saturation = 1.1;
          brightness = 1.05;
          break;
        case 'vibrant':
          saturation = 1.4;
          brightness = 1.1;
          break;
        case 'pale':
          saturation = 0.6;
          brightness = 1.2;
          break;
        // 'normal' or anything else -> defaults
      }
    }

    return GeneticsEffects(
      scale: scale,
      saturation: saturation,
      brightness: brightness,
      hueShift: hueShift,
      isPrismatic: false, // <- always false here
    );
  }
}

// Extension to make it easy to use with your existing creature data
extension CreatureSpriteBuilder on Map<String, dynamic> {
  Widget buildGeneticSprite({
    required String spritePath,
    required int totalFrames,
    required int rows,
    required Vector2 frameSize,
    double stepTime = 0.2,
    bool isPrismatic = false,
  }) {
    final genetics = this['genetics'] as Map<String, dynamic>? ?? {};
    final effects = GeneticsEffects.fromGenes(genetics);

    return CreatureSprite(
      spritePath: spritePath,
      totalFrames: totalFrames,
      rows: rows,
      frameSize: frameSize,
      stepTime: stepTime,
      scale: effects.scale,
      tint: effects.tint,
      saturation: effects.saturation,
      brightness: effects.brightness,
      hueShift: effects.hueShift,
      isPrismatic: isPrismatic,
    );
  }
}
