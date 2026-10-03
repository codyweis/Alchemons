import 'package:alchemons/audio/audio.dart';
// screens/breed/breed_screen.dart

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/screens/breed/breed_tab.dart';
import 'package:alchemons/screens/breed/nursery_tab.dart';
import 'package:alchemons/screens/story/models/story_page.dart';
import 'package:alchemons/services/cold_storage_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/game_data_gate.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/loading_widget.dart';
import 'package:alchemons/widgets/nav_bar.dart';
import 'package:alchemons/widgets/starter_granted_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum _BreedMode { cultivations, fusion }

class BreedScreen extends StatefulWidget {
  const BreedScreen({
    super.key,
    this.title = 'Alchemons',
    this.onGoToSection,
    this.isActive = false,
    this.cultivationsFocusToken = 0,
  });
  final String title;
  final ValueChanged<NavSection>? onGoToSection;
  final bool isActive;

  /// Changes whenever the shell is asked to land on the cultivations side —
  /// a notification tap, say. The value itself means nothing; only that it
  /// differs from the last one this screen saw.
  final int cultivationsFocusToken;

  @override
  State<BreedScreen> createState() => _BreedScreenState();
}

class _BreedScreenState extends State<BreedScreen> {
  _BreedMode _mode = _BreedMode.cultivations;
  bool _coldStorageIntroCheckInFlight = false;

  @override
  void initState() {
    super.initState();
    _maybeShowColdStorageIntroIfEligible();
  }

  @override
  void didUpdateWidget(covariant BreedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cultivationsFocusToken != widget.cultivationsFocusToken) {
      // Assigned rather than _setMode'd: the rebuild that brought the new
      // token here is already on its way, so setState would only ask for a
      // second one.
      _mode = _BreedMode.cultivations;
    }
    if (!oldWidget.isActive && widget.isActive) {
      _maybeShowColdStorageIntroIfEligible();
    }
  }

  void _goCreatureScreen() {
    widget.onGoToSection?.call(NavSection.creatures);
  }

  void _setMode(_BreedMode next) {
    if (_mode == next) return;
    setState(() => _mode = next);
  }

  void _handleModeSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 250) return;
    if (velocity < 0) {
      _setMode(_BreedMode.fusion);
      return;
    }
    _setMode(_BreedMode.cultivations);
  }

  void _maybeShowColdStorageIntroIfEligible() {
    if (!mounted || !widget.isActive) return;
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
      if (seen == '1' ||
          !mounted ||
          !widget.isActive ||
          _mode != _BreedMode.cultivations) {
        return;
      }

      final storedEggs = await db.incubatorDao.watchInventory().first;
      if (!mounted ||
          !widget.isActive ||
          _mode != _BreedMode.cultivations ||
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
                    onPressed: context.soundAction(
                      () => Navigator.of(dialogContext).pop(),
                    ),
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
      final story = context.read<StoryManager>();
      story.trigger(StoryEvent.firstBreeding);
      final pages = story.drainQueue();

      if (pages.isNotEmpty) {
        await SystemDialog.show(
          context,
          title: 'An older echo',
          message:
              'The first vial opens. Another presence speaks as though it remembers an earlier ritual.',
          primaryLabel: 'CONTINUE',
          barrierDismissible: false,
        );
        if (!mounted) return;
        await SystemDialog.playStory(context, pages);
        await story.acknowledge(StoryEvent.firstBreeding);
      }

      await db.settingsDao.setSetting('first_extraction_done', '1');
      await db.settingsDao.deleteSetting('tutorial_extraction_pending');
      await db.settingsDao.setNavLocked(false);

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
              final isCultivations = _mode == _BreedMode.cultivations;
              return ParticleBackgroundScaffold(
                whiteBackground: theme.brightness == Brightness.light,
                body: Scaffold(
                  backgroundColor: Colors.transparent,
                  body: SafeArea(
                    bottom: false,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragEnd: _handleModeSwipe,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Builder(
                              builder: (context) {
                                final palette = BracketPalette.fromTheme(theme);
                                return BracketTabs(
                                  labels: const ['CULTIVATIONS', 'FUSION'],
                                  selected: isCultivations ? 0 : 1,
                                  onSelect: (i) => _setMode(
                                    i == 0
                                        ? _BreedMode.cultivations
                                        : _BreedMode.fusion,
                                  ),
                                  palette: palette,
                                  accent: fusionGold(palette),
                                );
                              },
                            ),
                          ),
                          Expanded(
                            child: IndexedStack(
                              index: isCultivations ? 0 : 1,
                              sizing: StackFit.expand,
                              children: [
                                TickerMode(
                                  enabled: isCultivations,
                                  child: NurseryTab(
                                    maxSeenNowUtc: DateTime.now().toUtc(),
                                    onHatchComplete: _handleExtractionComplete,
                                    onRequestAddEgg: () =>
                                        _setMode(_BreedMode.fusion),
                                    onRequestFusion: () =>
                                        _setMode(_BreedMode.fusion),
                                  ),
                                ),
                                TickerMode(
                                  enabled: !isCultivations,
                                  child: BreedingTab(
                                    discoveredCreatures: entries,
                                    onBreedingComplete: _noop,
                                  ),
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
            },
      ),
    );
  }
}

void _noop() {}
