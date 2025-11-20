import 'dart:math' as math;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/providers/selected_party.dart';
import 'package:alchemons/screens/party_picker/party_picker_empty_state.dart';
import 'package:alchemons/screens/party_picker/party_picker_widgets.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/gameengines/boss_battle_engine_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/games/survival/survival_game.dart';

import 'package:alchemons/widgets/all_instaces_grid.dart';
import 'package:alchemons/widgets/creature_instances_sheet.dart';
import 'package:alchemons/widgets/creature_selection_sheet.dart';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class SurvivalGameScreen extends StatefulWidget {
  const SurvivalGameScreen({super.key});

  @override
  State<SurvivalGameScreen> createState() => _SurvivalGameScreenState();
}

class _SurvivalGameScreenState extends State<SurvivalGameScreen> {
  // Flame game instance (null until started)
  SurvivalGame? _game;
  bool _isStarting = false;

  // Party picker state (same logic as PartyPickerScreen)
  String? _selectedSpeciesId;
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
    final party = context.watch<SelectedPartyNotifier>();
    final maxSize = SelectedPartyNotifier.maxSize;
    final currentSize = party.members.length;

    return Scaffold(
      body: Stack(
        children: [
          // --- Background / Game layer ---
          Positioned.fill(
            child: _game == null
                ? Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.4),
                        radius: 1.2,
                        colors: [theme.surfaceAlt, theme.surface, Colors.black],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  )
                : GameWidget(game: _game!),
          ),

          // --- Top bar: close button & title ---
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: Colors.white,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Endless Survival',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (_game != null)
                    Text(
                      'Watching...',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                ],
              ),
            ),
          ),

          // --- Picker overlay (only when game not started) ---
          if (_game == null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: math.min(
                  MediaQuery.of(context).size.height * 0.78,
                  620,
                ),
                decoration: BoxDecoration(
                  color: theme.surface.withOpacity(0.96),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: _buildPickerOverlay(context, theme),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PICKER OVERLAY (party picker content)
  // ---------------------------------------------------------------------------

  Widget _buildPickerOverlay(BuildContext context, FactionTheme theme) {
    final db = context.watch<AlchemonsDatabase>();
    final party = context.watch<SelectedPartyNotifier>();
    final maxSize = SelectedPartyNotifier.maxSize;
    final currentSize = party.members.length;
    final canStart = !_isStarting && currentSize == maxSize;

    return Column(
      children: [
        // Handle bar
        const SizedBox(height: 6),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(height: 8),

        // Header
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
        const SizedBox(height: 6),

        // Party summary + Start button
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            children: [
              Text(
                'Party: $currentSize/$maxSize',
                style: TextStyle(
                  color: theme.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: PartyFooter(theme: theme)),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: canStart ? () => _onStartPressed(context) : null,
                icon: _isStarting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text('Start'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: theme.accent.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),

        // Divider
        Divider(color: theme.border.withOpacity(0.6), thickness: 1, height: 1),

        // Main picker content
        Expanded(
          child: StreamBuilder<List<CreatureInstance>>(
            stream: db.creatureDao.watchAllInstances(),
            builder: (context, snap) {
              final instances = snap.data ?? [];
              return _buildStageContent(theme, instances);
            },
          ),
        ),
      ],
    );
  }

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

    return _buildInstanceStage(theme, repo);
  }

  // Helper: build species list data (species + count)
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

  // Stage: Species list
  Widget _buildSpeciesStage(
    FactionTheme theme,
    List<CreatureInstance> instances,
    CreatureCatalog repo,
  ) {
    final speciesData = buildSpeciesListData(instances: instances, repo: repo);

    if (speciesData.isEmpty) {
      return const NoSpeciesOwnedWrapper();
    }

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
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
          child: Container(
            decoration: BoxDecoration(
              color: theme.surfaceAlt,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: theme.border.withOpacity(.5), width: 1),
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

        if (_searchQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
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

        Expanded(
          child: filteredSpeciesData.isEmpty
              ? NoResultsFound(theme: theme)
              : ListView.builder(
                  controller: _speciesScrollCtrl,
                  padding: const EdgeInsets.fromLTRB(5, 0, 5, 12),
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

  // Stage: All instances grid
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

  // Stage: Instances for one species
  Widget _buildInstanceStage(FactionTheme theme, CreatureCatalog repo) {
    final species = repo.getCreatureById(_selectedSpeciesId!);
    if (species == null) {
      return Center(
        child: Text('Species missing', style: TextStyle(color: theme.text)),
      );
    }

    final party = context.watch<SelectedPartyNotifier>();
    final selectedIds = party.members.map((m) => m.instanceId).toList();

    return InstancesSheet(
      species: species,
      theme: theme,
      selectionMode: true,
      initialDetailMode: InstanceDetailMode.stats,
      selectedInstanceIds: selectedIds,
      onTap: (inst) {
        context.read<SelectedPartyNotifier>().toggle(inst.instanceId);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

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

  Future<void> _onStartPressed(BuildContext context) async {
    if (_isStarting) return;

    final party = context.read<SelectedPartyNotifier>();
    final ids = party.members.map((m) => m.instanceId).toList();

    if (ids.length < SelectedPartyNotifier.maxSize) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select 4 creatures for Survival first.')),
      );
      return;
    }

    setState(() {
      _isStarting = true;
    });

    try {
      final db = context.read<AlchemonsDatabase>();
      final catalog = context.read<CreatureCatalog>();

      final team = <BattleCombatant>[];

      for (final id in ids) {
        // TODO: adapt to your DAO method name
        final instance = await db.creatureDao.getInstance(id);
        if (instance == null) continue;

        final species = catalog.getCreatureById(instance.baseId);
        if (species == null) continue;

        team.add(
          BattleCombatant.fromInstance(instance: instance, creature: species),
        );
      }

      if (team.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not build a team for Survival.')),
        );
      } else {
        setState(() {
          _game = SurvivalGame(team: team);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error starting Survival: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isStarting = false;
        });
      }
    }
  }
}
