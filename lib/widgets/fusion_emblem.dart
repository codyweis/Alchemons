// lib/widgets/fusion_emblem.dart
//
// The Fusion tab's icon: a vial — a glass orb, floating, with the cultivation
// sphere's grains turning inside it. Two sets of grains, teal and amber,
// counter-rotate on a tipped axis (the two parents, merging), a heart of
// light at its centre, a catchlight on the glass, a pool of light below that
// swells and shrinks as it bobs.
//
// Moves only when it is the open tab; closed, it is drawn once at a resting
// frame. Filled shapes, gradients and point batches — nothing stroked, no
// blur.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class FusionEmblem extends StatefulWidget {
  const FusionEmblem({
    super.key,
    required this.size,
    this.animate = false,
    this.dark = true,
  });

  final double size;

  /// Whether it moves — true only for the open tab.
  final bool animate;

  /// The theme it sits on (the pool of light under it is drawn deeper on the
  /// light one).
  final bool dark;

  @override
  State<FusionEmblem> createState() => _FusionEmblemState();
}

class _FusionEmblemState extends State<FusionEmblem> with GlyphClockLease {
  bool _visible = true;

  @override
  bool get wantsClock => widget.animate && _visible;

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
  void didUpdateWidget(covariant FusionEmblem oldWidget) {
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
    final clock = glyphClock;
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        willChange: clock != null,
        painter: FusionEmblemPainter(clock: clock, dark: widget.dark),
      ),
    );
  }
}

class FusionEmblemPainter extends CustomPainter {
  FusionEmblemPainter({this.clock, this.time, this.dark = true})
    : super(repaint: clock);

  /// Null leaves the painter at its resting frame.
  final ValueListenable<double>? clock;

  /// A fixed time, for a still frame (tests).
  final double? time;

  final bool dark;

  /// The frame a closed tab is drawn at.
  static const double restTime = 1.1;

  static const Color _violet = Color(0xFFC48CFF);
  static const Color _teal = Color(0xFF5FD4C8);
  static const Color _amber = Color(0xFFF0B254);
  static const Color _ink = Color(0xFF0B0911);
  static const Color _obsidian = Color(0xFF120E0A);

  static const int _grains = 170;
  static final GrainBatch _b = GrainBatch(7);
  static final Paint _p = Paint();

  static double _h(int i, int salt) {
    final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final t = time ?? clock?.value ?? restTime;
    _p
      ..shader = null
      ..color = const Color(0xFF000000);
    final r = s * 0.5;
    final bob = math.sin(t * 1.6);
    final R = r * 0.64;
    final c = size.center(Offset.zero) + Offset(0, -r * 0.06 + bob * r * 0.045);

    // The pool of light it floats over: wider and fainter as it rises.
    final rise = (bob + 1) / 2;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2 + r * 0.84);
    canvas.scale(1, 0.26);
    final pool = r * (0.62 - 0.1 * rise);
    canvas.drawCircle(
      Offset.zero,
      pool,
      _p
        ..shader = ui.Gradient.radial(Offset.zero, pool, [
          _violet.withValues(alpha: (dark ? 0.5 : 0.34) * (1 - 0.3 * rise)),
          _violet.withValues(alpha: 0),
        ]),
    );
    _p.shader = null;
    canvas.restore();

    // The glass: dark, tinted violet, lit upper left, its heart glowing.
    final orb = Rect.fromCircle(center: c, radius: R);
    canvas.drawCircle(
      c,
      R,
      _p
        ..shader = ui.Gradient.radial(
          c + Offset(-R * 0.35, -R * 0.4),
          R * 1.7,
          [Color.lerp(_violet, _ink, 0.62)!, _obsidian],
        ),
    );
    canvas.drawCircle(
      c,
      R * 0.8,
      _p
        ..shader = ui.Gradient.radial(c, R * 0.8, [
          _violet.withValues(alpha: 0.5 + 0.1 * math.sin(t * 2.2)),
          _violet.withValues(alpha: 0),
        ]),
    );
    _p.shader = null;

    // Two sets of grains turning against each other on an axis tipped
    // toward the viewer; the far side is drawn first and darker, then the
    // near side over it.
    final b = _b..clear();
    const tip = 0.34;
    final ct = math.cos(tip), st = math.sin(tip);
    for (var set = 0; set < 2; set++) {
      final spin = set == 0 ? t * 0.8 : -t * 0.55 + 1.7;
      final cs = math.cos(spin), sn = math.sin(spin);
      for (var i = 0; i < _grains; i++) {
        // Even over the sphere, a little inside its glass.
        final y = 1 - 2 * (i + 0.5) / _grains;
        final ring = math.sqrt(1 - y * y);
        final phi = i * 2.399963 + set * 0.9;
        final rho = 0.7 + 0.2 * _h(i, 10 + set);
        var x = math.cos(phi) * ring, z = math.sin(phi) * ring, yy = y;
        final xr = x * cs + z * sn;
        final zr = -x * sn + z * cs;
        x = xr;
        final y2 = yy * ct - zr * st;
        final z2 = yy * st + zr * ct;
        final px = c.dx + x * rho * R;
        final py = c.dy + y2 * rho * R;
        // Three depths a side, so the sphere has a front and a back.
        final depth = z2 < -0.3 ? 0 : (z2 > 0.3 ? 2 : 1);
        b.add(set * 3 + depth, px, py);
        if (depth == 2 && (t * 0.45 + _h(i, 20 + set) * 6) % 1.0 < 0.03) {
          b.add(6, px, py);
        }
      }
    }
    final d = math.max(0.9, r * 0.05);
    const mix = [_teal, _amber];
    for (var set = 0; set < 2; set++) {
      final col = mix[set];
      b.draw(canvas, set * 3, d * 0.75, Color.lerp(col, _ink, 0.7)!);
      b.draw(canvas, set * 3 + 1, d, Color.lerp(col, _ink, 0.25)!);
      b.draw(canvas, set * 3 + 2, d * 1.25, Color.lerp(col, Colors.white, 0.2)!);
    }
    b.draw(canvas, 6, d * 1.6, const Color(0xFFFFF4E0));

    // The glass over it: the edge catching light — filled, as glass is —
    // a darker lower rim, and a small bright reflection.
    canvas.drawCircle(
      c,
      R,
      _p
        ..shader = ui.Gradient.linear(
          orb.topLeft,
          orb.bottomRight,
          [
            Colors.white.withValues(alpha: 0.26),
            Colors.white.withValues(alpha: 0.0),
            _violet.withValues(alpha: 0.22),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );
    _p.shader = null;
    canvas.save();
    canvas.translate(c.dx - R * 0.42, c.dy - R * 0.5);
    canvas.rotate(-0.7);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: R * 0.5,
        height: R * 0.2,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FusionEmblemPainter old) =>
      old.clock != clock || old.time != time || old.dark != dark;
}
