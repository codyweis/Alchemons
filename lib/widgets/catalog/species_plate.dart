// lib/widgets/catalog/species_plate.dart
//
// The plate above the specimens when they are filtered to one species: its
// portrait in a lit case, element and rarity, how many have been bred, the
// next milestone and its points, and the milestone track. ✕ clears the filter.
// It replaces both the old per-species sheet and the old Specimen Progress
// screen, which repeated each other.

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/constellation_service.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/catalog/milestone_track.dart';
import 'package:alchemons/widgets/instance_widgets/specimen_case.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SpeciesPlate extends StatefulWidget {
  const SpeciesPlate({
    super.key,
    required this.species,
    required this.palette,
    required this.accent,
    required this.onClear,
  });

  final Creature species;
  final BracketPalette palette;
  final Color accent;
  final VoidCallback onClear;

  @override
  State<SpeciesPlate> createState() => _SpeciesPlateState();
}

class _SpeciesPlateState extends State<SpeciesPlate> {
  Future<BreedingProgress>? _progress;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-read whenever the service says something was bred.
    _progress = context.watch<ConstellationService>().getBreedingProgress(
      widget.species.id,
    );
  }

  @override
  void didUpdateWidget(SpeciesPlate old) {
    super.didUpdateWidget(old);
    if (old.species.id != widget.species.id) {
      _progress = context.read<ConstellationService>().getBreedingProgress(
        widget.species.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final species = widget.species;
    final palette = widget.palette;
    final light = caseElementLight(species);
    final rarity = BreedConstants.getRarityColor(species.rarity);
    final gilt = palette.isDark ? kCaseGilt : const Color(0xFF8A5A12);

    return CustomPaint(
      foregroundPainter: BracketFramePainter(
        color: light.withValues(alpha: 0.7),
        bracketSize: 9,
        strokeWidth: 1.2,
      ),
      child: Container(
        color: palette.surfaceMutedFill(),
        padding: const EdgeInsets.fromLTRB(10, 10, 6, 12),
        child: FutureBuilder<BreedingProgress>(
          future: _progress,
          builder: (context, snap) {
            final bred = snap.data?.totalBred ?? 0;
            final next = BreedingMilestone.nextMilestone(bred);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: CustomPaint(
                        painter: CaseLightPainter(color: light),
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Image.asset(
                            'assets/images/${species.image}',
                            cacheHeight: 140,
                            errorBuilder: (_, _, _) => const SizedBox(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            species.name.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: caseMono(14, palette.ink, spacing: 1.6),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              MarkDiamond(color: light),
                              const SizedBox(width: 6),
                              Text(
                                '${species.types.first.toUpperCase()}  ·  ',
                                style: caseMono(9.5, palette.muted),
                              ),
                              Text(
                                species.rarity.toUpperCase(),
                                style: caseMono(9.5, rarity),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: context.soundAction(widget.onClear),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          AppIcons.close_rounded,
                          size: 18,
                          color: palette.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Row(
                    children: [
                      Text(
                        '$bred',
                        style: caseMono(
                          14,
                          palette.ink,
                          weight: FontWeight.w900,
                        ),
                      ),
                      Text(' BRED', style: caseMono(9.5, palette.muted)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          next == null
                              ? 'EVERY MILESTONE REACHED'
                              : '${next.displayName.toUpperCase()} AT ${next.count}',
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: caseMono(
                            9,
                            next == null ? gilt : palette.muted,
                            spacing: 0.6,
                          ),
                        ),
                      ),
                      if (next != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '+${next.getPointsForRarity(species.rarity)} PTS',
                          style: caseMono(9.5, gilt),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: MilestoneTrack(
                    bred: bred,
                    palette: palette,
                    accent: widget.accent,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
