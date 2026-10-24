// lib/games/planet_dungeon/reward_popup_parts.dart
//
// The pieces a payout popup is built from, shared by the dungeon's star
// popup and the raid's loot popup so the two cannot drift apart: survival's
// surge card, its kind tag, cards counted out one after another, the slow
// rays behind the panel, and the lit CONTINUE.

import 'dart:math';

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/screens/cosmic/widgets/cosmic_screen_styles.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';

/// The card chrome every reward and choice shares (survival's surge card).
class RewardSurgeCard extends StatelessWidget {
  const RewardSurgeCard({
    super.key,
    required this.accent,
    required this.art,
    required this.child,
    this.selected = false,
    this.dim = false,
  });

  final Color accent;
  final Widget art;
  final Widget child;
  final bool selected;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final wash = dim ? 0.16 : (selected ? 0.46 : 0.34);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.lerp(CosmicScreenStyles.bg2, accent, wash)!,
              Color.lerp(CosmicScreenStyles.bg2, accent, wash * 0.25)!,
              CosmicScreenStyles.bg1,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          border: Border.all(
            color: accent.withValues(
              alpha: selected ? 1.0 : (dim ? 0.3 : 0.55),
            ),
            width: selected ? 1.8 : 1.0,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                color: accent.withValues(alpha: dim ? 0.5 : 1),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: CosmicScreenStyles.bg0.withValues(alpha: 0.7),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.7),
                          ),
                        ),
                        child: art,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: child),
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
}

/// The surge card's kind tag.
class RewardMiniTag extends StatelessWidget {
  const RewardMiniTag({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

/// Cards arrive one after another, sliding up — the reward is counted out,
/// not dumped.
class RewardStaggerIn extends StatefulWidget {
  const RewardStaggerIn({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<RewardStaggerIn> createState() => _RewardStaggerInState();
}

class _RewardStaggerInState extends State<RewardStaggerIn>
    with SingleTickerProviderStateMixin {
  // The wait is part of the animation (an Interval), not a Future.delayed:
  // a bare timer outlives the widget if the popup closes early.
  late final int _delayMs = 260 + widget.index * 110;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _delayMs + 380),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = _delayMs / (_delayMs + 380);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Interval(
          start,
          1,
          curve: Curves.easeOutCubic,
        ).transform(_c.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 16),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Slow rays behind the reward panel.
///
/// Deliberately unlike anything else in the dungeon: every other panel is
/// amber-on-dark with bracket corners, so a reward wearing that same chrome
/// read as another hint. This is the one moment allowed to look like an event.
class RewardRaysPainter extends CustomPainter {
  const RewardRaysPainter({required this.progress, required this.spin});

  final double progress;
  final double spin;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.01) return;
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.longestSide * 0.78;
    // UNEVEN, so it reads as light and not as a pinwheel. Fourteen identical
    // wedges turning in lockstep is a prize-wheel; a scatter of long thin
    // ones at three different widths and reaches is a shaft coming through
    // something.
    const rays = 11;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(spin);
    for (var i = 0; i < rays; i++) {
      final a = i * (pi * 2 / rays);
      final half = 0.016 + (i % 3) * 0.014;
      final reach = r * (0.62 + (i % 4) * 0.13);
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(cos(a - half) * reach, sin(a - half) * reach)
          ..lineTo(cos(a + half) * reach, sin(a + half) * reach)
          ..close(),
        Paint()
          ..color = CosmicScreenStyles.amberBright.withValues(
            alpha: (0.030 + (i % 3) * 0.014) * progress,
          ),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RewardRaysPainter old) =>
      old.progress != progress || old.spin != spin;
}

/// The popup's one button: filled and lit when it can be pressed, a dim
/// plate while it waits.
class RewardPopupButton extends StatelessWidget {
  const RewardPopupButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: context.soundAction(enabled ? onTap : null),
      child: CustomPaint(
        painter: BracketFramePainter(
          color: CosmicScreenStyles.amberBright.withValues(
            alpha: enabled ? 0.9 : 0.3,
          ),
          bracketSize: 8,
          strokeWidth: 1.2,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: enabled
                ? CosmicScreenStyles.amberBright
                : CosmicScreenStyles.bg2,
            border: Border.all(
              color: enabled
                  ? CosmicScreenStyles.amberBright
                  : CosmicScreenStyles.borderDim,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: enabled
                  ? CosmicScreenStyles.bg0
                  : CosmicScreenStyles.textSecondary,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 1.8,
            ),
          ),
        ),
      ),
    );
  }
}
