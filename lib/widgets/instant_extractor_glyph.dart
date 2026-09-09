import 'dart:math' as math;

import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The Instant Fusion Extractor, drawn as the thing it skips.
///
/// A chamber's progress arc races the whole way round, the cultivation inside
/// collapses to its fused core, and the rim flashes — the wait, compressed
/// into a second. It shares the round chamber and gold rim of
/// [FusionChamberGlyph] on purpose: one buys you a chamber, this one finishes
/// what is in it, and they should look related without looking alike.
class InstantExtractorGlyph extends StatefulWidget {
  const InstantExtractorGlyph({
    super.key,
    required this.size,
    this.animate = true,
  });

  final double size;

  /// Off for a still frame; a shop card scrolling past does not need to run.
  final bool animate;

  @override
  State<InstantExtractorGlyph> createState() => _InstantExtractorGlyphState();
}

class _InstantExtractorGlyphState extends State<InstantExtractorGlyph>
    with GlyphClockLease {
  @override
  bool get wantsClock => widget.animate;

  @override
  void initState() {
    super.initState();
    syncGlyphClock();
  }

  @override
  void didUpdateWidget(covariant InstantExtractorGlyph oldWidget) {
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
        painter: _InstantExtractorPainter(clock: glyphClock),
      ),
    );
  }
}

class _InstantExtractorPainter extends CustomPainter {
  _InstantExtractorPainter({required this.clock}) : super(repaint: clock);

  final ValueListenable<double>? clock;

  /// Reused across every frame and every glyph on screen.
  static final Paint _p = Paint();

  /// One sweep and flash.
  static const double _period = 2.8;

  /// Where the loop starts. A still glyph sits at t = 0 and the shop grid
  /// bakes that frame, so it starts just past the flash: arc complete, core
  /// hot. A blank chamber would say nothing about the item.
  static const double _stillPhase = 0.70;

  static const _rim = Color(0xFFE0A231);
  static const _rimHot = Color(0xFFFFE9A8);
  static const _wall = Color(0xFF11151C);

  static final Color _brew = ElementResources.byBiomeId['arcane']!.color;

  double get _t => clock?.value ?? 0;

  static double _seed(int i, int salt) => ((i * 59 + salt * 23) % 100) / 100.0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final c = Offset(size.width / 2, size.height / 2);
    final beat = ((_t / _period) + _stillPhase) % 1.0;
    final r = s * 0.38;

    // The sweep is the point: it starts slow, like a real timer, then runs
    // away with itself.
    final double sweep;
    final double flash;
    if (beat < 0.62) {
      sweep = Curves.easeInExpo.transform(beat / 0.62);
      flash = 0;
    } else if (beat < 0.78) {
      sweep = 1;
      flash = 1 - (beat - 0.62) / 0.16;
    } else {
      sweep = 1;
      flash = 0;
    }
    // How finished the brew looks: loose particles at the start, one fused
    // core once the sweep lands.
    final fused = Curves.easeInCubic.transform(sweep);

    canvas.drawCircle(c, r, _p..color = _wall);
    canvas.drawCircle(
      c,
      r * 0.96,
      _p..color = _brew.withValues(alpha: 0.10 + 0.10 * fused),
    );

    _particles(canvas, c, r, s, fused);
    _core(canvas, c, r, fused, flash);
    _track(canvas, c, r, s, sweep, flash);
  }

  /// The cultivation being pulled in to finish.
  void _particles(Canvas canvas, Offset c, double r, double s, double fused) {
    final spread = 1 - fused;
    if (spread <= 0.02) return;
    for (var i = 0; i < 9; i++) {
      final a = _seed(i, 1) * math.pi * 2 + _t * 1.1;
      final orbit = r * (0.28 + 0.44 * _seed(i, 3)) * spread;
      final p = c + Offset(math.cos(a) * orbit, math.sin(a) * orbit);
      canvas.drawCircle(
        p,
        s * 0.018 * spread,
        _p
          ..color = Color.lerp(
            _brew,
            Colors.white,
            0.35,
          )!.withValues(alpha: 0.85 * spread),
      );
    }
  }

  void _core(Canvas canvas, Offset c, double r, double fused, double flash) {
    final coreR = r * (0.10 + 0.20 * fused) * (1 + 0.30 * flash);
    if (coreR <= 0) return;
    for (var i = 3; i >= 1; i--) {
      canvas.drawCircle(
        c,
        coreR * (1 + 0.5 * i),
        _p..color = _brew.withValues(alpha: (0.16 * (fused + flash)) / i),
      );
    }
    canvas.drawCircle(
      c,
      coreR,
      _p
        ..color = Color.lerp(
          _brew,
          Colors.white,
          0.55 + 0.40 * flash,
        )!.withValues(alpha: 0.5 + 0.5 * fused),
    );
  }

  /// The chamber rim, and the progress running round it.
  void _track(
    Canvas canvas,
    Offset c,
    double r,
    double s,
    double sweep,
    double flash,
  ) {
    final rect = Rect.fromCircle(center: c, radius: r);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.034
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(c, r, _p..color = const Color(0xFF39414E));
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * sweep,
      false,
      _p..color = Color.lerp(_rim, _rimHot, flash)!,
    );

    // The head of the sweep, so the eye can see how fast it is going.
    if (sweep > 0.01 && sweep < 0.999) {
      final a = -math.pi / 2 + math.pi * 2 * sweep;
      _p.style = PaintingStyle.fill;
      canvas.drawCircle(
        c + Offset(math.cos(a) * r, math.sin(a) * r),
        s * 0.032,
        _p..color = _rimHot,
      );
    }

    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt;
  }

  @override
  bool shouldRepaint(covariant _InstantExtractorPainter old) =>
      old.clock != clock;
}
