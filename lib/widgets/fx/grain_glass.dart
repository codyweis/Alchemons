// lib/widgets/fx/grain_glass.dart
//
// A small sphere of dark glass with grains turning inside it, lit from the
// upper left: the power orb's look (power_orb.dart), opened up for the shop's
// item glyphs. The chambers, the stasis cells, the faction core and the
// catalyst are all one of these doing something different.
//
// Two lineages can share a sphere, turning against each other the way a
// cultivation's parents do, or split by where a grain is (a colour sweeping
// through). [gather] below 1 scatters the grains outward along a swirl, so a
// sphere can be shown forming. No blur: points in batches and radial
// gradients, cached per size and colour.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/fusion_particles.dart' show GrainBatch;
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

abstract final class GrainGlass {
  static const int _n = 340;

  static final List<double> _lat = [
    for (var i = 0; i < _n; i++) math.asin(2 * h(i, 1) - 1),
  ];
  static final List<double> _lon = [
    for (var i = 0; i < _n; i++) h(i, 2) * math.pi * 2,
  ];
  static final List<double> _rad = [
    for (var i = 0; i < _n; i++) 0.2 + 0.72 * math.pow(h(i, 3), 0.6),
  ];
  static final List<double> _ph = [for (var i = 0; i < _n; i++) h(i, 4)];

