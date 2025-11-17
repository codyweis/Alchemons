import 'dart:async' as async;
import 'dart:convert';

import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/daos/creature_dao.dart';
import 'package:alchemons/database/daos/settings_dao.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/harvest_rate.dart';
import 'package:alchemons/widgets/bottom_sheet_shell.dart';
import 'package:alchemons/widgets/creature_dialog.dart';
import 'package:alchemons/widgets/creature_selection_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flame/components.dart';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/stamina_bar.dart';
import 'package:alchemons/widgets/creature_sprite.dart';

// needs sizeLabels, tintLabels, sizeIcons, tintIcons in scope
// enum for card mode

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

  // ElementalGroup display names you gave us:
  static const List<String> _variantGroups = [
    'Volcanic',
    'Oceanic',
    'Earthen',
    'Verdant',
    'Arcane',
  ];

  // cycle order: Any → groups → Non-variant → Any
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
    'filterVariant': _filterVariant, // null | '__NON__' | group name
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

  bool get _isHarvestMode => widget.harvestDuration != null;

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
                  inst.nickname ?? inst.baseId, // ← added
                ].join(' ').toLowerCase();

                return tokens.contains(query);
              }).toList();
            }

            // 3. advanced filters
            // 3. advanced filters
            visible = visible.where((inst) {
              if (_filterPrismatic && inst.isPrismaticSkin != true)
                return false;

              // VARIANT: match against display name (case-insensitive)
              final hasVariant =
                  (inst.variantFaction != null &&
                  inst.variantFaction!.isNotEmpty);
              if (_filterVariant == '__NON__') {
                if (hasVariant) return false; // only non-variant
              } else if (_filterVariant != null) {
                if (!hasVariant) return false;
                final vf = inst.variantFaction!.trim().toLowerCase();
                if (vf != _filterVariant!.toLowerCase())
                  return false; // exact group
              }

              final g = decodeGenetics(inst.geneticsJson);
              final sizeGene = g?.get('size');
              final tintGene = g?.get('tinting');

              if (_filterSize != null && sizeGene != _filterSize) return false;
              if (_filterTint != null && tintGene != _filterTint) return false;
              if (_filterNature != null && inst.natureId != _filterNature)
                return false;

              return true;
            }).toList();

            // 4. sort
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
                visible.sort((a, b) {
                  final aStats = a.statBeauty;
                  final bStats = b.statBeauty;
                  return bStats.compareTo(aStats);
                });
                break;
              case SortBy.statSpeed:
                visible.sort((a, b) {
                  final aStats = a.statSpeed;
                  final bStats = b.statSpeed;
                  return bStats.compareTo(aStats);
                });
                break;
              case SortBy.statStrength:
                visible.sort((a, b) {
                  final aStats = a.statStrength;
                  final bStats = b.statStrength;
                  return bStats.compareTo(aStats);
                });
                break;
              case SortBy.statIntelligence:
                visible.sort((a, b) {
                  final aStats = a.statIntelligence;
                  final bStats = b.statIntelligence;
                  return bStats.compareTo(aStats);
                });
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
                  _FiltersPanel(
                    theme: widget.theme,
                    sortBy: _sortBy,
                    onSortChanged: (s) => _mutate(() => _sortBy = s),

                    // toggles
                    filterPrismatic: _filterPrismatic,
                    onTogglePrismatic: () =>
                        _mutate(() => _filterPrismatic = !_filterPrismatic),
                    harvestMode: _isHarvestMode,
                    // cyclers
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

                    variantValueText: () {
                      if (_filterVariant == null) return null; // Any

                      return _filterVariant; // Group name
                    }(),
                    onCycleVariant: () => _mutate(
                      () => _filterVariant = _cycleNextVariant(_filterVariant),
                    ),

                    // nature (sheet)
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
                      _sortBy = SortBy.newest;
                    }),
                  ),
                ],

                const SizedBox(height: 12),

                // ===== GRID LIST =====
                Expanded(
                  child: visible.isEmpty
                      ? _EmptyState(
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

                            return _InstanceCard(
                              species: widget.species,
                              instance: inst,
                              isSelected: isSelected,
                              selectionNumber: selectionNumber,
                              theme: widget.theme,
                              detailMode: _detailMode,
                              harvestDuration: widget.harvestDuration,
                              calculateHarvestRate: _isHarvestMode
                                  ? (inst) => computeHarvestRatePerMinute(
                                      inst,
                                      hasMatchingElement:
                                          true, // InstancesSheet is already biome-filtered
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

                                // Call the onTap callback (selection happens here)
                                widget.onTap(inst);
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

// FILTER PANEL
// FILTER PANEL (now includes horizontal sort bar)
class _FiltersPanel extends StatelessWidget {
  final FactionTheme theme;
  final SortBy sortBy;
  final ValueChanged<SortBy> onSortChanged;

  final bool filterPrismatic;
  final VoidCallback onTogglePrismatic;

  // cyclers (text already resolved for display)
  final String? sizeValueText;
  final VoidCallback onCycleSize;
  final String? tintValueText;
  final VoidCallback onCycleTint;
  final String? variantValueText;
  final VoidCallback onCycleVariant;

  final bool harvestMode; // Kept for sheet-specific logic

  // nature (sheet)
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
    this.harvestMode = false,
    required this.filterNature,
    required this.onPickNature,
    required this.natureOptions,
    required this.onClearAll,
  });

  /// Treat a filter as "active" whenever its value is non-null / true.
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
      // Clear All
      if (_hasActiveFilters) _ClearChip(theme: theme, onTap: onClearAll),
      if (!harvestMode) ...[
        // Variant cycler
        _CycleChip(
          theme: theme,
          icon: Icons.science_rounded,
          labelWhenAny: 'Variant: Any',
          valueText: variantValueText,
          onTap: onCycleVariant,
        ),

        // Size cycler
        _CycleChip(
          theme: theme,
          icon: Icons.straighten_rounded,
          labelWhenAny: 'Size: Any',
          valueText: sizeValueText,
          onTap: onCycleSize,
        ),

        // Tint cycler
        _CycleChip(
          theme: theme,
          icon: Icons.palette_outlined,
          labelWhenAny: 'Tint: Any',
          valueText: tintValueText,
          onTap: onCycleTint,
        ),
      ] else ...[
        // 🔥 HARVEST MODE: only Size here
        _CycleChip(
          theme: theme,
          icon: Icons.straighten_rounded,
          labelWhenAny: 'Size: Any',
          valueText: sizeValueText,
          onTap: onCycleSize,
        ),
      ],

      // Nature
      _FilterValueChip(
        theme: theme,
        icon: Icons.psychology_rounded,
        label: 'Nature',
        value: filterNature != null
            ? (natureOptions[filterNature] ?? filterNature!)
            : null,
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
      // Prismatic
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
        // Sort bar remains the same
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

        // 🔁 Filters as a horizontal scroller
        SizedBox(
          height: 36, // tweak if you want taller chips
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

// Simple pill chip for sorting (like in all_instaces_grid)
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

// Sorting chip that cycles through stat options
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
}

(IconData, String, Color) _getStatInfo(SortBy stat, bool isActive) {
  if (!isActive) {
    return (Icons.bar_chart_rounded, 'Stat', Colors.blueGrey);
  }
  // All stat sorts are descending (high to low)
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

// Modern filter chip with value/cycle
class _CycleChip extends StatelessWidget {
  final FactionTheme theme;
  final IconData icon;
  final String labelWhenAny;
  final String?
  valueText; // The currently selected value display text (or null for 'Any')
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

// Modern filter chip that toggles an on/off state (like prismatic)
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

// Modern filter chip with a value picker (like nature)
class _FilterValueChip extends StatelessWidget {
  final FactionTheme theme;
  final IconData icon;
  final String label;
  final String?
  value; // The currently selected value display text (or null for 'Any')
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
              color: active ? theme.primary.withOpacity(.6) : theme.textMuted,
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Clear',
              style: TextStyle(
                color: Colors.red.shade300,
                fontSize: 11,
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

// Re-implementing list picker to support the new filter chips
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
                BoxShadow(color: theme.accent.withOpacity(.4), blurRadius: 12),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    title,
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

// ============================================================================
// INSTANCE CARD
// ============================================================================

class _InstanceCard extends StatelessWidget {
  final Creature species;
  final CreatureInstance instance;
  final VoidCallback onTap;
  final bool isSelected;
  final int? selectionNumber;
  final FactionTheme theme;
  final InstanceDetailMode detailMode;
  final Duration? harvestDuration;
  final int Function(CreatureInstance)? calculateHarvestRate;

  const _InstanceCard({
    required this.species,
    required this.instance,
    required this.onTap,
    required this.theme,
    required this.detailMode,
    this.isSelected = false,
    this.selectionNumber,
    this.harvestDuration,
    this.calculateHarvestRate,
  });

  String _getSizeName(Genetics? genetics) =>
      sizeLabels[genetics?.get('size') ?? 'normal'] ?? 'Standard';

  String _getTintName(Genetics? genetics) =>
      tintLabels[genetics?.get('tinting') ?? 'normal'] ?? 'Standard';

  IconData _getSizeIcon(Genetics? genetics) =>
      sizeIcons[genetics?.get('size') ?? 'normal'] ?? Icons.circle;

  IconData _getTintIcon(Genetics? genetics) =>
      tintIcons[genetics?.get('tinting') ?? 'normal'] ?? Icons.palette_outlined;

  bool get _isHarvestMode =>
      harvestDuration != null && calculateHarvestRate != null;

  @override
  Widget build(BuildContext context) {
    final genetics = decodeGenetics(instance.geneticsJson);
    final sd = species.spriteData;
    final g = genetics;

    // pick which bottom block
    final Widget bottomBlock = _isHarvestMode
        ? _HarvestBlock(
            theme: theme,
            instance: instance,
            harvestDuration: harvestDuration!,
            calculateRate: calculateHarvestRate!,
            isSelected: isSelected,
            selectionNumber: selectionNumber,
          )
        : switch (detailMode) {
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
              getSizeIcon: _getSizeIcon,
              getSizeName: _getSizeName,
              getTintIcon: _getTintIcon,
              getTintName: _getTintName,
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
      onLongPress: () {
        CreatureDetailsDialog.show(
          context,
          species,
          true,
          instanceId: instance.instanceId,
        );
      },
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
              // sprite area
              Expanded(
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Center(
                        child: sd != null
                            ? InstanceSprite(
                                creature: species,
                                instance: instance,
                                size: 72,
                              )
                            : Image.asset(species.image, fit: BoxFit.contain),
                      ),
                    ),

                    // selected parent chip
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

              // Only show stamina badge if NOT in harvest mode (harvest mode shows it in bottom block)
              if (!_isHarvestMode)
                detailMode == InstanceDetailMode.genetics
                    ? StaminaBadge(
                        instanceId: instance.instanceId,
                        showCountdown: true,
                      )
                    : SizedBox.shrink(),

              if (!_isHarvestMode) const SizedBox(height: 6),

              bottomBlock,
            ],
          ),
        ),
      ),
    );
  }
}

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

        // Nickname row (with lock if locked)
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

        // Stamina badge with countdown
        StaminaBadge(instanceId: instance.instanceId, showCountdown: true),

        // Optional: show quick level line below (tiny)
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

// --- bottom content in STATS mode ---
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

        // Level / XP row
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

        // Individual Stats
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

        // prismatic chip still visible in stats mode
        if (instance.isPrismaticSkin == true) ...[
          const SizedBox(height: 4),
          _PrismaticChip(),
        ],
      ],
    );
  }
}

