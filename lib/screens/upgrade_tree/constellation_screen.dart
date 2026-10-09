// lib/screens/upgrade_tree/constellation_screen.dart
//
// The star chart's screen: the chart itself (ConstellationGame) under a thin
// layer of chrome in the bracket language the lab and the market use — a
// header with the points balance, a tab per tree with its count, and the
// chosen tree's name at the foot. Each tree's color is its light from
// constellation_art.dart, so a tab, its stones and its sky always agree.

import 'dart:async';

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/constellations/constellation_art.dart';
import 'package:alchemons/games/constellations/constellation_game.dart';
import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/screens/progress_overview_screen.dart';
import 'package:alchemons/screens/upgrade_tree/constellation_skill_dialog.dart';
import 'package:alchemons/services/constellation_service.dart';
import 'package:alchemons/services/onboarding_tasks.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

const _palette = BracketPalette.dark;
const _mono = 'monospace';

TextStyle _label(double size, Color color, {double spacing = 1.4}) => TextStyle(
  fontFamily: _mono,
  color: color,
  fontSize: size,
  fontWeight: FontWeight.w800,
  letterSpacing: spacing,
);

/// How tall the chrome over the chart is, so the chart can frame its trees
/// in what is left and keep its verse out from under it.
const double _kHeaderHeight = 58;
const double _kTabsHeight = 58;
const double _kFooterHeight = 86;

class ConstellationScreen extends StatefulWidget {
  const ConstellationScreen({super.key, this.revealReady, this.revealed});

  /// Set true once the constellation game is attached, for an entry portal
  /// covering this screen (VoidPortal.pushThroughGlyphs).
  final ValueNotifier<bool>? revealReady;

  /// From home's UPGRADE emblem, whose sky disc opens into this chart's
  /// sky: until this turns true the chart shows only its sky; then it
  /// lights its trees and the chrome comes in. Null: shown whole at once.
  final ValueListenable<bool>? revealed;

  @override
  State<ConstellationScreen> createState() => _ConstellationScreenState();
}

class _ConstellationScreenState extends State<ConstellationScreen> {
  static const String _firstUnlockSkillId = 'breeder_cross_species';
  ConstellationTree _selectedTree = ConstellationTree.breeder;
  ConstellationGame? _game;
  bool _gameInitialized = false;
  bool _finaleHandled =
      false; // Track if we've checked/played finale this session
  bool _treeAvailabilityInitialized = false;
  bool _isTreeRevealPlaying = false;
  Set<ConstellationTree> _availableTrees = const {ConstellationTree.breeder};

  /// Mirrored from the streams in [build] so the skill dialog can show the
  /// cost as a ledger (cost / balance / remainder) rather than a bare number.
  int _currentPoints = 0;
  Set<String> _currentUnlocked = const {};

  late final RevealWhenReady _revealWhenReady;

  /// The header, tabs and tree panel: in with the chart's entrance.
  late bool _chromeIn = widget.revealed?.value ?? true;

  void _onRevealed() {
    if (!(widget.revealed?.value ?? true) || _chromeIn) return;
    _game?.playEntrance();
    if (mounted) setState(() => _chromeIn = true);
  }

