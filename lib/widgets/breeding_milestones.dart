// lib/widgets/breeding_milestone_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/services/constellation_service.dart';
import 'package:alchemons/utils/faction_util.dart';

/// Shows breeding progress and milestone info for a species
/// Add this to your creatures screen / dex entry
class BreedingMilestoneWidget extends StatelessWidget {
  final String speciesId;
  final String? rarity; // Pass rarity to show accurate point rewards
  final bool compact;

  const BreedingMilestoneWidget({
    super.key,
    required this.speciesId,
    this.rarity,
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
        color: theme.primary.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.primary.withValues(alpha: .3)),
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
          border: Border.all(color: theme.border.withValues(alpha: .3)),
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

    // Calculate actual points based on rarity
    final pointsForRarity = rarity != null && nextMilestone != null
        ? nextMilestone.getPointsForRarity(rarity!)
        : nextMilestone?.pointsAwarded ?? 0;

    // Get rarity color for the points badge
    final rarityColor = _getRarityColor(rarity);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primary.withValues(alpha: .1),
            theme.secondary.withValues(alpha: .08),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.primary.withValues(alpha: .3), width: 1.5),
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
                  color: theme.primary.withValues(alpha: .2),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next: ${nextMilestone.displayName}',
                        style: TextStyle(
                          color: theme.text,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${nextMilestone.count} bred required',
                        style: TextStyle(
                          color: theme.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: rarityColor != null
                          ? [rarityColor, rarityColor.withValues(alpha: 0.8)]
                          : [Colors.amber.shade600, Colors.amber.shade700],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: (rarityColor ?? Colors.amber.shade600)
                            .withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.white, size: 10),
                      const SizedBox(width: 3),
                      Text(
                        '+$pointsForRarity',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Show rarity bonus if applicable
            if (rarity != null &&
                pointsForRarity > (nextMilestone.pointsAwarded)) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.workspace_premium,
                    color: rarityColor ?? theme.primary,
                    size: 11,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_getRarityMultiplierText(rarity!)} bonus for ${rarity!.toLowerCase()} rarity',
                    style: TextStyle(
                      color: theme.textMuted,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ] else ...[
            // All milestones complete
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.primary.withValues(alpha: .2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: theme.primary.withValues(alpha: .4)),
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

  // Helper to get color based on rarity
  Color? _getRarityColor(String? rarity) {
    if (rarity == null) return null;

    switch (rarity.toLowerCase()) {
      case 'common':
        return Colors.grey.shade600;
      case 'uncommon':
        return Colors.green.shade600;
      case 'rare':
        return Colors.blue.shade600;
      case 'epic':
        return Colors.purple.shade600;
      case 'legendary':
        return Colors.amber.shade600;
      default:
        return null;
    }
  }

  // Helper to get multiplier text
  String _getRarityMultiplierText(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return '1x';
      case 'uncommon':
        return '2x';
      case 'rare':
        return '3x';
      case 'epic':
        return '5x';
      case 'legendary':
        return '10x';
      default:
        return '1x';
    }
  }
}

/* ============================================================================
   USAGE EXAMPLES
   ============================================================================

// Example 1: In creature details dialog (compact badge)
// NOTE: Now you should pass rarity for accurate display!
SectionBlock(
  theme: theme,
  title: 'Breeding Stats',
  child: Column(
    children: [
      LabeledInlineValue(
        label: 'Times Bred',
        valueWidget: BreedingMilestoneWidget(
          speciesId: creature.id,
          rarity: creature.rarity, // Pass rarity here!
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
    rarity: creature.rarity, // Pass rarity here!
    compact: true,
  ),
)

// Example 3: In species detail page (full progress bar with rarity bonus display)
Column(
  children: [
    // ... creature info ...
    const SizedBox(height: 16),
    BreedingMilestoneWidget(
      speciesId: creature.id,
      rarity: creature.rarity, // Shows accurate points + bonus text!
    ),
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
        // Get creature definition to show accurate rarity-based points
        final creature = CreatureCatalog.byId(progress.speciesId);
        
        return SpeciesCard(
          speciesId: progress.speciesId,
          trailing: BreedingMilestoneWidget(
            speciesId: progress.speciesId,
            rarity: creature?.rarity, // Shows correct points!
            compact: true,
          ),
        );
      }).toList(),
    );
  },
)

// Example 5: Compare point potential between rarities
// Great for showing players why breeding rarer creatures is valuable
Widget buildRarityComparison(BreedingMilestone milestone) {
  return Column(
    children: [
      Text('Points for ${milestone.displayName}:'),
      ...['common', 'uncommon', 'rare', 'epic', 'legendary'].map((rarity) {
        final points = milestone.getPointsForRarity(rarity);
        return ListTile(
          leading: Icon(_getRarityIcon(rarity)),
          title: Text(rarity.toUpperCase()),
          trailing: Text(
            '+$points pts',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _getRarityColor(rarity),
            ),
          ),
        );
      }),
    ],
  );
}

// Example 6: Notification when milestone is close
// "You're 2 breeds away from earning 30 constellation points!"
Widget buildMilestoneAlert(BreedingProgress progress, String rarity) {
  if (progress.nextMilestone == null) return const SizedBox.shrink();
  
  final remaining = progress.nextMilestone!.count - progress.totalBred;
  final points = progress.nextMilestone!.getPointsForRarity(rarity);
  
  if (remaining <= 3 && remaining > 0) {
    return Card(
      color: Colors.amber.shade100,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.notification_important, color: Colors.amber.shade900),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Only $remaining more breed${remaining > 1 ? 's' : ''} '
                'to earn $points constellation points!',
                style: TextStyle(
                  color: Colors.amber.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  return const SizedBox.shrink();
}

============================================================================ */
