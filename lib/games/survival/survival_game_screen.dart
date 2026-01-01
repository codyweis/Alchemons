// lib/games/survival/survival_game_screen.dart
//
// UPDATED SURVIVAL GAME SCREEN
// Integrates the deployment phase overlay before starting the game.
//
// CHANGES FROM ORIGINAL:
// 1. Added DeploymentPhaseOverlay between party selection and game start
// 2. Players now choose WHERE to place their initial 4 creatures
// 3. Remaining creatures go to reserves automatically
//

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/survival/components/debug_teams_picker.dart';
import 'package:alchemons/games/survival/components/deployment_phase_overlay.dart';
import 'package:alchemons/games/survival/survival_engine.dart';
import 'package:alchemons/games/survival/survival_party_picker.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/games/survival/survival_game.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
import 'package:alchemons/widgets/creature_sprite.dart';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Game screen states
enum _ScreenState {
  /// Main menu / formation prompt
  menu,

  /// Deployment phase - choosing positions
  deployment,

  /// Active gameplay
  playing,
}

class SurvivalGameScreen extends StatefulWidget {
  const SurvivalGameScreen({super.key});

  @override
  State<SurvivalGameScreen> createState() => _SurvivalGameScreenState();
}

class _SurvivalGameScreenState extends State<SurvivalGameScreen> {
  _ScreenState _screenState = _ScreenState.menu;
  SurvivalHoardGame? _game;
  bool _isLoading = false;

  /// Party members loaded from formation selector
  List<PartyMember>? _loadedParty;

  late final PageController _familyPageController;
  double _familyPage = 0;

  @override
  void initState() {
    super.initState();
    _familyPageController = PageController(viewportFraction: 0.78);
    _familyPageController.addListener(() {
      setState(() {
        _familyPage = _familyPageController.page ?? 0;
      });
    });
  }

