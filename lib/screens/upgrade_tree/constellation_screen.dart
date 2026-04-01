// lib/screens/constellation_screen.dart
import 'package:alchemons/games/constellations/constellation_game.dart';
import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/screens/progress_overview_screen.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/services/constellation_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/widgets/tutorial_step.dart';

class _ConstellationPalette {
  static const bg0 = Color(0xFF080A0E);
  static const bg1 = Color(0xFF0E1117);
  static const bg2 = Color(0xFF141820);
  static const bg3 = Color(0xFF1C2230);
  static const border = Color(0xFF252D3A);
  static const borderSoft = Color(0xFF3A3020);
  static const text = Color(0xFFE8DCC8);
  static const textSoft = Color(0xFFD7E1EA);
  static const textMuted = Color(0xFFC2B39D);
  static const teal = Color(0xFF0EA5E9);
  static const success = Color(0xFF16A34A);
}

class ConstellationScreen extends StatefulWidget {
  const ConstellationScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _primeConstellationTutorialFlow();
    });
  }

  @override
  void dispose() {
    super.dispose();
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ConstellationProgressOverviewScreen(),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unlock Cross-Species Lineage to continue.'),
        behavior: SnackBarBehavior.floating,
      ),
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

    final theme = context.read<FactionTheme>();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _ConstellationPalette.bg1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: _ConstellationPalette.border),
          ),
          title: Row(
            children: [
              Icon(Icons.auto_awesome, color: theme.primary),
              const SizedBox(width: 8),
              Text(
                'Constellations',
                style: TextStyle(
                  color: _ConstellationPalette.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Earn constellation points, spend them to unlock powerful skills, and reveal three trees in order: Alchemy, Explorer, then Combat.',
                style: TextStyle(
                  color: _ConstellationPalette.textSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              TutorialStep(
                theme: theme,
                icon: Icons.bolt,
                title: 'Earn Points',
                body: 'Fuse creatures and complete milestones to gain points.',
              ),
              const SizedBox(height: 6),
              TutorialStep(
                theme: theme,
                icon: Icons.lock_open,
                title: 'Unlock Skills',
                body:
                    'Spend points to unlock nodes that boost breeding, combat, or extraction.',
              ),
              const SizedBox(height: 6),
              TutorialStep(
                theme: theme,
                icon: Icons.explore_rounded,
                title: 'Explore Trees',
                body:
                    'Switch tabs to view each tree and plan your progression.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await settings.setConstellationTutorialSeen();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text(
                'Got it',
                style: TextStyle(
                  color: theme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
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

  IconData _getTreeIcon(ConstellationTree tree) {
    switch (tree) {
      case ConstellationTree.breeder:
        return Icons.biotech_outlined;
      case ConstellationTree.combat:
        return Icons.shield_outlined;
      case ConstellationTree.extraction:
        return Icons.diamond_outlined;
    }
  }

  Color _getTreeAccentColor(FactionTheme theme, ConstellationTree tree) {
    switch (tree) {
      case ConstellationTree.breeder:
        return _ConstellationPalette.teal;
      case ConstellationTree.combat:
        return theme.primary;
      case ConstellationTree.extraction:
        return theme.secondary;
    }
  }

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
      final label = _getTreeName(tree);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label tree revealed'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _getTreeAccentColor(
            context.read<FactionTheme>(),
            tree,
          ),
        ),
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
    final theme = context.watch<FactionTheme>();
    final constellationService = context.watch<ConstellationService>();

    return PopScope(
      canPop: !_isFirstUnlockLocked,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isFirstUnlockLocked) {
          _showFirstUnlockLockedMessage();
        }
      },
      child: Scaffold(
        backgroundColor: _ConstellationPalette.bg0,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _ConstellationPalette.bg0,
                _ConstellationPalette.bg1,
                _ConstellationPalette.bg0,
              ],
            ),
          ),
          child: StreamBuilder<int>(
            stream: constellationService.watchPointBalance(),
            builder: (context, pointsSnapshot) {
              final points = pointsSnapshot.data ?? 0;

              return StreamBuilder<Set<String>>(
                stream: constellationService.watchUnlockedSkillIds(),
                builder: (context, unlockedSnapshot) {
                  final unlockedSkills = unlockedSnapshot.data ?? {};
                  if (unlockedSnapshot.hasData) {
                    _syncTreeAvailability(unlockedSkills);
                    if (_isFirstUnlockLocked &&
                        unlockedSkills.contains(_firstUnlockSkillId)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _completeFirstUnlockGuidance();
                      });
                    }
                  }

                  if (_game == null) {
                    _game = ConstellationGame(
                      selectedTree: _selectedTree,
                      unlockedSkills: unlockedSkills,
                      visibleTrees: _availableTrees,
                      onSkillTapped: (skill) =>
                          _handleSkillTap(context, skill, constellationService),
                      primaryColor: theme.primary,
                      secondaryColor: theme.secondary,
                      tutorialLocked: _isFirstUnlockLocked,
                    );
                    _gameInitialized = true;
                    if (_isFirstUnlockLocked) {
                      _focusFirstUnlockNode();
                    }

                    Future.delayed(const Duration(milliseconds: 500), () {
                      _checkAndHandleFinale(
                        unlockedSkills,
                        constellationService,
                      );
                    });
                  } else {
                    _game!.tutorialLocked = _isFirstUnlockLocked;
                    _game!.updateUnlockedSkills(unlockedSkills);
                    _game!.setVisibleTrees(_availableTrees);
                    if (_isFirstUnlockLocked) {
                      _focusFirstUnlockNode();
                    }
                    _checkAndHandleFinale(unlockedSkills, constellationService);
                  }

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: const Alignment(0, -0.35),
                                radius: 1.05,
                                colors: [
                                  theme.primary.withValues(alpha: 0.12),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(child: GameWidget(game: _game!)),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  _ConstellationPalette.bg0.withValues(
                                    alpha: 0.8,
                                  ),
                                  Colors.transparent,
                                  Colors.transparent,
                                  _ConstellationPalette.bg0.withValues(
                                    alpha: 0.92,
                                  ),
                                ],
                                stops: const [0.0, 0.18, 0.62, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SafeArea(
                        bottom: false,
                        child: Column(
                          children: [
                            _buildHeader(theme, points, unlockedSkills),
                            _buildTreeSelector(theme, unlockedSkills),
                            if (_isFirstUnlockLocked)
                              _buildFirstUnlockBanner(theme),
                            const Spacer(),
                            _buildTreeInfo(theme, unlockedSkills),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFirstUnlockBanner(FactionTheme theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _ConstellationPalette.bg1.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.primary.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.touch_app_rounded, color: theme.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FIRST UNLOCK',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: theme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tap Cross-Species Lineage and unlock it to continue.',
                  style: TextStyle(
                    color: _ConstellationPalette.textSoft,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    FactionTheme theme,
    int points,
    Set<String> unlockedSkills,
  ) {
    final total = ConstellationCatalog.allSkills.length;
    final unlocked = unlockedSkills.length;
    final progress = total > 0 ? unlocked / total : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 9),
      decoration: BoxDecoration(
        color: _ConstellationPalette.bg1.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _ConstellationPalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _ConstellationIconButton(
                theme: theme,
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: _isFirstUnlockLocked
                    ? _showFirstUnlockLockedMessage
                    : () => VoidPortal.pop(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONSTELLATION ALCHEMY',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: _ConstellationPalette.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _ConstellationIconButton(
                theme: theme,
                icon: Icons.grid_view_rounded,
                onTap: () =>
                    _showUnlockedSkillsSheet(context, theme, unlockedSkills),
              ),
              const SizedBox(width: 8),
              _ConstellationPointsButton(
                theme: theme,
                points: points,
                onTap: _openProgressOverview,
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Text(
                '$unlocked / $total',
                style: TextStyle(
                  color: theme.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'skills',
                style: TextStyle(
                  color: _ConstellationPalette.textMuted,
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  color: _ConstellationPalette.teal,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: _ConstellationPalette.bg3,
                    valueColor: AlwaysStoppedAnimation(theme.primary),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTreeSelector(FactionTheme theme, Set<String> unlockedSkills) {
    const allTrees = [
      ConstellationTree.combat,
      ConstellationTree.breeder,
      ConstellationTree.extraction,
    ];
    final trees = allTrees.where(_availableTrees.contains).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _ConstellationPalette.bg1.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _ConstellationPalette.border),
      ),
      child: Row(
        children: List.generate(trees.length, (index) {
          final tree = trees[index];
          final progress = _getTreeProgress(tree, unlockedSkills);
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? 0 : 4,
                right: index == trees.length - 1 ? 0 : 4,
              ),
              child: _ConstellationTreeButton(
                theme: theme,
                label: _getTreeName(tree),
                icon: _getTreeIcon(tree),
                accent: _getTreeAccentColor(theme, tree),
                progress: progress,
                selected: _selectedTree == tree,
                onTap: () => _handleTreeTap(tree),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTreeInfo(FactionTheme theme, Set<String> unlockedSkills) {
    final accent = _getTreeAccentColor(theme, _selectedTree);
    final (treeUnlocked, treeTotal) = _getTreeProgress(
      _selectedTree,
      unlockedSkills,
    );
    final treeProgress = treeTotal > 0 ? treeUnlocked / treeTotal : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      decoration: BoxDecoration(
        color: _ConstellationPalette.bg1.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _ConstellationPalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: accent.withValues(alpha: 0.35)),
                  ),
                  child: Icon(_getTreeIcon(_selectedTree), color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getTreeName(_selectedTree),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getTreeDescription(_selectedTree),
                        style: TextStyle(
                          color: _ConstellationPalette.textMuted,
                          fontSize: 10,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _ConstellationIconButton(
                  theme: theme,
                  icon: Icons.lightbulb_outline_rounded,
                  onTap: () => _showEarnPointsDialog(theme),
                  iconColor: accent,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '$treeUnlocked / $treeTotal',
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  ' skills',
                  style: TextStyle(
                    color: _ConstellationPalette.textMuted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  treeUnlocked == treeTotal ? 'MAXED' : 'ACTIVE',
                  style: TextStyle(
                    color: treeUnlocked == treeTotal
                        ? _ConstellationPalette.success
                        : _ConstellationPalette.teal,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: treeProgress,
                      minHeight: 4,
                      backgroundColor: _ConstellationPalette.bg3,
                      valueColor: AlwaysStoppedAnimation(accent),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEarnPointsDialog(FactionTheme theme) {
    if (_isFirstUnlockLocked) {
      _showFirstUnlockLockedMessage();
      return;
    }
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _ConstellationPalette.bg1,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _ConstellationPalette.borderSoft),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EARN CONSTELLATION POINTS',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: theme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              Container(height: 1, color: _ConstellationPalette.border),
              const SizedBox(height: 16),
              Text(
                'Fuse creatures and complete their milestone progress to earn constellation points. Spend those points here to unlock passive upgrades across the sky map.',
                style: TextStyle(
                  color: _ConstellationPalette.textSoft,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              _ConstellationInlineHint(
                theme: theme,
                icon: Icons.egg_alt_outlined,
                label:
                    'Fusion milestones award the points, not extraction taps.',
              ),
              const SizedBox(height: 20),
              _ConstellationDialogButton(
                theme: theme,
                label: 'GOT IT',
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUnlockedSkillsSheet(
    BuildContext context,
    FactionTheme theme,
    Set<String> unlockedSkills,
  ) {
    if (_isFirstUnlockLocked) {
      _showFirstUnlockLockedMessage();
      return;
    }
    // Organize skills by tree
    final breederSkills = <ConstellationSkill>[];
    final combatSkills = <ConstellationSkill>[];
    final extractionSkills = <ConstellationSkill>[];

    for (final skillId in unlockedSkills) {
      final skill = ConstellationCatalog.byId(skillId);
      if (skill != null) {
        switch (skill.tree) {
          case ConstellationTree.breeder:
            breederSkills.add(skill);
            break;
          case ConstellationTree.combat:
            combatSkills.add(skill);
            break;
          case ConstellationTree.extraction:
            extractionSkills.add(skill);
            break;
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: _ConstellationPalette.bg1,
            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            border: Border.fromBorderSide(
              BorderSide(color: _ConstellationPalette.border),
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _ConstellationPalette.textMuted.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'UNLOCKED SKILLS',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: _ConstellationPalette.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${unlockedSkills.length} of ${ConstellationCatalog.allSkills.length} total',
                            style: TextStyle(
                              color: _ConstellationPalette.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _ConstellationInlineBadge(
                      label:
                          '${unlockedSkills.length}/${ConstellationCatalog.allSkills.length}',
                      color: theme.primary,
                    ),
                    const SizedBox(width: 8),
                    _ConstellationIconButton(
                      theme: theme,
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    if (breederSkills.isNotEmpty) ...[
                      _buildTreeSection(
                        'ALCHEMY',
                        'Genetics & Breeding Mastery',
                        breederSkills,
                        theme,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (combatSkills.isNotEmpty) ...[
                      _buildTreeSection(
                        'COMBAT',
                        'Combat & Boss Battles',
                        combatSkills,
                        theme,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (extractionSkills.isNotEmpty) ...[
                      _buildTreeSection(
                        'EXPLORER',
                        'Resources & Convenience',
                        extractionSkills,
                        theme,
                      ),
                    ],
                    if (unlockedSkills.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _ConstellationPalette.bg2,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _ConstellationPalette.border,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 42,
                              color: _ConstellationPalette.textMuted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No skills unlocked yet',
                              style: TextStyle(
                                color: _ConstellationPalette.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Unlock nodes in the constellation trees to see them listed here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _ConstellationPalette.textSoft,
                                fontSize: 12,
                                height: 1.4,
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
    );
  }

  Widget _buildTreeSection(
    String title,
    String subtitle,
    List<ConstellationSkill> skills,
    FactionTheme theme,
  ) {
    final sectionTree = switch (title) {
      'COMBAT' => ConstellationTree.combat,
      'EXPLORER' => ConstellationTree.extraction,
      _ => ConstellationTree.breeder,
    };
    final accent = _getTreeAccentColor(theme, sectionTree);

    return Container(
      decoration: BoxDecoration(
        color: _ConstellationPalette.bg2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _ConstellationPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: _ConstellationPalette.bg3,
              borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
            ),
            child: Row(
              children: [
                Container(width: 3, height: 12, color: accent),
                const SizedBox(width: 8),
                Text(
                  '$title • ${skills.length}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _ConstellationPalette.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 10),
                ...skills.map(
                  (skill) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _ConstellationPalette.bg3,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _ConstellationPalette.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: accent,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  skill.name,
                                  style: const TextStyle(
                                    color: _ConstellationPalette.text,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  skill.description,
                                  style: const TextStyle(
                                    color: _ConstellationPalette.textSoft,
                                    fontSize: 11,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _ConstellationInlineBadge(
                            label: 'T${skill.tier}',
                            color: accent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

    final theme = context.read<FactionTheme>();
    final isUnlocked = await service.isSkillUnlocked(skill.id);
    final canUnlock = await service.canUnlockSkill(skill.id);
    if (!context.mounted) return;

    if (isUnlocked) {
      // Show info about unlocked skill
      _showSkillInfoDialog(context, skill, theme, isUnlocked: true);
    } else if (canUnlock) {
      // Show unlock confirmation
      _showUnlockDialog(context, skill, theme, service);
    } else {
      // Show why it's locked
      _showSkillInfoDialog(context, skill, theme, isUnlocked: false);
    }
  }

  void _showSkillInfoDialog(
    BuildContext context,
    ConstellationSkill skill,
    FactionTheme theme, {
    required bool isUnlocked,
  }) {
    final accent = isUnlocked ? theme.primary : _ConstellationPalette.textSoft;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _ConstellationPalette.bg1,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isUnlocked
                  ? theme.primary.withValues(alpha: 0.35)
                  : _ConstellationPalette.border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isUnlocked
                          ? theme.primary.withValues(alpha: 0.14)
                          : _ConstellationPalette.bg3,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      isUnlocked ? Icons.check_circle : Icons.lock_outline,
                      color: isUnlocked
                          ? theme.primary
                          : _ConstellationPalette.textSoft,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          skill.name,
                          style: const TextStyle(
                            color: _ConstellationPalette.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _ConstellationInlineBadge(
                          label: 'T${skill.tier} • ${skill.pointsCost} PTS',
                          color: accent,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              Container(height: 1, color: _ConstellationPalette.border),
              const SizedBox(height: 14),

              // Description
              Text(
                skill.description,
                style: const TextStyle(
                  color: _ConstellationPalette.textSoft,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),

              // Prerequisites section
              if (!isUnlocked && skill.prerequisites.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'PREREQUISITES',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                ...skill.prerequisites.map((prereqId) {
                  final prereq = ConstellationCatalog.byId(prereqId);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        Icon(
                          Icons.chevron_right,
                          color: accent.withValues(alpha: 0.7),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          prereq?.name ?? prereqId,
                          style: const TextStyle(
                            color: _ConstellationPalette.textSoft,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 20),

              _ConstellationDialogButton(
                theme: theme,
                label: 'CLOSE',
                onTap: () => Navigator.pop(context),
                accent: accent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUnlockDialog(
    BuildContext context,
    ConstellationSkill skill,
    FactionTheme theme,
    ConstellationService service,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _ConstellationPalette.bg1,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _ConstellationPalette.borderSoft),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    skill.name,
                    style: const TextStyle(
                      color: _ConstellationPalette.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  _ConstellationInlineBadge(
                    label: 'T${skill.tier}',
                    color: theme.primary,
                  ),
                ],
              ),

              const SizedBox(height: 14),
              Container(height: 1, color: _ConstellationPalette.border),
              const SizedBox(height: 14),

              Text(
                skill.description,
                style: const TextStyle(
                  color: _ConstellationPalette.textSoft,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 16),

              // Cost badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _ConstellationPalette.bg3,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _ConstellationPalette.borderSoft),
                ),
                child: Row(
                  children: [
                    Text(
                      '${skill.pointsCost} skill points',
                      style: const TextStyle(
                        color: _ConstellationPalette.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'COST',
                      style: TextStyle(
                        color: theme.primary,
                        fontFamily: 'monospace',
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: _ConstellationDialogButton(
                      theme: theme,
                      label: 'CANCEL',
                      onTap: () => Navigator.pop(context),
                      filled: false,
                      accent: _ConstellationPalette.textSoft,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _ConstellationDialogButton(
                      theme: theme,
                      label: 'UNLOCK',
                      onTap: () async {
                        final settingsDao = context
                            .read<AlchemonsDatabase>()
                            .settingsDao;
                        final success = await service.unlockSkill(skill.id);
                        if (success && skill.id == _firstUnlockSkillId) {
                          await settingsDao
                              .clearConstellationFirstUnlockPending();
                        }
                        if (context.mounted) {
                          Navigator.pop(context);

                          if (success) {
                            HapticFeedback.heavyImpact();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Unlocked: ${skill.name}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: theme.primary,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Not enough skill points'),
                                backgroundColor: Colors.red.shade800,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          }
                        }
                      },
                      accent: theme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConstellationIconButton extends StatelessWidget {
  final FactionTheme theme;
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const _ConstellationIconButton({
    required this.theme,
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _ConstellationPalette.bg2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _ConstellationPalette.border),
        ),
        child: Icon(
          icon,
          color: iconColor ?? _ConstellationPalette.text,
          size: 16,
        ),
      ),
    );
  }
}

class _ConstellationPointsButton extends StatelessWidget {
  final FactionTheme theme;
  final int points;
  final VoidCallback onTap;

  const _ConstellationPointsButton({
    required this.theme,
    required this.points,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _ConstellationPalette.bg2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _ConstellationPalette.borderSoft),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$points',
              style: const TextStyle(
                color: _ConstellationPalette.text,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            Text(
              'PTS',
              style: TextStyle(
                fontFamily: 'monospace',
                color: theme.primary,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConstellationInlineBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _ConstellationInlineBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _ConstellationPalette.bg2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ConstellationTreeButton extends StatelessWidget {
  final FactionTheme theme;
  final String label;
  final IconData icon;
  final Color accent;
  final (int, int) progress;
  final bool selected;
  final VoidCallback onTap;

  const _ConstellationTreeButton({
    required this.theme,
    required this.label,
    required this.icon,
    required this.accent,
    required this.progress,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (unlocked, total) = progress;
    final value = total > 0 ? unlocked / total : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.12)
              : _ConstellationPalette.bg2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.6)
                : _ConstellationPalette.border,
            width: selected ? 1.2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.14),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? accent : _ConstellationPalette.textMuted,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                color: selected
                    ? _ConstellationPalette.text
                    : _ConstellationPalette.text,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 3),
            Text(
              '$unlocked / $total',
              style: TextStyle(
                color: selected
                    ? _ConstellationPalette.text
                    : _ConstellationPalette.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 4,
                backgroundColor: _ConstellationPalette.bg3,
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConstellationDialogButton extends StatelessWidget {
  final FactionTheme theme;
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final Color? accent;

  const _ConstellationDialogButton({
    required this.theme,
    required this.label,
    required this.onTap,
    this.filled = true,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = accent ?? theme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: filled
              ? buttonColor.withValues(alpha: 0.16)
              : _ConstellationPalette.bg2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: filled ? buttonColor : _ConstellationPalette.border,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'monospace',
            color: filled
                ? buttonColor
                : (accent ?? _ConstellationPalette.textSoft),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}

class _ConstellationInlineHint extends StatelessWidget {
  final FactionTheme theme;
  final IconData icon;
  final String label;

  const _ConstellationInlineHint({
    required this.theme,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _ConstellationPalette.bg2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _ConstellationPalette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _ConstellationPalette.teal, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _ConstellationPalette.textSoft,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
