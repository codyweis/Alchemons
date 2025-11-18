import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/widgets/creature_selection_sheet.dart';
import 'package:flutter/material.dart';

import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/stamina_bar.dart';
import 'package:alchemons/widgets/creature_sprite.dart';

class InstanceCard extends StatelessWidget {
  final Creature species;
  final CreatureInstance instance;
  final FactionTheme theme;
  final InstanceDetailMode detailMode;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  final bool isSelected;
  final int? selectionNumber;

  // Harvest-only props
  final Duration? harvestDuration;
  final int Function(CreatureInstance)? calculateHarvestRate;

  const InstanceCard({
    super.key,
    required this.species,
    required this.instance,
    required this.theme,
    required this.detailMode,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.selectionNumber,
    this.harvestDuration,
    this.calculateHarvestRate,
  });

  bool get _isHarvestMode =>
      harvestDuration != null && calculateHarvestRate != null;

  @override
  Widget build(BuildContext context) {
    final genetics = decodeGenetics(instance.geneticsJson);
    final sd = species.spriteData;

    final Widget bottomBlock = _isHarvestMode
        ? _HarvestBlock(
            theme: theme,
            instance: instance,
            harvestDuration: harvestDuration!,
            calculateRate: calculateHarvestRate!,
            isSelected: isSelected,
            selectionNumber: selectionNumber,
          )
        : switch (detailMode) {
            InstanceDetailMode.info => _InfoBlock(
              theme: theme,
              instance: instance,
              isSelected: isSelected,
              selectionNumber: selectionNumber,
              creatureName: species.name,
            ),
            InstanceDetailMode.stats => _StatsBlock(
              theme: theme,
              instance: instance,
              isSelected: isSelected,
              selectionNumber: selectionNumber,
            ),
            InstanceDetailMode.genetics => _GeneticsBlock(
              theme: theme,
              instance: instance,
              genetics: genetics,
              isSelected: isSelected,
              selectionNumber: selectionNumber,
            ),
          };

    Color borderColor = isSelected
        ? selectionNumber == 1
              ? theme.accent
              : selectionNumber == 2
              ? Colors.blueAccent
              : Colors.purpleAccent
        : theme.textMuted.withOpacity(.3);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.green.withOpacity(.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: borderColor, width: isSelected ? 2.5 : .3),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // sprite area
              Expanded(
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Center(
                        child: RepaintBoundary(
                          child: sd != null
                              ? InstanceSprite(
                                  creature: species,
                                  instance: instance,
                                  size: 72,
                                )
                              : Image.asset(species.image, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                    if (isSelected && selectionNumber != null)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white, width: 1.5),
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

              const SizedBox(height: 6),

              // Stamina shown at top only for genetics in non-harvest mode
              if (!_isHarvestMode &&
                  detailMode == InstanceDetailMode.genetics) ...[
                StaminaBadge(
                  instanceId: instance.instanceId,
                  showCountdown: true,
                ),
                const SizedBox(height: 6),
              ],

              bottomBlock,
            ],
          ),
        ),
      ),
    );
  }
}

// ======================= INFO BLOCK =======================

class _InfoBlock extends StatelessWidget {
  final FactionTheme theme;
  final CreatureInstance instance;
  final bool isSelected;
  final int? selectionNumber;
  final String creatureName;

  const _InfoBlock({
    required this.theme,
    required this.instance,
    required this.isSelected,
    required this.selectionNumber,
    required this.creatureName,
  });

  @override
  Widget build(BuildContext context) {
    final hasNick =
        (instance.nickname != null && instance.nickname!.trim().isNotEmpty);
    final nick = hasNick ? instance.nickname!.trim() : creatureName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isSelected && selectionNumber != null) ...[
          _ParentChip(selectionNumber: selectionNumber),
          const SizedBox(height: 4),
        ],
        Row(
          children: [
            Icon(
              instance.locked ? Icons.lock_rounded : Icons.lock_open_rounded,
              size: 12,
              color: instance.locked ? theme.primary : theme.textMuted,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                nick,
                style: TextStyle(
                  color: theme.text,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        StaminaBadge(instanceId: instance.instanceId, showCountdown: true),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.stars_rounded, size: 12, color: Colors.green.shade400),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Lv ${instance.level}',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (instance.isPrismaticSkin == true) ...[
          const SizedBox(height: 4),
          const _PrismaticChip(),
        ],
      ],
    );
  }
}

// ======================= STATS BLOCK =======================

class _StatsBlock extends StatelessWidget {
  final FactionTheme theme;
  final CreatureInstance instance;
  final bool isSelected;
  final int? selectionNumber;

