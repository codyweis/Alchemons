// lib/widgets/black_market_button.dart
//
// The black market's door in the shop header: a black ball of grains, lit
// only at its edge by the violet glow behind it, turning slowly, with its
// three lilac orbs circling while the market is open. Shut, it goes still
// and dark. No blur: points in batches and radial gradients.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/widgets/animations/floating_particle.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart' show GrainBatch;
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AnimatedBlackMarketButton extends StatefulWidget {
  final bool isOpen;
  final Color accent;
  final VoidCallback onTap;

  /// The square the button takes up; the ball sits in the middle of it.
  final double size;

  const AnimatedBlackMarketButton({
    super.key,
    required this.isOpen,
    required this.accent,
    required this.onTap,
    this.size = 75,
  });

  @override
  State<AnimatedBlackMarketButton> createState() =>
      AnimatedBlackMarketButtonState();
}

class AnimatedBlackMarketButtonState extends State<AnimatedBlackMarketButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Use a smooth curve for seamless pulsing
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut, // Smooth in and out
      ),
    );

    if (widget.isOpen) {
      _pulseController.repeat(reverse: true); // Key change: reverse: true
    }
  }

  @override
  void didUpdateWidget(AnimatedBlackMarketButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      if (widget.isOpen) {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: context.soundAction(widget.onTap),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final pulse = widget.isOpen ? _pulseAnimation.value : 1.0;

          return Transform.scale(
            scale: pulse,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Its glow swells with it.
                  _MarketOrb(
                    size: widget.size,
                    open: widget.isOpen,
                    glow: 0.7 + 0.3 * (pulse - 1.0) / 0.08,
                  ),

                  // Particle effects when open
                  if (widget.isOpen) ...[
                    for (int i = 0; i < 3; i++)
                      FloatingParticle(controller: _pulseController, index: i),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The ball, turning on the shared [GlyphClock] while the market is open and
/// its screen is showing; shut, it is a single still frame.
class _MarketOrb extends StatefulWidget {
  const _MarketOrb({
    required this.size,
    required this.open,
    required this.glow,
  });

  final double size;
  final bool open;
  final double glow;

  @override
  State<_MarketOrb> createState() => _MarketOrbState();
}

class _MarketOrbState extends State<_MarketOrb> with GlyphClockLease {
  bool _visible = true;

  @override
  bool get wantsClock => widget.open && _visible;

  @override
  void initState() {
    super.initState();
    syncGlyphClock();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible != _visible) {
      _visible = visible;
      syncGlyphClock();
    }
  }

  @override
  void didUpdateWidget(covariant _MarketOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncGlyphClock();
  }

  @override
  void dispose() {
    releaseGlyphClock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: CustomPaint(
        willChange: widget.open,
        painter: _MarketOrbPainter(
          open: widget.open,
          glow: widget.glow,
          clock: glyphClock,
        ),
      ),
    );
  }
}

class _MarketOrbPainter extends CustomPainter {
  _MarketOrbPainter({
    required this.open,
    required this.glow,
    required this.clock,
  }) : super(repaint: clock);

  final bool open;
  final double glow;
  final ValueListenable<double>? clock;

  @override
  void paint(Canvas canvas, Size size) => _MarketOrbPaint.paint(
    canvas,
    size.center(Offset.zero),
    size.shortestSide * 0.3,
    // A still ball is caught mid-turn.
    clock?.value ?? 1.3,
    lit: open ? 1 : 0,
    glow: glow,
  );

  @override
  bool shouldRepaint(_MarketOrbPainter old) =>
      old.open != open || old.glow != glow || old.clock != clock;
}

/// Paints the black market's ball. Static: the sphere's layout is shared.
abstract final class _MarketOrbPaint {
  static const int _n = 260;

  // A unit sphere of grains, shell-weighted so it reads as a ball, each with
  // its own latitude, starting longitude and twinkle phase.
  static final List<double> _lat = [
    for (var i = 0; i < _n; i++) math.asin(2 * _h(i, 1) - 1),
  ];
  static final List<double> _lon = [
    for (var i = 0; i < _n; i++) _h(i, 2) * math.pi * 2,
  ];
  static final List<double> _rad = [
    for (var i = 0; i < _n; i++) 0.2 + 0.84 * math.pow(_h(i, 3), 0.5),
  ];
  static final List<double> _ph = [for (var i = 0; i < _n; i++) _h(i, 4)];

  static double _h(int i, int salt) {
    final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  /// The stall's old glow and its orbs' lilac.
  static const Color _violet = Color(0xFF8B4789);
  static const Color _lilac = Color(0xFFD8BFD8);

  // Near-side grains, from the dark face to the lit edge.
  static const List<Color> _tones = [
    Color(0xFF1C1522),
    Color(0xFF2A1F32),
    Color(0xFF3F2C4A),
    Color(0xFF6A4677),
    Color(0xFFA77DB4),
  ];

  // Buckets: far side, near side by edge light (5), glints.
  static const int _farB = 0, _nearB = 1, _glintB = 6;
  static final GrainBatch _b = GrainBatch(7);
  static final Paint _p = Paint();

  static final Map<int, Shader> _glowShaders = {};
  static final Map<int, Shader> _bodyShaders = {};
  static final Map<int, Shader> _rimShaders = {};
  static final Map<int, Shader> _shineShaders = {};

  /// Paints the ball round [c] at radius [r] at time [t].
  ///
  /// [lit] 1 is the market open; 0 is shut — no glow, a dim edge, no glints.
  /// [glow] scales the violet light round it.
  static void paint(
    Canvas canvas,
    Offset c,
    double r,
    double t, {
    double lit = 1,
    double glow = 1,
  }) {
    if (r <= 0) return;
    final b = _b..clear();
    final on = lit.clamp(0.0, 1.0);

    canvas.save();
    canvas.translate(c.dx, c.dy);

    // ── its light on what is round it ──
    if (on > 0) {
      final glowR = r * 1.9;
      _p
        ..shader = _glowShaders.putIfAbsent(
          glowR.round(),
          () => ui.Gradient.radial(
            Offset.zero,
            glowR,
            [
              _violet.withValues(alpha: 0.55),
              _violet.withValues(alpha: 0.42),
              _violet.withValues(alpha: 0.14),
              _violet.withValues(alpha: 0),
            ],
            const [0.0, 0.5, 0.7, 1.0],
          ),
        )
        ..color = Color.fromRGBO(0, 0, 0, (on * glow).clamp(0.0, 1.0));
      canvas.drawCircle(Offset.zero, glowR, _p);
      _p.shader = null;
    }

    // ── the sphere ──
    const tip = 0.38;
    final ct = math.cos(tip), st = math.sin(tip);
    final spin = t * 0.5;
    final count = (_n * (r / 30).clamp(0.6, 1.0)).round();
    for (var i = 0; i < count; i++) {
      final lat = _lat[i];
      final lon = _lon[i] + spin * (1 - 0.3 * math.sin(lat) * math.sin(lat));
      final cl = math.cos(lat);
      final pr = _rad[i] * r;
      final px = pr * cl * math.cos(lon);
      final py = pr * math.sin(lat);
      final pz = pr * cl * math.sin(lon);
      final y = py * ct + pz * st;
      final z = pz * ct - py * st;
      if (z < 0) {
        b.add(_farB, px, y);
        continue;
      }
      // Lit from behind: dark across its face, bright toward its edge.
      final edge = (math.sqrt(px * px + y * y) / r).clamp(0.0, 1.0);
      final light = edge * edge;
      if (on > 0 && light > 0.45 && (t * 0.3 + _ph[i] * 7.7) % 1.0 < 0.012) {
        b.add(_glintB, px, y);
        continue;
      }
      b.add(_nearB + (light * 4.99).floor(), px, y);
    }

    final d = (r * 0.08).clamp(1.0, 2.6);
    // Shut, the edge light goes out and the grains sink toward the face.
    Color tone(int k) =>
        on >= 1 ? _tones[k] : Color.lerp(_tones[k ~/ 2], _tones[k], on)!;

    // The core: black, soft at its edge, so the grains draw its outline.
    final bodyR = r.roundToDouble();
    _p
      ..shader = _bodyShaders.putIfAbsent(
        bodyR.round(),
        () => ui.Gradient.radial(
          Offset.zero,
          bodyR,
          const [Color(0xFF050307), Color(0xF2060409), Color(0x00070409)],
          const [0.0, 0.72, 1.0],
        ),
      )
      ..color = const Color(0xFF000000);
    canvas.drawCircle(Offset.zero, r, _p);
    _p.shader = null;
    // The far side, faint through the smoke.
    b.draw(canvas, _farB, d * 0.8, _tones[1].withValues(alpha: 0.55));
    for (var k = 0; k < 5; k++) {
      b.draw(canvas, _nearB + k, d, tone(k));
    }
    // The light behind it wells up round its edge.
    _p
      ..shader = _rimShaders.putIfAbsent(
        bodyR.round(),
        () => ui.Gradient.radial(
          Offset.zero,
          bodyR * 1.15,
          [
            _violet.withValues(alpha: 0),
            _violet.withValues(alpha: 0),
            Color.lerp(_violet, _lilac, 0.3)!.withValues(alpha: 0.3),
            _violet.withValues(alpha: 0),
          ],
          const [0.0, 0.6, 0.84, 1.0],
        ),
      )
      ..color = Color.fromRGBO(0, 0, 0, 0.15 + 0.85 * on);
    canvas.drawCircle(Offset.zero, r * 1.15, _p);
    _p.shader = null;
    // A faint catchlight, upper left: black glass, not a hole.
    final shineR = r * 0.38;
    canvas.save();
    canvas.translate(-r * 0.34, -r * 0.4);
    _p
      ..shader = _shineShaders.putIfAbsent(
        shineR.round(),
        () => ui.Gradient.radial(Offset.zero, shineR, const [
          Color(0x2EFFFFFF),
          Color(0x00FFFFFF),
        ]),
      )
      ..color = Color.fromRGBO(0, 0, 0, 0.5 + 0.5 * on);
    canvas.drawCircle(Offset.zero, shineR, _p);
    _p.shader = null;
    canvas.restore();
    b.draw(canvas, _glintB, d * 2.2, _lilac.withValues(alpha: 0.3));
    b.draw(canvas, _glintB, d * 1.2, _lilac);
    canvas.restore();
  }
}
