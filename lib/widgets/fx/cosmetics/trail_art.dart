// lib/widgets/fx/cosmetics/trail_art.dart
//
// The Athanor's trails: the ground answering a creature at home, whether
// it walks or stands. A host records each footfall ([TrailPrints.step]) and
// where it stands still ([TrailPrints.stand]), in its own space, and lays
// them into two shared atlases each frame — one laid over the ground, one
// of light added to it — so every trail in a field is two draws, however
// many creatures wear one. Where grass grows over the feet, a third pass
// ([TrailPrints.paintSurface]) lays the trail on the grass tops as well.
//
//   Frost Steps  frost blooms where each foot comes down: a lopsided
//                    spray of fronds that grows out in half a second,
//                    holds, and melts back to a wet glint and nothing.
//                    Standing, frost creeps out over the ground round it.
//   Gold Steps       gold dust kicked up at each step, falling back and
//                    lying in small glints that twinkle and fade.
//                    Standing, gold dust settles round it.
//
// They were prints alone, gone in five seconds, and residents mostly stand:
// a trail was hard to see at all (user, 2026-10-27). Now a still creature
// is always on its patch, prints last twelve seconds, so a stroll leaves a
// path, and in a meadow the trail is on the grass, not hidden under it.
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
  TrailPrints(this.style, {int capacity = defaultCapacity})
    : _x = Float64List(capacity),
      _y = Float64List(capacity),
      _born = Float64List(capacity),
      _size = Float64List(capacity),
      _seed = Int32List(capacity);

  final TrailStyle style;
  final Float64List _x, _y, _born, _size;
  final Int32List _seed;
  int _next = 0, _count = 0, _steps = 0;

  /// The ground it is standing on, and the patch it last walked off.
  final _Patch _here = _Patch(), _left = _Patch();

  /// Seconds from footfall to gone.
  double get life => lifeOf(style);

  static double lifeOf(TrailStyle style) => switch (style) {
    TrailStyle.hoarfrost => 12,
    TrailStyle.gilt => 10,
  };

  /// Seconds for a patch to reach its full spread under a still creature.
  static const double patchGrow = 3.5;

  /// Seconds a patch takes to go once it is walked off.
  double get patchFade => life * 0.55;

  /// Atlas entries, at most, for one print (a Gold print in the air: its
  /// light and fourteen grains, each with a tail of three), one patch, and
  /// one of either on the grass tops (for sizing an atlas).
  static const int entriesPerPrint = 43;
  static const int entriesPerPatch = 48;
  static const int entriesOnGrass = 14;

  /// Prints kept, unless a host asks for another number.
  static const int defaultCapacity = 24;

  /// Every entry one trail of [defaultCapacity] can lay in a frame, at most,
  /// on the ground and on the grass.
  static const int groundEntries =
      defaultCapacity * entriesPerPrint + 2 * entriesPerPatch;
  static const int grassEntries = (defaultCapacity + 2) * entriesOnGrass;

  /// The same for the light laid with them: a print's grains each light
  /// once at most (14), a patch its grains and motes (26), a spot on the
  /// grass its grains (9).
  static const int lightEntries = defaultCapacity * 14 + 2 * 26;
  static const int grassLightEntries = (defaultCapacity + 2) * 9;

  bool get isEmpty => _count == 0 && !_here.active && !_left.active;

  /// Whether anything is still showing at [time].
  bool aliveAt(double time) {
    if (_here.standing) return true;
    if (_left.active && time - _left.left <= patchFade) return true;
    for (var j = 0; j < _count; j++) {
      if (time - _born[j] <= life) return true;
    }
    return false;
  }

  void clear() {
    _count = 0;
    _next = 0;
    _here.from = double.nan;
    _left.from = double.nan;
  }

  /// It is standing still with its feet at ([x], [y]) at [time]: the ground
  /// under it takes the trail, spreading over [patchGrow]. [size] is as for
  /// [step]. Shifted more than half a patch from where it settled, it
  /// leaves that patch and a new one begins.
  void stand(double x, double y, double time, {required double size}) {
    if (_here.standing) {
      final dx = x - _here.x, dy = y - _here.y;
      if (dx * dx + dy * dy < size * size * 2.25) return;
      leave(time);
    }
    _here
      ..x = x
      ..y = y
      ..size = size
      ..from = time
      ..left = double.nan
      ..seed = _steps++;
  }

  /// It walked off the patch it stood on (or was lifted off it): the patch
  /// fades over [patchFade], from however far it had spread.
  void leave(double time) {
    if (!_here.standing) return;
    _left
      ..x = _here.x
      ..y = _here.y
      ..size = _here.size
      ..from = _here.from
      ..left = time
      ..seed = _here.seed;
    _here.from = double.nan;
  }

  /// How far [p] has spread at [time] (0–1) and how much of it is left
  /// (0–1), or null when it is not showing.
  (double, double)? _patchAt(_Patch p, double time) {
    if (!p.active) return null;
    final until = p.left.isNaN ? time : p.left;
    final grow = smoothstep(0, patchGrow, until - p.from);
    final fade = p.left.isNaN
        ? 1.0
        : 1 - smoothstep(0, patchFade, time - p.left);
    if (grow <= 0 || fade <= 0) return null;
    return (grow, fade);
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
    for (final p in [_left, _here]) {
      final at = _patchAt(p, time);
      if (at == null) continue;
      final (grow, fade) = at;
      final x = p.x + ox, y = p.y + oy;
      switch (style) {
        case TrailStyle.hoarfrost:
          _frostPatch(
            ground,
            light,
            x,
            y,
            p.size,
            p.seed,
            grow,
            time,
            fade * opacity,
          );
        case TrailStyle.gilt:
          _giltPatch(
            ground,
            light,
            x,
            y,
            p.size,
            p.seed,
            grow,
            time,
            fade * opacity,
          );
      }
    }
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

  /// The trail on the grass tops, where grass grows over the feet: rime
  /// caught on the blades, or gold dust and its glints, over the prints and
  /// the patches — laid into [over] (drawn over the front grass) and
  /// [light].
  void paintSurface(
    CosmeticAtlas over,
    CosmeticAtlas light,
    double time, {
    double ox = 0,
    double oy = 0,
  }) {
    void tops(double x, double y, double s, int seed, double spread, double a) {
      if (a <= 0.01 || spread <= 0) return;
      final n = style == TrailStyle.hoarfrost ? 9 : 7;
      for (var g = 0; g < n; g++) {
        final k = seed * 53 + g;
        final ang = hash01(k, 21) * math.pi * 2;
        final rad = math.sqrt(hash01(k, 22)) * s * 1.7 * spread;
        // Up on the blades: a little above the ground, at a tip's height.
        final gx = x + math.cos(ang) * rad;
        final gy =
            y + math.sin(ang) * rad * 0.34 - s * (0.45 + 0.9 * hash01(k, 23));
        final size = math.max(1.3, s * (0.09 + 0.06 * hash01(k, 24)));
        final tw = math.sin(time * (2 + 1.4 * hash01(k, 25)) + k * 1.3);
        switch (style) {
          case TrailStyle.hoarfrost:
            over.add(AtlasCell.bead, gx, gy, size, atlasArgb(_ice, 0.8 * a));
            if (tw > 0.6) {
              light.add(
                AtlasCell.dot,
                gx,
                gy,
                size * 3,
                atlasArgb(const Color(0xFFFFFFFF), (tw - 0.6) / 0.4 * 0.6 * a),
              );
            }
          case TrailStyle.gilt:
            over.add(AtlasCell.bead, gx, gy, size, atlasArgb(_gold, 0.85 * a));
            if (tw > 0.3) {
              light.add(
                AtlasCell.dot,
                gx,
                gy,
                size * 3.4,
                atlasArgb(_glint, (tw - 0.3) / 0.7 * 0.7 * a),
              );
            }
        }
      }
    }

    for (final p in [_left, _here]) {
      final at = _patchAt(p, time);
      if (at == null) continue;
      tops(p.x + ox, p.y + oy, p.size, p.seed, at.$1, at.$2);
    }
    for (var j = 0; j < _count; j++) {
      final age = time - _born[j];
      if (age < 0 || age > life) continue;
      final (spread, a) = switch (style) {
        TrailStyle.hoarfrost => (
          smoothstep(0, 0.55, age),
          1 - smoothstep(life * 0.5, life, age),
        ),
        TrailStyle.gilt => (
          smoothstep(0.3, 0.7, age),
          1 - smoothstep(life * 0.45, life, age),
        ),
      };
      tops(_x[j] + ox, _y[j] + oy, _size[j], _seed[j], spread, a);
    }
  }

  // ── Frost Steps ─────────────────────────────────────────────────────

  /// Frost creeping out over the ground round a creature standing still:
  /// the cold first, then rime from the feet outward, fronds reaching off
  /// it, and crystals catching the light. [grow] is how far it has spread.
  void _frostPatch(
    CosmeticAtlas ground,
    CosmeticAtlas light,
    double x,
    double y,
    double s,
    int seed,
    double grow,
    double time,
    double a,
  ) {
    ground.add(
      AtlasCell.pool,
      x,
      y,
      s * 6.2 * (0.45 + 0.55 * grow),
      atlasArgb(_cold, 0.3 * a),
    );
    ground.add(AtlasCell.pool, x, y, s * 4.4 * grow, atlasArgb(_ice, 0.4 * a));
    // Fronds reaching off it, each in its turn.
    for (var k = 0; k < 5; k++) {
      final sk = seed * 13 + k;
      final g = smoothstep(0.1 + k * 0.12, 0.55 + k * 0.1, grow);
      if (g <= 0) continue;
      final ang = (k + hash01(sk, 2) * 0.6) / 5 * math.pi * 2;
      final rad = s * (1.1 + 0.5 * hash01(sk, 3)) * g;
      ground.add(
        frondCell(sk),
        x + math.cos(ang) * rad,
        y + math.sin(ang) * rad * 0.34,
        s * (1.8 + 0.8 * hash01(sk, 4)) * g,
        atlasArgb(_ice, 0.68 * a),
      );
    }
    // Rime, from the feet outward.
    for (var g = 0; g < 24; g++) {
      final k = seed * 29 + g;
      final d = math.sqrt(hash01(k, 5));
      final on = smoothstep(d * 0.8, d * 0.8 + 0.2, grow);
      if (on <= 0) continue;
      final ang = hash01(k, 6) * math.pi * 2;
      ground.add(
        AtlasCell.bead,
        x + math.cos(ang) * d * s * 2.6,
        y + math.sin(ang) * d * s * 2.6 * 0.34,
        math.max(1.4, s * (0.1 + 0.07 * hash01(k, 7))),
        atlasArgb(_ice, 0.75 * on * a),
      );
    }
    for (var k = 0; k < 4; k++) {
      final tw = math.sin(time * 2.7 + seed * 1.9 + k * 1.7);
      if (tw < 0.5) continue;
      final ang = hash01(seed * 7 + k, 8) * math.pi * 2;
      final d = 0.3 + 0.7 * hash01(seed * 7 + k, 9);
      light.add(
        AtlasCell.dot,
        x + math.cos(ang) * d * s * 2.2 * grow,
        y + math.sin(ang) * d * s * 0.75 * grow,
        s * 0.45,
        atlasArgb(const Color(0xFFFFFFFF), (tw - 0.5) / 0.5 * 0.8 * a * grow),
      );
    }
  }

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

  /// Gold dust settling round a creature standing still: a warm light on
  /// the ground, grains drifting down one by one and lying in glints, and a
  /// few motes still turning in the air over it. [grow] is how far it has
  /// spread.
  void _giltPatch(
    CosmeticAtlas ground,
    CosmeticAtlas light,
    double x,
    double y,
    double s,
    int seed,
    double grow,
    double time,
    double a,
  ) {
    ground.add(
      AtlasCell.pool,
      x,
      y,
      s * 5 * (0.5 + 0.5 * grow),
      atlasArgb(const Color(0xFFE0A84A), 0.2 * a),
    );
    for (var g = 0; g < 22; g++) {
      final k = seed * 41 + g;
      // Each grain comes down in its own turn, and lies where it lands.
      final at = hash01(k, 1) * 0.8;
      final down = smoothstep(at, at + 0.18, grow);
      if (down <= 0) continue;
      final d = math.sqrt(hash01(k, 2));
      final ang = hash01(k, 3) * math.pi * 2;
      final gx = x + math.cos(ang) * d * s * 2.3;
      final gy = y + math.sin(ang) * d * s * 2.3 * 0.34 - (1 - down) * s * 1.6;
      final size = math.max(1.5, s * (0.11 + 0.08 * hash01(k, 4)));
      ground.add(
        AtlasCell.bead,
        gx,
        gy,
        size,
        atlasArgb(down < 1 ? _gold : _goldDeep, 0.88 * a),
      );
      final tw = math.sin(time * (2 + 1.5 * hash01(k, 5)) + k * 1.9);
      if (tw > 0.4) {
        light.add(
          AtlasCell.dot,
          gx,
          gy,
          size * 3.6,
          atlasArgb(_glint, (tw - 0.4) / 0.6 * 0.75 * a),
        );
      }
    }
    // Dust still in the air over it, rising slowly and thinning out.
    for (var m = 0; m < 4; m++) {
      final k = seed * 17 + m;
      final f = (time * (0.18 + 0.1 * hash01(k, 6)) + hash01(k, 7)) % 1.0;
      light.add(
        AtlasCell.dot,
        x + (hash01(k, 8) - 0.5) * s * 3 + math.sin(time * 0.9 + k) * s * 0.3,
        y - s * (0.4 + f * 2.6),
        s * 0.55,
        atlasArgb(_gold, 0.32 * math.sin(math.pi * f) * a * grow),
      );
    }
  }

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

/// Ground a creature stands on, taking its trail: where, how big, when it
/// began, and when it was walked off (NaN while it is still stood on).
class _Patch {
  double x = 0, y = 0, size = 0;
  double from = double.nan, left = double.nan;
  int seed = 0;

  bool get active => !from.isNaN;
  bool get standing => active && left.isNaN;
}
