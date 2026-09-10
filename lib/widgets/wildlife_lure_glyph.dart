import 'dart:math' as math;

import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The Wildlife Lure: a bait bloom that calls, and things that answer it.
///
/// Deliberately not the harvester's pulser, which also beats and also draws
/// something in. That is hardware clamping down on one specimen; this is bait
/// left in a clearing. So the core is grown rather than built, the call goes
/// out as a soft ring instead of a shockwave, and what arrives swims — the
/// motes wander in on their own line and circle once they are there, because
/// nothing has caught them.
class WildlifeLureGlyph extends StatefulWidget {
  const WildlifeLureGlyph({super.key, required this.size, this.animate = true});

  final double size;

  /// Off for a still frame; a shop card scrolling past does not need to run.
  final bool animate;

  @override
  State<WildlifeLureGlyph> createState() => _WildlifeLureGlyphState();
}

class _WildlifeLureGlyphState extends State<WildlifeLureGlyph>
    with GlyphClockLease {
  @override
  bool get wantsClock => widget.animate;

  @override
  void initState() {
    super.initState();
    syncGlyphClock();
  }

  @override
  void didUpdateWidget(covariant WildlifeLureGlyph oldWidget) {
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
        painter: _WildlifeLurePainter(clock: glyphClock),
      ),
    );
  }
}

class _WildlifeLurePainter extends CustomPainter {
  _WildlifeLurePainter({required this.clock}) : super(repaint: clock);

  final ValueListenable<double>? clock;

  /// Reused across every frame and every glyph on screen.
  static final Paint _p = Paint();

  /// One call and one answer.
  static const double _period = 3.2;

  /// Where the loop starts, so the frame the shop grid bakes has the callers
  /// mid-approach rather than an empty clearing.
  static const double _stillPhase = 0.55;

  static const int _callers = 6;

  static const _bloom = Color(0xFF6BCF7F);
  static const _bloomDeep = Color(0xFF1F6B3C);
  static const _bait = Color(0xFFF5C863);

  double get _t => clock?.value ?? 0;

  /// Golden-ratio spread, so no two callers share a line.
  static double _h(int i, int salt) => (i * 0.6180339887 + salt * 0.2749) % 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final c = Offset(size.width / 2, size.height / 2);
    final beat = ((_t / _period) + _stillPhase) % 1.0;

    _call(canvas, c, s, beat);
    _answer(canvas, c, s);
    _core(canvas, c, s, beat);
  }

  /// The scent going out. Soft and open, not a shockwave.
  void _call(Canvas canvas, Offset c, double s, double beat) {
    _p
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 2; i++) {
      final phase = (beat + i * 0.5) % 1.0;
      final e = Curves.easeOutCubic.transform(phase);
      final fade = (1 - phase) * 0.34;
      if (fade <= 0.01) continue;
      final r = s * (0.14 + 0.30 * e);
      // Broken into arcs rather than a closed ring: a scent carries in
      // patches, and a hard circle reads as a machine.
      for (var k = 0; k < 5; k++) {
        final start = k * math.pi * 2 / 5 + phase * 0.7;
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          start,
          0.52,
          false,
          _p
            ..strokeWidth = s * 0.022 * (1 - e * 0.55)
            ..color = _bloom.withValues(alpha: fade),
        );
      }
    }
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt;
  }

  /// What comes. Each on its own wandering line, and circling once it is in.
  void _answer(Canvas canvas, Offset c, double s) {
    for (var i = 0; i < _callers; i++) {
      final phase = (_t * 0.22 + _h(i, 1)) % 1.0;
      // Slows as it nears the bait rather than accelerating into it: it is
      // approaching something, not being pulled.
      final approach = Curves.easeOutCubic.transform(phase);
      final dist = s * (0.48 - 0.30 * approach);
      final lane = _h(i, 2) * math.pi * 2;
      // The wander is what makes it read as swimming.
      final wander = math.sin(phase * math.pi * 4 + i * 1.7) * 0.26;
      final a = lane + wander + approach * 0.9;
      final fade =
          (phase < 0.12 ? phase / 0.12 : 1.0) *
          (phase > 0.86 ? (1 - phase) / 0.14 : 1.0);
      if (fade <= 0.02) continue;

      final pos = c + Offset(math.cos(a) * dist, math.sin(a) * dist);
      final r = s * (0.021 + 0.008 * (1 - approach));

      // A tapered body: a head, and a shorter mark behind it on its own line.
      canvas.drawCircle(
        pos,
        r,
        _p
          ..color = Color.lerp(
            _bloom,
            Colors.white,
            0.45,
          )!.withValues(alpha: 0.9 * fade),
      );
      final tail =
          c +
          Offset(
            math.cos(a - 0.16) * (dist + s * 0.03),
            math.sin(a - 0.16) * (dist + s * 0.03),
          );
      canvas.drawCircle(
        tail,
        r * 0.55,
        _p..color = _bloom.withValues(alpha: 0.4 * fade),
      );
    }
  }

  /// The bait itself — grown, not built. Five lobes around a warm centre.
  void _core(Canvas canvas, Offset c, double s, double beat) {
    final breathe = 0.5 + 0.5 * math.sin(beat * math.pi * 2);
    final lobe = s * (0.052 + 0.008 * breathe);
    final spread = s * 0.062;

    for (var i = 0; i < 5; i++) {
      final a = i * math.pi * 2 / 5 - math.pi / 2;
      canvas.drawCircle(
        c + Offset(math.cos(a) * spread, math.sin(a) * spread),
        lobe,
        _p..color = Color.lerp(_bloom, _bloomDeep, 0.35)!,
      );
    }
    canvas.drawCircle(c, s * (0.055 + 0.010 * breathe), _p..color = _bait);
    canvas.drawCircle(
      c,
      s * 0.024,
      _p..color = Color.lerp(_bait, Colors.white, 0.65)!,
    );
  }

  @override
  bool shouldRepaint(covariant _WildlifeLurePainter old) => old.clock != clock;
}
