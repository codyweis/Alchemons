import 'package:alchemons/models/family_combat_copy.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/purity_stat_bonus.dart';
import 'package:alchemons/services/onboarding_tasks.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/utils/instance_purity_util.dart';

class ImprovedBattleScrollArea extends StatefulWidget {
  final FactionTheme? theme;
  final Creature creature;
  final CreatureInstance instance;

  const ImprovedBattleScrollArea({
    super.key,
    this.theme,
    required this.creature,
    required this.instance,
  });

  @override
  State<ImprovedBattleScrollArea> createState() =>
      _ImprovedBattleScrollAreaState();
}

class _ImprovedBattleScrollAreaState extends State<ImprovedBattleScrollArea> {
  @override
  void initState() {
    super.initState();
    // Arriving earns the task; collecting it happens in the journal.
    OnboardingTaskService.recordArrival(context, 'battle_tab');
  }

  @override
  Widget build(BuildContext context) {
    final family = widget.creature.mutationFamily ?? 'Unknown';

    return _ExploreTab(
      instance: widget.instance,
      creature: widget.creature,
      family: family,
      types: widget.creature.types,
    );
  }
}

class _ExploreTab extends StatelessWidget {
  const _ExploreTab({
    required this.instance,
    required this.creature,
    required this.family,
    required this.types,
  });

  final CreatureInstance instance;
  final Creature creature;
  final String family;
  final List<String> types;

  @override
  Widget build(BuildContext context) {
    final element = types.firstOrNull ?? 'Normal';
    final role = _cosmicFamilyRole(family);
    final basic = _cosmicFamilyBasicInfo(family, element);
    final special = cosmicFamilySpecialInfo(family, element);
    final specialName = cosmicSpecialAbilityName(family, element);
    final hasActiveSpecial =
        !special.subtitle.toLowerCase().contains('passive') &&
        !special.description.toLowerCase().contains('no active');

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BracketSectionDivider(label: 'Stats'),
          const SizedBox(height: 10),
          _ExploreStatGrid(instance: instance, family: family),
          const SizedBox(height: 18),
          const BracketSectionDivider(label: 'Auto Attack'),
          const SizedBox(height: 10),
          _BracketInfoCard(
            title: basic.name,
            subtitle: 'Automatic • Repeats while a target is in range',
            description:
                '${basic.description}\n\nStrength increases damage. Speed makes it repeat sooner.',
            icon: basic.icon,
          ),
          const SizedBox(height: 18),
          const BracketSectionDivider(label: 'Special Ability'),
          const SizedBox(height: 10),
          _BracketInfoCard(
            title: specialName,
            subtitle: hasActiveSpecial
                ? '${special.subtitle} • Activates when ready'
                : special.subtitle,
            description:
                '${special.description}\n\n${_familySpecialScalingCopy(family)}',
            icon: special.icon,
            accent: _elementAccentColor(element),
            featured: true,
          ),
          const SizedBox(height: 18),
          const BracketSectionDivider(label: 'Role'),
          const SizedBox(height: 10),
          _BracketInfoCard(title: role.title, description: role.description),
          const SizedBox(height: 18),
          const BracketSectionDivider(label: 'Boosts'),
          const SizedBox(height: 10),
          _CombatBoostsCard(
            instance: instance,
            creature: creature,
            family: family,
          ),
        ],
      ),
    );
  }
}

String _familySpecialScalingCopy(String family) => switch (family
    .toLowerCase()) {
  'horn' =>
    'Power: mostly Strength, with Intelligence. Intelligence also improves control and duration; Beauty expands coverage.',
  'wing' =>
    'Power: mostly Beauty, with Intelligence. Beauty widens the beam; Intelligence improves reach, duration, and control.',
  'let' =>
    'Power: mostly Strength, with Beauty. Beauty enlarges the impact; Intelligence improves aim, duration, and aftermath.',
  'pip' =>
    'Power: Strength and Beauty. Intelligence improves guidance, ricochets, and duration.',
  'mane' =>
    'Power: mostly Strength, with Intelligence. Beauty adds projectiles or makes the attack wider; Intelligence improves control and duration.',
  'mask' =>
    'Power: mostly Beauty, with Intelligence. Beauty enlarges and strengthens traps; Intelligence improves duration and control.',
  'kin' =>
    'Power: mostly Beauty, with some Strength and Intelligence. Beauty improves healing and potency; Intelligence improves duration and control.',
  'mystic' =>
    'Power: mostly Beauty, with Intelligence. Beauty expands world effects; Intelligence improves duration, control, and repeat effects.',
  _ =>
    'Beauty and Intelligence improve this special. Speed makes it ready sooner.',
};

// ──────────────────────────────────────────────────────────────────────────
// Bracket-style content cards (shared by Cosmic + Boss tabs)
// ──────────────────────────────────────────────────────────────────────────

class _BracketStatTile extends StatelessWidget {
  const _BracketStatTile({
    required this.label,
    required this.value,
    this.source,
  });

  final String label;
  final String value;

