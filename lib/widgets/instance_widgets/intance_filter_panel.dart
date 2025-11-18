import 'package:alchemons/database/daos/creature_dao.dart';
import 'package:flutter/material.dart';

import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/utils/faction_util.dart';

class InstanceFiltersPanel extends StatelessWidget {
  final FactionTheme theme;
  final SortBy sortBy;
  final ValueChanged<SortBy> onSortChanged;

  /// If true, use the reduced filter set (no tint/variant labels except size).
  final bool harvestMode;

  final bool filterPrismatic;
  final VoidCallback onTogglePrismatic;

  // cyclers (text already resolved for display)
  final String? sizeValueText;
  final VoidCallback onCycleSize;
  final String? tintValueText;
  final VoidCallback onCycleTint;
  final String? variantValueText;
  final VoidCallback onCycleVariant;

  // nature
  final String? filterNature;
  final ValueChanged<String?> onPickNature;
  final Map<String, String> natureOptions;

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
    required this.filterNature,
    required this.onPickNature,
    required this.natureOptions,
    required this.onClearAll,
  });

  bool get _hasActiveFilters {
    return filterPrismatic ||
        filterNature != null ||
        sizeValueText != null ||
        tintValueText != null ||
        variantValueText != null;
  }

  @override
  Widget build(BuildContext context) {
    // Build the list of filter chips once
    final List<Widget> filterChips = [
      if (_hasActiveFilters) _ClearChip(theme: theme, onTap: onClearAll),

      if (!harvestMode) ...[
        _CycleChip(
          theme: theme,
          icon: Icons.science_rounded,
          labelWhenAny: 'Variant: Any',
          valueText: variantValueText,
          onTap: onCycleVariant,
        ),
        _CycleChip(
          theme: theme,
          icon: Icons.straighten_rounded,
          labelWhenAny: 'Size: Any',
          valueText: sizeValueText,
          onTap: onCycleSize,
        ),
        _CycleChip(
          theme: theme,
          icon: Icons.palette_outlined,
          labelWhenAny: 'Tint: Any',
          valueText: tintValueText,
          onTap: onCycleTint,
        ),
      ] else ...[
        _CycleChip(
          theme: theme,
          icon: Icons.straighten_rounded,
          labelWhenAny: 'Size: Any',
          valueText: sizeValueText,
          onTap: onCycleSize,
        ),
      ],

      _FilterValueChip(
        theme: theme,
        icon: Icons.psychology_rounded,
        label: 'Nature',
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

      _FilterToggleChip(
        theme: theme,
        icon: Icons.auto_awesome_rounded,
        label: 'Prismatic',
        active: filterPrismatic,
        onTap: onTogglePrismatic,
      ),
    ];

    return Column(
      children: [
        // Sort bar
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _SortChip(
                theme: theme,
                label: 'Newest',
                selected: sortBy == SortBy.newest,
                onTap: () => onSortChanged(SortBy.newest),
              ),
              const SizedBox(width: 8),
              _SortChip(
                theme: theme,
                label: 'Oldest',
                selected: sortBy == SortBy.oldest,
                onTap: () => onSortChanged(SortBy.oldest),
              ),
              const SizedBox(width: 8),
              _SortChip(
                theme: theme,
                label: 'Level ↑',
                selected: sortBy == SortBy.levelHigh,
                onTap: () => onSortChanged(SortBy.levelHigh),
              ),
              const SizedBox(width: 8),
              _SortChip(
                theme: theme,
                label: 'Level ↓',
                selected: sortBy == SortBy.levelLow,
                onTap: () => onSortChanged(SortBy.levelLow),
              ),
              const SizedBox(width: 8),
              _StatCycleChip(
                theme: theme,
                currentStat: sortBy,
                onTap: () {
                  final nextStat = switch (sortBy) {
                    SortBy.statSpeed => SortBy.statIntelligence,
                    SortBy.statIntelligence => SortBy.statStrength,
                    SortBy.statStrength => SortBy.statBeauty,
                    SortBy.statBeauty => SortBy.statSpeed,
                    _ => SortBy.statSpeed,
                  };
                  onSortChanged(nextStat);
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Filters as a horizontal scroller
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: filterChips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => filterChips[i],
          ),
        ),
      ],
    );
  }
}

