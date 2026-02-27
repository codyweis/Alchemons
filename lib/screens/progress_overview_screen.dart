// lib/screens/constellation_progress_overview_screen.dart
//
// REDESIGNED CONSTELLATION PROGRESS OVERVIEW
// Aesthetic: Scorched Forge — dark metal, amber reagent accents, monospace
// All logic, routing, FutureBuilder caching, and view-toggle preserved.
//

import 'package:alchemons/screens/breeding_milestones_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/database/alchemons_db.dart';

import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/constellation_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flame/image_composition.dart';

// ──────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ──────────────────────────────────────────────────────────────────────────────

// Rarity → forge-palette color (replaces Colors.xxx.shade500)
Color _rarityColor(String rarity) => switch (rarity.toLowerCase()) {
  'common' => const Color(0xFF6B7280),
  'uncommon' => const Color(0xFF34D399),
  'rare' => const Color(0xFF60A5FA),
  'epic' => const Color(0xFFA855F7),
  'legendary' => const Color(0xFFF59E0B),
  _ => const Color(0xFF6B7280),
};

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.black.withOpacity(0.07);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ──────────────────────────────────────────────────────────────────────────────
// SCREEN
// ──────────────────────────────────────────────────────────────────────────────

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

  final Map<String, Future<BreedingProgress>> _progressFutures = {};

  Future<BreedingProgress> _progressFor(
    ConstellationService service,
    String speciesId,
  ) => _progressFutures.putIfAbsent(
    speciesId,
    () => service.getBreedingProgress(speciesId),
  );

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CreatureCatalog>();
    final constellationService = context.watch<ConstellationService>();
    final db = context.read<AlchemonsDatabase>();

    final t = ForgeTokens(context.read<FactionTheme>());
    return Scaffold(
      backgroundColor: t.bg0,
      appBar: _buildAppBar(t),
      body: StreamBuilder<List<PlayerCreature>>(
        stream: db.creatureDao.watchDiscovered(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: t.amber));
          }
          final species = snapshot.data!
              .map((d) => catalog.getCreatureById(d.id))
              .whereType<Creature>()
              .toList();

          if (species.isEmpty) return _buildEmptyState(t);

          return _isCardView
              ? _buildCardView(species, constellationService, t)
              : _buildListView(species, constellationService, t);
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ForgeTokens t) {
    return AppBar(
      backgroundColor: t.bg1,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: t.bg2,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: t.borderDim),
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            color: t.textSecondary,
            size: 18,
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 8, bottom: 1),
                decoration: BoxDecoration(
                  color: t.amber,
                  shape: BoxShape.circle,
                ),
              ),
              Text(
                'CONSTELLATION PROGRESS',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: t.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            'BREEDING MILESTONES',
            style: TextStyle(
              fontFamily: 'monospace',
              color: t.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ),
      actions: [
        GestureDetector(
          onTap: () => setState(() => _isCardView = !_isCardView),
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: t.bg2,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: t.borderDim),
            ),
            child: Icon(
              _isCardView ? Icons.list_rounded : Icons.view_carousel_rounded,
              color: t.textSecondary,
              size: 18,
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: t.borderDim),
      ),
    );
  }

  // ── CARD VIEW ──────────────────────────────────────────────────────────────

  Widget _buildCardView(
    List<Creature> species,
    ConstellationService constellationService,
    ForgeTokens t,
  ) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                HapticFeedback.selectionClick();
                setState(() => _currentPage = index);
              },
              itemCount: species.length,
              itemBuilder: (context, index) {
                final creature = species[index];
                return MyAnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    double value = 1.0;
                    if (_pageController.position.haveDimensions) {
                      value = (_pageController.page! - index).abs();
                      value = (1 - (value * 0.15)).clamp(0.85, 1.0);
                    }
                    return Transform.scale(
                      scale: value,
                      child: Opacity(
                        opacity: value.clamp(0.8, 1.0),
                        child: child,
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: _SpeciesCard(
                      creature: creature,
                      progressFuture: _progressFor(
                        constellationService,
                        creature.id,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          _buildPageIndicator(species.length, t),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int count, ForgeTokens t) {
    if (count <= 8) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            count,
            (index) => GestureDetector(
              onTap: () => _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: index == _currentPage ? 24 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: index == _currentPage
                      ? t.amberBright
                      : t.borderAccent.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.fromLTRB(40, 12, 40, 12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${_currentPage + 1}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: t.amberBright,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  ' / $count',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: t.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Progress scrubber
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: t.borderMid,
                borderRadius: BorderRadius.circular(2),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      left: (constraints.maxWidth / count) * _currentPage,
                      child: Container(
                        width: constraints.maxWidth / count,
                        height: 3,
                        decoration: BoxDecoration(
                          color: t.amberBright,
                          borderRadius: BorderRadius.circular(2),
                        ),
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

  // ── LIST VIEW ──────────────────────────────────────────────────────────────

  Widget _buildListView(
    List<Creature> species,
    ConstellationService constellationService,
    ForgeTokens t,
  ) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.all(14),
      itemCount: species.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _ListItem(
          creature: species[index],
          progressFuture: _progressFor(constellationService, species[index].id),
        ),
      ),
    );
  }

  // ── EMPTY STATE ────────────────────────────────────────────────────────────

  Widget _buildEmptyState(ForgeTokens t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: t.bg2,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: t.borderAccent.withOpacity(0.5)),
              ),
              child: Icon(
                Icons.auto_awesome_outlined,
                size: 36,
                color: t.amber,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'NO SPECIES DISCOVERED',
              style: TextStyle(
                fontFamily: 'monospace',
                color: t.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Discover and breed creatures to track\nyour constellation progress',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'monospace',
                color: t.textSecondary,
                fontSize: 10,
                letterSpacing: 0.3,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// SPECIES CARD  (card view)
// ──────────────────────────────────────────────────────────────────────────────

class _SpeciesCard extends StatelessWidget {
  final Creature creature;
  final Future<BreedingProgress> progressFuture;

  const _SpeciesCard({required this.creature, required this.progressFuture});

  @override
  Widget build(BuildContext context) {
    final rColor = _rarityColor(creature.rarity);

    return FutureBuilder<BreedingProgress>(
      future: progressFuture,
      builder: (context, snapshot) {
        final t = ForgeTokens(context.read<FactionTheme>());
        // Loading skeleton
        if (!snapshot.hasData) {
          return Container(
            decoration: BoxDecoration(
              color: t.bg2,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: t.borderDim),
            ),
            child: Center(
              child: CircularProgressIndicator(color: t.amber, strokeWidth: 2),
            ),
          );
        }

        final progress = snapshot.data!;
        final nextMilestone = progress.nextMilestone;
        final isComplete = nextMilestone == null;
        final pointsForRarity =
            nextMilestone?.getPointsForRarity(creature.rarity) ?? 0;

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BreedingMilestoneScreen(speciesId: creature.id),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: t.bg2,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: rColor.withOpacity(0.35), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: rColor.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Scanlines
                Positioned.fill(
                  child: CustomPaint(painter: _ScanlinePainter()),
                ),
                // Radial glow
                Positioned(
                  top: -60,
                  right: -60,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [rColor.withOpacity(0.10), Colors.transparent],
                      ),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Top row — rarity badge + arrow
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _RarityBadge(rarity: creature.rarity, color: rColor),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: t.textMuted,
                            size: 14,
                          ),
                        ],
                      ),

                      // Sprite
                      Expanded(
                        flex: 3,
                        child: Center(
                          child: Hero(
                            tag: 'constellation_sprite_${creature.id}',
                            child: SizedBox(
                              width: 140,
                              height: 140,
                              child: RepaintBoundary(
                                child: CreatureSprite(
                                  spritePath:
                                      creature.spriteData!.spriteSheetPath,
                                  totalFrames: creature.spriteData!.totalFrames,
                                  rows: creature.spriteData!.rows,
                                  frameSize: Vector2(
                                    creature.spriteData!.frameWidth.toDouble(),
                                    creature.spriteData!.frameHeight.toDouble(),
                                  ),
                                  stepTime:
                                      creature.spriteData!.frameDurationMs /
                                      1000.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Name
                      Text(
                        creature.name.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: t.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),

                      // Stats panel
                      Expanded(
                        flex: 2,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: t.bg3,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: t.borderDim),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Bred count
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '${progress.totalBred}',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      color: t.textPrimary,
                                      fontSize: 36,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'BRED',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      color: t.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              if (!isComplete) ...[
                                _ProgressBar(
                                  progress: progress.progress,
                                  color: rColor,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '${nextMilestone.displayName}  (${nextMilestone.count})',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          color: t.textSecondary,
                                          fontSize: 10,
                                          letterSpacing: 0.5,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    _RewardBadge(
                                      points: pointsForRarity,
                                      color: rColor,
                                    ),
                                  ],
                                ),
                              ] else
                                _CompleteBadge(),
                            ],
                          ),
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
}

// ──────────────────────────────────────────────────────────────────────────────
// LIST ITEM  (list view)
// ──────────────────────────────────────────────────────────────────────────────

class _ListItem extends StatelessWidget {
  final Creature creature;
  final Future<BreedingProgress> progressFuture;

  const _ListItem({required this.creature, required this.progressFuture});

  @override
  Widget build(BuildContext context) {
    final rColor = _rarityColor(creature.rarity);

    return FutureBuilder<BreedingProgress>(
      future: progressFuture,
      builder: (context, snapshot) {
        final t = ForgeTokens(context.read<FactionTheme>());
        // Stable-height loading skeleton
        if (!snapshot.hasData) {
          return Container(
            height: 92,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.bg2,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: t.borderDim),
            ),
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: t.amber),
            ),
          );
        }

        final progress = snapshot.data!;
        final nextMilestone = progress.nextMilestone;
        final isComplete = nextMilestone == null;
        final pointsForRarity =
            nextMilestone?.getPointsForRarity(creature.rarity) ?? 0;

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BreedingMilestoneScreen(speciesId: creature.id),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.bg2,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: t.borderDim),
            ),
            child: Row(
              children: [
                // Sprite plate
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: t.bg3,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: rColor.withOpacity(0.4)),
                  ),
                  child: SizedBox(
                    width: 52,
                    height: 52,
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
                ),
                const SizedBox(width: 12),

                // Info column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + rarity badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              creature.name.toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: t.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _RarityBadge(
                            rarity: creature.rarity,
                            color: rColor,
                            small: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Bred count
                      Row(
                        children: [
                          Text(
                            '${progress.totalBred}',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: t.amberBright,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '  BRED',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: t.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),

                      if (!isComplete) ...[
                        _ProgressBar(
                          progress: progress.progress,
                          color: rColor,
                          height: 3,
                        ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'NEXT  ${nextMilestone.count}',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: t.textMuted,
                                fontSize: 9,
                                letterSpacing: 0.5,
                              ),
                            ),
                            _RewardBadge(
                              points: pointsForRarity,
                              color: rColor,
                              small: true,
                            ),
                          ],
                        ),
                      ] else
                        Row(
                          children: [
                            Icon(
                              Icons.emoji_events_rounded,
                              color: t.amberBright,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'COMPLETE',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: t.amberBright,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: t.textMuted, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// SHARED SMALL WIDGETS
// ──────────────────────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final double progress;
  final Color color;
  final double height;
  const _ProgressBar({
    required this.progress,
    required this.color,
    this.height = 5,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: t.borderMid,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progress.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.4), blurRadius: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RarityBadge extends StatelessWidget {
  final String rarity;
  final Color color;
  final bool small;
  const _RarityBadge({
    required this.rarity,
    required this.color,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: small ? 6 : 9,
      vertical: small ? 3 : 5,
    ),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(2),
      border: Border.all(color: color.withOpacity(0.4), width: 0.8),
    ),
    child: Text(
      rarity.toUpperCase(),
      style: TextStyle(
        fontFamily: 'monospace',
        color: color,
        fontSize: small ? 8 : 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.0,
      ),
    ),
  );
}

class _RewardBadge extends StatelessWidget {
  final int points;
  final Color color;
  final bool small;
  const _RewardBadge({
    required this.points,
    required this.color,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: small ? 5 : 8,
      vertical: small ? 2 : 4,
    ),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(2),
      border: Border.all(color: color.withOpacity(0.35), width: 0.8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.auto_awesome, color: color, size: small ? 9 : 11),
        const SizedBox(width: 3),
        Text(
          '+$points',
          style: TextStyle(
            fontFamily: 'monospace',
            color: color,
            fontSize: small ? 9 : 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _CompleteBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: t.amberDim.withOpacity(0.25),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: t.borderAccent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_rounded, color: t.amberBright, size: 16),
          const SizedBox(width: 8),
          Text(
            'ALL COMPLETE',
            style: TextStyle(
              fontFamily: 'monospace',
              color: t.amberBright,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// ANIMATED PAGE BUILDER (unchanged — avoids collision with Flutter's built-in)
// ──────────────────────────────────────────────────────────────────────────────

class MyAnimatedBuilder extends AnimatedWidget {
  final Widget? child;
  final Widget Function(BuildContext context, Widget? child) builder;

  const MyAnimatedBuilder({
    super.key,
    required Listenable animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) => builder(context, child);
}