  /// The genetic stats this number is derived from, e.g. 'STR-INT'. Printed
  /// under the value so the tab answers "which stat do I enhance for this?"
  /// without turning into a formula dump.
  final String? source;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceFill(),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.line.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: bracketText(
                context,
                10.5,
                palette.muted,
                weight: FontWeight.w700,
                letterSpacing: 0.9,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: bracketText(
                context,
                15,
                palette.ink,
                weight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            if (source != null) ...[
              const SizedBox(height: 3),
              Text(
                source!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: bracketText(
                  context,
                  9,
                  palette.muted.withValues(alpha: 0.72),
                  weight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExploreStatGrid extends StatelessWidget {
  const _ExploreStatGrid({required this.instance, required this.family});

  final CreatureInstance instance;
  final String family;

  @override
  Widget build(BuildContext context) {
    final combatBonuses = context.watch<ConstellationEffectsService>();
    final strength = combatBonuses.applyCombatStatBonus(
      'strength',
      instance.statStrength,
    );
    final intelligence = combatBonuses.applyCombatStatBonus(
      'intelligence',
      instance.statIntelligence,
    );
    final beauty = combatBonuses.applyCombatStatBonus(
      'beauty',
      instance.statBeauty,
    );
    final speed = combatBonuses.applyCombatStatBonus(
      'speed',
      instance.statSpeed,
    );
    // The summoned companion is built with the family shape modifiers applied
    // (see summonCompanion); reporting the unmodified figures here understated
    // every Horn's HP by 30% and its defenses by 20%.
    final hpMultiplier = CosmicBalance.familyHpMultiplier(family);
    final defMultiplier = CosmicBalance.familyDefMultiplier(family);

    final hp =
        (CosmicBalance.companionMaxHp(
                  level: instance.level,
                  strength: strength,
                  intelligence: intelligence,
                ) *
                hpMultiplier)
            .round();
    final physAtk = CosmicBalance.companionPhysAtk(
      level: instance.level,
      strength: strength,
    );
    final elemAtk = CosmicBalance.companionElemAtk(
      level: instance.level,
      beauty: beauty,
    );
    final physDef =
        (CosmicBalance.companionPhysDef(
                  level: instance.level,
                  strength: strength,
                  intelligence: intelligence,
                ) *
                defMultiplier)
            .round();
    final elemDef =
        (CosmicBalance.companionElemDef(
                  level: instance.level,
                  beauty: beauty,
                  intelligence: intelligence,
                ) *
                defMultiplier)
            .round();
    final cdr = CosmicBalance.companionCooldownReduction(speed);
    final crit = CosmicBalance.companionCritChance(strength);
    final range = CosmicBalance.familyAttackRange(
      family,
      CosmicBalance.companionBaseRange(intelligence),
    );

    final stats = <_StatEntry>[
      _StatEntry('HP', hp.toString(), 'STR-INT'),
      _StatEntry('P-ATK', physAtk.toString(), 'STR'),
      _StatEntry('E-ATK', elemAtk.toString(), 'BEA'),
      _StatEntry('RANGE', range.round().toString(), 'INT'),
      _StatEntry('P-DEF', physDef.toString(), 'STR-INT'),
      _StatEntry('E-DEF', elemDef.toString(), 'BEA-INT'),
      // cdr divides the base cooldown, so printing it raw read backwards:
      // a '×0.89' specimen actually waits 13% longer between casts. Show the
      // cooldown length itself, where lower is plainly better.
      _StatEntry('CD', '×${(1 / cdr).toStringAsFixed(2)}', 'SPD'),
      _StatEntry('CRIT', '${(crit * 100).round()}%', 'STR'),
    ];

    return _StatGrid(stats: stats);
  }
}

class _StatEntry {
  const _StatEntry(this.label, this.value, this.source);
  final String label;
  final String value;
  final String source;
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});

  final List<_StatEntry> stats;
  static const columns = 4;

  @override
  Widget build(BuildContext context) {
    const spacing = 8.0;
    final rows = <Widget>[];
    for (var i = 0; i < stats.length; i += columns) {
      final rowItems = <Widget>[];
      for (var c = 0; c < columns; c++) {
        if (c > 0) rowItems.add(const SizedBox(width: spacing));
        final idx = i + c;
        if (idx < stats.length) {
          rowItems.add(
            Expanded(
              child: _BracketStatTile(
                label: stats[idx].label,
                value: stats[idx].value,
                source: stats[idx].source,
              ),
            ),
          );
        } else {
          rowItems.add(const Expanded(child: SizedBox.shrink()));
        }
      }
      if (rows.isNotEmpty) rows.add(const SizedBox(height: spacing));
      rows.add(Row(children: rowItems));
    }
    return Column(children: rows);
  }
}

/// Lists every persistent percentage modifier that feeds this creature's
/// battle readout, grouped by its player-facing source.
class _CombatBoostsCard extends StatelessWidget {
  const _CombatBoostsCard({
    required this.instance,
    required this.creature,
    required this.family,
  });

  final CreatureInstance instance;
  final Creature creature;
  final String family;

  static const _stats = <(String, String)>[
    ('Speed', kStatSpeed),
    ('Intelligence', kStatIntelligence),
    ('Strength', kStatStrength),
    ('Beauty', kStatBeauty),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    final theme = context.read<FactionTheme>();
    final accent = bracketReadableAccent(theme);
    final constellation = context.watch<ConstellationEffectsService>();
    final entries = <_BoostEntry>[];

    final natureIds = <String>{
      if (instance.natureId?.isNotEmpty == true) instance.natureId!,
      if (instance.natureId2?.isNotEmpty == true) instance.natureId2!,
    };
    if (natureIds.isEmpty) {
      entries.add(const _BoostEntry('Nature', 'No Nature boost'));
    } else {
      for (final id in natureIds) {
        final nature = NatureCatalog.byId(id);
        final parts = nature == null
            ? const <String>[]
            : _stats
                  .map((stat) {
                    final bonus = nature.effect.getDouble(
                      'stat_${stat.$2}_bonus',
                      fallback: 0,
                    );
                    return bonus == 0
                        ? null
                        : '${stat.$1} ${_signedPercent(bonus)}';
                  })
                  .whereType<String>()
                  .toList(growable: false);
        entries.add(
          _BoostEntry(
            'Nature · ${nature?.id ?? id}',
            parts.isEmpty ? 'No battle-stat modifier' : parts.join(' · '),
          ),
        );
      }
    }

    final enhancementParts = <String>[];
    final enhancementRanks = <int>[
      instance.statSpeedEnhancement,
      instance.statIntelligenceEnhancement,
      instance.statStrengthEnhancement,
      instance.statBeautyEnhancement,
    ];
    for (var i = 0; i < _stats.length; i++) {
      final rank = enhancementRanks[i];
      if (rank <= 0) continue;
      enhancementParts.add(
        '${_stats[i].$1} +${(rank * AlchemonStatSystem.enhancementBonusPerRank * 100).round()}%',
      );
    }
    entries.add(
      _BoostEntry(
        'Enhancement',
        enhancementParts.isEmpty
            ? 'No Enhancement boost'
            : enhancementParts.join(' · '),
      ),
    );

    final purity = classifyInstancePurity(instance, species: creature);
    final purityBonus = resolvePurityStatBonus(
      instanceId: instance.instanceId,
      isElementallyPure: purity.isElementallyPure,
      isSpeciesPure: purity.isSpeciesPure,
    );
    entries.add(
      _BoostEntry(
        'Purity · ${purityBonus.lineageLabel}',
        purityBonus.isNone || purityBonus.statKey == null
            ? 'No purity stat boost'
            : '${_statLabel(purityBonus.statKey!)} +${(purityBonus.bonus * 100).round()}%',
      ),
    );

    final constellationParts = <String>[];
    for (final stat in _stats) {
      final percent = constellation.getCombatStatBonusPercent(stat.$2);
      if (percent > 0) constellationParts.add('${stat.$1} +$percent%');
    }
    entries.add(
      _BoostEntry(
        'Combat Constellation',
        constellationParts.isEmpty
            ? 'No unlocked combat boost'
            : constellationParts.join(' · '),
      ),
    );

    final frameParts = <String>[];
    void addFramePart(String label, double multiplier) {
      final percent = ((multiplier - 1) * 100).round();
      if (percent == 0) return;
      frameParts.add('$label ${_signedPercent(percent / 100)}');
    }

    addFramePart('HP', CosmicBalance.familyHpMultiplier(family));
    addFramePart('Defense', CosmicBalance.familyDefMultiplier(family));
    addFramePart('Auto range', CosmicBalance.familyAttackRange(family, 1));
    addFramePart('Special range', CosmicBalance.familySpecialRange(family, 1));
    entries.add(
      _BoostEntry(
        'Family Frame · ${family.toUpperCase()}',
        frameParts.isEmpty ? 'No family modifier' : frameParts.join(' · '),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceFill(),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.line.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Column(
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              if (i > 0)
                Container(
                  height: 1,
                  color: palette.line.withValues(alpha: 0.28),
                ),
              _BoostRow(entry: entries[i], accent: accent),
            ],
          ],
        ),
      ),
    );
  }
}

class _BoostEntry {
  const _BoostEntry(this.source, this.value);

  final String source;
  final String value;
}

class _BoostRow extends StatelessWidget {
  const _BoostRow({required this.entry, required this.accent});

  final _BoostEntry entry;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            entry.source.toUpperCase(),
            style: bracketText(
              context,
              10.5,
              palette.muted,
              weight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            entry.value,
            style: bracketText(context, 12, accent, weight: FontWeight.w700),
            strutStyle: const StrutStyle(height: 1.35),
          ),
        ],
      ),
    );
  }
}

