import 'dart:async';
import 'dart:math';

import 'package:alchemons/models/family_combat_copy.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/purity_stat_bonus.dart';
import 'package:alchemons/models/variant_stat_bonus.dart';
import 'package:alchemons/services/onboarding_tasks.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/shared/alchemon_combat_stats.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/utils/instance_purity_util.dart';
import 'package:alchemons/screens/ability_preview_screen.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/perf/viewport_ticker_gate.dart';

part 'battle_sheet.dart';

class ImprovedBattleScrollArea extends StatefulWidget {
  final FactionTheme? theme;
  final Creature creature;
  final CreatureInstance instance;

  /// The live arena at the top. Off in widget tests, which cannot load the
  /// game's assets.
  final bool liveStage;

  const ImprovedBattleScrollArea({
    super.key,
    this.theme,
    required this.creature,
    required this.instance,
    this.liveStage = true,
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
    return _BattleSheet(
      instance: widget.instance,
      creature: widget.creature,
      family: widget.creature.mutationFamily ?? 'Unknown',
      element: widget.creature.types.firstOrNull ?? 'Normal',
      liveStage: widget.liveStage,
    );
  }
}

String _statName(AlchemonStat stat) => switch (stat) {
  AlchemonStat.strength => 'Strength',
  AlchemonStat.intelligence => 'Intelligence',
  AlchemonStat.beauty => 'Beauty',
  AlchemonStat.speed => 'Speed',
};

String _statAbbrev(AlchemonStat stat) => switch (stat) {
  AlchemonStat.strength => 'STR',
  AlchemonStat.intelligence => 'INT',
  AlchemonStat.beauty => 'BEA',
  AlchemonStat.speed => 'SPD',
};

/// The stats behind one combat number, strongest share first: 'STR·INT'.
String _feedSource(Map<AlchemonStat, double?> feeds) {
  final stats = feeds.keys.toList()
    ..sort((a, b) => (feeds[b] ?? 0).compareTo(feeds[a] ?? 0));
  return stats.map(_statAbbrev).join('·');
}

/// 'Strength (80%) and Intelligence (20%)', from the stats a blend names a
/// share for. A lone stat goes without its 100%.
String _shareLine(Map<AlchemonStat, double?> feeds) {
  final parts = feeds.entries.where((e) => e.value != null).toList()
    ..sort((a, b) => b.value!.compareTo(a.value!));
  if (parts.isEmpty) return '';
  if (parts.length == 1) return _statName(parts.single.key);
  final named = parts
      .map((e) => '${_statName(e.key)} (${(e.value! * 100).round()}%)')
      .toList();
  return '${named.sublist(0, named.length - 1).join(', ')} and ${named.last}';
}

/// How the family's special scales: what powers it and what brings it back.
/// Read from the same contract the game runs on (alchemon_combat_stats.dart).
/// Then what every cast in the family does besides its element's effect.
List<CosmicAbilityDescriptionLine> _specialScalingLines(
  String family,
  String element,
) {
  final feeds = alchemonStatFeeds(family);
  final power = _shareLine(feeds[AlchemonCombatOutput.special]!);
  final recharge = _shareLine(feeds[AlchemonCombatOutput.specialInterval]!);
  final f = family.toLowerCase();
  final passive = isPassiveOnlyCosmicAbility(family, element);
  final also = switch (f) {
    'horn' when !passive => 'Every cast also shields this Horn, more with '
        'Beauty.',
    'wing' when !const {'Fire', 'Poison', 'Lightning'}.contains(element) =>
      'The beam starts weak and hits harder the longer it stays on one '
          'enemy.',
    'kin' when !passive => 'Every cast also heals this Kin, and the orb a '
        'little.',
    'mystic' => 'The world lasts while this Mystic is alive and deployed.',
    _ => null,
  };
  return [
    CosmicAbilityDescriptionLine(
      label: 'Power',
      body: 'Stronger with $power.',
    ),
    if (!passive)
      CosmicAbilityDescriptionLine(
        label: 'Recharge',
        body: switch (f) {
          'mystic' => 'About a minute after it is deployed, whatever its '
              'stats. Each auto attack brings it a little sooner.',
          _ => 'Faster with $recharge. A stronger special also comes back '
              'sooner.',
        },
      ),
    if (also != null) CosmicAbilityDescriptionLine(label: 'Also', body: also),
    if (f == 'mystic')
      const CosmicAbilityDescriptionLine(
        label: 'Elsewhere',
        body:
            'Survival only. In Cosmic Space and the planet dungeons a Mystic fights with its auto attack.',
      ),
  ];
}

/// Seconds as the tab prints them: hundredths under a second, where a
/// fast attacker's differences live.
String _seconds(double s) => s < 1
    ? '${s.toStringAsFixed(2)}s'
    : s < 10
    ? '${s.toStringAsFixed(1)}s'
    : '${s.round()}s';

/// Lists every persistent percentage modifier that feeds this creature's
/// battle readout, grouped by its player-facing source.
class _CombatBoostsCard extends StatelessWidget {
  const _CombatBoostsCard({required this.entries});

