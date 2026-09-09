import 'dart:math' as math;

import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The Raid Beacon, drawn as a signal going out from a conquered planet.
///
/// A spire stands on the planet's limb, throws a pulse up and out, and
/// something answers — motes dropping in along the beam. It shared its
/// artwork with the Instant Extractor before this (the same swirl, recoloured),
/// which meant the shop's two most different items looked identical.
class RaidBeaconGlyph extends StatefulWidget {
  const RaidBeaconGlyph({super.key, required this.size, this.animate = true});

  final double size;

  /// Off for a still frame; a shop card scrolling past does not need to run.
  final bool animate;

  @override
  State<RaidBeaconGlyph> createState() => _RaidBeaconGlyphState();
}

class _RaidBeaconGlyphState extends State<RaidBeaconGlyph>
    with GlyphClockLease {
  @override
  bool get wantsClock => widget.animate;

  @override
  void initState() {
    super.initState();
    syncGlyphClock();
  }

  @override
  void didUpdateWidget(covariant RaidBeaconGlyph oldWidget) {
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
        painter: _RaidBeaconPainter(clock: glyphClock),
      ),
    );
  }
}

class _RaidBeaconPainter extends CustomPainter {
  _RaidBeaconPainter({required this.clock}) : super(repaint: clock);

  final ValueListenable<double>? clock;

  /// Reused across every frame and every glyph on screen.
  static final Paint _p = Paint();

  /// One pulse out, one answer back.
  static const double _period = 2.6;

  static const _signal = Color(0xFFFF3D71);
  static const _signalDeep = Color(0xFF8E1140);
  static const _hot = Color(0xFFFFD9E4);

  double get _t => clock?.value ?? 0;

  static double _seed(int i, int salt) => ((i * 61 + salt * 17) % 100) / 100.0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final beat = (_t % _period) / _period;

    // No ground. A planet limb under it made the icon read as a landscape
    // rather than as a thing you own — every other item in the shop is an
    // object on nothing, and this one has to sit in the same row.
    final apex = Offset(s * 0.5, s * 0.155);

    _rings(canvas, apex, s, beat);
    _shard(canvas, s, beat);
    _tip(canvas, apex, s, beat);
    _answer(canvas, apex, s, beat);
  }

  /// The signal leaving. Three rings a third of a beat apart, so it never
  /// looks like it has stopped broadcasting.
  void _rings(Canvas canvas, Offset apex, double s, double beat) {
    _p.style = PaintingStyle.stroke;
    for (var i = 0; i < 3; i++) {
      final phase = (beat + i / 3) % 1.0;
      final e = Curves.easeOutCubic.transform(phase);
      final fade = (1 - phase) * 0.55;
      if (fade <= 0.01) continue;
      // Wider than tall: the signal spreads across the sky, not into it.
      canvas.drawOval(
        Rect.fromCenter(
          center: apex,
          width: s * (0.16 + 0.80 * e),
          height: s * (0.10 + 0.44 * e),
        ),
        _p
          ..strokeWidth = s * 0.022 * (1 - e * 0.6)
          ..color = _signal.withValues(alpha: fade),
      );
    }
    _p.style = PaintingStyle.fill;
  }

  /// The beacon: a standing shard, pointed at both ends so it floats.
  void _shard(Canvas canvas, double s, double beat) {
    Path shardPath(double scale) {
      final w = s * 0.088 * scale;
      final cx = s * 0.5;
      return Path()
        ..moveTo(cx, s * 0.155)
        ..lineTo(cx + w, s * 0.52)
        ..lineTo(cx + w * 0.68, s * 0.855)
        ..lineTo(cx, s * 0.945)
        ..lineTo(cx - w * 0.68, s * 0.855)
        ..lineTo(cx - w, s * 0.52)
        ..close();
    }

    // Layered copies stand in for a glow. A blur here would cost more than
    // everything else in the shop grid put together.
    final surge = 0.55 + 0.45 * math.sin(beat * math.pi * 2);
    for (var i = 3; i >= 1; i--) {
      canvas.drawPath(
        shardPath(1 + 0.55 * i),
        _p..color = _signal.withValues(alpha: (0.17 * surge) / i),
      );
    }

    final body = shardPath(1);
    canvas.drawPath(
      body,
      _p
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_hot, _signal, _signalDeep],
          stops: [0.0, 0.40, 1.0],
        ).createShader(Rect.fromLTRB(0, s * 0.155, s, s * 0.945)),
    );
    _p.shader = null;

    canvas.drawPath(
      body,
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.014
        ..strokeJoin = StrokeJoin.round
        ..color = _hot.withValues(alpha: 0.75),
    );
    _p.style = PaintingStyle.fill;
  }

  void _tip(Canvas canvas, Offset apex, double s, double beat) {
    final pulse = 0.7 + 0.3 * math.sin(beat * math.pi * 2);
    canvas.drawCircle(
      apex,
      s * 0.058 * pulse,
      _p..color = _signal.withValues(alpha: 0.55),
    );
    canvas.drawCircle(apex, s * 0.030 * pulse, _p..color = _hot);
  }

  /// What the signal brings. Motes dropping in along the beam, late in the
  /// beat, so the loop reads call-then-answer.
  void _answer(Canvas canvas, Offset apex, double s, double beat) {
    if (beat < 0.45) return;
    final t = (beat - 0.45) / 0.55;
    for (var i = 0; i < 4; i++) {
      final phase = (t + _seed(i, 2) * 0.4) % 1.0;
      final a = -math.pi / 2 + (_seed(i, 4) - 0.5) * 2.2;
      final d = s * 0.52 * (1 - Curves.easeInCubic.transform(phase));
      final fade = phase > 0.8 ? (1 - phase) / 0.2 : 1.0;
      canvas.drawCircle(
        apex + Offset(math.cos(a) * d, math.sin(a) * d),
        s * 0.020,
        _p..color = _hot.withValues(alpha: 0.8 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RaidBeaconPainter old) => old.clock != clock;
}
