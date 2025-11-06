import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/creature_instance_service.dart';
import 'package:alchemons/utils/faction_util.dart';

/// Animated display showing the target creature being enhanced
/// REDESIGNED: More compact layout with reduced padding and cleaner spacing
class EnhancementDisplay extends StatefulWidget {
  final FactionTheme theme;
  final CreatureInstance instance;
  final FeedResult? preview;
  final Widget instanceSprite;
  final bool shouldAnimate; // one-shot trigger
  final int? preFeedLevel; // snapshot of level before feed
  final int? preFeedXp; // snapshot of xp before feed

  const EnhancementDisplay({
    super.key,
    required this.theme,
    required this.instance,
    required this.preview,
    required this.instanceSprite,
    this.shouldAnimate = false,
    this.preFeedLevel,
    this.preFeedXp,
  });

  @override
  State<EnhancementDisplay> createState() => _EnhancementDisplayState();
}

class _EnhancementDisplayState extends State<EnhancementDisplay>
    with TickerProviderStateMixin {
  // Controllers
  late AnimationController _xpController;
  late AnimationController _statController;
  late Animation<double> _xpAnimation;

  // Snapshot state for animation
  // FROM:
  double _fromProgress = 0.0;
  int _fromLevel = 0;
  int _fromMaxXp = 0;

  // TO:
  double _toProgress = 0.0;
  int _toLevel = 0;
  int _toMaxXp = 0;

  // Metadata
  bool _isAnimating = false;
  bool _isLevelingUp = false;
  bool _ignoreStatusListener = false; // Prevents status listener interference
  Map<String, double>?
  _lastStatGains; // Store stat gains to persist after preview clears
  bool _hasCompletedFeed = false; // Track if we've completed a feed animation

  @override
  void initState() {
    super.initState();
    print('EnhancementDisplay.initState() called');

    _xpController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1200),
        )..addStatusListener((status) {
          // ONLY set _isAnimating = false if we're not ignoring
          if ((status == AnimationStatus.completed ||
                  status == AnimationStatus.dismissed) &&
              !_ignoreStatusListener) {
            if (mounted) {
              setState(() {
                _isAnimating = false;
                _hasCompletedFeed = true; // Mark that we've completed a feed
              });
            }
          }
        });

    _statController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _xpAnimation = CurvedAnimation(
      parent: _xpController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(EnhancementDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);

    print(
      'didUpdateWidget: shouldAnimate=${widget.shouldAnimate}, oldShouldAnimate=${oldWidget.shouldAnimate}, isAnimating=$_isAnimating',
    );

    // Clear stat gains when preview is cleared ONLY if we haven't completed a feed
    // If we've completed a feed, keep the stats showing until new selection
    if (widget.preview == null &&
        oldWidget.preview != null &&
        !_hasCompletedFeed) {
      setState(() {
        _lastStatGains = null;
      });
    }

    // Clear the completed feed flag when we get a NEW preview (new material selection)
    if (widget.preview != null &&
        oldWidget.preview == null &&
        _hasCompletedFeed) {
      setState(() {
        _hasCompletedFeed = false;
      });
    }

    // Trigger ONLY on rising edge
    if (widget.shouldAnimate && !oldWidget.shouldAnimate) {
      print('TRIGGERING ANIMATION');
      _startAnimation();
    }
  }

  void _startAnimation() {
    // Block status listener during setup
    _ignoreStatusListener = true;

    // ---------
    // 1. SNAPSHOT START ("from")
    // ---------
    if (widget.preFeedLevel == null || widget.preFeedXp == null) {
      print('ERROR: preFeedLevel or preFeedXp is null, cannot animate');
      _ignoreStatusListener = false;
      return;
    }

    final startLevel = widget.preFeedLevel!;
    final startXp = widget.preFeedXp!;
    final startMaxXp = _getXpNeeded(startLevel);

    final startProgress = startMaxXp > 0
        ? (startXp / startMaxXp).clamp(0.0, 1.0)
        : 0.0;

    print(
      'Animation FROM: level=$startLevel, xp=$startXp, progress=$startProgress',
    );

    // ---------
    // 2. SNAPSHOT END ("to")
    // ---------
    final endLevel = widget.preview?.newLevel ?? widget.instance.level;
    final endMaxXp = _getXpNeeded(endLevel);

    final endProgress = (() {
      if (widget.preview != null) {
        return endMaxXp > 0
            ? (widget.preview!.newXpRemainder / endMaxXp).clamp(0.0, 1.0)
            : 0.0;
      } else {
        final liveXp = widget.instance.xp;
        final liveMax = _getXpNeeded(widget.instance.level);
        return liveMax > 0 ? (liveXp / liveMax).clamp(0.0, 1.0) : 0.0;
      }
    })();

    print('Animation TO: level=$endLevel, progress=$endProgress');

    final isLevelingUp = endLevel > startLevel;
    print('Is leveling up: $isLevelingUp');

    // ---------
    // 3. UPDATE STATE AND START ANIMATION
    // ---------
    setState(() {
      _fromLevel = startLevel;
      _fromMaxXp = startMaxXp;
      _fromProgress = startProgress;

      _toLevel = endLevel;
      _toMaxXp = endMaxXp;
      _toProgress = endProgress;

      _isLevelingUp = isLevelingUp;
      _isAnimating = true;
    });

    // Start animation
    _xpController.forward(from: 0.0);
    _statController.forward(from: 0.0);

    // Re-enable status listener AFTER animation starts
    _ignoreStatusListener = false;
  }

  int _getXpNeeded(int level) {
    const base = 100.0;
    const growth = 1.12;
    return (base * pow(growth, max(0, level - 1))).round();
  }

  // live helpers (used only AFTER animation)
  double _liveProgress() {
    final maxXp = _getXpNeeded(widget.instance.level);
    return maxXp > 0 ? (widget.instance.xp / maxXp).clamp(0.0, 1.0) : 0.0;
  }

  @override
  void dispose() {
    _xpController.dispose();
    _statController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('EnhancementDisplay.build() called - isAnimating=$_isAnimating');
    final repo = context.read<CreatureCatalog>();
    final creature = repo.getCreatureById(widget.instance.baseId);
    if (creature == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12), // REDUCED from 16
      decoration: BoxDecoration(
        color: widget.theme.surface,
        borderRadius: BorderRadius.circular(12), // REDUCED from 16
        border: Border.all(color: widget.theme.border, width: 1),
      ),
      child: Column(
        children: [
          // Creature + Level Row - MORE COMPACT
          Row(
            children: [
              // SMALLER sprite container
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: widget.theme.border, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: SizedBox(
                    width: 48, // REDUCED from default
                    height: 48,
                    child: widget.instanceSprite,
                  ),
                ),
              ),
              const SizedBox(width: 12), // REDUCED from 16
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      creature.name,
                      style: TextStyle(
                        color: widget.theme.text,
                        fontSize: 14, // REDUCED from 16
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2), // REDUCED from 4
                    // Just show current level - no preview
                    Text(
                      'Level ${widget.instance.level}',
                      style: TextStyle(
                        color: widget.theme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12), // REDUCED from 16
          // XP BAR (reduced height for compactness)
          SizedBox(
            height: 60, // REDUCED from 70
            child: AnimatedBuilder(
              animation: _xpAnimation,
              builder: (context, _) {
                // what should we render?
                final xpView = _buildXpViewForFrame();

                // showGainBadge only when we're idle
                final gainedXp = widget.preview?.totalXpGained;
                final showGainBadge =
                    !_isAnimating && gainedXp != null && gainedXp > 0;

                return _AnimatedXpBar(
                  theme: widget.theme,
                  currentXp: xpView.displayXp,
                  maxXp: xpView.displayMaxXp,
                  progress: xpView.displayProgress,
                  gainedXp: gainedXp,
                  showGainBadge: showGainBadge,
                );
              },
            ),
          ),

          // Stat gains (if any) - MORE COMPACT
          AnimatedBuilder(
            animation: _statController,
            builder: (context, _) {
              // Update _lastStatGains if preview has stat gains
              if (widget.preview?.statGains != null &&
                  widget.preview!.statGains!.isNotEmpty) {
                _lastStatGains = widget.preview!.statGains;
              }

              // Use _lastStatGains to persist display after preview clears
              final statGains = _lastStatGains;
              if (statGains == null || statGains.isEmpty) {
                return const SizedBox.shrink();
              }

              // Only show actual values AFTER feed animation completes
              // During preview (before feed), _hasCompletedFeed is false
              final showActualValues =
                  _hasCompletedFeed && !_isAnimating && !widget.shouldAnimate;

              print(
                'Stats display: _hasCompletedFeed=$_hasCompletedFeed, _isAnimating=$_isAnimating, shouldAnimate=${widget.shouldAnimate}, showActualValues=$showActualValues',
              );

              return Padding(
                padding: const EdgeInsets.only(top: 8), // REDUCED from default
                child: _StatGainsDisplay(
                  theme: widget.theme,
                  statGains: statGains,
                  animationValue: _statController.value,
                  isAnimating: _isAnimating,
                  creature: creature,
                  instance: widget.instance,
                  showActualValues: showActualValues,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Decides which XP values to render at the current animation frame
  _XpView _buildXpViewForFrame() {
    if (!_isAnimating) {
      // IDLE: show live data
      final liveLevel = widget.instance.level;
      final liveXp = widget.instance.xp;
      final liveMaxXp = _getXpNeeded(liveLevel);
      final liveProgress = _liveProgress();

      return _XpView(
        displayXp: liveXp,
        displayMaxXp: liveMaxXp,
        displayProgress: liveProgress,
      );
    }

    // ANIMATING
    final t = _xpAnimation.value;

    if (!_isLevelingUp) {
      // Simple fill, no level-up
      final interpXp = _lerpInt(
        _fromProgress * _fromMaxXp,
        _toProgress * _toMaxXp,
        t,
      );
      final interpProg = _lerpDouble(_fromProgress, _toProgress, t);

      return _XpView(
        displayXp: interpXp,
        displayMaxXp: _fromMaxXp,
        displayProgress: interpProg,
      );
    }

    // LEVEL-UP animation
    // Phase 1: fill to 100% on old bar
    if (t < 0.5) {
      final tPhase1 = t / 0.5;
      final interpXp = _lerpInt(
        _fromProgress * _fromMaxXp,
        _fromMaxXp.toDouble(),
        tPhase1,
      );
      final interpProg = _lerpDouble(_fromProgress, 1.0, tPhase1);

      return _XpView(
        displayXp: interpXp,
        displayMaxXp: _fromMaxXp,
        displayProgress: interpProg,
      );
    }

    // Phase 2: reset bar to new level, fill to final progress
    final tPhase2 = (t - 0.5) / 0.5;
    final interpXp = _lerpInt(0.0, _toProgress * _toMaxXp, tPhase2);
    final interpProg = _lerpDouble(0.0, _toProgress, tPhase2);

    return _XpView(
      displayXp: interpXp,
      displayMaxXp: _toMaxXp,
      displayProgress: interpProg,
    );
  }

  int _lerpInt(double a, double b, double t) {
    return (a + (b - a) * t).round();
  }

  double _lerpDouble(double a, double b, double t) {
    return a + (b - a) * t;
  }
}

/// Simple data class to hold XP values for a frame
class _XpView {
  final int displayXp;
  final int displayMaxXp;
  final double displayProgress;

  const _XpView({
    required this.displayXp,
    required this.displayMaxXp,
    required this.displayProgress,
  });
}

/// Level display with optional target level indicator
class _LevelDisplay extends StatefulWidget {
  final FactionTheme theme;
  final int currentLevel;
  final int? targetLevel;
  final bool isAnimating;

  const _LevelDisplay({
    required this.theme,
    required this.currentLevel,
    this.targetLevel,
    this.isAnimating = false,
  });

  @override
  State<_LevelDisplay> createState() => _LevelDisplayState();
}

class _LevelDisplayState extends State<_LevelDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _flashCtrl;

  @override
  void initState() {
    super.initState();
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _flashCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showTarget =
        widget.targetLevel != null && widget.targetLevel! > widget.currentLevel;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Current level
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 2,
          ), // REDUCED
          decoration: BoxDecoration(
            color: widget.theme.primary.withOpacity(.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: widget.theme.primary.withOpacity(.4)),
          ),
          child: Text(
            'Level ${widget.currentLevel}',
            style: TextStyle(
              color: widget.theme.primary,
              fontSize: 11, // REDUCED from 13
              fontWeight: FontWeight.w900,
            ),
          ),
        ),

        // Arrow + target if applicable
        if (showTarget) ...[
          AnimatedBuilder(
            animation: _flashCtrl,
            builder: (context, child) {
              final opacity = widget.isAnimating
                  ? (0.3 + _flashCtrl.value * 0.7)
                  : 1.0;
              return Opacity(opacity: opacity, child: child);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4), // REDUCED
              child: Icon(
                Icons.arrow_forward,
                size: 12, // REDUCED
                color: Colors.green.shade400,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 2,
            ), // REDUCED
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.green.withOpacity(.4)),
            ),
            child: Text(
              'Level ${widget.targetLevel}',
              style: TextStyle(
                color: Colors.green.shade400,
                fontSize: 11, // REDUCED from 13
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Animated XP progress bar UI - MORE COMPACT
class _AnimatedXpBar extends StatelessWidget {
  final FactionTheme theme;
  final int currentXp;
  final int maxXp;
  final double progress; // 0..1
  final int? gainedXp;
  final bool showGainBadge;

  const _AnimatedXpBar({
    required this.theme,
    required this.currentXp,
    required this.maxXp,
    required this.progress,
    this.gainedXp,
    required this.showGainBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // header row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Experience',
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 10, // REDUCED from 11
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            if (showGainBadge && gainedXp != null && gainedXp! > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2,
                ), // REDUCED
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.amber.withOpacity(.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bolt,
                      size: 9,
                      color: Colors.amber.shade400,
                    ), // REDUCED
                    const SizedBox(width: 2),
                    Text(
                      '+$gainedXp XP',
                      style: TextStyle(
                        color: Colors.amber.shade400,
                        fontSize: 9, // REDUCED from 10
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 4), // REDUCED from 6
        // bar - SMALLER
        Container(
          height: 20, // REDUCED from 24
          decoration: BoxDecoration(
            color: theme.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: progress.clamp(0.0, 1.0),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(color: theme.primary),
                  ),
                ),
                Center(
                  child: Text(
                    '$currentXp / $maxXp',
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 10, // REDUCED from 11
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Animated stat gains display - MORE COMPACT
class _StatGainsDisplay extends StatelessWidget {
  final FactionTheme theme;
  final Map<String, double>? statGains;
  final double animationValue; // 0..1 from controller
  final bool isAnimating;
  final Creature creature;
  final CreatureInstance instance;
  final bool showActualValues;

  const _StatGainsDisplay({
    required this.theme,
    required this.statGains,
    required this.animationValue,
    required this.isAnimating,
    required this.creature,
    required this.instance,
    required this.showActualValues,
  });

  @override
  Widget build(BuildContext context) {
    if (statGains == null) return const SizedBox.shrink();

    final stats = statGains!.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (stats.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          showActualValues ? 'New Stats' : 'Stat Increases',
          style: TextStyle(
            color: theme.textMuted,
            fontSize: 10, // REDUCED from 11
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6), // REDUCED from 8
        Wrap(
          spacing: 6, // REDUCED from 8
          runSpacing: 6, // REDUCED from 8
          children: [
            for (int i = 0; i < stats.length; i++)
              _buildChipAnimated(stats[i], i, stats.length),
          ],
        ),
      ],
    );
  }

  Widget _buildChipAnimated(
    MapEntry<String, double> entry,
    int index,
    int total,
  ) {
    print(
      '_buildChipAnimated: isAnimating=$isAnimating, showActualValues=$showActualValues',
    );

    if (showActualValues) {
      print('  -> Showing _StatValueChip (actual values)');
      // Show actual stat values (before → after)
      return _StatValueChip(
        statName: entry.key,
        gain: entry.value,
        creature: creature,
        instance: instance,
        theme: theme,
      );
    }

    // Always show gain chips without animation
    print('  -> Showing _StatGainChip (gain values)');
    return _StatGainChip(statName: entry.key, gain: entry.value, theme: theme);
  }
}

/// Individual stat gain chip - MORE COMPACT
class _StatGainChip extends StatelessWidget {
  final String statName;
  final double gain;
  final FactionTheme theme;

  const _StatGainChip({
    required this.statName,
    required this.gain,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _getStatStyle(statName);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            _formatStatName(statName),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            '+${gain.toStringAsFixed(2)}',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // pick icon + tint per stat name
  (IconData, Color) _getStatStyle(String stat) {
    switch (stat.toLowerCase()) {
      case 'speed':
        return (Icons.speed, Colors.cyan);
      case 'intelligence':
        return (Icons.psychology, Colors.purple);
      case 'strength':
        return (Icons.fitness_center, Colors.red);
      case 'beauty':
        return (Icons.auto_awesome, Colors.pink);
      default:
        return (Icons.star, Colors.amber);
    }
  }

  // shorten stat label if needed
  String _formatStatName(String stat) {
    switch (stat.toLowerCase()) {
      case 'intelligence':
        return 'Int';
      case 'strength':
        return 'Str';
      default:
        return stat[0].toUpperCase() + stat.substring(1);
    }
  }
}

/// Stat value chip showing before → after (used after enhancement completes)
class _StatValueChip extends StatelessWidget {
  final String statName;
  final double gain;
  final Creature creature;
  final CreatureInstance instance;
  final FactionTheme theme;

  const _StatValueChip({
    required this.statName,
    required this.gain,
    required this.creature,
    required this.instance,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _getStatStyle(statName);

    // Get the current (new) stat value from the instance
    final newValue = _getStatValue(statName);
    // Calculate the old value by subtracting the gain
    final oldValue = newValue - gain;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            _formatStatName(statName),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          // Old value FIRST
          Text(
            oldValue.toStringAsFixed(2),
            style: TextStyle(
              color: color.withOpacity(0.6),
              fontSize: 9,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(width: 3),
          Icon(Icons.arrow_forward, size: 10, color: color.withOpacity(0.7)),
          const SizedBox(width: 3),
          // New value SECOND (after arrow)
          Text(
            newValue.toStringAsFixed(2),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  double _getStatValue(String stat) {
    switch (stat.toLowerCase()) {
      case 'speed':
        return instance.statSpeed;
      case 'intelligence':
        return instance.statIntelligence;
      case 'strength':
        return instance.statStrength;
      case 'beauty':
        return instance.statBeauty;
      default:
        return 0.0;
    }
  }

  // pick icon + tint per stat name
  (IconData, Color) _getStatStyle(String stat) {
    switch (stat.toLowerCase()) {
      case 'speed':
        return (Icons.speed, Colors.cyan);
      case 'intelligence':
        return (Icons.psychology, Colors.purple);
      case 'strength':
        return (Icons.fitness_center, Colors.red);
      case 'beauty':
        return (Icons.auto_awesome, Colors.pink);
      default:
        return (Icons.star, Colors.amber);
    }
  }

  // shorten stat label if needed
  String _formatStatName(String stat) {
    switch (stat.toLowerCase()) {
      case 'intelligence':
        return 'Int';
      case 'strength':
        return 'Str';
      default:
        return stat[0].toUpperCase() + stat.substring(1);
    }
  }
}