  @override
  void dispose() {
    _familyPageController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NAVIGATION METHODS
  // ══════════════════════════════════════════════════════════════════════════

  /// Open formation selector to pick creatures
  Future<void> _openFormationSelector() async {
    final selectedSquad = await Navigator.of(context).push<Map<int, String>>(
      MaterialPageRoute(
        builder: (_) => const SurvivalFormationSelectorScreen(),
      ),
    );

    if (selectedSquad != null && mounted) {
      await _loadPartyAndShowDeployment(selectedSquad);
    }
  }

  /// Load party from selected squad and show deployment phase
  Future<void> _loadPartyAndShowDeployment(
    Map<int, String> selectedSquad,
  ) async {
    if (_isLoading) return;

    // Need at least 4 creatures
    if (selectedSquad.length < 4) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least 4 creatures'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = context.read<AlchemonsDatabase>();
      final catalog = context.read<CreatureCatalog>();

      // Build party from selected squad (simple list of instance IDs)
      final party = await _buildPartyFromSquad(
        squadIds: selectedSquad.values.toList(),
        db: db,
        catalog: catalog,
      );

      if (party.length < 4) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not load all team members'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Store party and transition to deployment phase
      if (mounted) {
        setState(() {
          _loadedParty = party;
          _screenState = _ScreenState.deployment;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading party: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  /// Build party members from a simple list of instance IDs
  Future<List<PartyMember>> _buildPartyFromSquad({
    required List<String> squadIds,
    required AlchemonsDatabase db,
    required CreatureCatalog catalog,
  }) async {
    final List<PartyMember> party = [];

    for (final instanceId in squadIds) {
      final instance = await db.creatureDao.getInstance(instanceId);
      if (instance == null) continue;

      final species = catalog.getCreatureById(instance.baseId);
      if (species == null) continue;

      final combatant = PartyCombatantStats(
        id: instance.instanceId,
        name: instance.nickname ?? species.name,
        types: species.types,
        family: species.mutationFamily!,
        level: instance.level,
        statSpeed: instance.statSpeed,
        statIntelligence: instance.statIntelligence,
        statStrength: instance.statStrength,
        statBeauty: instance.statBeauty,
        sheetDef: sheetFromCreature(species),
        spriteVisuals: visualsFromInstance(species, instance),
      );

      // All creatures start with a default position - deployment phase will assign real positions
      party.add(
        PartyMember(
          combatant: combatant,
          position: FormationPosition.frontLeft,
        ),
      );
    }

    return party;
  }

  /// Called when deployment is confirmed
  void _onDeploymentConfirmed(DeploymentResult result) {
    if (_loadedParty == null) return;

    // Rebuild party with deployment order
    final List<PartyMember> reorderedParty = [];

    // First add deployed creatures in their slot order (these become active)
    for (final deployed in result.deployedCreatures) {
      final originalMember = _loadedParty!.firstWhere(
        (m) => m.combatant.id == deployed.id,
      );

      // Map slot index to formation position
      final formationPosition = _slotToFormationPosition(
        deployed.assignedSlot!,
      );

      reorderedParty.add(
        PartyMember(
          combatant: originalMember.combatant,
          position: formationPosition,
        ),
      );
    }

    // Then add bench creatures
    for (final bench in result.benchCreatures) {
      final originalMember = _loadedParty!.firstWhere(
        (m) => m.combatant.id == bench.id,
      );

      // Bench creatures use backRight position (will be overridden anyway)
      reorderedParty.add(
        PartyMember(
          combatant: originalMember.combatant,
          position: FormationPosition.backRight,
        ),
      );
    }

    // Start the game with reordered party
    setState(() {
      _game = SurvivalHoardGame(
        party: reorderedParty,
        onGameOver: _handleGameOver,
      );
      _screenState = _ScreenState.playing;
    });
  }

  /// Map deployment slot index to formation position
  FormationPosition _slotToFormationPosition(int slotIndex) {
    // Map 8 slots to 4 formation positions
    // Slots 0,1 -> frontLeft
    // Slots 2,3 -> frontRight
    // Slots 4,5 -> backLeft
    // Slots 6,7 -> backRight
    switch (slotIndex % 4) {
      case 0:
        return FormationPosition.frontLeft;
      case 1:
        return FormationPosition.frontRight;
      case 2:
        return FormationPosition.backLeft;
      case 3:
      default:
        return FormationPosition.backRight;
    }
  }

  /// Cancel deployment and return to menu
  void _onDeploymentCancelled() {
    setState(() {
      _loadedParty = null;
      _screenState = _ScreenState.menu;
    });
  }

  /// Debug team picker (bypasses deployment for testing)
  Future<void> _openDebugTeamPicker() async {
    if (_isLoading) return;

    final party = await Navigator.of(context).push<List<PartyMember>>(
      MaterialPageRoute(builder: (_) => const SurvivalDebugTeamPickerScreen()),
    );

    if (party == null || !mounted) return;

    // For debug teams, go directly to deployment
    setState(() {
      _loadedParty = party;
      _screenState = _ScreenState.deployment;
    });
  }

  void _handleGameOver() {
    if (!mounted) return;

    final theme = context.read<FactionTheme>();
    final timeElapsed = _game?.timeElapsed ?? 0;
    final wave = _game?.currentWave ?? 1;
    final score = _game?.score ?? 0;
    final kills = _game?.kills ?? 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            color: const Color(0xF0101018),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withOpacity(0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with glow effect
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF8B5CF6).withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                ),
                child: Column(
                  children: [
                    // Skull/defeat icon
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFEF4444).withOpacity(0.2),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.dangerous_rounded,
                        color: Color(0xFFEF4444),
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'ORB DESTROYED',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Game Over',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              // Stats grid
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Column(
                  children: [
                    // Stats row 1
                    Row(
                      children: [
                        _buildStatBox(
                          icon: Icons.waves_rounded,
                          label: 'WAVE',
                          value: '$wave',
                          color: const Color(0xFF8B5CF6),
                        ),
                        const SizedBox(width: 12),
                        _buildStatBox(
                          icon: Icons.timer_rounded,
                          label: 'TIME',
                          value: _formatTime(timeElapsed),
                          color: const Color(0xFF06B6D4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Stats row 2
                    Row(
                      children: [
                        _buildStatBox(
                          icon: Icons.star_rounded,
                          label: 'SCORE',
                          value: _formatNumber(score),
                          color: const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 12),
                        _buildStatBox(
                          icon: Icons.gps_fixed_rounded,
                          label: 'KILLS',
                          value: _formatNumber(kills),
                          color: const Color(0xFFEF4444),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Divider
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                color: Colors.white.withOpacity(0.1),
              ),

              // Action buttons
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Primary action - Redeploy
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          setState(() {
                            _game = null;
                            _screenState = _ScreenState.deployment;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.replay_rounded, size: 20),
                        label: const Text(
                          'Redeploy',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Secondary actions row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              setState(() {
                                _game = null;
                                _loadedParty = null;
                                _screenState = _ScreenState.menu;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.2),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.groups_rounded, size: 18),
                            label: const Text(
                              'New Team',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.2),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(
                              Icons.exit_to_app_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'Exit',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildStatBox({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color.withOpacity(0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD METHODS
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    switch (_screenState) {
      case _ScreenState.menu:
        return _buildMenuScreen();

      case _ScreenState.deployment:
        return _buildDeploymentScreen();

      case _ScreenState.playing:
        return _buildGameScreen();
    }
  }

  Widget _buildMenuScreen() {
    final theme = context.watch<FactionTheme>();
    return _buildFormationPrompt(theme);
  }

  Widget _buildDeploymentScreen() {
    if (_loadedParty == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final catalog = context.read<CreatureCatalog>();

    return DeploymentPhaseOverlay(
      party: _loadedParty!,
      catalog: catalog,
      onConfirm: _onDeploymentConfirmed,
      onCancel: _onDeploymentCancelled,
    );
  }

  Widget _buildGameScreen() {
    final theme = context.watch<FactionTheme>();
    return _buildGameView(theme);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EXISTING UI BUILDERS (from original file)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildBackButton(FactionTheme theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1a1a2e),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Leave Game?',
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                'Your progress will be lost.',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text('Leave'),
                ),
              ],
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildFormationPrompt(FactionTheme theme) {
    return ParticleBackgroundScaffold(
      body: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(theme),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildFamilyCarousel(theme),
                      const SizedBox(height: 32),
                      _buildMechanicsSection(theme),
                      const SizedBox(height: 32),

                      // Start Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _openFormationSelector,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.accent,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: theme.surface,
                            disabledForegroundColor: theme.textMuted,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.group_rounded, size: 24),
                          label: Text(
                            _isLoading ? 'Preparing...' : 'Assemble Your Team',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: _isLoading ? null : _openDebugTeamPicker,
                          label: const Text(
                            'Pick Prebuilt Team',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.orangeAccent,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(FactionTheme theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: Colors.white,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Survival Mode',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Test your team against endless waves',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsOverlay() {
    return ValueListenableBuilder<SurvivalGameStats>(
      valueListenable: _game!.statsNotifier,
      builder: (context, stats, child) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildStatRow('WAVE', '${stats.wave}', const Color(0xFF8B5CF6)),
              const SizedBox(height: 4),
              _buildStatRow('TIME', stats.formattedTime, Colors.white),
              const SizedBox(height: 4),
              _buildStatRow('SCORE', stats.score.toString(), Colors.amber),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildGameView(FactionTheme theme) {
    return ParticleBackgroundScaffold(
      body: Scaffold(
        backgroundColor: Colors.black.withOpacity(.6),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GameWidget(
                game: _game!,
                backgroundBuilder: (context) =>
                    Container(color: Colors.transparent),
              ),
            ),

            // Alchemical choices overlay (center)
            if (_game != null) _buildAlchemyOverlay(),

            // Stats Overlay (Top Right)
            Align(
              alignment: Alignment.topRight,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, right: 12),
                  child: _buildStatsOverlay(),
                ),
              ),
            ),

            // Top bar (Back Button, Top Left)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [_buildBackButton(theme)]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlchemyOverlay() {
    return ValueListenableBuilder<AlchemyChoiceState?>(
      valueListenable: _game!.alchemyChoiceNotifier,
      builder: (context, state, child) {
        if (state == null) return const SizedBox.shrink();

        final theme = context.watch<FactionTheme>();

        return Container(
          color: Colors.black.withOpacity(0.7),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.surface.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.accent, width: 2),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Column(
                      children: [
                        Text(
                          'Alchemical Surge',
                          style: TextStyle(
                            color: theme.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'CHOOSE YOUR UPGRADE',
                          style: TextStyle(
                            color: theme.textMuted,
                            fontSize: 12,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Option cards
                    ...state.options.map(
                      (opt) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: _AlchemyOptionCard(
                          theme: theme,
                          label: opt.label,
                          description: opt.description,
                          onTap: () => _game!.applyAlchemyChoice(opt),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MENU UI BUILDERS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildMechanicsSection(FactionTheme theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: theme.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'How It Works',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMechanicItem(
            theme,
            Icons.map_rounded,
            'Strategic Deployment',
            'Choose where to place your guardians before battle begins',
          ),
          const SizedBox(height: 12),
          _buildMechanicItem(
            theme,
            Icons.waves_rounded,
            'Endless Waves',
            'Enemies spawn continuously with increasing difficulty',
          ),
          const SizedBox(height: 12),
          _buildMechanicItem(
            theme,
            Icons.auto_awesome_rounded,
            'Alchemical Upgrades',
            'Power up your team as you defeat enemies and deploy more Alchemons!',
          ),
        ],
      ),
    );
  }

  Widget _buildMechanicItem(
    FactionTheme theme,
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: theme.accent, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: theme.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFamilyCarousel(FactionTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Alchemon Species',
              style: TextStyle(
                color: theme.text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Each species has a distinct role and shines with different powerups.',
          style: TextStyle(color: theme.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 230,
          child: PageView.builder(
            controller: _familyPageController,
            itemCount: _familyInfos.length,
            itemBuilder: (context, index) {
              final info = _familyInfos[index];
              final distance = (index - _familyPage).abs().clamp(0.0, 1.0);
              final scale = 1.0 - (0.08 * distance);
              final opacity = 1.0 - (0.4 * distance);

              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: _buildFamilyCard(theme, info),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Page indicator dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_familyInfos.length, (index) {
            final isActive = (index - _familyPage).abs() < 0.5;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              width: isActive ? 20 : 8,
              decoration: BoxDecoration(
                color: isActive ? theme.accent : theme.accent.withOpacity(0.35),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildFamilyCard(FactionTheme theme, _FamilyInfo info) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.accent.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: theme.accent.withOpacity(0.35),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Silhouetted sprite with mystical aurora
          Expanded(
            flex: 4,
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Aurora glow
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          theme.accent.withOpacity(0.7),
                          theme.accent.withOpacity(0.1),
                          Colors.transparent,
                        ],
                        stops: const [0.2, 0.7, 1.0],
                      ),
                    ),
                  ),
                  // Outer orbit ring
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.accent.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                  ),
                  // Inner ring
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.accent.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                  ),
                  // Silhouette sprite
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcATop,
                      ),
                      child: Image.asset(info.assetPath, fit: BoxFit.contain),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 14),

          // Text details
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.name,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  info.role,
                  style: TextStyle(
                    color: theme.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  info.description,
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.auto_fix_high_rounded,
                      size: 14,
                      color: theme.accent.withOpacity(0.9),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Best with: ${info.bestPowerups}',
                        style: TextStyle(
                          color: theme.textMuted,
                          fontSize: 11,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ALCHEMY OPTION CARD
// ════════════════════════════════════════════════════════════════════════════

class _AlchemyOptionCard extends StatelessWidget {
  final FactionTheme theme;
  final String label;
  final String description;
  final VoidCallback onTap;

  const _AlchemyOptionCard({
    required this.theme,
    required this.label,
    required this.description,
    required this.onTap,
  });

  Color _getOptionColor() {
    if (label.contains('Transmute')) return const Color(0xFF9C27B0);
    if (label.contains('Empower')) return const Color(0xFFFF5722);
    if (label.contains('Deploy')) return const Color(0xFF03A9F4);
    return const Color(0xFF4CAF50);
  }

  IconData _getIconForCategory() {
    if (label.contains('Transmute')) return Icons.swap_horiz_rounded;
    if (label.contains('Empower')) return Icons.bolt_rounded;
    if (label.contains('Deploy')) return Icons.add_circle_outline_rounded;
    return Icons.favorite_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final optionColor = _getOptionColor();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: theme.surface.withOpacity(0.8),
            border: Border.all(color: optionColor.withOpacity(0.5), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: optionColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIconForCategory(),
                  size: 20,
                  color: optionColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: theme.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        color: theme.textMuted,
                        fontSize: 11,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: optionColor.withOpacity(0.7),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// FAMILY INFO DATA
// ════════════════════════════════════════════════════════════════════════════

class _FamilyInfo {
  final String id;
  final String name;
  final String role;
  final String description;
  final String bestPowerups;
  final String assetPath;
  final Color color;

  const _FamilyInfo({
    required this.id,
    required this.name,
    required this.role,
    required this.description,
    required this.bestPowerups,
    required this.assetPath,
    required this.color,
  });
}

const List<_FamilyInfo> _familyInfos = [
  _FamilyInfo(
    id: 'Let',
    name: 'Let',
    role: 'Meteor Caster',
    description:
        'Drops heavy AoE meteors to erase clustered waves. Shines in swarm and boss add phases.',
    bestPowerups: 'Int Transmute, Empower Meteor, Extra Deploy',
    assetPath: 'assets/images/creatures/common/LET02_waterlet.png',
    color: Color(0xFF3B82F6),
  ),
  _FamilyInfo(
    id: 'Pip',
    name: 'Pip',
    role: 'Ricochet Marksman',
    description:
        'Projectiles that bounce between enemies, turning tight packs into free value.',
    bestPowerups: 'Speed/Int Transmute, Empower Ricochet',
    assetPath: 'assets/images/creatures/uncommon/PIP06_lavapip.png',
    color: Color(0xFFF59E0B),
  ),
  _FamilyInfo(
    id: 'Mane',
    name: 'Mane',
    role: 'Barrage DPS',
    description:
        'Unleashes rapid-fire elemental volleys in a cone. Shreds clustered enemies with sustained damage.',
    bestPowerups: 'Speed/Beauty Transmute, Empower Barrage',
    assetPath: 'assets/images/creatures/uncommon/MAN03_earthmane.png',
    color: Color(0xFFEF4444),
  ),
  _FamilyInfo(
    id: 'Mask',
    name: 'Mask',
    role: 'Trap Specialist',
    description:
        'Deploys elemental trap fields that trigger on contact. Great for choke points and area denial.',
    bestPowerups: 'Int/Beauty Transmute, Empower Traps, Extra Deploy',
    assetPath: 'assets/images/creatures/rare/MSK01_firemask.png',
    color: Color(0xFF8B5CF6),
  ),
  _FamilyInfo(
    id: 'Horn',
    name: 'Horn',
    role: 'Frontline Tank',
    description:
        'Bulky guardians that hold the line with protective Novas. Knocks enemies back and shields allies.',
    bestPowerups: 'HP Transmute, Extra Deploy, Empower Nova',
    assetPath: 'assets/images/creatures/rare/HOR13_poisonhorn.png',
    color: Color(0xFF10B981),
  ),
  _FamilyInfo(
    id: 'Wing',
    name: 'Wing',
    role: 'Agile Ranged DPS',
    description:
        'Fast fliers that shred from a distance. Excel at focusing down priorities and kiting elite threats.',
    bestPowerups: 'Speed & Int Transmute, Empower Special',
    assetPath: 'assets/images/creatures/legendary/WIN01_firewing.png',
    color: Color(0xFF06B6D4),
  ),
  _FamilyInfo(
    id: 'Kin',
    name: 'Kin',
    role: 'Healer & Support',
    description:
        'Restores your orb and allies, with powerful team-wide surges at higher ranks.',
    bestPowerups: 'Int/Beauty Transmute, Empower Heal',
    assetPath: 'assets/images/creatures/legendary/KIN01_firekin.png',
    color: Color(0xFFEC4899),
  ),
];
