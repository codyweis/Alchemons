import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/screens/story/models/story_page.dart';
import 'package:alchemons/services/campaign_journal_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const _gold = Color(0xFFE4C16A);
const _mint = Color(0xFF8CD9B3);

class CampaignJournalScreen extends StatefulWidget {
  const CampaignJournalScreen({super.key});
  @override
  State<CampaignJournalScreen> createState() => _CampaignJournalScreenState();
}

class _CampaignJournalScreenState extends State<CampaignJournalScreen> {
  late Future<CampaignSnapshot> _snapshot;
  bool _claiming = false;
  String _filter = 'All';
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

  Future<void> claim(List<CampaignAchievement> rewards) async {
    if (_claiming) return;
    setState(() => _claiming = true);
    var gold = 0;
    var silver = 0;
    try {
      for (final reward in rewards) {
        if (await service.claim(reward.id)) {
          gold += reward.gold;
          silver += reward.silver;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            gold + silver > 0
                ? 'Collected $gold Gold and $silver Silver.'
                : 'Rewards already collected.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Some rewards could not be collected. Remaining rewards are safe to retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        await refresh();
        if (mounted) setState(() => _claiming = false);
      }
    }
  }

  Widget card(String title, String text, {Widget? action}) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _gold,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(text, style: const TextStyle(height: 1.5)),
          if (action != null) ...[const SizedBox(height: 14), action],
        ],
      ),
    ),
  );

  Widget rewardLabel(CampaignAchievement a) => Text(
    '${a.gold} Gold  ·  ${a.silver} Silver',
    style: const TextStyle(
      color: _gold,
      fontWeight: FontWeight.w600,
      fontSize: 13,
    ),
  );

  String category(CampaignAchievement a) {
    if (campaignMissionIds.contains(a.id)) return 'Story';
    if (a.id.startsWith('collection')) return 'Collection';
    if (a.id.startsWith('survival')) return 'Survival';
    return 'Challenges';
  }

  IconData categoryIcon(CampaignAchievement a) => switch (category(a)) {
    'Story' => Icons.auto_stories_outlined,
    'Collection' => Icons.auto_awesome_mosaic_outlined,
    'Survival' => Icons.shield_outlined,
    _ => Icons.emoji_events_outlined,
  };

  Widget achievement(CampaignSnapshot s, CampaignAchievement a) {
    final collected = s.claimed.contains(a.id);
    final ready = s.earned(a) && !collected;
    return Container(
      key: ValueKey('reward_${a.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ready ? const Color(0xFF172A25) : const Color(0xFF171C23),
        border: Border.all(
          color: ready ? _mint.withValues(alpha: .5) : Colors.white10,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                collected ? Icons.check_circle_outline : categoryIcon(a),
                color: collected
                    ? Colors.white38
                    : ready
                    ? _mint
                    : _gold,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      a.description,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!s.earned(a)) ...[
            LinearProgressIndicator(
              value: s.progress(a) / a.target,
              minHeight: 5,
              borderRadius: BorderRadius.circular(4),
              color: _gold,
              backgroundColor: Colors.white10,
            ),
            const SizedBox(height: 8),
            Text(
              '${s.progress(a)} / ${a.target}${a.metric == 'collectionPercent' ? '%' : ''}',
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
            const SizedBox(height: 10),
          ],
          Wrap(
            spacing: 14,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              rewardLabel(a),
              if (ready)
                FilledButton(
                  key: ValueKey('claim_${a.id}'),
                  onPressed: _claiming ? null : () => claim([a]),
                  child: const Text('Collect'),
                ),
              if (collected)
                const Text(
                  'Collected',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void showArchive(CampaignSnapshot s, {required bool memories}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Theme(
          data: journalTheme,
          child: Scaffold(
            appBar: AppBar(
              title: Text(memories ? 'Memories' : 'Story progress'),
            ),
            body: ListView(
              padding: const EdgeInsets.all(20),
              children: memories
                  ? memoryCards(s)
                  : [
                      const Text(
                        'Your main story',
                        style: TextStyle(fontSize: 22, color: _gold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Milestones advance as you play. Collecting a reward never blocks the next mission.',
                        style: TextStyle(color: Colors.white70, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      for (final (index, a) in campaignMissions.indexed)
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 6,
                          ),
                          leading: Icon(
                            s.earned(a)
                                ? Icons.check_circle
                                : s.currentMission?.id == a.id
                                ? Icons.radio_button_checked
                                : Icons.lock_outline,
                            color: s.earned(a) ? _mint : _gold,
                          ),
                          title: Text(
                            s.earned(a) || s.currentMission?.id == a.id
                                ? a.title
                                : 'Chapter ${index + 1} · Undiscovered',
                          ),
                          subtitle: Text(
                            s.earned(a)
                                ? 'Complete${s.claimed.contains(a.id) ? ' · Reward collected' : ' · Reward ready'}'
                                : s.currentMission?.id == a.id
                                ? campaignMissionInstructions[a.id]!
                                : 'Continue the main story to reveal this chapter.',
                          ),
                        ),
                    ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> memoryCards(CampaignSnapshot s) => [
    const Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Text(
        'Fragments from another presence. A memory is not necessarily the truth.',
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

  ThemeData get journalTheme => ThemeData.dark().copyWith(
    scaffoldBackgroundColor: const Color(0xFF0C1016),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0C1016),
      surfaceTintColor: Colors.transparent,
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: _gold,
      brightness: Brightness.dark,
    ).copyWith(primary: _gold, onPrimary: const Color(0xFF201B0C)),
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: journalTheme,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        actions: [
          IconButton(
            tooltip: 'Refresh progress',
            onPressed: _claiming ? null : refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<CampaignSnapshot>(
        future: _snapshot,
        builder: (context, state) {
          if (state.hasError) {
            return Center(
              child: TextButton(
                onPressed: refresh,
                child: const Text('Could not load progress. Retry'),
              ),
            );
          }
          if (!state.hasData) {
            return const Center(child: CircularProgressIndicator());
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
            onRefresh: refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF302C22), Color(0xFF1B2229)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _gold.withValues(alpha: .35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        current == null
                            ? 'MAIN STORY · COMPLETE'
                            : 'MAIN STORY · CHAPTER ${campaignMissionIds.indexOf(current.id) + 1} / ${campaignMissions.length}',
                        style: const TextStyle(
                          color: _gold,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        current?.title ?? 'The ritual continues',
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        current == null
                            ? 'The collection remains. Exploration, Survival, contests, and rites are yours to continue.'
                            : campaignMissionInstructions[current.id]!,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                      if (current != null) ...[
                        const SizedBox(height: 14),
                        rewardLabel(current),
                        if (current.target > 1) ...[
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: s.progress(current) / current.target,
                            color: _gold,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${s.progress(current)} / ${current.target} complete',
                          ),
                        ],
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: () => showArchive(s, memories: false),
                            icon: const Icon(Icons.route, size: 18),
                            label: const Text('Story progress'),
                          ),
                          TextButton.icon(
                            onPressed: () => showArchive(s, memories: true),
                            icon: const Icon(
                              Icons.auto_stories_outlined,
                              size: 18,
                            ),
                            label: const Text('Memories'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                if (ready.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.notifications_active_outlined,
                        color: _mint,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${ready.length} rewards ready',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: _mint,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _claiming ? null : () => claim(ready),
                    icon: const Icon(Icons.redeem, size: 18),
                    label: Text(
                      _claiming
                          ? 'Collecting…'
                          : 'Collect all · ${ready.fold(0, (v, a) => v + a.gold)} Gold + ${ready.fold(0, (v, a) => v + a.silver)} Silver',
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final a in ready) achievement(s, a),
                  const SizedBox(height: 16),
                ] else ...[
                  const Text(
                    'All rewards collected',
                    style: TextStyle(color: _mint, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your next milestones are below.',
                    style: TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 20),
                ],
                const Text(
                  'Next achievements',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final filter in [
                        'All',
                        'Collection',
                        'Story',
                        'Survival',
                        'Challenges',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: _filter == filter,
                            onSelected: (_) => setState(() => _filter = filter),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                for (final a in available) achievement(s, a),
                if (available.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No unfinished achievements in this category.'),
                  ),
                if (collected.isNotEmpty)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      'Collected · ${collected.length} / ${campaignAchievements.length}',
                    ),
                    children: [for (final a in collected) achievement(s, a)],
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
