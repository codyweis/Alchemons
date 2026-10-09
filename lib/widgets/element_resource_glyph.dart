import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart' show GrainBatch;
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A resource drawn as the essence the harvest chambers collect: fine lit
/// grains in the element's own form, over a soft body of light.
///
/// Volcanic is a flame of embers, Oceanic a drop of turning water, Earthen a
/// settled heap with grains trickling down it, Verdant a leaf its sap runs
/// along, Arcane a core with comets on two tipped orbits. The silhouette
/// carries it at a 15px chip; the motion carries it anywhere bigger. Points
/// in batches and cached gradients — no blur, no stroked rings.
class ElementResourceGlyph extends StatefulWidget {
  /// Takes the biome id and color rather than a resource object, because the
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

class _ElementResourceGlyphState extends State<ElementResourceGlyph>
    with GlyphClockLease {
  @override
  bool get wantsClock => widget.animate;

  @override
  void initState() {
    super.initState();
    syncGlyphClock();
  }

  @override
  void didUpdateWidget(covariant ElementResourceGlyph oldWidget) {
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
          clock: glyphClock,
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
  static final GrainBatch _b = GrainBatch(8);

  /// Gradients, built once per element, size and color: the essence's
  /// body of light does not move with its grains.
  static final Map<(int, int, int), ui.Shader> _shaders = {};

  static ui.Shader _shader(
    int kind,
    double s,
    Color c,
    ui.Shader Function() make,
  ) => _shaders.putIfAbsent((kind, (s * 4).round(), c.toARGB32()), make);

  // Buckets: deep, body, lit, hot; then a wide faint light pass, a fading
  // body, a fading lit, and white glints.
  static const int _deep = 0, _body = 1, _lit = 2, _hot = 3;
  static const int _wide = 4, _fadeBody = 5, _fadeLit = 6, _white = 7;

  double get _t => clock?.value ?? 0;

  /// Stable per-grain spread, so a glyph looks the same every time it is
  /// built rather than reshuffling on scroll.
  static double _h(int i, int salt) {
    final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  /// How many grains fill [share] of a box [s] across at grain [g].
  static int _count(double s, double g, double share, {int max = 360}) =>
      (share * s * s / (g * g * 2.2)).round().clamp(26, max);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);

    if (glow > 0) _halo(canvas, s);

    // Fine where there is room, a touch coarser at the 15px chips so a
    // grain is still a grain.
    final g = (s * 0.03).clamp(0.9, 2.1);
    _b.clear();
    switch (biomeId) {
      case 'volcanic':
        _flame(canvas, s, g);
      case 'oceanic':
        _drop(canvas, s, g);
      case 'earthen':
        _heap(canvas, s, g);
      case 'arcane':
        _orbits(canvas, s, g);
      default:
        _leaf(canvas, s, g);
    }
    canvas.restore();
  }

  /// The pool of light the essence sits in: one radial gradient that stops
  /// inside the box, so no ancestor's clip can slice it.
  void _halo(Canvas canvas, double s) {
    final r = s * 0.5;
    _p.shader = _shader(
      0,
      s,
      color,
      () => ui.Gradient.radial(
        Offset(r, r),
        r,
        [
          color.withValues(alpha: 0.24),
          color.withValues(alpha: 0.07),
          color.withValues(alpha: 0),
        ],
        const [0.0, 0.5, 1.0],
      ),
    );
    _p.color = Color.fromRGBO(0, 0, 0, glow.clamp(0.0, 1.0));
    canvas.drawCircle(Offset(r, r), r, _p);
    _p
      ..shader = null
      ..color = const Color(0xFF000000);
  }

  /// The essence's tones, deep to white.
  List<Color> get _tones => [
    Color.lerp(color, const Color(0xFF07060B), 0.45)!,
    color,
    Color.lerp(color, Colors.white, 0.38)!,
    Color.lerp(color, Colors.white, 0.72)!,
  ];

  /// Draws the batch: a wide faint pass under the bright grains so they
  /// read as light, then each tone.
  void _drawGrains(Canvas canvas, double g) {
    final t = _tones;
    _b.draw(canvas, _wide, g * 2.8, color.withValues(alpha: 0.12));
    _b.draw(canvas, _deep, g, t[0].withValues(alpha: 0.95));
    _b.draw(canvas, _body, g, t[1]);
    _b.draw(canvas, _fadeBody, g * 0.9, t[1].withValues(alpha: 0.45));
    _b.draw(canvas, _lit, g * 1.05, t[2]);
    _b.draw(canvas, _fadeLit, g, t[2].withValues(alpha: 0.5));
    _b.draw(canvas, _hot, g * 1.1, t[3]);
    _b.draw(canvas, _white, g * 1.25, Color.lerp(t[3], Colors.white, 0.6)!);
    _b.clear();
  }

  /// Fills [path] with [shader] (the essence's body of light).
  void _wash(Canvas canvas, Path path, ui.Shader shader) {
    _p.shader = shader;
    canvas.drawPath(path, _p);
    _p.shader = null;
  }

  // ── volcanic: a flame of embers ────────────────────────────────────────

  /// Embers rising through a flame — round at its root, drawn up into a
  /// tip that licks from side to side — and the odd one breaking off it.
  void _flame(Canvas canvas, double s, double g) {
    final t = _t;
    final r = s * 0.24;
    final at = Offset(s / 2, s * 0.66);
    final lick = math.sin(t * 2.3) * r * 0.32 + math.sin(t * 5.1) * r * 0.08;
    // A unit-disc point in the flame: the drop's shape, its tip leaning
    // with the lick.
    Offset flameAt(double dx, double dy) {
      final pt = _dropAt(dx, dy, at, r);
      final up = dy < 0 ? -dy : 0.0;
      return pt + Offset(lick * up * up, 0);
    }

    final body = Path();
    for (var k = 0; k <= 32; k++) {
      final a = k / 32 * math.pi * 2;
      final pt = flameAt(math.sin(a), -math.cos(a));
      k == 0 ? body.moveTo(pt.dx, pt.dy) : body.lineTo(pt.dx, pt.dy);
    }
    body.close();
    _wash(
      canvas,
      body,
      _shader(
        1,
        s,
        color,
        () => ui.Gradient.radial(
          at + Offset(0, r * 0.45),
          r * 2.2,
          [
            Color.lerp(color, Colors.white, 0.65)!.withValues(alpha: 0.6),
            color.withValues(alpha: 0.38),
            color.withValues(alpha: 0.0),
          ],
          const [0.0, 0.4, 1.0],
        ),
      ),
    );

    final n = _count(s, g, 0.16);
    for (var i = 0; i < n; i++) {
      final rise = (t * (0.45 + 0.35 * _h(i, 1)) + _h(i, 2)) % 1.0;
      final dy = 1 - 2 * rise;
      final across = (2 * _h(i, 4) - 1) * 0.92;
      final width = math.sqrt(math.max(0.0, 1 - dy * dy));
      final pt = flameAt(across * width, dy);
      final core = 1 - across.abs();
      final int b;
      if (rise < 0.05) {
        b = _fadeLit;
      } else if (rise < 0.45 && core > 0.4) {
        b = _hot;
      } else if (rise < 0.65) {
        b = _lit;
      } else if (rise < 0.88) {
        b = _body;
      } else {
        b = _fadeBody;
      }
      _b.add(b, pt.dx, pt.dy);
      if (b == _hot && i.isEven) _b.add(_wide, pt.dx, pt.dy);
    }
    // Embers breaking off the tip.
    final tip = flameAt(0, -1);
    for (var i = 0; i < 3; i++) {
      final p = (t * 0.45 + i / 3 + _h(i, 9) * 0.2) % 1.0;
      final y = tip.dy + r * 0.2 - p * s * 0.2;
      final x = tip.dx + math.sin(t * 3 + i * 2.1) * s * 0.07 * p;
      _b.add(p < 0.6 ? _lit : _fadeLit, x, y);
    }
    _drawGrains(canvas, g);
  }

  // ── oceanic: a drop of water ───────────────────────────────────────────

  /// A unit-disc point turned into the drop: the top half drawn up into a
  /// point.
  static Offset _dropAt(double dx, double dy, Offset at, double r) {
    if (dy < 0) {
      final k = math.pow(1 + dy, 0.8).toDouble();
      return at + Offset(dx * k * r, dy * 1.75 * r);
    }
    return at + Offset(dx * r, dy * r);
  }

  /// Water turning slowly inside a drop, lit from the upper left, with a
  /// bead of it falling in now and then.
  void _drop(Canvas canvas, double s, double g) {
    final t = _t;
    final r = s * 0.27;
    final at = Offset(s / 2, s * 0.6);
    final body = Path();
    for (var k = 0; k <= 32; k++) {
      final a = k / 32 * math.pi * 2;
      final pt = _dropAt(math.sin(a), -math.cos(a), at, r);
      k == 0 ? body.moveTo(pt.dx, pt.dy) : body.lineTo(pt.dx, pt.dy);
    }
    body.close();
    _wash(
      canvas,
      body,
      _shader(
        2,
        s,
        color,
        () => ui.Gradient.radial(
          at + Offset(-r * 0.35, -r * 0.4),
          r * 1.5,
          [
            Color.lerp(color, Colors.white, 0.3)!.withValues(alpha: 0.5),
            color.withValues(alpha: 0.32),
            Color.lerp(color, Colors.black, 0.5)!.withValues(alpha: 0.5),
          ],
          const [0.0, 0.5, 1.0],
        ),
      ),
    );

    final n = _count(s, g, 0.2);
    for (var i = 0; i < n; i++) {
      final rho = math.sqrt(_h(i, 11)) * 0.94;
      final a = _h(i, 12) * math.pi * 2 + t * (0.3 + 0.4 * _h(i, 13));
      final dx = math.sin(a) * rho, dy = -math.cos(a) * rho;
      final pt = _dropAt(dx, dy, at, r);
      // Lit from the upper left; the far edge goes deep.
      final light = 0.5 - 0.42 * dx - 0.5 * dy;
      final glint = (t * 0.35 + _h(i, 14) * 6) % 1.0 < 0.02;
      _b.add(
        glint
            ? _white
            : light > 0.85
            ? _lit
            : light > 0.4
            ? _body
            : _deep,
        pt.dx,
        pt.dy,
      );
    }
    // The catchlight: a few still grains high on the left.
    for (var i = 0; i < 4; i++) {
      final pt = _dropAt(-0.5 + i * 0.07, -0.25 - i * 0.12, at, r);
      _b.add(i < 2 ? _hot : _lit, pt.dx, pt.dy);
    }
    // A bead falling into its point.
    final p = (t / 2.4) % 1.0;
    if (p < 0.5) {
      final y = s * 0.02 + (at.dy - r * 1.75 - s * 0.02) * (p / 0.5);
      _b.add(_fadeLit, at.dx, y);
    }
    _drawGrains(canvas, g);
  }

  // ── earthen: a heap ────────────────────────────────────────────────────

  /// A settled heap of grains lit from the upper left, with a few more
  /// trickling down onto it and running down its slopes.
  void _heap(Canvas canvas, double s, double g) {
    final t = _t;
    final foot = s * 0.82, peakX = s * 0.48, peakY = s * 0.4;
    final half = s * 0.42;
    double top(double x) {
      final u = ((x - peakX).abs() / half).clamp(0.0, 1.0);
      // A soft mound, not a cone: grains settle round at the top.
      return foot -
          (foot - peakY) * math.pow(0.5 + 0.5 * math.cos(math.pi * u), 0.85);
    }

    final body = Path()..moveTo(peakX - half, foot);
    for (var k = 1; k < 16; k++) {
      final x = peakX - half + 2 * half * k / 16;
      body.lineTo(x, top(x));
    }
    body
      ..lineTo(peakX + half, foot)
      ..close();
    _wash(
      canvas,
      body,
      _shader(
        3,
        s,
        color,
        () => ui.Gradient.linear(
          Offset(peakX - half * 0.6, peakY),
          Offset(peakX + half * 0.5, foot),
          [
            Color.lerp(color, Colors.white, 0.4)!.withValues(alpha: 0.5),
            color.withValues(alpha: 0.42),
            Color.lerp(color, Colors.black, 0.55)!.withValues(alpha: 0.55),
          ],
          const [0.0, 0.45, 1.0],
        ),
      ),
    );

    final n = _count(s, g, 0.28);
    for (var i = 0; i < n; i++) {
      final x = peakX + (2 * _h(i, 21) - 1) * half * 0.97;
      final yt = top(x);
      final d = math.pow(_h(i, 22), 1.4).toDouble();
      final y = yt + g * 0.5 + (foot - yt - g) * d;
      // The slope facing the light, and the skin of the heap, are lit.
      final left = x < peakX;
      final twinkle = (t * 0.25 + _h(i, 23) * 5) % 1.0 < 0.025;
      _b.add(
        twinkle
            ? _hot
            : d < 0.15
            ? (left ? _lit : _body)
            : d < 0.55
            ? (left ? _body : _deep)
            : _deep,
        x,
        y,
      );
    }
    // Grains trickling down onto the peak and running off down a slope.
    for (var i = 0; i < 4; i++) {
      final p = (t * 0.32 + i / 4) % 1.0;
      final side = i.isEven ? -1.0 : 1.0;
      if (p < 0.3) {
        final y = s * 0.06 + (peakY - s * 0.06 - g) * (p / 0.3);
        _b.add(_fadeLit, peakX + side * g * 0.8, y);
      } else if (p < 0.9) {
        final q = (p - 0.3) / 0.6;
        final x = peakX + side * half * 0.92 * q * (0.6 + 0.4 * q);
        _b.add(_lit, x, top(x) - g * 0.55);
      } else {
        final x = peakX + side * half * 0.92;
        _b.add(_fadeBody, x, top(x) - g * 0.55);
      }
    }
    _drawGrains(canvas, g);
  }

  // ── verdant: a leaf ────────────────────────────────────────────────────

  /// A leaf of grains on a short stem, its sap running out to the tip and
  /// spores lifting off it, swaying a little.
  void _leaf(Canvas canvas, double s, double g) {
    final t = _t;
    final base = Offset(s * 0.3, s * 0.8);
    final dir = Offset(0.6, -0.8);
    final perp = Offset(0.8, 0.6);
    final len = s * 0.72;
    double width(double u) =>
        s * 0.18 * math.pow(math.sin(math.pi * math.pow(u, 0.8)), 0.9);
    Offset at(double u, double v) =>
        base +
        dir * (len * u) +
        perp * (math.sin(math.pi * u) * s * 0.05 + v * width(u));

    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(math.sin(t * 1.1) * 0.06);
    canvas.translate(-base.dx, -base.dy);

    final body = Path();
    for (var k = 0; k <= 16; k++) {
      final pt = at(k / 16, -1);
      k == 0 ? body.moveTo(pt.dx, pt.dy) : body.lineTo(pt.dx, pt.dy);
    }
    for (var k = 16; k >= 0; k--) {
      final pt = at(k / 16, 1);
      body.lineTo(pt.dx, pt.dy);
    }
    body.close();
    _wash(
      canvas,
      body,
      _shader(
        4,
        s,
        color,
        () => ui.Gradient.linear(
          base,
          base + dir * len,
          [
            Color.lerp(color, Colors.black, 0.4)!.withValues(alpha: 0.5),
            color.withValues(alpha: 0.4),
            Color.lerp(color, Colors.white, 0.3)!.withValues(alpha: 0.45),
          ],
          const [0.0, 0.5, 1.0],
        ),
      ),
    );

    final n = _count(s, g, 0.16);
    for (var i = 0; i < n; i++) {
      final u = (_h(i, 31) + t * 0.07 * (0.6 + 0.8 * _h(i, 32))) % 1.0;
      final v = (2 * _h(i, 33) - 1) * 0.94;
      final pt = at(u, v);
      final int b;
      if (u < 0.05 || u > 0.95) {
        b = _fadeBody;
      } else if (v.abs() < 0.12) {
        b = _hot; // the midrib
      } else if (v.abs() > 0.82) {
        b = _deep;
      } else {
        b = v < 0 ? _lit : _body;
      }
      _b.add(b, pt.dx, pt.dy);
    }
    // The stem.
    for (var k = 0; k < 5; k++) {
      final q = k / 4;
      _b.add(
        _deep,
        base.dx - s * 0.05 * q - s * 0.02 * q * q,
        base.dy + s * 0.13 * q,
      );
    }
    _drawGrains(canvas, g);
    canvas.restore();

    // Spores lifting off it.
    for (var i = 0; i < 3; i++) {
      final p = (t * 0.28 + i / 3) % 1.0;
      final from = at(0.45 + 0.2 * i, i.isEven ? -0.6 : 0.6);
      _b.add(
        p < 0.65 ? _lit : _fadeLit,
        from.dx + math.sin(t * 1.6 + i * 2) * s * 0.05,
        from.dy - p * s * 0.3,
      );
    }
    _drawGrains(canvas, g);
  }

  // ── arcane: a core and its orbits ──────────────────────────────────────

  /// A bright core, with grains running round it on two tipped orbits as
  /// comets with tails — the far side of each behind the core.
  void _orbits(Canvas canvas, double s, double g) {
    final t = _t;
    final c = Offset(s / 2, s / 2);
    final tail = (s * 0.35).clamp(6.0, 18.0).round();

    void orbit(bool front) {
      for (var ring = 0; ring < 2; ring++) {
        final a = s * (ring == 0 ? 0.38 : 0.3);
        final tilt = ring == 0 ? -0.45 : 0.6;
        final dir = ring == 0 ? 1.0 : -1.0;
        final ct = math.cos(tilt), st = math.sin(tilt);
        for (var k = 0; k < 2; k++) {
          final head = dir * t * (1.1 - ring * 0.25) + k * math.pi + ring;
          for (var j = 0; j < tail; j++) {
            final th = head - dir * j * 0.11;
            final sn = math.sin(th);
            // Behind the core where the orbit goes away from us.
            if ((sn < 0) == front) continue;
            final ox = math.cos(th) * a, oy = sn * a * 0.36;
            final x = c.dx + ox * ct - oy * st;
            final y = c.dy + ox * st + oy * ct;
            final f = j / tail;
            final int b;
            if (!front) {
              b = f < 0.4 ? _body : (f < 0.7 ? _deep : _fadeBody);
            } else if (j == 0) {
              b = _white;
            } else {
              b = f < 0.3 ? _hot : (f < 0.6 ? _lit : _fadeLit);
            }
            _b.add(b, x, y);
            if (j == 0 && front) _b.add(_wide, x, y);
          }
        }
      }
    }

    orbit(false);
    _drawGrains(canvas, g);

    // The core: a ball of light with grains turning in it.
    final cr = s * 0.21;
    _p.shader = _shader(
      5,
      s,
      color,
      () => ui.Gradient.radial(
        c,
        cr,
        [
          Color.lerp(color, Colors.white, 0.75)!,
          Color.lerp(color, Colors.white, 0.2)!.withValues(alpha: 0.6),
          color.withValues(alpha: 0),
        ],
        const [0.0, 0.35, 1.0],
      ),
    );
    canvas.drawCircle(c, cr, _p);
    _p.shader = null;
    final cn = (s * 0.6).clamp(10.0, 40.0).round();
    for (var i = 0; i < cn; i++) {
      final a = _h(i, 41) * math.pi * 2 + t * (0.8 + _h(i, 42));
      final rr = s * 0.1 * math.sqrt(_h(i, 43));
      _b.add(
        _h(i, 44) < 0.3 ? _white : _hot,
        c.dx + math.cos(a) * rr,
        c.dy + math.sin(a) * rr * 0.8,
      );
    }
    orbit(true);
    _drawGrains(canvas, g);
  }

  @override
  bool shouldRepaint(covariant _ElementParticlePainter old) =>
      old.biomeId != biomeId ||
      old.color != color ||
      old.glow != glow ||
      old.clock != clock;
}
