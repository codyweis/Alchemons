import 'dart:convert';
import 'dart:ui';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/color_util.dart';
import 'package:alchemons/utils/creature_filter_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/badges/badge_widget.dart';
import 'package:alchemons/widgets/glowing_icon.dart';
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
import '../utils/faction_util.dart';

/// Enhanced feeding screen with glassmorphism design
class FeedingScreen extends StatefulWidget {
  const FeedingScreen({super.key});

  @override
  State<FeedingScreen> createState() => _FeedingScreenState();
}

class _FeedingScreenState extends State<FeedingScreen>
    with TickerProviderStateMixin {
  // Selection state
  String? _targetSpeciesId;
  String? _targetInstanceId;
  Set<String> _selectedFodder = {};
  FeedResult? _preview;
  bool _busy = false;

  // Filter state
  String _speciesTypeFilter = 'All';
  String _speciesRarityFilter = 'All Rarities';
  String _speciesSortBy = 'Name';
  bool _speciesAscending = true;

  late AnimationController _glowController;

  // Fodder filter state
  String? _fodderFilterSize;
  String? _fodderFilterTint;
  bool _fodderFilterPrismatic = false;
  String _fodderSortBy = 'Level';
  bool _fodderAscending = false;

  String? _fodderFilterNature;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final factionSvc = context.read<FactionService>();
    final currentFaction = factionSvc.current;
    final (primaryColor, _, accentColor) = getFactionColors(currentFaction);
    final db = context.watch<AlchemonsDatabase>();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0B0F14).withOpacity(0.96),
              const Color(0xFF0B0F14).withOpacity(0.92),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(accentColor),
              _buildTargetSection(accentColor),

              Expanded(
                child: StreamBuilder<List<CreatureInstance>>(
                  stream: db.watchAllInstances(),
                  builder: (context, snap) {
                    final allInstances =
                        snap.data ?? const <CreatureInstance>[];
                    return _buildMainContent(allInstances, accentColor);
                  },
                ),
              ),
              if (_targetInstanceId != null)
                _buildFeedingInterface(accentColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color accentColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: _GlassContainer(
        accentColor: accentColor,
        glowController: _glowController,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _IconButton(
                icon: Icons.arrow_back_rounded,
                accentColor: accentColor,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ENHANCEMENT LAB', style: _TextStyles.headerTitle),
                    const SizedBox(height: 2),
                    Text(
                      'Biological enhancement protocols',
                      style: _TextStyles.headerSubtitle,
                    ),
                  ],
                ),
              ),
              GlowingIcon(
                icon: Icons.science_rounded,
                color: accentColor,
                controller: _glowController,
                dialogTitle: "Enhancement Instructions",
                dialogMessage:
                    "Select an Alchemon to enhance by feeding it "
                    "other Alchemons of the same species. The target Alchemon "
                    "will gain experience points (XP) based on the levels of "
                    "the fodder Alchemons used. Higher level fodder will yield "
                    "more XP, potentially allowing the target to level up. "
                    "Select multiple fodder Alchemons to maximize XP gain. "
                    "Once satisfied with your selection, press the 'Enhance' "
                    "button to apply the changes. Note that fodder Alchemons "
                    "will be permanently consumed in the process.",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTargetSection(Color accentColor) {
    if (_targetSpeciesId == null) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text('Select Target Species', style: _TextStyles.sectionTitle),
                const SizedBox(height: 4),
                Text(
                  'Choose specimen for enhancement',
                  style: _TextStyles.sectionSubtitle,
                ),
              ],
            ),
          ),
          _buildSpeciesFiltersAndSort(accentColor),
        ],
      );
    }

    return _buildSelectedTargetCard(accentColor);
  }

  Widget _buildSelectedTargetCard(Color accentColor) {
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
          return _buildDetailedTargetCard(
            creature,
            targetInstance,
            accentColor,
          );
        }

        return _buildSpeciesTargetCard(creature, accentColor);
      },
    );
  }

  Widget _buildSpeciesTargetCard(Creature creature, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: _GlassContainer(
        accentColor: Colors.green.shade400,
        glowController: _glowController,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(creature.name, style: _TextStyles.cardTitle),
                    const SizedBox(height: 4),
                    TypeBadges(types: creature.types),
                    const SizedBox(height: 4),
                    Text('Select specimen instance', style: _TextStyles.hint),
                  ],
                ),
              ),
              _ChangeButton(onTap: _resetSelection),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedTargetCard(
    Creature creature,
    CreatureInstance instance,
    Color accentColor,
  ) {
    final repo = context.watch<CreatureRepository>();
    final base = repo.getCreatureById(instance.baseId);
    final name = base?.name ?? instance.baseId;
    final genetics = GeneticsHelper.parseGenetics(instance);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: _GlassContainer(
        accentColor: accentColor,
        glowController: _glowController,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.biotech_rounded, color: accentColor, size: 16),
                  const SizedBox(width: 6),
                  Text('Target Specimen', style: _TextStyles.labelText),
                  const Spacer(),
                  _ChangeButton(size: 'small', onTap: _resetSelection),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FutureBuilder<Creature?>(
                    future: GeneticsHelper.createCreatureFromInstance(
                      instance,
                      repo,
                    ),
                    builder: (context, snapshot) {
                      return _CreatureAvatar(
                        creature: snapshot.data ?? base,
                        size: 80,
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
                            Text(name, style: _TextStyles.cardTitle),
                            const SizedBox(width: 8),
                            _Badge(
                              text: 'L${instance.level}',
                              color: Colors.amber,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.green.shade400.withOpacity(0.5),
                            ),
                          ),
                          child: StaminaBadge(
                            instanceId: instance.instanceId,
                            showCountdown: true,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _InstanceBadges(instance: instance, genetics: genetics),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeciesFiltersAndSort(Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _FilterDropdown(
                  items: CreatureFilterUtils.filterOptions,
                  selectedValue: _speciesTypeFilter,
                  onChanged: (v) => setState(() => _speciesTypeFilter = v!),
                  icon: Icons.category_rounded,
                  accentColor: accentColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterDropdown(
                  items: CreatureFilterUtils.rarityFilters,
                  selectedValue: _speciesRarityFilter,
                  onChanged: (v) => setState(() => _speciesRarityFilter = v!),
                  icon: Icons.star_rounded,
                  accentColor: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _FilterDropdown(
                  items: const ['Name', 'Rarity', 'Type'],
                  selectedValue: _speciesSortBy,
                  onChanged: (v) => setState(() => _speciesSortBy = v!),
                  icon: Icons.sort_rounded,
                  accentColor: accentColor,
                ),
              ),
              const SizedBox(width: 8),
              _IconButton(
                icon: _speciesAscending
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                accentColor: accentColor,
                onTap: () =>
                    setState(() => _speciesAscending = !_speciesAscending),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(
    List<CreatureInstance> allInstances,
    Color accentColor,
  ) {
    if (_targetSpeciesId == null) {
      return _buildSpeciesSelectionGrid(accentColor);
    } else if (_targetInstanceId == null) {
      return _buildTargetInstanceGrid(allInstances, accentColor);
    } else {
      return _buildFodderGrid(allInstances, accentColor);
    }
  }

  Widget _buildSpeciesSelectionGrid(Color accentColor) {
    final gameState = context.watch<GameStateNotifier>();
    final filteredSpecies = _FilterHelper.filterAndSortSpecies(
      gameState.discoveredCreatures,
      _speciesTypeFilter,
      _speciesRarityFilter,
      _speciesSortBy,
      _speciesAscending,
    );

    if (filteredSpecies.isEmpty) {
      return _EmptyState(message: 'No specimens match current filters');
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.9,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: filteredSpecies.length,
        itemBuilder: (_, i) => _SpeciesCard(
          creature: filteredSpecies[i]['creature'] as Creature,
          onTap: () => setState(() {
            _targetSpeciesId = (filteredSpecies[i]['creature'] as Creature).id;
            _targetInstanceId = null;
            _selectedFodder.clear();
            _preview = null;
          }),
        ),
      ),
    );
  }

  Widget _buildTargetInstanceGrid(
    List<CreatureInstance> allInstances,
    Color accentColor,
  ) {
    var targetInstances = allInstances
        .where((instance) => instance.baseId == _targetSpeciesId)
        .toList();

    targetInstances = targetInstances.where((inst) {
      if (_fodderFilterPrismatic && inst.isPrismaticSkin != true) return false;

      final genetics = GeneticsHelper.parseGenetics(inst);
      if (_fodderFilterSize != null && genetics?['size'] != _fodderFilterSize) {
        return false;
      }
      if (_fodderFilterTint != null &&
          genetics?['tinting'] != _fodderFilterTint) {
        return false;
      }

      if (_fodderFilterNature != null && inst.natureId != _fodderFilterNature) {
        return false;
      }

      return true;
    }).toList();

    targetInstances.sort((a, b) {
      int comparison = _fodderSortBy == 'Level'
          ? a.level.compareTo(b.level)
          : a.createdAtUtcMs.compareTo(b.createdAtUtcMs);
      return _fodderAscending ? comparison : -comparison;
    });

    final hasFilters =
        _fodderFilterSize != null ||
        _fodderFilterTint != null ||
        _fodderFilterNature != null ||
        _fodderFilterPrismatic;

    final totalCount = allInstances
        .where((i) => i.baseId == _targetSpeciesId)
        .length;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Select Target Specimen', style: _TextStyles.sectionTitle),
              const Spacer(),
              _Badge(
                text: '${targetInstances.length}/$totalCount',
                color: Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildFodderFilters(accentColor),
          const SizedBox(height: 8),
          Expanded(
            child: targetInstances.isEmpty
                ? _EmptyState(
                    message: hasFilters
                        ? 'No matching specimens'
                        : 'No instances of this species found',
                    subtitle: hasFilters ? 'Try adjusting your filters' : null,
                  )
                : GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: targetInstances.length,
                    itemBuilder: (_, i) => _TargetInstanceCard(
                      instance: targetInstances[i],
                      onTap: () => setState(() {
                        _targetInstanceId = targetInstances[i].instanceId;
                        _selectedFodder.clear();
                        _preview = null;
                      }),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFodderGrid(
    List<CreatureInstance> allInstances,
    Color accentColor,
  ) {
    var fodderInstances = _FilterHelper.filterAndSortFodder(
      allInstances,
      _targetSpeciesId,
      _targetInstanceId,
      _fodderSortBy,
      _fodderAscending,
    );

    fodderInstances = fodderInstances.where((inst) {
      if (_fodderFilterPrismatic && inst.isPrismaticSkin != true) return false;

      final genetics = GeneticsHelper.parseGenetics(inst);
      if (_fodderFilterSize != null && genetics?['size'] != _fodderFilterSize) {
        return false;
      }
      if (_fodderFilterTint != null &&
          genetics?['tinting'] != _fodderFilterTint) {
        return false;
      }

      if (_fodderFilterNature != null && inst.natureId != _fodderFilterNature) {
        return false;
      }

      return true;
    }).toList();

    final hasFilters =
        _fodderFilterSize != null ||
        _fodderFilterTint != null ||
        _fodderFilterNature != null ||
        _fodderFilterPrismatic;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science_rounded, color: accentColor, size: 16),
              const SizedBox(width: 6),
              Text(
                'Select Enhancement Material',
                style: _TextStyles.sectionTitle,
              ),
              const Spacer(),
              _Badge(
                text:
                    '${fodderInstances.length}/${allInstances.where((i) => i.baseId == _targetSpeciesId && i.instanceId != _targetInstanceId).length}',
                color: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildFodderFilters(accentColor),
          const SizedBox(height: 8),
          Expanded(
            child: fodderInstances.isEmpty
                ? _EmptyState(
                    message: hasFilters
                        ? 'No matching specimens'
                        : 'No Enhancement Material Available',
                    subtitle: hasFilters
                        ? 'Try adjusting your filters'
                        : 'No other instances available for enhancement protocols.',
                    icon: hasFilters
                        ? Icons.search_off_rounded
                        : Icons.no_food_rounded,
                  )
                : GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.6,
                          crossAxisSpacing: 5,
                          mainAxisSpacing: 5,
                        ),
                    itemCount: fodderInstances.length,
                    itemBuilder: (_, i) => _FodderCard(
                      instance: fodderInstances[i],
                      isSelected: _selectedFodder.contains(
                        fodderInstances[i].instanceId,
                      ),
                      onTap: () async {
                        setState(() {
                          if (_selectedFodder.contains(
                            fodderInstances[i].instanceId,
                          )) {
                            _selectedFodder.remove(
                              fodderInstances[i].instanceId,
                            );
                          } else {
                            _selectedFodder.add(fodderInstances[i].instanceId);
                          }
                        });
                        await _updatePreview();
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFodderFilters(Color accentColor) {
    return Column(
      children: [
        // Sort row
        Row(
          children: [
            Icon(
              Icons.sort_rounded,
              size: 14,
              color: accentColor.withOpacity(.8),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FodderSortChip(
                      label: 'Level ↑',
                      isSelected: _fodderSortBy == 'Level' && !_fodderAscending,
                      primaryColor: accentColor,
                      onTap: () => setState(() {
                        _fodderSortBy = 'Level';
                        _fodderAscending = false;
                      }),
                    ),
                    const SizedBox(width: 6),
                    _FodderSortChip(
                      label: 'Level ↓',
                      isSelected: _fodderSortBy == 'Level' && _fodderAscending,
                      primaryColor: accentColor,
                      onTap: () => setState(() {
                        _fodderSortBy = 'Level';
                        _fodderAscending = true;
                      }),
                    ),
                    const SizedBox(width: 6),
                    _FodderSortChip(
                      label: 'Newest',
                      isSelected:
                          _fodderSortBy == 'Created Date' && !_fodderAscending,
                      primaryColor: accentColor,
                      onTap: () => setState(() {
                        _fodderSortBy = 'Created Date';
                        _fodderAscending = false;
                      }),
                    ),
                    const SizedBox(width: 6),
                    _FodderSortChip(
                      label: 'Oldest',
                      isSelected:
                          _fodderSortBy == 'Created Date' && _fodderAscending,
                      primaryColor: accentColor,
                      onTap: () => setState(() {
                        _fodderSortBy = 'Created Date';
                        _fodderAscending = true;
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Filter row
        Row(
          children: [
            Icon(
              Icons.filter_list_rounded,
              size: 14,
              color: accentColor.withOpacity(.8),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FodderFilterChip(
                      icon: Icons.auto_awesome,
                      label: 'Prismatic',
                      isSelected: _fodderFilterPrismatic,
                      primaryColor: accentColor,
                      onTap: () => setState(
                        () => _fodderFilterPrismatic = !_fodderFilterPrismatic,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _FodderFilterDropdown(
                      icon: Icons.straighten_rounded,
                      label: 'Size',
                      value: _fodderFilterSize,
                      items: const [
                        'tiny',
                        'small',
                        'normal',
                        'large',
                        'giant',
                      ],
                      itemLabels: const {
                        'tiny': 'Tiny',
                        'small': 'Small',
                        'normal': 'Normal',
                        'large': 'Large',
                        'giant': 'Giant',
                      },
                      primaryColor: accentColor,
                      onChanged: (v) => setState(() => _fodderFilterSize = v),
                    ),
                    const SizedBox(width: 6),
                    _FodderFilterDropdown(
                      icon: Icons.palette_outlined,
                      label: 'Tint',
                      value: _fodderFilterTint,
                      items: const [
                        'normal',
                        'warm',
                        'cool',
                        'vibrant',
                        'pale',
                        'albino',
                      ],
                      itemLabels: const {
                        'normal': 'Normal',
                        'warm': 'Thermal',
                        'cool': 'Cryogenic',
                        'vibrant': 'Saturated',
                        'pale': 'Diminished',
                        'albino': 'Albino',
                      },
                      primaryColor: accentColor,
                      onChanged: (v) => setState(() => _fodderFilterTint = v),
                    ),
                    const SizedBox(width: 6),
                    _FodderFilterDropdown(
                      icon: Icons.psychology_rounded,
                      label: 'Nature',
                      value: _fodderFilterNature,
                      items: const [
                        'Metabolic',
                        'Reproductive',
                        'Ecophysiological',
                        'Sympatric',
                        'Conspecific',
                        'Homotypic',
                        'Heterotypic',
                        'Precocial',
                        'Neuroadaptive',
                        'Homeostatic',
                        'Placidal',
                        'Dormant',
                        'Apathetic',
                        'Nullic',
                      ],
                      itemLabels: const {
                        'Metabolic': 'Metabolic',
                        'Reproductive': 'Reproductive',
                        'Ecophysiological': 'Ecophysiological',
                        'Sympatric': 'Sympatric',
                        'Conspecific': 'Conspecific',
                        'Homotypic': 'Homotypic',
                        'Heterotypic': 'Heterotypic',
                        'Precocial': 'Precocial',
                        'Neuroadaptive': 'Neuroadaptive',
                        'Homeostatic': 'Homeostatic',
                        'Placidal': 'Placidal',
                        'Dormant': 'Dormant',
                        'Apathetic': 'Apathetic',
                        'Nullic': 'Nullic',
                      },
                      primaryColor: accentColor,
                      onChanged: (v) => setState(() => _fodderFilterNature = v),
                    ),
                    if (_fodderFilterSize != null ||
                        _fodderFilterTint != null ||
                        _fodderFilterNature != null ||
                        _fodderFilterPrismatic) ...[
                      const SizedBox(width: 6),
                      _ClearFodderFiltersButton(
                        primaryColor: accentColor,
                        onTap: () => setState(() {
                          _fodderFilterSize = null;
                          _fodderFilterTint = null;
                          _fodderFilterNature = null;
                          _fodderFilterPrismatic = false;
                        }),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeedingInterface(Color accentColor) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.18),
            border: Border(
              top: BorderSide(color: accentColor.withOpacity(0.35)),
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.18),
                blurRadius: 18,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              if (_preview != null) _buildPreviewStats(accentColor),
              if (_preview != null) const SizedBox(height: 8),
              _FeedButton(
                enabled:
                    _targetInstanceId != null &&
                    _selectedFodder.isNotEmpty &&
                    !_busy,
                busy: _busy,
                selectedCount: _selectedFodder.length,
                accentColor: accentColor,
                onTap: _doFeed,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewStats(Color accentColor) {
    if (_preview == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatColumn(
              value: '${_preview!.totalXpGained}',
              label: 'XP Gained',
              color: accentColor,
            ),
          ),
          Container(
            width: 1,
            height: 24,
            color: Colors.white.withOpacity(0.25),
          ),
          Expanded(
            child: _StatColumn(
              value: 'L${_preview!.newLevel}',
              label: 'New Level',
              color: Colors.purple.shade400,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  void _resetSelection() => setState(() {
    // Go back one step: if we're in fodder selection, go back to instance selection
    // If we're in instance selection, go back to species selection
    if (_targetInstanceId != null) {
      // Currently in fodder selection -> go back to instance selection
      _targetInstanceId = null;
      _selectedFodder.clear();
      _preview = null;
    } else {
      // Currently in instance selection -> go back to species selection
      _targetSpeciesId = null;
      _targetInstanceId = null;
      _selectedFodder.clear();
      _preview = null;
    }
  });

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

// ==================== REUSABLE COMPONENTS ====================

class _FodderSortChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _FodderSortChip({
    required this.label,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withOpacity(.2)
              : Colors.white.withOpacity(.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? primaryColor.withOpacity(.5)
                : Colors.white.withOpacity(.15),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? primaryColor : const Color(0xFFB6C0CC),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _FodderFilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _FodderFilterChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withOpacity(.2)
              : Colors.white.withOpacity(.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? primaryColor.withOpacity(.5)
                : Colors.white.withOpacity(.15),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 11,
              color: isSelected ? primaryColor : const Color(0xFFB6C0CC),
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? primaryColor : const Color(0xFFB6C0CC),
                fontSize: 10,
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

class _FodderFilterDropdown extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final List<String> items;
  final Map<String, String> itemLabels;
  final Color primaryColor;
  final ValueChanged<String?> onChanged;

  const _FodderFilterDropdown({
    required this.icon,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabels,
    required this.primaryColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await showDialog<String>(
          context: context,
          builder: (context) => _FodderFilterDialog(
            title: label,
            items: items,
            itemLabels: itemLabels,
            currentValue: value,
            primaryColor: primaryColor,
          ),
        );
        if (result != null) {
          onChanged(result == 'clear' ? null : result);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: value != null
              ? primaryColor.withOpacity(.2)
              : Colors.white.withOpacity(.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: value != null
                ? primaryColor.withOpacity(.5)
                : Colors.white.withOpacity(.15),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 11,
              color: value != null ? primaryColor : const Color(0xFFB6C0CC),
            ),
            const SizedBox(width: 3),
            Text(
              value != null ? itemLabels[value] ?? value! : label,
              style: TextStyle(
                color: value != null ? primaryColor : const Color(0xFFB6C0CC),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 12,
              color: value != null ? primaryColor : const Color(0xFFB6C0CC),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClearFodderFiltersButton extends StatelessWidget {
  final Color primaryColor;
  final VoidCallback onTap;

  const _ClearFodderFiltersButton({
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.red.withOpacity(.4), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.clear_rounded, size: 11, color: Colors.red.shade300),
            const SizedBox(width: 3),
            Text(
              'Clear',
              style: TextStyle(
                color: Colors.red.shade300,
                fontSize: 10,
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

// Replace your _FodderFilterDialog class with this version:

class _FodderFilterDialog extends StatelessWidget {
  final String title;
  final List<String> items;
  final Map<String, String> itemLabels;
  final String? currentValue;
  final Color primaryColor;

  const _FodderFilterDialog({
    required this.title,
    required this.items,
    required this.itemLabels,
    required this.currentValue,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 500, maxWidth: 400),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0B0F14).withOpacity(0.92),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: primaryColor.withOpacity(.4),
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFE8EAED),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        ...items.map((item) {
                          final isSelected = currentValue == item;
                          return GestureDetector(
                            onTap: () => Navigator.pop(context, item),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primaryColor.withOpacity(.2)
                                    : Colors.white.withOpacity(.06),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? primaryColor.withOpacity(.5)
                                      : Colors.white.withOpacity(.15),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      itemLabels[item] ?? item,
                                      style: TextStyle(
                                        color: isSelected
                                            ? primaryColor
                                            : const Color(0xFFE8EAED),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_rounded,
                                      color: primaryColor,
                                      size: 18,
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                        if (currentValue != null) ...[
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => Navigator.pop(context, 'clear'),
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
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final Color accentColor;
  final AnimationController glowController;

  const _GlassContainer({
    required this.child,
    required this.accentColor,
    required this.glowController,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedBuilder(
          animation: glowController,
          builder: (context, _) {
            final glow = 0.35 + glowController.value * 0.4;
            return Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentColor.withOpacity(glow * 0.85)),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(glow * 0.5),
                    blurRadius: 20 + glowController.value * 14,
                  ),
                ],
              ),
              child: child,
            );
          },
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _IconButton({
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accentColor.withOpacity(.35)),
        ),
        child: Icon(icon, color: _TextStyles.softText, size: 18),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final List<String> items;
  final String selectedValue;
  final ValueChanged<String?> onChanged;
  final IconData icon;
  final Color accentColor;

  const _FilterDropdown({
    required this.items,
    required this.selectedValue,
    required this.onChanged,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withOpacity(.35)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          icon: Icon(icon, color: accentColor, size: 16),
          dropdownColor: const Color(0xFF1A1F2E),
          style: TextStyle(
            color: _TextStyles.softText,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _TextStyles.softText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _CreatureAvatar extends StatelessWidget {
  final Creature? creature;
  final double size;

  const _CreatureAvatar({required this.creature, this.size = 48});

  @override
  Widget build(BuildContext context) {
    if (creature == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(.12)),
        ),
        child: Icon(
          Icons.help_outline,
          color: _TextStyles.mutedText,
          size: size * 0.5,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CreatureFilterUtils.getTypeColor(creature!.types.first),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: creature!.spriteData != null
            ? CreatureSprite(
                spritePath: creature!.spriteData!.spriteSheetPath,
                totalFrames: creature!.spriteData!.totalFrames,
                rows: creature!.spriteData!.rows,
                scale: scaleFromGenes(creature!.genetics),
                saturation: satFromGenes(creature!.genetics),
                brightness: briFromGenes(creature!.genetics),
                hueShift: hueFromGenes(creature!.genetics),
                isPrismatic: creature!.isPrismaticSkin,
                frameSize: Vector2(
                  creature!.spriteData!.frameWidth * 1.0,
                  creature!.spriteData!.frameHeight * 1.0,
                ),
                stepTime: creature!.spriteData!.frameDurationMs / 1000.0,
              )
            : Icon(
                CreatureFilterUtils.getTypeIcon(creature!.types.first),
                size: size * 0.5,
                color: CreatureFilterUtils.getTypeColor(creature!.types.first),
              ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final MaterialColor color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade100.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.shade400.withOpacity(0.6)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color.shade400,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ChangeButton extends StatelessWidget {
  final VoidCallback onTap;
  final String size;

  const _ChangeButton({required this.onTap, this.size = 'normal'});

  @override
  Widget build(BuildContext context) {
    final isSmall = size == 'small';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 8 : 10,
          vertical: isSmall ? 4 : 10,
        ),
        decoration: BoxDecoration(
          color: Colors.orange.shade100.withOpacity(0.15),
          borderRadius: BorderRadius.circular(isSmall ? 6 : 8),
          border: Border.all(color: Colors.orange.shade400.withOpacity(0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_horiz_rounded,
              color: Colors.orange.shade400,
              size: isSmall ? 12 : 14,
            ),
            SizedBox(width: isSmall ? 3 : 4),
            Text(
              'Change',
              style: TextStyle(
                color: Colors.orange.shade400,
                fontSize: isSmall ? 10 : 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstanceBadges extends StatelessWidget {
  final CreatureInstance instance;
  final Map<String, String>? genetics;

  const _InstanceBadges({required this.instance, this.genetics});

  @override
  Widget build(BuildContext context) {
    final sizeVariant = GeneticsHelper.getSizeVariant(genetics);
    final tintingVariant = GeneticsHelper.getTintingVariant(genetics);

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _SmallBadge(text: '${instance.xp} XP', color: Colors.green),
        if (instance.natureId != null)
          _SmallBadge(text: instance.natureId!, color: Colors.purple),
        if (sizeVariant != null)
          _GeneticsBadge(
            icon: sizeIcons[sizeVariant] ?? Icons.circle,
            text: sizeLabels[sizeVariant] ?? sizeVariant,
            color: getSizeTextColor(sizeVariant),
            bgColor: getSizeColor(sizeVariant),
          ),
        if (tintingVariant != null && tintingVariant != 'normal')
          _GeneticsBadge(
            icon: tintIcons[tintingVariant] ?? Icons.palette_outlined,
            text: tintLabels[tintingVariant] ?? tintingVariant,
            color: getTintingTextColor(tintingVariant),
            bgColor: getTintingColor(tintingVariant),
          ),
        if (instance.isPrismaticSkin)
          _SmallBadge(text: '⭐ Prismatic', color: Colors.pink),
      ],
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String text;
  final MaterialColor color;

  const _SmallBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade50.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.shade400.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color.shade400,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GeneticsBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color bgColor;

  const _GeneticsBadge({
    required this.icon,
    required this.text,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String groupKey;
  final int count;
  final IconData icon;
  final Color accentColor;

  const _GroupHeader({
    required this.groupKey,
    required this.count,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accentColor.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accentColor, size: 14),
          const SizedBox(width: 6),
          Text(
            '$groupKey ($count)',
            style: TextStyle(
              color: accentColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeciesCard extends StatelessWidget {
  final Creature creature;
  final VoidCallback onTap;

  const _SpeciesCard({required this.creature, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final typeColor = CreatureFilterUtils.getTypeColor(creature.types.first);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: typeColor.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(color: typeColor.withOpacity(0.15), blurRadius: 8),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: _CreatureAvatar(creature: creature, size: 80)),
            const SizedBox(height: 6),
            Text(
              creature.name,
              style: _TextStyles.cardSmallTitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetInstanceCard extends StatelessWidget {
  final CreatureInstance instance;
  final VoidCallback onTap;

  const _TargetInstanceCard({required this.instance, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CreatureRepository>();
    final base = repo.getCreatureById(instance.baseId);
    final genetics = GeneticsHelper.parseGenetics(instance);
    final sizeVariant = GeneticsHelper.getSizeVariant(genetics);
    final tintingVariant = GeneticsHelper.getTintingVariant(genetics);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.blue.shade400.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar with compact badges overlay
            FutureBuilder<Creature?>(
              future: GeneticsHelper.createCreatureFromInstance(instance, repo),
              builder: (context, snapshot) {
                return SizedBox(
                  height: 90,
                  child: Stack(
                    children: [
                      // Centered avatar
                      Center(
                        child: _CreatureAvatar(
                          creature: snapshot.data ?? base,
                          size: 85,
                        ),
                      ),
                      // Top row: Level and XP
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _CompactBadge(
                              text: 'L${instance.level}',
                              color: const Color.fromARGB(255, 0, 0, 0),
                              bgColor: Colors.amber.shade100,
                              borderColor: Colors.amber.shade300,
                            ),
                            _CompactBadge(
                              text: '${instance.xp}',
                              color: Colors.green.shade700,
                              bgColor: Colors.green.shade100,
                              borderColor: Colors.green.shade300,
                            ),
                          ],
                        ),
                      ),
                      // Bottom right: Prismatic indicator
                      if (instance.isPrismaticSkin)
                        const Positioned(
                          bottom: 2,
                          right: 2,
                          child: Text('⭐', style: TextStyle(fontSize: 16)),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 6),

            // Info badges row
            Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                // Nature
                _InfoChip(
                  text: instance.natureId ?? 'None',
                  color: instance.natureId != null
                      ? Colors.purple.shade600
                      : Colors.grey.shade600,
                  bgColor: instance.natureId != null
                      ? Colors.purple.shade100
                      : Colors.grey.shade200,
                ),
                // Size
                if (sizeVariant != null)
                  _InfoChip(
                    icon: sizeIcons[sizeVariant] ?? Icons.circle,
                    text: sizeLabels[sizeVariant] ?? sizeVariant,
                    color: getSizeTextColor(sizeVariant),
                    bgColor: getSizeColor(sizeVariant),
                  ),
                // Tint
                if (tintingVariant != null && tintingVariant != 'normal')
                  _InfoChip(
                    icon: tintIcons[tintingVariant] ?? Icons.palette_outlined,
                    text: tintLabels[tintingVariant] ?? tintingVariant,
                    color: getTintingTextColor(tintingVariant),
                    bgColor: getTintingColor(tintingVariant),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FodderCard extends StatelessWidget {
  final CreatureInstance instance;
  final bool isSelected;
  final VoidCallback onTap;

  const _FodderCard({
    required this.instance,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CreatureRepository>();
    final base = repo.getCreatureById(instance.baseId);
    final genetics = GeneticsHelper.parseGenetics(instance);
    final sizeVariant = GeneticsHelper.getSizeVariant(genetics);
    final tintingVariant = GeneticsHelper.getTintingVariant(genetics);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.green.shade400.withOpacity(0.15)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.green.shade400
                : base != null
                ? CreatureFilterUtils.getTypeColor(
                    base.types.first,
                  ).withOpacity(0.3)
                : Colors.grey.shade400,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.green.shade400.withOpacity(0.3),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar with level badge
            FutureBuilder<Creature?>(
              future: GeneticsHelper.createCreatureFromInstance(instance, repo),
              builder: (context, snapshot) {
                return SizedBox(
                  height: 80,
                  child: Stack(
                    children: [
                      Center(
                        child: _CreatureAvatar(
                          creature: snapshot.data ?? base,
                          size: 76,
                        ),
                      ),
                      // Level badge - top left
                      Positioned(
                        top: 0,
                        left: 0,
                        child: _CompactBadge(
                          text: 'L${instance.level}',
                          color: const Color.fromARGB(255, 0, 0, 0),
                          bgColor: Colors.amber.shade100,
                          borderColor: Colors.amber.shade300,
                        ),
                      ),
                      // Prismatic - bottom right
                      if (instance.isPrismaticSkin)
                        const Positioned(
                          bottom: 0,
                          right: 0,
                          child: Text('⭐', style: TextStyle(fontSize: 14)),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 4),

            // Name
            Text(
              base?.name ?? instance.baseId,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),

            // Info badges
            Wrap(
              spacing: 3,
              runSpacing: 3,
              alignment: WrapAlignment.center,
              children: [
                // Nature
                _InfoChip(
                  text: instance.natureId ?? 'None',
                  color: instance.natureId != null
                      ? Colors.purple.shade600
                      : Colors.grey.shade600,
                  bgColor: instance.natureId != null
                      ? Colors.purple.shade100
                      : Colors.grey.shade200,
                  compact: true,
                ),
                // Size
                if (sizeVariant != null)
                  _InfoChip(
                    icon: sizeIcons[sizeVariant] ?? Icons.circle,
                    text: sizeLabels[sizeVariant] ?? sizeVariant,
                    color: getSizeTextColor(sizeVariant),
                    bgColor: getSizeColor(sizeVariant),
                    compact: true,
                  ),
                // Tint
                if (tintingVariant != null && tintingVariant != 'normal')
                  _InfoChip(
                    icon: tintIcons[tintingVariant] ?? Icons.palette_outlined,
                    text: tintLabels[tintingVariant] ?? tintingVariant,
                    color: getTintingTextColor(tintingVariant),
                    bgColor: getTintingColor(tintingVariant),
                    compact: true,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Compact badge for level/xp
class _CompactBadge extends StatelessWidget {
  final String text;
  final Color color;
  final Color bgColor;
  final Color borderColor;

  const _CompactBadge({
    required this.text,
    required this.color,
    required this.bgColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
    );
  }
}

// Info chip for nature/size/tint
class _InfoChip extends StatelessWidget {
  final IconData? icon;
  final String text;
  final Color color;
  final Color bgColor;
  final bool compact;

  const _InfoChip({
    this.icon,
    required this.text,
    required this.color,
    required this.bgColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 6,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 9 : 10, color: color),
            SizedBox(width: compact ? 2 : 3),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: compact ? 8 : 9,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatColumn({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: _TextStyles.mutedText,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _FeedButton extends StatefulWidget {
  final bool enabled;
  final bool busy;
  final int selectedCount;
  final Color accentColor;
  final VoidCallback onTap;

  const _FeedButton({
    required this.enabled,
    required this.busy,
    required this.selectedCount,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_FeedButton> createState() => _FeedButtonState();
}

class _FeedButtonState extends State<_FeedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return GestureDetector(
          onTapDown: widget.enabled ? (_) => _controller.forward() : null,
          onTapUp: widget.enabled ? (_) => _controller.reverse() : null,
          onTapCancel: widget.enabled ? () => _controller.reverse() : null,
          onTap: widget.enabled ? widget.onTap : null,
          child: Transform.scale(
            scale: 1.0 - (_controller.value * 0.05),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: widget.enabled
                    ? Colors.green.shade600
                    : Colors.grey.shade700,
                borderRadius: BorderRadius.circular(12),
                boxShadow: widget.enabled
                    ? [
                        BoxShadow(
                          color: Colors.green.shade400.withOpacity(0.4),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.busy) ...[
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
                    widget.busy
                        ? 'Processing...'
                        : 'Begin Enhancement${widget.selectedCount > 0 ? ' (${widget.selectedCount})' : ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
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
}

class _EmptyState extends StatelessWidget {
  final String message;
  final String? subtitle;
  final IconData? icon;

  const _EmptyState({required this.message, this.subtitle, this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(.15)),
              ),
              child: Icon(
                icon ?? Icons.search_off_rounded,
                size: 48,
                color: _TextStyles.mutedText,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: _TextStyles.emptyStateTitle,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: _TextStyles.emptyStateSubtitle,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==================== HELPER CLASSES ====================

class _FilterHelper {
  static List<Map<String, dynamic>> filterAndSortSpecies(
    List<Map<String, dynamic>> species,
    String typeFilter,
    String rarityFilter,
    String sortBy,
    bool ascending,
  ) {
    var filtered = species.where((data) {
      final creature = data['creature'] as Creature;
      if (typeFilter != 'All' && !creature.types.contains(typeFilter)) {
        return false;
      }
      if (rarityFilter != 'All Rarities' && creature.rarity != rarityFilter) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      final creatureA = a['creature'] as Creature;
      final creatureB = b['creature'] as Creature;
      int comparison = 0;
      switch (sortBy) {
        case 'Name':
          comparison = creatureA.name.compareTo(creatureB.name);
          break;
        case 'Rarity':
          comparison = CreatureFilterUtils.getRarityOrder(
            creatureA.rarity,
          ).compareTo(CreatureFilterUtils.getRarityOrder(creatureB.rarity));
          break;
        case 'Type':
          comparison = creatureA.types.first.compareTo(creatureB.types.first);
          break;
      }
      return ascending ? comparison : -comparison;
    });

    return filtered;
  }

  static List<CreatureInstance> filterAndSortFodder(
    List<CreatureInstance> allInstances,
    String? targetSpeciesId,
    String? targetInstanceId,
    String sortBy,
    bool ascending,
  ) {
    final filtered = allInstances
        .where(
          (instance) =>
              instance.baseId == targetSpeciesId &&
              instance.instanceId != targetInstanceId &&
              !instance.locked,
        )
        .toList();

    filtered.sort((a, b) {
      int comparison = sortBy == 'Level'
          ? a.level.compareTo(b.level)
          : a.createdAtUtcMs.compareTo(b.createdAtUtcMs);
      return ascending ? comparison : -comparison;
    });

    return filtered;
  }
}

// ==================== TEXT STYLES ====================

class _TextStyles {
  static const softText = Color(0xFFE8EAED);
  static const mutedText = Color(0xFFB6C0CC);

  static const headerTitle = TextStyle(
    color: softText,
    fontSize: 15,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.8,
  );

  static const headerSubtitle = TextStyle(
    color: mutedText,
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  static const sectionTitle = TextStyle(
    color: softText,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  static const sectionSubtitle = TextStyle(
    color: mutedText,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  static const labelText = TextStyle(
    color: softText,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );

  static const cardTitle = TextStyle(
    color: softText,
    fontSize: 14,
    fontWeight: FontWeight.w800,
  );

  static const cardSmallTitle = TextStyle(
    color: softText,
    fontSize: 11,
    fontWeight: FontWeight.w700,
  );

  static const hint = TextStyle(
    color: mutedText,
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  static const emptyStateTitle = TextStyle(
    color: softText,
    fontSize: 16,
    fontWeight: FontWeight.w800,
  );

  static const emptyStateSubtitle = TextStyle(
    color: mutedText,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );
}

// ==================== GENETICS HELPER ====================

class GeneticsHelper {
  static Map<String, String>? parseGenetics(CreatureInstance instance) {
    if (instance.geneticsJson == null) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(instance.geneticsJson!));
      return map.map((k, v) => MapEntry(k, v.toString()));
    } catch (e) {
      return null;
    }
  }

  static String? getSizeVariant(Map<String, String>? genetics) {
    return genetics?['size'];
  }

  static String? getTintingVariant(Map<String, String>? genetics) {
    return genetics?['tinting'];
  }

  static Future<Creature?> createCreatureFromInstance(
    CreatureInstance instance,
    CreatureRepository repo,
  ) async {
    final base = repo.getCreatureById(instance.baseId);
    if (base == null) return null;

    var creature = base;

    if (instance.isPrismaticSkin) {
      creature = creature.copyWith(isPrismaticSkin: true);
    }

    final genetics = parseGenetics(instance);
    if (genetics != null) {
      final geneticsObj = Genetics(genetics);
      creature = creature.copyWith(genetics: geneticsObj);
    }

    return creature;
  }
}
