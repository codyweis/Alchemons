import 'package:alchemons/widgets/onboarding_tasks_section.dart';
import 'package:alchemons/services/timed_boost_service.dart';
import 'dart:async';

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/screens/story/models/story_page.dart';
import 'package:alchemons/services/campaign_journal_service.dart';
import 'package:alchemons/widgets/achievements/achievement_sphere.dart';
import 'package:alchemons/widgets/achievements/reward_collect_burst.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/widgets/element_resource_glyph.dart';
import 'package:alchemons/widgets/inventory_item_artwork.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// The achievements: the main story as a row of chapter beads over the
/// current chapter, then every other achievement as a grain sphere, three
/// across per category, that forms as it is worked towards. Tapping one
/// opens what it asks and what it pays.
///
/// It was a list of outlined cards in a mint and amber of its own until
/// 2026-10, the last screen still in that look.
class CampaignJournalScreen extends StatefulWidget {
  const CampaignJournalScreen({super.key});

  /// Names this screen's route so closing can drop every stacked copy of it
  /// without touching whatever it was opened over.
  static const String routeName = 'campaign_journal';

  /// The route to push. Always use this rather than a bare
  /// MaterialPageRoute: an unnamed journal is one the close button cannot
  /// recognise, and it would be left behind.
  static Route<void> route() => MaterialPageRoute<void>(
    settings: const RouteSettings(name: routeName),
    builder: (_) => const CampaignJournalScreen(),
  );
  @override
  State<CampaignJournalScreen> createState() => _CampaignJournalScreenState();
}

/// The categories the spheres are shelved under, in page order. The main
/// story is not one of them: its chapters are the beads at the top.
const _shelves = ['Collection', 'Exploration', 'Survival', 'Challenges'];

/// Which shelf an achievement lives on.
///
/// Cultivating specific families and breeding a species true are collection
/// goals — they are about what ends up in the catalog, not about a system
/// being exercised — so they sit with the discovery counts rather than in
/// the Challenges bucket everything unmatched falls into.
String _shelfOf(CampaignAchievement a) {
  if (campaignMissionIds.contains(a.id)) return 'Story';
  const collection = {'collection', 'fuse_', 'pure_'};
  if (collection.any(a.id.startsWith)) return 'Collection';
  if (a.id.startsWith('survival')) return 'Survival';
  const exploration = {'planets', 'raid', 'portal', 'maxim', 'constellation'};
  if (exploration.any(a.id.startsWith)) return 'Exploration';
  return 'Challenges';
}

/// A shelf's grains: the element whose matter it is closest to, so the
/// colors are ones the game already uses (the shop's element strip). The
/// story is pale brass.
Color _toneOf(String shelf, FC fc) => switch (shelf) {
  'Story' => fc.amberBright,
  'Collection' => ElementResources.byKey['res_verdant']!.color,
  'Exploration' => ElementResources.byKey['res_arcane']!.color,
  'Survival' => ElementResources.byKey['res_volcanic']!.color,
  _ => ElementResources.byKey['res_oceanic']!.color,
};

TextStyle _mono(double size, Color color, {double spacing = 1.6}) => TextStyle(
  fontFamily: 'monospace',
  color: color,
  fontSize: size,
  fontWeight: FontWeight.w800,
  letterSpacing: spacing,
  height: 1.2,
);

class _CampaignJournalScreenState extends State<CampaignJournalScreen> {
  late Future<CampaignSnapshot> _snapshot;
  bool _claiming = false;

  /// Live sphere rects, so the collect burst leaves from the sphere that was
  /// collected rather than from some fixed point on the screen.
  final Map<String, GlobalKey> _sphereKeys = {};

