import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

part 'battle_floor_orrery.dart';
part 'battle_floor_tidal.dart';
part 'battle_floor_garden.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  THE BATTLE FLOORS
//
//  What a battle is fought on (cosmic_game_battle.dart). Looks only: no floor
//  changes a rule. Each is dark and mostly empty so four Alchemons and their
//  abilities read on it; each is told by its material in grains and soft
//  light, never by lines (no hoops, no outlines); each has one thing of its
//  own the fight touches. The still parts are recorded once into pictures.
//
//  • Obsidian Floor (free): a slab of dark stone adrift in space.
//  • Glass Orrery: leaded glass over turning brass rings; the pane under a
//    special lights in its element's colour.
//  • Tidal Mirror: still black water; the fighters are mirrored in it, and
//    ripples spread where they step and where blows land.
//  • Moonlit Garden: flagstones and moss under a moon; fireflies drift off
//    from the fight.
// ─────────────────────────────────────────────────────────────────────────────

/// Half the battle floor's width and height.
const double kBattleFloorHalfWidth = 420.0;
const double kBattleFloorHalfHeight = 560.0;

const Color kBattleBrass = Color(0xFFCDB07A);
const Color kBattleSilver = Color(0xFFCBD2DA);

const Color _space = Color(0xFF060608);
const Color _stoneMid = Color(0xFF1C1C21);
const Color _stoneEdge = Color(0xFF121216);
const Color _dust = Color(0xFF8E8C88);
const Color _seam = Color(0xFFDCD3C2);

/// The floor for arena [id], [rx] by [ry] (half sizes); the obsidian floor
/// for an id it does not know.
BattleFloor battleFloorFor(String id, {required double rx, required double ry}) =>
    switch (id) {
      'orrery' => OrreryFloor(rx: rx, ry: ry),
      'tidal' => TidalFloor(rx: rx, ry: ry),
      'garden' => GardenFloor(rx: rx, ry: ry),
      _ => ObsidianFloor(rx: rx, ry: ry),
    };

/// A battle floor. Positions it is given are relative to its centre.
abstract class BattleFloor {
  BattleFloor({required this.rx, required this.ry});

  /// Half the floor's width and height.
  final double rx;
  final double ry;

  /// Whether the fighters are mirrored in it (the game draws them so).
  bool get reflects => false;

  /// The floor centred on [centre], at [time] seconds; [view] is the world
  /// rect on screen, filled with space first.
  void paint(Canvas canvas, Offset centre, double time, Rect view);

  /// A fighter's foot came down at [at].
  void step(Offset at, double time) {}

  /// A blow landed at [at], of [strength] 0..1, in [color].
  void hit(Offset at, Color color, double strength, double time) {}

  /// A special went off at [at] in its element's [color].
  void special(Offset at, Color color, double time) {}

  /// Where the fighters stand this frame.
  void fighters(List<Offset> at, double dt) {}

  void dispose() {}

  /// A soft elliptical pool: a radial gradient of [colors] stretched to
  /// [radiusX] by [radiusY].
  static void pool(
    Canvas c,
    Offset at,
    double radiusX,
    double radiusY,
    List<Color> colors, [
    List<double>? stops,
  ]) {
    c.save();
    c.translate(at.dx, at.dy);
    c.scale(1, radiusY / radiusX);
    c.drawCircle(
      Offset.zero,
      radiusX,
      Paint()
        ..shader = ui.Gradient.radial(Offset.zero, radiusX, colors, stops),
    );
    c.restore();
  }

  /// Whether [p] is inside the floor's oval, scaled by [k].
  bool inside(Offset p, [double k = 1]) {
    final x = p.dx / (rx * k), y = p.dy / (ry * k);
    return x * x + y * y <= 1;
  }

  /// Stars in the dark round the floor (none under it).
  void paintStars(Canvas c, Random rng, {int count = 320}) {
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final p = Offset(
        (rng.nextDouble() * 2 - 1) * rx * 2.6,
        (rng.nextDouble() * 2 - 1) * ry * 2.2,
      );
      if (inside(p)) continue;
      final r = 0.5 + pow(rng.nextDouble(), 3) * 1.4;
      final a = 0.12 + rng.nextDouble() * 0.45;
      paint.color = Color.lerp(
        const Color(0xFFE6E8F0),
        const Color(0xFFB8C4E0),
        rng.nextDouble(),
      )!.withValues(alpha: a);
      c.drawCircle(p, r, paint);
    }
  }
}

