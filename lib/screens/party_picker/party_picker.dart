import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/providers/selected_party.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/all_instaces_grid.dart';
import 'package:alchemons/widgets/creature_instances_sheet.dart';
import 'package:alchemons/widgets/creature_selection_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'party_picker_empty_state.dart';
import 'party_picker_widgets.dart';
import 'party_picker_dialogs.dart';

class PartyPickerScreen extends StatefulWidget {
  const PartyPickerScreen({super.key});

  @override
  State<PartyPickerScreen> createState() => _PartyPickerScreenState();
}

class _PartyPickerScreenState extends State<PartyPickerScreen> {
  // Selection state
  String? _selectedSpeciesId;

  // Search state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late final ScrollController _speciesScrollCtrl;

  bool _showAllInstances = false;

  @override
  void initState() {
    super.initState();
    _speciesScrollCtrl = ScrollController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _speciesScrollCtrl.dispose();
    super.dispose();
  }

  // Helper to build species summary list
  List<Map<String, dynamic>> buildSpeciesListData({
    required List<CreatureInstance> instances,
    required CreatureCatalog repo,
  }) {
    final countBySpecies = <String, int>{};
    for (final inst in instances) {
      countBySpecies[inst.baseId] = (countBySpecies[inst.baseId] ?? 0) + 1;
    }

    final result = <Map<String, dynamic>>[];
    for (final speciesId in countBySpecies.keys) {
      final creature = repo.getCreatureById(speciesId);
      if (creature == null) continue;
      result.add({'creature': creature, 'count': countBySpecies[speciesId]});
    }
    return result;
  }

  bool get _isPickingSpecies => _selectedSpeciesId == null;
  bool get _isPickingInstance => _selectedSpeciesId != null;

  String get _currentStage {
    if (_showAllInstances) return 'all_instances';
    if (_isPickingSpecies) return 'species';
    return 'instance';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    final db = context.watch<AlchemonsDatabase>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 0),
                radius: 1.2,
                colors: [
                  theme.surface,
                  theme.surface,
                  theme.surfaceAlt.withOpacity(.6),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  StageHeader(
                    theme: theme,
                    stage: _currentStage,
                    onBack: _handleBack,
                    onOpenAllInstances: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _showAllInstances = true;
                        _selectedSpeciesId = null;
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                  ),
                  const SizedBox(height: 10),

                  // Main content
                  Expanded(
                    child: StreamBuilder<List<CreatureInstance>>(
                      stream: db.creatureDao.watchAllInstances(),
                      builder: (context, snap) {
                        final instances = snap.data ?? [];
                        return _buildStageContent(theme, instances);
                      },
                    ),
                  ),

                  // Footer with party info
                  PartyFooter(theme: theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Stage Content Builders ----------

  Widget _buildStageContent(
    FactionTheme theme,
    List<CreatureInstance> instances,
  ) {
    final repo = context.read<CreatureCatalog>();

    if (_showAllInstances) {
      return _buildAllInstancesStage(theme, instances, repo);
    }

    if (_isPickingSpecies) {
      return _buildSpeciesStage(theme, instances, repo);
    }

    // Instance selection for specific species
    return _buildInstanceStage(theme, repo);
  }

  // Stage 1: Choose species
  Widget _buildSpeciesStage(
    FactionTheme theme,
    List<CreatureInstance> instances,
    CreatureCatalog repo,
  ) {
    final speciesData = buildSpeciesListData(instances: instances, repo: repo);

    // Nothing owned
    if (speciesData.isEmpty) {
      return const NoSpeciesOwnedWrapper();
    }

    // Filter species based on search query
    final filteredSpeciesData = _searchQuery.isEmpty
        ? speciesData
        : speciesData.where((data) {
            final creature = data['creature'] as Creature;
            final name = creature.name.toLowerCase();
            final types = creature.types.join(' ').toLowerCase();
            final query = _searchQuery.toLowerCase();
            return name.contains(query) || types.contains(query);
          }).toList();

    return Column(
      children: [
        // Search bar with toggle button
        Padding(
          padding: const EdgeInsets.fromLTRB(5, 0, 5, 5),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.surfaceAlt,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: theme.border.withOpacity(.5),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search species...',
                      hintStyle: TextStyle(
                        color: theme.textMuted.withOpacity(.5),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: theme.textMuted,
                        size: 20,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: theme.textMuted,
                                size: 20,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Results count if searching
        if (_searchQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Text(
                  '${filteredSpeciesData.length} result${filteredSpeciesData.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

        // Either empty "no matches" or list of species
        Expanded(
          child: filteredSpeciesData.isEmpty
              ? NoResultsFound(theme: theme)
              : ListView.builder(
                  controller: _speciesScrollCtrl,
                  padding: const EdgeInsets.fromLTRB(5, 0, 5, 24),
                  itemCount: filteredSpeciesData.length,
                  itemBuilder: (context, i) {
                    final creature =
                        filteredSpeciesData[i]['creature'] as Creature;
                    final count = filteredSpeciesData[i]['count'] as int;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: SpeciesRow(
                        theme: theme,
                        creature: creature,
                        count: count,
                        onTap: () {
                          setState(() {
                            _selectedSpeciesId = creature.id;
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAllInstancesStage(
    FactionTheme theme,
    List<CreatureInstance> instances,
    CreatureCatalog repo,
  ) {
    if (instances.isEmpty) {
      return const NoSpeciesOwnedWrapper();
    }

    final party = context.watch<SelectedPartyNotifier>();

    return AllCreatureInstances(
      theme: theme,
      selectedInstanceIds: party.members.map((m) => m.instanceId).toList(),
      onTap: (inst) {
        context.read<SelectedPartyNotifier>().toggle(inst.instanceId);
      },
    );
  }

  // Stage 2: Choose which specific instances to add to party
  Widget _buildInstanceStage(FactionTheme theme, CreatureCatalog repo) {
    final species = repo.getCreatureById(_selectedSpeciesId!);
    if (species == null) {
      return Center(
        child: Text('Species missing', style: TextStyle(color: theme.text)),
      );
    }

    final party = context.watch<SelectedPartyNotifier>();

    return InstancesSheet(
      species: species,
      theme: theme,
      selectionMode: true,
      initialDetailMode: InstanceDetailMode.stats,
      selectedInstanceIds: [
        if (party.members.isNotEmpty) party.members[0].instanceId,
        if (party.members.length > 1) party.members[1].instanceId,
        if (party.members.length > 2) party.members[2].instanceId,
      ],
      onTap: (inst) {
        context.read<SelectedPartyNotifier>().toggle(inst.instanceId);
      },
    );
  }

  // ---------- Actions ----------

  void _handleBack() {
    setState(() {
      if (_showAllInstances) {
        _showAllInstances = false;
        _searchController.clear();
        _searchQuery = '';
      } else if (_isPickingInstance) {
        _selectedSpeciesId = null;
      }
    });
  }
}
