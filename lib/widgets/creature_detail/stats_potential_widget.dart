// ============================================================================
// STAT POTENTIAL SECTION — Scorched Forge style
// ============================================================================

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StatPotentialBar extends StatelessWidget {
  // ignore: unused_field
  final FactionTheme? theme;
  final String statName;
  final double currentValue;
  final double potential;

  const StatPotentialBar({
    super.key,
    this.theme,
    required this.statName,
    required this.currentValue,
    required this.potential,
  });

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final ft = FT(fc);
    final currentPercent = (currentValue / 5.0).clamp(0.0, 1.0);
    final potentialPercent = (potential / 5.0).clamp(0.0, 1.0);
    final roomForGrowth = potential - currentValue;
    final isNearMax = roomForGrowth < 0.3;
    final isPerfectPotential = potential >= 4.8;

    return Row(
      children: [
        SizedBox(
          width: 112,
          child: Text(
            statName.toUpperCase(),
            style: ft.label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
          ),
        ),

        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              return Stack(
                children: [
                  Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: fc.bg3,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: fc.borderDim),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(1),
                      child: Row(
                        children: [
                          Container(
                            width: availableWidth * potentialPercent,
                            color: isPerfectPotential
                                ? FC.purple.withValues(alpha: .18)
                                : fc.bg2,
                          ),
                        ],
                      ),
                    ),
                  ),

                  Container(
                    height: 16,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(1),
                      child: Row(
                        children: [
                          Container(
                            width: availableWidth * currentPercent,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  fc.amberGlow,
                                  fc.amber.withValues(alpha: .7),
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
                  fontFamily: 'monospace',
                  color: fc.textPrimary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.clip,
                maxLines: 1,
              ),
              if (isNearMax)
                Text(
                  'Near Max',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: fc.amberBright,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Text(
                  '+${roomForGrowth.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: fc.textMuted,
                    fontSize: 8,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PotentialSummary extends StatelessWidget {
  final CreatureInstance instance;

  const _PotentialSummary({required this.instance});

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final ft = FT(fc);
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

    final tierLabel = isLegendaryPotential
        ? 'LEGENDARY'
        : isHighPotential
        ? 'EXCEPTIONAL'
        : 'STANDARD';
    final tierColor = isLegendaryPotential
        ? FC.purple
        : isHighPotential
        ? FC.blue
        : fc.textMuted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isLegendaryPotential
            ? FC.purple.withValues(alpha: .08)
            : isHighPotential
            ? FC.blue.withValues(alpha: .08)
            : fc.bg3,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: isLegendaryPotential
              ? FC.purple.withValues(alpha: .35)
              : isHighPotential
              ? FC.blue.withValues(alpha: .35)
              : fc.borderDim,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('GROWTH POTENTIAL', style: ft.label),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: tierColor.withValues(alpha: .45),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  tierLabel,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: tierColor,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Total: ${totalCurrent.toStringAsFixed(1)} / ${totalPotential.toStringAsFixed(1)}',
            style: ft.body.copyWith(fontSize: 10),
          ),
          const SizedBox(height: 4),
          Text(
            'Best Gene: ${highestPotential.key} (${highestPotential.value.toStringAsFixed(1)})',
            style: TextStyle(
              fontFamily: 'monospace',
              color: fc.amberBright,
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
  // ignore: unused_field
  final FactionTheme? theme;
  final String? instanceId;

  const StatPotentialBlock({super.key, this.theme, this.instanceId});

  Future<CreatureInstance?> _getInstance(BuildContext context) async {
    if (instanceId == null) return null;
    final db = context.read<AlchemonsDatabase>();
    return await db.creatureDao.getInstance(instanceId!);
  }

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final ft = FT(fc);
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info note
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: fc.amberDim.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: fc.amber.withValues(alpha: .2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 12, color: fc.amber),
                      const SizedBox(width: 6),
                      Text('UNDERSTANDING POTENTIAL', style: ft.sectionTitle),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Each creature has a genetic potential cap for every stat. Feeding can increase stats up to their potential, but never beyond. Breed creatures with high potential to create powerful offspring!',
                    style: ft.body.copyWith(fontSize: 10, height: 1.4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            StatPotentialBar(
              statName: 'Speed',
              currentValue: instance.statSpeed,
              potential: instance.statSpeedPotential,
            ),
            const SizedBox(height: 8),
            StatPotentialBar(
              statName: 'Intelligence',
              currentValue: instance.statIntelligence,
              potential: instance.statIntelligencePotential,
            ),
            const SizedBox(height: 8),
            StatPotentialBar(
              statName: 'Strength',
              currentValue: instance.statStrength,
              potential: instance.statStrengthPotential,
            ),
            const SizedBox(height: 8),
            StatPotentialBar(
              statName: 'Beauty',
              currentValue: instance.statBeauty,
              potential: instance.statBeautyPotential,
            ),

            const SizedBox(height: 12),

            _PotentialSummary(instance: instance),
          ],
        );
      },
    );
  }
}