// --- bottom content in HARVEST mode ---
class _HarvestBlock extends StatelessWidget {
  final FactionTheme theme;
  final CreatureInstance instance;
  final Duration harvestDuration;
  final int Function(CreatureInstance) calculateRate;
  final bool isSelected;
  final int? selectionNumber;

  const _HarvestBlock({
    required this.theme,
    required this.instance,
    required this.harvestDuration,
    required this.calculateRate,
    required this.isSelected,
    required this.selectionNumber,
  });

  @override
  Widget build(BuildContext context) {
    final rate = calculateRate(instance);
    final total = rate * harvestDuration.inMinutes;

    // 🔍 Genetics for size
    final genetics = decodeGenetics(instance.geneticsJson);
    final sizeKey = (genetics?.get('size') ?? 'normal');
    final sizeName = sizeLabels[sizeKey] ?? sizeKey;
    final sizeIcon = sizeIcons[sizeKey] ?? Icons.straighten_rounded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Stamina badge at top in harvest mode
        StaminaBadge(instanceId: instance.instanceId, showCountdown: true),
        const SizedBox(height: 6),

        if (isSelected && selectionNumber != null) ...[
          _ParentChip(selectionNumber: selectionNumber),
          const SizedBox(height: 4),
        ],

        if (instance.isPrismaticSkin == true) ...[
          _PrismaticChip(),
          const SizedBox(height: 4),
        ],

        // Level
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.stars_rounded,
                  size: 12,
                  color: Colors.green.shade400,
                ),
                const SizedBox(width: 4),
                Text(
                  'Lv ${instance.level}',
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),

