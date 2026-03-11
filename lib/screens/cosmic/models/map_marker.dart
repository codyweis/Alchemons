import 'package:flutter/material.dart';

class MapMarker {
  final Offset worldPos;
  final int colorIndex; // 0=red, 1=blue, 2=green

  const MapMarker({required this.worldPos, required this.colorIndex});

  static const _colors = [
    Color(0xFFFF4444), // red
    Color(0xFF448AFF), // blue
    Color(0xFF4CAF50), // green
  ];

  static List<Color> get colors => _colors;

  Color get color => _colors[colorIndex.clamp(0, 2)];

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

// ─────────────────────────────────────────────────────────
// MINI-MAP OVERLAY  (zoomable / pannable / markable)
// ─────────────────────────────────────────────────────────
