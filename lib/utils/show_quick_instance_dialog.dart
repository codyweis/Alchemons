import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_detail/creature_dialog.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/stamina_bar.dart';

// ─── Forge color tokens — derived from FactionTheme (light/dark aware) ────────
// (ForgeTokens is defined in faction_util.dart and used here via `t`)

/// Quick-look dialog — Forge aesthetic + stamina restore.
Future<void> showQuickInstanceDialog({
  required BuildContext context,
  required FactionTheme theme,
  required Creature creature,
  required CreatureInstance instance,
}) async {
  final genetics = decodeGenetics(instance.geneticsJson);
  final t = ForgeTokens(theme);

  await showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .8),
    builder: (ctx) {
      final db = ctx.read<AlchemonsDatabase>();

      // ── helpers ──────────────────────────────────────────────────────────
      Widget sectionLabel(IconData icon, String label) => Row(
        children: [
          Icon(icon, size: 12, color: t.amber),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              color: t.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
        ],
      );

      Widget statRow({
        required IconData icon,
        required String label,
        required double value,
        required Color color,
      }) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: t.bg2,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: color.withValues(alpha: .35), width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'monospace',
                color: t.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            Text(
              value.toStringAsFixed(1),
              style: TextStyle(
                fontFamily: 'monospace',
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );

      Widget traitChip(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: t.bg2,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: color.withValues(alpha: .4), width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: .8,
              ),
            ),
          ],
        ),
      );

      // ── dialog shell ─────────────────────────────────────────────────────
      return Dialog(
        insetPadding: const EdgeInsets.all(20),
        backgroundColor: Colors.transparent,
        child: Container(
          width: 360,
          decoration: BoxDecoration(
            color: t.bg1,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: t.borderAccent, width: 1),
            boxShadow: [
              BoxShadow(
                color: t.amber.withValues(alpha: .12),
                blurRadius: 32,
                spreadRadius: 4,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: .85),
                blurRadius: 48,
                spreadRadius: 20,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── header strip ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                color: t.bg0,
                child: Row(
                  children: [
                    Text(
                      'QUICK VIEW',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: t.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const Spacer(),
                    // DETAILS button
                    GestureDetector(
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        await CreatureDetailsDialog.show(
                          context,
                          creature,
                          true,
                          instanceId: instance.instanceId,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: t.bg2,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: t.borderAccent, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.open_in_full_rounded,
                              size: 11,
                              color: t.amber,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'DETAILS',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: t.amber,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // close button
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: t.bg2,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: t.borderDim, width: 1),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: t.textMuted,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── body ───────────────────────────────────────────────────
              SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // sprite + identity card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: t.bg0,
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: t.borderDim, width: 1),
                      ),
                      child: Row(
                        children: [
                          // sprite
                          SizedBox(
                            width: 88,
                            height: 88,
                            child: InstanceSprite(
                              creature: creature,
                              instance: instance,
                              size: 88,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // name
                                Text(
                                  creature.name.toUpperCase(),
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: t.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                // level + xp row
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: t.amberDim.withValues(alpha: .3),
                                        borderRadius: BorderRadius.circular(2),
                                        border: Border.all(
                                          color: t.borderAccent,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        'LVL ${instance.level}',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          color: t.amberBright,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: .8,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${instance.xp} XP',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        color: t.textMuted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // stamina badge
                                StaminaBadge(
                                  instanceId: instance.instanceId,
                                  showCountdown: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ── stamina restore (streams inventory) ──────────────
                    StreamBuilder<List<InventoryItem>>(
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
                        return Column(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                await db.inventoryDao.addItemQty(
                                  InvKeys.staminaPotion,
                                  -1,
                                );
                                await StaminaService(
                                  db,
                                ).restoreToFull(instance.instanceId);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: const Row(
                                        children: [
                                          Icon(
                                            Icons.local_drink_rounded,
                                            color: Color(0xFFF59E0B),
                                            size: 15,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'STAMINA RESTORED',
                                            style: TextStyle(
                                              fontFamily: 'monospace',
                                              color: Color(0xFFE8DCC8),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: t.bg1,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(3),
                                        side: BorderSide(
                                          color: t.borderAccent,
                                          width: 1,
                                        ),
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: t.amberDim.withValues(alpha: .15),
                                  borderRadius: BorderRadius.circular(2),
                                  border: Border.all(
                                    color: t.borderAccent,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: t.amber.withValues(alpha: .08),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.local_drink_rounded,
                                      color: t.amberBright,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Text(
                                        'RESTORE STAMINA',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          color: t.amberBright,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.4,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: t.bg2,
                                        borderRadius: BorderRadius.circular(2),
                                        border: Border.all(
                                          color: t.borderAccent,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        '×$qty',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          color: t.amber,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        );
                      },
                    ),

                    // ── stats ─────────────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: t.bg0,
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: t.borderDim, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          sectionLabel(Icons.bar_chart_rounded, 'STATS'),
                          const SizedBox(height: 10),
                          statRow(
                            icon: Icons.speed_rounded,
                            label: 'Speed',
                            value: instance.statSpeed,
                            color: const Color(0xFF60A5FA),
                          ),
                          const SizedBox(height: 5),
                          statRow(
                            icon: Icons.psychology_rounded,
                            label: 'Intelligence',
                            value: instance.statIntelligence,
                            color: const Color(0xFFC084FC),
                          ),
                          const SizedBox(height: 5),
                          statRow(
                            icon: Icons.fitness_center_rounded,
                            label: 'Strength',
                            value: instance.statStrength,
                            color: const Color(0xFFF87171),
                          ),
                          const SizedBox(height: 5),
                          statRow(
                            icon: Icons.favorite_rounded,
                            label: 'Beauty',
                            value: instance.statBeauty,
                            color: const Color(0xFFF9A8D4),
                          ),
                        ],
                      ),
                    ),

                    // ── traits / genetics ─────────────────────────────────
                    if (instance.isPrismaticSkin == true ||
                        genetics?.get('size') != null ||
                        genetics?.get('tinting') != null ||
                        (instance.natureId != null &&
                            instance.natureId!.isNotEmpty)) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: t.bg0,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: t.borderDim, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            sectionLabel(Icons.auto_fix_high_rounded, 'TRAITS'),
                            const SizedBox(height: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (instance.isPrismaticSkin == true) ...[
                                  traitChip(
                                    Icons.auto_awesome_rounded,
                                    'PRISMATIC',
                                    const Color(0xFFC084FC),
                                  ),
                                  const SizedBox(height: 5),
                                ],
                                if (genetics?.get('size') != null) ...[
                                  traitChip(
                                    Icons.straighten_rounded,
                                    'SIZE: ${genetics!.get('size')!.toUpperCase()}',
                                    const Color(0xFF60A5FA),
                                  ),
                                  const SizedBox(height: 5),
                                ],
                                if (genetics?.get('tinting') != null) ...[
                                  traitChip(
                                    Icons.palette_outlined,
                                    'TINT: ${genetics!.get('tinting')!.toUpperCase()}',
                                    const Color(0xFF60A5FA),
                                  ),
                                  const SizedBox(height: 5),
                                ],
                                if (instance.natureId != null &&
                                    instance.natureId!.isNotEmpty)
                                  traitChip(
                                    Icons.psychology_rounded,
                                    'NATURE: ${instance.natureId!.toUpperCase()}',
                                    t.amberBright,
                                  ),
                              ],
                            ),
                          ],
                        ),
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
}
