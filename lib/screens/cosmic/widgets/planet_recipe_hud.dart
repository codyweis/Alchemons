import 'package:flutter/material.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';

class PlanetRecipeHud extends StatefulWidget {  const PlanetRecipeHud({
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
  State<PlanetRecipeHud> createState() => _PlanetRecipeHudState();
}

class _PlanetRecipeHudState extends State<PlanetRecipeHud> {
  @override
  Widget build(BuildContext context) {
    final color = widget.planet.color;
    final recipeLabel = widget.recipe.level == 3
        ? '${planetName(widget.planet.element).toUpperCase()} FINAL RECIPE'
        : '${planetName(widget.planet.element).toUpperCase()} RECIPE  LV.${widget.recipe.level}';
    final score = widget.recipe.matchScore(widget.meter.breakdown, widget.meter.total);
    final scoreColor = score >= 0.7
        ? Colors.greenAccent
        : score >= 0.5
        ? Colors.amber
        : Colors.redAccent;
    final meterFull = widget.meter.isFull;
    // Highlighted when meter is full (regardless of match) or when match is good
    final buttonActive = (meterFull || score >= 0.7) && widget.onSummon != null;
    // Good match gets amber glow; full-but-mismatched gets a cool cyan glow
    final goodMatch = score >= 0.7 && widget.onSummon != null;

    // Sort recipe components by percentage descending
    final sortedComponents = widget.recipe.components.entries.toList()
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
                widget.hideLevel
                    ? '${planetName(widget.planet.element).toUpperCase()} PATHWAY'
                    : recipeLabel,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              if (widget.showPinnedTag) ...[
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
                onTap: widget.onTogglePin,
                radius: 16,
                child: Icon(
                  widget.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 15,
                  color: widget.isPinned
                      ? color.withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(width: 6),
              // Match score
              if (widget.meter.total > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: scoreColor.withValues(alpha: 0.62),
                    ),
                  ),
                  child: Text(
                    '${(score * 100).toStringAsFixed(0)}% MATCH',
                    style: TextStyle(
                      color: scoreColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      shadows: const [
                        Shadow(color: Colors.black87, blurRadius: 6),
                      ],
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
            final actualPct = widget.meter.total > 0
                ? ((widget.meter.breakdown[e.key] ?? 0) / widget.meter.total * 100)
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
                        color: Colors.white.withValues(alpha: 0.94),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        shadows: const [
                          Shadow(color: Colors.black87, blurRadius: 5),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${targetPct.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: elemColor.withValues(alpha: 0.98),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        shadows: const [
                          Shadow(color: Colors.black87, blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.white.withValues(alpha: 0.18),
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
                    width: 34,
                    child: Text(
                      '${actualPct.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: good
                            ? Colors.white.withValues(alpha: 0.96)
                            : const Color(0xFFFF8A80),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        shadows: const [
                          Shadow(color: Colors.black87, blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Random allowance
          if (widget.recipe.randomPct > 0)
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
                    'Any  ${widget.recipe.randomPct.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      shadows: const [
                        Shadow(color: Colors.black87, blurRadius: 5),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),
          GestureDetector(
            onTap: widget.onSummon,
            child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: goodMatch
                        ? [
                            const Color(0xFFFF6F00),
                            const Color(0xFFFF8F00),
                            const Color(0xFFFFC107),
                          ]
                        : buttonActive
                        ? [
                            const Color(0xFF1A3A5C),
                            const Color(0xFF1E4D7A),
                            const Color(0xFF2196F3).withValues(alpha: 0.85),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.07),
                            Colors.white.withValues(alpha: 0.03),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: goodMatch
                      ? [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.38),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: const Color(0xFFFF6F00).withValues(alpha: 0.22),
                            blurRadius: 36,
                            spreadRadius: 4,
                          ),
                        ]
                      : buttonActive
                      ? [
                          BoxShadow(
                            color: const Color(0xFF2196F3).withValues(alpha: 0.28),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                  border: goodMatch
                      ? Border.all(
                          color: Colors.amber.withValues(alpha: 0.55),
                          width: 1.2,
                        )
                      : buttonActive
                      ? Border.all(
                          color: const Color(0xFF2196F3).withValues(alpha: 0.4),
                          width: 1.0,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.actionLabel,
                  style: TextStyle(
                    color: buttonActive
                        ? Colors.white.withValues(alpha: 0.95)
                        : Colors.white.withValues(alpha: 0.28),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
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
