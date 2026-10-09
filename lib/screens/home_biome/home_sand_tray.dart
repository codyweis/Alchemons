// lib/screens/home_biome/home_sand_tray.dart
//
// Living Sands' trays. The color of one of its sands, picked on three
// strips of sand: its hue, how strong it is, and how light. And its
// amounts — how thick, how coarse, how much shimmer — each on
// a strip of the sand showing more of it further along. Each strip is a
// band of grains with a glass bead on what is picked; a finger drawn along
// one moves the bead and the floor changes under it as it goes.
//
// Cheap: each strip's grains are placed once and drawn in a few dozen
// point batches, one per step along it.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Hue, saturation and lightness strips for [color]. [onChanged] follows
/// the finger; [onDone] is called when it lifts.
class SandColorStrips extends StatefulWidget {
  const SandColorStrips({
    super.key,
    required this.color,
    required this.onChanged,
    required this.onDone,
    this.labelStyle,
  });

  final Color color;
  final ValueChanged<Color> onChanged;
  final VoidCallback onDone;
  final TextStyle? labelStyle;

  @override
  State<SandColorStrips> createState() => _SandColorStripsState();
}

class _SandColorStripsState extends State<SandColorStrips> {
  // Kept as picked, not read back from the color: a grey has no hue, and
  // drawing its saturation back up must find the hue it had.
  late HSLColor _hsl = HSLColor.fromColor(widget.color);

  @override
  void didUpdateWidget(SandColorStrips old) {
    super.didUpdateWidget(old);
    if (widget.color != _hsl.toColor()) {
      _hsl = HSLColor.fromColor(widget.color);
    }
  }

  void _set(HSLColor hsl) {
    setState(() => _hsl = hsl);
    widget.onChanged(hsl.toColor());
  }

  @override
  Widget build(BuildContext context) {
    final h = _hsl;
    Widget strip(
      String label,
      double value,
      Color Function(double t) colorAt,
      HSLColor Function(double t) pick,
    ) => Row(
      children: [
        SizedBox(width: 86, child: Text(label, style: widget.labelStyle)),
        Expanded(
          child: _Strip(
            key: ValueKey(label),
            // What the strip draws through changes with the other two.
            painter: _StripPainter(
              value,
              colorAt,
              Object.hash(h.hue, h.saturation, h.lightness),
            ),
            onChanged: (t) => _set(pick(t)),
            onDone: widget.onDone,
          ),
        ),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        strip(
          'HUE',
          h.hue / 360,
          (t) => h
              .withHue(t * 360)
              .withSaturation(0.75)
              .withLightness(0.55)
              .toColor(),
          (t) => h.withHue((t * 360).clamp(0, 359.9)),
        ),
        const SizedBox(height: 6),
        strip(
          'SATURATION',
          h.saturation,
          (t) => h.withSaturation(t).withLightness(0.5).toColor(),
          (t) => h.withSaturation(t.clamp(0, 1)),
        ),
        const SizedBox(height: 6),
        strip(
          'LIGHTNESS',
          // Kept off pure black and pure white: neither is a sand.
          (h.lightness - 0.08) / 0.84,
          (t) => h.withLightness(0.08 + 0.84 * t).toColor(),
          (t) => h.withLightness(0.08 + 0.84 * t.clamp(0, 1)),
        ),
      ],
    );
  }
}

/// What a [SandAmountStrip] picks, and shows more of along it.
enum SandAmount {
  /// More grains.
  density,

  /// Bigger grains.
  grain,

  /// More grains of the shimmer.
  sparkle,
}

/// One of Living Sands' amounts, 0..1, on a strip of [sand] showing more of
/// it further along. [onChanged] follows the finger; [onDone] is called
/// when it lifts.
class SandAmountStrip extends StatelessWidget {
  const SandAmountStrip({
    super.key,
    required this.label,
    required this.kind,
    required this.value,
    required this.sand,
    required this.shimmer,
    required this.onChanged,
    required this.onDone,
    this.labelStyle,
  });

  final String label;
  final SandAmount kind;
  final double value;
  final Color sand, shimmer;
  final ValueChanged<double> onChanged;
  final VoidCallback onDone;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 74, child: Text(label, style: labelStyle)),
      Expanded(
        child: _Strip(
          painter: _AmountPainter(kind, value, sand, shimmer),
          onChanged: onChanged,
          onDone: onDone,
        ),
      ),
    ],
  );
}

class _Strip extends StatelessWidget {
  const _Strip({
    super.key,
    required this.painter,
    required this.onChanged,
    required this.onDone,
  });

