import 'dart:async';

import 'dart:math' as math;

import 'package:alchemons/audio/audio.dart';
import 'package:flutter/services.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/screens/extraction_hub_screen.dart';
import 'package:alchemons/screens/feeding/feeding_screen.dart';
import 'package:alchemons/screens/mystic_altar/mystic_altar_screen.dart';
import 'package:alchemons/screens/profile_screen.dart';
import 'package:alchemons/screens/upgrade_tree/constellation_screen.dart';
import 'package:alchemons/services/onboarding_tasks.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/utils/section_router.dart';
import 'package:alchemons/widgets/achievements/reward_collect_burst.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The list of places the player has not been yet.
///
/// It empties as it is used and then disappears, which is the point: it is a
/// map handed to someone new, not a permanent scoreboard. Anything worth
/// keeping a record of belongs in the achievements above it.
class OnboardingTasksSection extends StatefulWidget {
  const OnboardingTasksSection({super.key});

  @override
  State<OnboardingTasksSection> createState() => _OnboardingTasksSectionState();
}

class _OnboardingTasksSectionState extends State<OnboardingTasksSection> {
  List<(OnboardingTask, TaskState)>? _outstanding;
  bool _claiming = false;

  /// One key per row, so a collected reward can fly from the row the player
  /// actually pressed rather than from the middle of the list.
  final Map<String, GlobalKey> _rowKeys = {};

