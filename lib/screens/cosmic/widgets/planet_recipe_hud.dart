import 'package:flutter/material.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/app_icons.dart';

// Cosmic HUD always renders on the dark space backdrop.
const _palette = BracketPalette.dark;

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
    final planetLabel = planetName(widget.planet.element).toUpperCase();
    final recipeLabel = widget.hideLevel
        ? '$planetLabel PATHWAY'
        : '$planetLabel RECIPE';
    // Recipe runs levels 1..3; levels below the current one are complete.
    final completedLevels = (widget.recipe.level - 1).clamp(0, 3);
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

    return CustomPaint(
      painter: BracketFramePainter(
        color: color.withValues(alpha: 0.8),
        bracketSize: 10,
        strokeWidth: 1.1,
      ),
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: _palette.surfaceFill(),
          border: Border.all(
            color: _palette.lineSoft.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(width: 3, height: 14, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          recipeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: bracketText(
                            context,
                            11.5,
                            color,
                            weight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      if (!widget.hideLevel) ...[
                        const SizedBox(width: 8),
                        _RecipeStars(
                          completed: completedLevels,
                          color: color,
                        ),
                      ],
                      if (widget.showPinnedTag) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          color: _palette.bg0,
                          child: Text(
                            'PINNED',
                            style: bracketText(
                              context,
                              9,
                              _palette.muted,
                              weight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkResponse(
                  onTap: widget.onTogglePin,
                  radius: 16,
                  child: Icon(
                    widget.isPinned
                        ? AppIcons.push_pin
                        : AppIcons.push_pin_outlined,
                    size: 15,
                    color: widget.isPinned ? color : _palette.muted,
                  ),
                ),
                const SizedBox(width: 8),
                // Match score
                if (widget.meter.total > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.16),
                      border: Border(
                        left: BorderSide(color: scoreColor, width: 2),
                      ),
                    ),
                    child: Text(
                      '${(score * 100).toStringAsFixed(0)}% match',
                      style: bracketText(
                        context,
                        10.5,
                        scoreColor,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

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
              padding: const EdgeInsets.symmetric(vertical: 2.5),
              child: Row(
                children: [
                  Container(width: 7, height: 7, color: elemColor),
                  const SizedBox(width: 7),
                  SizedBox(
                    width: 56,
                    child: Text(
                      e.key,
                      style: bracketText(
                        context,
                        12,
                        _palette.ink,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${targetPct.toStringAsFixed(0)}%',
                      style: bracketText(
                        context,
                        12,
                        elemColor,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 5,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ColoredBox(color: _palette.lineSoft),
                          ),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: (actualPct / 100).clamp(0.0, 1.0),
                            child: ColoredBox(
                              color: good
                                  ? elemColor
                                  : elemColor.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${actualPct.toStringAsFixed(0)}%',
                      style: bracketText(
                        context,
                        12,
                        good ? _palette.ink : const Color(0xFFFF8A80),
                        weight: FontWeight.w700,
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
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                children: [
                  Container(width: 7, height: 7, color: _palette.muted),
                  const SizedBox(width: 7),
                  Text(
                    'Any  ${widget.recipe.randomPct.toStringAsFixed(0)}%',
                    style: bracketText(
                      context,
                      12,
                      _palette.muted,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 10),
          _SummonButton(
            label: widget.actionLabel,
            color: color,
            goodMatch: goodMatch,
            active: buttonActive,
            onTap: widget.onSummon,
          ),
        ],
      ),
      ),
    );
  }
}

/// 3-star recipe progress — one star per planet recipe level. Completed
/// levels are filled; the level currently in progress is a bright outline.
class _RecipeStars extends StatelessWidget {
  const _RecipeStars({required this.completed, required this.color});

  final int completed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final filled = i < completed;
        final current = i == completed;
        return Padding(
          padding: EdgeInsets.only(right: i == 2 ? 0 : 3),
          child: Icon(
            filled ? AppIcons.star_rounded : AppIcons.star_outline_rounded,
            size: 14,
            color: filled
                ? color
                : (current
                      ? color.withValues(alpha: 0.85)
                      : _palette.line),
          ),
        );
      }),
    );
  }
}

class _SummonButton extends StatelessWidget {
  const _SummonButton({
    required this.label,
    required this.color,
    required this.goodMatch,
    required this.active,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool goodMatch;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Good match → solid accent CTA. Active-but-mismatched → solid dark with
    // accent edge. Inactive → muted, no emphasis.
    final accent = goodMatch
        ? const Color(0xFFE4C16A)
        : (active ? const Color(0xFF5BC8E8) : _palette.line);
    final filled = goodMatch;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        painter: BracketFramePainter(
          color: active ? accent : _palette.line.withValues(alpha: 0.6),
          bracketSize: 9,
          strokeWidth: active ? 1.3 : 1.0,
        ),
        child: Container(
          width: double.infinity,
          height: 42,
          alignment: Alignment.center,
          color: filled
              ? accent
              : (active
                    ? accent.withValues(alpha: 0.14)
                    : _palette.surfaceMutedFill()),
          child: Text(
            label,
            style: bracketText(
              context,
              13,
              filled
                  ? const Color(0xFF12161D)
                  : (active ? accent : _palette.muted),
              weight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// HOME PLANET MENU OVERLAY (full-screen when near home)
// ─────────────────────────────────────────────────────────
