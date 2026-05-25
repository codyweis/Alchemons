import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/services/gameengines/boss_battle_engine_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:provider/provider.dart';

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

class _ImprovedBattleScrollAreaState extends State<ImprovedBattleScrollArea>
    with SingleTickerProviderStateMixin {
  static const _tabLabels = ['Cosmic', 'Boss'];
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final family = widget.creature.mutationFamily ?? 'Unknown';

    final bossProfile = BattleCombatant(
      id: 'view_boss',
      name: widget.creature.name,
      types: widget.creature.types,
      family: family,
      statSpeed: widget.instance.statSpeed,
      statIntelligence: widget.instance.statIntelligence,
      statStrength: widget.instance.statStrength,
      statBeauty: widget.instance.statBeauty,
      level: widget.instance.level,
    );
    final battleSpecialMove = BattleMove.getSpecialMoveForCombatant(
      bossProfile,
    );
    final battleBasicMove = BattleMove.getBasicMove(family);

    return Column(
      children: [
        AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) => _BracketTabSelector(
            labels: _tabLabels,
            selectedIndex: _tabController.index,
            onSelect: (i) {
              HapticFeedback.selectionClick();
              _tabController.animateTo(i);
            },
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _ExploreTab(
                instance: widget.instance,
                family: family,
                types: widget.creature.types,
              ),
              _BossTab(
                profile: bossProfile,
                basicMove: battleBasicMove,
                specialMove: battleSpecialMove,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BracketTabSelector extends StatelessWidget {
  const _BracketTabSelector({
    required this.labels,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    final theme = context.read<FactionTheme>();
    final activeAccent = bracketReadableAccent(theme);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.lineSoft, width: 1)),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = selectedIndex == index;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? activeAccent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[index],
                  style: bracketText(
                    context,
                    12.5,
                    selected ? palette.ink : palette.muted,
                    weight: selected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ExploreTab extends StatelessWidget {
  const _ExploreTab({
    required this.instance,
    required this.family,
    required this.types,
  });

  final CreatureInstance instance;
  final String family;
  final List<String> types;

  @override
  Widget build(BuildContext context) {
    final element = types.firstOrNull ?? 'Normal';
    final role = _cosmicFamilyRole(family);
    final basic = _cosmicFamilyBasicInfo(family, element);
    final special = cosmicFamilySpecialInfo(family, element);
    final specialName = cosmicSpecialAbilityName(family, element);
    final mechanicNote = _elementMechanicNote(family, element);

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
          const BracketSectionDivider(label: 'Role'),
          const SizedBox(height: 10),
          _BracketInfoCard(title: role.title, description: role.description),
          const SizedBox(height: 18),
          const BracketSectionDivider(label: 'Basic'),
          const SizedBox(height: 10),
          _BracketInfoCard(
            title: basic.name,
            subtitle: basic.subtitle,
            description: basic.description,
          ),
          const SizedBox(height: 18),
          const BracketSectionDivider(label: 'Special'),
          const SizedBox(height: 10),
          _BracketInfoCard(
            title: specialName,
            subtitle: special.subtitle,
            description: special.description,
            icon: special.icon,
            accent: _survivalAccentColor(element),
            featured: true,
            footerLabel: mechanicNote?.label,
            footerBody: mechanicNote?.body,
          ),
          const SizedBox(height: 18),
          const BracketSectionDivider(label: 'Survival'),
          const SizedBox(height: 10),
          _SurvivalBracketCard(family: family, element: element),
        ],
      ),
    );
  }
}

class _BossTab extends StatelessWidget {
  const _BossTab({
    required this.profile,
    required this.basicMove,
    required this.specialMove,
  });

  final BattleCombatant profile;
  final BattleMove basicMove;
  final BattleMove specialMove;

  @override
  Widget build(BuildContext context) {
    final specialMoveSummary = BattleMove.specialSummaryForCombatant(profile);
    final specialCooldownTurns = BattleMove.specialCooldownForFamily(
      profile.family,
    );
    final specialRecoveryPerBasic =
        BattleMove.specialRecoveryPerBasicForCombatant(profile);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BracketSectionDivider(label: 'Stats'),
          const SizedBox(height: 10),
          _BossStatGrid(profile: profile),
          const SizedBox(height: 18),
          const BracketSectionDivider(label: 'Moves'),
          const SizedBox(height: 10),
          _BossMovesBracketCard(
            basicMoveName: basicMove.name,
            specialMoveName: specialMove.name,
            specialMoveSummary: specialMoveSummary,
          ),
          const SizedBox(height: 18),
          const BracketSectionDivider(label: 'Cooldowns'),
          const SizedBox(height: 10),
          _BossCooldownsBracketCard(
            specialCooldownTurns: specialCooldownTurns,
            specialRecoveryPerBasic: specialRecoveryPerBasic,
          ),
          const SizedBox(height: 18),
          const BracketSectionDivider(label: 'Stat scaling'),
          const SizedBox(height: 10),
          const _BossStatScalingBracketCard(),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Bracket-style content cards (shared by Cosmic + Boss tabs)
// ──────────────────────────────────────────────────────────────────────────

class _BracketStatTile extends StatelessWidget {
  const _BracketStatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    return CustomPaint(
      painter: BracketFramePainter(
        color: palette.line.withValues(alpha: 0.9),
        bracketSize: 8,
        strokeWidth: 1.05,
      ),
      child: Container(
        color: palette.surfaceFill(),
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
    final hp = CosmicBalance.companionMaxHp(
      level: instance.level,
      strength: instance.statStrength,
      intelligence: instance.statIntelligence,
    );
    final physAtk = CosmicBalance.companionPhysAtk(
      level: instance.level,
      strength: instance.statStrength,
    );
    final elemAtk = CosmicBalance.companionElemAtk(
      level: instance.level,
      beauty: instance.statBeauty,
    );
    final physDef = CosmicBalance.companionPhysDef(
      level: instance.level,
      strength: instance.statStrength,
      intelligence: instance.statIntelligence,
    );
    final elemDef = CosmicBalance.companionElemDef(
      level: instance.level,
      beauty: instance.statBeauty,
      intelligence: instance.statIntelligence,
    );
    final cdr = CosmicBalance.companionCooldownReduction(instance.statSpeed);
    final crit = CosmicBalance.companionCritChance(instance.statStrength);

    final stats = <_StatEntry>[
      _StatEntry('HP', hp.toString()),
      _StatEntry('P-ATK', physAtk.toString()),
      _StatEntry('E-ATK', elemAtk.toString()),
      _StatEntry('P-DEF', physDef.toString()),
      _StatEntry('E-DEF', elemDef.toString()),
      _StatEntry('CD', '×${cdr.toStringAsFixed(2)}'),
      _StatEntry('CRIT', '${(crit * 100).round()}%'),
    ];

    return _StatGrid(stats: stats);
  }
}

class _BossStatGrid extends StatelessWidget {
  const _BossStatGrid({required this.profile});

  final BattleCombatant profile;

  @override
  Widget build(BuildContext context) {
    final stats = <_StatEntry>[
      _StatEntry('HP', profile.maxHp.toString()),
      _StatEntry('ATK', profile.physAtk.toString()),
      _StatEntry('DEF', profile.physDef.toString()),
      _StatEntry('SPD', profile.speed.toString()),
    ];
    return _StatGrid(stats: stats, columns: 4);
  }
}

class _StatEntry {
  const _StatEntry(this.label, this.value);
  final String label;
  final String value;
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats, this.columns = 4});

  final List<_StatEntry> stats;
  final int columns;

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

class _BracketInfoCard extends StatelessWidget {
  const _BracketInfoCard({
    required this.title,
    this.subtitle,
    required this.description,
    this.icon,
    this.accent,
    this.featured = false,
    this.footerLabel,
    this.footerBody,
  });

  final String title;
  final String? subtitle;
  final String description;
  final IconData? icon;
  final Color? accent;
  final bool featured;
  final String? footerLabel;
  final String? footerBody;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    final theme = context.read<FactionTheme>();
    final activeAccent = bracketReadableAccent(theme, color: accent);
    final footer = (footerLabel != null && footerBody != null)
        ? Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 3, height: 10, color: activeAccent),
                    const SizedBox(width: 7),
                    Text(
                      footerLabel!.toUpperCase(),
                      style: bracketText(
                        context,
                        11,
                        activeAccent,
                        weight: FontWeight.w700,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  footerBody!,
                  style: bracketText(
                    context,
                    12.5,
                    palette.muted,
                    weight: FontWeight.w500,
                  ),
                  strutStyle: const StrutStyle(height: 1.45),
                ),
              ],
            ),
          )
        : null;

    return CustomPaint(
      painter: BracketFramePainter(
        color: featured
            ? activeAccent.withValues(alpha: 0.95)
            : palette.line.withValues(alpha: 0.9),
        bracketSize: featured ? 12 : 10,
        strokeWidth: featured ? 1.35 : 1.05,
      ),
      child: Container(
        color: featured
            ? Color.alphaBlend(
                activeAccent.withValues(alpha: palette.isDark ? 0.10 : 0.07),
                palette.surfaceFill(),
              )
            : palette.surfaceFill(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
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
            Text(
              description,
              style: bracketText(
                context,
                12.5,
                palette.muted,
                weight: FontWeight.w500,
              ),
              strutStyle: const StrutStyle(height: 1.45),
            ),
            if (footer != null) footer,
          ],
        ),
      ),
    );
  }
}

class _SurvivalBracketCard extends StatelessWidget {
  const _SurvivalBracketCard({required this.family, required this.element});

  final String family;
  final String element;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    final notes = _cosmicSurvivalNotes(family, element);
    final accent = _survivalAccentColor(element);

