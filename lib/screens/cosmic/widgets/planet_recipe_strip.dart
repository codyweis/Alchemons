// lib/screens/cosmic/widgets/planet_recipe_strip.dart
//
// The planet recipe, as a single band under the top HUD.
//
// This replaced a 218pt centred card that sat over the play area the whole
// time the ship was at a gate. The heavy lifting moved onto the alchemical
// meter itself — see `_RecipeTargetPainter` in top_hud.dart, which draws the
// recipe's target percentages as notches on the meter fill. This strip carries
// only what the notches cannot say: which planet, what the targets are in
// words, how close the match is, and the action.
//
// Full per-ingredient detail lives in the meter-tap breakdown sheet. Resist
// growing this band; its whole point is that it is one line tall.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/screens/cosmic/widgets/cosmic_screen_styles.dart';
import 'package:alchemons/utils/app_font_family.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';

class PlanetRecipeStrip extends StatelessWidget {
  const PlanetRecipeStrip({
    super.key,
    required this.planet,
    required this.recipe,
    required this.meter,
    required this.onSummon,
    required this.onDetail,
    this.actionLabel = 'UNSEAL GATE',
    this.isPinned = false,
    this.onTogglePin,
  });

  final CosmicPlanet planet;
  final PlanetRecipe recipe;
  final ElementMeter meter;

  /// Null until the gate can actually be opened.
  final VoidCallback? onSummon;

  /// Opens the meter breakdown, where the full recipe lives.
  final VoidCallback onDetail;

  final String actionLabel;
  final bool isPinned;
  final VoidCallback? onTogglePin;

  static const double height = 26;

  @override
  Widget build(BuildContext context) {
    final color = planet.color;
    final font = appFontFamily(context);
    final score = recipe.matchScore(meter.breakdown, meter.total);
    final ready = onSummon != null;

    final scoreColor = score >= 0.7
        ? const Color(0xFF7BE88C)
        : score >= 0.5
        ? CosmicScreenStyles.amberBright
        : const Color(0xFFFF8A80);

    // Targets in words — the notches show where, this says what.
    final sorted = recipe.components.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final targets = sorted
        .map((e) => '${e.key.toUpperCase()} ${e.value.toStringAsFixed(0)}')
        .join('  ·  ');

    return SizedBox(
      height: height,
      child: GestureDetector(
        onTap: onDetail,
        behavior: HitTestBehavior.opaque,
        child: CustomPaint(
          foregroundPainter: BracketFramePainter(
            color: color.withValues(alpha: 0.75),
            bracketSize: 6,
            strokeWidth: 1.05,
          ),
          child: Container(
            color: CosmicScreenStyles.bg1.withValues(alpha: 0.92),
            child: Row(
              children: [
                Container(width: 3, height: height, color: color),
                const SizedBox(width: 9),
                Text(
                  planetName(planet.element).toUpperCase(),
                  style: TextStyle(
                    fontFamily: font,
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    targets,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: font,
                      color: CosmicScreenStyles.textSecondary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      height: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (meter.total > 0)
                  Text(
                    '${(score * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontFamily: font,
                      color: scoreColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                const SizedBox(width: 8),
                InkResponse(
                  onTap: onTogglePin,
                  radius: 14,
                  child: Icon(
                    isPinned ? AppIcons.push_pin : AppIcons.push_pin_outlined,
                    size: 13,
                    color: isPinned ? color : CosmicScreenStyles.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                // The action only exists once it can be taken.
                if (ready)
                  GestureDetector(
                    onTap: onSummon,
                    child: Container(
                      height: height,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      color: CosmicScreenStyles.amberBright,
                      child: Text(
                        actionLabel,
                        style: TextStyle(
                          fontFamily: font,
                          color: const Color(0xFF12161D),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          height: 1.0,
                        ),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(
                      AppIcons.keyboard_arrow_down_rounded,
                      size: 14,
                      color: CosmicScreenStyles.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
