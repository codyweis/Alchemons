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
                Tab(text: 'SURVIVAL'),
                Tab(text: 'BOSS'),
                Tab(text: 'EXPLORE'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildSurvivalTab(unit, fc),
                _buildBossTab(bossProfile, battleBasicMove, battleSpecialMove),
                _buildExploreTab(unit, fc),
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
          title: 'Frontline Tank',
          description:
              'Horns are durable frontline companions with high HP and '
              'physical defence. Their Strength bonus boosts basic attack '
              'damage and lets them absorb enemy contact damage. Lower '
              'range keeps them close to the ship.',
        );
      case 'Wing':
        return const _CosmicFamilyRole(
          title: 'Swift Striker',
          description:
              'Wings are fast, long-range attackers. High Speed means '
              'rapid-fire basic attacks, and their Intelligence bonus '
              'gives them excellent range. Fragile but deadly.',
        );
      case 'Let':
        return const _CosmicFamilyRole(
          title: 'Elemental Caster',
          description:
              'Lets channel raw elemental power from a medium range. '
              'Decent Intelligence gives good reach. Strength is lower, '
              'so they rely on their special burst for big damage.',
        );
      case 'Pip':
        return const _CosmicFamilyRole(
          title: 'Speed Gunner',
          description:
              'Pips are extremely fast companions that shred enemies with '
              'a high attack rate. Their Speed bonus significantly '
              'reduces cooldowns on both basic and special attacks.',
        );
      case 'Mane':
        return const _CosmicFamilyRole(
          title: 'AoE Blaster',
          description:
              'Manes balance range and special power. High Beauty boosts '
              'their burst damage, and good Intelligence gives them wide '
              'coverage. Great for clearing groups of enemies.',
        );
      case 'Kin':
        return const _CosmicFamilyRole(
          title: 'Balanced Fighter',
          description:
              'Kins are well-rounded companions with no strong weakness. '
              'They perform consistently in all situations, making them '
              'a reliable choice for exploration.',
        );
      case 'Mystic':
        return const _CosmicFamilyRole(
          title: 'Arcane Specialist',
          description:
              'Mystics have exceptional range and powerful special bursts. '
              'They excel at hitting distant targets but are fragile in '
              'close combat. Keep them protected behind your ship.',
        );
      case 'Mask':
        return const _CosmicFamilyRole(
          title: 'Strategic Fighter',
          description:
              'Masks are sturdy tactical companions with good defence '
              'and moderate range. Their balanced stat spread makes '
              'them adaptable to different encounters.',
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
        name: '$element Dual Strike',
        subtitle: 'Scales with Strength • 2 spread bolts',
        description:
            'Fires two $element bolts with slight spread. Each deals '
            '65% damage, covering a wider area per shot. Great for '
            'hitting groups or fast-moving enemies.',
        icon: Icons.waves,
      );
    case 'Horn':
      return _CosmicBasicInfo(
        name: '$element Heavy Charge',
        subtitle: 'Scales with Strength • Slow & powerful',
        description:
            'Launches a single large, slow $element projectile that deals '
            '160% damage with an oversized hitbox. Slower rate of fire '
            'but devastating on impact.',
        icon: Icons.shield,
      );
    case 'Mask':
      return _CosmicBasicInfo(
        name: '$element Phantom Strike',
        subtitle: 'Scales with Strength • Piercing bolt',
        description:
            'Fires a fast $element bolt that pierces through the first '
            'enemy it hits. Deals 90% damage but can strike multiple '
            'targets in a line.',
        icon: Icons.warning_amber,
      );
    case 'Wing':
      return _CosmicBasicInfo(
        name: '$element Rapid Flick',
        subtitle: 'Scales with Strength • 2 quick bolts',
        description:
            'Unleashes two rapid small $element bolts in quick succession. '
            'Each deals 50% damage but fires 50% faster than normal. '
            'Ideal for sustained pressure.',
        icon: Icons.arrow_forward,
      );
    case 'Kin':
      return _CosmicBasicInfo(
        name: '$element Guided Bolt',
        subtitle: 'Scales with Strength • Homing',
        description:
            'Fires a slower $element bolt that homes toward the nearest '
            'enemy, steering mid-flight. Deals 110% damage and rarely '
            'misses. Great against evasive targets.',
        icon: Icons.favorite,
      );
    case 'Mystic':
      return _CosmicBasicInfo(
        name: '$element Arcane Burst',
        subtitle: 'Scales with Strength • 3 spread bolts',
        description:
            'Releases three small $element bolts in a spread pattern. '
            'Each deals 40% damage, but the combined barrage covers '
            'a wide area. Excellent zone control.',
        icon: Icons.auto_awesome,
      );
    case 'Pip':
      return _CosmicBasicInfo(
        name: '$element Bolt',
        subtitle: 'Scales with Strength • Fast fire rate',
        description:
            'Fires a standard $element bolt at the nearest enemy. '
            'Pip\'s extreme Speed means the attack rate is very high, '
            'compensating for single-bolt damage.',
        icon: Icons.bolt,
      );
    // Let and default
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
        subtitle: 'Shield Charge • Beauty × 2 • 30s',
        description:
            'Gains a shield absorbing 25% max HP, then charges at the nearest enemy '
            'dealing 3× special damage on impact. A nova ring of $element projectiles '
            'bursts outward on activation.',
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
        subtitle: 'Piercing Beam • Beauty × 2 • 30s',
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
        subtitle: 'Meteor Strike • Beauty × 2 • 30s',
        description:
            'Drops a massive $element meteor at the target dealing 3× special '
            'damage with a huge impact radius. '
            '${hasCluster ? 'The meteor fragments mid-flight, splitting into sub-projectiles. ' : ''}'
            'Element determines secondary effects like lingering zones, chain bolts, or freeze areas.',
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
        subtitle: 'Ricochet Salvo • Beauty × 2 • 30s',
        description:
            'Fires a burst of fast $element projectiles that seek out '
            'different enemies. '
            '${hasBounce ? 'Projectiles ricochet between enemies on hit, chaining damage. ' : 'Projectiles home toward the nearest enemy with strong tracking. '}'
            'Element determines count, speed, and behavior.',
        icon: Icons.bolt,
        tags: [
          hasBounce ? 'RICOCHET' : 'HOMING',
          'MULTI-TARGET',
          element.toUpperCase(),
        ],
      );
    case 'Mane':
      return _CosmicSpecialInfo(
        subtitle: 'Barrage Volley • Beauty × 2 • 30s',
        description:
            'Rapid-fire burst of many $element projectiles in a cone or full '
            '360°. Sheer volume overwhelms groups of enemies. Element '
            'determines spread, count, and speed.',
        icon: Icons.waves,
        tags: ['BARRAGE', 'MANY PROJECTILES', element.toUpperCase()],
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
            ? 'Decoy Totem • Beauty × 2 • 30s'
            : 'Mine Field • Beauty × 2 • 30s',
        description: isDecoy
            ? 'Deploys $element decoy totems that taunt nearby enemies. Enemies '
                  'attack the decoy instead of you. When destroyed, the decoy '
                  'explodes into a ring of damaging projectiles.'
            : 'Deploys stationary $element mines around the current position that '
                  'persist for several seconds and damage any enemy passing through.',
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
        subtitle: 'Blessing Pulse • Beauty × 2 • 30s',
        description:
            'Heals self and spawns orbiting $element projectiles that protect '
            'the companion before launching at enemies. Also applies a healing- '
            'over-time blessing. Element determines heal amount and orb count.',
        icon: Icons.favorite,
        tags: ['HEAL', 'ORBITAL', 'BLESSING', element.toUpperCase()],
      );
    case 'Mystic':
      return _CosmicSpecialInfo(
        subtitle: 'Orbital Storm • Beauty × 2 • 30s',
        description:
            'Summons orbiting $element projectiles that spiral outward before '
            'homing toward the nearest enemies. Element determines orb count, '
            'orbit speed, and tracking strength.',
        icon: Icons.auto_awesome,
        tags: ['ORBITAL', 'HOMING', 'SPIRALING', element.toUpperCase()],
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
          stat: 'Strength → HP',
          effect: 'Determines companion max health and survival',
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
          stat: 'Beauty → Burst DMG',
          effect: 'Increases special burst damage (2× multiplier)',
          fc: fc,
        ),
        const SizedBox(height: 8),
        _statEffect(
          icon: Icons.radar,
          stat: 'Intelligence → Range',
          effect: 'Increases attack and special ability range',
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
          stat: 'STR + INT → Defence',
          effect: 'Reduces contact damage taken from enemies',
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
