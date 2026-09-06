// ============================================================================
// STAT POTENTIAL SECTION — Scorched Forge style
// ============================================================================

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/services/creature_repository.dart';

class StatPotentialBar extends StatelessWidget {
  // ignore: unused_field
  final FactionTheme? theme;
  final String statName;
  final double currentValue;
  final double potential;
  final int baseStat;
  final int enhancementRank;

  const StatPotentialBar({
    super.key,
    this.theme,
    required this.statName,
    required this.currentValue,
    required this.potential,
    required this.baseStat,
    required this.enhancementRank,
  });

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final ft = FT(fc);
    final isDark = context.read<FactionTheme>().isDark;
    final currentRating = AlchemonStatSystem.displayRating(currentValue);
    final potentialRating = AlchemonStatSystem.normalizePotential(potential);
    final potentialPercent = (potentialRating / 100.0).clamp(0.0, 1.0);
    final isNearMax = enhancementRank >= AlchemonStatSystem.maxEnhancementRank;
    final isPerfectPotential = potentialRating >= 95;
    final trackColor = isDark ? fc.bg3 : fc.bg0.withValues(alpha: 0.06);
    final trackBorderColor = isDark ? fc.borderDim : fc.borderMid;
    final potentialFill = [
      FC.purple,
      isDark ? FC.purple.withValues(alpha: 0.72) : FC.blue,
    ];

    return Row(
      children: [
        // Scale-to-fit rather than overflow: the longest label
        // (INTELLIGENCE) was running straight into the bar, because this box
        // was fixed at 112 with overflow left visible.
        SizedBox(
          width: 116,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                statName.toUpperCase(),
                style: ft.label,
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              // The track Container draws a 1px border, so its content box is
              // 2px narrower. Sizing the fills off the full width overflowed
              // by exactly that whenever a stat sat at full potential.
              final fillWidth = (availableWidth - 2).clamp(
                0.0,
                double.infinity,
              );
              return Stack(
                children: [
                  Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: trackColor,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: trackBorderColor),
                    ),
                  ),

                  // Inset by the same 1px so the current fill lines up with
                  // the potential zone behind it instead of sitting a pixel
                  // proud of it on the left.
                  Padding(
                    padding: const EdgeInsets.all(1),
                    child: SizedBox(
                      height: 14,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(1),
                        child: Row(
                          children: [
                            Container(
                              width: fillWidth * potentialPercent,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: potentialFill),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        const SizedBox(width: 8),

        // Wide enough for the worst case ("10.0 / 10.0"). At 70 the potential
        // was clipped clean off, so every row read "2.5 /" with no cap shown.
        SizedBox(
          width: 92,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  textBaseline: TextBaseline.alphabetic,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  children: [
                    Text(
                      '$currentRating',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: fc.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '  P$potentialRating',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: isPerfectPotential ? FC.purple : fc.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isNearMax)
                Text(
                  'BASE $baseStat  •  ENH $enhancementRank/10',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: fc.amberBright,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Text(
                  'BASE $baseStat  •  ENH $enhancementRank/10',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: fc.textMuted,
                    fontSize: 10,
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
        AlchemonStatSystem.displayRating(instance.statSpeed) +
        AlchemonStatSystem.displayRating(instance.statIntelligence) +
        AlchemonStatSystem.displayRating(instance.statStrength) +
        AlchemonStatSystem.displayRating(instance.statBeauty);

    final potentials = {
      'Speed': instance.statSpeedPotential,
      'Intelligence': instance.statIntelligencePotential,
      'Strength': instance.statStrengthPotential,
      'Beauty': instance.statBeautyPotential,
    };

    final highestPotential = potentials.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );

    final isHighPotential = totalPotential >= 340.0;
    final isLegendaryPotential = totalPotential >= 380.0;

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
              Text('GENETIC POTENTIAL', style: ft.label),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Combined Power: $totalCurrent   •   Genetic Score: ${totalPotential.round()} / 400',
            style: ft.body.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'Best Gene: ${highestPotential.key} (${highestPotential.value.round()} / 100)',
            style: TextStyle(
              fontFamily: 'monospace',
              color: fc.amberBright,
              fontSize: 12,
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
        final repo = context.read<CreatureCatalog>();
        final species = repo.getCreatureById(instance.baseId);
        final base =
            species?.baseStats ??
            const SpeciesBaseStats(
              speed: 60,
              intelligence: 60,
              strength: 60,
              beauty: 60,
            );

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
                      Icon(AppIcons.info_outline, size: 12, color: fc.amber),
                      const SizedBox(width: 6),
                      Text('UNDERSTANDING POTENTIAL', style: ft.sectionTitle),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Base stats belong to the species. Potential is inherited genetic quality (1–100), Level trains every stat, and Orbs add permanent Enhancement to this individual.',
                    style: ft.body.copyWith(fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            StatPotentialBar(
              statName: 'Speed',
              currentValue: instance.statSpeed,
              potential: instance.statSpeedPotential,
              baseStat: base.speed,
              enhancementRank: instance.statSpeedEnhancement,
            ),
            const SizedBox(height: 8),
            StatPotentialBar(
              statName: 'Intelligence',
              currentValue: instance.statIntelligence,
              potential: instance.statIntelligencePotential,
              baseStat: base.intelligence,
              enhancementRank: instance.statIntelligenceEnhancement,
            ),
            const SizedBox(height: 8),
            StatPotentialBar(
              statName: 'Strength',
              currentValue: instance.statStrength,
              potential: instance.statStrengthPotential,
              baseStat: base.strength,
              enhancementRank: instance.statStrengthEnhancement,
            ),
            const SizedBox(height: 8),
            StatPotentialBar(
              statName: 'Beauty',
              currentValue: instance.statBeauty,
              potential: instance.statBeautyPotential,
              baseStat: base.beauty,
              enhancementRank: instance.statBeautyEnhancement,
            ),

            const SizedBox(height: 12),

            _PotentialSummary(instance: instance),
          ],
        );
      },
    );
  }
}
