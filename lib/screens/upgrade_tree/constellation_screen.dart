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

class ConstellationScreen extends StatefulWidget {
  const ConstellationScreen({super.key});

  @override
  State<ConstellationScreen> createState() => _ConstellationScreenState();
}

class _ConstellationScreenState extends State<ConstellationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ConstellationTree _selectedTree = ConstellationTree.breeder;
  ConstellationGame? _game;
  bool _gameInitialized = false;
  bool _finaleHandled =
      false; // Track if we've checked/played finale this session

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: 1, // <-- start on middle tab (BREEDER)
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _gameInitialized) {
        final newTree = _getTreeForIndex(_tabController.index);
        if (newTree != _selectedTree) {
          setState(() {
            _selectedTree = newTree;
          });
          _game?.transitionToTree(newTree);
        }
      }
    });
    // Check and show constellation tutorial once after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowConstellationTutorial();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  ConstellationTree _getTreeForIndex(int index) {
    switch (index) {
      case 0:
        return ConstellationTree.combat; // left tab
      case 1:
        return ConstellationTree.breeder; // middle tab
      case 2:
        return ConstellationTree.extraction; // right tab
      default:
        return ConstellationTree.breeder;
    }
  }

  // Tutorial state
  bool _constellationTutorialChecked = false;

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
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: theme.primary.withValues(alpha: 0.3)),
          ),
          title: Row(
            children: [
              Icon(Icons.auto_awesome, color: theme.primary),
              const SizedBox(width: 8),
              Text(
                'Constellations 101',
                style: TextStyle(
                  color: theme.text,
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
                'Earn constellation points, spend them to unlock powerful skills, and explore three trees: Breeder, Combat and Extraction.',
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              TutorialStep(
                theme: theme,
                icon: Icons.bolt,
                title: 'Earn Points',
                body: 'Breed creatures and complete milestones to gain points.',
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
  }

  String _getTreeName(ConstellationTree tree) {
    switch (tree) {
      case ConstellationTree.breeder:
        return 'BREEDER';
      case ConstellationTree.combat:
        return 'COMBAT';
      case ConstellationTree.extraction:
        return 'EXTRACTION';
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<int>(
        stream: constellationService.watchPointBalance(),
        builder: (context, pointsSnapshot) {
          final points = pointsSnapshot.data ?? 0;

          return StreamBuilder<Set<String>>(
            stream: constellationService.watchUnlockedSkillIds(),
            builder: (context, unlockedSnapshot) {
              final unlockedSkills = unlockedSnapshot.data ?? {};

              // Initialize game only once with all trees
              if (_game == null) {
                _game = ConstellationGame(
                  selectedTree: _selectedTree,
                  unlockedSkills: unlockedSkills,
                  onSkillTapped: (skill) =>
                      _handleSkillTap(context, skill, constellationService),
                  primaryColor: theme.primary,
                  secondaryColor: theme.secondary,
                );
                _gameInitialized = true;

                // Check if we need to handle the finale after the game loads
                Future.delayed(const Duration(milliseconds: 500), () {
                  _checkAndHandleFinale(unlockedSkills, constellationService);
                });
              } else {
                // Update existing game with new unlocks
                _game!.updateUnlockedSkills(unlockedSkills);

                // Check finale whenever unlocks change
                _checkAndHandleFinale(unlockedSkills, constellationService);
              }

              return Stack(
                children: [
                  // Flame game - now persistent across tree switches
                  GameWidget(game: _game!),

                  // UI Overlay
                  SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        _buildHeader(theme, points, unlockedSkills),
                        _buildTreeSelector(theme, unlockedSkills),
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
      padding: const EdgeInsets.fromLTRB(4, 10, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.95),
            Colors.black.withValues(alpha: 0.75),
            Colors.transparent,
          ],
          stops: const [0.0, 0.65, 1.0],
        ),
        border: Border(
          bottom: BorderSide(
            color: theme.primary.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => VoidPortal.pop(context),
            icon: Icon(
              Icons.arrow_back_ios_rounded,
              color: Colors.white70,
              size: 18,
            ),
          ),
          // Title + overall progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONSTELLATION ALCHEMY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      '$unlocked / $total',
                      style: TextStyle(
                        color: theme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'skills',
                      style: TextStyle(
                        color: theme.textMuted,
                        fontSize: 10,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: theme.primary.withValues(
                            alpha: 0.12,
                          ),
                          valueColor: AlwaysStoppedAnimation(
                            theme.primary.withValues(alpha: 0.7),
                          ),
                          minHeight: 3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Skills list button
          IconButton(
            onPressed: () =>
                _showUnlockedSkillsSheet(context, theme, unlockedSkills),
            icon: Icon(Icons.grid_view_rounded, color: theme.primary, size: 20),
          ),
          // Points display
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ConstellationProgressOverviewScreen(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.primary.withValues(alpha: 0.22),
                    theme.secondary.withValues(alpha: 0.12),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.primary.withValues(alpha: 0.55),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.primary.withValues(alpha: 0.18),
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$points',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'pts',
                    style: TextStyle(
                      color: theme.primary.withValues(alpha: 0.8),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeSelector(FactionTheme theme, Set<String> unlockedSkills) {
    final combatProgress = _getTreeProgress(
      ConstellationTree.combat,
      unlockedSkills,
    );
    final breederProgress = _getTreeProgress(
      ConstellationTree.breeder,
      unlockedSkills,
    );
    final extractionProgress = _getTreeProgress(
      ConstellationTree.extraction,
      unlockedSkills,
    );

    Widget treeTab(String label, IconData icon, (int, int) progress) {
      final (unlocked, total) = progress;
      return Tab(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14),
              const SizedBox(height: 2),
              Text(label),
              const SizedBox(height: 3),
              SizedBox(
                width: 40,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: total > 0 ? unlocked / total : 0,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(
                      theme.primary.withValues(alpha: 0.7),
                    ),
                    minHeight: 2.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.border.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.primary.withValues(alpha: 0.28),
              theme.secondary.withValues(alpha: 0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.primary.withValues(alpha: 0.45),
            width: 1.5,
          ),
        ),
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: theme.textMuted,
        labelStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.9,
        ),
        tabs: [
          treeTab('COMBAT', Icons.shield_outlined, combatProgress),
          treeTab('BREEDER', Icons.biotech_outlined, breederProgress),
          treeTab('EXPLORER', Icons.diamond_outlined, extractionProgress),
        ],
      ),
    );
  }

  Widget _buildTreeInfo(FactionTheme theme, Set<String> unlockedSkills) {
    final (treeUnlocked, treeTotal) = _getTreeProgress(
      _selectedTree,
      unlockedSkills,
    );
    final treeProgress = treeTotal > 0 ? treeUnlocked / treeTotal : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.92),
            Colors.black.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thin top accent bar that looks like an energy meter
            Stack(
              children: [
                Container(
                  height: 3,
                  color: theme.primary.withValues(alpha: 0.1),
                ),
                FractionallySizedBox(
                  widthFactor: treeProgress,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.primary.withValues(alpha: 0.4),
                          theme.primary,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  // Tree icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.primary.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      _getTreeIcon(_selectedTree),
                      color: theme.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Tree name + description + progress
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              _getTreeName(_selectedTree),
                              style: TextStyle(
                                color: theme.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '$treeUnlocked / $treeTotal',
                              style: TextStyle(
                                color: theme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              ' skills',
                              style: TextStyle(
                                color: theme.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getTreeDescription(_selectedTree),
                          style: TextStyle(
                            color: theme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Hint button
                  GestureDetector(
                    onTap: () => _showEarnPointsDialog(theme),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: theme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Icon(
                        Icons.lightbulb_outline,
                        color: theme.primary,
                        size: 17,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEarnPointsDialog(FactionTheme theme) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.isDark ? const Color(0xFF0E1118) : theme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.primary.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Earn Skill Points',
                      style: TextStyle(
                        color: theme.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Extract Alchemons to earn skill points.',
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Got It!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
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
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: theme.isDark ? const Color(0xFF0E1118) : theme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: theme.border),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header - more compact
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'UNLOCKED SKILLS',
                            style: TextStyle(
                              color: theme.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${unlockedSkills.length} of ${ConstellationCatalog.allSkills.length} total',
                            style: TextStyle(
                              color: theme.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: theme.textMuted, size: 20),
                      padding: EdgeInsets.all(8),
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Skills list
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  children: [
                    if (breederSkills.isNotEmpty) ...[
                      _buildTreeSection(
                        'BREEDER',
                        'Genetics & Breeding Mastery',
                        breederSkills,
                        theme,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (combatSkills.isNotEmpty) ...[
                      _buildTreeSection(
                        'COMBAT',
                        'Combat & Boss Battles',
                        combatSkills,
                        theme,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (extractionSkills.isNotEmpty) ...[
                      _buildTreeSection(
                        'EXTRACTION',
                        'Resources & Convenience',
                        extractionSkills,
                        theme,
                      ),
                    ],
                    if (unlockedSkills.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(48),
                          child: Column(
                            children: [
                              Icon(
                                Icons.lock_outline,
                                size: 64,
                                color: theme.textMuted.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No skills unlocked yet',
                                style: TextStyle(
                                  color: theme.textMuted,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Start unlocking skills to see them here',
                                style: TextStyle(
                                  color: theme.textMuted.withValues(alpha: 0.7),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header - more compact
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.primary.withValues(alpha: 0.15),
                theme.secondary.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: theme.primary.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: theme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${skills.length})',
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Skills cards - much more compact
        ...skills.map(
          (skill) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.primary.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.border.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Smaller icon
                  Icon(Icons.check_circle, color: theme.primary, size: 16),
                  const SizedBox(width: 10),

                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          skill.name,
                          style: TextStyle(
                            color: theme.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          skill.description,
                          style: TextStyle(
                            color: theme.textMuted,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Smaller tier badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'T${skill.tier}',
                      style: TextStyle(
                        color: theme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.isDark ? const Color(0xFF0E1118) : theme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUnlocked
                  ? theme.primary.withValues(alpha: 0.45)
                  : theme.border.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isUnlocked
                    ? theme.primary.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                spreadRadius: 2,
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
                          ? theme.primary.withValues(alpha: 0.2)
                          : theme.textMuted.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isUnlocked ? Icons.check_circle : Icons.lock_outline,
                      color: isUnlocked ? theme.primary : theme.textMuted,
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
                          style: TextStyle(
                            color: theme.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'TIER ${skill.tier}  •  ${skill.pointsCost} pts',
                            style: TextStyle(
                              color: theme.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              Container(height: 1, color: theme.border.withValues(alpha: 0.3)),
              const SizedBox(height: 14),

              // Description
              Text(
                skill.description,
                style: TextStyle(
                  color: theme.textMuted,
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
                    color: theme.primary,
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
                          color: theme.primary.withValues(alpha: 0.6),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          prereq?.name ?? prereqId,
                          style: TextStyle(
                            color: theme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: theme.primary.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: theme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  child: Text(
                    'CLOSE',
                    style: TextStyle(
                      color: theme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
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
            color: theme.isDark ? const Color(0xFF0E1118) : theme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.primary.withValues(alpha: 0.45),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.primary.withValues(alpha: 0.2),
                blurRadius: 24,
                spreadRadius: 2,
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
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'TIER ${skill.tier}',
                    style: TextStyle(
                      color: theme.primary.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              Container(height: 1, color: theme.border.withValues(alpha: 0.3)),
              const SizedBox(height: 14),

              Text(
                skill.description,
                style: TextStyle(
                  color: theme.textMuted,
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
                  gradient: LinearGradient(
                    colors: [
                      theme.primary.withValues(alpha: 0.15),
                      theme.secondary.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '${skill.pointsCost} skill points',
                      style: TextStyle(
                        color: theme.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'COST',
                      style: TextStyle(
                        color: theme.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
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
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: theme.border.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      child: Text(
                        'CANCEL',
                        style: TextStyle(
                          color: theme.textMuted,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        final success = await service.unlockSkill(skill.id);
                        if (context.mounted) {
                          Navigator.pop(context);

                          if (success) {
                            HapticFeedback.heavyImpact();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'UNLOCK',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
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
