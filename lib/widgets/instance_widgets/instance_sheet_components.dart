// lib/widgets/instance_widgets/instance_sheet_components.dart
//
// REDESIGNED INSTANCE SHEET COMPONENTS
// Aesthetic: Scorched Forge — dark metal cards, amber accents, monospace
// All logic, props, and public API preserved exactly.
//

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/database/daos/creature_dao.dart';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/utils/color_util.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/widgets/creature_selection_sheet.dart';
import 'package:alchemons/widgets/fast_long_press_detector.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/stamina_bar.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/app_icons.dart';

String _displayVariantFaction(String faction) {
  final trimmed = faction.trim();
  if (trimmed.isEmpty) return trimmed;
  if (trimmed.toLowerCase() == 'bloodborn') return 'Bloodborn';
  return trimmed[0].toUpperCase() + trimmed.substring(1);
}

// ──────────────────────────────────────────────────────────────────────────────
// INSTANCE CARD
// ──────────────────────────────────────────────────────────────────────────────

class InstanceCard extends StatelessWidget {
  final Creature species;
  final CreatureInstance instance;
  final FactionTheme theme;
  final InstanceDetailMode detailMode;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  final bool isSelected;
  final int? selectionNumber;
  final SortBy? activeSortBy;

  final Duration? harvestDuration;
  final int Function(CreatureInstance)? calculateHarvestRate;

  const InstanceCard({
    super.key,
    required this.species,
    required this.instance,
    required this.theme,
    required this.detailMode,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.selectionNumber,
    this.activeSortBy,
    this.harvestDuration,
    this.calculateHarvestRate,
  });

  bool get _isHarvestMode =>
      harvestDuration != null && calculateHarvestRate != null;

  // Selection accent colors: first=amber, second=teal, third=purple
  Color _selectionColor(ForgeTokens t) => switch (selectionNumber) {
    1 => t.amber,
    2 => t.teal,
    3 => const Color(0xFFA855F7),
    _ => t.success,
  };

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    final hasPotentialAnalyzer = context
        .watch<ConstellationEffectsService>()
        .hasPotentialAnalyzer();
    final genetics = decodeGenetics(instance.geneticsJson);
    final sd = species.spriteData;
    final rarityColor = BreedConstants.getRarityColor(species.rarity);
    final sortBadgeColor = switch (activeSortBy?.statFamily) {
      'speed' => const Color(0xFFFDE047),
      'intelligence' => const Color(0xFFC084FC),
      'strength' => const Color(0xFFF87171),
      'beauty' => const Color(0xFFF9A8D4),
      _ => t.amberBright,
    };
    final showSortBadge = activeSortBy?.isStatSort == true;
    final topLeftLabel = showSortBadge
        ? 'LV ${instance.level} ${activeSortBy!.shortLabel} ${activeSortBy!.valueForInstance(instance).toStringAsFixed(1)}'
        : 'LV ${instance.level}';
    final topLeftTextColor = showSortBadge
        ? t.readableAccent(sortBadgeColor)
        : t.amberBright;
    final topLeftBorderColor = showSortBadge
        ? topLeftTextColor.withValues(alpha: 0.85)
        : rarityColor.withValues(alpha: 0.85);

    final bottomBlock = _isHarvestMode
        ? _HarvestBlock(
            instance: instance,
            harvestDuration: harvestDuration!,
            calculateRate: calculateHarvestRate!,
            isSelected: isSelected,
            selectionNumber: selectionNumber,
          )
        : switch (detailMode) {
            InstanceDetailMode.info => _StatsBlock(
              instance: instance,
              isSelected: isSelected,
              selectionNumber: selectionNumber,
              creatureName: species.name,
              showPotentials: hasPotentialAnalyzer,
            ),
            InstanceDetailMode.stats => _StatsBlock(
              instance: instance,
              isSelected: isSelected,
              selectionNumber: selectionNumber,
              creatureName: species.name,
              showPotentials: hasPotentialAnalyzer,
            ),
            InstanceDetailMode.genetics => _GeneticsBlock(
              instance: instance,
              genetics: genetics,
              isSelected: isSelected,
              selectionNumber: selectionNumber,
              creatureName: species.name,
            ),
            InstanceDetailMode.enhancement => _EnhancementBlock(
              instance: instance,
              isSelected: isSelected,
              selectionNumber: selectionNumber,
              creatureName: species.name,
            ),
          };

