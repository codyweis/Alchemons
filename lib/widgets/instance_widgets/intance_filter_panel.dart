// lib/widgets/instance_widgets/intance_filter_panel.dart
//
// REDESIGNED INSTANCE FILTERS PANEL
// Aesthetic: Scorched Forge — dark metal chips, amber accents, monospace
// All logic, props, and public API preserved exactly.
//

import 'package:alchemons/database/daos/creature_dao.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/utils/instance_purity_util.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/utils/faction_util.dart';

// ──────────────────────────────────────────────────────────────────────────────
// BRACKET CHIP HELPER
// ──────────────────────────────────────────────────────────────────────────────

class _BracketChip extends StatelessWidget {
  const _BracketChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.activeColor,
    this.leading,
    this.trailing,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? activeColor;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final palette = BracketPalette.fromTheme(theme);
    final t = ForgeTokens(theme);
    final accent = t.readableAccent(activeColor ?? theme.accentSoft);
    final frameColor = active ? accent : palette.line.withValues(alpha: 0.55);
    final fillColor = active
        ? palette.accentWash(accent, darkAlpha: 0.16, lightAlpha: 0.09)
        : (palette.isDark ? Colors.transparent : palette.surfaceMutedFill());
    final textColor = active ? accent : palette.muted;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        painter: BracketFramePainter(
          color: frameColor,
          bracketSize: 7,
          strokeWidth: active ? 1.2 : 1.0,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          color: fillColor,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 5)],
              Text(
                label,
                style: bracketText(
                  context,
                  12,
                  textColor,
                  weight: active ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 4), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// PANEL
// ──────────────────────────────────────────────────────────────────────────────

class InstanceFiltersPanel extends StatelessWidget {
  final FactionTheme theme;
  final SortBy sortBy;
  final ValueChanged<SortBy> onSortChanged;
  final bool harvestMode;

  final bool filterPrismatic;
  final VoidCallback onTogglePrismatic;

  final String? sizeValueText;
  final VoidCallback onCycleSize;
  final String? tintValueText;
  final VoidCallback onCycleTint;
  final String? variantValueText;
  final VoidCallback onCycleVariant;
  final InstancePurityFilter purityFilter;
  final VoidCallback onCyclePurity;

  final String? filterNature;
  final ValueChanged<String?> onPickNature;
  final Map<String, String> natureOptions;

  final bool filterFavorites;
  final VoidCallback? onToggleFavorites;
  final bool showSortRow;
  final bool showFilterRow;
  final bool showClearChip;

  final VoidCallback onClearAll;

  const InstanceFiltersPanel({
    super.key,
    required this.theme,
    required this.sortBy,
    required this.onSortChanged,
    required this.harvestMode,
    required this.filterPrismatic,
    required this.onTogglePrismatic,
    required this.sizeValueText,
    required this.onCycleSize,
    required this.tintValueText,
    required this.onCycleTint,
    required this.variantValueText,
    required this.onCycleVariant,
    required this.purityFilter,
    required this.onCyclePurity,
    required this.filterNature,
    required this.onPickNature,
    required this.natureOptions,
    this.filterFavorites = false,
    this.onToggleFavorites,
    this.showSortRow = true,
    this.showFilterRow = true,
    this.showClearChip = true,
    required this.onClearAll,
  });

  bool get _hasActiveFilters =>
      filterPrismatic ||
      filterFavorites ||
      filterNature != null ||
      sizeValueText != null ||
      tintValueText != null ||
      variantValueText != null ||
      purityFilter != InstancePurityFilter.all;

  @override
  Widget build(BuildContext context) {
    final hasPotentialAnalyzer = context
        .watch<ConstellationEffectsService>()
        .hasPotentialAnalyzer();
    final filterChips = <Widget>[
      if (showClearChip && _hasActiveFilters) _ClearChip(onTap: onClearAll),

      if (!harvestMode) ...[
        _CycleChip(
          icon: Icons.science_rounded,
          labelWhenAny: 'VARIANT',
          valueText: variantValueText?.toUpperCase(),
          onTap: onCycleVariant,
        ),
        _CycleChip(
          icon: Icons.straighten_rounded,
          labelWhenAny: 'SIZE',
          valueText: sizeValueText?.toUpperCase(),
          onTap: onCycleSize,
        ),
        _CycleChip(
          icon: Icons.palette_outlined,
          labelWhenAny: 'TINT',
          valueText: tintValueText?.toUpperCase(),
          onTap: onCycleTint,
        ),
        _CycleChip(
          icon: Icons.verified_rounded,
          labelWhenAny: 'PURITY',
          valueText: purityFilter.chipValueText,
          onTap: onCyclePurity,
        ),
      ] else ...[
        _CycleChip(
          icon: Icons.straighten_rounded,
          labelWhenAny: 'SIZE',
          valueText: sizeValueText?.toUpperCase(),
          onTap: onCycleSize,
        ),
        _CycleChip(
          icon: Icons.verified_rounded,
          labelWhenAny: 'PURITY',
          valueText: purityFilter.chipValueText,
          onTap: onCyclePurity,
        ),
      ],

      _PickerChip(
        icon: Icons.psychology_rounded,
        label: 'NATURE',
        value: filterNature != null
            ? (natureOptions[filterNature] ?? filterNature!)
            : null,
        onTap: () async {
          final newVal = await pickFromList(
            context,
            theme,
            title: 'Nature',
            optionsMap: natureOptions,
            current: filterNature,
          );
          if (newVal == '_clear_') {
            onPickNature(null);
          } else if (newVal != null) {
            onPickNature(newVal);
          }
        },
      ),

      _ToggleChip(
        icon: Icons.auto_awesome_rounded,
        label: 'PRISMATIC',
        active: filterPrismatic,
        activeColor: const Color(0xFFE879F9), // purple for prismatic
        onTap: onTogglePrismatic,
      ),

      if (onToggleFavorites != null)
        _ToggleChip(
          icon: Icons.star_rounded,
          label: 'FAVORITES',
          active: filterFavorites,
          activeColor: const Color(0xFFE91E8C),
          onTap: onToggleFavorites!,
        ),
    ];

    return Column(
      children: [
        if (showSortRow)
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _SortChip(
                  label: 'NEWEST',
                  selected: sortBy == SortBy.newest,
                  onTap: () => onSortChanged(SortBy.newest),
                ),
                const SizedBox(width: 6),
                _SortChip(
                  label: 'OLDEST',
                  selected: sortBy == SortBy.oldest,
                  onTap: () => onSortChanged(SortBy.oldest),
                ),
                const SizedBox(width: 6),
                _SortChip(
                  label: 'LV ↑',
                  selected: sortBy == SortBy.levelHigh,
                  onTap: () => onSortChanged(SortBy.levelHigh),
                ),
                const SizedBox(width: 6),
                _SortChip(
                  label: 'LV ↓',
                  selected: sortBy == SortBy.levelLow,
                  onTap: () => onSortChanged(SortBy.levelLow),
                ),
                const SizedBox(width: 6),
                _StatCycleChip(
                  currentStat: sortBy,
                  hasPotentialAnalyzer: hasPotentialAnalyzer,
                  onTap: () {
                    onSortChanged(
                      sortBy.nextStatSort(
                        includePotential: hasPotentialAnalyzer,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        if (showSortRow && showFilterRow) const SizedBox(height: 10),
        if (showFilterRow)
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: filterChips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) => filterChips[i],
            ),
          ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// SORT CHIPS
// ──────────────────────────────────────────────────────────────────────────────

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _BracketChip(label: label, active: selected, onTap: onTap);
  }
}

class _StatCycleChip extends StatelessWidget {
  final SortBy currentStat;
  final bool hasPotentialAnalyzer;
  final VoidCallback onTap;
  const _StatCycleChip({
    required this.currentStat,
    required this.hasPotentialAnalyzer,
    required this.onTap,
  });

  (IconData, String, Color?) _info() {
    final isStat = currentStat.isStatSort;
    if (!isStat) return (Icons.bar_chart_rounded, 'STAT', null);
    final label = '${currentStat.shortLabel} ↓';
    return switch (currentStat.statFamily) {
      'speed' => (Icons.speed, label, const Color(0xFFFDE047)),
      'intelligence' => (Icons.psychology, label, const Color(0xFFC084FC)),
      'strength' => (Icons.fitness_center, label, const Color(0xFFF87171)),
      'beauty' => (Icons.favorite, label, const Color(0xFFF9A8D4)),
      _ => (Icons.bar_chart_rounded, 'STAT', null),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final palette = BracketPalette.fromTheme(theme);
    final t = ForgeTokens(theme);
    final (icon, label, color) = _info();
    final isStat = currentStat.isStatSort;
    final iconColor = isStat
        ? t.readableAccent(color ?? theme.accentSoft)
        : palette.muted;

    return _BracketChip(
      label: label,
      active: isStat,
      activeColor: color,
      onTap: onTap,
      leading: Icon(icon, size: 12, color: iconColor),
      trailing: (hasPotentialAnalyzer && isStat && currentStat.isPotentialSort)
          ? Icon(Icons.auto_graph_rounded, size: 11, color: iconColor)
          : null,
    );
  }
}

class _CycleChip extends StatelessWidget {
  final IconData icon;
  final String labelWhenAny;
  final String? valueText;
  final VoidCallback onTap;
  const _CycleChip({
    required this.icon,
    required this.labelWhenAny,
    required this.valueText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final palette = BracketPalette.fromTheme(theme);
    final active = valueText != null;
    final iconColor = active ? bracketReadableAccent(theme) : palette.muted;
    return _BracketChip(
      label: valueText ?? labelWhenAny,
      active: active,
      onTap: onTap,
      leading: Icon(icon, size: 12, color: iconColor),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color? activeColor;
  final VoidCallback onTap;
  const _ToggleChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final palette = BracketPalette.fromTheme(theme);
    final t = ForgeTokens(theme);
    final accent = t.readableAccent(activeColor ?? theme.accentSoft);
    final iconColor = active ? accent : palette.muted;
    return _BracketChip(
      label: label,
      active: active,
      activeColor: activeColor,
      onTap: onTap,
      leading: Icon(icon, size: 12, color: iconColor),
    );
  }
}

class _PickerChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;
  const _PickerChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final palette = BracketPalette.fromTheme(theme);
    final active = value != null;
    final iconColor = active ? bracketReadableAccent(theme) : palette.muted;
    return _BracketChip(
      label: value?.toUpperCase() ?? '$label: ANY',
      active: active,
      onTap: onTap,
      leading: Icon(icon, size: 12, color: iconColor),
      trailing: Icon(
        Icons.keyboard_arrow_down_rounded,
        size: 12,
        color: iconColor,
      ),
    );
  }
}

class _ClearChip extends StatelessWidget {
  final VoidCallback onTap;
  const _ClearChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    return _BracketChip(
      label: 'CLEAR',
      active: true,
      activeColor: t.danger,
      onTap: onTap,
      leading: Icon(Icons.close_rounded, size: 11, color: t.danger),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// NATURE PICKER BOTTOM SHEET  (public — called from parent)
// ──────────────────────────────────────────────────────────────────────────────

Future<String?> pickFromList(
  BuildContext context,
  FactionTheme theme, {
  required String title,
  required Map<String, String> optionsMap,
  required String? current,
}) async {
  final t = ForgeTokens(theme);
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: t.bg1,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          border: Border.all(color: t.borderAccent),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 14),
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                color: t.borderAccent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    color: t.amber,
                    margin: const EdgeInsets.only(right: 8),
                  ),
                  Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: t.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // List
            Expanded(
              child: ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: optionsMap.length + (current != null ? 1 : 0),
                itemBuilder: (_, i) {
                  // Clear button pinned at bottom
                  if (current != null && i == optionsMap.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, '_clear_'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF7F1D1D,
                            ).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: t.danger.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.close_rounded,
                                color: t.danger.withValues(alpha: 0.8),
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'CLEAR FILTER',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: t.danger.withValues(alpha: 0.8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final entry = optionsMap.entries.toList()[i];
                  final isSelected = entry.key == current;

                  return GestureDetector(
                    onTap: () => Navigator.pop(ctx, entry.key),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? t.amber.withValues(alpha: 0.12)
                            : t.bg2,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: isSelected ? t.borderAccent : t.borderDim,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.value.toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: isSelected
                                    ? t.amberBright
                                    : t.textPrimary,
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_rounded,
                              color: t.amberBright,
                              size: 16,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
