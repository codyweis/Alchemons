import 'dart:async';

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/screens/extraction_hub_screen.dart';
import 'package:alchemons/screens/feeding/feeding_screen.dart';
import 'package:alchemons/screens/mystic_altar/mystic_altar_screen.dart';
import 'package:alchemons/screens/profile_screen.dart';
import 'package:alchemons/screens/upgrade_tree/constellation_screen.dart';
import 'package:alchemons/services/onboarding_tasks.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/section_router.dart';
import 'package:alchemons/widgets/game_snack.dart';
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

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final db = context.read<AlchemonsDatabase>();
    final left = await OnboardingTaskService(db).outstanding();
    if (mounted) setState(() => _outstanding = left);
  }

  Future<void> _collect(OnboardingTask task) async {
    if (_claiming) return;
    setState(() => _claiming = true);
    final db = context.read<AlchemonsDatabase>();
    final paid = await OnboardingTaskService(db).claim(task.id);
    if (!mounted) return;
    setState(() => _claiming = false);
    if (paid) {
      showGameSnack(
        context,
        '+$kTaskSilverReward silver',
        icon: AppIcons.check_circle_rounded,
      );
    }
    await _refresh();
  }

  Future<void> _collectAll() async {
    if (_claiming) return;
    setState(() => _claiming = true);
    final db = context.read<AlchemonsDatabase>();
    final paid = await OnboardingTaskService(db).claimAll();
    if (!mounted) return;
    setState(() => _claiming = false);
    if (paid > 0) {
      showGameSnack(
        context,
        '+${paid * kTaskSilverReward} silver',
        icon: AppIcons.check_circle_rounded,
      );
    }
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
    final theme = context.watch<FactionTheme>();
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
                color: theme.text,
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
                color: readyCount > 0 ? theme.accent : theme.textMuted,
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
          style: TextStyle(
            color: theme.textMuted,
            height: 1.5,
            fontSize: 12,
          ),
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
                color: theme.accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: theme.accent.withValues(alpha: 0.6)),
              ),
              child: Text(
                _claiming
                    ? 'COLLECTING…'
                    : 'COLLECT ALL  ·  '
                          '${readyCount * kTaskSilverReward} SILVER',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.accent,
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

class _TaskRow extends StatelessWidget {
  const _TaskRow({
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
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    final ready = state == TaskState.earned;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: ready
              ? theme.accent.withValues(alpha: 0.75)
              : theme.border.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        children: [
          Icon(
            ready ? AppIcons.check_circle_rounded : task.icon,
            size: 17,
            color: theme.accent,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ready
                      ? 'Visited — $kTaskSilverReward silver waiting.'
                      : task.blurb,
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: context.soundAction(
              ready ? (busy ? null : onCollect) : onGo,
            ),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: theme.accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: theme.accent.withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ready ? 'COLLECT' : 'GO',
                    style: TextStyle(
                      color: theme.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  if (!ready) ...[
                    const SizedBox(width: 3),
                    Icon(
                      AppIcons.chevron_right_rounded,
                      size: 14,
                      color: theme.accent,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
