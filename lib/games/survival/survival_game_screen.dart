import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/survival/survival_engine.dart';
import 'package:alchemons/games/survival/survival_party_picker.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/games/survival/survival_game.dart';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SurvivalGameScreen extends StatefulWidget {
  const SurvivalGameScreen({super.key});

  @override
  State<SurvivalGameScreen> createState() => _SurvivalGameScreenState();
}

class _SurvivalGameScreenState extends State<SurvivalGameScreen> {
  SurvivalHoardGame? _game;
  bool _isLoading = false;

  // final game = SurvivalGame.godTeam();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();

    if (_game != null) {
      return _buildGameView(theme);
    }

    return _buildFormationPrompt(theme);
  }

  Widget _buildGameView(FactionTheme theme) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          //Positioned.fill(child: GameWidget(game: _game!)),
          Positioned.fill(child: GameWidget(game: _game!)),
          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [_buildBackButton(theme)]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton(FactionTheme theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Leave Game?'),
              content: const Text('Your progress will be lost.'),
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
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.4),
            radius: 1.2,
            colors: [theme.surfaceAlt, theme.surface, Colors.black],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(theme),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.grid_4x4,
                          size: 80,
                          color: theme.accent.withOpacity(0.8),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Endless Survival',
                          style: TextStyle(
                            color: theme.text,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Build a strategic 2x2 formation\nto survive endless waves',
                          style: TextStyle(
                            color: theme.textMuted,
                            fontSize: 15,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        _buildInfoCard(
                          theme,
                          Icons.shield_rounded,
                          'Front Row',
                          'Takes 75% of enemy attacks',
                          Colors.blue,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoCard(
                          theme,
                          Icons.favorite_rounded,
                          'Back Row',
                          'Protected - only 25% targeted',
                          Colors.pink,
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading
                                ? null
                                : _openFormationSelector,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.accent,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: theme.surface,
                              disabledForegroundColor: theme.textMuted,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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
                                : const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 24,
                                  ),
                            label: Text(
                              _isLoading ? 'Loading...' : 'Select Formation',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildInfoCard(
    FactionTheme theme,
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: theme.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
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

  Future<void> _openFormationSelector() async {
    final formationSlots = await Navigator.of(context).push<Map<int, String>>(
      MaterialPageRoute(
        builder: (_) => const SurvivalFormationSelectorScreen(),
      ),
    );

    if (formationSlots != null && mounted) {
      await _startGameWithFormation(formationSlots);
    }
  }

  Future<void> _startGameWithFormation(Map<int, String> formationSlots) async {
    if (_isLoading) return;

    // Validate formation
    if (!SurvivalFormationHelper.isFormationValid(formationSlots)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid formation - please try again'),
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

      // Build party with formation positions
      final party = await SurvivalFormationHelper.buildPartyFromFormation(
        formationSlots: formationSlots,
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
      } else {
        if (mounted) {
          setState(() {
            _game = SurvivalHoardGame(party: party);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error starting game: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
