// lib/widgets/instance_widgets/intance_filter_panel.dart
//
// REDESIGNED INSTANCE FILTERS PANEL
// Aesthetic: Scorched Forge — dark metal chips, amber accents, monospace
// All logic, props, and public API preserved exactly.
//

import 'package:alchemons/database/daos/creature_dao.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/utils/instance_purity_util.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/utils/faction_util.dart';

// ──────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ──────────────────────────────────────────────────────────────────────────────

TextStyle _chipLabel({
  required bool active,
  Color? activeColor,
  required ForgeTokens t,
}) {
  final displayColor = t.readableAccent(activeColor ?? t.amberBright);
  return TextStyle(
    color: active ? displayColor : t.textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
  );
}

BoxDecoration _chipBox({
  required bool active,
  Color? activeColor,
  required ForgeTokens t,
}) {
  final displayColor = t.readableAccent(activeColor ?? t.amber);
  return BoxDecoration(
    color: active
        ? displayColor.withValues(alpha: 0.08)
        : (t.isDark ? t.bg2 : Colors.white.withValues(alpha: 0.96)),
    borderRadius: BorderRadius.circular(3),
    border: Border.all(
      color: active
          ? displayColor.withValues(alpha: 0.8)
          : (t.isDark ? t.borderDim : t.borderDim.withValues(alpha: 0.9)),
      width: active ? 1.2 : 1.0,
    ),
  );
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
    final t = ForgeTokens(context.read<FactionTheme>());
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: _chipBox(active: selected, t: t),
        child: Text(
          label,
          style: _chipLabel(active: selected, t: t),
        ),
      ),
    );
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

  (IconData, String, Color) _info() {
    final isStat = currentStat.isStatSort;
    if (!isStat) {
      return (Icons.bar_chart_rounded, 'STAT', const Color(0xFF8A7B6A));
    }
    final label = '${currentStat.shortLabel} ↓';
    return switch (currentStat.statFamily) {
      'speed' => (Icons.speed, label, const Color(0xFFFDE047)),
      'intelligence' => (Icons.psychology, label, const Color(0xFFC084FC)),
      'strength' => (Icons.fitness_center, label, const Color(0xFFF87171)),
      'beauty' => (Icons.favorite, label, const Color(0xFFF9A8D4)),
      _ => (Icons.bar_chart_rounded, 'STAT', const Color(0xFF8A7B6A)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    final (icon, label, color) = _info();
    final displayColor = t.readableAccent(color);
    final isStat = currentStat.isStatSort;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: _chipBox(active: isStat, activeColor: color, t: t),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: isStat ? displayColor : t.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: _chipLabel(active: isStat, activeColor: color, t: t),
            ),
            if (hasPotentialAnalyzer && isStat && currentStat.isPotentialSort)
              Padding(
                padding: const EdgeInsets.only(left: 5),
                child: Icon(
                  Icons.auto_graph_rounded,
                  size: 11,
                  color: displayColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// FILTER CHIPS
// ──────────────────────────────────────────────────────────────────────────────

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
    final t = ForgeTokens(context.read<FactionTheme>());
    final active = valueText != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: _chipBox(active: active, t: t),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: active ? t.amberBright : t.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              valueText ?? labelWhenAny,
              style: _chipLabel(active: active, t: t),
            ),
          ],
        ),
      ),
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
    final t = ForgeTokens(context.read<FactionTheme>());
    final color = activeColor ?? t.amberBright;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: _chipBox(active: active, activeColor: color, t: t),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: active ? color : t.textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: _chipLabel(active: active, activeColor: color, t: t),
            ),
          ],
        ),
      ),
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
    final t = ForgeTokens(context.read<FactionTheme>());
    final active = value != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: _chipBox(active: active, t: t),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: active ? t.amberBright : t.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              value?.toUpperCase() ?? '$label: ANY',
              style: _chipLabel(active: active, t: t),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 12,
              color: active
                  ? t.amberBright.withValues(alpha: 0.7)
                  : t.textMuted,
            ),
          ],
        ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF7F1D1D).withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: t.danger.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.close_rounded,
              size: 11,
              color: t.danger.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 4),
            Text(
              'CLEAR',
              style: TextStyle(
                fontFamily: 'monospace',
                color: t.danger.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
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
                                  fontSize: 11,
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
