import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/screens/creatures_screen.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/utils/creature_filter_util.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_image.dart';
import 'package:alchemons/widgets/stamina_bar.dart';

// ------------------------------------
// VIEW MODES
// ------------------------------------
enum InstanceDetailMode { stats, genetics }

class CreatureSelectionSheet extends StatefulWidget {
  final List<CreatureEntry> discoveredCreatures;
  final Function(String creatureId) onSelectCreature;

  final ScrollController? scrollController;
  final String? title;
  final bool showViewToggle;
  final String? emptyStateMessage;
  final Widget? customHeader;

  final bool isInstanceMode;
  final InstanceDetailMode initialDetailMode;

  // NEW: filter options
  final bool
  showOnlyAvailableTypes; // only show types that exist in discoveredCreatures
  final bool showSearch;

  const CreatureSelectionSheet({
    super.key,
    required this.discoveredCreatures,
    required this.onSelectCreature,
    this.scrollController,
    this.title,
    this.showViewToggle = true,
    this.emptyStateMessage,
    this.customHeader,
    this.isInstanceMode = false,
    this.initialDetailMode = InstanceDetailMode.stats,
    this.showOnlyAvailableTypes = false,
    this.showSearch = true,
  });

  @override
  State<CreatureSelectionSheet> createState() => _CreatureSelectionSheetState();

  /// Convenience static launcher
  static Future<T?> show<T>({
    required BuildContext context,
    required List<CreatureEntry> discoveredCreatures,
    required Function(String) onSelectCreature,
    String? title,
    bool showViewToggle = true,
    String? emptyStateMessage,
    Widget? customHeader,
    bool isScrollControlled = true,
    bool isInstanceMode = false,
    InstanceDetailMode initialDetailMode = InstanceDetailMode.stats,
    bool showOnlyAvailableTypes = false,
    bool showSearch = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return CreatureSelectionSheet(
              discoveredCreatures: discoveredCreatures,
              onSelectCreature: onSelectCreature,
              scrollController: scrollController,
              title: title,
              showViewToggle: showViewToggle,
              emptyStateMessage: emptyStateMessage,
              customHeader: customHeader,
              isInstanceMode: isInstanceMode,
              initialDetailMode: initialDetailMode,
              showOnlyAvailableTypes: showOnlyAvailableTypes,
              showSearch: showSearch,
            );
          },
        );
      },
    );
  }
}

class _CreatureSelectionSheetState extends State<CreatureSelectionSheet> {
  String _selectedFilter = 'All';
  String _selectedSort = 'Name';
  bool _isGridView = true;
  String _searchQuery = ''; // NEW
  final _searchController = TextEditingController(); // NEW

  late InstanceDetailMode _detailMode;

