import 'dart:async' as async;
import 'dart:convert';

import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/daos/settings_dao.dart';
import 'package:alchemons/database/daos/creature_dao.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/show_quick_instance_dialog.dart';
import 'package:alchemons/widgets/creature_dialog.dart';
import 'package:alchemons/widgets/creature_instances_sheet.dart';
import 'package:alchemons/widgets/creature_selection_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/stamina_bar.dart';
import 'package:alchemons/widgets/creature_sprite.dart';

class AllCreatureInstances extends StatefulWidget {
  final FactionTheme theme;
  final List<String> selectedInstanceIds;
  final void Function(CreatureInstance inst)? onTap;
  final VoidCallback? onLongPress;

  // Selection mode support
  final bool selectionMode;
  final int maxSelections; // 0 = unlimited, positive = max
  final void Function(List<CreatureInstance>)? onConfirmSelection;

  const AllCreatureInstances({
    super.key,
    required this.theme,
    this.onTap,
    this.selectedInstanceIds = const [],
    this.onLongPress,
    this.selectionMode = false,
    this.maxSelections = 0,
    this.onConfirmSelection,
  });

  @override
  State<AllCreatureInstances> createState() => _AllCreatureInstancesState();
}

class _AllCreatureInstancesState extends State<AllCreatureInstances> {
  SortBy _sortBy = SortBy.newest;

  late TextEditingController _searchController;

  // search / filter state
  bool _filtersOpen = false;
  String _searchText = '';
  String? _filterSize;
  String? _filterTint;
  String? _filterNature;
  bool _filterPrismatic = false;
  String? _filterVariant;

  // Selection state (when in selection mode)
  final Set<String> _localSelections = {};

  // ordered cycles
  late final List<String> _sizeCycle = sizeLabels.keys.toList(growable: false);
  late final List<String> _tintCycle = tintLabels.keys.toList(growable: false);

  static const List<String> _variantGroups = [
    'Volcanic',
    'Oceanic',
    'Earthen',
    'Verdant',
    'Arcane',
  ];

  late final List<String?> _variantCycle = <String?>[
    null,
    ..._variantGroups,
    '__NON__',
  ];

  String? _cycleNextOrAny(String? current, List<String> ordered) {
    if (ordered.isEmpty) return null;
    if (current == null) return ordered.first;
    final i = ordered.indexOf(current);
    if (i < 0 || i == ordered.length - 1) return null;
    return ordered[i + 1];
  }

  String? _cycleNextVariant(String? current) {
    final i = _variantCycle.indexOf(current);
    if (i < 0 || i == _variantCycle.length - 1) return _variantCycle.first;
    return _variantCycle[i + 1];
  }

  late SettingsDao _settings;
  async.Timer? _saveTimer;
  async.Timer? _searchDebounce;

  String get _prefsKey => 'all_instances_filters';

  Map<String, dynamic> _toPrefs() => {
    'sortBy': _sortBy.name,
    'filtersOpen': _filtersOpen,
    'searchText': _searchText,
    'filterSize': _filterSize,
    'filterTint': _filterTint,
    'filterNature': _filterNature,
    'filterPrismatic': _filterPrismatic,
    'filterVariant': _filterVariant,
    'detailMode': _detailMode.name,
  };

  void _fromPrefs(Map<String, dynamic> p) {
    _sortBy = SortBy.values.firstWhere(
      (e) => e.name == (p['sortBy'] ?? _sortBy.name),
      orElse: () => SortBy.newest,
    );
    _filtersOpen = p['filtersOpen'] ?? _filtersOpen;
    _searchText = p['searchText'] ?? _searchText;
    _filterSize = p['filterSize'];
    _filterTint = p['filterTint'];
    _filterNature = p['filterNature'];
    _filterPrismatic = p['filterPrismatic'] ?? _filterPrismatic;
    _filterVariant = p['filterVariant'];
    _detailMode = InstanceDetailMode.values.firstWhere(
      (e) => e.name == (p['detailMode'] ?? _detailMode.name),
      orElse: () => InstanceDetailMode.info,
    );
  }

