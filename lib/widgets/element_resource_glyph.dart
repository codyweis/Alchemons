import 'dart:math' as math;

import 'package:alchemons/constants/element_resources.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// One clock for every glyph on screen.
///
/// These appear in lists — the black market picker draws five at once, the
/// shop rows more — and giving each its own AnimationController means one
/// ticker per glyph all asking for the same frame. Ref-counted so the ticker
/// only runs while something is actually painting.
class _GlyphClock {
  _GlyphClock._();
  static final _GlyphClock instance = _GlyphClock._();

  final ValueNotifier<double> seconds = ValueNotifier<double>(0);
  Ticker? _ticker;
  int _listeners = 0;

  void acquire() {
    _listeners++;
    if (_ticker != null) return;
    _ticker = Ticker((elapsed) {
      seconds.value = elapsed.inMicroseconds / 1e6;
    })..start();
  }

  void release() {
    _listeners = math.max(0, _listeners - 1);
    if (_listeners > 0) return;
    _ticker?.dispose();
    _ticker = null;
  }
}

/// A resource drawn as its own small particle field instead of a flat asset.
///
/// Each element moves the way the element would: embers climb and gutter,
/// water falls and pools, earth settles, spores drift, arcane orbits. The
/// behaviour is the identity, so these stay readable at 12px where a detailed
/// painting just turns to mush.
class ElementResourceGlyph extends StatefulWidget {
  /// Takes the biome id and colour rather than a resource object, because the
  /// codebase has two unrelated `ElementResource` types — one in `constants/`
  /// carrying an IconData, one in `models/` carrying an ImageProvider — and
  /// every surface that draws a resource holds one or the other.
  const ElementResourceGlyph({
    super.key,
    required this.biomeId,
    required this.color,
    required this.size,
    this.animate = true,
    this.glow = 0,
  });

  /// Convenience for the `constants/` resource, which most shop and market
  /// surfaces hold.
  ElementResourceGlyph.of(
    ElementResource resource, {
    super.key,
    required this.size,
    this.animate = true,
    this.glow = 0,
  }) : biomeId = resource.biomeId,
       color = resource.color;

  final String biomeId;
  final Color color;
  final double size;

  /// Off for a still frame — a picker cell that is scrolling past does not
  /// need to be alive.
  final bool animate;

  /// 0..1 halo drawn behind the particles, inside this widget's own bounds.
  ///
  /// Deliberately painted rather than a BoxShadow: a shadow spills outside the
  /// box and gets sliced by the first ancestor that clips (the resource strip
  /// is a SingleChildScrollView, so the glow came out as a hard rectangle),
  /// and an animating blur is the most expensive thing on the frame. Layered
  /// discs cost nothing and cannot be clipped, because they stay inside.
  final double glow;

  @override
  State<ElementResourceGlyph> createState() => _ElementResourceGlyphState();
}

class _ElementResourceGlyphState extends State<ElementResourceGlyph> {
  bool _held = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant ElementResourceGlyph oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.animate && !_held) {
      _GlyphClock.instance.acquire();
      _held = true;
    } else if (!widget.animate && _held) {
      _GlyphClock.instance.release();
      _held = false;
    }
  }

  @override
  void dispose() {
    if (_held) _GlyphClock.instance.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        // The painter animates every frame, so there is nothing to gain from
        // the engine trying to cache it as a picture.
        willChange: widget.animate,
        isComplex: false,
        painter: _ElementParticlePainter(
          biomeId: widget.biomeId,
          color: widget.color,
          glow: widget.glow,
          clock: widget.animate ? _GlyphClock.instance.seconds : null,
        ),
      ),
    );
  }
}

class _ElementParticlePainter extends CustomPainter {
  _ElementParticlePainter({
    required this.biomeId,
    required this.color,
    required this.glow,
    required this.clock,
  }) : super(repaint: clock);

  final String biomeId;
  final Color color;
  final double glow;
  final ValueListenable<double>? clock;

  // Reused across every frame and every glyph on screen.
  static final Paint _p = Paint();

  double get _t => clock?.value ?? 0;

  /// Stable per-particle spread, so a glyph looks the same every time it is
  /// built rather than reshuffling on scroll.
  static double _seed(int i, int salt) => ((i * 37 + salt * 17) % 100) / 100.0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final bright = Color.lerp(color, Colors.white, 0.5)!;

    if (glow > 0) _halo(canvas, size, s);

