// lib/widgets/fx/keepsake_view.dart
//
// A keepsake or piece of home decor drawn on its own, fitted to its box —
// for the shop's cards and dialog and the home biome's trays. Still unless
// [animate], so a grid of them costs nothing a frame.

import 'dart:math' as math;

import 'package:alchemons/widgets/fx/keepsake_art.dart';
import 'package:flutter/material.dart';

class KeepsakeView extends StatefulWidget {
  const KeepsakeView(
    this.kind, {
    super.key,
    this.style = 0,
    this.copy = 0,
    this.animate = false,
    this.night = 0.6,
  });

  final String kind;
  final int style, copy;
  final bool animate;

  /// How deep in the night it is shown, 0 to 1 — lit enough to read.
  final double night;

  @override
  State<KeepsakeView> createState() => _KeepsakeViewState();
}

class _KeepsakeViewState extends State<KeepsakeView>
    with SingleTickerProviderStateMixin {
  late KeepsakeArt? _art = _make();
  AnimationController? _clock;

  KeepsakeArt? _make() =>
      KeepsakeArt.of(widget.kind, style: widget.style, copy: widget.copy);

  @override
  void initState() {
    super.initState();
    _sync();
  }

  void _sync() {
    if (widget.animate && _clock == null) {
      _clock = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 60),
      )..repeat();
    } else if (!widget.animate) {
      _clock?.dispose();
      _clock = null;
    }
  }

  @override
  void didUpdateWidget(covariant KeepsakeView old) {
    super.didUpdateWidget(old);
    if (old.kind != widget.kind ||
        old.style != widget.style ||
        old.copy != widget.copy) {
      _art?.dispose();
      _art = _make();
    }
    _sync();
  }

  @override
  void dispose() {
    _clock?.dispose();
    _art?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final art = _art;
    if (art == null) return const SizedBox.shrink();
    return CustomPaint(
      size: Size.infinite,
      painter: _KeepsakePainter(art, _clock, widget.night),
    );
  }
}

class _KeepsakePainter extends CustomPainter {
  _KeepsakePainter(this.art, this.clock, double night)
    : _time = KeepsakeTime(t: 3.2, night: night, daylight: 1 - night),
      super(repaint: clock);

  final KeepsakeArt art;
  final Animation<double>? clock;
  final KeepsakeTime _time;

  @override
  void paint(Canvas canvas, Size size) {
    final b = art.box;
    final k = math.min(size.width / b.width, size.height / b.height) * 0.92;
    if (clock != null) _time.t = 3.2 + clock!.value * 60;
    canvas
      ..save()
      ..translate(size.width / 2 - b.center.dx * k, size.height - b.bottom * k)
      ..scale(k);
    art.paint(canvas, _time);
    if (art.hasFront) art.front(canvas, _time);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_KeepsakePainter old) =>
      old.art != art || old.clock != clock;
}
