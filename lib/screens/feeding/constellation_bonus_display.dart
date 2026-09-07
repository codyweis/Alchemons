// lib/widgets/constellation_bonus_display.dart
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/app_icons.dart';

/// Displays active constellation bonuses around feeding and Enhancement.
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
    final strengthBonus = effects.getCombatStatBonusPercent('strength');
    final intBonus = effects.getCombatStatBonusPercent('intelligence');
    final beautyBonus = effects.getCombatStatBonusPercent('beauty');
    final speedBonus = effects.getCombatStatBonusPercent('speed');
    final xpBoost = effects.getXpBoostMultiplier();

    final hasAnyStatBoost =
        strengthBonus > 0 || intBonus > 0 || beautyBonus > 0 || speedBonus > 0;
    final hasXpBoost = xpBoost > 1.0;
    final hasAnyBoost = hasAnyStatBoost || hasXpBoost;

    if (!hasAnyBoost) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primary.withValues(alpha: 0.15),
            theme.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withValues(alpha: 0.1),
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
                  color: theme.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  AppIcons.auto_awesome,
                  color: theme.primary,
                  size: 16,
                ),
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
                  color: theme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'ACTIVE',
                  style: TextStyle(
                    color: theme.primary,
                    fontSize: 12,
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
              'Combat Stat Bonuses',
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (strengthBonus > 0)
                  _buildBonusPill(
                    'STR',
                    strengthBonus,
                    AppIcons.fitness_center,
                  ),
                if (intBonus > 0)
                  _buildBonusPill('INT', intBonus, AppIcons.psychology),
                if (beautyBonus > 0)
                  _buildBonusPill('BEA', beautyBonus, AppIcons.auto_awesome),
                if (speedBonus > 0)
                  _buildBonusPill('SPD', speedBonus, AppIcons.speed),
              ],
            ),
          ],
          if (hasXpBoost) ...[
            const SizedBox(height: 10),
            Text(
              'Experience Bonuses',
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 12,
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

  Widget _buildBonusPill(String label, int bonusPercent, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
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
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '+$bonusPercent%',
            style: TextStyle(
              color: theme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildXpBonusPill(double multiplier) {
    final bonusPercent = ((multiplier - 1.0) * 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.trending_up, size: 12, color: theme.primary),
          const SizedBox(width: 4),
          Text(
            'XP Gain',
            style: TextStyle(
              color: theme.text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '+$bonusPercent%',
            style: TextStyle(
              color: theme.primary,
              fontSize: 12,
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
      final bonus = effects.getCombatStatBonusPercent(statName!);
      if (bonus <= 0) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: theme.primary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.auto_awesome, size: 8, color: theme.primary),
            const SizedBox(width: 2),
            Text(
              '+$bonus%',
              style: TextStyle(
                color: theme.primary,
                fontSize: 12,
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
          color: theme.primary.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.primary.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      ),
    );
  }
}
