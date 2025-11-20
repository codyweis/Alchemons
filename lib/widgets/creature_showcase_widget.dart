import 'dart:math' as math;
import 'dart:ui';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class FeaturedCreaturePresentation extends StatelessWidget {
  final AnimationController breathing;
  final FactionTheme theme;

  // Creature label
  final String displayName;
  final String subtitle; // e.g. "Specimen #12" or element/faction
  final CreatureInstance instance;
  final Creature creature;
  const FeaturedCreaturePresentation({
    super.key,
    required this.breathing,
    required this.theme,
    required this.displayName,
    required this.subtitle,
    required this.instance,
    required this.creature,
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
                  child: InstanceSprite(
                    creature: creature,
                    instance: instance,
                    size: 72,
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

  const FeaturedHeroInteractive({
    super.key,
    required this.data,
    required this.theme,
    required this.breathing,
    required this.onLongPressChoose,
    required this.onTapDetails,
    required this.instance,
    required this.creature,
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
          instance: instance,
          creature: creature,
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
  final CreatureInstance instance;
  final Creature creature;

  PresentationData({
    required this.displayName,
    required this.subtitle,
    required this.instance,
    required this.creature,
  });
}
