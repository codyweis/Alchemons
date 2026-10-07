// lib/screens/story/story_intro_screen.dart
//
// THE OPENING. The prelude's quotes, one to a page, over a dark field of
// drifting grains — the sand everything else in the game is made of. A finger
// drawn across the screen stirs it; each page turn breathes it outward; the
// last tap draws it all into the centre and the faction choice follows.
//
// It used to end on a fake loading page ("INITIALIZING LABORATORY SYSTEMS")
// that was mostly fixed delays and a re-precache of icons startup had already
// warmed, behind a full-size decode of a 2.4 MB background. That page is gone:
// the quotes are the whole screen. Page turns are quicker (220 ms out, 320 ms
// in, was 600 + 600) and SKIP is a tap, not a two-second hold that only
// skipped as far as the loader.
//
// Cheap: a couple of thousand grains stepped in typed arrays and drawn as points
// in six batches. No blur, no images.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/screens/faction_picker.dart';
import 'package:alchemons/screens/story/models/story_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _ground = Color(0xFF07080B);
const Color _ink = Color(0xFFE6E2DA);
const Color _muted = Color(0xFF8E8C88);

class StoryIntroScreen extends StatefulWidget {
  const StoryIntroScreen({super.key});

  @override
  State<StoryIntroScreen> createState() => _StoryIntroScreenState();
}