  GlobalKey _keyFor(String id) =>
      _rowKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'task_$id'));

  /// Read BEFORE the claim: collecting removes the row, and by the time the
  /// list has rebuilt its rect is gone.
  Rect? _rectFor(String id) {
    final ctx = _rowKeys[id]?.currentContext;
    if (ctx == null || !ctx.mounted) return null;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Where the coins land — the wallet's corner, matching the achievements
  /// collected on this same screen.
  Offset get _walletTarget {
    final media = MediaQuery.of(context);
    return Offset(media.size.width - 34, media.padding.top + 26);
  }

  /// The beat an achievement plays when it is collected: a knock, the unlock
  /// cue, and silver crossing the screen to the wallet. A task collected
  /// beside one should not be quieter than it.
  void _playCollect(Rect? from) {
    HapticFeedback.mediumImpact();
    context.sound(SoundCue.achievementUnlock, owner: this);
    if (from == null) return;
    unawaited(
      playRewardCollect(
        context,
        from: from,
        to: _walletTarget,
        gold: 0,
        silver: kTaskSilverReward,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final db = context.read<AlchemonsDatabase>();
    // Read defensively: this section is decoration on someone else's
    // screen, and it must not be able to take the journal down with it if it
    // is ever shown somewhere the shop is not provided. Without it the
    // forge task simply stays hidden.
    ShopService? shop;
    try {
      shop = context.read<ShopService>();
    } on ProviderNotFoundException {
      shop = null;
    }
    final left = await OnboardingTaskService(db).outstanding(shop: shop);
    if (mounted) setState(() => _outstanding = left);
  }

  Future<void> _collect(OnboardingTask task) async {
    if (_claiming) return;
    setState(() => _claiming = true);
    final from = _rectFor(task.id);
    final db = context.read<AlchemonsDatabase>();
    final paid = await OnboardingTaskService(db).claim(task.id);
    if (!mounted) return;
    setState(() => _claiming = false);
    if (paid) _playCollect(from);
    await _refresh();
  }

  Future<void> _collectAll() async {
    if (_claiming) return;
    setState(() => _claiming = true);
    final rows = _outstanding ?? const [];
    // Rects first, all of them: the first claim already invalidates the rest.
    final rects = {
      for (final (task, state) in rows)
        if (state == TaskState.earned) task.id: _rectFor(task.id),
    };
    final db = context.read<AlchemonsDatabase>();
    final service = OnboardingTaskService(db);

    var fired = 0;
    for (final id in rects.keys) {
      if (!await service.claim(id)) continue;
      if (!mounted) return;
      final from = rects[id];
      // Staggered so several rewards read as a sequence rather than one
      // dump — scheduled, never awaited, so the claims are not held up by
      // the animation.
      final delay = Duration(milliseconds: 110 * fired);
      fired++;
      unawaited(
        Future<void>.delayed(delay, () {
          if (!mounted) return;
          _playCollect(from);
        }),
      );
    }

    if (!mounted) return;
    setState(() => _claiming = false);
    if (fired > 0) HapticFeedback.heavyImpact();
    await _refresh();
  }

  /// Sends the player where the task points, then re-reads on the way back —
  /// the arrival marks itself, so the row is gone when they return.
  Future<void> _go(OnboardingTask task) async {
    final section = task.destination.section;
    if (section != null) {
      // A tab lives below this screen, so leave first and then switch.
      Navigator.of(context).popUntil((r) => r.isFirst);
      SectionRouter.instance.go(section);
      return;
    }
    final page = switch (task.destination) {
      TaskDestination.enhance => const FeedingScreen(),
      TaskDestination.harvest => const ExtractionHubScreen(),
      TaskDestination.rite => const MysticAltarScreen(),
      TaskDestination.constellation => const ConstellationScreen(),
      TaskDestination.profile => null,
      _ => null,
    };
    final navigator = Navigator.of(context);
    if (task.destination == TaskDestination.profile) {
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (ctx) => ProfileScreen(() => Navigator.of(ctx).pop()),
          fullscreenDialog: true,
        ),
      );
    } else if (page != null) {
      await navigator.push(
        MaterialPageRoute<void>(builder: (_) => page, fullscreenDialog: true),
      );
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _outstanding;
    // Nothing at all until it is loaded, and nothing ever again once done.
    if (tasks == null || tasks.isEmpty) return const SizedBox.shrink();
    final fc = FC.of(context);
    final readyCount = tasks.where((t) => t.$2 == TaskState.earned).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 26),
        Row(
          children: [
            Text(
              'TASKS',
              style: TextStyle(
                fontFamily: 'monospace',
                color: fc.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              readyCount > 0
                  ? '$readyCount READY'
                  : '${tasks.length} LEFT',
              style: TextStyle(
                color: readyCount > 0 ? fc.mint : fc.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Places you have not been. Each one pays '
          '$kTaskSilverReward silver for showing up.',
          style: TextStyle(color: fc.textMuted, height: 1.5, fontSize: 12),
        ),
        if (readyCount > 1) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: context.soundAction(_claiming ? null : _collectAll),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: fc.mint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: fc.mint.withValues(alpha: 0.6)),
              ),
              child: Text(
                _claiming
                    ? 'COLLECTING…'
                    : 'COLLECT ALL  ·  '
                          '${readyCount * kTaskSilverReward} SILVER',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: fc.mint,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        for (final (task, state) in tasks)
          _TaskRow(
            key: _keyFor(task.id),
            task: task,
            state: state,
            busy: _claiming,
            onGo: () => _go(task),
            onCollect: () => _collect(task),
          ),
      ],
    );
  }
}

/// Matches _AchievementCard beside it: the same forge palette, the same 4px
/// plate, and the same surge when a reward is taken — a task and an
/// achievement are collected on one screen, so collecting should feel like
/// one action, not two.
class _TaskRow extends StatefulWidget {
  const _TaskRow({
    super.key,
    required this.task,
    required this.state,
    required this.busy,
    required this.onGo,
    required this.onCollect,
  });

  final OnboardingTask task;
  final TaskState state;
  final bool busy;
  final VoidCallback onGo;
  final VoidCallback onCollect;

  @override
  State<_TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<_TaskRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _seal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  @override
  void didUpdateWidget(covariant _TaskRow old) {
    super.didUpdateWidget(old);
    // The row is removed from the list the moment it is claimed, so the
    // surge plays on the transition INTO earned — the moment the reward
    // appears, which is the moment worth marking.
    if (widget.state == TaskState.earned && old.state != TaskState.earned) {
      _seal.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _seal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final ready = widget.state == TaskState.earned;
    return AnimatedBuilder(
      animation: _seal,
      builder: (context, child) {
        final t = _seal.value;
        final surge = math.sin(t * math.pi);
        return Transform.scale(
          scale: 1 + 0.035 * Curves.easeOut.transform(surge),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: ready ? Color.lerp(fc.bg2, fc.mint, 0.06) : fc.bg2,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Color.lerp(
                  ready ? fc.mint.withValues(alpha: 0.55) : fc.borderDim,
                  fc.rewardGold,
                  surge * 0.8,
                )!,
                width: 1 + surge * 0.8,
              ),
            ),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
        child: Row(
          children: [
            Icon(
              ready ? AppIcons.check_circle_rounded : widget.task.icon,
              size: 17,
              color: ready ? fc.mint : fc.amberBright,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.task.title,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: fc.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ready
                        ? '$kTaskSilverReward silver waiting.'
                        : widget.task.blurb,
                    style: TextStyle(
                      color: fc.textMuted,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _TaskButton(
              label: ready ? 'Collect' : 'Go',
              icon: ready
                  ? AppIcons.inventory_2_outlined
                  : AppIcons.chevron_right_rounded,
              accent: ready ? fc.mint : fc.amberBright,
              onTap: ready
                  ? (widget.busy ? null : widget.onCollect)
                  : widget.onGo,
            ),
          ],
        ),
      ),
    );
  }
}

/// The journal's own button shape, which lives inside its screen — repeated
/// here rather than exported, because reaching into that file for one
/// private helper would drag the whole screen along with it.
class _TaskButton extends StatelessWidget {
  const _TaskButton({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final enabled = onTap != null;
    return GestureDetector(
      onTap: context.soundAction(onTap),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: enabled ? 0.12 : 0.05),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: accent.withValues(alpha: enabled ? 0.6 : 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'monospace',
                color: enabled ? accent : fc.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 4),
            Icon(icon, size: 13, color: enabled ? accent : fc.textMuted),
          ],
        ),
      ),
    );
  }
}
