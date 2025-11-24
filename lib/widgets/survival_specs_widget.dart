import 'package:flutter/material.dart';
import 'package:alchemons/games/survival/survival_combat.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/utils/faction_util.dart';

class SurvivalSpecsWidget extends StatelessWidget {
  final FactionTheme theme;
  final Creature creature;
  final CreatureInstance instance;

  const SurvivalSpecsWidget({
    super.key,
    required this.theme,
    required this.creature,
    required this.instance,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Instantiate the Logic Class to get derived stats
    // This ensures the UI numbers match the Game Engine numbers exactly.
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

    // 2. Determine Role Label based on Range logic in SurvivalUnit
    final isRanged = unit.attackRange >= 300;
    final roleLabel = isRanged ? "Ranged Blaster" : "Melee Brawler";
    final roleIcon = isRanged ? Icons.gps_fixed : Icons.sports_mma;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Header / Role ---
        Row(
          children: [
            Icon(roleIcon, color: theme.primary, size: 16),
            const SizedBox(width: 8),
            Text(
              roleLabel.toUpperCase(),
              style: TextStyle(
                color: theme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            Text(
              "SURVIVAL STATS",
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // --- Primary Stats (HP / Def) ---
        Row(
          children: [
            Expanded(
              child: _StatBox(
                theme: theme,
                label: "MAX HP",
                value: unit.maxHp.toString(),
                subLabel: "Base + Str",
                icon: Icons.favorite,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatBox(
                theme: theme,
                label: "DEFENSES",
                value: "${unit.physDef} / ${unit.elemDef}",
                subLabel: "Phys / Elem",
                icon: Icons.shield,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // --- Offensive Stats ---
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.surfaceAlt.withOpacity(0.5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.border.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              _CompactRow(
                theme: theme,
                label: "Phys Atk",
                value: unit.physAtk.toString(),
                sourceStat: "Strength",
                isPrimary: unit.physAtk > unit.elemAtk,
              ),
              const SizedBox(height: 6),
              _CompactRow(
                theme: theme,
                label: "Elem Atk",
                value: unit.elemAtk.toString(),
                sourceStat: "Intelligence",
                isPrimary: unit.elemAtk >= unit.physAtk,
              ),
              const Divider(height: 12, color: Colors.white10),
              _CompactRow(
                theme: theme,
                label: "Crit Chance",
                value: "${(unit.critChance * 100).toInt()}%",
                sourceStat: "Beauty",
                highlight: true,
              ),
              const SizedBox(height: 6),
              _CompactRow(
                theme: theme,
                label: "Cooldowns",
                value: "-${((unit.cooldownReduction - 1.0) * 100).toInt()}%",
                sourceStat: "Speed",
                highlight: true,
              ),
              const SizedBox(height: 6),
              _CompactRow(
                theme: theme,
                label: "Range",
                value: unit.attackRange.toInt().toString(),
                sourceStat: isRanged ? "Int + Beauty" : "Str + Beauty",
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final FactionTheme theme;
  final String label;
  final String value;
  final String subLabel;
  final IconData icon;

  const _StatBox({
    required this.theme,
    required this.label,
    required this.value,
    required this.subLabel,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: theme.textMuted),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: theme.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            subLabel,
            style: TextStyle(
              color: theme.primary.withOpacity(0.7),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactRow extends StatelessWidget {
  final FactionTheme theme;
  final String label;
  final String value;
  final String sourceStat;
  final bool isPrimary;
  final bool highlight;

  const _CompactRow({
    required this.theme,
    required this.label,
    required this.value,
    required this.sourceStat,
    this.isPrimary = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: highlight ? theme.secondary : theme.text,
              fontSize: 11,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: highlight ? theme.secondary : theme.text,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (isPrimary) ...[
          const SizedBox(width: 6),
          Icon(Icons.star, size: 10, color: theme.primary),
        ],
        const Spacer(),
        Text(
          sourceStat,
          style: TextStyle(
            color: theme.textMuted,
            fontSize: 10,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
