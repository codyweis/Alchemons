// lib/widgets/constellation_bonus_display.dart
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/utils/faction_util.dart';

/// Displays active constellation bonuses in the feeding screen
class ConstellationBonusDisplay extends StatelessWidget {
  final ConstellationEffectsService effects;
  final FactionTheme theme;
  final int fodderCount;

  const ConstellationBonusDisplay({
    super.key,
    required this.effects,
    required this.theme,
    this.fodderCount = 1,
  });

  @override
  Widget build(BuildContext context) {
    final strengthBoost = effects.getStatBoostMultiplier('strength');
    final intBoost = effects.getStatBoostMultiplier('intelligence');
    final beautyBoost = effects.getStatBoostMultiplier('beauty');
    final speedBoost = effects.getStatBoostMultiplier('speed');
    final xpBoost = effects.getXpBoostMultiplier();

    final hasAnyStatBoost =
        strengthBoost > 0 || intBoost > 0 || beautyBoost > 0 || speedBoost > 0;
    final hasXpBoost = xpBoost > 1.0;
    final hasAnyBoost = hasAnyStatBoost || hasXpBoost;

    if (!hasAnyBoost) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primary.withOpacity(0.15),
            theme.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primary.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_awesome, color: theme.primary, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                'Constellation Bonuses',
                style: TextStyle(
                  color: theme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'ACTIVE',
                  style: TextStyle(
                    color: theme.primary,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          if (hasAnyStatBoost) ...[
            const SizedBox(height: 10),
            Text(
              'Stat Enhancement Bonuses',
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (strengthBoost > 0)
                  _buildBonusPill(
                    'STR',
                    strengthBoost,
                    fodderCount,
                    Icons.fitness_center,
                  ),
                if (intBoost > 0)
                  _buildBonusPill(
                    'INT',
                    intBoost,
                    fodderCount,
                    Icons.psychology,
                  ),
                if (beautyBoost > 0)
                  _buildBonusPill(
                    'BEA',
                    beautyBoost,
                    fodderCount,
                    Icons.auto_awesome,
                  ),
                if (speedBoost > 0)
                  _buildBonusPill('SPD', speedBoost, fodderCount, Icons.speed),
              ],
            ),
          ],
          if (hasXpBoost) ...[
            const SizedBox(height: 10),
            Text(
              'Experience Bonuses',
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            _buildXpBonusPill(xpBoost),
          ],
        ],
      ),
    );
  }

  Widget _buildBonusPill(
    String label,
    double bonusPerFodder,
    int count,
    IconData icon,
  ) {
    final totalBonus = bonusPerFodder * count;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.primary.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: theme.text,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '+${totalBonus.toStringAsFixed(3)}',
            style: TextStyle(
              color: theme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (count > 1) ...[
            const SizedBox(width: 3),
            Text(
              '×$count',
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildXpBonusPill(double multiplier) {
    final bonusPercent = ((multiplier - 1.0) * 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.primary.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_up, size: 12, color: theme.primary),
          const SizedBox(width: 4),
          Text(
            'XP Gain',
            style: TextStyle(
              color: theme.text,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '+$bonusPercent%',
            style: TextStyle(
              color: theme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact version for tooltip/inline display
class ConstellationBonusBadge extends StatelessWidget {
  final ConstellationEffectsService effects;
  final FactionTheme theme;
  final String? statName; // if null, shows general badge

  const ConstellationBonusBadge({
    super.key,
    required this.effects,
    required this.theme,
    this.statName,
  });

  @override
  Widget build(BuildContext context) {
    if (statName != null) {
      final boost = effects.getStatBoostMultiplier(statName!);
      if (boost <= 0) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: theme.primary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 8, color: theme.primary),
            const SizedBox(width: 2),
            Text(
              '+${(boost * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                color: theme.primary,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    // General badge
    return Tooltip(
      message: 'Constellation bonuses',
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.primary.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(color: theme.primary.withOpacity(0.4), width: 1),
        ),
      ),
    );
  }
}
