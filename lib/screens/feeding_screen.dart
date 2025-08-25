import 'dart:convert';

import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/creature_filter_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/stamina_bar.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/alchemons_db.dart';
import '../services/creature_repository.dart';
import '../services/creature_instance_service.dart';
import '../providers/app_providers.dart';
import '../models/creature.dart';
import '../widgets/creature_sprite.dart';

// Genetics utility functions and labels
double scaleFromGenes(Genetics? g) {
  switch (g?.get('size')) {
    case 'tiny':
      return 0.75;
    case 'small':
      return 0.9;
    case 'large':
      return 1.15;
    case 'giant':
      return 1.3;
    default:
      return 1.0;
  }
}

double satFromGenes(Genetics? g) {
  switch (g?.get('tinting')) {
    case 'warm':
    case 'cool':
      return 1.1;
    case 'vibrant':
      return 1.4;
    case 'pale':
      return 0.6;
    default:
      return 1.0;
  }
}

double briFromGenes(Genetics? g) {
  switch (g?.get('tinting')) {
    case 'warm':
    case 'cool':
      return 1.05;
    case 'vibrant':
      return 1.1;
    case 'pale':
      return 1.2;
    default:
      return 1.0;
  }
}

double hueFromGenes(Genetics? g) {
  switch (g?.get('tinting')) {
    case 'warm':
      return 15;
    case 'cool':
      return -15;
    default:
      return 0;
  }
}

class FeedingScreen extends StatefulWidget {
  const FeedingScreen({super.key});

  @override
  State<FeedingScreen> createState() => _FeedingScreenState();
}

