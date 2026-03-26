import 'dart:async' as async;
import 'dart:convert';

import 'package:alchemons/database/daos/creature_dao.dart';
import 'package:alchemons/widgets/creature_selection_sheet.dart';
import 'package:alchemons/widgets/filterchip_solod.dart';
import 'package:alchemons/widgets/instance_widgets/instance_sheet_components.dart';
import 'package:alchemons/widgets/instance_widgets/intance_filter_panel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/database/daos/settings_dao.dart';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/creature_filter_util.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/utils/instance_purity_util.dart';
import 'package:alchemons/utils/show_quick_instance_dialog.dart';

class AllCreatureInstances extends StatefulWidget {
  final FactionTheme theme;
  final List<String> selectedInstanceIds;
  final void Function(CreatureInstance inst)? onTap;
  final VoidCallback? onLongPress;

  // Selection mode support
  final bool selectionMode;
  final int maxSelections; // 0 = unlimited, positive = max
  final void Function(List<CreatureInstance>)? onConfirmSelection;

  /// When true, only show favorited instances.
  final bool favoritesOnly;
  final String? searchTextOverride;
  final bool showInternalSearchBar;
  final int clearVersion;
  final ValueChanged<bool>? onResettableStateChanged;
  final List<String> allowedPrimaryTypes;
  final ValueChanged<List<CreatureInstance>>? onSelectionChanged;

