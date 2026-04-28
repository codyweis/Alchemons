import 'package:flutter/material.dart';
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

      final variant = (currentInstance.variantFaction ?? '').trim();
      final variantDisplay = variant.isEmpty
          ? null
          : variant[0].toUpperCase() + variant.substring(1);
      final variantColor = variant.isEmpty
          ? Colors.transparent
          : FactionColors.of(variantDisplay ?? variant);

      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        backgroundColor: Colors.transparent,
        child: Container(
          width: 340,
          decoration: BoxDecoration(
            color: theme.isDark ? t.bg1 : Colors.white,
            borderRadius: BorderRadius.circular(16),
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
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'LV ${currentInstance.level}',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: t.amberBright,
                              fontSize: 10,
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
                                  .getInstance(currentInstance.instanceId);
                              if (refreshed != null) {
                                currentInstance = refreshed;
                                setDialogState(() {});
                              }
                            },
                            child: const Icon(
                              Icons.star_rounded,
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
                                  .getInstance(currentInstance.instanceId);
                              if (refreshed != null) {
                                currentInstance = refreshed;
                                setDialogState(() {});
                              }
                            },
                            child: Icon(
                              Icons.star_outline_rounded,
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
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: t.amber.withValues(alpha: 0.3),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.open_in_full_rounded,
                                  size: 10,
                                  color: t.amber,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'DETAILS',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: t.amber,
                                    fontSize: 8,
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
                          onTap: () => Navigator.of(ctx).pop(),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: t.bg2.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.close_rounded,
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
                        size: 140,
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
                    // XP + stamina row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${currentInstance.xp} XP',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: t.textMuted,
                            fontSize: 10,
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
                    // ── Stamina restore ──
                    StreamBuilder<CreatureInstance?>(
                      stream: db.creatureDao.watchInstanceById(currentInstance.instanceId),
                      builder: (context, instSnap) {
                        final inst = instSnap.data;
                        if (inst == null) return const SizedBox.shrink();
                        final staminaSvc = context.read<StaminaService>();
                        final sState = staminaSvc.computeState(inst);
                        if (sState.bars >= sState.max) return const SizedBox.shrink();

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
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  title: Text(
                                    'Restore Stamina?',
                                    style: TextStyle(
                                      color: t.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  content: Text(
                                    'Use 1 stamina potion on ${creature.name}? ($qty remaining)',
                                    style: TextStyle(
                                      color: t.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(dCtx).pop(false),
                                      child: Text(
                                        'Cancel',
                                        style: TextStyle(color: t.textMuted),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(dCtx).pop(true),
                                      child: Text(
                                        'Restore',
                                        style: TextStyle(color: t.amberBright, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true || !ctx.mounted) return;
                              await db.inventoryDao.addItemQty(
                                InvKeys.staminaPotion,
                                -1,
                              );
                              await StaminaService(
                                db,
                              ).restoreToFull(currentInstance.instanceId);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Stamina restored!',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        color: t.textPrimary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    backgroundColor: t.bg1,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            child: Row(
                              children: [
                                Icon(
                                  Icons.local_drink_rounded,
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
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right_rounded,
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
                    _QuickStatBar(
                      label: 'SPD',
                      value: currentInstance.statSpeed,
                      potential: hasPotentialAnalyzer
                          ? currentInstance.statSpeedPotential
                          : null,
                      color: const Color(0xFF60A5FA),
                      icon: Icons.speed_rounded,
                    ),
                    const SizedBox(height: 6),
                    _QuickStatBar(
                      label: 'INT',
                      value: currentInstance.statIntelligence,
                      potential: hasPotentialAnalyzer
                          ? currentInstance.statIntelligencePotential
                          : null,
                      color: const Color(0xFFC084FC),
                      icon: Icons.psychology_rounded,
                    ),
                    const SizedBox(height: 6),
                    _QuickStatBar(
                      label: 'STR',
                      value: currentInstance.statStrength,
                      potential: hasPotentialAnalyzer
                          ? currentInstance.statStrengthPotential
                          : null,
                      color: const Color(0xFFF87171),
                      icon: Icons.fitness_center_rounded,
                    ),
                    const SizedBox(height: 6),
                    _QuickStatBar(
                      label: 'BTY',
                      value: currentInstance.statBeauty,
                      potential: hasPotentialAnalyzer
                          ? currentInstance.statBeautyPotential
                          : null,
                      color: const Color(0xFFF9A8D4),
                      icon: Icons.favorite_rounded,
                    ),

                    // ── Traits ─────────────────────────────────────────
                    if (variantDisplay != null ||
                        currentInstance.isPrismaticSkin == true ||
                        genetics?.get('size') != null ||
                        genetics?.get('tinting') != null ||
                        (currentInstance.natureId != null &&
                            currentInstance.natureId!.isNotEmpty)) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (variantDisplay != null)
                            _TraitPill(
                              label: variantDisplay.toUpperCase(),
                              color: variantColor,
                            ),
                          if (currentInstance.isPrismaticSkin == true)
                            const _TraitPill(
                              label: 'PRISMATIC',
                              color: Color(0xFFC084FC),
                            ),
                          if (genetics?.get('size') != null)
                            _TraitPill(
                              label: genetics!.get('size')!.toUpperCase(),
                              color: const Color(0xFF60A5FA),
                            ),
                          if (genetics?.get('tinting') != null)
                            _TraitPill(
                              label: genetics!.get('tinting')!.toUpperCase(),
                              color: const Color(0xFF60A5FA),
                            ),
                          if (currentInstance.natureId != null &&
                              currentInstance.natureId!.isNotEmpty)
                            _TraitPill(
                              label: currentInstance.natureId!.toUpperCase(),
                              color: t.amberBright,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      },
      );
    },
  );
}

// ── Compact stat bar with colored fill ───────────────────────────────────────

class _QuickStatBar extends StatelessWidget {
  final String label;
  final double value;
  final double? potential;
  final Color color;
  final IconData icon;

  const _QuickStatBar({
    required this.label,
    required this.value,
    this.potential,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    const maxStat = 5.0;
    final fill = (value / maxStat).clamp(0.0, 1.0);
    final potentialFill =
        potential != null ? (potential! / maxStat).clamp(0.0, 1.0) : null;

    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 6),
        SizedBox(
          width: 28,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              color: t.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              color: t.bg2,
              borderRadius: BorderRadius.circular(4),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barWidth = constraints.maxWidth;
                return Stack(
                  children: [
                    // Filled portion
                    Container(
                      width: barWidth * fill,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    // Potential marker line
                    if (potentialFill != null)
                      Positioned(
                        left: (barWidth * potentialFill) - 1,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 2,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text(
            value.toStringAsFixed(1),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'monospace',
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Compact trait pill ───────────────────────────────────────────────────────

class _TraitPill extends StatelessWidget {
  final String label;
  final Color color;

  const _TraitPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
