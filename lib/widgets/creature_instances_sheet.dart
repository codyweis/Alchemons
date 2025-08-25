import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/stamina_bar.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/providers/species_instances_vm.dart';
import 'package:alchemons/models/creature.dart';
import 'dart:convert';

typedef InstanceTap = void Function(CreatureInstance instance);

class InstancesSheet extends StatelessWidget {
  final Creature species;
  final InstanceTap onTap;
  final String? selectedInstanceId1; // Currently selected parent 1
  final String? selectedInstanceId2; // Currently selected parent 2

  const InstancesSheet({
    super.key,
    required this.species,
    required this.onTap,
    this.selectedInstanceId1,
    this.selectedInstanceId2,
  });

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();

    return ChangeNotifierProvider(
      create: (_) => SpeciesInstancesVM(db, species.id),
      child: Consumer<SpeciesInstancesVM>(
        builder: (_, vm, __) {
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.3,
            maxChildSize: 0.85,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  border: Border.all(color: Colors.indigo.shade200, width: 2),
                ),
                child: Column(
                  children: [
                    // Fixed header section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        children: [
                          Container(
                            width: 32,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.biotech_rounded,
                                  color: Colors.indigo.shade600,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${species.name} Specimens',
                                      style: TextStyle(
                                        color: Colors.indigo.shade800,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      'Containment facility',
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: (vm.count >= SpeciesInstancesVM.cap)
                                      ? Colors.red.shade50
                                      : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: (vm.count >= SpeciesInstancesVM.cap)
                                        ? Colors.red.shade300
                                        : Colors.green.shade300,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '${vm.count}/${SpeciesInstancesVM.cap}',
                                  style: TextStyle(
                                    color: (vm.count >= SpeciesInstancesVM.cap)
                                        ? Colors.red.shade700
                                        : Colors.green.shade700,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Scrollable content section
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                        child: vm.instances.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.science_outlined,
                                        size: 48,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      "No ${species.name} specimens",
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "Acquire specimens through genetic synthesis\nor field research operations",
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 11,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : GridView.builder(
                                controller: scrollController,
                                itemCount: vm.instances.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      childAspectRatio: 0.8,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                    ),
                                itemBuilder: (_, i) {
                                  final inst = vm.instances[i];
                                  final isSelected =
                                      inst.instanceId == selectedInstanceId1 ||
                                      inst.instanceId == selectedInstanceId2;
                                  final selectionNumber =
                                      inst.instanceId == selectedInstanceId1
                                      ? 1
                                      : inst.instanceId == selectedInstanceId2
                                      ? 2
                                      : null;

                                  return _InstanceCard(
                                    species: species,
                                    instance: inst,
                                    isSelected: isSelected,
                                    selectionNumber: selectionNumber,
                                    onTap: () => onTap(inst),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _InstanceCard extends StatelessWidget {
  final Creature species;
  final CreatureInstance instance;
  final VoidCallback onTap;
  final bool isSelected;
  final int? selectionNumber; // 1 for parent 1, 2 for parent 2

  const _InstanceCard({
    required this.species,
    required this.instance,
    required this.onTap,
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? Colors.green.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Colors.green.shade400
                  : Colors.indigo.shade200,
              width: isSelected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? Colors.green.shade200.withOpacity(0.7)
                    : Colors.indigo.shade100.withOpacity(0.5),
                blurRadius: isSelected ? 6 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Padding(
                              padding: const EdgeInsets.all(3),

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
                                  : Image.asset(
                                      species
                                          .image, // fallback static image if no sprite sheet
                                      fit: BoxFit.contain,
                                    ),
                            ),
                          ),
                        ),

                        Positioned(
                          top: -1,
                          left: -1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade600,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                            child: Text(
                              'L${instance.level}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        if (instance.isPrismaticSkin == true)
                          Positioned(
                            top: 3,
                            right: 3,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade600,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                color: Colors.white,
                                size: 10,
                              ),
                            ),
                          ),

                        // Selection indicator
                        if (isSelected && selectionNumber != null)
                          Positioned(
                            bottom: 3,
                            right: 3,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade600,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.merge_type_rounded,
                                    color: Colors.white,
                                    size: 8,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '$selectionNumber',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
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
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Selected badge for breeding
                      if (isSelected) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.green.shade400,
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.merge_type_rounded,
                                color: Colors.green.shade700,
                                size: 8,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'Parent $selectionNumber',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 3),
                      ],

                      if (instance.isPrismaticSkin == true) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.purple.shade300,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            'Prismatic',
                            style: TextStyle(
                              color: Colors.purple.shade700,
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                      ],
                      Row(
                        children: [
                          Icon(
                            sizeIcon,
                            size: 12,
                            color: Colors.indigo.shade600,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              sizeName,
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.indigo.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            tintIcon,
                            size: 12,
                            color: Colors.indigo.shade600,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              tintName,
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.indigo.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (instance.natureId != null &&
                          instance.natureId!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.psychology_rounded,
                              size: 12,
                              color: Colors.indigo.shade600,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                instance.natureId!,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.indigo.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
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
    );
  }
}
