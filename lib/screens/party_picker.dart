// lib/screens/party_picker_page.dart
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/providers/selected_party.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/creature_filter_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/alchemons_db.dart';
import '../widgets/stamina_bar.dart';
import '../providers/app_providers.dart';
import 'dart:convert';

const double _kBadgeHeight = 22.0;

/// Uniform badge container to keep size consistent across cards.
class _InfoBadge extends StatelessWidget {
  final Color bg;
  final Color border;
  final Widget child;
  final BorderRadius radius;
  final EdgeInsets padding;

  const _InfoBadge({
    super.key,
    required this.bg,
    required this.border,
    required this.child,
    this.radius = const BorderRadius.all(Radius.circular(6)),
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: _kBadgeHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          border: Border.all(color: border),
        ),
        child: Padding(
          padding: padding,
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Top-level helper so both the page and cards can use it (no duplicates).
Creature? _hydrateCreatureFromInstance(
  CreatureRepository repo,
  CreatureInstance instance,
) {
  final base = repo.getCreatureById(instance.baseId);

  var out = base;

  if (instance.isPrismaticSkin) {
    out = out?.copyWith(isPrismaticSkin: true);
  }

  if (instance.natureId != null && instance.natureId!.isNotEmpty) {
    final n = NatureCatalog.byId(instance.natureId!);
    if (n != null) out = out?.copyWith(nature: n);
  }

  final g = decodeGenetics(instance.geneticsJson);
  if (g != null) out = out?.copyWith(genetics: g);

  return out;
}

class PartyPickerPage extends StatefulWidget {
  const PartyPickerPage({super.key});

  @override
  State<PartyPickerPage> createState() => _PartyPickerPageState();
}

class _PartyPickerPageState extends State<PartyPickerPage> {
  String? _selectedSpeciesId;

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
              _buildSpeciesSection(),
              Expanded(
                child: StreamBuilder<List<CreatureInstance>>(
                  stream: db.watchAllInstances(),
                  builder: (_, snap) {
                    final rows = snap.data ?? const <CreatureInstance>[];
                    return _buildMainContent(rows);
                  },
                ),
              ),
              const _PartyFooter(),
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
                  'Team Assembly Station',
                  style: TextStyle(
                    color: Colors.indigo.shade800,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Select up to 3 specimens for field deployment',
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
              Icons.groups_rounded,
              color: Colors.blue.shade600,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeciesSection() {
    if (_selectedSpeciesId == null) {
      return Column(
        children: [
          _buildCurrentTeamDisplay(),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.science_rounded,
                  color: Colors.blue.shade600,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Select Species',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildCurrentTeamDisplay(),
        const SizedBox(height: 8),
        _buildSelectedSpeciesCard(),
      ],
    );
  }

  Widget _buildCurrentTeamDisplay() {
    final party = context.watch<SelectedPartyNotifier>();
    final count = party.members.length;

    // No need to build the full widget if no party members are selected.
    // This is a good initial check to prevent unnecessary work.
    if (count == 0) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.groups_outlined, color: Colors.grey.shade500, size: 16),
            const SizedBox(width: 8),
            Text(
              'No team members selected',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              '0 / ${SelectedPartyNotifier.maxSize}',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // The StreamBuilder will handle the asynchronous data.
    return StreamBuilder<List<CreatureInstance>>(
      stream: context.watch<AlchemonsDatabase>().watchAllInstances(),
      builder: (context, snapshot) {
        // 1. Check if snapshot.data is not yet available or is an empty list.
        // In this state, we don't have the data to hydrate the creatures yet.
        // Instead of throwing an exception, we'll return a loading indicator.
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          // This is the "wait" state you requested. The widget won't fail;
          // it will just show a temporary loading state until the data arrives.
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  'Loading team data...',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        // 2. The data is now available. We can safely proceed with hydrating the instances.
        final allInstances = snapshot.data!;
        final selectedInstances = party.members
            .map((m) {
              // Find the instance. If it's not found, this means the data
              // is out of sync (e.g., the creature was deleted).
              // Instead of throwing, we return null.
              final instance = allInstances.firstWhere(
                (inst) => inst.instanceId == m.instanceId,
                orElse: () => null as CreatureInstance,
              );
              return instance;
            })
            .whereType<CreatureInstance>() // Filter out any nulls
            .toList();

        // Handle the case where the selected instances couldn't be found.
        if (selectedInstances.isEmpty && count > 0) {
          // This can happen if the database is out of sync with the party selection.
          return _buildEmptyState('Team members not found');
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.groups_rounded,
                    color: Colors.green.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Current Team',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$count / ${SelectedPartyNotifier.maxSize}',
                    style: TextStyle(
                      color: Colors.green.shade600,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (int i = 0; i < SelectedPartyNotifier.maxSize; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: i < selectedInstances.length
                          ? _buildMiniTeamMember(selectedInstances[i])
                          : _buildEmptyTeamSlot(),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniTeamMember(CreatureInstance instance) {
    final repo = context.watch<CreatureRepository>();
    final base = repo.getCreatureById(instance.baseId);
    final name = base?.name ?? instance.baseId;

    return GestureDetector(
      onTap: () =>
          context.read<SelectedPartyNotifier>().toggle(instance.instanceId),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: base != null
                ? CreatureFilterUtils.getTypeColor(base.types.first)
                : Colors.grey.shade300,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: base != null
                      ? CreatureFilterUtils.getTypeColor(base.types.first)
                      : Colors.grey.shade400,
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: base?.spriteData != null
                    ? Image.asset(
                        'assets/images/${base!.image}',
                        fit: BoxFit.cover,
                      )
                    : Icon(
                        base != null
                            ? CreatureFilterUtils.getTypeIcon(base.types.first)
                            : Icons.help_outline,
                        size: 12,
                        color: base != null
                            ? CreatureFilterUtils.getTypeColor(base.types.first)
                            : Colors.grey.shade600,
                      ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              name,
              style: TextStyle(
                color: Colors.green.shade700,
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'L${instance.level}',
              style: TextStyle(
                color: Colors.amber.shade700,
                fontSize: 7,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTeamSlot() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.grey.shade300,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Colors.grey.shade300,
                style: BorderStyle.solid,
              ),
            ),
            child: Icon(
              Icons.add_outlined,
              size: 12,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Empty',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 8,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            '--',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 7,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedSpeciesCard() {
    final gameState = context.watch<GameStateNotifier>();

    final speciesData = gameState.discoveredCreatures.firstWhere(
      (data) => (data['creature'] as Creature).id == _selectedSpeciesId,
      orElse: () => <String, Object>{},
    );

    if (speciesData.isEmpty) return const SizedBox.shrink();

    final creature = speciesData['creature'] as Creature;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade300, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: CreatureFilterUtils.getTypeColor(creature.types.first),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: creature.spriteData != null
                  ? Image.asset('assets/images/${creature.image}')
                  : Icon(
                      CreatureFilterUtils.getTypeIcon(creature.types.first),
                      size: 16,
                      color: CreatureFilterUtils.getTypeColor(
                        creature.types.first,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  creature.name,
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Select instances',
                  style: TextStyle(
                    color: Colors.blue.shade600,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _selectedSpeciesId = null;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Text(
                'Change',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(List<CreatureInstance> allInstances) {
    if (_selectedSpeciesId == null) {
      return _buildSpeciesSelectionGrid();
    } else {
      return _buildInstanceGrid(allInstances);
    }
  }

  Widget _buildSpeciesSelectionGrid() {
    final gameState = context.watch<GameStateNotifier>();

    var filteredSpecies = gameState.discoveredCreatures.where((data) {
      return true;
    }).toList();

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
        _selectedSpeciesId = creature.id;
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
                    ? Image.asset('assets/images/${creature.image}')
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

  Widget _buildInstanceGrid(List<CreatureInstance> allInstances) {
    final filteredInstances = _filterAndSortInstances(allInstances);

    if (filteredInstances.isEmpty) {
      return _buildEmptyState('No instances match current filters');
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pets_rounded, color: Colors.blue.shade600, size: 16),
              const SizedBox(width: 6),
              Text(
                'Select Team Members',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  '${filteredInstances.length} available',
                  style: TextStyle(
                    color: Colors.blue.shade600,
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
                crossAxisCount: 2,
                childAspectRatio:
                    0.65, // Decreased from 0.85 to make cards taller
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: filteredInstances.length,
              itemBuilder: (_, i) {
                final instance = filteredInstances[i];
                final party = context.watch<SelectedPartyNotifier>();
                final selected = party.contains(instance.instanceId);
                final disabled = instance.locked;

                return _PartyCard(
                  instance: instance,
                  selected: selected,
                  disabled: disabled,
                  onTap: disabled
                      ? null
                      : () => context.read<SelectedPartyNotifier>().toggle(
                          instance.instanceId,
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<CreatureInstance> _filterAndSortInstances(List<CreatureInstance> rows) {
    // Filter by species
    var filtered = rows.where((instance) {
      return instance.baseId == _selectedSpeciesId;
    }).toList();

    return filtered;
  }

  Widget _buildEmptyState(String message) {
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
            Icon(Icons.pets_outlined, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              message,
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
}

class _PartyCard extends StatelessWidget {
  final CreatureInstance instance;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  const _PartyCard({
    required this.instance,
    required this.selected,
    required this.disabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CreatureRepository>();
    final hydrated = _hydrateCreatureFromInstance(repo, instance);
    final base = repo.getCreatureById(instance.baseId);
    final name = instance.nickname?.isNotEmpty == true
        ? instance.nickname!
        : base?.name ?? instance.baseId;
    final genetics = _parseGenetics(instance);
    final sizeVariant = _getSizeVariant(genetics);
    final tintingVariant = _getTintingVariant(genetics);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? Colors.green.shade50
              : disabled
              ? Colors.grey.shade100
              : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Colors.green.shade400
                : disabled
                ? Colors.grey.shade300
                : base != null
                ? CreatureFilterUtils.getTypeColor(
                    base.types.first,
                  ).withOpacity(0.3)
                : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? Colors.green.shade200
                  : disabled
                  ? Colors.grey.shade100
                  : Colors.grey.shade100,
              blurRadius: selected ? 6 : 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            // Creature image
            SizedBox(
              height: 100,
              width: 100,
              child: _CreatureDisplay(
                hydrated: hydrated,
                fallbackTypeColor: base != null
                    ? CreatureFilterUtils.getTypeColor(base.types.first)
                    : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 8),
            // Creature name
            Text(
              name,
              style: TextStyle(
                color: disabled ? Colors.grey.shade500 : Colors.indigo.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 6),

            // Stamina (uniform height)
            _InfoBadge(
              bg: Colors.green.shade50,
              border: Colors.green.shade200,
              child: StaminaBadge(
                instanceId: instance.instanceId,
                showCountdown: true,
              ),
            ),

            const SizedBox(height: 6),

            // Level and XP (two equal columns, uniform height)
            Row(
              children: [
                Expanded(
                  child: _InfoBadge(
                    bg: Colors.amber.shade100,
                    border: Colors.amber.shade300,
                    child: Text(
                      'L${instance.level}',
                      style: TextStyle(
                        color: Colors.amber.shade700,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _InfoBadge(
                    bg: Colors.green.shade50,
                    border: Colors.green.shade200,
                    child: Text(
                      '${instance.xp}XP',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Nature (uniform height)
            _InfoBadge(
              bg: instance.natureId != null
                  ? Colors.purple.shade50
                  : Colors.grey.shade50,
              border: instance.natureId != null
                  ? Colors.purple.shade200
                  : Colors.grey.shade200,
              radius: const BorderRadius.all(Radius.circular(4)),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Genetics variants (uniform height)
            if (genetics != null) ...[
              const SizedBox(height: 4),
              if (sizeVariant != null && sizeVariant != 'normal') ...[
                _InfoBadge(
                  bg: _getSizeColor(sizeVariant),
                  border: _getSizeTextColor(sizeVariant),
                  radius: const BorderRadius.all(Radius.circular(4)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getSizeIcon(sizeVariant),
                        size: 12,
                        color: _getSizeTextColor(sizeVariant),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getSizeLabel(sizeVariant),
                        style: TextStyle(
                          color: _getSizeTextColor(sizeVariant),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (tintingVariant != null && tintingVariant != 'normal') ...[
                const SizedBox(height: 4),
                _InfoBadge(
                  bg: _getTintingColor(tintingVariant),
                  border: _getTintingTextColor(tintingVariant),
                  radius: const BorderRadius.all(Radius.circular(4)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getTintingIcon(tintingVariant),
                        size: 12,
                        color: _getTintingTextColor(tintingVariant),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getTintingLabel(tintingVariant),
                        style: TextStyle(
                          color: _getTintingTextColor(tintingVariant),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            if (instance.isPrismaticSkin) ...[
              const SizedBox(height: 4),
              _InfoBadge(
                bg: Colors.pink.shade100,
                border: Colors.pink.shade300,
                radius: const BorderRadius.all(Radius.circular(4)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('⭐', style: TextStyle(fontSize: 10)),
                    const SizedBox(width: 4),
                    Text(
                      'Prismatic',
                      style: TextStyle(
                        color: Colors.pink.shade700,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
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

  Color _getSizeColor(String size) {
    switch (size) {
      case 'tiny':
        return Colors.pink.shade50;
      case 'small':
        return Colors.blue.shade50;
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
      case 'large':
        return Colors.green.shade700;
      case 'giant':
        return Colors.orange.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  IconData _getSizeIcon(String size) {
    switch (size) {
      case 'tiny':
        return Icons.radio_button_unchecked;
      case 'small':
        return Icons.remove_circle_outline;
      case 'large':
        return Icons.add_circle_outline;
      case 'giant':
        return Icons.circle_outlined;
      default:
        return Icons.circle;
    }
  }

  String _getSizeLabel(String size) {
    switch (size) {
      case 'tiny':
        return 'Tiny';
      case 'small':
        return 'Small';
      case 'large':
        return 'Large';
      case 'giant':
        return 'Giant';
      default:
        return size;
    }
  }

  Color _getTintingColor(String tinting) {
    switch (tinting) {
      case 'warm':
        return Colors.red.shade50;
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

  Color _getTintingTextColor(String tinting) {
    switch (tinting) {
      case 'warm':
        return Colors.red.shade700;
      case 'cool':
        return Colors.cyan.shade700;
      case 'vibrant':
        return Colors.purple.shade700;
      case 'pale':
        return Colors.grey.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  IconData _getTintingIcon(String tinting) {
    switch (tinting) {
      case 'warm':
        return Icons.local_fire_department_outlined;
      case 'cool':
        return Icons.ac_unit_outlined;
      case 'vibrant':
        return Icons.auto_awesome_outlined;
      case 'pale':
        return Icons.opacity_outlined;
      default:
        return Icons.palette_outlined;
    }
  }

  String _getTintingLabel(String tinting) {
    switch (tinting) {
      case 'warm':
        return 'Warm';
      case 'cool':
        return 'Cool';
      case 'vibrant':
        return 'Vibrant';
      case 'pale':
        return 'Pale';
      default:
        return tinting;
    }
  }
}

class _PartyFooter extends StatelessWidget {
  const _PartyFooter();

  @override
  Widget build(BuildContext context) {
    final party = context.watch<SelectedPartyNotifier>();
    final count = party.members.length;
    final canStart = count > 0 && count <= SelectedPartyNotifier.maxSize;

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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count == 0 ? 'Select Team Members' : 'Team Assembly',
                  style: TextStyle(
                    color: Colors.indigo.shade800,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Selected: $count / ${SelectedPartyNotifier.maxSize} specimens',
                  style: TextStyle(
                    color: Colors.indigo.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: canStart
                ? () => Navigator.pop(context, party.members)
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: canStart ? Colors.green.shade600 : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(8),
                boxShadow: canStart
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Deploy Team',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
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
}

class _CreatureDisplay extends StatelessWidget {
  final Creature? hydrated;
  final Color fallbackTypeColor;
  const _CreatureDisplay({
    required this.hydrated,
    required this.fallbackTypeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fallbackTypeColor, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: hydrated != null
            ? hydrated!.spriteData != null
                  ? CreatureSprite(
                      spritePath: hydrated!.spriteData!.spriteSheetPath,
                      totalFrames: hydrated!.spriteData!.totalFrames,
                      rows: hydrated!.spriteData!.rows,
                      scale: _scaleFromGenes(hydrated!.genetics),
                      saturation: _satFromGenes(hydrated!.genetics),
                      brightness: _briFromGenes(hydrated!.genetics),
                      hueShift: _hueFromGenes(hydrated!.genetics),
                      isPrismatic: hydrated!.isPrismaticSkin,
                      frameSize: Vector2(
                        hydrated!.spriteData!.frameWidth * 1.0,
                        hydrated!.spriteData!.frameHeight * 1.0,
                      ),
                      stepTime:
                          (hydrated!.spriteData!.frameDurationMs / 1000.0),
                    )
                  : Image.asset(
                      'assets/images/${hydrated!.image}',
                      fit: BoxFit.cover,
                    )
            : Icon(Icons.pets, size: 32, color: fallbackTypeColor),
      ),
    );
  }

  double _scaleFromGenes(Genetics? g) {
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

  double _satFromGenes(Genetics? g) {
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

  double _briFromGenes(Genetics? g) {
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

  double _hueFromGenes(Genetics? g) {
    switch (g?.get('tinting')) {
      case 'warm':
        return 15;
      case 'cool':
        return -15;
      default:
        return 0;
    }
  }
}

// Reuse the FilterDropdown from your feeding screen
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

class _CompactFilterDropdown extends StatelessWidget {
  final String hint;
  final List<String> items;
  final String selectedValue;
  final void Function(String?) onChanged;
  final IconData icon;
  final Color? color;

  const _CompactFilterDropdown({
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
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: themeColor, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          icon: Icon(icon, color: themeColor, size: 12),
          dropdownColor: Colors.white,
          style: TextStyle(
            color: themeColor,
            fontSize: 10,
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
                  fontSize: 10,
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
