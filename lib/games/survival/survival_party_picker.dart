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

  /// Selected creature instance IDs for the squad
  final List<String> _selectedCreatures = [];

  // ═══════════════════════════════════════════════════════════════════════════
  // CONFIGURABLE LIMITS
  // ═══════════════════════════════════════════════════════════════════════════
  static const int minSquadSize = 4; // Minimum needed to start
  static const int maxSquadSize = 10; // Maximum squad size

  bool get _hasMinimumSquad => _selectedCreatures.length >= minSquadSize;
  int get _totalSelected => _selectedCreatures.length;

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
                  'Assemble Your Squad',
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Select $minSquadSize-$maxSquadSize creatures for battle',
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (_selectedCreatures.isNotEmpty)
            TextButton(
              onPressed: () => setState(() {
                _selectedCreatures.clear();
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
          color: _hasMinimumSquad ? Colors.green : theme.border,
          width: 2,
        ),
      ),
      child: FutureBuilder<List<CreatureInstance>>(
        future: db.creatureDao.getAllInstances(),
        builder: (context, snapshot) {
          final allInstances = snapshot.data ?? [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.groups_rounded,
                    color: _hasMinimumSquad ? Colors.green : theme.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Your Squad (${_selectedCreatures.length}/$maxSquadSize)',
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (!_hasMinimumSquad)
                    Text(
                      'Need ${minSquadSize - _selectedCreatures.length} more',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Squad slots - 2 rows of 5
              Row(
                children: List.generate(5, (index) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: index < 4 ? 8 : 0),
                      child: _buildSquadSlot(theme, index, allInstances, repo),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(5, (index) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: index < 4 ? 8 : 0),
                      child: _buildSquadSlot(
                        theme,
                        index + 5,
                        allInstances,
                        repo,
                      ),
                    ),
                  );
                }),
              ),

              // Hint text
              const SizedBox(height: 12),
              Text(
                'You\'ll choose deployment positions in the next step',
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSquadSlot(
    FactionTheme theme,
    int slotIndex,
    List<CreatureInstance> allInstances,
    CreatureCatalog repo,
  ) {
    final instanceId = slotIndex < _selectedCreatures.length
        ? _selectedCreatures[slotIndex]
        : null;

    final instance = instanceId != null
        ? allInstances.firstWhere(
            (inst) => inst.instanceId == instanceId,
            orElse: () => allInstances.first,
          )
        : null;

    // Empty slot
    if (instance == null) {
      final isRequired = slotIndex < minSquadSize;
      return Container(
        height: 60,
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isRequired ? Colors.orange.withOpacity(0.5) : theme.border,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isRequired ? Icons.add_circle_outline : Icons.add,
              color: isRequired
                  ? Colors.orange.withOpacity(0.7)
                  : theme.textMuted,
              size: 18,
            ),
            const SizedBox(height: 2),
            Text(
              '${slotIndex + 1}',
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

    // Filled slot
    final species = repo.getCreatureById(instance.baseId);

    return GestureDetector(
      onTap: () => setState(() {
        _selectedCreatures.remove(instanceId);
      }),
      child: Container(
        height: 60,
        padding: const EdgeInsets.all(4),
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
                  size: 28,
                ),
              )
            else
              const Icon(Icons.help_outline, size: 24),
            Text(
              '${slotIndex + 1}',
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
        final isSelected = _selectedCreatures.contains(instance.instanceId);

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
    final canSelect = !isSelected && _selectedCreatures.length < maxSquadSize;

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
          // Remove from squad
          setState(() {
            _selectedCreatures.remove(instance.instanceId);
          });
        } else if (canSelect) {
          // Add to squad
          setState(() {
            _selectedCreatures.add(instance.instanceId);
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
                    '#${_selectedCreatures.indexOf(instance.instanceId) + 1}',
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
          onPressed: _hasMinimumSquad
              ? () {
                  // Return simple list of instance IDs
                  // The deployment phase will handle positioning
                  final result = <int, String>{};

                  for (int i = 0; i < _selectedCreatures.length; i++) {
                    result[i] = _selectedCreatures[i];
                  }

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
          icon: const Icon(Icons.arrow_forward_rounded, size: 24),
          label: Text(
            _hasMinimumSquad
                ? 'Continue to Deployment (${_selectedCreatures.length} selected)'
                : 'Select ${minSquadSize - _selectedCreatures.length} More',
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
