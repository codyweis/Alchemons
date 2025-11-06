// ============================================================================
// STAT POTENTIAL SECTION
// ============================================================================

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_detail/section_block.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StatPotentialBar extends StatelessWidget {
  final FactionTheme theme;
  final String statName;
  final double currentValue;
  final double potential;
  final IconData icon;

  const StatPotentialBar({
    required this.theme,
    required this.statName,
    required this.currentValue,
    required this.potential,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final currentPercent = (currentValue / 5.0).clamp(0.0, 1.0);
    final potentialPercent = (potential / 5.0).clamp(0.0, 1.0);
    final roomForGrowth = potential - currentValue;
    final isNearMax = roomForGrowth < 0.3;
    final isPerfectPotential = potential >= 4.8;

    return Row(
      children: [
        Icon(icon, size: 16, color: theme.textMuted),
        const SizedBox(width: 8),

        SizedBox(
          width: 85,
          child: Text(
            statName,
            style: TextStyle(
              color: theme.text,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              return Stack(
                children: [
                  Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: theme.surfaceAlt,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: theme.border, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Row(
                        children: [
                          Container(
                            width: availableWidth * potentialPercent,
                            decoration: BoxDecoration(
                              color: isPerfectPotential
                                  ? Colors.purple.withOpacity(.15)
                                  : Colors.grey.withOpacity(.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Container(
                    height: 20,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Row(
                        children: [
                          Container(
                            width: availableWidth * currentPercent,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.accent,
                                  theme.accent.withOpacity(.7),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        const SizedBox(width: 8),

        SizedBox(
          width: 70,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${currentValue.toStringAsFixed(1)} / ${potential.toStringAsFixed(1)}',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.clip,
                maxLines: 1,
              ),
              if (isNearMax)
                Text(
                  'Near Max',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Text(
                  '+${roomForGrowth.toStringAsFixed(1)}',
                  style: TextStyle(color: theme.textMuted, fontSize: 8),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PotentialSummary extends StatelessWidget {
  final FactionTheme theme;
  final CreatureInstance instance;

  const _PotentialSummary({required this.theme, required this.instance});

  @override
  Widget build(BuildContext context) {
    final totalPotential =
        instance.statSpeedPotential +
        instance.statIntelligencePotential +
        instance.statStrengthPotential +
        instance.statBeautyPotential;

    final totalCurrent =
        instance.statSpeed +
        instance.statIntelligence +
        instance.statStrength +
        instance.statBeauty;

    final potentials = {
      'Speed': instance.statSpeedPotential,
      'Intelligence': instance.statIntelligencePotential,
      'Strength': instance.statStrengthPotential,
      'Beauty': instance.statBeautyPotential,
    };

    final highestPotential = potentials.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );

    final isHighPotential = totalPotential >= 18.0;
    final isLegendaryPotential = totalPotential >= 19.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isLegendaryPotential
            ? Colors.purple.withOpacity(.08)
            : isHighPotential
            ? Colors.blue.withOpacity(.08)
            : theme.surfaceAlt.withOpacity(.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLegendaryPotential
              ? Colors.purple.withOpacity(.3)
              : isHighPotential
              ? Colors.blue.withOpacity(.3)
              : theme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Growth Potential',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isLegendaryPotential
                      ? Colors.purple.withOpacity(.2)
                      : isHighPotential
                      ? Colors.blue.withOpacity(.2)
                      : Colors.grey.withOpacity(.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isLegendaryPotential
                      ? 'LEGENDARY'
                      : isHighPotential
                      ? 'EXCEPTIONAL'
                      : 'AVERAGE',
                  style: TextStyle(
                    color: isLegendaryPotential
                        ? Colors.purple
                        : isHighPotential
                        ? Colors.blue
                        : Colors.grey,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Total: ${totalCurrent.toStringAsFixed(1)} / ${totalPotential.toStringAsFixed(1)}',
            style: TextStyle(color: theme.textMuted, fontSize: 10),
          ),
          const SizedBox(height: 4),
          Text(
            'Best Gene: ${highestPotential.key} (${highestPotential.value.toStringAsFixed(1)})',
            style: TextStyle(
              color: theme.primary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class StatPotentialBlock extends StatelessWidget {
  final FactionTheme theme;
  final String? instanceId;

  const StatPotentialBlock({required this.theme, this.instanceId});

  Future<CreatureInstance?> _getInstance(BuildContext context) async {
    if (instanceId == null) return null;
    final db = context.read<AlchemonsDatabase>();
    return await db.creatureDao.getInstance(instanceId!);
  }

  @override
  Widget build(BuildContext context) {
    if (instanceId == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<CreatureInstance?>(
      future: _getInstance(context),
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data == null) {
          return const SizedBox.shrink();
        }

        final instance = snap.data!;

        return SectionBlock(
          theme: theme,
          title: 'Stat Potential',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.primary.withOpacity(.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.primary.withOpacity(.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: theme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Understanding Potential',
                          style: TextStyle(
                            color: theme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Each creature has a genetic potential cap for every stat. Feeding can increase stats up to their potential, but never beyond. Breed creatures with high potential to create powerful offspring!',
                      style: TextStyle(
                        color: theme.textMuted,
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              StatPotentialBar(
                theme: theme,
                statName: 'Speed',
                currentValue: instance.statSpeed,
                potential: instance.statSpeedPotential,
                icon: Icons.flash_on,
              ),
              const SizedBox(height: 8),
              StatPotentialBar(
                theme: theme,
                statName: 'Intelligence',
                currentValue: instance.statIntelligence,
                potential: instance.statIntelligencePotential,
                icon: Icons.psychology,
              ),
              const SizedBox(height: 8),
              StatPotentialBar(
                theme: theme,
                statName: 'Strength',
                currentValue: instance.statStrength,
                potential: instance.statStrengthPotential,
                icon: Icons.fitness_center,
              ),
              const SizedBox(height: 8),
              StatPotentialBar(
                theme: theme,
                statName: 'Beauty',
                currentValue: instance.statBeauty,
                potential: instance.statBeautyPotential,
                icon: Icons.auto_awesome,
              ),

              const SizedBox(height: 12),

              _PotentialSummary(theme: theme, instance: instance),
            ],
          ),
        );
      },
    );
  }
}
