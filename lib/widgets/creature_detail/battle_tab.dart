import 'package:alchemons/games/survival/special_attacks/ability_config.dart';
import 'package:alchemons/widgets/survival_specs_widget.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/games/survival/survival_combat.dart';
import 'package:alchemons/widgets/creature_detail/section_block.dart';

class ImprovedBattleScrollArea extends StatelessWidget {
  final FactionTheme theme;
  final Creature creature;
  final CreatureInstance instance;

  const ImprovedBattleScrollArea({
    super.key,
    required this.theme,
    required this.creature,
    required this.instance,
  });

  @override
  Widget build(BuildContext context) {
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

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Stat Block
          SectionBlock(
            theme: theme,
            title: 'Survival Metrics',
            child: SurvivalSpecsWidget(
              theme: theme,
              creature: creature,
              instance: instance,
            ),
          ),
          const SizedBox(height: 16),

          // 2. Basic Attack Section
          SectionBlock(
            theme: theme,
            title: 'Basic Attack',
            child: _DynamicBasicAttackCard(theme: theme, unit: unit),
          ),
          const SizedBox(height: 16),

          // 3. Special Ability Section (Dynamic)
          SectionBlock(
            theme: theme,
            title: 'Special Ability',
            child: _DynamicSpecialAbilityCard(theme: theme, unit: unit),
          ),

          const SizedBox(height: 16),

          // 4. Stat Explanations
          SectionBlock(
            theme: theme,
            title: 'Stat Effects',
            child: _StatEffectsCard(theme: theme),
          ),
        ],
      ),
    );
  }
}

// ===============================================
// DYNAMIC BASIC ATTACK CARD
// ===============================================
class _DynamicBasicAttackCard extends StatelessWidget {
  final FactionTheme theme;
  final SurvivalUnit unit;

  const _DynamicBasicAttackCard({required this.theme, required this.unit});

