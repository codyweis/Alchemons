// lib/games/survival/survival_formation_selector_screen.dart
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/database/daos/creature_dao.dart';
import 'package:alchemons/games/survival/survival_engine.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
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
  final Map<int, String> _formationSlots = {};

  bool get _isFormationComplete => _formationSlots.length == 4;

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
              Expanded(child: Center(child: _buildFormationPreview(theme, db))),
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Formation Setup',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Tap slots to select creatures',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormationPreview(FactionTheme theme, AlchemonsDatabase db) {
    final repo = context.watch<CreatureCatalog>();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.surfaceAlt.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isFormationComplete ? Colors.green : theme.border,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.grid_4x4,
                color: _isFormationComplete ? Colors.green : theme.textMuted,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Formation (${_formationSlots.length}/4)',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (_formationSlots.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _formationSlots.clear()),
                  child: Text(
                    'Clear',
                    style: TextStyle(color: theme.textMuted, fontSize: 13),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          FutureBuilder<List<CreatureInstance>>(
            future: db.creatureDao.getAllInstances(),
            builder: (context, snapshot) {
              final allInstances = snapshot.data ?? [];

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'FRONT ROW (75% targeted)',
                      style: TextStyle(
                        color: theme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFormationSlot(
                          theme,
                          FormationPosition.frontLeft,
                          allInstances,
                          repo,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildFormationSlot(
                          theme,
                          FormationPosition.frontRight,
                          allInstances,
                          repo,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'BACK ROW (25% targeted)',
                      style: TextStyle(
                        color: theme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFormationSlot(
                          theme,
                          FormationPosition.backLeft,
                          allInstances,
                          repo,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildFormationSlot(
                          theme,
                          FormationPosition.backRight,
                          allInstances,
                          repo,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isFormationComplete
                  ? () => Navigator.of(context).pop(_formationSlots)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: theme.surface,
                disabledForegroundColor: theme.textMuted,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.check_rounded, size: 24),
              label: Text(
                _isFormationComplete
                    ? 'Confirm Formation'
                    : 'Select 4 Creatures',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormationSlot(
    FactionTheme theme,
    FormationPosition position,
    List<CreatureInstance> allInstances,
    CreatureCatalog repo,
  ) {
    final instanceId = _formationSlots[position.index];

    if (instanceId == null) {
      return _buildEmptyFormationSlot(theme, position);
    }

    final instance = allInstances
        .where((inst) => inst.instanceId == instanceId)
        .firstOrNull;

    if (instance == null) {
      return _buildEmptyFormationSlot(theme, position);
    }

    final species = repo.getCreatureById(instance.baseId);
    return _buildFilledFormationSlot(theme, position, species, instance);
  }

  Widget _buildEmptyFormationSlot(
    FactionTheme theme,
    FormationPosition position,
  ) {
    return GestureDetector(
      onTap: () => _openCreatureSelectionSheet(position),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.border, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: theme.textMuted, size: 40),
            const SizedBox(height: 8),
            Text(
              _getPositionLabel(position),
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilledFormationSlot(
    FactionTheme theme,
    FormationPosition position,
    Creature? species,
    CreatureInstance instance,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() => _formationSlots.remove(position.index));
      },
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 12,
              spreadRadius: 2,
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
                  size: 48,
                ),
              )
            else
              const Icon(Icons.help_outline, size: 48),
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
            Text(
              'Lv ${instance.level}',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPositionLabel(FormationPosition position) {
    switch (position) {
      case FormationPosition.frontLeft:
        return 'Front Left';
      case FormationPosition.frontRight:
        return 'Front Right';
      case FormationPosition.backLeft:
        return 'Back Left';
      case FormationPosition.backRight:
        return 'Back Right';
    }
  }

  Future<void> _openCreatureSelectionSheet(FormationPosition position) async {
    final selectedInstanceId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CreatureSelectionSheet(
        position: position,
        alreadySelectedIds: _formationSlots.values.toSet(),
      ),
    );

    if (selectedInstanceId != null && mounted) {
      setState(() {
        _formationSlots[position.index] = selectedInstanceId;
      });
    }
  }
}

// Bottom sheet for selecting creatures
class _CreatureSelectionSheet extends StatefulWidget {
  final FormationPosition position;
  final Set<String> alreadySelectedIds;

  const _CreatureSelectionSheet({
    required this.position,
    required this.alreadySelectedIds,
  });

  @override
  State<_CreatureSelectionSheet> createState() =>
      _CreatureSelectionSheetState();
}

class _CreatureSelectionSheetState extends State<_CreatureSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  SortBy _sortBy = SortBy.levelHigh;
  bool _filterPrismatic = false;
  String? _filterSize;
  String? _filterTint;
  String? _filterVariant;
  String? _filterNature;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    final db = context.watch<AlchemonsDatabase>();

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: theme.border, width: 2),
          ),
          child: Column(
            children: [
              _buildSheetHeader(theme),
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

                    return _buildInstanceGrid(
                      theme,
                      instances,
                      scrollController,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetHeader(FactionTheme theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.border)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.textMuted.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.pets, color: theme.accent, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Creature',
                      style: TextStyle(
                        color: theme.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _getPositionLabel(widget.position),
                      style: TextStyle(color: theme.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                color: theme.textMuted,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getPositionLabel(FormationPosition position) {
    switch (position) {
      case FormationPosition.frontLeft:
        return 'Front Left (75% targeted)';
      case FormationPosition.frontRight:
        return 'Front Right (75% targeted)';
      case FormationPosition.backLeft:
        return 'Back Left (25% targeted)';
      case FormationPosition.backRight:
        return 'Back Right (25% targeted)';
    }
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
    ScrollController scrollController,
  ) {
    final repo = context.watch<CreatureCatalog>();

    return GridView.builder(
      controller: scrollController,
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
        final isAlreadySelected = widget.alreadySelectedIds.contains(
          instance.instanceId,
        );

        return _buildInstanceCard(theme, species, instance, isAlreadySelected);
      },
    );
  }

  Widget _buildInstanceCard(
    FactionTheme theme,
    Creature? species,
    CreatureInstance instance,
    bool isAlreadySelected,
  ) {
    return GestureDetector(
      onTap: isAlreadySelected
          ? null
          : () => Navigator.of(context).pop(instance.instanceId),
      child: Opacity(
        opacity: isAlreadySelected ? 0.4 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAlreadySelected ? theme.textMuted : theme.border,
              width: 1.5,
            ),
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
              if (instance.nickname != null) ...[
                const SizedBox(height: 2),
                Text(
                  instance.nickname!,
                  style: TextStyle(color: theme.textMuted, fontSize: 9),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (isAlreadySelected) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.textMuted.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'SELECTED',
                    style: TextStyle(
                      color: theme.textMuted,
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
