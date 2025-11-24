import 'package:alchemons/widgets/survival_specs_widget.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/games/survival/survival_combat.dart';
import 'package:alchemons/widgets/creature_detail/section_block.dart';

class BattleScrollArea extends StatelessWidget {
  final FactionTheme theme;
  final Creature creature;
  final CreatureInstance instance;

  const BattleScrollArea({
    super.key,
    required this.theme,
    required this.creature,
    required this.instance,
  });

  @override
  Widget build(BuildContext context) {
    // Instantiate Logic ONCE here to share between widgets
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
          // 1. The Stat Block
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
            child: _BasicAttackCard(theme: theme, unit: unit),
          ),
          const SizedBox(height: 16),

          // 3. Special Ability Section (With Mastery Preview)
          SectionBlock(
            theme: theme,
            title: 'Special Ability',
            child: _SpecialAbilityCard(theme: theme, unit: unit),
          ),

          const SizedBox(height: 16),

          // 4. Placeholder
          Opacity(
            opacity: 0.5,
            child: SectionBlock(
              theme: theme,
              title: 'Boss Battle Configuration',
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  "Turn-based combat analysis unavailable in Survival Mode.",
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===============================================
// WIDGET: BASIC ATTACK CARD
// ===============================================
class _BasicAttackCard extends StatelessWidget {
  final FactionTheme theme;
  final SurvivalUnit unit;

  const _BasicAttackCard({required this.theme, required this.unit});

  @override
  Widget build(BuildContext context) {
    final element = unit.types.firstOrNull ?? 'Normal';
    final cooldown = (1.5 / unit.cooldownReduction).toStringAsFixed(1);
    final passiveEffect = _getElementalPassiveText(element);

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
            Column(
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
                  "Cooldown: ${cooldown}s • Higher Speed = faster attacks",
                  style: TextStyle(
                    color: theme.secondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          "Basic Damage scales with Strength, Elemental Damage with Beauty, attack speed with Speed, and range with Intelligence.",
          style: TextStyle(
            color: theme.text.withOpacity(0.9),
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),

        // Passive Effect Detail
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            "Passive Effect: $passiveEffect",
            style: TextStyle(
              color: theme.text,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  String _getElementalPassiveText(String element) {
    switch (element) {
      case 'Fire':
      case 'Lava':
        return "**Burn** (Damage over time).";
      case 'Ice':
      case 'Water':
      case 'Mud':
      case 'Steam':
        return "**Chill** (Minor pushback).";
      case 'Poison':
      case 'Dark':
        return "**Poison** (Long duration DoT).";
      case 'Lightning':
      case 'Crystal':
      case 'Light':
        return "**Shock** (Chance for critical damage).";
      case 'Earth':
      case 'Plant':
      case 'Dust':
        return "**Heavy Blow** (Guaranteed knockback).";
      default:
        return "No special passive.";
    }
  }
}

// ===============================================
// WIDGET: SPECIAL ABILITY CARD (UPDATED)
// ===============================================
class _SpecialAbilityCard extends StatelessWidget {
  final FactionTheme theme;
  final SurvivalUnit unit;

  const _SpecialAbilityCard({required this.theme, required this.unit});

  @override
  Widget build(BuildContext context) {
    final abilityInfo = _getSpecialAbilityInfo(unit);
    final element = unit.types.firstOrNull ?? 'Normal';

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
              child: Icon(Icons.auto_awesome, color: theme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  abilityInfo.name.toUpperCase(),
                  style: TextStyle(
                    color: theme.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  "$element Element • ${unit.family} Family",
                  style: TextStyle(
                    color: theme.secondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Description
        Text(
          abilityInfo.description,
          style: TextStyle(
            color: theme.text.withOpacity(0.9),
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),

        // NEW: Mastery Bonus (Rank 5 Preview)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.purple.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "MASTERY BONUS (RANK 5)",
                style: TextStyle(
                  color: Colors.purpleAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                abilityInfo.masteryDescription,
                style: TextStyle(
                  color: theme.text,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Stats Footer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Cooldown: ",
                style: TextStyle(color: theme.textMuted, fontSize: 10),
              ),
              Text(
                "${(8.0 / unit.cooldownReduction).toStringAsFixed(1)}s",
                style: TextStyle(
                  color: theme.secondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              Text(
                " • Role: ",
                style: TextStyle(color: theme.textMuted, fontSize: 10),
              ),
              Text(
                abilityInfo.roleLabel,
                style: TextStyle(
                  color: theme.secondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  _AbilityData _getSpecialAbilityInfo(SurvivalUnit unit) {
    final family = unit.family;
    final element = unit.types.firstOrNull ?? 'Normal';

    switch (family) {
      case 'Let':
        return _describeLetAbility(element);
      case 'Pip':
        return _describePipAbility(element);
      case 'Mane':
        return _describeManeAbility(element);
      case 'Horn':
        return _describeHornAbility(element);
      case 'Wing':
        return _describeWingAbility(element);
      case 'Mask':
        return _describeMaskAbility(element);
      case 'Kin':
        return _describeKinAbility(element);
      case 'Mystic':
        return _describeMysticAbility(element);
      default:
        return _AbilityData(
          "SPECIAL",
          "Elemental special attack.",
          "Rank 5: stronger damage and area.",
          "Special",
        );
    }
  }

  _AbilityData _describeLetAbility(String element) {
    switch (element) {
      case 'Fire':
      case 'Lava':
      case 'Blood':
        return _AbilityData(
          "METEOR",
          "Call down a burning meteor that explodes on impact.",
          "Rank 5: Drops three meteors at once.",
          "Burst AoE",
        );

      case 'Water':
      case 'Ice':
      case 'Steam':
      case 'Mud':
        return _AbilityData(
          "FROST METEOR",
          "Meteor slows and pushes enemies where it lands.",
          "Rank 5: Much larger impact area.",
          "Slow / Control",
        );

      case 'Plant':
      case 'Poison':
        return _AbilityData(
          "TOXIC METEOR",
          "Meteor leaves a damaging poison patch.",
          "Rank 5: Bigger patch and more damage over time.",
          "DoT Zone",
        );

      case 'Earth':
      case 'Dust':
      case 'Crystal':
        return _AbilityData(
          "STONE METEOR",
          "Heavy meteor with strong impact damage.",
          "Rank 5: Impact hits much harder.",
          "Heavy Hit",
        );

      case 'Air':
      case 'Lightning':
        return _AbilityData(
          "STORM METEOR",
          "Meteor knocks enemies back on impact.",
          "Rank 5: Huge knockback shockwave.",
          "Knockback",
        );

      case 'Spirit':
      case 'Dark':
        return _AbilityData(
          "SHADOW METEOR",
          "Meteor hits harder against low HP enemies.",
          "Rank 5: Very strong finisher on weakened foes.",
          "Execute",
        );

      case 'Light':
        return _AbilityData(
          "HOLY METEOR",
          "Meteor damages enemies and lightly heals allies nearby.",
          "Rank 5: Bigger heal and wider blast.",
          "Heal / Damage",
        );

      default:
        return _AbilityData(
          "METEOR",
          "Elemental meteor that explodes in an area.",
          "Rank 5: More meteors and more damage.",
          "AoE",
        );
    }
  }

  _AbilityData _describePipAbility(String element) {
    switch (element) {
      case 'Fire':
      case 'Lava':
        return _AbilityData(
          "FLAME RICOCHET",
          "Shots bounce between enemies and burn them.",
          "Rank 5: More bounces and higher burn.",
          "Chain / DoT",
        );

      case 'Blood':
        return _AbilityData(
          "BLOOD RICOCHET",
          "Bouncing shots drain enemies and heal the Orb a bit.",
          "Rank 5: More bounces and more Orb heal.",
          "Drain / Chain",
        );

      case 'Water':
      case 'Ice':
      case 'Steam':
        return _AbilityData(
          "TIDE RICOCHET",
          "Bouncing shots chip enemies and gently push them.",
          "Rank 5: More bounces and stronger control.",
          "Chip / Control",
        );

      case 'Plant':
      case 'Poison':
        return _AbilityData(
          "TOXIC RICOCHET",
          "Bounces spread poison between targets.",
          "Rank 5: Longer poison duration.",
          "Poison Spread",
        );

      case 'Earth':
      case 'Mud':
      case 'Crystal':
        return _AbilityData(
          "ROCK RICOCHET",
          "Heavier bounces that hit harder.",
          "Rank 5: Stronger hits and more bounces.",
          "Heavy Chain",
        );

      case 'Air':
      case 'Dust':
      case 'Lightning':
        return _AbilityData(
          "STORM RICOCHET",
          "Fast bouncing shots that chain between enemies.",
          "Rank 5: Very fast chains and more targets.",
          "Fast Chain",
        );

      case 'Spirit':
      case 'Dark':
        return _AbilityData(
          "SOUL RICOCHET",
          "Bounces add small drain on each hit.",
          "Rank 5: Stronger drain per bounce.",
          "Drain Chain",
        );

      case 'Light':
        return _AbilityData(
          "RADIANT RICOCHET",
          "Bounces slightly heal the Orb while damaging enemies.",
          "Rank 5: Extra heals and more bounces.",
          "Heal / Chain",
        );

      default:
        return _AbilityData(
          "RICOCHET",
          "Projectiles bounce between nearby enemies.",
          "Rank 5: More bounces and damage.",
          "Chain",
        );
    }
  }

  _AbilityData _describeManeAbility(String element) {
    switch (element) {
      case 'Fire':
      case 'Lava':
        return _AbilityData(
          "FIRE HAZARD",
          "Creates a burning zone that damages enemies over time.",
          "Rank 5: Larger, more damaging fire zone.",
          "DoT Zone",
        );

      case 'Blood':
        return _AbilityData(
          "BLOOD HAZARD",
          "Zone drains enemies and lightly heals the caster.",
          "Rank 5: More drain and more healing.",
          "Drain Zone",
        );

      case 'Water':
      case 'Ice':
      case 'Steam':
      case 'Mud':
        return _AbilityData(
          "FROST HAZARD",
          "Zone slows and chips enemies inside.",
          "Rank 5: Very strong slow (near root).",
          "Slow Zone",
        );

      case 'Plant':
      case 'Poison':
        return _AbilityData(
          "TOXIC HAZARD",
          "Zone poisons enemies that stay inside.",
          "Rank 5: Stronger, longer poison.",
          "Poison Zone",
        );

      case 'Earth':
      case 'Crystal':
        return _AbilityData(
          "STONE HAZARD",
          "Zone slightly pushes enemies away from the Orb.",
          "Rank 5: Stronger control and more pushes.",
          "Control Zone",
        );

      case 'Air':
      case 'Dust':
      case 'Lightning':
        return _AbilityData(
          "STORM HAZARD",
          "Zone jitters or shocks enemies inside.",
          "Rank 5: More frequent shocks.",
          "Disrupt Zone",
        );

      case 'Spirit':
      case 'Dark':
        return _AbilityData(
          "SHADOW HAZARD",
          "Zone saps enemy HP and helps sustain the caster.",
          "Rank 5: Stronger sap effect.",
          "Sap Zone",
        );

      case 'Light':
        return _AbilityData(
          "HOLY HAZARD",
          "Zone damages enemies and lightly heals allies inside.",
          "Rank 5: More healing and damage.",
          "Heal / DoT Zone",
        );

      default:
        return _AbilityData(
          "HAZARD",
          "Creates a small damaging zone on the ground.",
          "Rank 5: Larger and stronger zone.",
          "Area Denial",
        );
    }
  }

  _AbilityData _describeHornAbility(String element) {
    switch (element) {
      case 'Fire':
      case 'Lava':
        return _AbilityData(
          "FIRE NOVA",
          "Nova damages and slightly burns enemies around you.",
          "Rank 5: Much stronger nova.",
          "Close AoE",
        );

      case 'Blood':
        return _AbilityData(
          "BLOOD NOVA",
          "Nova hurts enemies and heals you a bit.",
          "Rank 5: More damage and more healing.",
          "Drain AoE",
        );

      case 'Water':
      case 'Ice':
      case 'Steam':
        return _AbilityData(
          "FROST NOVA",
          "Nova pushes enemies away and slows them.",
          "Rank 5: Strong push and slow.",
          "Defensive CC",
        );

      case 'Plant':
      case 'Poison':
        return _AbilityData(
          "TOXIC NOVA",
          "Nova inflicts poison in a short radius.",
          "Rank 5: Stronger poison.",
          "Poison AoE",
        );

      case 'Earth':
      case 'Mud':
      case 'Crystal':
        return _AbilityData(
          "STONE NOVA",
          "Nova knocks enemies back and toughens you.",
          "Rank 5: Very strong knockback.",
          "Knockback",
        );

      case 'Air':
      case 'Dust':
      case 'Lightning':
        return _AbilityData(
          "STORM NOVA",
          "Nova tosses enemies away from you.",
          "Rank 5: Wider range and stronger toss.",
          "Displacement",
        );

      case 'Spirit':
      case 'Dark':
        return _AbilityData(
          "SHADOW NOVA",
          "Nova deals damage all around.",
          "Rank 5: Higher damage and bigger radius.",
          "Burst AoE",
        );

      case 'Light':
        return _AbilityData(
          "HOLY NOVA",
          "Nova damages nearby enemies and heals you.",
          "Rank 5: Bigger heal and radius.",
          "Heal / Damage",
        );

      default:
        return _AbilityData(
          "NOVA",
          "Defensive blast around the Guardian.",
          "Rank 5: Bigger and stronger blast.",
          "Defensive AoE",
        );
    }
  }

  _AbilityData _describeWingAbility(String element) {
    switch (element) {
      case 'Fire':
      case 'Lava':
        return _AbilityData(
          "FLAME LANCE",
          "Shoots a piercing fire beam through enemies.",
          "Rank 5: Much wider, stronger beam.",
          "Piercing Line",
        );

      case 'Blood':
        return _AbilityData(
          "BLOOD LANCE",
          "Beam pierces enemies and heals you slightly.",
          "Rank 5: More pierces and more healing.",
          "Lifesteal Beam",
        );

      case 'Water':
      case 'Ice':
      case 'Steam':
        return _AbilityData(
          "FROST LANCE",
          "Beam slows enemies along its path.",
          "Rank 5: Strong slow and longer beam.",
          "Slow Beam",
        );

      case 'Plant':
      case 'Poison':
        return _AbilityData(
          "TOXIC LANCE",
          "Beam poisons enemies it pierces.",
          "Rank 5: Longer, stronger poison.",
          "Poison Beam",
        );

      case 'Earth':
      case 'Mud':
      case 'Crystal':
        return _AbilityData(
          "STONE LANCE",
          "Heavy beam that chunks enemies.",
          "Rank 5: Very high damage beam.",
          "Heavy Piercing",
        );

      case 'Air':
      case 'Dust':
      case 'Lightning':
        return _AbilityData(
          "STORM LANCE",
          "Fast beam that cuts through many targets.",
          "Rank 5: Massive Hyper Beam style shot.",
          "Hyper Beam",
        );

      case 'Spirit':
      case 'Dark':
        return _AbilityData(
          "SHADOW LANCE",
          "Beam deals more damage to low HP enemies.",
          "Rank 5: Very strong finisher line.",
          "Execute Beam",
        );

      case 'Light':
        return _AbilityData(
          "HOLY LANCE",
          "Beam damages enemies and slightly heals you.",
          "Rank 5: More healing and range.",
          "Heal / Damage",
        );

      default:
        return _AbilityData(
          "LANCE",
          "Piercing line attack.",
          "Rank 5: Wider and stronger line.",
          "Piercing",
        );
    }
  }

  _AbilityData _describeMaskAbility(String element) {
    switch (element) {
      case 'Fire':
      case 'Lava':
        return _AbilityData(
          "FIRE SINGULARITY",
          "Pulls enemies in and burns them.",
          "Rank 5: Bigger pull and more burn.",
          "Pull / DoT",
        );

      case 'Blood':
        return _AbilityData(
          "BLOOD SINGULARITY",
          "Pulls enemies in and drains HP to heal you.",
          "Rank 5: Much stronger drain.",
          "Pull / Drain",
        );

      case 'Water':
      case 'Ice':
      case 'Steam':
        return _AbilityData(
          "FROST SINGULARITY",
          "Pulls and slows enemies in its center.",
          "Rank 5: Strong slow and control.",
          "Pull / Slow",
        );

      case 'Plant':
      case 'Poison':
        return _AbilityData(
          "TOXIC SINGULARITY",
          "Pulls enemies and stacks poison on them.",
          "Rank 5: Stronger poison.",
          "Pull / Poison",
        );

      case 'Earth':
      case 'Mud':
      case 'Crystal':
        return _AbilityData(
          "STONE SINGULARITY",
          "Pulls enemies and holds them in place briefly.",
          "Rank 5: Very strong hold and damage.",
          "Pull / Hold",
        );

      case 'Air':
      case 'Dust':
      case 'Lightning':
        return _AbilityData(
          "STORM SINGULARITY",
          "Pulls enemies and shocks them inside.",
          "Rank 5: More shocks and damage.",
          "Pull / Shock",
        );

      case 'Spirit':
        return _AbilityData(
          "SPIRIT SINGULARITY",
          "Pulls enemies and softens them for a big burst.",
          "Rank 5: Huge detonation on trapped foes.",
          "Pull / Burst",
        );

      case 'Dark':
        return _AbilityData(
          "EVENT HORIZON",
          "Pulls enemies into a lethal dark core.",
          "Rank 5: Executes non-boss enemies under 30% HP.",
          "Execute",
        );

      case 'Light':
        return _AbilityData(
          "HOLY SINGULARITY",
          "Pulls enemies and lightly heals allies near the center.",
          "Rank 5: Bigger heal + burst.",
          "Pull / Heal",
        );

      default:
        return _AbilityData(
          "SINGULARITY",
          "Pulls enemies into a void and then explodes.",
          "Rank 5: Larger pull and explosion.",
          "Pull / AoE",
        );
    }
  }

  _AbilityData _describeKinAbility(String element) {
    switch (element) {
      case 'Fire':
      case 'Lava':
        return _AbilityData(
          "FIRE BLESSING",
          "Heals allies and burns nearby enemies.",
          "Rank 5: Stronger heal and burn.",
          "Heal / DoT",
        );

      case 'Blood':
        return _AbilityData(
          "BLOOD BLESSING",
          "Heals allies and converts some into damage to foes.",
          "Rank 5: More damage from each heal.",
          "Heal / Convert",
        );

      case 'Water':
      case 'Ice':
      case 'Steam':
        return _AbilityData(
          "TIDE BLESSING",
          "Heals allies near the Orb over time.",
          "Rank 5: Longer, stronger regen.",
          "Regen",
        );

      case 'Plant':
      case 'Poison':
        return _AbilityData(
          "VERDANT BLESSING",
          "Heals the team and poisons enemies near the base.",
          "Rank 5: Stronger poison and heal.",
          "Heal / Poison",
        );

      case 'Earth':
      case 'Mud':
      case 'Crystal':
        return _AbilityData(
          "STONE BLESSING",
          "Heals and toughens allies, especially the lowest HP.",
          "Rank 5: Much stronger sustain.",
          "Defensive Heal",
        );

      case 'Air':
      case 'Dust':
      case 'Lightning':
        return _AbilityData(
          "STORM BLESSING",
          "Heals allies and pushes/shocks enemies from the Orb.",
          "Rank 5: Big push and more shock.",
          "Heal / Displace",
        );

      case 'Spirit':
      case 'Dark':
        return _AbilityData(
          "SHADOW BLESSING",
          "Heals allies and damages enemies near the Orb.",
          "Rank 5: Stronger shadow burst.",
          "Heal / Burst",
        );

      case 'Light':
        return _AbilityData(
          "HOLY NOVA",
          "Big team heal and Light damage around the Orb.",
          "Rank 5: Very large heal and AoE.",
          "Heal / AoE",
        );

      default:
        return _AbilityData(
          "BLESSING",
          "Heals the Guardian and the Orb.",
          "Rank 5: Bigger heal and extra effects.",
          "Heal",
        );
    }
  }

  _AbilityData _describeMysticAbility(String element) {
    switch (element) {
      case 'Fire':
      case 'Lava':
        return _AbilityData(
          "FIRE ORBITALS",
          "Orbitals seek targets and explode in small fire bursts.",
          "Rank 5: Many more orbitals.",
          "Auto Burst",
        );

      case 'Blood':
        return _AbilityData(
          "BLOOD ORBITALS",
          "Hits heal the caster for a portion of damage.",
          "Rank 5: Much stronger lifesteal.",
          "Lifesteal Orbs",
        );

      case 'Water':
      case 'Ice':
      case 'Steam':
        return _AbilityData(
          "FROST ORBITALS",
          "Orbitals chip and slow enemies on hit.",
          "Rank 5: Longer slows.",
          "Slow Orbs",
        );

      case 'Plant':
      case 'Poison':
        return _AbilityData(
          "TOXIC ORBITALS",
          "Hits leave small poison patches on the ground.",
          "Rank 5: Larger, stronger patches.",
          "Poison Orbs",
        );

      case 'Earth':
      case 'Mud':
      case 'Crystal':
        return _AbilityData(
          "STONE ORBITALS",
          "Orbitals hit hard and sometimes chain to nearby enemies.",
          "Rank 5: More chains and more damage.",
          "Heavy Orbs",
        );

      case 'Air':
      case 'Dust':
      case 'Lightning':
        return _AbilityData(
          "STORM ORBITALS",
          "Fast-seeking orbs that zap enemies.",
          "Rank 5: Many fast orbs (swarm).",
          "Zap Orbs",
        );

      case 'Spirit':
      case 'Dark':
        return _AbilityData(
          "SHADOW ORBITALS",
          "Orbitals hit for spectral damage and softly heal the caster.",
          "Rank 5: Stronger hits and more healing.",
          "Drain Orbs",
        );

      case 'Light':
        return _AbilityData(
          "HOLY ORBITALS",
          "Orbitals damage enemies and slightly heal allies near impact.",
          "Rank 5: More orbs and more healing.",
          "Heal / Damage Orbs",
        );

      default:
        return _AbilityData(
          "ORBITALS",
          "Spawns orbiting projectiles that seek enemies.",
          "Rank 5: Spawns many more orbitals.",
          "Auto-Seeker",
        );
    }
  }
}

class _AbilityData {
  final String name;
  final String description;
  final String masteryDescription;
  final String roleLabel;
  _AbilityData(
    this.name,
    this.description,
    this.masteryDescription,
    this.roleLabel,
  );
}