/// Irregular cells round [sites] (a Voronoi diagram), each the polygon of
/// points nearer its site than any other, inside [bounds]. For floors made
/// of shards or flagstones: built once, at bake time.
List<List<Offset>> floorCells(List<Offset> sites, Rect bounds) {
  List<Offset> clip(List<Offset> poly, Offset a, Offset b) {
    // Keep the side of the bisector of a–b nearer a.
    final mid = (a + b) / 2;
    final n = b - a;
    double side(Offset p) => (p - mid).dx * n.dx + (p - mid).dy * n.dy;
    final out = <Offset>[];
    for (var i = 0; i < poly.length; i++) {
      final p = poly[i], q = poly[(i + 1) % poly.length];
      final sp = side(p), sq = side(q);
      if (sp <= 0) out.add(p);
      if ((sp <= 0) != (sq <= 0)) {
        out.add(Offset.lerp(p, q, sp / (sp - sq))!);
      }
    }
    return out;
  }

  return [
    for (final a in sites)
      () {
        var poly = [
          bounds.topLeft,
          bounds.topRight,
          bounds.bottomRight,
          bounds.bottomLeft,
        ];
        for (final b in sites) {
          if (identical(a, b) || (a - b).distance > bounds.longestSide) continue;
          if ((a - b).distance < 1e-6) continue;
          poly = clip(poly, a, b);
          if (poly.length < 3) break;
        }
        return poly;
      }(),
  ];
}

/// [cell] drawn in from its edges by [gap] toward [site], as a path: a
/// shard or a stone with lead or moss round it.
Path insetCell(List<Offset> cell, Offset site, double gap) {
  final path = Path();
  for (var i = 0; i < cell.length; i++) {
    final p = cell[i];
    final d = (p - site).distance;
    final q = d <= gap * 1.5 ? site : site + (p - site) * ((d - gap) / d);
    i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
  }
  return path..close();
}

/// A slab of dark stone adrift in space: the free floor.
class ObsidianFloor extends BattleFloor {
  ObsidianFloor({required super.rx, required super.ry, this.seed = 19});

  final int seed;

  ui.Picture? _still;
  late final List<_Glint> _glints = _makeGlints();
  late final List<_Mote> _motes = _makeMotes();

  @override
  void dispose() {
    _still?.dispose();
    _still = null;
  }

  @override
  void paint(Canvas canvas, Offset centre, double time, Rect view) {
    canvas.drawRect(view, Paint()..color = _space);
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.drawPicture(_still ??= _record());
    _paintGlints(canvas, time);
    _paintMotes(canvas, time);
    canvas.restore();
  }