class _StoryIntroScreenState extends State<StoryIntroScreen>
    with TickerProviderStateMixin {
  final List<StoryPage> _pages = AlchemonsStory.allPages;
  final _IntroDust _dust = _IntroDust();
  final ValueNotifier<int> _frame = ValueNotifier(0);

  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 220),
    value: 0,
  );
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;

  int _page = 0;
  bool _turning = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _ticker.start();
    _fade.forward();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _fade.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _dust.step(dt);
    _frame.value++;
  }

  Future<void> _next() async {
    if (_turning || _finishing) return;
    if (_page >= _pages.length - 1) {
      await _finish();
      return;
    }
    HapticFeedback.lightImpact();
    _turning = true;
    _dust.breathe();
    await _fade.reverse();
    if (!mounted) return;
    setState(() => _page++);
    await _fade.forward();
    _turning = false;
  }

  /// Where the last page's grains gather, and where the faction picker's
  /// realm bursts out of: the same point, so the two screens meet in it.
  static Offset knotFor(Size size) =>
      Offset(size.width / 2, size.height * 0.42);

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    HapticFeedback.mediumImpact();
    _dust.gather();
    await _fade.reverse();
    // Long enough to watch the grains close in, short enough not to be a
    // wait.
    await Future<void>.delayed(const Duration(milliseconds: 560));
    if (!mounted) return;
    final knot = knotFor(MediaQuery.sizeOf(context));
    // The picker opens on the knot and the realm forms out of it. It comes
    // back with the faction chosen (or nothing, if it was left some other
    // way); either way the opening is over.
    await Navigator.of(context).push<Object?>(
      PageRouteBuilder<Object?>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => FactionPickerDialog(emergeFrom: knot),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_page];
    return Scaffold(
      backgroundColor: _ground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          _dust.resize(constraints.biggest);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: context.soundAction(_next),
            onPanUpdate: (d) => _dust.stir(d.localPosition, d.delta),
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    painter: _DustPainter(_dust, repaint: _frame),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 36,
                      vertical: 72,
                    ),
                    child: Center(
                      child: FadeTransition(
                        opacity: _fade,
                        child: Text(
                          page.mainText,
                          key: ValueKey(_page),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.crimsonText(
                            fontSize: 22,
                            height: 1.6,
                            color: page.textColor ?? _ink,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: context.soundAction(_finish),
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(24, 16, 20, 16),
                        child: Text(
                          'SKIP',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: _muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < _pages.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              width: i == _page ? 6 : 4,
                              height: i == _page ? 6 : 4,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i <= _page
                                    ? _ink.withValues(
                                        alpha: i == _page ? 0.9 : 0.4,
                                      )
                                    : _muted.withValues(alpha: 0.25),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The grains: slow drift and sway, a finger's push, a breath outward on a
/// page turn, and a pull to the centre at the end.
class _IntroDust {
  static const int _n = 2600;
  static const int _tones = 3;

  final Float32List _x = Float32List(_n);
  final Float32List _y = Float32List(_n);
  final Float32List _vx = Float32List(_n);
  final Float32List _vy = Float32List(_n);
  final Float32List _phase = Float32List(_n);
  final Float32List _rise = Float32List(_n);
  final Uint8List _tone = Uint8List(_n);
  final Uint8List _big = Uint8List(_n);

  Size _size = Size.zero;
  double _t = 0;
  double _gather = 0; // 0 → 1 once gathering starts
  bool _gathering = false;

  // Per batch: tone × size. Reused every frame.
  final List<Float32List> _pts = List.generate(
    _tones * 2,
    (_) => Float32List(_n * 2),
  );
  final List<int> _counts = List.filled(_tones * 2, 0);

  void resize(Size size) {
    if (size.isEmpty || size == _size) return;
    final first = _size.isEmpty;
    final sx = first ? 1.0 : size.width / _size.width;
    final sy = first ? 1.0 : size.height / _size.height;
    _size = size;
    if (!first) {
      for (var i = 0; i < _n; i++) {
        _x[i] *= sx;
        _y[i] *= sy;
      }
      return;
    }
    final rng = math.Random(23);
    for (var i = 0; i < _n; i++) {
      _x[i] = rng.nextDouble() * size.width;
      // Nearly half settle into a bank of sand along the foot; the rest hang
      // in the air above it, thinning toward the top.
      _y[i] = rng.nextDouble() < 0.45
          ? size.height * (1 - 0.28 * math.pow(rng.nextDouble(), 1.6))
          : (1 - math.pow(rng.nextDouble(), 1.5)) * size.height;
      _phase[i] = rng.nextDouble() * math.pi * 2;
      // Grains in the bank barely lift; airborne ones drift up slowly.
      _rise[i] = _y[i] > size.height * 0.78
          ? rng.nextDouble() * 2
          : 4 + rng.nextDouble() * 10;
      final r = rng.nextDouble();
      _tone[i] = r < 0.62 ? 0 : (r < 0.9 ? 1 : 2);
      _big[i] = rng.nextDouble() < 0.18 ? 1 : 0;
    }
  }

  void stir(Offset at, Offset delta) {
    const radius = 70.0;
    for (var i = 0; i < _n; i++) {
      final dx = _x[i] - at.dx, dy = _y[i] - at.dy;
      final d2 = dx * dx + dy * dy;
      if (d2 > radius * radius) continue;
      final k = 1 - math.sqrt(d2) / radius;
      _vx[i] += delta.dx * 9 * k;
      _vy[i] += delta.dy * 9 * k;
    }
  }

  void breathe() {
    final cx = _size.width / 2, cy = _size.height / 2;
    for (var i = 0; i < _n; i++) {
      final dx = _x[i] - cx, dy = _y[i] - cy;
      final d = math.max(1.0, math.sqrt(dx * dx + dy * dy));
      final k = 26 * (1 - (d / (_size.longestSide * 0.7)).clamp(0.0, 1.0));
      _vx[i] += dx / d * k;
      _vy[i] += dy / d * k;
    }
  }

  void gather() => _gathering = true;

  Offset get _knot => _StoryIntroScreenState.knotFor(_size);

  void step(double dt) {
    if (_size.isEmpty) return;
    _t += dt;
    if (_gathering) _gather = math.min(1, _gather + dt / 0.7);
    final w = _size.width, h = _size.height;
    final cx = _knot.dx, cy = _knot.dy;
    final damp = math.pow(0.08, dt).toDouble(); // velocity halves in ~0.27 s
    final pull = _gather * _gather * 9.0;
    for (var i = 0; i < _n; i++) {
      var vx = _vx[i] * damp, vy = _vy[i] * damp;
      if (pull > 0) {
        vx += (cx - _x[i]) * pull * dt;
        vy += (cy - _y[i]) * pull * dt;
      }
      _vx[i] = vx;
      _vy[i] = vy;
      final sway = math.sin(_t * 0.6 + _phase[i]) * 6;
      var x = _x[i] + (vx + sway) * dt;
      var y = _y[i] + (vy - _rise[i]) * dt;
      if (!_gathering) {
        if (y < -4) y += h + 8;
        if (y > h + 4) y -= h + 8;
        if (x < -4) x += w + 8;
        if (x > w + 4) x -= w + 8;
      }
      _x[i] = x;
      _y[i] = y;
    }
  }

  void paint(Canvas canvas) {
    for (var b = 0; b < _counts.length; b++) {
      _counts[b] = 0;
    }
    for (var i = 0; i < _n; i++) {
      final b = _tone[i] * 2 + _big[i];
      final c = _counts[b];
      _pts[b][c * 2] = _x[i];
      _pts[b][c * 2 + 1] = _y[i];
      _counts[b] = c + 1;
    }
    final fade = 1 - _gather * 0.35;
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var b = 0; b < _counts.length; b++) {
      final n = _counts[b];
      if (n == 0) continue;
      final tone = b ~/ 2, big = b.isOdd;
      paint
        ..color = _toneColor(tone).withValues(
          alpha: (big ? 0.8 : 0.55) * fade,
        )
        ..strokeWidth = big ? 2.6 : 1.5;
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.sublistView(_pts[b], 0, n * 2),
        paint,
      );
    }
  }

  static Color _toneColor(int tone) => switch (tone) {
    0 => _muted,
    1 => _ink,
    _ => const Color(0xFFE0B068),
  };
}

class _DustPainter extends CustomPainter {
  _DustPainter(this.dust, {required Listenable repaint})
    : super(repaint: repaint);

  final _IntroDust dust;

  @override
  void paint(Canvas canvas, Size size) => dust.paint(canvas);

  @override
  bool shouldRepaint(covariant _DustPainter old) => old.dust != dust;
}
