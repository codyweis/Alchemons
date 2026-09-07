// ============================================================================
// STAT POTENTIAL SECTION — Scorched Forge style
// ============================================================================

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/services/creature_repository.dart';

/// One stat, read as two lines rather than a bar plus a cramped column.
///
/// The old right-hand block was 92px wide holding "BASE 70 • ENH 0/10", so it
/// wrapped and left the separator dangling at the end of a line. Splitting the
/// row gives every number its own column, and the track now shows Enhancement
/// ranks — the one quantity the numbers cannot express as progress — instead
/// of restating the Potential figure printed beside it.
class StatPotentialBar extends StatelessWidget {
  // ignore: unused_field
  final FactionTheme? theme;
  final String statName;
  final double currentValue;
  final double potential;
  final int baseStat;
  final int enhancementRank;
  final Color accent;

  const StatPotentialBar({
    super.key,
    this.theme,
    required this.statName,
    required this.currentValue,
    required this.potential,
    required this.baseStat,
    required this.enhancementRank,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final ft = FT(fc);
    final currentRating = AlchemonStatSystem.displayRating(currentValue);
    final potentialRating = AlchemonStatSystem.normalizePotential(potential);
    final isPerfectPotential = potentialRating >= 95;
    const maxRank = AlchemonStatSystem.maxEnhancementRank;
    final enhanceMaxed = enhancementRank >= maxRank;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
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
            const SizedBox(width: 8),
            Text(
              '$currentRating',
              style: TextStyle(
                fontFamily: 'monospace',
                color: accent,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(
              width: 54,
              child: Text(
                'P$potentialRating',
                textAlign: TextAlign.right,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: isPerfectPotential ? FC.purple : fc.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            SizedBox(
              width: 62,
              child: Text(
                'BASE $baseStat',
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: fc.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  for (var i = 0; i < maxRank; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: i < enhancementRank
                              ? (enhanceMaxed ? fc.amberBright : accent)
                              : fc.bg3,
                          borderRadius: BorderRadius.circular(1.5),
                          border: Border.all(
                            color: i < enhancementRank
                                ? Colors.transparent
                                : fc.borderDim,
                            width: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 66,
              child: Text(
                enhanceMaxed ? 'ENH MAX' : 'ENH $enhancementRank/$maxRank',
                textAlign: TextAlign.right,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: enhanceMaxed
                      ? fc.amberBright
                      : enhancementRank > 0
                      ? accent
                      : fc.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
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
            StatPotentialBar(
              statName: 'Speed',
              accent: const Color(0xFF60A5FA),
              currentValue: instance.statSpeed,
              potential: instance.statSpeedPotential,
              baseStat: base.speed,
              enhancementRank: instance.statSpeedEnhancement,
            ),
            const SizedBox(height: 14),
            StatPotentialBar(
              statName: 'Intelligence',
              accent: const Color(0xFFC084FC),
              currentValue: instance.statIntelligence,
              potential: instance.statIntelligencePotential,
              baseStat: base.intelligence,
              enhancementRank: instance.statIntelligenceEnhancement,
            ),
            const SizedBox(height: 14),
            StatPotentialBar(
              statName: 'Strength',
              accent: const Color(0xFFF87171),
              currentValue: instance.statStrength,
              potential: instance.statStrengthPotential,
              baseStat: base.strength,
              enhancementRank: instance.statStrengthEnhancement,
            ),
            const SizedBox(height: 14),
            StatPotentialBar(
              statName: 'Beauty',
              accent: const Color(0xFFF9A8D4),
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
