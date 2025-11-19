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
            Text(
              speciesName,
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
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
                _buildOverviewCard(theme, progress),
                const SizedBox(height: 16),
                _buildMilestonesList(theme, progress),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard(FactionTheme theme, BreedingProgress progress) {
    final nextMilestone = progress.nextMilestone;
    final isComplete = nextMilestone == null;

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
                    Text(
                      'Next: ${nextMilestone.count}',
                      style: TextStyle(
                        color: theme.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.shade600,
                            Colors.amber.shade700,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '+${nextMilestone.pointsAwarded}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
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

  Widget _buildMilestonesList(FactionTheme theme, BreedingProgress progress) {
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
            isComplete: isComplete,
            isCurrent: isCurrent,
          );
        }).toList(),
      ],
    );
  }

  Widget _buildMilestoneCard(
    FactionTheme theme,
    BreedingMilestone milestone, {
    required bool isComplete,
    required bool isCurrent,
  }) {
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
                Text(
                  'Breed ${milestone.count} specimens',
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Points badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: isComplete
                  ? LinearGradient(
                      colors: [Colors.amber.shade600, Colors.amber.shade700],
                    )
                  : null,
              color: isComplete ? null : theme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isComplete
                    ? Colors.amber.shade800
                    : theme.border.withOpacity(.5),
              ),
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
                  '+${milestone.pointsAwarded}',
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
    );
  }
}
