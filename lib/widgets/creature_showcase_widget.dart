import 'package:alchemons/audio/audio.dart';
import 'dart:math' as math;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fast_long_press_detector.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:flutter/material.dart';

class FeaturedCreaturePresentation extends StatelessWidget {
  final AnimationController breathing;
  final FactionTheme theme;

  // Creature label
  final String displayName;
  final String subtitle; // e.g. "Specimen #12" or element/faction
  final CreatureInstance instance;
  final Creature creature;

  /// Set when it has just been chosen: it gathers out of its element.
  final EssenceReveal? reveal;

  /// Round the sprite alone (not its glow), for reading it into grains.
  final GlobalKey? spriteKey;
  const FeaturedCreaturePresentation({
    super.key,
    required this.breathing,
    required this.theme,
    required this.displayName,
    required this.subtitle,
    required this.instance,
    required this.creature,
    this.reveal,
    this.spriteKey,
  });

  @override
  Widget build(BuildContext context) {
    Widget sprite = InstanceSprite(
      creature: creature,
      instance: instance,
      size: 72,
    );
    final key = spriteKey;
    if (key != null) {
      // Read with room round it, as the essence reads it: the size gene can
      // draw it a little past its box.
      sprite = OverflowBox(
        maxWidth: 72 * 1.4,
        maxHeight: 72 * 1.4,
        child: RepaintBoundary(
          key: key,
          child: SizedBox.square(
            dimension: 72 * 1.4,
            child: Center(child: SizedBox.square(dimension: 72, child: sprite)),
          ),
        ),
      );
    }
    return IgnorePointer(
      ignoring: true, // decorative only
      child: AnimatedBuilder(
        animation: breathing,
        builder: (context, _) {
          // gentle hover tied to breathing phase
          final floatY = -6 * math.sin(breathing.value * math.pi);

          return Transform.translate(
            offset: Offset(0, floatY),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // The glow behind it, in its own layer: the float moves the
                // layer, it never repaints the glow.
                RepaintBoundary(
                  child: CustomPaint(
                    size: const Size.square(220),
                    painter: _HaloPainter(
                      core: theme.primary,
                      rim: theme.accent,
                    ),
                  ),
                ),

                // the animated sprite
                Transform.scale(
                  scale: 2.5,
                  child: SizedBox.square(
                    dimension: 72,
                    child: ElementalEssence(
                      key: ValueKey(instance.instanceId),
                      element: creature.types.isEmpty
                          ? null
                          : creature.types.first,
                      dark: theme.isDark,
                      reveal: reveal,
                      tappable: false,
                      // The size gene can draw it a little past its box.
                      captureScale: 1.4,
                      child: sprite,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// INTERACTIVE HERO WRAPPER
// (you said we can move this to your other widget file later)
// ============================================================================

class FeaturedHeroInteractive extends StatelessWidget {
  final PresentationData data;
  final FactionTheme theme;
  final AnimationController breathing;
  final VoidCallback onLongPressChoose;
  final VoidCallback onTapDetails;
  final CreatureInstance instance;
  final Creature creature;
  final EssenceReveal? reveal;
  final GlobalKey? spriteKey;

  const FeaturedHeroInteractive({
    super.key,
    required this.data,
    required this.theme,
    required this.breathing,
    required this.onLongPressChoose,
    required this.onTapDetails,
    required this.instance,
    required this.creature,
    this.reveal,
    this.spriteKey,
  });

  @override
  Widget build(BuildContext context) {
    return FastLongPressDetector(
      onTap: context.soundAction(onTapDetails),
      onLongPress: onLongPressChoose,
      child: Container(
        color: Colors.transparent,
        child: FeaturedCreaturePresentation(
          breathing: breathing,
          theme: theme,
          instance: instance,
          creature: creature,
          displayName: data.displayName,
          subtitle: data.subtitle,
          reveal: reveal,
          spriteKey: spriteKey,
        ),
      ),
    );
  }
}

/// lightweight struct to pass around presentation info to the hero widget
class PresentationData {
  final String displayName;
  final String subtitle;
  final CreatureInstance instance;
  final Creature creature;

  PresentationData({
    required this.displayName,
    required this.subtitle,
    required this.instance,
    required this.creature,
  });
}

/// The featured specimen's glow: its faction's colour at the heart, fading
/// through the accent into nothing past the edge of its 220 box.
///
/// One radial gradient. It replaced a gradient disc over a 40px blurred
/// shadow, which the breathing float redrew every frame — a blur on home for
/// as long as home was open.
class _HaloPainter extends CustomPainter {
  const _HaloPainter({required this.core, required this.rim});

  final Color core;
  final Color rim;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    // The old shadow reached about 1.5x the disc's radius.
    final r = size.shortestSide * 0.75;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            core,
            Color.lerp(core, rim, 0.5)!.withValues(alpha: 0.72),
            rim.withValues(alpha: 0.24),
            rim.withValues(alpha: 0.07),
            rim.withValues(alpha: 0),
          ],
          stops: const [0, 0.33, 0.667, 0.85, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(covariant _HaloPainter old) =>
      old.core != core || old.rim != rim;
}
