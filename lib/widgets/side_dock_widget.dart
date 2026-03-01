import 'dart:math';
import 'package:flutter/material.dart';
import 'package:alchemons/utils/faction_util.dart';

class SideDockFloating extends StatelessWidget {
  final FactionTheme theme;
  final VoidCallback onEnhance;
  final VoidCallback onHarvest;
  final VoidCallback onCompetitions;
  final VoidCallback onField;
  final bool highlightField; // NEW: Add highlight parameter
  final bool showHarvestDot; // NEW
  final bool lockNonField;
  //battle
  final VoidCallback onBattle;
  final VoidCallback onBoss;
  final VoidCallback? onMysticAltar;

  const SideDockFloating({
    super.key,
    required this.theme,
    required this.onEnhance,
    required this.onHarvest,
    required this.onCompetitions,
    required this.onField,
    this.highlightField = false, // NEW: Default to false
    this.showHarvestDot = false,
    this.lockNonField = false,
    required this.onBattle,
    required this.onBoss,
    this.onMysticAltar,
  });

  @override
  Widget build(BuildContext context) {
    Widget lockWrap({required bool locked, required Widget child}) {
      if (!locked) return child;
      return Opacity(
        opacity: 0.35,
        child: IgnorePointer(ignoring: true, child: child),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // FIELD: highlighted, never locked
        _FloatingSideButton(
          theme: theme,
          label: 'Field',
          assetPath: 'assets/images/ui/fieldicon.png',
          onTap: onField,
          size: 70,
          highlight: highlightField,
        ),

        const SizedBox(height: 10),

        // ENHANCE: lock when lockNonField == true
        lockWrap(
          locked: lockNonField,
          child: _FloatingSideButton(
            size: 70,
            theme: theme,
            label: 'Enhance',
            assetPath: 'assets/images/ui/enhanceicon.png',
            onTap: onEnhance,
          ),
        ),

        const SizedBox(height: 10),

        lockWrap(
          locked: lockNonField,
          child: _FloatingSideButton(
            theme: theme,
            size: 70,
            label: 'Extract',
            assetPath: 'assets/images/ui/extracticon.png',
            onTap: onHarvest,
            showDot: showHarvestDot,
          ),
        ),
        // lockWrap(
        //   locked: lockNonField,
        //   child: _FloatingSideButton(
        //     theme: theme,
        //     size: 80,
        //     label: 'Competitions',
        //     assetPath: 'assets/images/ui/competeicon.png',
        //     onTap: onCompetitions,
        //   ),
        // ),
        const SizedBox(height: 10),
        lockWrap(
          locked: lockNonField,
          child: _FloatingSideButton(
            theme: theme,
            size: 80,
            label: 'Battle',
            assetPath: 'assets/images/ui/trialsicon.png',
            onTap: onBattle,
          ),
        ),
      ],
    );
  }
}

class _FloatingSideButton extends StatefulWidget {
  final FactionTheme theme;
  final String label;
  final String assetPath;
  final VoidCallback onTap;
  final double size;
  final bool highlight; // NEW: Add highlight parameter
  final bool showDot;

  const _FloatingSideButton({
    required this.theme,
    required this.label,
    required this.assetPath,
    required this.onTap,
    this.size = 60,
    this.highlight = false, // NEW: Default to false
    this.showDot = false,
  });

  @override
  State<_FloatingSideButton> createState() => _FloatingSideButtonState();
}

class _FloatingSideButtonState extends State<_FloatingSideButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.highlight) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_FloatingSideButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlight != oldWidget.highlight) {
      if (widget.highlight) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  @override
  Widget build(BuildContext context) {
    final imageWithBadge = SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: Image.asset(
              widget.assetPath,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
            ),
          ),
          if (widget.showDot)
            const Positioned(right: -2, top: -2, child: _RedDotTiny()),
        ],
      ),
    );

    Widget button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          imageWithBadge,
          Text(
            widget.label.toUpperCase(),
            style: TextStyle(
              color: widget.theme.text,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );

    // Highlight behavior only
    if (widget.highlight) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // glow ring
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.theme.accent.withValues(alpha: 0.6),
                          blurRadius: 25,
                          spreadRadius: 8,
                        ),
                        BoxShadow(
                          color: widget.theme.accent.withValues(alpha: 0.3),
                          blurRadius: 40,
                          spreadRadius: 15,
                        ),
                      ],
                    ),
                  ),
                ),
                // pulsing border
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.theme.accent.withValues(alpha: 0.8),
                        width: 3,
                      ),
                    ),
                  ),
                ),
                button,
              ],
            ),
          );
        },
      );
    }

    // Not highlighted → just normal button
    return button;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MYSTIC SWIRL BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class MysticSwirlButton extends StatefulWidget {
  final FactionTheme theme;
  final double size;
  final VoidCallback onTap;

  const MysticSwirlButton({super.key, 
    required this.theme,
    required this.onTap,
    this.size = 60,
  });

  @override
  State<MysticSwirlButton> createState() => _MysticSwirlButtonState();
}

