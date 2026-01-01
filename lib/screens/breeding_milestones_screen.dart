// lib/screens/breeding_milestone_screen.dart
import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/constellation_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';

class BreedingMilestoneScreen extends StatelessWidget {
  final String speciesId;

  const BreedingMilestoneScreen({super.key, required this.speciesId});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    final constellationService = context.watch<ConstellationService>();
    final catalog = context.watch<CreatureCatalog>();

    final species = catalog.getCreatureById(speciesId);
    final speciesName = species?.name ?? speciesId;
    final rarity = species?.rarity ?? 'common';

    return Scaffold(
      backgroundColor: theme.surface,
      appBar: AppBar(
        backgroundColor: theme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Specimen Progress',
              style: TextStyle(
                color: theme.text,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            Row(
              children: [
                Text(
                  speciesName,
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getRarityColor(rarity).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _getRarityColor(rarity).withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    rarity.toUpperCase(),
                    style: TextStyle(
                      color: _getRarityColor(rarity),
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: FutureBuilder<BreedingProgress>(
        future: constellationService.getBreedingProgress(speciesId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: theme.primary),
            );
          }

          final progress = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildOverviewCard(theme, progress, rarity),
                const SizedBox(height: 16),
                _buildMilestonesList(theme, progress, rarity),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard(
    FactionTheme theme,
    BreedingProgress progress,
    String rarity,
  ) {
    final nextMilestone = progress.nextMilestone;
    final isComplete = nextMilestone == null;
    final pointsForRarity = nextMilestone?.getPointsForRarity(rarity) ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primary.withOpacity(.2),
            theme.secondary.withOpacity(.15),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primary.withOpacity(.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withOpacity(.2),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Total bred
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome, color: theme.primary, size: 32),
              const SizedBox(width: 12),
              Text(
                '${progress.totalBred}',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'SPECIMENS BRED',
            style: TextStyle(
              color: theme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),

          if (!isComplete) ...[
            const SizedBox(height: 24),
            // Progress to next milestone
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next: ${nextMilestone!.displayName}',
                          style: TextStyle(
                            color: theme.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${nextMilestone.count} specimens',
                          style: TextStyle(
                            color: theme.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _getRarityColor(rarity),
                            _getRarityColor(rarity).withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: _getRarityColor(rarity).withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '+$pointsForRarity',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress.progress,
                    minHeight: 12,
                    backgroundColor: theme.surface,
                    valueColor: AlwaysStoppedAnimation(theme.primary),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${((progress.progress * 100).toInt())}% complete',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.primary.withOpacity(.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.primary.withOpacity(.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events, color: theme.primary, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'ALL MILESTONES COMPLETE!',
                    style: TextStyle(
                      color: theme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
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

  Widget _buildRarityBonusInfo(FactionTheme theme, String rarity) {
    final multiplier = _getRarityMultiplierText(rarity);
    final rarityColor = _getRarityColor(rarity);

    // Don't show for common rarity
    if (rarity.toLowerCase() == 'common') {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            rarityColor.withOpacity(0.15),
            rarityColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: rarityColor.withOpacity(0.4), width: 1.5),
      ),
      child: Text(
        multiplier,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildMilestonesList(
    FactionTheme theme,
    BreedingProgress progress,
    String rarity,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'MILESTONES',
          style: TextStyle(
            color: theme.primary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        ...BreedingMilestone.milestones.map((milestone) {
          final isComplete = progress.totalBred >= milestone.count;
          final isCurrent =
              !isComplete && (progress.nextMilestone?.count == milestone.count);

          return _buildMilestoneCard(
            theme,
            milestone,
            rarity,
            isComplete: isComplete,
            isCurrent: isCurrent,
          );
        }).toList(),
      ],
    );
  }

  Widget _buildMilestoneCard(
    FactionTheme theme,
    BreedingMilestone milestone,
    String rarity, {
    required bool isComplete,
    required bool isCurrent,
  }) {
    final pointsForRarity = milestone.getPointsForRarity(rarity);
    final rarityColor = _getRarityColor(rarity);
    final basePoints = milestone.pointsAwarded;
    final hasBonus = pointsForRarity > basePoints;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isComplete
            ? theme.primary.withOpacity(.15)
            : isCurrent
            ? theme.primary.withOpacity(.08)
            : theme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isComplete
              ? theme.primary.withOpacity(.5)
              : isCurrent
              ? theme.primary.withOpacity(.3)
              : theme.border.withOpacity(.3),
          width: isComplete || isCurrent ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isComplete ? theme.primary.withOpacity(.3) : theme.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: isComplete
                    ? theme.primary
                    : theme.border.withOpacity(.5),
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(
                isComplete
                    ? Icons.check_circle
                    : isCurrent
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isComplete
                    ? theme.primary
                    : isCurrent
                    ? theme.primary.withOpacity(.6)
                    : theme.textMuted,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  milestone.displayName,
                  style: TextStyle(
                    color: isComplete ? theme.primary : theme.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Breed ${milestone.count} specimens',
                      style: TextStyle(
                        color: theme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (hasBonus && !isComplete) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.workspace_premium,
                        color: rarityColor,
                        size: 11,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Points badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: isComplete
                      ? LinearGradient(
                          colors: [rarityColor, rarityColor.withOpacity(0.8)],
                        )
                      : null,
                  color: isComplete ? null : theme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isComplete
                        ? rarityColor.withOpacity(0.8)
                        : theme.border.withOpacity(.5),
                  ),
                  boxShadow: isComplete
                      ? [
                          BoxShadow(
                            color: rarityColor.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: isComplete ? Colors.white : theme.textMuted,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+$pointsForRarity',
                      style: TextStyle(
                        color: isComplete ? Colors.white : theme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return Colors.grey.shade600;
      case 'uncommon':
        return Colors.green.shade600;
      case 'rare':
        return Colors.blue.shade600;
      case 'legendary':
        return Colors.amber.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String _getRarityMultiplierText(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return '1x';
      case 'uncommon':
        return '2x';
      case 'rare':
        return '3x';
      case 'legendary':
        return '4x';
      default:
        return '1x';
    }
  }
}