  @override
  void initState() {
    super.initState();
    widget.revealed?.addListener(_onRevealed);
    _revealWhenReady = RevealWhenReady(
      widget.revealReady,
      () => mounted && (_game?.isAttached ?? false),
    );
    // Arriving earns the task; collecting it happens in the journal.
    OnboardingTaskService.recordArrival(context, 'constellation');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _primeConstellationTutorialFlow();
    });
  }

  @override
  void dispose() {
    widget.revealed?.removeListener(_onRevealed);
    _revealWhenReady.dispose();
    super.dispose();
  }

  /// Runs [cover] — a dialog, a sheet, another screen — with the chart
  /// paused underneath it. Nothing behind a barrier needs to move, and the
  /// chart animates every frame it runs.
  Future<T?> _whileCovered<T>(Future<T?> Function() cover) async {
    final game = _game;
    game?.pauseEngine();
    try {
      return await cover();
    } finally {
      if (mounted) game?.resumeEngine();
    }
  }

  void _selectTree(ConstellationTree tree) {
    if (!_gameInitialized) return;
    if (!_availableTrees.contains(tree) || tree == _selectedTree) return;

    setState(() {
      _selectedTree = tree;
    });
    _game?.transitionToTree(tree);
  }

  void _handleTreeTap(ConstellationTree tree) {
    if (_isFirstUnlockLocked) {
      _showFirstUnlockLockedMessage();
      return;
    }
    HapticFeedback.selectionClick();
    _selectTree(tree);
  }

  void _openProgressOverview() {
    if (_isFirstUnlockLocked) {
      _showFirstUnlockLockedMessage();
      return;
    }
    _whileCovered(
      () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ConstellationProgressOverviewScreen(),
        ),
      ),
    );
  }

  // Tutorial state
  bool _constellationTutorialChecked = false;
  bool _firstUnlockGuidanceActive = false;
  bool _firstUnlockGuidanceChecked = false;

  bool get _isFirstUnlockLocked => _firstUnlockGuidanceActive;

  Future<void> _primeConstellationTutorialFlow() async {
    if (_firstUnlockGuidanceChecked || !mounted) return;
    _firstUnlockGuidanceChecked = true;

    final db = context.read<AlchemonsDatabase>();
    final settings = db.settingsDao;
    final constellation = context.read<ConstellationService>();
    final alreadyUnlocked = await constellation.isSkillUnlocked(
      _firstUnlockSkillId,
    );

    if (alreadyUnlocked) {
      await settings.clearConstellationFirstUnlockPending();
      return;
    }

    final pending = await settings.hasPendingConstellationFirstUnlock();
    if (!mounted) return;

    if (pending) {
      final canStartGuide = await constellation.canUnlockSkill(
        _firstUnlockSkillId,
      );
      if (!mounted) return;
      if (canStartGuide) {
        _activateFirstUnlockGuidance();
      }
      return;
    }

    await _maybeShowConstellationTutorial();
  }

  void _activateFirstUnlockGuidance() {
    if (_firstUnlockGuidanceActive) return;
    setState(() {
      _firstUnlockGuidanceActive = true;
      _selectedTree = ConstellationTree.breeder;
    });
    _game?.tutorialLocked = true;
    _focusFirstUnlockNode();
  }

  Future<void> _completeFirstUnlockGuidance() async {
    final db = context.read<AlchemonsDatabase>();
    await db.settingsDao.clearConstellationFirstUnlockPending();
    if (!mounted || !_firstUnlockGuidanceActive) return;
    setState(() => _firstUnlockGuidanceActive = false);
    _game?.tutorialLocked = false;
  }

  void _focusFirstUnlockNode() {
    _game?.focusOnSkill(_firstUnlockSkillId, zoom: 1.0);
  }

  void _showFirstUnlockLockedMessage() {
    if (!mounted) return;
    showGameSnack(
      context,
      'Unlock Cross-Species Lineage to continue.',
      accent: treeLight(ConstellationTree.breeder).essence,
    );
  }

  Future<void> _maybeShowConstellationTutorial() async {
    if (_constellationTutorialChecked) return;
    _constellationTutorialChecked = true;

    if (!context.mounted) return;

    final db = context.read<AlchemonsDatabase>();
    final settings = db.settingsDao;
    final hasSeen = await settings.hasSeenConstellationTutorial();
    if (hasSeen || !mounted) return;

    await _showChartDialog(
      title: 'CONSTELLATIONS',
      accent: treeLight(ConstellationTree.breeder).essence,
      dismissible: false,
      body: const [
        _ChartDialogText(
          'Earn constellation points, spend them to unlock skills, and '
          'reveal three trees in order: Alchemy, Explorer, then Combat.',
        ),
        SizedBox(height: 14),
        _ChartDialogStep(
          sigil: ChartSigil.star,
          title: 'EARN POINTS',
          body: 'Fuse creatures and complete milestones to gain points.',
        ),
        SizedBox(height: 10),
        _ChartDialogStep(
          sigil: ChartSigil.rise,
          title: 'UNLOCK SKILLS',
          body:
              'Spend points to light stones that boost breeding, combat, '
              'or extraction.',
        ),
        SizedBox(height: 10),
        _ChartDialogStep(
          sigil: ChartSigil.lineage,
          title: 'EXPLORE TREES',
          body: 'Switch tabs to view each tree and plan your progression.',
        ),
      ],
      confirmLabel: 'GOT IT',
      onConfirm: () => settings.setConstellationTutorialSeen(),
    );

    if (!mounted) return;
    final constellation = context.read<ConstellationService>();
    final alreadyUnlocked = await constellation.isSkillUnlocked(
      _firstUnlockSkillId,
    );
    if (alreadyUnlocked || !mounted) return;

    await settings.setConstellationFirstUnlockPending();
    final canStartGuide = await constellation.canUnlockSkill(
      _firstUnlockSkillId,
    );
    if (!mounted) return;
    if (canStartGuide) {
      _activateFirstUnlockGuidance();
    }
  }

  /// A dialog in the chart's own frame: brackets in [accent] round a dark
  /// panel, the title in spaced monospace, one button.
  Future<void> _showChartDialog({
    required String title,
    required Color accent,
    required List<Widget> body,
    required String confirmLabel,
    bool dismissible = true,
    Future<void> Function()? onConfirm,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: dismissible,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: CustomPaint(
          foregroundPainter: BracketFramePainter(
            color: accent.withValues(alpha: 0.9),
            bracketSize: 14,
            strokeWidth: 1.3,
          ),
          child: Container(
            color: _palette.bg1,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: _label(14, _palette.ink, spacing: 1.8)),
                const SizedBox(height: 12),
                ...body,
                const SizedBox(height: 18),
                BracketButton(
                  label: confirmLabel,
                  height: 42,
                  palette: _palette,
                  accent: accent,
                  onTap: () async {
                    await onConfirm?.call();
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getTreeName(ConstellationTree tree) {
    switch (tree) {
      case ConstellationTree.breeder:
        return 'ALCHEMY';
      case ConstellationTree.combat:
        return 'COMBAT';
      case ConstellationTree.extraction:
        return 'EXPLORER';
    }
  }

  String _getTreeDescription(ConstellationTree tree) {
    switch (tree) {
      case ConstellationTree.breeder:
        return 'Genetics & Breeding Mastery';
      case ConstellationTree.combat:
        return 'Combat & Boss Battles';
      case ConstellationTree.extraction:
        return 'Resources & Convenience';
    }
  }

  Color _treeAccent(ConstellationTree tree) => treeLight(tree).essence;

  (int unlocked, int total) _getTreeProgress(
    ConstellationTree tree,
    Set<String> unlockedSkills,
  ) {
    final treeSkills = ConstellationCatalog.forTree(tree);
    final unlockedCount = treeSkills
        .where((s) => unlockedSkills.contains(s.id))
        .length;
    return (unlockedCount, treeSkills.length);
  }

  Set<ConstellationTree> _deriveAvailableTrees(Set<String> unlockedSkills) {
    final breederUnlocked = _getTreeProgress(
      ConstellationTree.breeder,
      unlockedSkills,
    ).$1;
    final extractionUnlocked = _getTreeProgress(
      ConstellationTree.extraction,
      unlockedSkills,
    ).$1;

    final trees = <ConstellationTree>{ConstellationTree.breeder};
    if (breederUnlocked >= 3) {
      trees.add(ConstellationTree.extraction);
    }
    if (extractionUnlocked >= 1) {
      trees.add(ConstellationTree.combat);
    }
    return trees;
  }

  void _syncTreeAvailability(Set<String> unlockedSkills) {
    final nextAvailableTrees = _deriveAvailableTrees(unlockedSkills);

    if (!_treeAvailabilityInitialized) {
      _treeAvailabilityInitialized = true;
      _availableTrees = nextAvailableTrees;
      if (!_availableTrees.contains(_selectedTree)) {
        _selectedTree = ConstellationTree.breeder;
      }
      return;
    }

    final newlyAvailableTrees = nextAvailableTrees.difference(_availableTrees);
    if (newlyAvailableTrees.isEmpty) {
      _availableTrees = nextAvailableTrees;
      if (!_availableTrees.contains(_selectedTree)) {
        _selectedTree = ConstellationTree.breeder;
      }
      return;
    }

    _availableTrees = nextAvailableTrees;

    if (_isTreeRevealPlaying || !mounted) return;

    final revealTree =
        newlyAvailableTrees.contains(ConstellationTree.extraction)
        ? ConstellationTree.extraction
        : ConstellationTree.combat;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _playTreeReveal(revealTree);
    });
  }

  Future<void> _playTreeReveal(ConstellationTree tree) async {
    if (_isTreeRevealPlaying || !_availableTrees.contains(tree) || !mounted) {
      return;
    }

    _isTreeRevealPlaying = true;
    setState(() {
      _selectedTree = tree;
    });

    HapticFeedback.heavyImpact();
    _game?.setVisibleTrees(_availableTrees);
    await _game?.playTreeRevealSequence(tree);

    if (mounted) {
      showGameSnack(
        context,
        '${_getTreeName(tree)} tree revealed',
        accent: _treeAccent(tree),
      );
    }

    _isTreeRevealPlaying = false;
  }

  /// Check if all skills are unlocked and handle finale accordingly
  Future<void> _checkAndHandleFinale(
    Set<String> unlockedSkills,
    ConstellationService constellationService,
  ) async {
    if (_finaleHandled) return; // Already handled this session

    final totalSkills = ConstellationCatalog.allSkills.length;
    final allUnlocked = unlockedSkills.length == totalSkills;

    if (!allUnlocked) return; // Not all skills unlocked yet

    // All skills are unlocked - check if user has seen the finale before
    final hasSeenBefore = await constellationService.hasSeenFinale();

    if (!hasSeenBefore) {
      // First time seeing finale - play full animation
      _finaleHandled = true;

      // Trigger heavy haptic feedback
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 100), () {
        HapticFeedback.heavyImpact();
      });

      // Play the finale animation
      await _game?.triggerFinale();

      // Mark as seen in the database
      await constellationService.markFinaleAsSeen();
    } else {
      // User has seen finale before - jump to end state
      _finaleHandled = true;
      await _game?.showFinaleEndState();
    }
  }

  @override
  Widget build(BuildContext context) {
    // The star chart is a dark surface by design — its own palette is
    // hardcoded dark, and the node colors come from FactionTheme. In light
    // mode that read handed the game light-theme colors to draw stars and
    // hexes with, so the whole chart washed out.
    return ForcedFactionBrightness(
      brightness: Brightness.dark,
      child: Builder(builder: _buildBody),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    final constellationService = context.watch<ConstellationService>();
    final safe = MediaQuery.paddingOf(context);
    final topChrome = safe.top + _kHeaderHeight + _kTabsHeight;
    final bottomChrome = safe.bottom + _kFooterHeight;

    return PopScope(
      canPop: !_isFirstUnlockLocked,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isFirstUnlockLocked) {
          _showFirstUnlockLockedMessage();
        }
      },
      child: Scaffold(
        backgroundColor: _palette.bg0,
        body: StreamBuilder<int>(
          stream: constellationService.watchPointBalance(),
          builder: (context, pointsSnapshot) {
            final points = pointsSnapshot.data ?? 0;
            _currentPoints = points;

            return StreamBuilder<Set<String>>(
              stream: constellationService.watchUnlockedSkillIds(),
              builder: (context, unlockedSnapshot) {
                final unlockedSkills = unlockedSnapshot.data ?? {};
                _currentUnlocked = unlockedSkills;
                if (unlockedSnapshot.hasData) {
                  _syncTreeAvailability(unlockedSkills);
                  if (_isFirstUnlockLocked &&
                      unlockedSkills.contains(_firstUnlockSkillId)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _completeFirstUnlockGuidance();
                    });
                  }
                }

                // Build the chart from the saved unlocks, not from the empty
                // set the stream starts on: built empty, every owned skill
                // then arrived as a new unlock and poured in again on open.
                if (_game == null && !unlockedSnapshot.hasData) {
                  return const SizedBox.expand();
                }

                if (_game == null) {
                  _game =
                      ConstellationGame(
                          selectedTree: _selectedTree,
                          unlockedSkills: unlockedSkills,
                          visibleTrees: _availableTrees,
                          onSkillTapped: (skill) => _handleSkillTap(
                            context,
                            skill,
                            constellationService,
                          ),
                          primaryColor: theme.primary,
                          secondaryColor: theme.secondary,
                          tutorialLocked: _isFirstUnlockLocked,
                        )
                        ..chartInsets = EdgeInsets.only(
                          top: topChrome,
                          bottom: bottomChrome,
                        );
                  _gameInitialized = true;
                  if (!_chromeIn) _game!.holdEntrance();
                  if (_isFirstUnlockLocked) {
                    _focusFirstUnlockNode();
                  }

                  Future.delayed(const Duration(milliseconds: 500), () {
                    _checkAndHandleFinale(unlockedSkills, constellationService);
                  });
                } else {
                  _game!.tutorialLocked = _isFirstUnlockLocked;
                  _game!.updateUnlockedSkills(unlockedSkills);
                  _game!.setVisibleTrees(_availableTrees);
                  _checkAndHandleFinale(unlockedSkills, constellationService);
                }

                return Stack(
                  children: [
                    Positioned.fill(child: GameWidget(game: _game!)),
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: !_chromeIn,
                        child: AnimatedOpacity(
                          opacity: _chromeIn ? 1 : 0,
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOut,
                          child: Stack(
                            children: [
                              // One scrim under each band of chrome, the
                              // full width of the screen, so the chart fades
                              // out beneath it rather than meeting a box's
                              // edge.
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: topChrome + 36,
                                child: _Scrim(top: true),
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                height: bottomChrome + 40,
                                child: _Scrim(top: false),
                              ),
                              SafeArea(
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: _kHeaderHeight,
                                      child: _buildHeader(
                                        points,
                                        unlockedSkills,
                                      ),
                                    ),
                                    SizedBox(
                                      height: _kTabsHeight,
                                      child: _buildTreeSelector(unlockedSkills),
                                    ),
                                    if (_isFirstUnlockLocked)
                                      _buildFirstUnlockBanner(),
                                    const Spacer(),
                                    SizedBox(
                                      height: _kFooterHeight,
                                      child: _buildTreeInfo(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildFirstUnlockBanner() {
    final accent = _treeAccent(ConstellationTree.breeder);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: accent.withValues(alpha: 0.85),
          bracketSize: 9,
          strokeWidth: 1.2,
        ),
        child: Container(
          width: double.infinity,
          color: _palette.bg1.withValues(alpha: 0.92),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CustomPaint(
                  painter: SigilPainter(ChartSigil.merge, accent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FIRST UNLOCK', style: _label(11, accent)),
                    const SizedBox(height: 4),
                    Text(
                      'Tap Cross-Species Lineage and unlock it to continue.',
                      style: bracketText(context, 12.5, _palette.ink),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int points, Set<String> unlockedSkills) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          BracketIconButton(
            icon: AppIcons.arrow_back_ios_new_rounded,
            palette: _palette,
            color: _palette.ink,
            size: 40,
            onTap: _isFirstUnlockLocked
                ? _showFirstUnlockLockedMessage
                : () => VoidPortal.pop(context),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONSTELLATION',
                  style: _label(13, _palette.ink, spacing: 2.6),
                ),
                const SizedBox(height: 3),
                Text(
                  'Chart your line through the sky.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bracketText(
                    context,
                    11.5,
                    _palette.muted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          BracketIconButton(
            icon: AppIcons.grid_view_rounded,
            palette: _palette,
            color: _palette.ink,
            size: 40,
            onTap: () => _showUnlockedSkillsSheet(context, unlockedSkills),
          ),
          const SizedBox(width: 8),
          _PointsReadout(
            points: points,
            onTap: context.soundTap(_openProgressOverview),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeSelector(Set<String> unlockedSkills) {
    const allTrees = [
      ConstellationTree.combat,
      ConstellationTree.breeder,
      ConstellationTree.extraction,
    ];
    final trees = allTrees.where(_availableTrees.contains).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          for (var i = 0; i < trees.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _TreeTab(
                label: _getTreeName(trees[i]),
                accent: _treeAccent(trees[i]),
                progress: _getTreeProgress(trees[i], unlockedSkills),
                selected: _selectedTree == trees[i],
                onTap: context.soundTap(() => _handleTreeTap(trees[i])),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTreeInfo() {
    final accent = _treeAccent(_selectedTree);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Lozenge(color: accent),
                    const SizedBox(width: 8),
                    Text(
                      _getTreeName(_selectedTree),
                      style: _label(12.5, accent, spacing: 2.2),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  _getTreeDescription(_selectedTree),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bracketText(context, 13, _palette.ink),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 138,
            child: BracketButton(
              label: 'HOW TO EARN',
              primary: false,
              height: 38,
              palette: _palette,
              accent: accent,
              onTap: () => _showEarnPointsDialog(),
            ),
          ),
        ],
      ),
    );
  }

  void _showEarnPointsDialog() {
    if (_isFirstUnlockLocked) {
      _showFirstUnlockLockedMessage();
      return;
    }
    _whileCovered(
      () => _showChartDialog(
        title: 'EARN CONSTELLATION POINTS',
        accent: _treeAccent(_selectedTree),
        body: const [
          _ChartDialogText(
            'Fuse creatures and complete their milestone progress to earn '
            'constellation points. Spend those points here to unlock '
            'passive upgrades across the sky map.',
          ),
          SizedBox(height: 14),
          _ChartDialogStep(
            sigil: ChartSigil.merge,
            title: 'FUSION MILESTONES',
            body: 'Fusion milestones award the points, not extraction taps.',
          ),
        ],
        confirmLabel: 'GOT IT',
      ),
    );
  }

  void _showUnlockedSkillsSheet(
    BuildContext context,
    Set<String> unlockedSkills,
  ) {
    if (_isFirstUnlockLocked) {
      _showFirstUnlockLockedMessage();
      return;
    }
    final byTree = <ConstellationTree, List<ConstellationSkill>>{
      for (final tree in ConstellationTree.values) tree: [],
    };
    for (final skillId in unlockedSkills) {
      final skill = ConstellationCatalog.byId(skillId);
      if (skill != null) byTree[skill.tree]!.add(skill);
    }
    final total = ConstellationCatalog.allSkills.length;

    _whileCovered(
      () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.6),
        builder: (sheetContext) => DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) => CustomPaint(
            foregroundPainter: BracketFramePainter(
              color: _palette.line.withValues(alpha: 0.9),
              bracketSize: 14,
            ),
            child: Container(
              color: _palette.bg1,
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    width: 36,
                    height: 3,
                    color: _palette.muted.withValues(alpha: 0.4),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'UNLOCKED SKILLS',
                            style: _label(13, _palette.ink, spacing: 2.4),
                          ),
                        ),
                        Text(
                          '${unlockedSkills.length} / $total',
                          style: _label(12, _palette.muted),
                        ),
                        const SizedBox(width: 12),
                        BracketIconButton(
                          icon: AppIcons.close_rounded,
                          palette: _palette,
                          size: 36,
                          onTap: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        for (final tree in const [
                          ConstellationTree.breeder,
                          ConstellationTree.combat,
                          ConstellationTree.extraction,
                        ])
                          if (byTree[tree]!.isNotEmpty) ...[
                            _buildTreeSection(tree, byTree[tree]!),
                            const SizedBox(height: 18),
                          ],
                        if (unlockedSkills.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              children: [
                                Text(
                                  'NO SKILLS UNLOCKED YET',
                                  style: _label(12, _palette.ink),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Light stones on the chart to see them '
                                  'listed here.',
                                  textAlign: TextAlign.center,
                                  style: bracketText(
                                    context,
                                    12.5,
                                    _palette.muted,
                                  ),
                                ),
                              ],
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
      ),
    );
  }

  Widget _buildTreeSection(
    ConstellationTree tree,
    List<ConstellationSkill> skills,
  ) {
    final accent = _treeAccent(tree);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Lozenge(color: accent),
            const SizedBox(width: 8),
            Text(_getTreeName(tree), style: _label(11.5, accent, spacing: 1.8)),
            const SizedBox(width: 10),
            Expanded(child: Container(height: 1, color: _palette.lineSoft)),
            const SizedBox(width: 10),
            Text('${skills.length}', style: _label(11, _palette.muted)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _getTreeDescription(tree),
          style: bracketText(context, 12, _palette.muted),
        ),
        const SizedBox(height: 10),
        for (final skill in skills)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CustomPaint(
                      painter: SigilPainter(sigilFor(skill), accent),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skill.name,
                        style: bracketText(
                          context,
                          13.5,
                          _palette.ink,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        skill.description,
                        style: bracketText(
                          context,
                          12.5,
                          _palette.ink.withValues(alpha: 0.72),
                        ).copyWith(height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _handleSkillTap(
    BuildContext context,
    ConstellationSkill skill,
    ConstellationService service,
  ) async {
    HapticFeedback.mediumImpact();

    if (_isFirstUnlockLocked && skill.id != _firstUnlockSkillId) {
      _showFirstUnlockLockedMessage();
      return;
    }

    final isUnlocked = await service.isSkillUnlocked(skill.id);
    final canUnlock = await service.canUnlockSkill(skill.id);
    if (!context.mounted) return;

    _showSkillDialog(
      context,
      skill,
      service,
      mode: isUnlocked
          ? SkillDialogMode.owned
          : canUnlock
          ? SkillDialogMode.available
          : SkillDialogMode.locked,
    );
  }

  /// One dialog for all three node states — see [ConstellationSkillDialog].
  void _showSkillDialog(
    BuildContext context,
    ConstellationSkill skill,
    ConstellationService service, {
    required SkillDialogMode mode,
  }) {
    _whileCovered(
      () => showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: skill.name,
        // Dark enough to sit the dialog forward without hiding the star
        // chart it belongs to.
        barrierColor: const Color(0xC404060A),
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (dialogContext, _, _) => ConstellationSkillDialog(
          skill: skill,
          mode: mode,
          pointsAvailable: _currentPoints,
          prerequisiteStates: {
            for (final id in skill.prerequisites)
              id: _currentUnlocked.contains(id),
          },
          onUnlock: mode == SkillDialogMode.available
              ? () => _performUnlock(dialogContext, skill, service)
              : null,
        ),
        transitionBuilder: (context, anim, _, child) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            // A short rise, so it reads as the stone opening up rather than
            // a system alert dropping in.
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Future<void> _performUnlock(
    BuildContext dialogContext,
    ConstellationSkill skill,
    ConstellationService service,
  ) async {
    final settingsDao = context.read<AlchemonsDatabase>().settingsDao;
    final success = await service.unlockSkill(skill.id);
    if (success && skill.id == _firstUnlockSkillId) {
      await settingsDao.clearConstellationFirstUnlockPending();
    }
    if (!dialogContext.mounted) return;
    Navigator.of(dialogContext).pop();

    if (success) {
      // No confirmation toast: closing the dialog resumes the chart, and the
      // pour runs down the link and lights the stone. Covering that would
      // hide the only part of this the player wants to watch.
      HapticFeedback.heavyImpact();
      // Heard the same way: a linked stone waits for its pour (1.05 s) and
      // ignites as it lands; a stone with no link ignites at once.
      if (mounted) {
        context.sound(
          skill.prerequisites.isEmpty
              ? SoundCue.upgradeComplete
              : SoundCue.constellationAttune,
        );
      }
      return;
    }
    // The button is disabled when you cannot afford it, so this only fires on
    // a genuine race. Still needs to say something.
    if (!mounted) return;
    showGameSnack(
      context,
      'Not enough skill points for ${skill.name}',
      accent: const Color(0xFFE0885A),
    );
  }
}

/// The chart fading out under a band of chrome.
class _Scrim extends StatelessWidget {
  const _Scrim({required this.top});
  final bool top;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: top ? Alignment.topCenter : Alignment.bottomCenter,
            end: top ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              _palette.bg0.withValues(alpha: 0.97),
              _palette.bg0.withValues(alpha: 0.82),
              _palette.bg0.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.62, 1.0],
          ),
        ),
      ),
    );
  }
}

/// A small diamond of a tree's light, beside its name.
class _Lozenge extends StatelessWidget {
  const _Lozenge({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: 0.785398,
    child: Container(width: 6, height: 6, color: color),
  );
}

/// The balance, framed like the lab's readouts. Opens the progress overview.
class _PointsReadout extends StatelessWidget {
  const _PointsReadout({required this.points, required this.onTap});
  final int points;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: _palette.line.withValues(alpha: 0.85),
          bracketSize: 8,
        ),
        child: Container(
          height: 40,
          constraints: const BoxConstraints(minWidth: 68),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          color: _palette.chromeMutedFill(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CustomPaint(
                      painter: SigilPainter(
                        ChartSigil.star,
                        treeLight(ConstellationTree.extraction).essence,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$points',
                    style: _label(15, _palette.ink, spacing: 0.6),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text('POINTS', style: _label(8.5, _palette.muted, spacing: 1.4)),
            ],
          ),
        ),
      ),
    );
  }
}

/// One tree's tab: its name, and how much of it is lit. The chosen one is
/// framed in the tree's light.
class _TreeTab extends StatelessWidget {
  const _TreeTab({
    required this.label,
    required this.accent,
    required this.progress,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final (int, int) progress;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (unlocked, total) = progress;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: selected ? accent : _palette.line.withValues(alpha: 0.7),
          bracketSize: 8,
          strokeWidth: selected ? 1.3 : 1,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          color: selected
              ? _palette.accentWash(accent, darkAlpha: 0.16)
              : _palette.chromeMutedFill(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: _label(
                  12,
                  selected ? _palette.ink : _palette.muted,
                  spacing: 1.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$unlocked / $total',
                style: _label(
                  10,
                  selected ? accent : _palette.muted.withValues(alpha: 0.8),
                  spacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartDialogText extends StatelessWidget {
  const _ChartDialogText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: bracketText(
      context,
      13.5,
      _palette.ink.withValues(alpha: 0.9),
    ).copyWith(height: 1.45),
  );
}

/// One line of a dialog's how-to: a glyph, a heading and a sentence.
class _ChartDialogStep extends StatelessWidget {
  const _ChartDialogStep({
    required this.sigil,
    required this.title,
    required this.body,
  });

  final ChartSigil sigil;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final accent = treeLight(ConstellationTree.breeder).essence;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: SizedBox(
            width: 14,
            height: 14,
            child: CustomPaint(painter: SigilPainter(sigil, accent)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _label(11, _palette.ink)),
              const SizedBox(height: 3),
              Text(
                body,
                style: bracketText(
                  context,
                  12.5,
                  _palette.muted,
                ).copyWith(height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
