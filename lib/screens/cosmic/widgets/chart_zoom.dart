// lib/screens/cosmic/widgets/chart_zoom.dart
//
// The way between space and the star chart. Opening, the camera pulls back
// off the ship: the view of space shrinks round the ship down to the patch
// of the chart it covers, its edges going soft and warming to the chart's
// amber, while the chart settles out from close in round it — so the chart
// opens on exactly where you are. Closing plays it back: the chart closes
// in on that patch and space opens back out of it to the whole screen.
//
// Space is pictured once as the chart opens (it is paused under it), so
// both ends of the way are the frame you were looking at.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'star_chart_art.dart' show kChartAmber;

double _smooth(double e0, double e1, double x) {
  final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Space as it stood when the chart opened, and where it goes on the chart.
class ChartZoom {
  ChartZoom({
    required this.image,
    required this.origin,
    required this.size,
    required this.ship,
    required this.spacePxPerUnit,
  });

  /// The picture of space, laid over [origin] at [size] (global, logical).
  final ui.Image image;
  final Offset origin;
  final Size size;

  /// Where the ship stands in it (global), and how many px a world unit is.
  final Offset ship;
  final double spacePxPerUnit;

  /// Where the ship is on the chart and its px per unit there; set once the
  /// chart is laid out, and again as it closes (it may have been panned).
  ({Offset at, double pxPerUnit})? onChart;

  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    image.dispose();
  }

  /// Pictures the RepaintBoundary under [key] at [ratio]; null when it
  /// cannot be (the chart then simply fades).
  static Future<(ui.Image, RenderRepaintBoundary)?> picture(
    GlobalKey key,
    double ratio,
  ) async {
    await SchedulerBinding.instance.endOfFrame;
    final boundary = key.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary || !boundary.attached) return null;
    try {
      final image = await boundary
          .toImage(pixelRatio: ratio)
          .timeout(const Duration(milliseconds: 300));
      if (!boundary.attached) {
        image.dispose();
        return null;
      }
      return (image, boundary);
    } catch (_) {
      return null;
    }
  }
}

/// Paints [zoom] at [progress] (0 space, 1 the chart).
class ChartZoomPainter extends CustomPainter {
  ChartZoomPainter(this.zoom, this.progress) : super(repaint: progress);

  final ChartZoom zoom;
  final Animation<double> progress;

  static final Paint _image = Paint()..filterQuality = FilterQuality.medium;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value.clamp(0.0, 1.0);
    final e = Curves.easeInOutCubic.transform(t);
    final target = zoom.onChart;
    // It covers the HUD over a few frames rather than at once, and fades
    // into the ship's patch on the chart at the end.
    final alpha = _smooth(0, 0.1, t) * (1 - _smooth(0.42, 0.95, e));
    if (alpha <= 0.004) return;
    // Shrinking in scale evenly (log), its ship sliding to the chart's.
    final end = target == null
        ? 0.5
        : (target.pxPerUnit / math.max(1e-6, zoom.spacePxPerUnit)).clamp(
            1e-3,
            1.0,
          );
    final s = math.exp(math.log(end) * e);
    final p = Offset.lerp(zoom.ship, target?.at ?? zoom.ship, e)!;
    final dst = Rect.fromLTWH(
      p.dx + (zoom.origin.dx - zoom.ship.dx) * s,
      p.dy + (zoom.origin.dy - zoom.ship.dy) * s,
      zoom.size.width * s,
      zoom.size.height * s,
    );
    canvas.saveLayer(
      dst.inflate(2),
      Paint()..color = Color.fromRGBO(0, 0, 0, alpha),
    );
    canvas.drawImageRect(
      zoom.image,
      Rect.fromLTWH(
        0,
        0,
        zoom.image.width.toDouble(),
        zoom.image.height.toDouble(),
      ),
      dst,
      _image,
    );
    // Its edges go soft as it falls away — an oval the view's own shape,
    // so no side of it stays a hard edge against the chart.
    final feather = math.max(_smooth(0.0, 0.32, e), _smooth(0.04, 0.3, t));
    if (feather > 0.01) {
      final c = dst.center;
      final k = 1.42 - 0.42 * feather;
      final rx = dst.width / 2 * k;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(1, dst.height / dst.width);
      canvas.drawRect(
        Rect.fromCircle(
          center: Offset.zero,
          radius: rx * 1.05 * dst.height / dst.width + rx,
        ),
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = ui.Gradient.radial(
            Offset.zero,
            rx,
            const [Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
            [0.0, 1 - 0.88 * feather, 1.0],
          ),
      );
      canvas.restore();
    }
    // …and warms to the chart's amber as it settles onto the ship's patch.
    final warm = _smooth(0.3, 0.9, e);
    if (warm > 0.01) {
      canvas.drawRect(
        dst,
        Paint()
          ..blendMode = BlendMode.srcATop
          ..color = kChartAmber.withValues(alpha: 0.4 * warm),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ChartZoomPainter old) =>
      old.zoom != zoom || old.progress != progress;
}