  @override
  Widget build(BuildContext context) {
    final element = unit.types.firstOrNull ?? 'Normal';
    final cooldown = (1.5 / unit.cooldownReduction).toStringAsFixed(1);
    final passiveEffect = AbilitySystemConfig.getPassiveEffectDescription(
      element,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.primary.withOpacity(0.5)),
              ),
              child: Icon(Icons.star_border, color: theme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "ELEMENTAL PROJECTILE",
                    style: TextStyle(
                      color: theme.text,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    "Cooldown: ${cooldown}s • Scales with Speed",
                    style: TextStyle(
                      color: theme.secondary,
                      fontSize: 10,
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
          "Fires elemental projectiles at enemies. Basic damage scales with Strength, elemental damage with Beauty, attack speed with Speed, and range with Intelligence.",
          style: TextStyle(
            color: theme.text.withOpacity(0.9),
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),

        // Dynamic Passive Effect
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: _getElementColor(element).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _getPassiveIcon(element),
                size: 14,
                color: _getElementColor(element),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  passiveEffect,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Damage Preview
        _DamagePreview(theme: theme, unit: unit),
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

class _DamagePreview extends StatelessWidget {
  final FactionTheme theme;
  final SurvivalUnit unit;

  const _DamagePreview({required this.theme, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          _statChip('DMG', '${unit.physAtk}', Icons.gavel),
          const SizedBox(width: 8),
          _statChip('ELEM', '${unit.elemAtk}', Icons.auto_awesome),
          const SizedBox(width: 8),
          _statChip(
            'RNG',
            unit.attackRange.toStringAsFixed(0),
            Icons.my_location,
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: theme.secondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                color: theme.text,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===============================================
// DYNAMIC SPECIAL ABILITY CARD (3-TIER SYSTEM)
// ===============================================
class _DynamicSpecialAbilityCard extends StatefulWidget {
  final FactionTheme theme;
  final SurvivalUnit unit;

  const _DynamicSpecialAbilityCard({required this.theme, required this.unit});

  @override
  State<_DynamicSpecialAbilityCard> createState() =>
      _DynamicSpecialAbilityCardState();
}

class _DynamicSpecialAbilityCardState
    extends State<_DynamicSpecialAbilityCard> {
  int _selectedRank = 0; // 0 = base, 1 = unlock, 2 = strengthened, 3 = ultimate

  @override
  Widget build(BuildContext context) {
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
        // Ability Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.theme.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.theme.primary.withOpacity(0.5),
                ),
              ),
              child: Icon(
                _getFamilyIcon(family),
                color: widget.theme.primary,
                size: 20,
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
                      color: widget.theme.text,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    "Scales with Beauty • 3 elemental upgrades",
                    style: TextStyle(
                      color: widget.theme.secondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Base Description
        Text(
          baseDescription,
          style: TextStyle(
            color: widget.theme.text.withOpacity(0.9),
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),

        // Rank Selector
        Text(
          "ELEMENTAL MASTERY",
          style: TextStyle(
            color: widget.theme.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),

        // Rank Buttons (4 buttons: BASE + 3 tiers)
        Row(
          children: [
            _rankButton(0, 'BASE', null),
            const SizedBox(width: 8),
            _rankButton(1, 'I', 'UNLOCK'),
            const SizedBox(width: 8),
            _rankButton(2, 'II', 'POWER'),
            const SizedBox(width: 8),
            _rankButton(3, 'III', 'ULTIMATE'),
          ],
        ),
        const SizedBox(height: 12),

        // Rank Description
        if (_selectedRank > 0) _rankDescriptionBox(family, element),
      ],
    );
  }

  Widget _rankButton(int rank, String label, String? subtitle) {
    final isSelected = _selectedRank == rank;
    final isUltimate = rank == 3;

    // Ultimate tier gets special styling
    final borderColor = isSelected
        ? (isUltimate ? Colors.amber : widget.theme.primary)
        : widget.theme.primary.withOpacity(0.2);
    final bgColor = isSelected
        ? (isUltimate
              ? Colors.amber.withOpacity(0.2)
              : widget.theme.primary.withOpacity(0.3))
        : Colors.black26;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedRank = rank),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? (isUltimate ? Colors.amber : widget.theme.text)
                      : widget.theme.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isSelected
                        ? (isUltimate
                              ? Colors.amber.withOpacity(0.8)
                              : widget.theme.secondary)
                        : widget.theme.textMuted.withOpacity(0.6),
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

  Widget _rankDescriptionBox(String family, String element) {
    final description = AbilitySystemConfig.getAbilityDescription(
      family,
      element,
      _selectedRank,
    );

    final isUltimate = _selectedRank == 3;
    final tierLabel = _getTierLabel(_selectedRank);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUltimate
              ? [Colors.amber.withOpacity(0.15), Colors.orange.withOpacity(0.1)]
              : [
                  widget.theme.primary.withOpacity(0.15),
                  widget.theme.secondary.withOpacity(0.1),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUltimate
              ? Colors.amber.withOpacity(0.5)
              : widget.theme.primary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isUltimate
                  ? Colors.amber.withOpacity(0.2)
                  : widget.theme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                Text(
                  _getRomanNumeral(_selectedRank),
                  style: TextStyle(
                    color: isUltimate ? Colors.amber : widget.theme.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  tierLabel,
                  style: TextStyle(
                    color: (isUltimate ? Colors.amber : widget.theme.primary)
                        .withOpacity(0.7),
                    fontSize: 6,
                    fontWeight: FontWeight.w700,
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
                color: widget.theme.text,
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
        return 'Ricochet Shot';
      case 'Mane':
        return 'Elemental Barrage';
      case 'Mask':
        return 'Trap Field';
      case 'Horn':
        return 'Protective Nova';
      case 'Wing':
        return 'Piercing Beam';
      case 'Kin':
        return 'Orb Blessing';
      case 'Mystic':
        return 'Orbital Strike';
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

// ===============================================
// STAT EFFECTS CARD
// ===============================================
class _StatEffectsCard extends StatelessWidget {
  final FactionTheme theme;

  const _StatEffectsCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statEffect(
          icon: Icons.favorite,
          stat: 'Max HP',
          effect: 'Guardian survivability and health pool',
        ),
        const SizedBox(height: 8),
        _statEffect(
          icon: Icons.gavel,
          stat: 'Strength',
          effect: 'Basic attack physical damage',
        ),
        const SizedBox(height: 8),
        _statEffect(
          icon: Icons.psychology,
          stat: 'Intelligence',
          effect: 'Attack range and cooldown reduction',
        ),
        const SizedBox(height: 8),
        _statEffect(
          icon: Icons.auto_awesome,
          stat: 'Beauty',
          effect: 'Elemental damage and ability power',
        ),
        const SizedBox(height: 8),
        _statEffect(
          icon: Icons.speed,
          stat: 'Speed',
          effect: 'Attack speed (from base stats)',
        ),
      ],
    );
  }

  Widget _statEffect({
    required IconData icon,
    required String stat,
    required String effect,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 14, color: theme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stat,
                style: TextStyle(
                  color: theme.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                effect,
                style: TextStyle(
                  color: theme.textMuted,
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
