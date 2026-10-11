// lib/widgets/fx/cosmetics/trail_art.dart
//
// The Athanor's trails: what a creature leaves on the ground where it
// walks at home. A host records each footfall ([TrailPrints.step], in its
// own space) and lays the prints into two shared atlases each frame — one
// laid over the ground, one of light added to it — so every trail in a
// field is two draws, however many creatures wear one.
//
//   Frost Steps  frost blooms where each foot comes down: a lopsided
//                    spray of fronds that grows out in half a second,
//                    holds, and melts back to a wet glint and nothing
//   Gold Steps       gold dust kicked up at each step, falling back and
//                    lying in small glints that twinkle and fade
//
// From the Hoarfrost prototype (docs/crucible/concepts/trail.png),
// its fronds and grains baked into the cosmetic atlas so a bloom is a few
// atlas entries instead of paths drawn each frame.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:alchemons/games/cosmic/obsidian_kit.dart' show hash01;
import 'package:alchemons/models/cosmetic_wear.dart';
import 'package:alchemons/widgets/fx/cosmetics/cosmetic_atlas.dart';
import 'package:flutter/painting.dart';

/// One creature's prints.
class TrailPrints {
  TrailPrints(this.style, {int capacity = 14})
    : _x = Float64List(capacity),
      _y = Float64List(capacity),
      _born = Float64List(capacity),
      _size = Float64List(capacity),
      _seed = Int32List(capacity);

  final TrailStyle style;
  final Float64List _x, _y, _born, _size;
  final Int32List _seed;
  int _next = 0, _count = 0, _steps = 0;

  /// Seconds from footfall to gone.
  double get life => lifeOf(style);

  static double lifeOf(TrailStyle style) => switch (style) {
    TrailStyle.hoarfrost => 5.5,
    TrailStyle.gilt => 4.2,
  };

  /// Each print as atlas entries, at most (for sizing an atlas).
  static const int entriesPerPrint = 34;

  bool get isEmpty => _count == 0;

  /// Whether any print is still showing at [time].
  bool aliveAt(double time) {
    for (var j = 0; j < _count; j++) {
      if (time - _born[j] <= life) return true;
    }
    return false;
  }

  void clear() {
    _count = 0;
    _next = 0;
  }

  /// A foot came down at ([x], [y]) at [time]; [size] is the print's
  /// radius in the host's units (about a fifth of the creature's width).
  void step(double x, double y, double time, {required double size}) {
    final i = _next;
    _x[i] = x;
    _y[i] = y;
    _born[i] = time;
    _size[i] = size;
    _seed[i] = _steps++;
    _next = (_next + 1) % _x.length;
    _count = math.min(_count + 1, _x.length);
  }

  /// Lays the prints alive at [time] into [ground] (laid over) and [light]
  /// (added), shifted by ([ox], [oy]).
  void paint(
    CosmeticAtlas ground,
    CosmeticAtlas light,
    double time, {
    double ox = 0,
    double oy = 0,
    double opacity = 1,
  }) {
    for (var j = 0; j < _count; j++) {
      final age = time - _born[j];
      if (age < 0 || age > life) continue;
      final x = _x[j] + ox, y = _y[j] + oy;
      switch (style) {
        case TrailStyle.hoarfrost:
          _frost(ground, light, x, y, _size[j], _seed[j], age, time, opacity);
        case TrailStyle.gilt:
          _gilt(ground, light, x, y, _size[j], _seed[j], age, time, opacity);
      }
    }
  }

  // ── Frost Steps ─────────────────────────────────────────────────────

  static const Color _ice = Color(0xFFE6F4FF);
  static const Color _cold = Color(0xFF8FC4FF);