    switch (biomeId) {
      case 'volcanic':
        _embers(canvas, s, bright);
      case 'oceanic':
        _droplets(canvas, s, bright);
      case 'earthen':
        _settling(canvas, s, bright);
      case 'verdant':
        _spores(canvas, s, bright);
      case 'arcane':
        _orbits(canvas, s, bright);
      default:
        _spores(canvas, s, bright);
    }
  }

  /// The pool of light the field stands in. Four flat discs, largest first —
  /// no blur, so it costs one draw call each and stays inside the box.
  void _halo(Canvas canvas, Size size, double s) {
    final c = Offset(size.width / 2, size.height / 2);
    // Largest disc stops just inside the box. Anything wider would be sliced
    // by the first ancestor that clips, which is the whole reason the old
    // BoxShadow showed up as a rectangle.
    for (var i = 4; i >= 1; i--) {
      canvas.drawCircle(
        c,
        s * 0.12 * i,
        _p..color = color.withValues(alpha: (0.15 * glow) / i),
      );
    }
  }

  /// Embers climbing and guttering out.
  void _embers(Canvas canvas, double s, Color bright) {
    const count = 9;
    for (var i = 0; i < count; i++) {
      final phase = (_t * 0.55 + _seed(i, 1)) % 1.0;
      final x =
          s * (0.22 + _seed(i, 2) * 0.56) + math.sin((_t * 2.2) + i) * s * 0.06;
      final y = s * (0.92 - phase * 0.80);
      final fade = (1 - phase) * (phase < 0.12 ? phase / 0.12 : 1.0);
      final r = s * (0.045 + 0.035 * (1 - phase));
      canvas.drawCircle(
        Offset(x, y),
        r * 2.0,
        _p..color = color.withValues(alpha: fade * 0.22),
      );
      canvas.drawCircle(
        Offset(x, y),
        r,
        _p..color = bright.withValues(alpha: fade * 0.95),
      );
    }
  }

  /// Droplets falling into a pool that answers with a ring.
  void _droplets(Canvas canvas, double s, Color bright) {
    const count = 5;
    final poolY = s * 0.80;
    for (var i = 0; i < count; i++) {
      final phase = (_t * 0.62 + _seed(i, 3)) % 1.0;
      final x = s * (0.20 + _seed(i, 4) * 0.60);
      if (phase < 0.72) {
        final fall = phase / 0.72;
        final y = s * 0.10 + (poolY - s * 0.10) * fall * fall;
        final r = s * 0.055;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x, y),
            width: r * 1.7,
            height: r * (2.0 + 1.4 * fall),
          ),
          _p..color = bright.withValues(alpha: 0.95),
        );
      } else {
        // The splash ring it leaves behind.
        final ripple = (phase - 0.72) / 0.28;
        canvas.drawCircle(
          Offset(x, poolY),
          s * (0.05 + 0.16 * ripple),
          _p
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.035
            ..color = color.withValues(alpha: (1 - ripple) * 0.8),
        );
        _p.style = PaintingStyle.fill;
      }
    }
  }

  /// Grains sliding down and stacking at the bottom.
  void _settling(Canvas canvas, double s, Color bright) {
    const count = 8;
    for (var i = 0; i < count; i++) {
      final phase = (_t * 0.40 + _seed(i, 5)) % 1.0;
      final x = s * (0.22 + _seed(i, 6) * 0.56);
      final y = s * (0.12 + phase * 0.66);
      final fade = phase > 0.86 ? (1 - phase) / 0.14 : 1.0;
      final r = s * (0.05 + _seed(i, 7) * 0.03);
      // Square grains: earth is not made of sparks.
      canvas.drawRect(
        Rect.fromCenter(center: Offset(x, y), width: r * 2, height: r * 2),
        _p..color = bright.withValues(alpha: fade * 0.9),
      );
    }
    // The heap they are landing on.
    final heap = Path()
      ..moveTo(s * 0.16, s * 0.88)
      ..lineTo(s * 0.50, s * 0.66)
      ..lineTo(s * 0.84, s * 0.88)
      ..close();
    canvas.drawPath(heap, _p..color = color.withValues(alpha: 0.55));
  }

  /// Spores drifting upward, swaying as they go.
  void _spores(Canvas canvas, double s, Color bright) {
    const count = 8;
    for (var i = 0; i < count; i++) {
      final phase = (_t * 0.34 + _seed(i, 8)) % 1.0;
      final sway = math.sin(_t * 1.5 + i * 1.3) * s * 0.11;
      final x = s * (0.24 + _seed(i, 9) * 0.52) + sway;
      final y = s * (0.90 - phase * 0.78);
      final fade =
          (phase < 0.15 ? phase / 0.15 : 1.0) *
          (phase > 0.8 ? (1 - phase) / 0.2 : 1.0);
      final r = s * (0.04 + _seed(i, 10) * 0.028);
      canvas.drawCircle(
        Offset(x, y),
        r * 1.9,
        _p..color = color.withValues(alpha: fade * 0.20),
      );
      canvas.drawCircle(
        Offset(x, y),
        r,
        _p..color = bright.withValues(alpha: fade * 0.9),
      );
    }
  }

  /// Sparks orbiting a core, on two counter-turning rings.
  void _orbits(Canvas canvas, double s, Color bright) {
    final c = Offset(s / 2, s / 2);
    canvas.drawCircle(c, s * 0.09, _p..color = bright.withValues(alpha: 0.95));
    canvas.drawCircle(c, s * 0.16, _p..color = color.withValues(alpha: 0.28));

    for (var ring = 0; ring < 2; ring++) {
      final count = ring == 0 ? 3 : 4;
      final radius = s * (ring == 0 ? 0.26 : 0.38);
      final dir = ring.isEven ? 1.0 : -1.0;
      for (var i = 0; i < count; i++) {
        final a = dir * _t * (1.5 - ring * 0.5) + i * math.pi * 2 / count;
        // Squashed orbit, so it reads as a ring seen at an angle.
        final pos = Offset(
          c.dx + math.cos(a) * radius,
          c.dy + math.sin(a) * radius * 0.62,
        );
        final twinkle = 0.55 + 0.45 * math.sin(_t * 4 + i * 2.1);
        final r = s * (0.035 + 0.02 * twinkle);
        canvas.drawCircle(
          pos,
          r * 2.0,
          _p..color = color.withValues(alpha: 0.22 * twinkle),
        );
        canvas.drawCircle(
          pos,
          r,
          _p..color = bright.withValues(alpha: 0.95 * twinkle),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ElementParticlePainter old) =>
      old.biomeId != biomeId ||
      old.color != color ||
      old.glow != glow ||
      old.clock != clock;
}