  final CustomPainter painter;
  final ValueChanged<double> onChanged;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final w = box.maxWidth;
      double at(Offset p) => (p.dx / w).clamp(0.0, 1.0);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => onChanged(at(d.localPosition)),
        onTapUp: (_) => onDone(),
        // A press that became a drag, or was taken away: what it showed is
        // still saved.
        onTapCancel: onDone,
        onHorizontalDragStart: (d) => onChanged(at(d.localPosition)),
        onHorizontalDragUpdate: (d) => onChanged(at(d.localPosition)),
        onHorizontalDragEnd: (_) => onDone(),
        child: SizedBox(
          height: 24,
          child: RepaintBoundary(
            child: CustomPaint(size: Size(w, 24), painter: painter),
          ),
        ),
      );
    },
  );
}

class _StripPainter extends CustomPainter {
  _StripPainter(this.value, this.colorAt, this.stamp);

  final double value;
  final Color Function(double t) colorAt;
  final int stamp;

  @override
  void paint(Canvas canvas, Size size) {
    final grains = _grainsFor(size);
    final dot = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.8;
    for (var s = 0; s < _steps; s++) {
      dot.color = colorAt((s + 0.5) / _steps);
      canvas.drawRawPoints(ui.PointMode.points, grains[s], dot);
    }
    final v = value.clamp(0.0, 1.0);
    _bead(canvas, size, v, colorAt(v));
  }

  @override
  bool shouldRepaint(_StripPainter old) =>
      old.value != value || old.stamp != stamp;
}

class _AmountPainter extends CustomPainter {
  _AmountPainter(this.kind, this.value, this.sand, this.shimmer);

  final SandAmount kind;
  final double value;
  final Color sand, shimmer;

  @override
  void paint(Canvas canvas, Size size) {
    final grains = _grainsFor(size);
    final dot = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.8
      ..color = sand;
    for (var s = 0; s < _steps; s++) {
      final t = (s + 0.5) / _steps;
      var pts = grains[s];
      switch (kind) {
        case SandAmount.density:
          final n = (pts.length / 2 * (0.25 + 0.75 * t)).round();
          pts = Float32List.sublistView(pts, 0, n * 2);
        case SandAmount.grain:
          dot.strokeWidth = 1.2 + 2.4 * t;
        case SandAmount.sparkle:
          break;
      }
      canvas.drawRawPoints(ui.PointMode.points, pts, dot);
      if (kind == SandAmount.sparkle) {
        final n = (pts.length / 2 * 0.14 * t).round();
        if (n > 0) {
          canvas.drawRawPoints(
            ui.PointMode.points,
            Float32List.sublistView(pts, 0, n * 2),
            Paint()
              ..strokeCap = StrokeCap.round
              ..strokeWidth = 2.2
              ..color = shimmer,
          );
        }
      }
    }
    _bead(canvas, size, value.clamp(0.0, 1.0), sand);
  }

  @override
  bool shouldRepaint(_AmountPainter old) =>
      old.value != value ||
      old.kind != kind ||
      old.sand != sand ||
      old.shimmer != shimmer;
}

const int _steps = 40;

// Where each step's grains lie, for a strip of a size: placed once.
final Map<Size, List<Float32List>> _grains = {};

List<Float32List> _grainsFor(Size size) => _grains.putIfAbsent(size, () {
  final r = math.Random(5);
  final band = size.height * 0.5;
  final top = (size.height - band) / 2;
  final n = (size.width * band / 5).round();
  final per = List.generate(_steps, (_) => <double>[]);
  for (var i = 0; i < n; i++) {
    final x = r.nextDouble() * size.width;
    // Thicker in the middle of the band, thinning at its edges.
    final y = top + band * (0.5 + 0.5 * (r.nextDouble() - r.nextDouble()));
    final step = (x / size.width * _steps).floor().clamp(0, _steps - 1);
    per[step]
      ..add(x)
      ..add(y);
  }
  return [for (final p in per) Float32List.fromList(p)];
});

/// The bead on what is picked, at [value] along: a drop of glass in
/// [color].
void _bead(Canvas canvas, Size size, double value, Color color) {
  final c = Offset(value * size.width, size.height / 2);
  const r = 8.0;
  canvas
    ..drawCircle(
      c + const Offset(0, 1.5),
      r + 1,
      Paint()..color = const Color(0x99000000),
    )
    ..drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          c + const Offset(-2.5, -3),
          r * 1.4,
          [
            Color.lerp(color, Colors.white, 0.55)!,
            color,
            Color.lerp(color, Colors.black, 0.45)!,
          ],
          const [0, 0.45, 1],
        ),
    );
}