            // total
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.inventory_2_rounded,
                  size: 12,
                  color: theme.accent.withOpacity(.9),
                ),
                const SizedBox(width: 4),
                Text(
                  'Total: $total',
                  style: TextStyle(
                    color: theme.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 3),

        //add back total harvest
        const SizedBox(height: 3),
        // 🧬 Size (affects harvest)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(sizeIcon, size: 12, color: theme.primary.withOpacity(.9)),
                const SizedBox(width: 4),
                Text(
                  sizeName,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            // Nature if present
            if (instance.natureId != null && instance.natureId!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  Icon(
                    Icons.psychology_rounded,
                    size: 12,
                    color: theme.primary.withOpacity(.8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    instance.natureId!,
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ],
        ),
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

// --- bottom content in GENETICS mode ---
class _GeneticsBlock extends StatelessWidget {
  final FactionTheme theme;
  final CreatureInstance instance;
  final Genetics? genetics;
  final IconData Function(Genetics? g) getSizeIcon;
  final String Function(Genetics? g) getSizeName;
  final IconData Function(Genetics? g) getTintIcon;
  final String Function(Genetics? g) getTintName;
  final bool isSelected;
  final int? selectionNumber;

  const _GeneticsBlock({
    required this.theme,
    required this.instance,
    required this.genetics,
    required this.getSizeIcon,
    required this.getSizeName,
    required this.getTintIcon,
    required this.getTintName,
    required this.isSelected,
    required this.selectionNumber,
  });

  @override
  Widget build(BuildContext context) {
    final sizeName = getSizeName(genetics);
    final tintName = getTintName(genetics);
    final sizeIcon = getSizeIcon(genetics);
    final tintIcon = getTintIcon(genetics);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isSelected && selectionNumber != null) ...[
          _ParentChip(selectionNumber: selectionNumber),
          const SizedBox(height: 4),
        ],

        if (instance.isPrismaticSkin == true) ...[
          _PrismaticChip(),
          const SizedBox(height: 4),
        ],

        _InfoRow(
          icon: sizeIcon,
          label: sizeName,
          color: theme.primary,
          textColor: theme.text,
        ),
        const SizedBox(height: 3),
        _InfoRow(
          icon: tintIcon,
          label: tintName,
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

// shared mini chips
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

// reused genetics row
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
