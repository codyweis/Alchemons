// lib/games/survival/survival_formation_selector_screen.dart
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/database/daos/creature_dao.dart';
import 'package:alchemons/games/survival/survival_engine.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_detail/creature_dialog.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/instance_widgets/intance_filter_panel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SurvivalFormationSelectorScreen extends StatefulWidget {
  const SurvivalFormationSelectorScreen({super.key});

  @override
  State<SurvivalFormationSelectorScreen> createState() =>
      _SurvivalFormationSelectorScreenState();
}

class _SurvivalFormationSelectorScreenState
    extends State<SurvivalFormationSelectorScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  SortBy _sortBy = SortBy.levelHigh;
  bool _filterPrismatic = false;
  String? _filterSize;
  String? _filterTint;
  String? _filterVariant;
  String? _filterNature;

  /// 0–3: active (FormationPosition indices)
  final Map<int, String> _activeSlots = {};

  /// 0–3: bench slots (local indices), we’ll encode them differently when we return.
  final Map<int, String> _benchSlots = {};

  bool get _hasFullActive => _activeSlots.length == 4;
  int get _totalSelected => _activeSlots.length + _benchSlots.length;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    final db = context.watch<AlchemonsDatabase>();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.4),
            radius: 1.2,
            colors: [theme.surfaceAlt, theme.surface, Colors.black],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(theme),
              _buildFormationBar(theme, db),
              const SizedBox(height: 8),
              _buildFiltersPanel(theme),
              const SizedBox(height: 8),
              _buildSearchBar(theme),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<CreatureInstance>>(
                  stream: db.creatureDao.watchAllInstances(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final instances = _applyFiltersAndSort(snapshot.data!);

                    if (instances.isEmpty) {
                      return _buildEmptyState(theme);
                    }

                    return _buildInstanceGrid(theme, instances);
                  },
                ),
              ),
              _buildConfirmButton(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(FactionTheme theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: Colors.white,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Formation & Bench',
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Select 4 active + up to 4 bench',
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (_activeSlots.isNotEmpty || _benchSlots.isNotEmpty)
            TextButton(
              onPressed: () => setState(() {
                _activeSlots.clear();
                _benchSlots.clear();
              }),
              child: Text(
                'Clear All',
                style: TextStyle(color: theme.accent, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFormationBar(FactionTheme theme, AlchemonsDatabase db) {
    final repo = context.watch<CreatureCatalog>();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surfaceAlt.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _hasFullActive ? Colors.green : theme.border,
          width: 2,
        ),
      ),
      child: FutureBuilder<List<CreatureInstance>>(
        future: db.creatureDao.getAllInstances(),
        builder: (context, snapshot) {
          final allInstances = snapshot.data ?? [];

          return Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.grid_4x4,
                    color: _hasFullActive ? Colors.green : theme.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${_activeSlots.length}/4)',
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildCompactSlot(
                      theme,
                      FormationPosition.frontLeft,
                      'Front L',
                      allInstances,
                      repo,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCompactSlot(
                      theme,
                      FormationPosition.frontRight,
                      'Front R',
                      allInstances,
                      repo,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCompactSlot(
                      theme,
                      FormationPosition.backLeft,
                      'Back L',
                      allInstances,
                      repo,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCompactSlot(
                      theme,
                      FormationPosition.backRight,
                      'Back R',
                      allInstances,
                      repo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.chair_alt_rounded,
                    color: _benchSlots.isNotEmpty
                        ? Colors.orangeAccent
                        : theme.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Bench (${_benchSlots.length}/4)',
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildBenchSlot(theme, 0, 'B1', allInstances, repo),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBenchSlot(theme, 1, 'B2', allInstances, repo),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBenchSlot(theme, 2, 'B3', allInstances, repo),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBenchSlot(theme, 3, 'B4', allInstances, repo),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBenchSlot(
    FactionTheme theme,
    int benchIndex,
    String label,
    List<CreatureInstance> allInstances,
    CreatureCatalog repo,
  ) {
    final instanceId = _benchSlots[benchIndex];
    final instance = instanceId != null
        ? allInstances.firstWhere(
            (inst) => inst.instanceId == instanceId,
            orElse: () => allInstances.first,
          )
        : null;

    if (instance == null) {
      return Container(
        height: 60,
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.border, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: theme.textMuted, size: 18),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final species = repo.getCreatureById(instance.baseId);

    return GestureDetector(
      onTap: () => setState(() => _benchSlots.remove(benchIndex)),
      child: Container(
        height: 60,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orangeAccent, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.orangeAccent.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (species != null)
              Expanded(
                child: InstanceSprite(
                  creature: species,
                  instance: instance,
                  size: 24,
                ),
              )
            else
              const Icon(Icons.help_outline, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactSlot(
    FactionTheme theme,
    FormationPosition position,
    String label,
    List<CreatureInstance> allInstances,
    CreatureCatalog repo,
  ) {
    final instanceId = _activeSlots[position.index];

    final instance = instanceId != null
        ? allInstances.firstWhere(
            (inst) => inst.instanceId == instanceId,
            orElse: () => allInstances.first,
          )
        : null;

    if (instance == null) {
      return Container(
        height: 70,
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.border, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: theme.textMuted, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final species = repo.getCreatureById(instance.baseId);

    return GestureDetector(
      onTap: () => setState(() => _activeSlots.remove(position.index)),
      child: Container(
        height: 70,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (species != null)
              Expanded(
                child: InstanceSprite(
                  creature: species,
                  instance: instance,
                  size: 32,
                ),
              )
            else
              const Icon(Icons.help_outline, size: 32),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersPanel(FactionTheme theme) {
    return InstanceFiltersPanel(
      theme: theme,
      sortBy: _sortBy,
      onSortChanged: (sort) => setState(() => _sortBy = sort),
      harvestMode: false,
      filterPrismatic: _filterPrismatic,
      onTogglePrismatic: () =>
          setState(() => _filterPrismatic = !_filterPrismatic),
      sizeValueText: _filterSize != null ? 'Size: $_filterSize' : null,
      onCycleSize: () => setState(() {
        _filterSize = switch (_filterSize) {
          null => 'XS',
          'XS' => 'S',
          'S' => 'M',
          'M' => 'L',
          'L' => 'XL',
          'XL' => null,
          _ => null,
        };
      }),
      tintValueText: _filterTint != null ? 'Tint: $_filterTint' : null,
      onCycleTint: () => setState(() {
        _filterTint = switch (_filterTint) {
          null => 'Red',
          'Red' => 'Orange',
          'Orange' => 'Yellow',
          'Yellow' => 'Green',
          'Green' => 'Blue',
          'Blue' => 'Purple',
          'Purple' => 'Pink',
          'Pink' => null,
          _ => null,
        };
      }),
      variantValueText: _filterVariant != null
          ? 'Variant: $_filterVariant'
          : null,
      onCycleVariant: () => setState(() {
        _filterVariant = switch (_filterVariant) {
          null => 'Alpha',
          'Alpha' => 'Beta',
          'Beta' => 'Gamma',
          'Gamma' => null,
          _ => null,
        };
      }),
      filterNature: _filterNature,
      onPickNature: (nature) => setState(() => _filterNature = nature),
      natureOptions: const {
        'hardy': 'Hardy',
        'bold': 'Bold',
        'modest': 'Modest',
        'calm': 'Calm',
        'timid': 'Timid',
      },
      onClearAll: () => setState(() {
        _filterPrismatic = false;
        _filterSize = null;
        _filterTint = null;
        _filterVariant = null;
        _filterNature = null;
      }),
    );
  }

  Widget _buildSearchBar(FactionTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: TextStyle(color: theme.text, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search creatures...',
          hintStyle: TextStyle(color: theme.textMuted),
          prefixIcon: Icon(Icons.search, color: theme.textMuted),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: theme.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: theme.surfaceAlt,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: theme.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: theme.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: theme.accent),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildInstanceGrid(
    FactionTheme theme,
    List<CreatureInstance> instances,
  ) {
    final repo = context.watch<CreatureCatalog>();
    final selectedIds = {..._activeSlots.values, ..._benchSlots.values};

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: instances.length,
      itemBuilder: (context, index) {
        final instance = instances[index];
        final species = repo.getCreatureById(instance.baseId);
        final isSelected = selectedIds.contains(instance.instanceId);

        return _buildInstanceCard(theme, species, instance, isSelected);
      },
    );
  }

  Widget _buildInstanceCard(
    FactionTheme theme,
    Creature? species,
    CreatureInstance instance,
    bool isSelected,
  ) {
    final isInActive = _activeSlots.containsValue(instance.instanceId);
    final isInBench = _benchSlots.containsValue(instance.instanceId);
    final canSelectActive = !isSelected && _activeSlots.length < 4;
    final canSelectBench = !isSelected && _benchSlots.length < 4;
    final canSelect = !isSelected && (canSelectActive || canSelectBench);

    return GestureDetector(
      onLongPress: () => CreatureDetailsDialog.show(
        context,
        species!,
        true,
        instanceId: instance.instanceId,
        openBattleTab: true,
      ),
      onTap: () {
        if (isSelected) {
          // Remove from whichever slot it's in
          setState(() {
            _activeSlots.removeWhere((_, id) => id == instance.instanceId);
            _benchSlots.removeWhere((_, id) => id == instance.instanceId);
          });
        } else if (canSelect) {
          setState(() {
            // Fill active first, then bench
            if (_activeSlots.length < 4) {
              final nextSlot = _getNextAvailableActiveSlot();
              if (nextSlot != null) {
                _activeSlots[nextSlot.index] = instance.instanceId;
              }
            } else if (_benchSlots.length < 4) {
              final nextBenchIdx = _getNextAvailableBenchIndex();
              if (nextBenchIdx != null) {
                _benchSlots[nextBenchIdx] = instance.instanceId;
              }
            }
          });
        }
      },
      child: Opacity(
        opacity: (!canSelect && !isSelected) ? 0.4 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.green : theme.border,
              width: isSelected ? 2.5 : 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (species != null)
                Expanded(
                  child: InstanceSprite(
                    creature: species,
                    instance: instance,
                    size: 56,
                  ),
                )
              else
                const Icon(Icons.help_outline, size: 56),
              const SizedBox(height: 6),
              Text(
                species?.name ?? 'Unknown',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                'Lv ${instance.level}',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getSlotLabelForInstance(instance.instanceId),
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getSlotLabelForInstance(String instanceId) {
    final activePos = _findActiveSlotForInstance(instanceId);
    if (activePos != null) return _getSlotLabel(activePos);

    final benchIdx = _findBenchSlotForInstance(instanceId);
    if (benchIdx != null) return 'B${benchIdx + 1}';

    return '';
  }

  FormationPosition? _findActiveSlotForInstance(String instanceId) {
    for (final entry in _activeSlots.entries) {
      if (entry.value == instanceId) {
        return FormationPosition.values[entry.key];
      }
    }
    return null;
  }

  int? _findBenchSlotForInstance(String instanceId) {
    for (final entry in _benchSlots.entries) {
      if (entry.value == instanceId) return entry.key;
    }
    return null;
  }

  FormationPosition? _getNextAvailableActiveSlot() {
    for (final position in FormationPosition.values) {
      if (!_activeSlots.containsKey(position.index)) {
        return position;
      }
    }
    return null;
  }

  int? _getNextAvailableBenchIndex() {
    for (int i = 0; i < 4; i++) {
      if (!_benchSlots.containsKey(i)) return i;
    }
    return null;
  }

  String _getSlotLabel(FormationPosition? position) {
    if (position == null) return '';
    switch (position) {
      case FormationPosition.frontLeft:
        return 'FL';
      case FormationPosition.frontRight:
        return 'FR';
      case FormationPosition.backLeft:
        return 'BL';
      case FormationPosition.backRight:
        return 'BR';
    }
  }

  Widget _buildConfirmButton(FactionTheme theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(top: BorderSide(color: theme.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _hasFullActive
              ? () {
                  final result = <int, String>{};

                  // 0–3: active (same as before)
                  result.addAll(_activeSlots);

                  // 100–103: bench slots (encoded)
                  _benchSlots.forEach((benchIdx, id) {
                    result[100 + benchIdx] = id;
                  });

                  Navigator.of(context).pop(result);
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            disabledBackgroundColor: theme.surfaceAlt,
            disabledForegroundColor: theme.textMuted,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.check_rounded, size: 24),
          label: Text(
            _hasFullActive
                ? 'Confirm Formation'
                : 'Select ${4 - _activeSlots.length} More',
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(FactionTheme theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pets_outlined,
            size: 64,
            color: theme.textMuted.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No creatures found',
            style: TextStyle(
              color: theme.textMuted,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
            style: TextStyle(
              color: theme.textMuted.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  List<CreatureInstance> _applyFiltersAndSort(
    List<CreatureInstance> instances,
  ) {
    var filtered = instances;

    if (_searchQuery.isNotEmpty) {
      final repo = context.read<CreatureCatalog>();
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((instance) {
        final species = repo.getCreatureById(instance.baseId);
        if (species == null) return false;

        return species.name.toLowerCase().contains(query) ||
            species.types.any((type) => type.toLowerCase().contains(query)) ||
            (instance.nickname?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    if (_filterPrismatic) {
      filtered = filtered.where((i) => i.isPrismaticSkin).toList();
    }
    if (_filterSize != null) {
      filtered = filtered
          .where((i) => decodeGenetics(i.geneticsJson)?.size == _filterSize)
          .toList();
    }
    if (_filterTint != null) {
      filtered = filtered
          .where((i) => decodeGenetics(i.geneticsJson)?.tinting == _filterTint)
          .toList();
    }
    if (_filterVariant != null) {
      filtered = filtered
          .where((i) => i.variantFaction == _filterVariant)
          .toList();
    }
    if (_filterNature != null) {
      filtered = filtered.where((i) => i.natureId == _filterNature).toList();
    }

    filtered.sort((a, b) {
      switch (_sortBy) {
        case SortBy.newest:
          return b.createdAtUtcMs.compareTo(a.createdAtUtcMs);
        case SortBy.oldest:
          return a.createdAtUtcMs.compareTo(b.createdAtUtcMs);
        case SortBy.levelHigh:
          return b.level.compareTo(a.level);
        case SortBy.levelLow:
          return a.level.compareTo(b.level);
        case SortBy.statSpeed:
          return b.statSpeed.compareTo(a.statSpeed);
        case SortBy.statIntelligence:
          return b.statIntelligence.compareTo(a.statIntelligence);
        case SortBy.statStrength:
          return b.statStrength.compareTo(a.statStrength);
        case SortBy.statBeauty:
          return b.statBeauty.compareTo(a.statBeauty);
      }
    });

    return filtered;
  }
}