  const _StatsBlock({
    required this.theme,
    required this.instance,
    required this.isSelected,
    required this.selectionNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isSelected && selectionNumber != null) ...[
          _ParentChip(selectionNumber: selectionNumber),
          const SizedBox(height: 4),
        ],
        Row(
          children: [
            Icon(Icons.stars_rounded, size: 12, color: Colors.green.shade400),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Lv ${instance.level}  •  ${instance.xp} XP',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        _StatRow(
          icon: Icons.speed,
          color: Colors.yellow.shade400,
          label: 'Speed',
          value: instance.statSpeed,
          theme: theme,
        ),
        const SizedBox(height: 2),
        _StatRow(
          icon: Icons.psychology,
          color: Colors.purple.shade300,
          label: 'Intelligence',
          value: instance.statIntelligence,
          theme: theme,
        ),
        const SizedBox(height: 2),
        _StatRow(
          icon: Icons.fitness_center,
          color: Colors.red.shade400,
          label: 'Strength',
          value: instance.statStrength,
          theme: theme,
        ),
        const SizedBox(height: 2),
        _StatRow(
          icon: Icons.favorite,
          color: Colors.pink.shade300,
          label: 'Beauty',
          value: instance.statBeauty,
          theme: theme,
        ),
        if (instance.isPrismaticSkin == true) ...[
          const SizedBox(height: 4),
          const _PrismaticChip(),
        ],
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final double value;
  final FactionTheme theme;

  const _StatRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '$label: ${value.toStringAsFixed(1)}',
            style: TextStyle(
              color: theme.text,
              fontSize: 10,
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

// ======================= GENETICS BLOCK =======================

class _GeneticsBlock extends StatelessWidget {
  final FactionTheme theme;
  final CreatureInstance instance;
  final Genetics? genetics;
  final bool isSelected;
  final int? selectionNumber;

  const _GeneticsBlock({
    required this.theme,
    required this.instance,
    required this.genetics,
    required this.isSelected,
    required this.selectionNumber,
  });

  String _getSizeName() =>
      sizeLabels[genetics?.get('size') ?? 'normal'] ?? 'Standard';

  String _getTintName() =>
      tintLabels[genetics?.get('tinting') ?? 'normal'] ?? 'Standard';

  IconData _getSizeIcon() =>
      sizeIcons[genetics?.get('size') ?? 'normal'] ?? Icons.circle;

  IconData _getTintIcon() =>
      tintIcons[genetics?.get('tinting') ?? 'normal'] ?? Icons.palette_outlined;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isSelected && selectionNumber != null) ...[
          _ParentChip(selectionNumber: selectionNumber),
          const SizedBox(height: 4),
        ],
        if (instance.isPrismaticSkin == true) ...[
          const _PrismaticChip(),
          const SizedBox(height: 4),
        ],
        _InfoRow(
          icon: _getSizeIcon(),
          label: _getSizeName(),
          color: theme.primary,
          textColor: theme.text,
        ),
        const SizedBox(height: 3),
        _InfoRow(
          icon: _getTintIcon(),
          label: _getTintName(),
          color: theme.primary,
          textColor: theme.text,
        ),
        if (instance.natureId != null && instance.natureId!.isNotEmpty) ...[
          const SizedBox(height: 3),
          _InfoRow(
            icon: Icons.psychology_rounded,
            label: instance.natureId!,
            color: theme.primary,
            textColor: theme.text,
          ),
        ],
      ],
    );
  }
}

// ======================= HARVEST BLOCK =======================

class _HarvestBlock extends StatelessWidget {
  final FactionTheme theme;
  final CreatureInstance instance;
  final Duration harvestDuration;
  final int Function(CreatureInstance) calculateRate;
  final bool isSelected;
  final int? selectionNumber;

  const _HarvestBlock({
    required this.theme,
    required this.instance,
    required this.harvestDuration,
    required this.calculateRate,
    required this.isSelected,
    required this.selectionNumber,
  });

  @override
  Widget build(BuildContext context) {
    final rate = calculateRate(instance);
    final total = rate * harvestDuration.inMinutes;

    final genetics = decodeGenetics(instance.geneticsJson);
    final sizeKey = (genetics?.get('size') ?? 'normal');
    final sizeName = sizeLabels[sizeKey] ?? sizeKey;
    final sizeIcon = sizeIcons[sizeKey] ?? Icons.straighten_rounded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Stamina badge at top in harvest mode
        StaminaBadge(instanceId: instance.instanceId, showCountdown: true),
        const SizedBox(height: 6),

        if (isSelected && selectionNumber != null) ...[
          _ParentChip(selectionNumber: selectionNumber),
          const SizedBox(height: 4),
        ],

        if (instance.isPrismaticSkin == true) ...[
          const _PrismaticChip(),
          const SizedBox(height: 4),
        ],

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.stars_rounded,
                  size: 12,
                  color: Colors.green.shade400,
                ),
                const SizedBox(width: 4),
                Text(
                  'Lv ${instance.level}',
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            Row(
              children: [
                Icon(
                  Icons.inventory_2_rounded,
                  size: 12,
                  color: theme.accent.withOpacity(.9),
                ),
                const SizedBox(width: 4),
                Text(
                  'Total: $total',
                  style: TextStyle(
                    color: theme.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(sizeIcon, size: 12, color: theme.primary.withOpacity(.9)),
                const SizedBox(width: 4),
                Text(
                  sizeName,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            if (instance.natureId != null && instance.natureId!.isNotEmpty) ...[
              Row(
                children: [
                  Icon(
                    Icons.psychology_rounded,
                    size: 12,
                    color: theme.primary.withOpacity(.8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    instance.natureId!,
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ======================= SHARED MINI WIDGETS =======================

class _ParentChip extends StatelessWidget {
  final int? selectionNumber;
  const _ParentChip({required this.selectionNumber});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
    );
  }
}

class _PrismaticChip extends StatelessWidget {
  const _PrismaticChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
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
            style: TextStyle(
              fontSize: 10,
              color: textColor,
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

// Public empty-state widget for both screens
class InstancesEmptyState extends StatelessWidget {
  final Color primaryColor;
  final bool hasFilters;

  const InstancesEmptyState({
    super.key,
    required this.primaryColor,
    this.hasFilters = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
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
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters
                  ? 'Try adjusting filters'
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
