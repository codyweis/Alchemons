import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/creature_instance_service.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/providers/app_providers.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/show_quick_instance_dialog.dart';
import 'package:alchemons/widgets/creature_image.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
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

  @override
  Widget build(BuildContext context) {
    final canGoBack = stage != 'species';
    final (title, subtitle) = _getStageText();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(bottom: BorderSide(color: theme.border)),
      ),
      child: Row(
        children: [
          if (canGoBack)
            GestureDetector(
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.border),
                ),
                child: Icon(Icons.arrow_back, color: theme.text, size: 18),
              ),
            ),
          if (canGoBack) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: theme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (stage == 'species' && onOpenAllInstances != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onOpenAllInstances,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.border),
                ),
                child: const Icon(Icons.grid_view_rounded, size: 18),
              ),
            ),
          ],
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
          'Select Fodder',
          selectedCount > 0
              ? '$selectedCount selected'
              : 'Choose specimens to feed',
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
                    color: widget.theme.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (currentLevel < 10) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: widget.theme.surface,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: widget.theme.border,
                          width: 0.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2.5),
                        child: Stack(
                          children: [
                            FractionallySizedBox(
                              widthFactor: displayXpPercent.clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.shade400,
                                      Colors.blue.shade600,
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
                  const SizedBox(width: 6),
                  Text(
                    '$displayXp/$xpNeeded',
                    style: TextStyle(
                      color: widget.theme.textMuted,
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
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'MAX',
                        style: TextStyle(
                          color: Colors.amber,
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
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          GestureDetector(
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
                    color: theme.text,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
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
    final percentage = (value / 5.0).clamp(0.0, 1.0);
    final potentialPercentage = (potential / 5.0).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.textMuted,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 60,
            height: 8,
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: potentialPercentage,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: percentage,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value.toStringAsFixed(1),
            style: TextStyle(
              color: theme.text,
              fontSize: 8,
              fontWeight: FontWeight.w700,
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
    final gains = preview.statGains ?? {};

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: Colors.green, size: 14),
              const SizedBox(width: 4),
              Text(
                'Predicted Changes',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
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
                Icon(Icons.star, color: Colors.amber, size: 12),
                const SizedBox(width: 4),
                Text(
                  'Level ${instance.level} → ${preview.newLevel}',
                  style: TextStyle(
                    color: Colors.amber,
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
    final newValue = (current + gain).clamp(0.0, potential);
    final color = gain > 0
        ? Colors.green
        : (gain < 0 ? Colors.red : theme.textMuted);
    final arrow = gain > 0 ? '↑' : (gain < 0 ? '↓' : '•');

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.textMuted,
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
            color: theme.text,
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
    final isMaxLevel = targetInstance?.level == 10;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(top: BorderSide(color: theme.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (targetInstance != null && targetCreature != null) ...[
            if (isMaxLevel)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.stars, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Max Level Reached!\nThis creature can no longer be enhanced.',
                        style: TextStyle(
                          color: Colors.amber,
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
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: canTap ? Colors.green.shade600 : widget.theme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: canTap
                      ? Colors.green.shade400
                      : widget.theme.border.withOpacity(.8),
                  width: 1.5,
                ),
                boxShadow: canTap
                    ? [
                        BoxShadow(
                          color: Colors.green.shade400.withOpacity(.4),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.busy)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    Text(
                      widget.busy
                          ? 'Processing...'
                          : 'Begin Enhancement${widget.selectedCount > 0 ? ' (${widget.selectedCount})' : ''}',
                      style: TextStyle(
                        color: widget.theme.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
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
    final theme = context.watch<FactionTheme>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          "You don't own any creatures yet.",
          style: TextStyle(
            color: theme.textMuted,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            color: theme.textMuted.withOpacity(.3),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'No species found',
            style: TextStyle(
              color: theme.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different search term',
            style: TextStyle(
              color: theme.textMuted.withOpacity(.7),
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 75,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: theme.border),
        ),
        child: Row(
          children: [
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
                      color: theme.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    creature.types.join(', '),
                    style: TextStyle(
                      color: theme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                color: theme.primary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
