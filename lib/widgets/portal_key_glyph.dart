import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart' show GrainBatch;
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A rift key, drawn as the element condensing into the shape that opens the
/// way in: a lit key in its element's light, the element's essence in its
/// bow, and a small rift of grains turning behind it.
///
/// The five keys were five painted PNGs — 8MB between them, for something that
/// renders at 56px in a market row next to painted harvesters. Here the key is
/// one glyph tinted by its element, with the rift aperture turning behind it,
/// so all five match each other and the devices they are sold beside.
class PortalKeyGlyph extends StatefulWidget {
  const PortalKeyGlyph({
    super.key,
    required this.biomeId,
    required this.size,
    this.color,
    this.animate = true,
  });

  /// 'volcanic' | 'oceanic' | 'earthen' | 'verdant' | 'arcane'
  final String biomeId;
  final double size;

  /// Overrides the element's own color.
  final Color? color;

  /// Off for a still frame; a market row scrolling past does not need to run.
  final bool animate;

  /// The element a portal-key inventory key belongs to, or null for anything
  /// that is not one.
  static String? biomeForInventoryKey(String? inventoryKey) {
    const prefix = 'item.portal_key.';
    if (inventoryKey == null || !inventoryKey.startsWith(prefix)) return null;
    final biome = inventoryKey.substring(prefix.length);
    return ElementResources.byBiomeId.containsKey(biome) ? biome : null;
  }

  /// Paints the same key glyph directly onto an arbitrary canvas at
  /// [center] — for contexts with no widget tree, e.g. an in-world
  /// loot-drop pickup. [fade] multiplies every alpha.
  static void paintGlyph(
    Canvas canvas,
    Offset center,
    double size,
    Color color,
    double time, {
    double fade = 1.0,
  }) => _PortalKeyPainter.paintGlyph(
    canvas,
    center,
    size,
    color,
    time,
    fade: fade,
  );

  @override
  State<PortalKeyGlyph> createState() => _PortalKeyGlyphState();
}

class _PortalKeyGlyphState extends State<PortalKeyGlyph> with GlyphClockLease {
  @override
  bool get wantsClock => widget.animate;

  @override
  void initState() {
    super.initState();
    syncGlyphClock();
  }

  @override
  void didUpdateWidget(covariant PortalKeyGlyph oldWidget) {
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
    final tint =
        widget.color ??
        ElementResources.byBiomeId[widget.biomeId]?.color ??
        const Color(0xFFCBD5E1);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        willChange: widget.animate,
        isComplex: false,
        painter: _PortalKeyPainter(color: tint, clock: glyphClock),
      ),
    );
  }
}

class _PortalKeyPainter extends CustomPainter {
  _PortalKeyPainter({required this.color, required this.clock})
    : super(repaint: clock);

  final Color color;
  final ValueListenable<double>? clock;

  /// Reused across every frame and every glyph on screen.
  static final Paint _p = Paint();

  /// The key shape at one size. Cutting it every frame for five rows of icons
  /// is the allocation worth avoiding here.
  static final Map<int, Path> _keys = <int, Path>{};

  double get _t => clock?.value ?? 0;

  static double _seed(int i, int salt) => ((i * 31 + salt * 11) % 100) / 100.0;

