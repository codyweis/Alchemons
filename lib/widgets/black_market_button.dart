// lib/widgets/black_market_button.dart
//
// The black market's door in the shop header: a black ball of grains, lit
// only at its edge by the violet glow behind it, turning slowly, with its
// three lilac orbs circling while the market is open. Shut, it goes still
// and dark. No blur: points in batches and radial gradients.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/navigation/emblem_passage.dart';
import 'package:alchemons/widgets/home_emblems.dart' show EmblemStage;
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

  /// True while the ball is away carrying the player in
  /// ([BlackMarketPassage]): its place is left empty.
  final ValueListenable<bool>? lifted;

  const AnimatedBlackMarketButton({
    super.key,
    required this.isOpen,
    required this.accent,
    required this.onTap,
    this.size = 75,
    this.lifted,
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
    final lifted = widget.lifted;
    final button = _button(context);
    if (lifted == null) return button;
    return ValueListenableBuilder<bool>(
      valueListenable: lifted,
      builder: (_, away, child) => Opacity(opacity: away ? 0 : 1, child: child),
      child: button,
    );
  }

  Widget _button(BuildContext context) {
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

  // Each light at unit size, scaled to the ball as it is drawn: the ball
  // grows over the whole screen on the way in, and a shader per radius
  // would be one per frame.
  static final Shader _glowShader = ui.Gradient.radial(
    Offset.zero,
    1,
    [
      _violet.withValues(alpha: 0.55),
      _violet.withValues(alpha: 0.42),
      _violet.withValues(alpha: 0.14),
      _violet.withValues(alpha: 0),
    ],
    const [0.0, 0.5, 0.7, 1.0],
  );
  static final Shader _bodyShader = ui.Gradient.radial(
    Offset.zero,
    1,
    const [Color(0xFF050307), Color(0xF2060409), Color(0x00070409)],
    const [0.0, 0.72, 1.0],
  );
  static final Shader _rimShader = ui.Gradient.radial(
    Offset.zero,
    1,
    [
      _violet.withValues(alpha: 0),
      _violet.withValues(alpha: 0),
      Color.lerp(_violet, _lilac, 0.3)!.withValues(alpha: 0.3),
      _violet.withValues(alpha: 0),
    ],
    const [0.0, 0.6, 0.84, 1.0],
  );
  static final Shader _shineShader = ui.Gradient.radial(Offset.zero, 1, const [
    Color(0x2EFFFFFF),
    Color(0x00FFFFFF),
  ]);

  /// [_p]'s unit-size light, drawn as a disc of radius [r].
  static void _unit(Canvas canvas, double r) {
    canvas.save();
    canvas.scale(r);
    canvas.drawCircle(Offset.zero, 1, _p);
    canvas.restore();
    _p.shader = null;
  }

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
      _p
        ..shader = _glowShader
        ..color = Color.fromRGBO(0, 0, 0, (on * glow).clamp(0.0, 1.0));
      _unit(canvas, r * 1.9);
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
    _p
      ..shader = _bodyShader
      ..color = const Color(0xFF000000);
    _unit(canvas, r);
    // The far side, faint through the smoke.
    b.draw(canvas, _farB, d * 0.8, _tones[1].withValues(alpha: 0.55));
    for (var k = 0; k < 5; k++) {
      b.draw(canvas, _nearB + k, d, tone(k));
    }
    // The light behind it wells up round its edge.
    _p
      ..shader = _rimShader
      ..color = Color.fromRGBO(0, 0, 0, 0.15 + 0.85 * on);
    _unit(canvas, r * 1.15);
    // A faint catchlight, upper left: black glass, not a hole.
    canvas.save();
    canvas.translate(-r * 0.34, -r * 0.4);
    _p
      ..shader = _shineShader
      ..color = Color.fromRGBO(0, 0, 0, 0.5 + 0.5 * on);
    _unit(canvas, r * 0.38);
    canvas.restore();
    b.draw(canvas, _glintB, d * 2.2, _lilac.withValues(alpha: 0.3));
    b.draw(canvas, _glintB, d * 1.2, _lilac);
    canvas.restore();
  }
}

/// The way into the black market: the ball lifts off the shop and grows
/// over it until the shop is gone into its dark, a few of its grains still
/// turning there; then the dark opens from where the stall's lamp hangs, and
/// the lamplit stall is what was inside it. Back, the lamp's light closes
/// and the ball shrinks home.
class BlackMarketPassage extends PassageScene {
  const BlackMarketPassage();

  @override
  Duration get inward => const Duration(milliseconds: 900);
  @override
  Duration get outward => const Duration(milliseconds: 850);
  @override
  Duration get landing => const Duration(milliseconds: 750);

  /// Built while the ball is still growing, so the stall's painting is read
  /// before the dark opens onto it.
  @override
  double get buildAt => 0.4;

  /// Wholly there under the dark from the first frame of the landing; the
  /// dark opening is what shows it.
  @override
  double pageShown(double land) => land > 0 ? 1 : 0.004;

  /// The stall's lamp: the black market screen's pool of lamplight is
  /// centred at Alignment(0, -0.2).
  static Offset lampOf(Size screen) =>
      Offset(screen.width / 2, screen.height * 0.4);

  static double _smooth(double e0, double e1, double x) {
    final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  static final Paint _veil = Paint();
  static const Color _night = Color(0xFF050307);

  @override
  void paint(
    Canvas canvas,
    EmblemStage s, {
    required bool back,
    required bool front,
  }) {
    final size = s.screen;
    final lamp = lampOf(size);
    // Far enough that the ball's solid core covers every corner.
    final far = math.sqrt(
      math.pow(size.width / 2, 2) +
          math.pow(math.max(lamp.dy, size.height - lamp.dy), 2),
    );
    final full = far / 0.7;
    final g = s.grow;
    final home = s.box.center;
    final r0 = s.box.shortestSide * 0.3;
    // It rises toward the lamp's place as it grows, quickly at first.
    final c = Offset.lerp(home, lamp, _smooth(0, 0.7, g))!;
    final r = r0 + (full - r0) * g * g;

    if (back) {
      // The shop goes under the night it is growing into.
      _veil.color = _night.withValues(alpha: 0.85 * s.ground);
      canvas.drawRect(Offset.zero & size, _veil);
    }
    if (!front) return;
    final land = s.land;
    if (land <= 0) {
      _MarketOrbPaint.paint(canvas, c, r, s.time, glow: 1 - 0.6 * g);
      return;
    }
    // The dark opens from the lamp: a hole of light widening through it,
    // its edge soft as lamplight is.
    final open = _smooth(0, 1, land);
    // Wide enough by the end that every corner is clear (inside 0.45).
    final hole = far * 2.4 * open;
    _veil
      ..color = const Color(0xFF000000)
      ..shader = ui.Gradient.radial(
        lamp,
        math.max(hole, 1),
        [_night.withValues(alpha: 0), _night.withValues(alpha: 0), _night],
        const [0.0, 0.45, 1.0],
      );
    canvas.drawRect(Offset.zero & size, _veil);
    _veil.shader = null;
  }
}
