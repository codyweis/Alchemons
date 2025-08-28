// lib/widgets/creature_sprite.dart
import 'dart:math' as math;

import 'package:flame/components.dart' show Vector2;
import 'package:flame/flame.dart' show Flame;
import 'package:flame/sprite.dart';
import 'package:flame/widgets.dart';
import 'package:flutter/material.dart';

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
  });

  @override
  State<CreatureSprite> createState() => _CreatureSpriteState();
}

class _CreatureSpriteState extends State<CreatureSprite>
    with SingleTickerProviderStateMixin {
  // Helper to detect albino based on brightness value
  bool get _isAlbino => widget.brightness == 1.45;

  AnimationController? _hueController;
  SpriteAnimation? _spriteAnimation;
  SpriteAnimationTicker? _spriteTicker;

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
    _hueController?.dispose();
    _spriteTicker = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_spriteAnimation == null) return const _LoadingIndicator();

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
      anchor: Anchor.center,
      animationTicker: _spriteTicker!,
    );

    // Prismatic trumps albino - only use albino processing if not prismatic
    if (_isAlbino && !widget.isPrismatic) {
      // For albino: apply desaturation matrix to convert to grayscale,
      // then brighten without any hue shifts
      sprite = ColorFiltered(
        colorFilter: ColorFilter.matrix(_albinoMatrix(widget.brightness)),
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
            _brightnessSaturationMatrix(widget.brightness, widget.saturation),
          ),
          child: sprite,
        );
      }

      // then hue rotation
      if (normalizedHue != 0) {
        sprite = ColorFiltered(
          colorFilter: ColorFilter.matrix(_hueRotationMatrix(normalizedHue)),
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

    return Transform.scale(
      scale: widget.scale,
      child: RepaintBoundary(
        child: SizedBox.square(dimension: 69, child: sprite),
      ),
    );
  }

  Future<void> _loadAnimation() async {
    final image = await Flame.images.load(widget.spritePath);

    // columns per row on the sheet
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

    setState(() {
      _spriteAnimation = anim;
      _spriteTicker = anim.createTicker();
    });
  }

  // ── color math helpers ────────────────────────────────────

  List<double> _brightnessSaturationMatrix(
    double brightness,
    double saturation,
  ) {
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

  List<double> _hueRotationMatrix(double degrees) {
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
  List<double> _albinoMatrix(double brightness) {
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
