// End-of-run results for cosmic survival: final stats, what the run paid out,
// and the three ways out of it.
//
// Lives outside the screen so the layout can be pumped on its own — survival is
// landscape and has cut the bottom off its own panels before, and the way out
// of a finished run is the one control that must never be the casualty.

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/screens/cosmic/widgets/cosmic_screen_styles.dart';
import 'package:alchemons/widgets/animations/loot_open_popup.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:flutter/material.dart';

const Color _frame = Color(0xFFFF9BA3);
const Color _amber = Color(0xFFFFAA00);

class CosmicSurvivalGameOverPanel extends StatelessWidget {
  const CosmicSurvivalGameOverPanel({
    super.key,
    required this.wave,
    required this.kills,
    required this.score,
    required this.time,
    required this.rewards,
    required this.onQuit,
    required this.onNewTeam,
    required this.onReplay,
  });

  final int wave;
  final int kills;
  final int score;
  final String time;
  final List<LootOpeningEntry> rewards;

  /// Leaves survival entirely and returns to whatever pushed it.
  final VoidCallback onQuit;
  final VoidCallback onNewTeam;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.96),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Only the readout scrolls. The actions sit below it so a long
                // reward list cannot push the way out past the bottom edge.
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: Text(
                            'ORB DESTROYED',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: _frame,
                              fontSize: 20,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 1,
                          color: _frame.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _statChip('WAVE', '$wave'),
                            _statChip('KILLS', '$kills'),
                            _statChip('SCORE', '$score'),
                            _statChip('TIME', time),
                          ],
                        ),
                        if (rewards.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'REWARDS  —  TAP FOR DETAILS',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: _amber.withValues(alpha: 0.55),
                              fontSize: 12,
                              letterSpacing: 3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...rewards.map(
                            (entry) => Builder(
                              builder: (ctx) => GestureDetector(
                                onTap: ctx.soundAction(
                                  () => _showRewardDetail(ctx, entry),
                                ),
                                child: _rewardRow(entry),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ResultsButton(
                          label: 'QUIT',
                          color: CosmicScreenStyles.danger,
                          onPressed: context.soundAction(onQuit),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ResultsButton(
                          label: 'NEW TEAM',
                          color: Colors.white70,
                          onPressed: context.soundAction(onNewTeam),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ResultsButton(
                          label: 'DEPLOY AGAIN',
                          color: _frame,
                          emphasized: true,
                          onPressed: context.soundAction(onReplay),
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

  Widget _statChip(String label, String value) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'monospace',
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _rewardRow(LootOpeningEntry entry) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: entry.color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: entry.color.withValues(alpha: 0.22)),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: entry.color.withValues(alpha: 0.12),
            border: Border.all(color: entry.color.withValues(alpha: 0.35)),
          ),
          child: entry.visualBuilder != null
              ? Center(child: entry.visualBuilder!(28))
              : Icon(entry.icon, color: entry.color, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            entry.name?.toUpperCase() ?? '',
            style: TextStyle(
              fontFamily: 'monospace',
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Text(
          entry.label,
          style: TextStyle(
            fontFamily: 'monospace',
            color: entry.color,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          AppIcons.chevron_right,
          color: entry.color.withValues(alpha: 0.45),
          size: 16,
        ),
      ],
    ),
  );

  void _showRewardDetail(BuildContext ctx, LootOpeningEntry entry) {
    showDialog<void>(
      context: ctx,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: CosmicScreenStyles.bg2,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: entry.color.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: entry.color.withValues(alpha: 0.18),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: entry.color.withValues(alpha: 0.12),
                  border: Border.all(
                    color: entry.color.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: entry.visualBuilder != null
                    ? Center(child: entry.visualBuilder!(48))
                    : Icon(entry.icon, color: entry.color, size: 30),
              ),
              const SizedBox(height: 16),
              if (entry.name != null)
                Text(
                  entry.name!.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                entry.label,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: entry.color,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: ctx.soundAction(() => Navigator.pop(dialogCtx)),
                child: Container(
                  width: double.infinity,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: entry.color.withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'CLOSE',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: entry.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                      ),
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
}

/// Same outlined button the results screen already used, with the label allowed
/// to shrink: three actions share the row where two used to.
class _ResultsButton extends StatelessWidget {
  const _ResultsButton({
    required this.label,
    required this.color,
    required this.onPressed,
    this.emphasized = false,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: emphasized ? Colors.white : color,
        side: BorderSide(
          color: emphasized ? color : color.withValues(alpha: 0.55),
          width: emphasized ? 1.5 : 1.2,
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
