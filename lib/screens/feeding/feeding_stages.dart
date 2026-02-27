import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/show_quick_instance_dialog.dart';
import 'package:alchemons/widgets/all_instaces_grid.dart';
import 'package:alchemons/widgets/creature_instances_sheet.dart';
import 'package:alchemons/widgets/creature_selection_sheet.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
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
    final t = ForgeTokens(theme);
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
              color: t.bg1,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: t.borderDim, width: 1),
            ),
            child: TextField(
              controller: searchController,
              onChanged: onSearchQueryChanged,
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Search species...',
                hintStyle: TextStyle(
                  color: t.textSecondary.withOpacity(.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: t.textSecondary,
                  size: 20,
                ),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: t.textSecondary,
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
                    color: t.textSecondary,
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
    final t = ForgeTokens(theme);
    final species = repo.getCreatureById(targetSpeciesId!);
    if (species == null) {
      return Center(
        child: Text(
          'Species missing',
          style: TextStyle(color: t.textSecondary),
        ),
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
    final t = ForgeTokens(theme);
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
              color: t.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 180),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 0.72,
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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSelected ? FC.amberDim.withOpacity(0.2) : t.bg1,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected ? FC.amberGlow : t.borderDim,
                    width: isSelected ? 2.0 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: FC.amber.withOpacity(0.35),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (baseCreature != null)
                      InstanceSprite(
                        creature: baseCreature,
                        instance: inst,
                        size: 44,
                      )
                    else
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: t.bg2,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(4),
                          ),
                        ),
                      ),
                    const SizedBox(height: 3),
                    if (inst.nickname != null || baseCreature != null)
                      Text(
                        inst.nickname ?? baseCreature!.name,
                        style: TextStyle(
                          color: isSelected ? FC.amberBright : t.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 2),
                    Text(
                      'Lv ${inst.level}',
                      style: TextStyle(
                        color: isSelected ? FC.amber : t.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? FC.amberDim.withOpacity(0.25)
                            : t.bg2,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '${highestEntry.key} ${highestEntry.value.toStringAsFixed(1)}',
                        style: TextStyle(
                          color: isSelected ? FC.amberBright : FC.amber,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Positioned(
                  top: -5,
                  right: -5,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: FC.amberGlow,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 10, color: FC.bg0),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
