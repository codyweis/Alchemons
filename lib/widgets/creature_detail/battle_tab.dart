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

    final moveStyle = BattleMove.styleForFamily(unit.family);
    final battleSpecialMove = BattleMove.getSpecialMove(unit.family);
    final battleBasicMove = BattleMove.getBasicMove(unit.family);
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
                Tab(text: 'SURVIVAL'),
                Tab(text: 'BOSS'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildSurvivalTab(unit, fc),
                _buildBossTab(
                  moveStyle,
                  bossProfile,
                  battleBasicMove,
                  battleSpecialMove,
                ),
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
    FamilyMoveStyle moveStyle,
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
              specialMoveSummary: moveStyle.summary,
            ),
          ),
        ],
      ),
    );
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

  const _BossCombatProfileCard({
    required this.profile,
    required this.basicMoveName,
    required this.specialMoveName,
    required this.specialMoveSummary,
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
  int _selectedRank = 0;

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
            _rankButton(0, 'BASE', null, fc),
            const SizedBox(width: 8),
            _rankButton(1, 'I', 'UNLOCK', fc),
            const SizedBox(width: 8),
            _rankButton(2, 'II', 'POWER', fc),
            const SizedBox(width: 8),
            _rankButton(3, 'III', 'ULTIMATE', fc),
          ],
        ),
        const SizedBox(height: 12),
        if (_selectedRank > 0) _rankDescriptionBox(family, element, fc),
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
              color: isSelected ? activeColor.withValues(alpha: 0.8) : fc.borderDim,
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
