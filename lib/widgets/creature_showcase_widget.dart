import 'dart:math' as math;
import 'dart:ui';

import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class FeaturedCreaturePresentation extends StatelessWidget {
  final AnimationController breathing;
  final FactionTheme theme;

  // Data for the chosen creature's sprite
  final String spritePath;
  final int totalFrames;
  final int rows;
  final Vector2 frameSize;
  final double stepTime;

  // Cosmetic DNA
  final double scale;
  final double saturation;
  final double brightness;
  final double hueShift;
  final bool isPrismatic;
  final Color? tint;

  // Creature label
  final String displayName;
  final String subtitle; // e.g. "Specimen #12" or element/faction

  const FeaturedCreaturePresentation({
    super.key,
    required this.breathing,
    required this.theme,
    required this.spritePath,
    required this.totalFrames,
    required this.rows,
    required this.frameSize,
    required this.stepTime,
    required this.scale,
    required this.saturation,
    required this.brightness,
    required this.hueShift,
    required this.isPrismatic,
    required this.tint,
    required this.displayName,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
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
                // glow aura behind
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [theme.primary, Colors.transparent],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.accent.withOpacity(0.45),
                        blurRadius: 40,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                ),

                // the animated sprite
                Transform.scale(
                  scale: 2.5,
                  child: CreatureSprite(
                    spritePath: spritePath,
                    totalFrames: totalFrames,
                    rows: rows,
                    frameSize: frameSize,
                    stepTime: stepTime,
                    scale: scale,
                    saturation: saturation,
                    brightness: brightness,
                    hueShift: hueShift,
                    isPrismatic: isPrismatic,
                    tint: tint,
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

// Little frosted label pill
class _SpecimenChip extends StatelessWidget {
  final FactionTheme theme;
  final String title;
  final String subtitle;
  const _SpecimenChip({
    required this.theme,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            border: Border.all(
              color: theme.accent.withOpacity(0.6),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: theme.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
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

  const FeaturedHeroInteractive({
    super.key,
    required this.data,
    required this.theme,
    required this.breathing,
    required this.onLongPressChoose,
    required this.onTapDetails,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTapDetails,
      onLongPress: onLongPressChoose,
      child: Container(
        color: Colors.transparent,
        child: FeaturedCreaturePresentation(
          breathing: breathing,
          theme: theme,
          spritePath: data.spritePath,
          totalFrames: data.totalFrames,
          rows: data.rows,
          frameSize: data.frameSize,
          stepTime: data.stepTime,
          scale: data.scale,
          saturation: data.saturation,
          brightness: data.brightness,
          hueShift: data.hueShift,
          isPrismatic: data.isPrismatic,
          tint: data.tint,
          displayName: data.displayName,
          subtitle: data.subtitle,
        ),
      ),
    );
  }
}

/// lightweight struct to pass around presentation info to the hero widget
class PresentationData {
  final String displayName;
  final String subtitle;
  final String spritePath;
  final int totalFrames;
  final int rows;
  final Vector2 frameSize;
  final double stepTime;
  final double scale;
  final double saturation;
  final double brightness;
  final double hueShift;
  final bool isPrismatic;
  final Color? tint;

  PresentationData({
    required this.displayName,
    required this.subtitle,
    required this.spritePath,
    required this.totalFrames,
    required this.rows,
    required this.frameSize,
    required this.stepTime,
    required this.scale,
    required this.saturation,
    required this.brightness,
    required this.hueShift,
    required this.isPrismatic,
    required this.tint,
  });
}
