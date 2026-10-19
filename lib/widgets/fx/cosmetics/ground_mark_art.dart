// lib/widgets/fx/cosmetics/ground_mark_art.dart
//
// What an Alchemon's element leaves on the ground where it lives in the
// home biome, coming in over days and fading over days once it has gone
// (models/home_biome.dart, HomeMark). Never announced: the place only
// looks more and more like who lives there.
//
// One table, one painter: each element is a pool of color lying under the
// spot and a scatter of grains in it — embers that flicker, frost lying
// flat, blooms, pebbles, glints that flash now and then, motes that rise or
// hover. More of the grains are out, and the pool deeper, the stronger the
// mark. Grains of light are added (they glow most at night); the rest are
// laid over.

import 'dart:math' as math;

import 'package:alchemons/games/cosmic/cosmic_data.dart' show elementColor;
import 'package:alchemons/games/cosmic/obsidian_kit.dart' show hash01;
import 'package:alchemons/widgets/fx/cosmetics/cosmetic_atlas.dart';
import 'package:flutter/painting.dart';

enum _Motion { still, flicker, rise, hover, flash }

class _MarkStyle {
  const _MarkStyle({
    this.pool,
    this.poolAlpha = 0,
    this.poolLight = false,
    required this.cell,
    required this.grains,
    required this.count,
    required this.size,
    this.motion = _Motion.still,
    this.light = false,
  });

  final Color? pool;
  final double poolAlpha;
  final bool poolLight;
  final AtlasCell cell;
  final List<Color> grains;
  final int count;

  /// A grain's width, as a share of the creature's size.
  final double size;
  final _Motion motion;
  final bool light;
}

const _styles = <String, _MarkStyle>{
  'Fire': _MarkStyle(
    pool: Color(0xFFE8641E),
    poolAlpha: 0.16,
    poolLight: true,
    cell: AtlasCell.bead,
    grains: [Color(0xFFFFB050), Color(0xFFE8521A)],
    count: 14,
    size: 0.035,
    motion: _Motion.flicker,
    light: true,
  ),
  'Lava': _MarkStyle(
    pool: Color(0xFFFF6A1A),
    poolAlpha: 0.24,
    poolLight: true,
    cell: AtlasCell.pool,
    grains: [Color(0xFFFFA040), Color(0xFFE8401A)],
    count: 7,
    size: 0.13,
    motion: _Motion.flicker,
    light: true,
  ),
  'Water': _MarkStyle(
    pool: Color(0xFF2E6A9A),
    poolAlpha: 0.32,
    cell: AtlasCell.bead,
    grains: [Color(0xFFBFE4FF)],
    count: 7,
    size: 0.026,
    motion: _Motion.flash,
    light: true,
  ),
  'Ice': _MarkStyle(
    pool: Color(0xFFCFEFFF),
    poolAlpha: 0.14,
    poolLight: true,
    cell: AtlasCell.frond0,
    grains: [Color(0xFFDFF4FF), Color(0xFFBFE8FF)],
    count: 6,
    size: 0.24,
  ),
  'Steam': _MarkStyle(
    pool: Color(0xFFD8DEE4),
    poolAlpha: 0.08,
    cell: AtlasCell.dot,
    grains: [Color(0xFFE8ECF0)],
    count: 6,
    size: 0.16,
    motion: _Motion.rise,
  ),
  'Earth': _MarkStyle(
    pool: Color(0xFF5A4630),
    poolAlpha: 0.3,
    cell: AtlasCell.bead,
    grains: [Color(0xFF8E7A62), Color(0xFF6A5A48), Color(0xFFA89478)],
    count: 13,
    size: 0.042,
  ),
  'Mud': _MarkStyle(
    pool: Color(0xFF2E2418),
    poolAlpha: 0.5,
    cell: AtlasCell.bead,
    grains: [Color(0xFF6A5642), Color(0xFF4A3A28)],
    count: 6,
    size: 0.032,
  ),
  'Dust': _MarkStyle(
    pool: Color(0xFFD9B98A),
    poolAlpha: 0.14,
    cell: AtlasCell.dot,
    grains: [Color(0xFFE8CFA0), Color(0xFFC8A878)],
    count: 22,
    size: 0.024,
  ),
  'Crystal': _MarkStyle(
    pool: Color(0xFF1DE9B6),
    poolAlpha: 0.1,
    poolLight: true,
    cell: AtlasCell.plume,
    grains: [Color(0xFF7FF0D8), Color(0xFFBFFFF0)],
    count: 7,
    size: 0.05,
    motion: _Motion.flash,
    light: true,
  ),
  'Air': _MarkStyle(
    cell: AtlasCell.dot,
    grains: [Color(0xFFDDF2FF)],
    count: 10,
    size: 0.03,
    motion: _Motion.hover,
    light: true,
  ),
  'Plant': _MarkStyle(
    pool: Color(0xFF3E7A30),
    poolAlpha: 0.24,
    cell: AtlasCell.bead,
    grains: [
      Color(0xFFF6D8E2),
      Color(0xFFFFF4B0),
      Color(0xFFB8E890),
      Color(0xFFFFFFFF),
    ],
    count: 12,
    size: 0.036,
  ),
  'Poison': _MarkStyle(
    pool: Color(0xFF6A2E8A),
    poolAlpha: 0.2,
    cell: AtlasCell.dot,
    grains: [Color(0xFFB07ADC), Color(0xFF9CF06A)],
    count: 9,
    size: 0.032,
    motion: _Motion.rise,
    light: true,
  ),
  'Spirit': _MarkStyle(
    pool: Color(0xFF3F51B5),
    poolAlpha: 0.12,
    poolLight: true,
    cell: AtlasCell.dot,
    grains: [Color(0xFFCFE0FF)],
    count: 8,
    size: 0.036,
    motion: _Motion.hover,
    light: true,
  ),
  'Dark': _MarkStyle(
    pool: Color(0xFF05030A),
    poolAlpha: 0.55,
    cell: AtlasCell.dot,
    grains: [Color(0xFF7A4ACC)],
    count: 4,
    size: 0.05,
    motion: _Motion.hover,
    light: true,
  ),
  'Light': _MarkStyle(
    pool: Color(0xFFFFE9A8),
    poolAlpha: 0.18,
    poolLight: true,
    cell: AtlasCell.bead,
    grains: [Color(0xFFFFF4D0)],
    count: 8,
    size: 0.03,
    motion: _Motion.flash,
    light: true,
  ),
  'Lightning': _MarkStyle(
    pool: Color(0xFFFFEB3B),
    poolAlpha: 0.06,
    poolLight: true,
    cell: AtlasCell.bead,
    grains: [Color(0xFFFFF59D), Color(0xFFFFFFFF)],
    count: 8,
    size: 0.026,
    motion: _Motion.flash,
    light: true,
  ),
  'Blood': _MarkStyle(
    pool: Color(0xFF5A0A12),
    poolAlpha: 0.38,
    cell: AtlasCell.bead,
    grains: [Color(0xFFA01E28), Color(0xFF6E1018)],
    count: 9,
    size: 0.032,
  ),
};

