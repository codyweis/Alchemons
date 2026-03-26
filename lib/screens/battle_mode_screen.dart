// lib/screens/game_mode_screen.dart
//
// GAME MODE SELECTION SCREEN
// Clean, minimal design for choosing between Survival and Boss Gauntlet
//

import 'package:alchemons/games/survival/survival_game_screen.dart';
import 'package:alchemons/screens/boss/boss_intro_screen.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
import 'package:alchemons/widgets/floating_close_button_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GameModeScreen extends StatelessWidget {
  const GameModeScreen({super.key});

  void _navigateToSurvival(BuildContext context) {
    HapticFeedback.mediumImpact();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SurvivalGameScreen()));
  }

  void _navigateToBoss(BuildContext context) {
    HapticFeedback.mediumImpact();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const BossBattleScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = FactionTheme.scorchForge();

    return ParticleBackgroundScaffold(
      whiteBackground: false,
      body: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: FloatingCloseButton(
          onTap: () => Navigator.of(context).pop(),
          theme: theme,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                // Title
                Text(
                  'Battle',
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                Text(
                  'Modes',
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 36,
                    fontWeight: FontWeight.w300,
                    height: 1.1,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'Choose how you want to test your team',
                  style: TextStyle(color: theme.textMuted, fontSize: 14),
                ),

                const SizedBox(height: 32),

                // Cards
                Expanded(
                  child: Column(
                    children: [
                      // Boss Gauntlet Card
                      Expanded(
                        child: _ModeCard(
                          theme: theme,
                          title: 'Boss Gauntlet',
                          tagline: '17 Elemental Bosses',
                          description:
                              'Challenge elemental bosses in turn-based combat. Conquer all seventeen to prove your mastery.',
                          accentColor: const Color(0xFFEF4444),
                          onTap: () => _navigateToBoss(context),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Survival Card
                      Expanded(
                        child: _ModeCard(
                          theme: theme,
                          title: 'Survival',
                          tagline: 'Endless Waves',
                          description:
                              'Defend your orb against endless hordes. Deploy strategically and unlock powerful upgrades as you progress.',
                          accentColor: const Color(0xFF8B5CF6),
                          onTap: () => _navigateToSurvival(context),
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
  }
}

// ════════════════════════════════════════════════════════════════════════════
// MODE CARD
// ════════════════════════════════════════════════════════════════════════════

class _ModeCard extends StatelessWidget {
  final FactionTheme theme;
  final String title;
  final String tagline;
  final String description;
  final Color accentColor;
  final VoidCallback onTap;

  const _ModeCard({
    required this.theme,
    required this.title,
    required this.tagline,
    required this.description,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Accent bar
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 14),
                // Title & tagline
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: theme.text,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tagline,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: accentColor,
                    size: 20,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Description
            Expanded(
              child: Text(
                description,
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),

            // Bottom accent line
            Container(
              height: 2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1),
                gradient: LinearGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.5),
                    accentColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
