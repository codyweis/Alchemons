// ============================================================================
// STAT POTENTIAL SECTION — Scorched Forge style
// ============================================================================

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/widgets/app_icons.dart';

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
    final isDark = context.read<FactionTheme>().isDark;
    final currentPercent = (currentValue / 5.0).clamp(0.0, 1.0);
    final potentialPercent = (potential / 5.0).clamp(0.0, 1.0);
    final roomForGrowth = potential - currentValue;
    final isNearMax = roomForGrowth < 0.3;
    final isPerfectPotential = potential >= 4.8;
    final trackColor = isDark ? fc.bg3 : fc.bg0.withValues(alpha: 0.06);
    final trackBorderColor = isDark ? fc.borderDim : fc.borderMid;
    final potentialZoneColor = isPerfectPotential
        ? FC.purple.withValues(alpha: isDark ? 0.18 : 0.14)
        : fc.amberBright.withValues(alpha: isDark ? 0.10 : 0.18);
    final currentFill = [
      fc.amberGlow,
      isDark ? fc.amber.withValues(alpha: 0.72) : fc.amber,
    ];
    final markerColor = isPerfectPotential
        ? FC.purple.withValues(alpha: isDark ? 0.85 : 0.70)
        : fc.amberBright.withValues(alpha: isDark ? 0.90 : 0.75);

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
              final markerLeft = (availableWidth * potentialPercent - 1).clamp(
                0.0,
                (availableWidth - 2).clamp(0.0, double.infinity),
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(1),
                      child: Row(
                        children: [
                          Container(
                            width: fillWidth * potentialPercent,
                            color: potentialZoneColor,
                          ),
                        ],
                      ),
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
                              width: fillWidth * currentPercent,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: currentFill),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (potentialPercent > 0 && potentialPercent < 1)
                    Positioned(
                      left: markerLeft,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 2,
                        decoration: BoxDecoration(
                          color: markerColor,
                          borderRadius: BorderRadius.circular(1),
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
                      currentValue.toStringAsFixed(1),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: fc.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      ' / ${potential.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: fc.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isNearMax)
                Text(
                  'Near Max',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: fc.amberBright,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Text(
                  '+${roomForGrowth.toStringAsFixed(1)}',
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
            'Total: ${totalCurrent.toStringAsFixed(1)} / ${totalPotential.toStringAsFixed(1)}',
            style: ft.body.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'Best Gene: ${highestPotential.key} (${highestPotential.value.toStringAsFixed(1)})',
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
                    'Each creature has a genetic potential cap for every stat. Feeding can increase stats up to their potential, but never beyond. Breed creatures with high potential to create powerful offspring!',
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
