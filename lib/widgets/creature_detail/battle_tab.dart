// ignore_for_file: unused_element

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/survival/special_attacks/ability_config.dart';
import 'package:alchemons/services/gameengines/boss_battle_engine_service.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/games/survival/survival_combat.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';

class ImprovedBattleScrollArea extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final unit = SurvivalUnit(
      id: 'view_battle',
      name: creature.name,
      types: creature.types,
      family: creature.mutationFamily ?? 'Unknown',
      level: instance.level,
      statSpeed: instance.statSpeed,
      statIntelligence: instance.statIntelligence,
      statStrength: instance.statStrength,
      statBeauty: instance.statBeauty,
    );

    final bossProfile = BattleCombatant(
      id: 'view_boss',
      name: creature.name,
      types: creature.types,
      family: unit.family,
      statSpeed: instance.statSpeed,
      statIntelligence: instance.statIntelligence,
      statStrength: instance.statStrength,
      statBeauty: instance.statBeauty,
      level: instance.level,
    );
    final battleSpecialMove = BattleMove.getSpecialMoveForCombatant(
      bossProfile,
    );
    final battleBasicMove = BattleMove.getBasicMove(unit.family);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: fc.bg3,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: fc.borderDim),
            ),
            child: TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: fc.amberBright,
              unselectedLabelColor: fc.textSecondary,
              labelStyle: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
              indicator: BoxDecoration(
                color: fc.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: fc.borderAccent),
              ),
              tabs: const [
                Tab(text: 'COSMIC'),
                Tab(text: 'BOSS'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildExploreTab(unit, fc),
                _buildBossTab(bossProfile, battleBasicMove, battleSpecialMove),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBossTab(
    BattleCombatant bossProfile,
    BattleMove battleBasicMove,
    BattleMove battleSpecialMove,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BattleSection(
            title: 'Boss Combat Profile',
            color: FC.orange,
            child: _BossCombatProfileCard(
              profile: bossProfile,
              basicMoveName: battleBasicMove.name,
              specialMoveName: battleSpecialMove.name,
              specialMoveSummary: BattleMove.specialSummaryForCombatant(
                bossProfile,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EXPLORE TAB — Cosmic / Exploration mode companion abilities
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildExploreTab(SurvivalUnit unit, FC fc) {
    final family = unit.family;
    final element = unit.types.firstOrNull ?? 'Normal';
    final ft = FT(fc);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BattleSection(
            title: 'Companion Role',
            color: fc.amber,
            child: _exploreRoleCard(family, element, fc, ft),
          ),
          const SizedBox(height: 20),
          _BattleSection(
            title: 'Basic Attack',
            color: fc.amber,
            child: _exploreBasicCard(family, element, fc, ft),
          ),
          const SizedBox(height: 20),
          _BattleSection(
            title: 'Special Attack',
            color: fc.amber,
            child: _exploreSpecialCard(family, element, fc, ft),
          ),
          const SizedBox(height: 20),
          _BattleSection(
            title: 'Cosmic Survival',
            color: fc.amber,
            child: _buildExploreSurvivalCard(family, element, fc),
          ),
          const SizedBox(height: 20),
          _BattleSection(
            title: 'Stat Effects',
            color: fc.amber,
            child: const _ExploreStatEffectsCard(),
          ),
        ],
      ),
    );
  }

  Widget _exploreRoleCard(String family, String element, FC fc, FT ft) {
    final role = _cosmicFamilyRole(family);
    final icon = _exploreFamilyIcon(family);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: fc.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: fc.borderAccent),
              ),
              child: Icon(icon, color: fc.amberBright, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${family.toUpperCase()} COMPANION',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: fc.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    role.title,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: fc.amberBright,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          role.description,
          style: TextStyle(color: fc.textSecondary, fontSize: 11, height: 1.4),
        ),
      ],
    );
  }

  Widget _exploreBasicCard(String family, String element, FC fc, FT ft) {
    final basicInfo = _cosmicFamilyBasicInfo(family, element);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: fc.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: fc.borderAccent),
              ),
              child: Icon(basicInfo.icon, color: fc.amberBright, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    basicInfo.name.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: fc.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    basicInfo.subtitle,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: fc.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          basicInfo.description,
          style: TextStyle(color: fc.textSecondary, fontSize: 11, height: 1.4),
        ),
      ],
    );
  }

  Widget _exploreSpecialCard(String family, String element, FC fc, FT ft) {
    final abilityName = cosmicSpecialAbilityName(family, element);
    final specialInfo = _cosmicFamilySpecialInfo(family, element);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: fc.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: fc.borderAccent),
              ),
              child: Icon(specialInfo.icon, color: fc.amberBright, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    abilityName.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: fc.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    specialInfo.subtitle,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: fc.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          specialInfo.description,
          style: TextStyle(color: fc.textSecondary, fontSize: 11, height: 1.4),
        ),
        if (specialInfo.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: specialInfo.tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: fc.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: fc.borderDim),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: fc.amberBright,
                    letterSpacing: 0.5,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  static IconData _exploreFamilyIcon(String family) {
    switch (family) {
      case 'Let':
        return Icons.south;
      case 'Pip':
        return Icons.bolt;
      case 'Mane':
        return Icons.waves;
      case 'Mask':
        return Icons.warning_amber;
      case 'Horn':
        return Icons.shield;
      case 'Wing':
        return Icons.arrow_forward;
      case 'Kin':
        return Icons.favorite;
      case 'Mystic':
        return Icons.auto_awesome;
      default:
        return Icons.star;
    }
  }

  static _CosmicFamilyRole _cosmicFamilyRole(String family) {
    switch (family) {
      case 'Horn':
        return const _CosmicFamilyRole(
          title: 'Charge Bruiser',
          description:
              'Horns force close fights. They push into short range, soak '
              'pressure with shields, and convert specials into real charge '
              'impacts that slam through targets instead of hovering at range.',
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
          title: 'Artillery Bomber',
          description:
              'Lets fight like bombardiers. They stay back, lob heavy shots, '
              'and drop meteor-style specials with huge impact bursts, '
              'fragments, and strong elemental follow-through pressure.',
        );
      case 'Pip':
        return const _CosmicFamilyRole(
          title: 'Skirmish Dart',
          description:
              'Pips are close-mid skirmishers. They cycle attacks fast, '
              'pepper targets with tracking darts, and turn specials into '
              'ricochet pressure that keeps jumping between enemies.',
        );
      case 'Mane':
        return const _CosmicFamilyRole(
          title: 'Suppression Barrage',
          description:
              'Manes are forward pressure gunners. They step into medium '
              'range and unload dense frontal volleys that suppress lanes and '
              'punish clustered enemies without wasting shots behind them.',
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
}

/// Flat section header for the battle tab — no box, just accent bar + rule
class _BattleSection extends StatelessWidget {
  final String title;
  final Widget child;
  final Color color;

  const _BattleSection({
    required this.title,
    required this.child,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final ft = FT(fc);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 3, height: 10, color: color),
            const SizedBox(width: 7),
            Text(
              title.toUpperCase(),
              style: ft.sectionTitle.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Container(height: 1, color: fc.borderDim),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

Widget _buildExploreSurvivalCard(String family, String element, FC fc) {
  final notes = _cosmicSurvivalNotes(family, element);
  final accent = _survivalAccentColor(element);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: fc.bg3,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.blur_circular_rounded, size: 16, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                notes.summary,
                style: TextStyle(
                  color: fc.textPrimary,
                  fontSize: 11,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      if (notes.bullets.isNotEmpty) ...[
        const SizedBox(height: 10),
        for (final bullet in notes.bullets) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Icon(Icons.circle, size: 5, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bullet,
                  style: TextStyle(
                    color: fc.textSecondary,
                    fontSize: 10.5,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          if (bullet != notes.bullets.last) const SizedBox(height: 8),
        ],
      ],
    ],
  );
}

class _BossCombatProfileCard extends StatelessWidget {
  final BattleCombatant profile;
  final String basicMoveName;
  final String specialMoveName;
  final String specialMoveSummary;

  const _BossCombatProfileCard({
    required this.profile,
    required this.basicMoveName,
    required this.specialMoveName,
    required this.specialMoveSummary,
  });

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final specialCooldownTurns = BattleMove.specialCooldownForFamily(
      profile.family,
    );
    final specialRecoveryPerBasic =
        BattleMove.specialRecoveryPerBasicForCombatant(profile);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _bossStatChip('HP', profile.maxHp.toString(), fc)),
            const SizedBox(width: 8),
            Expanded(
              child: _bossStatChip('ATK', profile.physAtk.toString(), fc),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _bossStatChip('DEF', profile.physDef.toString(), fc),
            ),
            const SizedBox(width: 8),
            Expanded(child: _bossStatChip('SPD', profile.speed.toString(), fc)),
          ],
        ),
        const SizedBox(height: 12),
        _moveLine('Basic Move', basicMoveName, fc),
        const SizedBox(height: 6),
        _moveLine('Special Move', specialMoveName, fc),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 90),
          child: Text(
            specialMoveSummary,
            style: TextStyle(
              color: fc.textSecondary,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _moveLine('Basic Action CD', '2 turns', fc),
        const SizedBox(height: 6),
        _moveLine('Special Action CD', '3 turns', fc),
        const SizedBox(height: 6),
        _moveLine(
          'Special CD',
          '$specialCooldownTurns turn${specialCooldownTurns == 1 ? '' : 's'}',
          fc,
        ),
        const SizedBox(height: 6),
        _moveLine(
          'CD / Basic',
          '$specialRecoveryPerBasic turn(s) recovered',
          fc,
        ),
        const SizedBox(height: 6),
        _moveLine('Special Unlock', 'Level 5', fc),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 90),
          child: Text(
            'Boss mode uses commitment cooldowns: specials lock longer and cooldown recovery comes from basic attacks and certain abilities.',
            style: TextStyle(
              color: fc.textSecondary,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'STAT SCALING',
          style: TextStyle(
            fontFamily: 'monospace',
            color: fc.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: fc.bg2.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: fc.borderDim),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _scalingRow(
                stat: 'SPD',
                title: 'Tempo + Cooldown',
                effect:
                    'Turn order priority, plus extra special recovery on basics at SPD 2.0 / 3.0 / 4.0 / 4.8.',
                fc: fc,
              ),
              const SizedBox(height: 6),
              _scalingRow(
                stat: 'INT',
                title: 'Elemental Power',
                effect:
                    'Raises elemental attack and boosts DoT/regen effect scaling.',
                fc: fc,
              ),
              const SizedBox(height: 6),
              _scalingRow(
                stat: 'BEAUTY',
                title: 'Elemental Defense',
                effect:
                    'Raises elemental defense and adds to physical defense.',
                fc: fc,
              ),
              const SizedBox(height: 6),
              _scalingRow(
                stat: 'STR',
                title: 'Physical Core',
                effect: 'Raises max HP, physical attack, and physical defense.',
                fc: fc,
              ),
              const SizedBox(height: 8),
              Text(
                'Cooldown scaling note: only SPD affects baseline cooldown recovery tiers in Boss mode.',
                style: TextStyle(
                  color: fc.textSecondary,
                  fontSize: 10,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'SPD tiers: +1 recovery at 2.0, +1 at 3.0, +1 at 4.0, +1 at 4.8.',
                style: TextStyle(
                  color: fc.textMuted,
                  fontSize: 10,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bossStatChip(String label, String value, FC fc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: fc.bg2,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: fc.borderDim),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              color: fc.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              color: fc.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _moveLine(String label, String value, FC fc) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'monospace',
              color: fc.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              color: fc.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _scalingRow({
    required String stat,
    required String title,
    required String effect,
    required FC fc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 50,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: fc.bg3,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: fc.borderDim),
          ),
          child: Text(
            stat,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'monospace',
              color: fc.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: fc.amberBright,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                effect,
                style: TextStyle(
                  color: fc.textSecondary,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ===============================================
// DYNAMIC BASIC ATTACK CARD
// ===============================================
class _DynamicBasicAttackCard extends StatelessWidget {
  final SurvivalUnit unit;

  const _DynamicBasicAttackCard({required this.unit});

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final element = unit.types.firstOrNull ?? 'Normal';
    final cooldown = (1.5 / unit.cooldownReduction).toStringAsFixed(1);
    final passiveEffect = AbilitySystemConfig.getPassiveEffectDescription(
      element,
    );
    final elemColor = _getElementColor(element);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: fc.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: fc.borderAccent),
              ),
              child: Icon(Icons.star_border, color: fc.amberBright, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ELEMENTAL PROJECTILE',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: fc.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    'Cooldown: ${cooldown}s • Scales with Speed',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: fc.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Fires elemental projectiles at enemies. Basic damage scales with Strength, elemental damage with Beauty, attack speed with Speed, and range with Intelligence.',
          style: TextStyle(color: fc.textSecondary, fontSize: 11, height: 1.4),
        ),
        const SizedBox(height: 12),

        // Dynamic Passive Effect
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: fc.bg3,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: elemColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(_getPassiveIcon(element), size: 12, color: elemColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  passiveEffect,
                  style: TextStyle(
                    color: fc.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),
        _DamagePreview(unit: unit),
      ],
    );
  }

  Color _getElementColor(String element) {
    switch (element) {
      case 'Fire':
      case 'Lava':
        return Colors.deepOrange;
      case 'Water':
      case 'Ice':
      case 'Steam':
        return Colors.blue;
      case 'Earth':
      case 'Mud':
      case 'Crystal':
        return Colors.brown;
      case 'Air':
      case 'Dust':
      case 'Lightning':
        return Colors.cyan;
      case 'Plant':
      case 'Poison':
        return Colors.green;
      case 'Spirit':
      case 'Dark':
        return Colors.deepPurple;
      case 'Light':
        return const Color(0xFFB45309);
      case 'Blood':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getPassiveIcon(String element) {
    switch (element) {
      case 'Fire':
      case 'Lava':
        return Icons.local_fire_department;
      case 'Water':
      case 'Ice':
        return Icons.water_drop;
      case 'Lightning':
        return Icons.bolt;
      case 'Earth':
        return Icons.terrain;
      case 'Plant':
        return Icons.eco;
      case 'Poison':
        return Icons.science;
      case 'Air':
        return Icons.air;
      default:
        return Icons.circle;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DAMAGE PREVIEW
// ─────────────────────────────────────────────────────────────────────────────
class _DamagePreview extends StatelessWidget {
  final SurvivalUnit unit;
  const _DamagePreview({required this.unit});

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: fc.amberDim.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: fc.borderAccent),
      ),
      child: Row(
        children: [
          _statChip('DMG', '${unit.physAtk}', Icons.gavel, fc),
          const SizedBox(width: 8),
          _statChip('ELEM', '${unit.elemAtk}', Icons.auto_awesome, fc),
          const SizedBox(width: 8),
          _statChip(
            'RNG',
            unit.attackRange.toStringAsFixed(0),
            Icons.my_location,
            fc,
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, IconData icon, FC fc) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: fc.bg3,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: fc.amberDim),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                color: fc.textMuted,
                fontSize: 8,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'monospace',
                color: fc.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DYNAMIC SPECIAL ABILITY CARD (3-TIER SYSTEM)
// ─────────────────────────────────────────────────────────────────────────────
class _DynamicSpecialAbilityCard extends StatefulWidget {
  final SurvivalUnit unit;
  const _DynamicSpecialAbilityCard({required this.unit});
  @override
  State<_DynamicSpecialAbilityCard> createState() =>
      _DynamicSpecialAbilityCardState();
}

class _DynamicSpecialAbilityCardState
    extends State<_DynamicSpecialAbilityCard> {
  int _selectedRank = 1;

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final ft = FT(fc);
    final family = widget.unit.family;
    final element = widget.unit.types.firstOrNull ?? 'Normal';
    final baseDescription = AbilitySystemConfig.getAbilityDescription(
      family,
      element,
      0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: fc.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: fc.borderAccent),
              ),
              child: Icon(
                _getFamilyIcon(family),
                color: fc.amberBright,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getFamilyAbilityName(family).toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: fc.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    'Scales with Beauty \u2022 3 elemental upgrades',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: fc.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          baseDescription,
          style: TextStyle(color: fc.textSecondary, fontSize: 11, height: 1.4),
        ),
        const SizedBox(height: 16),
        Text('ELEMENTAL MASTERY', style: ft.label),
        const SizedBox(height: 8),
        Row(
          children: [
            _rankButton(1, 'I', 'UNLOCK', fc),
            const SizedBox(width: 8),
            _rankButton(2, 'II', 'POWER', fc),
            const SizedBox(width: 8),
            _rankButton(3, 'III', 'ULTIMATE', fc),
          ],
        ),
        const SizedBox(height: 12),
        _rankDescriptionBox(family, element, fc),
      ],
    );
  }

  Widget _rankButton(int rank, String label, String? subtitle, FC fc) {
    final isSelected = _selectedRank == rank;
    final isUltimate = rank == 3;
    final activeColor = isUltimate ? fc.amberGlow : fc.amber;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedRank = rank),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.15) : fc.bg3,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.8)
                  : fc.borderDim,
              width: isSelected ? 1.0 : 0.8,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: isSelected ? activeColor : fc.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: isSelected
                        ? activeColor.withValues(alpha: 0.8)
                        : fc.textMuted,
                    fontSize: 7,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _rankDescriptionBox(String family, String element, FC fc) {
    final description = AbilitySystemConfig.getAbilityDescription(
      family,
      element,
      _selectedRank,
    );
    final isUltimate = _selectedRank == 3;
    final tierLabel = _getTierLabel(_selectedRank);
    final activeColor = isUltimate ? fc.amberGlow : fc.amber;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: activeColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: activeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: activeColor.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Text(
                  _getRomanNumeral(_selectedRank),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: activeColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  tierLabel,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: activeColor.withValues(alpha: 0.7),
                    fontSize: 6,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                color: fc.textPrimary,
                fontSize: 11,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRomanNumeral(int rank) {
    switch (rank) {
      case 1:
        return 'I';
      case 2:
        return 'II';
      case 3:
        return 'III';
      default:
        return '';
    }
  }

  String _getTierLabel(int rank) {
    switch (rank) {
      case 1:
        return 'UNLOCK';
      case 2:
        return 'POWER';
      case 3:
        return 'ULTIMATE';
      default:
        return '';
    }
  }

  String _getFamilyAbilityName(String family) {
    switch (family) {
      case 'Let':
        return 'Meteor Strike';
      case 'Pip':
        return 'Frenzy';
      case 'Mane':
        return 'Entangle';
      case 'Mask':
        return 'Hex Field';
      case 'Horn':
        return 'Fortress';
      case 'Wing':
        return 'Piercing Beam';
      case 'Kin':
        return 'Sanctuary';
      case 'Mystic':
        return 'Arcane Orbitals';
      default:
        return 'Special Ability';
    }
  }

  IconData _getFamilyIcon(String family) {
    switch (family) {
      case 'Let':
        return Icons.south;
      case 'Pip':
        return Icons.bolt;
      case 'Mane':
        return Icons.waves;
      case 'Mask':
        return Icons.warning_amber;
      case 'Horn':
        return Icons.shield;
      case 'Wing':
        return Icons.arrow_forward;
      case 'Kin':
        return Icons.favorite;
      case 'Mystic':
        return Icons.auto_awesome;
      default:
        return Icons.star;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAT EFFECTS CARD
// ─────────────────────────────────────────────────────────────────────────────
class _StatEffectsCard extends StatelessWidget {
  const _StatEffectsCard();

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statEffect(
          icon: Icons.favorite,
          stat: 'Max HP',
          effect: 'Guardian survivability and health pool',
          fc: fc,
        ),
        const SizedBox(height: 8),
        _statEffect(
          icon: Icons.gavel,
          stat: 'Strength',
          effect: 'Basic attack physical damage',
          fc: fc,
        ),
        const SizedBox(height: 8),
        _statEffect(
          icon: Icons.psychology,
          stat: 'Intelligence',
          effect: 'Attack range and cooldown reduction',
          fc: fc,
        ),
        const SizedBox(height: 8),
        _statEffect(
          icon: Icons.auto_awesome,
          stat: 'Beauty',
          effect: 'Elemental damage and ability power',
          fc: fc,
        ),
        const SizedBox(height: 8),
        _statEffect(
          icon: Icons.speed,
          stat: 'Speed',
          effect: 'Attack speed (from base stats)',
          fc: fc,
        ),
      ],
    );
  }

  Widget _statEffect({
    required IconData icon,
    required String stat,
    required String effect,
    required FC fc,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: fc.amberDim.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Icon(icon, size: 12, color: fc.amber),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stat.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: fc.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                effect,
                style: TextStyle(
                  color: fc.textSecondary,
                  fontSize: 10,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COSMIC FAMILY ROLE
// ─────────────────────────────────────────────────────────────────────────────
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
        'Horns are the bruiser family in survival: they push forward, intercept orb threats, and fight closer than most companions.',
        'Shield-heavy Horn variants buy time for the whole defense line and are best when lanes are collapsing into the orb.',
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
      }
      return _CosmicSurvivalNotes(
        summary:
            'Horn plays as an aggressive tank in cosmic survival: it wants to stand in front of danger, absorb pressure, and crash into priority threats.',
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
        'Their best moments come from controlling approach paths with meteors, wells, walls, or other heavy follow-through pieces.',
      ]);
      if (['Dark', 'Mud', 'Steam', 'Poison'].contains(normalizedElement)) {
        bullets.add(
          '$normalizedElement Let is especially control-oriented, so it shines when enemies are funneled through one lane and forced to sit in the setup.',
        );
      }
      return _CosmicSurvivalNotes(
        summary:
            'Let behaves like artillery in survival: slower to reposition, heavier on commitment, and best when it can lock down a lane instead of dueling up close.',
        bullets: bullets,
      );
    case 'Pip':
      bullets.addAll([
        'Pips are cleanup assassins: they dart after weak or spread-out enemies and keep pressure high between larger specials.',
        'They are valuable for removing messy leftovers so bulkier allies can stay on important threats.',
      ]);
      if ([
        'Lightning',
        'Air',
        'Crystal',
        'Light',
      ].contains(normalizedElement)) {
        bullets.add(
          '$normalizedElement Pip is one of the better ricochet or rebound variants, so it gets extra value when waves arrive in clumps or staggered packs.',
        );
      }
      return _CosmicSurvivalNotes(
        summary:
            'Pip is a fast skirmish finisher in survival. It should feel surgical, opportunistic, and better at picks than at holding the center.',
        bullets: bullets,
      );
    case 'Mane':
      bullets.addAll([
        'Manes are tempo brawlers: they step up, unload a barrage window, then keep the lane under pressure with fast follow-ups.',
        'They are better at forward suppression than at hard defense, so they feel best when your team already has some frontline stability.',
      ]);
      if (['Poison', 'Fire', 'Lightning', 'Dust'].contains(normalizedElement)) {
        bullets.add(
          '$normalizedElement Mane emphasizes tempo and barrage volume, which makes it especially good at keeping regular waves from rebuilding momentum.',
        );
      }
      return _CosmicSurvivalNotes(
        summary:
            'Mane is an offense-first pressure family in survival. It wins by keeping targets under constant frontal tempo instead of by anchoring or escorting.',
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
        'Mystics are high-impact control casters: they place major battlefield pieces and care more about cast quality than constant uptime.',
        'They are strongest when the fight gives them time to establish orbitals, control zones, sentinels, or trap patterns.',
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
      } else if (normalizedElement == 'Blood') {
        bullets.add(
          'Blood Mystic adds sustain on top of its control pattern, making it one of the safest long-run mystic picks.',
        );
      }
      return _CosmicSurvivalNotes(
        summary:
            'Mystic is the premium control family in survival. It should feel deliberate, setup-heavy, and capable of reshaping the battlefield with one special.',
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
        subtitle: 'Scales with Strength • 2 forward slashes',
        description:
            'Fires two forward $element shots with slight spread. The basic '
            'attack is built for lane pressure and consistent frontal damage, '
            'not circular spray.',
        icon: Icons.waves,
      );
    case 'Horn':
      return _CosmicBasicInfo(
        name: '$element Ram Shot',
        subtitle: 'Scales with Strength • Heavy close-range projectile',
        description:
            'Launches a large, slow $element projectile with an oversized '
            'hitbox. Horn basics hit hard up close and help keep pressure on '
            'targets before the shield-charge special lands.',
        icon: Icons.shield,
      );
    case 'Mask':
      return _CosmicBasicInfo(
        name: '$element Probe Bolt',
        subtitle: 'Scales with Strength • Fast piercing setup shot',
        description:
            'Fires a quick piercing $element bolt to tag targets in a line. '
            'Mask basics are light pressure tools that set up the family\'s '
            'trap, lure, and decoy control game.',
        icon: Icons.warning_amber,
      );
    case 'Wing':
      return _CosmicBasicInfo(
        name: '$element Feather Burst',
        subtitle: 'Scales with Strength • 2 rapid pursuit shots',
        description:
            'Unleashes two quick $element bolts in succession. Wing basics '
            'keep damage flowing while the companion stays mobile and looks '
            'for a clean beam line.',
        icon: Icons.arrow_forward,
      );
    case 'Kin':
      return _CosmicBasicInfo(
        name: '$element Guided Bolt',
        subtitle: 'Scales with Strength • Reliable homing support fire',
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
        subtitle: 'Scales with Strength • 3 spread bolts',
        description:
            'Releases three small $element bolts in a spread. Mystic basics '
            'hold space between ultimates, but the family\'s real power is in '
            'its slower, element-specific guardian special.',
        icon: Icons.auto_awesome,
      );
    case 'Pip':
      return _CosmicBasicInfo(
        name: '$element Dart Burst',
        subtitle: 'Scales with Strength • 3 fast tracking darts',
        description:
            'Fires a quick burst of small $element darts. Pip basics are '
            'built for high uptime, target pressure, and staying active '
            'between ricochet specials.',
        icon: Icons.bolt,
      );
    case 'Let':
      return _CosmicBasicInfo(
        name: '$element Bomb',
        subtitle: 'Scales with Strength • Slow artillery shot',
        description:
            'Lobs a compact $element bomb with more heft than a standard bolt. '
            'Let basics reinforce the artillery role and visually preview the '
            'family\'s meteor-style specials.',
        icon: Icons.south,
      );
    default:
      return _CosmicBasicInfo(
        name: '$element Bolt',
        subtitle: 'Scales with Strength • Auto-targets nearest',
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

_CosmicSpecialInfo _cosmicFamilySpecialInfo(String family, String element) {
  switch (family) {
    case 'Horn':
      return _CosmicSpecialInfo(
        subtitle: 'Shield Charge • Beauty × 2 • Close-range finisher',
        description:
            'Raises a shield, erupts with an elemental burst, then commits to '
            'a real impact charge. Horn specials are built to connect in melee '
            'and punish targets with a bruiser-style crash instead of just a dash animation.',
        icon: Icons.shield,
        tags: ['SHIELD', 'CHARGE', 'NOVA', element.toUpperCase()],
      );
    case 'Wing':
      final hasTrail = ['Lava', 'Fire', 'Plant'].contains(element);
      return _CosmicSpecialInfo(
        subtitle: 'Piercing Beam • Beauty × 2 • Long-range line attack',
        description:
            'Fires a powerful $element beam that pierces through all enemies in its path. '
            '${hasTrail ? 'Leaves a lingering $element damage trail behind the beam. ' : ''}'
            'Element determines secondary follow-through — chains, refractions, '
            'hunters, or scatter effects.',
        icon: Icons.arrow_forward,
        tags: [
          'PIERCING',
          'BEAM',
          if (hasTrail) 'TRAIL',
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
      return _CosmicSpecialInfo(
        subtitle: 'Meteor Strike • Beauty × 2 • Heavy artillery cooldown',
        description:
            'Drops a massive $element meteor on the target with a large impact burst. '
            '${hasCluster ? 'The meteor fragments mid-flight, splitting into sub-projectiles. ' : ''}'
            'Element determines the follow-through, such as shard fans, guided finishers, chain bursts, rupture lines, or other post-impact pressure.',
        icon: Icons.south,
        tags: [
          'METEOR',
          'IMPACT',
          'HEAVY',
          if (hasCluster) 'CLUSTER',
          element.toUpperCase(),
        ],
      );
    case 'Pip':
      final hasBounce = [
        'Crystal',
        'Lightning',
        'Air',
        'Fire',
        'Water',
        'Ice',
        'Dust',
        'Light',
      ].contains(element);
      return _CosmicSpecialInfo(
        subtitle: 'Ricochet Salvo • Beauty × 2 • Fast cycle skirmish special',
        description:
            'Fires a burst of fast $element projectiles that seek out '
            'different enemies. '
            '${hasBounce ? 'Projectiles ricochet between enemies on hit, chaining damage. ' : 'Projectiles home toward the nearest enemy with strong tracking. '}'
            'Element determines count, tracking pattern, and ricochet behavior.',
        icon: Icons.bolt,
        tags: [
          hasBounce ? 'RICOCHET' : 'HOMING',
          'MULTI-TARGET',
          element.toUpperCase(),
        ],
      );
    case 'Mane':
      return _CosmicSpecialInfo(
        subtitle: 'Barrage Volley • Beauty × 2 • Forward suppression burst',
        description:
            'Unloads a dense forward $element barrage meant to suppress what is '
            'in front of the Mane. Element changes spread, bolt weight, tempo, '
            'and follow-through, but the move stays focused on frontal pressure.',
        icon: Icons.waves,
        tags: ['BARRAGE', 'SUPPRESSION', element.toUpperCase()],
      );
    case 'Mask':
      final isDecoy = [
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
      return _CosmicSpecialInfo(
        subtitle: isDecoy
            ? 'Decoy Totem • Beauty × 2 • Control setup'
            : 'Seeker Swarm • Beauty × 2 • Control setup',
        description: isDecoy
            ? 'Deploys $element decoy totems that taunt nearby enemies. Enemies '
                  'attack the decoy instead of you. When destroyed, the decoy '
                  'explodes into a ring of damaging projectiles.'
            : 'Deploys $element seekers and control pieces that redirect enemy '
                  'movement, create pressure windows, and support the family\'s '
                  'bait-and-punish style instead of relying on raw burst.',
        icon: isDecoy ? Icons.sports_kabaddi : Icons.warning_amber,
        tags: [
          isDecoy ? 'DECOY' : 'SEEKERS',
          isDecoy ? 'TAUNT' : 'CONTROL',
          isDecoy ? 'EXPLODES' : 'REDIRECT',
          element.toUpperCase(),
        ],
      );
    case 'Kin':
      return _CosmicSpecialInfo(
        subtitle: 'Blessing Pulse • Beauty × 2 • Heal + guardian orbit',
        description:
            'Heals self, applies a blessing-over-time, and deploys a $element '
            'guardian pattern. Depending on the element, the constructs may '
            'escort the ship, intercept threats, mend ship health, peel melee '
            'pressure, stalk targets, or establish control zones before expiring.',
        icon: Icons.favorite,
        tags: ['HEAL', 'ORBITAL', 'BLESSING', element.toUpperCase()],
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
          'Guardian Ultimate • Long cooldown',
          'Calls a $element guardian ultimate built for single-slot impact. '
              'Mystic specials stage in orbit first, then resolve into '
              'elemental signatures.',
          <String>['GUARDIAN', 'ULTIMATE'],
        ),
      };
      return _CosmicSpecialInfo(
        subtitle: subtitle,
        description: desc,
        icon: Icons.auto_awesome,
        tags: [...tags, 'LONG CD', element.toUpperCase()],
      );
    default:
      return const _CosmicSpecialInfo(
        subtitle: 'Beauty × 2 • 30s cooldown',
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
class _ExploreStatEffectsCard extends StatelessWidget {
  const _ExploreStatEffectsCard();

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statEffect(
          icon: Icons.favorite,
          stat: 'STR + INT → HP',
          effect: 'Both power and intelligence feed companion durability',
          fc: fc,
        ),
        const SizedBox(height: 8),
        _statEffect(
          icon: Icons.gps_fixed,
          stat: 'Strength → Basic DMG',
          effect: 'Increases basic projectile damage',
          fc: fc,
        ),
        const SizedBox(height: 8),
        _statEffect(
          icon: Icons.auto_awesome,
          stat: 'Beauty → Special DMG',
          effect: 'Raises special attack power, including guardian ultimates',
          fc: fc,
        ),
        const SizedBox(height: 8),
        _statEffect(
          icon: Icons.radar,
          stat: 'Intelligence → Range',
          effect: 'Increases attack reach and supports survivability scaling',
          fc: fc,
        ),
        const SizedBox(height: 8),
        _statEffect(
          icon: Icons.speed,
          stat: 'Speed → Cooldowns',
          effect: 'Reduces time between attacks and specials',
          fc: fc,
        ),
        const SizedBox(height: 8),
        _statEffect(
          icon: Icons.shield,
          stat: 'Stats → Defence',
          effect:
              'Strength helps physical defence, Beauty helps elemental defence',
          fc: fc,
        ),
      ],
    );
  }

  Widget _statEffect({
    required IconData icon,
    required String stat,
    required String effect,
    required FC fc,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: fc.amberDim.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Icon(icon, size: 12, color: fc.amber),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stat.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: fc.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                effect,
                style: TextStyle(
                  color: fc.textSecondary,
                  fontSize: 10,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
