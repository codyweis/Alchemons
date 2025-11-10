// screens/breed/breed_screen.dart
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/screens/creatures_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

      await db.settingsDao.setSetting('first_extraction_done', '1');
      await db.settingsDao.deleteSetting(
        'tutorial_extraction_pending',
      ); // Clear the flag
      await db.settingsDao.setNavLocked(false);

      // navigate to creature screen
      _goCreatureScreen();
    } else {}
  }

  @override
  Widget build(BuildContext context) {
    return withGameData(
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
                  title: IgnorePointer(
                    ignoring: isLocked,
                    child: TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: 'Cultivations'),
                        Tab(text: 'Fusion'),
                      ],
                    ),
                  ),
                ),
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    NurseryTab(
                      maxSeenNowUtc: DateTime.now().toUtc(),
                      onHatchComplete: _handleExtractionComplete,
                      onRequestAddEgg: () => _tabController.animateTo(1),
                    ),
                    BreedingTab(
                      discoveredCreatures: entries,
                      onBreedingComplete: _noop,
                    ),
                  ],
                ),
              ),
            );
          },
    );
  }
}

void _noop() {}
