import 'dart:async';

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
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/coin_icon.dart';
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
      await navigator.push(ProfileScreen.route());
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
    final palette = BracketPalette.of(context);
    final readyCount = tasks.where((t) => t.$2 == TaskState.earned).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The journal's shelf head: a bar, spaced capitals, a hairline.
        Padding(
          padding: const EdgeInsets.only(top: 28, bottom: 8),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 16,
                color: fc.amberBright,
                margin: const EdgeInsets.only(right: 10),
              ),
              Text(
                'TASKS',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: fc.amberBright,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 1,
                  color: fc.amberBright.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                readyCount > 0 ? '$readyCount READY' : '${tasks.length} LEFT',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: readyCount > 0 ? fc.rewardGold : palette.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
        Text(
          'Places you have not been. Each one pays '
          '$kTaskSilverReward silver for showing up.',
          style: bracketText(
            context,
            12.5,
            palette.muted,
          ).copyWith(height: 1.35),
        ),
        if (readyCount > 1) ...[
          const SizedBox(height: 12),
          BracketButton(
            label: _claiming ? 'COLLECTING…' : 'COLLECT ALL',
            onTap: _collectAll,
            enabled: !_claiming,
            palette: palette,
            accent: fc.rewardGold,
            height: 42,
            trailing: CoinAmount(
              kind: CoinKind.silver,
              amount: readyCount * kTaskSilverReward,
              size: 11.5,
            ),
          ),
        ],
        const SizedBox(height: 4),
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

/// A place not visited yet: its name, what is there, and GO. Once the player
/// has been, the row is lit from below in gold and the button becomes
/// COLLECT — the same light a ready achievement wears beside it, easing on
/// rather than popping.
class _TaskRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final palette = BracketPalette.of(context);
    final ready = state == TaskState.earned;
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: bracketText(
                    context,
                    15,
                    palette.ink,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  ready ? '$kTaskSilverReward silver waiting.' : task.blurb,
                  style: bracketText(
                    context,
                    12,
                    palette.muted,
                  ).copyWith(height: 1.25),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // At least as wide as GO, and as wide as its label beyond that, so
          // COLLECT is never cut short at a large text size.
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 62),
            child: ready
                ? BracketButton(
                    label: 'COLLECT',
                    onTap: onCollect,
                    enabled: !busy,
                    palette: palette,
                    accent: fc.rewardGold,
                    height: 34,
                  )
                // A quiet button on a bg0 well: the kit's quiet fill alone
                // vanishes on the page.
                : Container(
                    color: palette.bg0,
                    child: BracketButton(
                      label: 'GO',
                      onTap: onGo,
                      palette: palette,
                      accent: fc.amber,
                      primary: false,
                      height: 34,
                    ),
                  ),
          ),
        ],
      ),
    );
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(end: ready ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 620),
          curve: Curves.easeOutCubic,
          builder: (context, lit, child) => CustomPaint(
            foregroundPainter: BracketFramePainter(
              color: fc.rewardGold.withValues(alpha: 0.8 * lit),
              strokeWidth: 1.2,
            ),
            child: Container(
              color: palette.accentWash(fc.rewardGold, darkAlpha: 0.06 * lit),
              child: child,
            ),
          ),
          child: row,
        ),
        Container(height: 1, color: palette.lineSoft),
      ],
    );
  }
}