/// Whether [element] leaves a mark.
bool elementMarks(String? element) => _styles.containsKey(element);

/// Where something lies buried, as the place shows it: an eddy of lit
/// grains turning slowly just over the ground, breathing, in [color] — and
/// once it is dug ([rise] 0→1), the grains drawn up and in to where it
/// rises, and gone.
void paintBuriedCue(
  double x,
  double y,
  double size,
  Color color,
  double time,
  double rise,
  CosmeticAtlas over,
  CosmeticAtlas light,
) {
  final breath = 0.7 + 0.3 * math.sin(time * 0.9);
  final gone = smoothstep(0.75, 1.0, rise);
  final vis = (1 - gone) * breath;
  if (vis <= 0.004) return;
  light.add(
    AtlasCell.pool,
    x,
    y,
    size * (1.1 + 0.6 * rise),
    atlasArgb(color, (0.12 + 0.25 * rise) * vis),
  );
  const n = 28;
  for (var i = 0; i < n; i++) {
    final h = hash01(i, 900);
    final a = h * math.pi * 2 + time * (0.35 + 0.3 * hash01(i, 901)) * (i.isEven ? 1 : -1);
    final r = size * (0.18 + 0.2 * hash01(i, 902)) * (1 - 0.8 * rise);
    final up = size * (0.04 + 0.08 * hash01(i, 903)) + rise * size * 0.9;
    final px = x + math.cos(a) * r;
    final py = y - up + math.sin(a) * r * 0.22;
    light.add(
      AtlasCell.bead,
      px,
      py,
      size * 0.028,
      atlasArgb(color, (0.5 + 0.4 * math.sin(time * 2 + i)) * vis),
    );
    if (i % 4 == 0) {
      light.add(AtlasCell.dot, px, py, size * 0.1, atlasArgb(color, 0.12 * vis));
    }
  }
}

/// How much it is night at [hour] (0–24): 0 by day, 1 from late evening
/// to before dawn.
double nightAt(double hour) {
  final h = hour % 24;
  if (h >= 12) return smoothstep(19.4, 21.2, h);
  return 1 - smoothstep(4.8, 6.4, h);
}