    final palette = BracketPalette.fromTheme(theme);
    final selColor = isSelected ? _selectionColor(t) : palette.line;

    return FastLongPressDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: CustomPaint(
        painter: BracketFramePainter(
          color: isSelected ? selColor : palette.line.withValues(alpha: 0.75),
          bracketSize: 10,
          strokeWidth: isSelected ? 1.5 : 1.05,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? palette.accentWash(selColor)
                : palette.surfaceFill(),
            border: Border.all(
              color: isSelected
                  ? selColor.withValues(alpha: 0.4)
                  : palette.lineSoft.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Sprite area ──────────────────────────────────────
              Expanded(
                child: Stack(
                  children: [
                    Center(
                      child: RepaintBoundary(
                        child: sd != null
                            ? InstanceSprite(
                                creature: species,
                                instance: instance,
                                size: 90,
                              )
                            : Image.asset(species.image, fit: BoxFit.contain),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      child: _CardCornerPill(
                        label: topLeftLabel,
                        color: topLeftTextColor,
                        frameColor: topLeftBorderColor,
                        palette: palette,
                        fontSize: showSortBadge ? 9 : 10,
                      ),
                    ),
                    if (instance.isFavorite ||
                        (isSelected && selectionNumber != null))
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (instance.isFavorite)
                              _CardCornerIcon(
                                icon: AppIcons.star_rounded,
                                color: const Color(0xFFE91E63),
                                palette: palette,
                              ),
                            if (instance.isFavorite &&
                                isSelected &&
                                selectionNumber != null)
                              const SizedBox(height: 4),
                            if (isSelected && selectionNumber != null)
                              _CardSelectionBadge(
                                number: selectionNumber!,
                                color: selColor,
                                palette: palette,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              if (!_isHarvestMode &&
                  detailMode == InstanceDetailMode.genetics) ...[
                _CardNameLine(
                  instance: instance,
                  creatureName: species.name,
                  trailing: _CompactStaminaSummary(instance: instance),
                ),
                const SizedBox(height: 4),
              ],

              bottomBlock,
            ],
          ),
        ),
      ),
    );
  }
}

class _CardCornerPill extends StatelessWidget {
  const _CardCornerPill({
    required this.label,
    required this.color,
    required this.frameColor,
    required this.palette,
    required this.fontSize,
  });

  final String label;
  final Color color;
  final Color frameColor;
  final BracketPalette palette;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: palette.chromeFill(),
        border: Border(left: BorderSide(color: color, width: 2)),
      ),
      child: Text(
        label,
        style: bracketText(
          context,
          fontSize,
          color,
          weight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _CardCornerIcon extends StatelessWidget {
  const _CardCornerIcon({
    required this.icon,
    required this.color,
    required this.palette,
  });

  final IconData icon;
  final Color color;
  final BracketPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      color: palette.chromeFill(),
      child: Icon(icon, size: 11, color: color),
    );
  }
}

class _CardSelectionBadge extends StatelessWidget {
  const _CardSelectionBadge({
    required this.number,
    required this.color,
    required this.palette,
  });

  final int number;
  final Color color;
  final BracketPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      color: color,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.merge_type_rounded, color: palette.bg0, size: 10),
          const SizedBox(width: 3),
          Text(
            '$number',
            style: bracketText(
              context,
              12,
              palette.bg0,
              weight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// STATS BLOCK
// ──────────────────────────────────────────────────────────────────────────────

class _StatsBlock extends StatelessWidget {
  final CreatureInstance instance;
  final bool isSelected;
  final int? selectionNumber;
  final String creatureName;
  final bool showPotentials;

  const _StatsBlock({
    required this.instance,
    required this.isSelected,
    required this.selectionNumber,
    required this.creatureName,
    required this.showPotentials,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isSelected && selectionNumber != null) ...[
          _ParentChip(selectionNumber: selectionNumber!),
          const SizedBox(height: 4),
        ],
        _CardNameLine(
          instance: instance,
          creatureName: creatureName,
          trailing: _CompactStaminaSummary(instance: instance),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                color: const Color(0xFFFDE047),
                label: 'SPD',
                currentValue: instance.statSpeed,
                potentialValue: showPotentials
                    ? instance.statSpeedPotential
                    : null,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _StatTile(
                color: const Color(0xFFC084FC),
                label: 'INT',
                currentValue: instance.statIntelligence,
                potentialValue: showPotentials
                    ? instance.statIntelligencePotential
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                color: const Color(0xFFF87171),
                label: 'STR',
                currentValue: instance.statStrength,
                potentialValue: showPotentials
                    ? instance.statStrengthPotential
                    : null,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _StatTile(
                color: const Color(0xFFF9A8D4),
                label: 'BEA',
                currentValue: instance.statBeauty,
                potentialValue: showPotentials
                    ? instance.statBeautyPotential
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final Color color;
  final String label;
  final double currentValue;
  final double? potentialValue;

  const _StatTile({
    required this.color,
    required this.label,
    required this.currentValue,
    required this.potentialValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final t = ForgeTokens(theme);
    final palette = BracketPalette.fromTheme(theme);
    final displayColor = t.readableAccent(color);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(width: 2, height: 18, color: displayColor),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: bracketText(
                    context,
                    10,
                    palette.muted,
                    weight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  potentialValue == null
                      ? '${AlchemonStatSystem.displayRating(currentValue)}'
                      : '${AlchemonStatSystem.displayRating(currentValue)} · P${AlchemonStatSystem.normalizePotential(potentialValue!)}',
                  style: bracketText(
                    context,
                    12.5,
                    displayColor,
                    weight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// ENHANCEMENT BLOCK
// ──────────────────────────────────────────────────────────────────────────────

class _EnhancementBlock extends StatelessWidget {
  final CreatureInstance instance;
  final bool isSelected;
  final int? selectionNumber;
  final String creatureName;

  const _EnhancementBlock({
    required this.instance,
    required this.isSelected,
    required this.selectionNumber,
    required this.creatureName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isSelected && selectionNumber != null) ...[
          _ParentChip(selectionNumber: selectionNumber!),
          const SizedBox(height: 4),
        ],
        _CardNameLine(
          instance: instance,
          creatureName: creatureName,
          trailing: _TotalEnhancementSummary(instance: instance),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _EnhancementTile(
                color: const Color(0xFFFDE047),
                label: 'SPD',
                rank: instance.statSpeedEnhancement,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _EnhancementTile(
                color: const Color(0xFFC084FC),
                label: 'INT',
                rank: instance.statIntelligenceEnhancement,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _EnhancementTile(
                color: const Color(0xFFF87171),
                label: 'STR',
                rank: instance.statStrengthEnhancement,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _EnhancementTile(
                color: const Color(0xFFF9A8D4),
                label: 'BEA',
                rank: instance.statBeautyEnhancement,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Ranks bought out of the 40 available, so a card can be read at a glance
/// without adding up four tiles.
class _TotalEnhancementSummary extends StatelessWidget {
  final CreatureInstance instance;

  const _TotalEnhancementSummary({required this.instance});

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final t = ForgeTokens(theme);
    final palette = BracketPalette.fromTheme(theme);
    const perStatMax = AlchemonStatSystem.maxEnhancementRank;
    final total =
        instance.statSpeedEnhancement +
        instance.statIntelligenceEnhancement +
        instance.statStrengthEnhancement +
        instance.statBeautyEnhancement;
    final full = total >= perStatMax * 4;
    return Text(
      'ENH $total/${perStatMax * 4}',
      style: bracketText(
        context,
        10,
        full ? t.amberBright : palette.muted,
        weight: FontWeight.w800,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _EnhancementTile extends StatelessWidget {
  final Color color;
  final String label;
  final int rank;

  const _EnhancementTile({
    required this.color,
    required this.label,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final t = ForgeTokens(theme);
    final palette = BracketPalette.fromTheme(theme);
    final displayColor = t.readableAccent(color);
    const maxRank = AlchemonStatSystem.maxEnhancementRank;
    final maxed = rank >= maxRank;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(width: 2, height: 18, color: displayColor),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: bracketText(
                          context,
                          10,
                          palette.muted,
                          weight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    Text(
                      '$rank/$maxRank',
                      style: bracketText(
                        context,
                        10,
                        maxed ? t.amberBright : displayColor,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                // One pip per rank, matching the Stat Infusion plate so the
                // two screens read the same way.
                Row(
                  children: [
                    for (var i = 0; i < maxRank; i++) ...[
                      if (i > 0) const SizedBox(width: 1),
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: i < rank
                                ? (maxed ? t.amberBright : displayColor)
                                : palette.line.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// GENETICS BLOCK
// ──────────────────────────────────────────────────────────────────────────────

class _GeneticsBlock extends StatelessWidget {
  final CreatureInstance instance;
  final Genetics? genetics;
  final bool isSelected;
  final int? selectionNumber;
  final String creatureName;

  const _GeneticsBlock({
    required this.instance,
    required this.genetics,
    required this.isSelected,
    required this.selectionNumber,
    required this.creatureName,
  });

  String _sizeName() =>
      sizeLabels[genetics?.get('size') ?? 'normal'] ?? 'Standard';
  String _tintName() =>
      tintLabels[genetics?.get('tinting') ?? 'normal'] ?? 'Standard';

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    final variant = instance.variantFaction?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isSelected && selectionNumber != null) ...[
          _ParentChip(selectionNumber: selectionNumber!),
          const SizedBox(height: 3),
        ],
        if (instance.isPrismaticSkin == true) ...[
          const _PrismaticChip(),
          const SizedBox(height: 3),
        ],
        if (variant.isNotEmpty) ...[
          _MiniRow(
            color: FactionColors.of(_displayVariantFaction(variant)),
            label: _displayVariantFaction(variant).toUpperCase(),
          ),
          const SizedBox(height: 2),
        ],
        _MiniRow(color: t.amberBright, label: _sizeName().toUpperCase()),
        const SizedBox(height: 2),
        _MiniRow(color: t.amberBright, label: _tintName().toUpperCase()),
        if (instance.natureId?.isNotEmpty == true) ...[
          const SizedBox(height: 2),
          _MiniRow(
            color: t.textSecondary,
            label: instance.natureId!.toUpperCase(),
          ),
        ],
        if (instance.natureId2?.isNotEmpty == true) ...[
          const SizedBox(height: 2),
          _MiniRow(
            color: t.textSecondary,
            label: instance.natureId2!.toUpperCase(),
          ),
        ],
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// HARVEST BLOCK
// ──────────────────────────────────────────────────────────────────────────────

class _HarvestBlock extends StatelessWidget {
  final CreatureInstance instance;
  final Duration harvestDuration;
  final int Function(CreatureInstance) calculateRate;
  final bool isSelected;
  final int? selectionNumber;

  const _HarvestBlock({
    required this.instance,
    required this.harvestDuration,
    required this.calculateRate,
    required this.isSelected,
    required this.selectionNumber,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    final rate = calculateRate(instance);
    final total = rate * harvestDuration.inMinutes;

    final genetics = decodeGenetics(instance.geneticsJson);
    final sizeKey = genetics?.get('size') ?? 'normal';
    final sizeName = sizeLabels[sizeKey] ?? sizeKey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _InlineStaminaSummary(instance: instance),
        const SizedBox(height: 4),
        if (isSelected && selectionNumber != null) ...[
          _ParentChip(selectionNumber: selectionNumber!),
          const SizedBox(height: 3),
        ],
        if (instance.isPrismaticSkin == true) ...[
          const _PrismaticChip(),
          const SizedBox(height: 3),
        ],
        // Total output row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox.shrink(),
            Row(
              children: [
                Icon(
                  AppIcons.inventory_2_rounded,
                  size: 10,
                  color: t.amberBright,
                ),
                const SizedBox(width: 3),
                Text(
                  '$total',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: t.amberBright,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _MiniRow(color: t.textSecondary, label: sizeName.toUpperCase()),
            if (instance.natureId?.isNotEmpty == true)
              _MiniRow(
                color: t.textSecondary,
                label: instance.natureId!.toUpperCase(),
              ),
            if (instance.natureId2?.isNotEmpty == true)
              _MiniRow(
                color: t.textSecondary,
                label: instance.natureId2!.toUpperCase(),
              ),
          ],
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// SHARED MINI WIDGETS
// ──────────────────────────────────────────────────────────────────────────────

class _MiniRow extends StatelessWidget {
  final Color color;
  final String label;
  const _MiniRow({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 4, height: 4, color: color),
        const SizedBox(width: 6),
        Flexible(
          fit: FlexFit.loose,
          child: Text(
            label,
            style: bracketText(
              context,
              11.5,
              color,
              weight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ParentChip extends StatelessWidget {
  final int selectionNumber;
  const _ParentChip({required this.selectionNumber});

  Color get _color => switch (selectionNumber) {
    1 => const Color(0xFFD97706),
    2 => const Color(0xFF0EA5E9),
    3 => const Color(0xFFA855F7),
    _ => const Color(0xFF16A34A),
  };

  @override
  Widget build(BuildContext context) {
    final c = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        border: Border(left: BorderSide(color: c, width: 2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.merge_type_rounded, color: c, size: 10),
          const SizedBox(width: 4),
          Text(
            'Parent $selectionNumber',
            style: bracketText(
              context,
              11,
              c,
              weight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrismaticChip extends StatelessWidget {
  const _PrismaticChip();

  @override
  Widget build(BuildContext context) {
    const c = Color(0xFFE879F9);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        border: Border(left: BorderSide(color: c, width: 2)),
      ),
      child: Text(
        'Prismatic',
        style: bracketText(
          context,
          11,
          c,
          weight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _CardNameLine extends StatelessWidget {
  const _CardNameLine({
    required this.instance,
    required this.creatureName,
    this.trailing,
  });

  final CreatureInstance instance;
  final String creatureName;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    final hasNick = instance.nickname?.trim().isNotEmpty == true;
    final nick = hasNick ? instance.nickname!.trim() : creatureName;

    return Row(
      children: [
        Expanded(
          child: Text(
            nick,
            style: bracketText(
              context,
              13,
              palette.ink,
              weight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 6), trailing!],
      ],
    );
  }
}

class _CompactStaminaSummary extends StatelessWidget {
  const _CompactStaminaSummary({required this.instance});

  final CreatureInstance instance;

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    final palette = BracketPalette.of(context);
    final stamina = context.read<StaminaService>();
    final state = stamina.computeState(instance);
    final bars = state.bars.clamp(0, state.max);
    final max = state.max <= 0 ? 1 : state.max;
    final textColor = t.readableAccent(const Color(0xFF22C55E));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StaminaBar(
          current: bars,
          max: max,
          size: 5,
          gap: 1.5,
          fillColor: textColor,
          emptyColor: palette.lineSoft,
          radius: BorderRadius.zero,
        ),
        const SizedBox(width: 5),
        Text(
          '$bars/$max',
          style: bracketText(
            context,
            11,
            textColor,
            weight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _InlineStaminaSummary extends StatelessWidget {
  const _InlineStaminaSummary({required this.instance});

  final CreatureInstance instance;

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    final palette = BracketPalette.of(context);
    final stamina = context.read<StaminaService>();
    final state = stamina.computeState(instance);
    final bars = state.bars.clamp(0, state.max);
    final max = state.max <= 0 ? 1 : state.max;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(AppIcons.local_fire_department, size: 12, color: t.success),
        const SizedBox(width: 5),
        StaminaBar(
          current: bars,
          max: max,
          size: 7,
          gap: 2,
          fillColor: t.success,
          emptyColor: palette.lineSoft,
          radius: BorderRadius.zero,
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// EMPTY STATE  (public)
// ──────────────────────────────────────────────────────────────────────────────

class InstancesEmptyState extends StatelessWidget {
  final Color primaryColor;
  final bool hasFilters;

  const InstancesEmptyState({
    super.key,
    required this.primaryColor,
    this.hasFilters = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final palette = BracketPalette.fromTheme(theme);
    final activeAccent = bracketReadableAccent(theme);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              painter: BracketFramePainter(
                color: activeAccent.withValues(alpha: 0.82),
                bracketSize: 10,
                strokeWidth: 1.1,
              ),
              child: Container(
                padding: const EdgeInsets.all(22),
                color: palette.surfaceFill(),
                child: Icon(
                  hasFilters
                      ? AppIcons.search_off_rounded
                      : AppIcons.science_outlined,
                  size: 36,
                  color: palette.muted,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters ? 'No matching specimens' : 'No specimens contained',
              style: bracketText(
                context,
                14,
                palette.ink,
                weight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters
                  ? 'Adjust filters or clear your search'
                  : 'Acquire specimens through fusion, rift portals, or planet summons.',
              style: bracketText(
                context,
                12.5,
                palette.muted,
                weight: FontWeight.w500,
                fontStyle: FontStyle.italic,
              ),
              strutStyle: const StrutStyle(height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
