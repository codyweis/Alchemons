// lib/games/planet_dungeon/reward_popup_parts.dart
//
// The pieces a payout popup is built from, shared by the dungeon's star
// popup and the raid's loot popup so the two cannot drift apart: the light
// it stands in, the star gathering out of grains, a reward row, rows counted
// out one after another, and the button.
//
// Until 2026-10 these were survival's old surge cards (a solid spine, an
// outlined medallion, an outlined tag) under slowly turning rays, with a
// stock star struck into a gold coin. Now the payout wears the bare kit:
// unframed rows on ink, the chosen one lit from below, and the only thing
// that moves on its own is the star's light.

import 'package:alchemons/screens/cosmic/widgets/cosmic_screen_styles.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:alchemons/widgets/fx/grain_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// How long a payout takes to arrive: the scrim, the light and the panel.
const Duration kRewardIntro = Duration(milliseconds: 900);

/// What the popup stands in: the scrim, and a warm pool of light rising
/// from below the panel, so the payout is lit and the world behind it is not.
class RewardBackdrop extends StatelessWidget {
  const RewardBackdrop({super.key, required this.t});

  /// 0..1 of the arrival.
  final double t;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(painter: _RewardBackdropPainter(t), size: Size.infinite),
  );
}

class _RewardBackdropPainter extends CustomPainter {
  const _RewardBackdropPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: 0.9 * t),
    );
    // Low and wide, not a disc round the middle: light from below the
    // panel, as a chosen thing in the kit is lit.
    final w = size.width;
    final c = Offset(w / 2, size.height * 0.62);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(1, 0.62);
    GrainGlass.pool(
      canvas,
      Offset.zero,
      w * 0.78,
      CosmicScreenStyles.amber,
      alpha: 0.42 * t,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RewardBackdropPainter old) => old.t != t;
}

/// The star just secured, as gold grains gathering into a sphere of light,
/// then running there. [delay] staggers several stars won at once.
class RewardStarGrains extends StatefulWidget {
  const RewardStarGrains({
    super.key,
    required this.size,
    this.delay = Duration.zero,
    this.salt = 0,
  });

  final double size;
  final Duration delay;
  final int salt;

  @override
  State<RewardStarGrains> createState() => _RewardStarGrainsState();
}

class _RewardStarGrainsState extends State<RewardStarGrains>
    with SingleTickerProviderStateMixin, GlyphClockLease {
  // The wait is part of the controller, not a timer that could outlive it.
  late final AnimationController _gather = AnimationController(
    vsync: this,
    duration: widget.delay + const Duration(milliseconds: 1500),
  )..forward();
  bool _visible = true;

  @override
  bool get wantsClock => _visible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    syncGlyphClock();
  }

  @override
  void dispose() {
    releaseGlyphClock();
    _gather.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _gather.duration!.inMicroseconds;
    final start = total == 0 ? 0.0 : widget.delay.inMicroseconds / total;
    return SizedBox.square(
      dimension: widget.size,
      child: CustomPaint(
        willChange: true,
        painter: _StarGrainsPainter(
          clock: glyphClock,
          gather: _gather,
          start: start,
          salt: widget.salt,
        ),
      ),
    );
  }
}

class _StarGrainsPainter extends CustomPainter {
  _StarGrainsPainter({
    required this.clock,
    required this.gather,
    required this.start,
    required this.salt,
  }) : super(
         repaint: Listenable.merge([gather, if (clock != null) clock]),
       );

  final ValueListenable<double>? clock;
  final Animation<double> gather;
  final double start;
  final int salt;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final g = GrainGlass.smooth(
      ((gather.value - start) / (1 - start)).clamp(0.0, 1.0),
    );
    if (g <= 0) return;
    GrainGlass.sphere(
      canvas,
      Offset(s / 2, s / 2),
      s * 0.3,
      clock?.value ?? 0,
      a: CosmicScreenStyles.amber,
      spin: 0.55,
      gather: g,
      heat: 0.85 * g,
      heatColor: CosmicScreenStyles.amberBright,
      glass: g,
      fade: GrainGlass.smooth(g / 0.35),
      salt: salt,
    );
  }

  @override
  bool shouldRepaint(covariant _StarGrainsPainter old) =>
      old.clock != clock || old.gather != gather || old.salt != salt;
}

