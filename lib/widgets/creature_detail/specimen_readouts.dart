// The readouts the quick look and the full details share: the four stat
// tiles, named trait rows and the stamina elixir chip. One copy, so the two
// screens can't drift into saying the same thing two ways.

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/parent_snapshot.dart' show decodeGenetics;
import 'package:alchemons/models/potential_genetics.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/models/wild_fusion.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/color_util.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/utils/nature_effect_formatter.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/instance_widgets/specimen_case.dart'
    show MarkDiamond, elementLight;
import 'package:alchemons/widgets/fx/mutation_sheets.dart' show mutationAccent;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ── Stat tiles ──────────────────────────────────────────────────────────────
//
// The number carries the value (an old bar plotted it against a soft curve,
// which told you less than the number did). The pips are the one thing a
// number cannot show: how many of the ten Enhancement ranks are bought.

class StatTileData {
  const StatTileData({
    required this.label,
    required this.color,
    required this.value,
    required this.potential,
    required this.enhancement,
    required this.isDominant,
  });

  final String label;
  final Color color;
  final double value;

  /// Null without the Potential analyzer.
  final double? potential;
  final int enhancement;

  /// One of the two stats this Alchemon passes down most reliably.
  final bool isDominant;
}

/// The two stats [instance] passes down most reliably. Pre-Dominants
/// creatures fall back to whatever they are already best at.
DominantStats dominantStatsOf(CreatureInstance instance) =>
    DominantStats.decode(instance.dominantStats) ??
    DominantStats.fromPotentials(
      speed: instance.statSpeedPotential,
      intelligence: instance.statIntelligencePotential,
      strength: instance.statStrengthPotential,
      beauty: instance.statBeautyPotential,
    );

List<StatTileData> statTilesFor(
  CreatureInstance instance, {
  required bool showPotential,
  required bool showDominants,
}) {
  final dominants = dominantStatsOf(instance);
  StatTileData stat(
    String label,
    Color color,
    double value,
    double potential,
    int enhancement,
    StatKind kind,
  ) => StatTileData(
    label: label,
    color: color,
    value: value,
    potential: showPotential ? potential : null,
    enhancement: enhancement,
    isDominant: showDominants && dominants.contains(kind),
  );

  return [
    stat(
      'Speed',
      const Color(0xFF60A5FA),
      instance.statSpeed,
      instance.statSpeedPotential,
      instance.statSpeedEnhancement,
      StatKind.speed,
    ),
    stat(
      'Intelligence',
      const Color(0xFFC084FC),
      instance.statIntelligence,
      instance.statIntelligencePotential,
      instance.statIntelligenceEnhancement,
      StatKind.intelligence,
    ),
    stat(
      'Strength',
      const Color(0xFFF87171),
      instance.statStrength,
      instance.statStrengthPotential,
      instance.statStrengthEnhancement,
      StatKind.strength,
    ),
    stat(
      'Beauty',
      const Color(0xFFF9A8D4),
      instance.statBeauty,
      instance.statBeautyPotential,
      instance.statBeautyEnhancement,
      StatKind.beauty,
    ),
  ];
}

/// The four stats, two by two.
class StatTileGrid extends StatelessWidget {
  const StatTileGrid({super.key, required this.stats});