  const AllCreatureInstances({
    super.key,
    required this.theme,
    this.onTap,
    this.selectedInstanceIds = const [],
    this.onLongPress,
    this.selectionMode = false,
    this.maxSelections = 0,
    this.onConfirmSelection,
    this.favoritesOnly = false,
    this.searchTextOverride,
    this.showInternalSearchBar = true,
    this.clearVersion = 0,
    this.onResettableStateChanged,
    this.allowedPrimaryTypes = const [],
    this.onSelectionChanged,
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
  String? _filterType;
  String? _filterFamily;
  bool _filterPrismatic = false;
  bool _filterFavorites = false;
  String? _filterVariant;
  InstancePurityFilter _filterPurity = InstancePurityFilter.all;

  // Selection state (when in selection mode)
  final Set<String> _localSelections = {};
  Map<String, CreatureInstance> _allKnownInstancesById = const {};
  List<String> _lastReportedSelectionIds = const [];

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

  // Any → groups → '__NON__' → Any
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
  bool? _lastReportedResettableState;

  String get _prefsKey => 'all_instances_filters';

  Map<String, dynamic> _toPrefs() => {
    'sortBy': _sortBy.name,
    'filtersOpen': _filtersOpen,
    'searchText': _searchText,
    'filterSize': _filterSize,
    'filterTint': _filterTint,
    'filterNature': _filterNature,
    'filterType': _filterType,
    'filterFamily': _filterFamily,
    'filterPrismatic': _filterPrismatic,
    'filterFavorites': _filterFavorites,
    'filterVariant': _filterVariant,
    'filterPurity': _filterPurity.name,
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
    _filterType = p['filterType'];
    _filterFamily = p['filterFamily'] ?? p['filterSpeciesId'];
    _filterPrismatic = p['filterPrismatic'] ?? _filterPrismatic;
    _filterFavorites =
        p['filterFavorites'] ?? (p['filterLocked'] ?? _filterFavorites);
    _filterVariant = p['filterVariant'];
    _filterPurity = InstancePurityFilter.values.firstWhere(
      (e) => e.name == (p['filterPurity'] ?? _filterPurity.name),
      orElse: () => InstancePurityFilter.all,
    );
    _detailMode = InstanceDetailMode.values.firstWhere(
      (e) => e.name == (p['detailMode'] ?? _detailMode.name),
      orElse: () => InstanceDetailMode.stats,
    );
    if (_detailMode == InstanceDetailMode.info) {
      _detailMode = InstanceDetailMode.stats;
    }
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
    _detailMode = InstanceDetailMode.stats;
    _searchController = TextEditingController();
    if (widget.searchTextOverride != null) {
      _searchController.text = widget.searchTextOverride!;
    }
    // Initialize with passed selections only when in selection mode
    if (widget.selectionMode) {
      _localSelections.addAll(widget.selectedInstanceIds);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _settings = context.read<AlchemonsDatabase>().settingsDao;
    () async {
      final raw = await _settings.getSetting(_prefsKey);
      if (!mounted || raw == null || raw.isEmpty) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      setState(() => _fromPrefs(map));
      if (mounted && widget.searchTextOverride == null) {
        _searchController.text = _searchText;
      }
    }();
  }

  @override
  void didUpdateWidget(covariant AllCreatureInstances oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clearVersion != oldWidget.clearVersion) {
      _mutate(() => _resetAllControls(clearSearch: true));
    }
    if (widget.searchTextOverride != oldWidget.searchTextOverride &&
        widget.searchTextOverride != null &&
        widget.searchTextOverride != _searchController.text) {
      _searchController.text = widget.searchTextOverride!;
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
      _emitSelectionChanged();
    } else if (widget.onTap != null) {
      widget.onTap!(inst);
    }
  }

  List<CreatureInstance> _currentSelectedInstances() {
    final orderedSelectionIds = _localSelections.toList();
    return orderedSelectionIds
        .map((id) => _allKnownInstancesById[id])
        .whereType<CreatureInstance>()
        .toList();
  }

  void _emitSelectionChanged() {
    if (!widget.selectionMode || widget.onSelectionChanged == null) return;
    widget.onSelectionChanged!(_currentSelectedInstances());
  }

  bool get _hasAdvancedFilters =>
      _filterPrismatic ||
      _filterFavorites ||
      _filterPurity != InstancePurityFilter.all ||
      _filterVariant != null ||
      _filterSize != null ||
      _filterTint != null ||
      _filterNature != null;

  bool get _hasBrowseChipSelection =>
      _filterType != null || _filterFamily != null;

  bool get _hasResettableState {
    final effectiveSearchText = widget.searchTextOverride ?? _searchText;
    return _hasAdvancedFilters ||
        _hasBrowseChipSelection ||
        effectiveSearchText.trim().isNotEmpty ||
        _sortBy != SortBy.newest;
  }

  void _resetAllControls({required bool clearSearch}) {
    _filterPrismatic = false;
    _filterFavorites = false;
    _filterType = null;
    _filterFamily = null;
    _filterVariant = null;
    _filterPurity = InstancePurityFilter.all;
    _filterSize = null;
    _filterTint = null;
    _filterNature = null;
    _sortBy = SortBy.newest;
    if (clearSearch) {
      _searchText = '';
      _searchController.clear();
    }
  }

  // Client-side filtering for size/tint (requires genetics parsing)
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

  List<CreatureInstance> _applySearchFilter(
    List<CreatureInstance> instances,
    CreatureCatalog repo,
    String searchText,
  ) {
    if (searchText.trim().isEmpty) {
      return instances;
    }

    final searchLower = searchText.trim().toLowerCase();

    return instances.where((inst) {
      // nickname
      if (inst.nickname != null &&
          inst.nickname!.toLowerCase().contains(searchLower)) {
        return true;
      }

      // species name
      final creature = repo.getCreatureById(inst.baseId);
      if (creature != null &&
          creature.name.toLowerCase().contains(searchLower)) {
        return true;
      }

      return false;
    }).toList();
  }

  List<CreatureInstance> _applySpeciesAndTypeFilters(
    List<CreatureInstance> instances,
    CreatureCatalog repo,
  ) {
    return instances.where((inst) {
      final creature = repo.getCreatureById(inst.baseId);
      if (!_matchesAllowedPrimaryTypes(creature)) {
        return false;
      }
      if (_filterFamily != null &&
          (creature == null || creature.mutationFamily != _filterFamily)) {
        return false;
      }
      if (_filterType != null &&
          (creature == null || !creature.types.contains(_filterType))) {
        return false;
      }
      return true;
    }).toList();
  }

  bool _matchesAllowedPrimaryTypes(Creature? creature) {
    if (widget.allowedPrimaryTypes.isEmpty) return true;
    if (creature == null || creature.types.isEmpty) return false;
    return widget.allowedPrimaryTypes.contains(creature.types.first);
  }

  List<CreatureInstance> _applyAdvancedFilters(
    List<CreatureInstance> instances,
    CreatureCatalog repo,
  ) {
    return instances.where((inst) {
      if ((widget.favoritesOnly || _filterFavorites) && !inst.isFavorite) {
        return false;
      }
      if (_filterPrismatic && !inst.isPrismaticSkin) {
        return false;
      }
      if (_filterNature != null && inst.natureId != _filterNature) {
        return false;
      }
      final species = repo.getCreatureById(inst.baseId);
      if (!matchesPurityFilter(inst, filter: _filterPurity, species: species)) {
        return false;
      }
      if (_filterVariant != null) {
        if (_filterVariant == '__NON__') {
          if (inst.variantFaction != null) return false;
        } else if (inst.variantFaction != _filterVariant) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _sortInstances(List<CreatureInstance> instances) {
    int compareNums(num a, num b) => a.compareTo(b);

    instances.sort((a, b) {
      final primary = switch (_sortBy) {
        SortBy.newest => compareNums(b.createdAtUtcMs, a.createdAtUtcMs),
        SortBy.oldest => compareNums(a.createdAtUtcMs, b.createdAtUtcMs),
        SortBy.levelHigh => compareNums(b.level, a.level),
        SortBy.levelLow => compareNums(a.level, b.level),
        SortBy.statSpeed => compareNums(b.statSpeed, a.statSpeed),
        SortBy.statIntelligence => compareNums(
          b.statIntelligence,
          a.statIntelligence,
        ),
        SortBy.statStrength => compareNums(b.statStrength, a.statStrength),
        SortBy.statBeauty => compareNums(b.statBeauty, a.statBeauty),
        SortBy.potentialSpeed => compareNums(
          b.statSpeedPotential,
          a.statSpeedPotential,
        ),
        SortBy.potentialIntelligence => compareNums(
          b.statIntelligencePotential,
          a.statIntelligencePotential,
        ),
        SortBy.potentialStrength => compareNums(
          b.statStrengthPotential,
          a.statStrengthPotential,
        ),
        SortBy.potentialBeauty => compareNums(
          b.statBeautyPotential,
          a.statBeautyPotential,
        ),
      };

      if (primary != 0) return primary;
      return compareNums(b.createdAtUtcMs, a.createdAtUtcMs);
    });
  }

  List<CreatureInstance> _applyAllFilters(
    List<CreatureInstance> instances,
    CreatureCatalog repo,
    String effectiveSearchText,
  ) {
    var filtered = _applyAdvancedFilters(instances, repo);
    filtered = _applySpeciesAndTypeFilters(filtered, repo);
    filtered = _applyClientSideFilters(filtered);
    filtered = _applySearchFilter(filtered, repo, effectiveSearchText);
    _sortInstances(filtered);
    return filtered;
  }

  List<String> _buildFamilyOptions(
    List<CreatureInstance> instances,
    CreatureCatalog repo,
  ) {
    final families = <String>{};
    for (final inst in instances) {
      final creature = repo.getCreatureById(inst.baseId);
      if (!_matchesAllowedPrimaryTypes(creature)) continue;
      final family = creature?.mutationFamily;
      if (family != null && family.isNotEmpty) {
        families.add(family);
      }
    }
    return CreatureFilterUtils.speciesFilters
        .where((family) => family != 'All' && families.contains(family))
        .toList(growable: false);
  }

  Map<String, String> _buildTypeOptions(
    List<CreatureInstance> instances,
    CreatureCatalog repo,
  ) {
    final types = <String>{};
    for (final inst in instances) {
      final creature = repo.getCreatureById(inst.baseId);
      if (_matchesAllowedPrimaryTypes(creature) && creature != null) {
        types.addAll(creature.types);
      }
    }
    final sorted = types.toList()..sort();
    return {for (final type in sorted) type: type};
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();
    final hasPotentialAnalyzer = context
        .watch<ConstellationEffectsService>()
        .hasPotentialAnalyzer();
    final effectiveSearchText = widget.searchTextOverride ?? _searchText;

    return StreamBuilder<List<CreatureInstance>>(
      stream: db.creatureDao.watchAllInstances(),
      initialData: const [],
      builder: (context, snapshot) {
        final allInstances = snapshot.data ?? [];
        _allKnownInstancesById = {
          for (final inst in allInstances) inst.instanceId: inst,
        };
        final familyOptions = _buildFamilyOptions(allInstances, repo);
        final typeOptions = _buildTypeOptions(allInstances, repo);
        final instances = _applyAllFilters(
          allInstances,
          repo,
          effectiveSearchText,
        );
        final currentSelectionIds = _localSelections.toList();

        final hasFiltersActive =
            _hasAdvancedFilters ||
            _hasBrowseChipSelection ||
            effectiveSearchText.trim().isNotEmpty ||
            _sortBy != SortBy.newest;

        if (_lastReportedResettableState != _hasResettableState) {
          _lastReportedResettableState = _hasResettableState;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            widget.onResettableStateChanged?.call(_hasResettableState);
          });
        }

        if (widget.selectionMode &&
            widget.onSelectionChanged != null &&
            currentSelectionIds.join('|') !=
                _lastReportedSelectionIds.join('|')) {
          _lastReportedSelectionIds = List<String>.from(currentSelectionIds);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _emitSelectionChanged();
          });
        }

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
                            widget.onConfirmSelection!(
                              _currentSelectedInstances(),
                            );
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
                          child: const Text(
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

            // Top controls
            Container(
              padding: const EdgeInsets.only(top: 9, bottom: 3),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _TopControlChip(
                      label: _sortBy == SortBy.oldest ? 'OLDEST' : 'NEWEST',
                      accentColor: widget.theme.primary,
                      labelFontSize: 9.72,
                      selected:
                          _sortBy == SortBy.newest || _sortBy == SortBy.oldest,
                      onTap: () => _mutate(() {
                        _sortBy = _sortBy == SortBy.oldest
                            ? SortBy.newest
                            : SortBy.oldest;
                      }),
                      theme: widget.theme,
                    ),
                    _TopControlChip(
                      label: _sortBy == SortBy.levelLow ? 'LV ↓' : 'LV ↑',
                      accentColor: const Color(0xFFFDE047),
                      labelFontSize: 9.72,
                      selected:
                          _sortBy == SortBy.levelHigh ||
                          _sortBy == SortBy.levelLow,
                      onTap: () => _mutate(() {
                        _sortBy = _sortBy == SortBy.levelLow
                            ? SortBy.levelHigh
                            : SortBy.levelLow;
                      }),
                      theme: widget.theme,
                    ),
                    _TopControlChip(
                      label: switch (_sortBy) {
                        _ when _sortBy.isStatSort => '${_sortBy.shortLabel} ↓',
                        _ => 'STAT',
                      },
                      accentColor: switch (_sortBy) {
                        _ when _sortBy.statFamily == 'intelligence' =>
                          const Color(0xFFC084FC),
                        _ when _sortBy.statFamily == 'strength' => const Color(
                          0xFFF87171,
                        ),
                        _ when _sortBy.statFamily == 'beauty' => const Color(
                          0xFFF9A8D4,
                        ),
                        _ when _sortBy.statFamily == 'speed' => const Color(
                          0xFFFDE047,
                        ),
                        _ => widget.theme.textMuted,
                      },
                      labelFontSize: 9.72,
                      selected: _sortBy.isStatSort,
                      onTap: () => _mutate(() {
                        _sortBy = _sortBy.nextStatSort(
                          includePotential: hasPotentialAnalyzer,
                        );
                      }),
                      theme: widget.theme,
                    ),
                    _TopControlChip(
                      label: _detailMode == InstanceDetailMode.genetics
                          ? 'GENETICS'
                          : 'STATS',
                      accentColor: _detailMode == InstanceDetailMode.genetics
                          ? const Color(0xFFC084FC)
                          : const Color(0xFFFDE047),
                      labelFontSize: 9.72,
                      selected: true,
                      onTap: () => _mutate(() {
                        _detailMode = _detailMode == InstanceDetailMode.genetics
                            ? InstanceDetailMode.stats
                            : InstanceDetailMode.genetics;
                      }),
                      theme: widget.theme,
                    ),
                    _TopControlChip(
                      label: 'FILTERS',
                      accentColor: widget.theme.primary,
                      labelFontSize: 9.72,
                      selected: _filtersOpen,
                      trailing: Icon(
                        _filtersOpen
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 12,
                        color: _filtersOpen
                            ? widget.theme.primary
                            : widget.theme.text,
                      ),
                      onTap: () => _mutate(() {
                        _filtersOpen = !_filtersOpen;
                      }),
                      theme: widget.theme,
                    ),
                    if (widget.searchTextOverride == null)
                      _TopControlChip(
                        label: 'CLEAR',
                        accentColor: const Color(0xFFEF4444),
                        selected: _hasResettableState,
                        onTap: () =>
                            _mutate(() => _resetAllControls(clearSearch: true)),
                        theme: widget.theme,
                      ),
                  ],
                ),
              ),
            ),

            // Filter panel
            if (_filtersOpen) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (familyOptions.isNotEmpty)
                      SizedBox(
                        height: 34,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: familyOptions.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (_, index) {
                            return FilterChipSolid(
                              label: familyOptions[index],
                              color: widget.theme.primary,
                              selected: _filterFamily == familyOptions[index],
                              onTap: () => _mutate(() {
                                _filterFamily =
                                    _filterFamily == familyOptions[index]
                                    ? null
                                    : familyOptions[index];
                              }),
                            );
                          },
                        ),
                      ),
                    if (familyOptions.isNotEmpty && typeOptions.isNotEmpty)
                      const SizedBox(height: 6),
                    if (typeOptions.isNotEmpty)
                      SizedBox(
                        height: 34,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: typeOptions.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (_, index) {
                            final entry = typeOptions.entries.elementAt(index);
                            return FilterChipSolid(
                              label: entry.value,
                              color: BreedConstants.getTypeColor(entry.key),
                              selected: _filterType == entry.key,
                              onTap: () => _mutate(() {
                                _filterType = _filterType == entry.key
                                    ? null
                                    : entry.key;
                              }),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              InstanceFiltersPanel(
                theme: widget.theme,
                sortBy: _sortBy,
                onSortChanged: (s) => _mutate(() => _sortBy = s),
                harvestMode: false,
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
                purityFilter: _filterPurity,
                onCyclePurity: () =>
                    _mutate(() => _filterPurity = _filterPurity.next()),
                filterNature: _filterNature,
                onPickNature: (val) => _mutate(() => _filterNature = val),
                natureOptions: _buildNatureOptions(),
                filterFavorites: _filterFavorites,
                onToggleFavorites: () =>
                    _mutate(() => _filterFavorites = !_filterFavorites),
                showSortRow: false,
                showClearChip: false,
                onClearAll: () =>
                    _mutate(() => _resetAllControls(clearSearch: true)),
              ),
            ],

            const SizedBox(height: 12),

            // Grid of instances
            Expanded(
              child: instances.isEmpty
                  ? InstancesEmptyState(
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
                        if (creature == null) {
                          return const SizedBox.shrink();
                        }

                        // Decide where selection comes from
                        final List<String> orderedSelectionIds =
                            widget.selectionMode
                            ? _localSelections.toList()
                            : widget.selectedInstanceIds;

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

                        return RepaintBoundary(
                          child: InstanceCard(
                            key: ValueKey(inst.instanceId),
                            species: creature,
                            instance: inst,
                            theme: widget.theme,
                            detailMode: _detailMode,
                            activeSortBy: _sortBy,
                            isSelected: isSelected,
                            selectionNumber: selectionNumber,
                            onTap: () => _handleInstanceTap(inst),
                            onLongPress: () {
                              if (!widget.selectionMode) {
                                showQuickInstanceDialog(
                                  context: context,
                                  theme: widget.theme,
                                  creature: creature,
                                  instance: inst,
                                );
                              } else {
                                widget.onLongPress?.call();
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

class _TopControlChip extends StatelessWidget {
  const _TopControlChip({
    required this.label,
    required this.accentColor,
    required this.selected,
    required this.onTap,
    required this.theme,
    this.labelFontSize = 12,
    this.trailing,
  });

  final String label;
  final Color accentColor;
  final bool selected;
  final VoidCallback onTap;
  final FactionTheme theme;
  final double labelFontSize;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return FilterChipSolid(
      label: label,
      color: accentColor,
      selected: selected,
      onTap: onTap,
      trailing: trailing,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      unselectedTextColor: theme.text,
      unselectedBorderColor: theme.border,
      selectedFillOpacity: 0.12,
      labelFontSize: labelFontSize,
    );
  }
}