/// An item's art standing in a pool of its own light, unframed.
class RewardArt extends StatelessWidget {
  const RewardArt({
    super.key,
    required this.accent,
    required this.child,
    this.size = 44,
  });

  final Color accent;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _ArtPoolPainter(accent),
      child: Center(child: child),
    ),
  );
}

class _ArtPoolPainter extends CustomPainter {
  const _ArtPoolPainter(this.accent);

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) => GrainGlass.pool(
    canvas,
    size.center(Offset.zero),
    size.shortestSide * 0.62,
    accent,
    alpha: 0.5,
  );

  @override
  bool shouldRepaint(covariant _ArtPoolPainter old) => old.accent != accent;
}

/// One reward, or one choice: its art, the amount large, the name under it,
/// and what kind of thing it is in small letters. Unframed on ink; a chosen
/// one is lit from below in its [accent], the rest of a choice go quiet.
class RewardRow extends StatelessWidget {
  const RewardRow({
    super.key,
    required this.accent,
    required this.art,
    required this.child,
    this.kind,
    this.selected = false,
    this.dim = false,
  });

  final Color accent;
  final Widget art;
  final Widget child;

  /// What kind of thing it is: CURRENCY, POWERUP, GUARDIAN RELIC.
  final String? kind;
  final bool selected;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: dim ? 0.45 : 1,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: selected ? 1 : 0),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (context, lit, inner) => CustomPaint(
          foregroundPainter: BracketFramePainter(
            color: accent.withValues(alpha: 0.55 + 0.45 * lit),
            strokeWidth: 1.3,
          ),
          child: Container(
            color: Color.lerp(
              CosmicScreenStyles.bg1,
              Color.lerp(CosmicScreenStyles.bg2, accent, 0.1),
              lit,
            ),
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            child: inner,
          ),
        ),
        child: Row(
          children: [
            RewardArt(accent: accent, child: art),
            const SizedBox(width: 12),
            Expanded(child: child),
            if (kind != null) ...[
              const SizedBox(width: 8),
              Text(
                kind!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: Color.lerp(CosmicScreenStyles.textSecondary, accent, 0.5)!
                      .withValues(alpha: 0.8),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A reward's amount over its name, as both popups set them.
class RewardAmountName extends StatelessWidget {
  const RewardAmountName({
    super.key,
    required this.amount,
    required this.name,
    required this.accent,
  });

  final String amount;
  final String name;
  final Color accent;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (amount.isNotEmpty)
        Text(
          amount,
          style: TextStyle(
            color: Color.lerp(CosmicScreenStyles.textPrimary, accent, 0.45),
            fontSize: 20,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
      const SizedBox(height: 3),
      Text(
        name.toUpperCase(),
        style: const TextStyle(
          color: CosmicScreenStyles.textPrimary,
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          height: 1.15,
        ),
      ),
    ],
  );
}

/// Rows arrive one after another, rising a little as they fade in — the
/// reward is counted out, not dumped.
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
  late final int _delayMs = 520 + widget.index * 140;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _delayMs + 480),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = _delayMs / (_delayMs + 480);
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
            offset: Offset(0, (1 - t) * 10),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// A section heading: small monospace letters, no rule.
class RewardSectionLabel extends StatelessWidget {
  const RewardSectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: 'monospace',
        color: CosmicScreenStyles.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.8,
      ),
    ),
  );
}

/// The popup's button, from the kit: lit from below in brass when it is the
/// way on; [quiet] is the lesser of two choices.
class RewardPopupButton extends StatelessWidget {
  const RewardPopupButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.quiet = false,
  });

  final String label;
  final bool enabled;
  final VoidCallback? onTap;
  final bool quiet;

  @override
  Widget build(BuildContext context) => BracketButton(
    label: label,
    onTap: onTap,
    palette: BracketPalette.dark,
    accent: CosmicScreenStyles.amberBright,
    enabled: enabled,
    primary: !quiet,
    height: 48,
  );
}

/// The panel every payout sits on: ink, unframed, no shadow — the light
/// below it is what sets it apart.
class RewardPanel extends StatelessWidget {
  const RewardPanel({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxWidth = size.width - 36;
    return Container(
      width: maxWidth < 400 ? maxWidth : 400,
      constraints: BoxConstraints(maxHeight: size.height - 60),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      color: CosmicScreenStyles.bg0.withValues(alpha: 0.94),
      child: child,
    );
  }
}
