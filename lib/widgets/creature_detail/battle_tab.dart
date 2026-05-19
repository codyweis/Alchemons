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
        border: Border(
          bottom: BorderSide(color: palette.lineSoft, width: 1),
        ),
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
    final special = _cosmicFamilySpecialInfo(family, element);
    final specialName = cosmicSpecialAbilityName(family, element);
    final survivalPassive = _survivalElementPassive(family, element);

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
          _BracketInfoCard(
            title: role.title,
            description: role.description,
          ),
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
            footerLabel: survivalPassive != null ? 'Survival passive' : null,
            footerBody: survivalPassive,
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
    this.footerLabel,
    this.footerBody,
  });

  final String title;
  final String? subtitle;
  final String description;
  final String? footerLabel;
  final String? footerBody;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    final theme = context.read<FactionTheme>();
    final activeAccent = bracketReadableAccent(theme);
    final footer = (footerLabel != null && footerBody != null)
        ? Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 10,
                      color: activeAccent,
                    ),
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
            Text(
              title,
              style: bracketText(
                context,
                16,
                palette.ink,
                weight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
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
        'Manes are offense-first barrage bruisers: they step up and fire active forward cut patterns instead of setting traps.',
        'They are best when paired with a true anchor behind them, because Mane wins by pressure cadence and lane carving, not by bunker control.',
      ]);
      final elementDetail = switch (normalizedElement) {
        'Water' =>
          'Water Mane uses dual crossing tide-cuts, creating an X-shaped pressure lane that slows pushes from two angles.',
        'Steam' =>
          'Steam Mane fires a two-beat sequence: fast openers followed by heavier delayed pressure cuts.',
        'Plant' =>
          'Plant Mane fires a core slash lane that forks into branch cuts, giving it a distinctive split-pressure rhythm.',
        'Poison' =>
          'Poison Mane leans into drifting venom slashes with longer duration and visible lane denial without becoming static.',
        'Crystal' =>
          'Crystal Mane is a disciplined 3-lance prism burst with refracted side follow-ups for precise pierce pressure.',
        'Blood' =>
          'Blood Mane uses two heavy spear-cuts plus a center finisher, with sustain tied into that focused burst.',
        'Dark' =>
          'Dark Mane is a narrow suppression package: fewer lanes, heavier cuts, stronger focused control.',
        'Earth' =>
          'Earth Mane advances with marching slab-cuts that stagger forward in sequence and hold lane leverage.',
        'Fire' =>
          'Fire Mane is a high-tempo advancing arc burst meant to shred regular waves before they settle.',
        'Lightning' =>
          'Lightning Mane emphasizes fast fork cuts with a guided center line for aggressive chase-through pressure.',
        'Air' =>
          'Air Mane is a wide split-sweep style with speed-first lane clear and high forward tempo.',
        'Dust' =>
          'Dust Mane throws the broadest fan pattern in the family, flooding lanes with rapid low-mass cuts.',
        'Ice' =>
          'Ice Mane favors heavier chill cleaves with firmer slowing follow-through in a tight frontal lane.',
        'Mud' =>
          'Mud Mane applies stumbling heavy cross-cuts that drag enemy movement while still pressing forward.',
        'Lava' =>
          'Lava Mane trades volume for hotter, heavier cleaves that spike frontline pressure.',
        'Spirit' =>
          'Spirit Mane keeps a disciplined barrage but threads a guided center finisher through it.',
        'Light' =>
          'Light Mane adds a disciplined parry-intercept line on top of forward pressure cuts.',
        _ =>
          '$normalizedElement Mane keeps the offense-first lane pressure pattern with an element-specific firing cadence.',
      };
      bullets.add(elementDetail);
      return _CosmicSurvivalNotes(
        summary:
            'Mane is an offense-first bruiser family in survival. It wins through active forward slash patterns and element-specific firing signatures rather than trap setups.',
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
class _CosmicSpecialInfo {
  final String subtitle;
  final String description;
  final IconData icon;
  final List<String> tags;
  const _CosmicSpecialInfo({
    required this.subtitle,
    required this.description,
    required this.icon,
    this.tags = const [],
  });
}

/// Returns the survival-mode passive identity for a given (family, element)
/// pair, or null when there is no special passive. These describe the
/// in-game *passive* mechanics players should know about — things that
/// trigger automatically beyond just casting the special.
String? _survivalElementPassive(String family, String element) {
  switch (family) {
    case 'Pip':
      switch (element) {
        case 'Plant':
          return 'Killed enemies grant +50% alchemy meter on death.';
        case 'Earth':
          return 'Each basic attack shaves 0.4s off the special cooldown.';
        case 'Spirit':
          return '8 credited kills empower this Pip for 6s — basic attacks ~55% faster.';
        case 'Steam':
          return 'Permanent steam aura — basic attacks fire ~35% faster.';
        case 'Mud':
          return 'Hit enemies are tagged: they continuously drop mud trail puffs that slow other enemies.';
        case 'Poison':
          return 'Each basic-hit draws a persistent poison line of zones from the previous hit to the new one.';
        case 'Fire':
          return 'Kills drop a persistent burning fire pool DoT zone.';
        case 'Dust':
          return 'Kills drop a slowing dust cloud zone.';
        case 'Crystal':
          return 'Kills drop a stationary taunting crystal that pulls enemy aggro for ~9s.';
        case 'Dark':
          return 'Kills create a black-hole pull at the kill site.';
        case 'Lightning':
          return 'Double the ricochet — bounce count is the highest in the family.';
        case 'Lava':
          return 'Each pierce drops a lava blob DoT zone at the enemy.';
      }
      return null;
    case 'Mane':
      switch (element) {
        case 'Plant':
          return 'Pierced enemies are rooted; if they die while rooted, they explode in a 130-radius AOE.';
        case 'Light':
          return 'Each pierce grows the projectile — damage, radius, and visual scale up per hit.';
        case 'Lava':
          return 'Each pierce drops a persistent lava blob DoT zone behind.';
        case 'Crystal':
          return 'Direct boss collision deals 25× damage + 200-radius AOE.';
        case 'Water':
          return 'Pierce drags enemies along the projectile path instead of pushing them back.';
        case 'Mud':
          return 'Survival: first enemy hit splits the projectile into 10 fragments in a ring.';
        case 'Spirit':
          return 'Survival: each cast adds another full barrage (1→10 stacks, then resets).';
        case 'Earth':
          return 'Survival: cast becomes a single massive boulder that shrinks while shedding shards along its path.';
        case 'Lightning':
          return 'Survival: cast plants 5–10 stationary lightning rods that chain-zap nearby enemies.';
        case 'Steam':
          return 'Survival: cast becomes a traveling geyser that drops persistent steam puffs along its path.';
      }
      return null;
    case 'Wing':
      switch (element) {
        case 'Dark':
          return 'Auto-attacks and laser pulses fire 2× as fast (cooldowns halved).';
        case 'Plant':
          return 'Beam-killed enemies leave flower pickups; orb collects them to permanently power up the beam (+4% damage per flower, capped at +200%).';
        case 'Mud':
          return 'Hit enemies are permanently slowed (60s effect duration).';
        case 'Dust':
          return 'Hit shooter enemies are disoriented — they shoot other enemies instead of allies.';
        case 'Lava':
          return 'Beam tip drops persistent ground-scar burn zones, painting a damaging line across the field.';
      }
      return null;
    case 'Mask':
      switch (element) {
        case 'Spirit':
          return 'Kills credited to this Mask stack wisps; 6 kills triggers a 220-radius AOE wisp burst.';
        case 'Ice':
          return 'Ice pillar broadcasts a ×2.4 damage amp to all allies within range while active.';
        case 'Plant':
          return 'Vine snare grows in radius and slow-strength over the trap’s lifetime.';
        case 'Light':
          return 'Survival: traps become stationary execute voids that persist until expiring.';
        case 'Air':
          return 'Survival: spawns 8–18 stationary gust pads instead of homing seekers.';
      }
      return null;
    case 'Let':
      switch (element) {
        case 'Plant':
          return 'Kill spawns 4 root zones whose effect radius grows over time.';
        case 'Spirit':
          return '20% chance per hit to instantly kill — scales up to 38% with Intelligence.';
        case 'Crystal':
          return 'Cooldown halved, damage reduced 42%, but on impact slows enemies by 90%.';
        case 'Dark':
          return 'Each kill spawns 2–5 follow-up meteors (twice as big) targeting nearby enemies. Chain capped to one generation.';
        case 'Steam':
          return 'Kill spawns a persistent geyser zone that pushes enemies (~24–40s in survival).';
        case 'Light':
          return 'Kill spawns a persistent heal pool that heals allies and ship.';
        case 'Blood':
          return 'Kill drains nearby enemies; drained HP heals every alchemon + ship.';
        case 'Air':
          return 'Kill blows back all surrounding enemies in 180 radius.';
        case 'Earth':
          return 'On collision, heals the lowest-HP ally or ship for percent of damage dealt.';
        case 'Fire':
          return 'Kill triggers a big AOE explosion damaging nearby enemies.';
        case 'Mud':
          return 'Kill spawns a persistent stun pool.';
      }
      return null;
    case 'Kin':
      switch (element) {
        case 'Dark':
          return 'Signature aura: orbs continuously pull enemies inward (black-hole tick).';
        case 'Fire':
          return 'Signature aura: orbs ignite enemies in range with persistent burn ticks.';
        case 'Water':
          return 'Signature aura: orbs continuously heal orb + ship as they orbit.';
        case 'Ice':
          return 'Signature aura: orbs freeze enemies caught in their orbit zone.';
        case 'Lightning':
          return 'Signature aura: orbs chain-zap enemies (3-target chain per tick) — formation crackles together.';
        case 'Spirit':
          return 'Signature aura: orbs execute low-HP enemies caught in their orbit.';
        case 'Blood':
          return 'Signature aura: orbs leech HP from enemies, healing orb + ship.';
        case 'Plant':
          return 'Signature aura: orbs root enemies in the orbit zone.';
        case 'Poison':
          return 'Signature aura: orbs stack poison DoT on enemies in range.';
        case 'Mud':
          return 'Signature aura: orbs slow-stack enemies + heavy snare + taunt.';
        case 'Air':
          return 'Signature aura: orbs continuously blow back approaching enemies.';
        case 'Earth':
          return 'Signature aura: orbs briefly stun enemies caught in their taunt — monolith turns them to stone.';
        case 'Steam':
          return 'Signature aura: orbs erupt geyser-pulses on enemies stuck in the fog.';
        case 'Light':
          return 'Signature aura: orbs continuously heal orb + ship; ship-orbital + intercept defense.';
        case 'Crystal':
          return 'Signature aura: piercing prism turrets + local splash damage.';
        case 'Dust':
          return 'Signature aura: orbs suppress shooting — shooters caught in the swarm can’t fire.';
        case 'Lava':
          return 'Signature: massive piercing boulders (not little orbs) + burn aura.';
      }
      return null;
    case 'Mystic':
      switch (element) {
        case 'Blood':
          return 'Crimson font + satellite blood pools, each periodically summoning Blood Thralls that hunt enemies. Pools leech HP → heal orb + ship.';
        case 'Lightning':
          return 'Plants 4–9 persistent storm rods in a ring; each fires chain lightning at nearby enemies.';
        case 'Crystal':
          return '5–8 stationary prism towers fire splitting crystal shards; explode into shrapnel when destroyed.';
        case 'Dust':
          return 'Central sandstorm zone suppresses shooting + slows; golden-spiral mote swarm rakes the storm.';
        case 'Fire':
          return 'Persistent ring of fire pillars + blast orbs that charge and home back.';
        case 'Lava':
          return 'Boulders drop persistent magma pools every 0.45s, painting long lava furrows.';
        case 'Water':
          return 'Persistent tidepool at convergence point heals allies + damages enemies. Plus ship blessing tick.';
        case 'Ice':
          return 'Inner ring of permanent freezing pillars + outer ring of launching ice lances.';
        case 'Poison':
          return 'Stationary venom field at target — central super-cloud + 4–8 satellite clouds.';
        case 'Dark':
          return 'Gravity wells that actively pull + execute low-HP enemies (black-hole ticks).';
        case 'Spirit':
          return 'Reaper bolts — slow homing wraiths that execute low-HP enemies on contact.';
      }
      return null;
  }
  return null;
}

_CosmicSpecialInfo _cosmicFamilySpecialInfo(String family, String element) {
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
      return _CosmicSpecialInfo(
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
          'Lightning forks into a rapid chain web of piercing side bolts.',
        'Crystal' =>
          'Crystal refracts from the beam tip into guided prism shards.',
        'Fire' =>
          'Fire widens into a sweeping inferno line with a burning trail.',
        'Ice' =>
          'Ice leaves freezing anchors, then throws back-fanning splinters.',
        'Dark' =>
          'Dark rakes the lane with rupture lances before execution seekers peel out.',
        'Blood' =>
          'Blood fires fewer heavier hunter bolts after the primary crimson lance.',
        'Water' =>
          'Water sends undertow ribbons that hook back inward through the beam lane.',
        'Lava' =>
          'Lava becomes an eruption trench of slow massive piercing chunks.',
        'Steam' =>
          'Steam pulses shells down the lane, then releases drifting cutter shots.',
        'Earth' =>
          'Earth trades speed for a few enormous boulder beams with the widest body.',
        'Mud' =>
          'Mud rakes the lane with bog slugs and sticky guided glob follow-up.',
        'Dust' =>
          'Dust sandblasts a wide scatter of very fast short-lived shards.',
        'Air' =>
          'Air drills forward with fast spiraling wind bolts around the beam.',
        'Plant' =>
          'Plant grows guided vine tendrils from the beam for pursuit pressure.',
        'Poison' =>
          'Poison rides the beam with venom spines, then feeds guided toxins through the lane.',
        'Spirit' =>
          'Spirit sends piercing reaper hunters that keep the long-range execution feel.',
        'Light' =>
          'Light bursts from the tip into radiant guided motes for cleanup.',
        _ =>
          'Element determines the beam follow-through: chains, refractions, hunters, or scatter effects.',
      };
      return _CosmicSpecialInfo(
        subtitle: 'Piercing Beam • Long-range line attack',
        description:
            'Fires a powerful $element beam that pierces through all enemies in its path. '
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
      return _CosmicSpecialInfo(
        subtitle: 'Meteor Strike • Siege follow-through',
        description:
            'Drops a massive $element meteor on the target with a large impact burst. '
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
      return _CosmicSpecialInfo(
        subtitle: 'Tempo Salvo • Fast skirmish special',
        description:
            'Fires a burst of fast $element darts for cleanup and target hopping. '
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
      final controlElement = [
        'Ice',
        'Steam',
        'Earth',
        'Mud',
        'Plant',
        'Poison',
        'Dark',
        'Lava',
        'Water',
      ].contains(element);
      final tempoElement = [
        'Fire',
        'Lightning',
        'Air',
        'Dust',
      ].contains(element);
      final finisherElement = ['Blood', 'Spirit', 'Crystal'].contains(element);
      final followThrough = switch (element) {
        'Fire' =>
          'Fire is an advancing flame-arc burst with a high-tempo follow-through.',
        'Lightning' =>
          'Lightning is a fast fork-cut package with a guided center lane.',
        'Air' =>
          'Air sweeps the widest split cone for speed-first lane clearing.',
        'Dust' => 'Dust floods lanes with a high-count sandblade fan.',
        'Water' =>
          'Water fires dual crossing tide-cuts that form a distinct X-lane slow.',
        'Steam' =>
          'Steam fires a two-beat slash sequence: quick opener into delayed pressure cuts.',
        'Plant' =>
          'Plant opens a core lane and forks into branch cuts for split pressure.',
        'Poison' =>
          'Poison uses drifting long-life venom slashes with stronger lane denial.',
        'Ice' =>
          'Ice keeps heavier chill cleaves with firmer frontal slow pressure.',
        'Earth' =>
          'Earth advances in marching slab-cuts that stagger the lane step by step.',
        'Mud' =>
          'Mud uses heavy stumbling cross-cuts to drag movement in front of it.',
        'Lava' => 'Lava is lower-volume, heavier molten cleave pressure.',
        'Dark' =>
          'Dark is a narrow, high-pressure suppression line with heavier cuts.',
        'Blood' =>
          'Blood fires twin spear-cuts plus a central finisher and sustain payoff.',
        'Spirit' =>
          'Spirit threads a guided center finisher through a disciplined barrage.',
        'Crystal' =>
          'Crystal is a fixed 3-lance prism burst with refracted side follow-ups.',
        'Light' =>
          'Light adds a disciplined parry lane that can intercept one threat.',
        _ =>
          'Element changes the forward technique while keeping Mane focused on lane pressure.',
      };
      return _CosmicSpecialInfo(
        subtitle: 'Barrage Volley • Martial lane pressure',
        description:
            'Unloads a forward $element slash technique meant to suppress what '
            'is directly in front of the Mane. $followThrough',
        icon: Icons.waves,
        tags: [
          'BARRAGE',
          if (tempoElement) 'TEMPO',
          if (controlElement) 'STAGGER',
          if (finisherElement) 'FINISHER',
          if (element == 'Light') 'PARRY',
          element.toUpperCase(),
        ],
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
      return _CosmicSpecialInfo(
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
      return _CosmicSpecialInfo(
        subtitle: 'Blessing Pulse • Guardian support',
        description:
            'Heals self, applies a blessing-over-time, and deploys $element '
            'guardian pieces. $followThrough',
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
      return _CosmicSpecialInfo(
        subtitle: subtitle,
        description: desc,
        icon: Icons.auto_awesome,
        tags: [...tags, 'ULTIMATE', 'LONG CD', element.toUpperCase()],
      );
    default:
      return const _CosmicSpecialInfo(
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
