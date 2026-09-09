import 'dart:math' as math;

import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A rift key, drawn as the element condensing into the shape that opens the
/// way in.
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

  /// Overrides the element's own colour.
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
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final c = Offset(size.width / 2, size.height / 2);

    _aperture(canvas, c, s);
    _motes(canvas, c, s);

    final key = _key(s);
    final bounds = Rect.fromLTWH(0, 0, s, s);
    final bright = Color.lerp(color, Colors.white, 0.55)!;

    canvas.drawPath(
      key,
      _p
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bright, color, Color.lerp(color, Colors.black, 0.45)!],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(bounds),
    );
    _p.shader = null;

    canvas.drawPath(
      key,
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.016
        ..strokeJoin = StrokeJoin.round
        ..color = Color.lerp(bright, Colors.white, 0.5)!.withValues(alpha: 0.9),
    );
    _p.style = PaintingStyle.fill;
  }

  /// The rift the key is for: a broken ring, turning.
  void _aperture(Canvas canvas, Offset c, double s) {
    final r = s * 0.415;
    final spin = _t * 0.42;
    // Breathes, so a still row of five is not five identical frozen rings.
    final pulse = 0.72 + 0.14 * math.sin(_t * 1.3);

    canvas.drawCircle(
      c,
      r * 0.86,
      _p..color = color.withValues(alpha: 0.07),
    );

    final rect = Rect.fromCircle(center: c, radius: r);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.030
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final start = spin + i * math.pi * 2 / 5;
      canvas.drawArc(
        rect,
        start,
        0.62,
        false,
        _p..color = color.withValues(alpha: 0.28 * pulse + 0.10),
      );
    }
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt;
  }

  /// Element being drawn out of the rift and into the key.
  void _motes(Canvas canvas, Offset c, double s) {
    final bright = Color.lerp(color, Colors.white, 0.45)!;
    for (var i = 0; i < 8; i++) {
      final phase = (_t * 0.30 + _seed(i, 1)) % 1.0;
      // Rim inward, so the key looks like it is being charged by the rift.
      final pull = Curves.easeInCubic.transform(phase);
      final dist = s * (0.44 - 0.30 * pull);
      final a = _seed(i, 2) * math.pi * 2 + phase * 1.4;
      final fade =
          (phase < 0.15 ? phase / 0.15 : 1.0) *
          (phase > 0.82 ? (1 - phase) / 0.18 : 1.0);
      if (fade <= 0.02) continue;
      canvas.drawCircle(
        c + Offset(math.cos(a) * dist, math.sin(a) * dist),
        s * (0.020 - 0.008 * pull),
        _p..color = bright.withValues(alpha: 0.75 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PortalKeyPainter old) =>
      old.color != color || old.clock != clock;
}
