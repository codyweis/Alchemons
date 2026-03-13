import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/survival/special_attacks/ability_config.dart';
import 'package:alchemons/services/gameengines/boss_battle_engine_service.dart';
import 'package:alchemons/widgets/survival_specs_widget.dart';
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
      length: 3,
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
                Tab(text: 'EXPLORE'),
                Tab(text: 'BOSS'),
                Tab(text: 'SURVIVAL'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildExploreTab(unit, fc),
                _buildBossTab(bossProfile, battleBasicMove, battleSpecialMove),
                _buildSurvivalTab(unit, fc),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurvivalTab(SurvivalUnit unit, FC fc) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BattleSection(
            title: 'Survival Metrics',
            color: fc.amber,
            child: SurvivalSpecsWidget(creature: creature, instance: instance),
          ),
          const SizedBox(height: 20),
          _BattleSection(
            title: 'Basic Attack',
            color: fc.amber,
            child: _DynamicBasicAttackCard(unit: unit),
          ),
          const SizedBox(height: 20),
          _BattleSection(
            title: 'Special Ability',
            color: fc.amber,
            child: _DynamicSpecialAbilityCard(unit: unit),
          ),
          const SizedBox(height: 20),
          _BattleSection(
            title: 'Stat Effects',
            color: fc.amber,
            child: const _StatEffectsCard(),
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
              bossGimmickSummary: BattleMove.bossGimmickSummaryForCombatant(
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
              'and drop meteor-style specials with impact zones, fragments, '
              'and strong elemental follow-up effects.',
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
              'Kins are sustain guardians. Their specials heal, bless, and '
              'deploy element-shaped guardian constructs such as ship wards, '
              'escort sentries, snares, hunters, and other persistent support '
              'tools instead of one generic orbital move.',
        );
      case 'Mystic':
        return const _CosmicFamilyRole(
          title: 'Guardian Ultimate',
          description:
              'Mystics are single-slot guardian power picks. Their specials '
              'are intentionally slower and much more powerful, with each '
              'element behaving like a distinct ultimate rather than a generic '
              'orbital burst.',
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

class _BossCombatProfileCard extends StatelessWidget {
  final BattleCombatant profile;
  final String basicMoveName;
  final String specialMoveName;
  final String specialMoveSummary;
  final String bossGimmickSummary;

  const _BossCombatProfileCard({
    required this.profile,
    required this.basicMoveName,
    required this.specialMoveName,
    required this.specialMoveSummary,
    required this.bossGimmickSummary,
  });

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
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
        _moveLine('Boss Special', '', fc),
        Padding(
          padding: const EdgeInsets.only(left: 90),
          child: Text(
            bossGimmickSummary,
            style: TextStyle(
              color: fc.textSecondary,
              fontSize: 11,
              height: 1.3,
            ),
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
        return Colors.yellow;
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
      final hasTrail = [
        'Poison',
        'Lava',
        'Fire',
        'Mud',
        'Steam',
        'Plant',
      ].contains(element);
      return _CosmicSpecialInfo(
        subtitle: 'Piercing Beam • Beauty × 2 • Long-range line attack',
        description:
            'Fires a powerful $element beam that pierces through all enemies in its path. '
            '${hasTrail ? 'Leaves a lingering $element damage trail behind the beam. ' : ''}'
            'Element determines secondary projectiles — chains, refractions, '
            'or scatter effects.',
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
            'Drops a massive $element meteor on the target with a large impact area. '
            '${hasCluster ? 'The meteor fragments mid-flight, splitting into sub-projectiles. ' : ''}'
            'Element determines follow-up effects like fragments, lingering zones, chain bursts, or impact hazards.',
        icon: Icons.south,
        tags: [
          'METEOR',
          'AOE',
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
            'in front of the Mane. Element changes spread, bolt weight, and '
            'volume, but the move stays focused on frontal pressure.',
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
            : 'Mine Field • Beauty × 2 • Control setup',
        description: isDecoy
            ? 'Deploys $element decoy totems that taunt nearby enemies. Enemies '
                  'attack the decoy instead of you. When destroyed, the decoy '
                  'explodes into a ring of damaging projectiles.'
            : 'Deploys $element control traps and seekers that deny space and '
                  'pull enemy movement into prepared zones instead of relying on raw burst.',
        icon: isDecoy ? Icons.sports_kabaddi : Icons.warning_amber,
        tags: [
          isDecoy ? 'DECOY' : 'MINES',
          isDecoy ? 'TAUNT' : 'STATIONARY',
          isDecoy ? 'EXPLODES' : 'AREA DENIAL',
          element.toUpperCase(),
        ],
      );
    case 'Kin':
      return _CosmicSpecialInfo(
        subtitle: 'Blessing Pulse • Beauty × 2 • Heal + guardian orbit',
        description:
            'Heals self, applies a blessing-over-time, and deploys a $element '
            'guardian pattern. Depending on the element, the constructs may '
            'escort the ship, intercept threats, set snares, stalk targets, '
            'or establish control zones before expiring.',
        icon: Icons.favorite,
        tags: ['HEAL', 'ORBITAL', 'BLESSING', element.toUpperCase()],
      );
    case 'Mystic':
      return _CosmicSpecialInfo(
        subtitle: 'Guardian Ultimate • Beauty × 2 • Long cooldown',
        description:
            'Calls a $element guardian attack built around long-cooldown power. '
            'Mystic specials stage in orbit first, then break into premium '
            'element-specific patterns such as mirrored crescents, splits, '
            'fragments, rebounds, residue trails, or heavy hunter cores. Each '
            'element is meant to feel like its own ultimate, not just a recolored orbital.',
        icon: Icons.auto_awesome,
        tags: ['GUARDIAN', 'ULTIMATE', 'LONG CD', element.toUpperCase()],
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
