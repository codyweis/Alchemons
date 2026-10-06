// lib/widgets/fx/grain_text.dart
//
// TEXT MADE OF GRAINS: a line or paragraph laid out like any Text, then
// sampled into points and drawn as sand. On arrival the grains drift in
// from just below and settle into their letters, left to right; after that
// the word is one recorded picture, so it costs nothing per frame. No blur.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class GrainText extends StatefulWidget {
  const GrainText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign = TextAlign.start,
    this.delay = Duration.zero,
    this.animate = true,
  });

  final String text;
  final TextStyle style;
  final TextAlign textAlign;

  /// Held back before the grains start to gather.
  final Duration delay;

  /// False = already settled (reduced motion, previews).
  final bool animate;

  @override
  State<GrainText> createState() => _GrainTextState();
}

class _GrainTextState extends State<GrainText>
    with SingleTickerProviderStateMixin {
  static const _intro = Duration(milliseconds: 900);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _intro + widget.delay,
  );

  _Grains? _grains;
  String _key = '';
  int _gen = 0;

  @override
  void dispose() {
    _c.dispose();
    _grains?.picture.dispose();
    super.dispose();
  }

  Future<void> _sample(double maxWidth, TextScaler scaler, double dpr) async {
    final key = '${widget.text}|${widget.style.hashCode}|$maxWidth|'
        '${scaler.hashCode}|${widget.textAlign}';
    if (key == _key) return;
    _key = key;
    final gen = ++_gen;
    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: TextDirection.ltr,
      textAlign: widget.textAlign,
      textScaler: scaler,
    )..layout(maxWidth: maxWidth + 0.5);
    final size = Size(maxWidth, tp.height.ceilToDouble() + 2);

    const scale = 2.0;
    final rec = ui.PictureRecorder();
    final cv = Canvas(rec)..scale(scale);
    tp.paint(cv, Offset.zero);
    final img = await rec.endRecording().toImage(
      (size.width * scale).ceil(),
      (size.height * scale).ceil(),
    );
    final bytes = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final iw = img.width, ih = img.height;
    img.dispose();
    tp.dispose();
    if (!mounted || gen != _gen || bytes == null) return;

    // One grain per half-pixel of ink, jittered inside its cell; a very
    // long paragraph thins out rather than grow without bound.
    var step = 1;
    var count = 0;
    for (var y = 0; y < ih; y += step) {
      for (var x = 0; x < iw; x += step) {
        if (bytes.getUint8((y * iw + x) * 4 + 3) > 60) count++;
      }
    }
    if (count > 14000) step = 2;

    final rng = math.Random(widget.text.hashCode);
    final tones = <List<double>>[[], [], []];
    final delays = <List<double>>[[], [], []];
    final from = <List<double>>[[], [], []];
    for (var y = 0; y < ih; y += step) {
      for (var x = 0; x < iw; x += step) {
        if (bytes.getUint8((y * iw + x) * 4 + 3) <= 60) continue;
        final px = (x + rng.nextDouble() * step) / scale;
        final py = (y + rng.nextDouble() * step) / scale;
        final t = rng.nextInt(3);
        tones[t]
          ..add(px)
          ..add(py);
        // Left to right across the width, with a little scatter.
        delays[t].add((px / size.width) * 0.45 + rng.nextDouble() * 0.12);
        from[t]
          ..add((rng.nextDouble() - 0.5) * 10)
          ..add(6 + rng.nextDouble() * 14);
      }
    }

    final grains = _Grains(
      tones: [for (final t in tones) Float32List.fromList(t)],
      delays: [for (final t in delays) Float32List.fromList(t)],
      from: [for (final t in from) Float32List.fromList(t)],
      picture: _record(tones, widget.style.color ?? Colors.white),
    );
    setState(() {
      _grains?.picture.dispose();
      _grains = grains;
    });
    if (widget.animate) {
      _c
        ..duration = _intro + widget.delay
        ..forward(from: 0);
    } else {
      _c.value = 1;
    }
  }

  static ui.Picture _record(List<List<double>> tones, Color base) {
    final rec = ui.PictureRecorder();
    final cv = Canvas(rec);
    _paintSettled(cv, tones, base);
    return rec.endRecording();
  }

  static List<Paint> _paints(Color base) => [
        for (final a in const [1.0, 0.9, 0.76])
          Paint()
            ..color = base.withValues(alpha: base.a * a)
            ..strokeWidth = 1.0
            ..strokeCap = StrokeCap.round,
      ];

  static void _paintSettled(Canvas cv, List<List<double>> tones, Color base) {
    final paints = _paints(base);
    for (var i = 0; i < 3; i++) {
      cv.drawRawPoints(
        ui.PointMode.points,
        Float32List.fromList(tones[i]),
        paints[i],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // The real Text sits underneath, clear: it sizes the block before the
    // grains are ready, and is what is read aloud and found. The grains are
    // sampled at the width it actually took.
    return Stack(
      children: [
        Text(
          widget.text,
          textAlign: widget.textAlign,
          style: widget.style.copyWith(color: Colors.transparent),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: LayoutBuilder(
              builder: (context, box) {
                _sample(box.maxWidth, scaler, dpr);
                final g = _grains;
                if (g == null) return const SizedBox.shrink();
                return RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) => CustomPaint(
                      size: Size.infinite,
                      painter: _GrainPainter(
                        grains: g,
                        t: _c.value * (_intro + widget.delay).inMilliseconds,
                        delayMs: widget.delay.inMilliseconds.toDouble(),
                        introMs: _intro.inMilliseconds.toDouble(),
                        base: widget.style.color ?? Colors.white,
                        done: _c.isCompleted,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Grains {
  _Grains({
    required this.tones,
    required this.delays,
    required this.from,
    required this.picture,
  });
  final List<Float32List> tones;
  final List<Float32List> delays;
  final List<Float32List> from;
  final ui.Picture picture;
}

class _GrainPainter extends CustomPainter {
  _GrainPainter({
    required this.grains,
    required this.t,
    required this.delayMs,
    required this.introMs,
    required this.base,
    required this.done,
  }) : super();

  final _Grains grains;
  final double t;
  final double delayMs;
  final double introMs;
  final Color base;
  final bool done;

  @override
  void paint(Canvas canvas, Size size) {
    if (done) {
      canvas.drawPicture(grains.picture);
      return;
    }
    final local = t - delayMs; // ms into the gather
    if (local <= 0) return;
    final paints = _GrainTextState._paints(base);
    for (var i = 0; i < 3; i++) {
      final home = grains.tones[i];
      final dl = grains.delays[i];
      final fr = grains.from[i];
      final n = dl.length;
      final out = Float32List(n * 2);
      var m = 0;
      for (var k = 0; k < n; k++) {
        // Each grain's own 0..1 over the back 55% of the intro.
        final u = ((local / introMs) - dl[k]) / 0.55;
        if (u <= 0) continue;
        final e = u >= 1 ? 1.0 : 1 - math.pow(1 - u, 3).toDouble();
        out[m++] = home[k * 2] + fr[k * 2] * (1 - e);
        out[m++] = home[k * 2 + 1] + fr[k * 2 + 1] * (1 - e);
      }
      if (m > 0) {
        canvas.drawRawPoints(
          ui.PointMode.points,
          Float32List.sublistView(out, 0, m),
          paints[i],
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GrainPainter old) =>
      old.t != t || old.grains != grains || old.done != done;
}
