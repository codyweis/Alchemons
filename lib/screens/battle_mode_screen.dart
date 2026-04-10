// lib/screens/game_mode_screen.dart
//
// GAME MODE SELECTION SCREEN
// Clean, minimal design for choosing between Survival and Boss Gauntlet
//

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_screen.dart';
import 'package:alchemons/screens/boss/boss_intro_screen.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
import 'package:alchemons/widgets/floating_close_button_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class GameModeScreen extends StatefulWidget {
  const GameModeScreen({super.key});

  @override
  State<GameModeScreen> createState() => _GameModeScreenState();
}

class _GameModeScreenState extends State<GameModeScreen> {
  bool _survivalUnlocked = false;

  @override
  void initState() {
    super.initState();
    _checkSurvivalUnlocked();
  }

  Future<void> _checkSurvivalUnlocked() async {
    final db = context.read<AlchemonsDatabase>();
    final unlocked =
        await db.settingsDao.isCosmicSurvivalPortalDiscovered();
    if (mounted) {
      setState(() {
        _survivalUnlocked = unlocked;
      });
    }
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

                      // Survival Card — locked until cosmic portal discovered
                      Expanded(
                        child: _survivalUnlocked
                            ? _ModeCard(
                                theme: theme,
                                title: 'Survival',
                                tagline: 'Endless Waves',
                                description:
                                    'Defend your orb against endless hordes. Deploy strategically and unlock powerful upgrades as you progress.',
                                accentColor: const Color(0xFF8B5CF6),
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const CosmicSurvivalScreen(),
                                    ),
                                  );
                                },
                              )
                            : _LockedModeCard(theme: theme),
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

// ════════════════════════════════════════════════════════════════════════════
// LOCKED MODE CARD — Survival not yet discovered via cosmic portal
// ════════════════════════════════════════════════════════════════════════════

class _LockedModeCard extends StatelessWidget {
  final FactionTheme theme;
  const _LockedModeCard({required this.theme});

  static const _accentColor = Color(0xFF8B5CF6);

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.5,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.surface.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Survival',
                        style: TextStyle(
                          color: theme.text.withValues(alpha: 0.5),
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Locked',
                        style: TextStyle(
                          color: _accentColor.withValues(alpha: 0.5),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    color: theme.textMuted,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Unlock Survival by exploring the Cosmos',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.textMuted,
                      fontSize: 14,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ),
            Container(
              height: 2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.06),
                    Colors.white.withValues(alpha: 0.0),
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