  ui.Picture _record() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final rng = Random(seed);
    paintStars(c, rng);
    _paintHalo(c);
    _paintSlab(c);
    _paintPools(c);
    _paintFloorGrains(c, rng);
    _paintRim(c, rng);
    _paintSeam(c, rng);
    return rec.endRecording();
  }

  /// A faint glow off the slab into the dark, so its edge is soft.
  void _paintHalo(Canvas c) => BattleFloor.pool(
    c,
    Offset.zero,
    rx * 1.22,
    ry * 1.18,
    [
      const Color(0xFF1C1C22).withValues(alpha: 0.55),
      const Color(0xFF1C1C22).withValues(alpha: 0.0),
    ],
    const [0.78, 1.0],
  );

  /// The stone, and its worn lip: a little lighter just inside the edge,
  /// where the dust gathers, before it falls away into the dark.
  void _paintSlab(Canvas c) => BattleFloor.pool(
    c,
    Offset.zero,
    rx,
    ry,
    const [
      _stoneMid,
      Color(0xFF16161A),
      _stoneEdge,
      Color(0xFF1E1D21),
      Color(0xFF0E0E11),
    ],
    const [0.0, 0.6, 0.86, 0.96, 1.0],
  );

  /// Each side's half lit from its own end, inside the slab.
  void _paintPools(Canvas c) {
    c.save();
    c.clipPath(
      Path()..addOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2)),
    );
    for (final (y, color, a) in [
      (ry * 0.62, kBattleBrass, 0.16),
      (-ry * 0.62, kBattleSilver, 0.12),
    ]) {
      BattleFloor.pool(c, Offset(0, y), rx * 1.0, ry * 0.62, [
        color.withValues(alpha: a),
        color.withValues(alpha: 0),
      ]);
    }
    c.restore();
  }

  /// Specks across the stone: what tells it is stone.
  void _paintFloorGrains(Canvas c, Random rng) {
    final paint = Paint();
    var placed = 0;
    while (placed < 1700) {
      final x = (rng.nextDouble() * 2 - 1) * rx;
      final y = (rng.nextDouble() * 2 - 1) * ry;
      final d = (x / rx) * (x / rx) + (y / ry) * (y / ry);
      if (d > 0.97) continue;
      placed++;
      final half = y > 0 ? kBattleBrass : kBattleSilver;
      final light = (y.abs() / ry).clamp(0.0, 1.0);
      final tone = Color.lerp(_dust, half, 0.25 + 0.35 * light)!;
      paint.color = tone.withValues(alpha: 0.04 + rng.nextDouble() * 0.11);
      c.drawCircle(Offset(x, y), 0.5 + rng.nextDouble() * 1.1, paint);
    }
  }

  /// The edge, worn: dust in drifts along the lip, thick in places and
  /// bare in others, thinning inward over a wide band, a little spilling
  /// past it. No line is drawn and no ring is even.
  void _paintRim(Canvas c, Random rng) {
    final paint = Paint();
    // Drifts: where along the edge the dust lies thick.
    final drifts = [
      for (var i = 0; i < 9; i++)
        (rng.nextDouble() * pi * 2, 0.25 + rng.nextDouble() * 0.5),
    ];
    double drift(double a) {
      var k = 0.18;
      for (final (at, width) in drifts) {
        var d = (a - at).abs() % (pi * 2);
        if (d > pi) d = pi * 2 - d;
        k += exp(-(d * d) / (width * width * 0.18));
      }
      return k.clamp(0.0, 1.0);
    }

    var placed = 0;
    while (placed < 1500) {
      final a = rng.nextDouble() * pi * 2;
      if (rng.nextDouble() > drift(a)) continue;
      placed++;
      final g = rng.nextDouble();
      final r = g < 0.9
          ? 1.0 - pow(rng.nextDouble(), 1.6) * 0.16
          : 1.0 + rng.nextDouble() * 0.04;
      final p = Offset(cos(a) * rx * r, sin(a) * ry * r);
      final half = p.dy > 0 ? kBattleBrass : kBattleSilver;
      final tone = Color.lerp(_dust, half, 0.3 + rng.nextDouble() * 0.4)!;
      final inside = r <= 1.0;
      final depth = inside ? (1 - (1 - r) / 0.16) : 0.0;
      paint.color = tone.withValues(
        alpha: inside
            ? (0.04 + rng.nextDouble() * 0.16) * (0.35 + 0.65 * depth)
            : 0.03 + rng.nextDouble() * 0.08,
      );
      c.drawCircle(p, 0.6 + rng.nextDouble() * (inside ? 1.6 : 0.8), paint);
    }
  }

  /// The glass seam across the middle: a lens of faint light, fading to
  /// nothing at both ends, set with a few shards.
  void _paintSeam(Canvas c, Random rng) {
    for (final (h, a) in [(46.0, 0.07), (16.0, 0.08)]) {
      BattleFloor.pool(c, Offset.zero, rx * 0.94, h / 2, [
        _seam.withValues(alpha: a),
        _seam.withValues(alpha: 0),
      ]);
    }
    final paint = Paint();
    for (var i = 0; i < 40; i++) {
      final x = (rng.nextDouble() * 2 - 1) * rx * 0.88;
      final along = 1 - (x / (rx * 0.94)).abs();
      final y = (rng.nextDouble() * 2 - 1) * 9 * along;
      paint.color = _seam.withValues(
        alpha: (0.06 + rng.nextDouble() * 0.18) * along,
      );
      c.drawCircle(Offset(x, y), 0.5 + rng.nextDouble() * 0.9, paint);
    }
  }

  List<_Glint> _makeGlints() {
    final rng = Random(seed + 1);
    return [
      for (var i = 0; i < 18; i++)
        _Glint(
          Offset(
            (rng.nextDouble() * 2 - 1) * rx * 0.8,
            (rng.nextDouble() * 2 - 1) * 2.4,
          ),
          rng.nextDouble() * pi * 2,
          0.5 + rng.nextDouble() * 0.9,
        ),
    ];
  }

  void _paintGlints(Canvas canvas, double time) {
    final paint = Paint();
    for (final g in _glints) {
      final k = sin(time * g.speed + g.phase);
      if (k < 0.55) continue;
      final a = (k - 0.55) / 0.45;
      paint.shader = ui.Gradient.radial(g.at, 7, [
        _seam.withValues(alpha: 0.5 * a),
        _seam.withValues(alpha: 0),
      ]);
      canvas.drawCircle(g.at, 7, paint);
    }
  }

  List<_Mote> _makeMotes() {
    final rng = Random(seed + 2);
    return [
      for (var i = 0; i < 40; i++)
        _Mote(
          x: (rng.nextDouble() * 2 - 1) * rx * 0.85,
          offset: rng.nextDouble(),
          speed: 0.025 + rng.nextDouble() * 0.04,
          phase: rng.nextDouble() * pi * 2,
          size: 0.8 + rng.nextDouble() * 1.2,
        ),
    ];
  }

  /// Motes rising off each half, toward the seam, fading as they go.
  void _paintMotes(Canvas canvas, double time) {
    final paint = Paint();
    for (var i = 0; i < _motes.length; i++) {
      final m = _motes[i];
      final below = i.isEven;
      final u = (m.offset + time * m.speed) % 1.0;
      final y = (below ? 1 : -1) * ry * 0.85 * (1 - u);
      final x = m.x + sin(time * 0.4 + m.phase) * 10;
      final d = (x / rx) * (x / rx) + (y / ry) * (y / ry);
      if (d > 0.9) continue;
      final a = sin(pi * u) * 0.28;
      paint.color = (below ? kBattleBrass : kBattleSilver).withValues(alpha: a);
      canvas.drawCircle(Offset(x, y), m.size, paint);
    }
  }
}

class _Glint {
  _Glint(this.at, this.phase, this.speed);
  final Offset at;
  final double phase;
  final double speed;
}

class _Mote {
  _Mote({
    required this.x,
    required this.offset,
    required this.speed,
    required this.phase,
    required this.size,
  });
  final double x;
  final double offset;
  final double speed;
  final double phase;
  final double size;
}