    return CustomPaint(
      painter: BracketFramePainter(
        color: accent.withValues(alpha: 0.6),
        bracketSize: 10,
        strokeWidth: 1.05,
      ),
      child: Container(
        color: palette.surfaceFill(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.blur_circular_rounded,
                    size: 14,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    notes.summary,
                    style: bracketText(
                      context,
                      12.5,
                      palette.ink,
                      weight: FontWeight.w600,
                    ),
                    strutStyle: const StrutStyle(height: 1.4),
                  ),
                ),
              ],
            ),
            if (notes.bullets.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (var i = 0; i < notes.bullets.length; i++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(width: 5, height: 5, color: accent),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notes.bullets[i],
                        style: bracketText(
                          context,
                          12,
                          palette.muted,
                          weight: FontWeight.w500,
                        ),
                        strutStyle: const StrutStyle(height: 1.4),
                      ),
                    ),
                  ],
                ),
                if (i < notes.bullets.length - 1) const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _BossMovesBracketCard extends StatelessWidget {
  const _BossMovesBracketCard({
    required this.basicMoveName,
    required this.specialMoveName,
    required this.specialMoveSummary,
  });

  final String basicMoveName;
  final String specialMoveName;
  final String specialMoveSummary;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    return CustomPaint(
      painter: BracketFramePainter(
        color: palette.line.withValues(alpha: 0.9),
        bracketSize: 10,
        strokeWidth: 1.05,
      ),
      child: Container(
        color: palette.surfaceFill(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BracketLabelValue(label: 'Basic', value: basicMoveName),
            const SizedBox(height: 10),
            _BracketLabelValue(label: 'Special', value: specialMoveName),
            const SizedBox(height: 12),
            Text(
              specialMoveSummary,
              style: bracketText(
                context,
                12.5,
                palette.muted,
                weight: FontWeight.w500,
              ),
              strutStyle: const StrutStyle(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _BossCooldownsBracketCard extends StatelessWidget {
  const _BossCooldownsBracketCard({
    required this.specialCooldownTurns,
    required this.specialRecoveryPerBasic,
  });

  final int specialCooldownTurns;
  final int specialRecoveryPerBasic;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    final rows = <(String, String)>[
      ('Basic action', '2 turns'),
      ('Special action', '3 turns'),
      (
        'Special CD',
        '$specialCooldownTurns turn${specialCooldownTurns == 1 ? '' : 's'}',
      ),
      ('CD / basic', '$specialRecoveryPerBasic turn(s) recovered'),
      ('Special unlock', 'Level 5'),
    ];
    return CustomPaint(
      painter: BracketFramePainter(
        color: palette.line.withValues(alpha: 0.9),
        bracketSize: 10,
        strokeWidth: 1.05,
      ),
      child: Container(
        color: palette.surfaceFill(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              _BracketLabelValue(label: rows[i].$1, value: rows[i].$2),
              if (i < rows.length - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _BossStatScalingBracketCard extends StatelessWidget {
  const _BossStatScalingBracketCard();

  static const _entries = <(String, String, String)>[
    (
      'SPD',
      'Tempo + cooldown',
      'Turn order priority, plus extra special recovery on basics at SPD 2.0 / 3.0 / 4.0 / 4.8.',
    ),
    (
      'INT',
      'Elemental power',
      'Raises elemental attack and boosts DoT/regen effect scaling.',
    ),
    (
      'BEAUTY',
      'Elemental defense',
      'Raises elemental defense and adds to physical defense.',
    ),
    (
      'STR',
      'Physical core',
      'Raises max HP, physical attack, and physical defense.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    final theme = context.read<FactionTheme>();
    final activeAccent = bracketReadableAccent(theme);
    return CustomPaint(
      painter: BracketFramePainter(
        color: palette.line.withValues(alpha: 0.9),
        bracketSize: 10,
        strokeWidth: 1.05,
      ),
      child: Container(
        color: palette.surfaceFill(),
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 14),
        child: Column(
          children: [
            for (var i = 0; i < _entries.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: CustomPaint(
                      painter: BracketFramePainter(
                        color: activeAccent.withValues(alpha: 0.82),
                        bracketSize: 6,
                        strokeWidth: 1,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        alignment: Alignment.center,
                        child: Text(
                          _entries[i].$1,
                          style: bracketText(
                            context,
                            11,
                            palette.ink,
                            weight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _entries[i].$2,
                          style: bracketText(
                            context,
                            12.5,
                            palette.ink,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _entries[i].$3,
                          style: bracketText(
                            context,
                            12,
                            palette.muted,
                            weight: FontWeight.w500,
                          ),
                          strutStyle: const StrutStyle(height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (i < _entries.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _BracketLabelValue extends StatelessWidget {
  const _BracketLabelValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label.toUpperCase(),
            style: bracketText(
              context,
              11,
              palette.muted,
              weight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: bracketText(
              context,
              13,
              palette.ink,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

_CosmicFamilyRole _cosmicFamilyRole(String family) {
  switch (family) {
    case 'Horn':
      return const _CosmicFamilyRole(
        title: 'Frontline Bastion',
        description:
            'Horns force close fights. They push into short range, soak '
            'pressure with shields, trade some raw damage for durability, '
            'and convert specials into charge impacts, '
            'body-blocking zones, taunts, slows, and interceptions that hold '
            'danger in front of the team.',
      );
    case 'Wing':
      return const _CosmicFamilyRole(
        title: 'Beam Hunter',
        description:
            'Wings are long-range pursuit attackers. They hold safer '
            'spacing, fire quickly, and use piercing beam specials to line '
            'through packs, bosses, and drifting targets.',
      );
    case 'Let':
      return const _CosmicFamilyRole(
        title: 'Siege Caster',
        description:
            'Lets are long-range siege casters. They stay back, commit to '
            'lanes, and drop a heavy meteor core followed by distinct '
            'elemental pressure: lances, shards, orbiting blades, guided '
            'finishers, or persistent control fields.',
      );
    case 'Pip':
      return const _CosmicFamilyRole(
        title: 'Tempo Carry',
        description:
            'Pips are fast skirmish finishers. They cycle attacks quickly, '
            'chase weak or scattered targets, and turn specials into tempo '
            'bursts: ricochets, pursuit darts, moving snares, quick haste, '
            'or heavy cleanup shots depending on element. They excel at wave '
            'cleanup but are less efficient into bosses than most families.',
      );
    case 'Mane':
      return const _CosmicFamilyRole(
        title: 'Barrage Bruiser',
        description:
            'Manes are martial barrage bruisers. They step into medium '
            'range and convert element into forward techniques: cleaves, '
            'cross-cuts, pressure lanes, readable staggers, and tempo combos that '
            'punish whatever is directly in front of them.',
      );
    case 'Kin':
      return const _CosmicFamilyRole(
        title: 'Guardian Support',
        description:
            'Kins are guardian supports. Their specials heal, bless, and '
            'deploy element-shaped constructs such as ship wards, escort '
            'sentries, snares, peel veils, interceptors, and other support '
            'tools instead of one generic orbital move.',
      );
    case 'Mystic':
      return const _CosmicFamilyRole(
        title: 'Guardian Ultimate',
        description:
            'Mystics are single-slot guardian power picks. Their specials '
            'are intentionally slower and much more powerful, with each '
            'element behaving like a distinct showpiece ultimate rather than '
            'a generic orbital burst.',
      );
    case 'Mask':
      return const _CosmicFamilyRole(
        title: 'Control Trapper',
        description:
            'Masks shape the battlefield. They bait enemies into taunt '
            'totems, decoys, and seeker swarms so pressure shifts off your '
            'ship and into prepared kill zones.',
      );
    default:
      return const _CosmicFamilyRole(
        title: 'Companion',
        description: 'A loyal companion that fights alongside your ship.',
      );
  }
}

/// Flat section header for the battle tab — no box, just accent bar + rule
class _CosmicFamilyRole {
  final String title;
  final String description;
  const _CosmicFamilyRole({required this.title, required this.description});
}

class _CosmicSurvivalNotes {
  final String summary;
  final List<String> bullets;

  const _CosmicSurvivalNotes({required this.summary, required this.bullets});
}

_CosmicSurvivalNotes _cosmicSurvivalNotes(String family, String element) {
  final normalizedFamily = family.trim();
  final normalizedElement = element.trim();

  final bullets = <String>[];

  switch (normalizedFamily) {
    case 'Horn':
      bullets.addAll([
        'Horns are the frontline bastion family in survival: they push forward, intercept orb threats, and fight closer than most companions.',
        'Horn identity includes a deliberate tradeoff: lower outgoing damage for stronger damage soaking and frontline uptime.',
        'Shield-heavy Horn variants buy time for the whole defense line, while taunt, slow, and intercept variants keep pressure pointed at the front.',
      ]);
      if ([
        'Earth',
        'Lava',
        'Mud',
        'Blood',
        'Ice',
      ].contains(normalizedElement)) {
        bullets.add(
          '$normalizedElement Horn leans especially hard into anchor duty with heavier body-blocking, sturdier pressure, or longer frontline presence.',
        );
      } else if ([
        'Light',
        'Crystal',
        'Lightning',
        'Air',
      ].contains(normalizedElement)) {
        bullets.add(
          '$normalizedElement Horn is more of a guard-response variant, using interceptions or fast peel to stop priority threats before they reach the orb.',
        );
      } else if ([
        'Water',
        'Steam',
        'Plant',
        'Poison',
      ].contains(normalizedElement)) {
        bullets.add(
          '$normalizedElement Horn adds lane control or recovery to the charge, helping the frontline stabilize without replacing dedicated support.',
        );
      }
      return _CosmicSurvivalNotes(
        summary:
            'Horn plays as an aggressive tank in cosmic survival: it stands in front of danger, takes reduced incoming damage, and gives up some DPS to hold the line.',
        bullets: bullets,
      );
    case 'Wing':
      bullets.addAll([
        'Wings are mobile hunters: they chase shooters, peel hunters, and keep moving instead of holding a static line.',
        'They are strongest when you need pursuit, cleanup, or boss pressure rather than pure orb anchoring.',
      ]);
      if (['Spirit', 'Air', 'Lightning', 'Light'].contains(normalizedElement)) {
        bullets.add(
          '$normalizedElement Wing is one of the cleaner pursuit variants, so it excels at finishing scattered enemies before they rejoin the wave.',
        );
      }
      return _CosmicSurvivalNotes(
        summary:
            'Wing is a skirmisher in survival. It wins by flying at vulnerable targets, re-angling constantly, and preventing backline enemies from getting comfortable.',
        bullets: bullets,
      );
    case 'Let':
      bullets.addAll([
        'Lets are siege companions: they commit to lanes, fire from safer distance, and do not want to brawl on top of enemies.',
        'Every Let special starts with a heavy meteor identity, then the element decides whether the follow-through becomes lances, shards, homing pressure, orbiting blades, or a real control field.',
      ]);
      if ([
        'Earth',
        'Mud',
        'Steam',
        'Poison',
        'Dark',
      ].contains(normalizedElement)) {
        bullets.add(
          '$normalizedElement Let is one of the anchored field variants, so it shines when enemies are funneled through one lane and forced to sit inside its setup.',
        );
      } else if (['Ice', 'Plant'].contains(normalizedElement)) {
        bullets.add(
          '$normalizedElement Let uses moving snare pressure rather than a static field, so it is better at catching targets while the wave is still shifting.',
        );
      }
      return _CosmicSurvivalNotes(
        summary:
            'Let behaves like siege artillery in survival: slower to reposition, heavier on commitment, and best when it can shape a lane before enemies reach the orb.',
        bullets: bullets,
      );
    case 'Pip':
      bullets.addAll([
        'Pips are cleanup assassins: they dart after weak or spread-out enemies and keep pressure high between larger specials.',
        'Pip identity is speed-first tempo: strong wave picks and chase pressure, but reduced boss damage compared with most families.',
        'They are valuable for removing messy leftovers so bulkier allies can stay on important threats, and they should not play like static lane holders.',
      ]);
      if ([
        'Lightning',
        'Air',
        'Crystal',
        'Light',
        'Fire',
      ].contains(normalizedElement)) {
        bullets.add(
          '$normalizedElement Pip is one of the better rebound or speed-chain variants, so it gets extra value when waves arrive in clumps or staggered packs.',
        );
      } else if ([
        'Ice',
        'Mud',
        'Plant',
        'Poison',
      ].contains(normalizedElement)) {
        bullets.add(
          '$normalizedElement Pip adds moving snare pressure to its chase pattern, so it helps catch leaks without becoming a true field-control family.',
        );
      } else if ([
        'Earth',
        'Lava',
        'Dark',
        'Blood',
        'Spirit',
      ].contains(normalizedElement)) {
        bullets.add(
          '$normalizedElement Pip leans into heavier cleanup shots, trading some volume for stronger pursuit or finishing power.',
        );
      }
      return _CosmicSurvivalNotes(
        summary:
            'Pip is a fast tempo finisher in survival. It should feel surgical and opportunistic, strongest in wave cleanup and intentionally weaker in boss races.',
        bullets: bullets,
      );
    case 'Mane':
      bullets.addAll([
        'Mane species are offense-first catapult bruisers: they step up and fire piercing specials with a distinct payoff per species.',
        'They are best when paired with a true anchor behind them, because Mane species win by pressure cadence and lane control, not by bunker control.',
      ]);
      final elementDetail = switch (normalizedElement) {
        'Water' =>
          'Watermane launches a massive water wall that carries enemies with it as it travels.',
        'Steam' =>
          'Steammane fires a big traveling geyser that releases damaging steam puffs along its path.',
        'Plant' =>
          'Plantmane roots every enemy it hits; rooted kills burst into plant area damage that can root nearby enemies too.',
        'Poison' =>
          'Poisonmane poisons every enemy pierced, stacking toxin pressure across the whole line.',
        'Crystal' =>
          'Crystalmane pierces packs normally, but detonates into a huge boss-shattering crystal burst on boss contact.',
        'Blood' =>
          'Bloodmane heals from every enemy it pierces, turning a clean line through a pack into direct sustain.',
        'Dark' =>
          'Darkmane sends a slow void cut that pulls enemies inward and punishes weakened targets caught in it.',
        'Earth' =>
          'Earthmane launches a huge slow fault slab that grinds through enemies and leaves quake bursts as it breaks apart.',
        'Fire' =>
          'Firemane throws a dense wave of fast fireballs through the lane for immediate piercing pressure.',
        'Lightning' =>
          'Lightningmane shoots small lightning balls to scattered map spots; each lands as a compact zap trap.',
        'Air' =>
          'Airmane pierces in a wide gust pattern and pushes every enemy in its path forward with the projectile.',
        'Dust' =>
          'Dustmane leaves suppressing dust clouds behind its projectile so enemies caught in the trail stop shooting.',
        'Ice' =>
          'Icemane freezes anything its piercing frost shot touches while traveling.',
        'Mud' =>
          'Mudmane breaks apart on the first enemy hit, scattering ten mud shards in every direction.',
        'Lava' =>
          'Lavamane leaves a burning lava blob at every enemy collision, turning the pierce path into damage-over-time zones.',
        'Spirit' =>
          'Spiritmane starts with one soul shot and ramps into a machine-gun stream up to ten shots before resetting.',
        'Light' =>
          'Lightmane launches a slow glowing orb that grows bigger and hits harder every time it pierces an enemy.',
        _ =>
          '$normalizedElement Mane keeps the offense-first catapult pattern with a species-specific piercing payoff.',
      };
      bullets.add(elementDetail);
      return _CosmicSurvivalNotes(
        summary:
            'Mane species are offense-first catapult bruisers in survival. Each one has a distinct piercing payoff instead of a generic slash.',
        bullets: bullets,
      );
    case 'Kin':
      bullets.addAll([
        'Kins are support escorts: they hold a safer distance, keep guardian pieces active, and stabilize the defense line instead of overcommitting.',
        'They are at their best when their orbitals, blessings, intercepts, or support zones stay online long enough to shape the fight.',
      ]);
      if (['Light', 'Water', 'Crystal'].contains(normalizedElement)) {
        bullets.add(
          '$normalizedElement Kin is one of the cleanest pure-support variants, with stronger escort, reinforcement, or interception value than most families get.',
        );
      } else if ([
        'Steam',
        'Mud',
        'Earth',
        'Plant',
      ].contains(normalizedElement)) {
        bullets.add(
          '$normalizedElement Kin leans more into forward control pieces, so it plays like a support-artillery hybrid instead of a pure healer.',
        );
      }
      return _CosmicSurvivalNotes(
        summary:
            'Kin is the dedicated support family in survival. It creates safer space through healing, blessing, escort orbitals, and control pieces rather than raw burst.',
        bullets: bullets,
      );
    case 'Mystic':
      bullets.addAll([
        'Mystics are premium ultimate casters: they care more about landing one fight-shaping special than constant uptime.',
        'They are strongest when the fight gives them time to establish collapses, control zones, sentinels, trap patterns, or hunter swarms.',
      ]);
      if ([
        'Steam',
        'Dark',
        'Earth',
        'Poison',
        'Light',
        'Air',
      ].contains(normalizedElement)) {
        bullets.add(
          '$normalizedElement Mystic is especially survival-relevant because it creates defensive orbitals, interception, taunt control, or long-lived denial space.',
        );
      } else if ([
        'Fire',
        'Lightning',
        'Crystal',
        'Dust',
        'Lava',
        'Spirit',
      ].contains(normalizedElement)) {
        bullets.add(
          '$normalizedElement Mystic is the more offensive ultimate style, using collapse burst, chain pressure, heavy projectiles, or hunter damage to swing a wave.',
        );
      } else if (normalizedElement == 'Blood') {
        bullets.add(
          'Blood Mystic adds sustain on top of its control pattern, making it one of the safest long-run mystic picks.',
        );
      }
      return _CosmicSurvivalNotes(
        summary:
            'Mystic is the premium ultimate family in survival. It should feel deliberate, setup-heavy, and capable of reshaping the battlefield with one special.',
        bullets: bullets,
      );
    case 'Mask':
      bullets.addAll([
        'Masks are battlefield manipulators: they lure, misdirect, snare, and punish enemies for choosing the wrong path.',
        'They are best in normal waves where aggro control and trap placement can peel pressure off the orb before the line breaks.',
      ]);
      if ([
        'Mud',
        'Dark',
        'Steam',
        'Poison',
        'Earth',
        'Light',
      ].contains(normalizedElement)) {
        bullets.add(
          '$normalizedElement Mask is one of the stronger trap-control variants, so it gets most of its value from where it places pressure rather than from direct burst.',
        );
      }
      return _CosmicSurvivalNotes(
        summary:
            'Mask is the trickster-control family in survival. It protects the orb by manipulating enemy movement, not by winning a straight damage race.',
        bullets: bullets,
      );
  }

  return _CosmicSurvivalNotes(
    summary:
        '$normalizedFamily has a distinct survival role, but its value still depends on whether this $normalizedElement variant leans toward pressure, control, support, or sustain.',
    bullets: [
      '$normalizedElement changes how the family delivers its role, not just the color of the projectiles.',
      'In survival, the best picks are the ones whose movement and special pattern solve a specific problem for the team.',
    ],
  );
}

Color _survivalAccentColor(String element) {
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
  final String subtitle;
  final String description;
  final IconData icon;
  const _CosmicBasicInfo({
    required this.name,
    required this.subtitle,
    required this.description,
    required this.icon,
  });
}

_CosmicBasicInfo _cosmicFamilyBasicInfo(String family, String element) {
  switch (family) {
    case 'Mane':
      return _CosmicBasicInfo(
        name: '$element Twin Volley',
        subtitle: '2 forward slashes',
        description:
            'Fires two forward $element shots with slight spread. The basic '
            'attack is built for lane pressure and consistent frontal damage, '
            'not circular spray.',
        icon: Icons.waves,
      );
    case 'Horn':
      return _CosmicBasicInfo(
        name: '$element Ram Shot',
        subtitle: 'Heavy close-range projectile',
        description:
            'Launches a large, slow $element projectile with an oversized '
            'hitbox. Horn basics hit hard up close and help keep pressure on '
            'targets before the shield-charge special lands.',
        icon: Icons.shield,
      );
    case 'Mask':
      return _CosmicBasicInfo(
        name: '$element Probe Bolt',
        subtitle: 'Fast piercing setup shot',
        description:
            'Fires a quick piercing $element bolt to tag targets in a line. '
            'Mask basics are light pressure tools that set up the family\'s '
            'trap, lure, and decoy control game.',
        icon: Icons.warning_amber,
      );
    case 'Wing':
      return _CosmicBasicInfo(
        name: '$element Feather Burst',
        subtitle: '2 rapid pursuit shots',
        description:
            'Unleashes two quick $element bolts in succession. Wing basics '
            'keep damage flowing while the companion stays mobile and looks '
            'for a clean beam line.',
        icon: Icons.arrow_forward,
      );
    case 'Kin':
      return _CosmicBasicInfo(
        name: '$element Guided Bolt',
        subtitle: 'Reliable homing support fire',
        description:
            'Fires a slower $element bolt that homes toward the nearest '
            'enemy, steering mid-flight. Deals 110% damage and rarely '
            'misses. Kin basics are about consistency while the guardian '
            'orbits and healing setup come online.',
        icon: Icons.favorite,
      );
    case 'Mystic':
      return _CosmicBasicInfo(
        name: '$element Arcane Triad',
        subtitle: '3 spread bolts',
        description:
            'Releases three small $element bolts in a spread. Mystic basics '
            'hold space between ultimates, but the family\'s real power is in '
            'its slower, element-specific guardian special.',
        icon: Icons.auto_awesome,
      );
    case 'Pip':
      return _CosmicBasicInfo(
        name: '$element Dart Burst',
        subtitle: '3 fast tracking darts',
        description:
            'Fires a quick burst of small $element darts. Pip basics are '
            'built for high uptime, target pressure, and staying active '
            'between ricochet specials.',
        icon: Icons.bolt,
      );
    case 'Let':
      return _CosmicBasicInfo(
        name: '$element Bomb',
        subtitle: 'Slow artillery shot',
        description:
            'Lobs a compact $element bomb with more heft than a standard bolt. '
            'Let basics reinforce the siege role: slower, heavier lane pressure '
            'between the family\'s larger element-shaped meteor specials.',
        icon: Icons.south,
      );
    default:
      return _CosmicBasicInfo(
        name: '$element Bolt',
        subtitle: 'Auto-targets nearest',
        description:
            'Fires a $element projectile at the nearest enemy within range. '
            'Damage is based on Strength. Attack speed scales with Speed stat.',
        icon: Icons.gps_fixed,
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
  final List<String> tags;
  const CosmicSpecialInfo({
    required this.subtitle,
    required this.description,
    required this.icon,
    this.tags = const [],
  });
}

class _ElementMechanicNote {
  const _ElementMechanicNote({required this.label, required this.body});

  final String label;
  final String body;
}

_ElementMechanicNote _survivalPassive(String body) =>
    _ElementMechanicNote(label: 'Survival only', body: body);

CosmicSpecialInfo? _speciesSpecificCosmicSpecialInfo(
  String family,
  String element,
) {
  final f = family.toLowerCase();
  final species = '$element$f';
  final abilityName = cosmicSpecialAbilityName(f, element);

  (String, String, IconData, List<String>)? data;
  switch (f) {
    case 'horn':
      data = switch (element) {
        'Fire' => (
          'Blaze ram',
          '$species raises a shield, makes a fast forward charge, and fires a tight cone of fireballs that leave brief burning trails.',
          Icons.local_fire_department,
          ['CHARGE', 'BURN', 'WAKE', 'FIRE'],
        ),
        'Lava' => (
          'Molten plow',
          '$species raises a larger shield, makes a slow heavy charge, and releases massive piercing magma boulders that leave lava trails and split into slag.',
          Icons.volcano,
          ['CHARGE', 'TRAIL', 'BOULDER', 'LAVA'],
        ),
        'Lightning' => (
          'Snap parry',
          '$species raises a light shield, snaps forward in the quickest charge, and shoots bouncing lightning rods that can intercept incoming fire.',
          Icons.flash_on,
          ['FAST', 'PARRY', 'BOUNCE', 'LIGHTNING'],
        ),
        'Water' => (
          'Surf guard',
          '$species raises a shield, shoves forward on a surf charge, sends crossing water tusks through the lane, and returns a small ship heal.',
          Icons.water,
          ['CHARGE', 'HEAL', 'CRASH', 'WATER'],
        ),
        'Ice' => (
          'Glacier body-check',
          '$species raises a sturdy shield, lumbers forward with a broad crash, and plants stationary ice slabs that heavily slow the front lane.',
          Icons.ac_unit,
          ['HEAVY', 'SLOW', 'FRONTLINE', 'ICE'],
        ),
        'Steam' => (
          'Pressure vents',
          '$species raises a shield, bursts forward, and leaves stationary steam vents that taunt, slow, and keep firing steam puffs.',
          Icons.blur_on,
          ['TAUNT', 'VENTS', 'PUFFS', 'STEAM'],
        ),
        'Earth' => (
          'Fortress crash',
          '$species raises the biggest shield, makes the slowest wide charge, and drops taunting stone bulwarks that can break apart into shrapnel.',
          Icons.terrain,
          ['ANCHOR', 'TAUNT', 'BULWARK', 'EARTH'],
        ),
        'Mud' => (
          'Quagmire shove',
          '$species raises a shield, drags a short wide charge through the lane, and sprays heavy mud globs that linger as slowing sludge.',
          Icons.grain,
          ['SLOW', 'SLUDGE', 'CHARGE', 'MUD'],
        ),
        'Dust' => (
          'Skitter ram',
          '$species raises a light shield, skitters through a long narrow charge, and fans bouncing sandwake shots behind the ram lane.',
          Icons.cloud,
          ['DASH', 'DISRUPT', 'NARROW', 'DUST'],
        ),
        'Crystal' => (
          'Mirror guard',
          '$species raises a reflective shield, takes a measured charge step, and spins orbiting crystal mirror plates that intercept and bounce shots.',
          Icons.diamond,
          ['INTERCEPT', 'REFRACT', 'GUARD', 'CRYSTAL'],
        ),
        'Air' => (
          'Gale dash',
          '$species raises a light shield, makes the longest and fastest gale charge, and fires crosswind crescents ahead of it that can intercept incoming shots.',
          Icons.air,
          ['DASH', 'PEEL', 'INTERCEPT', 'AIR'],
        ),
        'Plant' => (
          'Thorn hedge',
          '$species raises a large shield, advances slowly, and plants a stationary thorn hedge that roots enemies and fires thorn shots.',
          Icons.local_florist,
          ['ROOT', 'TURRET', 'HEDGE', 'PLANT'],
        ),
        'Poison' => (
          'Venom shove',
          '$species raises a guard shield, crashes forward, and leaves toxic fang posts plus poison clouds where it lands.',
          Icons.biotech,
          ['POISON', 'CHOKE', 'GUARD', 'VENOM'],
        ),
        'Spirit' => (
          'Phase bastion',
          '$species raises a phase shield, slips farther through the target, and leaves guarded spirit plates across the impact lane.',
          Icons.auto_awesome,
          ['PHASE', 'GUARD', 'PLATES', 'SPIRIT'],
        ),
        'Dark' => (
          'Execution ram',
          '$species raises a small shield, makes a quick narrow crash, and drops dark taunt pieces that pull enemies into a tight kill lane.',
          Icons.dark_mode,
          ['TAUNT', 'EXECUTE', 'NARROW', 'DARK'],
        ),
        'Light' => (
          'Radiant ward',
          '$species raises a radiant shield, takes a short guardian charge, plants wide parry plates, and heals the ship.',
          Icons.wb_sunny,
          ['PARRY', 'HEAL', 'WARD', 'LIGHT'],
        ),
        'Blood' => (
          'Crimson fortress',
          '$species raises a heavy shield, body-slams forward, heals itself, and leaves blood bulwarks in the impact lane.',
          Icons.bloodtype,
          ['HEAL', 'BULWARK', 'SUSTAIN', 'BLOOD'],
        ),
        _ => null,
      };
      break;
    case 'wing':
      data = switch (element) {
        'Fire' => (
          'Inferno sweep',
          '$species widens its beam into a sweeping fire ring and leaves a burning trail through the lane.',
          Icons.local_fire_department,
          ['BEAM', 'RING', 'TRAIL', 'FIRE'],
        ),
        'Lava' => (
          'Ground scar',
          '$species carves the beam path into lingering lava scars that keep burning after the beam passes.',
          Icons.volcano,
          ['BEAM', 'TRAIL', 'BURN', 'LAVA'],
        ),
        'Lightning' => (
          'Charged blast',
          '$species briefly charges, then releases a heavy lightning blast down the beam lane.',
          Icons.flash_on,
          ['BEAM', 'CHARGE', 'BURST', 'LIGHTNING'],
        ),
        'Water' => (
          'Healing tide',
          '$species cuts through enemies while sending healing through allies and the ship.',
          Icons.water,
          ['BEAM', 'HEAL', 'SUPPORT', 'WATER'],
        ),
        'Ice' => (
          'Frost buildup',
          '$species builds frost on sustained beam contact until targets snap into a hard freeze.',
          Icons.ac_unit,
          ['BEAM', 'FREEZE', 'RAMP', 'ICE'],
        ),
        'Steam' => (
          'Boiler execute',
          '$species executes the first target it catches, then erupts into lingering steam clouds.',
          Icons.blur_on,
          ['BEAM', 'EXECUTE', 'CLOUDS', 'STEAM'],
        ),
        'Earth' => (
          'Boulder beam',
          '$species fires a few enormous slow boulder beams that cover a wider lane than normal beams.',
          Icons.terrain,
          ['BEAM', 'HEAVY', 'WIDE', 'EARTH'],
        ),
        'Mud' => (
          'Mire rake',
          '$species rakes the lane with a beam that applies a long heavy slow to anything held inside it.',
          Icons.grain,
          ['BEAM', 'SLOW', 'CONTROL', 'MUD'],
        ),
        'Dust' => (
          'Sandblast',
          '$species sandblasts the beam lane and disorients enemy shooters so their shots can be redirected.',
          Icons.cloud,
          ['BEAM', 'DISRUPT', 'PIERCE', 'DUST'],
        ),
        'Crystal' => (
          'Prism heal',
          '$species heals from beam contact while refracting extra prism hits through the target line.',
          Icons.diamond,
          ['BEAM', 'REFRACT', 'SUSTAIN', 'CRYSTAL'],
        ),
        'Air' => (
          'Tornado drill',
          '$species drills forward with a wind beam that knocks enemies back out of the lane.',
          Icons.air,
          ['BEAM', 'KNOCKBACK', 'DRILL', 'AIR'],
        ),
        'Plant' => (
          'Vine pursuit',
          '$species grows guided vine tendrils from the beam that keep chasing enemies after contact.',
          Icons.local_florist,
          ['BEAM', 'VINES', 'HUNTER', 'PLANT'],
        ),
        'Poison' => (
          'Venom ring',
          '$species forms a venom ring around the caster that poisons enemies caught near the beam setup.',
          Icons.biotech,
          ['BEAM', 'RING', 'POISON', 'VENOM'],
        ),
        'Spirit' => (
          'Ship tether',
          '$species tethers through the ship, letting the ship fire the follow-up laser.',
          Icons.auto_awesome,
          ['BEAM', 'TETHER', 'SHIP', 'SPIRIT'],
        ),
        'Dark' => (
          'Double pulse',
          '$species makes both basic attacks and beam pulses fire twice as often.',
          Icons.dark_mode,
          ['BEAM', 'HASTE', 'PULSE', 'DARK'],
        ),
        'Light' => (
          'Radiant refraction',
          '$species refracts beam kills into two smaller beams that hunt nearby enemies.',
          Icons.wb_sunny,
          ['BEAM', 'REFRACT', 'HUNTER', 'LIGHT'],
        ),
        'Blood' => (
          'Crimson lance',
          '$species hunts the lowest-health target and executes enemies that fall below the threshold.',
          Icons.bloodtype,
          ['BEAM', 'HUNTER', 'EXECUTE', 'BLOOD'],
        ),
        _ => null,
      };
      break;
    case 'let':
      data = switch (element) {
        'Fire' => (
          'Ember follow-up',
          '$species drops a fire meteor, then follows with fast ember lances instead of lingering residue.',
          Icons.local_fire_department,
          ['METEOR', 'LANCES', 'FAST', 'FIRE'],
        ),
        'Lava' => (
          'Magma split',
          '$species throws slow massive magma chunks that split into burning debris after impact.',
          Icons.volcano,
          ['METEOR', 'CLUSTER', 'BURN', 'LAVA'],
        ),
        'Lightning' => (
          'Fork lattice',
          '$species turns the strike into a bouncing lightning lattice that chains through the pack.',
          Icons.flash_on,
          ['METEOR', 'BOUNCE', 'CHAIN', 'LIGHTNING'],
        ),
        'Water' => (
          'Undertow jaws',
          '$species opens water jaws that collapse inward on enemies and restore ship health.',
          Icons.water,
          ['METEOR', 'COLLAPSE', 'HEAL', 'WATER'],
        ),
        'Ice' => (
          'Comet splinters',
          '$species sends heavy snaring ice lances and guided splinters after the meteor.',
          Icons.ac_unit,
          ['METEOR', 'SNARE', 'SPLINTERS', 'ICE'],
        ),
        'Steam' => (
          'Pressure wall',
          '$species establishes a steam wall, then launches cutter shots outward from that wall.',
          Icons.blur_on,
          ['METEOR', 'WALL', 'CUTTERS', 'STEAM'],
        ),
        'Earth' => (
          'Moon drop',
          '$species drops a huge slow moon-like meteor and leaves lingering quake plates where it lands.',
          Icons.terrain,
          ['METEOR', 'HEAVY', 'QUAKE', 'EARTH'],
        ),
        'Mud' => (
          'Bog anchors',
          '$species drops bog anchors that heavily slow a lane before heavy slugs follow.',
          Icons.grain,
          ['METEOR', 'SLOW', 'SLUGS', 'MUD'],
        ),
        'Dust' => (
          'Sand front',
          '$species throws a wide bouncing sand front across the impact zone.',
          Icons.cloud,
          ['METEOR', 'BOUNCE', 'WIDE', 'DUST'],
        ),
        'Crystal' => (
          'Starfall shards',
          '$species launches homing crystal shards that ricochet and split.',
          Icons.diamond,
          ['METEOR', 'HOMING', 'CLUSTER', 'CRYSTAL'],
        ),
        'Air' => (
          'Wind orbit',
          '$species spins wind blades around the strike before releasing them outward.',
          Icons.air,
          ['METEOR', 'ORBIT', 'BLADES', 'AIR'],
        ),
        'Plant' => (
          'Vine pods',
          '$species sends seeking vine pods after the strike, and the pods snare enemies while they move.',
          Icons.local_florist,
          ['METEOR', 'SEEK', 'SNARE', 'PLANT'],
        ),
        'Poison' => (
          'Toxic bulbs',
          '$species plants toxic bulbs that slow a lane, then releases guided poison seeds.',
          Icons.biotech,
          ['METEOR', 'POISON', 'SEEDS', 'VENOM'],
        ),
        'Spirit' => (
          'Phantom staging',
          '$species stages orbiting phantoms around the meteor before they seek targets.',
          Icons.auto_awesome,
          ['METEOR', 'ORBIT', 'SEEK', 'SPIRIT'],
        ),
        'Dark' => (
          'Void wells',
          '$species punches rupture lances forward, then opens taunting void wells.',
          Icons.dark_mode,
          ['METEOR', 'TAUNT', 'VOID', 'DARK'],
        ),
        'Light' => (
          'Celestial crown',
          '$species crowns the impact with guided motes, execute-style finishers, and ship healing.',
          Icons.wb_sunny,
          ['METEOR', 'MOTES', 'SUSTAIN', 'LIGHT'],
        ),
        'Blood' => (
          'Transfusion orbs',
          '$species releases heavy homing blood orbs and heals from the meteor impact.',
          Icons.bloodtype,
          ['METEOR', 'HOMING', 'HEAL', 'BLOOD'],
        ),
        _ => null,
      };
      break;
    case 'pip':
      data = switch (element) {
        'Fire' => (
          'Overheat flurry',
          '$species fires a quick ricochet flurry and briefly speeds up basic attacks.',
          Icons.local_fire_department,
          ['TEMPO', 'HASTE', 'RICOCHET', 'FIRE'],
        ),
        'Lava' => (
          'Heavy magma chain',
          '$species launches slow heavy piercing magma chunks that hit fewer targets harder.',
          Icons.volcano,
          ['TEMPO', 'HEAVY', 'PIERCE', 'LAVA'],
        ),
        'Lightning' => (
          'Thunder chain',
          '$species fires the fastest ricochet chain volley, bouncing rapidly between nearby enemies.',
          Icons.flash_on,
          ['TEMPO', 'CHAIN', 'RICOCHET', 'LIGHTNING'],
        ),
        'Water' => (
          'Curling tide',
          '$species opens inward curling darts that collapse back through a target lane.',
          Icons.water,
          ['TEMPO', 'COLLAPSE', 'DARTS', 'WATER'],
        ),
        'Ice' => (
          'Chill chase',
          '$species sends chill darts that chase enemies and snare them on contact.',
          Icons.ac_unit,
          ['TEMPO', 'SNARE', 'CHASE', 'ICE'],
        ),
        'Steam' => (
          'Vent cutters',
          '$species vents short piercing cutter darts through the forward lane.',
          Icons.blur_on,
          ['TEMPO', 'CUTTERS', 'PIERCE', 'STEAM'],
        ),
        'Earth' => (
          'Stone finisher',
          '$species fires fewer heavier homing stone darts that hit durable targets harder.',
          Icons.terrain,
          ['TEMPO', 'HOMING', 'FINISHER', 'EARTH'],
        ),
        'Mud' => (
          'Sticky rebound',
          '$species launches sticky rebound slugs that slow enemies while chasing them.',
          Icons.grain,
          ['TEMPO', 'SLOW', 'REBOUND', 'MUD'],
        ),
        'Dust' => (
          'Sand spray',
          '$species sprays many tiny sand darts across a wide area.',
          Icons.cloud,
          ['TEMPO', 'SPRAY', 'CLEANUP', 'DUST'],
        ),
        'Crystal' => (
          'Prism bank-shot',
          '$species fires piercing prism darts with the strongest bank-shot behavior.',
          Icons.diamond,
          ['TEMPO', 'PIERCE', 'BANK', 'CRYSTAL'],
        ),
        'Air' => (
          'Cyclone rebound',
          '$species throws non-homing wind darts that rely on rebound movement instead of lock-on.',
          Icons.air,
          ['TEMPO', 'REBOUND', 'WIND', 'AIR'],
        ),
        'Plant' => (
          'Thorn pursuit',
          '$species fires vine darts that pierce and lightly snare moving targets.',
          Icons.local_florist,
          ['TEMPO', 'SNARE', 'PIERCE', 'PLANT'],
        ),
        'Poison' => (
          'Venom tags',
          '$species fires venom tag darts that slow enemies as they move and leaves no static residue field.',
          Icons.biotech,
          ['TEMPO', 'POISON', 'SLOW', 'VENOM'],
        ),
        'Spirit' => (
          'Phase chase',
          '$species uses high-guidance phase darts that pierce and reacquire targets.',
          Icons.auto_awesome,
          ['TEMPO', 'HOMING', 'PIERCE', 'SPIRIT'],
        ),
        'Dark' => (
          'Shadow pursuit',
          '$species fires tight piercing shadow darts that chase and finish weakened targets.',
          Icons.dark_mode,
          ['TEMPO', 'PIERCE', 'FINISHER', 'DARK'],
        ),
        'Light' => (
          'Halo rebound',
          '$species forms a halo of ricochet darts that can intercept threats as it cleans up.',
          Icons.wb_sunny,
          ['TEMPO', 'RICOCHET', 'INTERCEPT', 'LIGHT'],
        ),
        'Blood' => (
          'Crimson finish',
          '$species sends fewer heavy homing blood darts that focus one target at a time.',
          Icons.bloodtype,
          ['TEMPO', 'HOMING', 'FINISHER', 'BLOOD'],
        ),
        _ => null,
      };
      break;
    case 'mask':
      data = switch (element) {
        'Fire' => (
          'Inferno bait',
          '$species skips durable decoys and instead releases fast fire seekers from the trap.',
          Icons.local_fire_department,
          ['TRAP', 'SEEKERS', 'BURST', 'FIRE'],
        ),
        'Lava' => (
          'Volatile idol',
          '$species drops volatile idols that pull attention before erupting into heavy molten bursts.',
          Icons.volcano,
          ['TRAP', 'TAUNT', 'BURST', 'LAVA'],
        ),
        'Lightning' => (
          'Tesla scramble',
          '$species turns the trap into a tesla chain with fast bouncing seekers for clustered enemies.',
          Icons.flash_on,
          ['TRAP', 'BOUNCE', 'CHAIN', 'LIGHTNING'],
        ),
        'Water' => (
          'Bubble decoy',
          '$species uses bubble decoys to pull enemy aggro away from the ship, then fires guided water splashes.',
          Icons.water,
          ['TRAP', 'DECOY', 'SPLASH', 'WATER'],
        ),
        'Ice' => (
          'Frost lure',
          '$species traps enemies in freezing lures, then follows with slow heavy shards.',
          Icons.ac_unit,
          ['TRAP', 'FREEZE', 'SHARDS', 'ICE'],
        ),
        'Steam' => (
          'Pressure lure',
          '$species places slow steam vents around the trap instead of sending a large seeker swarm.',
          Icons.blur_on,
          ['TRAP', 'VENTS', 'SLOW', 'STEAM'],
        ),
        'Earth' => (
          'Monolith lure',
          '$species uses the toughest monolith lure, taunting enemies before breaking into boulder punishment.',
          Icons.terrain,
          ['TRAP', 'TAUNT', 'BOULDER', 'EARTH'],
        ),
        'Mud' => (
          'Bog snare',
          '$species snares enemies in a bog trap, then damages enemies caught trying to leave it.',
          Icons.grain,
          ['TRAP', 'SNARE', 'CONTROL', 'MUD'],
        ),
        'Dust' => (
          'Caltrop scatter',
          '$species scatters caltrop motes and fast ricochets from the trap point.',
          Icons.cloud,
          ['TRAP', 'RICOCHET', 'DISRUPT', 'DUST'],
        ),
        'Crystal' => (
          'Prism decoy',
          '$species uses prism decoys and bouncing shards to punish enemies that take the bait.',
          Icons.diamond,
          ['TRAP', 'DECOY', 'BOUNCE', 'CRYSTAL'],
        ),
        'Air' => (
          'Gust lure',
          '$species uses gust lures to break formation, then dives wind blades onto displaced enemies.',
          Icons.air,
          ['TRAP', 'GUST', 'DISPLACE', 'AIR'],
        ),
        'Plant' => (
          'Vine construct',
          '$species grows vine constructs that taunt enemies before thorn pods punish the cluster.',
          Icons.local_florist,
          ['TRAP', 'TAUNT', 'THORNS', 'PLANT'],
        ),
        'Poison' => (
          'Contamination grid',
          '$species establishes contamination traps first, then sends guided toxins through slowed targets.',
          Icons.biotech,
          ['TRAP', 'POISON', 'GUIDED', 'VENOM'],
        ),
        'Spirit' => (
          'Phantom lure',
          '$species sends phantom lures and phase seekers, splitting enemy attention across several false targets.',
          Icons.auto_awesome,
          ['TRAP', 'DECOY', 'SEEKERS', 'SPIRIT'],
        ),
        'Dark' => (
          'Void well',
          '$species builds a void well that pulls enemies into a snaring lure before execution seekers arrive.',
          Icons.dark_mode,
          ['TRAP', 'PULL', 'EXECUTE', 'DARK'],
        ),
        'Light' => (
          'Beacon decoy',
          '$species creates beacon decoys that draw aggro, then releases ricochet light motes.',
          Icons.wb_sunny,
          ['TRAP', 'DECOY', 'RICOCHET', 'LIGHT'],
        ),
        'Blood' => (
          'Blood obelisk',
          '$species plants a tougher obelisk lure backed by fewer, heavier blood punishers.',
          Icons.bloodtype,
          ['TRAP', 'TAUNT', 'HEAVY', 'BLOOD'],
        ),
        _ => null,
      };
      break;
    case 'kin':
      data = switch (element) {
        'Fire' => (
          'Ember guardians',
          '$species creates guardian embers that move forward and fire rapid turret shots.',
          Icons.local_fire_department,
          ['BLESS', 'GUARDIAN', 'TURRET', 'FIRE'],
        ),
        'Lava' => (
          'Heavy guardians',
          '$species deploys slower volcanic guardians with bigger impact shots.',
          Icons.volcano,
          ['BLESS', 'GUARDIAN', 'HEAVY', 'LAVA'],
        ),
        'Lightning' => (
          'Spark guardians',
          '$species creates fast guardian sparks that fire turret shots more frequently.',
          Icons.flash_on,
          ['BLESS', 'GUARDIAN', 'FAST', 'LIGHTNING'],
        ),
        'Water' => (
          'Escort fountain',
          '$species keeps wards near the ship that heal, intercept threats, and fire small turret shots.',
          Icons.water,
          ['BLESS', 'HEAL', 'ESCORT', 'WATER'],
        ),
        'Ice' => (
          'Chill guardians',
          '$species places chill guardians that slow a target area and fire slow shots.',
          Icons.ac_unit,
          ['BLESS', 'SLOW', 'CONTROL', 'ICE'],
        ),
        'Steam' => (
          'Pressure decoys',
          '$species creates steam decoys that hard-snare enemies while venting small turret shots.',
          Icons.blur_on,
          ['BLESS', 'SNARE', 'DECOY', 'STEAM'],
        ),
        'Earth' => (
          'Stone guardians',
          '$species sends sturdy guardian stones forward as taunting decoys that intercept threats and fire slow turret shots.',
          Icons.terrain,
          ['BLESS', 'TAUNT', 'INTERCEPT', 'EARTH'],
        ),
        'Mud' => (
          'Bog guardians',
          '$species creates forward bog guardians that taunt and slow enemies for a longer duration.',
          Icons.grain,
          ['BLESS', 'TAUNT', 'SLOW', 'MUD'],
        ),
        'Dust' => (
          'Distraction motes',
          '$species sends lightweight distraction guardians that disrupt and pepper the target area.',
          Icons.cloud,
          ['BLESS', 'DISRUPT', 'MOTES', 'DUST'],
        ),
        'Crystal' => (
          'Prism sentries',
          '$species deploys ship-escort sentries that pierce and fire from orbit while adding a small ship heal.',
          Icons.diamond,
          ['BLESS', 'ESCORT', 'SENTRY', 'CRYSTAL'],
        ),
        'Air' => (
          'Wind decoys',
          '$species transfers wind decoys to the fight, taunting and snaring enemies away from the ship.',
          Icons.air,
          ['BLESS', 'TAUNT', 'PEEL', 'AIR'],
        ),
        'Plant' => (
          'Vine guardians',
          '$species grows vine guardians that taunt, lightly snare, and fire guided support thorns.',
          Icons.local_florist,
          ['BLESS', 'TAUNT', 'THORNS', 'PLANT'],
        ),
        'Poison' => (
          'Toxin guardians',
          '$species sets contamination guardians that slow an area and feed guided toxin shots.',
          Icons.biotech,
          ['BLESS', 'POISON', 'SLOW', 'VENOM'],
        ),
        'Spirit' => (
          'Phase guardians',
          '$species sends piercing phase guardians with strong homing support fire.',
          Icons.auto_awesome,
          ['BLESS', 'PIERCE', 'HOMING', 'SPIRIT'],
        ),
        'Dark' => (
          'Eclipse hunters',
          '$species leans into offensive guardian hunters that transfer to the fight and fire high-guidance shots.',
          Icons.dark_mode,
          ['BLESS', 'HUNTER', 'HOMING', 'DARK'],
        ),
        'Light' => (
          'Pure escort',
          '$species is the pure guardian escort: long ship-orbiting wards that intercept threats and provide the strongest healing.',
          Icons.wb_sunny,
          ['BLESS', 'HEAL', 'INTERCEPT', 'LIGHT'],
        ),
        'Blood' => (
          'Sustain guardians',
          '$species creates blood guardians that taunt enemies, fire piercing shots, and support self-heal.',
          Icons.bloodtype,
          ['BLESS', 'HEAL', 'TAUNT', 'BLOOD'],
        ),
        _ => null,
      };
      break;
    case 'mystic':
      data = switch (element) {
        'Fire' => (
          'Supernova collapse',
          '$species erupts an outward fire-orb procession, then collapses it inward around a massive splitting core.',
          Icons.local_fire_department,
          ['ULTIMATE', 'COLLAPSE', 'CLUSTER', 'FIRE'],
        ),
        'Lava' => (
          'Cataclysm moons',
          '$species launches massive slow molten moons that pierce, leave lava trails, and split on impact.',
          Icons.volcano,
          ['ULTIMATE', 'PIERCE', 'TRAIL', 'LAVA'],
        ),
        'Lightning' => (
          'Storm lattice',
          '$species fills the fight with rapid zigzag bolts that bounce and chain through grouped enemies.',
          Icons.flash_on,
          ['ULTIMATE', 'BOUNCE', 'CHAIN', 'LIGHTNING'],
        ),
        'Water' => (
          'Tidal crescent',
          '$species sweeps crescent waves from both flanks so the tide collapses inward on the target.',
          Icons.water,
          ['ULTIMATE', 'PINCER', 'HOMING', 'WATER'],
        ),
        'Ice' => (
          'Glacier crown',
          '$species forms orbiting ice pillars as a barrier, then launches them outward as splitting frost lances.',
          Icons.ac_unit,
          ['ULTIMATE', 'BARRIER', 'LANCES', 'ICE'],
        ),
        'Steam' => (
          'Whiteout veil',
          '$species lays down a fog snare field with orbiting turret orbs that keep firing inside the whiteout.',
          Icons.blur_on,
          ['ULTIMATE', 'SNARE', 'TURRET', 'STEAM'],
        ),
        'Earth' => (
          'Monolith constellation',
          '$species summons orbiting stone pillars that taunt enemies, soak hits, and explode into shrapnel.',
          Icons.terrain,
          ['ULTIMATE', 'TAUNT', 'DECOY', 'EARTH'],
        ),
        'Mud' => (
          'Mire eclipse',
          '$species locks the target area in a huge snare zone, then sends piercing homing mud slugs through it.',
          Icons.grain,
          ['ULTIMATE', 'SNARE', 'PIERCE', 'MUD'],
        ),
        'Dust' => (
          'Sirocco halo',
          '$species unleashes a golden spiral swarm of tiny bouncing projectiles that hit groups of enemies.',
          Icons.cloud,
          ['ULTIMATE', 'SWARM', 'BOUNCE', 'DUST'],
        ),
        'Crystal' => (
          'Prism cathedral',
          '$species fires prism shards that pierce, bounce, and split into chain-reaction crystal fragments.',
          Icons.diamond,
          ['ULTIMATE', 'PIERCE', 'CLUSTER', 'CRYSTAL'],
        ),
        'Air' => (
          'Cyclone halo',
          '$species wraps the ship in interceptor orbs that block projectiles and damage enemies on contact.',
          Icons.air,
          ['ULTIMATE', 'INTERCEPT', 'ORBIT', 'AIR'],
        ),
        'Plant' => (
          'Verdant procession',
          '$species plants a line of vine turrets toward the target, creating a sustained thorn-fire lane.',
          Icons.local_florist,
          ['ULTIMATE', 'TURRET', 'THORNS', 'PLANT'],
        ),
        'Poison' => (
          'Venom halo',
          '$species deploys ship-following poison clouds that snare enemies and leave toxic trails.',
          Icons.biotech,
          ['ULTIMATE', 'POISON', 'TRAIL', 'VENOM'],
        ),
        'Spirit' => (
          'Wraith chorus',
          '$species launches piercing ghost bolts that strongly home onto enemies.',
          Icons.auto_awesome,
          ['ULTIMATE', 'HOMING', 'PIERCE', 'SPIRIT'],
        ),
        'Dark' => (
          'Eclipse procession',
          '$species opens dark wells that pull enemies inward and releases hunters that chase them.',
          Icons.dark_mode,
          ['ULTIMATE', 'PULL', 'HUNTER', 'DARK'],
        ),
        'Light' => (
          'Radiant crown',
          '$species crowns the ship with radiant protection, healing, and threat interception.',
          Icons.wb_sunny,
          ['ULTIMATE', 'HEAL', 'INTERCEPT', 'LIGHT'],
        ),
        'Blood' => (
          'Crimson coronation',
          '$species creates a blood field that heals while enemies are trapped inside it.',
          Icons.bloodtype,
          ['ULTIMATE', 'HEAL', 'SUSTAIN', 'BLOOD'],
        ),
        _ => null,
      };
      break;
  }

  if (data == null) return null;
  return CosmicSpecialInfo(
    subtitle: '$abilityName • ${data.$1}',
    description: data.$2,
    icon: data.$3,
    tags: data.$4,
  );
}

/// Returns only mode-specific mechanics that differ in Cosmic Survival.
/// Baseline species mechanics belong in the main special description.
_ElementMechanicNote? _elementMechanicNote(String family, String element) {
  switch (family) {
    case 'Pip':
      switch (element) {
        case 'Plant':
          return _survivalPassive(
            'Killed enemies grant +50% alchemy meter on death.',
          );
      }
      return null;
    case 'Wing':
      switch (element) {
        case 'Plant':
          return _survivalPassive(
            'Beam-killed enemies leave flower pickups; orb collects them to permanently power up the beam (+4% damage per flower, capped at +200%).',
          );
        case 'Earth':
          return _survivalPassive(
            'The orb co-fires its own mirror beam alongside the wing: two lasers at once.',
          );
      }
      return null;
  }
  return null;
}

CosmicSpecialInfo cosmicFamilySpecialInfo(String family, String element) {
  final speciesInfo = _speciesSpecificCosmicSpecialInfo(family, element);
  if (speciesInfo != null) return speciesInfo;

  switch (family) {
    case 'Horn':
      final anchorElement = [
        'Earth',
        'Lava',
        'Mud',
        'Ice',
        'Steam',
      ].contains(element);
      final interceptElement = [
        'Light',
        'Crystal',
        'Lightning',
        'Air',
      ].contains(element);
      final sustainElement = ['Water', 'Blood'].contains(element);
      final followThrough = switch (element) {
        'Fire' =>
          'Fire is a fast blaze ram that over-commits through the target lane, leaving a burning wake instead of a wall.',
        'Lava' =>
          'Lava is a slow molten plow whose boulders leave magma trails and split into slag after impact.',
        'Lightning' =>
          'Lightning trades shield size for the quickest snap-charge and bouncing parry rods.',
        'Water' =>
          'Water uses a medium surf shove with a wider finishing crash and a small ship heal.',
        'Ice' =>
          'Ice lumbers in with a broad glacial body-check and plants one of the hardest frontal slows.',
        'Steam' =>
          'Steam pops forward with a pressure-burst charge, then leaves taunting vents that keep firing pressure puffs.',
        'Earth' =>
          'Earth is the fortress variant: the slowest, widest charge, ending in taunting stone bulwarks that can break apart.',
        'Mud' =>
          'Mud drags a wide, short charge through the lane with crawling sludge that leaves slow trails.',
        'Dust' =>
          'Dust is a long skitter-charge with low shield, narrow contact, and quick disruption.',
        'Crystal' =>
          'Crystal takes a measured guard step, then spins orbiting mirror plates that intercept and refract hits.',
        'Air' =>
          'Air is the longest gale dash, cutting through the lane with light interception and peel.',
        'Plant' =>
          'Plant advances slowly and roots a thorn hedge that acts like a short-lived turret line.',
        'Poison' =>
          'Poison makes a guarded venom shove, leaving fangs and toxic choke points where it lands.',
        'Spirit' =>
          'Spirit phase-slips farther through the target and leaves guarded plates in the impact lane.',
        'Dark' =>
          'Dark is a sharp execution ram: quick, narrow, and built to taunt enemies into a tight kill lane.',
        'Light' =>
          'Light takes a short guardian step and plants wide radiant ward plates for parries, lane control, and ship healing.',
        'Blood' =>
          'Blood is a heavy sustain body-slam, converting a short crash into self-heal and blood bulwarks.',
        _ =>
          'Element changes how the Horn protects the front line after impact.',
      };
      return CosmicSpecialInfo(
        subtitle: 'Shield Charge • Frontline impact',
        description:
            'Raises a shield, erupts with an elemental guard burst, then '
            'commits to a real impact charge. $followThrough',
        icon: Icons.shield,
        tags: [
          'SHIELD',
          'CHARGE',
          if (anchorElement) 'ANCHOR',
          if (interceptElement) 'INTERCEPT',
          if (sustainElement) 'SUSTAIN',
          element.toUpperCase(),
        ],
      );
    case 'Wing':
      final hasTrail = ['Lava', 'Fire', 'Plant'].contains(element);
      final hunterElement = [
        'Crystal',
        'Water',
        'Ice',
        'Dark',
        'Blood',
        'Steam',
        'Mud',
        'Plant',
        'Poison',
        'Spirit',
        'Light',
      ].contains(element);
      final heavyElement = ['Earth', 'Lava', 'Mud'].contains(element);
      final followThrough = switch (element) {
        'Lightning' =>
          'Lightning charges briefly, then releases a heavy blast through the beam lane.',
        'Crystal' =>
          'Crystal turns beam contact into sustain while refracting prism pressure.',
        'Fire' => 'Fire widens into a sweeping inferno ring and burning trail.',
        'Ice' =>
          'Ice builds frost on sustained contact until targets snap into a hard freeze.',
        'Dark' =>
          'Dark doubles the tempo: basic attacks and beam pulses fire twice as fast.',
        'Blood' =>
          'Blood hunts the lowest-HP target and executes enemies below the threshold.',
        'Water' =>
          'Water heals allies and the ship while still cutting through enemies.',
        'Lava' =>
          'Lava scars the ground with lingering burn zones along the beam path.',
        'Steam' =>
          'Steam executes the first target it catches, then erupts into lingering steam clouds.',
        'Earth' =>
          'Earth trades speed for a few enormous boulder beams with the widest body.',
        'Mud' => 'Mud applies a long heavy slow to anything held in the beam.',
        'Dust' => 'Dust sandblasts the lane and disrupts enemy pressure.',
        'Air' =>
          'Air drills forward with wind pressure that knocks enemies back.',
        'Plant' =>
          'Plant grows guided vine tendrils from the beam for pursuit pressure.',
        'Poison' =>
          'Poison forms a venom ring around the caster for close-range area control.',
        'Spirit' =>
          'Spirit tethers through the ship, letting the ship fire the follow-up laser.',
        'Light' =>
          'Light refracts beam kills into smaller hunting beams for cleanup.',
        _ =>
          'Element determines the beam follow-through: chains, refractions, hunters, or scatter effects.',
      };
      return CosmicSpecialInfo(
        subtitle: 'Piercing Beam • Long-range line attack',
        description:
            'A long-range line special for piercing packs and pressuring bosses. '
            '${hasTrail ? 'Leaves a lingering $element damage trail behind the beam. ' : ''}'
            '$followThrough',
        icon: Icons.arrow_forward,
        tags: [
          'PIERCING',
          'BEAM',
          if (hasTrail) 'TRAIL',
          if (hunterElement) 'HUNTER',
          if (heavyElement) 'HEAVY',
          element.toUpperCase(),
        ],
      );
    case 'Let':
      final hasCluster = [
        'Crystal',
        'Dust',
        'Ice',
        'Water',
        'Lava',
        'Air',
      ].contains(element);
      final fieldElement = [
        'Earth',
        'Steam',
        'Mud',
        'Poison',
        'Dark',
      ].contains(element);
      final followThrough = switch (element) {
        'Fire' =>
          'Fire follows with fast ember lances instead of lingering residue.',
        'Lightning' => 'Lightning builds a fork lattice with bouncing arcs.',
        'Ice' => 'Ice sends heavy snaring lances and guided splinters.',
        'Earth' =>
          'Earth trades speed for a huge moon-drop and lingering quake plates.',
        'Spirit' => 'Spirit stages orbiting phantoms before they seek targets.',
        'Poison' =>
          'Poison plants toxic bulbs that slow a lane, then releases guided seeds.',
        'Water' =>
          'Water opens undertow jaws that collapse inward and help stabilize the ship.',
        'Lava' =>
          'Lava throws slow massive magma chunks that split into debris.',
        'Steam' =>
          'Steam establishes a pressure wall, then peels cutters away from it.',
        'Mud' =>
          'Mud drops bog anchors that heavily slow a lane before heavy slugs follow.',
        'Dust' =>
          'Dust throws a wide bouncing sand front across the impact zone.',
        'Crystal' => 'Crystal launches homing shards that ricochet and split.',
        'Air' =>
          'Air spins wind blades around the strike before releasing them.',
        'Plant' => 'Plant sends seeking vine pods with moving snare pressure.',
        'Blood' =>
          'Blood releases heavy homing orbs and converts impact into sustain.',
        'Dark' =>
          'Dark punches rupture lances forward, then opens taunting void wells.',
        'Light' =>
          'Light crowns the impact with guided motes, finishers, and ship sustain.',
        _ => 'Element determines the follow-through pattern after impact.',
      };
      return CosmicSpecialInfo(
        subtitle: 'Meteor Strike • Siege follow-through',
        description:
            'A heavy siege cast that lands on the target area, then turns the lane into an elemental problem. '
            '${hasCluster ? 'The meteor fragments mid-flight, splitting into sub-projectiles. ' : ''}'
            '$followThrough',
        icon: Icons.south,
        tags: [
          'METEOR',
          'IMPACT',
          fieldElement ? 'FIELD' : 'SIEGE',
          if (hasCluster) 'CLUSTER',
          element.toUpperCase(),
        ],
      );
    case 'Pip':
      final reboundElement = [
        'Crystal',
        'Lightning',
        'Air',
        'Fire',
        'Water',
        'Ice',
        'Dust',
        'Light',
      ].contains(element);
      final snareElement = ['Ice', 'Mud', 'Plant', 'Poison'].contains(element);
      final heavyElement = [
        'Earth',
        'Lava',
        'Dark',
        'Blood',
        'Spirit',
      ].contains(element);
      final followThrough = switch (element) {
        'Fire' =>
          'Fire becomes an overheat flurry that also briefly speeds up basic attacks.',
        'Lightning' =>
          'Lightning is the fastest chain volley, built for rapid ricochet cleanup.',
        'Air' =>
          'Air throws non-homing wind darts that rely on rebound movement instead of lock-on.',
        'Dust' =>
          'Dust sprays many tiny sand darts for wide cleanup across messy packs.',
        'Crystal' =>
          'Crystal fires piercing prism darts with the strongest bank-shot behavior.',
        'Light' =>
          'Light forms a halo of ricochet darts that can intercept threats as it cleans up.',
        'Water' =>
          'Water opens inward curling darts that collapse back through a target lane.',
        'Ice' =>
          'Ice sends chill darts with moving snare pressure for catching leaks.',
        'Mud' =>
          'Mud launches sticky rebound slugs that slow enemies while chasing them.',
        'Plant' =>
          'Plant fires vine darts that pierce and lightly snare moving targets.',
        'Poison' =>
          'Poison uses venom tag darts with moving slow pressure, without leaving residue fields.',
        'Earth' =>
          'Earth trades volume for heavier homing stone darts that finish sturdy targets.',
        'Lava' =>
          'Lava launches slow, heavy piercing chunks for high-value cleanup.',
        'Dark' => 'Dark fires tight piercing shadow darts for lethal pursuit.',
        'Blood' =>
          'Blood sends fewer heavy homing darts for focused finishing pressure.',
        'Spirit' =>
          'Spirit uses high-guidance phase darts that pierce and reacquire targets.',
        'Steam' =>
          'Steam vents short piercing cutter darts through the forward lane.',
        _ =>
          'Element determines the tempo pattern, target priority, and rebound behavior.',
      };
      return CosmicSpecialInfo(
        subtitle: 'Tempo Salvo • Fast skirmish special',
        description:
            'A quick cleanup special built for target hopping, leak control, and finishing scattered enemies. '
            '$followThrough',
        icon: Icons.bolt,
        tags: [
          reboundElement ? 'RICOCHET' : 'CHASE',
          if (snareElement) 'SNARE',
          if (heavyElement) 'FINISHER',
          'TEMPO',
          element.toUpperCase(),
        ],
      );
    case 'Mane':
      final maneInfo = switch (element) {
        'Air' => (
          'Gale Pierce • Push-through catapult',
          'Fires a wide piercing gust that shoves every enemy it passes through along the shot path.',
          Icons.air,
          ['PIERCE', 'PUSH', 'WIDE', 'AIR'],
        ),
        'Dust' => (
          'Dustwake Fan • Projectile silence',
          'Cuts a sand trail across the lane. Enemies that enter the dust cloud lose their ability to shoot for a moment.',
          Icons.cloud,
          ['TRAIL', 'SUPPRESS', 'PIERCE', 'DUST'],
        ),
        'Lava' => (
          'Molten Cleave • Burning residue',
          'Pierces through enemies and drops lava blobs at each collision, turning the path into lingering burn damage.',
          Icons.local_fire_department,
          ['BURN', 'BLOBS', 'PIERCE', 'LAVA'],
        ),
        'Poison' => (
          'Venom Edge • Stacking toxin',
          'Poisons every enemy the slash passes through. The more bodies it tags, the more the toxin pressure adds up.',
          Icons.biotech,
          ['POISON', 'STACKS', 'PIERCE', 'VENOM'],
        ),
        'Blood' => (
          'Bloodedge Rush • Lifesteal pierce',
          'Pierces through the lane and restores health for each enemy it cuts, making Bloodmane the sustain Mane.',
          Icons.bloodtype,
          ['HEAL', 'SUSTAIN', 'PIERCE', 'BLOOD'],
        ),
        'Earth' => (
          'Fault Slab • Grinding quake path',
          'Launches a huge slow stone slab that crushes through the lane and leaves quake bursts as it breaks apart.',
          Icons.terrain,
          ['SLAB', 'QUAKE', 'HEAVY', 'EARTH'],
        ),
        'Light' => (
          'Radiant Growth • Scaling pierce',
          'Launches a slow glowing orb that grows larger and hits harder each time it pierces an enemy.',
          Icons.wb_sunny,
          ['GROWTH', 'PIERCE', 'SCALING', 'LIGHT'],
        ),
        'Spirit' => (
          'Phaseblade Rush • Ramping stream',
          'Starts as one soul shot, then adds another shot on each cast up to ten before resetting into a new ramp.',
          Icons.auto_awesome,
          ['RAMP', 'STREAM', 'RESET', 'SPIRIT'],
        ),
        'Crystal' => (
          'Prism Edge • Boss shatter',
          'Pierces normally through packs, but detonates on bosses for a huge crystal burst and wide area damage.',
          Icons.diamond,
          ['BOSS', 'BURST', 'AOE', 'CRYSTAL'],
        ),
        'Fire' => (
          'Fireball Rush • Dense fire spread',
          'Throws a doubled wave of quick fireballs through the forward lane for immediate multi-hit pressure.',
          Icons.whatshot,
          ['FIREBALLS', 'MULTI', 'PIERCE', 'FIRE'],
        ),
        'Lightning' => (
          'Storm Orb Field • Remote zaps',
          'Shoots small lightning balls around the map. When they land, they form compact zap traps.',
          Icons.flash_on,
          ['ORBS', 'FIELD', 'ZAP', 'LIGHTNING'],
        ),
        'Steam' => (
          'Pressure Geyser • Traveling vent',
          'Launches a large geyser shot that releases damaging steam puffs as it travels.',
          Icons.blur_on,
          ['GEYSER', 'PUFFS', 'PIERCE', 'STEAM'],
        ),
        'Dark' => (
          'Voidcut Drive • Pull and consume',
          'Moves slowly through the lane, pulling enemies toward it and punishing weakened targets caught in the drag.',
          Icons.dark_mode,
          ['PULL', 'EXECUTE', 'SLOW', 'DARK'],
        ),
        'Ice' => (
          'Frostguard Cleave • Contact freeze',
          'A piercing frost ball freezes enemies it touches as it pushes through the lane.',
          Icons.ac_unit,
          ['FREEZE', 'PIERCE', 'CONTROL', 'ICE'],
        ),
        'Mud' => (
          'Bogbreaker Split • Ten-way burst',
          'The first enemy hit breaks the shot apart into ten mud shards that scatter in every direction.',
          Icons.grain,
          ['SPLIT', 'SHARDS', 'BURST', 'MUD'],
        ),
        'Plant' => (
          'Vine Lariat • Root bloom',
          'Roots every enemy it hits. If a rooted enemy dies, it bursts into plant area damage that can root nearby enemies too.',
          Icons.local_florist,
          ['ROOT', 'EXPLODE', 'AOE', 'PLANT'],
        ),
        'Water' => (
          'Tidewall Crash • Carrying wave',
          'Fires a massive water wall that drags enemies with it instead of merely damaging them.',
          Icons.water,
          ['WALL', 'CARRY', 'PIERCE', 'WATER'],
        ),
        _ => (
          'Barrage Volley • Piercing technique',
          'Fires a piercing Mane technique with an element-specific combat rule.',
          Icons.waves,
          ['PIERCE', 'BARRAGE', element.toUpperCase()],
        ),
      };
      return CosmicSpecialInfo(
        subtitle: maneInfo.$1,
        description: maneInfo.$2,
        icon: maneInfo.$3,
        tags: maneInfo.$4,
      );
    case 'Mask':
      final decoyElement = [
        'Earth',
        'Lava',
        'Crystal',
        'Spirit',
        'Dark',
        'Water',
        'Ice',
        'Plant',
        'Light',
        'Blood',
      ].contains(element);
      final snareElement = [
        'Dark',
        'Mud',
        'Steam',
        'Poison',
        'Air',
        'Ice',
      ].contains(element);
      final reboundElement = [
        'Lightning',
        'Dust',
        'Crystal',
        'Light',
      ].contains(element);
      final followThrough = switch (element) {
        'Earth' =>
          'Earth uses the toughest monolith lure: it taunts, soaks hits, then breaks into a boulder punishment.',
        'Lava' =>
          'Lava drops volatile idols that drag attention before erupting into heavy molten bursts.',
        'Crystal' =>
          'Crystal uses prism decoys and bouncing shards to punish enemies that take the bait.',
        'Spirit' =>
          'Spirit sends phantom lures and phase seekers, splitting attention across several false targets.',
        'Dark' =>
          'Dark builds the strongest void well, pulling enemies into a snaring lure before execution pressure arrives.',
        'Water' =>
          'Water uses bubble decoys and guided splashes to pull pressure away from the ship.',
        'Ice' =>
          'Ice traps enemies in freezing lures, then follows with slow heavy shards.',
        'Plant' =>
          'Plant grows vine constructs that taunt enemies before thorn pods punish the cluster.',
        'Light' =>
          'Light creates beacon decoys and ricochet motes, a cleaner defensive misdirection pattern.',
        'Blood' =>
          'Blood plants a tougher obelisk lure backed by fewer, heavier blood punishers.',
        'Fire' =>
          'Fire skips durable decoys for an inferno bait burst: many fast seekers punish anything that turns toward the trap.',
        'Lightning' =>
          'Lightning turns the trap into a tesla chain, using fast bouncing seekers to scramble clustered enemies.',
        'Steam' =>
          'Steam relies more on pressure traps and slow vents than on raw seeker volume.',
        'Mud' =>
          'Mud is the bog-control trap, locking movement first and punishing escape attempts second.',
        'Dust' =>
          'Dust scatters caltrop motes, using fast ricochets to break enemy formation.',
        'Poison' =>
          'Poison establishes contamination traps first, then sends guided toxins through slowed targets.',
        'Air' =>
          'Air uses gust lures to break formation, then dives wind blades onto displaced enemies.',
        _ =>
          'Element changes the bait pattern, trap pressure, and punishment style.',
      };
      return CosmicSpecialInfo(
        subtitle: decoyElement
            ? 'Decoy Totem • Control setup'
            : 'Seeker Swarm • Control setup',
        description:
            'Deploys $element misdirection pieces that make enemies choose bad '
            'targets, bad paths, or bad timing. $followThrough',
        icon: decoyElement ? Icons.sports_kabaddi : Icons.warning_amber,
        tags: [
          decoyElement ? 'DECOY' : 'SEEKERS',
          if (snareElement) 'SNARE',
          if (reboundElement) 'REBOUND',
          decoyElement ? 'TAUNT' : 'CONTROL',
          decoyElement ? 'EXPLODES' : 'REDIRECT',
          element.toUpperCase(),
        ],
      );
    case 'Kin':
      final escortElement = ['Light', 'Water', 'Crystal'].contains(element);
      final controlElement = [
        'Air',
        'Ice',
        'Steam',
        'Earth',
        'Mud',
        'Plant',
        'Poison',
      ].contains(element);
      final pressureElement = [
        'Dark',
        'Fire',
        'Lightning',
        'Spirit',
        'Lava',
        'Blood',
        'Dust',
      ].contains(element);
      final followThrough = switch (element) {
        'Light' =>
          'Light is the pure guardian escort: long ship-orbiting wards '
              'that intercept threats and provide the strongest healing.',
        'Water' =>
          'Water keeps escort wards near the ship, adding steady healing, '
              'interception, and soft turret pressure.',
        'Crystal' =>
          'Crystal deploys ship escort sentries that pierce and fire from '
              'orbit while adding a small ship heal.',
        'Air' =>
          'Air transfers wind decoys to the fight, taunting and snaring '
              'enemies away from the ship.',
        'Earth' =>
          'Earth sends sturdy guardian stones forward as taunting decoys '
              'with interception and slow turret pressure.',
        'Mud' =>
          'Mud creates forward bog guardians that taunt and slow enemies '
              'for a longer control window.',
        'Steam' =>
          'Steam creates pressure decoys that hard-snare enemies while '
              'venting small turret shots.',
        'Ice' =>
          'Ice places chill guardians that slow a target area and fire '
              'slower control shots.',
        'Plant' =>
          'Plant grows vine guardians that taunt, lightly snare, and fire '
              'guided support thorns.',
        'Poison' =>
          'Poison sets contamination guardians that slow an area and feed '
              'guided toxin shots.',
        'Spirit' =>
          'Spirit sends piercing phase guardians with strong homing support '
              'fire.',
        'Dark' =>
          'Dark leans into offensive guardian hunters, transferring to the '
              'fight and firing high-guidance shots.',
        'Fire' =>
          'Fire creates aggressive guardian embers that transfer forward '
              'and add rapid turret pressure.',
        'Lightning' =>
          'Lightning creates fast guardian sparks with high turret tempo.',
        'Lava' =>
          'Lava deploys slower heavy guardians with bigger impact shots.',
        'Blood' =>
          'Blood uses sustain guardians that taunt, pierce, and pressure '
              'while supporting self-heal.',
        'Dust' =>
          'Dust sends lightweight distraction guardians that disrupt and '
              'pepper the target area.',
        _ =>
          'Element changes whether the guardian pieces escort, intercept, '
              'taunt, snare, heal, or pressure enemies.',
      };
      return CosmicSpecialInfo(
        subtitle: 'Blessing Pulse • Guardian support',
        description:
            'A support cast that heals, blesses over time, and keeps guardian pieces active. '
            '$followThrough',
        icon: Icons.favorite,
        tags: [
          'HEAL',
          'BLESSING',
          if (escortElement) 'ESCORT',
          if (controlElement) 'CONTROL',
          if (pressureElement) 'PRESSURE',
          element.toUpperCase(),
        ],
      );
    case 'Mystic':
      final (subtitle, desc, tags) = switch (element) {
        'Fire' => (
          'Supernova Collapse • Beauty scales count • Long cooldown',
          'Erupts an expanding ring of fire orbs that orbit outward, then '
              'collapse inward with aggressive homing. A massive core orb '
              'detonates at the center, splitting into cluster fragments. '
              'Higher Beauty spawns more ring orbs for a bigger supernova.',
          ['BURST', 'CLUSTER', 'HOMING'],
        ),
        'Lava' => (
          'Cataclysm Moons • Strength scales count • Long cooldown',
          'Launches massive slow-moving piercing boulders that plow through '
              'everything in their path, leaving damaging lava trails and '
              'splitting into cluster detonations on impact. '
              'Higher Strength spawns more boulders.',
          ['PIERCING', 'TRAIL', 'CLUSTER'],
        ),
        'Lightning' => (
          'Storm Lattice • Intelligence scales count • Long cooldown',
          'Fires a fan of rapid zigzag bolts with extreme bounce counts that '
              'chain through groups of enemies. Short-lived but fills the '
              'screen with arcing electricity. '
              'Higher Intelligence spawns more bolts.',
          ['BOUNCE', 'CHAIN', 'HOMING'],
        ),
        'Water' => (
          'Tidal Crescent • Beauty scales count • Long cooldown',
          'Sweeps two crescent waves from both flanks that converge on the '
              'target in a pincer formation. Each wave projectile homes in and '
              'leaves trailing water damage. '
              'Higher Beauty adds more projectiles per wave.',
          ['HOMING', 'TRAIL', 'PINCER'],
        ),
        'Ice' => (
          'Glacier Crown • Intelligence scales count • Long cooldown',
          'Forms a crown of ice pillars orbiting the caster as a defensive '
              'barrier for 2 seconds, then launches them outward as piercing '
              'lances that split into frost clusters. '
              'Higher Intelligence adds more pillars.',
          ['PIERCING', 'CLUSTER', 'BARRIER'],
        ),
        'Steam' => (
          'Whiteout Veil • Intelligence scales count • Long cooldown',
          'Deploys a fog zone of stationary snare clouds that massively slow '
              'enemies, plus turret orbs that orbit inside the fog and fire '
              'homing shots. Area denial + sustained damage. '
              'Higher Intelligence adds more fog nodes and turrets.',
          ['SNARE', 'TURRET', 'AREA DENIAL'],
        ),
        'Earth' => (
          'Monolith Constellation • Strength scales count • Long cooldown',
          'Summons massive orbiting stone decoy pillars that taunt enemies '
              'away from you. When destroyed, each pillar explodes into a ring '
              'of shrapnel. A defensive powerhouse. '
              'Higher Strength summons more pillars.',
          ['DECOY', 'TAUNT', 'EXPLODES'],
        ),
        'Mud' => (
          'Mire Eclipse • Strength scales count • Long cooldown',
          'Creates a massive stationary snare zone at the target, then '
              'launches heavy homing mud slugs that pierce through enemies and '
              'leave persistent slowing trails. Locks down an area. '
              'Higher Strength sends more slugs.',
          ['SNARE', 'PIERCING', 'TRAIL'],
        ),
        'Dust' => (
          'Sirocco Halo • Beauty scales count • Long cooldown',
          'Unleashes a golden spiral swarm of tiny fast projectiles that '
              'bounce between enemies. Death by a thousand cuts — clears out '
              'groups of smaller enemies. '
              'Higher Beauty spawns a denser swarm.',
          ['SWARM', 'BOUNCE', 'HOMING'],
        ),
        'Crystal' => (
          'Prism Cathedral • Beauty scales count • Long cooldown',
          'Fires prismatic shards that pierce, bounce between enemies, and '
              'split into cluster fragments on each hit — creating chain '
              'reaction explosions that multiply through groups. '
              'Higher Beauty launches more shards.',
          ['PIERCING', 'BOUNCE', 'CLUSTER'],
        ),
        'Air' => (
          'Cyclone Halo • Intelligence scales count • Long cooldown',
          'Deploys a ship-following orbital ring of interceptor orbs that '
              'block enemy projectiles AND deal damage on contact. A defensive '
              'and offensive shield that moves with you. '
              'Higher Intelligence adds more interceptors.',
          ['INTERCEPT', 'ORBITAL', 'DEFENSE'],
        ),
        'Plant' => (
          'Verdant Procession • Strength scales count • Long cooldown',
          'Plants a line of vine turrets toward the target. Each turret fires '
              'homing thorns for the duration, creating a sustained DPS lane. '
              'Higher Strength plants more turrets.',
          ['TURRET', 'HOMING', 'SUSTAINED'],
        ),
        'Poison' => (
          'Venom Halo • Intelligence scales count • Long cooldown',
          'Deploys orbiting poison clouds that follow your ship, snaring '
              'enemies that pass through and leaving persistent toxic trails. '
              'An area denial ring that poisons everything nearby. '
              'Higher Intelligence adds more clouds.',
          ['SNARE', 'TRAIL', 'AREA DENIAL'],
        ),
        'Spirit' => (
          'Wraith Chorus • Intelligence scales count • Long cooldown',
          'Launches piercing ghost bolts with extreme homing that '
              'relentlessly chase targets through any obstacle, leaving '
              'spectral trails. Pure single-target hunter DPS. '
              'Higher Intelligence sends more wraiths.',
          ['PIERCING', 'HOMING', 'HUNTER'],
        ),
        'Dark' => (
          'Eclipse Procession • Strength scales count • Long cooldown',
          'Places stationary void wells that taunt enemies inward like '
              'gravitational traps, snare them in place, then detonate in '
              'massive cluster explosions. '
              'Higher Strength places more void wells.',
          ['TAUNT', 'SNARE', 'CLUSTER'],
        ),
        'Light' => (
          'Radiant Crown • Beauty scales count • Long cooldown',
          'Deploys ship-orbiting turret sentinels that auto-fire homing '
              'light bolts AND intercept incoming enemy projectiles. The '
              'ultimate defense + offense orbital. '
              'Higher Beauty adds more sentinels.',
          ['TURRET', 'INTERCEPT', 'ORBITAL'],
        ),
        'Blood' => (
          'Crimson Coronation • Strength scales count • Long cooldown',
          'Launches heavy homing blood orbs that split into clusters and '
              'leave crimson trails, while granting a massive self-heal and a '
              'blessing aura. Life-steal fantasy. '
              'Higher Strength launches more orbs.',
          ['HOMING', 'HEAL', 'BLESSING'],
        ),
        _ => (
          'Guardian Ultimate • Single-slot impact • Long cooldown',
          'Calls a $element guardian ultimate built for single-slot impact. '
              'Element decides whether it becomes a collapse, zone, sentinel '
              'ring, trap, turret lane, heavy projectile, or hunter swarm.',
          <String>['GUARDIAN', 'ULTIMATE'],
        ),
      };
      return CosmicSpecialInfo(
        subtitle: subtitle,
        description: desc,
        icon: Icons.auto_awesome,
        tags: [...tags, 'ULTIMATE', 'LONG CD', element.toUpperCase()],
      );
    default:
      return const CosmicSpecialInfo(
        subtitle: '30s cooldown',
        description:
            'Unleashes a burst of elemental energy at 2× damage. '
            'Cooldown is reduced by Speed.',
        icon: Icons.auto_awesome,
      );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPLORE STAT EFFECTS CARD
// ─────────────────────────────────────────────────────────────────────────────
/// Stat chips for the COSMIC tab — shows actual derived combat numbers
/// (HP, physical/elemental ATK + DEF, cooldown reduction, crit) the way
/// Boss tab shows its stat chips, so both tabs read like the same UI.