  final List<StatTileData> stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row * 2 < stats.length; row++) ...[
          if (row > 0) const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: StatTile(data: stats[row * 2])),
              const SizedBox(width: 8),
              Expanded(
                child: row * 2 + 1 < stats.length
                    ? StatTile(data: stats[row * 2 + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.data});

  final StatTileData data;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    final tokens = ForgeTokens(context.read<FactionTheme>());
    final d = data;
    final rating = AlchemonStatSystem.displayRating(d.value);
    final p = d.potential == null
        ? null
        : AlchemonStatSystem.normalizePotential(d.potential!);
    final potentialMaxed = p != null && p >= AlchemonStatSystem.maxPotential;
    const maxRank = AlchemonStatSystem.maxEnhancementRank;
    final enhanceMaxed = d.enhancement >= maxRank;
    final labelColor = d.isDominant ? tokens.dominant : palette.muted;

    return CustomPaint(
      painter: BracketFramePainter(
        color: (d.isDominant ? tokens.dominant : palette.line).withValues(
          alpha: d.isDominant ? 0.85 : 0.7,
        ),
        bracketSize: 8,
      ),
      child: Container(
        color: palette.surfaceFill(),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    d.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: labelColor,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.9,
                    ),
                  ),
                ),
                if (p != null)
                  Text(
                    'P$p',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: potentialMaxed
                          ? tokens.amberBright
                          : palette.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$rating',
              style: TextStyle(
                fontFamily: 'monospace',
                color: d.color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var i = 0; i < maxRank; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: i < d.enhancement
                            ? (enhanceMaxed ? tokens.amberBright : d.color)
                            : palette.lineSoft.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                Text(
                  enhanceMaxed ? 'MAX' : '${d.enhancement}/$maxRank',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: d.enhancement > 0 ? d.color : palette.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Rarity and element ──────────────────────────────────────────────────────

/// Rarity as a count of stars, by what a specimen is worth: Common one,
/// Uncommon two, Rare three, Legendary four, Mystic five.
int rarityStarCount(String rarity) => switch (rarity.toLowerCase()) {
  'uncommon' => 2,
  'rare' => 3,
  'epic' || 'legendary' => 4,
  'mystic' || 'mythic' || 'variant' => 5,
  _ => 1,
};

const int kMaxRarityStars = 5;

/// Lit stars for the rarity, dim ones for the rest of the five.
class RarityStars extends StatelessWidget {
  const RarityStars({super.key, required this.rarity, this.size = 13});

  final String rarity;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    final lit = ForgeTokens(context.read<FactionTheme>()).amberBright;
    final count = rarityStarCount(rarity);
    return Semantics(
      label: '$rarity, $count of $kMaxRarityStars stars',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < kMaxRarityStars; i++)
            Padding(
              padding: EdgeInsets.only(right: i == kMaxRarityStars - 1 ? 0 : 2),
              child: Icon(
                AppIcons.star_filled,
                size: size,
                color: i < count ? lit : palette.lineSoft,
              ),
            ),
        ],
      ),
    );
  }
}

/// A specimen's stars and its element's diamond: the one-line header the
/// details and the quick look share in place of rarity and type pills.
class RarityElementMark extends StatelessWidget {
  const RarityElementMark({
    super.key,
    required this.species,
    this.prismatic = false,
  });

  final Creature species;
  final bool prismatic;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RarityStars(rarity: species.rarity),
        for (final type in species.types.take(2)) ...[
          const SizedBox(width: 12),
          MarkDiamond(color: elementLight(type), prismatic: prismatic, size: 9),
        ],
      ],
    );
  }
}

// ── Traits ──────────────────────────────────────────────────────────────────

/// A named characteristic. Reading "SIZE  Small" beats a pill that just says
/// SMALL and leaves you to infer what kind of thing it is. [note] is a
/// quieter second line under the value.
class TraitRow extends StatelessWidget {
  const TraitRow({
    super.key,
    required this.label,
    required this.value,
    this.color,
    this.note,
    this.noteMuted = false,
    this.leading,
    this.trailing,
  });

  final String label;
  final String value;

  /// Null reads in ink.
  final Color? color;
  final String? note;

  /// The note is a "not yet" rather than a reading: dimmer and italic.
  final bool noteMuted;