/// The thread of grains between two Alchemons in harmony: from [a]'s chest
/// to [b]'s, arched, grains running out of each in its element's color and
/// turning to what they make ([makes]) where they meet. Strong at night,
/// barely there by day.
void paintHarmonyThread(
  Offset a,
  Offset b,
  String elementA,
  String elementB,
  String makes,
  double size,
  double time,
  double night,
  CosmeticAtlas light,
) {
  final vis = 0.08 + 0.72 * night;
  final ca = elementColor(elementA), cb = elementColor(elementB);
  final cm = elementColor(makes);
  final rise = size * 0.28;
  Offset at(double t) {
    final p = Offset.lerp(a, b, t)!;
    return p.translate(0, -rise * 4 * t * (1 - t));
  }

  // The thread itself, faint and continuous.
  const n = 22;
  for (var i = 0; i <= n; i++) {
    final t = i / n;
    final p = at(t);
    final c = t < 0.5
        ? Color.lerp(ca, cm, t * 2)!
        : Color.lerp(cm, cb, (t - 0.5) * 2)!;
    light.add(AtlasCell.dot, p.dx, p.dy, size * 0.08, atlasArgb(c, 0.16 * vis));
  }
  // Grains running along it from either end, meeting in the middle.
  for (var i = 0; i < 12; i++) {
    final fromA = i.isEven;
    final f = (time / 3.2 + i / 12) % 1;
    final t = fromA ? f * 0.5 : 1 - f * 0.5;
    final p = at(t);
    final c = Color.lerp(fromA ? ca : cb, cm, f)!;
    light
      ..add(
        AtlasCell.bead,
        p.dx,
        p.dy,
        size * 0.035,
        atlasArgb(c, 0.85 * vis * math.sin(math.pi * (0.15 + 0.85 * f))),
      )
      ..add(
        AtlasCell.dot,
        p.dx,
        p.dy,
        size * 0.12,
        atlasArgb(c, 0.2 * vis),
      );
  }
  // Where they meet, a slow glow of what they make.
  final mid = at(0.5);
  final beat = 0.75 + 0.25 * math.sin(time * 1.1);
  light.add(
    AtlasCell.dot,
    mid.dx,
    mid.dy,
    size * 0.32,
    atlasArgb(cm, 0.3 * vis * beat),
  );
}

/// Lays [element]'s mark at [strength] (0–1) round ([x], [y]) — the feet of
/// a creature [size] across — at the field's clock [time] into [over] and
/// [light]. [seed] keeps each one's scatter its own.
void paintGroundMark(
  String element,
  double strength,
  double x,
  double y,
  double size,
  double time,
  int seed,
  CosmeticAtlas over,
  CosmeticAtlas light,
) {
  final st = _styles[element];
  if (st == null || strength <= 0.01) return;
  final pool = st.pool;
  if (pool != null) {
    (st.poolLight ? light : over).add(
      AtlasCell.pool,
      x,
      y + size * 0.01,
      size * (1.1 + 0.7 * strength),
      atlasArgb(pool, st.poolAlpha * strength),
    );
  }
  final out = st.light ? light : over;
  final n = (st.count * (0.35 + 0.65 * strength)).round();
  final spread = size * (0.45 + 0.35 * strength);
  for (var i = 0; i < n; i++) {
    final h1 = hash01(i, seed), h2 = hash01(i, seed + 1);
    final h3 = hash01(i, seed + 2);
    // Thicker near the middle.
    final across = (h1 - 0.5) * 2;
    var gx = x + across * across.abs() * spread;
    var gy = y + (h2 - 0.5) * size * 0.07;
    var a = strength * (0.55 + 0.45 * h3);
    switch (st.motion) {
      case _Motion.still:
        break;
      case _Motion.flicker:
        a *= 0.55 + 0.45 * math.sin(time * (4 + 3 * h3) + i * 1.7);
      case _Motion.rise:
        final life = (time / (3.5 + 2 * h3) + h2) % 1;
        gy -= life * size * 0.45;
        a *= math.sin(math.pi * life);
      case _Motion.hover:
        gx += math.sin(time * (0.4 + 0.3 * h3) + i) * size * 0.08;
        gy -=
            size * (0.08 + 0.18 * h2) +
            math.sin(time * (0.7 + 0.4 * h1) + i * 2) * size * 0.03;
        a *= 0.6 + 0.4 * math.sin(time * 1.3 + i);
      case _Motion.flash:
        final f = math.pow(
          math.max(0.0, math.sin(time * (0.9 + 1.2 * h3) + i * 2.3)),
          8,
        );
        a *= 0.18 + 0.82 * f;
    }
    final cell = st.cell == AtlasCell.frond0 ? frondCell(seed + i) : st.cell;
    out.add(
      cell,
      gx,
      gy,
      size * st.size * (0.7 + 0.6 * h2),
      atlasArgb(st.grains[i % st.grains.length], a.clamp(0.0, 1.0)),
      // Shards stand up; fronds lie at any turn; the rest are round.
      rot: st.cell == AtlasCell.plume
          ? (h1 - 0.5) * 0.5
          : st.cell == AtlasCell.frond0
          ? (h3 - 0.5) * 0.6
          : 0,
    );
  }
}