  void _queueSave() {
    _saveTimer?.cancel();
    _saveTimer = async.Timer(const Duration(milliseconds: 300), () async {
      await _settings.setSetting(_prefsKey, jsonEncode(_toPrefs()));
    });
  }

  void _mutate(VoidCallback fn) {
    setState(fn);
    _queueSave();
  }

  late InstanceDetailMode _detailMode;

  @override
  void initState() {
    super.initState();
    _detailMode = InstanceDetailMode.info;
    _searchController = TextEditingController();
    // Initialize with passed selections only when in selection mode
    if (widget.selectionMode) {
      _localSelections.addAll(widget.selectedInstanceIds);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _settings = context.read<AlchemonsDatabase>().settingsDao;
    _refreshAllStamina();
    () async {
      final raw = await _settings.getSetting(_prefsKey);
      if (!mounted || raw == null || raw.isEmpty) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      setState(() => _fromPrefs(map));
      if (mounted) {
        _searchController.text = _searchText;
      }
    }();
  }

  Future<void> _refreshAllStamina() async {
    final stamina = context.read<StaminaService>();
    final db = context.read<AlchemonsDatabase>();

    final instances = await db.creatureDao.getAllInstances();
    for (final inst in instances) {
      await stamina.refreshAndGet(inst.instanceId);
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Map<String, String> _buildNatureOptions() {
    final Map<String, String> out = {};
    for (final def in NatureCatalog.all) {
      final String id = def.id;
      final String display = id.toUpperCase();
      out[id] = display;
    }
    final sorted = out.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return Map<String, String>.fromEntries(sorted);
  }

  void _handleInstanceTap(CreatureInstance inst) {
    if (widget.selectionMode) {
      setState(() {
        if (_localSelections.contains(inst.instanceId)) {
          _localSelections.remove(inst.instanceId);
        } else {
          // Check max selections
          if (widget.maxSelections > 0 &&
              _localSelections.length >= widget.maxSelections) {
            // Remove first selection (FIFO)
            _localSelections.remove(_localSelections.first);
          }
          _localSelections.add(inst.instanceId);
        }
      });
    } else if (widget.onTap != null) {
      widget.onTap!(inst);
    }
  }

  // NEW: Client-side filtering for size/tint (requires genetics parsing)
  List<CreatureInstance> _applyClientSideFilters(
    List<CreatureInstance> instances,
  ) {
    if (_filterSize == null && _filterTint == null) {
      return instances;
    }

    return instances.where((inst) {
      final g = decodeGenetics(inst.geneticsJson);
      final sizeGene = g?.get('size');
      final tintGene = g?.get('tinting');

      if (_filterSize != null && sizeGene != _filterSize) return false;
      if (_filterTint != null && tintGene != _filterTint) return false;

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();

    return StreamBuilder<List<CreatureInstance>>(
      // **OPTIMIZED: Use database-level filtering**
      stream: db.creatureDao.watchFilteredInstances(
        searchText: _searchText.trim().isEmpty ? null : _searchText.trim(),
        filterNature: _filterNature,
        filterPrismatic: _filterPrismatic,
        filterVariant: _filterVariant,
        sortBy: _sortBy,
      ),
      initialData: const [],
      builder: (context, snapshot) {
        var instances = snapshot.data ?? [];

        // Apply client-side filters for genetics (size/tint)
        instances = _applyClientSideFilters(instances);

        final hasFiltersActive =
            _filterPrismatic ||
            _filterVariant != null ||
            _filterSize != null ||
            _filterTint != null ||
            _filterNature != null ||
            _searchText.trim().isNotEmpty ||
            _sortBy != SortBy.newest;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Selection mode header with confirm button
            if (widget.selectionMode) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: widget.theme.surfaceAlt,
                  border: Border(
                    bottom: BorderSide(color: widget.theme.border, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _localSelections.isEmpty
                            ? 'Select specimens'
                            : '${_localSelections.length} selected${widget.maxSelections > 0 ? " / ${widget.maxSelections}" : ""}',
                        style: TextStyle(
                          color: widget.theme.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_localSelections.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          if (widget.onConfirmSelection != null) {
                            final selected = instances
                                .where(
                                  (i) =>
                                      _localSelections.contains(i.instanceId),
                                )
                                .toList();
                            widget.onConfirmSelection!(selected);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: widget.theme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Confirm',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Search and filters bar
            Container(
              padding: const EdgeInsets.only(
                left: 12,
                right: 12,
                top: 9,
                bottom: 3,
              ),
              child: Row(
                children: [
                  // Search box with debounce
                  Expanded(
                    child: Container(
                      height: 34,
                      decoration: BoxDecoration(
                        color: widget.theme.surfaceAlt,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: widget.theme.text.withOpacity(.35),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 14,
                            color: widget.theme.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: TextStyle(
                                color: widget.theme.text,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                isCollapsed: true,
                                border: InputBorder.none,
                                hintText: 'Search all specimens...',
                                hintStyle: TextStyle(
                                  color: widget.theme.textMuted.withOpacity(.6),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              onChanged: (val) {
                                // **OPTIMIZED: Debounce search**
                                _searchDebounce?.cancel();
                                _searchDebounce = async.Timer(
                                  const Duration(milliseconds: 300),
                                  () => _mutate(() => _searchText = val),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Detail mode toggle
                  GestureDetector(
                    onTap: () => _mutate(() {
                      _detailMode = switch (_detailMode) {
                        InstanceDetailMode.info => InstanceDetailMode.stats,
                        InstanceDetailMode.stats => InstanceDetailMode.genetics,
                        InstanceDetailMode.genetics => InstanceDetailMode.info,
                      };
                    }),
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: widget.theme.primary.withOpacity(.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: widget.theme.primary.withOpacity(.5),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _detailMode == InstanceDetailMode.info
                              ? 'INFO'
                              : _detailMode == InstanceDetailMode.stats
                              ? 'STATS'
                              : 'GENETICS',
                          style: TextStyle(
                            color: widget.theme.text,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .5,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Filters pill
                  GestureDetector(
                    onTap: () => _mutate(() {
                      _filtersOpen = !_filtersOpen;
                    }),
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: hasFiltersActive
                            ? widget.theme.primary.withOpacity(.18)
                            : widget.theme.surfaceAlt,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: hasFiltersActive
                              ? widget.theme.primary.withOpacity(.5)
                              : widget.theme.text.withOpacity(.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.filter_list_rounded,
                            size: 14,
                            color: hasFiltersActive
                                ? widget.theme.primary
                                : widget.theme.text,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Filters',
                            style: TextStyle(
                              color: hasFiltersActive
                                  ? widget.theme.primary
                                  : widget.theme.text,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _filtersOpen
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: hasFiltersActive
                                ? widget.theme.primary
                                : widget.theme.text,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Filter panel
            if (_filtersOpen) ...[
              const SizedBox(height: 10),
              _FiltersPanel(
                theme: widget.theme,
                sortBy: _sortBy,
                onSortChanged: (s) => _mutate(() => _sortBy = s),
                filterPrismatic: _filterPrismatic,
                onTogglePrismatic: () =>
                    _mutate(() => _filterPrismatic = !_filterPrismatic),
                sizeValueText: _filterSize == null
                    ? null
                    : (sizeLabels[_filterSize] ?? _filterSize!),
                onCycleSize: () => _mutate(
                  () => _filterSize = _cycleNextOrAny(_filterSize, _sizeCycle),
                ),
                tintValueText: _filterTint == null
                    ? null
                    : (tintLabels[_filterTint] ?? _filterTint!),
                onCycleTint: () => _mutate(
                  () => _filterTint = _cycleNextOrAny(_filterTint, _tintCycle),
                ),
                variantValueText: () {
                  if (_filterVariant == null) return null;
                  if (_filterVariant == '__NON__') return 'None';
                  return _filterVariant;
                }(),
                onCycleVariant: () => _mutate(
                  () => _filterVariant = _cycleNextVariant(_filterVariant),
                ),
                filterNature: _filterNature,
                onPickNature: (val) => _mutate(() => _filterNature = val),
                natureOptions: _buildNatureOptions(),
                onClearAll: () => _mutate(() {
                  _filterPrismatic = false;
                  _filterVariant = null;
                  _filterSize = null;
                  _filterTint = null;
                  _filterNature = null;
                  _searchText = '';
                  _searchController.clear();
                  _sortBy = SortBy.newest;
                }),
              ),
            ],

            const SizedBox(height: 12),

            // Grid of instances
            Expanded(
              child: instances.isEmpty
                  ? _EmptyState(
                      primaryColor: widget.theme.primary,
                      hasFilters: hasFiltersActive,
                    )
                  : GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(5, 0, 5, 24),
                      itemCount: instances.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemBuilder: (_, i) {
                        final inst = instances[i];
                        final creature = repo.getCreatureById(inst.baseId);
                        if (creature == null) return const SizedBox.shrink();

                        // Decide where selection comes from
                        final List<String> orderedSelectionIds =
                            widget.selectionMode
                            ? _localSelections.toList()
                            : widget.selectedInstanceIds;

                        // For quick membership check
                        final selectedSet = orderedSelectionIds.toSet();

                        final isSelected = selectedSet.contains(
                          inst.instanceId,
                        );

                        int? selectionNumber;
                        final index = orderedSelectionIds.indexOf(
                          inst.instanceId,
                        );
                        if (index >= 0 && index < 3) {
                          selectionNumber = index + 1;
                        }

                        // **OPTIMIZED: Wrap in RepaintBoundary**
                        return RepaintBoundary(
                          child: _InstanceCard(
                            key: ValueKey(inst.instanceId),
                            species: creature,
                            instance: inst,
                            isSelected: isSelected,
                            selectionNumber: selectionNumber,
                            theme: widget.theme,
                            detailMode: _detailMode,
                            onTap: () => _handleInstanceTap(inst),
                            onLongPress: () {
                              if (!widget.selectionMode) {
                                showQuickInstanceDialog(
                                  context: context,
                                  theme: widget.theme,
                                  creature: creature,
                                  instance: inst,
                                );
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _FiltersPanel extends StatelessWidget {
  final FactionTheme theme;
  final SortBy sortBy;
  final ValueChanged<SortBy> onSortChanged;
  final bool filterPrismatic;
  final VoidCallback onTogglePrismatic;
  final String? sizeValueText;
  final VoidCallback onCycleSize;
  final String? tintValueText;
  final VoidCallback onCycleTint;
  final String? variantValueText;
  final VoidCallback onCycleVariant;
  final String? filterNature;
  final ValueChanged<String?> onPickNature;
  final Map<String, String> natureOptions;
  final VoidCallback onClearAll;

  const _FiltersPanel({
    required this.theme,
    required this.sortBy,
    required this.onSortChanged,
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.border, width: 1),
          bottom: BorderSide(color: theme.border, width: 1),
        ),
        color: theme.surfaceAlt.withOpacity(.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sort section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  Icons.sort_rounded,
                  color: theme.primary.withOpacity(.8),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'SORT',
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
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
                      SortBy.statBeauty => SortBy.newest,
                      _ => SortBy.statSpeed,
                    };
                    onSortChanged(nextStat);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Filters section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  Icons.filter_list_rounded,
                  color: theme.primary.withOpacity(.8),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'FILTERS',
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _FilterChip(
                  theme: theme,
                  icon: Icons.auto_awesome,
                  label: 'Prismatic',
                  active: filterPrismatic,
                  onTap: onTogglePrismatic,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  theme: theme,
                  icon: Icons.straighten_rounded,
                  label: sizeValueText ?? 'Size',
                  active: sizeValueText != null,
                  onTap: onCycleSize,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  theme: theme,
                  icon: Icons.palette_outlined,
                  label: tintValueText ?? 'Tint',
                  active: tintValueText != null,
                  onTap: onCycleTint,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  theme: theme,
                  icon: Icons.science_rounded,
                  label: variantValueText ?? 'Variant',
                  active: variantValueText != null,
                  onTap: onCycleVariant,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  theme: theme,
                  icon: Icons.psychology_rounded,
                  label: filterNature != null
                      ? (natureOptions[filterNature] ?? filterNature!)
                      : 'Nature',
                  active: filterNature != null,
                  showDropdown: true,
                  onTap: () async {
                    final newVal = await _pickFromList(
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
                const SizedBox(width: 8),
                _ClearChip(theme: theme, onTap: onClearAll),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Modern sort chip matching creatures screen style
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

// Modern filter chip with icon
class _FilterChip extends StatelessWidget {
  final FactionTheme theme;
  final IconData icon;
  final String label;
  final bool active;
  final bool showDropdown;
  final VoidCallback onTap;

  const _FilterChip({
    required this.theme,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.showDropdown = false,
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
            if (showDropdown) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: active ? theme.primary : theme.text,
              ),
            ],
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withOpacity(.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.clear_rounded, size: 14, color: Colors.red.shade300),
            const SizedBox(width: 6),
            Text(
              'Clear All',
              style: TextStyle(
                color: Colors.red.shade300,
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

// Stat cycle chip for sorting by stats
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
    final isStatSort =
        currentStat == SortBy.statSpeed ||
        currentStat == SortBy.statIntelligence ||
        currentStat == SortBy.statStrength ||
        currentStat == SortBy.statBeauty;

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
      return (Icons.bar_chart_rounded, 'Stat', theme.text);
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
        return (Icons.bar_chart_rounded, 'Stat', theme.text);
    }
  }
}

Future<String?> _pickFromList(
  BuildContext context,
  FactionTheme theme, {
  required String title,
  required Map<String, String> optionsMap,
  required String? current,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    showDragHandle: false,
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
                  blurRadius: 28,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(.8),
                  blurRadius: 40,
                  spreadRadius: 16,
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  decoration: BoxDecoration(
                    color: theme.surfaceAlt,
                    border: Border(
                      bottom: BorderSide(color: theme.border, width: 1.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title.toUpperCase(),
                          style: TextStyle(
                            color: theme.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .6,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Icon(
                          Icons.close_rounded,
                          color: theme.textMuted,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scroll,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      ...optionsMap.entries.map((entry) {
                        final key = entry.key;
                        final label = entry.value;
                        final isSelected = current == key;

                        return GestureDetector(
                          onTap: () => Navigator.pop(ctx, key),
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
                                    ? theme.primary.withOpacity(.5)
                                    : theme.border,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    label,
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
                      }),
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
              ],
            ),
          );
        },
      );
    },
  );
}

class _EmptyState extends StatelessWidget {
  final Color primaryColor;
  final bool hasFilters;

  const _EmptyState({required this.primaryColor, this.hasFilters = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(.15)),
              ),
              child: Icon(
                hasFilters ? Icons.search_off_rounded : Icons.science_outlined,
                size: 48,
                color: primaryColor.withOpacity(.6),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              hasFilters ? 'No matching specimens' : 'No specimens contained',
              style: const TextStyle(
                color: Color(0xFFE8EAED),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters
                  ? 'Try adjusting filters'
                  : 'Acquire specimens through genetic synthesis\nor field research operations',
              style: const TextStyle(
                color: Color(0xFFB6C0CC),
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

// **OPTIMIZED: Removed fade animation, added RepaintBoundary in parent**
class _InstanceCard extends StatelessWidget {
  final Creature species;
  final CreatureInstance instance;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isSelected;
  final int? selectionNumber;
  final FactionTheme theme;
  final InstanceDetailMode detailMode;

  const _InstanceCard({
    super.key,
    required this.species,
    required this.instance,
    required this.onTap,
    required this.onLongPress,
    required this.theme,
    required this.detailMode,
    this.isSelected = false,
    this.selectionNumber,
  });

  @override
  Widget build(BuildContext context) {
    final genetics = decodeGenetics(instance.geneticsJson);

    final Widget bottomBlock = switch (detailMode) {
      InstanceDetailMode.info => _InfoBlock(
        theme: theme,
        instance: instance,
        isSelected: isSelected,
        selectionNumber: selectionNumber,
        creatureName: species.name,
      ),
      InstanceDetailMode.stats => _StatsBlock(
        theme: theme,
        instance: instance,
        isSelected: isSelected,
        selectionNumber: selectionNumber,
      ),
      InstanceDetailMode.genetics => _GeneticsBlock(
        theme: theme,
        instance: instance,
        genetics: genetics,
        isSelected: isSelected,
        selectionNumber: selectionNumber,
      ),
    };

    Color borderColor = isSelected
        ? selectionNumber == 1
              ? theme.accent
              : selectionNumber == 2
              ? Colors.blueAccent
              : Colors.purpleAccent
        : theme.textMuted.withOpacity(.3);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.green.withOpacity(.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: borderColor, width: isSelected ? 2.5 : .3),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Center(
                        // **OPTIMIZED: Wrap sprite in RepaintBoundary**
                        child: RepaintBoundary(
                          child: species.spriteData != null
                              ? InstanceSprite(
                                  creature: species,
                                  instance: instance,
                                  size: 72,
                                )
                              : Image.asset(species.image, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                    if (isSelected && selectionNumber != null)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.merge_type_rounded,
                                color: Colors.white,
                                size: 10,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '$selectionNumber',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              if (detailMode == InstanceDetailMode.genetics)
                StaminaBadge(
                  instanceId: instance.instanceId,
                  showCountdown: true,
                )
              else
                const SizedBox.shrink(),
              if (detailMode == InstanceDetailMode.genetics)
                const SizedBox(height: 6),
              bottomBlock,
            ],
          ),
        ),
      ),
    );
  }
}

// Info block
class _InfoBlock extends StatelessWidget {
  final FactionTheme theme;
  final CreatureInstance instance;
  final bool isSelected;
  final int? selectionNumber;
  final String creatureName;

  const _InfoBlock({
    required this.theme,
    required this.instance,
    required this.isSelected,
    required this.selectionNumber,
    required this.creatureName,
  });

  @override
  Widget build(BuildContext context) {
    final hasNick =
        (instance.nickname != null && instance.nickname!.trim().isNotEmpty);
    final nick = hasNick ? instance.nickname!.trim() : creatureName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isSelected && selectionNumber != null) ...[
          _ParentChip(selectionNumber: selectionNumber),
          const SizedBox(height: 4),
        ],
        Row(
          children: [
            Icon(
              instance.locked ? Icons.lock_rounded : Icons.lock_open_rounded,
              size: 12,
              color: instance.locked ? theme.primary : theme.textMuted,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                nick,
                style: TextStyle(
                  color: theme.text,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        StaminaBadge(instanceId: instance.instanceId, showCountdown: true),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.stars_rounded, size: 12, color: Colors.green.shade400),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Lv ${instance.level}',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (instance.isPrismaticSkin == true) ...[
          const SizedBox(height: 4),
          const _PrismaticChip(),
        ],
      ],
    );
  }
}

// Stats block
class _StatsBlock extends StatelessWidget {
  final FactionTheme theme;
  final CreatureInstance instance;
  final bool isSelected;
  final int? selectionNumber;

  const _StatsBlock({
    required this.theme,
    required this.instance,
    required this.isSelected,
    required this.selectionNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isSelected && selectionNumber != null) ...[
          _ParentChip(selectionNumber: selectionNumber),
          const SizedBox(height: 4),
        ],
        Row(
          children: [
            Icon(Icons.stars_rounded, size: 12, color: Colors.green.shade400),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Lv ${instance.level}  •  ${instance.xp} XP',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        _StatRow(
          icon: Icons.speed,
          color: Colors.yellow.shade400,
          label: 'Speed',
          value: instance.statSpeed,
          theme: theme,
        ),
        const SizedBox(height: 2),
        _StatRow(
          icon: Icons.psychology,
          color: Colors.purple.shade300,
          label: 'Intelligence',
          value: instance.statIntelligence,
          theme: theme,
        ),
        const SizedBox(height: 2),
        _StatRow(
          icon: Icons.fitness_center,
          color: Colors.red.shade400,
          label: 'Strength',
          value: instance.statStrength,
          theme: theme,
        ),
        const SizedBox(height: 2),
        _StatRow(
          icon: Icons.favorite,
          color: Colors.pink.shade300,
          label: 'Beauty',
          value: instance.statBeauty,
          theme: theme,
        ),
        if (instance.isPrismaticSkin == true) ...[
          const SizedBox(height: 4),
          const _PrismaticChip(),
        ],
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final double value;
  final FactionTheme theme;

  const _StatRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '$label: ${value.toStringAsFixed(1)}',
            style: TextStyle(
              color: theme.text,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// Genetics block
class _GeneticsBlock extends StatelessWidget {
  final FactionTheme theme;
  final CreatureInstance instance;
  final Genetics? genetics;
  final bool isSelected;
  final int? selectionNumber;

  const _GeneticsBlock({
    required this.theme,
    required this.instance,
    required this.genetics,
    required this.isSelected,
    required this.selectionNumber,
  });

  String _getSizeName() =>
      sizeLabels[genetics?.get('size') ?? 'normal'] ?? 'Standard';

  String _getTintName() =>
      tintLabels[genetics?.get('tinting') ?? 'normal'] ?? 'Standard';

  IconData _getSizeIcon() =>
      sizeIcons[genetics?.get('size') ?? 'normal'] ?? Icons.circle;

  IconData _getTintIcon() =>
      tintIcons[genetics?.get('tinting') ?? 'normal'] ?? Icons.palette_outlined;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isSelected && selectionNumber != null) ...[
          _ParentChip(selectionNumber: selectionNumber),
          const SizedBox(height: 4),
        ],
        if (instance.isPrismaticSkin == true) ...[
          const _PrismaticChip(),
          const SizedBox(height: 4),
        ],
        _InfoRow(
          icon: _getSizeIcon(),
          label: _getSizeName(),
          color: theme.primary,
          textColor: theme.text,
        ),
        const SizedBox(height: 3),
        _InfoRow(
          icon: _getTintIcon(),
          label: _getTintName(),
          color: theme.primary,
          textColor: theme.text,
        ),
        if (instance.natureId != null && instance.natureId!.isNotEmpty) ...[
          const SizedBox(height: 3),
          _InfoRow(
            icon: Icons.psychology_rounded,
            label: instance.natureId!,
            color: theme.primary,
            textColor: theme.text,
          ),
        ],
      ],
    );
  }
}

class _ParentChip extends StatelessWidget {
  final int? selectionNumber;
  const _ParentChip({required this.selectionNumber});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.green.shade400.withOpacity(.6),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.merge_type_rounded,
            color: Colors.green.shade300,
            size: 10,
          ),
          const SizedBox(width: 3),
          Text(
            'PARENT $selectionNumber',
            style: TextStyle(
              color: Colors.green.shade300,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.shade400.withOpacity(.2),
            Colors.purple.shade600.withOpacity(.2),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.purple.shade400.withOpacity(.6),
          width: 1,
        ),
      ),
      child: Text(
        'PRISMATIC',
        style: TextStyle(
          color: Colors.purple.shade200,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color.withOpacity(.8)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
