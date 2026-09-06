import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_instance_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/show_quick_instance_dialog.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:alchemons/widgets/creature_image.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fast_long_press_detector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/models/stat_system.dart';

// ---------- Header ----------

class StageHeader extends StatelessWidget {
  final FactionTheme theme;
  final String stage;
  final int selectedCount;
  final VoidCallback onBack;
  final VoidCallback? onOpenAllInstances;

  const StageHeader({
    super.key,
    required this.theme,
    required this.stage,
    required this.selectedCount,
    required this.onBack,
    this.onOpenAllInstances,
  });

  int _stageIndex() {
    switch (stage) {
      case 'species':
        return 0;
      case 'instance':
        return 1;
      case 'fodder':
        return 2;
      default:
        return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final t = ForgeTokens(theme);
    final canGoBack = stage != 'species';
    final (title, subtitle) = _getStageText();
    final step = _stageIndex();
    const stepLabels = ['SPECIES', 'SPECIMEN', 'MATERIAL'];

    return Container(
      decoration: BoxDecoration(
        color: t.bg1,
        border: Border(bottom: BorderSide(color: t.borderDim)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                if (canGoBack)
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: t.bg2,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: t.borderDim),
                      ),
                      child: Icon(
                        AppIcons.arrow_back,
                        color: t.textPrimary,
                        size: 18,
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: fc.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: t.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                if (stage == 'species' && onOpenAllInstances != null)
                  GestureDetector(
                    onTap: onOpenAllInstances,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: t.bg2,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: t.borderDim),
                      ),
                      child: Icon(
                        AppIcons.grid_view_rounded,
                        color: t.textSecondary,
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Step progress indicator
          if (step >= 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: List<Widget>.generate(stepLabels.length * 2 - 1, (i) {
                  if (i.isOdd) {
                    final filled = step > (i ~/ 2);
                    return Expanded(
                      child: Container(
                        height: 1.5,
                        color: filled
                            ? fc.amber.withValues(alpha: 0.55)
                            : t.borderDim,
                      ),
                    );
                  }
                  final idx = i ~/ 2;
                  final isDone = step > idx;
                  final isActive = step == idx;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive
                              ? fc.amber
                              : (isDone ? fc.amberDim : t.bg3),
                          border: Border.all(
                            color: isActive
                                ? fc.amberGlow
                                : (isDone
                                      ? fc.amber.withValues(alpha: 0.4)
                                      : t.borderDim),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: isDone
                              ? Icon(
                                  AppIcons.check,
                                  size: 10,
                                  color: fc.amberBright,
                                )
                              : Text(
                                  '${idx + 1}',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: isActive ? fc.bg0 : t.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        stepLabels[idx],
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: isActive
                              ? fc.amberBright
                              : (isDone ? t.textSecondary : t.textMuted),
                          fontSize: 7,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  (String, String?) _getStageText() {
    switch (stage) {
      case 'species':
        return ('Choose Species', 'Select which species to enhance');
      case 'instance':
        return ('Choose Specimen', 'Select the specimen to strengthen');
      case 'all_instances':
        return ('All Specimens', 'Select the specimen to enhance');
      case 'fodder':
        return (
          'Select Elemental Enhancements',
          selectedCount > 0
              ? '$selectedCount selected'
              : 'Choose specimens to convert into elemental material',
        );
      default:
        return ('', null);
    }
  }
}

// ---------- XP Bar Display ----------

class XPBarDisplay extends StatefulWidget {
  final FactionTheme theme;
  final CreatureInstance instance;
  final bool isAnimating;
  final int? preFeedLevel;
  final int? preFeedXp;

  const XPBarDisplay({
    super.key,
    required this.theme,
    required this.instance,
    required this.isAnimating,
    this.preFeedLevel,
    this.preFeedXp,
  });

  @override
  State<XPBarDisplay> createState() => _XPBarDisplayState();
}

class _XPBarDisplayState extends State<XPBarDisplay>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late AnimationController _levelFlashController;
  late Animation<double> _xpAnimation;
  bool _flashFiredThisRun = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _levelFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _setupAnimations();
    _animController.addListener(_maybeTriggerLevelFlash);
  }

  void _setupAnimations() {
    _xpAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
  }

  void _maybeTriggerLevelFlash() {
    if (!widget.isAnimating || _flashFiredThisRun) return;
    final startLevel = widget.preFeedLevel ?? widget.instance.level;
    final endLevel = widget.instance.level;
    if (endLevel <= startLevel) return;
    // Trigger the flash right as the bar crosses the level threshold.
    if (_animController.value >= 0.5) {
      _flashFiredThisRun = true;
      HapticFeedback.mediumImpact();
      _levelFlashController.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(XPBarDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isAnimating && !oldWidget.isAnimating) {
      _setupAnimations();
      _flashFiredThisRun = false;
      _levelFlashController.reset();
      _animController.forward(from: 0.0);
    } else if (!widget.isAnimating && oldWidget.isAnimating) {
      _animController.reset();
      _flashFiredThisRun = false;
    }
  }

  @override
  void dispose() {
    _animController.removeListener(_maybeTriggerLevelFlash);
    _animController.dispose();
    _levelFlashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final t = ForgeTokens(widget.theme);
    final currentLevel = widget.instance.level;
    final currentXp = widget.instance.xp;
    final repo = context.read<CreatureCatalog>();
    final creature = repo.getCreatureById(widget.instance.baseId);
    final rarity = creature?.rarity ?? 'Common';
    final xpNeeded = CreatureInstanceServiceFeeding.xpNeededForLevel(
      currentLevel,
      rarity: rarity,
    );

    return AnimatedBuilder(
      animation: Listenable.merge([_animController, _levelFlashController]),
      builder: (context, child) {
        final frame = _buildXpFrame(
          rarity: rarity,
          liveLevel: currentLevel,
          liveXp: currentXp,
          liveMaxXp: xpNeeded,
        );

        final flash = _levelFlashController.value;
        final burstT = flash == 0.0
            ? 0.0
            : (flash < 0.35
                  ? flash / 0.35
                  : 1.0 - ((flash - 0.35) / 0.65).clamp(0.0, 1.0));
        final isMaxLevel = currentLevel >= 10;

        if (isMaxLevel) {
          return Container(
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fc.amberBright.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: fc.amber.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Text(
              'MAX LEVEL',
              style: TextStyle(
                color: fc.amberBright,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 20,
              decoration: BoxDecoration(
                color: fc.bg0,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: fc.borderDim, width: 1),
                boxShadow: burstT > 0
                    ? [
                        BoxShadow(
                          color: fc.amberDim.withValues(alpha: burstT * 0.5),
                          blurRadius: burstT * 12,
                          spreadRadius: burstT * 1.5,
                        ),
                      ]
                    : const [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Stack(
                  children: [
                    FractionallySizedBox(
                      widthFactor: frame.displayProgress.clamp(0.0, 1.0),
                      child: Container(color: fc.amber),
                    ),
                    if (burstT > 0)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white.withValues(alpha: 0.55 * burstT),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                                stops: [
                                  (flash - 0.15).clamp(0.0, 1.0),
                                  flash.clamp(0.0, 1.0),
                                  (flash + 0.15).clamp(0.0, 1.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    Center(
                      child: Text(
                        '${frame.displayXp} / ${frame.displayMaxXp}',
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (burstT > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Opacity(
                      opacity: burstT.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, -16 * burstT),
                        child: Transform.scale(
                          scale: 0.8 + burstT * 0.4,
                          child: Text(
                            'LEVEL UP!',
                            style: TextStyle(
                              color: fc.amberBright,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  blurRadius: 4,
                                ),
                                Shadow(
                                  color: fc.amberGlow.withValues(alpha: 0.8),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  _XpBarFrame _buildXpFrame({
    required String rarity,
    required int liveLevel,
    required int liveXp,
    required int liveMaxXp,
  }) {
    if (!widget.isAnimating) {
      final progress = liveMaxXp > 0
          ? (liveXp / liveMaxXp).clamp(0.0, 1.0)
          : 0.0;
      return _XpBarFrame(
        displayLevel: liveLevel,
        displayXp: liveXp,
        displayMaxXp: liveMaxXp,
        displayProgress: progress,
      );
    }

    final startLevel = widget.preFeedLevel ?? liveLevel;
    final startXp = widget.preFeedXp ?? liveXp;
    final endLevel = liveLevel;
    final endXp = liveXp;
    final startMaxXp = CreatureInstanceServiceFeeding.xpNeededForLevel(
      startLevel,
      rarity: rarity,
    );
    final endMaxXp = CreatureInstanceServiceFeeding.xpNeededForLevel(
      endLevel,
      rarity: rarity,
    );
    final t = _xpAnimation.value;

    if (startLevel == endLevel) {
      final startProgress = startMaxXp > 0
          ? (startXp / startMaxXp).clamp(0.0, 1.0)
          : 0.0;
      final endProgress = endMaxXp > 0
          ? (endXp / endMaxXp).clamp(0.0, 1.0)
          : 0.0;
      final progress = _lerpDouble(startProgress, endProgress, t);
      return _XpBarFrame(
        displayLevel: startLevel,
        displayXp: (progress * startMaxXp).round(),
        displayMaxXp: startMaxXp,
        displayProgress: progress,
      );
    }

    if (t < 0.5) {
      final localT = t / 0.5;
      final startProgress = startMaxXp > 0
          ? (startXp / startMaxXp).clamp(0.0, 1.0)
          : 0.0;
      final progress = _lerpDouble(startProgress, 1.0, localT);
      return _XpBarFrame(
        displayLevel: startLevel,
        displayXp: (progress * startMaxXp).round(),
        displayMaxXp: startMaxXp,
        displayProgress: progress,
      );
    }

    final localT = (t - 0.5) / 0.5;
    final endProgress = endMaxXp > 0 ? (endXp / endMaxXp).clamp(0.0, 1.0) : 0.0;
    final progress = _lerpDouble(0.0, endProgress, localT);
    return _XpBarFrame(
      displayLevel: endLevel,
      displayXp: (progress * endMaxXp).round(),
      displayMaxXp: endMaxXp,
      displayProgress: progress,
    );
  }

  double _lerpDouble(double a, double b, double t) => a + ((b - a) * t);
}

class _XpBarFrame {
  final int displayLevel;
  final int displayXp;
  final int displayMaxXp;
  final double displayProgress;

  const _XpBarFrame({
    required this.displayLevel,
    required this.displayXp,
    required this.displayMaxXp,
    required this.displayProgress,
  });
}

// ---------- Level Chip ----------

class _LevelChip extends StatelessWidget {
  final FactionTheme theme;
  final int level;
  final int? previewLevel;
  final bool isAnimating;

  const _LevelChip({
    required this.theme,
    required this.level,
    required this.previewLevel,
    required this.isAnimating,
  });

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final showPreview =
        !isAnimating && previewLevel != null && previewLevel! > level;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fc.amber.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: fc.amberBright.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppIcons.shield_moon_outlined,
            size: 13,
            color: Colors.black.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 4),
          Text(
            'LV $level',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
          if (showPreview) ...[
            const SizedBox(width: 5),
            Icon(
              AppIcons.arrow_forward_rounded,
              size: 12,
              color: Colors.black.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 2),
            Text(
              '$previewLevel',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------- Current Stats Display ----------

class CurrentStatsDisplay extends StatelessWidget {
  final FactionTheme theme;
  final CreatureInstance instance;
  final Creature creature;
  final FeedResult? preview;
  final bool isAnimating;
  final int? preFeedLevel;
  final int? preFeedXp;
  final Widget? constellationTrailing;

  const CurrentStatsDisplay({
    super.key,
    required this.theme,
    required this.instance,
    required this.creature,
    this.preview,
    this.isAnimating = false,
    this.preFeedLevel,
    this.preFeedXp,
    this.constellationTrailing,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    final gains = preview?.statGains ?? const <String, double>{};
    final hasPreview = preview != null && preview!.ok;
    final previewLevel = hasPreview ? preview!.newLevel : null;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 110,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                bottom: 4,
                                child: FastLongPressDetector(
                                  onLongPress: () {
                                    showQuickInstanceDialog(
                                      context: context,
                                      theme: theme,
                                      creature: creature,
                                      instance: instance,
                                    );
                                  },
                                  child: InstanceSprite(
                                    creature: creature,
                                    instance: instance,
                                    size: 96,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          creature.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _LevelChip(
                            theme: theme,
                            level: instance.level,
                            previewLevel: previewLevel,
                            isAnimating: isAnimating,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              UnifiedStatRow(
                                label: 'SPD',
                                current: instance.statSpeed,
                                potential: instance.statSpeedPotential,
                                gain: gains['speed'] ?? 0,
                                hasPreview: hasPreview,
                                theme: theme,
                                color: AlchemicalPowerupType.speed.color,
                              ),
                              UnifiedStatRow(
                                label: 'INT',
                                current: instance.statIntelligence,
                                potential: instance.statIntelligencePotential,
                                gain: gains['intelligence'] ?? 0,
                                hasPreview: hasPreview,
                                theme: theme,
                                color: AlchemicalPowerupType.intelligence.color,
                              ),
                              UnifiedStatRow(
                                label: 'STR',
                                current: instance.statStrength,
                                potential: instance.statStrengthPotential,
                                gain: gains['strength'] ?? 0,
                                hasPreview: hasPreview,
                                theme: theme,
                                color: AlchemicalPowerupType.strength.color,
                              ),
                              UnifiedStatRow(
                                label: 'BEA',
                                current: instance.statBeauty,
                                potential: instance.statBeautyPotential,
                                gain: gains['beauty'] ?? 0,
                                hasPreview: hasPreview,
                                theme: theme,
                                color: AlchemicalPowerupType.beauty.color,
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
            const SizedBox(height: 10),
            XPBarDisplay(
              theme: theme,
              instance: instance,
              isAnimating: isAnimating,
              preFeedLevel: preFeedLevel,
              preFeedXp: preFeedXp,
            ),
          ],
        ),
        if (constellationTrailing != null)
          Positioned(top: 0, left: 0, child: constellationTrailing!),
      ],
    );
  }
}

// ---------- Unified Stat Row ----------
//
// One row per stat. Shows the label, a bar with current + projected-gain
// segment, and `current → projected` inline. Reserves space for the
// projected column even when no preview is active so the panel height is
// stable across selection changes.

class UnifiedStatRow extends StatelessWidget {
  final String label;
  final double current;
  final double potential;
  final double gain;
  final bool hasPreview;
  final FactionTheme theme;
  final Color color;

  const UnifiedStatRow({
    super.key,
    required this.label,
    required this.current,
    required this.potential,
    required this.gain,
    required this.hasPreview,
    required this.theme,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final t = ForgeTokens(theme);

    final currentRating = AlchemonStatSystem.displayRating(current);
    final potentialRating = AlchemonStatSystem.normalizePotential(potential);
    final currentPct = AlchemonStatSystem.displayFraction(current);
    final potentialPct = potentialRating / 100.0;
    final projected = current + gain;
    final projectedRating = AlchemonStatSystem.displayRating(projected);
    final projectedPct = AlchemonStatSystem.displayFraction(projected);

    final showGain = hasPreview && gain != 0;
    final gainColor = gain > 0
        ? color
        : (gain < 0 ? fc.danger : t.textSecondary);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              label,
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 9,
              decoration: BoxDecoration(
                color: t.bg1,
                borderRadius: const BorderRadius.all(Radius.circular(5)),
              ),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: potentialPct,
                    child: Container(
                      decoration: BoxDecoration(
                        color: t.borderMid,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(5),
                        ),
                      ),
                    ),
                  ),
                  if (showGain && gain > 0)
                    FractionallySizedBox(
                      widthFactor: projectedPct,
                      child: Container(
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.55),
                          borderRadius: const BorderRadius.all(
                            Radius.circular(5),
                          ),
                        ),
                      ),
                    ),
                  FractionallySizedBox(
                    widthFactor: currentPct,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 82,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '$currentRating · P$potentialRating',
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: showGain
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 2),
                            Icon(
                              gain > 0
                                  ? AppIcons.arrow_forward_rounded
                                  : AppIcons.arrow_back_rounded,
                              size: 10,
                              color: gainColor,
                            ),
                            const SizedBox(width: 1),
                            Text(
                              '$projectedRating',
                              style: TextStyle(
                                color: gainColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Target Panel ----------

class FeedTargetPanel extends StatelessWidget {
  final FactionTheme theme;
  final CreatureInstance? targetInstance;
  final Creature? targetCreature;
  final FeedResult? preview;
  final bool shouldAnimate;
  final int? preFeedLevel;
  final int? preFeedXp;

  const FeedTargetPanel({
    super.key,
    required this.theme,
    required this.targetInstance,
    required this.targetCreature,
    required this.preview,
    required this.shouldAnimate,
    this.preFeedLevel,
    this.preFeedXp,
  });

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final t = ForgeTokens(theme);
    final isMaxLevel = targetInstance?.level == 10;
    final constellationEffects = context.watch<ConstellationEffectsService>();

    if (targetInstance == null || targetCreature == null) {
      return const SizedBox.shrink();
    }

    final hasConstellationBoosts =
        constellationEffects.getXpBoostMultiplier() > 1.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: t.bg2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.borderDim),
      ),
      child: isMaxLevel
          ? Row(
              children: [
                Icon(AppIcons.stars, color: fc.amberBright, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Training Complete!\nUse Power Orbs to raise Enhancement ranks.',
                    style: TextStyle(
                      color: fc.amberBright,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            )
          : CurrentStatsDisplay(
              theme: theme,
              instance: targetInstance!,
              creature: targetCreature!,
              preview: preview,
              isAnimating: shouldAnimate,
              preFeedLevel: preFeedLevel,
              preFeedXp: preFeedXp,
              constellationTrailing: hasConstellationBoosts
                  ? _ConstellationInfoButton(
                      theme: theme,
                      effects: constellationEffects,
                    )
                  : null,
            ),
    );
  }
}

class _ConstellationInfoButton extends StatelessWidget {
  final FactionTheme theme;
  final ConstellationEffectsService effects;

  const _ConstellationInfoButton({required this.theme, required this.effects});

  void _showDialog(BuildContext context) {
    HapticFeedback.lightImpact();
    final t = ForgeTokens(theme);
    final xpBoost = effects.getXpBoostMultiplier();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: t.bg2,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: t.borderDim),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(AppIcons.auto_awesome, size: 16, color: theme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Training Bonus',
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          AppIcons.close_rounded,
                          size: 18,
                          color: t.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _BoostRow(
                  theme: theme,
                  entry: _BoostEntry(
                    'XP',
                    xpBoost - 1.0,
                    AppIcons.trending_up_rounded,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _showDialog(context),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.primary.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.primary.withValues(alpha: 0.45),
              width: 1,
            ),
          ),
          child: Icon(AppIcons.auto_awesome, size: 14, color: theme.primary),
        ),
      ),
    );
  }
}

class _BoostEntry {
  final String label;
  final double value;
  final IconData icon;
  const _BoostEntry(this.label, this.value, this.icon);
}

class _BoostRow extends StatelessWidget {
  final FactionTheme theme;
  final _BoostEntry entry;

  const _BoostRow({required this.theme, required this.entry});

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(entry.icon, size: 14, color: theme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            entry.label,
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              letterSpacing: 0.4,
            ),
          ),
        ),
        Text(
          '+${(entry.value * 100).toStringAsFixed(1)}%',
          style: TextStyle(
            color: theme.primary,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

// ---------- Feed Footer ----------

class FeedFooter extends StatelessWidget {
  final FactionTheme theme;
  final CreatureInstance? targetInstance;
  final Creature? targetCreature;
  final FeedResult? preview;
  final bool busy;
  final int selectedCount;
  final VoidCallback onEnhance;
  final bool shouldAnimate;
  final int? preFeedLevel;
  final int? preFeedXp;

  const FeedFooter({
    super.key,
    required this.theme,
    required this.targetInstance,
    required this.targetCreature,
    required this.preview,
    required this.busy,
    required this.selectedCount,
    required this.onEnhance,
    required this.shouldAnimate,
    this.preFeedLevel,
    this.preFeedXp,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);

    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 12 + bottomInset),
      decoration: BoxDecoration(
        color: t.bg1,
        border: Border(top: BorderSide(color: t.borderDim)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EnhanceButton(
            theme: theme,
            enabled:
                selectedCount > 0 && !busy && !(targetInstance?.level == 10),
            busy: busy,
            selectedCount: selectedCount,
            onTap: onEnhance,
          ),
        ],
      ),
    );
  }
}

// ---------- Enhance Button ----------

class EnhanceButton extends StatefulWidget {
  final FactionTheme theme;
  final bool enabled;
  final bool busy;
  final int selectedCount;
  final VoidCallback onTap;

  const EnhanceButton({
    super.key,
    required this.theme,
    required this.enabled,
    required this.busy,
    required this.selectedCount,
    required this.onTap,
  });

  @override
  State<EnhanceButton> createState() => _EnhanceButtonState();
}

class _EnhanceButtonState extends State<EnhanceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final canTap = widget.enabled && !widget.busy;

    return AnimatedBuilder(
      animation: _pressCtrl,
      builder: (context, _) {
        return GestureDetector(
          onTapDown: canTap ? (_) => _pressCtrl.forward() : null,
          onTapUp: canTap ? (_) => _pressCtrl.reverse() : null,
          onTapCancel: canTap ? () => _pressCtrl.reverse() : null,
          onTap: canTap ? widget.onTap : null,
          child: Transform.scale(
            scale: 1.0 - (_pressCtrl.value * 0.05),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: canTap
                    ? LinearGradient(
                        colors: [fc.amberDim, fc.amber],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: canTap ? null : fc.bg2,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: canTap ? fc.amberGlow : fc.borderDim,
                  width: canTap ? 1.5 : 1.0,
                ),
                boxShadow: const [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.busy)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          fc.textPrimary,
                        ),
                      ),
                    )
                  else ...[
                    Icon(
                      AppIcons.bolt_rounded,
                      size: 18,
                      color: canTap ? fc.bg0 : fc.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.selectedCount > 0
                          ? 'ENHANCE (${widget.selectedCount})'
                          : 'SELECT ENHANCEMENTS',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: canTap ? fc.bg0 : fc.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------- Empty States ----------

class NoSpeciesOwnedWrapper extends StatelessWidget {
  const NoSpeciesOwnedWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          "You don't own any creatures yet.",
          style: TextStyle(
            color: t.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class NoResultsFound extends StatelessWidget {
  final FactionTheme theme;
  const NoResultsFound({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            AppIcons.search_off_rounded,
            color: t.textSecondary.withValues(alpha: .3),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'No species found',
            style: TextStyle(
              color: t.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different search term',
            style: TextStyle(
              color: t.textSecondary.withValues(alpha: .7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Species Row ----------

class SpeciesRow extends StatelessWidget {
  final FactionTheme theme;
  final Creature creature;
  final int count;
  final VoidCallback onTap;

  const SpeciesRow({
    super.key,
    required this.theme,
    required this.creature,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final t = ForgeTokens(theme);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: t.bg1,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: t.borderDim),
        ),
        child: Row(
          children: [
            // Left amber accent bar
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: fc.amber,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(3),
                  bottomLeft: Radius.circular(3),
                ),
              ),
            ),
            SizedBox(width: 10),
            CreatureImage(c: creature, discovered: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    creature.name,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: fc.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(height: 3),
                  if (creature.types.isNotEmpty)
                    Row(
                      children: [
                        for (final type in creature.types.take(2)) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: fc.amberDim.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(
                                color: fc.amber.withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              type.toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: fc.amber,
                                fontSize: 7,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          SizedBox(width: 4),
                        ],
                      ],
                    ),
                ],
              ),
            ),
            // Count badge
            Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: fc.amberDim.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: fc.amber.withValues(alpha: 0.45)),
              ),
              child: Text(
                '×$count',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: fc.amberBright,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Icon(AppIcons.chevron_right_rounded, color: fc.textMuted, size: 16),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
