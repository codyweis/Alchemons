// screens/breed/breed_screen.dart
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/screens/story/models/story_page.dart';
import 'package:alchemons/services/cold_storage_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/game_data_gate.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
import 'package:alchemons/widgets/loading_widget.dart';
import 'package:alchemons/widgets/nav_bar.dart';
import 'package:alchemons/widgets/starter_granted_dialog.dart';
import 'package:flutter/material.dart';

import 'package:alchemons/screens/breed/breed_tab.dart';
import 'package:alchemons/screens/breed/nursery_tab.dart';
import 'package:provider/provider.dart';

class BreedScreen extends StatefulWidget {
  const BreedScreen({
    super.key,
    this.title = 'Alchemons',
    this.onGoToSection,
    this.isActive = false,
  });
  final String title;
  final ValueChanged<NavSection>? onGoToSection;
  final bool isActive;

  @override
  State<BreedScreen> createState() => _BreedScreenState();
}

class _BreedScreenState extends State<BreedScreen>
    with SingleTickerProviderStateMixin {
  static const _tabAnimationDuration = Duration(milliseconds: 180);

  late TabController _tabController;
  int _activeTabIndex = 0;
  bool _coldStorageIntroCheckInFlight = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      animationDuration: _tabAnimationDuration,
    );
    _tabController.addListener(_handleTabChange);
    _maybeShowColdStorageIntroIfEligible();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    final nextIndex = _tabController.index;
    if (nextIndex != _activeTabIndex) {
      setState(() => _activeTabIndex = nextIndex);
      _maybeShowColdStorageIntroIfEligible();
    }
  }

  @override
  void didUpdateWidget(covariant BreedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _maybeShowColdStorageIntroIfEligible();
    }
  }

  void _goCreatureScreen() {
    widget.onGoToSection?.call(NavSection.creatures);
  }

  void _maybeShowColdStorageIntroIfEligible() {
    if (!mounted || !widget.isActive || _activeTabIndex != 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeShowColdStorageIntro();
    });
  }

  Future<void> _maybeShowColdStorageIntro() async {
    if (_coldStorageIntroCheckInFlight) return;
    _coldStorageIntroCheckInFlight = true;

    final db = context.read<AlchemonsDatabase>();
    try {
      final seen = await db.settingsDao.getSetting(
        ColdStorageService.introSeenSettingKey,
      );
      if (seen == '1' || !mounted || !widget.isActive || _activeTabIndex != 0) {
        return;
      }

      final storedEggs = await db.incubatorDao.watchInventory().first;
      if (!mounted ||
          !widget.isActive ||
          _activeTabIndex != 0 ||
          storedEggs.isEmpty) {
        return;
      }

      final theme = context.read<FactionTheme>();
      final t = ForgeTokens(theme);
      final dialogSurface = theme.isDark ? t.bg1 : Colors.white;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: dialogSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: t.borderAccent, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cold Storage',
                  style: TextStyle(
                    color: t.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Cold storage still cultivates your vials, but at a 5x slower pace. An 8 hour cultivation becomes 40 hours while stored, and moving a vial back to a chamber resumes its active cultivation time.',
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      'Got it',
                      style: TextStyle(
                        color: t.amberBright,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (!mounted) return;
      await db.settingsDao.setSetting(
        ColdStorageService.introSeenSettingKey,
        '1',
      );
    } finally {
      _coldStorageIntroCheckInFlight = false;
    }
  }

  Future<void> _handleExtractionComplete() async {
    final db = context.read<AlchemonsDatabase>();
    final firstDone =
        await db.settingsDao.getSetting('first_extraction_done') == '1';

    if (!firstDone && mounted) {
      // trigger the narrative
      final story = context.read<StoryManager>();
      story.trigger(StoryEvent.firstBreeding);
      final pages = story.drainQueue();

      // show each page inside SystemDialog
      if (pages.isNotEmpty) {
        await SystemDialog.playStory(context, pages);
      }

      // 🔑 Mark extraction as complete and clear pending flag
      await db.settingsDao.setSetting('first_extraction_done', '1');
      await db.settingsDao.deleteSetting('tutorial_extraction_pending');
      await db.settingsDao.setNavLocked(false);

      // navigate to creature screen
      _goCreatureScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: withGameData(
        context,
        loadingBuilder: buildLoadingScreen,
        builder:
            (
              context, {
              required theme,
              required catalog,
              required entries,
              required discovered,
            }) {
              final hasHatchedCreature = discovered.isNotEmpty;
              final isLocked = !hasHatchedCreature;

              return ParticleBackgroundScaffold(
                whiteBackground: theme.brightness == Brightness.light,
                body: Scaffold(
                  backgroundColor: Colors.transparent,
                  appBar: AppBar(
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(1),
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              theme.border.withValues(alpha: .7),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    title: IgnorePointer(
                      ignoring: isLocked,
                      child: TabBar(
                        labelColor: theme.accent,
                        unselectedLabelColor: theme.textMuted,
                        controller: _tabController,
                        indicatorColor: theme.accent,
                        indicatorWeight: 2.5,
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                        tabs: [
                          Tab(
                            child: Builder(
                              builder: (ctx) {
                                final color =
                                    DefaultTextStyle.of(ctx).style.color ??
                                    theme.textMuted;
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.science_rounded,
                                      size: 14,
                                      color: color,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text('CULTIVATIONS'),
                                  ],
                                );
                              },
                            ),
                          ),
                          Tab(
                            child: Builder(
                              builder: (ctx) {
                                final color =
                                    DefaultTextStyle.of(ctx).style.color ??
                                    theme.textMuted;
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.merge_type_rounded,
                                      size: 14,
                                      color: color,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text('FUSION'),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  body: TabBarView(
                    controller: _tabController,
                    physics: _activeTabIndex == 0
                        ? const NeverScrollableScrollPhysics()
                        : const _SnappyTabPagePhysics(),
                    children: [
                      TickerMode(
                        enabled: _activeTabIndex == 0,
                        child: NurseryTab(
                          maxSeenNowUtc: DateTime.now().toUtc(),
                          onHatchComplete: _handleExtractionComplete,
                          onRequestAddEgg: () => _tabController.animateTo(
                            1,
                            duration: _tabAnimationDuration,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                      ),
                      TickerMode(
                        enabled: _activeTabIndex == 1,
                        child: BreedingTab(
                          discoveredCreatures: entries,
                          onBreedingComplete: _noop,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
      ),
    );
  }
}

void _noop() {}

class _SnappyTabPagePhysics extends PageScrollPhysics {
  const _SnappyTabPagePhysics({super.parent});

  @override
  _SnappyTabPagePhysics applyTo(ScrollPhysics? ancestor) {
    return _SnappyTabPagePhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
    mass: 0.7,
    stiffness: 260,
    ratio: 1.02,
  );
}
