import 'dart:async';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/screens/story/campaign_journal_screen.dart';
import 'package:alchemons/services/campaign_journal_service.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Event-driven notifications: database changes, route return, and app resume.
/// No polling, background service, or system notification permission required.
class CampaignRewardsButton extends StatefulWidget {
  const CampaignRewardsButton({
    super.key,
    this.color,
    this.enabled = true,
    this.expanded = false,
  });
  final Color? color;
  final bool enabled, expanded;
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
      final previous = _snapshot;
      setState(() => _snapshot = next);
      if (widget.enabled && (_route?.isCurrent ?? false)) {
        final fresh = next.ready
            .where((a) => !_announced.contains(a.id))
            .toList();
        _announced.addAll(next.ready.map((a) => a.id));
        if (previous != null && fresh.isNotEmpty) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(
                '${next.ready.length} achievement ${next.ready.length == 1 ? 'reward' : 'rewards'} ready to collect',
              ),
              action: SnackBarAction(label: 'View', onPressed: open),
            ),
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

  @override
  Widget build(BuildContext context) {
    final count = _snapshot?.ready.length ?? 0;
    final icon = Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      backgroundColor: const Color(0xFFE4C16A),
      textColor: const Color(0xFF201B0C),
      child: Icon(Icons.emoji_events_outlined, color: widget.color),
    );
    if (widget.expanded) {
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
      onPressed: widget.enabled ? open : null,
      icon: icon,
    );
  }
}