  /// Ids mid-collect, held so the sphere can settle before the snapshot
  /// reloads underneath it.
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
      _sphereKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'ach_$id'));

  Rect? _rectFor(String id) {
    final ctx = _sphereKeys[id]?.currentContext;
    if (ctx == null || !ctx.mounted) return null;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Where the coins are headed: the top-right corner, which is where the
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
        // The rect is read BEFORE the claim; a sphere scrolled out of view
        // has none, and its coins simply do not fly.
        final rect = _rectFor(reward.id);

        if (await service.claim(
          reward.id,
          boosts: context.read<TimedBoostService>(),
        )) {
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
      // captured its start rect already. No `return` in here either — it
      // would swallow anything thrown above.
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
    showGameSnack(context, message, accent: FC.of(context).rewardGold);
  }

  AchievementSphereState _stateOf(CampaignSnapshot s, CampaignAchievement a) {
    if (s.claimed.contains(a.id) || _collecting.contains(a.id)) {
      return AchievementSphereState.sealed;
    }
    if (s.earned(a)) return AchievementSphereState.ready;
    if (s.isSpoiler(a)) return AchievementSphereState.hidden;
    return AchievementSphereState.underway;
  }

  // ── Pieces ────────────────────────────────────────────────────────────────

  /// A reward, drawn with the coins and item art the rest of the game uses
  /// rather than the words "Gold" and "Silver".
  Widget rewardLabel(CampaignAchievement a, {double size = 12.5}) {
    final palette = BracketPalette.of(context);
    Widget item(Widget art, int amount, Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        art,
        const SizedBox(width: 4),
        Text('×$amount', style: _mono(size * 0.92, color, spacing: 0.4)),
      ],
    );

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (a.gold > 0)
          CoinAmount(kind: CoinKind.gold, amount: a.gold, size: size),
        if (a.silver > 0)
          CoinAmount(kind: CoinKind.silver, amount: a.silver, size: size),
        for (final entry in a.items.entries)
          item(
            InventoryItemArtwork(inventoryKey: entry.key, size: size * 1.6),
            entry.value,
            palette.muted,
          ),
        for (final entry in a.resources.entries)
          if (ElementResources.byKey[entry.key] case final res?)
            item(
              ElementResourceGlyph(
                biomeId: res.biomeId,
                color: res.color,
                size: size * 1.6,
                animate: false,
              ),
              entry.value,
              res.color,
            ),
      ],
    );
  }

  /// One status word under a sphere, in the same place on every one.
  Widget _status(CampaignSnapshot s, CampaignAchievement a) {
    final fc = FC.of(context);
    final palette = BracketPalette.of(context);
    return switch (_stateOf(s, a)) {
      AchievementSphereState.underway => Text(
        '${s.progress(a)} / ${a.target}'
        '${a.metric == 'collectionPercent' ? '%' : ''}',
        style: _mono(10.5, palette.ink.withValues(alpha: 0.75), spacing: 0.6),
      ),
      AchievementSphereState.ready => Text(
        'READY',
        style: _mono(10, fc.rewardGold),
      ),
      AchievementSphereState.sealed => Text(
        'SEALED',
        style: _mono(9.5, palette.muted),
      ),
      AchievementSphereState.hidden => Text(
        '—',
        style: _mono(10, palette.muted),
      ),
    };
  }

  // ── The sheet ─────────────────────────────────────────────────────────────

  /// What a sphere asks and what it pays, with COLLECT when it is ready.
  Future<void> _openSheet(CampaignSnapshot s, CampaignAchievement a) async {
    HapticFeedback.selectionClick();
    final fc = FC.of(context);
    final palette = BracketPalette.of(context);
    final shelf = _shelfOf(a);
    final tone = _toneOf(shelf, fc);
    final chapter = campaignMissionIds.indexOf(a.id);
    final isCurrent = s.currentMission?.id == a.id;
    // The current chapter is drawn forming, as its bead is, never hidden.
    final state = isCurrent ? AchievementSphereState.underway : _stateOf(s, a);
    final progress = s.progress(a) / a.target;

    final collect = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: palette.bg1,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      shape: const RoundedRectangleBorder(),
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 3, color: palette.line),
              const SizedBox(height: 4),
              AchievementSphere(
                size: 150,
                tone: tone,
                state: state,
                progress: isCurrent ? 0.45 + 0.55 * progress : progress,
                seed: AchievementSphere.seedFor(a.id),
                gold: fc.rewardGold,
              ),
              Text(
                chapter >= 0
                    ? 'MAIN STORY · CHAPTER ${chapter + 1}'
                    : shelf.toUpperCase(),
                style: _mono(10, tone, spacing: 2),
              ),
              const SizedBox(height: 6),
              Text(
                a.title,
                textAlign: TextAlign.center,
                style: bracketText(sheet, 24, palette.ink),
              ),
              const SizedBox(height: 6),
              Text(
                isCurrent ? campaignMissionInstructions[a.id]! : a.description,
                textAlign: TextAlign.center,
                style: bracketText(
                  sheet,
                  13.5,
                  palette.muted,
                ).copyWith(height: 1.35),
              ),
              if (state == AchievementSphereState.underway && a.target > 1) ...[
                const SizedBox(height: 16),
                _Track(value: progress, color: tone),
                const SizedBox(height: 6),
                _status(s, a),
              ],
              const SizedBox(height: 16),
              Opacity(
                opacity: state == AchievementSphereState.sealed ? 0.45 : 1,
                child: rewardLabel(a, size: 14),
              ),
              const SizedBox(height: 20),
              if (state == AchievementSphereState.ready)
                SizedBox(
                  width: double.infinity,
                  child: BracketButton(
                    label: 'COLLECT',
                    onTap: () => Navigator.of(sheet).pop(true),
                    palette: palette,
                    accent: fc.rewardGold,
                  ),
                )
              else if (state == AchievementSphereState.sealed)
                Text('COLLECTED', style: _mono(10.5, palette.muted)),
            ],
          ),
        ),
      ),
    );
    // Collected after the sheet has gone, so the coins leave from the sphere
    // on the page rather than from under a closing sheet.
    if (collect == true && mounted && !_claiming) await claim([a]);
  }

  // ── Archive ───────────────────────────────────────────────────────────────

  void showArchive(CampaignSnapshot s, {required bool memories}) {
    final fc = FC.of(context);
    final palette = BracketPalette.of(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (page) => Scaffold(
          backgroundColor: palette.bg0,
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 18, 4),
                  child: Row(
                    children: [
                      BracketIconButton(
                        icon: AppIcons.arrow_back_rounded,
                        onTap: () => Navigator.of(page).pop(),
                        palette: palette,
                        size: 42,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        memories ? 'Memories' : 'Story so far',
                        style: bracketText(page, 24, palette.ink),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
                    children: memories
                        ? memoryEntries(page, s)
                        : [
                            Text(
                              'Milestones advance as you play. Collecting a '
                              'reward never blocks the next chapter.',
                              style: bracketText(
                                page,
                                13,
                                palette.muted,
                              ).copyWith(height: 1.4),
                            ),
                            const SizedBox(height: 14),
                            for (final (index, a) in campaignMissions.indexed)
                              _ChapterRow(
                                index: index,
                                achievement: a,
                                snapshot: s,
                                isCurrent: s.currentMission?.id == a.id,
                                state: _stateOf(s, a),
                                tone: _toneOf('Story', fc),
                                gold: fc.rewardGold,
                              ),
                          ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> memoryEntries(BuildContext page, CampaignSnapshot s) {
    final palette = BracketPalette.of(page);
    final seen = campaignEntries.where((e) => s.seen.contains(e.id)).toList();
    return [
      Text(
        'Fragments from another presence. A memory is not necessarily the '
        'truth.',
        style: bracketText(page, 13, palette.muted).copyWith(height: 1.4),
      ),
      const SizedBox(height: 8),
      for (final e in seen) _Entry(title: e.title, text: e.text),
      if (s.seen.isEmpty)
        const _Entry(
          title: 'An empty page',
          text: 'Your journey has only just begun.',
        ),
      if (s.seen.contains('awakening'))
        _Fold(
          title: 'The opening passages',
          subtitle: 'Preserved as they appeared before waking',
          text: AlchemonsStory.darkPrelude.map((p) => p.mainText).join('\n\n'),
        ),
      if (s.seen.contains('extraction'))
        _Entry(
          title: 'An older echo',
          text: AlchemonsStory.breedingIntro
              .map((p) => '${p.mainText}\n${p.subtitle ?? ''}')
              .join('\n'),
        ),
    ];
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    return Scaffold(
      backgroundColor: palette.bg0,
      body: FutureBuilder<CampaignSnapshot>(
        future: _snapshot,
        builder: (context, state) {
          final s = state.data;
          return SafeArea(
            bottom: false,
            child: Column(
              children: [
                _Header(snapshot: s),
                Expanded(
                  child: state.hasError
                      ? Center(
                          child: SizedBox(
                            width: 240,
                            child: BracketButton(
                              label: 'COULD NOT LOAD · RETRY',
                              onTap: refresh,
                              palette: palette,
                              accent: FC.of(context).amber,
                              primary: false,
                              height: 40,
                            ),
                          ),
                        )
                      // Loading takes a frame or two; a spinner would only
                      // flash.
                      : s == null
                      ? const SizedBox.shrink()
                      : _page(s),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _page(CampaignSnapshot s) {
    final fc = FC.of(context);
    final current = s.currentMission;
    final ready = s.ready.where((a) => !_collecting.contains(a.id)).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        28 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        _ChapterBeads(
          snapshot: s,
          stateOf: (a) => _stateOf(s, a),
          keyFor: _keyFor,
          tone: _toneOf('Story', fc),
          gold: fc.rewardGold,
          onTap: (a) => _openSheet(s, a),
        ),
        const SizedBox(height: 10),
        _StoryPanel(
          current: current,
          snapshot: s,
          rewardLabel: current == null ? null : rewardLabel(current, size: 13),
          onProgress: () => showArchive(s, memories: false),
          onMemories: () => showArchive(s, memories: true),
        ),
        if (ready.isNotEmpty) ...[
          const SizedBox(height: 14),
          _ReadyBand(
            count: ready.length,
            gold: ready.fold(0, (v, a) => v + a.gold),
            silver: ready.fold(0, (v, a) => v + a.silver),
            claiming: _claiming,
            onCollectAll: () => claim(ready),
          ),
        ],

        // Under anything claimable: a reward the player can collect right
        // now outranks a room they have not visited.
        const OnboardingTasksSection(),

        for (final shelf in _shelves) ...[
          _ShelfHead(
            title: shelf.toUpperCase(),
            trailing:
                '${campaignAchievements.where((a) => _shelfOf(a) == shelf && s.claimed.contains(a.id)).length}'
                ' / ${campaignAchievements.where((a) => _shelfOf(a) == shelf).length}',
          ),
          _SphereWall(
            children: [
              for (final a in campaignAchievements)
                if (_shelfOf(a) == shelf)
                  _SphereCell(
                    key: ValueKey('reward_${a.id}'),
                    sphereKey: _keyFor(a.id),
                    title: a.title,
                    state: _stateOf(s, a),
                    progress: s.progress(a) / a.target,
                    seed: AchievementSphere.seedFor(a.id),
                    tone: _toneOf(shelf, fc),
                    gold: fc.rewardGold,
                    status: _status(s, a),
                    onTap: () => _openSheet(s, a),
                  ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

/// One row: the name, what has been collected of the whole set, and a way
/// out.
class _Header extends StatelessWidget {
  const _Header({required this.snapshot});

  final CampaignSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    final s = snapshot;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Achievements',
                maxLines: 1,
                style: bracketText(context, 24, palette.ink),
              ),
            ),
          ),
          if (s != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: palette.surfaceFill(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${s.claimed.length} / ${campaignAchievements.length}',
                    style: _mono(14, palette.ink, spacing: 0.6),
                  ),
                  const SizedBox(height: 2),
                  Text('COLLECTED', style: _mono(8.5, palette.muted)),
                ],
              ),
            ),
          ],
          const SizedBox(width: 8),
          // Closes rather than pops one route.
          //
          // Collecting a task from a notification pushes this screen, and
          // that notification can fire while it is already open — so a back
          // arrow could leave two or three journals stacked behind each
          // other, each needing its own press. This leaves for good.
          BracketIconButton(
            icon: AppIcons.close_rounded,
            palette: palette,
            size: 42,
            onTap: () {
              // Every journal on the stack, and nothing below them: the
              // notification can push this over the shop or the
              // constellations, and closing must not take those with it.
              Navigator.of(context).popUntil(
                (r) =>
                    r.settings.name != CampaignJournalScreen.routeName ||
                    r.isFirst,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Chapter beads ───────────────────────────────────────────────────────────

/// The main story as a row of spheres on a thread: chapters done are formed,
/// the current one is forming (and larger), the ones ahead are dark glass.
/// A chapter whose reward is waiting glows gold like any ready sphere.
class _ChapterBeads extends StatelessWidget {
  const _ChapterBeads({
    required this.snapshot,
    required this.stateOf,
    required this.keyFor,
    required this.tone,
    required this.gold,
    required this.onTap,
  });

  final CampaignSnapshot snapshot;
  final AchievementSphereState Function(CampaignAchievement) stateOf;
  final GlobalKey Function(String id) keyFor;
  final Color tone;
  final Color gold;
  final ValueChanged<CampaignAchievement> onTap;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    final current = snapshot.currentMission;
    return LayoutBuilder(
      builder: (context, c) {
        final slot = c.maxWidth / campaignMissions.length;
        final bead = (slot * 0.86).clamp(18.0, 32.0);
        final big = (slot * 1.12).clamp(22.0, 42.0);
        return SizedBox(
          height: big,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: slot / 2,
                right: slot / 2,
                child: Container(
                  height: 1,
                  color: palette.line.withValues(alpha: 0.6),
                ),
              ),
              Row(
                children: [
                  for (final a in campaignMissions)
                    SizedBox(
                      width: slot,
                      child: Center(
                        child: _bead(
                          context,
                          a,
                          a.id == current?.id,
                          bead,
                          big,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bead(
    BuildContext context,
    CampaignAchievement a,
    bool isCurrent,
    double bead,
    double big,
  ) {
    final state = stateOf(a);
    final sphere = SizedBox.square(
      key: keyFor(a.id),
      dimension: isCurrent ? big : bead,
      child: AchievementSphere(
        size: isCurrent ? big : bead,
        tone: tone,
        // The current chapter is shown forming even before any of it is
        // done, so the eye finds it; it is never hidden like the ones after.
        state: isCurrent ? AchievementSphereState.underway : state,
        progress: isCurrent
            ? 0.45 + 0.55 * snapshot.progress(a) / a.target
            : snapshot.progress(a) / a.target,
        seed: AchievementSphere.seedFor(a.id),
        gold: gold,
      ),
    );
    // Nothing to read about a chapter not reached yet.
    if (state == AchievementSphereState.hidden && !isCurrent) return sphere;
    return Semantics(
      button: true,
      label: isCurrent ? 'Current chapter: ${a.title}' : a.title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: context.soundAction(() => onTap(a)),
        child: sphere,
      ),
    );
  }
}

// ── Story panel ─────────────────────────────────────────────────────────────

/// The current chapter: the one lit panel on the page.
class _StoryPanel extends StatelessWidget {
  const _StoryPanel({
    required this.current,
    required this.snapshot,
    required this.rewardLabel,
    required this.onProgress,
    required this.onMemories,
  });

  final CampaignAchievement? current;
  final CampaignSnapshot snapshot;
  final Widget? rewardLabel;
  final VoidCallback onProgress;
  final VoidCallback onMemories;

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final palette = BracketPalette.of(context);
    final mission = current;
    final chapter = mission == null
        ? 'MAIN STORY · COMPLETE'
        : 'MAIN STORY · CHAPTER '
              '${campaignMissionIds.indexOf(mission.id) + 1} OF ${campaignMissions.length}';

    return CustomPaint(
      foregroundPainter: BracketFramePainter(
        color: fc.amber.withValues(alpha: 0.8),
        strokeWidth: 1.2,
      ),
      child: Container(
        color: palette.accentWash(fc.amber, darkAlpha: 0.07),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The chapter line runs long on a narrow phone; it has to be
            // allowed to shrink rather than push the panel open.
            Text(
              chapter,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _mono(10.5, fc.amberBright, spacing: 1.8),
            ),
            const SizedBox(height: 8),
            Text(
              mission?.title ?? 'The ritual continues',
              style: bracketText(context, 22, palette.ink),
            ),
            const SizedBox(height: 6),
            Text(
              mission == null
                  ? 'The collection remains. Exploration, Survival, contests, '
                        'and rites are yours to continue.'
                  : campaignMissionInstructions[mission.id]!,
              style: bracketText(
                context,
                13,
                palette.muted,
              ).copyWith(height: 1.35),
            ),
            if (mission != null) ...[
              const SizedBox(height: 12),
              rewardLabel!,
              if (mission.target > 1) ...[
                const SizedBox(height: 12),
                _Track(
                  value: snapshot.progress(mission) / mission.target,
                  color: fc.amberBright,
                ),
                const SizedBox(height: 6),
                Text(
                  '${snapshot.progress(mission)} / ${mission.target} complete',
                  style: _mono(
                    10.5,
                    palette.ink.withValues(alpha: 0.75),
                    spacing: 0.6,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _QuietButton(label: 'STORY SO FAR', onTap: onProgress),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuietButton(label: 'MEMORIES', onTap: onMemories),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A secondary button on a bg0 well: the kit's quiet fill alone vanishes on
/// a panel (the profile's buttons do the same).
class _QuietButton extends StatelessWidget {
  const _QuietButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    return Container(
      color: palette.bg0,
      child: BracketButton(
        label: label,
        onTap: onTap,
        palette: palette,
        accent: FC.of(context).amber,
        primary: false,
        height: 36,
      ),
    );
  }
}

// ── Ready band ──────────────────────────────────────────────────────────────

/// How many rewards wait and what they come to, with one button for all of
/// them. Lit from below in gold: it is the thing to do on this page.
class _ReadyBand extends StatelessWidget {
  const _ReadyBand({
    required this.count,
    required this.gold,
    required this.silver,
    required this.claiming,
    required this.onCollectAll,
  });

  final int count;
  final int gold;
  final int silver;
  final bool claiming;
  final VoidCallback onCollectAll;

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final palette = BracketPalette.of(context);
    return CustomPaint(
      foregroundPainter: BracketFramePainter(
        color: fc.rewardGold.withValues(alpha: 0.8),
        strokeWidth: 1.2,
      ),
      child: Container(
        color: palette.accentWash(fc.rewardGold, darkAlpha: 0.06),
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$count READY', style: _mono(11, fc.rewardGold)),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 10,
                    children: [
                      CoinAmount(kind: CoinKind.gold, amount: gold, size: 11.5),
                      CoinAmount(
                        kind: CoinKind.silver,
                        amount: silver,
                        size: 11.5,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 150,
              child: BracketButton(
                label: claiming ? 'COLLECTING…' : 'COLLECT ALL',
                onTap: onCollectAll,
                enabled: !claiming,
                palette: palette,
                accent: fc.rewardGold,
                height: 38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shelves ─────────────────────────────────────────────────────────────────

/// The shop's section head: a bar, spaced capitals, a hairline to the edge,
/// and how many of the shelf are collected.
class _ShelfHead extends StatelessWidget {
  const _ShelfHead({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final palette = BracketPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            color: fc.amberBright,
            margin: const EdgeInsets.only(right: 10),
          ),
          Text(title, style: _mono(12, fc.amberBright, spacing: 2.2)),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: fc.amberBright.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(width: 10),
          Text(trailing, style: _mono(10, palette.muted, spacing: 0.6)),
        ],
      ),
    );
  }
}

/// Three across on a phone, more on anything wider, every cell the same
/// width so the spheres line up in columns.
class _SphereWall extends StatelessWidget {
  const _SphereWall({required this.children});

  final List<Widget> children;

  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columns = ((c.maxWidth + _gap) / (120 + _gap)).floor().clamp(
          3,
          8,
        );
        final cell = (c.maxWidth - _gap * (columns - 1)) / columns;
        return Wrap(
          spacing: _gap,
          runSpacing: 24,
          children: [
            for (final child in children) SizedBox(width: cell, child: child),
          ],
        );
      },
    );
  }
}

class _SphereCell extends StatelessWidget {
  const _SphereCell({
    super.key,
    required this.sphereKey,
    required this.title,
    required this.state,
    required this.progress,
    required this.seed,
    required this.tone,
    required this.gold,
    required this.status,
    required this.onTap,
  });

  final GlobalKey sphereKey;
  final String title;
  final AchievementSphereState state;
  final double progress;
  final int seed;
  final Color tone;
  final Color gold;
  final Widget status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: context.soundAction(onTap),
        child: Column(
          children: [
            // Its own layer: a running sphere repaints every frame, and
            // without one each of those frames would repaint the wall.
            RepaintBoundary(
              child: SizedBox.square(
                key: sphereKey,
                dimension: 74,
                child: AchievementSphere(
                  size: 74,
                  tone: tone,
                  state: state,
                  progress: progress,
                  seed: seed,
                  gold: gold,
                ),
              ),
            ),
            const SizedBox(height: 2),
            // Two lines at whatever size the player reads at, so every
            // status word in a row sits on one line.
            SizedBox(
              height:
                  MediaQuery.textScalerOf(context).scale(12.5) * 1.1 * 2 + 2,
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: bracketText(
                  context,
                  12.5,
                  state == AchievementSphereState.sealed
                      ? palette.muted
                      : palette.ink,
                  weight: FontWeight.w600,
                ).copyWith(height: 1.1),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: MediaQuery.textScalerOf(context).scale(13),
              child: FittedBox(fit: BoxFit.scaleDown, child: status),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small parts ─────────────────────────────────────────────────────────────

/// A 2px track on a hairline. The stock LinearProgressIndicator came with a
/// rounded cap and a Material color scheme that fought everything around it.
class _Track extends StatelessWidget {
  const _Track({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    return SizedBox(
      height: 2,
      child: Stack(
        children: [
          Container(color: palette.lineSoft),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(color: color.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

/// A chapter in the story-so-far list: its bead, its name, where it stands.
class _ChapterRow extends StatelessWidget {
  const _ChapterRow({
    required this.index,
    required this.achievement,
    required this.snapshot,
    required this.isCurrent,
    required this.state,
    required this.tone,
    required this.gold,
  });

  final int index;
  final CampaignAchievement achievement;
  final CampaignSnapshot snapshot;
  final bool isCurrent;
  final AchievementSphereState state;
  final Color tone;
  final Color gold;

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final palette = BracketPalette.of(context);
    final done = snapshot.earned(achievement);
    final revealed = done || isCurrent;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              AchievementSphere(
                size: 44,
                tone: tone,
                state: isCurrent ? AchievementSphereState.underway : state,
                progress: isCurrent
                    ? 0.45 +
                          0.55 *
                              snapshot.progress(achievement) /
                              achievement.target
                    : 0,
                seed: AchievementSphere.seedFor(achievement.id),
                gold: gold,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CHAPTER ${index + 1}',
                      style: _mono(
                        9.5,
                        isCurrent ? fc.amberBright : palette.muted,
                        spacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      revealed ? achievement.title : 'Undiscovered',
                      style: bracketText(
                        context,
                        15,
                        revealed ? palette.ink : palette.muted,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      done
                          ? 'Complete · ${snapshot.claimed.contains(achievement.id) ? 'reward collected' : 'reward ready'}'
                          : isCurrent
                          ? campaignMissionInstructions[achievement.id]!
                          : 'Continue the main story to reveal this chapter.',
                      style: bracketText(
                        context,
                        12,
                        palette.muted,
                      ).copyWith(height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(height: 1, color: palette.lineSoft),
      ],
    );
  }
}

/// A memory: its title in spaced capitals, its text, a hairline under it.
class _Entry extends StatelessWidget {
  const _Entry({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final palette = BracketPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(title.toUpperCase(), style: _mono(11, fc.amberBright)),
        const SizedBox(height: 8),
        Text(
          text,
          style: bracketText(
            context,
            14,
            palette.ink.withValues(alpha: 0.85),
          ).copyWith(height: 1.5),
        ),
        const SizedBox(height: 16),
        Container(height: 1, color: palette.lineSoft),
      ],
    );
  }
}

/// A memory long enough to keep folded until asked for.
class _Fold extends StatefulWidget {
  const _Fold({
    required this.title,
    required this.subtitle,
    required this.text,
  });

  final String title;
  final String subtitle;
  final String text;

  @override
  State<_Fold> createState() => _FoldState();
}

class _FoldState extends State<_Fold> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final palette = BracketPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: context.soundAction(() => setState(() => _open = !_open)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title.toUpperCase(),
                        style: _mono(11, fc.amberBright),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.subtitle,
                        style: bracketText(context, 12.5, palette.muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  _open ? 'CLOSE' : 'READ',
                  style: _mono(10, palette.ink, spacing: 1.4),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    widget.text,
                    style: bracketText(
                      context,
                      14,
                      palette.ink.withValues(alpha: 0.85),
                    ).copyWith(height: 1.5),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        Container(height: 1, color: palette.lineSoft),
      ],
    );
  }
}
