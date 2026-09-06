import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/widgets/app_icons.dart';

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
  Widget build(BuildContext context) {
    final family = widget.creature.mutationFamily ?? 'Unknown';

    return _ExploreTab(
      instance: widget.instance,
      family: family,
      types: widget.creature.types,
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
    final hp = CosmicBalance.companionMaxHp(
      level: instance.level,
      strength: strength,
      intelligence: intelligence,
    );
    final physAtk = CosmicBalance.companionPhysAtk(
      level: instance.level,
      strength: strength,
    );
    final elemAtk = CosmicBalance.companionElemAtk(
      level: instance.level,
      beauty: beauty,
    );
    final physDef = CosmicBalance.companionPhysDef(
      level: instance.level,
      strength: strength,
      intelligence: intelligence,
    );
    final elemDef = CosmicBalance.companionElemDef(
      level: instance.level,
      beauty: beauty,
      intelligence: intelligence,
    );
    final cdr = CosmicBalance.companionCooldownReduction(speed);
    final crit = CosmicBalance.companionCritChance(strength);

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

class _StatEntry {
  const _StatEntry(this.label, this.value);
  final String label;
  final String value;
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
            _AbilityDescriptionText(
              description: description,
              accent: activeAccent,
              textColor: palette.muted,
            ),
            if (footer != null) footer,
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
                constraints: const BoxConstraints(minWidth: 58),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  border: Border.all(color: accent.withValues(alpha: 0.34)),
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
                    AppIcons.blur_circular_rounded,
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
        icon: AppIcons.waves,
      );
    case 'Horn':
      return _CosmicBasicInfo(
        name: '$element Ram Shot',
        subtitle: 'Heavy close-range projectile',
        description:
            'Launches a large, slow $element projectile with an oversized '
            'hitbox. Horn basics hit hard up close and help keep pressure on '
            'targets before the shield-charge special lands.',
        icon: AppIcons.shield,
      );
    case 'Mask':
      return _CosmicBasicInfo(
        name: '$element Probe Bolt',
        subtitle: 'Fast piercing setup shot',
        description:
            'Fires a quick piercing $element bolt to tag targets in a line. '
            'Mask basics are light pressure tools that set up the family\'s '
            'trap, lure, and decoy control game.',
        icon: AppIcons.warning_amber,
      );
    case 'Wing':
      return _CosmicBasicInfo(
        name: '$element Feather Burst',
        subtitle: '2 rapid pursuit shots',
        description:
            'Unleashes two quick $element bolts in succession. Wing basics '
            'keep damage flowing while the companion stays mobile and looks '
            'for a clean beam line.',
        icon: AppIcons.arrow_forward,
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
        icon: AppIcons.favorite,
      );
    case 'Mystic':
      return _CosmicBasicInfo(
        name: '$element Arcane Triad',
        subtitle: '3 spread bolts',
        description:
            'Releases three small $element bolts in a spread. Mystic basics '
            'hold space between ultimates, but the family\'s real power is in '
            'its slower, element-specific guardian special.',
        icon: AppIcons.auto_awesome,
      );
    case 'Pip':
      return _CosmicBasicInfo(
        name: '$element Dart Burst',
        subtitle: '3 fast tracking darts',
        description:
            'Fires a quick burst of small $element darts. Pip basics are '
            'built for high uptime, target pressure, and staying active '
            'between ricochet specials.',
        icon: AppIcons.bolt,
      );
    case 'Let':
      return _CosmicBasicInfo(
        name: '$element Bomb',
        subtitle: 'Slow artillery shot',
        description:
            'Lobs a compact $element bomb with more heft than a standard bolt. '
            'Let basics reinforce the siege role: slower, heavier lane pressure '
            'between the family\'s larger element-shaped meteor specials.',
        icon: AppIcons.south,
      );
    default:
      return _CosmicBasicInfo(
        name: '$element Bolt',
        subtitle: 'Auto-targets nearest',
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
    'Auto/Special kills',
    'Special kills',
    'Auto hits',
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

class _ElementMechanicNote {
  const _ElementMechanicNote({required this.label, required this.body});

  final String label;
  final String body;
}

_ElementMechanicNote _survivalPassive(String body) =>
    _ElementMechanicNote(label: 'Survival only', body: body);

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
          'Charges through enemies and paints a burning trail of taunt + DoT patches along the dash path.',
        'Lava' =>
          'Slow heavy charge with a glowing build-up telegraph. Enemies killed by the slam explode into homing flames that seek nearby targets.',
        'Lightning' =>
          'Quick dash to the target, then a 3-second storm brews around the horn (movement locked). Damage taken during the dash + brew is absorbed, then released as a chain shockwave whose size scales with the absorbed total.',
        'Water' =>
          'Charges in a circular sweep around the cast point, then drops a whirlpool at the center that pulls and slows trapped enemies.',
        'Ice' =>
          'Dashes sideways perpendicular to the enemy direction, painting an ice wall segment-by-segment along the path. Wall taunts, slows, and reflects enemy projectiles.',
        'Steam' =>
          'Heavy slam drops a steam geyser. If the slam KILLS an enemy, the special cooldown instantly resets AND another geyser spawns at the kill site — chain-cast through a streak.',
        'Earth' =>
          'Impact leaves a high-HP substitute clone that taunts enemies and pulses periodic mini-earthquakes around it.',
        'Mud' =>
          'Passive: No active cast. Drops slowing mud sludge wherever the horn walks. Trail rate scales with intelligence. Disabled while magnet-recalled to the ship.',
        'Dust' =>
          'Impact creates a dust cyclone that pulls nearby enemies inward and disorients shooter-enemies (they fire at each other).',
        'Crystal' =>
          'Wind-up gathers six crystal shards orbiting the horn, then dashes. Shards keep orbiting the moving horn, intercept enemy projectiles, and shatter into shrapnel when they expire.',
        'Air' =>
          'Passive: No active cast. Enemies near the horn are continuously blown back toward the arena edge. Inner deadzone lets the horn melee close targets with basics; outer aura pushes everything else away.',
        'Plant' =>
          'Charges through enemies. Each surviving enemy hit gets a personal root status — immobilized for a few seconds and wrapped in vines.',
        'Poison' =>
          'Special + Passive: Active charge applies a heavy poison DoT to each enemy the dash sweeps through. Always-on toxic aura also ticks poison damage to anyone in range.',
        'Spirit' =>
          'Two-second wind-up where phantoms swarm the horn (60% damage reduction throughout wind-up + dash). On dash, six mobile phantom wisps release in a ring, drifting outward and taunting enemies.',
        'Dark' =>
          'Five-second void-suck wind-up drags nearby enemies toward the horn. Then a long fast dash carries the captured cluster to the map edge, teleporting them with the horn and slamming them for impact damage on arrival.',
        'Light' =>
          'Stops moving and channels a stationary light barrier for ~5s. Barrier reflects enemy projectiles, bounces enemies that touch the perimeter, and allies inside take 70% reduced damage.',
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
          'Charges for ~0.75s, then unleashes a sustained heavy-damage beam down the lane.',
        'Water' =>
          'Beam locks onto the lowest-HP ally or the ship and heals them; enemies along the beam path still take damage.',
        'Ice' =>
          'Beam contact builds frost on the target — held on long enough, the enemy snaps into a hard freeze.',
        'Steam' =>
          'Executes the first enemy the beam touches and erupts 5–10 lingering steam clouds at the kill site (DoT).',
        'Earth' =>
          'Standard piercing beam — the orb also fires a mirror beam alongside the wing, doubling the coverage.',
        'Mud' => 'Permanently (60s) slows every enemy the beam touches.',
        'Dust' =>
          'Beam contact surrounds the enemy with disorienting dust — shooter-enemies start firing at each other instead of the ship.',
        'Air' =>
          'Beam contact knocks enemies back hard, holding them off the line.',
        'Crystal' => 'Beam damage heals the orb (lifesteal-to-orb sustain).',
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
        _ => 'Element changes the beam targeting + effect.',
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
          'On collision, sears the ground in a burning area that DoTs anything inside.',
        'Poison' =>
          'On collision, poisons the struck enemy and leaves a toxic pool that poisons others nearby.',
        'Plant' =>
          'If the meteor kills an enemy, vines grow from the ground that persist and damage enemies who walk through them.',
        'Blood' =>
          'If the meteor kills an enemy, drains HP from nearby enemies and splits the drained HP as healing to every alchemon and the ship.',
        'Earth' =>
          'On collision, % of damage dealt is converted into a heal for the lowest-HP alchemon or the ship.',
        'Light' =>
          'If the meteor kills an enemy, creates a pool of light that heals nearby allies and the ship.',
        'Spirit' =>
          '20% chance to one-shot any target on impact. Proc chance scales up with stats.',
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
          'On collision, splashes a big AOE damage burst across nearby enemies.',
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
          'Auto/Special kills: Create a fire pool that persists and burns enemies inside it.',
        'Lightning' => 'Doubles the amount of ricochets.',
        'Air' => 'Ricochet darts push enemies back on hit.',
        'Dust' =>
          'Auto/Special kills: Create a dust cloud that persists and slows enemies inside it.',
        'Crystal' =>
          'Auto/Special kills: Create a taunting crystal. Special darts also pierce and ricochet.',
        'Light' =>
          'Darts can intercept threats, and special kills heal allies or the ship.',
        'Water' =>
          'Auto/Special kills: Splash nearby enemies. The special\'s final ricochet creates a larger splash.',
        'Ice' => 'Darts freeze and slow enemies they hit.',
        'Mud' =>
          'Auto hits mark enemies to leave mud trails. Special darts slow enemies.',
        'Plant' =>
          'Auto/Special kills: Grant extra alchemy meter in Cosmic Survival.',
        'Poison' =>
          'Auto hits draw poison lines between hit enemies. Special darts poison and slow enemies.',
        'Earth' =>
          'Passive: Auto attacks reduce this Pip\'s special cooldown. Special kills refund extra cooldown.',
        'Lava' => 'Darts pierce and burn enemies they hit.',
        'Dark' =>
          'Passive: Auto-attack kills create a black hole that pulls enemies inward.',
        'Blood' => 'Enemies killed heal allies or the ship.',
        'Spirit' =>
          'Auto/Special kills: Build Spirit stacks; enough stacks give a temporary attack-speed boost.',
        'Steam' =>
          'Passive: This Pip cycles through a ramping attack-speed window. Special kills can trigger extra haste.',
        _ => 'Element changes the dart effect.',
      };
      if (element == 'Dark') {
        return CosmicSpecialInfo(
          subtitle: 'Auto Darts • Black Hole passive',
          description:
              'Auto: Fires three fast homing darts. Passive: This Pip has no active special; auto-attack kills create a black hole that pulls enemies inward.',
          icon: AppIcons.bolt,
        );
      }
      return CosmicSpecialInfo(
        subtitle: 'Auto Darts • Ricochet special',
        description:
            'Auto: Fires three fast homing darts. Special: Fires a short-lived elemental dart salvo; ricochet elements hop between nearby enemies. '
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
          'Drops a lava blob at each enemy collision; blobs DoT enemies who step into them.',
          AppIcons.local_fire_department,
        ),
        'Poison' => (
          'Venom Edge • Stacking toxin',
          'Each pierce stacks poison on the enemy. The more times it\'s hit, the harder the poison DoT bites.',
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
          'Radiant Growth • Scaling pierce',
          'Ball starts tiny. Each enemy it pierces makes it bigger and hits harder — ramps the longer the line.',
          AppIcons.wb_sunny,
        ),
        'Spirit' => (
          'Phaseblade Rush • Ramping stream',
          'Starts at 1 projectile. Each cast adds another shot up to 10, then resets back to 1.',
          AppIcons.auto_awesome,
        ),
        'Crystal' => (
          'Prism Edge • Boss shatter',
          'If it hits a boss, instantly explodes for a huge crystal burst that wipes the boss and AOE damages everything nearby.',
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
          'Vine Lariat • Root bloom',
          'Every enemy passed through is temporarily rooted. If a rooted enemy dies, it explodes into plant AOE damage.',
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
          'Opens a void hole. Enemies caught in its suction are yeeted out of the area; radius scales with stats.',
        'Ice' =>
          'Raises a giant ice pillar. Allies near it gain ~2–5× attack strength.',
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
        subtitle: 'Rare Support • Charged laser auto',
        description: description,
        icon: AppIcons.favorite,
      );
    case 'Mystic':
      final (subtitle, desc, _) = switch (element) {
        'Fire' => (
          'Supernova Collapse • Beauty scales count',
          'An expanding ring of fire orbs collapses inward, then a core orb detonates into fragments.',
          ['BURST', 'CLUSTER', 'HOMING'],
        ),
        'Lava' => (
          'Cataclysm Moons • Strength scales count',
          'Launches slow piercing boulders that leave lava trails and split into cluster detonations.',
          ['PIERCING', 'TRAIL', 'CLUSTER'],
        ),
        'Lightning' => (
          'Storm Lattice • Intelligence scales count',
          'Fires rapid zigzag bolts with high bounce counts.',
          ['BOUNCE', 'CHAIN', 'HOMING'],
        ),
        'Water' => (
          'Tidal Crescent • Beauty scales count',
          'Sweeps crescent waves from both flanks that home inward and leave water trails.',
          ['HOMING', 'TRAIL', 'PINCER'],
        ),
        'Ice' => (
          'Glacier Crown • Intelligence scales count',
          'Forms orbiting ice pillars, then launches them as piercing lances that split into frost clusters.',
          ['PIERCING', 'CLUSTER', 'BARRIER'],
        ),
        'Steam' => (
          'Whiteout Veil • Intelligence scales count',
          'Deploys snare clouds plus turret orbs that fire homing shots.',
          ['SNARE', 'TURRET', 'AREA DENIAL'],
        ),
        'Earth' => (
          'Monolith Constellation • Strength scales count',
          'Summons stone decoy pillars that taunt enemies and explode into shrapnel when destroyed.',
          ['DECOY', 'TAUNT', 'EXPLODES'],
        ),
        'Mud' => (
          'Mire Eclipse • Strength scales count',
          'Creates a snare zone, then launches homing mud slugs that pierce and leave slowing trails.',
          ['SNARE', 'PIERCING', 'TRAIL'],
        ),
        'Dust' => (
          'Sirocco Halo • Beauty scales count',
          'Unleashes a spiral swarm of fast projectiles that bounce between enemies.',
          ['SWARM', 'BOUNCE', 'HOMING'],
        ),
        'Crystal' => (
          'Prism Cathedral • Beauty scales count',
          'Fires prismatic shards that pierce, bounce, and split into fragments on hit.',
          ['PIERCING', 'BOUNCE', 'CLUSTER'],
        ),
        'Air' => (
          'Cyclone Halo • Intelligence scales count',
          'Deploys ship-following interceptor orbs that block enemy projectiles and deal contact damage.',
          ['INTERCEPT', 'ORBITAL', 'DEFENSE'],
        ),
        'Plant' => (
          'Verdant Procession • Strength scales count',
          'Plants vine turrets that fire homing thorns at nearby enemies.',
          ['TURRET', 'HOMING', 'SUSTAINED'],
        ),
        'Poison' => (
          'Venom Halo • Intelligence scales count',
          'Deploys ship-following poison clouds that snare enemies and leave toxic trails.',
          ['SNARE', 'TRAIL', 'AREA DENIAL'],
        ),
        'Spirit' => (
          'Wraith Chorus • Intelligence scales count',
          'Launches piercing ghost bolts with strong homing and spectral trails.',
          ['PIERCING', 'HOMING', 'HUNTER'],
        ),
        'Dark' => (
          'Eclipse Procession • Strength scales count',
          'Places void wells that taunt, snare, and detonate into cluster explosions.',
          ['TAUNT', 'SNARE', 'CLUSTER'],
        ),
        'Light' => (
          'Radiant Crown • Beauty scales count',
          'Deploys ship-orbiting sentinels that fire homing light bolts and intercept enemy projectiles.',
          ['TURRET', 'INTERCEPT', 'ORBITAL'],
        ),
        'Blood' => (
          'Crimson Coronation • Strength scales count',
          'Launches heavy homing blood orbs that split into clusters and leave crimson trails, plus a self-heal and blessing aura on cast.',
          ['HOMING', 'HEAL', 'BLESSING'],
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
            'Base: Unleashes a burst of elemental energy. Special: Cooldown is reduced by Speed.',
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