  @override
  void initState() {
    super.initState();
    _detailMode = widget.initialDetailMode;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();

    final filteredCreatures = _filterAndSortCreatures(
      widget.discoveredCreatures,
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.textMuted, width: 1),
          color: theme.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            _DragHandle(theme: theme),
            const SizedBox(height: 8),
            widget.customHeader ??
                _DefaultHeader(
                  title: widget.title ?? 'Select Specimen',
                  showViewToggle: widget.showViewToggle,
                  isGridView: _isGridView,
                  onToggleView: () =>
                      setState(() => _isGridView = !_isGridView),
                  theme: theme,
                  showDetailModeToggle: widget.isInstanceMode,
                  detailMode: _detailMode,
                  onToggleDetailMode: () {
                    setState(() {
                      _detailMode = _detailMode == InstanceDetailMode.stats
                          ? InstanceDetailMode.genetics
                          : InstanceDetailMode.stats;
                    });
                  },
                  selectedSort: !widget.isInstanceMode ? _selectedSort : null,
                  onSortChanged: !widget.isInstanceMode
                      ? (val) => setState(() => _selectedSort = val)
                      : null,
                ),
            const SizedBox(height: 8),

            // Search bar
            if (widget.showSearch) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.border.withOpacity(.5),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: theme.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(
                            color: theme.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintText: 'Search specimens...',
                            hintStyle: TextStyle(
                              color: theme.textMuted.withOpacity(.6),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                          child: Icon(
                            Icons.clear_rounded,
                            size: 18,
                            color: theme.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Type filter chips (hide in instance mode)
            if (!widget.isInstanceMode)
              _FilterSortRow(
                selectedFilter: _selectedFilter,
                onFilterChanged: (val) => setState(() => _selectedFilter = val),
                theme: theme,
                availableTypes: _getAvailableTypes(),
                showOnlyAvailableTypes: widget.showOnlyAvailableTypes,
              ),

            if (!widget.isInstanceMode) const SizedBox(height: 12),

            Expanded(
              child: _isGridView
                  ? _CreatureGrid(
                      creatures: filteredCreatures,
                      onSelectCreature: widget.onSelectCreature,
                      scrollController: widget.scrollController,
                      theme: theme,
                      emptyStateMessage: widget.emptyStateMessage,
                      isInstanceMode: widget.isInstanceMode,
                      detailMode: _detailMode,
                    )
                  : _CreatureList(
                      creatures: filteredCreatures,
                      onSelectCreature: widget.onSelectCreature,
                      scrollController: widget.scrollController,
                      theme: theme,
                      emptyStateMessage: widget.emptyStateMessage,
                      isInstanceMode: widget.isInstanceMode,
                      detailMode: _detailMode,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Get available types from discovered creatures
  Set<String> _getAvailableTypes() {
    final types = <String>{'All'}; // Always include 'All'

    for (final data in widget.discoveredCreatures) {
      final creature = data.creature;
      types.addAll(creature.types);
    }

    return types;
  }

  List<CreatureEntry> _filterAndSortCreatures(List<CreatureEntry> creatures) {
    // If we're in instance mode, do NOT filter/sort by species filters
    if (widget.isInstanceMode) {
      // Still apply search in instance mode
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        creatures = creatures.where((data) {
          final c = data.creature;

          // Search by creature name
          if (c.name.toLowerCase().contains(query)) return true;

          return false;
        }).toList();
      }
      return creatures;
    }

    // species mode - apply search
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      creatures = creatures.where((data) {
        final c = data.creature;
        return c.name.toLowerCase().contains(query) ||
            c.types.any((t) => t.toLowerCase().contains(query)) ||
            c.rarity.toLowerCase().contains(query);
      }).toList();
    }

    // Filter by type
    var filtered = creatures.where((creatureData) {
      final c = creatureData.creature;
      if (_selectedFilter == 'All') return true;
      return c.types.contains(_selectedFilter);
    }).toList();

    // Sort
    filtered.sort((a, b) {
      final A = a.creature;
      final B = b.creature;
      switch (_selectedSort) {
        case 'Rarity':
          return CreatureFilterUtils.getRarityOrder(
            A.rarity,
          ).compareTo(CreatureFilterUtils.getRarityOrder(B.rarity));
        case 'Type':
          return A.types.first.compareTo(B.types.first);
        case 'Name':
        default:
          return A.name.compareTo(B.name);
      }
    });

    return filtered;
  }
}
// ======================= DRAG HANDLE =======================

class _DragHandle extends StatelessWidget {
  final FactionTheme theme;
  const _DragHandle({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: theme.text.withOpacity(.25),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ======================= HEADER =======================

class _DefaultHeader extends StatelessWidget {
  final String title;
  final bool showViewToggle;
  final bool isGridView;
  final VoidCallback onToggleView;
  final FactionTheme theme;

  final bool showDetailModeToggle;
  final InstanceDetailMode detailMode;
  final VoidCallback onToggleDetailMode;

  // Sort parameters
  final String? selectedSort;
  final ValueChanged<String>? onSortChanged;

  const _DefaultHeader({
    required this.title,
    required this.showViewToggle,
    required this.isGridView,
    required this.onToggleView,
    required this.theme,
    this.showDetailModeToggle = false,
    this.detailMode = InstanceDetailMode.stats,
    this.onToggleDetailMode = _noop,
    this.selectedSort,
    this.onSortChanged,
  });

  static void _noop() {}

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // text block
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Research database',
                    style: TextStyle(
                      color: theme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Sort toggle button (if provided)
            if (selectedSort != null && onSortChanged != null)
              GestureDetector(
                onTap: () => _cycleSort(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: theme.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.accent),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sort_rounded, size: 14, color: theme.accent),
                      const SizedBox(width: 4),
                      Text(
                        selectedSort!,
                        style: TextStyle(
                          color: theme.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // STATS / GENETICS toggle pill
            if (showDetailModeToggle)
              GestureDetector(
                onTap: onToggleDetailMode,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: theme.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.accent),
                  ),
                  child: Text(
                    detailMode == InstanceDetailMode.stats
                        ? 'STATS'
                        : 'GENETICS',
                    style: TextStyle(
                      color: theme.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .5,
                    ),
                  ),
                ),
              ),

            // grid/list toggle
            if (showViewToggle)
              GestureDetector(
                onTap: onToggleView,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    isGridView
                        ? Icons.view_list_rounded
                        : Icons.grid_view_rounded,
                    color: theme.accent,
                    size: 24,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _cycleSort() {
    final sortOptions = ['Name', 'Rarity', 'Type'];
    final currentIndex = sortOptions.indexOf(selectedSort!);
    final nextIndex = (currentIndex + 1) % sortOptions.length;
    onSortChanged!(sortOptions[nextIndex]);
  }
}

// ======================= FILTER/SORT ROW =======================

class _FilterSortRow extends StatelessWidget {
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;
  final FactionTheme theme;
  final Set<String> availableTypes; // NEW
  final bool showOnlyAvailableTypes; // NEW

  const _FilterSortRow({
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.theme,
    required this.availableTypes,
    required this.showOnlyAvailableTypes,
  });

  @override
  Widget build(BuildContext context) {
    // Use only available types or all types
    final filterOptions = showOnlyAvailableTypes
        ? availableTypes.toList()
        : CreatureFilterUtils.filterOptions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 0, 8),
          child: Row(
            children: [
              Icon(Icons.filter_list_rounded, size: 14, color: theme.accent),
              const SizedBox(width: 6),
              Text(
                'TYPE',
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filterOptions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final type = filterOptions[i];
              final selected = selectedFilter == type;
              final color = type == 'All'
                  ? theme.accent
                  : BreedConstants.getTypeColor(type);

              return FilterChipSolid(
                label: type,
                color: color,
                selected: selected,
                onTap: () => onFilterChanged(type),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CreatureGrid extends StatelessWidget {
  final List<CreatureEntry> creatures;
  final Function(String) onSelectCreature;
  final ScrollController? scrollController;
  final FactionTheme theme;
  final String? emptyStateMessage;

  final bool isInstanceMode;
  final InstanceDetailMode detailMode;

  const _CreatureGrid({
    required this.creatures,
    required this.onSelectCreature,
    required this.scrollController,
    required this.theme,
    this.emptyStateMessage,
    required this.isInstanceMode,
    required this.detailMode,
  });

  @override
  Widget build(BuildContext context) {
    if (creatures.isEmpty) {
      return _EmptyState(
        theme: theme,
        message: emptyStateMessage ?? 'No specimens match current filters',
      );
    }

    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.8,
        crossAxisSpacing: 5,
        mainAxisSpacing: 5,
      ),
      itemCount: creatures.length,
      itemBuilder: (context, index) {
        final data = creatures[index];
        final c = data.creature;

        tap() => onSelectCreature((c.id));
        return _CreatureGridCard(c: c, onTap: tap, theme: theme);
      },
    );
  }
}

class _CreatureGridCard extends StatelessWidget {
  final Creature c;
  final VoidCallback onTap;
  final FactionTheme theme;

  const _CreatureGridCard({
    required this.c,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = BreedConstants.getTypeColor(c.types.first);
    final rarityColor = BreedConstants.getRarityColor(c.rarity);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: typeColor.withOpacity(.45), width: .5),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              c.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.text,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: CreatureImage(c: c, discovered: true),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              child: Text(
                c.rarity.toUpperCase(),
                style: TextStyle(
                  color: rarityColor,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Instance version of the grid card
class _InstanceGridCard extends StatelessWidget {
  final FactionTheme theme;
  final Creature creature;
  final CreatureInstance instance;
  final InstanceDetailMode detailMode;
  final VoidCallback onTap;

  const _InstanceGridCard({
    required this.theme,
    required this.creature,
    required this.instance,
    required this.detailMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // bottom text depends on mode
    final genes = decodeGenetics(instance.geneticsJson);
    final bottomText = (detailMode == InstanceDetailMode.stats)
        ? 'Lv ${instance.level}'
        : genes;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: theme.border, width: 1),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              creature.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.text,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: CreatureImage(c: creature, discovered: true),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              bottomText.toString(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _briefGenesLabel(Map<String, dynamic> genes, bool isPrismatic) {
    final parts = <String>[];
    if (isPrismatic) parts.add('Prismatic');
    if (genes['size'] != null) parts.add('Size ${genes['size']}');
    if (genes['tint'] != null) parts.add('${genes['tint']} tint');
    return parts.isEmpty ? 'Base form' : parts.join(' • ');
  }
}

// ======================= LIST MODE =======================

class _CreatureList extends StatelessWidget {
  final List<CreatureEntry> creatures;
  final Function(String) onSelectCreature;
  final ScrollController? scrollController;
  final FactionTheme theme;
  final String? emptyStateMessage;

  final bool isInstanceMode;
  final InstanceDetailMode detailMode;

  const _CreatureList({
    required this.creatures,
    required this.onSelectCreature,
    required this.scrollController,
    required this.theme,
    this.emptyStateMessage,
    required this.isInstanceMode,
    required this.detailMode,
  });

  @override
  Widget build(BuildContext context) {
    if (creatures.isEmpty) {
      return _EmptyState(
        theme: theme,
        message: emptyStateMessage ?? 'No specimens match current filters',
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      physics: const BouncingScrollPhysics(),
      itemCount: creatures.length,
      itemBuilder: (context, index) {
        final data = creatures[index];
        final c = data.creature;

        tap() => onSelectCreature((c.id));

        // species mode row:
        return _CreatureListTile(c: c, onTap: tap, theme: theme);
      },
    );
  }
}

class _CreatureListTile extends StatelessWidget {
  final Creature c;
  final VoidCallback onTap;
  final FactionTheme theme;

  const _CreatureListTile({
    required this.c,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final rarityColor = BreedConstants.getRarityColor(c.rarity);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        child: Row(
          children: [
            // image
            SizedBox(
              width: 48,
              height: 48,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: CreatureImage(c: c, discovered: true),
              ),
            ),
            const SizedBox(width: 12),

            // info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // name
                  Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // rarity chip
                      Text(
                        c.rarity.toUpperCase(),
                        style: TextStyle(
                          color: rarityColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .4,
                        ),
                      ),
                      const SizedBox(width: 6),

                      // types
                      ...c.types.take(2).map((t) {
                        final tColor = BreedConstants.getTypeColor(t);
                        return Container(
                          margin: const EdgeInsets.only(right: 4),
                          child: Text(
                            t.toUpperCase(),
                            style: TextStyle(
                              color: tColor,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .3,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================= LIST ITEM FOR INSTANCE =======================

class _InstanceListTile extends StatelessWidget {
  final FactionTheme theme;
  final Creature creature;
  final CreatureInstance instance;
  final InstanceDetailMode detailMode;
  final VoidCallback onTap;

  const _InstanceListTile({
    required this.theme,
    required this.creature,
    required this.instance,
    required this.detailMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // stats mode vs genetics mode
    final genes = decodeGenetics(instance.geneticsJson);
    final Widget subRow = detailMode == InstanceDetailMode.stats
        ? Row(
            children: [
              Text(
                'Lv ${instance.level}',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              StaminaBadge(
                instanceId: instance.instanceId,
                showCountdown: true,
              ),
            ],
          )
        : Text(
            genes.toString(),
            style: TextStyle(
              color: theme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: CreatureImage(c: creature, discovered: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    creature.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  subRow,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================= EMPTY STATE =======================

class _EmptyState extends StatelessWidget {
  final FactionTheme theme;
  final String message;
  const _EmptyState({required this.theme, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.accent.withOpacity(.4)),
                boxShadow: [
                  BoxShadow(
                    color: theme.accent.withOpacity(.16),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 40,
                color: theme.accent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No specimens found',
              style: TextStyle(
                color: theme.text,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
