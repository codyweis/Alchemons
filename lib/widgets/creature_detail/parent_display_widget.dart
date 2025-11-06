// ============================================================================
// PARENT CARD
// ============================================================================

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/creature_detail/detail_helper_widgets.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ParentCard extends StatelessWidget {
  final FactionTheme theme;
  final ParentSnapshot snap;
  final String parentKey;
  final bool isExpanded;
  final VoidCallback onToggle;

  const ParentCard({
    required this.theme,
    required this.snap,
    required this.parentKey,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();
    final creature = repo.getCreatureById(snap.baseId);
    final instance = db.creatureDao.getInstance(snap.instanceId!);

    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.04),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(.12)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: snap.spriteData != null
                          ? FutureBuilder<CreatureInstance?>(
                              future: instance,
                              builder: (context, snapshotInstance) {
                                if (snapshotInstance.connectionState ==
                                        ConnectionState.done &&
                                    snapshotInstance.data != null) {
                                  return InstanceSprite(
                                    creature: creature!,
                                    instance: snapshotInstance.data!,
                                    size: 48,
                                  );
                                }
                                return Image.asset(
                                  snap.image,
                                  fit: BoxFit.cover,
                                );
                              },
                            )
                          : Image.asset(snap.image, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          snap.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          snap.types.join(' • '),
                          style: TextStyle(
                            color: theme.text.withOpacity(0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          snap.rarity,
                          style: TextStyle(
                            color: theme.text.withOpacity(0.6),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Row(
                    children: [
                      if (snap.isPrismaticSkin)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.purple.shade400.withOpacity(.3),
                                Colors.purple.shade600.withOpacity(.3),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.purple.withOpacity(.4),
                            ),
                          ),
                          child: const Text(
                            'P',
                            style: TextStyle(
                              color: Colors.purple,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.expand_more,
                          color: theme.primary.withOpacity(.6),
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          ClipRect(
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              sizeCurve: Curves.easeInOut,
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Column(
                children: [
                  Divider(color: theme.border, height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _ParentSubSection(
                          theme: theme,
                          title: 'Genetic Profile',
                          children: [
                            if (snap.genetics?.get('size') != null)
                              LabeledInlineValue(
                                label: 'Size Variant',
                                valueColor: theme.text,
                                valueText:
                                    sizeLabels[snap.genetics!.get('size')] ??
                                    'Standard',
                              ),
                            if (snap.genetics?.get('tinting') != null)
                              LabeledInlineValue(
                                label: 'Pigmentation',
                                valueColor: theme.text,
                                valueText:
                                    tintLabels[snap.genetics!.get('tinting')] ??
                                    'Standard',
                              ),
                            if (snap.nature != null)
                              LabeledInlineValue(
                                valueColor: theme.text,
                                label: 'Behavior',
                                valueText: snap.nature!.id,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PARENT SUBSECTION
// ============================================================================

class _ParentSubSection extends StatelessWidget {
  final FactionTheme theme;
  final String title;
  final List<Widget> children;

  const _ParentSubSection({
    required this.theme,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: theme.primary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: .6,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.02),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}
