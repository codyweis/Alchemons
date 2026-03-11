import 'package:flutter/material.dart';
import 'package:alchemons/games/survival/survival_combat.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';

class SurvivalSpecsWidget extends StatelessWidget {
  // ignore: unused_field
  final FactionTheme? theme;
  final Creature creature;
  final CreatureInstance instance;

  const SurvivalSpecsWidget({
    super.key,
    this.theme,
    required this.creature,
    required this.instance,
  });

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final unit = SurvivalUnit(
      id: 'preview',
      name: creature.name,
      types: creature.types,
      family: creature.mutationFamily ?? 'Unknown',
      level: instance.level,
      statSpeed: instance.statSpeed,
      statIntelligence: instance.statIntelligence,
      statStrength: instance.statStrength,
      statBeauty: instance.statBeauty,
    );

    final isRanged = unit.attackRange >= 300;
    final roleLabel = isRanged ? 'RANGED BLASTER' : 'MELEE BRAWLER';
    final roleIcon = isRanged ? Icons.gps_fixed : Icons.sports_mma;
    final roleColor = isRanged ? fc.teal : fc.amber;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Role header ---
        Row(
          children: [
            Icon(roleIcon, color: roleColor, size: 14),
            const SizedBox(width: 6),
            Text(
              roleLabel,
              style: TextStyle(
                fontFamily: 'monospace',
                color: roleColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            const Spacer(),
            Text(
              'SURVIVAL METRICS',
              style: TextStyle(
                fontFamily: 'monospace',
                color: fc.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // --- HP / Defence boxes ---
        Row(
          children: [
            Expanded(
              child: _ForgeStatBox(
                label: 'MAX HP',
                value: unit.maxHp.toString(),
                subLabel: 'Base + Str',
                icon: Icons.favorite,
                accentColor: fc.danger,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ForgeStatBox(
                label: 'DEFENSES',
                value: '${unit.physDef} / ${unit.elemDef}',
                subLabel: 'Phys / Elem',
                icon: Icons.shield,
                accentColor: FC.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // --- Offensive stats block ---
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: fc.bg3,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: fc.borderDim),
          ),
          child: Column(
            children: [
              _ForgeCompactRow(
                label: 'Phys Atk',
                value: unit.physAtk.toString(),
                sourceStat: 'Strength',
                isPrimary: unit.physAtk > unit.elemAtk,
              ),
              const SizedBox(height: 6),
              _ForgeCompactRow(
                label: 'Elem Atk',
                value: unit.elemAtk.toString(),
                sourceStat: 'Intelligence',
                isPrimary: unit.elemAtk >= unit.physAtk,
              ),
              Divider(height: 12, color: fc.borderDim),
              _ForgeCompactRow(
                label: 'Crit Chance',
                value: '${(unit.critChance * 100).toInt()}%',
                sourceStat: 'Beauty',
                highlight: true,
              ),
              const SizedBox(height: 6),
              _ForgeCompactRow(
                label: 'Cooldowns',
                value: '-${((unit.cooldownReduction - 1.0) * 100).toInt()}%',
                sourceStat: 'Speed',
                highlight: true,
              ),
              const SizedBox(height: 6),
              _ForgeCompactRow(
                label: 'Range',
                value: unit.attackRange.toInt().toString(),
                sourceStat: isRanged ? 'Int + Beauty' : 'Str + Beauty',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ForgeStatBox extends StatelessWidget {
  final String label;
  final String value;
  final String subLabel;
  final IconData icon;
  final Color accentColor;

  const _ForgeStatBox({
    required this.label,
    required this.value,
    required this.subLabel,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: fc.bg3,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 11, color: accentColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: fc.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              color: fc.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            subLabel,
            style: TextStyle(
              fontFamily: 'monospace',
              color: accentColor.withValues(alpha: 0.7),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _ForgeCompactRow extends StatelessWidget {
  final String label;
  final String value;
  final String sourceStat;
  final bool isPrimary;
  final bool highlight;

  const _ForgeCompactRow({
    required this.label,
    required this.value,
    required this.sourceStat,
    this.isPrimary = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final textColor = highlight ? fc.amberBright : fc.textPrimary;
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              color: highlight ? fc.amberBright : fc.textSecondary,
              fontSize: 11,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'monospace',
            color: textColor,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (isPrimary) ...[
          const SizedBox(width: 5),
          Icon(Icons.star, size: 9, color: fc.amber),
        ],
        const Spacer(),
        Text(
          sourceStat,
          style: TextStyle(
            fontFamily: 'monospace',
            color: fc.textMuted,
            fontSize: 10,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