  /// Sits before the value, on its line: an element's diamond.
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: palette.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        value,
                        style: bracketText(
                          context,
                          13,
                          color ?? palette.ink,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (note != null && note!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    note!,
                    style: bracketText(
                      context,
                      12,
                      noteMuted
                          ? palette.muted.withValues(alpha: 0.75)
                          : palette.muted,
                      weight: FontWeight.w500,
                      fontStyle: noteMuted
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                    strutStyle: const StrutStyle(height: 1.3),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// Genetics and natures are stored lowercase or capitalised inconsistently;
/// this keeps the panel reading as prose rather than SHOUTING.
String titleCaseWord(String raw) {
  if (raw.isEmpty) return raw;
  return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
}

/// What a specimen is, as trait rows: element, family, size, tint, nature,
/// variant, skin, mutation. Each only when it has one.
///
/// [natureEffects] true prints what the nature does under it; false says the
/// Gene Analyzer is what reads it; null leaves the effect out altogether
/// (the quick look, which has no room for it).
List<TraitRow> specimenTraitRows(
  BuildContext context,
  Creature species,
  CreatureInstance? instance, {
  bool? natureEffects,
}) {
  final tokens = ForgeTokens(context.read<FactionTheme>());
  final family = (species.mutationFamily ?? '').trim();
  final kind = [
    if (species.types.isNotEmpty)
      TraitRow(
        label: 'ELEMENT',
        value: species.types.take(2).join(' · '),
        leading: MarkDiamond(
          color: elementLight(species.types.first),
          prismatic: instance?.isPrismaticSkin == true,
          size: 7,
        ),
      ),
    if (family.isNotEmpty) TraitRow(label: 'FAMILY', value: family),
  ];
  if (instance == null) return kind;

  final genetics = decodeGenetics(instance.geneticsJson);
  final size = genetics?.get('size');
  final tint = genetics?.get('tinting');

  final natures = [
    for (final id in [instance.natureId, instance.natureId2])
      if (id != null && id.isNotEmpty) id,
  ];
  String? natureNote;
  if (natures.isNotEmpty && natureEffects != null) {
    if (natureEffects) {
      natureNote = [
        for (final id in natures)
          if (NatureCatalog.byId(id) case final n?)
            formatNatureEffectSummary(n.effect),
      ].join('\n');
    } else {
      natureNote = 'Its effect is read by the Gene Analyzer.';
    }
  }

  final variant = (instance.variantFaction ?? '').trim();
  final variantDisplay = variant.isEmpty
      ? null
      : variant[0].toUpperCase() + variant.substring(1);
  final mutation = AlchemonMutation.byId(instance.mutation);

  return [
    ...kind,
    if (size != null)
      TraitRow(label: 'SIZE', value: sizeLabels[size] ?? titleCaseWord(size)),
    if (tint != null)
      TraitRow(label: 'TINT', value: tintLabels[tint] ?? titleCaseWord(tint)),
    if (natures.isNotEmpty)
      TraitRow(
        label: 'NATURE',
        value: natures.map(titleCaseWord).join(' · '),
        color: tokens.amberBright,
        note: natureNote,
        noteMuted: natureEffects == false,
      ),
    if (variantDisplay != null)
      TraitRow(
        label: 'VARIANT',
        value: variantDisplay,
        color: FactionColors.of(variantDisplay),
      ),
    if (instance.isPrismaticSkin == true)
      const TraitRow(
        label: 'SKIN',
        value: 'Prismatic',
        color: Color(0xFFE879F9),
      ),
    if (mutation != null)
      TraitRow(
        label: 'MUTATION',
        value: mutation.label,
        color: mutationAccent(mutation),
      ),
  ];
}

// ── Stamina elixir ──────────────────────────────────────────────────────────

/// Restores breeding stamina with an elixir, when it is down and there is
/// one to spend. Nothing otherwise.
class StaminaRestoreChip extends StatelessWidget {
  const StaminaRestoreChip({
    super.key,
    required this.instanceId,
    required this.creatureName,
  });

  final String instanceId;
  final String creatureName;

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    final palette = BracketPalette.of(context);
    final accent = bracketReadableAccent(context.read<FactionTheme>());
    return StreamBuilder<CreatureInstance?>(
      stream: db.creatureDao.watchInstanceById(instanceId),
      builder: (context, instSnap) {
        final inst = instSnap.data;
        if (inst == null) return const SizedBox.shrink();
        final sState = context.read<StaminaService>().computeState(inst);
        if (sState.bars >= sState.max) return const SizedBox.shrink();
        return StreamBuilder<List<InventoryItem>>(
          stream: db.inventoryDao.watchItemInventory(),
          builder: (context, snapshot) {
            var qty = 0;
            for (final item in snapshot.data ?? const <InventoryItem>[]) {
              if (item.key == InvKeys.staminaPotion) {
                qty = item.qty;
                break;
              }
            }
            if (qty <= 0) return const SizedBox.shrink();
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: context.soundAction(() => _restore(context, db, qty)),
              child: CustomPaint(
                painter: BracketFramePainter(
                  color: accent.withValues(alpha: 0.8),
                  bracketSize: 6,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  color: palette.accentWash(accent),
                  child: Text(
                    'RESTORE ×$qty',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: palette.ink,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _restore(
    BuildContext context,
    AlchemonsDatabase db,
    int qty,
  ) async {
    final t = ForgeTokens(context.read<FactionTheme>());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: t.bg1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        title: Text(
          'Restore Breeding Stamina?',
          style: TextStyle(
            color: t.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          "Use 1 Stamina Elixir to restore $creatureName's breeding "
          'stamina? ($qty remaining)',
          style: TextStyle(color: t.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: Text('Cancel', style: TextStyle(color: t.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: Text(
              'Restore',
              style: TextStyle(
                color: t.amberBright,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await db.inventoryDao.addItemQty(InvKeys.staminaPotion, -1);
    await StaminaService(db).restoreToFull(instanceId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Breeding stamina restored!',
          style: TextStyle(
            fontFamily: 'monospace',
            color: t.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: t.bg1,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
