import 'package:flutter/material.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';

class PlanetRecipeHud extends StatelessWidget {
  const PlanetRecipeHud({
    super.key,
    required this.planet,
    required this.recipe,
    required this.meter,
    required this.onSummon,
    this.actionLabel = 'SUMMON',
    this.hideLevel = false,
    this.onTogglePin,
    this.isPinned = false,
    this.showPinnedTag = false,
  });

  final CosmicPlanet planet;
  final PlanetRecipe recipe;
  final ElementMeter meter;
  final VoidCallback? onSummon; // null if meter not full
  final String actionLabel;
  final bool hideLevel;
  final VoidCallback? onTogglePin;
  final bool isPinned;
  final bool showPinnedTag;

  @override
  Widget build(BuildContext context) {
    final color = planet.color;
    final score = recipe.matchScore(meter.breakdown, meter.total);
    final scoreColor = score >= 0.7
        ? Colors.greenAccent
        : score >= 0.5
        ? Colors.amber
        : Colors.redAccent;

    // Sort recipe components by percentage descending
    final sortedComponents = recipe.components.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.08),
            const Color(0xFF0A0E27).withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.public, color: color, size: 14),
              const SizedBox(width: 8),
              Text(
                hideLevel
                    ? '${planetName(planet.element).toUpperCase()} PATHWAY'
                    : '${planetName(planet.element).toUpperCase()} RECIPE  LV.${recipe.level}',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              if (showPinnedTag) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    'PINNED',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              InkResponse(
                onTap: onTogglePin,
                radius: 16,
                child: Icon(
                  isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 15,
                  color: isPinned
                      ? color.withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(width: 6),
              // Match score
              if (meter.total > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: scoreColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    '${(score * 100).toStringAsFixed(0)}% MATCH',
                    style: TextStyle(
                      color: scoreColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Recipe ingredients
          ...sortedComponents.map((e) {
            final elemColor = elementColor(e.key);
            final targetPct = e.value;
            final actualPct = meter.total > 0
                ? ((meter.breakdown[e.key] ?? 0) / meter.total * 100)
                : 0.0;
            final diff = (actualPct - targetPct).abs();
            final good = diff <= 10;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.5),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: elemColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 56,
                    child: Text(
                      e.key,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${targetPct.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: elemColor.withValues(alpha: 0.9),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.white10,
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (actualPct / 100).clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: good
                                ? elemColor
                                : elemColor.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${actualPct.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: good
                            ? Colors.white70
                            : Colors.red.withValues(alpha: 0.7),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Random allowance
          if (recipe.randomPct > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Any  ${recipe.randomPct.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),
          GestureDetector(
            onTap: onSummon,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: score >= 0.7 && onSummon != null
                      ? [
                          const Color(0xFFFF6F00),
                          const Color(0xFFFF8F00),
                          const Color(0xFFFFC107),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.08),
                          Colors.white.withValues(alpha: 0.04),
                        ],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: score >= 0.7 && onSummon != null
                    ? [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 3,
                        ),
                        BoxShadow(
                          color: const Color(
                            0xFFFF6F00,
                          ).withValues(alpha: 0.25),
                          blurRadius: 40,
                          spreadRadius: 6,
                        ),
                      ]
                    : null,
                border: score >= 0.7 && onSummon != null
                    ? Border.all(
                        color: Colors.amber.withValues(alpha: 0.6),
                        width: 1.5,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: score >= 0.7 && onSummon != null
                        ? Colors.white
                        : Colors.white38,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    actionLabel,
                    style: TextStyle(
                      color: score >= 0.7 && onSummon != null
                          ? Colors.white
                          : Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// HOME PLANET MENU OVERLAY (full-screen when near home)
// ─────────────────────────────────────────────────────────
