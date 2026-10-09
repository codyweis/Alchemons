import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/services/onboarding_tasks.dart';
import 'package:alchemons/audio/audio.dart';
import 'dart:async';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/achievements/achievement_sphere.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/screens/story/campaign_journal_screen.dart';
import 'package:alchemons/services/campaign_journal_service.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart';
import 'package:alchemons/data/mystic_altar_data.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter/foundation.dart' show listEquals;
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
    this.docked = false,
  });
  final Color? color;
  final bool enabled;
  final CampaignRewardsStyle style;

  /// Bar style only: shrink to a small tab (trophy and badge) so the bar can
  /// be parked against a screen edge. State is kept, so the count stays live.
  final bool docked;
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

  /// Everything still sitting in the tasks list — places not yet visited as
  /// well as rewards not yet taken.
  ///
  /// Both belong on the badge: a task the player has not done is the whole
  /// reason the list exists, and a list nobody is told about is a list
  /// nobody opens. It empties itself as they are done, so the badge is not
  /// permanent furniture.
  int _tasksOutstanding = 0;

  /// Of those, the ones visited with their silver still to collect: a reward
  /// actually waiting, unlike a place not yet been to.
  int _tasksEarned = 0;

  /// What [refresh] last loaded from. A database write that leaves this
  /// unchanged cannot change the snapshot or the task count, so it is answered
  /// with one small query instead of a full journal load.
  List<Object?>? _loadedFrom;

  /// Everything the task count reads that the journal signature does not:
  /// the task flags, the relic gate (held or placed) and the forge gate.
  Future<List<Object?>> _taskSignature(
    AlchemonsDatabase db,
    ShopService? shop,
  ) async {
    final relicKeys = [
      for (final e in kAltarEntries) BossLootKeys.traitKeyForElement(e.element),
    ];
    final row = await db
        .customSelect(
          'SELECT '
          '(SELECT group_concat(kv, char(31)) FROM ('
          "SELECT key || '=' || value AS kv FROM settings "
          "WHERE key GLOB 'task_*' OR key GLOB 'altar_relic_placed_*' "
          'ORDER BY key)) AS s, '
          '(SELECT COUNT(*) FROM inventory_items WHERE qty > 0 AND key IN '
          '(${List.filled(relicKeys.length, '?').join(',')})) AS r',
          variables: [for (final k in relicKeys) Variable.withString(k)],
        )
        .getSingle();
    return [row.data['s'], row.data['r'], shop?.hasElementalCreatorUnlocked()];
  }

  Future<void> refresh() async {
    if (!mounted || _route?.isCurrent == false) return;
    if (_loading) {
      _reload = true;
      return;
    }
    _loading = true;
    try {
      final db = context.read<AlchemonsDatabase>();
      // Read defensively: this button sits on screens that may not provide
      // the shop, and the forge task's gate asks it whether the Elemental
      // Creator is owned. Without it that one task simply is not counted.
      ShopService? shop;
      try {
        shop = context.read<ShopService>();
      } on ProviderNotFoundException {
        shop = null;
      }
      final journal = CampaignJournalService(db);
      final signature = [
        ...await journal.inputsSignature(),
        ...await _taskSignature(db, shop),
      ];
      if (!mounted) return;
      // Nothing the badge reads has moved, so a load would return what is
      // already on screen. The one exception is a ready reward this screen
      // has not announced yet (the button was disabled, or off-route, when
      // it became ready): that still goes through the load below so the
      // snack fires exactly when it always did.
      final current = _snapshot;
      if (current != null &&
          listEquals(signature, _loadedFrom) &&
          (!widget.enabled ||
              current.ready.every((a) => _announced.contains(a.id)))) {
        return;
      }
      final next = await journal.load();
      if (!mounted) return;
      // Tasks are collected on this same screen, so the badge has to count
      // them too — otherwise the reward the player was told to come back for
      // is the one thing the button does not mention.
      final tasks = await OnboardingTaskService(db).outstanding(shop: shop);
      if (!mounted) return;
      _loadedFrom = signature;
      final previous = _snapshot;
      setState(() {
        _snapshot = next;
        _tasksOutstanding = tasks.length;
        _tasksEarned = tasks.where((t) => t.$2 == TaskState.earned).length;
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
    await Navigator.of(context).push(CampaignJournalScreen.route());
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
  /// Built to be read at a glance from the home screen. Its sphere is the
  /// whole set as the achievements screen draws each one: forming as more is
  /// collected, gold rising inside while something waits. The count says the
  /// same in figures, and the slab is lit from below when there is something
  /// to collect, so it reads as a call to action rather than another stat.
  ///
  /// Only a reward actually waiting lights it. Places not yet visited are
  /// counted too, because a list nobody is told about is a list nobody opens,
  /// but as tasks rather than as READY: nothing is there to collect yet.
  Widget _bar(BuildContext context) {
    final fc = FC.of(context);
    final palette = BracketPalette.of(context);
    final snapshot = _snapshot;
    final total = campaignAchievements.length;
    final done = snapshot?.claimed.length ?? 0;
    final ready = (snapshot?.ready.length ?? 0) + _tasksEarned;
    final unvisited = _tasksOutstanding - _tasksEarned;
    final hasReady = ready > 0;
    final label = hasReady
        ? 'Achievements, $ready rewards ready'
        : unvisited > 0
        ? 'Achievements, $unvisited tasks to do'
        : 'Achievements, $done of $total collected';

    Widget sphere(double size) => RepaintBoundary(
      child: AchievementSphere(
        size: size,
        tone: fc.amberBright,
        state: hasReady
            ? AchievementSphereState.ready
            : done >= total
            ? AchievementSphereState.sealed
            : AchievementSphereState.underway,
        progress: total == 0 ? 0 : done / total,
        seed: 7,
        gold: fc.rewardGold,
        // Still on the home screen unless something is waiting there.
        animate: hasReady,
      ),
    );

    Widget slab({required Widget child, required EdgeInsets padding}) =>
        CustomPaint(
          foregroundPainter: BracketFramePainter(
            color: hasReady
                ? fc.rewardGold.withValues(alpha: 0.8)
                : palette.line,
            strokeWidth: 1.2,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            padding: padding,
            color: hasReady
                ? Color.alphaBlend(
                    palette.accentWash(fc.rewardGold, darkAlpha: 0.08),
                    palette.chromeFill(),
                  )
                : palette.chromeFill(),
            child: child,
          ),
        );

    if (widget.docked) {
      return Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: context.soundAction(widget.enabled ? open : null),
          behavior: HitTestBehavior.opaque,
          child: Opacity(
            opacity: widget.enabled ? 1 : 0.4,
            child: slab(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  sphere(40),
                  if (hasReady || unvisited > 0)
                    Text(
                      '${hasReady ? ready : unvisited}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: hasReady ? fc.rewardGold : palette.ink,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        // On a narrow phone the word ACHIEVEMENTS and the count together do
        // not fit beside the sphere, and the sphere already says what this
        // is — so the narrow form keeps the number and drops the prose.
        final roomy = c.maxWidth >= 235;
        return Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            onTap: context.soundAction(widget.enabled ? open : null),
            behavior: HitTestBehavior.opaque,
            child: Opacity(
              opacity: widget.enabled ? 1 : 0.4,
              child: slab(
                padding: EdgeInsets.fromLTRB(4, 4, roomy ? 10 : 8, 4),
                child: Row(
                  children: [
                    sphere(42),
                    const SizedBox(width: 6),
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
                                      color: palette.ink,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.8,
                                    ),
                                  ),
                                ),
                              if (roomy) const Spacer(),
                              Text(
                                hasReady
                                    ? '$ready READY'
                                    : unvisited > 0
                                    ? '$unvisited TASKS'
                                    : '$done / $total',
                                maxLines: 1,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: hasReady
                                      ? fc.rewardGold
                                      : unvisited > 0
                                      ? palette.ink
                                      : palette.muted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          // Collected against the whole set. A claimable reward
                          // does not move this — you have to go and take it.
                          LayoutBuilder(
                            builder: (context, c) => Stack(
                              children: [
                                Container(
                                  height: 2,
                                  width: double.infinity,
                                  color: palette.lineSoft,
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 420),
                                  curve: Curves.easeOutCubic,
                                  height: 2,
                                  width:
                                      c.maxWidth *
                                      (total == 0 ? 0.0 : done / total),
                                  color: fc.amberBright.withValues(alpha: 0.85),
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
                        color: palette.muted,
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
    final count = (_snapshot?.ready.length ?? 0) + _tasksOutstanding;
    final badgeColor = fc.rewardGold;
    final icon = Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      backgroundColor: badgeColor,
      textColor: fc.onColor(badgeColor),
      child: Icon(Icons.emoji_events_outlined, color: widget.color),
    );
    if (widget.style == CampaignRewardsStyle.bar) {
      return _bar(context);
    }

    if (widget.style == CampaignRewardsStyle.tile) {
      // A row of the profile's journal panel, in its type.
      final palette = BracketPalette.of(context);
      TextStyle mono(double size, Color color) => TextStyle(
        fontFamily: 'monospace',
        color: color,
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
        height: 1.2,
      );
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: context.soundAction(widget.enabled ? open : null),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ACHIEVEMENTS', style: mono(11.5, palette.ink)),
                    const SizedBox(height: 4),
                    Text(
                      'Main story, rewards and memories',
                      style: bracketText(
                        context,
                        12.5,
                        palette.muted,
                      ).copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 12),
                Text('$count WAITING', style: mono(10.5, fc.rewardGold)),
              ],
              const SizedBox(width: 4),
              Icon(
                AppIcons.chevron_right_rounded,
                size: 20,
                color: palette.muted,
              ),
            ],
          ),
        ),
      );
    }
    return IconButton(
      tooltip: count > 0 ? 'Achievements · $count waiting' : 'Achievements',
      onPressed: context.soundAction(widget.enabled ? open : null),
      icon: icon,
    );
  }
}
