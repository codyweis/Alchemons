// lib/widgets/instance_widgets/instances_sheet.dart
//
// REDESIGNED INSTANCES SHEET
// Aesthetic: Scorched Forge — matches survival / boss / formation / dialog
// Only the chrome (search bar, filters pill, detail mode toggle) is restyled.
// All grid/card child widgets, logic, filtering, sorting, and state preserved.
//

import 'dart:async' as async;
import 'dart:convert';

import 'package:alchemons/database/daos/creature_dao.dart';
import 'package:alchemons/widgets/creature_selection_sheet.dart';
import 'package:alchemons/widgets/instance_widgets/instance_sheet_components.dart';
import 'package:alchemons/widgets/instance_widgets/intance_filter_panel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import 'package:alchemons/widgets/creature_detail/creature_dialog.dart';

// ──────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS  (inline — no import needed, keeps file self-contained)
// ──────────────────────────────────────────────────────────────────────────────

class _C {
  static const textSecondary = Color(0xFF8A7B6A);
}

class _T {
  static const label = TextStyle(
    fontFamily: 'monospace',
    color: _C.textSecondary,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// WIDGET
// ──────────────────────────────────────────────────────────────────────────────

class InstancesSheet extends StatefulWidget {
  final Creature species;
  final FactionTheme theme;
  final List<String> selectedInstanceIds;
  final void Function(CreatureInstance inst) onTap;
  final bool selectionMode;
  final InstanceDetailMode initialDetailMode;
  final Duration? harvestDuration;
  final List<String>? busyInstanceIds;
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
  ForgeTokens get t => ForgeTokens(widget.theme);

  SortBy _sortBy = SortBy.newest;

  late TextEditingController _searchController;

  bool _filtersOpen = false;
  String _searchText = '';
  String? _filterSize;
  String? _filterTint;
  String? _filterNature;
  bool _filterPrismatic = false;
  String? _filterVariant;

  late final List<String> _sizeCycle = sizeLabels.keys.toList(growable: false);
  late final List<String> _tintCycle = tintLabels.keys.toList(growable: false);

  static const List<String> _variantGroups = [
    'Volcanic',
    'Oceanic',
    'Earthen',
    'Verdant',
    'Arcane',
  ];
  late final List<String?> _variantCycle = <String?>[null, ..._variantGroups];

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
  String get _prefsKey => 'instances_filters';

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
      orElse: () => widget.initialDetailMode,
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
    _settings = context.read<AlchemonsDatabase>().settingsDao;
    () async {
      final raw = await _settings.getSetting(_prefsKey);
      if (!mounted || raw == null || raw.isEmpty) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      setState(() => _fromPrefs(map));
      if (mounted) _searchController.text = _searchText;
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
      out[def.id] = def.id.toUpperCase();
    }
    final sorted = out.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return Map<String, String>.fromEntries(sorted);
  }

  // ── BUILD ────────────────────────────────────────────────────────────────

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
            // ── Filtering + sorting (unchanged logic) ─────────────────────
            var visible = [...instances];

            if (_isHarvestMode && widget.busyInstanceIds != null) {
              visible = visible
                  .where(
                    (inst) =>
                        !widget.busyInstanceIds!.contains(inst.instanceId),
                  )
                  .toList();
            }

            if (_searchText.trim().isNotEmpty) {
              final query = _searchText.trim().toLowerCase();
              visible = visible.where((inst) {
                final g = decodeGenetics(inst.geneticsJson);
                final tokens = <String>[
                  sizeLabels[g?.get('size') ?? ''] ?? '',
                  tintLabels[g?.get('tinting') ?? ''] ?? '',
                  inst.natureId ?? '',
                  'LV ${inst.level}',
                  inst.instanceId,
                  inst.nickname ?? inst.baseId,
                ].join(' ').toLowerCase();
                return tokens.contains(query);
              }).toList();
            }

            visible = visible.where((inst) {
              if (_filterPrismatic && inst.isPrismaticSkin != true)
                return false;
              final hasVariant = inst.variantFaction?.isNotEmpty == true;
              if (_filterVariant == '__NON__') {
                if (hasVariant) return false;
              } else if (_filterVariant != null) {
                if (!hasVariant) return false;
                if (inst.variantFaction!.trim().toLowerCase() !=
                    _filterVariant!.toLowerCase())
                  return false;
              }
              final g = decodeGenetics(inst.geneticsJson);
              if (_filterSize != null && g?.get('size') != _filterSize)
                return false;
              if (_filterTint != null && g?.get('tinting') != _filterTint)
                return false;
              if (_filterNature != null && inst.natureId != _filterNature)
                return false;
              return true;
            }).toList();

            switch (_sortBy) {
              case SortBy.newest:
                visible.sort(
                  (a, b) => b.createdAtUtcMs.compareTo(a.createdAtUtcMs),
                );
              case SortBy.oldest:
                visible.sort(
                  (a, b) => a.createdAtUtcMs.compareTo(b.createdAtUtcMs),
                );
              case SortBy.levelHigh:
                visible.sort((a, b) => b.level.compareTo(a.level));
              case SortBy.levelLow:
                visible.sort((a, b) => a.level.compareTo(b.level));
              case SortBy.statBeauty:
                visible.sort((a, b) => b.statBeauty.compareTo(a.statBeauty));
              case SortBy.statSpeed:
                visible.sort((a, b) => b.statSpeed.compareTo(a.statSpeed));
              case SortBy.statStrength:
                visible.sort(
                  (a, b) => b.statStrength.compareTo(a.statStrength),
                );
              case SortBy.statIntelligence:
                visible.sort(
                  (a, b) => b.statIntelligence.compareTo(a.statIntelligence),
                );
            }

            final hasFiltersActive = _isHarvestMode
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
                // ── TOP CHROME ───────────────────────────────────────────
                _buildTopBar(hasFiltersActive),

                // ── FILTER PANEL ─────────────────────────────────────────
                if (_filtersOpen) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InstanceFiltersPanel(
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
                        () =>
                            _filterVariant = _cycleNextVariant(_filterVariant),
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
                  ),
                ],

