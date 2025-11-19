// lib/widgets/breeding_milestone_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/services/constellation_service.dart';
import 'package:alchemons/utils/faction_util.dart';

/// Shows breeding progress and milestone info for a species
/// Add this to your creatures screen / dex entry
class BreedingMilestoneWidget extends StatelessWidget {
  final String speciesId;
  final bool compact;

  const BreedingMilestoneWidget({
    super.key,
    required this.speciesId,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    final constellationService = context.watch<ConstellationService>();

    return FutureBuilder<BreedingProgress>(
      future: constellationService.getBreedingProgress(speciesId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final progress = snapshot.data!;

        if (compact) {
          return _buildCompactProgress(theme, progress);
        }

        return _buildFullProgress(theme, progress);
      },
    );
  }

  Widget _buildCompactProgress(FactionTheme theme, BreedingProgress progress) {
    if (progress.totalBred == 0) {
      return const SizedBox.shrink(); // Don't show if never bred
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.primary.withOpacity(.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.primary.withOpacity(.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, color: theme.primary, size: 12),
          const SizedBox(width: 4),
          Text(
            '${progress.totalBred}',
            style: TextStyle(
              color: theme.text,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullProgress(FactionTheme theme, BreedingProgress progress) {
    if (progress.totalBred == 0) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.border.withOpacity(.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_outlined, color: theme.textMuted, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Breed this species to earn constellation points',
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final nextMilestone = progress.nextMilestone;
    final isComplete = nextMilestone == null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primary.withOpacity(.1),
            theme.secondary.withOpacity(.08),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.primary.withOpacity(.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: theme.primary, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'BREEDING PROGRESS',
                    style: TextStyle(
                      color: theme.primary,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.primary.withOpacity(.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${progress.totalBred} bred',
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Progress bar
          if (!isComplete) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.progress,
                minHeight: 6,
                backgroundColor: theme.surface,
                valueColor: AlwaysStoppedAnimation(theme.primary),
              ),
            ),
            const SizedBox(height: 8),

            // Next milestone info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Next milestone: ${nextMilestone.count}',
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade600, Colors.amber.shade700],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.white, size: 10),
                      const SizedBox(width: 2),
                      Text(
                        '+${nextMilestone.pointsAwarded}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            // All milestones complete
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.primary.withOpacity(.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: theme.primary.withOpacity(.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.emoji_events, color: theme.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All breeding milestones completed!',
                      style: TextStyle(
                        color: theme.text,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/* ============================================================================
   USAGE EXAMPLES
   ============================================================================

// Example 1: In creature details dialog (compact badge)
SectionBlock(
  theme: theme,
  title: 'Breeding Stats',
  child: Column(
    children: [
      LabeledInlineValue(
        label: 'Times Bred',
        valueWidget: BreedingMilestoneWidget(
          speciesId: creature.id,
          compact: true,
        ),
      ),
    ],
  ),
)

// Example 2: In creatures list (show for species with instances)
ListTile(
  title: Text(creature.name),
  subtitle: BreedingMilestoneWidget(
    speciesId: creature.id,
    compact: true,
  ),
)

// Example 3: In species detail page (full progress bar)
Column(
  children: [
    // ... creature info ...
    const SizedBox(height: 16),
    BreedingMilestoneWidget(speciesId: creature.id),
  ],
)

// Example 4: Filter creatures by breeding progress
// Show only species that are close to milestones (for engagement)
FutureBuilder<List<BreedingProgress>>(
  future: Future.wait(
    speciesIds.map((id) => 
      constellationService.getBreedingProgress(id)
    ),
  ),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const SizedBox.shrink();
    
    // Find species that are 80%+ to next milestone
    final closeToMilestone = snapshot.data!
        .where((p) => p.progress >= 0.8 && p.nextMilestone != null)
        .toList();
    
    return Column(
      children: closeToMilestone.map((progress) {
        return SpeciesCard(
          speciesId: progress.speciesId,
          trailing: BreedingMilestoneWidget(
            speciesId: progress.speciesId,
            compact: true,
          ),
        );
      }).toList(),
    );
  },
)

============================================================================ */
