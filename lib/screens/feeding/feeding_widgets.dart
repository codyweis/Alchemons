import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_instance_service.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/show_quick_instance_dialog.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:alchemons/widgets/creature_image.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fast_long_press_detector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
                        Icons.arrow_back,
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
                            fontSize: 11,
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
                        Icons.grid_view_rounded,
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
                                  Icons.check,
                                  size: 10,
                                  color: fc.amberBright,
                                )
                              : Text(
                                  '${idx + 1}',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: isActive ? fc.bg0 : t.textMuted,
                                    fontSize: 8,
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
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _xpAnimation;
  late Animation<int> _levelAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _setupAnimations();
  }

  void _setupAnimations() {
    final startLevel = widget.preFeedLevel ?? widget.instance.level;
    final endLevel = widget.instance.level;
    final startXp = widget.preFeedXp ?? widget.instance.xp;
    final endXp = widget.instance.xp;

    _levelAnimation = IntTween(begin: startLevel, end: endLevel).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    if (startLevel == endLevel) {
      final xpNeeded = CreatureInstanceServiceFeeding.xpNeededForLevel(
        startLevel,
      );
      final startPercent = startXp / xpNeeded;
      final endPercent = endXp / xpNeeded;

      _xpAnimation = Tween<double>(begin: startPercent, end: endPercent)
          .animate(
            CurvedAnimation(
              parent: _animController,
              curve: Curves.easeOutCubic,
            ),
          );
    } else {
      _xpAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
      );
    }
  }

  @override
  void didUpdateWidget(XPBarDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isAnimating && !oldWidget.isAnimating) {
      _setupAnimations();
      _animController.forward(from: 0.0);
    } else if (!widget.isAnimating && oldWidget.isAnimating) {
      _animController.reset();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final t = ForgeTokens(widget.theme);
    final currentLevel = widget.instance.level;
    final currentXp = widget.instance.xp;
    final xpNeeded = CreatureInstanceServiceFeeding.xpNeededForLevel(
      currentLevel,
    );

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final displayLevel = widget.isAnimating
            ? _levelAnimation.value
            : currentLevel;

        final displayXpPercent = widget.isAnimating
            ? _xpAnimation.value
            : (currentXp / xpNeeded).clamp(0.0, 1.0);

        final displayXp = widget.isAnimating
            ? (displayXpPercent * xpNeeded).round()
            : currentXp;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Level $displayLevel',
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (currentLevel < 10) ...[
                  SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 11,
                      decoration: BoxDecoration(
                        color: fc.bg0,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: fc.borderDim, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: fc.amberDim.withValues(alpha: 0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(
                          children: [
                            FractionallySizedBox(
                              widthFactor: displayXpPercent.clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      fc.amberDim,
                                      fc.amber,
                                      fc.amberGlow,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    '$displayXp/$xpNeeded',
                    style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (currentLevel >= 10)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: fc.amberBright.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: fc.amber.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'MAX',
                        style: TextStyle(
                          color: fc.amberBright,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ---------- Current Stats Display ----------

class CurrentStatsDisplay extends StatelessWidget {
  final FactionTheme theme;
  final CreatureInstance instance;
  final Creature creature;
  final bool isAnimating;
  final int? preFeedLevel;
  final int? preFeedXp;

  const CurrentStatsDisplay({
    super.key,
    required this.theme,
    required this.instance,
    required this.creature,
    this.isAnimating = false,
    this.preFeedLevel,
    this.preFeedXp,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: t.bg2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: t.borderDim),
      ),
      child: Row(
        children: [
          FastLongPressDetector(
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
              size: 50,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  creature.name,
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                XPBarDisplay(
                  theme: theme,
                  instance: instance,
                  isAnimating: isAnimating,
                  preFeedLevel: preFeedLevel,
                  preFeedXp: preFeedXp,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 128,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                StatMiniBar(
                  label: 'SPD',
                  value: instance.statSpeed,
                  potential: instance.statSpeedPotential,
                  theme: theme,
                ),
                StatMiniBar(
                  label: 'INT',
                  value: instance.statIntelligence,
                  potential: instance.statIntelligencePotential,
                  theme: theme,
                ),
                StatMiniBar(
                  label: 'STR',
                  value: instance.statStrength,
                  potential: instance.statStrengthPotential,
                  theme: theme,
                ),
                StatMiniBar(
                  label: 'BEA',
                  value: instance.statBeauty,
                  potential: instance.statBeautyPotential,
                  theme: theme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Stat Mini Bar ----------

class StatMiniBar extends StatelessWidget {
  final String label;
  final double value;
  final double potential;
  final FactionTheme theme;

  const StatMiniBar({
    super.key,
    required this.label,
    required this.value,
    required this.potential,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    final percentage = (value / 5.0).clamp(0.0, 1.0);
    final potentialPercentage = (potential / 5.0).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          SizedBox(
            width: 24,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: t.bg1,
                borderRadius: const BorderRadius.all(Radius.circular(4)),
              ),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: potentialPercentage,
                    child: Container(
                      decoration: BoxDecoration(
                        color: t.borderMid,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: percentage,
                    child: Container(
                      decoration: BoxDecoration(
                        color: t.amber,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(4),
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
            width: 28,
            child: Text(
              value.toStringAsFixed(1),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Stat Gains Preview ----------

class StatGainsPreview extends StatelessWidget {
  final FactionTheme theme;
  final FeedResult preview;
  final CreatureInstance instance;

  const StatGainsPreview({
    super.key,
    required this.theme,
    required this.preview,
    required this.instance,
  });

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final gains = preview.statGains ?? {};

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: fc.amberDim.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fc.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_rounded, color: fc.amber, size: 12),
              SizedBox(width: 5),
              Text(
                'POWER ANALYSIS',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: fc.amberBright,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              StatGainIndicator(
                label: 'SPD',
                gain: gains['speed'] ?? 0,
                current: instance.statSpeed,
                potential: instance.statSpeedPotential,
                theme: theme,
              ),
              StatGainIndicator(
                label: 'INT',
                gain: gains['intelligence'] ?? 0,
                current: instance.statIntelligence,
                potential: instance.statIntelligencePotential,
                theme: theme,
              ),
              StatGainIndicator(
                label: 'STR',
                gain: gains['strength'] ?? 0,
                current: instance.statStrength,
                potential: instance.statStrengthPotential,
                theme: theme,
              ),
              StatGainIndicator(
                label: 'BEA',
                gain: gains['beauty'] ?? 0,
                current: instance.statBeauty,
                potential: instance.statBeautyPotential,
                theme: theme,
              ),
            ],
          ),
          if (preview.newLevel > instance.level) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.star, color: fc.amberBright, size: 12),
                const SizedBox(width: 4),
                Text(
                  'Level ${instance.level} → ${preview.newLevel}',
                  style: TextStyle(
                    color: fc.amberBright,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class StatGainIndicator extends StatelessWidget {
  final String label;
  final double gain;
  final double current;
  final double potential;
  final FactionTheme theme;

  const StatGainIndicator({
    super.key,
    required this.label,
    required this.gain,
    required this.current,
    required this.potential,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final t = ForgeTokens(theme);
    final newValue = (current + gain).clamp(0.0, potential);
    final color = gain > 0
        ? fc.amberBright
        : (gain < 0 ? fc.danger : t.textSecondary);
    final arrow = gain > 0 ? '↑' : (gain < 0 ? '↓' : '•');

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: t.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          '$arrow${gain.abs().toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          '→ ${newValue.toStringAsFixed(1)}',
          style: TextStyle(
            color: t.textPrimary,
            fontSize: 9,
            fontWeight: FontWeight.w600,
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
    final fc = FC.of(context);
    final t = ForgeTokens(theme);
    final isMaxLevel = targetInstance?.level == 10;
    final constellationEffects = context.watch<ConstellationEffectsService>();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.bg1,
        border: Border(top: BorderSide(color: t.borderDim)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // SPECIMEN LOADED status badge
          if (targetInstance != null) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: fc.amberDim.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: fc.amber.withValues(alpha: 0.45)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: fc.amberGlow,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        'SPECIMEN LOADED',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: fc.amberBright,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
          ],
          if (targetInstance != null && targetCreature != null) ...[
            if (isMaxLevel)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: fc.amberBright.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: fc.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.stars, color: fc.amberBright, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Max Level Reached!\nThis creature can no longer be enhanced.',
                        style: TextStyle(
                          color: fc.amberBright,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              CurrentStatsDisplay(
                theme: theme,
                instance: targetInstance!,
                creature: targetCreature!,
                isAnimating: shouldAnimate,
                preFeedLevel: preFeedLevel,
                preFeedXp: preFeedXp,
              ),
              if (preview != null && preview!.ok) ...[
                const SizedBox(height: 8),
                StatGainsPreview(
                  theme: theme,
                  preview: preview!,
                  instance: targetInstance!,
                ),
              ],
            ],
            const SizedBox(height: 12),
            _buildConstellationBonuses(theme, constellationEffects),
          ],
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

Widget _buildConstellationBonuses(
  FactionTheme theme,
  ConstellationEffectsService effects,
) {
  final strengthBoost = effects.getStatBoostMultiplier('strength');
  final intBoost = effects.getStatBoostMultiplier('intelligence');
  final beautyBoost = effects.getStatBoostMultiplier('beauty');
  final speedBoost = effects.getStatBoostMultiplier('speed');

  final hasAnyBoost =
      strengthBoost > 0 || intBoost > 0 || beautyBoost > 0 || speedBoost > 0;

  if (!hasAnyBoost) return const SizedBox.shrink();

  return Container(
    margin: const EdgeInsets.only(top: 8, bottom: 4),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: theme.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: theme.primary.withValues(alpha: 0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Constellation Bonuses',
          style: TextStyle(
            color: theme.primary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        if (strengthBoost > 0) _buildBonusPill('STR', strengthBoost, theme),
        if (intBoost > 0) _buildBonusPill('INT', intBoost, theme),
        if (beautyBoost > 0) _buildBonusPill('BEA', beautyBoost, theme),
        if (speedBoost > 0) _buildBonusPill('SPD', speedBoost, theme),
      ],
    ),
  );
}

Widget _buildBonusPill(String label, double bonus, FactionTheme theme) {
  final fc = FC(theme);
  return Container(
    margin: const EdgeInsets.only(left: 4),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: fc.amber.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      '$label +${(bonus * 100).toStringAsFixed(1)}%',
      style: TextStyle(
        color: fc.amber,
        fontSize: 9,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
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
                boxShadow: canTap
                    ? [
                        BoxShadow(
                          color: fc.amber.withValues(alpha: 0.45),
                          blurRadius: 18,
                          spreadRadius: 1,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
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
                      Icons.bolt_rounded,
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
            Icons.search_off_rounded,
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
            Icon(Icons.chevron_right_rounded, color: fc.textMuted, size: 16),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
