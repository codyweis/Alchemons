// screens/breed/breed_screen.dart
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/screens/story/models/story_page.dart';
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
  const BreedScreen({super.key, this.title = 'Alchemons', this.onGoToSection});
  final String title;
  final ValueChanged<NavSection>? onGoToSection;

  @override
  State<BreedScreen> createState() => _BreedScreenState();
}

class _BreedScreenState extends State<BreedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
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
    }
  }

  void _goCreatureScreen() {
    widget.onGoToSection?.call(NavSection.creatures);
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
                    children: [
                      TickerMode(
                        enabled: _activeTabIndex == 0,
                        child: NurseryTab(
                          maxSeenNowUtc: DateTime.now().toUtc(),
                          onHatchComplete: _handleExtractionComplete,
                          onRequestAddEgg: () => _tabController.animateTo(1),
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
