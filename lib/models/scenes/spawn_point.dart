// lib/models/scenes/spawn_point.dart
import 'dart:ui';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:flame/components.dart';

class SpawnPoint {
  final String id; // e.g. "SP_valley_01"
  final Offset normalizedPos; // 0..1 (x,y)
  final SceneLayer anchor; // which parallax layer
  final bool enabled; // allow disabling without removing
  final Vector2 size;

  const SpawnPoint({
    required this.id,
    required this.normalizedPos,
    this.anchor = SceneLayer.layer3,
    this.enabled = true,
    required this.size,
  });
}