                const SizedBox(height: 6),

                // ── GRID ─────────────────────────────────────────────────
                Expanded(
                  child: visible.isEmpty
                      ? InstancesEmptyState(
                          primaryColor: widget.theme.primary,
                          hasFilters: hasFiltersActive,
                        )
                      : GridView.builder(
                          controller: scrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                          itemCount: visible.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 1,
                                crossAxisSpacing: 6,
                                mainAxisSpacing: 6,
                              ),
                          itemBuilder: (_, i) {
                            final inst = visible[i];
                            final isSelected = widget.selectedInstanceIds
                                .contains(inst.instanceId);
                            final selIndex = widget.selectedInstanceIds.indexOf(
                              inst.instanceId,
                            );
                            final selectionNumber =
                                (selIndex >= 0 && selIndex < 3)
                                ? selIndex + 1
                                : null;

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
                                      hasMatchingElement: true,
                                    )
                                  : null,
                              onTap: () async {
                                if (widget.requireStamina) {
                                  final row = await db.creatureDao.getInstance(
                                    inst.instanceId,
                                  );
                                  if (row == null) return;
                                  final state = stamina.computeState(row);
                                  if (state.bars < 1) {
                                    final now = DateTime.now().toUtc();
                                    final next = state.nextTickUtc ?? now;
                                    final mins = next
                                        .difference(now)
                                        .inMinutes
                                        .clamp(0, 999);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(
                                      context,
                                    ).showSnackBar(_staminaSnackBar(mins));
                                    return;
                                  }
                                }
                                widget.onTap(inst);
                              },
                              onLongPress: () => CreatureDetailsDialog.show(
                                context,
                                widget.species,
                                true,
                                instanceId: inst.instanceId,
                              ),
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

  // ── TOP CHROME ─────────────────────────────────────────────────────────────

  Widget _buildTopBar(bool hasFiltersActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          // Search field
          Expanded(child: _buildSearchField()),
          const SizedBox(width: 6),
          // Detail mode toggle (non-harvest only)
          if (!_isHarvestMode) ...[
            _buildDetailModeToggle(),
            const SizedBox(width: 6),
          ],
          // Filters toggle
          _buildFiltersToggle(hasFiltersActive),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: t.bg2,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: t.borderDim),
      ),
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.only(left: 10),
            child: Icon(Icons.search_rounded, size: 14, color: t.textMuted),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                fontFamily: 'monospace',
                color: t.textPrimary,
                fontSize: 12,
                letterSpacing: 0.4,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                hintText: 'SEARCH TRAITS / NATURE / LV',
                hintStyle: _T.label.copyWith(fontSize: 9, letterSpacing: 0.8),
              ),
              onChanged: (val) => _mutate(() => _searchText = val),
            ),
          ),
          if (_searchText.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                _mutate(() => _searchText = '');
              },
              child: Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.close_rounded, size: 13, color: t.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailModeToggle() {
    final label = switch (_detailMode) {
      InstanceDetailMode.info => 'INFO',
      InstanceDetailMode.stats => 'STATS',
      InstanceDetailMode.genetics => 'GENES',
    };
    // Each mode gets a distinct accent so it's not just a text change
    final color = switch (_detailMode) {
      InstanceDetailMode.info => t.textSecondary,
      InstanceDetailMode.stats => t.amberBright,
      InstanceDetailMode.genetics => const Color(0xFF34D399), // teal-green
    };

    return GestureDetector(
      onTap: () => _mutate(() {
        _detailMode = switch (_detailMode) {
          InstanceDetailMode.info => InstanceDetailMode.stats,
          InstanceDetailMode.stats => InstanceDetailMode.genetics,
          InstanceDetailMode.genetics => InstanceDetailMode.info,
        };
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: t.bg3,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: _detailMode == InstanceDetailMode.info
                ? t.borderDim
                : color.withOpacity(0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersToggle(bool hasFiltersActive) {
    return GestureDetector(
      onTap: () => _mutate(() => _filtersOpen = !_filtersOpen),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: hasFiltersActive ? t.amber.withOpacity(0.12) : t.bg2,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: hasFiltersActive ? t.borderAccent : t.borderDim,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list_rounded,
              size: 14,
              color: hasFiltersActive ? t.amberBright : t.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              'FILTER',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: hasFiltersActive ? t.amberBright : t.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              _filtersOpen
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: hasFiltersActive ? t.amberBright : t.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  // ── STAMINA SNACK BAR ──────────────────────────────────────────────────────

  SnackBar _staminaSnackBar(int mins) => SnackBar(
    content: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: t.bg1,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Icon(
            Icons.hourglass_bottom_rounded,
            color: t.amberBright,
            size: 14,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'SPECIMEN RESTING  ·  NEXT STAMINA ~${mins}M',
            style: TextStyle(
              fontFamily: 'monospace',
              color: t.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    ),
    backgroundColor: t.amber,
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
    margin: const EdgeInsets.all(14),
  );
}
