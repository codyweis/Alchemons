import 'dart:math' as math;
import 'dart:typed_data';

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/perf/viewport_ticker_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// AN EMPTY CHAMBER: the same vessel a cultivation turns in, holding only a
// faint shell of dust where the sphere will be — the glass, not a button.

/// An unoccupied chamber in the nursery grid. A tap does what [onTap] says
/// (it opens fusion).
class EmptyChamber extends StatelessWidget {
  const EmptyChamber({super.key, required this.theme, required this.onTap});

  final FactionTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLight = theme.brightness == Brightness.light;
    final palette = BracketPalette.fromTheme(theme);
    return RepaintBoundary(
      child: GestureDetector(
        onTap: context.soundAction(onTap),
        // The vessel the occupied chambers beside it are drawn in, so a row
        // of chambers reads as a row of chambers, some of them filled.
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isLight ? palette.bg1 : Colors.black,
            border: Border.all(
              color: palette.lineSoft.withValues(alpha: 0.55),
              width: 1,
            ),
          ),
          child: ClipOval(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: ViewportTickerGate(
                    child: _EmptyChamberDust(
                      grain: palette.ink,
                      dark: !isLight,
                    ),
                  ),
                ),
                Text(
                  'Empty',
                  style: bracketText(
                    context,
                    12.5,
                    palette.muted,
                    weight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyChamberDust extends StatefulWidget {
  const _EmptyChamberDust({required this.grain, required this.dark});

  final Color grain;
  final bool dark;

  @override
  State<_EmptyChamberDust> createState() => _EmptyChamberDustState();
}

class _EmptyChamberDustState extends State<_EmptyChamberDust>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) => _time.value = e.inMicroseconds / 1e6)
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _EmptyChamberPainter(
      _time,
      grain: widget.grain,
      heart: const Color(0xFFC4A35A),
      dark: widget.dark,
    ),
  );
}

/// The dust: a hollow, sparse shell at the cultivation sphere's size and tilt,
/// turning slowly and breathing, with a dim warmth at its heart.
class _EmptyChamberPainter extends CustomPainter {
  _EmptyChamberPainter(
    this.time, {
    required this.grain,
    required this.heart,
    required this.dark,
  }) : super(repaint: time);

  final ValueNotifier<double> time;
  final Color grain;
  final Color heart;
  final bool dark;

  static const int _n = 200;

  /// The cultivation sphere's tip, so empty and filled sit the same way.
  static const double _tip = 0.32;

  /// One breath, in seconds.
  static const double _breath = 6.5;

  static final Float32List _lat = Float32List(_n),
      _lon = Float32List(_n),
      _r = Float32List(_n),
      _omega = Float32List(_n),
      _phase = Float32List(_n);
  static bool _seeded = false;

  static void _seed() {
    if (_seeded) return;
    _seeded = true;
    final rng = math.Random(41);
    for (var i = 0; i < _n; i++) {
      _lat[i] = math.asin(rng.nextDouble() * 2 - 1);
      _lon[i] = rng.nextDouble() * math.pi * 2;
      // A shell, not a ball: what is there is the outline of what will be.
      _r[i] = 0.9 + 0.1 * rng.nextDouble();
      _omega[i] = 0.8 + 0.4 * rng.nextDouble();
      _phase[i] = rng.nextDouble();
    }
  }

  // Far side, near side, glints.
  final GrainBatch _batch = GrainBatch(3);

  @override
  void paint(Canvas canvas, Size size) {
    _seed();
    final t = time.value;
    final c = size.center(Offset.zero);
    final breathe = 0.5 - 0.5 * math.cos(t * 2 * math.pi / _breath);
    final radius = size.shortestSide * 0.36 * (1 + 0.025 * breathe);

    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            heart.withValues(alpha: (dark ? 0.06 : 0.04) + 0.04 * breathe),
            heart.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: radius)),
    );

    final cosT = math.cos(_tip), sinT = math.sin(_tip);
    final b = _batch..clear();
    for (var i = 0; i < _n; i++) {
      final lon = _lon[i] + _omega[i] * t * 0.11;
      final cl = math.cos(_lat[i]);
      final r = _r[i] * radius;
      final px = r * cl * math.cos(lon);
      final py = r * math.sin(_lat[i]);
      final pz = r * cl * math.sin(lon);
      final y = py * cosT - pz * sinT;
      final z = py * sinT + pz * cosT;
      final glint = (t * 0.09 + _phase[i] * 7.3) % 1.0 < 0.004;
      b.add(
        z < 0
            ? 0
            : glint
            ? 2
            : 1,
        c.dx + px,
        c.dy + y,
      );
    }

    final d = math.max(1.1, radius * 0.026);
    b.draw(canvas, 0, d * 0.8, grain.withValues(alpha: dark ? 0.1 : 0.14));
    b.draw(
      canvas,
      1,
      d,
      grain.withValues(alpha: (dark ? 0.3 : 0.34) + 0.06 * breathe),
    );
    b.draw(canvas, 2, d * 1.4, grain.withValues(alpha: 0.7));
  }

  @override
  bool shouldRepaint(_EmptyChamberPainter old) =>
      old.time != time ||
      old.grain != grain ||
      old.heart != heart ||
      old.dark != dark;
}
