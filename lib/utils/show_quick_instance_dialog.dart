import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flame/components.dart' show Vector2;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/creature_dialog.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/stamina_bar.dart';

// helper so we reuse the animated sprite genetics-aware
class InstanceSprite extends StatelessWidget {
  final Creature creature;
  final CreatureInstance instance;
  final double size;

  const InstanceSprite({
    super.key,
    required this.creature,
    required this.instance,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final genetics = decodeGenetics(instance.geneticsJson);
    final sd = creature.spriteData;

    if (sd == null) {
      // fallback to the static image on Creature if no sprite data
      return Image.asset(
        creature.image,
        fit: BoxFit.contain,
        width: size,
        height: size,
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: CreatureSprite(
        spritePath: sd.spriteSheetPath,
        totalFrames: sd.totalFrames,
        rows: sd.rows,
        frameSize: Vector2(sd.frameWidth.toDouble(), sd.frameHeight.toDouble()),
        stepTime: sd.frameDurationMs / 1000.0,
        scale: scaleFromGenes(genetics),
        hueShift: hueFromGenes(genetics),
        saturation: satFromGenes(genetics),
        brightness: briFromGenes(genetics),
        isPrismatic: instance.isPrismaticSkin,
      ),
    );
  }
}

/// Quick-look dialog that shows level, XP, stats, genetics/traits.
/// UPDATED: now also has a DETAILS button that opens the full CreatureDetailsDialog.
Future<void> showQuickInstanceDialog({
  required BuildContext context,
  required FactionTheme theme,
  required Creature creature,
  required CreatureInstance instance,
}) async {
  final genetics = decodeGenetics(instance.geneticsJson);

  // tiny stat badge row
  Widget statRow({
    required IconData icon,
    required String label,
    required double value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.surfaceAlt.withOpacity(1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(1), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: theme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value.toStringAsFixed(1),
            style: TextStyle(
              color: theme.text,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // bullet row like "Tint: Purple"
  Widget bulletRow(IconData icon, String label, {Color? color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color ?? theme.text),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: theme.text,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  await showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(.7),
    builder: (ctx) {
      return Dialog(
        insetPadding: const EdgeInsets.all(24),
        backgroundColor: Colors.transparent,
        child: Container(
          width: 360,
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.border, width: 2),
            boxShadow: [
              BoxShadow(
                color: theme.accent.withOpacity(.4),
                blurRadius: 28,
                spreadRadius: 4,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(.8),
                blurRadius: 40,
                spreadRadius: 16,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // -----------------------------------------------------------------
              // HEADER ROW
              // now contains: name, stamina badge, DETAILS button, close button
              // -----------------------------------------------------------------
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                decoration: BoxDecoration(
                  color: theme.surfaceAlt,
                  border: Border(
                    bottom: BorderSide(color: theme.border, width: 1.5),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // name + stamina on the left
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // species name
                          Text(
                            creature.name.toUpperCase(),
                            style: TextStyle(
                              color: theme.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .6,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),

                          // stamina row under name
                          StaminaBadge(
                            instanceId: instance.instanceId,
                            showCountdown: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // DETAILS button
                    GestureDetector(
                      onTap: () async {
                        // open full details screen
                        Navigator.of(ctx).pop(); // close quick dialog first
                        await CreatureDetailsDialog.show(
                          context,
                          creature,
                          true,
                          instanceId: instance.instanceId,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.accent.withOpacity(.6),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 14,
                              color: theme.accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'DETAILS',
                              style: TextStyle(
                                color: theme.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // close X
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Icon(
                        Icons.close_rounded,
                        color: theme.textMuted,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),

              // -----------------------------------------------------------------
              // BODY
              // -----------------------------------------------------------------
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Top row: sprite + level/xp
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // sprite
                          SizedBox(
                            width: 100,
                            height: 100,
                            child: InstanceSprite(
                              creature: creature,
                              instance: instance,
                              size: 100,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // level / xp / id
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // level pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.amber.shade600,
                                      Colors.amber.shade700,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(.3),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amber.withOpacity(.30),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'LEVEL ${instance.level}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: .5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              // XP
                              Text(
                                '${instance.xp} XP',
                                style: TextStyle(
                                  color: theme.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Stats
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.surfaceAlt.withOpacity(.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.border, width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.bar_chart_rounded,
                                size: 14,
                                color: theme.accent,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'STATS',
                                style: TextStyle(
                                  color: theme.text,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          statRow(
                            icon: Icons.speed,
                            label: 'Speed',
                            value: instance.statSpeed ?? 0,
                            color: Colors.blueAccent,
                          ),
                          const SizedBox(height: 6),
                          statRow(
                            icon: Icons.psychology,
                            label: 'Intelligence',
                            value: instance.statIntelligence ?? 0,
                            color: Colors.purple.shade300,
                          ),
                          const SizedBox(height: 6),
                          statRow(
                            icon: Icons.fitness_center,
                            label: 'Strength',
                            value: instance.statStrength ?? 0,
                            color: Colors.red.shade400,
                          ),
                          const SizedBox(height: 6),
                          statRow(
                            icon: Icons.favorite,
                            label: 'Beauty',
                            value: instance.statBeauty ?? 0,
                            color: Colors.pink.shade300,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Traits / Genetics
                    if (instance.isPrismaticSkin == true ||
                        genetics?.get('size') != null ||
                        genetics?.get('tinting') != null ||
                        (instance.natureId != null &&
                            instance.natureId!.isNotEmpty))
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.surfaceAlt.withOpacity(.3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: theme.border, width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.auto_fix_high_rounded,
                                  size: 14,
                                  color: theme.accent,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'TRAITS',
                                  style: TextStyle(
                                    color: theme.text,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: .8,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (instance.isPrismaticSkin == true)
                                  bulletRow(
                                    Icons.auto_awesome,
                                    'Prismatic Variant',
                                    color: Colors.purple.shade300,
                                  ),
                                if (genetics?.get('size') != null)
                                  bulletRow(
                                    Icons.straighten_rounded,
                                    'Size: ${genetics!.get('size')!}',
                                    color: theme.primary,
                                  ),
                                if (genetics?.get('tinting') != null)
                                  bulletRow(
                                    Icons.palette_outlined,
                                    'Tint: ${genetics!.get('tinting')!}',
                                    color: theme.primary,
                                  ),
                                if (instance.natureId != null &&
                                    instance.natureId!.isNotEmpty)
                                  bulletRow(
                                    Icons.psychology_rounded,
                                    'Nature: ${instance.natureId!}',
                                    color: theme.primary,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
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