  final List<_BoostEntry> entries;

  static const _stats = <(String, String)>[
    ('Speed', kStatSpeed),
    ('Intelligence', kStatIntelligence),
    ('Strength', kStatStrength),
    ('Beauty', kStatBeauty),
  ];

  /// Only the boosts this creature actually has. An empty list means the
  /// section is not shown at all; a row that says "no boost" is not a boost.
  static List<_BoostEntry> entriesFor(
    BuildContext context, {
    required CreatureInstance instance,
    required Creature creature,
    required String family,
  }) {
    final constellation = context.watch<ConstellationEffectsService>();
    final entries = <_BoostEntry>[];

    final natureIds = <String>{
      if (instance.natureId?.isNotEmpty == true) instance.natureId!,
      if (instance.natureId2?.isNotEmpty == true) instance.natureId2!,
    };
    for (final id in natureIds) {
      final nature = NatureCatalog.byId(id);
      if (nature == null) continue;
      final parts = _stats
          .map((stat) {
            final bonus = nature.effect.getDouble(
              'stat_${stat.$2}_bonus',
              fallback: 0,
            );
            return bonus == 0 ? null : '${stat.$1} ${_signedPercent(bonus)}';
          })
          .whereType<String>()
          .toList(growable: false);
      if (parts.isEmpty) continue;
      entries.add(_BoostEntry('Nature · ${nature.id}', parts.join(' · ')));
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
    if (enhancementParts.isNotEmpty) {
      entries.add(_BoostEntry('Enhancement', enhancementParts.join(' · ')));
    }

    final purity = classifyInstancePurity(instance, species: creature);
    final purityBonus = resolvePurityStatBonus(
      instanceId: instance.instanceId,
      isElementallyPure: purity.isElementallyPure,
      isSpeciesPure: purity.isSpeciesPure,
    );
    if (!purityBonus.isNone && purityBonus.statKey != null) {
      entries.add(
        _BoostEntry(
          'Purity · ${purityBonus.lineageLabel}',
          '${_statLabel(purityBonus.statKey!)} +${(purityBonus.bonus * 100).round()}%',
        ),
      );
    }

    final variantBonus = resolveVariantStatBonus(
      variantFaction: instance.variantFaction,
      joinedFaction: context.watch<FactionService>().current?.name,
    );
    if (!variantBonus.isNone) {
      final percent = '+${(variantBonus.bonus * 100).round()}%';
      entries.add(
        _BoostEntry(
          variantBonus.joined
              ? 'Variant · ${variantBonus.faction}, your faction'
              : 'Variant · ${variantBonus.faction}',
          variantBonus.statKeys.length == 4
              ? 'All stats $percent'
              : '${_statLabel(variantBonus.statKeys.single)} $percent',
        ),
      );
    }

    final constellationParts = <String>[];
    for (final stat in _stats) {
      final percent = constellation.getCombatStatBonusPercent(stat.$2);
      if (percent > 0) constellationParts.add('${stat.$1} +$percent%');
    }
    if (constellationParts.isNotEmpty) {
      entries.add(
        _BoostEntry('Combat Constellation', constellationParts.join(' · ')),
      );
    }

    final frameParts = <String>[];
    void addFramePart(String label, double multiplier) {
      final percent = ((multiplier - 1) * 100).round();
      if (percent == 0) return;
      frameParts.add('$label ${_signedPercent(percent / 100)}');
    }

    final frame = alchemonFamilyFrame(family);
    addFramePart('HP', frame.hp);
    addFramePart('P-ATK', frame.physAtk);
    addFramePart('E-ATK & SPECIAL', frame.elemAtk);
    addFramePart('P-DEF', frame.physDef);
    addFramePart('E-DEF', frame.elemDef);
    addFramePart('Auto range', frame.autoRange);
    addFramePart('Special range', frame.specialRange);
    addFramePart('Auto cooldown', frame.basicCooldown);
    addFramePart('Special cooldown', frame.specialCooldown);
    if (frameParts.isNotEmpty) {
      entries.add(
        _BoostEntry(
          'Family Frame · ${family.toUpperCase()}',
          frameParts.join(' · '),
        ),
      );
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    final theme = context.read<FactionTheme>();
    final accent = bracketReadableAccent(theme);
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

class _AbilityDescriptionText extends StatelessWidget {
  const _AbilityDescriptionText({
    required this.description,
    required this.accent,
    required this.textColor,
    this.extraLines = const [],
  });

  final String description;
  final List<CosmicAbilityDescriptionLine> extraLines;
  final Color accent;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final parsed = cosmicAbilityDescriptionLines(description);
    final plain = parsed.length == 1 && parsed.first.label.isEmpty;
    final lines = [if (!plain) ...parsed, ...extraLines];
    final plainText = plain
        ? Text(
            parsed.first.body,
            style: bracketText(
              context,
              12.5,
              textColor,
              weight: FontWeight.w500,
            ),
            strutStyle: const StrutStyle(height: 1.45),
          )
        : null;
    if (lines.isEmpty) return plainText!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (plainText != null) ...[plainText, const SizedBox(height: 10)],
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
  // What the attack does comes from the family's combat copy, the same line
  // the survival roster and mastery tree show.
  final (name, icon) = switch (family) {
    'Mane' => ('$element Twin Blades', AppIcons.waves),
    'Horn' => ('$element Ram Shot', AppIcons.shield),
    'Mask' => ('$element Needle', AppIcons.warning_amber),
    'Wing' => ('$element Feather Pair', AppIcons.arrow_forward),
    'Kin' => ('$element Charged Beam', AppIcons.favorite),
    'Mystic' => ('$element Arcane Triad', AppIcons.auto_awesome),
    'Pip' => ('$element Dart Burst', AppIcons.bolt),
    'Let' => ('$element Meteor Stone', AppIcons.south),
    _ => ('$element Bolt', AppIcons.gps_fixed),
  };
  return _CosmicBasicInfo(
    name: name,
    description:
        FamilyCombatCopy.forName(family)?.attack ??
        'Fires a $element shot at the nearest enemy in range.',
    icon: icon,
  );
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
      final description = switch (element) {
        'Fire' =>
          'Charges through enemies and leaves a trail of fire. Enemies are drawn into the flames and burn while they stand in them.',
        'Lava' =>
          'A slow, heavy charge that hits hard. Each enemy it kills bursts into flames that chase nearby enemies, more with Beauty.',
        'Lightning' =>
          'Dashes in, then holds still for 3 seconds while a storm builds and lightning strikes the enemies around it. Damage it takes during the dash makes the lightning stronger.',
        'Water' =>
          'Charges in a full circle, hitting every enemy it passes. A whirlpool then forms in the middle that pulls enemies in and slows them.',
        'Ice' =>
          'Dashes sideways and leaves a wall of ice along its path. The wall draws enemies to it, slows them and turns enemy shots back at other enemies.',
        'Steam' =>
          'Charges and leaves a geyser that draws enemies in and throws them back. If the charge kills an enemy, the special is ready again and another geyser rises there.',
        'Earth' =>
          'Charges and leaves a stone decoy where it lands. Nearby enemies attack the decoy instead, and it shakes the ground to hurt them. It bursts into shards when broken.',
        'Mud' =>
          'Leaves patches of mud behind it as it moves, slowing enemies that walk through. More patches with Intelligence.',
        'Dust' =>
          'Charges and leaves a dust whirlwind where it lands. It pulls nearby enemies in and holds them there, slowed, for a few seconds.',
        'Crystal' =>
          'Gathers crystal for a moment, then charges. Where it lands, 5 to 7 crystal shards start circling it, each blocking two enemy shots.',
        'Air' =>
          'A steady wind pushes nearby enemies away from the orb. Enemies right beside it are left alone so it can still hit them. Reaches farther with Intelligence.',
        'Plant' =>
          'Charges through enemies. Every enemy it hits and doesn\'t kill is held in place by vines for a few seconds, longer with Intelligence.',
        'Poison' =>
          'Special ability: Charges through enemies, poisoning each one it hits for extra damage. Passive: A poison cloud around it hurts nearby enemies, reaching farther with Intelligence.',
        'Spirit' =>
          'Holds still for 2 seconds while spirits gather, then charges, taking 60% less damage the whole time. Where it lands, ghosts drift outward and enemies chase them instead.',
        'Dark' =>
          'Holds still for 5 seconds while a void pulls nearby enemies in. Then it dashes far ahead, carrying the caught enemies along and slamming them where it stops. A black hole there finishes off the weakest.',
        'Light' =>
          'Stops and raises a dome of light for about 5 seconds, longer with Intelligence. Enemies are pushed out, their shots bounce back, and Alchemons inside take 70% less damage.',
        'Blood' =>
          'Gives up some of its own health to hit harder with its charge. Each enemy it kills in the next few seconds heals it back a little.',
        _ => 'Charges through enemies.',
      };
      final subtitle = switch (element) {
        'Air' || 'Mud' => 'Passive',
        'Light' => 'Barrier',
        'Crystal' || 'Spirit' || 'Dark' => 'Wind-up charge',
        'Water' => 'Circling charge',
        'Ice' => 'Sideways charge',
        _ => 'Charge',
      };
      return CosmicSpecialInfo(
        subtitle: subtitle,
        description: description,
        icon: AppIcons.shield,
      );
    case 'Wing':
      final description = switch (element) {
        'Fire' =>
          'Throws a fan of fireballs, then burns every enemy in a wide circle around the Wing for a few seconds. The circle grows with Intelligence.',
        'Lava' =>
          'Throws slow chunks of magma and fires a beam. The ground under the beam burns and hurts enemies standing on it.',
        'Lightning' =>
          'Throws a fan of fast bolts, then holds still for 3 seconds to charge and fires one big blast that hits every enemy in a line.',
        'Water' =>
          'Throws homing water bolts and fires a beam at your most hurt Alchemon or the ship, healing it. Enemies the beam crosses take damage.',
        'Ice' =>
          'Fires ice shards and a beam that slows every enemy it touches. An enemy kept in the beam for about a second freezes solid.',
        'Steam' =>
          'Fires steam shots and a beam that kills the first enemy it reaches, except bosses. 5 to 13 steam clouds then burst there and burn enemies inside, more with Beauty.',
        'Earth' =>
          'Throws heavy boulders and fires a beam. The orb fires a second beam at the enemy nearest it, for half as long.',
        'Mud' =>
          'Fires mud shots and a beam. Every enemy the beam touches is slowed for a full minute.',
        'Dust' =>
          'Fires a spray of dust and a beam. Enemies it touches turn their shots on other enemies for a few seconds.',
        'Air' =>
          'Fires fast wind shots and a beam that knocks back every enemy it touches.',
        'Crystal' =>
          'Fires homing crystal shards that block enemy shots, and a beam whose damage heals the Wing, the ship and the orb.',
        'Plant' =>
          'Fires homing vines and a beam. Enemies the beam kills leave flowers for the ship to collect; each one makes this Wing\'s beam stronger, more with Beauty, up to 50.',
        'Poison' =>
          'Fires poison shots, then poisons every enemy in a wide circle around the Wing for a few seconds.',
        'Spirit' =>
          'Fires homing spirits and a beam. The ship fires a beam of its own at the nearest enemy, and the Wing attacks faster while its beam is hitting.',
        'Dark' =>
          'Fires dark lances and a beam. It uses its special and its auto attack twice as often as other Wings.',
        'Light' =>
          'Fires light orbs and a beam that heals the Wing, the ship and the orb a little. Its first kill splits the beam into two smaller beams that hunt other enemies, three with high Beauty.',
        'Blood' =>
          'Fires homing blood bolts and a beam that locks onto the weakest enemy in range. Any enemy it hits below a fifth of its health dies.',
        _ => 'Fires a long beam through enemies.',
      };
      final subtitle = switch (element) {
        'Fire' => 'Fire ring',
        'Poison' => 'Poison ring',
        'Lightning' => 'Charged blast',
        'Water' => 'Healing beam',
        _ => 'Beam',
      };
      return CosmicSpecialInfo(
        subtitle: subtitle,
        description: description,
        icon: AppIcons.arrow_forward,
      );
    case 'Let':
      final description = switch (element) {
        'Air' =>
          'Drops a meteor on the biggest group of enemies. When it lands on enemies, it blows back everything around the crater.',
        'Dust' =>
          'Drops a meteor on the biggest group of enemies and leaves a dust cloud that slows enemies inside.',
        'Lava' =>
          'Drops a meteor on the biggest group of enemies and leaves burning ground that hurts enemies standing in it.',
        'Poison' =>
          'Drops a meteor on the biggest group of enemies and leaves a poison pool that hurts enemies inside. The enemy it lands on is slowed.',
        'Plant' =>
          'Drops a meteor on the biggest group of enemies. If it kills, 5 vines grow around the crater, and each strikes the first enemy to come close.',
        'Blood' =>
          'Drops a meteor on the biggest group of enemies and heals this Let. If it kills, it drains the enemies around the crater and heals your team, the ship and the orb.',
        'Earth' =>
          'Drops a bigger, slower meteor that also hits enemies around the crater. It heals your most hurt Alchemon or the ship and leaves rubble that stops enemies.',
        'Light' =>
          'Drops a meteor on the biggest group of enemies and heals the ship. If it kills, a pool of light keeps healing your most hurt Alchemon or the ship.',
        'Spirit' =>
          'Drops a meteor on the biggest group of enemies. Each enemy in or near the crater may die outright, more often with Intelligence, and badly hurt ones always do.',
        'Crystal' =>
          'Drops a weaker meteor about twice as often as other Lets. The enemy it lands on is slowed almost to a stop.',
        'Fire' =>
          'Drops a meteor on the biggest group of enemies. If it kills, a second blast hits everything around the crater.',
        'Lightning' =>
          'Drops a meteor on the biggest group of enemies. Lightning jumps from the enemy it lands on to up to 3 more.',
        'Steam' =>
          'Drops a meteor on the biggest group of enemies. If it kills, a geyser stays for 9 seconds, hurting enemies and pushing them away from the orb.',
        'Dark' =>
          'Drops a meteor on the biggest group of enemies. If it kills, 2 to 5 larger meteors fall on the enemies around it, more with Intelligence.',
        'Ice' =>
          'Drops a meteor on the biggest group of enemies and freezes every enemy in and just around the crater for about 3 seconds.',
        'Mud' =>
          'Drops a meteor on the biggest group of enemies. If it kills, it leaves a mud pool that stops enemies inside.',
        'Water' =>
          'Drops a meteor on the biggest group of enemies. A splash also hits enemies just past the crater, and each cast heals the ship a little.',
        _ => 'Drops a meteor on the biggest group of enemies.',
      };
      return CosmicSpecialInfo(
        subtitle: 'Meteor',
        description: description,
        icon: AppIcons.south,
      );
    case 'Pip':
      final description = switch (element) {
        'Fire' =>
          'Fires darts that bounce between enemies, more with Beauty. Kills leave fire pools that burn enemies standing in them.',
        'Lightning' =>
          'Fires darts that pierce and bounce more times than any other Pip\'s, losing less damage with each bounce. More darts with Beauty.',
        'Air' =>
          'Fires darts outward in every direction, more with Beauty. They bounce between enemies and push each one they hit away from the orb.',
        'Dust' =>
          'Fires darts that bounce between enemies, more with Beauty. Kills leave dust clouds that slow enemies inside.',
        'Crystal' =>
          'Fires darts that bounce and pierce, more with Beauty. Kills leave a crystal that draws nearby enemies to it until they break it or it fades.',
        'Light' =>
          'Fires a ring of darts that pierce and bounce, more with Beauty. Each dart can block one enemy shot, and kills heal the orb.',
        'Water' =>
          'Fires darts that bounce between enemies, more with Beauty. Each kill splashes nearby enemies, and a kill on a dart\'s last bounce makes a bigger splash.',
        'Ice' =>
          'Fires darts that bounce between enemies, more with Beauty, freezing each one they hit for a moment.',
        'Mud' =>
          'Auto attack: Enemies it hits drip mud for the rest of their lives, slowing other enemies. Special ability: Fires darts that bounce between enemies and slow them, more with Beauty.',
        'Plant' =>
          'Fires darts that bounce and pierce, more with Beauty. In Survival, every kill this Pip makes fills the surge meter 50% more.',
        'Poison' =>
          'Fires darts that pierce enemies for extra poison damage, more with Beauty. Poison lines form between the enemies they hit and hurt anything that crosses them.',
        'Earth' =>
          'Auto attack: Each shot brings its special a little sooner. Special ability: Fires heavy darts that jump to a new enemy after each kill. A dart\'s first kill brings the next special sooner.',
        'Lava' =>
          'Fires heavy darts that pierce enemies and jump on after kills, more with Beauty. Each enemy hit takes extra burn damage.',
        'Dark' =>
          'No special. Each enemy its auto attacks kill leaves a black hole for a few seconds that pulls nearby enemies in and finishes off nearly dead ones.',
        'Blood' =>
          'Fires heavy darts that pierce enemies and jump on after kills, more with Beauty. Each kill heals this Pip.',
        'Spirit' =>
          'Fires darts that bounce and pierce, more with Beauty. After enough kills, fewer with Intelligence, its auto attacks fire about ten times as fast for a few seconds.',
        'Steam' =>
          'Passive: A steam cloud around it speeds up its auto attacks, from 1.5 to 4 times as fast over 9 seconds, then starts over. Special ability: Fires darts that pierce and bounce, more with Beauty.',
        _ => 'Fires darts that bounce between enemies.',
      };
      final subtitle = switch (element) {
        'Dark' => 'Passive',
        'Lava' || 'Blood' => 'Piercing darts',
        'Earth' => 'Heavy darts',
        _ => 'Ricochet darts',
      };
      return CosmicSpecialInfo(
        subtitle: subtitle,
        description: description,
        icon: AppIcons.bolt,
      );
    case 'Mane':
      final (subtitle, description, icon) = switch (element) {
        'Air' => (
          'Piercing shot',
          'Fires a fast gust through enemies, carrying each one along with it and slowing it briefly.',
          AppIcons.air,
        ),
        'Dust' => (
          'Piercing shot',
          'Throws a big dust cloud through enemies and leaves a dust trail behind it. Enemy shooters it touches, or that cross the trail, fire at other enemies for a while.',
          AppIcons.cloud,
        ),
        'Lava' => (
          'Piercing shot',
          'Throws a slow ball of lava through enemies. It leaves a lava puddle under the first 4 enemies it hits, burning anything that stands in it.',
          AppIcons.local_fire_department,
        ),
        'Poison' => (
          'Piercing shot',
          'Throws a slow poison ball through enemies. Each time the same enemy is poisoned again it takes more damage, up to 8 times.',
          AppIcons.biotech,
        ),
        'Blood' => (
          'Piercing shot',
          'Throws a slow blood ball through enemies. Each enemy it passes through heals the orb and this Alchemon, up to a limit each second.',
          AppIcons.bloodtype,
        ),
        'Earth' => (
          'Piercing shot',
          'Throws a huge, slow stone slab that shrinks as it travels and leaves small quakes behind it. The quakes hurt and slow nearby enemies.',
          AppIcons.terrain,
        ),
        'Light' => (
          'Orbiting rings',
          'Each cast adds a light ring that circles this Alchemon and hits enemies, up to 2 to 4 rings, more with Beauty. Later casts make the rings bigger, up to 10 times.',
          AppIcons.wb_sunny,
        ),
        'Spirit' => (
          'Shot stream',
          'Fires a line of shots: 1 on the first cast, one more each cast up to 10, then back to 1.',
          AppIcons.auto_awesome,
        ),
        'Crystal' => (
          'Piercing shot',
          'Throws a large crystal through enemies. If it hits a boss it shatters, dealing heavy damage to the boss and everything around it.',
          AppIcons.diamond,
        ),
        'Fire' => (
          'Fireballs',
          'Throws 4 to 6 fast fireballs in a wide fan, more with Beauty. Each one passes through every enemy in its way.',
          AppIcons.whatshot,
        ),
        'Lightning' => (
          'Shock fields',
          'Drops 5 to 10 orbs around the ship, more with Beauty. Each one becomes a small field that shocks enemies inside it for 4 seconds.',
          AppIcons.flash_on,
        ),
        'Steam' => (
          'Piercing shot',
          'Fires a slow geyser through enemies that lets off bursts of steam as it goes. The steam hurts enemies and pushes them away from the orb.',
          AppIcons.blur_on,
        ),
        'Dark' => (
          'Piercing shot',
          'Fires a slow dark bolt that pulls nearby enemies toward it. Enemies with little health left die when it reaches them.',
          AppIcons.dark_mode,
        ),
        'Ice' => (
          'Piercing shot',
          'Throws a slow ball of ice through enemies, freezing each one for about 2 seconds. Bosses are only slowed.',
          AppIcons.ac_unit,
        ),
        'Mud' => (
          'Splitting shot',
          'Throws a mud ball that bursts into 10 shards on the first enemy it hits. The shards fly out in every direction and slow what they hit.',
          AppIcons.grain,
        ),
        'Plant' => (
          'Piercing shot',
          'Throws a vine that holds each enemy it passes through in place, growing thicker with each one. An enemy that dies while held bursts, hurting and holding the enemies beside it.',
          AppIcons.local_florist,
        ),
        'Water' => (
          'Piercing shot',
          'Sends a wide, slow wave through enemies. Enemies it hits are carried along with it and slowed.',
          AppIcons.water,
        ),
        _ => (
          'Piercing shot',
          'Throws one big shot through every enemy in a line.',
          AppIcons.waves,
        ),
      };
      return CosmicSpecialInfo(
        subtitle: subtitle,
        description: description,
        icon: icon,
      );
    case 'Mask':
      final description = switch (element) {
        'Air' =>
          'Lays 7 to 21 air pads in the enemies\' path, more with Beauty. An enemy that touches a pad is hit and knocked away.',
        'Dust' =>
          'Wraps the ship and each of your Alchemons in a dust shield. Each shield blocks 5 enemy shots and hurts enemies that get close.',
        'Lava' =>
          'Lays 5 to 15 lava pools in the enemies\' path, more with Beauty. Enemies standing in them burn.',
        'Poison' =>
          'Lays 4 to 12 poison clouds in the enemies\' path, more with Beauty. Enemies inside take damage.',
        'Plant' =>
          'Plants one vine that grows with every cast, up to 100 casts. Enemies within its reach are held in place and take damage.',
        'Blood' =>
          'Places a blood pool in the enemies\' path. Enemies that touch it bleed until they die, and part of what they lose heals your team and the ship.',
        'Earth' =>
          'Places 2 to 5 healing pools under your most hurt Alchemons and the ship, more with Beauty. Anyone standing in one heals.',
        'Light' =>
          'Lays 3 to 7 light traps, more with Beauty. In Survival, small enemies walk over them and the first large or elite enemy to touch one dies; elsewhere, any enemy. Bosses are never affected.',
        'Spirit' =>
          'Scatters 4 to 14 wisps around the ship, more with Beauty. Once the ship collects 12, every enemy on the field except bosses is destroyed.',
        'Crystal' =>
          'Lays 3 to 7 large crystals, more with Beauty. When an enemy touches one it breaks into 3 small crystals that hit nearby enemies.',
        'Fire' =>
          'Lays 5 to 15 fire traps in the enemies\' path, more with Beauty. The first enemy to touch one sets it off, leaving a pool that burns enemies inside.',
        'Lightning' =>
          'Places one lightning field that hurts enemies inside it. Each new enemy it hits makes it bigger and last longer.',
        'Steam' =>
          'Places 3 to 8 small geysers, more with Beauty. Each shoots steam at the nearest enemy and scalds enemies around it, pushing them away from the orb.',
        'Dark' =>
          'Opens a hole that pulls nearby enemies in, from farther with Intelligence. Enemies that reach it are thrown out past the edge of the arena.',
        'Ice' =>
          'Raises an ice pillar near your team. Alchemons and the ship close to it deal 2 to 5 times their damage, more with Beauty.',
        'Mud' =>
          'Lays 2 to 5 mud pools in the enemies\' path, more with Beauty. Enemies that walk through are slowed, and stay slowed for a while after.',
        'Water' =>
          'Lays 3 to 10 water traps in the enemies\' path, more with Beauty. An enemy that touches one sets off a splash that hits the enemies around it.',
        _ => 'Lays traps in the enemies\' path.',
      };
      final subtitle = switch (element) {
        'Lightning' => 'Shock field',
        'Steam' => 'Geysers',
        'Dark' => 'Black hole',
        'Plant' => 'Growing vine',
        'Dust' => 'Shields',
        'Earth' => 'Healing pools',
        'Ice' => 'Ice pillar',
        'Spirit' => 'Wisps',
        _ => 'Traps',
      };
      return CosmicSpecialInfo(
        subtitle: subtitle,
        description: description,
        icon: AppIcons.gps_fixed,
      );
    case 'Kin':
      final description = switch (element) {
        'Light' =>
          'Sends 2 to 5 light orbs, more with Intelligence, that circle this Kin and then guard the ship. They heal your most hurt Alchemon or the ship, hurt enemies they pass through, and each blocks one enemy shot.',
        'Water' =>
          'A rain cloud follows the ship for a while, steadily healing your most hurt Alchemon or the ship, and the orb a little.',
        'Air' =>
          'An updraft follows the ship for a while and pushes away enemies that get close. Wider with Beauty.',
        'Earth' =>
          'Raises an arc of stone around the orb on the side this Kin faces. Enemies that touch it are pushed back, and enemy shots bounce off it. Longer with Beauty.',
        'Plant' =>
          'Grows a garden at this Kin\'s feet that keeps healing your most hurt Alchemon or the ship. Every 5 seconds it drops a flower; fly the ship over it to heal your whole team.',
        'Poison' =>
          'Fires 8 to 16 homing poison darts in all directions, more with Intelligence. Each one flies to an enemy and hits it with extra poison damage.',
        'Crystal' =>
          'Sends 2 to 4 crystal shards, more with Intelligence, that circle this Kin and then guard the ship. Each blocks up to 4 enemy shots and fires a beam at a nearby enemy for each one.',
        'Fire' =>
          'The first time the orb falls while this Kin is out, the orb comes back at 25% health. From then on this Kin burns nearby enemies and attacks faster and harder.',
        'Lava' =>
          'For about 9 seconds, whenever the orb, the ship or one of your Alchemons is hit, lava splashes the nearest enemy and those around it. Lasts longer with Intelligence.',
        'Ice' =>
          'Stands still for a few seconds to charge, then releases frost that slows nearby enemies by 90%. Reaches farther with Beauty and lasts longer with Intelligence. Bosses are not slowed.',
        'Steam' =>
          'For about 10 seconds, every hit on the orb, the ship or your Alchemons adds a stack, up to 10. Each stack makes your Alchemons attack faster, up to twice as fast.',
        'Lightning' =>
          'Stands still for about 10 seconds, longer with Intelligence. Meanwhile your other Alchemons\' auto attacks jump to up to 3 more enemies.',
        'Dust' =>
          'Places a dust cloud on the enemy it is attacking. Enemies inside are slowed, and enemy shots that enter it are almost always stopped. Up to 10 clouds at once, each lasting about 30 seconds.',
        'Mud' =>
          'For about 5 seconds, the ship leaves a mud trail that slows enemies who walk through it. Lasts longer with Intelligence.',
        'Spirit' =>
          'A wisp circles this Kin and grows as the Kin defeats enemies. After 5 it draws enemies to it, after 15 it attacks them, and after 30 each defeat heals this Kin.',
        'Dark' =>
          'For about 7 seconds, enemies cannot see your Alchemons or the orb and go after the ship instead. The ship takes 70% less damage, until it falls below about a third of its health.',
        'Blood' =>
          'For about 9 seconds, 60% of the damage your Alchemons and the ship take is healed back, shared evenly among them. Your Alchemons also take part of the orb\'s damage, never enough to down them.',
        _ => 'Supports your team in a way set by its element.',
      };
      return CosmicSpecialInfo(
        subtitle: element == 'Fire' ? 'Passive' : 'Support',
        description: description,
        icon: AppIcons.favorite,
      );
    case 'Mystic':
      final description = switch (element) {
        'Fire' =>
          'Dozens of embers drift across the arena, more with Beauty and Intelligence. An enemy that touches one takes fire damage.',
        'Lava' =>
          '5 to 9 cracks open across the arena, more with Strength. When a brute, colossus, elite or boss steps on one, meteors fall around that spot.',
        'Lightning' =>
          'About every 2 seconds a bolt strikes near a random enemy, hurting everything close by. A boss it hits is stunned for 1 second. Strikes come faster with a stronger special.',
        'Water' =>
          'A large whirlpool opens partway out from the orb. Enemies inside stop advancing, are carried around it and take steady damage. Bosses are only slowed. Bigger with Beauty and Intelligence.',
        'Ice' =>
          'Every enemy except bosses moves 30% to 55% slower, more with Intelligence. This adds to any other slow.',
        'Steam' =>
          'Every 8 seconds all enemies are pushed outward from the orb, the closest ones hardest. It does no damage; bosses are stunned for a moment instead. Pushes harder with Intelligence.',
        'Earth' =>
          'About every 30 seconds a quake hurts every enemy in the arena, bosses included, and stops them for a moment. Comes sooner with a stronger special and hits harder with Strength.',
        'Mud' =>
          'Every enemy takes extra damage from everything: a little on the smallest, far more on the biggest. More with Strength and Intelligence.',
        'Dust' =>
          'Enemy shooters sometimes misfire and hurt themselves, and walking enemies sometimes wander off course for a moment. Happens more often with Intelligence.',
        'Crystal' =>
          'Enemies that die sometimes leave a crystal shard, more often with Beauty. When the ship picks one up it fills the alchemical meter and bursts, hurting enemies around the ship.',
        'Air' =>
          'A tornado circles the orb about halfway out. Enemies it passes over are caught, spun and damaged, then dropped. Bosses are only slowed. Bigger with Intelligence.',
        'Plant' =>
          'Two vines grow on either side of the orb. One whips nearby enemies and knocks them back; the other shoots homing thorns at enemies farther away. Longer reach with Strength.',
        'Poison' =>
          'The ship leaves poison patches as it flies that hurt enemies standing in them. Bigger and longer-lasting with Intelligence and Beauty.',
        'Spirit' =>
          'Small enemies that die get back up on your side for a short time and attack other enemies. More at once with Intelligence.',
        'Dark' =>
          'A black hole opens above the orb and pulls enemies in. Enemies that reach it are put back outside the arena edge, unhurt but slowed. Bosses are not pulled. Wider pull with Strength.',
        'Light' =>
          'About every 40 seconds, sooner with Beauty, a star outside the arena flares and heals the orb, the ship and all your Alchemons to full.',
        'Blood' =>
          'Every auto attack that hits, from your Alchemons and the ship, heals the orb and this Mystic for part of the damage. More with Strength and Beauty.',
        _ => 'Changes the whole arena while this Mystic is out.',
      };
      return CosmicSpecialInfo(
        subtitle: 'World',
        description: description,
        icon: AppIcons.auto_awesome,
      );
    default:
      return const CosmicSpecialInfo(
        subtitle: 'Special',
        description: 'Releases a burst of elemental energy.',
        icon: AppIcons.auto_awesome,
      );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPLORE STAT EFFECTS CARD
// ─────────────────────────────────────────────────────────────────────────────
/// Stat chips for the COSMIC tab — shows actual derived combat numbers
/// (HP, physical/elemental ATK + DEF, special power, Speed modifier) the way
/// Boss tab shows its stat chips, so both tabs read like the same UI.
