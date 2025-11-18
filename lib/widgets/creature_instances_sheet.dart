import 'dart:async' as async;
import 'dart:convert';

import 'package:alchemons/database/daos/creature_dao.dart';
import 'package:alchemons/widgets/creature_selection_sheet.dart';
import 'package:alchemons/widgets/instance_widgets/instance_sheet_components.dart';
import 'package:alchemons/widgets/instance_widgets/intance_filter_panel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flame/components.dart';

import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/database/daos/settings_dao.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/utils/harvest_rate.dart';
import 'package:alchemons/widgets/bottom_sheet_shell.dart';
import 'package:alchemons/widgets/creature_dialog.dart';

class InstancesSheet extends StatefulWidget {
  final Creature species;
  final FactionTheme theme;
  final List<String> selectedInstanceIds;
  final void Function(CreatureInstance inst) onTap;
  final bool selectionMode;

  /// feeding screen can force this to InstanceDetailMode.stats
  final InstanceDetailMode initialDetailMode;

  /// HARVEST MODE: if provided, show harvest stats instead of genetics/stats modes
  final Duration? harvestDuration;
  final List<String>? busyInstanceIds; // instances currently on jobs

  /// if true, checks stamina before allowing selection (for harvest/jobs)
  final bool requireStamina;

  const InstancesSheet({
    super.key,
    required this.species,
    required this.theme,
    required this.onTap,
    this.selectedInstanceIds = const [],
    this.selectionMode = false,
    this.initialDetailMode = InstanceDetailMode.info,
    this.harvestDuration,
    this.busyInstanceIds,
    this.requireStamina = false,
  });

  @override
  State<InstancesSheet> createState() => _InstancesSheetState();
}

class _InstancesSheetState extends State<InstancesSheet> {
  SortBy _sortBy = SortBy.newest;

  late TextEditingController _searchController;

  // search / filter state
  bool _filtersOpen = false;
  String _searchText = '';
  String? _filterSize; // null = Any
  String? _filterTint; // null = Any
  String? _filterNature; // null = Any
  bool _filterPrismatic = false;

  // Variant cycle uses display names + special sentinels
  // null = Any; '__NON__' = Non-variant; others = 'Volcanic' | 'Oceanic' | 'Earthen' | 'Verdant' | 'Arcane'
  String? _filterVariant;

  // ordered cycles
  late final List<String> _sizeCycle = sizeLabels.keys.toList(growable: false);
  late final List<String> _tintCycle = tintLabels.keys.toList(growable: false);

  // ElementalGroup display names:
  static const List<String> _variantGroups = [
    'Volcanic',
    'Oceanic',
    'Earthen',
    'Verdant',
    'Arcane',
  ];

  // cycle order: Any → groups → Any
  late final List<String?> _variantCycle = <String?>[null, ..._variantGroups];

  // helpers
  String? _cycleNextOrAny(String? current, List<String> ordered) {
    if (ordered.isEmpty) return null;
    if (current == null) return ordered.first; // Any → first
    final i = ordered.indexOf(current);
    if (i < 0 || i == ordered.length - 1) return null; // last → Any
    return ordered[i + 1];
  }

  String? _cycleNextVariant(String? current) {
    final i = _variantCycle.indexOf(current);
    if (i < 0 || i == _variantCycle.length - 1) return _variantCycle.first;
    return _variantCycle[i + 1];
  }

  late SettingsDao _settings;
  async.Timer? _saveTimer;

  String get _prefsKey => 'instances_filters_${widget.species.id}';

