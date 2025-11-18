import 'dart:async' as async;
import 'dart:convert';

import 'package:alchemons/database/daos/creature_dao.dart';
import 'package:alchemons/widgets/creature_selection_sheet.dart';
import 'package:alchemons/widgets/instance_widgets/instance_sheet_components.dart';
import 'package:alchemons/widgets/instance_widgets/intance_filter_panel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/database/daos/settings_dao.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
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

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();

    return StreamBuilder<List<CreatureInstance>>(
      // DB-level filtering where possible
      stream: db.creatureDao.watchFilteredInstances(
        searchText: null,
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
        instances = _applySearchFilter(instances, repo, _searchText);

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
