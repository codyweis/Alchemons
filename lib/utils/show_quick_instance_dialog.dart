import 'package:alchemons/audio/audio.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/models/potential_genetics.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/color_util.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_detail/creature_dialog.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/stamina_bar.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/models/stat_system.dart';

/// Quick-look dialog — modern rounded card with clean layout.
Future<void> showQuickInstanceDialog({
  required BuildContext context,
  required FactionTheme theme,
  required Creature creature,
  required CreatureInstance instance,
}) async {
  final genetics = decodeGenetics(instance.geneticsJson);
  final t = ForgeTokens(theme);
  var currentInstance = instance;

  await showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .75),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          final db = ctx.read<AlchemonsDatabase>();
          final hasPotentialAnalyzer = ctx
              .watch<ConstellationEffectsService>()
              .hasPotentialAnalyzer();

          // Pre-Dominants creatures fall back to whatever they are best at.
          final showDominants = ctx
              .read<ConstellationEffectsService>()
              .hasDominantAnalyzer();
          final quickDominants =
              DominantStats.decode(currentInstance.dominantStats) ??
              DominantStats.fromPotentials(
                speed: currentInstance.statSpeedPotential,
                intelligence: currentInstance.statIntelligencePotential,
                strength: currentInstance.statStrengthPotential,
                beauty: currentInstance.statBeautyPotential,
              );

          final variant = (currentInstance.variantFaction ?? '').trim();
          final variantDisplay = variant.isEmpty
              ? null
              : variant[0].toUpperCase() + variant.substring(1);
          final variantColor = variant.isEmpty
              ? Colors.transparent
              : FactionColors.of(variantDisplay ?? variant);

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 24,
            ),
            backgroundColor: Colors.transparent,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: theme.isDark ? t.bg1 : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: t.borderDim.withValues(alpha: 0.5),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .5),
                    blurRadius: 40,
                    spreadRadius: 8,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Hero area: sprite + name + level ─────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: theme.isDark
                              ? [t.bg0, t.bg1]
                              : [
                                  theme.surfaceAlt.withValues(alpha: 0.6),
                                  Colors.white,
                                ],
                        ),
                      ),
                      child: Column(
                        children: [
                          // Top row: close + details
                          Row(
                            children: [
                              // Level pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: t.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  'LV ${currentInstance.level}',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: t.amberBright,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              if (currentInstance.isFavorite) ...[
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () async {
                                    final next = !currentInstance.isFavorite;
                                    await db.creatureDao.setFavorite(
                                      currentInstance.instanceId,
                                      next,
                                    );
                                    final refreshed = await db.creatureDao
                                        .getInstance(
                                          currentInstance.instanceId,
                                        );
                                    if (refreshed != null) {
                                      currentInstance = refreshed;
                                      setDialogState(() {});
                                    }
                                  },
                                  child: const Icon(
                                    AppIcons.star_filled,
                                    size: 32,
                                    color: Color(0xFFE91E63),
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () async {
                                    final next = !currentInstance.isFavorite;
                                    await db.creatureDao.setFavorite(
                                      currentInstance.instanceId,
                                      next,
                                    );
                                    final refreshed = await db.creatureDao
                                        .getInstance(
                                          currentInstance.instanceId,
                                        );
                                    if (refreshed != null) {
                                      currentInstance = refreshed;
                                      setDialogState(() {});
                                    }
                                  },
                                  child: Icon(
                                    AppIcons.star_outline_rounded,
                                    size: 32,
                                    color: t.textMuted,
                                  ),
                                ),
                              ],
                              const Spacer(),
                              // Details button
                              GestureDetector(
                                onTap: () async {
                                  Navigator.of(ctx).pop();
                                  await CreatureDetailsDialog.show(
                                    context,
                                    creature,
                                    true,
                                    instanceId: currentInstance.instanceId,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: t.amber.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: t.amber.withValues(alpha: 0.3),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        AppIcons.open_in_full_rounded,
                                        size: 10,
                                        color: t.amber,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'DETAILS',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          color: t.amber,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: context.soundAction(
                                  () => Navigator.of(ctx).pop(),
                                ),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: t.bg2.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Icon(
                                    AppIcons.close_rounded,
                                    color: t.textSecondary,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Sprite
                          SizedBox(
                            width: 140,
                            height: 140,
                            child: InstanceSprite(
                              creature: creature,
                              instance: currentInstance,
                              size: 190,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Name
                          Text(
                            creature.name,
                            style: TextStyle(
                              color: t.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // XP + breeding stamina row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${currentInstance.xp} XP',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: t.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              StaminaBadge(
                                instanceId: currentInstance.instanceId,
                                showCountdown: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── Body content ─────────────────────────────────────────
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Breeding stamina restore ──
                          StreamBuilder<CreatureInstance?>(
                            stream: db.creatureDao.watchInstanceById(
                              currentInstance.instanceId,
                            ),
                            builder: (context, instSnap) {
                              final inst = instSnap.data;
                              if (inst == null) {
                                return const SizedBox.shrink();
                              }
                              final staminaSvc = context.read<StaminaService>();
                              final sState = staminaSvc.computeState(inst);
                              if (sState.bars >= sState.max) {
                                return const SizedBox.shrink();
                              }

                              return StreamBuilder<List<InventoryItem>>(
                                stream: db.inventoryDao.watchItemInventory(),
                                builder: (context, snapshot) {
                                  int qty = 0;
                                  for (final item in snapshot.data ?? []) {
                                    if (item.key == InvKeys.staminaPotion) {
                                      qty = item.qty;
                                      break;
                                    }
                                  }
                                  if (qty <= 0) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: GestureDetector(
                                      onTap: () async {
                                        final confirmed = await showDialog<bool>(
                                          context: ctx,
                                          builder: (dCtx) => AlertDialog(
                                            backgroundColor: t.bg1,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            title: Text(
                                              'Restore Breeding Stamina?',
                                              style: TextStyle(
                                                color: t.textPrimary,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            content: Text(
                                              'Use 1 Stamina Elixir to restore ${creature.name}\'s breeding stamina? ($qty remaining)',
                                              style: TextStyle(
                                                color: t.textSecondary,
                                                fontSize: 13,
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(
                                                  dCtx,
                                                ).pop(false),
                                                child: Text(
                                                  'Cancel',
                                                  style: TextStyle(
                                                    color: t.textMuted,
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.of(
                                                  dCtx,
                                                ).pop(true),
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
                                        if (confirmed != true || !ctx.mounted) {
                                          return;
                                        }
                                        await db.inventoryDao.addItemQty(
                                          InvKeys.staminaPotion,
                                          -1,
                                        );
                                        await StaminaService(db).restoreToFull(
                                          currentInstance.instanceId,
                                        );
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
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
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              duration: const Duration(
                                                seconds: 2,
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      child: Row(
                                        children: [
                                          Icon(
                                            AppIcons.local_drink_rounded,
                                            color: t.amberBright,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Restore Stamina',
                                            style: TextStyle(
                                              color: t.amberBright,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            '×$qty',
                                            style: TextStyle(
                                              fontFamily: 'monospace',
                                              color: t.textMuted,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            AppIcons.chevron_right_rounded,
                                            size: 16,
                                            color: t.textMuted,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),

                          // ── Stats ─────────────────────────────────────────
                          _QuickStatLine(
                            label: 'Speed',
                            value: currentInstance.statSpeed,
                            potential: hasPotentialAnalyzer
                                ? currentInstance.statSpeedPotential
                                : null,
                            enhancement: currentInstance.statSpeedEnhancement,
                            color: const Color(0xFF60A5FA),
                            icon: AppIcons.speed_rounded,
                            isDominant: showDominants && quickDominants.contains(StatKind.speed),
                          ),
                          _QuickStatLine(
                            label: 'Intelligence',
                            value: currentInstance.statIntelligence,
                            potential: hasPotentialAnalyzer
                                ? currentInstance.statIntelligencePotential
                                : null,
                            enhancement:
                                currentInstance.statIntelligenceEnhancement,
                            color: const Color(0xFFC084FC),
                            icon: AppIcons.psychology_rounded,
                            isDominant: showDominants && quickDominants.contains(
                              StatKind.intelligence,
                            ),
                          ),
                          _QuickStatLine(
                            label: 'Strength',
                            value: currentInstance.statStrength,
                            potential: hasPotentialAnalyzer
                                ? currentInstance.statStrengthPotential
                                : null,
                            enhancement:
                                currentInstance.statStrengthEnhancement,
                            color: const Color(0xFFF87171),
                            icon: AppIcons.fitness_center_rounded,
                            isDominant: showDominants && quickDominants.contains(
                              StatKind.strength,
                            ),
                          ),
                          _QuickStatLine(
                            label: 'Beauty',
                            value: currentInstance.statBeauty,
                            potential: hasPotentialAnalyzer
                                ? currentInstance.statBeautyPotential
                                : null,
                            enhancement: currentInstance.statBeautyEnhancement,
                            color: const Color(0xFFF9A8D4),
                            icon: AppIcons.favorite_rounded,
                            isDominant: showDominants && quickDominants.contains(
                              StatKind.beauty,
                            ),
                          ),

                          // ── Characteristics ───────────────────────────
                          // Named rows instead of a row of pills: SIZE, TINT and
                          // NATURE were previously indistinguishable chips, so
                          // "SMALL COOL SWIFT" left you guessing which was which.
                          if (variantDisplay != null ||
                              currentInstance.isPrismaticSkin == true ||
                              genetics?.get('size') != null ||
                              genetics?.get('tinting') != null ||
                              (currentInstance.natureId != null &&
                                  currentInstance.natureId!.isNotEmpty) ||
                              (currentInstance.natureId2 != null &&
                                  currentInstance.natureId2!.isNotEmpty)) ...[
                            const SizedBox(height: 14),
                            Container(height: 1, color: t.borderDim),
                            const SizedBox(height: 8),
                            if (genetics?.get('size') != null)
                              _TraitRow(
                                label: 'SIZE',
                                value: _titleCase(genetics!.get('size')!),
                                color: const Color(0xFF60A5FA),
                              ),
                            if (genetics?.get('tinting') != null)
                              _TraitRow(
                                label: 'TINT',
                                value: _titleCase(genetics!.get('tinting')!),
                                color: const Color(0xFF60A5FA),
                              ),
                            if (_natureLabel(currentInstance) != null)
                              _TraitRow(
                                label: 'NATURE',
                                value: _natureLabel(currentInstance)!,
                                color: t.amberBright,
                              ),
                            if (variantDisplay != null)
                              _TraitRow(
                                label: 'VARIANT',
                                value: variantDisplay,
                                color: variantColor,
                              ),
                            if (currentInstance.isPrismaticSkin == true)
                              const _TraitRow(
                                label: 'SKIN',
                                value: 'Prismatic',
                                color: Color(0xFFC084FC),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// Genetics and natures are stored lowercase or capitalised inconsistently;
/// this keeps the panel reading as prose rather than SHOUTING.
String _titleCase(String raw) {
  if (raw.isEmpty) return raw;
  return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
}

/// Both natures on one line — two separate rows labelled NATURE read as a
/// mistake rather than as a pair.
String? _natureLabel(CreatureInstance instance) {
  final parts = <String>[
    if (instance.natureId != null && instance.natureId!.isNotEmpty)
      _titleCase(instance.natureId!),
    if (instance.natureId2 != null && instance.natureId2!.isNotEmpty)
      _titleCase(instance.natureId2!),
  ];
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}

// ── Stat line: value, Potential and the Enhancement track ──────────────────
//
// The old bar plotted the value against a soft curve, which told you less than
// the number already did. The pips below each row are the one thing a number
// cannot show: how many of the ten Enhancement ranks have been bought.

class _QuickStatLine extends StatelessWidget {
  final String label;
  final double value;
  final double? potential;
  final int enhancement;
  final Color color;
  final IconData icon;

  /// One of the two stats this Alchemon passes down most reliably.
  final bool isDominant;

  const _QuickStatLine({
    required this.label,
    required this.value,
    this.potential,
    required this.enhancement,
    required this.color,
    required this.icon,
    this.isDominant = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    final rating = AlchemonStatSystem.displayRating(value);
    final p = potential == null
        ? null
        : AlchemonStatSystem.normalizePotential(potential!);
    final potentialMaxed = p != null && p >= AlchemonStatSystem.maxPotential;
    const maxRank = AlchemonStatSystem.maxEnhancementRank;
    final enhanceMaxed = enhancement >= maxRank;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDominant ? t.dominant : t.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$rating',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: color,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  p == null ? '' : 'P$p',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: potentialMaxed ? t.amberBright : t.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Text(
                enhanceMaxed ? 'ENH MAX' : 'ENH $enhancement/$maxRank',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: enhancement > 0 ? color : t.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    for (var i = 0; i < maxRank; i++) ...[
                      if (i > 0) const SizedBox(width: 2),
                      Expanded(
                        child: Container(
                          height: 5,
                          decoration: BoxDecoration(
                            color: i < enhancement
                                ? (enhanceMaxed ? t.amberBright : color)
                                : t.bg2,
                            borderRadius: BorderRadius.circular(1.5),
                            border: Border.all(
                              color: i < enhancement
                                  ? Colors.transparent
                                  : t.borderDim,
                              width: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A named characteristic. Reading "SIZE  Small" beats a pill that just says
/// SMALL and leaves you to infer what kind of thing it is.
class _TraitRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TraitRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                color: t.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
