// lib/screens/breeding_milestone_screen.dart
import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/services/constellation_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';

class BreedingMilestoneScreen extends StatelessWidget {
  final String speciesId;

  const BreedingMilestoneScreen({super.key, required this.speciesId});

  @override
  Widget build(BuildContext context) {
    final constellationService = context.watch<ConstellationService>();
    final catalog = context.watch<CreatureCatalog>();

    final species = catalog.getCreatureById(speciesId);
    final speciesName = species?.name ?? speciesId;
    final rarity = species?.rarity ?? 'common';
    final theme = context.read<FactionTheme>();
    final t = ForgeTokens(theme);
    final rarityColor = _rarityColor(rarity, t);

    return Scaffold(
      backgroundColor: t.bg0,
      appBar: AppBar(
        backgroundColor: t.bg1,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: t.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SPECIMEN PROGRESS',
              style: TextStyle(
                fontFamily: 'monospace',
                color: t.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            Row(
              children: [
                Text(
                  speciesName,
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: rarityColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: rarityColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    rarity.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: rarityColor,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
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
            return Center(child: CircularProgressIndicator(color: t.amber));
          }

          final progress = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildOverviewCard(progress, rarity, t),
                const SizedBox(height: 16),
                _buildMilestonesList(progress, rarity, t),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard(
    BreedingProgress progress,
    String rarity,
    ForgeTokens t,
  ) {
    final nextMilestone = progress.nextMilestone;
    final isComplete = nextMilestone == null;
    final pointsForRarity = nextMilestone?.getPointsForRarity(rarity) ?? 0;
    final rarityColor = _rarityColor(rarity, t);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.bg2,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: t.borderAccent),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.science_outlined, color: t.amberBright, size: 28),
              const SizedBox(width: 12),
              Text(
                '${progress.totalBred}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Color(0xFFFFB020),
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'SPECIMENS BRED',
            style: TextStyle(
              fontFamily: 'monospace',
              color: t.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),

          if (!isComplete) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.bg3,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: t.borderDim),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NEXT: ${nextMilestone.displayName.toUpperCase()}',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: t.textPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${nextMilestone.count} specimens required',
                            style: TextStyle(
                              color: t.textSecondary,
                              fontSize: 10,
                              height: 1.5,
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
                          color: rarityColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(
                            color: rarityColor.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.star, color: rarityColor, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              '+$pointsForRarity pts',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: rarityColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: t.bg0,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: t.borderDim),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress.progress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [const Color(0xFFFFB020), t.amber],
                          ),
                          borderRadius: const BorderRadius.all(
                            Radius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${(progress.progress * 100).toInt()}% complete',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 10,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: t.success.withOpacity(0.45)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events, color: t.success, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'ALL MILESTONES COMPLETE',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: t.success,
                      fontSize: 12,
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

  Widget _buildMilestonesList(
    BreedingProgress progress,
    String rarity,
    ForgeTokens t,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(width: 3, height: 14, color: t.amber),
            const SizedBox(width: 8),
            Text(
              'MILESTONES',
              style: TextStyle(
                fontFamily: 'monospace',
                color: t.amberBright,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...BreedingMilestone.milestones.map((milestone) {
          final isComplete = progress.totalBred >= milestone.count;
          final isCurrent =
              !isComplete && (progress.nextMilestone?.count == milestone.count);
          return _buildMilestoneCard(
            milestone,
            rarity,
            t,
            isComplete: isComplete,
            isCurrent: isCurrent,
          );
        }),
      ],
    );
  }

  Widget _buildMilestoneCard(
    BreedingMilestone milestone,
    String rarity,
    ForgeTokens t, {
    required bool isComplete,
    required bool isCurrent,
  }) {
    final pointsForRarity = milestone.getPointsForRarity(rarity);
    final hasBonus = pointsForRarity > milestone.pointsAwarded;
    final rarityColor = _rarityColor(rarity, t);

    final borderColor = isComplete
        ? t.amber.withOpacity(0.55)
        : isCurrent
        ? t.amberDim.withOpacity(0.6)
        : t.borderDim;
    final bgColor = isComplete
        ? t.amber.withOpacity(0.08)
        : isCurrent
        ? t.bg2
        : t.bg1;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isComplete ? t.amber.withOpacity(0.18) : t.bg3,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: isComplete ? t.amber : t.borderDim),
            ),
            child: Center(
              child: Icon(
                isComplete
                    ? Icons.check
                    : isCurrent
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isComplete
                    ? t.amberBright
                    : isCurrent
                    ? t.amberDim
                    : t.textSecondary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  milestone.displayName.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: isComplete ? t.amberBright : t.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      'Breed ${milestone.count}',
                      style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 10,
                        height: 1.5,
                      ),
                    ),
                    if (hasBonus && !isComplete) ...[
                      const SizedBox(width: 5),
                      Icon(
                        Icons.workspace_premium,
                        color: rarityColor,
                        size: 10,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'BONUS',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: rarityColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isComplete ? rarityColor.withOpacity(0.18) : t.bg3,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(
                color: isComplete ? rarityColor.withOpacity(0.6) : t.borderDim,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star,
                  color: isComplete ? rarityColor : t.textSecondary,
                  size: 11,
                ),
                const SizedBox(width: 4),
                Text(
                  '+$pointsForRarity',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: isComplete ? rarityColor : t.textSecondary,
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

  Color _rarityColor(String rarity, ForgeTokens t) {
    switch (rarity.toLowerCase()) {
      case 'uncommon':
        return t.success;
      case 'rare':
        return const Color(0xFF3B82F6);
      case 'legendary':
        return t.amber;
      default:
        return const Color(0xFF8A9BAA);
    }
  }
}