  void _frost(
    CosmeticAtlas ground,
    CosmeticAtlas light,
    double x,
    double y,
    double s,
    int seed,
    double age,
    double time,
    double opacity,
  ) {
    final grow = smoothstep(0, 0.55, age);
    final melt = smoothstep(life * 0.5, life, age);
    final a = (1 - melt) * opacity;
    final shrink = 1 - 0.25 * melt;
    // The cold it lies in, and its pale crust.
    ground.add(AtlasCell.pool, x, y, s * 4.0, atlasArgb(_cold, 0.32 * a));
    ground.add(AtlasCell.pool, x, y, s * 2.6 * grow, atlasArgb(_ice, 0.46 * a));
    // Fine rime grains round it.
    for (var g = 0; g < 16; g++) {
      final ang = hash01(seed * 31 + g, 11) * math.pi * 2;
      final rad = math.sqrt(hash01(seed * 31 + g, 12)) * s * 1.25 * grow;
      ground.add(
        AtlasCell.bead,
        x + math.cos(ang) * rad,
        y + math.sin(ang) * rad * 0.34,
        math.max(1.4, s * (0.1 + 0.06 * hash01(seed * 31 + g, 13))),
        atlasArgb(_ice, 0.7 * a),
      );
    }
    // The fronds.
    ground.add(
      frondCell(seed),
      x,
      y,
      s * 2.6 * grow * shrink,
      atlasArgb(_ice, 0.72 * a),
    );
    // Crystals catching the light as it forms; a wet glint as it goes.
    for (var k = 0; k < 3; k++) {
      final tw = math.sin(time * 3.1 + seed * 1.7 + k * 2.3);
      if (tw < 0.55) continue;
      final ang = hash01(seed * 5 + k, 9) * math.pi * 2;
      light.add(
        AtlasCell.dot,
        x + math.cos(ang) * s * 0.6 * grow,
        y + math.sin(ang) * s * 0.2 * grow,
        s * 0.42,
        atlasArgb(const Color(0xFFFFFFFF), (tw - 0.55) / 0.45 * 0.8 * a),
      );
    }
    if (melt > 0.2 && melt < 0.98) {
      light.add(
        AtlasCell.pool,
        x,
        y,
        s * 1.6,
        atlasArgb(
          const Color(0xFFCFE8FF),
          0.35 * math.sin(math.pi * melt) * opacity,
        ),
      );
    }
  }

  // ── Gold Steps ──────────────────────────────────────────────────────────

  static const Color _gold = Color(0xFFE2B85A);
  static const Color _goldDeep = Color(0xFFB08436);
  static const Color _glint = Color(0xFFFFF0C4);

  void _gilt(
    CosmeticAtlas ground,
    CosmeticAtlas light,
    double x,
    double y,
    double s,
    int seed,
    double age,
    double time,
    double opacity,
  ) {
    final fade = 1 - smoothstep(life * 0.45, life, age);
    final a = fade * opacity;
    // A warm breath of light where the foot came down, soon gone.
    final puff = smoothstep(0, 0.12, age) * (1 - smoothstep(0.2, 1.4, age));
    ground.add(
      AtlasCell.pool,
      x,
      y,
      s * 3.4,
      atlasArgb(const Color(0xFFE0A84A), (0.16 + 0.2 * puff) * opacity * fade),
    );
    const grains = 14;
    for (var g = 0; g < grains; g++) {
      final k = seed * 37 + g;
      final flight = 0.42 + 0.3 * hash01(k, 1);
      final peak = s * (0.6 + 0.9 * hash01(k, 2));
      final dx = (hash01(k, 3) - 0.5) * s * 2.6;
      final depth = (hash01(k, 4) - 0.5) * s * 0.5;
      final land = Offset(x + dx, y + depth);
      final size = math.max(1.5, s * (0.12 + 0.08 * hash01(k, 5)));
      if (age < flight) {
        // In the air: thrown up and falling back, a short tail behind it.
        for (var tail = 2; tail >= 0; tail--) {
          final t = math.max(0.0, age - tail * 0.035) / flight;
          final px = x + dx * t;
          final py = y + depth * t - 4 * peak * t * (1 - t);
          ground.add(
            AtlasCell.bead,
            px,
            py,
            size * (1 - tail * 0.18),
            atlasArgb(
              tail == 0 ? _gold : _goldDeep,
              (tail == 0 ? 0.95 : 0.4 / tail) * opacity,
            ),
          );
        }
        final t = age / flight;
        light.add(
          AtlasCell.dot,
          x + dx * t,
          y + depth * t - 4 * peak * t * (1 - t),
          size * 3.2,
          atlasArgb(_gold, 0.28 * opacity),
        );
        continue;
      }
      // Down: lying in the dust as a glint, turning now and then.
      ground.add(
        AtlasCell.bead,
        land.dx,
        land.dy,
        size,
        atlasArgb(_goldDeep, 0.85 * a),
      );
      final tw = math.sin(time * (2.2 + 1.6 * hash01(k, 6)) + k * 1.9);
      if (tw > 0.35) {
        light.add(
          AtlasCell.dot,
          land.dx,
          land.dy,
          size * 3.6,
          atlasArgb(_glint, (tw - 0.35) / 0.65 * 0.75 * a),
        );
      }
    }
  }
}
