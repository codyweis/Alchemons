// lib/screens/constellation_progress_overview_screen.dart

import 'package:alchemons/screens/breeding_milestones_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/constellation_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flame/image_composition.dart';

class ConstellationProgressOverviewScreen extends StatefulWidget {
  const ConstellationProgressOverviewScreen({super.key});

  @override
  State<ConstellationProgressOverviewScreen> createState() =>
      _ConstellationProgressOverviewScreenState();
}

class _ConstellationProgressOverviewScreenState
    extends State<ConstellationProgressOverviewScreen> {
  bool _isCardView = true;
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    final catalog = context.watch<CreatureCatalog>();
    final constellationService = context.watch<ConstellationService>();
    final db = context.read<AlchemonsDatabase>();

    return Scaffold(
      backgroundColor: theme.surface,
      appBar: AppBar(
        backgroundColor: theme.surfaceAlt,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Constellation Progress',
              style: TextStyle(
                color: theme.text,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'Breeding milestones',
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isCardView ? Icons.list_rounded : Icons.view_carousel_rounded,
              color: theme.text,
            ),
            onPressed: () {
              setState(() {
                _isCardView = !_isCardView;
              });
            },
          ),
        ],
      ),
      body: StreamBuilder<List<PlayerCreature>>(
        stream: db.creatureDao.watchDiscovered(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: theme.primary),
            );
          }

          // Get all discovered species
          final discovered = snapshot.data!;
          final species = discovered
              .map((d) => catalog.getCreatureById(d.id))
              .whereType<Creature>()
              .toList();

          if (species.isEmpty) {
            return _buildEmptyState(theme);
          }

          return _isCardView
              ? _buildCardView(theme, species, constellationService)
              : _buildListView(theme, species, constellationService);
        },
      ),
    );
  }

  Widget _buildCardView(
    FactionTheme theme,
    List<Creature> species,
    ConstellationService constellationService,
  ) {
    return Column(
      children: [
        // Page indicator
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${_currentPage + 1}',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                ' / ${species.length}',
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // Swipeable cards
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: species.length,
            itemBuilder: (context, index) {
              final creature = species[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildSpeciesCard(theme, creature, constellationService),
              );
            },
          ),
        ),
        // Navigation dots
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              species.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: index == _currentPage ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: index == _currentPage
                      ? theme.primary
                      : theme.textMuted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeciesCard(
    FactionTheme theme,
    Creature creature,
    ConstellationService constellationService,
  ) {
    return FutureBuilder<BreedingProgress>(
      future: constellationService.getBreedingProgress(creature.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: theme.primary));
        }

        final progress = snapshot.data!;
        final nextMilestone = progress.nextMilestone;
        final isComplete = nextMilestone == null;
        final pointsForRarity =
            nextMilestone?.getPointsForRarity(creature.rarity) ?? 0;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BreedingMilestoneScreen(speciesId: creature.id),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.border.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Creature sprite
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Hero(
                      tag: 'constellation_sprite_${creature.id}',
                      child: SizedBox(
                        width: 200,
                        height: 200,
                        child: RepaintBoundary(
                          child: CreatureSprite(
                            spritePath: creature.spriteData!.spriteSheetPath,
                            totalFrames: creature.spriteData!.totalFrames,
                            rows: creature.spriteData!.rows,
                            frameSize: Vector2(
                              creature.spriteData!.frameWidth.toDouble(),
                              creature.spriteData!.frameHeight.toDouble(),
                            ),
                            stepTime:
                                creature.spriteData!.frameDurationMs / 1000.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Creature info
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Name
                      Text(
                        creature.name,
                        style: TextStyle(
                          color: theme.text,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),

                      // Rarity badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _getRarityColor(
                              creature.rarity,
                            ).withOpacity(0.6),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          creature.rarity.toUpperCase(),
                          style: TextStyle(
                            color: _getRarityColor(creature.rarity),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Progress stats
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.border.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Total bred
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${progress.totalBred}',
                                  style: TextStyle(
                                    color: theme.text,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'SPECIMENS BRED',
                              style: TextStyle(
                                color: theme.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            if (!isComplete) ...[
                              const SizedBox(height: 20),
                              // Progress bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: progress.progress,
                                  minHeight: 8,
                                  backgroundColor: theme.meterTrack,
                                  valueColor: AlwaysStoppedAnimation(
                                    theme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Next milestone
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Next: ${nextMilestone!.displayName}',
                                        style: TextStyle(
                                          color: theme.text,
                                          fontSize: 12,
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
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: _getRarityColor(
                                          creature.rarity,
                                        ).withOpacity(0.6),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.auto_awesome,
                                          color: _getRarityColor(
                                            creature.rarity,
                                          ),
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '+$pointsForRarity',
                                          style: TextStyle(
                                            color: _getRarityColor(
                                              creature.rarity,
                                            ),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: theme.primary.withOpacity(0.6),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.emoji_events,
                                      color: theme.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'ALL MILESTONES COMPLETE',
                                      style: TextStyle(
                                        color: theme.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tap for details • Swipe for next',
                        style: TextStyle(
                          color: theme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
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

  Widget _buildListView(
    FactionTheme theme,
    List<Creature> species,
    ConstellationService constellationService,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: species.length,
      itemBuilder: (context, index) {
        final creature = species[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildListItem(theme, creature, constellationService),
        );
      },
    );
  }

  Widget _buildListItem(
    FactionTheme theme,
    Creature creature,
    ConstellationService constellationService,
  ) {
    return FutureBuilder<BreedingProgress>(
      future: constellationService.getBreedingProgress(creature.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final progress = snapshot.data!;
        final nextMilestone = progress.nextMilestone;
        final isComplete = nextMilestone == null;
        final pointsForRarity =
            nextMilestone?.getPointsForRarity(creature.rarity) ?? 0;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BreedingMilestoneScreen(speciesId: creature.id),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.border.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Sprite
                SizedBox(
                  width: 60,
                  height: 60,
                  child: RepaintBoundary(
                    child: CreatureSprite(
                      spritePath: creature.spriteData!.spriteSheetPath,
                      totalFrames: creature.spriteData!.totalFrames,
                      rows: creature.spriteData!.rows,
                      frameSize: Vector2(
                        creature.spriteData!.frameWidth.toDouble(),
                        creature.spriteData!.frameHeight.toDouble(),
                      ),
                      stepTime: creature.spriteData!.frameDurationMs / 1000.0,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              creature.name,
                              style: TextStyle(
                                color: theme.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: _getRarityColor(
                                  creature.rarity,
                                ).withOpacity(0.6),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              creature.rarity.toUpperCase(),
                              style: TextStyle(
                                color: _getRarityColor(creature.rarity),
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: theme.primary,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${progress.totalBred} bred',
                            style: TextStyle(
                              color: theme.text,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (!isComplete) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress.progress,
                            minHeight: 6,
                            backgroundColor: theme.meterTrack,
                            valueColor: AlwaysStoppedAnimation(theme.primary),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Next: ${nextMilestone!.count}',
                              style: TextStyle(
                                color: theme.textMuted,
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
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _getRarityColor(
                                    creature.rarity,
                                  ).withOpacity(0.6),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    color: _getRarityColor(creature.rarity),
                                    size: 10,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '+$pointsForRarity',
                                    style: TextStyle(
                                      color: _getRarityColor(creature.rarity),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ] else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: theme.primary.withOpacity(0.6),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.emoji_events,
                                color: theme.primary,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Complete',
                                style: TextStyle(
                                  color: theme.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
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

  Widget _buildEmptyState(FactionTheme theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_outlined, size: 64, color: theme.textMuted),
            const SizedBox(height: 16),
            Text(
              'No Species Discovered',
              style: TextStyle(
                color: theme.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Discover and breed creatures to track your constellation progress',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
      case 'epic':
        return Colors.purple.shade600;
      case 'legendary':
        return Colors.amber.shade600;
      default:
        return Colors.grey.shade600;
    }
  }
}
