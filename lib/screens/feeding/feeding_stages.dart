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
import 'package:alchemons/widgets/fast_long_press_detector.dart';
import 'package:flutter/material.dart';

import 'feeding_widgets.dart';
import 'package:alchemons/widgets/app_icons.dart';

enum FeedingSpeciesSort { name, amount }

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
  final FeedingSpeciesSort speciesSort;
  final ValueChanged<FeedingSpeciesSort> onSpeciesSortChanged;

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
    required this.speciesSort,
    required this.onSpeciesSortChanged,
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
    result.sort((a, b) {
      final creatureA = a['creature'] as Creature;
      final creatureB = b['creature'] as Creature;
      final countA = a['count'] as int;
      final countB = b['count'] as int;

      return switch (speciesSort) {
        FeedingSpeciesSort.amount =>
          countB != countA
              ? countB.compareTo(countA)
              : creatureA.name.compareTo(creatureB.name),
        FeedingSpeciesSort.name =>
          creatureA.name != creatureB.name
              ? creatureA.name.compareTo(creatureB.name)
              : countB.compareTo(countA),
      };
    });
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
      prefsScopeKey: 'feeding_all_instances',
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
          child: Row(
            children: [
              Expanded(
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
                        color: t.textSecondary.withValues(alpha: .7),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      prefixIcon: Icon(
                        AppIcons.search_rounded,
                        color: t.textSecondary,
                        size: 20,
                      ),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                AppIcons.clear_rounded,
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
              const SizedBox(width: 6),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(5),
                  onTap: () {
                    onSpeciesSortChanged(
                      speciesSort == FeedingSpeciesSort.name
                          ? FeedingSpeciesSort.amount
                          : FeedingSpeciesSort.name,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: t.bg1,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: t.borderDim, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          AppIcons.sort_rounded,
                          color: t.textSecondary,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          speciesSort == FeedingSpeciesSort.amount
                              ? 'Amount'
                              : 'Name',
                          style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
      prefsScopeKey: 'feeding_target_instances',
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
    final fc = FC(theme);
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
            'No available feeding specimens.\nThey might be locked or already selected.',
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
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 180),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 6,
        mainAxisSpacing: 8,
        childAspectRatio: 0.66,
      ),
      itemCount: candidates.length,
      itemBuilder: (context, i) {
        final inst = candidates[i];
        final isSelected = selectedFodder.contains(inst.instanceId);
        final baseCreature = repo.getCreatureById(inst.baseId);
        return FastLongPressDetector(
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
                  color: t.bg1,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected
                        ? fc.amber.withValues(alpha: 0.85)
                        : t.borderDim,
                    width: isSelected ? 1.5 : 1.0,
                  ),
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
                          color: t.textPrimary,
                          fontSize: 12,
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
                        color: t.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'XP FEED',
                      style: TextStyle(
                        color: t.success,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
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
                    decoration: BoxDecoration(
                      color: fc.amberGlow,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(AppIcons.check, size: 10, color: fc.bg0),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
