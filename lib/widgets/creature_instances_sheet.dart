import 'dart:ui';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/screens/instance_selection_screen.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/filter_data_loader.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/stamina_bar.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/providers/species_instances_vm.dart';
import 'package:alchemons/models/creature.dart';

typedef InstanceTap = void Function(CreatureInstance instance);

enum SortBy { newest, oldest, levelHigh, levelLow }

class InstancesSheet extends StatefulWidget {
  final Creature species;
  final InstanceTap onTap;
  final String? selectedInstanceId1;
  final String? selectedInstanceId2;

  const InstancesSheet({
    super.key,
    required this.species,
    required this.onTap,
    this.selectedInstanceId1,
    this.selectedInstanceId2,
  });

  @override
  State<InstancesSheet> createState() => _InstancesSheetState();
}

class _InstancesSheetState extends State<InstancesSheet> {
  SortBy _sortBy = SortBy.newest;

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    final factionSvc = context.read<FactionService>();
    final currentFaction = factionSvc.current;
    final factionColors = getFactionColors(currentFaction);
    final primaryColor = factionColors.$1;
    final secondaryColor = factionColors.$2;

    return ChangeNotifierProvider(
      create: (_) => SpeciesInstancesVM(db, widget.species.id),
      child: Consumer<SpeciesInstancesVM>(
        builder: (_, vm, __) {
          // ✅ Apply ONLY sorting (no filters)
          var filtered = vm.instances.toList();

          // Apply sorting
          switch (_sortBy) {
            case SortBy.newest:
              filtered.sort(
                (a, b) => b.createdAtUtcMs.compareTo(a.createdAtUtcMs),
              );
              break;
            case SortBy.oldest:
              filtered.sort(
                (a, b) => a.createdAtUtcMs.compareTo(b.createdAtUtcMs),
              );
              break;
            case SortBy.levelHigh:
              filtered.sort((a, b) => b.level.compareTo(a.level));
              break;
            case SortBy.levelLow:
              filtered.sort((a, b) => a.level.compareTo(b.level));
              break;
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return Padding(
                padding: const EdgeInsets.all(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B0F14).withOpacity(0.92),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: primaryColor.withOpacity(.4),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(.2),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Header
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                            child: Column(
                              children: [
                                Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(.2),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: primaryColor.withOpacity(.35),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              primaryColor.withOpacity(.3),
                                              secondaryColor.withOpacity(.3),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.biotech_rounded,
                                          color: primaryColor,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${widget.species.name.toUpperCase()} SPECIMENS',
                                              style: const TextStyle(
                                                color: Color(0xFFE8EAED),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.8,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${filtered.length} specimens',
                                              style: const TextStyle(
                                                color: Color(0xFFB6C0CC),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              (vm.count >=
                                                  SpeciesInstancesVM.cap)
                                              ? Colors.red.withOpacity(.15)
                                              : Colors.green.withOpacity(.15),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color:
                                                (vm.count >=
                                                    SpeciesInstancesVM.cap)
                                                ? Colors.red.withOpacity(.4)
                                                : Colors.green.withOpacity(.4),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Text(
                                          '${vm.count}/${SpeciesInstancesVM.cap}',
                                          style: TextStyle(
                                            color:
                                                (vm.count >=
                                                    SpeciesInstancesVM.cap)
                                                ? Colors.red.shade300
                                                : Colors.green.shade300,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // ✅ View All Details Button
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () async {
                                    await InstanceSelectionDialog.show(
                                      context,
                                      widget.species,
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          primaryColor.withOpacity(.25),
                                          primaryColor.withOpacity(.15),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: primaryColor.withOpacity(.4),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.filter_list_rounded,
                                          color: primaryColor,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'View All & Filter',
                                          style: TextStyle(
                                            color: primaryColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ✅ Simple Sort Controls Only
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.sort_rounded,
                                  size: 16,
                                  color: primaryColor.withOpacity(.8),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        _SortChip(
                                          label: 'Newest',
                                          isSelected: _sortBy == SortBy.newest,
                                          primaryColor: primaryColor,
                                          onTap: () => setState(
                                            () => _sortBy = SortBy.newest,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        _SortChip(
                                          label: 'Oldest',
                                          isSelected: _sortBy == SortBy.oldest,
                                          primaryColor: primaryColor,
                                          onTap: () => setState(
                                            () => _sortBy = SortBy.oldest,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        _SortChip(
                                          label: 'Level ↑',
                                          isSelected:
                                              _sortBy == SortBy.levelHigh,
                                          primaryColor: primaryColor,
                                          onTap: () => setState(
                                            () => _sortBy = SortBy.levelHigh,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        _SortChip(
                                          label: 'Level ↓',
                                          isSelected:
                                              _sortBy == SortBy.levelLow,
                                          primaryColor: primaryColor,
                                          onTap: () => setState(
                                            () => _sortBy = SortBy.levelLow,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Content
                          Expanded(
                            child: filtered.isEmpty
                                ? _EmptyState(
                                    primaryColor: primaryColor,
                                    hasFilters: false,
                                  )
                                : Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      10,
                                      0,
                                      10,
                                      12,
                                    ),
                                    child: GridView.builder(
                                      controller: scrollController,
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: filtered.length,
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 2,
                                            childAspectRatio: 0.75,
                                            crossAxisSpacing: 8,
                                            mainAxisSpacing: 8,
                                          ),
                                      itemBuilder: (_, i) {
                                        final inst = filtered[i];
                                        final isSelected =
                                            inst.instanceId ==
                                                widget.selectedInstanceId1 ||
                                            inst.instanceId ==
                                                widget.selectedInstanceId2;
                                        final selectionNumber =
                                            inst.instanceId ==
                                                widget.selectedInstanceId1
                                            ? 1
                                            : inst.instanceId ==
                                                  widget.selectedInstanceId2
                                            ? 2
                                            : null;

                                        return _InstanceCard(
                                          species: widget.species,
                                          instance: inst,
                                          isSelected: isSelected,
                                          selectionNumber: selectionNumber,
                                          primaryColor: primaryColor,
                                          onTap: () => widget.onTap(inst),
                                        );
                                      },
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Keep _SortChip, _InstanceCard, _InfoRow, _EmptyState
// ❌ DELETE: _FilterChip, _FilterDropdown, _FilterDialog, _ClearFiltersButton
// Filter and Sort Chips

class _SortChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _SortChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withOpacity(.2)
              : Colors.white.withOpacity(.06),
          borderRadius: BorderRadius.circular(8),
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
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Color primaryColor;
  final bool hasFilters;

  const _EmptyState({required this.primaryColor, this.hasFilters = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(.15)),
              ),
              child: Icon(
                hasFilters ? Icons.search_off_rounded : Icons.science_outlined,
                size: 48,
                color: primaryColor.withOpacity(.6),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              hasFilters ? 'No matching specimens' : 'No specimens contained',
              style: const TextStyle(
                color: Color(0xFFE8EAED),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters
                  ? 'Try adjusting your filters'
                  : 'Acquire specimens through genetic synthesis\nor field research operations',
              style: const TextStyle(
                color: Color(0xFFB6C0CC),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Keep all the existing _InstanceCard and _InfoRow classes unchanged
class _InstanceCard extends StatelessWidget {
  final Creature species;
  final CreatureInstance instance;
  final VoidCallback onTap;
  final bool isSelected;
  final int? selectionNumber;
  final Color primaryColor;

  const _InstanceCard({
    required this.species,
    required this.instance,
    required this.onTap,
    required this.primaryColor,
    this.isSelected = false,
    this.selectionNumber,
  });

  String _getSizeName(Genetics? genetics) {
    return sizeLabels[genetics?.get('size') ?? 'normal'] ?? 'Standard';
  }

  String _getTintName(Genetics? genetics) {
    return tintLabels[genetics?.get('tinting') ?? 'normal'] ?? 'Standard';
  }

  IconData _getSizeIcon(Genetics? genetics) {
    return sizeIcons[genetics?.get('size') ?? 'normal'] ?? Icons.circle;
  }

  IconData _getTintIcon(Genetics? genetics) {
    return tintIcons[genetics?.get('tinting') ?? 'normal'] ??
        Icons.palette_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final genetics = decodeGenetics(instance.geneticsJson);
    final sizeName = _getSizeName(genetics);
    final tintName = _getTintName(genetics);
    final sizeIcon = _getSizeIcon(genetics);
    final tintIcon = _getTintIcon(genetics);

    final sd = species.spriteData;
    final g = genetics;

    final borderColor = isSelected
        ? Colors.green.shade400
        : primaryColor.withOpacity(.4);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.green.withOpacity(.12)
              : Colors.black.withOpacity(.2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: isSelected ? 2.5 : 1.5),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.green.withOpacity(.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(.12)),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Center(
                          child: sd != null
                              ? CreatureSprite(
                                  spritePath: sd.spriteSheetPath,
                                  totalFrames: sd.totalFrames,
                                  rows: sd.rows,
                                  frameSize: Vector2(
                                    sd.frameWidth.toDouble(),
                                    sd.frameHeight.toDouble(),
                                  ),
                                  stepTime: sd.frameDurationMs / 1000.0,
                                  scale: scaleFromGenes(g),
                                  saturation: satFromGenes(g),
                                  brightness: briFromGenes(g),
                                  hueShift: hueFromGenes(g),
                                  isPrismatic: instance.isPrismaticSkin,
                                )
                              : Image.asset(species.image, fit: BoxFit.contain),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                primaryColor.withOpacity(.9),
                                primaryColor,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.white.withOpacity(.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'LV ${instance.level}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      if (instance.isPrismaticSkin == true)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.purple.shade400,
                                  Colors.purple.shade600,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.white.withOpacity(.3),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                      if (isSelected && selectionNumber != null)
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade600,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.merge_type_rounded,
                                  color: Colors.white,
                                  size: 10,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '$selectionNumber',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              StaminaBadge(
                instanceId: instance.instanceId,
                showCountdown: true,
              ),
              const SizedBox(height: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.green.shade400.withOpacity(.6),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.merge_type_rounded,
                            color: Colors.green.shade300,
                            size: 10,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'PARENT $selectionNumber',
                            style: TextStyle(
                              color: Colors.green.shade300,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (instance.isPrismaticSkin == true) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.purple.shade400.withOpacity(.2),
                            Colors.purple.shade600.withOpacity(.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.purple.shade400.withOpacity(.6),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'PRISMATIC',
                        style: TextStyle(
                          color: Colors.purple.shade200,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  _InfoRow(
                    icon: sizeIcon,
                    label: sizeName,
                    color: primaryColor,
                  ),
                  const SizedBox(height: 3),
                  _InfoRow(
                    icon: tintIcon,
                    label: tintName,
                    color: primaryColor,
                  ),
                  if (instance.natureId != null &&
                      instance.natureId!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    _InfoRow(
                      icon: Icons.psychology_rounded,
                      label: instance.natureId!,
                      color: primaryColor,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color.withOpacity(.8)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFFE8EAED),
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
