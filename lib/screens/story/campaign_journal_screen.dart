import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/screens/story/models/story_page.dart';
import 'package:alchemons/services/campaign_journal_service.dart';
import 'package:alchemons/widgets/achievements/reward_collect_burst.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class CampaignJournalScreen extends StatefulWidget {
  const CampaignJournalScreen({super.key});
  @override
  State<CampaignJournalScreen> createState() => _CampaignJournalScreenState();
}

class _CampaignJournalScreenState extends State<CampaignJournalScreen> {
  late Future<CampaignSnapshot> _snapshot;
  bool _claiming = false;
  String _filter = 'All';

  /// Live card rects, so the collect burst can leave from the row you tapped
  /// rather than from some fixed point on the screen.
  final Map<String, GlobalKey> _cardKeys = {};

  /// Ids mid-collect, held so the card can seal itself before the list rebuilds
  /// underneath the animation.
  final Set<String> _collecting = {};

  CampaignJournalService get service =>
      CampaignJournalService(context.read<AlchemonsDatabase>());

  @override
  void initState() {
    super.initState();
    _snapshot = service.load();
  }

  Future<void> refresh() async {
    final next = service.load();
    setState(() {
      _snapshot = next;
    });
    try {
      await next;
    } catch (_) {
      // FutureBuilder presents the retry action.
    }
  }

