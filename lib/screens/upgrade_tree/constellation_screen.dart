// lib/screens/constellation_screen.dart
import 'package:alchemons/games/constellations/constellation_game.dart';
import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/services/constellation_service.dart';
import 'package:alchemons/utils/faction_util.dart';

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
                        _buildTreeSelector(theme),
                        const Spacer(),
                        _buildTreeInfo(theme),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.9),
            Colors.black.withOpacity(0.6),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back, color: Colors.white),
          ),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONSTELLATION ALCHEMY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),

                Text(
                  'Unlock powerful abilities',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () =>
                _showUnlockedSkillsSheet(context, theme, unlockedSkills),
            icon: Icon(Icons.list_alt, color: theme.primary),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.primary.withOpacity(0.3),
                  theme.secondary.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.primary.withOpacity(0.6),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Text(
                  '$points',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeSelector(FactionTheme theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.7)),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.primary.withOpacity(0.3),
              theme.secondary.withOpacity(0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: theme.textMuted,
        labelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
        tabs: const [
          Tab(text: 'COMBAT'), // index 0
          Tab(text: 'BREEDER'), // index 1 (middle)
          Tab(text: 'EXPLORER'), // index 2
        ],
      ),
    );
  }

  Widget _buildTreeInfo(FactionTheme theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.9),
            Colors.black.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 4),
                Text(
                  _getTreeDescription(_selectedTree),
                  style: TextStyle(color: theme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showEarnPointsDialog(theme),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.primary.withOpacity(0.3)),
              ),
              child: Icon(
                Icons.lightbulb_outline,
                color: theme.primary,
                size: 18,
              ),
            ),
          ),
        ],
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
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.black.withOpacity(0.95),
                theme.primary.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.primary.withOpacity(0.5), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.stars, color: theme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
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
            color: theme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  color: theme.textMuted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header - more compact
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    Icon(Icons.stars, color: theme.primary, size: 24),
                    const SizedBox(width: 10),
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
                                color: theme.textMuted.withOpacity(0.3),
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
                                  color: theme.textMuted.withOpacity(0.7),
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
                theme.primary.withOpacity(0.15),
                theme.secondary.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: theme.primary.withOpacity(0.25),
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
                color: theme.primary.withOpacity(0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.border.withOpacity(0.2),
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
                      color: theme.primary.withOpacity(0.12),
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
      builder: (context) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.border),
        ),
        title: Row(
          children: [
            Icon(
              isUnlocked ? Icons.check_circle : Icons.lock,
              color: isUnlocked ? theme.primary : theme.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                skill.name,
                style: TextStyle(
                  color: theme.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              skill.description,
              style: TextStyle(color: theme.textMuted, fontSize: 13),
            ),
            if (!isUnlocked && skill.prerequisites.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Prerequisites:',
                style: TextStyle(
                  color: theme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ...skill.prerequisites.map((prereqId) {
                final prereq = ConstellationCatalog.byId(prereqId);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_right, color: theme.textMuted, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        prereq?.name ?? prereqId,
                        style: TextStyle(color: theme.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CLOSE', style: TextStyle(color: theme.primary)),
          ),
        ],
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
      builder: (context) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.border),
        ),
        title: Text(
          'Unlock ${skill.name}?',
          style: TextStyle(
            color: theme.text,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              skill.description,
              style: TextStyle(color: theme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: theme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Cost: ${skill.pointsCost} points',
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: TextStyle(color: theme.textMuted)),
          ),
          ElevatedButton(
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
                          Icon(Icons.check_circle, color: Colors.white),
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
                      content: Text('Failed to unlock skill'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('UNLOCK'),
          ),
        ],
      ),
    );
  }
}
