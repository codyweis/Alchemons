// End-of-run results for cosmic survival: final stats, what the run paid out,
// and the three ways out of it.
//
// It comes up over the stilled arena as the core finishes coming apart, and
// the rewards gather into it out of grains (reward_reveal.dart) — the reveal
// and the results are one screen, so a run's pay is shown once. A tap
// anywhere brings them all in at once; the actions work from the start.
//
// Lives outside the screen so the layout can be pumped on its own — survival is
// landscape and has cut the bottom off its own panels before, and the way out
// of a finished run is the one control that must never be the casualty.

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/screens/cosmic/widgets/cosmic_screen_styles.dart';
import 'package:alchemons/widgets/animations/reward_reveal.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';

/// The loss: a muted ember red, the HUD's danger rather than candy pink.
const Color _frame = Color(0xFFE8857A);

/// The way forward, in the console's amber.
const Color _go = Color(0xFFE4B356);

class CosmicSurvivalGameOverPanel extends StatefulWidget {
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
  State<CosmicSurvivalGameOverPanel> createState() =>
      _CosmicSurvivalGameOverPanelState();
}

class _CosmicSurvivalGameOverPanelState
    extends State<CosmicSurvivalGameOverPanel>
    with SingleTickerProviderStateMixin {
  final _reveal = GlobalKey<RewardRevealState>();
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  void _finish() {
    _reveal.currentState?.finish();
    if (_in.isAnimating) _in.value = 1;
  }

  Animation<double> _phase(double a, double b) =>
      _in.drive(CurveTween(curve: Interval(a, b, curve: Curves.easeOut)));

  @override
  Widget build(BuildContext context) {
    final rewards = widget.rewards;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _finish,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Deepens the arena's own dimming toward the edges, so the
            // results sit in the dark the core went out in.
            FadeTransition(
              opacity: _phase(0, 0.6),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 1.1,
                    colors: [Color(0x8C000000), Color(0xE6000000)],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Only the readout scrolls. The actions sit below it so a
                      // long reward list cannot push the way out past the
                      // bottom edge.
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FadeTransition(
                                opacity: _phase(0, 0.5),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
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
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              FadeTransition(
                                opacity: _phase(0.2, 0.75),
                                child: Row(
                                  children: [
                                    _statChip('WAVE', '${widget.wave}'),
                                    _statChip('KILLS', '${widget.kills}'),
                                    _statChip('SCORE', '${widget.score}'),
                                    _statChip('TIME', widget.time),
                                  ],
                                ),
                              ),
                              if (rewards.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                FadeTransition(
                                  opacity: _phase(0.35, 0.9),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Container(
                                        height: 1,
                                        color: Colors.white.withValues(
                                          alpha: 0.08,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'REWARDS  —  TAP FOR DETAILS',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          color: _go.withValues(alpha: 0.7),
                                          fontSize: 12,
                                          letterSpacing: 3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                RewardReveal(
                                  key: _reveal,
                                  entries: rewards,
                                  delay: const Duration(milliseconds: 650),
                                  onTap: (e) => showRewardDetail(context, e),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      FadeTransition(
                        opacity: _phase(0.45, 1),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                          child: Row(
                            children: [
                              Expanded(
                                child: _ResultsButton(
                                  label: 'QUIT',
                                  color: CosmicScreenStyles.danger,
                                  onPressed: context.soundAction(widget.onQuit),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _ResultsButton(
                                  label: 'NEW TEAM',
                                  color: Colors.white70,
                                  onPressed: context.soundAction(
                                    widget.onNewTeam,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _ResultsButton(
                                  label: 'DEPLOY AGAIN',
                                  color: _go,
                                  emphasized: true,
                                  onPressed: context.soundAction(
                                    widget.onReplay,
                                  ),
                                ),
                              ),
                            ],
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
    );
  }

  Widget _statChip(String label, String value) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        color: Colors.white.withValues(alpha: 0.035),
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
    ),
  );
}

/// The mastery [points] a run earned [family], as a results row ("+99 Horn
/// mastery"): drawn by the creature of that family that was fielded
/// ([imagePath], its portrait), in the family's color, so it stands in the
/// same pool of light as every other reward. [creatures] is what each of the
/// family's creatures earned toward it (name, points), shown under the name
/// and listed in the row's detail.
LootOpeningEntry familyMasteryRewardEntry({
  required CreatureFamily family,
  required int points,
  required String? imagePath,
  List<(String, int)> creatures = const [],
}) {
  Widget fallback(double size) =>
      Icon(AppIcons.pets_rounded, color: family.color, size: size * 0.66);
  return LootOpeningEntry(
    icon: AppIcons.pets_rounded,
    name: '${family.displayName} mastery',
    label: '+$points',
    color: family.color,
    breakdown: [
      for (final (name, earned) in creatures)
        RewardBreakdownLine(label: name, amount: '+$earned'),
    ],
    visualBuilder: (size) => imagePath == null
        ? fallback(size)
        : Image.asset(
            imagePath,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => fallback(size),
          ),
  );
}

/// A results action: the way forward is a wash lit from below, the other two
/// quiet fills in their color. The label may shrink: three actions share the
/// row where two used to.
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
    return CustomPaint(
      foregroundPainter: emphasized
          ? BracketFramePainter(color: color, strokeWidth: 1.6)
          : null,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: emphasized ? Colors.white : color,
          side: BorderSide.none,
          backgroundColor: color.withValues(alpha: emphasized ? 0.14 : 0.06),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          shape: const RoundedRectangleBorder(),
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
      ),
    );
  }
}
