// lib/games/survival/survival_debug_team_picker_screen.dart
import 'package:alchemons/games/survival/components/debug_teams.dart';
import 'package:alchemons/games/survival/survival_engine.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SurvivalDebugTeamPickerScreen extends StatelessWidget {
  const SurvivalDebugTeamPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    final teams = DebugTeams.allTeams();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Prebuilt Teams'),
      ),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.4),
              radius: 1.2,
              colors: [theme.surfaceAlt, theme.surface, Colors.black],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: teams.length,
            itemBuilder: (context, index) {
              final t = teams[index];
              return _DebugTeamCard(
                theme: theme,
                label: t.label,
                party: t.party,
                onTap: () =>
                    Navigator.of(context).pop<List<PartyMember>>(t.party),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DebugTeamCard extends StatelessWidget {
  final FactionTheme theme;
  final String label;
  final List<PartyMember> party;
  final VoidCallback onTap;

  const _DebugTeamCard({
    required this.theme,
    required this.label,
    required this.party,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Small summary stats
    final avgLevel =
        party
            .map((p) => p.combatant.level.toDouble())
            .fold(0.0, (a, b) => a + b) /
        party.length;
    final avgSpeed =
        party.map((p) => p.combatant.statSpeed).fold(0.0, (a, b) => a + b) /
        party.length;
    final avgStr =
        party.map((p) => p.combatant.statStrength).fold(0.0, (a, b) => a + b) /
        party.length;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.accent.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: theme.accent.withValues(alpha: 0.3),
              blurRadius: 14,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.accent.withValues(alpha: 0.2),
                  ),
                  child: Icon(Icons.groups, color: theme.accent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Lv ${avgLevel.toStringAsFixed(0)} avg',
                      style: TextStyle(color: theme.textMuted, fontSize: 11),
                    ),
                    Text(
                      'SPD ${avgSpeed.toStringAsFixed(1)} • STR ${avgStr.toStringAsFixed(1)}',
                      style: TextStyle(color: theme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, color: Colors.white54),
              ],
            ),

            const SizedBox(height: 10),

            // Members table
            Column(
              children: party.map((member) {
                final c = member.combatant;
                final types = c.types.join('/');
                final posLabel = _positionShortLabel(member.position);

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.surfaceAlt.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          posLabel,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: TextStyle(
                                color: theme.text,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Lv ${c.level} • ${c.family} • $types',
                              style: TextStyle(
                                color: theme.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Stats row
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'SPD ${c.statSpeed.toStringAsFixed(1)}  INT ${c.statIntelligence.toStringAsFixed(1)}',
                            style: TextStyle(
                              color: theme.textMuted,
                              fontSize: 10,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          Text(
                            'STR ${c.statStrength.toStringAsFixed(1)}  BTY ${c.statBeauty.toStringAsFixed(1)}',
                            style: TextStyle(
                              color: theme.textMuted,
                              fontSize: 10,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _positionShortLabel(FormationPosition pos) {
    switch (pos) {
      case FormationPosition.frontLeft:
        return 'FL';
      case FormationPosition.frontRight:
        return 'FR';
      case FormationPosition.backLeft:
        return 'BL';
      case FormationPosition.backRight:
        return 'BR';
    }
  }
}
