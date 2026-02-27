// ============================================================================
// PARENT CARD
// ============================================================================

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/creature_detail/detail_helper_widgets.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ParentCard extends StatelessWidget {
  // ignore: unused_field
  final FactionTheme? theme;
  final ParentSnapshot snap;
  final String parentKey;
  final bool isExpanded;
  final VoidCallback onToggle;

  const ParentCard({
    this.theme,
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

    final instance = db.creatureDao.getInstance(snap.instanceId ?? '');

    return Container(
      decoration: BoxDecoration(
        color: FC.bg2,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: FC.borderDim),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(3),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: FC.bg3,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: FC.borderAccent, width: 0.8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
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
                                    size: 44,
                                  );
                                }
                                return Image.asset(
                                  'assets/images/${snap.image}',
                                  fit: BoxFit.cover,
                                );
                              },
                            )
                          : Image.asset(
                              'assets/images/${snap.image}',
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          snap.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: FC.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          snap.types.join(' • '),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: FC.textSecondary,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          snap.rarity.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: FC.textMuted,
                            fontSize: 8,
                            letterSpacing: 1.0,
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
                            color: FC.purple.withOpacity(.15),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(
                              color: FC.purple.withOpacity(.5),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            'PRISM',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: FC.purple,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.expand_more,
                          color: FC.amber,
                          size: 16,
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
                  const Divider(color: FC.borderDim, height: 1),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        _ParentSubSection(
                          title: 'Genetic Profile',
                          children: [
                            if (snap.genetics?.get('size') != null)
                              LabeledInlineValue(
                                label: 'Size Variant',
                                valueColor: FC.textPrimary,
                                valueText:
                                    sizeLabels[snap.genetics!.get('size')] ??
                                    'Standard',
                              ),
                            if (snap.genetics?.get('tinting') != null)
                              LabeledInlineValue(
                                label: 'Pigmentation',
                                valueColor: FC.textPrimary,
                                valueText:
                                    tintLabels[snap.genetics!.get('tinting')] ??
                                    'Standard',
                              ),
                            if (snap.nature != null)
                              LabeledInlineValue(
                                valueColor: FC.textPrimary,
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
  final String title;
  final List<Widget> children;

  const _ParentSubSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 10,
              color: FC.amber,
              margin: const EdgeInsets.only(right: 8),
            ),
            Text(title.toUpperCase(), style: FT.sectionTitle),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: FC.bg3,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: FC.borderDim),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}