  // persist the minimal UI state
  Map<String, dynamic> _toPrefs() => {
    'sortBy': _sortBy.name,
    'filtersOpen': _filtersOpen,
    'searchText': _searchText,
    'filterSize': _filterSize,
    'filterTint': _filterTint,
    'filterNature': _filterNature,
    'filterPrismatic': _filterPrismatic,
    'filterVariant': _filterVariant, // null | group name
    'detailMode': _detailMode.name, // info | stats | genetics
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
      orElse: () => widget.initialDetailMode,
    );
  }

  // debounce saves so we’re not hammering the DB
  void _queueSave() {
    _saveTimer?.cancel();
    _saveTimer = async.Timer(const Duration(milliseconds: 300), () async {
      await _settings.setSetting(_prefsKey, jsonEncode(_toPrefs()));
    });
  }

  // convenience so every mutation auto-saves
  void _mutate(VoidCallback fn) {
    setState(fn);
    _queueSave();
  }

  // STATS vs GENETICS
  late InstanceDetailMode _detailMode;

  bool get _isHarvestMode => widget.harvestDuration != null;

  @override
  void initState() {
    super.initState();
    _detailMode = widget.initialDetailMode;
    _searchController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // safe to read providers here
    _settings = context.read<AlchemonsDatabase>().settingsDao;

    () async {
      final raw = await _settings.getSetting(_prefsKey);
      if (!mounted || raw == null || raw.isEmpty) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      setState(() => _fromPrefs(map)); // no save on restore
      if (mounted) {
        // Must be done after setState runs and restores _searchText
        _searchController.text = _searchText;
      }
    }();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
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

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    final stamina = context.read<StaminaService>();

    final scrollController = SheetBodyWrapper.maybeOf(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamProvider<List<CreatureInstance>>(
        create: (_) =>
            db.creatureDao.watchInstancesBySpecies(widget.species.id),
        initialData: const [],
        child: Consumer<List<CreatureInstance>>(
          builder: (_, instances, __) {
            // 1. species instances
            var visible = [...instances];

            // Filter out busy instances if in harvest mode
            if (_isHarvestMode && widget.busyInstanceIds != null) {
              visible = visible
                  .where(
                    (inst) =>
                        !widget.busyInstanceIds!.contains(inst.instanceId),
                  )
                  .toList();
            }

            // 2. text search
            if (_searchText.trim().isNotEmpty) {
              final query = _searchText.trim().toLowerCase();
              visible = visible.where((inst) {
                final g = decodeGenetics(inst.geneticsJson);
                final sizeVar = g?.get('size') ?? '';
                final tintVar = g?.get('tinting') ?? '';
                final nat = inst.natureId ?? '';

                final tokens = <String>[
                  sizeLabels[sizeVar] ?? sizeVar,
                  tintLabels[tintVar] ?? tintVar,
                  nat,
                  'LV ${inst.level}',
                  inst.instanceId,
                  inst.nickname ?? inst.baseId,
                ].join(' ').toLowerCase();

                return tokens.contains(query);
              }).toList();
            }

            // 3. advanced filters
            visible = visible.where((inst) {
              if (_filterPrismatic && inst.isPrismaticSkin != true) {
                return false;
              }

              // VARIANT: match against display name (case-insensitive)
              final hasVariant =
                  (inst.variantFaction != null &&
                  inst.variantFaction!.isNotEmpty);
              if (_filterVariant == '__NON__') {
                if (hasVariant) return false; // only non-variant
              } else if (_filterVariant != null) {
                if (!hasVariant) return false;
                final vf = inst.variantFaction!.trim().toLowerCase();
                if (vf != _filterVariant!.toLowerCase()) {
                  return false; // exact group
                }
              }

              final g = decodeGenetics(inst.geneticsJson);
              final sizeGene = g?.get('size');
              final tintGene = g?.get('tinting');

              if (_filterSize != null && sizeGene != _filterSize) return false;
              if (_filterTint != null && tintGene != _filterTint) return false;
              if (_filterNature != null && inst.natureId != _filterNature) {
                return false;
              }

              return true;
            }).toList();

            // 4. sort (client-side for this sheet)
            switch (_sortBy) {
              case SortBy.newest:
                visible.sort(
                  (a, b) => b.createdAtUtcMs.compareTo(a.createdAtUtcMs),
                );
                break;
              case SortBy.oldest:
                visible.sort(
                  (a, b) => a.createdAtUtcMs.compareTo(b.createdAtUtcMs),
                );
                break;
              case SortBy.levelHigh:
                visible.sort((a, b) => b.level.compareTo(a.level));
                break;
              case SortBy.levelLow:
                visible.sort((a, b) => a.level.compareTo(b.level));
                break;
              case SortBy.statBeauty:
                visible.sort((a, b) => b.statBeauty.compareTo(a.statBeauty));
                break;
              case SortBy.statSpeed:
                visible.sort((a, b) => b.statSpeed.compareTo(a.statSpeed));
                break;
              case SortBy.statStrength:
                visible.sort(
                  (a, b) => b.statStrength.compareTo(a.statStrength),
                );
                break;
              case SortBy.statIntelligence:
                visible.sort(
                  (a, b) => b.statIntelligence.compareTo(a.statIntelligence),
                );
                break;
            }

            // is "Filters" pill active?
            final hasFiltersActive = _isHarvestMode
                // In harvest mode, we only care about size & nature (+ search/sort)
                ? _filterSize != null ||
                      _filterNature != null ||
                      _searchText.trim().isNotEmpty ||
                      _sortBy != SortBy.newest
                : _filterPrismatic ||
                      _filterVariant != null ||
                      _filterSize != null ||
                      _filterTint != null ||
                      _filterNature != null ||
                      _searchText.trim().isNotEmpty ||
                      _sortBy != SortBy.newest;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ===== SEARCH + TOP BAR =====
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      // search box
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
                                    hintText: 'Search traits / nature / LV',
                                    hintStyle: TextStyle(
                                      color: widget.theme.textMuted.withOpacity(
                                        .6,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  onChanged: (val) => _mutate(() {
                                    _searchText = val;
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Only show STATS/GENETICS toggle if NOT in harvest mode
                      if (!_isHarvestMode)
                        GestureDetector(
                          onTap: () => _mutate(() {
                            _detailMode = switch (_detailMode) {
                              InstanceDetailMode.info =>
                                InstanceDetailMode.stats,
                              InstanceDetailMode.stats =>
                                InstanceDetailMode.genetics,
                              InstanceDetailMode.genetics =>
                                InstanceDetailMode.info,
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
                      if (!_isHarvestMode) const SizedBox(width: 8),

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

                // ===== FILTER PANEL =====
                if (_filtersOpen) ...[
                  const SizedBox(height: 10),
                  InstanceFiltersPanel(
                    theme: widget.theme,
                    sortBy: _sortBy,
                    onSortChanged: (s) => _mutate(() => _sortBy = s),
                    harvestMode: _isHarvestMode,

                    filterPrismatic: _filterPrismatic,
                    onTogglePrismatic: () =>
                        _mutate(() => _filterPrismatic = !_filterPrismatic),

                    sizeValueText: _filterSize == null
                        ? null
                        : (sizeLabels[_filterSize] ?? _filterSize!),
                    onCycleSize: () => _mutate(
                      () => _filterSize = _cycleNextOrAny(
                        _filterSize,
                        _sizeCycle,
                      ),
                    ),

                    tintValueText: _filterTint == null
                        ? null
                        : (tintLabels[_filterTint] ?? _filterTint!),
                    onCycleTint: () => _mutate(
                      () => _filterTint = _cycleNextOrAny(
                        _filterTint,
                        _tintCycle,
                      ),
                    ),

                    variantValueText: _filterVariant,
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

                // ===== GRID LIST =====
                Expanded(
                  child: visible.isEmpty
                      ? InstancesEmptyState(
                          primaryColor: widget.theme.primary,
                          hasFilters: hasFiltersActive,
                        )
                      : GridView.builder(
                          controller: scrollController,
                          physics: const BouncingScrollPhysics(),
                          itemCount: visible.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 1,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                          itemBuilder: (_, i) {
                            final inst = visible[i];

                            // Check if selected
                            final isSelected = widget.selectedInstanceIds
                                .contains(inst.instanceId);

                            // Find selection number (only for first 3)
                            int? selectionNumber;
                            final index = widget.selectedInstanceIds.indexOf(
                              inst.instanceId,
                            );
                            if (index >= 0 && index < 3) {
                              selectionNumber = index + 1;
                            }

                            return InstanceCard(
                              key: ValueKey(inst.instanceId),
                              species: widget.species,
                              instance: inst,
                              theme: widget.theme,
                              detailMode: _detailMode,
                              isSelected: isSelected,
                              selectionNumber: selectionNumber,
                              harvestDuration: widget.harvestDuration,
                              calculateHarvestRate: _isHarvestMode
                                  ? (inst) => computeHarvestRatePerMinute(
                                      inst,
                                      hasMatchingElement:
                                          true, // already biome-filtered
                                    )
                                  : null,
                              onTap: () async {
                                // Only check stamina if required
                                if (widget.requireStamina) {
                                  final refreshed = await stamina.refreshAndGet(
                                    inst.instanceId,
                                  );
                                  final canUse =
                                      (refreshed?.staminaBars ?? 0) >= 1;

                                  if (!canUse) {
                                    final perBar = stamina.regenPerBar;
                                    final now = DateTime.now()
                                        .toUtc()
                                        .millisecondsSinceEpoch;
                                    final last =
                                        refreshed?.staminaLastUtcMs ?? now;
                                    final elapsed = now - last;
                                    final remMs =
                                        perBar.inMilliseconds -
                                        (elapsed % perBar.inMilliseconds);
                                    final mins = (remMs / 60000).ceil();

                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(
                                              Icons.hourglass_bottom_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                'Specimen is resting — next stamina in ~${mins}m',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        backgroundColor: Colors.orange,
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 2),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        margin: const EdgeInsets.all(16),
                                      ),
                                    );
                                    return;
                                  }
                                }

                                widget.onTap(inst);
                              },
                              onLongPress: () {
                                CreatureDetailsDialog.show(
                                  context,
                                  widget.species,
                                  true,
                                  instanceId: inst.instanceId,
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
