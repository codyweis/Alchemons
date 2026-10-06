// lib/widgets/creature_sprite.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/celebration_costume.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/utils/color_util.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/fx/alchemy_effects/alchemy_effect_paint.dart';
import 'package:alchemons/widgets/fx/alchemy_effects/alchemy_effect_view.dart';
import 'package:alchemons/widgets/fx/costume_paint.dart';
import 'package:alchemons/widgets/fx/mutation_sheets.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flame/flame.dart' show Flame;
import 'package:flame/sprite.dart';
import 'package:flame/widgets.dart';
import 'package:flutter/material.dart';

class _SpriteLoadingIndicator extends StatelessWidget {
  const _SpriteLoadingIndicator();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = colors.primary;

    return Center(
      child: SizedBox.square(
        dimension: 38,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.07),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.12),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            SizedBox.square(
              dimension: 34,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: accent.withValues(alpha: 0.72),
                backgroundColor: accent.withValues(alpha: 0.10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sent up the tree once a [CreatureSprite] has loaded and drawn its first
/// frame — so something wrapping it (the elemental essence's reveal) can read
/// what it shows, rather than the loading spinner.
class SpriteReadyNotification extends Notification {
  const SpriteReadyNotification();
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

  /// The creature's own first type, for the Elemental Aura when it has no
  /// off-faction pigment.
  final String? elementType;
  // Optional: UI slot size to normalize effect rendering in compact contexts
  // (e.g. party pickers) so effects don't overpower the sprite.
  final double? effectSlotSize;

  /// A wild-fusion mutation id, or null: draws the baked sheet instead
  /// ([mutatedSheet]). Pass the rest of the visuals as usual — a Transmuted
  /// creature's come from [visualsFromInstance] already untinted.
  final String? mutation;

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
    this.elementType,
    this.effectSlotSize,
    this.mutation,
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
        widget.mutation != oldWidget.mutation ||
        (widget.mutation != null &&
            widget.isPrismatic != oldWidget.isPrismatic) ||
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
      return const _SpriteLoadingIndicator();
    }

    // Loading state
    if (_spriteAnimation == null) {
      return const _SpriteLoadingIndicator();
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

    final effectiveTint = widget.tint ?? _deriveVariantTint();

    // optional overall tint (rarely needed, skip for non-prismatic albino)
    if (effectiveTint != null && !(_isAlbino && !widget.isPrismatic)) {
      sprite = ColorFiltered(
        colorFilter: ColorFilter.mode(effectiveTint, BlendMode.modulate),
        child: sprite,
      );
    }

    // A worn costume is part of the sprite: over its frame, at that frame's
    // fit, and clear of its colouring.
    final costume = widget.alchemyEffect;
    if (FamilyCostume.isEffect(costume)) {
      sprite = WornCostume(
        effect: costume!,
        frameSize: Size(widget.frameSize.x, widget.frameSize.y),
        frameIndex: () => _spriteTicker?.currentIndex ?? 0,
        child: sprite,
      );
    }

    final scaled = Transform.scale(
      scale: widget.scale,
      child: RepaintBoundary(
        child: SizedBox.square(dimension: 69, child: sprite),
      ),
    );

    // An alchemy effect wraps the sprite: behind it and, for an effect with a
    // near side, over it.
    if (AlchemyEffectPaint.has(widget.alchemyEffect)) {
      final effectPadding = widget.effectSlotSize != null
          ? (widget.effectSlotSize! <= 56 ? 2.0 : 6.0)
          : 8.0;
      // Round the sprite's own box; it paints past the box but never sizes
      // it.
      return AlchemyEffectView(
        effectKey: widget.alchemyEffect!,
        element: widget.variantFaction ?? widget.elementType,
        scale: widget.scale,
        inset: effectPadding,
        child: Padding(padding: EdgeInsets.all(effectPadding), child: scaled),
      );
    }

    return scaled;
  }

  Color? _deriveVariantTint() {
    final faction = widget.variantFaction?.trim();
    if (faction == null || faction.isEmpty) return null;
    if (faction.toLowerCase() == 'bloodborn') return null;
    return FactionColors.of(faction);
  }

  /// After the frame that first draws the loaded sprite.
  void _announceReady() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) const SpriteReadyNotification().dispatch(context);
    });
  }

  /// The sheet actually drawn: the asset, or its baked mutation.
  SpriteSheetDef get _sheet => mutatedSheet(
    SpriteSheetDef(
      path: widget.spritePath,
      totalFrames: widget.totalFrames,
      rows: widget.rows,
      frameSize: widget.frameSize,
      stepTime: widget.stepTime,
    ),
    mutation: widget.mutation,
    prismatic: widget.isPrismatic,
  );

  Future<void> _loadAnimation() async {
    try {
      final images = Flame.images;
      final sheet = _sheet;

      // If the image is already cached, do everything synchronously
      if (images.containsKey(sheet.path)) {
        final image = images.fromCache(sheet.path);

        final cols = (widget.totalFrames + widget.rows - 1) ~/ widget.rows;

        final anim = SpriteAnimation.fromFrameData(
          image,
          SpriteAnimationData.sequenced(
            amount: widget.totalFrames,
            amountPerRow: cols,
            textureSize: sheet.frameSize,
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
          _announceReady();
        }
        return;
      }

      // Otherwise, fall back to async loading
      final image = await loadCreatureSheet(images, sheet.path);

      final cols = (widget.totalFrames + widget.rows - 1) ~/ widget.rows;

      final anim = SpriteAnimation.fromFrameData(
        image,
        SpriteAnimationData.sequenced(
          amount: widget.totalFrames,
          amountPerRow: cols,
          textureSize: sheet.frameSize,
          stepTime: widget.stepTime,
          loop: true,
        ),
      );

      // A slow bake can land after the widget moved on to another sheet.
      if (!mounted || _sheet.path != sheet.path) return;
      setState(() {
        _spriteAnimation = anim;
        _spriteTicker = anim.createTicker();
        _loadError = null;
        _retryCount = 0;
      });
      _announceReady();
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
        mutation: visuals.mutation,
        // A costume is drawn by the sprite itself; an effect, round it below.
        alchemyEffect: FamilyCostume.isEffect(instance.alchemyEffect)
            ? instance.alchemyEffect
            : null,
      ),
    );

    // Blur-free on one shared clock, so even a scrolling grid of them is
    // cheap: every list shows its specimens' effects.
    if (AlchemyEffectPaint.has(instance.alchemyEffect)) {
      // Keep the padding so the sprite is not pushed to the edge of its box.
      sprite = AlchemyEffectView(
        effectKey: instance.alchemyEffect!,
        element: visuals.auraElement,
        scale: visuals.scale,
        inset: 8,
        child: Padding(padding: const EdgeInsets.all(8.0), child: sprite),
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
}

/// Pulls a faction name from instance lineage data (variant → native → dominant),
/// returns a soft tint color for the sprite.
Color? deriveLineageTint(CreatureInstance? inst) {
  if (inst == null) return null;
  // 1) Try explicit variant/native faction fields if present
  final variantFaction = _tryGetString(inst, 'variantFaction'); // e.g. "Pyro"
  if ((variantFaction ?? '').trim().toLowerCase() == 'bloodborn') return null;

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