// SORT CHIP
class _SortChip extends StatelessWidget {
  final FactionTheme theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({
    required this.theme,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? theme.primary.withOpacity(.18) : theme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? theme.primary.withOpacity(.5) : theme.border,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? theme.primary : theme.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

// STAT SORT CHIP (cycles stats)
class _StatCycleChip extends StatelessWidget {
  final FactionTheme theme;
  final SortBy currentStat;
  final VoidCallback onTap;

  const _StatCycleChip({
    required this.theme,
    required this.currentStat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isStatSort = currentStat.name.startsWith('stat');
    final (icon, label, color) = _getStatInfo(currentStat, isStatSort);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isStatSort ? theme.primary.withOpacity(.18) : theme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isStatSort ? theme.primary.withOpacity(.5) : theme.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isStatSort ? color : theme.text),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isStatSort ? theme.primary : theme.text,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, String, Color) _getStatInfo(SortBy stat, bool isActive) {
    if (!isActive) {
      return (Icons.bar_chart_rounded, 'Stat', Colors.blueGrey);
    }
    switch (stat) {
      case SortBy.statSpeed:
        return (Icons.speed, 'Speed ↓', Colors.yellow.shade400);
      case SortBy.statIntelligence:
        return (Icons.psychology, 'Intelligence ↓', Colors.purple.shade300);
      case SortBy.statStrength:
        return (Icons.fitness_center, 'Strength ↓', Colors.red.shade400);
      case SortBy.statBeauty:
        return (Icons.favorite, 'Beauty ↓', Colors.pink.shade300);
      default:
        return (Icons.bar_chart_rounded, 'Stat', Colors.blueGrey);
    }
  }
}

// Cycle chip (size/tint/variant)
class _CycleChip extends StatelessWidget {
  final FactionTheme theme;
  final IconData icon;
  final String labelWhenAny;
  final String? valueText;
  final VoidCallback onTap;

  const _CycleChip({
    required this.theme,
    required this.icon,
    required this.labelWhenAny,
    required this.valueText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool active = valueText != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? theme.primary.withOpacity(.18) : theme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? theme.primary.withOpacity(.5) : theme.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? theme.primary : theme.text),
            const SizedBox(width: 6),
            Text(
              valueText ?? labelWhenAny,
              style: TextStyle(
                color: active ? theme.primary : theme.text,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Toggle chip (e.g. prismatic)
class _FilterToggleChip extends StatelessWidget {
  final FactionTheme theme;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterToggleChip({
    required this.theme,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? theme.primary.withOpacity(.18) : theme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? theme.primary.withOpacity(.5) : theme.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? theme.primary : theme.text),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? theme.primary : theme.text,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Value chip (with bottom sheet picker)
class _FilterValueChip extends StatelessWidget {
  final FactionTheme theme;
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _FilterValueChip({
    required this.theme,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool active = value != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? theme.primary.withOpacity(.18) : theme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? theme.primary.withOpacity(.5) : theme.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? theme.primary : theme.text),
            const SizedBox(width: 6),
            Text(
              value ?? '$label: Any',
              style: TextStyle(
                color: active ? theme.primary : theme.text,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: active ? theme.primary.withOpacity(.6) : theme.text,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClearChip extends StatelessWidget {
  final FactionTheme theme;
  final VoidCallback onTap;

  const _ClearChip({required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withOpacity(.4), width: 1.5),
        ),
        child: Text(
          'Clear',
          style: TextStyle(
            color: Colors.red.shade300,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

// Shared picker for nature / other lists
Future<String?> pickFromList(
  BuildContext context,
  FactionTheme theme, {
  required String title,
  required Map<String, String> optionsMap,
  required String? current,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (ctx, scroll) {
          return Container(
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border.all(color: theme.border, width: 2),
              boxShadow: [
                BoxShadow(
                  color: theme.accent.withOpacity(.4),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      controller: scroll,
                      itemCount: optionsMap.length,
                      itemBuilder: (_, i) {
                        final entry = optionsMap.entries.toList()[i];
                        final id = entry.key;
                        final display = entry.value;
                        final isSelected = id == current;

                        return GestureDetector(
                          onTap: () => Navigator.pop(ctx, id),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.primary.withOpacity(.15)
                                  : theme.surfaceAlt,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? theme.primary.withOpacity(.4)
                                    : theme.border,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    display,
                                    style: TextStyle(
                                      color: isSelected
                                          ? theme.primary
                                          : theme.text,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_rounded,
                                    color: theme.primary,
                                    size: 18,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (current != null) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx, '_clear_'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.red.withOpacity(.4),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.clear_rounded,
                              color: Colors.red.shade300,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Clear Filter',
                              style: TextStyle(
                                color: Colors.red.shade300,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