class _FeedingScreenState extends State<FeedingScreen>
    with TickerProviderStateMixin {
  String? _targetSpeciesId;
  String? _targetInstanceId;
  Set<String> _selectedFodder = {};
  FeedResult? _preview;
  bool _busy = false;

  // Filter and sort state for species selection
  String _speciesTypeFilter = 'All';
  String _speciesRarityFilter = 'All Rarities';
  String _speciesSortBy = 'Name';
  bool _speciesAscending = true;

  // Filter and sort state for instance grouping
  String _instanceGroupBy = 'Level';
  String _instanceSortBy = 'Level';
  bool _instanceAscending = false;

  late AnimationController _feedButtonController;

  @override
  void initState() {
    super.initState();
    _feedButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _feedButtonController.dispose();
    super.dispose();
  }

  // Helper method to create creature from instance
  Future<Creature?> _createCreatureFromInstance(
    CreatureInstance instance,
  ) async {
    final repo = context.read<CreatureRepository>();
    final base = repo.getCreatureById(instance.baseId);

    if (base == null) return null;

    var creature = base;

    // Apply instance modifications
    if (instance.isPrismaticSkin) {
      creature = creature.copyWith(isPrismaticSkin: true);
    }

    final genetics = _parseGenetics(instance);
    if (genetics != null) {
      final geneticsObj = Genetics(genetics);
      creature = creature.copyWith(genetics: geneticsObj);
    }

    return creature;
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AlchemonsDatabase>();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.indigo.shade50,
              Colors.purple.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildTargetSection(),
              if (_targetInstanceId != null) _buildInstanceGrouping(),
              Expanded(
                child: StreamBuilder<List<CreatureInstance>>(
                  stream: db.watchAllInstances(),
                  builder: (context, snap) {
                    final allInstances =
                        snap.data ?? const <CreatureInstance>[];
                    return _buildMainContent(allInstances);
                  },
                ),
              ),
              if (_targetInstanceId != null) _buildFeedingInterface(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: Colors.indigo.shade600,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Specimen Enhancement Lab',
                  style: TextStyle(
                    color: Colors.indigo.shade800,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Biological enhancement via feeding protocols',
                  style: TextStyle(
                    color: Colors.indigo.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.science_rounded,
              color: Colors.blue.shade600,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetSection() {
    if (_targetSpeciesId == null) {
      return Column(
        children: [
          Column(
            children: [
              Text(
                'Select Target Species',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose specimen for enhancement',
                style: TextStyle(color: Colors.blue.shade600, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildSpeciesFiltersAndSort(),
        ],
      );
    }

    return _buildSelectedTargetCard();
  }

  Widget _buildSelectedTargetCard() {
    final gameState = context.watch<GameStateNotifier>();

    final speciesData = gameState.discoveredCreatures.firstWhere(
      (data) => (data['creature'] as Creature).id == _targetSpeciesId,
      orElse: () => <String, Object>{},
    );

    if (speciesData.isEmpty) return const SizedBox.shrink();

    final creature = speciesData['creature'] as Creature;

    return StreamBuilder<List<CreatureInstance>>(
      stream: context.watch<AlchemonsDatabase>().watchAllInstances(),
      builder: (context, snapshot) {
        final allInstances = snapshot.data ?? <CreatureInstance>[];

        if (_targetInstanceId != null) {
          final targetInstance = allInstances.firstWhere(
            (instance) => instance.instanceId == _targetInstanceId,
            orElse: () => throw Exception('Target instance not found'),
          );

          return _buildDetailedTargetCard(creature, targetInstance);
        }

        return _buildSpeciesTargetCard(creature);
      },
    );
  }

  Widget _buildSpeciesTargetCard(Creature creature) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Use CreatureSprite instead of icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: CreatureFilterUtils.getTypeColor(creature.types.first),
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: creature.spriteData != null
                  ? CreatureSprite(
                      spritePath: creature.image,
                      totalFrames: 1,
                      rows: creature.spriteData!.rows,
                      scale: scaleFromGenes(creature.genetics),
                      saturation: satFromGenes(creature.genetics),
                      brightness: briFromGenes(creature.genetics),
                      hueShift: hueFromGenes(creature.genetics),
                      isPrismatic: creature.isPrismaticSkin,
                      frameSize: Vector2(
                        creature.spriteData!.frameWidth * 1.0,
                        creature.spriteData!.frameHeight * 1.0,
                      ),
                      stepTime: (creature.spriteData!.frameDurationMs / 1000.0),
                    )
                  : Icon(
                      CreatureFilterUtils.getTypeIcon(creature.types.first),
                      size: 24,
                      color: CreatureFilterUtils.getTypeColor(
                        creature.types.first,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  creature.name,
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: creature.types
                      .take(2)
                      .map(
                        (type) => Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: CreatureFilterUtils.getTypeColor(
                              type,
                            ).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              color: CreatureFilterUtils.getTypeColor(type),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select specimen instance',
                  style: TextStyle(
                    color: Colors.green.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _targetSpeciesId = null;
              _targetInstanceId = null;
              _selectedFodder.clear();
              _preview = null;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.swap_horiz_rounded,
                    color: Colors.orange.shade700,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Change',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedTargetCard(
    Creature creature,
    CreatureInstance instance,
  ) {
    final repo = context.watch<CreatureRepository>();
    final base = repo.getCreatureById(instance.baseId);
    final name = base?.name ?? instance.baseId;

    final genetics = _parseGenetics(instance);
    final sizeVariant = _getSizeVariant(genetics);
    final tintingVariant = _getTintingVariant(genetics);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.biotech_rounded,
                color: Colors.blue.shade600,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Target Specimen',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  _targetSpeciesId = null;
                  _targetInstanceId = null;
                  _selectedFodder.clear();
                  _preview = null;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swap_horiz_rounded,
                        color: Colors.orange.shade700,
                        size: 12,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Change',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Use CreatureSprite for the detailed target as well
              FutureBuilder<Creature?>(
                future: _createCreatureFromInstance(instance),
                builder: (context, snapshot) {
                  final effectiveCreature = snapshot.data ?? base;

                  return Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: base != null
                            ? CreatureFilterUtils.getTypeColor(base.types.first)
                            : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: effectiveCreature?.spriteData != null
                          ? CreatureSprite(
                              spritePath: effectiveCreature!
                                  .spriteData!
                                  .spriteSheetPath,
                              totalFrames:
                                  effectiveCreature.spriteData!.totalFrames,
                              rows: effectiveCreature.spriteData!.rows,
                              scale: scaleFromGenes(effectiveCreature.genetics),
                              saturation: satFromGenes(
                                effectiveCreature.genetics,
                              ),
                              brightness: briFromGenes(
                                effectiveCreature.genetics,
                              ),
                              hueShift: hueFromGenes(
                                effectiveCreature.genetics,
                              ),
                              isPrismatic: effectiveCreature.isPrismaticSkin,
                              frameSize: Vector2(
                                effectiveCreature.spriteData!.frameWidth * 1.0,
                                effectiveCreature.spriteData!.frameHeight * 1.0,
                              ),
                              stepTime:
                                  (effectiveCreature
                                      .spriteData!
                                      .frameDurationMs /
                                  1000.0),
                            )
                          : Icon(
                              base != null
                                  ? CreatureFilterUtils.getTypeIcon(
                                      base.types.first,
                                    )
                                  : Icons.help_outline,
                              size: 24,
                              color: base != null
                                  ? CreatureFilterUtils.getTypeColor(
                                      base.types.first,
                                    )
                                  : Colors.grey.shade600,
                            ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Text(
                            'Level ${instance.level}',
                            style: TextStyle(
                              color: Colors.amber.shade700,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Add stamina badge here
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: StaminaBadge(
                        instanceId: instance.instanceId,
                        showCountdown: true,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text(
                            '${instance.xp} XP',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (instance.natureId != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.purple.shade200),
                            ),
                            child: Text(
                              instance.natureId!,
                              style: TextStyle(
                                color: Colors.purple.shade700,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        if (sizeVariant != null) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: '${sizeLabels[sizeVariant]} Specimen',
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.teal.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    sizeIcons[sizeVariant] ?? Icons.circle,
                                    size: 10,
                                    color: Colors.teal.shade700,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    sizeLabels[sizeVariant] ?? sizeVariant,
                                    style: TextStyle(
                                      color: Colors.teal.shade700,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (tintingVariant != null &&
                            tintingVariant != 'normal') ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: '${tintLabels[tintingVariant]} Tinting',
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.cyan.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.cyan.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    tintIcons[tintingVariant] ??
                                        Icons.palette_outlined,
                                    size: 10,
                                    color: Colors.cyan.shade700,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    tintLabels[tintingVariant] ??
                                        tintingVariant,
                                    style: TextStyle(
                                      color: Colors.cyan.shade700,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (instance.isPrismaticSkin) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.pink.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.pink.shade200),
                            ),
                            child: Text(
                              'Prismatic',
                              style: TextStyle(
                                color: Colors.pink.shade700,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeciesFiltersAndSort() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FilterDropdown(
                  hint: 'Type: $_speciesTypeFilter',
                  items: CreatureFilterUtils.filterOptions,
                  selectedValue: _speciesTypeFilter,
                  onChanged: (value) =>
                      setState(() => _speciesTypeFilter = value!),
                  icon: Icons.category_rounded,
                  color: Colors.amber.shade600,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilterDropdown(
                  hint: 'Rarity: $_speciesRarityFilter',
                  items: CreatureFilterUtils.rarityFilters,
                  selectedValue: _speciesRarityFilter,
                  onChanged: (value) =>
                      setState(() => _speciesRarityFilter = value!),
                  icon: Icons.star_rounded,
                  color: Colors.purple.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilterDropdown(
                  hint: 'Sort: $_speciesSortBy',
                  items: const ['Name', 'Rarity', 'Type'],
                  selectedValue: _speciesSortBy,
                  onChanged: (value) => setState(() => _speciesSortBy = value!),
                  icon: Icons.sort_rounded,
                  color: Colors.blue.shade600,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () =>
                    setState(() => _speciesAscending = !_speciesAscending),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200, width: 2),
                  ),
                  child: Icon(
                    _speciesAscending
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.blue.shade600,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstanceGrouping() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: FilterDropdown(
              hint: 'Group: $_instanceGroupBy',
              items: const ['Level', 'Genetics', 'Creation Date'],
              selectedValue: _instanceGroupBy,
              onChanged: (value) => setState(() => _instanceGroupBy = value!),
              icon: Icons.group_work_rounded,
              color: Colors.green.shade600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilterDropdown(
              hint: 'Sort: $_instanceSortBy',
              items: const ['Level', 'Created Date'],
              selectedValue: _instanceSortBy,
              onChanged: (value) => setState(() => _instanceSortBy = value!),
              icon: Icons.sort_rounded,
              color: Colors.blue.shade600,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () =>
                setState(() => _instanceAscending = !_instanceAscending),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200, width: 2),
              ),
              child: Icon(
                _instanceAscending
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: Colors.blue.shade600,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(List<CreatureInstance> allInstances) {
    if (_targetSpeciesId == null) {
      return _buildSpeciesSelectionGrid();
    } else if (_targetInstanceId == null) {
      return _buildTargetInstanceGrid(allInstances);
    } else {
      return _buildFodderGrid(allInstances);
    }
  }

  Widget _buildSpeciesSelectionGrid() {
    final gameState = context.watch<GameStateNotifier>();

    var filteredSpecies = gameState.discoveredCreatures.where((data) {
      final creature = data['creature'] as Creature;

      if (_speciesTypeFilter != 'All' &&
          !creature.types.contains(_speciesTypeFilter)) {
        return false;
      }

      if (_speciesRarityFilter != 'All Rarities' &&
          creature.rarity != _speciesRarityFilter) {
        return false;
      }

      return true;
    }).toList();

    filteredSpecies.sort((a, b) {
      final creatureA = a['creature'] as Creature;
      final creatureB = b['creature'] as Creature;

      int comparison = 0;
      switch (_speciesSortBy) {
        case 'Name':
          comparison = creatureA.name.compareTo(creatureB.name);
          break;
        case 'Rarity':
          comparison = _getRarityOrder(
            creatureA.rarity,
          ).compareTo(_getRarityOrder(creatureB.rarity));
          break;
        case 'Type':
          comparison = creatureA.types.first.compareTo(creatureB.types.first);
          break;
      }

      return _speciesAscending ? comparison : -comparison;
    });

    if (filteredSpecies.isEmpty) {
      return _buildEmptyState('No specimens match current filters');
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.9,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: filteredSpecies.length,
        itemBuilder: (_, i) =>
            _buildSpeciesCard(filteredSpecies[i]['creature'] as Creature),
      ),
    );
  }

  Widget _buildSpeciesCard(Creature creature) {
    return GestureDetector(
      onTap: () => setState(() {
        _targetSpeciesId = creature.id;
        _targetInstanceId = null;
        _selectedFodder.clear();
        _preview = null;
      }),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: CreatureFilterUtils.getTypeColor(
              creature.types.first,
            ).withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: CreatureFilterUtils.getTypeColor(
                creature.types.first,
              ).withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: CreatureFilterUtils.getTypeColor(creature.types.first),
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: creature.spriteData != null
                    ? // just use standard image widget and get imagae path
                      Image.asset('assets/images/${creature.image}')
                    : Icon(
                        CreatureFilterUtils.getTypeIcon(creature.types.first),
                        size: 20,
                        color: CreatureFilterUtils.getTypeColor(
                          creature.types.first,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              creature.name,
              style: TextStyle(
                color: Colors.indigo.shade700,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetInstanceGrid(List<CreatureInstance> allInstances) {
    final speciesInstances = allInstances
        .where((instance) => instance.baseId == _targetSpeciesId)
        .toList();

    if (speciesInstances.isEmpty) {
      return _buildEmptyState('No instances of this species found');
    }

    Map<String, List<CreatureInstance>> groupedInstances = {};

    for (final instance in speciesInstances) {
      String groupKey;
      switch (_instanceGroupBy) {
        case 'Level':
          final levelRange = (instance.level ~/ 10) * 10;
          groupKey = 'Level ${levelRange}-${levelRange + 9}';
          break;
        case 'Genetics':
          groupKey = instance.isPrismaticSkin ? 'Prismatic' : 'Standard';
          break;
        case 'Creation Date':
          final date = DateTime.fromMillisecondsSinceEpoch(
            instance.createdAtUtcMs,
          );
          final now = DateTime.now();
          final diff = now.difference(date).inDays;
          if (diff < 1) {
            groupKey = 'Recent';
          } else if (diff < 7) {
            groupKey = 'This Week';
          } else if (diff < 30) {
            groupKey = 'This Month';
          } else {
            groupKey = 'Archived';
          }
          break;
        default:
          groupKey = 'All';
      }

      groupedInstances.putIfAbsent(groupKey, () => []);
      groupedInstances[groupKey]!.add(instance);
    }

    for (final group in groupedInstances.values) {
      group.sort((a, b) {
        int comparison = 0;
        switch (_instanceSortBy) {
          case 'Level':
            comparison = a.level.compareTo(b.level);
            break;
          case 'Created Date':
            comparison = a.createdAtUtcMs.compareTo(b.createdAtUtcMs);
            break;
        }
        return _instanceAscending ? comparison : -comparison;
      });
    }

    final sortedGroupKeys = groupedInstances.keys.toList()..sort();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Target Specimen',
            style: TextStyle(
              color: Colors.blue.shade700,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: sortedGroupKeys.length,
              itemBuilder: (context, groupIndex) {
                final groupKey = sortedGroupKeys[groupIndex];
                final instances = groupedInstances[groupKey]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: EdgeInsets.only(
                        bottom: 6,
                        top: groupIndex > 0 ? 12 : 0,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getGroupIcon(_instanceGroupBy),
                            color: Colors.green.shade600,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$groupKey (${instances.length})',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.4,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: instances.length,
                      itemBuilder: (_, i) =>
                          _buildTargetInstanceCard(instances[i]),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getGroupIcon(String groupBy) {
    switch (groupBy) {
      case 'Level':
        return Icons.trending_up_rounded;
      case 'Genetics':
        return Icons.auto_awesome_rounded;
      case 'Creation Date':
        return Icons.schedule_rounded;
      default:
        return Icons.group_work_rounded;
    }
  }

  Map<String, String>? _parseGenetics(CreatureInstance instance) {
    if (instance.geneticsJson == null) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(instance.geneticsJson!));
      return map.map((k, v) => MapEntry(k, v.toString()));
    } catch (e) {
      return null;
    }
  }

  String? _getSizeVariant(Map<String, String>? genetics) {
    return genetics?['size'];
  }

  String? _getTintingVariant(Map<String, String>? genetics) {
    return genetics?['tinting'];
  }

  String _getGeneticsQuality(Map<String, String>? genetics) {
    if (genetics == null) return 'standard';

    final size = genetics['size'];
    final tinting = genetics['tinting'];

    if (size == 'tiny' || size == 'giant') return 'rare';
    if (tinting == 'vibrant' || tinting == 'pale') return 'uncommon';
    if (size == 'large' || size == 'small') return 'common';
    if (tinting == 'warm' || tinting == 'cool') return 'common';

    return 'standard';
  }

  Widget _buildTargetInstanceCard(CreatureInstance instance) {
    final repo = context.watch<CreatureRepository>();
    final base = repo.getCreatureById(instance.baseId);
    final name = base?.name ?? instance.baseId;
    final genetics = _parseGenetics(instance);
    final sizeVariant = _getSizeVariant(genetics);
    final tintingVariant = _getTintingVariant(genetics);
    final geneticsQuality = _getGeneticsQuality(genetics);

    return GestureDetector(
      onTap: () => setState(() {
        _targetInstanceId = instance.instanceId;
        _selectedFodder.clear();
        _preview = null;
      }),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade100,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image on the left with level badge overlay
            FutureBuilder<Creature?>(
              future: _createCreatureFromInstance(instance),
              builder: (context, snapshot) {
                final effectiveCreature = snapshot.data ?? base;

                return SizedBox(
                  width: 75,
                  height: 75,
                  child: Stack(
                    children: [
                      Container(
                        width: 75,
                        height: 75,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: base != null
                                ? CreatureFilterUtils.getTypeColor(
                                    base.types.first,
                                  )
                                : Colors.grey.shade400,
                            width: 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: effectiveCreature?.spriteData != null
                              ? CreatureSprite(
                                  spritePath: effectiveCreature!
                                      .spriteData!
                                      .spriteSheetPath,
                                  totalFrames:
                                      effectiveCreature.spriteData!.totalFrames,
                                  rows: effectiveCreature.spriteData!.rows,
                                  scale: scaleFromGenes(
                                    effectiveCreature.genetics,
                                  ),
                                  saturation: satFromGenes(
                                    effectiveCreature.genetics,
                                  ),
                                  brightness: briFromGenes(
                                    effectiveCreature.genetics,
                                  ),
                                  hueShift: hueFromGenes(
                                    effectiveCreature.genetics,
                                  ),
                                  isPrismatic:
                                      effectiveCreature.isPrismaticSkin,
                                  frameSize: Vector2(
                                    effectiveCreature.spriteData!.frameWidth *
                                        1.0,
                                    effectiveCreature.spriteData!.frameHeight *
                                        1.0,
                                  ),
                                  stepTime:
                                      (effectiveCreature
                                          .spriteData!
                                          .frameDurationMs /
                                      1000.0),
                                )
                              : Center(
                                  child: Text(
                                    name.substring(0, 1).toUpperCase(),
                                    style: TextStyle(
                                      color: base != null
                                          ? CreatureFilterUtils.getTypeColor(
                                              base.types.first,
                                            )
                                          : Colors.grey.shade600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      // Level badge overlay in top-left corner
                      Positioned(
                        top: -2,
                        left: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: Colors.amber.shade300,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            'L${instance.level}',
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 10),
            // Details column on the right
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Prismatic
                  if (instance.isPrismaticSkin) ...[
                    Text(
                      '⭐',
                      style: TextStyle(
                        color: Colors.pink.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 4),
                  // XP
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      '${instance.xp} XP',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Nature
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: instance.natureId != null
                          ? Colors.purple.shade50
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: instance.natureId != null
                            ? Colors.purple.shade200
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Text(
                      instance.natureId ?? 'None',
                      style: TextStyle(
                        color: instance.natureId != null
                            ? Colors.purple.shade700
                            : Colors.grey.shade600,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Size
                  if (genetics != null && sizeVariant != null) ...[
                    const SizedBox(height: 3),
                    Tooltip(
                      message: '${sizeLabels[sizeVariant]} Specimen',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getSizeColor(sizeVariant),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              sizeIcons[sizeVariant] ?? Icons.circle,
                              size: 8,
                              color: _getSizeTextColor(sizeVariant),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              sizeLabels[sizeVariant] ?? sizeVariant,
                              style: TextStyle(
                                color: _getSizeTextColor(sizeVariant),
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  // Tinting
                  if (genetics != null && tintingVariant != null) ...[
                    const SizedBox(height: 3),
                    Tooltip(
                      message: '${tintLabels[tintingVariant]} Tinting',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getTintingColor(tintingVariant),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              tintIcons[tintingVariant] ??
                                  Icons.palette_outlined,
                              size: 8,
                              color: _getTintingTextColor(tintingVariant),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              tintLabels[tintingVariant] ?? tintingVariant,
                              style: TextStyle(
                                color: _getTintingTextColor(tintingVariant),
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
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
      ),
    );
  }

  Widget _buildFodderCard(CreatureInstance instance) {
    final repo = context.watch<CreatureRepository>();
    final base = repo.getCreatureById(instance.baseId);
    final name = base?.name ?? instance.baseId;
    final isSelected = _selectedFodder.contains(instance.instanceId);
    final genetics = _parseGenetics(instance);
    final sizeVariant = _getSizeVariant(genetics);
    final tintingVariant = _getTintingVariant(genetics);

    return GestureDetector(
      onTap: () async {
        setState(() {
          if (isSelected) {
            _selectedFodder.remove(instance.instanceId);
          } else {
            _selectedFodder.add(instance.instanceId);
          }
        });
        await _updatePreview();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10), // Increased back to 10
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.green.shade50
              : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Colors.green.shade400
                : base != null
                ? CreatureFilterUtils.getTypeColor(
                    base.types.first,
                  ).withOpacity(0.3)
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? Colors.green.shade200 : Colors.grey.shade100,
              blurRadius: isSelected ? 6 : 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            FutureBuilder<Creature?>(
              future: _createCreatureFromInstance(instance),
              builder: (context, snapshot) {
                final effectiveCreature = snapshot.data ?? base;

                return SizedBox(
                  height: 80, // Increased from 64
                  width: 80, // Increased from 64
                  child: Stack(
                    children: [
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          width: 70, // Increased from 56
                          height: 70, // Increased from 56
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: base != null
                                  ? CreatureFilterUtils.getTypeColor(
                                      base.types.first,
                                    )
                                  : Colors.grey.shade400,
                              width: 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: effectiveCreature?.spriteData != null
                                ? CreatureSprite(
                                    spritePath: effectiveCreature!
                                        .spriteData!
                                        .spriteSheetPath,
                                    totalFrames: effectiveCreature
                                        .spriteData!
                                        .totalFrames,
                                    rows: effectiveCreature.spriteData!.rows,
                                    scale: scaleFromGenes(
                                      effectiveCreature.genetics,
                                    ),
                                    saturation: satFromGenes(
                                      effectiveCreature.genetics,
                                    ),
                                    brightness: briFromGenes(
                                      effectiveCreature.genetics,
                                    ),
                                    hueShift: hueFromGenes(
                                      effectiveCreature.genetics,
                                    ),
                                    isPrismatic:
                                        effectiveCreature.isPrismaticSkin,
                                    frameSize: Vector2(
                                      effectiveCreature.spriteData!.frameWidth *
                                          1.0,
                                      effectiveCreature
                                              .spriteData!
                                              .frameHeight *
                                          1.0,
                                    ),
                                    stepTime:
                                        (effectiveCreature
                                            .spriteData!
                                            .frameDurationMs /
                                        1000.0),
                                  )
                                : Center(
                                    child: Text(
                                      name.substring(0, 1).toUpperCase(),
                                      style: TextStyle(
                                        color: base != null
                                            ? CreatureFilterUtils.getTypeColor(
                                                base.types.first,
                                              )
                                            : Colors.grey.shade600,
                                        fontSize: 18, // Increased font size
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      // Level badge positioned in the corner
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4, // Increased padding
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: Colors.amber.shade300,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 1,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            'L${instance.level}',
                            style: TextStyle(
                              color: Colors.amber.shade700,
                              fontSize: 8, // Increased font size
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 4), // Increased spacing
            Text(
              name,
              style: TextStyle(
                color: Colors.indigo.shade700,
                fontSize: 11, // Increased font size
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4), // Increased spacing
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4, // Increased padding
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: Colors.green.shade200,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      '${instance.xp}XP',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 9, // Increased font size
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 4), // Increased spacing
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4, // Increased padding
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: instance.natureId != null
                          ? Colors.purple.shade50
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: instance.natureId != null
                            ? Colors.purple.shade200
                            : Colors.grey.shade200,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      instance.natureId ?? 'None',
                      style: TextStyle(
                        color: instance.natureId != null
                            ? Colors.purple.shade700
                            : Colors.grey.shade600,
                        fontSize: 8, // Increased font size
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3), // Increased spacing
            if (genetics != null) ...[
              if (sizeVariant != null) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getSizeColor(sizeVariant),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: _getSizeTextColor(sizeVariant),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        sizeIcons[sizeVariant] ?? Icons.circle,
                        size: 10,
                        color: _getSizeTextColor(sizeVariant),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        sizeLabels[sizeVariant] ?? sizeVariant,
                        style: TextStyle(
                          color: _getSizeTextColor(sizeVariant),
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (tintingVariant != null) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getTintingColor(tintingVariant),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: _getTintingTextColor(tintingVariant),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tintIcons[tintingVariant] ?? Icons.palette_outlined,
                        size: 10,
                        color: _getTintingTextColor(tintingVariant),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        tintLabels[tintingVariant] ?? tintingVariant,
                        style: TextStyle(
                          color: _getTintingTextColor(tintingVariant),
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            if (instance.isPrismaticSkin) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.pink.shade100,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: Colors.pink.shade300, width: 0.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('⭐', style: TextStyle(fontSize: 10)),
                    const SizedBox(width: 3),
                    Text(
                      'Prismatic',
                      style: TextStyle(
                        color: Colors.pink.shade700,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getTintingTextColor(String tinting) {
    switch (tinting) {
      case 'warm':
        return Colors.red.shade700;
      case 'cool':
        return Colors.cyan.shade50;
      case 'vibrant':
        return Colors.purple.shade50;
      case 'pale':
        return Colors.grey.shade50;
      default:
        return Colors.grey.shade50;
    }
  }

  Color _getSizeColor(String size) {
    switch (size) {
      case 'tiny':
        return Colors.pink.shade50;
      case 'small':
        return Colors.blue.shade50;
      case 'normal':
        return Colors.grey.shade50;
      case 'large':
        return Colors.green.shade50;
      case 'giant':
        return Colors.orange.shade50;
      default:
        return Colors.grey.shade50;
    }
  }

  Color _getSizeTextColor(String size) {
    switch (size) {
      case 'tiny':
        return Colors.pink.shade700;
      case 'small':
        return Colors.blue.shade700;
      case 'normal':
        return Colors.grey.shade700;
      case 'large':
        return Colors.green.shade700;
      case 'giant':
        return Colors.orange.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  Color _getTintingColor(String tinting) {
    switch (tinting) {
      case 'warm':
        return Colors.red.shade50;
      case 'cool':
        return Colors.cyan.shade700;
      case 'vibrant':
        return Colors.purple.shade700;
      case 'pale':
        return Colors.grey.shade600;
      default:
        return Colors.grey.shade700;
    }
  }

  Widget _buildFodderGrid(List<CreatureInstance> allInstances) {
    final fodderInstances = allInstances
        .where(
          (instance) =>
              instance.baseId == _targetSpeciesId &&
              instance.instanceId != _targetInstanceId &&
              !instance.locked,
        )
        .toList();

    fodderInstances.sort((a, b) {
      int comparison = 0;
      switch (_instanceSortBy) {
        case 'Level':
          comparison = a.level.compareTo(b.level);
          break;
        case 'Created Date':
          comparison = a.createdAtUtcMs.compareTo(b.createdAtUtcMs);
          break;
      }

      return _instanceAscending ? comparison : -comparison;
    });

    if (fodderInstances.isEmpty) {
      return _buildEmptyFodderState();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.science_rounded,
                color: Colors.green.shade600,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Select Enhancement Material',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  '${fodderInstances.length} available',
                  style: TextStyle(
                    color: Colors.green.shade600,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.6,
                crossAxisSpacing: 5,
                mainAxisSpacing: 5,
              ),
              itemCount: fodderInstances.length,
              itemBuilder: (_, i) => _buildFodderCard(fodderInstances[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedingInterface() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        border: Border(
          top: BorderSide(color: Colors.indigo.shade200, width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.shade50,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_preview != null) _buildPreviewStats(),
          const SizedBox(height: 8),
          _buildFeedButton(),
        ],
      ),
    );
  }

  Widget _buildPreviewStats() {
    if (_preview == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text(
                  '${_preview!.totalXpGained}',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'XP Gained',
                  style: TextStyle(
                    color: Colors.blue.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 24, color: Colors.blue.shade200),
          Expanded(
            child: Column(
              children: [
                Text(
                  'L${_preview!.newLevel}',
                  style: TextStyle(
                    color: Colors.purple.shade700,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'New Level',
                  style: TextStyle(
                    color: Colors.purple.shade600,
                    fontSize: 11,
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

  Widget _buildFeedButton() {
    final enabled =
        _targetInstanceId != null && _selectedFodder.isNotEmpty && !_busy;

    return AnimatedBuilder(
      animation: _feedButtonController,
      builder: (context, child) {
        return GestureDetector(
          onTapDown: enabled ? (_) => _feedButtonController.forward() : null,
          onTapUp: enabled ? (_) => _feedButtonController.reverse() : null,
          onTapCancel: enabled ? () => _feedButtonController.reverse() : null,
          onTap: enabled ? _doFeed : null,
          child: Transform.scale(
            scale: 1.0 - (_feedButtonController.value * 0.05),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: enabled ? Colors.green.shade600 : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(8),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: Colors.green.shade200,
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_busy) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else ...[
                    const Icon(
                      Icons.science_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    _busy
                        ? 'Processing...'
                        : 'Begin Enhancement ${_selectedFodder.isNotEmpty ? '(${_selectedFodder.length})' : ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String text) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.science_outlined, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              text,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFodderState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.no_food_rounded,
              size: 40,
              color: Colors.orange.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'No Enhancement Material Available',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No other instances of this species available for enhancement protocols.',
              style: TextStyle(color: Colors.orange.shade600, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  int _getRarityOrder(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return 0;
      case 'uncommon':
        return 1;
      case 'rare':
        return 2;
      case 'mythic':
        return 3;
      case 'legendary':
        return 4;
      default:
        return 0;
    }
  }

  Future<void> _updatePreview() async {
    if (_targetInstanceId == null || _selectedFodder.isEmpty) {
      setState(() => _preview = null);
      return;
    }
    final svc = CreatureInstanceService(context.read<AlchemonsDatabase>());
    final repo = context.read<CreatureRepository>();

    final res = await svc.previewFeed(
      targetInstanceId: _targetInstanceId!,
      fodderInstanceIds: _selectedFodder.toList(),
      repo: repo,
      strictSpecies: true,
    );
    setState(() => _preview = res.ok ? res : null);
  }

  Future<void> _doFeed() async {
    if (_busy || _targetInstanceId == null || _selectedFodder.isEmpty) return;

    setState(() => _busy = true);
    try {
      final svc = CreatureInstanceService(context.read<AlchemonsDatabase>());
      final repo = context.read<CreatureRepository>();
      final factions = context.read<FactionService>();

      final res = await svc.feedInstances(
        targetInstanceId: _targetInstanceId!,
        fodderInstanceIds: _selectedFodder.toList(),
        repo: repo,
        factions: factions,
        strictSpecies: true,
      );

      if (!mounted) return;
      if (!res.ok) {
        _showToast(
          res.error ?? 'Enhancement failed',
          icon: Icons.error_rounded,
          color: Colors.red.shade400,
        );
        return;
      }

      _showToast(
        'Enhancement complete: +${res.totalXpGained} XP, Level ${res.newLevel}',
        icon: Icons.science_rounded,
        color: Colors.green.shade400,
      );

      context.read<GameStateNotifier>().refresh();

      setState(() {
        _selectedFodder.clear();
        _preview = null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showToast(
    String message, {
    IconData icon = Icons.info_rounded,
    Color? color,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color ?? Colors.indigo.shade400,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

class FilterDropdown extends StatelessWidget {
  final String hint;
  final List<String> items;
  final String selectedValue;
  final void Function(String?) onChanged;
  final IconData icon;
  final Color? color;

  const FilterDropdown({
    super.key,
    required this.hint,
    required this.items,
    required this.selectedValue,
    required this.onChanged,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? Colors.indigo.shade600;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: themeColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          icon: Icon(icon, color: themeColor, size: 16),
          dropdownColor: Colors.white,
          style: TextStyle(
            color: themeColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: TextStyle(
                  color: themeColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