  /// A stable 0..1 hash, for anything that wants grains of its own.
  static double h(int i, int salt) {
    final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  static double smooth(double x) {
    final v = x.clamp(0.0, 1.0);
    return v * v * (3 - 2 * v);
  }

  // Per lineage: far side (2 tones) and near side (4). Then glints.
  static const int _farA = 0, _nearA = 2, _farB = 6, _nearB = 8, _glint = 12;
  static final GrainBatch _b = GrainBatch(13);
  static final Paint _p = Paint();
  static final Map<(int, int, int), Shader> _shaders = {};

  static Shader _radial(int kind, double r, Color c, Shader Function() make) =>
      _shaders.putIfAbsent((kind, r.round(), c.toARGB32()), make);

  /// The tones of [c], deep to white; [heat] pulls the bright ones gold.
  static List<Color> _tones(Color c, double heat, Color heatColor) {
    Color hot(Color x, double k) =>
        heat <= 0 ? x : Color.lerp(x, heatColor, heat * k)!;
    return [
      Color.lerp(c, const Color(0xFF07060B), 0.6)!,
      Color.lerp(c, const Color(0xFF07060B), 0.3)!,
      hot(c, 0.35),
      hot(Color.lerp(c, Colors.white, 0.3)!, 0.5),
      hot(Color.lerp(c, Colors.white, 0.58)!, 0.6),
      hot(Color.lerp(c, Colors.white, 0.85)!, 0.4),
    ];
  }

  /// Paints a glass sphere of grains round [c] at radius [r] at time [t].
  ///
  /// - [a], [b]: the lineages. With [b] and no [inB], alternate grains are
  ///   [b] and turn the other way. With [inB], a grain is [b] where it says.
  /// - [spin]: radians a second round the tipped axis.
  /// - [squeeze]: the grains' radius, 1 at rest; under 1 draws them in.
  /// - [heat]: 0..1 of gold light rising inside (a cultivation that is
  ///   ready).
  /// - [glass]: 0..1 of the glass body; 0 is loose grains only.
  /// - [gather]: 1 is the sphere; under 1 each grain is still on its way in,
  ///   further out and further back along a swirl, the late ones latest.
  /// - [density]: scales the grain count.
  /// - [fade]: scales every alpha.
  static void sphere(
    Canvas canvas,
    Offset c,
    double r,
    double t, {
    required Color a,
    Color? b,
    bool Function(double x, double y)? inB,
    double spin = 0.5,
    double squeeze = 1,
    double heat = 0,
    Color heatColor = const Color(0xFFE8B84A),
    double glass = 1,
    double gather = 1,
    double density = 1,
    double fade = 1,
    double glow = 1,
    int salt = 0,
  }) {
    if (r <= 0 || fade <= 0) return;
    final f = fade.clamp(0.0, 1.0);
    final bb = b ?? a;
    final mix = Color.lerp(a, bb, 0.5)!;
    final ta = _tones(a, heat, heatColor);
    final tb = _tones(bb, heat, heatColor);
    final batch = _b..clear();

    canvas.save();
    canvas.translate(c.dx, c.dy);

    // ── its light on what is round it ──
    final glowR = r * 2.0;
    _p
      ..shader = _radial(
        0,
        glowR,
        mix,
        () => ui.Gradient.radial(
          Offset.zero,
          glowR,
          [
            mix.withValues(alpha: 0.3),
            mix.withValues(alpha: 0.08),
            mix.withValues(alpha: 0),
          ],
          const [0.0, 0.45, 1.0],
        ),
      )
      ..color = Color.fromRGBO(0, 0, 0, f * glow * (0.4 + 0.6 * gather));
    canvas.drawCircle(Offset.zero, glowR, _p);
    if (heat > 0.01) {
      _p
        ..shader = _radial(
          1,
          glowR,
          heatColor,
          () => ui.Gradient.radial(
            Offset.zero,
            glowR,
            [
              heatColor.withValues(alpha: 0.42),
              heatColor.withValues(alpha: 0.1),
              heatColor.withValues(alpha: 0),
            ],
            const [0.0, 0.42, 1.0],
          ),
        )
        ..color = Color.fromRGBO(0, 0, 0, f * glow * heat);
      canvas.drawCircle(Offset.zero, glowR, _p);
    }
    _p.shader = null;

    // ── the grains ──
    const tip = 0.38;
    final ct = math.cos(tip), st = math.sin(tip);
    final count = (_n * density * (r / 32).clamp(0.25, 1.0)).round().clamp(
      12,
      _n,
    );
    final split = b != null && inB == null;
    final gr = r * squeeze;
    for (var i = 0; i < count; i++) {
      final lat = _lat[i];
      final other = split && i.isOdd;
      final dir = other ? -1.0 : 1.0;
      var lon =
          _lon[i] +
          salt * 1.3 +
          dir * t * spin * (1 - 0.3 * math.sin(lat) * math.sin(lat));
      var pr = _rad[i] * gr;
      var alpha = 1.0;
      if (gather < 1) {
        // Each grain arrives on its own: the late ones are further out and
        // further back round the swirl.
        final g = smooth((gather * 1.6 - _ph[i] * 0.6).clamp(0.0, 1.0));
        pr *= 1 + (1 - g) * 1.6;
        lon -= (1 - g) * 2.2;
        alpha = 0.25 + 0.75 * g;
        if (g <= 0.001 && _ph[i] > gather * 2) continue;
      }
      final cl = math.cos(lat);
      final px = pr * cl * math.cos(lon);
      final py = pr * math.sin(lat);
      final pz = pr * cl * math.sin(lon);
      final y = py * ct + pz * st;
      final z = pz * ct - py * st;
      var light = (-0.45 * px - 0.6 * y + 0.66 * z) / r * 0.5 + 0.5;
      light = smooth(light);
      if (alpha < 0.6) light *= 0.7;
      final isB = inB != null ? inB(px, y) : other;
      if (z < 0) {
        batch.add((isB ? _farB : _farA) + (light * 1.99).floor(), px, y);
        continue;
      }
      if ((t * 0.3 + _ph[i] * 7.7) % 1.0 < 0.008 + 0.02 * heat && light > 0.4) {
        batch.add(_glint, px, y);
        continue;
      }
      batch.add((isB ? _nearB : _nearA) + (light * 3.99).floor(), px, y);
    }

    final d = (r * 0.068).clamp(1.05, 2.3);
    Color k(Color c, [double m = 1]) =>
        c.withValues(alpha: (c.a * m * f).clamp(0.0, 1.0));
    final loose = gather < 1 ? 0.75 + 0.25 * gather : 1.0;

    for (var j = 0; j < 2; j++) {
      batch.draw(canvas, _farA + j, d * 0.8, k(ta[j + 1], 0.6 * loose));
      batch.draw(canvas, _farB + j, d * 0.8, k(tb[j + 1], 0.6 * loose));
    }

    // The glass: dark and tinted, so the light inside it glows.
    final g = glass.clamp(0.0, 1.0) * f;
    if (g > 0.01) {
      final bodyR = r.roundToDouble();
      _p
        ..shader = _radial(
          2,
          bodyR,
          mix,
          () => ui.Gradient.radial(
            Offset(-bodyR * 0.2, -bodyR * 0.25),
            bodyR * 1.25,
            [
              Color.lerp(
                mix,
                const Color(0xFF07060B),
                0.5,
              )!.withValues(alpha: 0.55),
              Color.lerp(
                mix,
                const Color(0xFF07060B),
                0.74,
              )!.withValues(alpha: 0.76),
              Color.lerp(
                mix,
                const Color(0xFF07060B),
                0.88,
              )!.withValues(alpha: 0.9),
            ],
            const [0.0, 0.6, 1.0],
          ),
        )
        ..color = Color.fromRGBO(0, 0, 0, g);
      canvas.drawCircle(Offset.zero, r, _p);
    }
    // The light inside it.
    final heartR = r * 0.8;
    // Stepped, so an animated heat reuses a handful of cached shaders.
    final heatStep = (heat * 8).round() / 8;
    final heart = heatStep > 0 ? Color.lerp(mix, heatColor, heatStep)! : mix;
    _p
      ..shader = _radial(
        3,
        heartR,
        heart,
        () => ui.Gradient.radial(
          Offset.zero,
          heartR,
          [
            Color.lerp(heart, Colors.white, 0.55)!.withValues(alpha: 0.7),
            heart.withValues(alpha: 0.3),
            heart.withValues(alpha: 0),
          ],
          const [0.0, 0.45, 1.0],
        ),
      )
      ..color = Color.fromRGBO(
        0,
        0,
        0,
        (f * (0.45 + 0.55 * heat) * (0.3 + 0.7 * gather)).clamp(0.0, 1.0),
      );
    canvas.drawCircle(Offset.zero, heartR, _p);
    _p.shader = null;

    for (var j = 0; j < 4; j++) {
      batch.draw(canvas, _nearA + j, d, k(ta[j + 2], 0.9 * loose));
      batch.draw(canvas, _nearB + j, d, k(tb[j + 2], 0.9 * loose));
    }

    if (g > 0.01) {
      // Its edge catches the light, lower right more: a lens, not a disc.
      final bodyR = r.roundToDouble();
      _p
        ..shader = _radial(
          4,
          bodyR,
          mix,
          () => ui.Gradient.radial(
            Offset(bodyR * 0.12, bodyR * 0.14),
            bodyR * 1.02,
            [
              mix.withValues(alpha: 0),
              mix.withValues(alpha: 0),
              Color.lerp(mix, Colors.white, 0.35)!.withValues(alpha: 0.5),
              mix.withValues(alpha: 0),
            ],
            const [0.0, 0.8, 0.95, 1.0],
          ),
        )
        ..color = Color.fromRGBO(0, 0, 0, g);
      canvas.drawCircle(Offset.zero, r * 1.04, _p);
      // A soft catchlight, upper left: glass.
      final shineR = r * 0.42;
      canvas.save();
      canvas.translate(-r * 0.34, -r * 0.4);
      _p
        ..shader = _radial(
          5,
          shineR,
          Colors.white,
          () => ui.Gradient.radial(Offset.zero, shineR, const [
            Color(0xB3FFFFFF),
            Color(0x00FFFFFF),
          ]),
        )
        ..color = Color.fromRGBO(0, 0, 0, g * 0.8);
      canvas.drawCircle(Offset.zero, shineR, _p);
      canvas.restore();
      _p.shader = null;
    }

    batch.draw(canvas, _glint, d * 2.3, k(const Color(0x40FFFFFF)));
    batch.draw(canvas, _glint, d * 1.25, k(Colors.white));
    canvas.restore();
  }

  /// A soft pool of [color] light, for a thing to stand in or a gap to glow.
  static void pool(
    Canvas canvas,
    Offset c,
    double r,
    Color color, {
    double alpha = 1,
  }) {
    if (alpha <= 0.005 || r <= 0) return;
    _p
      ..shader = _radial(
        6,
        r,
        color,
        () => ui.Gradient.radial(
          Offset.zero,
          r,
          [
            color.withValues(alpha: 0.5),
            color.withValues(alpha: 0.14),
            color.withValues(alpha: 0),
          ],
          const [0.0, 0.42, 1.0],
        ),
      )
      ..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0));
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.drawCircle(Offset.zero, r, _p);
    canvas.restore();
    _p.shader = null;
  }
}

/// A glyph painted on the shared [GlyphClock]: [painter] is handed the clock
/// while the glyph runs and null when it is still (a shelf's baked frame).
///
/// The clock is a bare ticker, deaf to TickerMode, so the glyph lets go of it
/// while a route covers it or a gated list has scrolled it away.
class GrainGlyph extends StatefulWidget {
  const GrainGlyph({
    super.key,
    required this.size,
    required this.animate,
    required this.painter,
  });

  final double size;
  final bool animate;
  final CustomPainter Function(ValueListenable<double>? clock) painter;

  @override
  State<GrainGlyph> createState() => _GrainGlyphState();
}

class _GrainGlyphState extends State<GrainGlyph> with GlyphClockLease {
  bool _visible = true;

  @override
  bool get wantsClock => widget.animate && _visible;

  // Not in initState: TickerMode is only readable here, and a glyph mounted
  // muted (a bake) must not start the clock even for a frame.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    syncGlyphClock();
  }

  @override
  void didUpdateWidget(covariant GrainGlyph oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncGlyphClock();
  }

  @override
  void dispose() {
    releaseGlyphClock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: CustomPaint(
      willChange: widget.animate,
      painter: widget.painter(glyphClock),
    ),
  );
}
