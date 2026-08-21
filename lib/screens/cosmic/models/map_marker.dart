import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The silhouette a marker is drawn with.
///
/// Shape carries as much identity as colour: on a dark star chart, six dots in
/// six hues are hard to tell apart at a glance (and impossible for a colour
/// blind player), whereas six silhouettes read instantly.
enum MarkerShape { pin, triangle, square, diamond, star, cross }

class MapMarker {
  final Offset worldPos;

  /// Marker type, 0–5. Each index is one colour *and* one shape. Older saves
  /// only ever wrote 0–2, and those indices still mean the same three colours.
  final int colorIndex;

  const MapMarker({required this.worldPos, required this.colorIndex});

  static const _colors = [
    Color(0xFFFF4444), // red
    Color(0xFF448AFF), // blue
    Color(0xFF4CAF50), // green
    Color(0xFFFFC24B), // amber
    Color(0xFFB47CFF), // violet
    Color(0xFF4DD0E1), // cyan
  ];

  static const _shapes = [
    MarkerShape.pin,
    MarkerShape.triangle,
    MarkerShape.square,
    MarkerShape.diamond,
    MarkerShape.star,
    MarkerShape.cross,
  ];

  static const int typeCount = 6;

  static List<Color> get colors => _colors;
  static List<MarkerShape> get shapes => _shapes;

  int get _i => colorIndex.clamp(0, typeCount - 1);

  Color get color => _colors[_i];
  MarkerShape get shape => _shapes[_i];

  String serialise() =>
      '${worldPos.dx.toStringAsFixed(1)},${worldPos.dy.toStringAsFixed(1)},$colorIndex';

  factory MapMarker.deserialise(String raw) {
    final p = raw.split(',');
    return MapMarker(
      worldPos: Offset(double.tryParse(p[0]) ?? 0, double.tryParse(p[1]) ?? 0),
      colorIndex: int.tryParse(p.length > 2 ? p[2] : '0') ?? 0,
    );
  }

  static String serialiseList(List<MapMarker> markers) =>
      markers.map((m) => m.serialise()).join(';');

  static List<MapMarker> deserialiseList(String raw) {
    if (raw.isEmpty) return [];
    return raw.split(';').map((s) => MapMarker.deserialise(s)).toList();
  }
}

/// Draws [shape] centred on [centre] at [r] radius. Shared by the chart
/// painter and the picker swatches so a marker looks the same in both.
void paintMarkerShape(
  Canvas canvas,
  Offset centre,
  double r,
  MarkerShape shape,
  Paint fill,
  Paint? stroke,
) {
  final path = Path();
  switch (shape) {
    case MarkerShape.pin:
      path.addOval(Rect.fromCircle(center: centre, radius: r));
    case MarkerShape.triangle:
      path
        ..moveTo(centre.dx, centre.dy - r * 1.15)
        ..lineTo(centre.dx + r, centre.dy + r * 0.75)
        ..lineTo(centre.dx - r, centre.dy + r * 0.75)
        ..close();
    case MarkerShape.square:
      path.addRect(
        Rect.fromCenter(center: centre, width: r * 1.8, height: r * 1.8),
      );
    case MarkerShape.diamond:
      path
        ..moveTo(centre.dx, centre.dy - r * 1.25)
        ..lineTo(centre.dx + r * 1.05, centre.dy)
        ..lineTo(centre.dx, centre.dy + r * 1.25)
        ..lineTo(centre.dx - r * 1.05, centre.dy)
        ..close();
    case MarkerShape.star:
      for (var i = 0; i < 10; i++) {
        final a = -1.5708 + i * 0.62832;
        final rr = i.isEven ? r * 1.3 : r * 0.55;
        final p = Offset(
          centre.dx + rr * math.cos(a),
          centre.dy + rr * math.sin(a),
        );
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
    case MarkerShape.cross:
      final t = r * 0.42;
      path
        ..addRect(Rect.fromCenter(center: centre, width: r * 2.2, height: t))
        ..addRect(Rect.fromCenter(center: centre, width: t, height: r * 2.2));
  }
  canvas.drawPath(path, fill);
  if (stroke != null) canvas.drawPath(path, stroke);
}
