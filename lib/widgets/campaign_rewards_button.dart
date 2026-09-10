import 'package:alchemons/services/onboarding_tasks.dart';
import 'package:alchemons/audio/audio.dart';
import 'dart:async';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/screens/story/campaign_journal_screen.dart';
import 'package:alchemons/services/campaign_journal_service.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:provider/provider.dart';

/// Event-driven notifications: database changes, route return, and app resume.
/// No polling, background service, or system notification permission required.
/// How the campaign entry point presents itself.
enum CampaignRewardsStyle {
  /// A badged icon, for a crowded toolbar.
  icon,

  /// A full-width list row, for a settings-style list.
  tile,

  /// A slab across the top of a screen: name, progress, and what is waiting.
  bar,
}

class CampaignRewardsButton extends StatefulWidget {
  const CampaignRewardsButton({
    super.key,
    this.color,
    this.enabled = true,
    this.style = CampaignRewardsStyle.icon,
  });
  final Color? color;
  final bool enabled;
  final CampaignRewardsStyle style;
  @override
  State<CampaignRewardsButton> createState() => _CampaignRewardsButtonState();
}

class _CampaignRewardsButtonState extends State<CampaignRewardsButton>
    with RouteAware, WidgetsBindingObserver {
  StreamSubscription<dynamic>? _changes;
  Timer? _debounce;
  ModalRoute<void>? _route;
  CampaignSnapshot? _snapshot;
  bool _loading = false;
  bool _reload = false;
  static final Set<String> _announced = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final db = context.read<AlchemonsDatabase>();
    _changes = db
        .customSelect('SELECT 1', readsFrom: {db.settings, db.playerCreatures})
        .watch()
        .listen((_) => scheduleRefresh());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_route != route) {
      routeObserver.unsubscribe(this);
      _route = route;
      if (route != null) routeObserver.subscribe(this, route);
    }
  }

  void scheduleRefresh() {
    _debounce?.cancel();
    if (_route?.isCurrent == false) return;
    _debounce = Timer(const Duration(milliseconds: 180), refresh);
  }

  @override
  void didPopNext() => scheduleRefresh();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) scheduleRefresh();
  }

  /// Uncollected task rewards, counted alongside the achievement ones.
  int _tasksReady = 0;

  Future<void> refresh() async {
    if (!mounted || _route?.isCurrent == false) return;
    if (_loading) {
      _reload = true;
      return;
    }
    _loading = true;
    try {
      final next = await CampaignJournalService(
        context.read<AlchemonsDatabase>(),
      ).load();
      if (!mounted) return;
      // Tasks are collected on this same screen, so the badge has to count
      // them too — otherwise the reward the player was told to come back for
      // is the one thing the button does not mention.
      final tasksReady = await OnboardingTaskService(
        context.read<AlchemonsDatabase>(),
      ).readyCount();
      if (!mounted) return;
      final previous = _snapshot;
      setState(() {
        _snapshot = next;
        _tasksReady = tasksReady;
      });
      if (widget.enabled && (_route?.isCurrent ?? false)) {
        final fresh = next.ready
            .where((a) => !_announced.contains(a.id))
            .toList();
        _announced.addAll(next.ready.map((a) => a.id));
        if (previous != null && fresh.isNotEmpty) {
          final count = next.ready.length;
          showGameSnack(
            context,
            '$count achievement ${count == 1 ? 'reward' : 'rewards'} ready',
            icon: AppIcons.emoji_events_outlined,
            accent: FC.of(context).rewardGold,
            action: SnackBarAction(label: 'VIEW', onPressed: open),
          );
        }
      }
    } catch (_) {
      // Keep the entry usable if a progress read fails; the screen offers retry.
    } finally {
      _loading = false;
      if (_reload && mounted) {
        _reload = false;
        scheduleRefresh();
      }
    }
  }

  Future<void> open() async {
    if (!widget.enabled) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CampaignJournalScreen()),
    );
    if (mounted) await refresh();
  }

  @override
  void dispose() {
    _changes?.cancel();
    _debounce?.cancel();
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The slab: what you have finished, what is waiting, and a way in.
  ///
  /// Built to be read at a glance from the top of the home screen — the count
  /// tells you where you are, the track shows it without needing the numbers,
  /// and the whole thing changes colour when something is actually claimable
  /// so it reads as a call to action rather than another stat.
  Widget _bar(BuildContext context, int ready) {
    final fc = FC.of(context);
    final snapshot = _snapshot;
    final total = campaignAchievements.length;
    final done = snapshot?.claimed.length ?? 0;
    final hasReady = ready > 0;
    final accent = hasReady ? fc.mint : fc.amberBright;

    return LayoutBuilder(
      builder: (context, c) {
        // In the home toolbar this sits between the avatar and the wallet,
        // which leaves it around 200px. The word ACHIEVEMENTS and the count
        // together do not fit there, and the trophy already says what this is
        // — so the narrow form keeps the number and drops the prose.
        final roomy = c.maxWidth >= 235;
        return Semantics(
          button: true,
          label: hasReady
              ? 'Achievements, $ready rewards ready'
              : 'Achievements, $done of $total collected',
          child: GestureDetector(
            onTap: context.soundAction(widget.enabled ? open : null),
            behavior: HitTestBehavior.opaque,
            child: Opacity(
              opacity: widget.enabled ? 1 : 0.4,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                padding: EdgeInsets.fromLTRB(0, 9, roomy ? 12 : 10, 9),
                decoration: BoxDecoration(
                  color: fc.bg2,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: hasReady
                        ? accent.withValues(alpha: 0.65)
                        : fc.borderDim,
                  ),
                ),
                child: Row(
                  children: [
                    // The 3px rule the rest of the app uses to head a panel.
                    Container(width: 3, height: 34, color: accent),
                    const SizedBox(width: 10),
                    Icon(
                      AppIcons.emoji_events_outlined,
                      size: 18,
                      color: accent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              if (roomy)
                                Flexible(
                                  child: Text(
                                    'ACHIEVEMENTS',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      color: fc.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.8,
                                    ),
                                  ),
                                ),
                              if (roomy) const Spacer(),
                              Text(
                                hasReady ? '$ready READY' : '$done / $total',
                                maxLines: 1,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: hasReady ? accent : fc.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Collected against the whole set. A claimable reward
                          // does not move this — you have to go and take it.
                          LayoutBuilder(
                            builder: (context, c) => Stack(
                              children: [
                                Container(
                                  height: 3,
                                  width: double.infinity,
                                  color: fc.borderDim,
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 420),
                                  curve: Curves.easeOutCubic,
                                  height: 3,
                                  width:
                                      c.maxWidth *
                                      (total == 0 ? 0.0 : done / total),
                                  color: accent,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (roomy) ...[
                      const SizedBox(width: 8),
                      Icon(
                        AppIcons.chevron_right_rounded,
                        size: 16,
                        color: fc.textMuted,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final count = (_snapshot?.ready.length ?? 0) + _tasksReady;
    final badgeColor = fc.rewardGold;
    final icon = Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      backgroundColor: badgeColor,
      textColor: fc.onColor(badgeColor),
      child: Icon(Icons.emoji_events_outlined, color: widget.color),
    );
    if (widget.style == CampaignRewardsStyle.bar) {
      return _bar(context, count);
    }

    if (widget.style == CampaignRewardsStyle.tile) {
      return ListTile(
        leading: icon,
        title: const Text('ACHIEVEMENTS'),
        subtitle: Text(
          count > 0
              ? '$count rewards ready to collect'
              : 'Main story, rewards, and memories',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: widget.enabled ? open : null,
      );
    }
    return IconButton(
      tooltip: count > 0
          ? 'Achievements · $count rewards ready'
          : 'Achievements',
      onPressed: context.soundAction(widget.enabled ? open : null),
      icon: icon,
    );
  }
}
