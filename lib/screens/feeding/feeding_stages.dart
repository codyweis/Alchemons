import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/show_quick_instance_dialog.dart';
import 'package:alchemons/widgets/all_instaces_grid.dart';
import 'package:alchemons/widgets/creature_instances_sheet.dart';
import 'package:alchemons/widgets/creature_selection_sheet.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flutter/material.dart';

import 'feeding_widgets.dart';

class FeedingStageBuilders {
  final BuildContext context;
  final TextEditingController searchController;
  final String searchQuery;
  final ScrollController speciesScrollController;
  final ValueChanged<String> onSearchQueryChanged;
  final ValueChanged<String> onSpeciesSelected;
  final ValueChanged<String> onInstanceSelected;
  final ValueChanged<CreatureInstance> onAllInstancesInstanceSelected;
  final Future<void> Function(String) onFodderToggle;
  final String? targetSpeciesId;
  final String? targetInstanceId;
  final Set<String> selectedFodder;

  const FeedingStageBuilders({
    required this.context,
    required this.searchController,
    required this.searchQuery,
    required this.speciesScrollController,
    required this.onSearchQueryChanged,
    required this.onSpeciesSelected,
    required this.onInstanceSelected,
    required this.onAllInstancesInstanceSelected,
    required this.onFodderToggle,
    required this.targetSpeciesId,
    required this.targetInstanceId,
    required this.selectedFodder,
  });

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

  Widget buildAllInstancesStage(
    FactionTheme theme,
    List<CreatureInstance> instances,
    CreatureCatalog repo,
  ) {
    if (instances.isEmpty) {
      return const NoSpeciesOwnedWrapper();
    }

    return AllCreatureInstances(
      theme: theme,
      selectedInstanceIds: const [],
      onTap: onAllInstancesInstanceSelected,
    );
  }

  Widget buildSpeciesStage(
    FactionTheme theme,
    List<CreatureInstance> instances,
    CreatureCatalog repo,
  ) {
    final speciesData = buildSpeciesListData(instances: instances, repo: repo);

    if (speciesData.isEmpty) {
      return const NoSpeciesOwnedWrapper();
    }

    final filteredSpeciesData = searchQuery.isEmpty
        ? speciesData
        : speciesData.where((data) {
            final creature = data['creature'] as Creature;
            final name = creature.name.toLowerCase();
            final types = creature.types.join(' ').toLowerCase();
            final query = searchQuery.toLowerCase();
            return name.contains(query) || types.contains(query);
          }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(5, 0, 5, 5),
          child: Container(
            decoration: BoxDecoration(
              color: theme.surfaceAlt,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: theme.border.withOpacity(.5), width: 1),
            ),
            child: TextField(
              controller: searchController,
              onChanged: onSearchQueryChanged,
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
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: theme.textMuted,
                          size: 20,
                        ),
                        onPressed: () {
                          searchController.clear();
                          onSearchQueryChanged('');
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
        if (searchQuery.isNotEmpty)
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
        Expanded(
          child: filteredSpeciesData.isEmpty
              ? NoResultsFound(theme: theme)
              : ListView.builder(
                  controller: speciesScrollController,
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
                        onTap: () => onSpeciesSelected(creature.id),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget buildInstanceStage(FactionTheme theme, CreatureCatalog repo) {
    final species = repo.getCreatureById(targetSpeciesId!);
    if (species == null) {
      return Center(
        child: Text('Species missing', style: TextStyle(color: theme.text)),
      );
    }

    return InstancesSheet(
      species: species,
      theme: theme,
      selectionMode: false,
      initialDetailMode: InstanceDetailMode.stats,
      onTap: (inst) => onInstanceSelected(inst.instanceId),
    );
  }

  Widget buildFodderStage(
    FactionTheme theme,
    List<CreatureInstance> instances,
    CreatureCatalog repo,
  ) {
    final candidates =
        instances
            .where(
              (inst) =>
                  inst.baseId == targetSpeciesId &&
                  inst.instanceId != targetInstanceId &&
                  !inst.locked,
            )
            .toList()
          ..sort((a, b) {
            final aMax = [
              a.statSpeed,
              a.statIntelligence,
              a.statStrength,
              a.statBeauty,
            ].reduce((a, b) => a > b ? a : b);
            final bMax = [
              b.statSpeed,
              b.statIntelligence,
              b.statStrength,
              b.statBeauty,
            ].reduce((a, b) => a > b ? a : b);
            return bMax.compareTo(aMax);
          });

    if (candidates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No available fodder specimens.\nThey might be locked or already selected.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 180),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: .75,
      ),
      itemCount: candidates.length,
      itemBuilder: (context, i) {
        final inst = candidates[i];
        final isSelected = selectedFodder.contains(inst.instanceId);
        final baseCreature = repo.getCreatureById(inst.baseId);

        final stats = {
          'SPD': inst.statSpeed,
          'INT': inst.statIntelligence,
          'STR': inst.statStrength,
          'BEA': inst.statBeauty,
        };
        final highestEntry = stats.entries.reduce(
          (a, b) => a.value > b.value ? a : b,
        );

        return GestureDetector(
          onTap: () => onFodderToggle(inst.instanceId),
          onLongPress: baseCreature == null
              ? null
              : () {
                  showQuickInstanceDialog(
                    context: context,
                    theme: theme,
                    creature: baseCreature,
                    instance: inst,
                  );
                },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.green.withOpacity(0.15)
                  : theme.surface,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: isSelected ? Colors.green : theme.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (baseCreature != null)
                  InstanceSprite(
                    creature: baseCreature,
                    instance: inst,
                    size: 36,
                  )
                else
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.surfaceAlt,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                const SizedBox(height: 3),
                if (inst.nickname != null || baseCreature != null)
                  Text(
                    inst.nickname ?? baseCreature!.name,
                    style: TextStyle(
                      color: isSelected ? Colors.green : theme.text,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                Text(
                  'Lv ${inst.level}',
                  style: TextStyle(
                    color: isSelected ? Colors.green.shade300 : theme.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.green.withOpacity(0.2)
                        : theme.surfaceAlt,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '${highestEntry.key} ${highestEntry.value.toStringAsFixed(1)}',
                    style: TextStyle(
                      color: isSelected ? Colors.green : theme.primary,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