  GlobalKey _keyFor(String id) =>
      _cardKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'ach_$id'));

  Rect? _rectFor(String id) {
    final ctx = _cardKeys[id]?.currentContext;
    if (ctx == null || !ctx.mounted) return null;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Where the coins are headed: the top-right of the bar, which is where the
  /// wallet lives everywhere else in the game.
  Offset get _walletTarget {
    final media = MediaQuery.of(context);
    return Offset(media.size.width - 34, media.padding.top + 26);
  }

  Future<void> claim(List<CampaignAchievement> rewards) async {
    if (_claiming) return;
    setState(() => _claiming = true);
    var gold = 0;
    var silver = 0;
    try {
      var fired = 0;
      for (final reward in rewards) {
        // The rect is read BEFORE the claim, because once the snapshot
        // refreshes the row moves into the collected section and its rect is
        // somewhere else entirely.
        final rect = _rectFor(reward.id);

        if (await service.claim(reward.id)) {
          gold += reward.gold;
          silver += reward.silver;
          if (!mounted) return;

          HapticFeedback.mediumImpact();
          context.sound(SoundCue.achievementUnlock, owner: this);
          setState(() => _collecting.add(reward.id));

          if (rect != null) {
            // Collecting several is a sequence, not a single dump — but the
            // stagger is scheduled, never awaited. Blocking the loop on the
            // animation made a four-reward collect take over a second of
            // database time for no reason.
            final delay = Duration(milliseconds: 110 * fired);
            fired++;
            unawaited(
              Future<void>.delayed(delay, () {
                if (!mounted) return;
                playRewardCollect(
                  context,
                  from: rect,
                  to: _walletTarget,
                  gold: reward.gold,
                  silver: reward.silver,
                );
              }),
            );
          }
        }
      }
      if (!mounted) return;
      if (gold + silver > 0) HapticFeedback.heavyImpact();
      _notify(
        gold + silver > 0
            ? 'Collected $gold Gold and $silver Silver.'
            : 'Rewards already collected.',
      );
    } catch (_) {
      if (mounted) {
        _notify(
          'Some rewards could not be collected. Remaining rewards are safe to retry.',
        );
      }
    } finally {
      // No waiting for the coins: the burst lives in the root overlay and
      // captured its start rect already, so the list is free to reshuffle
      // underneath it. No `return` in here either — it would swallow anything
      // thrown above.
      if (mounted) {
        await refresh();
      }
      if (mounted) {
        setState(() {
          _claiming = false;
          _collecting.clear();
        });
      }
    }
  }

  void _notify(String message) {
    final fc = FC.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: fc.bg3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: fc.borderDim),
        ),
        content: Text(
          message.toUpperCase(),
          style: TextStyle(
            fontFamily: 'monospace',
            color: fc.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }

  String category(CampaignAchievement a) {
    if (campaignMissionIds.contains(a.id)) return 'Story';
    if (a.id.startsWith('collection')) return 'Collection';
    if (a.id.startsWith('survival')) return 'Survival';
    return 'Challenges';
  }

  IconData categoryIcon(CampaignAchievement a) => switch (category(a)) {
    'Story' => AppIcons.menu_book_rounded,
    'Collection' => AppIcons.grid_view_rounded,
    'Survival' => AppIcons.shield_outlined,
    _ => AppIcons.emoji_events_outlined,
  };

  // ── Pieces ────────────────────────────────────────────────────────────────

  /// A reward, drawn with the coins the rest of the game uses rather than the
  /// words "Gold" and "Silver".
  Widget rewardLabel(CampaignAchievement a, {double size = 13}) {
    final fc = FC.of(context);
    Widget coin(Widget icon, int amount, Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 4),
        Text(
          '$amount',
          style: TextStyle(
            fontFamily: 'monospace',
            color: color,
            fontSize: size,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (a.gold > 0)
          coin(CoinIcon.gold(size: size + 2), a.gold, fc.rewardGold),
        if (a.gold > 0 && a.silver > 0) const SizedBox(width: 12),
        if (a.silver > 0)
          coin(CoinIcon.silver(size: size + 2), a.silver, fc.rewardSilver),
      ],
    );
  }

  Widget _sectionHeader(String title, {Color? accent, Widget? trailing}) {
    final fc = FC.of(context);
    final color = accent ?? fc.amberBright;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(width: 3, height: 13, color: color),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontFamily: 'monospace',
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
            ),
          ),
          if (trailing != null) ...[const Spacer(), trailing],
        ],
      ),
    );
  }

  /// Squared, outlined action. The stock FilledButton was the loudest thing on
  /// the screen and the only 20px-radius shape in the app.
  Widget _forgeButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    Color? accent,
    bool dense = false,
  }) {
    final fc = FC.of(context);
    final color = accent ?? fc.amberBright;
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: context.soundAction(onTap),
          borderRadius: BorderRadius.circular(3),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: dense ? 10 : 14,
              vertical: dense ? 7 : 10,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: color.withValues(alpha: 0.55)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: dense ? 13 : 15, color: color),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: color,
                      fontSize: dense ? 10 : 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget card(String title, String text, {Widget? action}) {
    final fc = FC.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: fc.bg2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fc.borderDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: fc.bg3,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontFamily: 'monospace',
                color: fc.amberBright,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(color: fc.textSecondary, height: 1.55),
                ),
                if (action != null) ...[const SizedBox(height: 14), action],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget achievement(CampaignSnapshot s, CampaignAchievement a) {
    final fc = FC.of(context);
    final spoiler = s.isSpoiler(a);
    final collected = s.claimed.contains(a.id) || _collecting.contains(a.id);
    final ready = s.earned(a) && !collected;
    final accent = collected
        ? fc.textMuted
        : ready
        ? fc.mint
        : fc.amberBright;

    return _AchievementCard(
      key: ValueKey('reward_${a.id}'),
      cardKey: _keyFor(a.id),
      collected: collected,
      ready: ready,
      accent: accent,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  collected ? AppIcons.check_circle : categoryIcon(a),
                  color: accent,
                  size: 20,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // Still shows the reward and the row, so the player
                        // knows something is there — just not what it is.
                        spoiler ? 'Undiscovered' : a.title,
                        style: TextStyle(
                          color: collected ? fc.textMuted : fc.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        spoiler
                            ? 'Continue the main story to reveal this.'
                            : a.description,
                        style: TextStyle(
                          color: fc.textMuted,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                if (collected)
                  Text(
                    'SEALED',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: fc.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                  ),
              ],
            ),
            if (!s.earned(a)) ...[
              const SizedBox(height: 12),
              _ProgressTrack(
                value: s.progress(a) / a.target,
                color: fc.amberBright,
                track: fc.borderDim,
              ),
              const SizedBox(height: 6),
              Text(
                '${s.progress(a)} / ${a.target}'
                '${a.metric == 'collectionPercent' ? '%' : ''}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: fc.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Opacity(
                    opacity: collected ? 0.45 : 1,
                    child: rewardLabel(a),
                  ),
                ),
                if (ready)
                  _forgeButton(
                    label: 'Collect',
                    icon: AppIcons.inventory_2_outlined,
                    accent: fc.mint,
                    dense: true,
                    onTap: _claiming ? null : () => claim([a]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Archive ───────────────────────────────────────────────────────────────

  void showArchive(CampaignSnapshot s, {required bool memories}) {
    final fc = FC.of(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Theme(
          data: journalTheme,
          child: Scaffold(
            backgroundColor: fc.bg1,
            appBar: AppBar(
              backgroundColor: fc.bg1,
              surfaceTintColor: Colors.transparent,
              title: Text(
                memories ? 'MEMORIES' : 'STORY PROGRESS',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: fc.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                ),
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.all(18),
              children: memories
                  ? memoryCards(s)
                  : [
                      _ArchiveHeading(
                        title: 'Your main story',
                        accent: fc.amberBright,
                      ),
                      Text(
                        'Milestones advance as you play. Collecting a reward '
                        'never blocks the next mission.',
                        style: TextStyle(
                          color: fc.textMuted,
                          height: 1.5,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (final (index, a) in campaignMissions.indexed)
                        _ChapterRow(
                          index: index,
                          achievement: a,
                          snapshot: s,
                          isCurrent: s.currentMission?.id == a.id,
                        ),
                    ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> memoryCards(CampaignSnapshot s) => [
    Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        'Fragments from another presence. A memory is not necessarily the truth.',
        style: TextStyle(color: FC.of(context).textMuted, height: 1.5),
      ),
    ),
    for (final e in campaignEntries.where((e) => s.seen.contains(e.id)))
      card(e.title, e.text),
    if (s.seen.isEmpty)
      card('An empty page', 'Your journey has only just begun.'),
    if (s.seen.contains('awakening'))
      ExpansionTile(
        title: const Text('The opening passages'),
        subtitle: const Text('Preserved as they appeared before waking'),
        children: [
          for (final p in AlchemonsStory.darkPrelude)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(p.mainText, style: const TextStyle(height: 1.5)),
            ),
        ],
      ),
    if (s.seen.contains('extraction'))
      card(
        'An older echo',
        AlchemonsStory.breedingIntro
            .map((p) => '${p.mainText}\n${p.subtitle ?? ''}')
            .join('\n'),
      ),
  ];

  /// The journal used to hardcode `ThemeData.dark()`. Its own surfaces come
  /// from [FC], which follows the faction theme, so in light mode the screen
  /// ended up with dark-theme Material defaults — white default text, dark
  /// dividers and ripples — painted over light parchment.
  ThemeData get journalTheme {
    final theme = context.read<FactionTheme>();
    final fc = FC(theme);
    final brightness = theme.isDark ? Brightness.dark : Brightness.light;
    final gold = fc.rewardGold;
    return (theme.isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
      scaffoldBackgroundColor: fc.bg1,
      appBarTheme: AppBarTheme(
        backgroundColor: fc.bg1,
        surfaceTintColor: Colors.transparent,
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: gold,
        brightness: brightness,
      ).copyWith(primary: gold, onPrimary: fc.onColor(gold)),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    return Theme(
      data: journalTheme,
      child: Scaffold(
        backgroundColor: fc.bg1,
        appBar: AppBar(
          backgroundColor: fc.bg1,
          surfaceTintColor: Colors.transparent,
          title: Text(
            'ACHIEVEMENTS',
            style: TextStyle(
              fontFamily: 'monospace',
              color: fc.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.4,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh progress',
              onPressed: context.soundAction(_claiming ? null : refresh),
              icon: Icon(AppIcons.refresh_rounded, color: fc.textSecondary),
            ),
          ],
        ),
        body: FutureBuilder<CampaignSnapshot>(
          future: _snapshot,
          builder: (context, state) {
            if (state.hasError) {
              return Center(
                child: _forgeButton(
                  label: 'Could not load · retry',
                  icon: AppIcons.refresh_rounded,
                  onTap: context.soundAction(refresh),
                ),
              );
            }
            if (!state.hasData) {
              return Center(
                child: CircularProgressIndicator(
                  color: fc.amberBright,
                  strokeWidth: 2,
                ),
              );
            }
            final s = state.data!;
            final current = s.currentMission;
            final ready = s.ready;
            final available =
                campaignAchievements
                    .where(
                      (a) =>
                          !s.earned(a) &&
                          (_filter == 'All' || category(a) == _filter),
                    )
                    .toList()
                  ..sort(
                    (a, b) => (s.progress(b) / b.target).compareTo(
                      s.progress(a) / a.target,
                    ),
                  );
            final collected = campaignAchievements
                .where((a) => s.claimed.contains(a.id))
                .toList();

            return RefreshIndicator(
              color: fc.amberBright,
              backgroundColor: fc.bg2,
              onRefresh: refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                children: [
                  _StoryBanner(
                    current: current,
                    snapshot: s,
                    rewardLabel: current == null
                        ? null
                        : rewardLabel(current, size: 14),
                    onProgress: () => showArchive(s, memories: false),
                    onMemories: () => showArchive(s, memories: true),
                    forgeButton: _forgeButton,
                  ),
                  const SizedBox(height: 22),

                  if (ready.isNotEmpty) ...[
                    _sectionHeader(
                      '${ready.length} reward${ready.length == 1 ? '' : 's'} ready',
                      accent: fc.mint,
                    ),
                    _forgeButton(
                      label: _claiming ? 'Collecting…' : 'Collect all',
                      icon: AppIcons.inventory_2_outlined,
                      accent: fc.mint,
                      onTap: _claiming ? null : () => claim(ready),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 12),
                      child: Row(
                        children: [
                          CoinIcon.gold(size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${ready.fold(0, (v, a) => v + a.gold)}',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: fc.rewardGold,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 12),
                          CoinIcon.silver(size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${ready.fold(0, (v, a) => v + a.silver)}',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: fc.rewardSilver,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final a in ready) achievement(s, a),
                    const SizedBox(height: 18),
                  ] else ...[
                    _sectionHeader('All rewards collected', accent: fc.mint),
                    Padding(
                      padding: const EdgeInsets.only(left: 11, bottom: 20),
                      child: Text(
                        'Your next milestones are below.',
                        style: TextStyle(color: fc.textMuted, fontSize: 12),
                      ),
                    ),
                  ],

                  _sectionHeader('Next achievements'),
                  _FilterRow(
                    selected: _filter,
                    onSelect: (f) => setState(() => _filter = f),
                  ),
                  const SizedBox(height: 14),
                  for (final a in available) achievement(s, a),
                  if (available.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No unfinished achievements in this category.',
                        style: TextStyle(color: fc.textMuted),
                      ),
                    ),

                  if (collected.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        iconColor: fc.textMuted,
                        collapsedIconColor: fc.textMuted,
                        title: Text(
                          'COLLECTED · ${collected.length} / ${campaignAchievements.length}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: fc.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                          ),
                        ),
                        children: [
                          for (final a in collected) achievement(s, a),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Story banner ────────────────────────────────────────────────────────────

class _StoryBanner extends StatelessWidget {
  const _StoryBanner({
    required this.current,
    required this.snapshot,
    required this.rewardLabel,
    required this.onProgress,
    required this.onMemories,
    required this.forgeButton,
  });

  final CampaignAchievement? current;
  final CampaignSnapshot snapshot;
  final Widget? rewardLabel;
  final VoidCallback onProgress;
  final VoidCallback onMemories;
  final Widget Function({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    Color? accent,
    bool dense,
  })
  forgeButton;

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final chapter = current == null
        ? 'MAIN STORY · COMPLETE'
        : 'MAIN STORY · CHAPTER '
              '${campaignMissionIds.indexOf(current!.id) + 1} / ${campaignMissions.length}';

    return Container(
      decoration: BoxDecoration(
        color: fc.bg2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fc.amber.withValues(alpha: 0.40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: fc.bg3,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              children: [
                Container(width: 3, height: 12, color: fc.amberBright),
                const SizedBox(width: 8),
                // The chapter line runs long on a narrow phone; it has to be
                // allowed to shrink rather than push the strip open.
                Expanded(
                  child: Text(
                    chapter,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: fc.amberBright,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current?.title ?? 'The ritual continues',
                  style: TextStyle(
                    color: fc.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  current == null
                      ? 'The collection remains. Exploration, Survival, contests, and rites are yours to continue.'
                      : campaignMissionInstructions[current!.id]!,
                  style: TextStyle(
                    color: fc.textSecondary,
                    height: 1.5,
                    fontSize: 12,
                  ),
                ),
                if (current != null) ...[
                  const SizedBox(height: 12),
                  rewardLabel!,
                  if (current!.target > 1) ...[
                    const SizedBox(height: 10),
                    _ProgressTrack(
                      value: snapshot.progress(current!) / current!.target,
                      color: fc.amberBright,
                      track: fc.borderDim,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${snapshot.progress(current!)} / ${current!.target} complete',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: fc.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 14),
                // Wrap, not Row: the two labels do not fit side by side on a
                // narrow phone, and a button that cannot fit should drop to
                // the next line rather than be clipped.
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    forgeButton(
                      label: 'Story progress',
                      icon: AppIcons.menu_book_rounded,
                      onTap: context.soundAction(onProgress),
                      dense: true,
                    ),
                    forgeButton(
                      label: 'Memories',
                      icon: AppIcons.menu_book_rounded,
                      onTap: context.soundAction(onMemories),
                      dense: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Achievement shell ───────────────────────────────────────────────────────

/// Handles the card's own reaction to being collected: a brief surge, then it
/// settles into a dimmed, sealed state.
class _AchievementCard extends StatefulWidget {
  const _AchievementCard({
    super.key,
    required this.cardKey,
    required this.collected,
    required this.ready,
    required this.accent,
    required this.child,
  });

  final GlobalKey cardKey;
  final bool collected;
  final bool ready;
  final Color accent;
  final Widget child;

  @override
  State<_AchievementCard> createState() => _AchievementCardState();
}

class _AchievementCardState extends State<_AchievementCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _seal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  @override
  void didUpdateWidget(covariant _AchievementCard old) {
    super.didUpdateWidget(old);
    // Fires on the transition into collected, not on a card that was already
    // collected when the list was built.
    if (widget.collected && !old.collected) _seal.forward(from: 0);
  }

  @override
  void dispose() {
    _seal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    return AnimatedBuilder(
      animation: _seal,
      builder: (context, child) {
        final t = _seal.value;
        // Up quickly, then settle — the card acknowledges the tap before it
        // goes quiet.
        final surge = math.sin(t * math.pi);
        return Transform.scale(
          scale: 1 + 0.035 * Curves.easeOut.transform(surge),
          child: Container(
            key: widget.cardKey,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: widget.ready ? Color.lerp(fc.bg2, fc.mint, 0.06) : fc.bg2,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Color.lerp(
                  widget.ready
                      ? widget.accent.withValues(alpha: 0.55)
                      : fc.borderDim,
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
      child: widget.child,
    );
  }
}

// ── Small parts ─────────────────────────────────────────────────────────────

/// A 3px track. The stock LinearProgressIndicator came with a rounded cap and
/// a Material colour scheme that fought everything around it.
class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({
    required this.value,
    required this.color,
    required this.track,
  });

  final double value;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => Stack(
        children: [
          Container(height: 3, width: double.infinity, color: track),
          Container(
            height: 3,
            width: c.maxWidth * value.clamp(0.0, 1.0),
            color: color,
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  static const _filters = [
    'All',
    'Collection',
    'Story',
    'Survival',
    'Challenges',
  ];

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final f in _filters)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: context.soundAction(() {
                  HapticFeedback.selectionClick();
                  onSelect(f);
                }),
                // Outline and coloured text, never a fill: a filled chip reads
                // as a button you are meant to press again.
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: selected == f ? fc.amberBright : fc.borderDim,
                    ),
                  ),
                  child: Text(
                    f.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: selected == f ? fc.amberBright : fc.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({
    required this.index,
    required this.achievement,
    required this.snapshot,
    required this.isCurrent,
  });

  final int index;
  final CampaignAchievement achievement;
  final CampaignSnapshot snapshot;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final done = snapshot.earned(achievement);
    final revealed = done || isCurrent;
    final accent = done
        ? fc.mint
        : isCurrent
        ? fc.amberBright
        : fc.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fc.bg2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isCurrent ? accent.withValues(alpha: 0.5) : fc.borderDim,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done
                ? AppIcons.check_circle
                : isCurrent
                ? AppIcons.radio_button_checked
                : AppIcons.lock_outline,
            color: accent,
            size: 18,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  revealed
                      ? achievement.title
                      : 'Chapter ${index + 1} · Undiscovered',
                  style: TextStyle(
                    color: revealed ? fc.textPrimary : fc.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  done
                      ? 'Complete${snapshot.claimed.contains(achievement.id) ? ' · Reward collected' : ' · Reward ready'}'
                      : isCurrent
                      ? campaignMissionInstructions[achievement.id]!
                      : 'Continue the main story to reveal this chapter.',
                  style: TextStyle(
                    color: fc.textMuted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchiveHeading extends StatelessWidget {
  const _ArchiveHeading({required this.title, required this.accent});

  final String title;
  final Color accent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Container(width: 3, height: 13, color: accent),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontFamily: 'monospace',
            color: accent,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
          ),
        ),
      ],
    ),
  );
}
