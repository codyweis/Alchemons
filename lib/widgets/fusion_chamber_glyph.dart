import 'dart:math' as math;

import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// An extra Alchemy Chamber, drawn as the chambers themselves.
///
/// The offer was borrowing the cold-storage art — a disc of eggs — which put
/// the wrong concept and the wrong noun on it twice over: fusion results are
/// particle cultivations, and the honeycomb next to it is the one that means
/// capacity in cells. This says the other thing capacity can mean: you had
/// two chambers running, here is a third coming online.
class FusionChamberGlyph extends StatefulWidget {
  const FusionChamberGlyph({
    super.key,
    required this.size,
    this.animate = true,
  });

  final double size;

  /// Off for a still frame; a shop card scrolling past does not need to run.
  final bool animate;

  @override
  State<FusionChamberGlyph> createState() => _FusionChamberGlyphState();
}

class _FusionChamberGlyphState extends State<FusionChamberGlyph>
    with GlyphClockLease {
  @override
  bool get wantsClock => widget.animate;

  @override
  void initState() {
    super.initState();
    syncGlyphClock();
  }

  @override
  void didUpdateWidget(covariant FusionChamberGlyph oldWidget) {
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
        willChange: widget.animate,
        isComplex: false,
        painter: _FusionChamberPainter(clock: glyphClock),
      ),
    );
  }
}

class _FusionChamberPainter extends CustomPainter {
  _FusionChamberPainter({required this.clock}) : super(repaint: clock);

  final ValueListenable<double>? clock;

  /// Reused across every frame and every glyph on screen.
  static final Paint _p = Paint();

  /// One ignition and settle of the new chamber.
  static const double _period = 4.6;

  /// Where the loop starts. A still glyph sits at t = 0 and the shop grid
  /// bakes that frame, so it starts with the third chamber already lit —
  /// three running chambers is the thing being sold.
  static const double _stillPhase = 0.52;

  static const _rim = Color(0xFFE0A231);
  static const _wall = Color(0xFF11151C);

  /// Two of the running chambers brew different lineages; the colours come
  /// from the element resources so the cultivations match the ones in the
  /// nursery.
  static final List<Color> _brews = [
    ElementResources.byBiomeId['arcane']!.color,
    ElementResources.byBiomeId['oceanic']!.color,
    ElementResources.byBiomeId['volcanic']!.color,
  ];

  double get _t => clock?.value ?? 0;

  static double _seed(int i, int salt) => ((i * 53 + salt * 29) % 100) / 100.0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final c = Offset(size.width / 2, size.height / 2);
    final beat = ((_t / _period) + _stillPhase) % 1.0;

    final r = s * 0.232;
    final d = s * 0.268;

    // Two established chambers on top, the new one below them.
    final centres = <Offset>[
      c + Offset(-d * 0.94, -d * 0.54),
      c + Offset(d * 0.94, -d * 0.54),
      c + Offset(0, d * 1.05),
    ];

    // The third comes online partway through the loop and stays lit for most
    // of it, so the icon spends its time showing three chambers, not two.
    final double online;
    if (beat < 0.16) {
      online = 0;
    } else if (beat < 0.36) {
      online = Curves.easeOutCubic.transform((beat - 0.16) / 0.20);
    } else if (beat < 0.90) {
      online = 1;
    } else {
      online = 1 - Curves.easeInCubic.transform((beat - 0.90) / 0.10);
    }

    for (var i = 0; i < 3; i++) {
      _chamber(canvas, centres[i], r, s, _brews[i], i, i == 2 ? online : 1.0);
    }
  }

  void _chamber(
    Canvas canvas,
    Offset centre,
    double r,
    double s,
    Color brew,
    int index,
    double lit,
  ) {
    // The chamber wall. Round, like the cultivation stage in the nursery.
    canvas.drawCircle(centre, r, _p..color = _wall);

    if (lit > 0.02) {
      // The cultivation inside: a core with its particles turning around it.
      canvas.drawCircle(
        centre,
        r * 0.92,
        _p..color = brew.withValues(alpha: 0.13 * lit),
      );

      final spin = _t * (0.55 + 0.12 * index) + index * 1.7;
      for (var k = 0; k < 5; k++) {
        final a = spin + k * math.pi * 2 / 5;
        final orbit = r * (0.40 + 0.24 * _seed(k, index + 1));
        final p = centre + Offset(math.cos(a) * orbit, math.sin(a) * orbit);
        canvas.drawCircle(
          p,
          s * 0.017 * lit,
          _p
            ..color = Color.lerp(
              brew,
              Colors.white,
              0.4,
            )!.withValues(alpha: 0.9 * lit),
        );
      }

      canvas.drawCircle(
        centre,
        r * 0.20 * (0.85 + 0.15 * lit),
        _p..color = Color.lerp(brew, Colors.white, 0.7)!.withValues(
          alpha: 0.95 * lit,
        ),
      );
    }

    // The rim. Dim while the chamber is cold, gold once it is running.
    canvas.drawCircle(
      centre,
      r,
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.020
        ..color = Color.lerp(
          const Color(0xFF3A424F),
          _rim,
          lit,
        )!.withValues(alpha: 0.45 + 0.55 * lit),
    );
    _p.style = PaintingStyle.fill;
  }

  @override
  bool shouldRepaint(covariant _FusionChamberPainter old) => old.clock != clock;
}