  static Path _key(double s) => _keys.putIfAbsent(s.round(), () {
    // Bow at the top, shaft down the middle, two wards off the right.
    final shaft = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.468, s * 0.34, s * 0.532, s * 0.80),
      Radius.circular(s * 0.03),
    );
    final ward1 = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.532, s * 0.615, s * 0.655, s * 0.672),
      Radius.circular(s * 0.02),
    );
    final ward2 = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.532, s * 0.720, s * 0.622, s * 0.777),
      Radius.circular(s * 0.02),
    );

    var path = Path()..addRRect(shaft);
    path = Path.combine(PathOperation.union, path, Path()..addRRect(ward1));
    path = Path.combine(PathOperation.union, path, Path()..addRRect(ward2));

    // The bow is a ring, so the key reads as a key at 24px.
    final bow = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(s * 0.5, s * 0.295), radius: s * 0.135),
      )
      ..addOval(
        Rect.fromCircle(center: Offset(s * 0.5, s * 0.295), radius: s * 0.062),
      )
      ..fillType = PathFillType.evenOdd;

    return Path.combine(PathOperation.union, path, bow);
  });

  @override
  void paint(Canvas canvas, Size size) => paintGlyph(
    canvas,
    Offset(size.width / 2, size.height / 2),
    size.shortestSide,
    color,
    _t,
  );

  // Shaders cut once per size and color, at the origin, and drawn through a
  // translate: a market row of five keys was cutting five gradients a frame.
  static final Map<(int, int), Shader> _poolShaders = {};
  static final Map<(int, int), Shader> _bodyShaders = {};
  static final Map<(int, int), Shader> _beadShaders = {};

  static Shader _cached(
    Map<(int, int), Shader> cache,
    double s,
    Color c,
    Shader Function() make,
  ) => cache.putIfAbsent((s.round(), c.toARGB32()), make);

  // The little rift's grains, laid out once: a disk, not a hoop — spread
  // wide and thickest at its inner edge, with angles of their own so they
  // do not line up into spiral arms, and Kepler's pace (the inner edge
  // runs) so only a cos and a sin are left per grain per frame.
  static const int _diskN = 76;
  static final List<double> _diskRho = [
    for (var i = 0; i < _diskN; i++)
      0.27 + 0.25 * math.pow((i * 0.6180339) % 1.0, 1.6).toDouble(),
  ];
  static final List<double> _diskA0 = [
    for (var i = 0; i < _diskN; i++)
      ((i * 0.7548776 + (i * i) * 0.0131) % 1.0) * math.pi * 2,
  ];
  static final List<double> _diskW = [
    for (final rho in _diskRho) 0.9 / math.pow(rho / 0.3, 1.5).toDouble(),
  ];
  static final double _diskCos = math.cos(-0.42), _diskSin = math.sin(-0.42);

  /// Grains: the little rift's far half, its near half, its near half lit,
  /// and the motes drawn in to the bow.
  static final GrainBatch _grains = GrainBatch(4);

  /// The paint's alpha scales its shader: how [fade] reaches the gradients.
  static Color _alpha(double f) => Color.fromRGBO(0, 0, 0, f);

  /// Paints the key glyph directly onto an arbitrary canvas at [center] —
  /// for contexts with no widget tree, e.g. an in-world loot-drop pickup.
  /// [fade] multiplies every alpha, for a drop that's fading out.
  ///
  /// The key stands in its element's light, in front of a small rift of
  /// grains turning on a tipped disk — the rift it opens, as every rift in
  /// the game is drawn — with the element's essence glowing in its bow and,
  /// now and then, a glint running down it. Material, not outline: the old
  /// key was a flat shape with a white rim inside a dashed hoop.
  static void paintGlyph(
    Canvas canvas,
    Offset center,
    double s,
    Color color,
    double t, {
    double fade = 1.0,
  }) {
    if (s <= 0) return;
    final f = fade.clamp(0.0, 1.0);
    if (f <= 0) return;
    final bright = Color.lerp(color, Colors.white, 0.55)!;
    final deep = Color.lerp(color, Colors.black, 0.6)!;
    final g = _grains..clear();

    canvas.save();
    canvas.translate(center.dx, center.dy);

    // ── the light it stands in ──
    final poolR = s * 0.5;
    _p
      ..shader = _cached(
        _poolShaders,
        s,
        color,
        () => ui.Gradient.radial(
          Offset.zero,
          poolR,
          [
            color.withValues(alpha: 0.24),
            color.withValues(alpha: 0.07),
            color.withValues(alpha: 0),
          ],
          const [0.0, 0.5, 1.0],
        ),
      )
      ..color = _alpha(f);
    canvas.drawCircle(Offset.zero, poolR, _p);
    _p.shader = null;

    // ── the rift behind it, in grains ── (too small to read below ~30px)
    if (s >= 30) {
      const flat = 0.32;
      for (var i = 0; i < _diskN; i++) {
        final a = _diskA0[i] + t * _diskW[i];
        final sn = math.sin(a);
        final rho = _diskRho[i];
        final x0 = math.cos(a) * rho * s, y0 = sn * rho * s * flat;
        final lit = math.sin(t * 2.3 + i * 1.7) > 0.72;
        g.add(
          sn > 0 ? (lit ? 2 : 1) : 0,
          x0 * _diskCos - y0 * _diskSin,
          x0 * _diskSin + y0 * _diskCos,
        );
      }
    }

    // ── the element, drawn in to the bow ──
    final bow = Offset(0, s * (0.295 - 0.5));
    for (var i = 0; i < 9; i++) {
      final phase = (t * 0.32 + _seed(i, 1)) % 1.0;
      if (phase < 0.08 || phase > 0.9) continue;
      final pull = Curves.easeInCubic.transform(phase);
      final dist = s * (0.46 - 0.36 * pull);
      final a = _seed(i, 2) * math.pi * 2 + phase * 1.6;
      g.add(3, bow.dx + math.cos(a) * dist, bow.dy + math.sin(a) * dist * 0.8);
    }

    final d = (s * 0.028).clamp(1.0, 2.2);
    g.draw(canvas, 0, d * 0.85, color.withValues(alpha: 0.42 * f));

    // ── the key ──
    canvas.save();
    canvas.translate(-s / 2, -s / 2);
    final key = _key(s);
    // Its edge, a shade under the body and off down-right: a key with some
    // thickness to it, instead of a white outline.
    canvas.save();
    canvas.translate(s * 0.013, s * 0.018);
    _p.color = deep.withValues(alpha: 0.92 * f);
    canvas.drawPath(key, _p);
    canvas.restore();
    _p
      ..shader = _cached(
        _bodyShaders,
        s,
        color,
        () => LinearGradient(
          begin: const Alignment(-0.45, -1),
          end: const Alignment(0.45, 1),
          colors: [bright, color, Color.lerp(color, Colors.black, 0.32)!],
          stops: const [0.0, 0.46, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, s, s)),
      )
      ..color = _alpha(f);
    canvas.drawPath(key, _p);
    _p.shader = null;

    // The essence in the bow, breathing.
    final beadR = s * 0.056 * (0.88 + 0.12 * math.sin(t * 2.1));
    canvas.save();
    canvas.translate(s * 0.5, s * 0.295);
    _p
      ..shader = _cached(
        _beadShaders,
        s,
        color,
        () => ui.Gradient.radial(
          Offset.zero,
          s * 0.062,
          [
            const Color(0xFFFFFFFF),
            Color.lerp(color, Colors.white, 0.4)!,
            color.withValues(alpha: 0.85),
          ],
          const [0.0, 0.45, 1.0],
        ),
      )
      ..color = _alpha(f);
    canvas.drawCircle(Offset.zero, beadR, _p);
    _p.shader = null;
    canvas.restore();

    // Now and then a glint runs down it. Each color keeps its own time, so
    // a row of five does not flash together.
    final cycle = ((t + (color.toARGB32() % 7) * 0.53) % 3.6) / 3.6;
    if (cycle < 0.16 && s >= 20) {
      final u = cycle / 0.16;
      final y = s * (0.1 + 0.82 * u);
      final band = s * 0.09;
      canvas.save();
      canvas.clipPath(key);
      _p
        ..shader = ui.Gradient.linear(
          Offset(0, y - band),
          Offset(0, y + band),
          [
            const Color(0x00FFFFFF),
            Colors.white.withValues(alpha: 0.55 * math.sin(math.pi * u) * f),
            const Color(0x00FFFFFF),
          ],
          const [0.0, 0.5, 1.0],
        )
        ..color = const Color(0xFF000000);
      canvas.drawRect(Rect.fromLTWH(0, y - band, s, band * 2), _p);
      _p.shader = null;
      canvas.restore();
    }
    canvas.restore();

    // ── the rift's near half, in front of the key, and the motes ──
    g.draw(
      canvas,
      1,
      d,
      Color.lerp(color, Colors.white, 0.2)!.withValues(alpha: 0.8 * f),
    );
    g.draw(canvas, 2, d * 1.15, bright.withValues(alpha: f));
    g.draw(canvas, 3, d * 1.1, bright.withValues(alpha: 0.85 * f));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PortalKeyPainter old) =>
      old.color != color || old.clock != clock;
}