String _signedPercent(double value) {
  final percent = (value * 100).round();
  return '${percent >= 0 ? '+' : '−'}${percent.abs()}%';
}

String _statLabel(String key) => switch (key) {
  kStatSpeed => 'Speed',
  kStatIntelligence => 'Intelligence',
  kStatStrength => 'Strength',
  kStatBeauty => 'Beauty',
  _ => key,
};

class _BracketInfoCard extends StatelessWidget {
  const _BracketInfoCard({
    required this.title,
    this.subtitle,
    required this.description,
    this.icon,
    this.accent,
    this.featured = false,
  });

  final String title;
  final String? subtitle;
  final String description;
  final IconData? icon;
  final Color? accent;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    final theme = context.read<FactionTheme>();
    final activeAccent = bracketReadableAccent(theme, color: accent);

    // Bracket corners on a full-width card read as scaffolding rather than
    // structure; a plain edge does the same job without the ornament.
    return Container(
      decoration: BoxDecoration(
        color: featured
            ? Color.alphaBlend(
                activeAccent.withValues(alpha: palette.isDark ? 0.08 : 0.05),
                palette.surfaceFill(),
              )
            : palette.surfaceFill(),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: featured
              ? activeAccent.withValues(alpha: 0.5)
              : palette.line.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Container(
                    width: featured ? 32 : 26,
                    height: featured ? 32 : 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: activeAccent.withValues(
                        alpha: palette.isDark ? 0.16 : 0.12,
                      ),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: activeAccent.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: featured ? 17 : 15,
                      color: activeAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: bracketText(
                      context,
                      featured ? 17 : 16,
                      palette.ink,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: bracketText(
                  context,
                  12,
                  palette.muted,
                  weight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 10),
            _AbilityDescriptionText(
              description: description,
              accent: activeAccent,
              textColor: palette.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _AbilityDescriptionText extends StatelessWidget {
  const _AbilityDescriptionText({
    required this.description,
    required this.accent,
    required this.textColor,
  });

  final String description;
  final Color accent;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final lines = cosmicAbilityDescriptionLines(description);
    if (lines.length == 1 && lines.first.label.isEmpty) {
      return Text(
        lines.first.body,
        style: bracketText(context, 12.5, textColor, weight: FontWeight.w500),
        strutStyle: const StrutStyle(height: 1.45),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 54),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: accent.withValues(alpha: 0.5)),
                ),
                child: Text(
                  lines[i].label.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: bracketText(
                    context,
                    9.5,
                    accent,
                    weight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lines[i].body,
                  style: bracketText(
                    context,
                    12.5,
                    textColor,
                    weight: FontWeight.w500,
                  ),
                  strutStyle: const StrutStyle(height: 1.35),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

_CosmicFamilyRole _cosmicFamilyRole(String family) {
  final copy = FamilyCombatCopy.forName(family);
  return _CosmicFamilyRole(
    title: copy?.role ?? 'Companion',
    description: copy == null
        ? 'A loyal companion that fights alongside your ship.'
        : 'Targets: ${copy.targets} Position: ${copy.position}',
  );
}

/// Flat section header for the battle tab — no box, just accent bar + rule
class _CosmicFamilyRole {
  final String title;
  final String description;
  const _CosmicFamilyRole({required this.title, required this.description});
}

Color _elementAccentColor(String element) {
  switch (element) {
    case 'Fire':
    case 'Lava':
      return Colors.deepOrange;
    case 'Water':
    case 'Ice':
    case 'Steam':
      return Colors.blueAccent;
    case 'Earth':
    case 'Mud':
    case 'Crystal':
      return Colors.teal;
    case 'Air':
    case 'Dust':
    case 'Lightning':
      return Colors.cyan;
    case 'Plant':
    case 'Poison':
      return Colors.green;
    case 'Spirit':
    case 'Dark':
      return Colors.deepPurpleAccent;
    case 'Light':
      return const Color(0xFFF4B860);
    case 'Blood':
      return const Color(0xFFE05A5A);
    default:
      return const Color(0xFF9FB3C8);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COSMIC BASIC ATTACK INFO (per family)
// ─────────────────────────────────────────────────────────────────────────────
class _CosmicBasicInfo {
  final String name;
  final String description;
  final IconData icon;
  const _CosmicBasicInfo({
    required this.name,
    required this.description,
    required this.icon,
  });
}

_CosmicBasicInfo _cosmicFamilyBasicInfo(String family, String element) {
  switch (family) {
    case 'Mane':
      return _CosmicBasicInfo(
        name: "$element Twin Blades",
        description:
            "Throws two $element blades side by side. The damage is in landing both on the same enemy.",
        icon: AppIcons.waves,
      );
    case 'Horn':
      return _CosmicBasicInfo(
        name: "$element Ram Shot",
        description:
            "Fires one large, slow $element shot with a wide hitbox. Enemies can see it coming.",
        icon: AppIcons.shield,
      );
    case 'Mask':
      return _CosmicBasicInfo(
        name: "$element Needle",
        description:
            "Fires one quick $element dart that keeps going through every enemy in its path.",
        icon: AppIcons.warning_amber,
      );
    case 'Wing':
      return _CosmicBasicInfo(
        name: "$element Feather Pair",
        description:
            "Fires two quick $element shots, one right behind the other, from long range.",
        icon: AppIcons.arrow_forward,
      );
    case 'Kin':
      return _CosmicBasicInfo(
        name: "$element Charged Beam",
        description:
            "Charges in place, then fires a $element laser at its target.",
        icon: AppIcons.favorite,
      );
    case 'Mystic':
      return _CosmicBasicInfo(
        name: "$element Arcane Triad",
        description: "Fires three small $element bolts in a fan.",
        icon: AppIcons.auto_awesome,
      );
    case 'Pip':
      return _CosmicBasicInfo(
        name: "$element Dart Burst",
        description:
            "Fires three quick $element darts in a fan. Light hits, but Pips attack more often than anyone.",
        icon: AppIcons.bolt,
      );
    case 'Let':
      return _CosmicBasicInfo(
        name: "$element Meteor Stone",
        description:
            "Throws one big, slow $element rock that takes a moment to arrive.",
        icon: AppIcons.south,
      );
    default:
      return _CosmicBasicInfo(
        name: '$element Bolt',
        description:
            'Fires a $element projectile at the nearest enemy within range. '
            'Damage is based on Strength. Attack speed scales with Speed stat.',
        icon: AppIcons.gps_fixed,
      );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COSMIC SPECIAL ATTACK INFO (per element)
// ─────────────────────────────────────────────────────────────────────────────
class CosmicSpecialInfo {
  final String subtitle;
  final String description;
  final IconData icon;
  const CosmicSpecialInfo({
    required this.subtitle,
    required this.description,
    required this.icon,
  });
}

class CosmicAbilityDescriptionLine {
  const CosmicAbilityDescriptionLine({required this.label, required this.body});

  final String label;
  final String body;
}

List<CosmicAbilityDescriptionLine> cosmicAbilityDescriptionLines(
  String description,
) {
  const labels = [
    'Special ability',
    'Auto attack',
    'Either attack',
    'Special kills',
    'Auto hits',
    'Targets',
    'Position',
    'Base',
    'Auto',
    'Special',
    'Passive',
  ];
  final pattern = RegExp('(${labels.map(RegExp.escape).join('|')}):');
  final matches = pattern.allMatches(description).toList();
  if (matches.isEmpty) {
    return [CosmicAbilityDescriptionLine(label: '', body: description.trim())];
  }

  final lines = <CosmicAbilityDescriptionLine>[];
  for (var i = 0; i < matches.length; i++) {
    final match = matches[i];
    final nextStart = i + 1 < matches.length
        ? matches[i + 1].start
        : description.length;
    final body = description.substring(match.end, nextStart).trim();
    if (body.isEmpty) continue;
    lines.add(CosmicAbilityDescriptionLine(label: match.group(1)!, body: body));
  }
  return lines.isEmpty
      ? [CosmicAbilityDescriptionLine(label: '', body: description.trim())]
      : lines;
}

CosmicSpecialInfo cosmicFamilySpecialInfo(String family, String element) {
  switch (family) {
    case 'Horn':
      // Per-element shape varies under the new "bulky defense tank"
      // theme — some elements charge, some wind up before dashing,
      // some are pure passives, Light is a stationary channel.
      final isPassive = ['Air', 'Mud'].contains(element);
      final hasWindUp = ['Dark', 'Crystal', 'Spirit'].contains(element);
      final isChannel = element == 'Light';
      final isCustomPath = ['Water', 'Ice'].contains(element);
      final description = switch (element) {
        'Fire' =>
          'Charges through enemies, leaving a burning trail that damages and taunts enemies.',
        'Lava' =>
          'Slow heavy charge with a glowing build-up telegraph. Enemies killed by the slam explode into homing flames that seek nearby targets.',
        'Lightning' =>
          'Quick dash to the target, then a 3-second storm brews around the horn (movement locked). Damage taken during the dash + brew is absorbed, then released as a chain shockwave whose size scales with the absorbed total.',
        'Water' =>
          'Charges in a circular sweep around the cast point, then drops a whirlpool at the center that pulls and slows trapped enemies.',
        'Ice' =>
          'Dashes sideways perpendicular to the enemy direction, painting an ice wall segment-by-segment along the path. Wall taunts, slows, and reflects enemy projectiles.',
        'Steam' =>
          'Slams down a steam geyser. A kill resets the special cooldown and creates another geyser at the kill site.',
        'Earth' =>
          'Impact leaves a high-HP substitute clone that taunts enemies and pulses periodic mini-earthquakes around it.',
        'Mud' =>
          'Passive: No active cast. Drops slowing mud sludge wherever the horn walks. Trail rate scales with intelligence. Disabled while magnet-recalled to the ship.',
        'Dust' =>
          'Impact creates a dust cyclone that pulls nearby enemies inward and disorients shooter-enemies (they fire at each other).',
        'Crystal' =>
          'Wind-up gathers six crystal shards orbiting the horn, then dashes. Shards keep orbiting the moving horn, intercept enemy projectiles, and shatter into shrapnel when they expire.',
        'Air' =>
          'Passive: No active cast. Enemies near the horn are continuously blown back toward the arena edge. An inner dead zone leaves close targets in auto-attack range; the outer aura pushes everything else away.',
        'Plant' =>
          'Charges through enemies. Each surviving enemy hit gets a personal root status — immobilized for a few seconds and wrapped in vines.',
        'Poison' =>
          'Special ability: Charges through enemies and applies a heavy poison effect. Passive: An always-on toxic aura damages nearby enemies.',
        'Spirit' =>
          'Two-second wind-up where phantoms swarm the horn (60% damage reduction throughout wind-up + dash). On dash, six mobile phantom wisps release in a ring, drifting outward and taunting enemies.',
        'Dark' =>
          'Five-second void-suck wind-up drags nearby enemies toward the horn. Then a long fast dash carries the captured cluster to the map edge, teleporting them with the horn and slamming them for impact damage on arrival.',
        'Light' =>
          'Stops moving and channels a light barrier for about 5 seconds. It reflects projectiles, repels enemies, and reduces damage to allies inside by 70%.',
        'Blood' =>
          'Sacrifices a chunk of current HP to amplify the impact damage. Every kill during a short post-cast window heals the horn back.',
        _ => 'Element decides the cast pattern and effect.',
      };
      final subtitle = isPassive
          ? 'Passive Aura • Constant battlefield pressure'
          : isChannel
          ? 'Channeled Barrier • Stationary defense zone'
          : hasWindUp
          ? 'Wind-up + Dash • Telegraphed heavy impact'
          : isCustomPath
          ? 'Path Dash • Custom-route slam'
          : 'Heavy Charge • Bulky frontline impact';
      return CosmicSpecialInfo(
        subtitle: subtitle,
        description: description,
        icon: AppIcons.shield,
      );
    case 'Wing':
      final description = switch (element) {
        'Fire' =>
          'Sweeps the beam in a circle around the map perimeter, hitting everything in the ring for big damage.',
        'Lava' =>
          'The beam carves a glowing scar across the ground — enemies passing through the scar take burn damage over time.',
        'Lightning' =>
          'Charges briefly, then unleashes a sustained high-damage beam down the lane.',
        'Water' =>
          'Beam locks onto the lowest-HP ally or the ship and heals them; enemies along the beam path still take damage.',
        'Ice' =>
          'Beam contact builds frost on the target — held on long enough, the enemy snaps into a hard freeze.',
        'Steam' =>
          'Executes the first enemy touched, then creates 5–10 lingering steam clouds that damage enemies over time.',
        'Earth' =>
          'Standard piercing beam — the orb also fires a mirror beam alongside the wing, doubling the coverage.',
        'Mud' => 'Slows every enemy the beam touches for 60 seconds.',
        'Dust' =>
          'Beam contact surrounds the enemy with disorienting dust — shooter-enemies start firing at each other instead of the ship.',
        'Air' =>
          'Beam contact knocks enemies back hard, holding them off the line.',
        'Crystal' =>
          'Converts part of the beam damage into healing for the orb.',
        'Plant' =>
          'Enemies killed by the beam turn into flower pickups. Fly the ship near a flower to collect it; each one stacks +4% beam damage (cap +200%).',
        'Poison' =>
          'Fires a poison-ring beam around the map perimeter instead of a straight line, contaminating the outer ring.',
        'Spirit' =>
          'Beam tethers through the ship — the ship then fires its own laser at the nearest enemies.',
        'Dark' =>
          'Passive: Dark wing pulses its beam and auto-attacks at twice the normal rate. No active cast.',
        'Light' =>
          'If the beam kills an enemy, it refracts into two smaller beams hunting nearby enemies for the rest of the original beam\'s duration.',
        'Blood' =>
          'Beam locks onto the lowest-HP enemy and executes any enemy below ~18% HP outright.',
        _ => 'The element changes the beam\'s target and effect.',
      };
      final subtitle = element == 'Dark'
          ? 'Dark Beam • Doubled-tempo passive'
          : element == 'Fire' || element == 'Poison'
          ? 'Ring Beam • Perimeter sweep'
          : element == 'Spirit'
          ? 'Tether Beam • Ship relay'
          : element == 'Water'
          ? 'Heal Beam • Ally targeting'
          : element == 'Blood'
          ? 'Execute Beam • Lowest-HP lock'
          : element == 'Lightning'
          ? 'Charged Beam • Telegraphed blast'
          : 'Piercing Beam • Long-range line';
      return CosmicSpecialInfo(
        subtitle: subtitle,
        description: description,
        icon: AppIcons.arrow_forward,
      );
    case 'Let':
      final description = switch (element) {
        'Air' =>
          'If the meteor kills an enemy on impact, blow back every nearby enemy from the impact point.',
        'Dust' =>
          'On collision, drops a dust cloud at the impact site that slows enemies caught inside.',
        'Lava' =>
          'On impact, sears the ground and damages enemies inside the burning area over time.',
        'Poison' =>
          'On collision, poisons the struck enemy and leaves a toxic pool that poisons others nearby.',
        'Plant' =>
          'If the meteor kills an enemy, vines grow from the ground that persist and damage enemies who walk through them.',
        'Blood' =>
          'If the meteor kills an enemy, drains HP from nearby enemies and splits the drained HP as healing to every alchemon and the ship.',
        'Earth' =>
          'On impact, converts part of the damage dealt into healing for the lowest-health Alchemon or the ship.',
        'Light' =>
          'If the meteor kills an enemy, creates a pool of light that heals nearby allies and the ship.',
        'Spirit' =>
          'Has a 20% chance to defeat its target instantly. The chance increases with stats.',
        'Crystal' =>
          'Half the cooldown of the other lets, weaker damage, but any enemy hit is slowed by 90% on impact.',
        'Fire' =>
          'If the meteor kills an enemy, detonates a big explosion that damages every enemy nearby.',
        'Lightning' =>
          'On impact, if there are enemies nearby, chain-lightning arcs jump between them for splash damage.',
        'Steam' =>
          'If the meteor kills an enemy, creates a long-lasting geyser that pushes enemies upward.',
        'Dark' =>
          'If the meteor kills an enemy, immediately launches up to 5 follow-up meteors (twice as big) at surrounding enemies.',
        'Ice' => 'On collision, freezes the struck enemy for a short window.',
        'Mud' =>
          'If the meteor kills an enemy, creates a mud pool that stuns enemies caught inside.',
        'Water' =>
          'On impact, deals a large burst of area damage to nearby enemies.',
        _ => 'Element changes the meteor impact behavior.',
      };
      return CosmicSpecialInfo(
        subtitle: 'Meteor Strike • Impact-triggered siege',
        description: description,
        icon: AppIcons.south,
      );
    case 'Pip':
      final followThrough = switch (element) {
        'Fire' =>
          'Either attack: Kills create a fire pool that burns enemies inside it.',
        'Lightning' => 'Doubles the amount of ricochets.',
        'Air' => 'Ricochet darts push enemies back on hit.',
        'Dust' =>
          'Either attack: Kills create a dust cloud that slows enemies inside it.',
        'Crystal' =>
          'Either attack: Kills create a taunting crystal. Special darts also pierce and ricochet.',
        'Light' => 'Darts can intercept threats. Enemies killed heal the orb.',
        'Water' =>
          'Either attack: Kills splash nearby enemies. The special\'s final ricochet creates a larger splash.',
        'Ice' => 'Darts freeze and slow enemies they hit.',
        'Mud' =>
          'Auto attack: Hits permanently mark enemies, causing them to leave slowing mud trails. Special ability: Darts slow on hit.',
        'Plant' => 'Either attack: Kills grant 50% extra alchemy meter.',
        'Poison' =>
          'Auto attack: Hits draw poison lines between enemies. Special ability: Darts poison and slow enemies.',
        'Earth' =>
          'Auto attack: Hits reduce the special cooldown. Special ability: Kills refund extra cooldown.',
        'Lava' => 'Darts pierce and burn enemies they hit.',
        'Dark' =>
          'Passive: Auto-attack kills create a black hole that pulls enemies inward.',
        'Blood' => 'Enemies killed heal this Pip itself.',
        'Spirit' =>
          'Either attack: Kills build Spirit stacks. Enough stacks grant a temporary auto-attack speed boost.',
        'Steam' =>
          'Passive: A steam cloud temporarily increases auto-attack speed. Special ability: Kills can trigger extra haste.',
        _ => 'Element changes the dart effect.',
      };
      if (element == 'Dark') {
        return CosmicSpecialInfo(
          subtitle: 'No active special • Auto-kill passive',
          description:
              'Passive: This Pip has no active special. Auto-attack kills create a black hole that pulls enemies inward.',
          icon: AppIcons.bolt,
        );
      }
      return CosmicSpecialInfo(
        subtitle: 'Ricochet Salvo • Active special',
        description:
            'Special ability: Fires a short-lived elemental dart salvo; ricochet elements hop between nearby enemies. '
            '$followThrough',
        icon: AppIcons.bolt,
      );
    case 'Mane':
      final maneInfo = switch (element) {
        'Air' => (
          'Gale Pierce • Fast push-through catapult',
          'Projectile travels at 2× speed and shoves every enemy it pierces along the shot path.',
          AppIcons.air,
        ),
        'Dust' => (
          'Dustwake Fan • Projectile silence',
          'Leaves a dust-cloud trail along its path. Enemies inside the trail can no longer shoot projectiles.',
          AppIcons.cloud,
        ),
        'Lava' => (
          'Molten Cleave • Burning residue',
          'Drops lava at each enemy hit, damaging anything that steps into it over time.',
          AppIcons.local_fire_department,
        ),
        'Poison' => (
          'Venom Edge • Stacking toxin',
          'Each hit adds another poison stack, increasing its damage over time.',
          AppIcons.biotech,
        ),
        'Blood' => (
          'Bloodedge Rush • Orb lifesteal',
          'Every enemy pierced restores HP back to the orb.',
          AppIcons.bloodtype,
        ),
        'Earth' => (
          'Fault Slab • Grinding quake path',
          'Starts huge, slowly grinds forward, breaks apart as it travels, and shoots quake-bursts out as it breaks down.',
          AppIcons.terrain,
        ),
        'Light' => (
          'Radiant Ward • Orbiting rings',
          'Casts hang light in orbit instead of throwing it. The first three set an outer, middle and inner ring turning around you; every cast after that feeds one of them in that order, up to ten times, until each is half again the size of an Earth catapult.',
          AppIcons.wb_sunny,
        ),
        'Spirit' => (
          'Phaseblade Rush • Ramping stream',
          'Starts at 1 projectile. Each cast adds another shot up to 10, then resets back to 1.',
          AppIcons.auto_awesome,
        ),
        'Crystal' => (
          'Prism Edge • Boss shatter',
          'Hitting a boss triggers a massive crystal burst that defeats the boss and damages everything nearby.',
          AppIcons.diamond,
        ),
        'Fire' => (
          'Fireball Rush • Dense fire spread',
          'Throws 3–8 fast fireballs in a forward wave.',
          AppIcons.whatshot,
        ),
        'Lightning' => (
          'Storm Orb Field • Remote zaps',
          'Places 5–10 stationary lightning orbs on the map that shock enemies who come near.',
          AppIcons.flash_on,
        ),
        'Steam' => (
          'Pressure Geyser • Traveling vent',
          'Big geyser projectile travels through the lane and periodically releases steam pulses as it goes.',
          AppIcons.blur_on,
        ),
        'Dark' => (
          'Voidcut Drive • Pull and consume',
          'One slow void bolt that constantly pulls nearby enemies toward it as it travels, executing any low-HP enemy caught in its path.',
          AppIcons.dark_mode,
        ),
        'Ice' => (
          'Frostguard Cleave • Contact freeze',
          'Freezes everything it touches as it travels through the lane.',
          AppIcons.ac_unit,
        ),
        'Mud' => (
          'Bogbreaker Split • Ten-way burst',
          'First enemy hit, the projectile breaks apart and splits into 10 smaller mud shards firing outward.',
          AppIcons.grain,
        ),
        'Plant' => (
          'Vine Lariat • Feeding growth',
          'Throws a thin vine that roots enemies and grows wider and stronger with every hit. Defeated rooted enemies burst, damaging nearby targets.',
          AppIcons.local_florist,
        ),
        'Water' => (
          'Tidewall Crash • Carrying wave',
          'Fires a massive wall of water that drags enemies along with it as it travels.',
          AppIcons.water,
        ),
        _ => (
          'Barrage Volley • Piercing technique',
          'Element changes the piercing technique.',
          AppIcons.waves,
        ),
      };
      return CosmicSpecialInfo(
        subtitle: maneInfo.$1,
        description: maneInfo.$2,
        icon: maneInfo.$3,
      );
    case 'Mask':
      final description = switch (element) {
        'Air' =>
          'Scatters air pads across the field. Each pad blows back enemies that touch it.',
        'Dust' =>
          'Wraps each alchemon in a dust shield that follows them around — absorbs incoming projectiles and damages enemies who collide.',
        'Lava' => 'Drops lava pools that burn any enemy standing in them.',
        'Poison' =>
          'Scatters poison clouds. Enemies inside take damage over time.',
        'Plant' =>
          'Plants a single vine that never dies. Each cast feeds it — the vine grows larger and meaner, sprouting a new attacking tendril every 10 feeds (up to 10 tendrils at 100 feeds).',
        'Blood' =>
          'Places a blood blob. Enemies that pass through it are permanently drained — life leaches to all alchemons until that enemy dies.',
        'Earth' =>
          'Creates earth pools that heal the ship and alchemons standing inside.',
        'Light' =>
          'Plants a light void. Persists until an enemy touches it — that enemy is instantly killed.',
        'Spirit' =>
          'Scatters spirit wisps for the ship to collect. Every 6 collected wipe all non-boss enemies on the field.',
        'Crystal' =>
          'Throws large crystals. On contact each shatters into 3 smaller crystals that deal damage.',
        'Fire' =>
          'Throws fire balls. When a ball strikes an enemy it leaves a burning pool behind.',
        'Lightning' =>
          'Plants a lightning field. Each enemy it hits expands the field; damage ticks while enemies are inside.',
        'Steam' =>
          'Scatters mini geysers around the field that turret-fire at nearby enemies.',
        'Dark' =>
          'Opens a void hole that pulls enemies in and throws them out of the area. Its radius scales with stats.',
        'Ice' =>
          'Raises a giant ice pillar. Nearby allies gain roughly 2–5× attack strength.',
        'Mud' => 'Lays a mud pool that heavily slows enemies inside it.',
        'Water' =>
          'Scatters splash traps. Each enemy contact triggers area damage to nearby enemies.',
        _ =>
          'Scatters element-tuned traps. Each placement triggers on enemy contact or aura.',
      };
      return CosmicSpecialInfo(
        subtitle: 'Trap Scatter • Field control',
        description: description,
        icon: AppIcons.gps_fixed,
      );
    case 'Kin':
      final description = switch (element) {
        'Light' =>
          'Heal escort orbs orbit the caster, then migrate to the ship, intercepting projectiles and pulsing heals along their path.',
        'Water' =>
          'A rain cloud follows the ship, dripping healing onto allies under it.',
        'Air' =>
          'An updraft column travels with the ship — enemies that try to close are lifted up and flung away.',
        'Earth' =>
          'Plants a row of indestructible stone wall segments. Enemies bumping into them are shoved back; the wall times out instead of being destroyed.',
        'Plant' =>
          'Grows a healing garden at your feet. Allies inside are healed over time, and the garden periodically drops collectible HP flowers nearby.',
        'Poison' =>
          'Fires a radial swirl of homing poison darts that seek nearby enemies, applying stacking poison on hit.',
        'Crystal' =>
          'Equips the ship with orbiting refractor shards. Each absorbs an enemy projectile and refracts a damaging beam back at a nearby enemy.',
        'Fire' =>
          'Passive — no active cast. While deployed, the first time the orb dies it instantly revives at 25% HP, and from that point on the fire kin has a permanent orbiting flame aura that damages nearby enemies for the rest of the run.',
        'Lava' =>
          'Coats the team in reactive molten plate. Incoming hits splash burning lava back at nearby enemies.',
        'Ice' =>
          'Charges briefly, then releases an all-direction frost burst that slows enemies by 90%. Range scales with Beauty — at max stats it can sweep the entire field.',
        'Steam' =>
          'Engages the boiler. Damage taken by the team converts into stacking companion attack speed (up to 10 stacks). Stress becomes tempo.',
        'Lightning' =>
          'Channels a tesla coil. While the kin actively charges, every companion auto-attack chains lightning to a nearby enemy. Charge time equals buff time — hold longer for sustained chains.',
        'Dust' =>
          'Plants a persistent dust cloud at the target. Each cast adds another (up to 10); enemy projectiles passing through any cloud have a high chance to miss.',
        'Mud' =>
          'Slings mud onto the ship. The ship gains a temporary enchant that drops slowing mud patches behind it as it moves.',
        'Spirit' =>
          'Releases a wisp that orbits the kin. Enemies killed by the spirit kin\'s auto-attacks tier the wisp up — it gains taunting, then an auto-attack, then at max tier heals its caster from the damage it deals.',
        'Dark' =>
          'Cloaks every companion in void — enemies cannot target them and retarget to the ship or orb instead.',
        'Blood' =>
          'Seals a blood pact. While active, a portion of damage taken by any alchemon OR the ship is converted into healing shared across every other living member of the team.',
        _ => 'Element changes the support utility.',
      };
      return CosmicSpecialInfo(
        subtitle: 'Support Ability • Elemental team utility',
        description: description,
        icon: AppIcons.favorite,
      );
    case 'Mystic':
      final (subtitle, desc, _) = switch (element) {
        'Fire' => (
          'The Ember Season • Beauty and Intelligence scale the field',
          'Lights a drifting ember field across the whole arena; anything that '
              'walks into an ember catches fire. It burns for as long as this '
              'Mystic is alive and deployed, and is cast once per deployment.',
          ['WORLD', 'PERSISTENT', 'BURN'],
        ),
        'Lava' => (
          'The Fissures • Strength scales the break',
          'Glowing cracks split the arena. When something as heavy as a BOSS '
              'steps over one it breaks further, and untargeted meteors rain '
              'across that ground. Holds while this Mystic is alive and '
              'deployed.',
          ['WORLD', 'TERRAIN', 'ANTI-BOSS'],
        ),
        'Lightning' => (
          'The Storm • Intelligence scales the bolt',
          'The sky turns over. Every ten seconds a bolt falls on someone at '
              'random; one that lands on a boss stuns it for a second. Holds '
              'while this Mystic is alive and deployed.',
          ['WORLD', 'STRIKE', 'BOSS STUN'],
        ),
        'Water' => (
          'The Maelstrom • Beauty and Intelligence scale the pull',
          'A vast whirlpool turns on the orb. Everything caught in it stops '
              'advancing and is carried slowly around the eye, grinding as it '
              'goes. Holds while this Mystic is alive and deployed.',
          ['WORLD', 'HOLD', 'GRIND'],
        ),
        'Ice' => (
          'The Blizzard • Intelligence scales the cold',
          'The whole arena freezes over: every enemy on the field is slowed for '
              'as long as the world holds, and it stacks on top of any other '
              'slow in play. Holds while this Mystic is alive and deployed.',
          ['WORLD', 'ARENA-WIDE', 'STACKS'],
        ),
        'Steam' => (
          'The Pressure • Intelligence scales the blast',
          'The arena builds pressure and vents it every eight seconds, throwing '
              'every enemy outward from the orb — hardest on whatever had got '
              'closest. It hurts nothing; it buys room. Holds while this Mystic '
              'is alive and deployed.',
          ['WORLD', 'DISPLACE', 'NO DAMAGE'],
        ),
        'Earth' => (
          'The Quaking • Strength scales the shock',
          'The ground will not hold still. Every fifteen seconds a quake runs '
              'the whole arena, hurting every enemy and knocking them off '
              'their feet. Holds while this Mystic is alive and deployed.',
          ['WORLD', 'ARENA-WIDE', 'STUN'],
        ),
        'Mud' => (
          'The Weight • Strength and Intelligence scale the drag',
          'Mud cakes everything on the field and it all takes more damage — '
              'barely anything on a wisp, far more on a brute, most of all on '
              'a boss. Holds while this Mystic is alive and deployed.',
          ['WORLD', 'AMPLIFY', 'ANTI-HEAVY'],
        ),
        'Dust' => (
          'The Haze • Intelligence scales the grit',
          'The air fills with grit. Enemy shooters choke on it — their rounds '
              'go off in their own faces instead of leaving the barrel. Holds '
              'while this Mystic is alive and deployed.',
          ['WORLD', 'MISFIRE', 'SELF-HARM'],
        ),
        'Crystal' => (
          'The Vein • Beauty scales the yield',
          'The dead crystallise. Enemies may leave shards behind; the ship '
              'draws them in, and each one feeds the alchemical meter. Holds '
              'while this Mystic is alive and deployed.',
          ['WORLD', 'PICKUP', 'SURGE'],
        ),
        'Air' => (
          'The Tornado • Intelligence scales the funnel',
          'A tornado walks a circuit around the arena. Anything it passes over '
              'is lifted off the ground, hauled into the funnel and ground '
              'down — then left wherever it ends up. Holds while this Mystic '
              'is alive and deployed.',
          ['WORLD', 'ROAMING', 'LIFT'],
        ),
        'Plant' => (
          'The Grove • Strength scales reach',
          'Grows two huge vines flanking the orb: one lashes everything that '
              'closes, one spits homing thorns at everything that does not. '
              'They stand while this Mystic is alive and deployed.',
          ['WORLD', 'MELEE', 'TURRET'],
        ),
        'Poison' => (
          'The Miasma • Intelligence and Beauty scale the spill',
          'The ship leaves poison wherever it flies, so the shape of the world '
              'is whatever the player draws with it. Holds while this Mystic '
              'is alive and deployed.',
          ['WORLD', 'SHIP TRAIL', 'POISON'],
        ),
        'Spirit' => (
          'The Turning • Intelligence scales the host',
          'Small enemies that die anywhere on the map get back up on your side '
              'as glowing revenants and hunt their own. The world holds while '
              'this Mystic is alive and deployed.',
          ['WORLD', 'PERSISTENT', 'RAISE'],
        ),
        'Dark' => (
          'The Maw • Strength scales the pull',
          'Tears a black hole open in the north of the arena that drags enemies '
              'in and spits them back out at the rim, hurt and reeling. It holds '
              'while this Mystic is alive and deployed.',
          ['WORLD', 'DISPLACE', 'CONTROL'],
        ),
        'Light' => (
          'The Dawn • Beauty scales the rising',
          'A star rises outside the arena and slowly brightens. When it breaks, '
              'everything you own — orb, ship and alchemons — is restored to '
              'full. Then it rises again. Holds while this Mystic is alive.',
          ['WORLD', 'FULL HEAL', 'SLOW BURN'],
        ),
        'Blood' => (
          'The Crimson Tithe • Strength and Beauty scale the draw',
          'A passive world: every auto attack that lands — the whole party\'s '
              'and the ship\'s — drains life back into the orb and into this '
              'Mystic. It holds while this Mystic is alive and deployed.',
          ['WORLD', 'PASSIVE', 'LIFESTEAL'],
        ),
        _ => (
          'Guardian Ultimate • Single-slot impact',
          'Element changes the ultimate into a collapse, zone, sentinel ring, trap, turret lane, heavy projectile, or hunter swarm.',
          <String>['GUARDIAN', 'ULTIMATE'],
        ),
      };
      return CosmicSpecialInfo(
        subtitle: subtitle,
        description: desc,
        icon: AppIcons.auto_awesome,
      );
    default:
      return const CosmicSpecialInfo(
        subtitle: '30s cooldown',
        description:
            'Special ability: Unleashes a burst of elemental energy. Its cooldown decreases with Speed.',
        icon: AppIcons.auto_awesome,
      );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPLORE STAT EFFECTS CARD
// ─────────────────────────────────────────────────────────────────────────────
/// Stat chips for the COSMIC tab — shows actual derived combat numbers
/// (HP, physical/elemental ATK + DEF, cooldown reduction, crit) the way
/// Boss tab shows its stat chips, so both tabs read like the same UI.