class _MysticSwirlButtonState extends State<MysticSwirlButton>
    with TickerProviderStateMixin {
  late final AnimationController _spinCtrl;
  late final AnimationController _counterCtrl;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    _counterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _counterCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([_spinCtrl, _counterCtrl, _pulseCtrl]),
            builder: (_, __) {
              final glow = 0.35 + _pulseCtrl.value * 0.45;
              return Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0C0418),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9C27B0).withValues(alpha: glow),
                      blurRadius: 18,
                      spreadRadius: 4,
                    ),
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: glow * 0.5),
                      blurRadius: 32,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: CustomPaint(
                    painter: MysticSwirlPainter(
                      angle: _spinCtrl.value * 2 * pi,
                      counterAngle: -_counterCtrl.value * 2 * pi,
                      pulseT: _pulseCtrl.value,
                    ),
                    size: Size(widget.size, widget.size),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 2),
          Text(
            'RELICS',
            style: TextStyle(
              color: widget.theme.text,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class MysticSwirlPainter extends CustomPainter {
  final double angle;
  final double counterAngle;
  final double pulseT;

  const MysticSwirlPainter({
    required this.angle,
    required this.counterAngle,
    required this.pulseT,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Dark background
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..color = const Color(0xFF0C0418),
    );

    // Clockwise swirl arms
    _drawSpiralArm(
      canvas,
      cx,
      cy,
      r,
      angle,
      const Color(0xFF9C27B0),
      4.5,
      0.75,
    );
    _drawSpiralArm(
      canvas,
      cx,
      cy,
      r,
      angle + pi * 2 / 3,
      const Color(0xFF7C3AED),
      3.5,
      0.65,
    );
    _drawSpiralArm(
      canvas,
      cx,
      cy,
      r,
      angle + pi * 4 / 3,
      const Color(0xFF6366F1),
      3.0,
      0.55,
    );

    // Counter-rotating inner arms
    _drawSpiralArm(
      canvas,
      cx,
      cy,
      r * 0.6,
      counterAngle,
      const Color(0xFFE879F9),
      2.5,
      0.55,
    );
    _drawSpiralArm(
      canvas,
      cx,
      cy,
      r * 0.6,
      counterAngle + pi,
      const Color(0xFF0EA5E9),
      2.0,
      0.45,
    );

    // Outer halo ring
    canvas.drawCircle(
      Offset(cx, cy),
      r - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF9C27B0).withValues(alpha: 0.3),
    );

    // Glowing centre orb
    final orbR = 4.0 + pulseT * 3.5;
    final orbPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.95),
          const Color(0xFFE879F9).withValues(alpha: 0.8),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: orbR));
    canvas.drawCircle(Offset(cx, cy), orbR, orbPaint);

    // Orbiting particles
    _drawParticle(canvas, cx, cy, r * 0.72, angle * 1.3, 2.2);
    _drawParticle(canvas, cx, cy, r * 0.55, angle * 1.3 + pi * 0.7, 1.6);
    _drawParticle(canvas, cx, cy, r * 0.62, counterAngle * 0.8 + 1.2, 1.8);
    _drawParticle(canvas, cx, cy, r * 0.42, counterAngle * 0.8 + pi, 1.4);
  }

  void _drawSpiralArm(
    Canvas canvas,
    double cx,
    double cy,
    double maxR,
    double startAngle,
    Color color,
    double strokeW,
    double opacity,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: opacity);

    final path = Path();
    const steps = 80;
    path.moveTo(cx, cy);
    for (int i = 1; i <= steps; i++) {
      final t = i / steps;
      final a = startAngle + t * pi * 2.8;
      final rr = maxR * 0.75 * t;
      path.lineTo(cx + cos(a) * rr, cy + sin(a) * rr);
    }
    canvas.drawPath(path, paint);
  }

  void _drawParticle(
    Canvas canvas,
    double cx,
    double cy,
    double orbitR,
    double a,
    double r,
  ) {
    canvas.drawCircle(
      Offset(cx + cos(a) * orbitR, cy + sin(a) * orbitR),
      r,
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
  }

  @override
  bool shouldRepaint(MysticSwirlPainter old) =>
      old.angle != angle ||
      old.counterAngle != counterAngle ||
      old.pulseT != pulseT;
}

class _RedDotTiny extends StatelessWidget {
  const _RedDotTiny();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.6),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
